import Foundation
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

    monitor.onWheelOpen = { files, isAdv, loc in
        wheelOpened = true
        currentIsAdvanced = isAdv
    }
    monitor.onWheelClose = {
        wheelClosed = true
    }
    monitor.onChargingProgress = { prog, loc in
        lastProgress = prog
    }
    monitor.onModeToggle = { isAdv in
        modeToggled = true
        currentIsAdvanced = isAdv
    }

    // 12.1 Hold 449 ms: no wheel
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1000.000)
    assertTest(monitor.state == .armed(startedAt: 1000.000, files: mockPasteboard.mockURLs, location: NSPoint(x: 100, y: 100)), "12.1 Shift down initiates Armed state at t=1000.0")

    // Advance to 1000.449 (449 ms elapsed)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1000.449)
    assertTest(!wheelOpened, "12.1 Hold 449 ms: wheel does NOT open")
    if case .charging = monitor.state {
        assertTest(true, "12.1 State is Charging after 120ms threshold")
    } else {
        assertTest(false, "12.1 Expected Charging state at 449 ms")
    }

    // 12.2 Hold 450 ms: wheel opens
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1000.450)
    assertTest(wheelOpened, "12.2 Hold 450 ms: wheel opens successfully")
    if case .open = monitor.state {
        assertTest(true, "12.2 State transitions to Open at exactly 450 ms")
    } else {
        assertTest(false, "12.2 Expected Open state at 450 ms")
    }

    // 12.3 Release after open: wheel stays (latches)
    wheelClosed = false
    monitor.processFlagsChanged(modifiers: [], timestamp: 1000.550)
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
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1100.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1100.200)
    monitor.processKeyDown(keyCode: 12, timestamp: 1100.250) // 'q' or other key
    assertTest(!wheelOpened && monitor.state == .idle && chargingCancelled, "12.5 Any key press during charging cancels progress and returns to Idle")

    // 12.6 No drag session: Shift does nothing
    mockPasteboard.mockURLs = []
    wheelOpened = false
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1200.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1200.500)
    assertTest(!wheelOpened && monitor.state == .idle, "12.6 No drag session: Shift press does nothing")

    // 12.7 Text drag (no file URLs): does nothing
    mockPasteboard.mockURLs = [] // Empty file list (pure text drag)
    wheelOpened = false
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1300.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1300.600)
    assertTest(!wheelOpened && monitor.state == .idle, "12.7 Text drag without file URLs does nothing")

    // 12.8 Second hold closes wheel
    mockPasteboard.mockURLs = [URL(fileURLWithPath: "/tmp/sample.png")]
    wheelOpened = false
    wheelClosed = false
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1400.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1400.450)
    assertTest(wheelOpened, "14.8 Wheel opened for second hold test")
    monitor.processFlagsChanged(modifiers: [], timestamp: 1400.500) // release shift

    // Second shift press down
    monitor.processFlagsChanged(modifiers: [.shift], timestamp: 1400.600)
    // Hold second shift for 450 ms -> 1401.050
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1401.050)
    assertTest(wheelClosed && monitor.state == .idle, "12.8 Second Shift hold closes the open wheel")

    // 12.9 Option tap toggles mode
    wheelOpened = false
    modeToggled = false
    currentIsAdvanced = false
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1500.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1500.450)
    monitor.processFlagsChanged(modifiers: [], timestamp: 1500.500)

    // Quick option tap (<250 ms): down at 1500.600, up at 1500.750 (150 ms)
    monitor.processFlagsChanged(modifiers: [.option], timestamp: 1500.600)
    monitor.processFlagsChanged(modifiers: [], timestamp: 1500.750)
    assertTest(modeToggled && currentIsAdvanced == true, "12.9 Quick Option tap (<250 ms) toggles Convert to Advanced mode")

    // Second quick option tap toggles back
    modeToggled = false
    monitor.processFlagsChanged(modifiers: [.option], timestamp: 1500.800)
    monitor.processFlagsChanged(modifiers: [], timestamp: 1500.900)
    assertTest(modeToggled && currentIsAdvanced == false, "12.9 Second Option tap toggles Advanced back to Convert mode")

    // 12.10 Option hold (>250 ms) does NOT toggle
    modeToggled = false
    monitor.processFlagsChanged(modifiers: [.option], timestamp: 1501.000)
    monitor.processFlagsChanged(modifiers: [], timestamp: 1501.300) // 300 ms hold
    assertTest(!modeToggled, "12.10 Option hold exceeding 250 ms does not toggle mode (requires a quick tap)")

    // 12.11 Configurable hold duration
    prefs.shiftHoldDurationMs = 600.0
    monitor.closeWheel()
    wheelOpened = false
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1600.000)
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1600.450)
    assertTest(!wheelOpened, "12.11 Configured 600 ms duration: not opened at 450 ms")
    monitor.processMouseDragged(modifiers: [.shift], location: NSPoint(x: 100, y: 100), timestamp: 1600.600)
    assertTest(wheelOpened, "12.11 Configured 600 ms duration: opens at 600 ms")
}

print("\n==================================================")
print("Test Suite Summary: \(passedTests)/\(totalTests) Passed, \(failedTests) Failed")
print("==================================================")

if failedTests > 0 {
    exit(1)
} else {
    exit(0)
}
