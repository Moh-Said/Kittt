// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Kittt",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Kittt",
            path: "Sources/Kittt"
        )
    ]
)
