extends RefCounted
# Lisière — les planches de l'herbier (scripts/herbier_planches.gd)
# Chaque herbe de scripts/botanique.gd sur sa planche de naturaliste, à l'encre et au lavis sur le papier du carnet : la
# plante entière et sa racine, dessinée en grand ; à côté, dans deux cercles de crayon, ce qu'on regarde à la loupe (la
# fleur ouverte ou le fruit coupé, puis une feuille et ses nervures — ou la tige tranchée, quand c'est elle qui parle :
# rouge sang, ou qui rend son lait) ; le niveau du sol, la cote de sa hauteur, une échelle. Pas un mot : la page écrit.
# Sept dessins, pas trente : les sept formes (FORMES), que l'espèce colore, que son lieu étire ou tasse (le port de
# scripts/herbe.gd) et marque de quelques traits à lui (le givre de la taïga, le luisant du marais, les pointes sèches de
# la lande). Le signe de l'espèce s'y voit : la tige rouge, le duvet d'argent, les abeilles du miel, la goutte de lait.
# Une herbe qu'on a vue pousser sans l'avoir cueillie (connue faux) n'a que sa silhouette, au lavis gris, sans racine.
#   planche(ci, id, rect, signe, connue)       la planche, dans rect (220 × 300 points à peu près)
#   vignette(ci, id, centre, taille, connue)   la même plante en petit (de 28 à 96 points), sans sa racine
# Tout se trace une fois dans un maillage gardé (scripts/interface_trace.gd) : ensuite, une planche est un seul appel.

const P := preload("res://scripts/palette.gd")
const Botanique := preload("res://scripts/botanique.gd")
const Herbe := preload("res://scripts/herbe.gd")
const Trace := preload("res://scripts/interface_trace.gd")

const ARGENT := Color("b4c2cd")          # le duvet, sur le papier : la lune, pâlie
const ROUGE_SANG := Color("a8291f")
const LAIT := Color("fdfaf1")
const RACINE := Color("c7b08a")          # une racine lavée : l'ivoire, tiré vers la terre
const MIEL := Color("d9a441")
const PAILLE := Color("c4a877")
# la boîte de chaque forme, en unités de plante : x de part et d'autre du collet, le haut, le bas de la racine
const BOITES := {"ombelle": [-43.0, 42.0, 106.0, -37.0], "clochette": [-34.0, 50.0, 97.0, -26.0], "epi": [-38.0, 38.0, 109.0, -31.0],
	"rosette": [-45.0, 45.0, 80.0, -56.0], "morelle": [-46.0, 46.0, 100.0, -33.0], "chardon": [-44.0, 44.0, 114.0, -39.0],
	"crosse": [-50.0, 40.0, 103.0, -27.0]}


# la planche d'une herbe, dans rect. signe : ce que son dessin montre de son indice (« rouge », « duvet », « miel », « lait », "")
static func planche(ci: CanvasItem, id: String, rect: Rect2, signe: String, connue: bool) -> void:
	var s := rect.size.round()
	var cle := "herbier|%s|%dx%d|%s|%s" % [id, int(s.x), int(s.y), signe, connue]
	var mesh := Trace.maillage(cle, func(t): _planche(t, id, s, signe, connue))
	ci.draw_mesh(mesh, null, Transform2D(0.0, rect.position.round()))


# la même plante en petit, centrée, sans racine ni détails : pour une tuile de la page ou du sac
static func vignette(ci: CanvasItem, id: String, centre: Vector2, taille: float, connue: bool) -> void:
	if taille < 8.0:
		return
	var signe := Botanique.signe(id)
	var cle := "vignette|%s|%d|%s|%s" % [id, int(round(taille)), signe, connue]
	var mesh := Trace.maillage(cle, func(t): _vignette(t, id, round(taille), signe, connue))
	ci.draw_mesh(mesh, null, Transform2D(0.0, centre.round()))


static func _vignette(t, id: String, taille: float, signe: String, connue: bool) -> void:
	var forme := Botanique.forme_de(id)
	var pl := Plume.new()
	# (le lait ne se voit qu'à la coupe, les abeilles sont trop petites : ici, la tige rouge et le duvet seulement)
	pl.preparer(t, id, signe if signe in ["rouge", "duvet"] else "", 0 if taille < 40.0 else 1, not connue)
	pl.w = 1.0 if taille < 40.0 else 1.1
	var b: Array = BOITES.get(forme, BOITES["ombelle"])
	pl.cadrer(Rect2(-taille * 0.46, -taille * 0.46, taille * 0.92, taille * 0.92), float(b[0]), float(b[1]), float(b[2]), -3.0)
	pl.plante(forme, false)


static func _planche(t, id: String, s: Vector2, signe: String, connue: bool) -> void:
	var forme := Botanique.forme_de(id)
	var pl := Plume.new()
	pl.preparer(t, id, signe, 2, not connue)
	var b: Array = BOITES.get(forme, BOITES["ombelle"])
	var zone := Rect2(s.x * 0.1, s.y * 0.03, s.x * 0.57, s.y * 0.915)
	pl.cadrer(zone, float(b[0]), float(b[1]), float(b[2]), float(b[3]) if connue else -3.0)
	var sol := pl.o.y
	var cime := sol - float(b[2]) * pl.ky * pl.u
	var crayon := Color(P.ENCRE, 0.34)
	var c1 := Vector2(s.x * 0.834, s.y * 0.19)
	var r1 := s.x * 0.152
	var c2 := Vector2(s.x * 0.84, s.y * 0.55)
	var r2 := s.x * 0.14
	# le crayon d'abord : l'axe de la plante, le niveau du sol et sa terre hachée
	Plume.tirets(t, Vector2(zone.position.x - s.x * 0.03, sol), Vector2(zone.end.x + s.x * 0.03, sol), 5.0, 3.0, crayon)
	for i in 5:
		var x := zone.position.x - s.x * 0.03 + 3.0 + i * 4.0
		t.draw_line(Vector2(x, sol + 1.0), Vector2(x - 3.0, sol + 5.0), crayon, 1.0, true)
		var x2 := zone.end.x + s.x * 0.03 - 3.0 - i * 4.0
		t.draw_line(Vector2(x2, sol + 1.0), Vector2(x2 - 3.0, sol + 5.0), crayon, 1.0, true)
	if not connue:
		# on l'a vue pousser, pas davantage : sa silhouette, et deux loupes vides
		pl.plante(forme, false)
		Plume.rond_tirets(t, c1, r1, Color(P.ENCRE, 0.2))
		Plume.rond_tirets(t, c2, r2, Color(P.ENCRE, 0.2))
		return
	t.draw_line(Vector2(pl.o.x, cime - 4.0), Vector2(pl.o.x, sol + 3.0), Color(P.ENCRE, 0.1), 1.0, true)
	pl.plante(forme, true)
	if signe == "lait":
		# (là où on l'a entaillée : une goutte blanche)
		var g: Vector2 = pl.ancres.get("tige", Vector2(pl.o.x, sol - 20.0))
		var goutte := PackedVector2Array([g + Vector2(0.0, -3.4)])
		for i in 11:
			goutte.append(g + Vector2(0.0, 1.0) + Vector2.from_angle(-PI * 0.15 + PI * 1.3 * i / 10.0) * 2.4)
		t.draw_colored_polygon(goutte, LAIT)
		goutte.append(goutte[0])
		t.draw_polyline(goutte, P.ENCRE, 1.0, true)
	if signe == "miel":
		var f: Vector2 = pl.ancres.get("fleur", Vector2(pl.o.x, cime))
		pl.abeille(f + Vector2(s.x * 0.085, -s.y * 0.012), s.x * 0.021, -0.5, true)
		pl.abeille(f + Vector2(-s.x * 0.1, -s.y * 0.05), s.x * 0.017, 2.6, true)
		pl.abeille(f + Vector2(s.x * 0.02, -s.y * 0.075), s.x * 0.014, 0.4, false)
	# la cote de sa hauteur : à gauche, du sol à la cime, graduée ; ses deux lignes de rappel
	var encre_fine := Color(P.ENCRE, 0.62)
	var xc := s.x * 0.05
	t.draw_line(Vector2(xc, sol), Vector2(xc, cime), encre_fine, 1.0, true)
	for y in [sol, cime]:
		t.draw_line(Vector2(xc - 3.5, float(y)), Vector2(xc + 3.5, float(y)), encre_fine, 1.0, true)
		Plume.tirets(t, Vector2(xc + 5.0, float(y)), Vector2(zone.position.x + (2.0 if float(y) == sol else zone.size.x * 0.3), float(y)), 2.0, 3.0, crayon)
	var pas := 10.0 * pl.ky * pl.u
	var k := 1
	while sol - k * pas > cime + 2.0:
		t.draw_line(Vector2(xc, sol - k * pas), Vector2(xc + (3.5 if k % 5 == 0 else 2.0), sol - k * pas), encre_fine, 1.0, true)
		k += 1
	# l'échelle : cinq cases, une sur deux à l'encre (une case : dix unités de plante)
	var pas_e := 10.0 * pl.u
	var e0 := Vector2(minf(s.x * 0.7, s.x * 0.965 - 5.0 * pas_e), s.y * 0.93)
	for i in 5:
		var rc := Rect2(e0.x + i * pas_e, e0.y - 2.0, pas_e, 4.0)
		if i % 2 == 0:
			t.draw_rect(rc, encre_fine)
	t.draw_polyline(PackedVector2Array([e0 + Vector2(0, -2), e0 + Vector2(5.0 * pas_e, -2), e0 + Vector2(5.0 * pas_e, 2), e0 + Vector2(0, 2), e0 + Vector2(0, -2)]), encre_fine, 1.0, true)
	t.draw_line(e0 + Vector2(0, -5), e0 + Vector2(0, 2), encre_fine, 1.0, true)
	t.draw_line(e0 + Vector2(5.0 * pas_e, -5), e0 + Vector2(5.0 * pas_e, 2), encre_fine, 1.0, true)
	# les deux loupes : la fleur ou le fruit ; puis la feuille — ou la tige tranchée, si c'est elle qui parle
	var tige_parle := signe in ["rouge", "lait"]
	var a1: Vector2 = pl.ancres.get("fleur", Vector2(pl.o.x, cime))
	var a2: Vector2 = pl.ancres.get("tige" if tige_parle else "feuille", Vector2(pl.o.x, sol - 20.0))
	for lp in [[c1, r1, a1], [c2, r2, a2]]:
		var c: Vector2 = lp[0]
		var rr := float(lp[1])
		var a: Vector2 = lp[2]
		var d := (a - c).normalized()
		t.draw_arc(c, rr, 0.0, TAU, 56, crayon, 1.0, true)
		t.draw_line(c + d * rr, a - d * 4.0, crayon, 1.0, true)
		t.draw_arc(a, 3.0, 0.0, TAU, 14, encre_fine, 1.0, true)
	var d1 := Plume.new()
	d1.preparer(t, id, signe, 3, false)
	d1.loupe(c1, r1)
	d1.detail_fleur(forme)
	var d2 := Plume.new()
	d2.preparer(t, id, signe, 3, false)
	d2.loupe(c2, r2)
	if tige_parle:
		d2.detail_tige(forme)
	else:
		d2.detail_feuille(forme)


# --- la plume : ce avec quoi une plante se dessine, à une taille et à un degré de détail donnés ---

class Plume extends RefCounted:
	var t                       # où l'on trace (une trace : scripts/interface_trace.gd)
	var o := Vector2.ZERO       # le collet : là où la plante sort de terre
	var u := 1.0                # points par unité de plante
	var kx := 1.0               # le port que le lieu lui donne
	var ky := 1.0
	var sens := 1.0
	var fin := 2                # le détail : 0 (une vignette de 28 points), 1 (une vignette), 2 (la planche), 3 (une loupe)
	var w := 1.15               # l'épaisseur de l'encre
	var lavis := false          # une herbe qu'on ne connaît pas : sa silhouette au lavis gris
	var lieu := "foret"
	var signe := ""
	var etroit := 1.0
	var vert := Color.WHITE
	var clair := Color.WHITE
	var sombre := Color.WHITE
	var tige_c := Color.WHITE
	var fleur := Color.WHITE
	var r := RandomNumberGenerator.new()
	var ancres := {}            # où pointent les loupes : « fleur », « feuille », « tige »
	var nu := false             # ce qu'on dessine n'est pas une feuille (un pétale, une écaille) : ni duvet, ni givre, ni luisant

	func preparer(trace, id: String, signe_: String, fin_: int, lavis_: bool) -> void:
		t = trace
		lieu = Botanique.lieu_de(id)
		signe = signe_
		fin = fin_
		lavis = lavis_
		r.seed = hash(id)
		var po: Dictionary = Herbe.port(lieu)
		var v: Color = po["vert"]
		vert = v.lerp(P.PAPIER, 0.2).lightened(0.1)
		clair = vert.lerp(P.PAPIER, 0.34)
		sombre = vert.darkened(0.22)
		tige_c = vert.lerp(P.IVOIRE, 0.55).lightened(0.06)
		if signe == "rouge":
			tige_c = ROUGE_SANG
		fleur = Botanique.couleur(id)
		if fleur.v > 0.82 and fleur.s < 0.25:
			# (une fleur blanche est plus blanche que le papier)
			fleur = fleur.lerp(Color.WHITE, 0.55)
		kx = lerpf(1.0, float(po["large"]), 0.8)
		ky = lerpf(1.0, float(po["haut"]), 0.6)
		etroit = lerpf(1.0, float(po["fin"]), 0.7)
		sens = 1.0 if hash(id) % 2 == 0 else -1.0

	# tenir toute la plante dans une zone : de x0 à x1, du bas au haut (en unités)
	func cadrer(zone: Rect2, x0: float, x1: float, haut: float, bas: float) -> void:
		u = minf(zone.size.x / ((x1 - x0) * kx), zone.size.y / ((haut - bas) * ky))
		var cx := (x0 + x1) * 0.5 * kx * sens
		o = Vector2(zone.get_center().x - cx * u, zone.position.y + (zone.size.y - (haut - bas) * ky * u) * 0.5 + haut * ky * u)

	# une loupe : le dessin tient dans un cercle (cinquante unités de rayon, à peu près)
	func loupe(centre: Vector2, rayon: float) -> void:
		o = centre
		u = rayon / 52.0
		kx = 1.0
		ky = 1.0
		sens = 1.0

	func pt(x: float, y: float) -> Vector2:
		return o + Vector2(x * kx * sens, -y * ky) * u

	func mm(x: float) -> float:
		return x * u

	# --- les gestes ---

	func gris(c: Color) -> Color:
		return P.PAPIER.lerp(P.ENCRE_DOUCE, 0.2 + 0.2 * (1.0 - c.v))

	func aplat(pts: PackedVector2Array, c: Color) -> void:
		if pts.size() >= 3:
			t.draw_colored_polygon(pts, gris(c) if lavis else c)

	# l'ombre d'une forme : ce qu'il en reste quand on la décale vers le jour (elle tombe en bas, à droite)
	func ombrer(pts: PackedVector2Array, d: float, force := 0.2) -> void:
		if lavis or fin < 1 or pts.size() < 3:
			return
		var decale := Transform2D(0.0, Vector2(-d, -d * 0.8)) * pts
		for q in Geometry2D.clip_polygons(pts, decale):
			if q.size() >= 3:
				t.draw_colored_polygon(q, Color(P.NUIT_BLEUE, force))

	# un trait d'encre ; a < 1 : un trait de détail (une nervure, un poil), que le lavis et les petites tailles ne font pas
	func filet(pts: PackedVector2Array, k := 1.0, a := 1.0) -> void:
		if pts.size() < 2:
			return
		if lavis:
			if a >= 1.0:
				t.draw_polyline(pts, Color(P.ENCRE_DOUCE, 0.3), 1.0, true)
			return
		if a < 1.0 and fin < 2:
			return
		t.draw_polyline(pts, Color(P.ENCRE, a), maxf(w * k, 0.6), true)

	func cerne(pts: PackedVector2Array, k := 1.0) -> void:
		if pts.size() < 3:
			return
		var f := pts.duplicate()
		f.append(pts[0])
		filet(f, k)

	# un trait de couleur, cerné d'encre : une tige trop fine pour qu'on en peigne les deux bords
	func brin(ligne: PackedVector2Array, l: float, c: Color, k := 1.0) -> void:
		if ligne.size() < 2:
			return
		var e := maxf(l, 1.0 if fin > 0 else 1.5)
		if lavis:
			t.draw_polyline(ligne, gris(c).darkened(0.06), e + 0.4, true)
			return
		t.draw_polyline(ligne, P.ENCRE, e + w * 1.5 * k, true)
		t.draw_polyline(ligne, c, e, true)

	func bande(a: PackedVector2Array, b: PackedVector2Array, c: Color) -> void:
		var n := mini(a.size(), b.size())
		if n < 2:
			return
		var pts := PackedVector2Array()
		var idx := PackedInt32Array()
		for i in n:
			pts.append(a[i])
			pts.append(b[i])
		for i in n - 1:
			var k := i * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
		t.triangles(idx, pts, gris(c) if lavis else c)

	# une tige, une racine, une crosse : un fuseau le long d'une ligne, ses largeurs données de place en place ; l'ombre
	# d'un côté (en bas, à droite), ses deux bords à l'encre
	func fuseau(ligne: PackedVector2Array, larg: PackedFloat32Array, c: Color, k := 1.0) -> void:
		var n := ligne.size()
		if n < 2 or larg.size() < 2:
			return
		var gros := 0.0
		for x in larg:
			gros = maxf(gros, x)
		if gros < 2.6:
			brin(ligne, gros * 0.8, c, k)
			return
		var ga := PackedVector2Array()
		var dr := PackedVector2Array()
		for i in n:
			var d := (ligne[mini(i + 1, n - 1)] - ligne[maxi(i - 1, 0)]).normalized()
			var x := float(i) / (n - 1) * (larg.size() - 1)
			var j := mini(int(x), larg.size() - 2)
			var h := lerpf(larg[j], larg[j + 1], x - j) * 0.5
			ga.append(ligne[i] + d.orthogonal() * h)
			dr.append(ligne[i] - d.orthogonal() * h)
		if (ga[n / 2] - dr[n / 2]).dot(Vector2(0.6, 0.8)) > 0.0:
			var x2 := ga
			ga = dr
			dr = x2
		bande(ga, dr, c)
		if not lavis:
			var mil := PackedVector2Array()
			for i in n:
				mil.append(ga[i].lerp(dr[i], 0.6))
			bande(mil, dr, c.darkened(0.17))
		filet(ga, k * 0.85)
		filet(dr, k * 1.15)

	func disque(c: Vector2, rx: float, ry: float, col: Color, k := 1.0) -> void:
		var e := ellipse(c, rx, ry)
		aplat(e, col)
		if k > 0.0:
			cerne(e, k)

	static func ellipse(c: Vector2, rx: float, ry: float, rot := 0.0) -> PackedVector2Array:
		var n := clampi(int(maxf(rx, ry) * 1.3) + 8, 8, 30)
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		return pts

	static func courbe(a: Vector2, b: Vector2, c: Vector2, n := 10) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n + 1:
			var s := float(i) / n
			pts.append(a.lerp(b, s).lerp(b.lerp(c, s), s))
		return pts

	# une ligne adoucie (elle garde ses bouts)
	static func lisser(pts: PackedVector2Array, tours := 2) -> PackedVector2Array:
		var p := pts
		for _k in tours:
			var q := PackedVector2Array([p[0]])
			for i in p.size() - 1:
				q.append(p[i].lerp(p[i + 1], 0.25))
				q.append(p[i].lerp(p[i + 1], 0.75))
			q.append(p[p.size() - 1])
			p = q
		return p

	# une forme fermée adoucie
	static func arrondir(pts: PackedVector2Array, tours := 1) -> PackedVector2Array:
		var p := pts
		for _k in tours:
			var q := PackedVector2Array()
			var n := p.size()
			for i in n:
				q.append(p[i].lerp(p[(i + 1) % n], 0.25))
				q.append(p[i].lerp(p[(i + 1) % n], 0.75))
			p = q
		return p

	static func sur(ligne: PackedVector2Array, s: float) -> Vector2:
		var x := clampf(s, 0.0, 1.0) * (ligne.size() - 1)
		var i := mini(int(x), ligne.size() - 2)
		return ligne[i].lerp(ligne[i + 1], x - i)

	static func tirets(t_, a: Vector2, b: Vector2, plein: float, vide: float, c: Color) -> void:
		var lg := a.distance_to(b)
		var d := (b - a) / maxf(lg, 0.001)
		var x := 0.0
		while x < lg:
			t_.draw_line(a + d * x, a + d * minf(x + plein, lg), c, 1.0, true)
			x += plein + vide

	static func rond_tirets(t_, c: Vector2, rayon: float, col: Color) -> void:
		var n := int(rayon * 0.9)
		for i in n:
			var a := TAU * i / n
			t_.draw_arc(c, rayon, a, a + TAU / n * 0.55, 4, col, 1.0, true)

	# --- la feuille ---

	# une feuille, de son attache a à sa pointe b (en points) : larg, sa demi-largeur ; cambre, sa courbure (en part de sa
	# longueur) ; opts : « pos » (où elle est la plus large, de 0 à 1), « dents », « nerv » (ses paires de nervures), « par »
	# (des nervures parallèles), « sores » (les fructifications d'une fougère)
	func feuille(a: Vector2, b: Vector2, larg: float, c: Color, cambre := 0.0, opts := {}) -> void:
		var d := b - a
		var lg := d.length()
		if lg < 0.6:
			return
		if not nu:
			larg *= etroit
		var duvet := signe == "duvet" and not nu
		var pays := "" if nu else lieu
		var menu := larg < 3.4
		if duvet:
			c = c.lerp(ARGENT, 0.5)
		var nrm := d.orthogonal() / lg
		var m := a + d * 0.5 + nrm * cambre * lg
		if larg < 1.3:
			brin(courbe(a, m, b, 4), larg * 1.7, c, 0.8)
			return
		var dents := int(opts.get("dents", 0)) if fin >= 1 else 0
		var pas := dents * 2 if dents > 0 else (12 if fin >= 2 else (8 if fin == 1 else 6))
		var ex := log(0.5) / log(clampf(float(opts.get("pos", 0.4)), 0.15, 0.85))
		var axe := PackedVector2Array()
		var ga := PackedVector2Array()
		var dr := PackedVector2Array()
		for i in pas + 1:
			var s := float(i) / pas
			var q := a.lerp(m, s).lerp(m.lerp(b, s), s)
			var nn := (m - a).lerp(b - m, s).normalized().orthogonal()
			var f := larg * pow(sin(PI * pow(s, ex)), 0.8)
			if dents > 0:
				f *= 1.14 if i % 2 == 1 else 0.88
			axe.append(q)
			ga.append(q + nn * f)
			dr.append(q - nn * f)
		var poly := ga.duplicate()
		for i in range(pas - 1, 0, -1):
			poly.append(dr[i])
		aplat(poly, c)
		if not lavis and fin >= 1:
			# (la moitié à l'ombre : celle d'en bas, à droite)
			var cote := dr if (dr[pas / 2] - ga[pas / 2]).dot(Vector2(0.5, 0.85)) > 0.0 else ga
			var demi := axe.duplicate()
			for i in range(pas - 1, 0, -1):
				demi.append(cote[i])
			if not menu:
				t.draw_colored_polygon(demi, c.darkened(0.13))
			if pays == "lande" and fin >= 2:
				# la lande : la pointe a séché
				var sec := PackedVector2Array()
				var i0 := int(pas * 0.72)
				for i in range(i0, pas + 1):
					sec.append(ga[i])
				for i in range(pas - 1, i0 - 1, -1):
					sec.append(dr[i])
				if sec.size() >= 3:
					t.draw_colored_polygon(sec, Color(PAILLE, 0.55))
			elif pays == "marais" and fin >= 2 and larg > 3.0:
				# le marais : elle luit
				var luit := PackedVector2Array()
				var haut := ga if cote == dr else dr
				for i in range(int(pas * 0.25), int(pas * 0.7)):
					luit.append(axe[i].lerp(haut[i], 0.55))
				if luit.size() >= 2:
					t.draw_polyline(luit, Color(1.0, 1.0, 0.98, 0.6), maxf(larg * 0.16, 1.0), true)
		cerne(poly, 0.9 if fin < 1 else clampf(larg / 5.0, 0.62, 1.0))
		if lavis or fin < 1:
			return
		# la nervure du milieu, puis les autres
		var nerv := axe.slice(0, int(pas * 0.92) + 1)
		if fin < 2 or menu:
			t.draw_polyline(nerv, Color(P.ENCRE, 0.42), 1.0, true)
		else:
			filet(nerv, 0.75, 0.85)
			if bool(opts.get("par", false)):
				for kk in [0.36, 0.7]:
					var l1 := PackedVector2Array()
					var l2 := PackedVector2Array()
					for i in range(1, pas):
						l1.append(axe[i].lerp(ga[i], float(kk)))
						l2.append(axe[i].lerp(dr[i], float(kk)))
					filet(l1, 0.6, 0.4)
					filet(l2, 0.6, 0.4)
			var paires := int(opts.get("nerv", 0))
			if fin >= 3:
				paires = int(paires * 1.6)
			for j in paires:
				var s0 := (j + 1.0) / (paires + 1.0) * 0.84
				var s1 := minf(s0 + 0.15, 0.97)
				var q0 := sur(axe, s0)
				for cote2 in [ga, dr]:
					var bord: PackedVector2Array = cote2
					var q1 := sur(axe, s1).lerp(sur(bord, s1), 0.9)
					filet(courbe(q0, q0.lerp(q1, 0.5) + (sur(bord, s0) - q0) * 0.3, q1, 5), 0.6, 0.5)
					if fin >= 3 and larg > 8.0:
						# (à la loupe : le réseau entre les nervures)
						var q2 := sur(axe, s0 + 0.05).lerp(sur(bord, s0 + 0.05), 0.55)
						filet(PackedVector2Array([q2, q2 + (q1 - q0).orthogonal().normalized() * larg * 0.2]), 0.5, 0.28)
			if opts.has("sores"):
				for j in int(opts["sores"]):
					var s0 := 0.16 + 0.7 * j / maxf(float(opts["sores"]) - 1.0, 1.0)
					for cote2 in [ga, dr]:
						var bord: PackedVector2Array = cote2
						var q := sur(axe, s0).lerp(sur(bord, s0), 0.52)
						disque(q, larg * 0.11, larg * 0.11, P.TERRE.lerp(P.BRAISE, 0.3), 0.6)
		if duvet:
			# le duvet : de petits poils d'argent, tout le long du bord
			var saut := 1 if fin >= 2 else 2
			var poil := (2.6 if fin >= 2 else 1.6) * (1.5 if fin >= 3 else 1.0)
			for cote2 in [ga, dr]:
				var bord: PackedVector2Array = cote2
				for i in range(1, pas, saut):
					var dehors := (bord[i] - axe[i]).normalized()
					var vers := (axe[mini(i + 1, pas)] - axe[i - 1]).normalized()
					t.draw_line(bord[i], bord[i] + (dehors + vers * 0.5) * poil, Color(P.ENCRE, 0.5), 1.0, true)
					if fin >= 3:
						var mi := bord[i].lerp(bord[i + 1], 0.5)
						t.draw_line(mi, mi + (dehors + vers * 0.2) * poil * 0.7, Color(P.ENCRE, 0.38), 1.0, true)
			if fin >= 2:
				for i in range(2, pas - 1, 2):
					for kk in [0.4, -0.45]:
						var q := axe[i].lerp(ga[i] if float(kk) > 0.0 else dr[i], absf(float(kk)))
						t.draw_line(q, q + Vector2(0.9, -1.5), Color(1.0, 1.0, 1.0, 0.7), 1.0, true)
		if pays == "taiga" and fin >= 2 and larg > 4.0:
			# la taïga : le givre, à la pointe
			for q in [b + Vector2(1.5, -2.5)]:
				var g: Vector2 = q
				t.draw_line(g + Vector2(-1.8, 0), g + Vector2(1.8, 0), Color(P.LUNE, 0.8), 1.0, true)
				t.draw_line(g + Vector2(0, -1.8), g + Vector2(0, 1.8), Color(P.LUNE, 0.8), 1.0, true)

	# une radicelle : un fil qui tremble
	func radicelle(a: Vector2, dir: Vector2, long: float, k := 0.7) -> void:
		dir = dir.normalized()
		var nn := dir.orthogonal()
		var pts := PackedVector2Array([a])
		for i in 4:
			var s := (i + 1) / 4.0
			pts.append(a + dir * long * s + nn * long * 0.09 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - s * 0.5) + Vector2(0.0, long * 0.12 * s * s))
		filet(lisser(pts, 1), k, 0.8)
		if fin >= 2 and long > 9.0:
			var q := sur(pts, 0.55)
			filet(PackedVector2Array([q, q + (dir + nn * 0.9).normalized() * long * 0.3]), 0.5, 0.55)

	# une racine pivotante : son fuseau, ses anneaux, ses radicelles
	func pivot(ligne: PackedVector2Array, larg: PackedFloat32Array, c: Color, anneaux: int) -> void:
		var axe := lisser(ligne, 2)
		var n := axe.size()
		for i in range(3, n - 1, 2):
			var cote := 1.0 if (i / 2) % 2 == 0 else -1.0
			radicelle(axe[i], Vector2(cote * 0.95, 0.55), mm(8.0 + 6.0 * r.randf()))
		radicelle(axe[n - 1], Vector2(0.25, 1.0), mm(9.0))
		fuseau(axe, larg, c)
		for j in anneaux:
			var s := 0.07 + 0.1 * j
			var q := sur(axe, s)
			var h := larg[0] * 0.42 * (1.0 - s * 0.6)
			filet(PackedVector2Array([q + Vector2(-h, -0.8), q + Vector2(0.0, 0.7), q + Vector2(h, -0.5)]), 0.6, 0.5)
		# (un peu de sa terre, restée prise)
		if fin >= 2:
			for i in 6:
				var q := sur(axe, 0.3 + 0.1 * i) + Vector2((r.randf() - 0.5) * larg[0] * 2.6, r.randf() * 3.0)
				t.draw_circle(q, 0.8, Color(P.TERRE, 0.5))

	# des racines en chevelu, sous le collet
	func chevelu(n: int, long: float, c: Color) -> void:
		for i in n:
			var a := lerpf(-1.15, 1.15, i / float(n - 1)) + (r.randf() - 0.5) * 0.2
			radicelle(pt(a * 2.5, -1.0), Vector2(sin(a) * sens, cos(a)), mm(long * (0.7 + 0.5 * r.randf())), 0.75)
		disque(pt(0.0, -2.0), mm(5.0), mm(3.2), c, 0.9)

	# une abeille : son corps rayé, ses deux ailes ; vole : le pointillé de son chemin
	func abeille(c: Vector2, s: float, rot: float, vole: bool) -> void:
		if lavis:
			return
		var tr := Transform2D(rot, c)
		if vole:
			for i in 5:
				t.draw_circle(tr * Vector2(-s * (2.2 + i * 1.3), s * (0.6 + 0.25 * i * i)), 0.7, Color(P.ENCRE, 0.4))
		for cote in [-1.0, 1.0]:
			var aile := tr * ellipse(Vector2(-s * 0.1, -s * 0.95 * float(cote) - s * 0.2), s * 0.95, s * 0.5, 0.5 * float(cote))
			t.draw_colored_polygon(aile, Color(1.0, 1.0, 1.0, 0.75))
			aile.append(aile[0])
			t.draw_polyline(aile, Color(P.ENCRE, 0.7), 1.0, true)
		var corps := tr * ellipse(Vector2.ZERO, s * 1.25, s * 0.72)
		t.draw_colored_polygon(corps, MIEL)
		for x in [-0.45, 0.15]:
			t.draw_line(tr * Vector2(s * float(x), -s * 0.62), tr * Vector2(s * float(x), s * 0.62), P.ENCRE, maxf(s * 0.3, 1.0), true)
		corps.append(corps[0])
		t.draw_polyline(corps, P.ENCRE, 1.0, true)
		t.draw_circle(tr * Vector2(s * 1.25, 0.0), s * 0.5, P.ENCRE)

	# --- les sept plantes ---

	func plante(forme: String, racine: bool) -> void:
		match forme:
			"clochette":
				clochette(racine)
			"epi":
				epi(racine)
			"rosette":
				rosette(racine)
			"morelle":
				morelle(racine)
			"chardon":
				chardon(racine)
			"crosse":
				crosse(racine)
			_:
				ombelle(racine)

	# l'ombelle : une racine en pivot, une tige creuse et cannelée, des feuilles découpées, deux ombelles plates
	func ombelle(racine: bool) -> void:
		if racine:
			pivot(PackedVector2Array([pt(0.0, 1.0), pt(0.6, -10.0), pt(-1.2, -22.0), pt(2.6, -36.0)]), PackedFloat32Array([mm(8.5), mm(10.0), mm(5.5), mm(1.2)]), RACINE.lightened(0.1), 7)
		var n1 := pt(1.5, 33.0)
		var n2 := pt(0.3, 61.0)
		var cou := pt(2.0, 87.0)
		decoupee(pt(-1.5, 1.0), pt(-41.0, 37.0), 0.14 * sens, 1.0)
		decoupee(pt(1.5, 1.0), pt(39.0, 27.0), -0.16 * sens, 0.92)
		decoupee(n1, pt(32.0, 57.0), -0.12 * sens, 0.62)
		ancres["feuille"] = pt(-27.0, 27.0)
		# le rameau de la seconde ombelle, plus jeune
		var c2 := pt(-25.0, 75.0)
		fuseau(courbe(n2, pt(-11.0, 63.0), c2, 8), PackedFloat32Array([mm(2.8), mm(1.9)]), tige_c)
		ombrelle(c2, -26.0, 87.0, 13.5, 5 if fin > 0 else 3, 0.78)
		# la tige, ses nœuds engainés
		var axe := lisser(PackedVector2Array([pt(0.0, 0.0), n1, n2, cou]), 2)
		fuseau(axe, PackedFloat32Array([mm(5.6), mm(4.8), mm(3.9), mm(3.0)]), tige_c)
		if fin >= 2:
			var canne := PackedVector2Array()
			for q in axe:
				canne.append(q + Vector2(-mm(1.0), 0.0))
			filet(canne, 0.6, 0.35)
		if fin >= 1:
			for nd in [n1, n2]:
				var q: Vector2 = nd
				disque(q, mm(3.6), mm(1.5), tige_c.darkened(0.12), 0.8)
		ancres["tige"] = pt(1.2, 47.0)
		ombrelle(cou, 2.5, 101.0, 31.0, 9 if fin >= 2 else (7 if fin == 1 else 5), 1.0)
		ancres["fleur"] = pt(14.0, 103.0)

	# une feuille découpée : son pétiole, trois paires de pennes dentées, celle du bout
	func decoupee(a: Vector2, b: Vector2, cambre: float, k: float) -> void:
		var d := b - a
		var lg := d.length()
		var axe := courbe(a, a + d * 0.5 + d.orthogonal() * cambre, b, 12)
		if fin == 0:
			brin(axe, 1.0, tige_c)
			for s in [0.55, 0.82]:
				var q := sur(axe, float(s))
				var tg := (sur(axe, float(s) + 0.06) - q).normalized()
				brin(PackedVector2Array([q, q + tg.rotated(1.0) * lg * 0.26]), 1.7, vert, 0.7)
				brin(PackedVector2Array([q, q + tg.rotated(-1.0) * lg * 0.26]), 1.7, vert, 0.7)
			return
		var paires := [[0.34, 0.36], [0.57, 0.3], [0.78, 0.21]]
		for cote in [1.0, -1.0]:
			for j in paires.size():
				var s := float(paires[j][0])
				var q := sur(axe, s)
				var tg := (sur(axe, s + 0.05) - q).normalized()
				var lp := lg * float(paires[j][1])
				var bout := q + tg.rotated(float(cote) * 0.98) * lp
				var col := vert if (j + int(float(cote) > 0.0)) % 2 == 0 else vert.lightened(0.1)
				if fin >= 2 and j < 2 and k > 0.7:
					# (les plus grandes sont découpées à leur tour)
					var mi := q.lerp(bout, 0.38)
					var dp := (bout - q).normalized()
					feuille(mi, mi + dp.rotated(0.85) * lp * 0.42, lp * 0.11, col, 0.0, {"dents": 3, "pos": 0.45})
					feuille(mi, mi + dp.rotated(-0.85) * lp * 0.42, lp * 0.11, col, 0.0, {"dents": 3, "pos": 0.45})
				feuille(q, bout, lp * 0.21, col, 0.0, {"dents": 4, "pos": 0.42, "nerv": 0})
		feuille(sur(axe, 0.88), b + (b - sur(axe, 0.88)).normalized() * lg * 0.12, lg * 0.055, vert, 0.0, {"dents": 4, "pos": 0.42})
		fuseau(axe, PackedFloat32Array([mm(2.4) * k, mm(1.1) * k]), tige_c if signe == "rouge" else tige_c.lerp(vert, 0.45))

	# une ombelle : ses rayons en éventail depuis le haut de la tige, une ombellule au bout de chacun
	func ombrelle(pied: Vector2, cx: float, cy: float, rx: float, n: int, k: float) -> void:
		if fin >= 2:
			for i in 4:
				var a := PI * (0.2 + 0.2 * i)
				filet(PackedVector2Array([pied, pied + Vector2(cos(a), sin(a) * 0.9) * mm(4.2)]), 0.8)
		var bouts := PackedVector2Array()
		for i in n:
			var a := lerpf(-1.0, 1.0, i / float(n - 1))
			var q := pt(cx + a * rx, cy + (1.0 - a * a) * rx * 0.2)
			filet(courbe(pied, pied.lerp(q, 0.55) + Vector2(0.0, mm(1.6)), q, 5), 0.75)
			bouts.append(q)
		if fin == 0:
			# (en tout petit : une seule nappe de fleurs, plate)
			disque(pt(cx, cy + rx * 0.14), mm(rx * 1.1), maxf(mm(rx * 0.3), 2.0), fleur, 0.9)
			return
		for q in bouts:
			bouquet(q, mm(5.4) * k * (1.5 if fin == 0 else 1.0))

	# une ombellule : cinq fleurs autour d'une, serrées, à plat
	func bouquet(c: Vector2, rr: float) -> void:
		if fin == 0 or rr < 2.6:
			disque(c, rr * 1.1, rr * 0.8, fleur, 0.85)
			return
		for i in 6:
			var q := c + Vector2(0.0, -rr * 0.12)
			if i < 5:
				q = c + Vector2(cos(TAU * i / 5.0 + 0.5), sin(TAU * i / 5.0 + 0.5) * 0.55) * rr * 0.74
			disque(q, rr * 0.5, rr * 0.42, fleur if i < 5 else fleur.lightened(0.1), 0.6)
			if fin >= 2 and not lavis:
				t.draw_circle(q, maxf(rr * 0.1, 0.6), MIEL.darkened(0.15))

	# la clochette : un rhizome couché, deux feuilles engainantes, une hampe qui verse, ses clochettes d'un seul côté
	func clochette(racine: bool) -> void:
		if racine:
			for i in 9:
				var x := lerpf(-27.0, 21.0, i / 8.0)
				radicelle(pt(x, -9.0), Vector2((r.randf() - 0.5) * 0.7, 1.0), mm(10.0 + 7.0 * r.randf()))
			var rz := lisser(PackedVector2Array([pt(-31.0, -9.0), pt(-17.0, -6.5), pt(0.0, -4.5), pt(13.0, -8.0), pt(25.0, -7.0)]), 2)
			fuseau(rz, PackedFloat32Array([mm(3.4), mm(5.8), mm(7.0), mm(5.2), mm(3.2)]), RACINE.darkened(0.06))
			for x in [-22.0, -12.0, 8.0, 17.0]:
				filet(PackedVector2Array([pt(float(x), -3.8), pt(float(x) + 0.8, -10.2)]), 0.6, 0.5)
			# (le bourgeon de l'an prochain)
			feuille(pt(-29.0, -8.0), pt(-33.0, 3.5), mm(2.8), clair, 0.0, {"pos": 0.45})
		var opts := {"par": true, "pos": 0.5}
		feuille(pt(-2.0, 0.5), pt(-25.0, 82.0), mm(10.0), vert, 0.1 * sens, opts)
		feuille(pt(2.0, 0.5), pt(17.0, 60.0), mm(8.6), vert.darkened(0.1), -0.12 * sens, opts)
		ancres["feuille"] = pt(-13.0, 44.0)
		# la gaine, pâle, qui serre le pied
		var gaine := PackedVector2Array([pt(-3.2, 0.0), pt(-3.6, 11.0), pt(0.5, 15.0), pt(3.4, 10.0), pt(3.0, 0.0)])
		aplat(gaine, clair.lerp(P.IVOIRE, 0.4))
		cerne(gaine, 0.8)
		var arche := lisser(PackedVector2Array([pt(0.3, 12.0), pt(2.0, 42.0), pt(6.0, 72.0), pt(18.0, 92.0), pt(33.0, 91.0), pt(43.0, 79.0), pt(47.0, 63.0)]), 2)
		ancres["tige"] = pt(2.2, 40.0)
		var n := 6 if fin >= 1 else 4
		for i in n:
			# (de la plus ouverte, près de la tige, aux boutons du bout)
			var s := lerpf(0.52, 0.985, i / float(n - 1))
			var a := sur(arche, s)
			var taille := mm(lerpf(9.6, 5.6, i / float(n - 1))) * (1.3 if fin == 0 else 1.0)
			var e := a + Vector2(mm(1.2) * sens, mm(4.6) + taille * 0.1)
			filet(courbe(a, a + Vector2(mm(1.6) * sens, mm(1.0)), e, 4), 0.7)
			cloche(e, taille, i >= n - (2 if fin >= 1 else 1))
			if i == 1:
				ancres["fleur"] = e + Vector2(0.0, taille * 0.6)
		fuseau(arche, PackedFloat32Array([mm(2.8), mm(2.2), mm(1.3)]), tige_c)

	# une clochette qui pend sous e : étroite à l'attache, évasée, la lèvre retroussée ; bouton : encore fermée
	func cloche(e: Vector2, s: float, bouton: bool) -> void:
		if bouton:
			var b0 := ellipse(e + Vector2(0.0, s * 0.5), s * 0.34, s * 0.52)
			aplat(b0, fleur.lerp(clair, 0.45))
			cerne(b0, 0.8)
			return
		var brut := PackedVector2Array()
		for q in [Vector2(-0.26, 0.0), Vector2(0.26, 0.0), Vector2(0.62, 0.3), Vector2(0.72, 0.78), Vector2(1.0, 1.1), Vector2(0.62, 1.04), Vector2(0.33, 1.2),
				Vector2(0.0, 1.05), Vector2(-0.33, 1.2), Vector2(-0.62, 1.04), Vector2(-1.0, 1.1), Vector2(-0.72, 0.78), Vector2(-0.62, 0.3)]:
			var v: Vector2 = q
			brut.append(e + v * s * 0.62)
		var poly := arrondir(brut, 1) if s > 5.0 else brut
		aplat(poly, fleur)
		ombrer(poly, s * 0.2, 0.24)
		cerne(poly, 0.9)
		if fin >= 2:
			filet(PackedVector2Array([e + Vector2(s * 0.08, s * 0.1), e + Vector2(s * 0.2, s * 0.6)]), 0.6, 0.4)
			t.draw_line(e + Vector2(-s * 0.2, s * 0.14), e + Vector2(-s * 0.36, s * 0.5), Color(1.0, 1.0, 1.0, 0.7), 1.0, true)

	# l'épi : des racines en chevelu, une rosette de feuilles nervurées, une hampe nue, un épi serré (au marais : une massette)
	func epi(racine: bool) -> void:
		if racine:
			chevelu(10, 24.0, RACINE.darkened(0.1))
		var opts := {"par": true, "pos": 0.5}
		var bouts := [Vector2(-17.0, 39.0), Vector2(15.0, 35.0), Vector2(-31.0, 25.0), Vector2(29.0, 21.0), Vector2(-36.0, 7.0), Vector2(35.0, 5.0)]
		if fin == 0:
			bouts = [Vector2(-22.0, 33.0), Vector2(22.0, 30.0), Vector2(-35.0, 9.0), Vector2(34.0, 7.0)]
		for i in bouts.size():
			var q: Vector2 = bouts[i]
			feuille(pt(signf(q.x) * 1.2, 0.8), pt(q.x, q.y), mm(6.4 if fin > 0 else 7.5), vert if i % 2 == 0 else vert.lightened(0.1), -signf(q.x) * 0.16 * sens, opts)
		ancres["feuille"] = pt(-22.0, 21.0)
		fuseau(lisser(PackedVector2Array([pt(0.0, 0.0), pt(1.6, 28.0), pt(2.0, 57.0)]), 1), PackedFloat32Array([mm(2.9), mm(2.3)]), tige_c)
		ancres["tige"] = pt(1.4, 36.0)
		var e0 := pt(2.0, 54.0)
		var e1 := pt(3.2, 107.0)
		var axe := PackedVector2Array()
		for i in 9:
			axe.append(e0.lerp(e1, i / 8.0))
		var massif := lieu == "marais"
		var larg := PackedFloat32Array([mm(6.0), mm(11.0), mm(11.5), mm(9.5), mm(6.5), mm(2.2)])
		if massif:
			# la massette : un manchon de velours, sa pointe nue au-dessus
			axe = PackedVector2Array()
			for i in 9:
				axe.append(e0.lerp(e1, i / 8.0 * 0.78))
			brin(PackedVector2Array([e0.lerp(e1, 0.74), e1 + Vector2(0.0, -mm(4.0))]), mm(1.6), tige_c)
			larg = PackedFloat32Array([mm(8.0), mm(11.5), mm(12.0), mm(12.0), mm(11.5), mm(8.0)])
		if fin == 0:
			for i in larg.size():
				larg[i] *= 1.3
		fuseau(axe, larg, fleur)
		ancres["fleur"] = e0.lerp(e1, 0.55) + Vector2(mm(4.0), 0.0)
		if lavis or fin < 1:
			return
		# les fleurs, en rangs serrés : de petites écailles qui se chevauchent ; les étamines qui dépassent, à mi-hauteur
		var rangs := 13 if fin >= 2 else 6
		for j in rangs:
			var s := (j + 0.6) / (rangs + 0.6)
			var q := sur(axe, s)
			var x := float(j) / (rangs - 1) * (larg.size() - 1)
			var jj := mini(int(x), larg.size() - 2)
			var h := lerpf(larg[jj], larg[jj + 1], x - jj) * 0.5
			for kk in 3:
				var dx := (kk - 1 + (0.5 if j % 2 == 0 else 0.0)) * h * 0.62
				if absf(dx) > h * 0.86:
					continue
				var c := q + Vector2(dx, 0.0)
				var ec := h * 0.3
				t.draw_polyline(PackedVector2Array([c + Vector2(-ec, -ec * 0.5), c + Vector2(0.0, ec * 0.6), c + Vector2(ec, -ec * 0.5)]), Color(P.ENCRE, 0.5), 1.0, true)
				if kk == 0 and fin >= 2:
					t.draw_circle(c + Vector2(0.0, -ec * 0.5), maxf(ec * 0.3, 0.6), fleur.lightened(0.35))
			if not massif and fin >= 2 and s > 0.25 and s < 0.75:
				for cote in [-1.0, 1.0]:
					var a := q + Vector2(float(cote) * h, 0.0)
					var b := a + Vector2(float(cote) * mm(4.2), -mm(1.6))
					t.draw_line(a, b, Color(P.ENCRE, 0.6), 1.0, true)
					t.draw_circle(b, 1.3, P.PAPIER.lerp(fleur, 0.3))
					t.draw_arc(b, 1.3, 0.0, TAU, 8, Color(P.ENCRE, 0.7), 1.0, true)

	# la rosette : un long pivot brun, de larges feuilles à plat, en étoile, une hampe courte et son bouquet au cœur
	func rosette(racine: bool) -> void:
		if racine:
			pivot(PackedVector2Array([pt(0.0, 3.0), pt(-1.0, -14.0), pt(1.6, -32.0), pt(-2.5, -53.0)]), PackedFloat32Array([mm(9.0), mm(8.0), mm(5.0), mm(1.2)]), RACINE.darkened(0.14), 5)
		var c0 := pt(0.0, 8.0)
		var n := 9 if fin >= 1 else 7
		var f1 := vert.lerp(fleur, 0.38)
		var f2 := sombre.lerp(fleur, 0.3).lightened(0.06)
		var liste: Array = []
		for i in n:
			var a := TAU * (i + 0.3) / n + (r.randf() - 0.5) * 0.2
			liste.append([sin(a), a, 0.86 + 0.2 * r.randf()])
		liste.sort_custom(func(x, y): return x[0] < y[0])
		for i in n:
			var a := float(liste[i][1])
			var lg := 39.0 * float(liste[i][2])
			var bout := c0 + Vector2(cos(a) * lg * kx, sin(a) * lg * 0.56 * ky) * u
			feuille(c0, bout, mm(9.4) * (0.82 + 0.18 * absf(cos(a))), f1 if i % 2 == 0 else f2, 0.05 * (1.0 if i % 3 == 0 else -1.0), {"pos": 0.66, "nerv": 4})
		ancres["feuille"] = c0 + Vector2(-27.0 * kx, 8.0 * ky) * u
		var haut := pt(3.0, 62.0)
		var hampe := courbe(c0, pt(0.0, 38.0), haut, 8)
		ancres["tige"] = sur(hampe, 0.5)
		# le bouquet : cinq fleurs sur leurs pédicelles
		var fl := [Vector2(-9.0, 4.0), Vector2(9.5, 5.0), Vector2(-4.5, 10.5), Vector2(5.0, 11.5), Vector2(0.0, 3.0)]
		for i in fl.size():
			var v: Vector2 = fl[i]
			var q := haut + Vector2(v.x * sens, -v.y) * u
			filet(courbe(haut, haut.lerp(q, 0.5) + Vector2(0.0, mm(1.0)), q, 4), 0.7)
			corolle(q, mm(5.6) * (1.35 if fin == 0 else 1.0), 5, fleur.lightened(0.1), i * 0.4)
		fuseau(hampe, PackedFloat32Array([mm(2.6), mm(1.8)]), tige_c)
		ancres["fleur"] = haut + Vector2(mm(5.0), -mm(8.0))

	# une fleur vue de face : ses pétales autour de son cœur
	func corolle(c: Vector2, ray: float, n: int, col: Color, tourne := 0.0, echancre := false) -> void:
		if fin == 0 or ray < 3.2:
			disque(c, ray * 0.9, ray * 0.9, col, 0.85)
			if not lavis and ray > 2.0:
				t.draw_circle(c, ray * 0.3, MIEL)
			return
		for i in n:
			var a := TAU * i / n + tourne
			var d := Vector2.from_angle(a)
			var pe := ellipse(c + d * ray * 0.56, ray * 0.52, ray * 0.4, a)
			if echancre:
				# (un pétale en cœur : échancré au bout)
				pe = PackedVector2Array()
				for q in [Vector2(0.05, 0.0), Vector2(0.5, 0.42), Vector2(0.95, 0.36), Vector2(1.12, 0.14), Vector2(0.98, 0.0), Vector2(1.12, -0.14),
						Vector2(0.95, -0.36), Vector2(0.5, -0.42)]:
					var v: Vector2 = q
					pe.append(c + v.rotated(a) * ray)
				pe = arrondir(pe, 1)
			aplat(pe, col if i % 2 == 0 else col.darkened(0.05))
			cerne(pe, 0.7)
			if fin >= 3:
				filet(PackedVector2Array([c + d * ray * 0.3, c + d * ray * 0.8]), 0.5, 0.3)
		disque(c, ray * 0.24, ray * 0.24, MIEL, 0.7)

	# la morelle : une racine ligneuse, des tiges en zigzag, des feuilles sombres, des baies luisantes en petites grappes
	func morelle(racine: bool) -> void:
		if racine:
			var pr := lisser(PackedVector2Array([pt(0.0, 1.0), pt(1.5, -10.0), pt(-2.0, -20.0), pt(1.0, -33.0)]), 2)
			for br in [[pt(1.0, -8.0), Vector2(1.0, 0.6), 17.0], [pt(-0.5, -15.0), Vector2(-1.0, 0.5), 15.0], [pt(-1.0, -22.0), Vector2(0.9, 0.8), 12.0], [pt(0.5, -5.0), Vector2(-1.0, 0.35), 12.0]]:
				var d: Vector2 = br[1]
				radicelle(br[0], Vector2(d.x * sens, d.y), mm(float(br[2])), 1.0)
			fuseau(pr, PackedFloat32Array([mm(6.0), mm(4.2), mm(2.6), mm(0.8)]), RACINE.darkened(0.2))
		var bois := tige_c if signe == "rouge" else tige_c.lerp(fleur, 0.3).darkened(0.1)
		var f1 := sombre.lerp(P.FEUILLE_SOMBRE, 0.25).lightened(0.1)
		var f2 := vert.darkened(0.08)
		var opts := {"pos": 0.36, "dents": 3, "nerv": 4}
		var t1 := PackedVector2Array([pt(0.0, 0.0), pt(2.0, 30.0), pt(-9.0, 50.0), pt(-20.0, 66.0), pt(-27.0, 86.0)])
		var t2 := PackedVector2Array([pt(2.0, 30.0), pt(13.0, 45.0), pt(19.0, 61.0), pt(32.0, 78.0)])
		var t3 := PackedVector2Array([pt(0.8, 14.0), pt(-13.0, 23.0), pt(-27.0, 30.0)])
		# les feuilles du fond, les tiges, puis les feuilles de devant
		var fonds := [[t1[2], Vector2(-21.0, 14.0), 10.0], [t2[1], Vector2(22.0, -3.0), 10.5], [t1[3], Vector2(11.0, 20.0), 9.0], [t2[2], Vector2(-8.0, 22.0), 9.0]]
		var devants := [[t1[4], Vector2(-9.0, 15.0), 9.0], [t1[4], Vector2(-19.0, -2.0), 8.5], [t2[3], Vector2(13.0, 13.0), 9.5], [t2[3], Vector2(17.0, -6.0), 8.0],
			[t3[2], Vector2(-17.0, 4.0), 9.5], [t3[1], Vector2(-3.0, 19.0), 8.0], [t1[1], Vector2(20.0, 6.0), 8.5]]
		if fin == 0:
			fonds = [fonds[0], fonds[1]]
			devants = [devants[0], devants[2], devants[4], devants[6]]
		for f in fonds:
			var a: Vector2 = f[0]
			var d: Vector2 = f[1]
			feuille(a, a + Vector2(d.x * kx * sens, -d.y * ky) * u * 1.25, mm(float(f[2])) * (1.25 if fin == 0 else 1.0), f1, 0.06 * sens, opts)
		fuseau(t3, PackedFloat32Array([mm(2.8), mm(1.6)]), bois)
		fuseau(t2, PackedFloat32Array([mm(3.4), mm(1.6)]), bois)
		fuseau(t1, PackedFloat32Array([mm(4.6), mm(3.6), mm(2.4), mm(1.6)]), bois)
		ancres["tige"] = pt(1.2, 21.0)
		for i in devants.size():
			var f: Array = devants[i]
			var a: Vector2 = f[0]
			var d: Vector2 = f[1]
			feuille(a, a + Vector2(d.x * kx * sens, -d.y * ky) * u * 1.25, mm(float(f[2])) * (1.25 if fin == 0 else 1.0), f2 if i % 2 == 0 else f1, -0.06 * sens, opts)
		ancres["feuille"] = t3[2] + Vector2(-9.0 * kx * sens, -3.0 * ky) * u
		# les grappes : un pédoncule sous la fourche, trois baies qui pendent ; une grappe encore en fleur
		var grappes := [[sur(t2, 0.45), Vector2(-5.0, -9.0), 3], [sur(t1, 0.62), Vector2(8.0, -8.0), 3], [sur(t2, 0.86), Vector2(-7.0, -7.0), 2], [sur(t3, 0.6), Vector2(3.0, -8.0), 2]]
		for g in grappes.size():
			var a: Vector2 = grappes[g][0]
			var d: Vector2 = grappes[g][1]
			var noeud := a + Vector2(d.x * sens, -d.y) * u
			filet(courbe(a, a + Vector2(d.x * sens * 0.7, -d.y * 0.2) * u, noeud, 4), 0.8)
			for k in int(grappes[g][2]):
				var q := noeud + Vector2((k - 1.0) * 6.6 * sens, 4.6 + (2.2 if k == 1 else 0.0)) * u
				filet(PackedVector2Array([noeud, q + Vector2(0.0, -mm(3.0))]), 0.7)
				if g == 3 and k == 1 and fin >= 1:
					corolle(q, mm(4.0), 5, P.PAPIER.lerp(Color.WHITE, 0.6), 0.3)
				else:
					baie(q, mm(4.6) * (1.35 if fin == 0 else 1.0))
			if g == 0:
				ancres["fleur"] = noeud + Vector2(0.0, mm(7.0))

	# une baie : luisante, son calice en étoile à l'attache
	func baie(c: Vector2, ray: float) -> void:
		var col := fleur
		if col.v < 0.3:
			col = col.lerp(P.LUNE, 0.14)
		var e := ellipse(c, ray, ray * 0.96)
		aplat(e, col)
		ombrer(e, ray * 0.5, 0.3)
		cerne(e, 0.95)
		if lavis:
			return
		t.draw_circle(c + Vector2(-ray * 0.36, -ray * 0.38), maxf(ray * 0.24, 0.8), Color(1.0, 1.0, 1.0, 0.9))
		if fin >= 1:
			for a in [-2.2, -1.57, -0.94]:
				t.draw_line(c + Vector2(0.0, -ray * 0.86), c + Vector2(0.0, -ray * 0.86) + Vector2.from_angle(float(a)) * ray * 0.62, clair.darkened(0.25), maxf(ray * 0.24, 1.0), true)

	# le chardon : un pivot épais, des feuilles en lames piquantes, une tige ailée d'épines, un capitule en étoile
	func chardon(racine: bool) -> void:
		if racine:
			pivot(PackedVector2Array([pt(0.0, 1.0), pt(-0.8, -12.0), pt(1.4, -25.0), pt(-1.6, -38.0)]), PackedFloat32Array([mm(10.5), mm(8.5), mm(4.6), mm(1.2)]), RACINE.darkened(0.05), 6)
		var gris := vert.lerp(P.IVOIRE, 0.22)
		lame(pt(-1.5, 1.0), pt(-25.0, 44.0), mm(8.0), gris.darkened(0.1), 0.12 * sens, 4)
		lame(pt(1.5, 1.0), pt(24.0, 39.0), mm(8.0), gris.darkened(0.04), -0.12 * sens, 4)
		lame(pt(-1.5, 1.0), pt(-43.0, 15.0), mm(8.6), gris, 0.14 * sens, 4)
		lame(pt(1.5, 1.0), pt(42.0, 11.0), mm(8.6), gris.lightened(0.06), -0.16 * sens, 4)
		ancres["feuille"] = pt(-30.0, 12.0)
		var cou := pt(2.0, 82.0)
		var axe := lisser(PackedVector2Array([pt(0.0, 0.0), pt(1.6, 40.0), cou]), 1)
		# le rameau, son bouton
		var c2 := pt(-21.0, 74.0)
		fuseau(courbe(pt(1.5, 52.0), pt(-12.0, 58.0), c2, 7), PackedFloat32Array([mm(3.0), mm(2.4)]), tige_c)
		capitule(c2 + Vector2(0.0, -mm(4.0)), mm(6.4), 0.35)
		lame(pt(1.6, 33.0), pt(24.0, 58.0), mm(5.0), gris, -0.1 * sens, 3)
		fuseau(axe, PackedFloat32Array([mm(6.2), mm(5.0), mm(4.2)]), tige_c)
		ancres["tige"] = pt(1.2, 24.0)
		if fin >= 1:
			# les ailes de la tige : de petites dents, une épine à chacune
			for i in (8 if fin >= 2 else 5):
				var s := 0.1 + 0.105 * i * (1.0 if fin >= 2 else 1.6)
				var q := sur(axe, s)
				var cote := (1.0 if i % 2 == 0 else -1.0) * sens
				var h := mm(lerpf(3.0, 2.2, s))
				var dent := PackedVector2Array([q + Vector2(cote * h * 0.9, mm(3.0)), q + Vector2(cote * (h + mm(3.6)), -mm(1.2)), q + Vector2(cote * h * 0.9, -mm(3.0))])
				aplat(dent, gris)
				filet(dent, 0.8)
				filet(PackedVector2Array([dent[1], dent[1] + Vector2(cote * mm(2.6), -mm(1.6))]), 0.7)
		capitule(cou + Vector2(0.0, -mm(9.0)), mm(11.5), 1.0)
		ancres["fleur"] = cou + Vector2(mm(8.0), -mm(20.0))

	# une feuille en lame : découpée en lobes aigus, une épine au bout de chacun, sa nervure pâle
	func lame(a: Vector2, b: Vector2, larg: float, c: Color, cambre: float, lobes: int) -> void:
		var d := b - a
		var lg := d.length()
		if signe == "duvet":
			c = c.lerp(ARGENT, 0.5)
		larg *= etroit
		var m := a + d * 0.5 + d.orthogonal() * cambre
		if fin == 0:
			lobes = 2
		var pas := lobes * 2 + 1
		var axe := PackedVector2Array()
		var ga := PackedVector2Array()
		var dr := PackedVector2Array()
		for i in pas + 1:
			var s := float(i) / pas
			var q := a.lerp(m, s).lerp(m.lerp(b, s), s)
			var tg := (m - a).lerp(b - m, s).normalized()
			var f := larg * pow(sin(PI * pow(s, 0.62)), 0.7)
			var pointe := i % 2 == 1 and i < pas
			f *= 1.2 if pointe else 0.4
			var avance := tg * (lg * 0.05 if pointe else 0.0)
			axe.append(q)
			ga.append(q + tg.orthogonal() * f + avance)
			dr.append(q - tg.orthogonal() * f + avance)
		var poly := ga.duplicate()
		for i in range(pas - 1, 0, -1):
			poly.append(dr[i])
		aplat(poly, c)
		if not lavis and fin >= 1:
			var cote := dr if (dr[pas / 2] - ga[pas / 2]).dot(Vector2(0.5, 0.85)) > 0.0 else ga
			var demi := axe.duplicate()
			for i in range(pas - 1, 0, -1):
				demi.append(cote[i])
			t.draw_colored_polygon(demi, c.darkened(0.13))
			t.draw_polyline(axe.slice(0, pas), c.lerp(P.PAPIER, 0.6), maxf(larg * 0.2, 1.2), true)
		cerne(poly, 1.0)
		if lavis or fin < 1:
			return
		for i in range(1, pas, 2):
			for cote2 in [ga, dr]:
				var bord: PackedVector2Array = cote2
				var dehors := (bord[i] - axe[i]).normalized()
				filet(PackedVector2Array([bord[i], bord[i] + dehors * maxf(larg * 0.42, 2.2)]), 0.8)
				filet(PackedVector2Array([axe[i - 1], bord[i]]), 0.5, 0.4)
				if signe == "duvet":
					var q := axe[i].lerp(bord[i], 0.5)
					t.draw_line(q, q + Vector2(1.0, -1.8), Color(1.0, 1.0, 1.0, 0.75), 1.0, true)
					t.draw_line(bord[i - 1], bord[i - 1] + dehors * 2.4, Color(P.ENCRE, 0.45), 1.0, true)
		filet(PackedVector2Array([b, b + (b - axe[pas - 1]).normalized() * maxf(larg * 0.5, 2.4)]), 0.8)
		if lieu == "taiga" and fin >= 2:
			var g := b + Vector2(2.0, -3.0)
			t.draw_line(g + Vector2(-1.8, 0), g + Vector2(1.8, 0), Color(P.LUNE, 0.8), 1.0, true)
			t.draw_line(g + Vector2(0, -1.8), g + Vector2(0, 1.8), Color(P.LUNE, 0.8), 1.0, true)

	# un capitule : son étoile de fleurons, puis son cœur d'écailles, chacune armée
	func capitule(c: Vector2, ray: float, ouvert: float) -> void:
		var n := 17 if fin >= 2 else (11 if fin == 1 else 7)
		var base := c + Vector2(0.0, -ray * 0.45)
		if ouvert > 0.5:
			for i in n:
				var a := -PI * lerpf(0.03, 0.97, i / float(n - 1))
				var lg := ray * (1.75 if i % 2 == 0 else 1.4)
				var bout := base + Vector2(cos(a) * lg * 1.06, sin(a) * lg)
				var nn := Vector2.from_angle(a).orthogonal() * maxf(ray * 0.17, 1.1)
				if fin == 0:
					brin(PackedVector2Array([base, bout]), 1.5, fleur, 0.55)
					continue
				var rai := PackedVector2Array([base + nn, bout, base - nn])
				aplat(rai, fleur if i % 2 == 0 else fleur.lightened(0.15))
				filet(PackedVector2Array([base + nn, bout, base - nn]), 0.7)
		else:
			# (un bouton : une houppe courte)
			var houppe := PackedVector2Array([base + Vector2(-ray * 0.5, 0.0), base + Vector2(-ray * 0.3, -ray * 0.75), base + Vector2(0.0, -ray * 0.95), base + Vector2(ray * 0.3, -ray * 0.75), base + Vector2(ray * 0.5, 0.0)])
			aplat(houppe, fleur.lerp(clair, 0.3))
			cerne(houppe, 0.8)
		var bulbe := PackedVector2Array()
		for i in 22:
			var a := TAU * i / 22.0
			bulbe.append(c + Vector2(cos(a) * ray, sin(a) * ray * (1.02 if sin(a) > 0.0 else 0.8)))
		if fin >= 1:
			# les épines des écailles, qui dépassent
			for i in (11 if fin >= 2 else 7):
				var a := lerpf(-0.5, PI + 0.5, i / (10.0 if fin >= 2 else 6.0))
				var d := Vector2(cos(a), sin(a) * 0.9)
				filet(PackedVector2Array([c + d * ray * 0.9, c + d * ray * 1.34 + Vector2(0.0, -ray * 0.16)]), 0.8)
		aplat(bulbe, sombre.lerp(P.IVOIRE, 0.3))
		ombrer(bulbe, ray * 0.4, 0.26)
		cerne(bulbe, 1.0)
		if fin >= 2:
			for j in 3:
				for i in (3 + j % 2):
					var q := c + Vector2((i - (2 + j % 2) * 0.5) * ray * 0.52, (j - 1.0) * ray * 0.5)
					filet(PackedVector2Array([q + Vector2(-ray * 0.24, -ray * 0.16), q + Vector2(0.0, ray * 0.2), q + Vector2(ray * 0.24, -ray * 0.16)]), 0.6, 0.6)

	# la crosse : une souche écailleuse, ses racines noires, une fronde ouverte et trois crosses qui se déplient
	func crosse(racine: bool) -> void:
		var stipe := tige_c if signe == "rouge" else tige_c.lerp(P.TERRE, 0.45)
		if racine:
			for i in 11:
				var a := lerpf(-1.2, 1.2, i / 10.0)
				radicelle(pt(a * 7.0, -6.0), Vector2(sin(a) * sens, cos(a) * 0.9), mm(13.0 + 8.0 * r.randf()), 0.8)
			var souche := arrondir(PackedVector2Array([pt(-12.0, -1.0), pt(-6.0, 3.0), pt(6.0, 3.0), pt(11.0, -2.0), pt(8.0, -9.0), pt(-3.0, -11.0), pt(-11.0, -8.0)]), 2)
			aplat(souche, P.TERRE.lerp(RACINE, 0.25))
			ombrer(souche, mm(3.0), 0.3)
			cerne(souche, 1.0)
			for i in 7:
				var q := pt(-8.0 + i * 2.7, -2.0 - (i % 3) * 2.6)
				filet(PackedVector2Array([q + Vector2(-mm(1.6), -mm(1.0)), q + Vector2(0.0, mm(1.2)), q + Vector2(mm(1.6), -mm(1.0))]), 0.6, 0.6)
			# (les chicots des frondes de l'an passé)
			brin(PackedVector2Array([pt(-8.0, 1.0), pt(-12.0, 8.0)]), mm(2.2), stipe.darkened(0.2))
			brin(PackedVector2Array([pt(8.0, 0.0), pt(13.0, 6.0)]), mm(2.2), stipe.darkened(0.2))
		var prele := lieu == "marais"
		# la grande fronde : ses pennes par paires, de plus en plus courtes, le bout encore roulé
		var a0 := pt(-2.0, 1.0)
		var b0 := pt(-34.0, 93.0)
		var rachis := courbe(a0, pt(-4.0, 66.0), b0, 18)
		var paires := 10 if fin >= 2 else (7 if fin == 1 else 4)
		for passe in 2:
			for j in paires:
				var s := 0.2 + 0.72 * j / (paires - 1.0)
				var q := sur(rachis, s)
				var tg := (sur(rachis, s + 0.04) - q).normalized()
				var lp := mm(lerpf(27.0, 5.0, pow(j / (paires - 1.0), 0.85))) * (0.78 if j == 0 else 1.0)
				# (d'abord celles du fond, plus sombres ; puis le rachis ; puis celles de devant)
				var cote := (1.0 if passe == 0 else -1.0) * sens
				var bout := q + tg.rotated(cote * (1.12 - 0.3 * s)) * lp
				var col := vert.darkened(0.1) if passe == 0 else (vert.lightened(0.06) if j % 2 == 0 else vert.lightened(0.16))
				if prele:
					feuille(q, bout, lp * 0.07, col, 0.0, {"pos": 0.3})
				else:
					feuille(q, bout, lp * (0.17 if fin > 0 else 0.24), col, 0.07 * cote, {"dents": 5 if fin >= 2 else 0, "pos": 0.28})
				if prele and passe == 1 and fin >= 1:
					filet(PackedVector2Array([q + tg.orthogonal() * mm(2.2), q - tg.orthogonal() * mm(2.2)]), 1.2)
			if passe == 0:
				fuseau(rachis, PackedFloat32Array([mm(3.6), mm(2.6), mm(1.2)]), stipe)
		ancres["feuille"] = sur(rachis, 0.45) + Vector2(-mm(12.0) * sens, -mm(3.0))
		ancres["tige"] = sur(rachis, 0.1)
		var jeune := fleur.lerp(clair, 0.25)
		spire(b0, (b0 - sur(rachis, 0.94)).normalized(), sens, mm(3.6), 0.9, mm(2.0), jeune)
		# la crosse à demi dépliée, ses pennes encore repliées
		var r2 := courbe(pt(3.0, 0.5), pt(17.0, 32.0), pt(22.0, 67.0), 12)
		if fin >= 1:
			for j in 4:
				var s := 0.42 + 0.14 * j
				var q := sur(r2, s)
				var tg := (sur(r2, s + 0.05) - q).normalized()
				for cote in [1.0, -1.0]:
					feuille(q, q + tg.rotated(float(cote) * 0.62) * mm(11.0 - 1.6 * j), mm(1.9), vert.lightened(0.12), 0.1 * float(cote), {"pos": 0.3})
		fuseau(r2, PackedFloat32Array([mm(3.8), mm(3.2)]), stipe)
		ecailles(r2, 0.1, 0.9, mm(1.6))
		var tete := spire(pt(22.0, 67.0), (pt(22.0, 67.0) - sur(r2, 0.92)).normalized(), -sens, mm(9.5), 1.35, mm(4.0), jeune)
		ancres["fleur"] = tete + Vector2(mm(7.0) * sens, 0.0)
		# la plus jeune, serrée ; et celle qui perce à peine
		var r3 := courbe(pt(0.5, 0.5), pt(4.0, 18.0), pt(9.0, 34.0), 8)
		fuseau(r3, PackedFloat32Array([mm(4.0), mm(3.4)]), stipe)
		ecailles(r3, 0.05, 0.95, mm(1.7))
		spire(pt(9.0, 34.0), (pt(9.0, 34.0) - sur(r3, 0.9)).normalized(), sens, mm(7.0), 1.5, mm(3.8), jeune)
		if fin >= 1:
			var r4 := courbe(pt(-4.0, 0.5), pt(-9.0, 7.0), pt(-12.0, 15.0), 6)
			fuseau(r4, PackedFloat32Array([mm(3.2), mm(2.8)]), stipe)
			spire(pt(-12.0, 15.0), (pt(-12.0, 15.0) - sur(r4, 0.85)).normalized(), -sens, mm(4.6), 1.3, mm(3.0), jeune)

	# une crosse : le ruban s'enroule sur lui-même depuis b, où arrive le stipe (de direction dir), du côté cote ; rend son centre
	func spire(b: Vector2, dir: Vector2, cote: float, rayon: float, tours: float, l0: float, col: Color) -> Vector2:
		var centre := b + dir.orthogonal() * cote * rayon
		var a0 := (b - centre).angle()
		var n := int(16.0 * tours) + 4
		var pts := PackedVector2Array()
		var larg := PackedFloat32Array()
		for i in n + 1:
			var s := float(i) / n
			pts.append(centre + Vector2.from_angle(a0 - cote * s * tours * TAU) * rayon * (1.0 - 0.82 * s))
			larg.append(lerpf(l0, l0 * 0.5, s))
		if fin >= 2 and rayon > 6.0:
			# (les pennes à naître : de petits rouleaux, le long du dos de la crosse)
			for i in range(2, n - 3, 2):
				var dehors := (pts[i] - centre).normalized()
				disque(pts[i] + dehors * l0 * 0.62, l0 * 0.3, l0 * 0.3, vert.lightened(0.1), 0.6)
		fuseau(pts, larg, col)
		return centre

	# les écailles d'un jeune stipe : de petits poils roux, de part et d'autre
	func ecailles(ligne: PackedVector2Array, s0: float, s1: float, long: float) -> void:
		if lavis or fin < 2:
			return
		var n := int(ligne.size() * (1.5 if fin >= 3 else 0.9))
		for i in n:
			var s := lerpf(s0, s1, i / float(n - 1))
			var q := sur(ligne, s)
			var tg := (sur(ligne, s + 0.03) - sur(ligne, s - 0.03)).normalized()
			var cote := 1.0 if i % 2 == 0 else -1.0
			var a := q + tg.orthogonal() * cote * long * 1.1
			t.draw_line(a, a + (tg.orthogonal() * cote + tg * 0.8) * long, Color(P.TERRE.lerp(P.BRAISE, 0.25), 0.85), 1.0, true)

	# --- à la loupe (cinquante unités de rayon, le centre à l'origine) ---

	func detail_fleur(forme: String) -> void:
		nu = true
		match forme:
			"clochette":
				_loupe_clochette()
			"epi":
				_loupe_epi()
			"rosette":
				_loupe_rosette()
			"morelle":
				_loupe_morelle()
			"chardon":
				_loupe_chardon()
			"crosse":
				_loupe_crosse()
			_:
				_loupe_ombelle()
		if signe == "miel" and forme != "crosse":
			abeille(pt(24.0, 30.0), mm(6.4), 2.5, false)

	# une ombellule : ses pédicelles, cinq fleurs à cinq pétales échancrés, leurs étamines
	func _loupe_ombelle() -> void:
		var pied := pt(0.0, -40.0)
		for a in [-1.0, -0.4, 0.4, 1.0]:
			feuille(pied, pied + Vector2(float(a) * mm(9.0), mm(6.0)), mm(1.8), vert, 0.0, {"pos": 0.4})
		var fl := [Vector2(-29.0, 6.0), Vector2(29.0, 4.0), Vector2(-14.0, 22.0), Vector2(15.0, 21.0), Vector2(0.0, 1.0)]
		for i in fl.size():
			var q := pt(fl[i].x, fl[i].y)
			fuseau(courbe(pied, pied.lerp(q, 0.5) + Vector2(0.0, mm(3.0)), q + Vector2(0.0, mm(4.0)), 6), PackedFloat32Array([mm(2.4), mm(1.8)]), tige_c if signe == "rouge" else vert.lerp(P.IVOIRE, 0.3))
			# l'ovaire, sous la fleur
			disque(q + Vector2(0.0, mm(4.0)), mm(3.0), mm(3.6), vert, 0.8)
			var ray := mm(12.5 if i == 4 else 10.0)
			for k in 5:
				var a := TAU * k / 5.0 + i * 0.6
				var d := Vector2.from_angle(a)
				t.draw_line(q + d * ray * 0.3, q + d * ray * 1.12, Color(P.ENCRE, 0.7), 1.0, true)
				t.draw_circle(q + d * ray * 1.12, 1.5, MIEL)
			corolle(q, ray, 5, fleur, i * 0.6 + TAU / 10.0, true)

	# une clochette ouverte : sa paroi coupée, ses étamines, son pistil
	func _loupe_clochette() -> void:
		filet(courbe(pt(-30.0, 44.0), pt(-6.0, 48.0), pt(0.0, 34.0), 6), 1.2)
		var brut := PackedVector2Array()
		for q in [Vector2(-7.0, 34.0), Vector2(7.0, 34.0), Vector2(20.0, 24.0), Vector2(25.0, 0.0), Vector2(27.0, -18.0), Vector2(38.0, -30.0), Vector2(24.0, -29.0), Vector2(13.0, -36.0),
				Vector2(0.0, -29.0), Vector2(-13.0, -36.0), Vector2(-24.0, -29.0), Vector2(-38.0, -30.0), Vector2(-27.0, -18.0), Vector2(-25.0, 0.0), Vector2(-20.0, 24.0)]:
			var v: Vector2 = q
			brut.append(pt(v.x, v.y))
		var poly := arrondir(brut, 2)
		# le dedans, pâle ; puis la moitié de paroi qu'on a laissée
		aplat(poly, fleur.lerp(P.PAPIER, 0.62))
		var mur := Geometry2D.intersect_polygons(poly, PackedVector2Array([pt(-60.0, 60.0), pt(-3.0, 60.0), pt(-7.0, 10.0), pt(-1.0, -12.0), pt(-6.0, -60.0), pt(-60.0, -60.0)]))
		for q in mur:
			aplat(q, fleur)
			ombrer(q, mm(5.0), 0.2)
		cerne(poly, 1.1)
		filet(lisser(PackedVector2Array([pt(-3.0, 34.0), pt(-7.0, 10.0), pt(-1.0, -12.0), pt(-5.0, -31.0)]), 2), 0.9)
		# le pistil : l'ovaire en haut, le style, le stigmate
		disque(pt(3.0, 24.0), mm(6.0), mm(7.0), vert.lightened(0.1), 0.9)
		fuseau(PackedVector2Array([pt(3.0, 18.0), pt(4.0, -8.0)]), PackedFloat32Array([mm(2.8), mm(2.8)]), clair)
		disque(pt(4.0, -10.0), mm(3.4), mm(2.6), MIEL.lerp(P.PAPIER, 0.3), 0.8)
		for x in [10.0, 17.0, -9.0]:
			filet(PackedVector2Array([pt(float(x) * 0.7, 26.0), pt(float(x), 9.0)]), 0.8)
			disque(pt(float(x), 5.0), mm(2.4), mm(4.6), MIEL, 0.8)

	# une fleur de l'épi : sa bractée, son calice, quatre lobes, quatre longues étamines, le style
	func _loupe_epi() -> void:
		feuille(pt(-6.0, -42.0), pt(-27.0, -8.0), mm(7.0), vert, 0.12, {"pos": 0.45, "nerv": 2})
		var calice := arrondir(PackedVector2Array([pt(-7.0, -40.0), pt(7.0, -40.0), pt(10.0, -16.0), pt(5.0, -9.0), pt(-5.0, -9.0), pt(-10.0, -16.0)]), 1)
		for st in [[Vector2(-30.0, 22.0), -0.5], [Vector2(-12.0, 37.0), -0.2], [Vector2(14.0, 37.0), 0.25], [Vector2(31.0, 20.0), 0.6]]:
			var v: Vector2 = st[0]
			filet(courbe(pt(v.x * 0.1, -6.0), pt(v.x * 0.3, v.y * 0.6), pt(v.x, v.y), 8), 0.8)
			var an := ellipse(pt(v.x, v.y), mm(3.2), mm(5.6), float(st[1]))
			aplat(an, P.PAPIER.lerp(MIEL, 0.55))
			cerne(an, 0.8)
		filet(courbe(pt(0.0, -6.0), pt(-2.0, 20.0), pt(3.0, 45.0), 8), 0.9)
		for i in 5:
			filet(PackedVector2Array([pt(1.0 + i * 0.5, 32.0 + i * 3.0), pt(5.5 + i * 0.5, 34.0 + i * 3.0)]), 0.6, 0.7)
		for lb in [[Vector2(-21.0, -2.0), 0.0], [Vector2(21.0, -3.0), 0.0], [Vector2(-10.0, 9.0), 0.1], [Vector2(11.0, 9.0), -0.1]]:
			var v: Vector2 = lb[0]
			var ec := etroit
			etroit = 1.0
			feuille(pt(signf(v.x) * 2.0, -9.0), pt(v.x, v.y), mm(5.6), fleur, float(lb[1]), {"pos": 0.5, "nerv": 0})
			etroit = ec
		aplat(calice, vert.lightened(0.08))
		ombrer(calice, mm(3.0))
		cerne(calice, 1.0)
		filet(PackedVector2Array([pt(0.0, -38.0), pt(0.0, -12.0)]), 0.6, 0.4)

	# la fleur de la rosette, de face : cinq pétales en cœur, l'œil doré, les sépales entre eux
	func _loupe_rosette() -> void:
		var c := pt(0.0, 4.0)
		fuseau(courbe(pt(-14.0, -46.0), pt(-10.0, -22.0), pt(-2.0, -4.0), 6), PackedFloat32Array([mm(3.4), mm(3.0)]), tige_c)
		for k in 5:
			var a := TAU * k / 5.0 - PI * 0.5 + TAU / 10.0
			var ec := etroit
			etroit = 1.0
			feuille(c, c + Vector2.from_angle(a) * mm(34.0), mm(5.0), vert, 0.0, {"pos": 0.5})
			etroit = ec
		corolle(c, mm(29.0), 5, fleur.lightened(0.12), -PI * 0.5, true)
		disque(c, mm(9.5), mm(9.5), MIEL.lerp(fleur, 0.2), 0.9)
		for k in 5:
			var a := TAU * k / 5.0 - PI * 0.5
			t.draw_circle(c + Vector2.from_angle(a) * mm(5.0), mm(1.7), P.TERRE)
		t.draw_circle(c, mm(2.2), vert.lightened(0.2))

	# la baie coupée : sa peau, sa chair, ses deux loges pleines de graines ; à côté, la baie entière et son calice
	func _loupe_morelle() -> void:
		var c := pt(7.0, -9.0)
		var col := fleur.lerp(P.LUNE, 0.14) if fleur.v < 0.3 else fleur
		var peau := ellipse(c, mm(31.0), mm(30.0))
		aplat(peau, col)
		var chair := ellipse(c, mm(27.0), mm(26.0))
		aplat(chair, col.lerp(P.PAPIER, 0.7))
		cerne(chair, 0.6)
		cerne(peau, 1.15)
		filet(lisser(PackedVector2Array([c + Vector2(mm(2.0), -mm(26.0)), c + Vector2(-mm(3.0), -mm(8.0)), c + Vector2(mm(3.0), mm(8.0)), c + Vector2(-mm(1.0), mm(26.0))]), 2), 0.8, 0.8)
		for cote in [-1.0, 1.0]:
			var loge := c + Vector2(float(cote) * mm(13.0), 0.0)
			disque(loge, mm(5.0), mm(11.0), col.lerp(P.PAPIER, 0.45), 0.6)
			for k in 8:
				var a := TAU * k / 8.0 + 0.3
				var q := loge + Vector2(cos(a) * mm(8.6), sin(a) * mm(15.5))
				if absf(q.x - c.x) < mm(4.0):
					continue
				disque(q, mm(2.3), mm(3.3), RACINE.lightened(0.15), 0.7)
		# la baie entière, en haut à gauche
		var b := pt(-24.0, 23.0)
		filet(courbe(pt(-36.0, 37.0), pt(-27.0, 41.0), b + Vector2(0.0, -mm(10.0)), 5), 1.1)
		baie(b, mm(11.0))
		for a in [-2.5, -1.57, -0.64]:
			var ec := etroit
			etroit = 1.0
			feuille(b + Vector2(0.0, -mm(10.0)), b + Vector2(0.0, -mm(10.0)) + Vector2.from_angle(float(a)) * mm(8.0), mm(2.4), vert, 0.0, {"pos": 0.5})
			etroit = ec

	# le capitule fendu : le réceptacle, les écailles armées de part et d'autre, les fleurons et leurs aigrettes
	func _loupe_chardon() -> void:
		fuseau(PackedVector2Array([pt(0.0, -48.0), pt(0.0, -30.0)]), PackedFloat32Array([mm(9.0), mm(10.0)]), tige_c)
		for cote in [-1.0, 1.0]:
			for j in 4:
				var a := pt(float(cote) * (8.0 + j * 3.0), -30.0 + j * 5.0)
				var b := pt(float(cote) * (25.0 + j * 2.5), -12.0 + j * 13.0)
				var ec := etroit
				etroit = 1.0
				feuille(a, b, mm(5.0), sombre.lerp(P.IVOIRE, 0.3), 0.14 * float(cote), {"pos": 0.5})
				etroit = ec
				filet(PackedVector2Array([b, b + (b - a).normalized() * mm(6.0)]), 0.9)
		var coupe := arrondir(PackedVector2Array([pt(-15.0, -30.0), pt(15.0, -30.0), pt(17.0, -22.0), pt(0.0, -16.0), pt(-17.0, -22.0)]), 1)
		aplat(coupe, P.PAPIER.lerp(vert, 0.25))
		cerne(coupe, 1.0)
		for i in 7:
			var x := -13.5 + i * 4.5
			var haut := 30.0 + 9.0 * (1.0 - absf(x) / 14.0)
			var penche := x * 0.9
			var pied := pt(x, -19.0 + absf(x) * 0.2)
			# l'akène, son aigrette, puis le tube du fleuron et ses lobes
			for k in 5:
				filet(PackedVector2Array([pied + Vector2(0.0, -mm(4.0)), pt(x + penche * 0.45 + (k - 2.0) * 2.6, 6.0 + absf(k - 2.0))]), 0.5, 0.36)
			disque(pied, mm(1.9), mm(3.6), P.PAPIER.lerp(RACINE, 0.6), 0.7)
			var bout := pt(x + penche, haut)
			fuseau(courbe(pied + Vector2(0.0, -mm(3.0)), pt(x + penche * 0.3, haut * 0.4), bout, 6), PackedFloat32Array([mm(2.0), mm(3.2)]), fleur if i % 2 == 0 else fleur.lightened(0.14))
			for a in [-0.6, 0.0, 0.6]:
				var d := (bout - pied).normalized().rotated(float(a))
				filet(PackedVector2Array([bout, bout + d * mm(5.0)]), 0.7)

	# la crosse de près : le stipe écailleux, la spirale, ses pennes roulées
	func _loupe_crosse() -> void:
		var stipe := tige_c if signe == "rouge" else tige_c.lerp(P.TERRE, 0.45)
		var ligne := courbe(pt(14.0, -50.0), pt(30.0, -30.0), pt(27.0, -4.0), 10)
		fuseau(ligne, PackedFloat32Array([mm(9.0), mm(9.5)]), stipe)
		ecailles(ligne, 0.0, 1.0, mm(3.4))
		spire(pt(27.0, -4.0), (pt(27.0, -4.0) - sur(ligne, 0.9)).normalized(), 1.0, mm(27.0), 1.7, mm(10.0), fleur.lerp(clair, 0.25))

	# une feuille de près : ses nervures, son bord, son duvet si elle en a
	func detail_feuille(forme: String) -> void:
		var a := pt(-33.0, -30.0)
		var b := pt(33.0, 33.0)
		fuseau(PackedVector2Array([pt(-43.0, -41.0), a + (b - a) * 0.04]), PackedFloat32Array([mm(4.0), mm(3.0)]), tige_c if signe == "rouge" else vert.lerp(P.IVOIRE, 0.3))
		var ec := etroit
		etroit = lerpf(1.0, etroit, 0.5)
		match forme:
			"clochette":
				feuille(a, b, mm(21.0), vert, 0.06, {"par": true, "pos": 0.5})
			"epi":
				feuille(a, b, mm(14.0), vert, 0.08, {"par": true, "pos": 0.5})
			"rosette":
				feuille(a, b, mm(23.0), vert.lerp(fleur, 0.38), 0.03, {"pos": 0.66, "nerv": 5})
			"morelle":
				feuille(a, b, mm(24.0), sombre.lerp(P.FEUILLE_SOMBRE, 0.25).lightened(0.14), 0.05, {"pos": 0.36, "dents": 4, "nerv": 4})
			"chardon":
				lame(a, b, mm(21.0), vert.lerp(P.IVOIRE, 0.22), 0.05, 4)
			"crosse":
				# (une penne, vue par dessous : ses sores, en deux rangs)
				feuille(a, b, mm(17.0), vert.lightened(0.06), 0.04, {"pos": 0.3, "dents": 9, "nerv": 5, "sores": 6})
			_:
				feuille(a, b, mm(19.0), vert, 0.04, {"pos": 0.42, "dents": 8, "nerv": 5})
		etroit = ec

	# la tige tranchée : sa peau, sa coupe (creuse, pour une ombelle) ; le lait qui en sourd
	func detail_tige(forme: String) -> void:
		var bas := pt(-9.0, -40.0)
		var haut := pt(5.0, 12.0)
		var d := (haut - bas).normalized()
		var nn := d.orthogonal()
		var l := mm(14.0)
		# le tronçon : rompu en bas, tranché net en haut
		var corps := PackedVector2Array([haut + nn * l, haut - nn * l, bas - nn * l, bas - nn * l * 0.4 + d * mm(5.0), bas + nn * l * 0.2 - d * mm(2.0), bas + nn * l * 0.7 + d * mm(4.0), bas + nn * l])
		aplat(corps, tige_c)
		ombrer(corps, mm(6.0), 0.26)
		cerne(corps, 1.1)
		for k in [-0.45, 0.2]:
			filet(PackedVector2Array([bas + nn * l * float(k) + d * mm(6.0), haut + nn * l * float(k) + d * mm(3.0)]), 0.6, 0.4)
		var rot := d.angle() + PI * 0.5
		var coupe := ellipse(haut, l, l * 0.46, rot)
		aplat(coupe, tige_c.lerp(P.PAPIER, 0.72))
		cerne(coupe, 1.1)
		if signe == "rouge":
			var anneau := ellipse(haut, l * 0.8, l * 0.36, rot)
			anneau.append(anneau[0])
			t.draw_polyline(anneau, Color(ROUGE_SANG, 0.7), 1.6, true)
		if forme == "ombelle":
			var creux := ellipse(haut, l * 0.52, l * 0.22, rot)
			aplat(creux, P.PAPIER.lerp(P.NUIT_BLEUE, 0.42))
			cerne(creux, 0.8)
		else:
			# (les faisceaux, en couronne ; la moelle)
			for k in 9:
				var a := TAU * k / 9.0
				t.draw_circle(haut + Vector2(cos(a) * l * 0.6, sin(a) * l * 0.26).rotated(rot), 1.0, Color(P.ENCRE, 0.55))
		# une cicatrice de feuille, sur le côté
		filet(courbe(bas + nn * l + d * mm(14.0), bas + nn * l * 0.5 + d * mm(17.0), bas + nn * l + d * mm(21.0), 5), 0.7, 0.7)
		if signe != "lait":
			return
		# le lait : il perle sur la coupe, coule le long de la tige, goutte
		var flaque := arrondir(PackedVector2Array([haut + Vector2(-l * 0.7, -l * 0.36), haut + Vector2(l * 0.3, -l * 0.44), haut + Vector2(l * 1.05, -l * 0.05), haut + Vector2(l * 0.95, l * 0.6),
			haut + Vector2(l * 0.3, l * 0.4), haut + Vector2(-l * 0.6, l * 0.26)]), 2)
		aplat(flaque, LAIT)
		cerne(flaque, 1.0)
		var coule := lisser(PackedVector2Array([haut + Vector2(l * 0.72, l * 0.3), haut + Vector2(l * 0.86, l * 1.2), haut + Vector2(l * 0.56, l * 2.2), haut + Vector2(l * 0.62, l * 2.9)]), 2)
		fuseau(coule, PackedFloat32Array([l * 0.5, l * 0.36, l * 0.46]), LAIT, 0.9)
		for g in [[haut + Vector2(l * 0.62, l * 3.1), 0.4], [haut + Vector2(l * 0.8, l * 4.2), 0.27]]:
			var c: Vector2 = g[0]
			var rg := l * float(g[1])
			var goutte := PackedVector2Array([c + Vector2(0.0, -rg * 1.9)])
			for i in 13:
				goutte.append(c + Vector2.from_angle(-PI * 0.18 + PI * 1.36 * i / 12.0) * rg)
			aplat(goutte, LAIT)
			cerne(goutte, 0.8)
			t.draw_circle(c + Vector2(-rg * 0.3, -rg * 0.2), maxf(rg * 0.22, 0.7), Color.WHITE)
		t.draw_line(haut + Vector2(-l * 0.2, -l * 0.12), haut + Vector2(l * 0.3, -l * 0.1), Color.WHITE, 1.2, true)
