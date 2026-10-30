import Foundation

public struct InputValidator {
    public static func validateInputFile(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw PastaError.invalidInput("File does not exist at '\(url.path)'")
        }

        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: url.path)
        } catch {
            throw PastaError.invalidInput("Cannot read attributes for file '\(url.path)': \(error.localizedDescription)")
        }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        if size == 0 {
            throw PastaError.invalidInput("File is empty (0 bytes): '\(url.lastPathComponent)'")
        }
    }

    public static func validateTimeRange(start: Double, end: Double) throws {
        guard start >= 0 else {
            throw PastaError.invalidInput("Start time cannot be negative: \(start)")
        }
        guard end > start else {
            throw PastaError.invalidInput("End time (\(end)s) must be greater than start time (\(start)s)")
        }
    }

    public static func validateDimensions(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw PastaError.invalidInput("Invalid dimensions: \(width)x\(height). Width and height must be positive.")
        }
        guard width <= 16384 && height <= 16384 else {
            throw PastaError.invalidInput("Dimensions \(width)x\(height) exceed maximum supported limit (16384px)")
        }
    }

    public static func validateCropWithinBounds(width: Int, height: Int, x: Int, y: Int, containerWidth: Int, containerHeight: Int) throws {
        guard x >= 0 && y >= 0 else {
            throw PastaError.invalidInput("Crop rectangle origin must be non-negative: (\(x), \(y))")
        }
        guard width > 0 && height > 0 else {
            throw PastaError.invalidInput("Crop rectangle dimensions must be positive: (\(width)x\(height))")
        }
        if x + width > containerWidth || y + height > containerHeight {
            throw PastaError.invalidInput("Crop rectangle (\(width)x\(height)+\(x)+\(y)) exceeds container dimensions (\(containerWidth)x\(containerHeight))")
        }
    }

    public static func validatePDFMerge(files: [URL]) throws {
        guard files.count >= 2 else {
            throw PastaError.invalidInput("Merging PDFs requires at least 2 PDF files (received \(files.count))")
        }
        for file in files {
            guard file.pathExtension.lowercased() == "pdf" else {
                throw PastaError.invalidInput("All files for PDF merge must be .pdf files ('\(file.lastPathComponent)' is not a PDF)")
            }
            try validateInputFile(file)
        }
    }

    public static func validateParameters(declared: [ActionParameter], values: ParameterValues) throws {
        let declaredMap = Dictionary(uniqueKeysWithValues: declared.map { ($0.id, $0) })
        for (key, val) in values {
            guard let param = declaredMap[key] else {
                throw PastaError.invalidInput("Unknown parameter '\(key)'")
            }

            // Check hostile string characters
            let strVal = val.asString
            let hostileChars = [";", "&", "|", "`", "$", "\n", "\r", "\"", "'", "\0"]
            for ch in hostileChars {
                if strVal.contains(ch) {
                    throw PastaError.invalidInput("Hostile character '\(ch)' detected in parameter '\(key)'")
                }
            }

            // Range checks
            switch param.kind {
            case .percent:
                guard let num = val.asDouble else {
                    throw PastaError.invalidInput("Parameter '\(key)' must be a numeric percentage")
                }
                let min = param.minValue ?? 0.0
                let max = param.maxValue ?? 100.0
                if num < min || num > max {
                    throw PastaError.invalidInput("Parameter '\(key)' value \(num) is outside allowed range (\(min)-\(max)%)")
                }
            case .number:
                guard let num = val.asDouble else {
                    throw PastaError.invalidInput("Parameter '\(key)' must be a number")
                }
                if let min = param.minValue, num < min {
                    throw PastaError.invalidInput("Parameter '\(key)' value \(num) is below minimum \(min)")
                }
                if let max = param.maxValue, num > max {
                    throw PastaError.invalidInput("Parameter '\(key)' value \(num) exceeds maximum \(max)")
                }
            case .sizeInBytes:
                guard let bytes = val.asInt64, bytes >= 0 else {
                    throw PastaError.invalidInput("Parameter '\(key)' must be a non-negative byte count")
                }
            case .timeRange:
                switch val {
                case .timeRange(let s, let e):
                    try validateTimeRange(start: s, end: e)
                default:
                    throw PastaError.invalidInput("Parameter '\(key)' must be a time range")
                }
            case .rectangle:
                switch val {
                case .rectangle(let x, let y, let w, let h):
                    guard x >= 0 && y >= 0 else {
                        throw PastaError.invalidInput("Rectangle origin must be non-negative: (\(x), \(y))")
                    }
                    try validateDimensions(width: w, height: h)
                default:
                    throw PastaError.invalidInput("Parameter '\(key)' must be a rectangle")
                }
            case .choice(let options):
                let choice = val.asString
                guard options.contains(choice) else {
                    throw PastaError.invalidInput("Invalid choice '\(choice)' for '\(key)'. Allowed: \(options.joined(separator: ", "))")
                }
            case .text:
                break
            }
        }
    }
}
