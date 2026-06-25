import SwiftUI

/// A circular icon button: animated tonal hover layer, spring press scale +
/// ripple (via PressableStyle), and an optional one-shot glyph rotation.
struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 13
    var rotateTrigger: Int = 0
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(hovering ? Palette.textPrimary : Palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.12 : 0)))
                .clipShape(Circle())
                .contentShape(Circle())
                .symbolEffect(.rotate, value: rotateTrigger)
        }
        .buttonStyle(PressableStyle())
        .onHover { h in withAnimation(.qlHover) { hovering = h } }
    }
}
