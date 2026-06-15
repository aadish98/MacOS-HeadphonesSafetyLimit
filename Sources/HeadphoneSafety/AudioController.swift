import CoreAudio
import Foundation

enum AudioRouteKind: String {
    case builtInSpeakers = "Built-in Speakers"
    case wiredHeadphones = "Wired Headphones"
    case bluetoothHeadphones = "Bluetooth Headphones"
    case usbHeadphones = "USB Headphones"
    case other = "Other Output"
    case unavailable = "Unavailable"
}

struct AudioRouteState {
    let deviceID: AudioDeviceID
    let deviceName: String
    let kind: AudioRouteKind
    let isHeadphones: Bool
    let currentVolume: Double?
    let canSetVolume: Bool

    // Protection applies to every output except the built-in MacBook speakers.
    var isLimited: Bool {
        switch kind {
        case .builtInSpeakers, .unavailable:
            return false
        case .wiredHeadphones, .bluetoothHeadphones, .usbHeadphones, .other:
            return true
        }
    }

    static let unavailable = AudioRouteState(
        deviceID: kAudioObjectUnknown,
        deviceName: "No Output Device",
        kind: .unavailable,
        isHeadphones: false,
        currentVolume: nil,
        canSetVolume: false
    )
}

@MainActor
final class AudioController: ObservableObject {
    @Published private(set) var route: AudioRouteState = .unavailable
    @Published private(set) var statusMessage = "Starting audio monitor..."
    @Published var protectionEnabled = true {
        didSet { enforceVolumeCeilingIfNeeded(reason: "settings changed") }
    }
    @Published var volumeCeiling = 0.55 {
        didSet {
            let clamped = max(0, min(1, volumeCeiling))
            if volumeCeiling != clamped {
                volumeCeiling = clamped
                return
            }
            enforceVolumeCeilingIfNeeded(reason: "ceiling changed")
        }
    }
    private var activeDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumeListenerDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isApplyingVolumeClamp = false
    private var monitorTimer: Timer?
    private let clampTolerance = 0.02
    private var clientData: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    init() {
        addSystemListeners()
        refreshRoute(rebindVolumeListener: true)
        startMonitorTimer()
    }

    private func startMonitorTimer() {
        monitorTimer?.invalidate()
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reevaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer
    }

    private func reevaluate() {
        guard activeDeviceID != kAudioObjectUnknown else { return }

        let newState = makeRouteState(for: activeDeviceID)
        if newState.currentVolume != route.currentVolume
            || newState.deviceID != route.deviceID
            || newState.canSetVolume != route.canSetVolume {
            route = newState
            statusMessage = routeStatus(for: route)
        }

        enforceVolumeCeilingIfNeeded(reason: "monitor")
    }

    func refreshRoute(rebindVolumeListener: Bool) {
        guard let deviceID = defaultOutputDeviceID() else {
            activeDeviceID = kAudioObjectUnknown
            route = .unavailable
            statusMessage = "No output device is currently available."
            removeVolumeListener()
            return
        }

        if rebindVolumeListener, deviceID != volumeListenerDeviceID {
            removeVolumeListener()
            addVolumeListener(for: deviceID)
        }

        activeDeviceID = deviceID
        route = makeRouteState(for: deviceID)
        statusMessage = routeStatus(for: route)
        enforceVolumeCeilingIfNeeded(reason: rebindVolumeListener ? "route changed" : "volume changed")
    }

    func setOutputVolume(_ scalar: Double) {
        guard activeDeviceID != kAudioObjectUnknown else { return }
        let clampedScalar = Float32(max(0, min(1, scalar)))

        if setVolume(clampedScalar, for: activeDeviceID, element: kAudioObjectPropertyElementMain) {
            refreshRoute(rebindVolumeListener: false)
            return
        }

        var didSetAnyChannel = false
        for element in [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)] {
            didSetAnyChannel = setVolume(clampedScalar, for: activeDeviceID, element: element) || didSetAnyChannel
        }

        if didSetAnyChannel {
            refreshRoute(rebindVolumeListener: false)
        }
    }

    func apply(settings: SettingsStore) {
        protectionEnabled = settings.protectionEnabled
        volumeCeiling = settings.volumeCeiling
        enforceVolumeCeilingIfNeeded(reason: "settings applied")
    }

    func enforceVolumeCeilingIfNeeded(reason: String = "volume changed") {
        guard !isApplyingVolumeClamp else { return }
        guard protectionEnabled else { return }
        guard route.isLimited else { return }
        guard let currentVolume = route.currentVolume else { return }
        guard currentVolume > volumeCeiling + clampTolerance else { return }

        guard route.canSetVolume else {
            statusMessage = "\(route.deviceName) is above the ceiling, but macOS reports its volume as read-only."
            return
        }

        isApplyingVolumeClamp = true
        setOutputVolume(volumeCeiling)
        isApplyingVolumeClamp = false

        statusMessage = "Reduced \(route.deviceName) to \(Int((volumeCeiling * 100).rounded()))% (\(reason))."
    }

    private func makeRouteState(for deviceID: AudioDeviceID) -> AudioRouteState {
        let deviceName = readDeviceName(for: deviceID) ?? "Unknown Output"
        let transportType = readUInt32Property(
            kAudioDevicePropertyTransportType,
            objectID: deviceID,
            scope: kAudioObjectPropertyScopeGlobal
        )

        let kind = routeKind(for: deviceID, deviceName: deviceName, transportType: transportType)
        let volume = readOutputVolume(for: deviceID)
        let canSetVolume = canSetOutputVolume(for: deviceID)

        return AudioRouteState(
            deviceID: deviceID,
            deviceName: deviceName,
            kind: kind,
            isHeadphones: kind == .wiredHeadphones || kind == .bluetoothHeadphones || kind == .usbHeadphones,
            currentVolume: volume.map(Double.init),
            canSetVolume: canSetVolume
        )
    }

    private func routeKind(
        for deviceID: AudioDeviceID,
        deviceName: String,
        transportType: UInt32?
    ) -> AudioRouteKind {
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetoothHeadphones
        case kAudioDeviceTransportTypeUSB:
            return .usbHeadphones
        case kAudioDeviceTransportTypeBuiltIn:
            if let sourceName = currentOutputDataSourceName(for: deviceID),
               sourceName.localizedCaseInsensitiveContains("headphone") {
                return .wiredHeadphones
            }

            return .builtInSpeakers
        default:
            let lowercasedName = deviceName.lowercased()
            if lowercasedName.contains("headphone")
                || lowercasedName.contains("airpods")
                || lowercasedName.contains("earbuds")
                || lowercasedName.contains("earphones") {
                return .bluetoothHeadphones
            }

            return .other
        }
    }

    private func routeStatus(for route: AudioRouteState) -> String {
        if route.kind == .unavailable {
            return "No output device is currently available."
        }

        let volumeDescription = route.currentVolume.map { "\(Int(($0 * 100).rounded()))%" } ?? "unknown volume"
        let capability = route.canSetVolume ? "controllable" : "read-only"
        return "\(route.deviceName) · \(route.kind.rawValue) · \(volumeDescription) · \(capability)"
    }
}

private extension AudioController {
    static let audioPropertyListener: AudioObjectPropertyListenerProc = { objectID, _, _, clientData in
        guard let clientData else { return noErr }
        let controller = Unmanaged<AudioController>.fromOpaque(clientData).takeUnretainedValue()

        Task { @MainActor in
        if objectID == AudioObjectID(kAudioObjectSystemObject) {
                controller.refreshRoute(rebindVolumeListener: true)
            } else {
                controller.refreshRoute(rebindVolumeListener: false)
            }
        }

        return noErr
    }

    func addSystemListeners() {
        addListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        )
        addListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal
        )
    }

    func removeSystemListeners() {
        removeListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        )
        removeListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal
        )
    }

    func addVolumeListener(for deviceID: AudioDeviceID) {
        guard deviceID != kAudioObjectUnknown else { return }

        addListener(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementWildcard
        )
        volumeListenerDeviceID = deviceID
    }

    func removeVolumeListener() {
        guard volumeListenerDeviceID != kAudioObjectUnknown else { return }

        removeListener(
            objectID: volumeListenerDeviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementWildcard
        )
        volumeListenerDeviceID = kAudioObjectUnknown
    }

    func addListener(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        AudioObjectAddPropertyListener(
            objectID,
            &propertyAddress,
            Self.audioPropertyListener,
            clientData
        )
    }

    func removeListener(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        AudioObjectRemovePropertyListener(
            objectID,
            &propertyAddress,
            Self.audioPropertyListener,
            clientData
        )
    }
}

private extension AudioController {
    func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    func readDeviceName(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var deviceName: CFString?

        let status = withUnsafeMutableBytes(of: &deviceName) { rawBuffer in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                rawBuffer.baseAddress!
            )
        }

        guard status == noErr, let deviceName else { return nil }
        return deviceName as String
    }

    func currentOutputDataSourceName(for deviceID: AudioDeviceID) -> String? {
        guard let dataSourceID = readUInt32Property(
            kAudioDevicePropertyDataSource,
            objectID: deviceID,
            scope: kAudioDevicePropertyScopeOutput
        ) else {
            return nil
        }

        var mutableDataSourceID = dataSourceID
        var dataSourceName: CFString?
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSourceNameForIDCFString,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status: OSStatus = noErr
        withUnsafeMutablePointer(to: &mutableDataSourceID) { inputPointer in
            withUnsafeMutableBytes(of: &dataSourceName) { outputBuffer in
                var translation = AudioValueTranslation(
                    mInputData: UnsafeMutableRawPointer(inputPointer),
                    mInputDataSize: UInt32(MemoryLayout<UInt32>.size),
                    mOutputData: outputBuffer.baseAddress!,
                    mOutputDataSize: UInt32(MemoryLayout<CFString?>.size)
                )
                var dataSize = UInt32(MemoryLayout<AudioValueTranslation>.size)

                status = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &dataSize,
                    &translation
                )
            }
        }

        guard status == noErr, let dataSourceName else { return nil }
        return dataSourceName as String
    }

    func readUInt32Property(
        _ selector: AudioObjectPropertySelector,
        objectID: AudioObjectID,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            objectID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &value
        )

        guard status == noErr else { return nil }
        return value
    }

    func readOutputVolume(for deviceID: AudioDeviceID) -> Float32? {
        if let mainVolume = readVolume(for: deviceID, element: kAudioObjectPropertyElementMain) {
            return mainVolume
        }

        let channelVolumes = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .compactMap { readVolume(for: deviceID, element: $0) }

        guard !channelVolumes.isEmpty else { return nil }
        return channelVolumes.reduce(0, +) / Float32(channelVolumes.count)
    }

    func readVolume(for deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float32? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var volume = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return nil }

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        guard status == noErr else { return nil }
        return volume
    }

    func canSetOutputVolume(for deviceID: AudioDeviceID) -> Bool {
        if isVolumeSettable(for: deviceID, element: kAudioObjectPropertyElementMain) {
            return true
        }

        return isVolumeSettable(for: deviceID, element: 1)
            || isVolumeSettable(for: deviceID, element: 2)
    }

    func isVolumeSettable(for deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var isSettable = DarwinBoolean(false)

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }

        let status = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    func setVolume(
        _ volume: Float32,
        for deviceID: AudioDeviceID,
        element: AudioObjectPropertyElement
    ) -> Bool {
        guard isVolumeSettable(for: deviceID, element: element) else { return false }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var mutableVolume = volume
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            dataSize,
            &mutableVolume
        )

        return status == noErr
    }
}
