// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhotoBorderKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PhotoBorderKit", targets: ["PhotoBorderKit"])
    ],
    targets: [
        .target(name: "PhotoBorderKit")
    ]
)
