extends RefCounted
# Lisière — le trait de la flore (scripts/flore_trait.gd)
# Les gestes que partagent les dessins des plantes (scripts/flore_dessins.gd, flore_arbres.gd, flore_sol.gd), par-dessus le
# pinceau de l'environnement (scripts/decor_pinceau.gd) : ce qui donne aux formes de l'herbier le volume, la lumière et le trait
# des premiers dessins (l'arbre, le sapin, le buisson d'objet.gd).
#  - des volumes peints par le shader de végétation : un tube le long d'un axe (un fût, une canne, une colonne de cactus et ses
#    côtes, un bras qui se coude), son bout rond ; une feuille charnue ;
#  - des feuilles à deux tons (le côté du jour, le côté de l'ombre), leur nervure, leur liseré d'encre ;
#  - l'encre : des hachures courtes là où la forme tourne, des épines, des fissures d'écorce ;
#  - ce que les caractères d'Orvane changent à toutes (a : la plante a-t-elle ce caractère ?).
# Rien ici ne tire de hasard hors du générateur qu'on lui donne : une plante se redessine toujours pareille.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
# d'où vient le jour, sur la feuille (en haut à gauche)
const JOUR := Vector2(-0.62, -0.78)
# ce qu'un volume vertical garde d'ombre : il regarde un peu vers le sol (trois tons en travers, et non deux)
const PENTE := 0.28


# la plante a-t-elle ce caractère d'Orvane ? (« naine », « geante », « echasses », « coriace », « rapide », « vent »…)
static func a(o, caractere: String) -> bool:
	var c = o.get("caracteres")
	return typeof(c) == TYPE_ARRAY and c.has(caractere)


# --- les volumes ---

# une bande entre deux lignes, peinte en volume : xa et xb, de -1 à 1, disent où ses deux bords sont sur le volume (mode : DOME,
# ECORCE…) ; q le décale (la pente du volume, par point : ys)
static func bande_volume(p, ga: PackedVector2Array, dr: PackedVector2Array, c: Color, mode: float, uva: PackedVector2Array, uvb: PackedVector2Array) -> void:
	var n := mini(ga.size(), dr.size())
	if n < 2:
		return
	p._plein()
	var base: int = p.pts.size()
	var m := Vector2(mode, mode)
	for i in n:
		p.pts.append(ga[i])
		p.pts.append(dr[i])
		p.cols.append(c)
		p.cols.append(c)
		p.uvs.append(m + uva[i])
		p.uvs.append(m + uvb[i])
	for i in n - 1:
		var k := base + i * 2
		p.idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])


# un tube le long d'un axe (un fût, une canne, une colonne) : son rayon à chaque point ; cotes : combien de côtes on en voit
# (1 : lisse), relief : ce que chaque côte a de bombé (0,35 : un cactus) ; rond : son bout se ferme en dôme. Peint en dôme lisse
# (ou en écorce : le cylindre et ses fibres). Rend ce qu'il faut pour poser l'encre et les détails : { g, d (ses deux bords),
# axe, nd (la normale, vers la droite de l'axe), r (les rayons), n (les points du fût, sans le dôme) }
static func tube(p, axe_: PackedVector2Array, rayons_: PackedFloat32Array, c: Color, mode := 15.0, cotes := 1, relief := 0.0, rond := true, pente := PENTE) -> Dictionary:
	var axe := PackedVector2Array(axe_)
	var rayons := PackedFloat32Array(rayons_)
	var n0 := axe.size()
	var phis := PackedFloat32Array()
	phis.resize(n0)
	phis.fill(0.0)
	if rond and n0 >= 2:
		# (le dôme : le rayon se ferme en quart de cercle le long de l'axe)
		var t := (axe[n0 - 1] - axe[n0 - 2]).normalized()
		var r0 := rayons[n0 - 1]
		for j in range(1, 5):
			var phi := PI * 0.5 * j / 4.0
			axe.append(axe[n0 - 1] + t * r0 * sin(phi))
			rayons.append(r0 * cos(phi))
			phis.append(phi)
	var n := axe.size()
	var nd := PackedVector2Array()
	var tg := PackedVector2Array()
	for k in n:
		var t := (axe[mini(k + 1, n - 1)] - axe[maxi(k - 1, 0)]).normalized()
		if k >= n0:
			t = tg[n0 - 1]
		tg.append(t)
		nd.append(-t.orthogonal())
	var lignes: Array = []
	for i in cotes + 1:
		var s := sin(-PI * 0.5 + PI * i / cotes)
		var l := PackedVector2Array()
		for k in n:
			l.append(axe[k] + nd[k] * rayons[k] * s)
		lignes.append(l)
	for i in cotes:
		var sa := clampf(sin(-PI * 0.5 + PI * i / cotes) - relief, -0.98, 0.98)
		var sb := clampf(sin(-PI * 0.5 + PI * (i + 1) / cotes) + relief, -0.98, 0.98)
		var uva := PackedVector2Array()
		var uvb := PackedVector2Array()
		for k in n:
			if mode > 9.5 and mode < 12.5:
				# (une écorce : le shader ne lit que le travers)
				uva.append(Vector2(sa, 0.0))
				uvb.append(Vector2(sb, 0.0))
			else:
				var cp := cos(phis[k])
				var long := tg[k] * sin(phis[k]) + Vector2(0.0, pente) * cp
				uva.append(nd[k] * sa * cp + long)
				uvb.append(nd[k] * sb * cp + long)
		bande_volume(p, lignes[i], lignes[i + 1], c, mode, uva, uvb)
	return {"g": lignes[0], "d": lignes[cotes], "axe": axe, "nd": nd, "r": rayons, "n": n0, "lignes": lignes}


# l'encre d'un tube : son bord du côté du jour, fin ; celui de l'ombre, lourd (g et d : ce que rend tube)
static func cerner_tube(p, t: Dictionary, fin := 0.9, lourd := 1.6, c := ENCRE) -> void:
	var g: PackedVector2Array = t["g"]
	var d: PackedVector2Array = t["d"]
	# (lequel des deux bords regarde le jour ?)
	var m := g.size() / 2
	var vers: Vector2 = g[m] - d[m]
	var jour_a_gauche := vers.dot(JOUR) >= 0.0
	p.tracer(g, fin if jour_a_gauche else lourd, c, false)
	p.tracer(d, lourd if jour_a_gauche else fin, c, false)


# un point d'un tube : au rang k de son axe, à s en travers (de -1 à 1)
static func sur_tube(t: Dictionary, k: int, s: float) -> Vector2:
	return t["axe"][k] + t["nd"][k] * float(t["r"][k]) * s


# un triangle d'une couleur (une foliole de palme, une penne de fougère : par centaines, sans triangulation)
static func tri(p, pa: Vector2, pb: Vector2, pc: Vector2, c: Color) -> void:
	p._plein()
	var base: int = p.pts.size()
	p.pts.append(pa)
	p.pts.append(pb)
	p.pts.append(pc)
	for i in 3:
		p.cols.append(c)
		p.uvs.append(Vector2.ZERO)
	p.idx.append_array([base, base + 1, base + 2])


# à partir d'ici, ce qu'on dessine est du feuillage : le feu l'emportera (scripts/objet.gd, _marquer, le cherche au premier aplat
# de feuillage). Des palmes, des frondes faites de traits et de triangles n'en ont pas : ce triangle sans surface le lui dit
static func debut_feuillage(p) -> void:
	var base: int = p.pts.size()
	for i in 3:
		p.pts.append(Vector2.ZERO)
		p.cols.append(Color(0, 0, 0, 0))
		p.uvs.append(Vector2(Pinceau.FEUILLAGE, Pinceau.FEUILLAGE))
	p.idx.append_array([base, base + 1, base + 2])


# une courbe douce par trois points (de a à c, tirée vers b), en n pas
static func courbe(pa: Vector2, pb: Vector2, pc: Vector2, n := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var u := float(k) / n
		out.append(pa.lerp(pb, u).lerp(pb.lerp(pc, u), u))
	return out


# --- les feuilles ---

# une feuille en lance, de a à b : deux tons (le côté du jour, le côté de l'ombre), sa nervure, son liseré d'encre ; pli la
# courbe (en pixels, en travers), ventre dit où elle est la plus large (0,3 : près du pied ; 0,5 : au milieu)
static func feuille(p, pa: Vector2, pb: Vector2, larg: float, c: Color, pli := 0.0, ventre := 0.34, cerne := 0.55, m := 5) -> void:
	var d := pb - pa
	if d.length_squared() < 0.01:
		return
	var nrm := d.orthogonal().normalized()
	var e := log(0.5) / log(clampf(ventre, 0.08, 0.92))
	var axe := PackedVector2Array()
	var g := PackedVector2Array()
	var dr := PackedVector2Array()
	var ge := PackedVector2Array()
	var de := PackedVector2Array()
	for k in m + 1:
		var u := float(k) / m
		var q := pa + d * u + nrm * pli * sin(u * PI)
		var w := larg * pow(sin(PI * pow(u, e)), 0.75)
		var av := d.normalized() * (cerne * (u * 2.0 - 1.0))
		axe.append(q)
		g.append(q + nrm * w)
		dr.append(q - nrm * w)
		ge.append(q + nrm * (w + cerne) + av)
		de.append(q - nrm * (w + cerne) + av)
	if cerne > 0.0:
		p.bande(ge, de, Color(ENCRE, 0.88))
	var jour := nrm.dot(JOUR) >= 0.0
	p.bande(g, axe, c.lightened(0.1) if jour else c.darkened(0.2))
	p.bande(axe, dr, c.darkened(0.2) if jour else c.lightened(0.1))
	if larg >= 1.2:
		p.tracer(axe, 0.45, Color(c.darkened(0.5), 0.7), false, PackedFloat32Array(), false)


# une feuille charnue (une plante grasse, un agave) : la même lance, peinte en volume (elle est épaisse : le jour la modèle),
# cernée d'encre. Rend son axe et ses deux bords (pour ses dents, son dard) : { axe, g, d }
static func feuille_charnue(p, pa: Vector2, pb: Vector2, larg: float, c: Color, pli := 0.0, ventre := 0.34, cerne := 0.7, m := 6, creux := 0.0) -> Dictionary:
	var d := pb - pa
	var axe := PackedVector2Array()
	if d.length_squared() < 0.01:
		return {"axe": axe, "g": axe, "d": axe}
	var nrm := d.orthogonal().normalized()
	var e := log(0.5) / log(clampf(ventre, 0.08, 0.92))
	var g := PackedVector2Array()
	var dr := PackedVector2Array()
	var ge := PackedVector2Array()
	var de := PackedVector2Array()
	var uvg := PackedVector2Array()
	var uva := PackedVector2Array()
	var uvd := PackedVector2Array()
	var uva2 := PackedVector2Array()
	var dir := d.normalized()
	for k in m + 1:
		var u := float(k) / m
		var q := pa + d * u + nrm * pli * sin(u * PI)
		var w := maxf(0.0, larg * pow(sin(PI * pow(u, e)), 0.7))
		var av := dir * (cerne * (u * 2.0 - 1.0))
		axe.append(q)
		g.append(q + nrm * w)
		dr.append(q - nrm * w)
		ge.append(q + nrm * (w + cerne) + av)
		de.append(q - nrm * (w + cerne) + av)
		# (le dessus de la feuille regarde un peu le ciel vers sa pointe)
		var long := Vector2(0.0, 0.2) + dir * (u - 0.4) * 0.35
		uvg.append(nrm * 0.94 + long)
		uvd.append(-nrm * 0.94 + long)
		# (creusée en gouttière : son milieu est dans l'ombre de ses bords)
		uva.append(nrm * -creux + long)
		uva2.append(nrm * creux + long)
	if cerne > 0.0:
		p.bande(ge, de, ENCRE)
	bande_volume(p, g, axe, c, Pinceau.DOME, uvg, uva)
	bande_volume(p, axe, dr, c, Pinceau.DOME, uva2, uvd)
	return {"axe": axe, "g": g, "d": dr}


# un polygone, un peu agrandi depuis son centre (son liseré d'encre, dessous)
static func grossi(poly: PackedVector2Array, centre: Vector2, de: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var d := q - centre
		out.append(q + d.normalized() * de)
	return out


# --- l'encre ---

# des hachures : n traits courts, parallèles, à partir de q, le long de dir, espacés de pas en travers
static func hachures(p, q: Vector2, dir: Vector2, n: int, l: float, pas: float, c := Color(0.086, 0.075, 0.059, 0.5), larg := 0.6) -> void:
	var t := dir.normalized()
	var tr := t.orthogonal()
	for i in n:
		var a0 := q + tr * pas * (i - (n - 1) * 0.5)
		var k := 1.0 - 0.35 * absf(i - (n - 1) * 0.5) / maxf(1.0, n * 0.5)
		p.tracer(PackedVector2Array([a0, a0 + t * l * k]), larg, c)


# une épine : un trait d'encre court, effilé, de q vers dir
static func epine(p, q: Vector2, dir: Vector2, l: float, larg := 0.7, c := ENCRE) -> void:
	p.tracer(PackedVector2Array([q - dir * 0.3, q + dir * l]), larg, c, false, PackedFloat32Array([larg, larg * 0.25]))


# une aréole : une touffe de laine pâle, et ses épines en étoile (un cactus)
static func areole(p, q: Vector2, dehors: Vector2, l: float, laine: Color) -> void:
	for k in 3:
		var dir := dehors.rotated((k - 1) * 0.75).normalized()
		p.tracer(PackedVector2Array([q, q + dir * l]), 0.5, Color(ENCRE, 0.8), false, PackedFloat32Array([0.55, 0.2]))
	p.disque(q, 0.62, 0.55, laine)


# une ombre douce sous un volume (une touffe sur celles de derrière, un chapeau sur son pied)
static func ombre_douce(p, centre: Vector2, rx: float, ry: float, force := 0.3) -> void:
	p.eventail(centre, rx, ry, Color(P.ENCRE, force), Color(P.ENCRE, 0.0), 14)


# de la terre remuée, une tache au pied : la plante est posée dans le sol, pas dessus
static func assise(p, centre: Vector2, rx: float, ry: float, c: Color, force := 0.5) -> void:
	p.eventail(centre, rx, ry, Color(c, force), Color(c, 0.0), 14)


# un caillou, un grain de gravier au pied d'une plante des pays secs
static func gravier(p, q: Vector2, s: float, c: Color) -> void:
	p.disque(q + Vector2(0.3, 0.3), s + 0.45, s * 0.7 + 0.45, Color(ENCRE, 0.8))
	p.disque(q, s, s * 0.7, c, Pinceau.PIERRE)


# --- la neige ---

# de la neige posée sur le haut d'un aplat (un feuillage, un coussin), s'il fait froid dans le lieu de la plante : la part du
# polygone au-dessus d'une ligne tremblée (scripts/objet.gd, _neige_sur). part : ce que la neige en couvre, par grand froid
static func neige(o, p, poly: PackedVector2Array, centre: Vector2, rx: float, ry: float, r: RandomNumberGenerator, part := 0.42) -> void:
	var froid := float(o._climat.get("froid", 0.0))
	if froid <= 0.25:
		return
	var haut := centre.y - ry
	o._neige_sur(p, poly, centre + Vector2(0.0, -ry * 0.55), rx * 0.9, ry * 0.5, haut + ry * 2.0 * lerpf(part * 0.55, part, froid), r)


# fait-il assez froid, là où elle pousse, pour que la neige tienne sur elle ?
static func enneigee(o) -> bool:
	return float(o._climat.get("froid", 0.0)) > 0.25


# un petit tas de neige au pied (une touffe, une tige : la neige ne tient pas dessus, elle s'amasse contre)
static func congere(p, q: Vector2, rx: float, ry: float) -> void:
	var poly := PackedVector2Array()
	for i in 9:
		var ang := PI + PI * i / 8.0
		poly.append(q + Vector2(cos(ang) * rx, sin(ang) * ry))
	poly.append(q + Vector2(rx * 0.6, 0.8))
	poly.append(q + Vector2(-rx * 0.6, 0.8))
	p.aplat(poly, P.PAPIER.lightened(0.3), Pinceau.DOME, q + Vector2(0.0, -ry * 0.3), Vector2(rx, ry) * 1.2)
	var haut := PackedVector2Array()
	for i in 9:
		haut.append(poly[i])
	p.tracer(haut, 0.6, Color(P.NUIT_BLEUE, 0.45), true)


# --- les couleurs ---

# la teinte d'un feuillage d'après ses caractères : coriace, il est plus sombre et plus dense ; rapide, plus tendre
static func feuillage(o, t: Color) -> Color:
	if a(o, "coriace"):
		t = t.darkened(0.1).lerp(P.FEUILLE_SOMBRE, 0.18)
	if a(o, "rapide"):
		t = t.lerp(P.MOUSSE.lightened(0.16), 0.14)
	return t


# le vert d'une plante qui ne suit qu'à peine la teinte du lieu (une plante grasse reste glauque sur la terre sèche), mais que
# le feu roussit comme les autres (scripts/objet.gd, _teinte_roussie)
static func vert_propre(o, c: Color, part := 0.2) -> Color:
	var t: Color = c.lerp(o.teinte, part)
	var roussi := float(o.roussi)
	if roussi > 0.0:
		t = t.lerp(P.TERRE.lerp(P.BRAISE_ROUGE, 0.4), 0.4 + 0.35 * roussi).darkened(0.08 + 0.3 * roussi)
	return t
