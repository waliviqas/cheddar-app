// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CheddarCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "CheddarCore"),
        .testTarget(name: "CheddarCoreTests", dependencies: ["CheddarCore"]),
    ]
)
