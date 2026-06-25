import AppKit

/// Renders the menu-bar status image: a progress ring plus the percentage in
/// SF Rounded, coloured by threshold. Drawn with Core Graphics so it stays
/// crisp at status-bar size and keeps its colour (non-template).
enum StatusIcon {
    static func image(ratio: Double, toolName: String?) -> NSImage {
        let clamped = min(max(ratio, 0), 1)
        let color = nsColor(ratio: ratio, tool: toolName)
        let text = "\(Int((ratio * 100).rounded()))"

        let base = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor,
                          size: 10.5) ?? base
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (text as NSString).size(withAttributes: textAttrs)

        let ringDiameter: CGFloat = 14
        let spacing: CGFloat = 3.5
        let height: CGFloat = 18
        let width = ringDiameter + spacing + ceil(textSize.width) + 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let ringRect = NSRect(x: 1, y: (height - ringDiameter) / 2,
                                  width: ringDiameter, height: ringDiameter)
            let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
            let radius = ringDiameter / 2 - 1.4
            let lineWidth: CGFloat = 2.0

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            NSColor.white.withAlphaComponent(0.20).setStroke()
            track.lineWidth = lineWidth
            track.stroke()

            if clamped > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius,
                              startAngle: 90, endAngle: 90 - 360 * clamped, clockwise: true)
                color.setStroke()
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                arc.stroke()
            }

            let textPoint = NSPoint(x: ringRect.maxX + spacing, y: (height - textSize.height) / 2)
            (text as NSString).draw(at: textPoint, withAttributes: textAttrs)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func nsColor(ratio: Double, tool: String?) -> NSColor {
        if ratio >= 0.9 { return NSColor(srgbRed: 1, green: 0x54 / 255, blue: 0x49 / 255, alpha: 1) }
        if let tool, tool.hasPrefix("claude") {
            return NSColor(srgbRed: 0xF0 / 255, green: 0xA0 / 255, blue: 0x7C / 255, alpha: 1)
        }
        switch tool {
        case "codex": return NSColor(srgbRed: 0x46 / 255, green: 0xDC / 255, blue: 0xB6 / 255, alpha: 1)
        default:      return NSColor(srgbRed: 0xB7 / 255, green: 0xA7 / 255, blue: 1.0, alpha: 1)
        }
    }
}
