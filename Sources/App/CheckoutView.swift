import SafariServices
import SwiftUI

struct BagView: View {
  @EnvironmentObject var store: ShopStore
  @State private var showCheckout = false
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if store.state.bag.items.isEmpty {
          EmptyState(
            symbol: "bag", title: "Room for something good",
            message: "Your bag is empty. Explore the collection and find your everyday favourites.")
          PrimaryButton(title: "Explore the collection") { store.selectedTab = 0 }
        } else {
          ForEach(store.state.bag.items, id: \.productID) { item in
            HStack(spacing: 16) {
              ProductArt(art: store.products.first { $0.id == item.productID }?.art ?? "tray")
                .frame(width: 84, height: 100).cornerRadius(9)
              VStack(alignment: .leading, spacing: 9) {
                Text(store.products.first { $0.id == item.productID }?.name ?? "Unavailable item")
                  .font(.headline)
                if let product = store.products.first(where: { $0.id == item.productID }) {
                  Text(money(product.price * item.quantity)).foregroundColor(.secondary)
                }
                HStack {
                  Button {
                    store.setQuantity(item.productID, item.quantity - 1)
                  } label: {
                    Image(systemName: item.quantity == 1 ? "trash" : "minus").frame(
                      width: 36, height: 32)
                  }.accessibilityLabel("Decrease quantity of \(item.productID)")
                  Text("\(item.quantity)").monospacedDigit().frame(minWidth: 24)
                  Button {
                    store.setQuantity(item.productID, item.quantity + 1)
                  } label: {
                    Image(systemName: "plus").frame(width: 36, height: 32)
                  }.disabled(item.quantity >= 20).accessibilityLabel(
                    "Increase quantity of \(item.productID)")
                }.buttonStyle(.bordered).disabled(store.busy || store.state.pending != nil)
              }
              Spacer(minLength: 0)
            }
            Divider()
          }
          if let quote = store.total { PriceSummary(quote: quote) }
          if store.state.pending != nil {
            Label(
              "A checkout is pending. Retry it to safely recover the result.",
              systemImage: "arrow.clockwise"
            ).font(.subheadline).foregroundColor(.secondary)
          }
          PrimaryButton(
            title: store.state.pending == nil ? "Continue to checkout" : "Resume checkout"
          ) { showCheckout = true }
          .disabled(store.total == nil || store.busy)
          Text(
            "Test orders only. No money is collected.\nUS delivery · USD prices · No tax calculated in this demo."
          ).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
      }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
    }.background(Style.canvas).navigationTitle("Your bag")
      .sheet(isPresented: $showCheckout) {
        NavigationView { CheckoutView() }.navigationViewStyle(.stack).environmentObject(store)
      }
  }
}

struct PriceSummary: View {
  let quote: Quote
  var body: some View {
    VStack(spacing: 14) {
      HStack {
        Text("Subtotal")
        Spacer()
        Text(money(quote.subtotal))
      }
      HStack {
        Text("Delivery")
        Spacer()
        Text(quote.shipping == 0 ? "Free" : money(quote.shipping))
      }
      Divider()
      HStack {
        Text("Total")
        Spacer()
        Text(money(quote.total))
      }.font(.title3.weight(.semibold))
    }.font(.subheadline).padding(20).background(Style.panel).cornerRadius(12)
  }
}

struct CheckoutView: View {
  @EnvironmentObject var store: ShopStore
  @Environment(\.dismiss) var dismiss
  @State private var address = DeliveryAddress()
  @State private var placed: ShopOrder?
  var body: some View {
    Group {
      if let placed {
        ScrollView {
          VStack(spacing: 22) {
            Image(systemName: placed.checkoutURL == nil ? "checkmark.circle" : "creditcard").font(
              .system(size: 52, weight: .light)
            ).foregroundColor(Style.green)
            Text(
              placed.checkoutURL == nil
                ? "Thank you, \(placed.address.name.components(separatedBy: " ").first ?? "friend")."
                : "Your order is reserved."
            ).font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
            Text(
              placed.checkoutURL == nil
                ? "Your demo order is saved. Nothing was charged and no items will be shipped."
                : "Finish your test payment from Orders. Returning from the payment page does not confirm payment; refresh the order to verify it."
            ).foregroundColor(.secondary).multilineTextAlignment(.center)
            PriceSummary(quote: placed.quote)
            PrimaryButton(title: "View orders") {
              store.selectedTab = 2
              dismiss()
            }
          }.padding(24)
        }
      } else {
        Form {
          Section {
            Text("Test checkout — use a sample address. No real purchases or deliveries.").font(
              .subheadline
            ).foregroundColor(.secondary)
            if store.state.pending == nil { Button("Use sample address") { address = .sample } }
          }
          Section("Contact") {
            TextField("Full name", text: $address.name).textContentType(.name)
            TextField("Email", text: $address.email).textContentType(.emailAddress).keyboardType(
              .emailAddress
            ).textInputAutocapitalization(.never).disableAutocorrection(true)
          }.disabled(store.state.pending != nil || store.busy)
          Section("US delivery address") {
            TextField("Street address", text: $address.street).textContentType(.streetAddressLine1)
            TextField("City", text: $address.city).textContentType(.addressCity)
            TextField("State code (e.g. OR)", text: $address.region).textInputAutocapitalization(
              .characters)
            TextField("ZIP code", text: $address.postalCode).keyboardType(.numberPad)
              .textContentType(.postalCode)
          }.disabled(store.state.pending != nil || store.busy)
          if let quote = store.total {
            Section("Order total") { PriceSummary(quote: quote).listRowInsets(EdgeInsets()) }
          }
          Section {
            PrimaryButton(
              title: store.state.pending == nil ? "Place test order" : "Retry pending checkout",
              busy: store.busy
            ) { Task { placed = await store.placeOrder(address: address) } }
            .disabled(address.validationMessage != nil && store.state.pending == nil)
            if let error = store.error {
              Text(error).font(.subheadline).foregroundColor(.red).accessibilityIdentifier(
                "checkout-error")
            }
            if let message = address.validationMessage, store.state.pending == nil {
              Text(message).font(.caption).foregroundColor(.secondary)
            }
            Text("No tax is calculated. This reference store does not fulfil orders.").font(
              .caption
            ).foregroundColor(.secondary)
          }
        }
      }
    }.navigationTitle("Checkout").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(placed == nil ? "Close" : "Done") { dismiss() }.disabled(store.busy)
        }
      }
      .interactiveDismissDisabled(store.busy)
      .onAppear { if let pending = store.state.pending { address = pending.request.address } }
  }
}

struct PaymentBrowser: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
