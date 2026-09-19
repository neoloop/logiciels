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

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        requesterName: String = "",
        requesterEmail: String = "",
        beneficiaryName: String = "",
        beneficiaryEmail: String = "",
        equipmentType: EquipmentType = .laptop,
        equipmentOtherDetail: String = "",
        justification: String = ""
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
    }

    /// Libellé du matériel affiché et écrit dans Excel (inclut le détail si "Autre").
    var equipmentLabel: String {
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

    /// La ligne, dans l'ordre des colonnes attendues par le tableau Excel "DemandesMateriel".
    /// Voir EquipmentRequestApp/README.md pour l'ordre exact des colonnes à créer.
    var excelRow: [String] {
        [
            Self.dateFormatter.string(from: date),
            requesterName,
            requesterEmail,
            beneficiaryName,
            beneficiaryEmail,
            equipmentLabel,
            justification,
            "Validée"
        ]
    }
}

extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
