import Foundation

/// One day's aggregated usage for one tool (historical analytics).
struct DailyStat: Codable, Sendable {
    let day: Date            // start-of-day
    let toolName: String
    var input: Double
    var output: Double
    var cacheCreate: Double
    var cacheRead: Double
    var costUSD: Double
    var requests: Int

    var total: Double { input + output + cacheCreate + cacheRead }
}

/// All-time totals over a selected tool filter.
struct StatsSummary: Sendable {
    var totalTokens: Double = 0
    var input: Double = 0
    var output: Double = 0
    var cacheCreate: Double = 0
    var cacheRead: Double = 0
    var costUSD: Double = 0
    var requests: Int = 0

    /// Share of cacheable input served from cache.
    var cacheHitRate: Double {
        let denom = input + cacheCreate + cacheRead
        return denom > 0 ? cacheRead / denom : 0
    }

    static let empty = StatsSummary()
}

/// One trend-chart series.
struct TrendSeries: Identifiable, Sendable {
    let id: String
    let label: String
    let points: [TrendPoint]
    let isCost: Bool          // plotted against the secondary ($) axis
}

struct TrendPoint: Sendable {
    let day: Date
    let value: Double
}
