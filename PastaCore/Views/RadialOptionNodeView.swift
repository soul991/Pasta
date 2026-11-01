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
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    private let defaultTextShadow: NSShadow = {
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.65)
        s.shadowOffset = NSSize(width: 0, height: -1)
        s.shadowBlurRadius = 2.0
        return s
    }()

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

        // Gradient Layer for active node
        gradientLayer.frame = NSRect(x: 0, y: 0, width: 64, height: 64)
        gradientLayer.cornerRadius = 32
        gradientLayer.masksToBounds = true
        gradientLayer.isHidden = true
        visualEffect.layer?.addSublayer(gradientLayer)

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

        // Title Label directly on glass below glyph with subtle text shadow
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let labelText: String
        switch slotKind {
        case .action(let action):
            labelText = action.shortHumanName
        case .more:
            labelText = "More"
        case .customize:
            labelText = "Settings"
        }
        titleLabel.stringValue = labelText
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.shadow = defaultTextShadow
        addSubview(titleLabel)

        // Accessibility attributes for VoiceOver
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        switch slotKind {
        case .action(let act):
            setAccessibilityLabel(act.displayName)
            setAccessibilityHelp("Convert file to \(act.outputExtension.uppercased())")
        case .more:
            setAccessibilityLabel("More Tools")
            setAccessibilityHelp("Open full categorized tools list")
        case .customize:
            setAccessibilityLabel("Customize Wheel")
            setAccessibilityHelp("Open wheel customization settings")
        }

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6)
        ])

        updateState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    public override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.width / 2.0
    }

    @objc private func themeChanged() {
        updateState()
    }

    private func updateState() {
        let accent = ThemeManager.shared.accentColor
        let darkInk = NSColor(hex: "#1A0F05") ?? .black
        let maxScale = ThemeManager.shared.maxHoverScale // 1.06
        let minScale = ThemeManager.shared.minHoverScale // 1.00

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled
        let isIncreaseContrast = PreferencesManager.shared.increaseContrastEnabled
        let isReduceTransparency = PreferencesManager.shared.reduceTransparencyEnabled

        // Label visibility mode
        let labelMode = WheelLayoutModel.shared.labelMode
        switch labelMode {
        case .always:
            titleLabel.isHidden = false
        case .onHover:
            titleLabel.isHidden = !(isHovered || isDraggingOver || isKeyFocused)
        }

        if isIncreaseContrast {
            titleLabel.isHidden = false
        }

        // Reduce Transparency: Use opaque dark background
        if isReduceTransparency {
            visualEffect.isHidden = true
            layer?.backgroundColor = ThemeManager.shared.reduceTransparencyBackground.cgColor
        } else {
            visualEffect.isHidden = false
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        let duration = isReduceMotion ? 0.0 : 0.16
        let isActive = isDraggingOver || isKeyFocused || isHovered

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.allowsImplicitAnimation = !isReduceMotion

            if isActive {
                // Active node: Accent gradient fill, dark ink label, glow fully inside panel
                let scale = (isDraggingOver || isKeyFocused) ? maxScale : ((minScale + maxScale) / 2.0)
                layer?.transform = CATransform3DMakeScale(scale, scale, 1.0)

                let topColor = (accent.blended(withFraction: 0.18, of: .white) ?? accent).cgColor
                let bottomColor = (accent.blended(withFraction: 0.16, of: .black) ?? accent).cgColor
                gradientLayer.colors = [topColor, bottomColor]
                gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
                gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
                gradientLayer.isHidden = false

                layer?.borderColor = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderColor.cgColor : NSColor.white.withAlphaComponent(0.90).cgColor
                layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.5

                // 14pt glow radius stays fully within the 28pt margin between node edge (172) and backplate rim (200)
                layer?.shadowColor = isReduceMotion ? nil : accent.cgColor
                layer?.shadowOpacity = isReduceMotion ? 0.0 : 0.40
                layer?.shadowRadius = 14.0
                layer?.shadowOffset = .zero

                titleLabel.textColor = darkInk
                iconView.contentTintColor = darkInk
                titleLabel.shadow = nil
            } else {
                // Idle state: glass disc, subtle text shadow, 1.00 scale
                layer?.transform = CATransform3DIdentity
                gradientLayer.isHidden = true
                visualEffect.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.75).cgColor
                layer?.borderColor = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderColor.cgColor : NSColor(white: 1.0, alpha: 0.20).cgColor
                layer?.borderWidth = isIncreaseContrast ? ThemeManager.shared.increaseContrastBorderWidth : 1.0
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.25
                layer?.shadowRadius = 4
                layer?.shadowOffset = CGSize(width: 0, height: -2)

                titleLabel.textColor = .white
                iconView.contentTintColor = .white
                titleLabel.shadow = defaultTextShadow
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

    // MARK: - Testing Helpers
    public var testTitleLabel: NSTextField { titleLabel }
    public var testHasDarkScrimView: Bool {
        return subviews.contains { $0 != titleLabel && $0 != iconView && $0 != visualEffect }
    }
    public var testGradientIsActive: Bool { !gradientLayer.isHidden }
    public var testTitleTextColor: NSColor { titleLabel.textColor ?? .clear }
    public var testTitleShadow: NSShadow? { titleLabel.shadow }
    public var testShadowRadius: CGFloat { layer?.shadowRadius ?? 0 }
}
