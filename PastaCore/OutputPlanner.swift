import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct OutputPlanner {
    private static var activeReservedPaths = Set<String>()
    private static let reservationLock = NSLock()

    internal static func unregisterReservation(_ url: URL) {
        reservationLock.lock()
        activeReservedPaths.remove(url.standardizedFileURL.path)
        reservationLock.unlock()
    }

    /// Atomically claims an output filename using open(2) with O_CREAT | O_EXCL.
    /// Never reserves the input path, and retries with numbered suffixes on collision.
    public static func reserveOutput(for inputURL: URL, targetExtension: String, destinationDirectory: URL? = nil) throws -> OutputReservation {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        let ext = targetExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let inputStandardized = inputURL.standardizedFileURL.path

        var counter = 0
        while true {
            let candidateName: String
            if counter == 0 {
                candidateName = ext.isEmpty ? originalBaseName : "\(originalBaseName).\(ext)"
            } else {
                candidateName = ext.isEmpty ? "\(originalBaseName) \(counter)" : "\(originalBaseName) \(counter).\(ext)"
            }
            let candidateURL = directory.appendingPathComponent(candidateName)
            let candidatePath = candidateURL.standardizedFileURL.path

            // Never plan or reserve the input path
            if candidatePath == inputStandardized {
                counter += 1
                continue
            }

            reservationLock.lock()
            if activeReservedPaths.contains(candidatePath) {
                reservationLock.unlock()
                counter += 1
                continue
            }

            // Claim the file atomically using open(2) with O_CREAT | O_EXCL | O_WRONLY
            let fd = open(candidatePath, O_CREAT | O_EXCL | O_WRONLY, 0o600)
            if fd != -1 {
                var statBuf = stat()
                fstat(fd, &statBuf)
                close(fd)
                activeReservedPaths.insert(candidatePath)
                reservationLock.unlock()
                return OutputReservation(url: candidateURL, isDirectory: false, deviceId: statBuf.st_dev, inode: statBuf.st_ino)
            } else {
                let err: Int32 = errno
                reservationLock.unlock()
                if err == EEXIST {
                    counter += 1
                    continue
                } else {
                    let errMsg = String(cString: strerror(err))
                    throw PastaError.executionFailed(tool: "filesystem", exitCode: err, output: "Failed to atomically reserve output file '\(candidatePath)': \(errMsg)")
                }
            }
        }
    }

    /// Atomically claims an output directory using mkdir(2).
    /// Never reserves the input path, and retries with numbered suffixes on collision.
    public static func reserveOutputDirectory(for inputURL: URL, suffix: String = "extracted", destinationDirectory: URL? = nil) throws -> OutputReservation {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        let inputStandardized = inputURL.standardizedFileURL.path

        var counter = 0
        while true {
            let candidateName: String
            if counter == 0 {
                candidateName = "\(originalBaseName) \(suffix)"
            } else {
                candidateName = "\(originalBaseName) \(suffix) \(counter)"
            }
            let candidateURL = directory.appendingPathComponent(candidateName)
            let candidatePath = candidateURL.standardizedFileURL.path

            if candidatePath == inputStandardized {
                counter += 1
                continue
            }

            reservationLock.lock()
            if activeReservedPaths.contains(candidatePath) {
                reservationLock.unlock()
                counter += 1
                continue
            }

            // Claim directory atomically via mkdir(2) with 0o700
            if mkdir(candidatePath, 0o700) == 0 {
                var statBuf = stat()
                stat(candidatePath, &statBuf)
                activeReservedPaths.insert(candidatePath)
                reservationLock.unlock()
                return OutputReservation(url: candidateURL, isDirectory: true, deviceId: statBuf.st_dev, inode: statBuf.st_ino)
            } else {
                let err: Int32 = errno
                reservationLock.unlock()
                if err == EEXIST {
                    counter += 1
                    continue
                } else {
                    let errMsg = String(cString: strerror(err))
                    throw PastaError.executionFailed(tool: "filesystem", exitCode: err, output: "Failed to atomically reserve output directory '\(candidatePath)': \(errMsg)")
                }
            }
        }
    }

    public static func planOutput(for inputURL: URL, targetExtension: String, destinationDirectory: URL? = nil) -> URL {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        let ext = targetExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        var candidateName = ext.isEmpty ? originalBaseName : "\(originalBaseName).\(ext)"
        var candidateURL = directory.appendingPathComponent(candidateName)
        
        let fm = FileManager.default
        // Must not overwrite existing file or input file itself
        if !fm.fileExists(atPath: candidateURL.path) && candidateURL.path != inputURL.path {
            return candidateURL
        }
        
        var counter = 1
        while true {
            candidateName = ext.isEmpty ? "\(originalBaseName) \(counter)" : "\(originalBaseName) \(counter).\(ext)"
            candidateURL = directory.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidateURL.path) && candidateURL.path != inputURL.path {
                return candidateURL
            }
            counter += 1
        }
    }
    
    public static func planOutputDirectory(for inputURL: URL, suffix: String = "extracted", destinationDirectory: URL? = nil) -> URL {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        
        var candidateName = "\(originalBaseName) \(suffix)"
        var candidateURL = directory.appendingPathComponent(candidateName)
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }
        
        var counter = 1
        while true {
            candidateName = "\(originalBaseName) \(suffix) \(counter)"
            candidateURL = directory.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
    
    public static func makeTempDirectory() throws -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Pasta_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
