extends RefCounted
# Lisière — les cicatrices de la Noire (scripts/noire_cicatrices.gd)
# Chaque nuit où on l'a prise au collet et blessée (scripts/noire_collet.gd), elle en garde une : une balafre sans poil, pâle,
# que son dessin porte ensuite (scripts/noire_corps.gd l'appelle, calque par calque) et que le feu accroche.
#  - la première : en travers de l'épaule, là où la lance l'a prise au bout de son élan ; et l'anneau du nœud, pelé, au
#    canon de sa patte de devant ;
#  - la deuxième : longue, sur les côtes ; elle boite dès lors de la patte prise (scripts/bete.gd) ;
#  - la troisième : en travers du chanfrein, devant l'œil. On ne la lui voit qu'en portrait : cette nuit-là, elle part.
# Leur nombre est dans le plan de sa lignée (« cicatrices » : scripts/noire.gd, lignee_a). Rien ici ne touche au hasard de sa
# planche : son poil reste le même d'une cicatrice à l'autre, elles s'y ajoutent.

const Planche := preload("res://scripts/bestiaire_planche.gd")
const Pal := preload("res://scripts/palette.gd")


# combien elle en porte, sur cette planche
static func nombre(p: Planche) -> int:
	return clampi(int(p.plan.get("cicatrices", 0)), 0, 3)


# la peau refaite : un ivoire à peine rosé, terni
static func _pale() -> Color:
	return Pal.IVOIRE.lerp(Pal.SANG, 0.14).darkened(0.1)


# une balafre de a à b, large de w en son milieu : la peau pelée autour (un halo gris), la cicatrice pâle, effilée aux deux
# bouts, un peu tordue ; son bourrelet, d'un trait d'encre du côté de l'ombre ; deux ou trois points où le poil n'a pas repris
static func balafre(p: Planche, a: Vector2, b: Vector2, w: float, graine: int) -> void:
	var T: Dictionary = p.tons
	var r := RandomNumberGenerator.new()
	r.seed = 7919 * graine + 13
	var n := 9
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	if nrm.y < 0.0:
		nrm = -nrm
	var long := a.distance_to(b)
	var axe := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		axe.append(a.lerp(b, t) + nrm * long * 0.035 * sin(t * PI * 1.6 + r.randf() * 0.6) + nrm * r.randf_range(-0.25, 0.25) * w)
	var lentille := func(k: float) -> String:
		var haut := PackedVector2Array()
		var bas := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			var e := w * k * pow(sin(PI * clampf(t, 0.02, 0.98)), 0.6) * 0.5
			haut.append(axe[i] - nrm * e)
			bas.append(axe[i] + nrm * e)
		bas.reverse()
		return Planche.ferme(haut + bas, 0.7)
	# (le poil ne repousse pas autour : la peau, grise, se voit)
	p.aplat(lentille.call(2.3), T["accent"].lerp(_pale(), 0.3), 0.6)
	p.aplat(lentille.call(1.0), _pale(), 0.96)
	# (son bourrelet, côté ombre ; un fil de lumière de l'autre)
	var ombre := PackedVector2Array()
	var clair := PackedVector2Array()
	for i in range(1, n):
		var e := w * pow(sin(PI * float(i) / n), 0.6) * 0.5
		ombre.append(axe[i] + nrm * e)
		clair.append(axe[i] - nrm * e * 0.4)
	p.tracer(Planche.ouvert(ombre), maxf(0.5, w * 0.22), T["encre"], 0.75)
	p.tracer(Planche.ouvert(clair), maxf(0.4, w * 0.16), Pal.IVOIRE, 0.5)
	# (les points où la peau a tiré)
	for i in 3:
		var t := r.randf_range(0.18, 0.82)
		var q := a.lerp(b, t) + nrm * w * (1.3 if i % 2 == 0 else -1.3)
		p.aplat(Planche.ferme(Planche.ellipse(q, w * 0.22, w * 0.16, 6, dir.angle()), 1.0), _pale(), 0.7)


# la première : en travers de l'épaule (le calque « dessus », par-dessus l'omoplate)
static func epaule(p: Planche, u: float) -> void:
	if nombre(p) >= 1:
		balafre(p, Vector2(0.108, -0.548) * u, Vector2(0.174, -0.436) * u, 0.0135 * u, 1)


# la deuxième : sur les côtes (le calque « corps »), plus longue
static func flanc(p: Planche, u: float) -> void:
	if nombre(p) >= 2:
		balafre(p, Vector2(-0.078, -0.462) * u, Vector2(0.036, -0.362) * u, 0.0145 * u, 2)


# la troisième : en travers du chanfrein, devant l'œil (le haut de la tête ; hp : un point de la tête, en longueurs de tête)
static func face(p: Planche, hp: Callable, hs: float) -> void:
	if nombre(p) >= 3:
		balafre(p, hp.call(Vector2(0.47, -0.215)), hp.call(Vector2(0.69, 0.03)), 0.05 * hs, 3)


# roulée, endormie : ce qu'on en voit sur son dos rond (l'épaule, les côtes)
static func roulee(p: Planche, u: float) -> void:
	if nombre(p) >= 1:
		balafre(p, Vector2(0.075, -0.262) * u, Vector2(0.15, -0.165) * u, 0.0135 * u, 1)
	if nombre(p) >= 2:
		balafre(p, Vector2(-0.085, -0.25) * u, Vector2(0.01, -0.15) * u, 0.0145 * u, 2)


# l'anneau du nœud, au canon de sa patte de devant : une bague de peau pelée, pâle, en biais. Le morceau de patte est couché
# de (0, 0) à (lg, 0), large de w0 à w1 (scripts/noire_corps.gd, _os) ; rend ce qu'il faut ajouter à son dessin
static func anneau(p: Planche, lg: float, w0: float, w1: float) -> String:
	if nombre(p) < 1:
		return ""
	var x := lg * 0.52
	var r := lerpf(w0, w1, 0.52) * 0.5 + 0.6
	var e := maxf(1.6, lg * 0.085)
	var bague := "M%s L%s L%s L%sZ" % [Planche.pt(Vector2(x - e * 0.5, -r)), Planche.pt(Vector2(x + e * 0.7, -r)), Planche.pt(Vector2(x + e * 0.5, r)), Planche.pt(Vector2(x - e * 0.7, r))]
	var halo := "M%s L%s L%s L%sZ" % [Planche.pt(Vector2(x - e * 1.1, -r)), Planche.pt(Vector2(x + e * 1.3, -r)), Planche.pt(Vector2(x + e * 1.1, r)), Planche.pt(Vector2(x - e * 1.3, r))]
	var T: Dictionary = p.tons
	return "<path d=\"%s\" fill=\"%s\" opacity=\"0.55\"/><path d=\"%s\" fill=\"%s\" opacity=\"0.95\"/>" % [halo, Planche.coul(T["accent"].lerp(_pale(), 0.3)), bague, Planche.coul(_pale())]
