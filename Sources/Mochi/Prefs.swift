import AppKit
import Combine
import SwiftUI

enum Intensity: String, CaseIterable, Identifiable {
    case still, calm, normal, lively
    var id: String { rawValue }
    var label: String {
        switch self {
        case .still: return "Still"
        case .calm: return "Calm"
        case .normal: return "Normal"
        case .lively: return "Lively"
        }
    }
}

enum HotKeyAction: String, CaseIterable, Identifiable {
    case toggleChat, togglePet
    var id: String { rawValue }
    var label: String {
        switch self {
        case .toggleChat: return "Summon pet & add a to-do"
        case .togglePet: return "Show / hide the pet"
        }
    }
}

/// All preferences, persisted in UserDefaults.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    static let isTestProfile = ProcessInfo.processInfo.environment["MOCHI_TEST_PROFILE"] == "1"
    static var defaults: UserDefaults { isTestProfile ? UserDefaults(suiteName: "com.mochi.desktoppet.testprofile")! : .standard }
    private let d = Prefs.defaults

    @Published var hasOnboarded: Bool { didSet { d.set(hasOnboarded, forKey: "hasOnboarded") } }

    // Creature
    @Published var petName: String { didSet { d.set(petName, forKey: "petName") } }
    @Published var species: Species { didSet { d.set(species.rawValue, forKey: "species") } }
    @Published var eyeStyle: EyeStyle { didSet { d.set(eyeStyle.rawValue, forKey: "eyeStyle") } }
    @Published var accessory: Accessory { didSet { d.set(accessory.rawValue, forKey: "accessory") } }
    @Published var held: HeldItem { didSet { d.set(held.rawValue, forKey: "held") } }
    @Published var blush: Bool { didSet { d.set(blush, forKey: "blush") } }
    @Published var palettePreset: PalettePreset { didSet { d.set(palettePreset.rawValue, forKey: "palettePreset") } }
    @Published var customBody: String { didSet { d.set(customBody, forKey: "customBody") } }
    @Published var customOutline: String { didSet { d.set(customOutline, forKey: "customOutline") } }
    @Published var customCheek: String { didSet { d.set(customCheek, forKey: "customCheek") } }
    @Published var customAccent: String { didSet { d.set(customAccent, forKey: "customAccent") } }
    @Published var customEye: String { didSet { d.set(customEye, forKey: "customEye") } }
    @Published var petScale: Int { didSet { d.set(petScale, forKey: "petScale") } }

    // Motion & look
    @Published var intensity: Intensity { didSet { d.set(intensity.rawValue, forKey: "intensity") } }
    @Published var napMinutes: Int { didSet { d.set(napMinutes, forKey: "napMinutes") } }
    @Published var scanlines: Bool { didSet { d.set(scanlines, forKey: "scanlines") } }
    @Published var typewriter: Bool { didSet { d.set(typewriter, forKey: "typewriter") } }
    @Published var uiTheme: UITheme { didSet { d.set(uiTheme.rawValue, forKey: "uiTheme") } }
    @Published var mode: VibeMode { didSet { d.set(mode.rawValue, forKey: "mode") } }

    // Personality & senses
    @Published var onboardedV2: Bool { didSet { d.set(onboardedV2, forKey: "onboardedV2") } }
    @Published var chattiness: Chattiness { didSet { d.set(chattiness.rawValue, forKey: "chattiness") } }
    @Published var watchCursor: Bool { didSet { d.set(watchCursor, forKey: "watchCursor") } }
    @Published var reactToApps: Bool { didSet { d.set(reactToApps, forKey: "reactToApps") } }
    @Published var dressForTask: Bool { didSet { d.set(dressForTask, forKey: "dressForTask") } }
    @Published var randomEvents: EventFrequency { didSet { d.set(randomEvents.rawValue, forKey: "randomEvents") } }
    @Published var exploring: Bool { didSet { d.set(exploring, forKey: "exploring") } }

    // Desktop behavior
    @Published var petVisible: Bool { didSet { d.set(petVisible, forKey: "petVisible") } }
    @Published var alwaysOnTop: Bool { didSet { d.set(alwaysOnTop, forKey: "alwaysOnTop") } }
    @Published var allSpaces: Bool { didSet { d.set(allSpaces, forKey: "allSpaces") } }
    @Published var everyDisplay: Bool { didSet { d.set(everyDisplay, forKey: "everyDisplay") } }
    @Published var hotKeyEnabled: Bool { didSet { d.set(hotKeyEnabled, forKey: "hotKeyEnabled") } }
    @Published var hotKey: HotKeyCombo {
        didSet { if let data = try? JSONEncoder().encode(hotKey) { d.set(data, forKey: "hotKey") } }
    }
    @Published var hotKeyAction: HotKeyAction { didSet { d.set(hotKeyAction.rawValue, forKey: "hotKeyAction") } }


    var petOrigin: NSPoint? {
        get {
            guard d.object(forKey: "petX") != nil else { return nil }
            return NSPoint(x: d.double(forKey: "petX"), y: d.double(forKey: "petY"))
        }
        set {
            if let p = newValue { d.set(p.x, forKey: "petX"); d.set(p.y, forKey: "petY") }
            else { d.removeObject(forKey: "petX"); d.removeObject(forKey: "petY") }
        }
    }

    /// Saved positions of the extra pets, per display.
    func copyOrigin(for screenKey: String) -> NSPoint? {
        guard let v = (d.dictionary(forKey: "copyOrigins") as? [String: [Double]])?[screenKey], v.count == 2 else { return nil }
        return NSPoint(x: v[0], y: v[1])
    }

    func setCopyOrigin(_ p: NSPoint, for screenKey: String) {
        var all = (d.dictionary(forKey: "copyOrigins") as? [String: [Double]]) ?? [:]
        all[screenKey] = [p.x, p.y]
        d.set(all, forKey: "copyOrigins")
    }

    private init() {
        let d = Prefs.defaults
        func str(_ k: String) -> String? { d.string(forKey: k) }
        func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) == nil ? def : d.bool(forKey: k) }
        func int(_ k: String, _ def: Int) -> Int { d.object(forKey: k) == nil ? def : d.integer(forKey: k) }

        for old in ["aiMode", "model", "effort", "saveHistory", "ollamaURL", "ollamaModel", "showAskTab"] { d.removeObject(forKey: old) }
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        petName = str("petName") ?? "Mochi"
        species = Species(rawValue: str("species") ?? "") ?? .mochi
        eyeStyle = EyeStyle(rawValue: str("eyeStyle") ?? "") ?? .bean
        accessory = Accessory(rawValue: str("accessory") ?? "") ?? .beret
        held = HeldItem(rawValue: str("held") ?? "") ?? .mug
        blush = bool("blush", true)
        palettePreset = PalettePreset(rawValue: str("palettePreset") ?? "") ?? .espresso
        customBody = str("customBody") ?? "#F3E6CF"
        customOutline = str("customOutline") ?? "#3B2A22"
        customCheek = str("customCheek") ?? "#E7A07E"
        customAccent = str("customAccent") ?? "#C8894F"
        customEye = str("customEye") ?? "#2A1E18"
        petScale = min(8, max(2, int("petScale", 4)))

        intensity = Intensity(rawValue: str("intensity") ?? "") ?? .calm
        napMinutes = int("napMinutes", 15)
        scanlines = bool("scanlines", false)
        typewriter = bool("typewriter", true)
        uiTheme = UITheme(rawValue: str("uiTheme") ?? "") ?? .cafe
        mode = VibeMode(rawValue: str("mode") ?? "") ?? .cafe
        onboardedV2 = d.bool(forKey: "onboardedV2")
        chattiness = Chattiness(rawValue: str("chattiness") ?? "") ?? .sometimes
        watchCursor = bool("watchCursor", true)
        reactToApps = bool("reactToApps", true)
        dressForTask = bool("dressForTask", true)
        randomEvents = EventFrequency(rawValue: str("randomEvents") ?? "") ?? .normal
        exploring = bool("exploring", true)

        petVisible = bool("petVisible", true)
        alwaysOnTop = bool("alwaysOnTop", true)
        allSpaces = bool("allSpaces", true)
        everyDisplay = bool("everyDisplay", false)
        hotKeyEnabled = bool("hotKeyEnabled", true)
        if let data = d.data(forKey: "hotKey"), let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            hotKey = combo
        } else {
            hotKey = .default
        }
        hotKeyAction = HotKeyAction(rawValue: str("hotKeyAction") ?? "") ?? .toggleChat

    }

    var look: CreatureLook {
        CreatureLook(species: species, eyes: eyeStyle, accessory: accessory, held: held, blush: blush)
    }

    var paletteBase: PaletteBase {
        palettePreset.base ?? PaletteBase(body: customBody, outline: customOutline, cheek: customCheek,
                                          accent: customAccent, eye: customEye)
    }

    var spriteColors: SpriteColors { SpriteColors.make(paletteBase) }

    var theme: ThemeColors { uiTheme.colors }

    func apply(_ m: VibeMode) {
        mode = m
        uiTheme = m.ui
        palettePreset = m.palette
        held = m.held
    }

    func randomizeCreature() {
        species = Species.allCases.randomElement()!
        eyeStyle = EyeStyle.allCases.randomElement()!
        accessory = Accessory.allCases.randomElement()!
        held = HeldItem.allCases.randomElement()!
        blush = Double.random(in: 0...1) < 0.8
        palettePreset = PalettePreset.allCases.filter { $0 != .custom }.randomElement()!
    }
}

enum Chattiness: String, CaseIterable, Identifiable {
    case quiet, sometimes, chatty
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quiet: return "Quiet"
        case .sometimes: return "Sometimes"
        case .chatty: return "Chatty"
        }
    }
    /// Seconds between unprompted little comments (nil = only reacts).
    var interval: ClosedRange<Double>? {
        switch self {
        case .quiet: return nil
        case .sometimes: return 20 * 60...30 * 60
        case .chatty: return 6 * 60...10 * 60
        }
    }
}

enum EventFrequency: String, CaseIterable, Identifiable {
    case off, normal, often
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"
        case .normal: return "Normal"
        case .often: return "Often"
        }
    }
}
