import Foundation

public struct Invocation: Equatable {
    public let toolName: String
    public let arguments: [String]
    public let environment: [String: String]?
    public let redirectStdoutTo: String?
    public let timeoutSeconds: TimeInterval?

    public static func defaultTimeout(for toolName: String) -> TimeInterval? {
        if toolName == "ffmpeg" {
            return nil
        }
        return 300.0
    }

    public init(
        toolName: String,
        arguments: [String],
        environment: [String: String]? = nil,
        redirectStdoutTo: String? = nil
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.environment = environment
        self.redirectStdoutTo = redirectStdoutTo
        self.timeoutSeconds = Self.defaultTimeout(for: toolName)
    }

    public init(
        toolName: String,
        arguments: [String],
        environment: [String: String]? = nil,
        redirectStdoutTo: String? = nil,
        timeout: TimeInterval?
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.environment = environment
        self.redirectStdoutTo = redirectStdoutTo
        self.timeoutSeconds = timeout
    }
}
