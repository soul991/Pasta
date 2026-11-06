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
        actionId: String,
        fileName: String,
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
    public static let didUpdateNotification = Notification.Name("PastaRecentConversionsStoreDidUpdate")

    public private(set) var fileURL: URL
    private let lock = NSLock()
    private var internalItems: [RecentConversionItem] = []

    public var items: [RecentConversionItem] {
        lock.lock()
        defer { lock.unlock() }
        return internalItems
    }

    public static var defaultStoreURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let pastaDir = appSupport.appendingPathComponent("Pasta", isDirectory: true)
        return pastaDir.appendingPathComponent("recent_conversions.json")
    }

    public init(fileURL: URL = RecentConversionsStore.defaultStoreURL) {
        self.fileURL = fileURL
        loadFromDisk()
    }

    public func setStoreURL(_ url: URL) {
        lock.lock()
        self.fileURL = url
        loadFromDiskUnderLock()
        lock.unlock()
    }

    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        loadFromDiskUnderLock()
    }

    private func loadFromDiskUnderLock() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            internalItems = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            internalItems = try decoder.decode([RecentConversionItem].self, from: data)
        } catch {
            PastaLogger.shared.warning("Recent conversions store corrupted or invalid at \(fileURL.path); resetting gracefully: \(error.localizedDescription)")
            internalItems = []
        }
    }

    private func saveToDiskUnderLock() {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(internalItems)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            PastaLogger.shared.error("Failed to save recent conversions store to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func record(
        actionId: String,
        outputURL: URL,
        preferences: PreferencesManager = PreferencesManager.shared
    ) -> RecentConversionItem? {
        guard preferences.recentConversionsEnabled else {
            return nil
        }
        let fullPath: String? = preferences.recentConversionsStoreFullPath ? outputURL.path : nil
        let item = RecentConversionItem(
            actionId: actionId,
            fileName: outputURL.lastPathComponent,
            timestamp: Date(),
            fullPath: fullPath
        )

        lock.lock()
        internalItems.insert(item, at: 0)
        if internalItems.count > 100 {
            internalItems = Array(internalItems.prefix(100))
        }
        saveToDiskUnderLock()
        lock.unlock()

        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        return item
    }

    public func clear() {
        lock.lock()
        internalItems = []
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: fileURL)
        }
        lock.unlock()

        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
    }

    @discardableResult
    public func revealInFinder(item: RecentConversionItem) -> Bool {
        guard let path = item.fullPath, !path.isEmpty else {
            PastaLogger.shared.warning("Cannot reveal in Finder: no full path stored for item \(item.fileName)")
            return false
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            PastaLogger.shared.warning("Cannot reveal in Finder: file not found at \(path)")
            return false
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }
}
