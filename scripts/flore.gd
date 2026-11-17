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
#  - ce qu'on en tire quand on la cueille.
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
	# (les feuilles d'un agave, les tiges d'un papyrus : une fibre longue et raide, dont on commet le filin ; scripts/atelier.gd)
	"agave": "fibre_longue",
	"papyrus": "fibre_longue",
	# (un buisson aromatique, en fleurs ou non : ses brins gris-vert, qui sentent la résine — un baume, une fumée ; scripts/botanique.gd)
	"aromatique": "aromates",
	# (la bruyère garde ses fleurs : avec celles des prés et des mares, elles font l'infusion)
	"bruyere": "fleurs",
	"nenuphar": "fleurs",
}
# les champignons des bois, de Lisière : la part d'amanites parmi eux
const AMANITES := 0.35


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


# ce qu'elle donne à la cueillette ("" : ce que dit son genre)
static func donne(forme: String, genre: String, en_fleurs: bool, a_fruits: bool) -> String:
	if genre == "fleur":
		return "fleurs" if en_fleurs else ""
	if DONNE.has(forme):
		var d: String = DONNE[forme]
		# (ce qui ne fleurit plus donne ses tiges)
		return d if d != "fleurs" or en_fleurs else "fibre"
	if genre == "buisson" and not a_fruits:
		# (un buisson sans fruits qu'on mange : son bois mort)
		return "bois"
	if forme == "lentille":
		return ""
	return ""
