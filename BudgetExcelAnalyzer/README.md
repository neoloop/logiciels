# Budget Excel Analyzer (iOS)

App SwiftUI qui lit un export d'exécution budgétaire (type "Situation
Budgétaire") stocké dans OneDrive via l'app Fichiers d'iOS, et affiche
Voté / Engagé / Disponible par service et par nomenclature, avec envoi du
résumé par email.

> ⚠️ Ce projet a été écrit dans un environnement sans Xcode/Swift, donc le
> code n'a pas pu être compilé ici. Il doit être buildé et testé sur un Mac
> avec Xcode avant utilisation.

## ⚠️ Format de fichier : .xlsx uniquement

Le parsing utilise [CoreXLSX](https://github.com/CoreOffice/CoreXLSX), qui ne
lit que le format **Office Open XML (.xlsx)**. Si ton export
`Situation_Budgétaire` sort en **.xls** (ancien format binaire Excel
97-2003), il faut le convertir en `.xlsx` avant de l'importer dans l'app
(ouvrir dans Excel/Numbers/Google Sheets/OneDrive Online → "Enregistrer
sous" / "Exporter" en `.xlsx`). Le sélecteur de fichiers de l'app ne filtre
que sur `.xlsx`.

## Fonctionnement

1. L'utilisateur importe un fichier `.xlsx` via le sélecteur de fichiers
   iOS standard (`.fileImporter`), qui donne accès à tous les emplacements
   enregistrés dans l'app **Fichiers** — y compris **OneDrive**, dès que
   l'app OneDrive est installée et connectée.
2. Le fichier est parsé en local avec CoreXLSX (pure Swift, pas de
   dépendance native). Une seule feuille est lue (la première), une ligne =
   une ligne de nomenclature budgétaire.
3. Les services (`Service Gestionnaire`) sont **détectés automatiquement**
   à partir des données importées — rien n'est codé en dur, ça marche pour
   n'importe quel service/année tant que les colonnes sont présentes.
4. Un bookmark sécurisé du fichier est conservé pour pouvoir le relire plus
   tard (bouton "Importer" ou tirer pour rafraîchir) sans repasser par le
   sélecteur.
5. Les données parsées sont mises en cache localement (JSON dans
   Application Support) pour que le dashboard s'affiche immédiatement au
   relancement de l'app.
6. Depuis la fiche d'un service, "Envoyer par email" ouvre le compositeur
   Mail natif d'iOS avec un résumé HTML (Voté/Engagé/Disponible par
   nomenclature) pré-rempli ; l'adresse du destinataire est mémorisée par
   service pour les envois suivants.

## Format du classeur Excel attendu

Une seule feuille, une ligne par nomenclature budgétaire. Colonnes
attendues (reconnaissance insensible à la casse/accents) :

| Colonne                             | Rôle                                             |
|--------------------------------------|---------------------------------------------------|
| `Article Nat. (Code)`                | Code de la nomenclature                            |
| `Article Nat. (Libellé)`             | Libellé de la nomenclature                         |
| `Groupe Section (Code)`              | `F` = Fonctionnement, `I` = Investissement         |
| `Groupe Chapitre Nat. (Code)`        | Code chapitre (optionnel)                          |
| `Service Gestionnaire (Code)`        | Code du service (ex : 58, 53, 52)                  |
| `Service Gestionnaire (Libellé)`     | Libellé du service                                 |
| `Mt Voté CP`                         | Montant budgété (crédits de paiement)              |
| `Mt Disponible`                      | Montant restant disponible                         |
| *(toute colonne contenant "Demandeur")* | Service demandeur — Code/Libellé, détecté automatiquement, stocké mais pas encore affiché en filtre dans la v1 |

Le montant **Engagé** n'est pas une colonne source : il est calculé comme
`Voté − Disponible`, comme dans le tableau de bord de référence dont ce
format est extrait.

## Build

Prérequis : Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
cd BudgetExcelAnalyzer
xcodegen generate
open BudgetExcelAnalyzer.xcodeproj
```

Le projet Xcode (`.xcodeproj`) n'est pas versionné (voir `.gitignore`) : il
est régénéré à partir de `project.yml` à chaque fois. C'est plus fiable que
de committer un `.pbxproj` écrit à la main.

Dans Xcode : sélectionner ton équipe de signature (Signing & Capabilities),
puis Run sur un simulateur ou un appareil (iOS 17+). Pour tester l'envoi
d'email sur simulateur, le compte Mail doit être configuré dans l'app Mail
du simulateur (Réglages → Mail → Comptes) ; sinon l'app affichera une
alerte "Mail non configuré".

## Activer l'accès à OneDrive

1. Installer l'app **OneDrive** depuis l'App Store et se connecter.
2. Dans OneDrive : Réglages → activer l'intégration avec l'app **Fichiers**
   (activée par défaut sur les versions récentes).
3. Dans Budget Excel Analyzer, taper "Choisir un fichier" → naviguer vers
   "Parcourir" → "OneDrive" → sélectionner le classeur `.xlsx`.

Aucune permission ou configuration OneDrive spécifique n'est nécessaire côté
app : tout passe par le sélecteur de fichiers standard d'iOS.

## Structure du projet

```
BudgetExcelAnalyzer/
├── project.yml                  # config XcodeGen
└── BudgetExcelAnalyzer/
    ├── App/                     # point d'entrée SwiftUI
    ├── Models/                  # BudgetLineItem, BudgetSection, ServiceSummary, NomenclatureSummary
    ├── Services/                # import Excel, parsing, bookmark, store, email
    └── Views/                   # écrans SwiftUI
```

## Limites connues (v1 volontairement ciblée)

- Devise codée en dur en EUR (`Services/CurrencyFormatting.swift`).
- Un seul fichier source à la fois (pas de fusion multi-fichiers,
  pas d'évolution pluriannuelle).
- Le filtre par "Service demandeur" n'a pas d'interface dans la v1 : le
  champ est parsé et stocké sur chaque ligne, mais pas encore exposé en
  filtre dans le dashboard.
- Pas d'export PDF : l'email envoyé contient un tableau HTML, pas de pièce
  jointe PDF.
- Pas d'édition des données dans l'app : tout vient du fichier Excel, qui
  reste la source de vérité.

## Prochaines étapes possibles

- Filtre "Service demandeur" dans le dashboard.
- Export PDF par service (en pièce jointe de l'email).
- Graphiques (Swift Charts) de répartition Fonctionnement/Investissement.
