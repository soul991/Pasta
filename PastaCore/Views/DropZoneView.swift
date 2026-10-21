import Foundation
import AppKit

public final class DropZoneView: NSView {
    public var onFilesSelected: (([URL]) -> Void)?

    private var isDraggingOver: Bool = false {
        didSet { needsDisplay = true }
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Drop files here to convert")
    private let subtitleLabel = NSTextField(labelWithString: "or click anywhere to browse")

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        registerForDraggedTypes([.fileURL])

        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil) {
            iconView.image = img
            iconView.contentTintColor = ThemeManager.shared.accentColor
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center

        let stack = NSStackView(views: [iconView, titleLabel, subtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8

        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        iconView.contentTintColor = ThemeManager.shared.accentColor
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: inset, xRadius: 12, yRadius: 12)

        let accent = ThemeManager.shared.accentColor

        if isDraggingOver {
            accent.withAlphaComponent(0.12).setFill()
            path.fill()

            accent.setStroke()
            let pattern: [CGFloat] = [8, 4]
            path.setLineDash(pattern, count: 2, phase: 0)
            path.lineWidth = 2.5
            path.stroke()
        } else {
            NSColor.controlBackgroundColor.withAlphaComponent(0.4).setFill()
            path.fill()

            NSColor.separatorColor.withAlphaComponent(0.8).setStroke()
            let pattern: [CGFloat] = [6, 4]
            path.setLineDash(pattern, count: 2, phase: 0)
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Choose"

        openPanel.begin { [weak self] response in
            if response == .OK {
                self?.onFilesSelected?(openPanel.urls)
            }
        }
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
            onFilesSelected?(urls)
            return true
        }
        return false
    }
}
