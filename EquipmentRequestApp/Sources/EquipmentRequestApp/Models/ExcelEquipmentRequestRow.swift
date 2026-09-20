import Foundation

/// Une demande telle que lue depuis une ligne du tableau Excel (créée par le
/// flux qui alimente le tableau à partir d'un mail structuré des employés, ou
/// par l'app elle-même). Conserve les valeurs brutes de la ligne pour pouvoir
/// les renvoyer inchangées lors d'une mise à jour du statut (voir
/// GraphExcelService.updateStatus), sans perdre d'éventuelles colonnes
/// supplémentaires non gérées par l'app.
struct ExcelEquipmentRequestRow: Identifiable {
    let index: Int
    var id: Int { index }
    let rawValues: [Any]

    let reference: String
    let date: String
    let groupement: String
    let requesterName: String
    let requesterEmail: String
    let beneficiaryName: String
    let beneficiaryEmail: String
    let phone: String
    let equipmentLabel: String
    let software: String
    let opportunity: String
    let justification: String
    let receptionDate: String
    let status: RequestStatus

    init(index: Int, rawValues: [Any], columnMap: ColumnMap) {
        self.index = index
        self.rawValues = rawValues

        func string(forAnyOf candidates: [String]) -> String {
            guard let i = columnMap.index(forAnyOf: candidates), i < rawValues.count else { return "" }
            return Self.stringify(rawValues[i])
        }

        reference = string(forAnyOf: ExcelColumn.reference)
        date = string(forAnyOf: ExcelColumn.date)
        groupement = string(forAnyOf: ExcelColumn.groupement)
        requesterName = string(forAnyOf: ExcelColumn.requesterName)
        requesterEmail = string(forAnyOf: ExcelColumn.requesterEmail)
        beneficiaryName = string(forAnyOf: ExcelColumn.beneficiaryName)
        beneficiaryEmail = string(forAnyOf: ExcelColumn.beneficiaryEmail)
        phone = string(forAnyOf: ExcelColumn.phone)
        equipmentLabel = string(forAnyOf: ExcelColumn.equipment)
        software = string(forAnyOf: ExcelColumn.software)
        opportunity = string(forAnyOf: ExcelColumn.opportunity)
        justification = string(forAnyOf: ExcelColumn.observations)
        receptionDate = string(forAnyOf: ExcelColumn.receptionDate)
        status = RequestStatus(rawStatus: string(forAnyOf: ExcelColumn.status))
    }

    private static func stringify(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if value is NSNull { return "" }
        return "\(value)"
    }

    /// Convertit la ligne en EquipmentRequest, pour réutiliser PDFGenerator et
    /// MailComposeView (conçus pour ce modèle) sans dupliquer leur logique.
    /// `overrideBeneficiaryEmail` permet d'utiliser l'email saisi/corrigé dans
    /// l'app plutôt que celui (éventuellement absent) de la ligne Excel.
    func asEquipmentRequest(overrideBeneficiaryEmail: String? = nil) -> EquipmentRequest {
        var request = EquipmentRequest()
        request.requesterName = requesterName
        request.requesterEmail = requesterEmail
        request.beneficiaryName = beneficiaryName
        request.beneficiaryEmail = overrideBeneficiaryEmail ?? beneficiaryEmail
        request.justification = justification
        request.equipmentLabelOverride = equipmentLabel
        request.reference = reference
        request.groupement = groupement
        request.phone = phone
        request.software = software
        request.opportunity = opportunity
        if let parsedDate = EquipmentRequest.dateFormatter.date(from: date) {
            request.date = parsedDate
        }
        return request
    }
}
