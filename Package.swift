// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "StateRoundtripKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "StateRoundtripKit", targets: ["StateRoundtripKit"])],
    targets: [.target(name: "StateRoundtripKit"),
              .testTarget(name: "StateRoundtripKitTests", dependencies: ["StateRoundtripKit"])]
)
