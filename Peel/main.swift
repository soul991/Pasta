import Foundation
import AppKit
import PeelCore

if CommandLine.arguments.count > 1 {
    PeelCLI.run(arguments: CommandLine.arguments)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
