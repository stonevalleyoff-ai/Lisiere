extends RefCounted
# Lisière — le dessin du sol des pays (scripts/biome_dessins.gd)
# Ce que scripts/biome_terrain.gd pose dans le lieu, dessiné à l'encre comme le reste du carnet (DIRECTION-ARTISTIQUE.md) : des
# aplats de la palette, un contour d'encre en quelques traits, la lumière en haut à gauche. Tout passe par le pinceau de
# l'environnement (scripts/decor_pinceau.gd) : un seul tableau de triangles par calque, un appel de dessin.
#  - à plat (le calque du sol) : le sol même (les dunes du désert, leurs rides et leur crête ; les champs de scories du volcan),
#    la fondrière (une vase noire, sa rive de boue, ses lentilles d'eau, ses joncs), la faille (la
#    roche brûlée, la fente, la lave au fond), la fumerolle (une croûte de soufre, un évent), la mare gelée (la glace, ses
#    fêlures, le trou où l'on puise) ;
#  - la lave qui luit (le calque additif) : le cœur des failles ;
#  - debout (au pied, triées avec le lieu) : l'obsidienne, la tourbe, le bois flotté, la carcasse ensablée. Elles maigrissent
#    à mesure qu'on y prend.
# Chaque chose a sa graine : elle se dessine toujours pareil.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")

const VASE := Color("1d1c19")
const ENCRE_LEGERE := Color(0.086, 0.075, 0.059, 0.55)


# le rayon d'une fondrière dans cette direction (les mêmes rayons que scripts/biome_terrain.gd lit pour l'eau)
static func rayon_de(s: Dictionary, a: float) -> float:
	var rs: PackedFloat32Array = s["rayons"]
	var n := rs.size()
	var u := fposmod(a, TAU) / TAU * n
	var i := int(u) % n
	return lerpf(rs[i], rs[(i + 1) % n], u - floorf(u))


static func _bord(s: Dictionary, k: float, n: int = 28) -> PackedVector2Array:
	var c: Vector2 = s["p"]
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		# (vue de trois quarts : un peu écrasée)
		out.append(c + Vector2(cos(a), sin(a) * 0.82) * rayon_de(s, a) * k)
	return out


# --- à plat ---

static func a_plat(p, s: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(s["graine"])
	match str(s["genre"]):
		"dune":
			_dune(p, s, r)
		"scories":
			_scories(p, s, r)
		"fondriere":
			_fondriere(p, s, r)
		"faille":
			_faille(p, s, r)
		"fumerolle":
			_fumerolle(p, s, r)
		"mare":
			_mare(p, s, r)


static func _fondriere(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var c: Vector2 = s["p"]
	var boue := P.TERRE.lerp(P.ENCRE_DOUCE, 0.45)
	# la rive : une boue luisante qui déborde, puis l'eau noire, plus noire au fond
	p.aplat(_bord(s, 1.22), Color(boue, 0.82))
	p.aplat(_bord(s, 1.08), boue.darkened(0.2))
	var eau := VASE.lerp(P.NUIT_BLEUE, 0.35)
	p.aplat(_bord(s, 1.0), eau)
	p.aplat(_bord(s, 0.62), VASE.lerp(P.NUIT, 0.4))
	# (le ciel s'y mire, en haut à gauche : deux ou trois traits pâles)
	var rr: float = s["taille"]
	for i in 3:
		var q := c + Vector2(r.randf_range(-0.55, -0.1), r.randf_range(-0.5, -0.15)) * rr
		var l := r.randf_range(0.18, 0.32) * rr
		p.tracer(PackedVector2Array([q, q + Vector2(l, -l * 0.12)]), r.randf_range(1.2, 2.2), Color(P.LUNE.lerp(P.PAPIER, 0.4), 0.32))
	# les lentilles d'eau, près du bord ; quelques bulles
	var lentille := P.MOUSSE.lerp(P.PAPIER, 0.18)
	for i in r.randi_range(9, 16):
		var a := r.randf() * TAU
		var q := c + Vector2(cos(a), sin(a) * 0.82) * rayon_de(s, a) * r.randf_range(0.7, 0.95)
		p.disque(q, r.randf_range(1.2, 2.6), r.randf_range(0.9, 1.8), Color(lentille, 0.85))
	for i in r.randi_range(2, 4):
		var q := c + Vector2(r.randf_range(-0.5, 0.5), r.randf_range(-0.4, 0.4)) * rr
		var b := r.randf_range(1.6, 3.2)
		p.tracer(_arc(q, b, b * 0.7, PI * 1.1, PI * 1.9, 6), 0.8, Color(P.LUNE.lerp(P.PAPIER, 0.5), 0.45), false)
	# l'encre : la ligne de l'eau, en quelques traits ; la rive, plus légère
	p.contour(_bord(s, 1.0, 22), 1.5, P.ENCRE, r, 3)
	p.contour(_bord(s, 1.22, 22), 0.8, ENCRE_LEGERE, r, 4)
	# des joncs, des touffes sur la rive (du côté de l'ombre, plus serrés)
	for i in r.randi_range(5, 9):
		var a := r.randf_range(-0.3, PI + 0.3) if r.randf() < 0.7 else r.randf() * TAU
		var pied := c + Vector2(cos(a), sin(a) * 0.82) * rayon_de(s, a) * r.randf_range(1.05, 1.25)
		var vert := P.FEUILLE_SOMBRE.lerp(P.MOUSSE, r.randf_range(0.2, 0.7))
		for k in r.randi_range(2, 4):
			var h := r.randf_range(7.0, 15.0)
			var penche := r.randf_range(-4.0, 4.0)
			p.tracer(PackedVector2Array([pied + Vector2(k * 1.6, 0), pied + Vector2(k * 1.6 + penche * 0.5, -h * 0.55), pied + Vector2(k * 1.6 + penche, -h)]),
				1.4, vert)


static func _faille(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var t: PackedVector2Array = s["trait"]
	var l: float = s["large"]
	# la roche brûlée autour : un lavis de cendre
	p.tracer(t, l * 6.0, Color(P.CENDRE, 0.42), true)
	p.tracer(t, l * 3.6, Color(P.CENDRE.lerp(P.ENCRE, 0.4), 0.55), true)
	# la fente : ses deux lèvres
	var bords := _levres(t, l)
	p.aplat(bords, P.ENCRE.lerp(P.CENDRE, 0.25))
	# la lave au fond (le jour aussi : le calque additif ne fait que la faire luire)
	p.tracer(t, l * 1.1, P.BRAISE_ROUGE.lerp(P.BRAISE, 0.3), true)
	p.tracer(t, l * 0.4, P.BRAISE_COEUR, true)
	# l'encre : les deux lèvres, des fentes qui partent de côté
	var n := t.size()
	var g := PackedVector2Array()
	var d := PackedVector2Array()
	for i in n:
		g.append(bords[i])
		d.append(bords[2 * n - 1 - i])
	p.tracer(g, 1.4, P.ENCRE)
	p.tracer(d, 1.6, P.ENCRE)
	for i in r.randi_range(3, 6):
		var k := r.randi_range(1, n - 2)
		var dir := (t[k + 1] - t[k - 1]).normalized().orthogonal() * (1.0 if r.randf() < 0.5 else -1.0)
		var q := t[k] + dir * l * 0.8
		var bout := q + dir.rotated(r.randf_range(-0.6, 0.6)) * r.randf_range(10.0, 26.0)
		p.tracer(PackedVector2Array([q, (q + bout) * 0.5 + dir.orthogonal() * r.randf_range(-3.0, 3.0), bout]), 1.1, Color(P.ENCRE, 0.8))
		p.tracer(PackedVector2Array([q, q.lerp(bout, 0.45)]), 0.9, Color(P.BRAISE, 0.7))


# les deux lèvres d'une fente, de largeur l au milieu, fines aux bouts : un polygone (l'aller sur un bord, le retour sur l'autre)
static func _levres(t: PackedVector2Array, l: float) -> PackedVector2Array:
	var n := t.size()
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in n:
		var dir := (t[mini(i + 1, n - 1)] - t[maxi(i - 1, 0)]).normalized()
		var w := l * (0.25 + 0.75 * sin(PI * float(i) / (n - 1)))
		a.append(t[i] + dir.orthogonal() * w)
		b.append(t[i] - dir.orthogonal() * w)
	b.reverse()
	a.append_array(b)
	return a


static func _fumerolle(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var c: Vector2 = s["p"]
	# la croûte de soufre : jaune pâle, tachée, un peu plus large que l'évent
	var dedans := PackedFloat32Array()
	var dehors := PackedFloat32Array()
	for i in 16:
		var k := r.randf_range(0.8, 1.15)
		dedans.append(26.0 * k)
		dehors.append(46.0 * k)
	var soufre := P.BRAISE_COEUR.lerp(P.IVOIRE, 0.22)
	# (la roche cuite autour, puis la croûte de soufre, qui s'efface sur ses bords)
	tache(p, c, PackedFloat32Array(Array(dehors).map(func(x): return x * 1.25)), PackedFloat32Array(Array(dehors).map(func(x): return x * 1.7)), Color(P.CENDRE, 0.4), 0.72)
	tache(p, c, dedans, dehors, Color(soufre, 0.9), 0.78)
	for i in r.randi_range(9, 15):
		var q := c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(10.0, 36.0) * Vector2(1.0, 0.78)
		p.disque(q, r.randf_range(1.5, 4.0), r.randf_range(1.0, 2.6), Color(soufre.lerp(P.BRAISE, r.randf_range(0.2, 0.5)), 0.8))
	var croute := PackedVector2Array()
	for i in 16:
		croute.append(c + Vector2(cos(TAU * i / 16.0), sin(TAU * i / 16.0) * 0.78) * dedans[i])
	# l'évent : une butte de cendre, son trou
	p.disque(c, 15.0, 9.5, P.CENDRE.lerp(P.IVOIRE, 0.2))
	p.disque(c + Vector2(-3.0, -2.0), 9.0, 4.5, Color(P.IVOIRE, 0.25))
	p.disque(c + Vector2(0.0, 0.5), 7.0, 4.0, P.ENCRE)
	p.contour(Pinceau.ellipse(c, 15.0, 9.5, 18), 1.3, P.ENCRE, r, 3)
	p.contour(croute, 0.7, ENCRE_LEGERE, r, 3)


static func _mare(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var c: Vector2 = s["p"]
	var rr: float = s["taille"]
	var glace := P.LUNE.lerp(P.ECHO, 0.35).lerp(P.PAPIER, 0.25)
	# la neige soufflée sur le bord, la glace (bleue au fond, plus claire en haut à gauche), un reflet du ciel
	p.disque(c, rr * 1.14, rr * 0.72, Color(P.PAPIER.lightened(0.3), 0.7))
	p.disque(c, rr, rr * 0.62, glace)
	p.disque(c + Vector2(rr * 0.12, rr * 0.08), rr * 0.72, rr * 0.4, glace.darkened(0.12))
	p.disque(c + Vector2(-rr * 0.28, -rr * 0.16), rr * 0.5, rr * 0.24, Color(P.PAPIER.lightened(0.4), 0.6))
	for i in 2:
		var q := c + Vector2(-rr * (0.55 - 0.18 * i), -rr * (0.2 - 0.1 * i))
		p.tracer(PackedVector2Array([q, q + Vector2(rr * 0.4, -rr * 0.12)]), 1.6, Color(P.PAPIER.lightened(0.5), 0.9))
	# des fêlures, d'un point
	var o := c + Vector2(r.randf_range(-0.3, 0.3), r.randf_range(-0.2, 0.2)) * rr
	for i in r.randi_range(4, 6):
		var a := r.randf() * TAU
		var q := o
		var ligne := PackedVector2Array([q])
		for k in 3:
			q += Vector2.from_angle(a + r.randf_range(-0.5, 0.5)) * rr * r.randf_range(0.15, 0.3) * Vector2(1.0, 0.62)
			ligne.append(q)
		p.tracer(ligne, 0.8, Color(P.NUIT_BLEUE, 0.5))
	# le trou où l'on puise : l'eau noire sous la glace
	var trou := c + Vector2(rr * 0.25, rr * 0.1)
	p.disque(trou, rr * 0.22, rr * 0.13, P.NUIT_BLEUE.lerp(P.NUIT, 0.4))
	p.contour(Pinceau.ellipse(trou, rr * 0.22, rr * 0.13, 12), 0.9, P.ENCRE, r, 2)
	p.contour(Pinceau.ellipse(c, rr, rr * 0.62, 22), 1.2, Color(P.NUIT_BLEUE.lerp(P.ENCRE, 0.5), 0.9), r, 3)


static func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := lerpf(a0, a1, float(i) / (n - 1))
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


# --- la lave qui luit (additif) : force, de 0 à 1, bat lentement ---

static func lave(p, s: Dictionary) -> void:
	var t: PackedVector2Array = s["trait"]
	var l: float = s["large"]
	p.tracer(t, l * 5.0, Color(P.BRAISE_ROUGE, 0.16), true)
	p.tracer(t, l * 2.2, Color(P.BRAISE, 0.3), true)
	p.tracer(t, l * 0.7, Color(P.BRAISE_COEUR, 0.55), true)


# --- debout : au pied (0, 0), ce qui reste (de 0 à plein) ---

static func debout(p, s: Dictionary, reste: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(s["graine"])
	var plein: int = int(s.get("plein", 3))
	var k := clampf(float(reste) / maxf(1.0, plein), 0.0, 1.0)
	match str(s["genre"]):
		"obsidienne":
			_obsidienne(p, r, k)
		"tourbe":
			_tourbe(p, r, k)
		"bois_flotte":
			_bois_flotte(p, r, k)
		"carcasse":
			_carcasse(p, r, k)


static func _ombre(p, rx: float, ry: float) -> void:
	p.eventail(Vector2(3.0, 1.0), rx, ry, Color(P.NUIT, 0.32), Color(P.NUIT, 0.0), 16)


static func _obsidienne(p, r: RandomNumberGenerator, k: float) -> void:
	_ombre(p, 24.0, 8.0)
	var noir := P.ENCRE.lerp(P.NUIT_BLEUE, 0.45)
	var face := P.NUIT_BLEUE.lerp(P.LUNE, 0.35)
	# (des éclats de verre noir, dressés, penchés ; il en reste moins à mesure qu'on en taille)
	var n := maxi(1, int(round(5.0 * k)))
	if k <= 0.0:
		for i in 4:
			var q := Vector2(r.randf_range(-12.0, 12.0), r.randf_range(-2.0, 3.0))
			p.disque(q, r.randf_range(2.0, 3.5), r.randf_range(1.2, 2.0), noir)
		return
	var places := [Vector2(-4.0, 0.0), Vector2(8.0, 2.0), Vector2(-13.0, 2.0), Vector2(14.0, -1.0), Vector2(1.0, 3.0)]
	var hauts := [30.0, 22.0, 17.0, 14.0, 11.0]
	for i in n:
		var pied: Vector2 = places[i]
		var h: float = hauts[i] * r.randf_range(0.85, 1.15)
		var w := h * r.randf_range(0.28, 0.4)
		var penche := r.randf_range(-0.35, 0.35)
		var pointe := pied + Vector2(sin(penche) * h, -cos(penche) * h)
		var g := pied + Vector2(-w, 0.0)
		var d := pied + Vector2(w * 0.9, 1.0)
		var milieu := pied.lerp(pointe, 0.55) + Vector2(-w * 0.15, 0.0)
		# (deux faces : l'une prend la lumière, l'autre pas)
		p.aplat(PackedVector2Array([g, milieu, pointe, pied + Vector2(-w * 0.1, 1.5)]), face)
		p.aplat(PackedVector2Array([pied + Vector2(-w * 0.1, 1.5), pointe, d]), noir)
		p.tracer(PackedVector2Array([g.lerp(milieu, 0.3), milieu.lerp(pointe, 0.7)]), 1.2, Color(P.PAPIER, 0.75))
		p.contour(PackedVector2Array([g, milieu, pointe, d]), 1.3, P.ENCRE, r, 2)


static func _tourbe(p, r: RandomNumberGenerator, k: float) -> void:
	_ombre(p, 30.0, 9.0)
	var brun := P.TERRE.darkened(0.5)
	var coupe := P.TERRE.darkened(0.28)
	# le banc : des mottes taillées, en deux rangs ; il en reste moins à mesure
	var n := int(round(5.0 * k))
	var mottes := [[-14.0, 0.0], [0.0, 1.0], [14.0, 0.0], [-7.0, -9.0], [7.0, -9.0]]
	if n <= 0:
		p.aplat(Pinceau.ellipse(Vector2(0, -1), 24.0, 6.0, 16), P.TERRE.darkened(0.35))
		p.contour(Pinceau.ellipse(Vector2(0, -1), 24.0, 6.0, 16), 1.0, Color(P.ENCRE, 0.7), r, 3)
		return
	for i in n:
		var m: Array = mottes[i]
		var o := Vector2(float(m[0]), float(m[1]))
		var w := r.randf_range(6.0, 7.5)
		var h := r.randf_range(8.0, 10.0)
		var dessus := PackedVector2Array([o + Vector2(-w, -h), o + Vector2(w, -h - 1.0), o + Vector2(w + 3.0, -h - 4.0), o + Vector2(-w + 3.0, -h - 3.5)])
		var devant := PackedVector2Array([o + Vector2(-w, 0.0), o + Vector2(w, 0.0), o + Vector2(w, -h - 1.0), o + Vector2(-w, -h)])
		p.aplat(devant, coupe)
		p.aplat(dessus, P.MOUSSE.lerp(brun, 0.45))
		# (les fibres de la tourbe, sur la coupe)
		for f in 3:
			var y := -h * r.randf_range(0.2, 0.85)
			p.tracer(PackedVector2Array([o + Vector2(-w + 1.0, y), o + Vector2(w - 1.0, y + r.randf_range(-1.2, 1.2))]), 0.6, Color(P.FAIM.lerp(P.TERRE, 0.3), 0.6), false)
		p.contour(PackedVector2Array([o + Vector2(-w, 0.0), o + Vector2(w, 0.0), o + Vector2(w + 3.0, -h - 4.0), o + Vector2(-w + 3.0, -h - 3.5), o + Vector2(-w, -h)]),
			1.2, P.ENCRE, r, 2)


static func _bois_flotte(p, r: RandomNumberGenerator, k: float) -> void:
	_ombre(p, 32.0, 8.0)
	var gris := P.IVOIRE.lerp(P.CENDRE, 0.22)
	var n := maxi(0, int(round(3.0 * k)))
	if n <= 0:
		for i in 4:
			var q := Vector2(r.randf_range(-16.0, 16.0), r.randf_range(-2.0, 2.0))
			p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(4.0, 8.0), r.randf_range(-1.0, 1.0))]), 1.6, gris.darkened(0.2))
		return
	for i in n:
		# (un tronc tordu, couché, écorcé par la mer, blanchi par le sel)
		var a := r.randf_range(-0.35, 0.35) + (0.5 if i == 1 else 0.0)
		var l := r.randf_range(36.0, 52.0) * (1.0 - 0.18 * i)
		var dir := Vector2.from_angle(a)
		var o := Vector2(r.randf_range(-6.0, 6.0), -float(i) * 4.5)
		var ligne := PackedVector2Array()
		for j in 6:
			var u := float(j) / 5.0 - 0.5
			ligne.append(o + dir * l * u + dir.orthogonal() * sin(u * 5.0 + i) * 2.5)
		var w := r.randf_range(5.5, 7.5)
		p.tracer(ligne, w + 2.6, P.ENCRE, false)
		p.tracer(ligne, w, gris, false)
		var haut := PackedVector2Array()
		for q in ligne:
			haut.append(q + Vector2(0.0, -w * 0.22))
		p.tracer(haut, w * 0.35, P.PAPIER.lightened(0.15), true)
		# (le grain, un nœud)
		p.tracer(PackedVector2Array([ligne[1] + Vector2(0, 1), ligne[3] + Vector2(0, 1.4)]), 0.6, Color(P.ENCRE, 0.5))
		var noeud := ligne[r.randi_range(2, 3)]
		p.disque(noeud, 1.8, 1.2, P.CENDRE)
	# (la neige posée dessus)
	p.disque(Vector2(-4.0, -float(n) * 4.5 - 2.0), 10.0, 2.2, Color(P.PAPIER.lightened(0.3), 0.85))


static func _carcasse(p, r: RandomNumberGenerator, k: float) -> void:
	_ombre(p, 34.0, 9.0)
	var sable := P.IVOIRE.lerp(P.FAIM, 0.35)
	var rouille := P.ECHARPE.lerp(P.TERRE, 0.25)
	var n := int(round(4.0 * k))
	# (ce qui dépasse du sable : les arceaux d'un vieux chariot, une roue cerclée de fer ; il en reste moins à mesure)
	if n >= 1:
		var c := Vector2(13.0, -7.0)
		p.tracer(_arc(c, 13.0, 12.0, PI * 0.95, PI * 2.05, 14), 5.2, P.ENCRE, false)
		p.tracer(_arc(c, 13.0, 12.0, PI * 0.95, PI * 2.05, 14), 3.2, rouille, false)
		for a in [PI * 1.25, PI * 1.5, PI * 1.75]:
			p.tracer(PackedVector2Array([c, c + Vector2(cos(a) * 12.0, sin(a) * 11.0)]), 1.5, rouille.darkened(0.2))
	for i in range(1, mini(n, 4)):
		var x := -22.0 + 9.0 * i
		var h := r.randf_range(14.0, 22.0)
		var arceau := PackedVector2Array([Vector2(x - 4.0, 0.0), Vector2(x - 3.0, -h * 0.7), Vector2(x + 1.0, -h), Vector2(x + 4.0, -h * 0.75)])
		p.tracer(arceau, 4.2, P.ENCRE, false)
		p.tracer(arceau, 2.4, rouille.lerp(P.BRAISE_ROUGE, r.randf_range(0.0, 0.25)), false)
	# le sable qui l'a recouverte : une dune basse par-dessus le pied
	var dune := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		dune.append(Vector2(-cos(a) * 34.0, -sin(a) * 6.5 + 2.0))
	dune.append(Vector2(30.0, 4.0))
	dune.append(Vector2(-30.0, 4.0))
	p.aplat(dune, sable)
	p.tracer(PackedVector2Array([Vector2(-26.0, -1.0), Vector2(-8.0, -5.0), Vector2(10.0, -4.0), Vector2(27.0, 0.0)]), 1.1, Color(P.ENCRE, 0.55))
	p.tracer(PackedVector2Array([Vector2(-14.0, 1.0), Vector2(2.0, -1.5), Vector2(16.0, 1.0)]), 0.7, Color(P.TERRE, 0.5))


# une tache au bord adouci : un cœur plein (rayons « dedans ») qui s'efface jusqu'aux rayons « dehors » ; vue de trois quarts
static func tache(p, c: Vector2, dedans: PackedFloat32Array, dehors: PackedFloat32Array, couleur: Color, ecrase: float = 0.82) -> void:
	var n := dedans.size()
	var coeur := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		coeur.append(c + Vector2(cos(a), sin(a) * ecrase) * dedans[i])
	p.aplat(coeur, couleur)
	var base: int = p.pts.size()
	var nu := Color(couleur.r, couleur.g, couleur.b, 0.0)
	for i in n:
		var a := TAU * i / n
		p.pts.append(coeur[i])
		p.pts.append(c + Vector2(cos(a), sin(a) * ecrase) * dehors[i])
		p.cols.append(couleur)
		p.cols.append(nu)
		p.uvs.append(Vector2.ZERO)
		p.uvs.append(Vector2.ZERO)
	for i in n:
		var k := base + i * 2
		var l := base + ((i + 1) % n) * 2
		p.idx.append_array([k, k + 1, l, k + 1, l + 1, l])


# le bord d'une tache (une dune, des scories), à la façon d'une fondrière : ses rayons, multipliés
static func _rayons(s: Dictionary, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for x in s["rayons"]:
		out.append(float(x) * k)
	return out


# une dune : du sable clair qui recouvre la terre craquelée, ses rides couchées par le vent, sa crête et son versant à l'ombre
static func _dune(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var c: Vector2 = s["p"]
	var sable := P.IVOIRE.lerp(P.FAIM, 0.28).lightened(0.06)
	tache(p, c, _rayons(s, 0.86), _rayons(s, 1.0), sable, 0.62)
	tache(p, c, _rayons(s, 0.45), _rayons(s, 0.72), sable.lightened(0.07), 0.62)
	# (le vent couche les rides en travers de son souffle)
	var a := float(s.get("angle", 0.0))
	var long := Vector2.from_angle(a + PI * 0.5)
	var travers := Vector2.from_angle(a)
	var rr: float = s["taille"]
	var n := int(rr / 16.0)
	for i in n:
		var u := (float(i) / (n - 1) - 0.5) * 1.5
		var demi := sqrt(maxf(0.0, 1.0 - u * u)) * 0.6
		if demi < 0.12:
			continue
		var milieu := c + travers * u * rr * 0.62 * Vector2(1.0, 0.62)
		var ligne := PackedVector2Array()
		for j in 7:
			var v := (float(j) / 6.0 - 0.5) * 2.0 * demi
			ligne.append(milieu + (long * v * rr + travers * sin(v * 5.0 + i) * 5.0) * Vector2(1.0, 0.62))
		p.tracer(ligne, 1.3, Color(P.TERRE, 0.38))
		var claire := PackedVector2Array()
		for q in ligne:
			claire.append(q + Vector2(-1.2, -1.8))
		p.tracer(claire, 1.0, Color(P.PAPIER, 0.55))
	# la crête : un trait d'encre courbe ; derrière, le versant à l'ombre
	var crete := PackedVector2Array()
	var cote := PackedVector2Array()
	for j in 9:
		var v := (float(j) / 8.0 - 0.5) * 1.1
		var q := c + (long * v * rr * 0.8 + travers * (rr * 0.12 - absf(v) * rr * 0.18)) * Vector2(1.0, 0.62)
		crete.append(q)
		cote.append(q + travers * rr * 0.16 * (1.0 - absf(v) * 1.4) * Vector2(1.0, 0.62))
	var ombre := crete.duplicate()
	var retour := cote.duplicate()
	retour.reverse()
	ombre.append_array(retour)
	p.aplat(ombre, Color(P.TERRE.lerp(sable, 0.55), 0.55))
	p.tracer(crete, 1.3, Color(P.ENCRE, 0.55))


# des scories : une roche noire, bulleuse, semée de cailloux de lave ; la cendre qui s'y dépose
static func _scories(p, s: Dictionary, r: RandomNumberGenerator) -> void:
	var c: Vector2 = s["p"]
	var noir := P.CENDRE.lerp(P.ENCRE, 0.35)
	tache(p, c, _rayons(s, 0.84), _rayons(s, 1.0), Color(P.CENDRE.lerp(P.IVOIRE, 0.12), 0.75), 0.7)
	tache(p, c, _rayons(s, 0.5), _rayons(s, 0.78), Color(noir, 0.82), 0.7)
	var rr: float = s["taille"]
	# (la cendre qui s'y dépose : des taches pâles)
	for i in int(rr / 12.0):
		var a := r.randf() * TAU
		var q := c + Vector2(cos(a), sin(a) * 0.7) * rayon_de(s, a) * sqrt(r.randf()) * 0.9
		p.disque(q, r.randf_range(3.0, 9.0), r.randf_range(1.5, 4.0), Color(P.IVOIRE.lerp(P.CENDRE, 0.3), 0.3))
	for i in int(rr / 3.5):
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 0.82
		var q := c + Vector2(cos(a), sin(a) * 0.7) * rayon_de(s, a) * d
		var k := r.randf_range(1.6, 4.2)
		p.disque(q, k, k * 0.7, noir.lerp(P.ENCRE, r.randf_range(0.0, 0.5)))
		if r.randf() < 0.4:
			p.disque(q + Vector2(-k * 0.3, -k * 0.3), k * 0.4, k * 0.25, Color(P.IVOIRE, 0.35))
	# (des fentes de refroidissement, à l'encre)
	for i in r.randi_range(3, 6):
		var a := r.randf() * TAU
		var q := c + Vector2(cos(a), sin(a) * 0.7) * rr * r.randf_range(0.1, 0.5)
		var ligne := PackedVector2Array([q])
		for k in 3:
			q += Vector2.from_angle(a + r.randf_range(-0.7, 0.7)) * r.randf_range(10.0, 22.0) * Vector2(1.0, 0.7)
			ligne.append(q)
		p.tracer(ligne, 0.9, Color(P.ENCRE, 0.6))
