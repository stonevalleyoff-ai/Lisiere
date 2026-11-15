extends RefCounted
# Lisière — les icônes de l'atelier, dessinées à l'encre (scripts/atelier_icones.gd)
# Une par chose qui se fabrique (les seize de scripts/atelier.gd, ORDRE), une par matière nouvelle (la peau, la ferraille, la
# corde, la bâche, l'eau), et le bouillon : pour la page de l'établi, celle du sac, et partout où le jeu les montre.
# Dans le trait de scripts/interface_icones.gd : une boîte de 100 unités, centrée, mise à la taille voulue ; des aplats de la
# palette cernés d'encre, l'ombre en bas à droite (la lumière vient d'en haut à gauche), une touche de papier pour l'éclat.
# Chacune est tracée une fois dans un maillage gardé (scripts/interface_trace.gd), puis dessinée d'un seul appel.
# Ce qui est clair (une vapeur, un faisceau, un cordage) est cerné d'encre : ces icônes se lisent sur le papier d'une page
# comme sur un jeton sombre du HUD. Un nom qu'on ne connaît pas ici est demandé aux icônes du HUD (le bois, la pierre…).

const P := preload("res://scripts/palette.gd")
const I := preload("res://scripts/interface_icones.gd")
const Trace := preload("res://scripts/interface_trace.gd")
const NOMS := ["corde", "bache", "etabli", "tente", "hamac", "recuperateur", "filet", "cerf_volant", "sac_a_dos", "vetement_chaud",
	"vetement_pluie", "gourde", "popote", "duvet", "lampe", "piles", "peau", "ferraille", "eau", "bouillon"]

const TOILE := Color("aba888")          # (la bâche : une toile écrue, enduite, entre l'ivoire et la mousse)
const TOILE_CLAIRE := Color("cbc6a4")
const TOILE_SOMBRE := Color("858268")
const CUIR := Color("8a5530")           # (la peau tannée : le brun de la viande cuite)
const CUIR_SOMBRE := Color("6b5238")
const CUIR_CLAIR := Color("ad7646")
const FOURRURE := Color("ded2b4")
const CHANVRE := Color("c4b783")        # (la corde : la paille des fibres, pâlie)
const FER := Color("77726a")            # (la ferraille : la pierre, plus sombre)
const FER_CLAIR := Color("aaa498")
const ROUILLE := Color("9e4523")        # (l'écharpe)
const EAU := Color("6fa8d6")
const EAU_SOMBRE := Color("4a7fad")
const BOIS := Color("c9a978")
const MANCHE := Color("8a6a48")
const ECORCE := Color("6b5238")
const PIERRE := Color("9d968a")
const BOUILLON := Color("c99a52")

static var _pales := {}


# cette icône est-elle dessinée ici ?
static func connue(id: String) -> bool:
	return NOMS.has(id)


# une icône : son nom (l'id d'une chose de l'atelier, d'une matière), son centre, sa taille (le côté de sa boîte), sa couleur
# multipliée (l'alpha : une chose qu'on n'a pas encore), et la transformation de celui qui dessine (s'il en a une)
static func icone(ci, id: String, centre: Vector2, taille: float, teinte: Color = Color.WHITE, base: Transform2D = Transform2D.IDENTITY) -> void:
	if taille < 1.0 or teinte.a <= 0.0:
		return
	if not NOMS.has(id):
		I.icone(ci, id, centre, taille, teinte, 1.0, base)
		return
	# (l'encre ne descend pas sous un pixel et demi : les petites icônes restent nettes)
	var w := snappedf(maxf(5.0, 150.0 / taille), 0.5)
	if ci is CanvasItem:
		var mesh := Trace.maillage("atelier|%s|%.1f" % [id, w], func(t): _icone(t, id, w, Color.WHITE))
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(taille, taille) / 100.0, 0.0, centre))
		ci.draw_mesh(mesh, null, Transform2D.IDENTITY, teinte)
		ci.draw_set_transform_matrix(base)
		return
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(taille, taille) / 100.0, 0.0, centre))
	_icone(ci, id, w, teinte)
	ci.draw_set_transform_matrix(base)


# la même icône, pâlie vers le papier (de 0, telle quelle, à 1, effacée) : une chose qu'on ne peut pas encore fabriquer, qu'on
# n'a pas. Pâlie et non transparente : ses traits ne se voient pas les uns à travers les autres. Sur du papier seulement.
static func esquisse(ci: CanvasItem, id: String, centre: Vector2, taille: float, pale: float = 0.6, base: Transform2D = Transform2D.IDENTITY) -> void:
	if taille < 1.0:
		return
	var w := snappedf(maxf(5.0, 150.0 / taille), 0.5)
	var k := snappedf(clampf(pale, 0.0, 1.0), 0.05)
	var cle := "%s|%.1f|%.2f" % [id, w, k]
	var mesh = _pales.get(cle)
	if mesh == null:
		var t := Pale.new()
		t.k = k
		if NOMS.has(id):
			_icone(t, id, w, Color.WHITE)
		else:
			I.icone(t, id, Vector2.ZERO, 100.0)
		mesh = t.en_maillage()
		_pales[cle] = mesh
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(taille, taille) / 100.0, 0.0, centre))
	ci.draw_mesh(mesh, null, Transform2D.IDENTITY, Color.WHITE)
	ci.draw_set_transform_matrix(base)


# une trace (scripts/interface_trace.gd) dont chaque couleur est tirée vers le papier
class Pale extends Trace:
	var k := 0.6

	func _pale(c: Color) -> Color:
		return Color(lerpf(c.r, P.PAPIER.r, k), lerpf(c.g, P.PAPIER.g, k), lerpf(c.b, P.PAPIER.b, k), c.a)

	func draw_colored_polygon(pts: PackedVector2Array, c: Color) -> void:
		super(pts, _pale(c))

	func draw_polyline(brut: PackedVector2Array, c: Color, w: float = -1.0, lisse: bool = false) -> void:
		super(brut, _pale(c), w, lisse)

	func draw_circle(centre: Vector2, r: float, c: Color) -> void:
		super(centre, r, _pale(c))


static func _icone(ci, id: String, w: float, m: Color) -> void:
	match id:
		"corde":
			_corde(ci, w, m)
		"bache":
			_bache(ci, w, m)
		"etabli":
			_etabli(ci, w, m)
		"tente":
			_tente(ci, w, m)
		"hamac":
			_hamac(ci, w, m)
		"recuperateur":
			_recuperateur(ci, w, m)
		"filet":
			_filet(ci, w, m)
		"cerf_volant":
			_cerf_volant(ci, w, m)
		"sac_a_dos":
			_sac_a_dos(ci, w, m)
		"vetement_chaud":
			_pelisse(ci, w, m)
		"vetement_pluie":
			_cape_de_pluie(ci, w, m)
		"gourde":
			_gourde(ci, w, m)
		"popote":
			_popote(ci, w, m)
		"duvet":
			_duvet(ci, w, m)
		"lampe":
			_lampe(ci, w, m)
		"piles":
			_piles(ci, w, m)
		"peau":
			_peau(ci, w, m)
		"ferraille":
			_ferraille(ci, w, m)
		"eau":
			_eau(ci, w, m)
		"bouillon":
			_bouillon(ci, w, m)


# --- les briques ---

# un aplat et son cerne
static func _forme(ci, pts: PackedVector2Array, fond: Color, w: float, m: Color) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fond * m)
	_cerne(ci, pts, w, m)


static func _cerne(ci, pts: PackedVector2Array, w: float, m: Color, a: float = 1.0) -> void:
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	ci.draw_polyline(ferme, Color(P.ENCRE, a) * m, w, true)


# une forme qui a du volume : son aplat, un croissant d'ombre en bas à droite (la forme, moins elle-même décalée vers la
# lumière), son cerne par-dessus
static func _volume(ci, pts: PackedVector2Array, fond: Color, w: float, m: Color, d: float = 7.0, force: float = 0.3) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fond * m)
	_ombre(ci, pts, m, d, force)
	_cerne(ci, pts, w, m)


static func _ombre(ci, pts: PackedVector2Array, m: Color, d: float = 7.0, force: float = 0.3) -> void:
	var decale := Transform2D(0.0, Vector2(-d, -d * 0.8)) * pts
	for q in Geometry2D.clip_polygons(pts, decale):
		if q.size() >= 3:
			ci.draw_colored_polygon(q, Color(P.NUIT_BLEUE, force) * m)


# ce qui d'une forme tombe dans une autre (une ombre, une bande de couleur)
static func _part(ci, pts: PackedVector2Array, coupe: PackedVector2Array, c: Color) -> void:
	for q in Geometry2D.intersect_polygons(pts, coupe):
		if q.size() >= 3:
			ci.draw_colored_polygon(q, c)


# un cordage, un manche, une anse : un trait de couleur, cerné d'encre
static func _cordon(ci, pts: PackedVector2Array, e: float, c: Color, w: float, m: Color) -> void:
	ci.draw_polyline(pts, P.ENCRE * m, e + w * 1.7, true)
	ci.draw_polyline(pts, c * m, e, true)


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _bezier(a: Vector2, b: Vector2, c: Vector2, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(a.lerp(b, u).lerp(b.lerp(c, u), u))
	return pts


# plusieurs courbes bout à bout, en une seule forme : [a, b, c] (une courbe, de a à c) ou [a] (un coin)
static func _contour(morceaux: Array, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for mo in morceaux:
		var q: PackedVector2Array = _bezier(mo[0], mo[1], mo[2], n) if mo.size() == 3 else PackedVector2Array([mo[0]])
		for p in q:
			if pts.is_empty() or not p.is_equal_approx(pts[pts.size() - 1]):
				pts.append(p)
	if pts.size() > 1 and pts[0].is_equal_approx(pts[pts.size() - 1]):
		pts.remove_at(pts.size() - 1)
	return pts


# des coins adoucis (chaque tour coupe les angles)
static func _lisse(pts: PackedVector2Array, tours: int = 2) -> PackedVector2Array:
	var p := pts
	for _k in tours:
		var q := PackedVector2Array()
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


# un bâton aux bouts ronds, de a à b
static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ang := (b - a).angle()
	for i in 9:
		pts.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * i / 8.0) * r)
	for i in 9:
		pts.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * i / 8.0) * r)
	return pts


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


# le même, les coins ronds
static func _arrondi(x0: float, y0: float, x1: float, y1: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var coins := [[Vector2(x1 - r, y0 + r), -PI * 0.5], [Vector2(x1 - r, y1 - r), 0.0], [Vector2(x0 + r, y1 - r), PI * 0.5], [Vector2(x0 + r, y0 + r), PI]]
	for coin in coins:
		for i in 5:
			pts.append(coin[0] + Vector2.from_angle(float(coin[1]) + PI * 0.5 * i / 4.0) * r)
	return pts


# un bord de fourrure : une forme ronde dont le contour moutonne
static func _touffe(c: Vector2, rx: float, ry: float, rot: float, bosses: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := bosses * 6
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + 0.16 * absf(sin(a * bosses * 0.5))
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k).rotated(rot))
	return pts


# une goutte d'eau, la pointe en haut
static func _goutte(ci, c: Vector2, r: float, w: float, m: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 2.1)])
	for i in 15:
		pts.append(c + Vector2.from_angle(-PI * 0.2 + PI * 1.4 * i / 14.0) * r)
	_forme(ci, pts, EAU, w, m)


# une volute de vapeur : claire, cernée d'encre
static func _vapeur(ci, pied: Vector2, haut: float, w: float, m: Color) -> void:
	var pts := _bezier(pied, pied + Vector2(-9, -haut * 0.3), pied + Vector2(0, -haut * 0.55), 8)
	pts.append_array(_bezier(pied + Vector2(0, -haut * 0.55), pied + Vector2(9, -haut * 0.8), pied + Vector2(1, -haut), 8).slice(1))
	ci.draw_polyline(pts, Color(P.ENCRE, 0.6) * m, w * 1.9, true)
	ci.draw_polyline(pts, P.PAPIER * m, w * 0.75, true)


# --- les matières ---

# un rouleau de corde, vu de trois quarts : ses tours, ses torons, le lien rouille qui le tient, le bout qui dépasse
static func _corde(ci, w: float, m: Color) -> void:
	var c := Vector2(-3, 0)
	var e := 22.0
	_cordon(ci, _bezier(Vector2(14, 18), Vector2(36, 20), Vector2(41, 43), 10), 8.5, CHANVRE, w, m)
	for y in [34.0, 39.0]:
		ci.draw_line(Vector2(34.0, y), Vector2(44.5, y - 2.5), Color(P.ENCRE, 0.7) * m, w * 0.55, true)
	var tour := _ellipse(c, 29.0, 22.0, -0.1, 44)
	tour.append(tour[0])
	ci.draw_polyline(tour, P.ENCRE * m, e + w * 1.8, true)
	ci.draw_polyline(tour, CHANVRE * m, e, true)
	# (l'ombre : le bas et la droite de l'anneau)
	var bas := PackedVector2Array()
	for i in 17:
		bas.append(c + Vector2(cos(-0.5 + 2.6 * i / 16.0) * 29.0, sin(-0.5 + 2.6 * i / 16.0) * 22.0).rotated(-0.1))
	ci.draw_polyline(bas, Color(P.NUIT_BLEUE, 0.22) * m, e, true)
	# (trois tours côte à côte, et sur chacun le biais des torons)
	for k in [-1.0, 1.0]:
		var entre := _ellipse(c, 29.0 + k * e / 6.0, 22.0 + k * e / 6.0, -0.1, 40)
		entre.append(entre[0])
		ci.draw_polyline(entre, Color(P.ENCRE, 0.6) * m, w * 0.5, true)
	for i in 20:
		var a := TAU * i / 20.0
		for k in 3:
			var r0 := (k - 1) * e / 3.0 - e / 6.0 + 1.2
			var r1 := r0 + e / 3.0 - 2.4
			var a0 := a + k * 0.11
			var p0 := c + Vector2(cos(a0) * (29.0 + r0), sin(a0) * (22.0 + r0)).rotated(-0.1)
			var p1 := c + Vector2(cos(a0 + 0.13) * (29.0 + r1), sin(a0 + 0.13) * (22.0 + r1)).rotated(-0.1)
			ci.draw_line(p0, p1, Color(P.ENCRE, 0.42) * m, w * 0.4, true)
	ci.draw_arc(c, 25.0, PI * 1.08, PI * 1.42, 8, Color(P.PAPIER, 0.55) * m, w * 0.7, true)
	# (le lien : un brin rouille noué en travers, comme sur la gerbe de fibres)
	var d := Vector2.from_angle(-2.25)
	var t := d.orthogonal() * 4.6
	var p := c + Vector2(d.x * 29.0, d.y * 22.0)
	_forme(ci, PackedVector2Array([p - d * 12.5 - t, p + d * 12.5 - t, p + d * 12.5 + t, p - d * 12.5 + t]), ROUILLE, w * 0.9, m)


# une bâche : la toile tendue par ses quatre coins, ses œillets, les plis d'avoir été pliée en quatre
static func _bache(ci, w: float, m: Color) -> void:
	var a := Vector2(-32, -28)
	var b := Vector2(31, -33)
	var c := Vector2(36, 27)
	var d := Vector2(-34, 31)
	for coin in [a, b, c, d]:
		var hors: Vector2 = coin + (coin - Vector2(0, -1)).normalized() * 15.0
		_cordon(ci, PackedVector2Array([coin, hors]), 3.2, CHANVRE, w, m)
	var pts := _contour([[a, Vector2(0, -23), b], [b, Vector2(27, -3), c], [c, Vector2(1, 22), d], [d, Vector2(-27, 2), a]], 9)
	ci.draw_colored_polygon(pts, TOILE * m)
	# (le quart d'en bas à droite dans l'ombre, celui d'en haut à gauche dans la lumière)
	_part(ci, pts, PackedVector2Array([Vector2(2, 0), Vector2(60, -4), Vector2(60, 60), Vector2(0, 60)]), Color(TOILE_SOMBRE, 0.9) * m)
	_part(ci, pts, PackedVector2Array([Vector2(-60, -60), Vector2(1, -60), Vector2(2, 0), Vector2(-60, 2)]), Color(TOILE_CLAIRE, 0.9) * m)
	ci.draw_polyline(_bezier(Vector2(1, -26), Vector2(3, 0), Vector2(0, 25), 8), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-30, 2), Vector2(2, -2), Vector2(31, -4), 8), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-25, -22), Vector2(-14, -20), Vector2(-6, -21), 6), Color(P.PAPIER, 0.7) * m, w * 0.7, true)
	_cerne(ci, pts, w, m)
	for coin in [a, b, c, d]:
		var dans: Vector2 = coin + (Vector2(0, -1) - coin).normalized() * 7.5
		ci.draw_circle(dans, 3.6, P.ENCRE * m)
		ci.draw_circle(dans, 1.7, P.PAPIER * m)


# la peau d'une bête, tendue : le cou, les quatre pattes, la queue, le poil le long de l'échine
static func _peau(ci, w: float, m: Color) -> void:
	var moitie := [Vector2(6, -45), Vector2(9, -33), Vector2(27, -40), Vector2(44, -37), Vector2(44, -25), Vector2(25, -19), Vector2(17, -6), Vector2(18, 7),
		Vector2(28, 15), Vector2(45, 20), Vector2(46, 33), Vector2(31, 36), Vector2(17, 29), Vector2(10, 35), Vector2(5, 39), Vector2(3, 47)]
	var brut := PackedVector2Array(moitie)
	for i in range(moitie.size() - 1, -1, -1):
		brut.append(Vector2(-moitie[i].x, moitie[i].y))
	var pts := _lisse(brut, 2)
	_volume(ci, pts, CUIR, w, m, 5.0, 0.3)
	# (le côté chair, plus clair, en retrait du bord)
	var dedans := PackedVector2Array()
	for p in _lisse(PackedVector2Array([Vector2(0, -34), Vector2(13, -26), Vector2(11, -6), Vector2(13, 12), Vector2(10, 26), Vector2(0, 32),
		Vector2(-10, 26), Vector2(-13, 12), Vector2(-11, -6), Vector2(-13, -26)]), 2):
		dedans.append(p)
	ci.draw_colored_polygon(dedans, Color(CUIR_CLAIR, 0.85) * m)
	for i in 6:
		var y := -26.0 + i * 10.0
		ci.draw_line(Vector2(0, y), Vector2(-5, y + 5.5), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
		ci.draw_line(Vector2(0, y), Vector2(5, y + 5.5), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-39, -34), Vector2(-28, -37), Vector2(-14, -30), 6), Color(P.PAPIER, 0.5) * m, w * 0.7, true)


# de la ferraille : une roue dentée rouillée, un écrou, un clou tordu
static func _ferraille(ci, w: float, m: Color) -> void:
	var c := Vector2(-11, -9)
	var roue := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		roue.append(c + Vector2.from_angle(a - 0.25) * 20.0)
		roue.append(c + Vector2.from_angle(a - 0.15) * 29.0)
		roue.append(c + Vector2.from_angle(a + 0.15) * 29.0)
		roue.append(c + Vector2.from_angle(a + 0.25) * 20.0)
	_volume(ci, roue, ROUILLE.lerp(CUIR_SOMBRE, 0.2), w, m, 5.0, 0.32)
	_forme(ci, _ellipse(c, 10.5, 10.5, 0.0, 20), ROUILLE.lerp(BOIS, 0.35), w * 0.8, m)
	ci.draw_circle(c, 4.2, P.ENCRE_DOUCE * m)
	ci.draw_arc(c, 24.0, PI * 1.05, PI * 1.4, 8, Color(P.PAPIER, 0.4) * m, w * 0.7, true)
	# (l'écrou)
	var e := Vector2(-27, 31)
	var ecrou := PackedVector2Array()
	for i in 6:
		ecrou.append(e + Vector2.from_angle(TAU * i / 6.0 + 0.3) * 12.5)
	_volume(ci, ecrou, FER, w, m, 3.5, 0.3)
	ci.draw_circle(e, 5.2, P.ENCRE * m)
	ci.draw_circle(e, 3.4, P.ENCRE_DOUCE.lerp(FER, 0.25) * m)
	# (le clou : tordu, sa tête plate)
	var clou := PackedVector2Array([Vector2(2, 42), Vector2(13, 24), Vector2(20, 6), Vector2(39, -11)])
	_cordon(ci, clou, 6.5, FER_CLAIR, w, m)
	ci.draw_line(Vector2(5, 35), Vector2(14, 19), Color(P.PAPIER, 0.55) * m, w * 0.6, true)
	_cordon(ci, PackedVector2Array([Vector2(33, -19), Vector2(45, -5)]), 5.5, FER_CLAIR, w, m)


# l'eau : une goutte, et le rond qu'elle fait
static func _eau(ci, w: float, m: Color) -> void:
	for r in [[34.0, 8.5, 0.9], [20.0, 4.6, 0.7]]:
		var rond := _ellipse(Vector2(0, 35), r[0], r[1], 0.0, 30)
		rond.append(rond[0])
		ci.draw_polyline(rond, Color(EAU_SOMBRE, r[2]) * m, w * 0.9, true)
	var pts := PackedVector2Array([Vector2(0, -46)])
	for i in 23:
		pts.append(Vector2(0, 4) + Vector2.from_angle(-PI * 0.22 + PI * 1.44 * i / 22.0) * 25.0)
	_volume(ci, pts, EAU, w, m, 6.0, 0.25)
	ci.draw_arc(Vector2(-2, 4), 15.0, PI * 0.95, PI * 1.45, 10, Color(P.PAPIER, 0.8) * m, w * 0.9, true)


# un bouillon : l'écuelle de bois, ce qui fume dedans, la cuiller
static func _bouillon(ci, w: float, m: Color) -> void:
	_vapeur(ci, Vector2(-12, -8), 32.0, w, m)
	_vapeur(ci, Vector2(8, -12), 30.0, w, m)
	_cordon(ci, PackedVector2Array([Vector2(12, 4), Vector2(42, -22)]), 4.6, BOIS, w, m)
	var bol := PackedVector2Array()
	for i in 19:
		var a := PI * i / 18.0
		bol.append(Vector2(cos(a) * 41.0, 6.0 + sin(a) * 34.0))
	_volume(ci, bol, ECORCE, w, m, 6.0, 0.3)
	_forme(ci, _ellipse(Vector2(0, 6), 41.0, 10.0, 0.0, 32), MANCHE, w, m)
	_forme(ci, _ellipse(Vector2(0, 7), 33.0, 6.5, 0.0, 28), BOUILLON, w * 0.7, m)
	ci.draw_arc(Vector2(-6, 6), 18.0, PI * 1.08, PI * 1.5, 8, Color(P.PAPIER, 0.6) * m, w * 0.6, true)
	ci.draw_arc(Vector2(0, 8), 30.0, PI * 0.14, PI * 0.42, 8, Color(P.PAPIER, 0.4) * m, w * 0.8, true)


# --- le camp ---

# l'établi : un plateau épais sur deux pieds de rondin, le maillet de pierre posé dessus, une bûche à travailler
static func _etabli(ci, w: float, m: Color) -> void:
	for sx in [-1.0, 1.0]:
		_volume(ci, _capsule(Vector2(sx * 27.0, 10), Vector2(sx * 31.0, 38), 6.5), ECORCE, w, m, 3.0, 0.3)
	_forme(ci, _rect(-27, 19, 27, 25), MANCHE, w * 0.8, m)
	# (la bûche, couchée au bout du plateau : son bout coupé vers nous)
	_forme(ci, _rect(8, -23, 34, -7), ECORCE, w, m)
	_forme(ci, _ellipse(Vector2(34, -15), 5.0, 8.0, 0.0, 16), BOIS, w * 0.8, m)
	ci.draw_line(Vector2(12, -18), Vector2(27, -18), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	# (le maillet : son manche, sa tête de pierre liée de corde)
	_cordon(ci, PackedVector2Array([Vector2(-21, -22), Vector2(-9, -46)]), 5.0, MANCHE, w, m)
	var tete: PackedVector2Array = Transform2D(-0.07, Vector2(-21, -18.5)) * _arrondi(-15, -10, 15, 10, 5.0)
	_volume(ci, tete, PIERRE, w, m, 4.0, 0.3)
	for x in [-24.0, -19.0]:
		ci.draw_line(Vector2(x, -27.5), Vector2(x + 1.5, -9.5), Color(P.ENCRE, 0.6) * m, w * 0.55, true)
	ci.draw_line(Vector2(-33, -23), Vector2(-28, -24), Color(P.PAPIER, 0.7) * m, w * 0.7, true)
	# (le plateau, et le fil de son bois)
	var plateau := PackedVector2Array([Vector2(-45, -8), Vector2(45, -8), Vector2(43, 8), Vector2(-43, 8)])
	_volume(ci, plateau, BOIS, w, m, 4.0, 0.25)
	ci.draw_line(Vector2(-37, -2), Vector2(4, -2), Color(P.ENCRE, 0.4) * m, w * 0.45, true)
	ci.draw_line(Vector2(-12, 3), Vector2(36, 3), Color(P.ENCRE, 0.4) * m, w * 0.45, true)
	ci.draw_line(Vector2(-41, -5), Vector2(-8, -5), Color(P.PAPIER, 0.55) * m, w * 0.6, true)


# la tente : deux pans de toile sur des perches croisées, l'ouverture sombre, un pan relevé
static func _tente(ci, w: float, m: Color) -> void:
	var faite := Vector2(-8, -33)
	var fond := Vector2(27, -26)
	# (les perches, qui dépassent du faîte)
	_cordon(ci, PackedVector2Array([faite + Vector2(5, 10), faite + Vector2(-9, -14)]), 3.4, MANCHE, w, m)
	_cordon(ci, PackedVector2Array([faite + Vector2(-5, 10), faite + Vector2(9, -14)]), 3.4, MANCHE, w, m)
	_cordon(ci, PackedVector2Array([fond + Vector2(-3, 6), fond + Vector2(5, -11)]), 3.0, MANCHE, w, m)
	_forme(ci, PackedVector2Array([faite, fond, Vector2(47, 31), Vector2(22, 37)]), TOILE_SOMBRE, w, m)
	var face := PackedVector2Array([faite, Vector2(22, 37), Vector2(-45, 37)])
	_forme(ci, face, TOILE, w, m)
	ci.draw_line(Vector2(-13, -19), Vector2(-34, 28), Color(P.PAPIER, 0.6) * m, w * 0.7, true)
	# (l'ouverture, et le pan qu'on a roulé sur le côté)
	var porte := PackedVector2Array([Vector2(-8, -12), Vector2(7, 37), Vector2(-24, 37)])
	_forme(ci, porte, P.ENCRE_DOUCE.lerp(P.NUIT_BLEUE, 0.35), w * 0.8, m)
	_forme(ci, PackedVector2Array([Vector2(-8, -12), Vector2(-24, 37), Vector2(-32, 37), Vector2(-15, 2)]), TOILE_CLAIRE, w * 0.8, m)
	# (le sol, deux brins d'herbe)
	ci.draw_line(Vector2(-49, 41), Vector2(49, 39), Color(P.ENCRE, 0.55) * m, w * 0.6, true)
	ci.draw_line(Vector2(36, 39), Vector2(40, 32), Color(P.ENCRE, 0.6) * m, w * 0.55, true)
	ci.draw_line(Vector2(40, 39), Vector2(46, 34), Color(P.ENCRE, 0.6) * m, w * 0.55, true)


# le hamac : une toile qui pend entre deux piquets, ses suspentes
static func _hamac(ci, w: float, m: Color) -> void:
	for sx in [-1.0, 1.0]:
		_volume(ci, _capsule(Vector2(sx * 39.0, -37), Vector2(sx * 42.5, 39), 3.8), ECORCE, w, m, 2.0, 0.3)
		for dy in [0.0, 5.0]:
			_cordon(ci, PackedVector2Array([Vector2(sx * 39.5, -25), Vector2(sx * 28.0, -8.0 + dy)]), 2.2, CHANVRE, w * 0.8, m)
		_forme(ci, _rect(sx * 39.5 - 5.5, -29, sx * 39.5 + 5.5, -22), CHANVRE, w * 0.8, m)
	var haut := _bezier(Vector2(-30, -9), Vector2(0, 9), Vector2(30, -9), 14)
	var bas := _bezier(Vector2(30, -5), Vector2(0, 54), Vector2(-30, -5), 14)
	var pts := haut + bas
	ci.draw_colored_polygon(pts, TOILE * m)
	# (le fond du creux, dans l'ombre ; les lés de la toile)
	_part(ci, pts, _bezier(Vector2(-33, 4), Vector2(0, 36), Vector2(33, 4), 12) + PackedVector2Array([Vector2(33, 60), Vector2(-33, 60)]), Color(TOILE_SOMBRE, 0.95) * m)
	ci.draw_polyline(_bezier(Vector2(-30, -8), Vector2(0, 26), Vector2(30, -8), 12), Color(P.ENCRE, 0.45) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-30, -7), Vector2(0, 41), Vector2(30, -7), 12), Color(P.ENCRE, 0.45) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-20, -2), Vector2(-10, 5), Vector2(0, 5), 6), Color(P.PAPIER, 0.6) * m, w * 0.7, true)
	_cerne(ci, pts, w, m)
	ci.draw_line(Vector2(-49, 42), Vector2(49, 42), Color(P.ENCRE, 0.55) * m, w * 0.6, true)


# le récupérateur d'eau : la toile en entonnoir entre deux piquets, la pluie dessus, la goutte, le pot qui se remplit
static func _recuperateur(ci, w: float, m: Color) -> void:
	for sx in [-1.0, 1.0]:
		_volume(ci, _capsule(Vector2(sx * 38.0, -31), Vector2(sx * 40.5, 40), 3.8), ECORCE, w, m, 2.0, 0.3)
	for p in [Vector2(-20, -48), Vector2(0, -49), Vector2(20, -48)]:
		I.trait_encre(ci, p, p + Vector2(-5, 14), 5.5, EAU_SOMBRE * m)
	var pts := _contour([[Vector2(-37, -26), Vector2(0, -20), Vector2(37, -26)], [Vector2(37, -26), Vector2(9, -10), Vector2(4, 7)], [Vector2(-4, 7)],
		[Vector2(-4, 7), Vector2(-9, -10), Vector2(-37, -26)]], 8)
	ci.draw_colored_polygon(pts, TOILE * m)
	_part(ci, pts, PackedVector2Array([Vector2(3, -40), Vector2(50, -40), Vector2(50, 20), Vector2(-1, 20)]), Color(TOILE_SOMBRE, 0.95) * m)
	ci.draw_line(Vector2(-16, -23), Vector2(-2, 5), Color(P.ENCRE, 0.45) * m, w * 0.5, true)
	ci.draw_line(Vector2(17, -23), Vector2(2, 5), Color(P.ENCRE, 0.45) * m, w * 0.5, true)
	ci.draw_line(Vector2(-29, -22), Vector2(-17, -20), Color(P.PAPIER, 0.65) * m, w * 0.7, true)
	_cerne(ci, pts, w, m)
	_goutte(ci, Vector2(0, 17), 3.6, w * 0.7, m)
	# (le pot, et l'eau qui y monte)
	var pot := _contour([[Vector2(-17, 27)], [Vector2(-17, 27), Vector2(-18, 45), Vector2(-7, 45)], [Vector2(7, 45), Vector2(18, 45), Vector2(17, 27)]], 6)
	_volume(ci, pot, CUIR, w, m, 3.0, 0.3)
	_forme(ci, _ellipse(Vector2(0, 27), 17.0, 4.6, 0.0, 22), EAU, w * 0.8, m)


# le filet : sa maille tendue au ras du sol, une pierre à chaque coin
static func _filet(ci, w: float, m: Color) -> void:
	var a := Vector2(-40, -11)
	var b := Vector2(25, -29)
	var c := Vector2(42, 13)
	var d := Vector2(-27, 33)
	var pts := PackedVector2Array([a, b, c, d])
	ci.draw_colored_polygon(pts, Color(FOURRURE, 0.55) * m)
	for i in range(1, 5):
		var u := i / 5.0
		ci.draw_line(a.lerp(b, u), d.lerp(c, u), Color(P.ENCRE, 0.75) * m, w * 0.5, true)
		ci.draw_line(a.lerp(d, u), b.lerp(c, u), Color(P.ENCRE, 0.75) * m, w * 0.5, true)
	var tour := pts.duplicate()
	tour.append(a)
	_cordon(ci, tour, 3.6, CHANVRE, w, m)
	for coin in [[a, 8.5], [b, 7.5], [c, 8.5], [d, 9.5]]:
		var p: Vector2 = coin[0]
		var pierre := _lisse(PackedVector2Array([p + Vector2(-coin[1], 1), p + Vector2(-3, -coin[1] * 0.8), p + Vector2(coin[1], -2), p + Vector2(coin[1] * 0.7, coin[1] * 0.7), p + Vector2(-coin[1] * 0.6, coin[1] * 0.75)]), 1)
		_volume(ci, pierre, PIERRE, w * 0.9, m, 2.5, 0.35)


# le cerf-volant : sa voilure en losange sur deux baguettes, sa queue de rubans, le fil qui descend
static func _cerf_volant(ci, w: float, m: Color) -> void:
	var haut := Vector2(9, -46)
	var droite := Vector2(35, -17)
	var bas := Vector2(-11, 19)
	var gauche := Vector2(-23, -24)
	var croix: Vector2 = Geometry2D.line_intersects_line(haut, bas - haut, gauche, droite - gauche)
	# (le fil, puis la queue et ses nœuds de ruban)
	ci.draw_polyline(_bezier(croix, Vector2(20, 26), Vector2(47, 45), 10), Color(P.ENCRE, 0.8) * m, w * 0.5, true)
	var queue := _bezier(bas, Vector2(-32, 22), Vector2(-25, 35), 8)
	queue.append_array(_bezier(Vector2(-25, 35), Vector2(-19, 46), Vector2(-39, 47), 8).slice(1))
	ci.draw_polyline(queue, P.ENCRE * m, w * 0.7, true)
	for k in [4, 10, 15]:
		var p: Vector2 = queue[k]
		var dx: Vector2 = (queue[k + 1] - queue[k - 1]).normalized()
		_forme(ci, PackedVector2Array([p - dx * 6.5, p + dx.orthogonal() * 4.2, p + dx * 6.5, p - dx.orthogonal() * 4.2]), ROUILLE, w * 0.7, m)
	ci.draw_colored_polygon(PackedVector2Array([haut, droite, croix]), TOILE_CLAIRE * m)
	ci.draw_colored_polygon(PackedVector2Array([droite, bas, croix]), ROUILLE.lerp(CUIR_SOMBRE, 0.25) * m)
	ci.draw_colored_polygon(PackedVector2Array([bas, gauche, croix]), TOILE * m)
	ci.draw_colored_polygon(PackedVector2Array([gauche, haut, croix]), ROUILLE * m)
	ci.draw_line(haut, bas, P.ENCRE * m, w * 0.65, true)
	ci.draw_line(gauche, droite, P.ENCRE * m, w * 0.65, true)
	_cerne(ci, PackedVector2Array([haut, droite, bas, gauche]), w, m)
	ci.draw_line(Vector2(11, -37), Vector2(26, -20), Color(P.PAPIER, 0.6) * m, w * 0.6, true)


# --- la tenue ---

# le sac à dos : de peau, son rabat sanglé, ses bretelles, le rouleau lié dessus
static func _sac_a_dos(ci, w: float, m: Color) -> void:
	for sx in [-1.0, 1.0]:
		_cordon(ci, _bezier(Vector2(sx * 23.0, -8), Vector2(sx * 47.0, 6), Vector2(sx * 26.0, 34), 10), 6.0, CUIR_SOMBRE, w, m)
	# (le rouleau : une couverture roulée, liée de deux sangles)
	var rouleau := _capsule(Vector2(-23, -31), Vector2(23, -31), 10.5)
	_volume(ci, rouleau, FOURRURE, w, m, 3.5, 0.28)
	for x in [-13.0, 13.0]:
		ci.draw_line(Vector2(x, -41.5), Vector2(x, -20.5), P.ENCRE * m, w * 1.5, true)
		ci.draw_line(Vector2(x, -41.0), Vector2(x, -21.0), CUIR_SOMBRE * m, w * 0.6, true)
	ci.draw_arc(Vector2(27, -31), 5.0, -PI * 0.5, PI * 0.9, 8, Color(P.ENCRE, 0.6) * m, w * 0.5, true)
	var corps := _lisse(PackedVector2Array([Vector2(-27, -20), Vector2(27, -20), Vector2(32, 8), Vector2(30, 40), Vector2(-30, 40), Vector2(-32, 8)]), 2)
	_volume(ci, corps, CUIR, w, m, 6.0, 0.3)
	# (la poche de devant)
	var poche := _arrondi(-18, 18, 18, 35, 5.0)
	_cerne(ci, poche, w * 0.6, m, 0.7)
	# (le rabat, sa sangle et sa boucle)
	var rabat := _contour([[Vector2(-28, -20)], [Vector2(28, -20)], [Vector2(31, 2)], [Vector2(31, 2), Vector2(0, 16), Vector2(-31, 2)]], 10)
	_forme(ci, rabat, CUIR_SOMBRE, w, m)
	ci.draw_polyline(_bezier(Vector2(-27, -1), Vector2(0, 11), Vector2(27, -1), 10), Color(FOURRURE, 0.7) * m, w * 0.45, true)
	ci.draw_line(Vector2(-22, -15), Vector2(-8, -16), Color(P.PAPIER, 0.4) * m, w * 0.7, true)
	_forme(ci, _rect(-4, -6, 4, 25), BOIS, w * 0.8, m)
	_forme(ci, _rect(-7, 11, 7, 20), FER_CLAIR, w * 0.8, m)
	ci.draw_line(Vector2(-2, 15.5), Vector2(4, 15.5), P.ENCRE * m, w * 0.6, true)


# la pelisse : un manteau de peau, le col, les poignets et le bas doublés de fourrure
static func _pelisse(ci, w: float, m: Color) -> void:
	var moitie := [Vector2(7, -29), Vector2(20, -27), Vector2(44, 10), Vector2(33, 18), Vector2(21, -2), Vector2(27, 37)]
	var pts := PackedVector2Array(moitie)
	for i in range(moitie.size() - 1, -1, -1):
		pts.append(Vector2(-moitie[i].x, moitie[i].y))
	_volume(ci, pts, CUIR, w, m, 6.0, 0.3)
	# (le devant qui croise, ses brandebourgs de bois)
	ci.draw_line(Vector2(1, -24), Vector2(-1, 34), P.ENCRE * m, w * 0.7, true)
	for y in [-9.0, 5.0, 19.0]:
		_cordon(ci, PackedVector2Array([Vector2(-6, y), Vector2(6, y + 1.0)]), 2.6, BOIS, w * 0.8, m)
	ci.draw_line(Vector2(-18, -20), Vector2(-33, 4), Color(P.PAPIER, 0.4) * m, w * 0.7, true)
	# (la fourrure : le bas, les poignets, le col)
	var bas := PackedVector2Array([Vector2(-30, 38), Vector2(-29, 32), Vector2(29, 32), Vector2(30, 38)])
	for i in 5:
		for k in 5:
			bas.append(Vector2(24.0 - 12.0 * i, 39.0) + Vector2.from_angle(PI * (0.1 + 0.8 * k / 4.0)) * Vector2(5.8, 5.5))
	_forme(ci, bas, FOURRURE, w, m)
	for sx in [-1.0, 1.0]:
		_forme(ci, _touffe(Vector2(sx * 38.5, 15.0), 9.5, 6.0, sx * -0.62, 5), FOURRURE, w, m)
	_forme(ci, _touffe(Vector2(0, -31), 19.0, 8.5, 0.0, 7), FOURRURE, w, m)
	ci.draw_arc(Vector2(0, -34), 9.0, PI * 0.15, PI * 0.85, 8, Color(P.ENCRE, 0.55) * m, w * 0.55, true)


# la cape de pluie : cirée, plus claire, son capuchon pointu ; la pluie perle dessus et rebondit
static func _cape_de_pluie(ci, w: float, m: Color) -> void:
	var pts := _contour([[Vector2(6, -47), Vector2(18, -34), Vector2(16, -15)], [Vector2(16, -15), Vector2(32, 6), Vector2(39, 33)],
		[Vector2(39, 33), Vector2(28, 42), Vector2(16, 36)], [Vector2(16, 36), Vector2(4, 44), Vector2(-9, 37)], [Vector2(-9, 37), Vector2(-24, 44), Vector2(-39, 34)],
		[Vector2(-39, 34), Vector2(-32, 6), Vector2(-16, -15)], [Vector2(-16, -15), Vector2(-17, -36), Vector2(6, -47)]], 8)
	_volume(ci, pts, TOILE_CLAIRE, w, m, 7.0, 0.3)
	# (le creux du capuchon, le fermoir rouille, le devant, les plis)
	_forme(ci, _ellipse(Vector2(0, -23), 9.5, 11.5, 0.0, 22), P.ENCRE_DOUCE.lerp(P.NUIT_BLEUE, 0.4), w * 0.8, m)
	ci.draw_line(Vector2(0, -8), Vector2(1, 37), Color(P.ENCRE, 0.7) * m, w * 0.6, true)
	ci.draw_polyline(_bezier(Vector2(-13, -6), Vector2(-20, 14), Vector2(-24, 37), 8), Color(P.ENCRE, 0.4) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(13, -6), Vector2(21, 14), Vector2(26, 35), 8), Color(P.ENCRE, 0.4) * m, w * 0.5, true)
	_forme(ci, _ellipse(Vector2(0, -8.5), 3.8, 3.8, 0.0, 12), ROUILLE, w * 0.7, m)
	ci.draw_polyline(_bezier(Vector2(-9, -40), Vector2(-15, -32), Vector2(-14, -18), 8), Color(P.PAPIER, 0.85) * m, w * 0.8, true)
	ci.draw_polyline(_bezier(Vector2(-19, -8), Vector2(-28, 6), Vector2(-33, 22), 8), Color(P.PAPIER, 0.8) * m, w * 0.8, true)
	# (la pluie : elle tombe, elle rebondit)
	_goutte(ci, Vector2(-33, -30), 4.2, w * 0.7, m)
	_goutte(ci, Vector2(33, -33), 4.2, w * 0.7, m)
	_goutte(ci, Vector2(43, -3), 3.4, w * 0.7, m)
	for t in [[Vector2(-24, -13), Vector2(-34, -20)], [Vector2(-27, -6), Vector2(-39, -7)], [Vector2(24, -15), Vector2(32, -23)]]:
		I.trait_encre(ci, t[0], t[1], 4.5, EAU_SOMBRE * m)


# --- les outils ---

# la gourde : une outre de peau cousue, son goulot, son bouchon de bois, le cordon qui la porte
static func _gourde(ci, w: float, m: Color) -> void:
	_cordon(ci, _bezier(Vector2(8, -26), Vector2(-52, -26), Vector2(-24, 26), 12), 3.4, CHANVRE, w, m)
	var corps := _lisse(PackedVector2Array([Vector2(6, -24), Vector2(19, -15), Vector2(31, 6), Vector2(28, 28), Vector2(8, 42), Vector2(-15, 38), Vector2(-28, 20), Vector2(-25, -3),
		Vector2(-10, -19)]), 2)
	_volume(ci, corps, CUIR, w, m, 7.0, 0.3)
	# (la couture, le long du flanc)
	var couture := _bezier(Vector2(14, -10), Vector2(27, 14), Vector2(10, 34), 10)
	for i in range(0, couture.size() - 1, 2):
		ci.draw_line(couture[i], couture[i + 1], Color(FOURRURE, 0.85) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-18, 16), Vector2(-21, 0), Vector2(-9, -11), 8), Color(P.PAPIER, 0.55) * m, w * 0.8, true)
	_forme(ci, PackedVector2Array([Vector2(1, -25), Vector2(15, -17), Vector2(22, -31), Vector2(11, -37)]), CUIR_SOMBRE, w, m)
	_forme(ci, PackedVector2Array([Vector2(12, -38), Vector2(21, -33), Vector2(27, -43), Vector2(17, -48)]), BOIS, w * 0.9, m)
	_goutte(ci, Vector2(37, -15), 4.6, w * 0.7, m)


# la popote : une marmite de ferraille sur trois pierres, son anse levée, ce qui fume dedans
static func _popote(ci, w: float, m: Color) -> void:
	_cordon(ci, _bezier(Vector2(-30, -6), Vector2(0, -56), Vector2(30, -6), 16), 2.6, FER_CLAIR, w, m)
	_vapeur(ci, Vector2(-9, -10), 34.0, w, m)
	_vapeur(ci, Vector2(10, -12), 30.0, w, m)
	for p in [Vector2(-27, 38), Vector2(27, 38)]:
		_volume(ci, _lisse(PackedVector2Array([p + Vector2(-11, 2), p + Vector2(-5, -8), p + Vector2(8, -7), p + Vector2(11, 3), p + Vector2(2, 8)]), 1), PIERRE, w * 0.9, m, 2.5, 0.35)
	var corps := _contour([[Vector2(-31, -5)], [Vector2(-31, -5), Vector2(-34, 32), Vector2(-14, 34)], [Vector2(14, 34), Vector2(34, 32), Vector2(31, -5)]], 8)
	_volume(ci, corps, FER, w, m, 7.0, 0.32)
	ci.draw_polyline(_bezier(Vector2(-24, 2), Vector2(-25, 20), Vector2(-17, 27), 8), Color(P.PAPIER, 0.5) * m, w * 0.8, true)
	_forme(ci, _ellipse(Vector2(0, -5), 31.0, 8.5, 0.0, 30), FER_CLAIR, w, m)
	_forme(ci, _ellipse(Vector2(0, -4.5), 24.0, 5.4, 0.0, 26), BOUILLON, w * 0.7, m)
	# (la pierre de devant)
	_volume(ci, _lisse(PackedVector2Array([Vector2(-11, 41), Vector2(-6, 32), Vector2(7, 32), Vector2(11, 41), Vector2(2, 46)]), 1), PIERRE, w * 0.9, m, 2.5, 0.35)


# le duvet : un sac de peau déroulé, matelassé, ouvert sur sa doublure de fourrure ; la lune dit qu'on y dort
static func _duvet(ci, w: float, m: Color) -> void:
	var tr := Transform2D(-0.62, Vector2(3, 6))
	var corps: PackedVector2Array = tr * _lisse(PackedVector2Array([Vector2(-44, -10), Vector2(-12, -16), Vector2(28, -18), Vector2(44, -11), Vector2(47, 0), Vector2(44, 11), Vector2(28, 18),
		Vector2(-12, 16), Vector2(-44, 10), Vector2(-48, 0)]), 2)
	_volume(ci, corps, CUIR, w, m, 6.0, 0.3)
	# (les coutures en travers, le laçage sur le dessus)
	for x in [-30.0, -16.0, -2.0, 12.0]:
		var h: float = 14.0 + (float(x) + 44.0) * 0.045
		ci.draw_polyline(tr * _bezier(Vector2(x, -h), Vector2(x + 4.0, 0), Vector2(x, h), 8), Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	ci.draw_polyline(tr * PackedVector2Array([Vector2(-38, -6), Vector2(-20, -8.5), Vector2(6, -10)]), Color(P.PAPIER, 0.45) * m, w * 0.7, true)
	# (l'ouverture : la doublure, et le pan rabattu)
	_forme(ci, tr * _ellipse(Vector2(31, 0), 12.0, 14.0, 0.0, 22), FOURRURE, w, m)
	_forme(ci, tr * _lisse(PackedVector2Array([Vector2(16, -18), Vector2(30, -17), Vector2(25, 0), Vector2(30, 17), Vector2(16, 18)]), 1), CUIR_CLAIR, w * 0.9, m)
	# (la lune)
	var lune := Geometry2D.clip_polygons(_ellipse(Vector2(-28, -30), 11.5, 11.5, 0.0, 24), _ellipse(Vector2(-22, -34), 10.0, 10.0, 0.0, 24))
	for q in lune:
		_forme(ci, q, Color("d8dcd6").lerp(P.LUNE, 0.3), w * 0.8, m)


# la lampe : un tube de ferraille, sa tête évasée, son poussoir rouille, le faisceau qu'elle jette
static func _lampe(ci, w: float, m: Color) -> void:
	var tr := Transform2D(-PI * 0.25, Vector2(-5, 7))
	# (le faisceau : clair, ses deux bords à l'encre)
	var faisceau: PackedVector2Array = tr * PackedVector2Array([Vector2(25, -13), Vector2(46, -24), Vector2(50, -9), Vector2(50, 9), Vector2(46, 24), Vector2(25, 13)])
	ci.draw_colored_polygon(faisceau, P.BRAISE_COEUR * m)
	ci.draw_colored_polygon(tr * PackedVector2Array([Vector2(25, -6), Vector2(49, -8), Vector2(49, 8), Vector2(25, 6)]), Color(P.PAPIER, 0.55) * m)
	ci.draw_line(tr * Vector2(25, -13), tr * Vector2(46, -24), Color(P.ENCRE, 0.85) * m, w * 0.6, true)
	ci.draw_line(tr * Vector2(25, 13), tr * Vector2(46, 24), Color(P.ENCRE, 0.85) * m, w * 0.6, true)
	var fut: PackedVector2Array = tr * _arrondi(-45, -9, 6, 9, 4.0)
	_volume(ci, fut, FER, w, m, 3.5, 0.3)
	for x in [-37.0, -31.0]:
		ci.draw_line(tr * Vector2(x, -8), tr * Vector2(x, 8), Color(P.ENCRE, 0.6) * m, w * 0.5, true)
	ci.draw_line(tr * Vector2(-24, -4.5), tr * Vector2(0, -4.5), Color(P.PAPIER, 0.55) * m, w * 0.7, true)
	_forme(ci, tr * _rect(-19, -14.5, -6, -8.5), ROUILLE, w * 0.8, m)
	var tete: PackedVector2Array = tr * PackedVector2Array([Vector2(5, -9), Vector2(19, -17), Vector2(25, -17), Vector2(25, 17), Vector2(19, 17), Vector2(5, 9)])
	_volume(ci, tete, FER_CLAIR, w, m, 3.5, 0.3)
	ci.draw_line(tr * Vector2(19, -16), tr * Vector2(19, 16), Color(P.ENCRE, 0.7) * m, w * 0.55, true)


# les piles : deux, côte à côte, leur plot, leur bande sombre, l'éclair de ce qu'elles gardent
static func _piles(ci, w: float, m: Color) -> void:
	_pile(ci, w, m, Transform2D(0.24, Vector2(17, 3)), false)
	_pile(ci, w, m, Transform2D(-0.07, Vector2(-14, 5)), true)


static func _pile(ci, w: float, m: Color, tr: Transform2D, eclair: bool) -> void:
	_forme(ci, tr * _rect(-5, -39, 5, -30), FER_CLAIR, w * 0.9, m)
	var corps: PackedVector2Array = tr * _arrondi(-13, -31, 13, 36, 4.5)
	ci.draw_colored_polygon(corps, ROUILLE * m)
	_part(ci, corps, tr * _rect(-20, -40, 20, -14), FER * m)
	_ombre(ci, corps, m, 5.0, 0.3)
	ci.draw_line(tr * Vector2(-13, -14), tr * Vector2(13, -14), P.ENCRE * m, w * 0.6, true)
	ci.draw_line(tr * Vector2(-8, -8), tr * Vector2(-8, 29), Color(P.PAPIER, 0.4) * m, w * 0.7, true)
	_cerne(ci, corps, w, m)
	if eclair:
		ci.draw_line(tr * Vector2(-4, -22.5), tr * Vector2(4, -22.5), P.PAPIER * m, w * 0.75, true)
		ci.draw_line(tr * Vector2(0, -26.5), tr * Vector2(0, -18.5), P.PAPIER * m, w * 0.75, true)
		_forme(ci, tr * PackedVector2Array([Vector2(4, -7), Vector2(-7, 11), Vector2(-1, 11), Vector2(-5, 28), Vector2(8, 6), Vector2(2, 6)]), P.BRAISE_COEUR, w * 0.7, m)
