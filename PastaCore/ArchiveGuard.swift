import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Configurable limits for untrusted archive extraction.
public struct ArchiveLimits {
    public var maxTotalEntries: Int
    public var maxDirectoryDepth: Int
    public var maxPathLength: Int
    public var maxSingleFileSize: Int64
    public var maxTotalExpandedSize: Int64
    public var rejectSetuidSetgid: Bool

    public static let standard = ArchiveLimits(
        maxTotalEntries: 100_000,
        maxDirectoryDepth: 64,
        maxPathLength: 1024,
        maxSingleFileSize: 4 * 1024 * 1024 * 1024, // 4 GB
        maxTotalExpandedSize: 8 * 1024 * 1024 * 1024, // 8 GB
        rejectSetuidSetgid: true
    )
}

/// Hardened guard against malicious and malformed archive extraction.
/// Defends against Zip Slip, absolute path injection, symlink hops, hard links,
/// decompression bombs, deep recursion, and setuid/setgid privilege escalation.
public enum ArchiveGuard {

    private static func isProhibitedPath(_ path: String) -> Bool {
        let p = path.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return false }
        if p.hasPrefix("/") || p.hasPrefix("\\") {
            return true
        }
        if p == ".." ||
           p.hasPrefix("../") ||
           p.contains("/../") ||
           p.hasSuffix("/..") ||
           p.hasPrefix("..\\") ||
           p.contains("\\..\\") ||
           p.hasSuffix("\\..") ||
           p.contains("../") ||
           p.contains("..\\") {
            return true
        }
        return false
    }

    /// Preflight inspects archive catalog before extraction for tools supporting safe listing.
    public static func preflightInspect(archiveURL: URL, toolName: String, limits: ArchiveLimits = .standard) throws {
        let proc = Process()
        let isLsar: Bool
        if toolName == "tar" {
            guard let toolURL = ToolLocator.shared.findTool("tar") else { return }
            proc.executableURL = toolURL
            proc.arguments = ["-tvf", archiveURL.path]
            isLsar = false
        } else if toolName == "7zz" {
            guard let toolURL = ToolLocator.shared.findTool("7zz") else { return }
            proc.executableURL = toolURL
            proc.arguments = ["l", "-slt", archiveURL.path]
            isLsar = false
        } else if toolName == "unar" {
            if let lsarTool = ToolLocator.shared.findTool("lsar") {
                proc.executableURL = lsarTool
                proc.arguments = ["-l", archiveURL.path]
                isLsar = true
            } else if let sevenzTool = ToolLocator.shared.findTool("7zz") {
                proc.executableURL = sevenzTool
                proc.arguments = ["l", "-slt", archiveURL.path]
                isLsar = false
            } else {
                return
            }
        } else if toolName == "ditto" {
            if archiveURL.pathExtension.lowercased() == "zip",
               FileManager.default.isExecutableFile(atPath: "/usr/bin/zipinfo") {
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
                proc.arguments = ["-s", archiveURL.path]
                isLsar = false
            } else {
                return
            }
        } else {
            return
        }

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            return
        }

        var entryCount = 0
        var totalDeclaredBytes: Int64 = 0
        var in7zEntries = (toolName != "7zz" && !isLsar)
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if toolName == "7zz" || (toolName == "unar" && !isLsar) {
                if trimmed.hasPrefix("----------") {
                    in7zEntries = true
                    continue
                }
                guard in7zEntries else { continue }
                if trimmed.hasPrefix("Path = ") {
                    entryCount += 1
                    if entryCount > limits.maxTotalEntries {
                        throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                    }
                    let entryPath = String(trimmed.dropFirst("Path = ".count)).trimmingCharacters(in: .whitespaces)
                    if entryPath != archiveURL.path && entryPath != archiveURL.lastPathComponent {
                        if isProhibitedPath(entryPath) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryPath)'")
                        }
                    }
                } else if trimmed.hasPrefix("Size = ") {
                    let sizeStr = String(trimmed.dropFirst("Size = ".count)).trimmingCharacters(in: .whitespaces)
                    if let size = Int64(sizeStr) {
                        if size > limits.maxSingleFileSize {
                            throw PastaError.invalidInput("Archive entry declared size (\(size) bytes) exceeds maximum single-file limit of \(limits.maxSingleFileSize) bytes")
                        }
                        totalDeclaredBytes += size
                        if totalDeclaredBytes > limits.maxTotalExpandedSize {
                            throw PastaError.invalidInput("Archive declared uncompressed size (\(totalDeclaredBytes) bytes) exceeds maximum limit of \(limits.maxTotalExpandedSize) bytes")
                        }
                    }
                } else if trimmed.hasPrefix("Symbolic Link = ") {
                    let target = String(trimmed.dropFirst("Symbolic Link = ".count)).trimmingCharacters(in: .whitespaces)
                    if isProhibitedPath(target) {
                        throw PastaError.invalidInput("Prohibited symlink target in archive: '\(target)' (points outside archive jail)")
                    }
                } else if trimmed.hasPrefix("Hard Link = ") {
                    let target = String(trimmed.dropFirst("Hard Link = ".count)).trimmingCharacters(in: .whitespaces)
                    if isProhibitedPath(target) {
                        throw PastaError.invalidInput("Prohibited hardlink target in archive: '\(target)' (points outside archive jail)")
                    }
                }
            } else if toolName == "tar" {
                if let arrowRange = line.range(of: " -> ") {
                    entryCount += 1
                    if entryCount > limits.maxTotalEntries {
                        throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                    }
                    let target = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if isProhibitedPath(target) {
                        throw PastaError.invalidInput("Prohibited symlink target in archive: '\(target)' (points outside archive jail)")
                    }
                    let leftPart = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let tokens = leftPart.split(separator: " ", omittingEmptySubsequences: true)
                    if let entryName = tokens.last {
                        if isProhibitedPath(String(entryName)) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryName)'")
                        }
                    }
                } else if let linkToRange = line.range(of: " link to ") {
                    entryCount += 1
                    if entryCount > limits.maxTotalEntries {
                        throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                    }
                    let target = String(line[linkToRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if isProhibitedPath(target) {
                        throw PastaError.invalidInput("Prohibited hardlink target in archive: '\(target)' (points outside archive jail)")
                    }
                    let leftPart = String(line[..<linkToRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let tokens = leftPart.split(separator: " ", omittingEmptySubsequences: true)
                    if let entryName = tokens.last {
                        if isProhibitedPath(String(entryName)) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryName)'")
                        }
                    }
                } else {
                    let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                    if tokens.count >= 9 {
                        entryCount += 1
                        if entryCount > limits.maxTotalEntries {
                            throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                        }
                        if let size = Int64(tokens[4]) {
                            if size > limits.maxSingleFileSize {
                                throw PastaError.invalidInput("Archive entry declared size (\(size) bytes) exceeds single-file limit of \(limits.maxSingleFileSize) bytes")
                            }
                            totalDeclaredBytes += size
                            if totalDeclaredBytes > limits.maxTotalExpandedSize {
                                throw PastaError.invalidInput("Archive declared uncompressed size (\(totalDeclaredBytes) bytes) exceeds maximum limit of \(limits.maxTotalExpandedSize) bytes")
                            }
                        }
                        let entryPath = tokens[8...].joined(separator: " ")
                        if isProhibitedPath(entryPath) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryPath)'")
                        }
                    }
                }
            } else if toolName == "unar" && isLsar {
                if let arrowRange = line.range(of: " -> ") {
                    entryCount += 1
                    if entryCount > limits.maxTotalEntries {
                        throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                    }
                    let target = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if isProhibitedPath(target) {
                        throw PastaError.invalidInput("Prohibited link target in archive: '\(target)' (points outside archive jail)")
                    }
                    let leftPart = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let tokens = leftPart.split(separator: " ", omittingEmptySubsequences: true)
                    if let entryName = tokens.last {
                        if isProhibitedPath(String(entryName)) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryName)'")
                        }
                    }
                } else {
                    let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                    if tokens.count >= 7 && (tokens[0].hasSuffix(".") || Int(tokens[0].dropLast()) != nil) {
                        entryCount += 1
                        if entryCount > limits.maxTotalEntries {
                            throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                        }
                        if let size = Int64(tokens[2]) {
                            if size > limits.maxSingleFileSize {
                                throw PastaError.invalidInput("Archive entry declared size (\(size) bytes) exceeds single-file limit of \(limits.maxSingleFileSize) bytes")
                            }
                            totalDeclaredBytes += size
                            if totalDeclaredBytes > limits.maxTotalExpandedSize {
                                throw PastaError.invalidInput("Archive declared uncompressed size (\(totalDeclaredBytes) bytes) exceeds maximum limit of \(limits.maxTotalExpandedSize) bytes")
                            }
                        }
                        let entryName = tokens[6...].joined(separator: " ")
                        if isProhibitedPath(entryName) {
                            throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryName)'")
                        }
                    }
                }
            } else if toolName == "ditto" {
                let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= 7 else { continue }
                entryCount += 1
                if entryCount > limits.maxTotalEntries {
                    throw PastaError.invalidInput("Archive catalog entry count exceeds maximum allowed limit of \(limits.maxTotalEntries) entries")
                }
                if let size = Int64(tokens[3]) {
                    if size > limits.maxSingleFileSize {
                        throw PastaError.invalidInput("Archive entry declared size (\(size) bytes) exceeds single-file limit of \(limits.maxSingleFileSize) bytes")
                    }
                    totalDeclaredBytes += size
                    if totalDeclaredBytes > limits.maxTotalExpandedSize {
                        throw PastaError.invalidInput("Archive declared uncompressed size (\(totalDeclaredBytes) bytes) exceeds maximum limit of \(limits.maxTotalExpandedSize) bytes")
                    }
                }
                let entryName = tokens[6...].joined(separator: " ")
                if entryName == archiveURL.path || entryName == archiveURL.lastPathComponent {
                    continue
                }
                if isProhibitedPath(entryName) {
                    throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryName)'")
                }
                if tokens[0].hasPrefix("l") && FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip") {
                    let targetProc = Process()
                    targetProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                    targetProc.arguments = ["-p", archiveURL.path, entryName]
                    let targetPipe = Pipe()
                    targetProc.standardOutput = targetPipe
                    targetProc.standardError = FileHandle.nullDevice
                    if let _ = try? targetProc.run() {
                        let targetData = targetPipe.fileHandleForReading.readDataToEndOfFile()
                        targetProc.waitUntilExit()
                        if let target = String(data: targetData, encoding: .utf8)?.trimmingCharacters(in: .newlines),
                           isProhibitedPath(target) {
                            throw PastaError.invalidInput("Prohibited symlink target in archive: '\(target)' (points outside archive jail)")
                        }
                    }
                }
            }
        }
    }

    /// Validates the extracted directory hierarchy against path escapes and resource exhaustion.
    public static func validate(root rootURL: URL, limits: ArchiveLimits = .standard) throws {
        let fm = FileManager.default
        let rootCanon = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let rootWithSlash = rootCanon.hasSuffix("/") ? rootCanon : rootCanon + "/"

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            throw PastaError.executionFailed(tool: "archive", exitCode: 1, output: "Unable to enumerate extracted archive directory")
        }

        var entryCount = 0
        var totalExpandedBytes: Int64 = 0
        var inodeCounts: [UInt64: Int] = [:]
        var filesWithMultipleLinks: [(URL, nlink_t, UInt64)] = []

        for case let fileURL as URL in enumerator {
            entryCount += 1
            if entryCount > limits.maxTotalEntries {
                throw PastaError.invalidInput("Archive exceeds maximum allowed entry count of \(limits.maxTotalEntries) entries")
            }

            let pathStr = fileURL.path
            let relPath = String(pathStr.dropFirst(rootURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let components = relPath.split(separator: "/")

            if components.count > limits.maxDirectoryDepth {
                throw PastaError.invalidInput("Archive directory depth (\(components.count)) exceeds maximum allowed limit of \(limits.maxDirectoryDepth)")
            }

            if relPath.count > limits.maxPathLength {
                throw PastaError.invalidInput("Archive path length (\(relPath.count)) exceeds maximum allowed limit of \(limits.maxPathLength) characters")
            }

            var statBuf = stat()
            guard lstat(pathStr, &statBuf) == 0 else {
                continue
            }

            let mode = statBuf.st_mode
            let fileType = (mode & S_IFMT)

            // Reject special device nodes, FIFOs, and sockets
            if fileType != S_IFREG && fileType != S_IFDIR && fileType != S_IFLNK {
                throw PastaError.invalidInput("Archive contains prohibited special device or FIFO node: '\(fileURL.lastPathComponent)'")
            }

            // Reject or clear setuid and setgid permission bits
            if (mode & mode_t(S_ISUID)) != 0 || (mode & mode_t(S_ISGID)) != 0 {
                if limits.rejectSetuidSetgid {
                    throw PastaError.invalidInput("Archive contains prohibited elevated privilege binary (setuid/setgid bits set): '\(fileURL.lastPathComponent)'")
                } else {
                    chmod(pathStr, mode & ~mode_t(S_ISUID | S_ISGID))
                }
            }

            // Symlink and path traversal checks
            let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            if resolved != rootCanon && !resolved.hasPrefix(rootWithSlash) {
                throw PastaError.invalidInput("Path traversal detected: item '\(fileURL.lastPathComponent)' escapes archive boundary (\(resolved))")
            }

            // Check symlink destination specifically (both relative and absolute)
            if fileType == S_IFLNK {
                if let dest = try? fm.destinationOfSymbolicLink(atPath: pathStr) {
                    let targetURL: URL
                    if dest.hasPrefix("/") {
                        targetURL = URL(fileURLWithPath: dest)
                    } else {
                        targetURL = fileURL.deletingLastPathComponent().appendingPathComponent(dest)
                    }
                    let targetCanon = targetURL.standardizedFileURL.path
                    let linkResolved = targetURL.resolvingSymlinksInPath().standardizedFileURL.path
                    if (targetCanon != rootCanon && !targetCanon.hasPrefix(rootWithSlash)) ||
                       (linkResolved != rootCanon && !linkResolved.hasPrefix(rootWithSlash)) {
                        throw PastaError.invalidInput("Path traversal detected: symlink '\(fileURL.lastPathComponent)' points outside archive jail (\(dest))")
                    }
                }
            }

            // Size checks and hard link tracking for regular files
            if fileType == S_IFREG {
                let ino = UInt64(statBuf.st_ino)
                inodeCounts[ino, default: 0] += 1
                if statBuf.st_nlink > 1 {
                    filesWithMultipleLinks.append((fileURL, statBuf.st_nlink, ino))
                }

                let fSize = statBuf.st_size
                if fSize > limits.maxSingleFileSize {
                    throw PastaError.invalidInput("Archive file '\(fileURL.lastPathComponent)' size (\(fSize) bytes) exceeds single-file limit of \(limits.maxSingleFileSize) bytes")
                }
                totalExpandedBytes += fSize
                if totalExpandedBytes > limits.maxTotalExpandedSize {
                    throw PastaError.invalidInput("Archive total expanded size (\(totalExpandedBytes) bytes) exceeds maximum limit of \(limits.maxTotalExpandedSize) bytes")
                }
            }
        }

        // Verify hard links: every hard link to a file inside the archive must reside inside the archive
        for (fileURL, expectedLinks, ino) in filesWithMultipleLinks {
            let actualInRoot = inodeCounts[ino] ?? 0
            if actualInRoot < Int(expectedLinks) {
                throw PastaError.invalidInput("Hard link escape detected: item '\(fileURL.lastPathComponent)' links to a file outside the archive boundary")
            }
        }
    }

    /// Recursively computes current bytes occupied by regular files in a directory.
    public static func directorySize(at rootURL: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            var statBuf = stat()
            if lstat(fileURL.path, &statBuf) == 0 {
                if (statBuf.st_mode & S_IFMT) == S_IFREG {
                    total += Int64(statBuf.st_size)
                }
            }
        }
        return total
    }

    /// Enforces running size cap on scratch directory during extraction.
    /// If total extracted size in scratch directory exceeds limits, the process is killed
    /// immediately and the scratch directory is wiped.
    public static func executeWithRunningCap(
        runner: JobRunner,
        invocation: Invocation,
        scratchURL: URL,
        jobId: UUID,
        limits: ArchiveLimits = .standard,
        pollIntervalSeconds: TimeInterval = 0.02
    ) throws {
        final class MonitorState: @unchecked Sendable {
            var isRunning = true
            var capBreached = false
            var breachedBytes: Int64 = 0
            let lock = NSLock()
        }

        let state = MonitorState()
        let queue = DispatchQueue(label: "com.pasta.runningcap.\(jobId)", qos: .userInitiated)

        queue.async {
            while true {
                Thread.sleep(forTimeInterval: pollIntervalSeconds)
                state.lock.lock()
                let running = state.isRunning
                state.lock.unlock()
                if !running { break }

                let currentSize = Self.directorySize(at: scratchURL)
                if currentSize > limits.maxTotalExpandedSize {
                    state.lock.lock()
                    state.capBreached = true
                    state.breachedBytes = currentSize
                    state.isRunning = false
                    state.lock.unlock()

                    // Immediately kill the extractor process
                    runner.cancel(jobId: jobId)
                    break
                }
            }
        }

        var execError: Error?
        do {
            try runner.execute(invocation: invocation, jobId: jobId)
        } catch {
            execError = error
        }

        state.lock.lock()
        state.isRunning = false
        var breached = state.capBreached
        var size = state.breachedBytes
        state.lock.unlock()

        if !breached {
            let finalSize = Self.directorySize(at: scratchURL)
            if finalSize > limits.maxTotalExpandedSize {
                breached = true
                size = finalSize
            }
        }

        if breached {
            // Wipe scratch directory immediately to prevent disk exhaustion
            try? FileManager.default.removeItem(at: scratchURL)
            throw PastaError.invalidInput("Archive extraction exceeded running expansion limit of \(limits.maxTotalExpandedSize) bytes (reached \(size) bytes); process terminated and scratch wiped")
        }

        if let error = execError {
            throw error
        }
    }
}
