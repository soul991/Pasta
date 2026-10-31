import Foundation

public struct ParameterPreset: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let values: ParameterValues

    public init(id: String, label: String, values: ParameterValues) {
        self.id = id
        self.label = label
        self.values = values
    }
}

public final class ParameterFormField: Equatable {
    public let parameter: ActionParameter

    public var id: String { parameter.id }
    public var label: String { parameter.label }
    public var kind: ActionParameterKind { parameter.kind }
    public var defaultValue: ParameterValue { parameter.defaultValue }
    public var minValue: Double? { parameter.minValue }
    public var maxValue: Double? { parameter.maxValue }

    public var options: [String] {
        if case .choice(let opts) = parameter.kind {
            return opts
        }
        return []
    }

    public var currentValue: ParameterValue
    public var errorMessage: String?

    public var currentStringValue: String {
        get { currentValue.asString }
        set { update(stringValue: newValue) }
    }

    public var isValid: Bool {
        return errorMessage == nil
    }

    public init(parameter: ActionParameter, initialValue: ParameterValue? = nil) {
        self.parameter = parameter
        self.currentValue = initialValue ?? parameter.defaultValue
        self.errorMessage = nil
    }

    public func update(value: ParameterValue) {
        self.currentValue = value
    }

    public func update(stringValue: String) {
        self.currentValue = ActionParameter.parseCLIValue(stringValue, for: kind)
    }

    public func resetToDefault() {
        self.currentValue = parameter.defaultValue
        self.errorMessage = nil
    }

    public static func == (lhs: ParameterFormField, rhs: ParameterFormField) -> Bool {
        return lhs.parameter == rhs.parameter &&
               lhs.currentValue == rhs.currentValue &&
               lhs.errorMessage == rhs.errorMessage
    }
}

public final class ParameterFormModel {
    public let actionID: String
    public let actionDisplayName: String
    public let parameters: [ActionParameter]
    public let preferences: PreferencesManager

    public private(set) var fields: [ParameterFormField] = []
    public private(set) var presets: [ParameterPreset] = []
    public private(set) var isValid: Bool = true
    public private(set) var validationErrors: [String: String] = [:]

    public var values: ParameterValues {
        var result: ParameterValues = [:]
        for f in fields {
            result[f.id] = f.currentValue
        }
        return result
    }

    public var validationErrorMessage: String? {
        if isValid { return nil }
        return validationErrors.values.first
    }

    public init(
        action: ConversionAction,
        preferences: PreferencesManager = .shared,
        loadLastUsed: Bool = true
    ) {
        self.actionID = action.id
        self.actionDisplayName = action.displayName
        self.parameters = action.parameters
        self.preferences = preferences
        setup(loadLastUsed: loadLastUsed)
    }

    public init(
        actionID: String,
        actionDisplayName: String,
        parameters: [ActionParameter],
        preferences: PreferencesManager = .shared,
        loadLastUsed: Bool = true
    ) {
        self.actionID = actionID
        self.actionDisplayName = actionDisplayName
        self.parameters = parameters
        self.preferences = preferences
        setup(loadLastUsed: loadLastUsed)
    }

    private func setup(loadLastUsed: Bool) {
        let lastUsed = loadLastUsed ? preferences.lastUsedParameterValues(for: actionID, parameters: parameters) : nil

        self.fields = parameters.map { param in
            let initial = lastUsed?[param.id] ?? param.defaultValue
            return ParameterFormField(parameter: param, initialValue: initial)
        }

        self.presets = Self.defaultPresets(for: actionID, parameters: parameters)
        validate()
    }

    public func field(for parameterId: String) -> ParameterFormField? {
        return fields.first { $0.id == parameterId }
    }

    public func updateValue(_ value: ParameterValue, for parameterId: String) {
        guard let field = field(for: parameterId) else { return }
        field.update(value: value)
        validate()
    }

    public func updateStringValue(_ stringValue: String, for parameterId: String) {
        guard let field = field(for: parameterId) else { return }
        field.update(stringValue: stringValue)
        validate()
    }

    public func applyPreset(_ preset: ParameterPreset) {
        for (key, val) in preset.values {
            if let f = field(for: key) {
                f.update(value: val)
            }
        }
        validate()
    }

    public func applyValues(_ newValues: ParameterValues) {
        for (key, val) in newValues {
            if let f = field(for: key) {
                f.update(value: val)
            }
        }
        validate()
    }

    public func resetToDefaults() {
        for f in fields {
            f.resetToDefault()
        }
        validate()
    }

    public func saveAsLastUsed() {
        preferences.setLastUsedParameterValues(values, for: actionID)
    }

    public func clearLastUsed() {
        preferences.clearLastUsedParameters(for: actionID)
    }

    @discardableResult
    public func validate() -> Bool {
        validationErrors.removeAll()

        for f in fields {
            do {
                try InputValidator.validateParameters(
                    declared: [f.parameter],
                    values: [f.id: f.currentValue]
                )
                f.errorMessage = nil
            } catch PastaError.invalidInput(let reason) {
                f.errorMessage = reason
                validationErrors[f.id] = reason
            } catch {
                f.errorMessage = error.localizedDescription
                validationErrors[f.id] = error.localizedDescription
            }
        }

        do {
            try InputValidator.validateParameters(declared: parameters, values: values)
        } catch PastaError.invalidInput(let reason) {
            if validationErrors.isEmpty {
                var attributed = false
                for f in fields {
                    if reason.contains("'\(f.id)'") {
                        f.errorMessage = reason
                        validationErrors[f.id] = reason
                        attributed = true
                    }
                }
                if !attributed, let first = fields.first {
                    first.errorMessage = reason
                    validationErrors[first.id] = reason
                }
            }
        } catch {
            if validationErrors.isEmpty, let first = fields.first {
                first.errorMessage = error.localizedDescription
                validationErrors[first.id] = error.localizedDescription
            }
        }

        isValid = validationErrors.isEmpty
        return isValid
    }

    public static func defaultPresets(
        for actionID: String,
        parameters: [ActionParameter]
    ) -> [ParameterPreset] {
        var presets: [ParameterPreset] = []
        let ids = Set(parameters.map { $0.id })

        if ids.contains("percent") && !ids.contains("start") {
            presets.append(ParameterPreset(
                id: "pct_25",
                label: "25%",
                values: ["percent": .number(25.0)]
            ))
            presets.append(ParameterPreset(
                id: "pct_50",
                label: "50%",
                values: ["percent": .number(50.0)]
            ))
            presets.append(ParameterPreset(
                id: "pct_75",
                label: "75%",
                values: ["percent": .number(75.0)]
            ))
        }

        if ids.contains("target_size") {
            presets.append(ParameterPreset(
                id: "size_5mb",
                label: "5 MB",
                values: ["target_size": .integer(5 * 1024 * 1024)]
            ))
            presets.append(ParameterPreset(
                id: "size_25mb",
                label: "25 MB",
                values: ["target_size": .integer(25 * 1024 * 1024)]
            ))
            presets.append(ParameterPreset(
                id: "size_100mb",
                label: "100 MB",
                values: ["target_size": .integer(100 * 1024 * 1024)]
            ))
        }

        if ids.contains("factor") {
            presets.append(ParameterPreset(
                id: "spd_05",
                label: "0.5x (Slow)",
                values: ["factor": .number(0.5)]
            ))
            presets.append(ParameterPreset(
                id: "spd_15",
                label: "1.5x",
                values: ["factor": .number(1.5)]
            ))
            presets.append(ParameterPreset(
                id: "spd_20",
                label: "2.0x (Fast)",
                values: ["factor": .number(2.0)]
            ))
        }

        if ids.contains("layout") {
            presets.append(ParameterPreset(
                id: "ch_mono",
                label: "Mono",
                values: ["layout": .text("mono")]
            ))
            presets.append(ParameterPreset(
                id: "ch_stereo",
                label: "Stereo",
                values: ["layout": .text("stereo")]
            ))
        }

        if ids.contains("box") {
            presets.append(ParameterPreset(
                id: "crop_16_9",
                label: "16:9",
                values: ["box": .text("16:9")]
            ))
            presets.append(ParameterPreset(
                id: "crop_1_1",
                label: "1:1",
                values: ["box": .text("1:1")]
            ))
            presets.append(ParameterPreset(
                id: "crop_9_16",
                label: "9:16",
                values: ["box": .text("9:16")]
            ))
        }

        if ids.contains("start") && ids.contains("end") {
            presets.append(ParameterPreset(
                id: "trim_10s",
                label: "First 10s",
                values: ["start": .number(0.0), "end": .number(10.0)]
            ))
            presets.append(ParameterPreset(
                id: "trim_30s",
                label: "First 30s",
                values: ["start": .number(0.0), "end": .number(30.0)]
            ))
            presets.append(ParameterPreset(
                id: "trim_60s",
                label: "First 60s",
                values: ["start": .number(0.0), "end": .number(60.0)]
            ))
        }

        if ids.contains("columns") {
            presets.append(ParameterPreset(
                id: "col_2",
                label: "2 Columns",
                values: ["columns": .number(2.0)]
            ))
            presets.append(ParameterPreset(
                id: "col_3",
                label: "3 Columns",
                values: ["columns": .number(3.0)]
            ))
            presets.append(ParameterPreset(
                id: "col_4",
                label: "4 Columns",
                values: ["columns": .number(4.0)]
            ))
        }

        return presets
    }
}
