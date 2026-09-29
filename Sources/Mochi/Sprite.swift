import AppKit
import CoreGraphics

// MARK: - Creature options

enum Species: String, CaseIterable, Identifiable {
    case mochi, kitty, bunny, bear, sprout, ghost
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mochi: return "Mochi"
        case .kitty: return "Kitty"
        case .bunny: return "Bun"
        case .bear: return "Cub"
        case .sprout: return "Sprout"
        case .ghost: return "Boo"
        }
    }
}

enum EyeStyle: String, CaseIterable, Identifiable {
    case bean, dot, sparkle, sleepy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bean: return "Bean"
        case .dot: return "Dot"
        case .sparkle: return "Sparkle"
        case .sleepy: return "Sleepy"
        }
    }
}

enum Accessory: String, CaseIterable, Identifiable {
    case none, beret, beanie, bow, crown, flower, headphones, glasses, partyHat, flowerCrown, bandana
    case wizard, halo, frogHat, witchHat
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .beret: return "Beret"
        case .beanie: return "Beanie"
        case .bow: return "Bow"
        case .crown: return "Crown"
        case .flower: return "Flower"
        case .headphones: return "Headphones"
        case .glasses: return "Glasses"
        case .partyHat: return "Party hat"
        case .flowerCrown: return "Flower crown"
        case .bandana: return "Bandana"
        case .wizard: return "Wizard hat"
        case .halo: return "Halo"
        case .frogHat: return "Frog hat"
        case .witchHat: return "Witch hat"
        }
    }

    /// Secret outfits are unlocked by discoveries.
    var isSecret: Bool { [.wizard, .halo, .frogHat, .witchHat].contains(self) }

    var unlockHint: String {
        switch self {
        case .wizard: return "Open a legendary mystery package."
        case .halo: return "Be very, very persistent with pokes."
        case .frogHat: return "Give your pet something golden."
        case .witchHat: return "Visit in the spookiest hour."
        default: return ""
        }
    }
}

enum HeldItem: String, CaseIterable, Identifiable {
    case none, mug, boba, matcha, notepad, handheld
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Nothing"
        case .mug: return "Coffee mug"
        case .boba: return "Boba tea"
        case .matcha: return "Matcha latte"
        case .notepad: return "Notepad"
        case .handheld: return "Handheld"
        }
    }
}

struct CreatureLook: Equatable {
    var species: Species = .mochi
    var eyes: EyeStyle = .bean
    var accessory: Accessory = .beret
    var held: HeldItem = .mug
    var blush = true
}

enum Expression: Equatable { case normal, blink, happy, sleep, surprised, chomp, dizzy, sad, love }

enum Effect: Equatable {
    case none
    case zzz(Int)
    case thinking(Int)
    case hearts(Int)
    case alert
    case sparkles(Int)
    case rain(Int)
    case balloon
    case question
    case stars(Int)
    case sweat
    case music(Int)
    case coin(Int)
}

/// One animation frame's worth of state.
struct Pose: Equatable {
    var breath = 0
    var lookX = 0
    var lookY = 0
    var expression: Expression = .normal
    var sipping = false
    var hop = 0
    var steam = 0
    var wiggle = 0
    var effect: Effect = .none
    /// Food being eaten (drawn at the mouth), and how many bites are gone (0…2).
    var food: Food? = nil
    var bite = 0
    var squash = false
    var flipped = false
}

// MARK: - Pixel grid

enum Mat: UInt8, CaseIterable {
    case empty, outline, body, shade, highlight, belly, cheek, eye, white
    case accent, accentDark, mug, mugShade, gold, goldDark, leaf, leafDark, tea
    case shadow, steam, bubble, ink, heart, yellow, purple, purpleDark, black, drop

    /// Solid materials get an automatic outline around them.
    var isSolid: Bool {
        switch self {
        case .empty, .outline, .shadow, .steam, .ink, .bubble, .drop: return false
        default: return true
        }
    }

    static let stampMap: [Character: Mat] = [
        "o": .outline, "B": .body, "S": .shade, "H": .highlight, "W": .white, "A": .accent, "a": .accentDark,
        "M": .mug, "m": .mugShade, "G": .gold, "g": .goldDark, "L": .leaf, "l": .leafDark, "T": .tea,
        "k": .eye, "P": .cheek, "h": .heart, "b": .bubble, "i": .ink, "Y": .yellow, "s": .steam,
        "V": .purple, "U": .purpleDark, "K": .black, "D": .drop,
    ]
}

struct PixelGrid {
    static let size = 32
    var cells = [Mat](repeating: .empty, count: 32 * 32)

    subscript(x: Int, y: Int) -> Mat {
        get {
            guard x >= 0, y >= 0, x < Self.size, y < Self.size else { return .empty }
            return cells[y * Self.size + x]
        }
        set {
            guard x >= 0, y >= 0, x < Self.size, y < Self.size else { return }
            cells[y * Self.size + x] = newValue
        }
    }

    /// Draws ASCII art. `mirrored` reflects across the sprite's vertical center line.
    mutating func stamp(_ rows: [String], x: Int, y: Int, mirrored: Bool = false) {
        for (j, row) in rows.enumerated() {
            for (i, ch) in row.enumerated() {
                guard let m = Mat.stampMap[ch] else { continue }
                let px = mirrored ? (Self.size - 1) - (x + i) : x + i
                self[px, y + j] = m
            }
        }
    }
}

// MARK: - Builder

enum SpriteBuilder {
    static func build(_ look: CreatureLook, _ pose: Pose) -> (base: PixelGrid, props: [RGBA?], fx: PixelGrid) {
        var g = PixelGrid()
        let sp = look.species

        var rx: Double, ry: Double
        switch sp {
        case .mochi: rx = 11; ry = 7.5
        case .ghost: rx = 9; ry = 9.5
        default: rx = 10; ry = 8
        }
        if pose.breath == 1 { ry += 0.6; rx -= 0.35 }
        if pose.squash { ry -= 1.8; rx += 1.3 }
        let float = sp == .ghost ? 2 : 0
        let bottomEdge = 29.0 - Double(pose.hop + float)
        let cx = 16.0
        let cy = bottomEdge - ry

        // Ground shadow.
        let shRx = max(3.0, (sp == .ghost ? 6.0 : rx * 0.8) - Double(pose.hop) * 0.8)
        for y in 28...30 {
            for x in 0..<32 {
                let dx = (Double(x) + 0.5 - cx) / shRx, dy = (Double(y) + 0.5 - 29.6) / 1.3
                if dx * dx + dy * dy <= 1 { g[x, y] = .shadow }
            }
        }

        // Body: a soft superellipse, rounder on top, flatter on the bottom.
        func inside(_ x: Int, _ y: Int) -> Bool {
            let px = Double(x) + 0.5, py = Double(y) + 0.5
            let dx = abs(px - cx) / rx, dy = abs(py - cy) / ry
            let e = py > cy ? (sp == .ghost ? 4.0 : 3.0) : 2.2
            return pow(dx, e) + pow(dy, e) <= 1
        }
        for y in 0..<32 { for x in 0..<32 where inside(x, y) { g[x, y] = .body } }

        if sp == .ghost {
            let row = Int(bottomEdge) - 1
            for x in 0..<32 where g[x, row] == .body && ((x + pose.wiggle) / 2) % 2 == 1 {
                g[x, row] = .empty
            }
        }

        let head = g
        func isHead(_ x: Int, _ y: Int) -> Bool { head[x, y] == .body }
        var topY = 0
        for y in 0..<32 where isHead(15, y) { topY = y; break }
        func span(_ y: Int) -> (Int, Int)? {
            var l: Int?, r = 0
            for x in 0..<32 where isHead(x, y) { if l == nil { l = x }; r = x }
            return l.map { ($0, r) }
        }

        // Ears.
        switch sp {
        case .kitty:
            let ear = ["B....", "BB...", "BPB..", "BPPB.", "BBBBB"]
            g.stamp(ear, x: 9, y: topY - 3)
            g.stamp(ear, x: 9, y: topY - 3, mirrored: true)
        case .bunny:
            let ear = [".BB.", "BBBB", "BPPB", "BPPB", "BPPB", "BPPB", "BBBB", ".BB."]
            let tilt = pose.wiggle == 1 ? 1 : 0
            g.stamp(ear, x: 10, y: topY - 7)
            g.stamp(ear, x: 10 - tilt, y: topY - 7 + tilt, mirrored: true)
        case .bear:
            for y in (topY - 4)...(topY + 3) {
                for x in 0..<32 {
                    for ecx in [10.5, 21.5] {
                        let d = hypot(Double(x) + 0.5 - ecx, Double(y) + 0.5 - (Double(topY) + 1.2))
                        if d <= 1.2 { g[x, y] = .cheek } else if d <= 2.7, g[x, y] != .cheek { g[x, y] = .body }
                    }
                }
            }
            // A seam where the ears meet the head.
            let withEars = g
            for y in 0..<32 {
                for x in 0..<32 where !isHead(x, y) && withEars[x, y] == .body && isHead(x, y + 1) {
                    g[x, y] = .outline
                }
            }
        case .sprout:
            g.stamp(["LL...LL", "LLL.LLL", ".LLlLL.", "...l...", "...l..."], x: 12, y: topY - 5)
        case .mochi, .ghost:
            break
        }

        // Shading: highlight rim top-left, shade rim bottom-right, plus a shine.
        let base = g
        func b(_ x: Int, _ y: Int) -> Bool { let m = base[x, y]; return m == .body || m == .cheek }
        let cyI = Int(cy)
        for y in 0..<32 {
            for x in 0..<32 where base[x, y] == .body {
                let rimBR = !b(x + 1, y) || !b(x, y + 1) || (!b(x, y + 2) && y > cyI)
                let rimTL = !b(x - 1, y) || !b(x, y - 1)
                if rimBR && (y >= cyI || x >= 16) { g[x, y] = .shade }
                else if rimTL && y < cyI && x < 16 { g[x, y] = .highlight }
            }
        }
        let shineX = Int(cx - rx * 0.55), shineY = topY + 2
        if b(shineX, shineY) && b(shineX + 1, shineY) {
            g[shineX, shineY] = .white; g[shineX + 1, shineY] = .white; g[shineX, shineY + 1] = .white
        }

        if sp == .bear || sp == .bunny {
            let bcy = cy + ry * 0.45
            for y in 0..<32 {
                for x in 0..<32 where g[x, y] == .body {
                    let dx = (Double(x) + 0.5 - cx) / (rx * 0.45), dy = (Double(y) + 0.5 - bcy) / (ry * 0.4)
                    if dx * dx + dy * dy <= 1 { g[x, y] = .belly }
                }
            }
        }

        // Face.
        let eyeBase = Int((cy - 1).rounded(.down))
        let lx = pose.lookX
        let eyeY = eyeBase + pose.lookY
        let my = eyeBase + 3, mx = 15 + lx

        func eye(_ ex: Int, right: Bool) {
            let o = right ? ex : ex - 1 // 3-wide shapes stay symmetric
            switch pose.expression {
            case .dizzy:
                for (dx, dy) in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)] { g[o + dx, eyeY + dy] = .eye }
                return
            case .love:
                for (dx, dy) in [(0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)] { g[o + dx, eyeY + dy] = .heart }
                return
            case .sad:
                for y in (eyeY + 1)...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                g[right ? ex + 1 : ex, eyeY] = .shade
                return
            case .chomp:
                g[ex - 1, eyeY + 2] = .eye; g[ex, eyeY + 1] = .eye; g[ex + 1, eyeY + 1] = .eye; g[ex + 2, eyeY + 2] = .eye
                return
            default: break
            }
            switch pose.expression {
            case .blink, .sleep:
                g[ex, eyeY + 2] = .eye; g[ex + 1, eyeY + 2] = .eye
            case .happy:
                g[ex - 1, eyeY + 2] = .eye; g[ex, eyeY + 1] = .eye; g[ex + 1, eyeY + 1] = .eye; g[ex + 2, eyeY + 2] = .eye
            case .surprised:
                for y in eyeY...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                g[ex + 1, eyeY] = .white
            case .normal, .dizzy, .love, .sad, .chomp:
                switch look.eyes {
                case .bean:
                    for y in eyeY...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                    g[ex, eyeY] = .white
                case .dot:
                    for y in (eyeY + 1)...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                case .sparkle:
                    for y in eyeY...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                    g[ex, eyeY] = .white; g[ex + 1, eyeY + 2] = .white
                case .sleepy:
                    g[ex, eyeY] = .shade; g[ex + 1, eyeY] = .shade
                    for y in (eyeY + 1)...(eyeY + 2) { g[ex, y] = .eye; g[ex + 1, y] = .eye }
                }
            }
        }
        eye(11 + lx, right: false)
        eye(19 + lx, right: true)

        switch pose.expression {
        case .surprised:
            g[mx, my] = .eye; g[mx + 1, my] = .eye; g[mx, my + 1] = .eye; g[mx + 1, my + 1] = .eye
        case .sleep:
            g[mx, my] = .eye; g[mx + 1, my] = .eye
        case .happy, .love, .chomp:
            if pose.expression == .chomp && pose.wiggle == 1 {
                g[mx, my] = .eye; g[mx + 1, my] = .eye
            } else {
                for x in (mx - 1)...(mx + 2) { g[x, my] = .eye }
                g[mx, my + 1] = .cheek; g[mx + 1, my + 1] = .cheek
            }
        case .dizzy:
            for (dx, dy) in [(-1, 1), (0, 0), (1, 1), (2, 0)] { g[mx + dx, my + dy] = .eye }
        case .sad:
            for (dx, dy) in [(-1, 1), (0, 0), (1, 0), (2, 1)] { g[mx + dx, my + dy] = .eye }
        case .normal, .blink:
            if sp == .kitty {
                for (dx, dy) in [(-2, 0), (-1, 1), (0, 0), (1, 0), (2, 1), (3, 0)] { g[mx + dx, my + dy] = .eye }
            } else {
                for (dx, dy) in [(-1, 0), (0, 1), (1, 1), (2, 0)] { g[mx + dx, my + dy] = .eye }
            }
        }

        if look.blush {
            for x in [9, 10, 21, 22] where b(x + lx, my) { g[x + lx, my] = .cheek }
        }

        // Accessories.
        switch look.accessory {
        case .none:
            break
        case .beanie:
            for y in (topY - 1)...(topY + 3) {
                guard let s = span(max(y, topY)) else { continue }
                var l = s.0 - 1, r = s.1 + 1
                if y == topY - 1 { l = s.0 + 1; r = s.1 - 1 }
                guard l <= r else { continue }
                for x in l...r {
                    if y == topY + 3 { g[x, y] = x % 2 == 0 ? .accentDark : .accent }
                    else { g[x, y] = (y == topY + 1 && x % 3 == 0) ? .accentDark : .accent }
                }
            }
            g.stamp([".WW.", "WWWW"], x: 14, y: topY - 3)
        case .beret:
            let rows: [(Int, Int, Int)] = [(topY - 2, 10, 17), (topY - 1, 8, 21), (topY, 8, 22), (topY + 1, 11, 21)]
            for (i, row) in rows.enumerated() {
                for x in row.1...row.2 { g[x, row.0] = i == 3 ? .accentDark : .accent }
            }
            g[16, topY - 3] = .accentDark
        case .bow:
            g.stamp(["AA.AA", "AAaAA", "AA.AA"], x: 18, y: topY - 1)
        case .crown:
            g.stamp(["G..GG..G", "GG.GG.GG", "GGGAAGGG", "GgGggGgG"], x: 12, y: topY - 3)
        case .flower:
            g.stamp([".P.", "PYP", ".P."], x: 8, y: topY)
            g[11, topY + 2] = .leaf
        case .headphones:
            for y in 0...max(0, eyeBase - 2) {
                for x in 0..<32 where g[x, y] == .empty || g[x, y] == .shadow {
                    var near1 = false, near2 = false
                    for dy in -2...2 {
                        for dx in -2...2 where isHead(x + dx, y + dy) {
                            if abs(dx) <= 1 && abs(dy) <= 1 { near1 = true } else { near2 = true }
                        }
                    }
                    if near2 && !near1 { g[x, y] = .accentDark }
                }
            }
            if let s = span(eyeBase) {
                let cup = ["AAA", "AaA", "AaA", "AaA", "AAA"]
                g.stamp(cup, x: s.0 - 2, y: eyeBase - 2)
                g.stamp(cup, x: s.0 - 2, y: eyeBase - 2, mirrored: true)
            }
        case .glasses:
            for ex in [11 + lx, 19 + lx] {
                for x in (ex - 1)...(ex + 2) {
                    for y in (eyeBase - 1)...(eyeBase + 3) {
                        let edgeX = x == ex - 1 || x == ex + 2, edgeY = y == eyeBase - 1 || y == eyeBase + 3
                        if (edgeX || edgeY) && !(edgeX && edgeY) { g[x, y] = .outline }
                    }
                }
            }
            for x in (14 + lx)...(17 + lx) { g[x, eyeBase] = .outline }
        case .partyHat:
            for i in 0..<6 {
                let y = topY - 6 + i, half = i / 2
                for x in (15 - half)...(16 + half) { g[x, y] = i % 2 == 1 ? .accentDark : .accent }
            }
            g[15, topY - 7] = .white; g[16, topY - 7] = .white
        case .flowerCrown:
            let petals: [Mat] = [.cheek, .leaf, .yellow, .leaf]
            for x in 11...20 { g[x, topY - 1] = petals[x % 4] }
            g[10, topY] = .leaf; g[21, topY] = .leaf
            g[13, topY - 2] = .cheek; g[18, topY - 2] = .yellow
        case .bandana:
            if let s = span(topY + 2), let s2 = span(topY + 3) {
                for x in (s.0 - 1)...(s.1 + 1) { g[x, topY + 2] = .accent }
                for x in (s2.0 - 1)...(s2.1 + 1) { g[x, topY + 3] = x % 3 == 0 ? .white : .accent }
                g.stamp(["AA", "A.", "AA"], x: s2.1 + 2, y: topY + 2)
            }
        case .wizard:
            for x in 9...22 { g[x, topY] = .purpleDark }
            for i in 0..<8 {
                let y = topY - 8 + i, half = max(0, (i - 1) / 2)
                let shift = i < 3 ? 2 - i : 0
                for x in (15 - half + shift)...(16 + half + shift) { g[x, y] = .purple }
            }
            g[15, topY - 4] = .yellow; g[16, topY - 5] = .yellow; g[18, topY - 2] = .yellow
        case .halo:
            for x in 13...18 { g[x, topY - 6] = .yellow; g[x, topY - 4] = .yellow }
            g[12, topY - 5] = .yellow; g[19, topY - 5] = .yellow
        case .frogHat:
            if let s = span(topY + 1) {
                for y in (topY - 1)...(topY + 1) {
                    let sp = span(max(y, topY)) ?? s
                    for x in (sp.0 - 1)...(sp.1 + 1) { g[x, y] = .leaf }
                }
                for x in (s.0 - 1)...(s.1 + 1) { g[x, topY + 1] = .leafDark }
            }
            let eyeBump = [".LLL.", "LWWWL", "LWKWL", "LLLLL"]
            g.stamp(eyeBump, x: 9, y: topY - 4)
            g.stamp(eyeBump, x: 9, y: topY - 4, mirrored: true)
        case .witchHat:
            for x in 8...23 { g[x, topY] = .black }
            for x in 11...20 { g[x, topY - 1] = x % 2 == 0 ? .purple : .black }
            for i in 0..<7 {
                let y = topY - 8 + i, half = i / 2
                let shift = i < 3 ? 3 - i : 0
                for x in (15 - half + shift)...(16 + half + shift) { g[x, y] = .black }
            }
        }

        // Held item.
        var fx = PixelGrid()
        var props = [RGBA?](repeating: nil, count: 32 * 32)
        func prop(_ icon: PixelIcon, x: Int, y: Int, cropRight: Int = 0) {
            let cells = icon.cells()
            for j in 0..<icon.height {
                for i in 0..<(icon.width - cropRight) {
                    guard let c = cells[j * icon.width + i] else { continue }
                    let px = x + i, py = y + j
                    if px >= 0, py >= 0, px < 32, py < 32 { props[py * 32 + px] = c }
                }
            }
        }
        let bottomRow = Int(bottomEdge) - 1
        let paw = [".oo.", "oBBo", ".oo."]
        let eating = pose.food != nil
        switch look.held {
        case .none:
            break
        case .mug:
            let sip = pose.sipping && !eating
            let mx0 = sip ? 13 + lx : 22
            let my0 = sip ? eyeBase + 3 : bottomRow - 5
            g.stamp(["oooooo..", "oWMMmoo.", "oAAAao.o", "oMMMmo.o", "oMMMmoo.", ".oooo..."], x: mx0, y: my0)
            g.stamp(paw, x: mx0 - 2, y: my0 + 2)
            if pose.steam >= 0 && !sip {
                for (col, off) in [(1, 0), (3, 1)] {
                    for r in 1...2 {
                        let wobble = (r + pose.steam + off) % 2
                        fx[mx0 + col + wobble, my0 - r] = .steam
                    }
                }
            }
        case .boba:
            let sip = pose.sipping && !eating
            let bx = sip ? 13 + lx : 22
            let by = sip ? my - 2 : bottomRow - 8
            g.stamp(["....a.", "...a..", "oooooo", "oWWWWo", "oTTTTo", "oTTTTo", "okTkTo", "oTkTko", ".oooo."], x: bx, y: by)
            g.stamp(paw, x: bx - 2, y: by + 5)
        case .matcha:
            let sip = pose.sipping && !eating
            let x0 = sip ? 12 + lx : 22, y0 = sip ? my - 1 : bottomRow - 6
            g.stamp(paw, x: x0 - 2, y: y0 + 3)
            prop(.matcha, x: x0, y: y0)
            if pose.steam >= 0 && !sip { fx[x0 + 2 + pose.steam, y0 - 1] = .steam; fx[x0 + 3 - pose.steam, y0 - 2] = .steam }
        case .notepad:
            g.stamp(paw, x: 20, y: bottomRow - 4)
            prop(.note, x: 22, y: bottomRow - 7)
        case .handheld:
            g.stamp(paw, x: 8, y: bottomRow - 3)
            g.stamp(paw, x: 20, y: bottomRow - 3)
            prop(.handheld, x: 10, y: bottomRow - 4)
        }

        g = outlined(g)

        if let food = pose.food {
            let icon = food.icon
            prop(icon, x: 16 - icon.width / 2, y: my - 2, cropRight: min(icon.width, pose.bite * 3))
        }

        // Floating effects, drawn on their own layer with a readable halo.
        switch pose.effect {
        case .none:
            break
        case .zzz(let p):
            fx.stamp(["iii", "..i", ".i.", "i..", "iii"], x: 22, y: 10 - p)
            if p >= 1 { fx.stamp(["iiii", "..i.", ".i..", "iiii"], x: 26, y: 5 - p) }
        case .thinking(let n):
            fx.stamp([".bbbbbbb.", "bbbbbbbbb", "bbbbbbbbb", "bbbbbbbbb", ".bbbbbbb."], x: 22, y: 1)
            fx[21, 7] = .bubble
            fx[19, 9] = .bubble
            for i in 0..<min(3, n) { fx[24 + i * 2, 3] = .ink }
        case .hearts(let p):
            fx.stamp([".hh.hh.", "hhhhhhh", ".hhhhh.", "..hhh..", "...h..."], x: 23, y: 7 - p)
            if p % 2 == 0 { fx.stamp(["h.h", "hhh", ".h."], x: 19, y: 10 - p) }
        case .alert:
            fx.stamp(["YY", "YY", "YY", "..", "YY"], x: 25, y: 3)
        case .sparkles(let p):
            let spots = [[(4, 9), (26, 6), (27, 18)], [(6, 17), (24, 3), (3, 4)], [(27, 11), (5, 12), (20, 2)]][p % 3]
            for (x, y) in spots { fx.stamp([".Y.", "YbY", ".Y."], x: x, y: y) }
        case .rain(let p):
            fx.stamp(["...bbbb....", "..bbbbbbbb.", ".bbbbbbbbbb", "bbbbbbbbbbb"], x: 10, y: max(0, topY - 12))
            let base = max(0, topY - 12) + 5
            for (i, x) in [11, 14, 17, 20].enumerated() {
                let y = base + (p + i * 2) % 5
                if y < topY - 1 { fx[x, y] = .drop; fx[x, y + 1] = .drop }
            }
        case .balloon:
            fx.stamp(["..iii..", ".ihhbi.", "ihhhhbi", "ihhhhhi", ".ihhhi.", "..iii..", "...i...", "....i..", "...i..."], x: 22, y: 0)
        case .question:
            fx.stamp(["iii", "..i", ".ii", "...", ".i."], x: 25, y: 3)
        case .stars(let p):
            let ring = [(9, topY - 3), (16, topY - 5), (23, topY - 3), (16, topY - 1)]
            for k in 0..<2 {
                let (x, y) = ring[(p + k * 2) % 4]
                fx.stamp([".Y.", "YYY", ".Y."], x: x - 1, y: max(0, y))
            }
        case .sweat:
            fx.stamp([".D", "DD", "DD"], x: 24, y: eyeBase - 3)
        case .music(let p):
            fx.stamp(["..ii", ".i.i", ".i..", "ii..", "ii.."], x: 24, y: 6 - p)
            if p >= 1 { fx.stamp([".i", ".i", "ii"], x: 5, y: 12 - p) }
        case .coin(let p):
            fx.stamp([".YY.", "YYYY", "YYYY", ".YY."], x: 24, y: 8 - p * 2)
        }

        var fxDone = fxOutlined(fx)
        if pose.flipped {
            func mirror(_ grid: PixelGrid) -> PixelGrid {
                var m = PixelGrid()
                for y in 0..<32 { for x in 0..<32 { m[31 - x, y] = grid[x, y] } }
                return m
            }
            g = mirror(g)
            fxDone = mirror(fxDone)
            var p2 = props
            for y in 0..<32 { for x in 0..<32 { p2[y * 32 + (31 - x)] = props[y * 32 + x] } }
            props = p2
        }
        return (g, props, fxDone)
    }

    static func outlined(_ g: PixelGrid) -> PixelGrid {
        var out = g
        for y in 0..<32 {
            for x in 0..<32 {
                let m = g[x, y]
                guard m == .empty || m == .shadow else { continue }
                if g[x - 1, y].isSolid || g[x + 1, y].isSolid || g[x, y - 1].isSolid || g[x, y + 1].isSolid {
                    out[x, y] = .outline
                }
            }
        }
        return out
    }

    static func fxOutlined(_ g: PixelGrid) -> PixelGrid {
        var out = g
        for y in 0..<32 {
            for x in 0..<32 where g[x, y] == .empty {
                let n = [g[x - 1, y], g[x + 1, y], g[x, y - 1], g[x, y + 1]]
                if n.contains(.ink) { out[x, y] = .bubble }
                else if n.contains(where: { $0 == .heart || $0 == .bubble || $0 == .yellow || $0 == .drop }) { out[x, y] = .ink }
            }
        }
        return out
    }
}

// MARK: - Rendering

struct SpriteFrame {
    let image: CGImage
    /// Which of the 32×32 cells are visible (used for CRT scanlines).
    let opaque: [Bool]
}

enum SpriteRenderer {
    static func frame(look: CreatureLook, pose: Pose, colors: SpriteColors) -> SpriteFrame {
        let (g, props, fx) = SpriteBuilder.build(look, pose)
        let n = PixelGrid.size
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        var opaque = [Bool](repeating: false, count: n * n)
        for i in 0..<(n * n) {
            var c: RGBA
            var isSteam = false
            if fx.cells[i] != .empty {
                c = colors[fx.cells[i]]
                isSteam = fx.cells[i] == .steam
            } else if let p = props[i] {
                c = colors.snap(p)
            } else if g.cells[i] != .empty {
                c = colors[g.cells[i]]
            } else {
                continue
            }
            let a = min(max(c.a, 0), 1)
            bytes[i * 4 + 0] = UInt8((c.r * a * 255).rounded())
            bytes[i * 4 + 1] = UInt8((c.g * a * 255).rounded())
            bytes[i * 4 + 2] = UInt8((c.b * a * 255).rounded())
            bytes[i * 4 + 3] = UInt8((a * 255).rounded())
            opaque[i] = a > 0.5 && !isSteam
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(
            width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return SpriteFrame(image: image, opaque: opaque)
    }

    static func nsImage(look: CreatureLook, pose: Pose = Pose(), colors: SpriteColors) -> NSImage {
        let f = frame(look: look, pose: pose, colors: colors)
        return NSImage(cgImage: f.image, size: NSSize(width: 32, height: 32))
    }

    /// Renders the sprite at an integer scale into a new bitmap (used for icons and previews).
    static func scaledImage(_ image: CGImage, scale: Int, into ctx: CGContext, at origin: CGPoint) {
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: origin.x, y: origin.y, width: CGFloat(32 * scale), height: CGFloat(32 * scale)))
    }
}
