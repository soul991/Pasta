import Foundation
import AppKit

public final class JobStatusRowView: NSView {
    public enum State {
        case running
        case completed(URL)
        case failed(String)
    }

    public let inputURL: URL
    public let action: ConversionAction
    public var onDismiss: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let statusIcon = NSImageView()
    private let actionButton = NSButton(title: "Reveal", target: nil, action: nil)

    public init(inputURL: URL, action: ConversionAction) {
        self.inputURL = inputURL
        self.action = action
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.stringValue = "\(inputURL.lastPathComponent) → \(action.outputExtension.uppercased().isEmpty ? action.displayName : action.outputExtension.uppercased())"
        titleLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Processing..."
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)

        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.isHidden = true

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .inline
        actionButton.target = self
        actionButton.action = #selector(actionButtonClicked)
        actionButton.isHidden = true

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(spinner)
        addSubview(statusIcon)
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            spinner.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),

            statusIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusIcon.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private var currentOutputURL: URL?

    public func update(state: State) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .running:
                self.spinner.isHidden = false
                self.spinner.startAnimation(nil)
                self.statusIcon.isHidden = true
                self.statusLabel.stringValue = "Converting..."
                self.statusLabel.textColor = .secondaryLabelColor
                self.actionButton.isHidden = true

            case .completed(let url):
                self.currentOutputURL = url
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.statusIcon.isHidden = false
                self.statusIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
                self.statusIcon.contentTintColor = .systemGreen
                self.statusLabel.stringValue = "Done: \(url.lastPathComponent)"
                self.statusLabel.textColor = .labelColor
                self.actionButton.title = "Reveal"
                self.actionButton.isHidden = false

            case .failed(let error):
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.statusIcon.isHidden = false
                self.statusIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                self.statusIcon.contentTintColor = .systemRed
                self.statusLabel.stringValue = error
                self.statusLabel.textColor = .systemRed
                self.actionButton.title = "Dismiss"
                self.actionButton.isHidden = false
            }
        }
    }

    @objc private func actionButtonClicked() {
        if let out = currentOutputURL {
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } else {
            onDismiss?()
            removeFromSuperview()
        }
    }
}
