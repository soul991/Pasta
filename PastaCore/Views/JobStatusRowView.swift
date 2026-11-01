import Foundation
import AppKit

public final class JobStatusRowView: NSView {
    public enum State: Equatable {
        case queued
        case running(etaSeconds: Double? = nil, progress: Double? = nil)
        case completed(URL)
        case failed(String)

        public static var running: State {
            return .running(etaSeconds: nil, progress: nil)
        }
    }

    public let inputURL: URL
    public let action: ConversionAction
    public var jobID: UUID?
    public var onDismiss: (() -> Void)?
    public var onCancel: (() -> Void)?

    public private(set) var currentState: State = .queued
    public private(set) var lastError: String?

    public var currentStatusText: String { statusLabel.stringValue }
    public var actionButtonTitle: String { actionButton.title }

    public let titleLabel = NSTextField(labelWithString: "")
    public let statusLabel = NSTextField(labelWithString: "")
    public let progressBar = NSProgressIndicator()
    private let spinner = NSProgressIndicator()
    private let statusIcon = NSImageView()
    public let actionButton = NSButton(title: "Reveal", target: nil, action: nil)

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

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.controlSize = .small
        progressBar.minValue = 0.0
        progressBar.maxValue = 100.0
        progressBar.isIndeterminate = true
        progressBar.isHidden = true

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

        let middleStack = NSStackView(views: [titleLabel, statusLabel, progressBar])
        middleStack.translatesAutoresizingMaskIntoConstraints = false
        middleStack.orientation = .vertical
        middleStack.alignment = .leading
        middleStack.spacing = 3

        addSubview(spinner)
        addSubview(statusIcon)
        addSubview(middleStack)
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            spinner.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),

            statusIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusIcon.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16),

            middleStack.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            middleStack.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -10),
            middleStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            middleStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),

            progressBar.widthAnchor.constraint(equalTo: middleStack.widthAnchor),

            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private var currentOutputURL: URL?

    public func update(state: State) {
        currentState = state

        let apply = { [weak self] in
            guard let self = self else { return }

            switch state {
            case .queued:
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.progressBar.stopAnimation(nil)
                self.progressBar.isIndeterminate = false
                self.progressBar.doubleValue = 0.0
                self.progressBar.isHidden = true
                self.statusIcon.isHidden = false
                self.statusIcon.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Queued")
                self.statusIcon.contentTintColor = .secondaryLabelColor
                self.statusLabel.stringValue = "Queued"
                self.statusLabel.textColor = .secondaryLabelColor
                self.actionButton.title = "Cancel"
                self.actionButton.isHidden = false

            case .running(let eta, let progress):
                self.spinner.isHidden = false
                self.spinner.startAnimation(nil)
                self.statusIcon.isHidden = true
                self.progressBar.isHidden = false
                if let p = progress {
                    self.progressBar.isIndeterminate = false
                    self.progressBar.minValue = 0.0
                    self.progressBar.maxValue = 100.0
                    self.progressBar.doubleValue = max(0.0, min(100.0, p * 100.0))
                    if let eta = eta, eta > 0 {
                        self.statusLabel.stringValue = String(format: "Converting (%d%%)... ~%.0fs left", Int(p * 100.0), eta)
                    } else {
                        self.statusLabel.stringValue = String(format: "Converting (%d%%)...", Int(p * 100.0))
                    }
                } else {
                    self.progressBar.isIndeterminate = true
                    self.progressBar.startAnimation(nil)
                    if let eta = eta, eta > 0 {
                        self.statusLabel.stringValue = String(format: "Converting... ~%.0fs left", eta)
                    } else {
                        self.statusLabel.stringValue = "Converting..."
                    }
                }
                self.statusLabel.textColor = .secondaryLabelColor
                self.actionButton.title = "Cancel"
                self.actionButton.isHidden = false

            case .completed(let url):
                self.currentOutputURL = url
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.progressBar.stopAnimation(nil)
                self.progressBar.isHidden = true
                self.statusIcon.isHidden = false
                self.statusIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
                self.statusIcon.contentTintColor = .systemGreen

                let inSize = (try? FileManager.default.attributesOfItem(atPath: self.inputURL.path)[.size] as? Int64) ?? 0
                let outSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

                if inSize > 0 && outSize > 0 {
                    let inStr = self.formatByteSize(inSize)
                    let outStr = self.formatByteSize(outSize)
                    if outSize < inSize {
                        let savedPct = Int(round((1.0 - Double(outSize) / Double(inSize)) * 100.0))
                        self.statusLabel.stringValue = "Done · Saved \(savedPct)% (\(inStr) → \(outStr))"
                    } else if outSize > inSize {
                        let incPct = Int(round((Double(outSize) / Double(inSize) - 1.0) * 100.0))
                        self.statusLabel.stringValue = "Done · (\(inStr) → \(outStr) [+\(incPct)%])"
                    } else {
                        self.statusLabel.stringValue = "Done · \(outStr)"
                    }
                } else {
                    self.statusLabel.stringValue = "Done: \(url.lastPathComponent)"
                }

                self.statusLabel.textColor = .labelColor
                self.actionButton.title = "Reveal"
                self.actionButton.isHidden = false

            case .failed(let error):
                self.lastError = error
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.progressBar.stopAnimation(nil)
                self.progressBar.isHidden = true
                self.statusIcon.isHidden = false
                self.statusIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                self.statusIcon.contentTintColor = .systemRed
                self.statusLabel.stringValue = error
                self.statusLabel.textColor = .systemRed
                self.actionButton.title = "Copy Details"
                self.actionButton.isHidden = false
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    public func updateProgress(_ progress: Double?, etaSeconds: Double? = nil) {
        update(state: .running(etaSeconds: etaSeconds, progress: progress))
    }

    @objc private func actionButtonClicked() {
        switch currentState {
        case .running:
            if let jid = jobID {
                JobRunner.shared.cancel(jobId: jid)
            }
            onCancel?()
            update(state: .failed("Conversion cancelled by user"))
        case .completed(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .failed(let err):
            copyErrorDetails(err)
        case .queued:
            if let jid = jobID {
                JobRunner.shared.cancel(jobId: jid)
            }
            onCancel?()
            onDismiss?()
            removeFromSuperview()
        }
    }

    public func copyErrorDetails(_ errorText: String) {
        let details = """
        Pasta Error Report
        File: \(inputURL.path)
        Action: \(action.displayName) (\(action.id))
        Error: \(errorText)
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        statusLabel.stringValue = "Error copied to clipboard ✓"
    }

    public func formatByteSize(_ bytes: Int64) -> String {
        let b = Double(bytes)
        if b < 1024 { return "\(bytes) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024.0) }
        return String(format: "%.1f MB", b / 1_048_576.0)
    }
}
