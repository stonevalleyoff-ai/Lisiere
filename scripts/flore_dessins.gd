extends RefCounted
# Lisière — la flore dessinée à l'encre (scripts/flore_dessins.gd)
# Chaque forme de l'herbier d'Orvane (scripts/flore.gd), dessinée par Lisière comme elle dessine ses bêtes : Orvane dit ce
# qu'est la plante (sa forme, sa hauteur, son stade, sa couleur), Lisière la dessine dans son carnet, au pinceau de
# l'environnement (scripts/decor_pinceau.gd), un contour d'encre, trois tons, la lumière en haut à gauche. On la reconnaît à sa
# silhouette, d'un coup d'œil, à la taille du jeu : le bouleau pâle et ses taches, le palmier sur son fût annelé, la fougère
# arborescente et ses crosses, le palétuvier sur ses échasses, le cactus en candélabre, l'agave et ses dards, les lichens à plat,
# les nénuphars sur leur mare… Et les plantes de Lisière : les fleurs des prés, le cèpe et l'amanite (rouge, piquée de blanc).
# objet.gd demande ici : regler (ce que la forme change à sa conduite : une part, un tronc plus fin, un rayon où l'on bute),
# mesurer (sa taille), pied et couronne (un arbre), dessiner (le reste), ombres. Rien n'est refait à chaque image : un objet se
# dessine une fois, et quand il change (cueilli, qui repousse).

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
const R_BAIES := preload("res://scripts/regles.gd").BAIES_PAR_BUISSON

# les formes que Lisière dessine elle-même (une forme qui n'y est pas se dessine comme celles de son port, ou par la planche)
const DESSINEES := ["arbre", "pionnier", "fruitier", "geant", "emergent", "figuier", "bouteille", "sous_bois", "palmier", "paletuvier",
	"fougere_arbre", "conifere", "buisson", "baies", "epine", "ronce", "aromatique", "bruyere", "liane", "herbe", "cereale", "grande_herbe",
	"legumineuse", "fougere", "coussin", "mousse", "lichen", "lichen_rennes", "lichen_croute", "succulente", "agave", "cactus", "caillou",
	"roseau", "jonc", "riz", "papyrus", "bambou", "fleur", "bulbe", "orchidee", "bromelia", "algue", "lentille", "nenuphar",
	"champignon", "champignon_lumineux", "champignon_geant", "moisissure", "cepe", "amanite"]


static func sait(forme: String) -> bool:
	return DESSINEES.has(forme)


# --- ce que la forme change à l'objet : ses parts, son tronc, ce où l'on bute ---

static func regler(o) -> void:
	match str(o.forme):
		"pionnier":
			o.epaisseur = 0.72
			# (un bouleau : l'écorce blanche)
			o.ecorce_teinte = P.PAPIER.lerp(P.IVOIRE, 0.45).darkened(0.04)
		"geant", "emergent":
			o.epaisseur = 1.35
		"figuier":
			o.epaisseur = 1.15
			o.ecorce_teinte = P.CENDRE.lerp(P.IVOIRE, 0.42)
		"bouteille":
			o.epaisseur = 2.2
			o.ecorce_teinte = P.CENDRE.lerp(P.IVOIRE, 0.38).lerp(P.TERRE, 0.2)
			o.rayon = 15.0
		"sous_bois":
			o.epaisseur = 0.8
		"palmier":
			o.epaisseur = 0.68
			o.ecorce_teinte = P.TERRE.lerp(P.IVOIRE, 0.32)
		"fougere_arbre":
			o.epaisseur = 0.74
			o.ecorce_teinte = P.ENCRE_DOUCE.lerp(P.TERRE, 0.45)
		"paletuvier":
			o.epaisseur = 0.85
			o.ecorce_teinte = P.TERRE.lerp(P.CENDRE, 0.4)
		"cactus":
			o.plein = 2
			o.rayon = 7.0
		"agave":
			o.rayon = 5.0
		"bambou":
			o.plein = 2
			o.rayon = 5.0
		"grande_herbe":
			o.haut_touffe = 1.6
		"lentille", "mousse", "lichen", "lichen_croute", "caillou":
			# (un tapis au ras du sol, une nappe sur l'eau : rien à cueillir)
			o.plein = 0
	if str(o.genre) == "fleur":
		# (une fleur qui n'est pas en fleurs n'a rien à donner)
		o.plein = 1 if o.en_fleurs else 0


# --- la taille, d'après la forme (après la mesure commune de son genre) ---

static func mesurer(o, r: RandomNumberGenerator) -> void:
	var f := str(o.forme)
	match str(o.genre):
		"arbre":
			_mesurer_arbre(o, r, f)
		"touffe":
			match f:
				"cactus":
					o._ry = r.randf_range(46.0, 58.0)
					o._rx = r.randf_range(6.5, 8.0)
					o.hauteur = o._ry
				"agave":
					o._rx = r.randf_range(16.0, 20.0)
					o._ry = r.randf_range(15.0, 19.0)
					o.hauteur = o._ry
				"bambou":
					o._ry = r.randf_range(56.0, 74.0)
					o.hauteur = o._ry
				"papyrus":
					o._ry = r.randf_range(32.0, 40.0)
					o.hauteur = o._ry
				"cereale", "riz":
					o._ry = r.randf_range(19.0, 25.0)
					o.hauteur = o._ry
				"jonc":
					o._ry = r.randf_range(19.0, 25.0)
					o.hauteur = o._ry
				"fougere":
					o._ry = r.randf_range(19.0, 24.0)
					o.hauteur = o._ry
				"coussin", "lichen_rennes", "succulente", "legumineuse":
					o._rx = r.randf_range(8.0, 11.5)
					o._ry = r.randf_range(6.0, 9.0)
					o.hauteur = o._ry
				"mousse", "lichen", "lichen_croute", "caillou":
					o._rx = r.randf_range(8.0, 13.0)
					o._ry = o._rx * r.randf_range(0.42, 0.55)
					o.hauteur = 2.0
		"buisson":
			match f:
				"bruyere", "aromatique":
					o._rx = r.randf_range(11.0, 14.0)
					o._ry = r.randf_range(9.0, 12.0)
					o.hauteur = o._ry
				"ronce":
					o._rx = r.randf_range(15.0, 19.0)
					o._ry = r.randf_range(15.0, 19.0)
					o.hauteur = o._ry
				"liane":
					o._ry = r.randf_range(26.0, 32.0)
					o.hauteur = o._ry
		"fleur":
			o._rx = r.randf_range(13.0, 19.0)
			o._ry = o._rx * r.randf_range(0.42, 0.55)
			o.hauteur = r.randf_range(9.0, 14.0)
		"aquatique":
			o._rx = r.randf_range(15.0, 22.0)
			o._ry = o._rx * r.randf_range(0.4, 0.48)
			o.hauteur = 1.0
		"cepe", "amanite":
			o._rx = r.randf_range(4.0, 6.0)
			o._ry = r.randf_range(6.0, 9.0)
			o.hauteur = o._ry


static func _mesurer_arbre(o, r: RandomNumberGenerator, f: String) -> void:
	var ht := 0.0
	var rx := 0.0
	var ry := 0.0
	match f:
		"pionnier":
			ht = r.randf_range(30.0, 38.0)
			rx = r.randf_range(17.0, 21.0)
			ry = rx * r.randf_range(1.05, 1.2)
		"fruitier":
			ht = r.randf_range(16.0, 21.0)
			rx = r.randf_range(22.0, 27.0)
			ry = rx * r.randf_range(0.82, 0.9)
		"geant":
			ht = r.randf_range(30.0, 36.0)
			rx = r.randf_range(33.0, 38.0)
			ry = rx * r.randf_range(0.78, 0.86)
		"emergent":
			ht = r.randf_range(56.0, 66.0)
			rx = r.randf_range(34.0, 40.0)
			ry = rx * r.randf_range(0.38, 0.46)
		"figuier":
			ht = r.randf_range(20.0, 25.0)
			rx = r.randf_range(34.0, 40.0)
			ry = rx * r.randf_range(0.62, 0.7)
		"sous_bois":
			ht = r.randf_range(13.0, 17.0)
			rx = r.randf_range(16.0, 20.0)
			ry = rx * r.randf_range(0.85, 0.95)
		"bouteille":
			ht = r.randf_range(30.0, 36.0)
			rx = r.randf_range(27.0, 32.0)
			ry = rx * r.randf_range(0.42, 0.5)
		"paletuvier":
			ht = r.randf_range(22.0, 27.0)
			rx = r.randf_range(26.0, 31.0)
			ry = rx * r.randf_range(0.68, 0.76)
		"palmier", "fougere_arbre":
			# (un fût, et les palmes en haut : le centre du feuillage est au sommet du fût)
			var palmier := f == "palmier"
			ht = r.randf_range(54.0, 66.0) if palmier else r.randf_range(34.0, 42.0)
			rx = r.randf_range(36.0, 42.0) if palmier else r.randf_range(29.0, 34.0)
			ry = r.randf_range(15.0, 18.0) if palmier else r.randf_range(13.0, 16.0)
			o._ht = ht
			o._rx = rx
			o._ry = ry
			o._penche = r.randf_range(0.1, 0.2) * (1.0 if o.graine % 2 == 0 else -1.0)
			o._cc = Vector2(_courbe_palme(o, -ht), -ht)
			o.hauteur = ht + ry
			o.couronne_rect = Rect2(o._cc - Vector2(rx, ry * 0.9), Vector2(rx * 2.0, ry * 2.1))
			return
		_:
			return
	o._ht = ht
	o._rx = rx
	o._ry = ry
	o._penche = r.randf_range(-0.06, 0.06)
	o._cc = Vector2(o._penche * (ht + ry * 0.8) + r.randf_range(-2.0, 2.0), -(ht + ry * 0.8))
	o.hauteur = -o._cc.y + ry
	o.couronne_rect = Rect2(o._cc - Vector2(rx, ry), Vector2(rx, ry) * 2.0)


# l'axe d'un fût de palmier, qui se courbe vers le haut (à la hauteur y, négative)
static func _courbe_palme(o, y: float) -> float:
	var u := clampf((-y - 8.5) / maxf(1.0, o._ht - 8.5), 0.0, 1.0)
	return o._axe(-8.5) + o._penche * 70.0 * u * u


# --- les ombres d'une forme à elle ([] : aucune ; null : celles de son genre) ---

static func ombres(o):
	var f := str(o.forme)
	match str(o.genre):
		"fleur":
			return [[Vector2(0, 1), Vector2(o._rx * 0.8, 3.0), 0.18, 0.0, 0.0]]
		"aquatique":
			return []
		"cepe", "amanite":
			return [[Vector2(0.5, 1), Vector2(6.0, 2.2), 0.4, 0.0, 0.0]]
		"touffe":
			match f:
				"cactus":
					return [[Vector2(1, 1), Vector2(9.0, 3.5), 0.45, 0.0, 0.0], [Vector2(2, 2), Vector2(o._rx * 1.4, o._rx * 0.6), 0.25, 1.0, o.hauteur * 0.8]]
				"bambou", "papyrus":
					return [[Vector2(0, 1), Vector2(10.0, 3.5), 0.35, 0.0, 0.0], [Vector2(2, 2), Vector2(9.0, 4.0), 0.2, 1.0, o.hauteur * 0.6]]
				"agave", "coussin", "succulente", "lichen_rennes":
					return [[Vector2(0.5, 1), Vector2(o._rx * 1.05, o._rx * 0.32), 0.32, 0.0, 0.0]]
				"mousse", "lichen", "lichen_croute", "caillou":
					return []
	return null


# --- les arbres : leur pied ---

static func pied(o, p, r: RandomNumberGenerator) -> bool:
	match str(o.forme):
		"paletuvier":
			_pied_paletuvier(o, p, r)
			return true
	return false


# le palétuvier : ses racines en échasses, arquées, qui le tiennent au-dessus de la vase
static func _pied_paletuvier(o, p, r: RandomNumberGenerator) -> void:
	var c: Color = o._ecorce()
	p.eventail(Vector2(0, 1.5), 20.0, 5.0, Color(P.ENCRE_DOUCE.lerp(P.TERRE, 0.4), 0.55), Color(P.ENCRE_DOUCE, 0.0), 14)
	var n := r.randi_range(5, 7)
	var racines := []
	for i in n:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var depart := Vector2(o._axe(-9.0) + cote * r.randf_range(0.5, 2.5), -r.randf_range(7.0, 12.0))
		var bout := Vector2(cote * r.randf_range(7.0, 19.0), r.randf_range(-0.5, 2.5))
		var haut := depart + Vector2(cote * r.randf_range(3.0, 7.0), -r.randf_range(3.0, 6.0))
		racines.append([depart, haut, bout, r.randf()])
	racines.sort_custom(func(a, b): return a[3] < b[3])
	for x in racines:
		var ligne := PackedVector2Array()
		for k in 7:
			var t := k / 6.0
			ligne.append(x[0].lerp(x[1], t).lerp(x[1].lerp(x[2], t), t))
		p.tracer(ligne, 2.9, ENCRE, false, PackedFloat32Array([3.0, 3.0, 2.8, 2.6, 2.4, 2.2, 2.0]))
		p.tracer(ligne, 1.7, c.lightened(0.05 + 0.1 * x[3]), false, PackedFloat32Array([1.8, 1.8, 1.6, 1.5, 1.4, 1.2, 1.0]))
	o._tronc(p, -6.0, -9.0, c)


# --- les arbres : leur haut (la couronne, sur son propre nœud) ---

static func couronne(o, p, r: RandomNumberGenerator) -> bool:
	var f := str(o.forme)
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.18))
	match f:
		"pionnier":
			# (un bouleau : un fût blanc taché d'encre, un feuillage léger en deux ou trois touffes, plus clair)
			var haut := cc.y + ry * 0.5
			var lobes := [[cc + Vector2(0, ry * 0.2), rx * 0.85, ry * 0.62], [cc + Vector2(-rx * 0.3, -ry * 0.35), rx * 0.62, ry * 0.5]]
			if r.randf() < 0.6:
				lobes.append([cc + Vector2(rx * 0.42, -ry * 0.05), rx * 0.55, ry * 0.45])
			_houppier(o, p, r, lobes, haut, t.lightened(0.1).lerp(P.BRAISE_COEUR, 0.06))
			_lenticelles(o, p, r, -9.0, haut + 4.0)
		"fruitier":
			_houppier(o, p, r, [[cc, rx, ry]], cc.y + ry * 0.35, t)
			# (ses fruits, ronds et luisants, posés sur le feuillage)
			var fruit := P.BRAISE_ROUGE.lerp(P.BRAISE, 0.25) if o.graine % 3 != 0 else P.BRAISE_COEUR.darkened(0.12)
			for i in r.randi_range(7, 11):
				var q: Vector2 = cc + Vector2(r.randf_range(-0.75, 0.75) * rx, r.randf_range(-0.55, 0.7) * ry)
				p.disque(q, 2.5, 2.4, ENCRE)
				p.disque(q, 1.9, 1.85, fruit, Pinceau.DOME)
				p.disque(q + Vector2(-0.6, -0.7), 0.55, 0.5, Color(1.0, 0.96, 0.88, 0.9))
		"geant":
			var lobes := [[cc + Vector2(-rx * 0.42, ry * 0.18), rx * 0.62, ry * 0.62], [cc + Vector2(rx * 0.44, ry * 0.22), rx * 0.6, ry * 0.6],
				[cc + Vector2(r.randf_range(-3.0, 3.0), -ry * 0.32), rx * 0.66, ry * 0.62]]
			_houppier(o, p, r, lobes, cc.y + ry * 0.55, t.lerp(P.FEUILLE_SOMBRE, 0.12))
		"emergent":
			# (au-dessus des autres : un long fût nu, une ombrelle plate)
			var lobes := [[cc + Vector2(-rx * 0.45, 0), rx * 0.6, ry * 0.85], [cc + Vector2(rx * 0.45, ry * 0.05), rx * 0.58, ry * 0.8],
				[cc + Vector2(0, -ry * 0.3), rx * 0.55, ry * 0.75]]
			_houppier(o, p, r, lobes, cc.y + ry * 0.5, t)
		"figuier":
			var lobes := [[cc + Vector2(-rx * 0.5, ry * 0.12), rx * 0.58, ry * 0.75], [cc + Vector2(rx * 0.5, ry * 0.15), rx * 0.56, ry * 0.72],
				[cc + Vector2(0, -ry * 0.2), rx * 0.62, ry * 0.8]]
			# (ses racines aériennes, qui tombent du feuillage jusqu'au sol)
			var corde := P.CENDRE.lerp(P.IVOIRE, 0.35)
			for i in r.randi_range(4, 6):
				var x := cc.x + r.randf_range(-0.8, 0.8) * rx
				var y0 := cc.y + ry * r.randf_range(0.3, 0.6)
				var ligne := PackedVector2Array([Vector2(x, y0), Vector2(x + r.randf_range(-1.5, 1.5), lerpf(y0, 0.0, 0.5)), Vector2(x + r.randf_range(-2.5, 2.5), r.randf_range(-1.0, 1.5))])
				p.tracer(ligne, 1.6, ENCRE, false)
				p.tracer(ligne, 0.8, corde, false)
			_houppier(o, p, r, lobes, cc.y + ry * 0.4, t)
		"sous_bois":
			_houppier(o, p, r, [[cc, rx, ry]], cc.y + ry * 0.35, t.lerp(P.FEUILLE_SOMBRE, 0.3))
		"paletuvier":
			var lobes := [[cc + Vector2(-rx * 0.38, ry * 0.1), rx * 0.66, ry * 0.7], [cc + Vector2(rx * 0.4, ry * 0.12), rx * 0.64, ry * 0.68],
				[cc + Vector2(0, -ry * 0.25), rx * 0.6, ry * 0.65]]
			_houppier(o, p, r, lobes, cc.y + ry * 0.45, t.lerp(P.FEUILLE_SOMBRE, 0.15))
		"bouteille":
			_baobab(o, p, r, t)
		"palmier":
			_palmier(o, p, r, t, false)
		"fougere_arbre":
			_palmier(o, p, r, t, true)
		_:
			return false
	return true


# un feuillu en plusieurs touffes : le tronc jusqu'à haut, une branche vers chaque touffe, puis les touffes (celles du fond
# d'abord), chacune bordée d'encre, des arcs d'ombre en bas à droite
static func _houppier(o, p, r: RandomNumberGenerator, lobes: Array, haut: float, teinte: Color) -> void:
	var c: Color = o._ecorce()
	o._tronc(p, -8.5, haut, c)
	for i in r.randi_range(2, 3):
		var y := r.randf_range(-12.0, haut + 6.0)
		var x: float = o._axe(y) + r.randf_range(-1.5, 2.0)
		p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + 0.3, y - r.randf_range(4.0, 7.0))]), 0.7, Color(ENCRE, 0.45))
	var depart := Vector2(o._axe(haut + 3.0), haut + 3.0)
	var ep: float = o.epaisseur
	for l in lobes:
		var b: Vector2 = l[0] + Vector2(0, float(l[2]) * 0.25)
		if b.distance_to(depart) < 4.0:
			continue
		var m := (depart + b) * 0.5 + Vector2((b.x - depart.x) * -0.12, 2.0)
		p.tracer(PackedVector2Array([depart, m, b]), 3.4 * ep, ENCRE)
		p.tracer(PackedVector2Array([depart, m, b]), 2.2 * ep, c)
	var bas := -INF
	for l in lobes:
		bas = maxf(bas, l[0].y + float(l[2]))
	p.eventail(Vector2(o._axe(bas), bas - 2.0), 6.5 * ep, 5.0, Color(P.ENCRE, 0.5), Color(P.ENCRE, 0.0), 12)
	var tries := lobes.duplicate()
	tries.sort_custom(func(a, b): return a[0].y < b[0].y)
	for l in tries:
		var q: Vector2 = l[0]
		var lx: float = l[1]
		var ly: float = l[2]
		var poly: PackedVector2Array = o.festons(q, lx, ly, r.randi_range(6, 8), 0.17, r, 48, 0.12)
		var tl := teinte.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.12)).lightened(r.randf_range(0.0, 0.07))
		p.aplat(poly, tl, Pinceau.FEUILLAGE, q, Vector2(lx, ly) * 1.08)
		p.contour(poly, 1.4, ENCRE, r, 4)
		for k in r.randi_range(2, 3):
			var a0 := q + Vector2(r.randf_range(-0.05, 0.7) * lx, r.randf_range(0.0, 0.65) * ly)
			var rr := r.randf_range(4.5, 7.0)
			var arc := PackedVector2Array()
			var d := r.randf_range(-0.2, 0.4)
			for j in 6:
				arc.append(a0 + Vector2(cos(d + j * 0.32), sin(d + j * 0.32) * 0.9) * rr)
			p.tracer(arc, 0.85, Color(ENCRE, 0.55))


# les taches d'encre d'un fût de bouleau, en travers
static func _lenticelles(o, p, r: RandomNumberGenerator, y0: float, y1: float) -> void:
	var y := y0 - r.randf_range(1.0, 3.0)
	while y > y1:
		var w: float = o._demi_largeur(y)
		var x: float = o._axe(y)
		var a := x - w * r.randf_range(0.2, 0.9)
		var b := a + w * r.randf_range(0.5, 1.1)
		p.tracer(PackedVector2Array([Vector2(a, y), Vector2(b, y + r.randf_range(-0.4, 0.4))]), r.randf_range(0.8, 1.4), Color(ENCRE, 0.8))
		y -= r.randf_range(3.0, 6.0)


# un baobab : un fût en bouteille, ventru, lisse et gris ; quelques grosses branches courtes, un feuillage maigre
static func _baobab(o, p, r: RandomNumberGenerator, t: Color) -> void:
	var c: Color = o._ecorce()
	var haut: float = o._cc.y + o._ry * 0.4
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	var n := 9
	for i in n + 1:
		var u := float(i) / n
		var y := lerpf(-8.5, haut, u)
		var w: float = o._demi_largeur(-8.5) * (1.0 + 0.28 * sin(u * PI * 0.9)) * lerpf(1.0, 0.55, smoothstep(0.65, 1.0, u))
		gauche.append(Vector2(o._axe(y) - w, y))
		droite.append(Vector2(o._axe(y) + w, y))
	var poly := PackedVector2Array(gauche)
	var rev := droite.duplicate()
	rev.reverse()
	poly.append_array(rev)
	var milieu := Vector2(o._axe((haut - 8.5) * 0.5), (haut - 8.5) * 0.5)
	p.aplat(poly, c, Pinceau.ECORCE, milieu, Vector2(o._demi_largeur(-8.5) * 1.3, absf(haut) * 0.6))
	p.tracer(gauche, 1.2, ENCRE, false)
	p.tracer(droite, 1.8, ENCRE, false)
	# (des plis verticaux sur l'écorce lisse)
	for i in 3:
		var x0: float = milieu.x + r.randf_range(-0.5, 0.6) * o._demi_largeur(-8.5)
		p.tracer(PackedVector2Array([Vector2(x0, -10.0), Vector2(x0 + r.randf_range(-1.0, 1.0), lerpf(-10.0, haut, 0.6))]), 0.7, Color(ENCRE, 0.4))
	var sommet := Vector2(o._axe(haut), haut)
	var touffes := []
	for i in r.randi_range(4, 6):
		var a := lerpf(-2.7, -0.45, (i + r.randf_range(0.2, 0.8)) / 5.0)
		var bout: Vector2 = sommet + Vector2(cos(a) * o._rx * r.randf_range(0.6, 0.95), sin(a) * o._ry * r.randf_range(0.8, 1.4))
		var mil := sommet.lerp(bout, 0.5) + Vector2(0, -2.0)
		p.tracer(PackedVector2Array([sommet, mil, bout]), 4.2, ENCRE, true, PackedFloat32Array([5.0, 3.6, 1.6]))
		p.tracer(PackedVector2Array([sommet, mil, bout]), 2.8, c, true, PackedFloat32Array([3.6, 2.4, 0.8]))
		touffes.append(bout)
	for q in touffes:
		var poly2: PackedVector2Array = o.festons(q + Vector2(0, -2.0), r.randf_range(9.0, 12.0), r.randf_range(5.5, 7.5), 6, 0.25, r, 26, 0.1)
		p.aplat(poly2, t, Pinceau.FEUILLAGE, q + Vector2(0, -2.0), Vector2(12.0, 7.5))
		p.contour(poly2, 1.0, ENCRE, r, 2)


# un palmier (ou une fougère arborescente) : le fût qui se courbe, annelé (ou hérissé de fibres sombres), puis ses palmes qui
# retombent en bouquet ; la fougère a ses folioles plus fines, et des crosses au cœur
static func _palmier(o, p, r: RandomNumberGenerator, t: Color, fougere: bool) -> void:
	var c: Color = o._ecorce()
	var ht: float = o._ht
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	var axe := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var y := lerpf(-8.5, -ht, float(i) / n)
		var x := _courbe_palme(o, y)
		var w: float = o._demi_largeur(-8.5) * lerpf(1.0, 0.82, float(i) / n)
		axe.append(Vector2(x, y))
		gauche.append(Vector2(x - w, y))
		droite.append(Vector2(x + w, y))
	var poly := PackedVector2Array(gauche)
	var rev := droite.duplicate()
	rev.reverse()
	poly.append_array(rev)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for i in poly.size():
		cols.append(c)
		uvs.append(Vector2(10.0 if i <= n else 12.0, 11.0))
	p.aplat_libre(poly, cols, uvs)
	p.tracer(gauche, 1.0, ENCRE, false)
	p.tracer(droite, 1.6, ENCRE, false)
	# (les anneaux des palmes tombées ; les fibres d'une fougère)
	for i in range(1, n):
		var q := axe[i]
		var w := gauche[i].distance_to(axe[i])
		if fougere:
			for k in 2:
				var x0 := q.x + r.randf_range(-w, w) * 0.8
				p.tracer(PackedVector2Array([Vector2(x0, q.y), Vector2(x0 + r.randf_range(-1.5, 1.5), q.y + 2.5)]), 0.8, Color(ENCRE, 0.65))
		else:
			p.tracer(PackedVector2Array([q + Vector2(-w, 0.6), q + Vector2(0, 1.4), q + Vector2(w, 0.4)]), 0.8, Color(ENCRE, 0.6), false)
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	# les palmes : de celles du fond (vers le haut) à celles qui viennent vers nous, en tombant
	var palmes := []
	var np := r.randi_range(8, 10) if fougere else r.randi_range(7, 9)
	for i in np:
		var a := lerpf(-PI + 0.15, -0.15, float(i) / (np - 1)) + r.randf_range(-0.12, 0.12)
		palmes.append([a, r.randf_range(0.85, 1.05)])
	palmes.append([r.randf_range(0.35, 0.6), r.randf_range(0.6, 0.75)])
	palmes.append([PI - r.randf_range(0.35, 0.6), r.randf_range(0.6, 0.75)])
	palmes.sort_custom(func(a, b): return sin(a[0]) < sin(b[0]))
	var m := 11 if fougere else 9
	for pa in palmes:
		var a: float = pa[0]
		var l: float = rx * float(pa[1])
		var d := Vector2(cos(a), sin(a) * 0.55)
		var tombe := ry * (0.9 if fougere else 0.75)
		var axe_p := PackedVector2Array()
		for k in m + 1:
			var u := float(k) / m
			# (elle monte un peu, puis retombe sous son poids)
			axe_p.append(cc + d * l * u + Vector2(0, -ry * 0.55 * sin(u * PI * 0.7) + tombe * u * u))
		for passe in 2:
			var e := 0.6 if passe == 0 else 0.0
			var g := PackedVector2Array()
			var dr := PackedVector2Array()
			for k in m + 1:
				var u := float(k) / m
				var tan_ := (axe_p[mini(k + 1, m)] - axe_p[maxi(k - 1, 0)]).normalized()
				var nrm := tan_.orthogonal()
				var w := (5.2 if fougere else 6.2) * sin(PI * minf(1.0, u * 1.15 + 0.06)) * (1.0 - u * 0.55)
				# (des folioles : la palme dentée, plus finement pour une fougère)
				w *= (1.0 if k % 2 == 0 else (0.45 if fougere else 0.62))
				w += e
				var avance := tan_ * (1.4 if k % 2 == 0 else 0.0)
				g.append(axe_p[k] + nrm * w + avance)
				dr.append(axe_p[k] - nrm * w + avance)
			if passe == 0:
				p.bande(g, dr, Color(ENCRE, 0.75))
			else:
				var face := t.lerp(t.lightened(0.22), clampf(-sin(a), 0.0, 1.0) * 0.6 + 0.15)
				p.bande(g, axe_p, face)
				p.bande(axe_p, dr, face.darkened(0.22))
				p.tracer(axe_p, 0.7, face.darkened(0.45), false, PackedFloat32Array(), false)
	if fougere:
		# (des crosses qui se déroulent, au cœur)
		for i in 2:
			var q := cc + Vector2((i - 0.5) * 5.0, -2.0)
			var spi := PackedVector2Array()
			for k in 12:
				var u := k / 11.0
				var ang := -PI * 0.5 + u * TAU * 1.1 * (1.0 if i == 0 else -1.0)
				spi.append(q + Vector2(0, -6.0 * (1.0 - u)) + Vector2(cos(ang), sin(ang)) * (2.6 * u))
			p.tracer(spi, 1.6, ENCRE, false)
			p.tracer(spi, 0.9, t.lightened(0.3), false)
	else:
		# (des fruits en grappe, sous les palmes)
		for i in 3:
			var q := cc + Vector2(r.randf_range(-3.0, 3.0), r.randf_range(2.0, 4.5))
			p.disque(q, 2.7, 2.5, ENCRE)
			p.disque(q, 2.1, 1.95, P.TERRE.lerp(P.BRAISE, 0.35), Pinceau.DOME)


# --- le reste : buissons, sol, fleurs, eau, champignons des bois ---

static func dessiner(o, p, r: RandomNumberGenerator) -> bool:
	if bool(o.planche):
		_planche(o)
		return true
	var f := str(o.forme)
	match str(o.genre):
		"buisson":
			match f:
				"epine":
					_epine(o, p, r)
				"ronce":
					_ronce(o, p, r)
				"aromatique":
					_aromatique(o, p, r)
				"bruyere":
					_bruyere(o, p, r)
				"liane":
					_liane(o, p, r)
				_:
					return false
		"touffe":
			match f:
				"cereale":
					_cereale(o, p, r, false)
				"riz":
					_cereale(o, p, r, true)
				"jonc":
					_jonc(o, p, r)
				"papyrus":
					_papyrus(o, p, r)
				"bambou":
					_bambou(o, p, r)
				"legumineuse":
					_legumineuse(o, p, r)
				"fougere":
					_fougere(o, p, r)
				"coussin":
					_coussin(o, p, r)
				"mousse":
					_mousse(o, p, r)
				"lichen":
					_lichen(o, p, r, false)
				"lichen_croute":
					_lichen(o, p, r, true)
				"lichen_rennes":
					_lichen_rennes(o, p, r)
				"succulente":
					_succulente(o, p, r)
				"agave":
					_agave(o, p, r)
				"cactus":
					_cactus(o, p, r)
				"caillou":
					_plante_caillou(o, p, r)
				_:
					return false
		"fleur":
			_fleurs(o, p, r)
		"aquatique":
			_aquatique(o, p, r)
		"cepe", "amanite":
			_champignons_des_bois(o, p, r, str(o.genre) == "amanite")
		_:
			return false
	return true


# une forme que Lisière ne sait pas dessiner : la planche d'Orvane, petite, en secours (un nœud à part : elle n'a pas d'encre)
static func _planche(o) -> void:
	if o.has_meta("planche"):
		return
	o.set_meta("planche", true)
	var orvane = o.get_node_or_null("/root/Orvane") if o.is_inside_tree() else null
	var tex: Texture2D = orvane.texture_plante(str(o.plante), 34.0) if orvane != null else null
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = Vector2(0, -tex.get_height() * (144.0 / 150.0 - 0.5))
	o.add_child.call_deferred(s)


# -- les buissons --

# un buisson d'épines : dense, anguleux, sombre, hérissé ; des prunelles bleu-noir s'il en porte
static func _epine(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var bois := P.ENCRE_DOUCE.lerp(P.TERRE, 0.35)
	for i in 4:
		var x := r.randf_range(-rx * 0.6, rx * 0.6)
		p.tracer(PackedVector2Array([Vector2(x, 1.5), Vector2(x * 1.4 + r.randf_range(-2, 2), -6.0)]), 1.4, bois)
	var centre := Vector2(0, -ry * 0.5)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.55, r.randi_range(11, 14), 0.3, r, 56, 0.25)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.38)
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.15)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.55) * 1.08)
	p.contour(poly, 1.3, ENCRE, r, 4)
	# (des rameaux qui dépassent en zigzag, et leurs épines)
	for i in r.randi_range(4, 6):
		var a := r.randf_range(-PI + 0.3, -0.3)
		var d := Vector2(cos(a), sin(a) * 0.7)
		var q0 := centre + Vector2(d.x * rx * 0.8, d.y * ry * 0.45)
		var q1 := q0 + d * r.randf_range(3.0, 6.0) + d.orthogonal() * r.randf_range(-1.5, 1.5)
		var q2 := q1 + d * r.randf_range(2.0, 4.0) - d.orthogonal() * r.randf_range(-1.5, 1.5)
		p.tracer(PackedVector2Array([q0, q1, q2]), 1.1, ENCRE, false)
		p.tracer(PackedVector2Array([q1, q1 + d.orthogonal() * 2.2 + d * 0.8]), 0.8, ENCRE)
	for i in range(0, poly.size(), 3):
		var q: Vector2 = poly[i]
		var dehors := (q - centre).normalized()
		if dehors.y > 0.55:
			continue
		p.tracer(PackedVector2Array([q - dehors * 0.5, q + dehors * 2.4 + dehors.orthogonal() * 0.9]), 0.85, ENCRE)
	if o.a_fruits:
		var prune := P.NUIT_BLEUE.lerp(P.LUNE, 0.35)
		var rb := RandomNumberGenerator.new()
		rb.seed = o.graine + 5
		for i in o.reste * 4:
			var q := centre + Vector2(rb.randf_range(-0.7, 0.7) * rx, rb.randf_range(-0.45, 0.5) * ry * 0.55)
			p.disque(q, 2.1, 2.0, ENCRE)
			p.disque(q, 1.55, 1.5, prune, Pinceau.DOME)
			p.disque(q + Vector2(-0.4, -0.5), 0.6, 0.5, Color(P.LUNE.lightened(0.5), 0.8))
	else:
		# (sans fruits : de petites fleurs blanches, éparses)
		for i in 6:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.5, 0.2) * ry * 0.55)
			p.disque(q, 1.1, 1.0, P.PAPIER.lightened(0.1))


# un roncier : des tiges arquées, rougeâtres, piquantes, qui retombent jusqu'au sol ; des mûres noires (et quelques rouges)
static func _ronce(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var tige := P.SANG.lerp(P.TERRE, 0.45)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.22)
	var centre := Vector2(0, -ry * 0.45)
	# (un fond de feuillage bas, sous les tiges)
	var fond: PackedVector2Array = o.festons(centre + Vector2(0, ry * 0.12), rx * 0.82, ry * 0.42, 8, 0.22, r, 40, 0.3)
	p.aplat(fond, t.darkened(0.12), Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5))
	p.contour(fond, 1.1, ENCRE, r, 3)
	var cannes := []
	for i in r.randi_range(5, 7):
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a := Vector2(r.randf_range(-rx * 0.35, rx * 0.35), 1.0)
		var b := Vector2(cote * r.randf_range(rx * 0.75, rx * 1.15), r.randf_range(-1.0, 2.0))
		var h := r.randf_range(ry * 0.7, ry * 1.1)
		cannes.append([a, Vector2((a.x + b.x) * 0.5, -h), b])
	for c in cannes:
		var ligne := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			ligne.append(c[0].lerp(c[1], u).lerp(c[1].lerp(c[2], u), u))
		p.tracer(ligne, 2.3, ENCRE, false)
		p.tracer(ligne, 1.3, tige, false)
		# (des épines le long, et des feuilles par trois)
		for k in range(1, 8, 2):
			var q := ligne[k]
			var d := (ligne[k + 1] - ligne[k - 1]).normalized()
			p.tracer(PackedVector2Array([q, q + d.orthogonal() * 1.8 + d * 0.6]), 0.7, ENCRE)
			if k % 4 == 1:
				for j in 3:
					var ang := d.angle() - PI * 0.5 + (j - 1) * 0.7
					var fb := q + Vector2.from_angle(ang) * 3.4
					p.disque(fb, 2.3, 1.6, ENCRE)
					p.disque(fb, 1.75, 1.15, t.lightened(0.08), Pinceau.FEUILLAGE)
	if o.reste > 0:
		var rb := RandomNumberGenerator.new()
		rb.seed = o.graine + 5
		for g in o.reste * 2:
			var c: Array = cannes[g % cannes.size()]
			var q: Vector2 = c[0].lerp(c[1], 0.7).lerp(c[1].lerp(c[2], 0.7), 0.7) + Vector2(rb.randf_range(-2.0, 2.0), rb.randf_range(0.0, 2.0))
			var mure := P.NUIT.lerp(P.SANG, 0.35) if rb.randf() < 0.75 else P.BRAISE_ROUGE
			p.disque(q, 2.4, 2.6, ENCRE)
			p.disque(q, 1.8, 2.0, mure, Pinceau.DOME)
			for k in 3:
				p.disque(q + Vector2(rb.randf_range(-0.9, 0.9), rb.randf_range(-1.1, 1.1)), 0.45, 0.45, Color(1.0, 0.92, 0.9, 0.6))


# un buisson aromatique : une boule basse, gris-vert, de tiges droites ; au bout, des épis de fleurs (lavande, ou jaunes)
static func _aromatique(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = o.teinte.lerp(P.LUNE, 0.28).lerp(P.IVOIRE, 0.18)
	var centre := Vector2(0, -ry * 0.42)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.5, r.randi_range(9, 12), 0.2, r, 44, 0.3)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5) * 1.08)
	p.contour(poly, 1.2, ENCRE, r, 3)
	var fleur := P.PEUR.lerp(P.CREPUSCULE, 0.45) if o.graine % 2 == 0 else P.BRAISE_COEUR.darkened(0.1)
	var n := 14
	var fleuries: int = n * o.reste / maxi(1, o.plein) if o.en_fleurs else 0
	for i in n:
		var x := lerpf(-rx * 0.85, rx * 0.85, (i + r.randf_range(0.2, 0.8)) / n)
		var y0 := centre.y + absf(x) / rx * ry * 0.25 - ry * 0.25
		var bout := Vector2(x * 1.15 + r.randf_range(-1.0, 1.0), y0 - r.randf_range(4.0, 8.0))
		p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 1.0, t.darkened(0.25))
		if i < fleuries:
			var d := (bout - Vector2(x, y0)).normalized()
			p.disque(bout - d * 1.2, 1.4, 2.6, ENCRE)
			p.disque(bout - d * 1.2, 0.95, 2.1, fleur, Pinceau.DOME)


# une bruyère : un coussin bas, ras, d'aiguilles brunes et vertes, piqué de petites fleurs rose-mauve
static func _bruyere(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var feuille := P.MOUSSE.lerp(P.TERRE, 0.4).darkened(0.12)
	var centre := Vector2(0, -ry * 0.4)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.62, r.randi_range(6, 8), 0.22, r, 36, 0.2)
	p.aplat(poly, feuille, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.62) * 1.08)
	p.contour(poly, 1.0, ENCRE, r, 3)
	for i in 10:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.4, 0.5) * ry * 0.48)
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-1.0, 1.0), -2.4)]), 0.7, Color(ENCRE, 0.5))
	if o.en_fleurs:
		var fleur := P.CREPUSCULE.lerp(P.PEUR, 0.3).lightened(0.12)
		var nb: int = 26 * o.reste / maxi(1, o.plein)
		for i in nb:
			var q := centre + Vector2(r.randf_range(-0.85, 0.75) * rx, r.randf_range(-0.95, 0.35) * ry * 0.48)
			p.disque(q, r.randf_range(0.8, 1.3), r.randf_range(0.6, 0.95), fleur.lightened(r.randf_range(0.0, 0.25)) if q.x < 0.0 else fleur.darkened(0.08))


# une liane : enroulée autour d'un vieux tronc mort penché, ses feuilles en cœur, ses vrilles
static func _liane(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var bois := P.TERRE.lerp(P.CENDRE, 0.35)
	var pied := Vector2(r.randf_range(-2.0, 2.0), 0.5)
	var tete := Vector2(r.randf_range(3.0, 7.0) * (1.0 if o.graine % 2 == 0 else -1.0), -h)
	p.tracer(PackedVector2Array([pied, pied.lerp(tete, 0.5) + Vector2(1.0, 0), tete]), 4.6, ENCRE, false, PackedFloat32Array([5.0, 4.2, 3.0]))
	p.tracer(PackedVector2Array([pied, pied.lerp(tete, 0.5) + Vector2(1.0, 0), tete]), 3.0, bois, false, PackedFloat32Array([3.4, 2.8, 1.8]))
	var vigne := P.MOUSSE.lerp(P.TERRE, 0.3)
	var spi := PackedVector2Array()
	var tours := 3.2
	for k in 30:
		var u := k / 29.0
		var q := pied.lerp(tete, u)
		spi.append(q + Vector2(sin(u * TAU * tours) * 4.2, cos(u * TAU * tours) * 1.2))
	p.tracer(spi, 1.6, ENCRE, false)
	p.tracer(spi, 0.9, vigne, false)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1)
	var feuilles: int = 14 * maxi(o.reste, 1) / maxi(1, o.plein) if o.reste > 0 else 4
	for i in feuilles:
		var k := r.randi_range(2, 29)
		var q := spi[k] + Vector2(r.randf_range(-2.0, 2.0), r.randf_range(-1.0, 1.0))
		_coeur(p, q, r.randf_range(2.4, 3.4), r.randf_range(-0.6, 0.6) + (0.0 if q.x < tete.x * (k / 29.0) else PI * 0.2), t.lightened(r.randf_range(0.0, 0.12)))
	# (des boucles qui pendent)
	for i in 2:
		var q := spi[r.randi_range(12, 26)]
		var boucle := PackedVector2Array([q, q + Vector2(3.0 * (1 - 2 * i), 4.0), q + Vector2(1.0 * (1 - 2 * i), 8.0)])
		p.tracer(boucle, 0.9, vigne.darkened(0.15))


# une feuille en cœur, sa pointe vers ang
static func _coeur(p, q: Vector2, s: float, ang: float, c: Color) -> void:
	var poly := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var rr := s * (0.75 + 0.25 * cos(a)) * (1.0 - 0.35 * pow(maxf(0.0, -cos(a)), 6.0))
		poly.append(q + Vector2(cos(a) * rr, sin(a) * rr * 0.8).rotated(ang + PI * 0.5))
	p.aplat(_grossi(poly, q, 0.7), ENCRE)
	p.aplat(poly, c, Pinceau.FEUILLAGE, q, Vector2(s, s) * 1.1)


# un polygone, un peu agrandi depuis son centre (son liseré d'encre, dessous)
static func _grossi(poly: PackedVector2Array, centre: Vector2, de: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var d := q - centre
		out.append(q + d.normalized() * de)
	return out


# -- le sol --

# une graminée à grains : des lames, et des tiges hautes au bout desquelles l'épi pèse ; le riz : ses grains en grappes qui
# pendent, sur un sol mouillé
static func _cereale(o, p, r: RandomNumberGenerator, riz: bool) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lightened(0.05)
	var paille := t.lerp(P.IVOIRE, 0.4).lerp(P.BRAISE_COEUR, 0.15)
	var grain := P.BRAISE.lerp(P.IVOIRE, 0.45).darkened(0.08) if not riz else P.IVOIRE.lerp(P.BRAISE_COEUR, 0.2).darkened(0.05)
	if riz:
		p.eventail(Vector2(0, 1.5), 13.0, 3.6, Color(P.NUIT_BLEUE.lerp(P.TERRE, 0.5), 0.45), Color(P.NUIT_BLEUE, 0.0), 14)
	if o.reste <= 0:
		_chaumes(p, r, paille)
		return
	# les lames
	for i in 9:
		var x0 := r.randf_range(-3.0, 3.0)
		var cote := signf(x0 + r.randf_range(-0.5, 0.5))
		var hh := r.randf_range(0.4, 0.7) * h
		var bout := Vector2(x0 * 2.0 + cote * r.randf_range(3.0, 9.0) * (1.4 if riz else 1.0), -hh * (0.75 if riz else 1.0))
		var mil := Vector2(x0 * 1.2 + bout.x * 0.3, -hh * 0.7)
		var ligne := PackedVector2Array([Vector2(x0, 1.0), mil, bout])
		p.tracer(ligne, 2.6, ENCRE, false, PackedFloat32Array([3.0, 2.2, 0.8]))
		p.tracer(ligne, 1.8, t.lerp(paille, r.randf() * 0.4).darkened(r.randf() * 0.15), false, PackedFloat32Array([2.2, 1.5, 0.4]))
	# les tiges et leurs épis : un épi dressé qui ploie au bout, ses grains en chevrons et ses barbes ; le riz, une panicule
	# qui retombe en arc, ses grains pendus dessous
	for i in r.randi_range(4, 6):
		var x0 := r.randf_range(-2.5, 2.5)
		var hh := h * r.randf_range(0.8, 1.05)
		var penche := r.randf_range(0.08, 0.25) * (1.0 if r.randf() < 0.5 else -1.0)
		var bout := Vector2(x0 + penche * hh, -hh)
		var ligne := PackedVector2Array([Vector2(x0, 1.0), Vector2(x0 + penche * hh * 0.4, -hh * 0.55), bout])
		p.tracer(ligne, 1.7, ENCRE, false)
		p.tracer(ligne, 0.9, paille, false)
		var dir := (bout - ligne[1]).normalized()
		var epi := PackedVector2Array([bout])
		for k in range(1, 8 if riz else 6):
			var u := float(k)
			# (le poids du grain le fait ployer ; le riz, jusqu'à pendre)
			epi.append(bout + dir * u * (1.6 if riz else 1.5) + Vector2(signf(penche) * u * u * (0.12 if riz else 0.05), u * u * (0.22 if riz else 0.04)))
		p.tracer(epi, 1.2, ENCRE, false)
		for k in range(1, epi.size()):
			var q := epi[k]
			var d := (epi[k] - epi[k - 1]).normalized()
			var nrm := d.orthogonal()
			if riz:
				var g := q + Vector2(0, 1.4)
				p.disque(g, 1.0, 1.35, ENCRE)
				p.disque(g, 0.65, 0.95, grain, Pinceau.DOME)
				continue
			for cote in [-1.0, 1.0]:
				var g: Vector2 = q + nrm * cote * 0.9
				p.disque(g, 1.25, 1.25, ENCRE)
				p.disque(g, 0.85, 0.85, grain, Pinceau.DOME)
				# (les barbes)
				p.tracer(PackedVector2Array([g, g + nrm * cote * 1.2 + d * 3.2]), 0.45, Color(ENCRE, 0.6))


# ce qui reste d'une touffe coupée : des chaumes
static func _chaumes(p, r: RandomNumberGenerator, paille: Color) -> void:
	p.eventail(Vector2(0, 1), 7.0, 2.8, Color(P.TERRE.darkened(0.3), 0.6), Color(P.TERRE.darkened(0.3), 0.0), 12)
	for i in 7:
		var x := r.randf_range(-4.5, 4.5)
		p.tracer(PackedVector2Array([Vector2(x, 1), Vector2(x + r.randf_range(-1, 1), -r.randf_range(2.5, 4.5))]), 1.2, paille.darkened(0.2), false)


# un jonc : un faisceau de tiges rondes, droites, vert sombre ; une petite grappe brune sur le côté
static func _jonc(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.3)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	var tiges := []
	for i in 16:
		var x0 := r.randf_range(-3.0, 3.0)
		tiges.append([x0, Vector2(x0 * 2.2 + r.randf_range(-1.5, 1.5), -h * r.randf_range(0.75, 1.05)), r.randf()])
	tiges.sort_custom(func(a, b): return a[2] < b[2])
	for i in tiges.size():
		var tg: Array = tiges[i]
		var ligne := PackedVector2Array([Vector2(tg[0], 1.0), tg[1]])
		p.tracer(ligne, 2.0, ENCRE, false, PackedFloat32Array([2.0, 1.0]))
		p.tracer(ligne, 1.1, t.lightened(0.18 * tg[2]), false, PackedFloat32Array([1.2, 0.4]))
	for i in 2:
		var tg: Array = tiges[tiges.size() - 1 - i * 3]
		var q: Vector2 = Vector2(tg[0], 1.0).lerp(tg[1], 0.68) + Vector2(1.6, 0)
		for k in 4:
			var g := q + Vector2(r.randf_range(0.0, 2.5), r.randf_range(-1.5, 1.5))
			p.disque(g, 1.2, 1.2, ENCRE)
			p.disque(g, 0.8, 0.8, P.TERRE.lerp(P.BRAISE, 0.2))


# un papyrus : de hautes tiges nues, chacune coiffée d'une ombelle de fins rayons
static func _papyrus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lightened(0.06)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	for i in r.randi_range(5, 7):
		var x0 := r.randf_range(-4.0, 4.0)
		var hh := h * r.randf_range(0.7, 1.0)
		var bout := Vector2(x0 * 1.8 + r.randf_range(-3.0, 3.0), -hh)
		p.tracer(PackedVector2Array([Vector2(x0, 1.0), bout]), 1.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(x0, 1.0), bout]), 1.1, t.darkened(0.12), false)
		for k in 14:
			var a := -PI * 0.5 + (k / 13.0 - 0.5) * PI * 1.5
			var l := r.randf_range(5.0, 8.0)
			var q := bout + Vector2(cos(a) * l, sin(a) * l * 0.6 + l * 0.25 * absf(cos(a)))
			p.tracer(PackedVector2Array([bout, q]), 0.75, t.lightened(0.18) if k % 2 == 0 else t, false)


# un bambou : des cannes droites, nouées d'encre, vert-jaune ; des feuilles en lance aux nœuds du haut. Coupé, des moignons
static func _bambou(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var canne: Color = o.teinte.lerp(P.BRAISE_COEUR, 0.22).lightened(0.05)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1)
	var n := 5
	var debout: int = n - (o.plein - o.reste) * 2
	for i in n:
		var x0 := lerpf(-6.0, 6.0, (i + r.randf_range(0.2, 0.8)) / n)
		var hh := h * r.randf_range(0.7, 1.0)
		var w := r.randf_range(1.5, 2.1)
		var penche := r.randf_range(-0.05, 0.05)
		if i >= debout:
			# (une canne coupée en biseau)
			var cut := r.randf_range(4.0, 7.0)
			var poly := PackedVector2Array([Vector2(x0 - w, 1), Vector2(x0 + w, 1), Vector2(x0 + w, -cut + 1.5), Vector2(x0 - w, -cut)])
			p.aplat(poly, canne.darkened(0.08), Pinceau.ECORCE, Vector2(x0, -cut * 0.5), Vector2(w, cut))
			p.contour(poly, 0.9, ENCRE, r, 2)
			p.tracer(PackedVector2Array([Vector2(x0 - w, -cut), Vector2(x0 + w, -cut + 1.5)]), 0.8, P.IVOIRE)
			continue
		var bout := Vector2(x0 + penche * hh, -hh)
		var poly := PackedVector2Array([Vector2(x0 - w, 1), Vector2(x0 + w, 1), bout + Vector2(w * 0.6, 0), bout - Vector2(w * 0.6, 0)])
		p.aplat(poly, canne, Pinceau.ECORCE, Vector2(x0 + penche * hh * 0.5, -hh * 0.5), Vector2(w * 1.1, hh * 0.55))
		p.tracer(PackedVector2Array([Vector2(x0 - w, 1), bout - Vector2(w * 0.6, 0)]), 0.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(x0 + w, 1), bout + Vector2(w * 0.6, 0)]), 1.3, ENCRE, false)
		var y := -r.randf_range(7.0, 10.0)
		while y > -hh + 3.0:
			var q := Vector2(x0 + penche * -y, y)
			p.tracer(PackedVector2Array([q - Vector2(w + 0.3, 0), q + Vector2(w + 0.3, 0.5)]), 0.9, ENCRE, false)
			if y < -hh * 0.45 and r.randf() < 0.7:
				var cote := -1.0 if r.randf() < 0.5 else 1.0
				for k in 3:
					var a := Vector2(cote * r.randf_range(4.0, 8.0), r.randf_range(-2.0, 3.5))
					_lance(p, q, q + a, 1.3, t.lightened(r.randf_range(0.0, 0.15)))
			y -= r.randf_range(8.0, 11.0)


# une feuille en lance, de a à b
static func _lance(p, a: Vector2, b: Vector2, larg: float, c: Color) -> void:
	var d := b - a
	var n := d.orthogonal().normalized() * larg
	var poly := PackedVector2Array([a, a + d * 0.35 + n, b, a + d * 0.35 - n])
	p.aplat(PackedVector2Array([a - d.normalized() * 0.4, a + d * 0.35 + n * 1.5, b + d.normalized() * 0.6, a + d * 0.35 - n * 1.5]), ENCRE)
	p.aplat(poly, c)


# une légumineuse : basse, des feuilles par trois, des gousses qui pendent, quelques fleurs en papillon
static func _legumineuse(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = o.teinte.lightened(0.04)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	var tiges := []
	for i in 6:
		var a := Vector2(r.randf_range(-2.0, 2.0), 1.0)
		var b := Vector2(r.randf_range(-rx, rx), -r.randf_range(ry * 0.5, ry))
		tiges.append([a, b])
		p.tracer(PackedVector2Array([a, (a + b) * 0.5 + Vector2(0, -1.5), b]), 1.0, t.darkened(0.3))
	for tg in tiges:
		var q: Vector2 = tg[1]
		for j in 3:
			var fb: Vector2 = q + Vector2.from_angle(-PI * 0.5 + (j - 1) * 1.0) * 2.4
			p.disque(fb, 2.0, 1.6, ENCRE)
			p.disque(fb, 1.5, 1.15, t.lightened(0.06 * j), Pinceau.FEUILLAGE)
	for i in 3:
		var tg: Array = tiges[i * 2]
		var q: Vector2 = (tg[0] + tg[1]) * 0.5
		var gousse := PackedVector2Array([q, q + Vector2(2.5, 1.5), q + Vector2(4.5, 4.0)])
		p.tracer(gousse, 2.6, ENCRE)
		p.tracer(gousse, 1.7, t.lerp(P.BRAISE_COEUR, 0.25))
	for i in 3:
		var q: Vector2 = tiges[i * 2 + 1][1] + Vector2(0, -2.5)
		p.disque(q, 1.5, 1.2, ENCRE)
		p.disque(q, 1.1, 0.85, P.PAPIER if o.graine % 2 == 0 else P.PEUR.lerp(P.PAPIER, 0.4))


# une fougère : des frondes qui partent du pied en couronne, dentées de folioles
static func _fougere(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.4).lightened(0.08)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.TERRE, 0.4))
		return
	var frondes := []
	var n := r.randi_range(6, 8)
	for i in n:
		frondes.append([lerpf(-PI + 0.35, -0.35, float(i) / (n - 1)) + r.randf_range(-0.12, 0.12), r.randf_range(0.8, 1.1) * h])
	frondes.append([r.randf_range(0.25, 0.5), h * 0.6])
	frondes.append([PI - r.randf_range(0.25, 0.5), h * 0.6])
	frondes.sort_custom(func(a, b): return sin(a[0]) < sin(b[0]))
	for fr in frondes:
		_fronde(p, Vector2(0, -1.5), fr[0], fr[1], 4.4, t)


# une fronde de fougère, de son pied le long de l'angle a (aplatie par la vue de biais)
static func _fronde(p, pied: Vector2, a: float, l: float, larg: float, t: Color) -> void:
	var m := 9
	var d := Vector2(cos(a), sin(a) * 0.62)
	var axe := PackedVector2Array()
	for k in m + 1:
		var u := float(k) / m
		axe.append(pied + d * l * u + Vector2(0, -l * 0.32 * sin(u * PI * 0.85) + u * u * 2.0))
	for passe in 2:
		var e := 0.55 if passe == 0 else 0.0
		var g := PackedVector2Array()
		var dr := PackedVector2Array()
		for k in m + 1:
			var u := float(k) / m
			var tan_ := (axe[mini(k + 1, m)] - axe[maxi(k - 1, 0)]).normalized()
			var nrm := tan_.orthogonal()
			var w := larg * sin(PI * minf(1.0, u * 1.2 + 0.08)) * (1.0 - u * 0.7) * (1.0 if k % 2 == 0 else 0.6) + e
			var avance := tan_ * (1.0 if k % 2 == 0 else 0.0)
			g.append(axe[k] + nrm * w + avance)
			dr.append(axe[k] - nrm * w + avance)
		if passe == 0:
			p.bande(g, dr, Color(ENCRE, 0.7))
		else:
			var face := t.lerp(t.lightened(0.2), clampf(-sin(a), 0.0, 1.0) * 0.6 + 0.2)
			p.bande(g, axe, face)
			p.bande(axe, dr, face.darkened(0.2))


# une plante en coussin : un dôme serré, ras, piqué de toutes petites fleurs ; poudré de neige s'il fait froid
static func _coussin(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry * 0.85
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.3)
	var centre := Vector2(0, -ry * 0.6)
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(9, 12), 0.08, r, 40, 0.15)
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.25)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	p.contour(poly, 1.1, ENCRE, r, 3)
	for i in 12:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.6, 0.6) * ry)
		p.disque(q, 0.5, 0.5, Color(ENCRE, 0.35))
	if o.reste > 0:
		var fleur := P.PAPIER.lightened(0.1) if o.graine % 3 != 0 else P.PEUR.lerp(P.PAPIER, 0.5)
		for i in 10:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.8, 0.2) * ry)
			p.disque(q, 0.85, 0.75, fleur)
	if float(o._climat.get("froid", 0.0)) > 0.25:
		o._neige_sur(p, poly, centre + Vector2(0, -ry * 0.4), rx * 0.8, ry * 0.5, centre.y - ry * 0.25, r)


# une mousse : des coussinets ras, d'un vert vif, serrés les uns contre les autres
static func _mousse(o, p, r: RandomNumberGenerator) -> void:
	var t := P.MOUSSE.lightened(0.12).lerp(o.teinte, 0.3)
	for i in r.randi_range(3, 5):
		var q := Vector2(r.randf_range(-0.6, 0.6) * o._rx, r.randf_range(-0.4, 0.5) * o._ry)
		var rx := r.randf_range(3.5, 6.0)
		var poly: PackedVector2Array = o.festons(q + Vector2(0, -1.0), rx, rx * 0.5, 6, 0.2, r, 20, 0.2)
		p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25)), Pinceau.FEUILLAGE, q + Vector2(0, -1.0), Vector2(rx, rx * 0.5) * 1.1)
		p.contour(poly, 0.7, Color(ENCRE, 0.7), r, 2)


# un lichen, à plat : des rosettes de croûte (jaune, vert pâle, orangée) sur une plaque grise ; en croûte, sur une pierre
static func _lichen(o, p, r: RandomNumberGenerator, croute: bool) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var gris := P.CENDRE.lerp(P.IVOIRE, 0.55)
	if croute:
		# (une pierre plate, la croûte dessus)
		var pierre: PackedVector2Array = o.festons(Vector2(0, -2.0), rx * 0.9, ry * 0.9, 5, 0.15, r, 18, 0.1)
		p.aplat(pierre, gris, Pinceau.PIERRE, Vector2(0, -2.0), Vector2(rx, ry))
		p.contour(pierre, 1.0, ENCRE, r, 2)
	else:
		var plaque: PackedVector2Array = o.festons(Vector2.ZERO, rx, ry, 7, 0.25, r, 26, 0.0)
		p.aplat(plaque, Color(gris.darkened(0.15), 0.85))
		p.contour(plaque, 0.7, Color(ENCRE, 0.45), r, 3)
	var tons := [P.BRAISE_COEUR.darkened(0.12), P.IVOIRE.lerp(P.MOUSSE, 0.3), P.BRAISE.darkened(0.1)]
	for i in r.randi_range(6, 10):
		var q := Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.6, 0.6) * ry - (2.0 if croute else 0.0))
		var s := r.randf_range(1.2, 2.6)
		var c: Color = tons[0 if croute and r.randf() < 0.6 else r.randi() % tons.size()]
		p.disque(q, s, s * 0.6, c)
		p.disque(q, s * 0.4, s * 0.25, c.darkened(0.3))


# le lichen des rennes : un coussin pâle, gris-vert, fait de petites boules ramifiées (un chou-fleur de corail) ; brouté ou
# cueilli, il n'en reste qu'une galette
static func _lichen_rennes(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry * (1.0 if o.reste > 0 else 0.45)
	var pale := P.IVOIRE.lerp(P.LUNE, 0.22).lerp(P.MOUSSE, 0.3).darkened(0.04)
	var centre := Vector2(0, -ry * 0.55)
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(10, 13), 0.18, r, 44, 0.12)
	p.aplat(poly, pale.darkened(0.18), Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	var boules := []
	for i in (22 if o.reste > 0 else 8):
		var a := r.randf() * TAU
		var d := sqrt(r.randf())
		boules.append(centre + Vector2(cos(a) * rx * 0.8 * d, sin(a) * ry * 0.75 * d - (1.0 - d) * 1.5))
	boules.sort_custom(func(u, v): return u.y < v.y)
	for q in boules:
		var s0 := r.randf_range(1.4, 2.2)
		p.disque(q, s0 + 0.45, s0 * 0.85 + 0.45, Color(ENCRE, 0.55))
		p.disque(q, s0, s0 * 0.85, pale.lerp(P.IVOIRE, r.randf_range(0.0, 0.25)) if q.x < 0.0 else pale.darkened(r.randf_range(0.0, 0.12)), Pinceau.DOME)
	p.contour(poly, 1.0, ENCRE, r, 3)


# une plante grasse : une rosette de feuilles charnues en cuillère, glauques, bordées de rose, vue de biais : celles du fond
# se dressent, celles de devant s'étalent vers nous ; cueillie, une rosette plus petite
static func _succulente(o, p, r: RandomNumberGenerator) -> void:
	var k: float = 1.0 if o.reste >= o.plein else 0.65
	var rx: float = (o._rx + 2.0) * k
	var t: Color = o.teinte.lerp(P.LUNE, 0.35).lightened(0.08)
	var bord := P.BRAISE_ROUGE.lerp(P.PEUR, 0.35).lightened(0.18)
	var c0 := Vector2(0, -4.0 * k)
	var feuilles := []
	for anneau in 2:
		var n := 9 if anneau == 0 else 6
		for i in n:
			var a := TAU * i / n + r.randf_range(-0.12, 0.12) + anneau * 0.3
			feuilles.append([a, (1.0 if anneau == 0 else 0.62) * r.randf_range(0.85, 1.0), anneau])
	# (de l'arrière vers l'avant ; le cœur, plus haut, par-dessus)
	feuilles.sort_custom(func(u, v): return sin(u[0]) + u[2] * 3.0 < sin(v[0]) + v[2] * 3.0)
	for fe in feuilles:
		var a: float = fe[0]
		var l: float = rx * float(fe[1])
		var leve := 3.5 if fe[2] == 1 else 1.5
		var bout := c0 + Vector2(cos(a) * l, sin(a) * l * 0.45 - leve * (1.0 - sin(a) * 0.5))
		var d := bout - c0
		var nrm := d.orthogonal().normalized() * (3.0 + 1.2 * float(fe[1])) * k
		var poly := PackedVector2Array([c0 + nrm * 0.3, c0 + d * 0.45 + nrm * 0.9, c0 + d * 0.8 + nrm * 0.85, bout, c0 + d * 0.8 - nrm * 0.85, c0 + d * 0.45 - nrm * 0.9, c0 - nrm * 0.3])
		var face := t.lerp(t.darkened(0.3), clampf(sin(a), 0.0, 1.0) * 0.45).lightened(0.06 * float(fe[2]))
		p.aplat(_grossi(poly, c0 + d * 0.5, 0.75), ENCRE)
		p.aplat(poly, face, Pinceau.DOME, c0 + d * 0.55, Vector2(d.length() * 0.6, nrm.length() * 1.2 + 0.5))
		p.tracer(PackedVector2Array([c0 + d * 0.8 + nrm * 0.75, bout, c0 + d * 0.8 - nrm * 0.75]), 0.8, bord, false)


# un agave : une grande rosette de feuilles raides, en lames, bleu-vert, chacune armée d'un dard noir et de dents
static func _agave(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx * (1.0 if o.reste > 0 else 0.6)
	var h: float = o._ry * (1.0 if o.reste > 0 else 0.6)
	var t: Color = o.teinte.lerp(P.LUNE, 0.35).lightened(0.04)
	var feuilles := []
	for i in 12:
		var a := lerpf(-PI + 0.1, -0.1, i / 11.0) + r.randf_range(-0.08, 0.08)
		feuilles.append([a, r.randf_range(0.7, 1.0), 0])
	for i in 4:
		feuilles.append([r.randf_range(0.3, 2.8), r.randf_range(0.45, 0.65), 1])
	feuilles.sort_custom(func(a, b): return sin(a[0]) < sin(b[0]))
	var c0 := Vector2(0, -2.0)
	for fe in feuilles:
		var a: float = fe[0]
		var l: float = float(fe[1])
		var bout := c0 + Vector2(cos(a) * rx * l, sin(a) * h * l if a < 0.0 else sin(a) * 3.0 * l)
		var d := bout - c0
		var nrm := d.orthogonal().normalized() * 2.6
		var poly := PackedVector2Array([c0 + nrm, c0 + d * 0.45 + nrm * 0.8, bout, c0 + d * 0.45 - nrm * 0.8, c0 - nrm])
		var face := t.lerp(t.lightened(0.18), clampf(-cos(a) * 0.5 + 0.3, 0.0, 1.0)).darkened(0.12 * float(fe[2]))
		p.aplat(_grossi(poly, c0 + d * 0.45, 0.75), ENCRE)
		p.aplat(poly, face)
		p.tracer(PackedVector2Array([c0, bout - d * 0.08]), 0.6, face.darkened(0.3), false)
		# (le dard, et des dents le long du bord)
		p.tracer(PackedVector2Array([bout - d.normalized() * 1.0, bout + d.normalized() * 2.2]), 1.2, ENCRE)
		for k in [0.35, 0.6]:
			var q: Vector2 = c0 + d * k + nrm * (0.9 - k * 0.3)
			p.tracer(PackedVector2Array([q, q + nrm.normalized() * 1.2 + d.normalized() * 0.5]), 0.6, ENCRE)


# un cactus en candélabre : une colonne côtelée, un ou deux bras qui se relèvent, des aréoles épineuses ; entamé, un bras en moins
static func _cactus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var w: float = o._rx
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.35).lerp(P.LUNE, 0.12)
	var bras := []
	var nb := 2 if o.graine % 3 != 0 else 1
	if o.reste < o.plein:
		nb -= 1
	for i in nb:
		var cote := -1.0 if (i + o.graine) % 2 == 0 else 1.0
		bras.append([cote, r.randf_range(0.3, 0.55) * h, r.randf_range(0.6, 0.85) * h, r.randf_range(w * 1.8, w * 2.6)])
	# (les bras derrière la colonne d'abord, du côté de l'ombre)
	for b in bras:
		_bras_cactus(p, r, b, w * 0.72, t.darkened(0.06))
	_colonne(p, r, Vector2.ZERO, w, h, t)
	if o.reste < o.plein:
		# (là où un bras a été coupé : une plaie claire)
		var q := Vector2(w * (1.0 if o.graine % 2 == 0 else -1.0) * 0.85, -h * 0.42)
		p.disque(q, 2.6, 2.0, ENCRE)
		p.disque(q, 2.0, 1.5, P.IVOIRE.lerp(P.MOUSSE, 0.3))


static func _colonne(p, r: RandomNumberGenerator, pied: Vector2, w: float, h: float, t: Color) -> void:
	var poly := PackedVector2Array([pied + Vector2(-w, 1.0)])
	for i in 9:
		var a := PI + PI * i / 8.0
		poly.append(pied + Vector2(cos(a) * w, -h + w + sin(a) * w))
	poly.append(pied + Vector2(w, 1.0))
	p.aplat(poly, t, Pinceau.ECORCE, pied + Vector2(0, -h * 0.5), Vector2(w * 1.05, h * 0.55))
	p.contour(poly, 1.3, ENCRE, r, 3)
	for k in [-0.5, 0.0, 0.5]:
		var x: float = pied.x + w * k
		var cote := Vector2(x, pied.y - 1.0)
		p.tracer(PackedVector2Array([cote, Vector2(x * 0.92 + pied.x * 0.08, pied.y - h + w * (0.4 + absf(k)))]), 0.7, Color(ENCRE, 0.55), false)
		var y := pied.y - 4.0
		while y > pied.y - h + w:
			p.disque(Vector2(x + 0.6, y), 0.55, 0.5, P.PAPIER.lightened(0.1))
			y -= r.randf_range(4.0, 6.0)


static func _bras_cactus(p, r: RandomNumberGenerator, b: Array, w: float, t: Color) -> void:
	var cote: float = b[0]
	var y0 := -float(b[1])
	var y1 := -float(b[2])
	var x1 := cote * float(b[3])
	# (le coude : il part de la colonne à l'horizontale, puis se relève)
	var coude := PackedVector2Array()
	for k in 7:
		var u := k / 6.0
		var a := PI * 0.5 * u
		coude.append(Vector2(lerpf(0.0, x1, sin(a)), y0 - (1.0 - cos(a)) * (x1 * cote) * 0.5))
	var g := PackedVector2Array()
	var d := PackedVector2Array()
	for k in coude.size():
		var tan_ := (coude[mini(k + 1, 6)] - coude[maxi(k - 1, 0)]).normalized()
		g.append(coude[k] + tan_.orthogonal() * w)
		d.append(coude[k] - tan_.orthogonal() * w)
	p.bande(g, d, Color(ENCRE, 0.9))
	var g2 := PackedVector2Array()
	var d2 := PackedVector2Array()
	for k in coude.size():
		var tan_ := (coude[mini(k + 1, 6)] - coude[maxi(k - 1, 0)]).normalized()
		g2.append(coude[k] + tan_.orthogonal() * (w - 1.0))
		d2.append(coude[k] - tan_.orthogonal() * (w - 1.0))
	p.bande(g2, d2, t)
	var haut_du_coude := coude[6]
	_colonne(p, r, Vector2(haut_du_coude.x, haut_du_coude.y + w * 0.5), w, maxf(6.0, haut_du_coude.y - y1 + w * 0.5), t)


# une plante-caillou : des paires de feuilles rondes, couleur de pierre, fendues au milieu, parmi des cailloux
static func _plante_caillou(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var pierre := P.IVOIRE.lerp(P.CENDRE, 0.25)
	for i in r.randi_range(3, 5):
		var q := Vector2(r.randf_range(-rx, rx), r.randf_range(-1.5, 2.5))
		var s := r.randf_range(1.2, 2.2)
		p.disque(q, s + 0.5, s * 0.75 + 0.5, ENCRE)
		p.disque(q, s, s * 0.75, pierre.darkened(r.randf_range(0.0, 0.2)), Pinceau.PIERRE)
	for i in r.randi_range(2, 4):
		var q := Vector2(r.randf_range(-0.6, 0.6) * rx, r.randf_range(-1.0, 1.0))
		var s := r.randf_range(2.6, 3.4)
		var t := pierre.lerp(P.BRAISE, 0.12).lerp(o.teinte, 0.15)
		p.disque(q + Vector2(0, -s * 0.4), s + 0.6, s * 0.7 + 0.6, ENCRE)
		p.disque(q + Vector2(0, -s * 0.4), s, s * 0.7, t, Pinceau.DOME)
		p.tracer(PackedVector2Array([q + Vector2(-s * 0.85, -s * 0.4), q + Vector2(0, -s * 0.3), q + Vector2(s * 0.85, -s * 0.45)]), 0.8, ENCRE, false)
		for k in 3:
			p.disque(q + Vector2(r.randf_range(-0.6, 0.6) * s, -s * 0.4 - r.randf_range(0.2, 0.5) * s * 0.7), 0.5, 0.4, Color(P.ENCRE_DOUCE, 0.6))


# -- les fleurs : celles des prés (de Lisière), celles de l'herbier (une fleur, un bulbe, une orchidée, une broméliacée) --

static func _fleurs(o, p, r: RandomNumberGenerator) -> void:
	var couleur: Color = o.couleur_fleur if o.couleur_fleur.a > 0.0 else P.PAPIER
	var vert: Color = o.teinte.lerp(P.MOUSSE, 0.35).lightened(0.04)
	var pousse := 1.0 - clampf(o._repousse / maxf(1.0, o._attente()), 0.0, 1.0) if o._repousse > 0.0 else 1.0
	var la: bool = o.reste > 0 and o.en_fleurs
	var u := 1.0 if la else (0.4 if pousse < 0.5 else 0.75)
	match str(o.forme):
		"bulbe":
			_bulbes(o, p, r, couleur, vert, la, u)
		"orchidee":
			_orchidees(o, p, r, couleur, vert, la, u)
		"bromelia":
			_bromelia(o, p, r, couleur, vert, la, u)
		_:
			_pres(o, p, r, couleur, vert, la, u, pousse)


# une colonie de fleurs des prés : des tiges grêles, une feuille ou deux, une corolle de cinq pétales ; l'herbier en fait des
# marguerites (plus hautes, plus de pétales). Cueillies : les tiges coupées ; puis les boutons, verts, qui reviennent
static func _pres(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float, pousse: float) -> void:
	var herbier := str(o.forme) == "fleur"
	var n := r.randi_range(4, 6) if herbier else r.randi_range(6, 9)
	var tetes := []
	for i in n:
		var pied := Vector2(r.randf_range(-o._rx, o._rx), r.randf_range(-o._ry, o._ry))
		var h := r.randf_range(0.6, 1.0) * float(o.hauteur) * (1.25 if herbier else 1.0) * u
		var bout := pied + Vector2(r.randf_range(-2.0, 2.0), -h)
		tetes.append([pied, bout, r.randf()])
	tetes.sort_custom(func(a, b): return a[0].y < b[0].y)
	for t in tetes:
		var pied: Vector2 = t[0]
		var bout: Vector2 = t[1]
		var mil := pied.lerp(bout, 0.5) + Vector2(r.randf_range(-1.0, 1.0), 0)
		p.tracer(PackedVector2Array([pied, mil, bout]), 1.6, Color(ENCRE, 0.8), false)
		p.tracer(PackedVector2Array([pied, mil, bout]), 0.8, vert.darkened(0.15), false)
		_lance(p, pied + Vector2(0, -0.5), pied + Vector2(r.randf_range(2.5, 4.0) * (1.0 if t[2] < 0.5 else -1.0), -r.randf_range(2.0, 3.5)), 1.0, vert)
		if la:
			var rc := 2.6 if herbier else r.randf_range(1.8, 2.4)
			var np := 9 if herbier else 5
			p.disque(bout, rc + 0.8, (rc + 0.8) * 0.82, ENCRE)
			for k in np:
				var a := TAU * k / np + float(t[2]) * 2.0
				var q := bout + Vector2(cos(a), sin(a) * 0.82) * rc * 0.55
				p.disque(q, rc * (0.38 if herbier else 0.55), rc * (0.3 if herbier else 0.48), couleur.lightened(0.08) if sin(a) < 0.0 else couleur.darkened(0.06))
			var coeur := P.BRAISE_COEUR.darkened(0.1) if couleur.v > 0.8 and couleur.s < 0.3 else P.ENCRE_DOUCE.lerp(P.BRAISE, 0.4)
			p.disque(bout, rc * 0.36, rc * 0.3, coeur, Pinceau.DOME)
		elif pousse >= 0.5 or not o.en_fleurs:
			# (des boutons, verts, qui reviendront)
			p.disque(bout, 1.2, 1.4, ENCRE)
			p.disque(bout, 0.8, 1.0, vert.lightened(0.15))
		else:
			# (coupée : la tige claire à la coupe)
			p.disque(bout, 0.6, 0.5, P.IVOIRE)


# des fleurs à bulbe : de longues feuilles en ruban qui retombent, une ou deux coupes de fleurs sur leurs hampes
static func _bulbes(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	for pied_i in r.randi_range(2, 3):
		var pied := Vector2(r.randf_range(-o._rx * 0.6, o._rx * 0.6), r.randf_range(-o._ry * 0.5, o._ry * 0.5))
		for i in 4:
			var cote := -1.0 if i % 2 == 0 else 1.0
			var h := r.randf_range(6.0, 10.0) * u
			var ligne := PackedVector2Array([pied, pied + Vector2(cote * 1.5, -h * 0.75), pied + Vector2(cote * r.randf_range(3.0, 5.0), -h)])
			p.tracer(ligne, 2.6, ENCRE, false, PackedFloat32Array([2.6, 2.2, 0.8]))
			p.tracer(ligne, 1.7, vert, false, PackedFloat32Array([1.8, 1.4, 0.3]))
		var hh := r.randf_range(11.0, 15.0) * u
		var bout := pied + Vector2(r.randf_range(-1.5, 1.5), -hh)
		p.tracer(PackedVector2Array([pied, bout]), 1.6, ENCRE, false)
		p.tracer(PackedVector2Array([pied, bout]), 0.9, vert.darkened(0.12), false)
		if la:
			# (la coupe : trois pétales, celui du milieu devant)
			var coupe := PackedVector2Array([bout + Vector2(-2.6, 0.5), bout + Vector2(-3.0, -3.0), bout + Vector2(-1.2, -2.0), bout + Vector2(0, -4.2),
				bout + Vector2(1.2, -2.0), bout + Vector2(3.0, -3.0), bout + Vector2(2.6, 0.5), bout + Vector2(0, 1.6)])
			p.aplat(_grossi(coupe, bout + Vector2(0, -1.2), 0.75), ENCRE)
			p.aplat(coupe, couleur, Pinceau.DOME, bout + Vector2(0, -1.4), Vector2(3.2, 3.2))
			p.tracer(PackedVector2Array([bout + Vector2(0, -4.0), bout + Vector2(0, 0.8)]), 0.6, Color(couleur.darkened(0.35), 0.8))
		else:
			p.disque(bout, 1.1, 1.6, ENCRE)
			p.disque(bout, 0.7, 1.1, vert.lightened(0.15))


# des orchidées : quelques larges feuilles au pied, une hampe arquée, des fleurs en lèvre le long
static func _orchidees(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	for i in 3:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a := Vector2(0, 0)
		var b := Vector2(cote * r.randf_range(6.0, 9.0), -r.randf_range(2.0, 4.0))
		_lance(p, a, b, 2.4, vert.lightened(0.05 * i))
	var hampe := PackedVector2Array()
	var sens := 1.0 if o.graine % 2 == 0 else -1.0
	for k in 7:
		var t := k / 6.0
		hampe.append(Vector2(sens * 7.0 * t * t, -16.0 * u * sin(t * PI * 0.6) / sin(PI * 0.6)))
	p.tracer(hampe, 1.5, ENCRE, false)
	p.tracer(hampe, 0.8, vert.darkened(0.2), false)
	for k in range(3, 7):
		var q := hampe[k] + Vector2(0, 1.5)
		if not la:
			p.disque(q, 1.0, 1.3, vert.lightened(0.1))
			continue
		for j in 3:
			var a := -PI * 0.5 + (j - 1) * 1.15
			var s := q + Vector2.from_angle(a) * 1.6
			p.disque(s, 1.5, 1.0, ENCRE)
			p.disque(s, 1.1, 0.7, couleur.lightened(0.12))
		p.disque(q + Vector2(0, 1.0), 1.6, 1.4, ENCRE)
		p.disque(q + Vector2(0, 1.0), 1.15, 1.0, couleur.darkened(0.2))
		p.disque(q + Vector2(0, 0.6), 0.4, 0.35, P.BRAISE_COEUR)


# une broméliacée : une rosette de feuilles raides, rouges au cœur, et l'épi rouge vif qui en sort
static func _bromelia(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	var c0 := Vector2(0, -2.0)
	var feuilles := []
	for i in 9:
		feuilles.append(lerpf(-PI + 0.2, -0.2, i / 8.0) + r.randf_range(-0.1, 0.1))
	feuilles.sort_custom(func(a, b): return sin(a) < sin(b))
	for a in feuilles:
		var bout := c0 + Vector2(cos(a) * 9.0, sin(a) * 7.0 * u)
		_lance(p, c0, bout, 1.8, vert.lerp(P.BRAISE_ROUGE, 0.12 if absf(cos(a)) < 0.5 else 0.0))
	if la:
		var rouge := couleur if couleur.r > couleur.g + 0.2 and couleur.r > couleur.b + 0.2 else P.BRAISE_ROUGE.lerp(P.BRAISE, 0.2)
		var epi := PackedVector2Array([c0 + Vector2(-2.0, 0), c0 + Vector2(-1.6, -7.0), c0 + Vector2(0, -11.0), c0 + Vector2(1.6, -7.0), c0 + Vector2(2.0, 0)])
		p.aplat(_grossi(epi, c0 + Vector2(0, -5.0), 0.7), ENCRE)
		p.aplat(epi, rouge, Pinceau.DOME, c0 + Vector2(0, -5.0), Vector2(2.2, 6.0))
		for k in 4:
			p.tracer(PackedVector2Array([c0 + Vector2(-1.6, -2.0 - k * 2.2), c0 + Vector2(1.6, -3.0 - k * 2.2)]), 0.5, Color(ENCRE, 0.5))


# -- l'eau : une mare, et ce qui y flotte --

static func _aquatique(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var eau := P.NUIT_BLEUE.lerp(P.FEUILLE_SOMBRE, 0.45).lerp(P.CENDRE, 0.2)
	var ciel := eau.lerp(P.LUNE, 0.4).lerp(P.PAPIER, 0.12)
	var vase := P.ENCRE_DOUCE.lerp(P.TERRE, 0.45)
	var rive: PackedVector2Array = o.festons(Vector2(0.5, 0.8), rx + 3.0, ry + 2.0, 6, 0.15, r, 30)
	p.aplat(rive, vase.darkened(0.15))
	var forme: PackedVector2Array = o.festons(Vector2.ZERO, rx, ry, r.randi_range(5, 7), 0.12, r, 30)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for q in forme:
		var v := clampf((q.y + ry) / (2.0 * ry), 0.0, 1.0)
		cols.append(ciel.lerp(eau, smoothstep(0.1, 0.7, v)))
		uvs.append(Vector2.ZERO)
	p.aplat_libre(forme, cols, uvs)
	p.contour(forme, 1.0, Color(ENCRE, 0.7), r, 3)
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.35)
	match str(o.forme):
		"lentille":
			# (une nappe de lentilles d'eau : des centaines de points verts, serrés vers les bords)
			for i in 110:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.92
				var q := Vector2(cos(a) * rx * d, sin(a) * ry * d)
				p.disque(q, r.randf_range(0.7, 1.2), r.randf_range(0.45, 0.75), t.lightened(r.randf_range(0.0, 0.25)))
		"algue":
			# (des filaments verts sous la surface, et des nattes qui flottent)
			for i in 7:
				var q := Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.5, 0.5) * ry)
				var ligne := PackedVector2Array()
				for k in 6:
					ligne.append(q + Vector2(k * 2.2, sin(k * 1.3 + i) * 1.2))
				p.tracer(ligne, 1.1, Color(t.lightened(0.1), 0.75), false)
			var nattes := 3 if o.reste > 0 else 1
			for i in nattes:
				var q := Vector2(r.randf_range(-0.5, 0.5) * rx, r.randf_range(-0.4, 0.4) * ry)
				var natte: PackedVector2Array = o.festons(q, r.randf_range(4.0, 6.0), r.randf_range(1.6, 2.4), 5, 0.3, r, 18)
				p.aplat(natte, t.lightened(0.12), Pinceau.FEUILLAGE, q, Vector2(6.0, 2.6))
				p.contour(natte, 0.7, Color(ENCRE, 0.6), r, 2)
		_:
			# (un nénuphar : des feuilles rondes, échancrées, posées à plat ; une fleur blanche ou rose)
			var feuilles := []
			for i in r.randi_range(3, 5):
				feuilles.append(Vector2(r.randf_range(-0.6, 0.6) * rx, r.randf_range(-0.45, 0.5) * ry))
			feuilles.sort_custom(func(a, b): return a.y < b.y)
			for q in feuilles:
				var s := r.randf_range(4.0, 5.6)
				var ang := r.randf() * TAU
				var poly := PackedVector2Array([q])
				for k in 15:
					var a := ang + 0.45 + (TAU - 0.9) * k / 14.0
					poly.append(q + Vector2(cos(a) * s, sin(a) * s * 0.48))
				p.aplat(_grossi(poly, q, 0.7), ENCRE)
				p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25)), Pinceau.FEUILLAGE, q, Vector2(s, s * 0.5) * 1.05)
				for k in 3:
					var a := ang + 0.45 + (TAU - 0.9) * (k + 1) / 4.0
					p.tracer(PackedVector2Array([q, q + Vector2(cos(a) * s * 0.8, sin(a) * s * 0.38)]), 0.5, Color(ENCRE, 0.35), false)
			if o.reste > 0 and o.en_fleurs:
				var q: Vector2 = feuilles[0] + Vector2(1.5, -1.5)
				var fleur := P.PAPIER.lightened(0.1) if o.graine % 3 != 0 else P.AUBE.lerp(P.PEUR, 0.15)
				for couche in 2:
					for k in 6:
						var a := TAU * k / 6.0 + couche * 0.5
						var pet := q + Vector2(cos(a) * 2.0, sin(a) * 0.9 - 1.6 - couche * 0.8)
						var bout := pet + Vector2(cos(a) * 1.6, -1.6)
						var poly := PackedVector2Array([q + Vector2(0, -0.6 - couche), pet + Vector2(-0.9, 0), bout, pet + Vector2(0.9, 0)])
						p.aplat(_grossi(poly, pet, 0.55), ENCRE)
						p.aplat(poly, fleur.darkened(0.08 * (1 - couche)))
				p.disque(q + Vector2(0, -2.4), 1.1, 0.8, P.BRAISE_COEUR)
	# (un reflet du ciel)
	p.tracer(PackedVector2Array([Vector2(-rx * 0.3, -ry * 0.55), Vector2(rx * 0.1, -ry * 0.55)]), 0.8, Color(P.PAPIER, 0.5))


# -- les champignons des bois : le cèpe (chapeau brun, pied ventru) et l'amanite (rouge piquée de blanc, son anneau, sa volve) --

static func _champignons_des_bois(o, p, r: RandomNumberGenerator, amanite: bool) -> void:
	# (un peu de litière dessous : quelques feuilles mortes)
	for i in 4:
		var q := Vector2(r.randf_range(-7.0, 7.0), r.randf_range(-0.5, 3.0))
		var d := Vector2.from_angle(r.randf() * TAU) * r.randf_range(1.8, 2.6)
		p.aplat(PackedVector2Array([q - d, q + d.orthogonal() * 0.5, q + d, q - d.orthogonal() * 0.5]), P.ECHARPE.lerp(P.TERRE, 0.45).darkened(r.randf_range(0.0, 0.25)))
	var n: int = 1 + o.graine % 3
	var pieds := []
	for i in n:
		pieds.append([Vector2((i - (n - 1) * 0.5) * 5.0 + r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.5)), r.randf_range(0.75, 1.0) * (0.7 if i == 1 else 1.0)])
	pieds.sort_custom(func(a, b): return a[0].y < b[0].y)
	var pale := P.IVOIRE.lerp(P.PAPIER, 0.45)
	for e in pieds:
		var q: Vector2 = e[0]
		var k: float = e[1]
		var h: float = o._ry * k
		var s: float = o._rx * k
		if o.reste <= 0:
			# (cueilli : le pied coupé, sa coupe claire)
			p.tracer(PackedVector2Array([q, q + Vector2(0, -2.2)]), 2.8, ENCRE, false)
			p.tracer(PackedVector2Array([q, q + Vector2(0, -2.2)]), 1.8, pale.darkened(0.15), false)
			p.disque(q + Vector2(0, -2.2), 1.1, 0.5, P.PAPIER)
			continue
		var penche := r.randf_range(-1.2, 1.2)
		var tete := q + Vector2(penche, -h)
		var larg_pied := s * (0.45 if not amanite else 0.3)
		# le pied : ventru pour le cèpe ; droit, avec un anneau et une volve, pour l'amanite
		var pied := PackedVector2Array([q + Vector2(-larg_pied * (1.25 if not amanite else 1.5), 0.5), q + Vector2(-larg_pied * (1.15 if not amanite else 0.8), -h * 0.35),
			tete + Vector2(-larg_pied * 0.7, 0), tete + Vector2(larg_pied * 0.7, 0), q + Vector2(larg_pied * (1.15 if not amanite else 0.8), -h * 0.35), q + Vector2(larg_pied * (1.25 if not amanite else 1.5), 0.5)])
		p.aplat(pied, pale if amanite else pale.lerp(P.TERRE, 0.12), Pinceau.ECORCE, q + Vector2(0, -h * 0.5), Vector2(larg_pied * 1.3, h * 0.6))
		p.contour(pied, 0.8, ENCRE, r, 2)
		if amanite:
			var anneau := q.lerp(tete, 0.72)
			p.tracer(PackedVector2Array([anneau + Vector2(-larg_pied - 1.0, 0.8), anneau + Vector2(0, 1.6), anneau + Vector2(larg_pied + 1.0, 0.8)]), 1.4, ENCRE, false)
			p.tracer(PackedVector2Array([anneau + Vector2(-larg_pied - 0.8, 0.5), anneau + Vector2(0, 1.2), anneau + Vector2(larg_pied + 0.8, 0.5)]), 0.8, P.PAPIER, false)
		else:
			# (le réseau fin sur le haut du pied)
			p.tracer(PackedVector2Array([q.lerp(tete, 0.55) + Vector2(-larg_pied * 0.6, 0), q.lerp(tete, 0.75) + Vector2(larg_pied * 0.5, 0)]), 0.5, Color(ENCRE, 0.3))
		# le chapeau : un dôme, plat dessous ; rouge et ses verrues blanches, ou brun bordé plus clair
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			cap.append(tete + Vector2(cos(a) * s, sin(a) * s * 0.8 + 0.6))
		cap.append(tete + Vector2(s * 0.75, 1.4))
		cap.append(tete + Vector2(-s * 0.75, 1.4))
		var teinte := P.BRAISE_ROUGE.lerp(P.SANG, 0.15).lightened(0.04) if amanite else P.TERRE.lerp(P.BRAISE, 0.32).darkened(0.08)
		p.aplat(_grossi(cap, tete + Vector2(0, -s * 0.3), 0.8), ENCRE)
		p.aplat(cap, teinte, Pinceau.DOME, tete + Vector2(0, -s * 0.35), Vector2(s, s * 0.75))
		if amanite:
			for i in 6:
				var v := tete + Vector2(r.randf_range(-0.7, 0.7) * s, -r.randf_range(0.2, 0.65) * s)
				p.disque(v, 0.75, 0.6, P.PAPIER.lightened(0.15))
		else:
			p.tracer(PackedVector2Array([tete + Vector2(-s * 0.9, 0.8), tete + Vector2(0, 1.6), tete + Vector2(s * 0.9, 0.8)]), 0.9, P.IVOIRE.lerp(P.BRAISE_COEUR, 0.3), false)
		p.disque(tete + Vector2(-s * 0.35, -s * 0.45), s * 0.22, s * 0.13, Color(1.0, 0.97, 0.9, 0.45))
