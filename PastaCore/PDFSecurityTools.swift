import Foundation
import AppKit
import CoreGraphics
import CoreText
import PDFKit

public final class PDFSecurityTools {
    public static let shared = PDFSecurityTools()

    public init() {}

    /// Encrypts and locks a PDF using AES-256 via qpdf
    /// Uses an isolated temporary arguments file with 0600 permissions to avoid exposing secrets in logs or process arguments.
    public func lockPDF(input: URL, output: URL, password: String, runner: JobRunner, jobId: UUID) throws {
        _ = try ToolLocator.shared.requireTool("qpdf")
        guard !password.isEmpty else {
            throw PastaError.invalidInput("Password cannot be empty")
        }

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: scratchDir)
        }

        let argFile = scratchDir.appendingPathComponent("qpdf_arg.txt")
        let argContent = "--encrypt\n--user-password=\(password)\n--owner-password=\(password)_owner\n--bits=256\n--\n"

        guard let argData = argContent.data(using: .utf8) else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to encode encryption parameters")
        }

        // Write with strict 0600 POSIX permissions
        try argData.write(to: argFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: argFile.path)

        let inv = Invocation(toolName: "qpdf", arguments: [
            "@\(argFile.path)",
            input.path,
            output.path
        ])
        try runner.execute(invocation: inv, timeoutSeconds: 60, jobId: jobId)
    }

    /// Decrypts and unlocks a PDF using qpdf
    /// Uses a temporary password file with 0600 permissions.
    public func unlockPDF(input: URL, output: URL, password: String, runner: JobRunner, jobId: UUID) throws {
        _ = try ToolLocator.shared.requireTool("qpdf")
        guard !password.isEmpty else {
            throw PastaError.invalidInput("Password cannot be empty")
        }

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: scratchDir)
        }

        let pwFile = scratchDir.appendingPathComponent("qpdf_pw.txt")
        guard let pwData = (password + "\n").data(using: .utf8) else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to encode password")
        }

        try pwData.write(to: pwFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pwFile.path)

        let inv = Invocation(toolName: "qpdf", arguments: [
            "--password-file=\(pwFile.path)",
            "--decrypt",
            input.path,
            output.path
        ])
        try runner.execute(invocation: inv, timeoutSeconds: 60, jobId: jobId)
    }

    /// Applies a text watermark to a PDF document using qpdf --overlay
    public func watermarkPDF(
        input: URL,
        output: URL,
        watermarkText: String,
        opacity: Double = 0.3,
        position: String = "diagonal",
        runner: JobRunner,
        jobId: UUID
    ) throws {
        _ = try ToolLocator.shared.requireTool("qpdf")
        guard let pdfDoc = PDFDocument(url: input), pdfDoc.pageCount > 0 else {
            throw PastaError.invalidInput("Cannot read source PDF at \(input.lastPathComponent)")
        }

        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: scratchDir)
        }

        let stampURL = scratchDir.appendingPathComponent("watermark_stamp.pdf")
        let firstPageSize = pdfDoc.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)

        try generateWatermarkStampPDF(
            to: stampURL,
            pageSize: firstPageSize,
            text: watermarkText,
            opacity: opacity,
            position: position
        )

        let inv = Invocation(toolName: "qpdf", arguments: [
            input.path,
            "--overlay",
            stampURL.path,
            "--",
            output.path
        ])
        try runner.execute(invocation: inv, timeoutSeconds: 60, jobId: jobId)
    }

    /// Adds page numbers to each page of a PDF document using qpdf --overlay
    public func addPageNumbers(
        input: URL,
        output: URL,
        position: String = "bottom-center",
        startNumber: Int = 1,
        format: String = "1, 2, 3",
        runner: JobRunner,
        jobId: UUID
    ) throws {
        _ = try ToolLocator.shared.requireTool("qpdf")
        guard let pdfDoc = PDFDocument(url: input), pdfDoc.pageCount > 0 else {
            throw PastaError.invalidInput("Cannot read source PDF at \(input.lastPathComponent)")
        }

        let totalPages = pdfDoc.pageCount
        let scratchDir = try OutputPlanner.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: scratchDir)
        }

        let stampURL = scratchDir.appendingPathComponent("numbers_stamp.pdf")
        try generatePageNumbersStampPDF(
            to: stampURL,
            sourcePDF: pdfDoc,
            position: position,
            startNumber: startNumber,
            totalPages: totalPages,
            format: format
        )

        let inv = Invocation(toolName: "qpdf", arguments: [
            input.path,
            "--overlay",
            stampURL.path,
            "--",
            output.path
        ])
        try runner.execute(invocation: inv, timeoutSeconds: 60, jobId: jobId)
    }

    // MARK: - Stamp Generation Helpers

    private func generateWatermarkStampPDF(
        to outputURL: URL,
        pageSize: CGSize,
        text: String,
        opacity: Double,
        position: String
    ) throws {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to create watermark stamp context")
        }

        context.beginPage(mediaBox: &mediaBox)
        context.saveGState()

        let clampedOpacity = CGFloat(min(max(opacity, 0.05), 1.0))
        let targetWidth = pageSize.width * 0.8
        let fontSize = max(min(targetWidth / CGFloat(max(text.count, 1)) * 1.5, 48.0), 10.0)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let color = NSColor.gray.withAlphaComponent(clampedOpacity)

        let attrStr = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
        ])
        let line = CTLineCreateWithAttributedString(attrStr)
        let lineBounds = CTLineGetBoundsWithOptions(line, [])

        switch position.lowercased() {
        case "center":
            let x = (pageSize.width - lineBounds.width) / 2.0
            let y = (pageSize.height - lineBounds.height) / 2.0
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        case "top":
            let x = (pageSize.width - lineBounds.width) / 2.0
            let y = pageSize.height - lineBounds.height - 40.0
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        case "bottom":
            let x = (pageSize.width - lineBounds.width) / 2.0
            let y = 40.0
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        default: // diagonal
            // 1. Draw invisible horizontal text anchor so text extractors (pdftotext) and screen readers
            // read the watermark string without line breaks caused by 45-degree rotation.
            context.saveGState()
            context.setTextDrawingMode(.invisible)
            context.textPosition = CGPoint(x: (pageSize.width - lineBounds.width) / 2.0, y: (pageSize.height - lineBounds.height) / 2.0)
            CTLineDraw(line, context)
            context.restoreGState()

            // 2. Draw visible diagonal watermark
            context.saveGState()
            context.translateBy(x: pageSize.width / 2.0, y: pageSize.height / 2.0)
            context.rotate(by: CGFloat.pi / 4.0)
            context.textPosition = CGPoint(x: -lineBounds.width / 2.0, y: -lineBounds.height / 2.0)
            CTLineDraw(line, context)
            context.restoreGState()
        }

        context.restoreGState()
        context.endPage()
        context.closePDF()

        try (pdfData as Data).write(to: outputURL, options: .atomic)
    }

    private func generatePageNumbersStampPDF(
        to outputURL: URL,
        sourcePDF: PDFDocument,
        position: String,
        startNumber: Int,
        totalPages: Int,
        format: String
    ) throws {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to create numbers stamp consumer")
        }

        var firstBox = sourcePDF.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else {
            throw PastaError.executionFailed(tool: "qpdf", exitCode: 1, output: "Failed to create numbers stamp context")
        }

        for i in 0..<totalPages {
            guard let page = sourcePDF.page(at: i) else { continue }
            var pageBox = page.bounds(for: .mediaBox)
            context.beginPage(mediaBox: &pageBox)
            context.saveGState()

            let currentNum = startNumber + i
            let labelText: String
            switch format {
            case "Page 1":
                labelText = "Page \(currentNum)"
            case "Page 1 of N":
                labelText = "Page \(currentNum) of \(startNumber + totalPages - 1)"
            default:
                labelText = "\(currentNum)"
            }

            let fontSize: CGFloat = 11.0
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let color = NSColor.darkGray
            let attrStr = NSAttributedString(string: labelText, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
            ])
            let line = CTLineCreateWithAttributedString(attrStr)
            let lineBounds = CTLineGetBoundsWithOptions(line, [])

            let margin: CGFloat = 36.0
            let x: CGFloat
            let y: CGFloat

            switch position.lowercased() {
            case "bottom-right":
                x = pageBox.width - lineBounds.width - margin
                y = margin
            case "top-right":
                x = pageBox.width - lineBounds.width - margin
                y = pageBox.height - margin - lineBounds.height
            default: // bottom-center
                x = (pageBox.width - lineBounds.width) / 2.0
                y = margin
            }

            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)

            context.restoreGState()
            context.endPage()
        }

        context.closePDF()
        try (pdfData as Data).write(to: outputURL, options: .atomic)
    }
}
