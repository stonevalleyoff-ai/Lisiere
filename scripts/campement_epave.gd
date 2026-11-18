extends RefCounted
# Lisière — ce que la Noire a mis en pièces (scripts/campement_epave.gd)
# À son cinquième acte (scripts/noire_faim.gd), la Noire saccage ce que la veilleuse a posé hors de la lumière d'un feu. Ce
# qu'elle a saccagé reste là, en épave, jusqu'à ce qu'on le répare ou le replie (scripts/atelier.gd) : son état porte
# « saccage » (elle est en pièces) et « cote » (de quel côté elle tirait : 1, à droite ; c'est de ce côté que la terre est
# labourée, que les lambeaux ont été traînés, que son empreinte est restée). Pendant qu'elle la secoue, « mordu » (de 0 à 1) :
# la chose tressaute dans sa gueule.
# Ici, le dessin de chaque épave, à la place de celui de la chose (scripts/campement.gd, _peindre) : la même encre, les mêmes
# matières, les mêmes mesures (on reconnaît la tente à sa toile et à sa perche restée debout, le hamac à sa rayure rouille),
# et ce qui dit qui est passé : la toile fendue de trois griffes, le bois cassé net (sa fibre pâle, en esquilles), les piquets
# arrachés, les cordes lâches, la terre labourée, une empreinte large comme un buste. Le fond se dessine une fois ; au vent,
# un lambeau bat encore.
#   Epave.est(c)       cette chose posée est-elle en pièces ?
#   Epave.mordue(c)    la Noire la tient-elle dans sa gueule, à cet instant ?
#   Epave.secousse(c)  de combien elle tressaute (une pose, pour tout son dessin)
#   Epave.remue(c)     quelque chose y bat-il au vent ?
#   Epave.peindre(c, p, quoi)   son dessin (« fond », « vif »), sur le pinceau p
# c : la chose (scripts/campement.gd) ; ses gestes de dessin et ses matières sont les siens (c._perche, c.TOILE…).

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")

const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
const NOIR := Color("14121a")           # ce qu'on voit par une déchirure : le dedans, dans l'ombre
const GENRES := ["tente", "hamac", "recuperateur", "filet", "filet_filin", "epouvantail", "mangeoire", "carre"]


static func est(c) -> bool:
	var v = c.etat.get("saccage", 0.0)
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0 and GENRES.has(str(c.genre))


static func mordue(c) -> bool:
	var v = c.etat.get("mordu", 0.0)
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0


static func _cote(c) -> float:
	return 1.0 if float(c.etat.get("cote", 1.0)) >= 0.0 else -1.0


# ce qu'elle secoue dans sa gueule tressaute : tiré de son côté, par à-coups, et ce qui se tient debout penche vers elle
static func secousse(c) -> Transform2D:
	if not mordue(c):
		return Transform2D.IDENTITY
	var u := clampf(float(c.etat.get("mordu", 0.0)), 0.0, 1.0)
	var cote := _cote(c)
	var t: float = c._tr
	var a := sin(t * 19.0) * (0.55 + 0.45 * sin(t * 5.3 + 1.0))
	var debout: bool = str(c.genre) in ["tente", "epouvantail", "recuperateur", "mangeoire", "hamac"]
	var tire := cote * (1.8 + 3.6 * u) * (0.55 + 0.45 * a)
	return Transform2D((0.05 + 0.07 * u) * (0.4 * cote + a) if debout else 0.0, Vector2(tire, -absf(a) * (1.6 if debout else 0.3)))


# au vent, un lambeau bat encore (la tente, le récupérateur, l'épouvantail)
static func remue(c) -> bool:
	return float(c._vent) > 0.03 and str(c.genre) in ["tente", "recuperateur", "epouvantail", "hamac"]


static func peindre(c, p, quoi: String) -> void:
	var cote := _cote(c)
	match quoi:
		"fond":
			match str(c.genre):
				"tente":
					_tente(c, p, cote)
				"hamac":
					_hamac(c, p, cote)
				"recuperateur":
					_recuperateur(c, p, cote)
				"filet", "filet_filin":
					_filet(c, p, cote)
				"epouvantail":
					_epouvantail(c, p, cote)
				"mangeoire":
					_mangeoire(c, p, cote)
				"carre":
					_carre(c, p, cote)
		"vif":
			match str(c.genre):
				"tente":
					_tente_vif(c, p, cote)
				"hamac":
					_hamac_vif(c, p, cote)
				"recuperateur":
					_recuperateur_vif(c, p, cote)
				"epouvantail":
					_epouvantail_vif(c, p, cote)


# --- les gestes du saccage ---

static func _courbe(a: Vector2, m: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		out.append(a.lerp(m, u).lerp(m.lerp(b, u), u))
	return out


# la terre labourée : un lavis sombre, des mottes retournées
static func _labour(p, r: RandomNumberGenerator, centre: Vector2, rx: float, ry: float, force: float = 1.0) -> void:
	p.eventail(centre, rx, ry, Color(P.TERRE.darkened(0.42), 0.6 * force), Color(P.TERRE.darkened(0.2), 0.0), 16)
	for i in int(6 * force) + 2:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.7, 0.7) * ry)
		var m := r.randf_range(0.9, 1.9)
		p.tracer(PackedVector2Array([q + Vector2(-m, 0.8), q + Vector2(m * 1.1, 0.85)]), 0.8, Color(ENCRE, 0.45), false)
		p.eventail(q, m, m * 0.6, P.TERRE.lightened(r.randf_range(0.04, 0.2)), P.TERRE.lightened(0.05), 6)


# son empreinte, enfoncée dans la terre meuble d'un carré : le coussinet large, quatre doigts, quatre griffes longues. q : son
# milieu ; t : sa demi-largeur (une vraie fait 17 pixels : large comme un buste) ; ang : où pointent les griffes (un angle du
# lieu). Ailleurs, ce sont ses vraies empreintes qu'on voit (scripts/traces.gd) : elles tiennent jusqu'au soir
static func _empreinte(p, q: Vector2, t: float, ang: float, force: float = 1.0) -> void:
	var ax := Vector2.from_angle(ang)
	var tr := ax.orthogonal()
	# (vue de trois quarts : ce qui s'éloigne de nous s'écrase)
	var pt := func(u: float, v: float) -> Vector2:
		var g: Vector2 = (ax * u + tr * v) * t
		return q + Vector2(g.x, g.y * 0.62)
	var creux := Color(P.TERRE.darkened(0.62), 0.9 * minf(1.0, force))
	var fond := Color(P.TERRE.darkened(0.45), 0.85 * minf(1.0, force))
	# le coussinet : un cœur large, échancré derrière
	var tour := PackedVector2Array()
	for z in [[-0.6, 0.0], [-0.74, -0.34], [-0.62, -0.72], [-0.3, -0.92], [0.06, -0.86], [0.26, -0.5], [0.3, 0.0], [0.26, 0.5], [0.06, 0.86], [-0.3, 0.92],
			[-0.62, 0.72], [-0.74, 0.34]]:
		tour.append(pt.call(float(z[0]), float(z[1])))
	p.aplat(tour, creux)
	var dedans := PackedVector2Array()
	for z in tour:
		dedans.append(q + (z - q) * 0.62 + Vector2(0.5, 0.6))
	p.aplat(dedans, fond)
	for i in 4:
		var v: float = [-0.86, -0.3, 0.3, 0.86][i]
		var u: float = 0.72 - 0.26 * absf(v)
		var doigt := PackedVector2Array()
		for k in 9:
			var a := TAU * k / 9.0
			doigt.append(pt.call(u + 0.3 * cos(a), v + 0.23 * sin(a)))
		p.aplat(doigt, creux)
		# (la griffe : une entaille étroite, loin devant le doigt)
		p.tracer(PackedVector2Array([pt.call(u + 0.34, v * 1.03), pt.call(u + 0.7, v * 1.1), pt.call(u + 1.05, v * 1.16)]), 2.0, Color(P.ENCRE, 0.85 * minf(1.0, force)), true,
			PackedFloat32Array([2.4, 1.5, 0.4]))
	# (son bord : plus net du côté d'où vient le jour, là où l'ombre tombe dans le creux)
	p.tracer(PackedVector2Array([tour[10], tour[11], tour[0], tour[1], tour[2], tour[3], tour[4]]), 1.0, Color(P.ENCRE, 0.7 * minf(1.0, force)), true)


# la terre griffée : là où elle s'est arc-boutée pour tirer, trois sillons de ses griffes, de a vers b
static func _sillons(p, a: Vector2, b: Vector2, ecart: float = 2.6) -> void:
	_griffes(p, a, b, ecart, 1.9, Color(P.TERRE.darkened(0.6), 0.9))
	_griffes(p, a + Vector2(0.5, 0.7), b + Vector2(0.5, 0.7), ecart, 0.7, Color(P.TERRE.lightened(0.25), 0.5))


# trois griffes : des entailles parallèles, de a vers b, inégales (celle du milieu la plus longue)
static func _griffes(p, a: Vector2, b: Vector2, ecart: float, w: float, coul: Color, n: int = 3) -> void:
	var d := b - a
	var nrm := d.orthogonal().normalized()
	for i in n:
		var k := float(i) - (n - 1) * 0.5
		var a2 := a + nrm * k * ecart + d * 0.1 * absf(k)
		var b2 := b + nrm * k * ecart * 1.3 - d * 0.14 * absf(k)
		p.tracer(_courbe(a2, a2.lerp(b2, 0.5) + nrm * ecart * 0.3, b2, 6), w, coul, true)


# une déchirure dans une toile : une fente sombre, de a à b, bâillante au milieu ; ses lèvres pâles, ses fils qui pendent
static func _dechirure(p, r: RandomNumberGenerator, a: Vector2, b: Vector2, baille: float, clair: Color) -> void:
	var d := b - a
	var nrm := d.orthogonal().normalized()
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var u := float(i) / n
		var q := a.lerp(b, u) + nrm * r.randf_range(-0.5, 0.5)
		var e := baille * sin(PI * u) * r.randf_range(0.7, 1.15)
		haut.append(q + nrm * e)
		bas.append(q - nrm * e)
	var fente := PackedVector2Array()
	fente.append_array(haut)
	for i in n + 1:
		fente.append(bas[n - i])
	p.aplat(fente, NOIR)
	p.tracer(haut, 0.9, ENCRE, true)
	p.tracer(bas, 1.1, ENCRE, true)
	# (la lèvre qui se retourne, pâle : l'envers de la toile ; deux ou trois fils)
	for i in range(1, n, 2):
		p.tracer(PackedVector2Array([haut[i] + nrm * 0.7, haut[i + 1] + nrm * 0.9]), 0.8, Color(clair, 0.85), true)
	for i in 3:
		var q: Vector2 = bas[1 + (i * 2) % (n - 1)]
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-0.8, 0.8), r.randf_range(1.6, 3.2))]), 0.6, Color(clair.darkened(0.1), 0.9), true)


# le bout d'une perche cassée, en q, tourné vers « vers » : sa fibre à nu, pâle, en esquilles
static func _casse(c, p, r: RandomNumberGenerator, q: Vector2, vers: Vector2, w: float) -> void:
	var tr := vers.orthogonal()
	for i in 4:
		var k := (float(i) - 1.5) / 1.5
		var base := q + tr * k * w * 0.42 - vers * 0.6
		var pointe := base + vers.rotated(k * 0.3) * w * r.randf_range(0.8, 1.9)
		p.tracer(PackedVector2Array([base, pointe]), 1.9, ENCRE, true, PackedFloat32Array([2.0, 0.5]))
		p.tracer(PackedVector2Array([base, base.lerp(pointe, 0.85)]), 1.0, c.BOIS_CLAIR.lightened(0.08), true, PackedFloat32Array([1.1, 0.2]))


# un morceau de perche, tombé : de a à b, son bout cassé du côté de b
static func _troncon(c, p, r: RandomNumberGenerator, a: Vector2, b: Vector2, w: float, bois: Color) -> void:
	c._ombre(p, a.lerp(b, 0.5) + Vector2(0.6, 1.2), a.distance_to(b) * 0.55, 1.8, 0.3)
	c._baton(p, PackedVector2Array([a, b]), w, bois, 1.1)
	p.tracer(PackedVector2Array([a.lerp(b, 0.12) + Vector2(0.0, -w * 0.25), a.lerp(b, 0.8) + Vector2(0.0, -w * 0.25)]), 0.6, Color(bois.lightened(0.3), 0.7), true)
	_casse(c, p, r, b, (b - a).normalized(), w)


# un lambeau de toile, à terre : de a (où il tient encore, large de w) à b (son bout effiloché) ; il fait un pli
static func _lambeau(p, r: RandomNumberGenerator, a: Vector2, b: Vector2, w: float, ton: Color, ombre: Color, clair: Color) -> void:
	var d := b - a
	var nrm := d.orthogonal().normalized()
	if nrm.y > 0.0:
		nrm = -nrm
	var n := 5
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var q := a.lerp(b, u) + nrm * 1.4 * sin(u * 5.0 + r.randf() * 2.0)
		var l := w * lerpf(1.0, 0.55, u) * r.randf_range(0.86, 1.1)
		haut.append(q + nrm * l * 0.5)
		bas.append(q - nrm * l * 0.5)
	var poly := PackedVector2Array()
	poly.append_array(haut)
	# (le bout : des dents inégales, là où la toile a cédé)
	var dents := 3
	for k in dents:
		var u := (k + 0.5) / dents
		poly.append(haut[n].lerp(bas[n], u) + d.normalized() * r.randf_range(1.0, 3.4))
		poly.append(haut[n].lerp(bas[n], (k + 1.0) / dents))
	for i in range(n - 1, -1, -1):
		poly.append(bas[i])
	p.eventail(a.lerp(b, 0.5) + Vector2(0.8, 1.6), d.length() * 0.6, w * 0.5, Color(P.ENCRE, 0.3), Color(P.ENCRE, 0.0), 12)
	p.aplat(poly, ton)
	var dessous := PackedVector2Array()
	for i in n + 1:
		dessous.append(haut[i].lerp(bas[i], 0.56))
	for i in range(n, -1, -1):
		dessous.append(bas[i])
	p.aplat(dessous, ton.lerp(ombre, 0.5))
	p.tracer(PackedVector2Array([haut[1].lerp(bas[1], 0.3), haut[3].lerp(bas[3], 0.42), haut[4].lerp(bas[4], 0.3)]), 0.7, Color(clair, 0.7), true)
	poly.append(poly[0])
	p.tracer(poly, 1.0, ENCRE, false)


# une corde lâche, à terre : elle serpente de a à b
static func _corde_lache(c, p, r: RandomNumberGenerator, a: Vector2, b: Vector2, w: float = 0.8, coul: Color = Color(0, 0, 0, 0)) -> void:
	var d := b - a
	var nrm := d.orthogonal().normalized()
	var ligne := PackedVector2Array()
	var ph := r.randf() * TAU
	for i in 9:
		var u := i / 8.0
		ligne.append(a.lerp(b, u) + nrm * sin(u * 7.5 + ph) * d.length() * 0.09 * sin(PI * u))
	p.tracer(ligne, w + 0.9, ENCRE, false)
	p.tracer(ligne, w, c.CORDE if coul.a <= 0.0 else coul, false)


# des brins épars : de la paille, du foin, sur le sol autour de q
static func _brins(p, r: RandomNumberGenerator, q: Vector2, rx: float, ry: float, n: int, coul: Color) -> void:
	for i in n:
		var o := q + Vector2(r.randf_range(-1.0, 1.0) * rx, r.randf_range(-1.0, 1.0) * ry)
		var d := Vector2.from_angle(r.randf_range(-0.7, 0.7)) * r.randf_range(2.0, 4.2)
		if i % 2 == 0:
			p.tracer(PackedVector2Array([o - d, o + d]), 2.0, Color(ENCRE, 0.55), true)
		p.tracer(PackedVector2Array([o - d, o + d]), 1.1, coul.lightened(0.1).darkened(r.randf_range(0.0, 0.3)), true)


# --- la tente : la perche de l'entrée cassée net, la toile affaissée qui pend encore de la perche du fond, fendue de trois
# griffes ; un pan arraché, traîné du côté où elle tirait ; les piquets sortis de terre, les haubans lâches ---

static func _tente_tons(c) -> Array:
	var mouille: float = c._mouille_cran()
	return [c.TOILE.lerp(c.TOILE_OMBRE.lerp(c.EAU, 0.12), 0.42 * mouille), c.TOILE_CLAIR.lerp(c.TOILE.lerp(c.EAU, 0.08), 0.5 * mouille), c.TOILE_OMBRE.darkened(0.2 * mouille)]


# là où la toile pend encore : le haut de la perche du fond, qui a pris du travers
static func _tente_cime(c, cote: float) -> Vector2:
	return c._tente_pt(0.0, -c.TENTE_L - 0.5, c.TENTE_H - 5.0) + Vector2(cote * 6.0, 2.0)


static func _tente(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(71)
	var tons := _tente_tons(c)
	var ton: Color = tons[0]
	var clair: Color = tons[1]
	var ombre: Color = tons[2]
	var neige: float = c._neige_cran()
	var bois: Color = c.BOIS.darkened(0.15 * c._mouille_cran())
	var W: float = c.TENTE_W
	var L: float = c.TENTE_L
	c._ombre(p, Vector2(3.0, 5.0), 39.0, 13.0, 0.36)
	# la terre labourée du côté où elle tirait, et sa patte
	_labour(p, r, Vector2(cote * 36.0, 10.0), 24.0, 8.0)
	_sillons(p, Vector2(cote * 52.0, 15.5), Vector2(cote * 33.0, 12.0))
	# le tapis de sol, à nu ; le rouleau, qui a roulé dehors
	var fl: Vector2 = c._tente_pt(-W, L, 0.0)
	var fr: Vector2 = c._tente_pt(W, L, 0.0)
	var bl: Vector2 = c._tente_pt(-W, -L, 0.0)
	var br: Vector2 = c._tente_pt(W, -L, 0.0)
	var tapis := PackedVector2Array([fl.lerp(fr, 0.14), fl.lerp(fr, 0.9), br.lerp(bl, 0.16), bl.lerp(br, 0.2)])
	p.aplat(tapis, Color("2a2622"))
	p.tracer(PackedVector2Array([tapis[0], tapis[1]]), 1.0, ENCRE, false)
	var rouleau := fl.lerp(fr, 0.5) + Vector2(-cote * 4.0, 9.5)
	p.disque(rouleau, 5.4, 2.7, ENCRE)
	p.disque(rouleau, 4.5, 2.0, Color("3b3329"))
	p.tracer(PackedVector2Array([rouleau + Vector2(-1.5, -1.6), rouleau + Vector2(-1.2, 1.7)]), 0.8, c.CORDE, false)
	# la perche du fond : restée debout, de travers
	var pied_f: Vector2 = c._tente_pt(0.0, -L - 0.5, 0.0)
	var cime := _tente_cime(c, cote)
	c._perche(p, pied_f, cime + Vector2(cote * 1.6, -8.0), 2.6, 2.2, bois)
	# --- la toile : elle pend de la cime, et s'étale ---
	var faite := _courbe(cime, c._tente_pt(0.0, -4.0, 9.0) + Vector2(cote * 3.0, 0.0), c._tente_pt(0.0, L * 0.6, 1.5), 7)
	var d_bas := PackedVector2Array([br + Vector2(1.0, 0.0), c._tente_pt(W + 4.0, -L * 0.3, 0.0), c._tente_pt(W + 5.0, L * 0.3, 0.0), fr + Vector2(2.0, 1.0)])
	var g_bas := PackedVector2Array([bl + Vector2(-1.0, 0.0), c._tente_pt(-W - 3.0, -L * 0.3, 0.0), c._tente_pt(-W - 4.0, L * 0.4, 0.0), fl + Vector2(-2.0, 1.5)])
	var devant := PackedVector2Array([fl + Vector2(-2.0, 1.5), fl.lerp(fr, 0.3) + Vector2(0.0, 3.6), fl.lerp(fr, 0.62) + Vector2(0.0, 2.2), fr + Vector2(2.0, 1.0)])
	# (le pan de droite, vers nous ; celui de gauche, qui prend le jour)
	var droite := PackedVector2Array()
	droite.append_array(faite)
	for i in range(3, -1, -1):
		droite.append(d_bas[i])
	p.aplat(droite, ton.lerp(ombre, 0.3))
	var gauche := PackedVector2Array()
	gauche.append_array(faite)
	for i in range(3, -1, -1):
		gauche.append(g_bas[i])
	p.aplat(gauche, clair.lerp(ton, 0.35))
	# (ce qui s'est affaissé devant : un tablier de toile, à plat)
	var tablier := PackedVector2Array([faite[5], faite[7]])
	tablier.append(devant[2])
	tablier.append(devant[3])
	tablier.append(d_bas[2])
	p.aplat(tablier, ton.lerp(ombre, 0.55))
	var tablier_g := PackedVector2Array([faite[5], g_bas[2], devant[0], devant[1], faite[7]])
	p.aplat(tablier_g, ton)
	# les plis : ils tombent de la cime, se cassent au sol
	for k in 5:
		var u: float = [0.12, 0.34, 0.58, 0.8, 0.94][k]
		var bas: Vector2 = (d_bas[0] as Vector2).lerp(d_bas[3], u) if k % 2 == 0 else (g_bas[0] as Vector2).lerp(g_bas[3], u)
		var haut: Vector2 = faite[1 + k]
		p.tracer(_courbe(haut, haut.lerp(bas, 0.5) + Vector2(r.randf_range(-2.0, 2.0), 1.5), bas, 5), 0.8, Color(ENCRE, 0.4), true)
	for k in 4:
		var q: Vector2 = (devant[0] as Vector2).lerp(devant[3], 0.15 + 0.22 * k) + Vector2(0.0, -2.5 - r.randf_range(0.0, 3.0))
		p.tracer(PackedVector2Array([q + Vector2(-3.0, 0.4), q + Vector2(0.0, -0.8), q + Vector2(3.2, 0.5)]), 0.7, Color(ENCRE, 0.36), true)
	# la couture des deux lés, qui court encore sur le pan ; sa pièce de cuir
	var couture := PackedVector2Array()
	for i in 8:
		couture.append((faite[i] as Vector2).lerp((d_bas[0] as Vector2).lerp(d_bas[3], i / 7.0), 0.5))
	p.tracer(couture, 0.6, Color(ENCRE, 0.5), false)
	var q_piece: Vector2 = (faite[4] as Vector2).lerp(d_bas[2], 0.72)
	var piece := PackedVector2Array([q_piece + Vector2(-3.0, -2.0), q_piece + Vector2(3.0, -2.4), q_piece + Vector2(3.4, 1.8), q_piece + Vector2(-2.6, 2.2)])
	p.aplat(piece, c.CUIR_CLAIR.lerp(ton, 0.45))
	piece.append(piece[0])
	p.tracer(piece, 0.6, Color(ENCRE, 0.6), false)
	# l'encre : le faîte affaissé, les bords
	p.tracer(faite, 1.2, ENCRE, false)
	p.tracer(d_bas, 1.5, ENCRE, false)
	p.tracer(g_bas, 1.1, ENCRE, false)
	p.tracer(devant, 1.5, ENCRE, false)
	# les trois griffes, en travers du pan : on voit le noir du dedans
	var pan_a: Vector2 = (faite[1] as Vector2).lerp(d_bas[0], 0.22)
	var pan_b: Vector2 = (faite[4] as Vector2).lerp(d_bas[2], 0.5)
	if cote < 0.0:
		pan_a = (faite[1] as Vector2).lerp(g_bas[0], 0.25)
		pan_b = (faite[4] as Vector2).lerp(g_bas[2], 0.52)
	var trav := (pan_b - pan_a).orthogonal().normalized()
	for k in 3:
		var dk := (k - 1.0) * 4.6
		_dechirure(p, r, pan_a + trav * dk + (pan_b - pan_a) * 0.1 * absf(k - 1.0), pan_b + trav * dk * 1.25 - (pan_b - pan_a) * 0.14 * absf(k - 1.0), 1.1 if k == 1 else 0.8, clair)
	# le pan arraché, traîné vers elle
	var prise: Vector2 = (d_bas[2] if cote > 0.0 else g_bas[2]) + Vector2(cote * -3.0, -1.0)
	_lambeau(p, r, prise, prise + Vector2(cote * 27.0, 7.0), 13.0, ton, ombre, clair)
	# la perche de l'entrée : son chicot, et le reste couché
	var pied_e: Vector2 = c._tente_pt(0.0, L + 0.5, 0.0)
	c._ombre(p, pied_e + Vector2(0.8, 0.8), 4.5, 1.8, 0.4)
	c._perche(p, pied_e, pied_e + Vector2(cote * 1.2, -8.5), 2.6, 2.5, bois)
	_casse(c, p, r, pied_e + Vector2(cote * 1.2, -8.5), Vector2(cote * 0.25, -1.0).normalized(), 2.6)
	_troncon(c, p, r, pied_e + Vector2(cote * 30.0, 9.0), pied_e + Vector2(cote * 7.0, 5.0), 2.3, bois)
	# les haubans lâches, les piquets sortis de terre
	var loin: Vector2 = c._tente_pt(0.0, L + 17.0, 0.0)
	_corde_lache(c, p, r, pied_e + Vector2(cote * 29.0, 8.0), loin + Vector2(cote * 6.0, 2.0))
	c._baton(p, PackedVector2Array([loin + Vector2(cote * 6.0, 2.0), loin + Vector2(cote * 11.0, 0.6)]), 1.3, c.BOIS, 0.9)
	for k in 2:
		var pq: Vector2 = c._tente_pt((W + 9.0) * cote, L * (0.7 - 1.2 * k), 0.0) + Vector2(cote * 6.0, 0.0)
		c._baton(p, PackedVector2Array([pq, pq + Vector2(cote * 4.6, -1.2)]), 1.3, c.BOIS, 0.9)
		_corde_lache(c, p, r, pq, pq + Vector2(-cote * 9.0, -2.0 + 3.0 * k), 0.6)
	# (du côté où elle n'était pas, deux piquets tiennent encore)
	for k in 2:
		var pied: Vector2 = c._tente_pt(-(W + 5.5) * cote, L * (1.0 - 1.4 * k), 0.0)
		c._piquet(p, pied + Vector2(0.0, 0.6), Vector2(-cote * 2.0, -3.6))
	if neige > 0.2:
		for k in 4:
			var q: Vector2 = (faite[1 + k] as Vector2).lerp(g_bas[1], 0.3 + 0.1 * k)
			p.disque(q, 4.0 + 3.0 * neige, 1.2 + 1.2 * neige, c.NEIGE, Pinceau.DOME)


# ce qui bat encore au vent : un lambeau noué à la cime de la perche du fond
static func _tente_vif(c, p, cote: float) -> void:
	var tons := _tente_tons(c)
	var vent: float = c._vent
	var cime := _tente_cime(c, cote) + Vector2(cote * 1.4, -6.0)
	var bout := cime
	var ligne := PackedVector2Array([bout])
	for k in 5:
		var ang := lerpf(1.45, 0.25, pow(vent, 0.6)) + 0.55 * sin(c._t * 6.3 - k * 0.9) * vent * (0.4 + 0.13 * k)
		bout += Vector2.from_angle(ang) * 3.0
		ligne.append(bout)
	p.tracer(ligne, 3.6, ENCRE, false, PackedFloat32Array([2.6, 4.2, 4.4, 3.8, 3.0, 1.4]))
	p.tracer(ligne, 2.6, (tons[0] as Color).lerp(tons[2], 0.25), false, PackedFloat32Array([1.6, 3.2, 3.4, 2.8, 2.0, 0.6]))
	c._corde(p, PackedVector2Array([cime + Vector2(-1.6, 0.6), cime + Vector2(1.6, 0.2)]), 0.8)


# --- le hamac : la toile fendue en deux. Une moitié pend le long du tronc (ou de l'autre piquet), l'autre traîne à terre ; le
# piquet fourchu est cassé ---

static func _hamac_tons(c) -> Array:
	var mouille: float = c._mouille_cran()
	return [c.TOILE.lerp(c.TOILE_OMBRE.lerp(c.EAU, 0.12), 0.4 * mouille), c.TOILE_CLAIR.lerp(c.TOILE.lerp(c.EAU, 0.08), 0.5 * mouille), c.TOILE_OMBRE.darkened(0.15 * mouille)]


# où tient encore la moitié qui pend : le nœud au tronc, ou la fourche de l'autre piquet
static func _hamac_noeud(c) -> Vector2:
	if c._arbre != null and is_instance_valid(c._arbre):
		var loin: float = c._tronc.length() / maxf(c._court, 0.2)
		var haut := clampf(c.HAMAC_Z + 1.0 + (loin - c.HAMAC_L - 4.5) * 0.28, c.HAMAC_Z + 1.0, 27.0)
		return c._tronc + Vector2(0.0, -haut)
	return c._hamac_pt(c.HAMAC_L + 16.5, 0.0, 25.0) + Vector2(0.0, 3.0)


static func _hamac(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(72)
	var tons := _hamac_tons(c)
	var ton: Color = tons[0]
	var clair: Color = tons[1]
	var ombre: Color = tons[2]
	var L: float = c.HAMAC_L
	var dir: Vector2 = (c._axe * c._court).normalized()
	var rouille: Color = P.ECHARPE.lerp(ton, 0.35)
	c._ombre_axe(p, Vector2(-dir.x * 8.0, 3.0), dir, L * c._court * 0.9, 5.0, 0.26)
	_labour(p, r, Vector2(cote * 20.0, 8.0), 19.0, 6.5)
	_sillons(p, Vector2(cote * 34.0, 12.0), Vector2(cote * 17.0, 9.0))
	# le piquet fourchu : cassé au pied ; sa fourche couchée, son hauban lâche
	var pied: Vector2 = c._hamac_pt(-(L + 14.0), 0.0, 0.0)
	var ancre: Vector2 = c._hamac_pt(-(L + 29.0), 0.0, 0.0)
	c._ombre(p, pied + Vector2(0.5, 0.8), 5.0, 2.0, 0.4)
	c._perche(p, pied + Vector2(0.0, 1.0), pied + Vector2(-dir.x * 1.0, -6.5), 3.4, 3.2, c.ECORCE.lightened(0.05))
	_casse(c, p, r, pied + Vector2(-dir.x * 1.0, -6.5), Vector2(0.15, -1.0).normalized(), 3.2)
	var tombe: Vector2 = pied + dir * 7.0 + Vector2(0.0, 5.0)
	var tete: Vector2 = tombe + dir * 17.0 + Vector2(0.0, 2.0)
	_troncon(c, p, r, tete, tombe, 2.8, c.ECORCE.lightened(0.05))
	c._baton(p, PackedVector2Array([tete, tete + dir * 3.0 + Vector2(0.0, -2.2)]), 1.4, c.ECORCE.lightened(0.08), 0.9)
	c._baton(p, PackedVector2Array([tete, tete + dir * 3.2 + Vector2(0.0, 1.8)]), 1.4, c.ECORCE.lightened(0.08), 0.9)
	_corde_lache(c, p, r, ancre, tete + Vector2(0.0, -0.5), 0.6)
	c._piquet(p, ancre + Vector2(0.0, 0.8), Vector2(-dir.x * 2.2, -3.0))
	# la moitié qui traîne à terre : chiffonnée, sa rayure rouille, son bord effiloché ; ses cordes vont encore à la fourche
	var a: Vector2 = tete + dir * 4.0 + Vector2(0.0, 1.0)
	var b: Vector2 = a + dir * 20.0 + Vector2(0.0, 3.5)
	for k in 3:
		p.tracer(PackedVector2Array([tete + Vector2(0.0, 0.6), a + Vector2(0.0, (k - 1) * 3.0)]), 0.8, Color(ENCRE, 0.85), false)
	_lambeau(p, r, a, b, 12.0, ton, ombre, clair)
	p.tracer(PackedVector2Array([a + Vector2(0.0, -2.2), a.lerp(b, 0.5) + Vector2(0.0, -1.4), b + Vector2(-dir.x * 2.0, -1.8)]), 1.1, Color(rouille, 0.9), false)
	# au tronc : la corde y fait toujours ses deux tours (c'est campement.gd qui la noue ; ici, elle ne tire plus sur rien)
	var noeud := _hamac_noeud(c)
	if c._arbre != null and is_instance_valid(c._arbre):
		for k in 2:
			c._corde(p, PackedVector2Array([noeud + Vector2(-4.6, -0.9 + k * 1.9), noeud + Vector2(0.0, -0.2 + k * 1.9), noeud + Vector2(4.6, -0.9 + k * 1.9)]), 0.9)
	else:
		c._hamac_piquet(p, 1.0)


# la moitié qui pend : du nœud, la corde, l'anneau, puis la toile jusqu'à terre, où elle s'étale ; elle bat un peu au vent
static func _hamac_vif(c, p, _cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(73)
	var tons := _hamac_tons(c)
	var ton: Color = tons[0]
	var clair: Color = tons[1]
	var ombre: Color = tons[2]
	var noeud := _hamac_noeud(c)
	var dir: Vector2 = (c._axe * c._court).normalized()
	var vent: float = c._vent
	var bal := sin(c._t * 2.1 + c._graine) * 2.2 * vent
	# (elle pend du côté du hamac, un peu en avant du tronc)
	var sol_y: float = c._hamac_pt(c.HAMAC_L, 0.0, 0.0).y + 1.0
	if c._arbre != null and is_instance_valid(c._arbre):
		sol_y = c._tronc.y + 2.0
	var anneau := noeud + Vector2(-dir.x * 5.0 + bal * 0.3, 6.0)
	c._hauban(p, PackedVector2Array([noeud, anneau]), 1.0)
	var bas := Vector2(anneau.x - dir.x * 2.0 + bal, sol_y)
	var traine := bas + Vector2(-dir.x * 12.0, 2.5)
	# la toile : étroite sous l'anneau, plus large en bas, puis couchée au sol
	var g := PackedVector2Array([anneau + Vector2(-1.0, 1.0), anneau.lerp(bas, 0.5) + Vector2(-4.0 + bal * 0.6, 0.0), bas + Vector2(-5.5, 0.0)])
	var d := PackedVector2Array([anneau + Vector2(1.0, 1.0), anneau.lerp(bas, 0.5) + Vector2(4.0 + bal * 0.6, 0.0), bas + Vector2(5.5, 0.0)])
	var pend := PackedVector2Array()
	pend.append_array(g)
	pend.append(d[2])
	pend.append(d[1])
	pend.append(d[0])
	p.aplat(pend, ton)
	p.aplat(PackedVector2Array([anneau, anneau.lerp(bas, 0.5) + Vector2(bal * 0.6, 0.0), bas, d[2], d[1], d[0]]), ton.lerp(ombre, 0.45))
	p.tracer(PackedVector2Array([g[0], g[1].lerp(d[1], 0.3), g[2].lerp(d[2], 0.3)]), 1.1, Color(P.ECHARPE.lerp(ton, 0.35), 0.9), false)
	p.tracer(g, 0.9, ENCRE, false)
	p.tracer(d, 1.3, ENCRE, false)
	p.disque(anneau, 1.5, 1.4, ENCRE)
	p.disque(anneau, 0.7, 0.65, c.CORDE)
	_lambeau(p, r, bas + Vector2(0.0, 0.5), traine, 11.0, ton, ombre, clair)


# --- le récupérateur : la bâche arrachée de ses pieux (un seul tient encore, un lambeau noué à sa tête), jetée en tas, fendue ;
# les pierres du creux éparpillées, son eau bue par la terre ---

static func _recuperateur(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(74)
	var mouille: float = c._mouille_cran()
	var ton: Color = c.TOILE.lerp(c.TOILE_OMBRE.lerp(c.EAU, 0.12), 0.42 * mouille)
	var clair: Color = c.TOILE_CLAIR.lerp(c.TOILE.lerp(c.EAU, 0.08), 0.5 * mouille)
	var ombre: Color = c.TOILE_OMBRE.darkened(0.2 * mouille)
	var pierre: Color = c._pierre_du_lieu()
	var ecorce: Color = c.ECORCE
	c._ombre(p, Vector2(1.0, 6.0), 24.0, 9.0, 0.3)
	# la terre qui a bu l'eau du creux : une tache sombre, qui s'étale vers le bas
	p.eventail(Vector2(-cote * 2.0, 11.0), 21.0, 8.0, Color(P.TERRE.darkened(0.55), 0.6), Color(P.TERRE.darkened(0.4), 0.0), 16)
	_labour(p, r, Vector2(cote * 26.0, 8.0), 18.0, 6.5)
	_sillons(p, Vector2(cote * 41.0, 13.0), Vector2(cote * 24.0, 10.0))
	# le pieu du fond qui tient encore (du côté où elle n'était pas) ; l'autre, cassé au ras du sol
	c._perche(p, c._pr(-cote * 11.0, -10.0, 0.0), c._pr(-cote * 12.4, -10.0, 28.0), 2.8, 2.4, ecorce.darkened(0.3))
	var chicot: Vector2 = c._pr(cote * 11.0, -10.0, 0.0)
	c._perche(p, chicot, chicot + Vector2(cote * 0.8, -6.0), 2.8, 2.7, ecorce.darkened(0.3))
	_casse(c, p, r, chicot + Vector2(cote * 0.8, -6.0), Vector2(cote * 0.2, -1.0).normalized(), 2.7)
	_troncon(c, p, r, chicot + Vector2(cote * 26.0, 1.0), chicot + Vector2(cote * 7.0, 3.0), 2.4, ecorce.darkened(0.2))
	# le creux : sa toile fendue, à sec ; trois pierres encore en place, les autres roulées
	var b := Vector2(0.0, 7.5)
	var bord := Pinceau.ellipse(b, 12.6, 5.3, 22)
	p.aplat(bord, c.TOILE.darkened(0.12 + 0.14 * mouille))
	p.contour(bord, 1.2, ENCRE, r, 3)
	p.disque(b + Vector2(0.0, 0.5), 10.9, 4.3, Color("2b2823"))
	p.disque(Vector2(0.0, 9.6), 6.6, 2.4, Color("3f382f"))
	_dechirure(p, r, b + Vector2(-cote * 7.0, -1.5), b + Vector2(cote * 8.0, 2.6), 1.3, clair)
	for i in 3:
		var a := lerpf(-2.85, -0.3, [0.0, 0.45, 1.0][i]) if cote < 0.0 else lerpf(-2.85, -0.3, [0.0, 0.3, 0.62][i])
		c._caillou(p, b + Vector2(cos(a) * 13.6, sin(a) * 5.6 - 1.6), r.randf_range(3.0, 4.0), r.randf_range(2.3, 2.9), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
	for i in 4:
		var q := b + Vector2(cote * r.randf_range(15.0, 31.0), r.randf_range(-5.0, 9.0))
		var rr := r.randf_range(2.8, 3.9)
		c._ombre(p, q + Vector2(0.5, rr * 0.4), rr * 1.2, rr * 0.45, 0.3)
		c._caillou(p, q + Vector2(0.0, -rr * 0.3), rr, rr * 0.74, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
	c._caillou(p, b + Vector2(-cote * 12.0, 3.4), 3.6, 2.7, pierre.lerp(P.IVOIRE, 0.1), r)
	# la bâche, en tas, jetée de son côté ; trois griffes dedans
	var tas := Vector2(cote * 12.0, -3.0)
	var contour := PackedVector2Array()
	for i in 11:
		var a := TAU * i / 11.0
		contour.append(tas + Vector2(cos(a) * 15.0, sin(a) * 6.4 - 2.6 * maxf(0.0, -sin(a))) * r.randf_range(0.82, 1.12))
	p.eventail(tas + Vector2(1.0, 2.5), 18.0, 7.0, Color(P.ENCRE, 0.34), Color(P.ENCRE, 0.0), 14)
	p.aplat(contour, ton)
	var haut_tas := PackedVector2Array()
	for i in range(6, 11):
		haut_tas.append(contour[i])
	haut_tas.append(tas + Vector2(8.0, -1.0))
	haut_tas.append(tas + Vector2(-7.0, 0.5))
	p.aplat(haut_tas, clair.lerp(ton, 0.3))
	var bas_tas := PackedVector2Array()
	for i in range(0, 6):
		bas_tas.append(contour[i])
	bas_tas.append(tas + Vector2(-7.0, 1.6))
	bas_tas.append(tas + Vector2(8.0, 0.4))
	p.aplat(bas_tas, ton.lerp(ombre, 0.5))
	for k in 4:
		var q := tas + Vector2(-9.0 + 6.0 * k, r.randf_range(-3.0, 2.5))
		p.tracer(PackedVector2Array([q + Vector2(-2.6, 1.2), q + Vector2(0.4, -1.4), q + Vector2(3.0, 0.9)]), 0.7, Color(ENCRE, 0.42), true)
	p.contour(contour, 1.2, ENCRE, r, 3)
	for k in 3:
		_dechirure(p, r, tas + Vector2(-8.0 + 2.0 * k, -5.0 + 2.6 * k), tas + Vector2(7.0 + 2.0 * k, -2.6 + 2.6 * k), 0.8 + 0.3 * (k % 2), clair)
	# les deux pieux de devant : l'un penche, l'autre est couché ; leurs cordes pendent
	var pg: Vector2 = c._pr(-cote * 16.5, 2.0, -0.5)
	c._perche(p, pg, pg + Vector2(-cote * 5.0, -15.0), 3.2, 2.7, ecorce.lightened(0.06))
	c._corde(p, PackedVector2Array([pg + Vector2(-cote * 4.6 - 2.0, -12.2), pg + Vector2(-cote * 4.6 + 2.0, -11.6)]), 0.9)
	p.tracer(_courbe(pg + Vector2(-cote * 4.4, -11.6), pg + Vector2(-cote * 2.0, -6.0), pg + Vector2(-cote * 3.2, -2.0), 5), 0.8, c.CORDE.darkened(0.1), true)
	_troncon(c, p, r, c._pr(cote * 34.0, 9.0, 0.0), c._pr(cote * 18.0, 5.0, 0.0), 2.8, ecorce.lightened(0.06))
	if c._neige_cran() > 0.2:
		p.disque(tas + Vector2(0.0, -3.0), 9.0, 2.6, c.NEIGE, Pinceau.DOME)


# le lambeau resté noué à la tête du pieu debout
static func _recuperateur_vif(c, p, cote: float) -> void:
	var mouille: float = c._mouille
	var clair: Color = c.TOILE_CLAIR.lerp(c.TOILE.lerp(c.EAU, 0.08), 0.5 * mouille)
	var vent: float = c._vent
	var tete: Vector2 = c._pr(-cote * 12.4, -10.0, 26.0)
	var bout := tete
	var ligne := PackedVector2Array([bout])
	for k in 5:
		var ang := lerpf(1.5, 0.3, pow(vent, 0.6)) + 0.5 * sin(c._t * 5.9 - k * 0.95) * vent * (0.4 + 0.12 * k)
		bout += Vector2.from_angle(ang) * 2.8
		ligne.append(bout)
	p.tracer(ligne, 3.4, ENCRE, false, PackedFloat32Array([2.4, 4.0, 4.2, 3.6, 2.8, 1.2]))
	p.tracer(ligne, 2.4, clair.lerp(c.TOILE_OMBRE, 0.35), false, PackedFloat32Array([1.4, 3.0, 3.2, 2.6, 1.8, 0.5]))
	c._corde(p, PackedVector2Array([tete + Vector2(-1.8, -0.3), tete + Vector2(1.8, 0.3)]), 0.9)


# --- le filet : la maille crevée (un grand trou, ses fils qui pendent dedans), la ralingue rompue de son côté, les pierres
# de lest roulées ; s'il tenait une prise, il n'en reste qu'une tache et un os ---

static func _filet(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(75)
	var grand: bool = str(c.genre) == "filet_filin"
	var k_g := 1.32 if grand else 1.0
	var pierre: Color = c._pierre_du_lieu()
	var fibre: Color = (c.FILIN if grand else c.CORDE).darkened(0.1 + 0.15 * c._mouille_cran())
	var coins := [Vector2(-24.0, -7.5) * k_g, Vector2(23.0, -9.0) * k_g, Vector2(27.0, 7.0) * k_g, Vector2(-22.0, 9.0) * k_g]
	c._ombre(p, Vector2(1.0, 1.0), 31.0 * k_g, 10.5 * k_g, 0.2)
	_labour(p, r, Vector2(cote * 22.0 * k_g, 4.0), 21.0 * k_g, 7.5 * k_g)
	_sillons(p, Vector2(cote * 44.0 * k_g, 11.0), Vector2(cote * 27.0 * k_g, 9.0))
	# le trou : là où elle a mis la gueule, du côté où elle se tenait
	var trou := Vector2(cote * 5.0, 0.0) * k_g
	var rt := Vector2(13.5, 6.2) * k_g
	if bool(c.etat.get("mangee", false)):
		# (ce qui s'y était pris : une tache, une touffe de poil, un os rongé)
		p.eventail(trou, rt.x * 0.8, rt.y * 0.8, Color(P.SANG.darkened(0.35), 0.75), Color(P.SANG.darkened(0.4), 0.0), 12)
		c._baton(p, PackedVector2Array([trou + Vector2(-3.0, 1.0), trou + Vector2(3.4, -0.6)]), 1.2, P.IVOIRE.lightened(0.15), 0.9)
		p.disque(trou + Vector2(3.8, -0.7), 1.2, 1.0, P.IVOIRE.lightened(0.2))
		for i in 5:
			var q := trou + Vector2(r.randf_range(-6.0, 6.0), r.randf_range(-2.5, 2.5))
			p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-1.6, 1.6), -r.randf_range(1.0, 2.2))]), 0.8, Color("6a5741"), true)
	else:
		# (l'appât : écrasé)
		for i in 3:
			var q := trou + Vector2.from_angle(i * 2.1 + 0.4) * 2.6
			p.eventail(q, 2.0, 1.1, Color(c.BAIE.darkened(0.2), 0.85), Color(c.BAIE, 0.0), 7)
	# la maille : la même nappe, chiffonnée, repoussée à l'opposé d'elle ; ses fils s'arrêtent au bord du trou
	var n := 6 if grand else 7
	var pt := func(a: float, b: float) -> Vector2:
		var q: Vector2 = (coins[0] as Vector2).lerp(coins[1], a).lerp((coins[3] as Vector2).lerp(coins[2], a), b)
		q += Vector2(2.4 * sin(PI * b) * (pow(1.0 - a, 4.0) - pow(a, 4.0)), 2.0 * absf(sin(TAU * a)) * (pow(1.0 - b, 4.0) - pow(b, 4.0)))
		# (elle a tiré : la nappe a suivi, puis s'est tassée en plis)
		var pres := exp(-((q - trou) / (rt * 2.2)).length_squared())
		q += Vector2(cote * 3.4 * pres, 0.0) + Vector2(sin(a * 13.0 + b * 7.0), cos(a * 9.0 - b * 11.0)) * 1.5 * (0.3 + pres)
		return q + Vector2(0.0, -1.2 * sin(PI * a) * sin(PI * b) - 1.4 * pres)
	var dans := func(q: Vector2) -> bool:
		return ((q - trou) / rt).length_squared() < 1.0
	var noeuds: Array = []
	for j in n + 1:
		var rang := PackedVector2Array()
		for i in n + 1:
			rang.append(pt.call(float(i) / n, float(j) / n))
		noeuds.append(rang)
	for j in n:
		for i in n:
			for pas in [[1, 1], [1, -1]]:
				var i2: int = i + 1
				var j0: int = j if int(pas[1]) > 0 else j + 1
				var j2: int = j0 + int(pas[1])
				var a: Vector2 = noeuds[j0][i]
				var b: Vector2 = noeuds[j2][i2]
				var da: bool = dans.call(a)
				var db: bool = dans.call(b)
				if da and db:
					continue
				if da or db:
					# (un fil rompu : il pend dans le trou, effiloché)
					var tient: Vector2 = b if da else a
					var bout: Vector2 = tient.lerp(a if da else b, r.randf_range(0.3, 0.6)) + Vector2(r.randf_range(-1.0, 1.0), r.randf_range(0.4, 1.8))
					if grand:
						p.tracer(PackedVector2Array([tient, bout]), 1.9, ENCRE, true)
					p.tracer(PackedVector2Array([tient, bout]), 1.15 if grand else 0.8, fibre.lightened(0.1), true)
					continue
				if grand:
					p.tracer(PackedVector2Array([a, b]), 1.9, ENCRE, false)
					p.tracer(PackedVector2Array([a, b]), 1.15, fibre, false)
				else:
					p.tracer(PackedVector2Array([a, b]), 0.8, fibre, false)
	if grand:
		for j in range(1, n):
			for i in range(1, n):
				var q: Vector2 = noeuds[j][i]
				if not dans.call(q):
					p.disque(q, 1.25, 1.0, ENCRE)
					p.disque(q + Vector2(-0.2, -0.2), 0.75, 0.6, fibre.lightened(0.12))
	# la ralingue : rompue du côté où elle tirait ; ses deux bouts traînent dehors
	var tour_ := PackedVector2Array()
	for i in n + 1:
		tour_.append(noeuds[0][i])
	for j in range(1, n + 1):
		tour_.append(noeuds[j][n])
	for i in range(n - 1, -1, -1):
		tour_.append(noeuds[n][i])
	for j in range(n - 1, 0, -1):
		tour_.append(noeuds[j][0])
	# (on l'ouvre au milieu du bord de son côté : le bord de droite est fait des points n à 2n, celui de gauche des derniers)
	var coupe := n + n / 2 if cote > 0.0 else 3 * n + n / 2
	var boucle := PackedVector2Array()
	for i in tour_.size():
		boucle.append(tour_[(coupe + 1 + i) % tour_.size()])
	var bout_a: Vector2 = boucle[0] + Vector2(cote * 6.0, -2.4)
	var bout_b: Vector2 = boucle[boucle.size() - 1] + Vector2(cote * 7.0, 3.0)
	boucle.insert(0, bout_a)
	boucle.append(bout_b)
	c._corde(p, boucle, 1.8 if grand else 1.1, fibre.lightened(0.08))
	for q in [bout_a, bout_b]:
		for i in 3:
			p.tracer(PackedVector2Array([q, q + Vector2(cote * r.randf_range(1.2, 2.8), r.randf_range(-1.4, 1.4))]), 0.6, fibre.lightened(0.15), true)
	# les pierres de lest : celles de son côté ont roulé
	var poids := [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.52, 0.0], [0.45, 1.0]]
	if grand:
		poids.append_array([[0.0, 0.5], [1.0, 0.48]])
	for i in poids.size():
		var q: Vector2 = pt.call(float(poids[i][0]), float(poids[i][1]))
		var de_son_cote := (float(poids[i][0]) > 0.6) == (cote > 0.0) and absf(float(poids[i][0]) - 0.5) > 0.2
		if de_son_cote:
			q += Vector2(cote * r.randf_range(7.0, 15.0), r.randf_range(-3.0, 4.0))
		var rr := r.randf_range(3.6, 5.0) * (1.35 if grand else 1.0)
		c._ombre(p, q + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.35)
		c._caillou(p, q + Vector2(0.0, -rr * 0.35), rr, rr * 0.72, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.2)), r)
		if c._neige_cran() > 0.25:
			p.disque(q + Vector2(-0.3, -rr * 0.9), rr * 0.7, rr * 0.3, c.NEIGE, Pinceau.DOME)


# --- l'épouvantail : sa perche cassée au-dessus du pied ; le reste couché de son côté, la bâche lacérée, la paille répandue,
# la tête de toile crevée, le chapeau plus loin ; l'écharpe traîne ---

static func _epouvantail(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(76)
	var mouille: float = c._mouille_cran()
	var toile: Color = c.TOILE.darkened(0.26 * mouille)
	var clair: Color = c.TOILE_CLAIR.darkened(0.24 * mouille)
	var paille: Color = c.CORDE.lightened(0.14).darkened(0.22 * mouille)
	var bois: Color = c.BOIS.darkened(0.2 * mouille)
	_labour(p, r, Vector2(cote * 18.0, 6.0), 19.0, 6.5)
	_sillons(p, Vector2(cote * 30.0, 12.0), Vector2(cote * 12.0, 9.5))
	# son pied : la perche plantée, ses pierres (le même que debout) ; cassée net au-dessus
	c._epouvantail(p)
	_casse(c, p, r, Vector2(0.3, -15.0), Vector2(cote * 0.3, -1.0).normalized(), 2.9)
	# la paille, partout
	_brins(p, r, Vector2(cote * 17.0, 3.0), 17.0, 5.0, 26, paille)
	# le haut de la perche, couché ; la traverse en travers, un bout en l'air
	var a := Vector2(cote * 5.0, 3.0)
	var b := Vector2(cote * 31.0, -1.0)
	_troncon(c, p, r, b, a, 2.4, bois.darkened(0.12))
	var epaule := a.lerp(b, 0.56)
	c._baton(p, PackedVector2Array([epaule + Vector2(-cote * 3.0, 7.0), epaule + Vector2(cote * 4.0, -9.0)]), 1.9, bois)
	for i in 4:
		var q := epaule + Vector2(cote * 4.0, -9.0)
		var ang := -PI * 0.5 + cote * 0.3 + (i - 1.5) * 0.4
		p.tracer(PackedVector2Array([q, q + Vector2.from_angle(ang) * r.randf_range(3.0, 4.4)]), 1.0, paille.darkened(0.06 * i), true)
	# sa bâche : le buste, vidé, lacéré de trois griffes ; une manche plus loin
	var buste := PackedVector2Array([a.lerp(b, 0.22) + Vector2(0.0, -4.4), a.lerp(b, 0.5) + Vector2(0.0, -5.6), a.lerp(b, 0.74) + Vector2(0.0, -4.0), a.lerp(b, 0.8) + Vector2(0.0, 2.6),
		a.lerp(b, 0.62) + Vector2(0.0, 5.4), a.lerp(b, 0.42) + Vector2(0.0, 4.0), a.lerp(b, 0.3) + Vector2(0.0, 5.6), a.lerp(b, 0.18) + Vector2(0.0, 2.8)])
	p.eventail(a.lerp(b, 0.5) + Vector2(1.0, 4.0), 13.0, 4.0, Color(P.ENCRE, 0.3), Color(P.ENCRE, 0.0), 12)
	p.aplat(buste, toile)
	p.aplat(PackedVector2Array([buste[3], buste[4], buste[5], buste[6], buste[7], a.lerp(b, 0.3), a.lerp(b, 0.7)]), toile.darkened(0.17))
	var piece_q := a.lerp(b, 0.34) + Vector2(0.0, -1.6)
	var piece := PackedVector2Array([piece_q + Vector2(-2.0, -1.6), piece_q + Vector2(2.0, -1.8), piece_q + Vector2(2.2, 1.6), piece_q + Vector2(-1.8, 1.8)])
	p.aplat(piece, c.CUIR_CLAIR.darkened(0.08 + 0.2 * mouille))
	buste.append(buste[0])
	p.tracer(buste, 1.1, ENCRE, false)
	for k in 3:
		var u := 0.4 + 0.13 * k
		_dechirure(p, r, a.lerp(b, u) + Vector2(-cote * 1.0, -4.0), a.lerp(b, u + 0.05) + Vector2(cote * 1.0, 3.6), 0.75, clair)
	c._corde(p, PackedVector2Array([a.lerp(b, 0.26) + Vector2(0.0, -3.0), a.lerp(b, 0.3) + Vector2(cote * 3.0, 6.0), a.lerp(b, 0.2) + Vector2(-cote * 2.0, 8.4)]), 1.0)
	var manche := Vector2(-cote * 8.0, 9.0)
	_lambeau(p, r, manche, manche + Vector2(-cote * 11.0, 2.0), 6.0, toile.darkened(0.1), c.TOILE_OMBRE, clair)
	# sa tête : le sac de toile crevé, sa bourre qui sort ; un trou d'œil regarde encore
	var tete := b + Vector2(cote * 8.0, 2.0)
	p.eventail(tete + Vector2(0.8, 3.0), 7.0, 2.6, Color(P.ENCRE, 0.34), Color(P.ENCRE, 0.0), 12)
	p.disque(tete, 6.2, 5.2, ENCRE)
	p.disque(tete, 5.3, 4.4, clair.darkened(0.08), Pinceau.DOME)
	# (sa couture, le col noué ; ses deux trous, l'un plus grand que l'autre, tournés vers le ciel)
	p.tracer(_courbe(tete + Vector2(-cote * 3.0, -3.8), tete + Vector2(-cote * 4.6, 0.0), tete + Vector2(-cote * 3.0, 3.6), 5), 0.7, Color(ENCRE, 0.6), false)
	for i in 3:
		var qc := tete + Vector2(-cote * 4.0, -2.2 + i * 2.1)
		p.tracer(PackedVector2Array([qc + Vector2(-1.0, -0.3), qc + Vector2(1.0, 0.3)]), 0.6, Color(ENCRE, 0.6), false)
	p.eventail(tete + Vector2(cote * 1.2, -1.9), 1.25, 1.5, Color("17130f"), Color("17130f"), 7)
	p.eventail(tete + Vector2(cote * 3.8, -0.8), 0.95, 1.15, Color("17130f"), Color("17130f"), 7)
	# (crevé par en dessous : sa bourre en sort, jaune, en touffe)
	_dechirure(p, r, tete + Vector2(-cote * 2.6, 1.6), tete + Vector2(cote * 4.2, 3.4), 1.0, clair)
	for i in 7:
		var q := tete + Vector2(cote * r.randf_range(-2.0, 3.6), r.randf_range(2.2, 3.6))
		var bout := q + Vector2(r.randf_range(-2.4, 2.4), r.randf_range(2.0, 5.0))
		p.tracer(PackedVector2Array([q, bout]), 1.9, Color(ENCRE, 0.6), true)
		p.tracer(PackedVector2Array([q, bout]), 1.0, paille.lightened(0.1).darkened(0.07 * (i % 3)), true)
	# son chapeau, roulé plus loin
	var chapeau := tete + Vector2(cote * 9.0, 7.0)
	var m := Transform2D(0.5 * cote, chapeau)
	p.eventail(chapeau + Vector2(0.6, 2.0), 9.0, 2.6, Color(P.ENCRE, 0.3), Color(P.ENCRE, 0.0), 12)
	p.aplat(m * Pinceau.ellipse(Vector2.ZERO, 8.6, 3.6, 16), ENCRE)
	p.aplat(m * Pinceau.ellipse(Vector2.ZERO, 7.8, 2.9, 16), paille.darkened(0.1))
	p.aplat(m * Pinceau.ellipse(Vector2(-0.5, -0.4), 5.6, 1.8, 14), paille.lightened(0.08))
	p.aplat(m * Pinceau.ellipse(Vector2(0.4, 0.2), 3.4, 1.5, 10), Color("1c1813"))
	if c._neige_cran() > 0.2:
		p.disque(a.lerp(b, 0.5) + Vector2(0.0, -4.0), 8.0, 2.0, c.NEIGE, Pinceau.DOME)


# son écharpe : nouée au col du sac, elle traîne à terre, et se soulève au vent
static func _epouvantail_vif(c, p, cote: float) -> void:
	var mouille: float = c._mouille_cran()
	var echarpe: Color = P.ECHARPE.lerp(P.IVOIRE, 0.12).darkened(0.1 + 0.2 * mouille)
	var vent: float = c._vent
	var bout := Vector2(cote * 36.0, 4.0)
	var ligne := PackedVector2Array([bout])
	for k in 5:
		var ang := lerpf(0.28, -0.5, pow(vent, 0.7)) + 0.5 * sin(c._t * 6.5 - k * 0.95) * vent * (0.3 + k * 0.14)
		bout += Vector2(cos(ang) * -cote, sin(ang)) * 2.7
		ligne.append(bout)
	p.tracer(ligne, 2.8, ENCRE, false, PackedFloat32Array([3.2, 3.6, 3.5, 3.2, 2.7, 2.0]))
	p.tracer(ligne, 1.8, echarpe, false, PackedFloat32Array([2.0, 2.4, 2.3, 2.0, 1.5, 0.8]))


# --- la mangeoire : l'auge renversée, ses deux rondins fendus séparés, l'un rayé de trois griffes ; une croix de pieux
# défaite, l'autre de travers ; le foin foulé ---

static func _mangeoire(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(77)
	var mouille: float = c._mouille_cran()
	var ecorce: Color = c.ECORCE.darkened(0.2 * mouille)
	var clair: Color = c.BOIS_CLAIR.darkened(0.24 * mouille)
	var paille: Color = c.CORDE.lightened(0.16).darkened(0.25 * mouille)
	c._ombre(p, Vector2(cote * 4.0, 3.0), 25.0, 8.5, 0.3)
	_labour(p, r, Vector2(cote * 22.0, 8.0), 19.0, 6.5)
	_sillons(p, Vector2(cote * 40.0, 15.0), Vector2(cote * 24.0, 12.5))
	# le foin : foulé, répandu de son côté
	_brins(p, r, Vector2(cote * 10.0, 4.0), 22.0, 6.5, 30, paille)
	# la croix restée debout, de travers (du côté où elle n'était pas) : ses deux pieux, sa ligature
	var l0 := -cote * 12.0
	var penche := Vector2(cote * 4.0, 1.0)
	c._perche(p, c._mg(l0, 8.0, 0.0), c._mg(l0, -7.0, 17.0) + penche, 2.7, 2.2, ecorce.darkened(0.15))
	c._perche(p, c._mg(l0, -8.0, 0.0), c._mg(l0, 7.0, 17.0) + penche, 2.9, 2.3, ecorce.lightened(0.04))
	var lig: Vector2 = c._mg(l0, 0.0, 9.0) + penche * 0.5
	c._corde(p, PackedVector2Array([lig + Vector2(-2.3, -1.3), lig + Vector2(2.2, 1.0)]), 0.9)
	c._corde(p, PackedVector2Array([lig + Vector2(-2.2, 0.9), lig + Vector2(2.3, -1.2)]), 0.9)
	# l'autre croix : défaite, ses pieux à terre, l'un cassé ; sa corde lâche
	var pied: Vector2 = c._mg(cote * 12.0, 0.0, 0.0)
	_troncon(c, p, r, pied + Vector2(cote * 20.0, -3.0), pied + Vector2(cote * 3.0, -5.0), 2.6, ecorce.darkened(0.1))
	c._baton(p, PackedVector2Array([pied + Vector2(-cote * 2.0, 6.0), pied + Vector2(cote * 15.0, 9.0)]), 2.4, ecorce.lightened(0.04), 1.1)
	_corde_lache(c, p, r, pied + Vector2(cote * 4.0, 1.0), pied + Vector2(cote * 13.0, 4.0), 0.8)
	# l'auge : le rondin du fond, retourné sur son plat ; celui de devant, tombé plus loin, son plat clair en l'air, griffé
	var fa := Vector2(-cote * 15.0, 2.0)
	var fb := Vector2(cote * 12.0, -3.0)
	c._rondin(p, fa, fb, 6.2, ecorce, clair)
	var da := Vector2(-cote * 5.0, 9.5)
	var db := Vector2(cote * 23.0, 13.0)
	p.eventail(da.lerp(db, 0.5) + Vector2(0.8, 2.4), 16.0, 3.4, Color(P.ENCRE, 0.32), Color(P.ENCRE, 0.0), 12)
	var n := (db - da).orthogonal().normalized() * 3.1
	if n.y > 0.0:
		n = -n
	var plat := PackedVector2Array([da + n, db + n, db - n * 0.4, da - n * 0.4])
	p.aplat(plat, clair)
	p.aplat(PackedVector2Array([da - n * 0.4, db - n * 0.4, db - n, da - n]), ecorce.lightened(0.05))
	# (le creux de l'auge, dans son plat)
	p.aplat(PackedVector2Array([da.lerp(db, 0.08) + n * 0.55, da.lerp(db, 0.92) + n * 0.55, da.lerp(db, 0.9) - n * 0.1, da.lerp(db, 0.1) - n * 0.1]), clair.darkened(0.3))
	p.tracer(PackedVector2Array([da + n, db + n]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([da - n, db - n]), 1.4, ENCRE, false)
	p.tracer(PackedVector2Array([da + n, da - n]), 1.0, ENCRE, false)
	p.tracer(PackedVector2Array([db + n, db - n]), 1.1, ENCRE, false)
	p.tracer(PackedVector2Array([da - n * 0.4, db - n * 0.4]), 0.6, Color(ENCRE, 0.6), false)
	# (les trois griffes : le bois à nu, pâle, dans l'écorce du rondin retourné)
	_griffes(p, fa.lerp(fb, 0.3) + Vector2(0.0, -2.2), fa.lerp(fb, 0.74) + Vector2(0.0, 1.6), 1.7, 1.9, ENCRE)
	_griffes(p, fa.lerp(fb, 0.32) + Vector2(0.0, -2.2), fa.lerp(fb, 0.72) + Vector2(0.0, 1.6), 1.7, 0.9, clair.lightened(0.1))
	# la planchette du bout, sautée
	var pl := Vector2(cote * 28.0, 2.0)
	var planche := PackedVector2Array([pl + Vector2(-3.0, -2.0), pl + Vector2(3.4, -2.8), pl + Vector2(4.0, 1.0), pl + Vector2(-2.6, 1.8)])
	p.aplat(planche, c.BOIS.darkened(0.1 + 0.2 * mouille))
	planche.append(planche[0])
	p.tracer(planche, 1.0, ENCRE, false)
	if c._neige_cran() > 0.2:
		p.tracer(PackedVector2Array([fa + Vector2(1.0, -3.2), fb + Vector2(-1.0, -3.2)]), 1.0 + 1.4 * c._neige_cran(), c.NEIGE)


# --- le carré de jardin : piétiné. Ses sillons écrasés, deux de ses pattes dedans, les tiges couchées et cassées, la terre
# jetée dehors ; on voit trois sillons qui ne sont pas de la houe ---

static func _carre(c, p, cote: float) -> void:
	var r: RandomNumberGenerator = c._hasard(78)
	# (le carré lui-même : ses rondins, ses pierres, sa terre ; il est vide, ce qui y poussait est perdu)
	c._carre(p)
	var terre: Color = P.TERRE.darkened(0.3)
	# la terre tassée, lissée : ses sillons n'y sont plus
	for i in 3:
		var q: Vector2 = c._carre_pt(lerpf(-12.0, 12.0, i / 2.0) + r.randf_range(-2.0, 2.0), r.randf_range(-5.0, 5.0))
		p.eventail(q, 11.0, 6.0, Color(terre, 0.7), Color(terre, 0.0), 12)
	# deux de ses pattes, en travers des sillons
	_empreinte(p, c._carre_pt(-cote * 9.0, -3.5), 8.5, PI if cote > 0.0 else 0.0)
	_empreinte(p, c._carre_pt(cote * 10.0, 3.5), 8.5, (PI if cote > 0.0 else 0.0) + cote * 0.25)
	# ses griffes : trois sillons en travers des autres
	_griffes(p, c._carre_pt(-cote * 18.0, 8.0), c._carre_pt(-cote * 1.0, 10.5), 2.2, 1.6, Color(P.ENCRE, 0.7))
	# ce qui poussait : couché, cassé, à demi enterré
	var vert: Color = P.MOUSSE.lerp(c.CORDE, 0.3)
	for i in 14:
		var q: Vector2 = c._carre_pt(r.randf_range(-19.0, 19.0), r.randf_range(-9.5, 9.5))
		var d := Vector2.from_angle(r.randf_range(-0.5, 0.5) + (0.0 if r.randf() < 0.5 else PI)) * r.randf_range(2.0, 4.6)
		p.tracer(PackedVector2Array([q, q + d * 0.5 + Vector2(0.0, -0.6), q + d]), 2.1, Color(ENCRE, 0.6), true)
		p.tracer(PackedVector2Array([q, q + d * 0.5 + Vector2(0.0, -0.6), q + d]), 1.2, vert.lightened(0.12).darkened(r.randf_range(0.0, 0.3)), true)
		if i % 3 == 0:
			# (une feuille, encore attachée, à plat)
			var f := q + d
			var fn := d.orthogonal().normalized() * 1.3
			p.aplat(PackedVector2Array([f - d.normalized() * 1.6, f + fn, f + d.normalized() * 2.0, f - fn]), vert.lightened(0.16))
	# la terre jetée hors du carré, du côté où elle est repartie
	for i in 9:
		var q: Vector2 = c._carre_pt(cote * r.randf_range(23.0, 34.0), r.randf_range(-11.0, 13.0))
		var m := r.randf_range(0.9, 2.0)
		p.tracer(PackedVector2Array([q + Vector2(-m, 0.8), q + Vector2(m * 1.1, 0.85)]), 0.8, Color(ENCRE, 0.45), false)
		p.eventail(q, m, m * 0.62, P.TERRE.lightened(r.randf_range(0.0, 0.16)), P.TERRE.darkened(0.1), 6)
