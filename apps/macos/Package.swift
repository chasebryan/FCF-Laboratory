// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FCFLaboratory",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "FCF-Laboratory", targets: ["FCFLaboratoryApp"])
    ],
    targets: [
        .target(
            name: "FCFPTY",
            path: "Sources/FCFPTY",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("util")
            ]
        ),
        .executableTarget(
            name: "FCFLaboratoryApp",
            dependencies: ["FCFPTY"],
            path: "Sources/FCFLaboratoryApp"
        ),
        .testTarget(
            name: "FCFLaboratoryAppTests",
            dependencies: ["FCFLaboratoryApp"],
            path: "Tests/FCFLaboratoryAppTests"
        )
    ]
)
