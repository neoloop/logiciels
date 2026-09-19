import Foundation

/// One row of a Sedit "Commandes" export, used to reconcile against the Expression
/// commandes by BC number (Sedit's "N° Commande" ↔ Expression's "BC").
struct SeditCommandeLine: Identifiable, Codable, Hashable {
    let id: UUID
    let numeroCommande: String
    let date: Date?
    let serviceCode: Int?
    let fournisseur: String?
    let libelle: String
    let montantTTC: Double
    let articleCode: String?

    init(
        id: UUID = UUID(),
        numeroCommande: String,
        date: Date?,
        serviceCode: Int?,
        fournisseur: String?,
        libelle: String,
        montantTTC: Double,
        articleCode: String?
    ) {
        self.id = id
        self.numeroCommande = numeroCommande
        self.date = date
        self.serviceCode = serviceCode
        self.fournisseur = fournisseur
        self.libelle = libelle
        self.montantTTC = montantTTC
        self.articleCode = articleCode
    }
}
