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

public enum CropIntent: Equatable, Sendable {
    case ratio(width: Int, height: Int)
    case manual(x: Int, y: Int, width: Int, height: Int)
}

public enum TrimEndIntent: Equatable, Sendable {
    case endOfFile
    case clamped(Double)
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
    public var warningMessage: String?

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
    public let inputFiles: [URL]
    public var inputFile: URL? { inputFiles.first }
    public var isBatch: Bool { inputFiles.count > 1 }
    public var batchCount: Int { inputFiles.count }
    public var cropIntent: CropIntent?
    public var trimEndIntent: TrimEndIntent?
    public let probe: MediaProbe
    public private(set) var probeResult: MediaProbeResult?
    public private(set) var probeError: String?

    public private(set) var fields: [ParameterFormField] = []
    public private(set) var presets: [ParameterPreset] = []
    public private(set) var isValid: Bool = true
    public private(set) var validationErrors: [String: String] = [:]
    public private(set) var warnings: [String: String] = [:]

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
        loadLastUsed: Bool = true,
        inputFile: URL? = nil,
        inputFiles: [URL] = [],
        probe: MediaProbe = MediaProbeService.shared.probe
    ) {
        self.actionID = action.id
        self.actionDisplayName = action.displayName
        self.parameters = action.parameters
        self.preferences = preferences
        if !inputFiles.isEmpty {
            self.inputFiles = inputFiles
        } else if let file = inputFile {
            self.inputFiles = [file]
        } else {
            self.inputFiles = []
        }
        self.probe = probe
        setup(loadLastUsed: loadLastUsed)
    }

    public init(
        actionID: String,
        actionDisplayName: String,
        parameters: [ActionParameter],
        preferences: PreferencesManager = .shared,
        loadLastUsed: Bool = true,
        inputFile: URL? = nil,
        inputFiles: [URL] = [],
        probe: MediaProbe = MediaProbeService.shared.probe
    ) {
        self.actionID = actionID
        self.actionDisplayName = actionDisplayName
        self.parameters = parameters
        self.preferences = preferences
        if !inputFiles.isEmpty {
            self.inputFiles = inputFiles
        } else if let file = inputFile {
            self.inputFiles = [file]
        } else {
            self.inputFiles = []
        }
        self.probe = probe
        setup(loadLastUsed: loadLastUsed)
    }

    private func setup(loadLastUsed: Bool) {
        if let file = inputFile {
            do {
                self.probeResult = try probe.probe(url: file)
                self.probeError = nil
            } catch {
                self.probeResult = nil
                self.probeError = error.localizedDescription
            }
        } else {
            self.probeResult = nil
            self.probeError = nil
        }

        let ids = Set(parameters.map { $0.id })
        if ids.contains("rectangle") {
            if let p = probeResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 {
                self.cropIntent = .ratio(width: cw, height: ch)
            } else {
                self.cropIntent = .ratio(width: 16, height: 9)
            }
        }
        if ids.contains("end") || parameters.contains(where: { $0.kind == .timeRange }) {
            self.trimEndIntent = .endOfFile
        }

        let lastUsed = loadLastUsed ? preferences.lastUsedParameterValues(for: actionID, parameters: parameters) : nil

        self.fields = parameters.map { param in
            var initial = lastUsed?[param.id] ?? param.defaultValue
            if lastUsed == nil, param.id == "rectangle", let p = self.probeResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 {
                let full = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: cw, ratioHeight: ch)
                initial = .rectangle(x: full.x, y: full.y, width: full.width, height: full.height)
            }
            if lastUsed == nil, param.id == "end", let p = self.probeResult, let dur = p.duration, dur > 0 {
                initial = .number(dur)
            }
            if lastUsed == nil, param.kind == .timeRange, let p = self.probeResult, let dur = p.duration, dur > 0 {
                initial = .timeRange(start: 0.0, end: dur)
            }
            return ParameterFormField(parameter: param, initialValue: initial)
        }

        self.presets = Self.defaultPresets(for: actionID, parameters: parameters, probeResult: probeResult)
        validate()
    }

    public func field(for parameterId: String) -> ParameterFormField? {
        return fields.first { $0.id == parameterId }
    }

    public func updateValue(_ value: ParameterValue, for parameterId: String) {
        guard let field = field(for: parameterId) else { return }
        field.update(value: value)
        if parameterId == "rectangle", case .rectangle(let x, let y, let w, let h) = value {
            cropIntent = .manual(x: x, y: y, width: w, height: h)
        } else if parameterId == "end", let num = value.asDouble {
            trimEndIntent = .clamped(num)
        }
        validate()
    }

    public func updateStringValue(_ stringValue: String, for parameterId: String) {
        guard let field = field(for: parameterId) else { return }
        field.update(stringValue: stringValue)
        if parameterId == "rectangle", case .rectangle(let x, let y, let w, let h) = field.currentValue {
            cropIntent = .manual(x: x, y: y, width: w, height: h)
        } else if parameterId == "end", let num = field.currentValue.asDouble {
            trimEndIntent = .clamped(num)
        }
        validate()
    }

    public func applyPreset(_ preset: ParameterPreset) {
        if preset.id == "crop_16_9" {
            cropIntent = .ratio(width: 16, height: 9)
        } else if preset.id == "crop_1_1" {
            cropIntent = .ratio(width: 1, height: 1)
        } else if preset.id == "crop_9_16" {
            cropIntent = .ratio(width: 9, height: 16)
        } else if preset.id.starts(with: "trim_") {
            if let endVal = preset.values["end"]?.asDouble {
                trimEndIntent = .clamped(endVal)
            }
        }

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

    public func resolveParameters(for fileURL: URL, probe: MediaProbe? = nil) throws -> ParameterValues {
        let activeProbe = probe ?? self.probe
        let pResult = try? activeProbe.probe(url: fileURL)
        var resolved = self.values
        let ids = Set(parameters.map { $0.id })

        // 1. Resolve Crop Intent
        if ids.contains("rectangle") {
            let intent: CropIntent
            if let existingIntent = self.cropIntent {
                intent = existingIntent
            } else if let val = resolved["rectangle"], case .rectangle(let rx, let ry, let rw, let rh) = val {
                intent = .manual(x: rx, y: ry, width: rw, height: rh)
            } else {
                intent = .ratio(width: 16, height: 9)
            }

            switch intent {
            case .ratio(let rw, let rh):
                guard let p = pResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 else {
                    throw PastaError.invalidInput("Cannot compute ratio crop: unable to probe dimensions for \(fileURL.lastPathComponent)")
                }
                let crop = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: rw, ratioHeight: rh)
                resolved["rectangle"] = .rectangle(x: crop.x, y: crop.y, width: crop.width, height: crop.height)

            case .manual(let rx, let ry, let rw, let rh):
                if let p = pResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 {
                    try InputValidator.validateCropWithinBounds(width: rw, height: rh, x: rx, y: ry, containerWidth: cw, containerHeight: ch)
                }
                resolved["rectangle"] = .rectangle(x: rx, y: ry, width: rw, height: rh)
            }
        }

        // 2. Resolve Trim End Intent
        if ids.contains("end") {
            let intent = self.trimEndIntent ?? .endOfFile
            let fileDur = pResult?.duration ?? 0.0

            switch intent {
            case .endOfFile:
                if fileDur > 0 {
                    resolved["end"] = .number(fileDur)
                }
            case .clamped(let targetEnd):
                if fileDur > 0 {
                    resolved["end"] = .number(min(targetEnd, fileDur))
                } else {
                    resolved["end"] = .number(targetEnd)
                }
            }
        }

        // 3. Resolve timeRange parameter
        for param in parameters {
            if param.kind == .timeRange, let val = resolved[param.id], case .timeRange(let s, _) = val {
                let intent = self.trimEndIntent ?? .endOfFile
                let fileDur = pResult?.duration ?? 0.0

                switch intent {
                case .endOfFile:
                    if fileDur > 0 {
                        resolved[param.id] = .timeRange(start: s, end: fileDur)
                    }
                case .clamped(let targetEnd):
                    let endVal = fileDur > 0 ? min(targetEnd, fileDur) : targetEnd
                    resolved[param.id] = .timeRange(start: s, end: endVal)
                }
            }
        }

        // Validate resolved parameters against declared definitions
        try InputValidator.validateParameters(declared: parameters, values: resolved)

        return resolved
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

        let ids = Set(parameters.map { $0.id })
        if ids.contains("rectangle") {
            if let err = probeError {
                let msg = "Could not probe media for crop: \(err)"
                validationErrors["rectangle"] = msg
                field(for: "rectangle")?.errorMessage = msg
            } else if let p = probeResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 {
                if let rectVal = values["rectangle"], case .rectangle(let rx, let ry, let rw, let rh) = rectVal {
                    do {
                        try InputValidator.validateCropWithinBounds(width: rw, height: rh, x: rx, y: ry, containerWidth: cw, containerHeight: ch)
                    } catch {
                        validationErrors["rectangle"] = error.localizedDescription
                        field(for: "rectangle")?.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        // Validate start/end trim against probed duration
        if ids.contains("start") && ids.contains("end") {
            let startVal = values["start"]?.asDouble ?? 0.0
            let endVal = values["end"]?.asDouble ?? 0.0
            if startVal < 0 {
                let msg = "Start time cannot be negative: \(startVal)s"
                validationErrors["start"] = msg
                field(for: "start")?.errorMessage = msg
            }
            if endVal <= startVal {
                let msg = "End time (\(endVal)s) must be greater than start time (\(startVal)s)"
                validationErrors["end"] = msg
                field(for: "end")?.errorMessage = msg
            }
            if let max = probeResult?.duration, max > 0 {
                if startVal > max {
                    let msg = "Start time (\(startVal)s) exceeds media duration (\(max)s)"
                    validationErrors["start"] = msg
                    field(for: "start")?.errorMessage = msg
                }
                if endVal > max {
                    let msg = "End time (\(endVal)s) exceeds media duration (\(max)s)"
                    validationErrors["end"] = msg
                    field(for: "end")?.errorMessage = msg
                }
            }
        }

        for param in parameters {
            if param.kind == .timeRange, let val = values[param.id], case .timeRange(let s, let e) = val {
                if s < 0 {
                    let msg = "Start time cannot be negative: \(s)s"
                    validationErrors[param.id] = msg
                    field(for: param.id)?.errorMessage = msg
                }
                if e <= s {
                    let msg = "End time (\(e)s) must be greater than start time (\(s)s)"
                    validationErrors[param.id] = msg
                    field(for: param.id)?.errorMessage = msg
                }
                if let max = probeResult?.duration, max > 0 {
                    if s > max {
                        let msg = "Start time (\(s)s) exceeds media duration (\(max)s)"
                        validationErrors[param.id] = msg
                        field(for: param.id)?.errorMessage = msg
                    }
                    if e > max {
                        let msg = "End time (\(e)s) exceeds media duration (\(max)s)"
                        validationErrors[param.id] = msg
                        field(for: param.id)?.errorMessage = msg
                    }
                }
            }
        }

        // Check target size against probed file size (warning only, Run stays enabled)
        warnings.removeAll()
        for f in fields {
            f.warningMessage = nil
        }
        let targetSizeKey = ids.contains("targetSize") ? "targetSize" : (ids.contains("target_size") ? "target_size" : nil)
        if let key = targetSizeKey, let val = values[key]?.asInt64, val > 0 {
            if let p = probeResult, let srcSize = p.fileSize, srcSize > 0 {
                if val > srcSize {
                    let msg = "already smaller than this target"
                    warnings[key] = msg
                    field(for: key)?.warningMessage = msg
                }
            }
        }

        isValid = validationErrors.isEmpty
        return isValid
    }

    public static func defaultPresets(
        for actionID: String,
        parameters: [ActionParameter],
        probeResult: MediaProbeResult? = nil
    ) -> [ParameterPreset] {
        var presets: [ParameterPreset] = []
        let ids = Set(parameters.map { $0.id })

        if ids.contains("percent") && !ids.contains("start") {
            let modeDict: [String: ParameterValue] = ids.contains("mode") ? ["mode": .text("percent")] : [:]
            presets.append(ParameterPreset(
                id: "pct_25",
                label: "25%",
                values: modeDict.merging(["percent": .number(25.0)]) { _, new in new }
            ))
            presets.append(ParameterPreset(
                id: "pct_50",
                label: "50%",
                values: modeDict.merging(["percent": .number(50.0)]) { _, new in new }
            ))
            presets.append(ParameterPreset(
                id: "pct_75",
                label: "75%",
                values: modeDict.merging(["percent": .number(75.0)]) { _, new in new }
            ))
        }

        let targetSizeKey = ids.contains("targetSize") ? "targetSize" : (ids.contains("target_size") ? "target_size" : nil)
        if let key = targetSizeKey {
            let modeDict: [String: ParameterValue] = ids.contains("mode") ? ["mode": .text("targetSize")] : [:]
            presets.append(ParameterPreset(
                id: "size_5mb",
                label: "5 MB",
                values: modeDict.merging([key: .integer(5 * 1024 * 1024)]) { _, new in new }
            ))
            presets.append(ParameterPreset(
                id: "size_25mb",
                label: "25 MB",
                values: modeDict.merging([key: .integer(25 * 1024 * 1024)]) { _, new in new }
            ))
            presets.append(ParameterPreset(
                id: "size_100mb",
                label: "100 MB",
                values: modeDict.merging([key: .integer(100 * 1024 * 1024)]) { _, new in new }
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

        let channelsKey = ids.contains("channels") ? "channels" : (ids.contains("layout") ? "layout" : nil)
        if let chKey = channelsKey {
            presets.append(ParameterPreset(
                id: "ch_mono",
                label: "Mono",
                values: [chKey: .text("mono")]
            ))
            presets.append(ParameterPreset(
                id: "ch_stereo",
                label: "Stereo",
                values: [chKey: .text("stereo")]
            ))
        }

        if ids.contains("rectangle") {
            if let p = probeResult, let cw = p.width, let ch = p.height, cw > 0, ch > 0 {
                let crop169 = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: 16, ratioHeight: 9)
                let crop11 = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: 1, ratioHeight: 1)
                let crop916 = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: 9, ratioHeight: 16)

                presets.append(ParameterPreset(
                    id: "crop_16_9",
                    label: "16:9",
                    values: ["rectangle": .rectangle(x: crop169.x, y: crop169.y, width: crop169.width, height: crop169.height)]
                ))
                presets.append(ParameterPreset(
                    id: "crop_1_1",
                    label: "1:1",
                    values: ["rectangle": .rectangle(x: crop11.x, y: crop11.y, width: crop11.width, height: crop11.height)]
                ))
                presets.append(ParameterPreset(
                    id: "crop_9_16",
                    label: "9:16",
                    values: ["rectangle": .rectangle(x: crop916.x, y: crop916.y, width: crop916.width, height: crop916.height)]
                ))
            }
        } else if ids.contains("box") {
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
