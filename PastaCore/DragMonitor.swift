import Foundation
import AppKit

public final class DragMonitor {
    public static let shared = DragMonitor()

    public var onDragStart: (([URL], Bool, NSPoint) -> Void)?
    public var onDragEnd: (() -> Void)?

    private var globalDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalFlagsMonitor: Any?

    private var localDragMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localFlagsMonitor: Any?

    private var lastChangeCount: Int = -1
    private var isOverlayActive: Bool = false

    public init() {}

    public static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func startMonitoring() {
        stopMonitoring()

        // 1. Global event monitors (when Finder or other app is active)
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.handleMouseUp()
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // 2. Local event monitors (when Pasta is active)
        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
            return event
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp()
            return event
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    public func stopMonitoring() {
        if let gdm = globalDragMonitor { NSEvent.removeMonitor(gdm); globalDragMonitor = nil }
        if let gmu = globalMouseUpMonitor { NSEvent.removeMonitor(gmu); globalMouseUpMonitor = nil }
        if let gfm = globalFlagsMonitor { NSEvent.removeMonitor(gfm); globalFlagsMonitor = nil }

        if let ldm = localDragMonitor { NSEvent.removeMonitor(ldm); localDragMonitor = nil }
        if let lmu = localMouseUpMonitor { NSEvent.removeMonitor(lmu); localMouseUpMonitor = nil }
        if let lfm = localFlagsMonitor { NSEvent.removeMonitor(lfm); localFlagsMonitor = nil }
    }

    private func handleMouseDragged(_ event: NSEvent) {
        let isShiftHeld = event.modifierFlags.contains(.shift)
        let isOptionHeld = event.modifierFlags.contains(.option)

        guard isShiftHeld else {
            // Shift is not held; if overlay is visible, dismiss
            if isOverlayActive {
                isOverlayActive = false
                onDragEnd?()
            }
            return
        }

        // Read the system drag pasteboard
        let pboard = NSPasteboard(name: .drag)
        let currentChangeCount = pboard.changeCount

        // Extract valid file URLs from pasteboard
        guard let items = pboard.pasteboardItems, !items.isEmpty else {
            return
        }

        var validURLs: [URL] = []
        for item in items {
            if let str = item.string(forType: .fileURL), let url = URL(string: str) {
                if FileManager.default.fileExists(atPath: url.path) {
                    validURLs.append(url)
                }
            }
        }

        guard !validURLs.isEmpty else {
            return
        }

        // Verify this is a real active drag session, not an empty marquee drag
        let mouseLoc = NSEvent.mouseLocation

        if !isOverlayActive {
            isOverlayActive = true
            lastChangeCount = currentChangeCount
            onDragStart?(validURLs, isOptionHeld, mouseLoc)
        }
    }

    private func handleMouseUp() {
        if isOverlayActive {
            // Delay slightly so any ongoing drop operation completes before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.isOverlayActive = false
                self.onDragEnd?()
            }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isShiftHeld = event.modifierFlags.contains(.shift)
        if !isShiftHeld && isOverlayActive {
            // When Shift key is released, dismiss overlay
            isOverlayActive = false
            onDragEnd?()
        }
    }
}
