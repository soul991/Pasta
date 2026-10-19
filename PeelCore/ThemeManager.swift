import Foundation
import AppKit

public final class ThemeManager {
    public static let shared = ThemeManager()

    public static let didChangeThemeNotification = Notification.Name("PeelThemeDidChangeNotification")

    public struct PresetColor: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let hex: String

        public init(id: String, name: String, hex: String) {
            self.id = id
            self.name = name
            self.hex = hex
        }
    }

    public let presets: [PresetColor] = [
        PresetColor(id: "orange", name: "Tangerine", hex: "#FF6B00"),
        PresetColor(id: "coral", name: "Deep Coral", hex: "#FF4B4B"),
        PresetColor(id: "purple", name: "Electric Purple", hex: "#8B5CF6"),
        PresetColor(id: "ocean", name: "Ocean Blue", hex: "#0EA5E9"),
        PresetColor(id: "emerald", name: "Mint Emerald", hex: "#10B981"),
        PresetColor(id: "gold", name: "Amber Gold", hex: "#F59E0B"),
        PresetColor(id: "pink", name: "Hot Pink", hex: "#EC4899")
    ]

    private let userDefaultsKey = "peel_accent_hex"

    public private(set) var currentHex: String {
        didSet {
            UserDefaults.standard.set(currentHex, forKey: userDefaultsKey)
            NotificationCenter.default.post(name: ThemeManager.didChangeThemeNotification, object: self)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey), !saved.isEmpty {
            self.currentHex = saved
        } else {
            self.currentHex = "#FF6B00" // Default Tangerine
        }
    }

    public func setAccentHex(_ hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("#") {
            clean = "#" + clean
        }
        guard clean.count == 7, Int(clean.dropFirst(), radix: 16) != nil else {
            return
        }
        self.currentHex = clean.uppercased()
    }

    public var accentColor: NSColor {
        return NSColor(hex: currentHex) ?? NSColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0)
    }

    public var accentColorSubtle: NSColor {
        return accentColor.withAlphaComponent(0.15)
    }

    public var accentColorHover: NSColor {
        return accentColor.withAlphaComponent(0.25)
    }
}

extension NSColor {
    public convenience init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        guard cString.count == 6, let rgbValue = UInt64(cString, radix: 16) else {
            return nil
        }
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    public var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FF6B00" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
