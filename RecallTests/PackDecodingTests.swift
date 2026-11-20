import XCTest
@testable import Recall

final class PackDecodingTests: XCTestCase {
    func testEveryBundledPackLoadsWithoutDroppingCards() throws {
        let store = AppStore(preview: true)
        XCTAssertGreaterThanOrEqual(store.packs.count, 1)
        XCTAssertNotNil(store.packs.first { $0.id == "recall-guide" }, "starter pack must be bundled")
        let dir = try XCTUnwrap(Bundle.main.url(forResource: "Packs", withExtension: nil))
        for url in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            let id = raw["id"] as! String
            let rawCount = (raw["cards"] as! [Any]).count
            let pack = try XCTUnwrap(store.packs.first { $0.id == id })
            XCTAssertEqual(pack.cards.count, rawCount, "\(id): some cards failed validation")
        }
    }

    func testDailyQueueHasCardsForFreshInstall() {
        let store = AppStore(preview: true)
        XCTAssertEqual(store.dailyQueue(limit: 20, newPerDay: 15).count, min(15, store.allRefs.count))
    }
}
