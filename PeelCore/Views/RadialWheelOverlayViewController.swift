import Foundation
import AppKit

public final class RadialWheelOverlayViewController: NSViewController {
    public var onCloseRequested: (() -> Void)?

    private var targetFiles: [URL] = []
    private var isAdvanced: Bool = false

    private let centerDisc = RadialWheelCenterDiscView()
    private let hudView = RadialConversionHUDView()
    private var nodeViews: [RadialOptionNodeView] = []

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 420))
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Center Disc
        centerDisc.frame = NSRect(x: 210 - 55, y: 210 - 55, width: 110, height: 110)
        view.addSubview(centerDisc)

        // HUD View (initially hidden)
        hudView.frame = NSRect(x: 210 - 75, y: 210 - 75, width: 150, height: 150)
        hudView.isHidden = true
        hudView.onDismiss = { [weak self] in
            self?.onCloseRequested?()
        }
        view.addSubview(hudView)
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

        // Spring animation for center disc
        centerDisc.layer?.transform = CATransform3DMakeScale(0.7, 0.7, 1.0)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            centerDisc.layer?.transform = CATransform3DIdentity
        }

        // Fetch valid actions
        let actions = FormatRegistry.shared.actions(for: firstFile, isOptionHeld: isOptionHeld)
        guard !actions.isEmpty else { return }

        let count = actions.count
        let orbitRadius: CGFloat = 138.0
        let centerX: CGFloat = 210.0
        let centerY: CGFloat = 210.0

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

            // Start collapsed at center, then bloom outward into orbit!
            nodeView.layer?.transform = CATransform3DMakeScale(0.2, 0.2, 1.0)
            nodeView.alphaValue = 0.0

            view.addSubview(nodeView)
            nodeViews.append(nodeView)

            // Staggered blooming animation
            let delay = Double(index) * 0.03
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.28
                    ctx.allowsImplicitAnimation = true
                    nodeView.layer?.transform = CATransform3DIdentity
                    nodeView.alphaValue = 1.0
                }
            }
        }
    }

    private func performConversion(action: ConversionAction) {
        guard let file = targetFiles.first else { return }

        // Collapse and fade radial option nodes
        for node in nodeViews {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                node.layer?.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
                node.alphaValue = 0.0
            }
        }

        // Morph center disc into HUD View
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            centerDisc.alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.centerDisc.isHidden = true
            self.hudView.isHidden = false
            self.hudView.alphaValue = 0.0
            self.hudView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)

            self.hudView.showConverting(action: action, filename: file.lastPathComponent)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
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
