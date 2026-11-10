import Carbon
import SwiftTerm
import XCTest
@testable import DropNotch

/// What can be checked without starting a shell.
@MainActor
final class SwiftTermSessionTests: XCTestCase {
    /// Programs can neither read nor write the clipboard (D48, design review L2).
    func testTheGuardedDelegateRefusesTheClipboard() {
        let view = LocalProcessTerminalView(frame: .zero)
        let guarded = GuardedTerminalDelegate(terminal: view)
        let before = NSPasteboard.general.changeCount
        guarded.clipboardCopy(source: view, content: Data("hi".utf8))
        XCTAssertNil(guarded.clipboardRead(source: view))
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
        XCTAssertEqual(guarded.kittyClipboardCapabilities(source: view), [])
        XCTAssertEqual(guarded.kittyClipboardRead(source: view, location: .standard, mimeType: "text/plain"), .denied)
    }

    /// OSC 52 written by a program, through the real parser: no clipboard change.
    func testOSC52FromOutputDoesNotTouchTheClipboard() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        let before = NSPasteboard.general.changeCount
        view.feed(text: "\u{1B}]52;c;aGk=\u{07}\u{1B}]52;c;?\u{07}")
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.2))
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
    }

    func testANewSessionIsBlackAndUnstarted() {
        let session = SwiftTermSession(fontSize: 11, scrollback: 1_000)
        let view = session.view as! LocalProcessTerminalView
        XCTAssertEqual(view.nativeBackgroundColor, .black)
        XCTAssertTrue(view.caretViewTracksFocus)
        session.hangUp()
        session.hangUpAndWait()
    }

    /// Balanced: never left on (design review L1).
    func testSecureKeyboardEntryTurnsOffAgain() {
        let secure = SecureKeyboardEntry()
        secure.set(true)
        XCTAssertTrue(IsSecureEventInputEnabled())
        secure.set(true)
        secure.set(false)
        XCTAssertFalse(IsSecureEventInputEnabled())
        secure.set(false)
        XCTAssertFalse(IsSecureEventInputEnabled())
    }
}
