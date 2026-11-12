extends Node
# Lisière — la vitrine du bestiaire (scripts/vitrine_betes.gd)
# Toutes les bêtes jouables d'un lieu, dans le vrai jeu (sa lumière, son sol, leur encre, leur marche), rangées de la plus légère
# à la plus lourde, par pages de vingt-quatre, autour de la veilleuse (pour l'échelle). Pour regarder le bestiaire, et le filmer.
# Rien n'est vérifié ici, rien n'est gardé ni envoyé.
#   outils/godot.sh --path . -- --betes [--lieu foret] [--heure jour|nuit] [--page 0] [--figees] [--decor]
#       [--image /tmp/betes]      une image par page (<image>_<lieu>_<heure>_<page>.png), puis s'arrête
#   outils/film.sh /tmp/film -- --betes --lieu foret --duree 8        filmée : les bêtes vont, broutent, guettent
# --figees : chaque bête reste à sa place, tournée vers la droite ; --decor : on garde les arbres et les rochers du lieu.

var jeu
var lieu := "foret"
var heure := "jour"
var page := -1
var figees := false
var decor := false
var image := ""
var duree := 8.0
var _places: Array = []       # [la bête, sa place]
var _t := 0.0
var _pret := false


func _ready() -> void:
	jeu = get_parent()
	var a := OS.get_cmdline_user_args()
	figees = "--figees" in a
	decor = "--decor" in a
	for i in a.size() - 1:
		match a[i]:
			"--lieu":
				lieu = a[i + 1]
			"--heure":
				heure = a[i + 1]
			"--page":
				page = int(a[i + 1])
			"--image":
				image = a[i + 1]
			"--duree":
				duree = float(a[i + 1])
	_lancer.call_deferred()


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie:
		return
	# (personne d'autre ne vient, la veilleuse tient, l'heure ne tourne pas)
	jeu._directeur = 999.0
	jeu.joueur.sante = 100.0
	jeu.joueur.faim = 100.0
	jeu.joueur.peur = 0.0
	jeu.horloge = _heure()
	for b in _places:
		if is_instance_valid(b[0]):
			b[0].maison = b[1]
			if figees:
				b[0].position = b[1]
	if _pret and image == "":
		_t += delta
		if _t >= duree:
			_pret = false
			get_tree().quit(0)


func _heure() -> float:
	return 60.0 if heure != "nuit" else 240.0 * (1.0 - jeu.part_nuit) + 30.0


func _lancer() -> void:
	jeu.donnees.hors_ligne_force = not ("--en-ligne" in OS.get_cmdline_user_args())
	await jeu.donnees.charger_index()
	await jeu._commencer(lieu)
	if not jeu.en_partie:
		print("la vitrine du bestiaire : le lieu « %s » ne se joue pas" % lieu)
		get_tree().quit(1)
		return
	jeu.horloge = _heure()
	jeu.ui._hud.visible = false
	if not decor:
		for o in jeu.monde.objets:
			o.visible = false
	# chaque lignée une fois, de la plus légère à la plus lourde
	var F: Dictionary = jeu.faune
	var toutes := {}
	for k in ["proies_jour", "proies_nuit", "rodeurs", "chasseurs_nuit"]:
		for e in F[k]:
			if not toutes.has(e["id"]):
				toutes[e["id"]] = e
	var liste: Array = toutes.values()
	liste.sort_custom(func(x, y): return float(x["masse"]) < float(y["masse"]))
	var colonnes := 6
	var rangs := 4
	var par_page := colonnes * rangs
	var pages := int(ceil(liste.size() / float(par_page)))
	var a_montrer := range(pages) if page < 0 else [clampi(page, 0, pages - 1)]
	var noms := CanvasLayer.new()
	noms.layer = 30
	jeu.add_child(noms)
	for pg in a_montrer:
		for b in get_tree().get_nodes_in_group("betes"):
			b.queue_free()
		for c in noms.get_children():
			c.queue_free()
		_places.clear()
		await get_tree().process_frame
		var vp: Vector2 = jeu.get_viewport().get_visible_rect().size
		var vu: Vector2 = vp / jeu.camera.zoom
		for i in par_page:
			var k: int = int(pg) * par_page + i
			if k >= liste.size():
				break
			var e: Dictionary = liste[k]
			var cx := (float(i % colonnes) + 0.5) / colonnes
			var cy := (float(i / colonnes) + 0.6) / rangs
			var p: Vector2 = jeu.joueur.position + Vector2((cx - 0.5) * vu.x, (cy - 0.5) * vu.y)
			var b = jeu._creer(e, "proie", p)
			b.flair = 0.0
			if figees:
				b.vitesse = 0.0
				b.regard = 1.0
			_places.append([b, p])
			var plan: Dictionary = e["lignee"].get("plan", {})
			var l := Label.new()
			l.text = "%s · %s kg · %s%s" % [e["nom"], str(snappedf(float(e["masse"]), 0.1)), str(plan.get("corps", {}).get("forme", "?")),
				" · chasseur" if str(plan.get("regime", "")) == "carnivore" else ""]
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			l.add_theme_constant_override("outline_size", 4)
			l.position = Vector2(cx * vp.x - 70.0, cy * vp.y + 14.0)
			noms.add_child(l)
		if image != "":
			await get_tree().create_timer(2.5).timeout
			get_viewport().get_texture().get_image().save_png("%s_%s_%s_%d.png" % [image, lieu, heure, pg])
			# (ce que coûte la page : les appels de dessin de l'image, bêtes, sol et veilleuse compris)
			print("la vitrine du bestiaire : page %d, %d bêtes, %d appels de dessin" % [pg, _places.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		elif a_montrer.size() > 1:
			await get_tree().create_timer(duree).timeout
	print("la vitrine du bestiaire : %d lignées, %d page%s" % [liste.size(), pages, "s" if pages > 1 else ""])
	if image != "" or a_montrer.size() > 1:
		get_tree().quit(0)
	else:
		_pret = true
