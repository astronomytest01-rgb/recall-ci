import Foundation
import Observation

@Observable
final class Session: Identifiable {
    struct Option: Hashable { let text: String; let correct: Bool }
    struct Outcome: Identifiable { let ref: CardRef; let correct: Bool; var id: String { ref.key } }

    enum Phase { case asking, revealed }

    let id = UUID()
    let title: String
    private(set) var queue: [CardRef]
    private(set) var index = 0
    private(set) var phase: Phase = .asking
    private(set) var options: [Option] = []
    private(set) var picked: Int?
    private(set) var outcomes: [Outcome] = []
    private var retried: Set<String> = []
    private var firstTry: Set<String> = []
    let started = Date()
    private(set) var finished: Date?

    init(title: String, cards: [CardRef]) {
        self.title = title
        self.queue = cards
        prepare()
    }

    var current: CardRef? { queue.indices.contains(index) ? queue[index] : nil }
    var isDone: Bool { current == nil }
    var total: Int { queue.count }
    var progress: Double { total == 0 ? 1 : Double(index) / Double(total) }
    var correctCount: Int { outcomes.filter(\.correct).count }
    var mistakes: [CardRef] { outcomes.filter { !$0.correct }.map(\.ref) }
    var isRetry: Bool { current.map { retried.contains($0.key) && firstTry.contains($0.key) } ?? false }

    var pickedCorrect: Bool {
        guard let picked, options.indices.contains(picked) else { return false }
        return options[picked].correct
    }

    private func prepare() {
        phase = .asking
        picked = nil
        guard let card = current?.card, card.type == .choice, let opts = card.options, let a = card.answer else {
            options = []
            return
        }
        let mapped = opts.enumerated().map { Option(text: $1, correct: $0 == a) }
        // Keep true/false in a fixed order; shuffle the rest.
        let isTF = Set(opts.map { $0.lowercased() }) == ["верно", "неверно"]
        options = isTF ? mapped : mapped.shuffled()
    }

    /// Choice answer. Returns whether it was right.
    @discardableResult
    func pick(_ i: Int) -> Bool {
        guard phase == .asking else { return pickedCorrect }
        picked = i
        phase = .revealed
        return pickedCorrect
    }

    func reveal() { phase = .revealed }

    /// Moves on, returning the grade to record for the card just answered (nil for in-session retries).
    func advance(grade: Grade) -> (CardRef, Grade)? {
        guard let ref = current else { return nil }
        let wasRetry = retried.contains(ref.key) && firstTry.contains(ref.key)
        var record: (CardRef, Grade)? = (ref, grade)
        if wasRetry {
            record = nil   // already graded on first attempt
        } else {
            firstTry.insert(ref.key)
            outcomes.append(Outcome(ref: ref, correct: grade != .again))
            if grade == .again && !retried.contains(ref.key) {
                retried.insert(ref.key)
                queue.append(ref)   // see it once more before the session ends
            }
        }
        index += 1
        if isDone { finished = .now }
        prepare()
        return record
    }

    var duration: TimeInterval { (finished ?? .now).timeIntervalSince(started) }
}
