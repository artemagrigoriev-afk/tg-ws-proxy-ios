// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwTgWsAppModules",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "TgWsProxy", targets: ["TgWsProxy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mac-cain13/R.swift.git", from: "7.8.0"),
        .package(path: "../"),//Local SwTgWs dependency
    ],
    targets: [
        .target(name: "TgWsProxy", dependencies: [
            .product(name: "RswiftLibrary", package: "R.swift"),
            .product(name: "SwTgWs", package: "SwTgWs")
        ], resources: [.copy("PrivacyInfo.xcprivacy")], linkerSettings: [
            .linkedFramework("Network"),
            .linkedFramework("CommonCrypto")
        ], plugins: [
            .plugin(name: "RswiftGenerateInternalResources", package: "R.swift")
        ]),
    ],
    swiftLanguageVersions: [.v5]
)
