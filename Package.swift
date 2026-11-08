// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pupil",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Pupil", targets: ["Pupil"])
    ],
    targets: [
        .executableTarget(
            name: "Pupil",
            path: "Sources/Pupil",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Vision"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOKit"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CryptoKit")
            ]
        ),
        .testTarget(
            name: "PupilTests",
            dependencies: ["Pupil"],
            path: "Tests/PupilTests"
        )
    ]
)
