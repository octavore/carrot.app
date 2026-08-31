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
    targets: [
        .executableTarget(
            name: "CarrotApp",
            path: "Sources/CarrotApp"
        ),
        .target(
            name: "CarrotMediaShim",
            path: "Sources/CarrotMediaShim",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
    ]
)
