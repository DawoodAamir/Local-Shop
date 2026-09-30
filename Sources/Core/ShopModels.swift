import Foundation

struct Product: Codable, Identifiable, Equatable {
  let id, name, category: String
  let price: Int
  let tagline, description, details, art, tone: String
}

struct BagItem: Codable, Equatable {
  let productID: String
  var quantity: Int
}

struct Bag: Codable, Equatable {
  private(set) var items: [BagItem] = []
  var count: Int { items.reduce(0) { $0 + $1.quantity } }
  mutating func set(_ id: String, quantity: Int) {
    items.removeAll { $0.productID == id }
    if quantity > 0 { items.append(BagItem(productID: id, quantity: min(quantity, 20))) }
    items.sort { $0.productID < $1.productID }
  }
  func quantity(_ id: String) -> Int { items.first { $0.productID == id }?.quantity ?? 0 }
  func quote(catalog: [Product]) throws -> Quote {
    guard !items.isEmpty else { throw ShopError.message("Your bag is empty.") }
    let lines = try items.map { item -> OrderLine in
      guard let product = catalog.first(where: { $0.id == item.productID }),
        (1...20).contains(item.quantity)
      else {
        throw ShopError.message("An item is no longer available. Remove it from your bag.")
      }
      return OrderLine(
        productID: product.id, name: product.name, quantity: item.quantity, unitPrice: product.price
      )
    }
    let subtotal = lines.reduce(0) { $0 + $1.quantity * $1.unitPrice }
    let shipping = subtotal >= 7500 ? 0 : 495
    return Quote(
      lines: lines, subtotal: subtotal, shipping: shipping, total: subtotal + shipping,
      currency: "usd")
  }
}

struct OrderLine: Codable, Equatable {
  let productID, name: String
  let quantity, unitPrice: Int
}

struct Quote: Codable, Equatable {
  let lines: [OrderLine]
  let subtotal, shipping, total: Int
  let currency: String
}

struct DeliveryAddress: Codable, Equatable {
  var name = ""
  var email = ""
  var street = ""
  var city = ""
  var region = ""
  var postalCode = ""
  var validationMessage: String? {
    let values = [name, email, street, city, region, postalCode]
    guard
      values.allSatisfy({
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 160
          && $0.rangeOfCharacter(from: .controlCharacters) == nil
      })
    else { return "Complete all delivery fields." }
    guard email.contains("@"), email.split(separator: "@").last?.contains(".") == true else {
      return "Enter a valid email address."
    }
    guard region.count == 2,
      region.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) && $0.isASCII })
    else { return "Use a two-letter US state code." }
    guard postalCode.count == 5, postalCode.allSatisfy({ $0.isASCII && $0.isNumber }) else {
      return "Use a five-digit US ZIP code."
    }
    return nil
  }
  static let sample = DeliveryAddress(
    name: "Alex Sample", email: "alex@example.com", street: "123 Example Street", city: "Portland",
    region: "OR", postalCode: "97201")
}

struct ShopOrder: Codable, Identifiable, Equatable {
  let id: String
  let createdAt: Double
  var status: String
  let paymentMode: String
  let quote: Quote
  let address: DeliveryAddress
  var checkoutURL: String?
  var date: Date { Date(timeIntervalSince1970: createdAt) }
  var statusTitle: String {
    switch status {
    case "demo_confirmed": return "Demo order confirmed"
    case "test_paid": return "Test payment confirmed"
    case "expired": return "Checkout expired"
    default: return "Awaiting test payment"
    }
  }
}

struct CheckoutRequest: Codable, Equatable {
  let items: [BagItem]
  let address: DeliveryAddress
  let expectedTotal: Int
}

struct PendingCheckout: Codable, Equatable {
  let id: String
  let request: CheckoutRequest
}

struct ShopState: Codable {
  var bag = Bag()
  var orders: [ShopOrder] = []
  var pending: PendingCheckout?
}

enum ShopError: LocalizedError {
  case message(String)
  case rejected(String)
  var errorDescription: String? {
    switch self {
    case .message(let text), .rejected(let text): return text
    }
  }
}

func money(_ cents: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .currency
  formatter.currencyCode = "USD"
  formatter.locale = Locale(identifier: "en_US")
  return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "$0.00"
}
