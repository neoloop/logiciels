# DiveLog

Application iOS (SwiftUI + SwiftData) pour tenir un carnet de plongée bouteille.

## Fonctionnalités

- **Journal des plongées** : date/heure, profondeur, durée, lieu (via géolocalisation GPS avec conversion en nom de lieu), et la liste des personnes avec qui vous avez plongé.
- **Détail d'une plongée** : affichage complet + carte du lieu de plongée.
- **Statistiques** : nombre total de plongées, durée totale cumulée, profondeur cumulée, et répartition du nombre de plongées par tranche de profondeur (≤ 20 m, 20-40 m, 40-60 m, > 60 m).

Les données sont stockées localement sur l'appareil avec SwiftData (aucune connexion réseau requise).

## Prérequis

- macOS avec Xcode 15 ou supérieur (iOS 17+)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) pour générer le projet Xcode à partir de `project.yml` :

  ```bash
  brew install xcodegen
  ```

## Générer et lancer le projet

Depuis le dossier `DiveLog` :

```bash
xcodegen generate
open DiveLog.xcodeproj
```

Dans Xcode :

1. Sélectionnez le target `DiveLog` puis renseignez votre équipe de signature (onglet *Signing & Capabilities*).
2. Choisissez un simulateur ou un iPhone/iPad physique.
3. Lancez avec ⌘R.

## Tester la géolocalisation

- Sur simulateur : menu *Features > Location* pour simuler une position.
- Sur appareil physique : autorisez l'accès à la localisation lors de la première demande (message défini dans `Info.plist`).

## Structure du projet

```
DiveLog/
├── project.yml            # Définition du projet pour XcodeGen
├── Info.plist
└── Sources/
    ├── App/                # Point d'entrée SwiftUI
    ├── Models/             # Modèle SwiftData `Dive`
    ├── Services/           # LocationService (CoreLocation + géocodage inverse)
    ├── Utilities/          # Formatteurs (durée, profondeur, date)
    ├── Views/              # Journal, formulaire, détail, statistiques
    └── Assets.xcassets/
```
