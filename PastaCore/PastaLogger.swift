import Foundation

public final class PastaLogger {
    public static let shared = PastaLogger()

    public let logFileURL: URL
    private let lock = NSLock()
    private let dateFormatter = ISO8601DateFormatter()

    public init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Pasta")
        // Safe to swallow: best-effort creation of user logs directory
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("pasta.log")
    }

    private func redactSensitiveInfo(_ text: String) -> String {
        var clean = text
        let patterns = [
            "(--(?:user-|owner-)?password=)[^\\s]+",
            "(-P\\s+)[^\\s]+",
            "((?i)password[:=]\\s*)[^\\s,;]+"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                clean = regex.stringByReplacingMatches(in: clean, range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "$1[REDACTED]")
            }
        }
        return clean
    }

    public func log(_ message: String, level: String = "INFO") {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = dateFormatter.string(from: Date())
        let safeMessage = redactSensitiveInfo(message)
        let line = "[\(timestamp)] [\(level)] \(safeMessage)\n"

        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            // Safe to swallow: logging must never crash or interrupt application execution if file open fails
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                // Safe to swallow: best-effort handle cleanup
                try? handle.close()
            }
        } else {
            // Safe to swallow: best-effort initial log file write
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    public func debug(_ message: String) {
        log(message, level: "DEBUG")
    }

    public func info(_ message: String) {
        log(message, level: "INFO")
    }

    public func warning(_ message: String) {
        log(message, level: "WARN")
    }

    public func error(_ message: String) {
        log(message, level: "ERROR")
    }
}
