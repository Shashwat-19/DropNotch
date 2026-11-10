import XCTest
@testable import DropNotch

final class NotchKeyRouteTests: XCTestCase {
    private func route(_ characters: String, _ modifiers: NSEvent.ModifierFlags = [], keyCode: UInt16 = 0,
                       owner: Bool = true, marked: Bool = false) -> NotchKeyRoute {
        NotchKeyRoute.route(keyCode: keyCode, characters: characters, modifiers: modifiers, ownerFocused: owner,
                            hasMarkedText: marked)
    }

    /// D31 as before: Escape closes a keyboard-opened notch unless an input method is composing.
    func testEscapeWithoutTheTerminal() {
        XCTAssertEqual(route("\u{1B}", keyCode: 53, owner: false), .dismiss)
        XCTAssertEqual(route("\u{1B}", .command, keyCode: 53, owner: false), .dismiss)
        XCTAssertEqual(route("\u{1B}", keyCode: 53, owner: false, marked: true), .pass)
    }

    func testEscapeGoesToTheTerminal() {
        XCTAssertEqual(route("\u{1B}", keyCode: 53), .pass)
    }

    func testCopyPasteAndSelectAllInTheTerminal() {
        XCTAssertEqual(route("c", .command), .copy)
        XCTAssertEqual(route("v", .command), .paste)
        XCTAssertEqual(route("a", .command), .selectAll)
        XCTAssertEqual(route("C", [.command, .capsLock]), .copy, "Caps Lock doesn't matter")
    }

    func testTabsAndSettingsShortcutsStillWork() {
        for key in ["1", "5", "9", ","] { XCTAssertEqual(route(key, .command), .pass, key) }
    }

    func testOtherCommandKeysAreSwallowedInTheTerminal() {
        for key in ["q", "w", "h", "m", "n", "t", "0", "."] { XCTAssertEqual(route(key, .command), .swallow, key) }
        XCTAssertEqual(route("c", [.command, .shift]), .swallow)
        XCTAssertEqual(route("v", [.command, .option]), .swallow)
    }

    func testShellKeysPass() {
        XCTAssertEqual(route("c", .control), .pass)
        XCTAssertEqual(route("\t"), .pass)
        XCTAssertEqual(route("\u{F700}", .function, keyCode: 126), .pass)
    }

    /// Without the terminal, ⌘ keys keep AppKit's normal handling.
    func testCommandKeysElsewhereAreUntouched() {
        for key in ["q", "c", "v", "1"] { XCTAssertEqual(route(key, .command, owner: false), .pass, key) }
    }
}
