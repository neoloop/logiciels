#!/bin/sh
# Watchdog : relance le serveur s'il ne répond pas. À planifier toutes les 5 minutes
# (ex. Planificateur de tâches Synology) : sh /chemin/vers/suivi-licences/lancer.sh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8091}"
NODE="${NODE:-$(command -v node)}"
cd "$APP_DIR" || exit 1
if curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$PORT/api/auth-status"; then
  exit 0
fi
PORT="$PORT" nohup "$NODE" server.js >> suivi.log 2>&1 &
