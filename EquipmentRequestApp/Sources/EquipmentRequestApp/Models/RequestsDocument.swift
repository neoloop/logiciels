import Foundation

/// Une demande, telle que stockée dans le fichier JSON partagé (le même que
/// celui lu/écrit par les pages web). Remplace l'ancien modèle basé sur les
/// colonnes Excel : plus de correspondance par nom d'en-tête nécessaire, les
/// champs sont directement typés.
struct JsonEquipmentRequest: Codable, Identifiable, Equatable {
    var id: String
    var reference: String = ""
    var date: String = ""
    var groupement: String = ""
    var requesterName: String = ""
    var requesterEmail: String = ""
    var beneficiaryName: String = ""
    var beneficiaryEmail: String = ""
    var phone: String = ""
    var equipment: String = ""
    var software: String = ""
    var opportunity: String = ""
    var justification: String = ""
    var status: String = RequestStatus.pending.rawValue
    var receptionDate: String = ""

    var requestStatus: RequestStatus {
        get { RequestStatus(rawStatus: status) }
        set { status = newValue.rawValue }
    }

    /// Convertit la demande en EquipmentRequest, pour réutiliser PDFGenerator et
    /// MailComposeView (conçus pour ce modèle) sans dupliquer leur logique.
    /// `overrideBeneficiaryEmail` permet d'utiliser l'email saisi/corrigé dans
    /// l'app plutôt que celui (éventuellement absent) de la demande d'origine.
    func asEquipmentRequest(overrideBeneficiaryEmail: String? = nil) -> EquipmentRequest {
        var request = EquipmentRequest()
        request.requesterName = requesterName
        request.requesterEmail = requesterEmail
        request.beneficiaryName = beneficiaryName
        request.beneficiaryEmail = overrideBeneficiaryEmail ?? beneficiaryEmail
        request.justification = justification
        request.equipmentLabelOverride = equipment
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

/// Le fichier JSON complet : toutes les demandes, connues et lues par l'app
/// iOS et par les pages web. `schemaVersion` permet de faire évoluer le
/// format plus tard sans casser les lecteurs existants.
struct RequestsDocument: Codable {
    var schemaVersion: Int = 1
    var requests: [JsonEquipmentRequest] = []
}
