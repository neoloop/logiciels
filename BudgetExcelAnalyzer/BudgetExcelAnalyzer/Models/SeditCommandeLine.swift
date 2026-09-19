import Foundation

/// One row of a Sedit "Commandes" export, used to reconcile against the Expression
/// commandes by BC number (Sedit's "N° Commande" ↔ Expression's "BC").
///
/// `serviceCode` is the "Service Gestionnaire" (which service's budget pays for the
/// order); `serviceDestinataire` is the "Service Destinataire" (which service actually
/// requested/receives it). `serviceEmetteur` is who issued the order, `serviceFacturation`
/// is who gets invoiced for it. Any of these pairs can differ when services order or bill
/// across each other.
struct SeditCommandeLine: Identifiable, Codable, Hashable {
    let id: UUID
    let numeroCommande: String
    let date: Date?
    let serviceCode: Int?
    let serviceDestinataire: Int?
    let serviceEmetteur: Int?
    let serviceFacturation: Int?
    let fournisseur: String?
    let libelle: String
    let montantTTC: Double
    let articleCode: String?

    init(
        id: UUID = UUID(),
        numeroCommande: String,
        date: Date?,
        serviceCode: Int?,
        serviceDestinataire: Int?,
        serviceEmetteur: Int?,
        serviceFacturation: Int?,
        fournisseur: String?,
        libelle: String,
        montantTTC: Double,
        articleCode: String?
    ) {
        self.id = id
        self.numeroCommande = numeroCommande
        self.date = date
        self.serviceCode = serviceCode
        self.serviceDestinataire = serviceDestinataire
        self.serviceEmetteur = serviceEmetteur
        self.serviceFacturation = serviceFacturation
        self.fournisseur = fournisseur
        self.libelle = libelle
        self.montantTTC = montantTTC
        self.articleCode = articleCode
    }
}
