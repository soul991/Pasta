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
        "ffmpeg", "ffprobe", "cwebp", "magick", "gs", "qpdf", "pdftoppm", "pdftotext",
        "exiftool", "pandoc", "rsvg-convert", "unar", "7zz", "sips", "ditto", "tar"
    ]
    public static let doctorOptionalToolNames = ["soffice", "ebook-convert", "avifenc"]

    private let searchPaths = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/opt/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin"
    ]

    private var overrides: [String: URL] = [:]
    private var unavailableOverrides: Set<String> = []
    private var cache: [String: URL] = [:]
    private let lock = NSLock()

    public init() {}

    public func setOverride(tool: String, url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        if let url = url {
            unavailableOverrides.remove(tool)
            overrides[tool] = url
        } else {
            overrides.removeValue(forKey: tool)
        }
    }

    /// Forces a tool to be unavailable without consulting the machine's PATH or app bundle.
    /// This is used by deterministic tests for optional conversion engines.
    public func setUnavailableOverride(tool: String, isUnavailable: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if isUnavailable {
            overrides.removeValue(forKey: tool)
            unavailableOverrides.insert(tool)
        } else {
            unavailableOverrides.remove(tool)
        }
    }

    public func findTool(_ name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }

        if unavailableOverrides.contains(name) {
            return nil
        }
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

        if name == "soffice" {
            let defaultAppPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            if fm.isExecutableFile(atPath: defaultAppPath) {
                let candidate = URL(fileURLWithPath: defaultAppPath)
                cache[name] = candidate
                return candidate
            }
        }

        return nil
    }

    public func requireTool(_ name: String) throws -> URL {
        guard let url = findTool(name) ?? findOptionalTool(name) else {
            throw PastaError.missingTool(name)
        }
        return url
    }

    public func findOptionalTool(_ name: String) -> URL? {
        if name == "soffice" {
            lock.lock()
            let isForcedUnavailable = unavailableOverrides.contains("soffice")
            let overridden = overrides["soffice"]
            lock.unlock()
            if isForcedUnavailable {
                return nil
            }
            if let overridden = overridden {
                if FileManager.default.isExecutableFile(atPath: overridden.path) {
                    return overridden
                }
            }
            let defaultAppPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            if FileManager.default.isExecutableFile(atPath: defaultAppPath) {
                return URL(fileURLWithPath: defaultAppPath)
            }
            return findTool(name)
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
