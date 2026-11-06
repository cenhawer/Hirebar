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
        .target(name: "HirebarCore"),
        .target(name: "HirebarSources", dependencies: ["HirebarCore"]),
        .target(name: "HirebarEngine", dependencies: ["HirebarCore", "HirebarSources"]),
        .executableTarget(name: "Hirebar", dependencies: ["HirebarCore", "HirebarEngine"]),
        .testTarget(name: "HirebarCoreTests", dependencies: ["HirebarCore"]),
        .testTarget(name: "HirebarSourcesTests", dependencies: ["HirebarCore", "HirebarSources"]),
        .testTarget(name: "HirebarDomainTests", dependencies: ["HirebarDomain"]),
        .testTarget(name: "HirebarApplicationTests", dependencies: ["HirebarApplication", "HirebarDomain"]),
    ]
)
