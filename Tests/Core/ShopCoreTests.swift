import XCTest
@testable import ShopCore

final class ShopCoreTests: XCTestCase {
    private var mug: Product { Product(id: "mug", name: "Mug", category: "Kitchen", price: 2400, tagline: "", description: "", details: "", art: "mug", tone: "clay") }
    func testBagQuantityLimitsAndRemoval() throws {
        var bag = Bag()
        bag.set("mug", quantity: 99)
        XCTAssertEqual(bag.quantity("mug"), 20)
        bag.set("mug", quantity: 2)
        XCTAssertEqual(bag.count, 2)
        bag.set("mug", quantity: 0)
        XCTAssertTrue(bag.items.isEmpty)
    }
    func testShippingThresholdUsesIntegerCents() throws {
        var bag = Bag(); bag.set("mug", quantity: 3)
        XCTAssertEqual(try bag.quote(catalog: [mug]).total, 7695)
        bag.set("mug", quantity: 4)
        XCTAssertEqual(try bag.quote(catalog: [mug]).shipping, 0)
        let product = Product(id: "threshold", name: "Threshold", category: "", price: 7500, tagline: "", description: "", details: "", art: "", tone: "")
        var exact = Bag(); exact.set("threshold", quantity: 1)
        XCTAssertEqual(try exact.quote(catalog: [product]).shipping, 0)
    }
    func testMissingProductCannotSilentlyDisappearFromTotal() {
        var bag = Bag(); bag.set("missing", quantity: 1)
        XCTAssertThrowsError(try bag.quote(catalog: [mug]))
        XCTAssertThrowsError(try Bag().quote(catalog: [mug]))
    }
    func testDeliveryValidation() {
        var address = DeliveryAddress.sample
        XCTAssertNil(address.validationMessage)
        address.postalCode = "１２３４５"
        XCTAssertNotNil(address.validationMessage)
        address = .sample; address.email = "invalid"
        XCTAssertNotNil(address.validationMessage)
        address = .sample; address.region = "Oregon"
        XCTAssertNotNil(address.validationMessage)
        address = .sample; address.name = "\n"
        XCTAssertNotNil(address.validationMessage)
    }
    func testPendingCheckoutSurvivesRelaunchUnchanged() throws {
        var state = ShopState(); state.bag.set("mug", quantity: 2)
        let request = CheckoutRequest(items: state.bag.items, address: .sample, expectedTotal: 5295)
        state.pending = PendingCheckout(id: UUID().uuidString, request: request)
        let restored = try JSONDecoder().decode(ShopState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.pending, state.pending)
        XCTAssertEqual(restored.bag, state.bag)
    }
    func testMoneyAndPaymentLabels() {
        XCTAssertEqual(money(2495), "$24.95")
        XCTAssertEqual(money(0), "$0.00")
    }
}
