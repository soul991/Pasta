import Foundation

public struct Invocation: Equatable {
    public let toolName: String
    public let arguments: [String]
    public let environment: [String: String]?

    public init(toolName: String, arguments: [String], environment: [String: String]? = nil) {
        self.toolName = toolName
        self.arguments = arguments
        self.environment = environment
    }
}
