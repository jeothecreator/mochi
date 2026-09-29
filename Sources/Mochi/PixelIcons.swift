import AppKit
import SwiftUI

/// Small hand-drawn pixel icons with their own fixed colors (foods, souvenirs, critters, props).
struct PixelIcon: Equatable {
    let rows: [String]
    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    static let colorMap: [Character: String] = [
        "o": "#2B1D16", "w": "#FFFFFF", "c": "#F3E6CF", "b": "#C8894F", "d": "#7A4B2A",
        "g": "#8FBF6A", "G": "#4E7A3A", "m": "#B9D38C", "r": "#E4576E", "p": "#F6A5B7",
        "y": "#F7D154", "Y": "#C99A2E", "s": "#8FB8DE", "S": "#4F7FB0", "k": "#1D1D24",
        "K": "#6A6F7C", "l": "#C9CED8", "t": "#D8B08C", "v": "#B69AF0", "V": "#6A4FA8",
        "e": "#9AD6E8",
    ]

    /// Cell colors, row-major; nil = transparent.
    func cells() -> [RGBA?] {
        var out = [RGBA?](repeating: nil, count: width * height)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if let hex = Self.colorMap[ch] { out[y * width + x] = RGBA(hex: hex) }
            }
        }
        return out
    }

    func cgImage(lock: [RGBA]? = nil) -> CGImage {
        let w = width, h = height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for (i, c) in cells().enumerated() {
            guard var c else { continue }
            if let lock, !lock.isEmpty { c = lock.min(by: { $0.distance(c) < $1.distance(c) }) ?? c }
            bytes[i * 4] = UInt8(c.r * 255); bytes[i * 4 + 1] = UInt8(c.g * 255)
            bytes[i * 4 + 2] = UInt8(c.b * 255); bytes[i * 4 + 3] = 255
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    var nsImage: NSImage { NSImage(cgImage: cgImage(), size: NSSize(width: width, height: height)) }

    // MARK: Foods (8×8)

    static let cookie = PixelIcon(rows: ["..oooo..", ".obbdbo.", "obdbbbbo", "obbbbdbo", "obbdbbbo", "obdbbbdo", ".obbbbo.", "..oooo.."])
    static let onigiri = PixelIcon(rows: ["...oo...", "..owwo..", ".owwwwo.", ".owwwwo.", "owwwwwwo", "owkkkkwo", "okkkkkko", ".oooooo."])
    static let strawberry = PixelIcon(rows: ["..oGGo..", ".oGggGo.", "orrGGrro", "orryrrro", "orrrryro", ".oyrrro.", "..orro..", "...oo..."])
    static let matcha = PixelIcon(rows: ["oooooo..", "omwmmo..", "occccooo", "oggggo.o", "occccooo", "occcco..", ".oooo...", "........"])
    static let boba = PixelIcon(rows: ["....o...", "...o....", "oooooooo", "owwwwwwo", ".otttto.", ".otktko.", ".oktkto.", "..oooo.."])
    static let fish = PixelIcon(rows: ["..oooo....", ".ossssoo.o", "oksssssoso", "osssssssoo", ".oSSSSoo.o", "..oooo...."])
    static let cake = PixelIcon(rows: ["...r....", "..oro...", ".owwwwo.", "owwwwwwo", "oppppppo", "obbbbbbo", "oppppppo", "oooooooo"])

    // MARK: Souvenirs & items

    static let coin = PixelIcon(rows: ["..oooo..", ".oyyyyo.", "oyyYyyyo", "oyYyyyyo", "oyYyyyyo", "oyyyyyYo", ".oyyyyo.", "..oooo.."])
    static let heart = PixelIcon(rows: [".oo.oo.", "orrorro", "orrrrro", ".orrro.", "..oro..", "...o..."])
    static let star = PixelIcon(rows: ["....o....", "...oyo...", "oooyyyooo", "oyyyyyyyo", ".oyyyyyo.", "..oyyyo..", ".oyyoyyo.", ".oyo.oyo.", ".oo...oo."])
    static let shell = PixelIcon(rows: ["...oo...", "..oppo..", ".opwppo.", "oppwpppo", "opwppwpo", "oppwppwo", ".oooooo.", "..o..o.."])
    static let acorn = PixelIcon(rows: ["..oooo..", ".oddddo.", "oddddddo", "oooooooo", ".obbbbo.", ".obbbbo.", "..obbo..", "...oo..."])
    static let gem = PixelIcon(rows: ["..oooo..", ".ovvwvo.", "ovvwvVvo", "oVvvvvVo", ".oVvvVo.", "..oVVo..", "...oo...", "........"])
    static let feather = PixelIcon(rows: ["......oo", ".....oeo", "....oeeo", "...oeeSo", "..oeeSo.", ".oeeSo..", ".oSSo...", "o.oo...."])
    static let goldenFish = PixelIcon(rows: ["..oooo....", ".oyyyyoo.o", "okyyyyyoyo", "oyyyyyyyoo", ".oYYYYoo.o", "..oooo...."])
    static let gift = PixelIcon(rows: [".oo..oo...", "orro.orro.", ".oorrroo..", "oooooooooo", "ovvvrrvvvo", "oooooooooo", ".ovvrrvvo.", ".ovvrrvvo.", ".ovvrrvvo.", ".oooooooo."])
    static let plant = PixelIcon(rows: ["..g.g...", ".ggGgg..", "..gGg.g.", ".g.G.gg.", "oooooooo", "obbbbbbo", ".obbbbo.", ".obbbbo.", "..oooo.."])
    static let tomato = PixelIcon(rows: ["...Gg...", ".oGgGo..", "orrrrro.", "orwrrrro", "orrrrrro", "orrrrrro", ".orrrro.", "..oooo.."])
    static let bag = PixelIcon(rows: ["..oooo..", ".o....o.", "oooooooo", "obbbbbbo", "obbyybbo", "obbbbbbo", "obbbbbbo", "oooooooo"])
    static let note = PixelIcon(rows: ["oooooooo", "oyyyyyyo", "oyKKKyyo", "oyyyyyyo", "oyKKKKyo", "oyyyyyyo", "oyKKyyyo", "oooooooo"])
    static let handheld = PixelIcon(rows: [".oooooooooo.", "okkkkkkkkkko", "okKkSSSSkyko", "oKKKSeeSkkro", "okKkSSSSkgko", "okkkkkkkkkko", ".oooooooooo."])
    static let sign = PixelIcon(rows: ["oooooooooo", "obbbbbbbbo", "obKKbKKKbo", "obbbbbbbbo", "oooooooooo", "....ob....", "....ob....", "....ob....", "...oooo..."])

    // MARK: Critters (walk across the screen)

    static let ladybug = PixelIcon(rows: ["..o..o..", "...oo...", ".okkkko.", "orrkrrro", "orkrrkro", "orrrkrro", ".oooooo."])
    static let ghost = PixelIcon(rows: ["..oooooo..", ".owwwwwwo.", "owwwwwwwwo", "owkwwwkwwo", "owkwwwkwwo", "owwwwwwwwo", "owwwkkwwwo", "owwwwwwwwo", "owowwowwoo", "o.o.oo.o.o"])
    static let balloon = PixelIcon(rows: ["..ooo..", ".orrwo.", "orrrrwo", "orrrrro", "orrrrro", ".orrro.", "..ooo..", "...o...", "...o...", "....o..", "...o..."])
    static let cloud = PixelIcon(rows: ["...oooo.....", "..owwwwoooo.", ".owwwwwwwwwo", "owwwwwwwwwwo", ".oooooooooo."])

    // MARK: Egg (onboarding)

    /// A speckled egg; `crack` 0…3 adds cracks.
    static func egg(crack: Int) -> PixelIcon {
        let w = 18, h = 22
        var grid = [[Character]](repeating: [Character](repeating: ".", count: w), count: h)
        let cx = 9.0, cy = 12.0
        func inside(_ x: Int, _ y: Int) -> Bool {
            let px = Double(x) + 0.5, py = Double(y) + 0.5
            let ry = py < cy ? 10.5 : 9.0
            let dx = (px - cx) / 7.6, dy = (py - cy) / ry
            return dx * dx + dy * dy <= 1
        }
        for y in 0..<h { for x in 0..<w where inside(x, y) { grid[y][x] = "c" } }
        for (x, y) in [(6, 7), (11, 5), (12, 11), (5, 14), (9, 17), (13, 16), (8, 10)] where grid[y][x] == "c" {
            grid[y][x] = "b"
            if x + 1 < w, grid[y][x + 1] == "c" { grid[y][x + 1] = "t" }
        }
        for y in 0..<h { for x in 0..<w where grid[y][x] != "." && (x > 9 && y > 12) && !inside(x + 1, y + 1) { grid[y][x] = "t" } }
        let cracks: [[(Int, Int)]] = [
            [(10, 8), (11, 9), (12, 8), (13, 9)],
            [(4, 11), (5, 12), (6, 11), (7, 12), (8, 11)],
            [(9, 3), (8, 4), (9, 5), (10, 6), (9, 7), (14, 12), (13, 13)],
        ]
        for stage in 0..<min(crack, 3) { for (x, y) in cracks[stage] where grid[y][x] != "." { grid[y][x] = "o" } }
        var out = grid
        for y in 0..<h {
            for x in 0..<w where grid[y][x] == "." {
                let n = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if n.contains(where: { $0.0 >= 0 && $0.0 < w && $0.1 >= 0 && $0.1 < h && grid[$0.1][$0.0] != "." }) { out[y][x] = "o" }
            }
        }
        return PixelIcon(rows: out.map { String($0) })
    }
}

/// SwiftUI view for a pixel icon at an integer scale.
struct IconImage: View {
    var icon: PixelIcon
    var scale: CGFloat = 3
    var body: some View {
        Image(nsImage: icon.nsImage)
            .interpolation(.none)
            .resizable()
            .frame(width: CGFloat(icon.width) * scale, height: CGFloat(icon.height) * scale)
            .accessibilityHidden(true)
    }
}
