import Foundation
import HirebarDomain

private let log = Log(.telegram)

extension Controller {
    func requestProfileChange(_ kind: String, _ text: String, example: String) {
        guard !text.isEmpty else {
            reply("Escribe el detalle, por ejemplo: \(example)")
            return
        }
        stores.profile.appendChangeRequest(kind, text, at: Date())
        runScheduled(.profileUpdate, manual: true)
    }

    func handleSkill(_ text: String) {
        var parts = text.split(separator: " ").map(String.init)
        guard parts.count >= 2, let level = SkillLevel.parse(parts.removeLast()) else {
            if !text.isEmpty, let skill = stores.profile.load().skill(named: text) {
                reply("\(skill.name): \(skill.level.rawValue)")
            } else {
                reply("Escribe: habilidad <nombre> <domino|conozco|evito>, por ejemplo: habilidad Go conozco")
            }
            return
        }
        let name = parts.joined(separator: " ")
        switch stores.profile.setSkill(name, level: level) {
        case .added:
            reply("Agregué \(name) como \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .updated(let from):
            reply("\(name): \(from.rawValue) → \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .unchanged:
            reply("\(name) ya estaba como \(level.rawValue).")
        case .failed(let reason):
            reply("No pude cambiar la habilidad: \(reason)")
        }
    }

    func latestPendingEmails() -> Batch? {
        let since = Date().addingTimeInterval(-24 * 3600)
        return stores.batches.load().filter { $0.mode == .prospectingSend && $0.status == .pending && $0.created > since }
            .max { $0.created < $1.created }
    }

    func discardList(_ found: Batch?) {
        discard(found, chatId: stores.config.load().chatId)
        guard found?.status == .pending, found?.mode == .prospectingSend else { return }
        stores.prospecting.discardPendingEmails(at: Date())
    }

    func discard(_ found: Batch?, chatId: Int64) {
        guard var target = found, target.status == .pending else {
            reply("No tengo listas pendientes.")
            return
        }
        target.status = .discarded
        stores.batches.upsert(target)
        stores.metrics.bump(target.mode, "listas_descartadas")
        if let id = target.messageId { chat.removeButtons(chatId: chatId, messageId: id) }
        reply("Descartada. Sigo buscando.")
    }

    nonisolated static let autoSendOrigin = "Telegram"

    func handleAuto(_ rest: [String]) {
        let named = rest.count > 1 ? stores.agents.parse(rest.dropLast().joined(separator: " ")) : nil
        let targets: [AgentKind] = (named.map { [$0] } ?? [.jobs, .freelance]).filter(AutoSend.agents.contains)
        if let value = rest.last, ["si", "on"].contains(value) {
            let pending = targets.filter { !stores.agents.load($0).autoApprove }
            if !pending.isEmpty {
                askToTurnOnAutoSend(pending)
                return
            }
        }
        if let value = rest.last, ["no", "off"].contains(value) {
            for kind in targets { AutoSend.turnOff(kind, from: Self.autoSendOrigin, agents: stores.agents) }
        }
        let lines = [AgentKind.jobs, .freelance, .clients].map { kind -> String in
            let agent = stores.agents.load(kind)
            return "\(agent.name): \(agent.autoApprove ? "SÍ" : "no")"
        }
        reply(
            "Envío automático · " + lines.joined(separator: " · ")
                + "\nCambiar: \"auto si\", \"auto no\", \"auto empleo no\", \"auto clientes si\".")
    }

    func askToTurnOnAutoSend(_ kinds: [AgentKind]) {
        let names = kinds.map(\.rawValue).joined(separator: ",")
        askPerson(
            AutoSend.explanation(for: kinds, agents: stores.agents) + "\n\n¿Lo prendo?",
            buttons: [[("Sí, prender", "autoon:\(names)"), ("No", "autocancel:\(names)")]])
    }

    func confirmAutoSend(_ names: String) {
        let kinds = names.split(separator: ",").compactMap { AgentKind(rawValue: String($0)) }.filter(AutoSend.agents.contains)
        guard !kinds.isEmpty else { return }
        for kind in kinds { AutoSend.turnOn(kind, from: Self.autoSendOrigin, agents: stores.agents) }
        reply("Envío automático prendido: " + kinds.map { stores.agents.load($0).name }.joined(separator: ", ") + ".")
    }

    func handleAgentSwitch(_ rest: [String]) {
        let named = stores.agents.parse(rest.dropLast().joined(separator: " "))
        guard let value = rest.last, ["on", "off", "si", "no"].contains(value), let kind = named else {
            reply("Escribe: agente <nombre> on / off, por ejemplo: agente clientes off")
            return
        }
        let on = value == "on" || value == "si"
        stores.agents.update(kind) { $0.enabled = on }
        reply("\(stores.agents.load(kind).name): \(on ? "prendido" : "apagado").")
    }

    func handleRunNow(_ name: String) {
        guard let kind = stores.agents.parse(name) else {
            reply("Escribe: corre <empleo | freelance | clientes | contenido | perfil | analista>")
            return
        }
        runAgentNow(kind)
    }

    public func runAgentNow(_ kind: AgentKind) {
        let agent = stores.agents.load(kind)
        switch kind {
        case .jobs: jobRadar?.checkNow()
        case .freelance: freelanceRadar?.checkNow()
        default: break
        }
        if kind == .profile {
            runScheduled(.profileUpdate, manual: true)
        } else {
            for task in agent.tasks { runScheduled(task.mode, manual: true) }
        }
        if agent.tasks.isEmpty && !agent.hasSearch && kind != .profile {
            reply("\(agent.name) no tiene tareas configuradas.")
        } else if agent.hasSearch {
            reply("\(agent.name): buscando ahora.")
        }
    }

    public func agentsReport() -> String {
        stores.agents.all().map { agent in
            var line = "\(agent.name): \(agent.enabled ? "prendido" : "apagado")"
            if agent.enabled {
                if [.jobs, .freelance, .clients].contains(agent.id) { line += " · auto \(agent.autoApprove ? "sí" : "no")" }
                if agent.practice { line += " · en práctica (no envía)" }
                if let next = scheduler?.nextRun(of: agent.id) { line += " · próxima \(TextTools.countdown(next))" }
                if let reason = pauseReason(of: agent.id) { line += " · en pausa: \(reason)" }
            }
            return line
        }.joined(separator: "\n")
    }
}
