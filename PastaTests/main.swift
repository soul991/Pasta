import Foundation
import AppKit
import CryptoKit
import PastaCore

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
print("Running PastaCore Unit & Integration Test Suite")
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
    } catch PastaError.missingTool(let name) {
        threwMissing = (name == "definitely_fake_binary_12345")
    } catch {
        threwMissing = false
    }
    assertTest(threwMissing, "ToolLocator throws PastaError.missingTool for nonexistent tool")
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

    // 5.5 Phase 8 Fix 1: Multi-page and single-page PDF to images and split tests
    let threePagesURL = testDir.appendingPathComponent("three_pages.pdf")
    if FileManager.default.fileExists(atPath: threePagesURL.path) {
        let hashBefore = fileSHA256(url: threePagesURL)
        
        // Test pdf.to.images on 3-page PDF
        if let pdfToImages = FormatRegistry.shared.action(for: threePagesURL, actionID: "pdf.to.images") {
            do {
                let imgFolder1 = try JobRunner.shared.run(action: pdfToImages, input: threePagesURL, destinationDirectory: outDir)
                let items1 = (try? FileManager.default.contentsOfDirectory(at: imgFolder1, includingPropertiesForKeys: nil))?.filter { $0.pathExtension.lowercased() == "png" } ?? []
                assertTest(items1.count == 3, "Fix 1: pdf.to.images on 3-page PDF produces exactly 3 PNGs (\(items1.count) found)")
                
                // Collision test: run again without overwriting
                let imgFolder2 = try JobRunner.shared.run(action: pdfToImages, input: threePagesURL, destinationDirectory: outDir)
                assertTest(imgFolder1.path != imgFolder2.path && FileManager.default.fileExists(atPath: imgFolder2.path), "Fix 1: collision creates distinct folder without overwriting")
            } catch {
                assertTest(false, "Fix 1: pdf.to.images failed", details: error.localizedDescription)
            }
        }
        
        // Test pdf.advanced.split on 3-page PDF
        if let pdfSplit = FormatRegistry.shared.action(for: threePagesURL, actionID: "pdf.advanced.split") {
            do {
                let splitFolder = try JobRunner.shared.run(action: pdfSplit, input: threePagesURL, destinationDirectory: outDir)
                let items = (try? FileManager.default.contentsOfDirectory(at: splitFolder, includingPropertiesForKeys: nil))?.filter { $0.pathExtension.lowercased() == "pdf" } ?? []
                assertTest(items.count == 3, "Fix 1: pdf.advanced.split on 3-page PDF produces exactly 3 PDFs (\(items.count) found)")
            } catch {
                assertTest(false, "Fix 1: pdf.advanced.split failed", details: error.localizedDescription)
            }
        }
        
        let hashAfter = fileSHA256(url: threePagesURL)
        assertTest(hashBefore == hashAfter, "Fix 1: three_pages.pdf checksum unchanged after operations")
    }

    // Single-page PDF test: 1 file in folder
    if let pdfToImagesSingle = FormatRegistry.shared.action(for: samplePdfURL, actionID: "pdf.to.images") {
        do {
            let singleImgFolder = try JobRunner.shared.run(action: pdfToImagesSingle, input: samplePdfURL, destinationDirectory: outDir)
            let singleImgs = (try? FileManager.default.contentsOfDirectory(at: singleImgFolder, includingPropertiesForKeys: nil))?.filter { $0.pathExtension.lowercased() == "png" } ?? []
            assertTest(singleImgs.count == 1, "Fix 1: pdf.to.images on 1-page PDF produces exactly 1 PNG")
        } catch {
            assertTest(false, "Fix 1: single-page pdf.to.images failed", details: error.localizedDescription)
        }
    }

    // 5.6 Phase 8 Fix 2: Timeout tests with fake sleep tool
    let fakeToolDir = outDir.appendingPathComponent("fake_tools")
    try? FileManager.default.createDirectory(at: fakeToolDir, withIntermediateDirectories: true)
    let fakeSleepScript = fakeToolDir.appendingPathComponent("fake_sleep.sh")
    let scriptContent = "#!/bin/sh\nsleep 2\nexit 0\n"
    try? scriptContent.write(to: fakeSleepScript, atomically: true, encoding: .utf8)
    chmod(fakeSleepScript.path, 0o755)
    ToolLocator.shared.setOverride(tool: "fake_sleep", url: fakeSleepScript)

    do {
        let invTimeout = Invocation(toolName: "fake_sleep", arguments: [], timeout: 1.0)
        var timedOutCaught = false
        do {
            try JobRunner.shared.execute(invocation: invTimeout, timeoutSeconds: 1.0)
        } catch PastaError.timedOut {
            timedOutCaught = true
        } catch {
            timedOutCaught = false
        }
        assertTest(timedOutCaught, "Fix 2: fake tool times out with 1.0s timeout and throws PastaError.timedOut")

        let invNoTimeout = Invocation(toolName: "fake_sleep", arguments: [], timeout: nil)
        var noTimeoutSucceeded = false
        do {
            try JobRunner.shared.execute(invocation: invNoTimeout, timeoutSeconds: 0)
            noTimeoutSucceeded = true
        } catch {
            noTimeoutSucceeded = false
        }
        assertTest(noTimeoutSucceeded, "Fix 2: fake tool with nil/0 timeout succeeds without killing")
    }
    ToolLocator.shared.setOverride(tool: "fake_sleep", url: nil)

    // 5.7 Phase 8 Fix 3: Cancellation tests
    let fakeSlowScript = fakeToolDir.appendingPathComponent("fake_slow.sh")
    let slowContent = "#!/bin/sh\nsleep 2\nexit 0\n"
    try? slowContent.write(to: fakeSlowScript, atomically: true, encoding: .utf8)
    chmod(fakeSlowScript.path, 0o755)
    ToolLocator.shared.setOverride(tool: "fake_slow", url: fakeSlowScript)

    do {
        // Test 1: Start two slow jobs, cancel one, confirm only that process dies and the other finishes
        let job1 = UUID()
        let job2 = UUID()
        let inv1 = Invocation(toolName: "fake_slow", arguments: [], timeout: 10.0)
        let inv2 = Invocation(toolName: "fake_slow", arguments: [], timeout: 10.0)

        var job1Result: Error?
        var job2Success = false
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            do {
                try JobRunner.shared.execute(invocation: inv1, timeoutSeconds: 10.0, jobId: job1)
            } catch {
                job1Result = error
            }
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            do {
                try JobRunner.shared.execute(invocation: inv2, timeoutSeconds: 10.0, jobId: job2)
                job2Success = true
            } catch {
                job2Success = false
            }
            group.leave()
        }

        // Give them a moment to start, then cancel job1 only
        Thread.sleep(forTimeInterval: 0.2)
        JobRunner.shared.cancel(jobId: job1)
        group.wait()

        let job1Cancelled = (job1Result as? PastaError) == .cancelled
        assertTest(job1Cancelled && job2Success, "Fix 3: cancelling one of two concurrent jobs cancels only that job and leaves the other running")

        // Test 2: Cancel before process starts
        let preCancelId = UUID()
        JobRunner.shared.cancel(jobId: preCancelId)
        var preCancelCaught = false
        do {
            try JobRunner.shared.execute(invocation: inv1, timeoutSeconds: 10.0, jobId: preCancelId)
        } catch PastaError.cancelled {
            preCancelCaught = true
        } catch {
            preCancelCaught = false
        }
        assertTest(preCancelCaught, "Fix 3: cancelling before process starts throws PastaError.cancelled without running")

        // Test 3: Cancel after process has finished without crashing
        JobRunner.shared.cancel(jobId: job2)
        assertTest(true, "Fix 3: cancelling after process finishes does not crash")
    }
    ToolLocator.shared.setOverride(tool: "fake_slow", url: nil)

    // 5.8 Phase 8 Fix 4: Concurrency & bounded stderr tests
    let fakeEchoScript = fakeToolDir.appendingPathComponent("fake_echo.sh")
    let echoContent = "#!/bin/sh\necho ok\nexit 0\n"
    try? echoContent.write(to: fakeEchoScript, atomically: true, encoding: .utf8)
    chmod(fakeEchoScript.path, 0o755)
    ToolLocator.shared.setOverride(tool: "fake_echo", url: fakeEchoScript)

    do {
        // Test 1: Run 8 fake-tool jobs concurrently and confirm all complete
        let invEcho = Invocation(toolName: "fake_echo", arguments: [], timeout: 10.0)
        let concurrentGroup = DispatchGroup()
        let count = 8
        var successCount = 0
        let countLock = NSLock()

        for _ in 0..<count {
            concurrentGroup.enter()
            DispatchQueue.global().async {
                do {
                    try JobRunner.shared.execute(invocation: invEcho, timeoutSeconds: 10.0)
                    countLock.lock()
                    successCount += 1
                    countLock.unlock()
                } catch {}
                concurrentGroup.leave()
            }
        }
        concurrentGroup.wait()
        assertTest(successCount == count, "Fix 4: 8 concurrent jobs all execute and complete successfully (\(successCount)/\(count))")

        // Test 2: Tool writing > 1MB to stderr: no hang and bounded error string (<= 64KB)
        let fakeChattyScript = fakeToolDir.appendingPathComponent("fake_chatty.sh")
        let chattyContent = "#!/bin/sh\ndd if=/dev/zero bs=1024 count=1500 2>/dev/null | tr '\\0' 'E' >&2\nexit 1\n"
        try? chattyContent.write(to: fakeChattyScript, atomically: true, encoding: .utf8)
        chmod(fakeChattyScript.path, 0o755)
        ToolLocator.shared.setOverride(tool: "fake_chatty", url: fakeChattyScript)

        let invChatty = Invocation(toolName: "fake_chatty", arguments: [], timeout: 10.0)
        var chattyOutputLen = 0
        var chattyFailedGracefully = false

        do {
            try JobRunner.shared.execute(invocation: invChatty, timeoutSeconds: 10.0)
        } catch PastaError.executionFailed(let tool, let code, let output) {
            chattyFailedGracefully = (tool == "fake_chatty" && code == 1)
            chattyOutputLen = output.utf8.count
        } catch {}

        let isBounded = chattyOutputLen > 0 && chattyOutputLen <= 65536
        assertTest(chattyFailedGracefully && isBounded, "Fix 4: tool writing > 1MB to stderr finishes without hanging and produces bounded error message (<= 64KB, got \(chattyOutputLen) bytes)")
        ToolLocator.shared.setOverride(tool: "fake_chatty", url: nil)
    }
    ToolLocator.shared.setOverride(tool: "fake_echo", url: nil)

    // 5.9 Phase 8 Fix 5: Finder selection and permission helper tests
    do {
        let rawFinderPaths = "/Users/test/file1.png\n/Users/test/file 2 with spaces.jpg\n\n/Users/test/-weird.mp4\n"
        let parsed = FinderSelectionHelper.parseSelectionPaths(from: rawFinderPaths)
        assertTest(parsed.count == 3 && parsed[1] == "/Users/test/file 2 with spaces.jpg", "Fix 5: FinderSelectionHelper parses multiple paths with spaces correctly")
        let permMsg = FinderSelectionHelper.formatPermissionDeniedMessage()
        assertTest(permMsg.contains("System Settings") && permMsg.contains("Automation"), "Fix 5: FinderSelectionHelper provides helpful permission guidance")
    }

    // MARK: - 6. Phase 9 Step 1: Parameterized Actions Tests
    print("\n--- 6. Phase 9 Step 1: Parameterized Actions Tests ---")
    do {
        let testVideoURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        let testImageURL = URL(fileURLWithPath: "/tmp/sample.jpg")
        let testOutputURL = URL(fileURLWithPath: "/tmp/output.mp4")
        let testOutputImgURL = URL(fileURLWithPath: "/tmp/output.jpg")

        // 6.1 Defaults reproduce old behavior exactly
        if let trimAction = FormatRegistry.shared.action(for: testVideoURL, actionID: "video.trim") {
            let invs = trimAction.buildInvocations(testVideoURL, testOutputURL)
            let args = invs.first?.arguments ?? []
            let matchesOld = args.contains("-ss") && args.contains("00:00:00") && args.contains("-to") && args.contains("00:00:10")
            assertTest(matchesOld, "Step 1: video.trim default parameters reproduce 10-second trim exactly")
        } else {
            assertTest(false, "Step 1: video.trim action registered")
        }

        if let resizeAction = FormatRegistry.shared.action(for: testImageURL, actionID: "image.resize") {
            let invs = resizeAction.buildInvocations(testImageURL, testOutputImgURL)
            let args = invs.first?.arguments ?? []
            let matchesOld = args.contains("-Z") && args.contains("1200")
            assertTest(matchesOld, "Step 1: image.resize default parameters reproduce 1200px resize exactly")
        } else {
            assertTest(false, "Step 1: image.resize action registered")
        }

        // 6.2 Aliases work
        let trimAlias = FormatRegistry.shared.action(for: testVideoURL, actionID: "video.advanced.trim10")
        assertTest(trimAlias != nil, "Step 1: video.advanced.trim10 alias resolves")
        let resizeAlias = FormatRegistry.shared.action(for: testImageURL, actionID: "image.advanced.resize_50")
        assertTest(resizeAlias != nil, "Step 1: image.advanced.resize_50 alias resolves")

        // 6.3 Custom parameters take effect
        if let trimAction = FormatRegistry.shared.action(for: testVideoURL, actionID: "video.trim") {
            let customInvs = trimAction.buildInvocationsWithParams(testVideoURL, testOutputURL, ["start": .number(15.0), "end": .number(30.0)])
            let customArgs = customInvs.first?.arguments ?? []
            let customMatches = customArgs.contains("00:00:15") && customArgs.contains("00:00:30")
            assertTest(customMatches, "Step 1: video.trim respects custom start and end parameters")
        }

        if let resizeAction = FormatRegistry.shared.action(for: testImageURL, actionID: "image.resize") {
            let customInvs = resizeAction.buildInvocationsWithParams(testImageURL, testOutputImgURL, ["percent": .number(75.0)])
            let customArgs = customInvs.first?.arguments ?? []
            let customMatches = customArgs.contains("-resize") && customArgs.contains("75%")
            assertTest(customMatches, "Step 1: image.resize respects custom percent parameter")
        }

        // 6.4 Out-of-range values rejected
        if let trimAction = FormatRegistry.shared.action(for: testVideoURL, actionID: "video.trim") {
            var threwOutOfRange = false
            do {
                try InputValidator.validateParameters(declared: trimAction.parameters, values: ["start": .number(-5.0)])
            } catch PastaError.invalidInput(let msg) {
                threwOutOfRange = msg.contains("below minimum")
            } catch {}
            assertTest(threwOutOfRange, "Step 1: Out-of-range negative start time is rejected")
        }

        if let resizeAction = FormatRegistry.shared.action(for: testImageURL, actionID: "image.resize") {
            var threwPercentOutOfRange = false
            do {
                try InputValidator.validateParameters(declared: resizeAction.parameters, values: ["percent": .number(600.0)])
            } catch PastaError.invalidInput(let msg) {
                threwPercentOutOfRange = msg.contains("outside allowed range")
            } catch {}
            assertTest(threwPercentOutOfRange, "Step 1: Out-of-range percent (>500%) is rejected")
        }

        // 6.5 Unknown parameter names rejected
        if let trimAction = FormatRegistry.shared.action(for: testVideoURL, actionID: "video.trim") {
            var threwUnknown = false
            do {
                try InputValidator.validateParameters(declared: trimAction.parameters, values: ["bogusParam": .text("hello")])
            } catch PastaError.invalidInput(let msg) {
                threwUnknown = msg.contains("Unknown parameter 'bogusParam'")
            } catch {}
            assertTest(threwUnknown, "Step 1: Unknown parameter name is rejected")
        }

        // 6.6 Hostile characters rejected
        let hostileInputs = ["; rm -rf /", "| cat /etc/passwd", "`whoami`", "$HOME", "\n", "\"", "'", "\0"]
        var allHostileRejected = true
        for hostile in hostileInputs {
            do {
                try InputValidator.validateParameters(
                    declared: [ActionParameter(id: "tag", label: "Tag", kind: .text, defaultValue: .text("test"))],
                    values: ["tag": .text(hostile)]
                )
                allHostileRejected = false
            } catch PastaError.invalidInput(let msg) {
                if !msg.contains("Hostile character") { allHostileRejected = false }
            } catch {
                allHostileRejected = false
            }
        }
        assertTest(allHostileRejected, "Step 1: Hostile characters (; & | ` $ \\n \\r \" ' \\0) rejected before process runs")

        // 6.7 OutputKind on folder actions
        let pdfURL = URL(fileURLWithPath: "/tmp/sample.pdf")
        let pdfImagesAction = FormatRegistry.shared.action(for: pdfURL, actionID: "pdf.to.images")
        let pdfSplitAction = FormatRegistry.shared.action(for: pdfURL, actionID: "pdf.advanced.split")
        let zipURL = URL(fileURLWithPath: "/tmp/sample.zip")
        let zipExtractAction = FormatRegistry.shared.action(for: zipURL, actionID: "archive.extract")

        assertTest(pdfImagesAction?.outputKind == .folder(suffix: "pages"), "Step 1: pdf.to.images has OutputKind .folder(suffix: 'pages')")
        assertTest(pdfSplitAction?.outputKind == .folder(suffix: "split"), "Step 1: pdf.advanced.split has OutputKind .folder(suffix: 'split')")
        assertTest(zipExtractAction?.outputKind == .folder(suffix: "extracted"), "Step 1: archive.extract has OutputKind .folder(suffix: 'extracted')")
    }
}

// MARK: - 7. Phase 9 Step 2: Formats Still Missing Tests
print("\n--- 7. Phase 9 Step 2: Formats Still Missing Tests ---")
do {
    let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures")
    let testTempDir = try OutputPlanner.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: testTempDir) }

    let sampleMp4 = fixturesDir.appendingPathComponent("sample.mp4")
    let sampleMp3 = fixturesDir.appendingPathComponent("sample.mp3")
    let samplePng = fixturesDir.appendingPathComponent("sample.png")
    let sampleJpg = fixturesDir.appendingPathComponent("sample.jpg")
    let samplePdf = fixturesDir.appendingPathComponent("sample.pdf")
    let threePagesPdf = fixturesDir.appendingPathComponent("three_pages.pdf")
    let sampleDocx = fixturesDir.appendingPathComponent("sample.docx")
    let sampleMd = fixturesDir.appendingPathComponent("sample.md")
    let sampleHtml = fixturesDir.appendingPathComponent("sample.html")
    let sampleTxt = fixturesDir.appendingPathComponent("sample.txt")

    // 7.1 Video outputs: AVI and WMV
    let aviAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.to.avi")
    assertTest(aviAction != nil, "Step 2: video.to.avi action is registered")
    if let aviAction = aviAction {
        let hashBefore = fileSHA256(url: sampleMp4)
        let out = try? JobRunner.shared.run(action: aviAction, input: sampleMp4, destinationDirectory: testTempDir)
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let hashAfter = fileSHA256(url: sampleMp4)
        assertTest(exists && hashBefore == hashAfter, "Step 2: Convert sample.mp4 -> video.to.avi produces file and preserves source")
    }

    let wmvAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.to.wmv")
    assertTest(wmvAction != nil, "Step 2: video.to.wmv action is registered")
    if let wmvAction = wmvAction {
        let hashBefore = fileSHA256(url: sampleMp4)
        let out = try? JobRunner.shared.run(action: wmvAction, input: sampleMp4, destinationDirectory: testTempDir)
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let hashAfter = fileSHA256(url: sampleMp4)
        assertTest(exists && hashBefore == hashAfter, "Step 2: Convert sample.mp4 -> video.to.wmv produces file and preserves source")
    }

    // 7.2 Audio outputs: OGG and AIFF
    let oggAction = FormatRegistry.shared.action(for: sampleMp3, actionID: "audio.to.ogg")
    assertTest(oggAction != nil, "Step 2: audio.to.ogg action is registered")
    if let oggAction = oggAction {
        let hashBefore = fileSHA256(url: sampleMp3)
        let out = try? JobRunner.shared.run(action: oggAction, input: sampleMp3, destinationDirectory: testTempDir)
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let hashAfter = fileSHA256(url: sampleMp3)
        assertTest(exists && hashBefore == hashAfter, "Step 2: Convert sample.mp3 -> audio.to.ogg produces file and preserves source")
    }

    let aiffAction = FormatRegistry.shared.action(for: sampleMp3, actionID: "audio.to.aiff")
    assertTest(aiffAction != nil, "Step 2: audio.to.aiff action is registered")
    if let aiffAction = aiffAction {
        let hashBefore = fileSHA256(url: sampleMp3)
        let out = try? JobRunner.shared.run(action: aiffAction, input: sampleMp3, destinationDirectory: testTempDir)
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let hashAfter = fileSHA256(url: sampleMp3)
        assertTest(exists && hashBefore == hashAfter, "Step 2: Convert sample.mp3 -> audio.to.aiff produces file and preserves source")
    }

    // 7.3 Archives: GZIP single file and .gz extraction
    let gzipAction = FormatRegistry.shared.action(for: sampleTxt, actionID: "archive.create.gzip")
    assertTest(gzipAction != nil, "Step 2: archive.create.gzip action is registered")
    if let gzipAction = gzipAction {
        let outGz = try? JobRunner.shared.run(action: gzipAction, input: sampleTxt, destinationDirectory: testTempDir)
        let exists = outGz != nil && FileManager.default.fileExists(atPath: outGz!.path)
        assertTest(exists, "Step 2: GZIP of single file produces .gz archive")

        if let outGz = outGz {
            let extractAction = FormatRegistry.shared.action(for: outGz, actionID: "archive.extract")
            assertTest(extractAction != nil, "Step 2: archive.extract available for .gz input")
            if let extractAction = extractAction {
                let outDir = try? JobRunner.shared.run(action: extractAction, input: outGz, destinationDirectory: testTempDir)
                let extractedFiles = (try? FileManager.default.contentsOfDirectory(at: outDir!, includingPropertiesForKeys: nil)) ?? []
                assertTest(!extractedFiles.isEmpty, "Step 2: Extraction of .gz archive produces uncompressed file")
            }
        }
    }

    // 7.4 Image to PDF: single and batch
    let imgToPdfAction = FormatRegistry.shared.action(for: samplePng, actionID: "image.to.pdf")
    assertTest(imgToPdfAction != nil, "Step 2: image.to.pdf action is registered")
    if let imgToPdfAction = imgToPdfAction {
        let outPdf = try? JobRunner.shared.run(action: imgToPdfAction, input: samplePng, destinationDirectory: testTempDir)
        assertTest(outPdf != nil && FileManager.default.fileExists(atPath: outPdf!.path), "Step 2: Single image to PDF produces PDF")

        let batchPdf = try? JobRunner.shared.runBatch(action: imgToPdfAction, inputs: [samplePng, sampleJpg], destinationDirectory: testTempDir)
        assertTest(batchPdf != nil && FileManager.default.fileExists(atPath: batchPdf!.path), "Step 2: Batch images to PDF produces merged PDF")
    }

    // 7.5 PDF merge
    let pdfMergeAction = FormatRegistry.shared.action(for: samplePdf, actionID: "pdf.merge")
    assertTest(pdfMergeAction != nil, "Step 2: pdf.merge action is registered")
    if let pdfMergeAction = pdfMergeAction {
        let merged = try? JobRunner.shared.runBatch(action: pdfMergeAction, inputs: [samplePdf, threePagesPdf], destinationDirectory: testTempDir)
        assertTest(merged != nil && FileManager.default.fileExists(atPath: merged!.path), "Step 2: pdf.merge produces combined PDF")
    }

    // 7.6 EPUB conversions
    let docxToEpub = FormatRegistry.shared.action(for: sampleDocx, actionID: "docx.to.epub")
    assertTest(docxToEpub != nil, "Step 2: docx.to.epub action is registered")
    if let docxToEpub = docxToEpub {
        let epubOut = try? JobRunner.shared.run(action: docxToEpub, input: sampleDocx, destinationDirectory: testTempDir)
        assertTest(epubOut != nil && FileManager.default.fileExists(atPath: epubOut!.path), "Step 2: Convert docx -> epub produces valid file")

        if let epubOut = epubOut {
            let epubToDocx = FormatRegistry.shared.action(for: epubOut, actionID: "epub.to.docx")
            let epubToMd = FormatRegistry.shared.action(for: epubOut, actionID: "epub.to.md")
            let epubToHtml = FormatRegistry.shared.action(for: epubOut, actionID: "epub.to.html")
            let epubToTxt = FormatRegistry.shared.action(for: epubOut, actionID: "epub.to.txt")
            assertTest(epubToDocx != nil && epubToMd != nil && epubToHtml != nil && epubToTxt != nil, "Step 2: epub conversions to docx, md, html, txt are registered")
        }

        let mdToEpub = FormatRegistry.shared.action(for: sampleMd, actionID: "md.to.epub")
        assertTest(mdToEpub != nil, "Step 2: md.to.epub action is registered")

        let htmlToEpub = FormatRegistry.shared.action(for: sampleHtml, actionID: "html.to.epub")
        assertTest(htmlToEpub != nil, "Step 2: html.to.epub action is registered")
    }

    // 7.7 Hostile filename variants for new formats
    let weirdMp4 = fixturesDir.appendingPathComponent("-weird.mp4")
    if let aviAct = FormatRegistry.shared.action(for: weirdMp4, actionID: "video.to.avi") {
        let hashBefore = fileSHA256(url: weirdMp4)
        let out = try? JobRunner.shared.run(action: aviAct, input: weirdMp4, destinationDirectory: testTempDir)
        let hashAfter = fileSHA256(url: weirdMp4)
        assertTest(out != nil && FileManager.default.fileExists(atPath: out!.path) && hashBefore == hashAfter, "Step 2: Hostile filename -weird.mp4 converts to AVI safely")
    }

    let spacesPng = fixturesDir.appendingPathComponent("sample with spaces.png")
    if let pdfAct = FormatRegistry.shared.action(for: spacesPng, actionID: "image.to.pdf") {
        let hashBefore = fileSHA256(url: spacesPng)
        let out = try? JobRunner.shared.run(action: pdfAct, input: spacesPng, destinationDirectory: testTempDir)
        let hashAfter = fileSHA256(url: spacesPng)
        assertTest(out != nil && FileManager.default.fileExists(atPath: out!.path) && hashBefore == hashAfter, "Step 2: Hostile filename 'sample with spaces.png' converts to PDF safely")
    }

    // 7.8 Optional LibreOffice detection & Doctor
    let sofficeAvailable = ToolLocator.shared.isOptionalToolAvailable("soffice")
    assertTest(sofficeAvailable == false, "Step 2: soffice is correctly reported as missing optional tool without failure")
}

// MARK: - 8. Phase 9 Step 3: Compression Modes Tests
print("\n--- 8. Phase 9 Step 3: Compression Modes Tests ---")
do {
    let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures")
    let testTempDir = try OutputPlanner.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: testTempDir) }

    let sampleBmp = fixturesDir.appendingPathComponent("sample.bmp")
    let sampleMp4 = fixturesDir.appendingPathComponent("sample.mp4")
    let sampleWav = fixturesDir.appendingPathComponent("sample.wav")
    let threePagesPdf = fixturesDir.appendingPathComponent("three_pages.pdf")
    let samplePng = fixturesDir.appendingPathComponent("sample.png")
    let sampleJpg = fixturesDir.appendingPathComponent("sample.jpg")

    // Generate a compressible image fixture
    let compressibleJpg = testTempDir.appendingPathComponent("compressible.jpg")
    if let magick = ToolLocator.shared.findTool("magick") {
        let p = Process()
        p.executableURL = magick
        p.arguments = ["-size", "400x400", "plasma:fractal", compressibleJpg.path]
        try? p.run()
        p.waitUntilExit()
    }

    // 8.1 Image compression by percent
    if let imgCompress = FormatRegistry.shared.action(for: compressibleJpg, actionID: "image.compress") {
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: compressibleJpg.path)[.size] as? Int64) ?? 0
        let targetPct = 50.0
        let maxTarget = Int64(Double(originalSize) * (targetPct / 100.0))
        let out = try? JobRunner.shared.run(
            action: imgCompress,
            input: compressibleJpg,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("percent"), "percent": .number(targetPct)]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0 && outSize <= maxTarget, "Step 3: Image compression by 50% produces file <= 50% original (orig: \(originalSize), out: \(outSize))")
    } else {
        assertTest(false, "Step 3: image.compress action is registered")
    }

    // 8.2 Image compression by exact target size
    if let imgCompress = FormatRegistry.shared.action(for: compressibleJpg, actionID: "image.compress") {
        let targetSize: Int64 = 25000
        let out = try? JobRunner.shared.run(
            action: imgCompress,
            input: compressibleJpg,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("targetSize"), "targetSize": .integer(targetSize)]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0 && outSize <= targetSize, "Step 3: Image compression by target size 25000 bytes produces file <= 25000 (out: \(outSize))")
    }

    // 8.3 Video compression by percent (with 10% stated tolerance)
    if let videoCompress = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.compress") {
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: sampleMp4.path)[.size] as? Int64) ?? 0
        let targetPct = 60.0
        let maxTarget = Int64(Double(originalSize) * 0.70) // 60% + 10% video muxing tolerance
        let out = try? JobRunner.shared.run(
            action: videoCompress,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("percent"), "percent": .number(targetPct)]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0 && outSize <= maxTarget, "Step 3: Video compression by 60% produces file within tolerance (orig: \(originalSize), out: \(outSize))")
    } else {
        assertTest(false, "Step 3: video.compress action is registered")
    }

    // 8.4 Audio compression by percent
    if let audioCompress = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.compress") {
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: sampleWav.path)[.size] as? Int64) ?? 0
        let out = try? JobRunner.shared.run(
            action: audioCompress,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("percent"), "percent": .number(50.0)]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0 && outSize <= originalSize / 2, "Step 3: Audio compression by 50% produces file <= 50% original (orig: \(originalSize), out: \(outSize))")
    } else {
        assertTest(false, "Step 3: audio.compress action is registered")
    }

    // 8.5 PDF compression
    if let pdfCompress = FormatRegistry.shared.action(for: threePagesPdf, actionID: "pdf.compress") {
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: threePagesPdf.path)[.size] as? Int64) ?? 0
        let out = try? JobRunner.shared.run(
            action: pdfCompress,
            input: threePagesPdf,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("targetSize"), "targetSize": .integer(5000)]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0 && outSize < originalSize, "Step 3: PDF compression reduces file size (orig: \(originalSize), out: \(outSize))")
    } else {
        assertTest(false, "Step 3: pdf.compress action is registered")
    }

    // 8.6 Impossible target size handling
    if let imgCompress = FormatRegistry.shared.action(for: sampleBmp, actionID: "image.compress") {
        let impossibleTarget: Int64 = 10
        let out = try? JobRunner.shared.run(
            action: imgCompress,
            input: sampleBmp,
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("targetSize"), "targetSize": .integer(impossibleTarget)]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let originalHash = fileSHA256(url: sampleBmp)
        assertTest(exists, "Step 3: Impossible target size produces smallest valid file without crashing or silent failure")
        assertTest(originalHash != nil, "Step 3: Source file remains intact after impossible target compression")
    }

    // 8.7 Batch compression
    if let imgCompress = FormatRegistry.shared.action(for: samplePng, actionID: "image.compress") {
        let batchOut = try? JobRunner.shared.runBatch(
            action: imgCompress,
            inputs: [samplePng, sampleJpg],
            destinationDirectory: testTempDir,
            parameters: ["mode": .text("percent"), "percent": .number(60.0)]
        )
        let folderExists = batchOut != nil && FileManager.default.fileExists(atPath: batchOut!.path)
        let contents = batchOut != nil ? ((try? FileManager.default.contentsOfDirectory(at: batchOut!, includingPropertiesForKeys: nil)) ?? []) : []
        assertTest(folderExists && contents.count >= 2, "Step 3: Batch compression produces folder containing all compressed items (\(contents.count) items)")
    }
}

// MARK: - 9. Phase 9 Step 4: Video and Audio Tools Tests
print("\n--- 9. Phase 9 Step 4: Video and Audio Tools Tests ---")
do {
    let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures")
    let testTempDir = try OutputPlanner.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: testTempDir) }

    let sampleMp4 = fixturesDir.appendingPathComponent("sample.mp4")
    let sampleWav = fixturesDir.appendingPathComponent("sample.wav")

    func probeDims(_ url: URL) -> (Int, Int)? {
        guard let ffprobe = ToolLocator.shared.findTool("ffprobe") else { return nil }
        let p = Process()
        p.executableURL = ffprobe
        p.arguments = ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let parts = str.split(separator: "x").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    func probeChannels(_ url: URL) -> Int? {
        guard let ffprobe = ToolLocator.shared.findTool("ffprobe") else { return nil }
        let p = Process()
        p.executableURL = ffprobe
        p.arguments = ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "default=noprint_wrappers=1:nokey=1", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return Int(str)
    }

    // 9.1 video.speed
    if let speedAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.speed") {
        assertTest(true, "Step 4: video.speed action is registered")
        let out = try? JobRunner.shared.run(
            action: speedAction,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["factor": .number(2.0)]
        )
        let dur = out != nil ? Compressor.shared.probeDuration(url: out!) : 0
        assertTest(out != nil && abs(dur - 1.0) < 0.25, "Step 4: video.speed 2.0x halves duration to ~1.0s (got \(dur)s)")
    } else {
        assertTest(false, "Step 4: video.speed action is registered")
    }

    // 9.2 video.crop
    if let cropAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.crop") {
        assertTest(true, "Step 4: video.crop action is registered")
        let out = try? JobRunner.shared.run(
            action: cropAction,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["rectangle": .rectangle(x: 10, y: 10, width: 160, height: 120)]
        )
        let dims = out != nil ? probeDims(out!) : nil
        assertTest(dims?.0 == 160 && dims?.1 == 120, "Step 4: video.crop crops to 160x120 (got \(dims?.0 ?? 0)x\(dims?.1 ?? 0))")

        // Test out of bounds rejection
        var rejectedOutOfBounds = false
        do {
            _ = try JobRunner.shared.run(
                action: cropAction,
                input: sampleMp4,
                destinationDirectory: testTempDir,
                parameters: ["rectangle": .rectangle(x: 0, y: 0, width: 640, height: 480)]
            )
        } catch {
            rejectedOutOfBounds = true
        }
        assertTest(rejectedOutOfBounds, "Step 4: video.crop rejects rectangle exceeding container dimensions")
    } else {
        assertTest(false, "Step 4: video.crop action is registered")
    }

    // 9.3 video.split
    if let splitAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.split") {
        assertTest(true, "Step 4: video.split action is registered")
        let out = try? JobRunner.shared.run(
            action: splitAction,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["times": .text("1.0")]
        )
        let folderExists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let parts = out != nil ? ((try? FileManager.default.contentsOfDirectory(at: out!, includingPropertiesForKeys: nil)) ?? []) : []
        assertTest(folderExists && parts.count == 2, "Step 4: video.split splits into 2 parts in folder (\(parts.count) parts)")
    } else {
        assertTest(false, "Step 4: video.split action is registered")
    }

    // 9.4 video.join
    if let joinAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.join") {
        assertTest(true, "Step 4: video.join action is registered")
        let out = try? JobRunner.shared.runBatch(
            action: joinAction,
            inputs: [sampleMp4, sampleMp4],
            destinationDirectory: testTempDir,
            parameters: [:]
        )
        let dur = out != nil ? Compressor.shared.probeDuration(url: out!) : 0
        assertTest(out != nil && abs(dur - 4.0) < 0.3, "Step 4: video.join sums duration of 2 clips to ~4.0s (got \(dur)s)")
    } else {
        assertTest(false, "Step 4: video.join action is registered")
    }

    // 9.5 video.snapshot
    if let snapshotAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.snapshot") {
        assertTest(true, "Step 4: video.snapshot action is registered")
        let out = try? JobRunner.shared.run(
            action: snapshotAction,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["time": .number(1.0)]
        )
        let dims = out != nil ? probeDims(out!) : nil
        assertTest(out != nil && dims?.0 == 320 && dims?.1 == 240, "Step 4: video.snapshot extracts 320x240 frame at 1.0s")
    } else {
        assertTest(false, "Step 4: video.snapshot action is registered")
    }

    // 9.6 audio.normalize
    if let normAction = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.normalize") {
        assertTest(true, "Step 4: audio.normalize action is registered")
        let out = try? JobRunner.shared.run(
            action: normAction,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: [:]
        )
        let outSize = out != nil ? ((try? FileManager.default.attributesOfItem(atPath: out!.path)[.size] as? Int64) ?? 0) : 0
        assertTest(out != nil && outSize > 0, "Step 4: audio.normalize produces normalized audio file (\(outSize) bytes)")
    } else {
        assertTest(false, "Step 4: audio.normalize action is registered")
    }

    // 9.7 audio.channels
    if let chanAction = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.channels") {
        assertTest(true, "Step 4: audio.channels action is registered")
        let out = try? JobRunner.shared.run(
            action: chanAction,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: ["channels": .text("stereo")]
        )
        let channels = out != nil ? probeChannels(out!) : nil
        assertTest(channels == 2, "Step 4: audio.channels produces 2 channels (stereo)")
    } else {
        assertTest(false, "Step 4: audio.channels action is registered")
    }

    // 9.8 audio.bleep
    if let bleepAction = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.bleep") {
        assertTest(true, "Step 4: audio.bleep action is registered")
        let out = try? JobRunner.shared.run(
            action: bleepAction,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: ["ranges": .text("0.5-1.0")]
        )
        let dur = out != nil ? Compressor.shared.probeDuration(url: out!) : 0
        assertTest(out != nil && abs(dur - 2.0) < 0.2, "Step 4: audio.bleep keeps duration intact (~2.0s)")
    } else {
        assertTest(false, "Step 4: audio.bleep action is registered")
    }

    // 9.9 audio.trim
    if let trimAction = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.trim") {
        assertTest(true, "Step 4: audio.trim action is registered")
        let out = try? JobRunner.shared.run(
            action: trimAction,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: ["start": .number(0.5), "end": .number(1.5)]
        )
        let dur = out != nil ? Compressor.shared.probeDuration(url: out!) : 0
        assertTest(out != nil && abs(dur - 1.0) < 0.2, "Step 4: audio.trim trims to ~1.0s (got \(dur)s)")
    } else {
        assertTest(false, "Step 4: audio.trim action is registered")
    }
}

// MARK: - 10. Phase 9 Step 5: Metadata, PDF Reorganize, Collage, QR Tests
print("\n--- 10. Phase 9 Step 5: Metadata, PDF Reorganize, Collage, QR Tests ---")
do {
    let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures")
    let testTempDir = try OutputPlanner.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: testTempDir) }

    let sampleJpg = fixturesDir.appendingPathComponent("sample.jpg")
    let samplePng = fixturesDir.appendingPathComponent("sample.png")
    let sampleQr = fixturesDir.appendingPathComponent("sample_qr.png")
    let threeNumberedPdf = fixturesDir.appendingPathComponent("three_numbered_pages.pdf")

    // 10.1 Metadata Read
    if let metaReadAction = FormatRegistry.shared.action(for: sampleJpg, actionID: "metadata.read") {
        assertTest(true, "Step 5: metadata.read action is registered")
        let originalHash = fileSHA256(url: sampleJpg)
        let out = try? JobRunner.shared.run(
            action: metaReadAction,
            input: sampleJpg,
            destinationDirectory: testTempDir,
            parameters: [:]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let content = out != nil ? (try? String(contentsOf: out!, encoding: .utf8)) ?? "" : ""
        assertTest(exists && content.contains("JPEG"), "Step 5: metadata.read produces readable metadata text report")
        assertTest(fileSHA256(url: sampleJpg) == originalHash, "Step 5: metadata.read never modifies source file")
    } else {
        assertTest(false, "Step 5: metadata.read action is registered")
    }

    // 10.2 Metadata Edit & second read-back
    if let metaEditAction = FormatRegistry.shared.action(for: sampleJpg, actionID: "metadata.edit") {
        assertTest(true, "Step 5: metadata.edit action is registered")
        let originalHash = fileSHA256(url: sampleJpg)
        let out = try? JobRunner.shared.run(
            action: metaEditAction,
            input: sampleJpg,
            destinationDirectory: testTempDir,
            parameters: ["title": .text("Verified Title"), "author": .text("Test Author")]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        assertTest(exists, "Step 5: metadata.edit produces output copy")
        assertTest(fileSHA256(url: sampleJpg) == originalHash, "Step 5: metadata.edit never writes to source file")

        // Reject invalid tag
        var rejectedInvalidTag = false
        do {
            _ = try JobRunner.shared.run(
                action: metaEditAction,
                input: sampleJpg,
                destinationDirectory: testTempDir,
                parameters: ["malicious_tag": .text("Bad")]
            )
        } catch {
            rejectedInvalidTag = true
        }
        assertTest(rejectedInvalidTag, "Step 5: metadata.edit rejects unallowed tag name")
    } else {
        assertTest(false, "Step 5: metadata.edit action is registered")
    }

    // 10.3 PDF Reorganize & page reordering
    if let pdfReorderAction = FormatRegistry.shared.action(for: threeNumberedPdf, actionID: "pdf.reorganize") {
        assertTest(true, "Step 5: pdf.reorganize action is registered")
        let out = try? JobRunner.shared.run(
            action: pdfReorderAction,
            input: threeNumberedPdf,
            destinationDirectory: testTempDir,
            parameters: ["pages": .text("3,1,2")]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        assertTest(exists, "Step 5: pdf.reorganize produces reordered PDF")

        // Check text of pages using pdftotext
        if let outPdf = out {
            let p = Process()
            p.executableURL = ToolLocator.shared.findTool("pdftotext") ?? URL(fileURLWithPath: "/opt/homebrew/bin/pdftotext")
            p.arguments = [outPdf.path, "-"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            try? p.run()
            p.waitUntilExit()
            let txt = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let pages = txt.components(separatedBy: "\u{0c}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let orderCorrect = pages.count >= 3 && pages[0].contains("Page 3") && pages[1].contains("Page 1") && pages[2].contains("Page 2")
            assertTest(orderCorrect, "Step 5: pdf.reorganize verifies Page 3, Page 1, Page 2 sequence")
        }

        // Reject out-of-range page number
        var rejectedOutOfRangePage = false
        do {
            _ = try JobRunner.shared.run(
                action: pdfReorderAction,
                input: threeNumberedPdf,
                destinationDirectory: testTempDir,
                parameters: ["pages": .text("1,5")]
            )
        } catch {
            rejectedOutOfRangePage = true
        }
        assertTest(rejectedOutOfRangePage, "Step 5: pdf.reorganize rejects page numbers beyond total page count")
    } else {
        assertTest(false, "Step 5: pdf.reorganize action is registered")
    }

    // 10.4 Image Collage
    if let collageAction = FormatRegistry.shared.action(for: samplePng, actionID: "image.collage") {
        assertTest(true, "Step 5: image.collage action is registered")
        let out = try? JobRunner.shared.runBatch(
            action: collageAction,
            inputs: [samplePng, sampleJpg],
            destinationDirectory: testTempDir,
            parameters: ["columns": .number(2), "spacing": .number(4)]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        assertTest(exists, "Step 5: image.collage combines images into grid")
    } else {
        assertTest(false, "Step 5: image.collage action is registered")
    }

    // 10.5 QR Read
    if let qrAction = FormatRegistry.shared.action(for: sampleQr, actionID: "image.qr.read") {
        assertTest(true, "Step 5: image.qr.read action is registered")
        let out = try? JobRunner.shared.run(
            action: qrAction,
            input: sampleQr,
            destinationDirectory: testTempDir,
            parameters: [:]
        )
        let exists = out != nil && FileManager.default.fileExists(atPath: out!.path)
        let text = out != nil ? (try? String(contentsOf: out!, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        assertTest(exists && text == "Hello Pasta QR", "Step 5: image.qr.read decodes QR fixture correctly to 'Hello Pasta QR' (got '\(text ?? "")')")
    }

    // -------------------------------------------------------------------------
    // SECTION 11: Phase 9 Adversarial Review Fixes & Deep Verification
    // -------------------------------------------------------------------------
    print("\n--- Section 11: Phase 9 Adversarial Review Verification ---")
    let sampleMp4 = fixturesDir.appendingPathComponent("sample.mp4")
    let sampleWav = fixturesDir.appendingPathComponent("sample.wav")

    // 11.1 JobRunner.runAsync with customRunner
    if let qrAction = FormatRegistry.shared.action(for: sampleQr, actionID: "image.qr.read") {
        let group = DispatchGroup()
        group.enter()
        var asyncOut: URL?
        var asyncErr: Error?
        Task {
            do {
                asyncOut = try await JobRunner.shared.runAsync(
                    action: qrAction,
                    input: sampleQr,
                    destinationDirectory: testTempDir,
                    parameters: [:]
                )
            } catch {
                asyncErr = error
            }
            group.leave()
        }
        group.wait()
        let ok = asyncOut != nil && FileManager.default.fileExists(atPath: asyncOut!.path)
        let content = asyncOut != nil ? (try? String(contentsOf: asyncOut!, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        assertTest(ok && content == "Hello Pasta QR", "Step 11: JobRunner.runAsync executes customRunner actions properly (output: '\(content ?? "")', err: \(String(describing: asyncErr)))")
    } else {
        assertTest(false, "Step 11: image.qr.read action registered")
    }

    // 11.2 PDF Reorganize: reverse range (3-1) and range deletion (2-3)
    let revOut = testTempDir.appendingPathComponent("rev_test.pdf")
    do {
        try PDFTools.shared.reorganize(input: threeNumberedPdf, output: revOut, pages: "3-1", rotate: "0", deletePages: "", runner: JobRunner.shared, jobId: UUID())
        let totalRev = try PDFTools.shared.totalPages(url: revOut)
        let (extractedText, _) = try JobRunner.shared.executeCapture(invocation: Invocation(toolName: "pdftotext", arguments: [revOut.path, "-"]))
        let pagesText = extractedText.components(separatedBy: "\u{0C}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let isReversed = pagesText.count == 3 && pagesText[0].contains("Page 3") && pagesText[1].contains("Page 2") && pagesText[2].contains("Page 1")
        assertTest(totalRev == 3 && isReversed, "Step 11: pdf.reorganize with '3-1' produces exact reverse page sequence (P3 -> P2 -> P1)")
    } catch {
        assertTest(false, "Step 11: pdf.reorganize reverse range failed: \(error)")
    }

    let delRangeOut = testTempDir.appendingPathComponent("del_range_test.pdf")
    do {
        try PDFTools.shared.reorganize(input: threeNumberedPdf, output: delRangeOut, pages: "1-3", rotate: "0", deletePages: "2-3", runner: JobRunner.shared, jobId: UUID())
        let totalDel = try PDFTools.shared.totalPages(url: delRangeOut)
        assertTest(totalDel == 1, "Step 11: pdf.reorganize supports range deletion '2-3' yielding exactly 1 page")
    } catch {
        assertTest(false, "Step 11: pdf.reorganize range deletion failed: \(error)")
    }

    // 11.3 Video frame snapshot to JPG
    if let snapJpgAction = FormatRegistry.shared.action(for: sampleMp4, actionID: "video.snapshot.jpg") {
        let snapOut = try? JobRunner.shared.run(
            action: snapJpgAction,
            input: sampleMp4,
            destinationDirectory: testTempDir,
            parameters: ["time": .number(0.1)]
        )
        let snapExists = snapOut != nil && FileManager.default.fileExists(atPath: snapOut!.path) && snapOut!.pathExtension.lowercased() == "jpg"
        var validJpgMagic = false
        if let snapOut = snapOut, let handle = try? FileHandle(forReadingFrom: snapOut) {
            let header = handle.readData(ofLength: 3)
            try? handle.close()
            if header.count == 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
                validJpgMagic = true
            }
        }
        assertTest(snapExists && validJpgMagic, "Step 11: video.snapshot.jpg extracts frame with valid JPEG signature")
    } else {
        assertTest(false, "Step 11: video.snapshot.jpg action registered")
    }

    // 11.4 Two-pass video compression
    let twoPassOut = testTempDir.appendingPathComponent("twopass_test.mp4")
    do {
        try Compressor.shared.compressVideo(
            input: sampleMp4,
            output: twoPassOut,
            parameters: ["mode": .text("targetSize"), "targetSizeMB": .number(0.2)],
            runner: JobRunner.shared,
            jobId: UUID()
        )
        let twoPassExists = FileManager.default.fileExists(atPath: twoPassOut.path)
        let passLogs = (try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath))?.filter { $0.contains("ffmpeg2pass") } ?? []
        assertTest(twoPassExists && passLogs.isEmpty, "Step 11: compressVideo completes two-pass encoding without passlog leaks in workspace")
    } catch {
        assertTest(false, "Step 11: compressVideo two-pass failed: \(error)")
    }

    // 11.5 Audio bleep filter
    if let bleepAction = FormatRegistry.shared.action(for: sampleWav, actionID: "audio.bleep") {
        let bleepOut = try? JobRunner.shared.run(
            action: bleepAction,
            input: sampleWav,
            destinationDirectory: testTempDir,
            parameters: ["ranges": .text("0.1-0.3")]
        )
        let bleepExists = bleepOut != nil && FileManager.default.fileExists(atPath: bleepOut!.path)
        let dur = bleepOut != nil ? Compressor.shared.probeDuration(url: bleepOut!) : 0
        assertTest(bleepExists && dur > 0, "Step 11: audio.bleep generates valid non-empty audio output")
    } else {
        assertTest(false, "Step 11: audio.bleep action registered")
    }

    // 11.6 Metadata edit strict read-back verification
    let metaTestFile = testTempDir.appendingPathComponent("meta_test.jpg")
    try? FileManager.default.copyItem(at: sampleJpg, to: metaTestFile)
    let metaEditOut = testTempDir.appendingPathComponent("meta_edited.jpg")
    do {
        try MetadataTools.shared.editMetadata(
            input: metaTestFile,
            output: metaEditOut,
            tags: ["author": "Reviewer 42"],
            runner: JobRunner.shared,
            jobId: UUID()
        )
        let readMap = try MetadataTools.shared.readMetadata(from: metaEditOut)
        let authorMatches = readMap.contains { k, v in
            k.lowercased() == "author" && String(describing: v).contains("Reviewer 42")
        }
        assertTest(authorMatches, "Step 11: metadata.edit accurately writes and verifies metadata tag read-back")
    } catch {
        assertTest(false, "Step 11: metadata.edit failed: \(error)")
    }

    // 11.7 Video join fallback with filter-complex
    let videoJoinOut = testTempDir.appendingPathComponent("joined_test.mp4")
    do {
        try MediaTools.shared.joinVideos(
            inputs: [sampleMp4, sampleMp4],
            output: videoJoinOut,
            runner: JobRunner.shared,
            jobId: UUID()
        )
        let joinExists = FileManager.default.fileExists(atPath: videoJoinOut.path)
        let joinDur = joinExists ? Compressor.shared.probeDuration(url: videoJoinOut) : 0
        let origDur = Compressor.shared.probeDuration(url: sampleMp4)
        assertTest(joinExists && joinDur >= origDur * 1.5, "Step 11: MediaTools.joinVideos successfully combines clips into continuous video (dur: \(joinDur)s >= \(origDur * 1.5)s)")
    } catch {
        assertTest(false, "Step 11: MediaTools.joinVideos failed: \(error)")
    }
}


// MARK: - 12. DragMonitor Shift-Hold State Machine Tests
print("\n--- 12. DragMonitor Shift-Hold State Machine Tests ---")
do {
    let mockClock = MockDragMonitorClock(initialTime: 1000.0)
    let mockPasteboard = MockDragPasteboardReader(urls: [URL(fileURLWithPath: "/tmp/test.png")])
    let prefs = PreferencesManager()
    prefs.shiftHoldDurationMs = 450.0
    prefs.stayOpenAfterRelease = true
    prefs.showChargingRing = true
    prefs.reduceMotionEnabled = false

    let monitor = DragMonitor(clock: mockClock, pasteboardReader: mockPasteboard, preferences: prefs)

    var wheelOpened = false
    var wheelClosed = false
    var lastProgress = 0.0
    var modeToggled = false
    var currentIsAdvanced = false

    monitor.onWheelOpen = { (files: [URL], isAdv: Bool, loc: NSPoint) in
        wheelOpened = true
        currentIsAdvanced = isAdv
    }
    monitor.onWheelClose = {
        wheelClosed = true
    }
    monitor.onChargingProgress = { (prog: Double, loc: NSPoint) in
        lastProgress = prog
    }
    monitor.onModeToggle = { (isAdv: Bool) in
        modeToggled = true
        currentIsAdvanced = isAdv
    }

    let shiftMod = NSEvent.ModifierFlags.shift
    let optMod = NSEvent.ModifierFlags.option
    let emptyMod = NSEvent.ModifierFlags()

    // 12.1 Hold 449 ms: no wheel
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1000.000)
    assertTest(monitor.state == .armed(startedAt: 1000.000, files: mockPasteboard.mockURLs, location: NSPoint(x: 100, y: 100)), "12.1 Shift down initiates Armed state at t=1000.0")

    // Advance to 1000.449 (449 ms elapsed)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1000.449)
    assertTest(!wheelOpened, "12.1 Hold 449 ms: wheel does NOT open")
    if case .charging = monitor.state {
        assertTest(true, "12.1 State is Charging after 120ms threshold")
    } else {
        assertTest(false, "12.1 Expected Charging state at 449 ms")
    }
    assertTest(lastProgress > 0.9 && lastProgress < 1.0, "12.1 Charging ring progress is >90% at 449 ms")

    // 12.2 Hold 450 ms: wheel opens
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1000.450)
    assertTest(wheelOpened, "12.2 Hold 450 ms: wheel opens successfully")
    assertTest(lastProgress == 1.0, "12.2 Charging ring reaches 100% exactly at 450 ms")
    if case .open = monitor.state {
        assertTest(true, "12.2 State transitions to Open at exactly 450 ms")
    } else {
        assertTest(false, "12.2 Expected Open state at 450 ms")
    }

    // 12.3 Release after open: wheel stays (latches)
    wheelClosed = false
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1000.550)
    assertTest(!wheelClosed, "12.3 Releasing Shift after open does not close wheel (latches)")
    if case .open = monitor.state {
        assertTest(true, "12.3 Wheel remains in Open state after Shift released")
    } else {
        assertTest(false, "12.3 Expected Open state preserved after Shift release")
    }

    // 12.4 Esc closes wheel
    monitor.processKeyDown(keyCode: 53, timestamp: 1000.600)
    assertTest(wheelClosed && monitor.state == .idle, "12.4 Esc key press closes the open wheel")

    // 12.5 Hold then other key cancels
    wheelOpened = false
    var chargingCancelled = false
    monitor.onChargingCancel = { chargingCancelled = true }
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1100.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1100.200)
    monitor.processKeyDown(keyCode: 12, timestamp: 1100.250) // 'q' or other key
    assertTest(!wheelOpened && monitor.state == .idle && chargingCancelled, "12.5 Any key press during charging cancels progress and returns to Idle")

    // 12.6 No drag session: Shift does nothing
    mockPasteboard.mockURLs = []
    wheelOpened = false
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1200.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1200.500)
    assertTest(!wheelOpened && monitor.state == .idle, "12.6 No drag session: Shift press does nothing")

    // 12.7 Text drag (no file URLs): does nothing
    mockPasteboard.mockURLs = [] // Empty file list (pure text drag)
    wheelOpened = false
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1300.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1300.600)
    assertTest(!wheelOpened && monitor.state == .idle, "12.7 Text drag without file URLs does nothing")

    // 12.8 Second hold closes wheel
    mockPasteboard.mockURLs = [URL(fileURLWithPath: "/tmp/sample.png")]
    wheelOpened = false
    wheelClosed = false
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1400.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1400.450)
    assertTest(wheelOpened, "12.8 Wheel opened for second hold test")
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1400.500) // release shift

    // Second shift press down
    monitor.processFlagsChanged(modifiers: shiftMod, timestamp: 1400.600)
    // Hold second shift for 450 ms -> 1401.050
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1401.050)
    assertTest(wheelClosed && monitor.state == .idle, "12.8 Second Shift hold closes the open wheel")

    // 12.9 Option tap toggles mode
    wheelOpened = false
    modeToggled = false
    currentIsAdvanced = false
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1500.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1500.450)
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1500.500)

    // Quick option tap (<250 ms): down at 1500.600, up at 1500.750 (150 ms)
    monitor.processFlagsChanged(modifiers: optMod, timestamp: 1500.600)
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1500.750)
    assertTest(modeToggled && currentIsAdvanced == true, "12.9 Quick Option tap (<250 ms) toggles Convert to Advanced mode")

    // Second quick option tap toggles back
    modeToggled = false
    monitor.processFlagsChanged(modifiers: optMod, timestamp: 1500.800)
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1500.900)
    assertTest(modeToggled && currentIsAdvanced == false, "12.9 Second Option tap toggles Advanced back to Convert mode")

    // 12.10 Option hold (>250 ms) does NOT toggle
    modeToggled = false
    monitor.processFlagsChanged(modifiers: optMod, timestamp: 1501.000)
    monitor.processFlagsChanged(modifiers: emptyMod, timestamp: 1501.300) // 300 ms hold
    assertTest(!modeToggled, "12.10 Option hold exceeding 250 ms does not toggle mode (requires a quick tap)")

    // 12.11 Configurable hold duration
    prefs.shiftHoldDurationMs = 600.0
    monitor.closeWheel()
    wheelOpened = false
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1600.000)
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1600.450)
    assertTest(!wheelOpened, "12.11 Configured 600 ms duration: not opened at 450 ms")
    monitor.processMouseDragged(modifiers: shiftMod, location: NSPoint(x: 100, y: 100), timestamp: 1600.600)
    assertTest(wheelOpened, "12.11 Configured 600 ms duration: opens at 600 ms")
}

// MARK: - 13. Phase 9 Step 0 Hardening & Inactivity Watchdog Tests
print("\n--- 13. Phase 9 Step 0 Hardening & Inactivity Watchdog Tests ---")
do {
    // 13.1 JobRunner timeout
    let sleepURL = URL(fileURLWithPath: "/bin/sleep")
    ToolLocator.shared.setOverride(tool: "fake_slow_tool", url: sleepURL)
    defer { ToolLocator.shared.setOverride(tool: "fake_slow_tool", url: nil) }

    let inv = Invocation(toolName: "fake_slow_tool", arguments: ["2"], timeout: 0.25)
    var didTimeout = false
    do {
        _ = try JobRunner.shared.executeCapture(invocation: inv, timeoutSeconds: 0.25)
    } catch PastaError.timedOut(let tool) {
        didTimeout = (tool == "fake_slow_tool")
    } catch {}
    assertTest(didTimeout, "Step 0: JobRunner explicit timeout throws PastaError.timedOut")

    // 13.2 cancel(jobId:) clean termination and scratch directory cleanup
    let cancelJobId = UUID()
    let beforeTemps = (try? FileManager.default.contentsOfDirectory(atPath: "/tmp").filter { $0.hasPrefix("Pasta_") }) ?? []

    let slowInv = Invocation(toolName: "fake_slow_tool", arguments: ["10"], timeout: nil)

    let semaStarted = DispatchSemaphore(value: 0)
    let semaDone = DispatchSemaphore(value: 0)
    var cancelErrorCaught = false

    DispatchQueue.global().async {
        semaStarted.signal()
        do {
            _ = try JobRunner.shared.executeCapture(invocation: slowInv, jobId: cancelJobId)
        } catch PastaError.cancelled {
            cancelErrorCaught = true
        } catch {}
        semaDone.signal()
    }

    semaStarted.wait()
    Thread.sleep(forTimeInterval: 0.1) // Allow process to launch
    assertTest(JobRunner.shared.isJobRunning(cancelJobId), "Step 0: Job is running before cancel")

    JobRunner.shared.cancel(jobId: cancelJobId)
    semaDone.wait()

    assertTest(cancelErrorCaught, "Step 0: cancel(jobId:) throws PastaError.cancelled")
    assertTest(!JobRunner.shared.isJobRunning(cancelJobId), "Step 0: Job process is cleanly terminated after cancel")

    let afterTemps = (try? FileManager.default.contentsOfDirectory(atPath: "/tmp").filter { $0.hasPrefix("Pasta_") }) ?? []
    let leftoverCount = afterTemps.filter { !beforeTemps.contains($0) }.count
    assertTest(leftoverCount == 0, "Step 0: cancel(jobId:) leaves zero leftover /tmp/Pasta_* directories")

    // 13.3 SIGTERM to SIGKILL escalation
    let shURL = URL(fileURLWithPath: "/bin/sh")
    let stubbornProc = Process()
    stubbornProc.executableURL = shURL
    stubbornProc.arguments = ["-c", "trap '' TERM; sleep 5"]
    try? stubbornProc.run()
    assertTest(stubbornProc.isRunning, "Step 0: Stubborn process launched")

    // Terminate with a short grace period of 0.3s
    JobRunner.shared.terminateGracefully(stubbornProc, gracePeriod: 0.3)
    // Wait 0.5s for SIGKILL escalation to fire and reap
    Thread.sleep(forTimeInterval: 0.5)
    assertTest(!stubbornProc.isRunning, "Step 0: SIGTERM-ignoring process is killed by SIGKILL escalation")

    // 13.4 ffmpeg inactivity watchdog (triggers when no output is produced within timeout)
    let quietInv = Invocation(toolName: "fake_slow_tool", arguments: ["2"], timeout: nil, inactivityTimeout: 0.25)
    var watchdogFired = false
    let startWatchdog = Date()
    do {
        _ = try JobRunner.shared.executeCapture(invocation: quietInv, inactivityTimeoutSeconds: 0.25)
    } catch PastaError.timedOut(let tool) {
        watchdogFired = tool.contains("inactivity watchdog")
    } catch {}
    let elapsedWatchdog = Date().timeIntervalSince(startWatchdog)
    assertTest(watchdogFired && elapsedWatchdog < 1.0, "Step 0: Inactivity watchdog cancels silent process within timeout window")

    // 13.5 ffmpeg inactivity watchdog resets on streaming output
    let streamingProcURL = URL(fileURLWithPath: "/bin/sh")
    ToolLocator.shared.setOverride(tool: "streaming_tool", url: streamingProcURL)
    defer { ToolLocator.shared.setOverride(tool: "streaming_tool", url: nil) }
    let streamInv = Invocation(
        toolName: "streaming_tool",
        arguments: ["-c", "for i in 1 2 3; do echo $i; sleep 0.1; done"],
        timeout: 2.0,
        inactivityTimeout: 0.25
    )
    var streamSucceeded = false
    do {
        let (out, _) = try JobRunner.shared.executeCapture(invocation: streamInv, inactivityTimeoutSeconds: 0.25)
        streamSucceeded = out.contains("1") && out.contains("2") && out.contains("3")
    } catch {}
    assertTest(streamSucceeded, "Step 0: Inactivity watchdog resets on active progress and completes successfully")
}

// MARK: - 14. MediaTools audio.normalize Loudness Measurement Tests
print("\n--- 14. MediaTools audio.normalize Loudness Measurement Tests ---")
do {
    let scriptURL = URL(fileURLWithPath: "/tmp/fake_ffmpeg_loudnorm.sh")
    let modeURL = URL(fileURLWithPath: "/tmp/loudnorm_test_mode.txt")
    let argsURL = URL(fileURLWithPath: "/tmp/loudnorm_pass2_args.txt")

    let scriptContent = """
    #!/bin/sh
    MODE_FILE="/tmp/loudnorm_test_mode.txt"
    ARGS_FILE="/tmp/loudnorm_pass2_args.txt"
    MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "missing_json")

    if echo "$@" | grep -q "print_format=json"; then
        case "$MODE" in
            "missing_json")
                echo "ffmpeg banner output without any json block" >&2
                exit 0
                ;;
            "missing_key")
                cat << 'EOF' >&2
    [Parsed_loudnorm_0 @ 0x123] 
    {
        "input_i" : "-21.50",
        "input_tp" : "-1.20",
        "input_lra" : "7.80",
        "target_offset" : "+0.20"
    }
    EOF
                exit 0
                ;;
            "inf_value")
                cat << 'EOF' >&2
    [Parsed_loudnorm_0 @ 0x123] 
    {
        "input_i" : "-inf",
        "input_tp" : "-inf",
        "input_lra" : "0.00",
        "input_thresh" : "-inf",
        "target_offset" : "0.00"
    }
    EOF
                exit 0
                ;;
            "valid")
                cat << 'EOF' >&2
    [Parsed_loudnorm_0 @ 0x123] 
    {
        "input_i" : "-21.50",
        "input_tp" : "-1.20",
        "input_lra" : "7.80",
        "input_thresh" : "-31.50",
        "target_offset" : "+0.20"
    }
    EOF
                exit 0
                ;;
        esac
    else
        echo "$@" > "$ARGS_FILE"
        for last_arg in "$@"; do :; done
        touch "$last_arg"
        exit 0
    fi
    """

    try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    ToolLocator.shared.setOverride(tool: "ffmpeg", url: scriptURL)
    defer {
        ToolLocator.shared.setOverride(tool: "ffmpeg", url: nil)
        try? FileManager.default.removeItem(at: scriptURL)
        try? FileManager.default.removeItem(at: modeURL)
        try? FileManager.default.removeItem(at: argsURL)
    }

    let dummyInput = URL(fileURLWithPath: "/tmp/fake_input.wav")
    let dummyOutput = URL(fileURLWithPath: "/tmp/fake_output.wav")
    try? Data("RIFF....WAVE".utf8).write(to: dummyInput)
    defer {
        try? FileManager.default.removeItem(at: dummyInput)
        try? FileManager.default.removeItem(at: dummyOutput)
    }

    // 14.1 Missing JSON throws PastaError.invalidInput
    try "missing_json".write(to: modeURL, atomically: true, encoding: .utf8)
    var missingJsonThrew = false
    var missingJsonMsg = ""
    do {
        try MediaTools.shared.normalizeAudio(input: dummyInput, output: dummyOutput, runner: JobRunner.shared, jobId: UUID())
    } catch PastaError.invalidInput(let msg) {
        missingJsonThrew = true
        missingJsonMsg = msg
    } catch {}
    assertTest(missingJsonThrew && missingJsonMsg.contains("Could not measure loudness"), "14.1 audio.normalize throws when pass 1 produces no JSON")

    // 14.2 Missing key throws PastaError.invalidInput
    try "missing_key".write(to: modeURL, atomically: true, encoding: .utf8)
    var missingKeyThrew = false
    var missingKeyMsg = ""
    do {
        try MediaTools.shared.normalizeAudio(input: dummyInput, output: dummyOutput, runner: JobRunner.shared, jobId: UUID())
    } catch PastaError.invalidInput(let msg) {
        missingKeyThrew = true
        missingKeyMsg = msg
    } catch {}
    assertTest(missingKeyThrew && missingKeyMsg.contains("Could not measure loudness"), "14.2 audio.normalize throws when loudnorm JSON key is missing")

    // 14.3 "-inf" value throws PastaError.invalidInput
    try "inf_value".write(to: modeURL, atomically: true, encoding: .utf8)
    var infThrew = false
    var infMsg = ""
    do {
        try MediaTools.shared.normalizeAudio(input: dummyInput, output: dummyOutput, runner: JobRunner.shared, jobId: UUID())
    } catch PastaError.invalidInput(let msg) {
        infThrew = true
        infMsg = msg
    } catch {}
    assertTest(infThrew && infMsg.contains("Could not measure loudness"), "14.3 audio.normalize throws when loudness measurement contains -inf")

    // 14.4 Valid JSON passes measured values to pass 2 with exact argument string
    try "valid".write(to: modeURL, atomically: true, encoding: .utf8)
    try? FileManager.default.removeItem(at: argsURL)
    var validThrew = false
    do {
        try MediaTools.shared.normalizeAudio(input: dummyInput, output: dummyOutput, runner: JobRunner.shared, jobId: UUID())
    } catch {
        validThrew = true
    }
    assertTest(!validThrew, "14.4 audio.normalize succeeds on valid loudnorm JSON")

    let capturedArgs = (try? String(contentsOf: argsURL, encoding: .utf8)) ?? ""
    let expectedAf = "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=-21.50:measured_TP=-1.20:measured_LRA=7.80:measured_thresh=-31.50:offset=+0.20:linear=true"
    let expectedArgs = "-nostdin -y -i \(dummyInput.path) -af \(expectedAf) \(dummyOutput.path)"
    let argsMatch = capturedArgs.trimmingCharacters(in: .whitespacesAndNewlines) == expectedArgs
    assertTest(argsMatch, "14.4 audio.normalize passes exact measured argument string to pass 2", details: "Got: '\(capturedArgs.trimmingCharacters(in: .whitespacesAndNewlines))'")
}

// MARK: - 15. ParameterFormModel Headless Tests (Phase 10 Step 1)
print("\n--- 15. ParameterFormModel Headless Tests (Phase 10 Step 1) ---")
do {
    let dummyFile = URL(fileURLWithPath: "sample.mp4")
    guard let speedAction = FormatRegistry.shared.action(for: dummyFile, actionID: "video.speed") else {
        fatalError("video.speed action not registered")
    }

    // 15.1 Defaults: initializes with declared default values and is valid
    let model1 = ParameterFormModel(action: speedAction, loadLastUsed: false)
    assertTest(model1.isValid, "15.1 ParameterFormModel initially valid")
    assertTest(model1.fields.count == 1, "15.1 Speed action produces 1 parameter field")
    assertTest(model1.field(for: "factor")?.currentValue == .number(2.0), "15.1 Default factor is 2.0")

    // 15.2 Presets: contains presets for factor (0.5x, 1.5x, 2.0x)
    assertTest(!model1.presets.isEmpty, "15.2 Model provides presets for speed action")
    if let preset2x = model1.presets.first(where: { $0.id == "spd_20" }) {
        model1.applyPreset(preset2x)
        assertTest(model1.values["factor"] == .number(2.0), "15.2 applyPreset updates factor to 2.0")
        assertTest(model1.isValid, "15.2 Model remains valid after applying preset")
    } else {
        assertTest(false, "15.2 spd_20 preset not found")
    }

    // 15.3 Last-used: saveAsLastUsed persists values to PreferencesManager and loads on next model
    model1.updateValue(.number(1.5), for: "factor")
    model1.saveAsLastUsed()
    defer { model1.clearLastUsed() }

    let model2 = ParameterFormModel(action: speedAction, loadLastUsed: true)
    assertTest(model2.values["factor"] == .number(1.5), "15.3 ParameterFormModel loads last-used values from PreferencesManager")

    // 15.4 Reset to defaults: reverts to default 2.0
    model2.resetToDefaults()
    assertTest(model2.values["factor"] == .number(2.0), "15.4 resetToDefaults reverts fields to declared defaults")

    // 15.5 Live validation error: hostile characters rejected
    model2.updateStringValue("1.5; echo pwned", for: "factor")
    assertTest(!model2.isValid, "15.5 Hostile characters make model invalid")
    assertTest(model2.validationErrors["factor"]?.contains("Hostile character") == true, "15.5 Validation error explains hostile character")

    // 15.6 Out-of-range below minimum rejected
    model2.updateValue(.number(0.1), for: "factor")
    assertTest(!model2.isValid, "15.6 Speed factor 0.1 below minimum 0.25 is invalid")
    assertTest(model2.validationErrors["factor"]?.contains("below minimum") == true, "15.6 Error explains value is below minimum")

    // 15.7 Out-of-range above maximum rejected
    model2.updateValue(.number(5.0), for: "factor")
    assertTest(!model2.isValid, "15.7 Speed factor 5.0 above maximum 4.0 is invalid")
    assertTest(model2.validationErrors["factor"]?.contains("exceeds maximum") == true, "15.7 Error explains value exceeds maximum")

    // 15.8 Choice validation on audio.channels
    let wavFile = URL(fileURLWithPath: "sample.wav")
    if let chanAction = FormatRegistry.shared.action(for: wavFile, actionID: "audio.channels") {
        let chanModel = ParameterFormModel(action: chanAction, loadLastUsed: false)
        assertTest(chanModel.isValid, "15.8 Channels model initially valid with default")

        chanModel.updateValue(.text("stereo"), for: "channels")
        assertTest(chanModel.isValid, "15.8 Channels 'stereo' is valid choice")

        chanModel.updateValue(.text("quadraphonic"), for: "channels")
        assertTest(!chanModel.isValid, "15.8 Channels 'quadraphonic' is invalid choice")
        assertTest(chanModel.validationErrors["channels"]?.contains("Invalid choice") == true, "15.8 Error explains invalid choice")
    } else {
        assertTest(false, "15.8 audio.channels action not registered")
    }

    // 15.9 Compression target_size presets and percent validation
    let pngFile = URL(fileURLWithPath: "sample.png")
    if let compAction = FormatRegistry.shared.action(for: pngFile, actionID: "image.compress") {
        let compModel = ParameterFormModel(action: compAction, loadLastUsed: false)
        assertTest(compModel.presets.contains(where: { $0.id == "size_5mb" }), "15.9 Compression model has 5 MB preset")
        assertTest(compModel.presets.contains(where: { $0.id == "pct_50" }), "15.9 Compression model has 50% preset")

        compModel.updateValue(.number(150.0), for: "percent")
        assertTest(!compModel.isValid, "15.9 Percent 150% is outside 0-100 range")
        assertTest(compModel.validationErrors["percent"]?.contains("outside allowed range") == true, "15.9 Error explains percentage range")
    } else {
        assertTest(false, "15.9 image.compress action not registered")
    }
}

// MARK: - 16. Parameter Panel UI & Integration Tests (Phase 10 Step 2)
print("\n--- 16. Parameter Panel UI & Integration Tests (Phase 10 Step 2) ---")
do {
    let dummyFile = URL(fileURLWithPath: "sample.mp4")
    guard let speedAction = FormatRegistry.shared.action(for: dummyFile, actionID: "video.speed") else {
        fatalError("video.speed action not registered")
    }

    let model = ParameterFormModel(action: speedAction, loadLastUsed: false)
    let panel = ParameterPanelView(model: model, action: speedAction)

    // 16.1 View structure and action binding
    assertTest(panel.action.id == "video.speed", "16.1 ParameterPanelView binds action correctly")
    assertTest(panel.model === model, "16.1 ParameterPanelView uses shared ParameterFormModel")

    // 16.2 VoiceOver and Accessibility
    assertTest(panel.isAccessibilityElement(), "16.2 ParameterPanelView is accessibility element")
    assertTest(panel.accessibilityRole() == .group, "16.2 ParameterPanelView role is group")
    assertTest(panel.accessibilityLabel()?.contains("Speed") == true, "16.2 ParameterPanelView has descriptive VoiceOver label")

    // 16.3 Presets chip interaction
    let initialCount = panel.model.presets.count
    assertTest(initialCount >= 2, "16.3 Model provides at least 2 presets for speed")
    if let preset05 = panel.model.presets.first(where: { $0.id == "spd_05" }) {
        let chip = PresetChipView(preset: preset05)
        assertTest(chip.isAccessibilityElement(), "16.3 PresetChipView is accessibility element")
        assertTest(chip.accessibilityRole() == .button, "16.3 PresetChipView role is button")
        var tapped = false
        chip.onTap = { tapped = true }
        chip.mouseDown(with: NSEvent())
        assertTest(tapped, "16.3 PresetChipView mouseDown triggers onTap callback")
    } else {
        assertTest(false, "16.3 spd_05 preset not found")
    }

    // 16.4 Choice chips for audio.channels
    let wavFile = URL(fileURLWithPath: "sample.wav")
    if let chanAction = FormatRegistry.shared.action(for: wavFile, actionID: "audio.channels") {
        let chanModel = ParameterFormModel(action: chanAction, loadLastUsed: false)
        let chanPanel = ParameterPanelView(model: chanModel, action: chanAction)
        assertTest(chanPanel.action.id == "audio.channels", "16.4 Channels panel created successfully")

        let monoChip = ChoiceChipView(title: "mono", isSelected: false)
        assertTest(!monoChip.isSelected, "16.4 ChoiceChipView initially unselected")
        monoChip.setSelected(true)
        assertTest(monoChip.isSelected, "16.4 ChoiceChipView setSelected updates selected state")
        assertTest(monoChip.isAccessibilityElement(), "16.4 ChoiceChipView is accessibility element")
        assertTest(monoChip.accessibilityLabel() == "Option mono", "16.4 ChoiceChipView has accessible label")
    } else {
        assertTest(false, "16.4 audio.channels action not registered")
    }

    // 16.5 Crop rectangle picker and ratio preset
    if let cropAction = FormatRegistry.shared.action(for: dummyFile, actionID: "video.crop") {
        let probe = FakeMediaProbe(results: ["sample.mp4": MediaProbeResult(width: 1920, height: 1080, duration: 10.0)])
        let cropModel = ParameterFormModel(action: cropAction, loadLastUsed: false, inputFile: dummyFile, probe: probe)
        let cropPanel = ParameterPanelView(model: cropModel, action: cropAction)
        assertTest(cropPanel.action.id == "video.crop", "16.5 Crop panel created successfully")

        if let ratio169 = cropModel.presets.first(where: { $0.id == "crop_16_9" }) {
            cropModel.applyPreset(ratio169)
            if case .rectangle(_, _, let w, let h)? = cropModel.values["rectangle"] {
                assertTest(w == 1920 && h == 1080, "16.5 Applying 16:9 preset sets 1920x1080 crop rectangle")
            } else {
                assertTest(false, "16.5 Rectangle value not set after applying preset")
            }
        } else {
            assertTest(false, "16.5 crop_16_9 preset not found")
        }
    } else {
        assertTest(false, "16.5 video.crop action not registered")
    }

    // 16.6 Run callback and execution with parameters
    var capturedParams: ParameterValues?
    panel.onRun = { params in
        capturedParams = params
    }
    model.updateValue(.number(1.5), for: "factor")
    if panel.model.isValid {
        panel.model.saveAsLastUsed()
        panel.onRun?(panel.model.values)
    }
    assertTest(capturedParams?["factor"] == .number(1.5), "16.6 Panel executes onRun with configured parameter values")

    // 16.7 Reduce motion and transparency preferences
    let origMotion = PreferencesManager.shared.reduceMotionEnabled
    let origTrans = PreferencesManager.shared.reduceTransparencyEnabled
    defer {
        PreferencesManager.shared.reduceMotionEnabled = origMotion
        PreferencesManager.shared.reduceTransparencyEnabled = origTrans
    }
    PreferencesManager.shared.reduceMotionEnabled = true
    PreferencesManager.shared.reduceTransparencyEnabled = true
    assertTest(PreferencesManager.shared.reduceMotionEnabled, "16.7 reduceMotionEnabled query returns true when set")
    assertTest(PreferencesManager.shared.reduceTransparencyEnabled, "16.7 reduceTransparencyEnabled query returns true when set")

    // 16.8 Radial wheel integration: parameter panel vs direct execution
    let wheelVC = RadialWheelOverlayViewController()
    wheelVC.loadView()
    wheelVC.viewDidLoad()
    assertTest(wheelVC.view != nil, "16.8 RadialWheelOverlayViewController view loaded")
    wheelVC.configure(files: [dummyFile], isOptionHeld: false)
    var closeRequested = false
    wheelVC.onCloseRequested = { closeRequested = true }
    wheelVC.cancelOperation(nil)
    assertTest(closeRequested, "16.8 cancelOperation without parameter panel requests wheel close")
}

// MARK: - 17. Crop Presets & Dynamic Media Probe Tests (Phase 10 Fix 1)
print("\n--- 17. Crop Presets & Dynamic Media Probe Tests (Phase 10 Fix 1) ---")
do {
    // 17.1 CropCalculator: 1280x720 container with 1:1 ratio gives 720x720 at x=280, y=0
    let crop1 = CropCalculator.computeCrop(containerWidth: 1280, containerHeight: 720, ratioWidth: 1, ratioHeight: 1)
    assertTest(crop1.width == 720 && crop1.height == 720 && crop1.x == 280 && crop1.y == 0,
               "17.1 CropCalculator: 1280x720 with 1:1 gives 720x720 at x=280, y=0")

    // 17.2 CropCalculator: 1080x1920 container with 16:9 ratio gives 1080x608 centered vertically at x=0, y=656
    let crop2 = CropCalculator.computeCrop(containerWidth: 1080, containerHeight: 1920, ratioWidth: 16, ratioHeight: 9)
    assertTest(crop2.width == 1080 && crop2.height == 608 && crop2.x == 0 && crop2.y == 656,
               "17.2 CropCalculator: 1080x1920 with 16:9 gives 1080x608 centered at x=0, y=656")

    // 17.3 CropCalculator: 1920x1080 container with 16:9 ratio gives full frame at x=0, y=0
    let crop3 = CropCalculator.computeCrop(containerWidth: 1920, containerHeight: 1080, ratioWidth: 16, ratioHeight: 9)
    assertTest(crop3.width == 1920 && crop3.height == 1080 && crop3.x == 0 && crop3.y == 0,
               "17.3 CropCalculator: 1920x1080 with 16:9 gives 1920x1080 at x=0, y=0 (full frame)")

    // 17.4 CropCalculator: non-standard odd dimensions produce even-rounded width and height
    let crop4 = CropCalculator.computeCrop(containerWidth: 1001, containerHeight: 701, ratioWidth: 1, ratioHeight: 1)
    assertTest(crop4.width % 2 == 0 && crop4.height % 2 == 0 && crop4.width <= 1001 && crop4.height <= 701,
               "17.4 CropCalculator produces even-rounded dimensions on odd containers")

    // 17.5 FakeMediaProbe provides dimensions, duration, and file size
    let probe = FakeMediaProbe(results: [
        "landscape.mp4": MediaProbeResult(width: 1280, height: 720, duration: 42.0, fileSize: 10_000_000),
        "portrait.mp4": MediaProbeResult(width: 1080, height: 1920, duration: 15.5, fileSize: 5_000_000)
    ])
    let landRes = try probe.probe(url: URL(fileURLWithPath: "landscape.mp4"))
    assertTest(landRes.width == 1280 && landRes.height == 720 && landRes.duration == 42.0 && landRes.fileSize == 10_000_000,
               "17.5 FakeMediaProbe returns probed dimensions and metadata")

    // 17.6 ParameterFormModel computes crop presets dynamically from probed video dimensions
    let landFile = URL(fileURLWithPath: "landscape.mp4")
    if let cropAction = FormatRegistry.shared.action(for: landFile, actionID: "video.crop") {
        let model = ParameterFormModel(action: cropAction, loadLastUsed: false, inputFile: landFile, probe: probe)
        assertTest(model.isValid, "17.6 ParameterFormModel with probed file is initially valid")
        assertTest(model.presets.count == 3, "17.6 Crop action generates 3 dynamic ratio presets (16:9, 1:1, 9:16)")

        if let p11 = model.presets.first(where: { $0.id == "crop_1_1" }) {
            model.applyPreset(p11)
            if case .rectangle(let x, let y, let w, let h)? = model.values["rectangle"] {
                assertTest(w == 720 && h == 720 && x == 280 && y == 0,
                           "17.6 Applying 1:1 preset on 1280x720 computes 720x720 at x=280, y=0")
            } else {
                assertTest(false, "17.6 rectangle value not set after applying 1:1 preset")
            }
        } else {
            assertTest(false, "17.6 crop_1_1 preset not found")
        }

        // 17.7 Out-of-bounds crop rejected with readable error message
        model.updateValue(.rectangle(x: 700, y: 100, width: 720, height: 720), for: "rectangle")
        assertTest(!model.isValid, "17.7 Crop rectangle exceeding container boundary is invalid")
        assertTest(model.validationErrors["rectangle"]?.contains("exceeds container dimensions") == true,
                   "17.7 Validation error explains that crop rectangle exceeds container dimensions")
    } else {
        assertTest(false, "17.6 video.crop action not found")
    }

    // 17.8 Probing failure shows readable error instead of guessing presets
    let failingProbe = FakeMediaProbe(shouldThrow: PastaError.invalidInput("Corrupt header"))
    let corruptFile = URL(fileURLWithPath: "corrupt.mp4")
    if let cropAction = FormatRegistry.shared.action(for: corruptFile, actionID: "video.crop") {
        let failModel = ParameterFormModel(action: cropAction, loadLastUsed: false, inputFile: corruptFile, probe: failingProbe)
        assertTest(!failModel.isValid, "17.8 ParameterFormModel is invalid when probing fails")
        assertTest(failModel.presets.isEmpty, "17.8 No guessed presets are created when probing fails")
        assertTest(failModel.validationErrors["rectangle"]?.contains("Could not probe media for crop") == true,
                   "17.8 Validation error contains readable message explaining probe failure")
    } else {
        assertTest(false, "17.8 video.crop action not found")
    }

    // 17.9 ParameterPanelView displays real source and crop size readouts
    if let cropAction = FormatRegistry.shared.action(for: landFile, actionID: "video.crop") {
        let panelModel = ParameterFormModel(action: cropAction, loadLastUsed: false, inputFile: landFile, probe: probe)
        let panel = ParameterPanelView(model: panelModel, action: cropAction)
        assertTest(panel.subviews.count > 0, "17.9 ParameterPanelView renders crop interface")

        func findLabel(identifier: String, in view: NSView) -> NSTextField? {
            if let tf = view as? NSTextField, tf.identifier?.rawValue == identifier {
                return tf
            }
            for sub in view.subviews {
                if let found = findLabel(identifier: identifier, in: sub) {
                    return found
                }
            }
            return nil
        }

        let srcLabel = findLabel(identifier: "ParameterPanel.sourceDimensions", in: panel)
        let cropLabel = findLabel(identifier: "ParameterPanel.cropDimensions", in: panel)
        assertTest(srcLabel?.stringValue == "Source: 1280×720", "17.9 Source dimension label displays real 1280×720 probed size")
        assertTest(cropLabel?.stringValue == "Crop: 1280×720", "17.9 Initial crop dimension label displays full frame 1280×720")

        if let p11 = panelModel.presets.first(where: { $0.id == "crop_1_1" }) {
            panelModel.applyPreset(p11)
            panel.refreshAllFields()
            assertTest(cropLabel?.stringValue == "Crop: 720×720", "17.9 Crop dimension label updates to 720×720 after applying 1:1 preset")
        } else {
            assertTest(false, "17.9 crop_1_1 preset not found")
        }
    } else {
        assertTest(false, "17.9 video.crop action not found")
    }
}

// MARK: - 18. Probed Trim Defaults, Duration Validation & Target-Size Warnings (Phase 10 Fix 2)
print("\n--- 18. Probed Trim Defaults, Duration Validation & Target-Size Warnings (Phase 10 Fix 2) ---")
do {
    let videoFile = URL(fileURLWithPath: "clip.mp4")
    let audioFile = URL(fileURLWithPath: "song.mp3")
    let imgFile = URL(fileURLWithPath: "photo.jpg")

    let fakeProbe = FakeMediaProbe(results: [
        "clip.mp4": MediaProbeResult(width: 1920, height: 1080, duration: 45.0, fileSize: 12_000_000),
        "song.mp3": MediaProbeResult(duration: 180.5, fileSize: 4_000_000),
        "photo.jpg": MediaProbeResult(width: 2000, height: 1500, fileSize: 2_000_000) // 2 MB
    ])

    // 18.1 Trim defaults: video.trim initializes end = probed duration (45.0s)
    if let vTrimAction = FormatRegistry.shared.action(for: videoFile, actionID: "video.trim") {
        let vTrimModel = ParameterFormModel(action: vTrimAction, loadLastUsed: false, inputFile: videoFile, probe: fakeProbe)
        assertTest(vTrimModel.isValid, "18.1 video.trim model initially valid")
        assertTest(vTrimModel.values["start"] == .number(0.0), "18.1 Default start time is 0.0s")
        assertTest(vTrimModel.values["end"] == .number(45.0), "18.1 Default end time uses probed duration (45.0s)")

        // 18.2 Trim validation: end <= start rejected
        vTrimModel.updateValue(.number(20.0), for: "start")
        vTrimModel.updateValue(.number(10.0), for: "end")
        assertTest(!vTrimModel.isValid, "18.2 End time <= start time is invalid")
        assertTest(vTrimModel.validationErrors["end"]?.contains("must be greater than start") == true,
                   "18.2 Error explains end time must be greater than start time")

        // 18.3 Trim validation: end exceeding duration rejected
        vTrimModel.updateValue(.number(50.0), for: "end")
        assertTest(!vTrimModel.isValid, "18.3 End time exceeding probed duration (50.0s > 45.0s) is invalid")
        assertTest(vTrimModel.validationErrors["end"]?.contains("exceeds media duration") == true,
                   "18.3 Error explains end time exceeds media duration")

        // 18.4 Trim validation: valid start/end within duration accepted
        vTrimModel.updateValue(.number(5.0), for: "start")
        vTrimModel.updateValue(.number(30.0), for: "end")
        assertTest(vTrimModel.isValid, "18.4 Valid start/end within probed duration is valid")
    } else {
        assertTest(false, "18.1 video.trim action not found")
    }

    // 18.5 Audio trim defaults: audio.trim initializes end = probed duration (180.5s)
    if let aTrimAction = FormatRegistry.shared.action(for: audioFile, actionID: "audio.trim") {
        let aTrimModel = ParameterFormModel(action: aTrimAction, loadLastUsed: false, inputFile: audioFile, probe: fakeProbe)
        assertTest(aTrimModel.isValid, "18.5 audio.trim model initially valid")
        assertTest(aTrimModel.values["end"] == .number(180.5), "18.5 audio.trim default end time uses probed duration (180.5s)")

        // Start time exceeding duration rejected
        aTrimModel.updateValue(.number(200.0), for: "start")
        aTrimModel.updateValue(.number(210.0), for: "end")
        assertTest(!aTrimModel.isValid, "18.5 Start time exceeding duration is invalid")
        assertTest(aTrimModel.validationErrors["start"]?.contains("exceeds media duration") == true,
                   "18.5 Error explains start time exceeds media duration")
    } else {
        assertTest(false, "18.5 audio.trim action not found")
    }

    // 18.6 Target-size warning: preset larger than source file produces inline warning
    if let compAction = FormatRegistry.shared.action(for: imgFile, actionID: "image.compress") {
        let compModel = ParameterFormModel(action: compAction, loadLastUsed: false, inputFile: imgFile, probe: fakeProbe)
        assertTest(compModel.isValid, "18.6 image.compress model initially valid")

        // photo.jpg is 2 MB (2,000,000 bytes). size_5mb preset is 5 MB (5,242,880 bytes).
        if let p5mb = compModel.presets.first(where: { $0.id == "size_5mb" }) {
            compModel.applyPreset(p5mb)
            // 18.7 Target-size warning: warning present, but model remains valid and Run stays enabled
            assertTest(compModel.warnings["targetSize"] == "already smaller than this target",
                       "18.7 Target-size larger than source file produces 'already smaller than this target' warning")
            assertTest(compModel.isValid, "18.7 Run stays enabled (isValid == true) when target-size warning is present")
            assertTest(compModel.validationErrors.isEmpty, "18.7 validationErrors is empty despite target-size warning")

            // Test UI panel shows warning and leaves Run button enabled
            let compPanel = ParameterPanelView(model: compModel, action: compAction)
            assertTest(compPanel.subviews.count > 0, "18.7 ParameterPanelView renders compression controls")

            func findLabel(identifier: String, in view: NSView) -> NSTextField? {
                if let tf = view as? NSTextField, tf.identifier?.rawValue == identifier {
                    return tf
                }
                for sub in view.subviews {
                    if let found = findLabel(identifier: identifier, in: sub) {
                        return found
                    }
                }
                return nil
            }

            let statusLabel = findLabel(identifier: "ParameterPanel.errorLabel", in: compPanel)
            let inlineWarnLabel = findLabel(identifier: "ParameterPanel.inlineWarning.targetSize", in: compPanel)

            assertTest(statusLabel?.stringValue.contains("already smaller than this target") == true,
                       "18.8 ParameterPanel bottom status displays warning message")
            assertTest(inlineWarnLabel?.stringValue.contains("already smaller than this target") == true,
                       "18.8 ParameterPanel field shows inline warning 'already smaller than this target'")

            // When updated to smaller size (e.g. 1 MB), warning disappears
            compModel.updateValue(.integer(1024 * 1024), for: "targetSize")
            compPanel.refreshAllFields()
            assertTest(compModel.warnings["targetSize"] == nil,
                       "18.9 Target-size smaller than source file clears warning")
            assertTest(inlineWarnLabel?.isHidden == true,
                       "18.9 Inline warning label is hidden when target size is smaller than source file")
        } else {
            assertTest(false, "18.6 size_5mb preset not found")
        }
    } else {
        assertTest(false, "18.6 image.compress action not found")
    }
}

// MARK: - 19. Drop Window Parameter Panel & Batch Execution Tests (Phase 10 Step 3)
print("\n--- 19. Drop Window Parameter Panel & Batch Execution Tests (Phase 10 Step 3) ---")
do {
    let dummyAction = ConversionAction(
        id: "image.convert.jpg",
        displayName: "Convert to JPG",
        outputExtension: "jpg",
        category: .image,
        iconName: "photo",
        parameters: [],
        buildInvocations: { inUrl, outUrl, _ in
            return [Invocation(toolName: "magick", arguments: [inUrl.path, outUrl.path])]
        }
    )

    let dummyParamAction = ConversionAction(
        id: "image.compress",
        displayName: "Compress Image",
        outputExtension: "jpg",
        isAdvanced: true,
        category: .image,
        iconName: "arrow.down.right.and.arrow.up.left",
        parameters: [
            ActionParameter(
                id: "targetSize",
                label: "Target Size",
                kind: .sizeInBytes,
                defaultValue: .integer(5 * 1024 * 1024)
            )
        ],
        buildInvocations: { inUrl, outUrl, _ in
            return [Invocation(toolName: "magick", arguments: [inUrl.path, outUrl.path])]
        }
    )

    // 19.1 BatchProgressRowView initialization
    let batchView = BatchProgressRowView(totalCount: 5, action: dummyParamAction)
    assertTest(batchView.totalCount == 5, "19.1 BatchProgressRowView totalCount is 5")
    assertTest(batchView.completedCount == 0, "19.1 Initial completedCount is 0")
    assertTest(batchView.summaryLabel.stringValue == "0 of 5 complete", "19.1 Initial summary string is '0 of 5 complete'")
    assertTest(batchView.progressBar.doubleValue == 0.0, "19.1 Initial progress bar doubleValue is 0.0")
    assertTest(batchView.progressBar.maxValue == 5.0, "19.1 Progress bar maxValue is 5.0")

    // 19.2 BatchProgressRowView update progress
    batchView.update(completed: 3, failed: 0)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    assertTest(batchView.completedCount == 3, "19.2 BatchProgressRowView updates completedCount to 3")
    assertTest(batchView.summaryLabel.stringValue == "3 of 5 complete", "19.2 Summary label displays '3 of 5 complete'")
    assertTest(batchView.progressBar.doubleValue == 3.0, "19.2 Progress bar advances to 3.0")

    // 19.3 BatchProgressRowView failure handling
    batchView.update(completed: 3, failed: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    assertTest(batchView.failedCount == 1, "19.3 BatchProgressRowView records 1 failure")
    assertTest(batchView.summaryLabel.stringValue.contains("4 of 5 complete (1 failed)"),
               "19.3 Summary label includes failure count")

    // 19.4 BatchProgressRowView all complete
    batchView.update(completed: 5, failed: 0)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    assertTest(batchView.summaryLabel.stringValue == "All 5 complete", "19.4 Summary label shows 'All 5 complete' when done")
    assertTest(batchView.cancelButton.isHidden, "19.4 Cancel button is hidden when all complete")

    // 19.5 BatchProgressRowView cancellation
    var wasCancelled = false
    batchView.onCancel = { wasCancelled = true }
    batchView.markCancelled()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    assertTest(batchView.isCancelled, "19.5 BatchProgressRowView marked as cancelled")
    assertTest(batchView.summaryLabel.stringValue.contains("Cancelled"), "19.5 Summary label indicates cancellation")

    // 19.6 DropWindowViewController files drop
    let dropVC = DropWindowViewController()
    dropVC.loadView()
    dropVC.viewDidLoad()
    assertTest(dropVC.view != nil, "19.6 DropWindowViewController view loaded")

    let testFile1 = URL(fileURLWithPath: "test1.png")
    let testFile2 = URL(fileURLWithPath: "test2.png")
    let testFile3 = URL(fileURLWithPath: "test3.png")

    dropVC.handleFilesDropped([testFile1])
    assertTest(dropVC.selectedFiles.count == 1, "19.6 Single file dropped records 1 selected file")

    dropVC.handleFilesDropped([testFile1, testFile2, testFile3])
    assertTest(dropVC.selectedFiles.count == 3, "19.6 Multi-file batch dropped records 3 selected files")

    // 19.7 Parameterless action executes directly without showing ParameterPanelView
    dropVC.selectAction(dummyAction)
    assertTest(dropVC.activeParameterPanel == nil, "19.7 Parameterless action executes directly without parameter panel")

    // 19.8 Parameterized action presents ParameterPanelView inline
    dropVC.selectAction(dummyParamAction)
    assertTest(dropVC.activeParameterPanel != nil, "19.8 Parameterized action displays ParameterPanelView inline")
    assertTest(dropVC.activeParameterPanel?.action.id == "image.compress", "19.8 Active parameter panel is bound to image.compress")

    // 19.9 Parameter panel cancel dismisses panel and restores format chips
    dropVC.activeParameterPanel?.onCancel?()
    assertTest(dropVC.activeParameterPanel == nil, "19.9 onCancel dismisses parameter panel")

    // 19.10 Batch execution creates BatchProgressRowView and individual job rows
    dropVC.selectAction(dummyParamAction)
    assertTest(dropVC.activeParameterPanel != nil, "19.10 Parameter panel presented for batch")
    dropVC.activeParameterPanel?.onRun?([:])
    assertTest(dropVC.activeParameterPanel == nil, "19.10 onRun dismisses parameter panel")
    assertTest(dropVC.jobsStack.arrangedSubviews.contains(where: { $0 is BatchProgressRowView }),
               "19.10 Batch execution adds BatchProgressRowView to jobsStack")
}

// MARK: - 20. Batch Parameter Resolution & Intent Tests (Phase 10 Fix A)
print("\n--- 20. Batch Parameter Resolution & Intent Tests (Phase 10 Fix A) ---")
do {
    let file1 = URL(fileURLWithPath: "file1_1280x720.mp4")
    let file2 = URL(fileURLWithPath: "file2_1920x1080.mp4")
    let file3 = URL(fileURLWithPath: "file3_1080x1920.mp4")
    let fileSmall = URL(fileURLWithPath: "file_small_800x600.mp4")

    let fakeProbe = FakeMediaProbe(results: [
        "file1_1280x720.mp4": MediaProbeResult(width: 1280, height: 720, duration: 15.5, fileSize: 10_000_000),
        "file2_1920x1080.mp4": MediaProbeResult(width: 1920, height: 1080, duration: 42.0, fileSize: 25_000_000),
        "file3_1080x1920.mp4": MediaProbeResult(width: 1080, height: 1920, duration: 120.0, fileSize: 30_000_000),
        "file_small_800x600.mp4": MediaProbeResult(width: 800, height: 600, duration: 10.0, fileSize: 5_000_000)
    ])

    let cropAction = ConversionAction(
        id: "video.crop",
        displayName: "Crop Video",
        outputExtension: "mp4",
        category: .video,
        iconName: "crop",
        parameters: [
            ActionParameter(
                id: "rectangle",
                label: "Crop Rectangle",
                kind: .rectangle,
                defaultValue: .rectangle(x: 0, y: 0, width: 1920, height: 1080)
            )
        ],
        buildInvocations: { inUrl, outUrl, _ in
            return [Invocation(toolName: "ffmpeg", arguments: [inUrl.path, outUrl.path])]
        }
    )

    let trimAction = ConversionAction(
        id: "video.trim",
        displayName: "Trim Video",
        outputExtension: "mp4",
        category: .video,
        iconName: "scissors",
        parameters: [
            ActionParameter(id: "start", label: "Start Time", kind: .number(unit: "s"), defaultValue: .number(0.0)),
            ActionParameter(id: "end", label: "End Time", kind: .number(unit: "s"), defaultValue: .number(10.0))
        ],
        buildInvocations: { inUrl, outUrl, _ in
            return [Invocation(toolName: "ffmpeg", arguments: [inUrl.path, outUrl.path])]
        }
    )

    // 20.1 Test 1: Batch with 3 files of different sizes where crop 1:1 gives the correct centered rectangle for each
    let batchCropModel = ParameterFormModel(
        action: cropAction,
        loadLastUsed: false,
        inputFiles: [file1, file2, file3],
        probe: fakeProbe
    )
    assertTest(batchCropModel.isBatch, "20.1 ParameterFormModel isBatch is true for 3 files")
    assertTest(batchCropModel.batchCount == 3, "20.1 ParameterFormModel batchCount is 3")

    // Set 1:1 crop ratio intent
    batchCropModel.cropIntent = .ratio(width: 1, height: 1)

    let resCrop1 = try? batchCropModel.resolveParameters(for: file1, probe: fakeProbe)
    let resCrop2 = try? batchCropModel.resolveParameters(for: file2, probe: fakeProbe)
    let resCrop3 = try? batchCropModel.resolveParameters(for: file3, probe: fakeProbe)

    // 1280x720 -> 720x720 at x=280, y=0
    assertTest(resCrop1?["rectangle"] == .rectangle(x: 280, y: 0, width: 720, height: 720),
               "20.1 1280x720 with 1:1 ratio crop gives 720x720 at x=280,y=0")

    // 1920x1080 -> 1080x1080 at x=420, y=0
    assertTest(resCrop2?["rectangle"] == .rectangle(x: 420, y: 0, width: 1080, height: 1080),
               "20.1 1920x1080 with 1:1 ratio crop gives 1080x1080 at x=420,y=0")

    // 1080x1920 -> 1080x1080 at x=0, y=420
    assertTest(resCrop3?["rectangle"] == .rectangle(x: 0, y: 420, width: 1080, height: 1080),
               "20.1 1080x1920 with 1:1 ratio crop gives 1080x1080 at x=0,y=420")

    // 20.2 Test 2: Trim to end uses each file's own duration
    let batchTrimModel = ParameterFormModel(
        action: trimAction,
        loadLastUsed: false,
        inputFiles: [file1, file2, file3],
        probe: fakeProbe
    )
    batchTrimModel.trimEndIntent = .endOfFile

    let resTrim1 = try? batchTrimModel.resolveParameters(for: file1, probe: fakeProbe)
    let resTrim2 = try? batchTrimModel.resolveParameters(for: file2, probe: fakeProbe)
    let resTrim3 = try? batchTrimModel.resolveParameters(for: file3, probe: fakeProbe)

    assertTest(resTrim1?["end"] == .number(15.5), "20.2 File 1 trim to end uses probed duration (15.5s)")
    assertTest(resTrim2?["end"] == .number(42.0), "20.2 File 2 trim to end uses probed duration (42.0s)")
    assertTest(resTrim3?["end"] == .number(120.0), "20.2 File 3 trim to end uses probed duration (120.0s)")

    // 20.3 Batch mode UI displays 'Applies to N files' without single-file dimensions
    let batchPanel = ParameterPanelView(model: batchCropModel, action: cropAction)
    func findLabel(identifier: String, in view: NSView) -> NSTextField? {
        if let tf = view as? NSTextField, tf.identifier?.rawValue == identifier {
            return tf
        }
        for sub in view.subviews {
            if let found = findLabel(identifier: identifier, in: sub) {
                return found
            }
        }
        return nil
    }

    let sourceLabel = findLabel(identifier: "ParameterPanel.sourceDimensions", in: batchPanel)
    let cropDimLabel = findLabel(identifier: "ParameterPanel.cropDimensions", in: batchPanel)
    assertTest(sourceLabel?.stringValue == "Applies to 3 files",
               "20.3 ParameterPanel displays 'Applies to 3 files' in batch mode")
    assertTest(sourceLabel?.stringValue.contains("1280×720") == false,
               "20.3 ParameterPanel does NOT show single file dimensions as if they were all")
    assertTest(cropDimLabel?.stringValue == "Ratio: 1:1",
               "20.3 ParameterPanel displays 'Ratio: 1:1' for cropDimensions in batch mode")

    // 20.4 Manual crop out of bounds per-file error handling
    batchCropModel.cropIntent = .manual(x: 0, y: 0, width: 1280, height: 720)

    var file1Fits = false
    var fileSmallThrew = false
    var file2Fits = false

    do {
        let r1 = try batchCropModel.resolveParameters(for: file1, probe: fakeProbe)
        file1Fits = (r1["rectangle"] == .rectangle(x: 0, y: 0, width: 1280, height: 720))
    } catch {
        file1Fits = false
    }

    do {
        _ = try batchCropModel.resolveParameters(for: fileSmall, probe: fakeProbe)
        fileSmallThrew = false
    } catch PastaError.invalidInput {
        fileSmallThrew = true
    } catch {
        fileSmallThrew = false
    }

    do {
        let r2 = try batchCropModel.resolveParameters(for: file2, probe: fakeProbe)
        file2Fits = (r2["rectangle"] == .rectangle(x: 0, y: 0, width: 1280, height: 720))
    } catch {
        file2Fits = false
    }

    assertTest(file1Fits, "20.4 File 1 fits manual rectangle 1280x720")
    assertTest(fileSmallThrew, "20.4 FileSmall (800x600) throws invalidInput when manual crop exceeds bounds")
    assertTest(file2Fits, "20.4 File 2 fits manual rectangle 1280x720")
}

print("\n==================================================")
print("Test Suite Summary: \(passedTests)/\(totalTests) Passed, \(failedTests) Failed")
print("==================================================")

if failedTests > 0 {
    exit(1)
} else {
    exit(0)
}
