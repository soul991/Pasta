import Foundation
import AppKit

public final class RadialWheelCenterDiscView: NSView {
    private let visualEffect = NSVisualEffectView()
    private let iconImageView = NSImageView()
    private let fileNameLabel = NSTextField(labelWithString: "")
    private let convertBadge = NSTextField(labelWithString: "CONVERT")

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 110, height: 110))
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 55
        layer?.masksToBounds = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 55
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        // Filename
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        fileNameLabel.textColor = .white
        fileNameLabel.alignment = .center
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(fileNameLabel)

        // Convert badge
        convertBadge.translatesAutoresizingMaskIntoConstraints = false
        convertBadge.font = NSFont.systemFont(ofSize: 9, weight: .black)
        convertBadge.textColor = ThemeManager.shared.accentColor
        convertBadge.alignment = .center
        addSubview(convertBadge)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 34),
            iconImageView.heightAnchor.constraint(equalToConstant: 34),

            fileNameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            fileNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            fileNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            convertBadge.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 2),
            convertBadge.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        updateBorder()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    @objc private func themeChanged() {
        updateBorder()
    }

    private func updateBorder() {
        let accent = ThemeManager.shared.accentColor
        layer?.borderWidth = 2.5
        layer?.borderColor = accent.cgColor
        layer?.shadowColor = accent.cgColor
        layer?.shadowOpacity = 0.6
        layer?.shadowRadius = 10
        layer?.shadowOffset = .zero
        convertBadge.textColor = accent
    }

    public func configure(fileURL: URL, isAdvanced: Bool) {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 34, height: 34)
        iconImageView.image = icon

        fileNameLabel.stringValue = fileURL.lastPathComponent
        convertBadge.stringValue = isAdvanced ? "TOOLS" : "CONVERT"
    }
}
