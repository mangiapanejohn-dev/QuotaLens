import SwiftUI

/// Hourly usage bars (oldest → newest) that rise from the baseline in a
/// staggered cascade on appear, with optional reset markers.
struct TimelineChart: View {
    let values: [Double]
    var color: Color
    var resetMarkers: [Double] = []
    var replay: Int = 0

    @State private var risen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach(values.indices, id: \.self) { i in
                        let full = max(geo.size.height * CGFloat(values[i] / maxV), 3)
                        Capsule()
                            .fill(values[i] > 0 ? color.opacity(0.85) : Palette.track)
                            .frame(height: risen ? full : 3)
                            .frame(maxWidth: .infinity)
                            .animation(reduceMotion ? nil : .qlBouncy.delay(Double(i) * 0.02), value: risen)
                    }
                }
                ForEach(resetMarkers.indices, id: \.self) { i in
                    Rectangle()
                        .fill(Palette.danger.opacity(0.85))
                        .frame(width: 1.5, height: geo.size.height)
                        .position(x: geo.size.width * min(max(resetMarkers[i], 0), 1),
                                  y: geo.size.height / 2)
                        .opacity(risen ? 1 : 0)
                }
            }
        }
        .onAppear { reveal() }
        .onChange(of: replay) { _, _ in
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { risen = false }
            reveal()
        }
    }

    private func reveal() {
        if reduceMotion { risen = true } else { risen = true }
    }
}
