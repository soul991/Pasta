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

    private var cache: [String: URL] = [:]
    private let lock = NSLock()

    public init() {}

    public func findTool(_ name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }

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
            throw PeelError.missingTool(name)
        }
        return url
    }
}
