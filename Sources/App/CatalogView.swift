import SwiftUI

struct CatalogView: View {
  @EnvironmentObject var store: ShopStore
  @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 40.0
  @State private var search = ""
  @State private var category = "All"
  @State private var sort = "Featured"
  private var filtered: [Product] {
    let products = store.products.filter {
      (category == "All" || $0.category == category)
        && (search.isEmpty
          || "\($0.name) \($0.category) \($0.description)".localizedCaseInsensitiveContains(search))
    }
    switch sort {
    case "Price: low to high": return products.sorted { $0.price < $1.price }
    case "Price: high to low": return products.sorted { $0.price > $1.price }
    default: return products
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Label(store.isDemo ? "DEMO COLLECTION" : "TEST STOREFRONT", systemImage: "circle.fill")
            .font(.caption2.weight(.semibold)).foregroundColor(Style.status)
          Spacer()
          Text("USD · US delivery").font(.caption).foregroundColor(.secondary)
        }
        if search.isEmpty && category == "All" {
          VStack(alignment: .leading, spacing: 12) {
            Text("Good things.\nEvery day.").font(
              .system(size: headingSize, weight: .regular, design: .serif)
            ).tracking(-1)
            Text("Useful pieces for the way you live.").foregroundColor(.secondary)
            HStack(spacing: 7) {
              Image(systemName: "shippingbox")
              Text("Free delivery on orders $75+")
            }.font(.caption.weight(.medium)).padding(.top, 4)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(["All", "Kitchen", "Living", "Everyday"], id: \.self) { item in
              Button {
                category = item
              } label: {
                Text(item).font(.subheadline.weight(.medium)).padding(.horizontal, 18).padding(
                  .vertical, 11
                )
                .background(category == item ? Style.green : Style.panel)
                .foregroundColor(category == item ? .white : .primary).clipShape(Capsule())
              }.buttonStyle(.plain).accessibilityAddTraits(category == item ? .isSelected : [])
            }
          }
        }
        HStack {
          Text(category == "All" ? "The collection" : category).font(.title3.weight(.semibold))
          Spacer()
          Menu {
            Picker("Sort", selection: $sort) {
              ForEach(["Featured", "Price: low to high", "Price: high to low"], id: \.self) {
                Text($0)
              }
            }
          } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down").font(.subheadline)
          }
        }
        if store.loading && store.products.isEmpty {
          ProgressView("Opening the shop…").frame(maxWidth: .infinity).padding(40)
        } else if let error = store.loadError {
          EmptyState(
            symbol: "wifi.exclamationmark", title: "The shop is out of reach", message: error)
          PrimaryButton(title: "Try again") { Task { await store.refreshCatalog() } }
        } else if filtered.isEmpty {
          EmptyState(
            symbol: "magnifyingglass", title: "Nothing here yet",
            message: "Try another search or collection.")
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 24) {
            ForEach(filtered) { product in
              NavigationLink {
                ProductDetail(product: product)
              } label: {
                VStack(alignment: .leading, spacing: 7) {
                  ProductArt(art: product.art).aspectRatio(0.95, contentMode: .fit).cornerRadius(12)
                  Text(product.category.uppercased()).font(.system(size: 10, weight: .semibold))
                    .tracking(1).foregroundColor(.secondary)
                  Text(product.name).font(.body.weight(.medium)).foregroundColor(.primary)
                  Text(money(product.price)).font(.subheadline).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
              }.buttonStyle(.plain)
            }
          }
        }
        Text("A sample store. No real purchases or deliveries.").font(.footnote).foregroundColor(
          .secondary
        ).padding(.vertical, 8)
      }.padding(20).frame(maxWidth: 900).frame(maxWidth: .infinity)
    }
    .background(Style.canvas).navigationTitle("Local Shop").navigationBarTitleDisplayMode(.inline)
    .searchable(text: $search, prompt: "Find something useful")
    .refreshable { await store.refreshCatalog() }
  }
}

struct ProductDetail: View {
  @EnvironmentObject var store: ShopStore
  let product: Product
  @State private var added = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ProductArt(art: product.art).frame(height: 310).cornerRadius(16)
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Text(product.category.uppercased()).font(.caption.weight(.semibold)).tracking(2)
              .foregroundColor(Style.tint)
            Text(product.name).font(.system(.largeTitle, design: .serif))
          }
          Spacer()
          Text(money(product.price)).font(.title3).padding(.top, 27)
        }
        Text(product.tagline).font(.title3)
        Text(product.description).foregroundColor(.secondary).lineSpacing(5)
        Divider()
        Label(product.details, systemImage: "checkmark.seal").font(.subheadline)
        Label("$4.95 delivery · free over $75", systemImage: "shippingbox").font(.subheadline)
        Text("Sample product · Illustrations are representative.").font(.caption).foregroundColor(
          .secondary)
        PrimaryButton(title: added ? "Added to your bag" : "Add to bag") {
          let previous = store.state.bag.quantity(product.id)
          store.setQuantity(product.id, previous + 1)
          added = store.state.bag.quantity(product.id) > previous
        }.disabled(store.state.bag.quantity(product.id) >= 20 || store.state.pending != nil)
        if added { Button("View bag") { store.selectedTab = 1 }.frame(maxWidth: .infinity) }
        if store.state.pending != nil {
          Text("Resolve your pending checkout in Bag before adding items.").font(.footnote)
            .foregroundColor(.secondary)
        }
      }.padding(20).frame(maxWidth: 600).frame(maxWidth: .infinity)
    }.background(Style.canvas).navigationBarTitleDisplayMode(.inline)
  }
}
