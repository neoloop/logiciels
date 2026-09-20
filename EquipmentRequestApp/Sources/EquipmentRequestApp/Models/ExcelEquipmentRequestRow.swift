import Foundation

/// Une demande telle que lue depuis une ligne du tableau Excel (créée par le
/// formulaire externe des employés, ou par l'app elle-même). Conserve les valeurs
/// brutes de la ligne pour pouvoir les renvoyer inchangées lors d'une mise à jour
/// du statut (voir GraphExcelService.updateStatus), sans perdre d'éventuelles
/// colonnes supplémentaires non gérées par l'app.
struct ExcelEquipmentRequestRow: Identifiable {
    let index: Int
    var id: Int { index }
    let rawValues: [Any]

    let date: String
    let requesterName: String
    let requesterEmail: String
    let beneficiaryName: String
    let beneficiaryEmail: String
    let equipmentLabel: String
    let justification: String
    let status: RequestStatus

    init(index: Int, rawValues: [Any], columnMap: ColumnMap) {
        self.index = index
        self.rawValues = rawValues

        func string(forAnyOf candidates: [String]) -> String {
            guard let i = columnMap.index(forAnyOf: candidates), i < rawValues.count else { return "" }
            return Self.stringify(rawValues[i])
        }

        date = string(forAnyOf: ExcelColumn.date)
        requesterName = string(forAnyOf: ExcelColumn.requesterName)
        requesterEmail = string(forAnyOf: ExcelColumn.requesterEmail)
        beneficiaryName = string(forAnyOf: ExcelColumn.beneficiaryName)
        beneficiaryEmail = string(forAnyOf: ExcelColumn.beneficiaryEmail)
        equipmentLabel = string(forAnyOf: ExcelColumn.equipment)
        justification = string(forAnyOf: ExcelColumn.justification)
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
    func asEquipmentRequest() -> EquipmentRequest {
        var request = EquipmentRequest()
        request.requesterName = requesterName
        request.requesterEmail = requesterEmail
        request.beneficiaryName = beneficiaryName
        request.beneficiaryEmail = beneficiaryEmail
        request.justification = justification
        request.equipmentLabelOverride = equipmentLabel
        if let parsedDate = EquipmentRequest.dateFormatter.date(from: date) {
            request.date = parsedDate
        }
        return request
    }
}
