import Foundation
import CryptoKit
import PeelCore

var totalTests = 0
var passedTests = 0
var failedTests = 0

func assertTest(_ condition: Bool, _ name: String, details: String = "") {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  ✓ PASS: \(name)")
    } else {
        failedTests += 1
        print("  ✗ FAIL: \(name) \(details.isEmpty ? "" : "- " + details)")
    }
}

func fileSHA256(url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

print("==================================================")
print("Running PeelCore Unit & Integration Test Suite")
print("==================================================")

// MARK: - 1. ToolLocator Tests
print("\n--- 1. ToolLocator Tests ---")
do {
    let sips = ToolLocator.shared.findTool("sips")
    assertTest(sips != nil, "ToolLocator finds system tool 'sips'")
    
    let ffmpeg = ToolLocator.shared.findTool("ffmpeg")
    assertTest(ffmpeg != nil, "ToolLocator finds Homebrew tool 'ffmpeg'")
    
    var threwMissing = false
    do {
        _ = try ToolLocator.shared.requireTool("definitely_fake_binary_12345")
    } catch PeelError.missingTool(let name) {
        threwMissing = (name == "definitely_fake_binary_12345")
    } catch {
        threwMissing = false
    }
    assertTest(threwMissing, "ToolLocator throws PeelError.missingTool for nonexistent tool")
}

// MARK: - 2. OutputPlanner Tests
print("\n--- 2. OutputPlanner Tests ---")
do {
    let tempDir = try OutputPlanner.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    let samplePng = tempDir.appendingPathComponent("sample.png")
    try "data".write(to: samplePng, atomically: true, encoding: .utf8)
    
    // Test basic plan without collision
    let outJpg = OutputPlanner.planOutput(for: samplePng, targetExtension: "jpg")
    assertTest(outJpg.lastPathComponent == "sample.jpg", "OutputPlanner plans 'sample.jpg' when target does not exist")
    
    // Create sample.jpg to trigger collision
    try "existing".write(to: outJpg, atomically: true, encoding: .utf8)
    let outJpg1 = OutputPlanner.planOutput(for: samplePng, targetExtension: "jpg")
    assertTest(outJpg1.lastPathComponent == "sample 1.jpg", "OutputPlanner plans 'sample 1.jpg' when 'sample.jpg' exists")
    
    // Create sample 1.jpg
    try "existing 1".write(to: outJpg1, atomically: true, encoding: .utf8)
    let outJpg2 = OutputPlanner.planOutput(for: samplePng, targetExtension: "jpg")
    assertTest(outJpg2.lastPathComponent == "sample 2.jpg", "OutputPlanner plans 'sample 2.jpg' when 'sample 1.jpg' exists")
    
    // Test same extension collision prevention (original must not be overwritten)
    let outPngColl = OutputPlanner.planOutput(for: samplePng, targetExtension: "png")
    assertTest(outPngColl.lastPathComponent == "sample 1.png", "OutputPlanner never plans original path if target extension matches input")
} catch {
    assertTest(false, "OutputPlanner test setup failed", details: error.localizedDescription)
}

// MARK: - 3. FormatRegistry Tests
print("\n--- 3. FormatRegistry Tests ---")
do {
    let upperURL = URL(fileURLWithPath: "/tmp/UPPERCASE.PNG")
    let upperActions = FormatRegistry.shared.actions(for: upperURL)
    let hasJpeg = upperActions.contains { $0.outputExtension == "jpg" }
    assertTest(hasJpeg, "FormatRegistry handles uppercase extension '.PNG' case-insensitively")
    
    let standardActions = FormatRegistry.shared.actions(for: upperURL, isOptionHeld: false)
    assertTest(standardActions.allSatisfy { !$0.isAdvanced }, "isOptionHeld: false returns only standard actions")
    
    let advancedActions = FormatRegistry.shared.actions(for: upperURL, isOptionHeld: true)
    assertTest(advancedActions.allSatisfy { $0.isAdvanced }, "isOptionHeld: true returns only advanced actions")
    
    // Command builder argument test for hostile filenames
    let hostileInput = URL(fileURLWithPath: "/tmp/nasty/--leading-dash 'quote' and spaces.png")
    let hostileOutput = URL(fileURLWithPath: "/tmp/nasty/out.jpg")
    if let jpegAction = FormatRegistry.shared.action(for: hostileInput, actionID: "image.to.jpeg") {
        let invocations = jpegAction.buildInvocations(hostileInput, hostileOutput)
        assertTest(!invocations.isEmpty, "Command builder successfully generated invocations for hostile path")
        let firstInv = invocations[0]
        assertTest(firstInv.arguments.contains(hostileInput.path), "Invocation arguments contain exact un-escaped raw input path string safely in arguments array")
    } else {
        assertTest(false, "Failed to find image.to.jpeg action")
    }
}

// MARK: - 4. Integration Tests on Fixtures
print("\n--- 4. Integration Tests on Real Fixtures ---")
let testDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures")
let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("test_outputs_phase2")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
defer {
    try? FileManager.default.removeItem(at: outDir)
}

struct TestCase {
    let relativePath: String
    let targetExt: String
    let actionId: String?
}

let testCases: [TestCase] = [
    TestCase(relativePath: "sample.png", targetExt: "jpg", actionId: "image.to.jpeg"),
    TestCase(relativePath: "sample.jpg", targetExt: "webp", actionId: "image.to.webp"),
    TestCase(relativePath: "sample.svg", targetExt: "png", actionId: "image.to.png"),
    TestCase(relativePath: "sample.mp4", targetExt: "mp3", actionId: "video.extract.mp3"),
    TestCase(relativePath: "sample.mp3", targetExt: "wav", actionId: "audio.to.wav"),
    TestCase(relativePath: "sample.pdf", targetExt: "txt", actionId: "pdf.to.text"),
    TestCase(relativePath: "sample.docx", targetExt: "md", actionId: "docx.to.md"),
    TestCase(relativePath: "sample.md", targetExt: "html", actionId: "md.to.html"),
    TestCase(relativePath: "sample.srt", targetExt: "vtt", actionId: "srt.to.vtt"),
    TestCase(relativePath: "sample.zip", targetExt: "", actionId: "archive.extract"),
    TestCase(relativePath: "sample with spaces.png", targetExt: "jpg", actionId: "image.to.jpeg"),
    TestCase(relativePath: "user's document.jpg", targetExt: "png", actionId: "image.to.png"),
    TestCase(relativePath: "-weird.mp4", targetExt: "mp3", actionId: "video.extract.mp3"),
    TestCase(relativePath: "SAMPLE_PHOTO.JPG", targetExt: "webp", actionId: "image.to.webp"),
    TestCase(relativePath: "サンプル_নমুনা.png", targetExt: "jpg", actionId: "image.to.jpeg"),
    TestCase(relativePath: "photo_🎉_cool.jpg", targetExt: "png", actionId: "image.to.png"),
    TestCase(relativePath: "very_long_file_name_that_exceeds_normal_lengths_for_boundary_testing_in_peel_converter_1234567890_abcdefghijklmnopqrstuvwxyz.png", targetExt: "jpg", actionId: "image.to.jpeg")
]

for tc in testCases {
    let fixtureURL = testDir.appendingPathComponent(tc.relativePath)
    guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        assertTest(false, "Fixture not found: \(tc.relativePath)")
        continue
    }
    
    guard let action = FormatRegistry.shared.action(for: fixtureURL, actionID: tc.actionId ?? "")
            ?? FormatRegistry.shared.action(for: fixtureURL, targetExtension: tc.targetExt) else {
        assertTest(false, "No action found for \(tc.relativePath) -> \(tc.targetExt)")
        continue
    }
    
    let originalHashBefore = fileSHA256(url: fixtureURL)
    
    do {
        let outputURL = try JobRunner.shared.run(action: action, input: fixtureURL, destinationDirectory: outDir)
        let exists = FileManager.default.fileExists(atPath: outputURL.path)
        let originalHashAfter = fileSHA256(url: fixtureURL)
        let unchanged = (originalHashBefore == originalHashAfter)
        
        assertTest(exists && unchanged, "Convert \(fixtureURL.lastPathComponent) -> \(action.id)", details: exists ? (unchanged ? "" : "Original was modified!") : "Output file missing!")
    } catch {
        assertTest(false, "Convert \(fixtureURL.lastPathComponent) -> \(action.id)", details: error.localizedDescription)
    }
}

// MARK: - 5. Phase 4: InputValidator & Advanced Tools Tests
print("\n--- 5. Phase 4: InputValidator & Advanced Actions ---")
do {
    // 5.1 InputValidator Tests
    let emptyURL = testDir.appendingPathComponent("empty_zero_byte.txt")
    var caughtEmpty = false
    do {
        try InputValidator.validateInputFile(emptyURL)
    } catch {
        caughtEmpty = true
    }
    assertTest(caughtEmpty, "InputValidator rejects empty zero-byte file")

    var caughtTime = false
    do {
        try InputValidator.validateTimeRange(start: 15.0, end: 10.0)
    } catch {
        caughtTime = true
    }
    assertTest(caughtTime, "InputValidator rejects end time before start time")

    var caughtDim = false
    do {
        try InputValidator.validateDimensions(width: -100, height: 200)
    } catch {
        caughtDim = true
    }
    assertTest(caughtDim, "InputValidator rejects negative image dimensions")

    var caughtPDFMerge = false
    do {
        try InputValidator.validatePDFMerge(files: [testDir.appendingPathComponent("sample.pdf")])
    } catch {
        caughtPDFMerge = true
    }
    assertTest(caughtPDFMerge, "InputValidator rejects PDF merge with fewer than 2 files")

    // 5.2 Advanced Actions: Metadata Stripping
    let photoURL = testDir.appendingPathComponent("photo_🎉_cool.jpg")
    if let stripAction = FormatRegistry.shared.action(for: photoURL, actionID: "image.advanced.strip_metadata") {
        do {
            let strippedOut = try JobRunner.shared.run(action: stripAction, input: photoURL, destinationDirectory: outDir)
            assertTest(FileManager.default.fileExists(atPath: strippedOut.path), "Advanced: strip image metadata creates output")
            
            // Verify with exiftool that EXIF is clean
            let exifProcess = Process()
            exifProcess.executableURL = ToolLocator.shared.findTool("exiftool")
            exifProcess.arguments = ["-s", strippedOut.path]
            let pOut = Pipe()
            exifProcess.standardOutput = pOut
            try exifProcess.run()
            exifProcess.waitUntilExit()
            let exifData = pOut.fileHandleForReading.readDataToEndOfFile()
            let exifStr = String(data: exifData, encoding: .utf8) ?? ""
            assertTest(!exifStr.contains("Artist") && !exifStr.contains("GPS"), "Advanced: image metadata stripped clean according to exiftool")
        } catch {
            assertTest(false, "Advanced: strip image metadata failed", details: error.localizedDescription)
        }
    }

    // 5.3 Advanced Actions: PDF Split
    let samplePdfURL = testDir.appendingPathComponent("sample.pdf")
    if let splitAction = FormatRegistry.shared.action(for: samplePdfURL, actionID: "pdf.advanced.split") {
        do {
            let splitFolder = try JobRunner.shared.run(action: splitAction, input: samplePdfURL, destinationDirectory: outDir)
            let items = (try? FileManager.default.contentsOfDirectory(at: splitFolder, includingPropertiesForKeys: nil)) ?? []
            assertTest(!items.isEmpty && items.contains { $0.lastPathComponent.hasPrefix("page-") }, "Advanced: PDF split creates directory with page PDFs")
        } catch {
            assertTest(false, "Advanced: PDF split failed", details: error.localizedDescription)
        }
    }

    // 5.4 Advanced Actions: PDF Compress
    if let pdfCompAction = FormatRegistry.shared.action(for: samplePdfURL, actionID: "pdf.advanced.compress") {
        do {
            let compPdf = try JobRunner.shared.run(action: pdfCompAction, input: samplePdfURL, destinationDirectory: outDir)
            assertTest(FileManager.default.fileExists(atPath: compPdf.path), "Advanced: PDF compress produces valid PDF")
        } catch {
            assertTest(false, "Advanced: PDF compress failed", details: error.localizedDescription)
        }
    }
}

print("\n==================================================")
print("Test Suite Summary: \(passedTests)/\(totalTests) Passed, \(failedTests) Failed")
print("==================================================")

if failedTests > 0 {
    exit(1)
} else {
    exit(0)
}
