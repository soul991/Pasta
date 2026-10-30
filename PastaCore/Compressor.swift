import Foundation

public final class Compressor {
    public static let shared = Compressor()

    public init() {}

    public static func targetBytes(for sourceSize: Int64, parameters: ParameterValues) -> Int64 {
        if let modeVal = parameters["mode"], modeVal.asString == "targetSize" {
            if let targetVal = parameters["targetSize"]?.asInt64, targetVal > 0 {
                return targetVal
            }
        }
        if let targetVal = parameters["targetSize"]?.asInt64, targetVal > 0 {
            return targetVal
        }
        let percent = parameters["percent"]?.asDouble ?? 50.0
        return max(1, Int64(Double(sourceSize) * (percent / 100.0)))
    }

    public func probeDuration(url: URL) -> Double {
        do {
            let inv = Invocation(
                toolName: "ffprobe",
                arguments: ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", "--", url.path]
            )
            let (outStr, _) = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 30)
            let trimmed = outStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if let dur = Double(trimmed), dur > 0 {
                return dur
            }
        } catch {
            PastaLogger.shared.warning("probeDuration failed for '\(url.lastPathComponent)': \(error.localizedDescription)")
        }
        return 2.0
    }

    public func compressImage(
        input: URL,
        output: URL,
        parameters: ParameterValues,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: input.path)
        } catch {
            throw PastaError.invalidInput("Cannot read attributes for file '\(input.path)': \(error.localizedDescription)")
        }
        let sourceSize = (attrs[.size] as? Int64) ?? 0
        let target = Self.targetBytes(for: sourceSize, parameters: parameters)

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer { try? fm.removeItem(at: scratchDir) }

        var low = 5
        var high = 95
        var bestCandidateURL: URL? = nil
        var smallestOutputURL: URL? = nil
        var smallestOutputSize: Int64 = Int64.max

        let ext = output.pathExtension.isEmpty ? input.pathExtension : output.pathExtension
        let iterations = 8

        for i in 0..<iterations {
            if low > high { break }
            let mid = (low + high) / 2
            let iterOut = scratchDir.appendingPathComponent("iter_\(i)_\(mid).\(ext)")

            let inv: Invocation
            let inExt = input.pathExtension.lowercased()
            if inExt == "webp" {
                inv = Invocation(toolName: "cwebp", arguments: ["-q", "\(mid)", input.path, "-o", iterOut.path])
            } else if inExt == "jpg" || inExt == "jpeg" {
                inv = Invocation(toolName: "sips", arguments: ["-s", "format", "jpeg", "-s", "formatOptions", "\(mid)", input.path, "--out", iterOut.path])
            } else if inExt == "bmp" {
                inv = Invocation(toolName: "magick", arguments: [input.path, "-colors", "\(max(2, mid * 2))", iterOut.path])
            } else {
                inv = Invocation(toolName: "magick", arguments: [input.path, "-quality", "\(mid)", iterOut.path])
            }

            do {
                try runner.execute(invocation: inv, jobId: jobId)
                if fm.fileExists(atPath: iterOut.path) {
                    let size = ((try? fm.attributesOfItem(atPath: iterOut.path)[.size] as? Int64) ?? 0)
                    if size < smallestOutputSize {
                        smallestOutputSize = size
                        smallestOutputURL = iterOut
                    }
                    if size <= target {
                        bestCandidateURL = iterOut
                        low = mid + 1 // try higher quality
                    } else {
                        high = mid - 1 // try lower quality
                    }
                } else {
                    high = mid - 1
                }
            } catch {
                high = mid - 1
            }
        }

        guard let winner = bestCandidateURL ?? smallestOutputURL else {
            throw PastaError.executionFailed(tool: "compress", exitCode: 1, output: "Image compression failed to produce an output file")
        }

        let winnerSize = (try? fm.attributesOfItem(atPath: winner.path)[.size] as? Int64) ?? 0
        if winnerSize > target {
            let msg = "could not reach \(target); produced \(winnerSize)"
            PastaLogger.shared.info(msg)
            print(msg)
        }

        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        try fm.copyItem(at: winner, to: output)
    }

    public func compressVideo(
        input: URL,
        output: URL,
        parameters: ParameterValues,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: input.path)
        } catch {
            throw PastaError.invalidInput("Cannot read attributes for file '\(input.path)': \(error.localizedDescription)")
        }
        let sourceSize = (attrs[.size] as? Int64) ?? 0
        let target = Self.targetBytes(for: sourceSize, parameters: parameters)

        let duration = probeDuration(url: input)
        let totalTargetBits = Double(target) * 8.0
        let totalBitrate = max(10000.0, totalTargetBits / duration)
        let audioBitrate = min(64000.0, max(24000.0, totalBitrate * 0.15))
        let videoBitrate = max(8000.0, totalBitrate - audioBitrate)

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer { try? fm.removeItem(at: scratchDir) }

        let passlogPrefix = scratchDir.appendingPathComponent("passlog").path
        let tempOut = scratchDir.appendingPathComponent("compressed.mp4")

        // Two-pass encoding for optimal bitrate budget distribution
        let pass1Inv = Invocation(
            toolName: "ffmpeg",
            arguments: [
                "-y", "-nostdin",
                "-i", input.path,
                "-c:v", "libx264", "-b:v", "\(Int(videoBitrate))",
                "-pass", "1",
                "-passlogfile", passlogPrefix,
                "-an",
                "-f", "null",
                "/dev/null"
            ]
        )
        let pass2Inv = Invocation(
            toolName: "ffmpeg",
            arguments: [
                "-y", "-nostdin",
                "-i", input.path,
                "-c:v", "libx264", "-b:v", "\(Int(videoBitrate))",
                "-pass", "2",
                "-passlogfile", passlogPrefix,
                "-c:a", "aac", "-b:a", "\(Int(audioBitrate))",
                tempOut.path
            ]
        )

        do {
            try runner.execute(invocation: pass1Inv, jobId: jobId)
            try runner.execute(invocation: pass2Inv, jobId: jobId)
        } catch {
            // Fallback to single pass if two-pass fails
            if fm.fileExists(atPath: tempOut.path) {
                try? fm.removeItem(at: tempOut)
            }
            let singlePassInv = Invocation(
                toolName: "ffmpeg",
                arguments: [
                    "-y", "-nostdin",
                    "-i", input.path,
                    "-c:v", "libx264", "-b:v", "\(Int(videoBitrate))",
                    "-c:a", "aac", "-b:a", "\(Int(audioBitrate))",
                    tempOut.path
                ]
            )
            try runner.execute(invocation: singlePassInv, jobId: jobId)
        }

        guard fm.fileExists(atPath: tempOut.path) else {
            throw PastaError.executionFailed(tool: "ffmpeg", exitCode: 1, output: "Video compression produced no output")
        }

        let finalSize = (try? fm.attributesOfItem(atPath: tempOut.path)[.size] as? Int64) ?? 0
        if finalSize > target {
            let msg = "could not reach \(target); produced \(finalSize)"
            PastaLogger.shared.info(msg)
            print(msg)
        }

        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        try fm.moveItem(at: tempOut, to: output)
    }

    public func compressAudio(
        input: URL,
        output: URL,
        parameters: ParameterValues,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: input.path)
        } catch {
            throw PastaError.invalidInput("Cannot read attributes for file '\(input.path)': \(error.localizedDescription)")
        }
        let sourceSize = (attrs[.size] as? Int64) ?? 0
        let target = Self.targetBytes(for: sourceSize, parameters: parameters)

        let duration = probeDuration(url: input)
        let totalTargetBits = Double(target) * 8.0
        let targetBitrate = max(16000.0, totalTargetBits / duration)

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer { try? fm.removeItem(at: scratchDir) }

        let ext = output.pathExtension.isEmpty ? "mp3" : output.pathExtension
        let tempOut = scratchDir.appendingPathComponent("compressed.\(ext)")
        let inv = Invocation(
            toolName: "ffmpeg",
            arguments: [
                "-y", "-nostdin", "-i", input.path,
                "-vn", "-c:a", "libmp3lame", "-b:a", "\(Int(targetBitrate / 1000.0))k",
                tempOut.path
            ]
        )
        try runner.execute(invocation: inv, jobId: jobId)

        guard fm.fileExists(atPath: tempOut.path) else {
            throw PastaError.executionFailed(tool: "ffmpeg", exitCode: 1, output: "Audio compression produced no output")
        }

        let finalSize = (try? fm.attributesOfItem(atPath: tempOut.path)[.size] as? Int64) ?? 0
        if finalSize > target {
            let msg = "could not reach \(target); produced \(finalSize)"
            PastaLogger.shared.info(msg)
            print(msg)
        }

        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        try fm.moveItem(at: tempOut, to: output)
    }

    public func compressPDF(
        input: URL,
        output: URL,
        parameters: ParameterValues,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: input.path)
        } catch {
            throw PastaError.invalidInput("Cannot read attributes for file '\(input.path)': \(error.localizedDescription)")
        }
        let sourceSize = (attrs[.size] as? Int64) ?? 0
        let target = Self.targetBytes(for: sourceSize, parameters: parameters)

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer { try? fm.removeItem(at: scratchDir) }

        let presets = ["/printer", "/ebook", "/screen"]
        var bestCandidateURL: URL? = nil
        var smallestOutputURL: URL? = nil
        var smallestOutputSize: Int64 = Int64.max

        for preset in presets {
            let iterOut = scratchDir.appendingPathComponent("gs_\(preset.replacingOccurrences(of: "/", with: "")).pdf")
            let inv = Invocation(
                toolName: "gs",
                arguments: [
                    "-sDEVICE=pdfwrite",
                    "-dCompatibilityLevel=1.4",
                    "-dPDFSETTINGS=\(preset)",
                    "-dNOPAUSE",
                    "-dQUIET",
                    "-dBATCH",
                    "-sOutputFile=\(iterOut.path)",
                    "--",
                    input.path
                ]
            )
            do {
                try runner.execute(invocation: inv, jobId: jobId)
                if fm.fileExists(atPath: iterOut.path) {
                    let size = (try? fm.attributesOfItem(atPath: iterOut.path)[.size] as? Int64) ?? 0
                    if size < smallestOutputSize {
                        smallestOutputSize = size
                        smallestOutputURL = iterOut
                    }
                    if size <= target {
                        bestCandidateURL = iterOut
                        break // target satisfied
                    }
                }
            } catch {}
        }

        guard let winner = bestCandidateURL ?? smallestOutputURL else {
            throw PastaError.executionFailed(tool: "gs", exitCode: 1, output: "PDF compression failed to produce output")
        }

        let winnerSize = (try? fm.attributesOfItem(atPath: winner.path)[.size] as? Int64) ?? 0
        if winnerSize > target {
            let msg = "could not reach \(target); produced \(winnerSize)"
            PastaLogger.shared.info(msg)
            print(msg)
        }

        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        try fm.copyItem(at: winner, to: output)
    }

    public func compressBatch(
        inputs: [URL],
        outputDir: URL,
        parameters: ParameterValues,
        compressItem: (URL, URL, ParameterValues, JobRunner, UUID) throws -> Void,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDir.path) {
            try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }
        for inp in inputs {
            let dest = outputDir.appendingPathComponent(inp.lastPathComponent)
            try compressItem(inp, dest, parameters, runner, jobId)
        }
    }
}
