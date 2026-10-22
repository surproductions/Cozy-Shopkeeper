// swift-tools-version:5.9
import PackageDescription

// ShopCore holds every gameplay rule of Cozy Shopkeeper: content, economy,
// customers, progression, persistence and monetization policy. It depends only
// on Foundation so it builds and tests on macOS, iOS and Linux.
let package = Package(
    name: "ShopCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "ShopCore", targets: ["ShopCore"])
    ],
    targets: [
        .target(name: "ShopCore", path: "Sources/ShopCore"),
        .testTarget(name: "ShopCoreTests", dependencies: ["ShopCore"], path: "Tests/ShopCoreTests")
    ]
)
