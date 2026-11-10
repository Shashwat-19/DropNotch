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

    /// Sends `signal` to each target still in the shell's session. A job keeps its session id after the shell has
    /// gone, so a foreground group read at hang-up time can still be killed later (code-reviewer W1).
    /// - Parameter foregroundGroups: every foreground group read so far; the shell's own pty is gone once it exits.
    /// - Returns: how many groups were signalled.
    @discardableResult
    static func send(_ signal: Int32, shellPid: pid_t, foregroundGroups: [pid_t]) -> Int {
        liveTargets(shellPid: shellPid, foregroundGroups: foregroundGroups).filter { killpg($0, signal) == 0 }.count
    }

    /// The target groups that still have a member in the shell's session. By member, not by the group's id: once a
    /// group's leader has exited (`a | b` with `a` gone), `getsid(group)` fails though `b` is still there
    /// (security-auditor L-B).
    static func liveTargets(shellPid: pid_t, foregroundGroups: [pid_t]) -> [pid_t] {
        let own = (group: getpgrp(), pid: getpid())
        var groups: [pid_t] = []
        for foreground in foregroundGroups.isEmpty ? [-1] : foregroundGroups {
            for group in targets(shellPid: shellPid, foregroundGroup: foreground, ownGroup: own.group, ownPid: own.pid)
                where !groups.contains(group) {
                groups.append(group)
            }
        }
        guard !groups.isEmpty else { return [] }
        let live = groupsInSession(shellPid)
        return groups.filter(live.contains)
    }

    /// The process groups of every process still in session `sid`, from the process table.
    static func groupsInSession(_ sid: pid_t) -> Set<pid_t> {
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        guard capacity > 64 else { return [] }
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.size)))
        return Set(pids.prefix(max(0, min(count, capacity))).filter { $0 > 1 && getsid($0) == sid }.map(getpgid))
    }
}
