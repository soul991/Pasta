import Foundation
import AppKit
import PastaCore

if CommandLine.arguments.count > 1 {
    PastaCLI.run(arguments: CommandLine.arguments)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
