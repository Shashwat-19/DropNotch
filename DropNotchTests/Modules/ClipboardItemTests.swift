import AppKit
import XCTest
@testable import DropNotch

final class ClipboardItemTests: XCTestCase {
    func testIsLinkAcceptsLoneHTTPURLs() {
        for text in ["https://example.com", "http://example.com/path?q=1", "  https://example.com\n",
                     "HTTPS://EXAMPLE.COM"] {
            XCTAssertTrue(ClipboardItem.isLink(text), text)
        }
    }

    func testIsLinkRejectsOtherText() {
        for text in ["", "ftp://example.com", "https://", "http:example.com", "example.com",
                     "mailto:a@example.com", "https://example.com and more", "see\nhttps://example.com"] {
            XCTAssertFalse(ClipboardItem.isLink(text), text)
        }
    }

    func testPreviewTrimsJoinsLinesAndCaps() {
        XCTAssertEqual(ClipboardItem(.text("  first\nsecond\n\n")).preview, "first second")
        XCTAssertEqual(ClipboardItem(.text(String(repeating: "a", count: 300))).preview.count, 200)
    }

    func testImageHasNoTextOrPreview() {
        let item = ClipboardItem(.image(Data([1, 2, 3]), .png))
        XCTAssertNil(item.text)
        XCTAssertEqual(item.preview, "")
        XCTAssertFalse(item.isLink)
        XCTAssertTrue(ClipboardItem(.link("https://example.com")).isLink)
    }
}
