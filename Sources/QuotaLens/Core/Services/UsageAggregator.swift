import Foundation

/// How the 5-hour window is interpreted.
enum FiveHourMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case block      // Claude-style: 5h block that resets as a unit
    case sliding    // rolling past-5h sum

    var id: String { rawValue }
    var displayName: String { self == .block ? "Block (reset)" : "Sliding" }
}

/// Pure functions that turn raw events into windowed `ToolUsage` values.
/// Stateless and fully unit-testable.
enum UsageAggregator {

    static let blockLength: TimeInterval = 5 * 3600

    /// De-duplicate by `dedupeKey`, keeping the first occurrence.
    static func deduplicate(_ events: [UsageEvent]) -> [UsageEvent] {
        var seen = Set<String>()
        var out: [UsageEvent] = []
        out.reserveCapacity(events.count)
        for e in events where seen.insert(e.dedupeKey).inserted {
            out.append(e)
        }
        return out
    }

    /// Sum of total tokens for events at/after `since`.
    static func slidingTokens(_ events: [UsageEvent], since: Date) -> Double {
        events.lazy.filter { $0.timestamp >= since }.reduce(0) { $0 + $1.quotaTokens }
    }

    static func cost(_ events: [UsageEvent], since: Date) -> Double {
        events.lazy.filter { $0.timestamp >= since }.reduce(0) { $0 + Pricing.cost(for: $1) }
    }

    /// The currently-active 5h block: `(start, tokens, cost)`.
    /// A new block begins on the first event after a gap ≥ 5h. The active block
    /// is the last one if `now` is still inside `start + 5h`; otherwise empty.
    static func activeBlock(_ events: [UsageEvent], now: Date) -> (start: Date, tokens: Double, cost: Double)? {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first else { return nil }

        var blockStart = first.timestamp
        var tokens = 0.0
        var cost = 0.0
        for e in sorted {
            if e.timestamp >= blockStart + blockLength {
                // start a fresh block at this event
                blockStart = e.timestamp
                tokens = 0
                cost = 0
            }
            tokens += e.quotaTokens
            cost += Pricing.cost(for: e)
        }
        // Has the latest block already expired relative to `now`?
        if now >= blockStart + blockLength {
            return (blockStart, 0, 0)
        }
        return (blockStart, tokens, cost)
    }

    /// Build the 5h / 7d / session usage trio for one tool.
    static func aggregate(
        events rawEvents: [UsageEvent],
        toolName: String,
        now: Date,
        baseline5h: Double,
        baseline7d: Double,
        mode: FiveHourMode
    ) -> [ToolUsage] {
        let events = deduplicate(rawEvents)

        // 5h
        let fiveHour: ToolUsage
        switch mode {
        case .sliding:
            let since = now.addingTimeInterval(-blockLength)
            fiveHour = ToolUsage(
                toolName: toolName, windowType: .fiveHour,
                usedTokens: slidingTokens(events, since: since),
                limitTokens: baseline5h, lastUpdated: now,
                localResetsAt: nil, costUSD: cost(events, since: since)
            )
        case .block:
            if let b = activeBlock(events, now: now) {
                fiveHour = ToolUsage(
                    toolName: toolName, windowType: .fiveHour,
                    usedTokens: b.tokens, limitTokens: baseline5h, lastUpdated: now,
                    localResetsAt: b.start + blockLength, costUSD: b.cost
                )
            } else {
                fiveHour = ToolUsage(
                    toolName: toolName, windowType: .fiveHour,
                    usedTokens: 0, limitTokens: baseline5h, lastUpdated: now
                )
            }
        }

        // 7d (rolling)
        let weekSince = now.addingTimeInterval(-7 * 24 * 3600)
        let sevenDay = ToolUsage(
            toolName: toolName, windowType: .sevenDay,
            usedTokens: slidingTokens(events, since: weekSince),
            limitTokens: baseline7d, lastUpdated: now,
            costUSD: cost(events, since: weekSince)
        )

        // session: the most-recently-active session's cumulative tokens.
        let session: ToolUsage
        if let latest = events.max(by: { $0.timestamp < $1.timestamp }) {
            let sid = latest.sessionId
            let sEvents = events.filter { $0.sessionId == sid }
            session = ToolUsage(
                toolName: toolName, windowType: .session,
                usedTokens: sEvents.reduce(0) { $0 + $1.quotaTokens },
                limitTokens: baseline5h, lastUpdated: now,
                costUSD: sEvents.reduce(0) { $0 + Pricing.cost(for: $1) }
            )
        } else {
            session = ToolUsage(
                toolName: toolName, windowType: .session,
                usedTokens: 0, limitTokens: baseline5h, lastUpdated: now
            )
        }

        return [fiveHour, sevenDay, session]
    }

    /// Token totals bucketed by hour over the last `hours`, oldest → newest.
    static func hourlyBuckets(_ rawEvents: [UsageEvent], now: Date, hours: Int) -> [Double] {
        let events = deduplicate(rawEvents)
        var buckets = [Double](repeating: 0, count: hours)
        let start = now.addingTimeInterval(-Double(hours) * 3600)
        for e in events where e.timestamp >= start && e.timestamp <= now {
            let idx = Int(e.timestamp.timeIntervalSince(start) / 3600)
            if idx >= 0 && idx < hours { buckets[idx] += e.quotaTokens }
        }
        return buckets
    }
}
