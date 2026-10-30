import Foundation

public struct PastaCLI {
    public static func run(arguments: [String]) {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(0)
        }

        switch command {
        case "doctor":
            runDoctor()
        case "list-actions":
            guard args.count >= 2 else {
                fputs("Error: Missing file path for list-actions.\nUsage: pasta list-actions <file>\n", stderr)
                exit(1)
            }
            runListActions(filePath: args[1])
        case "convert":
            runConvert(args: Array(args.dropFirst()))
        case "quick-action":
            guard args.count >= 2 else {
                fputs("Error: Missing file path for quick-action.\nUsage: pasta quick-action <file>...\n", stderr)
                exit(1)
            }
            runQuickAction(files: Array(args.dropFirst()))
        case "--help", "-h", "help":
            printUsage()
            exit(0)
        default:
            fputs("Error: Unknown command '\(command)'. Run 'pasta help' for usage.\n", stderr)
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        Pasta - Offline macOS File Converter
        Usage:
          pasta convert --action <action_id> [--param key=value] <file>...
          pasta convert <file> --to <format>
          pasta list-actions <file>
          pasta doctor
          pasta help
        """)
    }

    private static func runDoctor() {
        let tools = [
            "ffmpeg", "cwebp", "magick", "gs", "qpdf", "pdftoppm",
            "pdftotext", "exiftool", "pandoc", "rsvg-convert", "unar",
            "7zz", "sips", "ditto", "tar"
        ]

        print("Pasta Environment & Engine Doctor:")
        print("--------------------------------------------------")
        print("Required Engine Tools:")
        var allOk = true
        for tool in tools {
            if let url = ToolLocator.shared.findTool(tool) {
                print("  [OK]      \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) -> \(url.path)")
            } else {
                print("  [MISSING] \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) (NOT FOUND)")
                allOk = false
            }
        }
        print("\nOptional Engine Tools:")
        let optionalTools = ["soffice"]
        for tool in optionalTools {
            if let url = ToolLocator.shared.findOptionalTool(tool) {
                print("  [OK (OPTIONAL)]  \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) -> \(url.path)")
            } else {
                print("  [OPTIONAL MISSING] \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) (LibreOffice not installed, Office conversions disabled)")
            }
        }
        print("--------------------------------------------------")
        if allOk {
            print("All required engine binaries are available.")
        } else {
            print("Warning: Some tools are missing. Install missing tools via Homebrew.")
        }
    }

    private static func runListActions(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            fputs("Error: File not found at '\(filePath)'\n", stderr)
            exit(1)
        }

        let standard = FormatRegistry.shared.actions(for: url, isOptionHeld: false)
        let advanced = FormatRegistry.shared.actions(for: url, isOptionHeld: true)

        print("Actions for: \(url.lastPathComponent)")
        print("Standard Actions:")
        for a in standard {
            var line = "  - \(a.id.padding(toLength: 30, withPad: " ", startingAt: 0)) (\(a.displayName) -> .\(a.outputExtension))"
            if !a.parameters.isEmpty {
                let pList = a.parameters.map { "\($0.id)=\($0.defaultValue.asString)" }.joined(separator: ", ")
                line += " [params: \(pList)]"
            }
            print(line)
        }
        print("\nAdvanced Actions:")
        for a in advanced {
            var line = "  - \(a.id.padding(toLength: 30, withPad: " ", startingAt: 0)) (\(a.displayName) -> .\(a.outputExtension))"
            if !a.parameters.isEmpty {
                let pList = a.parameters.map { "\($0.id)=\($0.defaultValue.asString)" }.joined(separator: ", ")
                line += " [params: \(pList)]"
            }
            print(line)
        }
    }

    private static func runConvert(args: [String]) {
        var actionId: String?
        var targetFormat: String?
        var rawParams: [String: String] = [:]
        var files: [String] = []

        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg == "--action" && i + 1 < args.count {
                actionId = args[i + 1]
                i += 2
            } else if arg == "--to" && i + 1 < args.count {
                targetFormat = args[i + 1]
                i += 2
            } else if arg == "--param" && i + 1 < args.count {
                let pair = args[i + 1]
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    rawParams[parts[0]] = parts[1]
                }
                i += 2
            } else if !arg.hasPrefix("-") {
                files.append(arg)
                i += 1
            } else {
                i += 1
            }
        }

        guard !files.isEmpty else {
            fputs("Error: No input files specified.\nUsage: pasta convert --action <action_id> [--param key=value] <file>...\n", stderr)
            exit(1)
        }

        let fileURLs = files.map { URL(fileURLWithPath: $0) }
        for u in fileURLs {
            guard FileManager.default.fileExists(atPath: u.path) else {
                fputs("Error: File does not exist at '\(u.path)'\n", stderr)
                exit(1)
            }
        }

        let firstURL = fileURLs[0]
        let candidateAction: ConversionAction?
        if let aid = actionId {
            candidateAction = FormatRegistry.shared.action(for: firstURL, actionID: aid)
        } else if let tf = targetFormat {
            candidateAction = FormatRegistry.shared.action(for: firstURL, targetExtension: tf)
        } else {
            fputs("Error: Must specify either --action <action_id> or --to <extension>.\n", stderr)
            exit(1)
        }

        if let act = candidateAction, act.isBatch || (fileURLs.count > 1 && act.buildBatchInvocationsWithParams != nil) {
            var effectiveParams: ParameterValues = [:]
            for (k, v) in rawParams {
                if let declared = act.parameters.first(where: { $0.id == k }) {
                    effectiveParams[k] = ActionParameter.parseCLIValue(v, for: declared.kind)
                } else {
                    effectiveParams[k] = .text(v)
                }
            }
            do {
                let output = try JobRunner.shared.runBatch(action: act, inputs: fileURLs, parameters: effectiveParams)
                print("OK: \(output.path)")
                return
            } catch {
                fputs("Failed batch action '\(act.id)': \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }

        var anyFailed = false

        for file in files {
            let url = URL(fileURLWithPath: file)

            let action: ConversionAction?
            if let aid = actionId {
                action = FormatRegistry.shared.action(for: url, actionID: aid)
                if action == nil {
                    fputs("Error: Action '\(aid)' is not valid for '\(url.lastPathComponent)'.\n", stderr)
                    anyFailed = true
                    continue
                }
            } else if let tf = targetFormat {
                action = FormatRegistry.shared.action(for: url, targetExtension: tf)
                if action == nil {
                    fputs("Error: Target format '\(tf)' is not supported for '\(url.lastPathComponent)'.\n", stderr)
                    anyFailed = true
                    continue
                }
            } else {
                fputs("Error: Must specify either --action <action_id> or --to <extension>.\n", stderr)
                exit(1)
            }

            guard let selectedAction = action else { continue }

            var effectiveParams: ParameterValues = [:]
            for (k, v) in rawParams {
                if let declared = selectedAction.parameters.first(where: { $0.id == k }) {
                    effectiveParams[k] = ActionParameter.parseCLIValue(v, for: declared.kind)
                } else {
                    effectiveParams[k] = .text(v)
                }
            }

            do {
                let output = try JobRunner.shared.run(action: selectedAction, input: url, parameters: effectiveParams)
                print("OK: \(output.path)")
            } catch {
                fputs("Failed to convert '\(url.lastPathComponent)': \(error.localizedDescription)\n", stderr)
                anyFailed = true
            }
        }

        if anyFailed {
            exit(1)
        }
    }

    private static func runQuickAction(files: [String]) {
        for file in files {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let actions = FormatRegistry.shared.actions(for: url, isOptionHeld: false)
            guard !actions.isEmpty else {
                showNotification(title: "Pasta", message: "No conversion formats available for \(url.lastPathComponent)")
                continue
            }

            let actionTitles = actions.map { "\"\($0.displayName) (.\($0.outputExtension))\"" }.joined(separator: ", ")
            let script = "choose from list {\(actionTitles)} with title \"Pasta\" with prompt \"Choose target format for \(url.lastPathComponent):\" without multiple selections allowed"

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            let p = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = p
            proc.standardError = errPipe

            do {
                try proc.run()
            } catch {
                PastaLogger.shared.error("Failed to execute AppleScript dialog for \(url.lastPathComponent): \(error.localizedDescription)")
                fputs("Error: Could not run selection dialog: \(error.localizedDescription)\n", stderr)
                continue
            }
            proc.waitUntilExit()

            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            if proc.terminationStatus != 0 {
                if errStr.contains("-1743") || errStr.lowercased().contains("not authorized") {
                    let msg = FinderSelectionHelper.formatPermissionDeniedMessage()
                    PastaLogger.shared.error(msg)
                    fputs("Error: \(msg)\n", stderr)
                } else if !errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    PastaLogger.shared.error("AppleScript error: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
                continue
            }

            let data = p.fileHandleForReading.readDataToEndOfFile()
            let chosen = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !chosen.isEmpty && chosen != "false" else { continue }

            if let matched = actions.first(where: { chosen.contains($0.displayName) }) {
                do {
                    let out = try JobRunner.shared.run(action: matched, input: url)
                    showNotification(title: "Pasta Converted", message: "Successfully created \(out.lastPathComponent)")
                } catch {
                    showNotification(title: "Pasta Failed", message: error.localizedDescription)
                }
            }
        }
    }

    public static func showNotification(title: String, message: String) {
        let script = "display notification \"\(message.replacingOccurrences(of: "\"", with: "\\\""))\" with title \"\(title)\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let errPipe = Pipe()
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                PastaLogger.shared.error("Notification error: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            PastaLogger.shared.error("Failed to run notification osascript: \(error.localizedDescription)")
        }
    }
}
