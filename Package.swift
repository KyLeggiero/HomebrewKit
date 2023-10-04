// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HomebrewKit",
    platforms: [
        .macOS("10.15.4"),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HomebrewKit",
            targets: ["HomebrewKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/RougeWare/Swift-Collection-Tools.git", from: "3.2.0"),
        .package(url: "https://github.com/RougeWare/Swift-Special-String.git", from: "1.1.3"),
        .package(url: "https://github.com/RougeWare/Swift-Simple-Logging", from: "0.5.2"),
        .package(url: "https://github.com/RougeWare/Swift-SerializationTools.git", from: "1.1.1"),
        .package(url: "https://github.com/sunshinejr/SwiftyUserDefaults.git", from: "5.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "HomebrewKit",
            dependencies: [
                .product(name: "CollectionTools", package: "Swift-Collection-Tools"),
                .product(name: "SpecialString", package: "Swift-Special-String"),
                .product(name: "SimpleLogging", package: "Swift-Simple-Logging"),
                .product(name: "SerializationTools", package: "Swift-SerializationTools"),
                "SwiftyUserDefaults"
            ]),
        .testTarget(
            name: "HomebrewKitTests",
            dependencies: ["HomebrewKit"]),
    ]
)
