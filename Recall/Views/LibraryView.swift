import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(store.sources, id: \.self) { source in
                            VStack(alignment: .leading, spacing: 12) {
                                Label(source, systemImage: "shippingbox")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.ink2)
                                ForEach(store.packs.filter { $0.sourceName == source }) { pack in
                                    NavigationLink(value: pack) { PackRow(pack: pack) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("pack-\(pack.id)")
                                }
                            }
                        }
                        if store.packs.isEmpty {
                            ContentUnavailableView("Паков пока нет", systemImage: "tray",
                                                   description: Text("Импортируй JSON-пак в настройках."))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                } else {
                    SearchResults(query: query)
                }
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Темы")
            .searchable(text: $query, prompt: "Поиск по вопросам и ответам")
            .navigationDestination(for: Pack.self) { PackView(pack: $0) }
            .navigationDestination(for: TopicRoute.self) { TopicView(pack: $0.pack, topic: $0.topic) }
        }
    }
}

struct TopicRoute: Hashable { let pack: Pack; let topic: Topic }

struct PackRow: View {
    @Environment(AppStore.self) private var store
    let pack: Pack
    var body: some View {
        let refs = store.refs(pack)
        let m = store.mastery(refs)
        HStack(spacing: 14) {
            Image(systemName: pack.symbol)
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.accentBg))
            VStack(alignment: .leading, spacing: 6) {
                Text(pack.title).font(.cardTitle).foregroundStyle(Palette.ink)
                if let s = pack.subtitle {
                    Text(s).font(.caption).foregroundStyle(Palette.ink2).lineLimit(1)
                }
                HStack(spacing: 8) {
                    ProgressBar(value: m, height: 6)
                    Text("\(Int(m * 100))%").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Palette.ink2)
                }
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
        }
        .padding(16)
        .tactile(radius: 20)
        .opacity(store.isEnabled(pack) ? 1 : 0.55)
        .accessibilityElement(children: .combine)
    }
}

struct PackView: View {
    @Environment(AppStore.self) private var store
    let pack: Pack
    @State private var session: Session?

    var body: some View {
        let refs = store.refs(pack)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    if let s = pack.subtitle { Text(s).font(.subheadline).foregroundStyle(Palette.ink2) }
                    LevelBar(refs: refs)
                }
                HStack(spacing: 10) {
                    PrimaryButton(title: "Тест · 15", icon: "checklist") {
                        session = Session(title: pack.title, cards: store.quizQueue(refs, count: 15))
                    }
                    PrimaryButton(title: "Новые", icon: "plus", fill: Palette.surface, fg: Palette.ink) {
                        let fresh = refs.filter { store.state($0).seen == 0 }
                        session = Session(title: pack.title, cards: Array(fresh.prefix(15)))
                    }
                    .disabled(store.count(refs, .new) == 0)
                }
                Text("Темы").font(.cardTitle).foregroundStyle(Palette.ink).padding(.top, 8)
                ForEach(pack.topics) { topic in
                    NavigationLink(value: TopicRoute(pack: pack, topic: topic)) {
                        TopicRow(pack: pack, topic: topic)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("topic-\(topic.id)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(pack.title)
        .fullScreenCover(item: $session) { SessionView(session: $0) }
    }
}

struct TopicRow: View {
    @Environment(AppStore.self) private var store
    let pack: Pack
    let topic: Topic
    var body: some View {
        let refs = store.refs(pack, topic: topic.id)
        let m = store.mastery(refs)
        HStack(spacing: 12) {
            Image(systemName: topic.symbol)
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Palette.surface2))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(topic.title).font(.body.weight(.medium)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(refs.count)").font(.caption.monospacedDigit()).foregroundStyle(Palette.ink2)
                }
                ProgressBar(value: m, tint: m >= 0.75 ? Palette.good : Palette.accent, height: 5)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
        }
        .padding(14)
        .soft(radius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Stacked bar: new / learning / known / mastered.
struct LevelBar: View {
    @Environment(AppStore.self) private var store
    let refs: [CardRef]
    var body: some View {
        let parts: [(CardState.Level, Color, String)] = [
            (.mastered, Palette.good, "Закреплено"),
            (.known, Palette.accent, "Выучено"),
            (.learning, Palette.flame, "Учу"),
            (.new, Palette.surface2, "Новые"),
        ]
        let counts = parts.map { store.count(refs, $0.0) }
        let total = max(1, refs.count)
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts.indices, id: \.self) { i in
                        if counts[i] > 0 {
                            Rectangle().fill(parts[i].1)
                                .frame(width: max(4, geo.size.width * Double(counts[i]) / Double(total) - 2))
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            HStack(spacing: 14) {
                ForEach(parts.indices, id: \.self) { i in
                    HStack(spacing: 5) {
                        Circle().fill(parts[i].1).frame(width: 8, height: 8)
                            .overlay(Circle().strokeBorder(Palette.ink2.opacity(i == 3 ? 0.4 : 0), lineWidth: 1))
                        Text("\(parts[i].2) \(counts[i])").font(.caption).foregroundStyle(Palette.ink2)
                    }
                }
            }
        }
        .padding(16)
        .soft()
        .accessibilityElement(children: .combine)
    }
}

struct TopicView: View {
    @Environment(AppStore.self) private var store
    let pack: Pack
    let topic: Topic
    @State private var session: Session?
    @State private var open: Set<String> = []

    var body: some View {
        let refs = store.refs(pack, topic: topic.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LevelBar(refs: refs)
                HStack(spacing: 10) {
                    PrimaryButton(title: "Тест · \(min(10, refs.count))", icon: "checklist") {
                        session = Session(title: topic.title, cards: store.quizQueue(refs, count: 10))
                    }
                    PrimaryButton(title: "Все \(refs.count)", icon: "rectangle.stack", fill: Palette.surface, fg: Palette.ink) {
                        session = Session(title: topic.title, cards: refs.shuffled())
                    }
                }
                Text("Шпаргалка").font(.cardTitle).foregroundStyle(Palette.ink).padding(.top, 8)
                ForEach(refs) { ref in
                    CheatRow(ref: ref, expanded: open.contains(ref.key)) {
                        if open.contains(ref.key) { open.remove(ref.key) } else { open.insert(ref.key) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $session) { SessionView(session: $0) }
    }
}

struct CheatRow: View {
    @Environment(AppStore.self) private var store
    let ref: CardRef
    let expanded: Bool
    let toggle: () -> Void
    var body: some View {
        let level = store.state(ref).level
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(color(level)).frame(width: 8, height: 8).padding(.top, 7)
                    Text(ref.card.q).font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.ink2)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .padding(.top, 4)
                }
                if expanded {
                    Text(ref.card.correctText).font(.body.weight(.semibold)).foregroundStyle(Palette.good)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 18)
                    if let e = ref.card.explain, !e.isEmpty {
                        Text(e).font(.callout).foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 18)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .soft(radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: expanded)
    }
    private func color(_ l: CardState.Level) -> Color {
        switch l {
        case .new: Palette.surface2
        case .learning: Palette.flame
        case .known: Palette.accent
        case .mastered: Palette.good
        }
    }
}

struct SearchResults: View {
    @Environment(AppStore.self) private var store
    let query: String
    @State private var open: Set<String> = []
    var body: some View {
        let q = query.lowercased()
        let hits = store.packs.flatMap { store.refs($0) }.filter {
            $0.card.q.lowercased().contains(q) || $0.card.correctText.lowercased().contains(q)
                || ($0.card.explain ?? "").lowercased().contains(q)
        }
        LazyVStack(alignment: .leading, spacing: 10) {
            Text("\(hits.count) \(plural(hits.count, "карточка", "карточки", "карточек"))")
                .font(.caption).foregroundStyle(Palette.ink2)
            ForEach(hits.prefix(100)) { ref in
                CheatRow(ref: ref, expanded: open.contains(ref.key)) {
                    if open.contains(ref.key) { open.remove(ref.key) } else { open.insert(ref.key) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
