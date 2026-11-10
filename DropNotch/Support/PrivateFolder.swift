import Darwin
import Foundation
import os

/// Folders only this account can open (D47). Everything goes through file descriptors and never follows a symlink, so
/// a link put in a folder's place can't make DropNotch change, fill or empty another folder with its own access.
///
/// Swift note: these are the C calls from Darwin (`open`, `fstat`, `fchmod`); each returns -1 and sets `errno` on
/// failure. Only the error number is logged, never a path.
enum PrivateFolder {
    /// DropNotch's folder in Application Support.
    static let applicationSupport = URL.applicationSupportDirectory.appending(path: "DropNotch")

    /// Creates `folder` 0700, or sets an existing one to 0700, and sets tray.json and Notes/note.txt in it to 0600
    /// (D47). Called at launch, before any module starts. Only the folder itself and those two files: nothing
    /// recursive.
    static func secureApplicationSupport(_ folder: URL = applicationSupport) {
        if mkdir(folder.path, 0o700) != 0, errno != EEXIST { return log("create", errno) }
        guard let dir = open(folder.path) else { return }
        defer { close(dir) }
        guard fchmod(dir, 0o700) == 0 else { return log("chmod", errno) }
        restrictFile(dir, "tray.json")
        if let notes = open("Notes", in: dir) {
            restrictFile(notes, "note.txt")
            close(notes)
        }
    }

    /// Opens a directory without following a symlink at its last component, and only if this account owns it.
    /// - Parameter parent: a directory's descriptor that `path` is relative to; the current folder by default.
    /// - Returns: the descriptor, which the caller closes; nil when it is missing, a link, not a directory, or another
    ///   account's (the reason is logged, except a missing folder).
    static func open(_ path: String, in parent: Int32 = AT_FDCWD) -> Int32? {
        let dir = openat(parent, path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard dir >= 0 else {
            if errno != ENOENT { log("open", errno) }
            return nil
        }
        var info = stat()
        guard fstat(dir, &info) == 0, info.st_uid == getuid() else {
            log("owner", errno)
            close(dir)
            return nil
        }
        return dir
    }

    /// Sets a regular file this account owns to 0600; a missing file, or anything else at that name, is left alone.
    private static func restrictFile(_ dir: Int32, _ name: String) {
        let file = openat(dir, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard file >= 0 else {
            if errno != ENOENT { log("open file", errno) }
            return
        }
        defer { close(file) }
        var info = stat()
        guard fstat(file, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else { return }
        if fchmod(file, 0o600) != 0 { log("chmod file", errno) }
    }

    private static func log(_ step: StaticString, _ code: Int32) {
        Logger.settings.error("Private folder \(String(describing: step), privacy: .public) failed: \(code)")
    }
}
