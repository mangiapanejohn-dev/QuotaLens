import Foundation

/// Fans out to every official source and collects authoritative readings.
/// Codex resolves from local files (no network); Claude probes the API.
actor OfficialSyncService {
    private var sources: [any OfficialSource]

    init(sources: [any OfficialSource]) {
        self.sources = sources
    }

    /// Replace the source set (Claude account probes are dynamic at runtime).
    func setSources(_ newSources: [any OfficialSource]) {
        sources = newSources
    }

    /// `latestActivity` maps toolName → most recent local event time, so a
    /// source can decide whether a fresh (possibly networked) probe is due.
    /// `enabled` limits probing to enabled tools (skips disabled accounts).
    func sync(now: Date, latestActivity: [String: Date], enabled: Set<String>) async -> [String: [WindowType: OfficialReading]] {
        var result: [String: [WindowType: OfficialReading]] = [:]
        for source in sources where enabled.contains(source.toolName) {
            let readings = await source.officialReadings(
                now: now, latestActivity: latestActivity[source.toolName])
            if !readings.isEmpty { result[source.toolName] = readings }
        }
        return result
    }
}
