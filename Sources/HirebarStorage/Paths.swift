import CryptoKit
import Foundation
import HirebarApplication
import HirebarDomain

extension Paths {
    public static func ensure() {
        for dir in [root, workspace, runs, reports, prospecting, linkedIn, content, state, backups, logs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static let previousVersions: [String: Set<String>] = [
        "instrucciones-contenido-publicar.md": [
            "c84254fb1ade7117e9289e504c73a1851d07b9912eaf9c6aca9eb170c6b8ae5d",
            "d83f1e8d47fbe59cb06c9e46ffd55282531b6d37b91fbd824159b2a381d63de5",
            "ae157e9663adc871fa26b00ac26c288e1bef5179337958a8f040f9bc0220bae1",
        ],
        "instrucciones-contenido.md": [
            "7d0570183da32781761a75b9ababc55aeaa9984431225a254c776db5ee110bc5",
            "8e4506f6384978408a6401c874ef9f7d6c4c254db55e0bac75cbeeb146b2f1c6",
            "32e5749cf889a58515410d93904e90464474944056d3695cba4f66f88a6c8af2",
            "fe003991a2ae9ea1b25b737cde0fc1a6e1e75bb8213caf2c96f22b4b2ed3e292",
            "db7fa978455f0893a60c0399bc60419a2612fb446b3f73f822a52250afebcb93",
            "e20353453c4f9dea20b3925709b6c762aeddc2c0dfab9c036970ea3f7efec51f",
            "9dcc00aa0e7d6aa9e2fe0fb952dc45291f32fcf4bcb918d45f1c80df702e1430",
            "d15f30cfdb755fd5eb9cc1b9f7329b07c7b0ea057423776c14e66871e5ecb73b",
        ],
        "instrucciones-empleo.md": ["9a5f8307fbae0f8eaf39efdd29a9b0baa6d8cfa91e3f21e0b6baed7bd131df76"],
        "instrucciones-freelance.md": ["87e9d3076ff683fc6a318e4029973eb8facf9193e9b3f98453b227d613fd7ed4"],
        "instrucciones-portales-empleo.md": ["5a6848c1e8abe89bbba134e88702b3408f8ac617c0dda5adcf28335c9ee795ee"],
        "instrucciones-portales-freelance.md": ["ec168296d7802c7ddc4b69a56af3694e3169b11409c5537e193c53b641a67e9e"],
        "instrucciones-prospeccion-envio.md": ["2ca940762ff9cca8f53b38c0790c77344d0dfdf1ba17ff1828810d809bbd72b2"],
        "instrucciones-prospeccion.md": [
            "a6c6ad9fcb07e3a7827594e1e75b75edecd750466e952323a299619fed7be8a2",
            "fccf9290a49de2dbc110609493713e01b8caae38e1b7b48a0863c5917b800a26",
        ],
        "instrucciones-redes.md": ["11ca75e85c7dd4ef18905b1cf168ff7687e470d4e3eb72c479cabbbd223a6990"],
        "instrucciones-seguimiento.md": ["7da33ef4ef15fed7ee3013544cf47503c4844f95f98be857cfded350931e4b4a"],
        "instrucciones-seguimiento-envio.md": ["ce5c95c927cb0572f3f3681bcb7b67f2f03821de76c23763487775a73650e11d"],
    ]

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func installTemplates(from bundled: URL?) {
        guard let bundled else { return }
        ensure()
        let fm = FileManager.default
        let pairs: [(String, URL)] = [
            ("inicial", workspace),
        ]
        for (folder, target) in pairs {
            let source = bundled.appendingPathComponent(folder)
            guard let files = try? fm.contentsOfDirectory(atPath: source.path) else { continue }
            for name in files where !name.hasPrefix(".") {
                let destination = target.appendingPathComponent(name)
                let original = source.appendingPathComponent(name)
                if !fm.fileExists(atPath: destination.path) {
                    try? fm.copyItem(at: original, to: destination)
                } else if let installed = try? Data(contentsOf: destination),
                          let fresh = try? Data(contentsOf: original), installed != fresh,
                          previousVersions[name]?.contains(sha256(installed)) == true {
                    try? fresh.write(to: destination, options: .atomic)
                }
            }
        }
    }
}
