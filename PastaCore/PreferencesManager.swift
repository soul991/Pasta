import Foundation
import AppKit

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
    private let keepWheelOpenKey = "pasta_keep_wheel_open_after_running"
    private let autoDismissWheelKey = "pasta_auto_dismiss_wheel_after_running"
    private let showRingKey = "pasta_show_charging_ring"
    private let reduceMotionKey = "pasta_reduce_motion"
    private let reduceTransparencyKey = "pasta_reduce_transparency"
    private let increaseContrastKey = "pasta_increase_contrast"
    private let watchdogTimeoutKey = "pasta_watchdog_timeout_minutes"
    private let maxConcurrentJobsKey = "pasta_max_concurrent_jobs"
    private let recentConversionsEnabledKey = "pasta_recent_conversions_enabled"
    private let recentConversionsStoreFullPathKey = "pasta_recent_conversions_store_full_path"
    private let deleteOriginalKey = "pasta_delete_original_enabled"
    private let deleteOriginalConfirmationKey = "pasta_delete_original_confirmation_record"
    private let wheelEnabledKey = "pasta_wheel_enabled"
    private let launchAtLoginKey = "pasta_launch_at_login"
    private let hasEverGrantedAccessibilityKey = "pasta_has_ever_granted_accessibility"

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

    /// Whether the wheel stays open after executing a tool (default: true)
    public var keepWheelOpenAfterRunning: Bool {
        get {
            if UserDefaults.standard.object(forKey: keepWheelOpenKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: keepWheelOpenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepWheelOpenKey)
        }
    }

    /// Whether the wheel auto-dismisses after a successful conversion when keepWheelOpenAfterRunning is true (default: false, never closes on error)
    public var autoDismissWheelAfterRunning: Bool {
        get {
            return UserDefaults.standard.bool(forKey: autoDismissWheelKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoDismissWheelKey)
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

    /// Reduce transparency setting override or query
    public var reduceTransparencyEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: reduceTransparencyKey) == nil {
                return NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }
            return UserDefaults.standard.bool(forKey: reduceTransparencyKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: reduceTransparencyKey)
        }
    }

    /// Increase contrast setting override or query
    public var increaseContrastEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: increaseContrastKey) == nil {
                return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            }
            return UserDefaults.standard.bool(forKey: increaseContrastKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: increaseContrastKey)
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

    /// Maximum concurrent jobs for batch conversions (default: 2)
    public var maxConcurrentJobs: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: maxConcurrentJobsKey)
            if val <= 0 {
                return 2
            }
            return max(val, 1)
        }
        set {
            let clamped = max(newValue, 1)
            UserDefaults.standard.set(clamped, forKey: maxConcurrentJobsKey)
        }
    }

    /// Whether recent conversions are tracked in local history (default: true)
    public var recentConversionsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: recentConversionsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: recentConversionsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: recentConversionsEnabledKey)
        }
    }

    /// Whether recent conversions store full file paths or only filenames for privacy (default: true)
    public var recentConversionsStoreFullPath: Bool {
        get {
            if UserDefaults.standard.object(forKey: recentConversionsStoreFullPathKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: recentConversionsStoreFullPathKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: recentConversionsStoreFullPathKey)
        }
    }

    // MARK: - Delete-Original Double-Confirmation Settings

    /// Whether delete-original is enabled. Can only evaluate to true if backed by a valid stored confirmation.
    public var deleteOriginalEnabled: Bool {
        get {
            guard UserDefaults.standard.bool(forKey: deleteOriginalKey) else { return false }
            guard let record = UserDefaults.standard.string(forKey: deleteOriginalConfirmationKey),
                  DeleteOriginalGuard.validateConfirmationRecord(record) else {
                return false
            }
            return true
        }
        set {
            // Cannot enable without valid stored confirmation
            if newValue {
                guard hasValidDeleteOriginalConfirmation else { return }
                UserDefaults.standard.set(true, forKey: deleteOriginalKey)
            } else {
                UserDefaults.standard.set(false, forKey: deleteOriginalKey)
            }
        }
    }

    /// Checks whether a valid cryptographic confirmation record exists in stored preferences.
    public var hasValidDeleteOriginalConfirmation: Bool {
        guard let record = UserDefaults.standard.string(forKey: deleteOriginalConfirmationKey) else {
            return false
        }
        return DeleteOriginalGuard.validateConfirmationRecord(record)
    }

    /// Enables delete-original with required confirmation phrase.
    @discardableResult
    public func enableDeleteOriginal(confirmationPhrase: String) -> Bool {
        guard confirmationPhrase == DeleteOriginalGuard.confirmationPhrase else {
            return false
        }
        let record = DeleteOriginalGuard.generateConfirmationRecord(confirmedAt: Date(), phrase: confirmationPhrase)
        guard !record.isEmpty, DeleteOriginalGuard.validateConfirmationRecord(record) else {
            return false
        }
        UserDefaults.standard.set(record, forKey: deleteOriginalConfirmationKey)
        UserDefaults.standard.set(true, forKey: deleteOriginalKey)
        return true
    }

    /// Disables delete-original and clears stored confirmation.
    public func disableDeleteOriginal() {
        UserDefaults.standard.set(false, forKey: deleteOriginalKey)
        UserDefaults.standard.removeObject(forKey: deleteOriginalConfirmationKey)
    }

    // MARK: - Wheel Trigger & Permission State Preferences

    /// Whether the Shift-drag wheel trigger is enabled or paused by the user (default: true)
    public var wheelEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: wheelEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: wheelEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: wheelEnabledKey)
        }
    }

    /// Whether launch-at-login preference is toggled on (default: false)
    public var launchAtLoginEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
        }
    }

    /// Tracks whether Accessibility permission was ever granted previously (to distinguish missing vs revoked)
    public var hasEverGrantedAccessibility: Bool {
        get {
            return UserDefaults.standard.bool(forKey: hasEverGrantedAccessibilityKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasEverGrantedAccessibilityKey)
        }
    }

    // MARK: - Last-Used Parameters Per Action

    private let lastUsedPrefix = "pasta_last_used_params_"

    public func lastUsedParameters(for actionID: String) -> [String: String]? {
        let key = lastUsedPrefix + actionID
        return UserDefaults.standard.dictionary(forKey: key) as? [String: String]
    }

    public func setLastUsedParameters(_ values: [String: String], for actionID: String) {
        let key = lastUsedPrefix + actionID
        UserDefaults.standard.set(values, forKey: key)
    }

    public func clearLastUsedParameters(for actionID: String) {
        let key = lastUsedPrefix + actionID
        UserDefaults.standard.removeObject(forKey: key)
    }

    public func lastUsedParameterValues(for actionID: String, parameters: [ActionParameter]) -> ParameterValues? {
        guard let dict = lastUsedParameters(for: actionID) else { return nil }
        var result: ParameterValues = [:]
        let paramMap = Dictionary(uniqueKeysWithValues: parameters.map { ($0.id, $0) })
        for (k, str) in dict {
            if let param = paramMap[k] {
                result[k] = ActionParameter.parseCLIValue(str, for: param.kind)
            }
        }
        return result
    }

    public func setLastUsedParameterValues(_ values: ParameterValues, for actionID: String) {
        var dict: [String: String] = [:]
        for (k, v) in values {
            dict[k] = v.asString
        }
        setLastUsedParameters(dict, for: actionID)
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
