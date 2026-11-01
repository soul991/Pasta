import Foundation
import AppKit

// MARK: - WCAG 2.1 Color Contrast Utilities

public struct WCAGContrast {
    /// Computes the relative luminance of an sRGB color component
    private static func linearizeComponent(_ c: CGFloat) -> CGFloat {
        if c <= 0.03928 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// Computes the relative luminance of an NSColor (0.0 = darkest black, 1.0 = lightest white)
    public static func relativeLuminance(of color: NSColor) -> CGFloat {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0.5 }
        let r = linearizeComponent(srgb.redComponent)
        let g = linearizeComponent(srgb.greenComponent)
        let b = linearizeComponent(srgb.blueComponent)
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }

    /// Computes the WCAG contrast ratio between two colors (ranging from 1.0 to 21.0)
    public static func contrastRatio(foreground: NSColor, background: NSColor) -> Double {
        let l1 = relativeLuminance(of: foreground)
        let l2 = relativeLuminance(of: background)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return Double((lighter + 0.05) / (darker + 0.05))
    }

    /// Blends a foreground color (which may contain alpha) over an opaque background color
    public static func composite(foreground: NSColor, over background: NSColor) -> NSColor {
        guard let fg = foreground.usingColorSpace(.sRGB),
              let bg = background.usingColorSpace(.sRGB) else { return foreground }
        let a = fg.alphaComponent
        let r = (fg.redComponent * a) + (bg.redComponent * (1.0 - a))
        let g = (fg.greenComponent * a) + (bg.greenComponent * (1.0 - a))
        let b = (fg.blueComponent * a) + (bg.blueComponent * (1.0 - a))
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Returns either dark ink (#1A0F05) or crisp white to guarantee >= 4.5:1 contrast against accent
    public static func contrastingLabelColor(for accent: NSColor) -> NSColor {
        let darkInk = NSColor(hex: "#1A0F05") ?? .black
        let whiteInk = NSColor.white

        let darkContrast = contrastRatio(foreground: darkInk, background: accent)
        let whiteContrast = contrastRatio(foreground: whiteInk, background: accent)

        if darkContrast >= whiteContrast {
            return darkInk
        } else {
            return whiteInk
        }
    }
}

// MARK: - Wheel Themes

public enum WheelTheme: String, CaseIterable, Codable {
    case sunset = "sunset"
    case ocean = "ocean"
    case emerald = "emerald"
    case violet = "violet"
    case rose = "rose"
    case graphite = "graphite"
    case system = "system"

    public var displayName: String {
        switch self {
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .emerald: return "Emerald"
        case .violet: return "Violet"
        case .rose: return "Rose"
        case .graphite: return "Graphite"
        case .system: return "Match System"
        }
    }

    public var hex: String {
        switch self {
        case .sunset: return "#F2611F"
        case .ocean: return "#0EA5E9"
        case .emerald: return "#10B981"
        case .violet: return "#7C3AED"
        case .rose: return "#F43F5E"
        case .graphite: return "#475569"
        case .system: return "#007AFF"
        }
    }

    public var accentColor: NSColor {
        if self == .system {
            return NSColor.controlAccentColor
        }
        return NSColor(hex: hex) ?? NSColor(red: 0.95, green: 0.38, blue: 0.12, alpha: 1.0)
    }

    public var labelColor: NSColor {
        return WCAGContrast.contrastingLabelColor(for: accentColor)
    }

    public var contrastRatio: Double {
        return WCAGContrast.contrastRatio(foreground: labelColor, background: accentColor)
    }
}

// MARK: - Visual Customization Tokens

public enum WheelSize: String, CaseIterable, Codable {
    case compact = "compact"   // 340 pt backplate
    case standard = "standard" // 400 pt backplate (default)
    case large = "large"       // 460 pt backplate

    public var backplateDiameter: CGFloat {
        switch self {
        case .compact: return 340.0
        case .standard: return 400.0
        case .large: return 460.0
        }
    }

    public var orbitRadius: CGFloat {
        switch self {
        case .compact: return 126.0
        case .standard: return 148.0
        case .large: return 170.0
        }
    }

    public var hubDiameter: CGFloat {
        switch self {
        case .compact: return 108.0
        case .standard: return 128.0
        case .large: return 144.0
        }
    }
}

public enum GlassStyle: String, CaseIterable, Codable {
    case clear = "clear"
    case regular = "regular"
    case tinted = "tinted"
}

public enum LabelMode: String, CaseIterable, Codable {
    case always = "always"
    case onHover = "onHover"
}

// MARK: - Slot Architecture

public enum WheelSlotKind: Equatable {
    case action(ConversionAction)
    case more
    case customize
}

public struct WheelSlot: Equatable {
    public let slotIndex: Int // 0..<8
    public let kind: WheelSlotKind
    public let angle: CGFloat // Radians (-pi/2 starting at top)

    public var action: ConversionAction? {
        if case .action(let act) = kind {
            return act
        }
        return nil
    }

    public init(slotIndex: Int, kind: WheelSlotKind, angle: CGFloat) {
        self.slotIndex = slotIndex
        self.kind = kind
        self.angle = angle
    }
}

// MARK: - Wheel Layout Model

public final class WheelLayoutModel {
    public static let shared = WheelLayoutModel()

    // Preferences Keys
    private let themeKey = "pasta_theme_id"
    private let sizeKey = "pasta_wheel_size"
    private let glassStyleKey = "pasta_glass_style"
    private let glassStrengthKey = "pasta_glass_strength"
    private let labelModeKey = "pasta_label_mode"
    private let pinnedPrefix = "pasta_pinned_tools_"
    private let hiddenPrefix = "pasta_hidden_tools_"

    // In-memory overrides (for headless testing without UserDefaults)
    private var testStorage: [String: Any]?

    public init(isolatedStorage: [String: Any]? = nil) {
        self.testStorage = isolatedStorage
    }

    // MARK: - Storage Accessors

    private func storageString(forKey key: String) -> String? {
        if testStorage != nil { return testStorage?[key] as? String }
        return UserDefaults.standard.string(forKey: key)
    }

    private func setStorageString(_ value: String, forKey key: String) {
        if testStorage != nil {
            testStorage?[key] = value
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func storageStringArray(forKey key: String) -> [String]? {
        if testStorage != nil { return testStorage?[key] as? [String] }
        return UserDefaults.standard.stringArray(forKey: key)
    }

    private func setStorageStringArray(_ value: [String], forKey key: String) {
        if testStorage != nil {
            testStorage?[key] = value
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func storageDouble(forKey key: String, default defaultVal: Double) -> Double {
        if testStorage != nil { return (testStorage?[key] as? Double) ?? defaultVal }
        let val = UserDefaults.standard.double(forKey: key)
        return val <= 0 ? defaultVal : val
    }

    private func setStorageDouble(_ value: Double, forKey key: String) {
        if testStorage != nil {
            testStorage?[key] = value
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    // MARK: - Theme & Appearance

    public var currentTheme: WheelTheme {
        get {
            guard let raw = storageString(forKey: themeKey), let theme = WheelTheme(rawValue: raw) else {
                return .sunset
            }
            return theme
        }
        set {
            setStorageString(newValue.rawValue, forKey: themeKey)
            ThemeManager.shared.setAccentHex(newValue.hex)
        }
    }

    public var currentSize: WheelSize {
        get {
            guard let raw = storageString(forKey: sizeKey), let size = WheelSize(rawValue: raw) else {
                return .standard
            }
            return size
        }
        set {
            setStorageString(newValue.rawValue, forKey: sizeKey)
        }
    }

    public var currentGlassStyle: GlassStyle {
        get {
            guard let raw = storageString(forKey: glassStyleKey), let style = GlassStyle(rawValue: raw) else {
                return .regular
            }
            return style
        }
        set {
            setStorageString(newValue.rawValue, forKey: glassStyleKey)
        }
    }

    public var glassStrength: Double {
        get {
            return storageDouble(forKey: glassStrengthKey, default: 0.8)
        }
        set {
            setStorageDouble(min(max(newValue, 0.1), 1.0), forKey: glassStrengthKey)
        }
    }

    public var labelMode: LabelMode {
        get {
            guard let raw = storageString(forKey: labelModeKey), let mode = LabelMode(rawValue: raw) else {
                return .always
            }
            return mode
        }
        set {
            setStorageString(newValue.rawValue, forKey: labelModeKey)
        }
    }

    // MARK: - Pinned Tools per Category

    /// Default 6 pinned tools for each supported category
    public static func defaultPinnedToolIDs(for category: ActionCategory) -> [String] {
        switch category {
        case .image:
            return ["image.to.jpeg", "image.to.png", "image.to.webp", "image.to.gif", "image.to.pdf", "image.compress"]
        case .video:
            return ["video.to.mp4", "video.to.mkv", "video.to.mov", "video.to.webm", "video.extract.mp3", "video.to.gif"]
        case .audio:
            return ["audio.to.mp3", "audio.to.wav", "audio.to.m4a", "audio.to.flac", "audio.to.aac", "audio.normalize"]
        case .pdf:
            return ["pdf.to.text", "pdf.to.images", "pdf.advanced.split", "pdf.compress", "pdf.reorganize", "pdf.merge"]
        case .document:
            return ["docx.to.pdf", "docx.to.md", "docx.to.epub", "md.to.html", "md.to.pdf", "html.to.pdf"]
        case .archive:
            return ["archive.extract", "archive.create.zip", "archive.create.tar", "archive.create.7z", "archive.create.gzip", "metadata.read"]
        case .subtitle, .metadata:
            return []
        }
    }

    /// Returns exactly 6 pinned tool IDs for a category, migrating/filling defaults if needed
    public func pinnedToolIDs(for category: ActionCategory) -> [String] {
        let key = pinnedPrefix + category.rawValue
        let defaults = WheelLayoutModel.defaultPinnedToolIDs(for: category)
        var result = storageStringArray(forKey: key) ?? defaults
        if result.isEmpty { result = defaults }

        // Validate and ensure exactly 6 items
        for d in defaults {
            if result.count >= 6 { break }
            if !result.contains(d) {
                result.append(d)
            }
        }
        let allActions = FormatRegistry.shared.allActions(for: category)
        for a in allActions {
            if result.count >= 6 { break }
            if !result.contains(a.id) {
                result.append(a.id)
            }
        }
        return Array(result.prefix(6))
    }

    public func setPinnedToolIDs(_ ids: [String], for category: ActionCategory) {
        let key = pinnedPrefix + category.rawValue
        setStorageStringArray(Array(ids.prefix(6)), forKey: key)
    }

    public func reorderPinnedTool(from sourceIndex: Int, to destinationIndex: Int, in category: ActionCategory) {
        var current = pinnedToolIDs(for: category)
        guard sourceIndex >= 0 && sourceIndex < current.count,
              destinationIndex >= 0 && destinationIndex < current.count else { return }
        let moved = current.remove(at: sourceIndex)
        current.insert(moved, at: destinationIndex)
        setPinnedToolIDs(current, for: category)
    }

    public func removePinnedTool(at index: Int, in category: ActionCategory) {
        var current = pinnedToolIDs(for: category)
        guard index >= 0 && index < current.count else { return }
        let removedID = current.remove(at: index)
        setToolHidden(removedID, hidden: true, in: category)

        let allActions = FormatRegistry.shared.allActions(for: category)
        let hidden = hiddenToolIDs(for: category)
        if let replacement = allActions.first(where: { !current.contains($0.id) && !hidden.contains($0.id) }) {
            current.append(replacement.id)
        } else if let fallback = WheelLayoutModel.defaultPinnedToolIDs(for: category).first(where: { !current.contains($0) }) {
            current.append(fallback)
        } else if let anyOther = allActions.first(where: { !current.contains($0.id) }) {
            current.append(anyOther.id)
        } else {
            for act in FormatRegistry.shared.allRegisteredActions() {
                if !current.contains(act.id) {
                    current.append(act.id)
                    setToolHidden(act.id, hidden: false, in: category)
                    if current.count == 6 { break }
                }
            }
        }
        setPinnedToolIDs(current, for: category)
    }

    public func addPinnedTool(toolID: String, in category: ActionCategory) {
        var current = pinnedToolIDs(for: category)
        guard !current.contains(toolID) else { return }
        setToolHidden(toolID, hidden: false, in: category)
        if current.count >= 6 {
            current[current.count - 1] = toolID
        } else {
            current.append(toolID)
        }
        setPinnedToolIDs(current, for: category)
    }

    public func unpinnedTools(for category: ActionCategory) -> [ConversionAction] {
        let pinned = Set(pinnedToolIDs(for: category))
        return FormatRegistry.shared.allActions(for: category).filter { !pinned.contains($0.id) }
    }

    public func resetToDefaults(for category: ActionCategory) {
        let key = pinnedPrefix + category.rawValue
        setStorageStringArray(WheelLayoutModel.defaultPinnedToolIDs(for: category), forKey: key)
        let hiddenKey = hiddenPrefix + category.rawValue
        setStorageStringArray([], forKey: hiddenKey)
    }

    public func resetAllToDefaults() {
        for cat in ActionCategory.allCases {
            resetToDefaults(for: cat)
        }
        currentTheme = .sunset
        currentSize = .standard
        currentGlassStyle = .regular
        glassStrength = 0.8
        labelMode = .always
    }

    // MARK: - Hidden Tools

    public func hiddenToolIDs(for category: ActionCategory) -> Set<String> {
        let key = hiddenPrefix + category.rawValue
        return Set(storageStringArray(forKey: key) ?? [])
    }

    public func setToolHidden(_ toolID: String, hidden: Bool, in category: ActionCategory) {
        let key = hiddenPrefix + category.rawValue
        var current = hiddenToolIDs(for: category)
        if hidden {
            current.insert(toolID)
        } else {
            current.remove(toolID)
        }
        setStorageStringArray(Array(current), forKey: key)
    }

    public func isToolHidden(_ toolID: String, in category: ActionCategory) -> Bool {
        return hiddenToolIDs(for: category).contains(toolID)
    }

    // MARK: - Slot Generation for Wheel UI

    /// Computes the 8 wheel slots for a target file:
    /// - Slots 0..5 (1 to 6): primary pinned tools for that category
    /// - Slot 6 (7): More (ellipsis glyph)
    /// - Slot 7 (8): Customize (gear glyph)
    public func slots(for fileURL: URL?, isAdvanced: Bool) -> [WheelSlot] {
        let totalSlots = 8
        var result: [WheelSlot] = []

        let fileCategory: ActionCategory
        let allActions: [ConversionAction]
        if let file = fileURL {
            let actions = FormatRegistry.shared.actions(for: file, isOptionHeld: isAdvanced)
            allActions = actions
            fileCategory = actions.first?.category ?? .image
        } else {
            fileCategory = .image
            allActions = []
        }

        let pinnedIDs = pinnedToolIDs(for: fileCategory).filter { !isToolHidden($0, in: fileCategory) }

        // Slots 0 to 5: Primary tools
        for slotIndex in 0..<6 {
            let angle = (-CGFloat.pi / 2.0) + (CGFloat(slotIndex) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))

            if slotIndex < pinnedIDs.count {
                let targetID = pinnedIDs[slotIndex]
                if let matched = allActions.first(where: { $0.id == targetID }) ?? FormatRegistry.shared.action(byId: targetID) {
                    result.append(WheelSlot(slotIndex: slotIndex, kind: .action(matched), angle: angle))
                    continue
                }
            }

            // Fallback to unused actions
            if let nextAction = allActions.first(where: { act in
                !result.contains(where: { $0.action?.id == act.id }) && !isToolHidden(act.id, in: fileCategory)
            }) {
                result.append(WheelSlot(slotIndex: slotIndex, kind: .action(nextAction), angle: angle))
            }
        }

        // Slot 6: More
        let moreAngle = (-CGFloat.pi / 2.0) + (CGFloat(6) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))
        result.append(WheelSlot(slotIndex: 6, kind: .more, angle: moreAngle))

        // Slot 7: Customize
        let customAngle = (-CGFloat.pi / 2.0) + (CGFloat(7) * (2.0 * CGFloat.pi / CGFloat(totalSlots)))
        result.append(WheelSlot(slotIndex: 7, kind: .customize, angle: customAngle))

        return result
    }

    /// Returns all available actions for the file minus the pinned tools, excluding any tool with missing binary
    public func moreActions(for fileURL: URL?, isAdvanced: Bool) -> [ConversionAction] {
        guard let file = fileURL else { return [] }
        let allActions = FormatRegistry.shared.actions(for: file, isOptionHeld: isAdvanced)
        guard let first = allActions.first else { return [] }
        let pinned = Set(pinnedToolIDs(for: first.category))
        let hidden = hiddenToolIDs(for: first.category)

        return allActions.filter { act in
            // Exclude already pinned and hidden
            guard !pinned.contains(act.id) && !hidden.contains(act.id) else { return false }
            return true
        }
    }
}
