// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewToTownCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NewToTownCore", targets: ["NewToTownCore"])],
    dependencies: [.package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.1")],
    targets: [
        .target(name: "NewToTownCore", dependencies: [.product(name: "Supabase", package: "supabase-swift")], path: "Sources/NewToTownCore"),
        .testTarget(name: "NewToTownCoreTests", dependencies: ["NewToTownCore"])
    ]
)
