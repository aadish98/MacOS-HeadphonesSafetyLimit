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
        ),
        .executable(
            name: "HeadphoneSafetyMonitor",
            targets: ["HeadphoneSafetyMonitor"]
        ),
        .executable(
            name: "HeadphoneSafetyVerify",
            targets: ["HeadphoneSafetyVerify"]
        )
    ],
    targets: [
        .target(
            name: "HeadphoneSafetyCore",
            path: "Sources/HeadphoneSafetyCore"
        ),
        .executableTarget(
            name: "HeadphoneSafety",
            dependencies: ["HeadphoneSafetyCore"],
            path: "Sources/HeadphoneSafety"
        ),
        .executableTarget(
            name: "HeadphoneSafetyMonitor",
            dependencies: ["HeadphoneSafetyCore"],
            path: "Sources/HeadphoneSafetyMonitor"
        ),
        .executableTarget(
            name: "HeadphoneSafetyVerify",
            dependencies: ["HeadphoneSafetyCore"],
            path: "Sources/HeadphoneSafetyVerify"
        ),
        .testTarget(
            name: "HeadphoneSafetyCoreTests",
            dependencies: ["HeadphoneSafetyCore"],
            path: "Tests/HeadphoneSafetyCoreTests"
        )
    ]
)
