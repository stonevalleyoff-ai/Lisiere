extends RefCounted
# Lisière — les arbres de l'herbier, dessinés à l'encre (scripts/flore_arbres.gd)
# Chaque forme d'arbre de l'herbier d'Orvane (scripts/flore.gd), d'après sa planche : sa silhouette, ses proportions, sa hauteur.
# Le pionnier est un bouleau (un fût blanc taché d'encre, une couronne légère qui pleure) ; le fruitier, un arbre bas et rond,
# fourchu tôt ; le géant, un fût droit et massif sur ses contreforts, la couronne tout en haut ; l'émergent, une ombrelle plate
# au bout d'un long fût ; le figuier, un dais porté par ses racines tombées ; le baobab, une bouteille ridée coiffée de branches
# courtes ; le palmier, un fût annelé qui se courbe sous un bouquet de palmes ; la fougère arborescente, un fût noir et sa
# couronne de frondes ; le palétuvier, juché sur ses échasses au-dessus de la vase. L'arbre (le feuillu) et le conifère (le
# sapin) sont les premiers dessins : scripts/objet.gd.
# Tous ont la facture des premiers : le tronc en écorce, ses fibres et ses nœuds, des branches qui entrent dans la couronne, des
# touffes de feuillage peintes par le shader (chacune son ombre sur celles de derrière), le cerne plus lourd en bas à droite, la
# neige posée s'il fait froid. Et ce que les caractères d'Orvane y changent (scripts/flore_trait.gd) : des échasses, des racines
# qui empoignent le sol, un port couché par le vent, des pousses tendres, un feuillage coriace qui luit, des grappes de graines,
# des fleurs à miel, un pied noirci par les feux.
# Les mesures sont à l'échelle de l'herbier (scripts/monde.gd, HAUTEURS) : un pionnier de 9 m fait 77 pixels, un géant de 45 m, 147.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const T := preload("res://scripts/flore_trait.gd")
const Flore := preload("res://scripts/flore.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)


# --- ce que la forme change à sa conduite ---

static func regler(o) -> void:
	if str(o.genre) == "arbre" or str(o.genre) == "sapin":
		o.epaisseur = 1.0
	match str(o.forme):
		"pionnier":
			o.epaisseur = 0.7
			# (un bouleau : l'écorce blanche)
			o.ecorce_teinte = P.PAPIER.lerp(P.IVOIRE, 0.45).darkened(0.04)
		"fruitier":
			o.epaisseur = 0.95
		"geant":
			o.epaisseur = 1.5
			o.ecorce_teinte = P.TERRE.lerp(P.ENCRE_DOUCE, 0.3).lerp(P.BRAISE_ROUGE, 0.12)
		"emergent":
			o.epaisseur = 1.1
			o.ecorce_teinte = P.CENDRE.lerp(P.TERRE, 0.45).lightened(0.05)
		"figuier":
			o.epaisseur = 1.3
			o.ecorce_teinte = P.CENDRE.lerp(P.IVOIRE, 0.42)
		"bouteille":
			o.epaisseur = 2.1
			o.ecorce_teinte = P.CENDRE.lerp(P.IVOIRE, 0.38).lerp(P.TERRE, 0.22).lerp(P.PEUR, 0.05)
		"sous_bois":
			o.epaisseur = 0.66
			o.ecorce_teinte = P.TERRE.lerp(P.ENCRE_DOUCE, 0.5).lerp(P.MOUSSE, 0.1)
		"palmier":
			o.epaisseur = 0.74
			o.ecorce_teinte = P.TERRE.lerp(P.IVOIRE, 0.36).lerp(P.CENDRE, 0.2)
		"fougere_arbre":
			o.epaisseur = 0.78
			o.ecorce_teinte = P.ENCRE_DOUCE.lerp(P.TERRE, 0.5)
		"paletuvier":
			o.epaisseur = 0.85
			o.ecorce_teinte = P.TERRE.lerp(P.CENDRE, 0.4)
	# (une géante de sa forme : le fût plus fort)
	if T.a(o, "geante"):
		o.epaisseur *= 1.14


# là où l'on bute : le pied du tronc, et ce qui le tient (après la mesure et l'échelle)
static func ajuster(o) -> void:
	if str(o.genre) != "arbre" and str(o.genre) != "sapin":
		return
	var base: float = o._demi_largeur(-3.0)
	match str(o.forme):
		"paletuvier":
			base = maxf(base, 12.0)
		"geant", "emergent":
			base += 3.0
	o.rayon = clampf(base + 3.5, 11.0, 22.0)


# --- la taille, d'après la forme (les mesures de son dessin, à sa hauteur d'herbier) ---

static func mesurer(o, r: RandomNumberGenerator, f: String) -> void:
	var ht := 0.0
	var rx := 0.0
	var ry := 0.0
	match f:
		"arbre", "":
			# (le feuillu d'objet.gd garde ses mesures ; son port, lui, suit ses caractères)
			_porter(o)
			return
		"pionnier":
			# (9 m : 72 pixels, à l'échelle des autres — un arbre de 12 m en fait 81 : un pionnier reste plus petit que lui)
			ht = r.randf_range(27.5, 33.0)
			rx = r.randf_range(20.5, 24.5)
			ry = rx * r.randf_range(0.98, 1.1)
		"fruitier":
			# (6 m : 65 pixels ; bas, rond)
			ht = r.randf_range(21.0, 26.0)
			rx = r.randf_range(24.0, 29.0)
			ry = rx * r.randf_range(0.8, 0.88)
		"geant":
			# (45 m : 150 pixels ; un long fût, la couronne tout en haut — plus de trois fois la veilleuse —, large, en chou-fleur :
			# elle domine les autres de haut et de large)
			ht = r.randf_range(87.0, 98.0)
			rx = r.randf_range(38.0, 44.0)
			ry = rx * r.randf_range(0.7, 0.77)
		"emergent":
			# (45 m : une ombrelle plate au bout d'un fût nu)
			ht = r.randf_range(112.0, 126.0)
			rx = r.randf_range(40.0, 46.0)
			ry = rx * r.randf_range(0.36, 0.42)
		"figuier":
			# (20 m : 104 pixels ; plus large que haut)
			ht = r.randf_range(34.0, 40.0)
			rx = r.randf_range(46.0, 54.0)
			ry = rx * r.randf_range(0.7, 0.78)
		"sous_bois":
			# (5 m : 60 pixels ; grêle, sombre)
			ht = r.randf_range(18.0, 23.0)
			rx = r.randf_range(19.0, 23.0)
			ry = rx * r.randf_range(0.98, 1.1)
		"bouteille":
			# (20 m : 104 pixels ; le fût en fait plus de la moitié)
			ht = r.randf_range(52.0, 60.0)
			rx = r.randf_range(35.0, 41.0)
			ry = rx * r.randf_range(0.62, 0.72)
		"paletuvier":
			# (6 m : 65 pixels, échasses comprises)
			ht = r.randf_range(26.0, 31.0)
			rx = r.randf_range(27.0, 32.0)
			ry = rx * r.randf_range(0.66, 0.74)
		"palmier", "fougere_arbre":
			# (un fût, et les palmes en haut : le centre du feuillage est au sommet du fût ; 15 m : 94 pixels ; 8 m : 73)
			var palmier := f == "palmier"
			ht = r.randf_range(72.0, 84.0) if palmier else r.randf_range(52.0, 62.0)
			rx = r.randf_range(38.0, 44.0) if palmier else r.randf_range(31.0, 36.0)
			ry = r.randf_range(15.0, 18.0) if palmier else r.randf_range(14.0, 17.0)
			o._ht = ht
			o._rx = rx
			o._ry = ry
			o._penche = r.randf_range(0.08, 0.17) * (1.0 if o.graine % 2 == 0 else -1.0)
			if T.a(o, "vent"):
				o._penche = absf(o._penche) + 0.03
			o._cc = Vector2(courbe_palme(o, -ht), -ht)
			o.hauteur = ht + ry
			o.couronne_rect = Rect2(o._cc - Vector2(rx, ry * 0.9), Vector2(rx * 2.0, ry * 2.1))
			return
		_:
			_porter(o)
			return
	if T.a(o, "naine"):
		# (une naine se tasse : plus basse, plus large)
		ht *= 0.84
		rx *= 1.07
		ry *= 0.96
	o._ht = ht
	o._rx = rx
	o._ry = ry
	o._penche = r.randf_range(-0.06, 0.06)
	o._cc = Vector2(o._penche * (ht + ry * 0.8) + r.randf_range(-2.0, 2.0), -(ht + ry * 0.8))
	_porter(o)
	o.hauteur = -o._cc.y + ry
	o.couronne_rect = Rect2(o._cc - Vector2(rx, ry), Vector2(rx, ry) * 2.0)


# le port, d'après ses caractères : le vent la couche vers l'est (le vent du lieu vient de l'ouest), sa cime tirée de ce côté
static func _porter(o) -> void:
	if str(o.genre) != "arbre" or not T.a(o, "vent"):
		return
	var penche: float = absf(o._penche) * 0.5 + 0.055
	var haut: float = -o._cc.y
	o._cc.x += (penche - o._penche) * haut + o._rx * 0.06
	o._penche = penche
	o.couronne_rect = Rect2(o._cc - Vector2(o._rx, o._ry), Vector2(o._rx, o._ry) * 2.0)


# l'axe d'un fût de palmier, qui se courbe vers le haut (à la hauteur y, négative)
static func courbe_palme(o, y: float) -> float:
	var u := clampf((-y - 8.5) / maxf(1.0, o._ht - 8.5), 0.0, 1.0)
	return o._axe(-8.5) + o._penche * 78.0 * u * u


# --- les ombres ([] : aucune ; null : celles de son genre) ---

static func ombres(o):
	var ep: float = o.epaisseur
	var contact := [Vector2(1, 1), Vector2(10.0 + 5.0 * ep, 4.0 + 1.8 * ep), 0.45, 0.0, 0.0]
	match str(o.forme):
		"paletuvier":
			contact = [Vector2(0.5, 1.5), Vector2(22.0, 6.5), 0.4, 0.0, 0.0]
		"geant", "emergent":
			contact = [Vector2(1, 1.5), Vector2(14.0 + 6.0 * ep, 5.0 + 2.2 * ep), 0.45, 0.0, 0.0]
		"palmier", "fougere_arbre":
			return [[Vector2(1, 1), Vector2(10.0, 4.0), 0.42, 0.0, 0.0], [Vector2(o._cc.x * 0.4 + 3.0, 3.0), Vector2(o._rx * 0.88, o._rx * 0.36), 0.26, 1.0, o.hauteur * 0.8]]
		"arbre", "":
			return null
	return [contact, [Vector2(o._cc.x + 3.0, 3.0), Vector2(o._rx * 1.02, o._ry * 0.46), 0.3, 1.0, o.hauteur * 0.75]]


# --- le pied : ses racines, le bas de son tronc ---

# d'où part le bas du tronc (au-dessus du sol : il est juché sur ses échasses)
static func pied_du_tronc(o) -> float:
	if str(o.forme) == "paletuvier":
		return -5.5
	if T.a(o, "echasses") and str(o._espece) == "arbre":
		return -3.0
	return 0.5


# les racines d'une forme à elle (faux : celles de tous les arbres, scripts/objet.gd, _racines)
static func racines(o, p, r: RandomNumberGenerator, _souche: bool) -> bool:
	var c: Color = o._ecorce()
	match str(o.forme):
		"paletuvier":
			_vase(o, p, r)
			_echasses(o, p, r, c, r.randi_range(7, 9), 21.0, 15.0, -5.5)
			return true
		"geant", "emergent":
			_contreforts(o, p, r, c)
			return true
		"palmier":
			_pied_de_palmier(o, p, r, c)
			return true
		"fougere_arbre":
			_pied_de_fougere(o, p, r, c)
			return true
	if T.a(o, "echasses") and str(o._espece) == "arbre":
		# (un arbre qu'Orvane dit sur échasses : quelques racines arquées le tiennent au-dessus du sol)
		_echasses(o, p, r, c, r.randi_range(4, 5), 8.0 + 6.0 * o.epaisseur, 9.0, -3.0)
		return true
	return false


# ce que l'écorce porte au pied (sous la coupe : la souche le garde) : les taches d'un bouleau, les fissures d'un géant, le noir
# des feux passés
static func ecorce_du_pied(o, p, r: RandomNumberGenerator) -> void:
	match str(o.forme):
		"pionnier":
			# (le pied d'un vieux bouleau : noir, crevassé)
			for i in 4:
				var y := -r.randf_range(0.5, 6.0)
				var x: float = o._axe(y) + o._demi_largeur(y) * r.randf_range(-0.8, 0.7)
				p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + r.randf_range(-0.6, 0.6), y - r.randf_range(1.5, 3.5))]), r.randf_range(1.0, 1.8), Color(ENCRE, 0.85))
			lenticelles(o, p, r, -5.0, -9.0)
		"geant", "emergent":
			# (le contrefort de devant : une arête qui descend du fût et s'évase vers nous)
			var x0: float = o._axe(-4.0) + r.randf_range(-1.5, 1.5)
			var w: float = o._demi_largeur(0.0)
			var c: Color = o._ecorce()
			var arete := PackedVector2Array([Vector2(x0 - 0.6, -9.0), Vector2(x0 - w * 0.34, 3.2), Vector2(x0 + w * 0.1, 4.6), Vector2(x0 + w * 0.42, 3.4), Vector2(x0 + 0.8, -9.0)])
			p.aplat(arete, c.lightened(0.06), Pinceau.ECORCE, Vector2(x0, -3.0), Vector2(w * 0.5, 8.0))
			p.tracer(PackedVector2Array([arete[0], arete[1], arete[2]]), 0.8, Color(ENCRE, 0.7), false)
			p.tracer(PackedVector2Array([arete[4], arete[3], arete[2]]), 1.3, ENCRE, false)
			fissures(o, p, r, 0.0, -9.0, 4)
		"bouteille":
			# (la peau d'un baobab plisse à son pied)
			for i in 3:
				var y := -r.randf_range(1.0, 7.5)
				var w: float = o._demi_largeur(y)
				var x: float = o._axe(y) + w * r.randf_range(-0.5, 0.3)
				p.tracer(PackedVector2Array([Vector2(x - w * 0.3, y - 0.6), Vector2(x, y + 0.5), Vector2(x + w * 0.35, y - 0.4)]), 0.7, Color(ENCRE, 0.45))
		"palmier":
			# (les anneaux descendent jusqu'au pied)
			for y in [-3.0, -6.2]:
				var w: float = o._demi_largeur(y)
				var x: float = o._axe(y)
				p.tracer(PackedVector2Array([Vector2(x - w, y - 0.5), Vector2(x, y + 0.9), Vector2(x + w, y - 0.5)]), 0.8, Color(ENCRE, 0.6), false)
		"fougere_arbre":
			ecailles(o, p, r, -1.0, -9.0)
	if T.a(o, "pyrophyte"):
		# (une écorce épaisse, noircie par les feux passés : elle les a traversés)
		var w: float = o._demi_largeur(-3.0)
		for i in 5:
			var x: float = o._axe(-3.0) + w * lerpf(-0.9, 0.9, (i + r.randf()) / 5.0)
			var h := r.randf_range(4.0, 8.5)
			p.tracer(PackedVector2Array([Vector2(x, 0.5), Vector2(x + r.randf_range(-0.8, 0.8), -h)]), 2.6, Color(P.ENCRE, 0.6), false, PackedFloat32Array([3.0, 0.5]))


# la vase sous un palétuvier : une flaque sombre, son liseré, et les racines qui en pointent pour respirer
static func _vase(o, p, r: RandomNumberGenerator) -> void:
	var boue := P.ENCRE_DOUCE.lerp(P.TERRE, 0.42)
	var flaque: PackedVector2Array = o.festons(Vector2(0.5, 1.8), 25.0, 6.2, 7, 0.14, r, 30)
	p.aplat(flaque, Color(boue.darkened(0.15), 0.78))
	p.tracer(PackedVector2Array([Vector2(-17.0, -0.4), Vector2(-9.0, -0.9), Vector2(-3.0, -0.5)]), 0.6, Color(P.PAPIER, 0.32))
	p.tracer(PackedVector2Array([Vector2(8.0, 3.6), Vector2(15.0, 3.2)]), 0.6, Color(P.PAPIER, 0.26))
	for i in r.randi_range(6, 9):
		var a := r.randf() * TAU
		var d := r.randf_range(0.55, 1.0)
		var q := Vector2(cos(a) * 24.0 * d + 0.5, 1.8 + sin(a) * 5.4 * d)
		var h := r.randf_range(2.2, 4.6)
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-0.4, 0.4), -h)]), 1.5, ENCRE, false, PackedFloat32Array([1.6, 0.7]))
		p.tracer(PackedVector2Array([q, q + Vector2(0.0, -h + 0.5)]), 0.7, boue.lightened(0.22), false, PackedFloat32Array([0.8, 0.3]))


# des racines-échasses : n arcs qui partent du bas du tronc et se plantent autour, celles du fond d'abord ; chacune a son
# côté du jour, et celles de devant se ramifient avant de toucher le sol
static func _echasses(o, p, r: RandomNumberGenerator, c: Color, n: int, portee: float, haut: float, bas: float) -> void:
	var racines := []
	for i in n:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var loin := r.randf_range(0.42, 1.0)
		var y0 := bas - r.randf_range(0.5, haut - 4.0)
		var depart := Vector2(o._axe(y0) + cote * o._demi_largeur(y0) * r.randf_range(0.3, 0.85), y0)
		var bout := Vector2(o._axe(0.0) + cote * portee * loin, r.randf_range(-1.2, 3.4))
		var epaule := Vector2(lerpf(depart.x, bout.x, r.randf_range(0.55, 0.8)), depart.y - r.randf_range(1.0, 4.5) * loin)
		racines.append([depart, epaule, bout, bout.y, r.randf(), cote])
	racines.sort_custom(func(u, v): return u[3] < v[3])
	var rang := 0
	for x in racines:
		var ligne := T.courbe(x[0], x[1], x[2], 7)
		var devant := float(x[3]) > 0.8
		var ton: Color = c.lightened(0.04 + 0.1 * float(x[4])) if devant else c.darkened(0.16)
		var gros: float = 3.3 * (0.75 + 0.3 * o.epaisseur)
		var larg_e := PackedFloat32Array()
		var larg_c := PackedFloat32Array()
		var haut_l := PackedVector2Array()
		for k in ligne.size():
			var u := float(k) / (ligne.size() - 1)
			larg_e.append(lerpf(gros, gros * 0.5, u) + 1.1)
			larg_c.append(lerpf(gros, gros * 0.5, u))
			haut_l.append(ligne[k] + Vector2(-0.35, -lerpf(gros, gros * 0.5, u) * 0.24))
		p.tracer(ligne, gros, ENCRE, false, larg_e)
		p.tracer(ligne, gros, ton, false, larg_c)
		# (le dessus de l'arc prend le jour)
		p.tracer(haut_l, 0.6, Color(ton.lightened(0.3), 0.75 if devant else 0.4), true)
		if devant and rang % 2 == 0:
			# (elle se dédouble avant le sol)
			var q: Vector2 = ligne[4]
			var bout2: Vector2 = x[2] + Vector2(-float(x[5]) * r.randf_range(3.0, 5.5), r.randf_range(-0.6, 1.0))
			var f := T.courbe(q, (q + bout2) * 0.5 + Vector2(0.0, -1.0), bout2, 4)
			p.tracer(f, 2.2, ENCRE, false, PackedFloat32Array([2.6, 2.4, 2.2, 2.0, 1.7]))
			p.tracer(f, 1.2, ton.darkened(0.05), false, PackedFloat32Array([1.5, 1.4, 1.2, 1.0, 0.8]))
		# (là où elle entre en terre)
		p.disque(x[2] + Vector2(0.2, 0.7), 2.1, 0.8, Color(P.ENCRE, 0.32))
		rang += 1


# les contreforts d'un géant : des ailes d'écorce qui descendent du fût et s'évasent sur le sol, de chaque côté
static func _contreforts(o, p, r: RandomNumberGenerator, c: Color) -> void:
	var w0: float = o._demi_largeur(0.0)
	var profondes := T.a(o, "racines_profondes")
	for cote in [-1.0, 1.0]:
		for rang in (3 if profondes else 2):
			var haut := r.randf_range(15.0, 24.0) * (1.0 - 0.3 * rang)
			var loin: float = w0 * r.randf_range(1.5, 2.0) + 4.5 * rang + (3.0 if profondes else 0.0)
			var y_sol := r.randf_range(0.5, 3.0) - 1.6 * rang
			var sommet := Vector2(o._axe(-haut) + cote * o._demi_largeur(-haut) * 0.86, -haut)
			var pied := Vector2(o._axe(0.0) + cote * loin, y_sol)
			var creux := Vector2(lerpf(sommet.x, pied.x, 0.3), lerpf(sommet.y, pied.y, 0.82))
			var arete := T.courbe(sommet, creux, pied, 6)
			var poly := PackedVector2Array(arete)
			poly.append(Vector2(o._axe(0.0) + cote * w0 * 0.3, y_sol + 1.4))
			poly.append(Vector2(o._axe(-haut * 0.5), -haut * 0.5))
			var ton := c.darkened(0.1 * rang + (0.0 if cote < 0.0 else 0.12))
			p.aplat(poly, ton, Pinceau.ECORCE, Vector2(o._axe(0.0) + cote * loin * 0.5, -haut * 0.3), Vector2(loin * 0.62, haut * 0.7))
			p.tracer(arete, 1.1 if cote < 0.0 else 1.7, ENCRE, false)
			# (un pli d'écorce le long de l'aile)
			var pli := PackedVector2Array()
			for k in range(1, 6):
				pli.append(arete[k].lerp(Vector2(o._axe(0.0), arete[k].y), 0.42))
			p.tracer(pli, 0.6, Color(ENCRE, 0.42))
	# (deux racines qui courent encore sur le sol, au-delà)
	for i in 2:
		var cote := -1.0 if i == 0 else 1.0
		var depart := Vector2(o._axe(0.0) + cote * w0 * 1.5, r.randf_range(1.5, 3.5))
		var bout := depart + Vector2(cote * r.randf_range(8.0, 15.0), r.randf_range(0.5, 3.0))
		var ligne := T.courbe(depart, (depart + bout) * 0.5 + Vector2(0.0, -1.6), bout, 5)
		p.tracer(ligne, 2.6, ENCRE, false, PackedFloat32Array([3.4, 3.0, 2.6, 2.2, 1.7, 1.0]))
		p.tracer(ligne, 1.6, c.darkened(0.06), false, PackedFloat32Array([2.2, 1.9, 1.6, 1.3, 0.9, 0.4]))


# le pied d'un palmier : un bulbe de racines fines, serrées, qui soulève un peu le fût
static func _pied_de_palmier(o, p, r: RandomNumberGenerator, c: Color) -> void:
	var w: float = o._demi_largeur(0.0)
	var x: float = o._axe(0.0)
	var bulbe := PackedVector2Array()
	for i in 11:
		var ang := PI * i / 10.0
		bulbe.append(Vector2(x + cos(ang) * (w + 3.4), 0.8 + sin(ang) * 3.0))
	bulbe.append(Vector2(x - w * 0.9, -4.5))
	bulbe.append(Vector2(x + w * 0.9, -4.5))
	p.aplat(bulbe, c.darkened(0.22), Pinceau.ECORCE, Vector2(x, 0.0), Vector2(w + 3.4, 5.0))
	p.contour(bulbe, 1.1, ENCRE, r, 2)
	for i in 9:
		var u := (i + r.randf_range(0.2, 0.8)) / 9.0
		var q := Vector2(x + lerpf(-w - 2.8, w + 2.8, u), 1.2 + sin(u * PI) * 2.2)
		p.tracer(PackedVector2Array([Vector2(lerpf(q.x, x, 0.3), -2.6), q]), 0.7, Color(ENCRE, 0.55), false)


# le pied d'une fougère arborescente : un manchon de racines noires, plus large que le fût
static func _pied_de_fougere(o, p, r: RandomNumberGenerator, c: Color) -> void:
	var w: float = o._demi_largeur(0.0)
	var x: float = o._axe(0.0)
	var jupe := PackedVector2Array([Vector2(x - w - 4.5, 1.6), Vector2(x - w - 1.5, -3.0), Vector2(x - w * 0.9, -8.0), Vector2(x + w * 0.9, -8.0), Vector2(x + w + 1.5, -3.0), Vector2(x + w + 4.5, 1.6), Vector2(x, 3.0)])
	p.aplat(jupe, c.darkened(0.2), Pinceau.ECORCE, Vector2(x, -2.0), Vector2(w + 4.5, 7.0))
	p.contour(jupe, 1.1, ENCRE, r, 2)
	for i in 8:
		var u := (i + r.randf_range(0.15, 0.85)) / 8.0
		var haut := Vector2(x + lerpf(-w, w, u), -r.randf_range(4.0, 7.5))
		p.tracer(PackedVector2Array([haut, Vector2(x + lerpf(-w - 4.0, w + 4.0, u), 1.5 + sin(u * PI) * 1.2)]), 0.7, Color(ENCRE, 0.6))


# --- l'écorce : ses marques ---

# des fibres d'écorce le long d'un tronc, entre deux hauteurs ; et parfois un nœud
static func fibres(o, p, r: RandomNumberGenerator, y0: float, y1: float, n: int, noeud := true) -> void:
	for i in n:
		var y := r.randf_range(y1, y0)
		var x: float = o._axe(y) + o._demi_largeur(y) * r.randf_range(-0.45, 0.6)
		p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + 0.3, y - r.randf_range(4.0, 8.0))]), 0.7, Color(ENCRE, 0.5))
	if noeud and y0 - y1 > 12.0 and r.randf() < 0.7:
		var y := r.randf_range(y1 + 4.0, y0 - 3.0)
		var c: Color = o._ecorce()
		var nd := Vector2(o._axe(y) + r.randf_range(-1.0, 1.5), y)
		p.disque(nd, 1.5, 1.1, c.darkened(0.5))
		p.tracer(PackedVector2Array([nd + Vector2(-1.6, -0.6), nd + Vector2(0, -1.6), nd + Vector2(1.6, -0.4)]), 0.6, c.lightened(0.25), false)


# de longues fissures qui suivent un vieux fût, plus noires du côté de l'ombre ; des arêtes claires du côté du jour
static func fissures(o, p, r: RandomNumberGenerator, y0: float, y1: float, n: int) -> void:
	var c: Color = o._ecorce()
	for i in n:
		var s := r.randf_range(-0.8, 0.85)
		var depart := r.randf_range(y1 + 6.0, y0)
		var l := r.randf_range(9.0, 24.0)
		var ligne := PackedVector2Array()
		for k in 5:
			var y := depart - l * k / 4.0
			if y < y1:
				break
			ligne.append(Vector2(o._axe(y) + o._demi_largeur(y) * s + sin(k * 1.9 + i) * 0.55, y))
		if ligne.size() < 2:
			continue
		p.tracer(ligne, 0.8, Color(ENCRE, 0.42 if s < 0.1 else 0.68))
		if s < -0.1:
			var clair := PackedVector2Array()
			for q in ligne:
				clair.append(q + Vector2(-0.8, 0.0))
			p.tracer(clair, 0.55, Color(c.lightened(0.32), 0.5))


# les taches d'encre d'un fût de bouleau, en travers ; et, plus haut, l'œil noir d'une branche tombée
static func lenticelles(o, p, r: RandomNumberGenerator, y0: float, y1: float) -> void:
	var y := y0 - r.randf_range(1.0, 3.0)
	var rang := 0
	while y > y1:
		var w: float = o._demi_largeur(y)
		var x: float = o._axe(y)
		var a0 := x - w * r.randf_range(0.2, 0.9)
		var b0 := a0 + w * r.randf_range(0.5, 1.1)
		p.tracer(PackedVector2Array([Vector2(a0, y), Vector2(b0, y + r.randf_range(-0.4, 0.4))]), r.randf_range(0.8, 1.4), Color(ENCRE, 0.8))
		if rang % 4 == 2 and y0 - y1 > 20.0:
			# (un œil : la cicatrice en chevron d'une branche)
			var q := Vector2(x + w * r.randf_range(-0.3, 0.4), y - 2.0)
			p.tracer(PackedVector2Array([q + Vector2(-2.2, 1.6), q + Vector2(0.0, -0.8), q + Vector2(2.2, 1.6)]), 1.3, Color(ENCRE, 0.85))
			p.disque(q + Vector2(0.0, 0.6), 0.8, 0.6, Color(ENCRE, 0.9))
		y -= r.randf_range(3.0, 6.0)
		rang += 1


# les écailles d'un fût de fougère arborescente : les bases des frondes tombées, en losanges serrés
static func ecailles(o, p, r: RandomNumberGenerator, y0: float, y1: float) -> void:
	var c: Color = o._ecorce()
	var y := y0
	var rang := 0
	while y > y1:
		var w: float = _demi_fut(o, y)
		var x: float = _axe_fut(o, y)
		for k in 3:
			var s := (k - 1) * 0.62 + (0.31 if rang % 2 == 0 else 0.0)
			if absf(s) > 0.95:
				continue
			var q := Vector2(x + w * s, y)
			p.tracer(PackedVector2Array([q + Vector2(-1.3, -0.9), q + Vector2(0.0, 0.9), q + Vector2(1.3, -0.9)]), 0.7, Color(ENCRE, 0.62), false)
			if s < 0.0:
				p.disque(q + Vector2(-0.2, -0.9), 0.5, 0.4, Color(c.lightened(0.35), 0.5))
		y -= r.randf_range(2.6, 3.4)
		rang += 1


# l'axe et la demi-largeur du fût d'un palmier ou d'une fougère arborescente (il se courbe : courbe_palme)
static func _axe_fut(o, y: float) -> float:
	return courbe_palme(o, y) if y < -8.5 else o._axe(y)


static func _demi_fut(o, y: float) -> float:
	if y >= -8.5:
		return o._demi_largeur(y)
	var u := clampf((-y - 8.5) / maxf(1.0, o._ht - 8.5), 0.0, 1.0)
	return o._demi_largeur(-8.5) * lerpf(1.0, 0.8, u)


# --- les branches ---

# une branche : un trait d'écorce qui s'affine, cerné d'encre, son dessus éclairé
static func branche(p, ligne: PackedVector2Array, gros: float, fin: float, c: Color) -> void:
	var n := ligne.size()
	var larg_e := PackedFloat32Array()
	var larg_c := PackedFloat32Array()
	var clair := PackedVector2Array()
	for k in n:
		var u := float(k) / maxf(1.0, n - 1)
		var w := lerpf(gros, fin, u)
		larg_e.append(w + 1.2)
		larg_c.append(w)
		var t := (ligne[mini(k + 1, n - 1)] - ligne[maxi(k - 1, 0)]).normalized()
		var nrm := t.orthogonal()
		if nrm.dot(T.JOUR) < 0.0:
			nrm = -nrm
		clair.append(ligne[k] + nrm * w * 0.26)
	p.tracer(ligne, gros, ENCRE, false, larg_e)
	p.tracer(ligne, gros, c, false, larg_c)
	if gros >= 2.0:
		p.tracer(clair, 0.6, Color(c.lightened(0.3), 0.6))


# --- la couronne (le haut de l'arbre, sur son propre nœud) ---

static func couronne(o, p, r: RandomNumberGenerator) -> bool:
	var f := str(o.forme)
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.18)))
	var lobes := []
	match f:
		"pionnier":
			# (un bouleau : un fût blanc taché d'encre, une couronne légère en quatre touffes, plus claire, d'où pendent de
			# fins rameaux)
			var haut := cc.y + ry * 0.5
			lobes = [[cc + Vector2(0, ry * 0.26), rx * 0.92, ry * 0.62], [cc + Vector2(-rx * 0.36, -ry * 0.22), rx * 0.66, ry * 0.54],
				[cc + Vector2(rx * 0.4, -ry * 0.1), rx * 0.62, ry * 0.52], [cc + Vector2(rx * r.randf_range(-0.1, 0.16), -ry * 0.56), rx * 0.52, ry * 0.44]]
			var clair := t.lightened(0.1).lerp(P.BRAISE_COEUR, 0.07)
			o._tronc(p, -8.5, haut, o._ecorce())
			lenticelles(o, p, r, -9.0, haut + 4.0)
			_rameaux_pleureurs(o, p, r, lobes, clair)
			houppier(o, p, r, lobes, haut, clair, true)
		"fruitier":
			# (bas, rond, fourchu tôt : trois charpentières qu'on voit sous le feuillage ; ses fruits, ronds et luisants, sont
			# posés sur lui ensuite : scripts/flore_dessins.gd, fruits_couronne)
			var haut := cc.y + ry * 0.62
			lobes = [[cc + Vector2(0, ry * 0.1), rx, ry * 0.9], [cc + Vector2(-rx * 0.34, -ry * 0.36), rx * 0.6, ry * 0.56],
				[cc + Vector2(rx * 0.36, -ry * 0.3), rx * 0.56, ry * 0.52]]
			o._tronc(p, -8.5, haut, o._ecorce())
			fibres(o, p, r, -10.0, haut + 3.0, 2)
			_ecailles_d_ecorce(o, p, r, -10.0, haut + 2.0)
			houppier(o, p, r, lobes, haut, t, true, 3)
		"geant":
			_geant(o, p, r, t)
		"emergent":
			# (au-dessus des autres : un long fût nu, une ombrelle plate)
			var haut := cc.y + ry * 0.5
			lobes = [[cc + Vector2(-rx * 0.48, ry * 0.05), rx * 0.58, ry * 0.85], [cc + Vector2(rx * 0.48, ry * 0.1), rx * 0.56, ry * 0.8],
				[cc + Vector2(0, -ry * 0.28), rx * 0.6, ry * 0.8]]
			o._tronc(p, -8.5, haut, o._ecorce())
			fissures(o, p, r, -10.0, haut + 6.0, 5)
			houppier(o, p, r, lobes, haut, t, true, 4)
		"figuier":
			_figuier(o, p, r, t)
		"sous_bois":
			# (un petit arbre d'ombre : deux ou trois brins grêles, un feuillage sombre en étages)
			var haut := cc.y + ry * 0.55
			var sombre := t.lerp(P.FEUILLE_SOMBRE, 0.3)
			lobes = [[cc + Vector2(rx * 0.1, ry * 0.42), rx * 0.95, ry * 0.4], [cc + Vector2(-rx * 0.16, -ry * 0.02), rx * 0.8, ry * 0.4],
				[cc + Vector2(rx * 0.1, -ry * 0.48), rx * 0.58, ry * 0.4]]
			o._tronc(p, -8.5, haut, o._ecorce())
			var c: Color = o._ecorce()
			for cote in [-1.0, 1.0]:
				if cote > 0.0 and o.graine % 3 == 0:
					continue
				var a0 := Vector2(o._axe(-9.0) + cote * 2.4, -8.6)
				var b0: Vector2 = cc + Vector2(cote * rx * r.randf_range(0.4, 0.62), ry * r.randf_range(0.2, 0.45))
				branche(p, T.courbe(a0, Vector2(a0.x + cote * 3.0, lerpf(a0.y, b0.y, 0.6)), b0, 6), 2.2, 1.2, c)
			houppier(o, p, r, lobes, haut, sombre, true, 2)
		"paletuvier":
			# (un feuillage dense, coriace, qui luit ; ses fruits en cigares pendent dessous)
			var haut := cc.y + ry * 0.5
			var dense := t.lerp(P.FEUILLE_SOMBRE, 0.2)
			lobes = [[cc + Vector2(-rx * 0.4, ry * 0.12), rx * 0.66, ry * 0.7], [cc + Vector2(rx * 0.42, ry * 0.16), rx * 0.64, ry * 0.68],
				[cc + Vector2(rx * r.randf_range(-0.08, 0.08), -ry * 0.26), rx * 0.62, ry * 0.66]]
			o._tronc(p, -8.5, haut, o._ecorce())
			fibres(o, p, r, -10.0, haut + 3.0, 3)
			_propagules(o, p, r, lobes)
			houppier(o, p, r, lobes, haut, dense, true, 3)
			_luisant(p, r, lobes, 3)
		"bouteille":
			_baobab(o, p, r, t)
		"palmier":
			_palmier(o, p, r, t, false)
		"fougere_arbre":
			_palmier(o, p, r, t, true)
		_:
			return false
	if not lobes.is_empty():
		caracteres_de_couronne(o, p, lobes, t)
	return true


# un feuillu en plusieurs touffes : (le tronc jusqu'à haut,) une branche vers chaque touffe, puis les touffes, celles du fond
# d'abord : chacune jette son ombre sur celles de derrière, est peinte en feuillage, bordée d'encre (plus lourde en bas à
# droite), porte ses arcs d'ombre et quelques brins qui dépassent du côté du jour ; la neige s'y pose s'il fait froid
static func houppier(o, p, r: RandomNumberGenerator, lobes: Array, haut: float, teinte: Color, sans_tronc := false, branches := 2) -> void:
	var c: Color = o._ecorce()
	if not sans_tronc:
		o._tronc(p, -8.5, haut, c)
		fibres(o, p, r, -11.0, haut + 5.0, r.randi_range(2, 3))
	var depart := Vector2(o._axe(haut + 3.0), haut + 3.0)
	var ep: float = o.epaisseur
	var faites := 0
	for l in lobes:
		var b: Vector2 = l[0] + Vector2(0, float(l[2]) * 0.25)
		if b.distance_to(depart) < 4.0 or faites >= maxi(branches, 2) + 1:
			continue
		var m := (depart + b) * 0.5 + Vector2((b.x - depart.x) * -0.12, 2.0)
		branche(p, T.courbe(depart, m, b, 5), maxf(1.8, 3.3 * ep), maxf(1.0, 1.7 * ep), c)
		faites += 1
	var bas := -INF
	for l in lobes:
		bas = maxf(bas, l[0].y + float(l[2]))
	p.eventail(Vector2(o._axe(bas), bas - 2.0), 6.5 * maxf(ep, 0.8), 5.0, Color(P.ENCRE, 0.5), Color(P.ENCRE, 0.0), 12)
	var tries := lobes.duplicate()
	tries.sort_custom(func(u, v): return u[0].y < v[0].y)
	var rang := 0
	for l in tries:
		var q: Vector2 = l[0]
		var lx: float = l[1]
		var ly: float = l[2]
		if rang > 0:
			# (son ombre, sur les touffes de derrière)
			T.ombre_douce(p, q + Vector2(lx * 0.1, ly * 0.22), lx * 1.02, ly * 0.95, 0.3)
		var poly: PackedVector2Array = o.festons(q, lx, ly, r.randi_range(6, 8), 0.17, r, 48, 0.12)
		var tl := teinte.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.12)).lightened(r.randf_range(0.0, 0.07))
		p.aplat(poly, tl, Pinceau.FEUILLAGE, q, Vector2(lx, ly) * 1.08)
		T.neige(o, p, poly, q, lx, ly, r)
		p.contour(poly, 1.4, ENCRE, r, 4)
		for k in r.randi_range(2, 3):
			var a0 := q + Vector2(r.randf_range(-0.05, 0.7) * lx, r.randf_range(0.0, 0.65) * ly)
			var rr := r.randf_range(4.5, 7.0)
			var arc := PackedVector2Array()
			var d := r.randf_range(-0.2, 0.4)
			for j in 6:
				arc.append(a0 + Vector2(cos(d + j * 0.32), sin(d + j * 0.32) * 0.9) * rr)
			p.tracer(arc, 0.85, Color(ENCRE, 0.55))
		brins(p, r, poly, q, tl, 1 if lx < 16.0 else 2)
		rang += 1


# quelques feuilles qui dépassent d'une touffe, du côté du jour : la silhouette vit
static func brins(p, r: RandomNumberGenerator, poly: PackedVector2Array, centre: Vector2, t: Color, n: int) -> void:
	var faits := 0
	var essais := 0
	while faits < n and essais < 24:
		essais += 1
		var q: Vector2 = poly[r.randi() % poly.size()]
		var dehors := (q - centre).normalized()
		if dehors.dot(T.JOUR) < 0.25:
			continue
		var tourne := r.randf_range(-0.5, 0.5)
		T.feuille(p, q - dehors * 1.4, q + dehors.rotated(tourne) * r.randf_range(3.4, 4.6), 1.5, t.lightened(0.08), 0.0, 0.42, 0.55, 3)
		if r.randf() < 0.5:
			T.feuille(p, q - dehors * 1.4, q + dehors.rotated(tourne + 0.95) * r.randf_range(2.8, 3.6), 1.3, t, 0.0, 0.42, 0.55, 3)
		faits += 1


# ce que les caractères d'Orvane ajoutent à une couronne, par-dessus ses touffes : les pousses claires d'un arbre rapide,
# l'éclat d'un feuillage coriace, des grappes de graines, des fleurs à miel, des graines ailées que le vent emporte
static func caracteres_de_couronne(o, p, lobes: Array, t: Color) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(o.graine) + 97
	if T.a(o, "rapide"):
		# (les pousses de l'année : de petites touffes d'un vert tendre, posées sur le haut de la couronne)
		var tendre := t.lerp(P.MOUSSE.lightened(0.25), 0.55).lerp(P.BRAISE_COEUR, 0.16)
		for l in lobes:
			var q: Vector2 = l[0]
			if q.y > o._cc.y + 0.25 * float(o._ry):
				continue
			var centre: Vector2 = q + Vector2(r.randf_range(-0.35, 0.3) * float(l[1]), -float(l[2]) * r.randf_range(0.6, 0.78))
			var lx: float = float(l[1]) * r.randf_range(0.34, 0.44)
			var poly: PackedVector2Array = o.festons(centre, lx, lx * 0.62, 5, 0.22, r, 20, 0.1)
			p.aplat(poly, tendre, Pinceau.FEUILLAGE, centre, Vector2(lx, lx * 0.62) * 1.1)
			p.contour(poly, 0.9, ENCRE, r, 3)
	if T.a(o, "coriace"):
		_luisant(p, r, lobes, 3)
	if T.a(o, "graines_abondantes"):
		# (des grappes de graines brunes, au bord des touffes)
		var graine := P.TERRE.lerp(P.BRAISE, 0.35).lightened(0.12)
		for l in lobes:
			for k in 3:
				var ang := r.randf_range(0.15, PI - 0.15)
				var q: Vector2 = l[0] + Vector2(cos(ang) * float(l[1]) * 0.86, sin(ang) * float(l[2]) * 0.8)
				p.tracer(PackedVector2Array([q + Vector2(0.0, -2.0), q + Vector2(0.3, 1.0)]), 0.6, Color(ENCRE, 0.7), false)
				for j in 4:
					var g := q + Vector2((j % 2) * 1.5 - 0.75, 1.0 + j * 1.0)
					p.disque(g, 1.0, 0.9, ENCRE)
					p.disque(g, 0.62, 0.55, graine)
	if T.a(o, "mellifere") and not Flore.SANS_FLEURS.has(str(o.stade).to_lower()) and str(o.maturite) != "":
		# (des bouquets de petites fleurs pâles, que les abeilles cherchent)
		var pale := P.PAPIER.lightened(0.12)
		for l in lobes:
			for k in 4:
				var q: Vector2 = l[0] + Vector2(r.randf_range(-0.72, 0.72) * float(l[1]), r.randf_range(-0.7, 0.35) * float(l[2]))
				for j in 3:
					var f := q + Vector2.from_angle(j * 2.1 + k) * 1.3
					p.disque(f, 1.05, 0.95, Color(ENCRE, 0.5))
					p.disque(f, 0.72, 0.65, pale if j != 1 else P.AUBE.lerp(pale, 0.5))
				p.disque(q, 0.4, 0.4, P.BRAISE_COEUR)
	if T.a(o, "vent"):
		# (ses graines ailées, prises par le vent : deux ou trois s'en vont, du côté où il souffle)
		var aile := P.IVOIRE.lerp(P.BRAISE_COEUR, 0.3)
		for k in 3:
			var q: Vector2 = o._cc + Vector2(float(o._rx) * r.randf_range(0.95, 1.3), float(o._ry) * r.randf_range(-0.6, 0.5))
			var ang := r.randf_range(-0.6, 0.6)
			T.feuille(p, q, q + Vector2.from_angle(ang) * 2.8, 0.8, aile, 0.0, 0.5, 0.4, 3)
			p.disque(q, 0.55, 0.5, P.TERRE.darkened(0.1))


# l'éclat d'un feuillage coriace : de petits traits clairs sur le haut des touffes, du côté du jour
static func _luisant(p, r: RandomNumberGenerator, lobes: Array, n: int) -> void:
	for l in lobes:
		for k in n:
			var q: Vector2 = l[0] + Vector2(r.randf_range(-0.6, 0.15) * float(l[1]), r.randf_range(-0.72, -0.1) * float(l[2]))
			var d := Vector2(1.0, -0.5).normalized() * r.randf_range(1.6, 2.8)
			p.tracer(PackedVector2Array([q - d, q + d]), 0.7, Color(P.PAPIER.lightened(0.2), 0.42))


# l'écorce écailleuse d'un vieux fruitier : des plaques, leur bord d'encre
static func _ecailles_d_ecorce(o, p, r: RandomNumberGenerator, y0: float, y1: float) -> void:
	var c: Color = o._ecorce()
	for i in 3:
		var y := r.randf_range(y1, y0)
		var w: float = o._demi_largeur(y)
		var q := Vector2(o._axe(y) + w * r.randf_range(-0.5, 0.4), y)
		p.tracer(PackedVector2Array([q + Vector2(-1.4, 0.0), q + Vector2(-0.4, -1.8), q + Vector2(1.3, -1.2)]), 0.6, Color(ENCRE, 0.5), false)
		p.disque(q + Vector2(0.0, -0.6), 0.9, 0.7, Color(c.lightened(0.22), 0.5))


# les rameaux d'un bouleau : de fins brins qui pendent sous la couronne, leurs petites feuilles (derrière les touffes)
static func _rameaux_pleureurs(o, p, r: RandomNumberGenerator, lobes: Array, t: Color) -> void:
	var chatons := T.a(o, "vent")
	for i in r.randi_range(4, 5):
		var l: Array = lobes[i % 3]
		var q: Vector2 = l[0] + Vector2(r.randf_range(-0.85, 0.85) * float(l[1]), float(l[2]) * r.randf_range(0.5, 0.8))
		var h := r.randf_range(7.0, 11.0) * float(o._ry) / 25.0
		var bout := q + Vector2(r.randf_range(-1.5, 2.5), h)
		var ligne := T.courbe(q, q + Vector2(0.6, h * 0.5), bout, 4)
		p.tracer(ligne, 0.6, Color(ENCRE, 0.75), false)
		for k in range(1, 5):
			var a0: Vector2 = ligne[k]
			var cote := -1.0 if k % 2 == 0 else 1.0
			T.feuille(p, a0, a0 + Vector2(cote * 2.6, 2.1), 1.25, t.lightened(0.04), 0.0, 0.45, 0.5, 3)
		if chatons and i % 2 == 0:
			# (un chaton, que le vent secoue)
			p.tracer(PackedVector2Array([bout, bout + Vector2(0.5, 3.2)]), 1.5, ENCRE, false)
			p.tracer(PackedVector2Array([bout, bout + Vector2(0.5, 3.0)]), 0.8, P.BRAISE_COEUR.darkened(0.12), false)


# les fruits d'un palétuvier : des cigares verts qui pendent sous le feuillage (ils germent sur l'arbre)
static func _propagules(o, p, r: RandomNumberGenerator, lobes: Array) -> void:
	var vert := P.MOUSSE.lerp(P.TERRE, 0.3)
	for i in r.randi_range(4, 6):
		var l: Array = lobes[i % 2]
		var q: Vector2 = l[0] + Vector2(r.randf_range(-0.8, 0.8) * float(l[1]), float(l[2]) * r.randf_range(0.7, 0.9))
		var bout := q + Vector2(r.randf_range(-0.6, 0.6), r.randf_range(4.5, 7.0))
		p.tracer(PackedVector2Array([q, bout]), 1.9, ENCRE, false, PackedFloat32Array([1.4, 2.0]))
		p.tracer(PackedVector2Array([q, bout]), 1.0, vert.lightened(0.1), false, PackedFloat32Array([0.6, 1.1]))


# un géant : un fût droit et massif, crevassé, ses contreforts au pied (racines), un chicot à mi-hauteur, de grosses branches
# qui s'ouvrent tout en haut dans une couronne en cinq touffes
static func _geant(o, p, r: RandomNumberGenerator, t: Color) -> void:
	var c: Color = o._ecorce()
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	var haut := cc.y + ry * 0.5
	o._tronc(p, -8.5, haut, c)
	fissures(o, p, r, -9.0, haut + 4.0, r.randi_range(8, 10))
	# (de la mousse sur le flanc de l'ombre, s'il fait humide ; un nœud ; un chicot)
	if float(o._climat.get("humide", 0.5)) > 0.45:
		for i in r.randi_range(2, 4):
			var y := r.randf_range(haut * 0.55, -12.0)
			var m := Vector2(o._axe(y) + o._demi_largeur(y) * r.randf_range(0.35, 0.8), y)
			p.disque(m, r.randf_range(1.4, 2.4), r.randf_range(1.6, 3.0), P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.3), Pinceau.FEUILLAGE)
	for i in 2:
		var y := lerpf(-16.0, haut + 12.0, (i + r.randf_range(0.2, 0.8)) / 2.0)
		var nd := Vector2(o._axe(y) + o._demi_largeur(y) * r.randf_range(-0.4, 0.3), y)
		p.disque(nd, 2.0, 1.5, c.darkened(0.5))
		p.tracer(PackedVector2Array([nd + Vector2(-2.2, -0.8), nd + Vector2(0, -2.1), nd + Vector2(2.2, -0.6)]), 0.7, c.lightened(0.28), false)
	var cote := 1.0 if o.graine % 2 == 0 else -1.0
	var yb := lerpf(-22.0, haut, r.randf_range(0.42, 0.66))
	var a0 := Vector2(o._axe(yb) + cote * o._demi_largeur(yb) * 0.7, yb)
	var a1 := a0 + Vector2(cote * r.randf_range(8.0, 12.0), -r.randf_range(3.5, 6.5))
	branche(p, PackedVector2Array([a0, a0.lerp(a1, 0.5) + Vector2(0.0, 0.8), a1]), 3.6, 2.4, c.darkened(0.08))
	p.disque(a1, 1.3, 1.1, P.IVOIRE.lerp(P.BRAISE, 0.25).darkened(0.1))
	p.tracer(PackedVector2Array([a0.lerp(a1, 0.6), a0.lerp(a1, 0.6) + Vector2(cote * 2.0, -5.0)]), 1.2, ENCRE, false, PackedFloat32Array([1.4, 0.5]))
	# (six bouquets, chacun au bout de sa charpentière : deux bas sur les côtés, qui débordent, deux au-dessus, la cime, et un
	# bouquet du devant, sous la cime, qui fait de l'ombre aux autres)
	var lobes := [[cc + Vector2(-rx * 0.62, ry * 0.34), rx * 0.42, ry * 0.5], [cc + Vector2(rx * 0.64, ry * 0.38), rx * 0.4, ry * 0.48],
		[cc + Vector2(-rx * 0.28, -ry * 0.2), rx * 0.48, ry * 0.6], [cc + Vector2(rx * 0.3, -ry * 0.12), rx * 0.46, ry * 0.58],
		[cc + Vector2(rx * r.randf_range(-0.12, 0.12), -ry * 0.55), rx * 0.42, ry * 0.5],
		[cc + Vector2(rx * r.randf_range(-0.1, 0.06), ry * 0.36), rx * 0.46, ry * 0.5]]
	houppier(o, p, r, lobes, haut, t.lerp(P.FEUILLE_SOMBRE, 0.12), true, 4)
	caracteres_de_couronne(o, p, lobes, t)


# un figuier : un dais large, porté par ses racines aériennes — les plus vieilles sont devenues des fûts, les jeunes pendent
# encore du feuillage
static func _figuier(o, p, r: RandomNumberGenerator, t: Color) -> void:
	var c: Color = o._ecorce()
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	var haut := cc.y + ry * 0.45
	var lobes := [[cc + Vector2(-rx * 0.52, ry * 0.14), rx * 0.56, ry * 0.74], [cc + Vector2(rx * 0.52, ry * 0.18), rx * 0.54, ry * 0.7],
		[cc + Vector2(-rx * 0.12, -ry * 0.18), rx * 0.6, ry * 0.78], [cc + Vector2(rx * 0.24, -ry * 0.3), rx * 0.48, ry * 0.6]]
	o._tronc(p, -8.5, haut, c)
	fibres(o, p, r, -10.0, haut + 4.0, 3)
	# (les piliers : deux ou trois racines tombées, épaissies en fûts, de part et d'autre)
	for i in r.randi_range(2, 3):
		var cote := -1.0 if i % 2 == 0 else 1.0
		var x := cc.x + cote * rx * r.randf_range(0.34, 0.7)
		var y0 := cc.y + ry * r.randf_range(0.35, 0.55)
		var axe := PackedVector2Array([Vector2(x + r.randf_range(-1.5, 1.5), r.randf_range(-0.5, 2.0)), Vector2(x + r.randf_range(-1.0, 1.0), y0 * 0.5), Vector2(x, y0)])
		var tb := T.tube(p, axe, PackedFloat32Array([2.4, 1.7, 1.5]), c.darkened(0.05), Pinceau.ECORCE, 1, 0.0, false)
		T.cerner_tube(p, tb, 0.8, 1.3)
		p.disque(axe[0] + Vector2(0.3, 0.6), 3.4, 1.1, Color(P.ENCRE, 0.3))
	# (les jeunes : des cordes pâles, certaines n'ont pas encore touché le sol)
	var corde := P.CENDRE.lerp(P.IVOIRE, 0.35)
	for i in r.randi_range(5, 7):
		var x := cc.x + r.randf_range(-0.85, 0.85) * rx
		var y0 := cc.y + ry * r.randf_range(0.3, 0.6)
		var bas := r.randf_range(-1.0, 1.5) if i % 3 != 0 else lerpf(y0, 0.0, r.randf_range(0.4, 0.7))
		var ligne := PackedVector2Array([Vector2(x, y0), Vector2(x + r.randf_range(-1.5, 1.5), lerpf(y0, bas, 0.5)), Vector2(x + r.randf_range(-2.5, 2.5), bas)])
		p.tracer(ligne, 1.6, ENCRE, false)
		p.tracer(ligne, 0.8, corde, false)
	houppier(o, p, r, lobes, haut, t, true, 4)
	caracteres_de_couronne(o, p, lobes, t)


# un baobab : un fût en bouteille, ventru, à la peau lisse et ridée, cannelé ; de grosses branches courtes qui se tordent
# comme des racines, et au bout un feuillage maigre ; ses fruits pendent à de longs fils (fruits_couronne)
static func _baobab(o, p, r: RandomNumberGenerator, t: Color) -> void:
	var c: Color = o._ecorce()
	var haut: float = o._cc.y + o._ry * 0.55
	var w0: float = o._demi_largeur(-8.5)
	var axe := PackedVector2Array()
	var rayons := PackedFloat32Array()
	var n := 12
	for i in n + 1:
		var u := float(i) / n
		var y := lerpf(-8.5, haut, u)
		axe.append(Vector2(o._axe(y), y))
		# (le ventre, puis l'épaule qui se resserre vers le col)
		rayons.append(w0 * (1.0 + 0.2 * sin(u * PI * 0.85)) * lerpf(1.0, 0.56, smoothstep(0.62, 1.0, u)))
	var tb := T.tube(p, axe, rayons, c, Pinceau.DOME, 5, 0.13, false, 0.22)
	# (les cannelures : un trait d'ombre dans chaque creux)
	var lignes: Array = tb["lignes"]
	for i in range(1, 5):
		var creux: PackedVector2Array = lignes[i]
		p.tracer(creux, 0.7, Color(ENCRE, 0.26 if i < 3 else 0.42), true)
	T.cerner_tube(p, tb, 1.2, 1.9)
	# (les rides de sa peau : des plis en travers, serrés au pied et à l'épaule ; une cicatrice ; un creux)
	for i in r.randi_range(7, 9):
		var k := r.randi_range(0, n - 1)
		var s := r.randf_range(-0.7, 0.6)
		var larg := r.randf_range(0.2, 0.42)
		var a0 := T.sur_tube(tb, k, s - larg)
		var m0 := T.sur_tube(tb, k, s) + Vector2(0.0, r.randf_range(0.8, 1.6))
		var b0 := T.sur_tube(tb, k, s + larg)
		p.tracer(PackedVector2Array([a0, m0, b0]), 0.65, Color(ENCRE, 0.36))
	var kc := r.randi_range(3, 6)
	var trou := T.sur_tube(tb, kc, r.randf_range(-0.2, 0.35))
	p.disque(trou, 2.3, 3.2, ENCRE)
	p.disque(trou + Vector2(0.4, 0.3), 1.5, 2.3, P.ENCRE.lightened(0.04))
	p.tracer(PackedVector2Array([trou + Vector2(-2.6, -2.0), trou + Vector2(-3.0, 0.6), trou + Vector2(-1.8, 3.0)]), 0.8, Color(c.lightened(0.3), 0.7))
	# les branches : courtes, grosses, tordues, qui se dédoublent ; celles du fond d'abord
	var sommet := Vector2(o._axe(haut), haut)
	var branches := []
	var nb := r.randi_range(5, 7)
	for i in nb:
		var a := lerpf(-2.85, -0.3, (i + r.randf_range(0.2, 0.8)) / nb)
		branches.append([a, r.randf_range(0.62, 1.0)])
	branches.sort_custom(func(u, v): return absf(u[0] + PI * 0.5) < absf(v[0] + PI * 0.5))
	var touffes := []
	for b in branches:
		var a: float = b[0]
		var l: float = b[1]
		var bout: Vector2 = sommet + Vector2(cos(a) * o._rx * l, sin(a) * o._ry * 1.25 * l)
		var coude := sommet.lerp(bout, 0.45) + Vector2(cos(a) * 3.0, -4.0 + absf(cos(a)) * 5.0)
		branche(p, T.courbe(sommet + Vector2(cos(a) * rayons[n] * 0.5, 0.0), coude, bout, 6), 5.4, 1.8, c)
		# (un rameau qui part du coude)
		var bout2 := coude + Vector2(cos(a - 0.5) * 8.0, sin(a - 0.5) * 7.0 - 2.0)
		branche(p, PackedVector2Array([coude, coude.lerp(bout2, 0.5) + Vector2(0.0, -1.0), bout2]), 2.4, 1.0, c)
		touffes.append(bout)
		touffes.append(bout2)
	# (ses fruits pendent au bout de ces branches, sous leurs touffes : fruits_couronne les y retrouve)
	var bouts := []
	for i in range(0, touffes.size(), 2):
		bouts.append(touffes[i])
	o.set_meta("bouts", bouts)
	T.debut_feuillage(p)
	touffes.sort_custom(func(u, v): return u.y < v.y)
	var lobes := []
	for q in touffes:
		var lx := r.randf_range(7.5, 11.5)
		var ly := r.randf_range(5.0, 7.0)
		var centre: Vector2 = q + Vector2(0, -2.5)
		var poly: PackedVector2Array = o.festons(centre, lx, ly, 6, 0.25, r, 26, 0.1)
		T.ombre_douce(p, centre + Vector2(0.8, 2.0), lx, ly * 0.9, 0.22)
		p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.15)), Pinceau.FEUILLAGE, centre, Vector2(lx, ly) * 1.08)
		T.neige(o, p, poly, centre, lx, ly, r)
		p.contour(poly, 1.1, ENCRE, r, 3)
		lobes.append([centre, lx, ly])
	caracteres_de_couronne(o, p, lobes, t)


# un palmier (ou une fougère arborescente) : le fût qui se courbe — annelé, ses anneaux serrés vers le haut, le manchon de
# fibres sous les palmes ; ou noir, écailleux, sa jupe de frondes mortes — puis le bouquet : des palmes faites de leurs
# folioles, une à une, celles du fond d'abord, qui montent et retombent ; la fougère a ses frondes en dentelle et ses crosses
static func _palmier(o, p, r: RandomNumberGenerator, t: Color, fougere: bool) -> void:
	var c: Color = o._ecorce()
	var ht: float = o._ht
	var axe := PackedVector2Array()
	var rayons := PackedFloat32Array()
	var n := 14
	for i in n + 1:
		var y := lerpf(-8.5, -ht, float(i) / n)
		axe.append(Vector2(courbe_palme(o, y), y))
		rayons.append(_demi_fut(o, y) * (1.0 if i > 0 else 1.0))
	var tb := T.tube(p, axe, rayons, c, Pinceau.ECORCE if fougere else Pinceau.DOME, 1, 0.0, false)
	T.cerner_tube(p, tb, 1.0, 1.6)
	if fougere:
		ecailles(o, p, r, -9.5, -ht + 7.0)
	else:
		# (les anneaux des palmes tombées : des arcs, plus serrés vers le haut ; un sur deux marque le fût d'une bande sombre)
		var y := -11.0
		var rang := 0
		while y > -ht + 9.0:
			var u := clampf((-y - 8.5) / maxf(1.0, ht - 8.5), 0.0, 1.0)
			var w := _demi_fut(o, y)
			var x := courbe_palme(o, y)
			var arc := PackedVector2Array([Vector2(x - w, y - 0.6), Vector2(x - w * 0.4, y + 0.7), Vector2(x + w * 0.4, y + 0.7), Vector2(x + w, y - 0.6)])
			if rang % 2 == 0:
				var arc2 := PackedVector2Array()
				for q in arc:
					arc2.append(q + Vector2(0.0, -1.5))
				p.bande(arc, arc2, Color(c.darkened(0.3), 0.3))
			p.tracer(arc, 0.75, Color(ENCRE, 0.6), false)
			y -= lerpf(4.6, 3.0, u)
			rang += 1
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	if fougere:
		# (la jupe : des frondes mortes, brunes, qui pendent le long du fût)
		var morte := P.TERRE.lerp(P.BRAISE, 0.2).darkened(0.1)
		for i in r.randi_range(3, 5):
			var cote := -1.0 if i % 2 == 0 else 1.0
			var a := PI * 0.5 - cote * r.randf_range(0.12, 0.5)
			_palme(p, r, cc + Vector2(cote * 1.5, 1.0), a, rx * r.randf_range(0.42, 0.6), ry * 0.2, ry * 0.5, morte, true, 0.75, false)
	else:
		# (le manchon : les gaines des palmes, en fibres croisées, sous le bouquet)
		var k0 := n - 2
		for k in range(k0, n + 1):
			var w := float(tb["r"][k]) + 1.2
			var q: Vector2 = tb["axe"][k]
			p.disque(q, w, 2.4, ENCRE)
			p.disque(q, w - 0.7, 1.8, P.TERRE.lerp(P.BRAISE, 0.15).darkened(0.12), Pinceau.DOME)
		for i in 4:
			var q: Vector2 = tb["axe"][n - 1] + Vector2(lerpf(-3.0, 3.0, i / 3.0), 1.0)
			p.tracer(PackedVector2Array([q + Vector2(-1.6, 2.0), q + Vector2(1.6, -2.2)]), 0.5, Color(ENCRE, 0.5))
			p.tracer(PackedVector2Array([q + Vector2(1.6, 2.0), q + Vector2(-1.6, -2.2)]), 0.5, Color(ENCRE, 0.4))
	# les palmes : de celles du fond (vers le haut) à celles qui viennent vers nous, en tombant
	T.debut_feuillage(p)
	var palmes := []
	var np := r.randi_range(9, 11) if fougere else r.randi_range(8, 10)
	for i in np:
		var a := lerpf(-PI + 0.12, -0.12, float(i) / (np - 1)) + r.randf_range(-0.12, 0.12)
		palmes.append([a, r.randf_range(0.85, 1.05)])
	palmes.append([r.randf_range(0.3, 0.6), r.randf_range(0.6, 0.78)])
	palmes.append([PI - r.randf_range(0.3, 0.6), r.randf_range(0.6, 0.78)])
	if r.randf() < 0.7:
		palmes.append([PI * 0.5 + r.randf_range(-0.4, 0.4), r.randf_range(0.45, 0.6)])
	palmes.sort_custom(func(u, v): return sin(u[0]) < sin(v[0]))
	var froid := T.enneigee(o)
	for pa in palmes:
		var a: float = pa[0]
		var face := t.lerp(t.lightened(0.2), clampf(-sin(a), 0.0, 1.0) * 0.5 + 0.12)
		if cos(a) > 0.2:
			face = face.darkened(0.1)
		_palme(p, r, cc, a, rx * float(pa[1]), ry * (0.62 if fougere else 0.55), ry * (0.95 if fougere else 0.8), face, fougere, 1.0, froid and sin(a) < 0.2)
	if fougere:
		# (des crosses qui se déroulent, au cœur)
		for i in 3:
			var q := cc + Vector2((i - 1) * 4.2, -1.5 - (2.0 if i == 1 else 0.0))
			var spi := PackedVector2Array()
			for k in 13:
				var u := k / 12.0
				var ang := -PI * 0.5 + u * TAU * 1.15 * (1.0 if i != 2 else -1.0)
				spi.append(q + Vector2(0, -7.0 * (1.0 - u)) + Vector2(cos(ang), sin(ang)) * (2.7 * u))
			p.tracer(spi, 1.9, ENCRE, false)
			p.tracer(spi, 1.0, t.lightened(0.32).lerp(P.BRAISE_COEUR, 0.2), false)
	else:
		# (la flèche : la palme neuve, encore fermée, dressée au cœur)
		var bout := cc + Vector2(o._penche * 30.0 + r.randf_range(-2.0, 2.0), -ry * 1.15)
		T.feuille(p, cc + Vector2(0.0, -1.0), bout, 1.6, t.lightened(0.22).lerp(P.BRAISE_COEUR, 0.15), 1.0, 0.4, 0.6, 5)
	var lobes := [[cc + Vector2(0.0, -ry * 0.2), rx * 0.6, ry * 0.7]]
	caracteres_de_couronne(o, p, lobes, t)


# une palme : sa nervure qui monte puis retombe sous son poids, et ses folioles une à une, de chaque côté (l'encre d'abord,
# un peu plus large, puis la feuille : celles du côté du jour plus claires). La fronde d'une fougère : des pennes plus larges,
# plus serrées, en dentelle, la plus grande au premier tiers
static func _palme(p, r: RandomNumberGenerator, pied: Vector2, a: float, l: float, monte: float, tombe: float, t: Color, fougere: bool, force := 1.0, neige := false) -> void:
	var m := 13 if fougere else 12
	var d := Vector2(cos(a), sin(a) * 0.55)
	var axe := PackedVector2Array()
	for k in m + 1:
		var u := float(k) / m
		axe.append(pied + d * l * u + Vector2(0, -monte * sin(u * PI * 0.7) + tombe * u * u))
	var folioles := []
	for k in range(1, m + 1):
		var u := float(k) / m
		var tan_ := (axe[mini(k + 1, m)] - axe[maxi(k - 1, 0)]).normalized()
		var nrm := tan_.orthogonal()
		var long := (7.2 if fougere else 9.5) * force * (sin(PI * minf(1.0, u * 1.25 + 0.1)) * (1.0 - u * 0.5) + 0.12)
		if fougere:
			long *= 0.75 + 0.25 * sin(PI * minf(1.0, u * 2.2))
		var ouverture := lerpf(1.25, 0.55, u)
		for cote in [-1.0, 1.0]:
			var dir: Vector2 = (tan_ * cos(ouverture) + nrm * cote * sin(ouverture)).normalized()
			# (elle pend un peu, sous son poids)
			var bout: Vector2 = axe[k] + dir * long * r.randf_range(0.86, 1.08) + Vector2(0.0, long * (0.16 if fougere else 0.3))
			folioles.append([axe[k], bout, tan_, cote * nrm.dot(T.JOUR) > 0.0, u])
	var base := 1.5 if fougere else 1.15
	for f in folioles:
		var q: Vector2 = f[0]
		var tg: Vector2 = f[2]
		var b: Vector2 = f[1]
		T.tri(p, q - tg * (base + 0.5), q + tg * (base + 0.5), b + (b - q).normalized() * 0.9, Color(ENCRE, 0.82))
	for f in folioles:
		var q: Vector2 = f[0]
		var tg: Vector2 = f[2]
		var ton: Color = t.lightened(0.07) if bool(f[3]) else t.darkened(0.2)
		if float(f[4]) > 0.75:
			ton = ton.lightened(0.05)
		T.tri(p, q - tg * base, q + tg * base, f[1], ton)
	if neige:
		# (la neige tient sur la nervure des palmes hautes)
		var haut := PackedVector2Array()
		for k in range(1, m - 2):
			haut.append(axe[k] + Vector2(0.0, -0.6))
		p.tracer(haut, 2.2, P.PAPIER.lightened(0.3), true)
	p.tracer(axe, 1.3, Color(t.darkened(0.5), 0.9), false, PackedFloat32Array(), false)
	var clair := PackedVector2Array()
	for q in axe:
		clair.append(q + Vector2(-0.2, -0.35))
	p.tracer(clair, 0.5, Color(t.lightened(0.35), 0.7), true)


# le bois nu d'un palmier ou d'une fougère arborescente, quand le feu a pris ses palmes : leurs nervures noires qui retombent
# (faux : les branches de tous les arbres, scripts/objet.gd, _bois_nu)
static func bois_nu(o, p, dehors := false) -> bool:
	if not (str(o.forme) in ["palmier", "fougere_arbre"]):
		return false
	if dehors:
		return true
	var r := RandomNumberGenerator.new()
	r.seed = int(o.graine) + 41
	var cc: Vector2 = o._cc
	var noir := Color("1d1915").lightened(0.06)
	# (le haut du fût, charbonné, puis les nervures)
	var fut := PackedVector2Array()
	for k in 6:
		var y := lerpf(-12.0, -float(o._ht), k / 5.0)
		fut.append(Vector2(courbe_palme(o, y), y))
	var w: float = o._demi_largeur(-8.5)
	p.tracer(fut, w * 2.0, ENCRE, false, PackedFloat32Array([w * 2.0 + 1.0, w * 2.0 + 0.8, w * 1.9 + 0.8, w * 1.8 + 0.8, w * 1.7 + 0.8, w * 1.6 + 0.8]))
	p.tracer(fut, w * 2.0, noir, false, PackedFloat32Array([w * 2.0, w * 2.0, w * 1.9, w * 1.8, w * 1.7, w * 1.6]))
	for i in 7:
		var a := lerpf(-PI + 0.2, -0.2, i / 6.0) + r.randf_range(-0.15, 0.15)
		var l: float = float(o._rx) * r.randf_range(0.6, 0.9)
		var d := Vector2(cos(a), sin(a) * 0.55)
		var nervure := PackedVector2Array()
		for k in 6:
			var u := k / 5.0
			nervure.append(cc + d * l * u + Vector2(0, -float(o._ry) * 0.5 * sin(u * PI * 0.7) + float(o._ry) * 0.9 * u * u))
		p.tracer(nervure, 1.6, ENCRE, false, PackedFloat32Array([2.2, 1.9, 1.6, 1.3, 1.0, 0.6]))
	return true
