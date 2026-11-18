extends Node
# Lisière — le sol des pays qui ont leur caractère (scripts/biome_terrain.gd)
# Ce que le sol de la banquise, du volcan, du marais et du désert porte en propre (scripts/biomes.gd) : ce qui piège, et ce
# qu'on y trouve. Tout est posé d'après la graine du monde, case par case (600 pixels) autour de la veilleuse : toujours la
# même chose au même endroit, qu'on revienne ou qu'on reprenne la partie ; on ne garde que ce qu'on y a pris (photo, reprendre).
#  - la fondrière (le marais) : une mare de vase noire. On y a de l'eau aux genoux (climat.eau la lit ici : on s'y mouille,
#    on n'y fait pas de feu, on y patauge) ; qui s'y arrête s'enfonce (enlise), jusqu'aux cuisses, et n'en sort plus qu'à
#    grand-peine ; au bout de trois secondes, les sangsues. La nuit, des feux follets dansent au-dessus, et fuient qui approche ;
#  - la faille (le volcan) : une fente de roche où rougeoie la lave. Y mettre le pied, c'est prendre feu ; tout près, il fait chaud ;
#  - la fumerolle (le volcan) : un évent de soufre qui fume, et crache, à son heure (l'horloge de la partie) : il siffle une
#    seconde, puis une bouffée de vapeur brûle qui est tout contre. Sa chaleur se sent de loin ;
#  - la mare gelée (la banquise) : sous la glace, de l'eau pour la gourde ;
#  - le sol même : les dunes du désert (du sable, ses rides, sa crête), les champs de scories du volcan (une roche noire, des
#    cendres) ; ils ne font que se voir, ce que le sable fait au pas est dans scripts/climat.gd ;
#  - ce qu'on ramasse (« Agir ») : l'obsidienne (le volcan : une lance, à l'établi), la tourbe (le marais : un feu qui dure),
#    le bois flotté (la banquise, surtout sur le rivage : le seul bois ; la mer en rapporte), la carcasse ensablée (le désert :
#    de la ferraille). Elles se tiennent debout dans le lieu, triées avec le reste ; elles maigrissent à mesure qu'on y prend.
# Ce qui est à plat se dessine au-dessus du sol (sous la lueur des feux et tout ce qui se tient debout), case par case : une
# case se dessine une fois, quand elle se fait, et s'en va avec elle (scripts/biome_dessins.gd) ; le sol même (dunes, scories)
# sur un calque à lui, dessous. La lave luit sur un calque additif que la nuit n'assombrit pas, et qui ne fait que battre ; les
# feux follets passent au-dessus de tout, la nuit seulement.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")
const Biomes := preload("res://scripts/biomes.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const Dessins := preload("res://scripts/biome_dessins.gd")
const CASE := 600.0
const PORTEE := 1500.0         # les cases se font jusque-là autour d'elle
const OUBLI := 2700.0          # et se défont au-delà (ce qu'on y a pris reste su)
# (l'ordre où chaque case tire ses choses : il ne change pas, pour que la même case donne toujours les mêmes)
const ORDRE := ["dune", "scories", "fondriere", "tourbe", "faille", "fumerolle", "obsidienne", "bois_flotte", "mare", "carcasse"]
const A_PLAT := ["dune", "scories", "fondriere", "faille", "fumerolle", "mare"]
const FONDS := ["dune", "scories"]     # (le sol même : il se dessine sous le reste, et ne gêne la place de rien)
const DEBOUT := ["obsidienne", "tourbe", "bois_flotte", "carcasse"]
const BOUFFEE := 2.4           # secondes : une fumerolle crache
const SIFFLE := 1.1            # et siffle, avant
const VASE := 0.5              # l'eau qu'on a dans une fondrière (climat.eau) ; enlisée, jusqu'à 1

var jeu
var enlise := 0.0              # de 0 à 1 : ce qu'elle s'est enfoncée dans une fondrière
var _cases := {}               # Vector2i → [les choses de la case]
var _vases := {}               # Vector2i → [les fondrières qui touchent la case] (climat.eau les lit souvent : une case, une liste)
var _pris := {}                # id → [ce qui reste, l'heure de la partie où on y a pris]
var _fonds: Node2D            # le sol même (dunes, scories) : un calque par case
var _sol: Node2D              # ce qui est à plat par-dessus (fondrières, failles, évents, mares) : un calque par case
var _calques := {}            # Vector2i → les calques de la case
var _lave: Node2D
var _air: Node2D
var _sale := false
var _t := 0.0
var _revoir := 0.0
var _enfoncee := 0.0           # depuis combien de temps elle est enfoncée (les sangsues)
var _ebouillantee := false     # (une bouffée la brûle : l'écran et la jauge le disent une fois par bouffée)
var _crachait := {}            # id → elle crachait à l'image d'avant (le son, une fois par bouffée)
var _follets := {}             # id → [où il est, son éclat, sa phase]
var _bulle := 2.0
var _mobile := false


func _init() -> void:
	name = "Pays"


# au début d'une partie, dans la scène du lieu : les calques (le sol, la lave qui luit, l'air de la nuit)
func poser(scene: Node2D) -> void:
	_mobile = str(jeu.qualite) == "mobile"
	scene.add_child(self)
	_fonds = Node2D.new()
	_fonds.name = "PaysFonds"
	_sol = Node2D.new()
	_sol.name = "PaysSol"
	_lave = Calque.new()
	_lave.terrain = self
	_lave.quoi = "lave"
	_lave.material = T.materiau(true, false)
	_air = Calque.new()
	_air.terrain = self
	_air.quoi = "air"
	_air.material = T.materiau(true, false)
	scene.add_child(_fonds)
	scene.add_child(_sol)
	scene.add_child(_lave)
	# (au-dessus du sol, du temps qu'il fait au sol et des parois ; sous la lueur des feux, la brume, ce qui se tient debout)
	var lueurs: Node = scene.get_node_or_null("EffetsSol")
	var i: int = lueurs.get_index() if lueurs != null else jeu.monde.get_index()
	scene.move_child(_fonds, i)
	scene.move_child(_sol, i + 1)
	scene.move_child(_lave, i + 2)
	scene.add_child(_air)
	var inv: Dictionary = jeu.joueur.inventaire
	for k in ["obsidienne", "tourbe"]:
		if not inv.has(k):
			inv[k] = 0


# --- les cases : ce qu'il y a, d'après la graine ---

func _type_en(p: Vector2) -> String:
	if jeu.carte != null:
		return str(jeu.carte.type_en(p))
	# (un lieu fermé : tout le lieu est son biome)
	return str(jeu.biome) if absf(p.x) < R.DEMI and absf(p.y) < R.DEMI else ""


# un endroit où poser une chose de cette taille : ni dans l'eau, ni sur une crête, une paroi, la roche ; pas sur le réveil
func _libre(p: Vector2, rayon: float) -> bool:
	var C = jeu.carte
	if C == null:
		var lim := R.DEMI - 90.0 - rayon
		return absf(p.x) < lim and absf(p.y) < lim and p.length() > 380.0 + rayon
	if p.length() < 700.0:
		return false
	for q in [p, p + Vector2(rayon, 0.0), p - Vector2(rayon, 0.0), p + Vector2(0.0, rayon), p - Vector2(0.0, rayon)]:
		if C.retenir(q).distance_squared_to(q) > 1.0 or C.mouille(q):
			return false
	return true


# (la banquise) ce point est-il près du rivage ? Le bois flotté s'y entasse
func _rivage(p: Vector2) -> bool:
	var C = jeu.carte
	if C == null:
		return false
	var pr: Array = C.proches(p)
	return bool(C.regions[int(pr[1])]["eau"]) and float(pr[3]) - float(pr[2]) < 1800.0


# ce qu'une case porte, tiré de la graine et de sa place (toujours pareil) : la liste seule, sans rien poser dans le lieu. Le
# monde la lit aussi pour savoir où sont l'eau et le feu d'un pays, avant d'y semer ses plantes (scripts/monde.gd, _pays)
func _lister(k: Vector2i) -> Array:
	var liste: Array = []
	var coin := Vector2(k) * CASE
	# (les pays qui touchent la case : son milieu, ses coins)
	var ids: Array = []
	for q in [coin + Vector2(CASE, CASE) * 0.5, coin, coin + Vector2(CASE, 0.0), coin + Vector2(0.0, CASE), coin + Vector2(CASE, CASE)]:
		var t := _type_en(q)
		if t != "" and not ids.has(t) and not Biomes.de(t).is_empty():
			ids.append(t)
	if ids.is_empty():
		return liste
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%d" % [int(jeu.graine), k.x, k.y])
	var n := 0
	for t in ids:
		var sorts: Dictionary = Biomes.de(t).get("sorts", {})
		for genre in ORDRE:
			if not sorts.has(genre):
				continue
			var v := float(sorts[genre])
			if genre == "bois_flotte" and _rivage(coin + Vector2(CASE, CASE) * 0.5):
				v = 2.0 * float(sorts.get("rivage", v))
			var combien := int(v) + (1 if r.randf() < fmod(v, 1.0) else 0)
			for i in combien:
				var s := _sort(genre, t, coin, r, liste)
				if s.is_empty():
					continue
				s["id"] = "%d,%d,%d" % [k.x, k.y, n]
				n += 1
				liste.append(s)
	return liste


func _faire(k: Vector2i) -> void:
	var liste := _lister(k)
	_cases[k] = liste
	if liste.is_empty():
		return
	for s in liste:
		_inscrire(s)
		if str(s["genre"]) == "faille":
			_sale = true
	# (ce qui est à plat se dessine une fois, pour toute la case : le sol même, puis le reste)
	var calques: Array = []
	for fond in [true, false]:
		if liste.any(func(x): return A_PLAT.has(str(x["genre"])) and FONDS.has(str(x["genre"])) == fond):
			var c := Calque.new()
			c.terrain = self
			c.quoi = "fonds" if fond else "sol"
			c.case = k
			(_fonds if fond else _sol).add_child(c)
			calques.append(c)
	if not calques.is_empty():
		_calques[k] = calques


func _taille(genre: String, r: RandomNumberGenerator) -> float:
	match genre:
		"dune":
			return r.randf_range(150.0, 250.0)
		"scories":
			return r.randf_range(110.0, 200.0)
		"fondriere":
			return r.randf_range(42.0, 86.0)
		"faille":
			return r.randf_range(80.0, 160.0)
		"mare":
			return r.randf_range(34.0, 54.0)
		"fumerolle":
			return 34.0
	return 30.0


# une chose de ce genre dans la case (son pays : t), là où il y a de la place ; {} si elle n'en trouve pas
func _sort(genre: String, t: String, coin: Vector2, r: RandomNumberGenerator, liste: Array) -> Dictionary:
	var taille := _taille(genre, r)
	var s := {"genre": genre, "graine": r.randi(), "taille": taille}
	var marge := minf(taille + 20.0, CASE * 0.3)
	var angle := r.randf() * TAU
	var fond := FONDS.has(genre)
	for essai in 6:
		var p := coin + Vector2(r.randf_range(marge, CASE - marge), r.randf_range(marge, CASE - marge))
		if _type_en(p) != t or not _libre(p, taille * 1.1 if fond else minf(taille, 60.0)):
			continue
		var fente := PackedVector2Array()
		if genre == "faille":
			# (une fente qui serpente, plus large au milieu ; chacun de ses points doit tenir, dans son pays)
			var dir := Vector2.from_angle(angle)
			var q := p - dir * taille
			var pas := taille * 2.0 / 7.0
			var tient := true
			for i in 8:
				fente.append(q)
				if _type_en(q) != t or not _libre(q, 14.0):
					tient = false
				dir = dir.rotated(r.randf_range(-0.38, 0.38))
				q += dir * pas
			if not tient:
				continue
		# (pas de place si une autre chose de la case est trop près ; le sol même se chevauche, et ne gêne la place de rien)
		if not fond and _trop_pres(p, taille, fente, liste):
			continue
		if genre == "faille":
			s["trait"] = fente
			s["large"] = r.randf_range(6.0, 10.0)
		s["p"] = p
		break
	if not s.has("p"):
		return {}
	match genre:
		"fondriere", "dune", "scories":
			# (son bord : douze rayons, que le dessin et l'eau lisent pareil ; une dune s'allonge sous le vent)
			var rs := PackedFloat32Array()
			for i in 12:
				var allonge := 1.0 + (0.45 * absf(cos(TAU * i / 12.0 - angle)) if genre == "dune" else 0.0)
				rs.append(taille * r.randf_range(0.78, 1.08) * allonge)
			s["rayons"] = rs
			s["angle"] = angle
			s["follet"] = genre == "fondriere" and r.randf() < 0.45
		"fumerolle":
			s["periode"] = r.randf_range(7.0, 12.0)
			s["phase"] = r.randf_range(0.0, 12.0)
	if DEBOUT.has(genre):
		s["plein"] = int(Biomes.BUTINS[genre]["parts"])
	return s


# une chose (en p, de cette taille ; une faille : sa fente) toucherait-elle une autre chose de la case ? D'une faille, on compte
# la fente, pas son milieu
func _trop_pres(p: Vector2, taille: float, fente: PackedVector2Array, liste: Array) -> bool:
	for o in liste:
		var genre: String = o["genre"]
		if FONDS.has(genre):
			continue
		var marge: float = float(o["taille"]) + 30.0 if genre != "faille" else float(o["large"]) * 3.0 + 30.0
		if not fente.is_empty():
			if _vers_le_trait(o["p"], fente) < (marge if genre != "faille" else 60.0) or (genre == "faille" and _vers_le_trait(fente[3], o["trait"]) < 60.0):
				return true
		elif genre == "faille":
			if _vers_le_trait(p, o["trait"]) < taille + marge:
				return true
		elif p.distance_to(o["p"]) < taille + float(o["taille"]) + 40.0:
			return true
	return false


# une chose vient : la fondrière est inscrite dans les cases qu'elle touche ; ce qui se tient debout entre dans le lieu
func _inscrire(s: Dictionary) -> void:
	var genre: String = s["genre"]
	if genre == "fondriere":
		var rr: float = float(s["taille"]) * 1.1
		var p: Vector2 = s["p"]
		var a := Vector2i(((p - Vector2(rr, rr)) / CASE).floor())
		var b := Vector2i(((p + Vector2(rr, rr)) / CASE).floor())
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				var k := Vector2i(x, y)
				if not _vases.has(k):
					_vases[k] = []
				_vases[k].append(s)
	elif DEBOUT.has(genre) or genre == "fumerolle":
		var n = Debout.new() if genre != "fumerolle" else Fumee.new()
		n.terrain = self
		n.s = s
		n.position = s["p"]
		s["noeud"] = n
		jeu.monde.add_child(n)


func _defaire(k: Vector2i) -> void:
	for s in _cases[k]:
		var n = s.get("noeud")
		if n != null and is_instance_valid(n):
			n.queue_free()
		if str(s["genre"]) == "faille":
			_sale = true
		_follets.erase(s["id"])
		_crachait.erase(s["id"])
	_cases.erase(k)
	for c in _calques.get(k, []):
		c.queue_free()
	_calques.erase(k)
	# (les fondrières de cette case quittent les cases qu'elles touchaient)
	for v in _vases.keys():
		_vases[v] = _vases[v].filter(func(x): return Vector2i((Vector2(x["p"]) / CASE).floor()) != k)
		if _vases[v].is_empty():
			_vases.erase(v)


# les cases autour d'elle : celles qui manquent se font (la plus proche d'abord, une par image ; tout, d'un coup), les lointaines
# se défont
func suivre(p: Vector2, tout: bool = false) -> void:
	if jeu.carte == null:
		# (un lieu fermé n'est pas grand : il se fait tout entier, une fois pour toutes)
		var m := int(ceil(R.DEMI / CASE))
		for x in range(-m, m):
			for y in range(-m, m):
				if not _cases.has(Vector2i(x, y)):
					_faire(Vector2i(x, y))
					if not tout:
						return
		return
	var c := Vector2i((p / CASE).floor())
	var n := int(ceil(PORTEE / CASE))
	var manque: Array = []
	for x in range(c.x - n, c.x + n + 1):
		for y in range(c.y - n, c.y + n + 1):
			var k := Vector2i(x, y)
			if _cases.has(k):
				continue
			if ((Vector2(k) + Vector2(0.5, 0.5)) * CASE).distance_to(p) > PORTEE + CASE * 0.71:
				continue
			manque.append(k)
	if not manque.is_empty():
		manque.sort_custom(func(a, b): return ((Vector2(a) + Vector2(0.5, 0.5)) * CASE).distance_squared_to(p) < ((Vector2(b) + Vector2(0.5, 0.5)) * CASE).distance_squared_to(p))
		for k in manque:
			_faire(k)
			if not tout:
				break
	for k in _cases.keys():
		if ((Vector2(k) + Vector2(0.5, 0.5)) * CASE).distance_to(p) > OUBLI:
			_defaire(k)


# --- ce que le jeu en lit ---

# l'eau d'une fondrière en p (climat.eau) : 0 au sec ; VASE dedans ; jusqu'à 1 là où la veilleuse s'est enfoncée
func fondriere(p: Vector2) -> float:
	if _vases.is_empty():
		return 0.0
	var l = _vases.get(Vector2i((p / CASE).floor()))
	if l == null:
		return 0.0
	var e := 0.0
	for s in l:
		var d: Vector2 = p - s["p"]
		var bord := Dessins.rayon_de(s, atan2(d.y / 0.82, d.x))
		var loin := Vector2(d.x, d.y / 0.82).length()
		if loin < bord:
			e = maxf(e, clampf((bord - loin) / 18.0, 0.0, 1.0) * VASE)
	# (la veilleuse elle-même : enfoncée, l'eau lui monte aux cuisses)
	if e > 0.0 and jeu.joueur != null and p == jeu.joueur.position:
		e += (1.0 - VASE) * enlise
	return e


# ce qui ralentit encore la veilleuse (principal.gd, allure_sol) : enfoncée, elle n'avance plus qu'à peine
func frein() -> float:
	return 1.0 - R.FONDRIERE_FREIN * enlise


# la chaleur du sol en p, pour le corps (principal.gd, _temps_du_corps) : près d'une fumerolle (bien plus dans sa bouffée),
# près d'une faille
func chaleur(p: Vector2) -> float:
	var c := 0.0
	for s in _autour(p, maxf(R.FUMEROLLE_CHAUD, R.FAILLE_CHAUD) + 170.0):
		if FONDS.has(str(s["genre"])):
			continue
		match str(s["genre"]):
			"fumerolle":
				var d: float = p.distance_to(s["p"])
				if d < R.FUMEROLLE_CHAUD:
					var k := 1.0 - d / R.FUMEROLLE_CHAUD
					c = maxf(c, R.FUMEROLLE_CHALEUR * k * k + 40.0 * crache(s) * clampf(1.0 - d / (R.FUMEROLLE_BRULE * 1.6), 0.0, 1.0))
			"faille":
				var d := _vers_le_trait(p, s["trait"])
				if d < R.FAILLE_CHAUD:
					c = maxf(c, R.FAILLE_CHALEUR * (1.0 - d / R.FAILLE_CHAUD))
	return c


# la bouffée d'une fumerolle, à cette heure : de 0 (rien) à 1
func crache(s: Dictionary) -> float:
	var t := fposmod(float(jeu.horloge) + float(s["phase"]), float(s["periode"]))
	return pow(sin(PI * t / BOUFFEE), 0.4) if t < BOUFFEE else 0.0


func siffle(s: Dictionary) -> bool:
	var t := fposmod(float(jeu.horloge) + float(s["phase"]), float(s["periode"]))
	return t > float(s["periode"]) - SIFFLE


# le pied dans une faille ?
func dans_la_faille(p: Vector2) -> bool:
	for s in _autour(p, 200.0):
		if str(s["genre"]) == "faille" and _vers_le_trait(p, s["trait"]) < float(s["large"]) * 0.8 + 4.0:
			return true
	return false


# ce qui reste d'une chose qu'on ramasse (le bois flotté revient : la mer en rapporte)
func reste(s: Dictionary) -> int:
	var plein := int(s.get("plein", 0))
	var v = _pris.get(s["id"])
	if v == null:
		return plein
	if str(s["genre"]) == "bois_flotte" and float(jeu.horloge) - float(v[1]) > R.BOIS_FLOTTE_REVIENT:
		_pris.erase(s["id"])
		return plein
	return int(v[0])


# les choses des cases autour de p (toutes celles dont la case est à moins de « rayon » de p)
func _autour(p: Vector2, rayon: float) -> Array:
	var out: Array = []
	var a := Vector2i(((p - Vector2(rayon, rayon)) / CASE).floor())
	var b := Vector2i(((p + Vector2(rayon, rayon)) / CASE).floor())
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var l = _cases.get(Vector2i(x, y))
			if l != null:
				out.append_array(l)
	return out


static func _vers_le_trait(p: Vector2, t: PackedVector2Array) -> float:
	var d0 := INF
	for i in t.size() - 1:
		d0 = minf(d0, p.distance_to(Geometry2D.get_closest_point_to_segment(p, t[i], t[i + 1])))
	return d0


# la plus proche de ce genre (l'essai, la vitrine) ; {} s'il n'y en a pas autour
func le_plus_proche(genre: String, p: Vector2) -> Dictionary:
	var mieux := {}
	var d0 := INF
	for k in _cases:
		for s in _cases[k]:
			if str(s["genre"]) == genre and p.distance_to(s["p"]) < d0:
				d0 = p.distance_to(s["p"])
				mieux = s
	return mieux


# --- chaque image ---

func maj(delta: float) -> void:
	var j = jeu.joueur
	if j == null:
		return
	_t += delta
	var p: Vector2 = j.position
	_revoir -= delta
	if _revoir <= 0.0:
		_revoir = 0.25
		suivre(p)
	_dangers(delta, p)
	_entendre(delta, p)
	if _sale:
		_sale = false
		_lave.queue_redraw()
	# (la lave bat lentement ; les feux follets ne se montrent que la nuit)
	var nuit := 1.0 - float(jeu.lumiere_du_jour())
	_lave.modulate = Color(1, 1, 1, (0.4 + 0.6 * nuit) * (0.8 + 0.2 * sin(_t * 1.7) * sin(_t * 0.63 + 1.0)))
	_follets_(delta, p)


# ce qui la menace, là où elle est
func _dangers(delta: float, p: Vector2) -> void:
	var j = jeu.joueur
	if j.morte:
		enlise = 0.0
		return
	var C = jeu.climat
	# la faille : y mettre le pied, c'est prendre feu
	if dans_la_faille(p) and float(C.eau(p)) < 0.3:
		if j.en_feu <= 0.0:
			jeu.enflammer_joueur()
		jeu._conseil("faille", true, "Une faille : la lave est à fleur de roche. Fais-en le tour.", Color(0.98, 0.6, 0.4))
	# la bouffée d'une fumerolle : elle brûle qui est tout contre
	var brule := false
	for s in _autour(p, R.FUMEROLLE_BRULE + 10.0):
		if str(s["genre"]) != "fumerolle" or p.distance_to(s["p"]) > R.FUMEROLLE_BRULE:
			continue
		var c := crache(s)
		if c > 0.15:
			brule = true
			jeu._mal("vapeur", R.FUMEROLLE_DEGATS * c * delta)
			j.peur = minf(100.0, j.peur + 6.0 * delta)
			if not _ebouillantee:
				_ebouillantee = true
				jeu.effets.blessure()
				jeu.ui.blessure()
				jeu._conseil("fumerolle", true, "La vapeur brûle ! Une fumerolle siffle avant de cracher : écarte-toi.", Color(0.98, 0.6, 0.4))
	if not brule:
		_ebouillantee = false
	# la fondrière : qui s'arrête s'enfonce, qui marche s'en tire, lentement
	var e := 0.0
	if not _vases.is_empty():
		var garde := enlise
		enlise = 0.0
		e = fondriere(p)
		enlise = garde
	if e > 0.05 and j.monture == null:
		enlise = clampf(enlise + (-R.FONDRIERE_SORT if j.en_mouvement else R.FONDRIERE_ENLISE) * delta, 0.0, 1.0)
		_enfoncee = _enfoncee + delta if enlise > 0.5 else maxf(0.0, _enfoncee - delta)
		if enlise > 0.3:
			jeu._conseil("fondriere", true, "La fondrière t'aspire. Ne t'arrête pas : marche pour t'en tirer.", Color(0.72, 0.82, 0.92))
		if _enfoncee > 3.0:
			# (l'odeur des aromates, gardée sur elle depuis leur fumée, tient les sangsues : scripts/botanique.gd, impregnee)
			if jeu.get("botanique") != null and jeu.botanique.impregnee():
				jeu._conseil("sangsues_aromates", true, "Les sangsues approchent, puis s'écartent : l'odeur des aromates les tient.", Color(0.72, 0.84, 0.6))
			else:
				jeu._mal("sangsues", R.SANGSUES * delta)
				jeu._conseil("sangsues", true, "Des sangsues ! Sors de cette eau dormante.", Color(0.85, 0.6, 0.55))
	else:
		enlise = maxf(0.0, enlise - 2.0 * delta)
		_enfoncee = 0.0


# ce qu'on entend : la fumerolle qui siffle puis crache, la vase qui glougloute, la lave qui crache, près d'elle
func _entendre(delta: float, p: Vector2) -> void:
	var S = jeu.sons
	if S == null or not S.has_method("au_loin"):
		return
	for s in _autour(p, 900.0):
		var genre: String = s["genre"]
		if genre != "fumerolle":
			continue
		var c := crache(s)
		var avant := bool(_crachait.get(s["id"], false))
		if c > 0.0 and not avant:
			S.au_loin("vapeur", s["p"], -2.0, randf_range(0.55, 0.7), 900.0)
		elif c <= 0.0 and siffle(s) and not bool(_crachait.get(str(s["id"]) + "s", false)):
			S.au_loin("presage", s["p"], -14.0, randf_range(1.6, 1.8), 600.0)
		_crachait[str(s["id"]) + "s"] = siffle(s)
		_crachait[s["id"]] = c > 0.0
	_bulle -= delta
	if _bulle <= 0.0:
		_bulle = randf_range(1.2, 3.0)
		var proche := {}
		var d0 := 500.0
		for s in _autour(p, 500.0):
			var genre: String = s["genre"]
			if (genre == "fondriere" or genre == "faille") and p.distance_to(s["p"]) < d0:
				d0 = p.distance_to(s["p"])
				proche = s
		if not proche.is_empty():
			if str(proche["genre"]) == "fondriere":
				S.au_loin("goutte%d" % (randi() % 4), proche["p"], -6.0, randf_range(0.35, 0.5), 500.0)
			else:
				S.au_loin("crache%d" % (randi() % 3), proche["p"], -10.0, randf_range(0.5, 0.7), 500.0)


# les feux follets : la nuit, au-dessus des fondrières qui en ont ; ils s'écartent quand elle approche, et reviennent
func _follets_(delta: float, p: Vector2) -> void:
	var nuit := 1.0 - float(jeu.lumiere_du_jour())
	var vus := false
	for s in _autour(p, 1100.0):
		if str(s["genre"]) != "fondriere" or not bool(s.get("follet", false)):
			continue
		var f: Array = _follets.get(s["id"], [])
		if f.is_empty():
			f = [Vector2(s["p"]) + Vector2(0.0, -18.0), 0.0, randf() * TAU]
			_follets[s["id"]] = f
		var ou: Vector2 = f[0]
		var loin := ou.distance_to(p)
		# (de nuit, ils luisent ; trop près d'elle, ils s'éteignent et filent plus loin)
		var cible := smoothstep(0.4, 0.8, nuit) * smoothstep(110.0, 220.0, loin)
		f[1] = move_toward(float(f[1]), cible, delta * (0.6 if cible > float(f[1]) else 1.6))
		f[2] = float(f[2]) + delta
		var but: Vector2 = Vector2(s["p"]) + Vector2(cos(float(f[2]) * 0.37), sin(float(f[2]) * 0.29) * 0.6) * float(s["taille"]) * 0.8 + Vector2(0.0, -18.0)
		if loin < 160.0:
			but = ou + (ou - p).normalized() * 120.0
		f[0] = ou.lerp(but, 1.0 - exp(-delta * 0.8))
		if float(f[1]) > 0.01:
			vus = true
	if vus or _air.get_meta("vus", false):
		_air.queue_redraw()
	_air.set_meta("vus", vus)


# --- ce qu'on y ramasse ---

# « Agir » : la chose la plus proche à portée de main (vrai : elle s'en est servie, le jeu n'en fait rien d'autre)
func agir() -> bool:
	var j = jeu.joueur
	var p: Vector2 = j.position
	var mieux := {}
	var d0 := R.PORTEE_RECOLTE + 14.0
	for s in _autour(p, 120.0):
		var genre: String = s["genre"]
		if not DEBOUT.has(genre) and genre != "mare":
			continue
		var d: float = p.distance_to(s["p"]) - (float(s["taille"]) * 0.7 if genre == "mare" else 0.0)
		if d < d0:
			d0 = d
			mieux = s
	if mieux.is_empty():
		return false
	var genre: String = mieux["genre"]
	var b: Dictionary = Biomes.BUTINS[genre]
	if genre == "mare":
		return _puiser(mieux)
	var n := reste(mieux)
	if n <= 0:
		jeu.ui.message("Il n'y a plus rien à en tirer." if genre != "bois_flotte" else "Plus de bois ici. La mer en rapportera.", Color(0.75, 0.7, 0.66))
		return true
	j.geste(str(b["geste"]), mieux["p"])
	jeu._viser({"son": str(b["son"]), "db": -4.0, "p": mieux["p"], "genre": "rocher" if str(b["geste"]) == "rocher" else "brindille"})
	_pris[mieux["id"]] = [n - 1, snappedf(float(jeu.horloge), 0.1)]
	var noeud = mieux.get("noeud")
	if noeud != null and is_instance_valid(noeud):
		noeud.queue_redraw()
	var k: String = b["donne"]
	var pris: int = jeu.atelier.ranger(k, int(b["n"]))
	if pris > 0:
		jeu.ui.ramasse(k, pris, mieux["p"])
	jeu._conseil("butin_" + genre, true, str(b["dit"]), Color(0.95, 0.75, 0.45))
	return true


# (la banquise) la glace d'une mare : sous elle, de l'eau, si l'on a de quoi l'emporter
func _puiser(s: Dictionary) -> bool:
	var j = jeu.joueur
	var A = jeu.atelier
	if A.possede("gourde") <= 0:
		jeu.ui.message("Sous la glace, de l'eau. Il te faudrait une gourde pour l'emporter.", Color(0.75, 0.7, 0.66))
		return true
	var inv: Dictionary = j.inventaire
	var place: int = A.GORGEES - int(inv.get("eau", 0))
	if place <= 0:
		jeu.ui.message("Ta gourde est pleine.", Color(0.75, 0.7, 0.66))
		return true
	j.geste("rocher", s["p"])
	jeu._viser({"son": "pierre", "db": -6.0, "p": s["p"], "genre": "rocher"})
	inv["eau"] = int(inv.get("eau", 0)) + place
	jeu.sons.atelier("gourde")
	if jeu._deja.has("butin_mare"):
		jeu.ui.message("Ta gourde est pleine.", Color(0.72, 0.82, 0.92))
	jeu._conseil("butin_mare", true, str(Biomes.BUTINS["mare"]["dit"]), Color(0.72, 0.82, 0.92))
	return true


# « Nourrir le feu » : la tourbe d'abord, qui le tient bien plus longtemps qu'une bûche (vrai : c'est fait)
func nourrir(f) -> bool:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("tourbe", 0)) <= 0:
		return false
	inv["tourbe"] = int(inv["tourbe"]) - 1
	var mort: bool = not f.allume()
	f.bois = minf(R.FEU_MAX, float(f.bois) + R.TOURBE_FEU)
	if mort:
		f.gerbe(0.7)
	else:
		f.aviver()
	jeu.sons.jouer("allume", -10.0, 0.85)
	jeu._conseil("tourbe_au_feu", true, "La tourbe prend lentement, en fumant : le feu tiendra longtemps.", Color(0.95, 0.75, 0.45))
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		b.gerbe(f)
	return true


# --- la partie gardée : ce qu'on y a pris ---

func photo() -> Dictionary:
	var pris := {}
	for id in _pris:
		pris[id] = [int(_pris[id][0]), snappedf(float(_pris[id][1]), 0.1)]
	return {"pris": pris}


func reprendre(d: Dictionary) -> void:
	for id in d.get("pris", {}):
		var v = d["pris"][id]
		if typeof(v) == TYPE_ARRAY and v.size() >= 2:
			_pris[str(id)] = [int(v[0]), float(v[1])]
	for k in _cases:
		for s in _cases[k]:
			var n = s.get("noeud")
			if n != null and is_instance_valid(n):
				n.queue_redraw()


# --- le dessin ---

func _dessiner(ci: CanvasItem, quoi: String) -> void:
	match quoi:
		"fonds", "sol":
			# (une case : ce qu'elle a à plat, de son calque)
			var p := Pinceau.new()
			p.commencer(ci.get_canvas_item())
			for s in _cases.get(ci.case, []):
				var genre: String = s["genre"]
				if A_PLAT.has(genre) and FONDS.has(genre) == (quoi == "fonds"):
					Dessins.a_plat(p, s, _mobile)
			p.finir()
		"lave":
			var p := Pinceau.new()
			p.commencer(ci.get_canvas_item())
			for k in _cases:
				for s in _cases[k]:
					if str(s["genre"]) == "faille":
						Dessins.lave(p, s)
			p.finir()
		"air":
			var halo := T.lueur()
			var vert := P.ECHO.lerp(P.MOUSSE, 0.35)
			for id in _follets:
				var f: Array = _follets[id]
				var a := float(f[1])
				if a <= 0.01:
					continue
				var c: Vector2 = Vector2(f[0]) + Vector2(0.0, sin(float(f[2]) * 2.3) * 4.0)
				var batte := 0.75 + 0.25 * sin(float(f[2]) * 5.0)
				ci.draw_texture_rect(halo, Rect2(c - Vector2(70, 56), Vector2(140, 112)), false, Color(vert, 0.3 * a * batte))
				ci.draw_texture_rect(halo, Rect2(c - Vector2(26, 26), Vector2(52, 52)), false, Color(vert.lightened(0.3), 0.75 * a * batte))
				ci.draw_texture_rect(halo, Rect2(c - Vector2(9, 9), Vector2(18, 18)), false, Color(P.ECHO, a))
				ci.draw_circle(c, 2.4, Color(P.PAPIER, a))


# un calque du lieu (le sol, la lave, l'air) : il demande son dessin au terrain
class Calque extends Node2D:
	var terrain
	var quoi := ""
	var case := Vector2i.ZERO

	func _draw() -> void:
		if terrain != null:
			terrain._dessiner(self, quoi)


# ce qui se tient debout (l'obsidienne, la tourbe, le bois flotté, la carcasse) : au pied, trié avec le lieu
class Debout extends Node2D:
	var terrain
	var s: Dictionary

	func _draw() -> void:
		if terrain == null:
			return
		var p := Pinceau.new()
		p.commencer(get_canvas_item())
		# (dessinées à l'échelle des rochers du lieu)
		RenderingServer.canvas_item_add_set_transform(get_canvas_item(), Transform2D(0.0, Vector2(1.35, 1.35), 0.0, Vector2.ZERO))
		Dessins.debout(p, s, int(terrain.reste(s)))
		p.finir()


# la vapeur d'une fumerolle : des volutes, toujours ; une bouffée quand elle crache (elle monte, le vent la couche)
class Fumee extends Node2D:
	var terrain
	var s: Dictionary
	var _volutes: CPUParticles2D
	var _bouffee: CPUParticles2D

	func _ready() -> void:
		var mobile: bool = str(terrain.jeu.qualite) == "mobile"
		_volutes = _vapeur(10 if mobile else 18, 2.8, 20.0, 0.5)
		_bouffee = _vapeur(22 if mobile else 46, 1.7, 120.0, 0.6)
		_bouffee.emitting = false

	func _vapeur(n: int, vie: float, vitesse: float, alpha: float) -> CPUParticles2D:
		var c := CPUParticles2D.new()
		c.amount = n
		c.lifetime = vie
		c.lifetime_randomness = 0.4
		c.texture = T.point_doux()
		c.position = Vector2(0.0, -4.0)
		c.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		c.emission_sphere_radius = 5.0
		c.direction = Vector2(0.0, -1.0)
		c.spread = 14.0
		c.initial_velocity_min = vitesse * 0.6
		c.initial_velocity_max = vitesse
		c.gravity = Vector2(0.0, -6.0)
		c.damping_min = vitesse * 0.3
		c.damping_max = vitesse * 0.6
		c.scale_amount_min = 0.35
		c.scale_amount_max = 0.7
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
		var blanc := P.PAPIER.lightened(0.2)
		g.colors = PackedColorArray([Color(blanc, 0.0), Color(blanc, alpha), Color(P.IVOIRE, alpha * 0.55), Color(P.IVOIRE, 0.0)])
		c.color_ramp = g
		var k := Curve.new()
		k.add_point(Vector2(0.0, 0.5))
		k.add_point(Vector2(1.0, 2.6))
		c.scale_amount_curve = k
		add_child(c)
		return c

	func _process(_delta: float) -> void:
		if terrain == null or terrain.jeu == null or terrain.jeu.climat == null:
			return
		var C = terrain.jeu.climat
		var vent: Vector2 = C.vent_dir * float(C.vent) * 60.0
		_volutes.gravity = Vector2(0.0, -6.0) + vent
		_bouffee.gravity = Vector2(0.0, -10.0) + vent * 1.5
		_bouffee.emitting = terrain.crache(s) > 0.05
		_volutes.speed_scale = 1.6 if terrain.siffle(s) else 1.0
