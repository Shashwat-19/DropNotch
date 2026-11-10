import AppKit

/// A view that takes Escape and its own ⌘ keys while it is first responder (D48): the terminal. Defined here so the
/// panel can recognise it without depending on a module.
protocol NotchKeyOwner: AnyObject {}

/// Where `NotchPanel` sends a key (D31, D48). Pure, so the table is testable without a window.
enum NotchKeyRoute: Equatable {
    /// Close a keyboard-opened notch.
    case dismiss
    /// AppKit's normal handling: key equivalents, then the first responder.
    case pass
    case copy, paste, selectAll
    /// Dropped, so a ⌘ key can't reach DropNotch's menu (⌘Q, ⌘W, ⌘H, ⌘M) from the terminal.
    case swallow

    /// 53 is kVK_Escape.
    static let escapeKeyCode: UInt16 = 53
    /// ANSI key codes (kVK_ANSI_…) for the keys the terminal routes, used when the layout types something else.
    static let latinKeys: [UInt16: String] = [8: "c", 9: "v", 0: "a", 43: ",", 18: "1", 19: "2", 20: "3", 21: "4",
                                              23: "5", 22: "6", 26: "7", 28: "8", 25: "9"]

    /// - Parameters:
    ///   - characters: `charactersIgnoringModifiers`.
    ///   - ownerFocused: a `NotchKeyOwner` is first responder.
    ///   - hasMarkedText: an input method is composing text, which keeps Escape to cancel it.
    static func route(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags, ownerFocused: Bool,
                      hasMarkedText: Bool) -> Self {
        let modifiers = modifiers.intersection([.command, .shift, .option, .control])
        if keyCode == escapeKeyCode {
            return ownerFocused || hasMarkedText ? .pass : .dismiss
        }
        guard ownerFocused, modifiers.contains(.command) else { return .pass }
        // On a Cyrillic, Greek or Hebrew layout ⌘C doesn't give "c"; menus go by the key's position then, and so does
        // this (code-reviewer S4).
        let typed = characters?.lowercased() ?? ""
        let key = typed.unicodeScalars.allSatisfy(\.isASCII) && !typed.isEmpty ? typed : latinKeys[keyCode] ?? typed
        // The tabs' ⌘1… and Settings' ⌘, stay with SwiftUI's shortcuts.
        if key.count == 1, "123456789,".contains(key) { return .pass }
        guard modifiers == .command else { return .swallow }
        switch key {
        case "c": return .copy
        case "v": return .paste
        case "a": return .selectAll
        default: return .swallow
        }
    }
}
