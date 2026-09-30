import SwiftUI

@MainActor
final class ShopStore: ObservableObject {
  @Published private(set) var state = ShopState()
  @Published private(set) var products: [Product] = []
  @Published private(set) var busy = false
  @Published private(set) var loading = false
  @Published private(set) var loadError: String?
  @Published var error: String?
  @Published var selectedTab = 0
  @Published private(set) var endpoint: String
  private var storageFailed = false
  private var service: any ShopService
  private let directory: URL
  var isDemo: Bool { endpoint.isEmpty }
  var modeTitle: String { isDemo ? "Demo store" : "Connected store · test payments" }
  private var file: URL { directory.appendingPathComponent(isDemo ? "demo.json" : "server.json") }
  var total: Quote? { try? state.bag.quote(catalog: products) }

  init() {
    let testRun = ProcessInfo.processInfo.environment["LOCAL_SHOP_UI_TEST"]
    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        testRun.map { "LocalShop-Tests/" + $0 } ?? "LocalShop", isDirectory: true)
    let savedEndpoint =
      testRun == nil
      ? (UserDefaults.standard.string(forKey: "storeEndpoint") ?? "")
      : (ProcessInfo.processInfo.environment["LOCAL_SHOP_TEST_ENDPOINT"] ?? "")
    endpoint = savedEndpoint
    if let base = URL(string: savedEndpoint), !savedEndpoint.isEmpty {
      service = APIService(base: base)
    } else {
      service = DemoService()
    }
    load()
  }
  private func load() {
    do {
      state = try JSONDecoder().decode(ShopState.self, from: Data(contentsOf: file))
      storageFailed = false
    } catch let failure as CocoaError where failure.code == .fileReadNoSuchFile {
      state = ShopState()
      storageFailed = false
    } catch {
      storageFailed = true
      self.error =
        "Saved shopping data could not be opened. It has been preserved. Restore a backup or reinstall the app to reset local data."
    }
  }
  private func persist(_ next: ShopState) throws {
    guard !storageFailed else {
      throw ShopError.message("Saved data needs recovery before shopping can continue.")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtection])
    state = next
  }
  func setQuantity(_ id: String, _ quantity: Int) {
    guard !busy, state.pending == nil else { return }
    var next = state
    next.bag.set(id, quantity: quantity)
    // Keep unresolved requests recoverable; edits are blocked by the checkout screen.
    do { try persist(next) } catch { self.error = error.localizedDescription }
  }
  func refreshCatalog() async {
    guard !loading else { return }
    loading = true
    loadError = nil
    defer { loading = false }
    do { products = try await service.catalog() } catch { loadError = error.localizedDescription }
  }
  func refreshOrders() async {
    guard !isDemo, !busy else { return }
    busy = true
    defer { busy = false }
    do {
      var next = state
      next.orders = try await service.orders()
      try persist(next)
    } catch { self.error = error.localizedDescription }
  }
  func placeOrder(address: DeliveryAddress) async -> ShopOrder? {
    guard !busy else { return nil }
    busy = true
    defer { busy = false }
    do {
      let pending: PendingCheckout
      if let saved = state.pending {
        pending = saved
      } else {
        if let message = address.validationMessage { throw ShopError.message(message) }
        let quote = try state.bag.quote(catalog: products)
        pending = PendingCheckout(
          id: UUID().uuidString,
          request: CheckoutRequest(
            items: state.bag.items, address: address, expectedTotal: quote.total))
        var next = state
        next.pending = pending
        try persist(next)
      }
      let order = try await service.checkout(pending.request, key: pending.id)
      var next = state
      next.orders.removeAll { $0.id == order.id }
      next.orders.insert(order, at: 0)
      next.pending = nil
      next.bag = Bag()
      try persist(next)
      return order
    } catch {
      if case ShopError.rejected = error {
        do {
          var next = state
          next.pending = nil
          try persist(next)
        } catch {
          self.error = error.localizedDescription
          return nil
        }
      }
      self.error = error.localizedDescription
      return nil
    }
  }
  func refresh(_ order: ShopOrder) async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      let updated = try await service.refresh(order)
      var next = state
      if let index = next.orders.firstIndex(where: { $0.id == order.id }) {
        next.orders[index] = updated
      }
      try persist(next)
    } catch { self.error = error.localizedDescription }
  }
  func configure(_ input: String) async {
    guard !busy else { return }
    let raw = input.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(
      in: CharacterSet(charactersIn: "/"))
    if !raw.isEmpty {
      guard let url = URL(string: raw), let host = url.host, url.user == nil, url.password == nil,
        url.query == nil, url.fragment == nil, url.path.isEmpty,
        url.scheme == "https"
          || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(host))
      else {
        error = "Use an HTTPS origin, or http://localhost:8080 in Simulator."
        return
      }
    }
    guard state.pending == nil else {
      error = "Retry the pending checkout before changing stores."
      return
    }
    if raw != endpoint && !raw.isEmpty && !endpoint.isEmpty {
      error = "Switch to the demo store before connecting a different server."
      return
    }
    if !raw.isEmpty && UserDefaults.standard.string(forKey: "lastServer") != raw {
      let serverFile = directory.appendingPathComponent("server.json")
      if FileManager.default.fileExists(atPath: serverFile.path) {
        error =
          "This installation has data for another server. Use a separate simulator or reinstall to change servers."
        return
      }
      UserDefaults.standard.set(raw, forKey: "lastServer")
    }
    endpoint = raw
    UserDefaults.standard.set(raw, forKey: "storeEndpoint")
    service = raw.isEmpty ? DemoService() : APIService(base: URL(string: raw)!)
    products = []
    load()
    await refreshCatalog()
  }
  func newGuestSession() async {
    guard !isDemo, !busy, state.pending == nil else { return }
    do {
      try Credentials.delete(account: endpoint)
      service = APIService(base: URL(string: endpoint)!)
      var next = state
      next.orders = []
      try persist(next)
      await refreshOrders()
    } catch { self.error = error.localizedDescription }
  }
}
