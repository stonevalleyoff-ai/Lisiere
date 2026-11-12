extends Node
# Lisière — la vitrine (scripts/vitrine.gd)
# Une scène jouée toute seule, pour regarder le jeu et le filmer : un lieu, une heure, un feu, des bêtes de chaque sorte, et la
# veilleuse qui fait ce qu'on fait en jouant (attendre au feu, marcher, couper un arbre, cueillir, chasser, se faire mordre).
# Rien n'est vérifié ici (c'est le travail de l'essai) : on regarde.
#   outils/godot.sh --path . -- --vitrine [--heure jour|soir|nuit] [--duree 12] [--lieu foret]
#   outils/film.sh <dossier> -- --vitrine --heure nuit      (filmée image par image, et sa planche-contact)
# Le temps qu'il fait, montré (scripts/climat.gd) : --temps pluie|orage|crue|neige|brouillard|canicule|incendie. La veilleuse
# attend, tourne, puis va là où ça se passe (sous un arbre, dans l'eau, près de l'arbre frappé, contre les flammes).
#   --image <chemin> --a 0.3,0.6,0.9   écrit <chemin>_1.png, _2.png… à ces moments (en fractions de la durée)
#   --mesure   dit toutes les cinq secondes les images par seconde, la plus longue image, les appels de dessin
#   --sans son,ciel,sol,flammes,effets   éteint une chose, pour chercher ce qui coûte

const R := preload("res://scripts/regles.gd")

var jeu
var heure := "nuit"
var duree := 12.0
var lieu := "foret"
var _t := 0.0
var _pret := false
var _plan: Array = []          # [debut, fin, geste]
var _fait := {}
var _coup := 0.0
var temps := ""
var image := ""
var moments: Array = []
var _but := Vector2.ZERO
var _regles := {}              # (l'atelier : --boue, --crue, --neige-sol, --force, --vent, --corps (sa température), pour voir un état précis)
# (l'atelier « feu » : --feu brasier|restes|pluie, --nu (sans l'interface), --appels (les appels de dessin, à la fin))
var feu := ""
var nu := false
var appels := false
var _appels_max := 0
var _appels_somme := 0.0
var _appels_n := 0
var _brules: Array = []


func _ready() -> void:
	jeu = get_parent()
	var a := OS.get_cmdline_user_args()
	for i in a.size() - 1:
		match a[i]:
			"--heure":
				heure = a[i + 1]
			"--duree":
				duree = float(a[i + 1])
			"--lieu":
				lieu = a[i + 1]
			"--temps":
				temps = a[i + 1]
			"--feu":
				feu = a[i + 1]
				temps = "incendie"
			"--image":
				image = a[i + 1]
			"--boue", "--crue", "--neige-sol", "--force", "--vent", "--corps":
				_regles[a[i]] = float(a[i + 1])
			"--a":
				for x in a[i + 1].split(","):
					moments.append(float(x))
	nu = a.has("--nu")
	appels = a.has("--appels")
	_lancer.call_deferred()


func _lancer() -> void:
	jeu.donnees.hors_ligne_force = true
	await jeu.donnees.charger_index()
	await jeu._commencer(lieu)
	var soir: float = R.DUREE * (1.0 - jeu.part_nuit)
	match heure:
		"jour":
			jeu.horloge = R.TRANSITION + 30.0
		"soir":
			jeu.horloge = soir - R.TRANSITION * 0.6
		_:
			jeu.horloge = soir + 12.0
	var j = jeu.joueur
	j.inventaire["bois"] = 40
	j.inventaire["pierre"] = 12
	j.inventaire["fibre"] = 12
	j.inventaire["baies"] = 3
	if heure != "jour":
		jeu.fabriquer("feu")
		jeu.feux[0].ajouter(3)
	jeu.fabriquer("lance")
	var F: Dictionary = jeu.faune
	for i in 3:
		if not F["proies_jour"].is_empty():
			jeu._creer(F["proies_jour"][i % F["proies_jour"].size()], "proie", j.position + Vector2.from_angle(i * 2.1 + 0.4) * randf_range(170.0, 260.0))
	if not F["rodeurs"].is_empty() and heure != "nuit":
		jeu._creer(F["rodeurs"][0], "rodeur", j.position + Vector2(-300, 120))
	if heure != "jour":
		for i in 2:
			jeu._creer(F["chasseurs_nuit"][i % F["chasseurs_nuit"].size()], "chasseur", j.position + Vector2.from_angle(i * PI + 1.0) * 300.0)
	# le plan de la veilleuse, en fractions de la durée
	_plan = [
		[0.0, 0.18, "attendre"],
		[0.18, 0.4, "tourner"],
		[0.4, 0.52, "couper"],
		[0.52, 0.62, "chasser"],
		[0.62, 0.7, "cueillir"],
		[0.7, 0.82, "torche"],
		[0.82, 1.0, "peur"],
	]
	if temps != "":
		_poser_le_temps()
	# (--sans son,ciel,sol,flammes : pour chercher ce qui coûte, on éteint une chose à la fois)
	var args := OS.get_cmdline_user_args()
	var i_sans := args.find("--sans")
	if i_sans >= 0 and i_sans + 1 < args.size():
		for quoi in args[i_sans + 1].split(","):
			var cibles: Array = []
			match quoi:
				"son":
					cibles = [jeu.sons]
				"ciel":
					cibles = [jeu.ciel]
				"sol":
					cibles = jeu.scene.get_children().filter(func(n): return n.get_script() == jeu.TempsSol)
				"flammes":
					cibles = jeu.scene.get_children().filter(func(n): return n.get_script() == jeu.IncendieFlammes)
				"effets":
					cibles = [jeu.effets]
			for n in cibles:
				n.process_mode = Node.PROCESS_MODE_DISABLED
				if n is CanvasItem:
					n.visible = false
			print("vitrine : sans ", quoi, " (", cibles.size(), ")")
	_pret = true


# le temps qu'on veut voir, tout de suite, et là où la veilleuse ira
func _poser_le_temps() -> void:
	var C = jeu.climat
	var j = jeu.joueur
	_plan = [[0.0, 0.12, "attendre"], [0.12, 0.4, "tourner"], [0.4, 1.0, "aller"]]
	_but = j.position + Vector2(240, 60)
	var arbre = _plus_proche(["arbre", "sapin"])
	match temps:
		"pluie":
			C.forcer("pluie", 1.0, 9999.0)
			C.boue = 1.0
			if arbre != null:
				_but = arbre.position + Vector2(5, 8)
		"orage":
			C.forcer("orage", 1.0, 9999.0)
			C.boue = 0.7
		"crue":
			C.forcer("pluie", 0.8, 9999.0)
			C.boue = 1.0
			C.crue = 1.0
			var d0 := INF
			for k in 1600:
				var q: Vector2 = j.position + Vector2(-1200.0 + 60.0 * (k % 40), -1200.0 + 60.0 * (k / 40))
				if C.eau(q) > 0.85 and q.distance_to(j.position) < d0 and jeu.monde.repousser(q, 8.0).distance_to(q) < 1.0:
					d0 = q.distance_to(j.position)
					_but = q
			# (on part du bord de l'eau, pour la voir y entrer)
			j.position = _but + (j.position - _but).normalized() * 230.0
			_plan = [[0.0, 0.1, "attendre"], [0.1, 1.0, "aller"]]
		"neige":
			C.forcer("neige", 1.0, 9999.0)
			C.neige_sol = 0.9
			j.temperature = 32.0
		"canicule":
			C.forcer("canicule", 1.0, 9999.0)
			j.temperature = 74.0
		"incendie":
			C.forcer("clair", 0.0, 9999.0)
			C.vent = 0.5
		_:
			C.forcer(temps, 1.0, 9999.0)
	if _regles.has("--force"):
		C.forcer(C.temps, float(_regles["--force"]), 9999.0)
	if _regles.has("--boue"):
		C.boue = float(_regles["--boue"])
	if _regles.has("--crue"):
		C.crue = float(_regles["--crue"])
	if _regles.has("--neige-sol"):
		C.neige_sol = float(_regles["--neige-sol"])
	if _regles.has("--vent"):
		C.vent = float(_regles["--vent"])


# ce qui arrive pendant la scène : la foudre tombe sur un arbre (puis tout près d'elle), le feu prend
func _le_temps_passe(u: float) -> void:
	var j = jeu.joueur
	if temps == "orage" and u > 0.22 and not _fait.has("foudre"):
		_fait["foudre"] = true
		var arbre = _un_arbre(90.0, 230.0)
		if arbre != null:
			jeu.climat.frapper(arbre.position, R.FOUDRE_ANNONCE, arbre)
			_but = arbre.position + Vector2(52.0 * (1.0 if j.position.x >= arbre.position.x else -1.0), 12.0)
	if temps == "orage" and u > 0.8 and not _fait.has("foudre2"):
		_fait["foudre2"] = true
		jeu.climat.frapper(j.position + Vector2(48, -10), R.FOUDRE_ANNONCE)
	if feu != "":
		_atelier_feu(u)
	elif temps == "incendie" and u > 0.08 and not _fait.has("feu"):
		_fait["feu"] = true
		var arbre2 = _un_arbre(80.0, 260.0)
		if arbre2 != null:
			jeu.incendie.enflammer(arbre2)
			for o in jeu.monde.autour(arbre2.position, 70.0):
				if o != arbre2 and _fait.size() < 4:
					jeu.incendie.enflammer(o)
			# (elle s'approche, puis finit contre les flammes : elle prend feu)
			_but = arbre2.position + Vector2(16.0 * (1.0 if j.position.x >= arbre2.position.x else -1.0), 6.0)
	if not moments.is_empty() and u >= float(moments[0]) and image != "":
		moments.pop_front()
		_fait["images"] = int(_fait.get("images", 0)) + 1
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [image, int(_fait["images"])])
		print("APPELS %s %d : %d (objets %d)" % [image.get_file(), int(_fait["images"]), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])


# (l'atelier « feu ») un grand feu (24 objets), ce qui reste, la pluie qui éteint
func _atelier_feu(u: float) -> void:
	var j = jeu.joueur
	var I = jeu.incendie
	if u > 0.03 and not _fait.has("place"):
		_fait["place"] = true
		# (là où le lieu est le plus touffu, pas trop loin)
		var centre: Vector2 = j.position + Vector2(150, -30)
		var mieux := 0
		for o in jeu.monde.autour(j.position, 1300.0):
			if o.combustible():
				var n: int = jeu.monde.autour(o.position, 190.0).filter(func(x): return x.combustible()).size()
				if n > mieux:
					mieux = n
					centre = o.position
		j.position = jeu.monde.repousser(centre + Vector2(-150, 70), 8.0)
		_fait["centre"] = centre
		_but = j.position
		_plan = [[0.0, 1.0, "aller"]]
	if u > (0.06 if feu == "long" else 0.3) and not _fait.has("feu") and feu != "rien":
		_fait["feu"] = true
		var centre: Vector2 = _fait["centre"]
		var proches: Array = jeu.monde.autour(centre, 330.0)
		proches.sort_custom(func(a, b): return centre.distance_squared_to(a.position) < centre.distance_squared_to(b.position))
		var genres := {}
		for o in proches:
			if not o.combustible() or o.position.distance_to(j.position) < 50.0:
				continue
			if feu == "brasier" or int(genres.get(o._espece, 0)) < 3:
				if I.enflammer(o):
					genres[o._espece] = int(genres.get(o._espece, 0)) + 1
					_brules.append(o)
		print("vitrine : ", I.foyers.size(), " foyers ", genres)
	if feu == "restes" and u > 0.5 and not _fait.has("vite"):
		# (tout finit de brûler d'un coup, ou presque)
		_fait["vite"] = true
		for f in I.foyers:
			f.objet.brule = minf(f.objet.brule, randf_range(0.3, 2.5))
	if feu == "pluie" and u > 0.55 and not _fait.has("pluie"):
		_fait["pluie"] = true
		jeu.climat.forcer("pluie", 1.0, 9999.0)
	if feu == "brasier":
		# (le feu ne meurt pas pendant qu'on compte)
		for f in I.foyers:
			f.objet.brule = maxf(f.objet.brule, 6.0)
	if appels:
		var n := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var quand := "avant" if (u > 0.14 and u < 0.3) else ("apres" if u > 0.5 else "")
		if quand != "":
			_fait[quand] = float(_fait.get(quand, 0.0)) + n
			_fait[quand + "_n"] = int(_fait.get(quand + "_n", 0)) + 1
			_fait[quand + "_max"] = maxi(int(_fait.get(quand + "_max", 0)), n)
			_fait["foyers_max"] = maxi(int(_fait.get("foyers_max", 0)), I.foyers.size())
		if u >= 1.0 and not _fait.has("dit"):
			_fait["dit"] = true
			print("vitrine : appels de dessin, avant le feu %d (au pire %d) ; avec %d foyers %d (au pire %d)" % [int(float(_fait.get("avant", 0.0)) / maxi(1, int(_fait.get("avant_n", 0)))),
				int(_fait.get("avant_max", 0)), int(_fait.get("foyers_max", 0)), int(float(_fait.get("apres", 0.0)) / maxi(1, int(_fait.get("apres_n", 0)))), int(_fait.get("apres_max", 0))])


# (--mesure) toutes les cinq secondes : les images par seconde, la plus longue image, le temps du jeu (les scripts), les appels
var _mesure_ms := 0
var _mesure_n := 0
var _mesure_max := 0
var _mesure_avant := 0

func _mesurer() -> void:
	if not OS.get_cmdline_user_args().has("--mesure"):
		return
	var ms := Time.get_ticks_msec()
	if _mesure_avant > 0:
		_mesure_max = maxi(_mesure_max, ms - _mesure_avant)
	_mesure_avant = ms
	_mesure_n += 1
	if _mesure_ms == 0:
		_mesure_ms = ms
	elif ms - _mesure_ms >= 5000:
		print("vitrine mesure : %.1f images/s, la plus longue %d ms, %d appels, jeu %.0f ms au pire (%s, à %d s)" % [_mesure_n * 1000.0 / (ms - _mesure_ms), _mesure_max,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, temps, int(_t)])
		_mesure_ms = ms
		_mesure_n = 0
		_mesure_max = 0


func _un_arbre(de: float, a: float):
	var j = jeu.joueur
	var meilleur = null
	var d0 := INF
	for o in jeu.monde.autour(j.position, a):
		var d: float = j.position.distance_to(o.position)
		if o.couvert() > 0.0 and d >= de and d < d0:
			d0 = d
			meilleur = o
	return meilleur


func _process(delta: float) -> void:
	if not _pret or not jeu.en_partie:
		return
	_t += delta
	var j = jeu.joueur
	j.sante = maxf(j.sante, 60.0)
	var u := _t / duree
	if nu and jeu.ui != null and jeu.ui.visible:
		jeu.ui.visible = false
	_le_temps_passe(u)
	_mesurer()
	if _regles.has("--corps"):
		j.temperature = float(_regles["--corps"])
	if u >= 1.0:
		_pret = false
		_quitter()
		return
	var geste := "attendre"
	for p in _plan:
		if u >= p[0] and u < p[1]:
			geste = p[2]
	var centre: Vector2 = jeu.feux[0].position if not jeu.feux.is_empty() else Vector2.ZERO
	match geste:
		"attendre":
			j.deplacer(Vector2.ZERO, delta, jeu.monde)
		"tourner":
			var d: Vector2 = j.position - centre
			if d.length() < 1.0:
				d = Vector2.RIGHT
			var vers := d.normalized().orthogonal() + d.normalized() * (110.0 - d.length()) / 60.0
			j.deplacer(vers.limit_length(1.0), delta, jeu.monde)
		"couper", "cueillir":
			var genres := ["arbre", "sapin"] if geste == "couper" else ["buisson", "touffe"]
			var o = _plus_proche(genres)
			if o != null:
				# (de côté, pour que le geste se lise)
				var d2: Vector2 = o.position + Vector2(18.0 * (1.0 if j.position.x >= o.position.x else -1.0), 10.0) - j.position
				if d2.length() > 24.0:
					j.deplacer(d2.normalized(), delta, jeu.monde)
				else:
					j.deplacer(Vector2.ZERO, delta, jeu.monde)
					_cadence(geste, delta)
		"chasser":
			if not _fait.has("proie"):
				_fait["proie"] = jeu._creer(jeu.faune["proies_jour"][0], "proie", j.position + Vector2(26, 0))
				_fait["proie"].flair = 0.0
			var b = _fait["proie"]
			if is_instance_valid(b) and b.is_in_group("betes"):
				b.position = j.position + Vector2(26.0 * j.regard, 0)
				_cadence("chasser", delta)
			j.deplacer(Vector2.ZERO, delta, jeu.monde)
		"aller":
			var da: Vector2 = _but - j.position
			j.deplacer(da.normalized() if da.length() > 6.0 else Vector2.ZERO, delta, jeu.monde)
		"torche":
			if not _fait.has("torche"):
				_fait["torche"] = true
				jeu.fabriquer("torche")
			j.deplacer(Vector2(-1, 0.3), delta, jeu.monde)
		"peur":
			j.peur = minf(100.0, j.peur + 40.0 * delta)
			if not _fait.has("morsure"):
				var c = _un_chasseur()
				if c != null:
					_fait["morsure"] = true
					jeu.mordre(c)
			j.deplacer(Vector2(0.6, -0.4), delta, jeu.monde)


func _cadence(_quoi: String, delta: float) -> void:
	_coup -= delta
	if _coup <= 0.0:
		_coup = R.CADENCE
		jeu.agir()


func _plus_proche(genres: Array):
	var j = jeu.joueur
	var meilleur = null
	var d0 := INF
	for o in jeu.monde.autour(j.position, 700.0):
		if genres.has(o.genre) and not o.epuise():
			var d: float = j.position.distance_to(o.position)
			if d < d0:
				d0 = d
				meilleur = o
	return meilleur


func _un_chasseur():
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role == "chasseur":
			return b
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role != "echo":
			return b
	return null


# (des sons qui jouent encore quand Godot s'arrête, il dit qu'ils fuient : on les tait, et on laisse au serveur audio le temps)
func _quitter() -> void:
	jeu.sons.taire()
	jeu.sons.arreter_brefs()
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0)
