import HirebarApplication
import HirebarCore
import HirebarDomain

enum TaskProfiles {
    static func profile(for mode: Mode, account: ContentAccount?) -> RunProfile {
        switch mode {
        case .social, .portalScanJobs, .portalScanFreelance:
            return .read
        case .followUp:
            return .draft(writablePaths: ["seguimiento.json"])
        case .prospecting:
            return .draft(writablePaths: ["prospeccion/"])
        case .linkedInDraft:
            return .draft(writablePaths: [(account ?? ContentAccountStore.defaultAccount()).relativeFolder + "/"])
        case .profileUpdate:
            return .draft(writablePaths: ["perfil.json", "perfil.md", "hv/"])
        case .weeklyReport:
            return .draft(writablePaths: ["informes/"])
        case .jobs, .freelance, .followUpSend, .prospectingSend, .linkedInPublish:
            return .act
        }
    }

    static func allowedProposals(for mode: Mode) -> Set<ActionKind> {
        switch mode {
        case .portalScanJobs: return [.apply]
        case .portalScanFreelance: return [.sendProposal]
        case .social: return [.apply, .draftEmail]
        case .followUp: return [.sendFollowUp, .replyToClient]
        case .prospecting: return [.sendEmail, .sendFollowUp, .replyToClient]
        case .jobs, .freelance, .followUpSend, .prospectingSend, .linkedInDraft, .linkedInPublish, .profileUpdate, .weeklyReport: return []
        }
    }

    static func executionMode(for mode: Mode) -> Mode? {
        switch mode {
        case .portalScanJobs, .social: return .jobs
        case .portalScanFreelance: return .freelance
        case .followUp: return .followUpSend
        case .prospecting, .jobs, .freelance, .followUpSend, .prospectingSend, .linkedInDraft, .linkedInPublish, .profileUpdate,
            .weeklyReport:
            return nil
        }
    }

    static func needsBrowser(_ mode: Mode, account: ContentAccount?) -> Bool {
        switch mode {
        case .linkedInDraft:
            return account?.needsPerformanceCheck ?? false
        case .profileUpdate, .weeklyReport:
            return false
        case .social, .portalScanJobs, .portalScanFreelance, .followUp, .prospecting, .jobs, .freelance, .followUpSend,
            .prospectingSend, .linkedInPublish:
            return true
        }
    }
}
