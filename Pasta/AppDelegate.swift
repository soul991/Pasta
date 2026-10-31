import Foundation
import AppKit
import PastaCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dropWindowController: DropWindowViewController!
    private var wheelPanel: RadialWheelOverlayPanel!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: AccessibilityOnboardingWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize Native NSPopover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 440, height: 520)
        popover.behavior = .transient
        dropWindowController = DropWindowViewController()
        popover.contentViewController = dropWindowController

        // Initialize Radial Wheel Overlay Panel
        wheelPanel = RadialWheelOverlayPanel()

        // Setup DragMonitor with Shift-Hold state machine & Charging Ring
        DragMonitor.shared.onChargingProgress = { progress, location in
            DispatchQueue.main.async {
                ChargingProgressRingPanel.shared.show(at: location, progress: progress)
            }
        }

        DragMonitor.shared.onChargingCancel = {
            DispatchQueue.main.async {
                ChargingProgressRingPanel.shared.dismiss()
            }
        }

        DragMonitor.shared.onWheelOpen = { [weak self] files, isAdvanced, mouseLocation in
            DispatchQueue.main.async {
                ChargingProgressRingPanel.shared.dismiss()
                self?.wheelPanel.showCenteredAt(point: mouseLocation, files: files, isOptionHeld: isAdvanced)
            }
        }

        DragMonitor.shared.onWheelClose = { [weak self] in
            DispatchQueue.main.async {
                ChargingProgressRingPanel.shared.dismiss()
                self?.wheelPanel.dismiss()
            }
        }

        DragMonitor.shared.onModeToggle = { [weak self] isAdvanced in
            DispatchQueue.main.async {
                self?.wheelPanel.toggleMode(isAdvanced: isAdvanced)
            }
        }

        DragMonitor.shared.onFilesReplaced = { [weak self] newFiles in
            DispatchQueue.main.async {
                self?.wheelPanel.configure(files: newFiles)
            }
        }

        DragMonitor.shared.startMonitoring()

        // Initialize Status Item with Rigatoni silhouette icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let customIcon = BrandAssetManager.loadMenuBarIcon(size: NSSize(width: 18, height: 18)) {
                customIcon.isTemplate = true
                button.image = customIcon
            } else if let img = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Pasta") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "Pasta"
            }

            let verification = BrandAssetManager.verifyStatusItemImage(button: button)
            PastaLogger.shared.log("StatusItem verification: set=\(verification.isSet), template=\(verification.isTemplate), size=\(verification.size.width)x\(verification.size.height) - \(verification.logReason)")

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
            if DragMonitor.shared.isWheelOpen {
                menu.addItem(NSMenuItem(title: "Hide Wheel", action: #selector(hideWheel), keyEquivalent: "w"))
            } else {
                menu.addItem(NSMenuItem(title: "Show Wheel", action: #selector(showWheel), keyEquivalent: "w"))
            }
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            if !DragMonitor.isAccessibilityTrusted() {
                menu.addItem(NSMenuItem(title: "Enable Accessibility Permission...", action: #selector(requestAccessibility), keyEquivalent: ""))
                menu.addItem(NSMenuItem.separator())
            }
            menu.addItem(NSMenuItem(title: "About Pasta", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Pasta", action: #selector(quitApp), keyEquivalent: "q"))
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

    @objc private func hideWheel() {
        DragMonitor.shared.closeWheel(reason: "User selected Hide Wheel from menu bar")
    }

    @objc private func showWheel() {
        DragMonitor.shared.openWheelManually()
    }

    @objc private func requestAccessibility() {
        let trusted = DragMonitor.isAccessibilityTrusted(prompt: false)
        if !trusted {
            if onboardingWindowController == nil {
                onboardingWindowController = AccessibilityOnboardingWindowController()
            }
            onboardingWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Pasta File Converter"
        alert.informativeText = "Version 1.0\nA fast, offline macOS file converter with dynamic radial wheel."
        alert.alertStyle = .informational
        if let appIcon = BrandAssetManager.loadAppIcon(size: NSSize(width: 64, height: 64)) {
            alert.icon = appIcon
        }
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
