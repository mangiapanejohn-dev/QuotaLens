// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "QuotaLens",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "QuotaLens",
            path: "Sources/QuotaLens"
        ),
        .testTarget(
            name: "QuotaLensTests",
            dependencies: ["QuotaLens"],
            path: "Tests/QuotaLensTests"
        )
    ]
)
