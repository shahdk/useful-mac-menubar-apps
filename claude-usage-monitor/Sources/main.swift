import Cocoa
import ServiceManagement

// Claude Usage Monitor
// Shows your real Claude Code session usage in the menubar by running
// `claude -p "/usage"` and parsing the official "Current session" line, e.g.:
//
//   Current session: 37% used · resets Jul 29 at 12:59pm (America/Indianapolis)
//
// When the session usage crosses your chosen threshold, the edges of every screen
// pulse gently red. The weekly limit is shown for reference too.

let POLL_INTERVAL: TimeInterval = 300   // /usage changes slowly; poll every 5 min
let CMD_TIMEOUT: TimeInterval = 60
let AI_EMOJI = "🤖"                      // generic AI glyph shown in the menubar

// MARK: - Config

struct Config: Codable {
    var thresholdPercent: Int = 80

    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ClaudeUsageMonitor", isDirectory: true)
    static let url = dir.appendingPathComponent("config.json")

    static func load() -> Config {
        guard let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return cfg
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.dir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(self) { try? data.write(to: Config.url) }
    }
}

// MARK: - Claude CLI runner
//
// The pure parsing of `/usage` output (and the `UsageResult` model) lives in
// UsageParser.swift so it can be unit-tested with Foundation alone — see Tests/.

enum ClaudeCLI {
    // Run through the user's interactive login shell so their real PATH (e.g. the
    // newer ~/.local/bin/claude ahead of an older /opt/homebrew/bin/claude) is used,
    // even when launched as a .app with a minimal environment.
    static func fetchUsage() -> UsageResult {
        let (out, timedOut, launched) = runLoginShell("claude -p '/usage'", timeout: CMD_TIMEOUT)

        if !launched {
            return UsageResult(error: "Could not launch a shell to run Claude.")
        }
        if timedOut {
            return UsageResult(error: "Timed out running `claude -p /usage`.")
        }
        return UsageParser.parse(output: out)
    }

    // The account's configured login shell (independent of the process environment),
    // falling back to common shells. Handles machines without zsh.
    private static func loginShell() -> String {
        if let pw = getpwuid(getuid()), let shPtr = pw.pointee.pw_shell {
            let path = String(cString: shPtr)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        for candidate in ["/bin/zsh", "/bin/bash", "/bin/sh"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return "/bin/sh"
    }

    private static func runLoginShell(_ command: String, timeout: TimeInterval)
        -> (out: String, timedOut: Bool, launched: Bool) {
        let shell = loginShell()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        // Interactive + login so the user's rc files (which set PATH ordering) are sourced.
        process.arguments = shell.hasSuffix("/sh") ? ["-lc", command] : ["-ilc", command]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let sem = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sem.signal() }
        do { try process.run() } catch { return ("", false, false) }

        var timedOut = false
        if sem.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            _ = sem.wait(timeout: .now() + 5)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "", timedOut, true)
    }
}

// MARK: - Edge flash overlay

final class EdgeFlashView: NSView {
    var thickness: CGFloat = 90
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let strong = NSColor.systemRed.withAlphaComponent(0.9).cgColor
        let clear = NSColor.systemRed.withAlphaComponent(0.0).cgColor
        let space = CGColorSpaceCreateDeviceRGB()
        guard let grad = CGGradient(colorsSpace: space, colors: [strong, clear] as CFArray,
                                    locations: [0.0, 1.0]) else { return }
        let b = bounds
        ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: b.height - thickness, width: b.width, height: thickness))
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: b.height), end: CGPoint(x: 0, y: b.height - thickness), options: [])
        ctx.restoreGState()
        ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: b.width, height: thickness))
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: thickness), options: [])
        ctx.restoreGState()
        ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: thickness, height: b.height))
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: thickness, y: 0), options: [])
        ctx.restoreGState()
        ctx.saveGState(); ctx.clip(to: CGRect(x: b.width - thickness, y: 0, width: thickness, height: b.height))
        ctx.drawLinearGradient(grad, start: CGPoint(x: b.width, y: 0), end: CGPoint(x: b.width - thickness, y: 0), options: [])
        ctx.restoreGState()
    }
}

final class EdgeFlashController {
    private var windows: [NSWindow] = []
    private var pulsing = false

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        for screen in NSScreen.screens {
            let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.ignoresMouseEvents = true
            win.level = .screenSaver
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.hasShadow = false
            win.setFrame(screen.frame, display: true)
            let view = EdgeFlashView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            win.contentView = view
            win.alphaValue = 0.0
            windows.append(win)
        }
    }

    func setActive(_ active: Bool) {
        if active {
            guard !pulsing else { return }
            pulsing = true
            rebuildWindows()
            windows.forEach { $0.orderFrontRegardless() }
            pulse(up: true)
        } else {
            guard pulsing else { return }
            pulsing = false
            windows.forEach { $0.orderOut(nil) }
        }
    }

    private func pulse(up: Bool) {
        guard pulsing else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 1.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let target: CGFloat = up ? 0.55 : 0.12
            windows.forEach { $0.animator().alphaValue = target }
        }, completionHandler: { [weak self] in self?.pulse(up: !up) })
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config = Config.load()
    private var timer: Timer?
    private let flash = EdgeFlashController()

    private var usage = UsageResult(error: "Loading…")
    private var lastUpdated: Date?
    private var isRefreshing = false
    private var flashAcknowledged = false   // in-memory ack; resets when usage drops back under
    private let thresholdPresets = [50, 60, 70, 75, 80, 85, 90, 95]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = .systemFont(ofSize: 13, weight: .medium)
        render()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: POLL_INTERVAL, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Refresh

    @objc private func refresh() {
        isRefreshing = true
        render()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = ClaudeCLI.fetchUsage()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.usage = result
                self.lastUpdated = Date()
                self.isRefreshing = false
                self.render()
            }
        }
    }

    private func render() {
        updateTitle()
        let over = (usage.sessionPercent ?? -1) >= config.thresholdPercent
        if !over { flashAcknowledged = false }   // back under → re-arm for the next crossing
        flash.setActive(over && !flashAcknowledged)
        statusItem.menu = buildMenu()
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        button.image = nil
        if let pct = usage.sessionPercent {
            // White normally; red once the threshold is hit. (The emoji keeps its
            // own colors — only the percentage text takes the tint.)
            let tint: NSColor = pct >= config.thresholdPercent ? .systemRed : .white
            button.attributedTitle = Self.title("\(AI_EMOJI) \(pct)%", color: tint)
            var tip = "Claude session: \(pct)% used"
            if let r = usage.sessionReset { tip += " · resets \(r)" }
            if let w = usage.weekPercent { tip += "\nWeek: \(w)% used" }
            button.toolTip = tip
        } else {
            button.attributedTitle = Self.title("\(AI_EMOJI) ⚠", color: .systemYellow)
            button.toolTip = usage.error ?? "Claude usage unavailable"
        }
    }

    /// The menubar text, colored explicitly (status-item titles don't reliably
    /// follow contentTintColor, so we set the foreground color directly).
    private static func title(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        ])
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let over = (usage.sessionPercent ?? -1) >= config.thresholdPercent
        if over && !flashAcknowledged {
            let ack = NSMenuItem(title: "⚠︎ Over threshold — dismiss flashing",
                                 action: #selector(dismissFlash), keyEquivalent: "")
            ack.target = self
            menu.addItem(ack)
            menu.addItem(.separator())
        }

        if let pct = usage.sessionPercent {
            let s = NSMenuItem(title: "Session: \(pct)% used" + (usage.sessionReset.map { " · resets \($0)" } ?? ""),
                               action: nil, keyEquivalent: "")
            s.isEnabled = false
            menu.addItem(s)
            if let w = usage.weekPercent {
                let wk = NSMenuItem(title: "Week: \(w)% used" + (usage.weekReset.map { " · resets \($0)" } ?? ""),
                                    action: nil, keyEquivalent: "")
                wk.isEnabled = false
                menu.addItem(wk)
            }
        } else {
            let err = NSMenuItem(title: usage.error ?? "Usage unavailable",
                                 action: #selector(showHelp), keyEquivalent: "")
            err.target = self
            menu.addItem(err)
        }

        let status = NSMenuItem(title: refreshStatus(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let thresholdMenu = NSMenu()
        for p in thresholdPresets {
            let item = NSMenuItem(title: "\(p)%", action: #selector(setThreshold(_:)), keyEquivalent: "")
            item.target = self; item.tag = p
            item.state = (p == config.thresholdPercent) ? .on : .off
            thresholdMenu.addItem(item)
        }
        let thresholdParent = NSMenuItem(title: "Alert threshold: \(config.thresholdPercent)%", action: nil, keyEquivalent: "")
        thresholdParent.submenu = thresholdMenu
        menu.addItem(thresholdParent)


        let refreshItem = NSMenuItem(title: "Refresh now", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let help = NSMenuItem(title: "Setup / Help…", action: #selector(showHelp), keyEquivalent: "")
        help.target = self
        menu.addItem(help)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func refreshStatus() -> String {
        let every = "refreshes every \(Int(POLL_INTERVAL / 60)) min"
        if isRefreshing { return "Refreshing…" }
        guard let t = lastUpdated else { return "Updating… · \(every)" }
        let secs = Int(Date().timeIntervalSince(t))
        let ago: String
        if secs < 5 { ago = "just now" }
        else if secs < 60 { ago = "\(secs)s ago" }
        else { ago = "\(secs / 60)m ago" }
        return "Updated \(ago) · \(every)"
    }

    @objc private func setThreshold(_ sender: NSMenuItem) {
        config.thresholdPercent = sender.tag
        config.save()
        render()
    }

    @objc private func dismissFlash() {
        flashAcknowledged = true
        render()
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Claude Usage Monitor"
        alert.informativeText = """
        This app runs `claude -p "/usage"` and shows your Claude Code session usage.

        If it can't read usage, make sure the Claude CLI is installed, up to date, and logged in:

          • Install:  npm install -g @anthropic-ai/claude-code
            (or see https://docs.claude.com/claude-code)
          • Update:   run `claude update` (older versions omit the session line)
          • Log in:   run `claude` in Terminal and follow the sign-in prompts
          • Verify:   `claude -p "/usage"` prints a "Current session:" line

        Tip: if you have more than one `claude` on your PATH, this app uses the
        one your Terminal uses (`command -v claude`).

        Usage refreshes every 5 minutes (and via "Refresh now").
        """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch { NSLog("Login item toggle failed: \(error)") }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
