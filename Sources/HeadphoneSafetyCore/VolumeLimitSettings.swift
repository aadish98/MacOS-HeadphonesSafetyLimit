import Foundation

public enum VolumeLimitSettings {
    public static let defaultCeiling = 0.40
    public static let defaultProtectionEnabled = true

    /// 10%-40% maps to 75-85 dB; 40%-100% maps to 85-100 dB.
    public static func estimatedDB(forVolumeCeiling ceiling: Double) -> Int {
        let value: Double
        if ceiling <= defaultCeiling {
            let normalized = (ceiling - 0.1) / 0.3
            value = 75 + 10 * max(0, min(1, normalized))
        } else {
            let normalized = (ceiling - defaultCeiling) / 0.6
            value = 85 + 15 * max(0, min(1, normalized))
        }
        return Int(value.rounded())
    }
}
