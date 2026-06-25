import Foundation
import ServiceManagement

/// Launch-at-login via the modern `SMAppService` (macOS 13+). Registers the
/// main app bundle as a login item. Fails closed — a thrown error (e.g. an
/// unsigned build pending user approval) leaves the toggle reflecting reality.
enum LoginItem {
    static var isRegistered: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            switch (enabled, SMAppService.mainApp.status) {
            case (true, let s) where s != .enabled:  try SMAppService.mainApp.register()
            case (false, .enabled):                  try SMAppService.mainApp.unregister()
            default: break
            }
            return true
        } catch {
            return false
        }
    }
}
