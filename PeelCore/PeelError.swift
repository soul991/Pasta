import Foundation

public enum PeelError: LocalizedError, Equatable {
    case missingTool(String)
    case unsupportedFormat(String)
    case executionFailed(tool: String, exitCode: Int32, output: String)
    case outputNotFound(String)
    case invalidInput(String)
    case cancelled

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
        }
    }
}
