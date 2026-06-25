import SwiftUI

/// Unified, interruptible spring vocabulary.
extension Animation {
    static let qlSnappy = Animation.snappy(duration: 0.42, extraBounce: 0.06)
    static let qlSmooth = Animation.smooth(duration: 0.4)
    static let qlEntrance = Animation.spring(response: 0.55, dampingFraction: 0.72)  // slight overshoot
    static let qlBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let qlHover = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let qlPress = Animation.spring(response: 0.2, dampingFraction: 0.6)
}

/// Staggered delay for cascade entrances.
func staggerDelay(_ index: Int, base: Double = 0.04, step: Double = 0.06) -> Double {
    base + Double(index) * step
}

/// Scales + lifts + fades content in on appear, and replays whenever `nonce`
/// changes (so the panel re-cascades every time the popover opens). Respects
/// Reduce Motion.
private struct AppearModifier: ViewModifier {
    var nonce: Int
    var delay: Double
    var offset: CGFloat
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9, anchor: .center)
            .offset(y: shown ? 0 : offset)
            .onAppear { play() }
            .onChange(of: nonce) { _, _ in
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { shown = false }
                play()
            }
    }

    private func play() {
        if reduceMotion { shown = true; return }
        withAnimation(.qlEntrance.delay(delay)) { shown = true }
    }
}

extension View {
    func appear(nonce: Int = 0, delay: Double = 0, offset: CGFloat = 12) -> some View {
        modifier(AppearModifier(nonce: nonce, delay: delay, offset: offset))
    }
}
