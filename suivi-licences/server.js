// Suivi des échéances de licences / abonnements
// Serveur Node sans framework (http natif) + nodemailer pour le relais SMTP.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const PORT = parseInt(process.env.PORT || '8091', 10);
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'data.json');
const PUBLIC_DIR = path.join(__dirname, 'public');
const TZ = process.env.TZ || 'Europe/Paris';

// ---------- Données ----------
const DEFAULT_CONFIG = {
  smtp: {
    host: 'smtp.example.org',
    port: 25,
    secure: false,        // true = SSL direct (465) ; false = clair ou STARTTLS (25/587)
    user: '',
    pass: '',
    ignoreTLSErrors: true // relais interne : certificat souvent auto-signé
  },
  expediteur: 'Suivi licences <noreply@example.org>',
  destinataires: [],      // liste globale (licences sans routage de service)
  // Routage par service : les licences dont le champ « Service » correspond sont envoyées
  // UNIQUEMENT à ces destinataires (en plus des destinataires propres à la licence).
  routageServices: {
    '53': ['chef.service53@example.org', 'responsable@example.org'],
    '58': ['responsable@example.org', 'chef.service58@example.org']
  },
  alerteJours: 60,        // 2 mois avant l'échéance
  relanceJours: 7,        // puis une relance tous les N jours tant que la commande n'est pas faite
  heureEnvoi: '08:00',
  urlAppli: ''            // ex: http://nas:8091 — ajouté en pied de mail si renseigné
};

let db = null;

function seed() {
  // Données de démonstration fictives : l'échéance est calculée par rapport à aujourd'hui
  // pour illustrer les différents statuts (expiré, urgent, à anticiper, OK).
  const base = todayStr();
  const debutPour = (joursAvantEcheance, duree = 1) => {
    const [y, m, d] = base.split('-').map(Number);
    const t = new Date(Date.UTC(y, m - 1, d + joursAvantEcheance));
    return addYears(t.toISOString().slice(0, 10), -duree);
  };
  const L = (nom, editeur, jours, cout, extra = {}) => {
    const duree = extra.duree || 1;
    return {
      id: crypto.randomUUID(), nom, editeur, nomenclature: '', debut: debutPour(jours, duree), duree, cout,
      service: '', groupe: '', commentaire: '', destinatairesExtra: [],
      relanceActive: true, derniereRelance: null, historique: [], ...extra
    };
  };
  return {
    config: DEFAULT_CONFIG,
    journal: [],
    licences: [
      L('Antivirus poste de travail', 'Editeur Exemple A', -20, 4200.00, { service: '53' }),
      L('Maintenance logiciel RH', 'Editeur Exemple B', 12, 5800.50, { service: '58' }),
      L('Abonnement visioconférence', 'Fournisseur Exemple C', 45, 3100.00),
      L('Support base de données', 'Editeur Exemple D', 130, 1250.00, { duree: 2 }),
      L('Licences bureautique', 'Fournisseur Exemple E', 220, 9800.00, { duree: 3 }),
      L('Certificats SSL', 'Fournisseur Exemple F', 300, 450.00)
    ]
  };
}

function load() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  if (fs.existsSync(DATA_FILE)) {
    db = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    db.config = { ...DEFAULT_CONFIG, ...db.config, smtp: { ...DEFAULT_CONFIG.smtp, ...(db.config || {}).smtp } };
    db.journal = db.journal || [];
  } else {
    db = seed();
    save();
  }
}
function save() {
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(db, null, 2));
  fs.renameSync(tmp, DATA_FILE);
}

// ---------- Dates (calcul en jours calendaires, fuseau Europe/Paris) ----------
// Indépendant de la langue/ICU du Node (certains Node de NAS n'ont pas les locales complètes)
function nowParts() {
  const d = new Date();
  try {
    const f = new Intl.DateTimeFormat('en-US', {
      timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
    });
    const o = {};
    f.formatToParts(d).forEach(x => { o[x.type] = x.value; });
    if (o.hour === '24') o.hour = '00';
    if (/^\d{4}$/.test(o.year) && /^\d{1,2}$/.test(o.month) && /^\d{1,2}$/.test(o.day) && /^\d{1,2}$/.test(o.hour)) return o;
  } catch (e) { /* repli ci-dessous */ }
  const pad = n => String(n).padStart(2, '0');
  return { year: String(d.getFullYear()), month: pad(d.getMonth() + 1), day: pad(d.getDate()), hour: pad(d.getHours()), minute: pad(d.getMinutes()) };
}
function todayStr() {
  const p = nowParts();
  return `${p.year}-${p.month.padStart(2, '0')}-${p.day.padStart(2, '0')}`; // YYYY-MM-DD
}
function nowHHMM() {
  const p = nowParts();
  return `${p.hour.padStart(2, '0')}:${p.minute.padStart(2, '0')}`;
}
function toUTC(s) { const [y, m, d] = s.split('-').map(Number); return Date.UTC(y, m - 1, d); }
function diffDays(a, b) { return Math.round((toUTC(a) - toUTC(b)) / 86400000); } // a - b
function addYears(s, n) {
  const [y, m, d] = s.split('-').map(Number);
  const t = new Date(Date.UTC(y + n, m - 1, d));
  if (t.getUTCMonth() !== (m - 1 + 12) % 12) t.setUTCDate(0); // 29/02 -> 28/02
  return t.toISOString().slice(0, 10);
}
function echeance(l) { return addYears(l.debut, l.duree); }
function joursRestants(l, today = todayStr()) { return diffDays(echeance(l), today); }
function fr(s) { return s ? s.split('-').reverse().join('/') : ''; }
function euro(n) { return n == null ? '' : n.toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' }); }
function esc(s) { return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

function statut(j, alerte) {
  if (!Number.isFinite(j)) return 'Date invalide';
  if (j < 0) return 'Expiré';
  if (j <= 30) return 'Urgent — BC à faire';
  if (j <= alerte) return 'À anticiper';
  return 'OK';
}

// ---------- Mail ----------
function transport() {
  const s = db.config.smtp;
  const opts = {
    host: s.host, port: Number(s.port), secure: !!s.secure,
    tls: { rejectUnauthorized: !s.ignoreTLSErrors },
    connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 30000
  };
  if (s.user) opts.auth = { user: s.user, pass: s.pass };
  return nodemailer.createTransport(opts);
}

function destinatairesPour(licences) {
  const set = new Set((db.config.destinataires || []).map(x => x.trim()).filter(Boolean));
  licences.forEach(l => (l.destinatairesExtra || []).forEach(x => x.trim() && set.add(x.trim())));
  return [...set];
}

function buildMail(items, today, titre) {
  const alerte = db.config.alerteJours;
  const rows = items.map(l => {
    const j = joursRestants(l, today);
    const st = statut(j, alerte);
    const color = j < 0 ? '#5b1a1a' : j <= 30 ? '#c0392b' : '#b9770e';
    return `<tr>
      <td style="padding:6px 10px;border:1px solid #ddd"><b>${esc(l.nom)}</b></td>
      <td style="padding:6px 10px;border:1px solid #ddd">${esc(l.editeur)}</td>
      <td style="padding:6px 10px;border:1px solid #ddd">${fr(echeance(l))}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;text-align:right;color:${color};font-weight:bold">${j}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;color:${color}">${esc(st)}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;text-align:right">${esc(euro(l.cout))}</td>
    </tr>`;
  }).join('');
  const total = items.reduce((a, l) => a + (l.cout || 0), 0);
  const lien = db.config.urlAppli ? `<p>Marquer les commandes comme faites : <a href="${esc(db.config.urlAppli)}">${esc(db.config.urlAppli)}</a></p>` : '';
  const html = `<div style="font-family:Segoe UI,Arial,sans-serif;font-size:14px;color:#222">
    <p>Bonjour,</p>
    <p>${esc(titre)}</p>
    <table style="border-collapse:collapse;font-size:13px">
      <thead><tr style="background:#1b3a5f;color:#fff">
        <th style="padding:6px 10px;text-align:left">Licence / abonnement</th>
        <th style="padding:6px 10px;text-align:left">Éditeur</th>
        <th style="padding:6px 10px;text-align:left">Échéance</th>
        <th style="padding:6px 10px">Jours restants</th>
        <th style="padding:6px 10px;text-align:left">Statut</th>
        <th style="padding:6px 10px">Coût</th></tr></thead>
      <tbody>${rows}</tbody>
      <tfoot><tr><td colspan="5" style="padding:6px 10px;text-align:right"><b>Total</b></td><td style="padding:6px 10px;text-align:right"><b>${esc(euro(total))}</b></td></tr></tfoot>
    </table>
    ${lien}
    <p style="color:#777;font-size:12px">Relance automatique. Une relance est renvoyée tous les ${db.config.relanceJours} jours tant que la commande n'est pas marquée comme faite.</p>
  </div>`;
  const text = items.map(l => `- ${l.nom} (${l.editeur}) : échéance ${fr(echeance(l))}, J${joursRestants(l, today) >= 0 ? '-' : '+'}${Math.abs(joursRestants(l, today))}`).join('\n');
  return { html, text: `${titre}\n\n${text}` };
}

async function envoyer(items, titre, sujet, forceDest) {
  const to = forceDest || destinatairesPour(items);
  if (!to.length) throw new Error('Aucun destinataire configuré.');
  const { html, text } = buildMail(items, todayStr(), titre);
  await transport().sendMail({ from: db.config.expediteur, to, subject: sujet, html, text });
  return to;
}

function journaliser(entry) {
  db.journal.unshift({ date: new Date().toISOString(), ...entry });
  db.journal = db.journal.slice(0, 100);
}

// ---------- Routage par service ----------
const normSvc = x => String(x ?? '').trim().toLowerCase();
const digits = x => String(x ?? '').replace(/\D/g, '');
// Renvoie la clé de routage correspondant au service d'une licence (ou null)
function routeKey(service) {
  const r = db.config.routageServices || {};
  const sv = normSvc(service);
  if (!sv) return null;
  for (const k of Object.keys(r)) {
    if (normSvc(k) === sv) return k;
    const dk = digits(k), ds = digits(service);
    if (dk && dk === ds) return k;           // « Service 53 » ou « 53 » → clé « 53 »
  }
  return null;
}
function destsGroupe(key, items) {
  const base = key ? (db.config.routageServices[key] || []) : (db.config.destinataires || []);
  const set = new Set(base.map(x => x.trim()).filter(Boolean));
  items.forEach(l => (l.destinatairesExtra || []).forEach(x => x.trim() && set.add(x.trim())));
  return [...set];
}

// Vérification quotidienne : licences dans la fenêtre d'alerte, non commandées, relance due.
// Un mail par groupe de destinataires (service routé ou liste globale).
async function verifier({ force = false } = {}) {
  const today = todayStr();
  const { alerteJours, relanceJours } = db.config;
  const dues = db.licences.filter(l => {
    if (!l.relanceActive) return false;
    if (joursRestants(l, today) > alerteJours) return false;
    if (force) return true;
    return !l.derniereRelance || diffDays(today, l.derniereRelance) >= relanceJours;
  }).sort((a, b) => joursRestants(a, today) - joursRestants(b, today));
  if (!dues.length) return { envoye: false, nb: 0 };

  const groupes = new Map();
  dues.forEach(l => {
    const k = routeKey(l.service) || '';
    if (!groupes.has(k)) groupes.set(k, []);
    groupes.get(k).push(l);
  });

  let nbEnvoyes = 0; const erreurs = []; const tous = new Set();
  for (const [key, items] of groupes) {
    const label = key ? `service ${key}` : '';
    const titre = `${items.length} licence(s) / abonnement(s)${label ? ' du ' + label : ''} arrive(nt) à échéance dans moins de ${alerteJours} jours (ou sont expirés) et nécessitent une commande :`;
    const sujet = `[SIC] Renouvellements à commander${label ? ' — ' + label : ''} — ${items.length} licence(s)`;
    const to = destsGroupe(key, items);
    try {
      await envoyer(items, titre, sujet, to);
      items.forEach(l => { l.derniereRelance = today; });
      to.forEach(x => tous.add(x));
      nbEnvoyes += items.length;
      journaliser({ type: 'relance', ok: true, nb: items.length, destinataires: to, detail: label, licences: items.map(l => l.nom) });
    } catch (e) {
      erreurs.push(`${label || 'global'} : ${e.message}`);
      journaliser({ type: 'relance', ok: false, nb: items.length, detail: label, erreur: e.message });
    }
    save();
  }
  if (erreurs.length && !nbEnvoyes) throw new Error(erreurs.join(' | '));
  return { envoye: nbEnvoyes > 0, nb: nbEnvoyes, destinataires: [...tous], erreurs };
}

let lastRunDay = null;
async function tick() {
  const today = todayStr();
  if (lastRunDay === today) return;
  if (nowHHMM() < db.config.heureEnvoi) return;
  lastRunDay = today;
  try {
    const r = await verifier();
    console.log(`[${new Date().toISOString()}] vérification : ${r.nb} licence(s), envoyé=${r.envoye}`);
  } catch (e) {
    console.error('Erreur envoi relance :', e.message);
    lastRunDay = null; // réessaie au prochain passage (15 min)
  }
}

// ---------- API ----------
function view(l) {
  const j = joursRestants(l);
  return { ...l, echeance: echeance(l), joursRestants: j, statut: statut(j, db.config.alerteJours) };
}
function clean(body, existing) {
  const duree = parseInt(body.duree, 10);
  if (![1, 2, 3].includes(duree)) throw new Error('Durée invalide (1, 2 ou 3 ans).');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(body.debut || '')) throw new Error('Date de début invalide.');
  if (!String(body.nom || '').trim()) throw new Error('Le nom est obligatoire.');
  const cout = body.cout === '' || body.cout == null ? null : Number(body.cout);
  if (cout != null && Number.isNaN(cout)) throw new Error('Coût invalide.');
  const extra = (Array.isArray(body.destinatairesExtra) ? body.destinatairesExtra : [])
    .map(s => String(s).trim()).filter(Boolean);
  return {
    nom: String(body.nom).trim(), editeur: String(body.editeur || '').trim(),
    nomenclature: String(body.nomenclature || '').trim(), debut: body.debut, duree, cout,
    service: String(body.service || '').trim(), groupe: String(body.groupe || '').trim(),
    commentaire: String(body.commentaire || '').trim(), destinatairesExtra: extra,
    relanceActive: body.relanceActive !== false,
    ...(existing ? {} : { derniereRelance: null, historique: [] })
  };
}

const EMAIL_RE = /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;

async function api(req, res, url, body) {
  const m = (re) => url.pathname.match(re);
  let r;
  if (req.method === 'GET' && url.pathname === '/api/state') {
    return send(res, 200, { today: todayStr(), config: db.config, journal: db.journal, licences: db.licences.map(view) });
  }
  if (req.method === 'POST' && url.pathname === '/api/licences') {
    const l = { id: crypto.randomUUID(), ...clean(body) };
    db.licences.push(l); save();
    return send(res, 201, view(l));
  }
  if ((r = m(/^\/api\/licences\/([\w-]+)$/))) {
    const l = db.licences.find(x => x.id === r[1]);
    if (!l) return send(res, 404, { error: 'Introuvable' });
    if (req.method === 'PUT') {
      const before = echeance(l);
      Object.assign(l, clean(body, l));
      // si la date d'échéance change, on repart sur un nouveau cycle de relance
      if (echeance(l) !== before) l.derniereRelance = null;
      save(); return send(res, 200, view(l));
    }
    if (req.method === 'DELETE') {
      db.licences = db.licences.filter(x => x.id !== l.id); save();
      return send(res, 200, { ok: true });
    }
  }
  // Commande faite : le nouveau cycle démarre à l'ancienne échéance (continuité du contrat)
  if (req.method === 'POST' && (r = m(/^\/api\/licences\/([\w-]+)\/commande$/))) {
    const l = db.licences.find(x => x.id === r[1]);
    if (!l) return send(res, 404, { error: 'Introuvable' });
    const ancienne = echeance(l);
    const nouveauDebut = body.debut && /^\d{4}-\d{2}-\d{2}$/.test(body.debut) ? body.debut : ancienne;
    const nouvelleDuree = [1, 2, 3].includes(parseInt(body.duree, 10)) ? parseInt(body.duree, 10) : l.duree;
    const nouveauCout = body.cout === '' || body.cout == null ? l.cout : Number(body.cout);
    l.historique = l.historique || [];
    l.historique.unshift({ date: todayStr(), ancienDebut: l.debut, ancienneDuree: l.duree, ancienCout: l.cout, ancienneEcheance: ancienne });
    l.debut = nouveauDebut; l.duree = nouvelleDuree; l.cout = Number.isNaN(nouveauCout) ? l.cout : nouveauCout;
    l.derniereRelance = null;
    journaliser({ type: 'commande', ok: true, licences: [l.nom], detail: `Nouvelle échéance ${fr(echeance(l))}` });
    save(); return send(res, 200, view(l));
  }
  if (req.method === 'POST' && url.pathname === '/api/config') {
    const c = body;
    const dest = (Array.isArray(c.destinataires) ? c.destinataires : []).map(s => String(s).trim()).filter(Boolean);
    const bad = dest.filter(x => !EMAIL_RE.test(x));
    if (bad.length) return send(res, 400, { error: 'Adresse(s) invalide(s) : ' + bad.join(', ') });
    if (!/^\d{2}:\d{2}$/.test(c.heureEnvoi || '')) return send(res, 400, { error: 'Heure invalide (HH:MM).' });
    const routage = {};
    for (const [k, v] of Object.entries(c.routageServices || {})) {
      const key = String(k).trim();
      const list = (Array.isArray(v) ? v : []).map(x => String(x).trim()).filter(Boolean);
      if (!key) continue;
      const badR = list.filter(x => !EMAIL_RE.test(x));
      if (badR.length) return send(res, 400, { error: `Service ${key} — adresse(s) invalide(s) : ` + badR.join(', ') });
      routage[key] = list;
    }
    db.config = {
      ...db.config,
      destinataires: dest,
      routageServices: routage,
      alerteJours: Math.max(1, parseInt(c.alerteJours, 10) || 60),
      relanceJours: Math.max(1, parseInt(c.relanceJours, 10) || 7),
      heureEnvoi: c.heureEnvoi,
      expediteur: String(c.expediteur || db.config.expediteur).trim(),
      urlAppli: String(c.urlAppli || '').trim(),
      smtp: {
        host: String(c.smtp?.host || '').trim(), port: parseInt(c.smtp?.port, 10) || 25,
        secure: !!c.smtp?.secure, ignoreTLSErrors: c.smtp?.ignoreTLSErrors !== false,
        user: String(c.smtp?.user || '').trim(),
        // mot de passe : on garde l'ancien si le champ est laissé vide
        pass: c.smtp?.pass ? String(c.smtp.pass) : db.config.smtp.pass
      }
    };
    save(); return send(res, 200, db.config);
  }
  if (req.method === 'POST' && url.pathname === '/api/test-mail') {
    const to = db.config.destinataires;
    if (!to.length) return send(res, 400, { error: 'Ajoute au moins un destinataire dans les paramètres.' });
    const exemple = db.licences.slice().sort((a, b) => joursRestants(a) - joursRestants(b)).slice(0, 2);
    try {
      await envoyer(exemple, 'Ceci est un mail de TEST du suivi des licences (exemple de contenu).', '[SIC] TEST — Suivi des licences', to);
      journaliser({ type: 'test', ok: true, destinataires: to });
      save(); return send(res, 200, { ok: true, destinataires: to });
    } catch (e) {
      journaliser({ type: 'test', ok: false, erreur: e.message }); save();
      return send(res, 502, { error: 'Échec SMTP : ' + e.message });
    }
  }
  if (req.method === 'POST' && url.pathname === '/api/relance-maintenant') {
    try { return send(res, 200, await verifier({ force: true })); }
    catch (e) { return send(res, 502, { error: 'Échec SMTP : ' + e.message }); }
  }
  return send(res, 404, { error: 'Route inconnue' });
}

function send(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname.startsWith('/api/')) {
    let raw = '';
    req.on('data', c => { raw += c; if (raw.length > 1e6) req.destroy(); });
    req.on('end', async () => {
      let body = {};
      try { body = raw ? JSON.parse(raw) : {}; } catch { return send(res, 400, { error: 'JSON invalide' }); }
      try { await api(req, res, url, body); }
      catch (e) { send(res, 400, { error: e.message }); }
    });
    return;
  }
  const file = url.pathname === '/' ? '/index.html' : url.pathname;
  const full = path.join(PUBLIC_DIR, path.normalize(file));
  if (!full.startsWith(PUBLIC_DIR) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    res.writeHead(404); return res.end('Not found');
  }
  res.writeHead(200, { 'Content-Type': full.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/octet-stream' });
  fs.createReadStream(full).pipe(res);
});

load();
server.listen(PORT, () => console.log(`Suivi licences sur http://0.0.0.0:${PORT} (données : ${DATA_FILE})`));
setInterval(tick, 15 * 60 * 1000);
setTimeout(tick, 5000);
