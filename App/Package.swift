// swift-tools-version: 5.9
import PackageDescription

// The SwiftUI/AppKit app is macOS-only; on other hosts the package builds
// just the portable core + CLI. Package.swift is evaluated on the build host,
// so a plain #if on the build OS is the right switch. (A bare #if can't sit
// between array-literal elements, so the app target/product are appended
// conditionally to these arrays instead.)
var products: [Product] = [
    .executable(name: "minidumptruck-cli", targets: ["MiniDumpTruckCLI"]),
    .library(name: "MiniDumpTruckCore", targets: ["MiniDumpTruckCore"])
]

var targets: [Target] = [
    // System zlib, used for DEFLATE inflate on platforms without Apple's
    // Compression.framework (Linux/Windows). Apple builds use Compression
    // instead and never link this.
    .systemLibrary(name: "CZlib", path: "CZlib"),
    // Core library for testing (non-UI code only)
    .target(
        name: "MiniDumpTruckCore",
        dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
            .target(name: "CZlib", condition: .when(platforms: [.linux, .windows, .android, .openbsd]))
        ],
        path: "MiniDumpTruck",
        exclude: [
            "Info.plist",
            "MiniDumpTruck.entitlements",
            "MiniDumpTruckApp.swift",
            "MinidumpDocument.swift",
            "Views",
            "ViewModels"
        ],
        sources: [
            "Models",
            "Parsers",
            "Services",
            "Utilities"
        ]
    ),
    // CLI tool
    .executableTarget(
        name: "MiniDumpTruckCLI",
        dependencies: [
            "MiniDumpTruckCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ],
        path: "CLI"
    ),
    // Test target for core library. Depends on CZlib off-Apple so the ZIP
    // tests can DEFLATE fixtures with system zlib (matching the inflate path
    // the library uses there).
    .testTarget(
        name: "MiniDumpTruckTests",
        dependencies: [
            "MiniDumpTruckCore",
            .target(name: "CZlib", condition: .when(platforms: [.linux, .windows, .android, .openbsd]))
        ],
        path: "Tests"
    )
]

#if os(macOS)
products.append(.executable(name: "MiniDumpTruck", targets: ["MiniDumpTruck"]))
targets.append(
    // Main executable app (depends on core library). SwiftUI/AppKit, macOS-only.
    .executableTarget(
        name: "MiniDumpTruck",
        dependencies: ["MiniDumpTruckCore"],
        path: "MiniDumpTruck",
        exclude: [
            "Info.plist",
            "MiniDumpTruck.entitlements",
            "Models",
            "Parsers",
            "Services",
            "Utilities"
        ],
        sources: [
            "MiniDumpTruckApp.swift",
            "MinidumpDocument.swift",
            "Views",
            "ViewModels"
        ]
    )
)
#endif

let package = Package(
    name: "MiniDumpTruck",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.7.0"),
        // Cross-platform SHA-256 (CryptoKit on Apple, BoringSSL on Linux).
        // Replaces CommonCrypto so the symbol-server trust hashing builds
        // off-Apple.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0")
    ],
    targets: targets
)
