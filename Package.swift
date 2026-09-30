// swift-tools-version: 5.7
import PackageDescription
let package = Package(name: "ShopCore", platforms: [.iOS(.v15), .macOS(.v12)], products: [.library(name: "ShopCore", targets: ["ShopCore"])], targets: [.target(name: "ShopCore", path: "Sources/Core"), .testTarget(name: "ShopCoreTests", dependencies: ["ShopCore"], path: "Tests/Core")])
