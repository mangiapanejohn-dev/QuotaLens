import SwiftUI

/// Pill segmented control for the stats time range. The active highlight slides
/// between pills with a shared matchedGeometry, so switching ranges glides.
struct RangeSelector: View {
    let selected: StatsRange
    let customLabel: String
    let onSelect: (StatsRange) -> Void
    let onCustom: () -> Void

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 3) {
            ForEach(StatsRange.presets, id: \.self) { range in
                pill(range.label, active: selected == range) { onSelect(range) }
            }
            pill(customLabel, active: selected.isCustom, action: onCustom)
        }
        .padding(3)
        .background(Capsule().fill(Palette.tile))
        .overlay(Capsule().strokeBorder(Palette.stroke.opacity(0.6), lineWidth: 1))
        .animation(.qlSnappy, value: selected)
    }

    private func pill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.ql(11, .semibold))
                .foregroundStyle(active ? Palette.ink : Palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if active {
                        Capsule().fill(Palette.brand)
                            .matchedGeometryEffect(id: "rangeHighlight", in: ns)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
