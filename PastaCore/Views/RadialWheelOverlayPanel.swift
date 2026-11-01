import Foundation
import AppKit

public final class RadialWheelOverlayPanel: NSPanel {
    private let wheelViewController = RadialWheelOverlayViewController()

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: WheelGeometry.panelWidth, height: WheelGeometry.panelHeight),
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
        contentView?.wantsLayer = true
        contentView?.layer?.masksToBounds = false

        wheelViewController.onCloseRequested = {
            DragMonitor.shared.closeWheel(reason: "Panel view controller requested close")
        }
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public func configure(files: [URL]) {
        wheelViewController.configure(files: files, isOptionHeld: false)
    }

    public func toggleMode(isAdvanced: Bool) {
        wheelViewController.toggleMode(isAdvanced: isAdvanced)
    }

    public func showCenteredAt(point: NSPoint, files: [URL], isOptionHeld: Bool) {
        wheelViewController.configure(files: files, isOptionHeld: isOptionHeld)

        let panelSize = NSSize(width: WheelGeometry.panelWidth, height: WheelGeometry.panelHeight)
        setContentSize(panelSize)

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let origin = WheelGeometry.computePanelOrigin(
            cursorPoint: point,
            panelSize: panelSize,
            centerOffset: NSPoint(x: WheelGeometry.wheelCenterX, y: WheelGeometry.wheelCenterY),
            visibleFrame: visibleFrame,
            edgeMargin: 10.0
        )

        setFrameOrigin(origin)

        let isCramped = WheelGeometry.isBottomCramped(panelOrigin: origin, visibleFrame: visibleFrame)
        wheelViewController.setHintPillPlacement(aboveWheel: isCramped)

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
        wheelViewController.cancelAutoDismiss()
        wheelViewController.dismissCustomizeSheet(animated: false)
        wheelViewController.dismissMoreView()
        wheelViewController.dismissParameterPanel(animated: false)

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
