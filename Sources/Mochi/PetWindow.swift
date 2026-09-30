import AppKit
import Combine

/// Borderless, transparent, non-activating panel so the pet never steals focus.
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    var frameData: SpriteFrame? { didSet { needsDisplay = true } }
    var scanlines = false { didSet { needsDisplay = true } }

    var onClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onHover: ((Bool) -> Void)?

    private var mouseStart: NSPoint = .zero
    private var originStart: NSPoint = .zero
    private var dragging = false
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func draw(_ dirtyRect: NSRect) {
        guard let f = frameData, let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)
        ctx.draw(f.image, in: bounds)

        if scanlines {
            // CRT-style scanlines: a thin dark band across the bottom of every sprite pixel row.
            let px = bounds.width / 32
            ctx.setFillColor(NSColor(white: 0, alpha: 0.16).cgColor)
            for row in 0..<32 {
                var x0: Int?
                for col in 0...32 {
                    let on = col < 32 && f.opaque[row * 32 + col]
                    if on, x0 == nil { x0 = col }
                    if !on, let s = x0 {
                        let y = bounds.height - CGFloat(row + 1) * px
                        ctx.fill(CGRect(x: CGFloat(s) * px, y: y, width: CGFloat(col - s) * px, height: max(1, px * 0.28)))
                        x0 = nil
                    }
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        originStart = window?.frame.origin ?? .zero
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - mouseStart.x, dy = p.y - mouseStart.y
        if !dragging && hypot(dx, dy) > 3 {
            dragging = true
            onDragBegan?()
        }
        if dragging {
            window?.setFrameOrigin(NSPoint(x: originStart.x + dx, y: originStart.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            dragging = false
            onDragEnded?()
        } else {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) { onRightClick?(event) }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
}

/// Publishes the live frame so the pet's home room can show the very same animation.
final class PetMirror: ObservableObject {
    @Published var image: CGImage?
    var enabled = false
}

/// Owns the floating pet window, its animation timer, overrides from the director, and position persistence.
final class PetController {
    let panel: PetPanel
    let view = PetView()
    let brain = PetBrain()
    let mirror = PetMirror()
    private let prefs = Prefs.shared
    private let life = PetLife.shared
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastPose: Pose?
    private var lastLook: CreatureLook?
    private var lastColors: SpriteColors?
    private var lastExploring = false

    var onClick: (() -> Void)?
    var onMenu: ((NSEvent) -> Void)?
    var onMoved: (() -> Void)?
    var onHover: ((Bool) -> Void)?

    /// Extra pets on other displays (Settings → "A pet on every display"). They mirror the main pet's
    /// animation; hovering or clicking one quietly swaps it with the main pet, so popups follow you.
    private var copies: [String: (panel: PetPanel, view: PetView)] = [:]

    // Set by the Director.
    var systemIdle: TimeInterval = 0
    var cursorLook: (x: Int, y: Int)?
    var paletteOverride: PaletteBase? { didSet { render(force: true) } }
    var accessoryOverride: Accessory? { didSet { render(force: true) } }
    var heldOverride: HeldItem? { didSet { render(force: true) } }
    var exploring = false { didSet { render(force: true) } }
    var giant = false { didSet { applySize() } }
    private(set) var floating = false

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 128, height: 128),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = view
        panel.title = "Desktop pet"

        view.onClick = { [weak self] in self?.onClick?() }
        view.onRightClick = { [weak self] e in self?.onMenu?(e) }
        view.onHover = { [weak self] inside in self?.onHover?(inside) }
        view.onDragBegan = { [weak self] in self?.brain.dragging = true }
        view.onDragEnded = { [weak self] in
            guard let self else { return }
            self.brain.dragging = false
            self.brain.perform(.surprised)
            self.ensureOnScreen()
            self.savePosition()
            self.syncCopies()
            self.onMoved?()
        }

        applyWindowPrefs()
        restorePosition()

        prefs.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyWindowPrefs() }
            .store(in: &cancellables)
    }

    // MARK: Visibility

    func syncVisibility() {
        if prefs.petVisible { show() } else { hide() }
    }

    private func show() {
        guard !panel.isVisible else { syncCopies(); return }
        ensureOnScreen()
        panel.orderFrontRegardless()
        startTimer()
        render(force: true)
        syncCopies()
    }

    private func hide() {
        removeAllCopies()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        timer?.invalidate()
        timer = nil
    }

    // MARK: Look

    var effectiveLook: CreatureLook {
        var l = prefs.look
        if let a = accessoryOverride { l.accessory = a }
        if let h = heldOverride { l.held = h }
        if !life.isUnlocked(l.accessory) { l.accessory = .none }
        if !life.isUnlocked(l.held) { l.held = .none }
        return l
    }

    var effectiveColors: SpriteColors {
        let base = life.isUnlocked(prefs.palettePreset) ? prefs.paletteBase : PalettePreset.espresso.base!
        return SpriteColors.make(paletteOverride ?? base)
    }

    // MARK: Prefs & size

    private var currentSize: CGFloat { CGFloat(32 * prefs.petScale) * (giant ? 2 : 1) }

    private func configure(_ p: NSPanel) {
        p.level = prefs.petWindowLevel
        var behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
        if !prefs.alwaysOnTop { behavior.insert(.stationary) } // stays put on the desktop in Mission Control
        behavior.insert(prefs.allSpaces ? .canJoinAllSpaces : .moveToActiveSpace)
        p.collectionBehavior = behavior
    }

    private func applyWindowPrefs() {
        configure(panel)
        view.scanlines = prefs.scanlines
        view.setAccessibilityLabel("\(prefs.petName), your desktop pet. Click to add a to-do, right-click for more.")
        applySize()
        syncVisibility()
        render(force: true)
        syncCopies()
    }

    private func applySize() {
        let size = currentSize
        guard abs(panel.frame.width - size) > 0.5 else { return }
        let old = panel.frame
        let frame = NSRect(x: old.midX - size / 2, y: old.minY, width: size, height: size)
        if prefs.intensity != .still && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && panel.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                self?.ensureOnScreen()
                self?.onMoved?()
            }
        } else {
            panel.setFrame(frame, display: true)
            ensureOnScreen()
            onMoved?()
        }
        if !giant { savePosition() }
        syncCopies()
    }

    // MARK: Animation

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.render(force: false) }
        t.tolerance = 0.02
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var brainSettings: PetBrain.Settings {
        PetBrain.Settings(
            intensity: prefs.intensity,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            held: effectiveLook.held,
            species: prefs.species,
            napAfter: prefs.napMinutes > 0 ? TimeInterval(prefs.napMinutes * 60) : nil,
            systemIdle: systemIdle,
            cursorLook: prefs.watchCursor ? cursorLook : nil,
            hungry: life.s.hunger < 20,
            tired: life.s.energy < 15)
    }

    var isAsleep: Bool { brain.isAsleep(brainSettings) }

    func render(force: Bool) {
        guard panel.isVisible || force || mirror.enabled else { return }
        let look = effectiveLook
        let colors = effectiveColors
        if exploring {
            guard force || !lastExploring else { return }
            lastExploring = true
            view.frameData = Self.signFrame()
            for c in copies.values { c.view.frameData = view.frameData }
            if mirror.enabled { mirror.image = view.frameData?.image }
            return
        }
        lastExploring = false
        let pose = brain.pose(at: PetBrain.now, brainSettings)
        if !force && pose == lastPose && look == lastLook && colors == lastColors { return }
        lastPose = pose; lastLook = look; lastColors = colors
        let f = SpriteRenderer.frame(look: look, pose: pose, colors: colors)
        view.frameData = f
        for c in copies.values { c.view.frameData = f }
        if mirror.enabled { mirror.image = f.image }
    }

    /// "Out exploring, brb" sign shown while the pet is away.
    private static func signFrame() -> SpriteFrame {
        var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
        var opaque = [Bool](repeating: false, count: 32 * 32)
        let icon = PixelIcon.sign
        let cells = icon.cells()
        let ox = 16 - icon.width / 2, oy = 30 - icon.height
        for j in 0..<icon.height {
            for i in 0..<icon.width {
                guard let c = cells[j * icon.width + i] else { continue }
                let idx = (oy + j) * 32 + ox + i
                bytes[idx * 4] = UInt8(c.r * 255); bytes[idx * 4 + 1] = UInt8(c.g * 255)
                bytes[idx * 4 + 2] = UInt8(c.b * 255); bytes[idx * 4 + 3] = 255
                opaque[idx] = true
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let img = CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 128,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return SpriteFrame(image: img, opaque: opaque)
    }

    func setThinking(_ on: Bool) { brain.thinking = on; render(force: true) }
    func react(_ r: PetBrain.Reaction) { brain.react(r); render(force: true) }
    func perform(_ a: PetBrain.Act) { brain.perform(a); render(force: true) }

    /// Drifts up on a balloon and gently comes back.
    func floatAway() {
        guard !floating, panel.isVisible else { return }
        floating = true
        perform(.float)
        let start = panel.frame
        let vf = (panel.screen ?? NSScreen.main)?.visibleFrame ?? start
        let up = NSRect(x: start.minX, y: min(vf.maxY - start.height, start.minY + 120), width: start.width, height: start.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 2.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(up, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 2.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(start, display: true)
            } completionHandler: { [weak self] in
                self?.floating = false
                self?.onMoved?()
            }
        }
    }

    // MARK: Copies on other displays

    func syncCopies() {
        guard prefs.everyDisplay, prefs.petVisible, panel.isVisible, !floating else {
            if !floating { removeAllCopies() }
            return
        }
        let mainKey = mainScreen.map(Self.key(for:))
        let others = NSScreen.screens.filter { Self.key(for: $0) != mainKey }
        let wanted = Set(others.map(Self.key(for:)))
        for (k, c) in copies where !wanted.contains(k) {
            c.panel.orderOut(nil)
            copies[k] = nil
        }
        let size = currentSize
        for screen in others {
            let k = Self.key(for: screen)
            let c = copies[k] ?? makeCopy()
            copies[k] = c
            configure(c.panel)
            c.view.scanlines = prefs.scanlines
            c.view.setAccessibilityLabel(view.accessibilityLabel())
            let f = c.panel.frame
            if abs(f.width - size) > 0.5 || !screen.visibleFrame.intersects(f) {
                let origin = abs(f.width - size) > 0.5 && screen.visibleFrame.intersects(f)
                    ? NSPoint(x: f.midX - size / 2, y: f.minY)
                    : copyOrigin(on: screen, size: size)
                c.panel.setFrame(NSRect(origin: origin, size: NSSize(width: size, height: size)), display: false)
                clamp(c.panel, to: screen)
            }
            c.view.frameData = view.frameData
            if !c.panel.isVisible { c.panel.orderFrontRegardless() }
        }
    }

    private func removeAllCopies() {
        for c in copies.values { c.panel.orderOut(nil) }
        copies.removeAll()
    }

    private func makeCopy() -> (panel: PetPanel, view: PetView) {
        let p = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 128, height: 128),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = true
        p.title = "Desktop pet (copy)"
        let v = PetView()
        p.contentView = v
        v.onHover = { [weak self, weak p] inside in
            guard inside, let self, let p else { return }
            self.promote(p)
            self.onHover?(true)
        }
        v.onClick = { [weak self, weak p] in
            guard let self, let p else { return }
            self.promote(p)
            self.onClick?()
        }
        v.onRightClick = { [weak self, weak p] e in
            guard let self, let p else { return }
            self.promote(p)
            self.onMenu?(e)
        }
        v.onDragEnded = { [weak self, weak p] in
            guard let self, let p, let screen = p.screen else { return }
            self.clamp(p, to: screen)
            self.prefs.setCopyOrigin(p.frame.origin, for: Self.key(for: screen))
            self.syncCopies()
        }
        return (p, v)
    }

    /// Swaps a copy with the main pet. They look identical, so it's invisible — but now bubbles,
    /// the to-do box and menus open on the display you're using.
    private func promote(_ copy: PetPanel) {
        guard !floating, !brain.dragging, let entry = copies.first(where: { $0.value.panel === copy }),
              let mainKey = mainScreen.map(Self.key(for:)) else { return }
        let copyFrame = copy.frame
        copy.setFrame(panel.frame, display: true)
        panel.setFrame(copyFrame, display: true)
        copies[entry.key] = nil
        copies[mainKey] = entry.value
        prefs.setCopyOrigin(copy.frame.origin, for: mainKey)
        savePosition()
        onMoved?()
    }

    /// Where a copy goes on a display: its saved spot, or the same corner offset as the main pet.
    private func copyOrigin(on screen: NSScreen, size: CGFloat) -> NSPoint {
        let vf = screen.visibleFrame
        if let saved = prefs.copyOrigin(for: Self.key(for: screen)),
           vf.intersects(NSRect(origin: saved, size: NSSize(width: size, height: size))) { return saved }
        let mvf = mainScreen?.visibleFrame ?? vf
        let fromRight = mvf.maxX - panel.frame.maxX, fromBottom = panel.frame.minY - mvf.minY
        return NSPoint(x: vf.maxX - fromRight - size, y: vf.minY + fromBottom)
    }

    private func clamp(_ p: NSPanel, to screen: NSScreen) {
        let vf = screen.visibleFrame, f = p.frame
        let o = NSPoint(x: min(max(f.minX, vf.minX), vf.maxX - f.width), y: min(max(f.minY, vf.minY), vf.maxY - f.height))
        if o != f.origin { p.setFrameOrigin(o) }
    }

    // MARK: Position

    private func restorePosition() {
        let size = currentSize
        if let o = prefs.petOrigin {
            panel.setFrame(NSRect(x: o.x, y: o.y, width: size, height: size), display: false)
        } else {
            let vf = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            panel.setFrame(NSRect(x: vf.maxX - size - 40, y: vf.minY + 20, width: size, height: size), display: false)
        }
        ensureOnScreen()
    }

    func savePosition() {
        guard !floating else { return }
        prefs.petOrigin = panel.frame.origin
    }

    func resetPosition() {
        prefs.petOrigin = nil
        restorePosition()
        savePosition()
        onMoved?()
    }

    /// Pulls the pet back into the visible area if a display was unplugged, rearranged, or it was dragged off-screen.
    func ensureOnScreen() {
        let f = panel.frame
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let best = screens.max(by: { $0.visibleFrame.intersection(f).area < $1.visibleFrame.intersection(f).area })!
        let visibleArea = best.visibleFrame.intersection(f).area
        let target = visibleArea >= f.area * 0.6 ? best : (screens.min(by: {
            $0.visibleFrame.center.distance(to: f.center) < $1.visibleFrame.center.distance(to: f.center)
        }) ?? best)
        let vf = target.visibleFrame
        var o = f.origin
        o.x = min(max(o.x, vf.minX), vf.maxX - f.width)
        o.y = min(max(o.y, vf.minY), vf.maxY - f.height)
        if o != f.origin { panel.setFrameOrigin(o); savePosition() }
    }
}

// MARK: - A pet on every display

extension PetController {
    static func key(for screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
    }

    /// The display the main pet is mostly on.
    var mainScreen: NSScreen? {
        NSScreen.screens.max(by: { $0.frame.intersection(panel.frame).area < $1.frame.intersection(panel.frame).area })
    }
}

extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}

extension NSPoint {
    func distance(to p: NSPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}
