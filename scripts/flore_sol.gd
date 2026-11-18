extends RefCounted
# Lisière — les plantes du sol de l'herbier, dessinées à l'encre (scripts/flore_sol.gd)
# Ce qui se dresse et ce qui rampe, d'après les planches d'Orvane, avec le volume et le trait des premiers dessins
# (scripts/flore_trait.gd) : le cactus en candélabre (sa colonne côtelée, ses bras qui se coudent, ses aréoles et leurs épines,
# sa chair à nu quand on l'entame), l'agave (une grande rosette de lames épaisses, dentées, armées d'un dard ; parfois sa
# hampe), la plante grasse (une rosette charnue, ses rejets), le bambou (des cannes nouées, leurs gaines, leurs feuilles en
# éventail, la cime qui ploie), le roseau (de hautes tiges, leurs rubans, leurs quenouilles brunes), le jonc (une fontaine de
# brins raides, leurs glomérules bruns).
# Chaque plante vient de sa graine : le nombre de bras, de cannes, de feuilles, leur port, un nid dans la colonne, une hampe.
# Ses caractères d'Orvane s'y lisent (une naine se tasse, des échasses soulèvent la touffe, une rapide a ses pousses neuves).

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const T := preload("res://scripts/flore_trait.gd")
const Arbres := preload("res://scripts/flore_arbres.gd")
const Flore := preload("res://scripts/flore.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)


# --- la taille (après la mesure commune des touffes) ---

static func mesurer(o, r: RandomNumberGenerator, f: String) -> bool:
	match f:
		"cactus":
			# (6 m : 66 pixels, une fois et demie la veilleuse)
			o._ry = r.randf_range(60.0, 72.0)
			o._rx = r.randf_range(6.6, 8.0)
		"agave":
			o._rx = r.randf_range(22.0, 27.0)
			o._ry = r.randf_range(21.0, 26.0)
		"succulente":
			o._rx = r.randf_range(9.5, 12.5)
			o._ry = r.randf_range(8.0, 11.0)
		"bambou":
			# (6 m : 68 pixels ; 8 m : 76 ; 4 m : 58)
			o._ry = r.randf_range(62.0, 74.0)
			o._rx = 9.0
		"roseau":
			# (1,8 m : la hauteur de la veilleuse, à peu près)
			o._ry = r.randf_range(38.0, 47.0)
			o._rx = 8.0
		"jonc":
			o._ry = r.randf_range(18.0, 23.0)
			o._rx = 7.0
		"cereale", "riz":
			# (1 m : la moitié de la veilleuse, épis compris)
			o._ry = r.randf_range(22.0, 28.0)
			o._rx = 8.0
		"papyrus":
			o._ry = r.randf_range(44.0, 54.0)
			o._rx = 9.0
		"fougere":
			o._ry = r.randf_range(20.0, 25.0)
			o._rx = 14.0
		"legumineuse":
			o._rx = r.randf_range(10.0, 13.0)
			o._ry = r.randf_range(8.0, 11.0)
		"coussin", "lichen_rennes":
			o._rx = r.randf_range(8.5, 12.0)
			o._ry = r.randf_range(6.0, 9.0)
		"mousse", "lichen", "lichen_croute", "caillou":
			o._rx = r.randf_range(8.5, 13.0)
			o._ry = o._rx * r.randf_range(0.42, 0.55)
			o.hauteur = 2.0
			return true
		_:
			return false
	if T.a(o, "naine"):
		# (une naine se tasse)
		o._ry *= 0.9
		o._rx *= 1.08
	o.hauteur = o._ry
	return true


# --- les ombres ---

static func ombres(o):
	match str(o.forme):
		"cactus":
			return [[Vector2(1, 1), Vector2(o._rx * 1.5 + 3.0, 3.8), 0.45, 0.0, 0.0], [Vector2(2, 2), Vector2(o._rx * 2.6, o._rx * 0.9), 0.26, 1.0, o.hauteur * 0.8]]
		"bambou":
			return [[Vector2(0, 1), Vector2(12.0, 3.8), 0.36, 0.0, 0.0], [Vector2(2, 2), Vector2(11.0, 4.5), 0.2, 1.0, o.hauteur * 0.6]]
		"roseau":
			return [[Vector2(0, 1), Vector2(9.0, 3.0), 0.3 if o.reste > 0 else 0.15, 0.0, 0.0], [Vector2(2, 2), Vector2(7.0, 3.0), 0.14, 1.0, o.hauteur * 0.5]]
		"agave":
			return [[Vector2(0.5, 1), Vector2(o._rx * 1.0, o._rx * 0.3), 0.34, 0.0, 0.0]]
		"succulente", "coussin", "lichen_rennes":
			return [[Vector2(0.5, 1), Vector2(o._rx * 1.05, o._rx * 0.32), 0.32, 0.0, 0.0]]
		"papyrus":
			return [[Vector2(0, 1), Vector2(10.0, 3.5), 0.35, 0.0, 0.0], [Vector2(2, 2), Vector2(9.0, 4.0), 0.2, 1.0, o.hauteur * 0.6]]
		"fougere":
			return [[Vector2(0, 1), Vector2(o._rx * 0.9, 3.4), 0.3 if o.reste > 0 else 0.15, 0.0, 0.0]]
		"mousse", "lichen", "lichen_croute", "caillou":
			return []
	return null


# --- le dessin ---

static func dessiner(o, p, r: RandomNumberGenerator, f: String) -> bool:
	match f:
		"cactus":
			cactus(o, p, r)
		"agave":
			agave(o, p, r)
		"succulente":
			succulente(o, p, r)
		"bambou":
			bambou(o, p, r)
		"roseau":
			roseau(o, p, r)
		"jonc":
			jonc(o, p, r)
		"cereale":
			cereale(o, p, r, false)
		"riz":
			cereale(o, p, r, true)
		"papyrus":
			papyrus(o, p, r)
		"fougere":
			fougere(o, p, r)
		"legumineuse":
			legumineuse(o, p, r)
		"coussin":
			coussin(o, p, r)
		"mousse":
			mousse(o, p, r)
		"lichen":
			lichen(o, p, r, false)
		"lichen_croute":
			lichen(o, p, r, true)
		"lichen_rennes":
			lichen_rennes(o, p, r)
		"caillou":
			plante_caillou(o, p, r)
		_:
			return false
	return true


# ce qui reste d'une touffe coupée : des chaumes sur la terre remuée
static func chaumes(p, r: RandomNumberGenerator, paille: Color, haut := 4.5, large := 4.5) -> void:
	T.assise(p, Vector2(0, 1), large + 2.5, 2.8, P.TERRE.darkened(0.3), 0.6)
	for i in 7:
		var x := r.randf_range(-large, large)
		var bout := Vector2(x + r.randf_range(-1, 1), -r.randf_range(haut * 0.55, haut))
		p.tracer(PackedVector2Array([Vector2(x, 1), bout]), 1.9, Color(ENCRE, 0.8), false, PackedFloat32Array([2.0, 1.6]))
		p.tracer(PackedVector2Array([Vector2(x, 1), bout]), 1.1, paille.darkened(0.2), false, PackedFloat32Array([1.2, 0.9]))
		# (la coupe, claire)
		p.disque(bout, 0.55, 0.4, P.IVOIRE.lightened(0.05))


# -- le cactus --

# un cactus en candélabre : une colonne côtelée (chaque côte a son flanc au jour et son flanc à l'ombre), un ou deux bras qui
# partent du fût, se coudent et se relèvent ; sur chaque côte, des aréoles de laine pâle et leurs épines ; des épines sur la
# silhouette ; au pied, l'écorce qui se fait liège, des cailloux. Entamé, un bras en moins (ou une tranche de la colonne) : sa
# chair à nu, pâle et mouillée, d'où perle une goutte ; c'est sa pulpe qu'on emporte
static func cactus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var w: float = o._rx
	var t: Color = T.vert_propre(o, P.MOUSSE.lerp(P.LUNE, 0.14).darkened(0.03), 0.3)
	if T.a(o, "coriace"):
		# (une peau épaisse, cireuse : plus glauque)
		t = t.lerp(P.LUNE, 0.1).darkened(0.04)
	var graine: int = o.graine
	var tous := 2 if graine % 3 != 0 else 1
	var entames: int = int(o.plein) - int(o.reste)
	var nb := maxi(0, tous - entames)
	var penche := r.randf_range(-0.035, 0.035)
	var bras := []
	for i in tous:
		var cote := -1.0 if (i + graine) % 2 == 0 else 1.0
		var y0 := r.randf_range(0.3, 0.52) * h
		bras.append([cote, y0, minf(h * 0.96, y0 + r.randf_range(0.24, 0.42) * h), r.randf_range(w * 2.0, w * 2.8)])
	# (la terre sèche au pied, des cailloux)
	T.assise(p, Vector2(0.5, 1.2), w * 2.2 + 3.0, 3.6, P.TERRE.darkened(0.25), 0.4)
	for i in r.randi_range(2, 4):
		T.gravier(p, Vector2(r.randf_range(-w * 2.4, w * 2.4), r.randf_range(0.5, 3.6)), r.randf_range(0.9, 1.7), P.IVOIRE.lerp(P.CENDRE, 0.35).darkened(r.randf_range(0.0, 0.2)))
	# (les bras derrière la colonne d'abord)
	for i in nb:
		_bras_de_cactus(p, r, bras[i], w, penche, t.darkened(0.05))
	if graine % 4 == 1 and entames == 0:
		# (un bras qui naît : une boule sur le flanc)
		var cote := 1.0 if (graine / 4) % 2 == 0 else -1.0
		var yb := h * r.randf_range(0.5, 0.66)
		var pied := Vector2(cote * w * 0.6 + penche * yb, -yb)
		var bourgeon := T.tube(p, PackedVector2Array([pied, pied + Vector2(cote * w * 0.75, -0.6)]), PackedFloat32Array([w * 0.5, w * 0.5]), t.darkened(0.03), Pinceau.DOME, 3, 0.3, true)
		T.cerner_tube(p, bourgeon, 0.9, 1.4)
		T.areole(p, pied + Vector2(cote * w * 1.1, -0.8), Vector2(cote, -0.3), 1.5, P.PAPIER.lightened(0.08))
	# la colonne : un peu plus étroite au pied, renflée au milieu
	var axe := PackedVector2Array()
	var rayons := PackedFloat32Array()
	var n := maxi(8, int(h / 4.4))
	var ondule := r.randf() * TAU
	for k in n + 1:
		var u := float(k) / n
		var y := lerpf(1.0, -(h - w), u)
		axe.append(Vector2(penche * -y + sin(u * 2.4 + ondule) * 0.7, y))
		rayons.append(w * (0.86 + 0.14 * sin(u * PI * 0.92)))
	var cotes := 5
	var tb := T.tube(p, axe, rayons, t, Pinceau.DOME, cotes, 0.3, true)
	_habiller_cactus(p, r, tb, cotes, t, 1)
	# (le pied se fait liège : brun, fendillé)
	for i in 6:
		var s := lerpf(-0.85, 0.85, (i + r.randf()) / 6.0)
		var q := T.sur_tube(tb, 0, s)
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-0.5, 0.5), -r.randf_range(3.0, 7.0))]), 2.2, Color(P.TERRE.lerp(P.IVOIRE, 0.15), 0.72), false, PackedFloat32Array([2.4, 0.4]))
	if graine % 5 == 2:
		# (un nid : le trou qu'un oiseau a creusé dans la colonne, son bourrelet)
		var kn := int(n * r.randf_range(0.5, 0.72))
		var trou := T.sur_tube(tb, kn, r.randf_range(-0.3, 0.3))
		p.disque(trou, 2.1, 2.5, ENCRE)
		p.disque(trou + Vector2(0.3, 0.3), 1.3, 1.7, P.ENCRE)
		p.tracer(PackedVector2Array([trou + Vector2(-2.2, -1.4), trou + Vector2(-2.5, 0.8), trou + Vector2(-1.2, 2.6)]), 0.7, Color(t.lightened(0.4), 0.8))
	# (à sa cime : des fleurs crème au printemps, puis de petits fruits rouges)
	var sommet: Vector2 = tb["axe"][tb["axe"].size() - 1]
	if str(o.maturite) == "fleurs":
		for i in 3:
			var q := sommet + Vector2((i - 1) * w * 0.55, 1.0 + absf(i - 1) * 1.4)
			p.disque(q, 1.9, 1.6, ENCRE)
			p.disque(q, 1.4, 1.1, P.PAPIER.lightened(0.15), Pinceau.DOME)
			p.disque(q, 0.5, 0.4, P.BRAISE_COEUR)
	elif str(o.maturite) == "murs" and graine % 2 == 0:
		for i in 2:
			var q := sommet + Vector2((i * 2 - 1) * w * 0.42, 1.2)
			p.disque(q, 1.6, 1.8, ENCRE)
			p.disque(q, 1.1, 1.3, P.BRAISE_ROUGE.lerp(P.SANG, 0.3), Pinceau.DOME)
	if T.a(o, "pyrophyte"):
		# (le pied noirci par les feux passés)
		for i in 5:
			var q := T.sur_tube(tb, 0, lerpf(-0.9, 0.9, (i + r.randf()) / 5.0))
			p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-0.6, 0.6), -r.randf_range(4.0, 9.0))]), 2.4, Color(P.ENCRE, 0.55), false, PackedFloat32Array([2.8, 0.4]))
	# la chair à nu, là où l'on a pris
	var chair := P.IVOIRE.lerp(P.MOUSSE, 0.32).lightened(0.06)
	for k in entames:
		# (là où un bras a été coupé, à sa racine ; sans bras qui reste, une tranche prise au flanc de la colonne)
		var i_bras := tous - 1 - k
		var q: Vector2
		var face: PackedVector2Array
		var cote := -1.0
		if i_bras >= 0:
			# (le bras coupé à sa racine : un moignon qui sort du flanc, sa coupe tournée vers le dehors)
			cote = float(bras[i_bras][0])
			var y := -float(bras[i_bras][1])
			var ep := w * 0.64
			var a0 := Vector2(cote * w * 0.6 + penche * -y, y)
			q = Vector2(cote * (w + 3.4) + penche * -y, y - 0.6)
			var moignon := T.tube(p, PackedVector2Array([a0, q]), PackedFloat32Array([ep, ep]), t.darkened(0.05), Pinceau.DOME, 3, 0.3, false)
			T.cerner_tube(p, moignon, 0.9, 1.4)
			face = Pinceau.ellipse(q, 1.9, ep * 0.98, 14)
		else:
			# (une tranche prise au flanc de la colonne, plus bas : une coupe en biais)
			q = Vector2(-w * 0.3, -h * 0.24)
			face = Pinceau.ellipse(q, 3.4, 2.7, 14)
			for j in face.size():
				face[j] = q + (face[j] - q).rotated(-0.35)
		p.aplat(T.grossi(face, q, 0.75), ENCRE)
		p.aplat(face, chair, Pinceau.DOME, q, Vector2(3.0, 3.0))
		# (la peau autour, ses fibres vertes ; la chair, ses points ; une goutte qui perle et coule)
		p.tracer(Pinceau.ellipse(q, 2.2, 1.6, 12), 0.45, Color(P.MOUSSE.darkened(0.2), 0.7), false)
		p.disque(q + Vector2(-0.5, -0.3), 0.3, 0.3, Color(P.MOUSSE.darkened(0.35), 0.8))
		p.disque(q + Vector2(0.6, 0.2), 0.25, 0.25, Color(P.MOUSSE.darkened(0.35), 0.8))
		var goutte := q + Vector2(cote * 0.4, 2.6 + float(graine % 3))
		p.tracer(PackedVector2Array([q + Vector2(cote * 0.3, 1.5), goutte]), 0.5, Color(P.ECHO.lerp(P.PAPIER, 0.4), 0.7), false)
		p.disque(goutte, 0.55, 0.65, Color(P.ECHO.lerp(P.PAPIER, 0.3), 0.85))


# l'encre et les épines d'un tube de cactus : ses bords (le plus lourd à l'ombre), un trait dans chaque sillon, une aréole
# tous les deux ou trois points sur chaque côte, des épines qui dépassent de la silhouette
static func _habiller_cactus(p, r: RandomNumberGenerator, tb: Dictionary, cotes: int, t: Color, pas: int) -> void:
	var lignes: Array = tb["lignes"]
	for i in range(1, cotes):
		var sillon: PackedVector2Array = lignes[i]
		p.tracer(sillon, 0.65, Color(t.darkened(0.62), 0.55 if i <= cotes / 2 else 0.8), true)
	T.cerner_tube(p, tb, 1.0, 1.7)
	var laine := P.PAPIER.lightened(0.1)
	var n: int = tb["axe"].size()
	var nd: PackedVector2Array = tb["nd"]
	for i in cotes:
		var s := sin(-PI * 0.5 + PI * (i + 0.5) / cotes)
		var k := 1 + (i % 2)
		while k < n - 2:
			var q := T.sur_tube(tb, k, s)
			var dehors: Vector2 = (nd[k] * s * 1.4 + Vector2(0.0, -0.45)).normalized()
			T.areole(p, q, dehors, 1.7 if absf(s) > 0.5 else 1.2, laine)
			k += pas + 1
	# (la silhouette hérissée : des épines sur les deux bords, et au sommet)
	for cote in [-1.0, 1.0]:
		var k := 1
		while k < n - 1:
			var q := T.sur_tube(tb, k, cote)
			var dir: Vector2 = (nd[k] * cote + Vector2(0.0, -0.35)).normalized()
			T.epine(p, q, dir, r.randf_range(1.5, 2.3), 0.6)
			if k % 2 == 0:
				T.epine(p, q, dir.rotated(cote * 0.7), 1.3, 0.5)
			k += 1


# un bras de cactus : il part du fût à l'horizontale, se coude, puis se relève ; côtelé comme la colonne
static func _bras_de_cactus(p, r: RandomNumberGenerator, b: Array, w: float, penche: float, t: Color) -> void:
	var cote: float = b[0]
	var y0 := -float(b[1])
	var y1 := -float(b[2])
	var wa := w * r.randf_range(0.6, 0.7)
	var x0 := cote * w * 0.35 + penche * -y0
	var x1 := cote * float(b[3]) + penche * -y0
	var rayon_coude := absf(x1 - x0) * 0.72
	var axe := PackedVector2Array()
	for k in 7:
		var a := PI * 0.5 * k / 6.0
		axe.append(Vector2(lerpf(x0, x1, sin(a)), y0 - (1.0 - cos(a)) * rayon_coude))
	var haut := minf(y1 + wa, axe[6].y - 3.0)
	var pas := maxi(2, int((axe[6].y - haut) / 4.2))
	for k in range(1, pas + 1):
		axe.append(Vector2(x1 + sin(k * 0.9) * 0.4, lerpf(axe[6].y, haut, float(k) / pas)))
	var rayons := PackedFloat32Array()
	for k in axe.size():
		rayons.append(wa * (0.92 + 0.08 * sin(float(k) / axe.size() * PI)))
	var tb := T.tube(p, axe, rayons, t, Pinceau.DOME, 3, 0.3, true)
	_habiller_cactus(p, r, tb, 3, t, 1)


# -- l'agave --

# un agave : une grande rosette de lames épaisses, bleu-vert, creusées en gouttière, bordées de dents et finies d'un dard
# noir. Celles du fond se dressent, celles des côtés s'étalent, celles de devant viennent vers nous ; au cœur, le cône des
# feuilles encore serrées ; au pied, les vieilles lames sèches. Une sur six porte sa hampe. Entamé, la moitié des lames du
# tour sont coupées (leur coupe pâle, fibreuse) ; tout pris, il ne reste que le cœur
static func agave(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var h: float = o._ry
	var reste: int = o.reste
	var entier: bool = reste >= int(o.plein)
	var t: Color = T.vert_propre(o, P.MOUSSE.lerp(P.LUNE, 0.34).lightened(0.05), 0.2)
	var c0 := Vector2(0, -2.5)
	T.assise(p, Vector2(0.5, 1.0), rx * 0.9, 3.4, P.TERRE.darkened(0.25), 0.4)
	for i in r.randi_range(2, 4):
		T.gravier(p, Vector2(r.randf_range(-rx, rx), r.randf_range(0.0, 3.4)), r.randf_range(0.8, 1.5), P.IVOIRE.lerp(P.CENDRE, 0.3).darkened(r.randf_range(0.0, 0.2)))
	# (les vieilles lames, sèches, couchées au sol)
	var seche := P.TERRE.lerp(P.IVOIRE, 0.38)
	for i in r.randi_range(2, 3):
		var cote := -1.0 if i % 2 == 0 else 1.0
		T.feuille(p, c0 + Vector2(cote * 2.0, 2.0), Vector2(cote * rx * r.randf_range(0.7, 1.0), r.randf_range(0.5, 3.0)), 2.0, seche.darkened(r.randf_range(0.0, 0.15)), cote * 1.2, 0.3, 0.6, 4)
	var feuilles := []
	var nf := r.randi_range(11, 13)
	for i in nf:
		var a := lerpf(-PI + 0.06, -0.06, float(i) / (nf - 1)) + r.randf_range(-0.07, 0.07)
		feuilles.append([a, r.randf_range(0.74, 1.0), 0, i])
	for i in r.randi_range(4, 5):
		feuilles.append([lerpf(0.35, PI - 0.35, (i + r.randf_range(0.2, 0.8)) / 5.0), r.randf_range(0.5, 0.7), 1, i])
	feuilles.sort_custom(func(u, v): return sin(u[0]) < sin(v[0]))
	var mat := entier and int(o.graine) % 6 == 0
	if mat:
		_hampe_d_agave(p, r, c0, h, t)
	for fe in feuilles:
		var a: float = fe[0]
		var l: float = fe[1]
		var devant: bool = int(fe[2]) == 1
		# (ce qu'on a coupé : une lame sur deux du tour, puis toutes)
		var coupee: bool = not entier and (reste <= 0 or int(fe[3]) % 2 == 0)
		var bout := c0 + (Vector2(cos(a) * rx * l, sin(a) * h * l) if not devant else Vector2(cos(a) * rx * l * 0.85, sin(a) * 6.0 * l))
		if coupee:
			bout = c0.lerp(bout, 0.34)
		var face := t.lerp(t.lightened(0.14), clampf(-cos(a) * 0.5 + 0.3, 0.0, 1.0)).darkened(0.1 if devant else 0.0)
		var larg := (2.7 + 0.9 * l) * (1.0 if not coupee else 1.2)
		var pli := (1.0 if cos(a) > 0.0 else -1.0) * (1.6 if not devant else 0.6) * (0.0 if coupee else 1.0)
		var fl: Dictionary = T.feuille_charnue(p, c0, bout, larg, face, pli, 0.3 if not coupee else 0.75, 0.75, 6, 0.3)
		var axe: PackedVector2Array = fl["axe"]
		if axe.size() < 3:
			continue
		var dir := (axe[axe.size() - 1] - axe[axe.size() - 2]).normalized()
		if coupee:
			# (la coupe : une tranche pâle, ses fibres)
			var q: Vector2 = axe[axe.size() - 1] - dir * 0.6
			var tr := dir.orthogonal()
			var coupe := PackedVector2Array([q + tr * larg * 0.62, q + dir * 1.1, q - tr * larg * 0.62, q - dir * 0.5])
			p.aplat(T.grossi(coupe, q, 0.6), ENCRE)
			p.aplat(coupe, P.IVOIRE.lerp(P.MOUSSE, 0.25).lightened(0.08))
			p.tracer(PackedVector2Array([q + tr * larg * 0.3, q - tr * larg * 0.3]), 0.4, Color(P.MOUSSE.darkened(0.3), 0.6), false)
			continue
		# (le liseré pâle des bords, la gouttière ; les dents ; le dard)
		var g: PackedVector2Array = fl["g"]
		var d: PackedVector2Array = fl["d"]
		p.tracer(axe, 0.6, Color(face.darkened(0.42), 0.6), true)
		for k in range(1, axe.size() - 1):
			for bord in [g, d]:
				var q: Vector2 = bord[k]
				var dehors: Vector2 = (q - axe[k]).normalized()
				T.epine(p, q - dehors * 0.2, (dehors + dir * 0.7).normalized(), 1.3, 0.6)
		T.epine(p, axe[axe.size() - 1] - dir * 0.8, dir, 3.2, 1.3)
	# le cœur : le cône des feuilles neuves, serrées, dressées
	for i in 2:
		var bout := c0 + Vector2((i * 2 - 1) * 1.6 + r.randf_range(-0.6, 0.6), -h * r.randf_range(0.62, 0.8) * (1.0 if entier else 0.8))
		var fl: Dictionary = T.feuille_charnue(p, c0 + Vector2((i * 2 - 1) * 0.8, 0.5), bout, 2.0, t.lightened(0.08), (i * 2 - 1) * 0.7, 0.3, 0.65, 5, 0.2)
		var axe: PackedVector2Array = fl["axe"]
		T.epine(p, axe[axe.size() - 1] + Vector2(0, 0.6), Vector2(0, -1), 2.6, 1.1)
	if T.a(o, "rapide") and entier:
		# (des rejets au pied : elle drageonne)
		for i in 2:
			var q := Vector2((i * 2 - 1) * rx * r.randf_range(0.62, 0.8), r.randf_range(1.0, 3.0))
			for j in 4:
				var a := lerpf(-2.6, -0.5, j / 3.0)
				T.feuille_charnue(p, q, q + Vector2(cos(a) * 4.6, sin(a) * 4.8), 1.5, t.lightened(0.1), 0.0, 0.3, 0.6, 4, 0.2)


# la hampe d'un agave en fleurs : un mât qui monte du cœur, ses rameaux en candélabre, leurs bouquets jaunes
static func _hampe_d_agave(p, r: RandomNumberGenerator, c0: Vector2, h: float, t: Color) -> void:
	var haut := h * r.randf_range(2.3, 2.8)
	var sommet := c0 + Vector2(r.randf_range(-3.0, 3.0), -haut)
	var mat := T.courbe(c0, c0.lerp(sommet, 0.5) + Vector2(r.randf_range(-1.5, 1.5), 0.0), sommet, 8)
	p.tracer(mat, 2.6, ENCRE, false, PackedFloat32Array([3.4, 3.2, 3.0, 2.8, 2.6, 2.3, 2.0, 1.7, 1.3]))
	p.tracer(mat, 1.6, t.lerp(P.BRAISE_COEUR, 0.25), false, PackedFloat32Array([2.2, 2.0, 1.9, 1.7, 1.5, 1.3, 1.1, 0.9, 0.6]))
	var fleur := P.BRAISE_COEUR.lerp(P.MOUSSE, 0.2)
	for k in range(4, 9):
		var cote := -1.0 if k % 2 == 0 else 1.0
		var q: Vector2 = mat[k]
		var bout := q + Vector2(cote * r.randf_range(5.0, 8.0) * (1.0 - (k - 4) * 0.12), -r.randf_range(1.5, 3.5))
		p.tracer(PackedVector2Array([q, q.lerp(bout, 0.6) + Vector2(0.0, 1.2), bout]), 1.3, ENCRE, false)
		p.disque(bout + Vector2(0.0, -0.8), 2.7, 1.9, ENCRE)
		p.disque(bout + Vector2(0.0, -0.8), 2.1, 1.4, fleur, Pinceau.DOME)
	p.disque(sommet + Vector2(0.0, -1.0), 2.3, 1.8, ENCRE)
	p.disque(sommet + Vector2(0.0, -1.0), 1.7, 1.3, fleur, Pinceau.DOME)


# -- la plante grasse --

# une plante grasse : une rosette de feuilles charnues et pointues, glauques, le bout rougi ; vue de biais : celles du fond
# se dressent, celles de devant s'étalent vers nous, le cœur est serré. Souvent un rejet ou deux à son côté. Cueillie, la
# rosette est plus maigre : il lui manque des feuilles, leurs cicatrices pâles
static func succulente(o, p, r: RandomNumberGenerator) -> void:
	var entier: bool = o.reste >= o.plein
	var k: float = 1.0 if entier else (0.78 if o.reste > 0 else 0.6)
	var rx: float = (float(o._rx) + 1.5) * k
	# (le vert glauque d'une plante grasse, que le lieu teinte à peine : sur la terre sèche, elle ne pâlit pas en caillou)
	var t: Color = T.vert_propre(o, P.MOUSSE.lerp(P.LUNE, 0.24).darkened(0.04), 0.15)
	var bord := P.BRAISE_ROUGE.lerp(P.PEUR, 0.35).lightened(0.1)
	T.assise(p, Vector2(0.3, 1.0), rx * 0.95, 2.8, P.TERRE.darkened(0.25), 0.35)
	for i in r.randi_range(1, 3):
		T.gravier(p, Vector2(r.randf_range(-rx, rx) * 1.1, r.randf_range(0.5, 3.0)), r.randf_range(0.7, 1.3), P.IVOIRE.lerp(P.CENDRE, 0.3).darkened(r.randf_range(0.0, 0.2)))
	var graine: int = o.graine
	if entier and graine % 3 != 1:
		# (un rejet, plus petit, derrière ou à côté)
		var cote := 1.0 if graine % 2 == 0 else -1.0
		_rosette(p, r, Vector2(cote * rx * 0.86, -1.0 - r.randf_range(0.0, 2.0)), rx * 0.42, t.lightened(0.04), bord, true, 0)
	_rosette(p, r, Vector2(0, -3.6 * k), rx, t, bord, entier, 0 if entier else (1 if o.reste > 0 else 2))


# une rosette charnue : trois rangs de feuilles, du tour au cœur, celles de l'arrière d'abord ; manque : des feuilles prises
static func _rosette(p, r: RandomNumberGenerator, c0: Vector2, rx: float, t: Color, bord: Color, pleine: bool, manque: int) -> void:
	var feuilles := []
	for anneau in 3:
		var n: int = [9, 7, 4][anneau]
		for i in n:
			var a := TAU * i / n + r.randf_range(-0.12, 0.12) + anneau * 0.33
			feuilles.append([a, [1.0, 0.68, 0.4][anneau] * r.randf_range(0.86, 1.0), anneau, i])
	# (de l'arrière vers l'avant ; le cœur, plus haut, par-dessus)
	feuilles.sort_custom(func(u, v): return sin(u[0]) + u[2] * 3.0 < sin(v[0]) + v[2] * 3.0)
	for fe in feuilles:
		var a: float = fe[0]
		var anneau: int = fe[2]
		var l: float = rx * float(fe[1])
		var leve: float = [0.18, 0.42, 0.75][anneau] * rx
		var bout := c0 + Vector2(cos(a) * l, sin(a) * l * 0.45 - leve * (1.0 - sin(a) * 0.45))
		if manque > 0 and anneau == 0 and (manque > 1 or int(fe[3]) % 2 == 0):
			# (une feuille prise : sa cicatrice, pâle)
			var q := c0.lerp(bout, 0.3)
			p.disque(q, 1.2, 0.9, Color(ENCRE, 0.7))
			p.disque(q, 0.8, 0.55, P.IVOIRE.lerp(P.MOUSSE, 0.3))
			continue
		var face := t.lerp(t.darkened(0.24), clampf(sin(a), 0.0, 1.0) * 0.4).lightened(0.05 * anneau)
		var larg := maxf(1.3, rx * (0.26 - 0.03 * anneau))
		var fl: Dictionary = T.feuille_charnue(p, c0, bout, larg, face, 0.0, 0.52, 0.7, 5, 0.0)
		var axe: PackedVector2Array = fl["axe"]
		if axe.size() < 3:
			continue
		# (le bout rougi, une pointe)
		var dir := (axe[axe.size() - 1] - axe[axe.size() - 2]).normalized()
		var g: PackedVector2Array = fl["g"]
		var d: PackedVector2Array = fl["d"]
		p.tracer(PackedVector2Array([g[g.size() - 2], axe[axe.size() - 1] + dir * 0.3, d[d.size() - 2]]), 0.9, Color(bord, 0.9), false)
		if pleine and rx > 6.0:
			T.epine(p, axe[axe.size() - 1], dir, 1.2, 0.6)


# -- le bambou --

# un bambou : une touffe de cannes droites, vert-jaune, lisses (le jour les modèle), nouées d'encre — sous chaque nœud un
# anneau de cire pâle —, la cime qui ploie ; aux nœuds du haut, de fins rameaux et leurs feuilles en lance, en éventail ; au
# pied, les gaines sèches et la litière. Coupé, la moitié des cannes en biseau (leur creux), puis toutes
static func bambou(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var canne: Color = T.vert_propre(o, o.teinte.lerp(P.BRAISE_COEUR, 0.24).lightened(0.06), 1.0)
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1))
	var n := r.randi_range(5, 7)
	var coupees: int = (int(o.plein) - int(o.reste)) * ((n + 1) / 2)
	# (la litière : des feuilles sèches au pied)
	T.assise(p, Vector2(0, 1.2), 12.0, 3.4, P.TERRE.darkened(0.3), 0.45)
	var seche := P.IVOIRE.lerp(P.TERRE, 0.4)
	for i in 5:
		var q := Vector2(r.randf_range(-11.0, 11.0), r.randf_range(0.0, 3.6))
		var d := Vector2.from_angle(r.randf_range(-0.5, 0.5)) * r.randf_range(2.6, 4.0)
		T.feuille(p, q - d, q + d, 0.9, seche.darkened(r.randf_range(0.0, 0.2)), 0.0, 0.45, 0.4, 3)
	var cannes := []
	for i in n:
		var x0 := lerpf(-7.0, 7.0, (i + r.randf_range(0.2, 0.8)) / n)
		cannes.append([x0, r.randf_range(-1.6, 1.8), r.randf_range(0.72, 1.0), r.randf_range(1.7, 2.4), r.randf_range(-0.07, 0.07) + x0 * 0.006, r.randf(), i])
	cannes.sort_custom(func(u, v): return u[1] < v[1])
	if T.a(o, "rapide") and coupees == 0:
		# (un turion : la pousse de l'année, un cône brun dans ses gaines)
		var q := Vector2(r.randf_range(-9.0, 9.0), 2.0)
		var cone := PackedVector2Array([q + Vector2(-2.0, 0.5), q + Vector2(-1.4, -4.0), q + Vector2(0.2, -8.5), q + Vector2(1.6, -4.0), q + Vector2(2.0, 0.5)])
		p.aplat(T.grossi(cone, q + Vector2(0, -3.5), 0.7), ENCRE)
		p.aplat(cone, P.TERRE.lerp(P.BRAISE, 0.2), Pinceau.DOME, q + Vector2(0, -3.5), Vector2(2.2, 5.0))
		for j in 3:
			p.tracer(PackedVector2Array([q + Vector2(-1.6, -1.5 - j * 2.0), q + Vector2(1.4, -2.6 - j * 2.0)]), 0.5, Color(ENCRE, 0.6))
	var rang := 0
	for ca in cannes:
		var x0: float = ca[0]
		var y0: float = ca[1]
		var hh: float = h * float(ca[2])
		var w: float = ca[3]
		var penche: float = ca[4]
		var ton := canne.darkened(0.1 * (1.0 - float(rang) / n)).lerp(P.MOUSSE, 0.12 * float(ca[5]))
		rang += 1
		if int(ca[6]) < coupees:
			_canne_coupee(p, r, Vector2(x0, y0 + 1.0), w, ton)
			continue
		# (l'axe : droit, puis la cime qui ploie du côté où elle penche)
		var m := maxi(8, int(hh / 3.6))
		var axe := PackedVector2Array()
		var rayons := PackedFloat32Array()
		var sens := 1.0 if penche >= 0.0 else -1.0
		for k in m + 1:
			var u := float(k) / m
			var ploie := smoothstep(0.62, 1.0, u)
			axe.append(Vector2(x0 + penche * hh * u + sens * ploie * ploie * hh * 0.055, y0 + 1.0 - hh * u * (1.0 - 0.03 * ploie)))
			rayons.append(w * (1.0 - 0.62 * u * u))
		var tb := T.tube(p, axe, rayons, ton, Pinceau.DOME, 1, 0.0, false)
		T.cerner_tube(p, tb, 0.8, 1.3)
		# les nœuds : un anneau d'encre, la cire pâle dessous ; plus bas, les gaines sèches ; plus haut, les rameaux
		var k := r.randi_range(2, 3)
		var noeud := 0
		while k < m - 1:
			var q: Vector2 = axe[k]
			var wr: float = rayons[k]
			var nd: Vector2 = tb["nd"][k]
			var tg := nd.orthogonal()
			var a0 := q - nd * (wr + 0.4)
			var b0 := q + nd * (wr + 0.4)
			p.bande(PackedVector2Array([a0 - tg * 0.2, b0 - tg * 0.2]), PackedVector2Array([a0 - tg * 1.5, b0 - tg * 1.5]), Color(P.PAPIER, 0.3))
			p.tracer(PackedVector2Array([a0, q - tg * 0.5, b0]), 0.9, ENCRE, false)
			var u := float(k) / m
			if u < 0.4 and noeud % 2 == 0 and float(ca[5]) > 0.4:
				# (une gaine sèche, encore accrochée)
				var cote := -1.0 if noeud % 4 == 0 else 1.0
				var gaine := PackedVector2Array([q + nd * cote * wr * 0.2, q + nd * cote * (wr + 2.2) - tg * 3.0, q + nd * cote * (wr + 0.8) - tg * 6.5])
				p.aplat(T.grossi(gaine, (gaine[0] + gaine[1] + gaine[2]) / 3.0, 0.55), ENCRE)
				p.aplat(gaine, seche.lerp(P.BRAISE, 0.1))
			elif u > 0.42 and r.randf() < 0.8:
				var cote := -1.0 if (noeud + int(ca[6])) % 2 == 0 else 1.0
				var bout := q + nd * cote * r.randf_range(4.5, 8.0) - tg * r.randf_range(0.5, 3.5)
				p.tracer(PackedVector2Array([q, bout]), 0.9, Color(ENCRE, 0.85), false)
				p.tracer(PackedVector2Array([q, bout]), 0.4, ton.darkened(0.15), false)
				for j in r.randi_range(3, 4):
					var ang := (bout - q).angle() + (j - 1.5) * 0.52 + 0.25
					var fb := bout + Vector2.from_angle(ang) * r.randf_range(4.5, 7.0) + Vector2(0.0, 1.4)
					T.feuille(p, bout.lerp(q, 0.25 * (j % 2)), fb, 1.2, t.lightened(r.randf_range(0.0, 0.14)), cote * 0.8, 0.36, 0.5, 4)
			k += r.randi_range(2, 3)
			noeud += 1
		# (la cime : un plumet de feuilles)
		var cime: Vector2 = axe[m]
		for j in 3:
			var ang := -PI * 0.5 + sens * (0.5 + j * 0.55)
			T.feuille(p, cime, cime + Vector2.from_angle(ang) * r.randf_range(5.0, 7.5) + Vector2(0.0, 1.5), 1.2, t.lightened(0.1), sens * 0.6, 0.36, 0.5, 4)
		if T.a(o, "echasses") and rang % 2 == 0:
			# (des racines-échasses au premier nœud : une couronne de petites racines qui plongent)
			var q: Vector2 = axe[1]
			for j in 4:
				var cote := -1.0 if j % 2 == 0 else 1.0
				var bas := Vector2(q.x + cote * (w + 1.5 + j), y0 + 1.6)
				p.tracer(PackedVector2Array([q, Vector2(bas.x, q.y + 0.5), bas]), 1.2, ENCRE, false)
	if T.enneigee(o):
		T.congere(p, Vector2(0.0, 2.2), 11.0, 3.2)


# une canne coupée en biseau : son moignon, la coupe claire, le creux noir
static func _canne_coupee(p, r: RandomNumberGenerator, pied: Vector2, w: float, ton: Color) -> void:
	var haut := r.randf_range(4.5, 8.0)
	var axe := PackedVector2Array([pied, pied + Vector2(0.0, -haut)])
	var tb := T.tube(p, axe, PackedFloat32Array([w, w]), ton.darkened(0.08), Pinceau.DOME, 1, 0.0, false)
	T.cerner_tube(p, tb, 0.8, 1.2)
	var q := pied + Vector2(0.0, -haut)
	p.disque(q, w + 0.5, 1.5, ENCRE)
	p.disque(q, w, 1.1, P.IVOIRE.lerp(ton, 0.25))
	p.disque(q, w * 0.5, 0.55, P.ENCRE)
	p.tracer(PackedVector2Array([pied + Vector2(-w - 0.3, -haut * 0.45), pied + Vector2(w + 0.3, -haut * 0.45 + 0.4)]), 0.8, ENCRE, false)


# -- le roseau --

# un roseau : de hautes tiges droites qui sortent d'un sol mouillé, leurs feuilles en ruban qui s'arquent (une ou deux
# cassées), et leurs quenouilles — un manchon de velours brun, sa pointe ; l'une d'elles, mûre, s'effiloche en bourre. Coupé :
# moins de tiges, puis des chaumes
static func roseau(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.25).lightened(0.05)
	var paille := t.lerp(P.IVOIRE, 0.42)
	# (le sol mouillé, ses reflets)
	T.assise(p, Vector2(0, 1.6), 13.0, 3.8, P.NUIT_BLEUE.lerp(P.TERRE, 0.45), 0.5)
	p.tracer(PackedVector2Array([Vector2(-9.0, 1.2), Vector2(-4.5, 0.9)]), 0.6, Color(P.PAPIER, 0.3))
	p.tracer(PackedVector2Array([Vector2(4.0, 3.2), Vector2(8.5, 3.0)]), 0.6, Color(P.PAPIER, 0.25))
	if o.reste <= 0:
		chaumes(p, r, paille, 8.0, 5.5)
		return
	var entier: bool = o.reste >= o.plein
	var n := r.randi_range(8, 10) if entier else r.randi_range(4, 5)
	var tiges := []
	for i in n:
		var x0 := r.randf_range(-5.5, 5.5)
		var hh := h * r.randf_range(0.74, 1.02)
		tiges.append([x0, r.randf_range(-1.0, 2.2), hh, x0 * 0.5 + r.randf_range(-3.5, 3.5), r.randf(), i])
	tiges.sort_custom(func(u, v): return u[1] < v[1])
	var bourre := false
	var rang := 0
	for tg in tiges:
		var pied := Vector2(tg[0], float(tg[1]) + 1.0)
		var hh: float = tg[2]
		var tete := pied + Vector2(float(tg[3]), -hh)
		var avant := float(rang) / n
		rang += 1
		var ton := t.lerp(paille, avant * 0.35).darkened((1.0 - avant) * 0.2)
		var ligne := T.courbe(pied, pied.lerp(tete, 0.5) + Vector2(float(tg[3]) * -0.15, 0.0), tete, 6)
		# les feuilles : deux rubans qui quittent la tige et s'arquent ; l'un casse
		for j in 2:
			var k := 1 + j + int(float(tg[4]) * 2.0)
			var depart: Vector2 = ligne[mini(k, 4)]
			var cote := -1.0 if (j + int(tg[5])) % 2 == 0 else 1.0
			var long := hh * r.randf_range(0.4, 0.6)
			var bout := depart + Vector2(cote * long * r.randf_range(0.35, 0.6), -long * r.randf_range(0.45, 0.8))
			if j == 1 and float(tg[4]) > 0.62:
				# (cassée : elle monte, puis pend)
				var pli := depart.lerp(bout, 0.55)
				T.feuille(p, depart, pli, 1.25, ton.lightened(0.05), cote * 1.5, 0.3, 0.5, 4)
				T.feuille(p, pli, pli + Vector2(cote * long * 0.2, long * 0.34), 1.0, ton.darkened(0.08), 0.0, 0.2, 0.5, 3)
			else:
				T.feuille(p, depart, bout, 1.3, ton.lightened(0.05), cote * long * 0.14, 0.26, 0.5, 5)
		p.tracer(ligne, 1.9, ENCRE, false, PackedFloat32Array([2.2, 2.1, 2.0, 1.8, 1.6, 1.4, 1.2]))
		p.tracer(ligne, 1.1, ton, false, PackedFloat32Array([1.4, 1.3, 1.2, 1.0, 0.9, 0.7, 0.5]))
		if int(tg[5]) % 5 == 4 and n > 5:
			continue
		# la quenouille : un manchon de velours brun, juste sous la pointe de la tige
		var dir := (ligne[6] - ligne[5]).normalized()
		var bas: Vector2 = tete - dir * r.randf_range(8.5, 10.5)
		var haut: Vector2 = tete - dir * 2.6
		var brun := P.TERRE.lerp(P.ENCRE_DOUCE, 0.25).lerp(P.BRAISE, 0.12)
		var rq := r.randf_range(1.55, 1.95)
		var q0 := T.tube(p, PackedVector2Array([bas, bas.lerp(haut, 0.5), haut]), PackedFloat32Array([rq, rq, rq * 0.92]), brun, Pinceau.DOME, 1, 0.0, true, 0.2)
		T.cerner_tube(p, q0, 0.8, 1.2)
		p.disque(bas, rq, 0.7, ENCRE)
		p.tracer(PackedVector2Array([haut + dir * 1.2, tete + dir * 2.4]), 0.8, ENCRE, false, PackedFloat32Array([0.9, 0.3]))
		if not bourre and (T.a(o, "vent") or T.a(o, "graines_abondantes") or float(tg[4]) > 0.86):
			# (mûre : elle s'effiloche, sa bourre part au vent)
			bourre = true
			var c0 := bas.lerp(haut, 0.6)
			for j in 5:
				var f := c0 + Vector2(1.6 + j * 0.9, -0.8 + sin(j * 2.1) * 1.4)
				p.disque(f, 1.5 - j * 0.14, 1.1 - j * 0.1, Color(P.PAPIER.lightened(0.15), 0.85 - j * 0.1))
	if T.enneigee(o):
		T.congere(p, Vector2(0.0, 2.4), 9.0, 2.8)


# -- le jonc --

# un jonc : une fontaine de brins ronds, raides, vert sombre, qui partent d'un pied serré dans ses gaines rousses ; sur
# quelques-uns, un glomérule de fleurs brunes sort du flanc, sous la pointe. Coupé : la moitié des brins, puis des chaumes
static func jonc(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, 0.3))
	T.assise(p, Vector2(0, 1.4), 9.0, 2.8, P.NUIT_BLEUE.lerp(P.TERRE, 0.5), 0.42)
	if o.reste <= 0:
		chaumes(p, r, t.lerp(P.IVOIRE, 0.3), 5.0, 4.0)
		return
	var entier: bool = o.reste >= o.plein
	var socle := 0.0
	if T.a(o, "echasses"):
		# (un touradon : le pied de la touffe s'est haussé sur ses vieilles racines, au-dessus de l'eau)
		socle = 4.0
		var motte := PackedVector2Array()
		for i in 9:
			var ang := PI + PI * i / 8.0
			motte.append(Vector2(cos(ang) * 5.6, 1.2 + sin(ang) * 5.0))
		motte.append(Vector2(4.6, 1.8))
		motte.append(Vector2(-4.6, 1.8))
		p.aplat(motte, P.ENCRE_DOUCE.lerp(P.TERRE, 0.45), Pinceau.ECORCE, Vector2(0, -1.0), Vector2(5.6, 4.0))
		p.contour(motte, 1.0, ENCRE, r, 2)
		for i in 5:
			var x := lerpf(-4.6, 4.6, (i + r.randf_range(0.2, 0.8)) / 5.0)
			p.tracer(PackedVector2Array([Vector2(x * 0.7, -3.0), Vector2(x, 1.6)]), 0.6, Color(ENCRE, 0.55))
	var brins := []
	var n := r.randi_range(19, 23) if entier else r.randi_range(9, 11)
	for i in n:
		var x0 := r.randf_range(-3.2, 3.2)
		brins.append([x0, Vector2(x0 * r.randf_range(2.2, 3.0) + r.randf_range(-1.5, 1.5), -h * r.randf_range(0.7, 1.05) - socle), r.randf()])
	brins.sort_custom(func(u, v): return u[2] < v[2])
	var glomerules := 0
	var voulus := 7 if T.a(o, "graines_abondantes") else 5
	for i in brins.size():
		var b: Array = brins[i]
		var pied := Vector2(b[0], 1.0 - socle)
		var tete: Vector2 = b[1]
		var ligne := T.courbe(pied, Vector2(pied.x + (tete.x - pied.x) * 0.2, lerpf(pied.y, tete.y, 0.6)), tete, 5)
		var avant := float(i) / brins.size()
		if avant > 0.3:
			p.tracer(ligne, 2.0, ENCRE, false, PackedFloat32Array([2.1, 2.0, 1.8, 1.6, 1.3, 0.9]))
		var ton := t.lightened(0.2 * avant).darkened(0.12 * (1.0 - avant))
		p.tracer(ligne, 1.1, ton, false, PackedFloat32Array([1.3, 1.2, 1.1, 0.9, 0.7, 0.35]))
		if avant > 0.6 and i % 3 == 0:
			# (le brin est rond : un fil de jour le long)
			var clair := PackedVector2Array()
			for q in ligne:
				clair.append(q + Vector2(-0.35, 0.0))
			p.tracer(clair, 0.4, Color(ton.lightened(0.35), 0.7), true)
		if avant > 0.35 and glomerules < voulus and i % 2 == 1:
			# (le glomérule : quelques fleurs brunes serrées, sur le flanc, aux trois quarts du brin)
			glomerules += 1
			var q: Vector2 = ligne[4].lerp(ligne[3], r.randf_range(0.0, 0.7))
			var cote := 1.0 if tete.x >= pied.x else -1.0
			for g in r.randi_range(4, 5):
				var f := q + Vector2(cote * r.randf_range(0.6, 2.8), r.randf_range(-1.6, 1.2))
				p.tracer(PackedVector2Array([q, f]), 0.45, Color(ENCRE, 0.7), false)
				p.disque(f, 1.15, 1.1, ENCRE)
				p.disque(f, 0.75, 0.7, P.TERRE.lerp(P.BRAISE, 0.28), Pinceau.DOME)
	# (les gaines du pied : rousses, serrées)
	for i in 5:
		var x := lerpf(-3.4, 3.4, i / 4.0)
		var gaine := PackedVector2Array([Vector2(x, 1.2 - socle), Vector2(x * 1.25, -3.6 - socle - r.randf_range(0.0, 1.5))])
		p.tracer(gaine, 2.3, ENCRE, false, PackedFloat32Array([2.5, 1.2]))
		p.tracer(gaine, 1.4, P.TERRE.lerp(P.BRAISE_ROUGE, 0.25).lerp(t, 0.2), false, PackedFloat32Array([1.6, 0.5]))
	if T.enneigee(o):
		T.congere(p, Vector2(0.0, 2.0), 7.5, 2.4)


# -- les graminées à grains --

# une graminée à grains : une gerbe de lames (deux tons, leur nervure), et des tiges nouées au bout desquelles l'épi pèse —
# ses grains en deux rangs, ses longues barbes ; le riz : des panicules qui retombent en arc, leurs grains pendus, sur un sol
# mouillé. Mûrs (l'été, l'automne), les épis sont lourds et dorés, la touffe jaunit : on les cueille d'abord (des grains), et il
# ne reste que les tiges, coupées net ; puis la paille (une fibre), et des chaumes. Au printemps, les épis sont verts et
# droits ; l'hiver, il n'y en a plus
static func cereale(o, p, r: RandomNumberGenerator, riz: bool) -> void:
	var h: float = o._ry
	var murs: bool = o.epis_murs
	var t: Color = o.teinte.lightened(0.05)
	var paille := t.lerp(P.IVOIRE, 0.4).lerp(P.BRAISE_COEUR, 0.15)
	if murs:
		# (la touffe mûre se dore)
		paille = paille.lerp(P.BRAISE_COEUR, 0.22).lerp(P.BRAISE, 0.08)
		t = t.lerp(paille, 0.32)
	var grain := P.BRAISE.lerp(P.IVOIRE, 0.45).darkened(0.08) if not riz else P.IVOIRE.lerp(P.BRAISE_COEUR, 0.2).darkened(0.05)
	if not murs:
		grain = t.lightened(0.18).lerp(P.MOUSSE, 0.2)
	if riz:
		T.assise(p, Vector2(0, 1.5), 13.0, 3.6, P.NUIT_BLEUE.lerp(P.TERRE, 0.5), 0.48)
		p.tracer(PackedVector2Array([Vector2(-8.0, 1.0), Vector2(-4.0, 0.8)]), 0.6, Color(P.PAPIER, 0.28))
	else:
		T.assise(p, Vector2(0, 1.2), 7.5, 2.4, P.TERRE.darkened(0.3), 0.35)
	if o.reste <= 0:
		chaumes(p, r, paille, 5.0, 4.5)
		return
	var epis: bool = o.reste >= o.plein and str(o.maturite) != ""
	var beaucoup := T.a(o, "graines_abondantes")
	# les lames : en gerbe, celles du fond d'abord
	for i in 10:
		var x0 := r.randf_range(-3.0, 3.0)
		var cote := signf(x0 + r.randf_range(-0.5, 0.5))
		var hh := r.randf_range(0.42, 0.7) * h
		var bout := Vector2(x0 * 2.0 + cote * r.randf_range(3.0, 9.5) * (1.4 if riz else 1.0), -hh * (0.75 if riz else 1.0))
		var ton := t.lerp(paille, r.randf() * 0.4).darkened(r.randf() * 0.15 + (0.12 if i < 4 else 0.0))
		T.feuille(p, Vector2(x0, 1.0), bout, 1.35, ton, cote * hh * 0.16, 0.26, 0.5 if i >= 4 else 0.0, 5)
	# les tiges et leurs épis : un épi dressé qui ploie au bout, ses grains en deux rangs et ses barbes ; le riz, une panicule
	# qui retombe en arc, ses grains pendus dessous. Mûr, l'épi est plus lourd, et ploie davantage
	var poids := 1.0 if not murs else (1.25 if riz else 1.9)
	for i in r.randi_range(5, 7) if beaucoup else r.randi_range(4, 6):
		var x0 := r.randf_range(-2.5, 2.5)
		var hh := h * r.randf_range(0.8, 1.05)
		var penche := r.randf_range(0.08, 0.25) * (1.0 if r.randf() < 0.5 else -1.0) * (1.0 if not murs else 1.35)
		var mi := Vector2(x0 + penche * hh * 0.4, -hh * 0.55)
		if not epis:
			# (les épis cueillis : la tige coupée net, un peu plus bas, sa coupe claire)
			var haut := Vector2(x0 + penche * hh * 0.7, -hh * 0.78)
			var tige := PackedVector2Array([Vector2(x0, 1.0), Vector2(x0 + penche * hh * 0.3, -hh * 0.42), haut])
			p.tracer(tige, 1.7, ENCRE, false)
			p.tracer(tige, 0.9, paille, false)
			p.tracer(PackedVector2Array([haut + Vector2(-0.8, 0.3), haut + Vector2(0.8, -0.3)]), 0.6, P.IVOIRE.lightened(0.1), false)
			continue
		var bout := Vector2(x0 + penche * hh, -hh)
		var ligne := PackedVector2Array([Vector2(x0, 1.0), mi, bout])
		p.tracer(ligne, 1.7, ENCRE, false)
		p.tracer(ligne, 0.9, paille, false)
		# (un nœud, et la feuille qui en part)
		p.tracer(PackedVector2Array([mi + Vector2(-1.0, 0.2), mi + Vector2(1.0, -0.2)]), 0.8, Color(ENCRE, 0.8), false)
		T.feuille(p, mi, mi + Vector2(-signf(penche) * r.randf_range(4.0, 6.5), -r.randf_range(2.0, 4.5)), 1.0, t.lerp(paille, 0.3), 0.0, 0.3, 0.45, 4)
		var dir := (bout - mi).normalized()
		var epi := PackedVector2Array([bout])
		for k in range(1, (9 if riz else 7) + (1 if murs else 0)):
			var u := float(k)
			# (le poids du grain le fait ployer ; le riz, jusqu'à pendre)
			epi.append(bout + dir * u * (1.6 if riz else 1.5) + Vector2(signf(penche) * u * u * (0.12 if riz else 0.05) * poids, u * u * (0.22 if riz else 0.04) * poids))
		p.tracer(epi, 1.2, ENCRE, false)
		for k in range(1, epi.size()):
			var q := epi[k]
			var d := (epi[k] - epi[k - 1]).normalized()
			var nrm := d.orthogonal()
			if riz:
				# (deux grains pendus à chaque étage, sur leurs fils)
				for j in 2:
					var g := q + Vector2((j * 2 - 1) * 0.9, 1.3 + j * 0.9)
					p.tracer(PackedVector2Array([q, g]), 0.4, Color(ENCRE, 0.6), false)
					p.disque(g, 1.0, 1.35, ENCRE)
					p.disque(g, 0.65, 0.95, grain, Pinceau.DOME)
				continue
			for cote in [-1.0, 1.0]:
				var g: Vector2 = q + nrm * cote * (0.95 if murs else 0.7)
				var gr := 1.0 if murs else 0.8
				p.disque(g, 1.3 * gr, 1.3 * gr, ENCRE)
				p.disque(g, 0.9 * gr, 0.9 * gr, grain if cote * nrm.dot(T.JOUR) > 0.0 else grain.darkened(0.14), Pinceau.DOME)
				# (les barbes)
				p.tracer(PackedVector2Array([g, g + nrm * cote * 1.3 + d * 3.6]), 0.45, Color(ENCRE, 0.62))
	if T.enneigee(o):
		T.congere(p, Vector2(0.0, 2.0), 7.0, 2.4)


# -- le papyrus --

# un papyrus : de hautes tiges nues, à trois pans, chacune coiffée d'une ombelle — une sphère de fins rayons, plus clairs du
# côté du jour, piqués d'épillets roux —, sur un sol mouillé
static func papyrus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lightened(0.06)
	T.assise(p, Vector2(0, 1.5), 12.0, 3.6, P.NUIT_BLEUE.lerp(P.TERRE, 0.5), 0.46)
	if o.reste <= 0:
		chaumes(p, r, t.lerp(P.IVOIRE, 0.3), 7.0, 5.0)
		return
	var tiges := []
	for i in (r.randi_range(5, 7) if o.reste >= o.plein else 3):
		var x0 := r.randf_range(-4.0, 4.0)
		tiges.append([x0, h * r.randf_range(0.7, 1.0), r.randf_range(-3.0, 3.0), r.randf()])
	tiges.sort_custom(func(u, v): return u[1] > v[1])
	for tg in tiges:
		var x0: float = tg[0]
		var hh: float = tg[1]
		var bout := Vector2(x0 * 1.8 + float(tg[2]), -hh)
		var ligne := T.courbe(Vector2(x0, 1.0), Vector2(x0 * 1.2, -hh * 0.5), bout, 5)
		p.tracer(ligne, 2.1, ENCRE, false, PackedFloat32Array([2.4, 2.2, 2.0, 1.8, 1.6, 1.4]))
		p.tracer(ligne, 1.2, t.darkened(0.12), false, PackedFloat32Array([1.5, 1.4, 1.2, 1.1, 0.9, 0.8]))
		var clair := PackedVector2Array()
		for q in ligne:
			clair.append(q + Vector2(-0.4, 0.0))
		p.tracer(clair, 0.4, Color(t.lightened(0.3), 0.7), true)
		# l'ombelle : les bractées dessous, puis les rayons, ceux du fond d'abord
		for k in 4:
			var a := PI * 0.5 + (k - 1.5) * 0.7
			T.feuille(p, bout, bout + Vector2(cos(a) * 4.6, sin(a) * 2.6 + 1.0), 0.9, t.darkened(0.1), 0.0, 0.4, 0.4, 3)
		var rayons := 16
		for k in rayons:
			var a := -PI * 0.5 + (float(k) / (rayons - 1) - 0.5) * PI * 1.6
			var l := r.randf_range(5.5, 8.5)
			var q := bout + Vector2(cos(a) * l, sin(a) * l * 0.62 + l * 0.26 * absf(cos(a)))
			p.tracer(PackedVector2Array([bout, q]), 0.8, t.lightened(0.2) if cos(a) < 0.1 else t.darkened(0.06), false)
			if k % 3 == 1:
				p.disque(q, 0.7, 0.6, P.TERRE.lerp(P.BRAISE, 0.35))
		p.disque(bout, 1.0, 0.8, t.darkened(0.3))


# -- la fougère --

# une fougère : des frondes qui partent du pied en couronne, penne à penne, celles du fond d'abord, leur nervure claire ; au
# cœur, des crosses qui se déroulent ; au pied, une vieille fronde rousse. Cueillie : des stipes coupés
static func fougere(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = T.feuillage(o, o.teinte.lerp(P.MOUSSE, 0.4).lightened(0.08))
	T.assise(p, Vector2(0, 1.0), 9.0, 2.6, P.TERRE.darkened(0.3), 0.35)
	if o.reste <= 0:
		chaumes(p, r, t.lerp(P.TERRE, 0.4), 4.0, 3.5)
		return
	var entier: bool = o.reste >= o.plein
	var pied := Vector2(0, -1.5)
	# (une fronde morte, rousse, couchée)
	Arbres._palme(p, r, pied, r.randf_range(0.1, 0.4) if int(o.graine) % 2 == 0 else PI - r.randf_range(0.1, 0.4), h * 0.7, 0.0, 3.0, P.TERRE.lerp(P.BRAISE, 0.25).darkened(0.08), true, 0.5)
	var frondes := []
	var n := r.randi_range(7, 9) if entier else r.randi_range(4, 5)
	for i in n:
		frondes.append([lerpf(-PI + 0.3, -0.3, float(i) / (n - 1)) + r.randf_range(-0.12, 0.12), r.randf_range(0.82, 1.1) * h])
	frondes.append([r.randf_range(0.25, 0.5), h * 0.62])
	frondes.append([PI - r.randf_range(0.25, 0.5), h * 0.62])
	frondes.sort_custom(func(u, v): return sin(u[0]) < sin(v[0]))
	for fr in frondes:
		var a: float = fr[0]
		var l: float = fr[1]
		var face := t.lerp(t.lightened(0.18), clampf(-sin(a), 0.0, 1.0) * 0.5 + 0.15)
		Arbres._palme(p, r, pied, a, l, l * 0.34, l * 0.22, face, true, 0.62)
	# (les crosses, au cœur)
	for i in 2:
		var q := pied + Vector2((i * 2 - 1) * 1.8, -1.0)
		var spi := PackedVector2Array()
		for k in 10:
			var u := k / 9.0
			var ang := -PI * 0.5 + u * TAU * 1.1 * (1.0 if i == 0 else -1.0)
			spi.append(q + Vector2(0, -5.0 * (1.0 - u)) + Vector2(cos(ang), sin(ang)) * (1.9 * u))
		p.tracer(spi, 1.6, ENCRE, false)
		p.tracer(spi, 0.8, t.lightened(0.3).lerp(P.BRAISE_COEUR, 0.2), false)
	if T.a(o, "mellifere") and not Flore.SANS_FLEURS.has(str(o.stade).to_lower()):
		# (Orvane la dit mellifère : de petites grappes pâles entre les frondes)
		for i in 3:
			var q := pied + Vector2(r.randf_range(-0.6, 0.6) * h, -r.randf_range(0.25, 0.6) * h)
			for j in 3:
				p.disque(q + Vector2.from_angle(j * 2.1) * 1.1, 0.8, 0.7, P.PAPIER.lightened(0.1))
	if T.enneigee(o):
		T.congere(p, Vector2(0.0, 1.8), 8.0, 2.4)


# -- la légumineuse --

# une légumineuse : basse, des tiges qui s'étalent et leurs feuilles par trois (trois folioles, deux tons), des vrilles, des
# gousses bosselées qui pendent, des fleurs en papillon (l'étendard pâle, la carène plus sombre)
static func legumineuse(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = T.feuillage(o, o.teinte.lightened(0.04))
	T.assise(p, Vector2(0, 1.0), rx * 0.8, 2.4, P.TERRE.darkened(0.3), 0.32)
	if o.reste <= 0:
		chaumes(p, r, t.lerp(P.IVOIRE, 0.3), 3.5, 4.0)
		return
	var tiges := []
	for i in (7 if o.reste >= o.plein else 4):
		var a0 := Vector2(r.randf_range(-2.0, 2.0), 1.0)
		var b0 := Vector2(lerpf(-rx, rx, (i + r.randf_range(0.1, 0.9)) / 7.0), -r.randf_range(ry * 0.45, ry))
		tiges.append([a0, b0])
	tiges.sort_custom(func(u, v): return u[1].y < v[1].y)
	var fleur: Color = P.PAPIER if int(o.graine) % 2 == 0 else P.PEUR.lerp(P.PAPIER, 0.4)
	var rang := 0
	for tg in tiges:
		var a0: Vector2 = tg[0]
		var b0: Vector2 = tg[1]
		var ligne := T.courbe(a0, (a0 + b0) * 0.5 + Vector2(0, -2.0), b0, 5)
		p.tracer(ligne, 1.4, Color(ENCRE, 0.8), false)
		p.tracer(ligne, 0.7, t.darkened(0.25), false)
		# (ses feuilles : trois folioles au bout, trois autres à mi-tige)
		for q in [ligne[3], b0]:
			var vers := -PI * 0.5 + (b0.x - a0.x) * 0.04
			for j in 3:
				var ang := vers + (j - 1) * 0.95
				T.feuille(p, q, q + Vector2.from_angle(ang) * r.randf_range(2.8, 3.6), 1.35, t.lightened(0.05 * j), 0.0, 0.55, 0.5, 3)
		if rang % 2 == 0:
			# (une gousse : elle pend, bosselée de ses graines)
			var q0: Vector2 = ligne[2]
			var sens := 1.0 if b0.x >= a0.x else -1.0
			var gousse := T.courbe(q0, q0 + Vector2(sens * 2.4, 1.6), q0 + Vector2(sens * 3.6, 4.6), 4)
			p.tracer(gousse, 2.7, ENCRE, false, PackedFloat32Array([1.6, 2.8, 2.9, 2.6, 1.2]))
			p.tracer(gousse, 1.7, t.lerp(P.BRAISE_COEUR, 0.3), false, PackedFloat32Array([0.8, 1.9, 2.0, 1.7, 0.5]))
			for k in range(1, 4):
				p.disque(gousse[k] + Vector2(-0.3, -0.2), 0.45, 0.4, Color(P.PAPIER, 0.4))
		elif not Flore.SANS_FLEURS.has(str(o.stade).to_lower()):
			# (une fleur en papillon)
			var q0: Vector2 = b0 + Vector2(0, -2.8)
			p.disque(q0, 1.9, 1.6, ENCRE)
			p.disque(q0 + Vector2(0.0, -0.3), 1.4, 1.1, fleur, Pinceau.DOME)
			p.disque(q0 + Vector2(0.2, 0.7), 0.9, 0.6, fleur.darkened(0.25))
		else:
			# (une vrille)
			var q0: Vector2 = b0
			var vrille := PackedVector2Array()
			for k in 7:
				vrille.append(q0 + Vector2(k * 0.5 + sin(k * 1.4) * 1.0, -k * 0.6 + cos(k * 1.4) * 0.8))
			p.tracer(vrille, 0.5, Color(t.darkened(0.3), 0.9), false)
		rang += 1


# -- les coussins, les mousses, les lichens, la plante-caillou --

# une plante en coussin : un dôme serré, ras, fait de mille rosettes (des arcs d'encre du côté de l'ombre), piqué de toutes
# petites fleurs ; à son pied, la pierraille ; poudré de neige s'il fait froid
static func coussin(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = float(o._ry) * 0.85
	var t: Color = T.feuillage(o, o.teinte.lerp(P.MOUSSE, 0.3))
	var centre := Vector2(0, -ry * 0.6)
	for i in r.randi_range(2, 3):
		T.gravier(p, Vector2(r.randf_range(-rx, rx) * 1.15, r.randf_range(0.2, 2.6)), r.randf_range(0.8, 1.4), P.IVOIRE.lerp(P.CENDRE, 0.4).darkened(r.randf_range(0.0, 0.2)))
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(9, 12), 0.08, r, 40, 0.15)
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.25)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	for i in 6:
		var q := centre + Vector2(r.randf_range(-0.1, 0.75) * rx, r.randf_range(-0.2, 0.6) * ry)
		var arc := PackedVector2Array()
		for k in 4:
			var a := 0.2 + k * 0.4
			arc.append(q + Vector2(cos(a), sin(a) * 0.8) * 1.8)
		p.tracer(arc, 0.6, Color(ENCRE, 0.42))
	for i in 8:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.6, 0.6) * ry)
		p.disque(q, 0.5, 0.5, Color(ENCRE, 0.3))
	if o.reste > 0 and not Flore.SANS_FLEURS.has(str(o.stade).to_lower()):
		var fleur: Color = P.PAPIER.lightened(0.1) if int(o.graine) % 3 != 0 else P.PEUR.lerp(P.PAPIER, 0.5)
		if T.a(o, "mellifere"):
			fleur = P.BRAISE_COEUR.lerp(P.PAPIER, 0.25)
		for i in (16 if T.a(o, "mellifere") or T.a(o, "graines_abondantes") else 10):
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.8, 0.2) * ry)
			p.disque(q, 1.05, 0.95, Color(ENCRE, 0.45))
			p.disque(q, 0.8, 0.7, fleur)
	T.neige(o, p, poly, centre, rx, ry, r, 0.5)
	p.contour(poly, 1.1, ENCRE, r, 3)


# une mousse : des coussinets ras, d'un vert vif, serrés les uns contre les autres ; de l'un ou l'autre montent des soies
# fines, leur capsule au bout
static func mousse(o, p, r: RandomNumberGenerator) -> void:
	var t: Color = T.vert_propre(o, P.MOUSSE.lightened(0.12), 0.3)
	var coussinets := []
	for i in r.randi_range(4, 6):
		coussinets.append([Vector2(r.randf_range(-0.65, 0.65) * float(o._rx), r.randf_range(-0.4, 0.5) * float(o._ry)), r.randf_range(3.6, 6.2)])
	coussinets.sort_custom(func(u, v): return u[0].y < v[0].y)
	var rang := 0
	for c in coussinets:
		var q: Vector2 = c[0]
		var rx: float = c[1]
		var centre := q + Vector2(0, -1.2)
		var poly: PackedVector2Array = o.festons(centre, rx, rx * 0.52, 6, 0.2, r, 20, 0.2)
		p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25)), Pinceau.FEUILLAGE, centre, Vector2(rx, rx * 0.52) * 1.1)
		T.neige(o, p, poly, centre, rx, rx * 0.52, r, 0.5)
		p.contour(poly, 0.8, Color(ENCRE, 0.75), r, 2)
		if rang % 2 == 1:
			# (ses soies : des fils roux, une capsule)
			for k in 3:
				var pied := centre + Vector2(r.randf_range(-0.5, 0.5) * rx, -rx * 0.2)
				var bout := pied + Vector2(r.randf_range(-0.8, 0.8), -r.randf_range(2.6, 4.2))
				p.tracer(PackedVector2Array([pied, bout]), 0.45, P.TERRE.lerp(P.BRAISE_ROUGE, 0.3), false)
				p.disque(bout, 0.6, 0.75, P.TERRE.lerp(P.BRAISE, 0.3).darkened(0.1))
		rang += 1


# un lichen, à plat : des rosettes aux bords lobés (jaunes, vert pâle, orangées), leurs cernes, leurs coupes sombres, sur une
# plaque grise ; en croûte, sur une pierre plate qu'il mange
static func lichen(o, p, r: RandomNumberGenerator, croute: bool) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var gris := P.CENDRE.lerp(P.IVOIRE, 0.55)
	var dy := -2.0 if croute else 0.0
	if croute:
		# (une pierre plate, la croûte dessus)
		var pierre: PackedVector2Array = o.festons(Vector2(0, -2.0), rx * 0.9, ry * 0.9, 5, 0.15, r, 18, 0.1)
		T.ombre_douce(p, Vector2(0.8, 0.6), rx, ry * 0.8, 0.3)
		p.aplat(pierre, gris, Pinceau.PIERRE, Vector2(0, -2.0), Vector2(rx, ry))
		p.contour(pierre, 1.0, ENCRE, r, 2)
	else:
		var plaque: PackedVector2Array = o.festons(Vector2.ZERO, rx, ry, 7, 0.25, r, 26, 0.0)
		p.aplat(plaque, Color(gris.darkened(0.15), 0.85))
		p.contour(plaque, 0.7, Color(ENCRE, 0.45), r, 3)
	var tons := [P.BRAISE_COEUR.darkened(0.12), P.IVOIRE.lerp(P.MOUSSE, 0.3), P.BRAISE.darkened(0.1)]
	var rosettes := []
	for i in r.randi_range(6, 9):
		rosettes.append([Vector2(r.randf_range(-0.68, 0.68) * rx, r.randf_range(-0.58, 0.58) * ry + dy), r.randf_range(1.5, 3.1) * (0.8 if croute else 1.0), tons[0 if croute and r.randf() < 0.6 else r.randi() % tons.size()]])
	rosettes.sort_custom(func(u, v): return u[1] > v[1])
	for ro in rosettes:
		var q: Vector2 = ro[0]
		var s0: float = ro[1]
		var c: Color = ro[2]
		var bord: PackedVector2Array = o.festons(q, s0, s0 * 0.6, 5, 0.3, r, 14)
		p.aplat(T.grossi(bord, q, 0.4), Color(ENCRE, 0.5))
		p.aplat(bord, c)
		p.tracer(Pinceau.ellipse(q, s0 * 0.58, s0 * 0.34, 10), 0.4, Color(c.darkened(0.3), 0.8), false)
		p.disque(q + Vector2(-s0 * 0.15, -s0 * 0.08), s0 * 0.3, s0 * 0.2, c.lightened(0.18))
		if s0 > 2.2:
			# (ses coupes : de petits disques sombres, bordés)
			for k in 2:
				var g := q + Vector2.from_angle(k * 2.7 + s0) * s0 * 0.42 * Vector2(1.0, 0.6)
				p.disque(g, 0.6, 0.45, c.darkened(0.45))
	if T.enneigee(o) and not croute:
		p.disque(Vector2(-rx * 0.35, -ry * 0.3), rx * 0.3, ry * 0.26, Color(P.PAPIER.lightened(0.3), 0.8))


# le lichen des rennes : un coussin pâle, gris-vert, fait de petites boules ramifiées (un chou-fleur de corail), d'où pointent
# de fins bois de cerf ; brouté ou cueilli, il lui manque un pan, puis il n'en reste qu'une galette
static func lichen_rennes(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = float(o._ry) * (1.0 if o.reste > 0 else 0.45)
	var pale := P.IVOIRE.lerp(P.LUNE, 0.22).lerp(P.MOUSSE, 0.3).darkened(0.04)
	if float(o.roussi) > 0.0:
		pale = pale.lerp(P.TERRE, 0.4 * float(o.roussi))
	var centre := Vector2(0, -ry * 0.55)
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(10, 13), 0.18, r, 44, 0.12)
	p.aplat(poly, pale.darkened(0.18), Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	var entier: bool = o.reste >= o.plein
	if entier:
		# (ses rameaux : de fins bois de cerf, pâles, qui dépassent du coussin)
		for i in r.randi_range(5, 7):
			var pied := centre + Vector2(lerpf(-0.75, 0.75, (i + r.randf_range(0.1, 0.9)) / 7.0) * rx, -ry * r.randf_range(0.5, 0.8))
			var bout := pied + Vector2(r.randf_range(-1.5, 1.5), -r.randf_range(3.0, 5.0))
			var fourche := pied.lerp(bout, 0.55)
			for ligne in [PackedVector2Array([pied, bout]), PackedVector2Array([fourche, fourche + Vector2(-1.8, -1.8)]), PackedVector2Array([fourche, fourche + Vector2(1.9, -1.4)])]:
				p.tracer(ligne, 1.5, Color(ENCRE, 0.7), false)
				p.tracer(ligne, 0.75, pale.lightened(0.12), false)
	var boules := []
	# (cueilli d'une poignée, il en manque un pan ; tout cueilli, une galette)
	for i in (24 if entier else (14 if o.reste > 0 else 8)):
		var a := r.randf() * TAU
		var d := sqrt(r.randf())
		if not entier and o.reste > 0 and cos(a) > 0.35:
			continue
		boules.append(centre + Vector2(cos(a) * rx * 0.8 * d, sin(a) * ry * 0.75 * d - (1.0 - d) * 1.5))
	boules.sort_custom(func(u, v): return u.y < v.y)
	for q in boules:
		var s0 := r.randf_range(1.4, 2.2)
		p.disque(q, s0 + 0.45, s0 * 0.85 + 0.45, Color(ENCRE, 0.55))
		p.disque(q, s0, s0 * 0.85, pale.lerp(P.IVOIRE, r.randf_range(0.0, 0.25)) if q.x < 0.0 else pale.darkened(r.randf_range(0.0, 0.12)), Pinceau.DOME)
	T.neige(o, p, poly, centre, rx, ry, r, 0.34)
	p.contour(poly, 1.0, ENCRE, r, 3)


# une plante-caillou : des paires de feuilles rondes, couleur de pierre, fendues au milieu, leur dessus marbré, parmi de vrais
# cailloux ; de la fente de l'une sort une fleur en étoile
static func plante_caillou(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var pierre := P.IVOIRE.lerp(P.CENDRE, 0.25)
	for i in r.randi_range(3, 5):
		T.gravier(p, Vector2(r.randf_range(-rx, rx), r.randf_range(-1.5, 2.5)), r.randf_range(1.2, 2.2), pierre.darkened(r.randf_range(0.0, 0.2)))
	var n := r.randi_range(2, 4)
	var fleurie := int(o.graine) % 2 == 0 and not Flore.SANS_FLEURS.has(str(o.stade).to_lower())
	for i in n:
		var q := Vector2(lerpf(-0.6, 0.6, (i + r.randf_range(0.2, 0.8)) / n) * rx, r.randf_range(-1.0, 1.0))
		var s0 := r.randf_range(2.7, 3.5)
		var t: Color = T.vert_propre(o, pierre.lerp(P.BRAISE, 0.12), 0.15).lerp(P.MOUSSE, 0.12 * (i % 2))
		var c := q + Vector2(0, -s0 * 0.4)
		p.disque(c, s0 + 0.6, s0 * 0.7 + 0.6, ENCRE)
		p.disque(c, s0, s0 * 0.7, t, Pinceau.DOME)
		# (le dessus marbré : des taches sombres, des fenêtres claires)
		for k in 4:
			var m := c + Vector2(r.randf_range(-0.6, 0.6) * s0, -r.randf_range(0.0, 0.4) * s0 * 0.7)
			p.disque(m, 0.5, 0.4, Color(P.ENCRE_DOUCE, 0.55) if k % 2 == 0 else Color(P.PAPIER, 0.4))
		p.tracer(PackedVector2Array([c + Vector2(-s0 * 0.85, 0.0), c + Vector2(0, s0 * 0.12), c + Vector2(s0 * 0.85, -0.05 * s0)]), 0.9, ENCRE, false)
		if fleurie and i == 0:
			var f := c + Vector2(0.0, -s0 * 0.5)
			for k in 8:
				var a := TAU * k / 8.0
				p.tracer(PackedVector2Array([f, f + Vector2(cos(a) * 2.6, sin(a) * 1.6)]), 1.2, Color(ENCRE, 0.7), false)
				p.tracer(PackedVector2Array([f, f + Vector2(cos(a) * 2.3, sin(a) * 1.4)]), 0.7, P.BRAISE_COEUR.lightened(0.1) if sin(a) < 0.0 else P.BRAISE_COEUR.darkened(0.08), false)
			p.disque(f, 0.6, 0.45, P.BRAISE)
