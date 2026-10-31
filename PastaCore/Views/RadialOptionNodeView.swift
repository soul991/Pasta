import Foundation
import AppKit
import QuartzCore

public final class RadialOptionNodeView: NSView {
    public let slotKind: WheelSlotKind
    public var onSelect: ((WheelSlotKind) -> Void)?
    public var onDrop: ((WheelSlotKind, [URL]) -> Void)?
    public var onHoverChanged: ((Bool) -> Void)?

    private var isDraggingOver: Bool = false {
        didSet { updateState() }
    }
    private var isHovered: Bool = false {
        didSet {
            updateState()
            onHoverChanged?(isHovered || isDraggingOver)
        }
    }

    private let visualEffect = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let scrimView = NSView()

    public var isKeyFocused: Bool = false {
        didSet {
            if oldValue != isKeyFocused {
                updateState()
            }
        }
    }

    public func performSelect() {
        onSelect?(slotKind)
    }

    public init(slotKind: WheelSlotKind) {
        self.slotKind = slotKind
        super.init(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        setupView()
    }

    // Convenience initializer for standard action
    public convenience init(action: ConversionAction) {
        self.init(slotKind: .action(action))
    }

    public var action: ConversionAction? {
        if case .action(let act) = slotKind {
            return act
        }
        return nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 32
        layer?.masksToBounds = false

        registerForDraggedTypes([.fileURL])

        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)

        // Visual effect glass base
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 32
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        switch slotKind {
        case .action(let action):
            if let img = NSImage(systemSymbolName: action.iconName, accessibilityDescription: action.displayName) {
                iconView.image = img
            } else {
                iconView.image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)
            }
        case .more:
            iconView.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More tools")
        case .customize:
            iconView.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Customize wheel")
        }
        iconView.contentTintColor = .white
        addSubview(iconView)

        // Title Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let labelText: String
        switch slotKind {
        case .action(let action):
            labelText = action.outputExtension.isEmpty ? action.displayName : action.outputExtension.uppercased()
        case .more:
            labelText = "More"
        case .customize:
            labelText = "Settings"
        }
        titleLabel.stringValue = labelText
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        // Subtle adaptive scrim behind label for legibility over bright/red wallpapers
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        scrimView.wantsLayer = true
        scrimView.layer?.cornerRadius = 4
        scrimView.layer?.masksToBounds = true
        scrimView.layer?.backgroundColor = NSColor(white: 0.0, alpha: ThemeManager.shared.adaptiveScrimAlpha).cgColor
        addSubview(scrimView)
        addSubview(titleLabel)

        // Accessibility attributes for VoiceOver
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        switch slotKind {
        case .action(let act):
            setAccessibilityLabel(act.displayName)
            setAccessibilityHelp("Convert file to \(act.outputExtension.uppercased())")
        case .more:
            setAccessibilityLabel("More conversion tools")
            setAccessibilityHelp("Opens additional conversion options")
        case .customize:
            setAccessibilityLabel("Customize wheel")
            setAccessibilityHelp("Opens appearance and tool customization sheet")
        }

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),

            scrimView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -2),
            scrimView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 2),
            scrimView.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -1),
            scrimView.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1)
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
        let contrastInk = WCAGContrast.contrastingLabelColor(for: accent)
        let maxScale = ThemeManager.shared.maxHoverScale // 1.06
        let minScale = ThemeManager.shared.minHoverScale // 1.00

        let isReduceMotion = ThemeManager.shared.isReduceMotion
        let isReduceTransparency = ThemeManager.shared.isReduceTransparency
        let isIncreaseContrast = ThemeManager.shared.isIncreaseContrast

        // Reduce Transparency: Use opaque dark background
        if isReduceTransparency {
            visualEffect.isHidden = true
            layer?.backgroundColor = ThemeManager.shared.reduceTransparencyBackground.cgColor
        } else {
            visualEffect.isHidden = false
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        // Handle label mode (Always vs On Hover)
        if WheelLayoutModel.shared.labelMode == .onHover {
            titleLabel.isHidden = !(isHovered || isDraggingOver || isKeyFocused)
        } else {
            titleLabel.isHidden = false
        }

        // Adaptive Scrim visibility
        scrimView.isHidden = titleLabel.isHidden || isReduceTransparency
        scrimView.layer?.backgroundColor = NSColor(white: 0.0, alpha: ThemeManager.shared.adaptiveScrimAlpha).cgColor

        let duration = isReduceMotion ? 0.0 : 0.16
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.allowsImplicitAnimation = !isReduceMotion

            if isDraggingOver || isKeyFocused {
                // Drag hover or keyboard focus: scale clamped to maximum 1.06
                layer?.transform = CATransform3DMakeScale(maxScale, maxScale, 1.0)
                visualEffect.layer?.backgroundColor = accent.cgColor
                layer?.borderColor = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderColor.cgColor : NSColor.white.cgColor
                layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 2.0
                layer?.shadowColor = isReduceMotion ? nil : accent.cgColor
                layer?.shadowOpacity = isReduceMotion ? 0.0 : 0.35 // Accent glow @ 0.35 alpha
                layer?.shadowRadius = WheelGeometry.maxGlowRadius // 18pt accent glow
                layer?.shadowOffset = .zero

                titleLabel.textColor = contrastInk
                iconView.contentTintColor = contrastInk
            } else if isHovered {
                // Subtle hover: 1.03 scale
                let hoverScale = (minScale + maxScale) / 2.0 // 1.03
                layer?.transform = CATransform3DMakeScale(hoverScale, hoverScale, 1.0)
                visualEffect.layer?.backgroundColor = accent.withAlphaComponent(0.35).cgColor
                layer?.borderColor = accent.cgColor
                layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.5
                layer?.shadowColor = isReduceMotion ? nil : accent.cgColor
                layer?.shadowOpacity = isReduceMotion ? 0.0 : 0.30
                layer?.shadowRadius = 8
                layer?.shadowOffset = .zero

                titleLabel.textColor = .white
                iconView.contentTintColor = accent
            } else {
                // Idle state: scale 1.00 exactly
                layer?.transform = CATransform3DIdentity
                visualEffect.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.75).cgColor
                layer?.borderColor = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderColor.cgColor : NSColor(white: 1.0, alpha: 0.20).cgColor
                layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.0
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.25
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
        onSelect?(slotKind)
    }

    // MARK: - Dragging Destination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDraggingOver = true
        onHoverChanged?(true)
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
        onHoverChanged?(false)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        onHoverChanged?(false)
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
            onDrop?(slotKind, urls)
            return true
        } else {
            onSelect?(slotKind)
            return true
        }
    }
}
