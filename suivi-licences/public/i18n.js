// Interface translations (FR / EN). Add a language: copy a block and translate it.
(function () {
  const D = {
    fr: {
      'app.title': 'Suivi des licences', 'app.h1': 'Suivi des licences & abonnements',
      'btn.cfg': '⚙ Paramètres & mails', 'btn.add': '＋ Nouveau logiciel', 'btn.sec': '🔒 Sécurité', 'btn.logout': 'Déconnexion',
      'search.ph': 'Rechercher (nom, éditeur, service, groupe…)', 'btn.export': '⬇ Export CSV', 'btn.relance': '✉ Relancer maintenant',
      'btn.relance.tip': "Envoie maintenant le mail de relance pour toutes les licences dans la fenêtre d'alerte",
      'banner.noauth': "⚠ Aucune protection par mot de passe : toute personne qui accède à cette adresse peut tout modifier.",
      'banner.noauth.btn': 'Définir un mot de passe',
      'kpi.expired': 'Expirés', 'kpi.urgent': 'Urgent (≤ 30 j)', 'kpi.soon': 'À anticiper (≤ {0} j)', 'kpi.ok': 'OK',
      'kpi.toorder': 'À commander (fenêtre {0} j)',
      'col.nom': 'Licence / abonnement', 'col.editeur': 'Éditeur', 'col.nomenclature': 'Nomencl.', 'col.service': 'Service',
      'col.debut': 'Début', 'col.duree': 'Durée', 'col.echeance': 'Échéance', 'col.joursRestants': 'Jours restants',
      'col.statut': 'Statut', 'col.cout': 'Coût', 'col.groupe': 'Groupe',
      'st.ok': 'OK', 'st.soon': 'À anticiper', 'st.urgent': 'Urgent', 'st.expired': 'Expiré', 'st.invalid': 'Date invalide',
      'relance.off': 'relance off',
      'years.1': '1 an', 'years.n': '{0} ans',
      'btn.cmd': '✔ Commande faite', 'btn.cmd.tip': 'Commande passée : réinitialise le compteur', 'btn.edit': 'Modifier',
      'noresult': 'Aucun résultat',
      'legend': "Alerte mail {0} jours avant l'échéance, puis relance tous les {1} jours à {2} jusqu'à « Commande faite ». Destinataires : {3}.",
      'legend.none': '⚠ aucun configuré (⚙ Paramètres)',
      'lic.new': 'Nouveau logiciel', 'lic.edit': 'Modifier le logiciel',
      'lic.nom': 'Nom de la licence / abonnement *', 'lic.editeur': 'Éditeur / Fournisseur', 'lic.nomenclature': 'Nomenclature',
      'lic.nomenclature.ph': 'ex : 6156', 'lic.debut': 'Date de début de période *', 'lic.duree': "Durée d'engagement *",
      'lic.cout': 'Coût (€)', 'lic.service': 'Service (ex. 53, 58 — sert au routage des mails)', 'lic.groupe': 'Groupement',
      'lic.groupe.ph': 'DIR, OPS, GFOR…', 'lic.relance': 'Relance mail', 'lic.relance.on': 'Activée', 'lic.relance.off': 'Suspendue (ne pas relancer)',
      'lic.extra': 'Destinataires supplémentaires pour ce logiciel (séparés par virgule ou retour à la ligne)',
      'lic.extra.ph': "s'ajoutent à la liste globale", 'lic.comment': 'Commentaire',
      'lic.del': 'Supprimer', 'btn.cancel': 'Annuler', 'btn.save': 'Enregistrer', 'btn.close': 'Fermer',
      'calc.need': "Renseigne la date de début pour calculer l'échéance.",
      'calc.end': "Fin d'engagement calculée : {0}  ({1})", 'calc.in': 'dans {0} jours', 'calc.ago': 'expirée depuis {0} jours',
      'calc.newend': 'Nouvelle échéance : {0}  (dans {1} jours)',
      'cmd.title': '✔ Commande faite — réinitialiser le compteur',
      'cmd.intro': 'échéance actuelle {0} ({1} j).', 'cmd.debut': 'Nouveau début de période', 'cmd.duree': "Nouvelle durée d'engagement",
      'cmd.cout': 'Nouveau coût (€)',
      'cmd.hint': "Par défaut, le nouveau cycle démarre à l'ancienne échéance (continuité du contrat). La relance s'arrête et le compteur repart de zéro.",
      'cmd.ok': 'Valider la commande',
      'cfg.title': 'Paramètres des relances par mail',
      'cfg.dest': 'Destinataires des relances (un par ligne ou séparés par virgule) *',
      'cfg.routage': 'Routage par service — une ligne par service : <b>code : adresse1, adresse2</b> (ex. <code>53 : chef.service@example.org, responsable@example.org</code>)',
      'cfg.routage.hint': 'Les licences dont le champ « Service » vaut ce code partent <b>uniquement</b> vers ces adresses (un mail séparé par service). Les autres vont à la liste globale ci-dessus.',
      'cfg.alerte': "Prévenir X jours avant l'échéance", 'cfg.relance': 'Puis relancer tous les X jours', 'cfg.heure': "Heure d'envoi quotidienne",
      'cfg.url': "URL de l'appli (lien dans le mail)", 'cfg.lang': 'Langue des mails', 'cfg.exp': 'Expéditeur', 'cfg.host': 'Serveur SMTP', 'cfg.port': 'Port',
      'cfg.user': 'Utilisateur SMTP (vide = sans authentification)', 'cfg.pass': 'Mot de passe SMTP (vide = inchangé)',
      'cfg.pass.set': '•••••• (enregistré)', 'cfg.secure': 'SSL direct (port 465)', 'cfg.tls': 'Ignorer les erreurs de certificat',
      'cfg.journal': 'Journal des envois', 'cfg.journal.none': 'Aucun envoi pour le moment', 'cfg.test': '✉ Envoyer un mail de test',
      'j.relance': 'Relance', 'j.test': 'Test', 'j.commande': 'Commande', 'j.nlic': '{0} licence(s)',
      'sec.title': "Protection par mot de passe", 'sec.user': 'Identifiant', 'sec.cur': 'Mot de passe actuel', 'sec.new': 'Nouveau mot de passe (8 caractères minimum)',
      'sec.new2': 'Confirmer le nouveau mot de passe', 'sec.set': 'Enregistrer le mot de passe', 'sec.disable': 'Désactiver la protection',
      'sec.env': "L'accès est protégé via les variables d'environnement APP_USER / APP_PASSWORD : à modifier côté serveur.",
      'sec.off': "La protection est désactivée. Définissez un identifiant et un mot de passe pour l'activer.",
      'sec.on': 'La protection est active (identifiant : {0}).',
      'sec.mismatch': 'Les deux mots de passe ne correspondent pas.', 'sec.saved': 'Mot de passe enregistré', 'sec.disabled': 'Protection désactivée',
      'sec.confirm.disable': 'Désactiver la protection ? Toute personne accédant à cette adresse pourra tout modifier.',
      'login.title': 'Connexion', 'login.user': 'Identifiant', 'login.pass': 'Mot de passe', 'login.btn': 'Se connecter',
      'toast.saved': 'Modifications enregistrées', 'toast.added': 'Logiciel ajouté', 'toast.deleted': 'Supprimé',
      'toast.reset': 'Compteur réinitialisé — relances arrêtées pour ce logiciel', 'toast.cfg': 'Paramètres enregistrés',
      'toast.sending': 'Envoi du mail de test…', 'toast.testok': 'Mail de test envoyé à {0}',
      'toast.relanced': 'Relance envoyée ({0} licence(s))', 'toast.nothing': 'Rien à relancer pour le moment',
      'confirm.del': 'Supprimer définitivement « {0} » ?',
      'confirm.relance': "Envoyer maintenant le mail de relance à tous les destinataires pour les licences dans la fenêtre d'alerte ?",
      'err.generic': 'Erreur {0}',
      'csv.h': ['Nom', 'Éditeur', 'Nomenclature', 'Service', 'Début', 'Durée (ans)', 'Échéance', 'Jours restants', 'Statut', 'Coût', 'Groupe', 'Commentaire']
    },
    en: {
      'app.title': 'License tracker', 'app.h1': 'Software licenses & subscriptions',
      'btn.cfg': '⚙ Settings & mail', 'btn.add': '＋ New software', 'btn.sec': '🔒 Security', 'btn.logout': 'Log out',
      'search.ph': 'Search (name, vendor, department, group…)', 'btn.export': '⬇ Export CSV', 'btn.relance': '✉ Send reminders now',
      'btn.relance.tip': 'Send the reminder e-mail now for every license inside the alert window',
      'banner.noauth': '⚠ No password protection: anyone who can reach this address can change everything.',
      'banner.noauth.btn': 'Set a password',
      'kpi.expired': 'Expired', 'kpi.urgent': 'Urgent (≤ 30 d)', 'kpi.soon': 'Plan ahead (≤ {0} d)', 'kpi.ok': 'OK',
      'kpi.toorder': 'To order ({0} d window)',
      'col.nom': 'License / subscription', 'col.editeur': 'Vendor', 'col.nomenclature': 'Code', 'col.service': 'Dept.',
      'col.debut': 'Start', 'col.duree': 'Term', 'col.echeance': 'Renewal date', 'col.joursRestants': 'Days left',
      'col.statut': 'Status', 'col.cout': 'Cost', 'col.groupe': 'Group',
      'st.ok': 'OK', 'st.soon': 'Plan ahead', 'st.urgent': 'Urgent', 'st.expired': 'Expired', 'st.invalid': 'Invalid date',
      'relance.off': 'reminders off',
      'years.1': '1 year', 'years.n': '{0} years',
      'btn.cmd': '✔ Order placed', 'btn.cmd.tip': 'Order placed: resets the counter', 'btn.edit': 'Edit',
      'noresult': 'No results',
      'legend': 'Mail alert {0} days before renewal, then a reminder every {1} days at {2} until “Order placed”. Recipients: {3}.',
      'legend.none': '⚠ none configured (⚙ Settings)',
      'lic.new': 'New software', 'lic.edit': 'Edit software',
      'lic.nom': 'License / subscription name *', 'lic.editeur': 'Vendor / Supplier', 'lic.nomenclature': 'Code',
      'lic.nomenclature.ph': 'e.g. 6156', 'lic.debut': 'Period start date *', 'lic.duree': 'Commitment term *',
      'lic.cout': 'Cost (€)', 'lic.service': 'Department (e.g. 53, 58 — used to route mails)', 'lic.groupe': 'Group',
      'lic.groupe.ph': 'DIR, OPS, GFOR…', 'lic.relance': 'Mail reminders', 'lic.relance.on': 'Enabled', 'lic.relance.off': 'Paused (do not remind)',
      'lic.extra': 'Extra recipients for this software (comma or line separated)',
      'lic.extra.ph': 'added to the global list', 'lic.comment': 'Comment',
      'lic.del': 'Delete', 'btn.cancel': 'Cancel', 'btn.save': 'Save', 'btn.close': 'Close',
      'calc.need': 'Enter the start date to compute the renewal date.',
      'calc.end': 'Computed end of commitment: {0}  ({1})', 'calc.in': 'in {0} days', 'calc.ago': 'expired {0} days ago',
      'calc.newend': 'New renewal date: {0}  (in {1} days)',
      'cmd.title': '✔ Order placed — reset the counter',
      'cmd.intro': 'current renewal date {0} ({1} d).', 'cmd.debut': 'New period start', 'cmd.duree': 'New commitment term',
      'cmd.cout': 'New cost (€)',
      'cmd.hint': 'By default the new cycle starts at the previous renewal date (contract continuity). Reminders stop and the counter restarts.',
      'cmd.ok': 'Confirm order',
      'cfg.title': 'E-mail reminder settings',
      'cfg.dest': 'Reminder recipients (one per line or comma separated) *',
      'cfg.routage': 'Routing by department — one line per department: <b>code: address1, address2</b> (e.g. <code>53: head@example.org, manager@example.org</code>)',
      'cfg.routage.hint': 'Licenses whose “Department” field equals this code go <b>only</b> to these addresses (one separate mail per department). Others go to the global list above.',
      'cfg.alerte': 'Warn X days before renewal', 'cfg.relance': 'Then remind every X days', 'cfg.heure': 'Daily sending time',
      'cfg.url': 'App URL (link in the mail)', 'cfg.lang': 'Mail language', 'cfg.exp': 'Sender', 'cfg.host': 'SMTP server', 'cfg.port': 'Port',
      'cfg.user': 'SMTP user (empty = no authentication)', 'cfg.pass': 'SMTP password (empty = unchanged)',
      'cfg.pass.set': '•••••• (saved)', 'cfg.secure': 'Direct SSL (port 465)', 'cfg.tls': 'Ignore certificate errors',
      'cfg.journal': 'Sending log', 'cfg.journal.none': 'Nothing sent yet', 'cfg.test': '✉ Send a test mail',
      'j.relance': 'Reminder', 'j.test': 'Test', 'j.commande': 'Order', 'j.nlic': '{0} license(s)',
      'sec.title': 'Password protection', 'sec.user': 'Username', 'sec.cur': 'Current password', 'sec.new': 'New password (8 characters minimum)',
      'sec.new2': 'Confirm new password', 'sec.set': 'Save password', 'sec.disable': 'Disable protection',
      'sec.env': 'Access is protected through the APP_USER / APP_PASSWORD environment variables: change them on the server.',
      'sec.off': 'Protection is off. Set a username and password to enable it.',
      'sec.on': 'Protection is on (username: {0}).',
      'sec.mismatch': 'The two passwords do not match.', 'sec.saved': 'Password saved', 'sec.disabled': 'Protection disabled',
      'sec.confirm.disable': 'Disable protection? Anyone reaching this address will be able to change everything.',
      'login.title': 'Sign in', 'login.user': 'Username', 'login.pass': 'Password', 'login.btn': 'Sign in',
      'toast.saved': 'Changes saved', 'toast.added': 'Software added', 'toast.deleted': 'Deleted',
      'toast.reset': 'Counter reset — reminders stopped for this software', 'toast.cfg': 'Settings saved',
      'toast.sending': 'Sending test mail…', 'toast.testok': 'Test mail sent to {0}',
      'toast.relanced': 'Reminder sent ({0} license(s))', 'toast.nothing': 'Nothing to remind right now',
      'confirm.del': 'Permanently delete “{0}”?',
      'confirm.relance': 'Send the reminder mail now to all recipients for the licenses inside the alert window?',
      'err.generic': 'Error {0}',
      'csv.h': ['Name', 'Vendor', 'Code', 'Department', 'Start', 'Term (years)', 'Renewal date', 'Days left', 'Status', 'Cost', 'Group', 'Comment']
    }
  };
  let lang = 'fr';
  try { const s = localStorage.getItem('lang'); if (s && D[s]) lang = s; else if (/^en/i.test(navigator.language || '')) lang = 'en'; } catch (e) {}
  window.getLang = () => lang;
  window.t = (k, ...a) => {
    let s = (D[lang] && D[lang][k]);
    if (s === undefined) s = D.fr[k];
    if (s === undefined) return k;
    if (typeof s !== 'string') return s;
    return s.replace(/\{(\d+)\}/g, (m, i) => a[+i] ?? '');
  };
  window.setLang = (l) => {
    if (!D[l]) return;
    lang = l;
    try { localStorage.setItem('lang', l); } catch (e) {}
    window.applyI18n();
  };
  window.applyI18n = () => {
    document.documentElement.lang = lang;
    document.title = t('app.title');
    document.querySelectorAll('[data-i18n]').forEach(e => { e.textContent = t(e.dataset.i18n); });
    document.querySelectorAll('[data-i18n-html]').forEach(e => { e.innerHTML = t(e.dataset.i18nHtml); });
    document.querySelectorAll('[data-i18n-ph]').forEach(e => { e.placeholder = t(e.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-title]').forEach(e => { e.title = t(e.dataset.i18nTitle); });
    if (window.onLangChange) window.onLangChange();
  };
})();
