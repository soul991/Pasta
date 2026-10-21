import Foundation
import AppKit
import QuartzCore

public final class RadialOptionNodeView: NSView {
    public let action: ConversionAction
    public var onSelect: ((ConversionAction) -> Void)?
    public var onDrop: ((ConversionAction, [URL]) -> Void)?

    private var isDraggingOver: Bool = false {
        didSet { updateState() }
    }
    private var isHovered: Bool = false {
        didSet { updateState() }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    public init(action: ConversionAction) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 90, height: 38))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 19
        layer?.masksToBounds = false

        registerForDraggedTypes([.fileURL])

        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: action.iconName, accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = .labelColor
        }
        addSubview(iconView)

        // Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        var label = action.outputExtension.uppercased()
        if label.isEmpty {
            label = action.displayName
        }
        titleLabel.stringValue = label
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    @objc private func themeChanged() {
        updateState()
    }

    private func updateState() {
        let accent = ThemeManager.shared.accentColor

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.allowsImplicitAnimation = true

            if isDraggingOver {
                // Dramatic magnification on drag hover!
                layer?.transform = CATransform3DMakeScale(1.35, 1.35, 1.0)
                layer?.backgroundColor = accent.cgColor
                layer?.borderColor = NSColor.white.cgColor
                layer?.borderWidth = 2.5
                layer?.shadowColor = accent.cgColor
                layer?.shadowOpacity = 0.9
                layer?.shadowRadius = 12
                layer?.shadowOffset = .zero

                titleLabel.textColor = .white
                iconView.contentTintColor = .white
            } else if isHovered {
                layer?.transform = CATransform3DMakeScale(1.12, 1.12, 1.0)
                layer?.backgroundColor = accent.withAlphaComponent(0.3).cgColor
                layer?.borderColor = accent.cgColor
                layer?.borderWidth = 2.0
                layer?.shadowColor = accent.cgColor
                layer?.shadowOpacity = 0.5
                layer?.shadowRadius = 6

                titleLabel.textColor = .labelColor
                iconView.contentTintColor = accent
            } else {
                layer?.transform = CATransform3DIdentity
                layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.88).cgColor
                layer?.borderColor = NSColor(white: 0.35, alpha: 0.6).cgColor
                layer?.borderWidth = 1.2
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.35
                layer?.shadowRadius = 4
                layer?.shadowOffset = CGSize(width: 0, height: -2)

                titleLabel.textColor = .white
                iconView.contentTintColor = .white
            }
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

    // MARK: - Dragging Destination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDraggingOver = true
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        var urls: [URL] = []
        if let pasteboardURLs = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls.append(contentsOf: pasteboardURLs)
        }
        if urls.isEmpty, let items = sender.draggingPasteboard.pasteboardItems {
            for item in items {
                if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                    urls.append(url)
                }
            }
        }
        if !urls.isEmpty {
            onDrop?(action, urls)
            return true
        } else {
            // Drop target fallback: triggers conversion on the file currently selected by the wheel
            onSelect?(action)
            return true
        }
    }
}
