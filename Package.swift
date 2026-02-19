// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardWhere",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClipboardWhere",
            path: "Sources/ClipboardWhere"
        )
    ]
)
