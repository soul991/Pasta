import Foundation

public struct PastaToolStatus: Equatable {
    public let name: String
    public let isOptional: Bool
    public let path: String?

    public var isAvailable: Bool { path != nil }
    public var displayLine: String {
        let state = isAvailable ? "Available" : (isOptional ? "Optional missing" : "Missing")
        return "\(name): \(state)\(path.map { " — \($0)" } ?? "")"
    }
}

public final class ToolLocator {
    public static let shared = ToolLocator()

    public static let doctorRequiredToolNames = [
        "ffmpeg", "cwebp", "magick", "gs", "qpdf", "pdftoppm", "pdftotext",
        "exiftool", "pandoc", "rsvg-convert", "unar", "7zz", "sips", "ditto", "tar"
    ]
    public static let doctorOptionalToolNames = ["soffice", "ebook-convert", "avifenc"]

    private let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin"
    ]

    private var overrides: [String: URL] = [:]
    private var cache: [String: URL] = [:]
    private let lock = NSLock()

    public init() {}

    public func setOverride(tool: String, url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        if let url = url {
            overrides[tool] = url
        } else {
            overrides.removeValue(forKey: tool)
        }
    }

    public func findTool(_ name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }

        if let overridden = overrides[name] {
            return overridden
        }

        if let cached = cache[name] {
            return cached
        }

        let fm = FileManager.default
        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) {
                cache[name] = candidate
                return candidate
            }
        }

        return nil
    }

    public func requireTool(_ name: String) throws -> URL {
        guard let url = findTool(name) else {
            throw PastaError.missingTool(name)
        }
        return url
    }

    public func findOptionalTool(_ name: String) -> URL? {
        if name == "soffice" {
            lock.lock()
            let overridden = overrides["soffice"]
            lock.unlock()
            if let overridden = overridden {
                if FileManager.default.isExecutableFile(atPath: overridden.path) {
                    return overridden
                }
            }
            let defaultAppPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            if FileManager.default.isExecutableFile(atPath: defaultAppPath) {
                return URL(fileURLWithPath: defaultAppPath)
            }
            return nil
        }
        return findTool(name)
    }

    public func isOptionalToolAvailable(_ name: String) -> Bool {
        return findOptionalTool(name) != nil
    }

    public func doctorStatuses() -> [PastaToolStatus] {
        return Self.doctorRequiredToolNames.map { PastaToolStatus(name: $0, isOptional: false, path: findTool($0)?.path) }
            + Self.doctorOptionalToolNames.map { PastaToolStatus(name: $0, isOptional: true, path: findOptionalTool($0)?.path) }
    }

    public func doctorReport() -> String {
        doctorStatuses().map(\.displayLine).joined(separator: "\n")
    }
}
