import AppKit

/// Public-AppKit glass surface with a visual-effect fallback for macOS 13–25.
/// The system handles Reduce Transparency and Increase Contrast on macOS 26+.
public final class SystemGlassSurfaceView: NSView {
    public private(set) var usesSystemGlass = false
    private let fallback = NSVisualEffectView()
    private var glass: NSView?

    public init(cornerRadius: CGFloat, tintColor: NSColor? = nil, isInteractive: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        configure(cornerRadius: cornerRadius, tintColor: tintColor, isInteractive: isInteractive)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(cornerRadius: 0, tintColor: nil, isInteractive: false)
    }

    public func configure(cornerRadius: CGFloat, tintColor: NSColor?, isInteractive: Bool) {
        let shouldUseSystemGlass = !ThemeManager.shared.isReduceTransparency
        if #available(macOS 26, *), shouldUseSystemGlass {
            let systemGlass: NSGlassEffectView
            if let existing = glass as? NSGlassEffectView {
                systemGlass = existing
            } else {
                systemGlass = NSGlassEffectView()
                systemGlass.translatesAutoresizingMaskIntoConstraints = false
                addSubview(systemGlass)
                NSLayoutConstraint.activate([
                    systemGlass.leadingAnchor.constraint(equalTo: leadingAnchor),
                    systemGlass.trailingAnchor.constraint(equalTo: trailingAnchor),
                    systemGlass.topAnchor.constraint(equalTo: topAnchor),
                    systemGlass.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
                glass = systemGlass
            }
            systemGlass.cornerRadius = cornerRadius
            systemGlass.tintColor = tintColor
            systemGlass.style = .regular
            #if compiler(>=6.4)
            if #available(macOS 27, *) {
                systemGlass.effectIsInteractive = isInteractive
            }
            #endif
            fallback.isHidden = true
            usesSystemGlass = true
        } else {
            fallback.translatesAutoresizingMaskIntoConstraints = false
            fallback.blendingMode = .behindWindow
            fallback.material = .hudWindow
            fallback.state = .active
            fallback.wantsLayer = true
            fallback.layer?.cornerRadius = cornerRadius
            fallback.layer?.masksToBounds = true
            if fallback.superview == nil {
                addSubview(fallback)
                NSLayoutConstraint.activate([
                    fallback.leadingAnchor.constraint(equalTo: leadingAnchor),
                    fallback.trailingAnchor.constraint(equalTo: trailingAnchor),
                    fallback.topAnchor.constraint(equalTo: topAnchor),
                    fallback.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
            }
            glass?.isHidden = true
            fallback.isHidden = false
            usesSystemGlass = false
        }
    }
}

/// Groups nearby system glass surfaces so AppKit can merge and batch-render them.
@available(macOS 26, *)
public final class SystemGlassContainerView: NSGlassEffectContainerView {
    public init(spacing: CGFloat = 8) {
        super.init(frame: .zero)
        self.spacing = spacing
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
