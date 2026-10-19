import Foundation

public struct InputValidator {
    public static func validateInputFile(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw PeelError.invalidInput("File does not exist at '\(url.path)'")
        }

        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        if size == 0 {
            throw PeelError.invalidInput("File is empty (0 bytes): '\(url.lastPathComponent)'")
        }
    }

    public static func validateTimeRange(start: Double, end: Double) throws {
        guard start >= 0 else {
            throw PeelError.invalidInput("Start time cannot be negative: \(start)")
        }
        guard end > start else {
            throw PeelError.invalidInput("End time (\(end)s) must be greater than start time (\(start)s)")
        }
    }

    public static func validateDimensions(width: Int, height: Int) throws {
        guard width > 0 && height > 0 else {
            throw PeelError.invalidInput("Invalid dimensions: \(width)x\(height). Width and height must be positive.")
        }
        guard width <= 16384 && height <= 16384 else {
            throw PeelError.invalidInput("Dimensions \(width)x\(height) exceed maximum supported limit (16384px)")
        }
    }

    public static func validatePDFMerge(files: [URL]) throws {
        guard files.count >= 2 else {
            throw PeelError.invalidInput("Merging PDFs requires at least 2 PDF files (received \(files.count))")
        }
        for file in files {
            guard file.pathExtension.lowercased() == "pdf" else {
                throw PeelError.invalidInput("All files for PDF merge must be .pdf files ('\(file.lastPathComponent)' is not a PDF)")
            }
            try validateInputFile(file)
        }
    }
}
