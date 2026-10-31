import XCTest
@testable import DropNotch

final class TrayItemTests: XCTestCase {
    private func item(_ name: String) -> TrayItem { TrayItem(id: UUID(), name: name, copyFolder: UUID()) }

    func testSingleComponentNamesAreSafe() {
        for name in ["a.txt", "..hidden", "a..b", ".gitignore", "Café ☕️.png", "a\\b", "~"] {
            XCTAssertTrue(item(name).hasSafeName, name)
        }
    }

    func testNamesThatCouldLeaveTheFolderAreUnsafe() {
        for name in ["", ".", "..", "../x", "a/b", "/", "/etc/passwd", "a\0b"] {
            XCTAssertFalse(item(name).hasSafeName, name)
        }
    }

    func testCodableRoundTrip() throws {
        let items = [TrayItem(id: UUID(), name: "a.txt", bookmark: Data([1, 2, 3])), item("b.jpg")]
        XCTAssertEqual(try JSONDecoder().decode([TrayItem].self, from: JSONEncoder().encode(items)), items)
    }
}
