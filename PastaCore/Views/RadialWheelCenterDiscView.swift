import Foundation
import AppKit

public final class RadialWheelCenterDiscView: NSView {
    public var diameter: CGFloat = 128.0 {
        didSet {
            frame.size = NSSize(width: diameter, height: diameter)
            layer?.cornerRadius = diameter / 2.0
            visualEffect.layer?.cornerRadius = diameter / 2.0
        }
    }

    private let visualEffect = NSVisualEffectView()
    private let iconImageView = NSImageView()
    private let countBadge = NSTextField(labelWithString: "")
    private let fileNameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    public var displayedFileName: String {
        return fileNameLabel.stringValue
    }

    public var displayedDetail: String {
        return detailLabel.stringValue
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 64
        layer?.masksToBounds = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 64
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Accessibility attributes
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Wheel Center Hub")
        setAccessibilityHelp("Shows selected file preview and information")

        // Thumbnail / App Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconImageView)

        // Count Badge (for multi-file drag)
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = NSFont.systemFont(ofSize: 10, weight: .black)
        countBadge.textColor = .white
        countBadge.alignment = .center
        countBadge.wantsLayer = true
        countBadge.layer?.cornerRadius = 9
        countBadge.layer?.backgroundColor = ThemeManager.shared.accentColor.cgColor
        countBadge.layer?.masksToBounds = true
        countBadge.isHidden = true
        addSubview(countBadge)

        // Filename label (middle truncation)
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        fileNameLabel.textColor = .white
        fileNameLabel.alignment = .center
        fileNameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(fileNameLabel)

        // Detail label: "type · size"
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        detailLabel.textColor = ThemeManager.shared.accentColor
        detailLabel.alignment = .center
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            countBadge.trailingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            countBadge.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: -4),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            countBadge.heightAnchor.constraint(equalToConstant: 18),

            fileNameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            fileNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            fileNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
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
        let isReduceTransparency = ThemeManager.shared.isReduceTransparency
        let isIncreaseContrast = ThemeManager.shared.isIncreaseContrast
        let isReduceMotion = ThemeManager.shared.isReduceMotion

        if isReduceTransparency {
            visualEffect.isHidden = true
            layer?.backgroundColor = ThemeManager.shared.reduceTransparencyBackground.cgColor
        } else {
            visualEffect.isHidden = false
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.5
        layer?.borderColor = isIncreaseContrast ?
            ThemeManager.shared.increaseContrastBorderColor.cgColor :
            accent.withAlphaComponent(0.6).cgColor

        layer?.shadowColor = isReduceMotion ? nil : accent.cgColor
        layer?.shadowOpacity = isReduceMotion ? 0.0 : 0.35
        layer?.shadowRadius = isReduceMotion ? 0 : 8
        layer?.shadowOffset = .zero
        detailLabel.textColor = accent
        countBadge.layer?.backgroundColor = accent.cgColor
    }

    public func configureEmpty() {
        countBadge.isHidden = true
        if let pastaIcon = NSImage(named: "MenuBarIcon") {
            pastaIcon.isTemplate = true
            iconImageView.image = pastaIcon
        } else {
            let img = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: "Drag file")
            img?.isTemplate = true
            iconImageView.image = img
        }
        iconImageView.contentTintColor = ThemeManager.shared.accentColor
        fileNameLabel.stringValue = "Drag a file onto the wheel"
        detailLabel.stringValue = "PASTA"
    }

    public func configure(fileURL: URL?, isAdvanced: Bool) {
        guard let fileURL = fileURL else {
            configureEmpty()
            return
        }
        configure(files: [fileURL], isAdvanced: isAdvanced)
    }

    public func configure(files: [URL], isAdvanced: Bool) {
        guard let firstFile = files.first else {
            configureEmpty()
            return
        }

        let icon = NSWorkspace.shared.icon(forFile: firstFile.path)
        iconImageView.image = icon
        iconImageView.contentTintColor = nil

        if files.count > 1 {
            countBadge.isHidden = false
            countBadge.stringValue = " \(files.count) "
            fileNameLabel.stringValue = "\(files.count) Files"

            var totalBytes: Int64 = 0
            for f in files {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: f.path),
                   let sz = attrs[.size] as? Int64 {
                    totalBytes += sz
                }
            }
            let sizeStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            let ext = firstFile.pathExtension.uppercased()
            detailLabel.stringValue = "\(ext) · \(sizeStr)"
        } else {
            countBadge.isHidden = true
            fileNameLabel.stringValue = firstFile.lastPathComponent

            var sizeStr = ""
            if let attrs = try? FileManager.default.attributesOfItem(atPath: firstFile.path),
               let sz = attrs[.size] as? Int64 {
                sizeStr = ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)
            }
            let ext = firstFile.pathExtension.uppercased()
            detailLabel.stringValue = sizeStr.isEmpty ? ext : "\(ext) · \(sizeStr)"
        }
    }
}
