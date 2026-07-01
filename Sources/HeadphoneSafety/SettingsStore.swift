import Foundation
import HeadphoneSafetyCore

@MainActor
final class SettingsStore: ObservableObject {
    enum Keys {
        static let protectionEnabled = "protectionEnabled"
        static let volumeCeiling = "volumeCeiling"
    }

    @Published var protectionEnabled: Bool {
        didSet { defaults.set(protectionEnabled, forKey: Keys.protectionEnabled) }
    }

    @Published var volumeCeiling: Double {
        didSet {
            let clamped = max(0, min(1, volumeCeiling))
            if volumeCeiling != clamped {
                volumeCeiling = clamped
                return
            }
            defaults.set(volumeCeiling, forKey: Keys.volumeCeiling)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        protectionEnabled = defaults.object(forKey: Keys.protectionEnabled) as? Bool ?? VolumeLimitSettings.defaultProtectionEnabled
        volumeCeiling = defaults.object(forKey: Keys.volumeCeiling) as? Double ?? VolumeLimitSettings.defaultCeiling
    }
}
