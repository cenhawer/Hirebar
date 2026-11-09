import Foundation

public struct FreelanceProfile: Codable, Sendable {
    public var workanaQueries: [String]
    public var strong: [String]
    public var stretch: [String]
    public var hardBlocked: [String]
    public var stackBlocked: [String]
    public var titleBlocked: [String]
    public var titleNever: [String]
    public var whatsappBotWords: [String]
    public var offProfile: [String]
    public var frontendOnly: [String]
    public var minFixedUSD: Double
    public var minHourlyUSD: Double

    public static let defaults = FreelanceProfile(
        workanaQueries: [
            "category=it-programming", "category=it-programming&page=2",
            "query=api", "query=backend", "query=node", "query=net", "query=java", "query=aws", "query=docker",
            "query=sql", "query=angular", "query=integracion", "query=microservicios", "query=nestjs", "query=spring",
            "query=base%20de%20datos", "query=servidor", "query=migracion",
        ],
        strong: [
            "api", "apis", "rest", "backend", "back end", "node", "nodejs", "node.js", "nest", "nestjs", "nest.js",
            "typescript", ".net", "net core", "asp.net", "c#", "csharp", "java", "spring", "spring boot", "springboot",
            "microservicios", "microservicio", "microservices", "aws", "amazon web services", "ec2", "s3", "docker",
            "kubernetes", "k8s", "ci/cd", "devops", "postgresql", "postgres", "mysql", "sql", "sql server", "mongodb",
            "redis", "kafka", "rabbitmq", "graphql", "angular", "integracion", "integraciones", "integration", "webhook",
            "webhooks", "migracion", "optimizacion", "rendimiento", "performance", "keycloak", "jwt", "base de datos",
            "bases de datos", "database", "vps", "nginx", "linux", "servidor", "escalabilidad",
        ],
        stretch: [
            "python", "fastapi", "django", "flask", "go", "golang", "lambda", "serverless", "api gateway", "terraform",
            "azure", "gcp", "google cloud", "firebase", "supabase", "whatsapp", "chatbot", "bot", "pasarela", "pasarelas",
            "pagos", "stripe", "mercado pago", "mercadopago", "wompi", "paypal", "crm", "openai", "ia",
            "inteligencia artificial", "gpt", "chatgpt", "llm", "n8n", "zapier", "react", "next.js", "nextjs", "vue",
            "scraping", "automatizacion", "automatizaciones", "automation", "power bi", "sap", "odoo",
        ],
        hardBlocked: [
            "wordpress", "woocommerce", "shopify", "wix", "elementor", "solidity", "blockchain", "minecraft", "unity",
            "unreal", "filemaker", "traduccion", "translation", "docente", "tutor", "logo", "logotipo", "diseno grafico",
            "graphic design", "figma", "community manager", "redes sociales", "seo", "edicion de video",
        ],
        stackBlocked: ["php", "laravel"],
        titleBlocked: [
            "android", "ios", "swift", "kotlin", "flutter", "react native", "app movil", "aplicacion movil", "mobile app",
            "video", "data scientist", "ciencia de datos", "certificacion", "certified", "certification", "celular colombiano",
        ],
        titleNever: [
            "bot", "bots", "chatbot", "chatbots", "chat bot", "respuestas automaticas", "respuesta automatica",
            "automatizacion de respuestas", "inteligencia artificial", "ia", "gpt", "chatgpt", "openai", "llm",
            "agente de ia", "agentes de ia", "agente ia", "n8n", "firebase", "landing", "landing page", "pagina web",
            "sitio web", "diseno web", "odoo", "power bi", "tableau", "psicotecnicos",
        ],
        whatsappBotWords: ["respuestas", "automatiz", "asistente", "atencion", "inteligente", "mensajes"],
        offProfile: [
            "data entry", "entrada de datos", "research", "investigacion", "gohighlevel", "ghl", "zoho", "hubspot",
            "catalog", "catalogo", "virtual assistant", "asistente virtual", "copywriting", "redaccion", "marketing",
            "leads", "prospeccion", "ventas", "sales", "compliance", "legal", "contabilidad", "accounting", "excel",
            "google sheets", "tiktok", "instagram", "youtube", "canva", "transcripcion", "embudo", "funnel",
        ],
        frontendOnly: ["react", "next.js", "nextjs"],
        minFixedUSD: 50,
        minHourlyUSD: 12
    )
}

public struct JobProfile: Codable, Sendable {
    public var country: String
    public var homeCity: String
    public var linkedInQueries: [String]
    public var linkedInRegionalQueries: [String]
    public var linkedInContractQueries: [String]
    public var getOnBoardQueries: [String]
    public var computrabajoSlugs: [String]
    public var elempleoQueries: [String]
    public var magnetoRoles: [String]
    public var strong: [String]
    public var generic: [String]
    public var weak: [String]
    public var blocked: [String]
    public var blockedCompanies: [String]
    public var blockedTitleWords: [String]
    public var frontendOnly: [String]
    public var ownStack: [String]
    public var otherStack: [String]
    public var minSalaryCOP: Double
    public var minSalaryUSD: Int
    public var maxYearsRequired: Int
    public var hasProfessionalCard: Bool

    public static let defaults = JobProfile(
        country: "colombia",
        homeCity: "cali",
        linkedInQueries: [
            "nestjs", "desarrollador node.js", "desarrollador .net", "desarrollador backend",
            "desarrollador full stack", "desarrollador typescript", "backend developer", "ingeniero de software",
            "lider tecnico", "tech lead", "desarrollador c#", "asp.net core",
            "microservicios", "desarrollador aws", "desarrollador senior", "desarrollador angular .net",
            "desarrollador python", "desarrollador full stack react node", "desarrollador backend python",
        ],
        linkedInRegionalQueries: [
            "desarrollador backend", "desarrollador node.js", "nestjs", "desarrollador .net",
            "desarrollador c#", "lider tecnico", "desarrollador full stack",
        ],
        linkedInContractQueries: [
            "backend", "node.js", "nestjs", ".net", "java", "aws", "full stack", "freelance desarrollador",
            "desarrollador por proyecto",
        ],
        getOnBoardQueries: [
            "backend", "node", "nestjs", ".net", "c#", "java", "aws", "lider tecnico", "full stack",
            "microservicios", "typescript",
        ],
        computrabajoSlugs: [
            "backend", "desarrollador-backend", "desarrollador-node", "desarrollador-nodejs", "desarrollador-net",
            "desarrollador-de-software", "desarrollador-full-stack", "ingeniero-de-software", "lider-tecnico",
            "desarrollador-net-core", "microservicios", "aws", "desarrollador-angular", "desarrollador-typescript",
        ],
        elempleoQueries: [
            "backend", "nodejs", ".net", "desarrollador de software", "full stack", "ingeniero de software",
            "lider tecnico", "c#", "microservicios", "desarrollador senior",
        ],
        magnetoRoles: [
            "desarrollador-software", "ingeniero-software", "desarrollador-full-stack",
            "ingeniero-desarrollo-software", "desarrollador-web",
        ],
        strong: [
            "node", "nodejs", "node.js", "nest", "nestjs", "typescript", ".net", "net core", "asp.net", "c#",
            "lider tecnico", "tech lead", "technical lead", "team lead",
            "microservicios", "microservices", "java", "spring", "spring boot", "maven", "gradle",
        ],
        generic: [
            "backend", "back end", "back-end", "full stack", "fullstack", "full-stack", "desarrollador de software",
            "ingeniero de software", "software engineer", "software developer", "api", "apis", "integraciones",
            "cloud engineer", "aws", "angular", "desarrollador senior", "ingeniero desarrollador",
            "cloud", "python", "django", "fastapi", "flask",
        ],
        weak: [
            "webflux", "go", "golang", "devops", "sre", "azure", "gcp", "data engineer", "platform engineer",
            "kubernetes", "ingeniero de datos", "scala",
        ],
        blocked: [
            "php", "laravel", "wordpress", "flutter", "android", "ios", "kotlin", "swift", "react native", "data scientist",
            "qa", "tester", "testing", "soporte", "mesa de ayuda", "help desk", "salesforce", "abap", "cobol", "practicante",
            "aprendiz", "pasante", "intern", "junior", "trainee", "ventas", "vendedor", "docente", "profesor", "disenador",
            "ux", "ui designer", "sap", "rpa", "mainframe", "ruby", "staff", "principal", "arquitecto", "arquitecta",
            "architect", "hibrido", "hybrid", "presencial", "desenvolvedor", "pleno",
        ],
        blockedCompanies: ["canonical", "mercado libre", "mercadolibre"],
        blockedTitleWords: ["arquitecto", "arquitecta", "architect", "staff", "principal"],
        frontendOnly: ["react", "react.js", "reactjs", "next.js", "nextjs", "frontend", "front end", "front-end", "vue"],
        ownStack: [
            "node", "nodejs", "node.js", "nestjs", "nest", "typescript", ".net", "c#", "net core",
            "asp.net", "angular", "microservicios", "microservices", "aws", "java", "spring", "maven", "gradle",
        ],
        otherStack: ["webflux", "go", "golang", "php", "ruby", "scala", "kotlin"],
        minSalaryCOP: 5_000_000,
        minSalaryUSD: 1200,
        maxYearsRequired: 5,
        hasProfessionalCard: false
    )
}

public struct SearchProfile: Codable, Sendable {
    public var freelance: FreelanceProfile
    public var jobs: JobProfile

    public static let defaults = SearchProfile(freelance: .defaults, jobs: .defaults)

    public init(freelance: FreelanceProfile, jobs: JobProfile) {
        self.freelance = freelance
        self.jobs = jobs
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(self)
    }
}

extension FreelanceProfile {
    enum CodingKeys: String, CodingKey {
        case workanaQueries, strong, stretch, hardBlocked, stackBlocked, titleBlocked, titleNever
        case whatsappBotWords, offProfile, frontendOnly, minFixedUSD, minHourlyUSD
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FreelanceProfile.defaults
        workanaQueries = try c.decodeIfPresent([String].self, forKey: .workanaQueries) ?? d.workanaQueries
        strong = try c.decodeIfPresent([String].self, forKey: .strong) ?? d.strong
        stretch = try c.decodeIfPresent([String].self, forKey: .stretch) ?? d.stretch
        hardBlocked = try c.decodeIfPresent([String].self, forKey: .hardBlocked) ?? d.hardBlocked
        stackBlocked = try c.decodeIfPresent([String].self, forKey: .stackBlocked) ?? d.stackBlocked
        titleBlocked = try c.decodeIfPresent([String].self, forKey: .titleBlocked) ?? d.titleBlocked
        titleNever = try c.decodeIfPresent([String].self, forKey: .titleNever) ?? d.titleNever
        whatsappBotWords = try c.decodeIfPresent([String].self, forKey: .whatsappBotWords) ?? d.whatsappBotWords
        offProfile = try c.decodeIfPresent([String].self, forKey: .offProfile) ?? d.offProfile
        frontendOnly = try c.decodeIfPresent([String].self, forKey: .frontendOnly) ?? d.frontendOnly
        minFixedUSD = try c.decodeIfPresent(Double.self, forKey: .minFixedUSD) ?? d.minFixedUSD
        minHourlyUSD = try c.decodeIfPresent(Double.self, forKey: .minHourlyUSD) ?? d.minHourlyUSD
    }
}

extension JobProfile {
    enum CodingKeys: String, CodingKey {
        case country, homeCity, linkedInQueries, linkedInRegionalQueries, linkedInContractQueries
        case getOnBoardQueries, computrabajoSlugs, elempleoQueries, magnetoRoles
        case strong, generic, weak, blocked, blockedCompanies, blockedTitleWords, frontendOnly, ownStack, otherStack
        case minSalaryCOP, minSalaryUSD, maxYearsRequired, hasProfessionalCard
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = JobProfile.defaults
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? d.country
        homeCity = try c.decodeIfPresent(String.self, forKey: .homeCity) ?? d.homeCity
        linkedInQueries = try c.decodeIfPresent([String].self, forKey: .linkedInQueries) ?? d.linkedInQueries
        linkedInRegionalQueries = try c.decodeIfPresent([String].self, forKey: .linkedInRegionalQueries) ?? d.linkedInRegionalQueries
        linkedInContractQueries = try c.decodeIfPresent([String].self, forKey: .linkedInContractQueries) ?? d.linkedInContractQueries
        getOnBoardQueries = try c.decodeIfPresent([String].self, forKey: .getOnBoardQueries) ?? d.getOnBoardQueries
        computrabajoSlugs = try c.decodeIfPresent([String].self, forKey: .computrabajoSlugs) ?? d.computrabajoSlugs
        elempleoQueries = try c.decodeIfPresent([String].self, forKey: .elempleoQueries) ?? d.elempleoQueries
        magnetoRoles = try c.decodeIfPresent([String].self, forKey: .magnetoRoles) ?? d.magnetoRoles
        strong = try c.decodeIfPresent([String].self, forKey: .strong) ?? d.strong
        generic = try c.decodeIfPresent([String].self, forKey: .generic) ?? d.generic
        weak = try c.decodeIfPresent([String].self, forKey: .weak) ?? d.weak
        blocked = try c.decodeIfPresent([String].self, forKey: .blocked) ?? d.blocked
        blockedCompanies = try c.decodeIfPresent([String].self, forKey: .blockedCompanies) ?? d.blockedCompanies
        blockedTitleWords = try c.decodeIfPresent([String].self, forKey: .blockedTitleWords) ?? d.blockedTitleWords
        frontendOnly = try c.decodeIfPresent([String].self, forKey: .frontendOnly) ?? d.frontendOnly
        ownStack = try c.decodeIfPresent([String].self, forKey: .ownStack) ?? d.ownStack
        otherStack = try c.decodeIfPresent([String].self, forKey: .otherStack) ?? d.otherStack
        minSalaryCOP = try c.decodeIfPresent(Double.self, forKey: .minSalaryCOP) ?? d.minSalaryCOP
        minSalaryUSD = try c.decodeIfPresent(Int.self, forKey: .minSalaryUSD) ?? d.minSalaryUSD
        maxYearsRequired = try c.decodeIfPresent(Int.self, forKey: .maxYearsRequired) ?? d.maxYearsRequired
        hasProfessionalCard = try c.decodeIfPresent(Bool.self, forKey: .hasProfessionalCard) ?? d.hasProfessionalCard
    }
}

extension SearchProfile {
    enum CodingKeys: String, CodingKey { case freelance, jobs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        freelance = try c.decodeIfPresent(FreelanceProfile.self, forKey: .freelance) ?? .defaults
        jobs = try c.decodeIfPresent(JobProfile.self, forKey: .jobs) ?? .defaults
    }
}
