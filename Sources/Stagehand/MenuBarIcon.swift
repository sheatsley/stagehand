// Draws the menu bar icon: a display outline with a "restore" arrow inside.
import AppKit

enum MenuBarIcon {
    /// Returns the menu bar icon as a template image. Template images use only
    /// their shape (alpha), and macOS colors them to match the menu bar
    /// (white on a dark bar, black on a light bar, dimmed when inactive), the
    /// same way Apple's own menu bar icons behave.
    static func make() -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            // Draw the display outline as a rounded rectangle
            let display = NSRect(x: 1, y: 1.5, width: 18, height: 13)
            let outline = NSBezierPath(roundedRect: display, xRadius: 2.5, yRadius: 2.5)
            outline.lineWidth = 1.5
            NSColor.black.setStroke()
            outline.stroke()

            // Draw Apple's counterclockwise-arrow SF Symbol centered inside it, at its heaviest weight
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .black)
            if let arrow = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let origin = NSPoint(x: display.midX - arrow.size.width / 2,
                                     y: display.midY - arrow.size.height / 2)
                arrow.draw(in: NSRect(origin: origin, size: arrow.size))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = AppInfo.current.name
        return image
    }
}
