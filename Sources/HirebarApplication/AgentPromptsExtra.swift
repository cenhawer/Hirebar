import Foundation
import HirebarDomain

extension AgentPrompts {
    func reviewPrompt(for mode: Mode, proposals: [Proposal], owner: String) -> String {
        """
        Revisión del borrador de \(owner) para \(mode.title.lowercased()). Otro proceso de IA redactó esta lista; revísala \
        contra el perfil de \(owner) y lo que cada vacante, proyecto o hilo original pide (título y fuente de cada \
        elemento). Si una afirmación no está respaldada por el perfil, quítala; no inventes un dato nuevo para \
        justificarla. Si el texto está bien, devuélvelo exactamente igual. No envíes, publiques ni postules nada: solo \
        responde con la lista final en el mismo formato, entre \(ProposalParser.beginMarker) y \(ProposalParser.endMarker).

        \(ProposalParser.encodeBlock(proposals))
        """
    }

    func interviewPrepPrompt(_ context: AgentPrompts.PromptContext) -> String {
        let batch = context.batch
        let owner = context.owner
        let browser = context.browser
        return """
            Preparación de entrevista \(batch.id). \(owner) va a entrevistarse por esta postulación:

            \(context.list)

            Escribe entrevistas/\(batch.id).md con: un resumen de la vacante y la empresa, preguntas probables agrupadas \
            por tipo (técnicas, de experiencia, culturales), y los puntos del perfil de \(owner) que más conectan con lo \
            que pide esa vacante. Si revisas información pública de la empresa y no encuentras nada, dilo en esa sección \
            en vez de inventar datos; nunca inventes datos sobre la empresa o la vacante. \(browser)

            NO postules, envíes ni comentes nada. Al terminar, responde solo con un resumen corto: de qué vacante es y \
            cuántas preguntas trae el documento.

            Perfil de \(owner):
            \(stores.profile.load().summary)
            """
    }
}
