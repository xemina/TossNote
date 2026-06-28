// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TossNote",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TossNote", targets: ["TossNote"])
    ],
    targets: [
        .executableTarget(
            name: "TossNote",
            resources: [
                .process("Resources/TossNoteIcon.png"),
                .process("Resources/TossNote.icns"),
                .process("Resources/Assets.xcassets")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Vision"),
                .linkedFramework("PDFKit")
            ]
        )
    ]
)
