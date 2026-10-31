import Foundation
import AppKit

public final class RadialWheelMoreView: NSView {
    public var onSelectAction: ((ConversionAction) -> Void)?
    public var onCloseRequested: (() -> Void)?

    private var allActions: [ConversionAction] = []
    private var filteredActions: [ConversionAction] = []
    private var currentPage: Int = 0
    private let pageSize: Int = 8

    private let visualEffect = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "More Tools")
    private let searchField = NSSearchField()
    private let closeBtn = NSButton()
    private let pageControlLabel = NSTextField(labelWithString: "Page 1 of 1")
    private let prevPageBtn = NSButton(title: "◀", target: nil, action: nil)
    private let nextPageBtn = NSButton(title: "▶", target: nil, action: nil)
    private var actionButtons: [NSButton] = []

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 400))
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1.0
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.20).cgColor
        addSubview(visualEffect)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        // Close button (×)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.title = "✕"
        closeBtn.isBordered = false
        closeBtn.target = self
        closeBtn.action = #selector(closeClicked)
        addSubview(closeBtn)

        // Quick filter search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter tools..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.wantsLayer = true
        addSubview(searchField)

        // Page controls
        prevPageBtn.translatesAutoresizingMaskIntoConstraints = false
        prevPageBtn.bezelStyle = .inline
        prevPageBtn.target = self
        prevPageBtn.action = #selector(prevPageClicked)
        addSubview(prevPageBtn)

        pageControlLabel.translatesAutoresizingMaskIntoConstraints = false
        pageControlLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        pageControlLabel.textColor = ThemeManager.shared.textSecondaryColor
        pageControlLabel.alignment = .center
        addSubview(pageControlLabel)

        nextPageBtn.translatesAutoresizingMaskIntoConstraints = false
        nextPageBtn.bezelStyle = .inline
        nextPageBtn.target = self
        nextPageBtn.action = #selector(nextPageClicked)
        addSubview(nextPageBtn)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24),

            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            prevPageBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            prevPageBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            pageControlLabel.centerYAnchor.constraint(equalTo: prevPageBtn.centerYAnchor),
            pageControlLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            nextPageBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            nextPageBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    public func configure(actions: [ConversionAction]) {
        self.allActions = actions
        self.filteredActions = actions
        self.currentPage = 0
        renderPage()
    }

    @objc private func closeClicked() {
        onCloseRequested?()
    }

    @objc private func searchChanged() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredActions = allActions
        } else {
            filteredActions = allActions.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.outputExtension.lowercased().contains(query) ||
                $0.id.lowercased().contains(query)
            }
        }
        currentPage = 0
        renderPage()
    }

    @objc private func prevPageClicked() {
        if currentPage > 0 {
            currentPage -= 1
            renderPage()
        }
    }

    @objc private func nextPageClicked() {
        let totalPages = max(1, Int(ceil(Double(filteredActions.count) / Double(pageSize))))
        if currentPage < totalPages - 1 {
            currentPage += 1
            renderPage()
        }
    }

    private func renderPage() {
        actionButtons.forEach { $0.removeFromSuperview() }
        actionButtons.removeAll()

        let totalPages = max(1, Int(ceil(Double(filteredActions.count) / Double(pageSize))))
        pageControlLabel.stringValue = "Page \(currentPage + 1) of \(totalPages)"
        prevPageBtn.isEnabled = currentPage > 0
        nextPageBtn.isEnabled = currentPage < totalPages - 1

        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, filteredActions.count)
        guard startIndex < endIndex else { return }

        let pageItems = Array(filteredActions[startIndex..<endIndex])

        let startY: CGFloat = 80.0
        let itemHeight: CGFloat = 32.0
        let itemSpacing: CGFloat = 6.0

        for (i, action) in pageItems.enumerated() {
            let btn = NSButton(frame: NSRect(
                x: 14,
                y: bounds.height - startY - (CGFloat(i + 1) * (itemHeight + itemSpacing)),
                width: bounds.width - 28,
                height: itemHeight
            ))
            btn.title = "  \(action.displayName) (\(action.outputExtension.uppercased()))"
            if let img = NSImage(systemSymbolName: action.iconName, accessibilityDescription: nil) {
                btn.image = img
            }
            btn.imagePosition = .imageLeading
            btn.alignment = .left
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 8
            btn.layer?.backgroundColor = NSColor(white: 0.18, alpha: 0.7).cgColor
            btn.contentTintColor = .white
            btn.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            btn.target = self
            btn.action = #selector(itemClicked(_:))
            btn.tag = startIndex + i

            addSubview(btn)
            actionButtons.append(btn)
        }
    }

    @objc private func itemClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < filteredActions.count else { return }
        onSelectAction?(filteredActions[index])
    }
}
