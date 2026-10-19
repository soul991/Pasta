import Foundation

public enum ActionCategory: String, Codable, CaseIterable {
    case image
    case video
    case audio
    case pdf
    case document
    case subtitle
    case archive
    case metadata
}

public struct ConversionAction: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let outputExtension: String
    public let isAdvanced: Bool
    public let category: ActionCategory
    public let iconName: String
    public let buildInvocations: (URL, URL) -> [Invocation]

    public init(
        id: String,
        displayName: String,
        outputExtension: String,
        isAdvanced: Bool = false,
        category: ActionCategory,
        iconName: String = "gearshape",
        buildInvocations: @escaping (URL, URL) -> [Invocation]
    ) {
        self.id = id
        self.displayName = displayName
        self.outputExtension = outputExtension
        self.isAdvanced = isAdvanced
        self.category = category
        self.iconName = iconName
        self.buildInvocations = buildInvocations
    }

    public static func == (lhs: ConversionAction, rhs: ConversionAction) -> Bool {
        lhs.id == rhs.id
    }
}
