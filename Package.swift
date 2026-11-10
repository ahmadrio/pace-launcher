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

// Release builds record source paths (for example in Swift's "unimplemented
// initializer" traps). Map the checkout folder to "." there; debug builds
// keep real paths so the debugger finds the sources. (scripts/build-app.sh
// strips the debug symbols, which hold more paths, from release builds.)
let prefixMap: [SwiftSetting] = [
    .unsafeFlags(["-file-prefix-map", "\(Context.packageDirectory)=."], .when(configuration: .release)),
]

let package = Package(
    name: "PACELauncher",
    platforms: [.macOS(.v27)],
    products: [
        .executable(name: "PACELauncher", targets: ["PACELauncher"]),
    ],
    targets: [
        // Pure logic, no AppKit. Everything here is unit tested.
        .target(
            name: "PACELauncherCore",
            swiftSettings: upcoming + prefixMap
        ),
        // The menu bar app: AppKit + SwiftUI, main actor by default.
        .executableTarget(
            name: "PACELauncher",
            dependencies: ["PACELauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)] + upcoming + prefixMap
        ),
        .testTarget(
            name: "PACELauncherCoreTests",
            dependencies: ["PACELauncherCore"],
            swiftSettings: upcoming + testingPluginFlags
        ),
    ],
    swiftLanguageModes: [.v6]
)
