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

    /// code-reviewer S4: a Russian layout types "с" (Cyrillic) for ⌘C; the key's position decides.
    func testCopyPasteAndTabsOnANonLatinLayout() {
        XCTAssertEqual(route("с", .command, keyCode: 8), .copy)
        XCTAssertEqual(route("м", .command, keyCode: 9), .paste)
        XCTAssertEqual(route("ф", .command, keyCode: 0), .selectAll)
        XCTAssertEqual(route("б", .command, keyCode: 43), .pass)
        XCTAssertEqual(route("й", .command, keyCode: 12), .swallow, "⌘Q's position, still swallowed")
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

    // MARK: A real NotchPanel, never shown, with synthesized key events

    /// Stands in for the terminal: a first responder that owns its keys. Never forwards anything to the app's menu.
    private final class KeyOwnerView: NSView, NotchKeyOwner {
        var actions: [String] = []
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) { actions.append("keyDown \(event.keyCode)") }
        @objc func copy(_ sender: Any?) { actions.append("copy") }
        @objc func paste(_ sender: Any?) { actions.append("paste") }
        override func selectAll(_ sender: Any?) { actions.append("selectAll") }
    }

    private final class PlainView: NSView {
        var actions: [String] = []
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) { actions.append("keyDown \(event.keyCode)") }
    }

    @MainActor
    private func panel(with view: NSView) -> NotchPanel {
        let panel = NotchPanel(contentView: view)
        XCTAssertTrue(panel.makeFirstResponder(view))
        XCTAssertTrue(panel.firstResponder === view)
        XCTAssertFalse(panel.isVisible)
        return panel
    }

    @MainActor
    private func key(_ characters: String, _ modifiers: NSEvent.ModifierFlags = [], keyCode: UInt16,
                     in panel: NSWindow) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: panel.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
    }

    /// ⌘Q, ⌘W, ⌘H and ⌘M stop at the panel while the owner is focused; ⌘C, ⌘V and ⌘A reach the owner's actions.
    @MainActor
    func testPanelRoutesCommandKeysToTheOwner() {
        let owner = KeyOwnerView()
        let panel = panel(with: owner)
        for (character, code) in [("q", 12), ("w", 13), ("h", 4), ("m", 46)] as [(String, UInt16)] {
            XCTAssertTrue(panel.performKeyEquivalent(with: key(character, .command, keyCode: code, in: panel)), character)
        }
        XCTAssertEqual(owner.actions, [], "swallowed, not handed to the owner either")
        XCTAssertTrue(panel.performKeyEquivalent(with: key("c", .command, keyCode: 8, in: panel)))
        XCTAssertTrue(panel.performKeyEquivalent(with: key("v", .command, keyCode: 9, in: panel)))
        XCTAssertTrue(panel.performKeyEquivalent(with: key("a", .command, keyCode: 0, in: panel)))
        XCTAssertEqual(owner.actions, ["copy", "paste", "selectAll"])
        // The tabs' ⌘1 and Settings' ⌘, are left to AppKit (no SwiftUI here, so nobody takes them).
        XCTAssertFalse(panel.performKeyEquivalent(with: key("1", .command, keyCode: 18, in: panel)))
        XCTAssertFalse(panel.performKeyEquivalent(with: key(",", .command, keyCode: 43, in: panel)))
        XCTAssertEqual(owner.actions.count, 3)
    }

    /// `sendEvent` drops a ⌘ key that got past `performKeyEquivalent`, and hands Escape to the owner, not onDismiss.
    @MainActor
    func testPanelSendEventGivesEscapeToTheOwnerAndDropsCommandQ() {
        let owner = KeyOwnerView()
        let panel = panel(with: owner)
        var dismissals = 0
        panel.onDismiss = { dismissals += 1 }
        panel.sendEvent(key("q", .command, keyCode: 12, in: panel))
        XCTAssertEqual(owner.actions, [], "⌘Q never reaches the owner's keyDown (SwiftTerm would offer it to the menu)")
        panel.sendEvent(key("\u{1B}", keyCode: 53, in: panel))
        XCTAssertEqual(dismissals, 0)
        XCTAssertEqual(owner.actions, ["keyDown 53"])
        panel.sendEvent(key("c", .control, keyCode: 8, in: panel))
        XCTAssertEqual(owner.actions, ["keyDown 53", "keyDown 8"], "⌃C goes to the shell")
    }

    /// D31 unchanged: without the owner, Escape closes the notch and doesn't reach the first responder; ⌘ keys keep
    /// AppKit's handling.
    @MainActor
    func testPanelEscapeWithoutTheOwnerDismisses() {
        let view = PlainView()
        let panel = panel(with: view)
        var dismissals = 0
        panel.onDismiss = { dismissals += 1 }
        panel.sendEvent(key("\u{1B}", keyCode: 53, in: panel))
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(view.actions, [])
        XCTAssertFalse(panel.performKeyEquivalent(with: key("\u{1B}", keyCode: 53, in: panel)),
                       "Escape isn't handled twice through performKeyEquivalent")
        XCTAssertEqual(dismissals, 1)
        XCTAssertFalse(panel.performKeyEquivalent(with: key("c", .command, keyCode: 8, in: panel)))
    }
}
