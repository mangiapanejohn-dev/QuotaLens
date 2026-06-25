import SwiftUI

/// Official Claude / Codex brand marks (bundled monochrome templates, tintable).
/// Falls back to an SF Symbol when the asset isn't found (e.g. `swift run`
/// outside the bundle).
struct BrandLogo: View {
    let toolName: String
    var size: CGFloat = 13
    var tint: Color = Palette.textPrimary

    var body: some View {
        if let asset = Self.assetName(for: toolName), let image = NSImage(named: asset) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint)
        } else {
            Image(systemName: Self.fallbackSymbol(for: toolName))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    static func assetName(for tool: String) -> String? {
        if tool.hasPrefix("claude") { return "ClaudeMark" }
        if tool == "codex" { return "CodexMark" }
        return nil
    }

    static func fallbackSymbol(for tool: String) -> String {
        if tool.hasPrefix("claude") { return "sparkles" }
        if tool == "codex" { return "chevron.left.forwardslash.chevron.right" }
        return "gauge.with.dots.needle.bottom.50percent"
    }
}
