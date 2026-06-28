// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObsidianInbox",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ObsidianInbox", targets: ["ObsidianInbox"])
    ],
    targets: [
        .executableTarget(
            name: "ObsidianInbox",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Vision"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Security")
            ]
        )
    ]
)
