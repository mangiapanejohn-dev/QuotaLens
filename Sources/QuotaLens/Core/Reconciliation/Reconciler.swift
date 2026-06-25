import Foundation

/// Merges authoritative official readings into local usage records.
/// Official overrides the displayed percentage / limit / reset; local keeps
/// providing tokens, cost and trend. Official is truth — never the reverse.
enum Reconciler {
    static func reconcile(
        local: [ToolUsage],
        official: [WindowType: OfficialReading]
    ) -> [ToolUsage] {
        local.map { usage in
            var merged = usage
            if let reading = official[usage.windowType] {
                merged.official = reading
            }
            return merged
        }
    }
}
