import Foundation
import CommonCrypto

/// Protocol abstracting trash operations to enable deterministic testing without mutating real filesystem trash.
public protocol TrashProvider: AnyObject {
    func trashItem(at url: URL) throws -> URL
    func isVolumeReadOnly(at url: URL) -> Bool
    func canTrashItem(at url: URL) -> Bool
}

/// Real system trash provider using macOS FileManager.default.trashItem.
public final class SystemTrashProvider: TrashProvider {
    public static let shared = SystemTrashProvider()

    public init() {}

    public func trashItem(at url: URL) throws -> URL {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return (resultingURL as URL?) ?? url
    }

    public func isVolumeReadOnly(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]),
              let readOnly = values.volumeIsReadOnly else {
            return !FileManager.default.isWritableFile(atPath: url.path)
        }
        return readOnly
    }

    public func canTrashItem(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if isVolumeReadOnly(at: url) { return false }
        let parentDir = url.deletingLastPathComponent()
        return FileManager.default.isWritableFile(atPath: parentDir.path)
    }
}

/// In-memory mock trash provider for unit tests.
public final class MockTrashProvider: TrashProvider {
    public var trashedURLs: [URL] = []
    public var readOnlyURLs: Set<URL> = []
    public var untrashableURLs: Set<URL> = []
    public var simulateError: Error?

    public init() {}

    public func trashItem(at url: URL) throws -> URL {
        if let err = simulateError {
            throw err
        }
        if untrashableURLs.contains(url) || readOnlyURLs.contains(url) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: nil)
        }
        trashedURLs.append(url)
        let trashDir = URL(fileURLWithPath: "/tmp/.Trash")
        return trashDir.appendingPathComponent(url.lastPathComponent)
    }

    public func isVolumeReadOnly(at url: URL) -> Bool {
        return readOnlyURLs.contains(url)
    }

    public func canTrashItem(at url: URL) -> Bool {
        if readOnlyURLs.contains(url) || untrashableURLs.contains(url) {
            return false
        }
        return true
    }
}

/// Snapshot of the source file taken before conversion begins.
public struct SourceSnapshot: Equatable {
    public let url: URL
    public let fileSize: UInt64
    public let modificationDate: Date
    public let sha256Hex: String?

    public init(url: URL, fileSize: UInt64, modificationDate: Date, sha256Hex: String? = nil) {
        self.url = url
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.sha256Hex = sha256Hex
    }

    public static func capture(for url: URL, computeChecksum: Bool = true) -> SourceSnapshot? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              let mtime = attrs[.modificationDate] as? Date else {
            return nil
        }
        var checksum: String? = nil
        if computeChecksum, size <= 250 * 1024 * 1024 {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                checksum = DeleteOriginalGuard.sha256Hex(of: data)
            }
        }
        return SourceSnapshot(url: url, fileSize: size, modificationDate: mtime, sha256Hex: checksum)
    }

    public func verifyUnchanged(against currentURL: URL) -> Bool {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: currentURL.path),
              let currentSize = attrs[.size] as? UInt64,
              let currentMtime = attrs[.modificationDate] as? Date else {
            return false
        }
        if currentSize != self.fileSize {
            return false
        }
        if abs(currentMtime.timeIntervalSince(self.modificationDate)) > 1.0 {
            return false
        }
        if let originalHash = self.sha256Hex {
            if let data = try? Data(contentsOf: currentURL, options: .mappedIfSafe) {
                let currentHash = DeleteOriginalGuard.sha256Hex(of: data)
                if currentHash != originalHash {
                    return false
                }
            }
        }
        return true
    }
}

/// Job execution status for delete-original assessment.
public enum JobExecutionStatus: Equatable {
    case success
    case failed(exitCode: Int32, errorOutput: String)
    case cancelled
}

/// Reason why an original file was skipped and not moved to Trash.
public enum DeleteOriginalSkipReason: Error, Equatable, CustomStringConvertible {
    case preferenceDisabledOrUnconfirmed
    case jobFailed(String)
    case jobCancelled
    case outputMissing(URL)
    case outputZeroBytes(URL)
    case outputTypeMismatch(expected: String, actual: String)
    case sourceEqualsOutput
    case readOnlyVolume
    case cannotTrash(String)
    case sourceModifiedDuringConversion(reason: String)

    public var description: String {
        switch self {
        case .preferenceDisabledOrUnconfirmed:
            return "Delete-original preference is disabled or lacks stored double-confirmation"
        case .jobFailed(let msg):
            return "Job did not report success: \(msg)"
        case .jobCancelled:
            return "Job was cancelled by user or watchdog"
        case .outputMissing(let url):
            return "Output file was not found at '\(url.path)'"
        case .outputZeroBytes(let url):
            return "Output file exists but is 0 bytes at '\(url.path)'"
        case .outputTypeMismatch(let exp, let act):
            return "Output file type mismatch (expected '.\(exp)', got '.\(act)')"
        case .sourceEqualsOutput:
            return "Source file and output file resolve to the same canonical path"
        case .readOnlyVolume:
            return "Source volume or directory is read-only"
        case .cannotTrash(let reason):
            return "Source file cannot be moved to Trash: \(reason)"
        case .sourceModifiedDuringConversion(let reason):
            return "Source file changed during conversion: \(reason)"
        }
    }
}

/// Decision returned by DeleteOriginalGuard.assess.
public enum DeleteOriginalDecision: Equatable {
    case approved
    case rejected(DeleteOriginalSkipReason)
}

/// Final outcome of the delete-original check.
public enum DeleteOriginalResult: Equatable {
    case trashed(source: URL, trashURL: URL?)
    case skipped(source: URL, reason: DeleteOriginalSkipReason)
    case disabled
}

/// Pure domain guard enforcing safety rules before any original file is moved to Trash.
public final class DeleteOriginalGuard {
    public static var sharedTrashProvider: TrashProvider = SystemTrashProvider.shared

    public static let confirmationPhrase = "I understand deleted files are moved to the Trash"
    private static let confirmationSalt = "PASTA_DELETE_ORIGINAL_CONFIRMATION_V1"

    public static func captureSnapshot(for url: URL, computeChecksum: Bool = true) -> SourceSnapshot? {
        return SourceSnapshot.capture(for: url, computeChecksum: computeChecksum)
    }

    public struct StoredConfirmationRecord: Codable {
        public let timestamp: String
        public let phrase: String
        public let signature: String

        public init(timestamp: String, phrase: String, signature: String) {
            self.timestamp = timestamp
            self.phrase = phrase
            self.signature = signature
        }
    }

    public static func sha256Hex(of data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func generateConfirmationRecord(confirmedAt: Date = Date(), phrase: String = confirmationPhrase) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let ts = isoFormatter.string(from: confirmedAt)
        let payload = "\(ts):\(phrase):\(confirmationSalt)"
        let signature = sha256Hex(of: Data(payload.utf8))
        let record = StoredConfirmationRecord(timestamp: ts, phrase: phrase, signature: signature)
        guard let data = try? JSONEncoder().encode(record),
              let jsonString = String(data: data, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }

    public static func validateConfirmationRecord(_ record: String) -> Bool {
        guard let data = record.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StoredConfirmationRecord.self, from: data) else {
            return false
        }
        guard decoded.phrase == confirmationPhrase else { return false }
        let expectedPayload = "\(decoded.timestamp):\(decoded.phrase):\(confirmationSalt)"
        let expectedSig = sha256Hex(of: Data(expectedPayload.utf8))
        return decoded.signature == expectedSig
    }

    public static func assess(
        source: URL,
        output: URL,
        expectedExtension: String,
        snapshot: SourceSnapshot?,
        jobStatus: JobExecutionStatus,
        preferences: PreferencesManager = .shared,
        trashProvider: TrashProvider? = nil
    ) -> DeleteOriginalDecision {
        let provider = trashProvider ?? sharedTrashProvider

        // 1. Preference & Stored Confirmation check
        guard preferences.deleteOriginalEnabled else {
            return .rejected(.preferenceDisabledOrUnconfirmed)
        }

        // 2. Job Status check
        switch jobStatus {
        case .cancelled:
            return .rejected(.jobCancelled)
        case .failed(_, let err):
            return .rejected(.jobFailed(err))
        case .success:
            break
        }

        // 3. Source equals output check (canonical path comparison)
        let sourceCanonical = source.resolvingSymlinksInPath().standardized.path
        let outputCanonical = output.resolvingSymlinksInPath().standardized.path
        if sourceCanonical == outputCanonical {
            return .rejected(.sourceEqualsOutput)
        }

        // 4. Output existence check
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: output.path, isDirectory: &isDir) else {
            return .rejected(.outputMissing(output))
        }

        // 5. Output zero-byte check
        if isDir.boolValue {
            if let items = try? fm.contentsOfDirectory(atPath: output.path), items.isEmpty {
                return .rejected(.outputZeroBytes(output))
            }
        } else {
            guard let attrs = try? fm.attributesOfItem(atPath: output.path),
                  let size = attrs[.size] as? UInt64, size > 0 else {
                return .rejected(.outputZeroBytes(output))
            }
        }

        // 6. Output type match check
        let ext = output.pathExtension.lowercased()
        let expected = expectedExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        if !expected.isEmpty && !isDir.boolValue {
            if ext != expected {
                return .rejected(.outputTypeMismatch(expected: expected, actual: ext))
            }
        }

        // 7. Source snapshot / modification during conversion check
        if let snap = snapshot {
            if !snap.verifyUnchanged(against: source) {
                return .rejected(.sourceModifiedDuringConversion(reason: "File size or checksum changed during conversion"))
            }
        }

        // 8. Read-only volume / permissions check
        if provider.isVolumeReadOnly(at: source) {
            return .rejected(.readOnlyVolume)
        }

        // 9. Trashability check
        if !provider.canTrashItem(at: source) {
            return .rejected(.cannotTrash("Source file cannot be moved to Trash on this filesystem"))
        }

        return .approved
    }

    @discardableResult
    public static func execute(
        source: URL,
        output: URL,
        expectedExtension: String,
        snapshot: SourceSnapshot?,
        jobStatus: JobExecutionStatus,
        preferences: PreferencesManager = .shared,
        trashProvider: TrashProvider? = nil
    ) -> DeleteOriginalResult {
        let provider = trashProvider ?? sharedTrashProvider

        // If preference is disabled, return .disabled
        guard preferences.deleteOriginalEnabled else {
            return .disabled
        }

        let decision = assess(
            source: source,
            output: output,
            expectedExtension: expectedExtension,
            snapshot: snapshot,
            jobStatus: jobStatus,
            preferences: preferences,
            trashProvider: provider
        )

        switch decision {
        case .rejected(let reason):
            PastaLogger.shared.info("Delete-original skipped for '\(source.path)': \(reason.description)")
            return .skipped(source: source, reason: reason)
        case .approved:
            do {
                let trashedURL = try provider.trashItem(at: source)
                PastaLogger.shared.info("Moved original '\(source.path)' to Trash at '\(trashedURL.path)'")
                return .trashed(source: source, trashURL: trashedURL)
            } catch {
                PastaLogger.shared.error("Failed to trash original '\(source.path)': \(error.localizedDescription)")
                return .skipped(source: source, reason: .cannotTrash(error.localizedDescription))
            }
        }
    }
}
