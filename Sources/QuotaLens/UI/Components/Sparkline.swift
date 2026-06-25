import SwiftUI

/// A smooth trend line with a soft gradient fill and a glowing leading point.
struct Sparkline: View {
    let values: [Double]
    var color: Color
    var replay: Int = 0

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let pts = points(in: geo.size, maxV: maxV)
            ZStack {
                if pts.count > 1 {
                    smoothPath(pts, closeAt: geo.size.height)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0)],
                            startPoint: .top, endPoint: .bottom))
                    smoothPath(pts, closeAt: nil)
                        .stroke(
                            LinearGradient(colors: [color.opacity(0.7), color],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                    if let last = pts.last {
                        Circle().fill(color).frame(width: 4, height: 4).position(last)
                            .opacity(drawn ? 1 : 0)
                    }
                }
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

    private func points(in size: CGSize, maxV: Double) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        return values.enumerated().map { i, v in
            CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                    y: size.height * (1 - CGFloat(v / maxV)) * 0.92 + size.height * 0.04)
        }
    }

    private func smoothPath(_ pts: [CGPoint], closeAt bottom: CGFloat?) -> Path {
        Path { p in
            p.move(to: pts[0])
            for i in 1..<pts.count {
                let prev = pts[i - 1], cur = pts[i]
                let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
                p.addQuadCurve(to: mid, control: CGPoint(x: prev.x, y: prev.y))
                p.addQuadCurve(to: cur, control: CGPoint(x: cur.x, y: cur.y))
            }
            if let bottom {
                p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: bottom))
                p.addLine(to: CGPoint(x: pts[0].x, y: bottom))
                p.closeSubpath()
            }
        }
    }
}
