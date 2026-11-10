import Foundation
import HirebarDomain

private let log = Log(.portals)

public final class FreelanceRadar: Radar {
    public weak var controller: Controller?

    let stores: Repositories
    let portals: PortalAccess

    let limits: EnginePolicy.FreelanceRadar

    public init(stores: Repositories, clock: Clock, portals: PortalAccess, policy: EnginePolicy) {
        self.stores = stores
        self.portals = portals
        self.limits = policy.radares.freelance
        super.init(
            firstDelay: limits.firstDelay, seenKey: "radar.seen", seenWindow: limits.seenWindow, radars: policy.radares,
            runState: stores.runState, clock: clock)
    }

    override var intervalMinutes: Int { stores.agents.load(.freelance).searchEveryMinutes ?? stores.config.load().freelanceMinutes }

    public override func checkNow() {
        let config = stores.config.load()
        guard config.freelanceOn, stores.agents.load(.freelance).enabled else {
            setStatus(String(localized: "apagado"))
            return
        }
        let active = portals.freelance.filter { config.isEnabled($0.id) && !stores.quotas.exhausted($0.id) }
        guard !active.isEmpty else {
            setStatus(String(localized: "sin contactos ni ofertas hasta que se renueven"))
            return
        }
        guard beginCheck() else { return }
        let skipped = portals.freelance
            .filter { config.isEnabled($0.id) && stores.quotas.exhausted($0.id) }
            .map { String(localized: "\($0.name) sin cupos") }
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
        for source in portals.freelance {
            if let left = stores.quotas.remaining(source.id) { room[source.name] = left }
        }
        var hits: [Hit] = []
        for hit in pool where hits.count < limits.proyectosPorLista {
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
            setStatus(String(localized: "\(hour), nada nuevo\(suffix)"))
            log.write("Freelance: nada nuevo\(suffix)")
            return
        }
        setStatus(String(localized: "\(hour), \(hits.count) avisado(s)\(suffix)"))
        stores.metrics.bump(.freelance, "avisados", hits.count)
        stores.metrics.bump(.freelance, "avisados_reto", hits.filter { $0.fit == .stretch }.count)
        log.write("Freelance: \(hits.count) proyecto(s) avisado(s)")

        let batch = Batch(mode: .freelance, items: hits.map(BatchItem.init), status: .pending)
        stores.batches.upsert(batch)
        let auto = stores.agents.load(.freelance).autoApprove
        let title =
            String(localized: "Radar freelance: \(hits.count) proyecto(s) para ti") + (auto ? String(localized: " (envío automático)") : "")
        let ai = controller?.ai ?? AI(settings: stores.config.load().aiEngine)
        let quotas = String(localized: "Cupos: \(stores.quotas.summary())\n\n")
        let footer =
            auto
            ? quotas + String(localized: "\(ai.capitalizedName) ya está analizando y enviando las propuestas; te aviso al terminar.")
            : quotas + String(localized: "Responde \"si\" y \(ai.name) analiza la competencia, redacta y envía las propuestas. ")
                + String(localized: "\"si 1 3\" para elegir, \"no\" para descartar.")
        controller?.notifier.announce(batch, title: title, footer: footer)
        if auto {
            Task { [weak self] in self?.controller?.autoApprove(self?.stores.batches.find(id: batch.id) ?? batch) }
        }
    }
}
