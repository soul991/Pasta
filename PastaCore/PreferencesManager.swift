import Foundation

public final class PreferencesManager {
    public static let shared = PreferencesManager()

    public enum OutputLocationMode: String, Codable {
        case besideOriginal
        case customFolder
    }

    private let modeKey = "pasta_output_mode"
    private let customPathKey = "pasta_output_custom_path"
    private let holdDurationKey = "pasta_shift_hold_duration_ms"
    private let stayOpenKey = "pasta_stay_open_after_release"
    private let showRingKey = "pasta_show_charging_ring"
    private let reduceMotionKey = "pasta_reduce_motion"
    private let watchdogTimeoutKey = "pasta_watchdog_timeout_minutes"

    public init() {}

    public var outputMode: OutputLocationMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: modeKey),
                  let mode = OutputLocationMode(rawValue: raw) else {
                return .besideOriginal
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    public var customFolderPath: String? {
        get {
            return UserDefaults.standard.string(forKey: customPathKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: customPathKey)
        }
    }

    /// Shift-hold duration in milliseconds (clamped between 300 ms and 1000 ms, default 450 ms)
    public var shiftHoldDurationMs: Double {
        get {
            let val = UserDefaults.standard.double(forKey: holdDurationKey)
            if val <= 0 {
                return 450.0
            }
            return min(max(val, 300.0), 1000.0)
        }
        set {
            let clamped = min(max(newValue, 300.0), 1000.0)
            UserDefaults.standard.set(clamped, forKey: holdDurationKey)
        }
    }

    /// Whether the wheel latches and stays open after Shift is released (default: true)
    public var stayOpenAfterRelease: Bool {
        get {
            if UserDefaults.standard.object(forKey: stayOpenKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: stayOpenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: stayOpenKey)
        }
    }

    /// Whether to display the 120ms-delayed charging progress ring around cursor (default: true)
    public var showChargingRing: Bool {
        get {
            if UserDefaults.standard.object(forKey: showRingKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showRingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showRingKey)
        }
    }

    /// Reduce motion setting override or query
    public var reduceMotionEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: reduceMotionKey) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: reduceMotionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: reduceMotionKey)
        }
    }

    /// Inactivity watchdog timeout in minutes for long-running tools like ffmpeg (default: 10 minutes)
    public var watchdogTimeoutMinutes: Double {
        get {
            let val = UserDefaults.standard.double(forKey: watchdogTimeoutKey)
            if val <= 0 {
                return 10.0
            }
            return max(val, 1.0)
        }
        set {
            let clamped = max(newValue, 1.0)
            UserDefaults.standard.set(clamped, forKey: watchdogTimeoutKey)
        }
    }

    public func effectiveDestination(for inputURL: URL) -> URL? {
        if outputMode == .customFolder, let path = customFolderPath, !path.isEmpty {
            let customURL = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: customURL.path, isDirectory: &isDir), isDir.boolValue {
                return customURL
            }
        }
        return nil // nil indicates beside original file
    }
}
