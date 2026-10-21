import Foundation
import AppKit

public final class DragOverlayViewController: NSViewController {
    public var onCloseRequested: (() -> Void)?

    private var targetFiles: [URL] = []
    private var isAdvanced: Bool = false

    private let visualEffectView = NSVisualEffectView()
    private let containerView = NSView()

    // Header
    private let headerStack = NSStackView()
    private let fileIconView = NSImageView()
    private let fileNameLabel = NSTextField(labelWithString: "")
    private let fileBadgeLabel = NSTextField(labelWithString: "")

    // Content areas
    private let chipsContainer = NSView()
    private let chipsStack = NSStackView()
    private let hudView = ConversionProgressHUDView()

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 260))
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Acrylic backdrop
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        view.addSubview(visualEffectView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.borderWidth = 1.8
        containerView.layer?.borderColor = ThemeManager.shared.accentColor.withAlphaComponent(0.6).cgColor
        containerView.layer?.masksToBounds = true
        view.addSubview(containerView)

        // Header
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .centerY
        containerView.addSubview(headerStack)

        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        fileIconView.image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)
        fileIconView.contentTintColor = ThemeManager.shared.accentColor

        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        fileNameLabel.textColor = .labelColor
        fileNameLabel.lineBreakMode = .byTruncatingMiddle

        fileBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        fileBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        fileBadgeLabel.textColor = .secondaryLabelColor

        headerStack.addArrangedSubview(fileIconView)
        headerStack.addArrangedSubview(fileNameLabel)
        headerStack.addArrangedSubview(fileBadgeLabel)

        // Chips Container
        chipsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chipsContainer)

        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.orientation = .vertical
        chipsStack.spacing = 8
        chipsStack.alignment = .centerX
        chipsContainer.addSubview(chipsStack)

        // HUD View
        hudView.translatesAutoresizingMaskIntoConstraints = false
        hudView.isHidden = true
        hudView.onDismiss = { [weak self] in
            self?.onCloseRequested?()
        }
        containerView.addSubview(hudView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),

            fileIconView.widthAnchor.constraint(equalToConstant: 18),
            fileIconView.heightAnchor.constraint(equalToConstant: 18),

            chipsContainer.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            chipsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            chipsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            chipsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),

            chipsStack.centerXAnchor.constraint(equalTo: chipsContainer.centerXAnchor),
            chipsStack.centerYAnchor.constraint(equalTo: chipsContainer.centerYAnchor),

            hudView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hudView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hudView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hudView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        containerView.layer?.borderColor = ThemeManager.shared.accentColor.withAlphaComponent(0.6).cgColor
        fileIconView.contentTintColor = ThemeManager.shared.accentColor
    }

    public func configure(files: [URL], isOptionHeld: Bool) {
        self.targetFiles = files
        self.isAdvanced = isOptionHeld

        guard let firstFile = files.first else { return }

        fileNameLabel.stringValue = firstFile.lastPathComponent
        fileBadgeLabel.stringValue = isOptionHeld ? "(Advanced Tools)" : ""

        hudView.isHidden = true
        chipsContainer.isHidden = false

        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let actions = FormatRegistry.shared.actions(for: firstFile, isOptionHeld: isOptionHeld)
        if actions.isEmpty {
            let label = NSTextField(labelWithString: "No actions available")
            label.font = NSFont.systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            chipsStack.addArrangedSubview(label)
            return
        }

        // Arrange chips in rows of 2 or 3
        let maxPerRow = actions.count > 4 ? 3 : 2
        var currentRow = NSStackView()
        currentRow.orientation = .horizontal
        currentRow.spacing = 8
        chipsStack.addArrangedSubview(currentRow)

        var count = 0
        for action in actions {
            let chip = OverlayChipView(action: action)
            chip.onSelect = { [weak self] act in
                self?.performConversion(action: act)
            }
            chip.onDrop = { [weak self] act, droppedFiles in
                self?.targetFiles = droppedFiles
                self?.performConversion(action: act)
            }

            if count >= maxPerRow {
                currentRow = NSStackView()
                currentRow.orientation = .horizontal
                currentRow.spacing = 8
                chipsStack.addArrangedSubview(currentRow)
                count = 0
            }

            currentRow.addArrangedSubview(chip)
            count += 1
        }

        // Adjust window size based on number of rows
        let rowCount = chipsStack.arrangedSubviews.count
        let calculatedHeight = CGFloat(70 + (rowCount * 50))
        let calculatedWidth: CGFloat = maxPerRow == 3 ? 360 : 310
        view.setFrameSize(NSSize(width: calculatedWidth, height: calculatedHeight))
    }

    private func performConversion(action: ConversionAction) {
        guard let file = targetFiles.first else { return }

        chipsContainer.isHidden = true
        hudView.isHidden = false
        hudView.showProgress(action: action, filename: file.lastPathComponent)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let output = try JobRunner.shared.run(action: action, input: file)
                DispatchQueue.main.async {
                    self?.hudView.showSuccess(outputURL: output)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hudView.showError(error.localizedDescription)
                }
            }
        }
    }
}
