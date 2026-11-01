import Foundation
import AppKit

public final class RadialWheelCustomizeSheet: NSView {
    public var onSettingsChanged: (() -> Void)?
    public var onCloseRequested: (() -> Void)?

    private let visualEffect = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "Customize Wheel")
    private let closeBtn = NSButton()
    private let sectionSegment = NSSegmentedControl()

    private let appearanceContainer = NSView()
    private let primaryToolsContainer = NSView()
    private let behaviorContainer = NSView()

    // Appearance controls
    private var themeButtons: [NSButton] = []
    private let selectedThemeNameLabel = NSTextField(labelWithString: "")
    private let glassStyleSegment = NSSegmentedControl()
    private let glassStrengthSlider = NSSlider()
    private let glassStrengthLabel = NSTextField(labelWithString: "Strength: 80%")
    private let sizeSegment = NSSegmentedControl()
    private let labelModeSegment = NSSegmentedControl()

    // Primary tools controls
    private let categorySegmentRow1 = NSSegmentedControl()
    private let categorySegmentRow2 = NSSegmentedControl()
    private let toolsStackView = NSStackView()
    private let addToolPicker = NSPopUpButton()
    private var selectedCategory: ActionCategory = .image

    // Behavior controls
    private let holdDurationSlider = NSSlider()
    private let holdDurationLabel = NSTextField(labelWithString: "Hold duration: 450 ms")
    private let keepOpenCheckbox = NSButton(checkboxWithTitle: "Keep wheel open after running", target: nil, action: nil)
    private let showRingCheckbox = NSButton(checkboxWithTitle: "Show charging progress ring", target: nil, action: nil)

    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
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

        // Header Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        // Close button (×)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.title = "✕"
        closeBtn.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        closeBtn.isBordered = false
        closeBtn.target = self
        closeBtn.action = #selector(closeClicked)
        addSubview(closeBtn)

        // Section Segmented Control: Appearance, Primary Tools, Behavior
        sectionSegment.translatesAutoresizingMaskIntoConstraints = false
        sectionSegment.segmentCount = 3
        sectionSegment.setLabel("Appearance", forSegment: 0)
        sectionSegment.setLabel("Primary Tools", forSegment: 1)
        sectionSegment.setLabel("Behavior", forSegment: 2)
        sectionSegment.selectedSegment = 0
        sectionSegment.target = self
        sectionSegment.action = #selector(sectionChanged)
        addSubview(sectionSegment)

        // Setup Section Containers
        appearanceContainer.translatesAutoresizingMaskIntoConstraints = false
        primaryToolsContainer.translatesAutoresizingMaskIntoConstraints = false
        behaviorContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appearanceContainer)
        addSubview(primaryToolsContainer)
        addSubview(behaviorContainer)

        primaryToolsContainer.isHidden = true
        behaviorContainer.isHidden = true

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),

            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),

            sectionSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            sectionSegment.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sectionSegment.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sectionSegment.heightAnchor.constraint(equalToConstant: 26),

            appearanceContainer.topAnchor.constraint(equalTo: sectionSegment.bottomAnchor, constant: 12),
            appearanceContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            appearanceContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            appearanceContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            primaryToolsContainer.topAnchor.constraint(equalTo: sectionSegment.bottomAnchor, constant: 12),
            primaryToolsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            primaryToolsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            primaryToolsContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            behaviorContainer.topAnchor.constraint(equalTo: sectionSegment.bottomAnchor, constant: 12),
            behaviorContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            behaviorContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            behaviorContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])

        setupAppearanceSection()
        setupPrimaryToolsSection()
        setupBehaviorSection()
    }

    // MARK: - Section 1: Appearance
    private func setupAppearanceSection() {
        let themeLabel = makeSectionLabel("Theme Accent")
        appearanceContainer.addSubview(themeLabel)

        let swatchesStack = NSStackView()
        swatchesStack.translatesAutoresizingMaskIntoConstraints = false
        swatchesStack.orientation = .horizontal
        swatchesStack.spacing = 10
        swatchesStack.alignment = .centerY
        appearanceContainer.addSubview(swatchesStack)

        themeButtons.removeAll()
        for theme in WheelTheme.allCases {
            let btn = NSButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.title = ""
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 15
            btn.layer?.backgroundColor = (NSColor(hex: theme.hex) ?? .orange).cgColor
            btn.layer?.borderWidth = (theme == WheelLayoutModel.shared.currentTheme) ? 2.5 : 1.0
            btn.layer?.borderColor = (theme == WheelLayoutModel.shared.currentTheme) ? NSColor.white.cgColor : NSColor(white: 1.0, alpha: 0.3).cgColor
            btn.target = self
            btn.action = #selector(themeSwatchClicked(_:))
            btn.tag = WheelTheme.allCases.firstIndex(of: theme) ?? 0
            swatchesStack.addArrangedSubview(btn)
            btn.widthAnchor.constraint(equalToConstant: 30).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            themeButtons.append(btn)
        }

        selectedThemeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        selectedThemeNameLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        selectedThemeNameLabel.textColor = WheelLayoutModel.shared.currentTheme.accentColor
        selectedThemeNameLabel.alignment = .center
        selectedThemeNameLabel.stringValue = "Theme: \(WheelLayoutModel.shared.currentTheme.displayName)"
        appearanceContainer.addSubview(selectedThemeNameLabel)

        let glassLabel = makeSectionLabel("Glass Style & Strength")
        appearanceContainer.addSubview(glassLabel)

        glassStyleSegment.translatesAutoresizingMaskIntoConstraints = false
        glassStyleSegment.segmentCount = 3
        glassStyleSegment.setLabel("Clear", forSegment: 0)
        glassStyleSegment.setLabel("Regular", forSegment: 1)
        glassStyleSegment.setLabel("Tinted", forSegment: 2)
        glassStyleSegment.segmentDistribution = .fillEqually
        switch WheelLayoutModel.shared.currentGlassStyle {
        case .clear: glassStyleSegment.selectedSegment = 0
        case .regular: glassStyleSegment.selectedSegment = 1
        case .tinted: glassStyleSegment.selectedSegment = 2
        }
        glassStyleSegment.target = self
        glassStyleSegment.action = #selector(glassStyleChanged)
        appearanceContainer.addSubview(glassStyleSegment)

        glassStrengthSlider.translatesAutoresizingMaskIntoConstraints = false
        glassStrengthSlider.minValue = 0.1
        glassStrengthSlider.maxValue = 1.0
        glassStrengthSlider.doubleValue = WheelLayoutModel.shared.glassStrength
        glassStrengthSlider.target = self
        glassStrengthSlider.action = #selector(glassStrengthChanged)
        appearanceContainer.addSubview(glassStrengthSlider)

        glassStrengthLabel.translatesAutoresizingMaskIntoConstraints = false
        glassStrengthLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        glassStrengthLabel.textColor = ThemeManager.shared.textSecondaryColor
        glassStrengthLabel.alignment = .right
        glassStrengthLabel.stringValue = "Strength: \(Int(WheelLayoutModel.shared.glassStrength * 100))%"
        appearanceContainer.addSubview(glassStrengthLabel)

        let sizeLabel = makeSectionLabel("Wheel Diameter")
        appearanceContainer.addSubview(sizeLabel)

        sizeSegment.translatesAutoresizingMaskIntoConstraints = false
        sizeSegment.segmentCount = 3
        sizeSegment.setLabel("340 pt", forSegment: 0)
        sizeSegment.setLabel("400 pt", forSegment: 1)
        sizeSegment.setLabel("460 pt", forSegment: 2)
        sizeSegment.segmentDistribution = .fillEqually
        switch WheelLayoutModel.shared.currentSize {
        case .compact: sizeSegment.selectedSegment = 0
        case .standard: sizeSegment.selectedSegment = 1
        case .large: sizeSegment.selectedSegment = 2
        }
        sizeSegment.target = self
        sizeSegment.action = #selector(sizeChanged)
        appearanceContainer.addSubview(sizeSegment)

        let labelModeLabel = makeSectionLabel("Labels")
        appearanceContainer.addSubview(labelModeLabel)

        labelModeSegment.translatesAutoresizingMaskIntoConstraints = false
        labelModeSegment.segmentCount = 2
        labelModeSegment.setLabel("Always Visible", forSegment: 0)
        labelModeSegment.setLabel("On Hover", forSegment: 1)
        labelModeSegment.segmentDistribution = .fillEqually
        labelModeSegment.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        switch WheelLayoutModel.shared.labelMode {
        case .always: labelModeSegment.selectedSegment = 0
        case .onHover: labelModeSegment.selectedSegment = 1
        }
        labelModeSegment.target = self
        labelModeSegment.action = #selector(labelModeChanged)
        appearanceContainer.addSubview(labelModeSegment)

        NSLayoutConstraint.activate([
            themeLabel.topAnchor.constraint(equalTo: appearanceContainer.topAnchor),
            themeLabel.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),

            swatchesStack.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 6),
            swatchesStack.centerXAnchor.constraint(equalTo: appearanceContainer.centerXAnchor),
            swatchesStack.heightAnchor.constraint(equalToConstant: 30),

            selectedThemeNameLabel.topAnchor.constraint(equalTo: swatchesStack.bottomAnchor, constant: 4),
            selectedThemeNameLabel.centerXAnchor.constraint(equalTo: appearanceContainer.centerXAnchor),

            glassLabel.topAnchor.constraint(equalTo: selectedThemeNameLabel.bottomAnchor, constant: 10),
            glassLabel.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),

            glassStyleSegment.topAnchor.constraint(equalTo: glassLabel.bottomAnchor, constant: 6),
            glassStyleSegment.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),
            glassStyleSegment.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor),

            glassStrengthSlider.topAnchor.constraint(equalTo: glassStyleSegment.bottomAnchor, constant: 8),
            glassStrengthSlider.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),
            glassStrengthSlider.trailingAnchor.constraint(equalTo: glassStrengthLabel.leadingAnchor, constant: -8),

            glassStrengthLabel.centerYAnchor.constraint(equalTo: glassStrengthSlider.centerYAnchor),
            glassStrengthLabel.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor),
            glassStrengthLabel.widthAnchor.constraint(equalToConstant: 100),

            sizeLabel.topAnchor.constraint(equalTo: glassStrengthSlider.bottomAnchor, constant: 10),
            sizeLabel.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),

            sizeSegment.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 6),
            sizeSegment.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),
            sizeSegment.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor),

            labelModeLabel.topAnchor.constraint(equalTo: sizeSegment.bottomAnchor, constant: 10),
            labelModeLabel.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),

            labelModeSegment.topAnchor.constraint(equalTo: labelModeLabel.bottomAnchor, constant: 6),
            labelModeSegment.leadingAnchor.constraint(equalTo: appearanceContainer.leadingAnchor),
            labelModeSegment.trailingAnchor.constraint(equalTo: appearanceContainer.trailingAnchor),
            labelModeSegment.bottomAnchor.constraint(lessThanOrEqualTo: appearanceContainer.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Section 2: Primary Tools
    private func setupPrimaryToolsSection() {
        categorySegmentRow1.translatesAutoresizingMaskIntoConstraints = false
        categorySegmentRow1.segmentCount = 3
        categorySegmentRow1.setLabel("Image", forSegment: 0)
        categorySegmentRow1.setLabel("Video", forSegment: 1)
        categorySegmentRow1.setLabel("Audio", forSegment: 2)
        categorySegmentRow1.segmentDistribution = .fillEqually
        categorySegmentRow1.selectedSegment = 0
        categorySegmentRow1.target = self
        categorySegmentRow1.action = #selector(categoryRow1Changed)
        primaryToolsContainer.addSubview(categorySegmentRow1)

        categorySegmentRow2.translatesAutoresizingMaskIntoConstraints = false
        categorySegmentRow2.segmentCount = 3
        categorySegmentRow2.setLabel("PDF", forSegment: 0)
        categorySegmentRow2.setLabel("Document", forSegment: 1)
        categorySegmentRow2.setLabel("Archive", forSegment: 2)
        categorySegmentRow2.segmentDistribution = .fillEqually
        categorySegmentRow2.selectedSegment = -1
        categorySegmentRow2.target = self
        categorySegmentRow2.action = #selector(categoryRow2Changed)
        primaryToolsContainer.addSubview(categorySegmentRow2)

        toolsStackView.translatesAutoresizingMaskIntoConstraints = false
        toolsStackView.orientation = .vertical
        toolsStackView.spacing = 6
        toolsStackView.distribution = .fillEqually
        primaryToolsContainer.addSubview(toolsStackView)

        addToolPicker.translatesAutoresizingMaskIntoConstraints = false
        addToolPicker.target = self
        addToolPicker.action = #selector(addToolPickerChanged)
        primaryToolsContainer.addSubview(addToolPicker)

        let resetBtn = NSButton(title: "Reset Category to Defaults", target: self, action: #selector(resetCategoryClicked))
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        resetBtn.bezelStyle = .rounded
        primaryToolsContainer.addSubview(resetBtn)

        NSLayoutConstraint.activate([
            categorySegmentRow1.topAnchor.constraint(equalTo: primaryToolsContainer.topAnchor),
            categorySegmentRow1.leadingAnchor.constraint(equalTo: primaryToolsContainer.leadingAnchor),
            categorySegmentRow1.trailingAnchor.constraint(equalTo: primaryToolsContainer.trailingAnchor),
            categorySegmentRow1.heightAnchor.constraint(equalToConstant: 24),

            categorySegmentRow2.topAnchor.constraint(equalTo: categorySegmentRow1.bottomAnchor, constant: 4),
            categorySegmentRow2.leadingAnchor.constraint(equalTo: primaryToolsContainer.leadingAnchor),
            categorySegmentRow2.trailingAnchor.constraint(equalTo: primaryToolsContainer.trailingAnchor),
            categorySegmentRow2.heightAnchor.constraint(equalToConstant: 24),

            toolsStackView.topAnchor.constraint(equalTo: categorySegmentRow2.bottomAnchor, constant: 10),
            toolsStackView.leadingAnchor.constraint(equalTo: primaryToolsContainer.leadingAnchor),
            toolsStackView.trailingAnchor.constraint(equalTo: primaryToolsContainer.trailingAnchor),

            addToolPicker.topAnchor.constraint(equalTo: toolsStackView.bottomAnchor, constant: 8),
            addToolPicker.leadingAnchor.constraint(equalTo: primaryToolsContainer.leadingAnchor),
            addToolPicker.trailingAnchor.constraint(equalTo: primaryToolsContainer.trailingAnchor),
            addToolPicker.heightAnchor.constraint(equalToConstant: 24),

            resetBtn.topAnchor.constraint(equalTo: addToolPicker.bottomAnchor, constant: 8),
            resetBtn.bottomAnchor.constraint(lessThanOrEqualTo: primaryToolsContainer.bottomAnchor),
            resetBtn.centerXAnchor.constraint(equalTo: primaryToolsContainer.centerXAnchor)
        ])

        reloadToolsList()
    }

    private func reloadToolsList() {
        toolsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let pinnedIDs = WheelLayoutModel.shared.pinnedToolIDs(for: selectedCategory)
        for (index, toolID) in pinnedIDs.enumerated() {
            let row = PinnedToolRowView(slotIndex: index, toolID: toolID)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 28).isActive = true
            row.onRemove = { [weak self] idx in
                guard let self = self else { return }
                WheelLayoutModel.shared.removePinnedTool(at: idx, in: self.selectedCategory)
                self.reloadToolsList()
                self.onSettingsChanged?()
            }
            row.onMoveUp = { [weak self] idx in
                guard let self = self else { return }
                if idx > 0 {
                    WheelLayoutModel.shared.reorderPinnedTool(from: idx, to: idx - 1, in: self.selectedCategory)
                    self.reloadToolsList()
                    self.onSettingsChanged?()
                }
            }
            row.onMoveDown = { [weak self] idx in
                guard let self = self else { return }
                let pinned = WheelLayoutModel.shared.pinnedToolIDs(for: self.selectedCategory)
                if idx < pinned.count - 1 {
                    WheelLayoutModel.shared.reorderPinnedTool(from: idx, to: idx + 1, in: self.selectedCategory)
                    self.reloadToolsList()
                    self.onSettingsChanged?()
                }
            }
            row.onReorder = { [weak self] fromIdx, toIdx in
                guard let self = self else { return }
                WheelLayoutModel.shared.reorderPinnedTool(from: fromIdx, to: toIdx, in: self.selectedCategory)
                self.reloadToolsList()
                self.onSettingsChanged?()
            }
            toolsStackView.addArrangedSubview(row)
        }

        // Update "Add Tool" picker items
        addToolPicker.removeAllItems()
        addToolPicker.addItem(withTitle: "＋ Add Tool to Wheel...")
        let unpinned = WheelLayoutModel.shared.unpinnedTools(for: selectedCategory)
        for act in unpinned {
            let item = NSMenuItem(title: act.shortHumanName, action: nil, keyEquivalent: "")
            item.representedObject = act.id
            if let img = NSImage(systemSymbolName: act.iconName, accessibilityDescription: nil) {
                img.size = NSSize(width: 14, height: 14)
                item.image = img
            }
            addToolPicker.menu?.addItem(item)
        }
        addToolPicker.isEnabled = !unpinned.isEmpty
    }

    // MARK: - Section 3: Behavior
    private func setupBehaviorSection() {
        let holdLabel = makeSectionLabel("Shift-Hold Duration")
        behaviorContainer.addSubview(holdLabel)

        holdDurationSlider.translatesAutoresizingMaskIntoConstraints = false
        holdDurationSlider.minValue = 300.0
        holdDurationSlider.maxValue = 1000.0
        holdDurationSlider.doubleValue = PreferencesManager.shared.shiftHoldDurationMs
        holdDurationSlider.target = self
        holdDurationSlider.action = #selector(holdDurationChanged)
        behaviorContainer.addSubview(holdDurationSlider)

        holdDurationLabel.translatesAutoresizingMaskIntoConstraints = false
        holdDurationLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        holdDurationLabel.textColor = ThemeManager.shared.textSecondaryColor
        holdDurationLabel.stringValue = "Hold duration: \(Int(PreferencesManager.shared.shiftHoldDurationMs)) ms"
        behaviorContainer.addSubview(holdDurationLabel)

        let wheelBehaviorLabel = makeSectionLabel("Wheel Retention & Ring")
        behaviorContainer.addSubview(wheelBehaviorLabel)

        keepOpenCheckbox.translatesAutoresizingMaskIntoConstraints = false
        keepOpenCheckbox.state = PreferencesManager.shared.keepWheelOpenAfterRunning ? .on : .off
        keepOpenCheckbox.target = self
        keepOpenCheckbox.action = #selector(keepOpenToggled)
        behaviorContainer.addSubview(keepOpenCheckbox)

        showRingCheckbox.translatesAutoresizingMaskIntoConstraints = false
        showRingCheckbox.state = PreferencesManager.shared.showChargingRing ? .on : .off
        showRingCheckbox.target = self
        showRingCheckbox.action = #selector(showRingToggled)
        behaviorContainer.addSubview(showRingCheckbox)

        NSLayoutConstraint.activate([
            holdLabel.topAnchor.constraint(equalTo: behaviorContainer.topAnchor),
            holdLabel.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),

            holdDurationSlider.topAnchor.constraint(equalTo: holdLabel.bottomAnchor, constant: 8),
            holdDurationSlider.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),
            holdDurationSlider.trailingAnchor.constraint(equalTo: behaviorContainer.trailingAnchor),

            holdDurationLabel.topAnchor.constraint(equalTo: holdDurationSlider.bottomAnchor, constant: 4),
            holdDurationLabel.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),

            wheelBehaviorLabel.topAnchor.constraint(equalTo: holdDurationLabel.bottomAnchor, constant: 20),
            wheelBehaviorLabel.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),

            keepOpenCheckbox.topAnchor.constraint(equalTo: wheelBehaviorLabel.bottomAnchor, constant: 8),
            keepOpenCheckbox.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),
            keepOpenCheckbox.trailingAnchor.constraint(equalTo: behaviorContainer.trailingAnchor),

            showRingCheckbox.topAnchor.constraint(equalTo: keepOpenCheckbox.bottomAnchor, constant: 8),
            showRingCheckbox.leadingAnchor.constraint(equalTo: behaviorContainer.leadingAnchor),
            showRingCheckbox.trailingAnchor.constraint(equalTo: behaviorContainer.trailingAnchor)
        ])
    }

    private func makeSectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = ThemeManager.shared.textSecondaryColor
        return label
    }

    // MARK: - Actions
    @objc private func closeClicked() {
        onCloseRequested?()
    }

    @objc private func sectionChanged() {
        appearanceContainer.isHidden = (sectionSegment.selectedSegment != 0)
        primaryToolsContainer.isHidden = (sectionSegment.selectedSegment != 1)
        behaviorContainer.isHidden = (sectionSegment.selectedSegment != 2)
    }

    @objc public func themeSwatchClicked(_ sender: NSButton) {
        let index = sender.tag
        let themes = WheelTheme.allCases
        guard index >= 0 && index < themes.count else { return }
        let theme = themes[index]
        WheelLayoutModel.shared.currentTheme = theme

        selectedThemeNameLabel.stringValue = "Theme: \(theme.displayName)"
        selectedThemeNameLabel.textColor = theme.accentColor

        for (i, btn) in themeButtons.enumerated() {
            let isSel = (i == index)
            btn.layer?.borderWidth = isSel ? 2.5 : 1.0
            btn.layer?.borderColor = isSel ? NSColor.white.cgColor : NSColor(white: 1.0, alpha: 0.3).cgColor
        }

        onSettingsChanged?()
    }

    @objc private func glassStyleChanged() {
        switch glassStyleSegment.selectedSegment {
        case 0: WheelLayoutModel.shared.currentGlassStyle = .clear
        case 1: WheelLayoutModel.shared.currentGlassStyle = .regular
        case 2: WheelLayoutModel.shared.currentGlassStyle = .tinted
        default: break
        }
        onSettingsChanged?()
    }

    @objc private func glassStrengthChanged() {
        let val = glassStrengthSlider.doubleValue
        WheelLayoutModel.shared.glassStrength = val
        glassStrengthLabel.stringValue = "Strength: \(Int(val * 100))%"
        onSettingsChanged?()
    }

    @objc private func sizeChanged() {
        switch sizeSegment.selectedSegment {
        case 0: WheelLayoutModel.shared.currentSize = .compact
        case 1: WheelLayoutModel.shared.currentSize = .standard
        case 2: WheelLayoutModel.shared.currentSize = .large
        default: break
        }
        onSettingsChanged?()
    }

    @objc private func labelModeChanged() {
        switch labelModeSegment.selectedSegment {
        case 0: WheelLayoutModel.shared.labelMode = .always
        case 1: WheelLayoutModel.shared.labelMode = .onHover
        default: break
        }
        onSettingsChanged?()
    }

    @objc private func categoryRow1Changed() {
        let idx = categorySegmentRow1.selectedSegment
        let row1Categories: [ActionCategory] = [.image, .video, .audio]
        if idx >= 0 && idx < row1Categories.count {
            categorySegmentRow2.selectedSegment = -1
            selectedCategory = row1Categories[idx]
            reloadToolsList()
        }
    }

    @objc private func categoryRow2Changed() {
        let idx = categorySegmentRow2.selectedSegment
        let row2Categories: [ActionCategory] = [.pdf, .document, .archive]
        if idx >= 0 && idx < row2Categories.count {
            categorySegmentRow1.selectedSegment = -1
            selectedCategory = row2Categories[idx]
            reloadToolsList()
        }
    }

    public func selectCategory(_ category: ActionCategory) {
        let row1: [ActionCategory] = [.image, .video, .audio]
        let row2: [ActionCategory] = [.pdf, .document, .archive]
        if let idx = row1.firstIndex(of: category) {
            categorySegmentRow1.selectedSegment = idx
            categorySegmentRow2.selectedSegment = -1
            selectedCategory = category
            reloadToolsList()
        } else if let idx = row2.firstIndex(of: category) {
            categorySegmentRow2.selectedSegment = idx
            categorySegmentRow1.selectedSegment = -1
            selectedCategory = category
            reloadToolsList()
        }
    }

    @objc private func removePinnedToolClicked(_ sender: NSButton) {
        let index = sender.tag
        WheelLayoutModel.shared.removePinnedTool(at: index, in: selectedCategory)
        reloadToolsList()
        onSettingsChanged?()
    }

    @objc private func addToolPickerChanged() {
        guard let item = addToolPicker.selectedItem, let toolID = item.representedObject as? String else {
            return
        }
        WheelLayoutModel.shared.addPinnedTool(toolID: toolID, in: selectedCategory)
        reloadToolsList()
        onSettingsChanged?()
    }

    @objc private func moveToolUpClicked(_ sender: NSButton) {
        let index = sender.tag
        if index > 0 {
            WheelLayoutModel.shared.reorderPinnedTool(from: index, to: index - 1, in: selectedCategory)
            reloadToolsList()
            onSettingsChanged?()
        }
    }

    @objc private func moveToolDownClicked(_ sender: NSButton) {
        let index = sender.tag
        let pinned = WheelLayoutModel.shared.pinnedToolIDs(for: selectedCategory)
        if index < pinned.count - 1 {
            WheelLayoutModel.shared.reorderPinnedTool(from: index, to: index + 1, in: selectedCategory)
            reloadToolsList()
            onSettingsChanged?()
        }
    }

    @objc private func resetCategoryClicked() {
        WheelLayoutModel.shared.resetToDefaults(for: selectedCategory)
        reloadToolsList()
        onSettingsChanged?()
    }

    @objc private func holdDurationChanged() {
        let val = holdDurationSlider.doubleValue
        PreferencesManager.shared.shiftHoldDurationMs = val
        holdDurationLabel.stringValue = "Hold duration: \(Int(val)) ms"
    }

    @objc private func keepOpenToggled() {
        PreferencesManager.shared.keepWheelOpenAfterRunning = (keepOpenCheckbox.state == .on)
    }

    @objc private func showRingToggled() {
        PreferencesManager.shared.showChargingRing = (showRingCheckbox.state == .on)
    }

    // MARK: - Testing Helpers
    public var testThemeButtons: [NSButton] { themeButtons }
    public var testSelectedThemeName: String { selectedThemeNameLabel.stringValue }
    public var testCategoryRow1Labels: [String] { (0..<categorySegmentRow1.segmentCount).compactMap { categorySegmentRow1.label(forSegment: $0) } }
    public var testCategoryRow2Labels: [String] { (0..<categorySegmentRow2.segmentCount).compactMap { categorySegmentRow2.label(forSegment: $0) } }
    public var testGlassStrengthText: String { glassStrengthLabel.stringValue }
    public var testLabelModeLabels: [String] { (0..<labelModeSegment.segmentCount).compactMap { labelModeSegment.label(forSegment: $0) } }
    public var pinnedToolRows: [PinnedToolRowView] {
        return toolsStackView.arrangedSubviews.compactMap { $0 as? PinnedToolRowView }
    }
    public func simulateDragReorder(from sourceIndex: Int, to destinationIndex: Int) {
        WheelLayoutModel.shared.reorderPinnedTool(from: sourceIndex, to: destinationIndex, in: selectedCategory)
        reloadToolsList()
        onSettingsChanged?()
    }
}

// MARK: - Pinned Tool Row View with Drag-to-Reorder

public final class PinnedToolRowView: NSView, NSDraggingSource {
    public static let dragType = NSPasteboard.PasteboardType("com.pasta.tool-row-index")

    public let slotIndex: Int
    public let toolID: String
    public var onReorder: ((Int, Int) -> Void)?
    public var onRemove: ((Int) -> Void)?
    public var onMoveUp: ((Int) -> Void)?
    public var onMoveDown: ((Int) -> Void)?

    private var dragStartLocation: NSPoint?

    public init(slotIndex: Int, toolID: String) {
        self.slotIndex = slotIndex
        self.toolID = toolID
        super.init(frame: .zero)
        setupRow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupRow() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.5).cgColor

        registerForDraggedTypes([PinnedToolRowView.dragType])

        let action = FormatRegistry.shared.action(byId: toolID)
        let humanName = action?.shortHumanName ?? toolID
        let iconName = action?.iconName ?? "doc.fill"

        // Drag handle indicator (three horizontal lines glyph)
        let dragHandle = NSImageView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        if let dragImg = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag to reorder") {
            dragHandle.image = dragImg
        }
        dragHandle.contentTintColor = NSColor(white: 0.6, alpha: 1.0)
        addSubview(dragHandle)

        // Index label: "1."
        let indexLabel = NSTextField(labelWithString: "\(slotIndex + 1).")
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        indexLabel.textColor = ThemeManager.shared.accentColor
        addSubview(indexLabel)

        // Glyph Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: humanName) {
            iconView.image = img
        } else {
            iconView.image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: humanName)
        }
        iconView.contentTintColor = .white
        addSubview(iconView)

        // Human display name: (MP4, MKV, WebM, GIF, Extract MP3)
        let nameLabel = NSTextField(labelWithString: humanName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        // "Remove from wheel" control
        let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removeClicked))
        removeBtn.translatesAutoresizingMaskIntoConstraints = false
        removeBtn.bezelStyle = .inline
        removeBtn.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        addSubview(removeBtn)

        let upBtn = NSButton(title: "▲", target: self, action: #selector(upClicked))
        upBtn.translatesAutoresizingMaskIntoConstraints = false
        upBtn.bezelStyle = .inline
        upBtn.isEnabled = (slotIndex > 0)
        addSubview(upBtn)

        let downBtn = NSButton(title: "▼", target: self, action: #selector(downClicked))
        downBtn.translatesAutoresizingMaskIntoConstraints = false
        downBtn.bezelStyle = .inline
        downBtn.isEnabled = (slotIndex < 5)
        addSubview(downBtn)

        NSLayoutConstraint.activate([
            dragHandle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            dragHandle.centerYAnchor.constraint(equalTo: centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 12),
            dragHandle.heightAnchor.constraint(equalToConstant: 12),

            indexLabel.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: 4),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 16),

            iconView.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: removeBtn.leadingAnchor, constant: -4),

            downBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            downBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            downBtn.widthAnchor.constraint(equalToConstant: 24),

            upBtn.trailingAnchor.constraint(equalTo: downBtn.leadingAnchor, constant: -4),
            upBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            upBtn.widthAnchor.constraint(equalToConstant: 24),

            removeBtn.trailingAnchor.constraint(equalTo: upBtn.leadingAnchor, constant: -4),
            removeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeBtn.widthAnchor.constraint(equalToConstant: 58)
        ])
    }

    @objc private func removeClicked() {
        onRemove?(slotIndex)
    }

    @objc private func upClicked() {
        onMoveUp?(slotIndex)
    }

    @objc private func downClicked() {
        onMoveDown?(slotIndex)
    }

    // Drag Source
    public override func mouseDown(with event: NSEvent) {
        dragStartLocation = convert(event.locationInWindow, from: nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartLocation else { return }
        let current = convert(event.locationInWindow, from: nil)
        let distance = hypot(current.x - start.x, current.y - start.y)
        if distance > 4.0 {
            dragStartLocation = nil
            let pItem = NSPasteboardItem()
            pItem.setString(String(slotIndex), forType: PinnedToolRowView.dragType)
            let draggingItem = NSDraggingItem(pasteboardWriter: pItem)
            draggingItem.setDraggingFrame(bounds, contents: self)
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }
    }

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }

    // Drag Destination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let item = sender.draggingPasteboard.pasteboardItems?.first,
              let str = item.string(forType: PinnedToolRowView.dragType),
              let src = Int(str), src != slotIndex else {
            return []
        }
        layer?.backgroundColor = NSColor(white: 0.35, alpha: 0.7).cgColor
        return .move
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.5).cgColor
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.5).cgColor
        guard let item = sender.draggingPasteboard.pasteboardItems?.first,
              let str = item.string(forType: PinnedToolRowView.dragType),
              let src = Int(str) else {
            return false
        }
        if src != slotIndex {
            onReorder?(src, slotIndex)
            return true
        }
        return false
    }

    public func simulateDrag(to destinationIndex: Int) {
        onReorder?(slotIndex, destinationIndex)
    }
}
