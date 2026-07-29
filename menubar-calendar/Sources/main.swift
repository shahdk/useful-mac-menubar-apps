import Cocoa
import ServiceManagement

// Menubar Calendar
// - Menubar icon shows today's day-of-month number (e.g. "29" on July 29)
// - Clicking opens a popover with a month calendar, today highlighted,
//   the full weekday/date at the top, and prev/next month navigation.

// MARK: - Vertically-centered label

/// NSTextField normally top-aligns its single line of text. This cell centers
/// the text vertically so a day number sits in the middle of its (circular) cell.
private final class VCenterTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var r = super.titleRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        r.origin.y = rect.origin.y + (rect.height - textHeight) / 2
        r.size.height = textHeight
        return r
    }
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }
}

private final class DayCell: NSTextField {
    init() {
        super.init(frame: .zero)
        let c = VCenterTextFieldCell(textCell: "")
        c.isBordered = false
        c.drawsBackground = false
        c.alignment = .center
        cell = c
        isEditable = false
        isSelectable = false
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Calendar grid view

final class CalendarView: NSView {
    private let calendar = Calendar.current
    private var displayedMonth: Date = Date()
    private let today = Date()

    private let dateLabel = NSTextField(labelWithString: "")
    private let monthPopup = NSPopUpButton()
    private let yearPopup = NSPopUpButton()
    private var dayCells: [DayCell] = []
    private var highlightViews: [NSView] = []

    private let cellSize: CGFloat = 34
    private let padding: CGFloat = 14

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let width = padding * 2 + cellSize * 7
        let height: CGFloat = 336
        self.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Full weekday + date at top
        dateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateLabel.textColor = .secondaryLabelColor
        dateLabel.alignment = .center
        dateLabel.frame = NSRect(x: padding, y: height - 34, width: cellSize * 7, height: 18)
        addSubview(dateLabel)

        // Month + year dropdowns, with prev/next chevrons on the sides
        let navY = height - 68
        monthPopup.frame = NSRect(x: padding + cellSize, y: navY, width: cellSize * 3, height: 26)
        monthPopup.target = self
        monthPopup.action = #selector(monthYearChanged)
        for m in calendar.monthSymbols { monthPopup.addItem(withTitle: m) }
        addSubview(monthPopup)

        yearPopup.frame = NSRect(x: padding + cellSize * 4, y: navY, width: cellSize * 2, height: 26)
        yearPopup.target = self
        yearPopup.action = #selector(monthYearChanged)
        populateYears(around: calendar.component(.year, from: today))
        addSubview(yearPopup)

        let prev = makeNavButton("chevron.left", action: #selector(prevMonth))
        prev.frame = NSRect(x: padding, y: navY, width: cellSize, height: 26)
        addSubview(prev)

        let next = makeNavButton("chevron.right", action: #selector(nextMonth))
        next.frame = NSRect(x: padding + cellSize * 6, y: navY, width: cellSize, height: 26)
        addSubview(next)

        // Weekday header row (Su Mo Tu We Th Fr Sa, respecting locale first weekday)
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday // 1 = Sunday
        for i in 0..<7 {
            let idx = (firstWeekday - 1 + i) % 7
            let lbl = NSTextField(labelWithString: symbols[idx].uppercased())
            lbl.font = .systemFont(ofSize: 10, weight: .semibold)
            lbl.textColor = .tertiaryLabelColor
            lbl.alignment = .center
            lbl.frame = NSRect(x: padding + CGFloat(i) * cellSize, y: height - 96, width: cellSize, height: 16)
            addSubview(lbl)
        }

        // 6 rows x 7 cols of day cells (extra gap below the weekday header).
        // Each cell has a circular highlight view behind a vertically-centered
        // number, so the highlight is a clean circle centered on the digit.
        let gridTop = height - 132
        let hlDiameter = cellSize - 6
        for row in 0..<6 {
            for col in 0..<7 {
                let x = padding + CGFloat(col) * cellSize
                let y = gridTop - CGFloat(row) * cellSize

                let hl = NSView(frame: NSRect(x: x + (cellSize - hlDiameter) / 2,
                                              y: y + (cellSize - hlDiameter) / 2,
                                              width: hlDiameter, height: hlDiameter))
                hl.wantsLayer = true
                hl.layer?.cornerRadius = hlDiameter / 2
                highlightViews.append(hl)
                addSubview(hl)

                let cell = DayCell()
                cell.font = .systemFont(ofSize: 13)
                cell.frame = NSRect(x: x, y: y, width: cellSize, height: cellSize)
                dayCells.append(cell)
                addSubview(cell)
            }
        }

        // "Today" button at the bottom
        let todayBtn = NSButton(title: "Today", target: self, action: #selector(goToday))
        todayBtn.bezelStyle = .rounded
        todayBtn.controlSize = .small
        todayBtn.frame = NSRect(x: (width - 70) / 2, y: 10, width: 70, height: 22)
        addSubview(todayBtn)

        render()
    }

    private func makeNavButton(_ symbol: String, action: Selector) -> NSButton {
        let btn = NSButton(title: "", target: self, action: action)
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        btn.imagePosition = .imageOnly
        return btn
    }

    @objc private func prevMonth() { changeMonth(by: -1) }
    @objc private func nextMonth() { changeMonth(by: 1) }
    @objc private func goToday() { displayedMonth = Date(); render() }

    @objc private func monthYearChanged() {
        let month = monthPopup.indexOfSelectedItem + 1
        let year = Int(yearPopup.titleOfSelectedItem ?? "") ?? calendar.component(.year, from: today)
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        if let d = calendar.date(from: comps) {
            displayedMonth = d
            render()
        }
    }

    private func populateYears(around year: Int) {
        yearPopup.removeAllItems()
        for y in (year - 10)...(year + 10) {
            yearPopup.addItem(withTitle: "\(y)")
        }
    }

    private func changeMonth(by delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = d
            render()
        }
    }

    func resetToToday() { displayedMonth = Date(); render() }

    private func render() {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE, MMMM d, yyyy"
        dateLabel.stringValue = dateFmt.string(from: today)

        // First day of displayed month
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)

        // Sync the month/year dropdowns to the displayed month
        if let month = comps.month { monthPopup.selectItem(at: month - 1) }
        if let year = comps.year {
            if yearPopup.item(withTitle: "\(year)") == nil {
                populateYears(around: year)
            }
            yearPopup.selectItem(withTitle: "\(year)")
        }
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return }
        let daysInMonth = range.count

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) // 1..7
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)

        for (i, cell) in dayCells.enumerated() {
            let dayNumber = i - leading + 1
            let hl = highlightViews[i]
            hl.layer?.backgroundColor = NSColor.clear.cgColor
            if dayNumber < 1 || dayNumber > daysInMonth {
                cell.stringValue = ""
            } else {
                cell.stringValue = "\(dayNumber)"
                let isToday = (todayComps.year == comps.year &&
                               todayComps.month == comps.month &&
                               todayComps.day == dayNumber)
                if isToday {
                    hl.layer?.backgroundColor = NSColor.systemRed.cgColor
                    cell.textColor = .white
                    cell.font = .systemFont(ofSize: 13, weight: .semibold)
                } else {
                    cell.textColor = .labelColor
                    cell.font = .systemFont(ofSize: 13)
                }
            }
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var calendarView: CalendarView!
    private var midnightTimer: Timer?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        calendarView = CalendarView()
        let vc = NSViewController()
        vc.view = calendarView
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.contentSize = calendarView.frame.size

        updateTitle()
        scheduleMidnightRefresh()

        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged),
                                               name: .NSCalendarDayChanged, object: nil)
    }

    private func updateTitle() {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        let day = fmt.string(from: Date())
        if let button = statusItem.button {
            button.image = Self.calendarIcon(day: day)
            button.imagePosition = .imageOnly
            button.title = ""
        }
        let full = DateFormatter()
        full.dateFormat = "EEEE, MMMM d"
        statusItem.button?.toolTip = full.string(from: Date())
    }

    /// A small template calendar glyph with today's date drawn inside it,
    /// so the menubar shows a recognizable calendar page (not a bare number).
    private static func calendarIcon(day: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let ink = NSColor.black
            ink.setStroke()
            ink.setFill()

            // Calendar page
            let page = NSRect(x: 1, y: 1, width: 16, height: 14)
            let pagePath = NSBezierPath(roundedRect: page, xRadius: 2.5, yRadius: 2.5)
            pagePath.lineWidth = 1.3
            pagePath.stroke()

            // Header divider line
            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: 2, y: 11.5))
            divider.line(to: NSPoint(x: 16, y: 11.5))
            divider.lineWidth = 1.2
            divider.stroke()

            // Two hanger tabs straddling the top edge
            for x in [5.4, 11.0] as [CGFloat] {
                let tab = NSBezierPath(roundedRect: NSRect(x: x, y: 13.4, width: 1.7, height: 3.4),
                                       xRadius: 0.8, yRadius: 0.8)
                tab.fill()
            }

            // Day number, centered in the body below the divider
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let fontSize: CGFloat = day.count > 1 ? 8.5 : 9.5
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: ink,
                .paragraphStyle: para,
            ]
            let ns = day as NSString
            let textSize = ns.size(withAttributes: attrs)
            let body = NSRect(x: 1, y: 1, width: 16, height: 10.5) // below the divider
            let drawRect = NSRect(x: body.minX,
                                  y: body.midY - textSize.height / 2,
                                  width: body.width,
                                  height: textSize.height)
            ns.draw(in: drawRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = true // adopt the menubar's light/dark tint
        return image
    }

    @objc private func dayChanged() {
        DispatchQueue.main.async {
            self.updateTitle()
            self.calendarView.resetToToday()
        }
    }

    private func scheduleMidnightRefresh() {
        // Hourly tick as a safety net in case the day-changed notification is missed.
        midnightTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updateTitle()
            calendarView.resetToToday()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

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
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
