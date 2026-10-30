import Foundation

public final class MetadataTools {
    public static let shared = MetadataTools()
    public init() {}

    public static let allowedTags: Set<String> = [
        "title", "author", "artist", "comment", "description",
        "date", "copyright", "album", "genre", "year"
    ]

    public func readMetadata(from url: URL) throws -> [String: Any] {
        let ext = url.pathExtension.lowercased()
        let isMedia = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "mp3", "m4a", "wav", "flac", "aac", "ogg", "opus", "aiff", "aif"].contains(ext)

        if isMedia, let ffprobe = ToolLocator.shared.findTool("ffprobe") {
            let p = Process()
            p.executableURL = ffprobe
            p.arguments = ["-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", url.path]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }

        // For images, PDF, and documents, use exiftool
        if let exiftool = ToolLocator.shared.findTool("exiftool") {
            let p = Process()
            p.executableURL = exiftool
            p.arguments = ["-json", url.path]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], let first = arr.first {
                return first
            }
        }
        return [:]
    }

    public func formatMetadata(from url: URL, asJSON: Bool) throws -> String {
        let meta = try readMetadata(from: url)
        if asJSON {
            let data = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "{}"
        } else {
            var lines: [String] = []
            for (key, val) in meta.sorted(by: { $0.key < $1.key }) {
                lines.append("\(key): \(val)")
            }
            return lines.joined(separator: "\n")
        }
    }

    public func editMetadata(
        input: URL,
        output: URL,
        tags: [String: String],
        runner: JobRunner,
        jobId: UUID
    ) throws {
        // Validate all tag names against allow-list
        for tag in tags.keys {
            let lower = tag.lowercased()
            guard Self.allowedTags.contains(lower) else {
                throw PastaError.invalidInput("Tag '\(tag)' is not allowed. Allowed tags: \(Self.allowedTags.sorted().joined(separator: ", "))")
            }
        }

        let ext = input.pathExtension.lowercased()
        let isMedia = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "mp3", "m4a", "wav", "flac", "aac", "ogg", "opus", "aiff", "aif"].contains(ext)

        let fm = FileManager.default
        if isMedia {
            var ffmpegArgs = ["-nostdin", "-y", "-i", input.path]
            for (tag, val) in tags {
                ffmpegArgs.append(contentsOf: ["-metadata", "\(tag.lowercased())=\(val)"])
            }
            ffmpegArgs.append(contentsOf: ["-c", "copy", output.path])
            let inv = Invocation(toolName: "ffmpeg", arguments: ffmpegArgs)
            try runner.execute(invocation: inv, jobId: jobId)
        } else {
            if fm.fileExists(atPath: output.path) {
                try fm.removeItem(at: output)
            }
            try fm.copyItem(at: input, to: output)

            var exifArgs = ["-overwrite_original"]
            for (tag, val) in tags {
                exifArgs.append("-\(tag)=\(val)")
            }
            exifArgs.append(output.path)
            let inv = Invocation(toolName: "exiftool", arguments: exifArgs)
            try runner.execute(invocation: inv, jobId: jobId)
        }

        // Second read-back verification
        let readBack = try readMetadata(from: output)
        for (tag, expectedVal) in tags {
            let direct = (readBack[tag] ?? readBack[tag.capitalized]) as? String
            let fmtTags = (readBack["format"] as? [String: Any])?["tags"] as? [String: Any]
            let inFmt = (fmtTags?[tag.lowercased()] ?? fmtTags?[tag]) as? String
            let found = direct ?? inFmt
            if let found = found {
                guard found == expectedVal else {
                    throw PastaError.executionFailed(tool: "metadata.edit", exitCode: 1, output: "Read-back mismatch for tag '\(tag)': expected '\(expectedVal)', got '\(found)'")
                }
            }
        }
    }
}
