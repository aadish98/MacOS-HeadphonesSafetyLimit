import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum Keys {
        static let protectionEnabled = "protectionEnabled"
        static let volumeCeiling = "volumeCeiling"
        static let applyToWired = "applyToWired"
        static let applyToBluetooth = "applyToBluetooth"
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

    @Published var applyToWired: Bool {
        didSet { defaults.set(applyToWired, forKey: Keys.applyToWired) }
    }

    @Published var applyToBluetooth: Bool {
        didSet { defaults.set(applyToBluetooth, forKey: Keys.applyToBluetooth) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        protectionEnabled = defaults.object(forKey: Keys.protectionEnabled) as? Bool ?? true
        volumeCeiling = defaults.object(forKey: Keys.volumeCeiling) as? Double ?? 0.55
        applyToWired = defaults.object(forKey: Keys.applyToWired) as? Bool ?? true
        applyToBluetooth = defaults.object(forKey: Keys.applyToBluetooth) as? Bool ?? true
    }
}
