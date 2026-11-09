// swift-tools-version: 6.4
import Foundation
import PackageDescription

let upcoming: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// With only the Command Line Tools installed, SwiftPM does not load the
// Swift Testing macro plugin (it lives in a `testing/` subfolder), so `@Test`
// fails to expand. Point the compiler at it explicitly when it exists.
let testingPluginDir = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testingPluginFlags: [SwiftSetting] =
    FileManager.default.fileExists(atPath: testingPluginDir)
        ? [.unsafeFlags(["-plugin-path", testingPluginDir])]
        : []

let package = Package(
    name: "DOTLauncher",
    platforms: [.macOS(.v27)],
    products: [
        .executable(name: "DOTLauncher", targets: ["DOTLauncher"]),
    ],
    targets: [
        // Pure logic, no AppKit. Everything here is unit tested.
        .target(
            name: "DOTLauncherCore",
            swiftSettings: upcoming
        ),
        // The menu bar app: AppKit + SwiftUI, main actor by default.
        .executableTarget(
            name: "DOTLauncher",
            dependencies: ["DOTLauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)] + upcoming
        ),
        .testTarget(
            name: "DOTLauncherCoreTests",
            dependencies: ["DOTLauncherCore"],
            swiftSettings: upcoming + testingPluginFlags
        ),
    ],
    swiftLanguageModes: [.v6]
)
