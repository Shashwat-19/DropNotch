import XCTest
@testable import DropNotch

final class NotchAppearanceTests: XCTestCase {
    func testGlassOnlyWhenChosenAvailableAndTransparencyAllowed() {
        XCTAssertTrue(NotchAppearance.liquidGlass.usesGlass(reduceTransparency: false, glassAvailable: true))
        XCTAssertFalse(NotchAppearance.liquidGlass.usesGlass(reduceTransparency: true, glassAvailable: true))
        XCTAssertFalse(NotchAppearance.liquidGlass.usesGlass(reduceTransparency: false, glassAvailable: false),
                       "macOS 14–25 keep black")
        XCTAssertFalse(NotchAppearance.black.usesGlass(reduceTransparency: false, glassAvailable: true))
    }

    func testBlackWhenNothingIsSaved() throws {
        let name = "NotchAppearanceTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let saved = defaults.string(forKey: NotchAppearance.key).flatMap(NotchAppearance.init(rawValue:)) ?? .black
        XCTAssertEqual(saved, .black)
        XCTAssertEqual(NotchAppearance(rawValue: "liquidGlass"), .liquidGlass, "the saved raw value is stable")
    }
}
