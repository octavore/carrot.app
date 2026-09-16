// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarrotApp",
    platforms: [.macOS(.v14)],
    products: [
        // Built as a dylib but never linked by CarrotApp: it is loaded into
        // /usr/bin/perl at runtime, which is the only way to reach MediaRemote
        // on macOS 15.4+. See research/2026-08-31-mediaremote-perl-adapter.md.
        .library(name: "CarrotMediaShim", type: .dynamic, targets: ["CarrotMediaShim"]),
    ],
    dependencies: [
        .package(url: "https://github.com/octavore/sunshine.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "CarrotApp",
            dependencies: [
                .product(name: "Sunshine", package: "sunshine"),
            ],
            path: "Sources/CarrotApp"
        ),
        .target(
            name: "CarrotMediaShim",
            path: "Sources/CarrotMediaShim",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
    ]
)
