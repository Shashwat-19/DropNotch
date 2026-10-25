import XCTest
@testable import DropNotch

@MainActor
final class AppDelegateTests: XCTestCase {
    // If Xcode stopped setting the variable, the test host would start real modules again.
    func testTheTestRunIsRecognisedAsATestHost() {
        XCTAssertTrue(AppDelegate.isTestHost)
    }
}
