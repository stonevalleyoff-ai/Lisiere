# Lisière — la direction artistique

*L'encre et la braise.* Ce document tient l'équipe ensemble : ce que le jeu doit faire ressentir, ce qu'on voit, comment ça bouge, qui fait quoi, et comment on vérifie. Les règles du jeu ne bougent pas : on retravaille la façon dont il se montre, s'anime et sonne.

## L'intention

Lisière doit tenir dans une image : **une veilleuse au bord d'un feu, et autour, le noir qui regarde.** Le jour est un carnet de naturaliste : des bêtes vraies, dessinées à l'encre, dans une lumière douce. La nuit est une veillée : tout ce qui compte tient dans un cercle de braise, et le reste n'existe que par des yeux.

Trois sensations, par ordre d'importance :
1. **La chaleur précieuse.** Le feu est la chose la plus belle de l'écran. Il vit, il crépite, il pousse l'ombre des troncs, il réchauffe les couleurs. Le quitter doit coûter.
2. **Le noir qui a des yeux.** La nuit n'est pas noire : bleu d'encre, brume, silhouettes. On devine plus qu'on ne voit. Les yeux disent qui est là.
3. **Des bêtes vraies.** Chaque bête marche, respire, sursaute, fuit, tombe. Elles viennent du monde d'Orvane (chaque bête est une lignée, avec son plan de corps) ; leur dessin, lui, est celui de Lisière : à l'encre, comme le reste du carnet (« Le bestiaire », plus bas).

## Ce qu'on voit

- **La vue** : de dessus, un peu de biais (trois quarts). Les objets ont un pied, une ombre au sol, une hauteur. On passe derrière les troncs ; un feuillage qui cache la veilleuse s'efface.
- **La matière** : l'encre (des contours sombres, fins, un peu irréguliers), le papier (des grains, des nuances douces dans les aplats), la braise (des lueurs additives, chaudes). Rien de plastique, rien de flou : net, dessiné.
- **La lumière** :
  - le jour, douce et un peu dorée ;
  - le soir, orange puis mauve ;
  - la nuit, bleu d'encre (`NUIT`, `NUIT_BLEUE`, `LUNE`) ;
  - l'aube, rose et pâle.

  Le feu et la torche sont les seules lumières chaudes. Dans leur cercle, les couleurs reviennent ; dehors, elles se retirent.
- **La valeur** : la nuit, la plus grande part de l'écran est très sombre ; l'œil va au feu, puis aux yeux. Le jour, des valeurs moyennes, des ombres nettes au sol.
- **La palette** : `scripts/palette.gd`. Une couleur qui n'y est pas se tire de celles-là.
- **L'icône** (`icon.svg`, faite par `outils/icone.js`) : l'intention en une image. La lisière d'une forêt de sapins, bleu d'encre ; un feu et son cercle de braise ; la veilleuse assise, la capuche levée, l'écharpe rouille dans le vent ; et dans un grand sapin, deux yeux d'ambre qui la regardent (deux pâles plus loin). Le vent pousse la flamme, les étincelles et l'écharpe du même côté. Ce qui compte tient dans le cercle du milieu : Android peut la découper en rond.
- **La typographie** : un titre à l'empattement de gravure (une fonte libre, licence OFL, gardée avec sa licence dans `polices/`), un texte courant lisible et sobre. Jamais la fonte par défaut à l'écran-titre.

## Comment ça bouge

- **Tout réagit.** L'herbe s'écarte au passage, un buisson cueilli frémit, un arbre frappé lâche des feuilles, un rocher des éclats, une bête frappée recule et sursaute.
- **Le poids** : une anticipation avant le geste, un suivi après (l'écharpe continue, la cape retombe) ; un léger écrasement à l'impact ; un arrêt d'image de quelques centièmes sur un coup, plus long sur une mise à mort ; la caméra tremble à la morsure.
- **Le corps qui faiblit se voit, comme ce qui arrive à une page de carnet** (`scripts/effets.gd`, `_le_corps` ; les deux shaders d'écran) : l'écran n'est pas un hublot qui se couvre de givre ou de rouge (ce que font tant d'autres jeux), c'est la page du naturaliste qui souffre, dans l'encre et le papier du reste. La peur la froisse (des pans plats penchés, de longs plis droits partis des bords ; la nuit, les plis prennent la lumière). La faim la jaunit en auréoles et la pique de rousseurs, l'encre y pâlit ; ses crampes y font avancer le jaune d'un coup. La santé qui s'en va y fait boire de l'encre rouge, frange, liseré et gouttes, qui gonfle avec un cœur lourd. Le froid y grave un givre de hachures bleues. La chaleur en roussit et en charbonne les bords, une ligne de braise au front. La caméra, elle, porte le corps : elle tangue de faim, grelotte de froid, se serre au cœur lourd. Sur un téléphone (sans la passe qui lit l'image), le voile seul les porte.
- **Le vent** : une seule respiration pour tout le lieu (herbe, feuillages, flammes, brume, son du vent), lente, avec des rafales.
- **Les bêtes** : leurs pattes (les morceaux de leur dessin) marchent pour de vrai, le corps oscille au pas, la tête suit ; au repos, elles respirent et regardent ; la fuite est un bond. Sans pattes (serpents, poissons), le corps entier ondule.
- **La mesure** : rien ne gigote sans raison. Des mouvements lents au repos, vifs dans l'action.

## L'équipe

| département | fichiers dont il a la charge | ce qu'il livre |
| --- | --- | --- |
| Environnement | `scripts/monde.gd`, `scripts/objet.gd`, `scripts/flore*.gd`, `shaders/sol*`, `shaders/vegetation*` | le sol peint, l'herbe qui ondule, la flore de chaque biome dessinée d'après l'herbier (« La flore »), rochers redessinés, le vent dans les feuillages, les feuillages qui s'effacent devant la veilleuse, des détails (fougères, bois mort, bruyère, flaques selon le lieu), la lisière du monde |
| Créatures | `scripts/bete.gd`, `scripts/bestiaire*.gd`, `scripts/squelette.gd`, `scripts/vitrine_betes.gd`, `outils/planche_betes.gd`, `shaders/bete_encre.gdshader` | les bêtes dessinées par Lisière d'après le plan de corps de leur lignée (« Le bestiaire »), animées (pattes, pas, respiration, regard, queue), les réactions (sursaut, recul, fuite), la mort (chute, puis l'encre qui s'efface), les échos (fumée d'encre pâle) |
| La veilleuse | `scripts/joueur.gd` | la veilleuse redessinée et animée : marche, course, attente, respiration, gestes de récolte (couper, casser, cueillir, ramasser), coup de lance, torche, blessure, peur (elle se recroqueville), chute |
| Lumière et effets | `scripts/feu.gd`, `scripts/yeux.gd`, `scripts/effets.gd`, `shaders/feu*`, `shaders/ecran*` | le feu (flammes, braises, fumée, chaleur), la torche, la couleur du monde à chaque heure, la brume de nuit, les yeux, la caméra (secousse, arrêt d'image), les particules (éclats, poussière, feuilles, braises, lucioles), les effets d'écran (peur, blessure, faim, santé basse, froid, chaud, grain, vignette) |
| Interface | `scripts/interface.gd`, `scripts/tactile.gd`, `polices/` | l'écran-titre (une scène vivante), le HUD (jauges, objets dessinés en icônes, recettes en cartes), les cartes de titre (« Nuit 2 », « L'aube »), les objets récoltés qui volent vers le sac, l'écran de fin en page de carnet (les bêtes croisées, dessinées), la pause, les boutons tactiles |
| Son | `scripts/sons.gd` | l'ambiance (vent à rafales, grillons, chouettes, hurlements au loin), le feu qui crépite et éclate, les pas selon le sol, des sons de gestes plus riches, le cœur, un réverbère la nuit, une nappe musicale sobre, des notes à la tombée de la nuit et à l'aube ; tout fait par le code |
| Le temps qu'il fait | `scripts/ciel.gd`, `scripts/temps_sol.gd`, `scripts/incendie_flammes.gd`, `scripts/sons_temps.gd`, `shaders/temps_*`, `shaders/incendie_*` (et, dans les fichiers des autres, ce qui touche au temps : l'objet en feu, la veilleuse trempée, le givre à l'écran, la jauge du corps) | ce qui tombe, le sol détrempé, l'eau montée, la foudre, l'incendie, ce que le temps fait à la veilleuse, et ce qu'on en entend (« Le temps qu'il fait ») |
| Direction (intégration) | `scripts/principal.gd`, `scripts/essai.gd`, `scripts/vitrine.gd`, `scripts/regles.gd`, `scripts/donnees.gd`, `project.godot`, ce document | les accroches entre départements, l'intégration, la passe finale de cohérence, les essais |

Un département ne modifie que ses fichiers. S'il lui faut une accroche ailleurs, il la demande à la direction (son rapport le dit), et il peut l'ajouter, pour essayer, dans sa copie seulement.

## Le bestiaire

Les bêtes de Lisière sont dessinées par Lisière. Le monde d'Orvane donne à chaque lignée un **plan de corps** (`plan.corps` : sa forme, ses pattes, la longueur de son corps, de son cou, de son museau, ses oreilles, sa queue, ses cornes, sa crête, sa carapace, son motif, ses organes, ses couleurs) ; Lisière en fait un dessin à l'encre, dans ses tons, à une taille qui se lit en jouant. La planche d'Orvane ne sert plus que de secours (une forme qu'on ne sait pas encore dessiner).

**L'intention.** Une bête est une page du carnet qui s'est levée : dessinée par quelqu'un qui l'a regardée longtemps. On la reconnaît à sa silhouette avant de voir ses détails. De jour, elle est belle et vraie : on a envie de la regarder brouter. De nuit, un chasseur est une masse d'encre et deux yeux d'ambre.

**Le dessin**
- **La silhouette d'abord.** Trois masses qui se lisent à 40 pixels : la tête, le corps, l'arrière (la cuisse, la queue). Ce que dit le plan se voit, et se force un peu (de longues oreilles sont plus longues, un long museau plus long : d'un quart environ). Deux lignées aux plans différents ne se confondent pas.
- **L'encre.** Un cerne net (`p.e`, de 1,2 à 2,1 pixels), plus lourd en bas à droite, du côté de l'ombre (`p.volume` le fait). Les traits du dedans sont plus fins (la moitié). Des hachures courtes, rares, là où la forme tourne (le poil du dos, la cuisse, l'ombre du ventre) ; aucune sur une bête de moins de 44 pixels. L'encre est `P.ENCRE`, jamais un gris.
- **Trois tons.** La lumière vient d'en haut à gauche : un ton clair, le ton de la robe, un ton d'ombre qui tire vers le bleu de la nuit. Le dos est plus sombre, le ventre plus pâle. Les pattes, l'oreille, la corne du côté qu'on ne voit pas sont dans le ton lointain.
- **Les couleurs** viennent de la lignée, accordées au jeu (`Bestiaire.tons`) : sa teinte reste, mais ramenée à un pigment de carnet (un bleu vif devient un bleu d'ardoise, un rose un vieux rose). On ne prend de couleur que dans `p.tons` : la robe, la lumière, l'ombre, le dos, le ventre, le lointain, l'accent (le creux d'une oreille, une crête, une caroncule), l'œil, l'os (cornes, griffes, crocs), la truffe.
- **L'œil** fait vivre la bête : toujours lisible (jamais sous un pixel et demi de rayon), un éclat de papier en haut à gauche. Une proie a l'œil rond et sombre ; un chasseur, l'œil d'ambre sous une arcade qui tombe.
- **Le caractère.** Une proie : des formes rondes, la tête haute qui guette, des oreilles qui se voient ; elle donne envie de ne pas la tuer. Un chasseur : des angles, la tête basse en avant des épaules, des épaules fortes, un croc qui dépasse, des griffes claires ; il fait peur même immobile.
- **La mesure.** Rien de mécanique : les contours passent par `p.vivant` (la main tremble un peu), et la même lignée se dessine toujours pareil (le hasard vient de `p.r`, semé par son nom). Rien de plastique : pas de dégradé lisse sans encre dessus, pas de flou.

**La taille** (`Bestiaire.largeur_de`) : la largeur du dessin, du nez au bout de la queue, d'après la masse. La veilleuse fait 22 pixels de large et 44 de haut. 200 g : 38 ; 1 kg : 48 ; 5 kg : 66 ; 35 kg : 98 ; 60 kg : 109 ; un chasseur, 12 % de plus. Une bête d'un kilo se lit d'un coup d'œil ; un grand chasseur domine la veilleuse.

**La technique**
- `scripts/bestiaire.gd` : l'entrée (`lire`, `portrait`, `largeur_de`, `tons`), le cache. `scripts/bestiaire_planche.gd` : la planche, ses gestes (`volume`, `aplat`, `tracer`, `cerne`, `hachures`, `poils`, `bandes`, `taches`, `oeil`, `patte`, les chemins `ferme`, `ouvert`, `ruban`, `bords`, `ellipse`, `vivant`). Une forme par fichier : `scripts/bestiaire_<forme>.gd`, avec `static func dessiner(p)`.
- Les mesures sont en pixels montrés ; l'origine est le point où la bête touche le sol, sous son milieu ; elle regarde à droite ; y monte vers le négatif. Tout tient dans la largeur `p.L` et dans 1,1 `p.L` de haut.
- Quatre calques, de l'arrière vers l'avant : `queue` (elle balance : `p.pivot("queue", …)` à sa racine), les pattes lointaines, `corps`, les pattes proches, `dessus` (ce qui passe devant elles : l'épaule, une carapace, une aile repliée), `tete` (le cou et la tête, qui pivotent : `p.pivot("tete", …)` à la base du cou). Un corps sans pattes (un serpent) tient dans `corps` seul, avec `p.onde = true` : le shader le fait onduler.
- Une patte (`p.patte`) : ses articulations de la hanche au pied posé (y = 0), trois points au moins, sa largeur à chacune. La bête plie le genou et pose le pied (`bete.gd`, `_ik`) ; les morceaux sont dessinés couchés dans un atlas.
- Le dessin est un SVG que Godot change en image (deux pixels d'image par pixel montré) : des chemins, des cercles, des ellipses, des découpes (`clipPath`), des dégradés linéaires, de l'opacité. Pas de filtre, pas de texte, pas d'image. Il se fait sans écran (`--headless`), en quelques millisecondes par bête.
- Une bête coûte peu : quatre calques au plus et deux couches de pattes (six à huit appels de dessin). Pas de calque de plus.

**Vérifier**
```
outils/godot.sh --headless --path . -s outils/planche_betes.gd -- --lieu foret,lande,marais,prairie,taiga --sortie /tmp/planche
        # toutes les bêtes, au repos, sur les tons du sol : /tmp/planche_jeu.png (comme en jouant), /tmp/planche_agrandi.png
        # (--forme hexapode, --id tiskata,dunvi pour n'en voir que certaines)
outils/godot.sh --path . -- --betes --lieu foret --figees --image /tmp/betes      # dans le vrai jeu, une image par page
outils/godot.sh --path . -- --betes --lieu foret --heure nuit --image /tmp/betes  # de nuit
outils/film.sh /tmp/film -- --betes --lieu foret --page 1 --duree 8               # filmées : elles vont, broutent, guettent
```

## La flore

Le principe du bestiaire vaut pour les plantes : **Orvane donne la plante, Lisière la dessine.** L'herbier du biome dit ses lignées, leur forme, leur part, leur hauteur, leur stade, leurs défenses ; `scripts/flore.gd` en fait des objets du lieu, `scripts/flore_dessins.gd` les dessine à l'encre. La planche d'Orvane n'est plus qu'un secours, pour un port que Lisière ne connaît pas.

- **Un biome se reconnaît à sa flore.** Pas d'arbre dans l'herbier, pas d'arbre : la banquise est un pays de lichens à plat et de coussins poudrés de neige, le volcan et le désert de cactus en candélabre, d'agaves, de plantes grasses, de buissons d'épines ; le marais a ses palétuviers sur échasses, ses fougères arborescentes, ses bambous, ses joncs, ses mares à nénuphars ; la taïga ses conifères parmi les bouleaux. Sur le sol nu, les plantes vont par petits groupes de la même lignée : c'est par elles que se lit un lieu sans arbres.
- **La silhouette d'abord**, comme pour une bête : le bouleau à son fût blanc taché d'encre, le palmier à son fût annelé qui se courbe, le baobab à sa bouteille, le figuier à ses racines qui tombent du feuillage, le roncier à ses tiges arquées, l'aromatique à ses épis dressés, l'agave à ses dards, le lichen des rennes à ses boules de corail, l'amanite à son rouge piqué de blanc. Une plante se lit à la taille du jeu (une fleur des prés fait dix pixels, un cactus géant dépasse la veilleuse).
- **Le dessin** : celui des arbres et des buissons (`objet.gd`) : un cerne d'encre net, plus lourd en bas à droite ; les aplats peints par le shader de végétation selon leur matière (un feuillage en touffes, une écorce en cylindre, un dôme lisse pour un chapeau, une baie, une feuille charnue) ; la lumière en haut à gauche. Les couleurs viennent de la palette, tirées vers la couleur de la plante dans l'herbier (son vert, celui de ses fleurs, ramené vers les encres du carnet).
- **Ce qui se cueille se voit** : un buisson perd ses baies une à une, une fleur cueillie laisse sa tige coupée puis des boutons verts, un champignon son pied tranché, un cactus entamé un bras en moins (sa chair à nu, pâle et mouillée, une goutte qui perle), un nénuphar sa fleur, un aromatique ses brins coupés court ; une fleur qui repousse se redessine par quarts.
- **Ce qui nourrit se lit à sa silhouette, petit comme il l'est** (`flore_dessins.gd`, « la cueillette nourricière ») : sur la couronne, la pomme ronde et luisante et sa queue (une feuille de temps en temps), la figue en goutte prune, le col en haut, la noix de coco grosse, en grappe sous les palmes, le fruit du baobab, une gourde de velours pendue à un long fil, les sorbes en grappes orangées ; un ou deux tombés dans l'herbe, devant le tronc. Leurs places sont tirées une fois de la graine de l'arbre : on en cueille une, elle manque, les autres ne bougent pas. Vidé, l'arbre se couvre de fruits verts tirant sur le jaune, qui grossissent par quarts ; au printemps, des fleurs pâles à leur place. L'épi mûr est doré et ploie ; cueilli, la tige est coupée net ; vert au printemps, il se tient droit. Le lichen des rennes perd un pan, puis n'est plus qu'une galette. Au jardin, les grains talent, épient, puis dorent. Et la veilleuse se hisse sur la pointe des pieds pour cueillir dans les branches, le buste en arrière, le bras tendu ; la couronne frémit et lâche des feuilles.
- **Ce que ça coûte** : un objet se dessine une fois (et quand il change), en un seul appel ; une fleur des prés est une colonie de six à neuf corolles dans un seul objet. Les fleurs et les champignons ne sont plus du décor : ils sont dans le plan du lieu, comptés avec le reste.

**Regarder** : `outils/godot.sh --path . -- --vitrine --heure jour --lieu volcan|desert|marais|banquise` ; dans le monde ouvert, `--ouvert --depuis x,y --reste` ; `--cueillette` : elle cueille fleurs et champignons des bois ; `--fruits` : les fruits des arbres, les épis, le lichen, les cactus ; `--planche arbres|sol|geste [--gros] --nu` : la cueillette nourricière en planche, chaque plante à chacun de ses états (`--page sac --nourrir` : ses icônes, dans le sac).

**Ce que la plante devient** (l'artisanat des plantes : `scripts/atelier.gd`, `scripts/botanique.gd` ; leur dessin dans `campement.gd`, `harnais.gd`, `pont.gd`, `effets_herbes.gd`, `atelier_icones.gd`) se reconnaît à sa matière. Le **filin** est blond (la braise pâle tirée d'un tiers vers la terre), plus gros que la corde de chanvre, ses torons en biais, son bout surlié de sombre : la longe d'une bête, la maille du grand filet et ses nœuds, les mains courantes et les liures d'un pont lié. Les **aromates** sont gris-vert (la mousse vers la lune, éclaircie), à épis mauves ; leur **fumée** est un lavis bleu de lune, plus fin, plus haut et plus clair que la fumée âcre, ocre : on voit le camp au travers, et sa nappe s'arrête au bord de la lumière, là où elle apaise. L'**odeur** gardée se voit : des volutes bleues montent des épaules de la veilleuse, puis de plus en plus rares. Ce que ça coûte : la fumée est celle de la botte âcre (deux rectangles peints, deux émetteurs), l'odeur un émetteur de cinq particules (trois sur un téléphone) ; le filin d'une longe se redessine avec elle, comme la corde. Regarder : `--vitrine --lieu desert --artisanat --page sac`, `--pose filet_filin --etat prise --loupe 2`, `--pose piquet --aupres piquet --compagne longe,piquet,affolee`, `--botanique encens,parfum`, `--pont-ici`.

**La fin de la Noire** (`scripts/noire_collet.gd` ; le dessin : `collet_dessin.gd`, `noire_cicatrices.gd`, `interface_depart.gd`) se dit dans les mêmes matières. Le **grand collet** est du filin blond, couché en rond sur la terre qu'on a dégagée : on voit qu'il est ouvert (deux petites fourches le soulèvent), où est son œil (surlié de sombre), où il tient (deux pieux croisés, leur liure, leurs pierres) ; l'appât est un morceau de viande sombre, pas un rouge de jeu. Tenue, c'est **le filin qui montre la règle** : droit et vibrant au bout de son élan, mou quand elle se ramasse ; les pieux penchent vers elle et jouent dans leur trou, la terre saute, ses griffes labourent le sol là où il l'arrête (on y lit jusqu'où elle va) ; sonnée, sa tête pend. Aucun cercle, aucune jauge. Rompu, tout est couché du côté où elle est partie. Ses **cicatrices** sont de la peau, pas du papier : un ivoire rosé, terni, sans poil, un bourrelet d'encre du côté de l'ombre, le poil d'à côté qui retombe en travers ; elles ne changent rien à son poil, semé par son nom. La nuit on ne voit d'elle que ce que la torche ou le feu accrochent : c'est voulu, le collet est hors de la lumière. Sa **couche** vide est un creux d'herbe couchée en rond, froid : du poil, des os, les nœuds rongés. La **page** de son départ est celle de la fin, sans mort : elle sort de la feuille du côté où elle a quitté le lieu, ses empreintes s'effacent devant elle. Regarder : `--noire collet|prise|part|cicatrices 2`, `--pose collet,collet,collet,couche --etat planche --loupe 2`.

## Le temps qu'il fait

Les règles sont dans `scripts/climat.gd` (le temps de la partie, le sol, la foudre), `scripts/incendie.gd` et `principal.gd` (`_temps_du_corps`) ; les nombres dans `scripts/regles.gd`. Le dessin ne décide de rien : il **montre ce qui pèse**, et c'est sa première règle. On doit lire d'un coup d'œil où est l'eau, où la boue est épaisse, où la foudre va tomber, ce qui brûle et jusqu'où, dans quel état est la veilleuse.

- **Ce qui tombe, ce qui couvre** (`ciel.gd`) : la pluie en traits d'encre claire, du crachin à l'averse, couchée par le vent et ses rafales (un seul MultiMesh, animé par son shader) ; un voile sans lecture d'écran pour le ciel d'orage (l'ombre des nuages passe, sans rendre le jeu illisible : la nuit, il assombrit moins), les rideaux de pluie, le brouillard qui ne laisse voir qu'autour de soi et des feux, la neige, la lumière écrasée de la canicule. En qualité haute seulement, l'air tremble sous la canicule.
- **Le sol** (`temps_sol.gd`, `shaders/temps_sol.gdshader`) : un seul grand rectangle sous ce qui se tient debout. Le relief et le bruit des flaques du climat y sont cuits une fois dans deux petites textures : **l'eau est dessinée exactement là où `climat.eau(p)` la met** (la même formule), les flaques là où `climat.allure(p)` freine le plus. La boue est un lavis de sépia, ses flaques ont un bord où le pigment se dépose ; l'eau montée a un trait d'encre sur sa rive, un liseré clair, des rides couchées, plus sombre où c'est profond ; la pluie y fait des ronds, la veilleuse aussi. La neige tient par plaques puis partout, bleutée dans ses creux.
- **La foudre** : le présage (le sol pâlit jusqu'où elle blessera, un cercle se resserre, des étincelles montent : une seconde pour s'écarter, lisible sous l'averse et de nuit), puis l'éclair (un trait brisé du haut de l'écran, ses branches, blanc bleuté cerné), l'éclat sur tout l'écran (plus faible si elle tombe hors de la vue), l'image qui reste dans l'œil, une marque brûlée au sol.
- **L'incendie** (`incendie_flammes.gd`, `objet.gd`, `shaders/incendie_*`) : de la famille du feu de camp, en plus grand et plus sauvage. Les flammes sont dans le dessin de l'objet (à sa taille, à sa place parmi les autres : un arbre en feu reste derrière ce qui est devant lui), penchent et s'étirent sous le vent, faiblissent à la fin et sous la pluie. La fumée file sous le vent ; les braises volent jusqu'où le feu peut sauter (c'est par elles qu'on le comprend). Au sol, la terre brûlée et ses braises disent où l'on prend feu, sans cercle. La nuit, deux ou trois lumières par groupes de foyers, pas une par foyer. Ce qui a brûlé rougeoie un moment puis refroidit : une souche noire, de la cendre ; ce que la pluie a sauvé reste debout, roussi.
- **La veilleuse** (`joueur.gd`, `veilleuse_*.gd`) : trempée, elle s'assombrit et goutte ; dans l'eau, ses jambes disparaissent, des rides et un sillage la suivent ; dans la boue, elle peine et en arrache des éclats ; transie, elle grelotte, se voûte, bleuit, son souffle fait de la buée ; accablée de chaleur, elle rougit ; en feu, des flammes courent sur elle, et une bouffée de vapeur quand l'eau les éteint.
- **L'écran et l'interface** : le givre gagne par les bords quand elle a froid, ils rougeoient quand elle a trop chaud ou qu'elle brûle (dans le voile qui existe déjà, `shaders/ecran_voile_herbes.gdshader`). La **jauge du corps** est un anneau à deux branches depuis le haut (vers la gauche le froid, vers la droite la chaleur, les deux zones qui blessent marquées au bout), un thermomètre au centre, une goutte au coin quand elle est trempée, une flamme quand elle brûle ; son mot change (« Froid », « Gelée », « Chaud », « Brûlante », « Trempée », « En feu »).
- **Le son** (`sons_temps.gd`) : la pluie du crachin à l'averse, autre sous un feuillage (on entend l'abri) et les pieds dans l'eau ; le présage qui grésille, le claquement, le roulement qui arrive en retard quand la foudre est loin ; le ronflement et les craquements de l'incendie selon sa distance ; les pas dans la boue, l'eau, la neige ; le corps qui brûle, s'éteint, grelotte ; et ce qui se tait (les oiseaux sous la pluie, tout sous la neige, la musique sous l'orage).

**Ce que ça coûte** : une quinzaine d'appels de dessin au pire moment (un orage, l'eau montée, vingt-quatre foyers), aucun par temps sec ; rien n'est fait « par goutte » ni « par objet en feu ». Ce sont des rectangles peints au pixel : sur un téléphone, c'est la résolution de l'image qui les paie, et le jeu la baisse de lui-même s'il traîne (`principal.gd`, `_regler_image`). Le shader du sol a une version simple pour la qualité « mobile ».

**Regarder** : `outils/godot.sh --path . -- --vitrine --temps orage|pluie|crue|neige|brouillard|canicule|incendie [--heure nuit] [--mobile]` ; un état précis avec `--boue 0.8 --crue 1 --neige-sol 0.5 --force 0.4 --vent 0.9 --corps 10` ; un grand feu avec `--feu brasier|restes|pluie` ; `--image <chemin> --a 0.3,0.7` pour garder des images ; `--mesure` et `--sans ciel,sol,flammes,son` pour chercher ce qui coûte.

## Les accroches (déjà posées dans `principal.gd`)

- `effets` (`scripts/effets.gd`) : `nouvelle_partie(scene, camera, obscurite)`, `vider()`, `maj(delta)`, `teinter(obscurite, l)`, `secousse(force)`, `arret(duree)`, `impact(p, couleur)`, `mort(p, couleur, largeur)`, `recolte(p, genre)`, `allumage(p)`, `blessure()`, `echo(p)`, `tombee()`, `aube()`, `fin()`.
- `joueur` : `geste(genre, vers)` (une récolte), `frapper()` (un coup), `blesser(n)`, `mourir()` (la santé à zéro ; l'écran de fin vient `DUREE_MORT` secondes après).
- `ui` : `carte(titre, sous_titre)`, `ramasse(objet, n, p)` (p : où, dans le lieu), `blessure()`, `message(t, couleur)`.
- `sons` : `maj(jeu, delta)` (chaque image), `jouer(nom, volume_db, hauteur)`, `niveau(boucle, v)`, `taire()`.
- `jeu.qualite` : `"haute"` (un ordinateur) ou `"mobile"` (un écran tactile ; pour l'essayer : `-- --vitrine --mobile`). En `"mobile"` : moins de particules, pas d'ombres portées, pas d'effet qui lit l'écran.

## Les contraintes

- **Godot 4.3, rendu Compatibility** (il tourne dans un navigateur, en WebGL 2). Pas de compute, pas de 3D. Les shaders `canvas_item` sont permis. Un effet qui lit l'écran (`hint_screen_texture`) seulement en qualité haute.
- **Aucune image, aucun son venus d'ailleurs** : tout est dessiné par le code (`_draw`, des images générées, des shaders), et tout son est fait par le code. Seule exception : des fontes libres (OFL), avec leur licence.
- **La performance** : 60 images par seconde sur un ordinateur, 30 et plus sur un téléphone moyen. Le lieu a près de 900 objets : on ne les redessine pas à chaque image (le vent passe par un shader), l'herbe en masse passe par un `MultiMeshInstance2D`.
- **Les règles ne bougent pas** : `regles.gd`, les dégâts, les durées, ce qui est compté pour Orvane. L'essai (`-- --essai`) doit passer, sans écran comme avec.
- **Sans écran** (`--headless`), rien ne doit planter : pas de rendu, mais le code tourne.
- **Le code** : GDScript 4, indenté aux tabulations, commenté en français dans le style des fichiers existants (court, juste, sans jargon).

## Vérifier

```
outils/godot.sh --headless --path . --import                 # une fois, dans une copie neuve
outils/godot.sh --headless --path . -- --essai               # l'essai : il doit passer
gdparse scripts/*.gd                                         # la syntaxe, comme la CI
node outils/banc.js                                          # le projet, le kit, le monde gardé, l'application
outils/film.sh /tmp/film -- --vitrine --heure nuit           # filmer la vitrine : regarder /tmp/film/planche.png
outils/film.sh /tmp/film -- --vitrine --heure jour --duree 10
```

La vitrine (`scripts/vitrine.gd`) met en scène une partie : le feu, des bêtes de chaque sorte, la veilleuse qui attend, marche, coupe, chasse, cueille, prend une torche, a peur et se fait mordre. On la filme avant et après chaque changement, et on compare.
