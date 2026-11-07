import Foundation

/// Quality class assigned to conversion and processing actions.
/// Enforces truth-in-advertising for quality guarantees across the Pasta catalog.
public enum QualityClass: String, Codable, CaseIterable, Sendable {
    /// Output decodes to exactly the same content (proven by automated equality tests).
    case lossless = "LOSSLESS (proven)"

    /// Container change without re-encoding (stream copy, verified by packet or stream hash equality).
    case copy = "COPY"

    /// Re-encoded at very high quality (quality metric above documented threshold).
    case visuallyLossless = "VISUALLY LOSSLESS"

    /// Smaller file by user choice (warning plus estimated size shown).
    case lossy = "LOSSY (user-controlled)"

    public var displayName: String {
        return rawValue
    }

    public var isLossless: Bool {
        return self == .lossless || self == .copy
    }
}

/// Central quality policy managing quality classes and proof metrics for all actions.
public struct QualityPolicy {
    /// Catalog mapping action ID to its default quality class.
    public static var defaultActionQualityClasses: [String: QualityClass] = [
        // MARK: - Archives (Lossless container/deflate)
        "archive.create.gzip": .lossless,
        "archive.create.targz": .lossless,
        "archive.create.zip": .lossless,
        "archive.extract": .lossless,

        // MARK: - Audio
        "audio.advanced.compress": .lossy,
        "audio.advanced.strip_metadata": .lossless,
        "audio.bleep": .lossy,
        "audio.channels": .visuallyLossless,
        "audio.compress": .lossy,
        "audio.normalize": .visuallyLossless,
        "audio.to.aiff": .lossless,
        "audio.to.flac": .lossless,
        "audio.to.m4a": .lossy,
        "audio.to.mp3": .lossy,
        "audio.to.ogg": .lossy,
        "audio.to.opus": .lossy,
        "audio.to.wav": .lossless,
        "audio.trim": .copy,

        // MARK: - Code & Text Formats
        "code.to.html": .lossless,
        "code.to.md": .lossless,
        "code.to.pdf": .visuallyLossless,
        "code.to.txt": .lossless,
        "csv.to.xlsx": .lossless,
        "generic.to.pdf": .visuallyLossless,
        "generic.to.txt": .lossless,
        "srt.to.vtt": .lossless,
        "txt.to.docx": .lossless,
        "txt.to.html": .lossless,
        "txt.to.md": .lossless,
        "vtt.to.srt": .lossless,
        "xlsx.to.csv": .lossless,

        // MARK: - Documents & Office Formats
        "docx.to.epub": .visuallyLossless,
        "docx.to.html": .visuallyLossless,
        "docx.to.images": .visuallyLossless,
        "docx.to.md": .lossy,
        "docx.to.pdf": .visuallyLossless,
        "docx.to.txt": .lossy,
        "epub.to.docx": .visuallyLossless,
        "epub.to.html": .visuallyLossless,
        "epub.to.md": .lossy,
        "epub.to.txt": .lossy,
        "html.to.docx": .visuallyLossless,
        "html.to.epub": .visuallyLossless,
        "html.to.md": .lossy,
        "html.to.pdf": .visuallyLossless,
        "html.to.txt": .lossy,
        "md.to.docx": .visuallyLossless,
        "md.to.epub": .visuallyLossless,
        "md.to.html": .visuallyLossless,
        "md.to.pdf": .visuallyLossless,
        "md.to.txt": .lossless,
        "office.to.images": .visuallyLossless,
        "office.to.pdf": .visuallyLossless,

        // MARK: - Images
        "image.advanced.compress": .lossless,
        "image.advanced.resize_50": .lossy,
        "image.advanced.strip_metadata": .lossless,
        "image.collage": .visuallyLossless,
        "image.compress": .lossless,
        "image.ocr.searchable": .visuallyLossless,
        "image.ocr.text": .lossless,
        "image.qr.read": .lossless,
        "image.resize": .lossy,
        "image.to.avif": .visuallyLossless,
        "image.to.bmp": .lossless,
        "image.to.gif": .lossy,
        "image.to.heic": .visuallyLossless,
        "image.to.jpeg": .lossy,
        "image.to.pdf": .visuallyLossless,
        "image.to.png": .lossless,
        "image.to.tiff": .lossless,
        "image.to.webp": .visuallyLossless,

        // MARK: - Metadata
        "metadata.edit": .lossless,
        "metadata.read": .lossless,

        // MARK: - PDF
        "pdf.advanced.compress": .lossless,
        "pdf.advanced.split": .lossless,
        "pdf.advanced.strip_metadata": .lossless,
        "pdf.compress": .lossless,
        "pdf.merge": .lossless,
        "pdf.ocr.searchable": .visuallyLossless,
        "pdf.ocr.text": .lossless,
        "pdf.pagenumbers": .visuallyLossless,
        "pdf.reorganize": .lossless,
        "pdf.security.lock": .lossless,
        "pdf.security.unlock": .lossless,
        "pdf.to.epub": .lossy,
        "pdf.to.epub.calibre": .lossy,
        "pdf.to.images": .lossless,
        "pdf.to.pdfa": .visuallyLossless,
        "pdf.to.text": .lossy,
        "pdf.watermark": .visuallyLossless,

        // MARK: - Video
        "video.advanced.compress": .lossy,
        "video.advanced.strip_metadata": .copy,
        "video.advanced.trim10": .copy,
        "video.compress": .lossy,
        "video.crop": .visuallyLossless,
        "video.extract.m4a": .lossy,
        "video.extract.mp3": .lossy,
        "video.extract.wav": .lossless,
        "video.join": .copy,
        "video.snapshot": .visuallyLossless,
        "video.snapshot.jpg": .lossy,
        "video.speed": .visuallyLossless,
        "video.split": .copy,
        "video.to.avi": .visuallyLossless,
        "video.to.gif": .lossy,
        "video.to.mkv": .copy,
        "video.to.mov": .copy,
        "video.to.mp4": .visuallyLossless,
        "video.to.webm": .visuallyLossless,
        "video.to.wmv": .visuallyLossless,
        "video.trim": .copy
    ]

    /// Resolves the declared quality class for an action identifier.
    public static func qualityClass(for actionId: String) -> QualityClass? {
        return defaultActionQualityClasses[actionId]
    }

    /// Evaluates the effective quality class of an action given user parameter values.
    public static func effectiveQualityClass(for actionId: String, parameters: ParameterValues) -> QualityClass {
        guard let base = qualityClass(for: actionId) else {
            return .lossy
        }

        // Action-specific parameter overrides:
        // 1. Video compression presets
        if actionId == "video.compress" || actionId == "video.advanced.compress" {
            return .lossy
        }

        // 2. Audio compression presets
        if actionId == "audio.compress" || actionId == "audio.advanced.compress" {
            return .lossy
        }

        // 3. PDF compression
        if actionId == "pdf.compress" || actionId == "pdf.advanced.compress" {
            if let mode = parameters["mode"]?.asString, mode.lowercased() == "lossy" {
                return .lossy
            }
            return base
        }

        // 4. Image compression
        if actionId == "image.compress" || actionId == "image.advanced.compress" {
            if let lossy = parameters["lossy"]?.asString, lossy.lowercased() == "true" {
                return .lossy
            }
            return base
        }

        return base
    }
}
