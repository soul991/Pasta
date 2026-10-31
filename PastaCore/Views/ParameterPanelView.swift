import Foundation
import AppKit
import QuartzCore
import ObjectiveC

/// Inline parameter configuration panel for actions with parameters.
/// Built for the Shift-hold radial wheel and the menu bar drop window.
public final class ParameterPanelView: NSVisualEffectView {
    public let model: ParameterFormModel
    public let action: ConversionAction

    public var onRun: ((ParameterValues) -> Void)?
    public var onCancel: (() -> Void)?

    // Subviews
    private let headerStack = NSStackView()
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    private let presetsScrollView = NSScrollView()
    private let presetsStack = NSStackView()

    private let contentScrollView = NSScrollView()
    private let fieldsStack = NSStackView()

    private let errorLabel = NSTextField(labelWithString: "")
    private let actionsStack = NSStackView()
    private let cancelButton = NSButton()
    private let runButton = NSButton()

    // Updaters for field controls when presets are applied
    private var fieldRefreshers: [() -> Void] = []
    private var presetChips: [PresetChipView] = []
    private var choiceChips: [String: [ChoiceChipView]] = [:]

    public init(model: ParameterFormModel, action: ConversionAction) {
        self.model = model
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 350))
        setupView()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

        let isReduceTransparency = PreferencesManager.shared.reduceTransparencyEnabled
        let isIncreaseContrast = PreferencesManager.shared.increaseContrastEnabled

        if isReduceTransparency {
            material = .hudWindow
            blendingMode = .withinWindow
            layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.98).cgColor
        } else {
            material = .hudWindow
            blendingMode = .behindWindow
            state = .active
        }

        if isIncreaseContrast {
            layer?.borderWidth = 2.0
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.6).cgColor
        } else {
            layer?.borderWidth = 1.0
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        }

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("\(action.displayName) parameter settings")

        // 1. Header
        setupHeader()

        // 2. Presets (if available)
        setupPresets()

        // 3. Fields
        setupFields()

        // 4. Error Label
        setupErrorLabel()

        // 5. Actions (Cancel / Run)
        setupActions()

        // Layout constraints
        setupConstraints()

        // Initial validation check
        validateAndUpdate()
    }

    private func setupHeader() {
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        addSubview(headerStack)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: action.iconName, accessibilityDescription: nil) {
            iconImageView.image = img
            iconImageView.contentTintColor = ThemeManager.shared.accentColor
        }
        iconImageView.setAccessibilityElement(false)
        headerStack.addArrangedSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = action.displayName
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(titleLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        if let closeImg = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close") {
            closeButton.image = closeImg
            closeButton.contentTintColor = NSColor(white: 1.0, alpha: 0.6)
        } else {
            closeButton.title = "✕"
        }
        closeButton.target = self
        closeButton.action = #selector(cancelClicked)
        closeButton.keyEquivalent = "\u{1b}" // Esc
        closeButton.setAccessibilityElement(true)
        closeButton.setAccessibilityLabel("Close parameter configuration")
        headerStack.addArrangedSubview(closeButton)
    }

    private func setupPresets() {
        guard !model.presets.isEmpty else { return }

        presetsScrollView.translatesAutoresizingMaskIntoConstraints = false
        presetsScrollView.hasHorizontalScroller = false
        presetsScrollView.hasVerticalScroller = false
        presetsScrollView.drawsBackground = false
        presetsScrollView.borderType = .noBorder
        addSubview(presetsScrollView)

        presetsStack.orientation = .horizontal
        presetsStack.alignment = .centerY
        presetsStack.spacing = 6
        presetsStack.translatesAutoresizingMaskIntoConstraints = false
        presetsScrollView.documentView = presetsStack

        for preset in model.presets {
            let chip = PresetChipView(preset: preset)
            chip.onTap = { [weak self] in
                self?.applyPreset(preset)
            }
            presetsStack.addArrangedSubview(chip)
            presetChips.append(chip)
        }
    }

    private func setupFields() {
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.drawsBackground = false
        contentScrollView.borderType = .noBorder
        addSubview(contentScrollView)

        fieldsStack.orientation = .vertical
        fieldsStack.alignment = .leading
        fieldsStack.spacing = 12
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = fieldsStack

        for field in model.fields {
            buildControl(for: field)
        }
    }

    private func setupErrorLabel() {
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.identifier = NSUserInterfaceItemIdentifier("ParameterPanel.errorLabel")
        errorLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = NSColor.systemRed
        errorLabel.maximumNumberOfLines = 2
        errorLabel.cell?.wraps = true
        errorLabel.alignment = .left
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
        errorLabel.setAccessibilityElement(true)
        errorLabel.setAccessibilityLabel("Validation error message")
        addSubview(errorLabel)
    }

    private func setupActions() {
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 10
        actionsStack.distribution = .fillEqually
        addSubview(actionsStack)

        // Cancel
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.keyEquivalent = "\u{1b}" // Esc
        cancelButton.setAccessibilityElement(true)
        cancelButton.setAccessibilityLabel("Cancel parameter configuration")
        actionsStack.addArrangedSubview(cancelButton)

        // Run
        runButton.title = "Run"
        runButton.bezelStyle = .rounded
        runButton.target = self
        runButton.action = #selector(runClicked)
        runButton.keyEquivalent = "\r" // Return
        runButton.contentTintColor = .white
        runButton.setAccessibilityElement(true)
        runButton.setAccessibilityLabel("Run action with configured parameters")
        actionsStack.addArrangedSubview(runButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: 24),

            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        if !model.presets.isEmpty {
            NSLayoutConstraint.activate([
                presetsScrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
                presetsScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                presetsScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                presetsScrollView.heightAnchor.constraint(equalToConstant: 28),

                contentScrollView.topAnchor.constraint(equalTo: presetsScrollView.bottomAnchor, constant: 8)
            ])
        } else {
            NSLayoutConstraint.activate([
                contentScrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10)
            ])
        }

        NSLayoutConstraint.activate([
            contentScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentScrollView.bottomAnchor.constraint(equalTo: errorLabel.topAnchor, constant: -8),

            fieldsStack.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor),
            fieldsStack.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            errorLabel.bottomAnchor.constraint(equalTo: actionsStack.topAnchor, constant: -10),
            errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 14),

            actionsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            actionsStack.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - Dynamic Control Builder

    private func buildControl(for field: ParameterFormField) {
        let param = field.parameter

        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: param.label)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = ThemeManager.shared.textSecondaryColor
        row.addArrangedSubview(label)

        switch param.kind {
        case .percent:
            let sliderRow = NSStackView()
            sliderRow.orientation = .horizontal
            sliderRow.alignment = .centerY
            sliderRow.spacing = 8
            sliderRow.translatesAutoresizingMaskIntoConstraints = false

            let curVal = field.currentValue.asDouble ?? 0.0
            let slider = NSSlider(value: curVal, minValue: param.minValue ?? 1.0, maxValue: param.maxValue ?? 100.0, target: nil, action: nil)
            slider.isContinuous = true
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.setAccessibilityElement(true)
            slider.setAccessibilityLabel("\(param.label) percentage slider")

            let readout = NSTextField(labelWithString: "\(Int(curVal))%")
            readout.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            readout.textColor = ThemeManager.shared.textPrimaryColor
            readout.alignment = NSTextAlignment.right
            readout.widthAnchor.constraint(equalToConstant: 40).isActive = true

            slider.target = self
            slider.action = #selector(sliderChanged(_:))

            sliderRow.addArrangedSubview(slider)
            sliderRow.addArrangedSubview(readout)
            row.addArrangedSubview(sliderRow)

            sliderRow.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

            let updater: () -> Void = { [weak self, weak slider, weak readout] in
                guard let self = self, let current = self.model.values[param.id]?.asDouble else { return }
                slider?.doubleValue = current
                readout?.stringValue = "\(Int(current))%"
            }
            fieldRefreshers.append(updater)

            // Closure for live slider events
            objc_setAssociatedObject(slider, &AssociatedKeys.paramId, param.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(slider, &AssociatedKeys.readout, readout, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case .sizeInBytes:
            let sizeRow = NSStackView()
            sizeRow.orientation = .horizontal
            sizeRow.alignment = .centerY
            sizeRow.spacing = 8
            sizeRow.translatesAutoresizingMaskIntoConstraints = false

            let input = NSTextField()
            input.translatesAutoresizingMaskIntoConstraints = false
            let mbValue = Double(field.currentValue.asInt64 ?? 0) / (1024.0 * 1024.0)
            input.stringValue = (mbValue > 0) ? String(format: "%.1f", mbValue) : "0"
            input.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            input.target = self
            input.action = #selector(textInputChanged(_:))
            input.setAccessibilityElement(true)
            input.setAccessibilityLabel("\(param.label) in megabytes")
            objc_setAssociatedObject(input, &AssociatedKeys.paramId, param.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(input, &AssociatedKeys.isBytesField, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            let unit = NSTextField(labelWithString: "MB")
            unit.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            unit.textColor = ThemeManager.shared.textSecondaryColor

            sizeRow.addArrangedSubview(input)
            sizeRow.addArrangedSubview(unit)
            row.addArrangedSubview(sizeRow)
            sizeRow.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

            let warningLabel = NSTextField(labelWithString: "")
            warningLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            warningLabel.textColor = NSColor.systemOrange
            warningLabel.identifier = NSUserInterfaceItemIdentifier("ParameterPanel.inlineWarning.\(param.id)")
            warningLabel.setAccessibilityElement(true)
            warningLabel.setAccessibilityLabel("Target size warning")
            warningLabel.isHidden = true
            row.addArrangedSubview(warningLabel)

            let updater: () -> Void = { [weak self, weak input, weak warningLabel] in
                guard let self = self, let bytes = self.model.values[param.id]?.asInt64 else { return }
                let mb = Double(bytes) / (1024.0 * 1024.0)
                input?.stringValue = (mb > 0) ? String(format: "%.1f", mb) : "0"
                if let warn = self.model.warnings[param.id] {
                    warningLabel?.stringValue = "⚠️ " + warn
                    warningLabel?.isHidden = false
                } else {
                    warningLabel?.stringValue = ""
                    warningLabel?.isHidden = true
                }
            }
            fieldRefreshers.append(updater)
            updater()

        case .number:
            if let min = param.minValue, let max = param.maxValue {
                // Slider for bounded number (e.g. video speed 0.25 to 4.0)
                let numRow = NSStackView()
                numRow.orientation = .horizontal
                numRow.alignment = .centerY
                numRow.spacing = 8
                numRow.translatesAutoresizingMaskIntoConstraints = false

                let curVal = field.currentValue.asDouble ?? min
                let slider = NSSlider(value: curVal, minValue: min, maxValue: max, target: nil, action: nil)
                slider.isContinuous = true
                slider.translatesAutoresizingMaskIntoConstraints = false
                slider.setAccessibilityElement(true)
                slider.setAccessibilityLabel("\(param.label) slider")

                let readout = NSTextField(labelWithString: String(format: "%.2fx", curVal))
                readout.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
                readout.textColor = ThemeManager.shared.textPrimaryColor
                readout.alignment = NSTextAlignment.right
                readout.widthAnchor.constraint(equalToConstant: 45).isActive = true

                slider.target = self
                slider.action = #selector(sliderChanged(_:))
                objc_setAssociatedObject(slider, &AssociatedKeys.paramId, param.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                objc_setAssociatedObject(slider, &AssociatedKeys.readout, readout, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                numRow.addArrangedSubview(slider)
                numRow.addArrangedSubview(readout)
                row.addArrangedSubview(numRow)
                numRow.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

                let updater: () -> Void = { [weak self, weak slider, weak readout] in
                    guard let self = self, let current = self.model.values[param.id]?.asDouble else { return }
                    slider?.doubleValue = current
                    readout?.stringValue = String(format: "%.2fx", current)
                }
                fieldRefreshers.append(updater)
            } else {
                // Numeric text input (e.g. trim start/end time)
                let input = NSTextField()
                input.translatesAutoresizingMaskIntoConstraints = false
                input.stringValue = String(format: "%.1f", field.currentValue.asDouble ?? 0.0)
                input.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                input.target = self
                input.action = #selector(textInputChanged(_:))
                input.setAccessibilityElement(true)
                input.setAccessibilityLabel("\(param.label) numeric field")
                objc_setAssociatedObject(input, &AssociatedKeys.paramId, param.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                row.addArrangedSubview(input)
                input.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

                let updater: () -> Void = { [weak self, weak input] in
                    guard let self = self, let current = self.model.values[param.id]?.asDouble else { return }
                    input?.stringValue = String(format: "%.1f", current)
                }
                fieldRefreshers.append(updater)
            }

        case .timeRange:
            let timeRow = NSStackView()
            timeRow.orientation = .horizontal
            timeRow.alignment = .centerY
            timeRow.spacing = 8
            timeRow.translatesAutoresizingMaskIntoConstraints = false

            let startField = NSTextField()
            let endField = NSTextField()
            startField.translatesAutoresizingMaskIntoConstraints = false
            endField.translatesAutoresizingMaskIntoConstraints = false
            startField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            endField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            startField.widthAnchor.constraint(equalToConstant: 55).isActive = true
            endField.widthAnchor.constraint(equalToConstant: 55).isActive = true
            startField.setAccessibilityElement(true)
            startField.setAccessibilityLabel("\(param.label) start time")
            endField.setAccessibilityElement(true)
            endField.setAccessibilityLabel("\(param.label) end time")

            if case .timeRange(let s, let e) = field.currentValue {
                startField.stringValue = String(format: "%.1f", s)
                endField.stringValue = String(format: "%.1f", e)
            } else {
                startField.stringValue = "0.0"
                endField.stringValue = "10.0"
            }

            timeRow.addArrangedSubview(NSTextField(labelWithString: "Start:"))
            timeRow.addArrangedSubview(startField)
            timeRow.addArrangedSubview(NSTextField(labelWithString: "End:"))
            timeRow.addArrangedSubview(endField)
            timeRow.addArrangedSubview(NSTextField(labelWithString: "sec"))
            row.addArrangedSubview(timeRow)

            let timeUpdater: () -> Void = { [weak self, weak startField, weak endField] in
                guard let self = self,
                      let val = self.model.values[param.id],
                      case .timeRange(let s, let e) = val else { return }
                startField?.stringValue = String(format: "%.1f", s)
                endField?.stringValue = String(format: "%.1f", e)
            }
            fieldRefreshers.append(timeUpdater)

        case .choice(let options):
            let choiceRow = NSStackView()
            choiceRow.orientation = .horizontal
            choiceRow.alignment = .centerY
            choiceRow.spacing = 6
            choiceRow.translatesAutoresizingMaskIntoConstraints = false

            var chipsForField: [ChoiceChipView] = []
            let currentChoice = field.currentValue.asString

            for opt in options {
                let isSelected = (opt == currentChoice)
                let chip = ChoiceChipView(title: opt, isSelected: isSelected)
                chip.onTap = { [weak self] in
                    self?.selectChoice(opt, for: param.id)
                }
                choiceRow.addArrangedSubview(chip)
                chipsForField.append(chip)
            }
            choiceChips[param.id] = chipsForField

            row.addArrangedSubview(choiceRow)

            let updater: () -> Void = { [weak self] in
                guard let self = self, let current = self.model.values[param.id]?.asString else { return }
                for chip in self.choiceChips[param.id] ?? [] {
                    chip.setSelected(chip.title == current)
                }
            }
            fieldRefreshers.append(updater)

        case .rectangle:
            // Source & resulting crop size readout
            let sizeInfoRow = NSStackView()
            sizeInfoRow.orientation = .horizontal
            sizeInfoRow.alignment = .centerY
            sizeInfoRow.spacing = 8
            sizeInfoRow.translatesAutoresizingMaskIntoConstraints = false

            let srcW = model.probeResult?.width ?? 0
            let srcH = model.probeResult?.height ?? 0
            let sourceLabel: NSTextField
            let cropSizeLabel = NSTextField(labelWithString: "Crop: 0×0")

            if model.isBatch {
                sourceLabel = NSTextField(labelWithString: "Applies to \(model.batchCount) files")
                sourceLabel.textColor = ThemeManager.shared.accentColor
                if let intent = model.cropIntent {
                    switch intent {
                    case .ratio(let rw, let rh):
                        cropSizeLabel.stringValue = "Ratio: \(rw):\(rh)"
                    case .manual(_, _, let w, let h):
                        cropSizeLabel.stringValue = "Manual: \(w)×\(h)"
                    }
                } else {
                    cropSizeLabel.stringValue = "Centered crop"
                }
            } else {
                sourceLabel = NSTextField(labelWithString: (srcW > 0 && srcH > 0) ? "Source: \(srcW)×\(srcH)" : (model.probeError != nil ? "Source: probe error" : "Source: unknown"))
                sourceLabel.textColor = (model.probeError != nil) ? NSColor.systemRed : ThemeManager.shared.textSecondaryColor
            }
            sourceLabel.identifier = NSUserInterfaceItemIdentifier("ParameterPanel.sourceDimensions")
            sourceLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            sourceLabel.setAccessibilityElement(true)
            sourceLabel.setAccessibilityLabel("Source dimensions")

            cropSizeLabel.identifier = NSUserInterfaceItemIdentifier("ParameterPanel.cropDimensions")
            cropSizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            cropSizeLabel.textColor = ThemeManager.shared.accentColor
            cropSizeLabel.setAccessibilityElement(true)
            cropSizeLabel.setAccessibilityLabel("Crop dimensions")

            sizeInfoRow.addArrangedSubview(sourceLabel)
            if !model.isBatch {
                sizeInfoRow.addArrangedSubview(NSTextField(labelWithString: "→"))
            }
            sizeInfoRow.addArrangedSubview(cropSizeLabel)
            row.addArrangedSubview(sizeInfoRow)

            // Ratio chips
            let ratioRow = NSStackView()
            ratioRow.orientation = .horizontal
            ratioRow.alignment = .centerY
            ratioRow.spacing = 6
            ratioRow.translatesAutoresizingMaskIntoConstraints = false

            let ratios = [("16:9", 16, 9), ("1:1", 1, 1), ("9:16", 9, 16)]
            for (rName, rw, rh) in ratios {
                let chip = ChoiceChipView(title: rName, isSelected: false)
                chip.onTap = { [weak self] in
                    guard let self = self else { return }
                    self.model.cropIntent = .ratio(width: rw, height: rh)
                    if let cw = self.model.probeResult?.width, let ch = self.model.probeResult?.height, cw > 0, ch > 0 {
                        let crop = CropCalculator.computeCrop(containerWidth: cw, containerHeight: ch, ratioWidth: rw, ratioHeight: rh)
                        self.model.updateValue(.rectangle(x: crop.x, y: crop.y, width: crop.width, height: crop.height), for: param.id)
                    }
                    self.refreshAllFields()
                    self.validateAndUpdate()
                }
                ratioRow.addArrangedSubview(chip)
            }
            row.addArrangedSubview(ratioRow)

            // Coordinates Row
            let coordRow = NSStackView()
            coordRow.orientation = .horizontal
            coordRow.alignment = .centerY
            coordRow.spacing = 6
            coordRow.translatesAutoresizingMaskIntoConstraints = false

            let wField = NSTextField(string: "320")
            let hField = NSTextField(string: "240")
            let xField = NSTextField(string: "0")
            let yField = NSTextField(string: "0")

            func styleCoordField(_ f: NSTextField, label: String) {
                f.translatesAutoresizingMaskIntoConstraints = false
                f.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                f.widthAnchor.constraint(equalToConstant: 44).isActive = true
                f.setAccessibilityElement(true)
                f.setAccessibilityLabel("Crop \(label)")
            }

            styleCoordField(wField, label: "Width")
            styleCoordField(hField, label: "Height")
            styleCoordField(xField, label: "X Offset")
            styleCoordField(yField, label: "Y Offset")

            let handleCoordChange: () -> Void = { [weak self, weak wField, weak hField, weak xField, weak yField] in
                guard let self = self else { return }
                let w = Int(wField?.stringValue ?? "") ?? 0
                let h = Int(hField?.stringValue ?? "") ?? 0
                let x = Int(xField?.stringValue ?? "") ?? 0
                let y = Int(yField?.stringValue ?? "") ?? 0
                self.model.cropIntent = .manual(x: x, y: y, width: w, height: h)
                self.model.updateValue(.rectangle(x: x, y: y, width: w, height: h), for: param.id)
                if self.model.isBatch {
                    cropSizeLabel.stringValue = "Manual: \(w)×\(h)"
                } else {
                    cropSizeLabel.stringValue = "Crop: \(w)×\(h)"
                }
                self.validateAndUpdate()
            }

            wField.target = self
            wField.action = #selector(coordFieldChanged(_:))
            hField.target = self
            hField.action = #selector(coordFieldChanged(_:))
            xField.target = self
            xField.action = #selector(coordFieldChanged(_:))
            yField.target = self
            yField.action = #selector(coordFieldChanged(_:))

            objc_setAssociatedObject(self, &AssociatedKeys.coordHandler, handleCoordChange, .OBJC_ASSOCIATION_COPY_NONATOMIC)

            coordRow.addArrangedSubview(NSTextField(labelWithString: "W:"))
            coordRow.addArrangedSubview(wField)
            coordRow.addArrangedSubview(NSTextField(labelWithString: "H:"))
            coordRow.addArrangedSubview(hField)
            coordRow.addArrangedSubview(NSTextField(labelWithString: "X:"))
            coordRow.addArrangedSubview(xField)
            coordRow.addArrangedSubview(NSTextField(labelWithString: "Y:"))
            coordRow.addArrangedSubview(yField)

            row.addArrangedSubview(coordRow)

            let updater: () -> Void = { [weak self, weak wField, weak hField, weak xField, weak yField, weak sourceLabel, weak cropSizeLabel] in
                guard let self = self,
                      let rectVal = self.model.values[param.id],
                      case .rectangle(let x, let y, let w, let h) = rectVal else { return }
                wField?.stringValue = "\(w)"
                hField?.stringValue = "\(h)"
                xField?.stringValue = "\(x)"
                yField?.stringValue = "\(y)"
                if self.model.isBatch {
                    sourceLabel?.stringValue = "Applies to \(self.model.batchCount) files"
                    if let intent = self.model.cropIntent {
                        switch intent {
                        case .ratio(let rw, let rh):
                            cropSizeLabel?.stringValue = "Ratio: \(rw):\(rh)"
                        case .manual(_, _, let mw, let mh):
                            cropSizeLabel?.stringValue = "Manual: \(mw)×\(mh)"
                        }
                    } else {
                        cropSizeLabel?.stringValue = "Centered crop"
                    }
                } else {
                    cropSizeLabel?.stringValue = "Crop: \(w)×\(h)"
                }
            }
            fieldRefreshers.append(updater)
            updater()

        case .text:
            let input = NSTextField()
            input.translatesAutoresizingMaskIntoConstraints = false
            input.stringValue = field.currentValue.asString
            input.font = NSFont.systemFont(ofSize: 12)
            input.target = self
            input.action = #selector(textInputChanged(_:))
            input.setAccessibilityElement(true)
            input.setAccessibilityLabel("\(param.label) text field")
            objc_setAssociatedObject(input, &AssociatedKeys.paramId, param.id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            row.addArrangedSubview(input)
            input.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true

            let updater: () -> Void = { [weak self, weak input] in
                guard let self = self, let s = self.model.values[param.id]?.asString else { return }
                input?.stringValue = s
            }
            fieldRefreshers.append(updater)
        }

        fieldsStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: fieldsStack.widthAnchor).isActive = true
    }

    // MARK: - Actions & Events

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let paramId = objc_getAssociatedObject(sender, &AssociatedKeys.paramId) as? String else { return }
        let val = sender.doubleValue
        model.updateValue(.number(val), for: paramId)

        if let readout = objc_getAssociatedObject(sender, &AssociatedKeys.readout) as? NSTextField {
            if paramId.contains("percent") {
                readout.stringValue = "\(Int(val))%"
            } else {
                readout.stringValue = String(format: "%.2fx", val)
            }
        }
        validateAndUpdate()
    }

    @objc private func textInputChanged(_ sender: NSTextField) {
        guard let paramId = objc_getAssociatedObject(sender, &AssociatedKeys.paramId) as? String else { return }
        let isBytes = (objc_getAssociatedObject(sender, &AssociatedKeys.isBytesField) as? Bool) ?? false

        if isBytes {
            let mb = Double(sender.stringValue) ?? 0.0
            let bytes = Int64(mb * 1024.0 * 1024.0)
            model.updateValue(.integer(bytes), for: paramId)
        } else {
            model.updateStringValue(sender.stringValue, for: paramId)
        }
        validateAndUpdate()
    }

    private func selectChoice(_ choice: String, for paramId: String) {
        model.updateValue(.text(choice), for: paramId)
        if let chips = choiceChips[paramId] {
            for chip in chips {
                chip.setSelected(chip.title == choice)
            }
        }
        validateAndUpdate()
    }

    private func applyPreset(_ preset: ParameterPreset) {
        model.applyPreset(preset)
        refreshAllFields()
        validateAndUpdate()
    }

    public func refreshAllFields() {
        for refresher in fieldRefreshers {
            refresher()
        }
    }

    private func validateAndUpdate() {
        let valid = model.isValid
        runButton.isEnabled = valid

        if !valid, let firstError = model.validationErrors.values.first {
            errorLabel.stringValue = firstError
            errorLabel.textColor = NSColor.systemRed
            errorLabel.isHidden = false
        } else if let firstWarning = model.warnings.values.first {
            errorLabel.stringValue = "⚠️ " + firstWarning
            errorLabel.textColor = NSColor.systemOrange
            errorLabel.isHidden = false
        } else {
            errorLabel.stringValue = ""
            errorLabel.isHidden = true
        }
    }

    @objc private func coordFieldChanged(_ sender: NSTextField) {
        if let handler = objc_getAssociatedObject(self, &AssociatedKeys.coordHandler) as? () -> Void {
            handler()
        }
    }

    @objc private func cancelClicked() {
        onCancel?()
    }

    @objc private func runClicked() {
        guard model.isValid else { return }
        model.saveAsLastUsed()
        onRun?(model.values)
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var paramId: UInt8 = 0
    static var readout: UInt8 = 0
    static var isBytesField: UInt8 = 0
    static var coordHandler: UInt8 = 0
}

// MARK: - PresetChipView
public final class PresetChipView: NSView {
    public let preset: ParameterPreset
    public var onTap: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isHovered: Bool = false {
        didSet { updateState() }
    }

    public init(preset: ParameterPreset) {
        self.preset = preset
        super.init(frame: NSRect(x: 0, y: 0, width: 60, height: 24))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = false

        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = preset.label
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Apply preset \(preset.label)")

        updateState()
    }

    private func updateState() {
        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        if isHovered {
            layer?.backgroundColor = ThemeManager.shared.accentColorSubtle.cgColor
            layer?.borderColor = ThemeManager.shared.accentColor.cgColor
            layer?.borderWidth = 1.2
            if !isReduceMotion {
                layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
            }
        } else {
            layer?.backgroundColor = NSColor(white: 0.20, alpha: 0.6).cgColor
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
            layer?.borderWidth = 1.0
            layer?.transform = CATransform3DIdentity
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    public override func mouseDown(with event: NSEvent) {
        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled
        if !isReduceMotion {
            layer?.transform = CATransform3DMakeScale(1.06, 1.06, 1.0)
        }
        onTap?()
    }

    public override func mouseUp(with event: NSEvent) {
        updateState()
    }
}

// MARK: - ChoiceChipView
public final class ChoiceChipView: NSView {
    public let title: String
    private(set) public var isSelected: Bool
    public var onTap: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isHovered: Bool = false {
        didSet { updateAppearance() }
    }

    public init(title: String, isSelected: Bool) {
        self.title = title
        self.isSelected = isSelected
        super.init(frame: NSRect(x: 0, y: 0, width: 64, height: 26))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setSelected(_ selected: Bool) {
        self.isSelected = selected
        updateAppearance()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.masksToBounds = false

        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = title
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.alignment = .center
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Option \(title)")

        updateAppearance()
    }

    private func updateAppearance() {
        let accent = ThemeManager.shared.accentColor
        let darkInk = ThemeManager.shared.accentInkColor
        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        if isSelected {
            layer?.backgroundColor = accent.cgColor
            layer?.borderColor = NSColor.white.cgColor
            layer?.borderWidth = 1.5
            label.textColor = darkInk // 8.9:1 contrast against accent
            if !isReduceMotion {
                layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
            }
        } else if isHovered {
            layer?.backgroundColor = accent.withAlphaComponent(0.2).cgColor
            layer?.borderColor = accent.cgColor
            layer?.borderWidth = 1.2
            label.textColor = .white
            if !isReduceMotion {
                layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
            }
        } else {
            layer?.backgroundColor = NSColor(white: 0.18, alpha: 0.7).cgColor
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
            layer?.borderWidth = 1.0
            label.textColor = .white
            layer?.transform = CATransform3DIdentity
        }
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    public override func mouseDown(with event: NSEvent) {
        onTap?()
    }
}
