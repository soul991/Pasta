import Foundation

public enum PastaError: LocalizedError, Equatable {
    case missingTool(String)
    case unsupportedFormat(String)
    case executionFailed(tool: String, exitCode: Int32, output: String)
    case outputNotFound(String)
    case invalidInput(String)
    case cancelled
    case timedOut(tool: String)
    case insufficientDiskSpace(availableBytes: Int64, requiredBytes: Int64)
    case heavyJobConfirmationRequired(reason: String)
    case heavyJobBusy

    public var errorDescription: String? {
        switch self {
        case .missingTool(let tool):
            return "Required tool '\(tool)' is not installed. Please install it via Homebrew: brew install \(tool)"
        case .unsupportedFormat(let ext):
            return "Unsupported file extension or format: '\(ext)'"
        case .executionFailed(let tool, let code, let out):
            return "Tool '\(tool)' failed with exit code \(code): \(out.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .outputNotFound(let path):
            return "Expected output was not created at '\(path)'"
        case .invalidInput(let reason):
            return "Invalid input file: \(reason)"
        case .cancelled:
            return "Conversion was cancelled"
        case .timedOut(let tool):
            return "Execution of '\(tool)' timed out"
        case .insufficientDiskSpace(let avail, let req):
            let availMB = avail / (1024 * 1024)
            let reqMB = req / (1024 * 1024)
            return "Insufficient disk space: \(availMB) MB available, but estimated requirement is \(reqMB) MB"
        case .heavyJobConfirmationRequired(let reason):
            return "Heavy job confirmation required: \(reason)"
        case .heavyJobBusy:
            return "Another heavy conversion job is already in progress. Only one heavy job may run at a time."
        }
    }
}
