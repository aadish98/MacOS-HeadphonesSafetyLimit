import CoreAudio
import HeadphoneSafetyCore
import XCTest

final class AudioRouteKindTests: XCTestCase {
    func testBuiltInSpeakersAreNotLimited() {
        XCTAssertFalse(AudioRouteKind.builtInSpeakers.isLimited)
        XCTAssertFalse(AudioRouteKind.unavailable.isLimited)
    }

    func testExternalOutputsAreLimited() {
        XCTAssertTrue(AudioRouteKind.wiredHeadphones.isLimited)
        XCTAssertTrue(AudioRouteKind.bluetoothHeadphones.isLimited)
        XCTAssertTrue(AudioRouteKind.usbHeadphones.isLimited)
        XCTAssertTrue(AudioRouteKind.other.isLimited)
    }
}

final class AudioRouteClassificationTests: XCTestCase {
    func testBluetoothTransportIsLimited() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "Generic Device",
            transportType: kAudioDeviceTransportTypeBluetooth
        )
        XCTAssertEqual(kind, .bluetoothHeadphones)
    }

    func testBluetoothLETransportIsLimited() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "Generic Device",
            transportType: kAudioDeviceTransportTypeBluetoothLE
        )
        XCTAssertEqual(kind, .bluetoothHeadphones)
    }

    func testUSBTransportIsLimited() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "USB Audio",
            transportType: kAudioDeviceTransportTypeUSB
        )
        XCTAssertEqual(kind, .usbHeadphones)
    }

    func testBuiltInTransportWithoutHeadphoneJackIsNotLimited() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "MacBook Pro Speakers",
            transportType: kAudioDeviceTransportTypeBuiltIn
        )
        XCTAssertEqual(kind, .builtInSpeakers)
    }

    func testNameHeuristicDetectsAirPods() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "Aadish's AirPods Pro",
            transportType: nil
        )
        XCTAssertEqual(kind, .bluetoothHeadphones)
    }

    func testNameHeuristicDetectsHDMIAsOtherLimitedOutput() {
        let kind = AudioRouteCore.routeKind(
            for: 1,
            deviceName: "LG TV",
            transportType: kAudioDeviceTransportTypeHDMI
        )
        XCTAssertEqual(kind, .other)
        XCTAssertTrue(kind.isLimited)
    }
}

final class LaunchDecisionTests: XCTestCase {
    func testDoesNotLaunchWhenMainAppAlreadyRunning() {
        XCTAssertFalse(
            AudioRouteCore.shouldLaunchProtectionApp(
                isMainAppRunning: true,
                isDefaultOutputLimited: true,
                isDefaultOutputRunning: true
            )
        )
    }

    func testDoesNotLaunchForBuiltInSpeakers() {
        XCTAssertFalse(
            AudioRouteCore.shouldLaunchProtectionApp(
                isMainAppRunning: false,
                isDefaultOutputLimited: false,
                isDefaultOutputRunning: true
            )
        )
    }

    func testDoesNotLaunchWhenLimitedOutputIsIdle() {
        XCTAssertFalse(
            AudioRouteCore.shouldLaunchProtectionApp(
                isMainAppRunning: false,
                isDefaultOutputLimited: true,
                isDefaultOutputRunning: false
            )
        )
    }

    func testLaunchesWhenLimitedOutputIsPlayingAndAppIsNotRunning() {
        XCTAssertTrue(
            AudioRouteCore.shouldLaunchProtectionApp(
                isMainAppRunning: false,
                isDefaultOutputLimited: true,
                isDefaultOutputRunning: true
            )
        )
    }
}

final class VolumeLimitSettingsTests: XCTestCase {
    func testDefaultCeilingIsFortyPercent() {
        XCTAssertEqual(VolumeLimitSettings.defaultCeiling, 0.40, accuracy: 0.0001)
    }

    func testDefaultProtectionEnabled() {
        XCTAssertTrue(VolumeLimitSettings.defaultProtectionEnabled)
    }

    func testEstimatedDBAtDefaultCeiling() {
        XCTAssertEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.40), 85)
    }

    func testEstimatedDBAtMinimumSliderValue() {
        XCTAssertEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.10), 75)
    }

    func testEstimatedDBAtMaximumSliderValue() {
        XCTAssertEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 1.0), 100)
    }

    func testEstimatedDBTracksSliderBetweenAnchors() {
        XCTAssertEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.70), 93)
    }
}

final class SettingsDefaultsTests: XCTestCase {
    func testFreshDefaultsUseSharedVolumeLimitConstants() {
        XCTAssertTrue(VolumeLimitSettings.defaultProtectionEnabled)
        XCTAssertEqual(VolumeLimitSettings.defaultCeiling, 0.40, accuracy: 0.0001)
    }
}
