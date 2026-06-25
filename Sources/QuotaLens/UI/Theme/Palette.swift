import SwiftUI

/// QuotaLens colour system — a "gauge" family that warms from cool teal at low
/// usage through amber to coral red near the limit, so the threshold reads as
/// temperature (cool = headroom, hot = near limit). Tints are white-alpha so
/// they layer over both graphite tiles and Liquid Glass.
enum Palette {
    // Material 3 dark tonal surfaces (elevation = lighter tone, not shadow).
    static let ink = Color(hex: 0x0E0D11)              // surfaceContainerLowest
    static let background = Color(hex: 0x141218)        // surface
    static let tile = Color(hex: 0x211F26)             // surfaceContainer
    static let tileRaised = Color(hex: 0x2B2930)        // surfaceContainerHigh

    static let stroke = Color(hex: 0x49454F)           // outlineVariant
    static let strokeStrong = Color(hex: 0x938F99)      // outline
    static let track = Color(hex: 0x3A383F)            // progress track

    /// Brand — wordmark, aggregate ring.
    static let brand = Color(hex: 0x46DCB6)

    /// Per-tool Material primaries (Claude warm coral, Codex teal-green).
    static func toolColor(_ tool: String) -> Color {
        if tool.hasPrefix("claude") { return Color(hex: 0xF0A07C) }
        switch tool {
        case "codex": return Color(hex: 0x46DCB6)
        default:      return Color(hex: 0xB7A7FF)
        }
    }

    /// Material error.
    static let danger = Color(hex: 0xFF5449)

    static let textPrimary = Color(hex: 0xE6E0E9)       // onSurface
    static let textSecondary = Color(hex: 0xCAC4D0)      // onSurfaceVariant
    static let textTertiary = Color(hex: 0x938F99)       // outline
    static let textQuaternary = Color.white.opacity(0.30)

    // Heat stops as normalised RGB (cool teal → amber → coral red).
    private static let low: (Double, Double, Double)  = (0x37 / 255, 0xC8 / 255, 0xD6 / 255)
    private static let mid: (Double, Double, Double)  = (0xFF / 255, 0xC2 / 255, 0x4A / 255)
    private static let high: (Double, Double, Double) = (0xFF / 255, 0x5A / 255, 0x52 / 255)

    /// Continuous heat colour for a 0…1 usage ratio.
    static func heat(_ ratio: Double) -> Color {
        let r = min(max(ratio, 0), 1)
        let rgb = r <= 0.65 ? mix(low, mid, r / 0.65) : mix(mid, high, (r - 0.65) / 0.35)
        return Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }

    /// Top-lit gradient for bars and rings (lighter highlight → heat).
    static func heatGradient(_ ratio: Double) -> LinearGradient {
        let base = heat(ratio)
        return LinearGradient(
            colors: [lighten(base, 0.22), base],
            startPoint: .top, endPoint: .bottom)
    }

    // Threshold helpers kept for callers that work in coarse levels.
    static func color(for level: ThresholdLevel) -> Color {
        switch level {
        case .neutral: return heat(0.28)
        case .warning: return heat(0.8)
        case .critical: return heat(1.0)
        }
    }

    static func fill(for level: ThresholdLevel) -> LinearGradient {
        switch level {
        case .neutral: return heatGradient(0.28)
        case .warning: return heatGradient(0.8)
        case .critical: return heatGradient(1.0)
        }
    }

    // MARK: - helpers

    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> (Double, Double, Double) {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private static func lighten(_ color: Color, _ amount: Double) -> Color {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return Color(.sRGB,
                     red: Double(ns.redComponent) + (1 - Double(ns.redComponent)) * amount,
                     green: Double(ns.greenComponent) + (1 - Double(ns.greenComponent)) * amount,
                     blue: Double(ns.blueComponent) + (1 - Double(ns.blueComponent)) * amount,
                     opacity: 1)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
