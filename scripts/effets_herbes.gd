extends RefCounted
# Lisière — ce que les herbes font voir (scripts/effets_herbes.gd)
# Les règles sont dans scripts/botanique.gd ; ici, rien que ce qu'on en voit. Les effets (scripts/effets.gd) tiennent ce
# fichier (jeu.effets.herbes), l'avancent chaque image (maj) et en reçoivent ce que l'écran doit montrer ; le corps de la
# veilleuse (scripts/joueur.gd), la caméra et la couche des yeux (scripts/yeux.gd) y lisent le reste, pour que tout batte
# ensemble : le même cœur pour l'image qui se dédouble et pour elle qui se plie, la même paupière pour l'écran et pour sa tête
# qui tombe.
#  - le poison : l'image verdit par les bords, tangue, se dédouble au rythme du cœur ; un haut-le-cœur de temps en temps ;
#    quand il la quitte, un soupir ;
#  - la torpeur : les paupières tombent lentement, tiennent, se rouvrent d'un coup, de plus en plus lourdes ;
#  - les visions : des yeux qui n'existent pas s'ouvrent dans le noir, par paires, violets (jamais l'ambre d'un chasseur ni le
#    pâle d'une proie : on apprend à ne pas les croire), et des guetteurs au bord de l'écran, toujours dans son dos ;
#  - la voyance : chaque bête se devine dans le noir (un contour pâle, à la couleur de ses yeux), un fil de lueur part vers la
#    tanière de la Noire ;
#  - la fumée âcre d'un feu (la classe Fumee, que scripts/feu.gd monte le temps qu'elle dure) ; et, de la même classe, la
#    fumée bleue des aromates jetés au feu (sorte « encens »), plus fine, qui monte plus haut et sent la résine.
# Rien ici ne change une règle.

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")
const NAPPE := preload("res://shaders/fumee_nappe.gdshader")
const COLONNE := preload("res://shaders/fumee_colonne.gdshader")
const C_POISON := Color(0.45, 0.55, 0.17)
const C_VOYANCE := Color(0.53, 0.72, 0.95)
const OCRE := Color(0.69, 0.5, 0.25)
const OCRE_SOMBRE := Color(0.3, 0.23, 0.15)
# (la fumée des aromates : la lune et l'ivoire, un souffle de mousse ; son ombre, le bleu de la nuit vers la mousse)
const ENCENS := Color(0.59, 0.62, 0.64)
const ENCENS_SOMBRE := Color(0.18, 0.24, 0.24)
const MACHE := 1.0               # secondes : tant qu'elle mâche (le geste « gouter »), rien ne l'a encore prise
const NAUSEE := 1.15             # secondes : un haut-le-cœur
const SOUPIR := 2.0              # secondes : le poison la quitte, elle se redresse et souffle
const FOND := 0.9                # jusqu'où les paupières se ferment (jamais tout à fait : il reste une fente pour jouer)

var jeu
# ce qu'on lit d'ici, de 0 à 1
var poison := 0.0
var pouls := 0.0                 # le cœur du poison : deux coups qui retombent
var nausee := 0.0                # un haut-le-cœur : il monte d'un coup et retombe
var soupir := 0.0                # le poison vient de la quitter
var torpeur := 0.0
var paupiere := 0.0              # 0 : ouverte ; 1 : close
var sursaut := 0.0               # ses paupières se rouvrent : sa tête se relève d'un coup
var visions := 0.0
var voyance := 0.0
var devie := 0.0                 # radians : ses pas dévient
var tangage := 0.0               # la caméra : radians
var derive := Vector2.ZERO       # la caméra : pixels
var fantomes: Array = []         # les yeux qui n'existent pas : { ou, r, ecart, vie, age, ouvert, cligne, part }
var guetteurs: Array = []        # les silhouettes au bord de l'écran : { cote, y, taille, a, age, vie, graine }
var _t := 0.0
var _battu := 0.0
var _malade := false
var _nausee_t := -1.0
var _nausee_dans := 1.2
var _soupir_t := -1.0
var _cycle_t := 0.0
var _tombe := 2.8
var _tient := 0.2
var _fond := 0.6
var _reste := 0.0
var _reste_apres := 0.08
var _lourd := 0
var _fantome_dans := 0.0
var _guet_dans := 0.0
var _guet_n := 0
var _avant := Vector2.INF
var _calque: Node2D
var _mobile := false
var _nuit := 0.0


# une partie commence ; dessous : un calque de l'écran, sous le voile (scripts/effets_ecran.gd), où se tiennent les guetteurs
func commencer(dessous: Node2D) -> void:
	vider()
	_mobile = jeu != null and str(jeu.get("qualite")) == "mobile"
	if dessous != null and is_instance_valid(dessous):
		var g := Guetteurs.new()
		g.herbes = self
		dessous.add_child(g)
		_calque = g


func vider() -> void:
	poison = 0.0
	pouls = 0.0
	nausee = 0.0
	soupir = 0.0
	torpeur = 0.0
	paupiere = 0.0
	sursaut = 0.0
	visions = 0.0
	voyance = 0.0
	devie = 0.0
	tangage = 0.0
	derive = Vector2.ZERO
	fantomes.clear()
	guetteurs.clear()
	_malade = false
	_nausee_t = -1.0
	_soupir_t = -1.0
	_cycle_t = 0.0
	_lourd = 0
	_guet_n = 0
	_avant = Vector2.INF
	if _calque != null and is_instance_valid(_calque):
		_calque.queue_free()
	_calque = null


# vrai quand l'image doit être lue (la passe d'écran, en qualité haute : scripts/effets_ecran.gd)
func lit() -> bool:
	return poison > 0.01 or paupiere > 0.02 or torpeur > 0.02 or visions > 0.01 or voyance > 0.01


# chaque image : l'état des herbes (scripts/botanique.gd), adouci ; rend ce que les shaders de l'écran en attendent
func maj(delta: float, nuit: float) -> Dictionary:
	_t += delta
	_nuit = nuit
	var B = jeu.get("botanique") if jeu != null else null
	var j = jeu.joueur if jeu != null else null
	var c_poison := 0.0
	var c_torpeur := 0.0
	var c_visions := 0.0
	var c_voyance := 0.0
	if B != null and j != null and not j.morte:
		c_poison = clampf(float(B.poison) / 2.5, 0.0, 1.0)
		c_torpeur = clampf(float(B.torpeur) / 3.0, 0.0, 1.0)
		c_visions = clampf(float(B.visions) / 3.0, 0.0, 1.0)
		c_voyance = clampf(float(B.voyance) / 4.0, 0.0, 1.0)
		# (elle mâche encore : ce qu'elle vient d'avaler ne monte qu'au moment où son corps réagit)
		if str(j.get("atelier")) == "gouter" and float(j.get("atelier_t")) < MACHE:
			c_poison = minf(c_poison, poison)
			c_torpeur = minf(c_torpeur, torpeur)
			c_visions = minf(c_visions, visions)
	_empoisonner(delta, c_poison)
	_assoupir(delta, c_torpeur)
	visions = move_toward(visions, c_visions, delta * (0.8 if c_visions > visions else 0.55))
	voyance = move_toward(voyance, c_voyance, delta * 0.45)
	if j != null:
		_hanter(delta, nuit, j)
		_guetter(delta, j)
	# la caméra : elle tangue avec le poison, plonge au haut-le-cœur ; la torpeur la fait pencher, très lentement
	tangage = poison * (0.02 * sin(_t * 1.15) + 0.008 * pouls) + nausee * 0.02 + torpeur * 0.007 * sin(_t * 0.52)
	derive = Vector2(sin(_t * 0.9) * 5.0, cos(_t * 0.7) * 3.0) * poison + Vector2(0.0, 9.0 * nausee + 5.0 * paupiere)
	devie = poison * (0.34 * sin(_t * 1.7) + 0.2 * sin(_t * 0.63 + 1.3)) + nausee * 0.3 * sin(_t * 9.0)
	return {"poison": poison, "pouls": clampf(pouls + 0.9 * nausee, 0.0, 1.4), "torpeur": torpeur, "paupiere": paupiere,
		"flou": clampf(paupiere * 1.15 + torpeur * 0.22, 0.0, 1.0), "visions": visions, "voyance": voyance}


# --- le poison ---

func _empoisonner(delta: float, cible: float) -> void:
	poison = move_toward(poison, cible, delta * (1.8 if cible > poison else 1.1))
	if cible > 0.5:
		_malade = true
	elif _malade and cible <= 0.0:
		# (il la quitte : il s'est éteint, ou un baume l'a chassé)
		_malade = false
		_soupir_t = 0.0
		_nausee_t = -1.0
	if _soupir_t >= 0.0:
		_soupir_t += delta
		soupir = sin(PI * clampf(_soupir_t / SOUPIR, 0.0, 1.0))
		if _soupir_t >= SOUPIR:
			_soupir_t = -1.0
			soupir = 0.0
	# son cœur : lourd, lent, deux coups
	_battu += delta
	if _battu > 0.92:
		_battu = 0.0
	var b := _battu
	pouls = (exp(-b * 8.0) + (0.62 * exp(-(b - 0.2) * 8.0) if b > 0.2 else 0.0)) * poison
	# les haut-le-cœur : le premier vient vite, les autres toutes les quatre secondes ou presque
	if poison > 0.5 and _malade:
		if _nausee_t < 0.0:
			_nausee_dans -= delta
			if _nausee_dans <= 0.0:
				_nausee_t = 0.0
				_nausee_dans = randf_range(3.0, 5.2)
	else:
		_nausee_dans = minf(_nausee_dans, 1.2)
	if _nausee_t >= 0.0:
		_nausee_t += delta
		var u := clampf(_nausee_t / NAUSEE, 0.0, 1.0)
		nausee = pow(sin(PI * pow(u, 0.55)), 2.0)
		if _nausee_t >= NAUSEE:
			_nausee_t = -1.0
			nausee = 0.0
	else:
		nausee = 0.0


# --- la torpeur ---

# les paupières : un cycle après l'autre. Elles tombent lentement (en luttant un peu), tiennent closes un instant, se rouvrent
# d'un coup, jamais tout à fait ; et chaque fois elles tombent plus vite, plus bas, et tiennent plus longtemps
func _assoupir(delta: float, cible: float) -> void:
	torpeur = move_toward(torpeur, cible, delta * (0.5 if cible > torpeur else 0.7))
	sursaut = maxf(0.0, sursaut - delta * 2.4)
	if torpeur <= 0.02:
		paupiere = move_toward(paupiere, 0.0, delta * 2.0)
		_cycle_t = 0.0
		_lourd = 0
		_reste = 0.0
		_reste_apres = 0.08
		_fond = 0.6
		_tombe = 2.8
		_tient = 0.2
		return
	_cycle_t += delta
	var u := _cycle_t
	var p := 0.0
	if u < _tombe:
		var x := u / _tombe
		p = lerpf(_reste, _fond, x * x * (3.0 - 2.0 * x)) + 0.05 * sin(u * 7.0) * x * (1.0 - x)
	elif u < _tombe + _tient:
		p = _fond
	elif u < _tombe + _tient + 0.28:
		var x := (u - _tombe - _tient) / 0.28
		if sursaut <= 0.0 and x < 0.3:
			sursaut = 1.0
		p = lerpf(_fond, _reste_apres, 1.0 - pow(1.0 - x, 3.0))
	else:
		_lourd += 1
		_cycle_t = 0.0
		_reste = _reste_apres
		_reste_apres = minf(0.32, 0.08 + 0.04 * _lourd)
		_fond = minf(FOND, randf_range(0.6, 0.74) + 0.05 * _lourd)
		_tombe = maxf(1.5, randf_range(2.3, 3.2) - 0.16 * _lourd)
		_tient = minf(0.6, randf_range(0.16, 0.3) + 0.06 * _lourd)
		p = _reste
	paupiere = clampf(p, 0.0, FOND) * torpeur


# --- les visions : des yeux qui n'existent pas ---

func _hanter(delta: float, nuit: float, j) -> void:
	var ici: Vector2 = j.position
	var pas := ici - _avant if _avant != Vector2.INF and ici.distance_to(_avant) < 60.0 else Vector2.ZERO
	_avant = ici
	var la := visions > 0.05 and nuit > 0.3
	var i := fantomes.size() - 1
	while i >= 0:
		var f: Dictionary = fantomes[i]
		f["age"] = float(f["age"]) + delta
		# (ils la suivent : quand elle marche, ils glissent avec elle, moins vite)
		f["ou"] = Vector2(f["ou"]) + pas * 0.3
		var ou: Vector2 = f["ou"]
		# la lumière les chasse, et qu'on vienne trop près ; leur temps passé, ils se referment
		if not bool(f["part"]) and (not la or float(f["age"]) > float(f["vie"]) or ou.distance_to(ici) < 86.0 or float(jeu.eclairage(ou)) > 0.3):
			f["part"] = true
		f["ouvert"] = move_toward(float(f["ouvert"]), 0.0 if bool(f["part"]) else 1.0, delta * (5.0 if bool(f["part"]) else 1.5))
		f["cligne"] = float(f["cligne"]) - delta
		if float(f["cligne"]) < -0.13:
			f["cligne"] = randf_range(1.2, 3.6)
		if bool(f["part"]) and float(f["ouvert"]) <= 0.0:
			fantomes.remove_at(i)
		i -= 1
	_fantome_dans -= delta
	if la and _fantome_dans <= 0.0 and fantomes.size() < (4 if _mobile else 7):
		_fantome_dans = randf_range(0.3, 0.95) / maxf(visions, 0.3)
		for essai in 6:
			# (n'importe où dans le noir qu'on voit autour d'elle : un grand feu ne leur laisse que les bords de l'écran)
			var ou := ici + Vector2(randf_range(-450.0, 450.0), randf_range(-225.0, 215.0))
			if ou.distance_to(ici) < 120.0 or float(jeu.eclairage(ou)) > 0.12:
				continue
			# (certains sont grands, certains trop hauts pour une bête)
			var gros := randf() < 0.22
			var r := randf_range(3.0, 4.2) if gros else randf_range(1.6, 2.6)
			fantomes.append({"ou": ou + Vector2(0.0, -randf_range(6.0, 30.0) - (26.0 if gros else 0.0)), "r": r, "ecart": r * randf_range(2.0, 2.8),
				"vie": randf_range(2.6, 6.0), "age": 0.0, "ouvert": 0.0, "cligne": randf_range(0.8, 3.0), "part": false})
			break


# dans la couche des yeux (scripts/yeux.gd : additive, au-dessus de l'obscurité) : chaque paire, ses deux amandes tournées vers
# le nez, leur cœur plus clair qui glisse vers elle (ils la regardent)
func peindre_fantomes(ci: CanvasItem, amande: Texture2D, doux: Texture2D) -> void:
	if fantomes.is_empty() or jeu == null or jeu.joueur == null:
		return
	var ici: Vector2 = jeu.joueur.position + Vector2(0.0, -22.0)
	var c := P.PEUR.lerp(P.ECHO, 0.25)
	for f in fantomes:
		var a: float = float(f["ouvert"]) * (0.9 + 0.1 * sin(_t * 2.1 + float(f["vie"]) * 9.0))
		if a <= 0.02:
			continue
		var ou: Vector2 = f["ou"]
		var h: float = float(f["r"]) * 7.0
		for cote in [-1.0, 1.0]:
			var q: Vector2 = ou + Vector2(cote * float(f["ecart"]), 0.0)
			ci.draw_texture_rect(doux, Rect2(q - Vector2(h, h * 0.8), Vector2(h * 2.0, h * 1.6)), false, Color(c, 0.2 * a))
	for f in fantomes:
		var ouvert: float = float(f["ouvert"]) * (0.0 if float(f["cligne"]) < 0.0 else 1.0)
		if ouvert <= 0.05:
			continue
		var ou: Vector2 = f["ou"]
		var r: float = f["r"]
		var vers := (ici - ou).normalized()
		for cote in [-1.0, 1.0]:
			var q: Vector2 = ou + Vector2(cote * float(f["ecart"]), 0.0)
			# (l'image regarde à droite : sa pointe va vers le nez, et tombe un peu)
			var axe := Vector2(-cote, 0.2).normalized()
			var haut := Vector2(0.0, 1.0)
			ci.draw_set_transform_matrix(Transform2D(axe * r * 2.3, haut * r * 1.5 * ouvert, q))
			ci.draw_texture_rect(amande, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c, ouvert))
			ci.draw_set_transform_matrix(Transform2D(axe * r * 1.4, haut * r * 0.92 * ouvert, q + vers * r * 0.42))
			ci.draw_texture_rect(amande, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c.lightened(0.55), ouvert * 0.85))
	ci.draw_set_transform(Vector2.ZERO)


# --- les visions : les guetteurs ---

# au bord de l'écran, toujours dans son dos ; qu'elle se tourne vers lui, il n'est plus là. Le suivant se tient plus près
func _guetter(delta: float, j) -> void:
	var regard: float = float(j.regard)
	var derriere := false
	var i := guetteurs.size() - 1
	while i >= 0:
		var g: Dictionary = guetteurs[i]
		g["age"] = float(g["age"]) + delta
		var vu: bool = float(g["cote"]) * regard > 0.0
		var cible := 0.0 if vu or float(g["age"]) > float(g["vie"]) or visions < 0.2 else visions
		var a: float = g["a"]
		a = move_toward(a, cible, delta * (5.0 if cible < a else 0.4))
		g["a"] = a
		if a <= 0.0 and cible <= 0.0:
			guetteurs.remove_at(i)
		elif not vu:
			derriere = true
		i -= 1
	_guet_dans -= delta
	if visions > 0.3 and _guet_dans <= 0.0 and not derriere and guetteurs.size() < 2:
		_guet_n += 1
		guetteurs.append({"cote": -regard, "y": randf_range(-1.0, 1.0), "taille": minf(1.42, 0.86 + 0.11 * _guet_n + randf_range(0.0, 0.08)),
			"a": 0.0, "age": 0.0, "vie": randf_range(4.5, 8.5), "graine": randf() * 60.0})
		_guet_dans = randf_range(1.2, 3.0)
	elif visions <= 0.02:
		_guet_n = 0


# une silhouette d'encre, trop longue : des épaules étroites, des bras qui pendent jusqu'aux genoux, la tête penchée vers le
# milieu de l'écran, le bas du corps qui se défait en coulures ; un liseré de lune du côté du dedans (la nuit, on la lit
# encore), deux points pâles pour les yeux, qui s'éteignent les premiers
func peindre_guetteur(ci: CanvasItem, g: Dictionary, s: Vector2) -> void:
	var a: float = g["a"]
	if a <= 0.01:
		return
	var cote: float = g["cote"]
	var taille: float = g["taille"]
	var gr: float = g["graine"]
	var H := s.y * 0.56 * taille
	var vers := -cote
	var pied := Vector2(s.x * 0.5 + cote * (s.x * 0.5 - H * 0.085 - 6.0), s.y * (0.9 + 0.2 * (taille - 1.0)) + float(g["y"]) * s.y * 0.05)
	var balance := sin(_t * 0.55 + gr) * 0.014
	var t := _t
	# (un point du corps : x et y en parts de sa hauteur ; il penche vers le dedans, se balance, et son bord tremble)
	var pos := func(x: float, y: float) -> Vector2:
		var dx := -balance * y + vers * 0.035 * y * y + 0.004 * sin(t * 1.3 + y * 11.0 + gr)
		return pied + Vector2((x + dx) * H, y * H)
	# (le jour, une ombre d'encre ; la nuit, où tout est déjà noir, une pâleur : ce qui reste d'une image dans l'œil)
	var encre := Color(P.NUIT.lerp(P.ENCRE, 0.4), a * 0.84).lerp(Color(P.LUNE.lerp(P.NUIT, 0.4), a * 0.34), _nuit)
	var corps := PackedVector2Array()
	for q in [[-0.1, -0.79], [0.1, -0.79], [0.062, -0.5], [0.07, -0.43], [0.052, -0.2], [0.046, -0.02], [0.031, -0.09], [0.018, 0.0], [0.0, -0.11],
			[-0.015, -0.01], [-0.03, -0.08], [-0.046, -0.03], [-0.05, -0.2], [-0.07, -0.43], [-0.062, -0.5]]:
		corps.append(pos.call(float(q[0]), float(q[1])))
	ci.draw_colored_polygon(corps, encre)
	ci.draw_colored_polygon(PackedVector2Array([pos.call(-0.021, -0.785), pos.call(0.021, -0.785), pos.call(0.017, -0.875), pos.call(-0.017, -0.875)]), encre)
	# la tête : un ovale étroit, penché
	var tete: Vector2 = pos.call(vers * 0.014, -0.925)
	var ovale := PackedVector2Array()
	for k in 12:
		var an := TAU * k / 12.0
		ovale.append(tete + Vector2(cos(an) * 0.043, sin(an) * 0.064).rotated(vers * 0.24 + balance * 3.0) * H)
	ci.draw_colored_polygon(ovale, encre)
	# les bras : trop longs, les doigts écartés
	var gros := maxf(2.0, 0.03 * H)
	for b in [-1.0, 1.0]:
		var bras := PackedVector2Array([pos.call(b * 0.094, -0.775), pos.call(b * 0.13, -0.56), pos.call(b * 0.124, -0.36), pos.call(b * 0.119, -0.3)])
		ci.draw_polyline(bras, encre, gros, true)
		for d in [-0.016, 0.0, 0.016]:
			ci.draw_line(pos.call(b * 0.12, -0.31), pos.call(b * 0.12 + d, -0.228 - 0.012 * absf(d) / 0.016), encre, maxf(1.0, 0.008 * H), true)
	# le liseré, du côté du dedans
	var lisere := Color(P.LUNE, a * lerpf(0.22, 0.34, _nuit))
	ci.draw_polyline(PackedVector2Array([pos.call(vers * 0.1, -0.79), pos.call(vers * 0.062, -0.5), pos.call(vers * 0.07, -0.43), pos.call(vers * 0.052, -0.2)]), lisere, 1.2, true)
	ci.draw_arc(tete, 0.05 * H, (-1.1 if vers > 0.0 else PI - 0.3), (0.3 if vers > 0.0 else PI + 1.1), 6, lisere, 1.2, true)
	var oeil := Color(P.PAPIER.lerp(P.PEUR, 0.35), a * a * 0.8)
	for d in [-0.016, 0.016]:
		ci.draw_circle(tete + Vector2(d + vers * 0.006, -0.008) * H, maxf(1.0, 0.0065 * H), oeil)


# --- la voyance ---

# dans la couche des yeux : chaque bête restée dans le noir se devine. Un souffle de lueur dans son corps, et son contour
# pâle, de la couleur de ses yeux, refroidie
func peindre_voyance(ci: CanvasItem, doux: Texture2D) -> void:
	if voyance <= 0.01 or jeu == null or jeu.joueur == null:
		return
	var ici: Vector2 = jeu.joueur.position
	var n := 14 if _mobile else 26
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		if not is_instance_valid(b) or str(b.role) == "echo" or b.position.distance_to(ici) > 760.0:
			continue
		var noir: float = clampf((0.7 - float(jeu.eclairage(b.position))) / 0.5, 0.0, 1.0) * voyance
		if noir <= 0.02:
			continue
		var large: float = b.largeur
		var sq = b.get("_sq")
		var haut: float = large * 0.6
		if sq is Dictionary and sq.has("haut"):
			haut = maxf(6.0, -float(sq["haut"]))
		haut *= 1.0 - 0.45 * float(b.couchee)
		var centre: Vector2 = b.position + Vector2(0.0, -haut * 0.5)
		var rx := large * 0.6
		var ry := haut * 0.64
		var role: String = str(b.role)
		var c: Color = P.OEIL_NOIRE if role == "noire" else (P.OEIL_CHASSEUR if role == "chasseur" or role == "rodeur" else P.OEIL_PROIE)
		c = c.lerp(C_VOYANCE, 0.5)
		ci.draw_texture_rect(doux, Rect2(centre - Vector2(rx, ry) * 1.15, Vector2(rx, ry) * 2.3), false, Color(c, 0.16 * noir))
		# son corps lui-même, deviné : ses images (le corps, la tête), posées de chaque côté d'elles-mêmes, en lueur — un liseré
		# pâle l'entoure, et elle s'éclaire à peine
		var images := 0
		for s in [b.get("sprite"), b.get("_tete")]:
			if s == null or not is_instance_valid(s) or s.texture == null or not s.is_visible_in_tree():
				continue
			images += 1
			ci.draw_set_transform_matrix(s.get_global_transform())
			var vit := 2.4 + 0.5 * sin(_t * 1.7 + float(b.get_instance_id() % 89))
			for dec in ([Vector2(-1.0, 0.0), Vector2(1.0, 0.0)] if _mobile else [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]):
				ci.draw_texture(s.texture, s.offset + dec * vit, Color(c, (0.3 if _mobile else 0.2) * noir))
		ci.draw_set_transform(Vector2.ZERO)
		if images > 0:
			continue
		# (une bête sans planche : un contour simple, qui l'enveloppe)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in n + 1:
			var an := TAU * k / n
			pts.append(centre + Vector2(cos(an) * rx, sin(an) * ry) * 0.85)
			var court := 0.5 + 0.5 * sin(an * 2.0 - _t * 1.6)
			cols.append(Color(c, noir * (0.1 + 0.4 * court * court)))
		ci.draw_polyline_colors(pts, cols, 1.1, true)


# le fil : de son cœur vers la tanière de la Noire. Il ondule, pâlit en s'éloignant ; des grains de lueur y filent. Tout près
# de la tanière, il s'y noue
func peindre_fil(ci: CanvasItem, doux: Texture2D) -> void:
	if voyance <= 0.01 or jeu == null or jeu.joueur == null:
		return
	var N = jeu.get("noire")
	if N == null or Vector2(N.taniere) == Vector2.ZERO:
		return
	var depart: Vector2 = jeu.joueur.position + Vector2(0.0, -24.0)
	var but: Vector2 = N.taniere
	var d := depart.distance_to(but)
	if d < 6.0:
		return
	var dir := (but - depart) / d
	var cote := Vector2(-dir.y, dir.x)
	var longueur := minf(d, 320.0)
	var pres := d <= 320.0
	var n := 14 if _mobile else 26
	var c := C_VOYANCE.lerp(P.ECHO, 0.4)
	var pts := PackedVector2Array()
	var fins := PackedColorArray()
	var larges := PackedColorArray()
	for k in n + 1:
		var u := float(k) / n
		var s := u * longueur
		var onde := (sin(s * 0.036 - _t * 1.3) * 4.5 + sin(s * 0.012 + _t * 0.6) * 9.0) * smoothstep(0.0, 0.3, u) * (1.0 - (smoothstep(0.75, 1.0, u) if pres else 0.0))
		pts.append(depart + dir * s + cote * onde)
		var a := voyance * smoothstep(0.0, 0.07, u) * (1.0 - 0.45 * u if pres else pow(1.0 - u, 1.25))
		fins.append(Color(c, 0.62 * a))
		larges.append(Color(c, 0.13 * a))
	ci.draw_polyline_colors(pts, larges, 4.5, true)
	ci.draw_polyline_colors(pts, fins, 1.1, true)
	for k in 4:
		var u := fposmod(_t * 0.2 + k * 0.25, 1.0)
		var x := u * n
		var i := mini(int(x), n - 1)
		var p := pts[i].lerp(pts[i + 1], x - float(i))
		var a := voyance * sin(PI * u) * (1.0 if pres else 1.0 - u)
		ci.draw_texture_rect(doux, Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), false, Color(c.lightened(0.4), 0.8 * a))
	if pres:
		# (la tanière est là : le fil s'y noue, un anneau qui bat)
		var r := 9.0 + 2.0 * sin(_t * 2.0)
		ci.draw_arc(but, r, 0.0, TAU, 20, Color(c, 0.4 * voyance), 1.1, true)
		ci.draw_texture_rect(doux, Rect2(but - Vector2(22.0, 16.0), Vector2(44.0, 32.0)), false, Color(c, 0.2 * voyance))


# le monde, la nuit, sous la voyance : la couleur de l'obscurité se lève vers un bleu froid (scripts/effets.gd, teinter)
func ouvrir_le_noir(c: Color) -> Color:
	if voyance <= 0.01:
		return c
	var sombre := 1.0 - clampf((c.r + c.g + c.b) / 2.2, 0.0, 1.0)
	return c.lerp(Color(0.3, 0.42, 0.66), 0.5 * voyance * sombre)


# --- les guetteurs : leur calque, dans la couche de l'écran, sous le voile ---

class Guetteurs extends Node2D:
	var herbes
	var _pas := 0.0
	var _vus := false

	func _process(delta: float) -> void:
		if herbes == null:
			return
		var la: bool = not herbes.guetteurs.is_empty()
		if la or _vus:
			# (ils bougent à peine : vingt fois par seconde suffisent)
			_pas -= delta
			if _pas <= 0.0:
				_pas = 0.05
				queue_redraw()
		_vus = la

	func _draw() -> void:
		if herbes == null:
			return
		var s := get_viewport_rect().size
		for g in herbes.guetteurs:
			herbes.peindre_guetteur(self, g, s)


# --- la fumée âcre d'un feu ---

# Une botte d'herbe âcre dans un feu (scripts/botanique.gd, fumee(feu)) : scripts/feu.gd monte ceci le temps qu'elle dure, et
# le défait ensuite. Une colonne ocre au-dessus du foyer, que le vent couche (un rectangle, shaders/fumee_colonne.gdshader) ;
# des bouffées qui s'en détachent et dérivent ; des escarbilles ; et au sol, sous tout ce qui se tient debout, la nappe qui
# s'étale jusqu'où les chasseurs sont tenus (shaders/fumee_nappe.gdshader). Elle prend en une seconde, s'étale en quatre,
# s'éteint avec « force ».
# Des aromates dans un feu (sorte « encens » : scripts/botanique.gd, encens_de) : la même, en bleu-gris de lune ; une colonne
# plus fine qui monte plus haut, des volutes qui tournent lentement, quelques brins qui crépitent, et la nappe jusqu'au bord de
# la lumière du feu.
class Fumee extends Node2D:
	const LARGE := 220.0
	const HAUTE := 200.0
	var sorte := "acre"           # « acre », « encens » (à dire avant poser)
	var _ton := OCRE
	var _ton_sombre := OCRE_SOMBRE
	var _colonne: Sprite2D
	var _nappe: Sprite2D
	var _bouffees: CPUParticles2D
	var _escarbilles: CPUParticles2D
	var _age := 0.0
	var _fini := 0.0
	var _rayon := 0.0
	static var _bouffee: ImageTexture

	# une bouffée de fumée : un corps doux, mangé par le bruit, au bord plus sombre (un lavis)
	static func bouffee() -> ImageTexture:
		if _bouffee == null:
			var n := FastNoiseLite.new()
			n.seed = 23
			n.frequency = 0.055
			n.fractal_octaves = 3
			var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for y in 64:
				for x in 64:
					var q := Vector2((x + 0.5) / 32.0 - 1.0, (y + 0.5) / 32.0 - 1.0)
					var d := q.length() + n.get_noise_2d(x, y) * 0.34
					var a := 1.0 - smoothstep(0.36, 0.92, d)
					var bord := smoothstep(0.0, 0.3, a) * (1.0 - smoothstep(0.3, 0.75, a))
					var v := (0.84 + 0.16 * n.get_noise_2d(x * 1.7 + 40.0, y * 1.7)) * (1.0 - 0.32 * bord)
					img.set_pixel(x, y, Color(v, v, v, a))
			_bouffee = ImageTexture.create_from_image(img)
		return _bouffee

	func poser(sol: Node2D, mobile: bool, graine: int) -> void:
		var g := float(graine % 1000) * 0.137
		var encens := sorte == "encens"
		if encens:
			_ton = ENCENS
			_ton_sombre = ENCENS_SOMBRE
		# (l'encens : plus fin, plus haut)
		var taille := Vector2(LARGE * 0.62, HAUTE * 1.2) if encens else Vector2(LARGE, HAUTE)
		_colonne = Sprite2D.new()
		_colonne.texture = T.blanc()
		_colonne.scale = taille / 4.0
		_colonne.position = Vector2(0.0, -taille.y * 0.5 - 6.0)
		_colonne.material = _materiau(COLONNE, g)
		add_child(_colonne)
		_bouffees = CPUParticles2D.new()
		_bouffees.amount = 5 if mobile else 10
		_bouffees.lifetime = 5.2
		_bouffees.lifetime_randomness = 0.25
		_bouffees.texture = bouffee()
		_bouffees.material = T.materiau(false, true)
		_bouffees.position = Vector2(0.0, -64.0)
		_bouffees.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_bouffees.emission_sphere_radius = 11.0
		_bouffees.direction = Vector2(0, -1)
		_bouffees.spread = 16.0
		_bouffees.initial_velocity_min = 15.0
		_bouffees.initial_velocity_max = 27.0
		_bouffees.damping_min = 1.0
		_bouffees.damping_max = 2.5
		_bouffees.angle_min = 0.0
		_bouffees.angle_max = 360.0
		_bouffees.angular_velocity_min = -24.0
		_bouffees.angular_velocity_max = 24.0
		_bouffees.scale_amount_min = 0.55
		_bouffees.scale_amount_max = 0.9
		_bouffees.scale_amount_curve = T.courbe([[0.0, 0.4], [0.35, 0.85], [1.0, 1.7]])
		var clair := _ton.lerp(P.IVOIRE, 0.25)
		_bouffees.color_ramp = T.rampe([[0.0, Color(_ton, 0.0)], [0.14, Color(_ton, 0.5)], [0.55, Color(clair, 0.26)], [1.0, Color(clair, 0.0)]])
		if encens:
			# (des volutes plus petites, qui montent plus haut et tournent lentement sur elles-mêmes, comme une odeur qui s'en va)
			_bouffees.position = Vector2(0.0, -90.0)
			_bouffees.lifetime = 6.4
			_bouffees.scale_amount_min = 0.36
			_bouffees.scale_amount_max = 0.62
			_bouffees.angular_velocity_min = -12.0
			_bouffees.angular_velocity_max = 12.0
			_bouffees.tangential_accel_min = -6.0
			_bouffees.tangential_accel_max = 6.0
		_bouffees.local_coords = false
		_bouffees.emitting = false
		add_child(_bouffees)
		# les escarbilles : des brins qui brûlent encore, montent en tournant, retombent
		_escarbilles = CPUParticles2D.new()
		# (l'encens : quelques brins gommeux qui crépitent, pas une gerbe)
		_escarbilles.amount = (3 if mobile else 6) if encens else (6 if mobile else 14)
		_escarbilles.lifetime = 2.6
		_escarbilles.lifetime_randomness = 0.5
		_escarbilles.texture = T.eclat()
		_escarbilles.material = T.materiau(true, false)
		_escarbilles.position = Vector2(0.0, -16.0)
		_escarbilles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_escarbilles.emission_sphere_radius = 6.0
		_escarbilles.direction = Vector2(0, -1)
		_escarbilles.spread = 30.0
		_escarbilles.initial_velocity_min = 34.0
		_escarbilles.initial_velocity_max = 88.0
		_escarbilles.damping_min = 14.0
		_escarbilles.damping_max = 30.0
		_escarbilles.tangential_accel_min = -55.0
		_escarbilles.tangential_accel_max = 55.0
		_escarbilles.angle_min = 0.0
		_escarbilles.angle_max = 360.0
		_escarbilles.angular_velocity_min = -320.0
		_escarbilles.angular_velocity_max = 320.0
		_escarbilles.scale_amount_min = 0.12
		_escarbilles.scale_amount_max = 0.3
		_escarbilles.color_ramp = T.rampe([[0.0, Color(P.BRAISE_COEUR, 1.0)], [0.3, Color(P.BRAISE, 0.95)], [0.7, Color(OCRE.lerp(P.BRAISE_ROUGE, 0.5), 0.7)],
			[1.0, Color(P.BRAISE_ROUGE, 0.0)]])
		_escarbilles.local_coords = false
		_escarbilles.emitting = false
		add_child(_escarbilles)
		if sol != null and is_instance_valid(sol):
			_nappe = Sprite2D.new()
			_nappe.texture = T.blanc()
			_nappe.material = _materiau(NAPPE, g + 3.1)
			sol.add_child(_nappe)

	func _materiau(sh: Shader, graine: float) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("bruit", T.bruit())
		m.set_shader_parameter("graine", graine)
		m.set_shader_parameter("ocre", _ton)
		m.set_shader_parameter("sombre", _ton_sombre)
		m.set_shader_parameter("braise", P.BRAISE)
		return m

	# chaque image : force (de 0 à 1 : scripts/botanique.gd, fumee), le vent, le rayon où elle tient les chasseurs, la teinte de
	# l'heure, la vie du feu, le rayon de sa lumière ; rend faux quand il n'en reste rien (le feu la défait)
	func regler(force: float, vent: float, rayon: float, ambiance: Color, vif: float, delta: float, lumiere: float = 0.0) -> bool:
		_age += delta
		if force > 0.0:
			_fini = 0.0
			# (le bourrelet de la nappe, aux neuf dixièmes de son rectangle, se pose là où elle tient les chasseurs)
			_rayon = rayon / 0.9
		else:
			_fini += delta
		var monte := smoothstep(0.0, 1.3, _age)
		# (le jour, la lumière du feu compte peu)
		var jour := clampf((ambiance.r + ambiance.g + ambiance.b) / 3.0, 0.0, 1.0)
		var lueur := clampf(vif, 0.0, 1.0) * lerpf(1.0, 0.3, smoothstep(0.3, 0.9, jour))
		var m: ShaderMaterial = _colonne.material
		# (l'encens est une fumée claire : on voit le camp au travers)
		m.set_shader_parameter("force", force * (0.72 if sorte == "encens" else 1.0))
		m.set_shader_parameter("monte", monte)
		m.set_shader_parameter("vent", clampf(vent, -1.0, 1.0))
		m.set_shader_parameter("ambiance", ambiance)
		m.set_shader_parameter("feu", lueur)
		_colonne.visible = force > 0.0
		_bouffees.emitting = force > 0.35 and _age > 0.6
		_bouffees.gravity = Vector2(vent * 34.0, -9.0)
		_escarbilles.emitting = force > 0.5
		_escarbilles.gravity = Vector2(vent * 42.0, 20.0)
		if _nappe != null and is_instance_valid(_nappe):
			var n: ShaderMaterial = _nappe.material
			n.set_shader_parameter("force", force)
			n.set_shader_parameter("etale", lerpf(0.22, 1.0, smoothstep(0.0, 4.0, _age)))
			n.set_shader_parameter("vent", clampf(vent, -1.0, 1.0))
			n.set_shader_parameter("ambiance", ambiance)
			n.set_shader_parameter("feu", lueur)
			n.set_shader_parameter("lumiere", clampf(lumiere / maxf(_rayon, 1.0), 0.05, 1.0))
			# (couchée au sol : le cercle où elle tient les chasseurs, vu de trois quarts ; le vent la pousse un peu)
			_nappe.scale = Vector2(_rayon * 2.0, _rayon * 2.0 * 0.5) / 4.0
			_nappe.position = Vector2(vent * _rayon * 0.05, 2.0)
			_nappe.visible = force > 0.0
		return _fini < 5.6

	func _exit_tree() -> void:
		if _nappe != null and is_instance_valid(_nappe):
			_nappe.queue_free()
