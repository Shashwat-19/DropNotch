import XCTest
@testable import DropNotch

@MainActor
final class NotchHostingViewTests: XCTestCase {
    /// Only the operation mask is read by `dropOperation`; the rest is never touched.
    private final class FakeDraggingInfo: NSObject, NSDraggingInfo {
        let draggingSourceOperationMask: NSDragOperation
        init(_ mask: NSDragOperation) { draggingSourceOperationMask = mask }
        var draggingDestinationWindow: NSWindow? { nil }
        var draggingLocation: NSPoint { .zero }
        var draggedImageLocation: NSPoint { .zero }
        var draggedImage: NSImage? { nil }
        var draggingPasteboard: NSPasteboard { fatalError("unused") }
        var draggingSource: Any? { nil }
        var draggingSequenceNumber: Int { 0 }
        func slideDraggedImage(to screenPoint: NSPoint) {}
        var draggingFormation: NSDraggingFormation = .default
        var animatesToDestination = false
        var numberOfValidItemsForDrop = 0
        func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?,
                                    classes classArray: [AnyClass],
                                    searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
                                    using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
        var springLoadingHighlight: NSSpringLoadingHighlight { .none }
        func resetSpringLoading() {}
    }

    private func operation(_ mask: NSDragOperation) -> NSDragOperation {
        NotchHostingView.dropOperation(FakeDraggingInfo(mask))
    }

    // D32: never .move or .generic, which Finder treats as a move out of the original's folder.
    func testDropIsCopyElseLinkNeverMove() {
        XCTAssertEqual(operation(.every), .copy)
        XCTAssertEqual(operation([.copy, .move, .generic]), .copy)
        XCTAssertEqual(operation([.link, .move]), .link)
        XCTAssertEqual(operation([.move, .generic, .delete]), [])
        XCTAssertEqual(operation([]), [])
    }
}
