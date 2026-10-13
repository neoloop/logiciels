// License & subscription tracker / Suivi des échéances de licences et abonnements
// Plain Node.js server (native http) + nodemailer for the SMTP relay.
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

// Optional access protection managed from the environment (e.g. Docker).
// If APP_PASSWORD is set it takes precedence over the password set from the UI.
const ENV_USER = process.env.APP_USER || 'admin';
const ENV_PW = process.env.APP_PASSWORD || '';
const TRUST_PROXY = !!process.env.TRUST_PROXY;
const SESSION_MS = 12 * 3600 * 1000;
const COOKIE = 'licsid';

// ---------- Données / Data ----------
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
  sujetPrefixe: '[Licences]',
  langue: 'fr',           // langue des e-mails : 'fr' ou 'en'
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
  fs.writeFileSync(tmp, JSON.stringify(db, null, 2), { mode: 0o600 });
  fs.renameSync(tmp, DATA_FILE);
}

// ---------- Textes serveur (mails, erreurs) / Server-side texts ----------
const I18N = {
  fr: {
    'st.ok': 'OK', 'st.soon': 'À anticiper', 'st.urgent': 'Urgent — BC à faire', 'st.expired': 'Expiré', 'st.invalid': 'Date invalide',
    'mail.hello': 'Bonjour,',
    'mail.title': (n, d, svc) => `${n} licence(s) / abonnement(s)${svc ? ` du service ${svc}` : ''} arrive(nt) à échéance dans moins de ${d} jours (ou sont expirés) et nécessitent une commande :`,
    'mail.subject': (p, n, svc) => `${p} Renouvellements à commander${svc ? ` — service ${svc}` : ''} — ${n} licence(s)`,
    'mail.test.title': 'Ceci est un mail de TEST du suivi des licences (exemple de contenu).',
    'mail.test.subject': p => `${p} TEST — Suivi des licences`,
    'mail.col.name': 'Licence / abonnement', 'mail.col.vendor': 'Éditeur', 'mail.col.end': 'Échéance',
    'mail.col.days': 'Jours restants', 'mail.col.status': 'Statut', 'mail.col.cost': 'Coût', 'mail.total': 'Total',
    'mail.link': 'Marquer les commandes comme faites :',
    'mail.footer': n => `Relance automatique. Une relance est renvoyée tous les ${n} jours tant que la commande n'est pas marquée comme faite.`,
    'mail.line': (name, vendor, end, j) => `- ${name} (${vendor}) : échéance ${end}, J${j >= 0 ? '-' : '+'}${Math.abs(j)}`,
    'err.duration': 'Durée invalide (1, 2 ou 3 ans).', 'err.startdate': 'Date de début invalide.', 'err.name': 'Le nom est obligatoire.',
    'err.cost': 'Coût invalide.', 'err.notfound': 'Introuvable', 'err.emails': l => 'Adresse(s) invalide(s) : ' + l,
    'err.time': 'Heure invalide (HH:MM).', 'err.svcemails': (k, l) => `Service ${k} — adresse(s) invalide(s) : ${l}`,
    'err.norecipient': 'Aucun destinataire configuré.', 'err.norecipient.test': 'Ajoute au moins un destinataire dans les paramètres.',
    'err.smtp': m => 'Échec SMTP : ' + m, 'err.route': 'Route inconnue', 'err.json': 'JSON invalide',
    'err.lang': 'Langue invalide.',
    'err.auth': 'Authentification requise.', 'err.badcreds': 'Identifiant ou mot de passe incorrect.',
    'err.locked': n => `Trop de tentatives. Réessayez dans ${n} minute(s).`,
    'err.pwshort': 'Mot de passe trop court (8 caractères minimum).', 'err.pwcurrent': 'Mot de passe actuel incorrect.',
    'err.user': "Identifiant invalide (lettres, chiffres, . _ @ -, 64 caractères maximum).",
    'err.env': "La protection est gérée par les variables d'environnement APP_USER / APP_PASSWORD du serveur.",
    'err.ctype': 'Content-Type application/json requis.', 'err.origin': 'Origine refusée.'
  },
  en: {
    'st.ok': 'OK', 'st.soon': 'Plan ahead', 'st.urgent': 'Urgent — order needed', 'st.expired': 'Expired', 'st.invalid': 'Invalid date',
    'mail.hello': 'Hello,',
    'mail.title': (n, d, svc) => `${n} license(s) / subscription(s)${svc ? ` of department ${svc}` : ''} expire(s) in less than ${d} days (or already expired) and need(s) to be ordered:`,
    'mail.subject': (p, n, svc) => `${p} Renewals to order${svc ? ` — department ${svc}` : ''} — ${n} license(s)`,
    'mail.test.title': 'This is a TEST mail from the license tracker (sample content).',
    'mail.test.subject': p => `${p} TEST — License tracker`,
    'mail.col.name': 'License / subscription', 'mail.col.vendor': 'Vendor', 'mail.col.end': 'End date',
    'mail.col.days': 'Days left', 'mail.col.status': 'Status', 'mail.col.cost': 'Cost', 'mail.total': 'Total',
    'mail.link': 'Mark orders as placed:',
    'mail.footer': n => `Automatic reminder. A reminder is sent every ${n} days until the order is marked as placed.`,
    'mail.line': (name, vendor, end, j) => `- ${name} (${vendor}): ends ${end}, D${j >= 0 ? '-' : '+'}${Math.abs(j)}`,
    'err.duration': 'Invalid term (1, 2 or 3 years).', 'err.startdate': 'Invalid start date.', 'err.name': 'The name is required.',
    'err.cost': 'Invalid cost.', 'err.notfound': 'Not found', 'err.emails': l => 'Invalid address(es): ' + l,
    'err.time': 'Invalid time (HH:MM).', 'err.svcemails': (k, l) => `Department ${k} — invalid address(es): ${l}`,
    'err.norecipient': 'No recipient configured.', 'err.norecipient.test': 'Add at least one recipient in the settings.',
    'err.smtp': m => 'SMTP failure: ' + m, 'err.route': 'Unknown route', 'err.json': 'Invalid JSON',
    'err.lang': 'Invalid language.',
    'err.auth': 'Authentication required.', 'err.badcreds': 'Incorrect username or password.',
    'err.locked': n => `Too many attempts. Try again in ${n} minute(s).`,
    'err.pwshort': 'Password too short (8 characters minimum).', 'err.pwcurrent': 'Current password is incorrect.',
    'err.user': 'Invalid username (letters, digits, . _ @ -, 64 characters max).',
    'err.env': 'Protection is managed by the server APP_USER / APP_PASSWORD environment variables.',
    'err.ctype': 'Content-Type application/json required.', 'err.origin': 'Origin rejected.'
  }
};
const normLang = l => (l === 'en' ? 'en' : 'fr');
function T(lang, key, ...a) {
  const v = (I18N[normLang(lang)][key] ?? I18N.fr[key]);
  return typeof v === 'function' ? v(...a) : v;
}
class ApiError extends Error {
  constructor(status, key, ...a) { super(key); this.status = status; this.key = key; this.args = a; }
}

// ---------- Dates (calcul en jours calendaires) ----------
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
// Formats sans dépendance à Intl : jj/mm/aaaa et 1 234,56 € (fr) ; AAAA-MM-JJ et €1,234.56 (en)
function fmtDate(lang, s) { return !s ? '' : (lang === 'en' ? s : s.split('-').reverse().join('/')); }
function fmtMoney(lang, n) {
  if (n == null || !Number.isFinite(n)) return '';
  const neg = n < 0 ? '-' : '';
  const [i, d] = Math.abs(n).toFixed(2).split('.');
  return lang === 'en'
    ? `${neg}€${i.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${d}`
    : `${neg}${i.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')},${d} €`;
}
function esc(s) { return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

function statutCode(j, alerte) {
  if (!Number.isFinite(j)) return 'invalid';
  if (j < 0) return 'expired';
  if (j <= 30) return 'urgent';
  if (j <= alerte) return 'soon';
  return 'ok';
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

function buildMail(items, today, titre) {
  const lang = normLang(db.config.langue);
  const alerte = db.config.alerteJours;
  const rows = items.map(l => {
    const j = joursRestants(l, today);
    const st = T(lang, 'st.' + statutCode(j, alerte));
    const color = j < 0 ? '#5b1a1a' : j <= 30 ? '#c0392b' : '#b9770e';
    return `<tr>
      <td style="padding:6px 10px;border:1px solid #ddd"><b>${esc(l.nom)}</b></td>
      <td style="padding:6px 10px;border:1px solid #ddd">${esc(l.editeur)}</td>
      <td style="padding:6px 10px;border:1px solid #ddd">${fmtDate(lang, echeance(l))}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;text-align:right;color:${color};font-weight:bold">${j}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;color:${color}">${esc(st)}</td>
      <td style="padding:6px 10px;border:1px solid #ddd;text-align:right">${esc(fmtMoney(lang, l.cout))}</td>
    </tr>`;
  }).join('');
  const total = items.reduce((a, l) => a + (l.cout || 0), 0);
  const lien = db.config.urlAppli ? `<p>${esc(T(lang, 'mail.link'))} <a href="${esc(db.config.urlAppli)}">${esc(db.config.urlAppli)}</a></p>` : '';
  const th = (k, left) => `<th style="padding:6px 10px${left ? ';text-align:left' : ''}">${esc(T(lang, k))}</th>`;
  const html = `<div style="font-family:Segoe UI,Arial,sans-serif;font-size:14px;color:#222">
    <p>${esc(T(lang, 'mail.hello'))}</p>
    <p>${esc(titre)}</p>
    <table style="border-collapse:collapse;font-size:13px">
      <thead><tr style="background:#1b3a5f;color:#fff">
        ${th('mail.col.name', 1)}${th('mail.col.vendor', 1)}${th('mail.col.end', 1)}${th('mail.col.days')}${th('mail.col.status', 1)}${th('mail.col.cost')}</tr></thead>
      <tbody>${rows}</tbody>
      <tfoot><tr><td colspan="5" style="padding:6px 10px;text-align:right"><b>${esc(T(lang, 'mail.total'))}</b></td><td style="padding:6px 10px;text-align:right"><b>${esc(fmtMoney(lang, total))}</b></td></tr></tfoot>
    </table>
    ${lien}
    <p style="color:#777;font-size:12px">${esc(T(lang, 'mail.footer', db.config.relanceJours))}</p>
  </div>`;
  const text = items.map(l => T(lang, 'mail.line', l.nom, l.editeur, fmtDate(lang, echeance(l)), joursRestants(l, today))).join('\n');
  return { html, text: `${titre}\n\n${text}` };
}

async function envoyer(items, titre, sujet, to) {
  if (!to || !to.length) throw new Error(T(db.config.langue, 'err.norecipient'));
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
  const lang = normLang(db.config.langue);
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
    const titre = T(lang, 'mail.title', items.length, alerteJours, key);
    const sujet = T(lang, 'mail.subject', db.config.sujetPrefixe, items.length, key);
    const to = destsGroupe(key, items);
    try {
      await envoyer(items, titre, sujet, to);
      items.forEach(l => { l.derniereRelance = today; });
      to.forEach(x => tous.add(x));
      nbEnvoyes += items.length;
      journaliser({ type: 'relance', ok: true, nb: items.length, destinataires: to, service: key, licences: items.map(l => l.nom) });
    } catch (e) {
      erreurs.push(`${key || 'global'} : ${e.message}`);
      journaliser({ type: 'relance', ok: false, nb: items.length, service: key, erreur: e.message });
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
    console.log(`[${new Date().toISOString()}] check: ${r.nb} license(s), sent=${r.envoye}`);
  } catch (e) {
    console.error('Reminder sending error:', e.message);
    lastRunDay = null; // réessaie au prochain passage (15 min)
  }
}

// ---------- Authentification ----------
const authEnabled = () => !!ENV_PW || !!(db.auth && db.auth.hash);
const authUser = () => (ENV_PW ? ENV_USER : (db.auth && db.auth.user) || null);

function sha(x) { return crypto.createHash('sha256').update(String(x)).digest(); }
function safeEq(a, b) { return crypto.timingSafeEqual(sha(a), sha(b)); }

function sessionKey() {
  if (!db.sessionSecret) { db.sessionSecret = crypto.randomBytes(32).toString('hex'); save(); }
  // en mode variable d'environnement, changer APP_PASSWORD invalide aussi les sessions
  return ENV_PW ? sha(db.sessionSecret + '|' + ENV_PW) : Buffer.from(db.sessionSecret, 'hex');
}
const sign = payload => crypto.createHmac('sha256', sessionKey()).update(payload).digest('hex');
function makeToken() { const exp = String(Date.now() + SESSION_MS); return exp + '.' + sign(exp); }
function validToken(tok) {
  if (!tok || typeof tok !== 'string') return false;
  const [exp, sig] = tok.split('.');
  if (!/^\d+$/.test(exp || '') || !sig || Number(exp) < Date.now()) return false;
  const a = Buffer.from(sig), b = Buffer.from(sign(exp));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
function parseCookies(req) {
  const o = {};
  (req.headers.cookie || '').split(';').forEach(p => {
    const i = p.indexOf('=');
    if (i > 0) { try { o[p.slice(0, i).trim()] = decodeURIComponent(p.slice(i + 1).trim()); } catch { /* ignore */ } }
  });
  return o;
}
const isAuthed = req => !authEnabled() || validToken(parseCookies(req)[COOKIE]);
const isHttps = req => !!req.socket.encrypted || req.headers['x-forwarded-proto'] === 'https';
function cookieHeader(req, value, maxAgeSec) {
  return `${COOKIE}=${encodeURIComponent(value)}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${maxAgeSec}${isHttps(req) ? '; Secure' : ''}`;
}
function checkCreds(user, pw) {
  if (ENV_PW) { const u = safeEq(user, ENV_USER), p = safeEq(pw, ENV_PW); return u && p; }
  const a = db.auth;
  const u = safeEq(user, a.user);
  const h = crypto.scryptSync(String(pw), Buffer.from(a.salt, 'hex'), 64);
  return crypto.timingSafeEqual(h, Buffer.from(a.hash, 'hex')) && u;
}
function setPassword(user, pw) {
  const salt = crypto.randomBytes(16);
  db.auth = { user, salt: salt.toString('hex'), hash: crypto.scryptSync(String(pw), salt, 64).toString('hex') };
  db.sessionSecret = crypto.randomBytes(32).toString('hex'); // invalide toutes les sessions existantes
  save();
}

// Anti brute-force : 5 échecs => blocage 5 minutes par adresse IP
const fails = new Map();
const LOCK_MS = 5 * 60 * 1000;
function clientIp(req) {
  if (TRUST_PROXY && req.headers['x-forwarded-for']) return String(req.headers['x-forwarded-for']).split(',')[0].trim();
  return req.socket.remoteAddress || '?';
}
function lockedMinutes(ip) {
  const f = fails.get(ip);
  return f && f.until > Date.now() ? Math.ceil((f.until - Date.now()) / 60000) : 0;
}
function registerFail(ip) {
  const f = fails.get(ip) || { n: 0, until: 0 };
  if (f.until && f.until <= Date.now()) { f.n = 0; f.until = 0; }
  f.n++;
  if (f.n >= 5) { f.until = Date.now() + LOCK_MS; f.n = 0; }
  fails.set(ip, f);
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

// ---------- API ----------
function view(l) {
  const j = joursRestants(l);
  const code = statutCode(j, db.config.alerteJours);
  return { ...l, echeance: echeance(l), joursRestants: j, statutCode: code, statut: T(db.config.langue, 'st.' + code) };
}
function clean(req, body, existing) {
  const L = req.lang;
  const duree = parseInt(body.duree, 10);
  if (![1, 2, 3].includes(duree)) throw new ApiError(400, 'err.duration');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(body.debut || '')) throw new ApiError(400, 'err.startdate');
  if (!String(body.nom || '').trim()) throw new ApiError(400, 'err.name');
  const cout = body.cout === '' || body.cout == null ? null : Number(body.cout);
  if (cout != null && Number.isNaN(cout)) throw new ApiError(400, 'err.cost');
  const extra = (Array.isArray(body.destinatairesExtra) ? body.destinatairesExtra : [])
    .map(s => String(s).trim()).filter(Boolean);
  void L;
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
const USER_RE = /^[\w.@-]{1,64}$/;

function publicConfig() {
  const c = JSON.parse(JSON.stringify(db.config));
  c.smtp.passSet = !!c.smtp.pass;   // le mot de passe SMTP n'est jamais renvoyé au navigateur
  c.smtp.pass = '';
  return c;
}
function authInfo() { return { enabled: authEnabled(), managedByEnv: !!ENV_PW, user: authUser() }; }

const PUBLIC_API = new Set(['/api/auth-status', '/api/login', '/api/logout']);

async function api(req, res, url, body) {
  const m = (re) => url.pathname.match(re);
  const L = req.lang;
  let r;

  // ----- Routes publiques (état d'authentification, connexion, déconnexion) -----
  if (req.method === 'GET' && url.pathname === '/api/auth-status') {
    const authed = isAuthed(req);
    return send(res, 200, { authRequired: authEnabled(), authenticated: authed, managedByEnv: !!ENV_PW, user: authed ? authUser() : null });
  }
  if (req.method === 'POST' && url.pathname === '/api/login') {
    if (!authEnabled()) return send(res, 200, { ok: true });
    const ip = clientIp(req);
    const lock = lockedMinutes(ip);
    if (lock) throw new ApiError(429, 'err.locked', lock);
    const ok = checkCreds(String(body.user ?? ''), String(body.password ?? ''));
    if (!ok) { registerFail(ip); await sleep(400); throw new ApiError(401, 'err.badcreds'); }
    fails.delete(ip);
    return send(res, 200, { ok: true }, { 'Set-Cookie': cookieHeader(req, makeToken(), SESSION_MS / 1000) });
  }
  if (req.method === 'POST' && url.pathname === '/api/logout') {
    return send(res, 200, { ok: true }, { 'Set-Cookie': cookieHeader(req, '', 0) });
  }

  // ----- Tout le reste exige une session quand la protection est active -----
  if (!isAuthed(req)) throw new ApiError(401, 'err.auth');

  if (req.method === 'POST' && url.pathname === '/api/auth/password') {
    if (ENV_PW) throw new ApiError(409, 'err.env');
    const user = String(body.user ?? (authUser() || 'admin')).trim();
    if (!USER_RE.test(user)) throw new ApiError(400, 'err.user');
    const pw = String(body.newPassword ?? '');
    if (pw.length < 8) throw new ApiError(400, 'err.pwshort');
    if (authEnabled() && !checkCreds(authUser(), String(body.currentPassword ?? ''))) {
      registerFail(clientIp(req)); await sleep(400);
      throw new ApiError(403, 'err.pwcurrent');
    }
    setPassword(user, pw);
    return send(res, 200, { ok: true, auth: authInfo() }, { 'Set-Cookie': cookieHeader(req, makeToken(), SESSION_MS / 1000) });
  }
  if (req.method === 'POST' && url.pathname === '/api/auth/disable') {
    if (ENV_PW) throw new ApiError(409, 'err.env');
    if (authEnabled() && !checkCreds(authUser(), String(body.currentPassword ?? ''))) {
      registerFail(clientIp(req)); await sleep(400);
      throw new ApiError(403, 'err.pwcurrent');
    }
    db.auth = null; db.sessionSecret = crypto.randomBytes(32).toString('hex'); save();
    return send(res, 200, { ok: true, auth: authInfo() }, { 'Set-Cookie': cookieHeader(req, '', 0) });
  }

  if (req.method === 'GET' && url.pathname === '/api/state') {
    return send(res, 200, { today: todayStr(), config: publicConfig(), auth: authInfo(), journal: db.journal, licences: db.licences.map(view) });
  }
  if (req.method === 'POST' && url.pathname === '/api/licences') {
    const l = { id: crypto.randomUUID(), ...clean(req, body) };
    db.licences.push(l); save();
    return send(res, 201, view(l));
  }
  if ((r = m(/^\/api\/licences\/([\w-]+)$/))) {
    const l = db.licences.find(x => x.id === r[1]);
    if (!l) throw new ApiError(404, 'err.notfound');
    if (req.method === 'PUT') {
      const before = echeance(l);
      Object.assign(l, clean(req, body, l));
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
    if (!l) throw new ApiError(404, 'err.notfound');
    const ancienne = echeance(l);
    const nouveauDebut = body.debut && /^\d{4}-\d{2}-\d{2}$/.test(body.debut) ? body.debut : ancienne;
    const nouvelleDuree = [1, 2, 3].includes(parseInt(body.duree, 10)) ? parseInt(body.duree, 10) : l.duree;
    const nouveauCout = body.cout === '' || body.cout == null ? l.cout : Number(body.cout);
    l.historique = l.historique || [];
    l.historique.unshift({ date: todayStr(), ancienDebut: l.debut, ancienneDuree: l.duree, ancienCout: l.cout, ancienneEcheance: ancienne });
    l.debut = nouveauDebut; l.duree = nouvelleDuree; l.cout = Number.isNaN(nouveauCout) ? l.cout : nouveauCout;
    l.derniereRelance = null;
    journaliser({ type: 'commande', ok: true, licences: [l.nom], echeance: echeance(l) });
    save(); return send(res, 200, view(l));
  }
  if (req.method === 'POST' && url.pathname === '/api/config') {
    const c = body;
    const dest = (Array.isArray(c.destinataires) ? c.destinataires : []).map(s => String(s).trim()).filter(Boolean);
    const bad = dest.filter(x => !EMAIL_RE.test(x));
    if (bad.length) throw new ApiError(400, 'err.emails', bad.join(', '));
    if (!/^\d{2}:\d{2}$/.test(c.heureEnvoi || '')) throw new ApiError(400, 'err.time');
    if (c.langue != null && !['fr', 'en'].includes(c.langue)) throw new ApiError(400, 'err.lang');
    const routage = {};
    for (const [k, v] of Object.entries(c.routageServices || {})) {
      const key = String(k).trim();
      const list = (Array.isArray(v) ? v : []).map(x => String(x).trim()).filter(Boolean);
      if (!key) continue;
      const badR = list.filter(x => !EMAIL_RE.test(x));
      if (badR.length) throw new ApiError(400, 'err.svcemails', key, badR.join(', '));
      routage[key] = list;
    }
    db.config = {
      ...db.config,
      destinataires: dest,
      routageServices: routage,
      langue: c.langue || db.config.langue,
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
    save(); return send(res, 200, publicConfig());
  }
  if (req.method === 'POST' && url.pathname === '/api/test-mail') {
    const to = db.config.destinataires;
    if (!to.length) throw new ApiError(400, 'err.norecipient.test');
    const lang = normLang(db.config.langue);
    const exemple = db.licences.slice().sort((a, b) => joursRestants(a) - joursRestants(b)).slice(0, 2);
    try {
      await envoyer(exemple, T(lang, 'mail.test.title'), T(lang, 'mail.test.subject', db.config.sujetPrefixe), to);
      journaliser({ type: 'test', ok: true, destinataires: to });
      save(); return send(res, 200, { ok: true, destinataires: to });
    } catch (e) {
      journaliser({ type: 'test', ok: false, erreur: e.message }); save();
      throw new ApiError(502, 'err.smtp', e.message);
    }
  }
  if (req.method === 'POST' && url.pathname === '/api/relance-maintenant') {
    try { return send(res, 200, await verifier({ force: true })); }
    catch (e) { throw new ApiError(502, 'err.smtp', e.message); }
  }
  void L;
  throw new ApiError(404, 'err.route');
}

const SEC_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"
};
function send(res, code, obj, headers = {}) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...SEC_HEADERS, ...headers });
  res.end(JSON.stringify(obj));
}
function sendError(req, res, e) {
  if (e instanceof ApiError) {
    return send(res, e.status, { error: T(req.lang, e.key, ...e.args), code: e.key });
  }
  console.error(e);
  return send(res, 400, { error: e.message });
}

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  req.lang = normLang(req.headers['x-lang'] || db.config.langue);
  if (url.pathname.startsWith('/api/')) {
    // Protection CSRF : cookie SameSite=Strict + JSON obligatoire + contrôle de l'origine
    if (req.method !== 'GET') {
      if (!String(req.headers['content-type'] || '').toLowerCase().includes('application/json')) return sendError(req, res, new ApiError(415, 'err.ctype'));
      const origin = req.headers.origin;
      if (origin) {
        let ok = false;
        try { const h = new URL(origin).host; ok = h === req.headers.host || h === req.headers['x-forwarded-host']; } catch { ok = false; }
        if (!ok) return sendError(req, res, new ApiError(403, 'err.origin'));
      }
    }
    let raw = '';
    req.on('data', c => { raw += c; if (raw.length > 1e6) req.destroy(); });
    req.on('end', async () => {
      let body = {};
      try { body = raw ? JSON.parse(raw) : {}; } catch { return sendError(req, res, new ApiError(400, 'err.json')); }
      try { await api(req, res, url, body); }
      catch (e) { sendError(req, res, e); }
    });
    return;
  }
  const file = url.pathname === '/' ? '/index.html' : url.pathname;
  const full = path.join(PUBLIC_DIR, path.normalize(file));
  if (!full.startsWith(PUBLIC_DIR) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    res.writeHead(404, SEC_HEADERS); return res.end('Not found');
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(full)] || 'application/octet-stream', 'Cache-Control': 'no-cache', ...SEC_HEADERS });
  fs.createReadStream(full).pipe(res);
});

load();
server.listen(PORT, () => {
  console.log(`Suivi licences sur http://0.0.0.0:${PORT} (données : ${DATA_FILE})`);
  console.log(authEnabled() ? `Access protection: ON (${ENV_PW ? 'environment' : 'password set in the app'})` : 'Access protection: OFF — set a password from the app (🔒) or with APP_PASSWORD');
});
setInterval(tick, 15 * 60 * 1000);
setTimeout(tick, 5000);
