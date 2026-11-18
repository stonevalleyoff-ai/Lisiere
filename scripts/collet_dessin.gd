extends RefCounted
# Lisière — le grand collet, dessiné (scripts/collet_dessin.gd)
# Le collet de filin où se prend la Noire (scripts/noire_collet.gd), posé dans le lieu : c'est une chose du camp comme les
# autres (scripts/campement.gd, genre « collet »), dont le dessin est ici, à part. Son milieu est celui du nœud ; son état :
#   « amorce » (vrai : la viande est au milieu du nœud), « odeur » (vrai : il sent la main ; cela ne se voit pas), « phase » :
#     ""        tendu : un grand nœud coulant de filin blond couché en rond, ouvert sur deux petites fourches, son brin qui
#               court au ras du sol jusqu'à deux pieux croisés, enfoncés de biais, liés de filin ; ses pierres de lest ;
#     « serre » elle y est prise : le nœud n'est plus au sol (il est à sa patte), la terre est labourée, les fourches
#               couchées ; le filin se tend des pieux à sa patte (droit au bout de son élan, mou quand elle se ramasse), il
#               vibre à chaque à-coup, les pieux penchent vers elle et jouent dans leur trou, la terre saute ;
#     « rompu » les pieux arrachés, couchés du côté où elle est partie (l'un cassé), leurs trous, les pierres roulées, un bout
#               de filin effiloché resté à la liure ; ses griffes dans la terre ;
#   « vers » : le côté où elle tire, où elle est partie ([x, y]).
# Et, du même trait, la couche de la Noire (genre « couche »), qu'on trouve vide à sa tanière quand elle est partie : un creux
# d'herbe couchée, long comme elle ; du poil noir, des os rongés, et les nœuds de filin qu'elle a ramenés à la patte et
# tranchés d'un coup de dent (« noeuds » : combien ; « fouillee » : la veilleuse les a pris, l'herbe se redresse).
# Le nœud et ce qui est couché se trient par le fond (on marche dessus) ; les pieux, debout, par leur pied.
# c : la chose (scripts/campement.gd), dont on prend les gestes (c._perche, c._caillou, c._corde…) ; p : son pinceau.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const R := preload("res://scripts/regles.gd")
const PIEU := Vector2(40.0, -5.0)            # le pied des pieux, depuis le milieu du nœud (celui de scripts/noire_collet.gd)
const LIURE := Vector2(40.0, -15.0)          # où le filin tient aux pieux
const OEIL := -0.42                          # où est l'œil du nœud, sur son tour (un angle)
const RX := 25.0
const RY := 11.5
const TORON := Color("8c7546")               # les torons du filin, plus sombres (ceux de scripts/harnais.gd)
const CHAIR := Color("6e2620")               # la viande crue : le sang, tiré vers la terre


# --- ce que la chose demande (scripts/campement.gd) ---

# ce dont son fond dépend
static func cle(c) -> String:
	if c.genre == "couche":
		return "-%d-%s" % [int(c.etat.get("noeuds", 0)), bool(c.etat.get("fouillee", false))]
	var v: Array = c.etat.get("vers", [])
	return "-%s-%s-%s" % [str(c.etat.get("phase", "")), bool(c.etat.get("amorce", false)), str(v) if str(c.etat.get("phase", "")) == "rompu" else ""]


# remue-t-il ? (tenue : le filin, les pieux, à chaque image)
static func remue(c) -> bool:
	return c.genre == "collet" and str(c.etat.get("phase", "")) == "serre"


# où est sa patte prise, depuis le milieu du nœud : celle de la Noire si ce collet la tient ; sinon (la vitrine, une image
# seule) au bout du filin, du côté de « vers »
static func _patte(c) -> Vector2:
	var N = c.jeu.noire if c.jeu != null else null
	if N != null and N.collet != null:
		var q: Vector2 = N.collet.patte(c)
		if q != Vector2.INF:
			return q
	return PIEU + _vers(c) * (R.NOIRE_COLLET_LONGE + 0.15 * R.NOIRE_LARGEUR)


static func _vers(c) -> Vector2:
	var v: Array = c.etat.get("vers", [])
	if v.size() >= 2 and Vector2(float(v[0]), float(v[1])).length() > 0.1:
		return Vector2(float(v[0]), float(v[1])).normalized()
	return Vector2.LEFT


# depuis le dernier à-coup du filin (INF : aucun)
static func _a_coup(c) -> float:
	var N = c.jeu.noire if c.jeu != null else null
	if N != null and N.collet != null and N.collet.vise == c:
		return float(N.collet.depuis_a_coup)
	# (une image seule : un à-coup toutes les deux secondes, pour le voir)
	return fposmod(c._tr, 2.2)


# le filin : son trait d'encre, sa fibre blonde, ses torons en biais
static func _filin(c, p, ligne: PackedVector2Array, w: float, fibre: Color, torons := true) -> void:
	p.tracer(ligne, w + 1.1, c.ENCRE, false)
	p.tracer(ligne, w, fibre, false)
	if not torons or c._mobile:
		return
	var reste := 2.0
	for i in ligne.size() - 1:
		var a: Vector2 = ligne[i]
		var b: Vector2 = ligne[i + 1]
		var l := a.distance_to(b)
		if l < 0.01:
			continue
		var t := (b - a) / l
		while reste < l:
			var q := a + t * reste
			p.tracer(PackedVector2Array([q - t.orthogonal() * w * 0.42 - t * 0.5, q + t.orthogonal() * w * 0.42 + t * 0.5]), 0.6, Color(TORON, 0.85), false)
			reste += 3.6
		reste -= l


# un point du tour du nœud (a : l'angle), soulevé là où une fourche le porte
static func _tour(a: float, r: RandomNumberGenerator, leve := true) -> Vector2:
	var q := Vector2(cos(a) * RX, sin(a) * RY) * (1.0 + r.randf_range(-0.035, 0.035))
	if leve:
		# (deux fourches : à gauche, et devant à droite ; le nœud y monte de trois pixels)
		q.y -= 3.2 * exp(-pow(angle_difference(a, PI * 0.97) / 0.5, 2.0)) + 3.0 * exp(-pow(angle_difference(a, 1.15) / 0.5, 2.0))
	return q


# --- ce qui est couché : la terre, le nœud, l'appât ; rompu, tout ---

static func sol(c, p) -> void:
	if c.genre == "couche":
		_couche(c, p)
		return
	var r: RandomNumberGenerator = c._hasard(71)
	var phase := str(c.etat.get("phase", ""))
	var mouille: float = c._mouille_cran()
	var neige: float = c._neige_cran()
	var fibre: Color = c.FILIN.darkened(0.08 + 0.16 * mouille)
	var pierre: Color = c._pierre_du_lieu().darkened(0.04 + 0.14 * mouille)
	var terre := P.TERRE.darkened(0.22 + 0.1 * mouille)
	if phase == "":
		# la terre qu'elle a dégagée, foulée ; l'ombre du nœud
		p.eventail(Vector2(3.0, 0.5), 38.0, 16.5, Color(terre, 0.42), Color(terre, 0.0), 18)
		# les pierres du fond, qui tiennent l'arrière du nœud au sol
		for q in [[Vector2(-13.0, -10.6), 4.4], [Vector2(7.0, -11.6), 3.8]]:
			var o: Vector2 = q[0]
			var rr: float = q[1]
			c._ombre(p, o + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.34)
			c._caillou(p, o + Vector2(0.0, -rr * 0.3), rr, rr * 0.72, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.18)), r)
			if neige > 0.25:
				p.disque(o + Vector2(-0.3, -rr * 0.85), rr * 0.7, rr * 0.3, c.NEIGE, Pinceau.DOME)
		# le nœud : son tour, de l'œil à l'œil
		var tour := PackedVector2Array()
		var n := 30
		for i in n + 1:
			tour.append(_tour(OEIL + TAU * float(i) / n, r))
		tour[n] = tour[0]
		if not c._mobile:
			var bas := PackedVector2Array()
			for q in tour:
				bas.append(Vector2(q.x + 0.8, q.y * 0.35 + RY * 0.65 * signf(q.y) * minf(1.0, absf(q.y) / RY) + 2.2))
			p.tracer(bas, 1.6, Color(P.ENCRE, 0.2), false)
		# (la moitié du fond d'abord ; l'appât ; puis la moitié de devant, qui passe par-dessus)
		# (de l'œil, le tour passe par la droite, vient devant, repart à gauche et revient par le fond)
		var devant := PackedVector2Array()
		var haut_a := PackedVector2Array()
		var haut_b := PackedVector2Array()
		var coupe := false
		for i in n + 1:
			var a := wrapf(OEIL + TAU * float(i) / n, -PI, PI)
			if a > 0.0:
				coupe = true
				devant.append(tour[i])
			elif not coupe:
				haut_a.append(tour[i])
			else:
				haut_b.append(tour[i])
		if devant.size() >= 2:
			haut_a.append(devant[0])
			haut_b.insert(0, devant[devant.size() - 1])
		_filin(c, p, haut_b, 2.1, fibre)
		_filin(c, p, haut_a, 2.1, fibre)
		if bool(c.etat.get("amorce", false)):
			_viande(c, p, Vector2(-1.0, 1.2), 1.0, r)
		_filin(c, p, devant, 2.3, fibre.lightened(0.06))
		# les deux fourches qui le tiennent ouvert
		for f in [_tour(PI * 0.97, r), _tour(1.15, r)]:
			var pied: Vector2 = f + Vector2(0.0, 4.6)
			c._baton(p, PackedVector2Array([pied, f + Vector2(0.0, 1.0)]), 1.5, c.BOIS.darkened(0.15 + 0.15 * mouille), 0.9)
			c._baton(p, PackedVector2Array([f + Vector2(0.0, 1.2), f + Vector2(-2.2, -2.2)]), 1.1, c.BOIS.darkened(0.1), 0.8)
			c._baton(p, PackedVector2Array([f + Vector2(0.0, 1.2), f + Vector2(2.1, -2.4)]), 1.1, c.BOIS.darkened(0.2), 0.8)
		# l'œil du nœud : une boucle épissée, surliée de sombre, où passe le brin ; puis le brin, au ras du sol, jusqu'aux pieux
		var oeil: Vector2 = tour[0]
		var brin: PackedVector2Array = c._courbe(oeil + Vector2(1.6, 0.4), Vector2(32.0, 1.2), PIEU + Vector2(-1.0, 1.2), 8)
		if not c._mobile:
			var ob := PackedVector2Array()
			for q in brin:
				ob.append(q + Vector2(0.6, 1.5))
			p.tracer(ob, 1.4, Color(P.ENCRE, 0.2), false)
		_filin(c, p, brin, 2.0, fibre)
		var boucle := Pinceau.ellipse(oeil + Vector2(0.6, 0.1), 3.4, 2.3, 10)
		boucle.append(boucle[0])
		p.tracer(boucle, 2.9, c.ENCRE, false)
		p.tracer(boucle, 1.8, fibre.lightened(0.1), false)
		p.tracer(PackedVector2Array([oeil + Vector2(-3.3, -1.1), oeil + Vector2(-2.7, 1.5)]), 2.4, TORON.darkened(0.3), false)
		if neige > 0.3:
			for a in [2.2, 2.9, 3.6, 4.4]:
				var q := _tour(float(a), r, false)
				p.disque(q + Vector2(0.0, -0.9), 3.0, 1.0, Color(c.NEIGE, 0.85))
		return
	# prise, ou partie : la terre labourée autour du nœud, les fourches couchées, ce qu'il reste de l'appât
	var vers := _vers(c)
	p.eventail(Vector2(4.0, 0.5), 52.0, 23.0, Color(terre.darkened(0.12), 0.55), Color(terre, 0.0), 20)
	for i in 9:
		# (des mottes retournées, des sillons de griffes)
		var a := r.randf() * TAU
		var q := Vector2(cos(a) * r.randf_range(8.0, 40.0), sin(a) * r.randf_range(4.0, 17.0))
		c._pastille(p, q, r.randf_range(1.6, 3.2), r.randf_range(0.9, 1.6), terre.darkened(r.randf_range(0.1, 0.3)))
		c._pastille(p, q + Vector2(-0.5, -0.6), 1.1, 0.6, P.TERRE.lightened(r.randf_range(0.02, 0.14)))
	for k in 3:
		# (ses griffes : trois sillons côte à côte, là où sa patte a porté)
		var o := Vector2(-6.0 + 3.0 * k, 2.0 + 2.4 * k)
		var d := Vector2(vers.x, vers.y * 0.5).normalized() * 15.0
		p.tracer(PackedVector2Array([o - d * 0.5, o + d * 0.2, o + d * 0.7]), 2.0, Color(P.ENCRE, 0.6))
		p.tracer(PackedVector2Array([o - d * 0.5 + Vector2(0.0, -0.9), o + d * 0.6 + Vector2(0.0, -0.9)]), 0.8, Color(P.TERRE.lightened(0.2), 0.7))
	# (ce qu'il reste de l'appât : une tache sombre, que la terre a bue)
	p.eventail(Vector2(-2.0, 1.6), 7.0, 2.8, Color(P.SANG.darkened(0.35), 0.4), Color(P.SANG.darkened(0.35), 0.0), 10)
	for f in [Vector2(-24.0, 3.0), Vector2(9.0, 12.0)]:
		var fo: Vector2 = f
		c._baton(p, PackedVector2Array([fo, fo + Vector2(5.6, 1.2)]), 1.4, c.BOIS.darkened(0.2 + 0.15 * mouille), 0.9)
		c._baton(p, PackedVector2Array([fo + Vector2(5.6, 1.2), fo + Vector2(8.2, -0.4)]), 1.0, c.BOIS.darkened(0.1), 0.8)
	for q in [[Vector2(-17.0, -9.0), 4.4], [Vector2(12.0, -12.6), 3.8]]:
		var o: Vector2 = q[0]
		var rr: float = q[1]
		c._ombre(p, o + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.34)
		c._caillou(p, o + Vector2(0.0, -rr * 0.3), rr, rr * 0.72, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.18)), r)
	if phase != "rompu":
		return
	# rompu : les trous des pieux, leurs bords éboulés ; les pieux couchés du côté où elle est partie, l'un cassé ; les grosses
	# pierres roulées ; un bout de filin, effiloché, resté à la liure
	var couche := Vector2(vers.x, vers.y * 0.5).normalized()
	var trav := Vector2(-couche.y, couche.x)
	for t in [PIEU + Vector2(-3.0, 0.0), PIEU + Vector2(4.0, -1.5)]:
		var trou: Vector2 = t
		p.disque(trou, 3.6, 2.0, terre.darkened(0.45))
		p.disque(trou + Vector2(0.0, 0.5), 2.2, 1.0, Color(P.ENCRE, 0.85))
		for i in 4:
			c._pastille(p, trou + Vector2(r.randf_range(-6.0, 6.0), r.randf_range(1.4, 4.2)), r.randf_range(1.0, 2.0), 0.8, P.TERRE.lightened(r.randf_range(0.0, 0.14)))
	var bois: Color = c.BOIS.darkened(0.12 + 0.2 * mouille)
	var a0 := PIEU + couche * 9.0 + trav * 4.0
	# (le pieu entier, couché, sa pointe terreuse ; la liure et son bout de filin)
	_pieu_couche(c, p, a0, a0 + couche * 21.0, 4.2, bois)
	var liure := a0 + couche * 9.0
	for k in 3:
		var o := liure + couche * (k * 1.7 - 1.7)
		c._corde(p, PackedVector2Array([o - trav * 2.6, o + trav * 2.6]), 1.2, fibre)
	var bout: PackedVector2Array = c._courbe(liure + trav * 2.4, liure + trav * 8.0 + couche * 5.0, liure + trav * 9.0 + couche * 13.0, 6)
	_filin(c, p, bout, 1.9, fibre)
	var fin: Vector2 = bout[bout.size() - 1]
	for k in 3:
		# (ce que ses dents, ou le bois, en ont laissé : trois torons défaits)
		p.tracer(PackedVector2Array([fin, fin + (couche * 4.0 + trav * (k - 1) * 2.6)]), 0.9, fibre.lightened(0.1), true)
	# (l'autre, cassé net : ses deux morceaux, leur bois clair)
	var b0 := PIEU + couche * 15.0 - trav * 7.0
	_pieu_couche(c, p, b0, b0 + couche * 9.0 + trav * 1.5, 4.0, bois.darkened(0.06))
	var b1 := b0 + couche * 14.0 - trav * 3.0
	_pieu_couche(c, p, b1, b1 + couche * 8.0 - trav * 2.6, 3.7, bois.darkened(0.1))
	for e in [b0 + couche * 9.0 + trav * 1.5, b1]:
		var eclat: Vector2 = e
		p.tracer(PackedVector2Array([eclat - couche * 1.2, eclat + couche * 2.6 + trav * 1.0]), 1.4, c.BOIS_CLAIR)
		p.tracer(PackedVector2Array([eclat, eclat + couche * 2.0 - trav * 1.4]), 1.0, c.BOIS_CLAIR.lightened(0.1))
	for q in [[PIEU + couche * 4.0 + trav * 13.0, 5.6], [PIEU + couche * 26.0 - trav * 13.0, 5.0]]:
		var o: Vector2 = q[0]
		var rr: float = q[1]
		c._ombre(p, o + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.36)
		c._caillou(p, o + Vector2(0.0, -rr * 0.3), rr, rr * 0.72, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
		if neige > 0.25:
			p.disque(o + Vector2(-0.3, -rr * 0.85), rr * 0.7, rr * 0.3, c.NEIGE, Pinceau.DOME)


# un pieu couché au sol, de sa pointe (a) à sa tête écrasée (b)
static func _pieu_couche(c, p, a: Vector2, b: Vector2, w: float, bois: Color) -> void:
	c._ombre(p, a.lerp(b, 0.5) + Vector2(0.5, 1.6), a.distance_to(b) * 0.6, 2.4, 0.3)
	p.tracer(PackedVector2Array([a, b]), w + 1.3, c.ENCRE, false)
	p.tracer(PackedVector2Array([a, b]), w, bois, false)
	p.tracer(PackedVector2Array([a.lerp(b, 0.12) + Vector2(0.0, -w * 0.22), b + Vector2(0.0, -w * 0.22)]), w * 0.3, Color(bois.lightened(0.28), 0.8), false)
	# (sa pointe, encore noire de terre)
	p.tracer(PackedVector2Array([a, a.lerp(b, 0.3)]), w * 0.9, Color(P.TERRE.darkened(0.35), 0.8), true)
	p.disque(b, w * 0.42, w * 0.5, c.BOIS_CLAIR.darkened(0.1))


# l'appât : un morceau de viande crue, sombre, luisant ; son gras en liseré, un bout d'os ; le sang qu'il a rendu ; une mouche
static func _viande(c, p, o: Vector2, k: float, r: RandomNumberGenerator) -> void:
	p.eventail(o + Vector2(0.8, 2.0), 9.6 * k, 3.6, Color(P.SANG.darkened(0.3), 0.6), Color(P.SANG.darkened(0.3), 0.0), 12)
	var morceau := PackedVector2Array()
	for q in [Vector2(-6.8, 0.4), Vector2(-5.0, -2.9), Vector2(-0.8, -4.2), Vector2(3.8, -3.3), Vector2(6.6, -0.5), Vector2(5.8, 2.2), Vector2(1.6, 3.2), Vector2(-3.4, 3.0)]:
		morceau.append(o + (q as Vector2) * k)
	c._baton(p, PackedVector2Array([o + Vector2(4.6, -0.8) * k, o + Vector2(9.2, -2.6) * k]), 1.5, P.IVOIRE.lightened(0.15), 0.9)
	c._pastille(p, o + Vector2(9.6, -2.8) * k, 1.2, 1.1, P.IVOIRE.lightened(0.2))
	p.aplat(morceau, CHAIR.darkened(0.14 * c._mouille_cran()))
	# (son dessus luit un peu ; son dessous est dans l'ombre)
	var dessus := PackedVector2Array()
	for q in [Vector2(-5.6, -0.4), Vector2(-4.2, -2.6), Vector2(-0.6, -3.6), Vector2(3.4, -2.8), Vector2(5.2, -0.9), Vector2(1.0, -0.2)]:
		dessus.append(o + (q as Vector2) * k)
	p.aplat(dessus, CHAIR.lightened(0.14).lerp(P.BRAISE_ROUGE, 0.2))
	p.contour(morceau, 1.1, c.ENCRE, r, 3)
	p.tracer(PackedVector2Array([o + Vector2(-5.6, -0.2) * k, o + Vector2(-3.8, -2.4) * k, o + Vector2(-0.6, -3.3) * k]), 0.9, Color(P.IVOIRE, 0.85))
	for y in [0.9, 2.1]:
		p.tracer(PackedVector2Array([o + Vector2(-3.6, float(y)) * k, o + Vector2(0.4, float(y) + 0.5) * k, o + Vector2(4.2, float(y) - 0.2) * k]), 0.5, Color(P.ENCRE, 0.45))
	c._pastille(p, o + Vector2(1.6, -1.6) * k, 1.1, 0.6, Color(P.PAPIER, 0.5))
	var mo := o + Vector2(-2.6, -4.2) * k
	p.tracer(PackedVector2Array([mo, mo + Vector2(-1.7, -1.3)]), 1.1, Color(P.PAPIER, 0.8))
	p.tracer(PackedVector2Array([mo, mo + Vector2(1.6, -1.4)]), 1.1, Color(P.PAPIER, 0.8))
	c._pastille(p, mo, 0.95, 0.8, c.ENCRE)


# --- ce qui est debout : les pieux, leur liure, leurs grosses pierres ; tenue : le filin tendu jusqu'à sa patte ---

static func debout(c, p) -> void:
	if c.genre != "collet":
		return
	var phase := str(c.etat.get("phase", ""))
	if phase == "rompu":
		return
	var r: RandomNumberGenerator = c._hasard(73)
	var mouille: float = c._mouille_cran()
	var neige: float = c._neige_cran()
	var fibre: Color = c.FILIN.darkened(0.08 + 0.16 * mouille)
	var pierre: Color = c._pierre_du_lieu().darkened(0.04 + 0.14 * mouille)
	var bois: Color = c.BOIS.darkened(0.14 + 0.2 * mouille)
	var tenue := phase == "serre"
	# tenue : les pieux penchent du côté où elle tire, et jouent dans leur trou à chaque à-coup
	var penche := Vector2.ZERO
	var saute := 0.0
	var patte := Vector2.ZERO
	var tendu := 0.0
	var t := INF
	if tenue:
		patte = _patte(c)
		t = _a_coup(c)
		var tire := patte - LIURE
		var long := tire.length()
		tendu = smoothstep(R.NOIRE_COLLET_LONGE * 0.72, R.NOIRE_COLLET_LONGE * 1.0, long - 0.15 * R.NOIRE_LARGEUR * 0.5)
		var choc := exp(-t / 0.22) * sin(t * 41.0)
		penche = (tire / maxf(long, 1.0)) * (2.2 + 3.4 * tendu + 2.4 * choc)
		saute = maxf(0.0, exp(-t / 0.16) * sin(t * 26.0)) * 2.2
	var pied_a := PIEU + Vector2(-3.0, 1.0)
	var pied_b := PIEU + Vector2(4.0, -0.6)
	var tete_a := PIEU + Vector2(4.0, -20.0) + penche
	var tete_b := PIEU + Vector2(-3.4, -18.6) + penche * 0.85
	var liure := LIURE + penche * 0.55
	c._ombre(p, PIEU + Vector2(3.0, 2.0), 13.0, 4.2, 0.4)
	# la terre remuée à leur pied
	p.eventail(PIEU + Vector2(0.5, 1.0), 11.0, 4.4, Color(P.TERRE.darkened(0.25), 0.5), Color(P.TERRE, 0.0), 12)
	# le pieu du fond, la liure, le pieu de devant
	c._perche(p, pied_b, tete_b, 4.6, 3.8, bois.darkened(0.1))
	_tete_de_pieu(c, p, tete_b, mouille)
	c._perche(p, pied_a, tete_a, 4.8, 4.0, bois)
	_tete_de_pieu(c, p, tete_a, mouille)
	for k in 4:
		var o := liure + Vector2(-0.3 * k, k * 1.5 - 2.4)
		c._corde(p, PackedVector2Array([o + Vector2(-4.2, -0.6), o + Vector2(4.2, 0.6)]), 1.3, fibre.lightened(0.05 if k % 2 == 0 else 0.0))
	p.disque(liure + Vector2(-4.4, 0.4), 2.0, 1.8, c.ENCRE)
	p.disque(liure + Vector2(-4.5, 0.3), 1.3, 1.15, fibre.lightened(0.12))
	if not tenue:
		# (le brin monte du sol jusqu'à la liure)
		_filin(c, p, PackedVector2Array([PIEU + Vector2(-1.0, 1.2), PIEU + Vector2(-3.2, -4.0), liure + Vector2(-4.4, 0.6)]), 2.0, fibre)
	# les deux grosses pierres qui calent les pieux
	for q in [[PIEU + Vector2(-9.5, 2.6), 5.6], [PIEU + Vector2(10.5, 1.2), 5.0]]:
		var o: Vector2 = q[0] + Vector2(0.0, -saute * (0.6 if q[1] > 5.2 else 1.0))
		var rr: float = q[1]
		c._ombre(p, q[0] + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.38)
		c._caillou(p, o + Vector2(0.0, -rr * 0.34), rr, rr * 0.74, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
		if neige > 0.25:
			p.disque(o + Vector2(-0.3, -rr * 0.9), rr * 0.7, rr * 0.3, c.NEIGE, Pinceau.DOME)
	if neige > 0.25:
		p.disque(tete_a + Vector2(0.0, -1.0), 2.4, 0.9 + 0.8 * neige, c.NEIGE, Pinceau.DOME)
		p.disque(tete_b + Vector2(0.0, -1.0), 2.2, 0.8 + 0.7 * neige, c.NEIGE, Pinceau.DOME)
	if not tenue:
		return
	# le filin, de la liure à sa patte : tendu, une ligne droite qui vibre après l'à-coup ; mou, il retombe et traîne au sol
	var a := liure + Vector2(-4.4, 0.6)
	var b := patte + Vector2(0.0, -5.0)
	var n := 14
	var ligne := PackedVector2Array()
	var trav := (b - a).normalized().orthogonal()
	var vibre := exp(-t / 0.2) * sin(t * 58.0) * 2.6 * tendu
	for i in n + 1:
		var u := float(i) / n
		var q := a.lerp(b, u)
		# (mou : il pend, jusqu'au sol)
		var sol_y := lerpf(PIEU.y + 1.5, patte.y + 1.0, u)
		q.y = lerpf(minf(sol_y, q.y + 26.0 * sin(PI * u)), q.y, tendu)
		q += trav * vibre * sin(PI * u)
		ligne.append(q)
	if not c._mobile:
		var ombre := PackedVector2Array()
		for i in n + 1:
			var u := float(i) / n
			ombre.append(Vector2(ligne[i].x + 0.8, lerpf(PIEU.y + 2.6, patte.y + 2.0, u)))
		p.tracer(ombre, 1.6, Color(P.ENCRE, 0.24), false)
	_filin(c, p, ligne, 2.2, fibre.lightened(0.06 * tendu))
	# le nœud, serré sur son canon : deux tours, et l'œil où le brin mord
	var bague := Pinceau.ellipse(b, 5.2, 2.5, 10)
	bague.append(bague[0])
	p.tracer(bague, 3.0, c.ENCRE, false)
	p.tracer(bague, 1.9, fibre.lightened(0.08), false)
	p.disque(b + (a - b).normalized() * 5.0, 2.2, 1.9, c.ENCRE)
	p.disque(b + (a - b).normalized() * 5.0 + Vector2(-0.2, -0.2), 1.4, 1.2, fibre.lightened(0.14))
	# la terre qui saute au pied des pieux, à chaque à-coup
	if t < 0.5:
		for i in (3 if c._mobile else 7):
			var ang := -PI * 0.5 + (float(i) - 3.0) * 0.36
			var v := Vector2(cos(ang) * 34.0, sin(ang) * 52.0) * (0.6 + 0.4 * fposmod(i * 0.618, 1.0))
			var q := PIEU + Vector2(float(i % 3) * 3.0 - 3.0, 0.0) + v * t + Vector2(0.0, 150.0 * t * t)
			if q.y < PIEU.y + 3.0:
				c._pastille(p, q, 1.4, 1.1, Color(P.TERRE.darkened(0.15 + 0.1 * (i % 2)), 1.0 - t * 1.6))


# la tête d'un pieu, écrasée par le maillet : son bois clair, ses éclats
static func _tete_de_pieu(c, p, tete: Vector2, mouille: float) -> void:
	p.disque(tete, 2.9, 1.5, c.ENCRE)
	p.disque(tete + Vector2(0.0, -0.1), 2.1, 0.9, c.BOIS_CLAIR.darkened(0.1 + 0.2 * mouille))
	p.tracer(PackedVector2Array([tete + Vector2(-2.3, 0.3), tete + Vector2(-3.6, 2.2)]), 0.9, c.BOIS_CLAIR.darkened(0.2 * mouille))
	p.tracer(PackedVector2Array([tete + Vector2(2.2, 0.5), tete + Vector2(3.2, 2.6)]), 0.9, c.BOIS_CLAIR.darkened(0.15 + 0.2 * mouille))


# --- sa couche, vide ---

static func _couche(c, p) -> void:
	var r: RandomNumberGenerator = c._hasard(79)
	var mouille: float = c._mouille_cran()
	var neige: float = c._neige_cran()
	var fouillee := bool(c.etat.get("fouillee", false))
	var terre := P.TERRE.darkened(0.3 + 0.1 * mouille)
	var paille: Color = c.CORDE.lerp(P.MOUSSE, 0.35).darkened(0.12 + 0.2 * mouille)
	# le creux : long comme elle, la terre tassée, plus sombre au milieu
	p.eventail(Vector2(0.0, 0.0), 86.0, 35.0, Color(terre, 0.62), Color(terre, 0.0), 24)
	p.eventail(Vector2(-4.0, 1.0), 58.0, 22.0, Color(terre.darkened(0.25), 0.6), Color(terre, 0.0), 20)
	# l'herbe couchée, en rond : elle tournait sur elle-même avant de se coucher
	for i in 46:
		var a := r.randf() * TAU
		var k := r.randf_range(0.42, 1.0)
		var q := Vector2(cos(a) * 74.0 * k, sin(a) * 29.0 * k)
		var tang := Vector2(-sin(a) * 74.0, cos(a) * 29.0).normalized()
		var l := r.randf_range(5.0, 11.0)
		p.tracer(PackedVector2Array([q - tang * l, q + Vector2(cos(a), sin(a) * 0.4) * 1.2, q + tang * l]), r.randf_range(0.7, 1.2), Color(paille.lightened(r.randf_range(-0.08, 0.14)), r.randf_range(0.4, 0.7)))
	# des os rongés : une côte, deux os longs, fendus
	var os := P.IVOIRE.darkened(0.08 + 0.1 * mouille)
	var cote: PackedVector2Array = c._courbe(Vector2(26.0, -8.0), Vector2(40.0, -15.0), Vector2(53.0, -6.0), 8)
	c._baton(p, cote, 1.3, os, 0.9)
	for b in [[Vector2(-44.0, 9.0), Vector2(-36.0, 12.2), Vector2(-28.0, 12.0)], [Vector2(14.0, 14.0), Vector2(20.0, 11.2), Vector2(27.0, 10.6)]]:
		# (un os long : un peu courbe, une tête à un bout, l'autre bout fendu par ses dents)
		var a0: Vector2 = b[0]
		var b0: Vector2 = b[2]
		c._baton(p, PackedVector2Array([a0, b[1], b0]), 1.6, os, 0.9)
		var hors := (a0 - Vector2(b[1])).normalized()
		for k in [-1.0, 1.0]:
			c._pastille(p, a0 + hors * 0.6 + hors.orthogonal() * 1.2 * float(k), 1.7, 1.4, c.ENCRE)
		for k in [-1.0, 1.0]:
			c._pastille(p, a0 + hors * 0.6 + hors.orthogonal() * 1.2 * float(k), 1.1, 0.9, os.lightened(0.08))
		var fend := (b0 - Vector2(b[1])).normalized()
		p.tracer(PackedVector2Array([b0, b0 + fend.rotated(0.5) * 2.6]), 0.9, os)
		p.tracer(PackedVector2Array([b0, b0 + fend.rotated(-0.4) * 2.0]), 0.8, os.darkened(0.2))
	# son poil : des touffes noires prises dans l'herbe
	for i in 7:
		var a := r.randf() * TAU
		var q := Vector2(cos(a) * r.randf_range(10.0, 60.0), sin(a) * r.randf_range(4.0, 22.0))
		# (une mèche : cinq ou six poils fins, couchés du même côté, un peu frisés)
		var pente := r.randf_range(-0.4, 0.4)
		for k in 6:
			var o := q + Vector2(r.randf_range(-2.0, 2.0), r.randf_range(-1.0, 1.0))
			var d := Vector2.from_angle(pente + r.randf_range(-0.3, 0.3)) * r.randf_range(3.0, 6.5)
			p.tracer(PackedVector2Array([o, o + d * 0.5 + Vector2(0.0, -r.randf_range(0.4, 1.2)), o + d]), 0.55, Color(P.NUIT.lerp(P.ENCRE, 0.4), 0.8))
	# les nœuds qu'elle a ramenés à la patte, et tranchés : des boucles de filin blond, ouvertes, leurs bouts effilochés
	if not fouillee:
		var fibre: Color = c.FILIN.darkened(0.1 + 0.16 * mouille)
		var places := [Vector2(-16.0, -6.0), Vector2(18.0, 3.0), Vector2(-34.0, -1.0), Vector2(40.0, 8.0)]
		for i in clampi(int(c.etat.get("noeuds", 0)), 0, 4):
			var o: Vector2 = places[i]
			var tourne := r.randf_range(-0.5, 0.5)
			var boucle := PackedVector2Array()
			for k in 13:
				var a := tourne + 0.5 + (TAU - 1.0) * float(k) / 12.0
				boucle.append(o + Vector2(cos(a) * 8.0, sin(a) * 3.8))
			var ob := PackedVector2Array()
			for q in boucle:
				ob.append(q + Vector2(0.6, 1.4))
			p.tracer(ob, 1.3, Color(P.ENCRE, 0.22), false)
			_filin(c, p, boucle, 1.9, fibre)
			for bout in [boucle[0], boucle[12]]:
				var e: Vector2 = bout
				var hors := (e - o).normalized()
				for k in 3:
					p.tracer(PackedVector2Array([e, e + hors.rotated((k - 1) * 0.55) * 3.4]), 0.8, fibre.lightened(0.12), true)
	else:
		# (fouillée : plus rien d'elle que le creux ; l'herbe s'y redresse déjà, verte)
		var vert := P.MOUSSE.lightened(0.3)
		for i in 9:
			var a := r.randf() * TAU
			var q := Vector2(cos(a) * r.randf_range(20.0, 66.0), sin(a) * r.randf_range(8.0, 25.0))
			p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-1.4, 1.4), -r.randf_range(5.0, 8.5))]), 1.1, vert.darkened(r.randf_range(0.0, 0.2)))
	if neige > 0.3:
		p.eventail(Vector2(-4.0, 1.0), 50.0, 18.0, Color(c.NEIGE, 0.75 * neige), Color(c.NEIGE, 0.0), 18)
