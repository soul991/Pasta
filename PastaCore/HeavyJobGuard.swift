import Foundation
import IOKit.ps

public enum HeavyJobCategory: String, Codable, CaseIterable, Sendable {
    case video
    case audio
    case image
    case pdf
    case archive
    case ocr
    case other
}

public struct VideoLimitsConfig: Codable, Sendable {
    public var costThreshold: Double
    public var durationThresholdSeconds: Double
    public var codecFactors: [String: Double]

    enum CodingKeys: String, CodingKey {
        case costThreshold = "cost_threshold"
        case durationThresholdSeconds = "duration_threshold_seconds"
        case codecFactors = "codec_factors"
    }

    public init(costThreshold: Double = 500_000_000.0, durationThresholdSeconds: Double = 600.0, codecFactors: [String: Double] = [:]) {
        self.costThreshold = costThreshold
        self.durationThresholdSeconds = durationThresholdSeconds
        self.codecFactors = codecFactors
    }
}

public struct AudioLimitsConfig: Codable, Sendable {
    public var durationThresholdSeconds: Double

    enum CodingKeys: String, CodingKey {
        case durationThresholdSeconds = "duration_threshold_seconds"
    }

    public init(durationThresholdSeconds: Double = 1800.0) {
        self.durationThresholdSeconds = durationThresholdSeconds
    }
}

public struct ImageLimitsConfig: Codable, Sendable {
    public var megapixelsThreshold: Double

    enum CodingKeys: String, CodingKey {
        case megapixelsThreshold = "megapixels_threshold"
    }

    public init(megapixelsThreshold: Double = 50.0) {
        self.megapixelsThreshold = megapixelsThreshold
    }
}

public struct PDFLimitsConfig: Codable, Sendable {
    public var pagesThreshold: Int

    enum CodingKeys: String, CodingKey {
        case pagesThreshold = "pages_threshold"
    }

    public init(pagesThreshold: Int = 100) {
        self.pagesThreshold = pagesThreshold
    }
}

public struct ArchiveLimitsConfig: Codable, Sendable {
    public var declaredSizeBytesThreshold: Int64

    enum CodingKeys: String, CodingKey {
        case declaredSizeBytesThreshold = "declared_size_bytes_threshold"
    }

    public init(declaredSizeBytesThreshold: Int64 = 1_073_741_824) {
        self.declaredSizeBytesThreshold = declaredSizeBytesThreshold
    }
}

public struct OCRLimitsConfig: Codable, Sendable {
    public var pagesThreshold: Int

    enum CodingKeys: String, CodingKey {
        case pagesThreshold = "pages_threshold"
    }

    public init(pagesThreshold: Int = 20) {
        self.pagesThreshold = pagesThreshold
    }
}

public struct DiskSafetyConfig: Codable, Sendable {
    public var safetyBufferMultiplier: Double
    public var minimumHeadroomBytes: Int64

    enum CodingKeys: String, CodingKey {
        case safetyBufferMultiplier = "safety_buffer_multiplier"
        case minimumHeadroomBytes = "minimum_headroom_bytes"
    }

    public init(safetyBufferMultiplier: Double = 1.5, minimumHeadroomBytes: Int64 = 524_288_000) {
        self.safetyBufferMultiplier = safetyBufferMultiplier
        self.minimumHeadroomBytes = minimumHeadroomBytes
    }
}

public struct ThermalSafetyConfig: Codable, Sendable {
    public var pauseOnSerious: Bool
    public var pauseOnCritical: Bool
    public var autoResumeOnCooldown: Bool

    enum CodingKeys: String, CodingKey {
        case pauseOnSerious = "pause_on_serious"
        case pauseOnCritical = "pause_on_critical"
        case autoResumeOnCooldown = "auto_resume_on_cooldown"
    }

    public init(pauseOnSerious: Bool = true, pauseOnCritical: Bool = true, autoResumeOnCooldown: Bool = true) {
        self.pauseOnSerious = pauseOnSerious
        self.pauseOnCritical = pauseOnCritical
        self.autoResumeOnCooldown = autoResumeOnCooldown
    }
}

public struct ConcurrencyGuardConfig: Codable, Sendable {
    public var maxConcurrentHeavyJobs: Int

    enum CodingKeys: String, CodingKey {
        case maxConcurrentHeavyJobs = "max_concurrent_heavy_jobs"
    }

    public init(maxConcurrentHeavyJobs: Int = 1) {
        self.maxConcurrentHeavyJobs = maxConcurrentHeavyJobs
    }
}

public struct HeavyJobConfig: Codable, Sendable {
    public var video: VideoLimitsConfig
    public var audio: AudioLimitsConfig
    public var image: ImageLimitsConfig
    public var pdf: PDFLimitsConfig
    public var archive: ArchiveLimitsConfig
    public var ocr: OCRLimitsConfig
    public var diskSafety: DiskSafetyConfig
    public var thermal: ThermalSafetyConfig
    public var concurrency: ConcurrencyGuardConfig

    enum CodingKeys: String, CodingKey {
        case video
        case audio
        case image
        case pdf
        case archive
        case ocr
        case diskSafety = "disk_safety"
        case thermal
        case concurrency
    }

    public init(
        video: VideoLimitsConfig = VideoLimitsConfig(),
        audio: AudioLimitsConfig = AudioLimitsConfig(),
        image: ImageLimitsConfig = ImageLimitsConfig(),
        pdf: PDFLimitsConfig = PDFLimitsConfig(),
        archive: ArchiveLimitsConfig = ArchiveLimitsConfig(),
        ocr: OCRLimitsConfig = OCRLimitsConfig(),
        diskSafety: DiskSafetyConfig = DiskSafetyConfig(),
        thermal: ThermalSafetyConfig = ThermalSafetyConfig(),
        concurrency: ConcurrencyGuardConfig = ConcurrencyGuardConfig()
    ) {
        self.video = video
        self.audio = audio
        self.image = image
        self.pdf = pdf
        self.archive = archive
        self.ocr = ocr
        self.diskSafety = diskSafety
        self.thermal = thermal
        self.concurrency = concurrency
    }

    public static func load() -> HeavyJobConfig {
        let candidates: [URL?] = [
            Bundle.module.url(forResource: "heavy_job_limits", withExtension: "json"),
            Bundle(for: HeavyJobGuard.self).url(forResource: "heavy_job_limits", withExtension: "json"),
            Bundle.main.url(forResource: "heavy_job_limits", withExtension: "json"),
            URL(fileURLWithPath: "PastaCore/Resources/heavy_job_limits.json"),
            URL(fileURLWithPath: "Pasta.app/Contents/Resources/heavy_job_limits.json")
        ]
        for candidate in candidates {
            if let url = candidate,
               FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(HeavyJobConfig.self, from: data) {
                return decoded
            }
        }
        return HeavyJobConfig()
    }
}

public struct HeavyJobAssessment: Equatable, Sendable {
    public let isHeavy: Bool
    public let needsConfirmation: Bool
    public let category: HeavyJobCategory
    public let metricName: String
    public let metricValue: Double
    public let thresholdValue: Double
    public let estimatedOutputSizeBytes: Int64?
    public let warningMessage: String?
    public let isOnBattery: Bool

    public init(
        isHeavy: Bool,
        needsConfirmation: Bool,
        category: HeavyJobCategory,
        metricName: String,
        metricValue: Double,
        thresholdValue: Double,
        estimatedOutputSizeBytes: Int64? = nil,
        warningMessage: String? = nil,
        isOnBattery: Bool = false
    ) {
        self.isHeavy = isHeavy
        self.needsConfirmation = needsConfirmation
        self.category = category
        self.metricName = metricName
        self.metricValue = metricValue
        self.thresholdValue = thresholdValue
        self.estimatedOutputSizeBytes = estimatedOutputSizeBytes
        self.warningMessage = warningMessage
        self.isOnBattery = isOnBattery
    }
}

public enum HeavyJobEstimator {
    public static func videoCost(duration: Double, width: Int, height: Int, codec: String?, config: HeavyJobConfig) -> Double {
        let factor = codecFactor(for: codec, in: config)
        let pixels = Double(max(0, width * height))
        let dur = max(0.0, duration)
        return dur * pixels * factor
    }

    public static func codecFactor(for codec: String?, in config: HeavyJobConfig) -> Double {
        guard let codec = codec?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !codec.isEmpty else {
            return config.video.codecFactors["default"] ?? 1.0
        }
        if let direct = config.video.codecFactors[codec] {
            return direct
        }
        if codec == "h264" || codec == "avc" || codec == "avc1" {
            return config.video.codecFactors["h264"] ?? config.video.codecFactors["avc"] ?? 1.0
        }
        if codec == "hevc" || codec == "h265" || codec == "hev1" || codec == "hvc1" {
            return config.video.codecFactors["hevc"] ?? config.video.codecFactors["h265"] ?? 1.5
        }
        if codec == "av1" || codec == "av01" {
            return config.video.codecFactors["av1"] ?? 2.5
        }
        if codec == "prores" || codec.hasPrefix("apc") || codec.hasPrefix("ap4") {
            return config.video.codecFactors["prores"] ?? 0.8
        }
        if codec == "vp9" {
            return config.video.codecFactors["vp9"] ?? 1.8
        }
        return config.video.codecFactors["default"] ?? 1.0
    }

    public static func audioDuration(duration: Double) -> Double {
        return max(0.0, duration)
    }

    public static func imageMegapixels(width: Int, height: Int) -> Double {
        guard width > 0 && height > 0 else { return 0.0 }
        return Double(width * height) / 1_000_000.0
    }

    public static func pdfPages(pages: Int) -> Double {
        return Double(max(0, pages))
    }

    public static func archiveSize(declaredBytes: Int64) -> Double {
        return Double(max(0, declaredBytes))
    }

    public static func ocrPages(pages: Int) -> Double {
        return Double(max(0, pages))
    }
}

public protocol DiskSpaceProvider: Sendable {
    func availableFreeSpace(for directory: URL) throws -> Int64
}

public final class SystemDiskSpaceProvider: DiskSpaceProvider {
    public init() {}
    public func availableFreeSpace(for directory: URL) throws -> Int64 {
        let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values.volumeAvailableCapacityForImportantUsage {
            return important
        }
        if let avail = values.volumeAvailableCapacity {
            return Int64(avail)
        }
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: directory.path)
        if let freeSize = attrs[.systemFreeSize] as? Int64 {
            return freeSize
        }
        return 100 * 1024 * 1024 * 1024
    }
}

public final class MockDiskSpaceProvider: DiskSpaceProvider, @unchecked Sendable {
    public var freeSpace: Int64
    public init(freeSpace: Int64) {
        self.freeSpace = freeSpace
    }
    public func availableFreeSpace(for directory: URL) throws -> Int64 {
        return freeSpace
    }
}

public protocol ThermalStateProvider: AnyObject, Sendable {
    var currentThermalState: ProcessInfo.ThermalState { get }
    var isOnBattery: Bool { get }
    func setChangeHandler(_ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void)
}

public final class SystemThermalStateProvider: ThermalStateProvider, @unchecked Sendable {
    public init() {}
    public var currentThermalState: ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    public var isOnBattery: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as? String else {
            return false
        }
        return type == "Battery Power"
    }
    public func setChangeHandler(_ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void) {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler(ProcessInfo.processInfo.thermalState)
        }
    }
}

public final class MockThermalStateProvider: ThermalStateProvider, @unchecked Sendable {
    public var currentThermalState: ProcessInfo.ThermalState = .nominal
    public var isOnBattery: Bool = false
    private var handler: (@Sendable (ProcessInfo.ThermalState) -> Void)?

    public init(currentThermalState: ProcessInfo.ThermalState = .nominal, isOnBattery: Bool = false) {
        self.currentThermalState = currentThermalState
        self.isOnBattery = isOnBattery
    }

    public func setChangeHandler(_ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void) {
        self.handler = handler
    }

    public func simulateThermalStateChange(to newState: ProcessInfo.ThermalState) {
        currentThermalState = newState
        handler?(newState)
    }
}

public final class HeavyJobGuard: @unchecked Sendable {
    public static let shared = HeavyJobGuard()

    public var config: HeavyJobConfig
    public var diskSpaceProvider: DiskSpaceProvider
    public var thermalStateProvider: ThermalStateProvider

    private let lock = NSLock()
    private var activeHeavyJobs: Set<UUID> = []
    private var thermallyPausedJobs: Set<UUID> = []

    public init(
        config: HeavyJobConfig = HeavyJobConfig.load(),
        diskSpaceProvider: DiskSpaceProvider = SystemDiskSpaceProvider(),
        thermalStateProvider: ThermalStateProvider = SystemThermalStateProvider()
    ) {
        self.config = config
        self.diskSpaceProvider = diskSpaceProvider
        self.thermalStateProvider = thermalStateProvider

        self.thermalStateProvider.setChangeHandler { [weak self] newState in
            self?.handleThermalStateChange(newState)
        }
    }

    private func handleThermalStateChange(_ newState: ProcessInfo.ThermalState) {
        lock.lock()
        defer { lock.unlock() }

        if newState == .serious || newState == .critical {
            let shouldPause = (newState == .serious && config.thermal.pauseOnSerious) ||
                              (newState == .critical && config.thermal.pauseOnCritical)
            if shouldPause {
                for jobId in activeHeavyJobs {
                    if !thermallyPausedJobs.contains(jobId) {
                        try? JobRunner.shared.pause(jobId: jobId)
                        thermallyPausedJobs.insert(jobId)
                    }
                }
            }
        } else if newState == .nominal || newState == .fair {
            if config.thermal.autoResumeOnCooldown {
                for jobId in thermallyPausedJobs {
                    try? JobRunner.shared.resume(jobId: jobId)
                }
                thermallyPausedJobs.removeAll()
            }
        }
    }

    public func assess(
        action: ConversionAction,
        input: URL,
        probeResult: MediaProbeResult? = nil,
        codec: String? = nil,
        pageCount: Int? = nil,
        declaredArchiveBytes: Int64? = nil
    ) -> HeavyJobAssessment {
        let isOCR = action.id.contains(".ocr.") || action.id.hasPrefix("image.ocr") || action.id.hasPrefix("pdf.ocr")
        let category: HeavyJobCategory
        if isOCR {
            category = .ocr
        } else {
            switch action.category {
            case .video: category = .video
            case .audio: category = .audio
            case .image: category = .image
            case .pdf: category = .pdf
            case .archive: category = .archive
            default: category = .other
            }
        }

        let onBattery = thermalStateProvider.isOnBattery
        var isHeavy = false
        var metricName = ""
        var metricVal = 0.0
        var thresholdVal = 0.0
        var estSizeBytes: Int64?

        switch category {
        case .video:
            metricName = "video_compute_cost"
            let duration = probeResult?.duration ?? 0.0
            let width = probeResult?.width ?? 0
            let height = probeResult?.height ?? 0
            metricVal = HeavyJobEstimator.videoCost(duration: duration, width: width, height: height, codec: codec, config: config)
            thresholdVal = config.video.costThreshold
            if metricVal >= thresholdVal || duration >= config.video.durationThresholdSeconds {
                isHeavy = true
            }
            estSizeBytes = probeResult?.fileSize ?? (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .audio:
            metricName = "duration_seconds"
            metricVal = HeavyJobEstimator.audioDuration(duration: probeResult?.duration ?? 0.0)
            thresholdVal = config.audio.durationThresholdSeconds
            if metricVal >= thresholdVal {
                isHeavy = true
            }
            estSizeBytes = probeResult?.fileSize ?? (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .image:
            metricName = "megapixels"
            metricVal = HeavyJobEstimator.imageMegapixels(width: probeResult?.width ?? 0, height: probeResult?.height ?? 0)
            thresholdVal = config.image.megapixelsThreshold
            if metricVal >= thresholdVal {
                isHeavy = true
            }
            estSizeBytes = probeResult?.fileSize ?? (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .pdf:
            metricName = "page_count"
            metricVal = HeavyJobEstimator.pdfPages(pages: pageCount ?? 0)
            thresholdVal = Double(config.pdf.pagesThreshold)
            if metricVal >= thresholdVal {
                isHeavy = true
            }
            estSizeBytes = (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .archive:
            metricName = "declared_uncompressed_bytes"
            metricVal = HeavyJobEstimator.archiveSize(declaredBytes: declaredArchiveBytes ?? (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64) ?? 0)
            thresholdVal = Double(config.archive.declaredSizeBytesThreshold)
            if metricVal >= thresholdVal {
                isHeavy = true
            }
            estSizeBytes = declaredArchiveBytes ?? (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .ocr:
            metricName = "page_count"
            metricVal = HeavyJobEstimator.ocrPages(pages: pageCount ?? 1)
            thresholdVal = Double(config.ocr.pagesThreshold)
            if metricVal >= thresholdVal {
                isHeavy = true
            }
            estSizeBytes = (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? Int64)

        case .other:
            isHeavy = false
            metricName = "none"
            metricVal = 0.0
            thresholdVal = 0.0
        }

        var warning: String?
        if isHeavy {
            var msg = ""
            switch category {
            case .video:
                msg = "This video conversion involves substantial compute processing. It will utilize significant CPU resources."
            case .audio:
                msg = "This audio file is extensive in duration. Processing will require significant sustained computation."
            case .image:
                msg = "This image exceeds \(Int(config.image.megapixelsThreshold)) megapixels. Decoding and processing will require substantial memory and processing."
            case .pdf:
                msg = "This PDF document contains \(Int(metricVal)) pages. Processing large document page counts requires significant system resources."
            case .archive:
                msg = "This archive uncompresses to a large volume of data. Extraction requires significant disk and compute resources."
            case .ocr:
                msg = "Optical character recognition across \(Int(metricVal)) pages requires substantial neural and text processing."
            case .other:
                msg = "This job requires significant compute processing."
            }

            if onBattery {
                msg += " Your Mac is currently running on battery power."
            }
            warning = msg
        }

        return HeavyJobAssessment(
            isHeavy: isHeavy,
            needsConfirmation: isHeavy,
            category: category,
            metricName: metricName,
            metricValue: metricVal,
            thresholdValue: thresholdVal,
            estimatedOutputSizeBytes: estSizeBytes,
            warningMessage: warning,
            isOnBattery: onBattery
        )
    }

    public func checkFreeDiskSpace(for outputURL: URL, estimatedOutputBytes: Int64) throws {
        let directory = outputURL.deletingLastPathComponent()
        let available = try diskSpaceProvider.availableFreeSpace(for: directory)
        let required = Int64(Double(estimatedOutputBytes) * config.diskSafety.safetyBufferMultiplier) + config.diskSafety.minimumHeadroomBytes
        if available < required {
            throw PastaError.insufficientDiskSpace(availableBytes: available, requiredBytes: required)
        }
    }

    public func tryAcquireHeavyJobSlot(jobId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeHeavyJobs.count >= config.concurrency.maxConcurrentHeavyJobs && !activeHeavyJobs.contains(jobId) {
            return false
        }
        activeHeavyJobs.insert(jobId)
        return true
    }

    public func releaseHeavyJobSlot(jobId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        activeHeavyJobs.remove(jobId)
        thermallyPausedJobs.remove(jobId)
    }

    public func isJobThermallyPaused(_ jobId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return thermallyPausedJobs.contains(jobId)
    }

    public func resumeByUser(jobId: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        try JobRunner.shared.resume(jobId: jobId)
        thermallyPausedJobs.remove(jobId)
    }
}
