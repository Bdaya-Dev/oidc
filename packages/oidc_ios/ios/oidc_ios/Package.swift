// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oidc_ios",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "oidc-ios", targets: ["oidc_ios"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "oidc_ios",
            dependencies: [],
            resources: [
                // .process("Resources"),
            ]
        )
    ]
)
