import AppKit
import Combine
import SwiftUI

/// Left-click the pet → this little box pops up right next to it: jot a to-do, tick things off, done.
final class QuickTodoController {
    let panel: HomePanel
    private let host: NSHostingView<QuickTodoView>
    private weak var pet: PetController?
    private var escMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    static let width: CGFloat = 290

    var isVisible: Bool { panel.isVisible }

    init(pet: PetController, director: Director, openList: @escaping () -> Void) {
        self.pet = pet
        panel = HomePanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 160), styleMask: [.borderless], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "Quick to-do"
        host = NSHostingView(rootView: QuickTodoView(director: director, openList: {}, close: {}))
        host.sizingOptions = []
        panel.contentView = host
        host.rootView = QuickTodoView(director: director,
                                      openList: { [weak self] in self?.hide(); openList() },
                                      close: { [weak self] in self?.hide() })
        panel.onClose = { [weak self] in self?.hide() }

        // Resize/reposition as items are added or ticked off.
        PetLife.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in if self?.isVisible == true { self?.position() } }
            .store(in: &cancellables)
        // Tuck away when you click into another app.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
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
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if !NSApp.windows.contains(where: { $0.isVisible && ($0.styleMask.contains(.titled) || $0 is HomePanel) }) {
            NSApp.deactivate()
        }
    }

    func follow() { if isVisible { position() } }

    private func position() {
        guard let pet else { return }
        // Measure with a fresh auto-sizing view (the live one has sizing turned off so it can't fight our frame).
        let height = max(80, ceil(NSHostingView(rootView: host.rootView).fittingSize.height))
        let pf = pet.panel.frame
        let vf = (pet.panel.screen ?? NSScreen.main)?.visibleFrame ?? pf
        var y = pf.maxY - pf.height * 0.1
        if y + height > vf.maxY { y = pf.minY - height + pf.height * 0.1 }
        y = min(max(y, vf.minY), vf.maxY - height)
        let x = min(max(pf.midX - Self.width / 2, vf.minX), vf.maxX - Self.width)
        panel.setFrame(NSRect(x: x, y: y, width: Self.width, height: height), display: true)
    }
}

struct QuickTodoView: View {
    let director: Director
    var openList: () -> Void
    var close: () -> Void
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    private let shown = 5
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        let open = life.openTodos
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SpriteImage(look: prefs.look, pose: Pose(expression: .happy), colors: prefs.spriteColors, size: 22)
                Text("\(prefs.petName)'s list").font(t.font(12, .bold)).foregroundStyle(t.ink).lineLimit(1)
                Spacer()
                chromeButton("list.bullet", "Open full list", action: openList)
                chromeButton("xmark", "Close (Esc)", action: close)
            }
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
            Text("right-click me for snacks, play & more")
                .font(t.font(9)).foregroundStyle(t.subInk)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .frame(width: QuickTodoController.width - 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(t.bg)
        .clipShape(PixelRect(notch: t.rounded ? 0 : 3))
        .overlay(PixelRect(notch: t.rounded ? 0 : 3).strokeBorderCompat(t.border, lineWidth: t.rounded ? 1.5 : 2.5, notch: t.rounded ? 0 : 3))
        .background(PixelRect(notch: t.rounded ? 0 : 3).fill(t.shadow.opacity(0.85)).offset(x: 4, y: 4))
        .padding(EdgeInsets(top: 1, leading: 1, bottom: 6, trailing: 6))
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.colorScheme, prefs.uiTheme.isDark ? .dark : .light)
        .tint(t.accent)
    }

    private func chromeButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(t.ink.opacity(0.7))
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
