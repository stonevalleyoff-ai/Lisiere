# Lisière

*Tenir jusqu'au matin.*

Un jeu de survie et d'horreur en Godot 4, branché sur le monde vivant d'[Orvane](https://github.com/stonevalleyoff-ai/orvane). On s'éveille à la lisière d'un lieu vrai du monde : une forêt, une prairie, une lande. Le jour, on récolte, on fabrique, on chasse. La nuit, on tient près d'un feu, et les chasseurs du lieu viennent tourner au bord de la lumière.

Chaque bête du jeu est une lignée vraie d'Orvane, au dernier cycle publié : son nombre, son dessin, son heure, sa vitesse et son caractère viennent du monde. Ce que le joueur croise et ce qu'il tue est compté, et renvoyé au monde. Et le monde s'en souvient : ses bêtes se conduisent d'après ce que les joueurs leur ont appris, tous jeux confondus.

## Ce qu'on y fait

- **Le jour** (quatre minutes, dont une part de nuit) : ramasser des brindilles, couper du bois, casser des pierres, cueillir des baies et des fibres. Chasser les proies du lieu, qui fuient quand on approche (plus tôt si l'on court vers elles). Laisser passer les rôdeurs, des chasseurs qui vivent le jour : ils se retournent si l'on s'approche trop.
- **Fabriquer** : un feu de camp (4 bois, 2 pierres), une torche (2 bois, 1 fibre), une lance (2 bois, 1 pierre, 2 fibres), qui frappe trois fois plus fort et s'use.
- **La nuit** : le feu brûle son bois (une bûche, 25 secondes de plus) et éclaire d'autant plus qu'il en a. Les chasseurs du lieu viennent. Ils n'entrent pas dans la lumière d'un feu : ils tournent à sa lisière. Ils gardent leurs distances avec une torche, sauf les plus audacieux. Dans le noir, ils mordent.
- **Le corps** : la faim baisse sans cesse (des baies, de la viande, cuite de préférence). La peur monte dans le noir et quand un chasseur est près ; elle baisse à la lumière. Au comble, elle coûte de la santé.
- **Le temps qu'il fait** change pendant la partie, et il pèse (`scripts/climat.gd`) :
  - **la pluie** trempe la veilleuse (presque pas sous le feuillage d'un arbre), et le feu mange son bois plus vite ;
  - **la boue** : un sol détrempé freine la marche (jusqu'à 38 %, davantage dans les flaques), celle des bêtes aussi (les légères moins) ;
  - **la crue** : après une longue pluie, l'eau monte dans les creux du lieu. On y patauge (55 % de l'allure), on y est trempée, un feu s'y noie et l'on n'en allume pas. La butte où l'on s'éveille reste au sec ;
  - **l'orage** jette **la foudre** : le sol pâlit là où elle va tomber, une seconde avant. Elle blesse à moins de 70 pixels (près de deux fois plus loin si l'on a les pieds dans l'eau), fait fuir les bêtes, et **met le feu** à ce qu'elle frappe. Elle cherche ce qui dépasse : un arbre le plus souvent (celui sous lequel on s'abrite, une fois sur quatre), ou la veilleuse si elle est seule debout à découvert ;
  - **l'incendie** (`scripts/incendie.gd`) : un arbre en feu éclaire et tient les chasseurs à distance comme un feu de camp, chauffe, met le feu à qui le touche, et saute à ses voisins, plus loin sous le vent, presque jamais sous la pluie, de moins en moins fort à chaque saut. Il laisse des souches noires ; les buissons repoussent ;
  - **la neige** tient au sol et freine ; **le brouillard** cache le lointain ; **la canicule**, l'été dans les lieux secs, accable en plein jour (l'ombre d'un arbre soulage).
- **La température du corps** (la quatrième jauge) suit l'air (le lieu, la saison, la nuit, le temps), le vent, et surtout l'eau : **trempée**, on prend froid. Un feu réchauffe et sèche. Sous 25, le froid ralentit et coûte de la santé ; au-dessus de 78, la chaleur aussi. **En feu** (au contact d'un incendie, ou frappée de près par la foudre), on brûle quatre secondes : la pluie abrège, l'eau éteint.
- **Le monde ouvert, à l'essai** (`MONDE-OUVERT.md`) : à l'écran-titre, « Le monde d'Orvane » est le monde entier, d'un seul tenant, avec la géographie d'Orvane (`outils/carte.js`, `donnees/carte.json`, `scripts/carte.gd`) : 136 régions de terre, une par parcelle. On s'éveille dans la prairie du centre ; le monde se fabrique par morceaux autour de la veilleuse et ne garde que ce qu'on y change. D'un biome à l'autre, le sol, les plantes, les bêtes et le climat changent ; l'eau est une frontière, et une crête de roche ferme les passages qu'Orvane ne connaît pas. Une rivière se passe à ses gués (de l'eau jusqu'aux genoux), ou sur un **pont de fortune** qu'on fabrique au bord (6 bois, 3 fibres, touche 4) et qui ne dure pas. À la pause, le carnet montre **la carte** de ce qu'on a découvert.
- **La mémoire** (`scripts/bete.gd`) : chaque population du lieu se conduit d'après ce qu'elle a appris des joueurs. Rien ne le dit pendant la partie : on le voit.
  - **craintive** (on la chasse ici) : une proie broute moins, guette, et s'enfuit de plus loin (jamais hors de l'écran : 420 pixels au plus) ; un chasseur frappé lâche prise plus tôt, et se tient plus loin du feu ;
  - **habituée** (on la croise sans lui faire de mal) : elle se laisse approcher, et qui ne bouge pas la voit venir brouter à ses pieds ; un rôdeur laisse passer de plus près ;
  - **traqueuse** (elle a appris qu'une veilleuse est une proie) : le jour, un rôdeur suit de loin, et charge de plus loin, plus longtemps ; la nuit, les chasseurs arpentent la lisière du feu plus vite, reviennent après un coup, et la torche ne les tient plus ;
  - **le feu** : une population qui le craint reste hors de sa lumière (on ne voit plus que ses yeux), se tient loin de la torche, et recule à chaque bûche qu'on jette ; une population qui s'y est faite serre la torche de plus près ;
  - **attirée** par les joueurs : elle vient voir, juste hors de sa distance de fuite.
  - Ce qui reste juste : **le feu reste une loi** (aucun chasseur n'entre dans sa lumière, quoi qu'il ait appris) ; la mémoire ne change ni les morsures ni le nombre des bêtes ; ce qu'elle rend plus dangereux **s'annonce** (un chasseur s'aplatit et gronde une seconde avant de passer la torche, un rôdeur s'arrête et guette avant de charger) ; et **la première nuit**, ce qui rend une population dangereuse ne compte que pour moitié.
- **Les échos** : quand la peur est haute, les bêtes qu'on a tuées reviennent, pâles et lentes. Elles ne mordent pas : elles traversent, et la peur monte encore.
- **La fin** : la santé à zéro. L'écran dit combien de nuits on a tenues, quelles bêtes on a croisées, ce que chacune a appris des joueurs (« méfiante : on la chasse ici », « pour elle, tu es une proie »), et ce que la partie renvoie au monde.

## Ce qui vient d'Orvane

| dans le jeu | dans le monde d'Orvane |
| --- | --- |
| le lieu : ses arbres (des sapins s'il fait froid), ses rochers, ses buissons, son herbe, la couleur de son sol | les axes du biome : `couvert`, `altitude`, `humidite`, `temperature` |
| ses plantes : chaque arbre, chaque buisson, chaque touffe est une lignée de plantes du lieu, dessinée dans son stade du cycle (en fleurs, en fruits, nue), semée selon son poids | l'herbier publié à chaque cycle (`morceaux/herbier/<biome>.json`, docs/49) ; sans lui, le jeu dessine ses arbres lui-même, d'après les axes |
| le temps qu'il fait : ce qui vient le plus souvent (un lieu humide a plus de pluie et d'orages, un lieu froid de la neige, un lieu sec des canicules l'été), la boue et l'eau qui restent dans un marais, la température de l'air | les axes du biome (`humidite`, `temperature`), la saison du monde, et la météo du biome ce cycle (`biomes[].meteo`, docs/45) dans un monde qui l'a éveillée : ce temps-là revient alors le plus souvent |
| la longueur des nuits | la saison du monde ce jour-là (`cycle.saison`) : un tiers du jour en été, la moitié en hiver |
| les bêtes qui viennent, et combien souvent | les lignées vivantes du biome et leur `effectif` (les plus nombreuses viennent plus souvent) ; celles qui vivent en groupe (`sociabilite`) viennent en bande |
| qui chasse, qui fuit, et quand | `regime` (un carnivore, ou un omnivore de plus de 15 kg, chasse) et `activite` (de jour, de nuit, au crépuscule) |
| leur taille (de 38 à 150 pixels : une bête d'un kilo se lit d'un coup d'œil, un grand chasseur domine la veilleuse), leur force, leur vitesse, leur flair, leur audace | `masse_kg`, `vitesse_rel`, `perception`, `temperament` |
| leur dessin, et leurs yeux qui brillent dans le noir | le plan de corps de la lignée (`plan.corps` : sa forme, ses pattes, son cou, son museau, ses oreilles, sa queue, ses cornes, son motif, ses organes, ses couleurs) : Lisière la dessine elle-même, à l'encre (`scripts/bestiaire.gd`) ; à défaut (une forme qu'elle ne sait pas encore dessiner), la planche publiée à chaque cycle (`morceaux/silhouettes/<biome>.json`, docs/21) |
| comment elles se conduisent avec la veilleuse : d'où elles fuient, si elles suivent, ce qui les arrête | la mémoire de leur population dans ce lieu (`Orvane.dispositions`) : `mefiance`, `habituation` (docs/12), et `memoire` (docs/50) : `traque`, `attrait`, `neophobie` (0,5 : neutre ; au-dessus, elle craint le feu ; en dessous, elle s'y est faite). Absente, une disposition vaut sa valeur neutre, et la bête se conduit comme avant |
| ce que le carnet en dit, à la fin | `attitude` (un mot : traqueuse, rodeuse, quemandeuse, defensive, fuyante, familiere), sinon la disposition qui domine (`scripts/donnees.gd`, `dire_memoire`) |
| ce que la partie renvoie | une rencontre par bête vue dans la lumière, un prélèvement par bête tuée (`moyen` : `melee`), dans le biome d'Orvane où c'est arrivé (le kit : `Orvane.compter`, `clore`, `deposer`) |
| ce qu'elle apprend aux bêtes | `blessure` (une bête frappée qui s'en va en vie, une par bête, `melee`), `effarouchement` (un chasseur arrêté par un feu de camp, `feu`, ou par la torche, `lumiere` : une fois par bête, vue ou non), `attaque` (un assaut : une série de morsures, ou la charge d'un rôdeur, qu'elle morde ou non), `joueur_tombe` (la morsure qui tue). Rien pour un écho, ni pour ce que font la foudre et l'incendie |

Le jeu lit le monde en ligne, par morceaux (`Orvane.lire_lieux`, `Orvane.lire_silhouettes`) : l'index, puis le seul lieu choisi. Sans réseau, il joue avec une copie de cinq lieux gardée dans `donnees/` (`node outils/secours.js` la refait, depuis le monde publié ; il lui faut une copie d'Orvane à côté de ce dépôt, `../orvane`, ou `--orvane <dossier>`).

**La mémoire** est tenue par Orvane, par population, et nourrie par tous les jeux ; Lisière la lit à chaque partie et ne la change pas pendant qu'on joue : ce qu'on fait ce soir pèsera au cycle de la nuit, pour les parties suivantes. Les quatre actions qui la nourrissent ne sont comptées que si le monde lu la tient (`Orvane.memoire_eveillee()` : la clé `memoire` de `instantane.monde`) : un monde qui ne les connaît pas refuserait le lot entier. Le `moyen`, lui, part toujours. Lisière n'envoie pas `pillage` : rien ne s'y vole.

Tant que le monde publié n'a pas de mémoire, on l'essaie à la main : `-- --memoire <nom>` (ou `?memoire=<nom>` au bout de l'adresse, dans un navigateur) pose la même sur toutes les populations du lieu : `crainte`, `confiance`, `traque`, `feu` (elles craignent le feu), `accoutumance` (elles s'y sont faites). Un message le rappelle au réveil. Elle ne change que ce que le jeu lit, et **une partie jouée ainsi n'envoie rien** : des bêtes conduites par une mémoire qui n'est pas celle du monde ne lui apprendraient rien de vrai.

**Les lots vont dans le monde d'Orvane** (`monde: "orvane"`, `scripts/regles.gd`), comme ceux de Stone Valley : à la fin d'une partie, le lot part dans le Supabase d'Orvane avec la **clé du jeu** (`CLE_JEU`, publique, `orv_…` : Lisière y est inscrit sous le nom « lisiere »), et le cycle de la nuit le lit. Sans réseau, il attend la fin de la partie suivante. L'essai et la vitrine n'envoient rien. `MONDE_DES_LOTS = "essai"` les mettrait dans le bac à sable (gardés quatorze jours, lus par aucun monde). La clé d'administration ne va jamais dans le jeu.

## Le compte

Le même que pour Stone Valley : le bouton « Se connecter », sous « Entrer dans la nuit », ouvre une page du carnet (`scripts/interface_porte.gd`) pour se connecter, créer un compte ou demander un nouveau mot de passe. Un compte de Stone Valley y entre tel quel.

- **Le même Supabase** que Stone Valley, le projet « Vallée de pierre » (`scripts/session.gd`), et sa clé publique (sans compte connecté, elle n'ouvre rien). Tout passe par Supabase Auth : le jeu n'envoie l'adresse et le mot de passe qu'à lui, et ne garde que la session (`user://session.json`). Le jeton se renouvelle seul.
- **Une adresse confirmée** : un compte neuf reçoit un courriel de Supabase. Le lien ramène à la page du jeu, si Supabase la connaît (Authentication › URL Configuration › Redirect URLs : `https://stonevalleyoff-ai.github.io/Lisiere/`) ; sinon à celle de Stone Valley, et le compte vaut pareil. Revenu d'un lien « mot de passe oublié », la page s'ouvre pour en choisir un nouveau.
- **Dans un navigateur**, l'adresse et le mot de passe sont de vrais champs de la page, posés sur la feuille : sur un téléphone, le bon clavier s'ouvre, et le gestionnaire de mots de passe peut les remplir. Au doigt, la feuille monte en haut de l'écran, au-dessus du clavier.
- **Sans compte**, la partie se joue pareil ; connecté, ses nuits vont au tableau des scores.

## La partie gardée, le tableau des scores

- **La partie gardée** (`scripts/partie_gardee.gd`, `user://partie.json`) : une partie en cours s'écrit sur l'appareil toutes les vingt secondes (à l'horloge de l'appareil), à la pause, quand l'application passe derrière une autre (la partie se met alors en pause) et quand on revient au titre. L'écran-titre propose « Reprendre · Forêt, jour 3 », devant « Entrer dans la nuit » (qui demande un second appui : la partie gardée serait perdue). On garde le lieu et sa graine, l'heure, les nuits tenues ; la veilleuse, son sac, sa lance, sa torche ; les feux et leur bois ; le lieu tel qu'on l'a laissé (les arbres abattus, les rochers entamés, les buissons qui repoussent, les brindilles ramassées ou tombées) ; ce qu'on a croisé et chassé, et les bêtes tuées dont les échos reviennent. Les bêtes reviennent d'elles-mêmes. À la fin de la partie, elle s'efface. L'essai et la vitrine n'y touchent pas.
- **Le tableau des scores** (`scripts/interface_tableau.gd`, « Tableau des scores » à l'écran-titre) : les veilleuses qui ont tenu le plus de nuits, chacune sa meilleure partie, avec son nom, ses nuits, le lieu ; soi en rouge, et son rang même plus bas. Il se lit sans compte ; on y entre connecté : une partie commencée connectée a son numéro (`lisiere_partie_commencer`), et à la fin ses nuits y sont inscrites (`lisiere_partie_finir`) ; l'écran de fin dit le rang. Sans réseau à la fin, l'inscription attend (`user://tableau.json`) et repart à l'écran-titre.
- **La base** : celle de Stone Valley (Supabase « Vallée de pierre »), deux tables à elles (`lisiere_parties`, `lisiere_joueurs`), fermées (rien ne s'y lit ni ne s'y écrit en direct), et des fonctions qui vérifient : un compte connecté, au plus 40 parties par heure, et pas plus de nuits que le temps passé n'en permet (trois minutes par nuit au moins, depuis le début de la partie : un jour de Lisière en dure quatre). Effacer son compte dans Stone Valley efface aussi ses parties.
- **Le nom au tableau** : celui choisi dans la page du compte (« Enregistrer le nom », de 2 à 18 caractères), sinon celui de Stone Valley, sinon « Veilleuse ». L'adresse n'y paraît jamais.

## Les touches

| | au clavier | au doigt (un téléphone tenu à l'horizontale, une tablette) |
| --- | --- | --- |
| marcher | ZQSD (clavier français), WASD, ou les flèches | le pouce gauche, posé n'importe où dans la moitié gauche de l'écran |
| récolter, frapper | Espace, ou le clic | Agir (on peut le tenir en marchant) |
| un feu, une torche, une lance | 1, 2, 3 | Feu, Torche, Lance |
| manger, nourrir le feu, cuire | E, F, C | Manger, Nourrir, Cuire |
| pause | Échap | le bouton en haut, au milieu |

Les commandes tactiles (`scripts/tactile.gd`) s'allument seules sur un écran tactile. Elles pressent les mêmes actions que les touches. Un bouton pâlit quand on n'a pas de quoi s'en servir. Sur un petit écran l'image grossit ; tenu debout, le téléphone demande qu'on le tourne, et la partie attend.

**Dans un navigateur** : https://stonevalleyoff-ai.github.io/Lisiere/. Le jeu s'y installe aussi comme une application (voir plus bas).

## L'application qu'on installe

Lisière s'installe depuis le navigateur, comme une application (une PWA), sur un téléphone, une tablette ou un ordinateur : son icône sur l'écran d'accueil, plein écran, à l'horizontale, et **sans réseau** une fois ouvert une première fois.

- **Sur Android** (Chrome) : le menu ⋮, « Installer l'application » (ou « Ajouter à l'écran d'accueil »).
- **Sur iPhone, iPad** (Safari) : le bouton Partager, « Sur l'écran d'accueil ».
- **Sur un ordinateur** (Chrome, Edge) : l'icône d'installation au bout de la barre d'adresse.

Ce qui la fait :
- **L'export web de Godot** (`export_presets.cfg`, « progressive_web_app ») : un manifeste, un service worker qui garde le jeu sur l'appareil, une page hors ligne (`outils/hors-ligne.html`, quand le jeu n'est pas encore gardé).
- **`outils/pwa.js`**, après l'export : le manifeste complet (le nom, la langue, la couleur de la nuit, les icônes, deux images du jeu pour la fenêtre d'installation), et trois corrections au service worker de Godot 4.3. Il gardait à l'installation un fichier qu'un export sans fils d'exécution n'a pas (`index.worker.js`) : rien n'était gardé, le jeu ne s'ouvrait jamais hors ligne. Il ne gardait le gros du jeu (le `.wasm` et le `.pck`, près de 40 Mo) qu'au deuxième lancement. Et ouvert à l'adresse du dossier (`…/Lisiere/`), il ne trouvait rien hors ligne.
- **Hors ligne**, le jeu joue sur la copie du monde gardée dans `donnees/`, comme sans réseau : l'écran-titre le dit (« la copie gardée dans le jeu (hors ligne) »).
- **Les mises à jour** : quand une version nouvelle est publiée, l'application la reçoit en arrière-plan ; elle s'ouvre à l'écran-titre, jamais au milieu d'une partie (`principal.gd`, `_nouvelle_version`).
- **La publication** (`.github/workflows/publication.yml`) : à chaque changement de la branche par défaut, l'export, `outils/pwa.js`, puis GitHub Pages. Une seule fois, à la main : Settings › Pages › Source : « GitHub Actions ».

**L'icône** (`icon.svg`) dit le jeu en une image, celle de `DIRECTION-ARTISTIQUE.md` : une veilleuse au bord d'un feu, et autour, le noir qui regarde. La lisière d'une forêt de sapins, bleu d'encre ; le feu et son cercle de braise ; la veilleuse assise, la capuche levée, l'écharpe rouille dans le vent ; et dans un grand sapin, deux yeux d'ambre qui la regardent. Comme tout le jeu, elle est faite par le code, avec la palette du jeu : `node outils/icone.js` la dessine, `outils/godot.sh --headless --path . --script res://outils/icone.gd` la rend en PNG dans `application/` (« any » aux coins arrondis, « maskable » pleine pour Android, et celle d'iOS). Ce qui compte tient dans le cercle du milieu : Android peut la découper en rond, en goutte, en carré.

## Lancer, essayer, exporter

Godot 4.3 (`outils/godot.sh` le télécharge la première fois, vérifie son empreinte, puis le lance) :

```
outils/godot.sh --path .                                   # jouer
outils/godot.sh --headless --path . --import               # la première fois : importer le projet
outils/godot.sh --headless --path . -- --essai             # l'essai sans écran, sur la copie gardée
outils/godot.sh --headless --path . -- --essai --en-ligne  # l'essai sur le monde publié
outils/godot.sh --modeles-web                              # une fois : les modèles d'export web
outils/godot.sh --headless --path . --export-release Web build/web/index.html   # le jeu dans un navigateur
node outils/pwa.js build/web                               # … en application qu'on installe
outils/godot.sh --path . -- --memoire traque               # jouer avec une mémoire forcée (crainte, confiance, traque, feu, accoutumance) : rien n'est envoyé
outils/godot.sh --path . -- --vitrine --heure nuit         # la vitrine : une scène jouée toute seule, pour regarder
outils/film.sh /tmp/film -- --vitrine --heure jour         # la filmer image par image (et sa planche-contact)
outils/godot.sh --headless --path . -s outils/planche_betes.gd -- --lieu foret --sortie /tmp/planche   # le bestiaire d'un lieu, en une image, sans écran
outils/godot.sh --path . -- --betes --lieu foret            # la vitrine du bestiaire : toutes les bêtes d'un lieu, dans le vrai jeu (--heure nuit, --image, --figees)
```

La vitrine (`scripts/vitrine.gd`) met en scène une partie à une heure choisie (`--heure jour|soir|nuit`, `--duree`, `--lieu`, `--mobile`) : le feu, des bêtes de chaque sorte, la veilleuse qui attend, marche, coupe, chasse, cueille, prend une torche, a peur et se fait mordre. Avec `--temps pluie|orage|crue|neige|brouillard|canicule|incendie`, elle montre le temps qu'il fait : la veilleuse va là où ça se passe (sous un arbre, dans l'eau, près de l'arbre que la foudre frappe, contre les flammes) ; `--image <chemin> --a 0.3,0.6,0.9` en garde des images. `outils/film.sh` la filme avec un vrai rendu, sous un écran virtuel.

L'essai (`scripts/essai.gd`) joue une partie tout seul, en accéléré, et vérifie : le lieu et ses bêtes dessinées, la récolte, les fabrications, la nuit, les chasseurs qui n'entrent pas dans la lumière du feu, le temps qu'il fait (la pluie qui trempe, la boue, la crue, la foudre, l'incendie, la température du corps et sa jauge), la peur dans le noir, les échos, la mémoire (voir plus bas), l'aube, la fin, la partie gardée et reprise, et ce qui est compté pour Orvane. Il sort avec le code 0 si tout passe.

Pour la mémoire, la copie gardée n'en porte pas : l'essai fait chaque bête avec la mémoire qu'aurait sa population, et la joue image par image, sans attendre. Il vérifie que deux mondes pareils sauf la mémoire donnent deux conduites : la distance de fuite d'une proie (sans mémoire, craintive, habituée), les chasseurs autour du feu (aucun n'entre dans sa lumière, traqueur ou non ; celui qui le craint reste dehors et recule à une bûche), devant la torche (tenu ; traqueur, il s'annonce puis passe ; la première nuit, pas encore), le rôdeur qui guette avant de charger et celui qui suit ; puis ce qui est compté (une fois par bête, un assaut pour une série de morsures, rien pour la foudre), ce que le kit ne compte pas quand le monde ne tient pas la mémoire, la ligne du carnet, et `--memoire`.

Sans Godot, `node outils/banc.js` vérifie le projet : chaque fichier qu'il nomme existe, chaque lieu gardé se joue (des proies le jour, des chasseurs la nuit, un dessin pour chaque bête), l'export en fait une application, avec ses icônes. Il compare aussi la copie du kit Godot (`addons/orvane/`) à celle d'Orvane : le jeu choisit quand il la reprend, une copie en retard est seulement signalée.

## Où en est le jeu

- **Écrit** : le jeu entier (`scripts/`, 57 fichiers, et `shaders/`), ses sons (faits par le code), son essai sans écran, sa vitrine, sa configuration d'export web.
- **Vérifié à chaque PR** (`.github/workflows/verifications.yml`) : la syntaxe de chaque script (GDScript 4 avec `gdtoolkit`, JavaScript) ; le banc (`outils/banc.js`) ; et l'essai, dans Godot 4.3, sans écran.
- **Vérifié dans Godot 4.3** (le 7 novembre 2026, au cycle 46) :
  - l'essai sans écran passe, sur la copie gardée (5 lieux) comme sur le monde publié (32 lieux, chacun chargé) ;
  - le même essai, filmé avec un vrai rendu (`--write-movie`, sous un écran virtuel) : le feu et son halo, les chasseurs qui tournent à la lisière, les yeux dans le noir, les morsures, les échos, l'aube, l'écran de fin ;
  - l'export web, joué au clavier dans Chromium (WebGL 2) : l'écran-titre lit le monde en ligne, une partie va de l'éveil jusqu'à la mort dans la première nuit, sans erreur.
- **Corrigé ce jour-là** : la santé remontait de zéro (rassasiée et calme), et la partie ne s'arrêtait pas ; une bête frappée deux fois dans la même image mourait deux fois (deux prélèvements) ; le marais, gardé dans la copie, n'était jamais proposé (les lieux à demi dans l'eau sont jouables : le jeu n'y garde que les bêtes qui marchent) ; un lieu sans proie ni chasseur (l'ossuaire, les terres creuses) était proposé. L'essai ne dépend plus du hasard du directeur, joue son noir en pleine nuit, et vérifie chaque lieu proposé.
- **Le temps qu'il fait, vérifié le 12 novembre 2026** : l'essai sans écran (53 vérifications, en qualité haute et « mobile ») ; dix jours simulés par lieu et par saison pour le régler (une veilleuse qui s'abrite et fait du feu ne perd pas de santé l'été ; la taïga reste vivable ; un orage tous les deux jours en forêt) ; chaque temps regardé dans le vrai rendu, de jour et de nuit ; l'export web joué dans un téléphone émulé (Chromium, WebGL 2) : aucune erreur de shader, 213 à 238 appels de dessin sous l'orage, la crue et l'incendie (219 à 226 par temps clair). **Pas mesuré** : ce que coûtent ces effets sur la carte graphique d'un vrai téléphone (l'émulateur dessine sans carte graphique).
- **La mémoire, vérifiée le 13 novembre 2026** : l'essai sans écran (75 vérifications, dont 14 pour elle), et la vitrine sans écran sous chaque mémoire forcée, sans erreur. Sans mémoire, les 61 vérifications d'avant passent telles quelles. Mesuré par l'essai : un chasseur sans mémoire tourne à 0,80 du rayon du feu, à 1,03 s'il le craint ; la torche le tient à 138 pixels, à 93 s'il s'y est fait (une morsure porte à 56), à 192 s'il la craint ; un traqueur mord 2,3 secondes après s'être annoncé. **Pas vérifié** : ces conduites regardées dans le vrai rendu, ni jouées par une personne (les valeurs sont un point de départ) ; la ligne du carnet à l'écran ; le monde publié, qui ne porte pas encore de mémoire ; `?memoire=` dans un navigateur.
- **Pas encore vérifié** : une partie jouée par une personne, jusqu'au bout ; le jeu sur un vrai téléphone (au doigt, il n'a été joué que sur un téléphone émulé, dans Chromium, avec de vrais touchers multipoints).

- **L'application, vérifiée le 11 novembre 2026** dans Chromium : le manifeste se lit sans erreur, Chromium la dit installable, le service worker garde le jeu entier dès le premier lancement ; puis le serveur arrêté et le réseau coupé, le jeu s'ouvre (à `index.html` comme à l'adresse du dossier) sur la copie gardée. **Pas encore vérifié** : l'installation sur un vrai téléphone.

Filmer l'essai (des images PNG, puis les regarder) : `xvfb-run -a outils/godot.sh --path . --write-movie /tmp/film/f.png --fixed-fps 30 -- --essai`. Pas moins de 30 images par seconde : l'essai joue en accéléré, et à 10 images par seconde la caméra (lissée) s'envole hors du monde.

## Ce qu'on voit, ce qu'on entend

Le jeu a été retravaillé comme par une petite équipe de studio, chacun à son métier, sur une direction artistique commune (`DIRECTION-ARTISTIQUE.md` : l'intention, la palette de `scripts/palette.gd`, comment ça bouge, qui a la charge de quoi). Les règles n'ont pas bougé. Tout est fait par le code : aucune image ni aucun son venus d'ailleurs, sauf deux fontes libres (IM Fell English et Alegreya Sans, licence OFL, dans `polices/`).

- **Le lieu** (`monde.gd`, `objet.gd`, `decor*.gd`) : un sol peint d'après les axes du lieu (terre, mousse, feuilles mortes une à une, neige, boue), cuit par tuiles ; de l'herbe, des fougères et des roseaux qui ondulent au vent et s'écartent devant la veilleuse ; des arbres, sapins, rochers, buissons et touffes à l'encre, qu'on entaille, qu'on abat, qu'on use ; des couronnes qui s'effacent quand on passe dessous ; le décor selon le lieu ; quatre rangs de forêt pour clore le monde.
- **Les bêtes** (`bestiaire*.gd`, `bete.gd`) : dessinées par Lisière, à l'encre, d'après le plan de corps de leur lignée (un cerne plus lourd du côté de l'ombre, trois tons, le dos sombre et le ventre pâle, un œil qui vit ; les couleurs de la lignée, ramenées à des pigments de carnet) : des quadrupèdes (le mufle rond d'un brouteur, le museau en coin et le croc d'un chasseur, des cornes, des crêtes, des carapaces), des hexapodes de chitine, des serpents à écailles, des oiseaux, des bipèdes. Leurs pattes marchent pour de vrai (en diagonale, en trépied, en alternance), sans glisser ; leur queue balance ; elles respirent, clignent de l'œil, broutent, guettent, fuient en bondissant, se tapissent à l'affût ; frappées, elles sursautent ; tuées, elles s'affaissent et leur encre s'émiette ; les serpents ondulent ; les échos sont une fumée pâle. La direction artistique dit comment (`DIRECTION-ARTISTIQUE.md`, « Le bestiaire »).
- **La veilleuse** (`joueur.gd`, `veilleuse_*.gd`) : redessinée, elle se tourne de face, de profil et de dos ; elle marche, respire, tremble de peur ; chaque récolte a son geste, la lance son estoc ; l'écharpe est une chaîne simulée qui prend le vent ; à la fin, elle tombe à genoux, lâche la torche et s'effondre.
- **La lumière et les effets** (`feu.gd`, `yeux.gd`, `effets*.gd`, `shaders/`) : un feu vivant (deux langues de flamme, des braises, des étincelles, une fumée, une lueur au sol, de fausses ombres poussées par sa lumière), dont le cercle de lumière est la zone sûre ; la couleur de l'heure, de l'aube rose au soir mauve et à la nuit bleu d'encre ; une brume au sol ; des yeux qui brillent et clignent ; la caméra qui tremble et l'image qui s'arrête un instant sur un coup ; des particules ; la peur qui ferme et décolore l'écran au rythme du cœur ; la morsure qui le tache de rouge.
- **Le temps qu'il fait** (`ciel.gd`, `temps_sol.gd`, `incendie_flammes.gd`, `sons_temps.gd`, `shaders/temps_*`, `shaders/incendie_*`) : la pluie couchée par le vent, le ciel d'orage, le brouillard, la neige qui tient, la canicule ; le sol détrempé et ses flaques, l'eau montée dans les creux avec sa rive et ses rides, dessinée exactement là où les règles la mettent ; le présage de la foudre, l'éclair, la marque au sol ; des arbres qui flambent à leur taille, la fumée et les braises sous le vent, la lueur la nuit, les souches noires ; la veilleuse trempée, dans l'eau jusqu'aux genoux, transie, en feu ; le givre ou la fournaise aux bords de l'écran ; la pluie, le tonnerre, l'incendie et les pas dans la boue qu'on entend (`DIRECTION-ARTISTIQUE.md`, « Le temps qu'il fait »).
- **L'interface** (`interface*.gd`, `tactile.gd`) : un écran-titre vivant (la lune, trois plans de forêt, la brume, des yeux, la veilleuse au feu) ; des jauges en cercles d'encre, dont celle du corps (la température, la goutte quand on est trempée, la flamme quand on brûle) ; le sac en icônes, où vole ce qu'on ramasse ; des recettes en cartes ; un cadran soleil et lune ; des cartes « Nuit 2 » et « L'aube » ; la pause et la fin en pages de carnet, la fin avec les bêtes croisées dessinées.
- **Le son** (`sons*.gd`) : un vent à rafales qui suit celui de l'herbe ; des oiseaux le jour ; des grillons, des grenouilles, des chouettes la nuit ; les chasseurs qui hurlent ou grondent de leur côté ; un feu qui crépite au hasard ; des pas selon le sol ; la peur qui monte en bourdon et fait battre le cœur ; une musique discrète, en majeur le jour et en mineur la nuit. Il se prépare en arrière-plan, pendant l'écran-titre.

Un seul vent pour tout le lieu (`jeu.vent()`) : l'herbe, les feuillages, les flammes, la fumée, la brume, l'écharpe et le son du vent. En qualité « mobile » (un écran tactile, ou `--mobile`) : moins d'herbe et de particules, pas d'ombres portées, pas d'effet qui relit l'écran, des feuillages et des pierres peints sans leurs cellules, un HUD redessiné vingt fois par seconde au plus, et aucun son fabriqué pendant la partie (ils se font tous au chargement du lieu : « les sons s'accordent »). Dans un navigateur, sur un écran tactile, l'image est calculée à 1,5 fois la résolution CSS au plus, et non à celle de l'écran (2 à 3 fois) ; si elle traîne au début de la première partie (moins de 24 images par seconde), elle passe à 1 : `?dpr=2` (ou 1, ou 3) au bout de l'adresse choisit à sa place. Les icônes, les jetons, les arcs d'encre se tracent une fois dans un maillage gardé, la veilleuse et le feu se rendent d'un seul appel (`scripts/interface_trace.gd`), et les libellés ont un contour, non une ombre (Godot dessine l'ombre lettre après lettre) : sur un téléphone, une image coûtait 1 600 appels de dessin, elle en coûte 250. Le nombre d'images par seconde (et le temps du jeu, les appels de dessin, la résolution) s'affiche par la pause (« Afficher les images par seconde », le choix est gardé), ou par `?ips` au bout de l'adresse (`?ips=0` l'éteint ; `-- --ips` hors navigateur).

## Les choix

Lisière est un jeu du genre survie-horreur (récolter, fabriquer, tenir la nuit, la faim et la peur), avec son propre nom, son propre personnage (une veilleuse encapuchonnée, une écharpe rouille), son propre dessin (celui des planches de naturaliste d'Orvane, l'encre et la braise) et ses propres idées :
- **un écosystème vrai** à la place d'un bestiaire écrit à la main : les bêtes changent quand le monde change, d'un jour à l'autre ;
- **des yeux placés par leur dessin** : dans le noir, on reconnaît une bête à la hauteur de ses yeux, et l'on apprend leur couleur (ambre pour un chasseur, pâle pour une proie) ;
- **les échos** : la peur ne fabrique pas de monstres, elle ramène ce qu'on a tué ;
- **des nuits qui suivent la saison du monde** ;
- **un jeu qui pèse sur le monde** : ce qu'on chasse ici est compté là-bas ;
- **un monde qui se souvient** : les bêtes d'un lieu ont appris des joueurs passés avant, ici et dans les autres jeux d'Orvane. On le lit à leur conduite, puis dans le carnet.

## Ce qui reste

- L'équilibrer, partie après partie (les règles sont toutes dans `scripts/regles.gd`).
- La mémoire, à jouer : ce qu'elle change aux bêtes est écrit dans `scripts/bete.gd`, là où chaque conduite se décide, et n'a été que mesuré. À faire quand le monde la publiera : dire à l'écran-titre ce que les bêtes d'un lieu ont appris, avant d'y entrer.
- Une manette.
- Le jeu sur un vrai téléphone (il n'a été joué que sur un téléphone émulé, dans Chromium, sans carte graphique) : la lisibilité des petits textes, et surtout la vitesse de rendu. Dans Chromium en rendu logiciel, la partie retravaillée coûte environ 20 % de plus que l'ancienne, l'écran-titre environ trois fois plus : à mesurer sur un vrai appareil, et à alléger en qualité « mobile » s'il le faut.
- Une écoute du son : il a été réglé sur des mesures (spectres, niveaux, crêtes), sans oreille.

## D'où il vient

Lisière est né dans le dépôt d'Orvane (`jeux/lisiere/`), comme le premier jeu à se servir du kit Godot. Il a son dépôt depuis le 11 novembre 2026, avec son histoire : les commits d'Orvane qui le touchaient sont ici, réécrits pour ce dossier. Il reste branché sur Orvane comme n'importe quel jeu : il lit le monde publié, et porte une copie du kit Godot (`addons/orvane/`, depuis `kits/godot/addons/orvane/`).

Lisière est distribué sous la même licence qu'Orvane, la [PolyForm Shield 1.0.0](https://polyformproject.org/licenses/shield/1.0.0) (voir [LICENSE](LICENSE)), sauf les deux fontes de `polices/`, sous licence OFL (leurs licences sont à côté d'elles).
