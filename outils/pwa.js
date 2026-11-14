// Lisière — L'APPLICATION QU'ON INSTALLE (outils/pwa.js)
// Godot exporte le jeu pour un navigateur, avec ce qu'il faut pour l'installer (export_presets.cfg : « progressive_web_app ») :
// un manifeste, un service worker qui garde le jeu sur l'appareil, une page hors ligne. Ce script finit le travail, après l'export :
//   1. le manifeste : le nom, la langue, la couleur, et les icônes de application/ (outils/icone.js), « any » aux coins arrondis
//      et « maskable » pleines (Android les découpe à sa forme) ; deux images du jeu, pour la fenêtre d'installation ;
//   2. l'icône de l'onglet et celle d'iOS : les nôtres, à leur taille, à la place de celles que Godot réduit de icon.svg ;
//   3. le service worker de Godot 4.3 :
//      - il garde à l'installation des fichiers qu'un export sans fils d'exécution n'a pas (index.worker.js) : un seul fichier
//        manquant, et rien n'est gardé, le jeu ne s'ouvre jamais hors ligne. On ne lui laisse que ceux qui existent ;
//      - il ne gardait le gros du jeu (le .wasm et le .pck, près de 40 Mo) qu'au deuxième lancement : ouvert une seule fois, le jeu
//        ne se rouvrait pas hors ligne. Il les garde dès son installation (le navigateur vient de les lire : il les a encore) ;
//      - ouvert à l'adresse du dossier (…/), sans index.html, il ne trouvait rien hors ligne : il y sert index.html ;
//      - une version nouvelle prenait ses fichiers là où le navigateur les avait encore (dix minutes, chez GitHub Pages) : lue
//        peu après l'ancienne, elle gardait l'ancien jeu sous son nouveau nom. Il les redemande au site (« no-cache » : une
//        question, et le fichier seulement s'il a changé) ;
//   4. la mise à jour (outils/maj.js, posé dans index.html) : on la cherche dès l'ouverture, et le jeu sait quand elle est
//      prête ; la date de l'export, pour que l'écran-titre dise de quand est le jeu.
// Il vérifie à la fin que tout ce que le manifeste et le service worker nomment est là, et sort en erreur sinon.
//   node outils/pwa.js build/web
'use strict';
const fs = require('fs'), path = require('path');
const RACINE = path.join(__dirname, '..'), DOSSIER = path.resolve(process.argv[2] || 'build/web');
const ICI = f => path.join(DOSSIER, f);
let ok = true;
const dit = m => console.log('  ' + m), faux = m => { ok = false; console.log('  ✗ ' + m); };
if (!fs.existsSync(ICI('index.html')) || !fs.existsSync(ICI('index.service.worker.js'))) {
  console.error(`pwa.js : pas d'export web avec sa PWA dans ${DOSSIER} (outils/godot.sh --headless --path . --export-release Web build/web/index.html)`);
  process.exit(1);
}

// 1. les icônes et les images, à côté du jeu
const APPLI = path.join(RACINE, 'application');
fs.mkdirSync(ICI('application'), { recursive: true });
for (const f of fs.readdirSync(APPLI).filter(f => /\.(png|jpg)$/.test(f))) fs.copyFileSync(path.join(APPLI, f), ICI('application/' + f));
fs.copyFileSync(path.join(APPLI, 'lisiere-192.png'), ICI('index.icon.png'));
fs.copyFileSync(path.join(APPLI, 'lisiere-apple-180.png'), ICI('index.apple-touch-icon.png'));
for (const f of fs.readdirSync(DOSSIER).filter(f => /^index\.\d+x\d+\.png$/.test(f))) fs.rmSync(ICI(f));   // (celles de Godot)

// 2. le manifeste
const godot = JSON.parse(fs.readFileSync(ICI('index.manifest.json'), 'utf8'));
const icone = (f, taille, usage) => ({ src: 'application/' + f, sizes: `${taille}x${taille}`, type: 'image/png', purpose: usage });
const image = (f, legende, forme) => ({ src: 'application/' + f, sizes: '1280x720', type: 'image/jpeg', label: legende, ...(forme ? { form_factor: forme } : {}) });
const images = [['ecran-titre.jpg', "L'écran-titre : la lisière, la nuit, et la veilleuse au feu"], ['ecran-nuit.jpg', 'La première nuit : tenir dans la lumière du feu']];
const manifeste = {
  id: './',
  name: 'Lisière',
  short_name: 'Lisière',
  description: "Tenir jusqu'au matin, à la lisière d'un lieu du monde vivant d'Orvane. Le jour, on récolte et l'on chasse ; la nuit, on tient près d'un feu. Ses bêtes sont vraies.",
  lang: 'fr',
  dir: 'ltr',
  start_url: godot.start_url || './index.html',
  scope: './',
  display: godot.display || 'fullscreen',
  display_override: ['fullscreen', 'standalone'],
  orientation: godot.orientation || 'landscape',
  background_color: godot.background_color || '#050609',
  theme_color: godot.background_color || '#050609',
  categories: ['games'],
  icons: [
    icone('lisiere-192.png', 192, 'any'), icone('lisiere-512.png', 512, 'any'),
    icone('lisiere-masquable-192.png', 192, 'maskable'), icone('lisiere-masquable-512.png', 512, 'maskable'),
  ],
  // (sur un ordinateur, la fenêtre d'installation ne montre que les images « wide » ; sur un téléphone, celles sans forme)
  screenshots: [...images.map(([f, l]) => image(f, l, 'wide')), ...images.map(([f, l]) => image(f, l))],
};
fs.writeFileSync(ICI('index.manifest.json'), JSON.stringify(manifeste, null, 1) + '\n');
dit(`le manifeste : « ${manifeste.name} », ${manifeste.display}, ${manifeste.orientation}, ${manifeste.icons.length} icônes, ${images.length} images`);

// 3. le service worker
const SW = ICI('index.service.worker.js');
let sw = fs.readFileSync(SW, 'utf8');
const liste = sw.match(/const CACHED_FILES = (\[[^\]]*\]);/);
if (!liste) faux("le service worker n'a pas sa liste CACHED_FILES (une autre version de Godot ?)");
else {
  const lourds = sw.match(/const CACHE?ABLE_FILES = (\[[^\]]*\]);/);
  const avant = JSON.parse(liste[1]), apres = [...new Set([...avant, ...(lourds ? JSON.parse(lourds[1]) : [])])].filter(f => fs.existsSync(ICI(f)));
  sw = sw.replace(liste[0], `const CACHED_FILES = ${JSON.stringify(apres)};`);
  const otes = avant.filter(f => !apres.includes(f));
  if (!apres.includes('index.wasm') || !apres.includes('index.pck')) faux("le service worker ne garde pas index.wasm et index.pck à l'installation");
  dit(`le service worker garde ${apres.length} fichiers dès son installation, le jeu entier` + (otes.length ? ` (ôtés, absents de l'export : ${otes.join(', ')})` : ''));
}
const AVANT = 'let cached = await cache.match(event.request);';
const APRES = "let cached = await cache.match(event.request) || (isNavigate && new URL(url).pathname.endsWith('/') ? await cache.match(CACHED_FILES[0]) : undefined);";
if (sw.includes(APRES)) dit('le service worker sert déjà index.html à l\'adresse du dossier');
else if (sw.includes(AVANT)) { sw = sw.replace(AVANT, APRES); dit("le service worker sert index.html à l'adresse du dossier, hors ligne"); }
else faux("le service worker n'a plus la ligne attendue (« " + AVANT + " ») : à revoir avec cette version de Godot");
const GARDE = 'cache.addAll(CACHED_FILES)', GARDE_FRAIS = "cache.addAll(CACHED_FILES.map((f) => new Request(f, { cache: 'no-cache' })))";
if (sw.includes(GARDE_FRAIS)) dit('le service worker redemande déjà ses fichiers au site');
else if (sw.includes(GARDE)) { sw = sw.replace(GARDE, GARDE_FRAIS); dit('le service worker redemande ses fichiers au site à chaque version'); }
else faux("le service worker n'a plus la ligne attendue (« " + GARDE + " ») : à revoir avec cette version de Godot");
fs.writeFileSync(SW, sw);

// 4. la mise à jour, dans la page
const exporte = Number((sw.match(/const CACHE_VERSION = '(\d+)\|/) || [])[1] || 0);
let page = fs.readFileSync(ICI('index.html'), 'utf8');
if (!exporte) faux("le service worker ne dit pas quand le jeu a été exporté (CACHE_VERSION)");
else if (page.includes('lisiereMaj')) dit('la page cherche déjà les versions nouvelles');
else if (!page.includes('<head>')) faux("index.html n'a pas d'en-tête où poser la mise à jour");
else {
  const script = fs.readFileSync(path.join(__dirname, 'maj.js'), 'utf8').replace('__VERSION__', String(exporte));
  page = page.replace('<head>', '<head>\n<script>\n' + script + '</script>');
  fs.writeFileSync(ICI('index.html'), page);
  dit(`la page cherche les versions nouvelles dès l'ouverture (ce jeu : ${new Date(exporte * 1000).toISOString().slice(0, 16).replace('T', ' ')} UTC)`);
}

// 5. tout ce qui est nommé est là
const nommes = [...manifeste.icons, ...manifeste.screenshots].map(i => i.src);
const garde = sw.match(/const CACHED_FILES = (\[[^\]]*\]);/), gardables = sw.match(/const CACHE?ABLE_FILES = (\[[^\]]*\]);/);
for (const m of [garde, gardables]) if (m) nommes.push(...JSON.parse(m[1]));
const manquent = [...new Set(nommes)].filter(f => !fs.existsSync(ICI(f)));
if (manquent.length) faux('manquent : ' + manquent.join(', '));
else dit(`les ${new Set(nommes).size} fichiers que nomment le manifeste et le service worker sont là`);
const html = fs.readFileSync(ICI('index.html'), 'utf8');
if (!/rel=.manifest. href=.index\.manifest\.json/.test(html) || !/"serviceWorker":"index\.service\.worker\.js"/.test(html)) faux("index.html ne nomme pas le manifeste ou le service worker");

console.log(ok ? `pwa.js : l'application est prête (${DOSSIER})` : 'pwa.js : ÉCHEC');
process.exit(ok ? 0 : 1);
