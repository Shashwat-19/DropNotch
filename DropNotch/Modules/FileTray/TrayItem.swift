import Foundation

/// One file in the tray (D6, D32): a bookmark to the original, or, when there is no original to point at, a copy
/// in the tray's own storage.
struct TrayItem: Codable, Identifiable, Equatable {
    let id: UUID
    /// The file name when last seen. Shown while the original is missing; for a copy it is also its file name.
    var name: String
    /// A plain bookmark to the original. DropNotch isn't sandboxed (D4), so no security scope. Nil for a copy.
    var bookmark: Data?
    /// The folder under the tray's storage that holds the copy. Nil for a bookmark.
    var copyFolder: UUID?

    /// Whether `name` is a single path component, so a copy's path can't leave its folder. tray.json is
    /// outside the app and could be edited, and removing an item deletes its copy.
    var hasSafeName: Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }
}
