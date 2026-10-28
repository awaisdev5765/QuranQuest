import XCTest

final class QuranQuestUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ appearance: String = "light", largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-appearance", appearance, "-offlineAudioOnly", "YES"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testReaderBookmarksAndOfflineError() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Quran"].waitForExistence(timeout: 10))
        capture("home-light")
        app.tabBars.buttons["Quran"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Al-Faatiha")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Al-Faatiha"].waitForExistence(timeout: 5))
        capture("reader-light")
        app.swipeUp()
        let bookmark = app.buttons["Bookmark ayah 1"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5)); bookmark.tap()
        XCTAssertEqual(bookmark.value as? String, "Saved")
        app.buttons["Listen to ayah 1"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open player.")).firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open player.")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Retry playback"].waitForExistence(timeout: 5))
        capture("offline-playback-error")
    }
    func testHifzPlanCreationAndRecall() {
        let app = launch()
        app.tabBars.buttons["Hifz"].tap()
        app.buttons["New memorization plan"].tap()
        app.buttons["Save plan"].tap()
        let plan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Al-Faatiha · 1–3")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5)); plan.tap()
        XCTAssertTrue(app.navigationBars["Memorize"].waitForExistence(timeout: 5))
        capture("hifz-session")
        app.swipeUp()
        let hide = app.switches["Hide verses for recall"]
        if !hide.isHittable { app.swipeUp() }
        hide.tap()
        XCTAssertTrue(app.buttons["Reveal ayah"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Reveal ayah"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Hide ayah"].firstMatch.exists)
        capture("hifz-recall")
    }
    func testDarkAndLargeTextLayouts() {
        let app = launch("dark", largeText: true)
        capture("home-dark-large-text")
        app.tabBars.buttons["Settings"].tap()
        capture("settings-dark-large-text")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("settings-landscape-large-text")
        XCUIDevice.shared.orientation = .portrait
    }
}
