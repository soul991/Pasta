import Foundation
import AppKit

public final class DragOverlayPanel: NSPanel {
    private let overlayViewController = DragOverlayViewController()

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentViewController = overlayViewController

        overlayViewController.onCloseRequested = { [weak self] in
            self?.dismiss()
        }
    }

    public func showNear(point: NSPoint, files: [URL], isOptionHeld: Bool) {
        overlayViewController.configure(files: files, isOptionHeld: isOptionHeld)

        let size = overlayViewController.view.fittingSize
        setContentSize(size)

        // Center the panel slightly offset from the cursor so it does not block the drag drop target immediately
        var origin = NSPoint(x: point.x + 20, y: point.y - (size.height / 2))

        // Keep within active screen bounds
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            if origin.x + size.width > visible.maxX {
                origin.x = point.x - size.width - 20
            }
            if origin.y < visible.minY {
                origin.y = visible.minY + 20
            }
            if origin.y + size.height > visible.maxY {
                origin.y = visible.maxY - size.height - 20
            }
        }

        setFrameOrigin(origin)

        alphaValue = 0.0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1.0
        }
    }

    public func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1.0
        })
    }
}
