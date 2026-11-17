extends Control
# Lisière — la carte, dans le carnet (scripts/interface_carte_monde.gd)
# À la pause, une page du carnet montre ce qu'on a parcouru, si l'on a fabriqué sa carte (scripts/reperes.gd).
# Le monde ouvert (MONDE-OUVERT.md, étape 5) : chaque région où l'on est entrée est peinte du ton de son biome, avec son nom ;
# celles qui la touchent sont esquissées (on sait qu'il y a quelque chose) ; le reste est du papier. Les crêtes qu'on ne passe
# pas, les rivières, les feux, les ponts, et où est la veilleuse.
# Un lieu : les cases où elle est passée, du ton du lieu, ses arbres et ses rochers à l'encre, l'eau en lavis ; le bord du
# lieu ; les feux, et où est la veilleuse.
# Et, dans les deux, ce qu'elle y a écrit à la plume : ses repères, leur signe et leur nom ; hors de la vue, au bord, du côté
# où ils sont ; deux noms ne se couvrent pas (le plus proche d'elle garde le sien). Un appui change d'échelle : les environs,
# tout ce qu'on connaît, et (le monde ouvert) tout près, où l'on lit ses repères.

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")
const Reperes := preload("res://scripts/reperes.gd")
const Carte := preload("res://scripts/carte.gd")
const R := preload("res://scripts/regles.gd")

var jeu
var loin := false
var pres := false             # (le monde ouvert) tout près : deux mille pixels de large, comme un lieu
var _tons := {}
var _parois := {}             # par région connue : les points de ses parois (le relief), calculés une fois
var _bouches := {}            # par grotte connue : ses bouches
var _objets: Array = []       # un lieu : ses arbres et ses rochers, [position, genre, rayon], relus à chaque ouverture


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(200, 160)
	mouse_filter = Control.MOUSE_FILTER_STOP


func ouvrir(j) -> void:
	if j != jeu:
		_parois.clear()
		_bouches.clear()
	jeu = j
	_objets.clear()
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
		# (le monde ouvert : les environs, tout, tout près ; un lieu : les environs, tout)
		if jeu != null and jeu.get("carte") != null:
			var avant_loin := loin
			loin = not loin and not pres
			pres = avant_loin
		else:
			loin = not loin
			pres = false
		queue_redraw()
		accept_event()


# le ton d'un biome sur la carte : le sien (scripts/carte.gd), un peu lavé de papier
func _ton(type: String) -> Color:
	if not _tons.has(type):
		_tons[type] = Color(str(jeu.carte.TONS.get(type, "b9b29a"))).lerp(P.PAPIER, 0.22)
	return _tons[type]


func _draw() -> void:
	if jeu == null or jeu.joueur == null:
		return
	if jeu.get("carte") == null:
		_draw_lieu()
		return
	var C = jeu.carte
	var connues: Dictionary = jeu.decouvertes
	var ici: Vector2 = jeu.joueur.position
	# l'échelle : les environs (six régions de large), ou tout ce qu'on connaît
	var centre := ici
	var k: float = size.x / (float(C.cote) * 6.5)
	if pres:
		k = size.x / 2000.0
	elif loin and connues.size() > 1:
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
	# ce qu'elle y a écrit (la tanière de la Noire aussi, si elle l'a écrite : scripts/reperes.gd), puis elle
	_reperes(vers)
	_veilleuse(vers.call(ici))
	_aide()


# ce qu'elle a écrit à la plume : un signe, son nom dessous ; hors de la vue, au bord, plus petit, du côté où il est
func _reperes(vers: Callable) -> void:
	if jeu.get("reperes") == null:
		return
	var police := T.titre_italique()
	var bord := Rect2(Vector2(12.0, 12.0), size - Vector2(24.0, 24.0))
	var noms: Array = []
	var pris: Array = []          # (ce que les noms ne couvrent pas : les signes, puis les noms déjà écrits)
	# (les plus loin d'abord : le plus proche d'elle se dessine par-dessus, et garde son nom)
	var rangs: Array = jeu.reperes.par_distance()
	rangs.reverse()
	for i in rangs:
		var r: Dictionary = jeu.reperes.liste[i]
		var q: Vector2 = vers.call(Reperes.position(r))
		var dedans := bord.has_point(q)
		if not dedans:
			q = Vector2(clampf(q.x, bord.position.x, bord.end.x), clampf(q.y, bord.position.y, bord.end.y))
		var t := 22.0 if dedans else 14.0
		draw_circle(q, t * 0.55, Color(P.PAPIER, 0.85 if dedans else 0.6))
		Reperes.signe(self, str(r["genre"]), q, t, not dedans)
		if dedans:
			pris.append(Rect2(q - Vector2(t, t) * 0.45, Vector2(t, t) * 0.9))
			var nom := str(Reperes.GENRES.get(str(r["genre"]), {}).get("nom", ""))
			var l := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			noms.push_front([Rect2(q + Vector2(-l * 0.5, t * 0.5 + 1.0), Vector2(l, 14.0)), nom])
	# leurs noms : du plus proche d'elle au plus loin ; un nom qui en couvrirait un autre, ou un signe, se tait
	for e in noms:
		var rr: Rect2 = e[0]
		var libre := true
		for autre in pris:
			if rr.grow(2.0).intersects(autre):
				libre = false
				break
		if not libre:
			continue
		pris.append(rr)
		var o := rr.position + Vector2(0.0, 11.0)
		draw_string_outline(police, o, str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(P.PAPIER, 0.85))
		draw_string(police, o, str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(P.ENCRE, 0.9))


# où est la veilleuse : un rond d'encre, son écharpe, un cercle qui bat
func _veilleuse(v: Vector2) -> void:
	draw_circle(v, 6.5, Color(P.PAPIER, 0.9))
	draw_circle(v, 5.0, Color(P.ENCRE, 0.85))
	draw_circle(v, 2.6, P.ECHARPE)
	draw_arc(v, 10.0 + 2.0 * sin(Time.get_ticks_msec() / 300.0), 0.0, TAU, 24, Color(P.SANG, 0.7), 1.4, true)


# ce que dit un appui
func _aide() -> void:
	var ouvert: bool = jeu.get("carte") != null
	var aide := "tout ce que tu connais" if not loin and not pres else ("tout près" if loin and ouvert else "les environs")
	var la := T.texte_moyen().get_string_size(aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(T.texte_moyen(), Vector2(size.x - la - 6.0, size.y - 6.0), aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(P.ENCRE, 0.5))


# --- un lieu : ses cases parcourues, ses arbres, ses rochers, son eau, son bord ---

func _draw_lieu() -> void:
	var vus: Dictionary = jeu.reperes.vus if jeu.get("reperes") != null else {}
	var ici: Vector2 = jeu.joueur.position
	var cote := Reperes.CASE
	# l'échelle : les environs (deux mille pixels de large), ou tout ce qu'elle a parcouru
	var centre := ici
	var k: float = size.x / 2000.0
	if loin and vus.size() > 1:
		var boite := Rect2(ici, Vector2.ZERO)
		for c in vus:
			boite = boite.expand(Vector2(c) * cote).expand((Vector2(c) + Vector2.ONE) * cote)
		boite = boite.grow(cote)
		centre = boite.get_center()
		k = minf(k, minf(size.x / boite.size.x, size.y / boite.size.y))
	var vers := func(p: Vector2) -> Vector2: return (p - centre) * k + size * 0.5
	var vue: Rect2 = Rect2(centre - size * 0.5 / k, size / k).grow(cote)
	var ton := Color(str(Carte.TONS.get(str(jeu.biome), "b9b29a"))).lerp(P.PAPIER, 0.3)
	# les cases parcourues : le ton du lieu ; l'eau, en lavis bleu
	for c in vus:
		var o: Vector2 = Vector2(c) * cote
		if not vue.has_point(o):
			continue
		var r := Rect2(vers.call(o), Vector2(cote, cote) * k).grow(0.6)
		draw_rect(r, ton)
		if jeu.get("climat") != null and float(jeu.climat.eau(o + Vector2(cote, cote) * 0.5)) > 0.2:
			draw_rect(r, Color(0.47, 0.6, 0.7, 0.55))
	# ses arbres et ses rochers, là où elle est passée
	if _objets.is_empty() and jeu.get("monde") != null:
		for o in jeu.monde.objets:
			if is_instance_valid(o) and str(o.genre) in ["arbre", "sapin", "rocher"]:
				_objets.append([o.position, str(o.genre), float(o.rayon)])
	var encre := Color(P.ENCRE, 0.85)
	for e in _objets:
		var p: Vector2 = e[0]
		if not vue.has_point(p) or not vus.has(Reperes.cle(p)):
			continue
		var q: Vector2 = vers.call(p)
		var r: float = clampf(float(e[2]) * k * 0.7, 1.6, 5.0)
		match str(e[1]):
			"rocher":
				draw_circle(q, r, Color("3a2c20", 0.75))
				draw_circle(q + Vector2(-0.3, -0.3) * r, r * 0.6, Color("9d968a"))
			"sapin":
				var pts := PackedVector2Array([q + Vector2(0, -r * 1.6), q + Vector2(r, r * 0.8), q + Vector2(-r, r * 0.8)])
				draw_colored_polygon(pts, Color("3f5a3a"))
			_:
				draw_circle(q, r + 0.8, Color(encre, 0.55))
				draw_circle(q, r, Color("4c6a3a"))
	# le bord du lieu, là où elle l'a vu
	var lim := Rect2(Vector2(-R.DEMI, -R.DEMI), Vector2(R.DEMI, R.DEMI) * 2.0)
	var coins := [lim.position, Vector2(lim.end.x, lim.position.y), lim.end, Vector2(lim.position.x, lim.end.y)]
	for i in 4:
		var a: Vector2 = coins[i]
		var b: Vector2 = coins[(i + 1) % 4]
		var pas := int(a.distance_to(b) / cote)
		for u in pas:
			var m: Vector2 = a.lerp(b, (u + 0.5) / pas)
			if vus.has(Reperes.cle(m - (m - lim.get_center()).normalized() * 4.0)):
				draw_line(vers.call(a.lerp(b, float(u) / pas)), vers.call(a.lerp(b, float(u + 1) / pas)), encre, 2.0, true)
	# les feux
	for f in jeu.feux:
		if is_instance_valid(f):
			var q: Vector2 = vers.call(f.position)
			draw_circle(q, 4.2, encre)
			draw_circle(q, 3.0, P.BRAISE if f.allume() else P.CENDRE)
	# le nom du lieu
	var nom := str(jeu.biome_info.get("nom", "")) if typeof(jeu.get("biome_info")) == TYPE_DICTIONARY else ""
	if nom != "":
		draw_string(T.titre_italique(), Vector2(8.0, 20.0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(P.ENCRE, 0.75))
	_reperes(vers)
	_veilleuse(vers.call(ici))
	_aide()
