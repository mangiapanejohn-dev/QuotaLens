import Foundation
import Combine

/// Central view-model: local tracking + official sync → reconciliation →
/// reset detection → dual-metric snapshots, persisted and notified on.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ToolSnapshot] = []
    @Published private(set) var aggregateRatio: Double = 0
    /// The tool driving the aggregate (for the menu-bar tint).
    @Published private(set) var aggregateTool: String?
    @Published private(set) var lastUpdated: Date?
    /// Header filter: nil = all tools, otherwise a single toolName.
    @Published var selectedTool: String?
    /// Bumped each time the popover opens, to replay entrance animations.
    @Published private(set) var openNonce: Int = 0
    /// Bumped on a manual refresh, to trigger a one-shot icon rotation.
    @Published private(set) var refreshTick: Int = 0

    func markOpened() { openNonce &+= 1 }

    /// Set by AppDelegate; opens the statistics window.
    var onOpenStats: (() -> Void)?

    let settings: Settings
    private let registry = ProviderRegistry()
    private let persistence = PersistenceService()
    private let notifier = NotificationService()

    private let codexProvider: CodexProvider
    private var officialSync: OfficialSyncService
    private let resetDetector: ResetDetectionService
    /// Per-account Claude probes, keyed by toolName (for expiry status).
    private var claudeProbes: [String: ClaudeOfficialProbe] = [:]
    /// Per-account official-% history (toolName → samples), for the trend chart.
    private var probeHistory: [String: [ProbeSample]] = [:]

    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        let cfg = settings.providerConfig

        self.codexProvider = CodexProvider(config: cfg)
        self.officialSync = OfficialSyncService(sources: [])
        self.resetDetector = ResetDetectionService(persistence: persistence)

        rebuild(accounts: settings.claudeAccounts)
        observeAccounts()
        observeSelection()

        probeHistory = persistence.loadProbeHistory()
        snapshots = persistence.load()   // instant cold-start display
        recomputeAggregate()
    }

    /// The menu bar mirrors the selected tool; recompute when it changes.
    private func observeSelection() {
        $selectedTool
            .dropFirst()
            .sink { [weak self] sel in self?.recomputeAggregate(selection: sel) }
            .store(in: &cancellables)
    }

    func start() {
        notifier.requestAuthorization()
        startPolling()
    }

    var aggregateLevel: ThresholdLevel { ThresholdLevel(ratio: aggregateRatio) }

    var availableTools: [(name: String, label: String)] {
        snapshots.map { ($0.toolName, $0.displayName) }
    }

    /// Non-account tools (Codex, plus Mock in dev). Stable across the session.
    var fixedTools: [(name: String, label: String)] {
        registry.providers
            .filter { !($0 is ClaudeAccountProvider) }
            .map { ($0.toolName, $0.displayName) }
    }

    var visibleSnapshots: [ToolSnapshot] {
        let enabled = snapshots.filter { settings.isEnabled($0.toolName) }
        guard let sel = selectedTool else { return enabled }
        return enabled.filter { $0.toolName == sel }
    }

    func refreshNow() {
        refreshTick &+= 1
        Task { await poll() }
    }

    // MARK: - Provider wiring

    /// (Re)build the provider + official-source set from the current accounts.
    /// Claude accounts are dynamic, so this runs on every account change.
    private func rebuild(accounts: [ClaudeAccount]) {
        var providers: [any UsageProvider] = []
        var sources: [any OfficialSource] = [codexProvider]
        var probes: [String: ClaudeOfficialProbe] = [:]

        for account in accounts {
            providers.append(ClaudeAccountProvider(account: account))
            let probe = ClaudeOfficialProbe(toolName: account.toolName, token: account.token)
            probes[account.toolName] = probe
            sources.append(probe)
        }
        providers.append(codexProvider)
        if ProcessInfo.processInfo.environment["QUOTALENS_MOCK"] == "1" {
            providers.append(MockProvider())
        }

        registry.setProviders(providers)
        claudeProbes = probes
        let snapshot = sources
        Task { await officialSync.setSources(snapshot) }
    }

    private func observeAccounts() {
        // `@Published` emits the new value in willSet, so use the emitted value
        // (the stored property isn't updated yet at sink time).
        settings.$claudeAccounts
            .dropFirst()
            .sink { [weak self] accounts in
                guard let self else { return }
                self.rebuild(accounts: accounts)
                Task { await self.poll() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Poll

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                let interval = self?.settings.refreshInterval ?? 5
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 1) * 1_000_000_000))
            }
        }
    }

    private func poll() async {
        let cfg = settings.providerConfig
        let hours = settings.timelineHours
        let now = Date()

        // 1) Local tracking.
        var local: [String: [ToolUsage]] = [:]
        var buckets: [String: [Double]] = [:]
        var activity: [String: Date] = [:]
        var order: [(name: String, label: String)] = []

        for provider in registry.providers where settings.isEnabled(provider.toolName) {
            await provider.update(config: cfg)
            local[provider.toolName] = await provider.fetchUsage()
            buckets[provider.toolName] = await provider.recentHourlyBuckets(hours: hours)
            if let act = await provider.latestActivity() { activity[provider.toolName] = act }
            order.append((provider.toolName, provider.displayName))
        }

        // 2) Official sync (Codex from files, each Claude account via OAuth probe).
        let enabled = Set(order.map(\.name))
        let official = await officialSync.sync(now: now, latestActivity: activity, enabled: enabled)

        // 3) Reconcile official over local.
        var results: [ToolSnapshot] = []
        for (name, label) in order {
            let localUsages = local[name] ?? []
            let reconciled = Reconciler.reconcile(local: localUsages, official: official[name] ?? [:])
            let expired = await claudeProbes[name]?.isExpired() ?? false
            let available = expired || reconciled.contains { $0.usedTokens > 0 || $0.official != nil }
            results.append(ToolSnapshot(
                toolName: name, displayName: label,
                usages: reconciled,
                hourlyBuckets: buckets[name] ?? [],
                available: available,
                updatedAt: now,
                expired: expired
            ))
        }

        // 4) Reset detection + attach markers.
        resetDetector.observe(snapshots: results, now: now)
        for i in results.indices {
            results[i].resetMarkers = resetDetector.markers(
                for: results[i].toolName, within: Double(hours) * 3600, now: now)
        }

        // 5) Record official-% history for Claude accounts → per-card trend.
        recordProbeTrends(into: &results, now: now, windowHours: hours)

        snapshots = results
        lastUpdated = now
        recomputeAggregate()
        persistence.save(results)
        let enabledSnaps = results.filter { settings.isEnabled($0.toolName) }
        notifier.evaluate(snapshots: enabledSnaps)
        notifier.evaluateExpiry(snapshots: enabledSnaps)
    }

    /// Append the current official 5h/7d reading for each Claude account to its
    /// history (deduped to ~one sample per probe), prune to the window, and fill
    /// the snapshot's trend arrays. Codex keeps its token-volume sparkline.
    private func recordProbeTrends(into results: inout [ToolSnapshot], now: Date, windowHours: Int) {
        let windowSec = Double(windowHours) * 3600
        var changed = false
        for i in results.indices where results[i].toolName.hasPrefix("claude") {
            guard let h5 = results[i].usage(.fiveHour)?.official?.percent,
                  let d7 = results[i].usage(.sevenDay)?.official?.percent else { continue }
            var samples = probeHistory[results[i].toolName] ?? []
            if samples.last.map({ now.timeIntervalSince($0.t) >= 240 }) ?? true {
                samples.append(ProbeSample(t: now, h5: h5, d7: d7))
                changed = true
            }
            samples.removeAll { now.timeIntervalSince($0.t) > windowSec }
            probeHistory[results[i].toolName] = samples
            results[i].trend5h = samples.map(\.h5)
            results[i].trend7d = samples.map(\.d7)
        }
        if changed { persistence.saveProbeHistory(probeHistory) }
    }

    private func recomputeAggregate() { recomputeAggregate(selection: selectedTool) }

    /// Menu bar: when a tool is selected, mirror ITS weekly (7d) usage; on "All",
    /// show the highest headline (max 5h/7d) across enabled tools.
    private func recomputeAggregate(selection: String?) {
        let enabled = snapshots.filter { settings.isEnabled($0.toolName) }
        if let sel = selection, let snap = enabled.first(where: { $0.toolName == sel }) {
            aggregateRatio = snap.usage(.sevenDay)?.usageRatio ?? snap.headlineRatio
            aggregateTool = snap.toolName
            return
        }
        if let top = enabled.max(by: { $0.headlineRatio < $1.headlineRatio }) {
            aggregateRatio = top.headlineRatio
            aggregateTool = top.toolName
        } else {
            aggregateRatio = 0
            aggregateTool = nil
        }
    }
}
