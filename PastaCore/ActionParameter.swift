import Foundation

public enum ActionParameterKind: Equatable, Sendable {
    case percent
    case number
    case sizeInBytes
    case timeRange
    case rectangle
    case choice(options: [String])
    case text
}

public enum ParameterValue: Equatable, Sendable {
    case number(Double)
    case integer(Int64)
    case text(String)
    case timeRange(start: Double, end: Double)
    case rectangle(x: Int, y: Int, width: Int, height: Int)

    public var asDouble: Double? {
        switch self {
        case .number(let v): return v
        case .integer(let v): return Double(v)
        case .text(let s): return Double(s)
        default: return nil
        }
    }

    public var asInt: Int? {
        switch self {
        case .integer(let v): return Int(v)
        case .number(let v): return Int(v)
        case .text(let s): return Int(s)
        default: return nil
        }
    }

    public var asInt64: Int64? {
        switch self {
        case .integer(let v): return v
        case .number(let v): return Int64(v)
        case .text(let s): return Int64(s)
        default: return nil
        }
    }

    public var asString: String {
        switch self {
        case .text(let s): return s
        case .number(let n):
            return (n.rounded() == n) ? "\(Int64(n))" : "\(n)"
        case .integer(let i): return "\(i)"
        case .timeRange(let s, let e): return "\(s)-\(e)"
        case .rectangle(let x, let y, let w, let h): return "\(w):\(h):\(x):\(y)"
        }
    }
}

public typealias ParameterValues = [String: ParameterValue]

public struct ActionParameter: Equatable, Sendable {
    public let id: String
    public let label: String
    public let kind: ActionParameterKind
    public let defaultValue: ParameterValue
    public let minValue: Double?
    public let maxValue: Double?

    public init(
        id: String,
        label: String,
        kind: ActionParameterKind,
        defaultValue: ParameterValue,
        minValue: Double? = nil,
        maxValue: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.defaultValue = defaultValue
        self.minValue = minValue
        self.maxValue = maxValue
    }

    public static func parseCLIValue(_ raw: String, for kind: ActionParameterKind) -> ParameterValue {
        switch kind {
        case .percent, .number:
            if let d = Double(raw) {
                return .number(d)
            }
            return .text(raw)
        case .sizeInBytes:
            let upper = raw.uppercased().trimmingCharacters(in: .whitespaces)
            if upper.hasSuffix("K") || upper.hasSuffix("KB") {
                let numPart = upper.replacingOccurrences(of: "KB", with: "").replacingOccurrences(of: "K", with: "")
                if let d = Double(numPart) {
                    return .integer(Int64(d * 1024))
                }
            } else if upper.hasSuffix("M") || upper.hasSuffix("MB") {
                let numPart = upper.replacingOccurrences(of: "MB", with: "").replacingOccurrences(of: "M", with: "")
                if let d = Double(numPart) {
                    return .integer(Int64(d * 1024 * 1024))
                }
            } else if upper.hasSuffix("G") || upper.hasSuffix("GB") {
                let numPart = upper.replacingOccurrences(of: "GB", with: "").replacingOccurrences(of: "G", with: "")
                if let d = Double(numPart) {
                    return .integer(Int64(d * 1024 * 1024 * 1024))
                }
            } else if let intVal = Int64(raw) {
                return .integer(intVal)
            }
            return .text(raw)
        case .timeRange:
            let sep: Character = raw.contains(":") ? ":" : "-"
            let parts = raw.split(separator: sep).map(String.init)
            if parts.count == 2, let s = Double(parts[0]), let e = Double(parts[1]) {
                return .timeRange(start: s, end: e)
            }
            return .text(raw)
        case .rectangle:
            if raw.contains(":") {
                let parts = raw.split(separator: ":").compactMap { Int($0) }
                if parts.count == 4 {
                    return .rectangle(x: parts[2], y: parts[3], width: parts[0], height: parts[1])
                }
            } else if raw.contains(",") {
                let parts = raw.split(separator: ",").compactMap { Int($0) }
                if parts.count == 4 {
                    return .rectangle(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                }
            }
            return .text(raw)
        case .choice:
            return .text(raw)
        case .text:
            return .text(raw)
        }
    }
}
