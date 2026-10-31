import Foundation
import AppKit

public final class BrandAssetManager {
    public static let shared = BrandAssetManager()

    private init() {}

    /// Loads the MenuBarIcon template glyph (default 18pt x 18pt)
    public static func loadMenuBarIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage? {
        // 1. Try named resource
        if let img = NSImage(named: "MenuBarIcon") {
            let copy = img.copy() as! NSImage
            copy.isTemplate = true
            copy.size = size
            PastaLogger.shared.log("BrandAssetManager: loaded MenuBarIcon via NSImage(named: 'MenuBarIcon')")
            return copy
        }

        // 2. Try main bundle resource
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "pdf"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = size
            PastaLogger.shared.log("BrandAssetManager: loaded MenuBarIcon via Bundle.main.url: \(url.path)")
            return img
        }

        // 3. Try core bundle
        let coreBundle = Bundle(for: BrandAssetManager.self)
        if let url = coreBundle.url(forResource: "MenuBarIcon", withExtension: "pdf"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = size
            PastaLogger.shared.log("BrandAssetManager: loaded MenuBarIcon via coreBundle.url: \(url.path)")
            return img
        }

        // 4. Try candidate paths for CLI tests / development
        let candidatePaths = [
            "assets/MenuBarIcon.pdf",
            "Pasta.app/Contents/Resources/MenuBarIcon.pdf",
            "../assets/MenuBarIcon.pdf",
            "../../assets/MenuBarIcon.pdf",
            "/Applications/Pasta.app/Contents/Resources/MenuBarIcon.pdf"
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                img.isTemplate = true
                img.size = size
                PastaLogger.shared.log("BrandAssetManager: loaded MenuBarIcon from path: \(path)")
                return img
            }
        }

        PastaLogger.shared.log("BrandAssetManager: WARNING - MenuBarIcon.pdf not found in bundle or filesystem search paths (checked Bundle.main, assets/MenuBarIcon.pdf, Pasta.app/Contents/Resources/MenuBarIcon.pdf).")
        return nil
    }

    /// Loads the high-resolution Pasta App Icon (default 64pt x 64pt)
    public static func loadAppIcon(size: NSSize = NSSize(width: 64, height: 64)) -> NSImage? {
        // 1. Try named AppIcon
        if let img = NSImage(named: "AppIcon") {
            let copy = img.copy() as! NSImage
            copy.size = size
            return copy
        }

        // 2. Try main bundle AppIcon.icns
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            img.size = size
            return img
        }

        // 3. Try candidate file paths
        let candidatePaths = [
            "assets/AppIcon.icns",
            "assets/AppIcon-1024.png",
            "Pasta.app/Contents/Resources/AppIcon.icns",
            "../assets/AppIcon.icns",
            "../assets/AppIcon-1024.png",
            "../../assets/AppIcon.icns"
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                img.size = size
                return img
            }
        }

        if let appIcon = NSApp.applicationIconImage {
            let copy = appIcon.copy() as! NSImage
            copy.size = size
            return copy
        }

        return nil
    }

    /// Verifies that a status item's button image is configured correctly as a template with 18 pt size.
    public static func verifyStatusItemImage(button: NSStatusBarButton?) -> (isSet: Bool, isTemplate: Bool, size: NSSize, logReason: String) {
        guard let button = button else {
            return (false, false, .zero, "NSStatusBarButton is nil")
        }
        guard let image = button.image else {
            return (false, false, .zero, "button.image is nil; fallback title or missing asset")
        }

        let isTemplate = image.isTemplate
        let size = image.size
        let isCorrectSize = (size.width == 18 && size.height == 18)

        if isTemplate && isCorrectSize {
            return (true, true, size, "Status item image correctly configured: 18x18 template glyph")
        } else if !isTemplate {
            return (true, false, size, "Status item image is set but isTemplate is false; will not adapt to Dark Mode")
        } else {
            return (true, true, size, "Status item image size is \(size.width)x\(size.height), expected 18x18")
        }
    }
}
