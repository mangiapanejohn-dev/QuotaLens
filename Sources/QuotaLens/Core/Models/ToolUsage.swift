import Foundation

/// The usage windows QuotaLens tracks. New windows can be added here.
enum WindowType: String, CaseIterable, Codable, Sendable, Identifiable {
    case fiveHour = "5h"
    case sevenDay = "7d"
    case session

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveHour: return "5-Hour"
        case .sevenDay: return "7-Day"
        case .session: return "Session"
        }
    }

    /// Window length in seconds (session has no fixed length).
    var duration: TimeInterval? {
        switch self {
        case .fiveHour: return 5 * 3600
        case .sevenDay: return 7 * 24 * 3600
        case .session: return nil
        }
    }
}

/// Severity buckets used for colour + notifications.
enum ThresholdLevel: Int, Comparable, Sendable {
    case neutral = 0    // < 70%
    case warning = 1    // 70–90%
    case critical = 2   // > 90%

    static func < (lhs: ThresholdLevel, rhs: ThresholdLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(ratio: Double) {
        switch ratio {
        case ..<0.70: self = .neutral
        case ..<0.90: self = .warning
        default: self = .critical
        }
    }
}

/// Unified usage record for one tool × one window. Carries BOTH the local
/// estimate (usedTokens/limitTokens) and, when available, the authoritative
/// `official` reading. Official always wins for display — official is truth.
struct ToolUsage: Identifiable, Sendable, Codable {
    let toolName: String        // "claude-code", "codex"
    let windowType: WindowType
    var usedTokens: Double      // local estimate
    var limitTokens: Double     // local baseline (denominator)
    var lastUpdated: Date

    /// Local block-reset time (5h block mode); official reset lives on `official`.
    var localResetsAt: Date?
    /// Estimated spend in USD for this window (secondary display).
    var costUSD: Double
    /// Authoritative reading (Codex file / Claude probe). nil → local only.
    var official: OfficialReading?

    var id: String { "\(toolName)-\(windowType.rawValue)" }

    /// Local estimate ratio (tokens ÷ baseline).
    var localRatio: Double {
        guard limitTokens > 0 else { return 0 }
        return usedTokens / limitTokens
    }

    /// Display ratio: official wins; otherwise the local estimate.
    var usageRatio: Double {
        if let p = official?.percent { return min(max(p, 0), 2) }
        return localRatio
    }

    /// Reset time to display: official first, else local block reset.
    var effectiveResetsAt: Date? { official?.resetsAt ?? localResetsAt }

    /// Diagnostics: local − official (signed). nil when no official reading.
    var delta: Double? {
        guard let p = official?.percent else { return nil }
        return localRatio - p
    }

    var level: ThresholdLevel { ThresholdLevel(ratio: usageRatio) }

    init(
        toolName: String,
        windowType: WindowType,
        usedTokens: Double,
        limitTokens: Double,
        lastUpdated: Date,
        localResetsAt: Date? = nil,
        costUSD: Double = 0,
        official: OfficialReading? = nil
    ) {
        self.toolName = toolName
        self.windowType = windowType
        self.usedTokens = usedTokens
        self.limitTokens = limitTokens
        self.lastUpdated = lastUpdated
        self.localResetsAt = localResetsAt
        self.costUSD = costUSD
        self.official = official
    }
}

/// One billable model interaction, the atom the aggregator works on.
struct UsageEvent: Sendable, Codable, Hashable {
    let timestamp: Date
    let sessionId: String
    let model: String
    let inputTokens: Double
    let outputTokens: Double
    let cacheCreationTokens: Double
    let cacheReadTokens: Double
    /// Stable identity for de-duplication across resumed/forked sessions.
    let dedupeKey: String

    var totalTokens: Double {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    /// Tokens that meaningfully count toward quota. Cache *reads* are ~10x
    /// cheaper and dominate raw counts, so they are excluded from the
    /// percentage / trend measure (cost still uses the full breakdown).
    var quotaTokens: Double {
        inputTokens + outputTokens + cacheCreationTokens
    }
}
