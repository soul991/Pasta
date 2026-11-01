import Foundation
import AppKit
import QuartzCore

public final class MiniatureWheelPreviewView: NSView {
    public var currentTheme: WheelTheme = WheelLayoutModel.shared.currentTheme {
        didSet { updatePreview() }
    }
    public var currentGlassStyle: GlassStyle = WheelLayoutModel.shared.currentGlassStyle {
        didSet { updatePreview() }
    }
    public var glassStrength: Double = WheelLayoutModel.shared.glassStrength {
        didSet { updatePreview() }
    }
    public var currentSize: WheelSize = WheelLayoutModel.shared.currentSize {
        didSet { updatePreview() }
    }

    public var previewDiameter: CGFloat {
        switch currentSize {
        case .compact: return 68.0
        case .standard: return 80.0
        case .large: return 92.0
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
    }

    public func updatePreview() {
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = previewDiameter / 2.0
        let innerR = previewDiameter * 0.32 / 2.0

        // 1. Annulus Glass Backplate
        let annulusPath = CGMutablePath()
        annulusPath.addArc(center: center, radius: outerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: false)
        annulusPath.addArc(center: center, radius: innerR, startAngle: 0, endAngle: 2.0 * .pi, clockwise: true)

        context.saveGState()
        context.addPath(annulusPath)

        let baseGlassAlpha = CGFloat(max(0.1, min(1.0, glassStrength)))
        switch currentGlassStyle {
        case .clear:
            context.setFillColor(NSColor(white: 0.22, alpha: baseGlassAlpha * 0.35).cgColor)
            context.fillPath(using: .evenOdd)
        case .regular:
            context.setFillColor(NSColor(white: 0.12, alpha: baseGlassAlpha * 0.75).cgColor)
            context.fillPath(using: .evenOdd)
        case .tinted:
            context.setFillColor(NSColor(white: 0.10, alpha: baseGlassAlpha * 0.55).cgColor)
            context.fillPath(using: .evenOdd)
            context.saveGState()
            context.addPath(annulusPath)
            let tint = currentTheme.accentColor.withAlphaComponent(baseGlassAlpha * 0.35).cgColor
            context.setFillColor(tint)
            context.fillPath(using: .evenOdd)
            context.restoreGState()
        }
        context.restoreGState()

        // 2. Annulus Hairline Rim Strokes
        context.saveGState()
        let outerCircle = CGPath(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: previewDiameter, height: previewDiameter), transform: nil)
        context.addPath(outerCircle)
        context.setLineWidth(1.0)
        context.setStrokeColor(NSColor(white: 1.0, alpha: 0.35).cgColor)
        context.strokePath()

        let innerCircle = CGPath(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2), transform: nil)
        context.addPath(innerCircle)
        context.setLineWidth(1.0)
        context.setStrokeColor(NSColor(white: 1.0, alpha: 0.20).cgColor)
        context.strokePath()
        context.restoreGState()

        // 3. Center Hub
        context.saveGState()
        let hubR = innerR - 1.0
        let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
        context.setFillColor(NSColor(white: 0.08, alpha: 0.90).cgColor)
        context.fillEllipse(in: hubRect)

        // Center Accent Dot
        let dotR: CGFloat = 3.0
        let dotRect = CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)
        context.setFillColor(currentTheme.accentColor.cgColor)
        context.fillEllipse(in: dotRect)
        context.restoreGState()

        // 4. Eight Miniature Nodes
        let orbitR = (outerR + innerR) / 2.0
        let nodeR = previewDiameter * 0.065

        for i in 0..<8 {
            let angle = (-CGFloat.pi / 2.0) + (CGFloat(i) * (2.0 * CGFloat.pi / 8.0))
            let nodeCenter = CGPoint(x: center.x + orbitR * cos(angle), y: center.y + orbitR * sin(angle))
            let nodeRect = CGRect(x: nodeCenter.x - nodeR, y: nodeCenter.y - nodeR, width: nodeR * 2, height: nodeR * 2)

            context.saveGState()
            if i == 0 {
                // Active node: Accent fill with subtle glow
                context.setFillColor(currentTheme.accentColor.cgColor)
                context.fillEllipse(in: nodeRect)

                context.setLineWidth(1.0)
                context.setStrokeColor(NSColor.white.cgColor)
                context.strokeEllipse(in: nodeRect)
            } else {
                // Inactive nodes: Glass disc
                let nodeAlpha = CGFloat(0.35 + (glassStrength * 0.35))
                context.setFillColor(NSColor(white: 0.25, alpha: nodeAlpha).cgColor)
                context.fillEllipse(in: nodeRect)

                if currentGlassStyle == .tinted {
                    context.setFillColor(currentTheme.accentColor.withAlphaComponent(0.20).cgColor)
                    context.fillEllipse(in: nodeRect)
                }

                context.setLineWidth(0.8)
                context.setStrokeColor(NSColor(white: 1.0, alpha: 0.30).cgColor)
                context.strokeEllipse(in: nodeRect)
            }
            context.restoreGState()
        }
    }
}
