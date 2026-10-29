import Foundation

public struct FinderSelectionHelper {
    public static func parseSelectionPaths(from scriptOutput: String) -> [String] {
        return scriptOutput
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public static func formatPermissionDeniedMessage() -> String {
        return "Pasta needs Automation permissions to interact with Finder. Please enable Pasta in System Settings -> Privacy & Security -> Automation."
    }
}
