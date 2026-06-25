import Foundation
import UserNotifications

/// Fires threshold notifications (80 / 90 / 100%), de-duplicated per
/// tool × window × threshold × reset-cycle so each alert shows once.
@MainActor
final class NotificationService {
    private var fired: Set<String> = []
    private let available: Bool

    init() {
        // UNUserNotificationCenter requires a bundle identifier (a real .app).
        available = Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Notify once when a token-based account's token expires; re-arm on recovery
    /// so a future expiry alerts again. `snapshots` should be enabled-filtered.
    func evaluateExpiry(snapshots: [ToolSnapshot]) {
        guard available else { return }
        for snap in snapshots {
            let key = "expired:\(snap.toolName)"
            if snap.expired {
                if fired.insert(key).inserted { postExpiry(tool: snap.displayName) }
            } else {
                fired.remove(key)
            }
        }
    }

    private func postExpiry(tool: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(tool) — token expired"
        content.body = "Run `claude setup-token` and paste the new token in Settings."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// `snapshots` should already be filtered to enabled tools.
    func evaluate(snapshots: [ToolSnapshot]) {
        guard available else { return }
        for snap in snapshots {
            for window in [WindowType.fiveHour, .sevenDay] {
                guard let usage = snap.usage(window) else { continue }
                let pct = usage.usageRatio * 100
                let cycle = usage.effectiveResetsAt.map { Int($0.timeIntervalSince1970) } ?? 0
                for threshold in [80, 90, 100] where pct >= Double(threshold) {
                    let key = "\(snap.toolName):\(window.rawValue):\(threshold):\(cycle)"
                    if fired.insert(key).inserted {
                        post(tool: snap.displayName, window: window, threshold: threshold)
                    }
                }
            }
        }
    }

    private func post(tool: String, window: WindowType, threshold: Int) {
        let content = UNMutableNotificationContent()
        switch threshold {
        case 100:
            content.title = "\(tool) — limit reached"
            content.body = "\(window.displayName) usage hit 100%."
        case 90:
            content.title = "\(tool) — critical usage"
            content.body = "\(window.displayName) usage above 90%."
        default:
            content.title = "\(tool) — high usage"
            content.body = "\(window.displayName) usage above 80%."
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
