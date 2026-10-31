import Foundation
import AppKit
import QuartzCore

public final class RadialWheelOverlayViewController: NSViewController {
    public var onCloseRequested: (() -> Void)?

    private var targetFiles: [URL] = []
    private var isAdvanced: Bool = false

    private let centerDisc = RadialWheelCenterDiscView()
    private let hudView = RadialConversionHUDView()
    private var nodeViews: [RadialOptionNodeView] = []
    private var parameterPanelView: ParameterPanelView?

    // Floating hint pill
    private let hintPillContainer = NSVisualEffectView()
    private let hintPillLabel = NSTextField(labelWithString: "")

    // Compact progress row below wheel (Phase 10B Step 1)
    private let compactProgressContainer = NSVisualEffectView()
    private let compactProgressIcon = NSImageView()
    private let compactProgressLabel = NSTextField(labelWithString: "")
    private let compactProgressButton = NSButton(title: "Reveal", target: nil, action: nil)
    private var lastOutputURL: URL?

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
        // Center Disc centered at (WheelGeometry.wheelCenterX, WheelGeometry.wheelCenterY)
        centerDisc.frame = NSRect(
            x: WheelGeometry.wheelCenterX - 55,
            y: WheelGeometry.wheelCenterY - 55,
            width: 110,
            height: 110
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
        hintPillLabel.stringValue = "Esc closes · ⌥ tap switches Convert / Advanced · ⇧ hold re-targets"
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
        compactProgressContainer.addSubview(compactProgressIcon)

        compactProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        compactProgressLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        compactProgressLabel.textColor = .white
        compactProgressLabel.lineBreakMode = .byTruncatingMiddle
        compactProgressContainer.addSubview(compactProgressLabel)

        compactProgressButton.translatesAutoresizingMaskIntoConstraints = false
        compactProgressButton.bezelStyle = .inline
        compactProgressButton.title = "Reveal"
        compactProgressButton.target = self
        compactProgressButton.action = #selector(revealOutputClicked)
        compactProgressButton.isHidden = true
        compactProgressContainer.addSubview(compactProgressButton)

        NSLayoutConstraint.activate([
            hintPillContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintPillContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            hintPillContainer.heightAnchor.constraint(equalToConstant: 28),
            hintPillContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            hintPillContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            hintPillLabel.leadingAnchor.constraint(equalTo: hintPillContainer.leadingAnchor, constant: 14),
            hintPillLabel.trailingAnchor.constraint(equalTo: hintPillContainer.trailingAnchor, constant: -14),
            hintPillLabel.centerYAnchor.constraint(equalTo: hintPillContainer.centerYAnchor),

            compactProgressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            compactProgressContainer.bottomAnchor.constraint(equalTo: hintPillContainer.topAnchor, constant: -8),
            compactProgressContainer.heightAnchor.constraint(equalToConstant: 32),
            compactProgressContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            compactProgressContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            compactProgressIcon.leadingAnchor.constraint(equalTo: compactProgressContainer.leadingAnchor, constant: 10),
            compactProgressIcon.centerYAnchor.constraint(equalTo: compactProgressContainer.centerYAnchor),
            compactProgressIcon.widthAnchor.constraint(equalToConstant: 16),
            compactProgressIcon.heightAnchor.constraint(equalToConstant: 16),

            compactProgressLabel.leadingAnchor.constraint(equalTo: compactProgressIcon.trailingAnchor, constant: 8),
            compactProgressLabel.centerYAnchor.constraint(equalTo: compactProgressContainer.centerYAnchor),

            compactProgressButton.leadingAnchor.constraint(equalTo: compactProgressLabel.trailingAnchor, constant: 8),
            compactProgressButton.trailingAnchor.constraint(equalTo: compactProgressContainer.trailingAnchor, constant: -10),
            compactProgressButton.centerYAnchor.constraint(equalTo: compactProgressContainer.centerYAnchor)
        ])

        // Close control (×) at top-right of wheel
        let closeBtn = NSButton(frame: NSRect(
            x: WheelGeometry.wheelCenterX + 140,
            y: WheelGeometry.wheelCenterY + 140,
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
        view.addSubview(closeBtn)
    }

    @objc private func closeButtonClicked() {
        DragMonitor.shared.closeWheel(reason: "Close button (×) clicked")
    }

    @objc private func revealOutputClicked() {
        if let url = lastOutputURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
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
        centerDisc.configure(fileURL: firstFile, isAdvanced: isOptionHeld)

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

        // Fetch valid actions
        let actions = FormatRegistry.shared.actions(for: firstFile, isOptionHeld: isOptionHeld)
        guard !actions.isEmpty else { return }

        let count = actions.count

        for (index, action) in actions.enumerated() {
            let nodeCenter = WheelGeometry.nodeCenter(index: index, totalSlots: count)

            let nodeView = RadialOptionNodeView(action: action)
            let nodeWidth = nodeView.bounds.width
            let nodeHeight = nodeView.bounds.height
            nodeView.frame = NSRect(
                x: nodeCenter.x - (nodeWidth / 2.0),
                y: nodeCenter.y - (nodeHeight / 2.0),
                width: nodeWidth,
                height: nodeHeight
            )
            nodeView.layer?.masksToBounds = false

            nodeView.onSelect = { [weak self] act in
                if act.parameters.isEmpty {
                    self?.performConversion(action: act)
                } else {
                    self?.showParameterPanel(for: act)
                }
            }
            nodeView.onDrop = { [weak self] act, droppedFiles in
                self?.targetFiles = droppedFiles
                if act.parameters.isEmpty {
                    self?.performConversion(action: act)
                } else {
                    self?.showParameterPanel(for: act)
                }
            }

            if !isReduceMotion {
                // Staggered blooming animation with mass 1.0, stiffness 420.0, damping 28.0 physics
                nodeView.layer?.transform = CATransform3DMakeScale(0.4, 0.4, 1.0)
                nodeView.alphaValue = 0.0

                view.addSubview(nodeView)
                nodeViews.append(nodeView)

                let delay = Double(index) * 0.025
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

    public override func cancelOperation(_ sender: Any?) {
        if parameterPanelView != nil {
            dismissParameterPanel(animated: true)
        } else {
            DragMonitor.shared.closeWheel(reason: "ESC key via cancelOperation")
            onCloseRequested?()
        }
    }

    private func performConversion(action: ConversionAction, params: ParameterValues = [:], formModel: ParameterFormModel? = nil) {
        guard let file = targetFiles.first else { return }
        DragMonitor.shared.actionExecuted()

        let keepOpen = PreferencesManager.shared.keepWheelOpenAfterRunning

        if keepOpen {
            // Keep wheel open: keep nodes and center disc visible, show compact progress row under wheel
            compactProgressContainer.isHidden = false
            compactProgressButton.isHidden = true
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
                        if keepOpen {
                            self.compactProgressContainer.isHidden = false
                            self.compactProgressButton.isHidden = true
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
                let output = try JobRunner.shared.run(action: action, input: file, parameters: fileParams)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.lastOutputURL = output
                    if keepOpen {
                        self.compactProgressContainer.isHidden = false
                        self.compactProgressButton.isHidden = false
                        self.compactProgressLabel.stringValue = "Done: \(output.lastPathComponent)"
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
                    if keepOpen {
                        self.compactProgressContainer.isHidden = false
                        self.compactProgressButton.isHidden = true
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
