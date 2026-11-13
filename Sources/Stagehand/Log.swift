// Simple file logging, so problems can be diagnosed after the fact.
import Foundation

/// Appends timestamped lines to ~/Library/Logs/Stagehand/stagehand.log (the
/// standard place for per-user app logs; Console.app lists it under Log
/// Reports). Each line also goes to the system log, so `log stream` still
/// works. The file is capped at about 1 MB: at launch, a larger file is moved
/// to stagehand.log.1, replacing the previous one.
enum Log {
    /// The log file's location.
    static let fileURL: URL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/Stagehand/stagehand.log")

    private static let maxSize = 1_000_000

    /// Formats timestamps as "2026-11-13 13:53:02.123" in local time.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    /// Prepares the log at launch: creates the folder and rotates the file if
    /// it has grown past the size cap.
    static func start() {
        // Make sure ~/Library/Logs/Stagehand exists
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Move an oversized log aside, keeping one older file
        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        if size > maxSize {
            let older = fileURL.appendingPathExtension("1")
            try? fileManager.removeItem(at: older)
            try? fileManager.moveItem(at: fileURL, to: older)
        }
    }

    /// Writes one line, such as "2026-11-13 13:53:02.123 [sidecar] Connected",
    /// to the log file and the system log. `category` groups related lines.
    static func write(_ category: String, _ message: String) {
        // Mirror the line to the system log
        NSLog("Stagehand [%@] %@", category, message)

        // Append the line to the file, creating the file if it doesn't exist yet
        let line = "\(formatter.string(from: Date())) [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    /// Describes an error with its domain and code as well as its message,
    /// since private-framework errors are often only identifiable by code.
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
    }
}
