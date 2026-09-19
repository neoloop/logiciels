# GLPI Interventions (iOS)

App iOS native (SwiftUI) permettant à un technicien de consulter et suivre
ses interventions (tickets GLPI qui lui sont assignés) : liste, détail,
changement de statut, ajout de suivi, et notifications push optionnelles.

> Ce projet a été écrit dans un environnement Linux sans Xcode : le code
> Swift n'a donc pas pu être compilé ici. Il suit les conventions SwiftUI /
> Swift 5.9 standards, mais faites une première compilation attentive côté
> Mac avant de considérer la base comme stable.

## Prérequis

- macOS avec Xcode 15+ (cible iOS 17+)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) pour générer le projet
  `.xcodeproj` à partir de `project.yml` (ce fichier généré n'est pas versionné) :
  ```bash
  brew install xcodegen
  ```

## Configuration côté GLPI

1. **Activer l'API REST** : Configuration ▸ Générale ▸ onglet API ▸ activer
   "Activer Rest API", puis créer/activer un client API et noter son
   **App-Token**.
2. **Générer un User-Token** : chaque technicien va dans ses Préférences ▸
   onglet "Clés d'accès distant" (Remote access keys) et génère un
   **User-Token** personnel — c'est ce jeton, pas son mot de passe, que
   l'app utilise pour s'authentifier.
3. Vérifiez que le profil du technicien lui permet de voir les tickets où
   il est assigné (`Ticket::canView`).

## Générer et ouvrir le projet Xcode

```bash
cd ios/GLPIInterventions
xcodegen generate
open GLPIInterventions.xcodeproj
```

Dans Xcode : sélectionnez le target `GLPIInterventions` ▸ Signing &
Capabilities ▸ choisissez votre équipe de développement.

> **Compte développeur personnel (gratuit)** : la capacité *Push
> Notifications* n'est volontairement **pas** déclarée dans le projet, car
> elle n'est pas disponible avec un compte Apple "Personal Team" gratuit
> (uniquement avec le programme Apple Developer payant, 99$/an) et ferait
> échouer la signature automatique. L'app compile et fonctionne
> normalement sans elle ; seul le bouton "Notifications push" des Réglages
> échouera silencieusement (message d'erreur affiché). Si vous rejoignez
> le programme payant, ajoutez la capacité manuellement dans Xcode
> (Signing & Capabilities ▸ **+ Capability** ▸ *Push Notifications*, qui
> génère automatiquement le fichier d'entitlements et active le mode
> arrière-plan *Remote notifications*).

Lancez ensuite sur simulateur ou appareil avec ⌘R, ou exécutez les tests
unitaires avec ⌘U (voir `GLPIInterventionsTests/`).

## Utilisation dans l'app

Au premier lancement, l'écran de connexion demande :

- **Serveur** : l'URL de base de votre GLPI (ex. `https://glpi.exemple.com`)
- **App-Token** et **User-Token** obtenus ci-dessus

Une fois connecté, l'onglet **Interventions** liste les tickets assignés au
technicien connecté (triés par dernière modification), avec un filtre par
statut et l'option d'inclure les tickets clos. Le détail d'un ticket permet
de changer son statut et d'ajouter un suivi.

L'onglet **Réglages** permet de :
- se déconnecter ;
- activer les notifications push (voir ci-dessous) ;
- ajuster le **mapping des champs de recherche GLPI** si votre instance a
  été personnalisée (les identifiants de champ par défaut correspondent à
  une installation standard, voir `Models/GLPIFieldMapping.swift`).

## Notifications push

GLPI n'a pas de mécanisme natif pour pousser des notifications vers un
téléphone. Pour ce faire, l'app s'appuie sur un petit relais auto-hébergé
qui interroge GLPI à intervalles réguliers et déclenche les notifications
APNs : voir [`backend/glpi-push-relay`](../../backend/glpi-push-relay).
Sans ce relais déployé et configuré (URL + clé API dans Réglages), le
bouton "Notifications push" n'aura aucun effet observable.

## Structure du projet

```
GLPIInterventions/
  App/            point d'entrée SwiftUI + AppDelegate (APNs)
  Models/         Ticket, statuts/priorités, mapping de champs GLPI
  Networking/     client API GLPI, Keychain, service push
  ViewModels/     logique métier (auth, liste, détail)
  Views/          écrans SwiftUI
  Utilities/      conversion HTML → texte
  Resources/      Info.plist, Assets.xcassets
GLPIInterventionsTests/
```
