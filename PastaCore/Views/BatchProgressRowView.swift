import Foundation
import AppKit

/// Combined batch progress row displaying aggregate conversion status and progress bar.
public final class BatchProgressRowView: NSView {
    public let totalCount: Int
    public let action: ConversionAction
    public private(set) var completedCount: Int = 0
    public private(set) var failedCount: Int = 0
    public private(set) var isCancelled: Bool = false

    public var onCancel: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    public let summaryLabel = NSTextField(labelWithString: "")
    public let progressBar = NSProgressIndicator()
    public let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    public init(totalCount: Int, action: ConversionAction) {
        self.totalCount = totalCount
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

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Batch progress: 0 of \(totalCount) complete")
        identifier = NSUserInterfaceItemIdentifier("BatchProgressRow")

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.stringValue = "Batch \(action.displayName)"
        titleLabel.lineBreakMode = .byTruncatingTail

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = ThemeManager.shared.accentColor
        summaryLabel.stringValue = "0 of \(totalCount) complete"
        summaryLabel.identifier = NSUserInterfaceItemIdentifier("BatchProgressRow.summary")
        summaryLabel.setAccessibilityElement(true)
        summaryLabel.setAccessibilityLabel("Batch completion count")

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0.0
        progressBar.maxValue = Double(max(1, totalCount))
        progressBar.doubleValue = 0.0
        progressBar.controlSize = .small

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .inline
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.identifier = NSUserInterfaceItemIdentifier("BatchProgressRow.cancelButton")

        addSubview(titleLabel)
        addSubview(summaryLabel)
        addSubview(progressBar)
        addSubview(cancelButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 58),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: summaryLabel.leadingAnchor, constant: -8),

            summaryLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            summaryLabel.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -10),

            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: topAnchor, constant: 18),

            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    public func update(completed: Int, failed: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.completedCount = completed
            self.failedCount = failed
            let totalDone = completed + failed
            self.progressBar.doubleValue = Double(totalDone)

            if totalDone >= self.totalCount {
                self.cancelButton.isHidden = true
                if failed == 0 {
                    self.summaryLabel.stringValue = "All \(self.totalCount) complete"
                } else {
                    self.summaryLabel.stringValue = "\(completed) of \(self.totalCount) complete (\(failed) failed)"
                }
            } else {
                let failSuffix = failed > 0 ? " (\(failed) failed)" : ""
                self.summaryLabel.stringValue = "\(totalDone) of \(self.totalCount) complete\(failSuffix)"
            }
            self.setAccessibilityLabel("Batch progress: \(self.summaryLabel.stringValue)")
        }
    }

    public func markCancelled() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCancelled = true
            self.cancelButton.isHidden = true
            self.summaryLabel.stringValue = "Cancelled (\(self.completedCount) of \(self.totalCount) complete)"
            self.summaryLabel.textColor = NSColor.systemOrange
            self.setAccessibilityLabel("Batch cancelled: \(self.summaryLabel.stringValue)")
        }
    }

    @objc private func cancelClicked() {
        onCancel?()
        markCancelled()
    }
}
