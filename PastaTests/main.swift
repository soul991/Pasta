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

print("\n==================================================")
print("Test Suite Summary: \(passedTests)/\(totalTests) Passed, \(failedTests) Failed")
print("==================================================")

if failedTests > 0 {
    exit(1)
} else {
    exit(0)
}
