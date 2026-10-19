import Foundation

public final class PreferencesManager {
    public static let shared = PreferencesManager()

    public enum OutputLocationMode: String, Codable {
        case besideOriginal
        case customFolder
    }

    private let modeKey = "peel_output_mode"
    private let customPathKey = "peel_output_custom_path"

    public var outputMode: OutputLocationMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: modeKey),
                  let mode = OutputLocationMode(rawValue: raw) else {
                return .besideOriginal
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    public var customFolderPath: String? {
        get {
            return UserDefaults.standard.string(forKey: customPathKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: customPathKey)
        }
    }

    public func effectiveDestination(for inputURL: URL) -> URL? {
        if outputMode == .customFolder, let path = customFolderPath, !path.isEmpty {
            let customURL = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: customURL.path, isDirectory: &isDir), isDir.boolValue {
                return customURL
            }
        }
        return nil // nil indicates beside original file
    }
}
