// swift-tools-version:5.9
import PackageDescription

let adapters: [Target.Dependency] = [
    "HirebarDomain", "HirebarApplication", "HirebarStorage", "HirebarTelegram", "HirebarNotifications", "HirebarPortals",
]

let package = Package(
    name: "Hirebar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hirebar", targets: ["Hirebar"]),
    ],
    targets: [
        .target(name: "HirebarDomain"),
        .target(name: "HirebarApplication", dependencies: ["HirebarDomain"]),
        .target(name: "HirebarStorage", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .target(name: "HirebarTelegram", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .target(name: "HirebarNotifications", dependencies: ["HirebarApplication"]),
        .target(name: "HirebarPortals", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .target(name: "HirebarEngine", dependencies: adapters),
        .executableTarget(name: "Hirebar", dependencies: adapters + ["HirebarEngine"]),
        .testTarget(name: "HirebarDomainTests", dependencies: ["HirebarDomain"]),
        .testTarget(name: "HirebarApplicationTests", dependencies: ["HirebarApplication", "HirebarDomain"]),
        .testTarget(name: "HirebarStorageTests", dependencies: ["HirebarApplication", "HirebarDomain", "HirebarStorage"]),
        .testTarget(name: "HirebarTelegramTests", dependencies: ["HirebarDomain", "HirebarTelegram"]),
        .testTarget(name: "HirebarPortalsTests", dependencies: ["HirebarDomain", "HirebarPortals"]),
        .testTarget(name: "HirebarEngineTests", dependencies: adapters + ["HirebarEngine"]),
    ]
)
