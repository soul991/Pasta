import Foundation
import AppKit
import QuartzCore

public final class ConversionProgressHUDView: NSView {
    public var onDismiss: (() -> Void)?

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Converting...")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let actionButton = NSButton(title: "Reveal in Finder", target: nil, action: nil)

    private var outputURL: URL?

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
        layer?.cornerRadius = 16

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "gearshape.2.fill", accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = ThemeManager.shared.accentColor
        }
        addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(subtitleLabel)

        // Progress
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.startAnimation(nil)
        addSubview(progressIndicator)

        // Action button
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.isHidden = true
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 38),
            iconView.heightAnchor.constraint(equalToConstant: 38),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            progressIndicator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),

            actionButton.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 14),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionButton.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    public func showProgress(action: ConversionAction, filename: String) {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        actionButton.isHidden = true
        titleLabel.stringValue = "Converting to \(action.outputExtension.uppercased().isEmpty ? action.displayName : action.outputExtension.uppercased())"
        subtitleLabel.stringValue = filename

        if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = ThemeManager.shared.accentColor
        }
    }

    public func showSuccess(outputURL: URL) {
        self.outputURL = outputURL
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true

        titleLabel.stringValue = "Conversion Complete!"
        subtitleLabel.stringValue = outputURL.lastPathComponent

        if let img = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = .systemGreen
        }

        // Bounce animation
        iconView.layer?.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            iconView.layer?.transform = CATransform3DIdentity
        }

        actionButton.title = "Reveal in Finder"
        actionButton.isHidden = false

        // Auto dismiss after 2.5s if not interacted
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.window?.isVisible == true {
                self?.onDismiss?()
            }
        }
    }

    public func showError(_ message: String) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true

        titleLabel.stringValue = "Conversion Failed"
        subtitleLabel.stringValue = message

        if let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = .systemRed
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
