import Foundation
import AppKit
import QuartzCore

public final class RadialWheelOverlayViewController: NSViewController {
    public var onCloseRequested: (() -> Void)?

    private var targetFiles: [URL] = []
    private var isAdvanced: Bool = false

    private let backplateView = RadialWheelBackplateView()
    private let centerDisc = RadialWheelCenterDiscView()
    private let hudView = RadialConversionHUDView()
    private var nodeViews: [RadialOptionNodeView] = []
    private var parameterPanelView: ParameterPanelView?
    private var moreView: RadialWheelMoreView?
    private var customizeSheet: RadialWheelCustomizeSheet?
    private var savedNodeFrames: [ObjectIdentifier: NSRect] = [:]
    public private(set) var wheelCloseButton: NSButton?

    public var activeNodeViews: [RadialOptionNodeView] {
        return nodeViews
    }
    public var currentCustomizeSheet: RadialWheelCustomizeSheet? {
        return customizeSheet
    }

    // Floating hint pill
    public let hintPillContainer = NSVisualEffectView()
    public let hintPillLabel = NSTextField(labelWithString: "")
    public private(set) var isHintPillAboveWheel: Bool = false

    private var hintPillBottomConstraint: NSLayoutConstraint?
    private var hintPillTopConstraint: NSLayoutConstraint?
    private var compactProgressAbovePillConstraint: NSLayoutConstraint?
    private var compactProgressBottomConstraint: NSLayoutConstraint?

    // Compact progress row below wheel (Phase 10B Step 1)
    public let compactProgressContainer = NSVisualEffectView()
    public let compactProgressIcon = NSImageView()
    public let compactProgressLabel = NSTextField(labelWithString: "")
    public let compactProgressBar = NSProgressIndicator()
    public let compactProgressButton = NSButton(title: "Reveal", target: nil, action: nil)
    public var currentConversionJobID: UUID?
    public var currentConvertingFileName: String?
    private var lastOutputURL: URL?
    private var lastErrorMessage: String?

    public override func loadView() {
        // Frame sized via WheelGeometry to accommodate all 8 nodes, max 1.06 hover scale,
        // 18pt accent glow, 10pt shadow, and controls with >= 8pt margin.
        view = NSView(frame: NSRect(x: 0, y: 0, width: WheelGeometry.panelWidth, height: WheelGeometry.panelHeight))
        view.wantsLayer = true
        view.layer?.masksToBounds = false
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Backplate annulus (400 pt default)
        let outerD = WheelLayoutModel.shared.currentSize.backplateDiameter
        let hubD = WheelLayoutModel.shared.currentSize.hubDiameter
        backplateView.outerDiameter = outerD
        backplateView.hubDiameter = hubD
        backplateView.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (outerD / 2.0),
            y: WheelGeometry.wheelCenterY - (outerD / 2.0),
            width: outerD,
            height: outerD
        )
        view.addSubview(backplateView)

        // Center Disc centered at (WheelGeometry.wheelCenterX, WheelGeometry.wheelCenterY)
        centerDisc.diameter = hubD
        centerDisc.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (hubD / 2.0),
            y: WheelGeometry.wheelCenterY - (hubD / 2.0),
            width: hubD,
            height: hubD
        )
        view.addSubview(centerDisc)

        // HUD View (initially hidden)
        hudView.frame = NSRect(
            x: WheelGeometry.wheelCenterX - 75,
            y: WheelGeometry.wheelCenterY - 75,
            width: 150,
            height: 150
        )
        hudView.isHidden = true
        hudView.onDismiss = { [weak self] in
            self?.onCloseRequested?()
        }
        view.addSubview(hudView)

        // Hint pill container
        hintPillContainer.translatesAutoresizingMaskIntoConstraints = false
        hintPillContainer.blendingMode = .behindWindow
        hintPillContainer.material = .hudWindow
        hintPillContainer.state = .active
        hintPillContainer.wantsLayer = true
        hintPillContainer.layer?.cornerRadius = 14
        hintPillContainer.layer?.borderWidth = 1.0
        hintPillContainer.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        hintPillContainer.layer?.masksToBounds = true
        view.addSubview(hintPillContainer)

        hintPillLabel.translatesAutoresizingMaskIntoConstraints = false
        hintPillLabel.stringValue = "Esc closes · ⌥ mode · ⇧ re-targets"
        hintPillLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        // Calibrated 55% white to guarantee >= 4.5:1 contrast
        hintPillLabel.textColor = ThemeManager.shared.textTertiaryColor
        hintPillLabel.alignment = .center
        hintPillContainer.addSubview(hintPillLabel)

        // Compact progress container (below wheel, above hint pill)
        compactProgressContainer.translatesAutoresizingMaskIntoConstraints = false
        compactProgressContainer.blendingMode = .behindWindow
        compactProgressContainer.material = .hudWindow
        compactProgressContainer.state = .active
        compactProgressContainer.wantsLayer = true
        compactProgressContainer.layer?.cornerRadius = 16
        compactProgressContainer.layer?.borderWidth = 1.0
        compactProgressContainer.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        compactProgressContainer.layer?.masksToBounds = true
        compactProgressContainer.isHidden = true
        view.addSubview(compactProgressContainer)

        compactProgressIcon.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            compactProgressIcon.image = img
            compactProgressIcon.contentTintColor = ThemeManager.shared.accentColor
        }

        compactProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        compactProgressLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        compactProgressLabel.textColor = .white
        compactProgressLabel.lineBreakMode = .byTruncatingMiddle

        compactProgressBar.translatesAutoresizingMaskIntoConstraints = false
        compactProgressBar.style = .bar
        compactProgressBar.controlSize = .small
        compactProgressBar.minValue = 0.0
        compactProgressBar.maxValue = 100.0
        compactProgressBar.isIndeterminate = true
        compactProgressBar.isHidden = true

        compactProgressButton.translatesAutoresizingMaskIntoConstraints = false
        compactProgressButton.bezelStyle = .inline
        compactProgressButton.title = "Reveal"
        compactProgressButton.target = self
        compactProgressButton.action = #selector(revealOutputClicked)
        compactProgressButton.isHidden = true

        let compactStack = NSStackView(views: [compactProgressIcon, compactProgressLabel, compactProgressBar, compactProgressButton])
        compactStack.translatesAutoresizingMaskIntoConstraints = false
        compactStack.orientation = .horizontal
        compactStack.alignment = .centerY
        compactStack.spacing = 8
        compactProgressContainer.addSubview(compactStack)

        let pillBottom = hintPillContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        let pillTop = hintPillContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 12)
        let progAbovePill = compactProgressContainer.bottomAnchor.constraint(equalTo: hintPillContainer.topAnchor, constant: -8)
        let progBottom = compactProgressContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)

        self.hintPillBottomConstraint = pillBottom
        self.hintPillTopConstraint = pillTop
        self.compactProgressAbovePillConstraint = progAbovePill
        self.compactProgressBottomConstraint = progBottom

        NSLayoutConstraint.activate([
            hintPillContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintPillContainer.heightAnchor.constraint(equalToConstant: 28),
            hintPillContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            hintPillContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            hintPillLabel.leadingAnchor.constraint(equalTo: hintPillContainer.leadingAnchor, constant: 14),
            hintPillLabel.trailingAnchor.constraint(equalTo: hintPillContainer.trailingAnchor, constant: -14),
            hintPillLabel.centerYAnchor.constraint(equalTo: hintPillContainer.centerYAnchor),

            compactProgressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            compactProgressContainer.heightAnchor.constraint(equalToConstant: 32),
            compactProgressContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            compactProgressContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            compactStack.leadingAnchor.constraint(equalTo: compactProgressContainer.leadingAnchor, constant: 10),
            compactStack.trailingAnchor.constraint(equalTo: compactProgressContainer.trailingAnchor, constant: -10),
            compactStack.centerYAnchor.constraint(equalTo: compactProgressContainer.centerYAnchor),

            compactProgressIcon.widthAnchor.constraint(equalToConstant: 16),
            compactProgressIcon.heightAnchor.constraint(equalToConstant: 16),
            compactProgressBar.widthAnchor.constraint(equalToConstant: 70),

            pillBottom,
            progAbovePill
        ])

        // Close control (×) at top-right of wheel backplate
        let closeBtn = NSButton(frame: NSRect(
            x: WheelGeometry.wheelCenterX + 138,
            y: WheelGeometry.wheelCenterY + 138,
            width: 28,
            height: 28
        ))
        closeBtn.title = "✕"
        closeBtn.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        closeBtn.isBordered = false
        closeBtn.wantsLayer = true
        closeBtn.layer?.cornerRadius = 14
        closeBtn.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.6).cgColor
        closeBtn.contentTintColor = .white
        closeBtn.target = self
        closeBtn.action = #selector(closeButtonClicked)
        closeBtn.setAccessibilityElement(true)
        closeBtn.setAccessibilityRole(.button)
        closeBtn.setAccessibilityLabel("Close wheel")
        closeBtn.setAccessibilityHelp("Closes the radial wheel overlay")
        view.addSubview(closeBtn)
        self.wheelCloseButton = closeBtn

        DragMonitor.shared.onEscIntercepted = { [weak self] in
            return self?.handleEscKey() ?? false
        }
        DragMonitor.shared.onKeyDownIntercepted = { [weak self] keyCode in
            return self?.handleKeyDown(keyCode: keyCode) ?? false
        }
    }

    @objc private func closeButtonClicked() {
        DragMonitor.shared.closeWheel(reason: "Close button (×) clicked")
    }

    @objc private func revealOutputClicked() {
        if compactProgressButton.title == "Cancel" {
            if let jid = currentConversionJobID {
                JobRunner.shared.cancel(jobId: jid)
            }
            currentConversionJobID = nil
            currentConvertingFileName = nil
            compactProgressBar.stopAnimation(nil)
            compactProgressBar.isHidden = true
            compactProgressLabel.stringValue = "Conversion cancelled"
            compactProgressButton.title = "Dismiss"
            if let img = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) {
                compactProgressIcon.image = img
                compactProgressIcon.contentTintColor = .secondaryLabelColor
            }
            return
        }
        if compactProgressButton.title == "Dismiss" {
            compactProgressContainer.isHidden = true
            return
        }
        if let url = lastOutputURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else if let errorMsg = lastErrorMessage {
            let details = "Pasta Error Report\nAction error: \(errorMsg)\nTimestamp: \(ISO8601DateFormatter().string(from: Date()))"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(details, forType: .string)
            compactProgressLabel.stringValue = "Error copied to clipboard ✓"
        }
    }

    public func updateConvertingProgress(progress: Double?, eta: Double? = nil) {
        let apply = { [weak self] in
            guard let self = self else { return }
            let name = self.currentConvertingFileName ?? ""
            let namePrefix = name.isEmpty ? "Converting" : "Converting \(name)"
            if let p = progress {
                self.compactProgressBar.isIndeterminate = false
                self.compactProgressBar.minValue = 0.0
                self.compactProgressBar.maxValue = 100.0
                self.compactProgressBar.doubleValue = max(0.0, min(100.0, p * 100.0))
                self.compactProgressBar.isHidden = false
                if let eta = eta, eta > 0 {
                    self.compactProgressLabel.stringValue = String(format: "%@ (%d%%)... ~%.0fs left", namePrefix, Int(p * 100.0), eta)
                } else {
                    self.compactProgressLabel.stringValue = String(format: "%@ (%d%%)...", namePrefix, Int(p * 100.0))
                }
            } else {
                self.compactProgressBar.isIndeterminate = true
                self.compactProgressBar.startAnimation(nil)
                self.compactProgressBar.isHidden = false
                if let eta = eta, eta > 0 {
                    self.compactProgressLabel.stringValue = String(format: "%@... ~%.0fs left", namePrefix, eta)
                } else {
                    self.compactProgressLabel.stringValue = "\(namePrefix)..."
                }
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    public func setHintPillPlacement(aboveWheel: Bool) {
        self.isHintPillAboveWheel = aboveWheel
        if aboveWheel {
            hintPillBottomConstraint?.isActive = false
            compactProgressAbovePillConstraint?.isActive = false
            hintPillTopConstraint?.isActive = true
            compactProgressBottomConstraint?.isActive = true
        } else {
            hintPillTopConstraint?.isActive = false
            compactProgressBottomConstraint?.isActive = false
            hintPillBottomConstraint?.isActive = true
            compactProgressAbovePillConstraint?.isActive = true
        }
        view.needsLayout = true
    }

    public func evaluateHintPillPlacement(screenVisibleFrame: CGRect? = nil) {
        let visFrame = screenVisibleFrame ?? view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelOrigin = view.window?.frame.origin ?? .zero
        let cramped = WheelGeometry.isBottomCramped(panelOrigin: panelOrigin, visibleFrame: visFrame)
        setHintPillPlacement(aboveWheel: cramped)
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        evaluateHintPillPlacement()
    }

    public func toggleMode(isAdvanced: Bool) {
        self.isAdvanced = isAdvanced
        configure(files: targetFiles, isOptionHeld: isAdvanced)
    }

    public func configure(files: [URL], isOptionHeld: Bool) {
        self.targetFiles = files
        self.isAdvanced = isOptionHeld

        dismissParameterPanel(animated: false)

        guard let firstFile = files.first else {
            // Empty state: wheel opened without remembered files
            nodeViews.forEach { $0.removeFromSuperview() }
            nodeViews.removeAll()
            hudView.isHidden = true
            centerDisc.isHidden = false
            centerDisc.alphaValue = 1.0
            hintPillContainer.alphaValue = 1.0
            compactProgressContainer.isHidden = true
            centerDisc.configureEmpty()
            return
        }

        // Remove old nodes
        nodeViews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()

        hudView.isHidden = true
        centerDisc.isHidden = false
        centerDisc.alphaValue = 1.0
        hintPillContainer.alphaValue = 1.0
        centerDisc.configure(files: files, isAdvanced: isOptionHeld)

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        // Center disc bloom
        if !isReduceMotion {
            centerDisc.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.allowsImplicitAnimation = true
                centerDisc.layer?.transform = CATransform3DIdentity
            }
        } else {
            centerDisc.layer?.transform = CATransform3DIdentity
        }

        // Layout 8 slots via WheelLayoutModel
        let slots = WheelLayoutModel.shared.slots(for: firstFile, isAdvanced: isOptionHeld)
        let orbitRadius = WheelLayoutModel.shared.currentSize.orbitRadius

        let hasPrimaryActions = slots.contains(where: { $0.action != nil })
        if !hasPrimaryActions {
            centerDisc.configureUnsupported(fileName: firstFile.lastPathComponent, fileExtension: firstFile.pathExtension)
        }

        for slot in slots {
            let angle = slot.angle
            let nx = WheelGeometry.wheelCenterX + (orbitRadius * cos(angle))
            let ny = WheelGeometry.wheelCenterY + (orbitRadius * sin(angle))

            let nodeView = RadialOptionNodeView(slotKind: slot.kind)
            let nodeWidth: CGFloat = 64.0
            let nodeHeight: CGFloat = 64.0
            nodeView.frame = NSRect(
                x: nx - (nodeWidth / 2.0),
                y: ny - (nodeHeight / 2.0),
                width: nodeWidth,
                height: nodeHeight
            )
            nodeView.layer?.masksToBounds = false

            nodeView.onHoverChanged = { [weak self] isHovered in
                if isHovered {
                    self?.backplateView.hoveredSlotIndex = slot.slotIndex
                } else if self?.backplateView.hoveredSlotIndex == slot.slotIndex {
                    self?.backplateView.hoveredSlotIndex = nil
                }
            }

            nodeView.onSelect = { [weak self] kind in
                switch kind {
                case .action(let act):
                    if act.parameters.isEmpty {
                        self?.performConversion(action: act)
                    } else {
                        self?.showParameterPanel(for: act)
                    }
                case .more:
                    self?.showMoreView()
                case .customize:
                    self?.showCustomizeSheet()
                }
            }

            nodeView.onDrop = { [weak self] kind, droppedFiles in
                self?.targetFiles = droppedFiles
                switch kind {
                case .action(let act):
                    if act.parameters.isEmpty {
                        self?.performConversion(action: act)
                    } else {
                        self?.showParameterPanel(for: act)
                    }
                case .more:
                    self?.showMoreView()
                case .customize:
                    self?.showCustomizeSheet()
                }
            }

            if customizeSheet != nil {
                savedNodeFrames[ObjectIdentifier(nodeView)] = nodeView.frame
                nodeView.frame = .zero
                nodeView.isHidden = true
                nodeView.alphaValue = 0.0
                view.addSubview(nodeView)
                nodeViews.append(nodeView)
            } else if !isReduceMotion {
                // Staggered blooming animation with mass 1.0, stiffness 420.0, damping 28.0 physics
                nodeView.layer?.transform = CATransform3DMakeScale(0.4, 0.4, 1.0)
                nodeView.alphaValue = 0.0

                view.addSubview(nodeView)
                nodeViews.append(nodeView)

                let delay = Double(slot.slotIndex) * 0.025
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.25
                        ctx.allowsImplicitAnimation = true
                        nodeView.layer?.transform = CATransform3DIdentity
                        nodeView.alphaValue = 1.0
                    }
                }
            } else {
                // Plain fade for Reduce Motion
                nodeView.layer?.transform = CATransform3DIdentity
                nodeView.alphaValue = 1.0
                view.addSubview(nodeView)
                nodeViews.append(nodeView)
            }
        }
    }

    // MARK: - Parameter Panel Management (Phase 10 Step 2)

    private func showParameterPanel(for action: ConversionAction) {
        dismissParameterPanel(animated: false)

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        // Dim background elements
        if !isReduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                for node in nodeViews {
                    node.animator().alphaValue = 0.15
                }
                centerDisc.animator().alphaValue = 0.0
                hintPillContainer.animator().alphaValue = 0.0
            }
        } else {
            for node in nodeViews {
                node.alphaValue = 0.15
            }
            centerDisc.alphaValue = 0.0
            hintPillContainer.alphaValue = 0.0
        }

        let model = ParameterFormModel(
            action: action,
            loadLastUsed: true,
            inputFile: targetFiles.first,
            inputFiles: targetFiles,
            asyncProbe: true
        )
        let panel = ParameterPanelView(model: model, action: action)
        let panelW: CGFloat = 310.0
        let panelH: CGFloat = 340.0
        panel.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (panelW / 2.0),
            y: WheelGeometry.wheelCenterY - (panelH / 2.0),
            width: panelW,
            height: panelH
        )

        panel.onCancel = { [weak self] in
            self?.dismissParameterPanel(animated: true)
        }
        panel.onRun = { [weak self, weak model] params in
            model?.saveAsLastUsed()
            self?.dismissParameterPanel(animated: true)
            self?.performConversion(action: action, params: params, formModel: model)
        }

        view.addSubview(panel)
        self.parameterPanelView = panel

        if !isReduceMotion {
            panel.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
            panel.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                panel.animator().layer?.transform = CATransform3DIdentity
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.alphaValue = 1.0
        }
    }

    public func dismissParameterPanel(animated: Bool = true) {
        guard let panel = parameterPanelView else { return }
        self.parameterPanelView = nil

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        let restoreBackground: () -> Void = { [weak self] in
            guard let self = self else { return }
            for node in self.nodeViews {
                node.alphaValue = 1.0
            }
            self.centerDisc.alphaValue = 1.0
            self.hintPillContainer.alphaValue = 1.0
        }

        if animated && !isReduceMotion {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                panel.animator().alphaValue = 0.0
                panel.animator().layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
                for node in self.nodeViews {
                    node.animator().alphaValue = 1.0
                }
                self.centerDisc.animator().alphaValue = 1.0
                self.hintPillContainer.animator().alphaValue = 1.0
            }, completionHandler: {
                panel.removeFromSuperview()
            })
        } else {
            panel.removeFromSuperview()
            restoreBackground()
        }
    }

    public override var acceptsFirstResponder: Bool { return true }

    public private(set) var focusedSlotIndex: Int? = nil {
        didSet {
            for (idx, node) in nodeViews.enumerated() {
                node.isKeyFocused = (idx == focusedSlotIndex)
            }
            backplateView.hoveredSlotIndex = focusedSlotIndex
        }
    }

    public func handleKeyDown(keyCode: UInt16) -> Bool {
        // If Customize sheet is open, let it handle Esc or close
        if customizeSheet != nil && customizeSheet?.superview != nil {
            if keyCode == 53 {
                dismissCustomizeSheet()
                return true
            }
            return false
        }

        // If More view is open, let it handle Esc or close
        if moreView != nil && moreView?.superview != nil {
            if keyCode == 53 {
                dismissMoreView()
                return true
            }
            return false
        }

        // Arrow keys move between nodes (0..<8) cyclically
        switch keyCode {
        case 123, 125: // Left, Down -> move counter-clockwise
            guard !nodeViews.isEmpty else { return false }
            if let current = focusedSlotIndex {
                focusedSlotIndex = (current - 1 + nodeViews.count) % nodeViews.count
            } else {
                focusedSlotIndex = 0
            }
            return true

        case 124, 126: // Right, Up -> move clockwise
            guard !nodeViews.isEmpty else { return false }
            if let current = focusedSlotIndex {
                focusedSlotIndex = (current + 1) % nodeViews.count
            } else {
                focusedSlotIndex = 0
            }
            return true

        case 36, 49: // Return or Space -> executes focused node
            if let idx = focusedSlotIndex, idx >= 0 && idx < nodeViews.count {
                nodeViews[idx].performSelect()
                return true
            }
            return false

        case 48: // Tab -> cycle focus through nodes
            guard !nodeViews.isEmpty else { return false }
            if let current = focusedSlotIndex {
                focusedSlotIndex = (current + 1) % nodeViews.count
            } else {
                focusedSlotIndex = 0
            }
            return true

        case 53: // Esc
            return handleEscKey()

        default:
            return false
        }
    }

    public override func keyDown(with event: NSEvent) {
        if handleKeyDown(keyCode: event.keyCode) {
            return
        }
        super.keyDown(with: event)
    }

    public func handleEscKey() -> Bool {
        if customizeSheet != nil && customizeSheet?.superview != nil {
            dismissCustomizeSheet()
            return true
        }
        if moreView != nil && moreView?.superview != nil {
            dismissMoreView()
            return true
        }
        if parameterPanelView != nil {
            dismissParameterPanel(animated: true)
            return true
        }
        return false
    }

    public override func cancelOperation(_ sender: Any?) {
        if handleEscKey() {
            return
        }
        DragMonitor.shared.closeWheel(reason: "ESC key via cancelOperation")
        onCloseRequested?()
    }

    private func showMoreView() {
        dismissMoreView()
        dismissCustomizeSheet()
        dismissParameterPanel(animated: false)

        let more = RadialWheelMoreView()
        let moreW: CGFloat = 340.0
        let moreH: CGFloat = 400.0
        more.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (moreW / 2.0),
            y: WheelGeometry.wheelCenterY - (moreH / 2.0),
            width: moreW,
            height: moreH
        )

        let actions = WheelLayoutModel.shared.moreActions(for: targetFiles.first, isAdvanced: isAdvanced)
        more.configure(actions: actions)

        more.onSelectAction = { [weak self] action in
            self?.dismissMoreView()
            if action.parameters.isEmpty {
                self?.performConversion(action: action)
            } else {
                self?.showParameterPanel(for: action)
            }
        }
        more.onCloseRequested = { [weak self] in
            self?.dismissMoreView()
        }

        view.addSubview(more)
        self.moreView = more

        if !PreferencesManager.shared.reduceMotionEnabled {
            more.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
            more.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                more.animator().layer?.transform = CATransform3DIdentity
                more.animator().alphaValue = 1.0
            }
        }
    }

    public func dismissMoreView() {
        guard let more = moreView else { return }
        self.moreView = nil
        if !PreferencesManager.shared.reduceMotionEnabled {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                more.animator().alphaValue = 0.0
                more.animator().layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
            }, completionHandler: {
                more.removeFromSuperview()
            })
        } else {
            more.removeFromSuperview()
        }
    }

    public func showCustomizeSheet() {
        dismissCustomizeSheet()
        dismissMoreView()
        dismissParameterPanel(animated: false)

        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        savedNodeFrames.removeAll()
        for node in nodeViews {
            savedNodeFrames[ObjectIdentifier(node)] = node.frame
            node.frame = .zero
            node.isHidden = true
            node.alphaValue = 0.0
        }
        backplateView.isHidden = true
        backplateView.alphaValue = 0.0
        centerDisc.isHidden = true
        centerDisc.alphaValue = 0.0
        hintPillContainer.isHidden = true
        hintPillContainer.alphaValue = 0.0
        wheelCloseButton?.isHidden = true
        wheelCloseButton?.alphaValue = 0.0

        let sheet = RadialWheelCustomizeSheet()
        let sheetW: CGFloat = 360.0
        let sheetH: CGFloat = 480.0
        sheet.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (sheetW / 2.0),
            y: WheelGeometry.wheelCenterY - (sheetH / 2.0),
            width: sheetW,
            height: sheetH
        )

        sheet.onSettingsChanged = { [weak self] in
            self?.applyLayoutSettings()
        }
        sheet.onCloseRequested = { [weak self] in
            self?.dismissCustomizeSheet()
        }

        view.addSubview(sheet, positioned: .above, relativeTo: nil)
        self.customizeSheet = sheet

        if !isReduceMotion {
            sheet.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
            sheet.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                sheet.animator().layer?.transform = CATransform3DIdentity
                sheet.animator().alphaValue = 1.0
            }
        }
    }

    public func dismissCustomizeSheet(animated: Bool = true) {
        guard let sheet = customizeSheet else { return }
        self.customizeSheet = nil
        let isReduceMotion = PreferencesManager.shared.reduceMotionEnabled

        for node in self.nodeViews {
            if let saved = self.savedNodeFrames[ObjectIdentifier(node)], saved.width > 0 && saved.height > 0 {
                node.frame = saved
            }
            node.isHidden = false
            node.alphaValue = 1.0
        }
        self.savedNodeFrames.removeAll()
        if self.nodeViews.contains(where: { $0.frame.width <= 0 || $0.frame.height <= 0 }) {
            self.applyLayoutSettings()
        }
        self.backplateView.isHidden = false
        self.backplateView.alphaValue = 1.0
        self.centerDisc.isHidden = false
        self.centerDisc.alphaValue = 1.0
        self.hintPillContainer.isHidden = false
        self.hintPillContainer.alphaValue = 1.0
        self.wheelCloseButton?.isHidden = false
        self.wheelCloseButton?.alphaValue = 1.0

        if !isReduceMotion && animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                sheet.animator().alphaValue = 0.0
                sheet.animator().layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
            }, completionHandler: {
                sheet.removeFromSuperview()
            })
        } else {
            sheet.removeFromSuperview()
        }
    }

    public func applyLayoutSettings() {
        let size = WheelLayoutModel.shared.currentSize
        let outerD = size.backplateDiameter
        let hubD = size.hubDiameter

        backplateView.outerDiameter = outerD
        backplateView.hubDiameter = hubD
        backplateView.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (outerD / 2.0),
            y: WheelGeometry.wheelCenterY - (outerD / 2.0),
            width: outerD,
            height: outerD
        )

        centerDisc.diameter = hubD
        centerDisc.frame = NSRect(
            x: WheelGeometry.wheelCenterX - (hubD / 2.0),
            y: WheelGeometry.wheelCenterY - (hubD / 2.0),
            width: hubD,
            height: hubD
        )

        configure(files: targetFiles, isOptionHeld: isAdvanced)

        if let sheet = customizeSheet {
            view.addSubview(sheet, positioned: .above, relativeTo: nil)
            for node in nodeViews {
                node.frame = .zero
                node.isHidden = true
                node.alphaValue = 0.0
            }
            backplateView.isHidden = true
            backplateView.alphaValue = 0.0
            centerDisc.isHidden = true
            centerDisc.alphaValue = 0.0
            hintPillContainer.isHidden = true
            hintPillContainer.alphaValue = 0.0
            wheelCloseButton?.isHidden = true
            wheelCloseButton?.alphaValue = 0.0
        }
    }

    private func performConversion(action: ConversionAction, params: ParameterValues = [:], formModel: ParameterFormModel? = nil) {
        guard let file = targetFiles.first else { return }
        DragMonitor.shared.actionExecuted()

        let jobID = UUID()
        self.currentConversionJobID = jobID
        self.currentConvertingFileName = file.lastPathComponent

        let keepOpen = PreferencesManager.shared.keepWheelOpenAfterRunning

        if keepOpen {
            // Keep wheel open: keep nodes and center disc visible, show compact progress row under wheel
            compactProgressContainer.isHidden = false
            compactProgressButton.isHidden = false
            compactProgressButton.title = "Cancel"
            compactProgressBar.isHidden = false
            compactProgressBar.isIndeterminate = true
            compactProgressBar.startAnimation(nil)
            compactProgressLabel.stringValue = "Converting \(file.lastPathComponent)..."
            if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
                compactProgressIcon.image = img
                compactProgressIcon.contentTintColor = ThemeManager.shared.accentColor
            }
        } else {
            // Collapse and fade radial option nodes
            for node in nodeViews {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    node.layer?.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
                    node.alphaValue = 0.0
                }
            }

            // Morph center disc into HUD View
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                centerDisc.alphaValue = 0.0
            }, completionHandler: { [weak self] in
                guard let self = self else { return }
                self.centerDisc.isHidden = true
                self.hudView.isHidden = false
                self.hudView.alphaValue = 0.0
                self.hudView.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)

                self.hudView.showConverting(action: action, filename: file.lastPathComponent)

                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.22
                    self.hudView.alphaValue = 1.0
                    self.hudView.layer?.transform = CATransform3DIdentity
                }
            })
        }

        // Execute conversion in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileParams: ParameterValues
            if let model = formModel {
                do {
                    fileParams = try model.resolveParameters(for: file)
                } catch {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.currentConversionJobID = nil
                        if keepOpen {
                            self.compactProgressBar.stopAnimation(nil)
                            self.compactProgressBar.isHidden = true
                            self.compactProgressContainer.isHidden = false
                            self.compactProgressButton.isHidden = false
                            self.compactProgressButton.title = "Copy Error"
                            self.compactProgressLabel.stringValue = "Error: \(error.localizedDescription)"
                            if let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
                                self.compactProgressIcon.image = img
                                self.compactProgressIcon.contentTintColor = .systemOrange
                            }
                        } else {
                            self.hudView.showError(error.localizedDescription)
                        }
                    }
                    return
                }
            } else {
                fileParams = params
            }

            do {
                let output = try JobRunner.shared.run(action: action, input: file, parameters: fileParams, jobId: jobID)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.currentConversionJobID = nil
                    self.lastOutputURL = output
                    self.lastErrorMessage = nil
                    if keepOpen {
                        self.compactProgressBar.stopAnimation(nil)
                        self.compactProgressBar.isHidden = true
                        self.compactProgressContainer.isHidden = false
                        self.compactProgressButton.isHidden = false
                        self.compactProgressButton.title = "Reveal"

                        let inSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                        let outSize = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int64) ?? 0
                        if inSize > 0 && outSize > 0 {
                            let inMB = String(format: "%.1f MB", Double(inSize) / 1_048_576.0)
                            let outMB = String(format: "%.1f MB", Double(outSize) / 1_048_576.0)
                            if outSize < inSize {
                                let savedPct = Int(round((1.0 - Double(outSize) / Double(inSize)) * 100.0))
                                self.compactProgressLabel.stringValue = "Done · Saved \(savedPct)% (\(inMB) → \(outMB))"
                            } else if outSize > inSize {
                                let incPct = Int(round((Double(outSize) / Double(inSize) - 1.0) * 100.0))
                                self.compactProgressLabel.stringValue = "Done · (\(inMB) → \(outMB) [+\(incPct)%])"
                            } else {
                                self.compactProgressLabel.stringValue = "Done · \(output.lastPathComponent)"
                            }
                        } else {
                            self.compactProgressLabel.stringValue = "Done: \(output.lastPathComponent)"
                        }

                        if let img = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
                            self.compactProgressIcon.image = img
                            self.compactProgressIcon.contentTintColor = .systemGreen
                        }
                    } else {
                        self.hudView.showSuccess(outputURL: output)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.currentConversionJobID = nil
                    self.lastOutputURL = nil
                    self.lastErrorMessage = error.localizedDescription
                    if keepOpen {
                        self.compactProgressBar.stopAnimation(nil)
                        self.compactProgressBar.isHidden = true
                        self.compactProgressContainer.isHidden = false
                        self.compactProgressButton.isHidden = false
                        self.compactProgressButton.title = "Copy Error"
                        self.compactProgressLabel.stringValue = "Error: \(error.localizedDescription)"
                        if let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
                            self.compactProgressIcon.image = img
                            self.compactProgressIcon.contentTintColor = .systemOrange
                        }
                    } else {
                        self.hudView.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
}
