# Suivi des licences & abonnements

Petite application web auto-hébergée pour **suivre les échéances de licences, maintenances et abonnements logiciels**, et **relancer par mail** quand il faut passer commande. Aucune base de données ni framework : un serveur Node et un fichier JSON.

## Fonctionnalités

- **Durée d'engagement** de 1, 2 ou 3 ans : la date de fin est calculée automatiquement à partir du début de période.
- **Statuts automatiques** : `OK`, `À anticiper` (dans la fenêtre d'alerte, 60 jours par défaut), `Urgent` (30 jours ou moins), `Expiré`.
- **Relances par mail** via un relais SMTP : un premier mail à J-60 (réglable), puis une relance tous les 7 jours (réglable) tant que la commande n'est pas faite.
- **Bouton « Commande faite »** : repart d'une nouvelle période (par défaut à l'ancienne échéance), remet le compteur à zéro, arrête les relances et garde l'historique.
- **Plusieurs destinataires**, avec un **routage par service** : les licences d'un service (ex. `53`, `58`) sont envoyées à des destinataires dédiés, dans un mail séparé. Destinataires supplémentaires possibles par licence.
- Ajout / modification / suppression de logiciels, recherche, tri, filtre par statut, export CSV.
- Bouton « Relancer maintenant », mail de test et journal des envois.

## Démarrage

Prérequis : Node.js 18 ou plus.

```bash
npm install
PORT=8091 node server.js
```

Puis ouvrir `http://localhost:8091` et renseigner dans **⚙ Paramètres** : le serveur SMTP, l'expéditeur, les destinataires et le routage par service. Envoyer un mail de test pour valider.

Les données (licences, paramètres, journal) sont dans `data/data.json`, créé au premier lancement avec des exemples fictifs. **À sauvegarder.**

### Docker

```bash
docker compose up -d --build
```

### Lancement permanent (NAS, serveur)

`lancer.sh` relance le serveur s'il ne répond plus. Le planifier toutes les 5 minutes :

```bash
PORT=8091 sh lancer.sh
```

## Configuration

| Paramètre | Défaut |
|---|---|
| Serveur SMTP | `smtp.example.org:25`, sans authentification, certificat non vérifié |
| Alerte avant échéance | 60 jours |
| Relance tous les | 7 jours |
| Heure d'envoi quotidienne | 08:00 (fuseau `TZ`, `Europe/Paris` par défaut) |

Variables d'environnement : `PORT` (8091), `DATA_DIR` (`./data`), `TZ`.

## Sécurité

L'application **n'a pas d'authentification** : elle est prévue pour un réseau interne. Ne pas l'exposer sur Internet sans reverse proxy authentifié. Le mot de passe SMTP éventuel est stocké en clair dans `data/data.json` (dossier exclu du dépôt).
