import SwiftUI

/// Material 3 segmented buttons whose selected pill SLIDES between segments
/// (matchedGeometryEffect) with a bouncy spring; each segment has hover + press.
struct MaterialSegmented: View {
    let options: [(id: String?, label: String)]
    @Binding var selection: String?
    @Namespace private var ns
    @State private var hovered: String?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.label) { idx, option in
                if idx > 0 {
                    Rectangle().fill(Palette.stroke).frame(width: 1).frame(maxHeight: .infinity)
                }
                segment(option)
            }
        }
        .frame(height: 30)
        .background(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        .clipShape(Capsule())
    }

    private func segment(_ option: (id: String?, label: String)) -> some View {
        let selected = selection == option.id
        let isHover = hovered == option.label
        return Button {
            withAnimation(.qlBouncy) { selection = option.id }
        } label: {
            HStack(spacing: 4) {
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(option.label).font(.ql(11.5, .medium))
            }
            .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    if isHover && !selected {
                        Color.white.opacity(0.06)
                    }
                    if selected {
                        Capsule().fill(Color.white.opacity(0.16))
                            .matchedGeometryEffect(id: "segPill", in: ns)
                            .padding(2)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .onHover { h in withAnimation(.qlHover) { hovered = h ? option.label : nil } }
    }
}
