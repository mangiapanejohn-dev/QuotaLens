import SwiftUI

/// A flat progress ring: solid coloured arc over a neutral track, with the
/// figure in SF Rounded. Draws in on appear and rolls on change. No effects.
struct RingView: View {
    let ratio: Double
    var lineWidth: CGFloat = 6
    var showPercentage: Bool = true
    var tint: Color = Palette.brand
    var replay: Int = 0

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let clamped = min(max(ratio, 0), 1)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(Palette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: drawn ? clamped : 0)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.qlSnappy, value: clamped)
                if showPercentage {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(Int((ratio * 100).rounded()))")
                            .font(.qlRound(size * 0.34, .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.qlRound(size * 0.21, .medium))
                            .foregroundStyle(Palette.textTertiary)
                            .baselineOffset(size * 0.02)
                    }
                    .animation(.qlSnappy, value: ratio)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { draw() }
        .onChange(of: replay) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { drawn = false }
            draw()
        }
    }

    private func draw() {
        if reduceMotion { drawn = true }
        else { withAnimation(.qlBouncy) { drawn = true } }
    }
}
