import AppKit
import Combine
import SwiftUI

/// A small themed box that pops up right next to the pet (quick to-do, mini-games).
final class PetPopover {
    let panel: HomePanel
    private let host: NSHostingView<AnyView>
    private weak var pet: PetController?
    private var escMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    let width: CGFloat
    var onShow: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init(pet: PetController, width: CGFloat, title: String) {
        self.pet = pet
        self.width = width
        panel = HomePanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 160), styleMask: [.borderless], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = title
        host = NSHostingView(rootView: AnyView(EmptyView()))
        host.sizingOptions = []
        panel.contentView = host
        panel.onClose = { [weak self] in self?.hide() }

        // Resize as content changes (to-dos added, game rounds played, timer state).
        PetLife.shared.objectWillChange
            .merge(with: Prefs.shared.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in if self?.isVisible == true { self?.position() } }
            .store(in: &cancellables)
        // Tuck away when you click into another app.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
    }

    func setContent<V: View>(_ view: V) { host.rootView = AnyView(view) }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        onShow?()
        position()
        NSApp.activate()
        let wasVisible = panel.isVisible
        panel.makeKeyAndOrderFront(nil)
        if !wasVisible { Motion.fadeIn(panel, duration: 0.12) }
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
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if !NSApp.windows.contains(where: { $0.isVisible && ($0.styleMask.contains(.titled) || $0 is HomePanel) }) {
            NSApp.deactivate()
        }
    }

    func follow() { if isVisible { position() } }

    func position() {
        guard let pet else { return }
        // Measure with a fresh auto-sizing view (the live one has sizing off so it can't fight our frame).
        let height = max(60, ceil(NSHostingView(rootView: host.rootView).fittingSize.height))
        let pf = pet.panel.frame
        let vf = (pet.panel.screen ?? NSScreen.main)?.visibleFrame ?? pf
        var y = pf.maxY - pf.height * 0.1
        if y + height > vf.maxY { y = pf.minY - height + pf.height * 0.1 }
        y = min(max(y, vf.minY), vf.maxY - height)
        let x = min(max(pf.midX - width / 2, vf.minX), vf.maxX - width)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

/// Shared chrome for the pop-up boxes.
struct PopoverChrome<Content: View>: View {
    var width: CGFloat
    @ViewBuilder var content: Content
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        let t = prefs.theme
        content
            .padding(12)
            .frame(width: width - (Prefs.shared.retroFrames ? 10 : 24))
            .fixedSize(horizontal: false, vertical: true)
            .background(t.bg)
            .windowChrome(t)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
            .tint(t.accent)
    }
}

struct ChromeButton: View {
    var symbol: String
    var help: String
    var action: () -> Void
    @ObservedObject var prefs = Prefs.shared

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(prefs.theme.ink.opacity(0.7))
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Quick to-do (left-click the pet)

struct QuickTodoView: View {
    static let width: CGFloat = 290
    let director: Director
    var openList: () -> Void
    var close: () -> Void
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @ObservedObject var focus: FocusTimer
    private let shown = 5
    private var t: ThemeColors { prefs.theme }

    init(director: Director, openList: @escaping () -> Void, close: @escaping () -> Void) {
        self.director = director
        self.openList = openList
        self.close = close
        focus = director.focus
    }

    var body: some View {
        let open = life.openTodos
        PopoverChrome(width: Self.width) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    SpriteImage(look: prefs.look, pose: Pose(expression: .happy), colors: prefs.spriteColors, size: 22)
                    Text("\(prefs.petName)'s list").font(t.font(12, .bold)).foregroundStyle(t.ink).lineLimit(1)
                    Spacer()
                    ChromeButton(symbol: "arrow.up.left.and.arrow.down.right", help: "Open the full list", action: openList)
                    ChromeButton(symbol: "xmark", help: "Close (Esc)", action: close)
                }
                if focus.isRunning { focusBar }
                TodoInput(director: director, placeholder: "add a to-do…", compact: true)
                if open.isEmpty {
                    Text(life.doneTodos.isEmpty ? "nothing yet — type above and press Return" : "all clear ✨ nice work!")
                        .font(t.font(11)).foregroundStyle(t.subInk)
                        .padding(.horizontal, 4)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(open.prefix(shown)) { TodoRow(note: $0, director: director, compact: true) }
                    }
                    if open.count > shown {
                        Button("+\(open.count - shown) more · open list", action: openList)
                            .buttonStyle(.plain)
                            .font(t.font(10, .bold))
                            .foregroundStyle(t.accent)
                            .padding(.horizontal, 4)
                    }
                }
                Text("right-click me for snacks, focus, games & more")
                    .font(t.font(9)).foregroundStyle(t.subInk)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var focusBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 6) {
                IconImage(icon: .tomato, scale: 2)
                Text(focus.phase == .focus ? "Focusing · \(focus.remainingLabel) left" : "Break · \(focus.remainingLabel) left")
                    .font(t.font(11, .bold)).foregroundStyle(t.ink)
                    .monospacedDigit()
                Spacer()
                Button(focus.phase == .focus ? "Stop" : "Skip") {
                    focus.phase == .focus ? director.stopFocus() : director.skipBreak()
                }
                .buttonStyle(t.quietButton)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(t.accent.opacity(0.15))
            .outline(t.accent.opacity(0.6), 1.5)
        }
    }
}

// MARK: - Rock, paper, scissors (right-click → Play)

struct RPSView: View {
    static let width: CGFloat = 300
    let director: Director
    var close: () -> Void
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @State private var you = 0
    @State private var pet = 0
    @State private var last: (mine: Hand, theirs: Hand, outcome: Director.RPSOutcome)?
    @State private var matchOver = false
    private var t: ThemeColors { prefs.theme }

    enum Hand: CaseIterable {
        case rock, paper, scissors
        var emoji: String { self == .rock ? "✊" : (self == .paper ? "✋" : "✌️") }
        var name: String { self == .rock ? "Rock" : (self == .paper ? "Paper" : "Scissors") }
        func beats(_ o: Hand) -> Bool { (self == .rock && o == .scissors) || (self == .paper && o == .rock) || (self == .scissors && o == .paper) }
    }

    var body: some View {
        PopoverChrome(width: Self.width) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("Rock, Paper, Scissors").font(t.font(12, .bold)).foregroundStyle(t.ink)
                    Spacer()
                    ChromeButton(symbol: "xmark", help: "Close (Esc)", action: close)
                }
                HStack {
                    score("You", you)
                    Spacer()
                    Text("first to 2").font(t.font(10)).foregroundStyle(t.subInk)
                    Spacer()
                    score(prefs.petName, pet)
                }
                if let last {
                    HStack(spacing: 14) {
                        Text(last.mine.emoji).font(.system(size: 34))
                        Text("vs").font(t.font(11, .bold)).foregroundStyle(t.subInk)
                        Text(last.theirs.emoji).font(.system(size: 34))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("You played \(last.mine.name), \(prefs.petName) played \(last.theirs.name)")
                    Text(resultText(last.outcome)).font(t.font(12, .bold)).foregroundStyle(t.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("pick one! (\(prefs.petName) can't peek, promise)").font(t.font(11)).foregroundStyle(t.subInk)
                }
                if matchOver {
                    Button("Play again") { you = 0; pet = 0; last = nil; matchOver = false }
                        .buttonStyle(t.button)
                } else {
                    HStack(spacing: 10) {
                        ForEach(Hand.allCases, id: \.self) { hand in
                            Button { play(hand) } label: {
                                VStack(spacing: 2) {
                                    Text(hand.emoji).font(.system(size: 26))
                                    Text(hand.name).font(t.font(10, .bold)).foregroundStyle(t.ink)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .retroBox(fill: t.petBubble, border: t.border, shadow: t.shadow.opacity(0.5), notch: 2, line: 2, offset: 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(hand.name)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("Win a match: +2").font(t.font(10)).foregroundStyle(t.subInk)
                    IconImage(icon: .coin, scale: 1.25)
                    Text("· \(life.s.rpsWins) wins so far").font(t.font(10)).foregroundStyle(t.subInk)
                }
            }
        }
    }

    private func score(_ name: String, _ n: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(n)").font(t.font(18, .bold)).foregroundStyle(t.accent)
            Text(name).font(t.font(10)).foregroundStyle(t.subInk).lineLimit(1)
        }
        .frame(width: 80)
    }

    private func resultText(_ o: Director.RPSOutcome) -> String {
        if matchOver { return you > pet ? "you win the match! +2 🪙 🎉" : "\(prefs.petName) wins the match! 😼 rematch?" }
        switch o {
        case .youWin: return "you win this round!"
        case .petWins: return "\(prefs.petName) wins this round!"
        case .tie: return "a tie! go again"
        }
    }

    private func play(_ mine: Hand) {
        let theirs = Hand.allCases.randomElement()!
        let outcome: Director.RPSOutcome = mine == theirs ? .tie : (mine.beats(theirs) ? .youWin : .petWins)
        if outcome == .youWin { you += 1 }
        if outcome == .petWins { pet += 1 }
        last = (mine, theirs, outcome)
        director.rpsRound(outcome)
        if you == 2 || pet == 2 {
            matchOver = true
            director.rpsMatch(youWon: you == 2)
        }
    }
}
