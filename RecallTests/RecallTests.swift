import XCTest
@testable import Recall

final class SchedulerTests: XCTestCase {
    func testGoodGrowsInterval() {
        var s = CardState()
        s = Scheduler.apply(.good, to: s)
        XCTAssertEqual(s.interval, 1)
        s = Scheduler.apply(.good, to: s)
        XCTAssertEqual(s.interval, 3)
        s = Scheduler.apply(.good, to: s)
        XCTAssertEqual(s.interval, 8)   // 3 * 2.5 rounded
        XCTAssertEqual(s.level, .known)
    }

    func testAgainResets() {
        var s = CardState()
        s = Scheduler.apply(.good, to: s)
        s = Scheduler.apply(.good, to: s)
        s = Scheduler.apply(.again, to: s)
        XCTAssertEqual(s.reps, 0)
        XCTAssertEqual(s.interval, 0)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertLessThan(s.ease, 2.5)
        XCTAssertTrue(s.isDue(.now.addingTimeInterval(11 * 60)))
    }

    func testEaseFloor() {
        var s = CardState()
        for _ in 0..<20 { s = Scheduler.apply(.again, to: s) }
        XCTAssertEqual(s.ease, 1.3, accuracy: 0.001)
    }
}

final class SessionTests: XCTestCase {
    private func ref(_ id: String, choice: Bool = true) -> CardRef {
        let card = choice
            ? Card(id: id, topic: "t", type: .choice, q: "Q\(id)", options: ["a", "b", "c"], answer: 1)
            : Card(id: id, topic: "t", type: .flash, q: "Q\(id)", back: "B")
        return CardRef(packID: "p", packTitle: "P", topicTitle: "T", card: card)
    }

    func testWrongAnswerIsRetriedOnceAndCountedOnce() {
        let s = Session(title: "x", cards: [ref("1"), ref("2")])
        let wrong = s.options.firstIndex { !$0.correct }!
        XCTAssertFalse(s.pick(wrong))
        XCTAssertNotNil(s.advance(grade: .again))
        XCTAssertEqual(s.total, 3)
        let right = s.options.firstIndex { $0.correct }!
        XCTAssertTrue(s.pick(right))
        XCTAssertNotNil(s.advance(grade: .good))
        XCTAssertTrue(s.isRetry)
        s.pick(s.options.firstIndex { $0.correct }!)
        XCTAssertNil(s.advance(grade: .good), "retry must not be recorded twice")
        XCTAssertTrue(s.isDone)
        XCTAssertEqual(s.outcomes.count, 2)
        XCTAssertEqual(s.correctCount, 1)
    }

    func testOptionsKeepCorrectAnswer() {
        let s = Session(title: "x", cards: [ref("1")])
        XCTAssertEqual(s.options.filter(\.correct).map(\.text), ["b"])
    }
}

final class PackTests: XCTestCase {
    func testBundledPacksDecodeAndAreValid() throws {
        let store = AppStore(preview: true)
        XCTAssertTrue(store.loadErrors.isEmpty, store.loadErrors.joined(separator: "\n"))
        XCTAssertFalse(store.packs.isEmpty)
        for pack in store.packs {
            let topicIDs = Set(pack.topics.map(\.id))
            for card in pack.cards {
                XCTAssertTrue(topicIDs.contains(card.topic), "\(pack.id)/\(card.id) has unknown topic")
            }
            XCTAssertEqual(Set(pack.cards.map(\.id)).count, pack.cards.count, "\(pack.id) has duplicate ids")
        }
    }

    func testInterleaveMixesPacks() {
        let a = (0..<3).map { CardRef(packID: "a", packTitle: "", topicTitle: "", card: Card(id: "\($0)", topic: "t", type: .flash, q: "", back: "b")) }
        let b = (0..<3).map { CardRef(packID: "b", packTitle: "", topicTitle: "", card: Card(id: "\($0)", topic: "t", type: .flash, q: "", back: "b")) }
        let mixed = AppStore.interleave(a + b)
        XCTAssertEqual(mixed.count, 6)
        XCTAssertNotEqual(mixed[0].packID, mixed[1].packID)
    }
}
