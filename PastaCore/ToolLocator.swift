import Foundation

public final class ToolLocator {
    public static let shared = ToolLocator()

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
}
