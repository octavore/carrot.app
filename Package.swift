// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarrotApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CarrotApp",
            path: "Sources/CarrotApp"
        ),
    ]
)
