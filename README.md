# logiciels

## EquipmentRequestApp

App iOS + pages web pour gérer les demandes de matériel (ordinateur,
téléphone, clé USB...) : les employés soumettent leurs demandes depuis un
navigateur (`EquipmentRequestApp/web/nouvelle-demande.html`), le valideur les
consulte et les traite depuis l'app iOS ou depuis
`EquipmentRequestApp/web/valider.html` (validation ou refus, génération d'un
PDF à faire signer et envoi par mail). Tout repose sur un fichier JSON
partagé sur OneDrive/SharePoint, sans backend.
Voir [EquipmentRequestApp/README.md](EquipmentRequestApp/README.md) (app iOS)
et [EquipmentRequestApp/web/README.md](EquipmentRequestApp/web/README.md)
(pages web) pour l'installation et la configuration.