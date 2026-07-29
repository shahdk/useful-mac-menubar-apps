import Cocoa
import ServiceManagement

// Caffeinate Toggle
// A menubar app that toggles `caffeinate -ds` (prevents display + system sleep)
// and terminates the process when toggled off.
//
// - Left-click the menubar icon: toggle keep-awake on/off
// - Right-click (or control-click): open the menu (Start at Login / Quit)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var loginItem: NSMenuItem!
    private var caffeinateTask: Process?

    private var isActive: Bool { caffeinateTask?.isRunning ?? false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Caffeinate Toggle"
        }
        buildMenu()
        updateIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopCaffeinate()
    }

    // MARK: - Menu

    private func buildMenu() {
        menu = NSMenu()

        let hint = NSMenuItem(title: "Left-click icon to toggle keep-awake", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        refreshLoginState()
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            // Temporarily attach the menu so it pops up, then detach so left-click keeps toggling.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    private func toggle() {
        if isActive {
            stopCaffeinate()
        } else {
            startCaffeinate()
        }
        updateIcon()
    }

    // MARK: - caffeinate process

    private func startCaffeinate() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-ds"] // -d: no display sleep, -s: no system sleep (on AC)
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.updateIcon() }
        }
        do {
            try task.run()
            caffeinateTask = task
        } catch {
            caffeinateTask = nil
            let alert = NSAlert()
            alert.messageText = "Could not start caffeinate"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func stopCaffeinate() {
        caffeinateTask?.terminate()
        caffeinateTask = nil
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        if isActive {
            // ON: the same cup, tinted neon green. The color alone signals
            // "keep-awake is on", so there's no "ON" text.
            let green = NSColor(srgbRed: 0.20, green: 1.0, blue: 0.42, alpha: 1.0)
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [green]))
            if let image = NSImage(systemSymbolName: "cup.and.saucer.fill",
                                   accessibilityDescription: "Keep awake: ON")?
                .withSymbolConfiguration(cfg) {
                image.isTemplate = false // keep the green color
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = "☕︎"
            }
            button.attributedTitle = NSAttributedString(string: "")
            button.contentTintColor = nil
            button.toolTip = "Keep-awake is ON (caffeinate -ds) — click to turn off"
        } else {
            // OFF: a plain monochrome outline cup, no label — reads as inactive.
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let image = NSImage(systemSymbolName: "cup.and.saucer",
                                   accessibilityDescription: "Keep awake: OFF")?
                .withSymbolConfiguration(cfg) {
                image.isTemplate = true // adapts to the menubar (light/dark)
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = "○"
            }
            button.attributedTitle = NSAttributedString(string: "")
            button.contentTintColor = nil
            button.toolTip = "Keep-awake is OFF — click to keep your Mac awake"
        }
    }

    // MARK: - Login item

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Login item toggle failed: \(error)")
        }
        refreshLoginState()
    }

    private func refreshLoginState() {
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon
app.run()
