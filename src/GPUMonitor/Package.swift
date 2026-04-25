// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GPUMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "CIOReport",
            path: "Sources/CIOReport"
        ),
        .executableTarget(
            name: "GPUMonitor",
            dependencies: ["CIOReport"],
            path: "Sources/GPUMonitor",
            linkerSettings: [
                .unsafeFlags(["-L/usr/lib", "-lIOReport"])
            ]
        ),
    ]
)
