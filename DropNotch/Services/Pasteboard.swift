import AppKit

/// What the user allows for clipboard reads (D7a, D7c).
enum PasteboardAccess {
    /// Always Allow, or macOS 14.0–15.3, which has no setting and no alert: contents may be read in the background.
    case allowed
    /// Ask, or never asked yet. A read raises the macOS alert and blocks the main thread until it is answered (D7c).
    case ask
    /// Always Deny: reads fail silently.
    case denied
}

/// The parts of `NSPasteboard` that clipboard history uses, so tests can fake the clipboard.
/// Main actor: under the privacy setting AppKit throws when the pasteboard is used off the main thread (D7b).
@MainActor
protocol Pasteboard: AnyObject {
    var changeCount: Int { get }
    var access: PasteboardAccess { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    @discardableResult func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    @discardableResult func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: Pasteboard {
    var access: PasteboardAccess {
        guard #available(macOS 15.4, *) else { return .allowed }
        switch accessBehavior {
        case .alwaysAllow: return .allowed
        case .alwaysDeny: return .denied
        // `default` (never asked) and `ask` both raise the alert. A case added later is treated the same, so it
        // never leads to a background read.
        default: return .ask
        }
    }
}
