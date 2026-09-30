import AppKit
import SwiftUI

enum UITheme: String, CaseIterable, Identifiable {
    case cafe, matcha, psp, strawberry, terminal, pocket, midnight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cafe: return "Cozy Café"
        case .terminal: return "Green Terminal"
        case .pocket: return "Pocket Handheld"
        case .midnight: return "Midnight Arcade"
        case .matcha: return "Matcha"
        case .psp: return "PSP"
        case .strawberry: return "Strawberry Milk"
        }
    }

    var isDark: Bool { self == .terminal || self == .midnight || self == .psp }

    var colors: ThemeColors {
        switch self {
        case .cafe:
            return ThemeColors(bg: "#FBF4E6", panel: "#F3E6CF", ink: "#3B2A22", subInk: "#8A6F5E", accent: "#C8894F",
                               border: "#3B2A22", userBubble: "#9CAF88", userInk: "#1F2A18", petBubble: "#FFFDF7",
                               error: "#B5483A", titleBar: "#3B2A22", titleInk: "#FBF4E6", shadow: "#3B2A22",
                               wall: "#F3E6CF", floor: "#B98B62", trim: "#8FA37E")
        case .matcha:
            return ThemeColors(bg: "#F1F5E6", panel: "#DDE8C8", ink: "#2F3B26", subInk: "#6E7F5C", accent: "#7FA35B",
                               border: "#2F3B26", userBubble: "#F6EED8", userInk: "#2F3B26", petBubble: "#FBFDF5",
                               error: "#B5483A", titleBar: "#5E7F45", titleInk: "#F6F9EE", shadow: "#2F3B26",
                               wall: "#E4EDD2", floor: "#C9B38F", trim: "#9DB77F")
        case .psp:
            return ThemeColors(bg: "#0B1020", panel: "#161D33", ink: "#E9EEF8", subInk: "#8E99B5", accent: "#4FA3FF",
                               border: "#56688F", userBubble: "#2F7BEA", userInk: "#FFFFFF", petBubble: "#1B2440",
                               error: "#FF6B81", titleBar: "#111729", titleInk: "#E9EEF8", shadow: "#04060D",
                               wall: "#121A33", floor: "#0A0F1F", trim: "#4FA3FF", rounded: true)
        case .strawberry:
            return ThemeColors(bg: "#FFF1F4", panel: "#FBD9E1", ink: "#5A2A3A", subInk: "#A0667A", accent: "#E8708C",
                               border: "#5A2A3A", userBubble: "#9ED9CC", userInk: "#1F3B35", petBubble: "#FFFFFF",
                               error: "#C0392B", titleBar: "#E8708C", titleInk: "#FFF1F4", shadow: "#5A2A3A",
                               wall: "#FCE3EA", floor: "#F3B8C6", trim: "#9ED9CC")
        case .terminal:
            return ThemeColors(bg: "#0B0F0B", panel: "#101810", ink: "#8CFF98", subInk: "#3FA34D", accent: "#8CFF98",
                               border: "#8CFF98", userBubble: "#16361D", userInk: "#C4FFCA", petBubble: "#0F1F12",
                               error: "#FF6B6B", titleBar: "#8CFF98", titleInk: "#0B0F0B", shadow: "#1E5A27",
                               wall: "#0E170E", floor: "#0A120A", trim: "#8CFF98", mono: true)
        case .pocket:
            return ThemeColors(bg: "#9BBC0F", panel: "#8BAC0F", ink: "#0F380F", subInk: "#306230", accent: "#306230",
                               border: "#0F380F", userBubble: "#306230", userInk: "#9BBC0F", petBubble: "#8BAC0F",
                               error: "#0F380F", titleBar: "#0F380F", titleInk: "#9BBC0F", shadow: "#0F380F",
                               wall: "#9BBC0F", floor: "#306230", trim: "#0F380F", mono: true)
        case .midnight:
            return ThemeColors(bg: "#1B1633", panel: "#241E44", ink: "#F2E9FF", subInk: "#A99BD6", accent: "#FF77A8",
                               border: "#F2E9FF", userBubble: "#29ADFF", userInk: "#0B0826", petBubble: "#2E2657",
                               error: "#FF6B6B", titleBar: "#FF77A8", titleInk: "#1B1633", shadow: "#0B0826",
                               wall: "#241E44", floor: "#3A2E66", trim: "#FF77A8")
        }
    }
}

struct ThemeColors {
    let bg, panel, ink, subInk, accent, border, userBubble, userInk, petBubble, error, titleBar, titleInk, shadow: Color
    let wall, floor, trim: Color
    let rounded: Bool

    let mono: Bool

    /// Rounded by default (friendly + legible); monospaced in retro mode and for the Terminal/Pocket themes.
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let retro = Prefs.shared.retroFrames
        let design: Font.Design = (retro || mono) && !rounded ? .monospaced : .rounded
        let w: Font.Weight = design == .rounded && weight == .bold ? .semibold : weight
        return .system(size: design == .rounded ? size + 0.5 : size, weight: w, design: design)
    }

    /// Soft (modern) chrome, unless the user turned on retro pixel frames.
    var soft: Bool { rounded || !Prefs.shared.retroFrames }

    init(bg: String, panel: String, ink: String, subInk: String, accent: String, border: String, userBubble: String,
         userInk: String, petBubble: String, error: String, titleBar: String, titleInk: String, shadow: String,
         wall: String, floor: String, trim: String, rounded: Bool = false, mono: Bool = false) {
        func c(_ h: String) -> Color { RGBA(hex: h).color }
        self.wall = c(wall); self.floor = c(floor); self.trim = c(trim); self.rounded = rounded; self.mono = mono
        self.bg = c(bg); self.panel = c(panel); self.ink = c(ink); self.subInk = c(subInk); self.accent = c(accent)
        self.border = c(border); self.userBubble = c(userBubble); self.userInk = c(userInk); self.petBubble = c(petBubble)
        self.error = c(error); self.titleBar = c(titleBar); self.titleInk = c(titleInk); self.shadow = c(shadow)
    }
}

enum RetroFont {
    private static var design: Font.Design { Prefs.shared.retroFrames ? .monospaced : .rounded }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, design: design) }
    static func bold(_ size: CGFloat = 13) -> Font { .system(size: size, weight: Prefs.shared.retroFrames ? .bold : .semibold, design: design) }
}

/// Motion tokens. Strong ease-out for anything entering or responding; nothing uses ease-in.
enum Motion {
    static let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
    static let tab = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    static let move = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.32)
    static let pop = Animation.spring(duration: 0.45, bounce: 0.25)

    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Fades a window in (opacity only, so it's fine under Reduce Motion too). Exits stay instant.
    static func fadeIn(_ window: NSWindow, duration: TimeInterval) {
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            window.animator().alphaValue = 1
        }
    }
    /// Movement is dropped under Reduce Motion; opacity changes stay (they aid comprehension).
    static func ifAllowed(_ a: Animation) -> Animation? { reduced ? .easeOut(duration: 0.15) : a }
}

/// A rectangle with stepped, pixel-style corners.
struct PixelRect: Shape {
    var notch: CGFloat = 3
    /// Soft (default) = continuous rounded corners; retro = stepped pixel corners (Settings → Retro frames).
    var soft: Bool = !Prefs.shared.retroFrames

    static func radius(forNotch n: CGFloat) -> CGFloat { n <= 0 ? 12 : min(16, n * 3.4) }

    func path(in r: CGRect) -> Path {
        if soft {
            return RoundedRectangle(cornerRadius: min(Self.radius(forNotch: notch), r.height / 2), style: .continuous).path(in: r)
        }
        let n = min(notch, r.width / 2, r.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY + n))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + n))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - n))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + n))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.minY + n))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// A card/box. Soft style: rounded, hairline border, soft shadow. Retro style: pixel corners, hard drop shadow.
    /// A thick `line` (≥ 2.5) marks an emphasized border (e.g. selected) and stays fully visible in soft style.
    @ViewBuilder
    func retroBox(fill: Color, border: Color, shadow: Color? = nil, notch: CGFloat = 3, line: CGFloat = 2, offset: CGFloat = 3) -> some View {
        if Prefs.shared.retroFrames {
            background(
                ZStack {
                    if let shadow { PixelRect(notch: notch).fill(shadow).offset(x: offset, y: offset) }
                    PixelRect(notch: notch).fill(fill)
                    PixelRect(notch: notch).strokeBorderCompat(border, lineWidth: line, notch: notch)
                }
            )
        } else {
            let emphasized = line >= 2.5
            background(
                PixelRect(notch: notch)
                    .fill(fill)
                    .shadow(color: .black.opacity(shadow == nil ? 0 : 0.08), radius: 1, y: 1)
                    .shadow(color: .black.opacity(shadow == nil ? 0 : 0.10), radius: 10, y: 4)
                    .overlay(PixelRect(notch: notch).strokeBorderCompat(border.opacity(emphasized ? 1 : 0.16), lineWidth: emphasized ? 2 : 1, notch: notch))
            )
        }
    }

    /// Outer chrome for our borderless windows (home, pop-ups).
    @ViewBuilder
    func windowChrome(_ t: ThemeColors) -> some View {
        if Prefs.shared.retroFrames {
            self.clipShape(PixelRect(notch: 4))
                .overlay(PixelRect(notch: 4).strokeBorderCompat(t.border, lineWidth: 3, notch: 4))
                .background(PixelRect(notch: 4).fill(t.shadow.opacity(0.9)).offset(x: 5, y: 5))
                .padding(EdgeInsets(top: 2, leading: 2, bottom: 8, trailing: 8))
        } else {
            self.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(t.ink.opacity(0.12), lineWidth: 1))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(t.bg).shadow(color: .black.opacity(0.22), radius: 18, y: 8))
                .padding(EdgeInsets(top: 8, leading: 12, bottom: 22, trailing: 12))
        }
    }

    /// Subtle press feedback for custom tappable views.
    func pressable() -> some View { buttonStyle(PressableStyle()) }
}

extension View {
    /// Outline + rounded clip in soft style; square outline in retro style.
    @ViewBuilder
    func outline(_ color: Color, _ width: CGFloat = 1, radius: CGFloat = 10) -> some View {
        if Prefs.shared.retroFrames {
            overlay(Rectangle().stroke(color, lineWidth: width))
        } else {
            clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: min(width, 2)))
        }
    }
}

/// Shared checkbox for to-dos and wants. The checkmark pops in (a small, occasional reward).
struct CheckBox: View {
    var on: Bool
    var t: ThemeColors

    var body: some View {
        let retro = Prefs.shared.retroFrames
        let shape = RoundedRectangle(cornerRadius: retro ? 0 : 5, style: .continuous)
        ZStack {
            shape.fill(on ? t.accent : t.petBubble)
            shape.strokeBorder(on ? t.accent : t.ink.opacity(retro ? 1 : 0.3), lineWidth: retro ? 2 : 1.5)
            Image(systemName: "checkmark")
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(t.bg)
                .scaleEffect(on ? 1 : 0.5)
                .opacity(on ? 1 : 0)
        }
        .frame(width: 17, height: 17)
        .animation(Motion.ifAllowed(Motion.pop), value: on)
    }
}

/// Plain button that scales to 0.97 while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !Motion.reduced ? 0.97 : 1)
            .opacity(configuration.isPressed && Motion.reduced ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension PixelRect {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat, notch: CGFloat) -> some View {
        GeometryReader { geo in
            PixelRect(notch: notch)
                .path(in: CGRect(origin: .zero, size: geo.size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
                .stroke(color, lineWidth: lineWidth)
        }
    }
}

struct RetroButtonStyle: ButtonStyle {
    var fill: Color
    var ink: Color
    var border: Color
    var shadow: Color
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        if Prefs.shared.retroFrames {
            return AnyView(configuration.label
                .font(RetroFont.bold(compact ? 11 : 12))
                .foregroundStyle(ink)
                .padding(.horizontal, compact ? 7 : 10)
                .padding(.vertical, compact ? 3 : 5)
                .background(ZStack {
                    PixelRect(notch: 2).fill(fill)
                    PixelRect(notch: 2).strokeBorderCompat(border, lineWidth: 2, notch: 2)
                })
                .offset(x: pressed ? 2 : 0, y: pressed ? 2 : 0)
                .background(PixelRect(notch: 2).fill(shadow).offset(x: 2, y: 2))
                .opacity(isEnabled ? 1 : 0.5)
                .contentShape(Rectangle()))
        }
        return AnyView(configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(ink)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 6.5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous).strokeBorder(.white.opacity(compact ? 0 : 0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(compact ? 0.06 : 0.14), radius: compact ? 1 : 3, y: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(pressed && !Motion.reduced ? 0.97 : 1)
            .animation(Motion.press, value: pressed)
            .contentShape(Rectangle()))
    }
}

extension ThemeColors {
    var button: RetroButtonStyle { RetroButtonStyle(fill: accent, ink: bg, border: border, shadow: shadow) }
    var quietButton: RetroButtonStyle {
        RetroButtonStyle(fill: Prefs.shared.retroFrames ? panel : ink.opacity(0.07), ink: ink, border: border, shadow: shadow, compact: true)
    }
}

/// Pixel-perfect sprite image for SwiftUI.
struct SpriteImage: View {
    var look: CreatureLook
    var pose: Pose = Pose()
    var colors: SpriteColors
    var size: CGFloat

    var body: some View {
        Image(nsImage: SpriteRenderer.nsImage(look: look, pose: pose, colors: colors))
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Lets a borderless window be dragged from a SwiftUI area (e.g. a custom title bar).
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A one-tap aesthetic: app theme + creature palette + held treat.
enum VibeMode: String, CaseIterable, Identifiable {
    case cafe, matcha, psp, strawberry, pocket, midnight, terminal
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cafe: return "Mochi Café"
        case .matcha: return "Matcha"
        case .psp: return "PSP"
        case .strawberry: return "Strawberry Milk"
        case .pocket: return "Pocket"
        case .midnight: return "Midnight"
        case .terminal: return "Terminal"
        }
    }

    var tagline: String {
        switch self {
        case .cafe: return "espresso, cream & cozy crumbs"
        case .matcha: return "whisked, calm, a little earthy"
        case .psp: return "piano black & glowing waves"
        case .strawberry: return "pink milk & sweet treats"
        case .pocket: return "four shades of green, 1989 energy"
        case .midnight: return "late-night lilac glow"
        case .terminal: return "green-on-black hacker hours"
        }
    }

    var ui: UITheme {
        switch self {
        case .cafe: return .cafe
        case .matcha: return .matcha
        case .psp: return .psp
        case .strawberry: return .strawberry
        case .pocket: return .pocket
        case .midnight: return .midnight
        case .terminal: return .terminal
        }
    }

    var palette: PalettePreset {
        switch self {
        case .cafe: return .espresso
        case .matcha: return .matcha
        case .psp: return .psp
        case .strawberry: return .strawberry
        case .pocket: return .pocket
        case .midnight: return .midnight
        case .terminal: return .mint
        }
    }

    var held: HeldItem {
        switch self {
        case .cafe: return .mug
        case .matcha: return .matcha
        case .psp, .pocket: return .handheld
        case .strawberry: return .boba
        case .midnight: return .notepad
        case .terminal: return .mug
        }
    }
}

/// Glossy animated waves, PSP-menu style. Cheap: one path per wave, ~20 fps, only while visible.
struct WaveBackground: View {
    var tint: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for i in 0..<3 {
                    var path = Path()
                    let amp = size.height * (0.06 + Double(i) * 0.025)
                    let mid = size.height * (0.55 + Double(i) * 0.06)
                    path.move(to: CGPoint(x: 0, y: mid))
                    stride(from: 0.0, through: size.width, by: 6).forEach { x in
                        let y = mid + sin(x / size.width * .pi * 2 * (1 + Double(i) * 0.3) + t * (0.35 + Double(i) * 0.12)) * amp
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                    gc.fill(path, with: .linearGradient(Gradient(colors: [tint.opacity(0.22 - Double(i) * 0.05), .clear]),
                                                        startPoint: CGPoint(x: 0, y: mid - amp), endPoint: CGPoint(x: 0, y: size.height)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
