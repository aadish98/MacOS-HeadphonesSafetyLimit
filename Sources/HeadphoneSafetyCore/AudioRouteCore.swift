import CoreAudio
import Foundation

public enum AudioRouteKind: String {
    case builtInSpeakers = "Built-in Speakers"
    case wiredHeadphones = "Wired Headphones"
    case bluetoothHeadphones = "Bluetooth Headphones"
    case usbHeadphones = "USB Headphones"
    case other = "Other Output"
    case unavailable = "Unavailable"

    public var isLimited: Bool {
        switch self {
        case .builtInSpeakers, .unavailable:
            return false
        case .wiredHeadphones, .bluetoothHeadphones, .usbHeadphones, .other:
            return true
        }
    }
}

public enum AudioRouteCore {
    public static func defaultOutputDeviceID() -> AudioDeviceID? {
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

    public static func routeKind(for deviceID: AudioDeviceID) -> AudioRouteKind {
        let deviceName = readDeviceName(for: deviceID) ?? "Unknown Output"
        let transportType = readUInt32Property(
            kAudioDevicePropertyTransportType,
            objectID: deviceID,
            scope: kAudioObjectPropertyScopeGlobal
        )
        return routeKind(for: deviceID, deviceName: deviceName, transportType: transportType)
    }

    public static func isDefaultOutputLimited() -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        return routeKind(for: deviceID).isLimited
    }

    public static func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }

        var isRunning = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &isRunning
        )

        guard status == noErr else { return false }
        return isRunning != 0
    }

    public static func shouldLaunchProtectionApp(isMainAppRunning: Bool) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        return shouldLaunchProtectionApp(
            isMainAppRunning: isMainAppRunning,
            isDefaultOutputLimited: routeKind(for: deviceID).isLimited,
            isDefaultOutputRunning: isDeviceRunning(deviceID)
        )
    }

    public static func shouldLaunchProtectionApp(
        isMainAppRunning: Bool,
        isDefaultOutputLimited: Bool,
        isDefaultOutputRunning: Bool
    ) -> Bool {
        guard !isMainAppRunning else { return false }
        guard isDefaultOutputLimited else { return false }
        return isDefaultOutputRunning
    }

    public static func routeKind(
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

    private static func readDeviceName(for deviceID: AudioDeviceID) -> String? {
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

    private static func currentOutputDataSourceName(for deviceID: AudioDeviceID) -> String? {
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

    private static func readUInt32Property(
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
}
