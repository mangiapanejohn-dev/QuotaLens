import Foundation

/// Synthetic usage for development / previews. Registered only when the
/// `QUOTALENS_MOCK=1` environment variable is set (see `QuotaLensApp`).
struct MockProvider: UsageProvider {
    let toolName = "mock"
    let displayName = "Mock Tool"

    func update(config: ProviderConfig) {}

    func fetchUsage() -> [ToolUsage] {
        let now = Date()
        // Slowly oscillating values so the UI visibly animates.
        let phase = now.timeIntervalSince1970 / 120
        let r5 = 0.55 + 0.4 * abs(sin(phase))
        let r7 = 0.30 + 0.2 * abs(cos(phase / 3))

        return [
            ToolUsage(toolName: toolName, windowType: .fiveHour,
                      usedTokens: r5 * 35_000_000, limitTokens: 35_000_000,
                      lastUpdated: now, localResetsAt: now.addingTimeInterval(3 * 3600),
                      costUSD: r5 * 42),
            ToolUsage(toolName: toolName, windowType: .sevenDay,
                      usedTokens: r7 * 250_000_000, limitTokens: 250_000_000,
                      lastUpdated: now, costUSD: r7 * 310),
            ToolUsage(toolName: toolName, windowType: .session,
                      usedTokens: 2_400_000, limitTokens: 35_000_000,
                      lastUpdated: now, costUSD: 3.1),
        ]
    }

    func recentHourlyBuckets(hours: Int) -> [Double] {
        (0..<hours).map { i in
            let x = Double(i) / Double(max(hours - 1, 1))
            return 1_500_000 * (0.4 + abs(sin(x * 6)))
        }
    }

    func latestActivity() -> Date? { Date() }
}
