import Foundation

public final class JobRunner {
    public static let shared = JobRunner()

    private var runningProcesses: [UUID: Process] = [:]
    private var cancelledJobIds: Set<UUID> = []
    private let processLock = NSLock()

    public init() {}

    private func isJobCancelled(_ jobId: UUID) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        return cancelledJobIds.contains(jobId)
    }

    private func trackProcess(_ process: Process, for jobId: UUID) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        if cancelledJobIds.contains(jobId) {
            return false
        }
        runningProcesses[jobId] = process
        return true
    }

    private func untrackProcess(for jobId: UUID) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        runningProcesses.removeValue(forKey: jobId)
        return cancelledJobIds.contains(jobId)
    }

    public func cancel(jobId: UUID) {
        processLock.lock()
        cancelledJobIds.insert(jobId)
        let proc = runningProcesses[jobId]
        processLock.unlock()
        if let proc = proc {
            terminateGracefully(proc)
        }
    }

    public func cancel() {
        cancelAll()
    }

    public func cancelAll() {
        processLock.lock()
        let procs = Array(runningProcesses.values)
        for (id, _) in runningProcesses {
            cancelledJobIds.insert(id)
        }
        processLock.unlock()
        for proc in procs {
            terminateGracefully(proc)
        }
    }

    private func terminateGracefully(_ proc: Process) {
        guard proc.isRunning else { return }
        proc.terminate()
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            if proc.isRunning && pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }

    @discardableResult
    public func run(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        timeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) throws -> URL {
        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            processLock.unlock()
            throw PastaError.cancelled
        }
        processLock.unlock()
        let fm = FileManager.default

        // Validate input file
        try InputValidator.validateInputFile(input)

        let effectiveDest = destinationDirectory ?? PreferencesManager.shared.effectiveDestination(for: input)

        // Determine destination URL
        let isExtract = action.id == "archive.extract"
        let isPdfToImages = action.id == "pdf.to.images"
        let isPdfSplit = action.id == "pdf.advanced.split"

        let finalDestinationURL: URL
        if isExtract {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "extracted", destinationDirectory: effectiveDest)
        } else if isPdfToImages {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "pages", destinationDirectory: effectiveDest)
        } else if isPdfSplit {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "split", destinationDirectory: effectiveDest)
        } else {
            finalDestinationURL = OutputPlanner.planOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
        }

        PastaLogger.shared.info("Starting action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

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
            throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
        }

        // Run each invocation in sequence
        for inv in invocations {
            try execute(invocation: inv, timeoutSeconds: timeoutSeconds, jobId: jobId)
        }

        // Verify and move output to final destination
        if isPdfToImages {
            let contents = (try? fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)) ?? []
            if contents.isEmpty {
                let allTemp = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
                let pageFiles = allTemp.filter { $0.pathExtension.lowercased() == "png" }
                if pageFiles.isEmpty {
                    throw PastaError.outputNotFound(finalDestinationURL.path)
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
                throw PastaError.outputNotFound(finalDestinationURL.path)
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            return finalDestinationURL
        }

        guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
            throw PastaError.outputNotFound(finalDestinationURL.path)
        }

        // Safe atomic move
        if fm.fileExists(atPath: finalDestinationURL.path) {
            try fm.removeItem(at: finalDestinationURL)
        }
        try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)

        PastaLogger.shared.info("Successfully completed \(action.id) -> '\(finalDestinationURL.path)'")
        return finalDestinationURL
    }
}

private final class PipeCollector {
    private let lock = NSLock()
    private var outData = Data()
    private var errTail = Data()
    private let maxErrTail: Int = 64 * 1024

    func appendOut(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        outData.append(data)
    }

    func appendErr(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        errTail.append(data)
        if errTail.count > maxErrTail {
            errTail = errTail.suffix(maxErrTail)
        }
    }

    var results: (out: Data, err: Data) {
        lock.lock()
        defer { lock.unlock() }
        return (outData, errTail)
    }
}

extension JobRunner {
    public func execute(invocation: Invocation, timeoutSeconds: TimeInterval? = nil, jobId: UUID = UUID()) throws {
        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            processLock.unlock()
            throw PastaError.cancelled
        }
        processLock.unlock()

        let toolURL = try ToolLocator.shared.requireTool(invocation.toolName)

        let process = Process()
        process.executableURL = toolURL
        process.arguments = invocation.arguments
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        var redirectHandle: FileHandle?

        if let redirectPath = invocation.redirectStdoutTo {
            FileManager.default.createFile(atPath: redirectPath, contents: nil)
            redirectHandle = FileHandle(forWritingAtPath: redirectPath)
            process.standardOutput = redirectHandle
        } else {
            process.standardOutput = outPipe
        }
        process.standardError = errPipe

        var env = ProcessInfo.processInfo.environment
        if let customEnv = invocation.environment {
            for (k, v) in customEnv {
                env[k] = v
            }
        }
        process.environment = env

        let collector = PipeCollector()

        if redirectHandle == nil {
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    collector.appendOut(chunk)
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                collector.appendErr(chunk)
            }
        }

        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            processLock.unlock()
            throw PastaError.cancelled
        }
        runningProcesses[jobId] = process
        processLock.unlock()

        defer {
            processLock.lock()
            runningProcesses.removeValue(forKey: jobId)
            processLock.unlock()
        }

        let effectiveTimeout: TimeInterval?
        if let explicit = timeoutSeconds, explicit > 0 {
            effectiveTimeout = explicit
        } else if let explicit = timeoutSeconds, explicit <= 0 {
            effectiveTimeout = nil
        } else {
            effectiveTimeout = invocation.timeoutSeconds
        }

        var timer: DispatchSourceTimer?
        var timedOut = false
        if let timeout = effectiveTimeout, timeout > 0 {
            let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
            t.schedule(deadline: .now() + timeout)
            t.setEventHandler {
                timedOut = true
                process.terminate()
            }
            t.resume()
            timer = t
        }

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            sema.signal()
        }

        do {
            try process.run()
        } catch {
            timer?.cancel()
            throw PastaError.executionFailed(tool: invocation.toolName, exitCode: 1, output: error.localizedDescription)
        }

        sema.wait()
        timer?.cancel()

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        if redirectHandle == nil {
            let remOut = outPipe.fileHandleForReading.readDataToEndOfFile()
            if !remOut.isEmpty { collector.appendOut(remOut) }
        }
        let remErr = errPipe.fileHandleForReading.readDataToEndOfFile()
        if !remErr.isEmpty { collector.appendErr(remErr) }
        try? redirectHandle?.close()

        processLock.lock()
        let wasCancelled = cancelledJobIds.contains(jobId)
        processLock.unlock()

        if wasCancelled {
            throw PastaError.cancelled
        }

        if timedOut {
            throw PastaError.timedOut(tool: invocation.toolName)
        }

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            let (outData, errData) = collector.results
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            let msg = errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? outStr.trimmingCharacters(in: .whitespacesAndNewlines)
                : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PastaError.executionFailed(tool: invocation.toolName, exitCode: exitCode, output: msg)
        }
    }

    @discardableResult
    public func runAsync(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        timeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let fm = FileManager.default
            try InputValidator.validateInputFile(input)
            let effectiveDest = destinationDirectory ?? PreferencesManager.shared.effectiveDestination(for: input)
            let isExtract = action.id == "archive.extract"
            let isPdfToImages = action.id == "pdf.to.images"
            let isPdfSplit = action.id == "pdf.advanced.split"

            let finalDestinationURL: URL
            if isExtract {
                finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "extracted", destinationDirectory: effectiveDest)
            } else if isPdfToImages {
                finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "pages", destinationDirectory: effectiveDest)
            } else if isPdfSplit {
                finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: "split", destinationDirectory: effectiveDest)
            } else {
                finalDestinationURL = OutputPlanner.planOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
            }

            PastaLogger.shared.info("Starting async action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

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
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
            }

            for inv in invocations {
                try await executeAsync(invocation: inv, timeoutSeconds: timeoutSeconds, jobId: jobId)
            }

            if isPdfToImages {
                let contents = (try? fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)) ?? []
                if contents.isEmpty {
                    let allTemp = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
                    let pageFiles = allTemp.filter { $0.pathExtension.lowercased() == "png" }
                    if pageFiles.isEmpty {
                        throw PastaError.outputNotFound(finalDestinationURL.path)
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
                    throw PastaError.outputNotFound(finalDestinationURL.path)
                }
                try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
                return finalDestinationURL
            }

            guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
                throw PastaError.outputNotFound(finalDestinationURL.path)
            }

            if fm.fileExists(atPath: finalDestinationURL.path) {
                try fm.removeItem(at: finalDestinationURL)
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            PastaLogger.shared.info("Successfully completed async \(action.id) -> '\(finalDestinationURL.path)'")
            return finalDestinationURL
        } onCancel: {
            self.cancel(jobId: jobId)
        }
    }

    public func executeAsync(invocation: Invocation, timeoutSeconds: TimeInterval? = nil, jobId: UUID = UUID()) async throws {
        try Task.checkCancellation()
        if isJobCancelled(jobId) {
            throw PastaError.cancelled
        }

        let toolURL = try ToolLocator.shared.requireTool(invocation.toolName)

        let process = Process()
        process.executableURL = toolURL
        process.arguments = invocation.arguments
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        var redirectHandle: FileHandle?

        if let redirectPath = invocation.redirectStdoutTo {
            FileManager.default.createFile(atPath: redirectPath, contents: nil)
            redirectHandle = FileHandle(forWritingAtPath: redirectPath)
            process.standardOutput = redirectHandle
        } else {
            process.standardOutput = outPipe
        }
        process.standardError = errPipe

        var env = ProcessInfo.processInfo.environment
        if let customEnv = invocation.environment {
            for (k, v) in customEnv {
                env[k] = v
            }
        }
        process.environment = env

        let collector = PipeCollector()

        if redirectHandle == nil {
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    collector.appendOut(chunk)
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                collector.appendErr(chunk)
            }
        }

        let effectiveTimeout: TimeInterval?
        if let explicit = timeoutSeconds, explicit > 0 {
            effectiveTimeout = explicit
        } else if let explicit = timeoutSeconds, explicit <= 0 {
            effectiveTimeout = nil
        } else {
            effectiveTimeout = invocation.timeoutSeconds
        }

        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var timer: DispatchSourceTimer?
            var didTimeout = false
            func setTimer(_ t: DispatchSourceTimer) { lock.lock(); defer { lock.unlock() }; timer = t }
            func cancelTimer() { lock.lock(); defer { lock.unlock() }; timer?.cancel() }
            func markTimeout() { lock.lock(); defer { lock.unlock() }; didTimeout = true }
            var timedOut: Bool { lock.lock(); defer { lock.unlock() }; return didTimeout }
        }
        let box = Box()

        let rHandle = redirectHandle

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    box.cancelTimer()
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    if rHandle == nil {
                        let remOut = outPipe.fileHandleForReading.readDataToEndOfFile()
                        if !remOut.isEmpty { collector.appendOut(remOut) }
                    }
                    let remErr = errPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remErr.isEmpty { collector.appendErr(remErr) }
                    try? rHandle?.close()

                    let wasCancelled = self.untrackProcess(for: jobId)

                    if wasCancelled {
                        continuation.resume(throwing: PastaError.cancelled)
                        return
                    }

                    if box.timedOut {
                        continuation.resume(throwing: PastaError.timedOut(tool: invocation.toolName))
                        return
                    }

                    let exitCode = proc.terminationStatus
                    if exitCode != 0 {
                        let (outData, errData) = collector.results
                        let outStr = String(data: outData, encoding: .utf8) ?? ""
                        let errStr = String(data: errData, encoding: .utf8) ?? ""
                        let msg = errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? outStr.trimmingCharacters(in: .whitespacesAndNewlines)
                            : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: PastaError.executionFailed(tool: invocation.toolName, exitCode: exitCode, output: msg))
                    } else {
                        continuation.resume()
                    }
                }

                guard self.trackProcess(process, for: jobId) else {
                    continuation.resume(throwing: PastaError.cancelled)
                    return
                }

                if let timeout = effectiveTimeout, timeout > 0 {
                    let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
                    t.schedule(deadline: .now() + timeout)
                    t.setEventHandler { [weak process] in
                        box.markTimeout()
                        process?.terminate()
                    }
                    t.resume()
                    box.setTimer(t)
                }

                do {
                    try process.run()
                } catch {
                    box.cancelTimer()
                    _ = self.untrackProcess(for: jobId)
                    continuation.resume(throwing: PastaError.executionFailed(tool: invocation.toolName, exitCode: 1, output: error.localizedDescription))
                }
            }
        } onCancel: {
            self.cancel(jobId: jobId)
        }
    }
}
