import Foundation
import AppKit

// MARK: - Clock Protocol for Deterministic Testing
public protocol DragMonitorClock {
    var now: TimeInterval { get }
}

public struct SystemDragMonitorClock: DragMonitorClock {
    public init() {}
    public var now: TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }
}

public final class MockDragMonitorClock: DragMonitorClock {
    public var currentTime: TimeInterval

    public init(initialTime: TimeInterval = 1000.0) {
        self.currentTime = initialTime
    }

    public var now: TimeInterval {
        return currentTime
    }

    public func advance(by seconds: TimeInterval) {
        currentTime += seconds
    }

    public func advanceMs(_ ms: Double) {
        currentTime += (ms / 1000.0)
    }
}

// MARK: - Pasteboard Reader Protocol
public protocol DragPasteboardReader {
    func extractFileURLs() -> [URL]
}

public struct SystemDragPasteboardReader: DragPasteboardReader {
    public init() {}

    public func extractFileURLs() -> [URL] {
        let pboard = NSPasteboard(name: .drag)
        guard let items = pboard.pasteboardItems, !items.isEmpty else {
            return []
        }

        var validURLs: [URL] = []
        for item in items {
            if let str = item.string(forType: .fileURL), let url = URL(string: str) {
                if FileManager.default.fileExists(atPath: url.path) {
                    validURLs.append(url)
                }
            }
        }
        return validURLs
    }
}

public final class MockDragPasteboardReader: DragPasteboardReader {
    public var mockURLs: [URL]

    public init(urls: [URL] = []) {
        self.mockURLs = urls
    }

    public func extractFileURLs() -> [URL] {
        return mockURLs
    }
}

// MARK: - DragMonitor State Machine
public final class DragMonitor {
    public static let shared = DragMonitor()

    public enum State: Equatable {
        case idle
        case armed(startedAt: TimeInterval, files: [URL], location: NSPoint)
        case charging(startedAt: TimeInterval, files: [URL], location: NSPoint)
        case open(openedAt: TimeInterval, files: [URL], location: NSPoint, isAdvanced: Bool)
        case secondHoldArmed(startedAt: TimeInterval, files: [URL], location: NSPoint)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.armed(let t1, let f1, let l1), .armed(let t2, let f2, let l2)):
                return abs(t1 - t2) < 0.0001 && f1 == f2 && l1 == l2
            case (.charging(let t1, let f1, let l1), .charging(let t2, let f2, let l2)):
                return abs(t1 - t2) < 0.0001 && f1 == f2 && l1 == l2
            case (.open(let t1, let f1, let l1, let a1), .open(let t2, let f2, let l2, let a2)):
                return abs(t1 - t2) < 0.0001 && f1 == f2 && l1 == l2 && a1 == a2
            case (.secondHoldArmed(let t1, let f1, let l1), .secondHoldArmed(let t2, let f2, let l2)):
                return abs(t1 - t2) < 0.0001 && f1 == f2 && l1 == l2
            default:
                return false
            }
        }
    }

    // Callbacks
    public var onChargingProgress: ((Double, NSPoint) -> Void)?
    public var onChargingCancel: (() -> Void)?
    public var onWheelOpen: (([URL], Bool, NSPoint) -> Void)?
    public var onWheelClose: (() -> Void)?
    public var onModeToggle: ((Bool) -> Void)?
    public var onFilesReplaced: (([URL]) -> Void)?

    // Backward-compatibility callbacks
    public var onDragStart: (([URL], Bool, NSPoint) -> Void)? {
        get { return onWheelOpen }
        set { onWheelOpen = newValue }
    }
    public var onDragEnd: (() -> Void)? {
        get { return onWheelClose }
        set { onWheelClose = newValue }
    }

    // Dependencies
    public var clock: DragMonitorClock
    public var pasteboardReader: DragPasteboardReader
    public var preferences: PreferencesManager

    // Current internal state
    public private(set) var state: State = .idle

    // Sticky context: files remembered while wheel remains open
    public private(set) var rememberedFiles: [URL] = []

    // Option tap tracking
    private var optionKeyDownTimestamp: TimeInterval?

    // System event monitors
    private var globalDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?

    private var localDragMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyDownMonitor: Any?

    public init(
        clock: DragMonitorClock = SystemDragMonitorClock(),
        pasteboardReader: DragPasteboardReader = SystemDragPasteboardReader(),
        preferences: PreferencesManager = PreferencesManager.shared
    ) {
        self.clock = clock
        self.pasteboardReader = pasteboardReader
        self.preferences = preferences
    }

    public static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public var holdDurationSeconds: TimeInterval {
        return preferences.shiftHoldDurationMs / 1000.0
    }

    public var isWheelOpen: Bool {
        switch state {
        case .open, .secondHoldArmed:
            return true
        default:
            return false
        }
    }

    // MARK: - Diagnostic Logging Helper

    private func logTransition(
        event: String,
        modifiers: NSEvent.ModifierFlags? = nil,
        location: NSPoint? = nil,
        oldState: State,
        newState: State,
        reason: String? = nil
    ) {
        var details = "event: \(event), oldState: \(oldState), newState: \(newState)"
        if let m = modifiers { details += ", modifiers: \(m.rawValue)" }
        if let l = location { details += ", location: (\(l.x), \(l.y))" }
        if let r = reason { details += ", reason: \(r)" }
        PastaLogger.shared.debug("DragMonitor [\(clock.now)] \(details)")
    }

    // MARK: - Public State Machine Processing (Unit Testable)

    /// Process left mouse drag event
    public func processMouseDragged(
        modifiers: NSEvent.ModifierFlags,
        location: NSPoint,
        timestamp: TimeInterval
    ) {
        let isShiftHeld = modifiers.contains(.shift)
        let otherModifiers = modifiers.subtracting([.shift])
        let hasOtherModifiers = otherModifiers.contains(.control) ||
                               otherModifiers.contains(.command)

        // Rule: Any other modifier during charging cancels
        if hasOtherModifiers {
            if case .armed = state { cancelCharging(reason: "Cancel modifier during armed") }
            if case .charging = state { cancelCharging(reason: "Cancel modifier during charging") }
            return
        }

        switch state {
        case .idle:
            guard isShiftHeld else { return }
            // Verify file drag session
            let files = pasteboardReader.extractFileURLs()
            guard !files.isEmpty else { return }

            // Armed: valid file drag active and Shift went down
            let oldState = state
            state = .armed(startedAt: timestamp, files: files, location: location)
            logTransition(event: "mouseDragged.armed", modifiers: modifiers, location: location, oldState: oldState, newState: state)

        case .armed(let startedAt, let files, _):
            guard isShiftHeld else {
                cancelCharging(reason: "Shift released before 120ms threshold")
                return
            }

            let elapsed = timestamp - startedAt
            let duration = holdDurationSeconds

            if elapsed >= duration - 0.0005 {
                // Open wheel! Latches open.
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(1.0, location)
                }
                openWheel(openedAt: timestamp, files: files, location: location, isAdvanced: false)
            } else if elapsed >= 0.120 {
                // After 120 ms delay, transition to charging and emit progress
                let oldState = state
                state = .charging(startedAt: startedAt, files: files, location: location)
                logTransition(event: "mouseDragged.charging", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                let ringProgress = min(max(elapsed / duration, 0.0), 1.0)
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(ringProgress, location)
                }
            }

        case .charging(let startedAt, let files, _):
            guard isShiftHeld else {
                cancelCharging(reason: "Shift released before hold duration completed")
                return
            }

            let elapsed = timestamp - startedAt
            let duration = holdDurationSeconds

            if elapsed >= duration - 0.0005 {
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(1.0, location)
                }
                openWheel(openedAt: timestamp, files: files, location: location, isAdvanced: false)
            } else {
                let ringProgress = min(max(elapsed / duration, 0.0), 1.0)
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(ringProgress, location)
                }
            }

        case .open(_, let currentFiles, _, _):
            // Sticky wheel: drag movements do NOT close the wheel.
            // Check if a NEW drag with Shift held has started:
            if isShiftHeld {
                let newFiles = pasteboardReader.extractFileURLs()
                if !newFiles.isEmpty && newFiles != currentFiles {
                    let oldState = state
                    state = .secondHoldArmed(startedAt: timestamp, files: newFiles, location: location)
                    logTransition(event: "mouseDragged.startSecondHold", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                }
            }

        case .secondHoldArmed(let startedAt, let newFiles, let loc):
            guard isShiftHeld else {
                // Shift released before second hold threshold:
                // Revert to open state with current remembered files. Does NOT close wheel!
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "mouseDragged.secondHoldRevert", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                return
            }

            let elapsed = timestamp - startedAt
            if elapsed >= holdDurationSeconds - 0.0005 {
                // Second Shift hold completes: replace remembered files, keep wheel open!
                let oldState = state
                rememberedFiles = newFiles
                state = .open(openedAt: timestamp, files: newFiles, location: location, isAdvanced: false)
                logTransition(event: "mouseDragged.secondHoldReplacedFiles", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                onFilesReplaced?(newFiles)
            }
        }
    }

    /// Process modifier flag changes (Shift down/up, Option down/up)
    public func processFlagsChanged(
        modifiers: NSEvent.ModifierFlags,
        timestamp: TimeInterval
    ) {
        let isShiftHeld = modifiers.contains(.shift)
        let isOptionHeld = modifiers.contains(.option)
        let otherModifiers = modifiers.subtracting([.shift, .option])
        let hasCancelModifiers = otherModifiers.contains(.control) || otherModifiers.contains(.command)

        if hasCancelModifiers {
            if case .armed = state { cancelCharging(reason: "Cancel modifier during armed") }
            if case .charging = state { cancelCharging(reason: "Cancel modifier during charging") }
            return
        }

        switch state {
        case .armed, .charging:
            if !isShiftHeld {
                // Shift released before threshold: cancel charging!
                cancelCharging(reason: "Shift released before opening")
            }

        case .open(let openedAt, let files, let loc, var isAdvanced):
            if !isShiftHeld && !preferences.stayOpenAfterRelease {
                closeWheel(reason: "Shift released and stayOpenAfterRelease is false")
                return
            }
            // Releasing Shift while wheel is open does NOT close it: wheel latches open until Esc!
            // Track Option key tap: a quick Option tap (<250 ms) switches Convert/Advanced
            if isOptionHeld {
                if optionKeyDownTimestamp == nil {
                    optionKeyDownTimestamp = timestamp
                }
            } else {
                if let downTime = optionKeyDownTimestamp {
                    let elapsed = timestamp - downTime
                    optionKeyDownTimestamp = nil
                    if elapsed < 0.250 {
                        // Quick Option tap detected: toggle mode!
                        isAdvanced.toggle()
                        let oldState = state
                        state = .open(openedAt: openedAt, files: files, location: loc, isAdvanced: isAdvanced)
                        logTransition(event: "flagsChanged.optionToggle", modifiers: modifiers, oldState: oldState, newState: state)
                        onModeToggle?(isAdvanced)
                    }
                }
            }

            // If Shift pressed down again while open with files:
            if isShiftHeld {
                let newFiles = pasteboardReader.extractFileURLs()
                if !newFiles.isEmpty && newFiles != files {
                    let oldState = state
                    state = .secondHoldArmed(startedAt: timestamp, files: newFiles, location: loc)
                    logTransition(event: "flagsChanged.secondHoldArmed", modifiers: modifiers, oldState: oldState, newState: state)
                }
            }

        case .secondHoldArmed(let startedAt, let newFiles, let loc):
            if !isShiftHeld {
                // Shift released before second hold finished: revert to open with remembered files
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "flagsChanged.secondHoldRevert", modifiers: modifiers, oldState: oldState, newState: state)
            } else {
                let elapsed = timestamp - startedAt
                if elapsed >= holdDurationSeconds - 0.0005 {
                    let oldState = state
                    rememberedFiles = newFiles
                    state = .open(openedAt: timestamp, files: newFiles, location: loc, isAdvanced: false)
                    logTransition(event: "flagsChanged.secondHoldReplacedFiles", modifiers: modifiers, oldState: oldState, newState: state)
                    onFilesReplaced?(newFiles)
                }
            }

        case .idle:
            break
        }
    }

    /// Process key down events (Esc cancels, other keys cancel charging)
    public func processKeyDown(keyCode: UInt16, timestamp: TimeInterval) {
        switch state {
        case .armed, .charging:
            // Any other key pressed during charging cancels
            cancelCharging(reason: "Key pressed during charging (code: \(keyCode))")

        case .open, .secondHoldArmed:
            if keyCode == 53 { // ESC key
                closeWheel(reason: "Esc key pressed")
            }

        case .idle:
            break
        }
    }

    /// Process mouse up (drop outside or drag ending)
    public func processMouseUp(timestamp: TimeInterval) {
        switch state {
        case .armed, .charging:
            cancelCharging(reason: "Mouse up during charging")

        case .open:
            // STICKY WHEEL: Dropping outside or ending the drag does NOT close the wheel!
            // It remains open until Esc or Close control, unless stayOpenAfterRelease is turned off.
            if !preferences.stayOpenAfterRelease {
                closeWheel(reason: "Mouse up and stayOpenAfterRelease is false")
            } else {
                logTransition(event: "mouseUp.openPreserved", oldState: state, newState: state, reason: "Sticky wheel preserved after mouseUp per stayOpenAfterRelease")
            }

        case .secondHoldArmed(let startedAt, _, let loc):
            // Dropping during an incomplete second hold preserves the open wheel with original files
            let oldState = state
            state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
            logTransition(event: "mouseUp.secondHoldRevert", oldState: oldState, newState: state)

        case .idle:
            break
        }
    }

    // MARK: - Actions

    private func cancelCharging(reason: String = "Cancelled") {
        let oldState = state
        state = .idle
        optionKeyDownTimestamp = nil
        logTransition(event: "cancelCharging", oldState: oldState, newState: .idle, reason: reason)
        onChargingCancel?()
    }

    private func openWheel(openedAt: TimeInterval, files: [URL], location: NSPoint, isAdvanced: Bool) {
        let oldState = state
        rememberedFiles = files
        state = .open(openedAt: openedAt, files: files, location: location, isAdvanced: isAdvanced)
        optionKeyDownTimestamp = nil
        logTransition(event: "openWheel", location: location, oldState: oldState, newState: state)
        PastaLogger.shared.info("DragMonitor opened wheel with \(files.count) files at (\(location.x), \(location.y)), isAdvanced: \(isAdvanced)")
        onChargingCancel?() // Dismiss ring
        onWheelOpen?(files, isAdvanced, location)
    }

    public func openWheelManually(location: NSPoint? = nil) {
        let loc = location ?? NSEvent.mouseLocation
        let files = pasteboardReader.extractFileURLs()
        openWheel(openedAt: clock.now, files: files, location: loc, isAdvanced: false)
    }

    public func closeWheel(reason: String = "User requested close") {
        let oldState = state
        state = .idle
        rememberedFiles.removeAll()
        optionKeyDownTimestamp = nil
        logTransition(event: "closeWheel", oldState: oldState, newState: .idle, reason: reason)
        PastaLogger.shared.info("DragMonitor closeWheel triggered: \(reason)")
        onChargingCancel?()
        onWheelClose?()
    }

    public func actionExecuted() {
        PastaLogger.shared.info("DragMonitor actionExecuted. keepWheelOpenAfterRunning: \(preferences.keepWheelOpenAfterRunning)")
        if !preferences.keepWheelOpenAfterRunning {
            closeWheel(reason: "Action executed and keepWheelOpenAfterRunning is false")
        } else {
            // Keep wheel open!
            logTransition(event: "actionExecuted", oldState: state, newState: state, reason: "Kept open per preference")
        }
    }

    // MARK: - Live System Monitoring

    public func startMonitoring() {
        stopMonitoring()

        // Global monitors (when other apps/Finder are active)
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self = self else { return }
            self.processMouseDragged(
                modifiers: event.modifierFlags,
                location: NSEvent.mouseLocation,
                timestamp: event.timestamp
            )
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return }
            self.processMouseUp(timestamp: event.timestamp)
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            self.processFlagsChanged(modifiers: event.modifierFlags, timestamp: event.timestamp)
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            self.processKeyDown(keyCode: event.keyCode, timestamp: event.timestamp)
        }
        if globalKeyDownMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalKeyDownMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }

        // Local monitors (when Pasta is active)
        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self = self else { return event }
            self.processMouseDragged(
                modifiers: event.modifierFlags,
                location: NSEvent.mouseLocation,
                timestamp: event.timestamp
            )
            return event
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return event }
            self.processMouseUp(timestamp: event.timestamp)
            return event
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            self.processFlagsChanged(modifiers: event.modifierFlags, timestamp: event.timestamp)
            return event
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            self.processKeyDown(keyCode: event.keyCode, timestamp: event.timestamp)
            return event
        }
    }

    public func stopMonitoring() {
        if let gdm = globalDragMonitor { NSEvent.removeMonitor(gdm); globalDragMonitor = nil }
        if let gmu = globalMouseUpMonitor { NSEvent.removeMonitor(gmu); globalMouseUpMonitor = nil }
        if let gfm = globalFlagsMonitor { NSEvent.removeMonitor(gfm); globalFlagsMonitor = nil }
        if let gkd = globalKeyDownMonitor { NSEvent.removeMonitor(gkd); globalKeyDownMonitor = nil }

        if let ldm = localDragMonitor { NSEvent.removeMonitor(ldm); localDragMonitor = nil }
        if let lmu = localMouseUpMonitor { NSEvent.removeMonitor(lmu); localMouseUpMonitor = nil }
        if let lfm = localFlagsMonitor { NSEvent.removeMonitor(lfm); localFlagsMonitor = nil }
        if let lkd = localKeyDownMonitor { NSEvent.removeMonitor(lkd); localKeyDownMonitor = nil }
    }
}
