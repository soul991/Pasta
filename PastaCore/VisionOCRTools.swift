import Foundation
import AppKit
import Vision
import CoreGraphics
import CoreText
import PDFKit
import ImageIO

public final class VisionOCRTools {
    public static let shared = VisionOCRTools()

    public static let availableLanguages: [String] = [
        "auto", "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR"
    ]

    public init() {}

    private func loadCGImage(from url: URL) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return cgImage
        }
        if let nsImage = NSImage(contentsOf: url),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }
        return nil
    }

    /// Extracts recognized text from an image file URL
    public func recognizeText(from imageURL: URL, language: String? = nil) throws -> String {
        guard let cgImage = loadCGImage(from: imageURL) else {
            throw PastaError.invalidInput("Cannot read or decode image file at \(imageURL.lastPathComponent)")
        }

        let observations = try performRecognition(on: cgImage, language: language)
        guard !observations.isEmpty else {
            return ""
        }

        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Extracts recognized text from each page of a PDF document
    public func recognizeText(fromPDF pdfURL: URL, language: String? = nil) throws -> String {
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            throw PastaError.invalidInput("Cannot read or parse PDF document at \(pdfURL.lastPathComponent)")
        }

        guard pdfDoc.pageCount > 0 else {
            throw PastaError.invalidInput("PDF document has zero pages")
        }

        var allPagesText: [String] = []

        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            guard pageRect.width > 0 && pageRect.height > 0 else { continue }

            let scale: CGFloat = 2.0
            let pixelWidth = Int(pageRect.width * scale)
            let pixelHeight = Int(pageRect.height * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                continue
            }

            context.scaleBy(x: scale, y: scale)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageRect)
            page.draw(with: .mediaBox, to: context)

            guard let cgImage = context.makeImage() else { continue }
            let observations = (try? performRecognition(on: cgImage, language: language)) ?? []
            let pageLines = observations.compactMap { $0.topCandidates(1).first?.string }
            if !pageLines.isEmpty {
                allPagesText.append(pageLines.joined(separator: "\n"))
            }
        }

        return allPagesText.joined(separator: "\n\n") + "\n"
    }

    /// Creates a searchable PDF from an image file
    public func createSearchablePDF(from imageURL: URL, outputURL: URL, language: String? = nil) throws {
        guard let cgImage = loadCGImage(from: imageURL) else {
            throw PastaError.invalidInput("Cannot read or decode image file at \(imageURL.lastPathComponent)")
        }

        let observations = try performRecognition(on: cgImage, language: language)

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PastaError.executionFailed(tool: "VisionOCR", exitCode: 1, output: "Failed to create CGPDFContext")
        }

        pdfContext.beginPage(mediaBox: &mediaBox)

        // 1. Draw page image at native resolution
        pdfContext.draw(cgImage, in: mediaBox)

        // 2. Draw invisible text layer
        drawInvisibleText(observations: observations, in: pdfContext, pageSize: mediaBox.size)

        pdfContext.endPage()
        pdfContext.closePDF()

        try (pdfData as Data).write(to: outputURL, options: .atomic)
    }

    /// Creates a searchable PDF from an existing PDF (rendering pages as images with invisible text overlay)
    public func createSearchablePDF(fromPDF pdfURL: URL, outputURL: URL, language: String? = nil) throws {
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            throw PastaError.invalidInput("Cannot read or parse PDF document at \(pdfURL.lastPathComponent)")
        }

        guard pdfDoc.pageCount > 0 else {
            throw PastaError.invalidInput("PDF document has zero pages")
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw PastaError.executionFailed(tool: "VisionOCR", exitCode: 1, output: "Failed to create CGDataConsumer")
        }

        var firstBox = pdfDoc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else {
            throw PastaError.executionFailed(tool: "VisionOCR", exitCode: 1, output: "Failed to create CGPDFContext")
        }

        let scale: CGFloat = 2.0

        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            var pageRect = page.bounds(for: .mediaBox)
            guard pageRect.width > 0 && pageRect.height > 0 else { continue }

            let pixelWidth = Int(pageRect.width * scale)
            let pixelHeight = Int(pageRect.height * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let renderContext = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                continue
            }

            renderContext.scaleBy(x: scale, y: scale)
            renderContext.setFillColor(NSColor.white.cgColor)
            renderContext.fill(pageRect)
            page.draw(with: .mediaBox, to: renderContext)

            guard let cgImage = renderContext.makeImage() else { continue }
            let observations = (try? performRecognition(on: cgImage, language: language)) ?? []

            pdfContext.beginPage(mediaBox: &pageRect)
            pdfContext.draw(cgImage, in: pageRect)
            drawInvisibleText(observations: observations, in: pdfContext, pageSize: pageRect.size)
            pdfContext.endPage()
        }

        pdfContext.closePDF()
        try (pdfData as Data).write(to: outputURL, options: .atomic)
    }

    // MARK: - Recognition Core

    private func performRecognition(on cgImage: CGImage, language: String?) throws -> [VNRecognizedTextObservation] {
        var resultObservations: [VNRecognizedTextObservation] = []
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                recognitionError = error
                return
            }
            if let results = request.results as? [VNRecognizedTextObservation] {
                resultObservations = results
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        if let lang = language, !lang.isEmpty, lang != "auto" {
            request.recognitionLanguages = [lang]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Fallback for headless environments or runners where accurate level / language correction is unsupported
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            do {
                try handler.perform([request])
            } catch let fallbackError {
                throw PastaError.executionFailed(tool: "VisionOCR", exitCode: 1, output: fallbackError.localizedDescription)
            }
        }

        if let err = recognitionError {
            throw PastaError.executionFailed(tool: "VisionOCR", exitCode: 1, output: err.localizedDescription)
        }

        return resultObservations
    }

    private func drawInvisibleText(observations: [VNRecognizedTextObservation], in context: CGContext, pageSize: CGSize) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)

        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let str = candidate.string
            guard !str.isEmpty else { continue }

            let box = obs.boundingBox
            let x = box.origin.x * pageSize.width
            let y = box.origin.y * pageSize.height
            let h = max(box.size.height * pageSize.height, 8.0)

            let fontSize = max(h * 0.85, 6.0)
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attrStr = NSAttributedString(string: str, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font
            ])
            let line = CTLineCreateWithAttributedString(attrStr)

            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }
}
