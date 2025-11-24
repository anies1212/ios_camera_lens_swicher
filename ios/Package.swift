// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "IrisCameraPlugin",
  platforms: [.iOS(.v14)],
  products: [
    .library(name: "IrisCameraPlugin", targets: ["IrisCameraPlugin"]),
  ],
  targets: [
    .target(
      name: "IrisCameraPlugin",
      path: "Classes"
    ),
    .testTarget(
      name: "IrisCameraPluginTests",
      dependencies: ["IrisCameraPlugin"],
      path: "Tests"
    ),
  ]
)
