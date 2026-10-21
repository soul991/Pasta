import Foundation

public struct OutputPlanner {
    public static func planOutput(for inputURL: URL, targetExtension: String, destinationDirectory: URL? = nil) -> URL {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        let ext = targetExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        var candidateName = ext.isEmpty ? originalBaseName : "\(originalBaseName).\(ext)"
        var candidateURL = directory.appendingPathComponent(candidateName)
        
        let fm = FileManager.default
        // Must not overwrite existing file or input file itself
        if !fm.fileExists(atPath: candidateURL.path) && candidateURL.path != inputURL.path {
            return candidateURL
        }
        
        var counter = 1
        while true {
            candidateName = ext.isEmpty ? "\(originalBaseName) \(counter)" : "\(originalBaseName) \(counter).\(ext)"
            candidateURL = directory.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidateURL.path) && candidateURL.path != inputURL.path {
                return candidateURL
            }
            counter += 1
        }
    }
    
    public static func planOutputDirectory(for inputURL: URL, suffix: String = "extracted", destinationDirectory: URL? = nil) -> URL {
        let directory = destinationDirectory ?? inputURL.deletingLastPathComponent()
        let originalBaseName = inputURL.deletingPathExtension().lastPathComponent
        
        var candidateName = "\(originalBaseName) \(suffix)"
        var candidateURL = directory.appendingPathComponent(candidateName)
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }
        
        var counter = 1
        while true {
            candidateName = "\(originalBaseName) \(suffix) \(counter)"
            candidateURL = directory.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
    
    public static func makeTempDirectory() throws -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Pasta_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
