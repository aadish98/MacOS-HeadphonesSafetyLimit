import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static let monitorBundleIdentifier = "com.aadishms.HeadphoneSafetyLimit.monitor"

    static func registerMonitorIfNeeded() {
        let service = SMAppService.loginItem(identifier: monitorBundleIdentifier)
        guard service.status != .enabled else { return }

        do {
            try service.register()
        } catch {
            // The monitor is optional at runtime; manual app launch still works.
        }
    }
}
