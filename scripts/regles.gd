extends RefCounted
# Lisière — les règles du jeu, en un seul endroit (scripts/regles.gd)
# Tout ce qui se règle quand on équilibre le jeu est ici : la durée des jours, la faim, la peur, les feux, les bêtes.

# la clé du jeu Lisière (publique, « orv_… », comme celle de Stone Valley), reçue à l'inscription sur Orvane ; vide, les lots
# restent dans le jeu. La clé d'administration, elle, ne va jamais dans le jeu.
const CLE_JEU := "orv_3754ff9530cdad6b7f037328e0e4e5a4"
# où vont les lots : « orvane », le monde partagé (le cycle de la nuit les lit, comme ceux de Stone Valley) ; « essai », le bac à
# sable (gardés quatorze jours, lus par aucun monde)
const MONDE_DES_LOTS := "orvane"

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
const FAIM := 0.3             # par seconde : de rassasié à affamé en un jour et demi
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
const BAIES_PAR_BUISSON := 2
const REPOUSSE_BAIES := 420.0 # secondes avant qu'un buisson cueilli (un champignon de grotte) ne redonne

# les gestes
const CADENCE := 0.42         # secondes entre deux coups
const PORTEE_COUP := 46.0
const PORTEE_RECOLTE := 44.0
const PORTEE_FEU := 90.0
const DEGATS_POINGS := 8.0
const DEGATS_LANCE := 26.0
const USURE_LANCE := 30       # coups avant qu'elle se brise
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
const TEMPS := {"clair": "temps clair", "couvert": "ciel couvert", "pluie": "pluie", "orage": "orage", "neige": "neige", "gel": "gel", "canicule": "canicule", "tempete": "tempête", "brouillard": "brouillard"}
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
	"lance": {"nom": "Lance", "touche": "3", "cout": {"bois": 2, "pierre": 1, "fibre": 2}},
	# (le monde ouvert : au bord d'une rivière, vers l'autre berge ; scripts/pont.gd)
	"pont": {"nom": "Pont de fortune", "touche": "4", "cout": {"bois": 6, "fibre": 3}},
}
const ORDRE_RECETTES := ["feu", "torche", "lance", "pont"]
const PONT_DUREE := 360.0     # ce qu'un pont tient, en secondes (une journée et demie)
const PONT_PASSAGE := 25.0    # ce que chaque passage de la veilleuse lui retire
# le relief (scripts/carte.gd) : plus haut, l'air est plus froid et la vue plus large
const FROID_PAR_PALIER := 0.03   # ce que chaque étage retire à la température de l'air
const VUE_PAR_PALIER := 0.05     # et de combien la caméra recule
const AIR_SOUS_TERRE := 0.44     # l'air d'une grotte : frais, constant
# la Noire (scripts/noire.gd) : une seule bête, qui n'est pas d'Orvane ; elle vient d'acte en acte, nuit après nuit
const NOIRE_LARGEUR := 330.0     # son dessin, en pixels du lieu (un chasseur de 35 kg en fait 110, la veilleuse 22)
const NOIRE_VITESSE := 215.0     # sa charge (la veilleuse court à 165 : on ne la sème pas à la course)
const NOIRE_VOYAGE := 140.0      # ce qu'elle parcourt par seconde, de sa tanière à la veilleuse, tant qu'on ne la voit pas
const NOIRE_MORSURE := 38.0      # ce que prend chacune de ses morsures
const NOIRE_TANIERE_MIN := 3200.0   # à quelle distance de la veilleuse elle fait sa tanière, au moins
const NOIRE_TANIERE_MAX := 4600.0   # et au plus
const NOIRE_SUIT := 5600.0       # sa tanière plus loin que cela de la veilleuse, à l'aube : elle en change, pour suivre
const NOIRE_ENDURE := 70.0       # ce qu'elle encaisse dans une nuit avant de se retirer jusqu'à la suivante
const NOIRE_DEPART := [1.0, 0.45, 0.3, 0.18, 0.06]   # par acte : la part de la nuit passée quand elle quitte sa tanière
const NOIRE_TORCHE := [0.0, 0.0, 0.0, 14.0, 7.0]     # par acte : le temps que la torche la tient, avant qu'elle passe
const NOIRE_PRESAGE := 1.4       # elle s'aplatit et gronde ce temps-là, avant de charger
const NOIRE_PEUR := 5.0          # la peur gagnée par seconde sous son regard
const NOIRE_REVEIL := 120.0      # le jour, à cette distance de sa tanière, on la réveille
const NOMS := {"bois": "bois", "pierre": "pierre", "fibre": "fibres", "baies": "baies", "viande": "viande crue", "viande_cuite": "viande cuite"}
const ORDRE_INVENTAIRE := ["bois", "pierre", "fibre", "baies", "viande", "viande_cuite"]


# un nom, accordé à son nombre (« 2 pierres », « 1 pierre ») : les autres noms ne changent pas
static func nom(k: String, n: int) -> String:
	return str(NOMS[k]) + ("s" if k == "pierre" and n > 1 else "")
