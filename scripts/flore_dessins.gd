extends RefCounted
# Lisière — la flore dessinée à l'encre (scripts/flore_dessins.gd)
# Chaque forme de l'herbier d'Orvane (scripts/flore.gd), dessinée par Lisière comme elle dessine ses bêtes : Orvane dit ce
# qu'est la plante (sa forme, sa hauteur, son stade, sa couleur), Lisière la dessine dans son carnet, au pinceau de
# l'environnement (scripts/decor_pinceau.gd), un contour d'encre, trois tons, la lumière en haut à gauche. On la reconnaît à sa
# silhouette, d'un coup d'œil, à la taille du jeu : le bouleau pâle et ses taches, le palmier sur son fût annelé, la fougère
# arborescente et ses crosses, le palétuvier sur ses échasses, le cactus en candélabre, l'agave et ses dards, les lichens à plat,
# les nénuphars sur leur mare… Et les plantes de Lisière : les fleurs des prés, le cèpe et l'amanite (rouge, piquée de blanc).
# objet.gd demande ici : regler (ce que la forme change à sa conduite : une part, un tronc plus fin, un rayon où l'on bute),
# mesurer (sa taille), pied et couronne (un arbre), dessiner (le reste), ombres. Rien n'est refait à chaque image : un objet se
# dessine une fois, et quand il change (cueilli, qui repousse).

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const T := preload("res://scripts/flore_trait.gd")
const Arbres := preload("res://scripts/flore_arbres.gd")
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
const R_BAIES := preload("res://scripts/regles.gd").BAIES_PAR_BUISSON

# les formes que Lisière dessine elle-même (une forme qui n'y est pas se dessine comme celles de son port, ou par la planche)
const DESSINEES := ["arbre", "pionnier", "fruitier", "geant", "emergent", "figuier", "bouteille", "sous_bois", "palmier", "paletuvier",
	"fougere_arbre", "conifere", "buisson", "baies", "epine", "ronce", "aromatique", "bruyere", "liane", "herbe", "cereale", "grande_herbe",
	"legumineuse", "fougere", "coussin", "mousse", "lichen", "lichen_rennes", "lichen_croute", "succulente", "agave", "cactus", "caillou",
	"roseau", "jonc", "riz", "papyrus", "bambou", "fleur", "bulbe", "orchidee", "bromelia", "algue", "lentille", "nenuphar",
	"champignon", "champignon_lumineux", "champignon_geant", "moisissure", "cepe", "amanite"]


static func sait(forme: String) -> bool:
	return DESSINEES.has(forme)


# --- ce que la forme change à l'objet : ses parts, son tronc, ce où l'on bute ---

static func regler(o) -> void:
	if bool(o.planche):
		_planche(o)
	# (les arbres : leur tronc, leur écorce ; scripts/flore_arbres.gd)
	Arbres.regler(o)
	match str(o.forme):
		"cactus":
			o.plein = 2
			o.rayon = 7.0
		"agave":
			o.rayon = 5.0
		"bambou":
			o.plein = 2
			o.rayon = 5.0
		"grande_herbe":
			o.haut_touffe = 1.6
		"lentille", "mousse", "lichen", "lichen_croute", "caillou":
			# (un tapis au ras du sol, une nappe sur l'eau : rien à cueillir)
			o.plein = 0
	if str(o.genre) == "fleur":
		# (une fleur qui n'est pas en fleurs n'a rien à donner)
		o.plein = 1 if o.en_fleurs else 0


# --- la taille, d'après la forme (après la mesure commune de son genre) ---

static func mesurer(o, r: RandomNumberGenerator) -> void:
	var f := str(o.forme)
	match str(o.genre):
		"arbre":
			Arbres.mesurer(o, r, f)
		"touffe":
			match f:
				"cactus":
					o._ry = r.randf_range(46.0, 58.0)
					o._rx = r.randf_range(6.5, 8.0)
					o.hauteur = o._ry
				"agave":
					o._rx = r.randf_range(16.0, 20.0)
					o._ry = r.randf_range(15.0, 19.0)
					o.hauteur = o._ry
				"bambou":
					o._ry = r.randf_range(56.0, 74.0)
					o.hauteur = o._ry
				"papyrus":
					o._ry = r.randf_range(32.0, 40.0)
					o.hauteur = o._ry
				"cereale", "riz":
					o._ry = r.randf_range(19.0, 25.0)
					o.hauteur = o._ry
				"jonc":
					o._ry = r.randf_range(19.0, 25.0)
					o.hauteur = o._ry
				"fougere":
					o._ry = r.randf_range(19.0, 24.0)
					o.hauteur = o._ry
				"coussin", "lichen_rennes", "succulente", "legumineuse":
					o._rx = r.randf_range(8.0, 11.5)
					o._ry = r.randf_range(6.0, 9.0)
					o.hauteur = o._ry
				"mousse", "lichen", "lichen_croute", "caillou":
					o._rx = r.randf_range(8.0, 13.0)
					o._ry = o._rx * r.randf_range(0.42, 0.55)
					o.hauteur = 2.0
		"buisson":
			match f:
				"bruyere", "aromatique":
					o._rx = r.randf_range(11.0, 14.0)
					o._ry = r.randf_range(9.0, 12.0)
					o.hauteur = o._ry
				"ronce":
					o._rx = r.randf_range(15.0, 19.0)
					o._ry = r.randf_range(15.0, 19.0)
					o.hauteur = o._ry
				"liane":
					o._ry = r.randf_range(26.0, 32.0)
					o.hauteur = o._ry
		"fleur":
			o._rx = r.randf_range(13.0, 19.0)
			o._ry = o._rx * r.randf_range(0.42, 0.55)
			o.hauteur = r.randf_range(9.0, 14.0)
		"aquatique":
			o._rx = r.randf_range(15.0, 22.0)
			o._ry = o._rx * r.randf_range(0.4, 0.48)
			o.hauteur = 1.0
		"cepe", "amanite":
			o._rx = r.randf_range(4.0, 6.0)
			o._ry = r.randf_range(6.0, 9.0)
			o.hauteur = o._ry


# --- les ombres d'une forme à elle ([] : aucune ; null : celles de son genre) ---

static func ombres(o):
	var f := str(o.forme)
	match str(o.genre):
		"arbre":
			return Arbres.ombres(o)
		"fleur":
			return [[Vector2(0, 1), Vector2(o._rx * 0.8, 3.0), 0.18, 0.0, 0.0]]
		"aquatique":
			return []
		"cepe", "amanite":
			return [[Vector2(0.5, 1), Vector2(6.0, 2.2), 0.4, 0.0, 0.0]]
		"touffe":
			match f:
				"cactus":
					return [[Vector2(1, 1), Vector2(9.0, 3.5), 0.45, 0.0, 0.0], [Vector2(2, 2), Vector2(o._rx * 1.4, o._rx * 0.6), 0.25, 1.0, o.hauteur * 0.8]]
				"bambou", "papyrus":
					return [[Vector2(0, 1), Vector2(10.0, 3.5), 0.35, 0.0, 0.0], [Vector2(2, 2), Vector2(9.0, 4.0), 0.2, 1.0, o.hauteur * 0.6]]
				"agave", "coussin", "succulente", "lichen_rennes":
					return [[Vector2(0.5, 1), Vector2(o._rx * 1.05, o._rx * 0.32), 0.32, 0.0, 0.0]]
				"mousse", "lichen", "lichen_croute", "caillou":
					return []
	return null


# --- les arbres (scripts/flore_arbres.gd) : ce qu'objet.gd demande de leur pied et de leur couronne ---

# là où l'on bute, d'après le tronc (après la mesure et l'échelle)
static func ajuster(o) -> void:
	Arbres.ajuster(o)


# les racines d'une forme à elle (faux : celles de tous les arbres)
static func racines(o, p, r: RandomNumberGenerator, souche: bool) -> bool:
	return Arbres.racines(o, p, r, souche)


# d'où part le bas du tronc (0,5 : du sol ; plus haut : il est sur des échasses)
static func pied_du_tronc(o) -> float:
	return Arbres.pied_du_tronc(o)


# ce que l'écorce porte au pied
static func ecorce_du_pied(o, p, r: RandomNumberGenerator) -> void:
	Arbres.ecorce_du_pied(o, p, r)


# le haut de l'arbre (la couronne, sur son propre nœud) ; faux : le feuillu d'objet.gd
static func couronne(o, p, r: RandomNumberGenerator) -> bool:
	return Arbres.couronne(o, p, r)


# le bois nu d'un arbre en feu, roussi (faux : les branches de tous les arbres)
static func bois_nu(o, p, dehors := false) -> bool:
	return Arbres.bois_nu(o, p, dehors)


# --- la cueillette nourricière : les fruits des arbres (scripts/flore.gd, FRUITS ; scripts/objet.gd, cueillir_fruit) ---
# Chaque fruit se lit à sa silhouette, petit comme il l'est : la pomme ronde et luisante, sa queue ; la figue en goutte, le col en
# haut ; la noix de coco, grosse, en grappe sous les palmes ; le fruit du baobab, une gourde de velours pendue à un long fil ; les
# sorbes, des grappes de petites baies orangées. Leurs places sont tirées une fois de la graine de l'arbre : on en cueille une,
# elle manque, les autres ne bougent pas. Un arbre vidé en porte de nouveau en deux jours et demi : des fruits verts d'abord, qui
# grossissent (sa couronne se redessine par quarts). Au printemps, des fleurs à leur place ; l'hiver, rien.

# combien de fruits dessinés pour un fruit cueilli (un arbre chargé se voit chargé)
const PAR_FRUIT := {"pomme": 2, "figue": 2, "coco": 1, "pain_de_singe": 1, "baies": 1}


# la couleur d'un fruit mûr (un pommier sur trois a ses pommes jaunes)
static func couleur_fruit(sorte: String, graine: int = 1) -> Color:
	match sorte:
		"pomme":
			return P.BRAISE_ROUGE.lerp(P.BRAISE, 0.25) if graine % 3 != 0 else P.BRAISE_COEUR.darkened(0.12).lerp(P.MOUSSE, 0.12)
		"figue":
			# (une prune violette : elle se lit sur le vert sombre du figuier)
			return P.PEUR.lerp(P.SANG, 0.62).darkened(0.04)
		"coco":
			return P.TERRE.lerp(P.MOUSSE, 0.25).lerp(P.BRAISE, 0.1).darkened(0.12)
		"pain_de_singe":
			return P.CENDRE.lerp(P.IVOIRE, 0.42).lerp(P.MOUSSE, 0.22)
		"baies":
			return P.BRAISE_ROUGE.lerp(P.BRAISE, 0.42)
	return P.BRAISE_ROUGE


# les places de ses fruits sur sa couronne, tirées de sa graine : [où, vers où il penche]. Elles tiennent dans le bas et le devant
# du feuillage (un fruit pend) ; celles du baobab, au bout de ses branches ; celles du palmier, sous ses palmes
static func _places_fruits(o, n: int) -> Array:
	var rf := RandomNumberGenerator.new()
	rf.seed = int(o.graine) + 71
	var cc: Vector2 = o._cc
	var rx: float = o._rx
	var ry: float = o._ry
	var out := []
	match str(o.fruit):
		"coco":
			# (sous le cœur des palmes, serrées)
			for i in n:
				var a := (i - (n - 1) * 0.5) * 0.9 + rf.randf_range(-0.2, 0.2)
				out.append([cc + Vector2(sin(a) * 5.2, 4.2 + cos(a) * 1.8 + rf.randf_range(-0.6, 0.6)), a * 0.2])
		"pain_de_singe":
			var bouts: Array = o.get_meta("bouts", [])
			for i in n:
				var q: Vector2 = bouts[i % bouts.size()] if not bouts.is_empty() else cc + Vector2(rf.randf_range(-0.7, 0.7) * rx, 0.0)
				out.append([q + Vector2(rf.randf_range(-4.0, 4.0), rf.randf_range(1.0, 3.0)), rf.randf_range(-0.15, 0.15)])
		_:
			var larg := 0.8 if str(o.forme) in ["figuier", "bouteille", "emergent"] else 0.72
			for i in n:
				# (plus serrées vers le bas : le poids les tire)
				var u := rf.randf()
				var y := lerpf(-0.45, 0.72, sqrt(u))
				var x := rf.randf_range(-1.0, 1.0) * larg * sqrt(maxf(0.0, 1.0 - y * y * 0.6))
				out.append([cc + Vector2(x * rx, y * ry), rf.randf_range(-0.3, 0.3)])
	return out


# ses fruits sur sa couronne, ou ses fleurs (le printemps), ou ses fruits verts qui reviennent
static func fruits_couronne(o, p) -> void:
	var sorte := str(o.fruit)
	var k_par: int = int(PAR_FRUIT.get(sorte, 1))
	if str(o.maturite) == "fleurs":
		_fleurs_d_arbre(o, p)
		return
	var vert: float = o.pousse_fruits()
	var n := 0
	var murs := true
	if float(o._repousse_fruits) > 0.0:
		# (ils reviennent : rien le premier quart, puis des fruits verts qui grossissent)
		if vert < 0.25:
			return
		n = int(o.fruits_plein) * k_par
		murs = false
	else:
		n = int(o.fruits) * k_par
	if n <= 0:
		return
	var places := _places_fruits(o, int(o.fruits_plein) * k_par)
	var c := couleur_fruit(sorte, int(o.graine))
	var k := 1.0 if murs else lerpf(0.5, 0.82, (vert - 0.25) / 0.75)
	if not murs:
		# (vert tendre, tirant sur le jaune : un fruit qui n'est pas encore mûr)
		c = P.MOUSSE.lightened(0.12).lerp(P.BRAISE_COEUR, 0.28).lerp(c, smoothstep(0.6, 1.0, vert) * 0.3)
	for i in mini(n, places.size()):
		_fruit(p, sorte, places[i][0], float(places[i][1]), k, c, i)


# un fruit, à sa place sur l'arbre (pendu : son col, sa queue vers le haut) ; k sa taille, c sa couleur, i son rang (un sur
# trois a une feuille à côté)
static func _fruit(p, sorte: String, q: Vector2, penche: float, k: float, c: Color, i: int) -> void:
	var eclat := Color(P.PAPIER.lightened(0.3), 0.85)
	match sorte:
		"pomme":
			p.disque(q, 2.5 * k, 2.4 * k, ENCRE)
			p.disque(q, 1.9 * k, 1.85 * k, c, Pinceau.DOME)
			p.disque(q + Vector2(-0.6, -0.7) * k, 0.55 * k, 0.5 * k, eclat)
			p.tracer(PackedVector2Array([q + Vector2(0.1, -1.7) * k, q + Vector2(0.5 + penche, -3.0) * k]), 0.6, ENCRE, false)
			if i % 3 == 1:
				_feuille_de_fruit(p, q + Vector2(0.6, -2.6) * k, penche + 0.5, 2.2 * k)
		"figue":
			# (une goutte, le col en haut ; un rien de vert près du col)
			var poly := _goutte_pendue(q, 2.15 * k, 3.1 * k, penche)
			p.aplat(_grossi(poly, q, 0.65), ENCRE)
			p.aplat(poly, c, Pinceau.DOME, q + Vector2(0, 0.6 * k), Vector2(2.2, 2.8) * k)
			# (la pruine claire de sa peau, du côté du jour)
			p.disque(q + Vector2(-0.6, -0.3) * k, 0.55 * k, 0.75 * k, Color(P.PAPIER, 0.55))
			p.tracer(PackedVector2Array([q + Vector2(penche * 2.2, -2.8) * k, q + Vector2(penche * 2.9, -3.8) * k]), 0.7, P.MOUSSE.darkened(0.2), false)
			if i % 3 == 0:
				_feuille_de_fruit(p, q + Vector2(-1.2, -2.8) * k, penche - 0.7, 2.6 * k)
		"coco":
			# (grosse, ronde, ses fibres en côtes ; l'éclat d'une coque lisse)
			p.disque(q, 4.1 * k, 3.8 * k, ENCRE)
			p.disque(q, 3.4 * k, 3.1 * k, c, Pinceau.DOME)
			p.tracer(PackedVector2Array([q + Vector2(-2.2, -1.5) * k, q + Vector2(0.1, 0.5) * k, q + Vector2(0.8, 2.8) * k]), 0.6, Color(ENCRE, 0.45), false)
			p.disque(q + Vector2(-1.1, -1.2) * k, 0.85 * k, 0.65 * k, Color(eclat, 0.6))
		"pain_de_singe":
			# (une gourde de velours, pendue à un long fil, sous la branche)
			var bas := q + Vector2(penche * 4.0, 7.5 * k)
			p.tracer(PackedVector2Array([q, q.lerp(bas, 0.5) + Vector2(0.4, 0), bas + Vector2(0, -2.6 * k)]), 0.7, ENCRE, false)
			p.disque(bas, 2.0 * k + 0.6, 3.4 * k + 0.6, ENCRE)
			p.disque(bas, 2.0 * k, 3.4 * k, c, Pinceau.DOME)
			p.tracer(PackedVector2Array([bas + Vector2(0.9, -1.8) * k, bas + Vector2(1.2, 1.6) * k]), 0.5, Color(ENCRE, 0.35), false)
			p.disque(bas + Vector2(-0.7, -1.2) * k, 0.5 * k, 0.9 * k, Color(eclat, 0.45))
		"baies":
			# (une grappe de sorbes : six petites baies serrées sur leur corymbe)
			p.tracer(PackedVector2Array([q + Vector2(0.0, -3.0), q + Vector2(penche, -0.8)]), 0.6, P.TERRE, false)
			var grappe := [Vector2(0, 0), Vector2(-1.5, 0.4), Vector2(1.5, 0.3), Vector2(-0.8, 1.6), Vector2(0.9, 1.6), Vector2(0.1, -1.2)]
			for g in grappe:
				p.disque(q + g * k, 1.25 * k, 1.2 * k, ENCRE)
			for g in grappe:
				p.disque(q + g * k, 0.85 * k, 0.82 * k, c, Pinceau.DOME)
			p.disque(q + Vector2(-1.8, 0.0) * k, 0.3, 0.3, eclat)


# une goutte la pointe en haut (une figue), penchée
static func _goutte_pendue(q: Vector2, r: float, h: float, penche: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var col := q + Vector2(penche * h * 0.6, -h)
	for j in 11:
		var a := -PI * 0.15 + PI * 1.3 * j / 10.0
		poly.append(q + Vector2(cos(a) * r, sin(a) * r * 0.95 + r * 0.25))
	# (l'arc a tourné du flanc droit, par le bas, jusqu'au flanc gauche : le col, de gauche à droite)
	poly.append(col + Vector2(-r * 0.25, 0.0))
	poly.append(col + Vector2(r * 0.25, 0.0))
	return poly


# une feuille près d'un fruit : une amande verte, sa nervure
static func _feuille_de_fruit(p, q: Vector2, ang: float, l: float) -> void:
	var d := Vector2.from_angle(ang - PI * 0.5) * l
	var n := d.orthogonal().normalized() * l * 0.32
	var poly := PackedVector2Array([q, q + d * 0.5 + n, q + d, q + d * 0.5 - n])
	p.aplat(_grossi(poly, q + d * 0.5, 0.5), Color(ENCRE, 0.85))
	p.aplat(poly, P.MOUSSE.lightened(0.12), Pinceau.FEUILLAGE, q + d * 0.5, Vector2(l * 0.5, l * 0.5))
	p.tracer(PackedVector2Array([q, q + d * 0.85]), 0.4, Color(ENCRE, 0.5), false)


# au printemps, l'arbre fleurit à la place de ses fruits : des fleurs pâles (un pommier rose, le baobab ses grandes fleurs
# blanches pendues, le palmier ses épis crème) ; le figuier, lui, fleurit dans ses figues : on n'en voit rien
static func _fleurs_d_arbre(o, p) -> void:
	var sorte := str(o.fruit)
	if sorte == "figue":
		return
	var n: int = 4 if sorte in ["coco", "pain_de_singe"] else 12
	var places := _places_fruits(o, n)
	var pale := P.PAPIER.lerp(P.BRAISE_ROUGE, 0.12) if sorte == "pomme" else P.PAPIER.lightened(0.08)
	for i in places.size():
		var q: Vector2 = places[i][0]
		match sorte:
			"coco":
				# (un épi de fleurs crème, en balai, sous les palmes)
				for j in 5:
					var bout := q + Vector2((j - 2) * 1.3, 4.0 + absf(j - 2) * -0.6)
					p.tracer(PackedVector2Array([q, bout]), 0.9, ENCRE, false)
					p.disque(bout, 0.8, 0.7, P.BRAISE_COEUR.lerp(P.PAPIER, 0.5))
			"pain_de_singe":
				var bas := q + Vector2(0.0, 6.0)
				p.tracer(PackedVector2Array([q, bas]), 0.6, ENCRE, false)
				p.disque(bas, 2.5, 2.0, ENCRE)
				p.disque(bas, 2.0, 1.55, pale, Pinceau.DOME)
				p.disque(bas + Vector2(0, 1.0), 0.6, 0.5, P.BRAISE_COEUR)
			_:
				p.disque(q, 1.55, 1.35, Color(ENCRE, 0.55))
				p.disque(q, 1.15, 1.0, pale)
				p.disque(q, 0.35, 0.35, P.BRAISE_COEUR.darkened(0.1))


# ses fruits tombés, dans l'herbe à son pied (devant le tronc) : une bête qui broute vient les manger
static func tombes(o, p) -> void:
	var rf := RandomNumberGenerator.new()
	rf.seed = int(o.graine) + 83
	var sorte := str(o.fruit)
	var c := couleur_fruit(sorte, int(o.graine)).darkened(0.08)
	for i in int(o.tombes_plein):
		var a := rf.randf_range(0.35, PI - 0.35)
		var d := rf.randf_range(9.0, 18.0)
		var q := Vector2(cos(a) * d * 1.15, 1.5 + sin(a) * d * 0.32)
		var tourne := rf.randf_range(-1.2, 1.2)
		if i >= int(o.tombes):
			continue
		p.disque(q + Vector2(0.6, 1.0), 2.8, 1.0, Color(P.ENCRE, 0.28))
		match sorte:
			"pomme":
				p.disque(q, 2.4, 2.25, ENCRE)
				p.disque(q, 1.8, 1.7, c, Pinceau.DOME)
				p.disque(q + Vector2(-0.6, -0.6), 0.5, 0.45, Color(P.PAPIER, 0.7))
				# (une pomme tombée depuis un moment : une meurtrissure brune)
				if i == 1:
					p.disque(q + Vector2(0.8, 0.5), 0.8, 0.6, P.TERRE.darkened(0.2))
			"figue":
				var poly := _goutte_pendue(q, 1.7, 2.6, 0.0)
				for j in poly.size():
					poly[j] = q + (poly[j] - q).rotated(PI * 0.5 + tourne * 0.4)
				p.aplat(_grossi(poly, q, 0.6), ENCRE)
				p.aplat(poly, c, Pinceau.DOME, q, Vector2(2.2, 2.2))
			"coco":
				p.disque(q, 3.2, 2.8, ENCRE)
				p.disque(q, 2.6, 2.2, c.darkened(0.08), Pinceau.DOME)
				p.tracer(PackedVector2Array([q + Vector2(-1.6, -0.9), q + Vector2(1.4, 0.8)]), 0.5, Color(ENCRE, 0.45), false)
			"pain_de_singe":
				var axe := Vector2.from_angle(tourne * 0.3)
				p.disque(q, 3.7, 2.2, ENCRE)
				p.aplat(Pinceau.ellipse(q, 3.1, 1.6, 14), c, Pinceau.DOME, q, Vector2(3.1, 1.6))
				p.tracer(PackedVector2Array([q + axe * 3.0, q + axe * 5.2 + Vector2(0, -0.8)]), 0.6, ENCRE, false)
			"baies":
				# (quelques sorbes éparses ; leurs places ne tirent pas le hasard : les autres fruits tombés ne bougent pas)
				for j in 4:
					var b := q + Vector2(sin(i * 3.1 + j * 2.3) * 3.0, cos(i * 1.7 + j * 2.9) * 1.1)
					p.disque(b, 1.15, 1.05, ENCRE)
					p.disque(b, 0.75, 0.7, c, Pinceau.DOME)


# --- le reste : buissons, sol, fleurs, eau, champignons des bois ---

static func dessiner(o, p, r: RandomNumberGenerator) -> bool:
	if bool(o.planche):
		# (sa planche est un nœud à part, posé une fois : regler)
		return true
	var f := str(o.forme)
	match str(o.genre):
		"buisson":
			match f:
				"epine":
					_epine(o, p, r)
				"ronce":
					_ronce(o, p, r)
				"aromatique":
					_aromatique(o, p, r)
				"bruyere":
					_bruyere(o, p, r)
				"liane":
					_liane(o, p, r)
				_:
					return false
		"touffe":
			match f:
				"cereale":
					_cereale(o, p, r, false)
				"riz":
					_cereale(o, p, r, true)
				"jonc":
					_jonc(o, p, r)
				"papyrus":
					_papyrus(o, p, r)
				"bambou":
					_bambou(o, p, r)
				"legumineuse":
					_legumineuse(o, p, r)
				"fougere":
					_fougere(o, p, r)
				"coussin":
					_coussin(o, p, r)
				"mousse":
					_mousse(o, p, r)
				"lichen":
					_lichen(o, p, r, false)
				"lichen_croute":
					_lichen(o, p, r, true)
				"lichen_rennes":
					_lichen_rennes(o, p, r)
				"succulente":
					_succulente(o, p, r)
				"agave":
					_agave(o, p, r)
				"cactus":
					_cactus(o, p, r)
				"caillou":
					_plante_caillou(o, p, r)
				_:
					return false
		"fleur":
			_fleurs(o, p, r)
		"aquatique":
			_aquatique(o, p, r)
		"cepe", "amanite":
			_champignons_des_bois(o, p, r, str(o.genre) == "amanite")
		_:
			return false
	return true


# une forme que Lisière ne sait pas dessiner : la planche d'Orvane, petite, en secours (un nœud à part : elle n'a pas d'encre)
static func _planche(o) -> void:
	if o.has_meta("planche"):
		return
	o.set_meta("planche", true)
	var boucle = Engine.get_main_loop()
	var orvane = boucle.root.get_node_or_null("Orvane") if boucle is SceneTree else null
	var tex: Texture2D = orvane.texture_plante(str(o.plante), 34.0) if orvane != null else null
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = Vector2(0, -tex.get_height() * (144.0 / 150.0 - 0.5))
	o.add_child(s)


# -- les buissons --

# un buisson d'épines : dense, anguleux, sombre, hérissé ; des prunelles bleu-noir s'il en porte
static func _epine(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var bois := P.ENCRE_DOUCE.lerp(P.TERRE, 0.35)
	for i in 4:
		var x := r.randf_range(-rx * 0.6, rx * 0.6)
		p.tracer(PackedVector2Array([Vector2(x, 1.5), Vector2(x * 1.4 + r.randf_range(-2, 2), -6.0)]), 1.4, bois)
	var centre := Vector2(0, -ry * 0.5)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.55, r.randi_range(11, 14), 0.3, r, 56, 0.25)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.38)
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.15)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.55) * 1.08)
	p.contour(poly, 1.3, ENCRE, r, 4)
	# (des rameaux qui dépassent en zigzag, et leurs épines)
	for i in r.randi_range(4, 6):
		var a := r.randf_range(-PI + 0.3, -0.3)
		var d := Vector2(cos(a), sin(a) * 0.7)
		var q0 := centre + Vector2(d.x * rx * 0.8, d.y * ry * 0.45)
		var q1 := q0 + d * r.randf_range(3.0, 6.0) + d.orthogonal() * r.randf_range(-1.5, 1.5)
		var q2 := q1 + d * r.randf_range(2.0, 4.0) - d.orthogonal() * r.randf_range(-1.5, 1.5)
		p.tracer(PackedVector2Array([q0, q1, q2]), 1.1, ENCRE, false)
		p.tracer(PackedVector2Array([q1, q1 + d.orthogonal() * 2.2 + d * 0.8]), 0.8, ENCRE)
	for i in range(0, poly.size(), 3):
		var q: Vector2 = poly[i]
		var dehors := (q - centre).normalized()
		if dehors.y > 0.55:
			continue
		p.tracer(PackedVector2Array([q - dehors * 0.5, q + dehors * 2.4 + dehors.orthogonal() * 0.9]), 0.85, ENCRE)
	if o.a_fruits:
		var prune := P.NUIT_BLEUE.lerp(P.LUNE, 0.35)
		var rb := RandomNumberGenerator.new()
		rb.seed = o.graine + 5
		for i in o.reste * 4:
			var q := centre + Vector2(rb.randf_range(-0.7, 0.7) * rx, rb.randf_range(-0.45, 0.5) * ry * 0.55)
			p.disque(q, 2.1, 2.0, ENCRE)
			p.disque(q, 1.55, 1.5, prune, Pinceau.DOME)
			p.disque(q + Vector2(-0.4, -0.5), 0.6, 0.5, Color(P.LUNE.lightened(0.5), 0.8))
	else:
		# (sans fruits : de petites fleurs blanches, éparses)
		for i in 6:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.5, 0.2) * ry * 0.55)
			p.disque(q, 1.1, 1.0, P.PAPIER.lightened(0.1))


# un roncier : des tiges arquées, rougeâtres, piquantes, qui retombent jusqu'au sol ; des mûres noires (et quelques rouges)
static func _ronce(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var tige := P.SANG.lerp(P.TERRE, 0.45)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.22)
	var centre := Vector2(0, -ry * 0.45)
	# (un fond de feuillage bas, sous les tiges)
	var fond: PackedVector2Array = o.festons(centre + Vector2(0, ry * 0.12), rx * 0.82, ry * 0.42, 8, 0.22, r, 40, 0.3)
	p.aplat(fond, t.darkened(0.12), Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5))
	p.contour(fond, 1.1, ENCRE, r, 3)
	var cannes := []
	for i in r.randi_range(5, 7):
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a := Vector2(r.randf_range(-rx * 0.35, rx * 0.35), 1.0)
		var b := Vector2(cote * r.randf_range(rx * 0.75, rx * 1.15), r.randf_range(-1.0, 2.0))
		var h := r.randf_range(ry * 0.7, ry * 1.1)
		cannes.append([a, Vector2((a.x + b.x) * 0.5, -h), b])
	for c in cannes:
		var ligne := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			ligne.append(c[0].lerp(c[1], u).lerp(c[1].lerp(c[2], u), u))
		p.tracer(ligne, 2.3, ENCRE, false)
		p.tracer(ligne, 1.3, tige, false)
		# (des épines le long, et des feuilles par trois)
		for k in range(1, 8, 2):
			var q := ligne[k]
			var d := (ligne[k + 1] - ligne[k - 1]).normalized()
			p.tracer(PackedVector2Array([q, q + d.orthogonal() * 1.8 + d * 0.6]), 0.7, ENCRE)
			if k % 4 == 1:
				for j in 3:
					var ang := d.angle() - PI * 0.5 + (j - 1) * 0.7
					var fb := q + Vector2.from_angle(ang) * 3.4
					p.disque(fb, 2.3, 1.6, ENCRE)
					p.disque(fb, 1.75, 1.15, t.lightened(0.08), Pinceau.FEUILLAGE)
	if o.reste > 0:
		var rb := RandomNumberGenerator.new()
		rb.seed = o.graine + 5
		for g in o.reste * 2:
			var c: Array = cannes[g % cannes.size()]
			var q: Vector2 = c[0].lerp(c[1], 0.7).lerp(c[1].lerp(c[2], 0.7), 0.7) + Vector2(rb.randf_range(-2.0, 2.0), rb.randf_range(0.0, 2.0))
			var mure := P.NUIT.lerp(P.SANG, 0.35) if rb.randf() < 0.75 else P.BRAISE_ROUGE
			p.disque(q, 2.4, 2.6, ENCRE)
			p.disque(q, 1.8, 2.0, mure, Pinceau.DOME)
			for k in 3:
				p.disque(q + Vector2(rb.randf_range(-0.9, 0.9), rb.randf_range(-1.1, 1.1)), 0.45, 0.45, Color(1.0, 0.92, 0.9, 0.6))


# un buisson aromatique : une boule basse, gris-vert, de tiges droites ; au bout, des épis de fleurs (lavande, ou jaunes)
static func _aromatique(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = o.teinte.lerp(P.LUNE, 0.28).lerp(P.IVOIRE, 0.18)
	var centre := Vector2(0, -ry * 0.42)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.5, r.randi_range(9, 12), 0.2, r, 44, 0.3)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.5) * 1.08)
	p.contour(poly, 1.2, ENCRE, r, 3)
	var fleur := P.PEUR.lerp(P.CREPUSCULE, 0.45) if o.graine % 2 == 0 else P.BRAISE_COEUR.darkened(0.1)
	var n := 14
	var fleuries: int = n * o.reste / maxi(1, o.plein) if o.en_fleurs else 0
	# (ce qu'on y a cueilli se voit, en fleurs ou non : des brins coupés court, leur coupe claire ; scripts/flore.gd, des aromates)
	var restent: int = n * o.reste / maxi(1, o.plein)
	for i in n:
		var x := lerpf(-rx * 0.85, rx * 0.85, (i + r.randf_range(0.2, 0.8)) / n)
		var y0 := centre.y + absf(x) / rx * ry * 0.25 - ry * 0.25
		var bout := Vector2(x * 1.15 + r.randf_range(-1.0, 1.0), y0 - r.randf_range(4.0, 8.0))
		if i >= restent:
			bout = Vector2(x, y0).lerp(bout, 0.4)
			p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 1.0, t.darkened(0.25))
			p.disque(bout, 0.8, 0.6, P.IVOIRE.lerp(t, 0.3))
			continue
		p.tracer(PackedVector2Array([Vector2(x, y0), bout]), 1.0, t.darkened(0.25))
		if i < fleuries:
			var d := (bout - Vector2(x, y0)).normalized()
			p.disque(bout - d * 1.2, 1.4, 2.6, ENCRE)
			p.disque(bout - d * 1.2, 0.95, 2.1, fleur, Pinceau.DOME)


# une bruyère : un coussin bas, ras, d'aiguilles brunes et vertes, piqué de petites fleurs rose-mauve
static func _bruyere(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var feuille := P.MOUSSE.lerp(P.TERRE, 0.4).darkened(0.12)
	var centre := Vector2(0, -ry * 0.4)
	var poly: PackedVector2Array = o.festons(centre, rx, ry * 0.62, r.randi_range(6, 8), 0.22, r, 36, 0.2)
	p.aplat(poly, feuille, Pinceau.FEUILLAGE, centre, Vector2(rx, ry * 0.62) * 1.08)
	p.contour(poly, 1.0, ENCRE, r, 3)
	for i in 10:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.4, 0.5) * ry * 0.48)
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(-1.0, 1.0), -2.4)]), 0.7, Color(ENCRE, 0.5))
	if o.en_fleurs:
		var fleur := P.CREPUSCULE.lerp(P.PEUR, 0.3).lightened(0.12)
		var nb: int = 26 * o.reste / maxi(1, o.plein)
		for i in nb:
			var q := centre + Vector2(r.randf_range(-0.85, 0.75) * rx, r.randf_range(-0.95, 0.35) * ry * 0.48)
			p.disque(q, r.randf_range(0.8, 1.3), r.randf_range(0.6, 0.95), fleur.lightened(r.randf_range(0.0, 0.25)) if q.x < 0.0 else fleur.darkened(0.08))


# une liane : enroulée autour d'un vieux tronc mort penché, ses feuilles en cœur, ses vrilles
static func _liane(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var bois := P.TERRE.lerp(P.CENDRE, 0.35)
	var pied := Vector2(r.randf_range(-2.0, 2.0), 0.5)
	var tete := Vector2(r.randf_range(3.0, 7.0) * (1.0 if o.graine % 2 == 0 else -1.0), -h)
	p.tracer(PackedVector2Array([pied, pied.lerp(tete, 0.5) + Vector2(1.0, 0), tete]), 4.6, ENCRE, false, PackedFloat32Array([5.0, 4.2, 3.0]))
	p.tracer(PackedVector2Array([pied, pied.lerp(tete, 0.5) + Vector2(1.0, 0), tete]), 3.0, bois, false, PackedFloat32Array([3.4, 2.8, 1.8]))
	var vigne := P.MOUSSE.lerp(P.TERRE, 0.3)
	var spi := PackedVector2Array()
	var tours := 3.2
	for k in 30:
		var u := k / 29.0
		var q := pied.lerp(tete, u)
		spi.append(q + Vector2(sin(u * TAU * tours) * 4.2, cos(u * TAU * tours) * 1.2))
	p.tracer(spi, 1.6, ENCRE, false)
	p.tracer(spi, 0.9, vigne, false)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1)
	var feuilles: int = 14 * maxi(o.reste, 1) / maxi(1, o.plein) if o.reste > 0 else 4
	for i in feuilles:
		var k := r.randi_range(2, 29)
		var q := spi[k] + Vector2(r.randf_range(-2.0, 2.0), r.randf_range(-1.0, 1.0))
		_coeur(p, q, r.randf_range(2.4, 3.4), r.randf_range(-0.6, 0.6) + (0.0 if q.x < tete.x * (k / 29.0) else PI * 0.2), t.lightened(r.randf_range(0.0, 0.12)))
	# (des boucles qui pendent)
	for i in 2:
		var q := spi[r.randi_range(12, 26)]
		var boucle := PackedVector2Array([q, q + Vector2(3.0 * (1 - 2 * i), 4.0), q + Vector2(1.0 * (1 - 2 * i), 8.0)])
		p.tracer(boucle, 0.9, vigne.darkened(0.15))


# une feuille en cœur, sa pointe vers ang
static func _coeur(p, q: Vector2, s: float, ang: float, c: Color) -> void:
	var poly := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var rr := s * (0.75 + 0.25 * cos(a)) * (1.0 - 0.35 * pow(maxf(0.0, -cos(a)), 6.0))
		poly.append(q + Vector2(cos(a) * rr, sin(a) * rr * 0.8).rotated(ang + PI * 0.5))
	p.aplat(_grossi(poly, q, 0.7), ENCRE)
	p.aplat(poly, c, Pinceau.FEUILLAGE, q, Vector2(s, s) * 1.1)


# un polygone, un peu agrandi depuis son centre (son liseré d'encre, dessous)
static func _grossi(poly: PackedVector2Array, centre: Vector2, de: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var d := q - centre
		out.append(q + d.normalized() * de)
	return out


# -- le sol --

# une graminée à grains : des lames, et des tiges hautes au bout desquelles l'épi pèse ; le riz : ses grains en grappes qui
# pendent, sur un sol mouillé. Mûrs (l'été, l'automne), les épis sont lourds et dorés, la touffe jaunit : on les cueille d'abord
# (des grains), et il ne reste que les tiges, coupées net ; puis la paille (une fibre), et des chaumes. Au printemps, les épis
# sont verts et droits ; l'hiver, il n'y en a plus
static func _cereale(o, p, r: RandomNumberGenerator, riz: bool) -> void:
	var h: float = o._ry
	var murs: bool = o.epis_murs
	var t: Color = o.teinte.lightened(0.05)
	var paille := t.lerp(P.IVOIRE, 0.4).lerp(P.BRAISE_COEUR, 0.15)
	if murs:
		# (la touffe mûre se dore)
		paille = paille.lerp(P.BRAISE_COEUR, 0.22).lerp(P.BRAISE, 0.08)
		t = t.lerp(paille, 0.32)
	var grain := P.BRAISE.lerp(P.IVOIRE, 0.45).darkened(0.08) if not riz else P.IVOIRE.lerp(P.BRAISE_COEUR, 0.2).darkened(0.05)
	if not murs:
		grain = t.lightened(0.18).lerp(P.MOUSSE, 0.2)
	if riz:
		p.eventail(Vector2(0, 1.5), 13.0, 3.6, Color(P.NUIT_BLEUE.lerp(P.TERRE, 0.5), 0.45), Color(P.NUIT_BLEUE, 0.0), 14)
	if o.reste <= 0:
		_chaumes(p, r, paille)
		return
	var epis: bool = o.reste >= o.plein and str(o.maturite) != ""
	# les lames
	for i in 9:
		var x0 := r.randf_range(-3.0, 3.0)
		var cote := signf(x0 + r.randf_range(-0.5, 0.5))
		var hh := r.randf_range(0.4, 0.7) * h
		var bout := Vector2(x0 * 2.0 + cote * r.randf_range(3.0, 9.0) * (1.4 if riz else 1.0), -hh * (0.75 if riz else 1.0))
		var mil := Vector2(x0 * 1.2 + bout.x * 0.3, -hh * 0.7)
		var ligne := PackedVector2Array([Vector2(x0, 1.0), mil, bout])
		p.tracer(ligne, 2.6, ENCRE, false, PackedFloat32Array([3.0, 2.2, 0.8]))
		p.tracer(ligne, 1.8, t.lerp(paille, r.randf() * 0.4).darkened(r.randf() * 0.15), false, PackedFloat32Array([2.2, 1.5, 0.4]))
	# les tiges et leurs épis : un épi dressé qui ploie au bout, ses grains en chevrons et ses barbes ; le riz, une panicule
	# qui retombe en arc, ses grains pendus dessous. Mûr, l'épi est plus lourd, et ploie davantage
	var poids := 1.0 if not murs else (1.25 if riz else 1.9)
	for i in r.randi_range(4, 6):
		var x0 := r.randf_range(-2.5, 2.5)
		var hh := h * r.randf_range(0.8, 1.05)
		var penche := r.randf_range(0.08, 0.25) * (1.0 if r.randf() < 0.5 else -1.0) * (1.0 if not murs else 1.35)
		if not epis:
			# (les épis cueillis : la tige coupée net, un peu plus bas, sa coupe claire)
			var haut := Vector2(x0 + penche * hh * 0.7, -hh * 0.78)
			var tige := PackedVector2Array([Vector2(x0, 1.0), Vector2(x0 + penche * hh * 0.3, -hh * 0.42), haut])
			p.tracer(tige, 1.7, ENCRE, false)
			p.tracer(tige, 0.9, paille, false)
			p.tracer(PackedVector2Array([haut + Vector2(-0.8, 0.3), haut + Vector2(0.8, -0.3)]), 0.6, P.IVOIRE.lightened(0.1), false)
			continue
		var bout := Vector2(x0 + penche * hh, -hh)
		var ligne := PackedVector2Array([Vector2(x0, 1.0), Vector2(x0 + penche * hh * 0.4, -hh * 0.55), bout])
		p.tracer(ligne, 1.7, ENCRE, false)
		p.tracer(ligne, 0.9, paille, false)
		var dir := (bout - ligne[1]).normalized()
		var epi := PackedVector2Array([bout])
		for k in range(1, (8 if riz else 6) + (1 if murs else 0)):
			var u := float(k)
			# (le poids du grain le fait ployer ; le riz, jusqu'à pendre)
			epi.append(bout + dir * u * (1.6 if riz else 1.5) + Vector2(signf(penche) * u * u * (0.12 if riz else 0.05) * poids, u * u * (0.22 if riz else 0.04) * poids))
		p.tracer(epi, 1.2, ENCRE, false)
		for k in range(1, epi.size()):
			var q := epi[k]
			var d := (epi[k] - epi[k - 1]).normalized()
			var nrm := d.orthogonal()
			if riz:
				var g := q + Vector2(0, 1.4)
				p.disque(g, 1.0, 1.35, ENCRE)
				p.disque(g, 0.65, 0.95, grain, Pinceau.DOME)
				continue
			for cote in [-1.0, 1.0]:
				var g: Vector2 = q + nrm * cote * (0.9 if murs else 0.7)
				var gr := 1.0 if murs else 0.8
				p.disque(g, 1.25 * gr, 1.25 * gr, ENCRE)
				p.disque(g, 0.85 * gr, 0.85 * gr, grain, Pinceau.DOME)
				# (les barbes)
				p.tracer(PackedVector2Array([g, g + nrm * cote * 1.2 + d * 3.2]), 0.45, Color(ENCRE, 0.6))


# ce qui reste d'une touffe coupée : des chaumes
static func _chaumes(p, r: RandomNumberGenerator, paille: Color) -> void:
	p.eventail(Vector2(0, 1), 7.0, 2.8, Color(P.TERRE.darkened(0.3), 0.6), Color(P.TERRE.darkened(0.3), 0.0), 12)
	for i in 7:
		var x := r.randf_range(-4.5, 4.5)
		p.tracer(PackedVector2Array([Vector2(x, 1), Vector2(x + r.randf_range(-1, 1), -r.randf_range(2.5, 4.5))]), 1.2, paille.darkened(0.2), false)


# un jonc : un faisceau de tiges rondes, droites, vert sombre ; une petite grappe brune sur le côté
static func _jonc(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.3)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	var tiges := []
	for i in 16:
		var x0 := r.randf_range(-3.0, 3.0)
		tiges.append([x0, Vector2(x0 * 2.2 + r.randf_range(-1.5, 1.5), -h * r.randf_range(0.75, 1.05)), r.randf()])
	tiges.sort_custom(func(a, b): return a[2] < b[2])
	for i in tiges.size():
		var tg: Array = tiges[i]
		var ligne := PackedVector2Array([Vector2(tg[0], 1.0), tg[1]])
		p.tracer(ligne, 2.0, ENCRE, false, PackedFloat32Array([2.0, 1.0]))
		p.tracer(ligne, 1.1, t.lightened(0.18 * tg[2]), false, PackedFloat32Array([1.2, 0.4]))
	for i in 2:
		var tg: Array = tiges[tiges.size() - 1 - i * 3]
		var q: Vector2 = Vector2(tg[0], 1.0).lerp(tg[1], 0.68) + Vector2(1.6, 0)
		for k in 4:
			var g := q + Vector2(r.randf_range(0.0, 2.5), r.randf_range(-1.5, 1.5))
			p.disque(g, 1.2, 1.2, ENCRE)
			p.disque(g, 0.8, 0.8, P.TERRE.lerp(P.BRAISE, 0.2))


# un papyrus : de hautes tiges nues, chacune coiffée d'une ombelle de fins rayons
static func _papyrus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lightened(0.06)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	for i in r.randi_range(5, 7):
		var x0 := r.randf_range(-4.0, 4.0)
		var hh := h * r.randf_range(0.7, 1.0)
		var bout := Vector2(x0 * 1.8 + r.randf_range(-3.0, 3.0), -hh)
		p.tracer(PackedVector2Array([Vector2(x0, 1.0), bout]), 1.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(x0, 1.0), bout]), 1.1, t.darkened(0.12), false)
		for k in 14:
			var a := -PI * 0.5 + (k / 13.0 - 0.5) * PI * 1.5
			var l := r.randf_range(5.0, 8.0)
			var q := bout + Vector2(cos(a) * l, sin(a) * l * 0.6 + l * 0.25 * absf(cos(a)))
			p.tracer(PackedVector2Array([bout, q]), 0.75, t.lightened(0.18) if k % 2 == 0 else t, false)


# un bambou : des cannes droites, nouées d'encre, vert-jaune ; des feuilles en lance aux nœuds du haut. Coupé, des moignons
static func _bambou(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var canne: Color = o.teinte.lerp(P.BRAISE_COEUR, 0.22).lightened(0.05)
	var t: Color = o.teinte.lerp(P.FEUILLE_SOMBRE, 0.1)
	var n := 5
	var debout: int = n - (o.plein - o.reste) * 2
	for i in n:
		var x0 := lerpf(-6.0, 6.0, (i + r.randf_range(0.2, 0.8)) / n)
		var hh := h * r.randf_range(0.7, 1.0)
		var w := r.randf_range(1.5, 2.1)
		var penche := r.randf_range(-0.05, 0.05)
		if i >= debout:
			# (une canne coupée en biseau)
			var cut := r.randf_range(4.0, 7.0)
			var poly := PackedVector2Array([Vector2(x0 - w, 1), Vector2(x0 + w, 1), Vector2(x0 + w, -cut + 1.5), Vector2(x0 - w, -cut)])
			p.aplat(poly, canne.darkened(0.08), Pinceau.ECORCE, Vector2(x0, -cut * 0.5), Vector2(w, cut))
			p.contour(poly, 0.9, ENCRE, r, 2)
			p.tracer(PackedVector2Array([Vector2(x0 - w, -cut), Vector2(x0 + w, -cut + 1.5)]), 0.8, P.IVOIRE)
			continue
		var bout := Vector2(x0 + penche * hh, -hh)
		var poly := PackedVector2Array([Vector2(x0 - w, 1), Vector2(x0 + w, 1), bout + Vector2(w * 0.6, 0), bout - Vector2(w * 0.6, 0)])
		p.aplat(poly, canne, Pinceau.ECORCE, Vector2(x0 + penche * hh * 0.5, -hh * 0.5), Vector2(w * 1.1, hh * 0.55))
		p.tracer(PackedVector2Array([Vector2(x0 - w, 1), bout - Vector2(w * 0.6, 0)]), 0.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(x0 + w, 1), bout + Vector2(w * 0.6, 0)]), 1.3, ENCRE, false)
		var y := -r.randf_range(7.0, 10.0)
		while y > -hh + 3.0:
			var q := Vector2(x0 + penche * -y, y)
			p.tracer(PackedVector2Array([q - Vector2(w + 0.3, 0), q + Vector2(w + 0.3, 0.5)]), 0.9, ENCRE, false)
			if y < -hh * 0.45 and r.randf() < 0.7:
				var cote := -1.0 if r.randf() < 0.5 else 1.0
				for k in 3:
					var a := Vector2(cote * r.randf_range(4.0, 8.0), r.randf_range(-2.0, 3.5))
					_lance(p, q, q + a, 1.3, t.lightened(r.randf_range(0.0, 0.15)))
			y -= r.randf_range(8.0, 11.0)


# une feuille en lance, de a à b
static func _lance(p, a: Vector2, b: Vector2, larg: float, c: Color) -> void:
	var d := b - a
	var n := d.orthogonal().normalized() * larg
	var poly := PackedVector2Array([a, a + d * 0.35 + n, b, a + d * 0.35 - n])
	p.aplat(PackedVector2Array([a - d.normalized() * 0.4, a + d * 0.35 + n * 1.5, b + d.normalized() * 0.6, a + d * 0.35 - n * 1.5]), ENCRE)
	p.aplat(poly, c)


# une légumineuse : basse, des feuilles par trois, des gousses qui pendent, quelques fleurs en papillon
static func _legumineuse(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var t: Color = o.teinte.lightened(0.04)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.IVOIRE, 0.3))
		return
	var tiges := []
	for i in 6:
		var a := Vector2(r.randf_range(-2.0, 2.0), 1.0)
		var b := Vector2(r.randf_range(-rx, rx), -r.randf_range(ry * 0.5, ry))
		tiges.append([a, b])
		p.tracer(PackedVector2Array([a, (a + b) * 0.5 + Vector2(0, -1.5), b]), 1.0, t.darkened(0.3))
	for tg in tiges:
		var q: Vector2 = tg[1]
		for j in 3:
			var fb: Vector2 = q + Vector2.from_angle(-PI * 0.5 + (j - 1) * 1.0) * 2.4
			p.disque(fb, 2.0, 1.6, ENCRE)
			p.disque(fb, 1.5, 1.15, t.lightened(0.06 * j), Pinceau.FEUILLAGE)
	for i in 3:
		var tg: Array = tiges[i * 2]
		var q: Vector2 = (tg[0] + tg[1]) * 0.5
		var gousse := PackedVector2Array([q, q + Vector2(2.5, 1.5), q + Vector2(4.5, 4.0)])
		p.tracer(gousse, 2.6, ENCRE)
		p.tracer(gousse, 1.7, t.lerp(P.BRAISE_COEUR, 0.25))
	for i in 3:
		var q: Vector2 = tiges[i * 2 + 1][1] + Vector2(0, -2.5)
		p.disque(q, 1.5, 1.2, ENCRE)
		p.disque(q, 1.1, 0.85, P.PAPIER if o.graine % 2 == 0 else P.PEUR.lerp(P.PAPIER, 0.4))


# une fougère : des frondes qui partent du pied en couronne, dentées de folioles
static func _fougere(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.4).lightened(0.08)
	if o.reste <= 0:
		_chaumes(p, r, t.lerp(P.TERRE, 0.4))
		return
	var frondes := []
	var n := r.randi_range(6, 8)
	for i in n:
		frondes.append([lerpf(-PI + 0.35, -0.35, float(i) / (n - 1)) + r.randf_range(-0.12, 0.12), r.randf_range(0.8, 1.1) * h])
	frondes.append([r.randf_range(0.25, 0.5), h * 0.6])
	frondes.append([PI - r.randf_range(0.25, 0.5), h * 0.6])
	frondes.sort_custom(func(a, b): return sin(a[0]) < sin(b[0]))
	for fr in frondes:
		_fronde(p, Vector2(0, -1.5), fr[0], fr[1], 4.4, t)


# une fronde de fougère, de son pied le long de l'angle a (aplatie par la vue de biais)
static func _fronde(p, pied: Vector2, a: float, l: float, larg: float, t: Color) -> void:
	var m := 9
	var d := Vector2(cos(a), sin(a) * 0.62)
	var axe := PackedVector2Array()
	for k in m + 1:
		var u := float(k) / m
		axe.append(pied + d * l * u + Vector2(0, -l * 0.32 * sin(u * PI * 0.85) + u * u * 2.0))
	for passe in 2:
		var e := 0.55 if passe == 0 else 0.0
		var g := PackedVector2Array()
		var dr := PackedVector2Array()
		for k in m + 1:
			var u := float(k) / m
			var tan_ := (axe[mini(k + 1, m)] - axe[maxi(k - 1, 0)]).normalized()
			var nrm := tan_.orthogonal()
			var w := larg * sin(PI * minf(1.0, u * 1.2 + 0.08)) * (1.0 - u * 0.7) * (1.0 if k % 2 == 0 else 0.6) + e
			var avance := tan_ * (1.0 if k % 2 == 0 else 0.0)
			g.append(axe[k] + nrm * w + avance)
			dr.append(axe[k] - nrm * w + avance)
		if passe == 0:
			p.bande(g, dr, Color(ENCRE, 0.7))
		else:
			var face := t.lerp(t.lightened(0.2), clampf(-sin(a), 0.0, 1.0) * 0.6 + 0.2)
			p.bande(g, axe, face)
			p.bande(axe, dr, face.darkened(0.2))


# une plante en coussin : un dôme serré, ras, piqué de toutes petites fleurs ; poudré de neige s'il fait froid
static func _coussin(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry * 0.85
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.3)
	var centre := Vector2(0, -ry * 0.6)
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(9, 12), 0.08, r, 40, 0.15)
	if o.reste <= 0:
		t = t.lerp(P.TERRE, 0.25)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	p.contour(poly, 1.1, ENCRE, r, 3)
	for i in 12:
		var q := centre + Vector2(r.randf_range(-0.8, 0.8) * rx, r.randf_range(-0.6, 0.6) * ry)
		p.disque(q, 0.5, 0.5, Color(ENCRE, 0.35))
	if o.reste > 0:
		var fleur := P.PAPIER.lightened(0.1) if o.graine % 3 != 0 else P.PEUR.lerp(P.PAPIER, 0.5)
		for i in 10:
			var q := centre + Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.8, 0.2) * ry)
			p.disque(q, 0.85, 0.75, fleur)
	if float(o._climat.get("froid", 0.0)) > 0.25:
		o._neige_sur(p, poly, centre + Vector2(0, -ry * 0.4), rx * 0.8, ry * 0.5, centre.y - ry * 0.25, r)


# une mousse : des coussinets ras, d'un vert vif, serrés les uns contre les autres
static func _mousse(o, p, r: RandomNumberGenerator) -> void:
	var t := P.MOUSSE.lightened(0.12).lerp(o.teinte, 0.3)
	for i in r.randi_range(3, 5):
		var q := Vector2(r.randf_range(-0.6, 0.6) * o._rx, r.randf_range(-0.4, 0.5) * o._ry)
		var rx := r.randf_range(3.5, 6.0)
		var poly: PackedVector2Array = o.festons(q + Vector2(0, -1.0), rx, rx * 0.5, 6, 0.2, r, 20, 0.2)
		p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25)), Pinceau.FEUILLAGE, q + Vector2(0, -1.0), Vector2(rx, rx * 0.5) * 1.1)
		p.contour(poly, 0.7, Color(ENCRE, 0.7), r, 2)


# un lichen, à plat : des rosettes de croûte (jaune, vert pâle, orangée) sur une plaque grise ; en croûte, sur une pierre
static func _lichen(o, p, r: RandomNumberGenerator, croute: bool) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var gris := P.CENDRE.lerp(P.IVOIRE, 0.55)
	if croute:
		# (une pierre plate, la croûte dessus)
		var pierre: PackedVector2Array = o.festons(Vector2(0, -2.0), rx * 0.9, ry * 0.9, 5, 0.15, r, 18, 0.1)
		p.aplat(pierre, gris, Pinceau.PIERRE, Vector2(0, -2.0), Vector2(rx, ry))
		p.contour(pierre, 1.0, ENCRE, r, 2)
	else:
		var plaque: PackedVector2Array = o.festons(Vector2.ZERO, rx, ry, 7, 0.25, r, 26, 0.0)
		p.aplat(plaque, Color(gris.darkened(0.15), 0.85))
		p.contour(plaque, 0.7, Color(ENCRE, 0.45), r, 3)
	var tons := [P.BRAISE_COEUR.darkened(0.12), P.IVOIRE.lerp(P.MOUSSE, 0.3), P.BRAISE.darkened(0.1)]
	for i in r.randi_range(6, 10):
		var q := Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.6, 0.6) * ry - (2.0 if croute else 0.0))
		var s := r.randf_range(1.2, 2.6)
		var c: Color = tons[0 if croute and r.randf() < 0.6 else r.randi() % tons.size()]
		p.disque(q, s, s * 0.6, c)
		p.disque(q, s * 0.4, s * 0.25, c.darkened(0.3))


# le lichen des rennes : un coussin pâle, gris-vert, fait de petites boules ramifiées (un chou-fleur de corail) ; brouté ou
# cueilli, il n'en reste qu'une galette
static func _lichen_rennes(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry * (1.0 if o.reste > 0 else 0.45)
	var pale := P.IVOIRE.lerp(P.LUNE, 0.22).lerp(P.MOUSSE, 0.3).darkened(0.04)
	var centre := Vector2(0, -ry * 0.55)
	var poly: PackedVector2Array = o.festons(centre, rx, ry, r.randi_range(10, 13), 0.18, r, 44, 0.12)
	p.aplat(poly, pale.darkened(0.18), Pinceau.FEUILLAGE, centre, Vector2(rx, ry) * 1.05)
	var boules := []
	# (cueilli d'une poignée, il en manque un pan ; tout cueilli, une galette)
	for i in (22 if o.reste >= o.plein else (14 if o.reste > 0 else 8)):
		var a := r.randf() * TAU
		var d := sqrt(r.randf())
		boules.append(centre + Vector2(cos(a) * rx * 0.8 * d, sin(a) * ry * 0.75 * d - (1.0 - d) * 1.5))
	boules.sort_custom(func(u, v): return u.y < v.y)
	for q in boules:
		var s0 := r.randf_range(1.4, 2.2)
		p.disque(q, s0 + 0.45, s0 * 0.85 + 0.45, Color(ENCRE, 0.55))
		p.disque(q, s0, s0 * 0.85, pale.lerp(P.IVOIRE, r.randf_range(0.0, 0.25)) if q.x < 0.0 else pale.darkened(r.randf_range(0.0, 0.12)), Pinceau.DOME)
	p.contour(poly, 1.0, ENCRE, r, 3)


# une plante grasse : une rosette de feuilles charnues en cuillère, glauques, bordées de rose, vue de biais : celles du fond
# se dressent, celles de devant s'étalent vers nous ; cueillie, une rosette plus petite
static func _succulente(o, p, r: RandomNumberGenerator) -> void:
	var k: float = 1.0 if o.reste >= o.plein else 0.65
	var rx: float = (o._rx + 2.0) * k
	# (le vert glauque d'une plante grasse, que le lieu teinte à peine : sur la terre sèche, elle ne pâlit pas en caillou)
	var t: Color = P.MOUSSE.lerp(P.LUNE, 0.24).darkened(0.04).lerp(o.teinte, 0.15)
	var bord := P.BRAISE_ROUGE.lerp(P.PEUR, 0.35).lightened(0.1)
	var c0 := Vector2(0, -4.0 * k)
	var feuilles := []
	for anneau in 2:
		var n := 9 if anneau == 0 else 6
		for i in n:
			var a := TAU * i / n + r.randf_range(-0.12, 0.12) + anneau * 0.3
			feuilles.append([a, (1.0 if anneau == 0 else 0.62) * r.randf_range(0.85, 1.0), anneau])
	# (de l'arrière vers l'avant ; le cœur, plus haut, par-dessus)
	feuilles.sort_custom(func(u, v): return sin(u[0]) + u[2] * 3.0 < sin(v[0]) + v[2] * 3.0)
	for fe in feuilles:
		var a: float = fe[0]
		var l: float = rx * float(fe[1])
		var leve := 3.5 if fe[2] == 1 else 1.5
		var bout := c0 + Vector2(cos(a) * l, sin(a) * l * 0.45 - leve * (1.0 - sin(a) * 0.5))
		var d := bout - c0
		var nrm := d.orthogonal().normalized() * (3.0 + 1.2 * float(fe[1])) * k
		var poly := PackedVector2Array([c0 + nrm * 0.3, c0 + d * 0.45 + nrm * 0.9, c0 + d * 0.8 + nrm * 0.85, bout, c0 + d * 0.8 - nrm * 0.85, c0 + d * 0.45 - nrm * 0.9, c0 - nrm * 0.3])
		var face := t.lerp(t.darkened(0.3), clampf(sin(a), 0.0, 1.0) * 0.45).lightened(0.06 * float(fe[2]))
		p.aplat(_grossi(poly, c0 + d * 0.5, 0.75), ENCRE)
		p.aplat(poly, face, Pinceau.DOME, c0 + d * 0.55, Vector2(d.length() * 0.6, nrm.length() * 1.2 + 0.5))
		p.tracer(PackedVector2Array([c0 + d * 0.8 + nrm * 0.75, bout, c0 + d * 0.8 - nrm * 0.75]), 0.8, bord, false)


# un agave : une grande rosette de feuilles raides, en lames, bleu-vert, chacune armée d'un dard noir et de dents
static func _agave(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx * (1.0 if o.reste > 0 else 0.6)
	var h: float = o._ry * (1.0 if o.reste > 0 else 0.6)
	var t: Color = P.MOUSSE.lerp(P.LUNE, 0.38).lightened(0.06).lerp(o.teinte, 0.2)
	var feuilles := []
	for i in 12:
		var a := lerpf(-PI + 0.1, -0.1, i / 11.0) + r.randf_range(-0.08, 0.08)
		feuilles.append([a, r.randf_range(0.7, 1.0), 0])
	for i in 4:
		feuilles.append([r.randf_range(0.3, 2.8), r.randf_range(0.45, 0.65), 1])
	feuilles.sort_custom(func(a, b): return sin(a[0]) < sin(b[0]))
	var c0 := Vector2(0, -2.0)
	for fe in feuilles:
		var a: float = fe[0]
		var l: float = float(fe[1])
		var bout := c0 + Vector2(cos(a) * rx * l, sin(a) * h * l if a < 0.0 else sin(a) * 3.0 * l)
		var d := bout - c0
		var nrm := d.orthogonal().normalized() * 2.6
		var poly := PackedVector2Array([c0 + nrm, c0 + d * 0.45 + nrm * 0.8, bout, c0 + d * 0.45 - nrm * 0.8, c0 - nrm])
		var face := t.lerp(t.lightened(0.18), clampf(-cos(a) * 0.5 + 0.3, 0.0, 1.0)).darkened(0.12 * float(fe[2]))
		p.aplat(_grossi(poly, c0 + d * 0.45, 0.75), ENCRE)
		p.aplat(poly, face)
		p.tracer(PackedVector2Array([c0, bout - d * 0.08]), 0.6, face.darkened(0.3), false)
		# (le dard, et des dents le long du bord)
		p.tracer(PackedVector2Array([bout - d.normalized() * 1.0, bout + d.normalized() * 2.2]), 1.2, ENCRE)
		for k in [0.35, 0.6]:
			var q: Vector2 = c0 + d * k + nrm * (0.9 - k * 0.3)
			p.tracer(PackedVector2Array([q, q + nrm.normalized() * 1.2 + d.normalized() * 0.5]), 0.6, ENCRE)


# un cactus en candélabre : une colonne côtelée, un ou deux bras qui se relèvent, des aréoles épineuses. Entamé, un bras en moins
# (ou une tranche de la colonne) : sa chair à nu, pâle et mouillée, d'où perle une goutte ; c'est sa pulpe qu'on emporte
static func _cactus(o, p, r: RandomNumberGenerator) -> void:
	var h: float = o._ry
	var w: float = o._rx
	var t: Color = P.MOUSSE.lerp(P.LUNE, 0.12).lerp(o.teinte, 0.3)
	var bras := []
	var nb := 2 if o.graine % 3 != 0 else 1
	var entames: int = int(o.plein) - int(o.reste)
	var tous := nb
	nb = maxi(0, nb - entames)
	var racines := []
	for i in tous:
		var cote := -1.0 if (i + o.graine) % 2 == 0 else 1.0
		var b := [cote, r.randf_range(0.3, 0.55) * h, r.randf_range(0.6, 0.85) * h, r.randf_range(w * 1.8, w * 2.6)]
		racines.append(b)
		if i < nb:
			bras.append(b)
	# (les bras derrière la colonne d'abord, du côté de l'ombre)
	for b in bras:
		_bras_cactus(p, r, b, w * 0.72, t.darkened(0.06))
	_colonne(p, r, Vector2.ZERO, w, h, t)
	var chair := P.IVOIRE.lerp(P.MOUSSE, 0.32).lightened(0.06)
	for k in entames:
		# (là où un bras a été coupé, à sa racine ; sans bras qui reste, une tranche prise au flanc de la colonne)
		var i_bras := tous - 1 - k
		var cote := -1.0 if (i_bras + o.graine) % 2 == 0 else 1.0
		var q: Vector2
		var face: PackedVector2Array
		if i_bras >= 0:
			# (le bras coupé à sa racine : un moignon qui sort du flanc, sa coupe tournée vers le dehors)
			var y := -float(racines[i_bras][1])
			var ep := w * 0.62
			var a := Vector2(cote * w * 0.7, y)
			q = Vector2(cote * (w + 3.2), y - 0.6)
			p.tracer(PackedVector2Array([a, q]), ep * 2.0 + 1.4, ENCRE, false)
			p.tracer(PackedVector2Array([a, q]), ep * 2.0, t.darkened(0.06), false)
			face = Pinceau.ellipse(q, 1.9, ep * 0.95, 14)
		else:
			# (une tranche prise au flanc de la colonne, plus bas : une coupe en biais)
			q = Vector2(-w * 0.3, -h * 0.24)
			face = Pinceau.ellipse(q, 3.3, 2.6, 14)
			for n in face.size():
				face[n] = q + (face[n] - q).rotated(-0.35)
		p.aplat(_grossi(face, q, 0.75), ENCRE)
		p.aplat(face, chair, Pinceau.DOME, q, Vector2(3.0, 3.0))
		# (la peau autour, ses fibres vertes ; la chair, ses points ; une goutte qui perle et coule)
		p.tracer(Pinceau.ellipse(q, 2.2, 1.6, 12), 0.45, Color(P.MOUSSE.darkened(0.2), 0.7), false)
		p.disque(q + Vector2(-0.5, -0.3), 0.3, 0.3, Color(P.MOUSSE.darkened(0.35), 0.8))
		p.disque(q + Vector2(0.6, 0.2), 0.25, 0.25, Color(P.MOUSSE.darkened(0.35), 0.8))
		var goutte := q + Vector2(cote * 0.4, 2.6 + float(o.graine % 3))
		p.tracer(PackedVector2Array([q + Vector2(cote * 0.3, 1.5), goutte]), 0.5, Color(P.ECHO.lerp(P.PAPIER, 0.4), 0.7), false)
		p.disque(goutte, 0.55, 0.65, Color(P.ECHO.lerp(P.PAPIER, 0.3), 0.85))


static func _colonne(p, r: RandomNumberGenerator, pied: Vector2, w: float, h: float, t: Color) -> void:
	var poly := PackedVector2Array([pied + Vector2(-w, 1.0)])
	for i in 9:
		var a := PI + PI * i / 8.0
		poly.append(pied + Vector2(cos(a) * w, -h + w + sin(a) * w))
	poly.append(pied + Vector2(w, 1.0))
	p.aplat(poly, t, Pinceau.ECORCE, pied + Vector2(0, -h * 0.5), Vector2(w * 1.05, h * 0.55))
	p.contour(poly, 1.3, ENCRE, r, 3)
	for k in [-0.5, 0.0, 0.5]:
		var x: float = pied.x + w * k
		var cote := Vector2(x, pied.y - 1.0)
		p.tracer(PackedVector2Array([cote, Vector2(x * 0.92 + pied.x * 0.08, pied.y - h + w * (0.4 + absf(k)))]), 0.7, Color(ENCRE, 0.55), false)
		var y := pied.y - 4.0
		while y > pied.y - h + w:
			p.disque(Vector2(x + 0.6, y), 0.55, 0.5, P.PAPIER.lightened(0.1))
			y -= r.randf_range(4.0, 6.0)


static func _bras_cactus(p, r: RandomNumberGenerator, b: Array, w: float, t: Color) -> void:
	var cote: float = b[0]
	var y0 := -float(b[1])
	var y1 := -float(b[2])
	var x1 := cote * float(b[3])
	# (le coude : il part de la colonne à l'horizontale, puis se relève)
	var coude := PackedVector2Array()
	for k in 7:
		var u := k / 6.0
		var a := PI * 0.5 * u
		coude.append(Vector2(lerpf(0.0, x1, sin(a)), y0 - (1.0 - cos(a)) * (x1 * cote) * 0.5))
	var g := PackedVector2Array()
	var d := PackedVector2Array()
	for k in coude.size():
		var tan_ := (coude[mini(k + 1, 6)] - coude[maxi(k - 1, 0)]).normalized()
		g.append(coude[k] + tan_.orthogonal() * w)
		d.append(coude[k] - tan_.orthogonal() * w)
	p.bande(g, d, Color(ENCRE, 0.9))
	var g2 := PackedVector2Array()
	var d2 := PackedVector2Array()
	for k in coude.size():
		var tan_ := (coude[mini(k + 1, 6)] - coude[maxi(k - 1, 0)]).normalized()
		g2.append(coude[k] + tan_.orthogonal() * (w - 1.0))
		d2.append(coude[k] - tan_.orthogonal() * (w - 1.0))
	p.bande(g2, d2, t)
	var haut_du_coude := coude[6]
	_colonne(p, r, Vector2(haut_du_coude.x, haut_du_coude.y + w * 0.5), w, maxf(6.0, haut_du_coude.y - y1 + w * 0.5), t)


# une plante-caillou : des paires de feuilles rondes, couleur de pierre, fendues au milieu, parmi des cailloux
static func _plante_caillou(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var pierre := P.IVOIRE.lerp(P.CENDRE, 0.25)
	for i in r.randi_range(3, 5):
		var q := Vector2(r.randf_range(-rx, rx), r.randf_range(-1.5, 2.5))
		var s := r.randf_range(1.2, 2.2)
		p.disque(q, s + 0.5, s * 0.75 + 0.5, ENCRE)
		p.disque(q, s, s * 0.75, pierre.darkened(r.randf_range(0.0, 0.2)), Pinceau.PIERRE)
	for i in r.randi_range(2, 4):
		var q := Vector2(r.randf_range(-0.6, 0.6) * rx, r.randf_range(-1.0, 1.0))
		var s := r.randf_range(2.6, 3.4)
		var t := pierre.lerp(P.BRAISE, 0.12).lerp(o.teinte, 0.15)
		p.disque(q + Vector2(0, -s * 0.4), s + 0.6, s * 0.7 + 0.6, ENCRE)
		p.disque(q + Vector2(0, -s * 0.4), s, s * 0.7, t, Pinceau.DOME)
		p.tracer(PackedVector2Array([q + Vector2(-s * 0.85, -s * 0.4), q + Vector2(0, -s * 0.3), q + Vector2(s * 0.85, -s * 0.45)]), 0.8, ENCRE, false)
		for k in 3:
			p.disque(q + Vector2(r.randf_range(-0.6, 0.6) * s, -s * 0.4 - r.randf_range(0.2, 0.5) * s * 0.7), 0.5, 0.4, Color(P.ENCRE_DOUCE, 0.6))


# -- les fleurs : celles des prés (de Lisière), celles de l'herbier (une fleur, un bulbe, une orchidée, une broméliacée) --

static func _fleurs(o, p, r: RandomNumberGenerator) -> void:
	var couleur: Color = o.couleur_fleur if o.couleur_fleur.a > 0.0 else P.PAPIER
	var vert: Color = o.teinte.lerp(P.MOUSSE, 0.35).lightened(0.04)
	var pousse := 1.0 - clampf(o._repousse / maxf(1.0, o._attente()), 0.0, 1.0) if o._repousse > 0.0 else 1.0
	var la: bool = o.reste > 0 and o.en_fleurs
	var u := 1.0 if la else (0.4 if pousse < 0.5 else 0.75)
	match str(o.forme):
		"bulbe":
			_bulbes(o, p, r, couleur, vert, la, u)
		"orchidee":
			_orchidees(o, p, r, couleur, vert, la, u)
		"bromelia":
			_bromelia(o, p, r, couleur, vert, la, u)
		_:
			_pres(o, p, r, couleur, vert, la, u, pousse)


# une colonie de fleurs des prés : des tiges grêles, une feuille ou deux, une corolle de cinq pétales ; l'herbier en fait des
# marguerites (plus hautes, plus de pétales). Cueillies : les tiges coupées ; puis les boutons, verts, qui reviennent
static func _pres(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float, pousse: float) -> void:
	var herbier := str(o.forme) == "fleur"
	var n := r.randi_range(4, 6) if herbier else r.randi_range(6, 9)
	var tetes := []
	for i in n:
		var pied := Vector2(r.randf_range(-o._rx, o._rx), r.randf_range(-o._ry, o._ry))
		var h := r.randf_range(0.6, 1.0) * float(o.hauteur) * (1.25 if herbier else 1.0) * u
		var bout := pied + Vector2(r.randf_range(-2.0, 2.0), -h)
		tetes.append([pied, bout, r.randf()])
	tetes.sort_custom(func(a, b): return a[0].y < b[0].y)
	for t in tetes:
		var pied: Vector2 = t[0]
		var bout: Vector2 = t[1]
		var mil := pied.lerp(bout, 0.5) + Vector2(r.randf_range(-1.0, 1.0), 0)
		p.tracer(PackedVector2Array([pied, mil, bout]), 1.6, Color(ENCRE, 0.8), false)
		p.tracer(PackedVector2Array([pied, mil, bout]), 0.8, vert.darkened(0.15), false)
		_lance(p, pied + Vector2(0, -0.5), pied + Vector2(r.randf_range(2.5, 4.0) * (1.0 if t[2] < 0.5 else -1.0), -r.randf_range(2.0, 3.5)), 1.0, vert)
		if la:
			var rc := 2.6 if herbier else r.randf_range(1.8, 2.4)
			var np := 9 if herbier else 5
			p.disque(bout, rc + 0.8, (rc + 0.8) * 0.82, ENCRE)
			for k in np:
				var a := TAU * k / np + float(t[2]) * 2.0
				var q := bout + Vector2(cos(a), sin(a) * 0.82) * rc * 0.55
				p.disque(q, rc * (0.38 if herbier else 0.55), rc * (0.3 if herbier else 0.48), couleur.lightened(0.08) if sin(a) < 0.0 else couleur.darkened(0.06))
			var coeur := P.BRAISE_COEUR.darkened(0.1) if couleur.v > 0.8 and couleur.s < 0.3 else P.ENCRE_DOUCE.lerp(P.BRAISE, 0.4)
			p.disque(bout, rc * 0.36, rc * 0.3, coeur, Pinceau.DOME)
		elif pousse >= 0.5 or not o.en_fleurs:
			# (des boutons, verts, qui reviendront)
			p.disque(bout, 1.2, 1.4, ENCRE)
			p.disque(bout, 0.8, 1.0, vert.lightened(0.15))
		else:
			# (coupée : la tige claire à la coupe)
			p.disque(bout, 0.6, 0.5, P.IVOIRE)


# des fleurs à bulbe : de longues feuilles en ruban qui retombent, une ou deux coupes de fleurs sur leurs hampes
static func _bulbes(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	for pied_i in r.randi_range(2, 3):
		var pied := Vector2(r.randf_range(-o._rx * 0.6, o._rx * 0.6), r.randf_range(-o._ry * 0.5, o._ry * 0.5))
		for i in 4:
			var cote := -1.0 if i % 2 == 0 else 1.0
			var h := r.randf_range(6.0, 10.0) * u
			var ligne := PackedVector2Array([pied, pied + Vector2(cote * 1.5, -h * 0.75), pied + Vector2(cote * r.randf_range(3.0, 5.0), -h)])
			p.tracer(ligne, 2.6, ENCRE, false, PackedFloat32Array([2.6, 2.2, 0.8]))
			p.tracer(ligne, 1.7, vert, false, PackedFloat32Array([1.8, 1.4, 0.3]))
		var hh := r.randf_range(11.0, 15.0) * u
		var bout := pied + Vector2(r.randf_range(-1.5, 1.5), -hh)
		p.tracer(PackedVector2Array([pied, bout]), 1.6, ENCRE, false)
		p.tracer(PackedVector2Array([pied, bout]), 0.9, vert.darkened(0.12), false)
		if la:
			# (la coupe : trois pétales, celui du milieu devant)
			var coupe := PackedVector2Array([bout + Vector2(-2.6, 0.5), bout + Vector2(-3.0, -3.0), bout + Vector2(-1.2, -2.0), bout + Vector2(0, -4.2),
				bout + Vector2(1.2, -2.0), bout + Vector2(3.0, -3.0), bout + Vector2(2.6, 0.5), bout + Vector2(0, 1.6)])
			p.aplat(_grossi(coupe, bout + Vector2(0, -1.2), 0.75), ENCRE)
			p.aplat(coupe, couleur, Pinceau.DOME, bout + Vector2(0, -1.4), Vector2(3.2, 3.2))
			p.tracer(PackedVector2Array([bout + Vector2(0, -4.0), bout + Vector2(0, 0.8)]), 0.6, Color(couleur.darkened(0.35), 0.8))
		else:
			p.disque(bout, 1.1, 1.6, ENCRE)
			p.disque(bout, 0.7, 1.1, vert.lightened(0.15))


# des orchidées : quelques larges feuilles au pied, une hampe arquée, des fleurs en lèvre le long
static func _orchidees(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	for i in 3:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a := Vector2(0, 0)
		var b := Vector2(cote * r.randf_range(6.0, 9.0), -r.randf_range(2.0, 4.0))
		_lance(p, a, b, 2.4, vert.lightened(0.05 * i))
	var hampe := PackedVector2Array()
	var sens := 1.0 if o.graine % 2 == 0 else -1.0
	for k in 7:
		var t := k / 6.0
		hampe.append(Vector2(sens * 7.0 * t * t, -16.0 * u * sin(t * PI * 0.6) / sin(PI * 0.6)))
	p.tracer(hampe, 1.5, ENCRE, false)
	p.tracer(hampe, 0.8, vert.darkened(0.2), false)
	for k in range(3, 7):
		var q := hampe[k] + Vector2(0, 1.5)
		if not la:
			p.disque(q, 1.0, 1.3, vert.lightened(0.1))
			continue
		for j in 3:
			var a := -PI * 0.5 + (j - 1) * 1.15
			var s := q + Vector2.from_angle(a) * 1.6
			p.disque(s, 1.5, 1.0, ENCRE)
			p.disque(s, 1.1, 0.7, couleur.lightened(0.12))
		p.disque(q + Vector2(0, 1.0), 1.6, 1.4, ENCRE)
		p.disque(q + Vector2(0, 1.0), 1.15, 1.0, couleur.darkened(0.2))
		p.disque(q + Vector2(0, 0.6), 0.4, 0.35, P.BRAISE_COEUR)


# une broméliacée : une rosette de feuilles raides, rouges au cœur, et l'épi rouge vif qui en sort
static func _bromelia(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	var c0 := Vector2(0, -2.0)
	var feuilles := []
	for i in 9:
		feuilles.append(lerpf(-PI + 0.2, -0.2, i / 8.0) + r.randf_range(-0.1, 0.1))
	feuilles.sort_custom(func(a, b): return sin(a) < sin(b))
	for a in feuilles:
		var bout := c0 + Vector2(cos(a) * 9.0, sin(a) * 7.0 * u)
		_lance(p, c0, bout, 1.8, vert.lerp(P.BRAISE_ROUGE, 0.12 if absf(cos(a)) < 0.5 else 0.0))
	if la:
		var rouge := couleur if couleur.r > couleur.g + 0.2 and couleur.r > couleur.b + 0.2 else P.BRAISE_ROUGE.lerp(P.BRAISE, 0.2)
		var epi := PackedVector2Array([c0 + Vector2(-2.0, 0), c0 + Vector2(-1.6, -7.0), c0 + Vector2(0, -11.0), c0 + Vector2(1.6, -7.0), c0 + Vector2(2.0, 0)])
		p.aplat(_grossi(epi, c0 + Vector2(0, -5.0), 0.7), ENCRE)
		p.aplat(epi, rouge, Pinceau.DOME, c0 + Vector2(0, -5.0), Vector2(2.2, 6.0))
		for k in 4:
			p.tracer(PackedVector2Array([c0 + Vector2(-1.6, -2.0 - k * 2.2), c0 + Vector2(1.6, -3.0 - k * 2.2)]), 0.5, Color(ENCRE, 0.5))


# -- l'eau : une mare, et ce qui y flotte --

static func _aquatique(o, p, r: RandomNumberGenerator) -> void:
	var rx: float = o._rx
	var ry: float = o._ry
	var eau := P.NUIT_BLEUE.lerp(P.FEUILLE_SOMBRE, 0.45).lerp(P.CENDRE, 0.2)
	var ciel := eau.lerp(P.LUNE, 0.4).lerp(P.PAPIER, 0.12)
	var vase := P.ENCRE_DOUCE.lerp(P.TERRE, 0.45)
	var rive: PackedVector2Array = o.festons(Vector2(0.5, 0.8), rx + 3.0, ry + 2.0, 6, 0.15, r, 30)
	p.aplat(rive, vase.darkened(0.15))
	var forme: PackedVector2Array = o.festons(Vector2.ZERO, rx, ry, r.randi_range(5, 7), 0.12, r, 30)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for q in forme:
		var v := clampf((q.y + ry) / (2.0 * ry), 0.0, 1.0)
		cols.append(ciel.lerp(eau, smoothstep(0.1, 0.7, v)))
		uvs.append(Vector2.ZERO)
	p.aplat_libre(forme, cols, uvs)
	p.contour(forme, 1.0, Color(ENCRE, 0.7), r, 3)
	var t: Color = o.teinte.lerp(P.MOUSSE, 0.35)
	match str(o.forme):
		"lentille":
			# (une nappe de lentilles d'eau : des centaines de points verts, serrés vers les bords)
			for i in 110:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.92
				var q := Vector2(cos(a) * rx * d, sin(a) * ry * d)
				p.disque(q, r.randf_range(0.7, 1.2), r.randf_range(0.45, 0.75), t.lightened(r.randf_range(0.0, 0.25)))
		"algue":
			# (des filaments verts sous la surface, et des nattes qui flottent)
			for i in 7:
				var q := Vector2(r.randf_range(-0.7, 0.7) * rx, r.randf_range(-0.5, 0.5) * ry)
				var ligne := PackedVector2Array()
				for k in 6:
					ligne.append(q + Vector2(k * 2.2, sin(k * 1.3 + i) * 1.2))
				p.tracer(ligne, 1.1, Color(t.lightened(0.1), 0.75), false)
			var nattes := 3 if o.reste > 0 else 1
			for i in nattes:
				var q := Vector2(r.randf_range(-0.5, 0.5) * rx, r.randf_range(-0.4, 0.4) * ry)
				var natte: PackedVector2Array = o.festons(q, r.randf_range(4.0, 6.0), r.randf_range(1.6, 2.4), 5, 0.3, r, 18)
				p.aplat(natte, t.lightened(0.12), Pinceau.FEUILLAGE, q, Vector2(6.0, 2.6))
				p.contour(natte, 0.7, Color(ENCRE, 0.6), r, 2)
		_:
			# (un nénuphar : des feuilles rondes, échancrées, posées à plat ; une fleur blanche ou rose)
			var feuilles := []
			for i in r.randi_range(3, 5):
				feuilles.append(Vector2(r.randf_range(-0.6, 0.6) * rx, r.randf_range(-0.45, 0.5) * ry))
			feuilles.sort_custom(func(a, b): return a.y < b.y)
			for q in feuilles:
				var s := r.randf_range(4.0, 5.6)
				var ang := r.randf() * TAU
				var poly := PackedVector2Array([q])
				for k in 15:
					var a := ang + 0.45 + (TAU - 0.9) * k / 14.0
					poly.append(q + Vector2(cos(a) * s, sin(a) * s * 0.48))
				p.aplat(_grossi(poly, q, 0.7), ENCRE)
				p.aplat(poly, t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25)), Pinceau.FEUILLAGE, q, Vector2(s, s * 0.5) * 1.05)
				for k in 3:
					var a := ang + 0.45 + (TAU - 0.9) * (k + 1) / 4.0
					p.tracer(PackedVector2Array([q, q + Vector2(cos(a) * s * 0.8, sin(a) * s * 0.38)]), 0.5, Color(ENCRE, 0.35), false)
			if o.reste > 0 and o.en_fleurs:
				var q: Vector2 = feuilles[0] + Vector2(1.5, -1.5)
				var fleur := P.PAPIER.lightened(0.1) if o.graine % 3 != 0 else P.AUBE.lerp(P.PEUR, 0.15)
				for couche in 2:
					for k in 6:
						var a := TAU * k / 6.0 + couche * 0.5
						var pet := q + Vector2(cos(a) * 2.0, sin(a) * 0.9 - 1.6 - couche * 0.8)
						var bout := pet + Vector2(cos(a) * 1.6, -1.6)
						var poly := PackedVector2Array([q + Vector2(0, -0.6 - couche), pet + Vector2(-0.9, 0), bout, pet + Vector2(0.9, 0)])
						p.aplat(_grossi(poly, pet, 0.55), ENCRE)
						p.aplat(poly, fleur.darkened(0.08 * (1 - couche)))
				p.disque(q + Vector2(0, -2.4), 1.1, 0.8, P.BRAISE_COEUR)
	# (un reflet du ciel)
	p.tracer(PackedVector2Array([Vector2(-rx * 0.3, -ry * 0.55), Vector2(rx * 0.1, -ry * 0.55)]), 0.8, Color(P.PAPIER, 0.5))


# -- les champignons des bois : le cèpe (chapeau brun, pied ventru) et l'amanite (rouge piquée de blanc, son anneau, sa volve) --

static func _champignons_des_bois(o, p, r: RandomNumberGenerator, amanite: bool) -> void:
	# (un peu de litière dessous : quelques feuilles mortes)
	for i in 4:
		var q := Vector2(r.randf_range(-7.0, 7.0), r.randf_range(-0.5, 3.0))
		var d := Vector2.from_angle(r.randf() * TAU) * r.randf_range(1.8, 2.6)
		p.aplat(PackedVector2Array([q - d, q + d.orthogonal() * 0.5, q + d, q - d.orthogonal() * 0.5]), P.ECHARPE.lerp(P.TERRE, 0.45).darkened(r.randf_range(0.0, 0.25)))
	var n: int = 1 + o.graine % 3
	var pieds := []
	for i in n:
		pieds.append([Vector2((i - (n - 1) * 0.5) * 5.0 + r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.5)), r.randf_range(0.75, 1.0) * (0.7 if i == 1 else 1.0)])
	pieds.sort_custom(func(a, b): return a[0].y < b[0].y)
	var pale := P.IVOIRE.lerp(P.PAPIER, 0.45)
	for e in pieds:
		var q: Vector2 = e[0]
		var k: float = e[1]
		var h: float = o._ry * k
		var s: float = o._rx * k
		if o.reste <= 0:
			# (cueilli : le pied coupé, sa coupe claire)
			p.tracer(PackedVector2Array([q, q + Vector2(0, -2.2)]), 2.8, ENCRE, false)
			p.tracer(PackedVector2Array([q, q + Vector2(0, -2.2)]), 1.8, pale.darkened(0.15), false)
			p.disque(q + Vector2(0, -2.2), 1.1, 0.5, P.PAPIER)
			continue
		var penche := r.randf_range(-1.2, 1.2)
		var tete := q + Vector2(penche, -h)
		var larg_pied := s * (0.45 if not amanite else 0.3)
		# le pied : ventru pour le cèpe ; droit, avec un anneau et une volve, pour l'amanite
		var pied := PackedVector2Array([q + Vector2(-larg_pied * (1.25 if not amanite else 1.5), 0.5), q + Vector2(-larg_pied * (1.15 if not amanite else 0.8), -h * 0.35),
			tete + Vector2(-larg_pied * 0.7, 0), tete + Vector2(larg_pied * 0.7, 0), q + Vector2(larg_pied * (1.15 if not amanite else 0.8), -h * 0.35), q + Vector2(larg_pied * (1.25 if not amanite else 1.5), 0.5)])
		p.aplat(pied, pale if amanite else pale.lerp(P.TERRE, 0.12), Pinceau.ECORCE, q + Vector2(0, -h * 0.5), Vector2(larg_pied * 1.3, h * 0.6))
		p.contour(pied, 0.8, ENCRE, r, 2)
		if amanite:
			var anneau := q.lerp(tete, 0.72)
			p.tracer(PackedVector2Array([anneau + Vector2(-larg_pied - 1.0, 0.8), anneau + Vector2(0, 1.6), anneau + Vector2(larg_pied + 1.0, 0.8)]), 1.4, ENCRE, false)
			p.tracer(PackedVector2Array([anneau + Vector2(-larg_pied - 0.8, 0.5), anneau + Vector2(0, 1.2), anneau + Vector2(larg_pied + 0.8, 0.5)]), 0.8, P.PAPIER, false)
		else:
			# (le réseau fin sur le haut du pied)
			p.tracer(PackedVector2Array([q.lerp(tete, 0.55) + Vector2(-larg_pied * 0.6, 0), q.lerp(tete, 0.75) + Vector2(larg_pied * 0.5, 0)]), 0.5, Color(ENCRE, 0.3))
		# le chapeau : un dôme, plat dessous ; rouge et ses verrues blanches, ou brun bordé plus clair
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			cap.append(tete + Vector2(cos(a) * s, sin(a) * s * 0.8 + 0.6))
		cap.append(tete + Vector2(s * 0.75, 1.4))
		cap.append(tete + Vector2(-s * 0.75, 1.4))
		var teinte := P.BRAISE_ROUGE.lerp(P.SANG, 0.15).lightened(0.04) if amanite else P.TERRE.lerp(P.BRAISE, 0.32).darkened(0.08)
		p.aplat(_grossi(cap, tete + Vector2(0, -s * 0.3), 0.8), ENCRE)
		p.aplat(cap, teinte, Pinceau.DOME, tete + Vector2(0, -s * 0.35), Vector2(s, s * 0.75))
		if amanite:
			for i in 6:
				var v := tete + Vector2(r.randf_range(-0.7, 0.7) * s, -r.randf_range(0.2, 0.65) * s)
				p.disque(v, 0.75, 0.6, P.PAPIER.lightened(0.15))
		else:
			p.tracer(PackedVector2Array([tete + Vector2(-s * 0.9, 0.8), tete + Vector2(0, 1.6), tete + Vector2(s * 0.9, 0.8)]), 0.9, P.IVOIRE.lerp(P.BRAISE_COEUR, 0.3), false)
		p.disque(tete + Vector2(-s * 0.35, -s * 0.45), s * 0.22, s * 0.13, Color(1.0, 0.97, 0.9, 0.45))
