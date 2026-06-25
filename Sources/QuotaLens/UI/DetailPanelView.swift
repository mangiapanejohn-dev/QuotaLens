import SwiftUI

/// The dropdown panel shown from the menu bar.
struct DetailPanelView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var settings: Settings
    @State private var showSettings = false

    var body: some View {
        ZStack {
            GlassBackground().ignoresSafeArea()
            Palette.background.opacity(0.92).ignoresSafeArea()

            ZStack {
                if showSettings {
                    SettingsView(showSettings: $showSettings)
                        .transition(.push(from: .trailing).combined(with: .opacity))
                } else {
                    panel
                        .transition(.push(from: .leading).combined(with: .opacity))
                }
            }
            .animation(.qlSmooth, value: showSettings)
        }
        .frame(width: 392, height: panelHeight)
    }

    private var panelHeight: CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return min(648, max(380, screen - 80))
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .appear(nonce: store.openNonce)

            MaterialSegmented(options: [(nil, "All")] + store.availableTools.map { ($0.name, $0.label) },
                              selection: $store.selectedTool)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .appear(nonce: store.openNonce, delay: 0.03)

            if store.visibleSnapshots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(store.visibleSnapshots.enumerated()), id: \.element.id) { idx, snap in
                            ToolCard(snapshot: snap,
                                     timelineHours: settings.timelineHours,
                                     showDelta: settings.showDiagnostics && snap.hasLocalEstimate,
                                     index: idx, nonce: store.openNonce)
                                .transition(.blurReplace)
                        }
                        timelineSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .animation(.qlSmooth, value: store.selectedTool)
                }
                .frame(maxHeight: .infinity)
                .scrollIndicators(.never)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }

            footer
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RingView(ratio: store.aggregateRatio, lineWidth: 3.5, showPercentage: false,
                     tint: Palette.toolColor(store.aggregateTool ?? ""))
                .frame(width: 22, height: 22)
            HStack(spacing: 0) {
                Text("Quota").foregroundStyle(Palette.textPrimary)
                Text("Lens").foregroundStyle(Palette.brand)
            }
            .font(.ql(16, .bold))
            Spacer()
            CircleIconButton(systemName: "gearshape", size: 14) { showSettings = true }
        }
    }

    private var timelineSection: some View {
        let buckets = combinedBuckets
        return Group {
            if buckets.contains(where: { $0 > 0 }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Eyebrow(text: "Timeline · last \(settings.timelineHours)h")
                        Spacer()
                        if !combinedResetMarkers.isEmpty {
                            Label("reset", systemImage: "arrow.counterclockwise")
                                .font(.ql(9, .semibold))
                                .foregroundStyle(Palette.heat(1.0).opacity(0.9))
                        }
                    }
                    TimelineChart(values: buckets, color: Palette.brand,
                                  resetMarkers: combinedResetMarkers)
                        .frame(height: 44)
                }
                .padding(15)
                .tile(20)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(updatedText)
                .font(.qlMono(9.5, .regular))
                .foregroundStyle(Palette.textQuaternary)
            Spacer()
            CircleIconButton(systemName: "chart.xyaxis.line", size: 12) { store.onOpenStats?() }
            CircleIconButton(systemName: "arrow.clockwise", size: 12, rotateTrigger: store.refreshTick) { store.refreshNow() }
            CircleIconButton(systemName: "power", size: 12) { NSApplication.shared.terminate(nil) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Palette.textTertiary)
            Text("No usage yet")
                .font(.ql(13, .semibold))
                .foregroundStyle(Palette.textSecondary)
            Text("Run Claude Code or Codex to start tracking.")
                .font(.ql(10.5))
                .foregroundStyle(Palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
    }

    private var combinedBuckets: [Double] {
        let snaps = store.visibleSnapshots
        guard let length = snaps.map(\.hourlyBuckets.count).max(), length > 0 else { return [] }
        var out = [Double](repeating: 0, count: length)
        for snap in snaps {
            for (i, v) in snap.hourlyBuckets.enumerated() where i < length { out[i] += v }
        }
        return out
    }

    private var combinedResetMarkers: [Double] {
        store.visibleSnapshots.flatMap { $0.resetMarkerPositions(hours: settings.timelineHours) }
    }

    private var updatedText: String {
        guard let date = store.lastUpdated else { return "Updating…" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "Updated \(f.string(from: date))"
    }
}
