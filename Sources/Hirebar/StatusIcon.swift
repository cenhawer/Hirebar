import AppKit
import HirebarDomain

enum StatusIcon {
    static let symbol = "briefcase"

    static func make(dot: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
            if let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: "Hirebar")?
                .withSymbolConfiguration(config) {
                let size = glyph.size
                glyph.draw(in: NSRect(x: 1, y: (rect.height - size.height) / 2 + 1, width: size.width, height: size.height))
            }
            let dotRect = NSRect(x: rect.width - 9, y: 0.5, width: 8, height: 8)
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: dotRect.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            dot.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
