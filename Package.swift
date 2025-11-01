// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "cgtcalc",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "CGTCalcCore", targets: ["CGTCalcCore"]),
    .executable(name: "cgtcalc", targets: ["cgtcalc"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.6.0"))
  ],
  targets: [
    .target(
      name: "CGTCalcCore"),
    .executableTarget(
      name: "cgtcalc",
      dependencies: [
        "CGTCalcCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]),
    .testTarget(
      name: "CGTCalcCoreTests",
      dependencies: ["CGTCalcCore"],
      resources: [
        .copy("TestData")
      ])
  ])
