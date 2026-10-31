import Foundation
import AppKit

public final class SettingsHeaderView: NSView {
    public let iconImageView = NSImageView()
    public let titleLabel = NSTextField(labelWithString: "Pasta")
    public let subtitleLabel = NSTextField(labelWithString: "Preferences & Radial Wheel Settings")
    private let separator = NSBox()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        if let appIcon = BrandAssetManager.loadAppIcon(size: NSSize(width: 48, height: 48)) {
            iconImageView.image = appIcon
        } else if let menuBarIcon = BrandAssetManager.loadMenuBarIcon(size: NSSize(width: 48, height: 48)) {
            menuBarIcon.isTemplate = true
            iconImageView.image = menuBarIcon
            iconImageView.contentTintColor = ThemeManager.shared.accentColor
        }
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
}

public final class SettingsWindowController: NSWindowController {
    public let headerView = SettingsHeaderView()
    public let customizeSheet = RadialWheelCustomizeSheet()

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pasta Settings"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupContentView(window: window)
    }

    private func setupContentView(window: NSWindow) {
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        container.wantsLayer = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerView)

        customizeSheet.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(customizeSheet)

        customizeSheet.onCloseRequested = { [weak self] in
            self?.close()
        }

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: container.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 80),

            customizeSheet.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            customizeSheet.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            customizeSheet.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            customizeSheet.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])

        window.contentView = container
    }
}
