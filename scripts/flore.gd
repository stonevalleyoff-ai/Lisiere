extends RefCounted
# Lisière — la flore (scripts/flore.gd)
# Ce que Lisière fait de l'herbier d'Orvane (docs/49). Orvane dit quelles plantes poussent dans un biome, leur forme (un
# « pionnier », un « cactus », un « nénuphar »), leur port, leur hauteur, leur part du lieu, leur stade, leurs défenses ;
# Lisière les sème et les dessine à son encre (scripts/flore_dessins.gd), comme elle le fait des bêtes. Chaque forme a ici :
#  - le genre de l'objet qu'elle devient (scripts/objet.gd : un arbre, un sapin, un buisson, une touffe, une fleur, une plante
#    d'eau), qui dit comment il se conduit (on le coupe, on le cueille, il repousse, il brûle) ;
#  - sa strate (les arbres, les buissons, le sol, l'eau, les champignons d'une grotte) : le lieu sème chaque strate à la densité
#    que donnent ses axes (le couvert fait les arbres, l'humidité les buissons…), et chaque place d'une strate revient à l'une de
#    ses plantes, tirée selon sa part. Une strate que l'herbier n'a pas reste vide : pas d'arbre sur la banquise ;
#  - ce qu'on en tire quand on la cueille ; un arbre, ses fruits (FRUITS : la cueillette nourricière, mûre selon la saison et
#    le stade, maturite), une graminée ses grains, le lichen des rennes une soupe, le cactus sa pulpe.
# Une forme qu'on ne connaît pas encore se dessine comme les autres de son port (un arbre, un buisson, une herbe…) ; seule une
# plante d'un port inconnu prend la planche d'Orvane, en secours.
# Lisière a aussi ses plantes à elle, qu'Orvane ne publie pas : les fleurs des prés (« fleur » sans forme) et les champignons des
# bois, le cèpe qu'on mange et l'amanite qui tue.

# forme → [le genre de l'objet, sa strate]
const FORMES := {
	# les arbres : des feuillus (chacun son dessin), le conifère (le sapin du jeu), les palmiers, les fougères arborescentes…
	"arbre": ["arbre", "arbre"], "pionnier": ["arbre", "arbre"], "fruitier": ["arbre", "arbre"], "geant": ["arbre", "arbre"],
	"emergent": ["arbre", "arbre"], "figuier": ["arbre", "arbre"], "bouteille": ["arbre", "arbre"], "sous_bois": ["arbre", "arbre"],
	"palmier": ["arbre", "arbre"], "paletuvier": ["arbre", "arbre"], "fougere_arbre": ["arbre", "arbre"], "conifere": ["sapin", "arbre"],
	# les buissons
	"buisson": ["buisson", "buisson"], "baies": ["buisson", "buisson"], "epine": ["buisson", "buisson"], "ronce": ["buisson", "buisson"],
	"aromatique": ["buisson", "buisson"], "bruyere": ["buisson", "buisson"], "liane": ["buisson", "buisson"],
	# le sol : les herbes, les fougères, les coussins, les lichens, les plantes grasses, les plantes des rives
	"herbe": ["touffe", "sol"], "cereale": ["touffe", "sol"], "grande_herbe": ["touffe", "sol"], "legumineuse": ["touffe", "sol"],
	"fougere": ["touffe", "sol"], "coussin": ["touffe", "sol"], "mousse": ["touffe", "sol"], "lichen": ["touffe", "sol"],
	"lichen_rennes": ["touffe", "sol"], "lichen_croute": ["touffe", "sol"], "succulente": ["touffe", "sol"], "agave": ["touffe", "sol"],
	"cactus": ["touffe", "sol"], "caillou": ["touffe", "sol"], "roseau": ["touffe", "sol"], "jonc": ["touffe", "sol"],
	"riz": ["touffe", "sol"], "papyrus": ["touffe", "sol"], "bambou": ["touffe", "sol"],
	# les fleurs
	"fleur": ["fleur", "sol"], "bulbe": ["fleur", "sol"], "orchidee": ["fleur", "sol"], "bromelia": ["fleur", "sol"],
	# l'eau : sur une mare, au ras de l'eau
	"algue": ["aquatique", "eau"], "lentille": ["aquatique", "eau"], "nenuphar": ["aquatique", "eau"],
	# les champignons d'une grotte (scripts/objet.gd, _etre_champignon)
	"champignon": ["champignon", "champignon"], "champignon_lumineux": ["champignon", "champignon"],
	"champignon_geant": ["champignon", "champignon"], "moisissure": ["champignon", "champignon"],
}
# une forme inconnue, d'après son port : la forme qu'on dessine à sa place
const PORTS := {"arbre": "arbre", "buisson": "buisson", "herbe": "herbe", "roseau": "roseau", "succulente": "succulente",
	"lichen": "lichen", "algue": "algue", "champignon": "champignon"}
# ce qui ne se cueille pas : un tapis au ras du sol (une croûte, une mousse, une plante-caillou), une nappe de lentilles d'eau
const TAPIS := ["mousse", "lichen", "lichen_croute", "caillou", "lentille"]
# ce qui pique : on s'y écorche les mains en cueillant (Flore.pique)
const EPINEUSES := ["epine", "cactus", "ronce", "agave"]
# ce qui fleurit : on y cueille des fleurs, tant que son stade le permet (Flore.fleurit)
const FLEURISSENT := ["fleur", "bulbe", "orchidee", "bromelia", "bruyere", "aromatique", "nenuphar"]
# les stades d'Orvane où rien ne fleurit (« feuilles » : la plante est en pleine pousse, et celles qui fleurissent sont en fleurs)
const SANS_FLEURS := ["nu", "nue", "dormance", "repos", "graines", "fruits", "sec", "seche", "fanee", "mort"]
# ce que donne une forme, cueillie (sinon : le genre décide, scripts/objet.gd, BUTIN)
# (une entrée par ligne : chacun y ajoute la sienne sans toucher aux autres)
const DONNE := {
	"liane": "fibre",
	"bambou": "bois",
	"algue": "fibre",
	"aromatique": "fleurs",
	"bruyere": "fleurs",
	"nenuphar": "fleurs",
	"cereale": "grains",
	"riz": "grains",
	"lichen_rennes": "lichen",
	"cactus": "pulpe",
}
# les champignons des bois, de Lisière : la part d'amanites parmi eux
const AMANITES := 0.35
# la cueillette nourricière : le fruit de chaque arbre qui en porte un à lui (une entrée par ligne). Un autre arbre qu'Orvane dit
# aux fruits charnus (un pionnier, un géant…) porte des grappes de baies, des sorbes ; un conifère n'en porte pas (ses cônes ne
# se mangent pas). Les fruits se dessinent sur l'arbre (scripts/flore_dessins.gd), on les cueille d'« Agir » (scripts/objet.gd,
# cueillir_fruit), et ce n'est qu'un arbre sans fruits qu'on abat pour son bois
const FRUITS := {
	"fruitier": "pomme",
	"figuier": "figue",
	"palmier": "coco",
	"bouteille": "pain_de_singe",
}
# les graminées dont les épis donnent des grains (le premier geste les prend ; le second, la paille : une fibre)
const EPIS := ["cereale", "riz"]
# les stades d'Orvane où les fruits sont mûrs en toute saison ; ceux où l'arbre est en fleurs ; ceux où il n'a rien
const STADES_MURS := ["fruits", "graines"]
const STADES_FLEURS := ["fleurs", "floraison"]
const STADES_NUS := ["nu", "nue", "dormance", "repos", "sec", "seche", "fanee", "mort"]


# ce qu'est une plante de l'herbier pour Lisière : { forme (celle qu'on dessine), genre, strate, planche (vrai : seule la planche
# d'Orvane sait la montrer) }
static func sorte(e: Dictionary) -> Dictionary:
	var forme := str(e.get("forme", ""))
	var port := str(e.get("port", ""))
	if FORMES.has(forme):
		return {"forme": forme, "genre": FORMES[forme][0], "strate": FORMES[forme][1], "planche": false}
	if PORTS.has(port):
		var f: String = PORTS[port]
		return {"forme": f, "genre": FORMES[f][0], "strate": FORMES[f][1], "planche": false}
	# (un port que Lisière ne connaît pas : une touffe du sol, dessinée par la planche d'Orvane)
	return {"forme": forme, "genre": "touffe", "strate": "sol", "planche": true}


# la strate d'où vient un genre d'objet (ce que le lieu sème, et ce qu'une partie gardée ressème)
static func strate_de(genre: String) -> String:
	match genre:
		"arbre", "sapin":
			return "arbre"
		"buisson":
			return "buisson"
		"touffe", "sol":
			return "sol"
		"aquatique", "eau":
			return "eau"
		"champignon":
			return "champignon"
	return ""


# est-elle en fleurs ? (une forme qui fleurit, à un stade qui le permet)
static func fleurit(forme: String, stade: String) -> bool:
	if not FLEURISSENT.has(forme):
		return false
	var s := stade.to_lower()
	for k in SANS_FLEURS:
		if s == k:
			return false
	return true


# porte-t-elle des fruits qu'on mange ? (un buisson à baies, un roncier ; une autre, si Orvane dit ses fruits charnus)
static func fruits(forme: String, caracteres) -> bool:
	if forme in ["buisson", "baies", "ronce", ""]:
		return true
	return typeof(caracteres) == TYPE_ARRAY and caracteres.has("fruits_charnus")


# pique-t-elle les mains qui la cueillent ? (les formes épineuses ; un buisson qu'Orvane dit épineux)
static func pique(forme: String, genre: String, epineux: bool) -> bool:
	return EPINEUSES.has(forme) or (genre == "buisson" and epineux)


# le fruit d'un arbre ("" : il n'en porte pas) : celui de sa forme, ou des baies s'il est dit aux fruits charnus
static func fruit_de(forme: String, genre: String, caracteres) -> String:
	if genre != "arbre":
		return ""
	if FRUITS.has(forme):
		return str(FRUITS[forme])
	if typeof(caracteres) == TYPE_ARRAY and caracteres.has("fruits_charnus"):
		return "baies"
	return ""


# où en sont les fruits d'un arbre et les épis d'une graminée, à cette saison et à ce stade : « murs », « fleurs » (l'arbre
# fleurit, l'épi est vert : rien à manger encore) ou "" (rien : l'hiver, un stade nu). Le stade d'Orvane passe avant la saison ;
# sans lui, l'été et l'automne mûrissent, le printemps fleurit, l'hiver dépouille (hors ligne, c'est toujours l'été)
static func maturite(saison: String, stade: String) -> String:
	var s := stade.to_lower()
	if STADES_MURS.has(s):
		return "murs"
	if STADES_FLEURS.has(s):
		return "fleurs"
	if STADES_NUS.has(s):
		return ""
	match saison:
		"printemps":
			return "fleurs"
		"hiver":
			return ""
	return "murs"


# ce qu'elle donne à la cueillette ("" : ce que dit son genre) ; epis : une graminée a encore ses épis mûrs (sinon, sa paille)
static func donne(forme: String, genre: String, en_fleurs: bool, a_fruits: bool, epis: bool = true) -> String:
	if genre == "fleur":
		return "fleurs" if en_fleurs else ""
	if DONNE.has(forme):
		var d: String = DONNE[forme]
		# (des épis cueillis, ou verts : la paille)
		if d == "grains" and not epis:
			return "fibre"
		# (ce qui ne fleurit plus donne ses tiges)
		return d if d != "fleurs" or en_fleurs else "fibre"
	if genre == "buisson" and not a_fruits:
		# (un buisson sans fruits qu'on mange : son bois mort)
		return "bois"
	if forme == "lentille":
		return ""
	return ""
