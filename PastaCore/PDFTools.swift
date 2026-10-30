import Foundation

public final class PDFTools {
    public static let shared = PDFTools()
    public init() {}

    public func totalPages(url: URL) throws -> Int {
        guard let qpdf = ToolLocator.shared.findTool("qpdf") else {
            throw PastaError.missingTool("qpdf")
        }
        let p = Process()
        p.executableURL = qpdf
        p.arguments = ["--show-npages", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let count = Int(str), count > 0 else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to determine page count for '\(url.lastPathComponent)'")
        }
        return count
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
                if let p = Int(item) {
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
                    let start = Int(parts[0]) ?? 1
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
                    }
                }
            } else if let p = Int(token) {
                if p < 1 || p > total {
                    throw PastaError.invalidInput("Page number \(p) exceeds total page count (\(total))")
                }
                if !deleteSet.contains(p) {
                    resolvedPages.append(p)
                }
            } else if token == "1-z" || token == "z" {
                for p in 1...total {
                    if !deleteSet.contains(p) {
                        resolvedPages.append(p)
                    }
                }
            }
        }

        if !deleteSet.isEmpty && resolvedPages.isEmpty {
            throw PastaError.invalidInput("All pages were deleted; resulting PDF would be empty")
        }

        let finalPagesArg = resolvedPages.map(String.init).joined(separator: ",")
        let rotAngle = rotate.trimmingCharacters(in: .whitespaces)

        var args: [String] = [input.path]
        if rotAngle != "0" && !rotAngle.isEmpty {
            args.append(contentsOf: ["--rotate=+\(rotAngle):1-z"])
        }
        args.append(contentsOf: ["--pages", input.path, finalPagesArg.isEmpty ? "1-z" : finalPagesArg, "--", output.path])

        let inv = Invocation(toolName: "qpdf", arguments: args)
        try runner.execute(invocation: inv, jobId: jobId)
    }
}
