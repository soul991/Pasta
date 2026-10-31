import Foundation
import AppKit

public final class RadialWheelOverlayPanel: NSPanel {
    private let wheelViewController = RadialWheelOverlayViewController()

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentViewController = wheelViewController

        wheelViewController.onCloseRequested = { [weak self] in
            self?.dismiss()
        }
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public func toggleMode(isAdvanced: Bool) {
        wheelViewController.toggleMode(isAdvanced: isAdvanced)
    }

    public func showCenteredAt(point: NSPoint, files: [URL], isOptionHeld: Bool) {
        wheelViewController.configure(files: files, isOptionHeld: isOptionHeld)

        let panelSize = NSSize(width: 440, height: 480)
        setContentSize(panelSize)

        // Center wheel center (220, 250) directly over the cursor point
        var origin = NSPoint(x: point.x - 220, y: point.y - 250)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            if origin.x < visible.minX + 10 {
                origin.x = visible.minX + 10
            }
            if origin.x + panelSize.width > visible.maxX - 10 {
                origin.x = visible.maxX - panelSize.width - 10
            }
            if origin.y < visible.minY + 10 {
                origin.y = visible.minY + 10
            }
            if origin.y + panelSize.height > visible.maxY - 10 {
                origin.y = visible.maxY - panelSize.height - 10
            }
        }

        setFrameOrigin(origin)

        alphaValue = 0.0
        orderFront(nil)

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled
        if !isReduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                animator().alphaValue = 1.0
            }
        } else {
            alphaValue = 1.0
        }
    }

    public func dismiss() {
        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled
        if !isReduceMotion {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
                self?.alphaValue = 1.0
            })
        } else {
            orderOut(nil)
            alphaValue = 1.0
        }
    }
}
