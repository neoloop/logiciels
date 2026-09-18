# Budget Excel Analyzer (iOS)

App SwiftUI qui lit un classeur Excel stocké dans OneDrive (via l'app Fichiers
d'iOS) et compare les dépenses réelles à un budget par catégorie, mois par mois.

> ⚠️ Ce projet a été écrit dans un environnement sans Xcode/Swift, donc le
> code n'a pas pu être compilé ici. Il doit être buildé et testé sur un Mac
> avec Xcode avant utilisation.

## Fonctionnement

1. L'utilisateur importe un fichier `.xlsx` via le sélecteur de fichiers
   iOS standard (`UIDocumentPickerViewController` / `.fileImporter`), qui
   donne accès à tous les emplacements enregistrés dans l'app **Fichiers**
   — y compris **OneDrive**, dès que l'app OneDrive est installée et connectée.
2. Le fichier est parsé en local avec [CoreXLSX](https://github.com/CoreOffice/CoreXLSX)
   (pure Swift, pas de dépendance native).
3. Un "bookmark" sécurisé du fichier est conservé pour pouvoir le relire
   plus tard (bouton "Importer" ou tirer pour rafraîchir) sans repasser par
   le sélecteur.
4. Les données parsées sont mises en cache localement (JSON dans
   Application Support) pour que le dashboard s'affiche immédiatement au
   relancement de l'app.

## Format du classeur Excel attendu

Le classeur doit contenir deux feuilles :

### Feuille "Transactions" (ou "Dépenses" / "Opérations" / "Mouvements")

| Date       | Catégorie    | Montant | Description        |
|------------|--------------|---------|---------------------|
| 2026-09-03 | Alimentation | 45.20   | Courses Carrefour   |
| 2026-09-05 | Transport    | 12.50   | Essence             |

- **Date** : date Excel classique ou texte (`AAAA-MM-JJ`, `JJ/MM/AAAA`…).
- **Catégorie** : doit correspondre (insensible à la casse/accents) aux
  catégories de la feuille Budget pour être rapprochée automatiquement.
- **Montant** : nombre, avec virgule ou point décimal, espaces/symboles
  monétaires tolérés. La valeur absolue est utilisée comme dépense.
- **Description** : optionnelle.

### Feuille "Budget"

| Catégorie    | Budget |
|--------------|--------|
| Alimentation | 400    |
| Transport    | 100    |

- **Catégorie** : nom de la catégorie.
- **Budget** : montant budgété pour le mois, par catégorie.

Les en-têtes de colonnes sont reconnus même avec des variantes proches
(`Categorie`/`Catégorie`/`Category`, `Montant`/`Amount`, etc.) — voir
`ExcelImportService.swift` pour la liste exacte des synonymes acceptés, et
l'étendre si besoin.

Les transactions dont la catégorie n'existe pas dans la feuille Budget sont
affichées à part sous "Hors budget" pour repérer les dépenses non prévues.

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
puis Run sur un simulateur ou un appareil (iOS 17+).

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
    ├── Models/                  # Transaction, BudgetLine, CategorySummary
    ├── Services/                # import Excel, parsing, bookmark, store
    └── Views/                   # écrans SwiftUI
```

## Limites connues (MVP volontairement simple)

- Devise codée en dur en EUR (`CategoryRow.swift`, `DashboardView.swift`,
  `TransactionListView.swift`) — facile à changer si besoin.
- Un seul fichier source à la fois (pas de fusion multi-fichiers).
- Pas d'édition des transactions/budget dans l'app : tout vient du fichier
  Excel, qui reste la source de vérité.
- Comparaison "réel vs budget" par mois calendaire, sans report d'un mois
  sur l'autre.

## Prochaines étapes possibles

- Graphiques d'évolution mensuelle (Swift Charts).
- Alertes de dépassement (notifications locales).
- Édition du budget directement dans l'app.
