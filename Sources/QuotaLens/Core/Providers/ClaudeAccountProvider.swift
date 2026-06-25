import Foundation

/// A Claude account's local-tracking side. Pasted-token accounts have no
/// attributable local logs (`~/.claude/projects` belongs to the CLI login, not
/// a specific token), so this carries no local usage — it only emits empty 5h/7d
/// shells for `Reconciler` to attach the account's official probe readings onto.
struct ClaudeAccountProvider: UsageProvider {
    let toolName: String
    let displayName: String

    init(account: ClaudeAccount) {
        self.toolName = account.toolName
        self.displayName = account.name
    }

    func update(config: ProviderConfig) {}

    func fetchUsage() -> [ToolUsage] {
        let now = Date()
        return [
            ToolUsage(toolName: toolName, windowType: .fiveHour,
                      usedTokens: 0, limitTokens: 0, lastUpdated: now),
            ToolUsage(toolName: toolName, windowType: .sevenDay,
                      usedTokens: 0, limitTokens: 0, lastUpdated: now),
        ]
    }

    func recentHourlyBuckets(hours: Int) -> [Double] { [] }

    func latestActivity() -> Date? { nil }
}
