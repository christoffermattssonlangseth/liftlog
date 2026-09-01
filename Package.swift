// swift-tools-version: 5.9
import PackageDescription

// The app's pure-logic layer (parsing, serialization, analytics) lives in
// LiftLog/Core and is Foundation-only, so it builds and tests on the command
// line with no simulator: `swift test`. The iOS app compiles the same files
// via its Xcode target.
let package = Package(
    name: "LiftLogCore",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "LiftLogCore", targets: ["LiftLogCore"]),
    ],
    targets: [
        .target(name: "LiftLogCore", path: "LiftLog/Core"),
        .testTarget(
            name: "LiftLogCoreTests",
            dependencies: ["LiftLogCore"],
            path: "Tests/LiftLogCoreTests"
        ),
    ]
)
