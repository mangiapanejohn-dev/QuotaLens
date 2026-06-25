import SwiftUI

/// The standalone statistics window — hero total, stat cards, and the multi-
/// series trend chart, styled after the CC Switch usage dashboard.
struct StatsDashboardView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: Settings
    @StateObject private var model: StatsModel
    @State private var appeared = false
    @State private var showCustom = false
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(history: HistoryService) {
        _model = StateObject(wrappedValue: StatsModel(history: history))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.ink, Palette.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.appear(delay: 0.0)
                    rangeRow.appear(delay: 0.04)
                    if !liveAccounts.isEmpty { liveCard.appear(delay: 0.10) }
                    hero.appear(delay: 0.14)
                    cards.appear(delay: 0.20)
                    trendCard.appear(delay: 0.26)
                }
                .padding(22)
            }
            .scrollIndicators(.never)
            .animation(.qlSmooth, value: model.range)

            if model.isLoading {
                loadingOverlay.transition(.opacity)
            }
        }
        .frame(minWidth: 820, minHeight: 620)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.95)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .animation(.qlSmooth, value: model.isLoading)
        .task { await model.load(allowed: allowedTools) }
        .onChange(of: allowedTools) { _, new in model.setAllowed(new) }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(.qlEntrance) { appeared = true } }
        }
    }

    /// Tool history keys that may appear, mirroring the configured sources:
    /// Claude only when an enabled Claude account exists, Codex when enabled.
    private var allowedTools: Set<String> {
        var set = Set<String>()
        if settings.claudeAccounts.contains(where: { settings.isEnabled($0.toolName) }) {
            set.insert("claude-code")
        }
        if settings.isEnabled("codex") { set.insert("codex") }
        return set
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Usage Statistics")
                .font(.ql(20, .bold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            MaterialSegmented(options: filterOptions, selection: filterBinding)
                .frame(width: CGFloat(filterOptions.count) * 86)
                .onChange(of: filterKey) { _, _ in
                    if !filterOptions.contains(where: { $0.0 == model.filter }) { model.setFilter(nil) }
                }
        }
    }

    /// Filter chips track the configured sources: Claude shows only when an
    /// enabled Claude account exists; Codex only when it's enabled.
    private var filterOptions: [(String?, String)] {
        var opts: [(String?, String)] = [(nil, "All")]
        if settings.claudeAccounts.contains(where: { settings.isEnabled($0.toolName) }) {
            opts.append(("claude-code", "Claude"))
        }
        if settings.isEnabled("codex") { opts.append(("codex", "Codex")) }
        return opts
    }

    private var filterKey: String { filterOptions.map { $0.0 ?? "all" }.joined(separator: ",") }

    private var filterBinding: Binding<String?> {
        Binding(get: { model.filter }, set: { model.setFilter($0) })
    }

    // MARK: - Live per-account usage (real official %, synced to config)

    private var liveAccounts: [ToolSnapshot] {
        store.snapshots.filter { $0.toolName.hasPrefix("claude") && settings.isEnabled($0.toolName) }
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live quota").font(.ql(14, .semibold)).foregroundStyle(Palette.textPrimary)
            ForEach(liveAccounts) { snap in liveRow(snap) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile(20)
    }

    private func liveRow(_ snap: ToolSnapshot) -> some View {
        HStack(spacing: 12) {
            BrandLogo(toolName: snap.toolName, size: 16, tint: Palette.toolColor(snap.toolName))
            Text(snap.displayName).font(.ql(13, .semibold)).foregroundStyle(Palette.textPrimary)
            if snap.expired {
                Text("expired").font(.ql(9, .semibold)).foregroundStyle(Palette.danger)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Capsule().fill(Palette.danger.opacity(0.16)))
            }
            Spacer()
            liveStat("5h", snap.usage(.fiveHour)?.usageRatio)
            liveStat("7d", snap.usage(.sevenDay)?.usageRatio)
        }
    }

    private func liveStat(_ label: String, _ ratio: Double?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.qlMono(10)).foregroundStyle(Palette.textTertiary)
            if let r = ratio {
                Text("\(Int((r * 100).rounded()))%")
                    .font(.qlRound(15, .semibold)).monospacedDigit()
                    .foregroundStyle(r >= 0.9 ? Palette.danger : Palette.heat(min(r, 1)))
            } else {
                Text("—").font(.qlRound(15, .semibold)).foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(width: 72, alignment: .trailing)
    }

    // MARK: - Range row

    private var rangeRow: some View {
        HStack {
            RangeSelector(
                selected: model.range,
                customLabel: customLabel,
                onSelect: { model.setRange($0) },
                onCustom: { showCustom = true })
            .popover(isPresented: $showCustom, arrowEdge: .bottom) { customPopover }
            Spacer()
        }
    }

    private var customLabel: String {
        if case .custom(let a, let b) = model.range {
            let f = Date.FormatStyle.dateTime.month(.twoDigits).day(.twoDigits)
            return "\(a.formatted(f))–\(b.formatted(f))"
        }
        return "Custom"
    }

    private var customPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom range")
                .font(.ql(12, .semibold)).foregroundStyle(Palette.textPrimary)
            HStack {
                Text("From").font(.ql(11)).foregroundStyle(Palette.textSecondary)
                Spacer()
                DatePicker("", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                    .labelsHidden()
            }
            HStack {
                Text("To").font(.ql(11)).foregroundStyle(Palette.textSecondary)
                Spacer()
                DatePicker("", selection: $customEnd, in: customStart...Date(), displayedComponents: .date)
                    .labelsHidden()
            }
            HStack {
                Spacer()
                Button("Apply") {
                    model.setRange(.custom(customStart, customEnd))
                    showCustom = false
                }
                .font(.ql(11, .semibold))
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.brand)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.brand.opacity(0.16)))
                    Text("Tokens consumed")
                        .font(.ql(12, .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    CountUpText(target: model.summary.totalTokens,
                               format: { $0.formatted(.number.precision(.fractionLength(0))) },
                               font: .qlRound(38, .bold))
                    Text("≈ \(compact(model.summary.totalTokens))")
                        .font(.ql(13, .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            HStack(spacing: 22) {
                miniStat("Requests", Double(model.summary.requests), Palette.brand) { "\(Int($0))" }
                miniStat("Total cost", model.summary.costUSD, Color(hex: 0x5CD6A0), Format.dollars)
            }
            .padding(16)
            .tile(16)
        }
        .padding(18)
        .tile(20)
    }

    private func miniStat(_ label: String, _ target: Double, _ color: Color,
                          _ format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.ql(10, .medium)).foregroundStyle(Palette.textTertiary)
            CountUpText(target: target, format: format, font: .qlRound(18, .semibold), color: color)
        }
    }

    // MARK: - Cards

    private var cards: some View {
        HStack(spacing: 12) {
            statCard("arrow.down", "Input", model.summary.input, Color(hex: 0x37C8D6), Format.tokens)
            statCard("arrow.up", "Output", model.summary.output, Color(hex: 0x5CD6A0), Format.tokens)
            statCard("plus.square.on.square", "Cache created", model.summary.cacheCreate, Color(hex: 0xFFC24A), Format.tokens)
            statCard("bolt.horizontal", "Cache hits", model.summary.cacheRead, Color(hex: 0xA78BFA), Format.tokens)
            rateCard
        }
    }

    private func statCard(_ icon: String, _ label: String, _ target: Double, _ color: Color,
                          _ format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.ql(10.5, .medium)).foregroundStyle(Palette.textSecondary)
            }
            CountUpText(target: target, format: format, font: .qlRound(19, .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tile(16)
    }

    private var rateCard: some View {
        let rate = model.summary.cacheHitRate
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "speedometer").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: 0x5CD6A0))
                Text("Cache hit rate").font(.ql(10.5, .medium)).foregroundStyle(Palette.textSecondary)
            }
            CountUpText(target: rate, format: { Format.percent($0) }, font: .qlRound(19, .semibold))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(Color(hex: 0x5CD6A0)).frame(width: geo.size.width * min(max(rate, 0), 1))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tile(16)
    }

    // MARK: - Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Usage trend").font(.ql(14, .semibold)).foregroundStyle(Palette.textPrimary)
                Spacer()
                if let first = model.daily.first?.day, let last = model.daily.last?.day {
                    Text("\(first, format: .dateTime.year().month().day()) – \(last, format: .dateTime.month().day())")
                        .font(.qlMono(10)).foregroundStyle(Palette.textTertiary)
                }
            }
            if model.daily.isEmpty {
                Text("No usage in this range.").font(.ql(11)).foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                UsageTrendChart(daily: model.daily, granularity: model.granularity)
                    .frame(minHeight: 320)
                    .id(model.range)
            }
        }
        .padding(18)
        .tile(20)
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        ZStack {
            Palette.ink.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Parsing usage history…")
                    .font(.ql(12, .medium)).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func compact(_ value: Double) -> String {
        switch value {
        case 1_000_000_000...: return String(format: "%.2fB", value / 1_000_000_000)
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        default: return Format.tokens(value)
        }
    }
}
