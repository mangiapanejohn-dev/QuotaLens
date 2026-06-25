import SwiftUI

/// One capacity window. By default shows only the authoritative meter; the
/// local estimate (and its delta) appear when diagnostics are on.
struct DualUsageRow: View {
    let usage: ToolUsage
    var showDelta: Bool = false
    var replay: Int = 0
    var tint: Color = Palette.brand

    var body: some View {
        VStack(alignment: .leading, spacing: showDelta ? 9 : 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.windowType.displayName)
                    .font(.ql(12.5, .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if let reset = Format.reset(usage.effectiveResetsAt) {
                    Text(reset)
                        .font(.ql(9.5, .medium))
                        .foregroundStyle(Palette.textTertiary)
                        .monospacedDigit()
                }
            }

            if showDelta {
                Meter(label: usage.official?.stale == true ? "Official ·stale" : "Official",
                      ratio: usage.official?.percent, emphasized: true, height: 7, replay: replay, tint: tint)
                Meter(label: "Local", ratio: usage.localRatio, emphasized: false, height: 5, replay: replay, tint: tint)
                if let d = usage.delta {
                    let pct = Int((d * 100).rounded())
                    Label("\(pct > 0 ? "+" : "")\(pct)% vs official",
                          systemImage: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.qlMono(9, .medium))
                        .foregroundStyle(Palette.heat(d >= 0 ? 0.8 : 0.3))
                }
            } else {
                Meter(label: nil, ratio: usage.official?.percent, emphasized: true, height: 9, replay: replay, tint: tint)
            }
        }
    }
}

/// A progress meter with a value read-out. Heat-coloured by its own ratio;
/// grows from zero on appear and rolls its figure on change.
struct Meter: View {
    var label: String? = nil
    let ratio: Double?
    var emphasized: Bool = true
    var height: CGFloat = 7
    var placeholder: String = "N/A"
    var replay: Int = 0
    var tint: Color = Palette.brand

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 9) {
            if let label {
                Text(label)
                    .font(.ql(9.5, emphasized ? .semibold : .medium))
                    .foregroundStyle(emphasized ? Palette.textSecondary : Palette.textTertiary)
                    .frame(width: 52, alignment: .leading)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    if let r = ratio, r > 0 {
                        Capsule().fill(emphasized ? tint : tint.opacity(0.4))
                            .frame(width: grown ? max(geo.size.width * min(r, 1), 4) : 0)
                            .animation(.qlSnappy, value: r)
                    }
                }
            }
            .frame(height: height)

            value
                .frame(width: 44, alignment: .trailing)
        }
        .onAppear { grow() }
        .onChange(of: replay) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { grown = false }
            grow()
        }
    }

    private func grow() {
        if reduceMotion { grown = true }
        else { withAnimation(.qlEntrance) { grown = true } }
    }

    @ViewBuilder private var value: some View {
        if let r = ratio {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(Int((r * 100).rounded()))")
                    .font(.qlRound(13, .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("%").font(.qlRound(9, .medium)).foregroundStyle(.secondary)
            }
            .foregroundStyle(emphasized ? tint : Palette.textTertiary)
            .animation(.qlSnappy, value: r)
        } else {
            Text(placeholder)
                .font(.ql(10, .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
