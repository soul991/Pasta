import Foundation

public struct PeelCLI {
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
                fputs("Error: Missing file path for list-actions.\nUsage: peel list-actions <file>\n", stderr)
                exit(1)
            }
            runListActions(filePath: args[1])
        case "convert":
            runConvert(args: Array(args.dropFirst()))
        case "--help", "-h", "help":
            printUsage()
            exit(0)
        default:
            fputs("Error: Unknown command '\(command)'. Run 'peel help' for usage.\n", stderr)
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        Peel - Offline macOS File Converter
        Usage:
          peel convert --action <action_id> <file>...
          peel convert <file> --to <format>
          peel list-actions <file>
          peel doctor
          peel help
        """)
    }

    private static func runDoctor() {
        let tools = [
            "ffmpeg", "cwebp", "magick", "gs", "qpdf", "pdftoppm",
            "pdftotext", "exiftool", "pandoc", "rsvg-convert", "unar",
            "7zz", "sips", "ditto", "tar"
        ]

        print("Peel Environment & Engine Doctor:")
        print("--------------------------------------------------")
        var allOk = true
        for tool in tools {
            if let url = ToolLocator.shared.findTool(tool) {
                print("  [OK]      \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) -> \(url.path)")
            } else {
                print("  [MISSING] \(tool.padding(toLength: 14, withPad: " ", startingAt: 0)) (NOT FOUND)")
                allOk = false
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
            print("  - \(a.id.padding(toLength: 30, withPad: " ", startingAt: 0)) (\(a.displayName) -> .\(a.outputExtension))")
        }
        print("\nAdvanced Actions:")
        for a in advanced {
            print("  - \(a.id.padding(toLength: 30, withPad: " ", startingAt: 0)) (\(a.displayName) -> .\(a.outputExtension))")
        }
    }

    private static func runConvert(args: [String]) {
        var actionId: String?
        var targetFormat: String?
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
            } else if !arg.hasPrefix("-") {
                files.append(arg)
                i += 1
            } else {
                i += 1
            }
        }

        guard !files.isEmpty else {
            fputs("Error: No input files specified.\nUsage: peel convert --action <action_id> <file>...\n", stderr)
            exit(1)
        }

        var anyFailed = false

        for file in files {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                fputs("Error: File does not exist at '\(file)'\n", stderr)
                anyFailed = true
                continue
            }

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

            do {
                let output = try JobRunner.shared.run(action: selectedAction, input: url)
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
}
