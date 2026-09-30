import SwiftUI

struct OrdersView: View {
  @EnvironmentObject var store: ShopStore
  var body: some View {
    List {
      if store.state.orders.isEmpty {
        EmptyState(
          symbol: "shippingbox", title: "Your story starts here",
          message:
            "Completed checkouts will appear here, with an itemised receipt and payment status."
        ).listRowBackground(Color.clear)
      }
      ForEach(store.state.orders) { order in
        NavigationLink {
          OrderDetail(orderID: order.id)
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(order.date, style: .date).font(.headline)
              Spacer()
              Text(money(order.quote.total)).font(.headline)
            }
            Text(order.quote.lines.map { "\($0.quantity) × \($0.name)" }.joined(separator: ", "))
              .font(.subheadline).foregroundColor(.secondary).lineLimit(2)
            Text(order.statusTitle).font(.caption.weight(.medium)).foregroundColor(
              order.status == "awaiting_payment" ? Style.tint : Style.status)
          }.padding(.vertical, 8)
        }
      }
      Section {
        Text(
          "Guest order history belongs to this installation and server. Test orders are never shipped."
        ).font(.footnote).foregroundColor(.secondary)
      }
    }.listStyle(.insetGrouped).navigationTitle("Orders")
      .refreshable { await store.refreshOrders() }
      .task { await store.refreshOrders() }
      .toolbar {
        Button {
          Task { await store.refreshOrders() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }.accessibilityLabel("Refresh orders").disabled(store.isDemo || store.busy)
      }
  }
}

struct OrderDetail: View {
  @EnvironmentObject var store: ShopStore
  let orderID: String
  @State private var paymentURL: URL?
  @State private var showPayment = false
  var body: some View {
    if let order = store.state.orders.first(where: { $0.id == orderID }) {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Label(
            order.statusTitle,
            systemImage: order.status == "awaiting_payment" ? "clock" : "checkmark.circle"
          ).font(.headline).foregroundColor(Style.status)
          Text("Order \(order.id.prefix(8).uppercased())").font(.system(.title, design: .serif))
          Text(order.date, style: .date).foregroundColor(.secondary)
          ForEach(order.quote.lines, id: \.productID) { line in
            HStack {
              Text("\(line.quantity) × \(line.name)")
              Spacer()
              Text(money(line.quantity * line.unitPrice))
            }.font(.subheadline)
          }
          PriceSummary(quote: order.quote)
          VStack(alignment: .leading, spacing: 6) {
            Text("Delivery details").font(.headline)
            Text(
              "\(order.address.name)\n\(order.address.street)\n\(order.address.city), \(order.address.region) \(order.address.postalCode)\nUnited States"
            ).foregroundColor(.secondary)
          }
          if order.status == "awaiting_payment", let raw = order.checkoutURL,
            let url = URL(string: raw), url.scheme == "https", url.host == "checkout.stripe.com"
          {
            PrimaryButton(title: "Continue test payment") {
              paymentURL = url
              showPayment = true
            }
          }
          if order.paymentMode == "stripe_test" {
            PrimaryButton(title: "Refresh payment status", busy: store.busy) {
              Task { await store.refresh(order) }
            }
          }
          Text("Test order · No real payment or delivery.").font(.footnote).foregroundColor(
            .secondary)
        }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
      }.background(Style.canvas).navigationTitle("Order details").navigationBarTitleDisplayMode(
        .inline
      )
      .sheet(isPresented: $showPayment, onDismiss: { Task { await store.refresh(order) } }) {
        if let paymentURL { PaymentBrowser(url: paymentURL) }
      }
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject var store: ShopStore
  @State private var endpoint = ""
  @State private var resetGuest = false
  var body: some View {
    Form {
      Section("Store connection") {
        Label(store.modeTitle, systemImage: store.isDemo ? "shippingbox" : "network")
        Text(
          "Demo mode runs entirely on this device. Connect the included server to exercise the API and optional Stripe test checkout."
        ).font(.footnote).foregroundColor(.secondary)
        TextField("http://localhost:8080", text: $endpoint).keyboardType(.URL)
          .textInputAutocapitalization(.never).disableAutocorrection(true)
        Button("Connect to server") { Task { await store.configure(endpoint) } }.disabled(
          endpoint.isEmpty || store.busy || store.loading)
        if !store.isDemo {
          Button("Use standalone demo") { Task { await store.configure("") } }.disabled(
            store.busy || store.loading)
        }
      }
      Section("Privacy") {
        Text(
          "No analytics or advertising. The demo stays on your device. Connected checkout sends the entered address and bag to your configured server. Use the sample address when evaluating the project."
        ).font(.subheadline)
        Text(
          "Guest credentials are kept in Keychain. There is no cross-device account or password recovery."
        ).font(.footnote).foregroundColor(.secondary)
        if !store.isDemo {
          Button("Start a new guest session", role: .destructive) { resetGuest = true }.disabled(
            store.busy || store.state.pending != nil)
        }
      }
      Section("About") {
        Text("Local Shop").font(.headline)
        Text("A small store for useful, everyday things.\nPortfolio edition · iOS 15+")
          .foregroundColor(.secondary)
        Text(
          "USD · US addresses only · No sales tax engine, stock reservations, or real fulfilment."
        ).font(.footnote).foregroundColor(.secondary)
      }
    }.navigationTitle("Settings").onAppear { endpoint = store.endpoint }
      .alert("Start a new guest session?", isPresented: $resetGuest) {
        Button("Cancel", role: .cancel) {}
        Button("Start new session", role: .destructive) { Task { await store.newGuestSession() } }
      } message: {
        Text(
          "You will lose access to this guest's server order history. Existing orders stay on the reference server. This does not delete them."
        )
      }
  }
}
