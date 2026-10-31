import Foundation

/// Result of media probing containing dimensions, duration, and file size.
public struct MediaProbeResult: Equatable, Sendable {
    public let width: Int?
    public let height: Int?
    public let duration: Double?
    public let fileSize: Int64?

    public init(
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        fileSize: Int64? = nil
    ) {
        self.width = width
        self.height = height
        self.duration = duration
        self.fileSize = fileSize
    }
}

/// Protocol for probing media properties (dimensions, duration, size).
public protocol MediaProbe: Sendable {
    func probe(url: URL) throws -> MediaProbeResult
}

/// Production ffprobe-backed implementation of MediaProbe.
public final class FFprobeMediaProbe: MediaProbe {
    public init() {}

    public func probe(url: URL) throws -> MediaProbeResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw PastaError.fileNotFound(url.path)
        }

        let fileSize = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        // 1. Probe video stream width, height, and format duration
        let inv = Invocation(
            toolName: "ffprobe",
            arguments: [
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=width,height:format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                "--",
                url.path
            ]
        )

        do {
            let (outStr, _) = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 30)
            let lines = outStr.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            var width: Int?
            var height: Int?
            var duration: Double?

            for line in lines {
                if let val = Int(line) {
                    if width == nil {
                        width = val
                    } else if height == nil {
                        height = val
                    }
                } else if let dur = Double(line) {
                    duration = dur
                }
            }

            // If duration was not found in video stream (or for audio files), query format duration explicitly
            if duration == nil {
                let durInv = Invocation(
                    toolName: "ffprobe",
                    arguments: ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", "--", url.path]
                )
                if let (durStr, _) = try? JobRunner.shared.executeCapture(invocation: durInv, timeoutSeconds: 15) {
                    duration = Double(durStr.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            // Fallback for image dimensions if stream v:0 had no width/height
            if width == nil || height == nil {
                if let dims = MediaTools.shared.probeDimensions(url: url) {
                    width = dims.width
                    height = dims.height
                }
            }

            if width == nil && height == nil && duration == nil {
                throw PastaError.invalidInput("Could not probe media dimensions or duration for '\(url.lastPathComponent)'")
            }

            return MediaProbeResult(
                width: width,
                height: height,
                duration: duration,
                fileSize: fileSize > 0 ? fileSize : nil
            )
        } catch {
            throw PastaError.invalidInput("Failed to probe media '\(url.lastPathComponent)': \(error.localizedDescription)")
        }
    }
}

/// Fake media probe for unit and integration testing without spawning ffprobe.
public final class FakeMediaProbe: MediaProbe, @unchecked Sendable {
    public var results: [String: MediaProbeResult] = [:]
    public var shouldThrow: Error?

    public init(results: [String: MediaProbeResult] = [:], shouldThrow: Error? = nil) {
        self.results = results
        self.shouldThrow = shouldThrow
    }

    public func probe(url: URL) throws -> MediaProbeResult {
        if let err = shouldThrow {
            throw err
        }
        if let res = results[url.lastPathComponent] ?? results[url.path] {
            return res
        }
        if let defaultRes = results["*"] {
            return defaultRes
        }
        throw PastaError.invalidInput("Probing failed: '\(url.lastPathComponent)' not found in fake probe results")
    }
}

/// Singleton registry for the active media probe, allowing test overrides.
public final class MediaProbeService: @unchecked Sendable {
    public static let shared = MediaProbeService()

    private var currentProbe: MediaProbe = FFprobeMediaProbe()
    private let lock = NSLock()

    public var probe: MediaProbe {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentProbe
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            currentProbe = newValue
        }
    }

    public func setOverride(_ probe: MediaProbe?) {
        lock.lock()
        defer { lock.unlock() }
        currentProbe = probe ?? FFprobeMediaProbe()
    }
}
