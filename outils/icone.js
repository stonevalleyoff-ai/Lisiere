// Lisière — L'ICÔNE (outils/icone.js)
// Le jeu tient dans une image (DIRECTION-ARTISTIQUE.md) : une veilleuse au bord d'un feu, et autour, le noir qui regarde.
// L'icône la dessine, avec les couleurs de scripts/palette.gd : la lisière d'une forêt de sapins, bleu d'encre ; un feu et son
// cercle de braise ; la veilleuse assise, la capuche levée, l'écharpe rouille dans le vent ; et dans le noir, deux yeux d'ambre
// qui la regardent (un chasseur), deux pâles plus loin (une proie). Comme tout le jeu, elle est faite par le code.
// Ce qui compte tient dans le cercle du milieu (80 % de la largeur) : Android peut la découper en rond, en carré, en goutte.
//   node outils/icone.js            écrit icon.svg (l'icône du projet), puis outils/godot.sh la rend en PNG (outils/icone.gd)
'use strict';
const fs = require('fs'), path = require('path');
const RACINE = path.join(__dirname, '..');

// la palette (scripts/palette.gd)
const P = {
  ENCRE: '#16130f', NUIT: '#0a0d18', NUIT_BLEUE: '#1b2440', LUNE: '#6f86b8', IVOIRE: '#cfc3a6', PAPIER: '#e9dfc8',
  BRAISE: '#f29a48', BRAISE_COEUR: '#ffd88a', BRAISE_ROUGE: '#c4462a', CENDRE: '#3a3530', TERRE: '#5a4630',
  CAPE: '#303645', ECHARPE: '#9e4523', VISAGE: '#dccdb3', OEIL_CHASSEUR: '#ffc252', OEIL_PROIE: '#b8e6ff',
};
const melange = (a, b, t) => '#' + [1, 3, 5].map(i => Math.round(parseInt(a.slice(i, i + 2), 16) * (1 - t) + parseInt(b.slice(i, i + 2), 16) * t).toString(16).padStart(2, '0')).join('');

// le hasard, toujours le même : l'icône ne change pas d'un tirage à l'autre
let graine = 46;
const hasard = () => { graine = (graine * 1103515245 + 12345) % 2147483648; return graine / 2147483648; };
const n = v => +v.toFixed(1);

// un sapin : des étages de branches qui retombent, de plus en plus larges vers le pied (x, y : le pied ; h : la hauteur ; l : la largeur)
function sapin(x, y, h, l, tronc = 0.08) {
  const etages = 4 + Math.round(h / 60), g = [], d = [];
  let avant = l * 0.04;
  for (let i = 1; i <= etages; i++) {
    const t = i / etages, w = l / 2 * Math.pow(t, 0.85) * (0.92 + 0.16 * hasard()), yy = y - h * tronc - (h * (0.98 - tronc)) * (1 - t);
    const tombe = h * 0.025 * (0.6 + hasard());
    g.push([x - avant, yy - h * 0.9 / etages * 0.55]); g.push([x - w, yy + tombe]);
    d.push([x + avant, yy - h * 0.9 / etages * 0.5]); d.push([x + w * (0.94 + 0.12 * hasard()), yy + tombe * 0.8]);
    avant = w * (0.42 + 0.1 * hasard());
  }
  const pts = [[x, y - h], ...d, ...(tronc ? [[x + l * 0.05, y - h * tronc], [x + l * 0.05, y], [x - l * 0.05, y], [x - l * 0.05, y - h * tronc]] : []), ...g.reverse()];
  return 'M' + pts.map(p => n(p[0]) + ' ' + n(p[1])).join('L') + 'Z';
}
// un rang de sapins, de gauche à droite (base : le sol ; hmin, hmax : les hauteurs ; cadre : plus grands sur les bords)
function rang(base, hmin, hmax, pas, cadre) {
  let d = '';
  for (let x = 20; x < 500; x += pas * (0.75 + 0.5 * hasard())) {
    const bord = Math.pow(Math.abs(x - 256) / 236, 2.4);
    if (cadre && bord < 0.2) continue;                 // (le milieu reste ouvert : la clairière)
    const h = cadre ? hmin + (hmax - hmin) * bord : hmin + (hmax - hmin) * hasard();
    d += sapin(x, base + 8 * hasard(), h, h * (0.5 + 0.1 * hasard()), cadre ? 0.08 : 0);
  }
  return d;
}

// des étoiles, dans le haut du ciel
let etoiles = '';
for (let i = 0; i < 34; i++) {
  const x = 20 + 472 * hasard(), y = 18 + 190 * Math.pow(hasard(), 1.4), r = 0.8 + 1.5 * hasard() * hasard();
  etoiles += `<circle cx="${n(x)}" cy="${n(y)}" r="${n(r)}" fill="${P.PAPIER}" opacity="${n(0.25 + 0.5 * hasard())}"/>`;
}

// des yeux : deux amandes, et leur lueur (x, y : le milieu ; e : l'écart ; r : la taille)
function yeux(x, y, e, r, couleur, penche) {
  const oeil = (cx, s) => `<path d="M${n(cx - r * 1.25)} ${n(y + s * r * 0.2)}Q${n(cx)} ${n(y - r * 0.95 + s * penche)} ${n(cx + r * 1.25)} ${n(y - s * r * 0.2)}Q${n(cx)} ${n(y + r * 0.85 + s * penche * 0.3)} ${n(cx - r * 1.25)} ${n(y + s * r * 0.2)}Z" fill="${couleur}"/>`;
  return `<circle cx="${n(x)}" cy="${n(y)}" r="${n(e * 1.25)}" fill="url(#lueur-${couleur.slice(1)})"/>` + oeil(x - e / 2, 1) + oeil(x + e / 2, -1);
}

const ciel = rang(322, 80, 150, 26, false);          // le rang du fond, bleui par la nuit
const milieu = rang(342, 70, 130, 34, false);        // le rang du milieu
const cadre = rang(362, 60, 420, 40, true);          // les grands sapins des bords, qui ouvrent la clairière

// le vent souffle vers la droite : la flamme y penche, les étincelles y vont, l'écharpe y flotte (un seul vent, comme dans le jeu)
// la veilleuse, assise à droite du feu, tournée vers lui (vers la gauche), vue de profil : la capuche levée, dont la pointe retombe
// dans le dos ; son visage dans l'ombre, que le feu éclaire par-dessous ; les mains tendues vers lui ; l'écharpe nouée dans le dos
const cape = 'M318 288C318 268 334 252 354 250C372 248 386 256 394 270C400 282 404 292 410 302C404 304 400 306 398 310C408 334 418 360 426 388C432 404 438 418 442 432C400 438 336 438 298 432C290 420 288 404 294 392C298 384 306 378 316 374C324 360 330 346 334 336C330 330 326 326 324 322C320 312 318 300 318 288Z';
const creux = 'M320 290C326 280 342 278 352 286C358 294 358 308 352 318C346 324 336 326 328 323C322 318 319 304 320 290Z';            // l'ombre de la capuche
const visage = 'M330 287C329 291 327 294 323 299C322 301 324 302 327 303C326 305 326 307 327 309C327 312 328 315 331 317C336 319 341 317 343 312C340 306 338 298 336 290Z'; // le profil, que le feu éclaire
const echarpe = 'M324 318C332 326 350 330 366 328C376 327 384 322 390 316L394 330C386 340 370 344 352 344C338 344 328 338 324 330Z';
const pans = 'M386 318C398 312 410 304 424 302C436 300 446 304 456 298C452 306 452 312 458 318C446 320 436 316 426 320C414 326 404 332 392 334ZM388 330C398 332 408 338 418 346C426 352 436 352 444 350C438 356 436 362 438 368C428 366 420 360 412 356C404 350 396 344 390 340Z'; // les deux pans, dans le vent
const manche = 'M350 332C338 340 322 347 308 349C300 351 296 358 298 365C301 373 309 377 319 375C335 372 349 362 361 349Z';             // le bras tendu vers le feu
const plis = 'M392 318C398 352 410 392 420 430M370 346C376 372 382 404 386 432M318 378C330 386 342 398 350 432';                    // les plis de la cape
const lumiere = 'M350 251C336 254 324 266 320 284C318 296 319 306 322 316M300 356C297 360 297 366 300 369M294 392C289 402 289 418 296 432';  // ce que le feu éclaire
const mains = 'M300 357C294 355 288 356 283 359C280 361 280 364 283 365C287 367 294 368 300 368Z';

// le feu : deux bûches, trois langues de flamme (s : la taille ; p : combien la pointe penche), des étincelles
const flamme = (s, cx, b, p) => `M${cx} ${b}C${n(cx - 30 * s)} ${b} ${n(cx - 36 * s)} ${n(b - 36 * s)} ${n(cx - 24 * s)} ${n(b - 62 * s)}C${n(cx - 14 * s)} ${n(b - 84 * s)} ${n(cx - 4 * s)} ${n(b - 98 * s)} ${n(cx + p * s)} ${n(b - 130 * s)}C${n(cx + (8 + p * 0.3) * s)} ${n(b - 100 * s)} ${n(cx + 30 * s)} ${n(b - 82 * s)} ${n(cx + 30 * s)} ${n(b - 54 * s)}C${n(cx + 32 * s)} ${n(b - 28 * s)} ${n(cx + 28 * s)} ${b} ${cx} ${b}Z`;
let etincelles = '';
for (const [x, y, r, o] of [[244, 238, 2.8, 0.95], [266, 214, 2.1, 0.8], [252, 190, 1.7, 0.6], [280, 174, 1.4, 0.45], [236, 166, 1.2, 0.35]])
  etincelles += `<circle cx="${x}" cy="${y}" r="${r}" fill="${P.BRAISE_COEUR}" opacity="${o}"/>`;

// le cadre : ce qu'on voit de la scène (la clairière, sans le haut du ciel), et son milieu, où tient ce qui compte
const VUE = [40, 96, 432];

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${VUE.join(' ')} ${VUE[2]}" width="512" height="512">
<defs>
<linearGradient id="ciel" x1="0" y1="96" x2="0" y2="528" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#05070e"/><stop offset=".35" stop-color="${P.NUIT}"/><stop offset=".58" stop-color="${melange(P.NUIT_BLEUE, P.LUNE, 0.14)}"/><stop offset=".8" stop-color="${P.NUIT}"/></linearGradient>
<radialGradient id="halo" cx="226" cy="372" r="240" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${P.BRAISE}" stop-opacity=".72"/><stop offset=".2" stop-color="${P.BRAISE}" stop-opacity=".42"/><stop offset=".5" stop-color="${P.BRAISE_ROUGE}" stop-opacity=".12"/><stop offset="1" stop-color="${P.BRAISE_ROUGE}" stop-opacity="0"/></radialGradient>
<radialGradient id="sol"><stop offset="0" stop-color="${P.BRAISE_COEUR}" stop-opacity=".65"/><stop offset=".45" stop-color="${P.BRAISE}" stop-opacity=".36"/><stop offset=".86" stop-color="${P.BRAISE_ROUGE}" stop-opacity=".1"/><stop offset="1" stop-color="${P.BRAISE_ROUGE}" stop-opacity="0"/></radialGradient>
<linearGradient id="cape" x1="296" y1="0" x2="440" y2="0" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${melange(P.CAPE, P.BRAISE, 0.3)}"/><stop offset=".3" stop-color="${P.CAPE}"/><stop offset="1" stop-color="${melange(P.CAPE, P.ENCRE, 0.5)}"/></linearGradient>
<linearGradient id="visage" x1="321" y1="0" x2="345" y2="0" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${melange(P.VISAGE, P.BRAISE_COEUR, 0.3)}"/><stop offset=".45" stop-color="${melange(P.VISAGE, P.BRAISE, 0.35)}"/><stop offset="1" stop-color="${melange(P.CAPE, P.ENCRE, 0.3)}"/></linearGradient>
<linearGradient id="sol-nuit" x1="0" y1="346" x2="0" y2="430" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${melange(P.NUIT_BLEUE, P.NUIT, 0.3)}"/><stop offset="1" stop-color="#080a12"/></linearGradient>
<radialGradient id="voile" cx="244" cy="330" r="330" gradientUnits="userSpaceOnUse"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".6"/></radialGradient>
<radialGradient id="lueur-${P.OEIL_CHASSEUR.slice(1)}"><stop offset="0" stop-color="${P.OEIL_CHASSEUR}" stop-opacity=".26"/><stop offset="1" stop-color="${P.OEIL_CHASSEUR}" stop-opacity="0"/></radialGradient>
<radialGradient id="lueur-${P.OEIL_PROIE.slice(1)}"><stop offset="0" stop-color="${P.OEIL_PROIE}" stop-opacity=".22"/><stop offset="1" stop-color="${P.OEIL_PROIE}" stop-opacity="0"/></radialGradient>
</defs>
<rect x="0" y="0" width="512" height="560" fill="url(#ciel)"/>
${etoiles}
<path d="${ciel}" fill="${melange(P.NUIT_BLEUE, P.LUNE, 0.25)}"/>
<path d="${milieu}" fill="${melange(P.NUIT_BLEUE, P.NUIT, 0.3)}"/>
<rect y="346" width="512" height="200" fill="url(#sol-nuit)"/>
<path d="${cadre}" fill="#05070d"/>
<rect x="0" y="0" width="512" height="560" fill="url(#halo)"/>
<ellipse cx="232" cy="406" rx="200" ry="64" fill="url(#sol)"/>
${yeux(114, 304, 34, 12, P.OEIL_CHASSEUR, 3)}
${yeux(398, 232, 19, 5.5, P.OEIL_PROIE, 0)}
<ellipse cx="228" cy="406" rx="56" ry="10" fill="${P.ENCRE}" opacity=".55"/>
<path d="M192 412L264 390" stroke="${P.TERRE}" stroke-width="11" stroke-linecap="round"/><path d="M196 390L262 412" stroke="${melange(P.TERRE, P.ENCRE, 0.35)}" stroke-width="11" stroke-linecap="round"/>
<path d="${flamme(1.22, 226, 402, 16)}" fill="${P.BRAISE_ROUGE}"/>
<path d="${flamme(0.94, 229, 402, 14)}" fill="${P.BRAISE}"/>
<path d="${flamme(0.56, 230, 402, 10)}" fill="${P.BRAISE_COEUR}"/>
${etincelles}
<ellipse cx="370" cy="434" rx="84" ry="9" fill="${P.ENCRE}" opacity=".6"/>
<path d="${pans}" fill="${melange(P.ECHARPE, P.ENCRE, 0.25)}" stroke="${P.ENCRE}" stroke-width="2.5" stroke-linejoin="round"/>
<path d="${cape}" fill="url(#cape)" stroke="${P.ENCRE}" stroke-width="3" stroke-linejoin="round"/>
<path d="${plis}" fill="none" stroke="${P.ENCRE}" stroke-width="2.2" stroke-linecap="round" opacity=".55"/>
<path d="${creux}" fill="${P.ENCRE}"/>
<path d="${visage}" fill="url(#visage)"/>
<path d="${echarpe}" fill="${P.ECHARPE}" stroke="${P.ENCRE}" stroke-width="2.5" stroke-linejoin="round"/>
<path d="${manche}" fill="${melange(P.CAPE, P.BRAISE, 0.12)}" stroke="${P.ENCRE}" stroke-width="2.5" stroke-linejoin="round"/>
<path d="${mains}" fill="${melange(P.VISAGE, P.BRAISE, 0.4)}"/>
<path d="${lumiere}" fill="none" stroke="${P.BRAISE}" stroke-width="3.5" stroke-linecap="round" opacity=".9"/>
<rect x="0" y="0" width="512" height="560" fill="url(#voile)"/>
</svg>
`;

fs.writeFileSync(path.join(RACINE, 'icon.svg'), svg);
console.log(`icon.svg : ${svg.length} caractères`);
