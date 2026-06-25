import Foundation

/// Runtime configuration handed to every provider (driven by Settings).
struct ProviderConfig: Sendable {
    var fiveHourMode: FiveHourMode
    var claudeBaseline: PlanBaseline

    static let `default` = ProviderConfig(
        fiveHourMode: .block,
        claudeBaseline: PlanBaseline.defaults(for: .claudeMax5)
    )
}

/// Pluggable ingestion source. Adding a new tool means implementing this and
/// registering one instance — see `ProviderRegistry`.
protocol UsageProvider: Sendable {
    var toolName: String { get }
    var displayName: String { get }
    func update(config: ProviderConfig) async
    func fetchUsage() async -> [ToolUsage]
    func recentHourlyBuckets(hours: Int) async -> [Double]
    /// Timestamp of the most recent local activity, for adaptive sync. nil if none.
    func latestActivity() async -> Date?
}

/// Holds the active providers. New tools plug in here in <10 lines.
@MainActor
final class ProviderRegistry {
    private(set) var providers: [any UsageProvider] = []

    @discardableResult
    func register(_ provider: any UsageProvider) -> ProviderRegistry {
        providers.append(provider)
        return self
    }

    /// Replace the full provider set (Claude accounts are dynamic at runtime).
    func setProviders(_ newProviders: [any UsageProvider]) {
        providers = newProviders
    }

    func provider(named name: String) -> (any UsageProvider)? {
        providers.first { $0.toolName == name }
    }
}
