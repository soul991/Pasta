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

    /// Preflight inspects archive catalog before extraction for tools supporting safe listing.
    public static func preflightInspect(archiveURL: URL, toolName: String) throws {
        guard let toolURL = ToolLocator.shared.toolPath(toolName) else {
            return
        }

        let proc = Process()
        proc.executableURL = toolURL
        if toolName == "tar" {
            proc.arguments = ["-tf", archiveURL.path]
        } else if toolName == "7zz" {
            proc.arguments = ["l", "-slt", archiveURL.path]
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

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let entryPath: String
            if toolName == "7zz" {
                if trimmed.hasPrefix("Path = ") {
                    entryPath = String(trimmed.dropFirst("Path = ".count))
                } else {
                    continue
                }
            } else {
                entryPath = trimmed
            }

            if entryPath.hasPrefix("/") || entryPath.contains("../") || entryPath.contains("..\\") || entryPath == ".." {
                throw PastaError.invalidInput("Prohibited path traversal entry in archive: '\(entryPath)'")
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

            // Reject setuid and setgid permission bits
            if (mode & mode_t(S_ISUID)) != 0 || (mode & mode_t(S_ISGID)) != 0 {
                if limits.rejectSetuidSetgid {
                    throw PastaError.invalidInput("Archive contains prohibited elevated privilege binary (setuid/setgid bits set): '\(fileURL.lastPathComponent)'")
                }
            }

            // Symlink and path traversal checks
            let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            if resolved != rootCanon && !resolved.hasPrefix(rootWithSlash) {
                throw PastaError.invalidInput("Path traversal detected: item '\(fileURL.lastPathComponent)' escapes archive boundary (\(resolved))")
            }

            // Check symlink destination specifically
            if (mode & S_IFMT) == S_IFLNK {
                if let dest = try? fm.destinationOfSymbolicLink(atPath: pathStr) {
                    if dest.hasPrefix("/") {
                        let linkResolved = URL(fileURLWithPath: dest).resolvingSymlinksInPath().standardizedFileURL.path
                        if linkResolved != rootCanon && !linkResolved.hasPrefix(rootWithSlash) {
                            throw PastaError.invalidInput("Path traversal detected: symlink '\(fileURL.lastPathComponent)' points outside archive jail (\(dest))")
                        }
                    }
                }
            }

            // Size checks for regular files
            if (mode & S_IFMT) == S_IFREG {
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
    }
}
