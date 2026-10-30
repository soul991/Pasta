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
        parameters: ParameterValues = [:],
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

        // Validate parameters
        var effectiveParams = action.defaultParameterValues
        for (k, v) in parameters {
            effectiveParams[k] = v
        }
        try InputValidator.validateParameters(declared: action.parameters, values: effectiveParams)

        let effectiveDest = destinationDirectory ?? PreferencesManager.shared.effectiveDestination(for: input)

        // Determine destination URL from outputKind
        let isFolder: Bool
        let folderSuffix: String
        switch action.outputKind {
        case .folder(let suffix):
            isFolder = true
            folderSuffix = suffix
        case .file:
            isFolder = false
            folderSuffix = ""
        }

        let finalDestinationURL: URL
        if isFolder {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: folderSuffix, destinationDirectory: effectiveDest)
        } else {
            finalDestinationURL = OutputPlanner.planOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
        }

        PastaLogger.shared.info("Starting action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

        // Create temporary isolated scratch space
        let tempDir = try OutputPlanner.makeTempDirectory()
        defer {
            // Safe to swallow: best-effort temporary scratch directory removal on scope exit
            try? fm.removeItem(at: tempDir)
        }

        let tempWorkingOutputURL: URL
        if isFolder {
            tempWorkingOutputURL = tempDir.appendingPathComponent("output_items")
            try fm.createDirectory(at: tempWorkingOutputURL, withIntermediateDirectories: true)
        } else {
            let ext = action.outputExtension.isEmpty ? "out" : action.outputExtension
            tempWorkingOutputURL = tempDir.appendingPathComponent("output_result.\(ext)")
        }

        if let custom = action.customRunner {
            try custom(input, tempWorkingOutputURL, effectiveParams, self, jobId)
        } else {
            let invocations = action.buildInvocationsWithParams(input, tempWorkingOutputURL, effectiveParams)
            guard !invocations.isEmpty else {
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
            }

            // Run each invocation in sequence
            for inv in invocations {
                try execute(invocation: inv, timeoutSeconds: timeoutSeconds, jobId: jobId)
            }
        }

        // Verify and move output to final destination
        if isFolder {
            let contents: [URL]
            do {
                contents = try fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)
            } catch {
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to read output directory contents: \(error.localizedDescription)")
            }
            if contents.isEmpty {
                let allTemp: [URL]
                do {
                    allTemp = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                } catch {
                    throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to inspect scratch directory: \(error.localizedDescription)")
                }
                let looseItems = allTemp.filter { $0.lastPathComponent != "output_items" }
                if looseItems.isEmpty {
                    throw PastaError.outputNotFound(finalDestinationURL.path)
                }
                for item in looseItems {
                    let destFile = tempWorkingOutputURL.appendingPathComponent(item.lastPathComponent)
                    try fm.moveItem(at: item, to: destFile)
                }
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            return finalDestinationURL
        }

        if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
            let looseFiles = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil))?.filter {
                $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
            } ?? []
            if looseFiles.count == 1 {
                try? fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
            }
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

    @discardableResult
    public func runBatch(
        action: ConversionAction,
        inputs: [URL],
        destinationDirectory: URL? = nil,
        parameters: ParameterValues = [:],
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

        guard !inputs.isEmpty else {
            throw PastaError.invalidInput("Batch action requires at least one input file")
        }

        // Validate inputs
        if action.id == "pdf.merge" {
            try InputValidator.validatePDFMerge(files: inputs)
        } else {
            for inp in inputs {
                try InputValidator.validateInputFile(inp)
            }
        }

        // Validate parameters
        var effectiveParams = action.defaultParameterValues
        for (k, v) in parameters {
            effectiveParams[k] = v
        }
        try InputValidator.validateParameters(declared: action.parameters, values: effectiveParams)

        let firstInput = inputs[0]
        let effectiveDest = destinationDirectory ?? PreferencesManager.shared.effectiveDestination(for: firstInput)

        let isCompressBatch = action.id.contains("compress") && inputs.count > 1
        let finalDestinationURL: URL
        if isCompressBatch {
            finalDestinationURL = OutputPlanner.planOutputDirectory(for: firstInput, suffix: "compressed", destinationDirectory: effectiveDest)
        } else {
            switch action.outputKind {
            case .folder(let suffix):
                finalDestinationURL = OutputPlanner.planOutputDirectory(for: firstInput, suffix: suffix, destinationDirectory: effectiveDest)
            case .file:
                finalDestinationURL = OutputPlanner.planOutput(for: firstInput, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
            }
        }

        PastaLogger.shared.info("Starting batch action \(action.id) on \(inputs.count) files -> '\(finalDestinationURL.lastPathComponent)'")

        let tempDir = try OutputPlanner.makeTempDirectory()
        defer {
            // Safe to swallow: best-effort temporary scratch directory removal on scope exit
            try? fm.removeItem(at: tempDir)
        }

        let tempWorkingOutputURL: URL
        if isCompressBatch {
            tempWorkingOutputURL = tempDir.appendingPathComponent("output_items")
            try fm.createDirectory(at: tempWorkingOutputURL, withIntermediateDirectories: true)
        } else {
            switch action.outputKind {
            case .folder:
                tempWorkingOutputURL = tempDir.appendingPathComponent("output_items")
                try fm.createDirectory(at: tempWorkingOutputURL, withIntermediateDirectories: true)
            case .file:
                let ext = action.outputExtension.isEmpty ? "out" : action.outputExtension
                tempWorkingOutputURL = tempDir.appendingPathComponent("output_result.\(ext)")
            }
        }

        if let customBatch = action.customBatchRunner {
            try customBatch(inputs, tempWorkingOutputURL, effectiveParams, self, jobId)
        } else if let custom = action.customRunner, isCompressBatch {
            for inp in inputs {
                let dest = tempWorkingOutputURL.appendingPathComponent(inp.lastPathComponent)
                try custom(inp, dest, effectiveParams, self, jobId)
            }
        } else {
            let invocations = (action.buildBatchInvocationsWithParams ?? { ins, out, params in
                guard let first = ins.first else { return [] }
                return action.buildInvocationsWithParams(first, out, params)
            })(inputs, tempWorkingOutputURL, effectiveParams)

            guard !invocations.isEmpty else {
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for batch action \(action.id)")
            }

            for inv in invocations {
                try execute(invocation: inv, timeoutSeconds: timeoutSeconds, jobId: jobId)
            }
        }

        if isCompressBatch {
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            PastaLogger.shared.info("Successfully completed batch \(action.id) -> '\(finalDestinationURL.path)'")
            return finalDestinationURL
        }

        switch action.outputKind {
        case .folder:
            let contents: [URL]
            do {
                contents = try fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)
            } catch {
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to read batch output directory contents: \(error.localizedDescription)")
            }
            if contents.isEmpty {
                let allTemp: [URL]
                do {
                    allTemp = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                } catch {
                    throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to inspect batch scratch directory: \(error.localizedDescription)")
                }
                let looseItems = allTemp.filter { $0.lastPathComponent != "output_items" }
                if looseItems.isEmpty {
                    throw PastaError.outputNotFound(finalDestinationURL.path)
                }
                for item in looseItems {
                    let destFile = tempWorkingOutputURL.appendingPathComponent(item.lastPathComponent)
                    try fm.moveItem(at: item, to: destFile)
                }
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            return finalDestinationURL
        case .file:
            if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
                let looseFiles = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil))?.filter {
                    $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
                } ?? []
                if looseFiles.count == 1 {
                    try? fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
                }
            }
            guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
                throw PastaError.outputNotFound(finalDestinationURL.path)
            }
            if fm.fileExists(atPath: finalDestinationURL.path) {
                try fm.removeItem(at: finalDestinationURL)
            }
            try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
            PastaLogger.shared.info("Successfully completed batch \(action.id) -> '\(finalDestinationURL.path)'")
            return finalDestinationURL
        }
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
    @discardableResult
    public func executeCapture(invocation: Invocation, timeoutSeconds: TimeInterval? = nil, jobId: UUID = UUID()) throws -> (stdout: String, stderr: String) {
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
        // Safe to swallow: best-effort closing of redirected output handle
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
        let (outData, errData) = collector.results
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        if exitCode != 0 {
            let msg = errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? outStr.trimmingCharacters(in: .whitespacesAndNewlines)
                : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PastaError.executionFailed(tool: invocation.toolName, exitCode: exitCode, output: msg)
        }
        return (outStr, errStr)
    }

    public func execute(invocation: Invocation, timeoutSeconds: TimeInterval? = nil, jobId: UUID = UUID()) throws {
        _ = try executeCapture(invocation: invocation, timeoutSeconds: timeoutSeconds, jobId: jobId)
    }

    @discardableResult
    public func runAsync(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        parameters: ParameterValues = [:],
        timeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) async throws -> URL {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            if self.isJobCancelled(jobId) {
                throw PastaError.cancelled
            }
            let fm = FileManager.default
            try InputValidator.validateInputFile(input)

            // Validate parameters
            var effectiveParams = action.defaultParameterValues
            for (k, v) in parameters {
                effectiveParams[k] = v
            }
            try InputValidator.validateParameters(declared: action.parameters, values: effectiveParams)

            let effectiveDest = destinationDirectory ?? PreferencesManager.shared.effectiveDestination(for: input)

            // Determine destination URL from outputKind
            let isFolder: Bool
            let folderSuffix: String
            switch action.outputKind {
            case .folder(let suffix):
                isFolder = true
                folderSuffix = suffix
            case .file:
                isFolder = false
                folderSuffix = ""
            }

            let finalDestinationURL: URL
            if isFolder {
                finalDestinationURL = OutputPlanner.planOutputDirectory(for: input, suffix: folderSuffix, destinationDirectory: effectiveDest)
            } else {
                finalDestinationURL = OutputPlanner.planOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
            }

            PastaLogger.shared.info("Starting async action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

            let tempDir = try OutputPlanner.makeTempDirectory()
            defer {
                // Safe to swallow: best-effort temporary scratch directory removal on scope exit
                try? fm.removeItem(at: tempDir)
            }

            let tempWorkingOutputURL: URL
            if isFolder {
                tempWorkingOutputURL = tempDir.appendingPathComponent("output_items")
                try fm.createDirectory(at: tempWorkingOutputURL, withIntermediateDirectories: true)
            } else {
                let ext = action.outputExtension.isEmpty ? "out" : action.outputExtension
                tempWorkingOutputURL = tempDir.appendingPathComponent("output_result.\(ext)")
            }

            if let custom = action.customRunner {
                try custom(input, tempWorkingOutputURL, effectiveParams, self, jobId)
            } else {
                let invocations = action.buildInvocationsWithParams(input, tempWorkingOutputURL, effectiveParams)
                guard !invocations.isEmpty else {
                    throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
                }

                for inv in invocations {
                    try await executeAsync(invocation: inv, timeoutSeconds: timeoutSeconds, jobId: jobId)
                }
            }

            if isFolder {
                let contents: [URL]
                do {
                    contents = try fm.contentsOfDirectory(at: tempWorkingOutputURL, includingPropertiesForKeys: nil)
                } catch {
                    throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to read async output directory contents: \(error.localizedDescription)")
                }
                if contents.isEmpty {
                    let allTemp: [URL]
                    do {
                        allTemp = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                    } catch {
                        throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "Failed to inspect async scratch directory: \(error.localizedDescription)")
                    }
                    let looseItems = allTemp.filter { $0.lastPathComponent != "output_items" }
                    if looseItems.isEmpty {
                        throw PastaError.outputNotFound(finalDestinationURL.path)
                    }
                    for item in looseItems {
                        let destFile = tempWorkingOutputURL.appendingPathComponent(item.lastPathComponent)
                        try fm.moveItem(at: item, to: destFile)
                    }
                }
                try fm.moveItem(at: tempWorkingOutputURL, to: finalDestinationURL)
                return finalDestinationURL
            }

            if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
                let looseFiles = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil))?.filter {
                    $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
                } ?? []
                if looseFiles.count == 1 {
                    try? fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
                }
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
                    // Safe to swallow: best-effort closing of redirected output handle
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
