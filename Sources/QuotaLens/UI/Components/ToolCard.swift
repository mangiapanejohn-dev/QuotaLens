import SwiftUI

/// One tool as a flat card in its brand colour: header (glyph + name + ring) →
/// 5h/7d meters → session → trend. Colourful data, no effects.
struct ToolCard: View {
    let snapshot: ToolSnapshot
    var timelineHours: Int
    var showDelta: Bool = false
    var index: Int = 0
    var nonce: Int = 0

    private var headline: Double { snapshot.headlineRatio }
    private var tint: Color { Palette.toolColor(snapshot.toolName) }
    private var danger: Bool { headline >= 0.9 || snapshot.expired }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header

            VStack(spacing: 11) {
                if let five = snapshot.usage(.fiveHour) {
                    DualUsageRow(usage: five, showDelta: showDelta, replay: nonce, tint: tint)
                }
                if let seven = snapshot.usage(.sevenDay) {
                    DualUsageRow(usage: seven, showDelta: showDelta, replay: nonce, tint: tint)
                }
            }

            if let session = snapshot.usage(.session) {
                Rectangle().fill(Palette.stroke).frame(height: 1)
                UsageBar(usage: session, tint: tint, replay: nonce)
            }

            if isPercentTrend {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Eyebrow(text: "Last \(timelineHours)h")
                        Spacer()
                        trendLegend
                    }
                    MiniTrend(five: snapshot.trend5h, seven: snapshot.trend7d, color: tint, replay: nonce)
                        .frame(height: 34)
                }
            }

            if snapshot.hourlyBuckets.contains(where: { $0 > 0 }) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: isPercentTrend ? "Tokens · last \(timelineHours)h" : "Last \(timelineHours)h")
                    Sparkline(values: snapshot.hourlyBuckets, color: tint, replay: nonce)
                        .frame(height: 26)
                }
            }
        }
        .padding(15)
        .glassCard(tint: tint, danger: danger)
        .tilt()
        .appear(nonce: nonce, delay: staggerDelay(index))
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    BrandLogo(toolName: snapshot.toolName, size: 13, tint: tint)
                    Text(snapshot.displayName)
                        .font(.ql(14, .semibold))
                        .foregroundStyle(Palette.textPrimary)
                }
                Text(statusText)
                    .font(.ql(10))
                    .foregroundStyle(statusColor)
            }
            Spacer()
            RingView(ratio: headline, lineWidth: 5, tint: danger ? Palette.danger : tint, replay: nonce)
                .frame(width: 46, height: 46)
        }
    }

    private var statusText: String {
        if snapshot.expired { return "Token expired · re-paste" }
        guard snapshot.available else { return "No recent activity" }
        let hasOfficial = [WindowType.fiveHour, .sevenDay]
            .contains { snapshot.usage($0)?.official != nil }
        return hasOfficial ? "Official" : "Local estimate"
    }

    private var statusColor: Color {
        if snapshot.expired { return Palette.danger }
        return snapshot.available ? Palette.textSecondary : Palette.textTertiary
    }

    /// Claude accounts chart their probed 5h/7d % over time; others use buckets.
    private var isPercentTrend: Bool { snapshot.trend5h.count >= 2 }

    private var trendLegend: some View {
        HStack(spacing: 8) {
            legendDot(tint, "5h")
            legendDot(tint.opacity(0.4), "7d")
        }
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(c).frame(width: 5, height: 5)
            Text(label).font(.qlMono(8.5)).foregroundStyle(Palette.textTertiary)
        }
    }
}

