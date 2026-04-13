// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EzNote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EzNote",
            path: "Sources/EzNote"
        )
    ]
)
