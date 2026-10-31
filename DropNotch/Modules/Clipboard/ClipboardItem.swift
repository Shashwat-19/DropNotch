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

    init(_ content: Content) {
        self.content = content
        thumbnail = if case .image(let data, _) = content { Self.thumbnail(of: data) } else { nil }
    }

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

    /// One line for the row: leading space trimmed, line breaks as spaces, capped so a huge copy stays cheap to lay out.
    var preview: String {
        String((text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
            .components(separatedBy: .newlines).joined(separator: " ")
    }

    /// A lone http or https URL, such as one copied from a browser's address bar.
    static func isLink(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host() != nil
    }
}
