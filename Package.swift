// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GreenshotMac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GreenshotMac",
            path: "Sources/GreenshotMac",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .testTarget(
            name: "GreenshotMacTests",
            dependencies: ["GreenshotMac"],
            path: "Tests/GreenshotMacTests"
        )
    ]
)
