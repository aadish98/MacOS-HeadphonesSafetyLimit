// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HeadphoneSafetyLimit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "HeadphoneSafety",
            targets: ["HeadphoneSafety"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HeadphoneSafety",
            path: "Sources/HeadphoneSafety"
        )
    ]
)
