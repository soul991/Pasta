import Foundation

public final class PDFTools {
    public static let shared = PDFTools()
    public init() {}

    public func totalPages(url: URL) throws -> Int {
        let inv = Invocation(toolName: "qpdf", arguments: ["--show-npages", "--", url.path])
        let (outStr, _) = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 30)
        let lines = outStr.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for line in lines.reversed() {
            if let count = Int(line), count > 0 {
                return count
            }
        }
        let tokens = outStr.components(separatedBy: .whitespacesAndNewlines)
        for tok in tokens.reversed() {
            if let count = Int(tok), count > 0 {
                return count
            }
        }
        throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to determine page count for '\(url.lastPathComponent)': \(outStr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    public func reorganize(
        input: URL,
        output: URL,
        pages: String,
        rotate: String,
        deletePages: String,
        runner: JobRunner,
        jobId: UUID
    ) throws {
        let total = try totalPages(url: input)

        // Parse delete pages if any
        let deleteSet: Set<Int>
        if !deletePages.trimmingCharacters(in: .whitespaces).isEmpty {
            let delList = deletePages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            var set = Set<Int>()
            for item in delList {
                if item.contains("-") {
                    let parts = item.split(separator: "-").map(String.init)
                    if parts.count == 2 {
                        let start = (parts[0].lowercased() == "z") ? total : (Int(parts[0]) ?? 1)
                        let end = (parts[1].lowercased() == "z") ? total : (Int(parts[1]) ?? total)
                        let lo = min(start, end)
                        let hi = max(start, end)
                        for p in lo...hi {
                            if p >= 1 && p <= total { set.insert(p) }
                        }
                    }
                } else if let p = Int(item) {
                    if p < 1 || p > total {
                        throw PastaError.invalidInput("Page number to delete (\(p)) exceeds total pages (\(total))")
                    }
                    set.insert(p)
                }
            }
            deleteSet = set
        } else {
            deleteSet = []
        }

        var effectivePageSpec = pages.trimmingCharacters(in: .whitespaces)
        if effectivePageSpec.isEmpty {
            effectivePageSpec = "1-z"
        }

        // Validate pages in effectivePageSpec
        let pageTokens = effectivePageSpec.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var resolvedPages: [Int] = []
        for token in pageTokens {
            if token.contains("-") {
                let parts = token.split(separator: "-").map(String.init)
                if parts.count == 2 {
                    let start = (parts[0].lowercased() == "z") ? total : (Int(parts[0]) ?? 1)
                    let endStr = parts[1].lowercased()
                    let end = (endStr == "z") ? total : (Int(endStr) ?? total)
                    if start < 1 || start > total || end < 1 || end > total {
                        throw PastaError.invalidInput("Page range '\(token)' exceeds total page count (\(total))")
                    }
                    if start <= end {
                        for p in start...end {
                            if !deleteSet.contains(p) {
                                resolvedPages.append(p)
                            }
                        }
                    } else {
                        for p in stride(from: start, through: end, by: -1) {
                            if !deleteSet.contains(p) {
                                resolvedPages.append(p)
                            }
                        }
                    }
                }
            } else if token.lowercased() == "z" {
                if !deleteSet.contains(total) {
                    resolvedPages.append(total)
                }
            } else if let p = Int(token) {
                if p < 1 || p > total {
                    throw PastaError.invalidInput("Page number \(p) exceeds total page count (\(total))")
                }
                if !deleteSet.contains(p) {
                    resolvedPages.append(p)
                }
            }
        }

        if !deleteSet.isEmpty && resolvedPages.isEmpty {
            throw PastaError.invalidInput("All pages were deleted; resulting PDF would be empty")
        }

        let finalPagesArg = resolvedPages.map(String.init).joined(separator: ",")
        let rotAngle = rotate.trimmingCharacters(in: .whitespaces)

        var args: [String] = ["--empty"]
        if rotAngle != "0" && !rotAngle.isEmpty {
            let prefix = (rotAngle.hasPrefix("+") || rotAngle.hasPrefix("-")) ? "" : "+"
            args.append(contentsOf: ["--rotate=\(prefix)\(rotAngle):1-z"])
        }
        args.append(contentsOf: ["--pages", input.path, finalPagesArg.isEmpty ? "1-z" : finalPagesArg, "--", output.path])

        let inv = Invocation(toolName: "qpdf", arguments: args)
        try runner.execute(invocation: inv, jobId: jobId)
    }

    /// Converts PDF to archival PDF/A-2b using Ghostscript
    public func convertToPDFA(input: URL, output: URL, runner: JobRunner, jobId: UUID) throws {
        _ = try ToolLocator.shared.requireTool("gs")
        let inv = Invocation(toolName: "gs", arguments: [
            "-dPDFA=2",
            "-dBATCH",
            "-dNOPAUSE",
            "-dPDFACompatibilityPolicy=1",
            "-sColorConversionStrategy=UseDeviceIndependentColor",
            "-sDEVICE=pdfwrite",
            "-o", output.path,
            input.path
        ])
        try runner.execute(invocation: inv, timeoutSeconds: 60, jobId: jobId)
    }

    /// Converts PDF to EPUB using pdftotext to extract plain text/markdown followed by pandoc
    /// Note: Labeled "text only, layout not preserved"
    public func convertToEPUB(input: URL, output: URL, runner: JobRunner, jobId: UUID) throws {
        _ = try ToolLocator.shared.requireTool("pdftotext")
        _ = try ToolLocator.shared.requireTool("pandoc")

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: scratchDir)
        }

        let tempTextURL = scratchDir.appendingPathComponent("document_text.txt")
        let txtInv = Invocation(toolName: "pdftotext", arguments: ["-layout", input.path, tempTextURL.path])
        try runner.execute(invocation: txtInv, timeoutSeconds: 30, jobId: jobId)

        let epubInv = Invocation(toolName: "pandoc", arguments: [tempTextURL.path, "-o", output.path])
        try runner.execute(invocation: epubInv, timeoutSeconds: 60, jobId: jobId)
    }

    /// Converts PDF to EPUB using Calibre (ebook-convert) for enhanced layout preservation
    public func convertToEPUBWithCalibre(input: URL, output: URL, runner: JobRunner, jobId: UUID) throws {
        _ = try ToolLocator.shared.requireTool("ebook-convert")
        let inv = Invocation(toolName: "ebook-convert", arguments: [input.path, output.path])
        try runner.execute(invocation: inv, timeoutSeconds: 120, jobId: jobId)
    }
}
