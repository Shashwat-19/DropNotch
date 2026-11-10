import Darwin

/// Which processes ending a terminal session signals (D48, design review M3). The shell leads its own session
/// (forkpty calls setsid), so its process group and its foreground job's are signalled, and only while they still
/// belong to that session: a pid can be reused, and `killpg(0)` or `kill(-1)` would reach DropNotch or every
/// process the user owns.
enum TerminalHangUp {
    /// Process groups above 1, never DropNotch's own group or pid, each once.
    static func targets(shellPid: pid_t, foregroundGroup: pid_t, ownGroup: pid_t, ownPid: pid_t) -> [pid_t] {
        guard shellPid > 1 else { return [] }
        var groups: [pid_t] = []
        for group in [shellPid, foregroundGroup] where group > 1 && group != ownGroup && group != ownPid
            && !groups.contains(group) {
            groups.append(group)
        }
        return groups
    }

    /// Sends `signal` to each target still in the shell's session.
    /// - Returns: how many groups were signalled.
    @discardableResult
    static func send(_ signal: Int32, shellPid: pid_t, foregroundGroup: pid_t) -> Int {
        targets(shellPid: shellPid, foregroundGroup: foregroundGroup, ownGroup: getpgrp(), ownPid: getpid())
            .filter { getsid($0) == shellPid && killpg($0, signal) == 0 }
            .count
    }
}
