# Lisière — le monde ouvert

Le plan pour passer d'un lieu (un biome d'Orvane, 5 400 pixels de côté) à **un monde immense, d'un seul tenant, qui a la
géographie du monde d'Orvane**. Ce document dit ce qui est décidé, les étapes, où on en est. Il se tient à jour à chaque étape.

## Ce qui est décidé (le 12 novembre 2026)

1. **Le même monde pour tous**, tiré d'Orvane. Orvane découpe chaque biome en parcelles voisines, chacune avec sa faune
   (docs/15 d'Orvane) : la carte du jeu est ce réseau, posé sur un plan. Elle ne change que si Orvane change ses parcelles.
2. **La taille** : une région se traverse en une minute et demie de marche (16 000 pixels), le monde en vingt à trente minutes.
3. **Le but ne change pas** : survivre le plus de nuits. On explore librement.
4. **L'eau est une frontière** : ni nage, ni bateau. Mais on fabrique des **ponts éphémères** (voir l'étape 4).
5. Le jeu d'aujourd'hui reste jouable (« un seul lieu ») tant que le monde ouvert n'est pas solide.
6. **On s'éveille au centre, dans la prairie.** Les grottes sont une région comme les autres.

## L'idée

- **La carte** (`outils/carte.js`, `donnees/carte.json`) : chaque parcelle d'Orvane est une région. Deux biomes voisins dans
  Orvane se touchent sur la carte autant que possible ; le froid est au nord, la mer autour. Là où deux biomes de terre se
  touchent sans être voisins dans Orvane, la frontière est **fermée** : une crête, une falaise, on ne passe pas. On ne va donc
  d'un biome à l'autre que par où Orvane le dit.
- **Chaque région a son caractère** : son sol et ses plantes d'après ses axes (comme un lieu d'aujourd'hui), ses bêtes d'après
  ce qui vit dans cette parcelle (`populations[].parcelles`), son temps d'après son climat (`scripts/climat.gd`).
- **Ce qu'on chasse compte au bon endroit** : les lots disent la parcelle (`Orvane.compter(…, parcelle)`, le kit le sait déjà).
- **Le monde n'existe jamais en entier** : seuls les morceaux autour de la veilleuse sont fabriqués (toujours les mêmes au même
  endroit, d'après la graine du monde), puis oubliés. La partie gardée ne retient que ce qu'on a changé (les arbres coupés,
  brûlés, les feux, les ponts) et ce qu'on a découvert.

## Les étapes

Chacune est jouable et vérifiée (l'essai, le téléphone émulé) avant la suivante.

1. **La carte.** *Fait.* `node outils/carte.js` pose les 160 parcelles sur une grille en nid d'abeille (des régions de même
   taille), par un recuit qui cherche à respecter les voisinages d'Orvane, et écrit `donnees/carte.json` (un point par région,
   ses voisines, ses frontières fermées). `--svg` la dessine.
2. **Un biome sans bord.** *Fait, à essayer sur un vrai téléphone.* Le lieu d'aujourd'hui fabriqué par morceaux autour de la
   veilleuse, sans limite : le sol, les objets, les bêtes, le temps qu'il fait, la partie gardée par différences. C'est
   l'étape qui prouve la fluidité sur un téléphone. À l'écran-titre : « La grande prairie », juste après la forêt.
3. **Plusieurs biomes.** *Fait, à essayer sur un vrai téléphone.* Le jeu lit la carte : les régions, les transitions
   (quelques centaines de pixels où les plantes se mêlent), le sol qui passe d'une palette à l'autre, la faune par biome, le
   temps par région, les lots avec leur parcelle. Les frontières fermées sont des crêtes. À l'écran-titre : « Le monde
   d'Orvane ».
4. **L'eau et le relief.** *Fait : les rivières, les gués, le pont ; le relief (paliers, parois, cols) ; les grottes.* Les mers, les lacs, les
   rivières (un vrai cours d'eau, pas une région), les côtes. Les gués, où l'on passe à pied. **Le pont éphémère** : une fabrication (du bois, de la fibre) qu'on pose au bord de l'eau vers l'autre rive, sur
   une largeur limitée (une rivière, un bras de mer étroit, pas un lac). Il ne dure pas : il s'use à chaque passage et avec le
   temps, la crue l'emporte, le feu le brûle. Les bêtes le prennent aussi, les chasseurs compris. Un pont gardé avec la partie.
5. **Se repérer.** *Fait, sauf le tableau des scores.* Une carte dans le carnet, qui se dessine à mesure qu'on explore ; le
   nom de la région quand on y entre ; les régions découvertes au tableau des scores.
6. **Des raisons de voyager.** *Commencé : quatre pays ont leur caractère.* Des ressources qui changent avec le biome, des repères, des camps.

## Où on en est

**Étape 1, faite** (la carte calculée sur le monde d'Orvane publié, graine 1) :
- 160 parcelles : 136 régions de terre (dont 4 de grottes) et 24 d'eau, en 39 biomes ; la haute mer autour ;
- 78 des 85 voisinages entre biomes d'Orvane sont respectés (92 %). Il manque : toundra et lac, désert et côte, maquis et
  montagne, sommets et volcan, récif et haute mer, bois et tourbière, lande et falaise ;
- 17 frontières fermées (des crêtes) ;
- les régions ont la même taille à 9 % près. Dix biomes sont en plusieurs morceaux (deux forêts, deux déserts…) : dans Orvane
  leurs parcelles se suivent, sur la carte pas toujours ;
- les terres font environ 290 000 pixels d'est en ouest : une demi-heure de marche.

**Étape 2, faite** (`scripts/monde.gd`, mode « ouvert ») :
- le lieu se fait par **morceaux de 700 pixels**, à 1 400 pixels autour de la veilleuse (25 à 35 morceaux, 500 à 650 objets :
  autant qu'un lieu fermé), et se défait à 2 300. Un morceau est toujours le même au même endroit (la graine du lieu et sa
  place) ; il se fabrique en 2 à 7 millisecondes, un par image ;
- on ne garde que **ce qu'on a changé** (par morceau : un arbre abattu ou brûlé, un rocher entamé, une brindille ramassée,
  un buisson cueilli, qui repousse pendant qu'on est loin). La partie gardée aussi : 78 octets dans l'essai pour tout un lieu ;
- le décor se sème par rectangle (`scripts/decor.gd`, `semer_dans`), le sol peint n'a plus de limite et ses bruits lents se
  répètent sans couture tous les 5 400 pixels, la fenêtre du sol mouillé (le relief, les flaques) suit la veilleuse, les bêtes
  laissées à plus de 2 600 pixels s'en vont, les brindilles de l'aube tombent autour d'elle ;
- le lieu fermé ne change pas ;
- vérifié : l'essai (8 vérifications pour le lieu sans bord) ; la vitrine (`--ouvert`) sur 6 000 pixels de marche, par temps
  clair et sous la pluie ; l'export web dans un téléphone émulé : 203 à 234 appels de dessin, comme le lieu fermé.
- **pas mesuré** : la fluidité sur un vrai téléphone. Dans l'émulateur (qui dessine sans carte graphique), une image longue
  revient en marchant à chaque nouvelle tuile de sol peint (`scripts/decor_sol.gd` : la tuile est peinte, puis relue de la
  carte graphique). Le lieu fermé a le même coût, mais on y marche moins loin. Si ça saccade en marchant sur un vrai
  téléphone, c'est là qu'il faudra changer de méthode (garder la tuile sur la carte graphique, sans la relire).

**Étape 3, faite** (`scripts/carte.gd`, et le mode « ouvert » de `scripts/monde.gd`) :
- **la carte lue par le jeu** : une région est ce qui est plus près de son point que de tout autre, sur un plan un peu tordu
  (les frontières ondulent ; `Carte.tordre` et `shaders/sol_peint.gdshader` font le même calcul). L'origine du jeu est la
  prairie la plus proche du centre de la carte (`prairie~2`) ;
- **chaque quart de morceau** (350 pixels) est du biome de sa région : ses arbres (des sapins s'il fait froid), ses buissons,
  ses rochers, son herbe et son décor, d'après ses axes ; ses plantes dessinées quand son herbier est lu ;
- **le sol peint** mêle jusqu'à trois régions par tuile : une couche par région, la première partout, les autres là où elles
  sont les plus proches ; la frontière se défait par taches sur 150 pixels ;
- **l'eau** (lacs, rivières, mers) : une étendue sombre, une rive nette, rien n'y pousse, on n'y entre pas (ni les bêtes) ;
- **les crêtes** : une bande de roche fendue et des rochers serrés, là où deux biomes se touchent sans être voisins dans
  Orvane ; on ne passe pas (`Carte.retenir`), mais on y trouve de la pierre ;
- **en passant d'un biome à l'autre** : ses bêtes (son morceau du monde est lu quand on approche à 3 500 pixels de la
  frontière, et ses bêtes dessinées d'avance), son climat (`climat.changer_de_lieu`), son sol sous les pieds, son nom en
  carte de titre ; ce qu'on y voit et ce qu'on y chasse est compté dans son biome et sa parcelle d'Orvane ;
- vérifié : l'essai (13 vérifications pour le monde ouvert, 66 en tout) ; la vitrine (`--ouvert --depuis x,y`) dans la
  prairie, la forêt, le marais, la steppe, le désert, la taïga, sur une rive et devant une crête ; l'export web dans un
  téléphone émulé, d'un biome à l'autre : 198 à 220 appels de dessin, aucune erreur.

**Étape 4, faite pour l'eau** (`scripts/carte.gd`, `scripts/pont.gd`, `shaders/sol_peint.gdshader`) :
- **les rivières** : une région « rivière » d'Orvane est une vallée, de la terre (une prairie humide) que traverse un cours
  d'eau. Son lit suit les zéros d'un champ lent (`Carte.champ`, le même dans le shader du sol) : 110 à 330 pixels de large,
  5 % de la vallée ; il s'amincit vers les terres voisines (une source) et garde sa largeur vers un lac ou une mer. Il arrête
  la veilleuse et les bêtes ; rien n'y pousse ;
- **les gués** (`Carte.champ_gue` ; un cinquième de la longueur du lit) : l'eau y est claire, on voit le fond. On y passe à
  pied : de l'eau jusqu'aux genoux (`climat.eau`), donc ralentie, trempée, et pas de feu ;
- **le pont de fortune** (6 bois, 3 fibres) : posé au bord, vers l'autre berge, jusqu'à 400 pixels. On y passe au sec, les
  bêtes aussi. Il tient 360 secondes, moins 25 à chaque passage de la veilleuse ; la crue l'emporte, le feu le brûle ; ses
  planches manquent quand il s'use. Sa recette (touche 4) et son bouton tactile ne se montrent qu'au bord d'une rivière. Gardé
  avec la partie ;
- **l'eau** (lacs, mers, lits) : un lavis sombre par nappes, des rides, un trait d'encre et un liseré clair sur la rive ;
- la faune d'un biome qu'on approche se dessine une bête toutes les 0,25 seconde, pas à la file ;
- vérifié : l'essai (70 vérifications, 17 pour le monde ouvert) ; la vitrine (`--ouvert --depuis 20420,-11060 --pont`) ;
  l'export web dans un téléphone émulé : aucune erreur de shader.
- sous une neige épaisse, le lit d'une rivière reste visible : il est repeint sur le calque posé par-dessus ce que le temps
  fait au sol (le même que celui des parois du relief) ;
- **reste à faire** : les rivières ne coulent que dans leurs vallées (pas à travers la forêt ou le marais voisins) ; l'eau
  ne bouge pas (elle est peinte avec le sol).

**Étape 4, le relief** (`scripts/carte.gd`, `shaders/sol_peint.gdshader`, `scripts/decor_sol.gd`) — le jeu est vu de dessus :
la hauteur ne se voit pas, elle se dessine comme sur une carte et se sent dans la marche.
- **la force** d'une région vient de l'altitude de son biome (0 pour un pays plat ; montagne 0,6 ; neige et sommets 1 ; le
  canyon, bas pour Orvane, compte comme une montagne). Près d'une frontière, elle se mêle à celle de la voisine sur
  1 500 pixels de chaque côté : le relief a des contreforts, il ne s'arrête pas net ;
- **les paliers** : la hauteur d'un point est un champ de bosses (`Carte.bosses`, le même dans le shader), plus la force.
  Trois paliers ; en montagne un cinquième du pays est sur le premier étage (des plateaux isolés, on circule par les
  vallées), dans les sommets les deux tiers (un haut pays, des cuvettes) ;
- **les parois** : là où la hauteur passe un palier, une bande de roche de 52 pixels qu'on ne franchit pas (ni les bêtes),
  dessinée comme un escarpement de carte : un trait d'encre sur son bord haut, des barbules qui descendent, claire du côté
  du jour, sombre de l'autre, son ombre au pied. Rien n'y pousse ;
- **les cols** (`Carte.champ_col` ; un quart de la longueur des parois, un tous les 500 pixels à peu près) : des rampes
  d'éboulis, aux barbules légères. On y monte à pied, à 72 % de son allure ;
- **plus haut** : l'air perd 0,03 par étage, la caméra recule de 5 % par étage (on voit plus loin) ;
- **sous la neige, la boue, une crue**, les parois restent visibles : elles sont peintes une seconde fois sur un calque
  posé par-dessus ce que le temps fait au sol (`monde.relief_au_dessus`), seulement là où il y a du relief ;
- la force se calcule aux nœuds d'une grille de 256 pixels et se retient : retenir un pas coûte 18 µs en montagne ;
- vérifié : l'essai (4 vérifications pour le relief) ; la vitrine (`--ouvert --depuis -28480,23100 --reste`, et
  `--recul 0.4` pour voir un pays de haut ; `--temps neige`, `--temps pluie`) ; en rendu logiciel, marcher dans les sommets
  coûte un dixième d'images par seconde de plus que dans la prairie (18 à 19 contre 20 à 21) ;
- **sur la carte du carnet** : les parois d'une région connue, en pointillé d'encre brune (là où l'étage change, sauf aux
  cols) ; les bouches d'une grotte, un rond de papier cerclé d'encre. Calculés une région par image, puis retenus.

**Étape 4, les grottes** (`scripts/carte.gd`, `shaders/sol_peint.gdshader`, `scripts/climat.gd`) — les quatre régions
« grotte » d'Orvane (un seul massif, entre la montagne, le volcan, la forêt et la mer) sont sous terre :
- **la roche** : dans une grotte, tout est plein sauf là où le champ `Carte.cavites` est bas. Au cœur, quatre dixièmes de
  roche : par endroits de grandes salles à piliers, ailleurs des boyaux serrés (`Carte.salles`) ; 99,9 % du vide se rejoint ;
- **la muraille** : passé la frontière (cent pixels de dehors), trois cents pixels de roche que seuls les creux les plus
  profonds percent — **les bouches**, une tous les 2 000 pixels à peu près, larges de 100 à 500 pixels. La roche arrête la
  veilleuse et les bêtes (`Carte.plein`, `retenir`) ; elle se dessine noire, son bord fendu, par-dessus la neige aussi ;
- **le noir** : `jeu.sous_terre` (de 0 dehors à 1 passé la muraille) éteint le jour là où est la veilleuse
  (`lumiere_du_jour` ; `jour_du_ciel` garde l'heure vraie). Il fait donc nuit dedans à toute heure : la peur monte hors de
  la lumière, les chasseurs de nuit restent, leurs yeux se voient. À l'écran, ce noir est celui de la roche, plus profond
  que la nuit (`effets.nuit_roche`), et il ne tombe que sous la roche : près d'une grotte, tout l'écran prend cette nuit et
  le jour du dehors lui est rendu par une lumière dont la texture est le masque de l'air libre (`effets._jour_dehors`, 32 × 20
  points autour de la caméra). Du dehors, la bouche est sombre ; du dedans, on voit le jour au bout du boyau ;
- **les sons** : sous terre, ni grillons, ni grenouilles, ni oiseaux, ni chouette ; du vent, il ne reste qu'un souffle
  grave ; tout résonne (les pas, les coups) ; des gouttes tombent, une à une, avec leur écho (`goutte0` à `goutte3`). Entrer
  n'est pas une tombée de la nuit pour la musique ;
- **la flore est celle d'Orvane** (`Objet`, genre « champignon » ; `monde.PORTS`) : l'herbier de la grotte ne porte que
  des champignons, et chacun a ici son dessin et sa règle, d'après sa forme — le **champignon** (un bouquet ocre, deux
  parts), le **champignon lumineux** (vert d'eau, sa lueur dessinée hors de l'ombre : un repère dans le noir), le
  **champignon géant** (deux mètres, un seul pied, trois parts, on bute dessus), la **moisissure** (une plaque pâle sur la
  pierre, rien à cueillir). Leurs parts sont celles de l'herbier. On les cueille comme des baies ; ils repoussent. Hors
  ligne (pas d'herbier pour la grotte), tous sont lumineux ;
- **la faune est celle d'Orvane** : le biome « grotte » se lit en approchant, comme les autres. Comme il y fait nuit à toute
  heure, ce sont ses bêtes du soir et de la nuit qu'on y croise ;
- **l'abri** : `climat.toit` — ni pluie, ni orage, ni neige, ni brouillard, ni vent, ni canicule (ils s'effacent en entrant
  et reviennent en sortant, en une seconde ou deux) ; ni boue, ni crue, ni neige au sol ; un air frais et constant (0,44) ;
- **le sol** : de la pierre nue, fendue, des cailloux ; ni herbe, ni arbre, ni buisson, ni bois mort — on y vient avec ce
  qu'il faut pour le feu et la torche. Des rochers (de la pierre) ;
- vérifié : l'essai (81 vérifications, 5 pour les grottes) ; la vitrine (`--ouvert --depuis -53733,8744 --vers -55300,8500
  --torche`, et `--reste --recul 0.4` pour voir la bouche de haut) ;
- la vitrine : `--herbier fichier.json` donne l'herbier d'un biome à la main (le jeu de l'essai n'a pas le réseau) ;
- **fait le 17 novembre 2026** : hors ligne, la grotte a ses bêtes et son herbier (la copie gardée a maintenant neuf lieux, dont la grotte, la banquise, le volcan et le désert).

**Étape 5, faite** (`scripts/interface_carte_monde.gd`, la page de pause de `scripts/interface_carnet.gd`) :
- chaque région où l'on entre est notée (`jeu.decouvertes`), et gardée avec la partie (par le nom de la région) ;
- **à la pause**, dans le monde ouvert, le carnet montre la carte à la place des commandes (un bouton passe de l'une aux
  autres), si la veilleuse a fabriqué sa carte (`scripts/reperes.gd` ; sans elle, les commandes, et le compte des régions) :
  les régions découvertes au ton de leur biome, avec leur nom ; celles qui les touchent esquissées d'un « ? » (l'eau en
  bleu) ; les crêtes d'un trait double ; le lit des rivières ; les feux, les ponts ; les repères écrits à la plume ; où est
  la veilleuse. Un appui sur la carte change d'échelle : les environs (six régions de large), tout ce qu'on connaît, tout
  près (deux mille pixels, pour lire ses repères) ;
- le contour d'une région (`Carte.contour`) ondule comme sa frontière dans le jeu ;
- **reste à faire** : les régions découvertes au tableau des scores (il faut une colonne de plus dans la base de Stone
  Valley).

**Étape 6, commencée : les pays** (`scripts/biomes.gd`, `scripts/biome_terrain.gd`, `scripts/biome_dessins.gd`, `scripts/climat.gd`) —
d'un biome à l'autre, on jouait la même partie. Quatre ont maintenant un caractère, qui pose un problème et offre quelque chose :
- **le climat** (`climat.changer_de_lieu(axes, meteo, id)`) : en entrant dans le pays, l'air prend son caractère (la banquise
  plus froide, ses nuits bien plus ; le désert brûlant le jour, glacé la nuit), le temps qui vient aussi (la tourmente, la
  pluie de cendres, le vent de sable ; le brouillard au marais ; la canicule hors de l'été au désert), et le sol (la neige
  qui ne fond jamais sur la banquise, le sable qui freine). Le ciel en cours reste ce qu'il est jusqu'à son terme ;
- **le sol** (`scripts/biome_terrain.gd`) : par cases de 600 pixels, d'après la graine, autour de la veilleuse (1 500 pixels ; un
  lieu fermé, tout entier) : les fondrières, les failles, les fumerolles, les mares gelées, les dunes, les scories, et ce qu'on
  ramasse (le bois flotté, surtout près de la mer ; l'obsidienne, la tourbe, les carcasses). Jamais dans l'eau, sur une crête,
  une paroi, la roche. Une case se fait en une demi-milliseconde, se dessine en moins d'une, une fois ; elle se défait à 2 700
  pixels. La partie gardée ne retient que ce qu'on y a pris ;
- **on le dit** en y entrant (une fois par partie, avec le nom de la région) ;
- vérifié : l'essai (25 vérifications, « 9. Les pays » : l'entrée au désert et au volcan dans le monde ouvert, puis chacun des
  quatre dans un lieu fermé) ; la vitrine (`--pres faille`, `--temps tourmente`, `--ouvert --depuis -10724,40502` pour le
  désert, `-29825,42639` le volcan, `9058,-15350` le marais, `31979,-149784` la banquise) ;
- **reste à faire** : d'autres pays (la toundra, la caldeira, les braises, la tourbière en emprunteraient beaucoup) ; la mer
  gelée au bord de la banquise, où l'on marcherait (l'eau reste une frontière) ; le climat ne se mêle pas d'un pays à l'autre à
  leur frontière (il change d'un coup en la passant).

**La répartition de la flore, faite** (`scripts/milieu.gd`, `scripts/recensement.gd` ; `LISEZ-MOI.md`, « Où chaque plante se tient ») :
- **un quart de morceau a le même plan qu'un lieu fermé** (`Milieu.prevoir`) : chaque place porte son milieu (le couvert, l'eau, le sol, la pierre, le sec, le feu…), et la plante s'y tire selon sa part d'Orvane et son goût pour ce milieu. Le plan sait ce qui l'entoure : les berges d'une rivière, d'un lac, d'une mer à portée (`monde._berges` : des points de la rive, le sens où elle file ; une seule lecture de la carte quand l'eau est loin), et le pays (`monde._pays` : les fondrières, les mares gelées, les fumerolles, les failles, les scories, les dunes, que `biome_terrain._lister` dit sans les poser — le pays reprend ensuite la même liste, lue une fois). Au troisième plan, il sait aussi **ce que la carte dit nu** (un lit de rivière, un lac, une paroi, la roche d'une grotte : `monde._contexte_3`) : il n'y prévoit ni arbre, ni place de géant, ni rocher, ni mare — ce sur quoi d'autres places s'appuient (le couvert, le pied d'un arbre, une liane, la couronne d'un rocher, la ceinture d'une mare) ; il ne lit la carte que dans les quarts où il peut y en avoir (de l'eau près, du relief, une grotte, d'après les grilles de la carte), et ceux qui n'en ont pas ne la relisent plus en se posant. **Les places de géants se jugent chez elles** (le couvert du biome du quart où elles tombent, l'eau, la carte) : deux morceaux de part et d'autre d'une frontière voient les mêmes, et se laissent la même trouée. **L'eau des creux est celle de chaque lieu** (`monde.crue_fond_en` : la crue de fond du biome de chaque région — un marais, une mangrove, une jungle en ont ; une prairie, non —, retenue aux nœuds d'une grille de 128 pixels et mêlée entre eux près d'une frontière) : le plan, le temps qu'il fait (`climat.crue_en`, `climat.eau`) et son dessin (`temps_sol`, une petite texture de ces nœuds) la lisent tous trois ; elle ne dépend plus du biome où se tient la veilleuse (avant, les creux d'un marais encore à l'écran se vidaient quand elle passait dans la prairie voisine, et ceux de la prairie se remplissaient, arbres dedans, quand elle entrait au marais) ; la pluie y ajoute partout la même crue. **Le biome de chaque quart ne tient qu'à sa place** (`monde._type_du_quart`), et **un groupe tire une seule plante** (une colonie, une touffe, un fourré : sa première place dit sa cellule de peuplement ; chaque place tirait d'après la sienne, et un groupe à cheval sur deux cellules en mêlait deux) ;
- **les parts de chaque biome** sont réglées une fois, sur un échantillon de son plan : 81 quarts de morceau épars (à sept côtés l'un de l'autre), toujours les mêmes, tirés de la graine — en chargeant pour le biome du réveil (21 ms pour la prairie) ; pour les autres, l'échantillon se fait pendant que leur herbier se lit, quelques quarts par image (`monde.echantillonner`), et le réglage à son arrivée, avec le biome lui-même (`flore_arrivee` : au marais, 13 ms de réglage et 10 pour ses plantes, au lieu de 38 et 12 dans son premier morceau, qui en prenait 67) ; jamais dans un morceau, et rien pour une grotte ni au premier plan, où elles ne servent pas. Les morceaux faits avant que l'herbier arrive sont refaits un par image, pas tous dans la même (la plus longue image, alors : 128 ms avant, 62 maintenant). Un carré d'un seul tenant n'avait que quelques bosquets : les buissons de la lande y trouvaient trois fois plus de places qu'au cœur de la région où on les a comptés, et n'y en tenaient plus qu'un sur trois. Une strate que l'échantillon connaît à peine (les buissons d'un désert, quelques groupes) garde les proportions de ses parts, un seul facteur réglant combien il en vient ; les sortes de places où toutes les plantes ont le même goût se comptent ensemble ;
- **un morceau reste le même** : refait, il porte les mêmes plantes aux mêmes places, et aucune ne déborde chez son voisin ; ce qu'on y change est noté par le rang de sa place dans le plan ;
- **le plan a une version** (`monde.PLAN`, 3) : une partie gardée la dit, et garde jusqu'à sa fin le plan où elle a commencé, où ce qu'elle a changé est noté par rang — un arbre abattu reste une souche, à sa place. Une partie gardée d'avant ne la dit pas : c'est le premier (`_plan_m_1`, chaque strate semée au hasard, une plante par place selon sa seule part) ; une partie au deuxième garde le sien (le troisième n'y change rien : l'essai en garde l'empreinte, pour une graine et 27 morceaux). La partie gardée dit aussi sa version (`partie_gardee.VERSION`, « v ») : un jeu plus ancien, qui ne connaît pas ce plan, la refuse au lieu d'y reporter ces rangs ;
- **mesuré** (`--ouvert --depuis x,y --mesure --duree 45`, graine 7, sans écran ; `LISIERE_TEMPS=1` pour le détail) : la médiane d'un morceau, décor compris, 9 ms dans la prairie du réveil, 11 ms en forêt, 15 ms au marais (le plan 1,4 à 3,3 ms, la pose 3 à 4, le décor 4 à 7) ; le plus long toutes les cinq secondes, 9 à 17 ms dans la prairie (7 à 13 avant), 15 à 25 ms au marais (9 à 18 avant), 12 à 21 ms en forêt (10 à 19 avant). Au troisième plan (`--depuis 2270,-3000 --vers 2270,-11000`, de la prairie au marais ; `--depuis -38000,26839`, la montagne) : le plan d'un morceau prend 1,9 et 2,5 ms à la médiane (1,4 et 1,3 au deuxième), la pose 2,0 et 2,4 (3,3 et 3,4) — la carte lue par le plan, et plus à la pose là où elle ne dit rien nu ; le plus long toutes les cinq secondes reste de 8 à 26 ms (9 à 22 au deuxième). Près d'une rivière, le plan prend 33 ms à la médiane, au deuxième plan comme au troisième (36) : les berges (`_berges`, 36 points par quart, la carte lue cinq fois pour chacun) — à alléger ;
- vérifié : l'essai (« La répartition », 19 vérifications, dont la clairière du réveil, le plan d'un morceau en moins de 60 ms, la partie gardée d'avant) ; le recensement de chaque biome au cœur d'une de ses régions (`--depuis -34083,-505` la forêt, `14873,-31244` le marais, `51307,55476` le désert, `-113900,-14343` la lande, `0,0` la prairie, `10395,-77675` la taïga, `-41436,45982` le volcan, `14992,-153482` la banquise), avant et après.

**Ce que l'étape 3 ne fait pas encore** :
- hors ligne, seuls les neuf lieux de la copie gardée ont leurs bêtes (forêt, prairie, lande, taïga, marais, banquise, volcan, désert, grotte) ; ailleurs, celles du biome d'avant restent ;
- la faune est celle du biome, pas encore celle de la parcelle (la copie gardée ne dit pas la répartition par parcelle) ;
- **pas mesuré sur un vrai téléphone** : la lecture d'un biome en marchant (le réseau, puis une vingtaine de bêtes à dessiner).

## Ce qui reste incertain

- La fluidité sur un vrai téléphone quand le monde se fabrique en marchant : c'est l'objet de l'étape 2.
- La copie du monde gardée dans le jeu (hors ligne) passerait de 9 à 32 lieux : un jeu plus lourd à télécharger (neuf lieux : 2,3 Mo).
- Les parties gardées d'aujourd'hui (un lieu) ne se convertissent pas.
- Les parts de la flore dans le monde ouvert sont réglées sur un échantillon : autour d'un point, elles tiennent à 3 à 5 points près dans les grandes strates, 17 au marais, dont les roseaux vont par colonies de six (le lieu fermé, réglé sur lui-même, à moins d'un point en forêt) ; une petite strate (quelques buissons) dépend du tirage. Un quart de morceau ne voit pas les plantes de son voisin : à son bord, deux plantes « seules » peuvent se toucher.
