// Lisière — LA CARTE DU MONDE (outils/carte.js)
// Le monde ouvert (MONDE-OUVERT.md) a la géographie du monde d'Orvane : ses parcelles (docs/15 d'Orvane : chaque biome en
// quelques parcelles voisines, chacune avec sa faune) et leurs voisinages. Ce script les pose sur un plan : deux parcelles
// voisines dans Orvane se touchent sur la carte autant que possible, le froid est au nord, la mer autour. Chaque parcelle
// devient une région (une cellule de Voronoï autour de son point) ; le jeu n'a besoin que des points.
// Tout est tiré de la graine du monde : même monde, même carte, pour tous les joueurs. Écrit donnees/carte.json (lu par le
// jeu, gardé par outils/secours.js), dit ce qui est respecté et ce qui est approché, et dessine la carte (--svg).
//   node outils/carte.js [--depuis <url ou dossier mondes/<id>/>] [--cote 16000] [--svg carte.svg] [--essais 6] [--pas 3000000]
'use strict';
const fs = require('fs'), path = require('path');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const ICI = path.join(__dirname, '..');
const DEPUIS = arg('--depuis', 'https://stonevalleyoff-ai.github.io/orvane/mondes/orvane/');
const COTE = Number(arg('--cote', 16000));      // la largeur d'une région, en pixels du lieu (un lieu d'aujourd'hui : 5 400)
const ESSAIS = Number(arg('--essais', 6));
const ALLURE = 165;                             // la marche de la veilleuse, en pixels par seconde (scripts/regles.gd)
const lire = async c => {
  if (/^https?:/.test(DEPUIS)) { const r = await fetch(DEPUIS.replace(/\/?$/, '/') + c, { cache: 'no-cache' }); if (!r.ok) throw new Error(`${c} : HTTP ${r.status}`); return r.json(); }
  return JSON.parse(fs.readFileSync(path.join(DEPUIS, c), 'utf8'));
};

// un hasard semé (mulberry32)
const hasard = g => () => { g |= 0; g = g + 0x6D2B79F5 | 0; let t = Math.imul(g ^ g >>> 15, 1 | g); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
const hache = s => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; };

// --- la géométrie : une cellule de Voronoï, par demi-plans ; chaque bord sait qui est de l'autre côté (-1 : le bord du monde) ---
const couper = (poly, qui, mx, my, nx, ny, j) => {     // garde ce qui est du côté (p - m)·n <= 0
  const out = [], oq = [], m = poly.length;
  for (let k = 0; k < m; k++) {
    const a = poly[k], b = poly[(k + 1) % m];
    const da = (a[0] - mx) * nx + (a[1] - my) * ny, db = (b[0] - mx) * nx + (b[1] - my) * ny, ina = da <= 0, inb = db <= 0;
    if (ina) { out.push(a); oq.push(qui[k]); }
    if (ina !== inb) { const t = da / (da - db); out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]); oq.push(ina ? j : qui[k]); }
  }
  return [out, oq];
};
const cellules = (pts, boite) => pts.map((p, i) => {
  let poly = boite, qui = boite.map(() => -1);
  // (les plus proches d'abord : la cellule se referme vite, les autres ne coupent plus rien)
  const ordre = [];
  for (let j = 0; j < pts.length; j++) if (j !== i) ordre.push([j, (pts[j][0] - p[0]) ** 2 + (pts[j][1] - p[1]) ** 2]);
  ordre.sort((a, b) => a[1] - b[1]);
  let rayon2 = Infinity;
  for (const [j, d2] of ordre) {
    if (d2 > 4 * rayon2) break;
    const q = pts[j];
    [poly, qui] = couper(poly, qui, (p[0] + q[0]) / 2, (p[1] + q[1]) / 2, q[0] - p[0], q[1] - p[1], j);
    if (poly.length < 3) break;
    rayon2 = 0; for (const v of poly) rayon2 = Math.max(rayon2, (v[0] - p[0]) ** 2 + (v[1] - p[1]) ** 2);
  }
  return { poly, qui };
});
const aire = poly => { let a = 0; for (let k = 0; k < poly.length; k++) { const p = poly[k], q = poly[(k + 1) % poly.length]; a += p[0] * q[1] - q[0] * p[1]; } return Math.abs(a) / 2; };
const centre = poly => { let x = 0, y = 0; for (const p of poly) { x += p[0]; y += p[1]; } return [x / poly.length, y / poly.length]; };
// qui se touche : deux cellules qui partagent un bord assez long
const voisinages = (C, mini) => {
  const v = C.map(() => new Set());
  C.forEach((c, i) => c.poly.forEach((a, k) => { const j = c.qui[k], b = c.poly[(k + 1) % c.poly.length]; if (j >= 0 && Math.hypot(a[0] - b[0], a[1] - b[1]) >= mini) { v[i].add(j); v[j].add(i); } }));
  return v;
};

(async () => {
  const index = await lire('morceaux/index.json');
  const biomes = new Map(index.biomes.map(b => [b.id, b]));
  const P = index.parcelles;
  if (!P || !P.length) { console.error('carte : ce monde n\'a pas de parcelles (docs/15 d\'Orvane)'); process.exit(1); }
  const n = P.length, rang = new Map(P.map((p, i) => [p.id, i]));
  const mer = P.map(p => biomes.get(p.type)?.milieu === 'marin');
  const eau = P.map(p => ['marin', 'aquatique'].includes(biomes.get(p.type)?.milieu));
  const liens = P.map(() => new Set());
  P.forEach((p, i) => p.voisins.forEach(v => { const j = rang.get(v); if (j !== undefined && j !== i) { liens[i].add(j); liens[j].add(i); } }));
  const nLiens = liens.reduce((s, l) => s + l.size, 0) / 2;
  // les massifs : les parcelles d'un même biome qui se suivent en anneau (prairie~1…4 ; un monde fusionné en a deux : prairie~genese-7-1…4)
  const cle = id => id.replace(/\d+$/, ''), noms = [...new Set(P.map(p => cle(p.id)))], rangM = new Map(noms.map((c, a) => [c, a])), M = noms.length;
  const de = P.map(p => rangM.get(cle(p.id)));
  const membres = noms.map((_, a) => {
    // (dans l'ordre de l'anneau : chacune après sa voisine)
    const tous = P.map((_, i) => i).filter(i => de[i] === a), ordre = [tous[0]];
    while (ordre.length < tous.length) { const suite = tous.find(i => !ordre.includes(i) && liens[ordre[ordre.length - 1]].has(i)) ?? tous.find(i => !ordre.includes(i)); ordre.push(suite); }
    return ordre;
  });
  const liensM = noms.map(() => new Set());
  for (let i = 0; i < n; i++) for (const j of liens[i]) if (de[i] !== de[j]) liensM[de[i]].add(de[j]);
  const nLiensM = liensM.reduce((s, l) => s + l.size, 0) / 2;
  const merM = noms.map((_, a) => mer[membres[a][0]]), eauM = noms.map((_, a) => eau[membres[a][0]]);
  // la latitude voulue : le froid au nord. (Un sommet est froid par son altitude, pas par sa latitude : on la lui rend.)
  const latM = noms.map((_, a) => { const x = biomes.get(P[membres[a][0]].type).axes; return Math.min(1.1, x.temperature + 0.5 * x.altitude); });
  const latP = P.map((_, i) => latM[de[i]]);
  const inegales = aires => { const moy = aires.reduce((a, b) => a + b, 0) / aires.length; return [Math.sqrt(aires.reduce((s, a) => s + (a / moy - 1) ** 2, 0) / aires.length), moy]; };

  // --- 1. la grille : des cases en nid d'abeille, toutes de la même taille. Chaque parcelle en prend une ; le reste est la mer ---
  const R = Number(arg('--rayon', Math.max(4, Math.ceil((Math.sqrt(12 * n * 1.3 - 3) - 3) / 6))));
  const cases = [];
  for (let q = -R; q <= R; q++) for (let k = Math.max(-R, -q - R); k <= Math.min(R, -q + R); k++) cases.push([q, k]);
  const NC = cases.length, rangC = new Map(cases.map((c, k) => [c[0] * 1000 + c[1], k]));
  const vois = cases.map(([q, k]) => [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]].map(([dq, dk]) => rangC.get((q + dq) * 1000 + k + dk) ?? -1));
  const xy = ([q, k]) => [q + k / 2, k * Math.sqrt(3) / 2], XY = cases.map(xy), haut = R * Math.sqrt(3) / 2;
  // ce que vaut une carte. Deux parcelles voisines dans Orvane qui se touchent : 1 (4 si elles sont du même massif : il ne se défait
  // pas) ; deux biomes voisins qui se touchent quelque part : 3 ; deux biomes de terre qui se touchent sans être voisins : -0,6 (il
  // faudra une crête) ; la mer d'Orvane au large, les terres ramassées, le froid au nord.
  const MASSIF = 6, VOISINS = 5, INVENTE = -1.0, AU_LARGE = 0.5, RAMASSE = -0.06, NORD = 1.2;
  const large_ = p => mer[p] ? AU_LARGE : (eau[p] ? 0 : RAMASSE);
  const seul = (p, c) => -NORD * Math.abs(XY[c][1] / haut - (latP[p] - 0.55) * 1.8);
  const paire = (a, b) => liensM[a].has(b) ? VOISINS : (!eauM[a] && !eauM[b] ? INVENTE : 0);
  const chercher = graine => {
    const r = hasard(graine), occ = new Int16Array(NC).fill(-1), cnt = new Int16Array(M * M);
    // la parcelle de la case c arrive (s = 1) ou s'en va (s = -1) : ce que la note y gagne
    const compte = (c, s) => {
      const p = occ[c]; let d = s * seul(p, c);
      for (const v of vois[c]) {
        const q = v < 0 ? -1 : occ[v];
        if (q < 0) { d += s * large_(p); continue; }
        d -= s * large_(q);
        if (liens[p].has(q)) d += s * (de[p] === de[q] ? MASSIF : 1);
        if (de[p] !== de[q]) {
          const a = Math.min(de[p], de[q]), b = Math.max(de[p], de[q]), k = a * M + b, avant = cnt[k]; cnt[k] += s;
          if (avant === 0 && s > 0) d += paire(a, b); else if (avant === 1 && s < 0) d -= paire(a, b);
        }
      }
      return d;
    };
    const echanger = (c1, c2) => {
      const p1 = occ[c1], p2 = occ[c2]; let d = 0;
      if (p1 >= 0) { d += compte(c1, -1); occ[c1] = -1; }
      if (p2 >= 0) { d += compte(c2, -1); occ[c2] = -1; }
      if (p2 >= 0) { occ[c1] = p2; d += compte(c1, 1); }
      if (p1 >= 0) { occ[c2] = p1; d += compte(c2, 1); }
      return d;
    };
    // au départ : les parcelles au hasard dans les cases du milieu
    const milieu = cases.map((_, k) => k).sort((a, b) => Math.hypot(...XY[a]) - Math.hypot(...XY[b])).slice(0, n);
    for (let i = n - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [milieu[i], milieu[j]] = [milieu[j], milieu[i]]; }
    let E = 0; milieu.forEach((c, p) => { occ[c] = p; E += compte(c, 1); });
    // un recuit : on échange deux cases ; on garde presque toujours ce qui améliore, de moins en moins ce qui abîme
    const pas = Number(arg('--pas', 3000000)), T0 = 2.2, T1 = 0.04;
    let mieuxE = E, mieuxOcc = occ.slice();
    for (let t = 0; t < pas; t++) {
      const c1 = Math.floor(r() * NC); let c2;
      if (r() < 0.5) { c2 = vois[c1][Math.floor(r() * 6)]; if (c2 < 0) continue; } else c2 = Math.floor(r() * NC);
      if (c1 === c2 || (occ[c1] < 0 && occ[c2] < 0)) continue;
      const d = echanger(c1, c2), T = T0 * Math.pow(T1 / T0, t / pas);
      if (d < 0 && r() >= Math.exp(d / T)) echanger(c1, c2);
      else { E += d; if (E > mieuxE + 1e-9) { mieuxE = E; mieuxOcc = occ.slice(); } }
    }
    return { E: mieuxE, occ: mieuxOcc };
  };
  const g0 = hache(`${index.monde?.id || 'monde'}|${index.monde?.graine ?? 0}|carte`);

  // --- 2. les points : le centre de chaque case, un peu déplacé (des régions qui ne sont pas des alvéoles) ; la mer autour ---
  const dresser = occ => {
    const rj = hasard(g0 ^ 0x51ed), bouge = c => [c[0] + (rj() - 0.5) * 0.36, c[1] + (rj() - 0.5) * 0.36];
    const pts = new Array(n), mers = [];
    cases.forEach((c, k) => { const p = bouge(XY[k]); if (occ[k] >= 0) pts[occ[k]] = p; else mers.push(p); });
    for (let q = -R - 2; q <= R + 2; q++) for (let k = Math.max(-R - 2, -q - R - 2); k <= Math.min(R + 2, -q + R + 2); k++) if (!rangC.has(q * 1000 + k)) mers.push(bouge(xy([q, k])));
    const tous = pts.concat(mers), mm = R + 3.2, boite = [[-mm, -mm], [mm, -mm], [mm, mm], [-mm, mm]];
    const C = cellules(tous, boite), v = voisinages(C, 0.06);
    const J = { pts, tous, boite, C, v, polys: C.map(c => c.poly), tenus: 0, tenusM: 0, inventes: 0, morceaux: -M, touche: new Set() };
    for (let i = 0; i < n; i++) for (const j of v[i]) if (j < n) { if (j > i && liens[i].has(j)) J.tenus++; if (de[i] < de[j]) J.touche.add(de[i] * 1000 + de[j]); }
    for (const t of J.touche) { const a = Math.floor(t / 1000), b = t % 1000; if (liensM[a].has(b)) J.tenusM++; else if (!eauM[a] && !eauM[b]) J.inventes++; }
    [J.inegal, J.moy] = inegales(J.polys.slice(0, n).filter((_, i) => !eau[i]).map(aire));
    for (let a = 0; a < M; a++) { const vu = new Set(); for (const d of membres[a]) { if (vu.has(d)) continue; J.morceaux++; const pile = [d]; while (pile.length) { const x = pile.pop(); if (vu.has(x)) continue; vu.add(x); for (const y of v[x]) if (y < n && de[y] === a && !vu.has(y)) pile.push(y); } } }
    // (entre plusieurs cartes, on garde celle qui respecte le plus de voisinages de biomes, avec le moins de crêtes et de massifs défaits)
    J.choix = 3 * J.tenusM - J.inventes - 2 * J.morceaux;
    return J;
  };
  let mieux = null;
  for (let e = 0; e < ESSAIS; e++) { const c = chercher(g0 + e * 7919), j = dresser(c.occ); if (!mieux || j.choix > mieux.J.choix) mieux = { ...c, J: j, e }; }
  const J = mieux.J, pts = J.pts;
  const etat = noms.map((_, a) => ({ c: centre(membres[a].map(i => pts[i])) }));
  const echelle = COTE / Math.sqrt(J.moy);
  const px = p => [Math.round(p[0] * echelle), Math.round(p[1] * echelle)];
  const idDe = i => i < n ? P[i].id : `large~bord-${i - n + 1}`;
  // une frontière fermée : deux régions de terre qui se touchent sur la carte, mais dont les biomes ne sont pas voisins dans Orvane
  // (une crête, une falaise : on ne passe pas). Un passage : deux voisines d'Orvane qui ne se touchent pas sur la carte.
  const ferme = (i, j) => i < n && j < n && de[i] !== de[j] && !eau[i] && !eau[j] && !liensM[de[i]].has(de[j]);
  const manques = [], manquesM = [];
  for (let i = 0; i < n; i++) for (const j of liens[i]) if (j > i && !J.v[i].has(j)) manques.push([P[i].id, P[j].id]);
  for (let a = 0; a < M; a++) for (const b of liensM[a]) if (b > a && !J.touche.has(a * 1000 + b)) manquesM.push([noms[a], noms[b]]);
  const carte = {
    v: 1, monde: index.monde?.id || '', graine: index.monde?.graine ?? 0, cote: COTE,
    demi: Math.round(Math.abs(J.boite[0][0]) * echelle),
    parcelles: J.tous.map((p, i) => {
      const [x, y] = px(p), vs = [...J.v[i]].sort((a, b) => a - b), o = { id: idDe(i), type: i < n ? P[i].type : 'large', x, y, voisines: vs.map(idDe) };
      if (i >= n) o.bord = true;
      else { const murs = vs.filter(j => ferme(i, j)).map(idDe); if (murs.length) o.murs = murs; }
      return o;
    }),
  };
  fs.mkdirSync(path.join(ICI, 'donnees'), { recursive: true });
  fs.writeFileSync(path.join(ICI, 'donnees/carte.json'), JSON.stringify(carte));
  const terre = P.filter((_, i) => !eau[i]).length, large = 2 * carte.demi;
  console.log(`carte : ${n} parcelles (${terre} à terre, ${n - terre} d'eau) en ${M} massifs, ${biomes.size} biomes ; ${J.tous.length - n} cases de haute mer autour`);
  console.log(`carte : ${J.tenusM} voisinages de biomes sur ${nLiensM} respectés (${Math.round(100 * J.tenusM / nLiensM)} %) ; ${J.inventes} frontières inventées à terre (fermées : des crêtes) ; il manque : ${manquesM.map(x => x.join(' — ').replace(/~/g, '')).join(', ') || 'rien'}`);
  console.log(`carte : ${J.tenus} voisinages de parcelles sur ${nLiens} (${Math.round(100 * J.tenus / nLiens)} %) ; régions de terre inégales à ${Math.round(100 * J.inegal)} % ; ${J.morceaux} massif(s) en morceaux`);
  console.log(`carte : ${large} pixels de côté, soit ${(large / ALLURE / 60).toFixed(0)} minutes de marche d'un bord à l'autre (une région : ${COTE} pixels, ${(COTE / ALLURE / 60).toFixed(1)} min) ; essai ${mieux.e + 1} sur ${ESSAIS}, note ${mieux.E.toFixed(1)}`);
  console.log(`carte : donnees/carte.json (${fs.statSync(path.join(ICI, 'donnees/carte.json')).size} octets)`);

  // --- le dessin de la carte (pour la regarder ; le jeu dessinera la sienne) ---
  const svg = arg('--svg', '');
  if (!svg) return;
  const TONS = { banquise: '#e6edf0', toundra: '#c7ccb9', taiga: '#5f7a5c', steppe: '#cdbf8a', prairie: '#a9b86b', foret: '#55733f', jungle: '#2f6a3c', savane: '#cfae62', desert: '#e3c98a',
    'desert-froid': '#cfc8b4', maquis: '#9aa05c', montagne: '#9a9488', sommets: '#dcdcd8', volcan: '#6b4a40', grotte: '#4a4540', marais: '#6f7a4a', mangrove: '#4f7a5a', cote: '#d8cfa6',
    lac: '#7fa3b5', riviere: '#8fb0c0', recif: '#7fc0b8', large: '#5f8fa8', 'mer-froide': '#86a4b8', abysses: '#3f5f7a', rivage: '#d9d2b0', bois: '#6a8548', lande: '#a59a6a',
    falaise: '#b0a898', pierre: '#a8a49a', neige: '#eef0f0', tourbiere: '#7a6f4a', canyon: '#c98a55', sylve: '#7a5f8a', cristal: '#a9c7d6', caldeira: '#7a5a50', braises: '#a04a30',
    ossuaire: '#d9d0bc', 'terres-creuses': '#8a7f6a', cerisaie: '#d79aa5' };
  const S = 60, f = v => (v * S).toFixed(1), type = i => i < n ? P[i].type : 'large', mouille = i => i >= n || eau[i];
  // un bord qui tremble comme un trait de plume : le même vu des deux cellules
  const bord = (a, b) => {
    const inv = a[0] > b[0] || (a[0] === b[0] && a[1] > b[1]), p = inv ? b : a, q = inv ? a : b;
    const rr = hasard(hache(`${p[0].toFixed(3)},${p[1].toFixed(3)},${q[0].toFixed(3)},${q[1].toFixed(3)}`));
    let pts = [p, q];
    for (let prof = 0; prof < 4; prof++) {
      const s = [pts[0]];
      for (let k = 0; k + 1 < pts.length; k++) {
        const u = pts[k], w = pts[k + 1], l = Math.hypot(w[0] - u[0], w[1] - u[1]), d = (rr() - 0.5) * 0.34 * l;
        s.push([(u[0] + w[0]) / 2 - (w[1] - u[1]) / (l || 1) * d, (u[1] + w[1]) / 2 + (w[0] - u[0]) / (l || 1) * d], w);
      }
      pts = s;
    }
    return inv ? pts.reverse() : pts;
  };
  const contour = poly => poly.map((a, k) => bord(a, poly[(k + 1) % poly.length]).slice(0, -1)).flat();
  const chemin = pts => 'M' + pts.map(p => `${f(p[0])},${f(p[1])}`).join('L') + 'Z';
  const m = Math.abs(J.boite[0][0]), W = 2 * m * S;
  let o = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f(-m)} ${f(-m)} ${W.toFixed(0)} ${W.toFixed(0)}" width="${W.toFixed(0)}" height="${W.toFixed(0)}">`;
  o += `<rect x="${f(-m)}" y="${f(-m)}" width="${W}" height="${W}" fill="${TONS.large}"/>`;
  J.polys.forEach((poly, i) => { if (poly.length >= 3) o += `<path d="${chemin(contour(poly))}" fill="${TONS[type(i)] || '#b9b29a'}" stroke="${TONS[type(i)] || '#b9b29a'}" stroke-width="2"/>`; });
  // les bords : la côte (un trait d'encre, un liseré clair dans l'eau), les frontières entre biomes, les parcelles d'un même biome
  let cotes = '', frontieres = '', internes = '', cretes = '';
  J.polys.forEach((poly, i) => poly.forEach((a, k) => {
    const b = poly[(k + 1) % poly.length], j = J.C[i].qui[k];
    if (j < 0 || j < i) return;
    const d = 'M' + bord(a, b).map(p => `${f(p[0])},${f(p[1])}`).join('L');
    if (mouille(i) !== mouille(j)) cotes += d; else if (ferme(i, j)) cretes += d; else if (type(i) !== type(j) && !(mouille(i) && mouille(j))) frontieres += d; else if (!mouille(i)) internes += d;
  }));
  o += `<path d="${cretes}" fill="none" stroke="#3a2c20" stroke-width="7" stroke-linejoin="round" opacity="0.85"/><path d="${cretes}" fill="none" stroke="#b9a98a" stroke-width="2" stroke-dasharray="2 5" stroke-linejoin="round"/>`;
  o += `<path d="${cotes}" fill="none" stroke="#f1ead6" stroke-width="9" stroke-linejoin="round" opacity="0.55"/><path d="${cotes}" fill="none" stroke="#16130f" stroke-width="3.2" stroke-linejoin="round"/>`;
  o += `<path d="${frontieres}" fill="none" stroke="#16130f" stroke-width="1.6" stroke-linejoin="round" opacity="0.75"/><path d="${internes}" fill="none" stroke="#16130f" stroke-width="1" stroke-dasharray="3 7" opacity="0.4"/>`;
  // les passages : des voisines d'Orvane qui ne se touchent pas sur la carte
  if (process.argv.includes('--passages')) for (const [a, b] of manquesM) { const p = etat[rangM.get(a)].c, q = etat[rangM.get(b)].c; o += `<path d="M${f(p[0])},${f(p[1])}L${f(q[0])},${f(q[1])}" stroke="#7b1c1c" stroke-width="2.4" stroke-dasharray="3 7" opacity="0.8" fill="none"/>`; }
  // les noms : un par massif (les parcelles d'un même biome qui se touchent)
  const vu = new Set();
  for (let i = 0; i < n; i++) {
    if (vu.has(i)) continue;
    const massif = [], pile = [i];
    while (pile.length) { const x = pile.pop(); if (vu.has(x)) continue; vu.add(x); massif.push(x); for (const y of J.v[x]) if (y < n && !vu.has(y) && P[y].type === P[i].type) pile.push(y); }
    const c = centre(massif.map(x => centre(J.polys[x]))), nom = biomes.get(P[i].type).nom || P[i].type, clair = ['abysses', 'grotte', 'volcan', 'jungle', 'foret', 'taiga', 'braises', 'caldeira', 'large'].includes(P[i].type);
    const taille = (13 + 5 * Math.sqrt(massif.length)).toFixed(0);
    o += `<text x="${f(c[0])}" y="${f(c[1])}" text-anchor="middle" dominant-baseline="middle" font-family="'IM Fell English', Georgia, serif" font-style="italic" font-size="${taille}" fill="${clair ? '#f1ead6' : '#16130f'}" stroke="${clair ? '#16130f' : '#f1ead6'}" stroke-width="3" stroke-opacity="0.35" paint-order="stroke">${nom}</text>`;
  }
  // l'échelle (cinq minutes de marche) et le nord
  const cinq = 5 * 60 * ALLURE / echelle, x0 = -m + 1.2, y0 = m - 1.3;
  o += `<path d="M${f(x0)},${f(y0)}h${f(cinq)}M${f(x0)},${f(y0 - 0.15)}v${f(0.3)}M${f(x0 + cinq)},${f(y0 - 0.15)}v${f(0.3)}" stroke="#f1ead6" stroke-width="3" fill="none"/>`;
  o += `<text x="${f(x0 + cinq / 2)}" y="${f(y0 - 0.4)}" text-anchor="middle" font-family="'IM Fell English', Georgia, serif" font-style="italic" font-size="20" fill="#f1ead6">cinq minutes de marche</text>`;
  o += `<path d="M${f(m - 1.5)},${f(-m + 2.3)}l${f(0.28)},${f(0)}l${f(-0.28)},${f(-1.2)}l${f(-0.28)},${f(1.2)}z" fill="#f1ead6"/><text x="${f(m - 1.5)}" y="${f(-m + 2.9)}" text-anchor="middle" font-family="'IM Fell English', Georgia, serif" font-size="22" fill="#f1ead6">N</text>`;
  // le titre, et ce que disent les traits
  o += `<text x="${f(-m + 1.2)}" y="${f(-m + 1.9)}" font-family="'IM Fell English', Georgia, serif" font-size="44" fill="#f1ead6">${index.monde?.nom || 'Le monde'}</text>`;
  o += `<text x="${f(-m + 1.2)}" y="${f(-m + 2.7)}" font-family="'IM Fell English', Georgia, serif" font-style="italic" font-size="21" fill="#f1ead6" opacity="0.85">${terre} régions de terre, ${biomes.size} biomes</text>`;
  const yl = m - 2.6;
  o += `<path d="M${f(x0)},${f(yl)}h${f(1.6)}" stroke="#3a2c20" stroke-width="7"/><path d="M${f(x0)},${f(yl)}h${f(1.6)}" stroke="#b9a98a" stroke-width="2" stroke-dasharray="2 5"/>`;
  o += `<text x="${f(x0 + 1.9)}" y="${f(yl)}" dominant-baseline="middle" font-family="'IM Fell English', Georgia, serif" font-style="italic" font-size="20" fill="#f1ead6">une crête : on ne passe pas</text>`;
  o += '</svg>';
  fs.writeFileSync(svg, o);
  console.log(`carte : dessinée dans ${svg}`);
})().catch(e => { console.error('carte : ' + e.message); process.exit(1); });
