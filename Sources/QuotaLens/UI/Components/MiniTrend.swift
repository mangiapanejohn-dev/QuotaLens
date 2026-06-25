import SwiftUI

/// Two smooth trend lines (5h + 7d utilization) on a fixed 0–100% scale, so the
/// height reflects real usage. Used by Claude account cards, which have only
/// probed percentages over time — no per-hour token volume to plot.
struct MiniTrend: View {
    let five: [Double]
    let seven: [Double]
    var color: Color
    var replay: Int = 0

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                line(seven, in: geo.size, lineColor: color.opacity(0.4), width: 1.5)
                line(five, in: geo.size, lineColor: color, width: 1.9)
            }
            .mask(alignment: .leading) {
                Rectangle().frame(width: drawn ? geo.size.width : 0)
            }
        }
        .onAppear { reveal() }
        .onChange(of: replay) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { drawn = false }
            reveal()
        }
    }

    private func reveal() {
        if reduceMotion { drawn = true }
        else { withAnimation(.qlSmooth.speed(0.7)) { drawn = true } }
    }

    @ViewBuilder
    private func line(_ values: [Double], in size: CGSize, lineColor: Color, width: CGFloat) -> some View {
        let pts = points(values, in: size)
        if pts.count > 1 {
            smoothPath(pts).stroke(
                lineColor,
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    private func points(_ values: [Double], in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        return values.enumerated().map { i, v in
            let cv = min(max(v, 0), 1)   // fixed 0–100% scale
            return CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                           y: size.height * (1 - CGFloat(cv)) * 0.9 + size.height * 0.05)
        }
    }

    private func smoothPath(_ pts: [CGPoint]) -> Path {
        Path { p in
            p.move(to: pts[0])
            for i in 1..<pts.count {
                let prev = pts[i - 1], cur = pts[i]
                let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
                p.addQuadCurve(to: mid, control: prev)
                p.addQuadCurve(to: cur, control: cur)
            }
        }
    }
}
