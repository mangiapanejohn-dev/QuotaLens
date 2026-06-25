import SwiftUI

/// Type ramp. SF Pro for text, SF Pro Rounded for gauge figures (Fitness-ring
/// feel), SF Mono for tabular data. Always pair number views with
/// `.monospacedDigit()` so live values don't jitter.
extension Font {
    static func ql(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Geometric (Roboto-like) figures for metrics.
    static func qlRound(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    static func qlMono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Standard eyebrow label (uppercase, tracked) used for section headers.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ql(9, .semibold))
            .tracking(0.6)
            .foregroundStyle(Palette.textTertiary)
    }
}

/// Compact value formatting.
enum Format {
    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    static func tokens(_ value: Double) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:     return String(format: "%.0fK", value / 1_000)
        default:           return String(format: "%.0f", value)
        }
    }

    static func dollars(_ value: Double) -> String {
        value >= 100 ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
    }

    static func reset(_ date: Date?) -> String? {
        guard let date else { return nil }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "resets now" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours >= 24 { return "resets in \(hours / 24)d \(hours % 24)h" }
        return hours > 0 ? "resets in \(hours)h \(minutes)m" : "resets in \(minutes)m"
    }
}
