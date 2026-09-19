# logiciels

## GLPI Interventions (iOS)

App iOS native permettant à un technicien de consulter ses interventions
(tickets GLPI assignés), de changer leur statut et d'être notifié des
nouvelles affectations.

- [`ios/GLPIInterventions`](ios/GLPIInterventions) — app SwiftUI, à ouvrir
  dans Xcode (voir son README pour la configuration GLPI et la génération
  du projet via XcodeGen).
- [`backend/glpi-push-relay`](backend/glpi-push-relay) — relais Node.js
  optionnel qui sonde l'API GLPI et déclenche les notifications push APNs
  (GLPI n'a pas de mécanisme de push natif).
