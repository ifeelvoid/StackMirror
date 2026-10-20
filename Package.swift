// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StackMirror",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StackMirror", targets: ["StackMirror"])
    ],
    targets: [
        .executableTarget(
            name: "StackMirror",
            path: "Sources/StackMirror"
        ),
        .testTarget(
            name: "StackMirrorTests",
            dependencies: ["StackMirror"],
            path: "Tests/StackMirrorTests"
        )
    ]
)
