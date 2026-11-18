extends RefCounted
# Lisière — les buissons de l'herbier, dessinés à l'encre (scripts/flore_buissons.gd)
# Le buisson et l'arbuste à baies sont les premiers dessins (scripts/objet.gd, _buisson). Ici, ceux qui ont leur silhouette à
# eux, d'après les planches d'Orvane : le buisson d'épines (deux masses sombres, anguleuses, des rameaux en zigzag armés de
# longues épines, ses prunelles), le roncier (des cannes rouges arquées qui retombent, leurs aiguillons, leurs feuilles par
# trois, ses mûres), l'aromatique (un dôme gris-vert sur son bois, ses hampes et leurs épis de fleurs en étages), la bruyère (un
# coussin de brins dressés, ses grappes de clochettes), la liane (enroulée à un vieux fût mort, ses feuilles en cœur, ses
# brins qui pendent). Tous ont la facture des premiers : des touffes peintes par le shader, leur ombre l'une sur l'autre, le
# cerne plus lourd en bas à droite, la neige posée s'il fait froid, ce qu'on y a cueilli qui manque.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const T := preload("res://scripts/flore_trait.gd")
const Flore := preload("res://scripts/flore.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)


static func mesurer(o, r: RandomNumberGenerator, f: String) -> bool:
	match f:
		"bruyere", "aromatique":
			o._rx = r.randf_range(11.0, 14.0)
			o._ry = r.randf_range(9.0, 12.0)
		"ronce":
			o._rx = r.randf_range(15.0, 19.0)
			o._ry = r.randf_range(15.0, 19.0)
		"liane":
			# (8 m, enroulée à son fût : plus haute que la veilleuse)
			o._ry = r.randf_range(33.0, 40.0)
		_:
			return false
	if T.a(o, "naine"):
		o._ry *= 0.88
		o._rx *= 1.08
	o.hauteur = o._ry
	return true


static func dessiner(o, p, r: RandomNumberGenerator, f: String) -> bool:
	match f:
		"epine":
			epine(o, p, r)
		"ronce":
			ronce(o, p, r)
		"aromatique":
			aromatique(o, p, r)
		"bruyere":
			bruyere(o, p, r)
		"liane":
			liane(o, p, r)
		_:
			return false
	return true


# le bois au pied d'un buisson : quelques tiges tordues qui sortent de terre (noircies, si les feux y sont passés)
static func _bois(o, p, r: RandomNumberGenerator, rx: float, haut: float, n: int, bois: Color) -> void:
	var brule := T.a(o, "pyrophyte")
	for i in n:
		var x := lerpf(-rx * 0.6, rx * 0.6, (i + r.randf_range(0.1, 0.9)) / n)
		var bout := Vector2(x * 1.4 + r.randf_range(-2, 2), -haut)
		var ligne := PackedVector2Array([Vector2(x, 1.5), Vector2(x * 1.15 + r.randf_range(-1.2, 1.2), -haut * 0.5), bout])
		p.tracer(ligne, 2.3, ENCRE, false, PackedFloat32Array([2.6, 2.2, 1.6]))
		p.tracer(ligne, 1.3, bois if not brule else bois.lerp(P.ENCRE, 0.6), false, PackedFloat32Array([1.6, 1.3, 0.8]))
	if T.a(o, "racines_profondes"):
		# (le collet : une vieille souche d'où tout repart, ses racines qui plongent)
		p.disque(Vector2(0, 0.8), rx * 0.32, 2.0, ENCRE)
		p.disque(Vector2(0, 0.6), rx * 0.32 - 0.7, 1.4, bois.darkened(0.1), Pinceau.ECORCE)


# -- le buisson d'épines --

# un buisson d'épines : dense, anguleux, sombre — une masse au fond, une autre devant, qui lui fait de l'ombre ; des rameaux
# qui dépassent en zigzag, leurs longues épines à la pointe claire ; des prunelles bleu-noir s'il en porte, sinon de petites
# fleurs blanches
static func epine(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var bois := P.ENCRE_DOUCE.lerp(P.TERRE, 0.35)
	_bois(o, p, r, rx, 6.5, 4, bois)
	var centre := Vector2(0, -ry * 0.5)
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, 0.38))
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.15)
	# (la masse du fond, plus haute, plus sombre)
	var fond_c := centre + Vector2(rx * r.randf_range(-0.25, 0.25), -ry * 0.16)
	var fond: PackedVector2Array = o.festons(fond_c, rx * 0.74, ry * 0.46, r.randi_range(8, 10), 0.3, r, 40, 0.2)
	p.aplat(fond, t.darkened(0.14), Pinceau.FEUILLAGE, fond_c, Vector2(rx * 0.74, ry * 0.46) * 1.08)
	T.neige(o, p, fond, fond_c, rx * 0.74, ry * 0.46, r)
	p.contour(fond, 1.2, ENCRE, r, 4)
	_herisser(p, fond, fond_c, 3)
	T.ombre_douce(p, centre + Vector2(1.0, 1.5), rx * 0.95, ry * 0.5, 0.3)
	var poly: PackedVector2Array = o.festons(centre + Vector2(0, ry * 0.05), rx, ry * 0.5, r.randi_range(11, 14), 0.3, r, 56, 0.25)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.55) * 1.08)
	T.neige(o, p, poly, centre, rx, ry * 0.5, r)
	p.contour(poly, 1.3, ENCRE, r, 4)
	# (des rameaux qui dépassent en zigzag, et leurs épines)
	for i in r.randi_range(4, 6):
		var a := r.randf_range(-PI + 0.3, -0.3)
		var d := Vector2(cos(a), sin(a) * 0.7)
		var q0 := centre + Vector2(d.x * rx * 0.8, d.y * ry * 0.45)
		var q1 := q0 + d * r.randf_range(3.0, 6.0) + d.orthogonal() * r.randf_range(-1.5, 1.5)
		var q2 := q1 + d * r.randf_range(2.0, 4.0) - d.orthogonal() * r.randf_range(-1.5, 1.5)
		p.tracer(PackedVector2Array([q0, q1, q2]), 1.2, ENCRE, false)
		for q in [q1, q2]:
			var dir: Vector2 = (d.orthogonal() * (1.0 if q == q1 else -1.0) + d * 0.4).normalized()
			T.epine(p, q, dir, 2.8, 0.8)
			p.disque(q + dir * 2.8, 0.35, 0.35, P.IVOIRE)
	_herisser(p, poly, centre, 3)
	if o.a_fruits:
		var prune := P.NUIT_BLEUE.lerp(P.LUNE, 0.35)
		var rb := RandomNumberGenerator.new()
		rb.seed = int(o.graine) + 5
		for i in int(o.reste) * 4:
			var q := centre + Vector2(rb.randf_range(-0.7, 0.7) * rx, rb.randf_range(-0.45, 0.5) * ry * 0.55)
			p.disque(q, 2.1, 2.0, ENCRE)
			p.disque(q, 1.55, 1.5, prune, Pinceau.DOME)
			p.disque(q + Vector2(-0.4, -0.5), 0.6, 0.5, Color(P.LUNE.lightened(0.5), 0.8))
	else:
		# (sans fruits : de petites fleurs blanches, éparses, à cinq pétales)
		for i in 7:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.5, 0.2) * ry * 0.55)
			p.disque(q, 1.35, 1.2, Color(ENCRE, 0.5))
			p.disque(q, 1.05, 0.95, P.PAPIER.lightened(0.1))
			p.disque(q, 0.3, 0.3, P.BRAISE_COEUR)


# des épines d'encre tout autour d'une touffe, tournées vers dehors (sauf dessous)
static func _herisser(p, poly: PackedVector2Array, centre: Vector2, pas: int) -> void:
	for i in range(0, poly.size(), pas):
		var q: Vector2 = poly[i]
		var dehors := (q - centre).normalized()
		if dehors.y > 0.55:
			continue
		T.epine(p, q - dehors * 0.5, (dehors + dehors.orthogonal() * 0.35).normalized(), 2.6, 0.85)


# -- le roncier --

# un roncier : un fourré bas en deux masses (celle de devant, plus claire, fait de l'ombre à l'autre), des cannes arquées
# d'un brun pourpre qui en sortent et retombent jusqu'au sol, où leur pointe s'enracine — celles du fond derrière le fourré,
# deux ou trois par-dessus ; leurs aiguillons crochus, leurs feuilles alternes de trois folioles ; des mûres noires
# (quelques-unes encore rouges), ou ses fleurs au printemps
static func ronce(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	# (des cannes d'un brun pourpre, pruineuses, pas d'un rouge vif : elles se fondent dans leur fouillis)
	var tige := P.SANG.lerp(P.TERRE, 0.58).lerp(P.NUIT, 0.12)
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, 0.22))
	var centre := Vector2(0, -ry * 0.45)
	# (les cannes : elles montent du collet, s'arquent et retombent, leur pointe s'enracine dans la terre, à l'écart ; celles du
	# fond se dessinent avant le fourré, qui en cache le pied, celles de devant après ; deux ou trois passent par-dessus tout)
	var cannes := []
	for i in r.randi_range(5, 7):
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a0 := Vector2(r.randf_range(-rx * 0.3, rx * 0.3), r.randf_range(-ry * 0.12, 0.8))
		var b0 := Vector2(cote * r.randf_range(rx * 0.7, rx * 1.12), r.randf_range(-1.5, 2.0))
		var h := r.randf_range(ry * 0.8, ry * 1.15)
		var sommet := Vector2(lerpf(a0.x, b0.x, r.randf_range(0.3, 0.55)), -h)
		cannes.append([a0, sommet, b0, i % 3 != 0])
	var dessus := []
	for c in cannes:
		if not bool(c[3]):
			dessus.append(c)
			continue
		_canne(p, r, c, tige, t, 0.85)
	# (le fourré : une masse de feuilles, une autre, plus claire, devant et au-dessus, qui lui fait de l'ombre)
	var fond: PackedVector2Array = o.festons(centre + Vector2(0, ry * 0.1), rx * 0.86, ry * 0.46, 9, 0.24, r, 40, 0.3)
	p.aplat(fond, t.darkened(0.14), Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5))
	T.neige(o, p, fond, centre + Vector2(0, ry * 0.1), rx * 0.86, ry * 0.46, r)
	p.contour(fond, 1.1, ENCRE, r, 3)
	var c2 := centre + Vector2(-rx * 0.12, -ry * 0.06)
	var avant: PackedVector2Array = o.festons(c2, rx * 0.6, ry * 0.36, 7, 0.26, r, 32, 0.25)
	p.aplat(o.festons(c2 + Vector2(1.2, 1.4), rx * 0.6, ry * 0.36, 7, 0.26, r, 32, 0.25), Color(P.NUIT, 0.3))
	p.aplat(avant, t, Pinceau.FEUILLAGE, c2, Vector2(rx * 0.6, ry * 0.36) * 1.1)
	T.neige(o, p, avant, c2, rx * 0.6, ry * 0.36, r)
	p.contour(avant, 1.0, ENCRE, r, 3)
	# (des folioles dentées qui dépassent de la masse, du côté du jour)
	for i in 4:
		var q := c2 + Vector2(r.randf_range(-0.9, 0.5) * rx * 0.6, -r.randf_range(0.3, 0.9) * ry * 0.36)
		T.feuille(p, q, q + Vector2(r.randf_range(-2.4, 1.2), -r.randf_range(2.0, 3.2)), 1.3, t.lightened(0.12), 0.3, 0.45, 0.5, 3)
	for c in dessus:
		_canne(p, r, c, tige, t, 1.0)
	var rb := RandomNumberGenerator.new()
	rb.seed = int(o.graine) + 5
	if o.reste > 0 and str(o.maturite) == "fleurs":
		# (au printemps : ses fleurs blanc rosé, à la place des mûres)
		for g in int(o.reste) * 2:
			var c: Array = cannes[g % cannes.size()]
			var q: Vector2 = c[0].lerp(c[1], 0.7).lerp(c[1].lerp(c[2], 0.7), 0.7) + Vector2(rb.randf_range(-2.0, 2.0), rb.randf_range(0.0, 2.0))
			p.disque(q, 2.2, 2.0, Color(ENCRE, 0.6))
			for k in 5:
				p.disque(q + Vector2.from_angle(TAU * k / 5.0) * 1.1, 0.9, 0.8, P.PAPIER.lerp(P.AUBE, 0.25))
			p.disque(q, 0.5, 0.5, P.BRAISE_COEUR)
	elif o.reste > 0:
		for g in int(o.reste) * 2:
			var c: Array = cannes[g % cannes.size()]
			var q: Vector2 = c[0].lerp(c[1], 0.7).lerp(c[1].lerp(c[2], 0.7), 0.7) + Vector2(rb.randf_range(-2.0, 2.0), rb.randf_range(0.0, 2.0))
			var mure := P.NUIT.lerp(P.SANG, 0.35) if rb.randf() < 0.75 else P.BRAISE_ROUGE
			p.disque(q, 2.4, 2.6, ENCRE)
			p.disque(q, 1.8, 2.0, mure, Pinceau.DOME)
			for k in 3:
				p.disque(q + Vector2(rb.randf_range(-0.9, 0.9), rb.randf_range(-1.1, 1.1)), 0.45, 0.45, Color(1.0, 0.92, 0.9, 0.6))


# une canne de ronce : arquée, pruineuse (un fil pâle sur son dos), effilée vers sa pointe ; ses aiguillons crochus, de loin en
# loin ; ses feuilles alternes, de trois folioles au bout d'un pétiole, qui pendent un peu ; les plus jeunes, vers la pointe,
# plus petites et plus tendres ; la pointe qui retouche terre s'y enracine (une petite touffe neuve). force < 1 : une canne du
# fond, plus sombre
static func _canne(p, r: RandomNumberGenerator, c: Array, tige: Color, t: Color, force: float) -> void:
	# (8 segments : la courbe reste lisse à cette taille ; une feuille aux nœuds 2, 5 et 7, des aiguillons entre)
	var ligne := T.courbe(c[0], c[1], c[2], 8)
	var ton := tige.darkened(1.6 * (1.0 - force))
	var vert := t.darkened(0.6 * (1.0 - force))
	p.tracer(ligne, 2.2, ENCRE, false, PackedFloat32Array([2.4, 2.1, 1.3]))
	p.tracer(ligne, 1.2, ton, false, PackedFloat32Array([1.4, 1.15, 0.6]))
	var clair := PackedVector2Array()
	for k in range(1, ligne.size() - 2):
		clair.append(ligne[k] + Vector2(-0.2, -0.4))
	p.tracer(clair, 0.4, Color(ton.lightened(0.3).lerp(P.LUNE, 0.35), 0.6), true)
	for k in range(1, 8):
		var q := ligne[k]
		var d := (ligne[k + 1] - ligne[k - 1]).normalized()
		var nrm := d.orthogonal()
		var cote := 1.0 if k % 2 == 0 else -1.0
		if k in [1, 3, 4, 6]:
			# (l'aiguillon, crochu vers le pied de la canne)
			T.epine(p, q, (nrm * -cote - d * 0.5).normalized(), 1.5, 0.6)
			continue
		var jeune := k >= 7
		var dir_f := (nrm * cote + Vector2(0.0, 0.55)).normalized()
		var pq := q + dir_f * (1.1 if jeune else 1.6)
		p.tracer(PackedVector2Array([q, pq]), 0.6, Color(ENCRE, 0.7), false)
		var s := (0.72 if jeune else 1.0) * r.randf_range(0.9, 1.1)
		var ton_f := vert.lightened(0.16 if jeune else 0.0)
		ton_f = ton_f.lightened(0.08) if dir_f.dot(T.JOUR) > -0.2 else ton_f.darkened(0.12)
		# (trois folioles, la médiane plus longue ; à deux tons, sans nervure : à cette taille, elle ne se verrait pas)
		for j in [-1, 1, 0]:
			var ang: float = dir_f.angle() + j * 0.85
			var l: float = (3.0 if j != 0 else 3.9) * s
			T.feuille(p, pq, pq + Vector2.from_angle(ang) * l, 1.15 * s, ton_f, j * 0.35, 0.42, 0.5, 3)
	# (la pointe qui s'enracine, devant : une touffe neuve au ras du sol)
	var b: Vector2 = c[2]
	if b.y > -2.5 and force >= 1.0:
		T.ombre_douce(p, b + Vector2(0.4, 0.6), 2.2, 0.9, 0.25)
		for j in 2:
			var ang := -PI * 0.5 + (j - 0.5) * 1.0
			T.feuille(p, b, b + Vector2.from_angle(ang) * 2.2, 0.9, vert.lightened(0.2), 0.0, 0.42, 0.45, 3)


# -- l'aromatique --

# un buisson aromatique : un dôme bas, gris-vert, d'aiguilles feutrées qui le hérissent sur son pourtour, sur son vieux bois
# tordu ; il en monte des hampes grêles, chacune finie d'un épi effilé de fleurs en étages serrés (de la couleur de sa planche
# d'Orvane ; sinon lavande, ou jaunes). Ce qu'on y a cueilli se voit, en fleurs ou non : des brins coupés court,
# leur coupe claire. Sur échasses : son bois nu le soulève. Aux fruits charnus : de petites baies dans le gris
static func aromatique(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = T.feuillage(o, o.teinte.lerp(P.LUNE, 0.28).lerp(P.IVOIRE, 0.18))
	var leve := 3.6 if T.a(o, "echasses") else 0.0
	var bois := P.CENDRE.lerp(P.TERRE, 0.5)
	_bois(o, p, r, rx, 4.5 + leve * 1.6, 4 if leve > 0.0 else 3, bois)
	var centre := Vector2(0, -ry * 0.42 - leve)
	T.ombre_douce(p, Vector2(0.6, 0.8), rx * 0.8, 2.4, 0.22)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.5, r.randi_range(9, 12), 0.2, r, 44, 0.3)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5) * 1.08)
	T.neige(o, p, poly, centre, rx, ry * 0.5, r)
	p.contour(poly, 1.2, ENCRE, r, 3)
	# (son feuillage est fait d'aiguilles feutrées, gris argent : de fins traits clairs du côté du jour, des creux d'ombre en
	# bas à droite ; et sur son pourtour, des touffes d'aiguilles qui le hérissent)
	for i in 9:
		var q := centre + Vector2(r.randf_range(-0.75, 0.35) * rx, r.randf_range(-0.55, 0.15) * ry * 0.5)
		var dq := Vector2(r.randf_range(-0.5, 0.3), -1.0).normalized()
		p.tracer(PackedVector2Array([q, q + dq * r.randf_range(1.6, 2.6)]), 0.5, Color(t.lightened(0.32), 0.85), true)
	for i in 3:
		var q := centre + Vector2(r.randf_range(0.0, 0.6) * rx, r.randf_range(0.0, 0.35) * ry * 0.5)
		var arc := PackedVector2Array()
		for k in 5:
			var a := 0.1 + k * 0.33
			arc.append(q + Vector2(cos(a), sin(a) * 0.8) * 3.6)
		p.tracer(arc, 0.7, Color(ENCRE, 0.45))
	for i in range(1, poly.size(), 3):
		var q: Vector2 = poly[i]
		if q.y > centre.y + ry * 0.1:
			continue
		var dehors := (q - centre).normalized()
		var jour := dehors.dot(T.JOUR) > 0.0
		for k in 3:
			var dk := dehors.rotated((k - 1) * 0.42 + r.randf_range(-0.12, 0.12)) + Vector2(0.0, -0.35)
			var bout := q + dk.normalized() * r.randf_range(1.4, 2.4)
			p.tracer(PackedVector2Array([q - dehors * 0.6, bout]), 1.1, Color(ENCRE, 0.6), false, PackedFloat32Array([1.1, 0.5]))
			p.tracer(PackedVector2Array([q - dehors * 0.6, bout]), 0.5, t.lightened(0.16) if jour else t.darkened(0.12), false)
	if T.a(o, "fruits_charnus"):
		for i in 6:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.1, 0.4) * ry * 0.5)
			p.disque(q, 1.3, 1.25, ENCRE)
			p.disque(q, 0.9, 0.85, P.BRAISE_ROUGE.lerp(P.BRAISE, 0.3), Pinceau.DOME)
	# (la couleur de ses fleurs : celle de sa planche d'Orvane ; sinon lavande, ou jaune comme l'immortelle)
	var fleur: Color = o.couleur_fleur if o.couleur_fleur.a > 0.0 else (P.PEUR.lerp(P.CREPUSCULE, 0.45) if int(o.graine) % 2 == 0 else P.BRAISE_COEUR.darkened(0.1))
	var n := 12
	var fleuries: int = n * int(o.reste) / maxi(1, int(o.plein)) if o.en_fleurs else 0
	# (ce qu'on y a cueilli se voit, en fleurs ou non : des brins coupés court, leur coupe claire ; scripts/flore.gd, des aromates)
	var restent: int = n * int(o.reste) / maxi(1, int(o.plein))
	for i in n:
		var x := lerpf(-rx * 0.8, rx * 0.8, (i + r.randf_range(0.2, 0.8)) / n)
		var y0 := centre.y + absf(x) / rx * ry * 0.25 - ry * 0.25
		var bout := Vector2(x * 1.22 + r.randf_range(-1.0, 1.0), y0 - r.randf_range(6.0, 10.0) * (1.0 - absf(x) / rx * 0.3))
		if i >= restent:
			bout = Vector2(x, y0).lerp(bout, 0.35)
			p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 1.0, t.darkened(0.25))
			p.disque(bout, 0.8, 0.6, P.IVOIRE.lerp(t, 0.3))
			continue
		var d := (bout - Vector2(x, y0)).normalized()
		var nrm := d.orthogonal()
		# (la hampe : grêle, carrée, une paire de petites feuilles à mi-hauteur)
		p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 1.2, Color(ENCRE, 0.7), false, PackedFloat32Array([1.2, 0.8]))
		p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 0.6, t.darkened(0.2), false)
		var mi := Vector2(x, y0).lerp(bout, 0.38)
		for cote in [-1.0, 1.0]:
			p.tracer(PackedVector2Array([mi, mi + nrm * cote * 1.5 - d * 0.6]), 0.6, t.lightened(0.05), true)
		if i < fleuries:
			# (l'épi : une silhouette d'encre effilée, puis les fleurs en étages serrés, deux par étage, plus petites vers la
			# pointe ; un bouton pâle au bout)
			var lg := r.randf_range(3.6, 4.8)
			var base := bout - d * lg
			p.aplat(PackedVector2Array([bout + d * 0.9, bout - d * 1.2 + nrm * 1.25, base - d * 0.2 + nrm * 1.05, base - d * 0.7,
				base - d * 0.2 - nrm * 1.05, bout - d * 1.2 - nrm * 1.25]), Color(ENCRE, 0.85))
			for k in 5:
				var q := base.lerp(bout, k / 4.6)
				var s0 := 0.62 - 0.06 * k
				for cote in [-1.0, 1.0]:
					var fq: Vector2 = q + nrm * cote * (0.42 - 0.04 * k) + d * (0.22 if cote > 0.0 else 0.0)
					var clair: bool = (nrm * cote).dot(T.JOUR) > 0.0
					p.disque(fq, s0, s0 * 0.85, fleur.lightened(0.16) if clair else fleur.darkened(0.12), Pinceau.DOME)
			p.disque(bout + d * 0.3, 0.42, 0.42, fleur.lightened(0.3))
		else:
			# (pas en fleurs : deux petites feuilles au bout du brin)
			for cote in [-1.0, 1.0]:
				T.feuille(p, bout - d * 1.5, bout + nrm * cote * 2.0 + d * 0.8, 0.8, t.lightened(0.1), 0.0, 0.45, 0.35, 3)


# -- la bruyère --

# une bruyère : un coussin bas de brins dressés, serrés, vert brun (sa silhouette en est hérissée), sur son bois ; au bout des
# brins, des grappes de clochettes rose-mauve — d'autant moins qu'on en a cueilli
static func bruyere(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var feuille: Color = T.vert_propre(o, P.MOUSSE.lerp(P.TERRE, 0.4).darkened(0.12), 0.15)
	_bois(o, p, r, rx, 3.6, 3, P.TERRE.lerp(P.ENCRE_DOUCE, 0.4))
	var centre := Vector2(0, -ry * 0.4)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.62, r.randi_range(6, 8), 0.22, r, 36, 0.2)
	p.aplat(poly, feuille, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.62) * 1.08)
	T.neige(o, p, poly, centre, rx, ry * 0.62, r)
	p.contour(poly, 1.0, ENCRE, r, 3)
	# (les brins : de petits traits dressés sur le coussin, et d'autres qui dépassent du haut)
	for i in 10:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.4, 0.5) * ry * 0.48)
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-1.0, 1.0), -2.4)]), 0.7, Color(ENCRE, 0.5))
	var brins := []
	for i in range(0, poly.size(), 3):
		var q: Vector2 = poly[i]
		if q.y > centre.y - ry * 0.1:
			continue
		var bout := q + Vector2((q.x - centre.x) * 0.12 + r.randf_range(-0.6, 0.6), -r.randf_range(1.8, 3.4))
		p.tracer(PackedVector2Array([q + Vector2(0, 0.6), bout]), 1.3, Color(ENCRE, 0.8), false, PackedFloat32Array([1.4, 0.7]))
		p.tracer(PackedVector2Array([q + Vector2(0, 0.6), bout]), 0.6, feuille.lightened(0.12), false)
		brins.append(bout)
	if o.en_fleurs:
		var fleur := P.CREPUSCULE.lerp(P.PEUR, 0.3).lightened(0.12)
		var nb: int = 26 * int(o.reste) / maxi(1, int(o.plein))
		for i in nb:
			var q := centre + Vector2(r.randf_range(-0.85, 0.75) * rx, r.randf_range(-0.95, 0.35) * ry * 0.48)
			p.disque(q, r.randf_range(0.8, 1.3), r.randf_range(0.6, 0.95), fleur.lightened(r.randf_range(0.0, 0.25)) if q.x < 0.0 else fleur.darkened(0.08))
		# (et les grappes du bout des brins)
		for i in brins.size():
			if i * int(o.plein) >= brins.size() * int(o.reste):
				break
			var q: Vector2 = brins[i]
			for k in 3:
				var g := q + Vector2((k - 1) * 0.5, k * 0.9 - 0.4)
				p.disque(g, 0.95, 0.85, Color(ENCRE, 0.5))
				p.disque(g, 0.7, 0.6, fleur.lightened(0.15))


# -- la liane --

# une liane : enroulée autour d'un vieux fût mort, penché, dont l'écorce part ; ses tours passent devant puis derrière ; ses
# feuilles en cœur, peintes en feuillage ; au sommet, des brins qui retombent dans le vide avec leurs petites feuilles ; des
# trompettes pâles si Orvane la dit mellifère
static func liane(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var bois := P.TERRE.lerp(P.CENDRE, 0.35)
	var pied := Vector2(r.randf_range(-2.0, 2.0), 0.5)
	var sens := 1.0 if int(o.graine) % 2 == 0 else -1.0
	var tete := Vector2(r.randf_range(3.0, 7.0) * sens, -h)
	T.assise(p, Vector2(0, 1.2), 8.0, 2.6, P.TERRE.darkened(0.3), 0.4)
	# le fût mort : cassé en haut, fendu
	var axe := T.courbe(pied, pied.lerp(tete, 0.5) + Vector2(1.0, 0), tete, 8)
	var rayons := PackedFloat32Array()
	for k in axe.size():
		rayons.append(lerpf(2.7, 1.5, float(k) / (axe.size() - 1)))
	var tb := T.tube(p, axe, rayons, bois, Pinceau.ECORCE, 1, 0.0, false)
	T.cerner_tube(p, tb, 0.9, 1.5)
	p.tracer(PackedVector2Array([tete + Vector2(-1.4, 0.4), tete + Vector2(-0.4, -2.6), tete + Vector2(0.3, -0.6), tete + Vector2(1.3, -3.2), tete + Vector2(1.5, 0.4)]), 1.1, ENCRE, false)
	p.tracer(PackedVector2Array([axe[2] + Vector2(0.4, 0), axe[4] + Vector2(0.2, 0)]), 0.6, Color(ENCRE, 0.6))
	# la liane : sa spirale (les tours de derrière ne se voient pas)
	var vigne := P.MOUSSE.lerp(P.TERRE, 0.3)
	var spi := PackedVector2Array()
	var tours := 3.4
	for k in 34:
		var u := k / 33.0
		var q := pied.lerp(tete, u)
		spi.append(q + Vector2(sin(u * TAU * tours) * 4.4, cos(u * TAU * tours) * 1.3))
	var morceau := PackedVector2Array()
	for k in 34:
		var devant := cos((k / 33.0) * TAU * tours) > -0.25
		if devant:
			morceau.append(spi[k])
		if (not devant or k == 33) and morceau.size() >= 2:
			p.tracer(morceau, 1.9, ENCRE, false)
			p.tracer(morceau, 1.1, vigne, false)
			morceau = PackedVector2Array()
		elif not devant:
			morceau = PackedVector2Array()
	var t: Color = T.feuillage(o, o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1))
	# (au sommet : des brins qui retombent, leurs petites feuilles)
	for i in r.randi_range(3, 4):
		var q0 := tete + Vector2(r.randf_range(-3.0, 3.0), r.randf_range(-1.0, 3.0))
		var bas := q0 + Vector2(sens * r.randf_range(4.0, 10.0) * (1.0 if i % 2 == 0 else -0.6), r.randf_range(9.0, 17.0))
		var brin := T.courbe(q0, Vector2(bas.x, q0.y - 1.0), bas, 6)
		p.tracer(brin, 1.3, ENCRE, false)
		p.tracer(brin, 0.6, vigne.lightened(0.1), false)
		if o.reste > 0:
			for k in range(2, 7):
				var cote := -1.0 if k % 2 == 0 else 1.0
				T.feuille(p, brin[k], brin[k] + Vector2(cote * 2.6, 2.2), 1.3, t.lightened(0.06), 0.0, 0.42, 0.5, 3)
	var feuilles: int = 15 * maxi(int(o.reste), 1) / maxi(1, int(o.plein)) if o.reste > 0 else 4
	var places := []
	for i in feuilles:
		var k := r.randi_range(2, 33)
		places.append(spi[k] + Vector2(r.randf_range(-2.4, 2.4), r.randf_range(-1.0, 1.0)))
	places.sort_custom(func(u, v): return u.y < v.y)
	for q in places:
		coeur(p, q, r.randf_range(2.6, 3.6), r.randf_range(-0.6, 0.6), t.lightened(r.randf_range(0.0, 0.12)))
	if T.enneigee(o):
		p.tracer(PackedVector2Array([tete + Vector2(-2.0, -1.6), tete + Vector2(0.0, -2.6), tete + Vector2(2.0, -1.8)]), 2.4, P.PAPIER.lightened(0.3))
	if T.a(o, "mellifere") and o.reste > 0 and not Flore.SANS_FLEURS.has(str(o.stade).to_lower()):
		# (ses trompettes : pâles, la gorge jaune)
		var pale := P.PAPIER.lerp(P.AUBE, 0.3)
		for i in 5:
			var q: Vector2 = spi[r.randi_range(6, 31)] + Vector2(r.randf_range(-3.0, 3.0), r.randf_range(-1.0, 1.5))
			var cloche := PackedVector2Array([q + Vector2(-0.6, -1.6), q + Vector2(-2.0, 1.2), q + Vector2(0.0, 2.0), q + Vector2(2.0, 1.2), q + Vector2(0.6, -1.6)])
			p.aplat(T.grossi(cloche, q, 0.55), ENCRE)
			p.aplat(cloche, pale, Pinceau.DOME, q, Vector2(2.2, 2.2))
			p.disque(q + Vector2(0.0, 1.0), 0.6, 0.45, P.BRAISE_COEUR)


# une feuille en cœur, sa pointe vers ang ; sa nervure
static func coeur(p, q: Vector2, s: float, ang: float, c: Color) -> void:
	var poly := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var rr := s * (0.75 + 0.25 * cos(a)) * (1.0 - 0.35 * pow(maxf(0.0, -cos(a)), 6.0))
		poly.append(q + Vector2(cos(a) * rr, sin(a) * rr * 0.8).rotated(ang + PI * 0.5))
	p.aplat(T.grossi(poly, q, 0.7), ENCRE)
	p.aplat(poly, c, Pinceau.FEUILLAGE, q, Vector2(s, s) * 1.1)
	var d := Vector2.from_angle(ang + PI * 0.5)
	p.tracer(PackedVector2Array([q - d * s * 0.5, q + d * s * 0.8]), 0.4, Color(ENCRE, 0.4), false)
