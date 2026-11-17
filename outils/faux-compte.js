// Lisière — UN FAUX SERVICE DE COMPTES (outils/faux-compte.js), pour l'essai
// Ce que le jeu demande au Supabase de StoneValley pour garder la partie sur le compte (outils/sauvegarde.sql), joué en mémoire,
// avec les mêmes règles : se connecter (mot de passe « bon »), lisiere_garder, lisiere_reprendre, lisiere_oublier, lisiere_avancee.
// Et, pour les lots (scripts/lots.gd), ce que le jeu demande au Supabase d'Orvane (hebergement/supabase.sql d'Orvane) :
// orvane_deposer, avec les mêmes vérifications, sans compte (la clé publique et la clé du jeu suffisent).
// Rien ne part nulle part. L'essai le lance tout seul (scripts/essai.gd, la partie sur le compte, les lots) ; à la main :
//   node outils/faux-compte.js 8139        puis    LISIERE_SERVICE=http://127.0.0.1:8139 outils/godot.sh --path .
// GET /__etat rend ce qu'il garde, POST /__vider l'oublie (pour l'essai). GET /__lots rend les lots reçus ; POST /__refuser fait
// refuser les dépôts suivants (comme Orvane au 49ᵉ lot d'un joueur dans la journée), POST /__accepter les reprend.
'use strict';
const http = require('http');
const PORT = Number(process.argv[2] || 8139);
const parties = {};        // uid → { donnees, resume, rev, appareil, maj_le }
const lots = [];           // les lots reçus : { cle, compte, lot }
let refuser = false;
const ACTIONS = ['rencontre', 'prelevement', 'capture', 'liberation', 'nourrissage', 'reproduction', 'deplacement', 'habitat_perdu',
  'habitat_gagne', 'defrichage', 'reboisement', 'assechement', 'irrigation', 'construction', 'transformation',
  'blessure', 'effarouchement', 'pillage', 'attaque', 'joueur_tombe'];

const repondre = (res, code, corps) => {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(corps === undefined ? '' : JSON.stringify(corps));
};
const qui = req => {
  const m = /^Bearer jeton:(.+)$/.exec(req.headers.authorization || '');
  return m ? { uid: 'u-' + m[1].split('@')[0], email: m[1] } : null;
};

const FONCTIONS = {
  lisiere_garder(moi, a) {
    if (!a.p_donnees || typeof a.p_donnees !== 'object' || !('v' in a.p_donnees)) return { ok: false, erreur: 'partie invalide' };
    if (JSON.stringify(a.p_donnees).length > 2000000) return { ok: false, erreur: 'partie trop lourde' };
    if (!a.p_resume || typeof a.p_resume !== 'object' || JSON.stringify(a.p_resume).length > 4000) return { ok: false, erreur: 'résumé invalide' };
    if (typeof a.p_appareil !== 'string' || a.p_appareil.length < 4 || a.p_appareil.length > 64) return { ok: false, erreur: 'appareil invalide' };
    const s = parties[moi.uid];
    if (!s) {
      parties[moi.uid] = { donnees: a.p_donnees, resume: a.p_resume, rev: 1, appareil: a.p_appareil, maj_le: new Date().toISOString() };
      return { ok: true, rev: 1 };
    }
    if (!a.p_nouvelle && s.appareil !== a.p_appareil && (a.p_rev === null || a.p_rev === undefined || s.rev > a.p_rev))
      return { ok: false, erreur: 'conflit', rev: s.rev, maj_le: s.maj_le, resume: s.resume };
    Object.assign(s, { donnees: a.p_donnees, resume: a.p_resume, rev: s.rev + 1, appareil: a.p_appareil, maj_le: new Date().toISOString() });
    return { ok: true, rev: s.rev };
  },
  lisiere_reprendre(moi) {
    const s = parties[moi.uid];
    return { ok: true, partie: s ? { donnees: s.donnees, rev: s.rev, appareil: s.appareil, maj_le: s.maj_le } : null };
  },
  lisiere_oublier(moi, a) {
    const s = parties[moi.uid];
    const efface = !!s && (s.appareil === (a.p_appareil || '') || (a.p_rev !== null && a.p_rev !== undefined && s.rev <= a.p_rev));
    if (efface) delete parties[moi.uid];
    return { ok: true, efface };
  },
  lisiere_avancee(moi) {
    const s = parties[moi.uid];
    return { ok: true, pseudo: moi.email.split('@')[0], en_cours: s ? { resume: s.resume, maj_le: s.maj_le } : null, meilleur: null, rang: null, parties: 0, dernieres: [] };
  },
};

// le Supabase d'Orvane : ce qu'il vérifie d'un dépôt (hebergement/supabase.sql, orvane_deposer)
const ORVANE = {
  orvane_deposer(a) {
    if (typeof a.p_cle !== 'string' || !/^orv_[0-9a-f]{32}$/.test(a.p_cle)) return { ok: false, erreur: 'clé de jeu inconnue' };
    if (typeof a.p_compte !== 'string' || a.p_compte.length < 1 || a.p_compte.length > 128) return { ok: false, erreur: 'compte : 1 à 128 caractères' };
    const l = a.p_lot;
    if (!l || typeof l !== 'object' || Array.isArray(l) || !Array.isArray(l.evenements)) return { ok: false, erreur: 'lot mal formé' };
    if (JSON.stringify(l).length > 65536 || l.evenements.length > 500) return { ok: false, erreur: 'lot trop gros' };
    if (l.evenements.some(e => !e || typeof e !== 'object' || typeof e.biome !== 'string' || !ACTIONS.includes(e.action)
        || typeof e.n !== 'number' || !(e.n >= 0 && e.n <= 10000) || ('taxon' in e && typeof e.taxon !== 'string')
        || ('moyen' in e && typeof e.moyen !== 'string') || ('parcelle' in e && typeof e.parcelle !== 'string')))
      return { ok: false, erreur: 'événement mal formé (schemas/pression.schema.json)' };
    if (refuser) return { ok: false, erreur: "trop de dépôts aujourd'hui pour ce joueur" };
    lots.push({ cle: a.p_cle, compte: a.p_compte, lot: l });
    return { ok: true };
  },
};

http.createServer((req, res) => {
  let texte = '';
  req.on('data', c => { texte += c; });
  req.on('end', () => {
    const corps = texte ? JSON.parse(texte) : {};
    const chemin = req.url.split('?')[0];
    if (req.method === 'GET' && chemin === '/__etat') return repondre(res, 200, parties);
    if (req.method === 'POST' && chemin === '/__vider') { for (const k of Object.keys(parties)) delete parties[k]; return repondre(res, 200, {}); }
    if (req.method === 'GET' && chemin === '/__lots') return repondre(res, 200, lots);
    if (req.method === 'POST' && (chemin === '/__refuser' || chemin === '/__accepter')) { refuser = chemin === '/__refuser'; return repondre(res, 200, {}); }
    if (chemin === '/auth/v1/token') {
      if (corps.password !== 'bon') return repondre(res, 400, { error_code: 'invalid_credentials', msg: 'Invalid login credentials' });
      return repondre(res, 200, { access_token: 'jeton:' + corps.email, refresh_token: 'reprise:' + corps.email, expires_in: 3600,
        user: { id: 'u-' + corps.email.split('@')[0], email: corps.email } });
    }
    if (chemin === '/auth/v1/logout') return repondre(res, 204);
    const m = /^\/rest\/v1\/rpc\/(\w+)$/.exec(chemin);
    if (m && ORVANE[m[1]]) {
      if (!req.headers.apikey) return repondre(res, 401, { message: 'No API key found in request' });
      return repondre(res, 200, ORVANE[m[1]](corps));
    }
    if (m && FONCTIONS[m[1]]) {
      const moi = qui(req);
      if (!moi) return repondre(res, 401, { message: 'permission denied' });
      return repondre(res, 200, FONCTIONS[m[1]](moi, corps));
    }
    repondre(res, 404, { message: 'inconnu : ' + chemin });
  });
}).listen(PORT, '127.0.0.1', () => console.log('faux-compte.js : http://127.0.0.1:' + PORT));
