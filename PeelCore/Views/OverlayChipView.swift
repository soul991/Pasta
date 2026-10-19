import Foundation
import AppKit

public final class OverlayChipView: NSView {
    public let action: ConversionAction
    public var onSelect: ((ConversionAction) -> Void)?
    public var onDrop: ((ConversionAction, [URL]) -> Void)?

    private var isDraggingOver: Bool = false {
        didSet { updateAppearance() }
    }
    private var isHovered: Bool = false {
        didSet { updateAppearance() }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    public init(action: ConversionAction) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 42))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = false

        registerForDraggedTypes([.fileURL])

        // Tracking area for hover
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

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        var label = action.outputExtension.uppercased()
        if label.isEmpty {
            label = action.displayName
        }
        titleLabel.stringValue = label
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            heightAnchor.constraint(equalToConstant: 42),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        let accent = ThemeManager.shared.accentColor

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true

            if isDraggingOver {
                // Magnified state on drag hover!
                layer?.transform = CATransform3DMakeScale(1.18, 1.18, 1.0)
                layer?.backgroundColor = accent.withAlphaComponent(0.4).cgColor
                layer?.borderColor = accent.cgColor
                layer?.borderWidth = 2.5
                layer?.shadowColor = accent.cgColor
                layer?.shadowOpacity = 0.8
                layer?.shadowRadius = 8
                layer?.shadowOffset = .zero
                titleLabel.textColor = .white
                iconView.contentTintColor = .white
            } else if isHovered {
                layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
                layer?.backgroundColor = accent.withAlphaComponent(0.2).cgColor
                layer?.borderColor = accent.cgColor
                layer?.borderWidth = 1.8
                layer?.shadowOpacity = 0.4
                titleLabel.textColor = .labelColor
                iconView.contentTintColor = accent
            } else {
                layer?.transform = CATransform3DIdentity
                layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.65).cgColor
                layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
                layer?.borderWidth = 1.0
                layer?.shadowOpacity = 0.15
                layer?.shadowRadius = 4
                layer?.shadowOffset = CGSize(width: 0, height: -2)
                titleLabel.textColor = .labelColor
                iconView.contentTintColor = .secondaryLabelColor
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

    // MARK: - NSDraggingDestination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let items = sender.draggingPasteboard.pasteboardItems, !items.isEmpty else {
            return []
        }
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
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        var urls: [URL] = []
        for item in items {
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            onDrop?(action, urls)
            return true
        }
        return false
    }
}
