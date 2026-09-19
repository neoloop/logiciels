# glpi-push-relay

Petit service qui comble une lacune de GLPI : **GLPI ne pousse aucune
notification vers un appareil mobile**. Ce relais interroge périodiquement
l'API REST de GLPI pour le compte des techniciens qui ont activé les
notifications dans l'app iOS, détecte les nouvelles affectations et les
changements de statut, et déclenche une notification via APNs (Apple Push
Notification service).

Ce n'est **pas** un composant obligatoire de l'app : sans lui, l'app
fonctionne normalement en lecture/écriture des tickets, seul le bouton
"Notifications push" des Réglages n'aura aucun effet.

## Fonctionnement

1. L'app iOS obtient un jeton APNs et l'envoie à `POST /register` avec
   l'identifiant GLPI (`glpiID`) de l'utilisateur connecté.
2. Le relais interroge GLPI toutes les `POLL_INTERVAL_SECONDS` secondes,
   pour chaque utilisateur ayant au moins un appareil enregistré, via
   `/search/Ticket` filtré sur le technicien assigné.
3. S'il voit apparaître un ticket inconnu, ou un changement de statut sur un
   ticket déjà vu, il envoie une notification push à tous les appareils de
   cet utilisateur.
4. L'état (`data/relay-store.json` par défaut) garde la liste des appareils
   et le dernier statut connu de chaque ticket par utilisateur.

## Prérequis

- Node.js 18+
- Un compte de service GLPI (App-Token + User-Token) ayant le droit de voir
  les tickets de tous les techniciens à surveiller (par ex. un profil
  Admin/Super-Admin dédié à l'intégration, jamais un compte personnel).
- Une clé d'authentification APNs (`.p8`) créée dans le Apple Developer
  Portal (Certificates, Identifiers & Profiles → Keys → clé avec la
  capacité "Apple Push Notifications service (APNs)"), ainsi que son
  Key ID et votre Team ID.

## Installation

```bash
cp .env.example .env
# éditez .env : URL GLPI, tokens, clé API du relais, chemin vers la clé .p8, etc.
mkdir -p secrets && cp /chemin/vers/AuthKey_XXXXXXXXXX.p8 secrets/

npm install
npm run build
npm start
```

Pour le développement avec rechargement automatique :

```bash
npm run dev
```

## Déploiement

Le relais est un simple processus Node.js qui doit tourner en continu et
être joignable en HTTPS par l'app iOS (pour `/register`) — utilisez un
reverse proxy (nginx, Caddy) devant lui pour le TLS, ou déployez-le via le
`Dockerfile` fourni :

```bash
docker build -t glpi-push-relay .
docker run -d \
  --env-file .env \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/secrets:/app/secrets \
  -p 3000:3000 \
  glpi-push-relay
```

Configurez ensuite, dans l'app iOS (Réglages ▸ Relais de notifications),
l'URL publique de ce service et la valeur de `RELAY_API_KEY`.

## Limites connues

- Le délai de détection dépend de `POLL_INTERVAL_SECONDS` (par défaut 3
  minutes) : ce n'est pas du push instantané, GLPI n'exposant pas de
  webhook natif.
- Le mapping des champs de recherche (`GLPI_FIELD_*`) doit rester cohérent
  avec celui configuré côté app iOS.
- Le stockage est un fichier JSON local : suffisant pour un petit nombre de
  techniciens, mais pas pensé pour une charge importante ni pour du
  multi-instance (pas de verrou distribué).
