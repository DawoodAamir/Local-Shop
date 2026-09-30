import XCTest

final class ShoppingFlowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch(server: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LOCAL_SHOP_UI_TEST"] = UUID().uuidString
    if server { app.launchEnvironment["LOCAL_SHOP_TEST_ENDPOINT"] = "http://localhost:8080" }
    app.launch()
    XCTAssertTrue(app.staticTexts["Everyday mug"].waitForExistence(timeout: 15))
    return app
  }

  private func screenshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func purchase(_ app: XCUIApplication) {
    app.staticTexts["Everyday mug"].firstMatch.tap()
    app.swipeUp()
    XCTAssertTrue(app.buttons["Add to bag"].waitForExistence(timeout: 5))
    app.buttons["Add to bag"].tap()
    app.buttons["View bag"].tap()
    XCTAssertTrue(app.buttons["Continue to checkout"].waitForExistence(timeout: 5))
    screenshot(app, "02-bag")
    app.buttons["Continue to checkout"].tap()
    app.buttons["Use sample address"].tap()
    app.swipeUp()
    screenshot(app, "03-checkout")
    app.buttons["Place test order"].tap()
    XCTAssertTrue(app.buttons["View orders"].waitForExistence(timeout: 15))
    screenshot(app, "04-confirmation")
    app.buttons["View orders"].tap()
    XCTAssertTrue(app.staticTexts["Demo order confirmed"].waitForExistence(timeout: 10))
  }

  func testStandaloneShoppingFlow() {
    let app = launch()
    screenshot(app, "01-storefront")
    purchase(app)
  }

  func testServerBackedCheckout() {
    let app = launch(server: true)
    purchase(app)
  }

  func testSearchAndEmptyState() {
    let app = launch()
    app.swipeDown()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("no-such-product")
    XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))
  }
}
