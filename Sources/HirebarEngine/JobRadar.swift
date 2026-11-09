import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain
import HirebarSources

private let log = Log(.portals)

public final class JobRadar: Radar {
    public static let shared = JobRadar()
    static let maxReviewed = 15
    static let maxStrong = 6
    static let maxStretchOnly = 2

    private init() {
        super.init(firstDelay: 300, seenKey: "jobradar.seen", seenDays: 21)
    }

    override var intervalMinutes: Int { AgentStore.load(.jobs).searchEveryMinutes ?? Config.load().jobMinutes }

    public override func checkNow() {
        let config = Config.load()
        guard config.jobsOn, AgentStore.load(.jobs).enabled else {
            setStatus("apagado")
            return
        }
        guard beginCheck() else { return }
        let skip = Set(seen().keys)
        let profile = SearchProfile.loadEffective()
        let active = Catalog.jobs.filter { config.isEnabled($0.id) }
        Task {
            var found: [Hit] = []
            for source in active {
                found += await source.search(skip: skip, profile: profile).hits
            }
            let refined = await Self.refine(found, profile: profile.jobs)
            await MainActor.run { self.finish(refined.kept, examined: refined.examined) }
        }
    }

    static func refine(_ hits: [Hit], profile: JobProfile) async -> (kept: [Hit], examined: [Hit]) {
        var unique: [String: Hit] = [:]
        for hit in hits where unique[hit.id] == nil { unique[hit.id] = hit }
        let examined = Array(unique.values.sorted(by: Hit.ranked).prefix(maxReviewed))
        var kept: [Hit] = []
        for hit in examined {
            guard let source = Catalog.jobs.first(where: { $0.owns(hit) }) else { continue }
            guard case .read(let address) = source.descriptionCheck(for: hit) else {
                kept.append(hit)
                continue
            }
            guard let page = await Net.fetchText(address), let text = source.descriptionText(from: page) else {
                await Net.pause(1)
                continue
            }
            if let reason = source.staleReason(page: page) {
                log.write("Empleo: descartada \(hit.platform) · \(hit.title): \(reason)")
                await Net.pause(1)
                continue
            }
            let verdict = JobScreener.screen(text, location: source.location(from: page),
                                             requireRemote: source.requiresRemoteInDescription, profile: profile)
            switch verdict {
            case .reject(let reason):
                log.write("Empleo: descartada \(hit.platform) · \(hit.title): \(reason)")
            case .keep(let fit):
                let final: Fit = (hit.fit == .stretch || fit == .stretch) ? .stretch : .strong
                kept.append(hit.with(fit: final, detail: hit.detail + " · descripción revisada"))
            }
            await Net.pause(1.2)
        }
        return (kept, examined)
    }

    private func finish(_ found: [Hit], examined: [Hit]) {
        checking = false
        var unique: [String: Hit] = [:]
        for hit in found where unique[hit.id] == nil { unique[hit.id] = hit }
        let sorted = unique.values.sorted(by: Hit.ranked)
        let fits = sorted.filter { $0.fit == .strong }
        let hits = fits.isEmpty ? Array(sorted.prefix(Self.maxStretchOnly)) : Array(fits.prefix(Self.maxStrong))
        remember(examined)

        let hour = TextTools.shortTime()
        guard !hits.isEmpty else {
            setStatus("\(hour), nada nuevo")
            log.write("Empleo: nada nuevo")
            return
        }
        setStatus("\(hour), \(hits.count) avisada(s)")
        Metrics.bump(.jobs, "avisados", hits.count)
        Metrics.bump(.jobs, "avisados_reto", hits.filter { $0.fit == .stretch }.count)
        log.write("Empleo: \(hits.count) vacante(s) avisada(s)")
        let batch = Batch(mode: .jobs, items: hits.map(BatchItem.init), status: .pending)
        BatchStore.upsert(batch)
        let title = fits.isEmpty
            ? "Radar empleo: nada de tu fuerte esta hora, pero hay \(hits.count) vacante(s) RETO"
            : "Radar empleo: \(hits.count) vacante(s) para ti"
        let auto = AgentStore.load(.jobs).autoApprove
        Notifier.announce(batch, title: auto ? title + " (postulación automática)" : title,
                          footer: auto
                            ? "\(AI.capitalizedName) ya está revisando cada vacante y postulándote; te aviso al terminar."
                            : "Responde \"si\" y \(AI.name) revisa cada vacante, llena el formulario y te postula. \"si 1 3\" para elegir, \"no\" para descartar.")
        if auto {
            DispatchQueue.main.async { Controller.shared.autoApprove(BatchStore.find(id: batch.id) ?? batch) }
        }
    }
}
