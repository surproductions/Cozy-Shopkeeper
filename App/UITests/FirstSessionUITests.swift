import XCTest

/// Simulator smoke test of the first session: open the shop, make the first sale,
/// restock, and finish the short tutorial.
final class FirstSessionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFirstSessionFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let open = app.buttons["openShopButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Welcome screen should appear on first launch")
        open.tap()

        let serve = app.buttons["serveButton"]
        XCTAssertTrue(serve.waitForExistence(timeout: 10), "First customer should arrive")
        let coins = app.descendants(matching: .any)["coinsLabel"]
        XCTAssertTrue(coins.waitForExistence(timeout: 5))
        let before = coins.label
        serve.tap()

        let changed = NSPredicate(format: "label != %@", before)
        expectation(for: changed, evaluatedWith: coins)
        waitForExpectations(timeout: 5)

        let stock = app.buttons["stockButton"]
        XCTAssertTrue(stock.waitForExistence(timeout: 5))
        stock.tap()
        let restockOne = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Restock 1 for'")).firstMatch
        XCTAssertTrue(restockOne.waitForExistence(timeout: 5), "Stockroom should list restock buttons")
        restockOne.tap()

        let next = app.buttons["tutorialContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Housewarming gift should appear")
        next.tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Goals intro should appear")
        next.tap()

        XCTAssertTrue(app.buttons["goalsButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["openShopButton"].exists)
    }
}
