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
    private let systemGlass = SystemGlassSurfaceView(cornerRadius: 200, tintColor: NSColor(white: 0.10, alpha: 0.75))

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

        addSubview(systemGlass)
        NSLayoutConstraint.activate([
            systemGlass.leadingAnchor.constraint(equalTo: leadingAnchor),
            systemGlass.trailingAnchor.constraint(equalTo: trailingAnchor),
            systemGlass.topAnchor.constraint(equalTo: topAnchor),
            systemGlass.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        registerForDraggedTypes([.fileURL])

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
        systemGlass.configure(cornerRadius: outerDiameter / 2.0, tintColor: NSColor(white: 0.10, alpha: 0.75), isInteractive: false)
        visualEffect.isHidden = systemGlass.usesSystemGlass
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = outerDiameter / 2.0
        let innerR = hubDiameter / 2.0

        let path = CGMutablePath()
        path.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)

        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        maskLayer.fillRule = .evenOdd
        (systemGlass.usesSystemGlass ? systemGlass.layer : visualEffect.layer)?.mask = maskLayer
        visualEffect.layer?.backgroundColor = (ThemeManager.shared.isReduceTransparency
            ? ThemeManager.shared.reduceTransparencyBackground
            : NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 0.75)).cgColor
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = outerDiameter / 2.0
        let innerR = hubDiameter / 2.0

        // 0. Neutral dark base to eliminate wallpaper color blobs bleeding through
        let annulusPath = CGMutablePath()
        annulusPath.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        annulusPath.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)
        context.saveGState()
        context.addPath(annulusPath)
        let neutralDarkColor = ThemeManager.shared.isReduceTransparency
            ? ThemeManager.shared.reduceTransparencyBackground
            : NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 0.75)
        context.setFillColor(neutralDarkColor.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()

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
            let accent = ThemeManager.shared.accentColor.withAlphaComponent(0.18).cgColor
            context.setFillColor(accent)
            context.fillPath()
            context.restoreGState()
        }

        // 3a. Subtle Hairline Radial Dividers between 8 sectors (Obsidian Glass Craft)
        context.saveGState()
        context.setLineWidth(1.0)
        let dividerColor = NSColor(white: 1.0, alpha: 0.08).cgColor
        context.setStrokeColor(dividerColor)
        let totalSlots = 8
        let halfWedge = (2.0 * CGFloat.pi / CGFloat(totalSlots)) / 2.0
        for slot in 0..<totalSlots {
            let slotAngle = (-CGFloat.pi / 2.0) + (CGFloat(slot) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))
            let dividerAngle = slotAngle + halfWedge
            let x1 = center.x + ((innerR + 1.0) * cos(dividerAngle))
            let y1 = center.y + ((innerR + 1.0) * sin(dividerAngle))
            let x2 = center.x + ((outerR - 2.0) * cos(dividerAngle))
            let y2 = center.y + ((outerR - 2.0) * sin(dividerAngle))
            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
        }
        context.strokePath()
        context.restoreGState()

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

    // MARK: - NSDraggingDestination (Fitts' Law W = ∞ Hit-Testing)

    public var onSectorHovered: ((Int?) -> Void)?
    public var onSectorDropped: ((Int, [URL]) -> Void)?

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return draggingUpdated(sender)
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let loc = convert(sender.draggingLocation, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let slot = WheelGeometry.sectorIndex(for: loc, center: center, totalSlots: 8) {
            hoveredSlotIndex = slot
            onSectorHovered?(slot)
            return .copy
        } else {
            hoveredSlotIndex = nil
            onSectorHovered?(nil)
            return []
        }
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        hoveredSlotIndex = nil
        onSectorHovered?(nil)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let loc = convert(sender.draggingLocation, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard let slot = WheelGeometry.sectorIndex(for: loc, center: center, totalSlots: 8) else {
            return false
        }

        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !pasteboard.isEmpty else {
            return false
        }

        hoveredSlotIndex = nil
        onSectorDropped?(slot, pasteboard)
        return true
    }
}
