import AppKit
import SwiftUI

/// First-run: hatch an egg, name your pet, tell it about you, pick a vibe.
struct OnboardingView: View {
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    var onDone: () -> Void
    var startStep = 0

    @State private var step = 0
    @State private var cracks = 0
    @State private var hatched = false
    @State private var flash = 0.0
    @State private var lastTap: TimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let brain = PetBrain()

    private var t: ThemeColors { prefs.theme }
    private let steps = 7

    static let colors: [(String, String)] = [
        ("Pink", "#F6A5B7"), ("Red", "#E4576E"), ("Orange", "#F2A65A"), ("Yellow", "#F7D154"), ("Matcha", "#9DB77F"),
        ("Green", "#5E8C45"), ("Sky blue", "#8FB8DE"), ("Blue", "#2F7BEA"), ("Lilac", "#B69AF0"), ("Black", "#26222E"), ("White", "#F4F4F4"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: hatchStep
                case 1: nameStep
                case 2: aboutStep
                case 3: laptopStep
                case 4: modeStep
                case 5: screensStep
                default: tipsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .transition(.opacity)

            footer
        }
        .frame(width: 640, height: 580)
        .background(ZStack {
            t.bg
            if prefs.uiTheme == .psp { WaveBackground(tint: t.accent) }
        })
        .foregroundStyle(t.ink)
        .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
        .tint(t.accent)
        .onAppear {
            if startStep > 0 { step = startStep; hatched = true; cracks = 4 }
        }
    }

    private func title(_ s: String, _ sub: String) -> some View {
        VStack(spacing: 6) {
            Text(s).font(t.font(24, .bold)).multilineTextAlignment(.center)
            Text(sub).font(t.font(13)).foregroundStyle(t.subInk).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
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

    // MARK: Steps

    private var hatchStep: some View {
        VStack(spacing: 18) {
            title(hatched ? "it's a \(prefs.species.label.lowercased())!!" : "something's hatching…",
                  hatched ? "Hi! I'll live on your desktop now ♡" : "Tap the egg to help it out.")
            ZStack {
                Ellipse().fill(t.ink.opacity(0.12)).frame(width: 150, height: 22).offset(y: 96)
                if hatched {
                    livePet(220, expression: .love)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    IconImage(icon: .egg(crack: cracks), scale: 9)
                        .modifier(PixelShake(amount: reduceMotion ? 0 : 9, shakes: CGFloat(cracks)))
                        .onTapGesture(perform: tapEgg)
                        .accessibilityLabel("Egg. Tap to hatch.")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tapEgg() }
                }
                Color.white.opacity(flash).allowsHitTesting(false)
            }
            .frame(height: 240)
            if !hatched {
                Text(String(repeating: "●", count: cracks) + String(repeating: "○", count: max(0, 4 - cracks)))
                    .font(t.font(14)).foregroundStyle(t.accent)
            }
        }
    }

    private func tapEgg() {
        // Ignore accidental double-fires; real taps are further apart than this.
        let now = Date.timeIntervalSinceReferenceDate
        guard !hatched, now - lastTap > 0.12 else { return }
        lastTap = now
        withAnimation(reduceMotion ? nil : .linear(duration: 0.35)) { cracks += 1 }
        if cracks >= 4 {
            if !reduceMotion { flash = 1 }
            withAnimation(.easeOut(duration: 0.6)) {
                hatched = true
                flash = 0
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 14) {
            title("what's my name?", "You can change anything later.")
            livePet(150)
            TextField("Mochi", text: $prefs.petName)
                .textFieldStyle(.plain)
                .font(t.font(20, .bold))
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(width: 260)
                .retroBox(fill: t.petBubble, border: t.border, notch: 3, line: 2)
            HStack(spacing: 6) {
                ForEach(Species.allCases) { sp in speciesButton(sp) }
            }
            Button { prefs.randomizeCreature() } label: { Label("Shuffle my look", systemImage: "dice") }
                .buttonStyle(t.quietButton)
        }
    }

    private func speciesButton(_ sp: Species) -> some View {
        var look = prefs.look
        look.species = sp
        return Button { prefs.species = sp } label: {
            SpriteImage(look: look, colors: prefs.spriteColors, size: 52)
                .padding(3)
                .background(prefs.species == sp ? t.accent.opacity(0.25) : .clear)
                .overlay(Rectangle().stroke(prefs.species == sp ? t.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sp.label)
    }

    private var aboutStep: some View {
        VStack(spacing: 14) {
            title("tell me about you!", "I'll remember and bring it up sometimes. It stays on this Mac.")
            VStack(alignment: .leading, spacing: 12) {
                labeled("Your name") { input("what should I call you?", $life.s.profile.name) }
                labeled("Favorite color") {
                    HStack(spacing: 6) {
                        ForEach(Self.colors, id: \.0) { c in colorChip(c) }
                    }
                }
                labeled("Favorite games") { input("e.g. Stardew, Minecraft…", $life.s.profile.favoriteGames) }
                labeled("Birthday (optional)") {
                    HStack {
                        Picker("", selection: $life.s.profile.birthdayMonth) {
                            Text("—").tag(0)
                            ForEach(1...12, id: \.self) { m in Text(Calendar.current.monthSymbols[m - 1]).tag(m) }
                        }
                        .labelsHidden().frame(width: 140)
                        Picker("", selection: $life.s.profile.birthdayDay) {
                            Text("—").tag(0)
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden().frame(width: 80)
                        .disabled(life.s.profile.birthdayMonth == 0)
                    }
                }
            }
            .frame(width: 520)
            .padding(16)
            .retroBox(fill: t.panel, border: t.border, notch: 3, line: 2)
        }
    }

    private func colorChip(_ c: (String, String)) -> some View {
        let on = life.s.profile.favoriteColor == c.0
        return Button {
            life.s.profile.favoriteColor = c.0
            life.s.profile.favoriteColorHex = c.1
        } label: {
            Rectangle().fill(RGBA(hex: c.1).color).frame(width: 24, height: 24)
                .overlay(Rectangle().stroke(on ? t.ink : t.border.opacity(0.4), lineWidth: on ? 3 : 1))
        }
        .buttonStyle(.plain)
        .help(c.0)
        .accessibilityLabel(c.0)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(t.font(11, .bold)).foregroundStyle(t.subInk)
            content()
        }
    }

    private func input(_ placeholder: String, _ value: Binding<String>) -> some View {
        TextField("", text: value, prompt: Text(placeholder).foregroundColor(t.subInk))
            .textFieldStyle(.plain)
            .font(t.font(14))
            .padding(7)
            .background(t.petBubble)
            .overlay(Rectangle().stroke(t.border.opacity(0.5), lineWidth: 1.5))
    }

    private var laptopStep: some View {
        VStack(spacing: 14) {
            title("what do you do on your laptop?", "Pick any. I'll dress up and cheer you on in those apps.\nI only notice which app is in front — never what you type or see.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                ForEach(Activity.allCases) { a in activityChip(a) }
            }
            .frame(width: 580)
        }
    }

    private func activityChip(_ a: Activity) -> some View {
        let on = life.s.profile.activities.contains(a)
        return Button {
            if on { life.s.profile.activities.removeAll { $0 == a } } else { life.s.profile.activities.append(a) }
        } label: {
            VStack(spacing: 4) {
                Text(a.emoji).font(.system(size: 28))
                Text(a.label).font(t.font(12, .bold)).foregroundStyle(on ? t.bg : t.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .retroBox(fill: on ? t.accent : t.petBubble, border: on ? t.accent : t.border.opacity(0.4),
                      shadow: on ? t.shadow : nil, notch: 3, line: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var modeStep: some View {
        VStack(spacing: 14) {
            title("pick a vibe", prefs.mode.tagline)
            livePet(120)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                ForEach(VibeMode.allCases) { m in ModeCard(mode: m, selected: prefs.mode == m) { prefs.apply(m) } }
            }
            .frame(width: 560)
        }
    }

    private var screensStep: some View {
        let displays = NSScreen.screens.count
        return VStack(spacing: 16) {
            title("where should I hang out?", "Change this anytime in Settings → Desktop & Shortcut.")
            HStack(spacing: 14) {
                placeCard(everyDisplay: false, monitors: 1, title: "Just one screen",
                          detail: "I'll stay right where you put me.")
                placeCard(everyDisplay: true, monitors: 2, title: "Every screen",
                          detail: displays > 1
                            ? "A copy of me on each of your \(displays) displays — whichever one you touch is the real me."
                            : "One of me on each display. (You have 1 right now — this kicks in when you plug in another.)")
            }
            Toggle(isOn: $prefs.allSpaces) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow me to every desktop too").font(t.font(13, .bold))
                    Text("Stay visible when you swipe between Spaces and full-screen apps.").font(t.font(11)).foregroundStyle(t.subInk)
                }
            }
            .toggleStyle(.checkbox)
            .padding(12)
            .frame(width: 560, alignment: .leading)
            .retroBox(fill: t.panel, border: t.border.opacity(0.5), notch: 3, line: 2)
        }
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
                                SpriteImage(look: prefs.look, colors: prefs.spriteColors, size: 26).padding(3)
                            }
                            .frame(width: 76, height: 50)
                            .overlay(Rectangle().stroke(t.border, lineWidth: 3))
                            Rectangle().fill(t.border).frame(width: 10, height: 7)
                            Rectangle().fill(t.border).frame(width: 30, height: 3)
                        }
                    }
                }
                .frame(height: 70)
                Text(title).font(t.font(14, .bold)).foregroundStyle(on ? t.bg : t.ink)
                Text(detail).font(t.font(11)).foregroundStyle(on ? t.bg.opacity(0.9) : t.subInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 273, height: 210)
            .retroBox(fill: on ? t.accent : t.petBubble, border: on ? t.accent : t.border.opacity(0.4),
                      shadow: on ? t.shadow : nil, notch: 3, line: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var tipsStep: some View {
        VStack(spacing: 14) {
            title("you're all set, \(life.s.profile.name.isEmpty ? "friend" : life.s.profile.name)!", "a few secrets for living together:")
            HStack(alignment: .top, spacing: 18) {
                livePet(130, expression: .happy)
                VStack(alignment: .leading, spacing: 9) {
                    tip("hand.tap", "Click me to jot a to-do — Return adds it.")
                    tip("contextualmenu.and.cursorarrow", "Right-click me to feed, play, give treasures or open the closet.")
                    tip("pin", "Pin a to-do and I'll show it when you hover over me. Drag me anywhere.")
                    tip("keyboard", "\(prefs.hotKey.display) summons me to add a to-do from anywhere.")
                    tip("sparkles", "Keep me around — random events and secrets happen…")
                    tip("terminal", "Coder? Settings → Personality & Senses teaches me to cheer your builds.")
                }
                .frame(width: 380)
            }
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label { Text(text).font(t.font(12)).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: symbol).foregroundStyle(t.accent)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("◀ Back") { withAnimation { step -= 1 } }.buttonStyle(t.quietButton)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Rectangle().fill(i == step ? t.accent : t.border.opacity(0.3)).frame(width: i == step ? 16 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            Button(step == steps - 1 ? "LET'S GO ▶" : "NEXT ▶") {
                if step == steps - 1 { finish() } else { withAnimation { step += 1 } }
            }
            .buttonStyle(t.button)
            .keyboardShortcut(.defaultAction)
            .disabled(step == 0 && !hatched)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func finish() {
        if life.s.achievements[.hatched] == nil { life.s.firstMet = Date() }
        life.unlock(.hatched)
        life.remember("you hatched me and named me \(prefs.petName)", emoji: "🥚")
        life.saveNow()
        prefs.hasOnboarded = true
        prefs.onboardedV2 = true
        onDone()
    }
}

/// Side-to-side shake that snaps to whole points so pixel art stays crisp.
struct PixelShake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = (sin(shakes * .pi * 4) * amount).rounded()
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
