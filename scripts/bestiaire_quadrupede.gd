extends RefCounted
# Lisière — un quadrupède, dessiné à l'encre (scripts/bestiaire_quadrupede.gd)
# La bête de profil, tournée vers la droite, d'après le plan de corps de sa lignée (p.corps) : la longueur de son corps (long),
# la hauteur de ses pattes (haut), son cou, sa tête, son museau, ses oreilles, sa queue, ses cornes, sa crête, sa carapace, son
# motif ; sa masse dit si elle est frêle ou massive (p.robustesse), sa façon de se déplacer plie ses pattes (course, saut,
# fouissage, grimpe), son régime fait sa tête (le museau en coin et l'oreille dressée d'un chasseur, le mufle rond et l'oreille
# en feuille d'un brouteur). Elle dessine sur la planche p (scripts/bestiaire_planche.gd), dans quatre calques : la queue (qui
# balance), le corps, le dessus (ce qui passe devant les pattes proches), la tête et le cou (qui pivotent).

const Planche := preload("res://scripts/bestiaire_planche.gd")


static func dessiner(p) -> void:
	var c: Dictionary = p.corps
	var rob: float = p.robustesse
	var loco: Array = p.locomotion
	var course := loco.has("course")
	var saut := loco.has("saut") and not course
	var fouit := loco.has("fouissage") and not course
	var grimpe := loco.has("grimpe")
	var T: Dictionary = p.tons
	# --- les mesures, d'abord sans échelle (u = 1), puis mises à la largeur de la planche ---
	var long := float(c.get("long", 0.5))
	var lt := 0.3 + 0.32 * long                                   # la longueur du corps
	var th := 0.14 + 0.1 * rob + 0.04 * (1.0 - long)              # son épaisseur
	var hl := (0.06 + 0.34 * float(c.get("haut", 0.3))) * (0.7 if fouit else 1.0) * (1.2 if p.traits.has("pattes-longues") else 1.0)
	var tl := 0.03 + 0.42 * float(c.get("queue", 0.3))            # la queue
	var hs := 0.085 + 0.1 * float(c.get("tete", 0.4))             # la tête
	var cl := 0.03 + 0.2 * float(c.get("cou", 0.2))               # le cou
	var ml := 0.012 + 0.12 * float(c.get("museau", 0.4))          # le museau
	var naturel := tl * 0.9 + lt + cl * 0.8 + hs * 0.9 + ml
	var u: float = p.L * 0.96 / naturel
	var haut_naturel := hl + th + cl + hs
	if haut_naturel * u > p.L * 1.0:
		u = p.L * 1.0 / haut_naturel
	lt *= u
	th *= u
	hl *= u
	tl *= u
	hs *= u
	cl *= u
	ml *= u
	# (le corps est centré entre le bout de la queue et le bout du nez : l'origine tombe sous son milieu)
	var dx := (tl * 0.9 - (cl * 0.8 + hs * 0.9 + ml)) * 0.5
	var xa := lt * 0.5 + dx          # le poitrail
	var xr := -lt * 0.5 + dx         # la croupe
	var yb := -hl - th * 0.45        # le milieu du corps
	var top := yb - th * 0.5
	var bot := yb + th * 0.5
	var bosse := th * (0.06 + 0.16 * rob) * (1.25 if course else 1.0)     # le garrot
	var creux := th * 0.14 * rob                                         # le ventre qui pend
	var xf := xa - lt * 0.17         # les pattes de devant
	var xh := xr + lt * 0.2          # celles de derrière
	var yt := yb + th * 0.1          # la hauteur des hanches
	p.ombre(dx, lt * 0.58)

	# --- la queue (derrière le corps) ---
	if float(c.get("queue", 0.0)) > 0.06:
		var racine := Vector2(xr + th * 0.12, yb - th * 0.2)
		var q1: Vector2
		var q2: Vector2
		if grimpe or p.traits.has("queue-prehensile"):
			q1 = Vector2(xr - tl * 0.7, yb + tl * 0.35)
			q2 = Vector2(xr - tl * 0.72, yb - tl * 0.12)
		elif course:
			q1 = Vector2(xr - tl * 0.5, yb - th * 0.32)
			q2 = Vector2(xr - tl, yb - th * 0.15 - tl * 0.14)
		elif rob > 0.6:
			q1 = Vector2(xr - tl * 0.35, yb)
			q2 = Vector2(xr - tl * 0.45, yb + tl * 0.7)
		else:
			q1 = Vector2(xr - tl * 0.5, yb - tl * 0.22)
			q2 = Vector2(xr - tl * 0.95, yb + tl * 0.06)
		var ligne := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			ligne.append(racine.lerp(q1, t).lerp(q1.lerp(q2, t), t))
		p.calque("queue")
		p.pivot("queue", racine)
		var w0 := th * (0.2 + 0.2 * rob)
		var dq := Planche.ruban(ligne, w0, maxf(p.e * 0.9, w0 * 0.3))
		p.volume(dq, T["robe"], func():
			p.aplat(Planche.ruban(ligne, w0 * 0.5, w0 * 0.1), T["dos"], 0.45)
			if str(c.get("motif", "")) in ["bandes", "rayures"]:
				p.bandes(q2.x, racine.x, minf(q2.y, racine.y) - w0, maxf(q2.y, racine.y) + w0, 4, 0.0, tl * 0.08, T["dos"], 0.7))

	# --- les pattes du côté lointain ---
	var wp := th * (0.3 + 0.16 * rob)        # la largeur d'une cuisse
	var pied := "coussinet"
	if p.regime == "carnivore" or fouit:
		pied = "griffes"
	elif rob > 0.3 and not grimpe:
		pied = "sabot"
	_patte(p, xf + lt * 0.07, true, true, yt, hl, th, wp, course, saut, fouit, rob, pied)
	_patte(p, xh + lt * 0.07, false, true, yt, hl, th, wp, course, saut, fouit, rob, pied)

	# --- le corps ---
	var silhouette: PackedVector2Array = p.vivant(PackedVector2Array([
		Vector2(xr, yb - th * 0.05), Vector2(xr + lt * 0.16, top + th * 0.02), Vector2(dx, top - bosse * 0.3),
		Vector2(xa - lt * 0.24, top - bosse), Vector2(xa - lt * 0.02, yb - th * 0.22), Vector2(xa - lt * 0.05, yb + th * 0.3),
		Vector2(xa - lt * 0.22, bot + creux * 0.5), Vector2(dx, bot + creux * 1.4), Vector2(xr + lt * 0.2, bot + th * 0.02),
		Vector2(xr + lt * 0.03, yb + th * 0.3)]), p.e * 0.25)
	var d_corps := Planche.ferme(silhouette, 1.0)
	p.calque("corps")
	p.volume(d_corps, T["robe"], func():
		# (le dos, plus sombre, fondu ; le ventre, plus pâle)
		p.aplat(Planche.ferme(PackedVector2Array([Vector2(xr - 2.0, top - bosse - 4.0), Vector2(xa + 2.0, top - bosse - 4.0), Vector2(xa, top + th * 0.2),
			Vector2(dx, top + th * 0.3), Vector2(xr, top + th * 0.24)]), 0.8), T["dos"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(dx + lt * 0.03, bot + creux), lt * 0.4, th * 0.26, 10), 1.0), T["ventre"], 0.85)
		_motif(p, c, xr, xa, top - bosse, bot + creux * 1.5, th)
		# (l'ombre sous le ventre, le poil du dos, le pli de la cuisse)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(dx, bot + creux * 1.6 + th * 0.08), lt * 0.5, th * 0.16, 10), 1.0), T["encre"], 0.22)
		p.poils(PackedVector2Array([Vector2(xr + lt * 0.12, top + th * 0.1), Vector2(dx, top - bosse * 0.2 + th * 0.08), Vector2(xa - lt * 0.26, top - bosse + th * 0.1)]),
			th * 0.16, 2.2, 3.2)
		p.hachures(Vector2(xh - wp * 0.2, yt - th * 0.25), Vector2(xh + wp * 0.9, yt + th * 0.2), 4, th * 0.2, 1.9))

	# --- les pattes du côté proche, puis ce qui passe devant elles ---
	_patte(p, xf, true, false, yt, hl, th, wp, course, saut, fouit, rob, pied)
	_patte(p, xh, false, false, yt, hl, th, wp, course, saut, fouit, rob, pied)
	p.calque("dessus")
	# (l'épaule et la cuisse : un aplat de la robe fond le haut de la patte dans le corps, un trait d'encre dit le muscle)
	for x in [xf, xh]:
		var rr := wp * (0.9 if x == xf else 1.15)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(x, yt - th * 0.12), rr, th * 0.34, 8), 1.0), T["robe"], 1.0)
		p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(x - rr * 0.95, yt - th * 0.1)), Planche.pt(Vector2(x - rr * 0.2, yt + th * 0.42)), Planche.pt(Vector2(x + rr * 0.9, yt + th * 0.05))],
			p.e * 0.6, T["encre"], 0.6)
	if float(c.get("carapace", 0.0)) > 0.3:
		_carapace(p, xr, xa, top - bosse, th, lt, dx, float(c.get("carapace", 0.0)))
	if float(c.get("crete", 0.0)) > 0.1:
		_crete(p, xr + lt * 0.2, xa - lt * 0.2, top - bosse * 0.6, th * (0.2 + 0.7 * float(c.get("crete", 0.0))))

	# --- le cou et la tête ---
	var angle := lerpf(0.2, 0.95, clampf(float(c.get("cou", 0.2)) * 1.4 + (0.2 if p.chasseur else 0.0), 0.0, 1.0))
	var base := Vector2(xa - lt * 0.1, yb - th * 0.18)
	var tete := Vector2(xa + cl * cos(angle) + hs * 0.35, top - bosse * 0.4 - cl * sin(angle) - hs * 0.05)
	p.calque("tete")
	p.pivot("tete", base)
	var cou := PackedVector2Array([base, base.lerp(tete, 0.5) + Vector2(-hs * 0.05, hs * 0.04), tete + Vector2(-hs * 0.2, hs * 0.1)])
	# (le cou sort du corps : cerné sur ses deux côtés seulement, sans trait en travers)
	p.volume(Planche.ruban(cou, th * 0.86, hs * 0.72), T["robe"], func():
		p.aplat(Planche.ruban(PackedVector2Array([cou[0] + Vector2(0, -th * 0.3), cou[1] + Vector2(-hs * 0.1, -hs * 0.3), cou[2] + Vector2(0, -hs * 0.3)]), th * 0.4, hs * 0.3), T["dos"], 0.45)
		p.aplat(Planche.ruban(PackedVector2Array([cou[0] + Vector2(th * 0.1, th * 0.36), cou[2] + Vector2(hs * 0.1, hs * 0.32)]), th * 0.3, hs * 0.26), T["ventre"], 0.7),
		{"lourd": false, "cerne": 0.0})
	for bord in Planche.bords(cou, th * 0.86, hs * 0.72):
		p.cerne(Planche.ouvert(bord.slice(1)))
	_tete(p, c, tete, hs, ml)


# une patte, d'après sa façon de se déplacer : droite comme un pilier chez un massif, pliée en trois chez un coureur, repliée
# sous une grosse cuisse chez un sauteur, courte et écartée chez un fouisseur
static func _patte(p, x: float, devant: bool, loin: bool, yt: float, hl: float, th: float, wp: float, course: bool, saut: bool, fouit: bool, rob: float, pied: String) -> void:
	var hanche := Vector2(x, yt)
	var bas := -yt
	var pts: PackedVector2Array
	var larg: Array
	if saut and not devant:
		pts = PackedVector2Array([hanche + Vector2(th * 0.1, th * 0.1), Vector2(x + bas * 0.42, -bas * 0.42), Vector2(x - bas * 0.2, -bas * 0.12), Vector2(x + bas * 0.16, 0.0)])
		larg = [wp * 1.5, wp * 0.8, wp * 0.5, wp * 0.46]
	elif course:
		if devant:
			pts = PackedVector2Array([hanche, Vector2(x + bas * 0.06, -bas * 0.5), Vector2(x, 0.0)])
			larg = [wp, wp * 0.62, wp * 0.44]
		else:
			pts = PackedVector2Array([hanche, Vector2(x + bas * 0.2, -bas * 0.6), Vector2(x - bas * 0.14, -bas * 0.24), Vector2(x - bas * 0.02, 0.0)])
			larg = [wp * 1.25, wp * 0.7, wp * 0.48, wp * 0.44]
	elif rob > 0.65:
		pts = PackedVector2Array([hanche, Vector2(x + (0.6 if devant else -0.6), -bas * 0.48), Vector2(x, 0.0)])
		larg = [wp * 1.2, wp * 1.0, wp * 0.92]
	elif fouit:
		pts = PackedVector2Array([hanche, Vector2(x + bas * (0.22 if devant else -0.22), -bas * 0.45), Vector2(x + bas * (0.34 if devant else 0.0), 0.0)])
		larg = [wp * 1.1, wp * 0.8, wp * 0.66]
	else:
		pts = PackedVector2Array([hanche, Vector2(x + bas * (0.1 if devant else -0.12), -bas * 0.5), Vector2(x, 0.0)])
		larg = [wp * (1.0 if devant else 1.2), wp * 0.68, wp * 0.5]
	p.patte(pts, larg, loin, {"pied": pied, "pied_taille": 1.25 if pied != "sabot" else 1.1, "poilu": not devant})


# le motif de la robe, découpé au corps : des bandes larges, des rayures fines, des taches ; le masque est sur la tête
static func _motif(p, c: Dictionary, x0: float, x1: float, y0: float, y1: float, th: float) -> void:
	match str(c.get("motif", "uni")):
		"bandes":
			p.bandes(x0 + (x1 - x0) * 0.12, x1 - (x1 - x0) * 0.1, y0, y0 + (y1 - y0) * 0.72, 4, th * 0.1, (x1 - x0) * 0.09, p.tons["dos"], 0.62)
		"rayures":
			p.bandes(x0 + (x1 - x0) * 0.08, x1 - (x1 - x0) * 0.06, y0, y0 + (y1 - y0) * 0.66, 8, th * 0.16, (x1 - x0) * 0.035, p.tons["dos"], 0.7)
		"taches":
			p.taches(Rect2(x0 + (x1 - x0) * 0.08, y0 + (y1 - y0) * 0.1, (x1 - x0) * 0.84, (y1 - y0) * 0.55), 9, th * 0.06, th * 0.13, p.tons["dos"], 0.62)


# la tête : le crâne, le museau selon le régime, l'oreille, l'œil, les cornes
static func _tete(p, c: Dictionary, o: Vector2, hs: float, ml: float) -> void:
	var T: Dictionary = p.tons
	var carn: bool = p.regime == "carnivore"
	# l'oreille du côté lointain, puis les cornes, derrière le crâne
	var oreilles := float(c.get("oreilles", 0.0))
	if oreilles > 0.12:
		_oreille(p, o + Vector2(-hs * 0.22, -hs * 0.36), hs * (0.3 + 1.0 * oreilles), carn, true)
	var cornes := float(c.get("cornes", 0.0))
	if cornes > 0.1:
		_corne(p, o + Vector2(-hs * 0.02, -hs * 0.4), hs * (0.5 + 1.4 * cornes), true)
	# le crâne et le museau, d'une seule forme
	var bout: Vector2
	var pts: PackedVector2Array
	if carn:
		# (un coin : le front fuyant, le museau long, la mâchoire droite)
		bout = o + Vector2(hs * 0.5 + ml, hs * 0.1)
		pts = PackedVector2Array([o + Vector2(-hs * 0.56, -hs * 0.02), o + Vector2(-hs * 0.3, -hs * 0.44), o + Vector2(hs * 0.18, -hs * 0.4),
			o + Vector2(hs * 0.42 + ml * 0.55, -hs * 0.16), bout + Vector2(0, -hs * 0.1), bout + Vector2(-hs * 0.02, hs * 0.12),
			o + Vector2(hs * 0.3 + ml * 0.5, hs * 0.3), o + Vector2(-hs * 0.1, hs * 0.44), o + Vector2(-hs * 0.48, hs * 0.3)])
	else:
		# (un mufle : le front rond, le museau plein)
		var r := 0.3 if p.regime == "omnivore" else 0.38
		bout = o + Vector2(hs * 0.42 + ml * 0.9, hs * 0.12)
		pts = PackedVector2Array([o + Vector2(-hs * 0.56, 0.0), o + Vector2(-hs * 0.34, -hs * 0.42), o + Vector2(hs * 0.14, -hs * 0.44),
			o + Vector2(hs * 0.4 + ml * 0.4, -hs * 0.2), bout + Vector2(0, -hs * r * 0.6), bout + Vector2(hs * 0.04, hs * r * 0.5),
			o + Vector2(hs * 0.3 + ml * 0.4, hs * 0.36), o + Vector2(-hs * 0.12, hs * 0.44), o + Vector2(-hs * 0.5, hs * 0.3)])
	var d := Planche.ferme(p.vivant(pts, p.e * 0.15), 1.0)
	p.volume(d, T["robe"], func():
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(-hs * 0.1, -hs * 0.42), hs * 0.6, hs * 0.22, 8), 1.0), T["dos"], 0.45)
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.2 + ml * 0.4, hs * 0.36), hs * 0.5 + ml * 0.4, hs * 0.2, 8), 1.0), T["ventre"], 0.8)
		if str(c.get("motif", "")) == "masque":
			p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.16, -hs * 0.1), hs * 0.5, hs * 0.2, 8, -0.1), 1.0), T["dos"], 0.85))
	# la truffe, la gueule
	p.aplat(Planche.ferme(Planche.ellipse(bout + Vector2(-hs * 0.03, -hs * 0.05), hs * 0.1, hs * 0.08, 6), 1.0), T["truffe"])
	p.tracer("M%s Q%s %s" % [Planche.pt(bout + Vector2(-hs * 0.05, hs * 0.1)), Planche.pt(bout + Vector2(-ml * 0.5 - hs * 0.1, hs * 0.2)), Planche.pt(o + Vector2(hs * 0.14, hs * 0.2))],
		p.e * 0.6, T["encre"], 0.85)
	if carn and (p.robustesse > 0.2 or p.traits.has("crocs-allonges")):
		# (un croc, clair, qui dépasse)
		var lc: float = hs * (0.4 if p.traits.has("crocs-allonges") else 0.2)
		var b := bout + Vector2(-ml * 0.35 - hs * 0.08, hs * 0.12)
		p.svg("<path d=\"M%s L%s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(b), Planche.pt(b + Vector2(hs * 0.04, lc)), Planche.pt(b + Vector2(hs * 0.12, 0)),
			Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(p.e * 0.4)])
	# l'œil
	p.oeil(o + Vector2(hs * (0.2 if carn else 0.1), -hs * 0.1), hs * 0.13)
	# l'oreille et la corne du côté proche
	if oreilles > 0.12:
		_oreille(p, o + Vector2(-hs * 0.36, -hs * 0.3), hs * (0.3 + 1.0 * oreilles), carn, false)
	if cornes > 0.1:
		_corne(p, o + Vector2(-hs * 0.14, -hs * 0.38), hs * (0.5 + 1.4 * cornes), false)


# une oreille : dressée et pointue chez un chasseur, en feuille couchée vers l'arrière chez un brouteur
static func _oreille(p, o: Vector2, l: float, pointue: bool, loin: bool) -> void:
	var T: Dictionary = p.tons
	var teinte: Color = T["loin"] if loin else T["robe"]
	var pts: PackedVector2Array
	if pointue:
		pts = PackedVector2Array([o + Vector2(-l * 0.2, 0), o + Vector2(l * 0.02, -l), o + Vector2(l * 0.32, -l * 0.08)])
	else:
		var d := Vector2(-0.62, -0.78)
		var t := d.orthogonal()
		pts = PackedVector2Array([o, o + d * l * 0.45 + t * l * 0.24, o + d * l, o + d * l * 0.5 - t * l * 0.2])
	var dd := Planche.ferme(pts, 0.7 if pointue else 1.0)
	p.volume(dd, teinte, func():
		if not loin:
			# (le creux de l'oreille)
			var m := (pts[0] + pts[1] + pts[2]) / 3.0
			p.aplat(Planche.ferme(Planche.ellipse(m, l * 0.1, l * 0.24, 6, -0.25 if pointue else 0.65), 1.0), T["accent"], 0.5),
		{"lourd": false, "cerne": 0.85})


# une corne : un ruban d'os, courbé vers l'arrière
static func _corne(p, o: Vector2, l: float, loin: bool) -> void:
	var T: Dictionary = p.tons
	var ligne := PackedVector2Array([o, o + Vector2(-l * 0.1, -l * 0.5), o + Vector2(-l * 0.42, -l * 0.9)])
	var teinte: Color = T["os"].darkened(0.3) if loin else T["os"]
	p.volume(Planche.ruban(ligne, maxf(p.e * 1.6, l * 0.2), p.e * 0.7), teinte, Callable(), {"lourd": false, "cerne": 0.8})


# une crête : une rangée de pointes le long du dos
static func _crete(p, x0: float, x1: float, y: float, h: float) -> void:
	var T: Dictionary = p.tons
	var m := 6
	var pts := PackedVector2Array([Vector2(x0, y + 1.0)])
	for i in m:
		var x := lerpf(x0, x1, (i + 0.5) / m)
		pts.append(Vector2(x - (x1 - x0) / m * 0.2, y - h * (0.75 + 0.25 * sin(i * 1.7))))
		pts.append(Vector2(x + (x1 - x0) / m * 0.5, y - h * 0.15))
	pts.append(Vector2(x1, y + 1.0))
	p.volume(Planche.poly(pts), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})


# une carapace : un dôme sur le dos, ses plaques
static func _carapace(p, xr: float, xa: float, top: float, th: float, lt: float, dx: float, taille: float) -> void:
	var T: Dictionary = p.tons
	var h := th * (0.35 + 0.4 * taille)
	var pts := PackedVector2Array([Vector2(xr + lt * 0.04, top + th * 0.5), Vector2(xr + lt * 0.2, top - h * 0.7), Vector2(dx, top - h),
		Vector2(xa - lt * 0.2, top - h * 0.75), Vector2(xa - lt * 0.05, top + th * 0.45), Vector2(dx, top + th * 0.62)])
	p.volume(Planche.ferme(pts, 1.0), T["dos"], func():
		for i in 4:
			var x := lerpf(xr + lt * 0.2, xa - lt * 0.2, i / 3.0)
			p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(x, top - h)), Planche.pt(Vector2(x + lt * 0.03, top)), Planche.pt(Vector2(x, top + th * 0.6))], p.e * 0.55, T["encre"], 0.6)
		p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(xr + lt * 0.1, top + th * 0.05)), Planche.pt(Vector2(dx, top - h * 0.5)), Planche.pt(Vector2(xa - lt * 0.1, top + th * 0.05))], p.e * 0.55, T["encre"], 0.5))
