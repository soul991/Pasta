import Foundation
import Vision
import CoreGraphics
import ImageIO

public final class QRReader {
    public static func readQRCode(from url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PastaError.invalidInput("File does not exist at '\(url.path)'")
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let urlHandler = VNImageRequestHandler(url: url, options: [:])
        do {
            try urlHandler.perform([request])
            if let results = request.results,
               let first = results.first,
               let payload = first.payloadStringValue {
                return payload
            }
        } catch {}

        // Fallback with CGImageSource
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let cgHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try cgHandler.perform([request])
        if let results = request.results,
           let first = results.first,
           let payload = first.payloadStringValue {
            return payload
        }
        return nil
    }
}
