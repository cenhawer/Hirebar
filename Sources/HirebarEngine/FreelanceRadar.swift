import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

private let log = Log(.portals)

public final class FreelanceRadar: Radar {
    weak var controller: Controller?
    static let maxPerBatch = 5

    let stores: Repositories

    public init(stores: Repositories) {
        self.stores = stores
        super.init(firstDelay: 60, seenKey: "radar.seen", seenDays: 14)
    }

    override var intervalMinutes: Int { stores.agents.load(.freelance).searchEveryMinutes ?? stores.config.load().freelanceMinutes }

    public override func checkNow() {
        let config = stores.config.load()
        guard config.freelanceOn, stores.agents.load(.freelance).enabled else {
            setStatus("apagado")
            return
        }
        let active = Catalog.freelance.filter { config.isEnabled($0.id) && !stores.quotas.exhausted($0.id) }
        guard !active.isEmpty else {
            setStatus("sin contactos ni ofertas hasta que se renueven")
            return
        }
        guard beginCheck() else { return }
        let skipped = Catalog.freelance
            .filter { config.isEnabled($0.id) && stores.quotas.exhausted($0.id) }
            .map { "\($0.name) sin cupos" }
        let skip = Set(seen().keys)
        let profile = stores.profile.effectiveSearch()
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
            if let left = stores.quotas.remaining(source.id) { room[source.name] = left }
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
        stores.metrics.bump(.freelance, "avisados", hits.count)
        stores.metrics.bump(.freelance, "avisados_reto", hits.filter { $0.fit == .stretch }.count)
        log.write("Freelance: \(hits.count) proyecto(s) avisado(s)")

        let batch = Batch(mode: .freelance, items: hits.map(BatchItem.init), status: .pending)
        stores.batches.upsert(batch)
        let auto = stores.agents.load(.freelance).autoApprove
        let title = "Radar freelance: \(hits.count) proyecto(s) para ti" + (auto ? " (envío automático)" : "")
        let ai = controller?.ai ?? AI(settings: stores.config.load().aiEngine)
        let quotas = "Cupos: \(stores.quotas.summary())\n\n"
        let footer =
            auto
            ? quotas + "\(ai.capitalizedName) ya está analizando y enviando las propuestas; te aviso al terminar."
            : quotas + "Responde \"si\" y \(ai.name) analiza la competencia, redacta y envía las propuestas. "
                + "\"si 1 3\" para elegir, \"no\" para descartar."
        controller?.notifier.announce(batch, title: title, footer: footer)
        if auto {
            DispatchQueue.main.async { self.controller?.autoApprove(self.stores.batches.find(id: batch.id) ?? batch) }
        }
    }
}
