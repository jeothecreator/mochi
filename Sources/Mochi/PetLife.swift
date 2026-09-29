import AppKit
import Combine
import Foundation

// MARK: - Catalogs

enum Food: String, CaseIterable, Identifiable, Codable {
    case cookie, onigiri, strawberry, matcha, boba, fish, cake
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cookie: return "Cookie"
        case .onigiri: return "Onigiri"
        case .strawberry: return "Strawberry"
        case .matcha: return "Matcha latte"
        case .boba: return "Boba"
        case .fish: return "Fish"
        case .cake: return "Cake"
        }
    }

    var icon: PixelIcon {
        switch self {
        case .cookie: return .cookie
        case .onigiri: return .onigiri
        case .strawberry: return .strawberry
        case .matcha: return .matcha
        case .boba: return .boba
        case .fish: return .fish
        case .cake: return .cake
        }
    }

    var cost: Int {
        switch self {
        case .cookie, .onigiri, .strawberry: return 0
        case .matcha: return 2
        case .boba, .fish: return 3
        case .cake: return 5
        }
    }

    /// (fullness, happiness, energy)
    var effect: (Double, Double, Double) {
        switch self {
        case .cookie: return (8, 6, 0)
        case .onigiri: return (22, 3, 2)
        case .strawberry: return (8, 8, 0)
        case .matcha: return (4, 6, 28)
        case .boba: return (10, 16, 5)
        case .fish: return (26, 10, 0)
        case .cake: return (15, 26, 3)
        }
    }

    var lines: [String] {
        switch self {
        case .cookie: return ["nom nom 🍪", "crunchy!!", "cookie time ♡"]
        case .onigiri: return ["rice ball supremacy 🍙", "so filling…", "mmm, salty & perfect"]
        case .strawberry: return ["berry cute 🍓", "sweet!!", "juicy ♡"]
        case .matcha: return ["matcha powered 🍵✨", "i can see sounds now", "zen mode: on"]
        case .boba: return ["pearls!!! 🧋", "chewy happiness", "boba is a food group"]
        case .fish: return ["fishy friend 🐟", "omega-3 energy", "blub (thank you)"]
        case .cake: return ["CAKE?! for me?? 🍰", "best day ever", "is it my birthday?"]
        }
    }
}

enum Souvenir: String, CaseIterable, Identifiable, Codable {
    case shell, acorn, gem, feather, goldenFish
    var id: String { rawValue }
    var label: String {
        switch self {
        case .shell: return "Pink shell"
        case .acorn: return "Lucky acorn"
        case .gem: return "Tiny gem"
        case .feather: return "Sky feather"
        case .goldenFish: return "Golden fish"
        }
    }
    var icon: PixelIcon {
        switch self {
        case .shell: return .shell
        case .acorn: return .acorn
        case .gem: return .gem
        case .feather: return .feather
        case .goldenFish: return .goldenFish
        }
    }
}

enum Achievement: String, CaseIterable, Identifiable, Codable {
    case hatched, firstMeal, bestFriends, pokeMaster, pokeLegend, bigMochi, nightOwl, explorer
    case lucky, bugSpotter, itCompiles, buildHero, noteTaker, doneAndDusted, fashionista, welcomeBack, fishFriend, birthday, secretWord
    case firstFocus, deepFocus, shopper, rpsChamp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hatched: return "Hello, world"
        case .firstMeal: return "First meal"
        case .bestFriends: return "Best friends"
        case .pokeMaster: return "Poke master"
        case .pokeLegend: return "Poke legend"
        case .bigMochi: return "Big Mochi"
        case .nightOwl: return "Night owl"
        case .explorer: return "Explorer"
        case .lucky: return "Legendary luck"
        case .bugSpotter: return "Bug spotter"
        case .itCompiles: return "It compiles!"
        case .buildHero: return "Build hero"
        case .noteTaker: return "List maker"
        case .doneAndDusted: return "Done & dusted"
        case .fashionista: return "Fashionista"
        case .welcomeBack: return "Welcome back"
        case .fishFriend: return "Fish friend"
        case .birthday: return "Birthday buddy"
        case .secretWord: return "Say my name"
        case .firstFocus: return "In the zone"
        case .deepFocus: return "Deep focus"
        case .shopper: return "Treat yourself"
        case .rpsChamp: return "Rock star"
        }
    }

    var detail: String {
        switch self {
        case .hatched: return "Hatched your pet."
        case .firstMeal: return "Fed your pet for the first time."
        case .bestFriends: return "Reached friendship level 5."
        case .pokeMaster: return "Poked your pet 100 times."
        case .pokeLegend: return "Poked your pet 500 times."
        case .bigMochi: return "10 cookies in one day. Very big."
        case .nightOwl: return "Hung out at 3 AM."
        case .explorer: return "Your pet went exploring and came back."
        case .lucky: return "Witnessed a legendary event."
        case .bugSpotter: return "Saw a bug crawl across the screen."
        case .itCompiles: return "First successful build together."
        case .buildHero: return "10 successful builds."
        case .noteTaker: return "Added 10 to-dos."
        case .doneAndDusted: return "Finished 10 to-dos."
        case .fashionista: return "Tried on 5 accessories."
        case .welcomeBack: return "Came back after a day away."
        case .fishFriend: return "Gave away a golden fish."
        case .birthday: return "Celebrated your birthday."
        case .secretWord: return "Typed the secret word."
        case .firstFocus: return "Finished a focus session."
        case .deepFocus: return "Finished 10 focus sessions."
        case .shopper: return "Bought something in the shop."
        case .rpsChamp: return "Won 10 rock-paper-scissors matches."
        }
    }

    /// Hidden until unlocked.
    var isSecret: Bool {
        switch self {
        case .pokeLegend, .bigMochi, .nightOwl, .lucky, .fishFriend, .secretWord: return true
        default: return false
        }
    }

    var coins: Int { isSecret ? 10 : 5 }
}

enum Activity: String, CaseIterable, Identifiable, Codable {
    case coding, slides, design, writing, studying, gaming, video, music
    var id: String { rawValue }

    var label: String {
        switch self {
        case .coding: return "Coding"
        case .slides: return "Slides"
        case .design: return "Design & Canva"
        case .writing: return "Writing"
        case .studying: return "Studying"
        case .gaming: return "Gaming"
        case .video: return "Video editing"
        case .music: return "Music"
        }
    }

    var emoji: String {
        switch self {
        case .coding: return "💻"
        case .slides: return "📊"
        case .design: return "🎨"
        case .writing: return "✍️"
        case .studying: return "📚"
        case .gaming: return "🎮"
        case .video: return "🎬"
        case .music: return "🎧"
        }
    }

    /// Bundle-ID prefixes of apps that count as this activity (frontmost app only — never window contents).
    var bundlePrefixes: [String] {
        switch self {
        case .coding:
            return ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.Terminal",
                    "com.googlecode.iterm2", "com.jetbrains.", "dev.zed.Zed", "dev.warp.", "com.mitchellh.ghostty",
                    "com.sublimetext.", "com.panic.Nova", "com.google.antigravity", "com.exafunction.windsurf", "com.cc.arduino"]
        case .slides: return ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint", "com.pitch."]
        case .design: return ["com.canva.", "com.figma.", "com.adobe.Photoshop", "com.adobe.illustrator", "com.bohemiancoding.sketch3",
                              "com.seriflabs.", "org.blenderfoundation.blender", "com.pixelmatorteam."]
        case .writing: return ["com.apple.iWork.Pages", "com.microsoft.Word", "notion.id", "md.obsidian", "com.apple.Notes", "net.shinyfrog.bear"]
        case .studying: return ["com.apple.iBooksX", "com.apple.Preview", "com.collegeboard.", "com.quizlet", "com.anki"]
        case .gaming: return ["com.valvesoftware.steam", "com.hiddenpath.", "com.epicgames.", "com.riotgames.", "com.blizzard."]
        case .video: return ["com.blackmagic-design.DaVinciResolve", "com.apple.FinalCut", "com.lemon.lvoverseas", "com.apple.iMovieApp", "com.adobe.PremierePro"]
        case .music: return ["com.apple.garageband10", "com.apple.logic10", "com.apple.Music", "com.spotify.client", "com.ableton."]
        }
    }

    static func match(bundleID: String?) -> Activity? {
        guard let id = bundleID else { return nil }
        return allCases.first { $0.bundlePrefixes.contains { id.hasPrefix($0) } }
    }
}

/// A to-do. (Named PetNote for save-file compatibility with earlier versions.)
struct PetNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var color = 0
    var created = Date()
    var pinned = false
    var doneAt: Date? = nil
    var isDone: Bool { doneAt != nil }
}

struct MemoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    /// Phrased to fit "Remember when …?" e.g. "you coded for 3 hours straight".
    var text: String
    var emoji = "✨"
}

struct UserProfile: Codable, Equatable {
    var name = ""
    var favoriteColor = ""
    var favoriteColorHex = "#8FA37E"
    var favoriteGames = ""
    var birthdayMonth = 0
    var birthdayDay = 0
    var activities: [Activity] = []
    var facts: [String] = []
}

/// Things you can buy with coins.
enum ShopItem: String, CaseIterable, Identifiable {
    case sunglasses, chefHat, cowboyHat, starClip, plant, sunset, ocean, cottonCandy, golden
    var id: String { rawValue }

    enum Kind { case outfit, palette, extra }

    var kind: Kind {
        switch self {
        case .sunglasses, .chefHat, .cowboyHat, .starClip: return .outfit
        case .sunset, .ocean, .cottonCandy, .golden: return .palette
        case .plant: return .extra
        }
    }

    var accessory: Accessory? {
        switch self {
        case .sunglasses: return .sunglasses
        case .chefHat: return .chefHat
        case .cowboyHat: return .cowboyHat
        case .starClip: return .starClip
        default: return nil
        }
    }

    var palette: PalettePreset? {
        switch self {
        case .sunset: return .sunset
        case .ocean: return .ocean
        case .cottonCandy: return .cottonCandy
        case .golden: return .golden
        default: return nil
        }
    }

    var held: HeldItem? { self == .plant ? .plant : nil }

    var label: String {
        accessory?.label ?? palette.map { "\($0.label) palette" } ?? held?.label ?? rawValue
    }

    var price: Int {
        switch self {
        case .starClip: return 10
        case .plant, .sunset, .ocean: return 12
        case .sunglasses, .cottonCandy: return 15
        case .chefHat: return 20
        case .cowboyHat: return 25
        case .golden: return 60
        }
    }

    var boughtLine: String {
        switch self {
        case .sunglasses: return "too cool for school 😎"
        case .chefHat: return "bonjour, i am chef now 👨‍🍳"
        case .cowboyHat: return "yeehaw 🤠"
        case .starClip: return "sparkly! ⭐"
        case .plant: return "i will name it leafy 🌱"
        case .golden: return "✨ i am GOLDEN ✨"
        default: return "new colors!! how do i look? 🎨"
        }
    }

    static func item(for acc: Accessory) -> ShopItem? { allCases.first { $0.accessory == acc } }
    static func item(for p: PalettePreset) -> ShopItem? { allCases.first { $0.palette == p } }
    static func item(for h: HeldItem) -> ShopItem? { allCases.first { $0.held == h } }
}

// MARK: - Save file

struct PetSave: Codable {
    var hunger: Double = 80       // fullness, 0 = starving
    var happiness: Double = 80
    var energy: Double = 90
    var coins = 10
    var xp = 0
    var firstMet = Date()
    var lastSeen = Date()
    var lastInteraction = Date()

    var clicks = 0
    var feeds = 0
    var cookieDay = ""
    var cookiesToday = 0
    var buildsOK = 0
    var buildsFailed = 0
    var failStreak = 0
    var notesWritten = 0
    var todosDone = 0
    var purchases: [String] = []
    var focusSessions = 0
    var focusMinutesTotal = 0
    var rpsWins = 0
    var eventsSeen: [String: Int] = [:]
    var accessoriesTried: [String] = []

    var achievements: [Achievement: Date] = [:]
    var unlockedSecrets: [String] = []
    var inventory: [Souvenir: Int] = [:]
    var notes: [PetNote] = []
    var memories: [MemoryEntry] = []
    var profile = UserProfile()

    var activityDay = ""
    var activitySeconds: [Activity: Double] = [:]
    var loggedMilestones: [String] = []
    var lastBirthdayYear = 0
}

// MARK: - Life

/// Everything the pet remembers, persisted as local JSON (never uploaded).
final class PetLife: ObservableObject {
    static let shared = PetLife()

    @Published var s: PetSave
    /// Fired when an achievement unlocks (UI & pet react to it).
    let achievementUnlocked = PassthroughSubject<Achievement, Never>()

    private var saveWork: DispatchWorkItem?

    /// ~/Library/Application Support/Mochi (or MOCHI_DATA_DIR, used by the test/snapshot tools).
    static var dataDir: URL {
        if let custom = ProcessInfo.processInfo.environment["MOCHI_DATA_DIR"] { return URL(fileURLWithPath: custom, isDirectory: true) }
        if Prefs.isTestProfile { return URL(fileURLWithPath: NSTemporaryDirectory() + "mochi-testprofile", isDirectory: true) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochi", isDirectory: true)
    }

    static var fileURL: URL { dataDir.appendingPathComponent("pet.json") }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL), let saved = Self.tolerantDecode(data) {
            s = saved
        } else {
            s = PetSave()
        }
    }

    /// Decodes a save from any earlier version: fields it doesn't know yet fall back to defaults.
    static func tolerantDecode(_ data: Data) -> PetSave? {
        if let exact = try? JSONDecoder().decode(PetSave.self, from: data) { return exact }
        guard let loaded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let defaults = try? JSONEncoder().encode(PetSave()),
              var merged = try? JSONSerialization.jsonObject(with: defaults) as? [String: Any] else { return nil }
        for (k, v) in loaded { merged[k] = v }
        guard let mergedData = try? JSONSerialization.data(withJSONObject: merged) else { return nil }
        return try? JSONDecoder().decode(PetSave.self, from: mergedData)
    }

    var level: Int { min(99, 1 + s.xp / 100) }
    var levelProgress: Double { Double(s.xp % 100) / 100 }
    var pinnedNote: PetNote? { s.notes.first { $0.pinned && !$0.isDone } }
    var openTodos: [PetNote] { s.notes.filter { !$0.isDone } }
    var doneTodos: [PetNote] { s.notes.filter { $0.isDone } }

    func saveSoon() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func saveNow() {
        if s.activityDay != activityDay || s.activitySeconds != activitySeconds {
            s.activityDay = activityDay
            s.activitySeconds = activitySeconds
        }
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: [.atomic]) }
    }

    func resetEverything() {
        s = PetSave()
        saveNow()
    }

    // MARK: Stats

    private static func clamp(_ v: Double) -> Double { min(100, max(0, v)) }

    /// Gentle decay. Never drops below a cozy floor while you're away — no guilt trips.
    func decay(seconds: TimeInterval, asleep: Bool) {
        let minutes = seconds / 60
        s.hunger = max(s.hunger - minutes / 9, min(s.hunger, 12))
        s.happiness = max(s.happiness - minutes / 12, min(s.happiness, 15))
        if asleep { s.energy = Self.clamp(s.energy + minutes * 1.5) }
        else { s.energy = max(s.energy - minutes / 10, min(s.energy, 10)) }
    }

    func gainXP(_ n: Int) {
        let before = level
        s.xp += n
        if level >= 5 && before < 5 { unlock(.bestFriends) }
        saveSoon()
    }

    func addCoins(_ n: Int) { s.coins += n; saveSoon() }

    func touch() { s.lastInteraction = Date() }

    // MARK: Actions

    enum FeedResult { case ok, broke, full }

    func feed(_ food: Food) -> FeedResult {
        guard s.coins >= food.cost else { return .broke }
        if s.hunger >= 99 && food != .matcha { return .full }
        s.coins -= food.cost
        let (h, j, e) = food.effect
        s.hunger = Self.clamp(s.hunger + h)
        s.happiness = Self.clamp(s.happiness + j)
        s.energy = Self.clamp(s.energy + e)
        s.feeds += 1
        if food == .cookie {
            let day = Self.dayKey()
            if s.cookieDay != day { s.cookieDay = day; s.cookiesToday = 0 }
            s.cookiesToday += 1
        }
        unlock(.firstMeal)
        touch()
        gainXP(3)
        return .ok
    }

    func pat() {
        s.happiness = Self.clamp(s.happiness + 3)
        touch()
        gainXP(1)
    }

    func play() {
        s.happiness = Self.clamp(s.happiness + 10)
        s.energy = Self.clamp(s.energy - 6)
        s.hunger = Self.clamp(s.hunger - 3)
        touch()
        gainXP(2)
    }

    func click() -> Int {
        s.clicks += 1
        touch()
        if s.clicks == 100 { unlock(.pokeMaster) }
        if s.clicks == 500 { unlock(.pokeLegend) }
        saveSoon()
        return s.clicks
    }

    func addSouvenir(_ item: Souvenir) {
        s.inventory[item, default: 0] += 1
        saveSoon()
    }

    /// Gives an item to the pet. Returns an unlocked secret accessory, if any.
    func give(_ item: Souvenir) -> Accessory? {
        guard let n = s.inventory[item], n > 0 else { return nil }
        s.inventory[item] = n - 1 == 0 ? nil : n - 1
        s.happiness = Self.clamp(s.happiness + 12)
        gainXP(4)
        if item == .goldenFish {
            unlock(.fishFriend)
            return unlockSecret(.frogHat)
        }
        return nil
    }

    @discardableResult
    func unlockSecret(_ acc: Accessory) -> Accessory? {
        guard !s.unlockedSecrets.contains(acc.rawValue) else { return nil }
        s.unlockedSecrets.append(acc.rawValue)
        saveSoon()
        return acc
    }

    func isUnlocked(_ acc: Accessory) -> Bool {
        if let item = ShopItem.item(for: acc) { return owns(item) }
        return !acc.isSecret || s.unlockedSecrets.contains(acc.rawValue)
    }
    func isUnlocked(_ p: PalettePreset) -> Bool { ShopItem.item(for: p).map(owns) ?? true }
    func isUnlocked(_ h: HeldItem) -> Bool { ShopItem.item(for: h).map(owns) ?? true }

    // MARK: Shop

    func owns(_ item: ShopItem) -> Bool { s.purchases.contains(item.rawValue) }

    enum BuyResult { case bought, alreadyOwned, broke }

    func buy(_ item: ShopItem) -> BuyResult {
        if owns(item) { return .alreadyOwned }
        guard s.coins >= item.price else { return .broke }
        s.coins -= item.price
        s.purchases.append(item.rawValue)
        unlock(.shopper)
        gainXP(5)
        return .bought
    }

    // MARK: Focus & games

    func focusFinished(minutes: Int) {
        s.focusSessions += 1
        s.focusMinutesTotal += minutes
        s.coins += 3
        s.energy = max(0, s.energy - 5)
        unlock(.firstFocus)
        if s.focusSessions == 10 { unlock(.deepFocus) }
        gainXP(5)
    }

    func rpsMatchWon() {
        s.rpsWins += 1
        s.coins += 2
        s.happiness = min(100, s.happiness + 4)
        if s.rpsWins == 10 { unlock(.rpsChamp) }
        gainXP(2)
    }

    func triedAccessory(_ acc: Accessory) {
        guard acc != .none, !s.accessoriesTried.contains(acc.rawValue) else { return }
        s.accessoriesTried.append(acc.rawValue)
        if s.accessoriesTried.count >= 5 { unlock(.fashionista) }
        saveSoon()
    }

    // MARK: Achievements & memories

    @discardableResult
    func unlock(_ a: Achievement) -> Bool {
        guard s.achievements[a] == nil else { return false }
        s.achievements[a] = Date()
        s.coins += a.coins
        remember("we unlocked “\(a.title)”", emoji: "🏆")
        saveSoon()
        achievementUnlocked.send(a)
        return true
    }

    func remember(_ text: String, emoji: String = "✨") {
        // Don't record the same memory twice in one day.
        if s.memories.contains(where: { $0.text == text && Calendar.current.isDateInToday($0.date) }) { return }
        s.memories.insert(MemoryEntry(text: text, emoji: emoji), at: 0)
        if s.memories.count > 200 { s.memories.removeLast(s.memories.count - 200) }
        saveSoon()
    }

    /// A memory at least a day old, for "remember when…" callbacks.
    func oldMemory() -> MemoryEntry? {
        s.memories.filter { $0.date < Date().addingTimeInterval(-20 * 3600) && !$0.text.hasPrefix("we unlocked") }.randomElement()
    }

    // MARK: Notes

    func addNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        s.notes.insert(PetNote(text: t, color: s.notesWritten % 5), at: 0)
        s.notesWritten += 1
        if s.notesWritten == 10 { unlock(.noteTaker) }
        touch()
        gainXP(2)
    }

    /// Checks/unchecks a to-do. Returns true when it was just completed.
    @discardableResult
    func toggleDone(_ id: UUID) -> Bool {
        guard let i = s.notes.firstIndex(where: { $0.id == id }) else { return false }
        if s.notes[i].isDone {
            s.notes[i].doneAt = nil
            saveSoon()
            return false
        }
        s.notes[i].doneAt = Date()
        s.notes[i].pinned = false
        s.todosDone += 1
        s.coins += 1
        s.happiness = min(100, s.happiness + 2)
        if s.todosDone == 10 { unlock(.doneAndDusted) }
        touch()
        gainXP(3)
        return true
    }

    func clearDone() {
        s.notes.removeAll { $0.isDone }
        saveSoon()
    }

    func togglePin(_ id: UUID) {
        for i in s.notes.indices {
            s.notes[i].pinned = s.notes[i].id == id ? !s.notes[i].pinned : false
        }
        saveSoon()
    }

    func deleteNote(_ id: UUID) {
        s.notes.removeAll { $0.id == id }
        saveSoon()
    }

    // MARK: Activity time (frontmost app category only)

    static func dayKey(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Returns total seconds today for that activity.
    /// Kept out of `s` between saves so ticking time doesn't redraw the UI twice a second.
    private lazy var activityDay = s.activityDay
    private lazy var activitySeconds = s.activitySeconds

    @discardableResult
    func logActivity(_ a: Activity, seconds: Double) -> Double {
        let day = Self.dayKey()
        if activityDay != day { activityDay = day; activitySeconds = [:] }
        activitySeconds[a, default: 0] += seconds
        return activitySeconds[a]!
    }

    func milestoneOnce(_ key: String) -> Bool {
        guard !s.loggedMilestones.contains(key) else { return false }
        s.loggedMilestones.append(key)
        if s.loggedMilestones.count > 300 { s.loggedMilestones.removeFirst(100) }
        return true
    }
}

extension Achievement: CodingKeyRepresentable {}
extension Souvenir: CodingKeyRepresentable {}
extension Activity: CodingKeyRepresentable {}
