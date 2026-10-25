// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVPipeline",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CVPipeline", targets: ["CVPipeline"]),
    ],
    targets: [
        .target(name: "CVPipeline", resources: [.copy("Resources/PuckModel.mlmodel")]),
        .testTarget(
            name: "CVPipelineTests",
            dependencies: ["CVPipeline"],
            resources: [.copy("Resources")]
        ),
    ]
)
