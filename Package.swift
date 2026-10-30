// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pasta",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PastaCore", targets: ["PastaCore"]),
        .executable(name: "Pasta", targets: ["Pasta"]),
        .executable(name: "PastaTests", targets: ["PastaTests"])
    ],
    targets: [
        .target(
            name: "PastaCore",
            path: "PastaCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Pasta",
            dependencies: ["PastaCore"],
            path: "Pasta"
        ),
        .executableTarget(
            name: "PastaTests",
            dependencies: ["PastaCore"],
            path: "PastaTests"
        )
    ]
)
