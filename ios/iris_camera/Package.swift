// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iris_camera",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "iris_camera",
            targets: ["iris_camera"]
        ),
    ],
    targets: [
        .target(
            name: "iris_camera",
            path: "Classes",
            publicHeadersPath: "",
            cSettings: [
                // Aligns with CocoaPods builds that define COCOAPODS when present.
                .define("COCOAPODS", to: "1")
            ]
        ),
    ]
)
