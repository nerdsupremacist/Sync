// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sync",
    platforms: [.macOS(.v12), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "Sync",
            targets: ["Sync"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Sync",
            dependencies: []),
        .testTarget(
            name: "SyncTests",
            dependencies: ["Sync"]),
    ]
)
