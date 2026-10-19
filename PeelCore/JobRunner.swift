import Foundation

public final class JobRunner {
    public static let shared = JobRunner()

    public init() {}

    @discardableResult
    public func run(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        timeoutSeconds: TimeInterval = 120.0
    ) throws -> URL {
        let fm = FileManager.default

        // Validate input file
        try InputValidator.validateInputFile(input)

        // Determine destination URL
        let isExtract = action.id == "archive.extract"
        let isPdfToImages = action.id == "pdf.to.images"
        let isPdfSplit = action.id == "pdf.advanced.split"

        let finalDestinationURL: URL
        if isExtract {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "extracted", destinationDirectory: destinationDirectory)
        } else if isPdfToImages {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "pages", destinationDirectory: destinationDirectory)
        } else if isPdfSplit {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "split", destinationDirectory: destinationDirectory)
        } else {
            finalDestinationURL = OutputPlanner.planOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: destinationDirectory)
        }

        // Create temporary isolated scratch space
        let tempDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? fm.removeItem(at: tempDir)
        }

        let tempWorkingOutputURL: URL
        if isExtract || isPdfToImages || isPdfSplit {
            tempWorkingOutputURL = tempDir.appendingPathComponent("output_items")
            try fm.createDirectory(at: tempWorkingOutputURL, withIntermediateDirectories: true)
        } else {
            let ext = action.outputExtension.isEmpty ? "out" : action.outputExtension
            tempWorkingOutputURL = tempDir.appendingPathComponent("output_result.\(ext)")
        }

        let invocations = action.buildInvocations(input, tempWorkingOutputURL)
        guard !invocations.isEmpty else {
            throw PeelError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
        }

        // Run each invocation in sequence
        for inv in invocations {
            try execute(invocation: inv, timeoutSeconds: timeoutSeconds)
        }

        // Verify and move output to final destination
        if isPdfToImages {
            let contents = (try? fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)) ?? []
            if contents.isEmpty {
                let allTemp = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
                let pageFiles = allTemp.filter { $0.pathExtension.lowercased() == "png" }
                if pageFiles.isEmpty {
                    throw PeelError.outputNotFound(finalDestinationURL.path)
                }
                for file in pageFiles {
                    let destFile = tempWorkingOutputURL.appendingPathComponent(file.lastPathComponent)
                    try? fm.moveItem(at: file, to: destFile)
                }
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            return finalDestinationURL
        }

        if isExtract || isPdfSplit {
            guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
                throw PeelError.outputNotFound(finalDestinationURL.path)
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            return finalDestinationURL
        }

        guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
            throw PeelError.outputNotFound(finalDestinationURL.path)
        }

        // Safe atomic move
        if fm.fileExists(atPath: finalDestinationURL.path) {
            try fm.removeItem(at: finalDestinationURL)
        }
        try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)

        return finalDestinationURL
    }

    public func execute(invocation: Invocation, timeoutSeconds: TimeInterval) throws {
        let toolURL = try ToolLocator.shared.requireTool(invocation.toolName)

        let process = Process()
        process.executableURL = toolURL
        process.arguments = invocation.arguments
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        var env = ProcessInfo.processInfo.environment
        if let customEnv = invocation.environment {
            for (k, v) in customEnv {
                env[k] = v
            }
        }
        process.environment = env

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        do {
            try process.run()
        } catch {
            throw PeelError.executionFailed(tool: invocation.toolName, exitCode: 1, output: error.localizedDescription)
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
        var timedOut = false
        timer.schedule(deadline: .now() + timeoutSeconds)
        timer.setEventHandler {
            timedOut = true
            process.terminate()
        }
        timer.resume()

        process.waitUntilExit()
        timer.cancel()
        group.wait()

        if timedOut {
            throw PeelError.executionFailed(tool: invocation.toolName, exitCode: -1, output: "Execution timed out after \(timeoutSeconds) seconds")
        }

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            let msg = errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? outStr.trimmingCharacters(in: .whitespacesAndNewlines)
                : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PeelError.executionFailed(tool: invocation.toolName, exitCode: exitCode, output: msg)
        }
    }
}
