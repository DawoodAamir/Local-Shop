import SwiftUI

@main
struct LocalShopApp: App {
  @StateObject private var store = ShopStore()
  var body: some Scene {
    WindowGroup { ShopRoot().environmentObject(store).tint(Style.tint) }
  }
}

enum Style {
  static let accent = Color(red: 0.62, green: 0.25, blue: 0.15)
  static let tint = Color(
    UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.94, green: 0.59, blue: 0.43, alpha: 1)
        : UIColor(red: 0.62, green: 0.25, blue: 0.15, alpha: 1)
    })
  static let status = Color(
    UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.62, green: 0.77, blue: 0.63, alpha: 1)
        : UIColor(red: 0.24, green: 0.36, blue: 0.28, alpha: 1)
    })
  static let canvas = Color(UIColor.systemGroupedBackground)
  static let panel = Color(UIColor.secondarySystemGroupedBackground)
  static let green = Color(red: 0.24, green: 0.36, blue: 0.28)
}

struct ShopRoot: View {
  @EnvironmentObject var store: ShopStore
  var body: some View {
    TabView(selection: $store.selectedTab) {
      NavigationView { CatalogView() }.navigationViewStyle(.stack)
        .tabItem { Label("Shop", systemImage: "building.2") }.tag(0)
      NavigationView { BagView() }.navigationViewStyle(.stack)
        .tabItem { Label("Bag", systemImage: "bag") }.badge(store.state.bag.count).tag(1)
      NavigationView { OrdersView() }.navigationViewStyle(.stack)
        .tabItem { Label("Orders", systemImage: "shippingbox") }.tag(2)
      NavigationView { SettingsView() }.navigationViewStyle(.stack)
        .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
    }
    .task { await store.refreshCatalog() }
    .alert(
      "Something needs attention",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }
}

struct PrimaryButton: View {
  let title: String
  var busy = false
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Spacer()
        if busy { ProgressView().tint(.white) }
        Text(title).fontWeight(.semibold)
        Spacer()
      }
      .padding(.vertical, 16).foregroundColor(.white).background(Style.accent).cornerRadius(12)
    }.buttonStyle(.plain).disabled(busy)
  }
}

struct EmptyState: View {
  let symbol, title, message: String
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundColor(
        Style.tint)
      Text(title).font(.title2.weight(.semibold))
      Text(message).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
    }.padding(32).frame(maxWidth: .infinity)
  }
}
