// Draws a placeholder app icon for the About window until a real icon exists.
import AppKit

enum AppIconArt {
    /// The accent color: a warm amber, like a stage light.
    static let accent = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.04, alpha: 1)

    /// Returns the placeholder icon: the menu bar glyph (white display outline,
    /// amber restore arrow) on a dark gray rounded tile, laid out on Apple's
    /// 1024-point macOS icon grid and scaled to `size` points.
    static func make(size: CGFloat = 512) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = rect.width / 1024

            // Fill the dark gray rounded tile (824 points with a 100-point margin, per Apple's grid)
            let tile = NSRect(x: 100, y: 100, width: 824, height: 824).scaled(by: scale)
            NSColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: tile, xRadius: 185 * scale, yRadius: 185 * scale).fill()

            // Stroke the white display outline
            let display = NSRect(x: 252, y: 322, width: 520, height: 380).scaled(by: scale)
            let outline = NSBezierPath(roundedRect: display, xRadius: 56 * scale, yRadius: 56 * scale)
            outline.lineWidth = 34 * scale
            NSColor.white.setStroke()
            outline.stroke()

            // Draw the amber restore arrow centered in the display
            let config = NSImage.SymbolConfiguration(pointSize: 190 * scale, weight: .bold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [accent]))
            if let arrow = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let origin = NSPoint(x: display.midX - arrow.size.width / 2,
                                     y: display.midY - arrow.size.height / 2)
                arrow.draw(in: NSRect(origin: origin, size: arrow.size))
            }
            return true
        }
    }
}

private extension NSRect {
    /// Scales every coordinate of the rectangle by the same factor.
    func scaled(by factor: CGFloat) -> NSRect {
        NSRect(x: origin.x * factor, y: origin.y * factor, width: width * factor, height: height * factor)
    }
}
