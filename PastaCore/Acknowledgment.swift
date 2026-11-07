import Foundation

public struct AcknowledgmentItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let spdxId: String
    public let licenseUrl: String
    public let sourceUrl: String
    public let licenseText: String
    public let bundlingDecision: String
    public let usageDescription: String

    public init(
        id: String,
        name: String,
        version: String,
        spdxId: String,
        licenseUrl: String,
        sourceUrl: String,
        licenseText: String,
        bundlingDecision: String = "Do Not Bundle (User-managed via Homebrew)",
        usageDescription: String = ""
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.spdxId = spdxId
        self.licenseUrl = licenseUrl
        self.sourceUrl = sourceUrl
        self.licenseText = licenseText
        self.bundlingDecision = bundlingDecision
        self.usageDescription = usageDescription
    }
}

public struct AcknowledgmentCatalog: Codable, Sendable {
    public let items: [AcknowledgmentItem]

    public init(items: [AcknowledgmentItem] = []) {
        self.items = items
    }

    public func item(named name: String) -> AcknowledgmentItem? {
        return items.first { $0.name.lowercased() == name.lowercased() || $0.id.lowercased() == name.lowercased() }
    }

    public static func loadBundled() -> AcknowledgmentCatalog? {
        // 1. Try Bundle.module (SwiftPM resource bundle)
        if let moduleURL = Bundle.module.url(forResource: "acknowledgments", withExtension: "json"),
           let catalog = try? load(from: moduleURL) {
            return catalog
        }

        // 2. Try Bundle.main resources (for app bundle)
        if let mainURL = Bundle.main.url(forResource: "acknowledgments", withExtension: "json"),
           let catalog = try? load(from: mainURL) {
            return catalog
        }

        // 3. Fallback to file search in typical bundle/development locations
        let fallbackCandidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/acknowledgments.json"),
            Bundle.main.bundleURL.appendingPathComponent("Resources/acknowledgments.json"),
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/acknowledgments.json")
        ]

        for cand in fallbackCandidates {
            if FileManager.default.fileExists(atPath: cand.path),
               let catalog = try? load(from: cand) {
                return catalog
            }
        }

        return nil
    }

    public static func load(from url: URL) throws -> AcknowledgmentCatalog {
        let data = try Data(contentsOf: url)
        if let catalog = try? JSONDecoder().decode(AcknowledgmentCatalog.self, from: data) {
            return catalog
        }
        let items = try JSONDecoder().decode([AcknowledgmentItem].self, from: data)
        return AcknowledgmentCatalog(items: items)
    }
}
