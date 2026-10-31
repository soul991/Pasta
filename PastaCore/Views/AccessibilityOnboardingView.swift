import Foundation
import AppKit

public final class AccessibilityOnboardingView: NSView {
    public var onPermissionGranted: (() -> Void)?
    public var onDismiss: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Enable Accessibility for Pasta")
    private let subtitleLabel = NSTextField(labelWithString: "Pasta needs Accessibility permissions to detect Shift-drag gestures and allow Esc to close the wheel when other applications are active.")

    private let step1Label = NSTextField(labelWithString: "1. Click 'Open System Settings' below")
    private let step2Label = NSTextField(labelWithString: "2. Under Accessibility, toggle 'Pasta' to ON")
    private let step3Label = NSTextField(labelWithString: "3. Return to Finder — Pasta will detect it automatically")

    public let statusBadge = NSTextField(labelWithString: "Waiting for permission...")
    public let openSettingsButton = NSButton(title: "Open System Settings", target: nil, action: nil)
    public let dismissButton = NSButton(title: "Later", target: nil, action: nil)

    private var pollTimer: Timer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 280))
        setupUI()
        startPolling()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        let stepsStack = NSStackView(views: [step1Label, step2Label, step3Label])
        stepsStack.orientation = .vertical
        stepsStack.alignment = .leading
        stepsStack.spacing = 6
        stepsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stepsStack)

        for step in [step1Label, step2Label, step3Label] {
            step.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            step.textColor = .labelColor
        }

        statusBadge.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusBadge.textColor = .systemOrange
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusBadge)

        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettingsClicked)
        openSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(openSettingsButton)

        dismissButton.bezelStyle = .rounded
        dismissButton.target = self
        dismissButton.action = #selector(dismissClicked)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            stepsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            stepsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stepsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            statusBadge.topAnchor.constraint(equalTo: stepsStack.bottomAnchor, constant: 14),
            statusBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            openSettingsButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            openSettingsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }

    public func checkPermission() {
        if DragMonitor.isAccessibilityTrusted() {
            statusBadge.stringValue = "Permission Granted ✓"
            statusBadge.textColor = .systemGreen
            pollTimer?.invalidate()
            pollTimer = nil
            onPermissionGranted?()
        }
    }

    @objc private func openSettingsClicked() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func dismissClicked() {
        pollTimer?.invalidate()
        onDismiss?()
        removeFromSuperview()
    }
}

public final class AccessibilityOnboardingWindowController: NSWindowController {
    public let onboardingView = AccessibilityOnboardingView()

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Pasta"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentView = onboardingView
        onboardingView.onDismiss = { [weak self] in
            self?.close()
        }
        onboardingView.onPermissionGranted = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self?.close()
            }
        }
    }
}
