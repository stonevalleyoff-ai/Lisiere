extends Control
# Lisière — la carte du monde, dans le carnet (scripts/interface_carte_monde.gd)
# Le monde ouvert (MONDE-OUVERT.md, étape 5) : à la pause, une page du carnet montre ce qu'on a découvert. Chaque région où l'on
# est entrée est peinte du ton de son biome, avec son nom ; celles qui la touchent sont esquissées (on sait qu'il y a quelque
# chose) ; le reste est du papier. Les crêtes qu'on ne passe pas, les rivières, les feux, les ponts, et où est la veilleuse.
# Un appui change d'échelle : les environs, ou tout ce qu'on connaît.

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")

var jeu
var loin := false
var _tons := {}
var _parois := {}             # par région connue : les points de ses parois (le relief), calculés une fois
var _bouches := {}            # par grotte connue : ses bouches


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(200, 160)
	mouse_filter = Control.MOUSE_FILTER_STOP


func ouvrir(j) -> void:
	if j != jeu:
		_parois.clear()
		_bouches.clear()
	jeu = j
	queue_redraw()


# le relief d'une région, pour la carte : là où l'étage change d'un point de la grille à son voisin passe une paroi (sauf à
# un col, qu'on laisse en blanc : on y passe)
func _relief_de(i: int) -> PackedVector2Array:
	var C = jeu.carte
	var reg: Dictionary = C.regions[i]
	var pts := PackedVector2Array()
	if reg["eau"]:
		return pts
	var contour: PackedVector2Array = C.contour(i)[0]
	var s: Vector2 = reg["pos"] - C.tordre(reg["pos"])
	if C.force(s) <= 0.0 and C.force(contour[0]) <= 0.0 and C.force(contour[contour.size() / 2]) <= 0.0:
		return pts
	var pas := 240.0
	var n := int(float(C.cote) * 1.3 / pas)
	var au_dessus := {}
	for iy in range(-n, n + 1):
		var a_gauche := -1
		for ix in range(-n, n + 1):
			var p := s + Vector2(ix, iy) * pas
			var e: int = C.palier(p) if Geometry2D.is_point_in_polygon(p, contour) else -1
			if e >= 0 and a_gauche >= 0 and e != a_gauche and C.champ_col(p - Vector2(pas * 0.5, 0.0)) <= C.COL:
				pts.append(p - Vector2(pas * 0.5, 0.0))
			var en_haut := int(au_dessus.get(ix, -1))
			if e >= 0 and en_haut >= 0 and e != en_haut and C.champ_col(p - Vector2(0.0, pas * 0.5)) <= C.COL:
				pts.append(p - Vector2(0.0, pas * 0.5))
			a_gauche = e
			au_dessus[ix] = e
	return pts


# les bouches d'une grotte, pour la carte : le long de ses frontières ouvertes, là où la muraille est percée de part en part
func _bouches_de(i: int) -> PackedVector2Array:
	var C = jeu.carte
	var reg: Dictionary = C.regions[i]
	var out := PackedVector2Array()
	if not reg["grotte"]:
		return out
	var s: Vector2 = reg["pos"] - C.tordre(reg["pos"])
	for bord in C.contour(i)[1]:
		var j: int = bord[0]
		if j < 0 or C.regions[j]["grotte"] or C.regions[j]["eau"] or C.ferme(i, j):
			continue
		var ligne: PackedVector2Array = bord[1]
		var somme := Vector2.ZERO
		var compte := 0
		for u in ligne.size() - 1:
			var a: Vector2 = ligne[u]
			var b: Vector2 = ligne[u + 1]
			var vers_dedans := (b - a).orthogonal().normalized()
			if vers_dedans.dot(s - a) < 0.0:
				vers_dedans = -vers_dedans
			var pas := maxi(1, int(a.distance_to(b) / 70.0))
			for t in pas:
				var q: Vector2 = a.lerp(b, float(t) / pas)
				var perce := true
				for d in [130.0, 250.0, 370.0, 480.0]:
					if C.plein(q + vers_dedans * d) > 0.0:
						perce = false
						break
				if perce:
					somme += q + vers_dedans * 200.0
					compte += 1
				elif compte > 0:
					out.append(somme / compte)
					somme = Vector2.ZERO
					compte = 0
		if compte > 0:
			out.append(somme / compte)
	return out


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		loin = not loin
		queue_redraw()
		accept_event()


# le ton d'un biome sur la carte : le sien (scripts/carte.gd), un peu lavé de papier
func _ton(type: String) -> Color:
	if not _tons.has(type):
		_tons[type] = Color(str(jeu.carte.TONS.get(type, "b9b29a"))).lerp(P.PAPIER, 0.22)
	return _tons[type]


func _draw() -> void:
	if jeu == null or jeu.get("carte") == null or jeu.joueur == null:
		return
	var C = jeu.carte
	var connues: Dictionary = jeu.decouvertes
	var ici: Vector2 = jeu.joueur.position
	# l'échelle : les environs (six régions de large), ou tout ce qu'on connaît
	var centre := ici
	var k: float = size.x / (float(C.cote) * 6.5)
	if loin and connues.size() > 1:
		var boite := Rect2(ici, Vector2.ZERO)
		for i in connues:
			boite = boite.expand(C.regions[i]["pos"])
		boite = boite.grow(float(C.cote) * 1.3)
		centre = boite.get_center()
		k = minf(k, minf(size.x / boite.size.x, size.y / boite.size.y))
	var vers := func(p: Vector2) -> Vector2: return (p - centre) * k + size * 0.5
	var vue: Rect2 = Rect2(centre - size * 0.5 / k, size / k).grow(float(C.cote) * 1.6)
	var encre := Color(P.ENCRE, 0.85)
	var police := T.titre_italique()
	var noms: Array = []
	var esquisses := {}
	# les régions connues : leur ton, leur contour ; l'eau en lavis bleu
	for i in connues:
		var reg: Dictionary = C.regions[i]
		for j in reg["voisines"]:
			if not connues.has(j):
				esquisses[j] = true
		if not vue.has_point(reg["pos"]):
			continue
		var co: Array = C.contour(i)
		var pts := PackedVector2Array()
		for p in co[0]:
			pts.append(vers.call(p))
		draw_colored_polygon(pts, _ton(str(reg["type"])))
		noms.append([vers.call(reg["pos"] - C.tordre(reg["pos"])), str(reg["nom"])])
	# ce qui les touche : de l'eau (on la voit de la rive), ou une terre qu'on devine
	for j in esquisses:
		var reg: Dictionary = C.regions[j]
		if not vue.has_point(reg["pos"]):
			continue
		var pts := PackedVector2Array()
		for p in C.contour(j)[0]:
			pts.append(vers.call(p))
		draw_colored_polygon(pts, Color(0.47, 0.6, 0.7, 0.5) if reg["eau"] else Color(P.ENCRE, 0.06))
		if not reg["eau"]:
			noms.append([vers.call(reg["pos"] - C.tordre(reg["pos"])), "?"])
	# les bords : un trait fin entre deux régions ; une rive à l'encre ; une crête, épaisse (on ne passe pas)
	for i in connues:
		var reg: Dictionary = C.regions[i]
		if not vue.has_point(reg["pos"]):
			continue
		for bord in C.contour(i)[1]:
			var j: int = bord[0]
			if j < 0:
				continue
			var ligne := PackedVector2Array()
			for p in bord[1]:
				ligne.append(vers.call(p))
			if C.ferme(i, j):
				draw_polyline(ligne, Color("3a2c20"), 4.0, true)
				draw_polyline(ligne, Color("b9a98a"), 1.2, true)
			elif bool(C.regions[j]["eau"]) != bool(reg["eau"]):
				draw_polyline(ligne, encre, 1.8, true)
			elif str(C.regions[j]["type"]) != str(reg["type"]):
				draw_polyline(ligne, Color(P.ENCRE, 0.5), 1.0, true)
			else:
				draw_polyline(ligne, Color(P.ENCRE, 0.16), 1.0, true)
		# une rivière : son lit, par petites touches
		if reg["riviere"]:
			var pas: float = maxf(260.0, 2.2 / k)
			var n := int(float(C.cote) * 1.3 / pas)
			for ix in range(-n, n + 1):
				for iy in range(-n, n + 1):
					var p: Vector2 = reg["pos"] + Vector2(ix, iy) * pas
					if absf(C.champ(p)) < C.LIT * 1.3 and C.region_en(p) == i and C.lit(p) > 0.0:
						draw_rect(Rect2(vers.call(p) - Vector2(1.3, 1.3), Vector2(2.6, 2.6)), Color(0.3, 0.45, 0.6, 0.85))
	# le relief : ses parois, en pointillé d'encre brune ; les bouches d'une grotte, un rond de papier cerclé d'encre.
	# (Calculés une région à la fois, une par image : la carte s'ouvre sans attendre, et se complète.)
	var a_faire := -1
	for i in connues:
		var reg: Dictionary = C.regions[i]
		if not _parois.has(i):
			if a_faire < 0:
				a_faire = i
			continue
		if not vue.has_point(reg["pos"]):
			continue
		for p in _parois[i]:
			draw_rect(Rect2(vers.call(p) - Vector2(0.9, 0.9), Vector2(1.8, 1.8)), Color("3a2c20", 0.62))
		for p in _bouches[i]:
			var q: Vector2 = vers.call(p)
			draw_circle(q, 3.6, encre)
			draw_circle(q, 2.3, P.PAPIER)
	if a_faire >= 0:
		_parois[a_faire] = _relief_de(a_faire)
		_bouches[a_faire] = _bouches_de(a_faire)
		queue_redraw.call_deferred()
	# les noms
	for e in noms:
		var t: String = e[1]
		var taille := 15 if t != "?" else 20
		var l := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		draw_string_outline(police, e[0] + Vector2(-l * 0.5, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color(P.PAPIER, 0.8))
		draw_string(police, e[0] + Vector2(-l * 0.5, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(P.ENCRE, 0.9 if t != "?" else 0.4))
	# les ponts, les feux, la veilleuse
	for pont in jeu.ponts:
		if is_instance_valid(pont):
			draw_line(vers.call(pont.a), vers.call(pont.b), Color("7a5c3c"), 2.5, true)
	for f in jeu.feux:
		if is_instance_valid(f):
			var q: Vector2 = vers.call(f.position)
			draw_circle(q, 4.2, encre)
			draw_circle(q, 3.0, P.BRAISE if f.allume() else P.CENDRE)
	var v: Vector2 = vers.call(ici)
	draw_circle(v, 6.5, Color(P.PAPIER, 0.9))
	draw_circle(v, 5.0, encre)
	draw_circle(v, 2.6, P.ECHARPE)
	draw_arc(v, 10.0 + 2.0 * sin(Time.get_ticks_msec() / 300.0), 0.0, TAU, 24, Color(P.SANG, 0.7), 1.4, true)
	# ce que dit un appui
	var aide := "tout ce que tu connais" if not loin else "les environs"
	var la := T.texte_moyen().get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(T.texte_moyen(), Vector2(size.x - la - 6.0, size.y - 6.0), aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(P.ENCRE, 0.5))
