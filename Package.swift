// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "cgtcalc",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "CGTCalcCore",
      targets: ["CGTCalcCore"]),
    .executable(
      name: "cgtcalc",
      targets: ["cgtcalc"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
  ],
  targets: [
    .target(
      name: "CGTCalcCore",
      dependencies: [],
      path: "Sources/CGTCalcCore"),
    .executableTarget(
      name: "cgtcalc",
      dependencies: [
        "CGTCalcCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/cgtcalc"),
    .testTarget(
      name: "CGTCalcCoreTests",
      dependencies: ["CGTCalcCore"],
      path: "Tests/CGTCalcCoreTests",
      resources: [
        .copy("TestData")
      ]),
    .testTarget(
      name: "CGTCalcCorePublicAPITests",
      dependencies: ["CGTCalcCore"],
      path: "Tests/CGTCalcCorePublicAPITests"),
    .testTarget(
      name: "cgtcalcTests",
      dependencies: ["cgtcalc"],
      path: "Tests/cgtcalcTests")
  ])
