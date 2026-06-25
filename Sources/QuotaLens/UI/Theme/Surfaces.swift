import SwiftUI

extension View {
    /// Frameless group: a very subtle raised fill, no border. Colour comes from
    /// the data inside, not a frame.
    func glassCard(tint: Color, radius: CGFloat = 20, glow: Bool = false, danger: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(Palette.tile))
            .overlay(shape.fill(tint.opacity(0.05)))
            .overlay {
                if danger { shape.fill(Palette.danger.opacity(0.10)) }
            }
    }

    /// Frameless neutral tile.
    func tile(_ radius: CGFloat = 16) -> some View {
        self.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.tile))
    }

    /// Flat solid progress fill.
    func glassFill(_ tint: Color) -> some View {
        self.foregroundStyle(tint)
    }
}
