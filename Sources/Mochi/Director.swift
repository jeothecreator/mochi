import AppKit
import Combine

/// Pomodoro-style focus timer. Lives in memory; stats are saved in PetLife.
final class FocusTimer: ObservableObject {
    enum Phase: Equatable { case idle, focus, rest }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var endsAt: Date?
    private(set) var minutes = 25

    var isRunning: Bool { phase != .idle }
    var remaining: TimeInterval { max(0, endsAt?.timeIntervalSinceNow ?? 0) }
    var remainingLabel: String {
        let r = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    func start(_ p: Phase, minutes m: Int) {
        minutes = m
        phase = p
        endsAt = p == .idle ? nil : Date().addingTimeInterval(TimeInterval(m * 60))
    }

    func stop() { start(.idle, minutes: 0) }
}

/// The pet's rule-based brain: senses → mood & decisions → actions (talking, animation, events).
/// No AI anywhere in here — just timers, dice, and memories.
final class Director {
    private let pet: PetController
    private let bubble = SpeechBubble()
    private let actors = ActorLayer()
    private let package = PropPanel()
    private let senses = Senses()
    private let life = PetLife.shared
    private let prefs = Prefs.shared
    private var cancellables = Set<AnyCancellable>()

    /// Latest line, mirrored into the home panel.
    let lastLine = CurrentValueSubject<String, Never>("")

    private var lastSnap: Senses.Snapshot?
    private var wasAsleep = false
    private var lastDecay = Date.timeIntervalSinceReferenceDate
    private var nextChatter = Date.timeIntervalSinceReferenceDate + 90
    private var nextEventRoll = Date.timeIntervalSinceReferenceDate + 120
    private var lastSpoke: TimeInterval = 0
    private var currentActivity: Activity?
    private var activitySince: TimeInterval = 0
    private var lastActivityLine: [Activity: TimeInterval] = [:]
    private var lastHungerLine: TimeInterval = 0
    private var rainbowUntil: TimeInterval = 0
    private var giantUntil: TimeInterval = 0
    private var spookyHourKey = ""
    private var exploringSince: TimeInterval?
    private var hovering = false
    let focus = FocusTimer()
    private var lastEditorReaction: TimeInterval = 0
    private var editorErrors = 0

    private var quietForFocus: Bool { focus.phase == .focus && prefs.focusQuiet }

    init(pet: PetController) {
        self.pet = pet
        pet.onHover = { [weak self] inside in self?.hover(inside) }
        package.onClick = { [weak self] in self?.openPackage() }
        life.achievementUnlocked
            .receive(on: RunLoop.main)
            .sink { [weak self] a in self?.celebrateAchievement(a) }
            .store(in: &cancellables)
        senses.onTick = { [weak self] snap in self?.tick(snap) }
    }

    func start() {
        senses.start()
        greetOnLaunch()
    }

    // MARK: - Talking

    func say(_ text: String, duration: TimeInterval = 5, force: Bool = false) {
        guard force || pet.isVisible, !pet.exploring || force else { return }
        lastSpoke = PetBrain.now
        lastLine.send(text)
        if pet.isVisible { bubble.show(text, near: pet.panel, duration: duration) }
    }

    func petMoved() { bubble.place(near: pet.panel) }

    private var name: String { life.s.profile.name.isEmpty ? "friend" : life.s.profile.name }

    private func hover(_ inside: Bool) {
        hovering = inside
        guard inside, !bubble.isShowing, let note = life.pinnedNote else { return }
        say("📌 \(note.text)", duration: 4, force: true)
    }

    // MARK: - Tick (every 0.5 s)

    private func tick(_ s: Senses.Snapshot) {
        let now = PetBrain.now
        lastSnap = s
        pet.systemIdle = s.idle
        pet.cursorLook = cursorLook(s)

        // Sleep / wake: jump awake when the cursor comes close.
        let asleep = pet.isAsleep
        if wasAsleep && !asleep && distanceToPet(s.mouse) < 160 && pet.brain.currentAct == nil {
            pet.perform(.surprised)
            say(["!! oh hi", "i'm up, i'm up!", "*yawn* …hi \(name)"].randomElement()!)
        }
        wasAsleep = asleep

        // Stats decay every 30 s.
        if now - lastDecay >= 30 {
            life.decay(seconds: now - lastDecay, asleep: asleep)
            lastDecay = now
            if s.idle < 120 && Int(now) % 600 < 30 { life.addCoins(1) } // a coin every ~10 active minutes
            life.saveSoon()
        }

        focusCheck()
        exploreCheck(s, now: now)
        guard !pet.exploring else { return }

        activityCheck(s, now: now)
        overridesCheck(now: now)
        needsCheck(now: now, idle: s.idle)

        if quietForFocus { return }
        if s.idle < 60 && now >= nextChatter && !bubble.isShowing {
            scheduleChatter(now)
            if prefs.chattiness != .quiet, let line = chatterLine() { say(line) }
        }
        if s.idle < 120 && now >= nextEventRoll {
            nextEventRoll = now + 60
            rollEvent()
        }
    }

    private func scheduleChatter(_ now: TimeInterval) {
        nextChatter = now + (prefs.chattiness.interval.map { Double.random(in: $0) } ?? 20 * 60)
    }

    private func distanceToPet(_ p: NSPoint) -> CGFloat { pet.panel.frame.center.distance(to: p) }

    private func cursorLook(_ s: Senses.Snapshot) -> (x: Int, y: Int)? {
        let c = pet.panel.frame.center
        if s.sinceMouseMove < 4 {
            let dx = s.mouse.x - c.x, dy = s.mouse.y - c.y
            return (dx < -50 ? -1 : (dx > 50 ? 1 : 0), dy > 70 ? -1 : (dy < -70 ? 1 : 0))
        }
        // Not moving the mouse but working in a code/design app: peek at the screen.
        if prefs.reactToApps, s.activity != nil, s.idle < 20, let vf = pet.panel.screen?.visibleFrame {
            return (vf.midX < c.x - 50 ? -1 : (vf.midX > c.x + 50 ? 1 : 0), 0)
        }
        return nil
    }

    // MARK: - Activities (frontmost app category)

    private func activityCheck(_ s: Senses.Snapshot, now: TimeInterval) {
        guard prefs.reactToApps else {
            if currentActivity != nil { currentActivity = nil; applyTaskOutfit(nil) }
            return
        }
        let a = s.idle < 90 ? s.activity : nil
        if a != currentActivity {
            let previous = currentActivity
            currentActivity = a
            activitySince = now
            applyTaskOutfit(a)
            if let a, previous == nil, now - (lastActivityLine[a] ?? 0) > 25 * 60, prefs.chattiness != .quiet, !bubble.isShowing, !quietForFocus {
                lastActivityLine[a] = now
                say(Lines.activityStart(a, name: name))
            }
        }
        guard let a else { return }
        let total = life.logActivity(a, seconds: 0.5)
        for hours in [1, 2, 3, 5] where total >= Double(hours * 3600) {
            let key = "\(PetLife.dayKey())-\(a.rawValue)-\(hours)h"
            if life.milestoneOnce(key) {
                say(Lines.activityMilestone(a, hours: hours, name: name), duration: 7, force: true)
                if hours >= 3 { life.remember("you spent \(hours) hours \(Lines.verb(a)) in one day", emoji: a.emoji) }
            }
        }
    }

    private func applyTaskOutfit(_ a: Activity?) {
        if focus.phase == .focus {
            pet.accessoryOverride = .headphones
            return
        }
        guard prefs.dressForTask, let a else {
            if pet.accessoryOverride != nil && rainbowUntil == 0 { pet.accessoryOverride = birthdayAccessory }
            if pet.heldOverride != nil { pet.heldOverride = nil }
            return
        }
        switch a {
        case .coding, .studying: pet.accessoryOverride = .glasses
        case .design: pet.accessoryOverride = .beret
        case .music, .video: pet.accessoryOverride = .headphones
        case .writing: pet.heldOverride = .notepad
        case .gaming: pet.heldOverride = .handheld
        case .slides: pet.accessoryOverride = .bow
        }
    }

    private var birthdayAccessory: Accessory? { isBirthday ? .partyHat : nil }

    // MARK: - Needs

    private func needsCheck(now: TimeInterval, idle: TimeInterval) {
        guard idle < 120, now - lastHungerLine > 20 * 60, !quietForFocus else { return }
        if life.s.hunger < 20 {
            lastHungerLine = now
            pet.perform(.sad)
            say(["i'm sooo hungry 🥺", "tummy rumbling…", "snack? pretty please? 🍙"].randomElement()!)
        } else if life.s.energy < 15 {
            lastHungerLine = now
            pet.perform(.yawn)
            say(["so… sleepy…", "a matcha would fix me 🍵", "*yaaawn*"].randomElement()!)
        }
    }

    private func chatterLine() -> String? {
        let roll = Int.random(in: 0..<10)
        if roll < 3, let m = life.oldMemory() { return "remember when \(m.text)? \(m.emoji)" }
        if roll < 5, let l = Lines.profileLine(life.s.profile) { return l }
        if roll < 6, let n = life.pinnedNote { return "psst — don't forget: \(n.text)" }
        if roll < 7, life.openTodos.count >= 2 { return "\(life.openTodos.count) things on your list — knock one out? ✅" }
        if roll == 7, let w = life.openWants.randomElement() {
            let name = w.title.count > 36 ? String(w.title.prefix(34)) + "…" : w.title
            return "still thinking about \(name)? 🛍️"
        }
        if roll < 7, let a = currentActivity { return Lines.activityIdle(a) }
        return Lines.idle(name: name, hour: Calendar.current.component(.hour, from: Date()))
    }

    // MARK: - Overrides (rainbow, giant, spooky, birthday)

    private var isBirthday: Bool {
        let p = life.s.profile
        guard p.birthdayMonth > 0 else { return false }
        let c = Calendar.current.dateComponents([.month, .day], from: Date())
        return c.month == p.birthdayMonth && c.day == p.birthdayDay
    }

    private func overridesCheck(now: TimeInterval) {
        if rainbowUntil > 0 {
            if now < rainbowUntil {
                pet.paletteOverride = .rainbow(hue: now / 2, over: prefs.paletteBase)
            } else {
                rainbowUntil = 0
                pet.paletteOverride = spookyActive ? .spooky : nil
            }
        }
        if giantUntil > 0 && now >= giantUntil {
            giantUntil = 0
            pet.giant = false
            say("…back to normal size 🍪")
        }
        let comps = Calendar.current.dateComponents([.hour], from: Date())
        let key = PetLife.dayKey()
        if comps.hour == 3 && spookyHourKey != key {
            spookyHourKey = key
            pet.paletteOverride = .spooky
            pet.perform(.surprised)
            say("👻 it's 3 AM… everything feels spooky", duration: 6)
            life.unlock(.nightOwl)
            if let acc = life.unlockSecret(.witchHat) { unlockedOutfit(acc) }
        } else if comps.hour != 3 && spookyActive && rainbowUntil == 0 {
            pet.paletteOverride = nil
        }
        if isBirthday && life.s.lastBirthdayYear != Calendar.current.component(.year, from: Date()) {
            life.s.lastBirthdayYear = Calendar.current.component(.year, from: Date())
            pet.accessoryOverride = .partyHat
            pet.perform(.celebrate)
            say("🎉 HAPPY BIRTHDAY \(name.uppercased())!! 🎂", duration: 8, force: true)
            life.addCoins(25)
            life.unlock(.birthday)
            life.remember("we celebrated your birthday together", emoji: "🎂")
        }
    }

    private var spookyActive: Bool { pet.paletteOverride == .spooky }

    // MARK: - Exploring

    private func exploreCheck(_ s: Senses.Snapshot, now: TimeInterval) {
        if !pet.exploring {
            guard prefs.exploring, s.idle > 30 * 60, pet.isVisible else { return }
            pet.exploring = true
            exploringSince = now
            bubble.hide()
        } else if s.idle < 3 {
            pet.exploring = false
            let found = Souvenir.allCases.filter { $0 != .goldenFish }.randomElement()!
            life.addSouvenir(found)
            life.addCoins(3)
            pet.perform(.celebrate)
            let away = Int((now - (exploringSince ?? now)) / 60)
            say("i went exploring and found a \(found.label.lowercased())!" + (away > 90 ? " (i was gone for ages)" : ""), duration: 7, force: true)
            life.remember("i went exploring and brought back a \(found.label.lowercased())", emoji: "🧭")
            life.unlock(.explorer)
            exploringSince = nil
        }
    }

    // MARK: - Launch greeting & day away

    private func greetOnLaunch() {
        let away = Date().timeIntervalSince(life.s.lastSeen)
        life.s.lastSeen = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if away > 24 * 3600 {
                let days = Int(away / 86400)
                self.life.s.notes.insert(PetNote(text: "Dear \(self.name), I missed you for \(days) day\(days == 1 ? "" : "s")! I kept your desk warm. — \(self.prefs.petName) ♡", color: 2), at: 0)
                self.life.unlock(.welcomeBack)
                self.pet.perform(.love)
                self.say("you're back!! i missed you 🥺 (i left you a note)", duration: 7, force: true)
            } else {
                self.say(Lines.greeting(name: self.name, hour: Calendar.current.component(.hour, from: Date())))
            }
            self.life.saveSoon()
        }
        // Keep lastSeen fresh while running.
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.life.s.lastSeen = Date() }
            .store(in: &cancellables)
    }

    // MARK: - User interactions

    func clicked() -> Bool {
        let n = life.click()
        pet.brain.wake()
        if n == 100 {
            rainbowUntil = PetBrain.now + 10
            pet.perform(.spin)
            say("✨ 100 POKES?! secret rainbow mode unlocked ✨", duration: 6, force: true)
            return true
        }
        if n == 500, let acc = life.unlockSecret(.halo) {
            pet.perform(.spin)
            unlockedOutfit(acc)
            return true
        }
        if n % 25 == 0 { pet.perform(.love) }
        return false
    }

    func feed(_ food: Food) -> PetLife.FeedResult {
        let r = life.feed(food)
        switch r {
        case .ok:
            pet.brain.wake()
            pet.perform(.eat(food))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                guard let self else { return }
                self.say(food.lines.randomElement()!, duration: 3)
                if food == .cookie && self.life.s.cookiesToday == 10 { self.goGiant() }
            }
        case .broke: say("that costs \(food.cost) 🪙 — we're a bit short", duration: 3)
        case .full: say("i'm so full… maybe later 😮‍💨", duration: 3)
        }
        return r
    }

    private func goGiant() {
        giantUntil = PetBrain.now + 60
        pet.giant = true
        pet.perform(.celebrate)
        say("10 COOKIES. i am… BIG MOCHI now 🍪🍪🍪", duration: 6, force: true)
        life.unlock(.bigMochi)
        life.remember("i ate 10 cookies and became gigantic", emoji: "🍪")
    }

    func pat() {
        life.pat()
        pet.brain.wake()
        pet.perform(.love)
        say(["hehe ♡", "more pats pls", "purr… wait, am i a cat?", "that's the spot ✨"].randomElement()!, duration: 2.5)
    }

    func play() {
        life.play()
        pet.brain.wake()
        pet.perform([.play, .dance].randomElement()!)
        say(["wheee!", "again again!", "i win!! (i think)", "zoomies!!"].randomElement()!, duration: 2.5)
    }

    func nap() {
        pet.brain.nap(for: 10 * 60)
        say("goodnight… 💤", duration: 2)
    }

    func give(_ item: Souvenir) {
        let unlocked = life.give(item)
        pet.perform(.love)
        if let unlocked { unlockedOutfit(unlocked) }
        else { say("for me?! i'll treasure this \(item.label.lowercased()) ♡", duration: 4) }
    }

    // MARK: - Focus timer

    func startFocus(minutes: Int? = nil) {
        let m = minutes ?? prefs.focusMinutes
        focus.start(.focus, minutes: m)
        pet.brain.wake()
        pet.accessoryOverride = .headphones
        pet.perform(.love)
        say("🍅 \(m)-minute focus — i'll be quiet. you've got this!", duration: 4, force: true)
    }

    func stopFocus() {
        let was = focus.phase
        focus.stop()
        applyTaskOutfit(currentActivity)
        if was == .focus { say("focus stopped — that still counts as trying ♡", duration: 3, force: true) }
    }

    func skipBreak() {
        guard focus.phase == .rest else { return }
        focus.stop()
        say("break skipped! back at it? 🍅", duration: 3, force: true)
    }

    private func focusCheck() {
        guard focus.isRunning, focus.remaining <= 0 else { return }
        switch focus.phase {
        case .focus:
            let m = focus.minutes
            life.focusFinished(minutes: m)
            focus.start(.rest, minutes: prefs.breakMinutes)
            applyTaskOutfit(currentActivity)
            pet.perform(.celebrate)
            say("🍅 \(m) minutes of focus — amazing! (+3 🪙) take \(prefs.breakMinutes) min to stretch ☕", duration: 7, force: true)
            if m >= 45 { life.remember("you focused for \(m) minutes straight", emoji: "🍅") }
        case .rest:
            focus.stop()
            pet.perform(.wave)
            say("break's over! ready for another round? 🍅 (right-click me → Focus)", duration: 6, force: true)
        case .idle:
            break
        }
    }

    // MARK: - Shop

    func buy(_ item: ShopItem) -> PetLife.BuyResult {
        let r = life.buy(item)
        switch r {
        case .bought:
            if let acc = item.accessory { prefs.accessory = acc; life.triedAccessory(acc) }
            if let p = item.palette { prefs.palettePreset = p }
            if let h = item.held { prefs.held = h }
            pet.brain.wake()
            pet.perform(.celebrate)
            say(item.boughtLine, duration: 4, force: true)
        case .broke:
            say("we need \(item.price - life.s.coins) more 🪙 for that — finish some to-dos?", duration: 4, force: true)
        case .alreadyOwned:
            break
        }
        return r
    }

    // MARK: - Rock, paper, scissors

    enum RPSOutcome { case youWin, petWins, tie }

    func rpsRound(_ outcome: RPSOutcome) {
        pet.brain.wake()
        switch outcome {
        case .youWin: pet.perform(.sad)
        case .petWins: pet.perform(.celebrate)
        case .tie: pet.perform(.surprised)
        }
        life.touch()
    }

    func rpsMatch(youWon: Bool) {
        if youWon {
            life.rpsMatchWon()
            pet.perform(.love)
        } else {
            pet.perform(.dance)
            life.gainXP(1)
        }
    }

    // MARK: - Wants list (drag links onto the pet)

    private var lastDropHoverLine: TimeInterval = 0

    func dropHover(_ inside: Bool) {
        guard inside else { return }
        pet.brain.wake()
        if pet.brain.currentAct == nil { pet.perform(.surprised) }
        if PetBrain.now - lastDropHoverLine > 6 {
            lastDropHoverLine = PetBrain.now
            say("ooh! drop it on me 🛍️", duration: 2, force: true)
        }
    }

    func handleDrop(_ pb: NSPasteboard) -> Bool {
        let items = DropParser.items(from: pb)
        guard !items.isEmpty else {
            say("hmm, i can only hold links and text", duration: 3, force: true)
            return false
        }
        saveWants(items)
        return true
    }

    /// From the Wants tab's text box: a link or a plain wish.
    func addWant(text: String) {
        saveWants([DropParser.Item(title: DropParser.webURL(text) == nil ? text : nil, url: DropParser.webURL(text))])
    }

    func saveWants(_ items: [DropParser.Item]) {
        var added: [WantItem] = []
        var duplicates = 0
        for item in items {
            switch life.addWant(title: item.title, url: item.url) {
            case .added(let w): added.append(w)
            case .duplicate: duplicates += 1
            }
        }
        pet.brain.wake()
        if let first = added.first {
            pet.perform(.celebrate)
            let name = first.title.count > 40 ? String(first.title.prefix(38)) + "…" : first.title
            say(added.count == 1 ? "saved “\(name)” to your wants 🛍️" : "saved \(added.count) things to your wants 🛍️", duration: 4, force: true)
        } else if duplicates > 0 {
            pet.perform(.love)
            say("that's already on your wants list ♡", duration: 3, force: true)
        }
    }

    // MARK: - To-dos

    func addTodo(_ text: String) {
        life.addNote(text)
        pet.brain.wake()
        noticeTyped(text)
        if pet.brain.currentAct == nil { pet.perform(.love) }
        let open = life.openTodos.count
        say(["got it ✍️", "added! (\(open) on the list)", "i'll hold onto that 📌", "noted ♡"].randomElement()!, duration: 2.5, force: true)
    }

    func toggleTodo(_ id: UUID) {
        guard life.toggleDone(id) else { return }
        pet.brain.wake()
        pet.perform(.celebrate)
        let left = life.openTodos.count
        let line = left == 0 ? "ALL DONE!! the list is empty ✨ (+1 🪙)" : ["done! ✨ \(left) to go (+1 🪙)", "checked off! (+1 🪙)", "one less thing ♡ (+1 🪙)"].randomElement()!
        say(line, duration: 3, force: true)
    }

    /// Typed text (notes, facts) is checked for the secret word — only inside Mochi, never system-wide.
    func noticeTyped(_ text: String) {
        guard text.lowercased().contains("mochi") else { return }
        if life.unlock(.secretWord) {
            pet.perform(.spin)
            say("THAT'S ME!! you said my name!! ✨", duration: 5, force: true)
        } else {
            pet.perform(.love)
            say("you called? ♡", duration: 3, force: true)
        }
    }

    private func unlockedOutfit(_ acc: Accessory) {
        say("🔓 secret outfit unlocked: \(acc.label)! (Closet → Outfits)", duration: 7, force: true)
        life.remember("you unlocked my secret \(acc.label.lowercased())", emoji: "👒")
    }

    private func celebrateAchievement(_ a: Achievement) {
        guard a != .hatched else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.bubble.isShowing || a.isSecret else { return }
            self.say("🏆 \(a.title)! (+\(a.coins) 🪙)", duration: 4, force: true)
        }
    }

    // MARK: - Terminal / build hooks (mochi:// URLs)

    func handle(url: URL) {
        guard url.scheme == "mochi" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ k: String) -> String? { items.first { $0.name == k }?.value }
        let what = url.host ?? ""
        switch what {
        case "build", "test", "terminal":
            let ok = (q("status") ?? "0") == "0" && q("result") != "fail"
            let secs = Int(q("seconds") ?? "") ?? 0
            buildResult(ok: ok, seconds: secs, kind: what == "test" ? "tests" : "build")
        case "success": buildResult(ok: true, seconds: 0, kind: "build")
        case "fail", "error": buildResult(ok: false, seconds: 0, kind: "build")
        case "editor":
            editorDiagnostics(errors: Int(q("errors") ?? "") ?? 0)
        case "commit":
            pet.perform(.dance)
            say(["committed! 📦✨", "another one in the history books", "git gud (you did)"].randomElement()!)
            life.gainXP(2)
        case "home", "open":
            AppDelegate.shared?.openHome()
        default:
            break
        }
    }

    /// From the VS Code extension: error count changed (it only sends real transitions).
    private func editorDiagnostics(errors: Int) {
        let now = PetBrain.now
        defer { editorErrors = errors }
        guard now - lastEditorReaction > 8 else { return }
        lastEditorReaction = now
        pet.brain.wake()
        if errors > 0 && editorErrors == 0 {
            pet.perform(.sad)
            say(errors == 1 ? "😰 uh oh, a red squiggle…" : "😰 uh oh, \(errors) errors…", duration: 3, force: !quietForFocus)
        } else if errors == 0 && editorErrors > 0 {
            pet.perform(.celebrate)
            say(["✨ all clean!", "no more squiggles ✨", "fixed it!! 🎉"].randomElement()!, duration: 3, force: !quietForFocus)
        }
    }

    private func buildResult(ok: Bool, seconds: Int, kind: String) {
        pet.brain.wake()
        if ok {
            life.s.buildsOK += 1
            let streakBroken = life.s.failStreak
            life.s.failStreak = 0
            pet.perform(.celebrate)
            if streakBroken >= 3 {
                say("✨ WE DID IT ✨ after \(streakBroken) tries!!", duration: 6, force: true)
                life.remember("we fixed that \(kind) after \(streakBroken) failed tries", emoji: "🛠️")
            } else {
                say(["✨ WE DID IT ✨", "it compiles!! 🎉", "green checks all around ✅", "ship it!! 🚀"].randomElement()!, force: true)
            }
            if life.s.buildsOK == 1 { life.unlock(.itCompiles) }
            if life.s.buildsOK == 10 { life.unlock(.buildHero) }
            life.gainXP(2)
        } else {
            life.s.buildsFailed += 1
            life.s.failStreak += 1
            pet.perform(.fall)
            if life.s.failStreak >= 3 {
                say(["\(life.s.failStreak) in a row… deep breaths, we got this 🫧", "it's not you, it's the semicolon 😭"].randomElement()!, duration: 6, force: true)
            } else {
                say(["uh oh 💥", "the \(kind) fell over (and so did i)", "😰 red text…"].randomElement()!, force: true)
            }
        }
        if seconds > 600 { life.remember("a \(kind) took \(seconds / 60) whole minutes", emoji: "⏳") }
        life.saveSoon()
    }

    // MARK: - Random events

    private enum Rarity { case common, uncommon, rare, legendary }

    private func rollEvent() {
        guard prefs.randomEvents != .off, !quietForFocus, pet.isVisible, !pet.isAsleep, pet.brain.currentAct == nil, !actors.isBusy else { return }
        let mult = prefs.randomEvents == .often ? 2 : 1
        let r = Int.random(in: 1...1000)
        let rarity: Rarity?
        if r <= 1 * mult { rarity = .legendary }
        else if r <= 5 * mult { rarity = .rare }
        else if r <= 25 * mult { rarity = .uncommon }
        else if r <= 125 * mult { rarity = .common }
        else { rarity = nil }
        guard let rarity else { return }
        trigger(rarity)
    }

    /// Exposed for Settings → "Surprise event" and testing.
    func triggerRandomEvent() {
        trigger([.common, .common, .uncommon, .uncommon, .rare].randomElement()!)
    }

    private func trigger(_ rarity: Rarity) {
        guard let screen = pet.panel.screen ?? NSScreen.main else { return }
        let key: String
        switch rarity {
        case .common:
            switch Int.random(in: 0..<5) {
            case 0:
                key = "cookie"
                pet.perform(.eat(.cookie))
                life.s.hunger = min(100, life.s.hunger + 6)
                say("🍪 found a cookie under the keyboard!", duration: 4)
            case 1:
                key = "sneeze"
                pet.perform(.sneeze)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in self?.say("ACHOO! 💨", duration: 2) }
            case 2:
                key = "nap"
                pet.brain.nap(for: 90)
                say("just… resting my eyes… 💤", duration: 3)
            case 3:
                key = "investigate"
                pet.perform(.investigate)
                say("🕵️ what IS that pointy thing…", duration: 3)
            default:
                key = "dance"
                pet.perform(.dance)
                say("♪ dance break ♪", duration: 3)
            }
        case .uncommon:
            switch Int.random(in: 0..<3) {
            case 0:
                key = "coin"
                pet.perform(.coin)
                life.addCoins(5)
                say("💰 ooh a shiny coin! (+5)", duration: 4)
            case 1:
                key = "balloon"
                pet.floatAway()
                say("🎈 wheee— i'll be right back!", duration: 4)
            default:
                key = "bug"
                spawnCritter(.ladybug, on: screen, speed: 55, height: 0)
                pet.perform(.investigate)
                say("🐛 a bug! (the cute kind, not the code kind)", duration: 4)
                life.unlock(.bugSpotter)
            }
        case .rare:
            switch Int.random(in: 0..<4) {
            case 0:
                key = "fish"
                spawnCritter(.goldenFish, on: screen, speed: 130, height: 0.35, bob: 6)
                life.addSouvenir(.goldenFish)
                pet.perform(.surprised)
                say("🐟 a GOLDEN fish swam by and dropped something! (right-click me → Give)", duration: 6)
                life.remember("a golden fish swam across your screen", emoji: "🐟")
            case 1:
                key = "ghost"
                spawnCritter(.ghost, on: screen, speed: 70, height: 0.5, bob: 10, alpha: 0.75)
                pet.perform(.surprised)
                say("👻 d-did you see that??", duration: 5)
                life.remember("we saw a ghost float across the screen", emoji: "👻")
            case 2:
                key = "visitor"
                spawnVisitor(on: screen)
            default:
                key = "rain"
                pet.perform(.rained)
                say("🌧️ it's raining in here?!", duration: 4)
                life.remember("it rained indoors and i got soaked", emoji: "🌧️")
            }
        case .legendary:
            key = "package"
            package.show(.gift, scale: CGFloat(max(3, prefs.petScale)), beside: pet.panel.frame)
            pet.perform(.surprised)
            say("📦 a mystery package arrived! click it!", duration: 8, force: true)
            life.unlock(.lucky)
        }
        life.s.eventsSeen[key, default: 0] += 1
        life.gainXP(rarity == .common ? 1 : 5)
    }

    private func openPackage() {
        package.hide()
        pet.perform(.celebrate)
        if let acc = life.unlockSecret(.wizard) {
            unlockedOutfit(acc)
        } else {
            life.addCoins(25)
            life.addSouvenir(.gem)
            say("🎁 25 coins and a tiny gem!!", duration: 5, force: true)
        }
        life.remember("a legendary mystery package showed up", emoji: "📦")
    }

    private func spawnCritter(_ icon: PixelIcon, on screen: NSScreen, speed: CGFloat, height: CGFloat, bob: CGFloat = 0, alpha: CGFloat = 1) {
        let vf = screen.visibleFrame
        let scale = CGFloat(max(3, prefs.petScale - 1))
        let size = CGSize(width: CGFloat(icon.width) * scale, height: CGFloat(icon.height) * scale)
        let y = vf.minY + 4 + (vf.height - size.height - 40) * height
        let fromLeft = Bool.random()
        let a = ActorLayer.Actor(
            image: icon.cgImage(), size: size,
            waypoints: [(CGPoint(x: fromLeft ? vf.minX - size.width : vf.maxX + size.width, y: y), 0),
                        (CGPoint(x: fromLeft ? vf.maxX + size.width : vf.minX - size.width, y: y), 0)],
            speed: speed, bob: bob, alpha: alpha, facingLeft: !fromLeft)
        actors.spawn(a, on: screen)
    }

    private func spawnVisitor(on screen: NSScreen) {
        let vf = screen.visibleFrame
        let look = CreatureLook(species: Species.allCases.randomElement()!, eyes: .bean,
                                accessory: [.bow, .beanie, .flowerCrown, .none].randomElement()!, held: .none, blush: true)
        let base = PalettePreset.allCases.filter { $0 != .custom && $0 != prefs.palettePreset }.randomElement()!.base!
        let img = SpriteRenderer.frame(look: look, pose: Pose(expression: .happy), colors: SpriteColors.make(base)).image
        let side = CGFloat(32 * max(2, prefs.petScale - 1))
        let pf = pet.panel.frame
        let fromLeft = pf.midX > vf.midX
        let startX = fromLeft ? vf.minX - side : vf.maxX + side
        let meetX = fromLeft ? pf.minX - side * 0.6 : pf.maxX + side * 0.6
        let y = max(vf.minY, pf.minY)
        var a = ActorLayer.Actor(image: img, size: CGSize(width: side, height: side),
                                 waypoints: [(CGPoint(x: startX, y: y), 0), (CGPoint(x: meetX, y: y), 3.0), (CGPoint(x: startX, y: y), 0)],
                                 speed: 80, facingLeft: !fromLeft)
        a.onArrive = { [weak self] i in
            guard i == 1, let self else { return }
            self.pet.perform(.wave)
            self.say(["a visitor!! hi hi 👋", "oh! a new friend ♡", "we're having a playdate!"].randomElement()!, duration: 3)
        }
        actors.spawn(a, on: screen)
        life.remember("a tiny \(look.species.label.lowercased()) came to visit", emoji: "🧸")
    }
}

// MARK: - Line library

enum Lines {
    static func greeting(name: String, hour: Int) -> String {
        switch hour {
        case 5..<12: return ["good morning \(name) ☀️", "morning! coffee first? ☕", "rise and shine ✨"].randomElement()!
        case 12..<17: return ["hi \(name)! good afternoon ♡", "hey :)", "afternoon snack time? 🍪"].randomElement()!
        case 17..<22: return ["good evening \(name) 🌙", "evening vibes ✨", "hey you :) how was today?"].randomElement()!
        default: return ["up late, \(name)? 🌙", "night owl mode 🦉", "shh… the pixels are sleeping"].randomElement()!
        }
    }

    static func idle(name: String, hour: Int) -> String {
        var pool = ["hey :)", "i'm just vibing here ✨", "you're doing great, \(name)", "*sips* ☕",
                    "posture check! 🧍", "water break? 💧", "i believe in you ♡", "blink twice if you need a snack 🍙",
                    "tiny reminder: you're awesome", "hmm hm hmm ♪"]
        if hour >= 23 || hour < 5 { pool += ["sleep is a feature, not a bug 🌙", "it's late… one more thing, then bed?"] }
        if hour >= 6 && hour < 10 { pool += ["breakfast counts as a task ✅"] }
        return pool.randomElement()!
    }

    static func profileLine(_ p: UserProfile) -> String? {
        var pool: [String] = []
        if !p.favoriteGames.isEmpty { pool += ["thinking about \(p.favoriteGames) again 🎮", "one round of \(p.favoriteGames) after this? 👀"] }
        if !p.favoriteColor.isEmpty { pool += ["saw something \(p.favoriteColor.lowercased()) earlier and thought of you", "\(p.favoriteColor.lowercased()) is objectively the best color"] }
        if let fact = p.facts.randomElement() { pool += ["i remember: \(fact) ♡", "you told me \(fact) — still true?"] }
        return pool.randomElement()
    }

    static func verb(_ a: Activity) -> String {
        switch a {
        case .coding: return "coding"
        case .slides: return "on slides"
        case .design: return "designing"
        case .writing: return "writing"
        case .studying: return "studying"
        case .gaming: return "gaming"
        case .video: return "editing video"
        case .music: return "making music"
        }
    }

    static func activityStart(_ a: Activity, name: String) -> String {
        switch a {
        case .coding: return ["👀 ooh, code time", "let's squash some bugs 🐛", "i'll watch the semicolons"].randomElement()!
        case .slides: return ["presentation mode! you got this 🎤", "make those slides sparkle ✨"].randomElement()!
        case .design: return ["make it pretty ✨", "design mode: activated 🎨", "ooh what are we making?"].randomElement()!
        case .writing: return ["words, words, words ✍️", "i'll be quiet… mostly"].randomElement()!
        case .studying: return ["study buddy reporting for duty 📚", "you'll ace it 💯"].randomElement()!
        case .gaming: return ["game time!! 🎮", "can i be player 2?"].randomElement()!
        case .video: return ["🎬 lights, camera, render bar", "cut! (that was great)"].randomElement()!
        case .music: return ["🎧 vibes incoming", "bop detected ♪"].randomElement()!
        }
    }

    static func activityIdle(_ a: Activity) -> String {
        switch a {
        case .coding: return ["have you tried turning it off and on again? 🔌", "commit early, commit often 📦", "that function looks cozy"].randomElement()!
        case .slides: return "less text, more pictures 📊"
        case .design: return "zoom out and squint — looks great 👀"
        case .writing: return "that last sentence? chef's kiss ✍️"
        case .studying: return "quiz me later? 📚"
        case .gaming: return "gg 🎮"
        case .video: return "save your project! 💾"
        case .music: return "this one's a banger ♪"
        }
    }

    static func activityMilestone(_ a: Activity, hours: Int, name: String) -> String {
        "that's \(hours) hour\(hours == 1 ? "" : "s") \(verb(a)) today — stretch break? 🧘"
    }
}
