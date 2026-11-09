// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hirebar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hirebar", targets: ["Hirebar"]),
    ],
    targets: [
        .target(name: "HirebarDomain"),
        .target(name: "HirebarApplication", dependencies: ["HirebarDomain"]),
        .target(name: "HirebarCore", dependencies: ["HirebarDomain", "HirebarApplication"]),
        .target(name: "HirebarSources", dependencies: ["HirebarCore"]),
        .target(name: "HirebarEngine", dependencies: ["HirebarApplication", "HirebarCore", "HirebarDomain", "HirebarSources"]),
        .executableTarget(name: "Hirebar", dependencies: ["HirebarApplication", "HirebarCore", "HirebarDomain", "HirebarEngine"]),
        .testTarget(name: "HirebarCoreTests", dependencies: ["HirebarApplication", "HirebarCore", "HirebarDomain"]),
        .testTarget(name: "HirebarSourcesTests", dependencies: ["HirebarCore", "HirebarSources"]),
        .testTarget(name: "HirebarDomainTests", dependencies: ["HirebarDomain"]),
        .testTarget(name: "HirebarApplicationTests", dependencies: ["HirebarApplication", "HirebarDomain"]),
        .testTarget(name: "HirebarEngineTests", dependencies: ["HirebarApplication", "HirebarCore", "HirebarEngine"]),
    ]
)
