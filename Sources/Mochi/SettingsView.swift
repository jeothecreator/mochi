import AppKit
import ServiceManagement
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case creature, motion, senses, scrapbook, general, about
    var id: String { rawValue }
    var label: String {
        switch self {
        case .creature: return "Creature"
        case .motion: return "Modes & Motion"
        case .senses: return "Personality & Senses"
        case .scrapbook: return "Scrapbook"
        case .general: return "Desktop & Shortcut"
        case .about: return "About & Privacy"
        }
    }
    var symbol: String {
        switch self {
        case .creature: return "pawprint.fill"
        case .motion: return "sparkles"
        case .senses: return "eye"
        case .scrapbook: return "book.closed.fill"
        case .general: return "keyboard"
        case .about: return "lock.shield"
        }
    }
}

final class SettingsNav: ObservableObject {
    @Published var page: SettingsPage = .creature
}

struct SettingsRoot: View {
    @ObservedObject var nav: SettingsNav
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(nav.page.label.uppercased())
                        .font(RetroFont.bold(18))
                        .padding(.bottom, 2)
                    switch nav.page {
                    case .creature: CreaturePage()
                    case .motion: MotionPage()
                    case .senses: SensesPage()
                    case .scrapbook:
                        ScrapbookTab()
                            .padding(12)
                            .background(prefs.theme.bg)
                            .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
                    case .general: GeneralPage()
                    case .about: AboutPage()
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 580)
    }

    private var sidebar: some View {
        let t = UITheme.cafe.colors
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SpriteImage(look: prefs.look, colors: prefs.spriteColors, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(prefs.petName).font(RetroFont.bold(14)).foregroundStyle(t.ink).lineLimit(1)
                    Text("settings.cfg").font(RetroFont.body(10)).foregroundStyle(t.subInk)
                }
            }
            .padding(.bottom, 10)
            ForEach(SettingsPage.allCases) { page in
                Button {
                    nav.page = page
                } label: {
                    Label(page.label, systemImage: page.symbol)
                        .font(RetroFont.bold(12))
                        .foregroundStyle(nav.page == page ? t.titleInk : t.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(PixelRect(notch: 2).fill(nav.page == page ? t.titleBar : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(nav.page == page ? .isSelected : [])
            }
            Spacer()
            Text("v1.0 · local-first")
                .font(RetroFont.body(10))
                .foregroundStyle(t.subInk)
        }
        .padding(14)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(t.panel)
        .overlay(alignment: .trailing) { Rectangle().fill(t.border).frame(width: 2) }
    }
}

// MARK: - Shared bits

struct Card<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        } label: {
            Text(title).font(RetroFont.bold(12))
        }
    }
}

struct Note: View {
    var text: String
    var symbol = "info.circle"
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Grid of selectable thumbnails.
struct ThumbGrid<Item: Identifiable & Equatable, Thumb: View>: View {
    var items: [Item]
    @Binding var selection: Item
    var label: (Item) -> String
    var locked: (Item) -> Bool = { _ in false }
    var accent: Color = .accentColor
    @ViewBuilder var thumb: (Item) -> Thumb

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
            ForEach(items) { item in
                let selected = item == selection
                Button { selection = item } label: {
                    VStack(spacing: 3) {
                        thumb(item)
                        Text(label(item)).font(.system(size: 10, weight: selected ? .bold : .regular, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity)
                    .background(PixelRect(notch: 3).fill(selected ? accent.opacity(0.18) : Color.primary.opacity(0.04)))
                    .overlay(PixelRect(notch: 3).strokeBorderCompat(selected ? accent : Color.primary.opacity(0.15), lineWidth: 2, notch: 3))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(locked(item) ? 0.5 : 1)
                .accessibilityLabel(locked(item) ? "Locked secret" : label(item))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

extension Binding where Value == String {
    /// Bridges a stored hex string to a SwiftUI color well.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { RGBA(hex: wrappedValue).color },
            set: { wrappedValue = RGBA(NSColor($0)).hex })
    }
}

// MARK: - Creature

struct CreaturePage: View {
    @ObservedObject var prefs = Prefs.shared
    private let brain = PetBrain()

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            preview
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $prefs.petName)
                    .textFieldStyle(.roundedBorder)
                    .font(RetroFont.body(14))
                    .frame(maxWidth: 240)
                Picker("Eyes", selection: $prefs.eyeStyle) {
                    ForEach(EyeStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                Toggle("Rosy cheeks", isOn: $prefs.blush)
                HStack {
                    Text("Size")
                    Slider(value: Binding(get: { Double(prefs.petScale) }, set: { prefs.petScale = Int($0.rounded()) }),
                           in: 2...8, step: 1)
                        .frame(maxWidth: 200)
                    Text("\(32 * prefs.petScale) pt").font(RetroFont.body(11)).foregroundStyle(.secondary)
                }
                Button {
                    prefs.randomizeCreature()
                } label: {
                    Label("Surprise me", systemImage: "dice")
                }
            }
        }

        Card(title: "SPECIES") {
            ThumbGrid(items: Species.allCases, selection: $prefs.species, label: { $0.label }) { sp in
                var look = prefs.look
                let _ = (look.species = sp)
                SpriteImage(look: look, colors: prefs.spriteColors, size: 56)
            }
        }
        Card(title: "ACCESSORY") {
            ThumbGrid(items: Accessory.allCases, selection: Binding(get: { prefs.accessory }, set: { acc in
                guard PetLife.shared.isUnlocked(acc) else { return }
                prefs.accessory = acc
                PetLife.shared.triedAccessory(acc)
            }), label: { PetLife.shared.isUnlocked($0) ? $0.label : "Secret" }, locked: { !PetLife.shared.isUnlocked($0) }) { acc in
                if PetLife.shared.isUnlocked(acc) {
                    var look = prefs.look
                    let _ = (look.accessory = acc)
                    SpriteImage(look: look, colors: prefs.spriteColors, size: 56)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 22)).frame(width: 56, height: 56).help(acc.unlockHint)
                }
            }
        }
        Card(title: "HOLDING") {
            ThumbGrid(items: HeldItem.allCases, selection: Binding(get: { prefs.held }, set: { h in
                if PetLife.shared.isUnlocked(h) { prefs.held = h }
            }), label: { PetLife.shared.isUnlocked($0) ? $0.label : "Shop" }, locked: { !PetLife.shared.isUnlocked($0) }) { item in
                var look = prefs.look
                let _ = (look.held = item)
                SpriteImage(look: look, colors: prefs.spriteColors, size: 56)
            }
        }
        Card(title: "PALETTE") {
            ThumbGrid(items: PalettePreset.allCases, selection: Binding(get: { prefs.palettePreset }, set: { p in
                if PetLife.shared.isUnlocked(p) { prefs.palettePreset = p }
            }), label: { PetLife.shared.isUnlocked($0) ? $0.label : "\($0.label) · Shop" }, locked: { !PetLife.shared.isUnlocked($0) }) { preset in
                let base = preset.base ?? prefs.paletteBase
                SpriteImage(look: prefs.look, colors: SpriteColors.make(base), size: 56)
            }
            if prefs.palettePreset == .custom {
                HStack(spacing: 16) {
                    ColorPicker("Body", selection: $prefs.customBody.asColor, supportsOpacity: false)
                    ColorPicker("Outline", selection: $prefs.customOutline.asColor, supportsOpacity: false)
                    ColorPicker("Cheeks", selection: $prefs.customCheek.asColor, supportsOpacity: false)
                    ColorPicker("Accent", selection: $prefs.customAccent.asColor, supportsOpacity: false)
                    ColorPicker("Eyes", selection: $prefs.customEye.asColor, supportsOpacity: false)
                }
            } else {
                Note(text: "Pick “Custom” to mix your own colors. Arcade 8-bit and Pocket Green snap every pixel to a classic limited palette.")
            }
        }
    }

    private var preview: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let pose = brain.pose(at: ctx.date.timeIntervalSinceReferenceDate, PetBrain.Settings(
                intensity: prefs.intensity == .still ? .calm : prefs.intensity,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                held: prefs.held, species: prefs.species, napAfter: nil))
            SpriteImage(look: prefs.look, pose: pose, colors: prefs.spriteColors, size: 160)
        }
        .padding(8)
        .retroBox(fill: RGBA(hex: "#E9DCC4").color, border: RGBA(hex: "#3B2A22").color, shadow: RGBA(hex: "#3B2A22").color, notch: 4, line: 3, offset: 4)
        .accessibilityLabel("Preview of \(prefs.petName)")
    }
}

// MARK: - Motion & look

struct MotionPage: View {
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        Card(title: "MODES") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(VibeMode.allCases) { m in ModeCard(mode: m, selected: prefs.mode == m) { prefs.apply(m) } }
            }
            Note(text: "A mode sets the app theme, your pet's colors and what it's holding. Tweak any of them afterwards.")
        }
        Card(title: "ANIMATION") {
            Picker("Liveliness", selection: $prefs.intensity) {
                ForEach(Intensity.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)
            Note(text: "Still: only blinks. Calm: slow breathing and the occasional sip. Lively: hops and wiggles. No sounds, ever.")
            Picker("Nap when you're away from the keyboard", selection: $prefs.napMinutes) {
                Text("Never").tag(0)
                Text("After 5 min").tag(5)
                Text("After 15 min").tag(15)
                Text("After 30 min").tag(30)
            }
            .frame(maxWidth: 300)
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                Note(text: "Reduce Motion is on in System Settings, so movement is kept to blinks and quiet state changes.", symbol: "figure.walk.motion")
            }
        }
        Card(title: "RETRO EFFECTS") {
            Toggle("CRT scanlines on the creature", isOn: $prefs.scanlines)
            Toggle("Typewriter text for replies", isOn: $prefs.typewriter)
        }
        Card(title: "APP THEME") {
            ThumbGrid(items: UITheme.allCases, selection: $prefs.uiTheme, label: { $0.label }) { theme in
                let c = theme.colors
                VStack(spacing: 0) {
                    c.titleBar.frame(height: 10)
                    HStack(spacing: 4) {
                        PixelRect(notch: 1).fill(c.petBubble).frame(width: 26, height: 12)
                        Spacer(minLength: 0)
                        PixelRect(notch: 1).fill(c.userBubble).frame(width: 22, height: 12)
                    }
                    .padding(5)
                    .frame(maxHeight: .infinity)
                    .background(c.bg)
                }
                .frame(width: 70, height: 46)
                .overlay(Rectangle().stroke(c.border, lineWidth: 2))
            }
        }
    }
}

// MARK: - Desktop & shortcut

struct GeneralPage: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var hotKeys = HotKeyManager.shared
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var confirmLogin = false
    @State private var loginError: String?

    var body: some View {
        Card(title: "ON THE DESKTOP") {
            Toggle("Show \(prefs.petName) on the desktop", isOn: $prefs.petVisible)
            Toggle("Float above other windows", isOn: $prefs.alwaysOnTop)
            Note(text: prefs.alwaysOnTop
                 ? "\(prefs.petName) floats over every app."
                 : "\(prefs.petName) lives on your desktop, behind your app windows — like a desktop widget. Turn this on to keep it in view over your apps.")
            Toggle("Visible on every Space (virtual desktop)", isOn: $prefs.allSpaces)
            Toggle("A \(prefs.petName) on every display", isOn: $prefs.everyDisplay)
            Note(text: NSScreen.screens.count > 1
                 ? "With \(NSScreen.screens.count) displays you'll get one on each. They move together in spirit — hover or click any of them and it becomes the “real” one."
                 : "You have one display right now. Plug in another and a second \(prefs.petName) appears there.")
            Button("Bring \(prefs.petName) back to the corner") { AppDelegate.shared?.pet.resetPosition() }
            Note(text: "Tip: drag \(prefs.petName) anywhere. If a display is unplugged, it hops back onto a visible screen.")
        }
        Card(title: "GLOBAL SHORTCUT") {
            Toggle("Enable shortcut", isOn: $prefs.hotKeyEnabled)
            ShortcutRecorder()
                .disabled(!prefs.hotKeyEnabled)
            Picker("Shortcut does", selection: $prefs.hotKeyAction) {
                ForEach(HotKeyAction.allCases) { Text($0.label).tag($0) }
            }
            .frame(maxWidth: 360)
            switch hotKeys.status {
            case .active(let s): Note(text: "\(s) is ready.", symbol: "checkmark.circle")
            case .failed(let msg): Note(text: msg, symbol: "exclamationmark.triangle")
            case .inactive: Note(text: "Shortcut is off.", symbol: "moon.zzz")
            }
        }
        Card(title: "LOGIN") {
            Toggle("Open \(prefs.petName) when I log in", isOn: Binding(
                get: { loginEnabled },
                set: { on in
                    if on { confirmLogin = true } else { setLogin(false) }
                }))
            .disabled(!isBundled)
            if !isBundled {
                Note(text: "Available when running the built Mochi.app (see README).")
            } else {
                Note(text: "Off by default. Manage it anytime here or in System Settings → General → Login Items.")
            }
            if let loginError { Note(text: loginError, symbol: "exclamationmark.triangle") }
        }
        .alert("Start \(prefs.petName) automatically?", isPresented: $confirmLogin) {
            Button("Enable") { setLogin(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mochi will open quietly in the menu bar each time you log in. If you quit it, it stays quit until next login.")
        }
        .onAppear { loginEnabled = SMAppService.mainApp.status == .enabled }
    }

    private var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change the login item: \(error.localizedDescription)"
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }
}

struct ShortcutRecorder: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(recording ? "Press keys…" : prefs.hotKey.display)
                    .font(RetroFont.bold(14))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .frame(minWidth: 120)
                    .background(PixelRect(notch: 2).fill(Color.primary.opacity(0.07)))
                    .overlay(PixelRect(notch: 2).strokeBorderCompat(recording ? Color.accentColor : Color.primary.opacity(0.3), lineWidth: 2, notch: 2))
                    .accessibilityLabel("Current shortcut \(prefs.hotKey.display)")
                Button(recording ? "Cancel" : "Change…") { recording ? stop() : start() }
                Button("Reset to ⌃⌥⌘Space") { prefs.hotKey = .default; hint = nil }
                    .disabled(prefs.hotKey == .default)
            }
            if let hint { Note(text: hint, symbol: "keyboard") }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        hint = "Hold ⌘, ⌥ or ⌃ and press a key. Esc cancels."
        HotKeyManager.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            handle(e)
            return nil
        }
    }

    private func handle(_ e: NSEvent) {
        let mods = e.modifierFlags.intersection([.command, .option, .control, .shift])
        if e.keyCode == 53 && mods.isEmpty { hint = nil; stop(); return }
        let hasMain = !mods.intersection([.command, .option, .control]).isEmpty
        guard hasMain || HotKeyCombo.isFunctionKey(e.keyCode) else {
            hint = "Include ⌘, ⌥ or ⌃ so it doesn't clash with typing."
            return
        }
        let combo = HotKeyCombo(keyCode: UInt32(e.keyCode), command: mods.contains(.command), option: mods.contains(.option),
                                control: mods.contains(.control), shift: mods.contains(.shift), keyLabel: HotKeyCombo.label(for: e))
        if let reason = combo.reservedReason {
            hint = "\(reason) Try another."
            return
        }
        prefs.hotKey = combo
        hint = nil
        stop()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyManager.shared.resume() }
        recording = false
    }
}

// MARK: - About

struct AboutPage: View {
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        Card(title: "NOTHING LEAVES YOUR MAC") {
            row("wifi.slash", "Fully offline", "\(prefs.petName) never connects to the internet. There's no AI, account, or server — every line it says is built in.")
        }
        Card(title: "WHAT YOUR PET SENSES") {
            row("cursorarrow", "Cursor position", "So its eyes can follow you. Never recorded.")
            row("timer", "Idle time", "Seconds since your last keyboard/mouse input — to nap and wake up. Not which keys.")
            row("app.badge", "Frontmost app", "Only the app's identity (e.g. Xcode, Keynote) to cheer you on. Never window titles, contents, or keystrokes.")
            row("terminal", "Build hooks", "Only what you send it via mochi:// links from your own shell hooks.")
        }
        Card(title: "STORED LOCALLY") {
            row("slider.horizontal.3", "Preferences", "Your creature's look, size, position, and settings (UserDefaults).")
            row("cart", "Wants list", "Links and wishes you drop on \(prefs.petName) are saved as-is on this Mac. They're never fetched or shared — they only open in your browser when you click Open.")
            row("pawprint", "Pet life", "Stats, notes, memories, achievements and what you told it — \(PetLife.fileURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).")
        }
        Card(title: "NO TRACKING") {
            Note(text: "No accounts, analytics, telemetry, or network access at all. No Accessibility, Input Monitoring, camera, microphone, or screen-recording permissions.", symbol: "hand.raised")
        }
        Card(title: "CREDITS") {
            Note(text: "All pixel art is generated in code — original creatures, no borrowed characters. Built with SwiftUI + AppKit.", symbol: "paintbrush.pointed")
        }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Personality & senses

struct SensesPage: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @State private var copied: String?
    @State private var confirmReset = false

    static let zshHook = """
    # Mochi: cheer (or faint) when long commands and builds finish
    mochi_preexec() { MOCHI_T=$SECONDS; MOCHI_CMD=$1 }
    mochi_precmd() {
      local s=$? d=$(( SECONDS - ${MOCHI_T:-$SECONDS} )); unset MOCHI_T
      [[ -z $MOCHI_CMD ]] && return
      if (( d >= 8 )) || [[ $MOCHI_CMD =~ '(build|test|make|cargo|swift|xcodebuild|npm run|pnpm|yarn|gradle|pytest|go test)' ]]; then
        open -g "mochi://build?status=$s&seconds=$d"
      fi
      MOCHI_CMD=
    }
    autoload -Uz add-zsh-hook; add-zsh-hook preexec mochi_preexec; add-zsh-hook precmd mochi_precmd
    """

    static let gitHook = """
    #!/bin/sh
    # .git/hooks/post-commit — Mochi dances when you commit
    open -g "mochi://commit"
    """

    var body: some View {
        Card(title: "PERSONALITY") {
            Picker("Chattiness", selection: $prefs.chattiness) { ForEach(Chattiness.allCases) { Text($0.label).tag($0) } }
                .pickerStyle(.segmented).frame(maxWidth: 360)
            Note(text: "Quiet: only reacts to you. Sometimes: a little comment every 20–30 min. Chatty: every ~8 min. All lines are built in — no AI.")
            Picker("Random events", selection: $prefs.randomEvents) { ForEach(EventFrequency.allCases) { Text($0.label).tag($0) } }
                .pickerStyle(.segmented).frame(maxWidth: 360)
            HStack {
                Button("Trigger a surprise now") { AppDelegate.shared?.director.triggerRandomEvent() }
                Text("Rolled once per active minute: common 1/10 · uncommon 1/50 · rare 1/250 · legendary 1/1000. “Often” doubles the odds.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Go exploring when I'm away for 30 minutes", isOn: $prefs.exploring)
        }
        Card(title: "FOCUS TIMER") {
            Stepper("Focus length: \(prefs.focusMinutes) min", value: $prefs.focusMinutes, in: 5...90, step: 5)
                .frame(maxWidth: 300, alignment: .leading)
            Stepper("Break length: \(prefs.breakMinutes) min", value: $prefs.breakMinutes, in: 1...30)
                .frame(maxWidth: 300, alignment: .leading)
            Toggle("Wear headphones and stay quiet while focusing", isOn: $prefs.focusQuiet)
            Note(text: "Start one with right-click → Focus. The countdown shows in the menu bar; each finished session is +3 🪙.", symbol: "timer")
        }
        Card(title: "SENSES") {
            Toggle("Watch my cursor", isOn: $prefs.watchCursor)
            Toggle("React to the app I'm using", isOn: $prefs.reactToApps)
            Toggle("Dress for the task (glasses for coding, beret for design…)", isOn: $prefs.dressForTask)
                .disabled(!prefs.reactToApps)
            Text("What I do on my laptop").font(.callout.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading) {
                ForEach(Activity.allCases) { a in
                    Toggle("\(a.emoji) \(a.label)", isOn: Binding(
                        get: { life.s.profile.activities.contains(a) },
                        set: { on in
                            if on { life.s.profile.activities.append(a) } else { life.s.profile.activities.removeAll { $0 == a } }
                            life.saveSoon()
                        }))
                }
            }
            Note(text: "Your pet only notices which app is in front — never keystrokes, window titles or screen contents. No special permissions.", symbol: "lock.shield")
        }
        Card(title: "TERMINAL & BUILD REACTIONS") {
            Note(text: "Paste this into ~/.zshrc. When a build/test (or anything over 8 s) finishes, your pet celebrates ✨ or falls over 💥.", symbol: "terminal")
            snippet(Self.zshHook, id: "zsh")
            Note(text: "Optional git hook so it dances on every commit:", symbol: "arrow.triangle.branch")
            snippet(Self.gitHook, id: "git")
            HStack {
                Button("Test: build passed") { AppDelegate.shared?.director.handle(url: URL(string: "mochi://build?status=0")!) }
                Button("Test: build failed") { AppDelegate.shared?.director.handle(url: URL(string: "mochi://build?status=1")!) }
                Button("Test: commit") { AppDelegate.shared?.director.handle(url: URL(string: "mochi://commit")!) }
            }
            Note(text: "Works from anything that can open a URL: VS Code tasks, Makefiles, CI scripts — `open -g mochi://success` or `mochi://fail`.")
        }
        Card(title: "START OVER") {
            Button("Reset pet & re-hatch…", role: .destructive) { confirmReset = true }
            Note(text: "Clears stats, notes, memories, achievements and unlocked secrets, then shows the hatching again.")
        }
        .confirmationDialog("Reset everything and hatch a new egg?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                life.resetEverything()
                prefs.onboardedV2 = false
                AppDelegate.shared?.showOnboarding()
            }
        }
    }

    private func snippet(_ text: String, id: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.06))
            Button(copied == id ? "Copied!" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = id
            }
        }
    }
}
