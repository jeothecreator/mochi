import AppKit
import CoreGraphics
import SwiftUI

/// Command-line helpers: `--render-icon <dir.iconset>` and `--render-previews <file.png>`.
enum Exporters {
    static func makeContext(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    static func writePNG(_ ctx: CGContext, to url: URL) {
        guard let img = ctx.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: img)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    static func appIcon(size n: Int) -> CGContext {
        let ctx = makeContext(n, n)
        let s = CGFloat(n)
        let inset = s * 0.1
        let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let path = CGPath(roundedRect: rect, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(RGBA(hex: "#F3E6CF").nsColor.cgColor)
        ctx.fillPath()
        // Retro stripes along the bottom.
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let stripes = ["#C8894F", "#8FA37E", "#3B2A22"]
        for (i, hex) in stripes.enumerated() {
            ctx.setFillColor(RGBA(hex: hex).nsColor.cgColor)
            ctx.fill(CGRect(x: 0, y: inset + rect.height * (0.08 + CGFloat(i) * 0.06), width: s, height: rect.height * 0.045))
        }
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(RGBA(hex: "#3B2A22").nsColor.cgColor)
        ctx.setLineWidth(max(1, s * 0.02))
        ctx.strokePath()

        let look = CreatureLook()
        let colors = SpriteColors.make(PalettePreset.espresso.base!)
        let frame = SpriteRenderer.frame(look: look, pose: Pose(), colors: colors)
        let target = rect.width * 0.9
        let spriteSize = max(CGFloat(32), (target / 32).rounded(.down) * 32)
        ctx.interpolationQuality = .none
        ctx.draw(frame.image, in: CGRect(x: (s - spriteSize) / 2, y: inset + rect.height * 0.02, width: spriteSize, height: spriteSize))
        return ctx
    }

    static func exportIconset(to path: String) {
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            writePNG(appIcon(size: base), to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
            writePNG(appIcon(size: base * 2), to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
        }
    }

    /// A few sprites at large scale for close inspection.
    static func exportZoom(to path: String) {
        let scale = 8, cell = 32 * scale
        let items: [(CreatureLook, Pose)] = [
            (CreatureLook(accessory: .wizard, held: .handheld), Pose(lookY: 1)),
            (CreatureLook(species: .kitty, accessory: .witchHat, held: .matcha), Pose(expression: .love, effect: .sparkles(0))),
            (CreatureLook(species: .bunny, accessory: .halo, held: .notepad), Pose(expression: .chomp, food: .cookie, bite: 1)),
            (CreatureLook(species: .bear, accessory: .frogHat, held: .none), Pose(expression: .dizzy, effect: .stars(0), squash: true)),
            (CreatureLook(species: .sprout, accessory: .flowerCrown, held: .boba), Pose(expression: .sad, effect: .rain(1))),
            (CreatureLook(species: .ghost, accessory: .bandana, held: .mug), Pose(effect: .balloon)),
            (CreatureLook(species: .mochi, accessory: .none, held: .none), Pose(expression: .happy, effect: .music(1))),
            (CreatureLook(species: .kitty, accessory: .bandana, held: .none), Pose(expression: .surprised, effect: .sweat)),
        ]
        let ctx = makeContext(items.count * cell, cell)
        ctx.setFillColor(RGBA(hex: "#6E7F86").nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: items.count * cell, height: cell))
        let colors = SpriteColors.make(PalettePreset.espresso.base!)
        for (i, item) in items.enumerated() {
            let f = SpriteRenderer.frame(look: item.0, pose: item.1, colors: colors)
            SpriteRenderer.scaledImage(f.image, scale: scale, into: ctx, at: CGPoint(x: i * cell, y: 0))
        }
        writePNG(ctx, to: URL(fileURLWithPath: path))
    }

    /// A contact sheet of every species × accessory, plus palettes and poses, for visual QA.
    static func exportPreviews(to path: String) {
        let scale = 4, cell = 32 * scale + 8
        let poses: [(String, Pose)] = [
            ("normal", Pose()), ("blink", Pose(expression: .blink)), ("happy", Pose(expression: .happy, effect: .hearts(1))),
            ("sip", Pose(expression: .happy, sipping: true)), ("think", Pose(lookX: 1, lookY: -1, effect: .thinking(3))),
            ("sleep", Pose(expression: .sleep, effect: .zzz(1))), ("surprised", Pose(expression: .surprised, effect: .alert)),
            ("breath", Pose(breath: 1)), ("hop", Pose(hop: 2)),
        ]
        let cols = max(Accessory.allCases.count, poses.count, PalettePreset.allCases.count)
        let rows = Species.allCases.count + 3
        let ctx = makeContext(cols * cell, rows * cell)
        ctx.setFillColor(RGBA(hex: "#6E7F86").nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: cols * cell, height: rows * cell))
        let espresso = SpriteColors.make(PalettePreset.espresso.base!)

        func draw(_ look: CreatureLook, _ pose: Pose, _ colors: SpriteColors, col: Int, row: Int) {
            let f = SpriteRenderer.frame(look: look, pose: pose, colors: colors)
            let y = (rows - 1 - row) * cell + 4
            SpriteRenderer.scaledImage(f.image, scale: scale, into: ctx, at: CGPoint(x: col * cell + 4, y: y))
        }
        for (r, sp) in Species.allCases.enumerated() {
            for (c, acc) in Accessory.allCases.enumerated() {
                let held: HeldItem = c % 3 == 0 ? .mug : (c % 3 == 1 ? .none : .boba)
                draw(CreatureLook(species: sp, eyes: EyeStyle.allCases[c % 4], accessory: acc, held: held), Pose(), espresso, col: c, row: r)
            }
        }
        for (c, p) in poses.enumerated() {
            draw(CreatureLook(), p.1, espresso, col: c, row: Species.allCases.count)
        }
        for (c, preset) in PalettePreset.allCases.enumerated() {
            let base = preset.base ?? PalettePreset.espresso.base!
            draw(CreatureLook(species: Species.allCases[c % 6], accessory: Accessory.allCases[(c + 2) % 9]), Pose(), SpriteColors.make(base), col: c, row: Species.allCases.count + 1)
        }
        for (c, sp) in Species.allCases.enumerated() {
            draw(CreatureLook(species: sp, held: .none), Pose(expression: .happy, sipping: false, effect: .hearts(0)), espresso, col: c, row: Species.allCases.count + 2)
        }
        writePNG(ctx, to: URL(fileURLWithPath: path))
    }
}

// MARK: - Offscreen UI snapshots (for QA without touching the desktop)

extension Exporters {
    static func snapshot<V: View>(_ view: V, size: NSSize, to url: URL, appearance: NSAppearance.Name = .aqua) {
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -10000, y: -10000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [] // keep the exact size so clipping would be visible
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }

    static func exportUI(to dir: String) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let prefs = Prefs.shared
        prefs.petVisible = false
        prefs.petName = "Mochi" // screenshots never show a real user's pet name
        let life = PetLife.shared
        let pet = PetController()
        let director = Director(pet: pet)
        pet.mirror.enabled = true
        pet.render(force: true)

        // Sample content so every tab has something to show.
        if life.s.notes.isEmpty {
            life.addNote("buy oat milk for matcha 🍵")
            life.addNote("finish the slides for Thursday")
            life.togglePin(life.s.notes[0].id)
        }
        life.s.profile.name = life.s.profile.name.isEmpty ? "Sam" : life.s.profile.name
        life.s.profile.favoriteGames = "Stardew Valley"
        life.s.profile.activities = [.coding, .design]
        life.s.inventory[.shell] = 2
        life.s.inventory[.goldenFish] = 1
        _ = life.unlock(.hatched); _ = life.unlock(.firstMeal)
        life.remember("you spent 3 hours coding in one day", emoji: "💻")

        let nav = HomeNav()
        let savedMode = prefs.mode
        for mode in [VibeMode.cafe, .matcha, .psp, .strawberry] {
            prefs.apply(mode)
            pet.render(force: true)
            for tab in HomeTab.allCases {
                nav.tab = tab
                snapshot(HomeView(nav: nav, director: director, onClose: {}),
                         size: HomeController.size, to: out.appendingPathComponent("home-\(mode.rawValue)-\(tab.rawValue).png"))
            }
        }
        prefs.apply(savedMode)

        // Speech bubbles at their measured size — nothing should be clipped.
        let bubble = SpeechBubble()
        let samples = ["hey :)", "crunchy!!", "🐟 a GOLDEN fish swam by and dropped something! (check your items)",
                       "🔓 secret outfit unlocked: Wizard hat! (Closet → Outfits)",
                       "that's 3 hours coding today — stretch break? 🧘",
                       "you're back!! i missed you 🥺 (i left you a note)",
                       "remember when you spent 3 hours coding in one day? 💻",
                       "📌 finish the slides for Thursday and email them to the team before lunch"]
        for (i, text) in samples.enumerated() {
            for up in [false, true] {
                let size = bubble.layout(text, tailUp: up)
                print("bubble \(i)\(up ? "↑" : "↓") \(Int(size.width))×\(Int(size.height)): \(text)")
                snapshot(BubbleView(text: text, tailUp: up, theme: prefs.theme, dark: prefs.uiTheme.isDark, onTap: {}), size: size,
                         to: out.appendingPathComponent("bubble-\(i)\(up ? "-up" : "").png"))
            }
        }
        // Quick to-do box (left-click the pet), measured the same way the app does.
        for extra in ["", "email the team the final deck before lunch tomorrow", "water the plant 🪴", "book dentist", "fix the flaky login test"] where !extra.isEmpty {
            life.addNote(extra)
        }
        if let first = life.openTodos.last { life.toggleDone(first.id) }
        for mode in [VibeMode.cafe, .psp] {
            prefs.apply(mode)
            let view = QuickTodoView(director: director, openList: {}, close: {})
            let probe = NSHostingView(rootView: view)
            let size = NSSize(width: QuickTodoController.width, height: ceil(probe.fittingSize.height))
            print("quick box \(mode.rawValue): \(Int(size.width))×\(Int(size.height))")
            snapshot(view, size: size, to: out.appendingPathComponent("quick-\(mode.rawValue).png"))
        }
        prefs.apply(savedMode)

        let snav = SettingsNav()
        for page in SettingsPage.allCases {
            snav.page = page
            snapshot(SettingsRoot(nav: snav), size: NSSize(width: 780, height: 1000), to: out.appendingPathComponent("settings-\(page.rawValue).png"))
        }
        for step in 0..<7 {
            snapshot(OnboardingView(onDone: {}, startStep: step), size: NSSize(width: 640, height: 580),
                     to: out.appendingPathComponent("onboarding-\(step).png"))
        }
    }
}

// MARK: - Self-test (no UI, no real credentials)

extension Exporters {
    static func selfTest() {
        var failures = 0
        func check(_ ok: Bool, _ label: String) { print(ok ? "✔" : "✘", label); if !ok { failures += 1 } }

        // Hotkey: register the default combo. If Mochi.app is already running it should report a friendly conflict.
        let hk = HotKeyManager.shared
        hk.configure(combo: .default, enabled: true)
        switch hk.status {
        case .active(let s): check(true, "hotkey registered: \(s)")
        case .failed(let m): check(m.contains("already taken"), "hotkey conflict handled: \(m)")
        case .inactive: check(false, "hotkey inactive")
        }
        var cmdSpace = HotKeyCombo.default
        cmdSpace.control = false; cmdSpace.option = false
        hk.configure(combo: cmdSpace, enabled: true)
        if case .failed(let m) = hk.status { check(true, "reserved ⌘Space refused: \(m)") } else { check(false, "⌘Space should be refused") }
        hk.configure(combo: .default, enabled: false)

        // Pet life & director rules (runs against a throwaway data folder).
        let prefs = Prefs.shared
        prefs.petVisible = false
        let life = PetLife.shared
        life.resetEverything()
        check(life.feed(.cake) == .ok && life.s.coins == 10, "cake costs 5, first-meal achievement pays 5 back")
        check(life.feed(.cake) == .ok && life.s.coins == 5, "second cake costs 5")
        life.s.hunger = 0
        check(life.feed(.cake) == .ok && life.feed(.cake) == .broke, "can't buy cake when broke")
        life.s.hunger = 100
        check(life.feed(.onigiri) == .full, "a full pet politely refuses")
        check(life.s.achievements[.firstMeal] != nil, "first meal achievement")
        check(Activity.match(bundleID: "com.apple.dt.Xcode") == .coding && Activity.match(bundleID: "com.canva.CanvaDesktop") == .design
              && Activity.match(bundleID: "com.apple.iWork.Keynote") == .slides && Activity.match(bundleID: "com.apple.Safari") == nil,
              "frontmost-app → activity matching")
        let pet = PetController()
        let director = Director(pet: pet)
        for _ in 0..<100 { _ = director.clicked() }
        check(life.s.achievements[.pokeMaster] != nil, "100 pokes → Poke master + rainbow secret")
        for _ in 0..<3 { director.handle(url: URL(string: "mochi://build?status=1")!) }
        check(life.s.failStreak == 3, "3 failed builds tracked")
        director.handle(url: URL(string: "mochi://build?status=0&seconds=12")!)
        check(life.s.failStreak == 0 && life.s.buildsOK == 1 && life.s.achievements[.itCompiles] != nil, "passing build resets streak + It compiles!")
        check(!life.isUnlocked(.frogHat), "frog hat starts locked")
        life.addSouvenir(.goldenFish)
        director.give(.goldenFish)
        check(life.isUnlocked(.frogHat), "giving a golden fish unlocks the frog hat")
        life.addNote("remember the milk")
        let coinsBefore = life.s.coins
        check(life.toggleDone(life.s.notes[0].id) && life.s.coins == coinsBefore + 1 && life.openTodos.isEmpty, "checking off a to-do pays 1 coin")
        check(!life.toggleDone(life.s.notes[0].id) && life.openTodos.count == 1, "un-checking brings it back")
        let legacy = #"{"hunger":50,"happiness":60,"energy":70,"coins":3,"notes":[{"id":"\#(UUID().uuidString)","text":"old note","color":1,"created":0,"pinned":true}]}"#
        let old = PetLife.tolerantDecode(Data(legacy.utf8))
        check(old?.coins == 3 && old?.notes.first?.text == "old note" && old?.notes.first?.isDone == false && old?.todosDone == 0,
              "older save files still load (missing fields get defaults)")
        director.noticeTyped("i love mochi")
        check(life.s.achievements[.secretWord] != nil, "typing the secret word")
        life.saveNow()
        if let data = try? Data(contentsOf: PetLife.fileURL), let back = try? JSONDecoder().decode(PetSave.self, from: data) {
            check(back.achievements.count == life.s.achievements.count && back.notes.count == 1 && back.unlockedSecrets.contains("frogHat"),
                  "save file round-trips (\(data.count) bytes)")
        } else { check(false, "save file readable") }

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
