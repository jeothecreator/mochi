import AppKit
import Combine
import SwiftUI

enum HomeTab: String, CaseIterable, Identifiable {
    case todo, closet, shop
    var id: String { rawValue }
    var label: String {
        switch self {
        case .todo: return "To-do"
        case .closet: return "Closet"
        case .shop: return "Shop"
        }
    }
    var symbol: String {
        switch self {
        case .todo: return "checklist"
        case .closet: return "tshirt.fill"
        case .shop: return "bag.fill"
        }
    }
}

final class HomeNav: ObservableObject {
    @Published var tab: HomeTab = .todo
}

/// The pet's home: a floating panel docked next to the creature.
/// Borderless panel that can still take keyboard focus (for notes); Esc closes it.
final class HomePanel: NSPanel {
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onClose?() }
    override func performClose(_ sender: Any?) { onClose?() }
}

final class HomeController {
    let nav = HomeNav()
    let panel: HomePanel
    private weak var pet: PetController?
    private var escMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    static let size = NSSize(width: 430, height: 600)

    var isVisible: Bool { panel.isVisible }

    init(pet: PetController, director: Director) {
        self.pet = pet
        panel = HomePanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "Home"
        panel.onClose = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(rootView: HomeView(nav: nav, director: director, onClose: { [weak self] in self?.hide() }))
    }

    func toggle() { isVisible && panel.isKeyWindow ? hide() : show() }

    func show(tab: HomeTab? = nil) {
        if let tab { nav.tab = tab }
        position()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if escMonitor == nil {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                guard let self, e.keyCode == 53, e.window === self.panel else { return e }
                self.hide()
                return nil
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        PetLife.shared.saveSoon()
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if !NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
            NSApp.deactivate()
        }
    }

    func followPet() { if isVisible { position() } }

    private func position() {
        guard let pet else { return }
        let pf = pet.panel.frame
        let screen = pet.panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let vf = screen?.visibleFrame else { return }
        let size = Self.size
        var x = pf.minX - size.width - 6
        if x < vf.minX { x = pf.maxX + 6 }
        if x + size.width > vf.maxX { x = vf.maxX - size.width }
        let y = min(max(pf.minY, vf.minY), vf.maxY - size.height)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

// MARK: - Root

struct HomeView: View {
    @ObservedObject var nav: HomeNav
    let director: Director
    var onClose: () -> Void
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared

    private var t: ThemeColors { prefs.theme }
    private var tabs: [HomeTab] { HomeTab.allCases }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Group {
                switch nav.tab {
                case .todo: TodoTab(director: director)
                case .closet: ScrollView { ClosetTab().padding(12) }
                case .shop: ScrollView { ShopTab(director: director).padding(12) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollIndicators(.never)
        }
        .background(ZStack {
            t.bg
            if prefs.uiTheme == .psp { WaveBackground(tint: t.accent) }
        })
        .clipShape(PixelRect(notch: t.rounded ? 0 : 4))
        .overlay(PixelRect(notch: t.rounded ? 0 : 4).strokeBorderCompat(t.border, lineWidth: t.rounded ? 1.5 : 3, notch: t.rounded ? 0 : 4))
        .background(PixelRect(notch: t.rounded ? 0 : 4).fill(t.shadow.opacity(0.9)).offset(x: 5, y: 5))
        .padding(EdgeInsets(top: 2, leading: 2, bottom: 8, trailing: 8))
        .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
        .tint(t.accent)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            SpriteImage(look: prefs.look, colors: prefs.spriteColors, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(prefs.uiTheme == .psp ? prefs.petName : "\(prefs.petName.uppercased()).EXE")
                    .font(t.font(13, .bold))
                    .foregroundStyle(t.titleInk)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("LV \(life.level)").font(t.font(9, .bold)).foregroundStyle(t.titleInk.opacity(0.8))
                    ProgressBar(value: life.levelProgress, fill: t.accent, track: t.titleInk.opacity(0.25), segments: 10)
                        .frame(width: 60, height: 5)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                IconImage(icon: .coin, scale: 1.75)
                Text("\(life.s.coins)").font(t.font(12, .bold)).foregroundStyle(t.titleInk)
            }
            .help("Coins — earned by hanging out, events and achievements")
            titleButton("gearshape", help: "Settings") { AppDelegate.shared?.openSettings(.creature) }
            titleButton("xmark", help: "Close (Esc)", action: onClose)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(ZStack { t.titleBar; WindowDragArea() })
    }

    private func titleButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(t.titleBar)
                .frame(width: 20, height: 18)
                .background(PixelRect(notch: t.rounded ? 0 : 2).fill(t.titleInk).clipShape(RoundedRectangle(cornerRadius: t.rounded ? 5 : 0)))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                let on = nav.tab == tab
                Button { nav.tab = tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol).font(.system(size: prefs.uiTheme == .psp ? 15 : 12, weight: .semibold))
                        Text(tab.label).font(t.font(10, on ? .bold : .regular))
                    }
                    .foregroundStyle(on ? (prefs.uiTheme == .psp ? t.ink : t.bg) : t.subInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background {
                        if on {
                            if prefs.uiTheme == .psp {
                                Capsule().fill(t.accent.opacity(0.25)).shadow(color: t.accent.opacity(0.8), radius: 6)
                            } else {
                                PixelRect(notch: 2).fill(t.accent)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(t.panel.opacity(prefs.uiTheme == .psp ? 0.5 : 1))
        .overlay(alignment: .bottom) { Rectangle().fill(t.border.opacity(0.4)).frame(height: 2) }
    }
}

// MARK: - Bits

struct ProgressBar: View {
    var value: Double
    var fill: Color
    var track: Color
    var segments = 10

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle().fill(Double(i) < value * Double(segments) ? fill : track)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct SectionTitle: View {
    var text: String
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        Text(prefs.uiTheme == .psp ? text.capitalized : text.uppercased())
            .font(prefs.theme.font(11, .bold))
            .foregroundStyle(prefs.theme.subInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

extension View {
    func themedCard(_ t: ThemeColors) -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .retroBox(fill: t.panel.opacity(t.rounded ? 0.7 : 1), border: t.border.opacity(t.rounded ? 0.5 : 1), notch: t.rounded ? 0 : 3, line: t.rounded ? 1 : 2)
    }
}

// MARK: - To-do

struct TodoTab: View {
    let director: Director
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @State private var showDone = false
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        VStack(spacing: 0) {
            TodoInput(director: director, placeholder: "add a to-do…")
                .padding(12)
            if life.s.notes.isEmpty {
                VStack(spacing: 8) {
                    SpriteImage(look: prefs.look, pose: Pose(expression: .happy), colors: prefs.spriteColors, size: 64)
                    Text("Nothing on the list! Add something above,\nor just click me on your desktop. 📌")
                        .font(t.font(11)).foregroundStyle(t.subInk).multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(life.openTodos) { TodoRow(note: $0, director: director) }
                        if !life.doneTodos.isEmpty {
                            HStack {
                                Button { showDone.toggle() } label: {
                                    Label("Done (\(life.doneTodos.count))", systemImage: showDone ? "chevron.down" : "chevron.right")
                                        .font(t.font(11, .bold)).foregroundStyle(t.subInk)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button("Clear done") { life.clearDone() }.buttonStyle(t.quietButton)
                            }
                            .padding(.top, 6)
                            if showDone { ForEach(life.doneTodos) { TodoRow(note: $0, director: director) } }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

/// Text box that adds a to-do on Return (⇧/⌥-Return for a new line).
struct TodoInput: View {
    let director: Director
    var placeholder: String
    var compact = false
    @ObservedObject var prefs = Prefs.shared
    @State private var draft = ""
    @FocusState private var focused: Bool
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(t.accent)
            TextField("", text: $draft, prompt: Text(placeholder).foregroundColor(t.subInk), axis: .vertical)
                .textFieldStyle(.plain)
                .font(t.font(compact ? 12 : 13))
                .foregroundStyle(t.ink)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit(add)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) || press.modifiers.contains(.option) { return .ignored }
                    add()
                    return .handled
                }
                .accessibilityLabel("New to-do")
            if !compact {
                Button("Add", action: add)
                    .buttonStyle(t.button)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(compact ? 8 : 10)
        .retroBox(fill: t.panel, border: t.border, notch: t.rounded ? 0 : 3, line: 2)
        .onAppear { focused = true }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        director.addTodo(text)
    }
}

struct TodoRow: View {
    let note: PetNote
    let director: Director
    var compact = false
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { director.toggleTodo(note.id) } label: {
                ZStack {
                    Rectangle().fill(note.isDone ? t.accent : t.petBubble).frame(width: 16, height: 16)
                    Rectangle().stroke(t.border, lineWidth: 2).frame(width: 16, height: 16)
                    if note.isDone { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(t.bg) }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isDone ? "Mark not done" : "Mark done")
            .padding(.top, 1)

            Text(note.text)
                .font(t.font(compact ? 12 : 13))
                .foregroundStyle(note.isDone ? t.subInk : t.ink)
                .strikethrough(note.isDone, color: t.subInk)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !compact {
                if !note.isDone {
                    iconButton(note.pinned ? "pin.fill" : "pin", note.pinned ? "Unpin" : "Pin — shows when you hover over \(prefs.petName)") {
                        life.togglePin(note.id)
                    }
                }
                iconButton("trash", "Delete") { life.deleteNote(note.id) }
            } else if note.pinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(t.accent).accessibilityLabel("Pinned")
            }
        }
        .padding(.horizontal, compact ? 4 : 10)
        .padding(.vertical, compact ? 3 : 8)
        .background(compact ? Color.clear : t.petBubble)
        .overlay(compact ? nil : Rectangle().stroke(note.pinned ? t.accent : t.border.opacity(0.35), lineWidth: note.pinned ? 2.5 : 1.5))
    }

    private func iconButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(t.subInk) }
            .buttonStyle(.plain)
            .help(help)
            .accessibilityLabel(help)
    }
}

// MARK: - Closet

struct ClosetTab: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Modes")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(VibeMode.allCases) { m in ModeCard(mode: m, selected: prefs.mode == m) { prefs.apply(m) } }
                }
                .padding(2)
            }
            .scrollIndicators(.never)

            SectionTitle(text: "Species")
            ThumbGrid(items: Species.allCases, selection: $prefs.species, label: { $0.label }, accent: t.accent) { sp in
                var look = prefs.look
                let _ = (look.species = sp)
                SpriteImage(look: look, colors: prefs.spriteColors, size: 48)
            }
            SectionTitle(text: "Outfits")
            ThumbGrid(items: Accessory.allCases, selection: Binding(get: { prefs.accessory }, set: { acc in
                guard life.isUnlocked(acc) else { return }
                prefs.accessory = acc
                life.triedAccessory(acc)
            }), label: { life.isUnlocked($0) ? $0.label : "???" }, locked: { !life.isUnlocked($0) }, accent: t.accent) { acc in
                if life.isUnlocked(acc) {
                    var look = prefs.look
                    let _ = (look.accessory = acc)
                    SpriteImage(look: look, colors: prefs.spriteColors, size: 48)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 20)).frame(width: 48, height: 48).help(acc.unlockHint)
                }
            }
            SectionTitle(text: "Holding")
            ThumbGrid(items: HeldItem.allCases, selection: Binding(get: { prefs.held }, set: { h in
                if life.isUnlocked(h) { prefs.held = h }
            }), label: { life.isUnlocked($0) ? $0.label : "Shop" }, locked: { !life.isUnlocked($0) }, accent: t.accent) { item in
                if life.isUnlocked(item) {
                    var look = prefs.look
                    let _ = (look.held = item)
                    SpriteImage(look: look, colors: prefs.spriteColors, size: 48)
                } else {
                    Image(systemName: "bag.fill").font(.system(size: 20)).frame(width: 48, height: 48)
                        .help(ShopItem.item(for: item).map { "Buy it in the Shop · \($0.price) coins" } ?? "")
                }
            }
            SectionTitle(text: "Eyes")
            Picker("Eyes", selection: $prefs.eyeStyle) { ForEach(EyeStyle.allCases) { Text($0.label).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
            Toggle("Rosy cheeks", isOn: $prefs.blush).font(t.font(12)).foregroundStyle(t.ink)
            Button("More: palettes, custom colors, size…") { AppDelegate.shared?.openSettings(.creature) }
                .buttonStyle(t.quietButton)
        }
        .foregroundStyle(t.ink)
    }
}

struct ModeCard: View {
    var mode: VibeMode
    var selected: Bool
    var action: () -> Void
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        let c = mode.ui.colors
        var look = prefs.look
        let _ = (look.held = mode.held)
        return Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    c.bg
                    if mode == .psp { WaveBackground(tint: c.accent) }
                    SpriteImage(look: look, colors: SpriteColors.make(mode.palette.base!), size: 52)
                }
                .frame(width: 84, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: mode == .psp ? 8 : 0))
                Text(mode.label).font(c.font(10, .bold)).foregroundStyle(c.ink).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(5)
            .background(c.panel)
            .overlay(Rectangle().stroke(selected ? c.accent : c.border.opacity(0.5), lineWidth: selected ? 3 : 1.5))
        }
        .buttonStyle(.plain)
        .help(mode.tagline)
        .accessibilityLabel("\(mode.label) mode")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Shop

struct ShopTab: View {
    let director: Director
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconImage(icon: .bag, scale: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coin shop").font(t.font(14, .bold)).foregroundStyle(t.ink)
                    Text("You have \(life.s.coins) 🪙").font(t.font(11)).foregroundStyle(t.subInk)
                }
            }
            Text("Earn coins by finishing to-dos (+1), focus sessions (+3), rock-paper-scissors wins (+2), random events and achievements.")
                .font(t.font(10)).foregroundStyle(t.subInk).fixedSize(horizontal: false, vertical: true)
            section("Outfits", .outfit)
            section("Palettes", .palette)
            section("Extras", .extra)
        }
    }

    private func section(_ title: String, _ kind: ShopItem.Kind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(ShopItem.allCases.filter { $0.kind == kind }) { card($0) }
            }
        }
    }

    private func preview(_ item: ShopItem) -> (CreatureLook, SpriteColors) {
        var look = prefs.look
        if let a = item.accessory { look.accessory = a }
        if let h = item.held { look.held = h }
        let colors = item.palette.flatMap(\.base).map(SpriteColors.make) ?? prefs.spriteColors
        return (look, colors)
    }

    private func wearing(_ item: ShopItem) -> Bool {
        (item.accessory != nil && prefs.accessory == item.accessory) ||
        (item.palette != nil && prefs.palettePreset == item.palette) ||
        (item.held != nil && prefs.held == item.held)
    }

    private func card(_ item: ShopItem) -> some View {
        let owned = life.owns(item)
        let (look, colors) = preview(item)
        return VStack(spacing: 5) {
            SpriteImage(look: look, colors: colors, size: 56)
            Text(item.accessory?.label ?? item.palette?.label ?? item.held?.label ?? "")
                .font(t.font(11, .bold)).foregroundStyle(t.ink).lineLimit(1).minimumScaleFactor(0.8)
            if owned {
                Button(wearing(item) ? "Wearing ✓" : "Wear") { wear(item) }
                    .buttonStyle(t.quietButton)
                    .disabled(wearing(item))
            } else {
                Button("\(item.price) 🪙") { _ = director.buy(item) }
                    .buttonStyle(t.button)
                    .opacity(life.s.coins >= item.price ? 1 : 0.5)
                    .help(life.s.coins >= item.price ? "Buy \(item.label)" : "You need \(item.price - life.s.coins) more coins")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .retroBox(fill: t.petBubble, border: wearing(item) ? t.accent : t.border.opacity(0.4), notch: t.rounded ? 0 : 3, line: wearing(item) ? 2.5 : 1.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label), \(owned ? "owned" : "\(item.price) coins")")
    }

    private func wear(_ item: ShopItem) {
        if let a = item.accessory { prefs.accessory = a; life.triedAccessory(a) }
        if let p = item.palette { prefs.palettePreset = p }
        if let h = item.held { prefs.held = h }
        AppDelegate.shared?.pet.perform(.love)
    }
}

// MARK: - Scrapbook

struct ScrapbookTab: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @State private var newFact = ""
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            friendship
            aboutYou
            achievements
            memories
        }
        .foregroundStyle(t.ink)
        .onChange(of: life.s.profile) { life.saveSoon() }
    }

    private var friendship: some View {
        let cal = Calendar.current
        let days = (cal.dateComponents([.day], from: cal.startOfDay(for: life.s.firstMet), to: cal.startOfDay(for: Date())).day ?? 0) + 1
        return HStack(spacing: 12) {
            SpriteImage(look: prefs.look, pose: Pose(expression: .love), colors: prefs.spriteColors, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Friendship level \(life.level)").font(t.font(13, .bold))
                ProgressBar(value: life.levelProgress, fill: t.accent, track: t.ink.opacity(0.12), segments: 10).frame(height: 8)
                Text("\(days) day\(days == 1 ? "" : "s") together · \(life.s.feeds) meals · \(life.s.clicks) pokes · \(life.s.buildsOK) builds cheered")
                    .font(t.font(10)).foregroundStyle(t.subInk).fixedSize(horizontal: false, vertical: true)
            }
        }
        .themedCard(t)
    }

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "What I know about you")
            field("Name", $life.s.profile.name)
            field("Favorite color", $life.s.profile.favoriteColor)
            field("Favorite games", $life.s.profile.favoriteGames)
            HStack {
                Text("Laptop life").font(t.font(11, .bold)).frame(width: 110, alignment: .leading)
                Text(life.s.profile.activities.isEmpty ? "— (set in Settings → Personality & Senses)" : life.s.profile.activities.map { "\($0.emoji) \($0.label)" }.joined(separator: "  "))
                    .font(t.font(11)).foregroundStyle(t.subInk).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(life.s.profile.facts.enumerated()), id: \.offset) { i, fact in
                HStack {
                    Text("♡ \(fact)").font(t.font(11)).frame(maxWidth: .infinity, alignment: .leading)
                    Button { life.s.profile.facts.remove(at: i) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain).foregroundStyle(t.subInk).accessibilityLabel("Forget this")
                }
            }
            HStack {
                TextField("", text: $newFact, prompt: Text("tell me something about you…").foregroundColor(t.subInk))
                    .textFieldStyle(.plain).font(t.font(11))
                    .onSubmit(addFact)
                Button("Remember", action: addFact).buttonStyle(t.quietButton)
                    .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("I bring these up now and then. Stored only on this Mac.").font(t.font(9)).foregroundStyle(t.subInk)
        }
        .themedCard(t)
    }

    private func addFact() {
        let f = newFact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty else { return }
        life.s.profile.facts.append(f)
        newFact = ""
        AppDelegate.shared?.director.noticeTyped(f)
        AppDelegate.shared?.pet.perform(.love)
    }

    private func field(_ label: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label).font(t.font(11, .bold)).frame(width: 110, alignment: .leading)
            TextField("", text: value, prompt: Text("—").foregroundColor(t.subInk)).textFieldStyle(.plain).font(t.font(11))
        }
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Achievements \(life.s.achievements.count)/\(Achievement.allCases.count)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                ForEach(Achievement.allCases) { a in
                    let got = life.s.achievements[a] != nil
                    HStack(spacing: 6) {
                        IconImage(icon: .star, scale: 2).saturation(got ? 1 : 0).opacity(got ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(got || !a.isSecret ? a.title : "???").font(t.font(10, .bold)).lineLimit(1)
                            Text(got || !a.isSecret ? a.detail : "a secret…").font(t.font(8)).foregroundStyle(t.subInk).lineLimit(2)
                        }
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.petBubble.opacity(got ? 1 : 0.5))
                    .overlay(Rectangle().stroke(got ? t.accent : t.border.opacity(0.3), lineWidth: got ? 2 : 1))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .themedCard(t)
    }

    private var memories: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Memories")
            if life.s.memories.isEmpty {
                Text("We'll make some soon ♡").font(t.font(11)).foregroundStyle(t.subInk)
            }
            ForEach(life.s.memories.prefix(40)) { m in
                HStack(alignment: .top, spacing: 8) {
                    Text(m.emoji)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.text).font(t.font(11)).fixedSize(horizontal: false, vertical: true)
                        Text(m.date.formatted(date: .abbreviated, time: .omitted)).font(t.font(9)).foregroundStyle(t.subInk)
                    }
                }
            }
        }
        .themedCard(t)
    }
}
