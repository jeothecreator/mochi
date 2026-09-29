import AppKit
import CoreGraphics

/// What the pet can perceive. Deliberately limited: cursor position, time since last input, and the
/// name of the frontmost app. No keystrokes, no window contents, no special permissions required.
final class Senses {
    struct Snapshot {
        var mouse: NSPoint
        var idle: TimeInterval
        var sinceMouseMove: TimeInterval
        var bundleID: String?
        var appName: String?
        var activity: Activity?
    }

    var onTick: ((Snapshot) -> Void)?
    private var timer: Timer?
    private var lastMouse = NSPoint.zero
    private var lastMove = Date.timeIntervalSinceReferenceDate

    static func systemIdle() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date.timeIntervalSinceReferenceDate
        let m = NSEvent.mouseLocation
        if hypot(m.x - lastMouse.x, m.y - lastMouse.y) > 2 { lastMove = now; lastMouse = m }
        let app = NSWorkspace.shared.frontmostApplication
        let own = app?.bundleIdentifier == Bundle.main.bundleIdentifier
        let snap = Snapshot(
            mouse: m,
            idle: Self.systemIdle(),
            sinceMouseMove: now - lastMove,
            bundleID: own ? nil : app?.bundleIdentifier,
            appName: own ? nil : app?.localizedName,
            activity: own ? nil : Activity.match(bundleID: app?.bundleIdentifier))
        onTick?(snap)
    }
}
