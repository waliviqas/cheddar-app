// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVPipeline",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "CVPipeline"),
        .testTarget(
            name: "CVPipelineTests",
            dependencies: ["CVPipeline"],
            resources: [.copy("Resources")]
        ),
    ]
)
