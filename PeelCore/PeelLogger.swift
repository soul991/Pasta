import Foundation

public final class PeelLogger {
    public static let shared = PeelLogger()

    private let logFileURL: URL
    private let lock = NSLock()
    private let dateFormatter = ISO8601DateFormatter()

    public init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Peel")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("peel.log")
    }

    public func log(_ message: String, level: String = "INFO") {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"

        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    public func info(_ message: String) {
        log(message, level: "INFO")
    }

    public func error(_ message: String) {
        log(message, level: "ERROR")
    }
}
