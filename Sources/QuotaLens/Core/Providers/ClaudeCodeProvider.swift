import Foundation

/// Reads real Claude Code usage from `~/.claude/projects/**/*.jsonl`.
/// Claude does not write server-side limits, so percentages are computed
/// against the configured `PlanBaseline`.
actor ClaudeCodeProvider: UsageProvider {
    nonisolated let toolName = "claude-code"
    nonisolated let displayName = "Claude Code"

    private var config: ProviderConfig
    private var events: [String: UsageEvent] = [:]
    private var offsets: [String: UInt64] = [:]
    private let rootURL: URL

    init(config: ProviderConfig, root: URL? = nil) {
        self.config = config
        self.rootURL = root ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    func update(config: ProviderConfig) { self.config = config }

    func fetchUsage() -> [ToolUsage] {
        ingest()
        prune()
        return UsageAggregator.aggregate(
            events: Array(events.values),
            toolName: toolName,
            now: Date(),
            baseline5h: config.claudeBaseline.fiveHour,
            baseline7d: config.claudeBaseline.sevenDay,
            mode: config.fiveHourMode
        )
    }

    func recentHourlyBuckets(hours: Int) -> [Double] {
        UsageAggregator.hourlyBuckets(Array(events.values), now: Date(), hours: hours)
    }

    func latestActivity() -> Date? {
        events.values.map(\.timestamp).max()
    }

    // MARK: - Ingestion

    private func ingest() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for file in jsonlFiles(modifiedAfter: cutoff) {
            let path = file.path
            let (lines, newOffset) = IncrementalFileReader.readNewLines(
                path: path, from: offsets[path] ?? 0)
            offsets[path] = newOffset
            for line in lines {
                if let event = ClaudeJSONLParser.parse(line: line) {
                    events[event.dedupeKey] = event
                }
            }
        }
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        events = events.filter { $0.value.timestamp >= cutoff }
    }

    /// `~/.claude/projects/<project>/<session>.jsonl`, modified within 7 days.
    private func jsonlFiles(modifiedAfter cutoff: Date) -> [URL] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: rootURL, includingPropertiesForKeys: nil) else { return [] }
        var out: [URL] = []
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                let mod = (try? file.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                if mod >= cutoff { out.append(file) }
            }
        }
        return out
    }
}
