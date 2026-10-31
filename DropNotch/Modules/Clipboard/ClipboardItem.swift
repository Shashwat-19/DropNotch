import AppKit

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
    /// Decoded once here rather than on every redraw. `NSImage` decodes lazily, on first draw.
    let image: NSImage?

    init(_ content: Content) {
        self.content = content
        if case .image(let data, _) = content { image = NSImage(data: data) } else { image = nil }
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
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// A lone http or https URL, such as one copied from a browser's address bar.
    static func isLink(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host() != nil
    }
}
