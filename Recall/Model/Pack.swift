import Foundation

struct Pack: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String?
    var source: String?
    var icon: String?
    var version: Int?
    var topics: [Topic]
    var cards: [Card]

    var sourceName: String { source ?? "Без источника" }
    var symbol: String { icon ?? "book.closed" }

    func topic(_ id: String) -> Topic? { topics.first { $0.id == id } }
    func cards(in topicID: String) -> [Card] { cards.filter { $0.topic == topicID } }
}

struct Topic: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var icon: String?
    var symbol: String { icon ?? "circle.grid.2x2" }
}

struct Card: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case choice, flash }

    var id: String
    var topic: String
    var type: Kind
    var q: String
    var options: [String]?
    var answer: Int?
    var back: String?
    var explain: String?
    var source: String?

    var correctText: String {
        switch type {
        case .flash: return back ?? ""
        case .choice:
            guard let options, let answer, options.indices.contains(answer) else { return "" }
            return options[answer]
        }
    }

    var isValid: Bool {
        switch type {
        case .flash: return !(back ?? "").isEmpty
        case .choice:
            guard let options, let answer else { return false }
            return options.count >= 2 && options.indices.contains(answer)
        }
    }
}

/// A card with the pack it belongs to. Progress is keyed by `key`.
struct CardRef: Identifiable, Hashable {
    let packID: String
    let packTitle: String
    let topicTitle: String
    let card: Card
    var id: String { key }
    var key: String { "\(packID)/\(card.id)" }
}
