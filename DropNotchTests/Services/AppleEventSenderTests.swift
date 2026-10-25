import XCTest
@testable import DropNotch

// No Apple Events here: the sender's events need real players, which tests must never touch.
@MainActor
final class AppleEventSenderTests: XCTestCase {
    // `permission(ask: true)` blocks until the user answers the Automation prompt, so its queue must
    // never be the main thread, even when called from the main actor.
    func testWorkRunsOffTheMainThread() async {
        XCTAssertTrue(Thread.isMainThread)
        let ranOnMain = await AppleEventSender.run { Thread.isMainThread }
        XCTAssertFalse(ranOnMain)
    }
}
