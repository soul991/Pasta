import Foundation

public final class MediaTools {
    public static let shared = MediaTools()
    public init() {}

    public func probeDimensions(url: URL) -> (width: Int, height: Int)? {
        guard let ffprobe = ToolLocator.shared.findTool("ffprobe") else { return nil }
        let p = Process()
        p.executableURL = ffprobe
        p.arguments = ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
            let parts = str.split(separator: "x").compactMap { Int($0) }
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        } catch {
            return nil
        }
    }

    public static func atempoFilter(factor: Double) -> String {
        var f = factor
        var filters: [String] = []
        while f > 2.0 {
            filters.append("atempo=2.0")
            f /= 2.0
        }
        while f < 0.5 {
            filters.append("atempo=0.5")
            f /= 0.5
        }
        let rounded = (f * 1000).rounded() / 1000
        filters.append("atempo=\(rounded)")
        return filters.joined(separator: ",")
    }

    public func splitVideo(
        input: URL,
        outputDir: URL,
        timesString: String,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDir.path) {
            try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        let totalDuration = Compressor.shared.probeDuration(url: input)
        let splitPoints = timesString
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0.0 && $0 < totalDuration }
            .sorted()

        var cutPoints: [Double] = [0.0]
        cutPoints.append(contentsOf: splitPoints)
        cutPoints.append(totalDuration)

        let ext = input.pathExtension.isEmpty ? "mp4" : input.pathExtension
        let baseName = input.deletingPathExtension().lastPathComponent

        for i in 0..<(cutPoints.count - 1) {
            let start = cutPoints[i]
            let end = cutPoints[i + 1]
            let partNumber = String(format: "%02d", i + 1)
            let partURL = outputDir.appendingPathComponent("\(baseName)_part\(partNumber).\(ext)")

            let startStr = FormatRegistry.formatFfmpegTimestamp(start)
            let endStr = FormatRegistry.formatFfmpegTimestamp(end)

            let inv = Invocation(
                toolName: "ffmpeg",
                arguments: [
                    "-nostdin", "-y",
                    "-ss", startStr,
                    "-to", endStr,
                    "-i", input.path,
                    "-c", "copy",
                    partURL.path
                ]
            )
            try runner.execute(invocation: inv, jobId: jobId)
        }
    }

    public func joinVideos(
        inputs: [URL],
        output: URL,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        guard inputs.count >= 2 else {
            throw PastaError.invalidInput("Joining videos requires at least 2 files")
        }
        let scratchDir = try OutputPlanner.makeTempDirectory()
        let fm = FileManager.default
        defer { try? fm.removeItem(at: scratchDir) }

        let listFile = scratchDir.appendingPathComponent("concat_list.txt")
        var content = ""
        for inp in inputs {
            let escapedPath = inp.path.replacingOccurrences(of: "'", with: "'\\''")
            content += "file '\(escapedPath)'\n"
        }
        try content.write(to: listFile, atomically: true, encoding: .utf8)

        // Try copy demuxer first
        let copyInv = Invocation(
            toolName: "ffmpeg",
            arguments: [
                "-nostdin", "-y",
                "-f", "concat",
                "-safe", "0",
                "-i", listFile.path,
                "-c", "copy",
                output.path
            ]
        )
        do {
            try runner.execute(invocation: copyInv, jobId: jobId)
        } catch {
            // Re-encode fallback
            if fm.fileExists(atPath: output.path) {
                try? fm.removeItem(at: output)
            }
            let reencodeInv = Invocation(
                toolName: "ffmpeg",
                arguments: [
                    "-nostdin", "-y",
                    "-f", "concat",
                    "-safe", "0",
                    "-i", listFile.path,
                    "-c:v", "libx264", "-crf", "23", "-preset", "medium",
                    "-c:a", "aac",
                    output.path
                ]
            )
            try runner.execute(invocation: reencodeInv, jobId: jobId)
        }
    }

    public func normalizeAudio(
        input: URL,
        output: URL,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        guard let ffmpeg = ToolLocator.shared.findTool("ffmpeg") else {
            throw PastaError.missingTool("ffmpeg")
        }

        // Pass 1: measure
        let p1 = Process()
        p1.executableURL = ffmpeg
        p1.arguments = ["-nostdin", "-i", input.path, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"]
        let stderrPipe = Pipe()
        p1.standardOutput = Pipe()
        p1.standardError = stderrPipe
        try? p1.run()
        p1.waitUntilExit()

        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        var measuredI = "-16.0"
        var measuredTP = "-1.5"
        var measuredLRA = "11.0"
        var measuredThresh = "-26.0"
        var targetOffset = "0.0"

        if let jsonStart = errStr.range(of: "{", options: .backwards),
           let jsonEnd = errStr.range(of: "}", options: .backwards) {
            let jsonSubstring = String(errStr[jsonStart.lowerBound...jsonEnd.upperBound])
            if let data = jsonSubstring.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                measuredI = (json["input_i"] as? String) ?? measuredI
                measuredTP = (json["input_tp"] as? String) ?? measuredTP
                measuredLRA = (json["input_lra"] as? String) ?? measuredLRA
                measuredThresh = (json["input_thresh"] as? String) ?? measuredThresh
                targetOffset = (json["target_offset"] as? String) ?? targetOffset
            }
        }

        let af = "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=\(measuredI):measured_TP=\(measuredTP):measured_LRA=\(measuredLRA):measured_thresh=\(measuredThresh):offset=\(targetOffset):linear=true"
        let inv = Invocation(
            toolName: "ffmpeg",
            arguments: ["-nostdin", "-y", "-i", input.path, "-af", af, output.path]
        )
        try runner.execute(invocation: inv, jobId: jobId)
    }
}
