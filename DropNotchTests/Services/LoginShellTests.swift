import XCTest
@testable import DropNotch

final class LoginShellTests: XCTestCase {
    private let account = LoginShell.Account(shell: "/opt/homebrew/bin/fish", home: "/Users/you", user: "you")
    private let shells: Set<String> = ["/bin/zsh", "/bin/bash", "/opt/homebrew/bin/fish"]

    private func make(_ account: LoginShell.Account? = nil, shells: Set<String>? = nil, executable: Bool = true,
                      inherited: [String: String] = [:], locale: String = "en_GB") -> LoginShell {
        LoginShell.make(account: account ?? self.account, allowedShells: shells ?? self.shells,
                        isExecutable: { _ in executable }, inherited: inherited, version: "0.2.0", locale: locale)
    }

    private func env(_ shell: LoginShell) -> [String: String] {
        Dictionary(uniqueKeysWithValues: shell.environment.map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
        })
    }

    func testTheAccountShellAsALoginShellInTheHomeFolder() {
        let shell = make()
        XCTAssertEqual(shell.executable, "/opt/homebrew/bin/fish")
        XCTAssertEqual(shell.argv0, "-fish", "from the shell's name, not a fixed -zsh (L6)")
        XCTAssertEqual(shell.directory, "/Users/you")
        XCTAssertEqual(env(shell)["SHELL"], "/opt/homebrew/bin/fish")
    }

    func testAnUnlistedRelativeOrUnrunnableShellFallsBackToZsh() {
        var relative = account
        relative.shell = "bin/zsh"
        var empty = account
        empty.shell = ""
        for shell in [make(shells: ["/bin/zsh"]), make(relative), make(empty), make(executable: false)] {
            XCTAssertEqual(shell.executable, "/bin/zsh")
            XCTAssertEqual(shell.argv0, "-zsh")
            XCTAssertEqual(env(shell)["SHELL"], "/bin/zsh")
        }
    }

    func testTheEnvironmentIsAnAllowListNotDropNotchsOwn() {
        let shell = make(inherited: ["DYLD_INSERT_LIBRARIES": "/tmp/x.dylib", "XPC_SERVICE_NAME": "x",
                                     "XCTestConfigurationFilePath": "/tmp/t", "PATH": "/evil:/usr/bin",
                                     "SHELL": "/bin/sh", "HOME": "/elsewhere", "TMPDIR": "/var/folders/x/T/",
                                     "SSH_AUTH_SOCK": "/private/tmp/agent", "LANG": "fr_FR.UTF-8"])
        XCTAssertEqual(env(shell), [
            "TERM": "xterm-256color", "COLORTERM": "truecolor", "TERM_PROGRAM": "DropNotch",
            "TERM_PROGRAM_VERSION": "0.2.0", "HOME": "/Users/you", "USER": "you", "LOGNAME": "you",
            "SHELL": "/opt/homebrew/bin/fish", "PATH": LoginShell.basePath, "LANG": "fr_FR.UTF-8",
            "TMPDIR": "/var/folders/x/T/", "SSH_AUTH_SOCK": "/private/tmp/agent",
        ])
    }

    func testPosixLocaleDropsTheScript() {
        XCTAssertEqual(LoginShell.posixLocale(language: "zh", region: "CN"), "zh_CN")
        XCTAssertEqual(LoginShell.posixLocale(language: "en", region: "GB"), "en_GB")
        XCTAssertEqual(LoginShell.posixLocale(language: "sr", region: nil), "en_US")
        XCTAssertEqual(LoginShell.posixLocale(language: nil, region: "DE"), "en_US")
    }

    func testLangFallsBackToTheLocale() {
        XCTAssertEqual(env(make())["LANG"], "en_GB.UTF-8")
        XCTAssertEqual(env(make(inherited: ["LANG": ""], locale: "de_DE@calendar=gregorian"))["LANG"], "de_DE.UTF-8")
        XCTAssertNil(env(make())["TMPDIR"])
    }

    /// The real account on this Mac: a shell that runs, and nothing from the test host's environment.
    func testCurrentUsesAnExecutableShellAndAFreshEnvironment() {
        let shell = LoginShell.current()
        XCTAssertTrue(LoginShell.isExecutableFile(shell.executable))
        XCTAssertTrue(shell.argv0.hasPrefix("-"))
        XCTAssertFalse(shell.environment.contains { $0.hasPrefix("DYLD_") || $0.hasPrefix("XCTest") || $0.hasPrefix("XPC_") })
    }

    /// The real check behind "an executable regular file": no folders, no plain files, nothing missing.
    func testIsExecutableFile() {
        XCTAssertTrue(LoginShell.isExecutableFile("/bin/zsh"))
        XCTAssertFalse(LoginShell.isExecutableFile("/bin"), "a folder")
        XCTAssertFalse(LoginShell.isExecutableFile("/etc/shells"), "not executable")
        XCTAssertFalse(LoginShell.isExecutableFile("/bin/no-such-shell-\(UUID())"))
        XCTAssertFalse(LoginShell.isExecutableFile(""))
    }
}
