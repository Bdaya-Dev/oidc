// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oidc_darwin",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "oidc-darwin", targets: ["oidc_darwin"])
    ],
    dependencies: [
        // Required for Swift Package Manager plugins as of Flutter 3.41.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "oidc_darwin",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // .process("Resources"),
            ]
        )
    ]
)
