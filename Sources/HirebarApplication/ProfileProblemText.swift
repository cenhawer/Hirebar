import Foundation
import HirebarDomain

extension ProfileProblem {
    public var message: String {
        switch self {
        case .missingName:
            return String(localized: "Escribe tu nombre en Datos personales.")
        case .invalidEmail(let email):
            return String(localized: "El correo \(email) no parece válido.")
        case .missingCompany(let position):
            return String(localized: "El empleo número \(position) necesita el nombre de la empresa.")
        case .invalidMonth(let company, let value):
            return String(localized: "En \(company), la fecha \(value) debe tener el formato AAAA-MM, por ejemplo 2024-06.")
        case .endsBeforeStart(let company):
            return String(localized: "En \(company), la fecha de salida es anterior a la de entrada.")
        case .emptyAchievement(let company):
            return String(localized: "En \(company) hay un logro vacío: escríbelo o quítalo.")
        case .incompleteVariant(let position):
            return String(localized: "La hoja de vida número \(position) necesita un identificador y un nombre de archivo.")
        case .repeatedVariant(let key):
            return String(localized: "Hay dos hojas de vida con el identificador \(key); cambia uno.")
        }
    }
}
