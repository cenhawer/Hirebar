import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain
import HirebarSources

private let log = Log(.portals)

public final class FreelanceRadar: Radar {
    public static let shared = FreelanceRadar()
    static let maxPerBatch = 5

    private init() {
        super.init(firstDelay: 60, seenKey: "radar.seen", seenDays: 14)
    }

    override var intervalMinutes: Int { AgentStore.load(.freelance).searchEveryMinutes ?? Config.load().freelanceMinutes }

    public override func checkNow() {
        let config = Config.load()
        guard config.freelanceOn, AgentStore.load(.freelance).enabled else {
            setStatus("apagado")
            return
        }
        let active = Catalog.freelance.filter { config.isEnabled($0.id) && !Quotas.exhausted($0.id) }
        guard !active.isEmpty else {
            setStatus("sin contactos ni ofertas hasta que se renueven")
            return
        }
        guard beginCheck() else { return }
        let skipped = Catalog.freelance
            .filter { config.isEnabled($0.id) && Quotas.exhausted($0.id) }
            .map { "\($0.name) sin cupos" }
        let skip = Set(seen().keys)
        let profile = SearchProfile.loadEffective()
        Task {
            var found: [Hit] = []
            for source in active {
                found += await source.search(skip: skip, profile: profile).hits
            }
            let hits = found
            let note = skipped.joined(separator: ", ")
            await MainActor.run { self.finish(hits, note: note) }
        }
    }

    private func finish(_ found: [Hit], note: String) {
        checking = false
        let pool = found.filter { $0.fit == .strong || $0.fit == .stretch }.sorted(by: Hit.ranked)
        var room: [String: Int] = [:]
        for source in Catalog.freelance {
            if let left = Quotas.remaining(source.id) { room[source.name] = left }
        }
        var hits: [Hit] = []
        for hit in pool where hits.count < Self.maxPerBatch {
            if let left = room[hit.platform] {
                if left <= 0 { continue }
                room[hit.platform] = left - 1
            }
            hits.append(hit)
        }
        remember(found + hits)

        let hour = TextTools.shortTime()
        let suffix = note.isEmpty ? "" : " (\(note))"
        guard !hits.isEmpty else {
            setStatus("\(hour), nada nuevo\(suffix)")
            log.write("Freelance: nada nuevo\(suffix)")
            return
        }
        setStatus("\(hour), \(hits.count) avisado(s)\(suffix)")
        Metrics.bump(.freelance, "avisados", hits.count)
        Metrics.bump(.freelance, "avisados_reto", hits.filter { $0.fit == .stretch }.count)
        log.write("Freelance: \(hits.count) proyecto(s) avisado(s)")

        let batch = Batch(mode: .freelance, items: hits.map(BatchItem.init), status: .pending)
        BatchStore.upsert(batch)
        let auto = AgentStore.load(.freelance).autoApprove
        let title = "Radar freelance: \(hits.count) proyecto(s) para ti" + (auto ? " (envío automático)" : "")
        let footer = auto
            ? "Cupos: \(Quotas.summary())\n\n\(AI.capitalizedName) ya está analizando y enviando las propuestas; te aviso al terminar."
            : "Cupos: \(Quotas.summary())\n\nResponde \"si\" y \(AI.name) analiza la competencia, redacta y envía las propuestas. \"si 1 3\" para elegir, \"no\" para descartar."
        Notifier.announce(batch, title: title, footer: footer)
        if auto {
            DispatchQueue.main.async { Controller.shared.autoApprove(BatchStore.find(id: batch.id) ?? batch) }
        }
    }
}
