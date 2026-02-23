import Foundation
import Combine

enum SudoStatus: Equatable {
    case enabled
    case disabled
    case enabledExternal
    case error(String)
    case notPermitted
    case unknown

    var label: String {
        switch self {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .enabledExternal: return "Enabled (External)"
        case .error: return "Error"
        case .notPermitted: return "Not Permitted"
        case .unknown: return "Checking…"
        }
    }

    var canToggle: Bool {
        switch self {
        case .enabled, .disabled, .error: return true
        case .enabledExternal, .notPermitted, .unknown: return false
        }
    }

    var isEnabled: Bool {
        switch self {
        case .enabled, .enabledExternal: return true
        default: return false
        }
    }
}

@MainActor
final class SudoManager: ObservableObject {
    @Published private(set) var status: SudoStatus = .unknown
    @Published private(set) var isBusy = false

    private let managedFilePath = "/private/etc/sudoers.d/passwordless-sudo"
    private let pendingFilePath = "/private/etc/sudoers.d/.passwordless-sudo.pending"

    private var username: String {
        NSUserName()
    }

    init() {
        refreshStatus()
    }

    // MARK: - Status Detection

    func refreshStatus() {
        let fileExists = FileManager.default.fileExists(atPath: managedFilePath)
        let sudoTestPasses = runSudoTest()

        switch (fileExists, sudoTestPasses) {
        case (true, .success):
            status = .enabled
        case (false, .failure):
            status = .disabled
        case (false, .success):
            status = .enabledExternal
        case (true, .failure):
            status = .error("File exists but sudo test fails")
        case (_, .notPermitted):
            status = .notPermitted
        }
    }

    private enum SudoTestResult {
        case success
        case failure
        case notPermitted
    }

    private func runSudoTest() -> SudoTestResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-k", "-n", "/usr/bin/true"]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure
        }

        if process.terminationStatus == 0 {
            return .success
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if stderrString.contains("not allowed") || stderrString.contains("not in the sudoers file") {
            return .notPermitted
        }

        return .failure
    }

    // MARK: - Enable

    func enable() {
        guard !isBusy, status.canToggle else { return }
        isBusy = true

        Task {
            defer {
                isBusy = false
                refreshStatus()
            }

            let rule = "\(username) ALL=(ALL) NOPASSWD: ALL"

            // Single privileged script: write pending → chmod → validate → move → validate → rollback on failure
            let script = """
            /usr/bin/printf '%s\\n' \(appleScriptQuoted(rule)) > \(pendingFilePath) && \
            /usr/sbin/chown root:wheel \(pendingFilePath) && \
            /bin/chmod 0440 \(pendingFilePath) && \
            /usr/sbin/visudo -c -f \(pendingFilePath) && \
            /bin/mv -f \(pendingFilePath) \(managedFilePath) && \
            /usr/sbin/visudo -c || \
            { /bin/rm -f \(managedFilePath) \(pendingFilePath); exit 1; }
            """

            do {
                try runPrivileged(script: script)
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Disable

    func disable() {
        guard !isBusy, status.canToggle else { return }
        isBusy = true

        Task {
            defer {
                isBusy = false
                refreshStatus()
            }

            let script = """
            /bin/rm -f \(managedFilePath) && \
            /usr/sbin/visudo -c
            """

            do {
                try runPrivileged(script: script)
                // Clear cached credentials (unprivileged)
                clearSudoCache()
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func toggle() {
        if status.isEnabled {
            disable()
        } else {
            enable()
        }
    }

    // MARK: - Privilege Escalation

    private func runPrivileged(script: String) throws {
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escapedScript)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"

            // User cancelled the auth dialog — not an error
            if stderrString.contains("User canceled") || stderrString.contains("-128") {
                return
            }

            throw NSError(
                domain: "SudoManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: stderrString.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }
    }

    private func clearSudoCache() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-k"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Helpers

    private func appleScriptQuoted(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
