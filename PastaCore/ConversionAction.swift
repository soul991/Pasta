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

    public var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .pdf: return "PDF"
        case .document: return "Document"
        case .subtitle: return "Subtitle"
        case .archive: return "Archive"
        case .metadata: return "Metadata"
        }
    }
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
    public let isBatch: Bool
    public typealias CustomRunner = (URL, URL, ParameterValues, JobRunner, UUID) throws -> Void
    public typealias CustomBatchRunner = ([URL], URL, ParameterValues, JobRunner, UUID) throws -> Void

    public let requiredTool: String?
    public let buildInvocationsWithParams: (URL, URL, ParameterValues) -> [Invocation]
    public let buildBatchInvocationsWithParams: (([URL], URL, ParameterValues) -> [Invocation])?
    public let customRunner: CustomRunner?
    public let customBatchRunner: CustomBatchRunner?

    public var buildInvocations: (URL, URL) -> [Invocation] {
        return { input, output in
            self.buildInvocationsWithParams(input, output, self.defaultParameterValues)
        }
    }

    public var buildBatchInvocations: (([URL], URL) -> [Invocation])? {
        guard let builder = buildBatchInvocationsWithParams else { return nil }
        return { inputs, output in
            builder(inputs, output, self.defaultParameterValues)
        }
    }

    public var defaultParameterValues: ParameterValues {
        var dict: ParameterValues = [:]
        for p in parameters {
            dict[p.id] = p.defaultValue
        }
        return dict
    }

    public var requirementNote: String? {
        guard let req = requiredTool else { return nil }
        if !ToolLocator.shared.isOptionalToolAvailable(req) {
            switch req {
            case "soffice": return "needs LibreOffice"
            case "ebook-convert": return "needs Calibre"
            case "avifenc": return "needs avifenc"
            default: return "needs \(req)"
            }
        }
        return nil
    }

    public var shortHumanName: String {
        var name = displayName
        if name.hasPrefix("Convert to ") {
            name = String(name.dropFirst("Convert to ".count))
        } else if name.hasPrefix("Remux to ") {
            name = String(name.dropFirst("Remux to ".count))
        } else if name.hasPrefix("Compress to ") {
            name = String(name.dropFirst("Compress to ".count))
        }
        if name == "Extract MP3 Audio" {
            name = "Extract MP3"
        }
        if name == "Plain Text" {
            name = "TXT"
        }
        let base = name.isEmpty ? outputExtension.uppercased() : name
        if let note = requirementNote {
            return "\(base) (\(note))"
        }
        return base
    }

    /// Resolves the primary conversion engine tool name for this action.
    public var primaryEngine: String {
        if let req = requiredTool, !req.isEmpty {
            return req
        }
        if id == "pdf.compress" || id == "pdf.advanced.compress" || id == "pdf.to.pdfa" {
            return "ghostscript"
        }
        let dummyIn = URL(fileURLWithPath: "/tmp/in.tmp")
        let dummyOut = URL(fileURLWithPath: "/tmp/out.tmp")
        let invocations = buildInvocationsWithParams(dummyIn, dummyOut, defaultParameterValues)
        if let first = invocations.first {
            return first.toolName
        }
        if id.hasPrefix("video.") || id.hasPrefix("audio.") {
            return "ffmpeg"
        }
        return ""
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
        isBatch: Bool = false,
        requiredTool: String? = nil,
        buildInvocations: @escaping (URL, URL, ParameterValues) -> [Invocation] = { _, _, _ in [] },
        buildBatchInvocations: (([URL], URL, ParameterValues) -> [Invocation])? = nil,
        customRunner: CustomRunner? = nil,
        customBatchRunner: CustomBatchRunner? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.outputExtension = outputExtension
        self.isAdvanced = isAdvanced
        self.category = category
        self.iconName = iconName
        self.outputKind = outputKind
        self.parameters = parameters
        self.isBatch = isBatch
        self.requiredTool = requiredTool
        self.buildInvocationsWithParams = buildInvocations
        self.buildBatchInvocationsWithParams = buildBatchInvocations ?? { inputs, out, params in
            guard let first = inputs.first else { return [] }
            return buildInvocations(first, out, params)
        }
        self.customRunner = customRunner
        self.customBatchRunner = customBatchRunner
    }

    public init(
        batchId id: String,
        displayName: String,
        outputExtension: String,
        isAdvanced: Bool = false,
        category: ActionCategory,
        iconName: String = "gearshape",
        outputKind: OutputKind = .file,
        parameters: [ActionParameter] = [],
        requiredTool: String? = nil,
        buildBatchInvocations: @escaping ([URL], URL, ParameterValues) -> [Invocation]
    ) {
        self.init(
            id: id,
            displayName: displayName,
            outputExtension: outputExtension,
            isAdvanced: isAdvanced,
            category: category,
            iconName: iconName,
            outputKind: outputKind,
            parameters: parameters,
            isBatch: true,
            requiredTool: requiredTool,
            buildInvocations: { input, out, params in buildBatchInvocations([input], out, params) },
            buildBatchInvocations: buildBatchInvocations
        )
    }

    public init(
        id: String,
        displayName: String,
        outputExtension: String,
        isAdvanced: Bool = false,
        category: ActionCategory,
        iconName: String = "gearshape",
        outputKind: OutputKind = .file,
        requiredTool: String? = nil,
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
            isBatch: false,
            requiredTool: requiredTool,
            buildInvocations: { input, output, _ in buildInvocations(input, output) }
        )
    }

    public static func == (lhs: ConversionAction, rhs: ConversionAction) -> Bool {
        lhs.id == rhs.id
    }
}
