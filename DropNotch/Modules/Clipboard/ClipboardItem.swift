import AppKit
import ImageIO

/// One copied thing in the clipboard history (D7). Lives in memory only.
struct ClipboardItem: Identifiable {
    enum Content: Equatable {
        case text(String)
        /// An http or https URL on its own, kept as the text that was copied.
        case link(String)
        /// The pasteboard's PNG or TIFF data, written back unchanged.
        case image(Data, NSPasteboard.PasteboardType)
    }

    let id = UUID()
    let content: Content
    /// A row-sized thumbnail, made once. The full image is never decoded for display: a 5K screenshot decodes to
    /// about 59 MB, which the 10 MB and 50 MB caps on the stored data wouldn't bound (code-reviewer W2).
    let thumbnail: NSImage?
    /// One line for the row, made once: leading space dropped, line breaks as spaces, at most 200 characters, so a long
    /// copy is never scanned again on redraw (security-auditor M2).
    let preview: String

    init(_ content: Content) {
        self.content = content
        let text: Substring = switch content {
        case .text(let text), .link(let text): text.drop(while: \.isWhitespace).prefix(200)
        case .image: ""
        }
        preview = text.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        thumbnail = if case .image(let data, _) = content { Self.thumbnail(of: data) } else { nil }
    }

    /// Whether pasteboard bytes are a PNG or TIFF (by content, not the claimed type) of at most `maxPixels`, read from the
    /// header alone. A small file can claim a huge size and decode to gigabytes (security-auditor M1).
    static func isAcceptableImage(_ data: Data, maxPixels: Int = 25_000_000) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?, type == "public.png" || type == "public.tiff",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return fits(width: width, height: height, maxPixels: maxPixels)
    }

    /// Overflow-safe: a crafted header's sizes could multiply past `Int.max`, and Swift traps on overflow.
    static func fits(width: Int, height: Int, maxPixels: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        return !overflow && pixels <= maxPixels
    }

    // shortcut: the thumbnail is made on the main thread; a 25 MP PNG decodes in full once (about 100 MB, briefly).
    // Move it off the main actor if image copies stall the notch.
    /// At most 64 px on the long side: the row draws it at 32 × 20 pt, 2× on Retina.
    private static func thumbnail(of data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { NSImage(cgImage: $0, size: .zero) }
    }

    /// The text, for search and the row. Nil for an image.
    var text: String? {
        switch content {
        case .text(let text), .link(let text): text
        case .image: nil
        }
    }

    var isLink: Bool {
        if case .link = content { true } else { false }
    }

    /// A lone http or https URL, such as one copied from a browser's address bar.
    static func isLink(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host() != nil
    }
}
