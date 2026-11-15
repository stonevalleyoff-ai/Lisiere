extends RefCounted
# Lisière — les herbes de l'herbier, là où elles poussent (scripts/herbe.gd)
# Les sept formes de scripts/botanique.gd (FORMES), à la taille du lieu, au pinceau de l'environnement
# (scripts/decor_pinceau.gd). Une herbe fait de douze à vingt-deux pixels : moins qu'un buisson, assez pour qu'on la
# remarque en passant. Elle se reconnaît à sa silhouette (l'ombelle plate sur ses rayons, la hampe qui ploie sous ses
# clochettes, l'épi dressé sur sa rosette, les larges feuilles à plat, le petit buisson à baies, l'étoile du chardon, les
# crosses enroulées) et à la couleur de son espèce (Botanique.couleur).
# Le lieu donne le port et le vert (port) : la taïga fait trapu et givré, le marais haut et luisant, la lande grêle et
# grise, la prairie tendre. Le signe de l'espèce se voit (Botanique.signe) : la tige rouge sang, le duvet d'argent, les
# insectes du miel (un nœud à part, que sa matière fait tourner sans que rien ne se redessine : Essaim), la goutte de
# lait sur la tige coupée.
# objet.gd appelle dessiner (une herbe du lieu : entière, cueillie, qui repousse) ; campement.gd appelle plant (un plant
# d'un carré de jardin, à ses stades). Une herbe coûte ce que coûte une touffe : quelques centaines de sommets, posés
# une fois, dans le maillage de son objet.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const Botanique := preload("res://scripts/botanique.gd")

const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
const NEIGE := Color("f1ebdc")
const ARGENT := Color("cdd6dc")          # le duvet : la lune, tirée vers le papier
const ROUGE_SANG := Color("a8291f")      # la tige d'une herbe « rouge » : le sang, avivé de braise pour qu'il se voie de loin
const LAIT := Color("f6f1e4")
const PAILLE := Color("c4a877")          # ce que jaunit un plant qui a soif (la fibre du campement)
# les insectes : chacun tourne autour de sa fleur (UV.x : sa phase ; UV.y : le rayon de sa ronde), sans redessin
const CODE_ESSAIM := "shader_type canvas_item;\nvoid vertex() {\n\tfloat a = TIME * (1.9 + fract(UV.x * 3.7) * 1.7) + UV.x * 6.2831;\n" \
	+ "\tVERTEX += vec2(cos(a) * UV.y, sin(a * 1.31 + UV.x * 4.0) * UV.y * 0.5 + sin(a * 3.3) * 0.45);\n}\n"

static var _ports := {}
static var _matiere_essaim: ShaderMaterial


# ce que le lieu fait d'une herbe : son vert, sa taille (haut, large), la finesse de ses feuilles, son givre, son luisant
static func port(lieu: String) -> Dictionary:
	if _ports.is_empty():
		_ports = {
			"foret": {"vert": P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.12).lightened(0.1), "haut": 1.0, "large": 1.0, "fin": 1.0, "givre": 0.0, "luit": 0.0},
			"lande": {"vert": P.MOUSSE.lerp(P.IVOIRE.darkened(0.15), 0.5), "haut": 0.9, "large": 0.96, "fin": 0.78, "givre": 0.0, "luit": 0.0},
			"marais": {"vert": P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.36).lerp(P.NUIT_BLEUE, 0.1).lightened(0.04), "haut": 1.2, "large": 0.9, "fin": 1.0, "givre": 0.0, "luit": 1.0},
			"prairie": {"vert": P.MOUSSE.lightened(0.16).lerp(P.BRAISE_COEUR, 0.1), "haut": 1.04, "large": 1.06, "fin": 1.0, "givre": 0.0, "luit": 0.0},
			"taiga": {"vert": P.MOUSSE.lerp(P.LUNE, 0.32).darkened(0.06), "haut": 0.8, "large": 1.16, "fin": 1.12, "givre": 1.0, "luit": 0.0},
		}
	return _ports.get(lieu, _ports["foret"])


# une herbe du lieu, le pied à l'origine du pinceau. entiere : on ne l'a pas cueillie ; pousse : de 0 (on vient de la couper)
# à 1 (elle est revenue) ; climat : celui de l'objet (froid, humide) ; roussi : ce qu'un feu voisin en a grillé
static func dessiner(p, id: String, graine: int, entiere: bool, pousse: float, climat: Dictionary, roussi: float = 0.0, teinte: Color = Color.WHITE) -> void:
	var forme := Botanique.forme_de(id)
	var po := port(Botanique.lieu_de(id))
	var signe := Botanique.signe(id)
	var pl := Plant.new()
	pl.p = p
	pl.r.seed = graine * 31 + 7
	pl.lieu = Botanique.lieu_de(id)
	var froid := float(climat.get("froid", 0.0))
	var humide := float(climat.get("humide", 0.5))
	pl.givre = maxf(float(po["givre"]), smoothstep(0.25, 0.6, froid))
	pl.neige = smoothstep(0.35, 0.75, froid)
	pl.luit = maxf(float(po["luit"]), smoothstep(0.62, 0.85, humide))
	# (chaque plant diffère de son voisin : sa taille, son côté, son aplomb)
	var k := pl.r.randf_range(0.9, 1.1)
	pl.e = float(po["haut"]) * k
	pl.l = float(po["large"]) * lerpf(1.0, k, 0.5)
	pl.fin = float(po["fin"])
	pl.sens = 1.0 if graine % 2 == 0 else -1.0
	pl.pen = pl.r.randf_range(-0.08, 0.08)
	var vert: Color = po["vert"]
	if teinte != Color.WHITE and roussi <= 0.0:
		# (si le lieu donne sa teinte, comme aux touffes : elle tire le vert à elle)
		vert = vert.lerp(teinte, 0.35)
	var fleur := Botanique.couleur(id)
	if roussi > 0.0:
		var roux := P.TERRE.lerp(P.BRAISE_ROUGE, 0.4)
		vert = vert.lerp(roux, 0.45 + 0.35 * roussi).darkened(0.08 + 0.3 * roussi)
		fleur = fleur.lerp(roux, 0.5 * roussi)
	pl.couleurs(vert, fleur, signe)
	if entiere:
		pl.pousser(forme, 1.0)
	elif pousse < 0.5:
		pl.coupee(forme, signe == "lait", pousse >= 0.25)
	else:
		# (elle revient : petite et verte, puis en boutons)
		var u := 0.56 if pousse < 0.75 else 0.8
		pl.e *= u
		pl.l *= lerpf(u, 1.0, 0.35)
		pl.pousser(forme, 0.0 if pousse < 0.75 else 0.5)
	pl.finir()


# les insectes d'une herbe à miel : posés une fois sur son objet, ils tournent sans lui (et se cachent quand on l'a cueillie)
static func essaim(objet: Node2D, graine: int, haut: float) -> void:
	if objet.has_meta("essaim"):
		return
	objet.set_meta("essaim", true)
	if _matiere_essaim == null:
		var sh := Shader.new()
		sh.code = CODE_ESSAIM
		_matiere_essaim = ShaderMaterial.new()
		_matiere_essaim.shader = sh
	var es := Essaim.new()
	es.graine = graine
	es.haut = haut
	es.material = _matiere_essaim
	# (on est en plein dessin de l'objet : le nœud s'ajoute après)
	objet.add_child.call_deferred(es)


# la hauteur de ses fleurs, à peu près (où tournent les insectes)
static func cime(id: String) -> float:
	var h := 17.0
	match Botanique.forme_de(id):
		"rosette":
			h = 7.0
		"morelle":
			h = 11.0
		"clochette", "crosse":
			h = 14.0
	return h * float(port(Botanique.lieu_de(id))["haut"])


class Essaim extends Node2D:
	var graine := 0
	var haut := 16.0

	func _ready() -> void:
		var o := get_parent()
		if o is CanvasItem:
			o.draw.connect(_voir)
		_voir()

	# (cueillie, en feu, en cendres : plus de fleurs, plus d'insectes)
	func _voir() -> void:
		var o = get_parent()
		if o == null:
			return
		visible = int(o.get("reste")) > 0 and not bool(o.get("calcine")) and float(o.get("brule")) <= 0.0

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = graine + 3
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var corps := Color(0.1, 0.08, 0.05)
		var aile := Color(P.PAPIER, 0.8)
		var miel := P.BRAISE.lerp(P.BRAISE_COEUR, 0.3)
		var n := 2 + graine % 2
		for i in n:
			var c := Vector2(r.randf_range(-3.5, 3.5), -haut - r.randf_range(-1.0, 3.5))
			var uv := Vector2(r.randf(), r.randf_range(2.6, 4.8))
			# deux ailes pâles, le corps d'encre par-dessus, son anneau de miel
			for cote in [-1.0, 1.0]:
				var b := pts.size()
				pts.append_array(PackedVector2Array([c, c + Vector2(2.1 * cote, -1.4), c + Vector2(0.7 * cote, -2.3)]))
				for k in 3:
					cols.append(aile)
					uvs.append(uv)
				idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
			var b0 := pts.size()
			pts.append_array(PackedVector2Array([c + Vector2(-1.5, 0.0), c + Vector2(0.0, -1.0), c + Vector2(1.5, 0.0), c + Vector2(0.0, 1.0)]))
			for k in 4:
				cols.append(corps if k != 2 else miel)
				uvs.append(uv)
			idx.append_array(PackedInt32Array([b0, b0 + 1, b0 + 2, b0, b0 + 2, b0 + 3]))
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs)


# --- une plante, à l'encre : ses gestes, ses sept formes ---

class Plant extends RefCounted:
	var p
	var r := RandomNumberGenerator.new()
	var lieu := "foret"
	var q := Vector2.ZERO      # le pied
	var e := 1.0               # l'échelle, en hauteur
	var l := 1.0               # en largeur
	var fin := 1.0             # la finesse des feuilles
	var sens := 1.0
	var pen := 0.0             # son aplomb
	var vert := Color.WHITE
	var clair := Color.WHITE
	var sombre := Color.WHITE
	var tige := Color.WHITE
	var fleur := Color.WHITE
	var duvet := false
	var givre := 0.0
	var neige := 0.0
	var luit := 0.0
	var cimes: Array = []      # où la neige se pose : [un point, une demi-largeur]

	func couleurs(v: Color, f: Color, signe: String) -> void:
		vert = v
		clair = v.lightened(0.16)
		sombre = v.darkened(0.24)
		tige = v.lerp(P.IVOIRE, 0.3)
		fleur = f
		duvet = signe == "duvet"
		if signe == "rouge":
			tige = ROUGE_SANG

	# un point de la plante : x de part et d'autre de l'axe, y au-dessus du sol (en pixels d'une herbe de taille 1)
	func pt(x: float, y: float) -> Vector2:
		return q + Vector2(x * l * sens + pen * y * e, -y * e)

	# un trait de couleur, cerné d'encre
	func brin(ligne: PackedVector2Array, w: float, c: Color, larg := PackedFloat32Array()) -> void:
		if larg.is_empty():
			p.tracer(ligne, w + 0.95, ENCRE, false)
			p.tracer(ligne, w, c, false)
			return
		var gras := PackedFloat32Array()
		for x in larg:
			gras.append(x + 0.95)
		p.tracer(ligne, w, ENCRE, false, gras)
		p.tracer(ligne, w, c, false, larg)

	# une feuille : un trait qui s'élargit puis s'effile, de l'attache à la pointe ; courbe : ce dont elle se cambre ;
	# spatule : large vers le bout (une feuille de rosette)
	func limbe(a: Vector2, b: Vector2, w: float, c: Color, courbe := 0.0, spatule := false) -> void:
		var d := b - a
		var n := d.orthogonal().normalized()
		var ligne := PackedVector2Array([a, a + d * 0.34 + n * courbe, a + d * 0.7 + n * courbe * 0.8, b])
		w *= fin
		var larg := PackedFloat32Array([w * 0.4, w, w * 0.76, 0.3])
		if spatule:
			larg = PackedFloat32Array([w * 0.34, w * 0.72, w, w * 0.42])
		if duvet:
			c = c.lerp(ARGENT, 0.5)
		brin(ligne, w, c, larg)
		# (le côté du jour)
		if n.y > 0.0:
			n = -n
		if duvet:
			# le duvet : un liseré d'argent sur le dos de la feuille
			p.tracer(PackedVector2Array([ligne[0], ligne[1] + n * w * 0.36, ligne[2] + n * w * 0.3, ligne[3]]), 0.75, ARGENT.lightened(0.35), false)
		elif luit > 0.0 and w > 2.0:
			p.tracer(PackedVector2Array([ligne[1] + n * w * 0.18, ligne[2] + n * w * 0.14]), 0.6, Color(P.ECHO, 0.55 * luit))
		if givre > 0.0:
			p.tracer(PackedVector2Array([a + d * 0.8 + n * courbe * 0.5, b]), clampf(w * 0.3, 0.7, 1.1), Color(NEIGE, 0.75 * givre), false)

	# une foliole : la même, en plus court (trois points)
	func foliole(a: Vector2, b: Vector2, w: float, c: Color) -> void:
		w *= fin
		if duvet:
			c = c.lerp(ARGENT, 0.5)
		var ligne := PackedVector2Array([a, a.lerp(b, 0.5), b])
		p.tracer(ligne, w, ENCRE, false, PackedFloat32Array([w * 0.5 + 0.9, w + 0.95, 1.1]))
		p.tracer(ligne, w, c, false, PackedFloat32Array([w * 0.5, w, 0.25]))

	# une pastille de couleur sur son encre (une fleur, une baie, un bouton)
	func grain(c: Vector2, rx: float, ry: float, col: Color, mode := 0.0) -> void:
		p.eventail(c, rx + 0.62, ry + 0.62, ENCRE, ENCRE, 8)
		p.eventail(c, rx, ry, col, col, 8, mode)

	func teinte_fleur(fl: float) -> Color:
		return fleur.lerp(clair, (1.0 - fl) * 0.7)

	func pousser(forme: String, fl: float) -> void:
		match forme:
			"ombelle":
				ombelle(fl)
			"clochette":
				clochette(fl)
			"epi":
				epi(fl)
			"rosette":
				rosette(fl)
			"morelle":
				morelle(fl)
			"chardon":
				chardon(fl)
			"crosse":
				crosse(fl)
			_:
				ombelle(fl)

	# --- l'ombelle : une tige creuse, des feuilles découpées, une ou deux ombelles plates sur leurs rayons ---

	func ombelle(fl: float) -> void:
		var h := 17.5 + 3.0 * r.randf()
		var tete := pt(0.5, h)
		var n1 := pt(0.7, h * 0.34)
		var n2 := pt(-0.2, h * 0.66)
		decoupee(pt(0.0, 0.6), Vector2(-0.94 * sens, -0.36), 7.6 * l, clair)
		decoupee(pt(0.2, 0.4), Vector2(0.9 * sens, -0.46), 6.6 * l, vert)
		decoupee(n1, Vector2(0.84 * sens, -0.54), 5.4 * l, clair)
		# la seconde ombelle, plus petite, sur son rameau
		if r.randf() < 0.75:
			var t2 := pt(-4.8, h * 0.84)
			brin(PackedVector2Array([n2, n2.lerp(t2, 0.6) + Vector2(-0.5 * sens, 0.5), t2 + Vector2(0.0, 2.2)]), 0.8, tige)
			ombrelle(t2, 3.4 * l, fl)
		else:
			foliole(n2, n2 + Vector2(-3.6 * sens * l, -2.4), 1.7, vert)
		# la tige : pâle, creuse (un reflet le long), ses deux nœuds
		brin(PackedVector2Array([pt(0.0, 0.0), n1, n2, tete + Vector2(0.0, 2.8)]), 1.5, tige, PackedFloat32Array([1.9, 1.6, 1.4, 1.1]))
		p.tracer(PackedVector2Array([pt(-0.25, 1.5), n1 + Vector2(-0.3, 0.0), n2 + Vector2(-0.25, 0.0)]), 0.5, Color(P.PAPIER, 0.42), false)
		for nd in [n1, n2]:
			var o: Vector2 = nd
			p.tracer(PackedVector2Array([o + Vector2(-1.25, 0.25), o + Vector2(1.25, -0.25)]), 0.8, ENCRE, false)
		ombrelle(tete, 5.6 * l, fl)

	# une feuille découpée : son pétiole, deux paires de folioles, une au bout
	func decoupee(a: Vector2, dir: Vector2, long: float, c: Color) -> void:
		dir = dir.normalized()
		var n := dir.orthogonal()
		var mi := a + dir * long * 0.55 + Vector2(0.0, -long * 0.07)
		var bout := a + dir * long + Vector2(0.0, long * 0.1)
		brin(PackedVector2Array([a, mi, bout]), 0.7, tige.lerp(vert, 0.5))
		for k in 2:
			var o := a.lerp(mi, 0.8) if k == 0 else mi.lerp(bout, 0.5)
			var lf := long * (0.42 - 0.1 * k)
			foliole(o, o + (dir * 0.6 + n).normalized() * lf, 1.8, c)
			foliole(o, o + (dir * 0.6 - n).normalized() * lf, 1.8, c)
		foliole(mi.lerp(bout, 0.6), bout + dir * 1.2, 1.9, c)

	# une ombelle : ses rayons en éventail, sa nappe de fleurs (plate dessus, d'un seul cerne)
	func ombrelle(c: Vector2, rx: float, fl: float) -> void:
		var pied := c + Vector2(0.0, rx * 0.5 + 1.2)
		var n := 5 if rx > 4.2 else 3
		for i in n:
			var x := lerpf(-1.0, 1.0, i / float(n - 1))
			p.tracer(PackedVector2Array([pied, c + Vector2(x * rx * 0.86, absf(x) * 0.6)]), 0.7, ENCRE.lerp(tige, 0.45), false)
		if fl <= 0.0:
			return
		var col := teinte_fleur(fl)
		var rr := rx * (0.22 + 0.1 * fl) + 0.4
		p.eventail(c + Vector2(0.0, -0.35 - rr * 0.22), rx + 0.6, rr * 0.82 + 0.62, ENCRE, ENCRE, 10)
		for i in n:
			var x := lerpf(-1.0, 1.0, i / float(n - 1))
			var ci := col.lightened(0.12) if x < -0.2 else (col if x < 0.6 else col.darkened(0.12))
			p.eventail(c + Vector2(x * rx * 0.74, -0.35 - (1.0 - x * x) * rr * 0.5), rr, rr * 0.82, ci, ci, 7)
		cimes.append([c + Vector2(0.0, -rr * 0.9), rx * 0.7])

	# --- la clochette : deux feuilles dressées, une hampe qui ploie, ses clochettes d'un seul côté ---

	func clochette(fl: float) -> void:
		var h := 14.5 + 2.5 * r.randf()
		limbe(pt(-0.6, 0.0), pt(-4.6, h * 0.74), 3.7, vert, -1.3 * sens)
		limbe(pt(0.6, 0.0), pt(2.6, h * 0.5), 3.3, sombre, 1.0 * sens)
		# la hampe monte, puis verse d'un côté
		var ha := PackedVector2Array([pt(0.0, 0.5), pt(0.2, h * 0.55), pt(2.0, h * 0.93), pt(5.6, h * 1.04), pt(9.4, h * 0.95), pt(12.2, h * 0.74)])
		brin(ha, 1.0, tige, PackedFloat32Array([1.4, 1.2, 1.05, 0.9, 0.8, 0.6]))
		if fl <= 0.0:
			return
		var col := teinte_fleur(fl)
		var n := 3 + int(r.randf() < 0.6)
		for i in n:
			# (de la plus ouverte, près de la tige, au bouton du bout)
			var u := lerpf(0.46, 1.0, i / float(n - 1))
			var a := _sur(ha, u)
			var s := lerpf(2.3, 1.5, i / float(n - 1)) * (0.6 + 0.4 * fl)
			var o := a + Vector2(0.0, 1.2 + 0.9 * (i % 2))
			p.tracer(PackedVector2Array([a, o]), 0.7, ENCRE, false)
			cloche(o, s, col.darkened(0.06 * (i % 2)))
		cimes.append([ha[3], 3.0])

	# un point le long d'une ligne (u de 0 à 1, par les sommets)
	func _sur(ligne: PackedVector2Array, u: float) -> Vector2:
		var x := clampf(u, 0.0, 1.0) * (ligne.size() - 1)
		var i := mini(int(x), ligne.size() - 2)
		return ligne[i].lerp(ligne[i + 1], x - i)

	# une clochette qui pend : étroite à l'attache, évasée, la lèvre festonnée
	func cloche(o: Vector2, s: float, col: Color) -> void:
		p.eventail(o + Vector2(0.0, 0.64 * s), s + 0.8, 0.8 * s + 0.75, ENCRE, ENCRE, 9)
		p.aplat(PackedVector2Array([o + Vector2(-0.3 * s, 0.0), o + Vector2(0.3 * s, 0.0), o + Vector2(0.78 * s, 0.6 * s), o + Vector2(1.0 * s, 1.25 * s),
			o + Vector2(0.42 * s, 1.0 * s), o + Vector2(0.0, 1.32 * s), o + Vector2(-0.42 * s, 1.0 * s), o + Vector2(-1.0 * s, 1.25 * s), o + Vector2(-0.78 * s, 0.6 * s)]), col)
		p.tracer(PackedVector2Array([o + Vector2(-0.3 * s, 0.3 * s), o + Vector2(-0.6 * s, 0.95 * s)]), 0.55, Color(P.PAPIER, 0.6), false)

	# --- l'épi : une rosette basse, une hampe, un épi serré de petites fleurs ---

	func epi(fl: float) -> void:
		var h := 16.0 + 4.0 * r.randf()
		for i in 5:
			var u := i / 4.0
			var x := lerpf(-7.4, 7.4, u) + r.randf_range(-0.8, 0.8)
			limbe(pt(0.0, 0.4), pt(x, 1.4 + 3.6 * (1.0 - absf(u - 0.5) * 2.0) + r.randf()), 2.5, clair if i % 2 == 0 else vert, -signf(x) * 0.9 * sens)
		brin(PackedVector2Array([pt(0.0, 0.5), pt(0.35, h * 0.24), pt(0.2, h * 0.46)]), 1.1, tige)
		var e0 := pt(0.2, h * 0.4)
		var e1 := pt(0.5, h)
		var massif := lieu == "marais"
		var ligne := PackedVector2Array([e0, e0.lerp(e1, 0.3), e0.lerp(e1, 0.68), e1])
		if fl <= 0.0:
			# (pas encore d'épi : un fuseau vert)
			brin(ligne, 1.4, clair, PackedFloat32Array([1.2, 1.9, 1.5, 0.5]))
			return
		var col := teinte_fleur(fl)
		var larg := PackedFloat32Array([1.9, 3.5, 2.8, 0.6])
		if massif:
			# (la massette du marais : un manchon, sa pointe nue au-dessus)
			larg = PackedFloat32Array([3.0, 3.9, 3.9, 2.8])
			ligne = PackedVector2Array([e0, e0.lerp(e1, 0.28), e0.lerp(e1, 0.56), e0.lerp(e1, 0.8)])
			brin(PackedVector2Array([ligne[3], e1 + Vector2(0.0, -1.0)]), 0.8, tige)
		brin(ligne, 3.0, col, larg)
		# les fleurs, serrées : des points clairs d'un côté, sombres de l'autre
		var d := (ligne[3] - ligne[0]).normalized()
		var n := d.orthogonal()
		for i in 7:
			var u := 0.1 + i * 0.125
			var o := _sur(ligne, u) + n * (0.75 if i % 2 == 0 else -0.75) * (1.0 - u * (0.0 if massif else 0.6))
			if i % 2 == 0:
				p.eventail(o, 0.62, 0.55, col.lightened(0.3), col.lightened(0.3), 5)
			else:
				p.eventail(o, 0.6, 0.5, col.darkened(0.28), col.darkened(0.28), 5)
		cimes.append([e1, 1.2])

	# --- la rosette : de larges feuilles à plat, en étoile, une hampe courte au cœur ---

	func rosette(fl: float) -> void:
		var n := 6 + r.randi() % 3
		var rl := 9.6 + 2.2 * r.randf()
		var c0 := pt(0.0, 1.4)
		var a0 := r.randf() * TAU
		# (les feuilles de l'espèce prennent de sa couleur : la feuille-de-lune est pâle, celle des noyés glauque)
		var f1 := vert.lerp(fleur, 0.42).lightened(0.06)
		var f2 := sombre.lerp(fleur, 0.3)
		var feuilles: Array = []
		for i in n:
			var a := a0 + TAU * i / n + r.randf_range(-0.16, 0.16)
			feuilles.append([sin(a), a, r.randf_range(0.82, 1.08)])
		# du fond vers le devant
		feuilles.sort_custom(func(x, y): return x[0] < y[0])
		for i in n:
			var f: Array = feuilles[i]
			var a := float(f[1])
			var lg := rl * float(f[2])
			var bout := c0 + Vector2(cos(a) * lg * l, sin(a) * lg * 0.42 * e - (0.9 if sin(a) < 0.0 else 0.0))
			limbe(c0, bout, 4.4, f1 if i % 2 == 0 else f2, 0.0, true)
			# la nervure, pâle
			p.tracer(PackedVector2Array([c0.lerp(bout, 0.12), c0.lerp(bout, 0.84)]), 0.55, Color(clair.lerp(P.PAPIER, 0.35), 0.75), false)
		# le cœur : une hampe courte, son bouquet
		var haut := c0 + Vector2(0.6 * sens, -5.6 * e)
		brin(PackedVector2Array([c0, haut]), 1.0, tige)
		if fl > 0.0:
			var col := teinte_fleur(fl).lightened(0.12)
			grain(haut + Vector2(-1.3, 0.5), 1.1, 1.0, col.darkened(0.1))
			grain(haut + Vector2(1.3, 0.4), 1.1, 1.0, col.darkened(0.04))
			grain(haut + Vector2(0.0, -0.7), 1.35, 1.2, col)
		cimes.append([c0 + Vector2(0.0, -1.2), 4.5])

	# --- la morelle : un petit buisson herbacé, des feuilles sombres, des baies luisantes par deux ou trois ---

	func morelle(fl: float) -> void:
		var h := 12.5 + 2.5 * r.randf()
		var bois := tige.lerp(fleur, 0.3).darkened(0.12) if tige != ROUGE_SANG else tige
		var f1 := sombre.lerp(P.FEUILLE_SOMBRE, 0.3)
		var f2 := vert.darkened(0.12)
		var tiges := [
			PackedVector2Array([pt(0.0, 0.0), pt(0.5, h * 0.45), pt(-1.4, h * 0.8), pt(-2.4, h)]),
			PackedVector2Array([pt(0.4, h * 0.38), pt(4.4, h * 0.6), pt(6.6, h * 0.92)]),
			PackedVector2Array([pt(0.2, h * 0.2), pt(-4.6, h * 0.4), pt(-7.0, h * 0.62)]),
		]
		for t in tiges:
			var ligne: PackedVector2Array = t
			brin(ligne, 1.1, bois)
		# les feuilles : ovales, pointues, tournées vers dehors
		var poses := [[tiges[2][2], Vector2(-0.9, -0.3), 5.6], [tiges[2][1], Vector2(-0.5, -0.9), 4.6], [tiges[0][3], Vector2(-0.3, -1.0), 5.2],
			[tiges[0][2], Vector2(-1.0, -0.2), 4.8], [tiges[1][2], Vector2(0.6, -0.8), 5.4], [tiges[1][1], Vector2(0.95, 0.15), 5.2],
			[tiges[0][1], Vector2(0.9, -0.5), 4.4], [tiges[1][2], Vector2(1.0, 0.1), 4.4], [tiges[0][1], Vector2(-0.95, -0.25), 4.6], [tiges[0][3], Vector2(0.8, -0.6), 4.2]]
		for i in poses.size():
			var po: Array = poses[i]
			var a: Vector2 = po[0]
			var d: Vector2 = po[1]
			d = Vector2(d.x * sens, d.y).normalized()
			limbe(a, a + d * float(po[2]) * 1.12 * lerpf(l, e, 0.5), 4.3, f1 if i % 2 == 0 else f2, 0.5 * sens)
		cimes.append([tiges[0][3] + Vector2(0.0, -2.0), 3.6])
		if fl <= 0.0:
			return
		# les baies : en grappes sous les fourches, luisantes
		var col := teinte_fleur(fl)
		if col.v < 0.3:
			# (une baie noire ne se perd pas dans l'encre : un reflet bleu la tient)
			col = col.lerp(P.LUNE, 0.16)
		var rb := 1.6 * (0.6 + 0.4 * fl)
		var grappes := [tiges[1][1] + Vector2(0.4 * sens, 2.4), tiges[0][2] + Vector2(-2.2 * sens, 2.6), tiges[1][2] + Vector2(-2.4 * sens, 1.8)]
		for g in grappes.size():
			var o: Vector2 = grappes[g]
			for k in (3 if g == 0 else 2):
				var b := o + Vector2.from_angle(k * 2.3 + g * 1.1) * rb * 1.05
				p.eventail(b, rb + 0.65, rb + 0.6, ENCRE, ENCRE, 8)
				p.eventail(b, rb, rb * 0.96, col, col, 8, Pinceau.DOME)
				p.eventail(b + Vector2(-0.5, -0.55) * rb * 0.6, rb * 0.34, rb * 0.3, Color(1.0, 0.97, 0.92, 0.95), Color(1.0, 0.97, 0.92, 0.95), 5)

	# --- le chardon : des feuilles en lames piquantes, une tige armée, un capitule en étoile ---

	func chardon(fl: float) -> void:
		var h := 16.5 + 4.0 * r.randf()
		var gris := vert.lerp(P.IVOIRE, 0.18)
		lame(pt(-0.4, 0.3), pt(-8.2, 4.6 + r.randf() * 2.0), 3.0, gris)
		lame(pt(0.4, 0.3), pt(7.8, 3.8 + r.randf() * 2.0), 3.0, gris.darkened(0.12))
		lame(pt(-0.2, 0.5), pt(-4.4, h * 0.5), 2.6, gris.darkened(0.08))
		lame(pt(0.3, 0.5), pt(4.0, h * 0.42), 2.6, gris.lightened(0.06))
		var cou := pt(0.0, h * 0.8)
		brin(PackedVector2Array([pt(0.0, 0.0), pt(0.5, h * 0.45), cou]), 1.6, tige, PackedFloat32Array([2.0, 1.7, 1.4]))
		# la tige armée : une feuille étroite, des épines
		lame(pt(0.4, h * 0.5), pt(4.6, h * 0.72), 1.9, gris)
		for i in 3:
			var o := pt(0.3, h * (0.2 + 0.2 * i))
			var cote := -1.0 if i % 2 == 0 else 1.0
			p.tracer(PackedVector2Array([o, o + Vector2(cote * 2.3 * sens, -1.4)]), 0.8, ENCRE)
		# le capitule : un cœur d'écailles, et son étoile de fleurons
		var c := cou + Vector2(0.0, -2.4)
		var col := teinte_fleur(fl)
		if fl > 0.0:
			for i in 9:
				var a := -PI * lerpf(0.04, 0.96, i / 8.0)
				var lg := (5.9 if i % 2 == 0 else 4.4) * (0.45 + 0.55 * fl)
				var bout := c + Vector2(cos(a) * lg * 1.08, sin(a) * lg - 1.0)
				p.tracer(PackedVector2Array([c + Vector2(0.0, -1.0), bout]), 1.0, ENCRE, false, PackedFloat32Array([2.5, 1.5]))
				p.tracer(PackedVector2Array([c + Vector2(0.0, -1.0), bout]), 1.0, col if i % 2 == 0 else col.lightened(0.16), false, PackedFloat32Array([1.6, 0.6]))
		p.eventail(c, 3.5, 3.4, ENCRE, ENCRE, 9)
		p.eventail(c, 2.8, 2.7, sombre.lerp(P.IVOIRE, 0.22), sombre.lerp(P.IVOIRE, 0.22), 9, Pinceau.DOME)
		for i in 4:
			var x := -1.8 + 1.2 * i
			p.tracer(PackedVector2Array([c + Vector2(x * 0.5, 2.4), c + Vector2(x, -1.6)]), 0.5, Color(ENCRE, 0.6), false)
		cimes.append([c + Vector2(0.0, -4.5), 2.4])

	# une feuille en lame : un fuseau d'encre, ses dents, une épine à chacune
	func lame(a: Vector2, b: Vector2, w: float, c: Color) -> void:
		var d := b - a
		var n := d.orthogonal().normalized()
		w *= fin
		if duvet:
			c = c.lerp(ARGENT, 0.5)
		var profil := [0.3, 1.0, 0.42, 0.92, 0.36, 0.66, 0.0]
		var gauche := PackedVector2Array()
		var droite := PackedVector2Array()
		for i in 7:
			var o := a + d * (i / 6.0)
			var k := float(profil[i]) * w * 0.5
			gauche.append(o + n * (k + 0.25))
			droite.append(o - n * (float(profil[(i + 1) % 7 if i in [2, 3, 4] else i]) * w * 0.5 + 0.25))
		p.tracer(PackedVector2Array([a, a + d * 0.3, a + d * 0.7, b]), w, ENCRE, false, PackedFloat32Array([w * 0.5 + 1.0, w * 0.86 + 1.0, w * 0.7 + 1.0, 1.2]))
		p.bande(gauche, droite, c)
		for i in [1, 3, 5]:
			var o: Vector2 = gauche[i]
			var o2: Vector2 = droite[i - 1 if i > 1 else i]
			p.tracer(PackedVector2Array([o - n * 0.4, o + n * 1.4 + d.normalized() * 0.7]), 0.75, ENCRE)
			p.tracer(PackedVector2Array([o2 + n * 0.4, o2 - n * 1.4 + d.normalized() * 0.7]), 0.75, ENCRE)
		p.tracer(PackedVector2Array([a, a + d * 0.9]), 0.5, Color(clair.lerp(P.PAPIER, 0.4), 0.7), false)
		if givre > 0.0:
			p.tracer(PackedVector2Array([a + d * 0.6, b]), 0.9, Color(NEIGE, 0.8 * givre), false)

	# --- la crosse : des frondes enroulées, qui se déplient ---

	func crosse(fl: float) -> void:
		var h := 14.5 + 3.0 * r.randf()
		var stipe := tige.lerp(P.TERRE, 0.3) if tige != ROUGE_SANG else tige
		fronde(pt(-0.6, 0.0), pt(-7.4, h * 0.82), -1.0, 0.85, stipe, fl)
		fronde(pt(1.0, 0.0), pt(5.4, h * 0.5), 1.0, 0.25, stipe, fl)
		fronde(pt(0.2, 0.0), pt(1.6, h), 1.0, 0.5, stipe, fl)
		if r.randf() < 0.6:
			fronde(pt(-0.2, 0.0), pt(-2.6, h * 0.36), -1.0, 0.0, stipe, fl)
		cimes.append([pt(1.6, h * 1.06), 2.4])

	# une fronde : du pied à sa tête, qui s'enroule ; deroule : ce qu'elle a déjà déplié (ses pennes le long du stipe)
	func fronde(a: Vector2, b: Vector2, cote: float, deroule: float, stipe: Color, fl: float) -> void:
		cote *= sens
		var d := b - a
		var n := d.orthogonal().normalized() * cote
		if n.y > 0.0:
			n = -n
		var mi := a + d * 0.5 + n * d.length() * 0.14
		var ligne := PackedVector2Array([a, a.lerp(mi, 0.6) + n * 0.4, mi, mi.lerp(b, 0.6) + n * 0.3, b])
		var jeune := fleur.lerp(clair, (1.0 - maxf(fl, 0.35)) * 0.6)
		# ses pennes : par paires, plus courtes vers la crosse (la prêle du marais : des verticilles droits, à ses nœuds)
		var prele := lieu == "marais"
		var np := int(round(deroule * 6.0))
		for i in np:
			var u := 0.2 + 0.68 * i / maxf(np - 1.0, 1.0)
			var o := _sur(ligne, u)
			var lg := (4.4 - 2.6 * u) * lerpf(l, e, 0.5)
			var dd := d.normalized()
			if prele:
				p.tracer(PackedVector2Array([o - dd.orthogonal() * lg, o + dd * 0.8, o + dd.orthogonal() * lg]), 0.8, ENCRE.lerp(vert, 0.35), false)
				p.tracer(PackedVector2Array([o - dd.orthogonal() * 1.0, o + dd.orthogonal() * 1.0]), 1.0, ENCRE, false)
			else:
				foliole(o, o + (dd.orthogonal() + dd * 0.5).normalized() * lg, 1.7, vert if i % 2 == 0 else clair)
				foliole(o, o + (-dd.orthogonal() + dd * 0.5).normalized() * lg, 1.7, clair if i % 2 == 0 else vert)
		brin(ligne, 1.2, stipe, PackedFloat32Array([1.5, 1.4, 1.25, 1.1, 1.0]))
		# la crosse : une spirale, de plus en plus serrée
		var rayon := (2.7 - 1.0 * deroule) * lerpf(l, e, 0.5)
		var centre := b + Vector2(cote * rayon * 0.9, 0.3)
		var a0 := (b - centre).angle()
		var spire := PackedVector2Array()
		var larg := PackedFloat32Array()
		for k in 9:
			var u := k / 8.0
			spire.append(centre + Vector2.from_angle(a0 + cote * u * 4.9) * rayon * (1.0 - 0.72 * u))
			larg.append(lerpf(1.5, 0.8, u))
		spire[0] = b
		brin(spire, 1.3, jeune, larg)
		if givre > 0.0:
			p.eventail(centre + Vector2(0.0, -rayon * 0.6), rayon * 0.7, 0.6, Color(NEIGE, 0.85 * givre), Color(NEIGE, 0.85 * givre), 6)

	# --- cueillie : la tige coupée, pâle à la coupe, quelques feuilles au pied ; la goutte de lait ; puis la pousse qui revient ---

	func coupee(forme: String, lait: bool, repart: bool) -> void:
		var bas := vert.darkened(0.1)
		var n := 3 if forme in ["rosette", "epi", "chardon"] else 2
		for i in n:
			var cote := -1.0 if i % 2 == 0 else 1.0
			var bout := pt(cote * (6.4 + 1.8 * r.randf()), 2.4 + 2.2 * r.randf())
			if forme == "chardon":
				lame(pt(0.0, 0.3), bout, 2.6, bas.lerp(P.IVOIRE, 0.18))
			else:
				limbe(pt(0.0, 0.3), bout, 3.8 if forme == "rosette" else 3.0, bas if i % 2 == 0 else vert, -cote * 0.7 * sens, forme == "rosette")
		var chicots := 3 if forme == "crosse" else (2 if forme == "morelle" else 1)
		for i in chicots:
			var x := (i - (chicots - 1) * 0.5) * 2.2
			var haut := pt(x * 1.3 + 0.3, 5.0 - 0.8 * absf(x))
			brin(PackedVector2Array([pt(x * 0.5, 0.0), haut]), 1.7, tige, PackedFloat32Array([1.9, 1.6]))
			# (la coupe : nette, de biais, pâle)
			grain(haut + Vector2(0.0, -0.2), 1.0, 0.55, P.IVOIRE.lightened(0.2))
			if lait and i == 0:
				p.tracer(PackedVector2Array([haut + Vector2(0.9, 0.0), haut + Vector2(1.1, 2.2)]), 0.9, LAIT, false)
				grain(haut + Vector2(1.1, 2.4), 0.75, 0.9, LAIT)
				grain(haut + Vector2(0.1, -0.6), 1.0, 0.8, LAIT)
		if repart:
			# la pousse qui revient : deux feuilles tendres, serrées
			var o := pt(-2.2, 0.0)
			var tendre := clair.lightened(0.2)
			brin(PackedVector2Array([o, o + Vector2(-0.3, -4.4 * e)]), 0.9, tendre)
			foliole(o + Vector2(-0.3, -3.8 * e), o + Vector2(-3.0, -7.4 * e), 2.2, tendre)
			foliole(o + Vector2(-0.3, -3.8 * e), o + Vector2(2.0, -7.0 * e), 2.2, tendre.darkened(0.08))

	# ce que le temps y pose : la neige sur ses têtes, une goutte qui luit
	func finir() -> void:
		if neige > 0.05:
			for cm in cimes:
				var c: Vector2 = cm[0]
				var rx := float(cm[1]) * (0.6 + 0.5 * neige)
				p.eventail(c + Vector2(0.0, 0.2), rx + 0.4, 0.9 + 0.9 * neige, NEIGE.darkened(0.14), NEIGE.darkened(0.14), 8)
				p.eventail(c + Vector2(-0.2, -0.2), rx, 0.6 + 0.8 * neige, NEIGE, NEIGE, 8, Pinceau.DOME)
		elif luit > 0.5 and not cimes.is_empty():
			var c: Vector2 = cimes[0][0]
			p.eventail(c + Vector2(1.6 * sens, 1.4), 0.7, 0.8, Color(P.ECHO, 0.85), Color(P.ECHO, 0.85), 6)


# --- un plant d'un carré de jardin (scripts/campement.gd, _carre_vif) ---

# la graine d'une herbe, sur la terre du carré : claire, un peu de la couleur de l'espèce
static func graine(id: String) -> Color:
	return P.IVOIRE.lerp(Botanique.couleur(id), 0.3)


# id : l'espèce semée ; q : son pied ; s : son stade (de 0,25, la pousse, à 3, mûre) ; k : sa taille ; bal : ce dont le vent
# la couche ; g : son hasard (de 0 à 1) ; sec : sa soif ; givre ; mobile : la version légère. Du coût des trois autres cultures.
static func plant(p, id: String, q: Vector2, s: float, k: float, bal: float, g: float, sec: float, givre: bool, mobile: bool) -> void:
	var forme := Botanique.forme_de(id)
	var vert: Color = port(Botanique.lieu_de(id))["vert"]
	vert = vert.lightened(0.1).lerp(PAILLE, 0.42 * sec)
	if givre:
		vert = vert.lerp(Color("b9c0cf").lightened(0.25), 0.45)
	var fleur := Botanique.couleur(id)
	var doux := not mobile
	var vide := PackedFloat32Array()
	if s < 1.0:
		# la pousse : deux feuilles tendres (une crosse : déjà enroulée)
		var u0 := (s - 0.25) / 0.75
		var h := (1.0 + 3.2 * u0) * k
		var haut := q + Vector2(bal * h, -h)
		p.tracer(PackedVector2Array([q, haut]), 0.9, vert.lightened(0.2), false, vide, doux)
		if forme == "crosse":
			p.eventail(haut + Vector2(0.6, 0.0), 0.9 + 0.4 * u0, 0.9 + 0.4 * u0, fleur.lerp(vert, 0.4), fleur.lerp(vert, 0.4), 7)
			return
		var f := 0.7 + 1.0 * u0
		p.eventail(haut + Vector2(-f, -0.2), f, f * 0.66, vert.lightened(0.28), vert.lightened(0.28), 7)
		p.eventail(haut + Vector2(f, -0.4), f, f * 0.66, vert.lightened(0.18), vert.lightened(0.18), 7)
		return
	var u := clampf(s - 1.0, 0.0, 1.0)
	var fl := smoothstep(1.7, 2.5, s)
	var mur := smoothstep(2.2, 3.0, s)
	var col := fleur.lerp(vert.lightened(0.3), 1.0 - (0.35 + 0.65 * mur))
	match forme:
		"ombelle":
			var h := (3.0 + 8.4 * u) * k
			var haut := q + Vector2(bal * h, -h)
			for j in 2:
				var c := 1.0 if j == 0 else -1.0
				p.tracer(PackedVector2Array([q, q + Vector2(c * (2.2 + 1.6 * u) * k + bal, -1.6 - 1.4 * u)]), 1.6, vert.lightened(0.06 * j), true, vide, doux)
			p.tracer(PackedVector2Array([q, q.lerp(haut, 0.5) + Vector2(-bal * h * 0.12, 0.0), haut]), 0.9, vert.lerp(P.IVOIRE, 0.3), false, vide, doux)
			if fl > 0.05:
				var rx := (1.3 + 2.0 * fl) * k
				p.eventail(haut + Vector2(0.0, 0.1), rx + 0.7, rx * 0.3 + 0.9, ENCRE, ENCRE, 9)
				p.eventail(haut + Vector2(-rx * 0.4, 0.0), rx * 0.6, rx * 0.3 + 0.2, col.darkened(0.08), col.darkened(0.08), 7)
				p.eventail(haut + Vector2(rx * 0.4, -0.1), rx * 0.6, rx * 0.3 + 0.2, col, col, 7)
		"clochette":
			var h := (2.6 + 6.4 * u) * k
			p.tracer(PackedVector2Array([q, q + Vector2(-1.6 * k + bal * h * 0.5, -h * 0.5), q + Vector2(-2.2 * k + bal * h, -h * 0.86)]), 2.3, vert, true, vide, doux)
			var crete := q + Vector2(1.6 * k + bal * h, -h)
			var bout := q + Vector2(4.6 * k + bal * h * 1.3, -h * 0.66)
			p.tracer(PackedVector2Array([q, q + Vector2(0.2 + bal * h * 0.5, -h * 0.6), crete, bout]), 0.85, vert.lerp(P.IVOIRE, 0.25), false, vide, doux)
			if fl > 0.05:
				for j in (2 if mobile else 3):
					var o := crete.lerp(bout, 0.2 + 0.4 * j) + Vector2(0.0, 1.3)
					var rr := (1.25 - 0.2 * j) * (0.5 + 0.5 * fl)
					p.eventail(o, rr + 0.55, rr + 0.5, ENCRE, ENCRE, 7)
					p.eventail(o, rr, rr * 0.92, col, col, 7)
		"epi":
			var h := (3.0 + 8.6 * u) * k
			var haut := q + Vector2(bal * h, -h)
			for j in 3:
				var c := j - 1.0
				p.tracer(PackedVector2Array([q, q + Vector2(c * (2.8 + 1.4 * u) * k + bal, -1.2 - 1.2 * u - absf(c) * 0.2)]), 1.6, vert.lightened(0.05 * j), true, vide, doux)
			var mi := q.lerp(haut, 0.45)
			p.tracer(PackedVector2Array([q, mi]), 0.9, vert.lerp(P.IVOIRE, 0.25), false, vide, doux)
			var e1 := q.lerp(haut, 0.72)
			if not mobile:
				p.tracer(PackedVector2Array([mi, e1, haut]), 1.0, ENCRE, false, PackedFloat32Array([1.9, 2.9 + 0.5 * fl, 1.2]))
			p.tracer(PackedVector2Array([mi, e1, haut]), 1.0, col if fl > 0.05 else vert.lightened(0.15), false, PackedFloat32Array([1.0, 1.9 + 0.5 * fl, 0.4]), doux)
		"rosette":
			var lf := (2.1 + 1.9 * u) * k
			var f1 := vert.lerp(fleur, 0.34)
			for j in 5:
				var a := -PI * 0.5 + (j - 2.0) * 0.72 + (g - 0.5) * 0.3
				var bout := q + Vector2(cos(a) * lf * 1.25 + bal * 1.2, sin(a) * lf * 0.5 - 0.2)
				p.tracer(PackedVector2Array([q, q.lerp(bout, 0.6) + Vector2(0.0, -0.6), bout]), 2.1, f1.lightened(0.1 * (j % 2)), true, vide, doux)
			if fl > 0.05:
				var haut := q + Vector2(bal * 2.0, -(1.6 + 2.4 * fl) * k)
				p.tracer(PackedVector2Array([q, haut]), 0.8, vert.lerp(P.IVOIRE, 0.25), false, vide, doux)
				p.eventail(haut, 1.0 + 0.5 * fl, 0.95 + 0.4 * fl, col.lightened(0.1), col.lightened(0.1), 7)
		"morelle":
			var rx := (2.2 + 1.9 * u) * k
			var ry := (1.9 + 1.7 * u) * k
			var c := q + Vector2(bal * ry * 1.4, -ry - 0.3)
			var sombre := vert.darkened(0.22)
			if not mobile:
				p.eventail(c + Vector2(0.0, -0.1 * ry), rx * 1.18 + 0.7, ry * 1.05 + 0.7, ENCRE, ENCRE, 10)
			p.eventail(c + Vector2(-0.5 * rx, 0.28 * ry), rx * 0.68, ry * 0.7, sombre, sombre, 8, Pinceau.FEUILLAGE)
			p.eventail(c + Vector2(0.5 * rx, 0.22 * ry), rx * 0.68, ry * 0.7, sombre.lightened(0.06), sombre.lightened(0.06), 8, Pinceau.FEUILLAGE)
			p.eventail(c + Vector2(bal * ry * 0.8, -0.42 * ry), rx * 0.68, ry * 0.7, sombre.lightened(0.1), sombre.lightened(0.1), 8, Pinceau.FEUILLAGE)
			if fl > 0.05:
				var baie := col.lerp(P.LUNE, 0.16) if col.v < 0.3 else col
				for j in (3 if mobile else 4):
					var a := g * TAU + j * 1.9
					var o := c + Vector2(cos(a) * rx * 0.6, sin(a) * ry * 0.36 + ry * 0.12)
					var rb := 0.6 + 0.45 * fl
					p.eventail(o, rb, rb, baie, baie, 7)
					p.eventail(o + Vector2(-0.3, -0.3), rb * 0.36, rb * 0.34, Color(P.PAPIER, 0.9), Color(P.PAPIER, 0.9), 5)
		"chardon":
			var h := (3.0 + 8.0 * u) * k
			var haut := q + Vector2(bal * h, -h)
			var gris := vert.lerp(P.IVOIRE, 0.18)
			for j in 4:
				var c := (j - 1.5) / 1.5
				p.tracer(PackedVector2Array([q, q + Vector2(c * (3.6 + 1.8 * u) * k + bal, -1.0 - (2.4 - absf(c) * 1.4) * (1.0 + u))]), 1.3, gris.darkened(0.06 * (j % 2)), false, PackedFloat32Array([1.5, 0.3]), doux)
			p.tracer(PackedVector2Array([q, haut]), 1.0, gris.lightened(0.1), false, vide, doux)
			if fl > 0.05:
				for j in (3 if mobile else 5):
					var a := -PI * (0.12 + 0.76 * j / (2.0 if mobile else 4.0))
					p.tracer(PackedVector2Array([haut, haut + Vector2(cos(a) * 2.9, sin(a) * 2.9) * (0.5 + 0.5 * fl) * k]), 1.0, col, false, PackedFloat32Array([1.2, 0.4]), doux)
			p.eventail(haut + Vector2(0.0, 0.3), 1.3 * k, 1.25 * k, ENCRE.lerp(gris, 0.45), ENCRE.lerp(gris, 0.45), 7)
		_:
			# la crosse : deux frondes, leur tête enroulée
			for j in 2:
				var c := 1.0 if j == 0 else -1.0
				var h := (2.8 + (7.4 - 2.6 * j) * u) * k
				var haut := q + Vector2(c * (1.2 + 1.6 * u) * k + bal * h, -h)
				var mi := q.lerp(haut, 0.55) + Vector2(c * 0.9 * k, 0.0)
				p.tracer(PackedVector2Array([q, mi, haut]), 1.0, vert.lerp(P.TERRE, 0.25), false, vide, doux)
				if u > 0.3 and not mobile:
					var o := q.lerp(mi, 0.75)
					p.tracer(PackedVector2Array([o + Vector2(-2.2 * k, -0.4), o, o + Vector2(2.2 * k, -0.9)]), 1.2, vert, true, vide, doux)
				var rr := (1.1 + 0.5 * u) * k
				var tete := haut + Vector2(-c * rr * 0.7, 0.2)
				p.eventail(tete, rr + 0.55, rr + 0.55, ENCRE, ENCRE, 8)
				p.eventail(tete, rr, rr, fleur.lerp(vert.lightened(0.2), 0.3), fleur.lerp(vert.lightened(0.2), 0.3), 8)
				p.eventail(tete + Vector2(c * 0.2, 0.1), rr * 0.4, rr * 0.4, ENCRE, ENCRE, 6)
	if givre:
		p.eventail(q + Vector2(bal * 3.0, -3.0 * k), 1.6, 0.6, Color(NEIGE, 0.7), Color(NEIGE, 0.7), 7)
