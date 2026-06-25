import Foundation

/// Everything the UI needs to render one tool, produced each poll.
struct ToolSnapshot: Codable, Sendable, Identifiable {
    let toolName: String
    let displayName: String
    var usages: [ToolUsage]
    var hourlyBuckets: [Double]
    var available: Bool
    var updatedAt: Date
    /// Reset times (within the timeline window) to mark on the chart.
    var resetMarkers: [Date] = []
    /// Token expired (auth failed) — for token-based Claude accounts. Re-paste needed.
    var expired: Bool = false

    var id: String { toolName }

    /// Whether this tool carries a local estimate (vs official-only accounts).
    var hasLocalEstimate: Bool { usages.contains { $0.usedTokens > 0 } }

    /// Position (0…1) of each reset marker across the last `hours`, for the chart.
    func resetMarkerPositions(hours: Int, now: Date = Date()) -> [Double] {
        let span = Double(hours) * 3600
        guard span > 0 else { return [] }
        return resetMarkers.compactMap { date in
            let age = now.timeIntervalSince(date)
            guard age >= 0, age <= span else { return nil }
            return 1 - age / span
        }
    }

    func usage(_ window: WindowType) -> ToolUsage? {
        usages.first { $0.windowType == window }
    }

    /// Highest ratio across the two capacity windows (5h, 7d) — drives colour.
    var headlineRatio: Double {
        [WindowType.fiveHour, .sevenDay]
            .compactMap { usage($0)?.usageRatio }
            .max() ?? 0
    }
}
