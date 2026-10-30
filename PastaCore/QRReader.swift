import Foundation
import Vision
import CoreGraphics
import ImageIO

public final class QRReader {
    public static func readQRCode(from url: URL) throws -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PastaError.invalidInput("Cannot read image for QR detection from '\(url.lastPathComponent)'")
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        if let results = request.results,
           let first = results.first,
           let payload = first.payloadStringValue {
            return payload
        }
        return nil
    }
}
