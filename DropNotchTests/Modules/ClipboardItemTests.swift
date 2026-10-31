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

    /// Crafted header sizes never trap or pass (automated security review).
    func testPixelCheckRejectsOverflowAndNonPositiveSizes() {
        XCTAssertFalse(ClipboardItem.fits(width: .max, height: .max, maxPixels: 25_000_000))
        XCTAssertFalse(ClipboardItem.fits(width: 1 << 32, height: 1 << 32, maxPixels: .max))
        XCTAssertFalse(ClipboardItem.fits(width: 0, height: 10, maxPixels: 100))
        XCTAssertFalse(ClipboardItem.fits(width: -10, height: -10, maxPixels: 1_000))
        XCTAssertTrue(ClipboardItem.fits(width: 5_000, height: 5_000, maxPixels: 25_000_000))
        XCTAssertFalse(ClipboardItem.fits(width: 5_001, height: 5_000, maxPixels: 25_000_000))
    }
}
