import CoreAudio
import Foundation
import HeadphoneSafetyCore

var failureCount = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String, file: StaticString = #fileID, line: UInt = #line) {
    guard condition() else {
        failureCount += 1
        fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
        return
    }
    print("PASS: \(message)")
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: StaticString = #fileID, line: UInt = #line) {
    guard actual == expected else {
        failureCount += 1
        fputs("FAIL: \(message) expected \(expected), got \(actual) (\(file):\(line))\n", stderr)
        return
    }
    print("PASS: \(message)")
}

func expectApprox(_ actual: Double, _ expected: Double, accuracy: Double = 0.0001, _ message: String) {
    guard abs(actual - expected) <= accuracy else {
        failureCount += 1
        fputs("FAIL: \(message) expected \(expected), got \(actual)\n", stderr)
        return
    }
    print("PASS: \(message)")
}

print("Running Headphone Safety verification tests...\n")

expect(!AudioRouteKind.builtInSpeakers.isLimited, "built-in speakers are not limited")
expect(!AudioRouteKind.unavailable.isLimited, "unavailable route is not limited")
expect(AudioRouteKind.wiredHeadphones.isLimited, "wired headphones are limited")
expect(AudioRouteKind.bluetoothHeadphones.isLimited, "bluetooth headphones are limited")
expect(AudioRouteKind.usbHeadphones.isLimited, "usb headphones are limited")
expect(AudioRouteKind.other.isLimited, "other outputs are limited")

expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "Generic Device", transportType: kAudioDeviceTransportTypeBluetooth),
    .bluetoothHeadphones,
    "bluetooth transport is classified as bluetooth headphones"
)
expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "Generic Device", transportType: kAudioDeviceTransportTypeBluetoothLE),
    .bluetoothHeadphones,
    "bluetooth LE transport is classified as bluetooth headphones"
)
expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "USB Audio", transportType: kAudioDeviceTransportTypeUSB),
    .usbHeadphones,
    "usb transport is classified as usb headphones"
)
expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "MacBook Pro Speakers", transportType: kAudioDeviceTransportTypeBuiltIn),
    .builtInSpeakers,
    "built-in transport without headphone jack is not limited"
)
expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "Aadish's AirPods Pro", transportType: nil),
    .bluetoothHeadphones,
    "airpods name heuristic is limited"
)
expectEqual(
    AudioRouteCore.routeKind(for: 1, deviceName: "LG TV", transportType: kAudioDeviceTransportTypeHDMI),
    .other,
    "hdmi output is classified as other"
)

expect(
    !AudioRouteCore.shouldLaunchProtectionApp(
        isMainAppRunning: true,
        isDefaultOutputLimited: true,
        isDefaultOutputRunning: true
    ),
    "does not launch when main app is already running"
)
expect(
    !AudioRouteCore.shouldLaunchProtectionApp(
        isMainAppRunning: false,
        isDefaultOutputLimited: false,
        isDefaultOutputRunning: true
    ),
    "does not launch for built-in speakers"
)
expect(
    !AudioRouteCore.shouldLaunchProtectionApp(
        isMainAppRunning: false,
        isDefaultOutputLimited: true,
        isDefaultOutputRunning: false
    ),
    "does not launch when limited output is idle"
)
expect(
    AudioRouteCore.shouldLaunchProtectionApp(
        isMainAppRunning: false,
        isDefaultOutputLimited: true,
        isDefaultOutputRunning: true
    ),
    "launches when limited output is playing and app is not running"
)

expectApprox(VolumeLimitSettings.defaultCeiling, 0.40, "default ceiling is 40%")
expect(VolumeLimitSettings.defaultProtectionEnabled, "default protection is enabled")
expectEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.40), 85, "40% maps to 85 dB")
expectEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.10), 75, "10% maps to 75 dB")
expectEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 1.0), 100, "100% maps to 100 dB")
expectEqual(VolumeLimitSettings.estimatedDB(forVolumeCeiling: 0.70), 93, "70% maps to 93 dB")

if let deviceID = AudioRouteCore.defaultOutputDeviceID() {
    let kind = AudioRouteCore.routeKind(for: deviceID)
    print("INFO: current default output route is \(kind.rawValue)")
    expect(kind == .builtInSpeakers || kind.isLimited, "live default output route is recognized")
} else {
    print("INFO: no default output device available for live CoreAudio check")
}

print("")
if failureCount == 0 {
    print("All verification tests passed.")
    exit(0)
} else {
    fputs("\(failureCount) verification test(s) failed.\n", stderr)
    exit(1)
}
