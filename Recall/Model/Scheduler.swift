import Foundation

enum Grade: Int, Codable, CaseIterable {
    case again, hard, good, easy

    var title: String {
        switch self {
        case .again: "Не помню"
        case .hard: "Трудно"
        case .good: "Помню"
        case .easy: "Легко"
        }
    }
}

/// Spaced-repetition state of one card (SM-2 with small tweaks).
struct CardState: Codable, Hashable {
    var ease: Double = 2.5
    var interval: Double = 0      // days
    var reps: Int = 0             // successful reviews in a row
    var lapses: Int = 0
    var due: Date = .distantPast
    var seen: Int = 0
    var correct: Int = 0
    var last: Date?

    enum Level: Int, Comparable {
        case new, learning, known, mastered
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    var level: Level {
        if seen == 0 { return .new }
        if interval >= 21 { return .mastered }
        if interval >= 4 { return .known }
        return .learning
    }

    func isDue(_ now: Date = .now) -> Bool { seen > 0 && due <= now }
}

enum Scheduler {
    static func apply(_ grade: Grade, to s: CardState, now: Date = .now) -> CardState {
        var s = s
        s.seen += 1
        s.last = now
        switch grade {
        case .again:
            s.lapses += 1
            s.reps = 0
            s.ease = max(1.3, s.ease - 0.2)
            s.interval = 0
            s.due = now.addingTimeInterval(10 * 60)
        case .hard, .good, .easy:
            s.correct += grade == .hard ? 0 : 1
            s.interval = nextInterval(grade, s)
            if grade == .hard { s.ease = max(1.3, s.ease - 0.15) }
            if grade == .easy { s.ease += 0.15 }
            s.reps += 1
            s.due = now.addingTimeInterval(s.interval * 86_400)
        }
        return s
    }

    static let maxInterval: Double = 3650   // 10 years; keeps date math finite

    static func nextInterval(_ grade: Grade, _ s: CardState) -> Double {
        min(maxInterval, rawInterval(grade, s))
    }

    private static func rawInterval(_ grade: Grade, _ s: CardState) -> Double {
        let base: Double
        switch s.reps {
        case 0: base = grade == .easy ? 3 : 1
        case 1: base = grade == .easy ? 6 : 3
        default: base = max(1, s.interval) * s.ease
        }
        switch grade {
        case .again: return 0
        case .hard: return max(1, (s.reps == 0 ? 1 : s.interval * 1.2).rounded())
        case .good: return base.rounded()
        case .easy: return (base * 1.3).rounded()
        }
    }

    /// Human hint like "10 мин", "3 дн", "2 мес".
    static func hint(_ grade: Grade, _ s: CardState) -> String {
        if grade == .again { return "10 мин" }
        let d = Int(nextInterval(grade, s))
        if d < 30 { return "\(d) дн" }
        if d < 365 { return "\(d / 30) мес" }
        return "\(d / 365) г"
    }
}
