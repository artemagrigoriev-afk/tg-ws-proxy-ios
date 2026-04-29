// swift-tools-version:6.0
import PackageDescription

#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
//Exclude CryptoSwift package (used built-in CommonCrypto)
let dependencies: [Package.Dependency] = []
let mainTargetDependencies: [Target.Dependency] = []
#else
let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.9.0")
]
let mainTargetDependencies: [Target.Dependency] = [
    .product(name: "CryptoSwift", package: "CryptoSwift")
]
#endif

let package = Package(
    name: "SwTgWs",
    platforms: [
        .macOS(.v10_12), .macCatalyst(.v13), .iOS(.v10), .tvOS(.v10), .watchOS(.v3), .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwTgWs",
            targets: ["SwTgWs"]),
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "SwTgWs", dependencies: mainTargetDependencies, resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "SwTgWsTests", dependencies: ["SwTgWs"]),
    ],
    swiftLanguageVersions: [.v5, .v6]
)
