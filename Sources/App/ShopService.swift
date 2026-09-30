import Foundation
import Security

protocol ShopService {
  func catalog() async throws -> [Product]
  func checkout(_ request: CheckoutRequest, key: String) async throws -> ShopOrder
  func orders() async throws -> [ShopOrder]
  func refresh(_ order: ShopOrder) async throws -> ShopOrder
}

struct DemoService: ShopService {
  func catalog() async throws -> [Product] {
    guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
      throw ShopError.message("The sample catalog is missing.")
    }
    return try JSONDecoder().decode([Product].self, from: Data(contentsOf: url))
  }
  func checkout(_ request: CheckoutRequest, key: String) async throws -> ShopOrder {
    if let error = request.address.validationMessage { throw ShopError.message(error) }
    var bag = Bag()
    for item in request.items { bag.set(item.productID, quantity: item.quantity) }
    let quote = try bag.quote(catalog: await catalog())
    guard request.expectedTotal == quote.total else {
      throw ShopError.message("Prices changed. Review your bag.")
    }
    return ShopOrder(
      id: key, createdAt: Date().timeIntervalSince1970, status: "demo_confirmed",
      paymentMode: "demo", quote: quote, address: request.address)
  }
  func orders() async throws -> [ShopOrder] { [] }
  func refresh(_ order: ShopOrder) async throws -> ShopOrder { order }
}

actor APIService: ShopService {
  private struct Failure: Decodable { let error: String }
  let base: URL
  private var token: String?
  private var credentialAccount: String {
    base.absoluteString
      + (ProcessInfo.processInfo.environment["LOCAL_SHOP_UI_TEST"].map { "|test:" + $0 } ?? "")
  }
  init(base: URL) { self.base = base }

  private func call<T: Decodable>(
    _ path: String, method: String = "GET", body: Data? = nil, key: String? = nil,
    authorized: Bool = true
  ) async throws -> T {
    var request = URLRequest(url: base.appendingPathComponent(path))
    request.httpMethod = method
    request.timeoutInterval = 25
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let key { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
    if authorized {
      request.setValue("Bearer \(try await session())", forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw ShopError.message("No response from the store.")
    }
    guard (200..<300).contains(response.statusCode) else {
      let message =
        (try? JSONDecoder().decode(Failure.self, from: data).error)
        ?? "The store could not complete this request."
      if [400, 401, 409].contains(response.statusCode) { throw ShopError.rejected(message) }
      throw ShopError.message(message)
    }
    return try JSONDecoder().decode(T.self, from: data)
  }
  private func session() async throws -> String {
    if let token { return token }
    if let saved = try Credentials.read(account: credentialAccount) {
      token = saved
      return saved
    }
    struct Session: Decodable { let token: String }
    let response: Session = try await call(
      "v1/sessions", method: "POST", body: Data("{}".utf8), authorized: false)
    try Credentials.save(response.token, account: credentialAccount)
    token = response.token
    return response.token
  }
  func catalog() async throws -> [Product] { try await call("v1/catalog", authorized: false) }
  func checkout(_ request: CheckoutRequest, key: String) async throws -> ShopOrder {
    try await call("v1/checkout", method: "POST", body: JSONEncoder().encode(request), key: key)
  }
  func orders() async throws -> [ShopOrder] { try await call("v1/orders") }
  func refresh(_ order: ShopOrder) async throws -> ShopOrder {
    try await call("v1/orders/\(order.id)/refresh", method: "POST", body: Data("{}".utf8))
  }
}

enum Credentials {
  private static func query(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.dd.localshop.guest", kSecAttrAccount as String: account,
    ]
  }
  static func read(account: String) throws -> String? {
    var q = query(account)
    q[kSecReturnData as String] = true
    var result: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data,
      let text = String(data: data, encoding: .utf8)
    else { throw ShopError.message("Could not read your guest session from Keychain.") }
    return text
  }
  static func save(_ token: String, account: String) throws {
    var q = query(account)
    q[kSecValueData as String] = Data(token.utf8)
    q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status = SecItemAdd(q as CFDictionary, nil)
    if status == errSecDuplicateItem { return }
    guard status == errSecSuccess else {
      throw ShopError.message("Could not save your guest session securely.")
    }
  }
  static func delete(account: String) throws {
    let status = SecItemDelete(query(account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw ShopError.message("Could not remove the guest session.")
    }
  }
}
