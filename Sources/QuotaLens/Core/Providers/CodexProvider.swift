import Foundation

/// Reads real Codex CLI usage from `~/.codex/sessions/**/rollout-*.jsonl`.
/// Codex writes authoritative `used_percent` + `resets_at` for the 5h (primary)
/// and 7d (secondary) windows, so those are used verbatim — no baseline guessing.
actor CodexProvider: UsageProvider, OfficialSource {
    nonisolated let toolName = "codex"
    nonisolated let displayName = "Codex CLI"

    private var config: ProviderConfig
    private var events: [String: UsageEvent] = [:]
    private var offsets: [String: UInt64] = [:]
    private var latestSnapshot: CodexRateSnapshot?
    private let rootURL: URL

    /// Cosmetic reference for the (non-authoritative) session bar only.
    private let nominalSessionBaseline = 5_000_000.0

    init(config: ProviderConfig, root: URL? = nil) {
        self.config = config
        self.rootURL = root ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
    }

    func update(config: ProviderConfig) { self.config = config }

    /// Local estimate only — official readings come via `officialReadings`.
    func fetchUsage() -> [ToolUsage] {
        ingest()
        prune()

        let now = Date()
        let all = Array(events.values)
        let fiveSince = now.addingTimeInterval(-5 * 3600)
        let weekSince = now.addingTimeInterval(-7 * 24 * 3600)

        let fiveHour = ToolUsage(
            toolName: toolName, windowType: .fiveHour,
            usedTokens: UsageAggregator.slidingTokens(all, since: fiveSince),
            limitTokens: nominalSessionBaseline, lastUpdated: now,
            costUSD: UsageAggregator.cost(all, since: fiveSince)
        )

        let sevenDay = ToolUsage(
            toolName: toolName, windowType: .sevenDay,
            usedTokens: UsageAggregator.slidingTokens(all, since: weekSince),
            limitTokens: nominalSessionBaseline * 7, lastUpdated: now,
            costUSD: UsageAggregator.cost(all, since: weekSince)
        )

        let session: ToolUsage
        if let latest = all.max(by: { $0.timestamp < $1.timestamp }) {
            let sEvents = all.filter { $0.sessionId == latest.sessionId }
            session = ToolUsage(
                toolName: toolName, windowType: .session,
                usedTokens: sEvents.reduce(0) { $0 + $1.quotaTokens },
                limitTokens: nominalSessionBaseline, lastUpdated: now,
                costUSD: sEvents.reduce(0) { $0 + Pricing.cost(for: $1) }
            )
        } else {
            session = ToolUsage(
                toolName: toolName, windowType: .session,
                usedTokens: 0, limitTokens: nominalSessionBaseline, lastUpdated: now
            )
        }

        return [fiveHour, sevenDay, session]
    }

    func recentHourlyBuckets(hours: Int) -> [Double] {
        UsageAggregator.hourlyBuckets(Array(events.values), now: Date(), hours: hours)
    }

    func latestActivity() -> Date? {
        events.values.map(\.timestamp).max()
    }

    // MARK: - OfficialSource (no network — parsed from rollout files)

    func officialReadings(now: Date, latestActivity: Date?) -> [WindowType: OfficialReading] {
        ingest()
        guard let snap = latestSnapshot else { return [:] }
        var out: [WindowType: OfficialReading] = [:]
        if let r = reading(percent: snap.primaryPercent, resetsAt: snap.primaryResetsAt,
                           fetchedAt: snap.timestamp, now: now) {
            out[.fiveHour] = r
        }
        if let r = reading(percent: snap.secondaryPercent, resetsAt: snap.secondaryResetsAt,
                           fetchedAt: snap.timestamp, now: now) {
            out[.sevenDay] = r
        }
        return out
    }

    /// Build a reading; if the window already reset (resetsAt past), report 0%.
    private func reading(percent: Double?, resetsAt: Date?, fetchedAt: Date, now: Date) -> OfficialReading? {
        guard let percent else { return nil }
        if let resetsAt, resetsAt < now {
            return OfficialReading(percent: 0, resetsAt: nil, source: .codexFile, fetchedAt: fetchedAt)
        }
        return OfficialReading(percent: percent / 100, resetsAt: resetsAt,
                               source: .codexFile, fetchedAt: fetchedAt)
    }

    // MARK: - Ingestion

    private func ingest() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for file in jsonlFiles(modifiedAfter: cutoff) {
            let path = file.path
            let sessionId = file.deletingPathExtension().lastPathComponent
            let (lines, newOffset) = IncrementalFileReader.readNewLines(
                path: path, from: offsets[path] ?? 0)
            offsets[path] = newOffset
            for line in lines {
                guard let parsed = CodexJSONLParser.parse(line: line, sessionId: sessionId)
                else { continue }
                if let event = parsed.event { events[event.dedupeKey] = event }
                if let snap = parsed.snapshot {
                    if let current = latestSnapshot {
                        if snap.timestamp > current.timestamp { latestSnapshot = snap }
                    } else {
                        latestSnapshot = snap
                    }
                }
            }
        }
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        events = events.filter { $0.value.timestamp >= cutoff }
    }

    /// Recursively find `rollout-*.jsonl` modified within 7 days.
    private func jsonlFiles(modifiedAfter cutoff: Date) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        var out: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            if mod >= cutoff { out.append(url) }
        }
        return out
    }
}
