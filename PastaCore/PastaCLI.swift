import Foundation
import UserNotifications

public struct PastaCLI {
    public static func run(arguments: [String]) {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(0)
        }

        switch command {
        case "doctor":
            runDoctor(args: Array(args.dropFirst()))
        case "list-actions":
            runListActions(args: Array(args.dropFirst()))
        case "convert":
            runConvert(args: Array(args.dropFirst()))
        case "quick-action":
            guard args.count >= 2 else {
                fputs("Error: Missing file path for quick-action.\nUsage: pasta quick-action <file>...\n", stderr)
                exit(1)
            }
            runQuickAction(files: Array(args.dropFirst()))
        case "metadata":
            runMetadata(args: Array(args.dropFirst()))
        case "--help", "-h", "help":
            printUsage()
            exit(0)
        default:
            fputs("Error: Unknown command '\(command)'. Run 'pasta help' for usage.\n", stderr)
            exit(1)
        }
    }

    private static func runMetadata(args: [String]) {
        guard let sub = args.first else {
            fputs("Error: Missing metadata subcommand (read or edit).\nUsage: pasta metadata read <file> [--json]\n", stderr)
            exit(1)
        }
        if sub == "read" {
            let rest = Array(args.dropFirst())
            guard let file = rest.first(where: { !$0.hasPrefix("--") }) else {
                fputs("Error: Missing file path for metadata read.\nUsage: pasta metadata read <file> [--json]\n", stderr)
                exit(1)
            }
            let asJSON = rest.contains("--json")
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                fputs("Error: File not found at '\(file)'\n", stderr)
                exit(1)
            }
            do {
                let out = try MetadataTools.shared.formatMetadata(from: url, asJSON: asJSON)
                print(out)
                exit(0)
            } catch {
                fputs("Error reading metadata: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        } else {
            fputs("Error: Unknown metadata subcommand '\(sub)'. Use 'read'.\n", stderr)
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        Pasta - Offline macOS File Converter
        Usage:
          pasta convert --action <action_id> [--dest <dir>] [--param key=value] <file>...
          pasta convert <file> --to <format> [--dest <dir>]
          pasta list-actions <file> | --all [--markdown]
          pasta doctor [--json]
          pasta help
        """)
    }

    private static func runDoctor(args: [String]) {
        let isJson = args.contains("--json")
        let report = ToolLocator.shared.doctorReportData(fetchVersions: true)
        if isJson {
            print(report.jsonString(prettyPrinted: true))
        } else {
            print(ToolLocator.shared.doctorReport(fetchVersions: true))
        }
    }

    private static func runListActions(args: [String]) {
        if args.contains("--all") {
            if args.contains("--markdown") {
                let actions = FormatRegistry.shared.allRegisteredActions()
                print("| Category | Action ID | Display Name | Target Extension | Advanced |")
                print("| :--- | :--- | :--- | :--- | :---: |")
                for a in actions {
                    let cat = a.category.displayName
                    let id = "`\(a.id)`"
                    let name = a.displayName
                    let ext = a.outputExtension.isEmpty ? "(folder)" : ".\(a.outputExtension)"
                    let adv = a.isAdvanced ? "Yes" : "No"
                    print("| \(cat) | \(id) | \(name) | `\(ext)` | \(adv) |")
                }
            } else {
                let actions = FormatRegistry.shared.allRegisteredActions()
                print("All Registered Pasta Actions (\(actions.count) total):")
                print("--------------------------------------------------")
                for a in actions {
                    let adv = a.isAdvanced ? " [Advanced]" : ""
                    let ext = a.outputExtension.isEmpty ? "(folder)" : ".\(a.outputExtension)"
                    print("  - \(a.id.padding(toLength: 30, withPad: " ", startingAt: 0)) (\(a.displayName) -> \(ext))\(adv)")
                }
            }
            return
        }

        guard let filePath = args.first(where: { !$0.hasPrefix("-") }) else {
            fputs("Error: Missing file path or flags for list-actions.\nUsage: pasta list-actions <file> | --all [--markdown]\n", stderr)
            exit(1)
        }

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
        var destinationDir: URL?
        var rawParams: [String: String] = [:]
        var files: [String] = []

        var i = 0
        var endOfOptions = false
        while i < args.count {
            let arg = args[i]
            if endOfOptions {
                files.append(arg)
                i += 1
            } else if arg == "--" {
                endOfOptions = true
                i += 1
            } else if arg == "--action" && i + 1 < args.count {
                actionId = args[i + 1]
                i += 2
            } else if (arg == "--dest" || arg == "--destination") && i + 1 < args.count {
                destinationDir = URL(fileURLWithPath: args[i + 1])
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
            } else if !arg.hasPrefix("-") || FileManager.default.fileExists(atPath: arg) {
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
                let output = try JobRunner.shared.runBatch(action: act, inputs: fileURLs, destinationDirectory: destinationDir, parameters: effectiveParams)
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
                let output = try JobRunner.shared.run(action: selectedAction, input: url, destinationDirectory: destinationDir, parameters: effectiveParams)
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

            let safeFilename = url.lastPathComponent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")

            let titleForAction: (ConversionAction) -> String = { "\($0.displayName) (.\($0.outputExtension))" }
            let actionTitles = actions.map { act in
                let escaped = titleForAction(act)
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }.joined(separator: ", ")
            let script = "choose from list {\(actionTitles)} with title \"Pasta\" with prompt \"Choose target format for \(safeFilename):\" without multiple selections allowed"

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

            if let matched = actions.first(where: { titleForAction($0) == chosen || $0.displayName == chosen }) {
                do {
                    let out = try JobRunner.shared.run(action: matched, input: url)
                    showNotification(title: "Pasta Converted", message: "Successfully created \(out.lastPathComponent)")
                } catch {
                    showNotification(title: "Pasta Failed", message: error.localizedDescription)
                }
            }
        }
    }

    public static func makeNotificationRequest(title: String, message: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }

    public static func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        let request = makeNotificationRequest(title: title, message: message)

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                deliverNotification(request, through: center)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        PastaLogger.shared.error("Native notification authorization failed: \(error.localizedDescription)")
                    } else if granted {
                        deliverNotification(request, through: center)
                    } else {
                        PastaLogger.shared.warning("Native notifications are disabled; no notification was delivered")
                    }
                }
            case .denied:
                PastaLogger.shared.warning("Native notifications are disabled; no notification was delivered")
            @unknown default:
                PastaLogger.shared.warning("Native notification authorization has an unknown status; no notification was delivered")
            }
        }
    }

    private static func deliverNotification(_ request: UNNotificationRequest, through center: UNUserNotificationCenter) {
        center.add(request) { error in
            if let error {
                PastaLogger.shared.error("Native notification delivery failed: \(error.localizedDescription)")
            }
        }
    }
}
