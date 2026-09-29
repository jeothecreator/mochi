import AppKit
import SwiftUI

// MARK: - Speech bubble

struct BubbleView: View {
    var text: String
    var tailUp: Bool
    var theme: ThemeColors
    var dark: Bool
    var onTap: () -> Void

    static let maxTextWidth: CGFloat = 210

    var body: some View {
        let t = theme
        VStack(spacing: 0) {
            if tailUp { tail(t).rotationEffect(.degrees(180)) }
            Text(text)
                .font(t.font(12, .medium))
                .foregroundStyle(t.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.maxTextWidth)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .retroBox(fill: t.petBubble, border: t.border, shadow: t.shadow.opacity(0.6), notch: 3, line: 2, offset: 2)
            if !tailUp { tail(t) }
        }
        .padding(4)
        .environment(\.colorScheme, dark ? .dark : .light)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    private func tail(_ t: ThemeColors) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(t.border).frame(width: 10, height: 3)
            Rectangle().fill(t.border).frame(width: 6, height: 3)
            Rectangle().fill(t.border).frame(width: 2, height: 3)
        }
    }
}

/// Little comic bubble above the pet. Non-activating; click to dismiss.
final class SpeechBubble {
    private let panel: PetPanel
    private let host: NSHostingView<BubbleView>
    private var hideWork: DispatchWorkItem?
    private(set) var lastText = ""
    private(set) var isShowing = false

    init() {
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        host = NSHostingView(rootView: BubbleView(text: "", tailUp: false, theme: Prefs.shared.theme, dark: false, onTap: {}))
        panel.contentView = host
    }

    /// Builds the view for `text` and returns the exact size it needs (so nothing gets clipped).
    @discardableResult
    func layout(_ text: String, tailUp: Bool) -> NSSize {
        let prefs = Prefs.shared
        let view = BubbleView(text: text, tailUp: tailUp, theme: prefs.theme, dark: prefs.uiTheme.isDark,
                              onTap: { [weak self] in self?.hide() })
        host.rootView = view
        // Width: the text's natural width (capped). Height: the wrapped height at that width —
        // fittingSize alone assumes one long line and would clip multi-line bubbles.
        let measurer = NSHostingController(rootView: view)
        let natural = measurer.view.fittingSize.width
        let size = measurer.sizeThatFits(in: NSSize(width: natural, height: 4000))
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    func show(_ text: String, near pet: NSWindow, duration: TimeInterval = 5) {
        lastText = text
        isShowing = true
        place(near: pet)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        // Longer lines stay up longer so they can actually be read.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(duration, Double(text.count) / 14), execute: work)
    }

    func place(near pet: NSWindow) {
        guard isShowing else { return }
        let pf = pet.frame
        let vf = (pet.screen ?? NSScreen.main)?.visibleFrame ?? pf
        var size = layout(lastText, tailUp: false)
        var y = pf.maxY - pf.height * 0.08
        if y + size.height > vf.maxY {
            size = layout(lastText, tailUp: true)
            y = pf.minY - size.height + pf.height * 0.05
        }
        let x = min(max(pf.midX - size.width / 2, vf.minX), vf.maxX - size.width)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        hideWork?.cancel()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; panel.animator().alphaValue = 0 }) { [weak self] in
            guard let self, !self.isShowing else { return }
            self.panel.orderOut(nil)
        }
    }
}

// MARK: - Critters crossing the screen

/// Transparent, click-through overlay for things that wander by (bugs, fish, ghosts, visitors).
/// Only exists — and only animates — while an actor is on screen.
final class ActorLayer {
    struct Actor {
        var image: CGImage
        var size: CGSize
        var waypoints: [(point: CGPoint, pause: TimeInterval)]
        var speed: CGFloat
        var bob: CGFloat = 0
        var alpha: CGFloat = 1
        var pos: CGPoint = .zero
        var index = 0
        var pausedUntil: TimeInterval = 0
        var facingLeft = false
        var onArrive: ((Int) -> Void)?
        var onDone: (() -> Void)?
    }

    final class LayerView: NSView {
        var actors: [Actor] = []
        var origin: CGPoint = .zero
        override var isFlipped: Bool { false }
        override func draw(_ dirtyRect: NSRect) {
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.interpolationQuality = .none
            let t = Date.timeIntervalSinceReferenceDate
            for a in actors {
                let y = a.pos.y - origin.y + (a.bob > 0 ? CGFloat(sin(t * 3)) * a.bob : 0)
                var r = CGRect(x: a.pos.x - origin.x - a.size.width / 2, y: y, width: a.size.width, height: a.size.height)
                ctx.saveGState()
                ctx.setAlpha(a.alpha)
                if !a.facingLeft {
                    ctx.translateBy(x: r.midX, y: 0); ctx.scaleBy(x: -1, y: 1); ctx.translateBy(x: -r.midX, y: 0)
                }
                r = r.integral
                ctx.draw(a.image, in: r)
                ctx.restoreGState()
            }
        }
    }

    private let panel: PetPanel
    private let view = LayerView()
    private var timer: Timer?
    private var lastTick = Date.timeIntervalSinceReferenceDate

    init() {
        panel = PetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = view
    }

    var isBusy: Bool { !view.actors.isEmpty }

    func spawn(_ actor: Actor, on screen: NSScreen) {
        var a = actor
        a.pos = actor.waypoints.first?.point ?? .zero
        a.index = 1
        if view.actors.isEmpty {
            let vf = screen.visibleFrame
            panel.setFrame(vf, display: false)
            view.origin = vf.origin
            panel.orderFrontRegardless()
        }
        view.actors.append(a)
        startTimer()
    }

    private func startTimer() {
        guard timer == nil else { return }
        lastTick = Date.timeIntervalSinceReferenceDate
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        let now = Date.timeIntervalSinceReferenceDate
        let dt = CGFloat(min(0.1, now - lastTick))
        lastTick = now
        var finished: [Int] = []
        for i in view.actors.indices {
            var a = view.actors[i]
            if now < a.pausedUntil { continue }
            guard a.index < a.waypoints.count else { finished.append(i); continue }
            let target = a.waypoints[a.index].point
            let dx = target.x - a.pos.x, dy = target.y - a.pos.y
            let dist = hypot(dx, dy)
            let stepLen = a.speed * dt
            if dist <= stepLen {
                a.pos = target
                a.pausedUntil = now + a.waypoints[a.index].pause
                a.onArrive?(a.index)
                a.index += 1
            } else {
                a.pos.x += dx / dist * stepLen
                a.pos.y += dy / dist * stepLen
                if abs(dx) > 0.5 { a.facingLeft = dx < 0 }
            }
            view.actors[i] = a
        }
        for i in finished.reversed() {
            let done = view.actors[i].onDone
            view.actors.remove(at: i)
            done?()
        }
        view.needsDisplay = true
        if view.actors.isEmpty {
            timer?.invalidate()
            timer = nil
            panel.orderOut(nil)
        }
    }
}

// MARK: - Clickable prop (mystery package)

final class PropPanel {
    private let panel: PetPanel
    private let view = PropView()
    var onClick: (() -> Void)?

    final class PropView: NSView {
        var image: CGImage?
        var onClick: (() -> Void)?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            guard let image, let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.interpolationQuality = .none
            let wobble = CGFloat(sin(Date.timeIntervalSinceReferenceDate * 6)) * 2
            ctx.draw(image, in: bounds.insetBy(dx: 4, dy: 4).offsetBy(dx: wobble, dy: 0))
        }
        override func mouseUp(with event: NSEvent) { onClick?() }
    }

    private var timer: Timer?

    init() {
        panel = PetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = view
        view.onClick = { [weak self] in self?.onClick?() }
    }

    var isVisible: Bool { panel.isVisible }

    func show(_ icon: PixelIcon, scale: CGFloat, beside pet: NSRect) {
        view.image = icon.cgImage()
        let w = CGFloat(icon.width) * scale + 8, h = CGFloat(icon.height) * scale + 8
        panel.setFrame(NSRect(x: pet.minX - w + 6, y: pet.minY, width: w, height: h), display: true)
        panel.orderFrontRegardless()
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 15, repeats: true) { [weak self] _ in self?.view.needsDisplay = true }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
    }
}
