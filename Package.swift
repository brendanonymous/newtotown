// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NewToTownCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NewToTownCore", targets: ["NewToTownCore"]),
        .library(name: "NewToTownSupabase", targets: ["NewToTownSupabase"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.1")
    ],
    targets: [
        .target(name: "NewToTownCore"),
        .target(
            name: "NewToTownSupabase",
            dependencies: [
                "NewToTownCore",
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        .testTarget(name: "NewToTownCoreTests", dependencies: ["NewToTownCore"]),
        .testTarget(name: "NewToTownSupabaseTests", dependencies: ["NewToTownSupabase"])
    ]
)
