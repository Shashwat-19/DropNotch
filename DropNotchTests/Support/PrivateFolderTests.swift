import XCTest
@testable import DropNotch

final class PrivateFolderTests: XCTestCase {
    private var root: URL!
    private let files = FileManager.default

    /// A fresh folder per test, so nothing touches the real Application Support folder.
    override func setUpWithError() throws {
        root = files.temporaryDirectory.appending(path: "PrivateFolderTests-\(UUID())")
        try files.createDirectory(at: root, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        try? files.removeItem(at: root)
    }

    private var folder: URL { root.appending(path: "DropNotch") }

    private func mode(_ url: URL) throws -> Int {
        try XCTUnwrap(files.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
    }

    private func make(_ url: URL, mode: Int) throws {
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
        try files.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
    }

    func testCreatesTheFolder0700() throws {
        PrivateFolder.secureApplicationSupport(folder)
        XCTAssertEqual(try mode(folder), 0o700)
    }

    func testAnExistingInstallGetsA0700FolderAnd0600TrayAndNoteFilesOnly() throws {
        try files.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        let tray = folder.appending(path: "tray.json"), note = folder.appending(path: "Notes/note.txt")
        let other = folder.appending(path: "clipboard.json"), trayFile = folder.appending(path: "Tray/a.txt")
        for url in [tray, note, other, trayFile] { try make(url, mode: 0o644) }

        PrivateFolder.secureApplicationSupport(folder)

        XCTAssertEqual(try mode(folder), 0o700)
        XCTAssertEqual(try mode(tray), 0o600)
        XCTAssertEqual(try mode(note), 0o600)
        XCTAssertEqual(try mode(other), 0o644, "only the two named files")
        XCTAssertEqual(try mode(trayFile), 0o644, "nothing recursive")
        XCTAssertEqual(try mode(folder.appending(path: "Notes")), 0o755, "the folder only, not its subfolders")
    }

    func testASymlinkInTheFolderPlaceIsNotFollowed() throws {
        let elsewhere = root.appending(path: "Elsewhere")
        try files.createDirectory(at: elsewhere, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        try make(elsewhere.appending(path: "tray.json"), mode: 0o644)
        try files.createSymbolicLink(at: folder, withDestinationURL: elsewhere)

        PrivateFolder.secureApplicationSupport(folder)

        XCTAssertEqual(try mode(elsewhere), 0o755)
        XCTAssertEqual(try mode(elsewhere.appending(path: "tray.json")), 0o644)
    }

    func testASymlinkedTrayFileIsNotFollowed() throws {
        try files.createDirectory(at: folder, withIntermediateDirectories: false)
        let target = root.appending(path: "target.txt")
        try make(target, mode: 0o644)
        try files.createSymbolicLink(at: folder.appending(path: "tray.json"), withDestinationURL: target)

        PrivateFolder.secureApplicationSupport(folder)

        XCTAssertEqual(try mode(target), 0o644)
        XCTAssertEqual(try mode(folder), 0o700)
    }

    func testOpenRefusesALinkAndAFileButOpensAFolder() throws {
        try files.createDirectory(at: folder, withIntermediateDirectories: false)
        try files.createSymbolicLink(at: root.appending(path: "Link"), withDestinationURL: folder)
        try make(root.appending(path: "file"), mode: 0o644)

        XCTAssertNil(PrivateFolder.open(root.appending(path: "Link").path))
        XCTAssertNil(PrivateFolder.open(root.appending(path: "file").path))
        XCTAssertNil(PrivateFolder.open(root.appending(path: "missing").path))
        let dir = try XCTUnwrap(PrivateFolder.open(folder.path))
        close(dir)
    }
}
