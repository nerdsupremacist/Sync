// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sync",
    platforms: [.macOS(.v11), .iOS(.v14), .watchOS(.v6), .tvOS(.v14)],
    products: [
        .library(
            name: "Sync",
            targets: ["Sync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.13.0"),
        .package(url: "https://github.com/nerdsupremacist/AssociatedTypeRequirementsKit.git", .upToNextMinor(from: "0.3.2")),
    ],
    targets: [
        .target(
            name: "Sync",
            dependencies: [
                .product(name: "OpenCombineShim", package: "OpenCombine"),
                .product(name: "AssociatedTypeRequirementsKit", package: "AssociatedTypeRequirementsKit"),
            ]),
        .testTarget(
            name: "SyncTests",
            dependencies: ["Sync"]),
    ]
)
