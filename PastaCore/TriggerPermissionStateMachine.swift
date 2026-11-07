import Foundation
import AppKit
import ServiceManagement

public enum WheelTriggerState: String, Codable, Equatable {
    case enabled
    case paused
}

public enum AccessibilityState: String, Codable, Equatable {
    case missing
    case granted
    case revoked
}

public enum LaunchAtLoginState: String, Codable, Equatable {
    case enabled
    case disabled
}

public enum EffectiveTriggerStatus: Equatable {
    case active
    case pausedByUser
    case waitingForAccessibility
    case accessibilityRevoked
}

public protocol AccessibilityPermissionProvider: AnyObject {
    func isTrusted() -> Bool
    func requestPermission() -> Bool
}

public protocol LaunchAtLoginProvider: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public protocol DragMonitorLifecycleController: AnyObject {
    var isMonitoring: Bool { get }
    func startMonitoring()
    func stopMonitoring()
}

public final class SystemAccessibilityPermissionProvider: AccessibilityPermissionProvider {
    public static let shared = SystemAccessibilityPermissionProvider()
    public init() {}
    public func isTrusted() -> Bool {
        return DragMonitor.isAccessibilityTrusted(prompt: false)
    }
    public func requestPermission() -> Bool {
        return DragMonitor.isAccessibilityTrusted(prompt: true)
    }
}

public final class SystemLaunchAtLoginProvider: LaunchAtLoginProvider {
    public static let shared = SystemLaunchAtLoginProvider()
    public init() {}
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "pasta_launch_at_login")
        }
    }
    public func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
        UserDefaults.standard.set(enabled, forKey: "pasta_launch_at_login")
    }
}

public final class MockAccessibilityPermissionProvider: AccessibilityPermissionProvider {
    public var trusted: Bool
    public var requestPermissionCalled = false
    public init(trusted: Bool = false) {
        self.trusted = trusted
    }
    public func isTrusted() -> Bool { return trusted }
    public func requestPermission() -> Bool {
        requestPermissionCalled = true
        return trusted
    }
}

public final class MockLaunchAtLoginProvider: LaunchAtLoginProvider {
    public var isEnabled: Bool
    public var simulateError: Error?
    public init(enabled: Bool = false) {
        self.isEnabled = enabled
    }
    public func setEnabled(_ enabled: Bool) throws {
        if let err = simulateError { throw err }
        self.isEnabled = enabled
    }
}

public final class MockDragMonitorLifecycleController: DragMonitorLifecycleController {
    public private(set) var isMonitoring: Bool = false
    public var startMonitoringCallCount = 0
    public var stopMonitoringCallCount = 0
    public init(isMonitoring: Bool = false) {
        self.isMonitoring = isMonitoring
    }
    public func startMonitoring() {
        isMonitoring = true
        startMonitoringCallCount += 1
    }
    public func stopMonitoring() {
        isMonitoring = false
        stopMonitoringCallCount += 1
    }
}

public final class TriggerPermissionStateMachine {
    public private(set) var wheelState: WheelTriggerState
    public private(set) var accessibilityState: AccessibilityState
    public private(set) var launchAtLoginState: LaunchAtLoginState

    public let permissionProvider: AccessibilityPermissionProvider
    public let launchAtLoginProvider: LaunchAtLoginProvider
    public let monitorController: DragMonitorLifecycleController
    public let preferences: PreferencesManager

    private var pollTimer: Timer?
    public var isAutoPollingActive: Bool {
        return pollTimer != nil
    }

    public var onStateChange: ((EffectiveTriggerStatus) -> Void)?

    public init(
        permissionProvider: AccessibilityPermissionProvider = SystemAccessibilityPermissionProvider.shared,
        launchAtLoginProvider: LaunchAtLoginProvider = SystemLaunchAtLoginProvider.shared,
        monitorController: DragMonitorLifecycleController = DragMonitor.shared,
        preferences: PreferencesManager = .shared
    ) {
        self.permissionProvider = permissionProvider
        self.launchAtLoginProvider = launchAtLoginProvider
        self.monitorController = monitorController
        self.preferences = preferences

        self.wheelState = preferences.wheelEnabled ? .enabled : .paused

        if permissionProvider.isTrusted() {
            self.accessibilityState = .granted
            preferences.hasEverGrantedAccessibility = true
        } else if preferences.hasEverGrantedAccessibility {
            self.accessibilityState = .revoked
        } else {
            self.accessibilityState = .missing
        }

        self.launchAtLoginState = launchAtLoginProvider.isEnabled ? .enabled : .disabled

        if self.wheelState == .enabled && self.accessibilityState == .granted {
            self.monitorController.startMonitoring()
        }
    }

    public var effectiveStatus: EffectiveTriggerStatus {
        if wheelState == .paused {
            return .pausedByUser
        }
        switch accessibilityState {
        case .granted:
            return .active
        case .revoked:
            return .accessibilityRevoked
        case .missing:
            return .waitingForAccessibility
        }
    }

    public func setWheelState(_ state: WheelTriggerState) {
        let oldStatus = effectiveStatus
        self.wheelState = state
        preferences.wheelEnabled = (state == .enabled)

        if state == .enabled {
            if accessibilityState == .granted {
                monitorController.startMonitoring()
            }
        } else {
            monitorController.stopMonitoring()
        }

        let newStatus = effectiveStatus
        if oldStatus != newStatus {
            onStateChange?(newStatus)
        }
    }

    public func checkAccessibilityPermission() {
        let oldStatus = effectiveStatus
        let isTrusted = permissionProvider.isTrusted()

        if isTrusted {
            let wasGranted = (accessibilityState == .granted)
            accessibilityState = .granted
            preferences.hasEverGrantedAccessibility = true

            if !wasGranted && wheelState == .enabled {
                monitorController.startMonitoring()
            }
        } else {
            let wasTrusted = (accessibilityState == .granted)
            if wasTrusted || preferences.hasEverGrantedAccessibility {
                accessibilityState = .revoked
            } else {
                accessibilityState = .missing
            }

            if wasTrusted {
                monitorController.stopMonitoring()
            }
        }

        let newStatus = effectiveStatus
        if oldStatus != newStatus {
            onStateChange?(newStatus)
        }
    }

    public func pollTick() {
        checkAccessibilityPermission()
    }

    public func setLaunchAtLogin(enabled: Bool) throws {
        try launchAtLoginProvider.setEnabled(enabled)
        preferences.launchAtLoginEnabled = enabled
        launchAtLoginState = enabled ? .enabled : .disabled
    }

    public func startAutoPolling(interval: TimeInterval = 1.0) {
        stopAutoPolling()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
        RunLoop.current.add(timer, forMode: .default)
        self.pollTimer = timer
    }

    public func stopAutoPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        stopAutoPolling()
    }
}
