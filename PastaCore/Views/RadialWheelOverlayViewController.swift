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

    // Floating hint pill
    private let hintPillContainer = NSVisualEffectView()
    private let hintPillLabel = NSTextField(labelWithString: "")

    public override func loadView() {
        // Frame large enough for radial orbit (diameter 420) + bottom hint pill
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 480))
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Center Disc centered at (220, 250)
        centerDisc.frame = NSRect(x: 220 - 55, y: 250 - 55, width: 110, height: 110)
        view.addSubview(centerDisc)

        // HUD View (initially hidden)
        hudView.frame = NSRect(x: 220 - 75, y: 250 - 75, width: 150, height: 150)
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
        hintPillLabel.stringValue = "Hold ⇧ to open · Esc cancels · tap ⌥ switches Convert / Advanced"
        hintPillLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        // Calibrated 55% white to guarantee >= 4.5:1 contrast
        hintPillLabel.textColor = ThemeManager.shared.textTertiaryColor
        hintPillLabel.alignment = .center
        hintPillContainer.addSubview(hintPillLabel)

        NSLayoutConstraint.activate([
            hintPillContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintPillContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            hintPillContainer.heightAnchor.constraint(equalToConstant: 28),
            hintPillContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            hintPillContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            hintPillLabel.leadingAnchor.constraint(equalTo: hintPillContainer.leadingAnchor, constant: 14),
            hintPillLabel.trailingAnchor.constraint(equalTo: hintPillContainer.trailingAnchor, constant: -14),
            hintPillLabel.centerYAnchor.constraint(equalTo: hintPillContainer.centerYAnchor)
        ])
    }

    public func toggleMode(isAdvanced: Bool) {
        self.isAdvanced = isAdvanced
        configure(files: targetFiles, isOptionHeld: isAdvanced)
    }

    public func configure(files: [URL], isOptionHeld: Bool) {
        self.targetFiles = files
        self.isAdvanced = isOptionHeld

        guard let firstFile = files.first else { return }

        // Remove old nodes
        nodeViews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()

        hudView.isHidden = true
        centerDisc.isHidden = false
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
        let orbitRadius: CGFloat = 138.0
        let centerX: CGFloat = 220.0
        let centerY: CGFloat = 250.0

        for (index, action) in actions.enumerated() {
            let angle = (-CGFloat.pi / 2.0) + (CGFloat(index) * (2.0 * CGFloat.pi / CGFloat(count)))
            let nodeCenterX = centerX + (orbitRadius * cos(angle))
            let nodeCenterY = centerY + (orbitRadius * sin(angle))

            let nodeView = RadialOptionNodeView(action: action)
            let nodeWidth = nodeView.bounds.width
            let nodeHeight = nodeView.bounds.height
            nodeView.frame = NSRect(
                x: nodeCenterX - (nodeWidth / 2.0),
                y: nodeCenterY - (nodeHeight / 2.0),
                width: nodeWidth,
                height: nodeHeight
            )

            nodeView.onSelect = { [weak self] act in
                self?.performConversion(action: act)
            }
            nodeView.onDrop = { [weak self] act, droppedFiles in
                self?.targetFiles = droppedFiles
                self?.performConversion(action: act)
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

    private func performConversion(action: ConversionAction) {
        guard let file = targetFiles.first else { return }
        DragMonitor.shared.actionExecuted()

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

        // Execute conversion in background
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
