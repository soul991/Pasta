import Foundation
import AppKit

public final class DropWindowViewController: NSViewController {
    public private(set) var selectedFiles: [URL] = []
    public var files: [URL] { selectedFiles }
    private var isAdvancedMode: Bool = false

    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "Pasta")
    private let modeSegmentedControl = NSSegmentedControl(labels: ["Standard", "Advanced"], trackingMode: .selectOne, target: nil, action: nil)

    // Accent color palette
    private let paletteStack = NSStackView()

    // Main views
    private let dropZone = DropZoneView()
    private let actionsContainer = NSView()
    private let actionsScrollView = NSScrollView()
    private let actionsStack = NSStackView()
    private let parameterPanelContainer = NSView()
    public private(set) var activeParameterPanel: ParameterPanelView?

    private let filesSummaryLabel = NSTextField(labelWithString: "")
    private let clearFilesButton = NSButton(title: "Clear", target: nil, action: nil)

    // Job history/results
    private let jobsScrollView = NSScrollView()
    public let jobsStack = NSStackView()

    private var actionsContainerHeightConstraint: NSLayoutConstraint?

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 520))
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPalette()
    }

    private func setupUI() {
        // Visual effect backdrop
        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .sidebar
        visualEffect.state = .active
        view.addSubview(visualEffect, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Header
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        headerView.addSubview(titleLabel)

        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.selectedSegment = 0
        modeSegmentedControl.target = self
        modeSegmentedControl.action = #selector(modeChanged)
        headerView.addSubview(modeSegmentedControl)

        paletteStack.translatesAutoresizingMaskIntoConstraints = false
        paletteStack.orientation = .horizontal
        paletteStack.spacing = 6
        paletteStack.alignment = .centerY
        headerView.addSubview(paletteStack)

        // Drop Zone
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.onFilesSelected = { [weak self] urls in
            self?.handleFilesDropped(urls)
        }
        view.addSubview(dropZone)

        // Actions Container
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        actionsContainer.isHidden = true
        view.addSubview(actionsContainer)

        filesSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        filesSummaryLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        filesSummaryLabel.textColor = .secondaryLabelColor
        actionsContainer.addSubview(filesSummaryLabel)

        clearFilesButton.translatesAutoresizingMaskIntoConstraints = false
        clearFilesButton.bezelStyle = .inline
        clearFilesButton.target = self
        clearFilesButton.action = #selector(clearFilesClicked)
        actionsContainer.addSubview(clearFilesButton)

        actionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        actionsScrollView.hasVerticalScroller = true
        actionsScrollView.drawsBackground = false
        actionsContainer.addSubview(actionsScrollView)

        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.orientation = .vertical
        actionsStack.spacing = 8
        actionsStack.alignment = .leading
        actionsScrollView.documentView = actionsStack

        // Parameter Panel Container (inline configuration)
        parameterPanelContainer.translatesAutoresizingMaskIntoConstraints = false
        parameterPanelContainer.isHidden = true
        actionsContainer.addSubview(parameterPanelContainer)

        // Jobs ScrollView
        jobsScrollView.translatesAutoresizingMaskIntoConstraints = false
        jobsScrollView.hasVerticalScroller = true
        jobsScrollView.drawsBackground = false
        view.addSubview(jobsScrollView)

        jobsStack.translatesAutoresizingMaskIntoConstraints = false
        jobsStack.orientation = .vertical
        jobsStack.spacing = 6
        jobsStack.alignment = .width
        jobsScrollView.documentView = jobsStack

        let containerHeight = actionsContainer.heightAnchor.constraint(equalToConstant: 140)
        self.actionsContainerHeightConstraint = containerHeight

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            paletteStack.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 14),
            paletteStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            modeSegmentedControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            modeSegmentedControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Drop zone
            dropZone.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            dropZone.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dropZone.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dropZone.heightAnchor.constraint(equalToConstant: 120),

            // Actions Container
            actionsContainer.topAnchor.constraint(equalTo: dropZone.bottomAnchor, constant: 10),
            actionsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerHeight,

            filesSummaryLabel.topAnchor.constraint(equalTo: actionsContainer.topAnchor, constant: 4),
            filesSummaryLabel.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),

            clearFilesButton.centerYAnchor.constraint(equalTo: filesSummaryLabel.centerYAnchor),
            clearFilesButton.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),

            actionsScrollView.topAnchor.constraint(equalTo: filesSummaryLabel.bottomAnchor, constant: 8),
            actionsScrollView.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            actionsScrollView.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),
            actionsScrollView.bottomAnchor.constraint(equalTo: actionsContainer.bottomAnchor),

            actionsStack.leadingAnchor.constraint(equalTo: actionsScrollView.contentView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsScrollView.contentView.trailingAnchor),

            // Parameter Panel Container constraints
            parameterPanelContainer.topAnchor.constraint(equalTo: actionsContainer.topAnchor),
            parameterPanelContainer.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            parameterPanelContainer.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),
            parameterPanelContainer.bottomAnchor.constraint(equalTo: actionsContainer.bottomAnchor),

            // Jobs ScrollView
            jobsScrollView.topAnchor.constraint(equalTo: actionsContainer.bottomAnchor, constant: 10),
            jobsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            jobsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            jobsScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            jobsStack.leadingAnchor.constraint(equalTo: jobsScrollView.contentView.leadingAnchor),
            jobsStack.trailingAnchor.constraint(equalTo: jobsScrollView.contentView.trailingAnchor)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.didChangeThemeNotification,
            object: nil
        )
    }

    private func setupPalette() {
        paletteStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for preset in ThemeManager.shared.presets {
            let dot = NSButton(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 9
            dot.layer?.masksToBounds = true
            let color = NSColor(hex: preset.hex) ?? .orange
            dot.layer?.backgroundColor = color.cgColor
            dot.isBordered = false
            dot.title = ""
            dot.toolTip = preset.name
            dot.target = self
            dot.action = #selector(presetClicked(_:))
            dot.identifier = NSUserInterfaceItemIdentifier(preset.hex)

            if ThemeManager.shared.currentHex.uppercased() == preset.hex.uppercased() {
                dot.layer?.borderWidth = 2.5
                dot.layer?.borderColor = NSColor.white.cgColor
            }

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 18),
                dot.heightAnchor.constraint(equalToConstant: 18)
            ])
            paletteStack.addArrangedSubview(dot)
        }
    }

    @objc private func presetClicked(_ sender: NSButton) {
        guard let hex = sender.identifier?.rawValue else { return }
        ThemeManager.shared.setAccentHex(hex)
    }

    @objc private func themeDidChange() {
        setupPalette()
    }

    @objc private func modeChanged() {
        isAdvancedMode = (modeSegmentedControl.selectedSegment == 1)
        updateAvailableActions()
    }

    @objc private func clearFilesClicked() {
        hideParameterPanel()
        selectedFiles.removeAll()
        actionsContainer.isHidden = true
    }

    public func handleFilesDropped(_ urls: [URL]) {
        self.selectedFiles = urls
        hideParameterPanel()
        if urls.count == 1 {
            filesSummaryLabel.stringValue = "Selected: \(urls[0].lastPathComponent)"
        } else {
            filesSummaryLabel.stringValue = "\(urls.count) Files Selected"
        }
        actionsContainer.isHidden = false
        updateAvailableActions()
    }

    private func updateAvailableActions() {
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let firstFile = selectedFiles.first else { return }

        let actions = FormatRegistry.shared.actions(for: firstFile, isOptionHeld: isAdvancedMode)
        if actions.isEmpty {
            let label = NSTextField(labelWithString: "No actions available for this file type.")
            label.font = NSFont.systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            actionsStack.addArrangedSubview(label)
            return
        }

        // Display actions in rows of chips
        var currentRowStack = NSStackView()
        currentRowStack.orientation = .horizontal
        currentRowStack.spacing = 8
        actionsStack.addArrangedSubview(currentRowStack)

        var countInRow = 0
        for action in actions {
            let chip = FormatChipView(action: action)
            chip.onSelect = { [weak self] act in
                self?.selectAction(act)
            }
            chip.onFileDropped = { [weak self] act, droppedURLs in
                self?.handleFilesDropped(droppedURLs)
                self?.selectAction(act)
            }

            if countInRow >= 3 {
                currentRowStack = NSStackView()
                currentRowStack.orientation = .horizontal
                currentRowStack.spacing = 8
                actionsStack.addArrangedSubview(currentRowStack)
                countInRow = 0
            }

            currentRowStack.addArrangedSubview(chip)
            countInRow += 1
        }
    }

    public func selectAction(_ action: ConversionAction) {
        if action.parameters.isEmpty {
            executeConversion(action: action, params: [:])
        } else {
            showParameterPanel(for: action)
        }
    }

    public func showParameterPanel(for action: ConversionAction) {
        activeParameterPanel?.removeFromSuperview()

        let model = ParameterFormModel(
            action: action,
            loadLastUsed: true,
            inputFile: selectedFiles.first
        )
        let panel = ParameterPanelView(model: model, action: action)
        panel.translatesAutoresizingMaskIntoConstraints = false
        self.activeParameterPanel = panel

        panel.onCancel = { [weak self] in
            self?.hideParameterPanel()
        }

        panel.onRun = { [weak self, weak model] params in
            guard let self = self else { return }
            model?.saveAsLastUsed()
            self.hideParameterPanel()
            self.executeConversion(action: action, params: params)
        }

        parameterPanelContainer.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: parameterPanelContainer.topAnchor),
            panel.leadingAnchor.constraint(equalTo: parameterPanelContainer.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: parameterPanelContainer.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: parameterPanelContainer.bottomAnchor)
        ])

        actionsScrollView.isHidden = true
        filesSummaryLabel.isHidden = true
        clearFilesButton.isHidden = true
        parameterPanelContainer.isHidden = false
        actionsContainerHeightConstraint?.constant = 320
        view.layoutSubtreeIfNeeded()
    }

    public func hideParameterPanel() {
        activeParameterPanel?.removeFromSuperview()
        activeParameterPanel = nil
        parameterPanelContainer.isHidden = true
        actionsContainerHeightConstraint?.constant = 140
        actionsScrollView.isHidden = false
        filesSummaryLabel.isHidden = false
        clearFilesButton.isHidden = false
        view.layoutSubtreeIfNeeded()
    }

    public func executeConversion(action: ConversionAction, params: ParameterValues = [:]) {
        guard !selectedFiles.isEmpty else { return }

        let files = self.selectedFiles
        let count = files.count

        if count > 1 {
            // Batch execution
            let batchRow = BatchProgressRowView(totalCount: count, action: action)
            jobsStack.insertArrangedSubview(batchRow, at: 0)

            var completed = 0
            var failed = 0
            var activeJobIDs: [UUID] = []
            let lock = NSLock()

            batchRow.onCancel = {
                lock.lock()
                defer { lock.unlock() }
                for jid in activeJobIDs {
                    JobRunner.shared.cancel(jobId: jid)
                }
            }

            for file in files {
                let jobID = UUID()
                lock.lock()
                activeJobIDs.append(jobID)
                lock.unlock()

                let row = JobStatusRowView(inputURL: file, action: action)
                jobsStack.insertArrangedSubview(row, at: 1)
                row.update(state: .running)

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let output = try JobRunner.shared.run(
                            action: action,
                            input: file,
                            parameters: params,
                            jobId: jobID
                        )
                        row.update(state: .completed(output))
                        lock.lock()
                        completed += 1
                        let c = completed
                        let f = failed
                        lock.unlock()
                        batchRow.update(completed: c, failed: f)
                    } catch {
                        row.update(state: .failed(error.localizedDescription))
                        lock.lock()
                        failed += 1
                        let c = completed
                        let f = failed
                        lock.unlock()
                        batchRow.update(completed: c, failed: f)
                    }
                }
            }
        } else if let file = files.first {
            // Single file execution
            let row = JobStatusRowView(inputURL: file, action: action)
            jobsStack.insertArrangedSubview(row, at: 0)
            row.update(state: .running)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let output = try JobRunner.shared.run(
                        action: action,
                        input: file,
                        parameters: params
                    )
                    row.update(state: .completed(output))
                } catch {
                    row.update(state: .failed(error.localizedDescription))
                }
            }
        }
    }
}
