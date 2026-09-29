import AppKit
import SwiftUI

/// Plain sRGB color used by the sprite engine and themes.
struct RGBA: Equatable, Hashable {
    var r: Double, g: Double, b: Double, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else {
            self.init(0, 0, 0); return
        }
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? .black
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
    }

    static let clear = RGBA(0, 0, 0, 0)
    static let white = RGBA(1, 1, 1)

    var hex: String {
        func c(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    func mix(_ o: RGBA, _ t: Double) -> RGBA {
        RGBA(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t)
    }

    func distance(_ o: RGBA) -> Double {
        let dr = r - o.r, dg = g - o.g, db = b - o.b
        return dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11
    }

    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// Core colors a creature palette is built from; everything else is derived.
struct PaletteBase: Equatable {
    var body: String
    var outline: String
    var cheek: String
    var accent: String
    var eye: String
    var shade: String? = nil
    var highlight: String? = nil
    var mug: String? = nil
    /// When set, every sprite color snaps to this limited palette (true retro look).
    var lock: [String]? = nil
}

enum PalettePreset: String, CaseIterable, Identifiable {
    case espresso, latte, matcha, strawberry, mint, pumpkin, midnight, psp, arcade, pocket, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .espresso: return "Espresso Cream"
        case .latte: return "Caramel Latte"
        case .matcha: return "Matcha"
        case .strawberry: return "Strawberry Milk"
        case .mint: return "Mint Choco"
        case .pumpkin: return "Pumpkin Spice"
        case .midnight: return "Midnight Lilac"
        case .psp: return "Piano Black"
        case .arcade: return "Arcade 8-bit"
        case .pocket: return "Pocket Green"
        case .custom: return "Custom"
        }
    }

    var base: PaletteBase? {
        switch self {
        case .espresso:
            return PaletteBase(body: "#F3E6CF", outline: "#3B2A22", cheek: "#E7A07E", accent: "#8FA37E", eye: "#2A1E18")
        case .latte:
            return PaletteBase(body: "#D9AE7E", outline: "#4A2E1F", cheek: "#E98C6B", accent: "#F4EBD8", eye: "#2A1A12", mug: "#8FA37E")
        case .matcha:
            return PaletteBase(body: "#B9CE9C", outline: "#2F3B26", cheek: "#EBA3A3", accent: "#F6EED8", eye: "#1F2A18")
        case .strawberry:
            return PaletteBase(body: "#F8CBD3", outline: "#5A2A3A", cheek: "#E8708C", accent: "#9ED9CC", eye: "#3A1A26")
        case .mint:
            return PaletteBase(body: "#A9E4CF", outline: "#3B2A22", cheek: "#F2A5A5", accent: "#6B4430", eye: "#2A1E18")
        case .pumpkin:
            return PaletteBase(body: "#E39A4E", outline: "#3D2412", cheek: "#C8553D", accent: "#4E6B3A", eye: "#2A1608")
        case .midnight:
            return PaletteBase(body: "#B8A9E8", outline: "#1B1633", cheek: "#FF8FB1", accent: "#FFD166", eye: "#1B1633")
        case .psp:
            return PaletteBase(body: "#DCE3EE", outline: "#10131C", cheek: "#8DB4FF", accent: "#2F7BEA", eye: "#10131C",
                               shade: "#AAB6C8", highlight: "#FFFFFF", mug: "#1E2230")
        case .arcade:
            return PaletteBase(body: "#FFCCAA", outline: "#1D2B53", cheek: "#FF77A8", accent: "#29ADFF", eye: "#1D2B53", mug: "#FFF1E8",
                               lock: ["#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F", "#C2C3C7", "#FFF1E8",
                                      "#FF004D", "#FFA300", "#FFEC27", "#00E436", "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"])
        case .pocket:
            return PaletteBase(body: "#8BAC0F", outline: "#0F380F", cheek: "#306230", accent: "#306230", eye: "#0F380F",
                               shade: "#306230", highlight: "#9BBC0F", mug: "#9BBC0F",
                               lock: ["#0F380F", "#306230", "#8BAC0F", "#9BBC0F"])
        case .custom:
            return nil
        }
    }
}

/// Resolved color for every sprite material.
struct SpriteColors: Equatable {
    var table: [RGBA]
    var lock: [RGBA] = []

    /// Snaps an arbitrary prop color to the locked palette, if any.
    func snap(_ c: RGBA) -> RGBA {
        guard !lock.isEmpty else { return c }
        return lock.min(by: { $0.distance(c) < $1.distance(c) }) ?? c
    }

    subscript(m: Mat) -> RGBA { table[Int(m.rawValue)] }

    static func make(_ p: PaletteBase) -> SpriteColors {
        let body = RGBA(hex: p.body), outline = RGBA(hex: p.outline)
        let accent = RGBA(hex: p.accent)
        let mug = p.mug.map(RGBA.init(hex:)) ?? RGBA(hex: "#FFF8EC")
        var t = [RGBA](repeating: .clear, count: Mat.allCases.count)
        func set(_ m: Mat, _ c: RGBA) { t[Int(m.rawValue)] = c }
        set(.outline, outline)
        set(.body, body)
        set(.shade, p.shade.map(RGBA.init(hex:)) ?? body.mix(outline, 0.2))
        set(.highlight, p.highlight.map(RGBA.init(hex:)) ?? body.mix(.white, 0.45))
        set(.belly, body.mix(.white, 0.55))
        set(.cheek, RGBA(hex: p.cheek))
        set(.eye, RGBA(hex: p.eye))
        set(.white, .white)
        set(.accent, accent)
        set(.accentDark, accent.mix(outline, 0.35))
        set(.mug, mug)
        set(.mugShade, mug.mix(outline, 0.2))
        set(.gold, RGBA(hex: "#F2C14E"))
        set(.goldDark, RGBA(hex: "#C68B2C"))
        set(.leaf, RGBA(hex: "#8FBF6A"))
        set(.leafDark, RGBA(hex: "#5E8C45"))
        set(.tea, RGBA(hex: "#D8B08C"))
        set(.shadow, RGBA(0, 0, 0, 0.2))
        set(.steam, RGBA(1, 1, 1, 0.6))
        set(.bubble, .white)
        set(.ink, outline)
        set(.heart, RGBA(hex: "#E4576E"))
        set(.yellow, RGBA(hex: "#F7D154"))
        set(.purple, RGBA(hex: "#8A6AD8"))
        set(.purpleDark, RGBA(hex: "#4E3591"))
        set(.black, RGBA(hex: "#26222E"))
        set(.drop, RGBA(hex: "#6FA8DC"))

        if let lock = p.lock?.map(RGBA.init(hex:)), !lock.isEmpty {
            for i in t.indices where t[i].a > 0.99 {
                let c = t[i]
                t[i] = lock.min(by: { $0.distance(c) < $1.distance(c) }) ?? c
            }
            // Keep the effect halo readable on a locked palette.
            t[Int(Mat.bubble.rawValue)] = lock.max(by: { ($0.r + $0.g + $0.b) < ($1.r + $1.g + $1.b) }) ?? .white
            return SpriteColors(table: t, lock: lock)
        }
        return SpriteColors(table: t)
    }
}

extension PaletteBase {
    /// Pastel body in any hue — used for the secret rainbow mode.
    static func rainbow(hue: Double, over base: PaletteBase) -> PaletteBase {
        var p = base
        p.body = RGBA(NSColor(hue: CGFloat(hue.truncatingRemainder(dividingBy: 1)), saturation: 0.38, brightness: 0.98, alpha: 1)).hex
        p.shade = nil; p.highlight = nil; p.lock = nil
        return p
    }

    static let spooky = PaletteBase(body: "#DDE6F5", outline: "#2A2F4A", cheek: "#9FB4E0", accent: "#6A5ACD", eye: "#2A2F4A")
}
