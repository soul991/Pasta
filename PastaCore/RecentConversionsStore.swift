import Foundation
import AppKit

public struct RecentConversionItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let actionId: String
    public let fileName: String
    public let timestamp: Date
    public let fullPath: String?

    public init(
        id: UUID = UUID(),
        actionId: String = "",
        fileName: String = "",
        timestamp: Date = Date(),
        fullPath: String? = nil
    ) {
        self.id = id
        self.actionId = actionId
        self.fileName = fileName
        self.timestamp = timestamp
        self.fullPath = fullPath
    }
}

public final class RecentConversionsStore {
    public static let shared = RecentConversionsStore()

    public private(set) var fileURL: URL

    public static var defaultStoreURL: URL {
        return URL(fileURLWithPath: "/tmp/uninitialized_store.json")
    }

    public var items: [RecentConversionItem] {
        return []
    }

    public init(fileURL: URL = RecentConversionsStore.defaultStoreURL) {
        self.fileURL = fileURL
    }

    @discardableResult
    public func record(actionId: String, outputURL: URL, preferences: PreferencesManager = PreferencesManager.shared) -> RecentConversionItem? {
        return nil
    }

    public func clear() {}

    @discardableResult
    public func revealInFinder(item: RecentConversionItem) -> Bool {
        return false
    }
}
