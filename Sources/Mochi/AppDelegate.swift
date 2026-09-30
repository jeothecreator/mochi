import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) weak var shared: AppDelegate?

    let prefs = Prefs.shared
    let life = PetLife.shared
    private(set) var pet: PetController!
    private(set) var director: Director!
    private(set) var home: HomeController!
    private(set) var quick: PetPopover!
    private(set) var game: PetPopover!
    private var menuBarTimer: Timer?
    private var statusItem: NSStatusItem!
    private var statusMenu = NSMenu()
    private var settingsWindow: NSWindow?
    private let settingsNav = SettingsNav()
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        // Menu-bar only by default; MOCHI_SHOW_IN_DOCK=1 is handy for UI-testing tools.
        NSApp.setActivationPolicy(ProcessInfo.processInfo.environment["MOCHI_SHOW_IN_DOCK"] == "1" ? .regular : .accessory)
        buildMainMenu()

        pet = PetController()
        director = Director(pet: pet)
        home = HomeController(pet: pet, director: director)
        quick = PetPopover(pet: pet, width: QuickTodoView.width, title: "Quick to-do")
        quick.setContent(QuickTodoView(director: director,
                                       openList: { [weak self] in self?.quick.hide(); self?.openHome(tab: .todo) },
                                       close: { [weak self] in self?.quick.hide() }))
        game = PetPopover(pet: pet, width: RPSView.width, title: "Rock, paper, scissors")
        quick.onShow = { [weak self] in self?.game.hide() }
        game.onShow = { [weak self] in self?.quick.hide() }
        pet.onClick = { [weak self] in
            guard let self else { return }
            _ = self.director.clicked()
            self.quick.toggle()
        }
        pet.onMenu = { [weak self] e in self?.showPetMenu(e) }
        pet.onDropHover = { [weak self] inside in self?.director.dropHover(inside) }
        pet.onDrop = { [weak self] pb in self?.director.handleDrop(pb) ?? false }
        pet.onMoved = { [weak self] in
            self?.home.followPet()
            self?.quick.follow()
            self?.game.follow()
            self?.director.petMoved()
        }

        setupStatusItem()
        director.focus.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarTimer() }
            .store(in: &cancellables)

        HotKeyManager.shared.onFire = { [weak self] in self?.hotKeyPressed() }
        prefs.$hotKey.combineLatest(prefs.$hotKeyEnabled)
            .sink { combo, enabled in HotKeyManager.shared.configure(combo: combo, enabled: enabled) }
            .store(in: &cancellables)

        prefs.$petVisible
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in if !visible { self?.home.hide(); self?.quick.hide(); self?.game.hide() } }
            .store(in: &cancellables)

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pet.ensureOnScreen()
            self?.pet.syncCopies()
            self?.home.followPet()
        }
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pet.ensureOnScreen()
            self?.pet.render(force: true)
        }
        wnc.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pet.render(force: true)
        }

        pet.syncVisibility()
        if prefs.onboardedV2 {
            director.start()
        } else {
            showOnboarding()
        }
        pendingURLs.forEach { director.handle(url: $0) }
        pendingURLs = []
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let director else { pendingURLs += urls; return }
        urls.forEach { director.handle(url: $0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPet()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        pet?.savePosition()
        life.s.lastSeen = Date()
        life.saveNow()
    }

    // MARK: Actions

    @objc func showPet() {
        prefs.petVisible = true
        pet.ensureOnScreen()
    }

    @objc func hidePet() {
        home.hide()
        quick.hide()
        game.hide()
        prefs.petVisible = false
    }

    @objc func togglePet() { prefs.petVisible ? hidePet() : showPet() }

    @objc func openTodoList() { openHome(tab: .todo) }
    @objc func openWants() { openHome(tab: .wants) }
    @objc func openCloset() { openHome(tab: .closet) }
    @objc func openScrapbook() { openSettings(.scrapbook) }
    @objc func quickAdd() {
        showPet()
        DispatchQueue.main.async { self.quick.show() }
    }

    func openHome(tab: HomeTab? = nil) {
        showPet()
        DispatchQueue.main.async { self.home.show(tab: tab) }
    }

    @objc func headPats() { showPet(); director.pat() }
    @objc func play() { showPet(); director.play() }
    @objc func playRPS() {
        showPet()
        game.setContent(RPSView(director: director, close: { [weak self] in self?.game.hide() }))
        DispatchQueue.main.async { self.game.show() }
    }
    @objc func openShop() { openHome(tab: .shop) }
    @objc func startFocusMenu(_ sender: NSMenuItem) { showPet(); director.startFocus(minutes: sender.tag) }
    @objc func stopFocus() { director.stopFocus() }
    @objc func skipBreak() { director.skipBreak() }
    @objc func nap() { director.nap() }
    @objc func wake() { pet.brain.wake(); pet.perform(.surprised) }
    @objc func giveFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let item = Souvenir(rawValue: raw) else { return }
        showPet()
        director.give(item)
    }
    @objc func feedFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let food = Food(rawValue: raw) else { return }
        showPet()
        _ = director.feed(food)
    }

    @objc func resetPosition() {
        showPet()
        pet.resetPosition()
    }

    @objc func openSettingsMenu() { openSettings(.creature) }

    func openSettings(_ page: SettingsPage) {
        settingsNav.page = page
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsRoot(nav: settingsNav))
            w.center()
            w.setFrameAutosaveName("MochiSettings")
            settingsWindow = w
        }
        settingsWindow?.title = "\(prefs.petName) Settings"
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showOnboarding() {
        if let w = onboardingWindow {
            NSApp.activate(); w.makeKeyAndOrderFront(nil); return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        // Match the window (traffic lights, title bar) to the chosen vibe, live.
        let applyAppearance = { [weak w] in w?.appearance = NSAppearance(named: Prefs.shared.uiTheme.isDark ? .darkAqua : .aqua) }
        applyAppearance()
        prefs.$uiTheme.receive(on: RunLoop.main).sink { _ in applyAppearance() }.store(in: &cancellables)
        w.title = "Welcome"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView { [weak self] in
            guard let self else { return }
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.showPet()
            self.pet.perform(.love)
            self.director.start()
        })
        w.center()
        onboardingWindow = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
    }

    private func hotKeyPressed() {
        switch prefs.hotKeyAction {
        case .togglePet:
            togglePet()
        case .toggleChat:
            if quick.isVisible && quick.panel.isKeyWindow { quick.hide() } else { quickAdd() }
        }
    }

    // MARK: Menus

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Mochi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Needed so ⌘C / ⌘V / ⌘A work in text fields of this menu-bar-only app.
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = main
    }

    /// Shows "🍅 24:59" next to the menu bar icon while a focus session or break is running.
    private func updateMenuBarTimer() {
        let running = director.focus.isRunning
        statusItem.length = running ? NSStatusItem.variableLength : NSStatusItem.squareLength
        if running {
            if menuBarTimer == nil {
                let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshMenuBarTitle() }
                RunLoop.main.add(t, forMode: .common)
                menuBarTimer = t
            }
            refreshMenuBarTitle()
        } else {
            menuBarTimer?.invalidate()
            menuBarTimer = nil
            statusItem.button?.title = ""
        }
    }

    private func refreshMenuBarTitle() {
        let f = director.focus
        guard f.isRunning else { return }
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = " \(f.phase == .focus ? "🍅" : "☕") \(f.remainingLabel)"
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.setAccessibilityLabel("Mochi")
        statusMenu.delegate = self
        statusItem.menu = statusMenu
    }

    private func feedMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Feed", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for food in Food.allCases {
            let f = NSMenuItem(title: "\(food.label)  —  \(food.cost == 0 ? "free" : "\(food.cost) 🪙")", action: #selector(feedFromMenu(_:)), keyEquivalent: "")
            f.representedObject = food.rawValue
            f.target = self
            let img = food.icon.nsImage
            img.size = NSSize(width: 16, height: 16)
            f.image = img
            sub.addItem(f)
        }
        item.submenu = sub
        return item
    }

    private func focusMenu() -> NSMenuItem {
        let f = director.focus
        let title = f.phase == .focus ? "Focus — \(f.remainingLabel) left" : (f.phase == .rest ? "Break — \(f.remainingLabel) left" : "Focus")
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = { let i = PixelIcon.tomato.nsImage; i.size = NSSize(width: 16, height: 16); return i }()
        let sub = NSMenu()
        if f.phase == .focus {
            sub.addItem(target(NSMenuItem(title: "Stop focus", action: #selector(stopFocus), keyEquivalent: "")))
        } else if f.phase == .rest {
            sub.addItem(target(NSMenuItem(title: "Skip break", action: #selector(skipBreak), keyEquivalent: "")))
        }
        if f.phase != .focus {
            for m in Array(Set([prefs.focusMinutes, 15, 25, 50])).sorted() {
                let i = NSMenuItem(title: "Start \(m)-min focus\(m == prefs.focusMinutes ? "  (default)" : "")", action: #selector(startFocusMenu(_:)), keyEquivalent: "")
                i.tag = m
                sub.addItem(target(i))
            }
        }
        sub.addItem(.separator())
        let stats = NSMenuItem(title: "\(life.s.focusSessions) sessions · \(life.s.focusMinutesTotal) min focused", action: nil, keyEquivalent: "")
        stats.isEnabled = false
        sub.addItem(stats)
        item.submenu = sub
        return item
    }

    private func playMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Play", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(target(NSMenuItem(title: "Zoomies!", action: #selector(play), keyEquivalent: "")))
        sub.addItem(target(NSMenuItem(title: "Rock, Paper, Scissors…", action: #selector(playRPS), keyEquivalent: "")))
        item.submenu = sub
        return item
    }

    private func target(_ i: NSMenuItem) -> NSMenuItem { i.target = self; return i }

    private func giveMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Give", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let owned = Souvenir.allCases.filter { (life.s.inventory[$0] ?? 0) > 0 }
        if owned.isEmpty {
            let none = NSMenuItem(title: "No treasures yet — they come from exploring & events", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        for souvenir in owned {
            let g = NSMenuItem(title: "\(souvenir.label)  ×\(life.s.inventory[souvenir] ?? 0)", action: #selector(giveFromMenu(_:)), keyEquivalent: "")
            g.representedObject = souvenir.rawValue
            g.target = self
            let img = souvenir.icon.nsImage
            img.size = NSSize(width: 16, height: 16)
            g.image = img
            sub.addItem(g)
        }
        item.submenu = sub
        return item
    }

    /// Disabled header line showing how the pet is doing.
    private func statsItem() -> NSMenuItem {
        let s = life.s
        let item = NSMenuItem(title: "♥ \(Int(s.happiness))   🍙 \(Int(s.hunger))   ⚡ \(Int(s.energy))   🪙 \(s.coins)   ·   Lv \(life.level)",
                              action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// The pet's action menu — used for right-click and the menu bar icon.
    private func buildActionMenu(_ menu: NSMenu, forMenuBar: Bool) {
        let name = prefs.petName
        menu.addItem(statsItem())
        menu.addItem(.separator())
        let add = menu.addItem(withTitle: "Add a To-do…", action: #selector(quickAdd), keyEquivalent: "")
        if forMenuBar, prefs.hotKeyEnabled, case .active = HotKeyManager.shared.status, prefs.hotKeyAction == .toggleChat {
            add.title += "   \(prefs.hotKey.display)"
        }
        menu.addItem(withTitle: "To-do List…", action: #selector(openTodoList), keyEquivalent: "")
        menu.addItem(withTitle: "Wants List…  (\(life.openWants.count))", action: #selector(openWants), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(focusMenu())
        menu.addItem(.separator())
        menu.addItem(feedMenu())
        menu.addItem(playMenu())
        menu.addItem(withTitle: "Head Pats ♥", action: #selector(headPats), keyEquivalent: "")
        if pet.isAsleep {
            menu.addItem(withTitle: "Wake Up", action: #selector(wake), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Nap Time", action: #selector(nap), keyEquivalent: "")
        }
        menu.addItem(giveMenu())
        menu.addItem(.separator())
        menu.addItem(withTitle: "Closet…", action: #selector(openCloset), keyEquivalent: "")
        menu.addItem(withTitle: "Shop…  (\(life.s.coins) 🪙)", action: #selector(openShop), keyEquivalent: "")
        menu.addItem(withTitle: "Scrapbook…", action: #selector(openScrapbook), keyEquivalent: "")
        menu.addItem(.separator())
        if prefs.petVisible {
            menu.addItem(withTitle: "Hide \(name)", action: #selector(hidePet), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Show \(name)", action: #selector(showPet), keyEquivalent: "")
        }
        if forMenuBar {
            menu.addItem(withTitle: "Bring \(name) Back On-Screen", action: #selector(resetPosition), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        if forMenuBar {
            menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
        for item in menu.items where item.action != nil && item.action != #selector(NSApplication.terminate(_:)) && item.submenu == nil {
            item.target = self
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildActionMenu(menu, forMenuBar: true)
    }

    private func showPetMenu(_ event: NSEvent) {
        quick.hide()
        let menu = NSMenu()
        menu.autoenablesItems = false
        buildActionMenu(menu, forMenuBar: false)
        for item in menu.items where item.action != nil { item.isEnabled = true }
        // Pop up at the cursor (the click may have come from a copy on another display).
        let inWindow = pet.panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        menu.popUp(positioning: nil, at: pet.view.convert(inWindow, from: nil), in: pet.view)
    }

    /// A tiny pixel silhouette for the menu bar (template image, adapts to light/dark).
    static func menuBarIcon() -> NSImage {
        let art = [
            "................",
            "................",
            "................",
            ".......##.......",
            ".....######.....",
            "...##########...",
            "..############..",
            ".##############.",
            ".###..####..###.",
            ".###..####..###.",
            "################",
            "#######..#######",
            "################",
            ".##############.",
            "..############..",
            "................",
        ]
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.setFill()
            for (y, row) in art.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" {
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
