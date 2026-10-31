import Foundation

public struct Invocation: Equatable {
    public let toolName: String
    public let arguments: [String]
    public let environment: [String: String]?
    public let redirectStdoutTo: String?
    public let timeoutSeconds: TimeInterval?
    public let inactivityTimeoutSeconds: TimeInterval?

    public static func defaultTimeout(for toolName: String) -> TimeInterval? {
        if toolName == "ffmpeg" {
            return nil
        }
        return 300.0
    }

    public static func defaultInactivityTimeout(for toolName: String) -> TimeInterval? {
        if toolName == "ffmpeg" {
            let minutes = PreferencesManager.shared.watchdogTimeoutMinutes
            return minutes * 60.0
        }
        return nil
    }

    public init(
        toolName: String,
        arguments: [String],
        environment: [String: String]? = nil,
        redirectStdoutTo: String? = nil,
        timeout: TimeInterval? = nil,
        inactivityTimeout: TimeInterval? = nil
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.environment = environment
        self.redirectStdoutTo = redirectStdoutTo
        self.timeoutSeconds = timeout ?? Self.defaultTimeout(for: toolName)
        self.inactivityTimeoutSeconds = inactivityTimeout ?? Self.defaultInactivityTimeout(for: toolName)
    }
}
