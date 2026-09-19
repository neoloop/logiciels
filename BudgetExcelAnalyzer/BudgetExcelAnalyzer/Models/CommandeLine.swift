import Foundation

/// One row of a "Expression-<service>-<year>" sheet: a single purchase order line.
struct CommandeLine: Identifiable, Codable, Hashable {
    let id: UUID
    let numero: String
    let date: Date?
    let serviceCode: Int
    let serviceLabel: String
    let articleCode: String?
    let libelle: String
    let montant: Double
    let fournisseur: String?
    let bc: String?
    let projetRef: String?

    init(
        id: UUID = UUID(),
        numero: String,
        date: Date?,
        serviceCode: Int,
        serviceLabel: String,
        articleCode: String?,
        libelle: String,
        montant: Double,
        fournisseur: String?,
        bc: String?,
        projetRef: String?
    ) {
        self.id = id
        self.numero = numero
        self.date = date
        self.serviceCode = serviceCode
        self.serviceLabel = serviceLabel
        self.articleCode = articleCode
        self.libelle = libelle
        self.montant = montant
        self.fournisseur = fournisseur
        self.bc = bc
        self.projetRef = projetRef
    }
}
