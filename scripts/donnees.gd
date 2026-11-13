extends RefCounted
# Lisière — ce que le jeu lit du monde (scripts/donnees.gd)
# Le monde d'Orvane en ligne, par morceaux, avec le kit (Orvane.lire_lieux, Orvane.lire_silhouettes) ; sans réseau, la copie
# gardée dans donnees/ (outils/secours.js). Puis la faune d'un lieu, rangée comme le jeu la joue : les proies du jour et de la
# nuit, les rôdeurs (des chasseurs qui vivent le jour), les chasseurs de la nuit. Rien n'est inventé : chaque bête est une
# lignée du monde, avec sa masse, sa vitesse, son caractère, son effectif dans ce lieu, et ce que sa population y a appris des
# joueurs (la mémoire d'Orvane, docs/12 et docs/50 : Orvane.dispositions).

const SECOURS := "res://donnees/"
const TERRE := ["marche", "course", "saut", "fouissage", "grimpe", "reptation"]
# la mémoire forcée, pour essayer à la main tant que le monde publié n'en porte pas (-- --memoire <nom>, ?memoire=<nom>) : ce
# que chaque population du lieu aurait appris. Elle ne touche que ce qu'on lit ; une partie jouée ainsi n'envoie rien.
const MEMOIRES := {
	"crainte": {"mefiance": 0.9, "attitude": "fuyante"},
	"confiance": {"habituation": 0.9, "attitude": "familiere"},
	"traque": {"traque": 0.9, "attitude": "traqueuse"},
	"feu": {"neophobie": 0.95},
	"accoutumance": {"neophobie": 0.05},
	"agressivite": {"agressivite": 0.8, "attitude": "agressive"},
	"troupeau": {"mefiance": 0.7, "agressivite": 0.3, "attitude": "fuyante"},
}
# ce que le carnet dit d'une attitude (le mot que publie Orvane), ou à défaut de la disposition qui domine
const ATTITUDES := {"traqueuse": "elle traque les veilleuses", "rodeuse": "elle rôde autour des camps", "quemandeuse": "elle vient quémander",
	"agressive": "elle fait front, et charge", "defensive": "méfiante, elle fait front quand même", "exigeante": "elle exige sa part, et mord qui ne donne rien",
	"fuyante": "elle fuit les veilleuses", "familiere": "familière des veilleuses"}
const SEUIL_DIT := 0.35

var index: Dictionary = {}
var en_ligne := false
var hors_ligne_force := false
# "" : la mémoire du monde, telle qu'il la publie ; sinon un nom de MEMOIRES
var memoire_forcee := ""
var _secours: Dictionary = {}


func charger_index() -> Dictionary:
	if not hors_ligne_force:
		var i = await Orvane.lire_json(Orvane.monde_url.trim_suffix("/") + "/morceaux/index.json")
		if typeof(i) == TYPE_DICTIONARY and i.has("biomes"):
			index = i
			en_ligne = true
			return index
	index = index_secours()
	en_ligne = false
	return index


func index_secours() -> Dictionary:
	if _secours.is_empty():
		_secours = local("index.json")
	return _secours


func local(chemin: String) -> Dictionary:
	var c := SECOURS + chemin
	if not FileAccess.file_exists(c):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if typeof(d) == TYPE_DICTIONARY else {}


# les lieux où l'on peut jouer : sur la terre ferme ou à demi dans l'eau (un marais, une côte : le jeu n'y garde que les bêtes
# qui marchent), avec au moins une proie et un chasseur ; hors ligne, ceux de la copie. L'index ne dit pas comment une lignée
# se déplace : charger_lieu et faune trient ensuite, et le jeu refuse un lieu qui n'a rien à chasser ou personne pour chasser.
func lieux() -> Array:
	var compte := {}
	var proies := {}
	var chasseurs := {}
	for t in index.get("taxons", []):
		if str(t.get("famille", "animale")) != "animale" or str(t.get("statut", "")) == "eteint":
			continue
		var regime := str(t.get("regime", ""))
		var masse := float(t.get("masse_kg", 0.0))
		var chasseur := regime == "carnivore" or (regime == "omnivore" and masse >= 15.0)
		var compte_ici := masse >= 0.2 and regime != "vegetal" and regime != "synthetique"
		for b in t.get("biomes", []):
			compte[b] = int(compte.get(b, 0)) + 1
			if compte_ici and chasseur and masse >= 1.0:
				chasseurs[b] = true
			elif compte_ici and not chasseur:
				proies[b] = true
	var gardes: Array = index_secours().get("secours", {}).get("lieux", [])
	var out := []
	for b in index.get("biomes", []):
		var id := str(b.get("id", ""))
		if not ["terrestre", "amphibie"].has(str(b.get("milieu", "terrestre"))) or not proies.has(id) or not chasseurs.has(id):
			continue
		if not en_ligne and not gardes.has(id):
			continue
		out.append({"id": id, "nom": str(b.get("nom", id)), "lignees": int(compte.get(id, 0)), "garde": gardes.has(id)})
	out.sort_custom(func(a, b): return str(a["nom"]).naturalnocasecmp_to(str(b["nom"])) < 0)
	return out


func biome(id: String) -> Dictionary:
	for b in index.get("biomes", []):
		if str(b.get("id", "")) == id:
			return b
	for b in index_secours().get("biomes", []):
		if str(b.get("id", "")) == id:
			return b
	return {"id": id, "nom": id, "axes": {}}


# un lieu : l'instantané réduit à ce lieu, et ses planches ; en ligne d'abord, la copie sinon ({} : ce lieu ne se lit pas)
func charger_lieu(id: String) -> Dictionary:
	var garde := local("silhouettes/%s.json" % id)
	var herbier := local("herbier/%s.json" % id)
	if en_ligne:
		var inst: Dictionary = await Orvane.lire_lieux([id])
		if not inst.get("taxons", []).is_empty():
			# (docs/49) les plantes du lieu, dessinées, et le temps qu'il y fait : en ligne d'abord, la copie sinon, rien s'il n'y en a pas
			var h: Dictionary = await Orvane.lire_herbier(id)
			if h.is_empty() and not herbier.is_empty():
				Orvane.ajouter_herbier(id, herbier)
			var s: Dictionary = await Orvane.lire_silhouettes(id)
			if s.is_empty():
				# (le monde publié n'a pas encore ses planches : on prend celles de la copie, pour les lignées qu'elle connaît)
				Orvane.ajouter_planche(id, garde.get("silhouettes", {}))
			return inst
	var m := local("biomes/%s.json" % id)
	if m.is_empty():
		return {}
	var inst2: Dictionary = Orvane.assembler(index_secours(), {id: m})
	Orvane.instantane = inst2
	Orvane.ajouter_planche(id, garde.get("silhouettes", {}))
	Orvane.ajouter_herbier(id, herbier)
	return inst2


# la faune d'un lieu, comme le jeu la joue. Chaque entrée : { lignee, id, nom, masse, effectif, poids, sociable, activite, memoire }
# (memoire : { mefiance, habituation, attrait, traque, neophobie, agressivite, attitude }, ce que sa population a appris des joueurs ;
# chaque bête s'en écarte ensuite selon sa propre audace : scripts/bete.gd, _apprendre)
func faune(inst: Dictionary, id: String) -> Dictionary:
	var F := {"proies_jour": [], "proies_nuit": [], "rodeurs": [], "chasseurs_nuit": []}
	var chasseurs := []
	for t in inst.get("taxons", []):
		if typeof(t.get("eteint")) != TYPE_NIL:
			continue
		var p = t.get("plan", {})
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var regime := str(p.get("regime", ""))
		if regime == "vegetal" or regime == "synthetique" or str(p.get("famille", "animale")) == "vegetale":
			continue
		var masse := float(p.get("masse_kg", 0.0))
		if masse < 0.2:
			continue
		var terrestre := false
		for l in p.get("locomotion", []):
			if TERRE.has(l):
				terrestre = true
		if not terrestre:
			continue
		var effectif := 0.0
		for pop in t.get("populations", []):
			if str(pop.get("biome", "")) == id:
				effectif += float(pop.get("effectif", 0))
		if effectif < 1.0:
			continue
		var act := str(p.get("activite", "diurne"))
		var e := {"lignee": t, "id": str(t.get("id", "")), "nom": nom_court(t), "masse": masse, "effectif": effectif,
			"poids": log(effectif + 1.0) / log(10.0) + 0.5, "sociable": float(p.get("sociabilite", 0.3)), "activite": act,
			"memoire": memoire_de(t, id)}
		var chasseur := regime == "carnivore" or (regime == "omnivore" and masse >= 15.0)
		if chasseur:
			chasseurs.append(e)
			if act != "diurne":
				F["chasseurs_nuit"].append(e)
			elif masse >= 1.0:
				F["rodeurs"].append(e)
		else:
			if act != "nocturne":
				F["proies_jour"].append(e)
			if act != "diurne":
				F["proies_nuit"].append(e)
	if F["chasseurs_nuit"].is_empty():
		# (aucun chasseur de nuit ici : la faim fait sortir ceux du jour)
		F["chasseurs_nuit"] = chasseurs.filter(func(x): return float(x["masse"]) >= 1.0)
	return F


# ce qu'une population a appris des joueurs : la mémoire du monde, ou celle qu'on force pour essayer
func memoire_de(t: Dictionary, id: String) -> Dictionary:
	if MEMOIRES.has(memoire_forcee):
		var m: Dictionary = Orvane.DISPOSITIONS_NEUTRES.duplicate()
		m.merge(MEMOIRES[memoire_forcee], true)
		return m
	return Orvane.dispositions(t, id)


# ce que le carnet en dit, en quelques mots ("" : rien à dire, une population que les joueurs n'ont pas marquée)
static func dire_memoire(m: Dictionary) -> String:
	var a := str(m.get("attitude", ""))
	if ATTITUDES.has(a):
		return ATTITUDES[a]
	var feu := (float(m.get("neophobie", 0.5)) - 0.5) * 2.0
	var dits := [[float(m.get("traque", 0.0)), "pour elle, tu es une proie"], [float(m.get("agressivite", 0.0)), "elle a appris à faire front"], [float(m.get("mefiance", 0.0)), "méfiante : on la chasse ici"],
		[feu, "elle craint le feu"], [-feu, "le feu ne l'effraie plus"], [float(m.get("habituation", 0.0)), "habituée aux veilleuses"],
		[float(m.get("attrait", 0.0)), "attirée par les camps"]]
	var mieux := SEUIL_DIT
	var dit := ""
	for d in dits:
		if float(d[0]) > mieux:
			mieux = float(d[0])
			dit = str(d[1])
	return dit


static func nom_de(t: Dictionary) -> String:
	var n := str(t.get("nom_commun", ""))
	if n == "":
		n = str(t.get("nom", t.get("id", "?")))
	return n


# le premier mot du nom (« Losilmé mangeur d'herbe de prairie » → « Losilmé »)
static func nom_court(t: Dictionary) -> String:
	return nom_de(t).split(" ")[0]
