import SwiftUI
import Charts

/// Multi-series daily trend: input / output / cache-create / cache-hit token
/// lines on the primary axis, cost (dashed) on a scaled secondary axis. Hover
/// snaps a crosshair to the nearest day, lights up a dot on every series, and
/// trails a tooltip — positioned manually so it never clips the card.
struct UsageTrendChart: View {
    let daily: [DailyStat]
    var granularity: StatsGranularity = .day
    @State private var hovered: DailyStat?
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Series { let label: String; let color: Color; let value: (DailyStat) -> Double }
    private let tokenSeries: [Series] = [
        .init(label: "Input",        color: Color(hex: 0x37C8D6), value: { $0.input }),
        .init(label: "Output",       color: Color(hex: 0x5CD6A0), value: { $0.output }),
        .init(label: "Cache create", color: Color(hex: 0xFFC24A), value: { $0.cacheCreate }),
        .init(label: "Cache hit",    color: Color(hex: 0xA78BFA), value: { $0.cacheRead }),
    ]
    private let costColor = Color(hex: 0xFF5A52)

    private var maxToken: Double {
        max(daily.map { Swift.max($0.input, $0.output, $0.cacheCreate, $0.cacheRead) }.max() ?? 1, 1)
    }
    private var maxCost: Double { max(daily.map(\.costUSD).max() ?? 1, 0.0001) }
    private var costScale: Double { maxToken / maxCost }

    var body: some View {
        Chart {
            ForEach(tokenSeries, id: \.label) { s in
                ForEach(daily, id: \.day) { d in
                    AreaMark(x: .value("Day", d.day), y: .value("Tokens", s.value(d)))
                        .foregroundStyle(by: .value("Series", s.label))
                        .opacity(0.07)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", d.day), y: .value("Tokens", s.value(d)))
                        .foregroundStyle(by: .value("Series", s.label))
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                        .interpolationMethod(.catmullRom)
                }
            }
            ForEach(daily, id: \.day) { d in
                LineMark(x: .value("Day", d.day), y: .value("Tokens", d.costUSD * costScale))
                    .foregroundStyle(by: .value("Series", "Cost"))
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([
            "Input": Color(hex: 0x37C8D6), "Output": Color(hex: 0x5CD6A0),
            "Cache create": Color(hex: 0xFFC24A), "Cache hit": Color(hex: 0xA78BFA),
            "Cost": costColor,
        ])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Palette.stroke.opacity(0.6))
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text(Format.tokens(t)).font(.qlMono(9)).foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text(Format.dollars(t / costScale)).font(.qlMono(9)).foregroundStyle(costColor.opacity(0.8))
                    }
                }
            }
        }
        .chartXAxis {
            if granularity == .hour {
                AxisMarks(values: .stride(by: .hour, count: max(daily.count / 6, 1))) { _ in
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                        .font(.qlMono(9))
                        .foregroundStyle(Palette.textTertiary)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: max(daily.count / 8, 1))) { _ in
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .font(.qlMono(9))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .chartLegend(position: .bottom, spacing: 14)
        .chartOverlay { proxy in
            GeometryReader { geo in
                hoverLayer(proxy: proxy, geo: geo)
            }
        }
        .mask { Rectangle().scaleEffect(x: drawn ? 1 : 0, y: 1, anchor: .leading) }
        .onAppear {
            if reduceMotion { drawn = true }
            else { withAnimation(.qlSmooth.speed(0.45)) { drawn = true } }
        }
    }

    // MARK: - Hover

    @ViewBuilder
    private func hoverLayer(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        if let anchor = proxy.plotFrame {
            let plot = geo[anchor]
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let x = location.x - plot.origin.x
                            if let day: Date = proxy.value(atX: x) {
                                let nearest = daily.min {
                                    abs($0.day.timeIntervalSince(day)) < abs($1.day.timeIntervalSince(day))
                                }
                                withAnimation(.qlSnappy) { hovered = nearest }
                            }
                        case .ended:
                            withAnimation(.qlSmooth) { hovered = nil }
                        }
                    }

                if let h = hovered, let px = proxy.position(forX: h.day) {
                    let cx = plot.origin.x + px
                    crosshair(at: cx, plot: plot, day: h, proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private func crosshair(at cx: CGFloat, plot: CGRect, day h: DailyStat, proxy: ChartProxy) -> some View {
        // Vertical guide.
        Rectangle()
            .fill(Palette.strokeStrong.opacity(0.7))
            .frame(width: 1, height: plot.height)
            .position(x: cx, y: plot.midY)

        // A lit dot on every series at the hovered day.
        ForEach(tokenSeries, id: \.label) { s in
            seriesDot(color: s.color, value: s.value(h), cx: cx, plot: plot, proxy: proxy)
        }
        seriesDot(color: costColor, value: h.costUSD * costScale, cx: cx, plot: plot, proxy: proxy)

        // Tooltip, trailing the cursor and clamped inside the plot.
        tooltip(h)
            .fixedSize()
            .background(GeometryReader { tip in
                Color.clear.preference(key: TipSizeKey.self, value: tip.size)
            })
            .modifier(TooltipPlacement(cx: cx, plot: plot))
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    @ViewBuilder
    private func seriesDot(color: Color, value: Double, cx: CGFloat, plot: CGRect, proxy: ChartProxy) -> some View {
        if let py = proxy.position(forY: value) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                .shadow(color: color.opacity(0.6), radius: 3)
                .position(x: cx, y: plot.origin.y + py)
        }
    }

    private var tooltipDateFormat: Date.FormatStyle {
        granularity == .hour
            ? .dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute()
            : .dateTime.month(.twoDigits).day(.twoDigits)
    }

    private func tooltip(_ d: DailyStat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(d.day, format: tooltipDateFormat)
                .font(.ql(11, .semibold)).foregroundStyle(Palette.textPrimary)
            row("Input", d.input, Color(hex: 0x37C8D6))
            row("Output", d.output, Color(hex: 0x5CD6A0))
            row("Cache create", d.cacheCreate, Color(hex: 0xFFC24A))
            row("Cache hit", d.cacheRead, Color(hex: 0xA78BFA))
            HStack(spacing: 6) {
                Circle().fill(costColor).frame(width: 6, height: 6)
                Text("Cost").font(.ql(9.5)).foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 10)
                Text(Format.dollars(d.costUSD)).font(.qlMono(9.5)).foregroundStyle(Palette.textPrimary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.tileRaised))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
    }

    private func row(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.ql(9.5)).foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 10)
            Text(Format.tokens(value)).font(.qlMono(9.5)).foregroundStyle(Palette.textPrimary)
        }
    }
}

private struct TipSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Places the tooltip beside the crosshair, flipping sides and clamping
/// vertically so it always stays within the plot rectangle.
private struct TooltipPlacement: ViewModifier {
    let cx: CGFloat
    let plot: CGRect
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        let margin: CGFloat = 12
        let onLeft = cx > plot.midX
        let x = onLeft ? cx - margin - size.width / 2 : cx + margin + size.width / 2
        let clampedX = min(max(x, plot.minX + size.width / 2), plot.maxX - size.width / 2)
        let y = min(max(plot.minY + size.height / 2 + 4, plot.minY + size.height / 2),
                    plot.maxY - size.height / 2)
        content
            .onPreferenceChange(TipSizeKey.self) { size = $0 }
            .position(x: clampedX, y: y)
            .animation(.qlSnappy, value: cx)
    }
}
