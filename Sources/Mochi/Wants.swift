import AppKit
import SwiftUI

/// Reads links and text dropped onto the pet. Nothing is fetched — titles come from the browser or the URL itself.
enum DropParser {
    struct Item: Equatable {
        var title: String?
        var url: URL?
    }

    static let urlName = NSPasteboard.PasteboardType("public.url-name")
    static let webURLsWithTitles = NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType")
    static var acceptedTypes: [NSPasteboard.PasteboardType] { [.URL, urlName, webURLsWithTitles, .string] }

    static func webURL(_ s: String) -> URL? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.contains(" "), let u = URL(string: t), let scheme = u.scheme?.lowercased(),
              scheme == "http" || scheme == "https", u.host != nil else { return nil }
        return u
    }

    static func items(from pb: NSPasteboard) -> [Item] {
        var out: [Item] = []
        // Safari/WebKit: parallel arrays of URLs and page titles.
        if let plist = pb.propertyList(forType: webURLsWithTitles) as? [[String]], plist.count == 2 {
            for (i, raw) in plist[0].enumerated() {
                if let url = webURL(raw) { out.append(Item(title: i < plist[1].count ? plist[1][i] : nil, url: url)) }
            }
        }
        // Chrome, Firefox, links, the address-bar icon: URL objects (+ a page title when the browser provides one).
        if out.isEmpty, let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let title = pb.string(forType: urlName)
            let web = urls.compactMap { webURL($0.absoluteString) }
            for url in web { out.append(Item(title: web.count == 1 ? title : nil, url: url)) }
        }
        // Plain text: a link, or a few short lines ("oat milk", "new headphones").
        if out.isEmpty, let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            if let url = webURL(text) {
                out.append(Item(title: nil, url: url))
            } else {
                let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if lines.count <= 8 && lines.allSatisfy({ $0.count <= 120 }) {
                    out += lines.map { Item(title: $0, url: webURL($0)) }
                } else {
                    out.append(Item(title: String(text.prefix(120)) + (text.count > 120 ? "…" : ""), url: nil))
                }
            }
        }
        return Array(out.prefix(20))
    }
}

// MARK: - Wants tab

struct WantsTab: View {
    let director: Director
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    @State private var draft = ""
    @State private var showGot = false
    @FocusState private var focused: Bool
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                IconImage(icon: .bag, scale: 3)
                Text("Drag a link or browser tab onto \(prefs.petName) to save it here — or type or paste one below.")
                    .font(t.font(11)).foregroundStyle(t.subInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(t.accent)
                TextField("", text: $draft, prompt: Text("add a wish or paste a link…").foregroundColor(t.subInk))
                    .textFieldStyle(.plain)
                    .font(t.font(13))
                    .foregroundStyle(t.ink)
                    .focused($focused)
                    .onSubmit(add)
                    .accessibilityLabel("New wish")
                Button("Add", action: add)
                    .buttonStyle(t.button)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .retroBox(fill: t.panel, border: t.border, notch: t.rounded ? 0 : 3, line: 2)
            .padding(.horizontal, 12)

            if life.s.wants.isEmpty {
                VStack(spacing: 8) {
                    SpriteImage(look: prefs.look, pose: Pose(expression: .happy), colors: prefs.spriteColors, size: 64)
                    Text("Your wants list is empty.\nTry dragging a product link onto me! 🛍️")
                        .font(t.font(11)).foregroundStyle(t.subInk).multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(life.openWants) { WantRow(item: $0) }
                        if !life.gotWants.isEmpty {
                            HStack {
                                Button { showGot.toggle() } label: {
                                    Label("Got it (\(life.gotWants.count))", systemImage: showGot ? "chevron.down" : "chevron.right")
                                        .font(t.font(11, .bold)).foregroundStyle(t.subInk)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button("Clear") { life.clearGotWants() }.buttonStyle(t.quietButton)
                            }
                            .padding(.top, 6)
                            if showGot { ForEach(life.gotWants) { WantRow(item: $0) } }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        director.addWant(text: text)
    }
}

struct WantRow: View {
    let item: WantItem
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var life = PetLife.shared
    private var t: ThemeColors { prefs.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { life.toggleGot(item.id) } label: {
                ZStack {
                    Rectangle().fill(item.isGot ? t.accent : t.petBubble).frame(width: 16, height: 16)
                    Rectangle().stroke(t.border, lineWidth: 2).frame(width: 16, height: 16)
                    if item.isGot { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(t.bg) }
                }
            }
            .buttonStyle(.plain)
            .help(item.isGot ? "Move back to wants" : "Got it!")
            .accessibilityLabel(item.isGot ? "Mark not got" : "Mark got it")
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(t.font(13, .medium))
                    .foregroundStyle(item.isGot ? t.subInk : t.ink)
                    .strikethrough(item.isGot, color: t.subInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text([item.site, item.added.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.joined(separator: " · "))
                    .font(t.font(9)).foregroundStyle(t.subInk)
                TextField("", text: Binding(get: { item.note }, set: { life.setWantNote(item.id, $0) }),
                          prompt: Text("price, size, color, notes…").foregroundColor(t.subInk.opacity(0.7)))
                    .textFieldStyle(.plain)
                    .font(t.font(11))
                    .foregroundStyle(t.ink)
                    .accessibilityLabel("Note for \(item.title)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let link = item.link {
                icon("arrow.up.forward.square", "Open \(item.site ?? "link") in your browser") { NSWorkspace.shared.open(link) }
                icon("doc.on.doc", "Copy link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link.absoluteString, forType: .string)
                }
            }
            icon("trash", "Delete") { life.deleteWant(item.id) }
        }
        .padding(10)
        .background(t.petBubble)
        .overlay(Rectangle().stroke(t.border.opacity(0.35), lineWidth: 1.5))
    }

    private func icon(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(t.subInk) }
            .buttonStyle(.plain)
            .help(help)
            .accessibilityLabel(help)
    }
}
