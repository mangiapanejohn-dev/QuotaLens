import SwiftUI

/// A number that rolls up from zero to its target on appear (and re-counts when
/// the target changes). Respects Reduce Motion.
struct CountUpText: View {
    let target: Double
    var format: (Double) -> String
    var font: Font
    var color: Color = Palette.textPrimary

    @State private var value: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(format(value))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear { run() }
            .onChange(of: target) { _, _ in run() }
    }

    private func run() {
        if reduceMotion { value = target; return }
        value = 0
        withAnimation(.qlSmooth.speed(0.5)) { value = target }
    }
}
