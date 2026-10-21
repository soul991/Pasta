import Foundation
import AppKit
import QuartzCore

public final class RadialConversionHUDView: NSView {
    public var onDismiss: (() -> Void)?

    private let visualEffect = NSVisualEffectView()
    private let statusIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Converting...")
    private let formatLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "Reveal", target: nil, action: nil)

    private var rotatingRingLayer: CAShapeLayer?
    private var outputURL: URL?

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 75
        layer?.masksToBounds = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 75
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Status Icon
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            statusIconView.image = img
            statusIconView.contentTintColor = ThemeManager.shared.accentColor
        }
        addSubview(statusIconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        addSubview(titleLabel)

        // Format label
        formatLabel.translatesAutoresizingMaskIntoConstraints = false
        formatLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        formatLabel.textColor = ThemeManager.shared.accentColor
        formatLabel.alignment = .center
        addSubview(formatLabel)

        // Action button
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .inline
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.isHidden = true
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            statusIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusIconView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            statusIconView.widthAnchor.constraint(equalToConstant: 32),
            statusIconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: statusIconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            formatLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            formatLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            formatLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            actionButton.topAnchor.constraint(equalTo: formatLabel.bottomAnchor, constant: 6),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        setupRotatingRing()
    }

    private func setupRotatingRing() {
        rotatingRingLayer?.removeFromSuperlayer()

        let ring = CAShapeLayer()
        let radius: CGFloat = 72
        let path = CGMutablePath()
        path.addArc(
            center: CGPoint(x: 75, y: 75),
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: false
        )
        ring.path = path
        ring.fillColor = nil
        ring.strokeColor = ThemeManager.shared.accentColor.cgColor
        ring.lineWidth = 3.0
        ring.lineDashPattern = [16, 8]
        ring.lineCap = .round

        layer?.addSublayer(ring)
        self.rotatingRingLayer = ring

        // Continuous rotation animation
        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = 0
        rotate.toValue = CGFloat.pi * 2
        rotate.duration = 1.6
        rotate.repeatCount = .infinity
        ring.add(rotate, forKey: "rotateAnimation")
    }

    public func showConverting(action: ConversionAction, filename: String) {
        setupRotatingRing()
        actionButton.isHidden = true
        titleLabel.stringValue = "Converting..."
        formatLabel.stringValue = "→ \(action.outputExtension.uppercased().isEmpty ? action.displayName : action.outputExtension.uppercased())"
        formatLabel.textColor = ThemeManager.shared.accentColor

        if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            statusIconView.image = img
            statusIconView.contentTintColor = ThemeManager.shared.accentColor
        }
    }

    public func showSuccess(outputURL: URL) {
        self.outputURL = outputURL
        rotatingRingLayer?.removeAllAnimations()
        rotatingRingLayer?.strokeColor = NSColor.systemGreen.cgColor
        rotatingRingLayer?.lineDashPattern = nil

        titleLabel.stringValue = "Done!"
        formatLabel.stringValue = outputURL.lastPathComponent
        formatLabel.textColor = .systemGreen

        if let img = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
            statusIconView.image = img
            statusIconView.contentTintColor = .systemGreen
        }

        // Celebratory bounce
        statusIconView.layer?.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            statusIconView.layer?.transform = CATransform3DIdentity
        }

        actionButton.title = "Reveal in Finder"
        actionButton.isHidden = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.onDismiss?()
        }
    }

    public func showError(_ message: String) {
        rotatingRingLayer?.removeAllAnimations()
        rotatingRingLayer?.strokeColor = NSColor.systemRed.cgColor
        rotatingRingLayer?.lineDashPattern = nil

        titleLabel.stringValue = "Failed"
        formatLabel.stringValue = message
        formatLabel.textColor = .systemRed

        if let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
            statusIconView.image = img
            statusIconView.contentTintColor = .systemRed
        }

        actionButton.title = "Dismiss"
        actionButton.isHidden = false
    }

    @objc private func actionClicked() {
        if let out = outputURL {
            NSWorkspace.shared.activateFileViewerSelecting([out])
        }
        onDismiss?()
    }
}
