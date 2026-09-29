import AppKit
import Carbon.HIToolbox

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool
    var keyLabel: String

    static let `default` = HotKeyCombo(keyCode: UInt32(kVK_Space), command: true, option: true, control: true, shift: false, keyLabel: "Space")

    var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + keyLabel
    }

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if command { m |= UInt32(cmdKey) }
        if option { m |= UInt32(optionKey) }
        if control { m |= UInt32(controlKey) }
        if shift { m |= UInt32(shiftKey) }
        return m
    }

    /// Well-known system shortcuts that Carbon happily "registers" but that never reach us.
    var reservedReason: String? {
        let onlyCmd = command && !option && !control && !shift
        switch Int(keyCode) {
        case kVK_Space:
            if onlyCmd { return "⌘Space opens Spotlight." }
            if control && !command && !shift { return "⌃Space switches input sources." }
            if control && command && !option && !shift { return "⌃⌘Space opens the emoji picker." }
        case kVK_Tab where onlyCmd: return "⌘Tab switches apps."
        case kVK_ANSI_Q where onlyCmd, kVK_ANSI_W where onlyCmd, kVK_ANSI_H where onlyCmd,
             kVK_ANSI_M where onlyCmd, kVK_ANSI_C where onlyCmd, kVK_ANSI_V where onlyCmd, kVK_ANSI_X where onlyCmd:
            return "\(display) is a standard app shortcut."
        default: break
        }
        return nil
    }

    static func label(for event: NSEvent) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let s = special[Int(event.keyCode)] { return s }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }

    static func isFunctionKey(_ code: UInt16) -> Bool {
        [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12].contains(Int(code))
    }
}

/// Registers one global shortcut through Carbon's hot-key API (no Accessibility permission needed).
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    enum Status: Equatable {
        case inactive
        case active(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .inactive
    var onFire: (() -> Void)?

    private var ref: EventHotKeyRef?
    private var handlerInstalled = false
    private var suspended = false
    private var combo: HotKeyCombo?
    private var enabled = false

    func configure(combo: HotKeyCombo, enabled: Bool) {
        self.combo = combo
        self.enabled = enabled
        apply()
    }

    /// Temporarily releases the shortcut, e.g. while the user is recording a new one.
    func suspend() { suspended = true; apply() }
    func resume() { suspended = false; apply() }

    private func apply() {
        if let ref {
            UnregisterEventHotKey(ref)
            self.ref = nil
        }
        guard enabled, !suspended, let combo else { status = .inactive; return }
        if let reason = combo.reservedReason {
            status = .failed("\(reason) Pick a different combination.")
            return
        }
        installHandlerIfNeeded()
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4D4F_4348), id: 1) // "MOCH"
        let err = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id, GetApplicationEventTarget(), 0, &newRef)
        if err == noErr, let newRef {
            ref = newRef
            status = .active(combo.display)
        } else if err == OSStatus(eventHotKeyExistsErr) {
            status = .failed("\(combo.display) is already taken by another app. Pick a different combination.")
        } else {
            status = .failed("Couldn't register \(combo.display) (error \(err)). Try another combination.")
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { HotKeyManager.shared.onFire?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
