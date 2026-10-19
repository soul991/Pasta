import Foundation
import AppKit

public final class FormatChipView: NSView {
    public let action: ConversionAction
    public var onSelect: ((ConversionAction) -> Void)?
    public var onFileDropped: ((ConversionAction, [URL]) -> Void)?

    private var isHovered: Bool = false {
        didSet { needsDisplay = true }
    }
    private var isDraggingOver: Bool = false {
        didSet { needsDisplay = true }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()

    public init(action: ConversionAction) {
        self.action = action
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        registerForDraggedTypes([.fileURL])

        // Tracking area for hover
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        // Title and icon setup
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left

        // Short label: e.g. "JPEG", "PNG", "eBook PDF"
        var label = action.outputExtension.uppercased()
        if label.isEmpty {
            label = action.displayName
        }
        titleLabel.stringValue = label

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(systemSymbolName: action.iconName, accessibilityDescription: nil) {
            iconImageView.image = image
            iconImageView.contentTintColor = .secondaryLabelColor
        }

        addSubview(iconImageView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)

        let accent = ThemeManager.shared.accentColor

        if isDraggingOver {
            accent.withAlphaComponent(0.35).setFill()
            path.fill()
            accent.setStroke()
            path.lineWidth = 2.0
            path.stroke()
            titleLabel.textColor = .white
            iconImageView.contentTintColor = accent
        } else if isHovered {
            ThemeManager.shared.accentColorSubtle.setFill()
            path.fill()
            accent.setStroke()
            path.lineWidth = 1.5
            path.stroke()
            iconImageView.contentTintColor = accent
        } else {
            NSColor.controlBackgroundColor.withAlphaComponent(0.7).setFill()
            path.fill()
            NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1.0
            path.stroke()
            titleLabel.textColor = .labelColor
            iconImageView.contentTintColor = .secondaryLabelColor
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    public override func mouseDown(with event: NSEvent) {
        onSelect?(action)
    }

    // MARK: - NSDraggingDestination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let items = sender.draggingPasteboard.pasteboardItems, !items.isEmpty else {
            return []
        }
        isDraggingOver = true
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        var urls: [URL] = []
        for item in items {
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            onFileDropped?(action, urls)
            return true
        }
        return false
    }
}
