import Foundation
import AppKit

/// Concurrent execution queue for batch conversion jobs.
/// Manages running at most `maxConcurrent` jobs at a time, tracks queued items,
/// handles individual failures without stopping others, and supports clean cancellation.
public final class BatchJobQueue {
    public struct QueueItem {
        public let id: UUID
        public let file: URL
        public let row: JobStatusRowView?

        public init(id: UUID = UUID(), file: URL, row: JobStatusRowView? = nil) {
            self.id = id
            self.file = file
            self.row = row
        }
    }

    public let action: ConversionAction
    public let maxConcurrent: Int
    public let formModel: ParameterFormModel?
    public let fallbackParams: ParameterValues
    public let probe: MediaProbe?

    private var pendingItems: [QueueItem] = []
    private var runningItems: [UUID: QueueItem] = [:]
    private let lock = NSLock()
    private var isCancelled = false

    public private(set) var completedCount: Int = 0
    public private(set) var failedCount: Int = 0
    public var totalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingItems.count + runningItems.count + completedCount + failedCount
    }

    public var runningCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return runningItems.count
    }

    public var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingItems.count
    }

    public var onProgress: ((Int, Int) -> Void)?
    public var onAllFinished: (() -> Void)?
    public var onItemStarted: ((UUID, URL) -> Void)?
    public var onItemFinished: ((UUID, URL, Result<URL, Error>) -> Void)?

    public init(
        files: [URL],
        action: ConversionAction,
        formModel: ParameterFormModel? = nil,
        fallbackParams: ParameterValues = [:],
        probe: MediaProbe? = nil,
        maxConcurrent: Int = PreferencesManager.shared.maxConcurrentJobs,
        makeRow: ((URL) -> JobStatusRowView?)? = nil
    ) {
        self.action = action
        self.formModel = formModel
        self.fallbackParams = fallbackParams
        self.probe = probe
        self.maxConcurrent = max(1, maxConcurrent)
        self.pendingItems = files.map { file in
            let itemID = UUID()
            let row = makeRow?(file)
            row?.jobID = itemID
            row?.onCancel = { [weak self] in
                self?.cancelItem(itemID)
            }
            row?.update(state: .queued)
            return QueueItem(id: itemID, file: file, row: row)
        }
    }

    public func start() {
        scheduleNext()
    }

    public func cancelItem(_ id: UUID) {
        lock.lock()
        if let idx = pendingItems.firstIndex(where: { $0.id == id }) {
            let item = pendingItems.remove(at: idx)
            failedCount += 1
            let comp = completedCount
            let fail = failedCount
            lock.unlock()
            item.row?.update(state: .failed("Cancelled"))
            onItemFinished?(item.id, item.file, .failure(PastaError.cancelled))
            onProgress?(comp, fail)
            scheduleNext()
            return
        }
        if let item = runningItems.removeValue(forKey: id) {
            failedCount += 1
            let comp = completedCount
            let fail = failedCount
            lock.unlock()
            JobRunner.shared.cancel(jobId: id)
            item.row?.update(state: .failed("Cancelled"))
            onItemFinished?(item.id, item.file, .failure(PastaError.cancelled))
            onProgress?(comp, fail)
            scheduleNext()
            return
        }
        lock.unlock()
    }

    public func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        let runningToCancel = Array(runningItems.values)
        let queuedToCancel = pendingItems
        pendingItems.removeAll()
        runningItems.removeAll()
        failedCount += queuedToCancel.count
        let comp = completedCount
        let fail = failedCount
        lock.unlock()

        // Mark queued items cancelled without starting them
        for item in queuedToCancel {
            item.row?.update(state: .failed("Cancelled"))
            onItemFinished?(item.id, item.file, .failure(PastaError.cancelled))
        }

        // Cancel running jobs in JobRunner
        for item in runningToCancel {
            JobRunner.shared.cancel(jobId: item.id)
            item.row?.update(state: .failed("Cancelled"))
            onItemFinished?(item.id, item.file, .failure(PastaError.cancelled))
        }

        Self.cleanLeftoverTempDirectories()
        onProgress?(comp, fail)
    }

    private func scheduleNext() {
        lock.lock()
        if isCancelled {
            lock.unlock()
            return
        }

        var toDispatch: [QueueItem] = []
        while runningItems.count < maxConcurrent && !pendingItems.isEmpty {
            let item = pendingItems.removeFirst()
            runningItems[item.id] = item
            toDispatch.append(item)
        }

        let isDone = runningItems.isEmpty && pendingItems.isEmpty
        lock.unlock()

        for item in toDispatch {
            dispatchJob(item)
        }

        if isDone {
            onAllFinished?()
        }
    }

    private func dispatchJob(_ item: QueueItem) {
        item.row?.update(state: .running)
        onItemStarted?(item.id, item.file)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            if self.isCancelled {
                self.lock.unlock()
                return
            }
            self.lock.unlock()

            // Resolve parameters per file using formModel or fallbackParams
            let resolvedParams: ParameterValues
            if let model = self.formModel {
                do {
                    resolvedParams = try model.resolveParameters(for: item.file, probe: self.probe)
                } catch {
                    self.finishJob(item: item, result: .failure(error))
                    return
                }
            } else {
                resolvedParams = self.fallbackParams
            }

            do {
                let output = try JobRunner.shared.run(
                    action: self.action,
                    input: item.file,
                    parameters: resolvedParams,
                    jobId: item.id
                )
                self.finishJob(item: item, result: .success(output))
            } catch {
                self.finishJob(item: item, result: .failure(error))
            }
        }
    }

    private func finishJob(item: QueueItem, result: Result<URL, Error>) {
        lock.lock()
        if !isCancelled {
            runningItems.removeValue(forKey: item.id)
            switch result {
            case .success:
                completedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        let comp = completedCount
        let fail = failedCount
        lock.unlock()

        switch result {
        case .success(let output):
            item.row?.update(state: .completed(output))
        case .failure(let err):
            item.row?.update(state: .failed(err.localizedDescription))
        }

        onItemFinished?(item.id, item.file, result)
        onProgress?(comp, fail)
        scheduleNext()
    }

    public static func cleanLeftoverTempDirectories() {
        let fm = FileManager.default
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        guard let contents = try? fm.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil) else { return }
        for item in contents {
            if item.lastPathComponent.hasPrefix("Pasta_") {
                try? fm.removeItem(at: item)
            }
        }
    }
}
