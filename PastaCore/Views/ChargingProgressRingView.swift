import Foundation
import AppKit
import QuartzCore

public final class ChargingProgressRingView: NSView {
    private var progressLayer = CAShapeLayer()
    private var trackLayer = CAShapeLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        setupLayers()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        wantsLayer = true

        let center = CGPoint(x: 22, y: 22)
        let radius: CGFloat = 16.0
        let startAngle = -CGFloat.pi / 2.0
        let endAngle = startAngle + (2.0 * CGFloat.pi)

        let path = CGMutablePath()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Faint background track
        trackLayer.path = path
        trackLayer.fillColor = NSColor.clear.cgColor
        trackLayer.strokeColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        trackLayer.lineWidth = 2.0
        trackLayer.lineCap = .round
        layer?.addSublayer(trackLayer)

        // Progress ring
        let accent = ThemeManager.shared.accentColor
        progressLayer.path = path
        progressLayer.fillColor = NSColor.clear.cgColor
        progressLayer.strokeColor = accent.cgColor
        progressLayer.lineWidth = 2.0
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.0
        progressLayer.shadowColor = accent.cgColor
        progressLayer.shadowOpacity = 0.6
        progressLayer.shadowRadius = 4.0
        progressLayer.shadowOffset = .zero
        layer?.addSublayer(progressLayer)
    }

    public func setProgress(_ progress: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = CGFloat(min(max(progress, 0.0), 1.0))
        CATransaction.commit()
    }

    public func updateAccentColor() {
        let accent = ThemeManager.shared.accentColor
        progressLayer.strokeColor = accent.cgColor
        progressLayer.shadowColor = accent.cgColor
    }
}

public final class ChargingProgressRingPanel: NSPanel {
    public static let shared = ChargingProgressRingPanel()

    private let ringView = ChargingProgressRingView()

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 44, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ringView
    }

    public func show(at location: NSPoint, progress: Double) {
        ringView.updateAccentColor()
        ringView.setProgress(progress)

        let ringSize = NSSize(width: 44, height: 44)
        setContentSize(ringSize)
        setFrameOrigin(NSPoint(x: location.x - 22, y: location.y - 22))

        if !isVisible {
            alphaValue = 0.0
            orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                animator().alphaValue = 1.0
            }
        }
    }

    public func dismiss() {
        if isVisible {
            orderOut(nil)
            alphaValue = 0.0
            ringView.setProgress(0.0)
        }
    }
}
