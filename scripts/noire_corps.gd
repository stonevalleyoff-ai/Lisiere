extends RefCounted
# Lisière — la Noire, dessinée à l'encre (scripts/noire_corps.gd)
# La seule bête qui n'est pas d'Orvane (scripts/noire.gd) : elle ne sort pas du plan de corps d'une lignée, elle a sa planche à
# elle. Une bête plausible, et fausse, qu'on aurait du mal à nommer : haute sur pattes, le garrot plus haut que la croupe (les
# omoplates dépassent l'échine), un long cou qui porte la tête sous la ligne du dos ; maigre sous son poil (l'épine, les côtes,
# la pointe de la hanche, le flanc creux) ; une tête longue et busquée, sans front, la gueule fendue jusque sous l'œil, l'œil
# petit, l'oreille couchée ; une queue maigre qui pend. Ni aplat ni cerne : son poil est fait de coups de pinceau sec, dans le
# sens du poil, qui s'effilochent au contour (l'échine, la nuque, le ventre, l'arrière des pattes) ; un noir d'encre bleue, les
# pattes de l'autre côté en encre délayée, et un peu de clair sur l'échine et le dessus de la tête : ce que le feu accroche.
# Elle dessine sur la planche p (scripts/bestiaire_planche.gd) les quatre calques de toutes les bêtes (la gueule fermée : une
# fente), et trois de plus, que scripts/bete.gd lit dans « plus » : « gueule » (la tête sans sa mâchoire, les dents du haut),
# « machoire » (la mâchoire, ses dents, le fond de la gueule ; elle tourne autour du repère « machoire »), « roulee »
# (endormie, roulée sur elle-même, le menton au sol). Les mesures sont en largeurs de bête : elle se dessine à toute taille.

const Planche := preload("res://scripts/bestiaire_planche.gd")
const Pal := preload("res://scripts/palette.gd")

# le tronc, dans le sens des aiguilles depuis la racine de la queue : la croupe (la pointe de la hanche), le rein creux, le
# garrot (le plus haut), la pointe de l'épaule, le bréchet (le plus bas), le ventre qui remonte, l'aine
const TRONC := [[-0.275, -0.385], [-0.25, -0.435], [-0.2, -0.462], [-0.12, -0.468], [-0.03, -0.492], [0.06, -0.535], [0.125, -0.585],
	[0.175, -0.56], [0.215, -0.49], [0.225, -0.42], [0.19, -0.325], [0.12, -0.268], [0.03, -0.275], [-0.06, -0.31], [-0.14, -0.345],
	[-0.2, -0.335], [-0.255, -0.345]]
const I_CROUPE := 2
const I_GARROT := 6
const PAS := 6               # points par tronçon d'un contour lissé
# l'omoplate, qui dépasse l'échine ; la cuisse, sous la pointe de la hanche (elles cachent le haut des pattes proches)
const OMOPLATE := [[0.098, -0.584], [0.14, -0.594], [0.183, -0.52], [0.19, -0.43], [0.166, -0.372], [0.13, -0.378], [0.102, -0.46], [0.086, -0.54]]
const CUISSE := [[-0.235, -0.44], [-0.19, -0.462], [-0.135, -0.43], [-0.11, -0.36], [-0.124, -0.288], [-0.166, -0.268], [-0.216, -0.31], [-0.25, -0.38]]
# les pattes, de la hanche au pied : devant (le coude en arrière, un long canon), derrière (le genou en avant, le jarret haut)
const PATTE_AV := [[0.15, -0.4], [0.108, -0.268], [0.146, -0.11], [0.15, 0.0]]
const PATTE_AR := [[-0.185, -0.36], [-0.128, -0.24], [-0.232, -0.125], [-0.205, 0.0]]
const LARG_AV := [0.066, 0.046, 0.031, 0.027]
const LARG_AR := [0.09, 0.05, 0.034, 0.028]
const QUEUE := [[-0.255, -0.405], [-0.292, -0.362], [-0.322, -0.288], [-0.346, -0.205], [-0.37, -0.125], [-0.398, -0.058], [-0.432, -0.012]]
# le cou : sa ligne du dessus (du garrot à la nuque : il descend), sa ligne du dessous (de la gorge au poitrail)
const COU_HAUT := [[0.12, -0.57], [0.18, -0.545], [0.235, -0.492], [0.288, -0.438], [0.334, -0.412]]
const COU_BAS := [[0.336, -0.303], [0.292, -0.338], [0.245, -0.374], [0.2, -0.368], [0.13, -0.37]]
const COU_PIVOT := Vector2(0.165, -0.49)
# la tête : la nuque (son origine), sa longueur, de combien le nez pique ; son profil en longueurs de tête (x vers le nez, y
# vers le bas) : le crâne plat, le chanfrein busqué, le bout du nez, puis la lèvre jusqu'au coin de la gueule, la ganache
const NUQUE := Vector2(0.33, -0.37)
const TETE := 0.215
const INCL := 0.6
const CRANE := [[-0.06, -0.2], [0.14, -0.24], [0.34, -0.225], [0.52, -0.185], [0.72, -0.16], [0.9, -0.125], [0.995, -0.06], [1.0, 0.02],
	[0.97, 0.075], [0.8, 0.085], [0.55, 0.078], [0.36, 0.09], [0.2, 0.15], [0.0, 0.18], [-0.1, 0.0]]
const MACHOIRE := [[0.14, 0.09], [0.36, 0.065], [0.55, 0.05], [0.8, 0.055], [0.95, 0.055], [0.975, 0.12], [0.93, 0.185], [0.78, 0.215], [0.5, 0.24],
	[0.26, 0.285], [0.08, 0.215]]
const CHARNIERE := Vector2(0.17, 0.12)
const LEVRE := [[0.968, 0.078], [0.8, 0.087], [0.55, 0.08], [0.4, 0.09], [0.31, 0.062]]
const OEIL := Vector2(0.4, -0.085)
const OEIL_LOIN := Vector2(0.47, -0.205)
const RAYON_OEIL := 0.0082   # en largeurs de bête : petit (2,7 pixels pour 330)
# roulée : son dos, du bassin (à gauche) aux épaules, le cou qui redescend, le sol ; où sa nuque repose, et de combien
const ROULEE := [[-0.265, -0.01], [-0.29, -0.09], [-0.255, -0.19], [-0.165, -0.245], [-0.05, -0.285], [0.06, -0.3], [0.14, -0.27],
	[0.2, -0.2], [0.225, -0.12], [0.215, -0.035], [0.17, 0.0], [0.0, 0.004], [-0.18, 0.004]]
const NUQUE_ROULEE := Vector2(0.2, -0.06)
const INCL_ROULEE := 0.06


static func dessiner(p) -> void:
	var pl: Planche = p
	var u: float = pl.L
	pl.ombre(-0.03 * u, 0.3 * u)
	# (la place de chaque calque, connue d'avance : son image se fait dans un cadre à sa mesure, bien plus vite)
	_place(pl, "queue", u, -0.56, -0.47, -0.2, 0.14)
	_place(pl, "corps", u, -0.36, -0.68, 0.3, -0.17)
	_place(pl, "dessus", u, -0.36, -0.68, 0.3, -0.17)
	_place(pl, "tete", u, 0.02, -0.68, 0.58, -0.12)
	_place(pl, "gueule", u, 0.02, -0.68, 0.58, -0.12)
	_place(pl, "machoire", u, 0.2, -0.44, 0.58, -0.1)
	_place(pl, "roulee", u, -0.42, -0.45, 0.56, 0.14)
	_queue(pl, u)
	_patte(pl, u, true, true)
	_patte(pl, u, false, true)
	_tronc(pl, u)
	_patte(pl, u, true, false)
	_patte(pl, u, false, false)
	_dessus(pl, u)
	_tete(pl, u)
	_roulee(pl, u)


# la place d'un calque, de (x0, y0) à (x1, y1) en largeurs de bête, arrondie au pixel (le dessin y tombe comme dans le grand cadre)
static func _place(p: Planche, nom: String, u: float, x0: float, y0: float, x1: float, y1: float) -> void:
	var a := Vector2(floorf(x0 * u), floorf(y0 * u))
	p.place(nom, Rect2(a, Vector2(ceilf(x1 * u), ceilf(y1 * u)) - a))


# --- les gestes du pinceau sec ---

static func _v(a: Array, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(float(q[0]), float(q[1])) * u)
	return out


# les points d'une courbe souple qui passe par ces points (la même que Planche.ferme, Planche.ouvert), k par tronçon
static func _lisse(pts: PackedVector2Array, clos: bool, k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	for i in (m if clos else m - 1):
		var p0 := pts[(i - 1 + m) % m] if clos else pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % m]
		var p3 := pts[(i + 2) % m] if clos else pts[mini(i + 2, m - 1)]
		for j in k:
			out.append(p1.bezier_interpolate(p1 + (p2 - p0) / 6.0, p2 - (p3 - p1) / 6.0, p2, float(j) / k))
	if not clos:
		out.append(pts[m - 1])
	return out


# une mèche : une feuille d'encre très mince, de a vers l'angle ang, un peu courbe, qui finit en pointe
static func _meche(a: Vector2, ang: float, lg: float, w: float, courbe: float) -> String:
	var b := a + Vector2.from_angle(ang) * lg
	var nrm := Vector2.from_angle(ang + PI * 0.5)
	var m := a.lerp(b, 0.4) + nrm * courbe * lg
	return "M%s Q%s %s Q%s %sZ" % [Planche.pt(a), Planche.pt(m + nrm * w), Planche.pt(b), Planche.pt(m - nrm * w), Planche.pt(a)]


# un coup de pinceau sec : trois ou quatre mèches parties du même endroit, qui s'écartent, celles du milieu plus longues ;
# entre elles on voit le dessous. Jamais deux pareils (plus de dents de scie).
static func _coup(p: Planche, a: Vector2, ang: float, lg: float, w: float) -> String:
	var d := ""
	var m := 3 + (p.r.randi() % 2)
	var nrm := Vector2.from_angle(ang + PI * 0.5)
	var courbe := p.r.randf_range(-0.13, 0.13)
	for i in m:
		var k := (float(i) + 0.5) / m - 0.5
		var l := lg * (1.0 - 0.9 * absf(k)) * p.r.randf_range(0.6, 1.0)
		d += _meche(a + nrm * k * w, ang + k * 0.32, l, w / m * p.r.randf_range(0.7, 1.25), courbe)
	return d


# le poil qui dépasse d'un contour (ses points, dans le sens des aiguilles), de l'indice a à l'indice b : un coup de pinceau
# tous les « pas » pixels, parti d'un peu en dedans, couché vers l'arrière (kb) et pendant (kd), long de l0 à l1
static func _frange(p: Planche, ligne: PackedVector2Array, a: int, b: int, pas: float, kb: float, kd: float, l0: float, l1: float, w: float, dedans := 2.5) -> String:
	var d := ""
	var x := 0.0
	var m := ligne.size()
	# (par touffes : le poil s'allonge et se raccourcit par endroits, et manque ici ou là)
	var touffe := p.r.randf()
	for i in range(a, b):
		var q0 := ligne[i % m]
		var seg := ligne[(i + 1) % m] - q0
		var lg := seg.length()
		if lg < 0.01:
			continue
		var nrm := Vector2(seg.y, -seg.x) / lg
		while x < lg:
			touffe = lerpf(touffe, p.r.randf(), 0.6)
			if touffe > 0.16:
				var o := q0 + seg * (x / lg) - nrm * dedans * p.r.randf_range(0.3, 1.2)
				var vers := (nrm + Vector2(-kb, kd)).normalized()
				d += _coup(p, o, vers.angle() + p.r.randf_range(-0.2, 0.2), lerpf(l0, l1, touffe) * p.r.randf_range(0.75, 1.15), w)
			x += pas * p.r.randf_range(0.6, 1.5)
		x -= lg
	return d


# les côtes : m coups de pinceau inégaux, chacun de a à b (ce que rend « ou », en largeurs de bête) ; [les clairs, leurs creux]
static func _cotes(p: Planche, u: float, m: int, ou: Callable) -> Array:
	var clair := ""
	var creux := ""
	for i in m:
		var ab: Array = ou.call(i)
		var a: Vector2 = ab[0] * u
		var b: Vector2 = ab[1] * u
		var ang := (b - a).angle()
		clair += _meche(a, ang, a.distance_to(b), 0.0075 * u, -0.1)
		creux += _meche(a + Vector2(-0.012 * u, 0.0), ang, a.distance_to(b) * 1.05, 0.013 * u, -0.1)
	return [clair, creux]


# l'épine : ses vertèbres, de petits clairs inégaux sous le contour (ses points, de l'indice a à l'indice b)
static func _epine(p: Planche, u: float, sil: PackedVector2Array, a: int, b: int) -> String:
	var d := ""
	for i in range(a, b, 2):
		var t := (sil[i + 1] - sil[i - 1]).normalized()
		var vers := Vector2(-t.y, t.x)
		d += _meche(sil[i] + vers * 0.006 * u, (vers - t * 0.35).angle(), p.r.randf_range(0.012, 0.024) * u, 0.008 * u, 0.0)
	return d


# la matière du poil, dans une forme : des coups de pinceau semés dans une zone (un par case, à peu près), couchés dans le
# sens du poil (sens : l'angle du poil en un point)
static func _matiere(p: Planche, zone: Rect2, nx: int, ny: int, sens: Callable, l0: float, l1: float, w: float) -> String:
	var d := ""
	for i in nx:
		for j in ny:
			var q := zone.position + Vector2((i + p.r.randf()) / nx * zone.size.x, (j + p.r.randf()) / ny * zone.size.y)
			var a: float = sens.call(q)
			d += _coup(p, q, a + p.r.randf_range(-0.14, 0.14), p.r.randf_range(l0, l1), w)
	return d


# une forme de son poil : pas de cerne, pas d'encre lourde dessous ; l'encre un peu plus claire en haut à gauche
static func _masse(p: Planche, d: String, dedans := Callable()) -> void:
	var T: Dictionary = p.tons
	var robe: Color = T["robe"]
	var accent: Color = T["accent"]
	p.volume(d, robe, dedans, {"cerne": 0.0, "lourd": false, "lumiere": robe.lerp(accent, 0.3), "ombre": T["ombre"]})


# la ligne du dos et celle du ventre, à peu près (en largeurs de bête), pour coucher le poil du flanc
static func _y_dos(x: float) -> float:
	return -0.47 - 0.115 * clampf((x + 0.12) / 0.245, 0.0, 1.0)


static func _y_ventre(x: float) -> float:
	return -0.34 + 0.07 * clampf((x + 0.14) / 0.26, 0.0, 1.0)


# --- le tronc ---

static func _tronc(p: Planche, u: float) -> void:
	var T: Dictionary = p.tons
	p.calque("corps")
	var pts := _v(TRONC, u)
	var sil := _lisse(pts, true, PAS)
	# (le poil du flanc : couché vers l'arrière, il se redresse sur l'échine et pend sous le ventre)
	var sens := func(q: Vector2) -> float:
		var haut := _y_dos(q.x / u)
		return PI + lerpf(0.25, -1.0, clampf((q.y / u - haut) / (_y_ventre(q.x / u) - haut), 0.0, 1.0))
	var dedans := func():
		p.aplat(_matiere(p, Rect2(-0.29 * u, -0.6 * u, 0.53 * u, 0.34 * u), 12, 7, sens, 0.05 * u, 0.11 * u, 0.022 * u), T["accent"], 0.34)
		p.aplat(_matiere(p, Rect2(-0.29 * u, -0.56 * u, 0.53 * u, 0.3 * u), 9, 5, sens, 0.05 * u, 0.1 * u, 0.02 * u), T["encre"], 0.5)
		# les côtes : on les devine, un clair et son creux, de l'épine vers le bréchet
		var cotes: Array = _cotes(p, u, 5, func(i: int) -> Array:
			var x := lerpf(-0.03, 0.085, i / 4.0) + p.r.randf_range(-0.006, 0.006)
			return [Vector2(x, lerpf(_y_dos(x), _y_ventre(x), 0.36)), Vector2(x - 0.05, lerpf(_y_dos(x - 0.05), _y_ventre(x - 0.05), p.r.randf_range(0.68, 0.84)))])
		p.aplat(cotes[1], T["encre"], 0.45)
		p.aplat(cotes[0], T["accent"], 0.4)
		# l'épine : ses vertèbres, une à une, sous le poil du dos
		p.aplat(_epine(p, u, sil, I_CROUPE * PAS + 1, I_GARROT * PAS - 2), T["lumiere"], 0.3)
		# le flanc creux devant la cuisse, l'ombre sous le ventre et dans le poitrail
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(-0.118, -0.4) * u, 0.05 * u, 0.036 * u, 8, 0.3), 1.0), T["encre"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(-0.01, -0.292) * u, 0.21 * u, 0.045 * u, 10, -0.2), 1.0), T["encre"], 0.55)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(0.2, -0.4) * u, 0.035 * u, 0.09 * u, 8, 0.1), 1.0), T["encre"], 0.4)
	_masse(p, Planche.ferme(pts, 1.0), dedans)
	# son contour : pas un trait, du poil. Ras sur le rein (les vertèbres y pointent), long au garrot, pendant sous le poitrail
	# et le ventre
	var d := _frange(p, sil, 0, I_CROUPE * PAS, 5.0, 0.5, 0.9, 0.02 * u, 0.045 * u, 0.016 * u)
	d += _frange(p, sil, I_CROUPE * PAS, 5 * PAS, 6.5, 1.3, -0.1, 0.014 * u, 0.034 * u, 0.014 * u)
	d += _frange(p, sil, 5 * PAS, 8 * PAS, 4.2, 1.4, -0.25, 0.025 * u, 0.055 * u, 0.017 * u)
	d += _frange(p, sil, 8 * PAS, 11 * PAS, 6.0, 0.2, 1.0, 0.02 * u, 0.045 * u, 0.015 * u)
	d += _frange(p, sil, 11 * PAS, 15 * PAS, 4.4, 0.8, 0.7, 0.03 * u, 0.066 * u, 0.017 * u)
	d += _frange(p, sil, 15 * PAS, 17 * PAS, 6.0, 0.6, 0.8, 0.02 * u, 0.04 * u, 0.015 * u)
	for i in range(I_CROUPE * PAS + 1, 5 * PAS + 3, 2):
		var t := (sil[i + 1] - sil[i - 1]).normalized()
		d += Planche.ferme(Planche.ellipse(sil[i] + Vector2(t.y, -t.x) * 0.002 * u, 0.012 * u, 0.0065 * u, 6, t.angle()), 1.0)
	p.aplat(d, T["dos"], 0.96)
	# ce que la lumière accroche : quelques poils clairs, couchés le long de l'échine (le liseré du feu, la nuit)
	p.aplat(_frange(p, sil, I_CROUPE * PAS - 2, 8 * PAS, 8.5, 2.4, 0.15, 0.022 * u, 0.05 * u, 0.008 * u, 0.012 * u), T["lumiere"], 0.55)


# --- ce qui passe devant le haut des pattes proches : l'omoplate, la cuisse ---

static func _dessus(p: Planche, u: float) -> void:
	var T: Dictionary = p.tons
	p.calque("dessus")
	for devant in [false, true]:
		var pts := _v(OMOPLATE if devant else CUISSE, u)
		var sil := _lisse(pts, true, PAS)
		var centre := Vector2.ZERO
		for q in pts:
			centre += q / pts.size()
		var zone := Rect2(centre - Vector2(0.09, 0.13) * u, Vector2(0.18, 0.26) * u)
		var pente := 0.75 if devant else 1.05
		var sens := func(_q: Vector2) -> float:
			return PI - pente
		var dedans := func():
			p.aplat(_matiere(p, zone, 4, 6, sens, 0.04 * u, 0.085 * u, 0.02 * u), T["accent"], 0.36)
			p.aplat(_matiere(p, zone, 3, 4, sens, 0.04 * u, 0.08 * u, 0.018 * u), T["encre"], 0.5)
		_masse(p, Planche.ferme(pts, 1.0), dedans)
		if devant:
			# (l'épine de l'omoplate : un clair qui descend du garrot vers l'épaule ; son haut dépasse le dos)
			p.aplat(_meche(Vector2(0.124, -0.585) * u, 1.33, 0.15 * u, 0.007 * u, 0.06), T["lumiere"], 0.4)
			p.aplat(_frange(p, sil, 7 * PAS + 2, 9 * PAS, 6.0, 2.0, 0.2, 0.02 * u, 0.04 * u, 0.008 * u, 0.01 * u), T["lumiere"], 0.55)
			p.aplat(_frange(p, sil, 4 * PAS, 8 * PAS - 2, 6.0, 0.6, 0.7, 0.02 * u, 0.045 * u, 0.015 * u) + _frange(p, sil, 7 * PAS + 3, 9 * PAS + 4, 4.0, 2.0, -0.2, 0.016 * u, 0.036 * u, 0.014 * u), T["dos"], 0.95)
		else:
			# (la pointe de la hanche, et le poil de la fesse)
			p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(-0.224, -0.432) * u), Planche.pt(Vector2(-0.19, -0.458) * u), Planche.pt(Vector2(-0.15, -0.43) * u)], 0.006 * u, T["lumiere"], 0.36)
			p.aplat(_frange(p, sil, 2 * PAS, 8 * PAS, 6.0, 0.7, 0.7, 0.02 * u, 0.05 * u, 0.015 * u), T["dos"], 0.94)


# --- la queue : maigre, elle pend ; son poil s'allonge vers le bout ---

static func _queue(p: Planche, u: float) -> void:
	var T: Dictionary = p.tons
	p.calque("queue")
	var ligne := _lisse(_v(QUEUE, u), false, 4)
	p.aplat(Planche.ruban(ligne, 0.03 * u, 0.007 * u), T["robe"])
	var d := ""
	var m := ligne.size()
	for i in range(5, m):
		var s := float(i) / (m - 1)
		for k in (1 if s < 0.6 else 3):
			if s < 0.6 and p.r.randf() < 0.35:
				continue
			d += _coup(p, ligne[i] + Vector2(p.r.randf_range(-2.0, 2.0), 0.0), Vector2(-0.4, 1.0).angle() + p.r.randf_range(-0.35, 0.35),
				lerpf(0.016, 0.09, s * s * s) * u * p.r.randf_range(0.6, 1.0), 0.013 * u)
	p.aplat(d, T["dos"], 0.95)
	p.pivot("queue", Vector2(float(QUEUE[0][0]), float(QUEUE[0][1])) * u)


# --- les pattes : le haut charnu, le bas en os (il se creuse entre ses articulations), du poil derrière, un long pied ---

static func _patte(p: Planche, u: float, devant: bool, loin: bool) -> void:
	var pts := _v(PATTE_AV if devant else PATTE_AR, u)
	var larg: Array = []
	for w in (LARG_AV if devant else LARG_AR):
		larg.append(float(w) * u * (0.9 if loin else 1.0))
	if loin:
		# (la patte de l'autre côté : un peu en avant, sa hanche un peu plus bas)
		for i in pts.size():
			pts[i] += Vector2((0.036 if devant else 0.04) * u, (0.008 * u if i == 0 else 0.0))
	var morceau := func(s: int, lg: float, w0: float, w1: float, loin_: bool) -> String:
		return _os(p, u, s, lg, w0, w1, loin_, devant)
	var pied := func(w: float, loin_: bool) -> Array:
		return _pied(p, w, loin_)
	p.patte(pts, larg, loin, {"pied": "griffes", "pied_taille": 1.25, "marge": 0.022 * u, "morceau": morceau, "pied_fait": pied})


# un morceau de patte, couché de (0, 0) à (lg, 0) : y > 0 est son arrière
static func _os(p: Planche, u: float, s: int, lg: float, w0: float, w1: float, loin: bool, devant: bool) -> String:
	var T: Dictionary = p.tons
	var r0 := w0 * 0.5
	var r1 := w1 * 0.5
	var teinte: Color = T["loin"] if loin else T["robe"]
	var devant_ := -minf(r0, r1) * (0.9 if s == 0 else 0.3)
	var derriere := maxf(r0, r1) * 1.2 if s == 0 else minf(r0, r1) * 0.45
	# (le dernier os finit à plat sous le pied, qui le couvre)
	var bout := "A%s %s 0 0 1 %s" % [Planche.n(r1), Planche.n(r1), Planche.pt(Vector2(lg, r1))] if s < 2 else "L%s" % Planche.pt(Vector2(lg, r1))
	var d := "M%s Q%s %s %s Q%s %s A%s %s 0 0 1 %sZ" % [Planche.pt(Vector2(0.0, -r0)), Planche.pt(Vector2(lg * 0.5, devant_)),
		Planche.pt(Vector2(lg, -r1)), bout, Planche.pt(Vector2(lg * 0.5, derriere)),
		Planche.pt(Vector2(0.0, r0)), Planche.n(r0), Planche.n(r0), Planche.pt(Vector2(0.0, -r0))]
	if s == 2 and not devant:
		# (la pointe du jarret, qui saille en arrière)
		d += "M%s L%s L%sZ" % [Planche.pt(Vector2(-r0 * 0.5, r0 * 0.2)), Planche.pt(Vector2(-r0 * 0.4, r0 * 1.5)), Planche.pt(Vector2(lg * 0.3, r0 * 0.75))]
	elif s == 1 and devant:
		# (la pointe du coude)
		d += "M%s L%s L%sZ" % [Planche.pt(Vector2(-r0 * 0.3, r0 * 0.2)), Planche.pt(Vector2(-r0 * 0.5, r0 * 1.5)), Planche.pt(Vector2(lg * 0.2, r0 * 0.8))]
	var out := "<path d=\"%s\" fill=\"%s\"/>" % [d, Planche.coul(teinte)]
	# le poil de derrière : il pend le long de l'os, plus long en haut ; un toupet au-dessus du pied
	var poil := ""
	var m := (4 if s == 0 else 3) if not loin else 2
	for i in m:
		var x := lg * (0.1 + 0.62 * (float(i) + p.r.randf()) / m) if s < 2 else lg * p.r.randf_range(0.4, 0.66)
		var l := minf((0.045 if s == 0 else 0.034) * u * p.r.randf_range(0.6, 1.0), (lg - x) * 1.15 + r1)
		poil += _coup(p, Vector2(x, lerpf(r0, r1, x / lg) * 0.2), p.r.randf_range(0.3, 0.6), l, 0.013 * u)
	out += "<path d=\"%s\" fill=\"%s\" opacity=\"0.95\"/>" % [poil, Planche.coul(T["loin"].darkened(0.2) if loin else T["dos"])]
	if not loin:
		# (un clair le long du devant : le tendon, l'os sous la peau)
		out += "<path d=\"%s\" fill=\"%s\" opacity=\"0.4\"/>" % [_meche(Vector2(r0 * 0.5, -r0 * 0.32), 0.0, lg - r1, maxf(1.0, minf(w0, w1) * 0.2), -0.02), Planche.coul(T["accent"])]
	return out


# son pied, autour du point où il touche le sol, tourné vers l'avant : long, les doigts écartés, des griffes ternes
static func _pied(p: Planche, w: float, loin: bool) -> Array:
	var T: Dictionary = p.tons
	var teinte: Color = T["loin"] if loin else T["robe"]
	var os_: Color = T["os"].darkened(0.3) if loin else T["os"]
	var d := Planche.ferme(PackedVector2Array([Vector2(-0.5, -0.05) * w, Vector2(-0.46, -0.75) * w, Vector2(0.3, -0.95) * w, Vector2(1.1, -0.7) * w,
		Vector2(1.6, -0.44) * w, Vector2(1.92, -0.16) * w, Vector2(1.85, 0.03) * w, Vector2(1.0, 0.05) * w, Vector2(0.0, 0.06) * w]), 0.9)
	var griffes := ""
	for i in 3:
		griffes += _meche(Vector2(1.84 - 0.36 * i, -0.12 - 0.18 * i) * w, 0.36 - 0.06 * i, (0.78 - 0.08 * i) * w, 0.18 * w, -0.18)
	var s := "<path d=\"%s\" fill=\"%s\"/><path d=\"%s\" fill=\"%s\"/>" % [griffes, Planche.coul(os_), d, Planche.coul(teinte)]
	if not loin:
		s += "<path d=\"M%s L%s M%s L%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" opacity=\"0.7\"/>" % [Planche.pt(Vector2(0.9, -0.66) * w), Planche.pt(Vector2(1.55, -0.2) * w),
			Planche.pt(Vector2(0.45, -0.72) * w), Planche.pt(Vector2(1.1, -0.12) * w), Planche.coul(T["encre"]), Planche.n(maxf(0.6, 0.09 * w))]
	return [s, Rect2(-w, -1.2 * w, 4.2 * w, 1.5 * w)]


# --- le cou et la tête ---

static func _hp(o: Vector2, hs: float, incl: float, q: Vector2) -> Vector2:
	return o + (q * hs).rotated(incl)


static func _h(a: Array, o: Vector2, hs: float, incl: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(_hp(o, hs, incl, Vector2(float(q[0]), float(q[1]))))
	return out


static func _tete(p: Planche, u: float) -> void:
	var T: Dictionary = p.tons
	var o := NUQUE * u
	var hs := TETE * u
	# le cou : il part du garrot et descend ; sa crinière se couche vers le dos, son poil pend sous la gorge
	p.calque_en_plus("_cou")
	var haut := _lisse(_v(COU_HAUT, u), false, PAS)
	var bas := _lisse(_v(COU_BAS, u), false, PAS)
	var sens_cou := func(q: Vector2) -> float:
		return PI + lerpf(0.5, -0.9, clampf((q.y / u + 0.55) / 0.2, 0.0, 1.0))
	var dans_cou := func():
		p.aplat(_matiere(p, Rect2(0.12 * u, -0.58 * u, 0.22 * u, 0.24 * u), 6, 6, sens_cou, 0.045 * u, 0.1 * u, 0.02 * u), T["accent"], 0.34)
		p.aplat(_matiere(p, Rect2(0.12 * u, -0.56 * u, 0.22 * u, 0.22 * u), 4, 4, sens_cou, 0.045 * u, 0.09 * u, 0.018 * u), T["encre"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(0.24, -0.37) * u, 0.08 * u, 0.03 * u, 8, -0.1), 1.0), T["encre"], 0.5)
	_masse(p, Planche.ferme(haut + bas, 0.6), dans_cou)
	var d := _frange(p, haut, 0, haut.size() - 1, 3.4, 1.7, -0.2, 0.03 * u, 0.066 * u, 0.018 * u)
	d += _frange(p, bas, 2, bas.size() - 4, 5.0, 0.5, 1.0, 0.025 * u, 0.055 * u, 0.016 * u)
	p.aplat(d, T["dos"], 0.96)
	p.aplat(_frange(p, haut, 3, haut.size() - 1, 9.0, 2.6, 0.1, 0.025 * u, 0.05 * u, 0.008 * u, 0.012 * u), T["lumiere"], 0.5)
	# la mâchoire (derrière la tête : fermée, ses dents sont sous la lèvre)
	p.calque_en_plus("_bas")
	var machoire := _h(MACHOIRE, o, hs, INCL)
	var dans_machoire := func():
		p.aplat(Planche.ferme(Planche.ellipse(_hp(o, hs, INCL, Vector2(0.55, 0.2)), 0.4 * hs, 0.05 * hs, 8, INCL), 1.0), T["encre"], 0.5)
	_masse(p, Planche.ferme(machoire, 0.85), dans_machoire)
	p.aplat(_frange(p, _lisse(machoire, true, 4), 6 * 4, 10 * 4, 5.0, 0.9, 0.5, 0.012 * u, 0.03 * u, 0.01 * u, 1.5), T["dos"], 0.95)
	# le haut de la tête : l'oreille couchée, puis le crâne
	p.calque_en_plus("_haut")
	var oreille := _h([[0.05, -0.2], [-0.08, -0.275], [-0.27, -0.3], [-0.2, -0.255], [-0.3, -0.235], [-0.18, -0.2], [-0.04, -0.13]], o, hs, INCL)
	p.aplat(Planche.ferme(oreille, 0.6), T["dos"])
	p.tracer("M%s L%s" % [Planche.pt(_hp(o, hs, INCL, Vector2(0.0, -0.2))), Planche.pt(_hp(o, hs, INCL, Vector2(-0.18, -0.26)))], 0.004 * u, T["accent"], 0.5)
	var crane := _h(CRANE, o, hs, INCL)
	var sil := _lisse(crane, true, 4)
	var dans_tete := func():
		# le poil ras de la face, couché vers la nuque ; la tempe creuse, l'arcade, la pommette sous l'œil
		var sens := func(_q: Vector2) -> float:
			return INCL + PI + 0.12
		p.aplat(_matiere(p, Rect2(o + Vector2(-0.02, -0.05) * u, Vector2(0.2, 0.17) * u), 6, 5, sens, 0.025 * u, 0.06 * u, 0.012 * u), T["accent"], 0.32)
		p.aplat(Planche.ferme(Planche.ellipse(_hp(o, hs, INCL, Vector2(0.2, -0.04)), 0.14 * hs, 0.09 * hs, 8, INCL), 1.0), T["encre"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(_hp(o, hs, INCL, Vector2(0.62, 0.04)), 0.3 * hs, 0.035 * hs, 8, INCL), 1.0), T["encre"], 0.45)
		p.tracer("M%s Q%s %s" % [Planche.pt(_hp(o, hs, INCL, Vector2(0.27, 0.0))), Planche.pt(_hp(o, hs, INCL, Vector2(0.42, 0.03))), Planche.pt(_hp(o, hs, INCL, Vector2(0.62, -0.02)))],
			0.0045 * u, T["accent"], 0.6)
		p.tracer("M%s Q%s %s" % [Planche.pt(_hp(o, hs, INCL, Vector2(0.3, -0.15))), Planche.pt(_hp(o, hs, INCL, Vector2(0.4, -0.185))), Planche.pt(_hp(o, hs, INCL, Vector2(0.52, -0.13)))],
			0.0045 * u, T["lumiere"], 0.45)
		# la narine : une fente
		p.tracer("M%s L%s" % [Planche.pt(_hp(o, hs, INCL, Vector2(0.9, -0.025))), Planche.pt(_hp(o, hs, INCL, Vector2(0.97, 0.005)))], 0.005 * u, T["encre"], 0.9)
	_masse(p, Planche.ferme(crane, 0.9), dans_tete)
	p.aplat(_frange(p, sil, 0, 2 * 4, 4.0, 1.4, -0.2, 0.012 * u, 0.03 * u, 0.01 * u, 1.5) + _frange(p, sil, 12 * 4, 14 * 4 + 2, 4.5, 0.8, 0.6, 0.012 * u, 0.028 * u, 0.01 * u, 1.5), T["dos"], 0.95)
	# (le dessus de la tête, le chanfrein : ce que le feu accroche)
	p.aplat(_frange(p, sil, 1, 6 * 4, 8.0, 3.0, 0.1, 0.02 * u, 0.045 * u, 0.006 * u, 0.008 * u), T["lumiere"], 0.5)
	# la tête, gueule fermée : ce que la bête porte presque toujours
	p.calque("tete")
	p.verser("_cou", "tete")
	p.verser("_bas", "tete")
	p.verser("_haut", "tete")
	_fente(p, o, hs, INCL)
	_oeil(p, o, hs, INCL, true)
	var c := _hp(o, hs, INCL, OEIL)
	var c2 := _hp(o, hs, INCL, OEIL_LOIN)
	p.yeux.append(Vector3(c.x, c.y, RAYON_OEIL * u))
	p.yeux.append(Vector3(c2.x, c2.y, RAYON_OEIL * u * 0.7))
	p.pivot("tete", COU_PIVOT * u)
	p.pivot("machoire", _hp(o, hs, INCL, CHARNIERE))
	p.pivot("axe", Vector2.from_angle(INCL))
	# la gueule ouverte : la tête sans sa mâchoire, les dents du haut sous la lèvre
	p.calque_en_plus("gueule")
	p.verser("_cou", "gueule")
	p.aplat(_dents(p, o, hs, 0.43, 0.95, 0.08, 1.0, 15), T["os"], 0.95)
	p.verser("_haut", "gueule")
	_oeil(p, o, hs, INCL, true)
	# la mâchoire, à part : le fond de la gueule (le haut de la tête le cache tant qu'elle est fermée), ses dents, sa lèvre
	p.calque_en_plus("machoire")
	p.aplat(Planche.ferme(_h([[0.2, 0.1], [0.4, -0.03], [0.62, -0.1], [0.8, -0.04], [0.93, 0.05], [0.6, 0.1]], o, hs, INCL), 0.8), Pal.SANG.darkened(0.72).lerp(T["encre"], 0.3))
	p.aplat(_dents(p, o, hs, 0.46, 0.93, 0.06, -1.0, 13), T["os"].darkened(0.12), 0.95)
	p.verser("_bas", "machoire")


# la gueule fermée : une fente, trop longue, qui remonte sous l'œil ; un clair sur la lèvre du haut
static func _fente(p: Planche, o: Vector2, hs: float, incl: float) -> void:
	var T: Dictionary = p.tons
	var levre := _h(LEVRE, o, hs, incl)
	p.tracer(Planche.ouvert(levre), 0.03 * hs, T["encre"], 0.95)
	var au_dessus := PackedVector2Array()
	for i in levre.size() - 1:
		au_dessus.append(levre[i] + Vector2(0.0, -0.03 * hs).rotated(incl))
	p.tracer(Planche.ouvert(au_dessus), 0.016 * hs, T["accent"], 0.55)


# des dents : petites, nombreuses, inégales, ternes ; il en manque. vers : 1, celles du haut (elles pendent) ; -1, celles du bas
static func _dents(p: Planche, o: Vector2, hs: float, x0: float, x1: float, y: float, vers: float, m: int) -> String:
	var d := ""
	for i in m:
		if p.r.randf() < 0.1:
			continue
		var x := lerpf(x0, x1, (float(i) + p.r.randf_range(0.2, 0.8)) / m)
		var w := p.r.randf_range(0.012, 0.019)
		var l := p.r.randf_range(0.045, 0.085) * (1.25 if x > 0.82 else 1.0)
		d += "M%s L%s L%sZ" % [Planche.pt(_hp(o, hs, INCL, Vector2(x - w, y - 0.03 * vers))), Planche.pt(_hp(o, hs, INCL, Vector2(x + w, y - 0.03 * vers))),
			Planche.pt(_hp(o, hs, INCL, Vector2(x + p.r.randf_range(-0.012, 0.012), y + l * vers)))]
	return d


# son œil : petit, enfoncé dans une orbite d'encre ; une braise sombre, un cœur à peine plus clair (scripts/yeux.gd le fait
# luire). Fermé : un trait.
static func _oeil(p: Planche, o: Vector2, hs: float, incl: float, ouvert: bool) -> void:
	var T: Dictionary = p.tons
	var c := _hp(o, hs, incl, OEIL)
	var r := RAYON_OEIL * p.L
	p.aplat(Planche.ferme(Planche.ellipse(c, r * 2.3, r * 1.7, 8, incl), 1.0), T["encre"], 0.85)
	if ouvert:
		var braise: Color = T["oeil"]
		p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(c.x), Planche.n(c.y), Planche.n(r), Planche.coul(braise.darkened(0.7))])
		p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(c.x), Planche.n(c.y), Planche.n(r * 0.5), Planche.coul(braise.darkened(0.45))])
	else:
		p.tracer("M%s L%s" % [Planche.pt(c + Vector2(-r * 1.3, 0.0).rotated(incl)), Planche.pt(c + Vector2(r * 1.3, r * 0.3).rotated(incl))], r * 0.5, T["accent"], 0.7)


# --- endormie : roulée sur elle-même, le dos rond, la tête au sol devant ses pattes, la queue ramenée ---

static func _roulee(p: Planche, u: float) -> void:
	var T: Dictionary = p.tons
	p.calque_en_plus("roulee")
	# (la queue, qui fait le tour par le sol ; une patte de devant sous le menton)
	var queue := _lisse(_v([[-0.275, -0.03], [-0.25, 0.012], [-0.15, 0.022], [-0.03, 0.02], [0.07, 0.012]], u), false, 4)
	p.aplat(Planche.ruban(queue, 0.028 * u, 0.008 * u), T["robe"])
	var dq := ""
	for i in range(4, queue.size()):
		dq += _coup(p, queue[i], p.r.randf_range(-0.25, 0.35), lerpf(0.02, 0.06, float(i) / queue.size()) * u, 0.012 * u)
	p.aplat(dq, T["dos"], 0.95)
	var pied: Array = _pied(p, 0.04 * u, false)
	p.aplat(Planche.ruban(PackedVector2Array([Vector2(0.17, -0.03) * u, Vector2(0.27, -0.022) * u, Vector2(0.34, -0.014) * u]), 0.04 * u, 0.03 * u), T["robe"])
	p.svg("<g transform=\"translate(%s %s)\">%s</g>" % [Planche.n(0.335 * u), Planche.n(0.0), pied[0]])
	# la tête : la même, posée ; l'œil clos
	var o := NUQUE * u
	var tour := "translate(%s) rotate(%s) translate(%s)" % [Planche.pt(NUQUE_ROULEE * u), Planche.n(rad_to_deg(INCL_ROULEE - INCL)), Planche.pt(-o)]
	p.svg("<g transform=\"%s\">" % tour)
	p.verser("_bas", "roulee")
	p.verser("_haut", "roulee")
	_fente(p, o, TETE * u, INCL)
	p.svg("</g>")
	_oeil(p, NUQUE_ROULEE * u, TETE * u, INCL_ROULEE, false)
	p.pivot("oeil_roulee", _hp(NUQUE_ROULEE * u, TETE * u, INCL_ROULEE, OEIL))
	# le corps : un dos rond, où l'on compte les vertèbres
	var pts := _v(ROULEE, u)
	var sil := _lisse(pts, true, PAS)
	var sens := func(q: Vector2) -> float:
		return PI + lerpf(0.3, -0.85, clampf((q.y / u + 0.3) / 0.3, 0.0, 1.0)) - 0.5 * clampf((q.x / u - 0.1) / 0.12, 0.0, 1.0)
	var dedans := func():
		p.aplat(_matiere(p, Rect2(-0.29 * u, -0.31 * u, 0.53 * u, 0.32 * u), 12, 7, sens, 0.05 * u, 0.11 * u, 0.022 * u), T["accent"], 0.34)
		p.aplat(_matiere(p, Rect2(-0.29 * u, -0.28 * u, 0.53 * u, 0.29 * u), 9, 5, sens, 0.05 * u, 0.1 * u, 0.02 * u), T["encre"], 0.5)
		var cotes: Array = _cotes(p, u, 5, func(i: int) -> Array:
			var x := lerpf(-0.045, 0.07, i / 4.0) + p.r.randf_range(-0.006, 0.006)
			return [Vector2(x, -0.225 - 0.008 * i), Vector2(x - 0.05, p.r.randf_range(-0.11, -0.07))])
		p.aplat(cotes[1], T["encre"], 0.45)
		p.aplat(cotes[0], T["accent"], 0.4)
		p.aplat(_epine(p, u, sil, 2 * PAS, 6 * PAS), T["lumiere"], 0.3)
		# (la cuisse repliée, la pointe de la hanche, l'omoplate ; l'ombre au ras du sol)
		p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(-0.21, -0.17) * u), Planche.pt(Vector2(-0.09, -0.17) * u), Planche.pt(Vector2(-0.085, -0.02) * u)], 0.012 * u, T["encre"], 0.55)
		p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(-0.268, -0.16) * u), Planche.pt(Vector2(-0.24, -0.198) * u), Planche.pt(Vector2(-0.2, -0.185) * u)], 0.006 * u, T["lumiere"], 0.38)
		p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(0.05, -0.275) * u), Planche.pt(Vector2(0.115, -0.22) * u), Planche.pt(Vector2(0.13, -0.12) * u)], 0.011 * u, T["encre"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(-0.03, -0.012) * u, 0.26 * u, 0.04 * u, 10), 1.0), T["encre"], 0.55)
	_masse(p, Planche.ferme(pts, 1.0), dedans)
	var d := _frange(p, sil, 0, 2 * PAS, 5.0, 0.4, 0.8, 0.02 * u, 0.045 * u, 0.016 * u)
	d += _frange(p, sil, 2 * PAS, 5 * PAS, 5.5, 1.3, -0.1, 0.016 * u, 0.04 * u, 0.015 * u)
	d += _frange(p, sil, 5 * PAS, 9 * PAS, 4.2, 1.3, -0.2, 0.03 * u, 0.07 * u, 0.017 * u)
	for i in range(2 * PAS, 5 * PAS + 2, 2):
		var t := (sil[i + 1] - sil[i - 1]).normalized()
		d += Planche.ferme(Planche.ellipse(sil[i] + Vector2(t.y, -t.x) * 0.002 * u, 0.012 * u, 0.0065 * u, 6, t.angle()), 1.0)
	p.aplat(d, T["dos"], 0.96)
	p.aplat(_frange(p, sil, 2 * PAS - 2, 7 * PAS, 8.5, 2.4, 0.15, 0.022 * u, 0.05 * u, 0.008 * u, 0.012 * u), T["lumiere"], 0.55)
	# (le pied de derrière, qui dépasse)
	var pied2: Array = _pied(p, 0.036 * u, false)
	p.svg("<g transform=\"translate(%s %s)\">%s</g>" % [Planche.n(-0.07 * u), Planche.n(0.004 * u), pied2[0]])
