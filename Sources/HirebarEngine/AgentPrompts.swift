import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum AgentPrompts {
    static func prompt(for batch: Batch, items: [BatchItem], owner: String) -> String {
        let base = basePrompt(for: batch, items: items, owner: owner)
        guard TaskProfiles.profile(for: batch.mode, account: ContentAccountStore.find(batch.account)).canAct else { return base }
        return base + "\n\n" + actionLogSection(for: batch)
    }

    static func pastEmployers(from url: URL = Profile.url) -> [String] {
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let experience = root["experience"] as? [[String: Any]]
        else { return [] }
        return Array(Set(experience.compactMap { $0["company"] as? String }.filter { !$0.isEmpty })).sorted()
    }

    static func achievements(from url: URL = Profile.url) -> [String] {
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let experience = root["experience"] as? [[String: Any]]
        else { return [] }
        return experience.flatMap { job -> [String] in
            let place = [job["role"] as? String, job["company"] as? String].compactMap { $0 }.joined(separator: " en ")
            let items = (job["achievements"] as? [[String: Any]]) ?? []
            return items.compactMap { $0["text"] as? String }.map { "- \($0) (\(place))" }
        }
    }

    static func actionLogSection(for batch: Batch) -> String {
        let approved = ExecutionApprovals.store.approvedItems(batch: batch.id).map { item in
            "- itemId: \(item.proposal.id) · action: \(item.proposal.action.rawValue) · target: \(ExecutionApprovals.targetJSON(item.proposal.target))"
        }.joined(separator: "\n")
        let file = FileExecutionStateStore.actionLogFile(batch: batch.id).lastPathComponent
        return """
            Registro obligatorio de acciones. Solo puedes actuar sobre esta lista aprobada; cualquier otra acción es una \
            violación y pone en pausa al agente:
            \(approved)

            Al terminar, escribe ejecuciones/\(file) con exactamente este formato (fechas ISO 8601):
            {"schemaVersion": 1, "batch": "\(batch.id)", "actions": [
              {"itemId": "<itemId de la lista>", "action": "<action de la lista>", "target": <target de la lista, igual>,
               "sentText": "<el texto que enviaste o publicaste, si hubo>", "outcome": "done | pending | discarded",
               "reason": "<motivo si no quedó done>", "at": "<fecha y hora>"}
            ]}
            Registra todos los elementos de la lista, también los que no enviaste. Copia itemId, action y target tal como \
            aparecen arriba.
            """
    }

    static func approvedEmails(for batch: Batch) -> String {
        ExecutionApprovals.store.approvedItems(batch: batch.id).map { item in
            """
            itemId \(item.proposal.id) · para: \(item.proposal.target.displayText)
            asunto: \(item.proposal.title)
            texto:
            \(item.proposal.text ?? "")
            """
        }.joined(separator: "\n\n")
    }

    static func basePrompt(for batch: Batch, items: [BatchItem], owner: String) -> String {
        let list = items.enumerated().map { index, item in
            "\(index + 1). [\(item.kind)] \(item.platform): \(item.title)\n   \(item.url)\n   \(item.detail)"
        }.joined(separator: "\n")
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let week = Metrics.weekKey()
        let browser = AI.settings.kind.browserHint
        let limit = AgentStore.load(AgentKind.owner(of: batch.mode)).dailyLimit.map { " Cupo diario de este agente: \($0)." } ?? ""
        switch batch.mode {
        case .followUp:
            return """
                Revisión de seguimientos \(batch.id) (\(now), semana \(week)). Revisa seguimiento.json según tus \
                instrucciones. NO envíes nada: propone cada seguimiento y cada respuesta a clientes con su texto en la lista \
                entre \(ProposalParser.beginMarker) y \(ProposalParser.endMarker) al final de tu respuesta; \(owner) los \
                aprueba desde Telegram. Si no hay nada que proponer ni novedades, responde solo \(Controller.noNewsMarker). \(browser)
                """
        case .followUpSend:
            return """
                Envío de seguimientos \(batch.id) (\(now)). \(owner) aprobó desde Telegram estos seguimientos: envíalos YA, \
                cada uno con exactamente el texto aprobado, según tus instrucciones. \(browser)

                \(list)
                """
        case .weeklyReport:
            return """
            Informe semanal \(batch.id) (\(now)). Cierra la semana \(week): analiza las métricas y los registros \
            de cada agente según tus instrucciones y escribe el informe. Solo analizas: no cambies playbooks, \
            perfiles ni configuración, y no propongas cambios automáticos; \(owner) decide qué ajustar.
            """
        case .linkedInDraft:
            let account = ContentAccountStore.find(batch.account) ?? ContentAccountStore.defaultAccount()
            let note = (try? String(contentsOf: account.changes, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            try? FileManager.default.removeItem(at: account.changes)
            let change = note.isEmpty ? "" : "\n\nCambio que pidió \(owner) sobre el borrador anterior: \(note)"
            let review = account.needsPerformanceCheck
                ? "\n\nEsta vez toca revisar el rendimiento de la cuenta (sección 0 de tus instrucciones). \(browser)"
                : ""
            return """
            Contenido \(batch.id) (\(now)). Prepara UNA publicación para esta cuenta según tus instrucciones. \
            NO publiques nada: \(owner) la aprueba primero desde Telegram.\(review)

            \(accountSheet(account))\(change)
            """
        case .prospecting:
            return """
                Prospección \(batch.id) (\(now), semana \(week)). Busca empresas y negocios según tus instrucciones, revisa \
                respuestas y seguimientos pendientes, y deja la lista del día en prospeccion/pendientes.json. NO envíes \
                ningún correo: \(owner) aprueba la lista desde Telegram. \(browser)

                Empresas donde \(owner) ya trabajó (no las incluyas): \(pastEmployers().joined(separator: ", "))

                Resultados reales de \(owner) para los correos (usa solo estos, sin inventar cifras):
                \(achievements().joined(separator: "\n"))
                """
        case .prospectingSend:
            return """
                Envío de prospección \(batch.id) (\(now)). \(owner) aprobó desde Telegram estos correos: envíalos desde su \
                Gmail con exactamente el destinatario, el asunto y el texto de cada uno, según tus instrucciones. \(browser)

                \(approvedEmails(for: batch))
                """
        case .social:
            return """
                Búsqueda en redes \(batch.id) (\(now), semana \(week)). Busca publicaciones de las últimas horas que ofrezcan \
                vacantes o proyectos que encajen con las habilidades de \(owner), según tus instrucciones. NO postules ni \
                escribas a nadie: propone cada hallazgo en la lista entre \(ProposalParser.beginMarker) y \
                \(ProposalParser.endMarker) al final de tu respuesta; \(owner) la aprueba desde Telegram. \(browser) Si no \
                hay nada nuevo, responde solo \(Controller.noNewsMarker).

                Habilidades de \(owner):
                \(Profile.load().summary)
                """
        case .linkedInPublish:
            let account = ContentAccountStore.find(batch.account) ?? ContentAccountStore.defaultAccount()
            return """
            Publicar \(batch.id) (\(now)). \(owner) respondió "publica" en Telegram: publica en \(account.network.title) \
            (cuenta \(account.handle.isEmpty ? account.title : account.handle)) EXACTAMENTE el texto de \
            \(account.relativeFolder)/borrador.md con las imágenes de \(account.relativeFolder)/laminas/ (los .png, en orden), \
            según tus instrucciones. Antes de publicar, revisa que la sesión abierta sea la de esa cuenta. \(browser)
            """
        case .portalScanJobs, .portalScanFreelance:
            let agent: AgentKind = batch.mode == .portalScanJobs ? .jobs : .freelance
            let portals = PortalStore.active(for: agent).enumerated().map { index, portal in
                "\(index + 1). \(portal.name): \(portal.url)" + (portal.notes.isEmpty ? "" : "\n   Indicaciones: \(portal.notes)")
            }.joined(separator: "\n")
            let what = agent == .jobs ? "vacantes" : "proyectos freelance"
            return """
                Revisión de portales \(batch.id) (\(now)). Revisa estos portales que agregó \(owner) y busca \(what) recientes \
                que encajen con sus habilidades, según tus instrucciones. NO postules ni envíes nada: devuelve lo encontrado en \
                la lista entre \(ProposalParser.beginMarker) y \(ProposalParser.endMarker) al final de tu respuesta. Si no hay nada \
                nuevo, responde solo \(Controller.noNewsMarker). \(browser)

                Habilidades de \(owner):
                \(Profile.load().summary)

                \(portals)
                """
        case .profileUpdate:
            let request = (try? String(contentsOf: Paths.workspaceFile(ProfileRequests.fileName), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let what = request.isEmpty ? "No hay cambios nuevos: solo regenera las hojas de vida." : "Cambios que pidió \(owner):\n\(request)"
            return """
            Actualizar perfil \(batch.id) (\(now)). Actualiza perfil.json y perfil.md y regenera las hojas de vida en HTML \
            según tus instrucciones. No necesitas el navegador.

            \(what)
            """
        case .jobs:
            return """
            Lote \(batch.id) (\(now)). \(owner) respondió SÍ desde Telegram: postúlalo YA a estas vacantes, \
            sin pedirle más confirmación, siguiendo tus instrucciones (perfil.md y las reglas de empleo). \(browser)\(limit)

            \(list)
            """
        case .freelance:
            return """
            Lote \(batch.id) (\(now)). \(owner) respondió SÍ desde Telegram: analiza la competencia, redacta y ENVÍA YA \
            la propuesta de cada uno de estos proyectos, sin pedirle más confirmación, siguiendo tus instrucciones \
            (perfil.md y las reglas de propuestas). \(browser)\(limit)

            \(list)
            """
        }
    }

    /// Ficha de la cuenta de contenido que va en el mensaje a la IA.
    static func accountSheet(_ account: ContentAccount) -> String {
        let p = account.palette
        let name = account.name.trimmingCharacters(in: .whitespaces)
        return """
        Cuenta: \(account.id)
        Carpeta: \(account.relativeFolder)/ (borrador.md, laminas/, temas.md)
        Red: \(account.network.title)
        Nombre que firma las imágenes: \(name.isEmpty ? "(sin nombre: no pongas firma)" : name)
        Línea bajo el nombre: \(account.tagline.isEmpty ? "(ninguna)" : account.tagline)
        Usuario: \(account.handle.isEmpty ? "(ninguno)" : account.handle)
        De qué habla y para quién: \(account.focus)
        Paleta: fondo \(p.background), superficie \(p.surface), acento \(p.accent), texto \(p.text), texto secundario \(p.muted)
        Estilo de las imágenes: \(account.style)
        Video corto: \(account.video ? "SÍ. Además del carrusel, prepara un Short que la persona narra con su voz (sección 5 de tus instrucciones) en \(account.relativeFolder)/video/. Es un video ANIMADO e independiente, pensado para ganar audiencia, NO una copia del carrusel. Subtítulos de Hirebar: \(account.captions ? "sí (deja libre su franja)" : "no (el texto clave va animado dentro de cada escena)")." : "no")
        """
    }

    static func statusText(for mode: Mode, count: Int, since hour: String) -> String {
        switch mode {
        case .followUp: return "revisando seguimientos (desde \(hour))"
        case .followUpSend: return "enviando \(count) seguimientos aprobados (desde \(hour))"
        case .weeklyReport: return "armando el informe semanal (desde \(hour))"
        case .prospecting: return "buscando empresas y negocios (desde \(hour))"
        case .prospectingSend: return "enviando correos aprobados (desde \(hour))"
        case .social: return "buscando en redes (desde \(hour))"
        case .linkedInDraft: return "preparando una publicación con imágenes (desde \(hour))"
        case .linkedInPublish: return "publicando en redes (desde \(hour))"
        case .jobs: return "haciendo \(count) postulaciones (desde \(hour))"
        case .freelance: return "haciendo \(count) propuestas (desde \(hour))"
        case .profileUpdate: return "actualizando tu perfil y hojas de vida (desde \(hour))"
        case .portalScanJobs: return "revisando tus portales de empleo (desde \(hour))"
        case .portalScanFreelance: return "revisando tus portales freelance (desde \(hour))"
        }
    }
}
