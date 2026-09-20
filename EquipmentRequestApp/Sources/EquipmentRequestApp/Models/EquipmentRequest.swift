import Foundation

enum EquipmentType: String, CaseIterable, Identifiable, Codable {
    case laptop = "Ordinateur portable"
    case desktop = "Ordinateur fixe"
    case phone = "Téléphone"
    case usbKey = "Clé USB"
    case other = "Autre"

    var id: String { rawValue }
}

struct EquipmentRequest: Identifiable, Codable {
    let id: UUID
    var date: Date
    var requesterName: String
    var requesterEmail: String
    var beneficiaryName: String
    var beneficiaryEmail: String
    var equipmentType: EquipmentType
    var equipmentOtherDetail: String
    var justification: String

    /// Quand la demande provient du fichier JSON (créée par le formulaire des
    /// employés), le libellé de matériel est du texte libre qui ne correspond pas
    /// forcément à un cas d'EquipmentType : on le stocke tel quel plutôt que
    /// d'essayer de le faire rentrer dans l'enum.
    var equipmentLabelOverride: String?

    /// Champs de contexte présents dans le fichier JSON mais pas dans le
    /// formulaire de saisie manuelle de l'app : vides pour une demande créée
    /// depuis l'app, renseignés pour une demande relue depuis le JSON.
    var reference: String = ""
    var groupement: String = ""
    var phone: String = ""
    var software: String = ""
    var opportunity: String = ""

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        requesterName: String = "",
        requesterEmail: String = "",
        beneficiaryName: String = "",
        beneficiaryEmail: String = "",
        equipmentType: EquipmentType = .laptop,
        equipmentOtherDetail: String = "",
        justification: String = "",
        equipmentLabelOverride: String? = nil,
        reference: String = "",
        groupement: String = "",
        phone: String = "",
        software: String = "",
        opportunity: String = ""
    ) {
        self.id = id
        self.date = date
        self.requesterName = requesterName
        self.requesterEmail = requesterEmail
        self.beneficiaryName = beneficiaryName
        self.beneficiaryEmail = beneficiaryEmail
        self.equipmentType = equipmentType
        self.equipmentOtherDetail = equipmentOtherDetail
        self.justification = justification
        self.equipmentLabelOverride = equipmentLabelOverride
        self.reference = reference
        self.groupement = groupement
        self.phone = phone
        self.software = software
        self.opportunity = opportunity
    }

    /// Libellé du matériel affiché et écrit dans le JSON (inclut le détail si "Autre").
    var equipmentLabel: String {
        if let equipmentLabelOverride, !equipmentLabelOverride.isEmpty {
            return equipmentLabelOverride
        }
        if equipmentType == .other, !equipmentOtherDetail.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Autre : \(equipmentOtherDetail)"
        }
        return equipmentType.rawValue
    }

    var isValid: Bool {
        !requesterName.trimmingCharacters(in: .whitespaces).isEmpty &&
        requesterEmail.isValidEmail &&
        !beneficiaryName.trimmingCharacters(in: .whitespaces).isEmpty &&
        beneficiaryEmail.isValidEmail &&
        !justification.trimmingCharacters(in: .whitespaces).isEmpty &&
        (equipmentType != .other || !equipmentOtherDetail.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
}

extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
