// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oidc_ios",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "oidc-ios", targets: ["oidc_ios"])
    ],
    dependencies: [
        // Required for Swift Package Manager plugins as of Flutter 3.41.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "oidc_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // .process("Resources"),
            ]
        )
    ]
)
