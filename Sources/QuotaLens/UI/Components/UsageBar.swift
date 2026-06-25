import SwiftUI

/// The session read-out: informational (tokens + $), flat thin bar.
struct UsageBar: View {
    let usage: ToolUsage
    var tint: Color = Palette.brand
    var replay: Int = 0

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(usage.windowType.displayName)
                    .font(.ql(12, .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Format.tokens(usage.usedTokens))
                        .font(.qlRound(13, .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.qlSnappy, value: usage.usedTokens)
                    Text("tok").font(.ql(9.5, .medium)).foregroundStyle(Palette.textTertiary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(tint.opacity(0.7))
                        .frame(width: grown ? max(geo.size.width * min(max(usage.usageRatio, 0), 1), 4) : 0)
                        .animation(.qlSnappy, value: usage.usageRatio)
                }
            }
            .frame(height: 5)

            HStack {
                Text("current session")
                    .font(.ql(9.5))
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                if usage.costUSD > 0 {
                    Text(Format.dollars(usage.costUSD))
                        .font(.qlRound(10, .medium))
                        .foregroundStyle(Palette.textTertiary)
                        .monospacedDigit()
                }
            }
        }
        .onAppear { grow() }
        .onChange(of: replay) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { grown = false }
            grow()
        }
    }

    private func grow() {
        if reduceMotion { grown = true } else { withAnimation(.qlEntrance) { grown = true } }
    }
}

