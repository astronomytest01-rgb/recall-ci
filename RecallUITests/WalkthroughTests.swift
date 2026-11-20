import XCTest

/// Walks every screen in light and dark and attaches screenshots (exported by CI).
final class WalkthroughTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testWalkthroughLight() { walk(theme: 1, name: "light") }
    func testWalkthroughDark() { walk(theme: 2, name: "dark") }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func walk(theme: Int, name: String) {
        let app = XCUIApplication()
        let ru = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launchArguments = ["-demo", "-theme", "\(theme)", "-reminderOn", "NO"] + ru
        app.launch()

        // Today
        XCTAssertTrue(app.staticTexts["Сегодня"].waitForExistence(timeout: 10))
        shot(app, "\(name)-01-today")

        // Daily session: answer up to 6 cards, both kinds
        let start = app.buttons["Начать"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "daily session should have cards")
        start.tap()
        var sawChoice = false, sawFlash = false
        for step in 0..<6 {
            let option = app.buttons["option-0"]
            let reveal = app.buttons["Показать ответ"]
            if option.waitForExistence(timeout: 3) {
                if !sawChoice { shot(app, "\(name)-02-question") }
                option.tap()
                if !sawChoice { shot(app, "\(name)-03-answered") }
                sawChoice = true
                let next = app.buttons["Дальше"].exists ? app.buttons["Дальше"] : app.buttons["Понятно, дальше"]
                XCTAssertTrue(next.waitForExistence(timeout: 3), "no next button at step \(step)")
                next.tap()
            } else if reveal.exists {
                if !sawFlash { shot(app, "\(name)-04-flash") }
                reveal.tap()
                XCTAssertTrue(app.buttons["grade-2"].waitForExistence(timeout: 3))
                if !sawFlash { shot(app, "\(name)-05-flash-revealed") }
                sawFlash = true
                app.buttons["grade-2"].tap()
            } else {
                break
            }
        }
        XCTAssertTrue(sawChoice, "no choice card shown")
        app.buttons["close"].tap()
        let showResult = app.buttons["Показать итог"]
        if showResult.waitForExistence(timeout: 3) {
            showResult.tap()
            XCTAssertTrue(app.buttons["Готово"].waitForExistence(timeout: 5))
            shot(app, "\(name)-06-result")
            app.buttons["Готово"].tap()
        }

        // Library → pack → topic
        app.tabBars.buttons["Темы"].tap()
        XCTAssertTrue(app.navigationBars["Темы"].waitForExistence(timeout: 5))
        shot(app, "\(name)-07-library")
        let firstPack = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pack-'")).firstMatch
        XCTAssertTrue(firstPack.waitForExistence(timeout: 5))
        firstPack.tap()
        shot(app, "\(name)-08-pack")
        let topic = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'topic-'")).firstMatch
        if topic.waitForExistence(timeout: 3) {
            topic.tap()
            shot(app, "\(name)-09-topic")
        }

        // Search
        app.tabBars.buttons["Темы"].tap()
        app.tabBars.buttons["Темы"].tap()
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            search.tap()
            search.typeText("интервал")
            shot(app, "\(name)-10-search")
        }

        // Blitz (relaunch: the search keyboard covers the tab bar)
        app.terminate()
        app.launchArguments = ["-theme", "\(theme)", "-tab", "2"] + ru
        app.launch()
        let go = app.buttons["Поехали"]
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        shot(app, "\(name)-11-blitz")
        go.tap()
        XCTAssertTrue(app.buttons["Верно"].waitForExistence(timeout: 5))
        shot(app, "\(name)-12-blitz-play")
        app.buttons["Верно"].tap()
        app.buttons["Нет"].tap()
        shot(app, "\(name)-13-blitz-answered")
        app.buttons["close"].tap()
        XCTAssertTrue(app.buttons["Ещё раз"].waitForExistence(timeout: 5))
        shot(app, "\(name)-14-blitz-result")

        // Settings
        app.terminate()
        app.launchArguments = ["-theme", "\(theme)", "-tab", "3"] + ru
        app.launch()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 10))
        shot(app, "\(name)-15-settings")
    }
}
