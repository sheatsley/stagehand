// Saves and restores Stage Manager's state by snapshotting its preferences.
import Foundation

/// Errors Stagehand reports when saving or restoring stages fails.
enum StageManagerError: LocalizedError {
    case noSnapshot
    case commandFailed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .noSnapshot:
            return "No saved stages yet. Use Save Stages first."
        case .commandFailed(let command, let output):
            return output.isEmpty ? "“\(command)” failed." : "“\(command)” failed: \(output)"
        }
    }
}

/// Stage Manager keeps its groupings in the com.apple.WindowManager
/// preferences domain. Saving exports that domain to a file; restoring
/// imports the file back and restarts the WindowManager process (launchd
/// relaunches it right away) so it rereads the restored groupings. Windows
/// stay open throughout; the screen flickers briefly during the restart.
enum StageManager {
    private static let domain = "com.apple.WindowManager"

    /// Where the snapshot lives: ~/Library/Application Support/Stagehand/WindowManager.plist
    static var snapshotURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stagehand", isDirectory: true)
            .appendingPathComponent("WindowManager.plist")
    }

    /// When the snapshot was last saved, or nil if there isn't one.
    static var lastSaved: Date? {
        try? FileManager.default.attributesOfItem(atPath: snapshotURL.path)[.modificationDate] as? Date
    }

    /// The error message from the most recent restore if it failed, or nil if it
    /// succeeded. Shown in the menu, since automatic restores have no alert.
    private(set) static var lastRestoreError: String?

    /// True if a snapshot exists to restore from.
    static var hasSnapshot: Bool {
        FileManager.default.fileExists(atPath: snapshotURL.path)
    }

    /// Exports the current Stage Manager preferences to the snapshot file,
    /// replacing any earlier snapshot. Throws if `defaults` fails.
    static func save() throws {
        // Make sure the Application Support folder exists
        try FileManager.default.createDirectory(
            at: snapshotURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Export the domain to the snapshot file
        do {
            try run("/usr/bin/defaults", ["export", domain, snapshotURL.path])
            Log.write("stages", "Saved stages to \(snapshotURL.path)")
        } catch {
            Log.write("stages", "Save failed: \(Log.describe(error))")
            throw error
        }
    }

    /// Imports the snapshot back into Stage Manager's preferences and restarts
    /// the WindowManager process so it picks them up. Throws if there's no
    /// snapshot or either command fails.
    static func restore() throws {
        do {
            // Refuse to restore when nothing has been saved
            guard hasSnapshot else { throw StageManagerError.noSnapshot }

            // Write the snapshot back into the domain
            try run("/usr/bin/defaults", ["import", domain, snapshotURL.path])

            // Restart WindowManager so it rereads the restored groupings
            try run("/usr/bin/killall", ["WindowManager"])
            lastRestoreError = nil
            Log.write("stages", "Restored stages and restarted WindowManager")
        } catch {
            // Remember the failure for the menu and the log, then pass it on
            lastRestoreError = error.localizedDescription
            Log.write("stages", "Restore failed: \(Log.describe(error))")
            throw error
        }
    }

    /// Runs a command-line tool, waits for it to finish, and throws with its
    /// error output if it exits with a nonzero status.
    private static func run(_ path: String, _ arguments: [String]) throws {
        // Launch the tool with its error output captured
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        // Turn a nonzero exit status into an error that includes the tool's message
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let command = ([URL(fileURLWithPath: path).lastPathComponent] + arguments).joined(separator: " ")
            throw StageManagerError.commandFailed(command: command, output: output)
        }
    }

    /// Returns the gray header lines for the Stage Manager part of the menu.
    static func statusLines() -> [(text: String, toolTip: String?)] {
        // Show when the snapshot was saved, if there is one
        var lines: [(text: String, toolTip: String?)]
        if let date = lastSaved {
            lines = [("Stages Last Saved", nil), (date.menuTimestamp, nil)]
        } else {
            lines = [("No Stages Saved", nil)]
        }

        // Flag a failed restore; hovering shows why
        if let error = lastRestoreError {
            lines.append(("Last Restore Failed", error))
        }
        return lines
    }
}
