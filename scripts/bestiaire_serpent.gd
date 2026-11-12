extends RefCounted
# Lisière — un serpent, dessiné à l'encre (scripts/bestiaire_serpent.gd)
# Un corps sans pattes, posé au sol et vu d'un peu haut : un ruban sinueux, de la queue effilée (à gauche) à la tête (à droite,
# un peu levée), d'après le plan de corps de sa lignée (p.corps). Sa longueur (long) fait ses méandres et sa finesse, sa masse
# son épaisseur (p.robustesse), sa queue (queue) la longueur de ce qui s'effile, son cou (cou) la nuque qui se pince et la tête
# qui se lève, sa tête (tete, museau) la taille et la longueur du coin ; son régime fait sa tête (le coin anguleux, l'arcade et
# les crochets d'un chasseur, la tête ronde d'une proie, le mufle large d'un filtreur) ; sa façon de se déplacer se voit (la
# queue en rame d'un nageur, le bout de queue enroulé d'un grimpeur, les anses serrées d'un sauteur). Ses organes : la
# collerette (le capuchon d'un cobra : alors il se dresse), la crête, les épines, les plaques, les cornes, la sonnette ou la
# massue, l'aiguillon, les nageoires.
# Tout tient dans un seul calque, « corps », et p.onde est vrai : le jeu fait onduler l'image entière (shaders/bete_encre.gdshader),
# la queue plus que la tête. Pas de patte : scripts/bete.gd le lit comme « sans pattes ».

const Planche := preload("res://scripts/bestiaire_planche.gd")
const KY := 0.55             # le sol est vu de biais : ce qui s'éloigne s'écrase
const N := 34                # les pas du corps, du bout de la queue à la nuque
const NC := 5                # ceux du cou, de la nuque à la tête


static func dessiner(p) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var L: float = p.L
	var e: float = p.e
	var rob: float = p.robustesse
	var loco: Array = p.locomotion
	var carn: bool = p.regime == "carnivore"
	var filtre: bool = p.regime == "filtreur" or p.regime == "detritivore"
	var long := float(c.get("long", 0.8))
	var cou := float(c.get("cou", 0.0))
	var nage: bool = loco.has("nage") or p.traits.has("palmes")
	p.onde = true
	p.calque("corps")

	# --- les mesures (en pixels montrés : la largeur est celle de la planche) ---
	var w := maxf(4.3, L * (0.09 + 0.07 * rob) / (0.72 + 0.34 * long))                # l'épaisseur du corps
	var ro: float = (1.45 if L < 60.0 else 1.7) * (1.15 if p.nocturne else 1.0)       # (le plus petit œil que dessine la planche)
	var hh := maxf(w * (0.98 + 0.42 * float(c.get("tete", 0.4))), 2.0 * (ro + e * 0.55) + 1.4)   # la hauteur de la tête
	var hl := hh * (1.05 + 0.75 * float(c.get("museau", 0.4))) * (1.06 if carn else 1.0) * (1.2 if filtre else 1.0)   # sa longueur
	var langue := 0.0 if filtre else hl * 0.46
	var col := _og(c, "collerette")
	var dresse := not col.is_empty()
	var leve := w * (0.5 + 2.2 * cou + 1.2 * float(c.get("haut", 0.0)))               # de combien la tête se lève
	var avance := maxf(leve * 1.4, w * 1.0)
	var ang := -0.1 - 0.3 * cou
	if dresse:
		# (un capuchon : le cou se dresse, la tête regarde droit devant)
		leve = w * (2.5 + 2.0 * float(col.get("taille", 0.5)))
		avance = leve * 0.25
		ang = 0.08
	var massue := _og(c, "massue")
	var dard := _og(c, "aiguillon")
	var bout_arme := not massue.is_empty() or not dard.is_empty() or not _og(c, "panache").is_empty() or not _og(c, "epines", "queue").is_empty()
	var enroule: bool = (loco.has("grimpe") or p.traits.has("queue-prehensile")) and not bout_arme and not nage
	var reserve := 0.0
	if not massue.is_empty():
		reserve = w * (0.3 + 0.5 * float(massue.get("taille", 0.5)))
	elif enroule:
		reserve = maxf(w * 1.1, e * 3.6) * 1.1

	# --- la ligne du corps : un méandre au sol, de la queue à la nuque (elle y arrive droit, du côté proche) ---
	# (ses anses reviennent un peu sur elles-mêmes : on lit un corps couché qui serpente, pas un dos qui se bombe)
	var vagues := clampf(1.25 + 0.6 * (long - 0.9) + (0.2 if loco.has("saut") else 0.0) - (0.15 if loco.has("course") else 0.0), 1.05, 1.45)
	var ampleur := clampf(1.5 + 0.9 * (long - 0.8), 1.35, 1.72)
	var brut := PackedVector2Array([Vector2.ZERO])
	var x_min := 0.0
	for i in N:
		var s := (i + 0.5) / N
		var th := ampleur * lerpf(0.7, 1.0, smoothstep(0.0, 0.4, s)) * sin(TAU * vagues * (1.0 - s))
		brut.append(brut[i] + Vector2(cos(th), sin(th) * KY))
		x_min = minf(x_min, brut[i + 1].x)
	var x_nez := L * 0.5 - langue * 0.8 - e * 0.5
	var x_b := x_nez - hl * cos(ang) - avance
	var x_q := -L * 0.5 + e + reserve
	var k := (x_b - x_q) / (brut[N].x - x_min)           # la longueur d'un pas, en pixels
	var ligne := PackedVector2Array()
	var larg := PackedFloat32Array()
	var fq := lerpf(0.3, 0.72, float(c.get("queue", 0.5)))
	var fin := maxf(0.1, e * (1.7 if enroule else 0.9) / w)      # (le bout de la queue ; plus épais s'il s'enroule : on y voit sa couleur)
	var pince := 0.1 + 0.45 * cou
	var y_haut := 0.0
	for i in N + 1:
		y_haut = minf(y_haut, (brut[i].y - brut[N].y) * k)
	for i in N + 1:
		var s := float(i) / N
		ligne.append(Vector2(x_q + (brut[i].x - x_min) * k, (brut[i].y - brut[N].y) * k))
		var f := lerpf(fin, 1.0, pow(smoothstep(0.0, fq, s), 0.8))
		if nage:
			# (une queue en rame : plate, au bout rond)
			f = maxf(f, 0.58 * pow(sin(minf(s / 0.07, 1.0) * PI * 0.5), 0.7))
		f *= 1.0 + 0.05 * sin(PI * s)
		if p.traits.has("estomac-large"):
			# (il a mangé : une bosse au milieu du corps)
			f *= 1.0 + 0.2 * exp(-pow((s - 0.56) / 0.075, 2.0))
		# (ce qui est loin est un peu plus fin)
		f *= 1.0 - 0.14 * ligne[i].y / minf(y_haut, -1.0)
		larg.append(w * maxf(fin, f) * (1.0 - pince * smoothstep(0.86, 1.0, s)))
	if bout_arme and dard.is_empty():
		# (la queue se relève pour montrer ce qu'elle porte)
		var m := int(N * 0.2)
		for i in m:
			ligne[i] += Vector2(0.25, -1.0) * w * 0.9 * pow(1.0 - float(i) / m, 2.0)
	var i0 := 0
	if enroule:
		# (un grimpeur : le bout de la queue s'enroule)
		var d0 := (ligne[0] - ligne[1]).normalized()
		var haut_ := -d0.orthogonal()
		if haut_.y > 0.0:
			haut_ = -haut_
		var rc := maxf(w * 1.1, e * 3.6)
		var centre := ligne[0] + haut_ * rc
		var boucle := PackedVector2Array()
		var lb := PackedFloat32Array()
		for j in range(5, 0, -1):
			var phi := j * 0.8
			boucle.append(centre + (-haut_ * cos(phi) + d0 * sin(phi)) * rc * (1.0 - 0.07 * j))
			lb.append(larg[0] * (1.0 - 0.09 * j))
		ligne = boucle + ligne
		larg = lb + larg
		i0 = 5
	var i1 := i0 + N
	# le cou : il quitte le sol et monte jusqu'à la tête
	var b := ligne[i1]
	var nuque := b + Vector2(avance, -leve)
	var c1 := b + Vector2(leve * 0.45 if dresse else avance * 0.55, 0.0)
	for j in range(1, NC + 1):
		var t := float(j) / NC
		ligne.append(b.lerp(c1, t).lerp(c1.lerp(nuque, t), t))
		larg.append(lerpf(larg[i1], hh * 0.78, t))
	# (le sol : le point le plus bas du corps couché le touche, un peu sous l'origine : l'ombre du jeu tombe sous lui)
	var bas_max := -1e9
	for i in i1 + 1:
		bas_max = maxf(bas_max, ligne[i].y + larg[i] * 0.5)
	var dy := L * 0.035 - bas_max
	for i in ligne.size():
		ligne[i].y += dy
	nuque.y += dy
	b.y += dy
	c1.y += dy
	var B := _bords(ligne, larg)
	var nor: PackedVector2Array = B[2]
	var pointe := ligne[0] + (ligne[0] - ligne[1]).normalized() * larg[0] * 1.3
	var contour := PackedVector2Array([pointe])
	contour.append_array(B[0])
	var dessous: PackedVector2Array = B[1].duplicate()
	dessous.reverse()
	contour.append_array(dessous)
	var d_corps := Planche.ferme(contour, 0.9)
	p.ombre(0.0, L * 0.44)

	# --- l'ombre portée : le corps est couché, la tête levée (son ombre reste au sol) ---
	var au_sol := ligne.slice(0, i1 + 1)
	var l_sol := larg.slice(0, i1 + 1)
	for t in [0.3, 0.6, 1.0, 1.5, 1.9]:
		au_sol.append(b + Vector2((avance + hl * 0.5) * t / 1.5, 0.0))
		l_sol.append(lerpf(larg[i1], hh * 0.7, minf(t, 1.0)) * (1.0 if t < 1.6 else 0.5))
	var Bs := _bords(au_sol, l_sol)
	var ombre_: PackedVector2Array = Bs[0].duplicate()
	var dessous_s: PackedVector2Array = Bs[1].duplicate()
	dessous_s.reverse()
	ombre_.append_array(dessous_s)
	p.svg("<path d=\"%s\" fill=\"%s\" opacity=\"0.24\" transform=\"translate(%s %s)\"/>" % [Planche.ferme(ombre_, 0.9), Planche.coul(T["encre"]), Planche.n(w * 0.14), Planche.n(maxf(1.2, w * 0.3))])

	# --- ce qui passe derrière le corps : le capuchon, ce que porte la queue, l'encre lourde de la tête ---
	if dresse:
		var tc := 0.74
		var centre_c := b.lerp(c1, tc).lerp(c1.lerp(nuque, tc), tc)
		var axe := (c1.lerp(nuque, tc) - b.lerp(c1, tc)).normalized()
		_capuchon(p, col, centre_c, axe, leve * 0.36, w * (0.85 + 0.9 * float(col.get("taille", 0.5))))
	var d_queue := (ligne[0] - ligne[1]).normalized()
	if not massue.is_empty():
		_massue(p, massue, pointe, d_queue, w)
	if not dard.is_empty():
		_aiguillon(p, dard, pointe, d_queue, w)
	var panache := _og(c, "panache")
	if not panache.is_empty():
		_panache(p, panache, pointe, d_queue, w)
	if not _og(c, "epines", "queue").is_empty():
		for j in 3:
			var q: Vector2 = ligne[1 + j * 2] + nor[1 + j * 2] * larg[1 + j * 2] * 0.3
			_pointe(p, q, q + Vector2(-0.25, -1.0) * w * 0.7, maxf(e * 1.2, w * 0.2), T["os"])
	var tete := _mesures_tete(p, nuque, ang, hl, hh, dresse)
	if not dresse:
		# (la tête sort du cou : son contour part des deux bords du cou, et la nuque n'a pas de trait)
		var ct: PackedVector2Array = tete["contour"]
		ct[0] = B[0][B[0].size() - 1]
		ct[ct.size() - 1] = B[1][B[1].size() - 1]
		tete["contour"] = ct
		_lourd(p, Planche.ferme(ct, 1.0))

	# --- le corps ---
	# (cerné de la nuque à la nuque, par le bout de la queue : pas de trait en travers du cou, la tête en sort)
	_lourd(p, d_corps)
	p.volume(d_corps, T["robe"], func(): _robe(p, c, ligne, nor, larg, i0, i1, w, k), {"lourd": false, "cerne": 0.0})
	var tour := dessous.duplicate()
	tour.append(pointe)
	tour.append_array(B[0])
	p.cerne(Planche.ouvert(tour, 0.9), 0.9)
	if nage:
		# (le pli de la rame, au bout de la queue)
		p.tracer(Planche.ouvert(PackedVector2Array([ligne[i0], ligne[i0 + 2], ligne[i0 + 4]])), maxf(0.45, e * 0.4), T["encre"], 0.5)
	_dos(p, c, ligne, nor, larg, i0, i1, w)

	# --- la tête ---
	_tete(p, c, tete, hl, hh, langue, dresse)


# --- le corps ---

# les deux bords d'un ruban dont la largeur change à chaque point, et ses normales (elles montrent le dos)
static func _bords(ligne: PackedVector2Array, larg: PackedFloat32Array) -> Array:
	var m := ligne.size()
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in m:
		var n := (ligne[mini(i + 1, m - 1)] - ligne[maxi(i - 1, 0)]).normalized().orthogonal()
		nor.append(n)
		haut.append(ligne[i] + n * larg[i] * 0.5)
		bas.append(ligne[i] - n * larg[i] * 0.5)
	return [haut, bas, nor]


# un point entre deux pas de la ligne (f : un rang, pas forcément entier)
static func _sur(pts: PackedVector2Array, f: float) -> Vector2:
	var i := clampi(int(floor(f)), 0, pts.size() - 2)
	return pts[i].lerp(pts[i + 1], clampf(f - i, 0.0, 1.0))


static func _larg(larg: PackedFloat32Array, f: float) -> float:
	var i := clampi(int(floor(f)), 0, larg.size() - 2)
	return lerpf(larg[i], larg[i + 1], clampf(f - i, 0.0, 1.0))


# une bande le long du corps, du rang ia au rang ib : décalée vers le dos (dec > 0) ou vers le ventre, large de k (en fois la
# largeur du corps à cet endroit)
static func _bande(ligne: PackedVector2Array, nor: PackedVector2Array, larg: PackedFloat32Array, ia: int, ib: int, dec: float, k: float) -> String:
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in range(ia, ib + 1):
		haut.append(ligne[i] + nor[i] * larg[i] * (dec + k * 0.5))
		bas.append(ligne[i] + nor[i] * larg[i] * (dec - k * 0.5))
	bas.reverse()
	return Planche.poly(haut + bas)


# un anneau en travers du corps, du rang f0 au rang f1 (un peu couché : il fait le tour d'un corps rond)
static func _anneau(ligne: PackedVector2Array, nor: PackedVector2Array, larg: PackedFloat32Array, f0: float, f1: float) -> String:
	var pts := PackedVector2Array()
	var penche := (f1 - f0) * 0.3
	for q in [[f0 - penche, 0.56], [f1 - penche, 0.56], [f1 + penche * 0.4, 0.0], [f1 - penche * 0.5, -0.56], [f0 - penche * 0.5, -0.56], [f0 + penche * 0.4, 0.0]]:
		pts.append(_sur(ligne, q[0]) + _sur(nor, q[0]) * _larg(larg, q[0]) * q[1])
	return Planche.poly(pts)


# la robe, découpée au corps : le dos sombre, le ventre pâle en liseré, le motif, un reflet, les écailles
static func _robe(p, c: Dictionary, ligne: PackedVector2Array, nor: PackedVector2Array, larg: PackedFloat32Array, i0: int, i1: int, w: float, k: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var fin := ligne.size() - 1
	var motif := str(c.get("motif", "uni"))
	p.aplat(_bande(ligne, nor, larg, 0, fin, 0.22, 0.58), T["dos"], 0.3 if motif in ["bandes", "taches"] else 0.46)
	p.aplat(_bande(ligne, nor, larg, 0, fin, -0.38, 0.26), T["ventre"], 0.92)
	var vif: bool = p.traits.has("coloration-aposematique")
	if motif == "bandes" or vif:
		# des anneaux : larges, par paires, ou bordés de clair, selon la lignée
		var genre: int = p.r.randi() % 3
		var pas: float = w * p.r.randf_range(1.45, 1.8) / k
		var demi := pas * (0.24 if genre != 1 else 0.11)
		var d := ""
		var clair := ""
		var f := float(fin) - 1.6
		while f > 1.0:
			if genre == 1:
				d += _anneau(ligne, nor, larg, f - demi * 2.3, f - demi * 0.6) + _anneau(ligne, nor, larg, f + demi * 0.6, f + demi * 2.3)
			else:
				d += _anneau(ligne, nor, larg, f - demi, f + demi)
			if genre == 2 or vif:
				clair += _anneau(ligne, nor, larg, f + demi, f + demi * 1.5) + _anneau(ligne, nor, larg, f - demi * 1.5, f - demi)
			f -= pas
		if clair != "":
			p.aplat(clair, T["ventre"], 0.75)
		p.aplat(d, T["dos"].lerp(T["encre"], 0.3), 0.85)
	elif motif == "rayures":
		# deux raies sombres le long du dos, une claire entre elles
		p.aplat(_bande(ligne, nor, larg, 1, fin, 0.12, 0.2), T["ventre"], 0.4)
		p.aplat(_bande(ligne, nor, larg, 1, fin, 0.3, 0.15), T["dos"], 0.85)
		p.aplat(_bande(ligne, nor, larg, 1, fin, -0.07, 0.15), T["dos"], 0.85)
	elif motif == "taches":
		# des selles sur le dos, des points sur le flanc entre elles
		var pas2: float = w * p.r.randf_range(1.5, 1.75) / k
		var d2 := ""
		var points := ""
		var f2 := float(fin) - 1.2
		while f2 > 1.5:
			var lw := _larg(larg, f2)
			var q := _sur(ligne, f2)
			var n := _sur(nor, f2)
			d2 += Planche.ferme(p.vivant(Planche.ellipse(q + n * lw * (0.17 if w >= 5.6 else 0.3), pas2 * k * 0.31 * sqrt(lw / w), lw * (0.36 if w >= 5.6 else 0.5), 7, n.angle() + PI * 0.5), e * 0.12), 1.0)
			var f3 := f2 - pas2 * 0.5
			if w >= 5.6 and f3 > 2.0:
				var lw3 := _larg(larg, f3)
				points += Planche.ferme(Planche.ellipse(_sur(ligne, f3) - _sur(nor, f3) * lw3 * 0.13, lw3 * 0.13, lw3 * 0.1, 6), 1.0)
			f2 -= pas2
		p.aplat(d2, T["dos"].lerp(T["encre"], 0.25), 0.85)
		if w >= 6.4:
			p.tracer(d2, maxf(0.45, e * 0.34), T["encre"], 0.4)
		if points != "":
			p.aplat(points, T["dos"], 0.7)
	elif motif == "masque":
		# (le masque est sur la tête ; il se perd en une raie sur la nuque)
		p.aplat(_bande(ligne, nor, larg, i1 - 3, fin, 0.08, 0.3), T["dos"], 0.7)
	# un reflet le long du dos, du côté de la lumière : le corps est rond, ses écailles luisent
	var dr := ""
	var i := i0 + int(N * 0.25)
	while i + 2 < fin - 1:
		dr += Planche.ouvert(PackedVector2Array([ligne[i] + nor[i] * larg[i] * 0.33, ligne[i + 1] + nor[i + 1] * larg[i + 1] * 0.33, ligne[i + 2] + nor[i + 2] * larg[i + 2] * 0.33]))
		i += 4
	p.tracer(dr, maxf(0.6, w * 0.11), Planche.clair(T["robe"]), 0.55)
	# les écailles : de petits arcs d'encre, en deux rangs, sur les grands seulement
	if w >= 6.4:
		var pas3 := maxf(1.9, w * 0.3) / k
		var de := ""
		var f4 := float(fin) - 0.6
		var rang := 0
		while f4 > float(i0) + N * 0.14:
			var lw4 := _larg(larg, f4)
			var n4 := _sur(nor, f4)
			var t4 := Vector2(-n4.y, n4.x)
			var q4 := _sur(ligne, f4) + n4 * lw4 * (0.29 if rang % 2 == 0 else 0.04)
			de += "M%s Q%s %s" % [Planche.pt(q4 + n4 * lw4 * 0.12), Planche.pt(q4 + t4 * lw4 * 0.24), Planche.pt(q4 - n4 * lw4 * 0.12)]
			f4 -= pas3 * 0.5
			rang += 1
		p.tracer(de, maxf(0.42, e * 0.32), T["encre"], 0.36)
	# l'ombre du ventre, tout en bas
	p.aplat(_bande(ligne, nor, larg, 0, fin, -0.48, 0.1), T["encre"], 0.24)


# l'encre lourde sous une forme (comme le fait volume), pour une forme qu'on cerne à part
static func _lourd(p, d: String) -> void:
	var encre: String = Planche.coul(p.tons["encre"])
	p.svg("<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" transform=\"translate(%s %s)\"/>" % [d, encre, encre, Planche.n(p.e * 1.5), Planche.n(p.e * 0.3), Planche.n(p.e * 0.5)])


# une pointe (une épine, une corne, un clou) : un triangle fin, de sa base à son bout
static func _pointe(p, base: Vector2, bout: Vector2, large: float, teinte: Color) -> void:
	var t := (bout - base).normalized().orthogonal() * large * 0.5
	p.volume(Planche.poly(PackedVector2Array([base + t, bout, base - t])), teinte, Callable(), {"lourd": false, "cerne": 0.7, "plat": true})


# --- les organes ---

# un organe de la lignée ({} : elle ne l'a pas)
static func _og(c: Dictionary, type: String, place := "") -> Dictionary:
	var o = c.get("organes", [])
	if typeof(o) == TYPE_ARRAY:
		for x in o:
			if typeof(x) == TYPE_DICTIONARY and str(x.get("type", "")) == type and (place == "" or str(x.get("place", "")) == place):
				return x
	return {}


# ce que porte le dos : une crête (lisse : une voile basse ; dentelée : des pointes), des épines, des plaques, des nageoires
static func _dos(p, c: Dictionary, ligne: PackedVector2Array, nor: PackedVector2Array, larg: PackedFloat32Array, i0: int, i1: int, w: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var crete := _og(c, "crete", "dos")
	var t_crete := float(crete.get("taille", 0.0))
	if crete.is_empty() and _og(c, "crete", "tete").is_empty():
		t_crete = float(c.get("crete", 0.0))
	var nageoire := _og(c, "nageoires")
	var ia := i0 + int(N * 0.16)
	var ib := i1 + 2
	# (la ligne du dos : là où le corps tourne vers nous ; ce qui s'y dresse ne se voit bien que là où le corps passe de
	# profil : sur ses anses, il se perd)
	var arete := func(f: float) -> Vector2: return _sur(ligne, f) + _sur(nor, f) * _larg(larg, f) * 0.34
	var profil := func(f: float) -> float: return smoothstep(0.3, 0.75, absf(_sur(nor, f).y)) * _larg(larg, f) / w
	if t_crete > 0.1 or not nageoire.is_empty():
		var h := w * (0.3 + 0.75 * maxf(t_crete, float(nageoire.get("taille", 0.0)) * (1.3 if str(nageoire.get("forme", "")) == "voiles" else 0.8)))
		var teinte: Color = T["accent"] if t_crete > 0.1 else T["dos"].lerp(T["robe"], 0.4)
		var pts := PackedVector2Array()
		var haut := PackedVector2Array()
		var m := ib - ia
		var dents := str(crete.get("forme", "lisse")) == "dentelee" and nageoire.is_empty()
		for i in m + 1:
			var hi: float = h * profil.call(float(ia + i)) * pow(sin(PI * float(i) / m), 0.5)
			if dents:
				hi *= 1.0 if i % 2 == 1 else 0.3
			pts.append(arete.call(float(ia + i)))
			haut.append(pts[i] + Vector2(-0.15, -1.0) * hi)
		var base := pts.duplicate()
		base.reverse()
		p.volume(Planche.poly(haut + base) if dents else Planche.ferme(haut + base, 0.8), teinte, func():
			# (les rayons de la voile)
			if not dents:
				for i in range(2, m - 1, 2):
					p.tracer("M%s L%s" % [Planche.pt(pts[i]), Planche.pt(haut[i])], maxf(0.45, e * 0.4), T["encre"], 0.5),
			{"lourd": false, "cerne": 0.75})
	var epines := _og(c, "epines", "dos")
	if not epines.is_empty():
		var m2 := clampi(int(epines.get("nombre", 7)), 4, 10) + 3
		var l := w * (0.4 + 0.8 * float(epines.get("taille", 0.5)))
		var gros := maxf(e * 1.1, w * (0.26 if str(epines.get("forme", "")) == "massives" else 0.16))
		for i in m2:
			var f := lerpf(ia, ib, (i + 0.5) / m2)
			var pr: float = profil.call(f)
			if pr > 0.25:
				var q: Vector2 = arete.call(f)
				_pointe(p, q, q + Vector2(-0.3, -1.0) * l * pr, gros, T["os"])
	var plaques := _og(c, "plaques")
	var t_plaques := float(plaques.get("taille", 0.0))
	if plaques.is_empty() and _og(c, "carapace").is_empty():
		# (une carapace sans organe : une cuirasse d'écussons le long du dos)
		t_plaques = float(c.get("carapace", 0.0)) * 0.6 if float(c.get("carapace", 0.0)) > 0.3 else 0.0
	elif plaques.is_empty():
		t_plaques = float(_og(c, "carapace").get("taille", 0.5)) * 0.6
	if t_plaques > 0.0:
		var m3 := clampi(int(plaques.get("nombre", 7)), 4, 9) + 3
		var h3 := w * (0.3 + 0.6 * t_plaques)
		for i in m3:
			var f := lerpf(ia, ib, (i + 0.5) / m3)
			var pr3: float = profil.call(f)
			if pr3 < 0.25:
				continue
			var q3: Vector2 = arete.call(f)
			var t3 := -_sur(nor, f).orthogonal()
			var hh3 := h3 * pr3
			if str(plaques.get("forme", "rondes")) == "triangles":
				p.volume(Planche.poly(PackedVector2Array([q3 - t3 * hh3 * 0.5, q3 + Vector2(-0.1, -1.0) * hh3, q3 + t3 * hh3 * 0.5])), T["accent"], Callable(), {"lourd": false, "cerne": 0.7})
			else:
				p.volume(Planche.ferme(Planche.ellipse(q3 + Vector2(0.0, -hh3 * 0.3), hh3 * 0.5, hh3 * 0.55, 7), 1.0), T["accent"], Callable(), {"lourd": false, "cerne": 0.7})
	# des ailes repliées sur le dos (rare : un serpent qui plane)
	var ailes := _og(c, "ailes")
	if not ailes.is_empty() or float(c.get("ailes", 0.0)) > 0.3:
		var ta := float(ailes.get("taille", c.get("ailes", 0.5)))
		var f5 := lerpf(ia, ib, 0.7)
		var a0: Vector2 = arete.call(f5)
		var la := w * (1.6 + 2.2 * ta)
		var aile := PackedVector2Array([a0, a0 + Vector2(-la * 0.3, -la * 0.42), a0 + Vector2(-la * 0.75, -la * 0.34), a0 + Vector2(-la, -la * 0.05), a0 + Vector2(-la * 0.5, la * 0.02)])
		p.volume(Planche.ferme(aile, 0.7), T["dos"], func():
			for i in 3:
				var bout := a0 + Vector2(-la * (0.45 + 0.25 * i), -la * (0.3 - 0.12 * i))
				p.tracer("M%s L%s" % [Planche.pt(a0), Planche.pt(bout)], maxf(0.45, e * 0.45), T["robe"] if str(ailes.get("forme", "")) == "membranes" else T["encre"], 0.6),
			{"lourd": false, "cerne": 0.8})


# le capuchon : le cou d'un cobra, étalé derrière lui (lisse), ou une fraise de pointes (frangée)
static func _capuchon(p, o: Dictionary, centre: Vector2, axe: Vector2, demi_long: float, demi_large: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var frange := str(o.get("forme", "")) == "frangee"
	var cote := axe.orthogonal()
	var m := 16
	var pts := PackedVector2Array()
	for i in m:
		var a := TAU * i / m
		var r := 0.76 if frange and i % 2 == 1 else 1.0
		# (plus large vers la tête : une goutte renversée)
		pts.append(centre + axe * (cos(a) * demi_long * r) + cote * (sin(a) * demi_large * (1.0 + 0.22 * cos(a)) * r))
	p.volume(Planche.ferme(p.vivant(pts, e * 0.15), 0.4 if frange else 1.0), T["accent"].lerp(T["robe"], 0.3), func():
		# (les côtes du capuchon, et ses deux « lunettes »)
		var d := ""
		for i in 7:
			var a := -1.25 + 2.5 * i / 6.0
			for s in [-1.0, 1.0]:
				var dir: Vector2 = (axe * sin(a) * 0.6 + cote * s * cos(a)).normalized()
				d += "M%s L%s" % [Planche.pt(centre + dir * demi_large * 0.42), Planche.pt(centre + dir * demi_large * 1.05)]
		p.tracer(d, maxf(0.45, e * 0.4), T["encre"], 0.42)
		if demi_large >= 5.0:
			for s in [-1.0, 1.0]:
				var q: Vector2 = centre + cote * s * demi_large * 0.62 + axe * demi_long * 0.12
				p.aplat(Planche.ferme(Planche.ellipse(q, demi_large * 0.2, demi_long * 0.22, 7, axe.angle() + PI * 0.5), 1.0), T["ventre"], 0.8)
				p.aplat(Planche.ferme(Planche.ellipse(q, demi_large * 0.09, demi_long * 0.1, 6), 1.0), T["dos"], 0.9),
		{"cerne": 0.9})


# la sonnette (une massue ronde : des grelots d'os au bout de la queue) ou la massue cloutée
static func _massue(p, o: Dictionary, bout: Vector2, d: Vector2, w: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var t := float(o.get("taille", 0.5))
	if str(o.get("forme", "ronde")) == "cloutee":
		var r := w * (0.42 + 0.4 * t)
		var ctr := bout + d * r * 0.5
		for i in 6:
			var dir := Vector2.from_angle(TAU * i / 6.0 + 0.3)
			_pointe(p, ctr + dir * r * 0.7, ctr + dir * r * 1.65, maxf(e * 1.2, r * 0.42), T["os"])
		p.volume(Planche.ferme(Planche.ellipse(ctr, r * 1.1, r, 8, d.angle()), 1.0), T["dos"], Callable(), {"cerne": 0.85})
		return
	var r0 := maxf(1.3, w * (0.2 + 0.2 * t))
	var m := 3 + int(round(t * 2.0))
	var q := bout + d * r0 * (m - 1) * 1.15
	# (du bout vers la queue : chaque grelot recouvre le suivant)
	for i in m:
		var r1 := r0 * (0.62 + 0.38 * float(i) / (m - 1))
		p.volume(Planche.ferme(Planche.ellipse(q, r1 * 0.8, r1, 7, d.angle()), 1.0), T["os"].darkened(0.12), Callable(), {"lourd": i == 0, "cerne": 0.7})
		q -= d * r0 * 1.15


# l'aiguillon : une ampoule de venin au bout de la queue, et son dard (courbe : un crochet de scorpion)
static func _aiguillon(p, o: Dictionary, bout: Vector2, d: Vector2, w: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var l := w * (0.7 + 1.0 * float(o.get("taille", 0.5)))
	var haut_ := Vector2(0.0, -1.0)
	var a := bout + d * w * 0.1
	var c1 := a + d * l * 0.75 + haut_ * l * 0.05
	var z := a + d * l * 0.45 + haut_ * l * 0.85
	if str(o.get("forme", "courbe")) != "courbe":
		c1 = a + d * l * 0.5
		z = a + d * l
	var ligne := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		ligne.append(a.lerp(c1, t).lerp(c1.lerp(z, t), t))
	p.volume(Planche.ruban(ligne, maxf(e * 1.5, w * 0.34), e * 0.5), T["os"].darkened(0.1), Callable(), {"lourd": false, "cerne": 0.7, "plat": true})
	p.volume(Planche.ferme(Planche.ellipse(bout - d * w * 0.05, maxf(e * 1.3, w * 0.42), maxf(e * 1.1, w * 0.34), 7, d.angle()), 1.0), T["accent"], Callable(), {"cerne": 0.75})


# un panache : une touffe au bout de la queue, ou un éventail
static func _panache(p, o: Dictionary, bout: Vector2, d: Vector2, w: float) -> void:
	var T: Dictionary = p.tons
	var l := w * (0.8 + 1.4 * float(o.get("taille", 0.5)))
	var ouvert_ := 1.1 if str(o.get("forme", "")) == "eventail" else 0.5
	var dd := ""
	for i in 5:
		var dir := d.rotated(lerpf(-ouvert_, ouvert_, i / 4.0) + 0.5)
		dd += "M%s Q%s %s" % [Planche.pt(bout - d * w * 0.2), Planche.pt(bout + dir * l * 0.5 + Vector2(0, -l * 0.1)), Planche.pt(bout + dir * l)]
	p.tracer(dd, maxf(1.2, w * 0.24) + p.e * 0.9, T["encre"])
	p.tracer(dd, maxf(1.2, w * 0.24), T["accent"])


# --- la tête ---

# où est la tête : son repère (u : de la nuque au nez, v : vers la gorge), son contour (ouvert : de la nuque, par le nez, à la
# gorge), son régime
static func _mesures_tete(p, nuque: Vector2, ang: float, hl: float, hh: float, dresse: bool) -> Dictionary:
	var a := Vector2.from_angle(ang)
	var M := Transform2D(a * hl, Vector2(-a.y, a.x) * hh, nuque)
	if dresse:
		# (la tête se pose sur le cou dressé, qui lui arrive par-dessous)
		M.origin = nuque - M.x * 0.16 - M.y * 0.2
	var uv: PackedVector2Array
	if p.regime == "carnivore":
		# (un coin : le front plat, l'arcade, la joue large des glandes à venin)
		uv = PackedVector2Array([Vector2(-0.06, -0.4), Vector2(0.24, -0.5), Vector2(0.52, -0.4), Vector2(0.84, -0.17), Vector2(1.0, 0.0),
			Vector2(0.95, 0.17), Vector2(0.6, 0.31), Vector2(0.22, 0.5), Vector2(-0.08, 0.37)])
	elif p.regime == "filtreur" or p.regime == "detritivore":
		# (un crâne rond, puis une spatule plate qui fouille la vase)
		uv = PackedVector2Array([Vector2(-0.06, -0.4), Vector2(0.24, -0.5), Vector2(0.5, -0.42), Vector2(0.66, -0.2), Vector2(0.9, -0.2), Vector2(1.04, -0.06),
			Vector2(1.04, 0.12), Vector2(0.9, 0.24), Vector2(0.6, 0.25), Vector2(0.38, 0.42), Vector2(0.12, 0.44), Vector2(-0.08, 0.36)])
	else:
		# (une tête ronde, douce)
		uv = PackedVector2Array([Vector2(-0.06, -0.4), Vector2(0.28, -0.5), Vector2(0.62, -0.42), Vector2(0.9, -0.22), Vector2(1.0, 0.02),
			Vector2(0.92, 0.22), Vector2(0.55, 0.38), Vector2(0.15, 0.44), Vector2(-0.08, 0.36)])
	var contour: PackedVector2Array = p.vivant(M * uv, p.e * 0.12)
	return {"M": M, "contour": contour}


static func _tete(p, c: Dictionary, tete: Dictionary, hl: float, hh: float, langue: float, dresse: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var M: Transform2D = tete["M"]
	var contour: PackedVector2Array = tete["contour"]
	var carn: bool = p.regime == "carnivore"
	var filtre: bool = p.regime == "filtreur" or p.regime == "detritivore"
	var a := M.x.normalized()
	# ce qui passe derrière le crâne : la corne du côté lointain, la crête
	var cornes := _og(c, "cornes")
	var t_cornes := float(cornes.get("taille", c.get("cornes", 0.0)))
	var n_cornes := int(cornes.get("nombre", 2))
	if t_cornes > 0.1 and n_cornes != 1:
		_corne(p, M * Vector2(0.6, -0.4), hh * (0.4 + 0.9 * t_cornes), true, str(cornes.get("forme", "")))
	var crete := _og(c, "crete", "tete")
	if not crete.is_empty():
		var h := hh * (0.35 + 0.75 * float(crete.get("taille", 0.5)))
		var pts: PackedVector2Array
		if str(crete.get("forme", "lisse")) == "dentelee":
			pts = PackedVector2Array([M * Vector2(-0.05, -0.3), M * Vector2(0.02, -0.4) + Vector2(-h * 0.5, -h * 0.8), M * Vector2(0.2, -0.45) + Vector2(-h * 0.1, -h * 0.3),
				M * Vector2(0.28, -0.45) + Vector2(-h * 0.3, -h), M * Vector2(0.45, -0.42) + Vector2(0, -h * 0.25), M * Vector2(0.55, -0.4) + Vector2(-h * 0.1, -h * 0.7), M * Vector2(0.7, -0.25)])
			p.volume(Planche.poly(pts), T["accent"], Callable(), {"lourd": false, "cerne": 0.75})
		else:
			pts = PackedVector2Array([M * Vector2(0.64, -0.3), M * Vector2(0.3, -0.5) + Vector2(-h * 0.1, -h * 0.7), M * Vector2(0.0, -0.45) + Vector2(-h * 0.6, -h * 0.85),
				M * Vector2(-0.12, -0.4) + Vector2(-h * 0.5, -h * 0.15), M * Vector2(-0.05, -0.2)])
			p.volume(Planche.ferme(pts, 0.7), T["accent"], func():
				for i in 3:
					p.tracer("M%s L%s" % [Planche.pt(M * Vector2(0.1 + 0.15 * i, -0.4)), Planche.pt(M * Vector2(0.05 + 0.13 * i, -0.45) + Vector2(-h * (0.5 - 0.15 * i), -h * (0.7 - 0.05 * i)))], maxf(0.45, e * 0.4), T["encre"], 0.5),
				{"lourd": false, "cerne": 0.75})
	# le crâne et le museau, d'une seule forme ; la nuque n'a pas de trait : la tête sort du cou
	var bouche := PackedVector2Array([M * Vector2(0.98, 0.08 if carn else 0.1), M * Vector2(0.62, 0.11), M * Vector2(0.34, 0.19), M * Vector2(0.15, 0.3 if carn else 0.24)])
	if filtre:
		bouche = PackedVector2Array([M * Vector2(1.04, 0.03), M * Vector2(0.72, 0.04), M * Vector2(0.5, 0.13), M * Vector2(0.3, 0.24)])
	var d := Planche.ferme(contour, 1.0)
	var dedans := func():
		p.aplat(Planche.ferme(M * Planche.ellipse(Vector2(0.3, -0.46), 0.6, 0.2, 8), 1.0), T["dos"], 0.5)
		var gorge := bouche.duplicate()
		gorge.append(M * Vector2(-0.1, 0.7))
		gorge.append(M * Vector2(1.1, 0.6))
		p.aplat(Planche.poly(gorge), T["ventre"], 0.9)
		if str(c.get("motif", "")) == "masque":
			p.aplat(Planche.ferme(M * Planche.ellipse(Vector2(0.42, -0.1), 0.66, 0.17, 8), 1.0), T["dos"], 0.88)
		if p.traits.has("coloration-aposematique"):
			p.aplat(Planche.ferme(M * Planche.ellipse(Vector2(0.05, 0.0), 0.16, 0.7, 6), 1.0), T["ventre"], 0.8)
	if dresse:
		p.volume(d, T["robe"], dedans)
	else:
		p.volume(d, T["robe"], dedans, {"lourd": false, "cerne": 0.0})
		p.cerne(Planche.ouvert(contour))
	# la gueule, la narine
	p.tracer(Planche.ouvert(bouche), e * 0.55, T["encre"], 0.85)
	if hh >= 7.4:
		var nar := M * Vector2(0.9, -0.03 if carn else -0.05)
		p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(nar.x), Planche.n(nar.y), Planche.n(maxf(0.4, hh * 0.035)), Planche.coul(T["encre"])])
	if carn or not _og(c, "defenses").is_empty():
		# les crochets : deux, clairs, sous la lèvre
		var lc := 0.62 if p.traits.has("crocs-allonges") or not _og(c, "defenses").is_empty() else 0.36
		for f in ([[0.7, 0.72], [0.82, 1.0]] if hh >= 6.6 else [[0.8, 1.0]]):
			var b: Vector2 = M * Vector2(f[0], 0.09)
			p.svg("<path d=\"M%s Q%s %s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(b), Planche.pt(b + M.y * lc * f[1] * 0.6 + M.x * 0.05), Planche.pt(b + M.y * lc * f[1] - M.x * 0.02),
				Planche.pt(b + M.x * 0.09), Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.32)])
	# la langue, fourchue
	if langue > 0.0:
		var l0 := M * Vector2(0.99, 0.07 if carn else 0.09)
		var l1 := l0 + a * langue * 0.6 + Vector2(0.0, langue * 0.08)
		var t := a.orthogonal() * maxf(0.5, e * 0.4)
		p.aplat(Planche.poly(PackedVector2Array([l0 + t, l1 + t * 0.8, l1 + a.rotated(-0.5) * langue * 0.46, l1 + a * langue * 0.12, l1 + a.rotated(0.5) * langue * 0.44, l1 - t * 0.8, l0 - t])),
			T["accent"].lerp(T["os"], 0.18))
	# des barbillons (des antennes, chez un serpent)
	var antennes := _og(c, "antennes")
	if not antennes.is_empty() or float(c.get("antennes", 0.0)) > 0.3:
		var la := hh * (0.6 + 1.2 * float(antennes.get("taille", c.get("antennes", 0.4))))
		for s in [0.0, 0.1]:
			var q0: Vector2 = M * Vector2(0.92 - s, -0.14)
			p.tracer("M%s Q%s %s" % [Planche.pt(q0), Planche.pt(q0 + Vector2(la * 0.1, -la * 0.7)), Planche.pt(q0 + Vector2(la * 0.6, -la * 0.8))], maxf(0.6, e * 0.5), T["encre"], 0.9)
	# l'œil : une pupille en fente
	p.oeil(M * Vector2(0.52 if carn else (0.4 if filtre else 0.56), -0.12 if carn else -0.1), hh * 0.17, {"fente": true})
	# la corne du côté proche (une seule : sur le nez)
	if t_cornes > 0.1:
		if n_cornes == 1:
			_corne(p, M * Vector2(0.86, -0.18), hh * (0.4 + 0.9 * t_cornes), false, "nez")
		else:
			_corne(p, M * Vector2(0.5, -0.44), hh * (0.4 + 0.9 * t_cornes), false, str(cornes.get("forme", "")))


# une corne : une écaille dressée au-dessus de l'œil (une vipère à cornes), ou sur le nez
static func _corne(p, o: Vector2, l: float, loin: bool, forme: String) -> void:
	var T: Dictionary = p.tons
	var teinte: Color = T["os"].darkened(0.3) if loin else T["os"]
	var bout := o + (Vector2(0.25, -1.0) if forme == "nez" or forme == "droites" else Vector2(-0.35, -0.95)) * l
	var milieu := (o + bout) * 0.5 + (Vector2(0.1, -0.05) if forme == "nez" else Vector2(0.12, -0.1)) * l
	p.volume(Planche.ruban(PackedVector2Array([o, milieu, bout]), maxf(p.e * 1.7, l * 0.3), p.e * 0.6), teinte, Callable(), {"lourd": false, "cerne": 0.75})
	if forme == "ramifiees":
		_pointe(p, milieu, milieu + Vector2(0.5, -0.4) * l * 0.5, maxf(p.e * 1.2, l * 0.16), teinte)
