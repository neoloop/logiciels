# License & subscription tracker

🇬🇧 English · 🇫🇷 [Français](README.md)

A small self-hosted web app to **track software license, maintenance and subscription renewals** and **send e-mail reminders** when an order has to be placed. No database, no framework: one Node.js server and one JSON file.

> **Note:** the user interface is currently in French. The code is small and every label is in `public/index.html`, so translations and i18n contributions are welcome.

## Screenshots

Dashboard with statuses, counters and the amount to order:

![Dashboard](docs/screenshots/01-tableau.png)

Adding software: the end of the commitment is computed automatically from the chosen term (1, 2 or 3 years):

![Add a license](docs/screenshots/02-ajout-licence.png)

"Commande faite" (order placed): the counter restarts on a new period and reminders stop:

![Order placed](docs/screenshots/03-commande-faite.png)

Settings: recipients, per-department routing, SMTP and sending log:

![Settings](docs/screenshots/04-parametres.png)

Reminder e-mail received by the recipients of the relevant department:

![Reminder e-mail](docs/screenshots/05-mail-relance.png)

## Features

- **Commitment term** of 1, 2 or 3 years: the end date is computed automatically from the start of the period.
- **Automatic statuses**: `OK`, `À anticiper` (inside the alert window, 60 days by default), `Urgent` (30 days or less), `Expiré` (expired).
- **E-mail reminders** through an SMTP relay: a first mail at D-60 (configurable), then a reminder every 7 days (configurable) until the order is marked as done.
- **"✔ Commande faite" button**: starts a new period (by default at the previous end date), resets the counter, stops the reminders and keeps the history.
- **Several recipients** with **per-department routing**: licenses of a department (e.g. `53`, `58`) are sent to dedicated recipients, in a separate mail. Extra recipients can also be set per license.
- Add / edit / delete software, search, sort, filter by status, CSV export.
- "Relancer maintenant" (send reminders now) button, test mail and sending log.

## Installation

The app fits in a single folder: `server.js`, `public/index.html` and a data file `data/data.json` created on first launch. It needs **Node.js 18 or later** and network access to an **SMTP relay** to send mail.

Pick your setup:

| Environment | Section |
|---|---|
| Synology NAS (DSM) | [Installation on a Synology NAS](#installation-on-a-synology-nas) |
| Linux or macOS server / workstation | [Linux / macOS](#linux--macos) |
| Windows | [Windows](#windows) |
| Docker | [Docker](#docker) |

In every case, finish with the [first-time setup](#first-time-setup).

### Installation on a Synology NAS

**1. Install Node.js.** In DSM: *Package Center* > search **Node.js** (v18 or later) > Install.

**2. Enable SSH.** *Control Panel* > *Terminal & SNMP* > tick *Enable SSH service*. Then connect from a terminal:

```bash
ssh your-user@nas-address
```

**3. Copy the app to the NAS.** Download this repository and drop the `suivi-licences` folder into a shared folder, for example `/volume1/web/suivi-licences` (using *File Station*). Check:

```bash
cd /volume1/web/suivi-licences
ls
```

You should see `server.js`, `package.json` and the `public` folder.

**4. Install the dependency** (nodemailer, used to send mail):

```bash
npm install --omit=dev
```

> **NAS without Internet access?** Run `npm install --omit=dev` on a PC, then copy the resulting `node_modules` folder into the app folder on the NAS. The dependency is pure JavaScript, so it works on any platform.

> **Heads-up:** `npm install` can take a minute or two. Wait for the shell prompt to come back before typing the next command, otherwise your input gets mixed into the output.

**5. Test in the foreground** (**always set the port** in the command):

```bash
PORT=8091 node server.js
```

The message `Suivi licences sur http://0.0.0.0:8091` should appear. Open `http://nas-address:8091` in a browser. Stop with `Ctrl+C`.

> **Always write `PORT=...` in the command.** If another app on the NAS left a `PORT` variable in your session, the server silently picks it up and may take another application's port. The startup message shows the port actually used: check it.

**6. Run in the background** so the server survives closing SSH:

```bash
cd /volume1/web/suivi-licences
PORT=8091 nohup node server.js >> suivi.log 2>&1 &
sleep 2
curl -s http://127.0.0.1:8091/api/state | head -c 100
```

The beginning of a JSON document (`{"today":"..."`) confirms the server is answering.

**7. Autostart and restart on crash.** The `lancer.sh` script checks that the server answers and restarts it otherwise. Schedule it every 5 minutes: *Control Panel* > *Task Scheduler* > *Create* > *Scheduled Task* > *User-defined script*:

- **User**: the same user that installed the app
- **Schedule**: daily, with *Repeat* every **5 minutes**, all day
- **Script**:

```bash
NODE=/usr/local/bin/node PORT=8091 sh /volume1/web/suivi-licences/lancer.sh
```

Find the exact Node path with `which node` (over SSH). Task Scheduler does not have the same `PATH` as an SSH session, hence the full path.

**8. Firewall.** If the page is unreachable from another machine while `curl` works on the NAS: *Control Panel* > *Security* > *Firewall* > allow port `8091` for your local network.

**Stop or restart only this app** (without touching other Node apps on the NAS):

```bash
for p in /proc/[0-9]*; do [ "$(readlink $p/cwd)" = /volume1/web/suivi-licences ] && kill ${p#/proc/}; done
sh /volume1/web/suivi-licences/lancer.sh
```

> `pgrep` and `pkill` do not exist on DSM, and `pkill -f "node server.js"` would stop **all** Node apps. The command above only targets this app's folder.

### Linux / macOS

```bash
git clone https://github.com/neoloop/logiciels.git
cd logiciels/suivi-licences
npm install --omit=dev
PORT=8091 node server.js
```

For a permanent setup on Linux with systemd, create `/etc/systemd/system/suivi-licences.service`:

```ini
[Unit]
Description=License tracker
After=network.target

[Service]
WorkingDirectory=/opt/suivi-licences
Environment=PORT=8091
Environment=TZ=Europe/Paris
ExecStart=/usr/bin/node server.js
Restart=always
User=suivi

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now suivi-licences
```

Without systemd, `lancer.sh` scheduled in cron every 5 minutes does the same job:

```cron
*/5 * * * * PORT=8091 /opt/suivi-licences/lancer.sh
```

### Windows

1. Install [Node.js LTS](https://nodejs.org/).
2. Download this repository, open a PowerShell terminal in the `suivi-licences` folder, then:

```powershell
npm install --omit=dev
$env:PORT = 8091
node server.js
```

For automatic startup, create a Windows *Task Scheduler* task (*At startup* trigger) that runs `node.exe server.js` in the app folder, or use a service manager such as [NSSM](https://nssm.cc/) or `pm2`.

### Docker

```bash
cd suivi-licences
docker compose up -d --build
```

Port `8091` is published and data is kept in `./data` (mounted volume). To change the port, edit `ports` in `docker-compose.yml`.

## First-time setup

Open `http://server-address:8091`, then **⚙ Paramètres & mails** (Settings & mails):

1. **SMTP server**: address and port of your mail relay (often `25` for an internal relay, `587` with authentication, `465` with *SSL direct* ticked). Fill in the user and password only if the relay requires it.
2. **Sender**: an address accepted by the relay (some relays only allow certain sender addresses).
3. **Recipients**: the addresses that receive the reminders, one per line.
4. **Per-department routing** (optional): so that a department receives its own reminders, add one line per department as `53 : head@example.org, manager@example.org`. Licenses whose **Service** field equals `53` are then sent only to those addresses, in a separate mail.
5. **App URL**: the address of the app, added as a link in the mails so people can mark orders as done.
6. Click **Envoyer un mail de test** (send a test mail) to validate the relay. Sending errors appear in the *Journal des envois* (sending log) at the bottom of the window.
7. **Enregistrer** (save).

The sample licenses are only there for testing: delete them (*Modifier* > *Supprimer*), then add the real ones with **+ Nouveau logiciel**. Fill in the **Service** field of the licenses concerned by routing.

From then on, a mail is sent every day at the configured time (08:00 by default) for licenses less than 60 days from their end date, and repeated every 7 days until someone clicks **✔ Commande faite**.

## Updating

Replace `server.js` and the `public/` folder with the new ones, **without touching the `data/` folder**, then restart the server (see above). With git:

```bash
git pull
npm install --omit=dev
```

A browser holding the old page in cache refreshes with `Ctrl+F5`.

## Backup

The whole state (licenses, settings, log) lives in `data/data.json`. Copy it regularly, for example with your NAS backup. To restore: stop the server, put the file back, restart.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `ERR_CONNECTION_REFUSED` in the browser | The server is not running. Start it by hand (`PORT=8091 node server.js`) and read the error. |
| `Cannot find module 'nodemailer'` | `npm install --omit=dev` was not run in this folder (or was interrupted). |
| `EADDRINUSE` | The port is already in use. Pick another one: `PORT=8092 node server.js`. |
| Server starts on another port than expected (`8090`...) | A `PORT` variable already exists in the session. Always write `PORT=8091` in the command. |
| Server stops when SSH closes | Start it with `nohup ... &` and set up the `lancer.sh` scheduled task. |
| `node: command not found` in the scheduled task | Give the full path: `NODE=/usr/local/bin/node`. |
| Test mail fails | Check the SMTP server and port, SSL mode, authentication, and that the sender is allowed on the relay. The exact message is in the sending log. |
| Remaining days or statuses are wrong | Check the server date and time zone (`date`). The time zone is set with the `TZ` variable. |
| No mail arrives although the test works | Check that the **Service** field of the licenses matches a routing code, and that at least one license is less than 60 days from its end date. The **✉ Relancer maintenant** button forces a send. |

## Configuration

| Setting | Default |
|---|---|
| SMTP server | `smtp.example.org:25`, no authentication, certificate not verified |
| Alert before end date | 60 days |
| Reminder every | 7 days |
| Daily sending time | 08:00 (`TZ` time zone, `Europe/Paris` by default) |

Environment variables: `PORT` (8091), `DATA_DIR` (`./data`), `TZ`.

## Security

The app **has no authentication**: it is meant for an internal network. Do not expose it to the Internet without an authenticating reverse proxy. The SMTP password, if any, is stored in clear text in `data/data.json` (folder excluded from the repository).

## License

[MIT](../LICENSE).

## Support the project

This app is free and open source. If it saves you time, you can buy me a coffee to help me maintain and improve it. Entirely optional, but always appreciated!

[![Buy me a coffee](https://img.shields.io/badge/Buy_me_a_coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/neoloop)

An idea, a bug? Open an [issue](https://github.com/neoloop/logiciels/issues).
