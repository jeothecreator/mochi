import Foundation

/// Turns the pet's current situation into an animation frame. Pure rules — no AI involved.
final class PetBrain {
    enum Reaction { case happy, surprised }

    /// Short scripted performances.
    enum Act: Equatable {
        case eat(Food), sneeze, celebrate, fall, spin, love, investigate, surprised, float, dance, play, sad, rained, coin, yawn, wave

        var duration: TimeInterval {
            switch self {
            case .eat: return 2.8
            case .sneeze: return 1.4
            case .celebrate: return 2.6
            case .fall: return 3.2
            case .spin: return 3.0
            case .love: return 2.2
            case .investigate: return 3.0
            case .surprised: return 1.2
            case .float: return 5.0
            case .dance: return 3.0
            case .play: return 2.4
            case .sad: return 2.5
            case .rained: return 6.0
            case .coin: return 1.8
            case .yawn: return 1.8
            case .wave: return 2.0
            }
        }
    }

    struct Settings {
        var intensity: Intensity
        var reduceMotion: Bool
        var held: HeldItem
        var species: Species
        var napAfter: TimeInterval?
        /// Seconds since any keyboard/mouse input on this Mac.
        var systemIdle: TimeInterval = 0
        /// Where the cursor is relative to the pet, when it's worth watching.
        var cursorLook: (x: Int, y: Int)? = nil
        var hungry = false
        var tired = false
    }

    private enum Idle { case none, lookAround, sip, hop, wiggle }

    var thinking = false
    var dragging = false
    private(set) var napUntil: TimeInterval = 0
    private var act: (act: Act, start: TimeInterval)?
    private var nextBlink: TimeInterval = 0
    private var blinkUntil: TimeInterval = 0
    private var idle: Idle = .none
    private var idleStart: TimeInterval = 0
    private var idleEnd: TimeInterval = 0
    private var nextIdle: TimeInterval = Date.timeIntervalSinceReferenceDate + 4

    static var now: TimeInterval { Date.timeIntervalSinceReferenceDate }

    var currentAct: Act? {
        guard let a = act, Self.now - a.start < a.act.duration else { return nil }
        return a.act
    }

    func perform(_ a: Act) {
        act = (a, Self.now)
        napUntil = 0
    }

    func react(_ r: Reaction) { perform(r == .happy ? .love : .surprised) }

    func nap(for seconds: TimeInterval) { napUntil = Self.now + seconds }
    func wake() { napUntil = 0 }

    func isAsleep(_ s: Settings, at now: TimeInterval = PetBrain.now) -> Bool {
        if thinking || dragging || currentAct != nil { return false }
        if now < napUntil { return true }
        if let nap = s.napAfter, s.systemIdle > nap { return true }
        return s.tired && s.systemIdle > 90
    }

    func pose(at now: TimeInterval, _ s: Settings) -> Pose {
        var p = Pose()
        let animated = s.intensity != .still && !s.reduceMotion
        let breathPeriod: Double
        let gap: ClosedRange<Double>
        switch s.intensity {
        case .still, .calm: breathPeriod = 1.6; gap = 10...20
        case .normal: breathPeriod = 1.2; gap = 6...12
        case .lively: breathPeriod = 0.9; gap = 3...7
        }
        if animated { p.breath = Int(now / breathPeriod) % 2 }
        p.steam = animated ? Int(now / 0.45) % 2 : 0
        if s.species == .ghost && animated { p.wiggle = Int(now / 0.5) % 2 }
        let phase = { (period: Double, count: Int) in animated ? Int(now / period) % count : 0 }

        if now >= nextBlink {
            blinkUntil = now + 0.14
            nextBlink = now + Double.random(in: 2.5...6.5)
        }
        let blinking = now < blinkUntil

        if dragging {
            p.expression = .surprised
            p.breath = 0
            return p
        }

        if let a = act {
            let t = now - a.start
            if t < a.act.duration {
                performPose(a.act, t: t, into: &p, animated: animated, phase: phase, s: s)
                return p
            }
            act = nil
        }

        if isAsleep(s, at: now) {
            p.expression = .sleep
            p.effect = .zzz(animated ? Int(now / 0.8) % 3 : 1)
            p.breath = animated ? Int(now / 2.4) % 2 : 0
            p.steam = -1
            return p
        }
        if thinking {
            p.lookX = 1
            p.lookY = -1
            p.effect = .thinking(animated ? Int(now / 0.35) % 3 + 1 : 3)
            if blinking { p.expression = .blink }
            return p
        }

        if animated {
            if idle == .none && now >= nextIdle {
                var choices: [Idle] = [.lookAround, .lookAround]
                if [.mug, .boba, .matcha].contains(s.held) { choices += [.sip, .sip, .sip] }
                if s.intensity != .calm { choices.append(.hop) }
                if s.intensity == .lively { choices += [.hop, .wiggle] }
                idle = choices.randomElement() ?? .none
                idleStart = now
                switch idle {
                case .lookAround: idleEnd = now + 3.0
                case .sip: idleEnd = now + 2.2
                case .hop: idleEnd = now + 0.6
                case .wiggle: idleEnd = now + 1.6
                case .none: idleEnd = now
                }
            }
            if idle != .none && now >= idleEnd {
                idle = .none
                nextIdle = now + Double.random(in: gap)
            }
            let t = now - idleStart
            switch idle {
            case .lookAround: p.lookX = t < 1.2 ? -1 : (t < 2.4 ? 1 : 0)
            case .sip: p.sipping = true; p.expression = .happy
            case .hop: p.hop = (t < 0.2 || (t > 0.3 && t < 0.5)) ? 2 : 0
            case .wiggle:
                p.lookX = Int(now / 0.2) % 2 == 0 ? -1 : 1
                p.expression = .happy
                p.wiggle = Int(now / 0.2) % 2
            case .none: break
            }
        } else {
            idle = .none
        }

        // Watching the cursor beats idle glances.
        if let c = s.cursorLook, !p.sipping {
            p.lookX = c.x
            p.lookY = c.y
        } else if s.held == .handheld && idle == .none {
            p.lookY = 1 // absorbed in a game
        }
        if s.hungry && p.expression == .normal && Int(now / 7) % 3 == 0 { p.expression = .sad }
        if blinking && p.expression == .normal { p.expression = .blink }
        if s.tired && p.expression == .normal && Int(now / 5) % 4 == 0 { p.expression = .blink }
        return p
    }

    private func performPose(_ a: Act, t: TimeInterval, into p: inout Pose, animated: Bool, phase: (Double, Int) -> Int, s: Settings) {
        switch a {
        case .eat(let food):
            if t < 2.1 {
                p.food = food
                p.bite = min(2, Int(t / 0.7))
                p.expression = .chomp
                p.wiggle = Int(t / 0.22) % 2
            } else {
                p.expression = .happy
                p.effect = .hearts(min(3, Int((t - 2.1) / 0.2)))
            }
        case .sneeze:
            if t < 0.7 { p.expression = .blink; p.lookY = -1 }
            else if t < 1.0 { p.expression = .surprised; p.squash = true }
            else { p.expression = .happy }
        case .celebrate:
            p.expression = .happy
            p.hop = animated && Int(t / 0.25) % 2 == 0 ? 2 : 0
            p.effect = .sparkles(phase(0.3, 3))
        case .fall:
            p.squash = true
            p.expression = .dizzy
            p.effect = .stars(phase(0.25, 4))
        case .spin:
            p.flipped = animated && Int(t / 0.15) % 2 == 1
            p.expression = .happy
            p.effect = .sparkles(phase(0.3, 3))
        case .love:
            p.expression = .love
            p.effect = .hearts(animated ? min(3, Int(t / 0.3)) : 1)
        case .investigate:
            p.expression = .normal
            if let c = s.cursorLook { p.lookX = c.x; p.lookY = c.y } else { p.lookX = Int(t / 0.8) % 2 == 0 ? -1 : 1 }
            p.effect = .question
        case .surprised:
            p.expression = .surprised
            p.effect = .alert
            p.hop = animated && t < 0.3 ? 2 : 0
        case .float:
            p.expression = .happy
            p.effect = .balloon
        case .dance:
            p.lookX = Int(t / 0.25) % 2 == 0 ? -1 : 1
            p.wiggle = Int(t / 0.25) % 2
            p.hop = animated && Int(t / 0.5) % 2 == 0 ? 1 : 0
            p.expression = .happy
            p.effect = .music(phase(0.4, 3))
        case .play:
            p.expression = .happy
            p.hop = animated && Int(t / 0.3) % 2 == 0 ? 2 : 0
            p.lookX = Int(t / 0.3) % 2 == 0 ? -1 : 1
            p.effect = .sparkles(phase(0.35, 3))
        case .sad:
            p.expression = .sad
            p.effect = .sweat
        case .rained:
            p.expression = t < 4 ? .sad : .happy
            p.effect = t < 4 ? .rain(phase(0.15, 5)) : .sparkles(0)
        case .coin:
            p.expression = t < 0.4 ? .surprised : .happy
            p.effect = .coin(min(2, Int(t / 0.3)))
        case .yawn:
            p.expression = t < 1.2 ? .surprised : .blink
            p.lookY = -1
        case .wave:
            p.expression = .happy
            p.lookX = Int(t / 0.3) % 2 == 0 ? -1 : 0
            p.effect = .hearts(0)
        }
    }
}
