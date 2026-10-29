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

public enum OutputKind: Equatable, Sendable {
    case file
    case folder(suffix: String)
}

public struct ConversionAction: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let outputExtension: String
    public let isAdvanced: Bool
    public let category: ActionCategory
    public let iconName: String
    public let outputKind: OutputKind
    public let parameters: [ActionParameter]
    public let buildInvocationsWithParams: (URL, URL, ParameterValues) -> [Invocation]

    public var buildInvocations: (URL, URL) -> [Invocation] {
        return { input, output in
            self.buildInvocationsWithParams(input, output, self.defaultParameterValues)
        }
    }

    public var defaultParameterValues: ParameterValues {
        var dict: ParameterValues = [:]
        for p in parameters {
            dict[p.id] = p.defaultValue
        }
        return dict
    }

    public init(
        id: String,
        displayName: String,
        outputExtension: String,
        isAdvanced: Bool = false,
        category: ActionCategory,
        iconName: String = "gearshape",
        outputKind: OutputKind = .file,
        parameters: [ActionParameter] = [],
        buildInvocations: @escaping (URL, URL, ParameterValues) -> [Invocation]
    ) {
        self.id = id
        self.displayName = displayName
        self.outputExtension = outputExtension
        self.isAdvanced = isAdvanced
        self.category = category
        self.iconName = iconName
        self.outputKind = outputKind
        self.parameters = parameters
        self.buildInvocationsWithParams = buildInvocations
    }

    public init(
        id: String,
        displayName: String,
        outputExtension: String,
        isAdvanced: Bool = false,
        category: ActionCategory,
        iconName: String = "gearshape",
        outputKind: OutputKind = .file,
        buildInvocations: @escaping (URL, URL) -> [Invocation]
    ) {
        self.init(
            id: id,
            displayName: displayName,
            outputExtension: outputExtension,
            isAdvanced: isAdvanced,
            category: category,
            iconName: iconName,
            outputKind: outputKind,
            parameters: [],
            buildInvocations: { input, output, _ in buildInvocations(input, output) }
        )
    }

    public static func == (lhs: ConversionAction, rhs: ConversionAction) -> Bool {
        lhs.id == rhs.id
    }
}
