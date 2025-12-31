// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oidc_macos",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "oidc-macos", targets: ["oidc_macos"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "oidc_macos",
            dependencies: [],
            resources: [
                // .process("Resources"),
            ]
        )
    ]
)
