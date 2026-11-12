extends RefCounted
# Lisière — un oiseau, un bipède, dessinés à l'encre (scripts/bestiaire_oiseau.gd)
# Deux bêtes à deux pattes, de profil, tournées vers la droite, d'après le plan de corps de leur lignée (p.corps).
#  - L'oiseau : un corps en œuf, penché ; l'aile repliée sur le flanc, avec ses rémiges ; les plumes de la queue (un éventail
#    si l'organe « panache » le dit) ; le cou (cou : du moineau au héron) ; le bec d'après ce qu'il mange (crochu pour un
#    rapace, en poignard pour un pêcheur, conique pour un mangeur de graines, gros pour un mangeur de fruits, plat pour un
#    filtreur) et sa longueur d'après museau ; une huppe ou une aigrette (crete), une fraise (collerette) ; des pattes fines
#    (haut : de la caille à l'échassier), aux doigts écartés. Sa matière : des plumes, en rangs de petits arcs.
#  - Le bipède : un corps tenu à l'horizontale sur deux fortes pattes arrière, une longue queue en balancier, deux petits
#    bras (des mains si l'organe le dit ; alors, ou sans queue, il se tient debout), la tête d'après son régime : quelque
#    chose d'un petit théropode.
# Les calques : la queue (elle balance), le corps, le dessus (l'aile, la cuisse, le bras proche, une cuirasse : ce qui passe
# devant la patte proche), la tête et le cou (ils pivotent à la base du cou). Une patte de chaque côté : le jeu les fait
# marcher en alternance, et la tête avance à chaque pas (scripts/bete.gd).

const Planche := preload("res://scripts/bestiaire_planche.gd")


static func dessiner(p) -> void:
	if str(p.corps.get("forme", "")) == "bipede":
		_bipede(p)
	else:
		_oiseau(p)


# un organe de la lignée ({} : elle ne l'a pas)
static func _og(c: Dictionary, type: String, place := "") -> Dictionary:
	var o = c.get("organes", [])
	if typeof(o) == TYPE_ARRAY:
		for x in o:
			if typeof(x) == TYPE_DICTIONARY and str(x.get("type", "")) == type and (place == "" or str(x.get("place", "")) == place):
				return x
	return {}


# une pointe (une griffe, une épine, une dent) : un triangle fin, de sa base à son bout
static func _pointe(p, base: Vector2, bout: Vector2, large: float, teinte: Color) -> void:
	var t := (bout - base).normalized().orthogonal() * large * 0.5
	p.volume(Planche.poly(PackedVector2Array([base + t, bout, base - t])), teinte, Callable(), {"lourd": false, "cerne": 0.7, "plat": true})


# une forme ouverte du côté où elle sort d'une autre : peinte sans trait, puis cernée seulement le long de « bord »
static func _sortant(p, d: String, bord: PackedVector2Array, teinte: Color, dedans := Callable(), k := 1.0) -> void:
	p.volume(d, teinte, dedans, {"lourd": false, "cerne": 0.0})
	p.cerne(Planche.ouvert(bord), k)


# ============================================================ L'OISEAU ============================================================

# le bec, d'après ce qu'il mange
static func _genre_bec(p, c: Dictionary) -> String:
	var diete = p.plan.get("diete", {})
	var fruits := float(diete.get("fruits", 0.0)) if typeof(diete) == TYPE_DICTIONARY else 0.0
	if p.regime == "carnivore":
		if p.locomotion.has("nage") or (float(c.get("cou", 0.0)) >= 0.55 and float(c.get("museau", 0.0)) >= 0.55):
			return "poignard"
		return "crochu"
	if p.regime == "filtreur" or p.regime == "detritivore":
		return "plat"
	if fruits >= 0.4:
		return "gros"
	if p.regime == "omnivore":
		return "droit"
	return "conique"


# où sont les choses, pour un oiseau à l'échelle u (u = 1 : pour le mesurer), décalé de dx
static func _mesures_oiseau(p, c: Dictionary, u: float, dx: float) -> Dictionary:
	var rob: float = p.robustesse
	var loco: Array = p.locomotion
	var cou := float(c.get("cou", 0.2))
	var haut := float(c.get("haut", 0.3))
	var m := {}
	var Lt := u * (0.27 + 0.2 * float(c.get("long", 0.5)))                 # la longueur du corps
	var Th := u * (0.165 + 0.08 * rob) * (1.0 if p.chasseur else 1.07)     # son épaisseur (une proie est plus ronde)
	var Hl := u * (0.05 + 0.4 * haut) * (1.15 if loco.has("nage") and haut > 0.5 else 1.0)   # ses pattes, sous le ventre
	var hs := u * (0.105 + 0.06 * float(c.get("tete", 0.4)))              # la tête
	var nl := u * 0.3 * pow(cou, 1.3)                                      # le cou
	var tl := u * (0.09 + 0.36 * float(c.get("queue", 0.3)))              # la queue
	var ailes := float(_og(c, "ailes").get("taille", c.get("ailes", 0.5)))
	var penche := clampf(0.2 + 0.3 * cou + 0.2 * (float(c.get("posture", 1.0)) - 1.0) - (0.12 if loco.has("course") else 0.0), 0.06, 0.55)
	var X := Vector2(cos(penche), -sin(penche))
	var Y := Vector2(sin(penche), cos(penche))
	var C := Vector2(dx, -Hl - Th * 0.5)
	var M := Transform2D(X * Lt, Y * Th, C)                                # (le repère du corps : x vers le poitrail, y vers le ventre)
	var genre := _genre_bec(p, c)
	var bl: float = hs * (0.4 + 1.2 * float(c.get("museau", 0.4))) * float({"crochu": 0.72, "poignard": 1.45, "plat": 1.2, "gros": 1.15, "droit": 0.9, "conique": 0.58}[genre])
	# le cou monte d'autant plus droit qu'il est long ; un chasseur porte la tête en avant
	var ang := lerpf(0.7, 1.3, clampf(cou * 1.25, 0.0, 1.0)) - (0.12 if p.chasseur else 0.0)
	var base := M * Vector2(0.3, -0.2)
	var tete := base + Vector2(cos(ang), -sin(ang)) * (Th * 0.3 + nl + hs * 0.28)
	var racine := M * Vector2(-0.4, -0.1)
	var dq := Vector2(-cos(penche * 0.6), sin(penche * 0.6))
	var al := 0.5 + 0.5 * ailes                                            # l'aile repliée, en longueurs de corps
	var bout_aile := M * Vector2(0.3 - al, -0.06)
	var panache := _og(c, "panache")
	var t_pan := float(panache.get("taille", 0.5))
	var crete := _og(c, "crete", "tete")
	var t_crete := float(crete.get("taille", c.get("crete", 0.0)))
	m["x0"] = minf(racine.x + dq.x * tl, bout_aile.x) - (0.0 if panache.is_empty() else tl * (0.25 + 0.5 * t_pan))
	m["x1"] = tete.x + hs * 0.42 + bl
	m["y0"] = minf(tete.y - hs * (0.52 + (0.2 + 0.7 * t_crete if t_crete > 0.1 else 0.0)),
		racine.y - (tl * (1.0 + 0.7 * t_pan) if str(panache.get("forme", "")) == "eventail" else 0.0))
	m.merge({"Lt": Lt, "Th": Th, "Hl": Hl, "hs": hs, "nl": nl, "tl": tl, "bl": bl, "ailes": ailes, "al": al, "penche": penche, "X": X, "Y": Y, "C": C, "M": M,
		"genre": genre, "ang": ang, "base": base, "tete": tete, "racine": racine, "dq": dq, "cou": cou, "haut": haut, "t_crete": t_crete, "crete": crete, "panache": panache})
	return m


static func _oiseau(p) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var L: float = p.L
	var e: float = p.e
	var rob: float = p.robustesse
	# on mesure d'abord sans échelle, puis on met l'oiseau à la largeur de la planche (et pas plus haut qu'elle)
	var m := _mesures_oiseau(p, c, 1.0, 0.0)
	var u: float = L * 0.96 / (float(m["x1"]) - float(m["x0"]))
	if -float(m["y0"]) * u > L * 0.92:
		u = L * 0.92 / -float(m["y0"])
	m = _mesures_oiseau(p, c, u, -(float(m["x0"]) + float(m["x1"])) * 0.5 * u)
	var M: Transform2D = m["M"]
	var Lt: float = m["Lt"]
	var Th: float = m["Th"]
	var C: Vector2 = m["C"]
	var X: Vector2 = m["X"]
	var motif := str(c.get("motif", "uni"))
	var carn: bool = p.regime == "carnivore"
	p.ombre(C.x, Lt * 0.5)

	# --- la queue : ses plumes, derrière le corps ---
	_queue_oiseau(p, c, m)

	# --- les pattes : fines, le talon en arrière, les doigts écartés ---
	var hanche := M * Vector2(-0.03, 0.2)
	var hy := -hanche.y
	var pied_x := C.x + Lt * 0.03
	var wt := maxf(1.5, u * (0.014 + 0.013 * rob)) * (1.2 if carn else 1.0)   # le tarse (fort chez un rapace)
	var wc := maxf(wt * 1.5, Th * (0.2 + 0.1 * rob)) * (1.2 if carn else 1.0)   # le haut du pilon, dans les plumes
	var recul := hy * (0.27 if p.locomotion.has("course") else 0.21)       # le talon, en arrière
	var teinte_patte: Color = T["os"] if carn else T["os"].lerp(T["accent"], 0.45).darkened(0.12)
	var opts := {"teinte": teinte_patte, "pied": "doigts", "pied_taille": clampf(Th * (0.17 if carn else 0.14) / wt, 1.2, 2.4), "pied_teinte": teinte_patte}
	var loin_opts := opts.duplicate()
	loin_opts["teinte"] = teinte_patte.darkened(0.3).lerp(T["loin"], 0.3)
	loin_opts["pied_teinte"] = loin_opts["teinte"]
	# (au repos : la patte proche un peu en arrière, l'autre un peu en avant)
	var pied_p := Vector2(pied_x - Lt * 0.05, 0.0)
	var pied_l := Vector2(pied_x + Lt * 0.17, 0.0)
	var talon_p := pied_p + Vector2(-recul, -hy * 0.47)
	p.patte(PackedVector2Array([hanche + Vector2(Lt * 0.09, -Th * 0.04), pied_l + Vector2(-recul, -hy * 0.47), pied_l]), [wc * 0.9, wt * 1.1, wt], true, loin_opts)
	p.patte(PackedVector2Array([hanche, talon_p, pied_p]), [wc, wt * 1.15, wt], false, opts)

	# --- le corps : un œuf, le gros bout au poitrail ---
	var oeuf: PackedVector2Array = p.vivant(M * PackedVector2Array([Vector2(-0.5, -0.02), Vector2(-0.3, -0.36), Vector2(0.02, -0.5), Vector2(0.3, -0.42), Vector2(0.48, -0.1),
		Vector2(0.44, 0.24), Vector2(0.2, 0.48), Vector2(-0.12, 0.46), Vector2(-0.38, 0.24)]), e * 0.2)
	p.calque("corps")
	p.volume(Planche.ferme(oeuf, 1.0), T["robe"], func():
		p.aplat(Planche.ferme(M * PackedVector2Array([Vector2(-0.7, -0.8), Vector2(0.6, -0.8), Vector2(0.5, -0.22), Vector2(0.0, -0.26), Vector2(-0.55, -0.08)]), 0.8), T["dos"], 0.45)
		p.aplat(Planche.ferme(Planche.ellipse(M * Vector2(0.14, 0.36), Lt * 0.4, Th * 0.3, 10, X.angle()), 1.0), T["ventre"], 0.85)
		match motif:
			"rayures":
				# (le poitrail barré d'un épervier)
				var d := ""
				for i in 4:
					var y := -0.08 + 0.15 * i
					d += Planche.ouvert(M * PackedVector2Array([Vector2(-0.2 + 0.03 * i, y + 0.05), Vector2(0.12, y + 0.07), Vector2(0.5, y - 0.06)]))
				p.tracer(d, maxf(0.8, Th * 0.065), T["dos"], 0.75)
			"bandes":
				# (un plastron sombre en travers du poitrail)
				p.aplat(Planche.ferme(M * PackedVector2Array([Vector2(0.16, -0.5), Vector2(0.4, -0.5), Vector2(0.56, 0.12), Vector2(0.3, 0.3), Vector2(0.22, -0.05)]), 0.8), T["dos"], 0.75)
			"taches":
				var o: Vector2 = M * Vector2(0.14, 0.14)
				p.taches(Rect2(o - Vector2(Lt * 0.3, Th * 0.26), Vector2(Lt * 0.6, Th * 0.52)), 8, maxf(0.6, Th * 0.04), maxf(0.9, Th * 0.075), T["dos"], 0.75)
		# (les plumes du poitrail : des rangs de petits arcs ; l'ombre sous le ventre)
		if L >= 44.0:
			var da := ""
			for r in 3:
				for k in 3 + r % 2:
					var q := Vector2(0.36 - 0.13 * k - 0.06 * (r % 2), -0.06 + 0.16 * r)
					da += "M%s Q%s %s" % [Planche.pt(M * (q + Vector2(-0.045, 0.0))), Planche.pt(M * (q + Vector2(0.0, 0.1))), Planche.pt(M * (q + Vector2(0.045, 0.0)))]
			p.tracer(da, maxf(0.45, e * 0.38), T["encre"], 0.42)
		p.aplat(Planche.ferme(Planche.ellipse(M * Vector2(-0.04, 0.58), Lt * 0.46, Th * 0.15, 10, X.angle()), 1.0), T["encre"], 0.22))

	# --- le dessus : la culotte de plumes en haut de la patte proche, puis l'aile repliée ---
	p.calque("dessus")
	if float(m["haut"]) >= 0.22:
		var bas_c := hanche.lerp(talon_p, clampf(0.62 - 0.4 * float(m["haut"]), 0.22, 0.6) + 0.25)
		var culotte := PackedVector2Array([hanche + Vector2(-wc * 1.0, -Th * 0.12), hanche + Vector2(wc * 1.0, -Th * 0.12), hanche.lerp(bas_c, 0.6) + Vector2(wc * 0.62, 0.0), bas_c + Vector2(wt * 0.6, 0.0),
			bas_c + Vector2(-wt * 0.9, 0.0), hanche.lerp(bas_c, 0.6) + Vector2(-wc * 0.75, 0.0)])
		_sortant(p, Planche.ferme(culotte, 0.9), culotte.slice(1), T["robe"].lerp(T["ventre"], 0.4), func():
			p.hachures(hanche + Vector2(-wc * 0.4, Th * 0.1), bas_c + Vector2(-wt * 0.3, -wt), 3, Th * 0.14, 1.75, 0.5), 0.85)
	_aile(p, c, m)

	# --- le cou et la tête ---
	_tete_oiseau(p, c, m)


# la queue d'un oiseau : un éventail de rectrices, serré ; ou un panache
static func _queue_oiseau(p, c: Dictionary, m: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var racine: Vector2 = m["racine"]
	var dq: Vector2 = m["dq"]
	var tl: float = m["tl"]
	var Th: float = m["Th"]
	var motif := str(c.get("motif", "uni"))
	var panache: Dictionary = m["panache"]
	p.calque("queue")
	p.pivot("queue", racine)
	var a0 := dq.angle()
	if not panache.is_empty():
		var t := float(panache.get("taille", 0.5))
		if str(panache.get("forme", "")) == "eventail":
			# la roue : des plumes longues dressées en éventail, un « œil » au bout de chacune
			var l := tl * (1.0 + 0.7 * t)
			var n := 7 if p.L >= 50.0 else 5
			var bord := PackedVector2Array([racine + Vector2(Th * 0.1, Th * 0.1)])
			var bouts := PackedVector2Array()
			for i in n:
				var a := a0 + lerpf(-0.25, 1.75, float(i) / (n - 1))
				var b := racine + Vector2.from_angle(a) * l * (0.86 + 0.14 * sin(PI * float(i) / (n - 1)))
				bouts.append(b)
				bord.append(b)
				if i < n - 1:
					bord.append(racine + Vector2.from_angle(a + 1.0 / (n - 1)) * l * 0.8)
			p.volume(Planche.ferme(p.vivant(bord, e * 0.2), 0.7), T["dos"].lerp(T["accent"], 0.35), func():
				var d := ""
				for b in bouts:
					d += "M%s L%s" % [Planche.pt(racine), Planche.pt(b)]
				p.tracer(d, maxf(0.5, e * 0.45), T["encre"], 0.55)
				for b in bouts:
					var q: Vector2 = racine.lerp(b, 0.84)
					var r := maxf(1.3, l * 0.085)
					p.aplat(Planche.ferme(Planche.ellipse(q, r, r * 1.2, 7, (b - racine).angle() + PI * 0.5), 1.0), T["ventre"], 0.9)
					p.aplat(Planche.ferme(Planche.ellipse(q, r * 0.5, r * 0.62, 6), 1.0), T["accent"].lerp(T["encre"], 0.3), 0.95),
				{"cerne": 0.85})
		else:
			# une touffe : des plumes souples qui retombent
			var l2 := tl * (0.9 + 0.8 * t)
			for i in 4:
				var a2 := a0 + lerpf(1.0, 0.0, i / 3.0)
				var ligne := PackedVector2Array([racine, racine + Vector2.from_angle(a2) * l2 * 0.5, racine + Vector2.from_angle(a2 - 0.5) * l2 * 0.9, racine + Vector2.from_angle(a2 - 0.95) * l2 * 1.05])
				p.volume(Planche.ruban(ligne, maxf(e * 2.4, Th * 0.3), maxf(e * 1.3, Th * 0.14)), T["accent"] if i % 2 == 0 else T["dos"], Callable(), {"lourd": i == 0, "cerne": 0.75})
	# les rectrices : un éventail serré de longues plumes, celles du dessus les plus longues ; chacune dite d'un trait
	var n2 := 3 if p.L < 50.0 else 4
	var w0 := Th * 0.36
	var haut_ := Vector2.from_angle(a0 + PI * 0.5)
	var demi := 0.17 / n2
	var pts := PackedVector2Array([racine + haut_ * w0 * 0.5 - dq * w0 * 0.4])
	var crans := PackedVector2Array()
	for i in n2:
		var a3 := a0 + lerpf(0.1, -0.22, float(i) / (n2 - 1))
		var li := tl * lerpf(1.0, 0.82, float(i) / (n2 - 1))
		pts.append(racine + Vector2.from_angle(a3 + demi * 0.9) * li * 0.95)
		pts.append(racine + Vector2.from_angle(a3 - demi * 0.5) * li)
		if i < n2 - 1:
			var cran := racine + Vector2.from_angle(a3 - demi * 1.15) * li * 0.9
			pts.append(cran)
			crans.append(cran)
	pts.append(racine - haut_ * w0 * 0.5 - dq * w0 * 0.4)
	p.volume(Planche.ferme(p.vivant(pts, e * 0.12), 0.45), T["dos"].lerp(T["encre"], 0.12), func():
		p.aplat(Planche.poly(PackedVector2Array([racine + haut_ * w0, racine + dq * tl * 1.1 + haut_ * w0, racine + dq * tl * 1.1 + haut_ * w0 * 0.1, racine + haut_ * w0 * 0.2])), Planche.clair(T["dos"]), 0.4)
		if motif == "rayures":
			# (une queue barrée)
			var d := ""
			for i in 3:
				var q := racine + dq * tl * (0.4 + 0.2 * i)
				d += "M%s L%s" % [Planche.pt(q + haut_ * w0), Planche.pt(q - haut_ * w0 * 1.2)]
			p.tracer(d, maxf(1.0, tl * 0.07), T["ventre"], 0.6)
		elif motif == "bandes":
			var q2 := racine + dq * tl * 0.84
			p.tracer("M%s L%s" % [Planche.pt(q2 + haut_ * w0), Planche.pt(q2 - haut_ * w0 * 1.2)], maxf(1.2, tl * 0.14), T["ventre"], 0.75)
		var dc := ""
		for q3 in crans:
			dc += "M%s L%s" % [Planche.pt(racine.lerp(q3, 0.35)), Planche.pt(q3)]
		p.tracer(dc, maxf(0.45, e * 0.42), T["encre"], 0.6),
		{"cerne": 0.9})


# l'aile repliée sur le flanc : les couvertures (de petits arcs, en rangs), les rémiges (de longs traits), les grandes plumes du bout
static func _aile(p, c: Dictionary, m: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var M: Transform2D = m["M"]
	var al: float = m["al"]
	var motif := str(c.get("motif", "uni"))
	var xb := 0.3 - al                # le bout de l'aile, dans le repère du corps
	var bout := Vector2(xb, -0.04)
	var forme := PackedVector2Array([Vector2(0.37, -0.06), Vector2(0.25, -0.36), Vector2(-0.02, -0.42), Vector2(lerpf(0.3, xb, 0.62), -0.3), Vector2(lerpf(0.3, xb, 0.9), -0.14), bout,
		Vector2(lerpf(0.3, xb, 0.8), 0.1), Vector2(lerpf(0.3, xb, 0.45), 0.22), Vector2(0.08, 0.24), Vector2(0.3, 0.12)])
	var pts: PackedVector2Array = p.vivant(M * forme, e * 0.18)
	var teinte: Color = T["dos"].lerp(T["robe"], 0.4)
	p.volume(Planche.ferme(pts, 0.85), teinte, func():
		# les grandes plumes du bout, plus sombres
		p.aplat(Planche.ferme(M * PackedVector2Array([Vector2(lerpf(0.3, xb, 0.5), -0.5), Vector2(xb - 0.1, -0.4), Vector2(xb - 0.1, 0.3), Vector2(lerpf(0.3, xb, 0.62), 0.3), Vector2(lerpf(0.3, xb, 0.56), -0.05)]), 0.7),
			T["dos"].lerp(T["encre"], 0.3), 0.8)
		# les couvertures, plus claires, à l'épaule
		p.aplat(Planche.ferme(Planche.ellipse(M * Vector2(0.2, -0.2), float(m["Lt"]) * 0.17, float(m["Th"]) * 0.2, 8, m["X"].angle()), 1.0), Planche.clair(T["robe"]), 0.5)
		if motif == "bandes" or motif == "masque":
			# (une barre claire en travers de l'aile)
			p.tracer(Planche.ouvert(M * PackedVector2Array([Vector2(lerpf(0.3, xb, 0.42), -0.4), Vector2(lerpf(0.3, xb, 0.36), -0.05), Vector2(lerpf(0.3, xb, 0.4), 0.26)])), maxf(1.0, float(m["Th"]) * 0.08), T["ventre"], 0.8)
		if motif == "taches" and p.L >= 44.0:
			var o: Vector2 = M * Vector2(0.12, -0.12)
			p.taches(Rect2(o - Vector2(float(m["Lt"]) * 0.2, float(m["Th"]) * 0.2), Vector2(float(m["Lt"]) * 0.4, float(m["Th"]) * 0.4)), 6, maxf(0.5, float(m["Th"]) * 0.03), maxf(0.8, float(m["Th"]) * 0.055), T["ventre"], 0.8)
		# les rémiges : de longs traits, de l'épaule vers le bord de fuite ; barrées chez un oiseau rayé
		var d := ""
		var n := 3 if p.L < 50.0 else 5
		for i in n:
			var k := float(i) / (n - 1)
			var a := Vector2(lerpf(0.02, lerpf(0.3, xb, 0.5), k), lerpf(0.02, -0.2, k))
			var b := Vector2(lerpf(lerpf(0.3, xb, 0.42), xb + 0.05, k), lerpf(0.24, 0.0, k))
			d += "M%s Q%s %s" % [Planche.pt(M * a), Planche.pt(M * ((a + b) * 0.5 + Vector2(0.0, 0.07))), Planche.pt(M * b)]
		p.tracer(d, maxf(0.5, e * 0.45), T["encre"], 0.6)
		if motif == "rayures":
			var db := ""
			for i in 4:
				var x := lerpf(0.3, xb, 0.42 + 0.14 * i)
				db += "M%s L%s" % [Planche.pt(M * Vector2(x, -0.34)), Planche.pt(M * Vector2(x - 0.04, 0.24))]
			p.tracer(db, maxf(0.8, float(m["Th"]) * 0.05), T["encre"], 0.4)
		# les couvertures : deux rangs de petits arcs
		if p.L >= 44.0:
			var da := ""
			for r in 2:
				for j in 3:
					var q := Vector2(0.27 - 0.1 * j - 0.05 * r, -0.26 + 0.14 * r)
					da += "M%s Q%s %s" % [Planche.pt(M * (q + Vector2(0.04, -0.06))), Planche.pt(M * (q + Vector2(-0.07, 0.0))), Planche.pt(M * (q + Vector2(0.04, 0.07)))]
			p.tracer(da, maxf(0.45, e * 0.38), T["encre"], 0.45),
		{"cerne": 0.95})


# le cou et la tête d'un oiseau : la fraise, le cou (en S quand il est long), la huppe, le crâne, le bec, l'œil
static func _tete_oiseau(p, c: Dictionary, m: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var hs: float = m["hs"]
	var Th: float = m["Th"]
	var cou: float = m["cou"]
	var base: Vector2 = m["base"]
	var o: Vector2 = m["tete"]
	var carn: bool = p.regime == "carnivore"
	var motif := str(c.get("motif", "uni"))
	p.calque("tete")
	p.pivot("tete", base)
	# le cou : épais et court (il se fond dans le poitrail), ou long et fin, en S
	var long_ := smoothstep(0.3, 0.7, cou)
	var nuque := o + Vector2(-hs * 0.14, hs * 0.14)
	var depart := base + (base - nuque).normalized() * Th * 0.12
	var travers := (nuque - base).orthogonal().normalized()      # (vers l'arrière)
	if travers.x > 0.0:
		travers = -travers
	var s := (nuque - base).length() * 0.27 * long_
	var ligne := PackedVector2Array([depart, base.lerp(nuque, 0.3) - travers * s, base.lerp(nuque, 0.68) + travers * s * 0.75, nuque, nuque.lerp(o, 0.8)])
	var w0 := lerpf(Th * 0.74, Th * 0.4, long_)
	var w1 := hs * lerpf(0.8, 0.52, long_)
	var collerette := _og(c, "collerette")
	p.volume(Planche.ruban(ligne, w0, w1), T["robe"], func():
		var B := Planche.bords(ligne, w0, w1)
		var dos_: PackedVector2Array = (B[0] if B[0][3].x < B[1][3].x else B[1]).slice(0, 4)
		var gorge: PackedVector2Array = (B[1] if B[0][3].x < B[1][3].x else B[0]).slice(0, 4)
		p.tracer(Planche.ouvert(dos_), w1 * 0.5, T["dos"], 0.45)
		p.tracer(Planche.ouvert(gorge), w1 * 0.55, T["ventre"], 0.75)
		if motif == "bandes":
			p.tracer("M%s L%s" % [Planche.pt(dos_[2]), Planche.pt(gorge[2])], maxf(1.2, hs * 0.16), T["ventre"], 0.85),
		{"lourd": false, "cerne": 0.0})
	for bord in Planche.bords(ligne, w0, w1):
		p.cerne(Planche.ouvert(bord.slice(1)))
	if long_ > 0.4 and p.L >= 50.0:
		# (les plumes longues du jabot, au bas d'un grand cou)
		var dj := ""
		for i in 3:
			var q := ligne[1] + Vector2(w0 * (0.1 + 0.16 * i), w0 * 0.15)
			dj += "M%s q%s %s" % [Planche.pt(q), Planche.pt(Vector2(w0 * 0.1, w0 * 0.3)), Planche.pt(Vector2(-w0 * 0.05, w0 * 0.62))]
		p.tracer(dj, maxf(0.45, e * 0.4), T["encre"], 0.5)
	if not collerette.is_empty():
		_fraise(p, collerette, ligne[2].lerp(nuque, 0.35), (nuque - ligne[2]).normalized(), w1, hs)
	# la huppe, les aigrettes, derrière le crâne
	var t_crete: float = m["t_crete"]
	if t_crete > 0.1:
		_huppe(p, m["crete"], o, hs, t_crete, long_)
	var cornes := _og(c, "cornes")
	var t_cornes := float(cornes.get("taille", c.get("cornes", 0.0)))
	if t_cornes > 0.1:
		# (des aigrettes en cornes : les oreilles d'un hibou)
		for dx in [0.1, -0.22]:
			var b: Vector2 = o + Vector2(hs * dx, -hs * 0.36)
			p.volume(Planche.ferme(PackedVector2Array([b + Vector2(-hs * 0.14, hs * 0.1), b + Vector2(-hs * 0.16, -hs * (0.3 + 0.7 * t_cornes)), b + Vector2(hs * 0.14, hs * 0.08)]), 0.6),
				T["dos"] if dx < 0.0 else T["dos"].lerp(T["loin"], 0.5), Callable(), {"lourd": false, "cerne": 0.8})
	# le crâne : rond chez une proie, le front plat et l'arcade marquée chez un rapace
	var uv: PackedVector2Array
	if carn:
		uv = PackedVector2Array([Vector2(-0.5, 0.1), Vector2(-0.46, -0.24), Vector2(-0.2, -0.45), Vector2(0.16, -0.44), Vector2(0.42, -0.24), Vector2(0.5, -0.02),
			Vector2(0.44, 0.24), Vector2(0.14, 0.44), Vector2(-0.26, 0.4)])
	else:
		uv = PackedVector2Array([Vector2(-0.5, 0.08), Vector2(-0.46, -0.24), Vector2(-0.2, -0.47), Vector2(0.12, -0.5), Vector2(0.4, -0.32), Vector2(0.52, -0.04),
			Vector2(0.44, 0.24), Vector2(0.14, 0.45), Vector2(-0.26, 0.4)])
	var crane := PackedVector2Array()
	for q in uv:
		crane.append(o + q * hs)
	crane = p.vivant(crane, e * 0.12)
	var genre: String = m["genre"]
	# (le haut du bec passe derrière le crâne : il en sort)
	_bec(p, genre, o, hs, float(m["bl"]), true)
	_sortant(p, Planche.ferme(crane, 1.0), PackedVector2Array([crane[8]]) + crane.slice(0, 8), T["robe"], func():
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(-hs * 0.08, -hs * 0.4), hs * 0.56, hs * 0.22, 8), 1.0), T["dos"], 0.5)
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.14, hs * 0.34), hs * 0.42, hs * 0.2, 8), 1.0), T["ventre"], 0.8)
		if p.nocturne:
			# (le disque de la face, chez un oiseau de nuit)
			p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.12, -hs * 0.02), hs * 0.36, hs * 0.4, 9), 1.0), T["ventre"], 0.7)
			p.tracer(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.12, -hs * 0.02), hs * 0.36, hs * 0.4, 9), 1.0), maxf(0.45, e * 0.4), T["encre"], 0.5)
		if motif == "masque":
			p.aplat(Planche.ferme(PackedVector2Array([o + Vector2(hs * 0.56, -hs * 0.02), o + Vector2(hs * 0.2, -hs * 0.26), o + Vector2(-hs * 0.4, -hs * 0.18), o + Vector2(-hs * 0.56, 0.0),
				o + Vector2(-hs * 0.3, hs * 0.1), o + Vector2(hs * 0.2, hs * 0.08)]), 0.9), T["dos"].lerp(T["encre"], 0.35), 0.9)
		elif motif == "rayures":
			# (un sourcil clair, une moustache)
			p.tracer("M%s Q%s %s" % [Planche.pt(o + Vector2(hs * 0.4, -hs * 0.22)), Planche.pt(o + Vector2(0.0, -hs * 0.4)), Planche.pt(o + Vector2(-hs * 0.4, -hs * 0.2))], maxf(0.8, hs * 0.09), T["ventre"], 0.8)
			p.tracer("M%s L%s" % [Planche.pt(o + Vector2(hs * 0.3, hs * 0.12)), Planche.pt(o + Vector2(hs * 0.1, hs * 0.4))], maxf(0.8, hs * 0.09), T["dos"], 0.8))
	_bec(p, genre, o, hs, float(m["bl"]), false)
	# l'œil : rond et sombre chez une proie, d'ambre sous l'arcade chez un rapace ; grand la nuit
	p.oeil(o + Vector2(hs * (0.16 if carn else 0.12), -hs * 0.1), hs * (0.2 if p.nocturne else 0.135))


# un bec. Deux temps : « derriere » (avant le crâne : la mandibule du bas, la base), puis le dessus
static func _bec(p, genre: String, o: Vector2, hs: float, bl: float, derriere: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var corne: Color = T["os"]
	var sombre: Color = T["truffe"].lerp(T["os"], 0.12)
	var b := o + Vector2(hs * 0.4, hs * 0.04)        # la racine du bec, au milieu
	var opts := {"lourd": false, "cerne": 0.8}
	match genre:
		"crochu":
			if derriere:
				# la mandibule du bas, courte
				p.volume(Planche.ferme(PackedVector2Array([b + Vector2(-hs * 0.06, hs * 0.04), b + Vector2(bl * 0.62, hs * 0.1), b + Vector2(bl * 0.3, hs * 0.22), b + Vector2(-hs * 0.08, hs * 0.2)]), 0.7), corne.darkened(0.2), Callable(), opts)
				return
			# celle du haut : épaisse, courbée, sa pointe passe sous l'autre ; sombre au bout, la cire claire à sa racine
			var haut := PackedVector2Array([b + Vector2(-hs * 0.1, -hs * 0.2), b + Vector2(bl * 0.4, -hs * 0.2), b + Vector2(bl * 0.86, -hs * 0.02), b + Vector2(bl * 0.96, hs * 0.3),
				b + Vector2(bl * 0.7, hs * 0.12), b + Vector2(bl * 0.3, hs * 0.08), b + Vector2(-hs * 0.08, hs * 0.08)])
			p.volume(Planche.ferme(haut, 0.75), corne, func():
				p.aplat(Planche.ferme(PackedVector2Array([b + Vector2(bl * 0.5, -hs * 0.4), b + Vector2(bl * 1.2, -hs * 0.3), b + Vector2(bl * 1.1, hs * 0.5), b + Vector2(bl * 0.6, hs * 0.3)]), 0.7), sombre, 0.92), opts)
			p.aplat(Planche.ferme(Planche.ellipse(b + Vector2(bl * 0.12, -hs * 0.07), maxf(0.7, hs * 0.1), maxf(0.6, hs * 0.085), 6), 1.0), T["accent"].lerp(corne, 0.45))
		"poignard":
			if derriere:
				return
			# long et droit : un harpon ; l'arête sombre
			var pts := PackedVector2Array([b + Vector2(-hs * 0.1, -hs * 0.15), b + Vector2(bl * 0.5, -hs * 0.07), b + Vector2(bl, hs * 0.06), b + Vector2(bl * 0.45, hs * 0.15), b + Vector2(-hs * 0.1, hs * 0.2)])
			p.volume(Planche.ferme(pts, 0.5), corne, func():
				p.aplat(Planche.poly(PackedVector2Array([b + Vector2(-hs * 0.1, -hs * 0.3), b + Vector2(bl * 1.1, -hs * 0.1), b + Vector2(bl * 1.1, hs * 0.05), b + Vector2(-hs * 0.1, -hs * 0.02)])), sombre, 0.7), opts)
			p.tracer("M%s L%s" % [Planche.pt(b + Vector2(0.0, hs * 0.05)), Planche.pt(b + Vector2(bl * 0.8, hs * 0.06))], maxf(0.45, e * 0.4), T["encre"], 0.7)
		"plat":
			if derriere:
				return
			# une spatule : plate, le bout rond et un peu relevé
			var pts2 := PackedVector2Array([b + Vector2(-hs * 0.1, -hs * 0.12), b + Vector2(bl * 0.5, -hs * 0.02), b + Vector2(bl * 0.86, -hs * 0.08), b + Vector2(bl * 1.02, hs * 0.02), b + Vector2(bl * 0.9, hs * 0.16),
				b + Vector2(bl * 0.45, hs * 0.17), b + Vector2(-hs * 0.1, hs * 0.22)])
			p.volume(Planche.ferme(pts2, 0.85), T["accent"].lerp(corne, 0.4), Callable(), opts)
			p.tracer("M%s L%s" % [Planche.pt(b + Vector2(0.0, hs * 0.08)), Planche.pt(b + Vector2(bl * 0.86, hs * 0.07))], maxf(0.45, e * 0.4), T["encre"], 0.7)
		"gros":
			if derriere:
				return
			# un gros bec bombé, vif : un mangeur de fruits
			var pts3 := PackedVector2Array([b + Vector2(-hs * 0.12, -hs * 0.26), b + Vector2(bl * 0.45, -hs * 0.3), b + Vector2(bl * 0.9, -hs * 0.08), b + Vector2(bl, hs * 0.16), b + Vector2(bl * 0.6, hs * 0.26),
				b + Vector2(-hs * 0.1, hs * 0.26)])
			p.volume(Planche.ferme(pts3, 0.85), T["accent"].lerp(corne, 0.25), func():
				p.aplat(Planche.ferme(Planche.ellipse(b + Vector2(bl * 0.35, -hs * 0.14), bl * 0.3, hs * 0.08, 6), 1.0), corne, 0.5), opts)
			p.tracer("M%s Q%s %s" % [Planche.pt(b + Vector2(0.0, hs * 0.1)), Planche.pt(b + Vector2(bl * 0.5, hs * 0.06)), Planche.pt(b + Vector2(bl * 0.94, hs * 0.15))], maxf(0.45, e * 0.4), T["encre"], 0.7)
		_:
			if derriere:
				return
			# un cône : court et fort (des graines), plus long et pointu chez un omnivore
			var h := 0.2 if genre == "conique" else 0.15
			var pts4 := PackedVector2Array([b + Vector2(-hs * 0.1, -hs * h), b + Vector2(bl * 0.55, -hs * h * 0.4), b + Vector2(bl, hs * 0.05), b + Vector2(bl * 0.5, hs * (h * 0.6 + 0.06)), b + Vector2(-hs * 0.1, hs * (h + 0.04))])
			p.volume(Planche.ferme(pts4, 0.6), corne.lerp(T["accent"], 0.18), Callable(), opts)
			p.tracer("M%s L%s" % [Planche.pt(b + Vector2(0.0, hs * 0.05)), Planche.pt(b + Vector2(bl * 0.75, hs * 0.05))], maxf(0.45, e * 0.4), T["encre"], 0.65)


# la huppe (lisse : une pointe couchée vers l'arrière, ou les aigrettes d'un grand cou ; dentelée : des plumes dressées, une à une)
static func _huppe(p, crete: Dictionary, o: Vector2, hs: float, taille: float, long_: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var h := hs * (0.4 + 0.9 * taille)
	if str(crete.get("forme", "lisse")) == "dentelee":
		for i in 4:
			var b := o + Vector2(hs * (0.12 - 0.14 * i), -hs * 0.4)
			var z := b + Vector2(-h * (0.1 + 0.2 * i), -h * (1.0 - 0.08 * i))
			p.tracer("M%s Q%s %s" % [Planche.pt(b), Planche.pt(b + Vector2(h * 0.05, -h * 0.55)), Planche.pt(z)], maxf(0.9, hs * 0.07) + e * 0.7, T["encre"])
			p.tracer("M%s Q%s %s" % [Planche.pt(b), Planche.pt(b + Vector2(h * 0.05, -h * 0.55)), Planche.pt(z)], maxf(0.9, hs * 0.07), T["accent"])
			p.volume(Planche.ferme(Planche.ellipse(z, maxf(1.0, hs * 0.09), maxf(1.0, hs * 0.09), 6), 1.0), T["accent"], Callable(), {"lourd": false, "cerne": 0.6, "plat": true})
	elif long_ > 0.4:
		# deux aigrettes fines, qui tombent de la nuque
		for i in 2:
			var b2 := o + Vector2(-hs * (0.3 + 0.1 * i), -hs * (0.3 - 0.12 * i))
			var ligne := PackedVector2Array([b2, b2 + Vector2(-h * 0.6, -h * (0.12 - 0.1 * i)), b2 + Vector2(-h * 1.25, h * (0.2 + 0.25 * i))])
			p.volume(Planche.ruban(ligne, maxf(e * 1.4, hs * 0.14), e * 0.5), T["accent"], Callable(), {"lourd": false, "cerne": 0.7, "plat": true})
	else:
		var pts := PackedVector2Array([o + Vector2(hs * 0.3, -hs * 0.36), o + Vector2(-hs * 0.05, -hs * 0.5) + Vector2(-h * 0.25, -h * 0.5), o + Vector2(-hs * 0.3, -hs * 0.4) + Vector2(-h * 0.85, -h * 0.55),
			o + Vector2(-hs * 0.44, -hs * 0.2) + Vector2(-h * 0.3, -h * 0.05), o + Vector2(-hs * 0.4, 0.0)])
		p.volume(Planche.ferme(pts, 0.75), T["accent"], func():
			p.tracer("M%s L%s" % [Planche.pt(o + Vector2(-hs * 0.1, -hs * 0.4)), Planche.pt(pts[2] + Vector2(h * 0.25, h * 0.12))], maxf(0.45, e * 0.4), T["encre"], 0.5),
			{"lourd": false, "cerne": 0.8})


# la fraise : un collier de plumes autour du cou (lisse : un bourrelet ; frangée : des pointes)
static func _fraise(p, o: Dictionary, centre: Vector2, axe: Vector2, large: float, hs: float) -> void:
	var T: Dictionary = p.tons
	var t := float(o.get("taille", 0.5))
	var cote := axe.orthogonal()
	var r := large * (0.75 + 0.7 * t)
	var frange := str(o.get("forme", "")) == "frangee"
	var n := 9
	var pts := PackedVector2Array()
	for i in n:
		var a := PI * float(i) / (n - 1)
		var k := 0.72 if frange and i % 2 == 1 else 1.0
		pts.append(centre + cote * cos(a) * r * k - axe * (sin(a) * hs * (0.3 + 0.5 * t) * k + hs * 0.05))
	pts.append(centre + cote * -r * 0.7 + axe * hs * 0.12)
	pts.append(centre + cote * r * 0.7 + axe * hs * 0.12)
	p.volume(Planche.ferme(pts, 0.45 if frange else 0.9), T["accent"].lerp(T["ventre"], 0.25), func():
		var d := ""
		for i in range(1, n - 1, 2 if frange else 1):
			d += "M%s L%s" % [Planche.pt(centre + axe * hs * 0.05), Planche.pt(pts[i].lerp(centre, 0.2))]
		p.tracer(d, maxf(0.45, p.e * 0.4), T["encre"], 0.45),
		{"lourd": false, "cerne": 0.85})


# ============================================================ LE BIPÈDE ============================================================

# où sont les choses, pour un bipède à l'échelle u, décalé de dx
static func _mesures_bipede(p, c: Dictionary, u: float, dx: float) -> Dictionary:
	var rob: float = p.robustesse
	var long := float(c.get("long", 0.5))
	var cou := float(c.get("cou", 0.2))
	var queue := float(c.get("queue", 0.3))
	var mains := not _og(c, "mains").is_empty()
	var debout: bool = mains or queue < 0.3 or (float(c.get("posture", 1.0)) >= 0.95 and queue < 0.45)
	var lt := u * (0.3 + 0.32 * long) * (0.8 if debout else 1.0)           # le tronc
	var th := u * (0.14 + 0.1 * rob + 0.04 * (1.0 - long))                 # son épaisseur
	var hl := u * (0.06 + 0.34 * float(c.get("haut", 0.3))) * (1.35 if not p.locomotion.has("fouissage") else 1.0) * (1.15 if p.traits.has("pattes-longues") else 1.0)
	var tl := u * (0.03 + 0.42 * queue) * (0.75 if debout else 1.3)        # la queue
	var hs := u * (0.085 + 0.1 * float(c.get("tete", 0.4)))                # la tête
	var cl := u * (0.03 + 0.2 * cou)                                       # le cou
	var ml := u * (0.012 + 0.12 * float(c.get("museau", 0.4)))             # le museau
	var penche := 1.08 if debout else 0.14 + 0.12 * cou
	var X := Vector2(cos(penche), -sin(penche))
	var Y := Vector2(sin(penche), cos(penche))
	var H := Vector2(dx, -hl - th * 0.36)                                  # la hanche : tout s'équilibre autour d'elle
	var M := Transform2D(X * lt, Y * th, H - X * lt * 0.24)                # (le repère du tronc : x de la croupe (0) au poitrail (1), y vers le ventre)
	var ang := clampf((0.55 if p.regime == "carnivore" else 0.95) + 0.4 * cou + (0.35 if debout else 0.0), 0.3, 1.45)
	var base := M * Vector2(0.94, -0.22)
	var tete := base + Vector2(cos(ang), -sin(ang)) * (th * 0.3 + cl + hs * 0.3)
	var racine := M * Vector2(0.06, -0.08)
	var bout_queue := racine + (Vector2(-tl * 0.6, tl * 0.75) if debout else Vector2(-tl, -tl * 0.1 - th * 0.1))
	var m := {"lt": lt, "th": th, "hl": hl, "tl": tl, "hs": hs, "cl": cl, "ml": ml, "penche": penche, "X": X, "Y": Y, "H": H, "M": M, "ang": ang, "base": base, "tete": tete,
		"racine": racine, "bout_queue": bout_queue, "debout": debout, "mains": mains, "cou": cou}
	var col := _og(c, "collerette")
	m["x0"] = bout_queue.x - (th * 0.5 if not _og(c, "massue").is_empty() or not _og(c, "panache").is_empty() else 0.0)
	m["x1"] = tete.x + hs * 0.5 + ml
	m["y0"] = tete.y - hs * (0.5 + maxf(maxf(0.25 + 0.9 * float(c.get("oreilles", 0.0)) if float(c.get("oreilles", 0.0)) > 0.12 else 0.0, 0.5 + 1.2 * float(c.get("cornes", 0.0)) if float(c.get("cornes", 0.0)) > 0.1 else 0.0),
		0.3 + 0.8 * float(col.get("taille", 0.5)) if not col.is_empty() else 0.0))
	return m


static func _bipede(p) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var L: float = p.L
	var e: float = p.e
	var rob: float = p.robustesse
	var m := _mesures_bipede(p, c, 1.0, 0.0)
	var u: float = L * 0.96 / (float(m["x1"]) - float(m["x0"]))
	if -float(m["y0"]) * u > L * 1.02:
		u = L * 1.02 / -float(m["y0"])
	m = _mesures_bipede(p, c, u, -(float(m["x0"]) + float(m["x1"])) * 0.5 * u)
	var M: Transform2D = m["M"]
	var H: Vector2 = m["H"]
	var X: Vector2 = m["X"]
	var lt: float = m["lt"]
	var th: float = m["th"]
	var tl: float = m["tl"]
	var debout: bool = m["debout"]
	var carn: bool = p.regime == "carnivore"
	var motif := str(c.get("motif", "uni"))
	p.ombre(H.x + lt * 0.08, lt * 0.5 + th * 0.3)

	# --- la queue : épaisse à sa racine, elle prolonge le corps et fait balancier ---
	var racine: Vector2 = m["racine"]
	var bq: Vector2 = m["bout_queue"]
	var w_q := th * (0.74 if not debout else 0.42)
	var ligne_q := PackedVector2Array()
	if float(c.get("queue", 0.0)) > 0.06:
		var q1 := racine + (Vector2(-tl * 0.3, tl * 0.2) if debout else Vector2(-tl * 0.5, th * 0.06))
		for i in 7:
			var t := i / 6.0
			ligne_q.append((racine + X * lt * 0.1).lerp(q1, t).lerp(q1.lerp(bq, t), t))
		p.calque("queue")
		p.pivot("queue", racine)
		var fin_q := maxf(e * 0.9, w_q * 0.14)
		p.volume(Planche.ruban(ligne_q, w_q, fin_q), T["robe"], func():
			p.aplat(Planche.ruban(PackedVector2Array([ligne_q[0] + Vector2(0, -w_q * 0.3), ligne_q[3] + Vector2(0, -w_q * 0.18), ligne_q[6]]), w_q * 0.5, fin_q * 0.5), T["dos"], 0.45)
			p.aplat(Planche.ruban(PackedVector2Array([ligne_q[0] + Vector2(0, w_q * 0.36), ligne_q[3] + Vector2(0, w_q * 0.2), ligne_q[6]]), w_q * 0.3, fin_q * 0.4), T["ventre"], 0.7)
			_motif_ruban(p, motif, ligne_q, w_q, fin_q))
		_bout_de_queue(p, c, bq, (bq - ligne_q[5]).normalized(), th)

	# --- les deux pattes : fortes, pliées en trois, sous la hanche ---
	var hy := -H.y
	var wp := th * (0.36 + 0.16 * rob)
	var pied := "griffes" if p.regime != "herbivore" or rob < 0.45 else "sabot"
	var po := {"pied": pied, "pied_taille": 1.35, "poilu": true}
	if carn:
		po["pied_teinte"] = T["robe"]
	for loin in [true, false]:
		# (au repos : la patte proche sous la hanche, l'autre un pas en avant)
		var h0: Vector2 = H + (Vector2(lt * 0.09, -th * 0.03) if loin else Vector2.ZERO)
		var k := 0.92 if loin else 1.0
		var av := hy * (0.3 if loin else -0.06)
		p.patte(PackedVector2Array([h0, h0 + Vector2(hy * 0.2 + av * 0.5, hy * 0.42), Vector2(h0.x - hy * 0.13 + av * 0.8, -hy * 0.25), Vector2(h0.x + hy * 0.03 + av, 0.0)]),
			[wp * 1.45 * k, wp * 0.9 * k, wp * 0.56 * k, wp * 0.5 * k], loin, po)

	# --- le corps : le poitrail profond, la croupe qui file dans la queue ---
	p.calque("corps")
	_bras(p, c, m, true)
	var tronc: PackedVector2Array = p.vivant(M * PackedVector2Array([Vector2(-0.04, -0.3), Vector2(0.24, -0.5), Vector2(0.6, -0.52), Vector2(0.92, -0.4), Vector2(1.03, -0.02), Vector2(0.9, 0.42),
		Vector2(0.55, 0.52), Vector2(0.2, 0.44), Vector2(-0.04, 0.26)]), e * 0.22)
	var dedans := func():
		p.aplat(Planche.ferme(M * PackedVector2Array([Vector2(-0.2, -0.9), Vector2(1.2, -0.9), Vector2(1.0, -0.22), Vector2(0.5, -0.2), Vector2(-0.2, -0.1)]), 0.8), T["dos"], 0.48)
		p.aplat(Planche.ferme(Planche.ellipse(M * Vector2(0.56, 0.42), lt * 0.4, th * 0.24, 10, X.angle()), 1.0), T["ventre"], 0.85)
		match motif:
			"bandes":
				for i in 4:
					var x := 0.16 + 0.22 * i
					p.aplat(Planche.poly(M * PackedVector2Array([Vector2(x - 0.05, -0.7), Vector2(x + 0.07, -0.7), Vector2(x + 0.05, 0.12), Vector2(x - 0.02, 0.12)])), T["dos"], 0.66)
			"rayures":
				for i in 8:
					var x2 := 0.08 + 0.115 * i
					p.aplat(Planche.poly(M * PackedVector2Array([Vector2(x2 - 0.02, -0.7), Vector2(x2 + 0.025, -0.7), Vector2(x2 + 0.05, 0.08), Vector2(x2 + 0.035, 0.08)])), T["dos"], 0.72)
			"taches":
				var o: Vector2 = M * Vector2(0.5, -0.14)
				p.taches(Rect2(o - Vector2(lt * 0.46, th * 0.36), Vector2(lt * 0.92, th * 0.56)), 9, maxf(0.6, th * 0.06), maxf(1.0, th * 0.13), T["dos"], 0.66)
		p.aplat(Planche.ferme(Planche.ellipse(M * Vector2(0.5, 0.62), lt * 0.5, th * 0.16, 10, X.angle()), 1.0), T["encre"], 0.22)
		p.poils(M * PackedVector2Array([Vector2(0.14, -0.36), Vector2(0.5, -0.42), Vector2(0.86, -0.32)]), th * 0.16, 2.2 - float(m["penche"]), 3.2)
	if ligne_q.is_empty():
		p.volume(Planche.ferme(tronc, 1.0), T["robe"], dedans)
	else:
		# (la croupe n'a pas de trait : le corps file dans la queue)
		_lourd(p, Planche.ferme(tronc, 1.0))
		p.volume(Planche.ferme(tronc, 1.0), T["robe"], dedans, {"lourd": false, "cerne": 0.0})
		p.cerne(Planche.ouvert(tronc.slice(1, 8)))

	# --- le dessus : la cuisse, le bras proche, ce que porte le dos ---
	p.calque("dessus")
	var rr := wp * 1.2
	p.aplat(Planche.ferme(Planche.ellipse(H + Vector2(0.0, -th * 0.1), rr, th * 0.4, 8, -0.3), 1.0), T["robe"], 1.0)
	p.tracer("M%s Q%s %s" % [Planche.pt(H + Vector2(-rr * 1.0, -th * 0.16)), Planche.pt(H + Vector2(-rr * 0.3, th * 0.5)), Planche.pt(H + Vector2(rr * 1.0, th * 0.1))], e * 0.6, T["encre"], 0.6)
	_dos_bipede(p, c, m)
	_bras(p, c, m, false)

	# --- le cou et la tête ---
	_tete_bipede(p, c, m)


static func _lourd(p, d: String) -> void:
	var encre: String = Planche.coul(p.tons["encre"])
	p.svg("<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" transform=\"translate(%s %s)\"/>" % [d, encre, encre, Planche.n(p.e * 1.5), Planche.n(p.e * 0.3), Planche.n(p.e * 0.5)])


# le motif sur un ruban (une queue) : des anneaux, des taches
static func _motif_ruban(p, motif: String, ligne: PackedVector2Array, w0: float, w1: float) -> void:
	if not motif in ["bandes", "rayures", "taches"]:
		return
	var n := 5 if motif == "bandes" else (8 if motif == "rayures" else 5)
	var d := ""
	for i in n:
		var t := (i + 0.6) / n
		var f := t * (ligne.size() - 1)
		var j := mini(int(f), ligne.size() - 2)
		var q := ligne[j].lerp(ligne[j + 1], f - j)
		var dir := (ligne[j + 1] - ligne[j]).normalized()
		var w := lerpf(w0, w1, t)
		var lg := ligne[0].distance_to(ligne[ligne.size() - 1]) / n * (0.4 if motif == "bandes" else 0.26)
		if motif == "taches":
			d += Planche.ferme(Planche.ellipse(q + dir.orthogonal() * w * 0.12, lg * 0.7, w * 0.26, 6, dir.angle()), 1.0)
		else:
			d += Planche.poly(PackedVector2Array([q - dir * lg * 0.5 + dir.orthogonal() * w, q + dir * lg * 0.5 + dir.orthogonal() * w, q + dir * lg * 0.5 - dir.orthogonal() * w * 0.15, q - dir * lg * 0.5 - dir.orthogonal() * w * 0.15]))
	p.aplat(d, p.tons["dos"], 0.68)


# ce que porte le bout de la queue : une massue, un aiguillon, un panache, des épines
static func _bout_de_queue(p, c: Dictionary, bout: Vector2, d: Vector2, th: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var massue := _og(c, "massue")
	if not massue.is_empty():
		var r := th * (0.24 + 0.3 * float(massue.get("taille", 0.5)))
		var ctr := bout + d * r * 0.4
		if str(massue.get("forme", "")) == "cloutee":
			for i in 6:
				var dir := Vector2.from_angle(TAU * i / 6.0 + 0.3)
				_pointe(p, ctr + dir * r * 0.7, ctr + dir * r * 1.6, maxf(e * 1.2, r * 0.4), T["os"])
		p.volume(Planche.ferme(Planche.ellipse(ctr, r * 1.15, r, 8, d.angle()), 1.0), T["dos"], Callable(), {"cerne": 0.85})
	var dard := _og(c, "aiguillon")
	if not dard.is_empty():
		var l := th * (0.4 + 0.7 * float(dard.get("taille", 0.5)))
		var z := bout + (d * l * 0.3 + Vector2(0.0, -l) if str(dard.get("forme", "courbe")) == "courbe" else d * l)
		p.volume(Planche.ruban(PackedVector2Array([bout - d * th * 0.05, bout + d * l * 0.6 + Vector2(0.0, -l * 0.15), z]), maxf(e * 1.6, th * 0.16), e * 0.5), T["os"].darkened(0.1), Callable(), {"lourd": false, "cerne": 0.7, "plat": true})
	var panache := _og(c, "panache")
	if not panache.is_empty():
		var l2 := th * (0.5 + 0.9 * float(panache.get("taille", 0.5)))
		var ouvert_ := 1.1 if str(panache.get("forme", "")) == "eventail" else 0.55
		var dd := ""
		for i in 5:
			var dir2 := d.rotated(lerpf(-ouvert_, ouvert_, i / 4.0))
			dd += "M%s Q%s %s" % [Planche.pt(bout - d * th * 0.1), Planche.pt(bout + dir2 * l2 * 0.5 + Vector2(0, -l2 * 0.08)), Planche.pt(bout + dir2 * l2)]
		p.tracer(dd, maxf(1.2, th * 0.12) + e * 0.9, T["encre"])
		p.tracer(dd, maxf(1.2, th * 0.12), T["accent"])
	var epines := _og(c, "epines", "queue")
	if not epines.is_empty():
		for i in 3:
			var q := bout - d * th * (0.15 + 0.3 * i)
			_pointe(p, q + Vector2(0.0, -th * 0.04), q + Vector2(-th * 0.1, -th * (0.35 + 0.5 * float(epines.get("taille", 0.5)))), maxf(e * 1.2, th * 0.12), T["os"])


# un petit bras, replié sous le poitrail : trois griffes, ou une main aux doigts écartés (loin : celui de l'autre côté, dans l'ombre)
static func _bras(p, c: Dictionary, m: Dictionary, loin: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var M: Transform2D = m["M"]
	var th: float = m["th"]
	var lt: float = m["lt"]
	var debout: bool = m["debout"]
	var mains: bool = m["mains"]
	var teinte: Color = T["loin"] if loin else T["robe"]
	var epaule := M * Vector2(0.84, 0.16) + (Vector2(lt * 0.06, -th * 0.04) if loin else Vector2.ZERO)
	var l := th * (0.62 if not debout else 0.95) * (1.2 if mains else 1.0)
	var coude := epaule + Vector2(l * 0.22, l * 0.62) if not debout else epaule + Vector2(l * 0.1, l * 0.7)
	var main_ := coude + Vector2(l * 0.62, l * 0.05) if not debout else coude + Vector2(l * 0.6, l * 0.3)
	var w := maxf(e * 1.7, th * 0.2)
	var ligne := PackedVector2Array([epaule, coude, main_])
	# les doigts d'abord (le bras passe dessus)
	var dir := (main_ - coude).normalized()
	var doigts := ""
	for a in ([-0.6, 0.0, 0.6] if mains else [-0.35, 0.3]):
		doigts += "M%s L%s" % [Planche.pt(main_ - dir * w * 0.2), Planche.pt(main_ + dir.rotated(a) * w * (1.5 if mains else 1.1))]
	if mains:
		p.tracer(doigts, w * 0.5 + e * 0.9, T["encre"])
		p.tracer(doigts, w * 0.5, teinte)
	else:
		p.tracer(doigts, maxf(0.8, w * 0.36) + e * 0.6, T["encre"])
		p.tracer(doigts, maxf(0.8, w * 0.36), T["os"].darkened(0.3) if loin else T["os"])
	if loin:
		p.volume(Planche.ruban(ligne, w, w * 0.7), teinte, Callable(), {"lourd": false, "cerne": 0.85, "plat": true})
	else:
		var B := Planche.bords(ligne, w * 1.15, w * 0.75)
		var contour: PackedVector2Array = B[0].slice(1)
		var retour: PackedVector2Array = B[1].slice(1)
		retour.reverse()
		_sortant(p, Planche.ruban(ligne, w * 1.15, w * 0.75), contour + retour, teinte, Callable(), 0.9)


# ce que porte le dos d'un bipède : une cuirasse, des plaques, une crête, des épines, des ailes repliées
static func _dos_bipede(p, c: Dictionary, m: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var M: Transform2D = m["M"]
	var th: float = m["th"]
	var lt: float = m["lt"]
	var X: Vector2 = m["X"]
	var haut_ := -Vector2(m["Y"])
	var dos := func(x: float) -> Vector2: return M * Vector2(x, -0.5 + 0.9 * pow(absf(x - 0.5), 2.2))
	var carapace := _og(c, "carapace")
	var t_car := float(carapace.get("taille", c.get("carapace", 0.0)))
	if t_car > 0.3:
		# une cuirasse : des bandes d'écussons sur le dos et le haut des flancs (segmentée), ou un dôme (bombée)
		var bas := 0.0 + 0.3 * t_car
		var forme := PackedVector2Array([Vector2(0.02, -0.2), Vector2(0.18, -0.56 - 0.2 * t_car), Vector2(0.45, -0.6 - 0.3 * t_car), Vector2(0.68, -0.54 - 0.15 * t_car), Vector2(0.8, -0.2),
			Vector2(0.68, bas), Vector2(0.4, bas + 0.06), Vector2(0.14, bas - 0.08)])
		p.volume(Planche.ferme(p.vivant(M * forme, e * 0.2), 0.95), T["dos"].lerp(T["robe"], 0.25), func():
			var d := ""
			for i in 5:
				var x := 0.15 + 0.125 * i
				d += "M%s Q%s %s" % [Planche.pt(M * Vector2(x, -1.0)), Planche.pt(M * Vector2(x + 0.06, -0.3)), Planche.pt(M * Vector2(x - 0.02, bas + 0.1))]
			p.tracer(d, e * 0.55, T["encre"], 0.6)
			p.tracer(Planche.ouvert(M * PackedVector2Array([Vector2(0.06, -0.26), Vector2(0.45, -0.5), Vector2(0.82, -0.3)])), e * 0.5, T["encre"], 0.45)
			p.tracer(Planche.ouvert(M * PackedVector2Array([Vector2(0.1, -0.4), Vector2(0.45, -0.72 - 0.2 * t_car), Vector2(0.76, -0.5)])), maxf(0.7, th * 0.05), Planche.clair(T["robe"]), 0.5),
			{"cerne": 0.95})
	var plaques := _og(c, "plaques")
	if not plaques.is_empty():
		var n := clampi(int(plaques.get("nombre", 5)), 3, 9)
		var h := th * (0.3 + 0.55 * float(plaques.get("taille", 0.5)))
		for i in n:
			var x := 0.1 + 0.8 * (i + 0.5) / n
			var q: Vector2 = dos.call(x)
			var hh := h * (0.6 + 0.4 * sin(PI * (i + 0.5) / n))
			if str(plaques.get("forme", "")) == "rondes":
				p.volume(Planche.ferme(Planche.ellipse(q + haut_ * hh * 0.3, lt * 0.045 + 1.0, hh * 0.6, 7, X.angle()), 1.0), T["accent"], Callable(), {"lourd": false, "cerne": 0.75})
			else:
				p.volume(Planche.poly(PackedVector2Array([q - X * lt * 0.05 - haut_ * hh * 0.1, q + haut_ * hh - X * hh * 0.1, q + X * lt * 0.05 - haut_ * hh * 0.1])), T["accent"], Callable(), {"lourd": false, "cerne": 0.75})
	var crete := _og(c, "crete", "dos")
	var t_crete := float(crete.get("taille", 0.0))
	if crete.is_empty() and _og(c, "crete", "tete").is_empty():
		t_crete = float(c.get("crete", 0.0))
	if t_crete > 0.1:
		var h2 := th * (0.25 + 0.75 * t_crete)
		var pts := PackedVector2Array()
		var n2 := 7
		var dents := str(crete.get("forme", "dentelee")) == "dentelee"
		for i in n2 * 2 + 1:
			var x := 0.12 + 0.76 * i / (n2 * 2.0)
			var q2: Vector2 = dos.call(x)
			var k := sin(PI * i / (n2 * 2.0))
			pts.append(q2 + haut_ * h2 * ((1.0 if i % 2 == 1 else 0.12) if dents else pow(k, 0.6)) * (0.5 + 0.5 * k) - X * h2 * 0.12 - haut_ * h2 * 0.05)
		for i in 3:
			pts.append(dos.call(0.88 - 0.38 * i) - haut_ * h2 * 0.2)
		p.volume(Planche.poly(pts) if dents else Planche.ferme(pts, 0.8), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})
	var epines := _og(c, "epines", "dos")
	if not epines.is_empty():
		var n3 := clampi(int(epines.get("nombre", 7)), 4, 10)
		var l := th * (0.3 + 0.5 * float(epines.get("taille", 0.5)))
		for i in n3:
			var q3: Vector2 = dos.call(0.12 + 0.76 * (i + 0.5) / n3)
			_pointe(p, q3 - haut_ * th * 0.06, q3 + haut_ * l - X * l * 0.35, maxf(e * 1.2, th * (0.16 if str(epines.get("forme", "")) == "massives" else 0.1)), T["os"])
	var ailes := _og(c, "ailes")
	var t_ailes := float(ailes.get("taille", c.get("ailes", 0.0)))
	if t_ailes > 0.3:
		# des ailes repliées sur le flanc : de plumes, ou de peau tendue sur ses doigts
		var la := 0.5 + 0.6 * t_ailes
		var forme2 := PackedVector2Array([Vector2(0.9, -0.1), Vector2(0.74, -0.46), Vector2(0.9 - la * 0.5, -0.52), Vector2(0.9 - la, -0.34), Vector2(0.9 - la * 1.08, -0.02), Vector2(0.9 - la * 0.6, 0.14), Vector2(0.62, 0.16)])
		var plumes := str(ailes.get("forme", "plumes")) != "membranes"
		p.volume(Planche.ferme(p.vivant(M * forme2, e * 0.18), 0.85 if plumes else 0.6), T["dos"].lerp(T["robe"], 0.3), func():
			var d := ""
			for i in 4:
				var b := Vector2(0.9 - la * (0.55 + 0.16 * i), 0.14 - 0.06 * i)
				d += "M%s L%s" % [Planche.pt(M * Vector2(0.82 - 0.03 * i, -0.2 - 0.03 * i)), Planche.pt(M * b)]
			p.tracer(d, maxf(0.5, e * 0.45), T["encre"] if plumes else T["robe"], 0.6),
			{"cerne": 0.95})


# le cou et la tête d'un bipède : la collerette, le cou, les oreilles, les cornes, le crâne et le museau selon le régime
static func _tete_bipede(p, c: Dictionary, m: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var hs: float = m["hs"]
	var ml: float = m["ml"]
	var th: float = m["th"]
	var base: Vector2 = m["base"]
	var o: Vector2 = m["tete"]
	var carn: bool = p.regime == "carnivore"
	var motif := str(c.get("motif", "uni"))
	p.calque("tete")
	p.pivot("tete", base)
	# le cou : il sort du poitrail, cerné sur ses deux côtés seulement
	var nuque := o + Vector2(-hs * 0.2, hs * 0.12)
	var depart := base + (base - nuque).normalized() * th * 0.22
	var cou := PackedVector2Array([depart, base, base.lerp(nuque, 0.35) + Vector2(hs * 0.03, hs * 0.02), base.lerp(nuque, 0.7) + Vector2(hs * 0.03, hs * 0.02), nuque])
	var w0 := th * 0.68
	var w1 := hs * 0.7
	p.volume(Planche.ruban(cou, w0, w1), T["robe"], func():
		var B := Planche.bords(cou, w0, w1)
		p.tracer(Planche.ouvert(B[0]), w1 * 0.5, T["dos"], 0.45)
		p.tracer(Planche.ouvert(B[1]), w1 * 0.5, T["ventre"], 0.7)
		_motif_ruban(p, motif, cou, w0, w1),
		{"lourd": false, "cerne": 0.0})
	for bord in Planche.bords(cou, w0, w1):
		p.cerne(Planche.ouvert(bord.slice(1)))
	# la collerette, derrière la tête : un disque de peau tendue (lisse), ou une fraise de pointes (frangée)
	var col := _og(c, "collerette")
	if not col.is_empty():
		var r := hs * (0.72 + 0.8 * float(col.get("taille", 0.5)))
		var ctr := o + Vector2(-hs * 0.4, -hs * 0.06)
		var frange := str(col.get("forme", "")) == "frangee"
		var pts := PackedVector2Array()
		var n := 13
		for i in n:
			var a := deg_to_rad(-200.0 + 220.0 * i / (n - 1))
			var k := 0.78 if frange and i % 2 == 1 else 1.0
			pts.append(ctr + Vector2(cos(a) * r * 0.62, sin(a) * r) * k)
		p.volume(Planche.ferme(p.vivant(pts, e * 0.15), 0.4 if frange else 0.9), T["accent"].lerp(T["robe"], 0.25), func():
			var d := ""
			for i in range(1, n - 1, 2):
				d += "M%s L%s" % [Planche.pt(ctr.lerp(pts[i], 0.3)), Planche.pt(ctr.lerp(pts[i], 0.92))]
			if p.L >= 44.0:
				p.tracer(d, maxf(0.45, e * 0.4), T["encre"], 0.5)
			p.tracer(Planche.ouvert(pts), maxf(0.8, r * 0.1), T["ventre"], 0.5),
			{"cerne": 0.9})
	# l'oreille et la corne du côté lointain
	var oreilles := float(c.get("oreilles", 0.0))
	if oreilles > 0.12 and (p.L >= 44.0 or col.is_empty()):
		_oreille(p, o + Vector2(-hs * 0.2, -hs * 0.34), hs * (0.3 + 1.0 * oreilles), carn, true)
	var cornes := _og(c, "cornes")
	var t_cornes := float(cornes.get("taille", c.get("cornes", 0.0)))
	if t_cornes > 0.1:
		_corne(p, o + Vector2(0.0, -hs * 0.4), hs * (0.5 + 1.3 * t_cornes), true, str(cornes.get("forme", "")))
	var crete := _og(c, "crete", "tete")
	if not crete.is_empty():
		var h := hs * (0.35 + 0.8 * float(crete.get("taille", 0.5)))
		var pc: PackedVector2Array
		if str(crete.get("forme", "lisse")) == "dentelee":
			pc = PackedVector2Array([o + Vector2(-hs * 0.45, -hs * 0.2), o + Vector2(-hs * 0.4, -hs * 0.4 - h), o + Vector2(-hs * 0.18, -hs * 0.44 - h * 0.3), o + Vector2(-hs * 0.08, -hs * 0.44 - h * 0.9),
				o + Vector2(hs * 0.1, -hs * 0.42 - h * 0.25), o + Vector2(hs * 0.2, -hs * 0.4 - h * 0.6), o + Vector2(hs * 0.34, -hs * 0.3)])
			p.volume(Planche.poly(pc), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})
		else:
			pc = PackedVector2Array([o + Vector2(hs * 0.3, -hs * 0.34), o + Vector2(-hs * 0.1, -hs * 0.46 - h * 0.7), o + Vector2(-hs * 0.5 - h * 0.4, -hs * 0.4 - h * 0.8), o + Vector2(-hs * 0.55, -hs * 0.1)])
			p.volume(Planche.ferme(pc, 0.75), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})
	# le crâne et le museau, d'une seule forme
	var bout: Vector2
	var pts2: PackedVector2Array
	if carn:
		# (un coin : le front fuyant, la mâchoire longue et droite)
		bout = o + Vector2(hs * 0.5 + ml * 1.1, hs * 0.1)
		pts2 = PackedVector2Array([o + Vector2(-hs * 0.56, -hs * 0.02), o + Vector2(-hs * 0.32, -hs * 0.44), o + Vector2(hs * 0.16, -hs * 0.42), o + Vector2(hs * 0.42 + ml * 0.55, -hs * 0.18),
			bout + Vector2(0, -hs * 0.11), bout + Vector2(-hs * 0.02, hs * 0.13), o + Vector2(hs * 0.3 + ml * 0.5, hs * 0.32), o + Vector2(-hs * 0.1, hs * 0.44), o + Vector2(-hs * 0.48, hs * 0.3)])
	else:
		# (un mufle : le front rond, le museau plein ; plus fin chez un omnivore)
		var r := 0.3 if p.regime == "omnivore" else 0.38
		bout = o + Vector2(hs * 0.42 + ml * 0.9, hs * 0.12)
		pts2 = PackedVector2Array([o + Vector2(-hs * 0.56, 0.0), o + Vector2(-hs * 0.34, -hs * 0.42), o + Vector2(hs * 0.14, -hs * 0.44), o + Vector2(hs * 0.4 + ml * 0.4, -hs * 0.2),
			bout + Vector2(0, -hs * r * 0.6), bout + Vector2(hs * 0.04, hs * r * 0.5), o + Vector2(hs * 0.3 + ml * 0.4, hs * 0.36), o + Vector2(-hs * 0.12, hs * 0.44), o + Vector2(-hs * 0.5, hs * 0.3)])
	p.volume(Planche.ferme(p.vivant(pts2, e * 0.15), 1.0), T["robe"], func():
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(-hs * 0.1, -hs * 0.42), hs * 0.6, hs * 0.22, 8), 1.0), T["dos"], 0.45)
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.2 + ml * 0.4, hs * 0.36), hs * 0.5 + ml * 0.4, hs * 0.2, 8), 1.0), T["ventre"], 0.8)
		if motif == "masque":
			p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(hs * 0.16, -hs * 0.1), hs * 0.52, hs * 0.2, 8, -0.1), 1.0), T["dos"].lerp(T["encre"], 0.2), 0.88))
	# la narine, la gueule, les dents
	p.aplat(Planche.ferme(Planche.ellipse(bout + Vector2(-hs * 0.04, -hs * 0.05), hs * 0.08, hs * 0.06, 6), 1.0), T["truffe"])
	p.tracer("M%s Q%s %s" % [Planche.pt(bout + Vector2(-hs * 0.05, hs * 0.1)), Planche.pt(bout + Vector2(-ml * 0.5 - hs * 0.1, hs * 0.2)), Planche.pt(o + Vector2(hs * 0.1, hs * 0.2))], e * 0.6, T["encre"], 0.85)
	if carn:
		var lc: float = hs * (0.36 if p.traits.has("crocs-allonges") else 0.18)
		for i in (3 if hs >= 9.0 else 1):
			var b := bout + Vector2(-ml * (0.3 + 0.32 * i) - hs * 0.08, hs * 0.12 + hs * 0.02 * i)
			p.svg("<path d=\"M%s L%s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(b), Planche.pt(b + Vector2(hs * 0.04, lc * (1.0 if i == 0 else 0.6))), Planche.pt(b + Vector2(hs * 0.12, 0)),
				Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.4)])
	var defenses := _og(c, "defenses")
	if not defenses.is_empty():
		var ld := hs * (0.5 + 0.8 * float(defenses.get("taille", 0.5)))
		p.volume(Planche.ruban(PackedVector2Array([bout + Vector2(-hs * 0.2, hs * 0.12), bout + Vector2(ld * 0.4, hs * 0.4), bout + Vector2(ld * 0.6, -hs * 0.1)]), maxf(e * 1.6, hs * 0.16), e * 0.6), T["os"], Callable(), {"lourd": false, "cerne": 0.75})
	p.oeil(o + Vector2(hs * (0.2 if carn else 0.1), -hs * 0.1), hs * 0.13)
	if oreilles > 0.12:
		_oreille(p, o + Vector2(-hs * 0.36, -hs * 0.28), hs * (0.3 + 1.0 * oreilles), carn, false)
	if t_cornes > 0.1:
		_corne(p, o + Vector2(-hs * 0.12, -hs * 0.38), hs * (0.5 + 1.3 * t_cornes), false, str(cornes.get("forme", "")))


# une oreille : dressée et pointue chez un chasseur, longue et couchée vers l'arrière chez une proie
static func _oreille(p, o: Vector2, l: float, pointue: bool, loin: bool) -> void:
	var T: Dictionary = p.tons
	var teinte: Color = T["loin"] if loin else T["robe"]
	var pts: PackedVector2Array
	if pointue:
		pts = PackedVector2Array([o + Vector2(-l * 0.2, 0), o + Vector2(-l * 0.06, -l), o + Vector2(l * 0.3, -l * 0.08)])
	else:
		var d := Vector2(-0.6, -0.8)
		var t := d.orthogonal()
		pts = PackedVector2Array([o, o + d * l * 0.45 + t * l * 0.22, o + d * l, o + d * l * 0.5 - t * l * 0.18])
	p.volume(Planche.ferme(pts, 0.7 if pointue else 1.0), teinte, func():
		if not loin:
			var mi := (pts[0] + pts[1] + pts[2]) / 3.0
			p.aplat(Planche.ferme(Planche.ellipse(mi, l * 0.09, l * 0.24, 6, -0.2 if pointue else 0.62), 1.0), T["accent"], 0.5),
		{"lourd": false, "cerne": 0.85})


# une corne : un ruban d'os (droite, recourbée vers l'arrière, ou ramifiée)
static func _corne(p, o: Vector2, l: float, loin: bool, forme: String) -> void:
	var T: Dictionary = p.tons
	var teinte: Color = T["os"].darkened(0.3) if loin else T["os"]
	var ligne := PackedVector2Array([o, o + Vector2(l * 0.08, -l * 0.5), o + Vector2(l * 0.2, -l)]) if forme == "droites" else PackedVector2Array([o, o + Vector2(-l * 0.1, -l * 0.5), o + Vector2(-l * 0.45, -l * 0.9)])
	p.volume(Planche.ruban(ligne, maxf(p.e * 1.6, l * 0.2), p.e * 0.7), teinte, Callable(), {"lourd": false, "cerne": 0.8})
	if forme == "ramifiees":
		_pointe(p, ligne[1], ligne[1] + Vector2(l * 0.3, -l * 0.3), maxf(p.e * 1.2, l * 0.12), teinte)
