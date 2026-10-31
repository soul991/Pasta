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

        if isMedia {
            let inv = Invocation(
                toolName: "ffprobe",
                arguments: ["-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", "--", url.path]
            )
            let (outStr, _) = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 30)
            if let data = outStr.data(using: .utf8),
               let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        } else {
            let inv = Invocation(
                toolName: "exiftool",
                arguments: ["-json", "--", url.path]
            )
            let (outStr, _) = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 30)
            if let data = outStr.data(using: .utf8),
               let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = arr.first {
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
                let lower = tag.lowercased()
                ffmpegArgs.append(contentsOf: ["-metadata", "\(lower)=\(val)"])
                if lower == "author" {
                    ffmpegArgs.append(contentsOf: ["-metadata", "artist=\(val)"])
                }
            }
            ffmpegArgs.append(contentsOf: ["-c", "copy", "--", output.path])
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
            exifArgs.append("--")
            exifArgs.append(output.path)
            let inv = Invocation(toolName: "exiftool", arguments: exifArgs)
            try runner.execute(invocation: inv, jobId: jobId)
        }

        // Second read-back verification
        let readBack = try readMetadata(from: output)
        for (tag, expectedVal) in tags {
            let lower = tag.lowercased()
            var foundVal: String?
            for (k, v) in readBack {
                if k.lowercased() == lower {
                    foundVal = "\(v)"
                    break
                }
            }
            if foundVal == nil && (lower == "author" || lower == "artist") {
                for syn in ["artist", "author", "creator", "by-line"] {
                    for (k, v) in readBack {
                        if k.lowercased() == syn {
                            foundVal = "\(v)"
                            break
                        }
                    }
                    if foundVal != nil { break }
                }
            }
            if foundVal == nil && (lower == "date" || lower == "year") {
                for syn in ["date", "year", "createdate", "datetimeoriginal"] {
                    for (k, v) in readBack {
                        if k.lowercased() == syn {
                            foundVal = "\(v)"
                            break
                        }
                    }
                    if foundVal != nil { break }
                }
            }
            if foundVal == nil, let fmtTags = (readBack["format"] as? [String: Any])?["tags"] as? [String: Any] {
                for (k, v) in fmtTags {
                    if k.lowercased() == lower {
                        foundVal = "\(v)"
                        break
                    }
                }
                if foundVal == nil && (lower == "author" || lower == "artist") {
                    for syn in ["artist", "author", "creator"] {
                        for (k, v) in fmtTags {
                            if k.lowercased() == syn {
                                foundVal = "\(v)"
                                break
                            }
                        }
                        if foundVal != nil { break }
                    }
                }
            }

            guard let found = foundVal else {
                throw PastaError.executionFailed(tool: "metadata.edit", exitCode: 1, output: "Read-back verification failed: tag '\(tag)' was not found in output metadata")
            }
            guard found == expectedVal || found.contains(expectedVal) else {
                throw PastaError.executionFailed(tool: "metadata.edit", exitCode: 1, output: "Read-back mismatch for tag '\(tag)': expected '\(expectedVal)', got '\(found)'")
            }
        }
    }
}
