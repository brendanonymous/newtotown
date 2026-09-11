// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewToTownCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NewToTownCore", targets: ["NewToTownCore"])],
    targets: [
        .target(name: "NewToTownCore", path: "Sources/NewToTownCore"),
        .testTarget(name: "NewToTownCoreTests", dependencies: ["NewToTownCore"])
    ]
)
