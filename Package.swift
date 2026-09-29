// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Mochi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Mochi",
            path: "Sources/Mochi",
            linkerSettings: [.linkedFramework("Carbon")]
        )
    ]
)
