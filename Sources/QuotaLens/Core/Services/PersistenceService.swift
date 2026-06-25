import Foundation

/// Lightweight JSON cache for instant cold-start display plus an append-only
/// archive of completed billing cycles. Raw usage lives in the CLI logs; we
/// only persist aggregates.
struct PersistenceService: Sendable {
    /// Bump when the persisted snapshot shape changes incompatibly. A mismatch
    /// makes `load()` return nothing, so the store rebuilds from logs/probe.
    static let schemaVersion = 3

    private let snapshotURL: URL
    private let cyclesURL: URL
    private let probeHistoryURL: URL

    private struct SnapshotEnvelope: Codable {
        var version: Int
        var snapshots: [ToolSnapshot]
    }

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("QuotaLens", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.snapshotURL = dir.appendingPathComponent("snapshots.json")
        self.cyclesURL = dir.appendingPathComponent("cycles.json")
        self.probeHistoryURL = dir.appendingPathComponent("probe-history.json")
    }

    // MARK: - Probe history (per-account official %, for the trend chart)

    func loadProbeHistory() -> [String: [ProbeSample]] {
        guard let data = try? Data(contentsOf: probeHistoryURL),
              let history = try? JSONDecoder().decode([String: [ProbeSample]].self, from: data)
        else { return [:] }
        return history
    }

    func saveProbeHistory(_ history: [String: [ProbeSample]]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: probeHistoryURL, options: .atomic)
    }

    // MARK: - Snapshots

    func load() -> [ToolSnapshot] {
        guard let data = try? Data(contentsOf: snapshotURL),
              let env = try? JSONDecoder().decode(SnapshotEnvelope.self, from: data),
              env.version == Self.schemaVersion
        else { return [] }
        return env.snapshots
    }

    func save(_ snapshots: [ToolSnapshot]) {
        let env = SnapshotEnvelope(version: Self.schemaVersion, snapshots: snapshots)
        guard let data = try? JSONEncoder().encode(env) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    // MARK: - Billing cycle archive (append-only)

    func loadCycles() -> [BillingCycle] {
        guard let data = try? Data(contentsOf: cyclesURL),
              let cycles = try? JSONDecoder().decode([BillingCycle].self, from: data)
        else { return [] }
        return cycles
    }

    func appendCycle(_ cycle: BillingCycle) {
        var cycles = loadCycles()
        cycles.append(cycle)
        if cycles.count > 500 { cycles = Array(cycles.suffix(500)) }
        guard let data = try? JSONEncoder().encode(cycles) else { return }
        try? data.write(to: cyclesURL, options: .atomic)
    }
}
