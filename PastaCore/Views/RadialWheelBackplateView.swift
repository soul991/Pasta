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

        // 0. Reduce Transparency: Draw opaque dark background if enabled
        if ThemeManager.shared.isReduceTransparency {
            let annulusPath = CGMutablePath()
            annulusPath.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
            annulusPath.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)
            context.saveGState()
            context.addPath(annulusPath)
            context.setFillColor(ThemeManager.shared.reduceTransparencyBackground.cgColor)
            context.fillPath(using: .evenOdd)
            context.restoreGState()
        }

        // 1. Faint Top Sheen Gradient (white 0.12 to 0.0)
        if !ThemeManager.shared.isReduceTransparency {
            context.saveGState()
            let sheenRect = CGRect(x: center.x - outerR, y: center.y, width: outerDiameter, height: outerR)
            let annulusPath = CGMutablePath()
            annulusPath.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
            annulusPath.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)
            context.addPath(annulusPath)
            context.clip(using: .evenOdd)
            context.clip(to: sheenRect)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let sheenColors = [
                ThemeManager.shared.sheenTopColor.cgColor,
                NSColor(white: 1.0, alpha: 0.0).cgColor
            ] as CFArray
            if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
                context.drawLinearGradient(sheenGrad, start: CGPoint(x: center.x, y: center.y + outerR), end: CGPoint(x: center.x, y: center.y), options: [])
            }
            context.restoreGState()
        }

        // 2. Soft Inner Shadow around outer rim
        context.saveGState()
        let innerShadowPath = CGMutablePath()
        innerShadowPath.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        innerShadowPath.addArc(center: center, radius: outerR - 4.0, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)
        context.addPath(innerShadowPath)
        context.setFillColor(NSColor(white: 0.0, alpha: 0.15).cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()

        // 3. Draw Connecting Wedge when a node is hovered (accent @ 0.12 alpha)
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

        // 4. Outer Annulus 1pt Hairline Gradient Stroke (or 2.0pt in Increase Contrast)
        // Top-left white 0.45 to bottom-right white 0.08
        let isHighContrast = ThemeManager.shared.isIncreaseContrast
        let strokeWidth: CGFloat = isHighContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.0

        context.saveGState()
        let outerCirclePath = CGPath(
            ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerDiameter, height: outerDiameter),
            transform: nil
        )
        context.addPath(outerCirclePath)
        context.setLineWidth(strokeWidth)
        context.replacePathWithStrokedPath()
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = isHighContrast ? [
            ThemeManager.shared.increaseContrastBorderColor.cgColor,
            ThemeManager.shared.increaseContrastBorderColor.cgColor
        ] as CFArray : [
            ThemeManager.shared.specularTopLeftColor.cgColor,
            ThemeManager.shared.specularBottomRightColor.cgColor
        ] as CFArray

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0]) {
            let startPoint = CGPoint(x: center.x - outerR, y: center.y + outerR)
            let endPoint = CGPoint(x: center.x + outerR, y: center.y - outerR)
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        context.restoreGState()

        // 5. Inner Hub 1pt Hairline Stroke (soft border around center disc)
        context.saveGState()
        let innerCirclePath = CGPath(
            ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: hubDiameter, height: hubDiameter),
            transform: nil
        )
        context.addPath(innerCirclePath)
        context.setLineWidth(strokeWidth)
        let innerStrokeColor = isHighContrast ?
            ThemeManager.shared.increaseContrastBorderColor.cgColor :
            NSColor(white: 1.0, alpha: 0.20).cgColor
        context.setStrokeColor(innerStrokeColor)
        context.strokePath()
        context.restoreGState()
    }
}
