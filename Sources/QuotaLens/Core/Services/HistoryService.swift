import Foundation

/// Builds historical usage analytics by scanning every Claude + Codex JSONL
/// once (cheap substring pre-filter + the existing parsers), aggregating per
/// hour × tool, and caching the result. Subsequent loads read only newly
/// appended bytes (per-file offsets), so they are near-instant. Hourly buckets
/// are the base unit; `stats` rolls them up to the requested granularity.
actor HistoryService {
    private var buckets: [String: DailyStat] = [:]    // "tool|hourEpoch" → stat (day = hour start)
    private var offsets: [String: UInt64] = [:]
    private var seenKeys: Set<String> = []            // de-dup resumed/forked messages
    private var loaded = false

    private let claudeRoot: URL
    private let codexRoot: URL
    private let cacheURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeRoot = home.appendingPathComponent(".claude/projects")
        codexRoot = home.appendingPathComponent(".codex/sessions")
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("QuotaLens", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("history.json")
    }

    /// Load cache (if any) then ingest new lines. The first ever call is a full
    /// scan; later calls are incremental.
    func ensureLoaded() {
        if !loaded { loadCache(); loaded = true }
        scan()
        saveCache()
    }

    /// Summary + trend series for a tool filter (nil = all merged), constrained
    /// to `interval` (nil = all-time) and rolled up to `granularity`. `allowed`
    /// limits which tools count at all — so the window stays in sync with the
    /// configured sources (e.g. no Claude account → no Claude history).
    func stats(filter: String?, interval: DateInterval?, granularity: StatsGranularity, allowed: Set<String>)
    -> (summary: StatsSummary, daily: [DailyStat]) {
        let selected = buckets.values.filter {
            allowed.contains($0.toolName) &&
            (filter == nil || $0.toolName == filter) &&
            (interval == nil || interval!.contains($0.day))
        }
        var sum = StatsSummary()
        for s in selected {
            sum.input += s.input; sum.output += s.output
            sum.cacheCreate += s.cacheCreate; sum.cacheRead += s.cacheRead
            sum.costUSD += s.costUSD; sum.requests += s.requests
        }
        sum.totalTokens = sum.input + sum.output + sum.cacheCreate + sum.cacheRead
        return (sum, rollup(selected, granularity: granularity).sorted { $0.day < $1.day })
    }

    // MARK: - Scan

    private func scan() {
        let cal = Calendar.current
        for (root, isClaude) in [(claudeRoot, true), (codexRoot, false)] {
            for file in jsonlFiles(under: root) {
                let path = file.path
                let sid = file.deletingPathExtension().lastPathComponent
                let (lines, newOffset) = IncrementalFileReader.readNewLines(
                    path: path, from: offsets[path] ?? 0)
                offsets[path] = newOffset
                for line in lines {
                    let event: UsageEvent?
                    if isClaude {
                        guard line.contains("\"usage\"") else { continue }
                        event = ClaudeJSONLParser.parse(line: line)
                    } else {
                        guard line.contains("token_count") else { continue }
                        event = CodexJSONLParser.parse(line: line, sessionId: sid)?.event
                    }
                    guard let e = event, seenKeys.insert(e.dedupeKey).inserted else { continue }
                    add(e, tool: isClaude ? "claude-code" : "codex", cal: cal)
                }
            }
        }
    }

    private func add(_ e: UsageEvent, tool: String, cal: Calendar) {
        let hour = cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: e.timestamp))
            ?? e.timestamp
        let key = "\(tool)|\(Int(hour.timeIntervalSince1970))"
        var d = buckets[key] ?? DailyStat(day: hour, toolName: tool,
                                          input: 0, output: 0, cacheCreate: 0,
                                          cacheRead: 0, costUSD: 0, requests: 0)
        d.input += e.inputTokens
        d.output += e.outputTokens
        d.cacheCreate += e.cacheCreationTokens
        d.cacheRead += e.cacheReadTokens
        d.costUSD += Pricing.cost(for: e)
        d.requests += 1
        buckets[key] = d
    }

    private func jsonlFiles(under root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" { out.append(url) }
        return out
    }

    /// Merge hourly base buckets into display points at the requested
    /// granularity (hour = identity-ish, day = collapse 24h), tool-agnostic.
    private func rollup(_ stats: [DailyStat], granularity: StatsGranularity) -> [DailyStat] {
        let cal = Calendar.current
        func bucketStart(_ d: Date) -> Date {
            switch granularity {
            case .hour: return cal.date(from: cal.dateComponents([.year, .month, .day, .hour], from: d)) ?? d
            case .day:  return cal.startOfDay(for: d)
            }
        }
        var byKey: [Int: DailyStat] = [:]
        for s in stats {
            let start = bucketStart(s.day)
            let k = Int(start.timeIntervalSince1970)
            if var m = byKey[k] {
                m.input += s.input; m.output += s.output
                m.cacheCreate += s.cacheCreate; m.cacheRead += s.cacheRead
                m.costUSD += s.costUSD; m.requests += s.requests
                byKey[k] = m
            } else {
                byKey[k] = DailyStat(day: start, toolName: "all",
                                     input: s.input, output: s.output,
                                     cacheCreate: s.cacheCreate, cacheRead: s.cacheRead,
                                     costUSD: s.costUSD, requests: s.requests)
            }
        }
        return Array(byKey.values)
    }

    // MARK: - Cache

    // `version` bumps the schema (day → hour buckets); an old cache fails to
    // decode and triggers a one-time full rescan.
    private struct Cache: Codable { var version: Int = 2; var buckets: [DailyStat]; var offsets: [String: UInt64] }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data),
              cache.version == 2 else { return }
        offsets = cache.offsets
        for d in cache.buckets {
            buckets["\(d.toolName)|\(Int(d.day.timeIntervalSince1970))"] = d
        }
    }

    private func saveCache() {
        let cache = Cache(buckets: Array(buckets.values), offsets: offsets)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
