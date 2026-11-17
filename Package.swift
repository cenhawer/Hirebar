// swift-tools-version:6.2
import PackageDescription

let adapters: [Target.Dependency] = [
    "HirebarDomain", "HirebarApplication", "HirebarStorage", "HirebarTelegram", "HirebarNotifications", "HirebarPortals",
    "HirebarMedia", "HirebarAI",
]

let package = Package(
    name: "Hirebar",
    platforms: [.macOS(.v26)],
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
        .target(name: "HirebarMedia", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .target(name: "HirebarAI", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .executableTarget(name: "Hirebar", dependencies: adapters, swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "HirebarDomainTests", dependencies: ["HirebarDomain"]),
        .testTarget(name: "HirebarApplicationTests", dependencies: ["HirebarApplication", "HirebarDomain"]),
        .testTarget(name: "HirebarStorageTests", dependencies: ["HirebarApplication", "HirebarDomain", "HirebarStorage"]),
        .testTarget(name: "HirebarTelegramTests", dependencies: ["HirebarDomain", "HirebarTelegram"]),
        .testTarget(name: "HirebarPortalsTests", dependencies: ["HirebarApplication", "HirebarDomain", "HirebarPortals"]),
        .testTarget(name: "HirebarUseCaseTests", dependencies: adapters),
    ]
)
