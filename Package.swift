// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ElectrumKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ElectrumKit",
            targets: ["ElectrumKit"]),
    ],
    targets: [
        .target(
            name: "ElectrumKit"),
        .testTarget(
            name: "ElectrumKitTests",
            dependencies: ["ElectrumKit"]
        ),
    ]
)
