import SwiftUI

/// Button style with tactile feedback: a spring scale-down on press plus a
/// ripple that expands from the centre. Reads as Material touch response.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, scale: scale)
    }

    private struct PressableBody: View {
        let configuration: Configuration
        let scale: CGFloat
        @State private var rippleScale: CGFloat = 0.2
        @State private var rippleOpacity: Double = 0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? scale : 1)
                .animation(.qlPress, value: configuration.isPressed)
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                        .allowsHitTesting(false)
                        .blendMode(.plusLighter)
                }
                .onChange(of: configuration.isPressed) { _, pressed in
                    guard pressed, !reduceMotion else { return }
                    rippleScale = 0.2; rippleOpacity = 0.5
                    withAnimation(.easeOut(duration: 0.5)) {
                        rippleScale = 2.2; rippleOpacity = 0
                    }
                }
        }
    }
}
