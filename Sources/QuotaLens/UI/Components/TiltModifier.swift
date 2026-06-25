import SwiftUI

/// Parallax 3D tilt that follows the cursor, plus a slight lift. Reads the
/// view's own size via a background reader so layout is untouched.
private struct TiltModifier: ViewModifier {
    var maxAngle: Double = 7
    @State private var size: CGSize = .zero
    @State private var tilt: CGSize = .zero
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { size = g.size }
                        .onChange(of: g.size) { _, new in size = new }
                }
            )
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.height) * -maxAngle),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.width) * maxAngle),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(hovering && !reduceMotion ? 1.025 : 1)
            .animation(.qlHover, value: tilt)
            .animation(.qlHover, value: hovering)
            .onContinuousHover { phase in
                guard size.width > 0, size.height > 0 else { return }
                switch phase {
                case .active(let p):
                    hovering = true
                    tilt = CGSize(width: (p.x / size.width - 0.5) * 2,
                                  height: (p.y / size.height - 0.5) * 2)
                case .ended:
                    hovering = false
                    tilt = .zero
                }
            }
    }
}

extension View {
    func tilt(maxAngle: Double = 7) -> some View {
        modifier(TiltModifier(maxAngle: maxAngle))
    }
}
