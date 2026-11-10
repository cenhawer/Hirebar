import Foundation
import HirebarDomain

private let log = Log(.portals)

public final class JobRadar: Radar {
    public weak var controller: Controller?

    let stores: Repositories
    let portals: PortalAccess

    let limits: EnginePolicy.JobRadar

    public init(stores: Repositories, clock: Clock, portals: PortalAccess, policy: EnginePolicy) {
        self.stores = stores
        self.portals = portals
        self.limits = policy.radares.empleo
        super.init(
            firstDelay: limits.firstDelay, seenKey: "jobradar.seen", seenWindow: limits.seenWindow, radars: policy.radares,
            runState: stores.runState, clock: clock)
    }

    override var intervalMinutes: Int { stores.agents.load(.jobs).searchEveryMinutes ?? stores.config.load().jobMinutes }

    public override func checkNow() {
        let config = stores.config.load()
        guard config.jobsOn, stores.agents.load(.jobs).enabled else {
            setStatus(String(localized: "apagado"))
            return
        }
        guard beginCheck() else { return }
        let skip = Set(seen().keys)
        let profile = stores.profile.effectiveSearch()
        let active = portals.jobs.filter { config.isEnabled($0.id) }
        Task {
            var found: [Hit] = []
            for source in active {
                found += await source.search(skip: skip, profile: profile).hits
            }
            let refined = await Self.refine(found, profile: profile.jobs, portals: self.portals, reviewed: self.limits.revisadasPorBusqueda)
            await MainActor.run { self.finish(refined.kept, examined: refined.examined) }
        }
    }

    static func refine(_ hits: [Hit], profile: JobProfile, portals: PortalAccess, reviewed: Int) async -> (kept: [Hit], examined: [Hit]) {
        var unique: [String: Hit] = [:]
        for hit in hits where unique[hit.id] == nil { unique[hit.id] = hit }
        let examined = Array(unique.values.sorted(by: Hit.ranked).prefix(reviewed))
        var kept: [Hit] = []
        for hit in examined {
            guard let source = portals.jobs.first(where: { $0.owns(hit) }) else { continue }
            guard case .read(let address) = source.descriptionCheck(for: hit) else {
                kept.append(hit)
                continue
            }
            guard let page = await portals.fetcher.text(address), let text = source.descriptionText(from: page) else {
                await portals.fetcher.pause(1)
                continue
            }
            if let reason = source.staleReason(page: page) {
                log.write("Empleo: descartada \(hit.platform) · \(hit.title): \(reason)")
                await portals.fetcher.pause(1)
                continue
            }
            let verdict = JobScreener.screen(
                text, location: source.location(from: page),
                requireRemote: source.requiresRemoteInDescription, profile: profile)
            switch verdict {
            case .reject(let reason):
                log.write("Empleo: descartada \(hit.platform) · \(hit.title): \(reason)")
            case .keep(let fit):
                let final: Fit = (hit.fit == .stretch || fit == .stretch) ? .stretch : .strong
                kept.append(hit.with(fit: final, detail: hit.detail + String(localized: " · descripción revisada")))
            }
            await portals.fetcher.pause(1.2)
        }
        return (kept, examined)
    }

    private func finish(_ found: [Hit], examined: [Hit]) {
        checking = false
        var unique: [String: Hit] = [:]
        for hit in found where unique[hit.id] == nil { unique[hit.id] = hit }
        let sorted = unique.values.sorted(by: Hit.ranked)
        let fits = sorted.filter { $0.fit == .strong }
        let hits = fits.isEmpty ? Array(sorted.prefix(limits.retoPorLista)) : Array(fits.prefix(limits.fuertesPorLista))
        remember(examined)

        let hour = TextTools.shortTime()
        guard !hits.isEmpty else {
            setStatus(String(localized: "\(hour), nada nuevo"))
            log.write("Empleo: nada nuevo")
            return
        }
        setStatus(String(localized: "\(hour), \(hits.count) avisada(s)"))
        stores.metrics.bump(.jobs, "avisados", hits.count)
        stores.metrics.bump(.jobs, "avisados_reto", hits.filter { $0.fit == .stretch }.count)
        log.write("Empleo: \(hits.count) vacante(s) avisada(s)")
        let batch = Batch(mode: .jobs, items: hits.map(BatchItem.init), status: .pending)
        stores.batches.upsert(batch)
        let title =
            fits.isEmpty
            ? String(localized: "Radar empleo: nada de tu fuerte esta hora, pero hay \(hits.count) vacante(s) RETO")
            : String(localized: "Radar empleo: \(hits.count) vacante(s) para ti")
        let auto = stores.agents.load(.jobs).autoApprove
        let ai = controller?.ai ?? AI(settings: stores.config.load().aiEngine)
        let automatic = String(localized: "\(ai.capitalizedName) ya está revisando cada vacante y postulándote; te aviso al terminar.")
        let manual =
            String(localized: "Responde \"si\" y \(ai.name) revisa cada vacante, llena el formulario y te postula. ")
            + String(localized: "\"si 1 3\" para elegir, \"no\" para descartar.")
        controller?.notifier.announce(
            batch, title: auto ? title + String(localized: " (postulación automática)") : title, footer: auto ? automatic : manual)
        if auto {
            Task { [weak self] in self?.controller?.autoApprove(self?.stores.batches.find(id: batch.id) ?? batch) }
        }
    }
}
