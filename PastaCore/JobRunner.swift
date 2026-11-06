import Foundation

public final class JobRunner {
    public static let shared = JobRunner()

    private var runningProcesses: [UUID: Process] = [:]
    private var cancelledJobIds: Set<UUID> = []
    private let processLock = NSLock()

    public init() {}

    public func isCancelled(_ jobId: UUID) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        return cancelledJobIds.contains(jobId)
    }

    private func isJobCancelled(_ jobId: UUID) -> Bool {
        return isCancelled(jobId)
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
        try? FileManager.default.removeItem(atPath: "/tmp/Pasta_lo_\(jobId.uuidString)")
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

    public func isJobRunning(_ jobId: UUID) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        return runningProcesses[jobId]?.isRunning ?? false
    }

    public func terminateGracefully(_ proc: Process, gracePeriod: TimeInterval = 2.0) {
        guard proc.isRunning else { return }
        let pid = proc.processIdentifier
        if pid > 0 {
            kill(pid, SIGTERM)
        } else {
            proc.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if proc.isRunning && pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }

    public static func safelyMoveOrReplace(source: URL, destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            do {
                _ = try fm.replaceItemAt(destination, withItemAt: source, backupItemName: nil, options: [])
                return
            } catch {
                try? fm.removeItem(at: destination)
            }
        }
        try fm.moveItem(at: source, to: destination)
    }

    public static func validateFolderJail(at rootURL: URL) throws {
        try ArchiveGuard.validate(root: rootURL)
    }

    @discardableResult
    public func run(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        parameters: ParameterValues = [:],
        timeoutSeconds: TimeInterval? = nil,
        inactivityTimeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) throws -> URL {
        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            cancelledJobIds.remove(jobId)
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

        let reservation: OutputReservation
        if isFolder {
            reservation = try OutputPlanner.reserveOutputDirectory(for: input, suffix: folderSuffix, destinationDirectory: effectiveDest)
        } else {
            reservation = try OutputPlanner.reserveOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
        }
        defer {
            reservation.cleanup()
        }
        let finalDestinationURL = reservation.url

        PastaLogger.shared.info("Starting action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

        // Create temporary isolated scratch space
        let tempDir = try OutputPlanner.makeTempDirectory()
        let loProfileDir = URL(fileURLWithPath: "/tmp/Pasta_lo_\(jobId.uuidString)")
        defer {
            processLock.lock()
            cancelledJobIds.remove(jobId)
            processLock.unlock()
            // Safe to swallow: best-effort temporary scratch directory removal on scope exit
            try? fm.removeItem(at: tempDir)
            try? fm.removeItem(at: loProfileDir)
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
            if isJobCancelled(jobId) {
                throw PastaError.cancelled
            }
        } else {
            let invocations = action.buildInvocationsWithParams(input, tempWorkingOutputURL, effectiveParams)
            guard !invocations.isEmpty else {
                throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
            }

            // Run each invocation in sequence
            for inv in invocations {
                try execute(invocation: inv, timeoutSeconds: timeoutSeconds, inactivityTimeoutSeconds: inactivityTimeoutSeconds, jobId: jobId)
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
            try Self.validateFolderJail(at: tempWorkingOutputURL)
            try reservation.publish(from: tempWorkingOutputURL)
            return finalDestinationURL
        }

        if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
            let looseFiles = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
            }
            if looseFiles.count == 1 {
                try fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
            }
        }

        guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
            throw PastaError.outputNotFound(finalDestinationURL.path)
        }

        // Safe atomic publish over reserved placeholder
        try reservation.publish(from: tempWorkingOutputURL)
        RecentConversionsStore.shared.record(actionId: action.id, outputURL: finalDestinationURL)

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
        inactivityTimeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) throws -> URL {
        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            cancelledJobIds.remove(jobId)
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
        let reservation: OutputReservation
        if isCompressBatch {
            reservation = try OutputPlanner.reserveOutputDirectory(for: firstInput, suffix: "compressed", destinationDirectory: effectiveDest)
        } else {
            switch action.outputKind {
            case .folder(let suffix):
                reservation = try OutputPlanner.reserveOutputDirectory(for: firstInput, suffix: suffix, destinationDirectory: effectiveDest)
            case .file:
                reservation = try OutputPlanner.reserveOutput(for: firstInput, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
            }
        }
        defer {
            reservation.cleanup()
        }
        let finalDestinationURL = reservation.url

        PastaLogger.shared.info("Starting batch action \(action.id) on \(inputs.count) files -> '\(finalDestinationURL.lastPathComponent)'")

        let tempDir = try OutputPlanner.makeTempDirectory()
        let loProfileDir = URL(fileURLWithPath: "/tmp/Pasta_lo_\(jobId.uuidString)")
        defer {
            processLock.lock()
            cancelledJobIds.remove(jobId)
            processLock.unlock()
            // Safe to swallow: best-effort temporary scratch directory removal on scope exit
            try? fm.removeItem(at: tempDir)
            try? fm.removeItem(at: loProfileDir)
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
            if isJobCancelled(jobId) {
                throw PastaError.cancelled
            }
        } else if let custom = action.customRunner, isCompressBatch {
            for inp in inputs {
                if isJobCancelled(jobId) {
                    throw PastaError.cancelled
                }
                let dest = tempWorkingOutputURL.appendingPathComponent(inp.lastPathComponent)
                try custom(inp, dest, effectiveParams, self, jobId)
            }
            if isJobCancelled(jobId) {
                throw PastaError.cancelled
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
                try execute(invocation: inv, timeoutSeconds: timeoutSeconds, inactivityTimeoutSeconds: inactivityTimeoutSeconds, jobId: jobId)
            }
        }

        if isCompressBatch {
            try reservation.publish(from: tempWorkingOutputURL)
            RecentConversionsStore.shared.record(actionId: action.id, outputURL: finalDestinationURL)
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
            try Self.validateFolderJail(at: tempWorkingOutputURL)
            try reservation.publish(from: tempWorkingOutputURL)
            RecentConversionsStore.shared.record(actionId: action.id, outputURL: finalDestinationURL)
            return finalDestinationURL
        case .file:
            if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
                let looseFiles = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil).filter {
                    $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
                }
                if looseFiles.count == 1 {
                    try fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
                }
            }
            guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
                throw PastaError.outputNotFound(finalDestinationURL.path)
            }
            try reservation.publish(from: tempWorkingOutputURL)
            RecentConversionsStore.shared.record(actionId: action.id, outputURL: finalDestinationURL)
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
    public func executeCapture(
        invocation: Invocation,
        timeoutSeconds: TimeInterval? = nil,
        inactivityTimeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) throws -> (stdout: String, stderr: String) {
        processLock.lock()
        if cancelledJobIds.contains(jobId) {
            processLock.unlock()
            throw PastaError.cancelled
        }
        processLock.unlock()

        let toolURL = try ToolLocator.shared.requireTool(invocation.toolName)

        var processArgs = invocation.arguments
        if invocation.toolName == "soffice" {
            let loProfile = "file:///tmp/Pasta_lo_\(jobId.uuidString)"
            if !processArgs.contains(where: { $0.hasPrefix("-env:UserInstallation=") }) {
                processArgs.insert("-env:UserInstallation=\(loProfile)", at: 0)
            }
        }

        let process = Process()
        process.executableURL = toolURL
        process.arguments = processArgs
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

        let activityLock = NSLock()
        var lastActivityTime = Date().timeIntervalSinceReferenceDate

        let outGroup = DispatchGroup()
        var outDrained = false
        let outDrainLock = NSLock()
        if redirectHandle == nil {
            outGroup.enter()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    outDrainLock.lock()
                    if !outDrained {
                        outDrained = true
                        outGroup.leave()
                    }
                    outDrainLock.unlock()
                } else {
                    collector.appendOut(chunk)
                    activityLock.lock()
                    lastActivityTime = Date().timeIntervalSinceReferenceDate
                    activityLock.unlock()
                }
            }
        }

        let errGroup = DispatchGroup()
        var errDrained = false
        let errDrainLock = NSLock()
        errGroup.enter()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                errDrainLock.lock()
                if !errDrained {
                    errDrained = true
                    errGroup.leave()
                }
                errDrainLock.unlock()
            } else {
                collector.appendErr(chunk)
                activityLock.lock()
                lastActivityTime = Date().timeIntervalSinceReferenceDate
                activityLock.unlock()
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

        let effectiveInactivityTimeout: TimeInterval?
        if let explicit = inactivityTimeoutSeconds, explicit > 0 {
            effectiveInactivityTimeout = explicit
        } else if let explicit = inactivityTimeoutSeconds, explicit <= 0 {
            effectiveInactivityTimeout = nil
        } else {
            effectiveInactivityTimeout = invocation.inactivityTimeoutSeconds
        }

        var timer: DispatchSourceTimer?
        var timedOut = false
        if let timeout = effectiveTimeout, timeout > 0 {
            let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
            t.schedule(deadline: .now() + timeout)
            t.setEventHandler { [weak process] in
                activityLock.lock()
                timedOut = true
                activityLock.unlock()
                if let p = process { JobRunner.shared.terminateGracefully(p) }
            }
            t.resume()
            timer = t
        }

        var watchdogTimer: DispatchSourceTimer?
        var watchdogTimedOut = false
        if let inact = effectiveInactivityTimeout, inact > 0 {
            let wt = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
            let checkInterval = max(min(0.2, inact / 4.0), 0.05)
            wt.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
            wt.setEventHandler { [weak process] in
                activityLock.lock()
                let elapsed = Date().timeIntervalSinceReferenceDate - lastActivityTime
                if elapsed >= inact {
                    watchdogTimedOut = true
                    activityLock.unlock()
                    if let p = process { JobRunner.shared.terminateGracefully(p) }
                } else {
                    activityLock.unlock()
                }
            }
            wt.resume()
            watchdogTimer = wt
        }

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            sema.signal()
        }

        do {
            try process.run()
        } catch {
            timer?.cancel()
            watchdogTimer?.cancel()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw PastaError.executionFailed(tool: invocation.toolName, exitCode: 1, output: error.localizedDescription)
        }

        sema.wait()
        timer?.cancel()
        watchdogTimer?.cancel()

        if redirectHandle == nil {
            _ = outGroup.wait(timeout: .now() + 2.0)
            outPipe.fileHandleForReading.readabilityHandler = nil
            let remOut = outPipe.fileHandleForReading.readDataToEndOfFile()
            if !remOut.isEmpty { collector.appendOut(remOut) }
        }
        _ = errGroup.wait(timeout: .now() + 2.0)
        errPipe.fileHandleForReading.readabilityHandler = nil
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

        activityLock.lock()
        let didTimeOut = timedOut
        let didWatchdogTimeOut = watchdogTimedOut
        activityLock.unlock()

        if didTimeOut {
            throw PastaError.timedOut(tool: invocation.toolName)
        }

        if didWatchdogTimeOut {
            throw PastaError.timedOut(tool: "\(invocation.toolName) (inactivity watchdog)")
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

    public func execute(
        invocation: Invocation,
        timeoutSeconds: TimeInterval? = nil,
        inactivityTimeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) throws {
        _ = try executeCapture(
            invocation: invocation,
            timeoutSeconds: timeoutSeconds,
            inactivityTimeoutSeconds: inactivityTimeoutSeconds,
            jobId: jobId
        )
    }

    @discardableResult
    public func runAsync(
        action: ConversionAction,
        input: URL,
        destinationDirectory: URL? = nil,
        parameters: ParameterValues = [:],
        timeoutSeconds: TimeInterval? = nil,
        inactivityTimeoutSeconds: TimeInterval? = nil,
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

            let reservation: OutputReservation
            if isFolder {
                reservation = try OutputPlanner.reserveOutputDirectory(for: input, suffix: folderSuffix, destinationDirectory: effectiveDest)
            } else {
                reservation = try OutputPlanner.reserveOutput(for: input, targetExtension: action.outputExtension, destinationDirectory: effectiveDest)
            }
            defer {
                reservation.cleanup()
            }
            let finalDestinationURL = reservation.url

            PastaLogger.shared.info("Starting async action \(action.id) on '\(input.lastPathComponent)' -> '\(finalDestinationURL.lastPathComponent)'")

            let tempDir = try OutputPlanner.makeTempDirectory()
            let loProfileDir = URL(fileURLWithPath: "/tmp/Pasta_lo_\(jobId.uuidString)")
            defer {
                processLock.lock()
                cancelledJobIds.remove(jobId)
                processLock.unlock()
                // Safe to swallow: best-effort temporary scratch directory removal on scope exit
                try? fm.removeItem(at: tempDir)
                try? fm.removeItem(at: loProfileDir)
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
                if self.isJobCancelled(jobId) {
                    throw PastaError.cancelled
                }
            } else {
                let invocations = action.buildInvocationsWithParams(input, tempWorkingOutputURL, effectiveParams)
                guard !invocations.isEmpty else {
                    throw PastaError.executionFailed(tool: "engine", exitCode: 1, output: "No invocations built for action \(action.id)")
                }

                for inv in invocations {
                    try await executeAsync(
                        invocation: inv,
                        timeoutSeconds: timeoutSeconds,
                        inactivityTimeoutSeconds: inactivityTimeoutSeconds,
                        jobId: jobId
                    )
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
                try Self.validateFolderJail(at: tempWorkingOutputURL)
                try reservation.publish(from: tempWorkingOutputURL)
                return finalDestinationURL
            }

            if !fm.fileExists(atPath: tempWorkingOutputURL.path) {
                let looseFiles = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil).filter {
                    $0.lastPathComponent != "output_items" && $0.pathExtension.lowercased() == action.outputExtension.lowercased()
                }
                if looseFiles.count == 1 {
                    try fm.moveItem(at: looseFiles[0], to: tempWorkingOutputURL)
                }
            }

            guard fm.fileExists(atPath: tempWorkingOutputURL.path) else {
                throw PastaError.outputNotFound(finalDestinationURL.path)
            }

            try reservation.publish(from: tempWorkingOutputURL)
            PastaLogger.shared.info("Successfully completed async \(action.id) -> '\(finalDestinationURL.path)'")
            return finalDestinationURL
        } onCancel: {
            self.cancel(jobId: jobId)
        }
    }

    public func executeAsync(
        invocation: Invocation,
        timeoutSeconds: TimeInterval? = nil,
        inactivityTimeoutSeconds: TimeInterval? = nil,
        jobId: UUID = UUID()
    ) async throws {
        try Task.checkCancellation()
        if isJobCancelled(jobId) {
            throw PastaError.cancelled
        }

        let toolURL = try ToolLocator.shared.requireTool(invocation.toolName)

        var processArgs = invocation.arguments
        if invocation.toolName == "soffice" {
            let loProfile = "file:///tmp/Pasta_lo_\(jobId.uuidString)"
            if !processArgs.contains(where: { $0.hasPrefix("-env:UserInstallation=") }) {
                processArgs.insert("-env:UserInstallation=\(loProfile)", at: 0)
            }
        }

        let process = Process()
        process.executableURL = toolURL
        process.arguments = processArgs
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

        let effectiveTimeout: TimeInterval?
        if let explicit = timeoutSeconds, explicit > 0 {
            effectiveTimeout = explicit
        } else if let explicit = timeoutSeconds, explicit <= 0 {
            effectiveTimeout = nil
        } else {
            effectiveTimeout = invocation.timeoutSeconds
        }

        let effectiveInactivityTimeout: TimeInterval?
        if let explicit = inactivityTimeoutSeconds, explicit > 0 {
            effectiveInactivityTimeout = explicit
        } else if let explicit = inactivityTimeoutSeconds, explicit <= 0 {
            effectiveInactivityTimeout = nil
        } else {
            effectiveInactivityTimeout = invocation.inactivityTimeoutSeconds
        }

        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var timer: DispatchSourceTimer?
            var watchdogTimer: DispatchSourceTimer?
            var didTimeout = false
            var didWatchdogTimeout = false
            var lastActivity = Date().timeIntervalSinceReferenceDate

            func setTimer(_ t: DispatchSourceTimer) { lock.lock(); defer { lock.unlock() }; timer = t }
            func setWatchdogTimer(_ t: DispatchSourceTimer) { lock.lock(); defer { lock.unlock() }; watchdogTimer = t }
            func cancelTimers() {
                lock.lock(); defer { lock.unlock() }
                timer?.cancel()
                watchdogTimer?.cancel()
            }
            func markTimeout() { lock.lock(); defer { lock.unlock() }; didTimeout = true }
            func markWatchdogTimeout() { lock.lock(); defer { lock.unlock() }; didWatchdogTimeout = true }
            func touchActivity() { lock.lock(); defer { lock.unlock() }; lastActivity = Date().timeIntervalSinceReferenceDate }
            func timeSinceActivity() -> TimeInterval {
                lock.lock(); defer { lock.unlock() }
                return Date().timeIntervalSinceReferenceDate - lastActivity
            }
            var timedOut: Bool { lock.lock(); defer { lock.unlock() }; return didTimeout }
            var watchdogTimedOut: Bool { lock.lock(); defer { lock.unlock() }; return didWatchdogTimeout }
        }
        let box = Box()

        if redirectHandle == nil {
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    collector.appendOut(chunk)
                    box.touchActivity()
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                collector.appendErr(chunk)
                box.touchActivity()
            }
        }

        let rHandle = redirectHandle

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    box.cancelTimers()
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

                    if box.watchdogTimedOut {
                        continuation.resume(throwing: PastaError.timedOut(tool: "\(invocation.toolName) (inactivity watchdog)"))
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

                if let inact = effectiveInactivityTimeout, inact > 0 {
                    let wt = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
                    let checkInterval = max(min(0.2, inact / 4.0), 0.05)
                    wt.schedule(deadline: .now() + checkInterval, repeating: checkInterval)
                    wt.setEventHandler { [weak process] in
                        if box.timeSinceActivity() >= inact {
                            box.markWatchdogTimeout()
                            process?.terminate()
                        }
                    }
                    wt.resume()
                    box.setWatchdogTimer(wt)
                }

                do {
                    try process.run()
                } catch {
                    box.cancelTimers()
                    _ = self.untrackProcess(for: jobId)
                    continuation.resume(throwing: PastaError.executionFailed(tool: invocation.toolName, exitCode: 1, output: error.localizedDescription))
                }
            }
        } onCancel: {
            self.cancel(jobId: jobId)
        }
    }
}
