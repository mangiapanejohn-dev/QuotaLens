import SwiftUI

/// Drives the statistics window: loads historical aggregates off the actor and
/// publishes them, tracking the tool filter, the time range, and a first-load
/// state. Range + filter changes recompute against the cached hourly buckets.
@MainActor
final class StatsModel: ObservableObject {
    @Published var summary = StatsSummary.empty
    @Published var daily: [DailyStat] = []
    @Published var isLoading = true
    @Published var filter: String? = nil          // nil = all tools
    @Published var range: StatsRange = .all
    @Published private(set) var granularity: StatsGranularity = .day
    /// Tool keys that may appear at all — driven by the configured sources.
    private var allowed: Set<String> = []

    private let history: HistoryService

    init(history: HistoryService) { self.history = history }

    func load(allowed: Set<String>) async {
        self.allowed = allowed
        await history.ensureLoaded()
        await recompute()
        isLoading = false
    }

    func setFilter(_ value: String?) {
        filter = value
        Task { await recompute() }
    }

    func setRange(_ value: StatsRange) {
        range = value
        Task { await recompute() }
    }

    func setAllowed(_ value: Set<String>) {
        guard value != allowed else { return }
        allowed = value
        if !value.contains(where: { $0 == filter }) && filter != nil { filter = nil }
        Task { await recompute() }
    }

    private func recompute() async {
        let now = Date()
        let g = range.granularity(now: now)
        let result = await history.stats(
            filter: filter, interval: range.interval(now: now), granularity: g, allowed: allowed)
        granularity = g
        summary = result.summary
        daily = result.daily
    }
}
