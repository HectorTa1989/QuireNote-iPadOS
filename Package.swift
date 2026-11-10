// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Quire",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "QuireCore", targets: ["QuireCore"]),
    ],
    targets: [
        .target(name: "QuireCore"),
        .testTarget(name: "QuireCoreTests", dependencies: ["QuireCore"]),
    ]
)
