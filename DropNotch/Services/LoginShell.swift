import Darwin
import Foundation
import os

/// How the Terminal tab starts the user's shell (D48): the shell from the account record, as a login shell, in the
/// account's home folder, with a fresh environment rather than DropNotch's own. Pure apart from `current()`, so tests
/// can feed it any account.
struct LoginShell: Equatable {
    let executable: String
    /// "-" plus the shell's name: the convention that makes it a login shell, which reads /etc/zprofile (path_helper,
    /// so the full PATH) and the user's own setup files.
    let argv0: String
    let directory: String
    /// "NAME=value" pairs, the form SwiftTerm passes to `execve`.
    let environment: [String]

    static let fallbackShell = "/bin/zsh"
    /// What the login shell starts from; path_helper and the user's setup add the rest, as in Terminal.app.
    static let basePath = "/usr/bin:/bin:/usr/sbin:/sbin"
    /// Inherited only if DropNotch has them: a temp folder and an ssh agent.
    static let passedThrough = ["TMPDIR", "SSH_AUTH_SOCK"]

    struct Account: Equatable {
        var shell: String
        var home: String
        var user: String
    }

    /// - Parameters:
    ///   - allowedShells: /etc/shells.
    ///   - isExecutable: true for an executable regular file.
    ///   - inherited: DropNotch's environment; only `LANG` and `passedThrough` are read from it.
    ///   - locale: for `LANG` when DropNotch has none, such as "en_GB".
    static func make(account: Account, allowedShells: Set<String>, isExecutable: (String) -> Bool,
                     inherited: [String: String], version: String, locale: String) -> LoginShell {
        let usable = account.shell.hasPrefix("/") && allowedShells.contains(account.shell) && isExecutable(account.shell)
        let shell = usable ? account.shell : fallbackShell
        var environment = [
            "TERM=xterm-256color", "COLORTERM=truecolor",
            // Not Apple_Terminal: /etc/zshrc would then save sessions to ~/.zsh_sessions (design review L6).
            "TERM_PROGRAM=DropNotch", "TERM_PROGRAM_VERSION=\(version)",
            "HOME=\(account.home)", "USER=\(account.user)", "LOGNAME=\(account.user)", "SHELL=\(shell)",
            "PATH=\(basePath)",
            "LANG=\(inherited["LANG"].flatMap { $0.isEmpty ? nil : $0 } ?? "\(locale.split(separator: "@").first ?? "en_US").UTF-8")",
        ]
        environment += passedThrough.compactMap { name in inherited[name].map { "\(name)=\($0)" } }
        return LoginShell(executable: shell, argv0: "-" + (shell as NSString).lastPathComponent,
                          directory: account.home, environment: environment)
    }

    /// The signed-in account's shell, from the account record (`getpwuid`), not `$SHELL`.
    static func current() -> LoginShell {
        let record = getpwuid(getuid())
        let account = Account(shell: record.flatMap { String(validatingCString: $0.pointee.pw_shell) } ?? "",
                              home: record.flatMap { String(validatingCString: $0.pointee.pw_dir) }
                                  ?? FileManager.default.homeDirectoryForCurrentUser.path,
                              user: record.flatMap { String(validatingCString: $0.pointee.pw_name) } ?? NSUserName())
        var shells = Set<String>()
        setusershell()
        while let entry = getusershell() { shells.insert(String(cString: entry)) }
        endusershell()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let shell = make(account: account, allowedShells: shells, isExecutable: isExecutableFile,
                         inherited: ProcessInfo.processInfo.environment, version: version,
                         locale: Locale.current.identifier)
        // Never the path: it can name the user.
        if shell.executable != account.shell { Logger.terminal.notice("Account shell not usable; using the fallback") }
        return shell
    }

    static func isExecutableFile(_ path: String) -> Bool {
        var info = stat()
        return stat(path, &info) == 0 && info.st_mode & S_IFMT == S_IFREG && access(path, X_OK) == 0
    }
}
