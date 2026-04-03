// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarTodo",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarTodo",
            path: "MenuBarTodo/Sources",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
