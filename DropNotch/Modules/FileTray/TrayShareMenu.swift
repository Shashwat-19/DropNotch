import AppKit
import SwiftUI

/// Opens the system share menu below the tray's Share button, from a click or a key press (D40). Replaces `ShareLink`,
/// which SwiftUI gives no way to open from Return or Space.
@MainActor
final class TrayShareMenu {
    private weak var anchor: NSView?

    func show(_ urls: [URL]) {
        guard let anchor else { return }
        NSSharingServicePicker(items: urls).show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    /// An empty view behind the button, so the menu has something to point at.
    struct Anchor: NSViewRepresentable {
        let menu: TrayShareMenu

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            menu.anchor = view
            return view
        }

        func updateNSView(_ view: NSView, context: Context) { menu.anchor = view }
    }
}
