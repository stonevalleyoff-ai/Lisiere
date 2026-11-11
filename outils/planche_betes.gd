extends SceneTree
# Lisière — LA PLANCHE DES BÊTES (outils/planche_betes.gd) : le bestiaire de Lisière, vu d'un coup, sans écran
# Dessine chaque bête jouable d'un lieu gardé (donnees/biomes/<lieu>.json), au repos, à la taille du jeu, sur les tons du sol,
# rangées de la plus légère à la plus lourde, avec la veilleuse pour l'échelle (22 × 44). Deux images : l'une comme on la voit
# en jouant (la caméra grossit 1,35 fois), l'autre agrandie pour regarder le trait. Et la liste, dans l'ordre, à l'écran.
#   outils/godot.sh --headless --path . -s outils/planche_betes.gd -- [--lieu foret] [--forme hexapode] [--id tiskata,dunvi]
#       [--sortie /tmp/planche] [--colonnes 6] [--agrandi 3]
# Écrit <sortie>_jeu.png et <sortie>_agrandi.png.

const Bestiaire := preload("res://scripts/bestiaire.gd")
const TERRE := ["marche", "course", "saut", "fouissage", "grimpe", "reptation"]
const SOLS := [Color("6f5b46"), Color("4f6238"), Color("5a4937"), Color("3f4f30")]
const NUIT := Color("141a2a")


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	for i in a.size() - 1:
		if a[i] == nom:
			return a[i + 1]
	return defaut


func _init() -> void:
	var lieux := _arg("--lieu", "foret").split(",")
	var forme := _arg("--forme", "")
	var ids := _arg("--id", "")
	var sortie := _arg("--sortie", "/tmp/planche")
	var colonnes := int(_arg("--colonnes", "6"))
	var agrandi := float(_arg("--agrandi", "3"))
	var vus := {}
	var betes := []
	for lieu in lieux:
		var chemin := "res://donnees/biomes/%s.json" % lieu
		if not FileAccess.file_exists(chemin):
			print("pas de lieu gardé : ", lieu)
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		for t in d.get("taxons", []):
			var p = t.get("plan", {})
			if typeof(t.get("eteint")) != TYPE_NIL or typeof(p) != TYPE_DICTIONARY or vus.has(t.get("id")):
				continue
			if str(p.get("regime", "")) in ["vegetal", "synthetique"] or str(p.get("famille", "animale")) == "vegetale" or float(p.get("masse_kg", 0.0)) < 0.2:
				continue
			if not p.get("locomotion", []).any(func(l): return TERRE.has(l)):
				continue
			var c: Dictionary = p.get("corps", {})
			if forme != "" and str(c.get("forme", "")) != forme:
				continue
			if ids != "" and not ids.split(",").has(str(t.get("id", ""))):
				continue
			vus[t.get("id")] = true
			betes.append(t)
	betes.sort_custom(func(a, b): return float(a["plan"]["masse_kg"]) < float(b["plan"]["masse_kg"]))
	if betes.is_empty():
		print("aucune bête")
		quit(1)
		return
	var portraits := []
	var cw := 60.0
	var ch := 50.0
	var debut := Time.get_ticks_msec()
	for t in betes:
		var plan: Dictionary = t["plan"]
		var chasse: bool = Bestiaire.est_chasseur(plan)
		var largeur: float = Bestiaire.largeur_de(float(plan["masse_kg"]), chasse)
		var po: Dictionary = Bestiaire.portrait(t, largeur)
		portraits.append([po, largeur])
		if not po.is_empty():
			cw = maxf(cw, po["taille"].x + 16.0)
			ch = maxf(ch, -po["pos"].y + 14.0)
	print("%d bêtes dessinées en %d ms" % [betes.size(), Time.get_ticks_msec() - debut])
	ch += 10.0
	var rangs := int(ceil(betes.size() / float(colonnes)))
	# (la planche, à deux pixels par pixel montré, comme les images des bêtes)
	var k := 2.0
	var marge := 36.0
	var img := Image.create(int((marge + colonnes * cw) * k), int(rangs * ch * k), false, Image.FORMAT_RGBA8)
	for i in betes.size():
		var col := i % colonnes
		var rg := i / colonnes
		var fond: Color = SOLS[(col + rg) % SOLS.size()] if rg % 4 != 3 else NUIT.lerp(SOLS[col % SOLS.size()], 0.25)
		img.fill_rect(Rect2i(int((marge + col * cw) * k), int(rg * ch * k), int(cw * k), int(ch * k)), fond)
		if col == 0:
			# (la veilleuse, pour l'échelle)
			img.fill_rect(Rect2i(0, int(rg * ch * k), int(marge * k), int(ch * k)), fond.darkened(0.25))
			img.fill_rect(Rect2i(int((marge * 0.5 - 11.0) * k), int(((rg + 1) * ch - 8.0 - 44.0) * k), int(22.0 * k), int(44.0 * k)), Color("2b3350"))
		var po: Dictionary = portraits[i][0]
		var t: Dictionary = betes[i]
		var plan: Dictionary = t["plan"]
		var c: Dictionary = plan.get("corps", {})
		print("%2d.%d  %-10s %6.2f kg  %-10s larg %3d  %s%s  %s" % [rg + 1, col + 1, str(t["id"]), float(plan["masse_kg"]), str(c.get("forme", "?")), int(portraits[i][1]),
			str(plan.get("regime", "")), " (chasseur)" if Bestiaire.est_chasseur(plan) else "", str(c.get("motif", ""))])
		if po.is_empty():
			continue
		var sol := Vector2(marge + (col + 0.5) * cw, (rg + 1) * ch - 8.0)
		var image: Image = po["image"]
		img.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(((sol + po["pos"]) * k).round()))
	var jeu := img.duplicate()
	jeu.resize(int(img.get_width() * 1.35 / k), int(img.get_height() * 1.35 / k), Image.INTERPOLATE_LANCZOS)
	jeu.save_png(sortie + "_jeu.png")
	var grand := img.duplicate()
	grand.resize(int(img.get_width() * agrandi / k), int(img.get_height() * agrandi / k), Image.INTERPOLATE_LANCZOS)
	grand.save_png(sortie + "_agrandi.png")
	print("écrit : %s_jeu.png (%d × %d), %s_agrandi.png" % [sortie, jeu.get_width(), jeu.get_height(), sortie])
	quit(0)
