import Foundation
import Observation
import UserNotifications

struct Progress: Codable {
    var cards: [String: CardState] = [:]
    var days: [String: Int] = [:]          // "2026-11-20": answers that day
    var correctDays: [String: Int] = [:]   // correct answers that day
    var disabledPacks: Set<String> = []
    var blitzBest: Int = 0
}

@Observable
final class AppStore {
    private(set) var packs: [Pack] = []
    private(set) var progress = Progress()
    var loadErrors: [String] = []

    private let fm = FileManager.default
    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var progressURL: URL { docs.appendingPathComponent("progress.json") }
    var importedDir: URL { docs.appendingPathComponent("Packs", isDirectory: true) }

    init(preview: Bool = false) {
        loadPacks()
        if !preview { loadProgress() }
    }

    // MARK: Packs

    func loadPacks() {
        var found: [String: Pack] = [:]
        loadErrors = []
        var urls: [URL] = []
        if let dir = Bundle.main.url(forResource: "Packs", withExtension: nil) {
            urls += (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        }
        urls += Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        try? fm.createDirectory(at: importedDir, withIntermediateDirectories: true)
        urls += (try? fm.contentsOfDirectory(at: importedDir, includingPropertiesForKeys: nil)) ?? []

        for url in urls where url.pathExtension == "json" {
            do {
                var pack = try JSONDecoder().decode(Pack.self, from: Data(contentsOf: url))
                pack.cards = pack.cards.filter(\.isValid)
                // An imported pack with the same id replaces the bundled one.
                found[pack.id] = pack
            } catch {
                loadErrors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        packs = found.values.sorted { ($0.sourceName, $0.title) < ($1.sourceName, $1.title) }
    }

    /// Copies a pack JSON into the app. Returns the pack title.
    func importPack(from url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let pack = try JSONDecoder().decode(Pack.self, from: data)
        try fm.createDirectory(at: importedDir, withIntermediateDirectories: true)
        try data.write(to: importedDir.appendingPathComponent("\(pack.id).json"), options: .atomic)
        loadPacks()
        return pack.title
    }

    var sources: [String] { Array(Set(packs.map(\.sourceName))).sorted() }
    var activePacks: [Pack] { packs.filter { !progress.disabledPacks.contains($0.id) } }

    func refs(_ pack: Pack, topic: String? = nil) -> [CardRef] {
        pack.cards
            .filter { topic == nil || $0.topic == topic }
            .map { CardRef(packID: pack.id, packTitle: pack.title, topicTitle: pack.topic($0.topic)?.title ?? "", card: $0) }
    }

    var allRefs: [CardRef] { activePacks.flatMap { refs($0) } }

    func isEnabled(_ pack: Pack) -> Bool { !progress.disabledPacks.contains(pack.id) }
    func setEnabled(_ pack: Pack, _ on: Bool) {
        if on { progress.disabledPacks.remove(pack.id) } else { progress.disabledPacks.insert(pack.id) }
        save()
    }

    // MARK: Progress

    func state(_ ref: CardRef) -> CardState { progress.cards[ref.key] ?? CardState() }

    func record(_ ref: CardRef, grade: Grade, now: Date = .now) {
        progress.cards[ref.key] = Scheduler.apply(grade, to: state(ref), now: now)
        let day = Self.dayKey(now)
        progress.days[day, default: 0] += 1
        if grade != .again { progress.correctDays[day, default: 0] += 1 }
        save()
    }

    func recordBlitz(score: Int, answered: Int) {
        progress.blitzBest = max(progress.blitzBest, score)
        let day = Self.dayKey(.now)
        progress.days[day, default: 0] += answered
        progress.correctDays[day, default: 0] += score
        save()
    }

    func resetProgress() {
        let disabled = progress.disabledPacks
        progress = Progress()
        progress.disabledPacks = disabled
        save()
    }

    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressURL),
              let p = try? JSONDecoder().decode(Progress.self, from: data) else { return }
        progress = p
    }

    func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: progressURL, options: .atomic)
    }

    // MARK: Stats

    static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04ld-%02ld-%02ld", c.year!, c.month!, c.day!)
    }

    var answeredToday: Int { progress.days[Self.dayKey(.now)] ?? 0 }

    func studied(on date: Date) -> Bool { (progress.days[Self.dayKey(date)] ?? 0) > 0 }

    var streak: Int {
        let cal = Calendar.current
        var day = Date.now
        if !studied(on: day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while studied(on: day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    var accuracy7: Double? {
        let cal = Calendar.current
        var all = 0, ok = 0
        for i in 0..<7 {
            let k = Self.dayKey(cal.date(byAdding: .day, value: -i, to: .now)!)
            all += progress.days[k] ?? 0
            ok += progress.correctDays[k] ?? 0
        }
        return all == 0 ? nil : Double(ok) / Double(all)
    }

    func dueRefs(now: Date = .now) -> [CardRef] {
        allRefs.filter { state($0).isDue(now) }.sorted { state($0).due < state($1).due }
    }

    func newRefs() -> [CardRef] { allRefs.filter { state($0).seen == 0 } }

    func count(_ refs: [CardRef], _ level: CardState.Level) -> Int {
        refs.filter { state($0).level == level }.count
    }

    /// Share of cards at least "known" — what the progress bars show.
    func mastery(_ refs: [CardRef]) -> Double {
        guard !refs.isEmpty else { return 0 }
        let score = refs.reduce(0.0) { acc, r in
            switch state(r).level {
            case .new: acc
            case .learning: acc + 0.33
            case .known: acc + 0.75
            case .mastered: acc + 1
            }
        }
        return score / Double(refs.count)
    }

    struct Weak: Identifiable {
        let pack: Pack
        let topic: Topic
        let accuracy: Double
        var id: String { pack.id + "/" + topic.id }
    }

    /// Topics with the lowest answer accuracy among those already practised.
    var weakTopics: [Weak] {
        var out: [Weak] = []
        for pack in activePacks {
            for topic in pack.topics {
                let states = refs(pack, topic: topic.id).map(state).filter { $0.seen > 0 }
                let seen = states.reduce(0) { $0 + $1.seen }
                guard seen >= 3 else { continue }
                let lapses = states.reduce(0) { $0 + $1.lapses }
                out.append(Weak(pack: pack, topic: topic, accuracy: 1 - Double(lapses) / Double(seen)))
            }
        }
        return Array(out.filter { $0.accuracy < 0.85 }.sorted { $0.accuracy < $1.accuracy }.prefix(3))
    }

    // MARK: Sessions

    func dailyQueue(limit: Int, newPerDay: Int) -> [CardRef] {
        let due = dueRefs()
        let newToday = progress.cards.values.filter {
            $0.seen > 0 && $0.last.map(Self.dayKey) == Self.dayKey(.now) && $0.reps <= 1 && $0.lapses == 0
        }.count
        let fresh = Self.interleave(newRefs()).prefix(max(0, newPerDay - newToday))
        return Array((due + fresh).prefix(limit))
    }

    /// Round-robin across packs so a session does not start with 15 cards of one file.
    static func interleave(_ refs: [CardRef]) -> [CardRef] {
        var buckets = Dictionary(grouping: refs, by: \.packID).values.map { Array($0) }
        var out: [CardRef] = []
        while !buckets.isEmpty {
            for i in buckets.indices.reversed() {
                out.append(buckets[i].removeFirst())
                if buckets[i].isEmpty { buckets.remove(at: i) }
            }
        }
        return out
    }

    func quizQueue(_ refs: [CardRef], count: Int) -> [CardRef] {
        // Prefer cards that are weak or unseen, then shuffle.
        let ranked = refs.shuffled().sorted { state($0).level < state($1).level }
        return Array(ranked.prefix(count)).shuffled()
    }

    // MARK: Reminders

    static func scheduleReminder(enabled: Bool, hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily"])
        guard enabled else { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Пора повторить"
        content.body = "Пять минут, и стрик не сгорит."
        content.sound = .default
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let req = UNNotificationRequest(identifier: "daily", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        try? await center.add(req)
        return true
    }
}
