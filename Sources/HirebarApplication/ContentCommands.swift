import Foundation
import HirebarDomain

private let log = Log(.telegram)

extension Controller {
    enum AccountLookup {
        case found(ContentAccount)
        case problem(String)
    }

    func draftAccount(named word: String?, verb: String, suffix: String = "") -> AccountLookup {
        if let word, let account = stores.contentAccounts.match(word) {
            let missing = String(
                localized: "\(account.title) no tiene publicación pendiente. Escribe \"post \(account.id)\" para armar una.")
            return stores.contentAccounts.hasDraft(account) ? .found(account) : .problem(missing)
        }
        let pending = stores.contentAccounts.load().filter { stores.contentAccounts.hasDraft($0) }
        switch pending.count {
        case 0: return .problem(String(localized: "No tengo publicaciones pendientes. Escribe \"post\" para que arme una."))
        case 1: return .found(pending[0])
        default:
            let names = pending.map { "\(verb) \($0.id)\(suffix)" }.joined(separator: " · ")
            return .problem(String(localized: "Hay publicaciones pendientes en varias cuentas. Dime cuál: \(names)"))
        }
    }

    func rebuildVideo(_ word: String?) {
        let withScenes = stores.contentAccounts.load().filter(stores.contentAccounts.hasVideoScript)
        let account: ContentAccount
        if let word, let named = stores.contentAccounts.match(word) {
            account = named
        } else if withScenes.count == 1 {
            account = withScenes[0]
        } else if withScenes.isEmpty {
            reply(
                String(
                    localized: """
                        No hay escenas de video guardadas. Escribe \"post <cuenta>\" con el video prendido en esa \
                        cuenta.
                        """))
            return
        } else {
            reply(String(localized: "¿De cuál cuenta? ") + withScenes.map { "video \($0.id)" }.joined(separator: " · "))
            return
        }
        reply(String(localized: "Armando la vista previa del video de \(account.title); tarda unos minutos."))
        media.renderVideoPreview(for: account) { [weak self] video, problem in
            let sendScript = {
                if let script = self?.media.readingScript(for: account) {
                    self?.stores.runState.setWaitingVoiceAccount(account.id)
                    self?.reply(script)
                }
            }
            guard let video else {
                self?.reply(String(localized: "No salió la vista previa: \(problem ?? String(localized: "sin detalle"))."))
                sendScript()
                return
            }
            self?.notifier.sendVideo(video, caption: String(localized: "\(account.title): vista previa del video, sin voz")) {
                sendScript()
            }
        }
    }

    func remakeWithLastRecording(_ word: String?) {
        let accounts = stores.contentAccounts.load()
        let waiting = stores.contentAccounts.find(stores.runState.waitingVoiceAccount())
        guard let account = word.flatMap(stores.contentAccounts.match) ?? waiting ?? accounts.first(where: \.video) else {
            reply(String(localized: "No sé de qué cuenta. Escribe: rearmar <cuenta>"))
            return
        }
        guard let recording = stores.contentAccounts.latestRecording(account) else {
            reply(String(localized: "No tengo una nota de voz guardada de \(account.title). Mándame una leyendo el guion."))
            return
        }
        reply(String(localized: "Rehaciendo el video de \(account.title) con tu última nota de voz; tarda unos minutos."))
        deliverVoiced(account, recording: recording)
    }

    func deliverVoiced(_ account: ContentAccount, recording: URL) {
        media.renderVideoWithVoice(for: account, recording: recording) { [weak self] video, problem in
            guard let video else {
                self?.reply(
                    String(
                        localized:
                            """
                            No pude armar el video con tu voz: \(problem ?? String(localized: "sin detalle")). Puedes \
                            mandar el audio otra vez.
                            """
                    ))
                return
            }
            self?.notifier.sendVideo(video, caption: String(localized: "\(account.title): video con tu voz, listo para subir")) {
                if let text = self?.stores.contentAccounts.videoDescription(account) {
                    self?.reply(String(localized: "Descripción del video de \(account.title), lista para copiar:\n\n\(text)"))
                }
                let several = (self?.stores.contentAccounts.load().count ?? 0) > 1
                self?.reply(
                    String(
                        localized:
                            """
                            ¿Lo subo? Responde \"\(several ? "publica \(account.id)" : "publica")\" para subir el carrusel \
                            y este video.\u{20}
                            """)
                        + String(localized: "Si quieres repetir la grabación, manda otra nota de voz."))
            }
        }
    }

    func audioProblem(bytes: Int?, seconds: Int?) -> String? {
        switch media.audioCheck(bytes: bytes, seconds: seconds) {
        case .accepted:
            return nil
        case .toolsMissing:
            return String(localized: "Falta herramientas.json dentro de la app; vuelve a instalarla con scripts/bundle.sh --install.")
        case .ffmpegMissing(let install):
            return String(
                localized: "Para armar el video con tu voz falta ffmpeg en el Mac. Instálalo con \(install) y vuelve a mandar el audio.")
        case .tooLong(let minutes, let megabytes):
            return String(localized: "Ese audio es muy largo: el máximo es \(minutes) minutos o \(megabytes) MB. Graba uno más corto.")
        }
    }

    func handleRecording(fileId: String, ext: String, size: (bytes: Int?, seconds: Int?) = (nil, nil)) {
        if let problem = audioProblem(bytes: size.bytes, seconds: size.seconds) {
            reply(problem)
            return
        }
        let waiting = stores.runState.waitingVoiceAccount()
        let candidates = stores.contentAccounts.load().filter { $0.video && stores.contentAccounts.hasVideoScript($0) }
        guard let account = stores.contentAccounts.find(waiting) ?? candidates.first else {
            reply(
                String(
                    localized: "Recibí tu audio, pero no tengo ningún video esperando voz. Escribe \"post <cuenta>\" con el video prendido."
                ))
            return
        }
        reply(String(localized: "Recibí tu audio. Armo el video de \(account.title) con tu voz; tarda unos minutos."))
        let file = account.videoFolder.appendingPathComponent("grabacion.\(ext)")
        let limit = media.maxAudioBytes()
        let chat = chat
        Task { [weak self] in
            let downloaded = await Task.detached(priority: .userInitiated) {
                chat.download(fileId: fileId, to: file, maxBytes: limit)
            }.value
            guard downloaded else {
                self?.reply(String(localized: "No pude descargar tu audio de Telegram. Mándalo otra vez."))
                return
            }
            self?.deliverVoiced(account, recording: file)
        }
    }

    func handlePost(_ rest: String) {
        var parts = rest.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 2).map(String.init)
        var named: ContentAccount?
        if let first = parts.first, let account = stores.contentAccounts.match(first) {
            named = account
            parts.removeFirst()
        }
        let sub = parts.first?.lowercased() ?? ""
        stores.workspace.prepare()
        guard sub == "salta" || sub == "no" || sub == "cambia" else {
            runScheduled(.linkedInDraft, manual: true, account: named?.id)
            return
        }
        let account: ContentAccount
        switch draftAccount(named: named?.id, verb: "post", suffix: sub == "cambia" ? String(localized: " cambia <qué>") : " salta") {
        case .found(let found): account = found
        case .problem(let text):
            reply(text)
            return
        }
        if sub == "cambia" {
            let note = parts.dropFirst().joined(separator: " ")
            stores.contentAccounts.requestChange(account, note)
            runScheduled(.linkedInDraft, manual: true, account: account.id)
            return
        }
        stores.contentAccounts.discardDraft(account, at: Date())
        reply(String(localized: "Listo, no se publica en \(account.title). Escribe \"post \(account.id)\" cuando quieras otra."))
    }
}
