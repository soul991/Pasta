import Foundation
import AppKit
import PeelCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dropWindowController: DropWindowViewController!
    private var wheelPanel: RadialWheelOverlayPanel!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 440, height: 520)
        popover.behavior = .transient
        dropWindowController = DropWindowViewController()
        popover.contentViewController = dropWindowController

        // Initialize Radial Wheel Overlay Panel
        wheelPanel = RadialWheelOverlayPanel()

        // Setup DragMonitor
        DragMonitor.shared.onDragStart = { [weak self] files, isOptionHeld, mouseLocation in
            DispatchQueue.main.async {
                self?.wheelPanel.showCenteredAt(point: mouseLocation, files: files, isOptionHeld: isOptionHeld)
            }
        }

        DragMonitor.shared.onDragEnd = { [weak self] in
            DispatchQueue.main.async {
                self?.wheelPanel.dismiss()
            }
        }

        DragMonitor.shared.startMonitoring()

        // Initialize Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Peel") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "Peel"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let currentEvent = NSApp.currentEvent
        if currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Open Drop Window", action: #selector(openDropWindow), keyEquivalent: "o"))
            menu.addItem(NSMenuItem.separator())
            if !DragMonitor.isAccessibilityTrusted() {
                menu.addItem(NSMenuItem(title: "Enable Accessibility Permission...", action: #selector(requestAccessibility), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
            }
            menu.addItem(NSMenuItem(title: "About Peel", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Peel", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    @objc private func openDropWindow() {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func requestAccessibility() {
        _ = DragMonitor.isAccessibilityTrusted(prompt: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Peel File Converter"
        alert.informativeText = "Version 1.0\nA fast, offline macOS file converter with dynamic theme accents."
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
