// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Threadlight",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ThreadlightCore", targets: ["ThreadlightCore"]),
        .executable(name: "threadlight", targets: ["ThreadlightCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing", exact: "0.12.0"),
    ],
    targets: [
        .target(name: "ThreadlightCore"),
        .executableTarget(
            name: "ThreadlightCLI",
            dependencies: ["ThreadlightCore"],
            exclude: ["Info.plist"],
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                "-Xlinker", "Sources/ThreadlightCLI/Info.plist",
            ])]
        ),
        .testTarget(name: "ThreadlightCoreTests", dependencies: ["ThreadlightCore", .product(name: "Testing", package: "swift-testing")]),
    ]
)
