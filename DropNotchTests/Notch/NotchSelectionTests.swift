import XCTest
@testable import DropNotch

final class NotchSelectionTests: XCTestCase {
    private func opacity(_ isSelected: Bool, _ groupHasSelection: Bool, _ increasedContrast: Bool) -> Double {
        NotchSelection.opacity(isSelected: isSelected, groupHasSelection: groupHasSelection,
                               increasedContrast: increasedContrast)
    }

    func testSelectedItemIsFullWhiteRegardlessOfContrast() {
        XCTAssertEqual(opacity(true, true, false), 1)
        XCTAssertEqual(opacity(true, true, true), 1)
    }

    func testNothingDimsWhenTheGroupHasNoSelection() {
        // isSelected without groupHasSelection can't happen in the views, but must still read as full white.
        for isSelected in [false, true] {
            for contrast in [false, true] {
                XCTAssertEqual(opacity(isSelected, false, contrast), 1)
            }
        }
    }

    func testUnselectedItemDimsInAGroupWithASelection() {
        XCTAssertEqual(opacity(false, true, false), 0.5)
        XCTAssertEqual(opacity(false, true, true), 0.75)
    }

    // MARK: - WCAG contrast

    /// WCAG 2 relative luminance of a grey sRGB channel value.
    private func luminance(_ srgb: Double) -> Double {
        srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
    }

    /// Contrast of white at `alpha` over the black notch, composited in sRGB (gamma-encoded) space.
    private func contrastOnBlack(alpha: Double) -> Double {
        (luminance(alpha) + 0.05) / (luminance(0) + 0.05)
    }

    func testDimmedGreyMeetsWCAGTextContrastOnBlack() {
        let normal = contrastOnBlack(alpha: opacity(false, true, false))
        XCTAssertGreaterThanOrEqual(normal, 4.5, "dimmed text must meet WCAG AA 4.5:1")
        XCTAssertEqual(normal, 5.28, accuracy: 0.01)
        XCTAssertGreaterThan(contrastOnBlack(alpha: opacity(false, true, true)), normal,
                             "Increase Contrast must brighten the grey")
    }

    func testContrastFormulaSanity() {
        XCTAssertEqual(contrastOnBlack(alpha: 1), 21, accuracy: 1e-9)
        XCTAssertEqual(contrastOnBlack(alpha: 0), 1, accuracy: 1e-9)
    }
}
