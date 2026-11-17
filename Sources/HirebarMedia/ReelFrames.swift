import AppKit
import CoreGraphics
import Foundation
import HirebarDomain
import ImageIO

extension ReelRenderer {
    public static func stillImage(_ page: URL, chrome: String, scratch: URL) -> CGImage? {
        let png = page.deletingPathExtension().appendingPathExtension("png")
        guard SlideRenderer.shoot(page, to: png, chrome: chrome, scratch: scratch, width: width, height: height),
            let source = CGImageSourceCreateWithURL(png as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    public static func captionWords(_ words: [WordTiming], at elapsed: Double) -> (words: [String], active: Int)? {
        guard let first = words.first, elapsed >= first.start - 0.05 else { return nil }
        var active = words.count - 1
        for (index, word) in words.enumerated() where elapsed < word.end {
            active = index
            break
        }
        let start = (active / wordsPerCaption) * wordsPerCaption
        let end = min(words.count, start + wordsPerCaption)
        return (words[start..<end].map(\.word), active - start)
    }

    static func pixelBuffer(
        pool: CVPixelBufferPool?, image: CGImage, zoom: Double,
        caption: (words: [String], active: Int)?, accent: NSColor
    ) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        if let pool {
            _ = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        } else {
            _ = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &created)
        }
        guard let buffer = created else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        let scaledWidth = Double(width) * zoom
        let scaledHeight = Double(height) * zoom
        let origin = CGPoint(x: (Double(width) - scaledWidth) / 2, y: (Double(height) - scaledHeight) / 2)
        context.draw(image, in: CGRect(origin: origin, size: CGSize(width: scaledWidth, height: scaledHeight)))
        if let caption { drawCaption(caption.words, active: caption.active, accent: accent, in: context) }
        return buffer
    }

    public static func drawCaption(_ words: [String], active: Int, accent: NSColor, in context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        let font = NSFont.systemFont(ofSize: 84, weight: .heavy)
        let text = NSMutableAttributedString()
        for (index, word) in words.enumerated() {
            text.append(
                NSAttributedString(
                    string: (index == 0 ? "" : " ") + word,
                    attributes: [
                        .font: font,
                        .foregroundColor: index == active ? accent : NSColor.white,
                        .strokeColor: NSColor.black,
                        .strokeWidth: -6,
                        .paragraphStyle: paragraph,
                        .shadow: shadow,
                    ]))
        }
        let margin = 90.0
        let box = CGSize(width: Double(width) - margin * 2, height: 600)
        let bounds = text.boundingRect(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let rect = CGRect(
            x: margin, y: Double(height) - captionCenterFromTop - bounds.height / 2,
            width: box.width, height: bounds.height + 12)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }

    public static func color(_ hex: String) -> NSColor {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return .systemYellow }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
