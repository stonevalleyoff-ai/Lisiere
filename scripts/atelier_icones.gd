extends RefCounted
# Lisière — les icônes de l'atelier, dessinées à l'encre (scripts/atelier_icones.gd)
# Une par chose qui se fabrique (les seize de scripts/atelier.gd, ORDRE), une par matière nouvelle (la peau, la ferraille, la
# corde, la bâche, l'eau), et le bouillon : pour la page de l'établi, celle du sac, et partout où le jeu les montre.
# Et celles du jardin et de l'élevage : la houe, l'arrosoir, l'épouvantail, le licol, le piquet, la mangeoire, les sacoches, la
# selle ; pour la page du sac, le carré, l'appât, les trois sachets de graines (on les distingue à leur lien et à ce qui est
# peint dessus), les simples, le lait, et « bete » (une tête de bête à licol : tes bêtes).
# Et la carte (une peau roulée sur sa corde, un chemin et sa croix), la plume et son godet d'encre (scripts/reperes.gd).
# Et celles de la cueillette (scripts/flore.gd) : un petit bouquet de fleurs des prés lié d'un brin, le cèpe (brun, le pied
# ventru), l'amanite (rouge piquée de blanc, son anneau), l'infusion (un bol fumant, une fleur qui y flotte).
# Et celles de l'herbier : le cahier où une plante est pressée, le mortier, et ce qu'on y prépare — le baume, la tisane, le
# philtre, la botte âcre, les deux appâts (l'empoisonné : de la viande ; le dormant : des baies, sous la lune).
# Dans le trait de scripts/interface_icones.gd : une boîte de 100 unités, centrée, mise à la taille voulue ; des aplats de la
# palette cernés d'encre, l'ombre en bas à droite (la lumière vient d'en haut à gauche), une touche de papier pour l'éclat.
# Chacune est tracée une fois dans un maillage gardé (scripts/interface_trace.gd), puis dessinée d'un seul appel.
# Ce qui est clair (une vapeur, un faisceau, un cordage) est cerné d'encre : ces icônes se lisent sur le papier d'une page
# comme sur un jeton sombre du HUD. Un nom qu'on ne connaît pas ici est demandé aux icônes du HUD (le bois, la pierre…).

const P := preload("res://scripts/palette.gd")
const I := preload("res://scripts/interface_icones.gd")
const Trace := preload("res://scripts/interface_trace.gd")
const NOMS := ["corde", "bache", "etabli", "tente", "hamac", "recuperateur", "filet", "cerf_volant", "sac_a_dos", "vetement_chaud",
	"vetement_pluie", "gourde", "popote", "duvet", "lampe", "piles", "peau", "ferraille", "eau", "bouillon",
	"houe", "arrosoir", "epouvantail", "licol", "piquet", "mangeoire", "sacoche", "selle",
	"carre", "appat", "graine_baie", "graine_lin", "graine_simple", "simples", "lait", "bete",
	"herbier", "mortier", "baume", "tisane", "philtre", "botte", "appat_poison", "appat_dormant", "carte", "plume",
	"fleurs", "champignons", "amanite", "infusion",
	# (ce que donnent les pays qui ont leur caractère : scripts/biomes.gd)
	"obsidienne", "tourbe", "lance_obsidienne"]

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
const VERT := Color("5f7d44")           # (la feuille : la mousse, un peu plus claire)
const ROUGE := Color("a8321f")          # (les baies : celles du HUD)
const BLEU := Color("7f97c6")           # (la fleur du lin : la lune, éclaircie)
const LAIT := Color("efe8d6")           # (le papier, plus blanc)
const PELAGE := Color("ac9e83")         # (le poil d'une bête : l'ivoire, tiré vers la terre)

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
		"houe":
			_houe(ci, w, m)
		"arrosoir":
			_arrosoir(ci, w, m)
		"epouvantail":
			_epouvantail(ci, w, m)
		"licol":
			_licol(ci, w, m)
		"piquet":
			_piquet(ci, w, m)
		"mangeoire":
			_mangeoire(ci, w, m)
		"sacoche":
			_sacoche(ci, w, m)
		"selle":
			_selle(ci, w, m)
		"carre":
			_carre(ci, w, m)
		"appat":
			_appat(ci, w, m)
		"graine_baie":
			_graine_baie(ci, w, m)
		"graine_lin":
			_graine_lin(ci, w, m)
		"graine_simple":
			_graine_simple(ci, w, m)
		"simples":
			_simples(ci, w, m)
		"lait":
			_lait(ci, w, m)
		"bete":
			_bete(ci, w, m)
		"herbier":
			_herbier(ci, w, m)
		"mortier":
			_mortier(ci, w, m)
		"baume":
			_baume(ci, w, m)
		"tisane":
			_tisane(ci, w, m)
		"philtre":
			_philtre(ci, w, m)
		"botte":
			_botte(ci, w, m)
		"appat_poison":
			_appat_poison(ci, w, m)
		"appat_dormant":
			_appat_dormant(ci, w, m)
		"carte":
			_carte(ci, w, m)
		"plume":
			_plume(ci, w, m)
		"fleurs":
			_fleurs(ci, w, m)
		"champignons":
			_champignon(ci, w, m, false)
		"amanite":
			_champignon(ci, w, m, true)
		"infusion":
			_infusion(ci, w, m)

		"obsidienne":
			_obsidienne(ci, w, m)
		"tourbe":
			_tourbe(ci, w, m)
		"lance_obsidienne":
			_lance_obsidienne(ci, w, m)


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


# --- le jardin ---

# la houe : un manche, une lame de pierre en travers, liée de corde ; un peu de terre y colle encore
static func _houe(ci, w: float, m: Color) -> void:
	var a := Vector2(-38, 42)
	var b := Vector2(21, -31)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_cordon(ci, PackedVector2Array([a, b + d * 9.0]), 6.5, MANCHE, w, m)
	var lame := _lisse(PackedVector2Array([b - d * 7.0 - n * 5.0, b + d * 7.0 - n * 5.0, b + d * 11.0 + n * 25.0, b - d * 11.0 + n * 29.0]), 1)
	_volume(ci, lame, PIERRE, w, m, 4.0, 0.3)
	ci.draw_line(b + d * 8.0 + n * 21.0, b - d * 8.0 + n * 24.0, Color(P.PAPIER, 0.55) * m, w * 0.6, true)
	for k in 3:
		var q := b + d * (-5.0 + k * 5.0)
		ci.draw_line(q - n * 7.0, q + n * 6.0, P.ENCRE * m, w * 1.6, true)
		ci.draw_line(q - n * 6.5, q + n * 5.5, CHANVRE * m, w * 0.7, true)
	for q in [Vector2(45, -8), Vector2(36, 5), Vector2(47, 6)]:
		ci.draw_circle(q, 3.2, P.ENCRE * m)
		ci.draw_circle(q, 2.0, P.TERRE.lightened(0.15) * m)


# l'arrosoir : une outre de peau ventrue, son anse de corde, son bec de bois ; l'eau en tombe goutte à goutte
static func _arrosoir(ci, w: float, m: Color) -> void:
	_cordon(ci, _bezier(Vector2(-30, -6), Vector2(-16, -54), Vector2(6, -18), 12), 3.6, CHANVRE, w, m)
	var bec: PackedVector2Array = Transform2D(-0.72, Vector2(14, 6)) * PackedVector2Array([Vector2(0, -7), Vector2(38, -4.5), Vector2(38, 4.5), Vector2(0, 7)])
	_volume(ci, bec, BOIS, w, m, 3.0, 0.28)
	_forme(ci, _ellipse(Vector2(42.5, -19), 2.6, 4.6, -0.72, 12), ECORCE, w * 0.7, m)
	var corps := _lisse(PackedVector2Array([Vector2(-12, -22), Vector2(2, -20), Vector2(19, -6), Vector2(25, 16), Vector2(17, 36), Vector2(-6, 44), Vector2(-28, 38), Vector2(-38, 18),
		Vector2(-34, -4), Vector2(-22, -18)]), 2)
	_volume(ci, corps, CUIR, w, m, 7.0, 0.3)
	# (le col noué, la couture du flanc, un reflet)
	_forme(ci, PackedVector2Array([Vector2(-21, -21), Vector2(-1, -23), Vector2(2, -32), Vector2(-9, -37), Vector2(-22, -32)]), CUIR_SOMBRE, w, m)
	ci.draw_line(Vector2(-22, -22), Vector2(0, -23.5), P.ENCRE * m, w * 1.7, true)
	ci.draw_line(Vector2(-21, -22), Vector2(-1, -23.5), CHANVRE * m, w * 0.8, true)
	var couture := _bezier(Vector2(4, -10), Vector2(18, 14), Vector2(4, 36), 10)
	for i in range(0, couture.size() - 1, 2):
		ci.draw_line(couture[i], couture[i + 1], Color(FOURRURE, 0.85) * m, w * 0.5, true)
	ci.draw_polyline(_bezier(Vector2(-29, 18), Vector2(-31, 2), Vector2(-19, -9), 8), Color(P.PAPIER, 0.55) * m, w * 0.8, true)
	_goutte(ci, Vector2(45, -1), 3.8, w * 0.7, m)
	_goutte(ci, Vector2(39, 16), 3.4, w * 0.7, m)
	_goutte(ci, Vector2(46, 31), 3.0, w * 0.7, m)


# l'épouvantail : une croix de perches sous une bâche, une tête de toile à deux trous, un chapeau de fibres, une écharpe
static func _epouvantail(ci, w: float, m: Color) -> void:
	_cordon(ci, PackedVector2Array([Vector2(0, 46), Vector2(0, 12)]), 5.0, MANCHE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(-38, -3), Vector2(38, -8)]), 4.5, MANCHE, w, m)
	for sx in [-1.0, 1.0]:
		var main := Vector2(float(sx) * 38.0, -3.0 if sx < 0.0 else -8.0)
		for k in 3:
			var bout := main + Vector2.from_angle((PI if sx < 0.0 else 0.0) + (k - 1) * 0.55) * 9.0
			ci.draw_line(main, bout, P.ENCRE * m, w * 1.5, true)
			ci.draw_line(main, bout, CHANVRE * m, w * 0.65, true)
	var bache := PackedVector2Array([Vector2(-33, -9), Vector2(-9, -13), Vector2(9, -14), Vector2(33, -14), Vector2(34, -2), Vector2(13, 1), Vector2(17, 29), Vector2(10, 22), Vector2(5, 32),
		Vector2(0, 23), Vector2(-6, 32), Vector2(-11, 22), Vector2(-17, 30), Vector2(-13, 4), Vector2(-34, 3)])
	_volume(ci, bache, TOILE, w, m, 5.0, 0.28)
	ci.draw_line(Vector2(-14, 12), Vector2(15, 11), P.ENCRE * m, w * 1.6, true)
	ci.draw_line(Vector2(-13, 12), Vector2(14, 11), CHANVRE * m, w * 0.75, true)
	_forme(ci, _rect(-9, -7, -1, 2), CUIR_CLAIR, w * 0.6, m)
	_volume(ci, _ellipse(Vector2(0, -26), 13.0, 13.5, 0.0, 24), TOILE_CLAIRE, w, m, 4.0, 0.28)
	ci.draw_circle(Vector2(-5, -25), 3.0, P.ENCRE * m)
	ci.draw_circle(Vector2(5.5, -25.5), 2.3, P.ENCRE * m)
	_forme(ci, PackedVector2Array([Vector2(-11, -16), Vector2(11, -17), Vector2(12, -10), Vector2(23, 6), Vector2(15, 8), Vector2(4, -9), Vector2(-11, -9)]), ROUILLE, w * 0.8, m)
	_forme(ci, _ellipse(Vector2(0, -36), 23.0, 6.0, -0.1, 24), CHANVRE, w, m)
	_forme(ci, _lisse(PackedVector2Array([Vector2(-12, -36), Vector2(-9, -46), Vector2(1, -49), Vector2(10, -46), Vector2(12, -38), Vector2(0, -35)]), 1), CHANVRE.darkened(0.12), w, m)


# le carré de jardin : une planche de terre entre deux rondins, ses sillons, ses pousses
static func _carre(ci, w: float, m: Color) -> void:
	_volume(ci, _capsule(Vector2(-35, -25), Vector2(37, -29), 5.5), ECORCE, w, m, 2.5, 0.3)
	var terre := PackedVector2Array([Vector2(-38, -21), Vector2(40, -25), Vector2(45, 23), Vector2(-43, 27)])
	_forme(ci, terre, P.TERRE, w, m)
	for k in 2:
		var y := -9.0 + k * 21.0
		ci.draw_line(Vector2(-39.0 - k * 2.0, y + 9.5), Vector2(41.0 + k * 2.0, y + 5.5), Color(P.ENCRE, 0.55) * m, w * 1.0, true)
		ci.draw_line(Vector2(-37.0 - k * 2.0, y - 8.5), Vector2(39.0 + k * 2.0, y - 12.5), Color(P.IVOIRE, 0.2) * m, w * 0.8, true)
		for i in 3:
			var q := Vector2(-25.0 + i * 25.0 + k * 5.0, y - i * 1.3)
			ci.draw_line(q + Vector2(0, 6), q + Vector2(0, -2), P.ENCRE * m, w * 1.4, true)
			_forme(ci, _ellipse(q + Vector2(-6.2, -4.6), 7.0, 4.0, 0.5, 12), VERT, w * 0.7, m)
			_forme(ci, _ellipse(q + Vector2(6.2, -5.4), 7.0, 4.0, -0.5, 12), VERT.lightened(0.14), w * 0.7, m)
	_volume(ci, _capsule(Vector2(-39, 37), Vector2(42, 33), 7.0), ECORCE, w, m, 3.0, 0.3)
	_forme(ci, _ellipse(Vector2(-41, 37), 4.5, 7.0, 0.0, 14), BOIS, w * 0.8, m)


# un sachet de graines : une bourse de toile nouée d'un lien de couleur ; ce qu'on y a mis est peint dessus
static func _sachet(ci, w: float, m: Color, lien: Color) -> void:
	_forme(ci, PackedVector2Array([Vector2(-18, -30), Vector2(-7, -35), Vector2(6, -34), Vector2(18, -29), Vector2(9, -15), Vector2(-9, -15)]), TOILE_CLAIRE, w, m)
	ci.draw_line(Vector2(-6, -31), Vector2(-3, -18), Color(P.ENCRE, 0.45) * m, w * 0.45, true)
	ci.draw_line(Vector2(6, -30), Vector2(3, -18), Color(P.ENCRE, 0.45) * m, w * 0.45, true)
	var corps := _lisse(PackedVector2Array([Vector2(-10, -17), Vector2(10, -17), Vector2(29, 4), Vector2(32, 27), Vector2(19, 42), Vector2(-19, 42), Vector2(-32, 27), Vector2(-29, 4)]), 2)
	_volume(ci, corps, TOILE, w, m, 6.0, 0.28)
	_cordon(ci, _bezier(Vector2(9, -15), Vector2(22, -14), Vector2(21, -2), 6), 2.6, lien, w * 0.8, m)
	ci.draw_line(Vector2(-11, -15.5), Vector2(11, -15.5), P.ENCRE * m, w * 2.1, true)
	ci.draw_line(Vector2(-10, -15.5), Vector2(10, -15.5), lien * m, w * 1.1, true)


# les graines tombées du sachet
static func _semis(ci, w: float, m: Color, c: Color) -> void:
	for q in [Vector2(-40, 43), Vector2(38, 38), Vector2(45, 27), Vector2(-45, 31)]:
		_forme(ci, _ellipse(q, 3.6, 2.6, 0.6, 10), c, w * 0.6, m)


# les graines de baies : le sachet au lien rouille, deux baies peintes
static func _graine_baie(ci, w: float, m: Color) -> void:
	_sachet(ci, w, m, ROUILLE)
	ci.draw_polyline(_bezier(Vector2(-7, 14), Vector2(-4, 4), Vector2(3, 1), 6), P.ENCRE * m, w * 1.3, true)
	ci.draw_polyline(_bezier(Vector2(9, 12), Vector2(8, 5), Vector2(3, 1), 6), P.ENCRE * m, w * 1.3, true)
	for b in [[Vector2(-8, 22), 9.5], [Vector2(10, 19), 8.5]]:
		_forme(ci, _ellipse(b[0], b[1], b[1], 0.0, 16), ROUGE, w * 0.8, m)
		ci.draw_circle(b[0] + Vector2(-b[1] * 0.35, -b[1] * 0.35), b[1] * 0.22, Color(P.PAPIER, 0.85) * m)
	_semis(ci, w, m, ROUGE.darkened(0.35))


# les graines de lin : le sachet au lien bleu, une fleur à cinq pétales
static func _graine_lin(ci, w: float, m: Color) -> void:
	_sachet(ci, w, m, BLEU)
	var c := Vector2(0, 16)
	for k in 5:
		var ang := -PI * 0.5 + k * TAU / 5.0
		_forme(ci, _ellipse(c + Vector2.from_angle(ang) * 8.4, 7.4, 5.4, ang, 12), BLEU, w * 0.6, m)
	ci.draw_circle(c, 4.0, P.ENCRE * m)
	ci.draw_circle(c, 2.7, P.BRAISE_COEUR * m)
	_semis(ci, w, m, Color("b98a4a"))


# les graines de simples : le sachet au lien vert, une ombelle pâle
static func _graine_simple(ci, w: float, m: Color) -> void:
	_sachet(ci, w, m, VERT)
	var pied := Vector2(0, 36)
	var bouquets := [Vector2(-14, 12), Vector2(0, 5), Vector2(14, 12)]
	for q in bouquets:
		ci.draw_line(pied, q, P.ENCRE * m, w * 1.3, true)
		ci.draw_line(pied, q, VERT * m, w * 0.6, true)
	for q in bouquets:
		_forme(ci, _touffe(q, 7.6, 5.0, 0.0, 4), LAIT, w * 0.6, m)
	_semis(ci, w, m, P.IVOIRE)


# les simples : un bouquet d'herbes lié, ses feuilles en éventail, ses ombelles pâles
static func _simples(ci, w: float, m: Color) -> void:
	for k in 4:
		var pied := Vector2(-9.0 + k * 6.5, 47)
		ci.draw_line(Vector2(-4.5 + k * 3.0, 20), pied, P.ENCRE * m, w * 1.7, true)
		ci.draw_line(Vector2(-4.5 + k * 3.0, 20), pied, VERT.darkened(0.15) * m, w * 0.75, true)
	var noeud := Vector2(0, 18)
	var hampes := [Vector2(-22, -28), Vector2(1, -39), Vector2(24, -26)]
	for q in hampes:
		ci.draw_polyline(_bezier(noeud, Vector2(q.x * 0.3, -6), q, 8), P.ENCRE * m, w * 1.5, true)
		ci.draw_polyline(_bezier(noeud, Vector2(q.x * 0.3, -6), q, 8), VERT.darkened(0.1) * m, w * 0.65, true)
	var k2 := 0
	for f in [[-1.05, 37.0], [-0.42, 34.0], [0.45, 35.0], [1.08, 36.0]]:
		var d := Vector2.from_angle(-PI * 0.5 + float(f[0]))
		var bout := noeud + d * float(f[1])
		var cote := Vector2(-d.y, d.x) * 8.5
		var mi := noeud.lerp(bout, 0.55)
		var feuille := _bezier(noeud, mi + cote, bout, 8) + _bezier(bout, mi - cote, noeud, 8).slice(1, 8)
		_forme(ci, feuille, VERT.lightened(0.1) if k2 % 2 == 0 else VERT.darkened(0.08), w * 0.8, m)
		ci.draw_line(noeud.lerp(bout, 0.2), noeud.lerp(bout, 0.85), Color(P.ENCRE, 0.45) * m, w * 0.45, true)
		k2 += 1
	for q in hampes:
		_forme(ci, _touffe(q, 12.5, 7.0, 0.0, 5), LAIT, w * 0.8, m)
		ci.draw_line(q + Vector2(-6, 3), q + Vector2(6, 3), Color(P.NUIT_BLEUE, 0.25) * m, w * 0.6, true)
	_forme(ci, Transform2D(0.06, noeud) * _rect(-9.5, -4.5, 9.5, 5.5), ROUILLE, w * 0.9, m)
	ci.draw_line(noeud + Vector2(-8, 0.5), noeud + Vector2(8, 1.5), Color(P.ENCRE, 0.5) * m, w * 0.5, true)


# l'appât : une poignée de baies, sur une feuille
static func _appat(ci, w: float, m: Color) -> void:
	var feuille := _bezier(Vector2(-47, 24), Vector2(-8, -16), Vector2(47, 8), 14) + _bezier(Vector2(47, 8), Vector2(8, 54), Vector2(-47, 24), 14).slice(1, 14)
	_volume(ci, feuille, VERT, w, m, 5.0, 0.25)
	ci.draw_polyline(_bezier(Vector2(-41, 23), Vector2(0, 17), Vector2(43, 9), 10), Color(P.PAPIER, 0.5) * m, w * 0.6, true)
	for b in [[Vector2(-6, -6), 11.0], [Vector2(15, -7), 10.5], [Vector2(-18, 11), 11.0], [Vector2(5, 14), 11.5], [Vector2(25, 9), 10.0]]:
		_forme(ci, _ellipse(b[0], b[1], b[1], 0.0, 18), ROUGE, w * 0.9, m)
		ci.draw_circle(b[0] + Vector2(b[1] * 0.25, b[1] * 0.3), b[1] * 0.55, Color(P.SANG, 0.45) * m)
		ci.draw_circle(b[0] + Vector2(-b[1] * 0.35, -b[1] * 0.35), b[1] * 0.22, Color(P.PAPIER, 0.85) * m)


# --- l'élevage ---

# le licol : une têtière de corde (la petite boucle autour du museau, la grande derrière les oreilles, deux montants entre
# elles), son anneau sous le menton, sa longe
static func _licol(ci, w: float, m: Color) -> void:
	_cordon(ci, _bezier(Vector2(-26, 37), Vector2(-22, 53), Vector2(2, 45), 10) + _bezier(Vector2(2, 45), Vector2(24, 38), Vector2(41, 46), 8).slice(1), 4.0, CHANVRE, w, m)
	var tetiere := _ellipse(Vector2(22, -14), 12.0, 26.0, 0.3, 26)
	tetiere.append(tetiere[0])
	_cordon(ci, tetiere, 5.0, CHANVRE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(-18, -7.5), Vector2(29, -38)]), 5.0, CHANVRE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(-26, 27.5), Vector2(14.5, 10.5)]), 5.0, CHANVRE, w, m)
	var muserolle := _ellipse(Vector2(-22, 10), 9.5, 18.0, 0.22, 22)
	muserolle.append(muserolle[0])
	_cordon(ci, muserolle, 5.0, CHANVRE, w, m)
	# (les torons de la corde, les nœuds où les brins se tiennent)
	for k in 4:
		var q := Vector2(-18, -7.5).lerp(Vector2(29, -38), 0.2 + k * 0.2)
		ci.draw_line(q + Vector2(-1.0, -2.8), q + Vector2(1.0, 2.8), Color(P.ENCRE, 0.55) * m, w * 0.45, true)
	for q in [Vector2(-18, -7.5), Vector2(29, -38), Vector2(14.5, 10.5)]:
		ci.draw_circle(q, 5.2, P.ENCRE * m)
		ci.draw_circle(q, 3.4, CHANVRE.darkened(0.15) * m)
	ci.draw_arc(Vector2(-26, 31), 6.0, 0.0, TAU, 20, P.ENCRE * m, w * 2.2, true)
	ci.draw_arc(Vector2(-26, 31), 6.0, 0.0, TAU, 20, FER_CLAIR * m, w * 0.9, true)


# le piquet d'attache : un pieu enfoncé au maillet, deux tours de corde, la boucle qui pend
static func _piquet(ci, w: float, m: Color) -> void:
	_forme(ci, _ellipse(Vector2(0, 37), 31.0, 8.0, 0.0, 24), P.TERRE.lightened(0.1), w, m)
	var boucle := _ellipse(Vector2(27, 9), 11.0, 21.0, 0.36, 26)
	boucle.append(boucle[0])
	_cordon(ci, boucle, 4.4, CHANVRE, w, m)
	var pieu := PackedVector2Array([Vector2(-12, -35), Vector2(8, -39), Vector2(11, 37), Vector2(-9, 37)])
	_volume(ci, pieu, BOIS, w, m, 5.0, 0.3)
	_forme(ci, PackedVector2Array([Vector2(-9.7, 14), Vector2(-3, 8), Vector2(3, 17), Vector2(10.2, 11), Vector2(11, 37), Vector2(-9, 37)]), ECORCE, w * 0.8, m)
	ci.draw_line(Vector2(-4, -26), Vector2(-3, -4), Color(P.ENCRE, 0.4) * m, w * 0.45, true)
	ci.draw_line(Vector2(3, -20), Vector2(4, 2), Color(P.ENCRE, 0.4) * m, w * 0.45, true)
	_forme(ci, _ellipse(Vector2(-2, -37), 12.5, 4.6, -0.2, 18), BOIS.lightened(0.12), w, m)
	for y in [-17.0, -8.0]:
		_cordon(ci, PackedVector2Array([Vector2(-13, float(y)), Vector2(12, float(y) - 2.0)]), 4.0, CHANVRE, w, m)


# la mangeoire : une auge de bois sur deux croix de pieux, pleine de foin
static func _mangeoire(ci, w: float, m: Color) -> void:
	for sx in [-1.0, 1.0]:
		var x := float(sx) * 27.0
		_volume(ci, _capsule(Vector2(x - 13.0, 44), Vector2(x + 9.0, 0), 4.4), ECORCE, w, m, 2.5, 0.3)
		_volume(ci, _capsule(Vector2(x + 13.0, 44), Vector2(x - 9.0, 0), 4.4), ECORCE, w, m, 2.5, 0.3)
	for b in [[Vector2(-22, -22), Vector2(-28, -38)], [Vector2(-4, -30), Vector2(-7, -46)], [Vector2(12, -30), Vector2(19, -44)], [Vector2(26, -20), Vector2(37, -31)]]:
		ci.draw_line(b[0], b[1], P.ENCRE * m, w * 1.5, true)
		ci.draw_line(b[0], b[1], CHANVRE * m, w * 0.65, true)
	var foin := _lisse(PackedVector2Array([Vector2(-38, -4), Vector2(-33, -19), Vector2(-14, -31), Vector2(6, -35), Vector2(25, -27), Vector2(38, -6)]), 2)
	_forme(ci, foin, CHANVRE, w, m)
	for b in [[Vector2(-24, -14), Vector2(-12, -24)], [Vector2(-4, -16), Vector2(8, -27)], [Vector2(14, -13), Vector2(24, -20)]]:
		ci.draw_line(b[0], b[1], Color(P.ENCRE, 0.5) * m, w * 0.5, true)
	var auge := PackedVector2Array([Vector2(-45, -8), Vector2(45, -8), Vector2(37, 15), Vector2(-37, 15)])
	_volume(ci, auge, BOIS, w, m, 5.0, 0.28)
	ci.draw_line(Vector2(-39, -3), Vector2(30, -3), Color(P.PAPIER, 0.5) * m, w * 0.6, true)
	ci.draw_line(Vector2(-30, 6), Vector2(12, 6), Color(P.ENCRE, 0.4) * m, w * 0.45, true)
	for sx in [-1.0, 1.0]:
		var c := Vector2(float(sx) * 27.0, 24.5)
		ci.draw_line(c + Vector2(-6, -2.5), c + Vector2(6, 2.5), P.ENCRE * m, w * 1.7, true)
		ci.draw_line(c + Vector2(-5.5, -2.3), c + Vector2(5.5, 2.3), CHANVRE * m, w * 0.8, true)


# les sacoches : deux poches de peau à rabat, tenues par la sangle qui passe sur le dos de la bête
static func _sacoche(ci, w: float, m: Color) -> void:
	_cordon(ci, _bezier(Vector2(-27, 2), Vector2(0, -58), Vector2(27, 2), 14), 9.0, CUIR_SOMBRE, w, m)
	ci.draw_polyline(_bezier(Vector2(-24, -6), Vector2(0, -50), Vector2(24, -6), 12), Color(FOURRURE, 0.6) * m, w * 0.4, true)
	for sx in [-1.0, 1.0]:
		var tr := Transform2D(float(sx) * -0.09, Vector2(float(sx) * 27.0, 17))
		_volume(ci, tr * _arrondi(-18, -22, 18, 27, 8.0), CUIR, w, m, 5.0, 0.3)
		ci.draw_polyline(tr * _bezier(Vector2(-13, 15), Vector2(0, 23), Vector2(13, 15), 8), Color(FOURRURE, 0.7) * m, w * 0.45, true)
		var rabat: PackedVector2Array = tr * _contour([[Vector2(-14, -23)], [Vector2(14, -23)], [Vector2(14, -23), Vector2(19, -22), Vector2(19, -15)], [Vector2(19, -15), Vector2(19, -6), Vector2(0, 7)],
			[Vector2(0, 7), Vector2(-19, -6), Vector2(-19, -15)], [Vector2(-19, -15), Vector2(-19, -22), Vector2(-14, -23)]], 6)
		_forme(ci, rabat, CUIR_SOMBRE, w, m)
		_forme(ci, tr * _rect(-3, -6, 3, 15), CUIR_CLAIR, w * 0.7, m)
		_forme(ci, tr * _rect(-5.5, 3, 5.5, 10), FER_CLAIR, w * 0.7, m)


# la selle : un siège de peau entre son pommeau et son troussequin, sur un tapis ; la sangle, un étrier de corde
static func _selle(ci, w: float, m: Color) -> void:
	_volume(ci, _lisse(PackedVector2Array([Vector2(-41, -9), Vector2(41, -11), Vector2(43, 15), Vector2(-39, 17)]), 1), FOURRURE, w, m, 4.0, 0.25)
	_forme(ci, _rect(-8, 12, 4, 47), CUIR_SOMBRE, w, m)
	_forme(ci, _rect(-10.5, 30, 6.5, 38), FER_CLAIR, w * 0.8, m)
	_cordon(ci, PackedVector2Array([Vector2(22, 8), Vector2(15, 38)]), 3.0, CHANVRE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(25, 8), Vector2(32, 38)]), 3.0, CHANVRE, w, m)
	_forme(ci, _capsule(Vector2(12, 41), Vector2(35, 41), 3.8), BOIS, w * 0.9, m)
	var siege := _contour([[Vector2(-37, -7), Vector2(-42, -30), Vector2(-27, -37)], [Vector2(-27, -37), Vector2(-15, -20), Vector2(4, -20)], [Vector2(4, -20), Vector2(26, -22), Vector2(35, -42)],
		[Vector2(35, -42), Vector2(48, -24), Vector2(39, -3)], [Vector2(39, -3), Vector2(0, 7), Vector2(-37, -7)]], 8)
	_volume(ci, siege, CUIR, w, m, 6.0, 0.3)
	ci.draw_polyline(_bezier(Vector2(-30, -26), Vector2(-18, -13), Vector2(2, -13), 8), Color(P.PAPIER, 0.5) * m, w * 0.7, true)
	var quartier := _lisse(PackedVector2Array([Vector2(-21, -8), Vector2(27, -9), Vector2(31, 13), Vector2(17, 25), Vector2(-13, 25), Vector2(-25, 12)]), 2)
	_volume(ci, quartier, CUIR_SOMBRE, w, m, 4.0, 0.25)
	ci.draw_polyline(_bezier(Vector2(-18, 10), Vector2(2, 22), Vector2(24, 10), 8), Color(FOURRURE, 0.7) * m, w * 0.45, true)


# le lait : un bol de bois plein, une goutte qui y tombe
static func _lait(ci, w: float, m: Color) -> void:
	var bol := _contour([[Vector2(-39, -3)], [Vector2(-39, -3), Vector2(-37, 41), Vector2(0, 41)], [Vector2(0, 41), Vector2(37, 41), Vector2(39, -3)]], 10)
	_volume(ci, bol, BOIS, w, m, 7.0, 0.3)
	ci.draw_polyline(_bezier(Vector2(-29, 10), Vector2(-22, 29), Vector2(-3, 33), 8), Color(P.ENCRE, 0.35) * m, w * 0.45, true)
	ci.draw_polyline(_bezier(Vector2(-18, 8), Vector2(-12, 20), Vector2(2, 23), 8), Color(P.ENCRE, 0.3) * m, w * 0.45, true)
	_forme(ci, _ellipse(Vector2(0, -3), 39.0, 11.5, 0.0, 30), BOIS.lightened(0.14), w, m)
	_forme(ci, _ellipse(Vector2(0, -2), 31.5, 7.6, 0.0, 26), LAIT, w * 0.7, m)
	_ombre(ci, _ellipse(Vector2(0, -2), 31.5, 7.6, 0.0, 26), m, 3.0, 0.16)
	var rond := _ellipse(Vector2(5, -1.5), 10.0, 2.6, 0.0, 16)
	rond.append(rond[0])
	ci.draw_polyline(rond, Color(P.ENCRE, 0.35) * m, w * 0.45, true)
	var goutte := PackedVector2Array([Vector2(5, -44)])
	for i in 15:
		goutte.append(Vector2(5, -26) + Vector2.from_angle(-PI * 0.2 + PI * 1.4 * i / 14.0) * 7.0)
	_forme(ci, goutte, LAIT, w * 0.8, m)


# tes bêtes : une tête de bête, de profil, son licol de corde et sa longe
static func _bete(ci, w: float, m: Color) -> void:
	var cou := _lisse(PackedVector2Array([Vector2(8, 6), Vector2(30, -14), Vector2(46, 10), Vector2(48, 47), Vector2(8, 47), Vector2(2, 24)]), 2)
	_volume(ci, cou, PELAGE.darkened(0.1), w, m, 6.0, 0.3)
	_forme(ci, _lisse(PackedVector2Array([Vector2(22, -26), Vector2(31, -49), Vector2(41, -30), Vector2(35, -19)]), 1), PELAGE.darkened(0.22), w, m)
	var tete := _lisse(PackedVector2Array([Vector2(-45, 10), Vector2(-37, -2), Vector2(-14, -20), Vector2(4, -32), Vector2(24, -30), Vector2(36, -14), Vector2(34, 6), Vector2(20, 20), Vector2(-4, 20),
		Vector2(-26, 27), Vector2(-41, 25)]), 2)
	_volume(ci, tete, PELAGE, w, m, 6.0, 0.3)
	var oreille := _lisse(PackedVector2Array([Vector2(7, -27), Vector2(5, -50), Vector2(22, -39), Vector2(23, -24)]), 1)
	_forme(ci, oreille, PELAGE, w, m)
	ci.draw_colored_polygon(_lisse(PackedVector2Array([Vector2(11, -29), Vector2(9, -43), Vector2(18, -36), Vector2(19, -27)]), 1), Color(CUIR_CLAIR, 0.6) * m)
	ci.draw_circle(Vector2(6, -10), 5.0, P.ENCRE * m)
	ci.draw_circle(Vector2(4.4, -11.6), 1.5, Color(P.PAPIER, 0.9) * m)
	ci.draw_circle(Vector2(-38, 10), 2.3, P.ENCRE * m)
	ci.draw_polyline(_bezier(Vector2(-43, 20), Vector2(-35, 21), Vector2(-29, 18), 6), Color(P.ENCRE, 0.7) * m, w * 0.6, true)
	# (le licol : la muserolle autour du museau, le montant le long de la joue, la têtière derrière l'oreille)
	_cordon(ci, _bezier(Vector2(-23, -13), Vector2(-14, 6), Vector2(-20, 26), 8), 4.2, CHANVRE, w, m)
	_cordon(ci, _bezier(Vector2(-19, 23), Vector2(8, 15), Vector2(28, -8), 10) + _bezier(Vector2(28, -8), Vector2(31, -20), Vector2(23, -27), 6).slice(1), 4.2, CHANVRE, w, m)
	_cordon(ci, _bezier(Vector2(-20, 31), Vector2(-25, 46), Vector2(-8, 48), 8), 3.6, CHANVRE, w, m)
	ci.draw_circle(Vector2(-20, 27), 5.6, P.ENCRE * m)
	ci.draw_circle(Vector2(-20, 27), 3.7, FER_CLAIR * m)
	ci.draw_circle(Vector2(-20, 27), 1.5, P.ENCRE * m)


# --- l'herbier ---

# une feuille posée à plat : de son attache à sa pointe, sa nervure
static func _limbe(ci, a: Vector2, b: Vector2, larg: float, c: Color, w: float, m: Color) -> void:
	var cote := (b - a).orthogonal().normalized() * larg
	var mi := a.lerp(b, 0.45)
	_forme(ci, _bezier(a, mi + cote, b, 7) + _bezier(b, mi - cote, a, 7).slice(1, 7), c, w, m)
	ci.draw_line(a.lerp(b, 0.12), a.lerp(b, 0.84), Color(P.ENCRE, 0.45) * m, w * 0.5, true)


# l'herbier : le cahier de cuir ouvert sur une page, une plante pressée dessus (une clochette de minuit), tenue par deux
# bandes de papier ; le signet qui dépasse
static func _herbier(ci, w: float, m: Color) -> void:
	var tr := Transform2D(-0.1, Vector2(0, 0))
	_forme(ci, tr * PackedVector2Array([Vector2(17, 36), Vector2(27, 36), Vector2(28, 52), Vector2(22.5, 46), Vector2(18, 52)]), ROUILLE, w * 0.9, m)
	_volume(ci, tr * _arrondi(-40, -45, 42, 44, 6), CUIR, w, m, 6.0, 0.3)
	# (la tranche des pages, puis la page)
	_forme(ci, tr * _rect(-31, -40, 38, 40), FOURRURE.darkened(0.14), w * 0.8, m)
	_forme(ci, tr * _rect(-33, -42, 34, 37), LAIT, w, m)
	# (la reliure : sa couture)
	for y in [-30.0, -6.0, 18.0]:
		ci.draw_line(tr * Vector2(-38, y), tr * Vector2(-38, y + 10.0), Color(FOURRURE, 0.9) * m, w * 0.6, true)
	var tige: PackedVector2Array = tr * _bezier(Vector2(-13, 30), Vector2(5, 6), Vector2(-2, -24), 12)
	for f in [[2, -1.0, 16.0], [4, 1.0, 18.0], [7, -1.0, 14.0], [9, 1.0, 12.5]]:
		var q: Vector2 = tige[int(f[0])]
		var cote := float(f[1])
		_limbe(ci, q, q + Vector2(cote * 0.84, -0.54) * float(f[2]), float(f[2]) * 0.3, VERT.lightened(0.24) if cote < 0.0 else VERT.lightened(0.12), w * 0.7, m)
	ci.draw_polyline(tige, P.ENCRE * m, w * 1.5, true)
	ci.draw_polyline(tige, VERT.darkened(0.12) * m, w * 0.65, true)
	# (sa hampe verse, sa clochette pend)
	var tete: Vector2 = tige[12]
	var bout := tete + Vector2(13, 2)
	ci.draw_polyline(_bezier(tete, tete + Vector2(9, -7), bout, 8), P.ENCRE * m, w * 0.9, true)
	var cloche := _lisse(PackedVector2Array([bout + Vector2(-2.5, 0), bout + Vector2(2.5, 0), bout + Vector2(7, 7), bout + Vector2(9.5, 15), bout + Vector2(4, 13), bout + Vector2(0, 16.5),
		bout + Vector2(-4, 13), bout + Vector2(-9.5, 15), bout + Vector2(-7, 7)]), 1)
	_forme(ci, cloche, P.PEUR.lightened(0.12), w * 0.9, m)
	# (les deux bandes qui la tiennent)
	for k in [3, 8]:
		var q: Vector2 = tige[int(k)]
		_forme(ci, Transform2D(0.55, q) * _rect(-7.5, -2.7, 7.5, 2.7), TOILE_CLAIRE, w * 0.7, m)


# le mortier : une pierre creuse, les herbes broyées au fond, le pilon de bois qui y trempe
static func _mortier(ci, w: float, m: Color) -> void:
	_forme(ci, _ellipse(Vector2(0, 37), 19.0, 5.0, 0.0, 20), PIERRE.darkened(0.2), w, m)
	var corps := _contour([[Vector2(-38, -8)], [Vector2(-38, -8), Vector2(-37, 30), Vector2(-16, 37)], [Vector2(16, 37), Vector2(37, 30), Vector2(38, -8)]], 8)
	_volume(ci, corps, PIERRE, w, m, 7.0, 0.32)
	ci.draw_polyline(_bezier(Vector2(-30, 3), Vector2(-28, 20), Vector2(-17, 29), 8), Color(P.PAPIER, 0.5) * m, w * 0.8, true)
	for q in [Vector2(-7, 18), Vector2(7, 27), Vector2(19, 12), Vector2(-19, 11)]:
		ci.draw_circle(q, 1.6, Color(P.ENCRE, 0.32) * m)
	_forme(ci, _ellipse(Vector2(0, -8), 38.0, 11.5, 0.0, 32), PIERRE.lightened(0.16), w, m)
	_forme(ci, _ellipse(Vector2(0, -7), 29.0, 7.6, 0.0, 28), PIERRE.darkened(0.34), w * 0.8, m)
	_forme(ci, _ellipse(Vector2(-6, -4.6), 17.0, 4.3, 0.0, 20), VERT, w * 0.6, m)
	ci.draw_circle(Vector2(-12, -5.2), 1.6, VERT.lightened(0.3) * m)
	ci.draw_circle(Vector2(-2, -3.4), 1.3, VERT.lightened(0.3) * m)
	_volume(ci, _capsule(Vector2(7, -8), Vector2(32, -40), 7.2), BOIS, w, m, 3.5, 0.3)
	_forme(ci, _ellipse(Vector2(34.5, -43), 8.6, 8.6, 0.0, 18), MANCHE, w, m)
	# (deux brins qui ont sauté)
	_limbe(ci, Vector2(-46, 30), Vector2(-33, 41), 3.0, VERT, w * 0.7, m)
	_limbe(ci, Vector2(36, 44), Vector2(46, 34), 2.6, VERT.lightened(0.1), w * 0.7, m)


# le baume : un petit pot de terre, son lien de fibre, l'onguent pâle où un doigt a passé ; la feuille dont il est fait
static func _baume(ci, w: float, m: Color) -> void:
	var corps := _contour([[Vector2(-29, -10)], [Vector2(-29, -10), Vector2(-41, 30), Vector2(-15, 39)], [Vector2(15, 39), Vector2(41, 30), Vector2(29, -10)]], 8)
	_volume(ci, corps, CUIR_CLAIR, w, m, 7.0, 0.3)
	ci.draw_polyline(_bezier(Vector2(-28, 6), Vector2(-30, 22), Vector2(-17, 32), 8), Color(P.PAPIER, 0.5) * m, w * 0.8, true)
	_cordon(ci, _bezier(Vector2(-31, -2), Vector2(0, 9), Vector2(31, -2), 12), 3.4, CHANVRE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(19, 3), Vector2(27, 16)]), 2.6, CHANVRE, w, m)
	_cordon(ci, PackedVector2Array([Vector2(19, 3), Vector2(16, 17)]), 2.6, CHANVRE, w, m)
	_forme(ci, _ellipse(Vector2(0, -12), 30.0, 9.6, 0.0, 30), CUIR, w, m)
	_forme(ci, _ellipse(Vector2(0, -12), 24.0, 6.7, 0.0, 26), VERT.lerp(LAIT, 0.62), w * 0.7, m)
	ci.draw_polyline(_bezier(Vector2(-13, -12), Vector2(-2, -6.5), Vector2(11, -13), 8), Color(VERT.darkened(0.1), 0.75) * m, w * 0.8, true)
	ci.draw_polyline(_bezier(Vector2(-14, -14.5), Vector2(-6, -17.5), Vector2(4, -15.5), 6), Color(P.PAPIER, 0.85) * m, w * 0.6, true)
	_limbe(ci, Vector2(-47, 44), Vector2(-24, 20), 7.0, VERT, w * 0.9, m)
	_limbe(ci, Vector2(-45, 44), Vector2(-14, 40), 5.0, VERT.lightened(0.12), w * 0.9, m)


# la tisane : une tasse de terre claire, son anse, l'infusion dorée où trempe une feuille, sa vapeur
static func _tisane(ci, w: float, m: Color) -> void:
	_vapeur(ci, Vector2(-9, -10), 34.0, w, m)
	_vapeur(ci, Vector2(11, -14), 26.0, w, m)
	_cordon(ci, _bezier(Vector2(30, 6), Vector2(55, 6), Vector2(31, 28), 10), 5.0, LAIT.darkened(0.14), w, m)
	_forme(ci, _arrondi(-14, 33, 14, 41, 2.5), LAIT.darkened(0.2), w, m)
	var bol := PackedVector2Array()
	for i in 19:
		var a := PI * i / 18.0
		bol.append(Vector2(cos(a) * 36.0, 3.0 + sin(a) * 34.0))
	_volume(ci, bol, LAIT.darkened(0.07), w, m, 6.0, 0.28)
	ci.draw_polyline(_bezier(Vector2(-31, 16), Vector2(0, 33), Vector2(31, 16), 12), Color(ROUILLE, 0.85) * m, w * 0.9, true)
	_forme(ci, _ellipse(Vector2(0, 3), 36.0, 9.6, 0.0, 30), LAIT, w, m)
	_forme(ci, _ellipse(Vector2(0, 4), 29.0, 6.5, 0.0, 26), VERT.lerp(BOUILLON, 0.6).lightened(0.14), w * 0.7, m)
	_limbe(ci, Vector2(-15, 5), Vector2(3, 2.5), 3.0, VERT, w * 0.6, m)
	ci.draw_arc(Vector2(4, 5), 22.0, PI * 0.12, PI * 0.4, 8, Color(P.PAPIER, 0.6) * m, w * 0.6, true)


# le philtre : une fiole de verre sombre, bouchée de bois ; dans sa panse, un œil pâle qui s'ouvre
static func _philtre(ci, w: float, m: Color) -> void:
	var verre := P.NUIT_BLEUE.lerp(P.PEUR, 0.22)
	_forme(ci, _rect(-6.5, -48, 6.5, -37), BOIS, w, m)
	_forme(ci, _rect(-8.5, -36, 8.5, -10), verre, w, m)
	_forme(ci, _arrondi(-12.5, -40, 12.5, -33, 3), verre.lightened(0.14), w, m)
	_volume(ci, _ellipse(Vector2(0, 15), 33.0, 30.0, 0.0, 34), verre, w, m, 7.0, 0.36)
	_cordon(ci, PackedVector2Array([Vector2(-9.5, -17), Vector2(9.5, -15)]), 3.0, CHANVRE, w, m)
	ci.draw_polyline(_bezier(Vector2(-27, 8), Vector2(-26, -6), Vector2(-14, -11), 8), Color(P.PAPIER, 0.5) * m, w * 0.8, true)
	# (ses cils de lueur, puis l'œil)
	for a in [-2.25, -1.57, -0.9]:
		var d := Vector2.from_angle(float(a))
		ci.draw_line(Vector2(0, 14) + d * 15.0, Vector2(0, 14) + d * 21.0, Color(P.ECHO, 0.85) * m, w * 0.6, true)
	var oeil := _bezier(Vector2(-24, 16), Vector2(0, -6), Vector2(24, 16), 12) + _bezier(Vector2(24, 16), Vector2(0, 36), Vector2(-24, 16), 12).slice(1, 12)
	_forme(ci, oeil, P.ECHO, w * 0.9, m)
	_forme(ci, _ellipse(Vector2(0, 15.5), 9.2, 9.6, 0.0, 20), P.PEUR, w * 0.8, m)
	ci.draw_circle(Vector2(0, 15.5), 4.3, P.ENCRE * m)
	ci.draw_circle(Vector2(-2.8, 12.4), 1.8, Color(P.PAPIER, 0.95) * m)


# la botte âcre : des tiges sèches liées serré, le bout qui rougeoie, sa fumée ocre
static func _botte(ci, w: float, m: Color) -> void:
	var sec := VERT.lerp(CHANVRE, 0.55)
	var a0 := Vector2(-33, 30)
	var b0 := Vector2(24, -14)
	var dir := (b0 - a0).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	for f in [[b0 + Vector2(-3, -6), 30.0, -1.0], [b0 + Vector2(10, 2), 22.0, 1.0]]:
		var pied: Vector2 = f[0]
		var haut := float(f[1])
		var c := float(f[2])
		var pts := _bezier(pied, pied + Vector2(-9.0 * c, -haut * 0.3), pied + Vector2(0, -haut * 0.55), 8)
		pts.append_array(_bezier(pied + Vector2(0, -haut * 0.55), pied + Vector2(9.0 * c, -haut * 0.8), pied + Vector2(c, -haut), 8).slice(1))
		ci.draw_polyline(pts, Color(P.ENCRE, 0.7) * m, w * 2.3, true)
		ci.draw_polyline(pts, BOUILLON.lerp(CHANVRE, 0.35) * m, w * 1.05, true)
	# (les feuilles sèches, au talon)
	_limbe(ci, a0 + nrm * 6.0, a0 + nrm * 9.0 - dir * 13.0, 3.4, sec.darkened(0.12), w * 0.8, m)
	_limbe(ci, a0 - nrm * 5.0, a0 - nrm * 12.0 - dir * 9.0, 3.2, VERT.lerp(CHANVRE, 0.3), w * 0.8, m)
	for k in 5:
		var e := k - 2.0
		var a := a0 + nrm * e * 6.4 - dir * (2.0 - absf(e)) * 2.5
		var b := b0 + nrm * e * 4.0 + dir * (2.0 - absf(e)) * 3.0
		_cordon(ci, PackedVector2Array([a, b]), 5.0, sec.darkened(0.07 * (k % 2)), w, m)
		ci.draw_circle(b, 3.5, P.ENCRE * m)
		ci.draw_circle(b, 2.5, P.BRAISE * m)
		ci.draw_circle(b, 1.1, P.BRAISE_COEUR * m)
	for s2 in [0.28, 0.62]:
		var c := a0.lerp(b0, float(s2))
		var demi := nrm * lerpf(17.5, 13.0, float(s2))
		_cordon(ci, PackedVector2Array([c - demi, c + demi]), 4.6, ROUILLE, w, m)
		ci.draw_line(c - demi * 0.8 + dir * 1.3, c + demi * 0.8 + dir * 1.3, Color(P.ENCRE, 0.4) * m, w * 0.4, true)


# l'appât empoisonné : un morceau de viande sombre, son os scié, les feuilles écrasées dessus, une mouche
static func _appat_poison(ci, w: float, m: Color) -> void:
	var morceau := _lisse(PackedVector2Array([Vector2(-43, 8), Vector2(-31, -12), Vector2(-6, -20), Vector2(22, -14), Vector2(42, 2), Vector2(40, 22), Vector2(18, 36), Vector2(-14, 36), Vector2(-37, 26)]), 2)
	_volume(ci, morceau, P.SANG.lerp(ROUGE, 0.3), w, m, 7.0, 0.36)
	ci.draw_polyline(_bezier(Vector2(-35, 8), Vector2(-25, -8), Vector2(-5, -13), 8), FOURRURE * m, w * 1.3, true)
	for y in [16.0, 26.0]:
		ci.draw_polyline(_bezier(Vector2(-26, y), Vector2(0, y + 6.0), Vector2(28, y - 2.0), 8), Color(P.ENCRE, 0.35) * m, w * 0.5, true)
	_forme(ci, _ellipse(Vector2(32, 8), 6.6, 8.2, 0.2, 16), LAIT, w * 0.9, m)
	ci.draw_circle(Vector2(32, 8), 2.5, Color(ROUILLE, 0.7) * m)
	# (le jus sombre des feuilles, puis leurs lambeaux)
	ci.draw_colored_polygon(_lisse(PackedVector2Array([Vector2(-26, 2), Vector2(-8, -12), Vector2(16, -8), Vector2(22, 6), Vector2(6, 16), Vector2(-16, 14)]), 2), Color(P.FEUILLE_SOMBRE, 0.7) * m)
	_limbe(ci, Vector2(-25, 3), Vector2(-4, -8), 5.6, VERT.lightened(0.22), w * 0.7, m)
	_limbe(ci, Vector2(-8, 11), Vector2(13, 2), 6.0, VERT.lightened(0.1), w * 0.7, m)
	_limbe(ci, Vector2(2, -9), Vector2(20, -2), 4.6, VERT.lightened(0.3), w * 0.7, m)
	ci.draw_circle(Vector2(-13, 19), 2.6, Color(P.FEUILLE_SOMBRE, 0.9) * m)
	# la mouche
	var mo := Vector2(27, -31)
	_forme(ci, _ellipse(mo + Vector2(-6, -4), 6.4, 3.2, 0.6, 12), LAIT, w * 0.6, m)
	_forme(ci, _ellipse(mo + Vector2(6, -4), 6.4, 3.2, -0.6, 12), LAIT, w * 0.6, m)
	ci.draw_circle(mo, 4.2, P.ENCRE * m)
	for k in 3:
		ci.draw_circle(mo + Vector2(-9.0 - k * 5.0, 6.0 + k * k * 1.6), 1.0, Color(P.ENCRE, 0.5) * m)


# l'appât dormant : des baies sur leur feuille, un brin d'herbe à dormir couché dessus ; la lune dit ce qu'il fait
static func _appat_dormant(ci, w: float, m: Color) -> void:
	var lune := Geometry2D.clip_polygons(_ellipse(Vector2(29, -31), 11.5, 11.5, 0.0, 24), _ellipse(Vector2(35, -35), 10.0, 10.0, 0.0, 24))
	for q in lune:
		_forme(ci, q, Color("d8dcd6").lerp(P.LUNE, 0.3), w * 0.8, m)
	var feuille := _bezier(Vector2(-47, 26), Vector2(-8, -12), Vector2(47, 12), 14) + _bezier(Vector2(47, 12), Vector2(8, 56), Vector2(-47, 26), 14).slice(1, 14)
	_volume(ci, feuille, VERT, w, m, 5.0, 0.25)
	ci.draw_polyline(_bezier(Vector2(-41, 25), Vector2(0, 20), Vector2(43, 13), 10), Color(P.PAPIER, 0.5) * m, w * 0.6, true)
	for b in [[Vector2(-17, 12), 10.5], [Vector2(7, 19), 11.0], [Vector2(26, 13), 9.5]]:
		_forme(ci, _ellipse(b[0], b[1], b[1], 0.0, 18), ROUGE, w * 0.9, m)
		ci.draw_circle(b[0] + Vector2(b[1] * 0.25, b[1] * 0.3), b[1] * 0.55, Color(P.SANG, 0.45) * m)
		ci.draw_circle(b[0] + Vector2(-b[1] * 0.35, -b[1] * 0.35), b[1] * 0.22, Color(P.PAPIER, 0.85) * m)
	# le brin : pâle, ses feuilles par paires, sa fleur
	var pale := VERT.lerp(LAIT, 0.42)
	var brin := _bezier(Vector2(-38, 32), Vector2(-14, -2), Vector2(8, -22), 12)
	for k in [4, 7, 10]:
		var q: Vector2 = brin[int(k)]
		var d := (brin[int(k) + 1] - brin[int(k) - 1]).normalized()
		_limbe(ci, q, q + (d * 0.5 + Vector2(-d.y, d.x)).normalized() * 12.0, 3.4, pale, w * 0.8, m)
		_limbe(ci, q, q + (d * 0.5 - Vector2(-d.y, d.x)).normalized() * 12.0, 3.4, pale.darkened(0.08), w * 0.8, m)
	ci.draw_polyline(brin, P.ENCRE * m, w * 1.5, true)
	ci.draw_polyline(brin, pale.darkened(0.15) * m, w * 0.65, true)
	_forme(ci, _touffe(Vector2(9, -25), 8.0, 6.0, 0.0, 5), LAIT, w * 0.8, m)



# --- la carte et la plume (scripts/reperes.gd) ---

# la carte : une peau grattée, ses deux bords roulés, nouée d'une corde ; un chemin en pointillé, un arbre, et la croix rouge
# de là où l'on veut revenir
static func _carte(ci, w: float, m: Color) -> void:
	var tr := Transform2D(-0.1, Vector2(2, 2))
	var velin := Color("e3d2a8")
	var feuille := PackedVector2Array([Vector2(-30, -36), Vector2(-9, -39), Vector2(12, -35), Vector2(31, -38), Vector2(31, 34), Vector2(11, 38),
		Vector2(-10, 34), Vector2(-30, 37)])
	_volume(ci, tr * feuille, velin, w, m, 5.0, 0.2)
	# (ses deux bords roulés)
	_volume(ci, tr * _capsule(Vector2(-33, -37), Vector2(-33, 37), 7.0), velin.darkened(0.14), w, m, 3.0, 0.3)
	_volume(ci, tr * _capsule(Vector2(34, -39), Vector2(34, 35), 7.0), velin.darkened(0.14), w, m, 3.0, 0.3)
	# (le chemin, à l'encre, en pointillé)
	var chemin: PackedVector2Array = tr * _bezier(Vector2(-20, 26), Vector2(-8, -22), Vector2(17, -15), 14)
	for i in range(0, chemin.size() - 1, 2):
		ci.draw_line(chemin[i], chemin[i + 1], Color(P.ENCRE, 0.9) * m, w * 0.75, true)
	# (un arbre au bord du chemin, un trait d'eau)
	var arbre: Vector2 = tr * Vector2(8, 16)
	ci.draw_line(arbre + Vector2(0, 2), arbre + Vector2(0, 10), Color(P.ENCRE, 0.8) * m, w * 0.6, true)
	_forme(ci, _ellipse(arbre, 7.0, 6.0, 0.0, 14), VERT.lightened(0.15), w * 0.6, m)
	ci.draw_polyline(tr * _bezier(Vector2(-24, -24), Vector2(-14, -30), Vector2(-4, -26), 6), Color(EAU_SOMBRE, 0.9) * m, w * 0.7, true)
	# (la croix, à l'encre rouge)
	var x: Vector2 = tr * Vector2(17, -15)
	ci.draw_line(x + Vector2(-6, -6), x + Vector2(6, 6), ROUILLE * m, w * 1.3, true)
	ci.draw_line(x + Vector2(-6, 6), x + Vector2(6, -6), ROUILLE * m, w * 1.3, true)
	# (la corde nouée autour du rouleau gauche, son bout qui pend)
	_cordon(ci, tr * PackedVector2Array([Vector2(-43, 2), Vector2(-23, 4)]), 3.4, CHANVRE, w * 0.6, m)
	_cordon(ci, tr * _bezier(Vector2(-42, 4), Vector2(-50, 16), Vector2(-45, 28), 6), 2.8, CHANVRE, w * 0.6, m)


# la plume et l'encre : un godet de pierre plein d'encre noire, une plume taillée qui y trempe
static func _plume(ci, w: float, m: Color) -> void:
	var encre := Color("1f1b26")
	_forme(ci, _ellipse(Vector2(-14, 40), 23.0, 5.0, 0.0, 20), PIERRE.darkened(0.3), w, m)
	var godet := _contour([[Vector2(-38, 12)], [Vector2(-38, 12), Vector2(-37, 36), Vector2(-14, 41)], [Vector2(-14, 41), Vector2(9, 36), Vector2(10, 12)]], 8)
	_volume(ci, godet, PIERRE, w, m, 6.0, 0.3)
	_forme(ci, _ellipse(Vector2(-14, 12), 24.0, 7.5, 0.0, 26), PIERRE.lightened(0.14), w, m)
	_forme(ci, _ellipse(Vector2(-14, 13), 18.0, 4.8, 0.0, 22), encre, w * 0.7, m)
	ci.draw_circle(Vector2(-21, 12), 1.8, Color(P.PAPIER, 0.55) * m)
	# (la plume : sa hampe plonge dans l'encre ; ses barbes, plus larges d'un côté)
	var a := Vector2(-10, 12)
	var b := Vector2(38, -46)
	var dir := (b - a).normalized()
	var n := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(a.lerp(b, lerpf(0.3, 1.0, t)) + n * sin(PI * pow(t, 0.75)) * 13.0)
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		pts.append(a.lerp(b, lerpf(0.3, 1.0, t)) - n * sin(PI * pow(t, 0.75)) * 7.0)
	_volume(ci, pts, LAIT, w, m, 4.0, 0.22)
	for k in [0.42, 0.56, 0.7, 0.84]:
		var q: Vector2 = a.lerp(b, k)
		ci.draw_line(q, q + (n * 0.9 - dir * 0.45).normalized() * 9.0, Color(P.ENCRE, 0.45) * m, w * 0.45, true)
	ci.draw_line(a.lerp(b, 0.12), b, P.ENCRE * m, w * 0.9, true)
	# (le bec taillé, noirci d'encre)
	ci.draw_line(a, a.lerp(b, 0.3), encre * m, w * 1.4, true)


# --- la cueillette ---

# une fleur des prés : une silhouette d'encre, cinq pétales posés dessus (sans cerne chacun : l'encre les noierait), un cœur
static func _fleur(ci, c: Vector2, r: float, petale: Color, coeur: Color, w: float, m: Color) -> void:
	var tour := PackedVector2Array()
	for k in 30:
		var a := TAU * k / 30.0
		tour.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.16 * cos(a * 5.0 + PI * 0.5)) * 1.08)
	ci.draw_colored_polygon(tour, P.ENCRE * m)
	for k in 5:
		var a := TAU * k / 5.0 - PI * 0.5
		var pet := _ellipse(c + Vector2(cos(a), sin(a)) * r * 0.5, r * 0.5, r * 0.38, a, 16)
		ci.draw_colored_polygon(pet, (petale.lightened(0.1) if sin(a) < 0.1 else petale.darkened(0.05)) * m)
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.32, c + Vector2(cos(a), sin(a)) * r * 0.78, Color(P.ENCRE, 0.25) * m, w * 0.35, true)
	_forme(ci, _ellipse(c, r * 0.3, r * 0.3, 0.0, 14), coeur, w * 0.45, m)


# les fleurs : un petit bouquet de fleurs des prés, des tiges liées d'un brin de paille
static func _fleurs(ci, w: float, m: Color) -> void:
	var tetes := [[Vector2(-21, -16), 14.0, P.PAPIER.lightened(0.15)], [Vector2(19, -20), 13.0, P.BRAISE_COEUR.lightened(0.05)],
		[Vector2(-1, -34), 14.0, P.PEUR.lerp(P.CREPUSCULE, 0.25).lightened(0.3)], [Vector2(2, 2), 13.0, P.PAPIER.lightened(0.15)]]
	for t in tetes:
		var ligne := _bezier(Vector2(0, 46), Vector2((t[0].x) * 0.4, 20), t[0], 8)
		_cordon(ci, ligne, 3.4, VERT, w * 0.8, m)
	_limbe(ci, Vector2(-3, 28), Vector2(-26, 18), 6.0, VERT.lightened(0.08), w * 0.7, m)
	_limbe(ci, Vector2(3, 31), Vector2(25, 22), 5.5, VERT, w * 0.7, m)
	_cordon(ci, PackedVector2Array([Vector2(-9, 36), Vector2(9, 34)]), 4.5, CHANVRE, w * 0.8, m)
	for t in tetes:
		_fleur(ci, t[0], t[1], t[2], P.BRAISE_COEUR.darkened(0.05) if t[2].v > 0.85 and t[2].s < 0.3 else P.BRAISE.darkened(0.1), w, m)


# un champignon des bois : le cèpe (chapeau brun, pied ventru, un fin réseau) ou l'amanite (rouge, ses verrues blanches, son
# anneau, sa volve)
static func _champignon(ci, w: float, m: Color, amanite: bool) -> void:
	var pale := LAIT.darkened(0.06)
	var pied := PackedVector2Array()
	if amanite:
		pied = _lisse(PackedVector2Array([Vector2(-15, 44), Vector2(-17, 34), Vector2(-9, 26), Vector2(-7, -4), Vector2(7, -4), Vector2(9, 26), Vector2(17, 34), Vector2(15, 44)]), 1)
	else:
		pied = _lisse(PackedVector2Array([Vector2(-14, 44), Vector2(-21, 26), Vector2(-15, 6), Vector2(-9, -4), Vector2(9, -4), Vector2(15, 6), Vector2(21, 26), Vector2(14, 44)]), 2)
	_volume(ci, pied, pale if amanite else pale.lerp(BOIS, 0.35), w, m, 5.0, 0.25)
	if amanite:
		_forme(ci, _lisse(PackedVector2Array([Vector2(-15, 6), Vector2(-9, 0), Vector2(9, 0), Vector2(15, 6), Vector2(9, 11), Vector2(-9, 11)]), 1), LAIT, w * 0.8, m)
	else:
		for k in 3:
			ci.draw_polyline(_bezier(Vector2(-9 + k * 6, 4), Vector2(-7 + k * 6, 14), Vector2(-10 + k * 7, 26), 6), Color(P.ENCRE, 0.3) * m, w * 0.4, true)
	var chapeau := _bezier(Vector2(-42, 2), Vector2(-40, -46), Vector2(0, -46), 12) + _bezier(Vector2(0, -46), Vector2(40, -46), Vector2(42, 2), 12).slice(1)
	chapeau += _bezier(Vector2(42, 2), Vector2(0, 10), Vector2(-42, 2), 12).slice(1, 11)
	var teinte := P.BRAISE_ROUGE.lerp(P.SANG, 0.12) if amanite else P.TERRE.lerp(P.BRAISE, 0.35)
	_volume(ci, chapeau, teinte, w, m, 8.0, 0.3)
	if amanite:
		for q in [Vector2(-22, -18), Vector2(-4, -31), Vector2(15, -22), Vector2(28, -8), Vector2(-30, -3), Vector2(5, -10)]:
			ci.draw_colored_polygon(_ellipse(q, 6.0, 4.6, 0.3, 14), LAIT * m)
			ci.draw_arc(q, 5.4, PI * 0.1, PI * 0.9, 6, Color(P.ENCRE, 0.35) * m, w * 0.3, true)
	else:
		ci.draw_polyline(_bezier(Vector2(-38, 2), Vector2(0, 9), Vector2(38, 2), 10), Color(P.BRAISE_COEUR, 0.7) * m, w * 1.1, true)
	ci.draw_arc(Vector2(-6, -12), 28.0, PI * 1.08, PI * 1.42, 8, Color(P.PAPIER, 0.55) * m, w * 0.8, true)


# l'infusion : un bol de bois fumant, une fleur qui flotte dans le thé doré
static func _infusion(ci, w: float, m: Color) -> void:
	_vapeur(ci, Vector2(-10, -10), 32.0, w, m)
	_vapeur(ci, Vector2(10, -13), 25.0, w, m)
	var bol := PackedVector2Array()
	for i in 19:
		var a := PI * i / 18.0
		bol.append(Vector2(cos(a) * 38.0, 3.0 + sin(a) * 36.0))
	_volume(ci, bol, BOIS, w, m, 6.0, 0.28)
	_forme(ci, _ellipse(Vector2(0, 3), 38.0, 10.0, 0.0, 30), BOIS.lightened(0.12), w, m)
	_forme(ci, _ellipse(Vector2(0, 4), 31.0, 6.8, 0.0, 26), BOUILLON.lerp(P.BRAISE_COEUR, 0.35), w * 0.7, m)
	_fleur(ci, Vector2(6, 3), 7.0, P.PAPIER.lightened(0.15), P.BRAISE_COEUR, w * 0.8, m)
	ci.draw_polyline(_bezier(Vector2(-31, 18), Vector2(0, 34), Vector2(31, 18), 12), Color(P.ENCRE, 0.3) * m, w * 0.5, true)

# --- ce que donnent les pays (scripts/biomes.gd) ---

# l'obsidienne : un éclat de verre noir, à facettes, une arête de lumière bleue, son tranchant clair
static func _obsidienne(ci, w: float, m: Color) -> void:
	var noir := P.ENCRE.lerp(P.NUIT_BLEUE, 0.45)
	var face := P.NUIT_BLEUE.lerp(P.LUNE, 0.4)
	var eclat := PackedVector2Array([Vector2(-38, 30), Vector2(-26, -14), Vector2(4, -44), Vector2(36, -26), Vector2(30, 18), Vector2(-4, 40)])
	_forme(ci, eclat, noir, w, m)
	_forme(ci, PackedVector2Array([Vector2(-26, -14), Vector2(4, -44), Vector2(6, 6), Vector2(-20, 22)]), face, w * 0.7, m)
	_forme(ci, PackedVector2Array([Vector2(6, 6), Vector2(36, -26), Vector2(30, 18)]), noir.lerp(face, 0.35), w * 0.6, m)
	ci.draw_line(Vector2(-22, -10), Vector2(0, -36), Color(P.PAPIER, 0.85) * m, w * 0.9, true)
	ci.draw_line(Vector2(-14, 14), Vector2(2, 2), Color(P.PAPIER, 0.45) * m, w * 0.6, true)


# la tourbe : une motte taillée, brune, fibreuse, sa coupe plus claire, de la mousse dessus
static func _tourbe(ci, w: float, m: Color) -> void:
	var brun := P.TERRE.darkened(0.45)
	var coupe := P.TERRE.darkened(0.2)
	var devant := PackedVector2Array([Vector2(-40, -6), Vector2(22, -6), Vector2(22, 36), Vector2(-40, 36)])
	var dessus := PackedVector2Array([Vector2(-40, -6), Vector2(-20, -30), Vector2(42, -30), Vector2(22, -6)])
	var cote := PackedVector2Array([Vector2(22, -6), Vector2(42, -30), Vector2(42, 12), Vector2(22, 36)])
	_forme(ci, cote, brun, w, m)
	_forme(ci, devant, coupe, w, m)
	_forme(ci, dessus, P.MOUSSE.lerp(brun, 0.35), w, m)
	for y in [4.0, 14.0, 24.0]:
		ci.draw_line(Vector2(-34, y), Vector2(16, y + 2.0), Color(P.FAIM, 0.7) * m, w * 0.6, true)
	for x in [-12.0, 8.0, 28.0]:
		ci.draw_line(Vector2(x, -26), Vector2(x - 6.0, -12), Color(P.FEUILLE_SOMBRE, 0.8) * m, w * 0.6, true)


# la lance d'obsidienne : la hampe et sa ligature, une pointe de verre noir, sa lumière bleue
static func _lance_obsidienne(ci, w: float, m: Color) -> void:
	_forme(ci, _capsule(Vector2(-42, 42), Vector2(10, -10), 6.5), MANCHE * m, w, m)
	ci.draw_line(Vector2(-34, 30), Vector2(2, -6), Color(P.PAPIER, 0.3) * m, w * 0.6, true)
	var lame := PackedVector2Array([Vector2(2, -2), Vector2(12, -32), Vector2(48, -48), Vector2(32, -12)])
	_forme(ci, lame, P.ENCRE.lerp(P.NUIT_BLEUE, 0.45), w, m)
	_forme(ci, PackedVector2Array([Vector2(2, -2), Vector2(12, -32), Vector2(48, -48)]), P.NUIT_BLEUE.lerp(P.LUNE, 0.4), w * 0.6, m)
	ci.draw_line(Vector2(14, -26), Vector2(38, -42), Color(P.PAPIER, 0.85) * m, w * 0.8, true)
	for i in 3:
		var q := Vector2(-2, 2) + Vector2(-1, 1) * (i * 6.0)
		ci.draw_line(q + Vector2(-8, -8), q + Vector2(8, 8), P.ENCRE * m, w * 1.9, true)
		ci.draw_line(q + Vector2(-7, -7), q + Vector2(7, 7), CHANVRE * m, w * 0.9, true)
