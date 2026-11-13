extends RefCounted
# Lisière — la partie gardée (scripts/partie_gardee.gd)
# Une partie en cours s'écrit sur l'appareil (user://partie.json) : toutes les vingt secondes, à la pause, quand l'application
# passe derrière une autre, quand on revient au titre (principal.gd, _garder). L'écran-titre propose de la reprendre. On garde
# le lieu et sa graine, l'heure, les nuits tenues ; la veilleuse (où elle est, sa santé, sa faim, sa peur, son sac, sa lance, sa
# torche, sa température, si elle est trempée) ; le temps qu'il fait, la boue, l'eau montée ; les feux et leur bois ; le lieu tel qu'on
# l'a laissé (les arbres abattus ou brûlés, les rochers entamés, les buissons qui
# repoussent, les brindilles ramassées ou tombées) ; ce qu'on a croisé et chassé, et les bêtes tuées dont les échos reviennent ;
# le numéro de la partie au tableau des scores. Les bêtes, elles, reviennent d'elles-mêmes. À la fin d'une partie, elle s'efface.

const Feu := preload("res://scripts/feu.gd")
const FICHIER := "user://partie.json"
const VERSION := 1


static func lire() -> Dictionary:
	if not FileAccess.file_exists(FICHIER):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != VERSION or str(d.get("biome", "")) == "":
		return {}
	return d


static func effacer() -> void:
	if FileAccess.file_exists(FICHIER):
		DirAccess.remove_absolute(FICHIER)


static func ecrire(jeu) -> void:
	ecrire_donnees(photo(jeu))


static func ecrire_donnees(d: Dictionary) -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


# ce que dit le bouton de l'écran-titre : « Forêt, jour 3 »
static func resume(d: Dictionary) -> String:
	return "%s, jour %d" % [str(d.get("nom", d.get("biome", ""))), int(d.get("jour", 1))]


static func photo(jeu) -> Dictionary:
	var j = jeu.joueur
	var feux := []
	for f in jeu.feux:
		if is_instance_valid(f):
			feux.append([snappedf(f.position.x, 0.1), snappedf(f.position.y, 0.1), snappedf(f.bois, 0.01), snappedf(minf(f._eteint, 999.0), 0.1)])
	var tuees := []
	for t in jeu.tuees:
		tuees.append(str(t["id"]))
	return {
		"v": VERSION,
		"quand": int(Time.get_unix_time_from_system()),
		"biome": jeu.biome,
		"nom": "Le monde d'Orvane" if jeu.ouvert else str(jeu.biome_info.get("nom", jeu.biome)),
		"graine": jeu.graine,
		"horloge": snappedf(jeu.horloge, 0.01),
		"jour": jeu.jour,
		"nuits": jeu.nuits,
		"croisees": jeu.croisees,
		"chassees": jeu.chassees,
		"tuees": tuees,
		"vues": jeu.vues,
		"rencontres": jeu.rencontres,
		"prelevements": jeu.prelevements,
		"deja": jeu._deja.keys(),
		"partie": jeu.partie_id,
		"joueur": {
			"x": snappedf(j.position.x, 0.1), "y": snappedf(j.position.y, 0.1), "regard": j.regard,
			"sante": snappedf(j.sante, 0.01), "faim": snappedf(j.faim, 0.01), "peur": snappedf(j.peur, 0.01),
			"inventaire": j.inventaire, "lance": j.lance, "torche": snappedf(j.torche, 0.01),
			"temperature": snappedf(j.temperature, 0.1), "trempe": snappedf(j.trempe, 0.1),
		},
		"climat": jeu.climat.photo(),
		"feux": feux,
		"ponts": jeu.ponts.filter(func(x): return is_instance_valid(x)).map(func(x): return [snappedf(x.a.x, 0.1), snappedf(x.a.y, 0.1), snappedf(x.b.x, 0.1), snappedf(x.b.y, 0.1), snappedf(x.tenue, 0.1)]),
		# (un lieu sans bord ne garde que ce qu'on y a changé : le reste se refait de sa graine)
		"ouvert": jeu.ouvert,
		"objets": [] if jeu.ouvert else jeu.monde.photo_objets(),
		"monde": jeu.monde.photo_ouvert() if jeu.ouvert else {},
	}


# la partie reprise : le lieu est déjà semé tel qu'on l'avait laissé (monde.generer, avec les objets gardés) ; le reste ici
static func appliquer(jeu, d: Dictionary) -> void:
	jeu.horloge = float(d.get("horloge", jeu.horloge))
	jeu.jour = int(d.get("jour", 1))
	jeu.nuits = int(d.get("nuits", 0))
	jeu.croisees = int(d.get("croisees", 0))
	jeu.chassees = int(d.get("chassees", 0))
	jeu.partie_id = str(d.get("partie", ""))
	for k in d.get("vues", {}):
		jeu.vues[k] = str(d["vues"][k])
	for k in d.get("rencontres", {}):
		jeu.rencontres[k] = int(d["rencontres"][k])
	for k in d.get("prelevements", {}):
		jeu.prelevements[k] = int(d["prelevements"][k])
	for k in d.get("deja", []):
		jeu._deja[str(k)] = true
	# (les bêtes tuées, retrouvées dans la faune du lieu : leurs échos reviendront)
	for id in d.get("tuees", []):
		var e := _dans_la_faune(jeu.faune, str(id))
		if not e.is_empty():
			jeu.tuees.append({"lignee": e["lignee"], "id": e["id"], "nom": e["nom"], "masse": e["masse"], "effectif": 1.0, "poids": 1.0,
				"sociable": 0.0, "activite": "nocturne"})
	var g: Dictionary = d.get("joueur", {})
	var j = jeu.joueur
	j.position = Vector2(float(g.get("x", 0.0)), float(g.get("y", 0.0)))
	j.regard = float(g.get("regard", 1.0))
	j.sante = float(g.get("sante", 100.0))
	j.faim = float(g.get("faim", 100.0))
	j.peur = float(g.get("peur", 0.0))
	var inv: Dictionary = g.get("inventaire", {})
	for k in inv:
		j.inventaire[k] = int(inv[k])
	j.lance = int(g.get("lance", 0))
	j.torche = float(g.get("torche", 0.0))
	j.temperature = float(g.get("temperature", 50.0))
	j.trempe = float(g.get("trempe", 0.0))
	jeu.climat.reprendre(d.get("climat", {}))
	if jeu.camera != null:
		jeu.camera.reset_smoothing()
	for x in d.get("feux", []):
		if typeof(x) != TYPE_ARRAY or x.size() < 4:
			continue
		var f = Feu.new()
		f.jeu = jeu
		f.position = Vector2(float(x[0]), float(x[1]))
		f.bois = float(x[2])
		jeu.monde.add_child(f)
		f._eteint = float(x[3])
		jeu.feux.append(f)
	for x in d.get("ponts", []):
		if typeof(x) == TYPE_ARRAY and x.size() >= 5:
			jeu.poser_pont(Vector2(float(x[0]), float(x[1])), Vector2(float(x[2]), float(x[3])), float(x[4]))
	jeu._etait_nuit = jeu.lumiere_du_jour() <= 0.0


static func _dans_la_faune(F: Dictionary, id: String) -> Dictionary:
	for k in F:
		for e in F[k]:
			if str(e.get("id", "")) == id:
				return e
	return {}
