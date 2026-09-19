# glpi-onedrive-export

Script PowerShell qui exporte toutes les heures, pour chaque technicien
configuré, ses tickets GLPI assignés vers un fichier JSON déposé dans un
dossier synchronisé OneDrive. C'est l'alternative "mode Fichier partagé" de
l'app iOS quand le téléphone ne peut pas atteindre GLPI directement (VPN
indisponible, réseau externe, etc.).

## Fonctionnement

1. Le script tourne sur une machine **toujours allumée et sur le réseau où
   GLPI est accessible**, avec le client OneDrive installé et connecté.
2. Il se connecte à l'API REST GLPI avec un compte de service (App-Token +
   User-Token), interroge les tickets assignés à chaque technicien listé
   dans `config.json`, récupère le détail et les suivis de chaque ticket.
3. Il écrit un fichier `tickets_<slug>.json` par technicien dans le dossier
   OneDrive configuré (`OneDriveExportFolder`) — l'écriture est atomique
   (fichier temporaire puis renommage) pour qu'OneDrive ne synchronise
   jamais un fichier à moitié écrit.
4. Le client OneDrive de la machine synchronise ensuite ces fichiers vers
   le cloud tout seul, sans rien de plus à faire dans ce script.
5. Chaque technicien récupère, une fois, l'URL de partage de **son propre**
   fichier (voir plus bas) et la colle dans l'app iOS ▸ Réglages ▸ mode
   "Fichier partagé".

## Format du fichier produit

```json
{
  "generated_at": "2024-03-01 10:00:00",
  "tickets": [
    {
      "id": 42,
      "name": "Imprimante en panne",
      "content": "<p>...</p>",
      "status": 2,
      "priority": 4,
      "date": "2024-02-28 09:00:00",
      "date_mod": "2024-03-01 08:30:00",
      "followups": [
        { "id": 1, "content": "Pris en charge.", "date": "2024-03-01 08:30:00", "is_private": 0 }
      ]
    }
  ]
}
```

Les clés des tickets et des suivis reprennent exactement celles de l'API
GLPI (`GET /Ticket/{id}` et `GET /Ticket/{id}/ITILFollowup`), donc l'app
iOS les décode sans mapping particulier.

## Installation

1. Copiez ce dossier sur la machine qui restera allumée (ex.
   `C:\GLPI-Export\`).
2. `Copy-Item config.example.json config.json` puis éditez `config.json` :
   - `GlpiUrl`, `AppToken`, `UserToken` : compte de service GLPI (droit de
     voir les tickets de tous les techniciens listés, jamais un compte
     personnel).
   - `OneDriveExportFolder` : chemin **local** du dossier synchronisé par
     le client OneDrive sur cette machine (pas une URL).
   - `Technicians` : liste `{ "Id": <id GLPI>, "Slug": "<nom_fichier>" }`
     pour chaque technicien à exporter.
   - `Fields` : identifiants de champs de recherche GLPI (mêmes valeurs
     par défaut que dans l'app iOS ; à ajuster seulement si votre
     instance a été personnalisée).
3. Testez manuellement :
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Export-GlpiTickets.ps1
   ```
   Vérifiez qu'un fichier `tickets_<slug>.json` apparaît bien dans le
   dossier OneDrive configuré, et consultez `export.log` en cas d'erreur.

## Planifier l'exécution toutes les heures

Avec le Planificateur de tâches Windows (`taskschd.msc`) :

1. Créer une tâche de base ▸ déclencheur "Tous les jours", répéter la
   tâche toutes les **1 heure**, pendant une durée de **1 jour** (donc en
   continu).
2. Action : démarrer un programme
   - Programme : `powershell.exe`
   - Arguments : `-NoProfile -ExecutionPolicy Bypass -File "C:\GLPI-Export\Export-GlpiTickets.ps1"`
3. Onglet Général : cochez "Exécuter que l'utilisateur soit connecté ou
   non" **seulement si** vous n'avez pas besoin qu'une session OneDrive
   interactive tourne — en pratique, le client OneDrive de bureau
   nécessite une session utilisateur ouverte pour synchroniser, donc il
   est plus sûr de choisir "Exécuter uniquement si l'utilisateur est
   connecté" et de configurer cette machine pour rester en session
   ouverte (écran verrouillé, ce qui n'empêche ni le script ni OneDrive de
   fonctionner).

## Partager les fichiers avec l'app iOS

Pour chaque technicien, dans OneDrive (web ou client) :

1. Clic droit sur `tickets_<slug>.json` ▸ **Partager**.
2. Choisissez de préférence **"Personnes de \<votre organisation\>"**
   plutôt que "Tout le monde avec le lien" si votre OneDrive
   professionnel le permet (accès restreint aux comptes de l'entreprise).
   Avec un OneDrive personnel, seul "Toute personne disposant du lien"
   est disponible : traitez alors ce lien comme un secret (ne le postez
   pas publiquement), il donne accès en lecture au contenu des tickets.
3. Copiez le lien de partage, puis **transformez-le en lien de
   téléchargement direct** en ajoutant `&download=1` à la fin de l'URL
   (astuce OneDrive classique) — c'est cette URL avec `download=1` qu'il
   faut coller dans l'app iOS ▸ Réglages ▸ "Fichier d'export", pas le lien
   de partage brut (qui ouvre une page web de prévisualisation au lieu de
   renvoyer le JSON).

## Limites connues

- Les données ont jusqu'à ~1h de retard (délai entre deux exécutions).
- Lecture seule : impossible de changer un statut ou d'ajouter un suivi
  depuis l'app en mode fichier (il faut repasser en mode Direct/VPN).
- Si la machine d'export est éteinte ou hors ligne, le fichier n'est plus
  mis à jour et l'app affichera silencieusement des données de plus en
  plus anciennes (l'heure de "dernière synchro" affichée dans l'app permet
  de le repérer).
