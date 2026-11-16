extends RefCounted
# Lisière — L'AFFÛT (scripts/affut.gd)
# La nuit, autour d'un feu où la veilleuse se tient, un chasseur ne tourne pas : il se poste dans le noir, et il attend
# (scripts/bete.gd, _chasseur). Ici : où il se poste, et l'entente de la meute (qui bouge, qui tient, qui vient d'abord).
# Rien de tout cela ne se fait à chaque image : seulement quand un chasseur choisit un poste, ou quand son tour vient.
#
# Un poste : hors de la lumière (on ne voit de lui que ses yeux), dans l'écran tant que c'est possible (l'écran suit la
# veilleuse : sous un feu haut, le noir visible est sur les côtés), derrière un couvert s'il s'en trouve un à la bonne
# distance, et à l'écart des autres : à trois, ils tiennent trois côtés.

const R := preload("res://scripts/regles.gd")
# ce qui cache une bête, et combien (un arbre en feu ne cache rien)
const COUVERTS := {"arbre": 1.0, "sapin": 1.0, "rocher": 0.9, "buisson": 0.7, "souche": 0.35}
const DIRECTIONS := 16
# où il en est (bete.gd, _af)
const RIEN := 0        # pas de feu entre elle et lui
const VIENT := 1       # il vient voir, droit sur la lisière
const TENU := 2        # le feu le tient, à la lisière : il regarde
const GAGNE := 3       # il gagne son poste (ou s'y remet : le feu a baissé, il a gagné quelques pas)
const POSTE := 4       # posté : il ne bouge plus
const CHANGE := 5      # il s'est détourné : il passe par le noir, au large, vers un autre poste
const FEINTE := 6      # quelques pas vifs jusqu'à la lisière
const GRONDE := 7      # … un grondement, et il s'en retourne

# à la torche, derrière la veilleuse : l'écart de chacun avec son dos (radians), dans l'ordre où ils y viennent
const AU_DOS := [0.0, 0.95, -0.95, 1.7, -1.7]

# (la vitrine, --hate 4 : leur patience quatre fois plus courte, pour les voir changer de poste sans attendre)
static var hate := 1.0


# la moitié de ce qu'on voit du lieu autour de la veilleuse, moins une marge : ses yeux doivent tenir dans l'image (le
# téléphone montre moins haut)
static func demi_ecran(jeu) -> Vector2:
	var haut := 576.0 if str(jeu.qualite) == "mobile" else 720.0
	return Vector2(1280.0, haut) / (2.0 * R.ZOOM) - Vector2(40.0, 34.0)


# de combien ce point sort de l'écran (0 : il y est)
static func hors_ecran(jeu, p: Vector2) -> float:
	var q: Vector2 = (p - jeu.joueur.position).abs() - demi_ecran(jeu)
	return maxf(maxf(q.x, q.y), 0.0)


# à quelle distance du feu il se poste : hors de sa lumière, de la moitié de son corps et un peu plus (1,07 rayon) ; plus loin
# s'il craint le feu ou les joueurs (jusqu'à 1,4), et sous la fumée âcre : _lisiere en tient compte
static func distance(b, feu) -> float:
	var l: float = b._lisiere()
	return float(feu.rayon()) * (1.5 * l - 0.13) + 10.0 + float(b.largeur) * 0.4


# les autres chasseurs en vie, la nuit, à portée de ce feu
static func meute(b, jeu, centre: Vector2) -> Array:
	var autres := []
	for o in jeu.get_tree().get_nodes_in_group("betes"):
		if o != b and str(o.role) == "chasseur" and float(o.pv) > 0.0 and str(o.etat) != "part" and o.position.distance_to(centre) < 1100.0:
			autres.append(o)
	return autres


# où se tient (ou va se tenir) un autre de la meute
static func place(o) -> Vector2:
	return o._poste_p if int(o._af) >= GAGNE else o.position


# un autre de la meute est-il en train de bouger (il change de poste, il feinte) ? Jamais tous à la fois : celui-ci attendra
static func un_autre_bouge(b, jeu, centre: Vector2) -> bool:
	for o in meute(b, jeu, centre):
		if int(o._af) == CHANGE or int(o._af) == FEINTE or int(o._af) == GRONDE:
			return true
	return false


# elle sort de la lumière : dans combien de temps son tour vient. Le plus près ou le plus hardi d'abord, les autres une ou
# deux secondes après, l'un après l'autre
static func tour(b, jeu, centre: Vector2) -> float:
	var j: Vector2 = jeu.joueur.position
	var moi: float = b.position.distance_to(j) - 160.0 * float(b.audace)
	var rang := 0
	for o in meute(b, jeu, centre):
		if int(o._af) != RIEN and o.position.distance_to(j) - 160.0 * float(o.audace) < moi:
			rang += 1
	return rang * randf_range(1.0, 1.5) + (randf_range(0.05, 0.3) if rang == 0 else 0.0)


# à la torche : la première place libre derrière elle (jamais deux au même endroit)
static func place_au_dos(b, jeu) -> int:
	var prises := {}
	for o in meute(b, jeu, jeu.joueur.position):
		if int(o._dos_n) >= 0:
			prises[int(o._dos_n)] = true
	for n in AU_DOS.size():
		if not prises.has(n):
			return n
	return randi() % AU_DOS.size()


# un poste autour de ce feu. « ailleurs » : il change de poste (pas à deux pas de celui qu'il quitte) ; sinon, le plus près de
# là d'où il vient qui soit libre. Rend le point, dans le lieu
static func poste(b, feu, jeu, ailleurs: bool) -> Vector2:
	var c: Vector2 = feu.position
	var r: float = feu.rayon()
	var d0 := distance(b, feu)
	var ici: Vector2 = b.position - c
	var a_ici := ici.angle()
	var autres := meute(b, jeu, c)
	var places: Array[Vector2] = []
	for o in autres:
		places.append(place(o))
	# (ce qu'il faut d'écart entre deux bêtes pour qu'on les sente de deux côtés : un tiers de tour à trois)
	var large := TAU / maxf(3.0, places.size() + 1.0)
	var feux: Array = jeu.feux_et_foyers()
	var limite: float = b._lisiere()
	# les candidats : seize directions, à sa distance ; puis l'arrière de chaque couvert qui se trouve à peu près là
	var candidats: Array[Vector3] = []
	var tourne := randf() * TAU
	for k in DIRECTIONS:
		var p := c + Vector2.from_angle(tourne + k * TAU / DIRECTIONS) * (d0 + randf() * 0.05 * r)
		candidats.append(Vector3(p.x, p.y, 0.0))
	if jeu.monde != null:
		for o in jeu.monde.autour(c, d0 + 0.08 * r + 30.0):
			var cache: float = COUVERTS.get(str(o.genre), 0.0)
			if cache <= 0.0 or float(o.brule) > 0.0:
				continue
			var vers: Vector2 = o.position - c
			if vers.length() < 1.0:
				continue
			# (derrière lui, vu du feu : le tronc entre elle et lui)
			var p2: Vector2 = o.position + vers.normalized() * (maxf(float(o.rayon), 8.0) + 6.0 + float(b.largeur) * 0.25)
			var d2 := p2.distance_to(c)
			if d2 >= d0 - 0.02 * r and d2 <= d0 + 0.08 * r:
				candidats.append(Vector3(p2.x, p2.y, cache))
	var meilleur := c + (ici.normalized() if ici.length() > 1.0 else Vector2.RIGHT) * d0
	var note0 := -INF
	for cand in candidats:
		var p := Vector2(cand.x, cand.y)
		if not jeu.ouvert and (absf(p.x) > R.DEMI - 20.0 or absf(p.y) > R.DEMI - 20.0):
			continue
		# (pas dans la lumière d'un autre feu, ni d'un arbre qui brûle)
		var eclaire := false
		for f in feux:
			if f != feu and f.allume() and p.distance_to(f.position) < float(f.rayon()) * maxf(limite, 1.0) + 20.0:
				eclaire = true
				break
		if eclaire:
			continue
		var note := 0.4 * cand.z + randf() * 0.25
		var hors := hors_ecran(jeu, p)
		note += 1.0 if hors <= 0.0 else -0.02 * hors
		# à l'écart des autres
		var a := (p - c).angle()
		var ecart := PI
		for q in places:
			ecart = minf(ecart, absf(wrapf(a - (q - c).angle(), -PI, PI)))
			if p.distance_to(q) < 110.0:
				note -= 3.0
		note += 2.4 * minf(ecart / large, 1.0)
		var da := absf(wrapf(a - a_ici, -PI, PI))
		if ailleurs:
			# (ailleurs pour de bon : un quart de tour ou plus, pas le tour entier)
			note -= 2.5 if da < 0.8 else 0.25 * absf(da - 1.8)
		else:
			note -= 0.35 * da
		if note > note0:
			note0 = note
			meilleur = p
	return meilleur
