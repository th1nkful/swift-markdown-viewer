// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-markdown-viewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PlanViewerCore", targets: ["PlanViewerCore"]),
        .executable(name: "planner", targets: ["planner"])
    ],
    targets: [
        .target(
            name: "PlanViewerCore"
        ),
        .executableTarget(
            name: "planner",
            dependencies: ["PlanViewerCore"]
        ),
        .testTarget(
            name: "PlanViewerCoreTests",
            dependencies: ["PlanViewerCore"]
        )
    ]
)
