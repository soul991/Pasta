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

// MARK: - Mouse State Provider Protocol
public protocol MouseStateProvider {
    var isLeftButtonDown: Bool { get }
}

public struct SystemMouseStateProvider: MouseStateProvider {
    public init() {}
    public var isLeftButtonDown: Bool {
        return (NSEvent.pressedMouseButtons & 1) != 0
    }
}

public final class MockMouseStateProvider: MouseStateProvider {
    public var isLeftButtonDown: Bool

    public init(isLeftButtonDown: Bool = false) {
        self.isLeftButtonDown = isLeftButtonDown
    }
}

// MARK: - Pasteboard Reader Protocol
public protocol DragPasteboardReader {
    var changeCount: Int { get }
    func extractFileURLs() -> [URL]
}

public struct SystemDragPasteboardReader: DragPasteboardReader {
    public init() {}

    public var changeCount: Int {
        return NSPasteboard(name: .drag).changeCount
    }

    public func extractFileURLs() -> [URL] {
        let pboard = NSPasteboard(name: .drag)

        // 1. Try reading NSURLs directly from the drag pasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let valid = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !valid.isEmpty {
                return valid
            }
        }

        // 2. Try pasteboardItems with .fileURL
        if let items = pboard.pasteboardItems, !items.isEmpty {
            var validURLs: [URL] = []
            for item in items {
                if let str = item.string(forType: .fileURL), let url = URL(string: str) {
                    if FileManager.default.fileExists(atPath: url.path) {
                        validURLs.append(url)
                    }
                }
            }
            if !validURLs.isEmpty {
                return validURLs
            }
        }

        // 3. Try propertyList for NSFilenamesPboardType
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let filenames = pboard.propertyList(forType: filenamesType) as? [String] {
            let urls = filenames.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty {
                return urls
            }
        }

        return []
    }
}

public final class MockDragPasteboardReader: DragPasteboardReader {
    public var mockURLs: [URL]
    public var changeCount: Int

    public init(urls: [URL] = [], changeCount: Int = 0) {
        self.mockURLs = urls
        self.changeCount = changeCount
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
    public var onEscIntercepted: (() -> Bool)?
    public var onKeyDownIntercepted: ((UInt16) -> Bool)?

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
    public var mouseStateProvider: MouseStateProvider

    // Current internal state
    public private(set) var state: State = .idle
    private var _dragSessionActive: Bool = false
    public var dragSessionActive: Bool {
        get {
            return _dragSessionActive && mouseStateProvider.isLeftButtonDown
        }
        set {
            _dragSessionActive = newValue
        }
    }
    public private(set) var dragPasteboardBaselineChangeCount: Int = 0

    // Sticky context: files remembered while wheel remains open
    public private(set) var rememberedFiles: [URL] = []

    // Option tap tracking
    private var optionKeyDownTimestamp: TimeInterval?

    // System event monitors
    private var globalMouseDownMonitor: Any?
    private var globalDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?

    private var localMouseDownMonitor: Any?
    private var localDragMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyDownMonitor: Any?

    // Active timer to advance charging state when mouse is stationary
    private var chargingTimer: Timer?

    public var isChargingTimerRunning: Bool {
        return chargingTimer != nil
    }

    private func startChargingTimer() {
        stopChargingTimer()
        guard clock is SystemDragMonitorClock else { return }
        let timer = Timer(timeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.tickCharging()
        }
        RunLoop.main.add(timer, forMode: .common)
        chargingTimer = timer
    }

    private func stopChargingTimer() {
        chargingTimer?.invalidate()
        chargingTimer = nil
    }

    public func tickCharging(now: TimeInterval? = nil) {
        if !mouseStateProvider.isLeftButtonDown {
            dragSessionActive = false
        }

        // Stop charging immediately if mouse button released or dragSession no longer active
        guard mouseStateProvider.isLeftButtonDown && dragSessionActive else {
            stopChargingTimer()
            switch state {
            case .armed, .charging:
                cancelCharging(reason: "Mouse button released or dragSession inactive during charging")
            case .secondHoldArmed(let startedAt, _, let loc):
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "timer.secondHoldRevertMouseUp", oldState: oldState, newState: state)
            default:
                break
            }
            return
        }

        let currentNow = now ?? clock.now
        switch state {
        case .armed(let startedAt, let files, let location):
            let elapsed = currentNow - startedAt
            let duration = holdDurationSeconds
            if elapsed >= duration - 0.0005 {
                stopChargingTimer()
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(1.0, location)
                }
                openWheel(openedAt: currentNow, files: files, location: location, isAdvanced: false)
            } else if elapsed >= 0.120 {
                let oldState = state
                state = .charging(startedAt: startedAt, files: files, location: location)
                logTransition(event: "timer.charging", location: location, oldState: oldState, newState: state)
                let ringProgress = min(max(elapsed / duration, 0.0), 1.0)
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(ringProgress, location)
                }
            }
        case .charging(let startedAt, let files, let location):
            let elapsed = currentNow - startedAt
            let duration = holdDurationSeconds
            if elapsed >= duration - 0.0005 {
                stopChargingTimer()
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(1.0, location)
                }
                openWheel(openedAt: currentNow, files: files, location: location, isAdvanced: false)
            } else {
                let ringProgress = min(max(elapsed / duration, 0.0), 1.0)
                if preferences.showChargingRing && !preferences.reduceMotionEnabled {
                    onChargingProgress?(ringProgress, location)
                }
            }
        case .secondHoldArmed(let startedAt, let newFiles, let location):
            let elapsed = currentNow - startedAt
            if elapsed >= holdDurationSeconds - 0.0005 {
                stopChargingTimer()
                let oldState = state
                rememberedFiles = newFiles
                state = .open(openedAt: currentNow, files: newFiles, location: location, isAdvanced: false)
                logTransition(event: "timer.secondHoldReplacedFiles", location: location, oldState: oldState, newState: state)
                onFilesReplaced?(newFiles)
            }
        default:
            stopChargingTimer()
        }
    }

    public init(
        clock: DragMonitorClock = SystemDragMonitorClock(),
        pasteboardReader: DragPasteboardReader = SystemDragPasteboardReader(),
        preferences: PreferencesManager = PreferencesManager.shared,
        mouseStateProvider: MouseStateProvider = SystemMouseStateProvider()
    ) {
        self.clock = clock
        self.pasteboardReader = pasteboardReader
        self.preferences = preferences
        self.mouseStateProvider = mouseStateProvider
        self.dragPasteboardBaselineChangeCount = pasteboardReader.changeCount
        self.dragSessionActive = false
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

    public var isArmed: Bool {
        if case .armed = state { return true }
        return false
    }

    public var isCharging: Bool {
        if case .charging = state { return true }
        return false
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

    private func logArmingDecision(
        allowed: Bool,
        source: String,
        baseline: Int,
        current: Int,
        buttonDown: Bool,
        sessionActive: Bool,
        reason: String
    ) {
        let status = allowed ? "ALLOWED" : "REJECTED"
        PastaLogger.shared.info(
            "DragMonitor arming \(status) [\(source)]: baseline=\(baseline), current=\(current), buttonDown=\(buttonDown), sessionActive=\(sessionActive), reason=\(reason)"
        )
    }

    // MARK: - Public State Machine Processing (Unit Testable)

    /// Process left mouse down event
    public func processMouseDown(timestamp: TimeInterval) {
        let currentChange = pasteboardReader.changeCount
        dragPasteboardBaselineChangeCount = currentChange
        dragSessionActive = false
        PastaLogger.shared.debug("DragMonitor [\(clock.now)] mouseDown: baselineChangeCount=\(currentChange)")
    }

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

        let isLeftDown = mouseStateProvider.isLeftButtonDown
        let currentChange = pasteboardReader.changeCount

        // Rule: Any other modifier during charging cancels
        if hasOtherModifiers {
            if isShiftHeld && state == .idle {
                logArmingDecision(
                    allowed: false,
                    source: "mouseDragged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Cancel modifier present (Control or Command)"
                )
            }
            if case .armed = state { cancelCharging(reason: "Cancel modifier during armed") }
            if case .charging = state { cancelCharging(reason: "Cancel modifier during charging") }
            return
        }

        // 1. Detect drag session activation during mouse drag:
        // A drag began after the latest mouseDown: during leftMouseDragged, the changeCount differs from that baseline
        // AND the drag pasteboard contains file URLs.
        var detectedFiles: [URL]? = nil
        if isLeftDown && !dragSessionActive {
            if currentChange != dragPasteboardBaselineChangeCount {
                let files = pasteboardReader.extractFileURLs()
                if !files.isEmpty {
                    dragSessionActive = true
                    detectedFiles = files
                    PastaLogger.shared.info("DragMonitor drag session activated: baseline=\(dragPasteboardBaselineChangeCount), current=\(currentChange), filesCount=\(files.count)")
                }
            }
        }

        switch state {
        case .idle:
            guard isShiftHeld else { return }

            guard isLeftDown else {
                logArmingDecision(
                    allowed: false,
                    source: "mouseDragged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Left mouse button is not down"
                )
                return
            }

            guard dragSessionActive else {
                logArmingDecision(
                    allowed: false,
                    source: "mouseDragged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Drag session is not active (changeCount unchanged from baseline or non-file drag)"
                )
                return
            }

            // Both isLeftDown and dragSessionActive are true!
            // Never read file URLs from the drag pasteboard for arming unless dragSessionActive is true.
            let files = detectedFiles ?? pasteboardReader.extractFileURLs()
            guard !files.isEmpty else {
                logArmingDecision(
                    allowed: false,
                    source: "mouseDragged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Drag pasteboard contains no file URLs"
                )
                return
            }

            let oldState = state
            state = .armed(startedAt: timestamp, files: files, location: location)
            logArmingDecision(
                allowed: true,
                source: "mouseDragged.idle",
                baseline: dragPasteboardBaselineChangeCount,
                current: currentChange,
                buttonDown: isLeftDown,
                sessionActive: dragSessionActive,
                reason: "Valid drag session with Shift held"
            )
            logTransition(event: "mouseDragged.armed", modifiers: modifiers, location: location, oldState: oldState, newState: state)
            startChargingTimer()

        case .armed(let startedAt, let files, _):
            guard isLeftDown && dragSessionActive else {
                cancelCharging(reason: "Mouse button released or drag session ended during armed")
                return
            }
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
            guard isLeftDown && dragSessionActive else {
                cancelCharging(reason: "Mouse button released or drag session ended during charging")
                return
            }
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
                guard isLeftDown && dragSessionActive else {
                    logArmingDecision(
                        allowed: false,
                        source: "mouseDragged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: mouse button not down or dragSession not active"
                    )
                    return
                }

                let newFiles = pasteboardReader.extractFileURLs()
                if newFiles.isEmpty {
                    logArmingDecision(
                        allowed: false,
                        source: "mouseDragged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: drag pasteboard contains no file URLs"
                    )
                } else if newFiles == currentFiles {
                    logArmingDecision(
                        allowed: false,
                        source: "mouseDragged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: files identical to currently open wheel"
                    )
                } else {
                    let oldState = state
                    state = .secondHoldArmed(startedAt: timestamp, files: newFiles, location: location)
                    logArmingDecision(
                        allowed: true,
                        source: "mouseDragged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "New real drag re-targeting sticky wheel"
                    )
                    logTransition(event: "mouseDragged.startSecondHold", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                    startChargingTimer()
                }
            }

        case .secondHoldArmed(let startedAt, let newFiles, let loc):
            guard isLeftDown && dragSessionActive else {
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "mouseDragged.secondHoldRevert", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                stopChargingTimer()
                return
            }
            guard isShiftHeld else {
                // Shift released before second hold threshold:
                // Revert to open state with current remembered files. Does NOT close wheel!
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "mouseDragged.secondHoldRevert", modifiers: modifiers, location: location, oldState: oldState, newState: state)
                stopChargingTimer()
                return
            }

            let elapsed = timestamp - startedAt
            if elapsed >= holdDurationSeconds - 0.0005 {
                stopChargingTimer()
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

        let isLeftDown = mouseStateProvider.isLeftButtonDown
        let currentChange = pasteboardReader.changeCount

        if hasCancelModifiers {
            if isShiftHeld && state == .idle {
                logArmingDecision(
                    allowed: false,
                    source: "flagsChanged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Cancel modifier present (Control or Command)"
                )
            }
            if case .armed = state { cancelCharging(reason: "Cancel modifier during armed") }
            if case .charging = state { cancelCharging(reason: "Cancel modifier during charging") }
            return
        }

        switch state {
        case .armed, .charging:
            if !isShiftHeld {
                // Shift released before threshold: cancel charging!
                cancelCharging(reason: "Shift released before opening")
            } else if !isLeftDown || !dragSessionActive {
                cancelCharging(reason: "Mouse button released or dragSession ended during charging")
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
                guard isLeftDown && dragSessionActive else {
                    logArmingDecision(
                        allowed: false,
                        source: "flagsChanged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: mouse button not down or dragSession not active"
                    )
                    return
                }

                let newFiles = pasteboardReader.extractFileURLs()
                if newFiles.isEmpty {
                    logArmingDecision(
                        allowed: false,
                        source: "flagsChanged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: drag pasteboard contains no file URLs"
                    )
                } else if newFiles == files {
                    logArmingDecision(
                        allowed: false,
                        source: "flagsChanged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "Re-targeting rejected: files identical to currently open wheel"
                    )
                } else {
                    let oldState = state
                    state = .secondHoldArmed(startedAt: timestamp, files: newFiles, location: loc)
                    logArmingDecision(
                        allowed: true,
                        source: "flagsChanged.secondHold",
                        baseline: dragPasteboardBaselineChangeCount,
                        current: currentChange,
                        buttonDown: isLeftDown,
                        sessionActive: dragSessionActive,
                        reason: "New real drag re-targeting sticky wheel via flagsChanged"
                    )
                    logTransition(event: "flagsChanged.secondHoldArmed", modifiers: modifiers, oldState: oldState, newState: state)
                    startChargingTimer()
                }
            }

        case .secondHoldArmed(let startedAt, let newFiles, let loc):
            if !isShiftHeld || !isLeftDown || !dragSessionActive {
                // Shift released or mouse up before second hold finished: revert to open with remembered files
                let oldState = state
                state = .open(openedAt: startedAt, files: rememberedFiles, location: loc, isAdvanced: false)
                logTransition(event: "flagsChanged.secondHoldRevert", modifiers: modifiers, oldState: oldState, newState: state)
                stopChargingTimer()
            } else {
                let elapsed = timestamp - startedAt
                if elapsed >= holdDurationSeconds - 0.0005 {
                    stopChargingTimer()
                    let oldState = state
                    rememberedFiles = newFiles
                    state = .open(openedAt: timestamp, files: newFiles, location: loc, isAdvanced: false)
                    logTransition(event: "flagsChanged.secondHoldReplacedFiles", modifiers: modifiers, oldState: oldState, newState: state)
                    onFilesReplaced?(newFiles)
                }
            }

        case .idle:
            guard isShiftHeld else { break }

            guard isLeftDown else {
                logArmingDecision(
                    allowed: false,
                    source: "flagsChanged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Left mouse button is not down"
                )
                break
            }

            guard dragSessionActive else {
                logArmingDecision(
                    allowed: false,
                    source: "flagsChanged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Drag session is not active"
                )
                break
            }

            // Both isLeftDown and dragSessionActive are true!
            // The idle Shift path (stationary hold) is allowed only when dragSessionActive and the mouse button is still down.
            // Never read file URLs from the drag pasteboard for arming unless dragSessionActive is true.
            let files = pasteboardReader.extractFileURLs()
            guard !files.isEmpty else {
                logArmingDecision(
                    allowed: false,
                    source: "flagsChanged.idle",
                    baseline: dragPasteboardBaselineChangeCount,
                    current: currentChange,
                    buttonDown: isLeftDown,
                    sessionActive: dragSessionActive,
                    reason: "Drag pasteboard contains no file URLs"
                )
                break
            }

            let location = NSEvent.mouseLocation
            let oldState = state
            state = .armed(startedAt: timestamp, files: files, location: location)
            logArmingDecision(
                allowed: true,
                source: "flagsChanged.idle",
                baseline: dragPasteboardBaselineChangeCount,
                current: currentChange,
                buttonDown: isLeftDown,
                sessionActive: dragSessionActive,
                reason: "Stationary hold with active drag session and button down"
            )
            logTransition(event: "flagsChanged.armed", modifiers: modifiers, location: location, oldState: oldState, newState: state)
            startChargingTimer()
        }
    }

    /// Process key down events (Esc cancels, other keys cancel charging)
    public func processKeyDown(keyCode: UInt16, timestamp: TimeInterval) {
        switch state {
        case .armed, .charging:
            // Any other key pressed during charging cancels
            cancelCharging(reason: "Key pressed during charging (code: \(keyCode))")

        case .open, .secondHoldArmed:
            if let keyInterceptor = onKeyDownIntercepted, keyInterceptor(keyCode) {
                return
            }
            if keyCode == 53 { // ESC key
                if let interceptor = onEscIntercepted, interceptor() {
                    return
                }
                closeWheel(reason: "Esc key pressed")
            }

        case .idle:
            break
        }
    }

    /// Process mouse up (drop outside or drag ending)
    public func processMouseUp(timestamp: TimeInterval) {
        dragSessionActive = false
        stopChargingTimer()
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
        stopChargingTimer()
        let oldState = state
        state = .idle
        optionKeyDownTimestamp = nil
        logTransition(event: "cancelCharging", oldState: oldState, newState: .idle, reason: reason)
        onChargingCancel?()
    }

    private func openWheel(openedAt: TimeInterval, files: [URL], location: NSPoint, isAdvanced: Bool) {
        stopChargingTimer()
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
        stopChargingTimer()
        dragSessionActive = false
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

        // Refresh baseline upon starting monitoring
        dragPasteboardBaselineChangeCount = pasteboardReader.changeCount
        dragSessionActive = false

        // Global monitors (when other apps/Finder are active)
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return }
            self.processMouseDown(timestamp: event.timestamp)
        }

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
        if globalMouseDownMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalMouseDownMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }
        if globalDragMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalDragMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }
        if globalMouseUpMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalMouseUpMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }
        if globalFlagsMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalFlagsMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }
        if globalKeyDownMonitor == nil {
            PastaLogger.shared.warning("DragMonitor: globalKeyDownMonitor returned nil (requires Accessibility / Input Monitoring permission)")
        }

        // Local monitors (when Pasta is active)
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            self.processMouseDown(timestamp: event.timestamp)
            return event
        }

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
        stopChargingTimer()
        dragSessionActive = false
        if let gmd = globalMouseDownMonitor { NSEvent.removeMonitor(gmd); globalMouseDownMonitor = nil }
        if let gdm = globalDragMonitor { NSEvent.removeMonitor(gdm); globalDragMonitor = nil }
        if let gmu = globalMouseUpMonitor { NSEvent.removeMonitor(gmu); globalMouseUpMonitor = nil }
        if let gfm = globalFlagsMonitor { NSEvent.removeMonitor(gfm); globalFlagsMonitor = nil }
        if let gkd = globalKeyDownMonitor { NSEvent.removeMonitor(gkd); globalKeyDownMonitor = nil }

        if let lmd = localMouseDownMonitor { NSEvent.removeMonitor(lmd); localMouseDownMonitor = nil }
        if let ldm = localDragMonitor { NSEvent.removeMonitor(ldm); localDragMonitor = nil }
        if let lmu = localMouseUpMonitor { NSEvent.removeMonitor(lmu); localMouseUpMonitor = nil }
        if let lfm = localFlagsMonitor { NSEvent.removeMonitor(lfm); localFlagsMonitor = nil }
        if let lkd = localKeyDownMonitor { NSEvent.removeMonitor(lkd); localKeyDownMonitor = nil }
    }
}
