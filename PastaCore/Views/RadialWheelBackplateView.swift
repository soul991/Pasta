import Foundation
import AppKit
import QuartzCore

public final class RadialWheelBackplateView: NSView {
    public var outerDiameter: CGFloat = 400.0 {
        didSet { needsDisplay = true }
    }
    public var hubDiameter: CGFloat = 128.0 {
        didSet { needsDisplay = true }
    }

    /// Slot index currently hovered (0..<8) to draw connecting wedge, or nil
    public var hoveredSlotIndex: Int? = nil {
        didSet {
            if oldValue != hoveredSlotIndex {
                needsDisplay = true
            }
        }
    }

    private let visualEffect = NSVisualEffectView()

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateAnnulusMask()
    }

    public override func layout() {
        super.layout()
        updateAnnulusMask()
    }

    private func updateAnnulusMask() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = outerDiameter / 2.0
        let innerR = hubDiameter / 2.0

        let path = CGMutablePath()
        path.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)

        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        maskLayer.fillRule = .evenOdd
        visualEffect.layer?.mask = maskLayer
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = outerDiameter / 2.0
        let innerR = hubDiameter / 2.0

        // 1. Draw Connecting Wedge when a node is hovered (accent @ 0.12 alpha)
        if let slot = hoveredSlotIndex {
            let totalSlots = 8
            let slotAngle = (-CGFloat.pi / 2.0) + (CGFloat(slot) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))
            let halfWedge = (2.0 * CGFloat.pi / CGFloat(totalSlots)) / 2.0

            let wedgePath = CGMutablePath()
            wedgePath.addArc(center: center, radius: outerR - 4.0, startAngle: slotAngle - halfWedge, endAngle: slotAngle + halfWedge, clockwise: false)
            wedgePath.addArc(center: center, radius: innerR + 2.0, startAngle: slotAngle + halfWedge, endAngle: slotAngle - halfWedge, clockwise: true)
            wedgePath.closeSubpath()

            context.saveGState()
            context.addPath(wedgePath)
            let accent = ThemeManager.shared.accentColor.withAlphaComponent(0.12).cgColor
            context.setFillColor(accent)
            context.fillPath()
            context.restoreGState()
        }

        // 2. Outer Annulus 1pt Hairline Gradient Stroke
        // Top-left white 0.45 to bottom-right white 0.08
        context.saveGState()
        let outerCirclePath = CGPath(
            ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerDiameter, height: outerDiameter),
            transform: nil
        )
        context.addPath(outerCirclePath)
        context.setLineWidth(1.0)
        context.replacePathWithStrokedPath()
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [
            NSColor(white: 1.0, alpha: 0.45).cgColor,
            NSColor(white: 1.0, alpha: 0.08).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0]) {
            let startPoint = CGPoint(x: center.x - outerR, y: center.y + outerR)
            let endPoint = CGPoint(x: center.x + outerR, y: center.y - outerR)
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        context.restoreGState()

        // 3. Inner Hub 1pt Hairline Stroke (soft border around center disc)
        context.saveGState()
        let innerCirclePath = CGPath(
            ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: hubDiameter, height: hubDiameter),
            transform: nil
        )
        context.addPath(innerCirclePath)
        context.setLineWidth(1.0)
        context.setStrokeColor(NSColor(white: 1.0, alpha: 0.20).cgColor)
        context.strokePath()
        context.restoreGState()
    }
}
