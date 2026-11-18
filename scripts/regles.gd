extends RefCounted
# Lisière — les règles du jeu, en un seul endroit (scripts/regles.gd)
# Tout ce qui se règle quand on équilibre le jeu est ici : la durée des jours, la faim, la peur, les feux, les bêtes.

# la clé du jeu Lisière (publique, « orv_… », comme celle de Stone Valley), reçue à l'inscription sur Orvane ; vide, les lots
# restent dans le jeu. La clé d'administration, elle, ne va jamais dans le jeu.
const CLE_JEU := "orv_3754ff9530cdad6b7f037328e0e4e5a4"
# où vont les lots : « orvane », le monde partagé (le cycle de la nuit les lit, comme ceux de Stone Valley) ; « essai », le bac à
# sable (gardés quatorze jours, lus par aucun monde)
const MONDE_DES_LOTS := "orvane"
# le portail StoneValley, où sont les autres jeux et le compte : l'écran-titre y ramène
const PORTAIL := "https://stonevalleyoff-ai.github.io/"

# le lieu : un carré de 4 200 pixels de côté, centré sur le réveil
const DEMI := 2100.0
const ZOOM := 1.35

# le temps : un jour entier dure quatre minutes ; la nuit en prend une part qui dépend de la saison du monde d'Orvane
const DUREE := 240.0
const TRANSITION := 14.0
const NUIT := {"printemps": 0.4, "été": 0.33, "automne": 0.42, "hiver": 0.5}
const NUIT_COULEUR := Color(0.03, 0.035, 0.07)

# le corps
const VITESSE := 165.0
# (la faim, la peur, le froid, la chaleur tuent : chacune prend sur la santé avant d'être à son comble, de plus en plus)
const FAIM := 0.24            # par seconde : de rassasié à affamé en un peu moins de deux jours (un jour et demi, 0,3, était trop court)
const FAIM_MORD := 15.0       # sous ce seuil, la faim prend sur la santé
const FAMINE := 1.8           # la santé perdue par seconde, l'estomac vide (de moins en moins au-dessus, jusqu'à FAIM_MORD)
const BAIE := 12.0            # ce qu'une poignée de baies rend à la faim
const SOIN := 0.2             # la santé regagnée par seconde, rassasié et calme
const PEUR_NOIR := 6.5        # la peur gagnée par seconde dans le noir, la nuit
const PEUR_LUMIERE := 4.0     # perdue par seconde dans la lumière, la nuit
const PEUR_JOUR := 3.0        # perdue par seconde, le jour
const PEUR_PRESENCE := 4.0    # gagnée par seconde, un chasseur à moins de 260 pixels
const PEUR_MORD := 75.0       # au-dessus de ce seuil, la peur prend sur la santé
const PANIQUE := 4.0          # la santé perdue par seconde, la peur au comble (de moins en moins en dessous, jusqu'à PEUR_MORD)
# une morsure : MORSURE + MORSURE_MASSE × log10(masse + 1) points de santé (un kilo : 9 ; cinq : 15 ; trente-cinq : 23)
const MORSURE := 6.0
const MORSURE_MASSE := 11.0
# la cueillette : peu de buissons, deux poignées de baies chacun, qui repoussent en près de deux jours
const BUISSONS := 10.0        # par lieu (4 200 pixels de côté), au plus sec…
const BUISSONS_HUMIDE := 30.0 # … et ce que l'humidité y ajoute
const BAIES_PAR_BUISSON := 3
const REPOUSSE_BAIES := 420.0 # secondes avant qu'un buisson cueilli (un champignon de grotte) ne redonne

# les gestes
const CADENCE := 0.42         # secondes entre deux coups
const PORTEE_COUP := 46.0
const PORTEE_RECOLTE := 44.0
const PORTEE_FEU := 90.0
const DEGATS_POINGS := 8.0
const DEGATS_LANCE := 26.0
const USURE_LANCE := 60       # coups avant qu'elle se brise (on ne la fabrique plus : on la trouve, dans un coffre)
# le lance-pierre (scripts/atelier.gd le fabrique ; scripts/principal.gd tire ; scripts/galet.gd, le galet qui vole)
const DEGATS_TIR := 13.0
const PORTEE_TIR := 300.0     # jusqu'où elle vise une bête : presque tout l'écran, et dans le noir aussi
const CADENCE_TIR := 0.75     # secondes entre deux tirs
const VITESSE_GALET := 620.0
const GALETS_COFFRE := 6      # ceux qu'on trouve avec la lance
const TIR_NOIR := 20.0        # l'écart d'un tir vers des yeux dans le noir, en pixels (de près ; quatre fois plus au bout de sa portée)
const TIR_NOIRE := 0.2        # ce qu'un galet fait à la Noire, en parts de ce qu'il fait aux autres : il l'agace
const DUREE_TORCHE := 75.0
const RAYON_TORCHE := 175.0

# le feu : son bois se compte en secondes de feu
const FEU_DEPART := 60.0
const FEU_BUCHE := 25.0
const FEU_MAX := 150.0

# le temps qu'il fait dans le lieu, ce cycle du monde d'Orvane (docs/45) : ce qu'il fait au feu (son bois brûle plus vite sous
# l'eau et le vent) et à la marche (la neige au sol la ralentit)
const FEU_TEMPS := {"pluie": 1.4, "orage": 1.7, "tempete": 2.0, "neige": 1.25, "brouillard": 1.1}
const NEIGE_AU_SOL := 0.3     # à partir de ce manteau, on marche dans la neige
const ALLURE_NEIGE := 0.8
const TEMPS := {"clair": "temps clair", "couvert": "ciel couvert", "pluie": "pluie", "orage": "orage", "neige": "neige", "gel": "gel", "canicule": "canicule", "tempete": "tempête", "brouillard": "brouillard",
	"tourmente": "tourmente", "cendres": "pluie de cendres", "sable": "vent de sable"}
const TEMPS_DIT := {"pluie": "Il pleut : le feu mange son bois plus vite.", "orage": "L'orage gronde : le feu mange son bois bien plus vite.", "tempete": "La tempête passe : un feu ne tiendra pas longtemps.",
	"neige": "Il neige : le feu mange son bois plus vite.", "brouillard": "Le brouillard est tombé.", "gel": "Il gèle.", "canicule": "La chaleur écrase le lieu."}

# le temps qu'il fait pendant la partie (scripts/climat.gd) : il change d'heure en heure, d'après le climat du lieu
const TEMPS_REPIT := 45.0          # secondes de temps calme, au réveil : de quoi faire un premier feu
const BOUE_MONTE := 0.016           # par seconde, sous une pluie battante : le sol est détrempé en une demi-minute
const BOUE_SECHE := 0.009          # par seconde, sans pluie : trois minutes pour sécher
const BOUE_FREIN := 0.38           # la part de la vitesse perdue dans la boue pleine
const CRUE_MONTE := 0.014          # par seconde, sous la pluie, le sol une fois détrempé : l'eau monte
const CRUE_BAISSE := 0.006         # par seconde, la pluie passée
const EAU_FREIN := 0.45            # la part de la vitesse perdue dans l'eau jusqu'aux genoux
const NEIGE_FREIN := 0.25          # dans un manteau de neige épais
const FOUDRE_ANNONCE := 0.9        # secondes entre le présage (le sol qui pâlit, l'air qui crépite) et la foudre
const FOUDRE_RAYON := 70.0         # jusqu'où elle blesse (près de deux fois plus loin, les pieds dans l'eau)
const FOUDRE_DEGATS := 40.0        # au point d'impact
const FOUDRE_PEUR := 22.0

# le corps et le temps : trempée, la veilleuse prend froid ; trop près des flammes, elle brûle
const TREMPE_PLUIE := 9.0          # points par seconde sous une pluie battante (de sèche à trempée en onze secondes)
const TREMPE_ABRI := 0.15          # la part de la pluie qui passe sous un feuillage
const TREMPE_EAU := 45.0           # par seconde, dans l'eau
const SECHE := 1.6                 # points perdus par seconde, au sec
const SECHE_FEU := 11.0            # près d'un feu
const TEMPERATURE_ALLURE := 0.085  # la part de l'écart que le corps rattrape par seconde
const FROID := 32.0                # en dessous, le froid mord
const CHAUD := 72.0                # au-dessus, la chaleur accable
const FROID_DEGATS := 2.4          # la santé perdue par seconde, à zéro (une nuit froide sans feu ne se passe pas)
const CHAUD_DEGATS := 2.6          # à cent (une canicule à découvert tue en une minute)
const EN_FEU := 4.0                # secondes : le temps que ses vêtements brûlent
const EN_FEU_DEGATS := 6.0         # la santé perdue par seconde, en feu

# l'incendie (scripts/incendie.gd) : la foudre l'allume, le vent le pousse, la pluie l'éteint
const INCENDIE_MAX := 24           # objets en feu à la fois
const INCENDIE_DUREE := {"arbre": 28.0, "sapin": 24.0, "buisson": 12.0, "touffe": 6.0, "souche": 9.0}
const INCENDIE_LUEUR := {"arbre": 125.0, "sapin": 120.0, "buisson": 75.0, "touffe": 45.0, "souche": 55.0}
const INCENDIE_PORTEE := 64.0      # jusqu'où il saute d'un objet à l'autre (plus loin sous le vent)
const INCENDIE_PRISE := 0.3        # la chance qu'il prenne sur un voisin, toutes les deux secondes, par temps sec
const INCENDIE_CONTACT := 24.0     # à cette distance d'un objet en feu, on prend feu
const INCENDIE_ESSOUFFLE := 0.55   # ce qu'un feu garde de force en sautant à un voisin : l'incendie s'essouffle, il ne rase pas le lieu
const FOUDRE_SUR_L_ABRI := 0.25    # sous un arbre pendant l'orage : la part des éclairs qui tombent sur cet arbre-là
const FOUDRE_A_DECOUVERT := 0.2    # seule debout loin de tout arbre : la part des éclairs qui tombent sur elle

# les bêtes
const PROIES_JOUR := 12       # autour du joueur, le jour
const CHASSEURS_MAX := 10
const VAGUE := 20.0           # secondes entre deux venues de chasseurs, la nuit
const ECHOS_MAX := 3

const RECETTES := {
	"feu": {"nom": "Feu de camp", "touche": "1", "cout": {"bois": 4, "pierre": 2}},
	"torche": {"nom": "Torche", "touche": "2", "cout": {"bois": 2, "fibre": 1}},
	# (le lance-pierre ne se fait pas ici mais à l'établi ; ici, on tire : chaque tir prend un galet)
	"tir": {"nom": "Lance-pierre", "touche": "3", "cout": {"galet": 1}},
	# (le monde ouvert : au bord d'une rivière, vers l'autre berge ; scripts/pont.gd)
	"pont": {"nom": "Pont de fortune", "touche": "4", "cout": {"bois": 6, "fibre": 3}},
}
const ORDRE_RECETTES := ["feu", "torche", "tir", "pont"]
const PONT_DUREE := 360.0     # ce qu'un pont tient, en secondes (une journée et demie)
const PONT_PASSAGE := 25.0    # ce que chaque passage de la veilleuse lui retire
# le relief (scripts/carte.gd) : plus haut, l'air est plus froid et la vue plus large
const FROID_PAR_PALIER := 0.03   # ce que chaque étage retire à la température de l'air
const VUE_PAR_PALIER := 0.05     # et de combien la caméra recule
const AIR_SOUS_TERRE := 0.44     # l'air d'une grotte : frais, constant

# --- l'artisanat des plantes : la fibre longue de l'agave et du papyrus, le filin qu'on en commet ; les aromates, leur baume et
# leur fumée (scripts/atelier.gd, scripts/elevage.gd, scripts/pont.gd, scripts/botanique.gd) ---
const PONT_FILIN := 2              # le filin qui lie un pont, à la place de ses trois fibres
const PONT_FILIN_DUREE := 3.0      # ce qu'un pont lié de filin tient de plus : trois fois (quatre jours et demi)
const PONT_FILIN_USURE := 0.4      # ce que chaque passage l'use, en parts de ce qu'il use un pont de fibres
const PONT_FILIN_CRUE := 0.9       # la crue qui l'emporte (un pont de fibres : 0,6 ; scripts/pont.gd)
const FILET_FILIN := 30.0          # la plus grosse bête que retient le grand filet, en kilos (le filet de corde : 8)
const LONGE_AFFOLEE := 2.0         # au bout de sa longe de filin, une bête affolée par le noir a faim tant de fois plus vite
const AROMATES_BAUME := 3          # les aromates d'un baume aromatique (pilés au mortier, liés d'une gorgée d'eau)
const AROMATES_FEU := 2            # ceux qu'on jette dans un feu
const ONGUENT := 40.0              # secondes : le baume aromatique soigne tout ce temps
const ONGUENT_SOIN := 1.5          # la santé qu'il rend par seconde (soixante en tout ; le baume des herbes : 45, d'un coup)
const ONGUENT_POISON := 3.0        # le poison qu'il chasse par seconde, en plus du temps (celui d'une herbe s'en va en cinq secondes)
const ENCENS := 90.0               # secondes : la fumée des aromates sur un feu
const ENCENS_APAISE := 3.0         # la peur qu'elle retire par seconde à qui s'y tient (de quoi tenir sous le regard d'un chasseur)
const PARFUM := 180.0              # secondes : l'odeur qu'elle garde sur elle, sortie de la fumée (les sangsues n'y mordent pas)

# --- les biomes : ce que chaque pays pèse, et ce qu'il offre (scripts/biomes.gd, scripts/biome_terrain.gd) ---
# (le climat de chacun, ses temps à lui et ses sorts de sol sont dans scripts/biomes.gd ; ici, ce qu'ils font au corps)
const TOURMENTE_FROID := 9.0     # ce que la tourmente (la banquise) retire encore au corps, à découvert
const TOURMENTE_FEU := 0.6       # et ce qu'elle ajoute à l'appétit du feu (le vent fouette les braises)
const SABLE_FEU := 0.35          # le vent de sable aussi
const SABLE_FREIN := 0.25        # dans le vent de sable, la part de l'allure perdue
const FUMEROLLE_BRULE := 38.0    # le rayon de la bouffée d'une fumerolle, qui brûle
const FUMEROLLE_DEGATS := 9.0    # la santé perdue par seconde dans la bouffée
const FUMEROLLE_CHAUD := 150.0   # jusqu'où l'on sent sa chaleur
const FUMEROLLE_CHALEUR := 32.0  # ce qu'elle ajoute au corps, tout contre (une nuit au volcan se passe au bord d'une fumerolle)
const FAILLE_CHAUD := 90.0       # jusqu'où l'on sent la chaleur d'une faille
const FAILLE_CHALEUR := 16.0
const FONDRIERE_ENLISE := 0.45   # par seconde, ce qu'elle s'enfonce dans une fondrière si elle s'arrête (à 1 : jusqu'aux cuisses)
const FONDRIERE_SORT := 0.35     # ce qu'elle en sort par seconde, en marchant (enfoncée, trois secondes à peiner)
const FONDRIERE_FREIN := 0.8     # enfoncée jusqu'aux cuisses, la part de l'allure perdue
const SANGSUES := 0.6            # la santé perdue par seconde, enfoncée depuis plus de trois secondes
const TOURBE_FEU := 60.0         # ce qu'une motte de tourbe donne au feu, en secondes (une bûche : FEU_BUCHE)
const BOIS_FLOTTE_REVIENT := 480.0   # la mer rapporte du bois flotté sur le rivage en deux jours
# la Noire (scripts/noire.gd) : une seule bête, qui n'est pas d'Orvane ; elle vient d'acte en acte, nuit après nuit
const NOIRE_LARGEUR := 330.0     # son dessin, en pixels du lieu (un chasseur de 35 kg en fait 110, la veilleuse 22)
const NOIRE_VITESSE := 215.0     # sa charge (la veilleuse court à 165 : on ne la sème pas à la course)
const NOIRE_VOYAGE := 140.0      # ce qu'elle parcourt par seconde, de sa tanière à la veilleuse, tant qu'on ne la voit pas
const NOIRE_MORSURE := 38.0      # ce que prend chacune de ses morsures
const NOIRE_TANIERE_MIN := 3200.0   # à quelle distance de la veilleuse elle fait sa tanière, au moins
const NOIRE_TANIERE_MAX := 4600.0   # et au plus
const NOIRE_SUIT := 5600.0       # sa tanière plus loin que cela de la veilleuse, à l'aube : elle en change, pour suivre
const NOIRE_ENDURE := 70.0       # ce qu'elle encaisse dans une nuit avant de se retirer jusqu'à la suivante
# l'acte de chaque nuit (la première, la deuxième…) : les deux premières nuits, rien ; puis les signes (un appel, au loin) ;
# deux nuits où elle vient regarder ; deux où elle tourne et feinte ; deux où elle charge ; à la dixième, la faim. Après la
# dernière : le dernier acte
const NOIRE_ACTES := [0, 0, 1, 2, 2, 3, 3, 4, 4, 5]
# par acte : la part de la nuit passée quand elle quitte sa tanière (négative : avant la nuit, au crépuscule ; voir la faim)
const NOIRE_DEPART := [1.0, 0.45, 0.3, 0.18, 0.06, -0.3]
const NOIRE_TORCHE := [0.0, 0.0, 0.0, 14.0, 7.0, 4.0]   # par acte : le temps que la torche la tient, avant qu'elle passe
const NOIRE_PRESAGE := 1.4       # elle s'aplatit et gronde ce temps-là, avant de charger
const NOIRE_PEUR := 5.0          # la peur gagnée par seconde sous son regard
const NOIRE_REVEIL := 120.0      # le jour, à cette distance de sa tanière, on la réveille
# --- la Noire, acte 5 : la faim (elle rôde dès le crépuscule, saccage le camp, prend les bêtes attachées) ---
# (scripts/noire_faim.gd. Pour juger : une nuit dure de 79 secondes, l'été, à 120, l'hiver ; un feu neuf éclaire à 198 pixels et
# garde ce qui est à moins de 168 de lui (les 85 centièmes de son rayon), un feu comble à 360 et 306 ; il perd 1,8 pixel de
# rayon par seconde, une bûche lui en rend 45)
const NOIRE_FAIM := 5              # l'acte où la faim commence (elle vaut pour tout acte à partir de celui-là)
# le crépuscule : NOIRE_DEPART vaut -0,3 à cet acte. Elle quitte sa tanière trois dixièmes de nuit AVANT la nuit (24 secondes
# l'été, 29 au printemps, 36 l'hiver), et son appel s'entend quand le jour baisse. De sa tanière (3 200 à 4 600 pixels) il
# lui faut 15 à 25 secondes sans corps (NOIRE_VOYAGE), puis 7 de marche jusqu'à la lisière du feu : 22 à 32 en tout. Elle y
# est donc quand la nuit commence, à quelques secondes près ; l'hiver, où les nuits sont longues, on la voit arriver dans le
# jour qui tombe. Qui a dormi plus loin d'elle la voit toujours arriver plus tard
# la torche : 4 secondes (NOIRE_TORCHE), puis le présage (1,4) et la course (elle part de 215 pixels et reprend 50 pixels par
# seconde à la veilleuse : quatre secondes encore) : moins de dix secondes hors de la lumière, 1 500 pixels à la course. De
# quoi passer d'un feu à l'autre ; plus de quoi aller défendre sa tente la torche à la main
const NOIRE_FAIM_ATTENTE := 12.0   # secondes qu'un feu la tient avant qu'elle se tourne vers le camp (et après une bûche qui l'en a chassée)
const NOIRE_FAIM_REPIT := 26.0     # secondes entre deux choses mises en pièces
# (12 d'attente, une dizaine pour venir, flairer et déchirer, 26 de répit, une dizaine encore : la seconde chose tombe une
# soixantaine de secondes après son arrivée (61 à l'essai). Deux tiennent dans la plus courte nuit, 79 secondes ; une troisième,
# vers 97, n'y tiendrait pas)
const NOIRE_SACCAGES := 2          # ce qu'elle met en pièces par nuit, au plus : une erreur ne coûte pas tout le camp
const NOIRE_FAIM_PORTEE := 900.0   # jusqu'où elle va chercher, depuis le feu qui la tient : là où s'entend encore un son du lieu
const NOIRE_FLAIRE := 4.0          # secondes : elle flaire et gronde, le museau sur la chose, avant d'y mettre la dent (l'annonce)
# (quatre secondes : de quoi jeter une bûche, si l'on est au feu ; la veilleuse en court 660 pixels)
const NOIRE_SACCAGE := 2.6         # secondes : elle la secoue et la met en pièces
const NOIRE_FAIM_BETE := 4.0       # une bête attachée dans le noir : tenue ce temps-là par un feu, elle va à elle (avant toute chose)
const NOIRE_DEVORE := 6.0          # secondes : elle mange la bête qu'elle a prise, la tête basse (le temps de ramener les autres au feu)
# une épave vaut la moitié de la chose : la réparer sur place coûte l'autre moitié de chaque matière (arrondie au-dessus : une
# bâche déchirée est une bâche à refaire), la replier rend la moitié (arrondie en dessous). Une tente (2 bâches, 2 cordes,
# 4 bois) : 1 bâche, 1 corde et 2 bois pour la réparer ; autant, repliée
const NOIRE_EPAVE := 0.5
# --- la Noire, la fin : le collet de filin, l'appât, les cicatrices, son départ ---
# (scripts/noire_collet.gd. Le grand collet se fabrique à l'établi — scripts/atelier.gd, OBJETS, « collet » : 4 filins, soit
# 12 fibres longues, 4 bois pour ses pieux, 4 pierres de lest. Sans sac à dos on porte 20 fibres longues : un collet par
# voyage au chaud ; avec, 40 : trois, sans un de trop. Rompu, il rend ses pieux et ses pierres, pas son filin.)
# Réglé par le calcul, pas encore joué. Ce qui compte : la lance porte à PORTEE_COUP + 0,3 × NOIRE_LARGEUR = 145 pixels du
# milieu de son corps ; tenue, sa gueule porte à NOIRE_COLLET_MORD, et son corps ne va pas plus loin que NOIRE_COLLET_LONGE
# du pieu. Entre 175 et 235 pixels du pieu, la veilleuse la touche au bout de son filin sans qu'elle l'atteigne : une bande
# de 60 pixels (près de trois fois sa largeur, un tiers de seconde de marche), que le filin tendu montre.
const NOIRE_COLLET_FLAIR := 750.0      # jusqu'où elle sent un collet amorcé, de là où elle passe (sa tanière, son chemin, sa ronde autour du camp)
const NOIRE_COLLET_FLAIRE := 2.4       # secondes : elle flaire un collet qui sent la main, le nez dessus, avant de renâcler
const NOIRE_COLLET_PLUIE := 30.0       # secondes d'averse qui lavent d'un collet l'odeur d'une main
const NOIRE_COLLET_TENUE := 15.0       # secondes : le nœud la tient ce temps-là (six ou sept élans : ci-dessous)
const NOIRE_COLLET_RENONCE := 22.0     # secondes : son corps là, en route vers l'appât, sans avoir pu y mettre le nez : elle y renonce pour la nuit
const NOIRE_COLLET_LONGE := 90.0       # jusqu'où va son corps, du pieu, au bout du filin
const NOIRE_COLLET_MORD := 85.0        # tenue par la patte, sa gueule porte moins loin (libre : 100)
const NOIRE_COLLET_ELAN := 0.5         # avant chaque élan elle se ramasse ce temps-là : on la voit venir
# (un élan : 0,5 s ramassée, une demi-seconde à une seconde de course, puis l'à-coup ; 2,2 à 2,7 s en tout)
const NOIRE_COLLET_SONNEE := 1.2       # l'à-coup au bout du filin la jette de côté : elle ne mord pas ce temps-là
# (CADENCE : 0,42 s entre deux coups ; dans cette seconde-là, trois coups de lance tiennent — à 0, 0,42 et 0,84 s —, deux à coup sûr)
const NOIRE_COLLET_BLESSE := 60.0      # ce qu'elle doit prendre, tenue, pour en garder une cicatrice : trois coups de lance (78 ; deux : 52),
# huit coups de poing (64 : trois élans sans une faute). Un galet n'y compte presque pas (2,6). Une morsure prend 38 : on en
# réchappe deux fois, pas trois ; qui reste dans la bande n'en prend aucune
const NOIRE_CICATRICES := 3            # à la troisième, elle quitte le lieu pour de bon (une par nuit au plus)
const NOIRE_CICATRICE_FREIN := 0.09    # ce que chaque cicatrice retire à sa charge : 215, puis 196, puis 176 (la veilleuse court à 165)
const NOIRE_DEPART_PAGE := 7.0         # secondes après l'aube du départ : le temps de voir sa piste, puis la page « Elle est partie. »
# --- la cueillette : les fleurs, les champignons des bois, les épines (scripts/flore.gd, principal.gd : agir, manger) ---
const CHAMPIGNON := 9.0           # ce qu'un cèpe rend à la faim (cru : moins qu'une poignée de baies)
const REPOUSSE_FLEURS := 300.0    # secondes avant qu'une fleur cueillie refleurisse
const REPOUSSE_CHAMPIGNONS := 480.0   # avant qu'un champignon cueilli ressorte de la mousse
const EPINES := 2.0               # la santé que prennent les épines (un cactus, un roncier…), cueillis à mains nues
const FLEURS_INFUSION := 3        # des fleurs, une gorgée d'eau, à la popote sur un feu : une infusion
const INFUSION_PEUR := 30.0       # la peur qu'elle apaise
const INFUSION_CHAUD := 8.0       # et ce qu'elle rend de chaleur au corps (une boisson chaude)
const AMANITE_POISON := 1.0       # une amanite mangée : le poison d'une herbe vénéneuse goûtée, en parts (scripts/botanique.gd, POISON)

# --- la cueillette nourricière : les fruits des arbres, les grains, le lichen des rennes, la pulpe du cactus (scripts/flore.gd,
# objet.gd, principal.gd : agir, manger, cuire ; atelier.gd : la popote, le mortier ; jardin.gd : les grains semés) ---
# (pour juger : la faim perd FAIM × DUREE, près de 58, en un jour ; une poignée de baies rend 12, un cèpe 9, la viande cuite 35,
# le bouillon 50. Un arbre ne nourrit pas mieux qu'un buisson : ce qu'il a de plus, c'est d'être là où il n'y a pas de buisson)
const POMME := 11.0               # une pomme sauvage du fruitier, acide et ferme
const FIGUE := 9.0                # une figue : moins, mais sucrée…
const FIGUE_PEUR := 4.0           # … elle pose un peu le cœur
const COCO := 14.0                # une noix de coco : sa chair…
const COCO_FRAIS := 9.0           # … et son eau, qui rafraîchit comme une gorgée (scripts/atelier.gd, boire)
const PAIN_DE_SINGE := 15.0       # le fruit du baobab, farineux : il tient au corps
const PAIN_DE_SINGE_SANTE := 2.0
const FRUITS_DE_L_ARBRE := {"pomme": [3, 5], "figue": [4, 6], "coco": [2, 3], "pain_de_singe": [2, 3], "baies": [2, 3]}
const PORTE_FRUITS := 0.7         # la part des arbres fruitiers qui portent, cette année (les autres se reposent)
const TOMBES := 2                 # au plus, les fruits tombés au pied d'un arbre chargé : les bêtes qui broutent viennent les manger
const TOMBE_MANGEE := 4.0         # secondes : une bête mange un fruit tombé
const TOMBES_FLAIR := 260.0       # jusqu'où une bête qui broute les sent
const REPOUSSE_FRUITS := 600.0    # secondes (deux jours et demi) : un arbre cueilli jusqu'au dernier fruit en porte de nouveau
const FRUIT_TOMBE := 150.0        # secondes : un arbre chargé lâche un fruit de ses branches au pied, tant qu'il y a de la place
# (sans cela, les fruits tombés qu'une bête avait mangés ne revenaient qu'une fois l'arbre vidé : l'affût au pied d'un arbre
# chargé tient tant qu'il porte)
# les grains : un épi mûr se cueille d'abord (des grains), sa paille ensuite (une fibre) ; crus, ils nourrissent peu, cuits en
# gruau à la popote (des grains, une gorgée d'eau, un feu), ils font un vrai repas ; semés, une récolte (scripts/jardin.gd)
const GRAINS_PAR_EPI := 2         # ce que donnent les épis d'une touffe de céréale, de riz sauvage
const GRAINS_CRUS := 4.0          # une poignée de grains crus : à peine
const GRUAU_GRAINS := 3           # ce qu'il faut de grains pour un gruau (et une gorgée d'eau)
const GRUAU := 40.0               # un gruau : presque un bouillon…
const GRUAU_SANTE := 4.0
const GRUAU_CHAUD := 8.0          # … chaud
# le lichen des rennes : ce qui pousse sur la banquise. Cru, amer, il noue le ventre ; bouilli à la popote, une soupe maigre mais
# vraie : deux soupes et un peu plus par jour tiennent la faim (il faut un feu, de l'eau sous la glace, et deux lichens chacune)
const LICHEN_CRU := 3.0
const LICHEN_CRU_PEUR := 5.0
const SOUPE_LICHENS := 2          # ce qu'il faut de lichens pour une soupe (et une gorgée d'eau)
const SOUPE_LICHEN := 26.0
const SOUPE_LICHEN_CHAUD := 10.0
# la pulpe du cactus : l'eau du désert. Mangée, elle nourrit à peine, mais rafraîchit, et la chaleur pèse moins un moment ;
# pressée au mortier, elle remplit la gourde (deux pulpes, une gorgée)
const PULPE := 3.0
const PULPE_FRAIS := 8.0          # ce qu'elle retire tout de suite à la chaleur du corps
const FRAICHEUR := 45.0           # secondes : le temps qu'un fruit frais (la pulpe, la coco) allège la chaleur…
const FRAICHEUR_CIBLE := 10.0     # … de tant (la chaleur que le corps cherche, en plein soleil : un désert passe de 78 à 68)
const PULPES_GORGEE := 2
const MANGER_FRAIS := 66.0        # au-dessus, « Manger » prend d'abord ce qui rafraîchit (une coco, la pulpe)

# --- le milieu des plantes : où chacune se tient dans le lieu, d'après sa forme et ses caractères d'Orvane (scripts/milieu.gd :
# ses règles, forme par forme ; scripts/monde.gd : le plan ; scripts/recensement.gd : ce qui en sort, compté) ---
# les arbres
const MILIEU_GEANT := 4.0             # la place d'un géant : celle de quatre arbres (sa part d'Orvane est une part du couvert, pas un nombre de pieds)
const MILIEU_TRONES := 520.0          # une place de géant au plus par cellule de tant de pixels de côté…
const MILIEU_TRONE_COUVERT := 0.6     # … là où le couvert (de 0 à 1) est au moins tel : le cœur d'un bosquet
const MILIEU_DEGAGE := 115.0          # rien d'autre ne pousse à moins de tant d'un géant (son dessin est le plus large du lieu)
const MILIEU_ESPACE_ARBRES := 38.0    # deux troncs ne sont jamais plus près que cela (leur dessin a grandi d'un cinquième)
const MILIEU_COEUR := 0.72            # le couvert au-dessus duquel un arbre est au cœur d'un bosquet
const MILIEU_LISIERE_ARBRES := 0.45   # en dessous : il est en lisière…
const MILIEU_ISOLE := 0.2             # … et en dessous : seul dans le pré
const MILIEU_PEUPLEMENT := 300.0      # un peuplement (une boulaie, une sapinière) : une cellule de tant de pixels…
const MILIEU_COHESION_ARBRES := 0.7   # … où cette part des arbres est de la même espèce
# le sol, les buissons
const MILIEU_BOSQUET := 0.5           # le couvert au-dessus duquel le sol est « sous les arbres »…
const MILIEU_LISIERE := 0.25          # … et au-dessus duquel il est « en lisière »
const MILIEU_COUVERT := 62.0          # sous un arbre : à moins de tant de son tronc
const MILIEU_ROCHER := 46.0           # contre un rocher : à moins de tant
const MILIEU_BUTTE := 0.62            # le sol est « au plus sec » là où ses grandes plaques passent ce seuil (les buttes)
const MILIEU_SOL := 90.0              # les plantes du sol d'un lieu (4 200 pixels de côté), sous un couvert entier…
const MILIEU_SOL_DECOUVERT := 235.0   # … et ce que le découvert y ajoute
const MILIEU_TOUFFES := 0.62          # les groupes de places du fond, pour une plante du sol voulue (un groupe : de trois à six places)
const MILIEU_GROUPE := 6              # les places d'un groupe, au plus (une colonie, une touffe, un arc de ceinture)
const MILIEU_ECART := 30.0            # deux groupes du sol ne sont jamais plus près…
const MILIEU_ECART_SEC := 100.0       # … et dans un lieu sec : les racines se partagent l'eau
const MILIEU_SOUS_BOIS := 0.3         # les groupes offerts au pied des arbres, par arbre (aux fougères, aux mousses)
const MILIEU_AU_ROCHER := 0.6         # ceux offerts autour des rochers, par rocher (aux lichens, aux coussins)
const MILIEU_FOURRES := 0.7           # les fourrés (de deux à quatre places), pour un buisson voulu
const MILIEU_LIANES := 0.12           # les places de liane au pied des arbres, par arbre, dans un lieu humide
# l'eau
const MILIEU_MARES := 10.0            # les plantes d'eau d'un lieu, au plus sec…
const MILIEU_MARES_BOUE := 80.0       # … et ce que la boue y ajoute (elles vont par mares de deux à cinq)
const MILIEU_MARES_RESERVE := 1.25    # il y en a tant de fois plus au plan : une année d'eaux hautes les remplit toutes
const MILIEU_OVALE := 0.45            # une mare est vue de biais : sa hauteur, pour sa largeur
const MILIEU_RIVE := 34.0             # au bord d'une mare : à moins de tant de son eau
const MILIEU_RIVE_ARBRES := 60.0      # … pour un arbre (le palétuvier, ce qui a des échasses)
const MILIEU_ARBRES_DE_RIVE := 0.7    # la part des mares qui ont un arbre sur leur bord (la place du palétuvier, de ce qui a des échasses)
const MILIEU_BERGE := 70.0            # sur une berge : à moins de tant de l'eau d'une rivière, d'un lac
const MILIEU_BERGES := 0.8            # la part des points de berge trouvés qui portent un groupe de rive
# le réglage des parts (milieu.gd, regler)
const MILIEU_TOURS := 40              # les tours du réglage
const MILIEU_POIDS_MAX := 8.0         # un poids ne monte pas plus haut que tant de fois la part : une plante sans milieu ici ne va pas se poser n'importe où
const MILIEU_ECHANTILLON := 2800.0    # (le monde ouvert) le côté du carré où le plan d'un biome est essayé, pour régler ses parts
# la météo d'Orvane (production, secheresse, eaux, e) : ce qu'elle fait aux densités (milieu.gd, densites)
const MILIEU_SECHERESSE_SOL := 0.5        # une sécheresse entière ôte cette part des plantes du sol…
const MILIEU_SECHERESSE_BUISSONS := 0.3   # … et celle-ci des buissons
const MILIEU_EAUX_FOND := 0.85            # la part des mares en eau quand les eaux sont au plus bas…
const MILIEU_EAUX := 1.0                  # … et ce que les eaux du cycle y ajoutent
# la cueillette de Lisière (les fleurs des prés, les champignons des bois), par lieu : comme avant, avec une réserve
const MILIEU_FLEURS := 20.0
const MILIEU_FLEURS_HERBE := 140.0
const MILIEU_CHAMPIGNONS := 130.0
const MILIEU_CUEILLETTE_RESERVE := 1.25   # il y en a tant de fois plus au plan : la météo dit combien servent

const NOMS := {"bois": "bois", "pierre": "pierre", "fibre": "fibres", "baies": "baies", "viande": "viande crue", "viande_cuite": "viande cuite"}
const ORDRE_INVENTAIRE := ["bois", "pierre", "fibre", "baies", "viande", "viande_cuite"]


# un nom, accordé à son nombre (« 2 pierres », « 1 pierre ») : les autres noms ne changent pas
static func nom(k: String, n: int) -> String:
	return str(NOMS[k]) + ("s" if k == "pierre" and n > 1 else "")
