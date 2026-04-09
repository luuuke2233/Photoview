// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoView",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PhotoView", targets: ["PhotoView"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PhotoView",
            path: "Sources/PhotoView"
        )
    ]
)
