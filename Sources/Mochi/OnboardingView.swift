import AppKit
import SwiftUI

/// First-run walkthrough: hatch → name → about you → your work → vibe → where I live → ready.
struct OnboardingView: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    var onDone: () -> Void
    var startStep = 0

    @State private var step = 0
    @State private var forward = true
    @State private var cracks = 0
    @State private var hatched = false
    @State private var lastTap: TimeInterval = 0
    @State private var shakeX: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let brain = PetBrain()

    private var t: ThemeColors { prefs.theme }
    static let steps = ["Hatch", "Name", "About you", "Your work", "Vibe", "Where I live", "Ready"]

    static let colors: [(String, String)] = [
        ("Pink", "#F6A5B7"), ("Red", "#E4576E"), ("Orange", "#F2A65A"), ("Yellow", "#F7D154"), ("Matcha", "#9DB77F"),
        ("Green", "#5E8C45"), ("Sky blue", "#8FB8DE"), ("Blue", "#2F7BEA"), ("Lilac", "#B69AF0"), ("Black", "#26222E"), ("White", "#F4F4F4"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                stepView(step)
                    .id(step)
                    .transition(slide)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            footer
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .background(ZStack {
            t.bg
            if prefs.uiTheme == .psp { WaveBackground(tint: t.accent) }
        })
        .ignoresSafeArea() // fill under the transparent title bar
        .foregroundStyle(t.ink)
        .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
        .tint(t.accent)
        .onAppear {
            if startStep > 0 { step = startStep; hatched = true; cracks = 4 }
        }
    }

    /// Direction-aware: forward slides in from the right, Back from the left. Reduce Motion → fade only.
    private var slide: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let dx: CGFloat = forward ? 28 : -28
        return .asymmetric(insertion: .offset(x: dx).combined(with: .opacity),
                           removal: .offset(x: -dx).combined(with: .opacity))
    }

    private func go(to newStep: Int) {
        forward = newStep > step
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.easeOut) { step = newStep }
    }

    // MARK: Chrome

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Step \(step + 1) of \(Self.steps.count)")
                    .font(t.font(11, .semibold)).foregroundStyle(t.subInk)
                Text("·").foregroundStyle(t.subInk.opacity(0.6))
                Text(Self.steps[step]).font(t.font(11, .medium)).foregroundStyle(t.subInk)
                Spacer()
                if step > 0 && step < Self.steps.count - 1 {
                    Button("Skip setup") { go(to: Self.steps.count - 1) }
                        .buttonStyle(.plain)
                        .font(t.font(11, .medium))
                        .foregroundStyle(t.subInk)
                        .help("Keep the defaults — you can change everything later in Settings")
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(t.ink.opacity(0.08))
                    Capsule().fill(t.accent)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(Self.steps.count))
                        .animation(Motion.ifAllowed(Motion.easeOut), value: step)
                }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(Self.steps.count): \(Self.steps[step])")
        }
        .padding(.horizontal, 32)
        .padding(.top, 38) // clears the window's traffic lights
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button { go(to: step - 1) } label: {
                    Label("Back", systemImage: "chevron.left").font(t.font(13, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(t.subInk)
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
            Spacer()
            Button {
                if step == Self.steps.count - 1 { finish() } else { go(to: step + 1) }
            } label: {
                Text(step == Self.steps.count - 1 ? "Start using \(prefs.petName.isEmpty ? "Mochi" : prefs.petName)" : "Continue")
                    .font(t.font(14, .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
            }
            .buttonStyle(t.button)
            .keyboardShortcut(.defaultAction)
            .disabled(step == 0 && !hatched)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func stepView(_ s: Int) -> some View {
        switch s {
        case 0: hatchStep
        case 1: nameStep
        case 2: aboutStep
        case 3: laptopStep
        case 4: modeStep
        case 5: screensStep
        default: tipsStep
        }
    }

    private func header(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(t.font(26, .bold)).multilineTextAlignment(.center)
            Text(sub).font(t.font(13.5)).foregroundStyle(t.subInk).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480)
        }
        .staggered(0)
    }

    private func livePet(_ size: CGFloat, expression: Expression? = nil) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let base = brain.pose(at: ctx.date.timeIntervalSinceReferenceDate, PetBrain.Settings(
                intensity: .normal, reduceMotion: reduceMotion, held: prefs.held, species: prefs.species, napAfter: nil))
            SpriteImage(look: prefs.look, pose: Self.with(base, expression), colors: prefs.spriteColors, size: size)
        }
    }

    private static func with(_ pose: Pose, _ e: Expression?) -> Pose {
        var p = pose
        if let e, p.expression != .blink { p.expression = e }
        return p
    }

    /// A soft stage behind the pet.
    private func stage<C: View>(_ size: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        ZStack {
            Circle().fill(t.accent.opacity(0.12)).frame(width: size, height: size)
            Circle().fill(t.accent.opacity(0.08)).frame(width: size * 0.7, height: size * 0.7).offset(y: size * 0.12)
            content()
        }
    }

    // MARK: 1 · Hatch

    private var hatchStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            header(hatched ? "It's a \(prefs.species.label.lowercased())!" : "Something's hatching…",
                   hatched ? "Hi! I'll keep you company on your desktop ♡" : "Tap the egg a few times to help it out.")
            stage(250) {
                if hatched {
                    livePet(200, expression: .love)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                } else {
                    IconImage(icon: .egg(crack: cracks), scale: 9)
                        .offset(x: shakeX)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: tapEgg)
                        .accessibilityLabel("Egg. Tap to hatch.")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tapEgg() }
                        .transition(.opacity)
                }
            }
            .frame(height: 260)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(i < cracks ? t.accent : t.ink.opacity(0.12))
                        .frame(width: 18, height: 5)
                }
            }
            .opacity(hatched ? 0 : 1)
            .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }

    private func tapEgg() {
        let now = Date.timeIntervalSinceReferenceDate
        guard !hatched, now - lastTap > 0.12 else { return }
        lastTap = now
        cracks += 1
        if !reduceMotion {
            // Stepped, whole-point shake: reads as "game-y" and keeps the pixel art sharp on every frame.
            for (i, x) in [8, -8, 6, -4, 2, 0].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.045 * Double(i)) { shakeX = CGFloat(x) }
            }
        }
        if cracks >= 4 {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.pop) { hatched = true }
        }
    }

    // MARK: 2 · Name

    private var nameStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            header("What's my name?", "Pick a name and a look. You can change both anytime.")
            stage(170) { livePet(140) }
            TextField("Mochi", text: $prefs.petName)
                .textFieldStyle(.plain)
                .font(t.font(20, .semibold))
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(width: 280)
                .retroBox(fill: t.petBubble, border: t.border, notch: 3, line: 1.5)
                .accessibilityLabel("Pet name")
                .staggered(2)
            HStack(spacing: 8) {
                ForEach(Species.allCases) { sp in speciesButton(sp) }
            }
            .staggered(3)
            Button { prefs.randomizeCreature() } label: { Label("Shuffle look", systemImage: "dice") }
                .buttonStyle(t.quietButton)
                .staggered(4)
            Spacer(minLength: 0)
        }
    }

    private func speciesButton(_ sp: Species) -> some View {
        var look = prefs.look
        look.species = sp
        let on = prefs.species == sp
        return Button { prefs.species = sp } label: {
            VStack(spacing: 2) {
                SpriteImage(look: look, colors: prefs.spriteColors, size: 48)
                Text(sp.label).font(t.font(10, on ? .semibold : .regular)).foregroundStyle(on ? t.ink : t.subInk)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(on ? t.accent.opacity(0.14) : Color.clear)
            .outline(on ? t.accent : .clear, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(sp.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 3 · About you

    private var aboutStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            header("Tell me about you", "I'll remember and bring it up now and then. It stays on this Mac.")
            VStack(alignment: .leading, spacing: 16) {
                labeled("Your name") { input("What should I call you?", $life.s.profile.name) }
                labeled("Favorite color") {
                    HStack(spacing: 8) { ForEach(Self.colors, id: \.0) { colorChip($0) } }
                }
                labeled("Favorite games") { input("e.g. Stardew Valley, Minecraft…", $life.s.profile.favoriteGames) }
                labeled("Birthday (optional)") {
                    HStack {
                        Picker("", selection: $life.s.profile.birthdayMonth) {
                            Text("Month").tag(0)
                            ForEach(1...12, id: \.self) { m in Text(Calendar.current.monthSymbols[m - 1]).tag(m) }
                        }
                        .labelsHidden().frame(width: 150)
                        Picker("", selection: $life.s.profile.birthdayDay) {
                            Text("Day").tag(0)
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden().frame(width: 90)
                        .disabled(life.s.profile.birthdayMonth == 0)
                    }
                }
            }
            .padding(20)
            .frame(width: 540)
            .retroBox(fill: t.petBubble, border: t.border, shadow: t.shadow, notch: 4, line: 1.5)
            .staggered(1)
            Spacer(minLength: 0)
        }
    }

    private func colorChip(_ c: (String, String)) -> some View {
        let on = life.s.profile.favoriteColor == c.0
        return Button {
            life.s.profile.favoriteColor = c.0
            life.s.profile.favoriteColorHex = c.1
        } label: {
            ZStack {
                Circle().fill(RGBA(hex: c.1).color).frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(t.ink.opacity(0.15), lineWidth: 1))
                if on {
                    Circle().strokeBorder(t.accent, lineWidth: 2.5).frame(width: 34, height: 34)
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(PressableStyle())
        .help(c.0)
        .accessibilityLabel(c.0)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(t.font(11.5, .semibold)).foregroundStyle(t.subInk)
            content()
        }
    }

    private func input(_ placeholder: String, _ value: Binding<String>) -> some View {
        TextField("", text: value, prompt: Text(placeholder).foregroundColor(t.subInk.opacity(0.8)))
            .textFieldStyle(.plain)
            .font(t.font(14))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(t.bg)
            .outline(t.ink.opacity(0.14), 1, radius: 8)
    }

    // MARK: 4 · Your work

    private var laptopStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            header("What do you do on your Mac?",
                   "Pick any. I'll dress for the job and cheer you on. I only notice which app is in front — never what you type or see.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Array(Activity.allCases.enumerated()), id: \.element) { i, a in
                    activityChip(a).staggered(1 + i / 4)
                }
            }
            .frame(width: 600)
            Spacer(minLength: 0)
        }
    }

    private func activityChip(_ a: Activity) -> some View {
        let on = life.s.profile.activities.contains(a)
        return Button {
            if on { life.s.profile.activities.removeAll { $0 == a } } else { life.s.profile.activities.append(a) }
        } label: {
            VStack(spacing: 6) {
                Text(a.emoji).font(.system(size: 28))
                Text(a.label).font(t.font(12, .semibold)).foregroundStyle(t.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(on ? t.accent.opacity(0.14) : t.petBubble)
            .outline(on ? t.accent : t.ink.opacity(0.1), on ? 2 : 1, radius: 12)
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15)).foregroundStyle(t.accent)
                        .padding(7)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(Motion.ifAllowed(Motion.press), value: on)
        .accessibilityLabel(a.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 5 · Vibe

    private var modeStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            header("Pick a vibe", prefs.mode.tagline.prefix(1).uppercased() + prefs.mode.tagline.dropFirst() + ".")
            stage(130) { livePet(110) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(VibeMode.allCases) { m in ModeCard(mode: m, selected: prefs.mode == m) { prefs.apply(m) } }
            }
            .frame(width: 440)
            .staggered(2)
            Spacer(minLength: 0)
        }
    }

    // MARK: 6 · Where I live

    private var screensStep: some View {
        let displays = NSScreen.screens.count
        return VStack(spacing: 18) {
            Spacer(minLength: 0)
            header("Where should I hang out?", "You can change this anytime in Settings → Desktop & Shortcut.")
            HStack(spacing: 14) {
                placeCard(everyDisplay: false, monitors: 1, title: "Just one screen",
                          detail: "I'll stay right where you put me.")
                placeCard(everyDisplay: true, monitors: 2, title: "Every screen",
                          detail: displays > 1
                            ? "One of me on each of your \(displays) displays."
                            : "One of me on each display — kicks in when you plug another one in.")
            }
            .staggered(1)
            VStack(spacing: 0) {
                settingRow("Float above my apps",
                           "Off: I live on your desktop, behind your windows. On: I stay in view over everything.",
                           $prefs.alwaysOnTop)
                Divider().opacity(0.5).padding(.leading, 14)
                settingRow("Show me on every desktop",
                           prefs.alwaysOnTop ? "Stay visible across Spaces and full-screen apps." : "Show up on every Space (virtual desktop) you swipe to.",
                           $prefs.allSpaces)
            }
            .frame(width: 560)
            .retroBox(fill: t.petBubble, border: t.border, notch: 3, line: 1.5)
            .staggered(2)
            Spacer(minLength: 0)
        }
    }

    private func settingRow(_ title: String, _ detail: String, _ value: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(t.font(13, .semibold))
                Text(detail).font(t.font(11)).foregroundStyle(t.subInk).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: value).toggleStyle(.switch).labelsHidden().accessibilityLabel(title)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func placeCard(everyDisplay: Bool, monitors: Int, title: String, detail: String) -> some View {
        let on = prefs.everyDisplay == everyDisplay
        return Button { prefs.everyDisplay = everyDisplay } label: {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(0..<monitors, id: \.self) { _ in
                        VStack(spacing: 0) {
                            ZStack(alignment: .bottomTrailing) {
                                Rectangle().fill(t.wall)
                                SpriteImage(look: prefs.look, colors: prefs.spriteColors, size: 24).padding(3)
                            }
                            .frame(width: 70, height: 46)
                            .outline(t.ink.opacity(0.7), 3, radius: 5)
                            Rectangle().fill(t.ink.opacity(0.7)).frame(width: 8, height: 6)
                            Capsule().fill(t.ink.opacity(0.7)).frame(width: 28, height: 3)
                        }
                    }
                }
                .frame(height: 64)
                Text(title).font(t.font(14, .semibold))
                Text(detail).font(t.font(11)).foregroundStyle(t.subInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 273, height: 186)
            .background(on ? t.accent.opacity(0.14) : t.petBubble)
            .outline(on ? t.accent : t.ink.opacity(0.1), on ? 2 : 1, radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 7 · Ready

    private var tipsStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            header("You're all set\(life.s.profile.name.isEmpty ? "" : ", \(life.s.profile.name)")!", "A few things worth knowing:")
            HStack(alignment: .center, spacing: 26) {
                stage(150) { livePet(120, expression: .happy) }
                VStack(alignment: .leading, spacing: 10) {
                    tip("hand.tap.fill", "Click me to jot a to-do")
                    tip("contextualmenu.and.cursorarrow", "Right-click for snacks, games, focus timer & shop")
                    tip("cart.fill", "Drag a link onto me to save it to your Wants")
                    tip("pin.fill", "Pin a to-do — hover over me to see it")
                    tip("keyboard", "\(prefs.hotKey.display) summons me from anywhere")
                    tip("sparkles", "Stick around — events and secrets happen…")
                }
                .frame(width: 360, alignment: .leading)
                .staggered(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(t.accent)
                .frame(width: 26, height: 26)
                .background(t.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(text).font(t.font(13)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func finish() {
        if prefs.petName.trimmingCharacters(in: .whitespaces).isEmpty { prefs.petName = "Mochi" }
        if life.s.achievements[.hatched] == nil { life.s.firstMet = Date() }
        life.unlock(.hatched)
        life.remember("you hatched me and named me \(prefs.petName)", emoji: "🥚")
        life.saveNow()
        prefs.hasOnboarded = true
        prefs.onboardedV2 = true
        onDone()
    }
}

/// Fades content up into place with a short delay per index (first-run only, so a little delight is fine).
struct StaggerIn: ViewModifier {
    var index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear {
                withAnimation(Motion.easeOut.delay(Double(index) * 0.05)) { shown = true }
            }
    }
}

extension View {
    func staggered(_ index: Int) -> some View { modifier(StaggerIn(index: index)) }
}
