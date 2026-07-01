import AppKit
import CoreAudio
import Foundation
import HeadphoneSafetyCore

private let mainAppBundleIdentifier = "com.aadishms.HeadphoneSafetyLimit"

final class PlaybackLaunchMonitor {
    private var monitoredDeviceIDs: Set<AudioDeviceID> = []
    private var pollTimer: Timer?
    private var clientData: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    func start() {
        addSystemListeners()
        refreshDeviceListeners()
        startPollTimer()
        evaluateLaunchConditions()
    }

    private func startPollTimer() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.evaluateLaunchConditions()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func evaluateLaunchConditions() {
        guard AudioRouteCore.shouldLaunchProtectionApp(isMainAppRunning: isMainAppRunning()) else { return }
        launchMainApp()
    }

    private func isMainAppRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleIdentifier).isEmpty
    }

    private func launchMainApp() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppBundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }

    private func refreshDeviceListeners() {
        removeDeviceListeners()

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: kAudioObjectUnknown, count: deviceCount)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return
        }

        for deviceID in deviceIDs where deviceID != kAudioObjectUnknown && hasOutputChannels(deviceID) {
            addRunningListener(for: deviceID)
            monitoredDeviceIDs.insert(deviceID)
        }
    }

    private func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return false
        }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        ) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private func addSystemListeners() {
        addListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        addListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )
    }

    private func addRunningListener(for deviceID: AudioDeviceID) {
        addListener(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceIsRunningSomewhere
        )
    }

    private func removeDeviceListeners() {
        for deviceID in monitoredDeviceIDs {
            removeListener(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceIsRunningSomewhere
            )
        }
        monitoredDeviceIDs.removeAll()
    }

    private func addListener(objectID: AudioObjectID, selector: AudioObjectPropertySelector) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(
            objectID,
            &propertyAddress,
            Self.propertyListener,
            clientData
        )
    }

    private func removeListener(objectID: AudioObjectID, selector: AudioObjectPropertySelector) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(
            objectID,
            &propertyAddress,
            Self.propertyListener,
            clientData
        )
    }

    private static let propertyListener: AudioObjectPropertyListenerProc = { objectID, _, _, clientData in
        guard let clientData else { return noErr }
        let monitor = Unmanaged<PlaybackLaunchMonitor>.fromOpaque(clientData).takeUnretainedValue()

        if objectID == AudioObjectID(kAudioObjectSystemObject) {
            monitor.refreshDeviceListeners()
        }
        monitor.evaluateLaunchConditions()

        return noErr
    }
}

let monitor = PlaybackLaunchMonitor()
monitor.start()
RunLoop.main.run()
