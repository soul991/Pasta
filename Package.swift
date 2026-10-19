// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PeelCore", targets: ["PeelCore"]),
        .executable(name: "Peel", targets: ["Peel"]),
        .executable(name: "PeelTests", targets: ["PeelTests"])
    ],
    targets: [
        .target(
            name: "PeelCore",
            path: "PeelCore"
        ),
        .executableTarget(
            name: "Peel",
            dependencies: ["PeelCore"],
            path: "Peel"
        ),
        .executableTarget(
            name: "PeelTests",
            dependencies: ["PeelCore"],
            path: "PeelTests"
        )
    ]
)
