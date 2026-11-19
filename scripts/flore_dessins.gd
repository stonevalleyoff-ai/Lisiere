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
const Sol := preload("res://scripts/flore_sol.gd")
const Buissons := preload("res://scripts/flore_buissons.gd")
# ce que le vent ne plie pas : les plantes grasses, les coussins, les lichens, les tapis
const RAIDES := ["cactus", "agave", "succulente", "caillou", "mousse", "lichen", "lichen_croute", "lichen_rennes", "coussin"]
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
	o.raide = RAIDES.has(str(o.forme))
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
			# (les plantes du sol : scripts/flore_sol.gd ; l'herbe et la grande herbe gardent la mesure des touffes)
			Sol.mesurer(o, r, f)
		"buisson":
			# (scripts/flore_buissons.gd ; le buisson et l'arbuste à baies gardent la mesure des buissons)
			Buissons.mesurer(o, r, f)
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
			return Sol.ombres(o)
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


# ce que les caractères d'Orvane ajoutent à une couronne (lobes : [[centre, rx, ry]…])
static func caracteres_de_couronne(o, p, lobes: Array, t: Color) -> void:
	Arbres.caracteres_de_couronne(o, p, lobes, t)


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
			return Buissons.dessiner(o, p, r, f)
		"touffe":
			return Sol.dessiner(o, p, r, f)
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


# un polygone, un peu agrandi depuis son centre (son liseré d'encre, dessous)
static func _grossi(poly: PackedVector2Array, centre: Vector2, de: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		var d := q - centre
		out.append(q + d.normalized() * de)
	return out


# une feuille en lance, de a à b
static func _lance(p, a: Vector2, b: Vector2, larg: float, c: Color) -> void:
	var d := b - a
	var n := d.orthogonal().normalized() * larg
	var poly := PackedVector2Array([a, a + d * 0.35 + n, b, a + d * 0.35 - n])
	p.aplat(PackedVector2Array([a - d.normalized() * 0.4, a + d * 0.35 + n * 1.5, b + d.normalized() * 0.6, a + d * 0.35 - n * 1.5]), ENCRE)
	p.aplat(poly, c)


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
		var cote_f := 1.0 if t[2] < 0.5 else -1.0
		T.feuille(p, pied + Vector2(0, -0.3), pied + Vector2(r.randf_range(2.5, 4.2) * cote_f, -r.randf_range(2.0, 3.8)), 1.15, vert, cote_f * 0.6, 0.4, 0.5, 4)
		if herbier:
			T.feuille(p, pied + Vector2(0, -0.3), pied + Vector2(-r.randf_range(2.0, 3.4) * cote_f, -r.randf_range(1.6, 3.0)), 1.0, vert.darkened(0.08), -cote_f * 0.5, 0.4, 0.5, 4)
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
	var pieds := []
	for pied_i in r.randi_range(2, 3):
		pieds.append(Vector2(r.randf_range(-o._rx * 0.6, o._rx * 0.6), r.randf_range(-o._ry * 0.5, o._ry * 0.5)))
	pieds.sort_custom(func(a, b): return a.y < b.y)
	for pied_ in pieds:
		var pied: Vector2 = pied_
		# (le bulbe affleure : sa tunique brune, dans la terre remuée)
		T.assise(p, pied + Vector2(0, 0.6), 4.0, 1.6, P.TERRE.darkened(0.3), 0.5)
		p.disque(pied + Vector2(0, 0.2), 2.3, 1.7, ENCRE)
		p.disque(pied + Vector2(0, 0.2), 1.7, 1.2, P.TERRE.lerp(P.BRAISE, 0.3), Pinceau.DOME)
		for i in 5:
			var cote := -1.0 if i % 2 == 0 else 1.0
			var h := r.randf_range(6.0, 10.5) * u
			T.feuille(p, pied, pied + Vector2(cote * r.randf_range(2.5, 6.0), -h), 1.35, vert.lightened(0.04 * i), cote * h * 0.18, 0.3, 0.5, 5)
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


# des orchidées : deux ou trois larges feuilles charnues couchées au pied (tachées de pourpre, chez la plupart), la dernière
# qui engaine la hampe ; la hampe monte puis s'arque, ses fleurs alternes le long, les plus ouvertes en bas : chacune son casque
# (trois sépales, deux pétales, en éventail) et sa lèvre qui pend devant, plus claire, piquetée de sombre ; vers la pointe, des
# boutons verts qui s'ouvriront. Cueillie : la hampe coupée, ses boutons
static func _orchidees(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	T.ombre_douce(p, Vector2(0.5, 0.6), 6.5, 1.8, 0.22)
	var tachee := int(o.graine) % 3 != 0
	var charnu := vert.lerp(P.FEUILLE_SOMBRE, 0.12)
	for i in 3:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var pa := Vector2(cote * 0.4, 0.2)
		var pb := Vector2(cote * r.randf_range(6.0, 8.5), -r.randf_range(0.4, 2.4)) if i < 2 else Vector2(cote * r.randf_range(2.2, 3.2), -r.randf_range(5.0, 6.5))
		var fe: Dictionary = T.feuille_charnue(p, pa, pb, 2.2 if i < 2 else 1.5, charnu.lightened(0.05 * i), cote * (0.9 if i < 2 else 0.4), 0.4, 0.6, 6, 0.25)
		if tachee and i < 2:
			for k in [2, 3, 4]:
				var q: Vector2 = fe["axe"][k].lerp(fe["g"][k] if k % 2 == 0 else fe["d"][k], 0.5)
				p.disque(q, 0.5, 0.34, Color(P.SANG.lerp(P.NUIT, 0.35), 0.7))
	var hampe := PackedVector2Array()
	var sens := 1.0 if o.graine % 2 == 0 else -1.0
	var haut := 18.0 * u
	for k in 9:
		var t := k / 8.0
		hampe.append(Vector2(sens * 6.5 * t * t, -haut * sin(t * PI * 0.6) / sin(PI * 0.6)))
	if not la and u < 0.6:
		# (coupée : un chicot de hampe, sa coupe claire)
		var bout := hampe[3]
		p.tracer(PackedVector2Array([hampe[0], hampe[1], hampe[2], bout]), 1.5, ENCRE, false)
		p.tracer(PackedVector2Array([hampe[0], hampe[1], hampe[2], bout]), 0.8, vert.darkened(0.2), false)
		p.disque(bout, 0.6, 0.5, P.IVOIRE)
		return
	p.tracer(hampe, 1.5, ENCRE, false, PackedFloat32Array([1.6, 1.4, 1.0]))
	p.tracer(hampe, 0.8, vert.darkened(0.2), false, PackedFloat32Array([0.9, 0.8, 0.5]))
	var levre := couleur.lightened(0.2)
	var sombre := couleur.darkened(0.45).lerp(P.SANG, 0.3)
	for k in range(3, 9):
		var tg := (hampe[mini(k + 1, 8)] - hampe[k - 1]).normalized()
		var cote := 1.0 if k % 2 == 0 else -1.0
		var q := hampe[k] + tg.orthogonal() * cote * 0.9 + Vector2(0.0, 0.6)
		var s := lerpf(0.9, 0.62, (k - 3) / 5.0)
		if not la or k >= 7:
			# (les boutons : verts, pointus, de plus en plus petits vers la pointe)
			p.disque(q, 0.95 * s + 0.4, 1.2 * s + 0.4, ENCRE)
			p.disque(q, 0.95 * s, 1.2 * s, vert.lightened(0.14).lerp(couleur, 0.15 if la else 0.0), Pinceau.DOME)
			continue
		# (le casque : trois sépales et deux pétales en éventail, au-dessus)
		p.disque(q + Vector2(0.0, -0.75 * s), 2.05 * s, 1.55 * s, Color(ENCRE, 0.8))
		for j in 5:
			var ang := -PI * 0.5 + (j - 2) * 0.62
			var e := q + Vector2.from_angle(ang) * 1.25 * s
			p.disque(e, 0.62 * s, 0.44 * s, couleur.lightened(0.12) if j < 2 else couleur.darkened(0.06), Pinceau.DOME)
		# (la lèvre : trois lobes qui pendent devant, plus clairs, piquetés de sombre ; la gorge au-dessus)
		var lv := q + Vector2(0.0, 1.0 * s)
		p.disque(lv, 1.35 * s + 0.4, 1.1 * s + 0.4, ENCRE)
		for j in [-1.0, 1.0]:
			p.disque(lv + Vector2(j * 0.85 * s, -0.15), 0.7 * s, 0.6 * s, levre.darkened(0.05))
		p.disque(lv + Vector2(0.0, 0.2), 0.95 * s, 0.85 * s, levre, Pinceau.DOME)
		# (ses points, en traînée sur la lèvre, d'un côté)
		p.disque(lv + Vector2(0.2 * cote, 0.15), 0.2, 0.17, sombre)
		p.disque(lv + Vector2(0.45 * cote, 0.5), 0.17, 0.15, sombre)


# une broméliacée : une rosette en vase de feuilles raides, charnues, arquées, cerclées de bandes pâles ; au cœur, l'eau
# qu'elle garde (un miroir sombre qui luit) ; en fleurs, ses feuilles du cœur rougissent et il en sort, sur sa hampe, un épi de
# bractées rouges imbriquées comme les écailles d'un cône, piquées de petites fleurs bleues. Cueillie : la rosette seule
static func _bromelia(o, p, r: RandomNumberGenerator, couleur: Color, vert: Color, la: bool, u: float) -> void:
	var c0 := Vector2(0, -2.2)
	var glauque := vert.lerp(P.LUNE, 0.14)
	var rouge := couleur if couleur.r > couleur.g + 0.2 and couleur.r > couleur.b + 0.2 else P.BRAISE_ROUGE.lerp(P.BRAISE, 0.2)
	var bandes := int(o.graine) % 2 == 0
	T.ombre_douce(p, Vector2(0.6, 0.6), 8.5, 2.2, 0.26)
	var feuilles := []
	for i in 11:
		feuilles.append([lerpf(-PI + 0.12, -0.12, i / 10.0) + r.randf_range(-0.08, 0.08), r.randf_range(0.85, 1.1)])
	for i in 3:
		feuilles.append([lerpf(0.55, PI - 0.55, i / 2.0) + r.randf_range(-0.1, 0.1), r.randf_range(0.6, 0.75)])
	feuilles.sort_custom(func(x, y): return sin(x[0]) < sin(y[0]))
	var coeur_fait := false
	for fe in feuilles:
		var a: float = fe[0]
		if not coeur_fait and sin(a) > -0.3:
			# (le cœur du vase, entre les feuilles du fond et celles de devant : l'eau qu'il garde, et l'épi qui en sort)
			coeur_fait = true
			p.disque(c0 + Vector2(0.0, -1.4), 2.4, 1.2, ENCRE)
			p.disque(c0 + Vector2(0.0, -1.4), 1.8, 0.8, P.NUIT_BLEUE.lerp(glauque, 0.25))
			p.tracer(PackedVector2Array([c0 + Vector2(-1.1, -1.7), c0 + Vector2(0.2, -1.9)]), 0.4, Color(P.LUNE, 0.8))
			if la:
				_epi_de_bromelia(p, c0 + Vector2(0.0, -1.6), 13.0 * u, rouge)
		var l: float = 9.6 * float(fe[1]) * (0.75 + 0.25 * u)
		var leve := 2.6 + 4.2 * (1.0 - absf(cos(a))) * (1.0 if sin(a) < 0.0 else 0.35)
		var bout := c0 + Vector2(cos(a) * l * 0.9, sin(a) * l * 0.42 - leve)
		var du_coeur := absf(cos(a)) < 0.5 and sin(a) < 0.0
		var ton := glauque.lerp(rouge, 0.5 if (la and du_coeur) else 0.0)
		ton = ton.lightened(0.06) if cos(a) < 0.0 else ton.darkened(0.06)
		var pied := c0 + Vector2(cos(a) * 1.2, 0.4)
		var f: Dictionary = T.feuille_charnue(p, pied, bout, 1.35 + 0.2 * absf(cos(a)), ton, signf(cos(a)) * 2.0, 0.3, 0.6, 6, 0.3)
		if bandes:
			for k in [2, 4]:
				p.tracer(PackedVector2Array([f["g"][k], f["d"][k]]), 0.45, Color(P.LUNE.lerp(ton, 0.3), 0.55), false)
		# (sa pointe, un peu rougie, armée)
		p.disque(bout, 0.4, 0.4, ton.lerp(rouge, 0.4).darkened(0.1))


# l'épi d'une broméliacée, de pied à pied + (0, -h) : sa hampe, puis ses bractées rouges, celles du haut d'abord (chacune cache
# la base de celle du dessus), une petite fleur bleue au bout d'une sur deux
static func _epi_de_bromelia(p, pied: Vector2, h: float, rouge: Color) -> void:
	var sommet := pied + Vector2(0.0, -h)
	p.tracer(PackedVector2Array([pied, pied + Vector2(0.0, -h * 0.5)]), 1.5, ENCRE, false)
	p.tracer(PackedVector2Array([pied, pied + Vector2(0.0, -h * 0.5)]), 0.75, rouge.darkened(0.25), false)
	for k in range(6, -1, -1):
		var t := k / 6.0
		var q := pied.lerp(sommet, 0.42 + t * 0.58)
		var w := 1.55 * (1.0 - t * 0.5)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var pointe := q + Vector2(cote * w * 0.6, -2.0 * (1.0 - t * 0.3))
		T.tri(p, q + Vector2(-w - 0.45, 0.9), q + Vector2(w + 0.45, 0.9), pointe + Vector2(cote * 0.2, -0.6), ENCRE)
		T.tri(p, q + Vector2(-w, 0.7), q + Vector2(w, 0.7), pointe, rouge.lightened(0.14) if cote < 0.0 else rouge.darkened(0.08))
		if k % 2 == 1:
			p.disque(pointe + Vector2(cote * 0.5, 0.2), 0.5, 0.45, Color(ENCRE, 0.7))
			p.disque(pointe + Vector2(cote * 0.5, 0.2), 0.32, 0.28, P.PEUR.lerp(P.LUNE, 0.3))


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
			# (ses mèches montent du fond en ondulant, comme sur la planche d'Orvane : on les voit sous l'eau, plus fines
			# vers la surface ; et des nattes qui flottent)
			for i in 9:
				var q := Vector2(r.randf_range(-0.72, 0.72) * rx, r.randf_range(-0.2, 0.6) * ry)
				var haut := r.randf_range(5.0, 9.0)
				var ligne := PackedVector2Array()
				for k in 7:
					ligne.append(q + Vector2(sin(k * 1.1 + i * 1.7) * 1.5, -haut * k / 6.0))
				p.tracer(ligne, 1.9, Color(P.ENCRE, 0.35), false, PackedFloat32Array([2.2, 2.0, 1.8, 1.6, 1.3, 1.0, 0.6]))
				p.tracer(ligne, 1.1, Color(t.lightened(0.04 + 0.03 * (i % 3)), 0.9), false, PackedFloat32Array([1.5, 1.4, 1.2, 1.1, 0.9, 0.7, 0.3]))
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
				# (son ombre sur l'eau, puis la feuille : cirée, elle luit ; ses nervures en étoile)
				p.aplat(_grossi(poly, q + Vector2(0.6, 0.9), 0.4), Color(P.ENCRE, 0.3))
				p.aplat(_grossi(poly, q, 0.7), ENCRE)
				var ton := t.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.25))
				p.aplat(poly, ton, Pinceau.DOME, q + Vector2(s * 0.2, s * 0.2), Vector2(s, s * 0.5) * 1.5)
				for k in 5:
					var a := ang + 0.45 + (TAU - 0.9) * (k + 0.5) / 5.0
					p.tracer(PackedVector2Array([q, q + Vector2(cos(a) * s * 0.84, sin(a) * s * 0.4)]), 0.5, Color(ENCRE, 0.35), false)
				p.tracer(PackedVector2Array([q + Vector2(-s * 0.6, -s * 0.22), q + Vector2(-s * 0.2, -s * 0.36)]), 0.6, Color(P.PAPIER, 0.4))
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
