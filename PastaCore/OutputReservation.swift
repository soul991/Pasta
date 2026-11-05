import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Holds an atomically claimed output path (file or directory placeholder).
/// Guarantees that concurrent jobs or processes will never overwrite each other's outputs.
/// On success, `publish(from:)` atomically renames the staging output over the placeholder.
/// On failure or cancellation, `cleanup()` safely unlinks the placeholder if and only if
/// it is still empty and matches our created inode and device ID.
public final class OutputReservation {
    public let url: URL
    public let isDirectory: Bool
    public let deviceId: dev_t
    public let inode: ino_t
    private var isPublished: Bool = false
    private let lock = NSLock()

    public init(url: URL, isDirectory: Bool, deviceId: dev_t, inode: ino_t) {
        self.url = url
        self.isDirectory = isDirectory
        self.deviceId = deviceId
        self.inode = inode
    }

    deinit {
        cleanup()
    }

    /// Atomically publishes the verified working output over our reserved placeholder.
    public func publish(from tempWorkingURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isPublished else { return }

        let srcPath = tempWorkingURL.path
        let dstPath = url.path

        // On macOS / POSIX, rename(2) atomically replaces the target placeholder.
        // For directories, rename(2) over an empty directory is permitted.
        if rename(srcPath, dstPath) != 0 {
            let err: Int32 = errno
            if err == EXDEV {
                // Cross-device link fallback: stage inside target destination directory, then rename
                let stagingURL = url.deletingLastPathComponent().appendingPathComponent(".pasta_stage_\(UUID().uuidString)")
                let fm = FileManager.default
                try fm.copyItem(at: tempWorkingURL, to: stagingURL)
                if rename(stagingURL.path, dstPath) != 0 {
                    let stageErr: Int32 = errno
                    if isDirectory {
                        _ = rmdir(stagingURL.path)
                    } else {
                        _ = unlink(stagingURL.path)
                    }
                    let stageMsg = String(cString: strerror(stageErr))
                    throw PastaError.executionFailed(tool: "filesystem", exitCode: Int(stageErr), output: "Failed to publish cross-device output: \(stageMsg)")
                }
            } else {
                let errMsg = String(cString: strerror(err))
                throw PastaError.executionFailed(tool: "filesystem", exitCode: Int(err), output: "Failed to atomically publish output via rename(2): \(errMsg)")
            }
        }

        isPublished = true
        OutputPlanner.unregisterReservation(url)
    }

    /// Safe release: unlinks placeholder only if it still belongs to us and is empty.
    public func cleanup() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPublished else { return }

        OutputPlanner.unregisterReservation(url)

        var statBuf = stat()
        if stat(url.path, &statBuf) == 0 {
            // Verify device and inode match creation record
            if statBuf.st_dev == deviceId && statBuf.st_ino == inode {
                if isDirectory {
                    // Only rmdir if it's an empty directory
                    _ = rmdir(url.path)
                } else {
                    // Only unlink if it's still an empty 0-byte placeholder
                    if statBuf.st_size == 0 {
                        _ = unlink(url.path)
                    }
                }
            }
        }
    }
}
