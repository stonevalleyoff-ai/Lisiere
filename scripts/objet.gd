extends Node2D
# Lisière — ce qui pousse et ce qui gît (scripts/objet.gd)
# Un arbre (du bois, puis une souche), un rocher (des pierres), un buisson (des baies, qui repoussent), une touffe (des fibres,
# qui repoussent), une brindille (un bois, ramassé d'un geste). Chacun dessiné une fois, d'après sa graine, comme sur une planche
# de naturaliste : un contour d'encre, trois tons (l'ombre, le ton propre, la lumière venue d'en haut à gauche), l'écorce, la
# mousse, les baies (scripts/decor_pinceau.gd, shaders/vegetation_feuillage.gdshader). Deux arbres ne se ressemblent pas.
# L'origine du nœud est son pied : le monde les trie par hauteur, le joueur passe derrière les troncs. La couronne d'un arbre est
# un nœud à part, qui a son propre dessin : le vent la plie (le shader), elle tremble quand on frappe, tombe quand l'arbre tombe,
# et s'efface quand la veilleuse passe dessous (monde.gd). Les ombres au sol, le monde les dessine (ombres()).

const Pinceau := preload("res://scripts/decor_pinceau.gd")
const P := preload("res://scripts/palette.gd")
const SHADER := preload("res://shaders/vegetation_feuillage.gdshader")
const BUTIN := {"arbre": "bois", "sapin": "bois", "souche": "", "rocher": "pierre", "buisson": "baies", "touffe": "fibre", "brindille": "bois"}
const R_INCENDIE := preload("res://scripts/regles.gd").INCENDIE_DUREE
const R_LUEUR := preload("res://scripts/regles.gd").INCENDIE_LUEUR
# le feu : ce qui brûle se peint par shaders/incendie_objet.gdshader, qui lit dans les UV ce que le dessin lui dit
const SHADER_FEU := preload("res://shaders/incendie_objet.gdshader")
const FEU_FLAMMES := 23.0      # un pan de flammes
const FEU_ENCRE := 27.0        # l'encre posée sur un feuillage : elle part avec lui
const CHARBON := 35.0          # le charbon : il rougeoie tant qu'il est chaud
const TIEDE := 14.0            # secondes : ce qui vient de brûler rougeoie encore
const NOIR := Color("1d1915")  # le bois brûlé
const REPOUSSE := 240.0
const CHUTE := 1.15            # secondes : un arbre abattu tombe
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)

# les deux matières, partagées par tous : la végétation (le vent la plie), et ce qui ne bouge pas (la même peinture)
static var vegetation: ShaderMaterial
static var fixe: ShaderMaterial
# ce qui brûle (une matière pour tous ; scripts/incendie_flammes.gd lui donne les foyers, le vent, l'heure)
static var incendie: ShaderMaterial
static var _bruit_flammes: Texture2D
# le climat du lieu, posé par le monde avant de semer (de 0 à 1) : la neige, la mousse
static var climat := {"froid": 0.0, "humide": 0.5}
static var _pinceau

var genre := "arbre"
var reste := 4
var plein := 4
var rayon := 0.0
var teinte := Color(0.2, 0.3, 0.18)
var graine := 0
var hauteur := 10.0            # en pixels, au-dessus du pied : pour son ombre portée
var couronne: Node2D = null    # le feuillage d'un arbre, sur son propre nœud
var couronne_rect := Rect2()   # où est ce feuillage, autour du pied
var _espece := "arbre"
var _repousse := 0.0
var _secoue := 0.0
var _chute := -1.0
var _sens := 1.0
# les mesures, tirées de la graine
var _ht := 28.0                # le tronc, jusqu'à la couronne (un sapin : ce qu'on en voit)
var _rx := 28.0
var _ry := 25.0
var _cc := Vector2(0, -50)     # le centre de la couronne
var _penche := 0.0


static func matieres() -> void:
	if vegetation == null:
		vegetation = ShaderMaterial.new()
		vegetation.shader = SHADER
		fixe = ShaderMaterial.new()
		fixe.shader = SHADER
		fixe.set_shader_parameter("souplesse", 0.0)
	if incendie == null:
		incendie = ShaderMaterial.new()
		incendie.shader = SHADER_FEU
		incendie.set_shader_parameter("bruit", bruit_des_flammes())
		incendie.set_shader_parameter("rouge", P.BRAISE_ROUGE)
		incendie.set_shader_parameter("braise", P.BRAISE)
		incendie.set_shader_parameter("coeur", P.BRAISE_COEUR)
		incendie.set_shader_parameter("charbon", NOIR)
		incendie.set_shader_parameter("roux", P.TERRE.lerp(P.BRAISE_ROUGE, 0.3).darkened(0.25))



# le bruit des flammes : doux, sans couture, sans grain fin (de grandes langues nettes, pas un fourmillement)
static func bruit_des_flammes() -> Texture2D:
	if _bruit_flammes == null:
		var n := FastNoiseLite.new()
		n.seed = 23
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.022
		n.fractal_octaves = 2
		n.fractal_gain = 0.4
		var img := n.get_seamless_image(128, 128, false, false, 0.15, true)
		img.convert(Image.FORMAT_L8)
		_bruit_flammes = ImageTexture.create_from_image(img)
	return _bruit_flammes


static func pinceau():
	if _pinceau == null:
		_pinceau = Pinceau.new()
	return _pinceau

# l'incendie (scripts/incendie.gd) : les secondes de feu qui lui restent (0 : il ne brûle pas) ; brûlé, il est calciné
var brule := 0.0
var calcine := false
# ce que le feu lui a pris avant que la pluie l'éteigne (de 0 à 1 : il reste debout, roussi d'autant)
var roussi := 0.0
var _brule_total := 0.0        # la durée de son feu, quand il a pris
var _tiede := -1.0             # depuis qu'il a fini de brûler, tant qu'il rougeoie (-1 : froid)
var _chicot := true            # calciné debout (un chicot), ou déjà abattu (une souche basse)
# (docs/49) la plante du monde d'Orvane qu'est cet objet, d'après l'herbier ("" : aucune) ; son port (un roseau…), ses épines
var plante := ""
var port := ""
var epineux := false


func preparer(g: String, couleur: Color, s: int) -> void:
	genre = g
	_espece = g
	teinte = couleur
	graine = s
	match g:
		"arbre", "sapin":
			plein = 4
			rayon = 11.0
		"rocher":
			plein = 3
			rayon = 15.0
		"buisson":
			plein = 3
		"touffe":
			plein = 2
		_:
			plein = 1
	reste = plein
	matieres()
	_mesurer()
	material = vegetation if g in ["arbre", "sapin", "buisson", "touffe"] else fixe
	if g == "arbre" or g == "sapin":
		couronne = Couronne.new()
		couronne.objet = self
		couronne.material = vegetation
		add_child(couronne)
	set_process(false)


# une plante du monde d'Orvane (docs/49), d'après l'herbier : sa teinte (la couleur de son dessin, à la valeur du lieu), sa taille
# (sa hauteur), son port (un roseau), ses épines. Le dessin reste celui du carnet, à l'encre.
func porter_plante(e: Dictionary) -> void:
	plante = str(e.get("id", ""))
	port = str(e.get("port", ""))
	var defense = e.get("defense", [])
	epineux = typeof(defense) == TYPE_ARRAY and defense.has("epineux")
	var c = e.get("couleur")
	if typeof(c) == TYPE_COLOR and c.s > 0.08:
		teinte = Color.from_hsv(c.h, lerpf(teinte.s, c.s, 0.35), teinte.v)
	var k := float(e.get("taille", 1.0))
	if absf(k - 1.0) > 0.01:
		_mesurer()
		_echelle(k)
	if couronne != null:
		couronne.queue_redraw()
	queue_redraw()


# toutes les mesures, à cette échelle (une plante plus haute, ou plus basse, que la moyenne)
func _echelle(k: float) -> void:
	_ht *= k
	_rx *= k
	_ry *= k
	_cc *= k
	hauteur *= k
	match genre:
		"arbre":
			couronne_rect = Rect2(_cc - Vector2(_rx, _ry), Vector2(_rx, _ry) * 2.0)
		"sapin":
			couronne_rect = Rect2(-_rx, -hauteur, _rx * 2.0, _ry)


func _mesurer() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	match genre:
		"arbre":
			_ht = r.randf_range(22.0, 31.0)
			_rx = r.randf_range(24.0, 32.0)
			_ry = _rx * r.randf_range(0.84, 0.95)
			_penche = r.randf_range(-0.07, 0.07)
			_cc = Vector2(_penche * (_ht + _ry * 0.8) + r.randf_range(-2.0, 2.0), -(_ht + _ry * 0.8))
			hauteur = -_cc.y + _ry
			couronne_rect = Rect2(_cc - Vector2(_rx, _ry), Vector2(_rx, _ry) * 2.0)
		"sapin":
			_ht = r.randf_range(7.0, 10.0)
			_ry = r.randf_range(58.0, 74.0)
			_rx = r.randf_range(17.0, 22.0)
			_penche = r.randf_range(-0.04, 0.04)
			hauteur = _ht + _ry
			couronne_rect = Rect2(-_rx, -hauteur, _rx * 2.0, _ry)
		"rocher":
			_rx = r.randf_range(14.0, 18.5)
			_ry = r.randf_range(11.0, 16.0)
			hauteur = _ry
		"buisson":
			_rx = r.randf_range(12.0, 15.5)
			_ry = r.randf_range(16.0, 21.0)
			hauteur = _ry
		"touffe":
			hauteur = 16.0
		_:
			hauteur = 2.0


# un geste : ce qu'il donne ({ "bois": 1 }), ou rien
func recolter() -> Dictionary:
	if reste <= 0:
		return {}
	reste -= 1
	var item: String = BUTIN.get(genre, "")
	if (genre == "arbre" or genre == "sapin") and reste <= 0:
		genre = "souche"
		rayon = 6.0
		_chute = 0.0
		_sens = 1.0 if graine % 2 == 0 else -1.0
		material = fixe
	elif (genre == "buisson" or genre == "touffe") and reste <= 0:
		_repousse = REPOUSSE
	_secoue = 0.35
	set_process(true)
	queue_redraw()
	_ombre_changee()
	return {item: 1} if item != "" else {}


func epuise() -> bool:
	return reste <= 0


# --- l'abri, le feu ---

# le rayon de son feuillage, pour s'abriter de la pluie dessous (0 : ce n'est pas un arbre debout, ou il brûle, ou il a brûlé).
# C'est aussi ce que la foudre cherche.
func couvert() -> float:
	if couronne == null or _chute >= 0.0 or brule > 0.0 or calcine or (genre != "arbre" and genre != "sapin"):
		return 0.0
	return maxf(_rx, 22.0) * 1.05


# peut-il prendre feu ? (ce qui pousse, et pas deux fois)
func combustible() -> bool:
	return brule <= 0.0 and not calcine and R_INCENDIE.has(genre) and not ((genre == "buisson" or genre == "touffe") and reste <= 0)


# il prend feu, pour cette durée (scripts/incendie.gd le suit ; il se dessine en feu lui-même : ses flammes sont dans son dessin,
# peintes par shaders/incendie_objet.gdshader)
func enflammer(duree: float) -> void:
	brule = duree
	_brule_total = maxf(duree, 0.1)
	_tiede = -1.0
	_secoue = 0.3
	matieres()
	material = incendie
	if couronne != null and _chute < 0.0:
		couronne.material = incendie
		couronne.queue_redraw()
	set_process(true)
	queue_redraw()


# où en est son feu, de 0 (il prend) à 1 (il n'en reste rien)
func feu_avance() -> float:
	return clampf(1.0 - brule / _brule_total, 0.0, 1.0) if brule > 0.0 and _brule_total > 0.0 else 0.0


# ce qui vient de brûler rougeoie encore : de 1 (à l'instant) à 0 (froid)
func tiedeur() -> float:
	return clampf(1.0 - _tiede / TIEDE, 0.0, 1.0) if _tiede >= 0.0 else 0.0


func _matiere_au_repos() -> ShaderMaterial:
	return vegetation if genre in ["arbre", "sapin", "buisson", "touffe"] else fixe


# la pluie l'a éteint avant la fin : il reste debout, roussi (d'autant plus qu'il a brûlé longtemps)
func eteindre() -> void:
	roussi = maxf(roussi, clampf(0.3 + 0.7 * feu_avance(), 0.0, 1.0))
	brule = 0.0
	material = _matiere_au_repos()
	if couronne != null:
		couronne.material = vegetation
		couronne.queue_redraw()
	queue_redraw()


# il a brûlé jusqu'au bout : un arbre n'est plus qu'une souche noire, un buisson, une touffe sont rasés (ils repousseront)
func calciner() -> void:
	# (ce qui vient de brûler rougeoie un moment : il garde la matière du feu, le temps de refroidir)
	_tiede = 0.0 if brule > 0.0 or material == incendie else -1.0
	brule = 0.0
	calcine = true
	roussi = 0.0
	_chicot = genre == "arbre" or genre == "sapin"
	if _chicot:
		genre = "souche"
		reste = 0
		rayon = 6.0
		if couronne != null:
			couronne.queue_free()
			couronne = null
		_chute = -1.0
	else:
		reste = 0
		_repousse = REPOUSSE * 1.5
	if _tiede < 0.0:
		material = _matiere_au_repos()
	set_process(true)
	queue_redraw()
	_ombre_changee()


# en feu, il éclaire comme un feu de camp : les chasseurs n'entrent pas dans sa lumière (les mêmes noms que scripts/feu.gd)
func allume() -> bool:
	return brule > 0.0


func rayon_lueur() -> float:
	return float(R_LUEUR.get(_espece if genre == "souche" else genre, 60.0)) if brule > 0.0 else 0.0


func eclaire(p: Vector2) -> float:
	var r := rayon_lueur()
	if r <= 0.0:
		return 0.0
	return clampf((r - p.distance_to(position)) / (r * 0.4), 0.0, 1.0)


# une partie reprise : l'objet tel qu'on l'avait laissé (entamé, abattu en souche, ou qui repousse), sans le geste qui l'y a mené
func reprendre(g: String, r: int, repousse: float, brule_: bool = false) -> void:
	reste = clampi(r, 0, plein)
	if brule_:
		# (ce qui avait brûlé : noir, et froid)
		calcine = true
		_tiede = -1.0
	if g == "souche" and genre != "souche":
		genre = "souche"
		rayon = 6.0
		material = fixe
		if couronne != null:
			couronne.queue_free()
			couronne = null
	if repousse > 0.0:
		_repousse = repousse
		set_process(true)
	queue_redraw()


# la veilleuse, debout en p, est-elle cachée par ce feuillage ? (derrière le tronc, sous la couronne)
func cache(p: Vector2) -> bool:
	if couronne == null or _chute >= 0.0 or p.y >= position.y - 2.0:
		return false
	var corps := Rect2(p.x - 9.0, p.y - 40.0, 18.0, 40.0)
	return corps.intersects(Rect2(couronne_rect.position + position, couronne_rect.size).grow(-5.0))


func _ombre_changee() -> void:
	var m := get_parent()
	if m != null and m.has_method("ombre_changee"):
		m.ombre_changee(self)


func _process(delta: float) -> void:
	var anime := false
	if _secoue > 0.0:
		_secoue = maxf(0.0, _secoue - delta)
		anime = true
		if couronne != null and _chute < 0.0:
			# (l'arbre frappé : sa couronne tremble, autour de son pied, sans se redessiner)
			couronne.rotation = sin(_secoue * 55.0) * _secoue * 0.11
		else:
			queue_redraw()
	if _chute >= 0.0 and couronne != null:
		_chute += delta
		var u := clampf(_chute / CHUTE, 0.0, 1.0)
		couronne.rotation = _sens * u * u * 1.45
		# (le tronc pivote sur sa coupe, pas sur le pied)
		var coupe := Vector2(_axe(-8.5), -8.5)
		couronne.position = coupe - coupe.rotated(couronne.rotation)
		couronne.modulate.a = 1.0 - smoothstep(0.6, 1.0, u)
		anime = true
		if u >= 1.0:
			couronne.queue_free()
			couronne = null
			_chute = -1.0
	if _tiede >= 0.0:
		# (ce qui vient de brûler refroidit, puis reprend sa matière : la lumière du lieu le touche de nouveau)
		_tiede += delta
		anime = true
		if _tiede >= TIEDE:
			_tiede = -1.0
			if brule <= 0.0:
				material = _matiere_au_repos()
	if _repousse > 0.0:
		_repousse -= delta
		anime = true
		if _repousse <= 0.0:
			reste = plein
			# (ce qui avait brûlé, ou roussi, a repoussé)
			calcine = false
			roussi = 0.0
			queue_redraw()
			_ombre_changee()
	if not anime:
		set_process(false)


# ses ombres au sol : [centre, rayons, opacité, portée (0 : de contact ; 1 : elle suit le soleil), hauteur]
func ombres() -> Array:
	match genre:
		"arbre":
			return [[Vector2(1, 1), Vector2(14, 5.5), 0.45, 0.0, 0.0], [Vector2(_cc.x + 3.0, 3.0), Vector2(_rx * 1.02, _ry * 0.46), 0.3, 1.0, hauteur * 0.75]]
		"sapin":
			return [[Vector2(1, 1), Vector2(12, 5.0), 0.45, 0.0, 0.0], [Vector2(3, 3), Vector2(_rx * 0.95, _rx * 0.44), 0.3, 1.0, hauteur * 0.7]]
		"souche":
			return [[Vector2(1, 1), Vector2(10, 4.0), 0.4, 0.0, 0.0]]
		"rocher":
			var t := _usure()
			return [[Vector2(1.5, 1.5), Vector2(_rx * 1.2 * t, _rx * 0.45 * t), 0.45, 0.0, 0.0], [Vector2(3, 2), Vector2(_rx * t, _rx * 0.4 * t), 0.22, 1.0, _ry * t * 0.7]]
		"buisson":
			return [[Vector2(0, 1.5), Vector2(_rx * 1.15, _rx * 0.45), 0.42, 0.0, 0.0], [Vector2(2, 2), Vector2(_rx, _rx * 0.4), 0.22, 1.0, _ry * 0.55]]
		"touffe":
			return [[Vector2(0, 1), Vector2(8, 3.0), 0.3 if reste > 0 else 0.15, 0.0, 0.0]]
		_:
			return [[Vector2(0, 1), Vector2(11, 3.5), 0.22, 0.0, 0.0]]


func _usure() -> float:
	return 0.62 + 0.38 * float(reste) / float(plein)


func _draw() -> void:
	var p = pinceau()
	p.commencer(get_canvas_item())
	var r := RandomNumberGenerator.new()
	r.seed = graine + 11
	if _secoue > 0.0 and genre != "souche":
		var k := sin(_secoue * 46.0) * _secoue
		if genre == "rocher":
			draw_set_transform(Vector2(k * 3.0, 0.0))
		elif genre != "arbre" and genre != "sapin":
			# (un buisson, une touffe : la tête frémit, le pied reste)
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-k * 0.35, 1), Vector2.ZERO))
	# (brûlé jusqu'au bout : il n'en reste que du charbon et de la cendre)
	if calcine:
		if genre == "souche":
			_souche_noire(p, r)
		else:
			_cendres(p, r)
		p.finir()
		return
	var en_feu := brule > 0.0
	var garde := teinte
	if roussi > 0.0:
		teinte = _teinte_roussie()
	if en_feu:
		# (le feu qui court au sol, derrière lui : on prend feu à vingt-quatre pixels de son pied)
		_flammes(p, Vector2(0, -6), 19.0, 20.0, 1.0, 0.13)
	var depuis: int = p.uvs.size()
	match genre:
		"arbre", "sapin":
			_pied(p, r, false)
		"souche":
			_pied(p, r, true)
		"rocher":
			_rocher(p, r)
		"buisson":
			_buisson(p, r)
		"touffe":
			_touffe(p, r)
		"brindille":
			_brindille(p, r)
	if en_feu:
		_dessiner_feu(p, depuis)
	teinte = garde
	p.finir()


func _dessiner_couronne(c: CanvasItem) -> void:
	var p = pinceau()
	p.commencer(c.get_canvas_item())
	var r := RandomNumberGenerator.new()
	r.seed = graine + 23
	var sapin := _espece == "sapin"
	var en_feu: bool = brule > 0.0 and c.material == incendie
	var garde := teinte
	if roussi > 0.0:
		teinte = _teinte_roussie()
	if en_feu:
		# (derrière la couronne : le grand corps de flammes, puis le bois nu qu'on verra quand les feuilles seront parties)
		if sapin:
			_flammes(p, Vector2(0, -_ht + 4.0), _rx * 1.6, _ry + 48.0, 0.0, 0.71)
		else:
			_flammes(p, _cc + Vector2(0, _ry * 0.8), _rx * 1.5, _ry * 2.0 + 52.0, 0.5, 0.71)
		_bois_nu(p)
	var depuis: int = p.uvs.size()
	if sapin:
		_sapin(p, r)
	else:
		_feuillu(p, r)
	if en_feu:
		# (devant : des flammes plus basses, qui laissent voir les feuilles roussir)
		_marquer(p, depuis, false)
		if sapin:
			_flammes(p, Vector2(-_rx * 0.3, -_ht - 2.0), _rx * 0.85, _ry * 0.62 + 12.0, 0.2, 0.37)
			_flammes(p, Vector2(_rx * 0.25, -_ht - _ry * 0.3), _rx * 0.75, _ry * 0.6 + 14.0, 0.2, 0.83)
		else:
			_flammes(p, _cc + Vector2(-_rx * 0.42, _ry * 0.8), _rx * 0.72, _ry * 1.25 + 14.0, 0.2, 0.37)
			_flammes(p, _cc + Vector2(_rx * 0.4, _ry * 0.55), _rx * 0.66, _ry * 1.15 + 16.0, 0.2, 0.83)
	elif roussi > 0.35:
		_bois_nu(p, true)
	teinte = garde
	p.finir()


# --- le feu : ce qui brûle, ce qui reste ---

# les flammes d'un objet en feu, par-dessus son dessin (son feuillage est marqué : le feu l'emportera)
func _dessiner_feu(p, depuis: int) -> void:
	match genre:
		"arbre", "sapin":
			_flammes(p, Vector2(0, 9), 25.0, 26.0, 1.0, 0.57)
		"souche":
			_flammes(p, Vector2(0, -3), 15.0, 36.0, 0.0, 0.31)
			_flammes(p, Vector2(0, 8), 24.0, 18.0, 1.0, 0.57)
		"buisson":
			_marquer(p, depuis, false)
			_flammes(p, Vector2(0, 1), _rx * 1.75, _ry + 34.0, 0.5, 0.31)
			_flammes(p, Vector2(0, 8), 25.0, 20.0, 1.0, 0.57)
		"touffe":
			_marquer(p, depuis, true)
			_flammes(p, Vector2(0, 2), 14.0, 30.0, 0.0, 0.31)
			_flammes(p, Vector2(0, 7), 24.0, 16.0, 1.0, 0.57)


# un pan de flammes (shaders/incendie_objet.gdshader) : son pied (au milieu, en bas), sa demi-largeur, sa hauteur ; sa sorte
# (0 : une langue ; 0,5 : un corps rond, une couronne qui flambe ; 1 : un feu qui court au sol) ; k le distingue des autres
func _flammes(p, pied: Vector2, demi: float, haut: float, sorte: float, k: float) -> void:
	var base: int = p.pts.size()
	var c := Color(fposmod(float(graine % 997) * 0.0131 + k, 1.0), sorte, haut / 256.0, 1.0)
	p.pts.append_array(PackedVector2Array([pied + Vector2(-demi, haut * 0.03), pied + Vector2(demi, haut * 0.03), pied + Vector2(demi, -haut), pied + Vector2(-demi, -haut)]))
	p.cols.append_array(PackedColorArray([c, c, c, c]))
	p.uvs.append_array(PackedVector2Array([Vector2(FEU_FLAMMES - 1.0, FEU_FLAMMES - 0.03), Vector2(FEU_FLAMMES + 1.0, FEU_FLAMMES - 0.03),
		Vector2(FEU_FLAMMES + 1.0, FEU_FLAMMES + 1.0), Vector2(FEU_FLAMMES - 1.0, FEU_FLAMMES + 1.0)]))
	p.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


# ce que le feu emportera : dès le premier aplat de feuillage (ou tout : une touffe), l'encre et les baies posées dessus sont
# marquées dans leurs UV (le shader les fait partir avec les feuilles ; le tronc et les branches, dessinés avant, restent)
func _marquer(p, depuis: int, tout: bool) -> void:
	var dedans := tout
	for i in range(depuis, p.uvs.size()):
		var uv: Vector2 = p.uvs[i]
		if not dedans and ((uv.x > 1.5 and uv.x < 4.5) or (uv.x > 17.5 and uv.x < 20.5)):
			dedans = true
		if not dedans:
			continue
		if uv == Vector2.ZERO:
			p.uvs[i] = Vector2(FEU_ENCRE, FEU_ENCRE)
		elif uv.x > 13.5 and uv.x < 16.5:
			p.uvs[i] = uv + Vector2(16.0, 16.0)


# le bois nu d'un arbre : derrière ses feuilles en feu (on le voit quand elles partent), ou qui dépasse d'une couronne roussie
func _bois_nu(p, dehors: bool = false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine + 41
	var bois := NOIR.lightened(0.06)
	if _espece == "sapin":
		var sommet := -(_ht + _ry * 0.93)
		if dehors:
			# (roussi : la flèche et quelques branches hautes sont nues)
			p.tracer(PackedVector2Array([Vector2(_penche * -sommet, sommet + 9.0), Vector2(_penche * -sommet + 0.6, sommet - 5.0)]), 1.5, ENCRE, false)
			return
		var fut := PackedVector2Array()
		for k in 6:
			var y := lerpf(-_ht - 2.0, sommet, k / 5.0)
			fut.append(Vector2(_penche * -y, y))
		p.tracer(fut, 3.4, ENCRE, false, PackedFloat32Array([4.6, 4.2, 3.6, 3.0, 2.2, 1.2]))
		p.tracer(fut, 2.0, bois, false, PackedFloat32Array([3.0, 2.7, 2.2, 1.7, 1.1, 0.5]))
		for k in 7:
			var u := (k + 0.6) / 7.5
			var y := lerpf(-_ht - 4.0, sommet + 6.0, u)
			var cote := -1.0 if k % 2 == 0 else 1.0
			var l := _rx * (1.0 - u * 0.72) * r.randf_range(0.55, 0.85)
			var a := Vector2(_penche * -y, y)
			p.tracer(PackedVector2Array([a, a + Vector2(cote * l * 0.55, l * 0.1), a + Vector2(cote * l, l * 0.32 + 1.0)]), 1.5, ENCRE, false, PackedFloat32Array([2.0, 1.5, 0.8]))
		return
	var n := 3 if dehors else 6
	for k in n:
		# (des branches qui partent du haut du tronc ; roussi, seules leurs pointes dépassent des feuilles)
		var ang := lerpf(-2.5, -0.65, (k + r.randf_range(0.2, 0.8)) / n)
		var dir := Vector2(cos(ang), sin(ang))
		var a := Vector2(_axe(_cc.y + _ry * 0.35), _cc.y + _ry * 0.35)
		var bout := _cc + dir * Vector2(_rx, _ry) * (r.randf_range(1.02, 1.14) if dehors else r.randf_range(0.6, 0.92))
		var mil := a.lerp(bout, 0.55) + Vector2(dir.y, -dir.x) * r.randf_range(-3.0, 3.0)
		if dehors:
			var depart := mil.lerp(bout, 0.55)
			p.tracer(PackedVector2Array([depart, bout]), 1.3, ENCRE, false, PackedFloat32Array([1.5, 0.7]))
			p.tracer(PackedVector2Array([depart.lerp(bout, 0.4), depart.lerp(bout, 0.75) + Vector2(dir.y, -dir.x) * 3.2]), 1.0, ENCRE, false, PackedFloat32Array([1.1, 0.5]))
		else:
			p.tracer(PackedVector2Array([a, mil, bout]), 2.4, ENCRE, false, PackedFloat32Array([3.4, 2.4, 1.0]))
			p.tracer(PackedVector2Array([a, mil, bout]), 1.4, bois, false, PackedFloat32Array([2.0, 1.3, 0.4]))
			var f := mil.lerp(bout, 0.3)
			p.tracer(PackedVector2Array([f, f + Vector2(dir.y, -dir.x) * r.randf_range(4.0, 7.0) + dir * 4.0]), 1.2, ENCRE, false, PackedFloat32Array([1.5, 0.6]))


# la teinte d'un feuillage que le feu a roussi, avant que la pluie l'éteigne
func _teinte_roussie() -> Color:
	return teinte.lerp(P.TERRE.lerp(P.BRAISE_ROUGE, 0.4), 0.45 + 0.35 * roussi).darkened(0.08 + 0.3 * roussi)


# ce qui reste d'un arbre brûlé jusqu'au bout : un chicot noir, fendu, dans sa cendre (d'un arbre déjà abattu : sa souche)
func _souche_noire(p, r: RandomNumberGenerator) -> void:
	var cendre := P.CENDRE.lerp(P.IVOIRE, 0.3)
	p.eventail(Vector2(0, 2), 22.0, 8.5, Color(P.CENDRE.darkened(0.3), 0.66), Color(P.CENDRE.darkened(0.3), 0.0), 16)
	for i in 8:
		var q := Vector2(r.randf_range(-17.0, 17.0), r.randf_range(-2.0, 7.0))
		p.disque(q, r.randf_range(0.9, 1.9), r.randf_range(0.5, 0.9), Color(cendre, r.randf_range(0.35, 0.8)))
	_racines(p, r, NOIR.lightened(0.04))
	# le chicot : le bas du tronc, cassé en pointes
	var h := (13.0 + float(graine % 9)) if _chicot else 8.5
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	for i in 5:
		var y := lerpf(0.5, -h, i / 4.0)
		var w := _demi_largeur(y) * lerpf(1.0, 0.86, i / 4.0)
		gauche.append(Vector2(_axe(y) - w, y))
		droite.append(Vector2(_axe(y) + w, y))
	var poly := PackedVector2Array()
	poly.append_array(gauche)
	if _chicot:
		var x0: float = gauche[4].x
		var x1: float = droite[4].x
		var dents := 3 + graine % 2
		for k in range(1, dents * 2):
			var x := lerpf(x0, x1, float(k) / (dents * 2))
			poly.append(Vector2(x + r.randf_range(-0.5, 0.5), -h + (-r.randf_range(2.5, 7.0) if k % 2 == 1 else r.randf_range(0.5, 2.5))))
	droite.reverse()
	poly.append_array(droite)
	var centre := Vector2(_axe(-h * 0.5), -h * 0.5)
	p.aplat(poly, NOIR, CHARBON, centre, Vector2(8.0, h))
	# la lumière sur le charbon : des écailles grises, du côté du jour ; puis l'encre
	for i in 3:
		var y := lerpf(-2.0, -h + 1.0, (i + r.randf_range(0.1, 0.9)) / 3.0)
		var x := _axe(y) - _demi_largeur(y) * r.randf_range(0.25, 0.7)
		p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + 0.4, y - r.randf_range(2.0, 4.0))]), 1.0, Color(cendre.darkened(0.25), 0.7))
	if not _chicot:
		p.disque(Vector2(_axe(-h), -h), _demi_largeur(-h) * 0.86, 2.3, NOIR.lightened(0.07), CHARBON)
	p.contour(poly, 1.4, ENCRE, r, 3)
	# des branches tombées, noires
	for i in 2:
		var q := Vector2(r.randf_range(7.0, 16.0) * (1.0 if i == 0 else -1.0), r.randf_range(1.0, 6.0))
		var d := Vector2.from_angle(r.randf_range(-0.5, 0.5)) * r.randf_range(4.0, 7.5)
		p.tracer(PackedVector2Array([q - d, q + Vector2(0, -0.6), q + d]), 2.6, ENCRE)
		p.tracer(PackedVector2Array([q - d, q + Vector2(0, -0.6), q + d]), 1.5, NOIR.lightened(0.08))


# ce qui reste d'un buisson, d'une touffe : une tache de cendre, quelques tiges noires (ils repousseront)
func _cendres(p, r: RandomNumberGenerator) -> void:
	var buisson := genre == "buisson"
	var large := 15.0 if buisson else 9.5
	var cendre := P.CENDRE.lerp(P.IVOIRE, 0.3)
	p.eventail(Vector2(0, 1), large * 1.35, large * 0.52, Color(P.CENDRE.darkened(0.3), 0.72), Color(P.CENDRE.darkened(0.3), 0.0), 14)
	p.eventail(Vector2(r.randf_range(-2.0, 2.0), 1.5), large * 0.7, large * 0.24, Color(cendre, 0.5), Color(cendre, 0.0), 12)
	for i in (7 if buisson else 4):
		var q := Vector2(r.randf_range(-large, large), r.randf_range(-2.0, 5.0))
		p.disque(q, r.randf_range(0.8, 1.6), r.randf_range(0.45, 0.8), Color(cendre, r.randf_range(0.35, 0.8)))
	# des braises dans la cendre (du charbon : elles rougeoient tant qu'il est chaud)
	for i in (5 if buisson else 3):
		var q := Vector2(r.randf_range(-large * 0.7, large * 0.7), r.randf_range(-1.5, 3.5))
		p.disque(q, r.randf_range(1.0, 1.7), r.randf_range(0.7, 1.0), NOIR, CHARBON)
	for i in (5 if buisson else 3):
		var x := r.randf_range(-large * 0.55, large * 0.55)
		var bout := Vector2(x + r.randf_range(-2.5, 2.5), -r.randf_range(3.0, 8.5 if buisson else 5.0))
		var tige := PackedVector2Array([Vector2(x, 1.5), Vector2(x, 1.5).lerp(bout, 0.5) + Vector2(r.randf_range(-0.8, 0.8), 0), bout])
		p.tracer(tige, 2.2, ENCRE, false, PackedFloat32Array([2.4, 1.9, 1.0]))
		p.tracer(tige, 1.1, NOIR.lightened(0.1), false, PackedFloat32Array([1.2, 0.9, 0.3]))


# --- les arbres ---

func _ecorce() -> Color:
	var c := P.TERRE.lerp(P.BRAISE_ROUGE, 0.12).darkened(0.32) if _espece == "sapin" else P.TERRE.lerp(P.ENCRE_DOUCE, 0.42).lerp(P.CENDRE, 0.15)
	# (le feu a léché le tronc)
	return c.lerp(NOIR, 0.3 + 0.45 * roussi) if roussi > 0.0 else c


# l'axe du tronc, à la hauteur y (négative), et sa demi-largeur
func _axe(y: float) -> float:
	return _penche * -y + sin(-y * 0.07 + graine % 7) * 0.7


func _demi_largeur(y: float) -> float:
	var haut := -_cc.y if _espece == "arbre" else _ht + 6.0
	var u := clampf(-y / haut, 0.0, 1.0)
	var w := lerpf(5.0, 2.8, u) if _espece == "arbre" else lerpf(3.6, 2.6, u)
	return w + 2.6 * (1.0 - smoothstep(0.0, 6.0, -y))


# un morceau de tronc, de y0 à y1 (négatifs), en écorce, bordé d'encre
func _tronc(p, y0: float, y1: float, c: Color) -> void:
	var n := maxi(3, int((y0 - y1) / 5.0))
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	for i in n + 1:
		var y := lerpf(y0, y1, float(i) / n)
		var x := _axe(y)
		var w := _demi_largeur(y)
		gauche.append(Vector2(x - w, y))
		droite.append(Vector2(x + w, y))
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for i in gauche.size():
		poly.append(gauche[i])
		cols.append(c)
		uvs.append(Vector2(10.0, 11.0))
	for i in range(droite.size() - 1, -1, -1):
		poly.append(droite[i])
		cols.append(c)
		uvs.append(Vector2(12.0, 11.0))
	p.aplat_libre(poly, cols, uvs)
	p.tracer(gauche, 1.1, ENCRE, false)
	p.tracer(droite, 1.7, ENCRE, false)


func _racines(p, r: RandomNumberGenerator, c: Color) -> void:
	var n := r.randi_range(2, 4)
	for i in n:
		var cote := -1.0 if i % 2 == 0 else 1.0
		var a := cote * r.randf_range(0.15, 1.2)
		var l := r.randf_range(6.0, 11.0)
		var dir := Vector2(sin(a), cos(a) * 0.35)
		var depart := Vector2(_axe(0.0) + cote * 3.5, -1.5)
		var bout := depart + dir * l + Vector2(0, 2.0)
		var nrm := dir.orthogonal()
		var poly := PackedVector2Array([depart + nrm * 2.4 + Vector2(0, -2.5), depart + dir * l * 0.5 + nrm * 1.3, bout, depart + dir * l * 0.5 - nrm * 1.5, depart - nrm * 2.4])
		p.aplat(poly, c.darkened(0.08), Pinceau.ECORCE, depart + dir * l * 0.4, Vector2(5.0, 5.0))
		p.tracer(PackedVector2Array([depart - nrm * 2.4, depart + dir * l * 0.5 - nrm * 1.5, bout]), 1.2, ENCRE)


# le pied d'un arbre : les racines, le bas du tronc, les entailles des coups ; ou la souche qu'il laisse
func _pied(p, r: RandomNumberGenerator, souche: bool) -> void:
	var c := _ecorce()
	_racines(p, r, c)
	var haut := -9.0
	_tronc(p, 0.5, haut, c)
	if climat.get("humide", 0.5) > 0.5:
		# (de la mousse au pied, du côté de l'ombre)
		for i in r.randi_range(1, 3):
			var m := Vector2(_axe(0.0) + r.randf_range(-5.5, -1.5), r.randf_range(-5.0, 0.5))
			p.disque(m, r.randf_range(1.2, 2.2), r.randf_range(0.9, 1.5), P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.35), Pinceau.FEUILLAGE)
	if souche:
		# la coupe : le bois clair, ses cernes, une fente
		var x := _axe(haut)
		var w := _demi_largeur(haut)
		var bois := P.IVOIRE.lerp(P.BRAISE, 0.22).darkened(0.12)
		var coupe := Vector2(x, haut)
		p.disque(coupe, w + 0.4, 2.6, bois, Pinceau.DOME)
		for k in 2:
			p.tracer(Pinceau.ellipse(coupe, (w - 1.2) * (0.66 - k * 0.3), 2.6 * (0.66 - k * 0.3), 12), 0.5, bois.darkened(0.35), false)
		p.tracer(PackedVector2Array([coupe, coupe + Vector2(w * 0.8, 0.9)]), 0.7, ENCRE.darkened(0.2))
		var bord := Pinceau.ellipse(coupe, w + 0.4, 2.6, 18)
		bord.append(bord[0])
		p.tracer(bord, 1.1, ENCRE, false)
		# des copeaux, tombés autour
		for i in 3:
			var q := Vector2(r.randf_range(-14.0, 14.0), r.randf_range(1.0, 6.0))
			var a := r.randf() * TAU
			var d := Vector2.from_angle(a)
			p.aplat(PackedVector2Array([q - d * 2.2, q + d.orthogonal() * 0.9, q + d * 2.2, q - d.orthogonal() * 0.7]), bois, Pinceau.UNI)
		return
	# les entailles : chaque coup creuse le tronc
	var coups := plein - reste
	if coups > 0:
		var y := -4.5
		var x := _axe(y) + _demi_largeur(y) * 0.1
		var w := 1.6 + coups * 1.3
		var bois := P.IVOIRE.lerp(P.BRAISE, 0.25)
		var entaille := PackedVector2Array([Vector2(x - w, y - 1.6), Vector2(x + w * 0.9, y - 2.3), Vector2(x + w * 0.6, y + 0.4 + coups * 0.4), Vector2(x - w * 0.8, y + 1.0)])
		p.aplat(entaille, bois, Pinceau.UNI)
		p.contour(entaille, 0.8, ENCRE, r, 2)


# le haut d'un feuillu : le tronc, deux branches, la couronne en touffes, son contour d'encre
func _feuillu(p, r: RandomNumberGenerator) -> void:
	var c := _ecorce()
	var haut := _cc.y + _ry * 0.35
	_tronc(p, -8.5, haut, c)
	# l'écorce : des fibres, un nœud
	for i in r.randi_range(2, 4):
		var y := r.randf_range(-12.0, haut + 6.0)
		var x := _axe(y) + r.randf_range(-1.5, 2.2)
		p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + 0.3, y - r.randf_range(4.0, 8.0))]), 0.7, Color(ENCRE, 0.5))
	if r.randf() < 0.7:
		var y := r.randf_range(-16.0, -11.0)
		var nd := Vector2(_axe(y) + r.randf_range(-1.0, 1.5), y)
		p.disque(nd, 1.5, 1.1, c.darkened(0.5))
		p.tracer(PackedVector2Array([nd + Vector2(-1.6, -0.6), nd + Vector2(0, -1.6), nd + Vector2(1.6, -0.4)]), 0.6, c.lightened(0.25), false)
	# les branches, qui partent dans la couronne
	for cote in [-1.0, 1.0]:
		var y0 := _cc.y + _ry * r.randf_range(0.35, 0.55)
		var a := Vector2(_axe(y0), y0)
		var b := a + Vector2(cote * _rx * r.randf_range(0.35, 0.6), -_ry * r.randf_range(0.3, 0.55))
		var m := (a + b) * 0.5 + Vector2(-cote * 1.5, 2.0)
		p.tracer(PackedVector2Array([a, m, b]), 3.6, ENCRE)
		p.tracer(PackedVector2Array([a, m, b]), 2.4, c)
	# l'ombre de la couronne sur le tronc
	p.eventail(Vector2(_axe(_cc.y + _ry), _cc.y + _ry * 0.92), 6.5, 5.0, Color(P.ENCRE, 0.55), Color(P.ENCRE, 0.0), 12)
	# la couronne : des festons, peints en touffes
	var poly := festons(_cc, _rx, _ry, r.randi_range(7, 9), 0.16, r, 60, 0.12)
	var t := teinte.lerp(P.FEUILLE_SOMBRE, r.randf_range(0.0, 0.18)).lightened(r.randf_range(0.0, 0.08))
	p.aplat(poly, t, Pinceau.FEUILLAGE, _cc, Vector2(_rx, _ry) * 1.08)
	# l'encre : le contour, en quelques traits, et des arcs de touffes du côté de l'ombre
	p.contour(poly, 1.5, ENCRE, r, 4)
	for i in r.randi_range(3, 5):
		var q := _cc + Vector2(r.randf_range(-0.1, 0.75) * _rx, r.randf_range(-0.05, 0.7) * _ry)
		var rr := r.randf_range(5.0, 8.5)
		var arc := PackedVector2Array()
		var a0 := r.randf_range(-0.2, 0.4)
		for k in 6:
			var a := a0 + k * 0.32
			arc.append(q + Vector2(cos(a), sin(a) * 0.9) * rr)
		p.tracer(arc, 0.9, Color(ENCRE, 0.6))


# un sapin : des étages d'aiguilles, du bas vers le haut, chacun bordé de dents d'encre ; la neige s'il fait froid
func _sapin(p, r: RandomNumberGenerator) -> void:
	var c := _ecorce()
	_tronc(p, -8.5, -_ht - 4.0, c)
	var etages := r.randi_range(4, 5)
	var froid := float(climat.get("froid", 0.0))
	var t0 := teinte.lerp(P.FEUILLE_SOMBRE, 0.25)
	for i in etages:
		var u := float(i) / etages
		var bas := -_ht + 1.0 - u * _ry * 0.78
		var h := _ry * (0.4 if i < etages - 1 else 0.36)
		var sommet := bas - h
		var w := _rx * (1.0 - u * 0.72) * r.randf_range(0.94, 1.06)
		var ax := _penche * -sommet
		var x0 := _penche * -bas
		var poly := PackedVector2Array()
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		var t := t0.lightened(u * 0.06)
		var bord_d := PackedVector2Array()
		var bord_g := PackedVector2Array()
		var dents := PackedVector2Array()
		# le flanc droit, de la pointe vers le bas, un peu creusé
		for k in 5:
			var v := float(k) / 4.0
			var q := Vector2(lerpf(ax, x0 + w, v) - sin(v * PI) * w * 0.08, lerpf(sommet, bas, pow(v, 0.9)))
			poly.append(q)
			bord_d.append(q)
		# le bas, en dents d'aiguilles
		var nd := maxi(3, int(w * 2.0 / 4.2))
		for k in range(1, nd):
			var v := float(k) / nd
			var x := lerpf(x0 + w, x0 - w, v)
			var creux := k % 2 == 1
			var q := Vector2(x + r.randf_range(-0.8, 0.8), bas + (-2.2 if creux else 1.2) + r.randf_range(-0.6, 0.6) - sin(v * PI) * 1.5)
			poly.append(q)
			dents.append(q)
		# le flanc gauche, du bas vers la pointe
		for k in 5:
			var v := 1.0 - float(k) / 4.0
			var q := Vector2(lerpf(ax, x0 - w, v) + sin(v * PI) * w * 0.08, lerpf(sommet, bas, pow(v, 0.9)))
			poly.append(q)
			bord_g.append(q)
		for q in poly:
			cols.append(t)
			uvs.append(Vector2(19.0 + clampf((q.x - lerpf(ax, x0, clampf((q.y - sommet) / h, 0.0, 1.0))) / w, -1.0, 1.0), 19.0 + clampf((q.y - sommet) / h, 0.0, 1.0)))
		p.aplat_libre(poly, cols, uvs)
		if froid > 0.25:
			_neige_sur(p, poly, Vector2(ax, sommet + h * 0.25), w * 0.8, h * 0.3, sommet + h * lerpf(0.3, 0.55, froid), r)
		var dents_t := PackedVector2Array([bord_d[bord_d.size() - 1]])
		dents_t.append_array(dents)
		dents_t.append(bord_g[0])
		p.tracer(dents_t, 1.3, ENCRE, false)
		p.tracer(bord_d, 1.6, ENCRE)
		p.tracer(bord_g, 0.9, ENCRE)


# de la neige posée sur un aplat : la part du polygone au-dessus d'une ligne tremblée
func _neige_sur(p, poly: PackedVector2Array, centre: Vector2, rx: float, ry: float, ligne: float, r: RandomNumberGenerator) -> void:
	var masque := PackedVector2Array([Vector2(-200, -400), Vector2(200, -400)])
	for k in 9:
		var x := lerpf(200.0, -200.0, k / 8.0)
		masque.append(Vector2(x, ligne + r.randf_range(-1.6, 1.6) + (x - centre.x) * 0.04))
	var bouts := Geometry2D.intersect_polygons(poly, masque)
	var neige := P.PAPIER.lightened(0.3)
	for b in bouts:
		p.aplat(b, neige, Pinceau.DOME, centre, Vector2(rx, ry) * 1.3)


# des festons : le contour d'un feuillage, d'un buisson (un rayon qui ondule de lobe en lobe)
static func festons(centre: Vector2, rx: float, ry: float, lobes: int, creux: float, r: RandomNumberGenerator, n := 56, aplatir := 0.0) -> PackedVector2Array:
	var phase := r.randf() * TAU
	var amp := PackedFloat32Array()
	for k in lobes:
		amp.append(r.randf_range(0.55, 1.15))
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var u := (a + phase) * lobes / TAU
		var k := int(floor(u)) % lobes
		var bosse := sin((u - floor(u)) * PI)
		var rr := 1.0 - creux + creux * pow(bosse, 0.55) * amp[k]
		var q := Vector2(cos(a) * rx * rr, sin(a) * ry * rr)
		if q.y > 0.0:
			q.y *= 1.0 - aplatir
		out.append(centre + q)
	return out


# --- les rochers, les buissons, les touffes, les brindilles ---

func _rocher(p, r: RandomNumberGenerator) -> void:
	var t := _usure()
	if reste <= 0:
		# il n'en reste qu'un tas d'éclats
		for i in 5:
			var q := Vector2(r.randf_range(-9.0, 9.0), r.randf_range(-2.0, 3.0))
			_caillou(p, q, r.randf_range(2.5, 4.5), r)
		return
	var w := _rx * t
	var h := _ry * t
	var poly := PackedVector2Array()
	for i in 7:
		var a := PI + PI * i / 6.0
		var rr := r.randf_range(0.84, 1.06)
		poly.append(Vector2(cos(a) * w * rr, -h * 0.12 + sin(a) * h * rr * 0.92))
	poly.append(Vector2(w * r.randf_range(0.75, 0.9), r.randf_range(1.8, 3.0)))
	poly.append(Vector2(w * r.randf_range(-0.1, 0.2), r.randf_range(3.0, 4.0)))
	poly.append(Vector2(-w * r.randf_range(0.75, 0.9), r.randf_range(1.8, 2.8)))
	var centre := Vector2(0, -h * 0.42)
	var pierre := teinte.lerp(P.IVOIRE, r.randf_range(0.0, 0.12))
	p.aplat(poly, pierre, Pinceau.PIERRE, centre, Vector2(w, h * 0.78))
	# les éclats arrachés : des faces claires, toutes fraîches
	var coups := plein - reste
	for i in coups:
		var k := 2 + i * 2
		var a := poly[k]
		var b := poly[k + 1]
		var m := (a + b) * 0.5 + (centre - (a + b) * 0.5) * 0.35
		var face := PackedVector2Array([a, b, m])
		p.aplat(face, pierre.lightened(0.28), Pinceau.UNI)
		p.tracer(PackedVector2Array([a, m, b]), 0.8, ENCRE)
	var humide := float(climat.get("humide", 0.5))
	if humide > 0.55 and r.randf() < 0.75:
		var mousse := festons(Vector2(-w * 0.25, -h * 0.78), w * 0.55, h * 0.24, 5, 0.3, r, 24)
		var bouts := Geometry2D.intersect_polygons(mousse, poly)
		for b in bouts:
			p.aplat(b, P.MOUSSE.lerp(teinte, 0.15), Pinceau.FEUILLAGE, Vector2(-w * 0.25, -h * 0.78), Vector2(w * 0.55, h * 0.3))
	if float(climat.get("froid", 0.0)) > 0.25:
		_neige_sur(p, poly, Vector2(-w * 0.1, -h * 0.85), w, h * 0.35, -h * lerpf(0.7, 0.5, float(climat["froid"])), r)
	# les lichens, en haut à gauche
	for i in r.randi_range(2, 5):
		var q := Vector2(r.randf_range(-0.75, 0.2) * w, r.randf_range(-0.85, -0.35) * h)
		p.disque(q, r.randf_range(0.7, 1.4), r.randf_range(0.5, 1.0), P.IVOIRE.lerp(P.MOUSSE, r.randf_range(0.1, 0.5)).darkened(0.1))
	# l'encre : le contour, une fêlure
	p.contour(poly, 1.6, ENCRE, r, 3)
	var f0 := poly[r.randi_range(1, 5)]
	var f1 := f0 + (centre - f0) * r.randf_range(0.35, 0.6) + Vector2(r.randf_range(-2, 2), r.randf_range(-1, 1))
	p.tracer(PackedVector2Array([f0, (f0 + f1) * 0.5 + Vector2(1.0, 0.6), f1]), 0.8, Color(ENCRE, 0.75))


func _caillou(p, q: Vector2, s: float, r: RandomNumberGenerator) -> void:
	var poly := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + r.randf_range(-0.3, 0.3)
		poly.append(q + Vector2(cos(a) * s, sin(a) * s * 0.7) * r.randf_range(0.8, 1.15))
	p.aplat(poly, teinte, Pinceau.PIERRE, q, Vector2(s, s * 0.8))
	p.contour(poly, 0.9, ENCRE, r, 2)


func _buisson(p, r: RandomNumberGenerator) -> void:
	var c := _ecorce()
	# des tiges qui dépassent, au pied
	for i in 3:
		var x := r.randf_range(-_rx * 0.5, _rx * 0.5)
		p.tracer(PackedVector2Array([Vector2(x, 1.5), Vector2(x * 1.3 + r.randf_range(-2, 2), -5.0)]), 1.3, c)
	var centre := Vector2(0, -_ry * 0.5)
	var poly := festons(centre, _rx, _ry * 0.55, r.randi_range(6, 8), 0.2, r, 44, 0.25)
	var t := teinte.lerp(P.FEUILLE_SOMBRE, 0.2)
	if reste <= 0:
		t = t.lerp(P.TERRE, 0.12)
	p.aplat(poly, t, Pinceau.FEUILLAGE, centre, Vector2(_rx, _ry * 0.55) * 1.08)
	p.contour(poly, 1.35, ENCRE, r, 3)
	if epineux:
		# (une plante épineuse : de petites épines d'encre, tournées vers dehors, sur le haut et les flancs)
		for i in range(0, poly.size(), 4):
			var q: Vector2 = poly[i]
			var dehors := (q - centre).normalized()
			if dehors.y > 0.5:
				continue
			p.tracer(PackedVector2Array([q - dehors * 0.6, q + dehors * 2.6 + dehors.orthogonal() * 0.8]), 0.9, ENCRE)
	for i in 2:
		var q := centre + Vector2(r.randf_range(0.0, 0.6) * _rx, r.randf_range(0.0, 0.4) * _ry * 0.5)
		var arc := PackedVector2Array()
		for k in 5:
			var a := 0.1 + k * 0.33
			arc.append(q + Vector2(cos(a), sin(a) * 0.8) * 4.5)
		p.tracer(arc, 0.8, Color(ENCRE, 0.55))
	# les baies : des grappes luisantes, d'autant moins qu'on en a cueilli
	var baie := P.SANG.lerp(P.BRAISE_ROUGE, 0.55).lightened(0.06)
	var rb := RandomNumberGenerator.new()
	rb.seed = graine + 5
	for g in 3:
		var q := centre + Vector2(rb.randf_range(-0.6, 0.6) * _rx, rb.randf_range(-0.5, 0.45) * _ry * 0.55)
		for k in 3:
			if g * 3 + k >= reste * 3:
				continue
			var b := q + Vector2.from_angle(k * 2.1 + g) * 2.4
			p.disque(b, 2.45, 2.35, ENCRE)
			p.disque(b, 1.85, 1.8, baie, Pinceau.DOME)
			p.disque(b + Vector2(-0.6, -0.7), 0.6, 0.55, Color(1.0, 0.96, 0.9, 0.95))


func _touffe(p, r: RandomNumberGenerator) -> void:
	var paille := teinte.lerp(P.IVOIRE, 0.35)
	var vert := teinte.lightened(0.08)
	if reste <= 0:
		# arrachée : la terre nue, des chaumes, une tige couchée
		p.eventail(Vector2(0, 1), 7.0, 2.8, Color(P.TERRE.darkened(0.3), 0.7), Color(P.TERRE.darkened(0.3), 0.0), 12)
		for i in 6:
			var x := r.randf_range(-4.0, 4.0)
			p.tracer(PackedVector2Array([Vector2(x, 1), Vector2(x + r.randf_range(-1, 1), -r.randf_range(2.5, 4.5))]), 1.2, paille.darkened(0.2), false)
		var a := r.randf_range(-0.3, 0.3)
		var d := Vector2.from_angle(a)
		p.tracer(PackedVector2Array([Vector2(-3, 2) - d * 6.0, Vector2(-3, 2.5), Vector2(-3, 2) + d * 7.0]), 1.1, paille)
		return
	var n := 10 + reste * 4
	var lames: Array = []
	for i in n:
		var x0 := r.randf_range(-3.5, 3.5)
		var cote := signf(x0 + r.randf_range(-0.5, 0.5))
		var h := r.randf_range(12.0, 21.0) * (1.0 if reste >= plein else 0.85) * (1.75 if port == "roseau" else 1.0)
		# (un roseau : plus haut, plus droit)
		var bout := Vector2(x0 * 2.0 + cote * r.randf_range(2.0, 11.0) * (0.4 if port == "roseau" else 1.0), -h)
		var milieu := Vector2(x0 * 1.3 + bout.x * 0.35, -h * 0.62)
		lames.append([Vector2(x0, 1.0), milieu, bout, r.randf()])
	# de l'arrière vers l'avant : les lames du fond, plus sombres, puis celles du devant, cernées d'encre
	lames.sort_custom(func(a, b): return a[3] < b[3])
	for i in lames.size():
		var l: Array = lames[i]
		var ligne := PackedVector2Array()
		for k in 6:
			var v := k / 5.0
			ligne.append(l[0].lerp(l[1], v).lerp(l[1].lerp(l[2], v), v))
		var avant := float(i) / lames.size()
		var larg := PackedFloat32Array()
		for k in 6:
			larg.append(lerpf(2.5, 0.4, k / 5.0))
		if avant > 0.35:
			var larg_e := PackedFloat32Array()
			for k in 6:
				larg_e.append(larg[k] + 0.9)
			p.tracer(ligne, 2.6, ENCRE, false, larg_e)
		p.tracer(ligne, 2.0, vert.lerp(paille, avant * 0.55).darkened((1.0 - avant) * 0.22), false, larg)
		# (un roseau : un épi brun au bout de quelques tiges)
		if port == "roseau" and int(l[3] * 10.0) % 4 == 0:
			var epi: Vector2 = l[2] + (l[1] - l[2]).normalized() * 4.0
			p.disque(epi, 1.9, 4.2, ENCRE)
			p.disque(epi, 1.3, 3.5, P.TERRE.lightened(0.08), Pinceau.DOME)
	# des épis, au bout de quelques lames
	for i in mini(3, lames.size()):
		var l: Array = lames[lames.size() - 1 - i * 2]
		var bout: Vector2 = l[2]
		var dir: Vector2 = (bout - l[1]).normalized()
		p.disque(bout - dir * 1.5, 1.1, 2.2, ENCRE)
		p.disque(bout - dir * 1.5, 0.75, 1.7, P.IVOIRE.lerp(P.BRAISE, 0.3))


func _brindille(p, r: RandomNumberGenerator) -> void:
	var bois := P.TERRE.lerp(P.BRAISE, 0.12)
	for i in 3:
		var a := r.randf_range(-0.5, 0.5) + (PI * 0.5 if i == 1 else 0.0) + r.randf_range(-0.3, 0.3)
		var l := r.randf_range(7.0, 11.0)
		var d := Vector2(cos(a), sin(a) * 0.6)
		var m := Vector2(r.randf_range(-2, 2), r.randf_range(-1.5, 1.5))
		var ligne := PackedVector2Array([m - d * l, m + d.orthogonal() * r.randf_range(-1.0, 1.0), m + d * l])
		p.tracer(ligne, 3.1, ENCRE)
		p.tracer(ligne, 2.1, bois)
		p.tracer(PackedVector2Array([ligne[0] + Vector2(0, -0.5), ligne[1] + Vector2(0, -0.6), ligne[2] + Vector2(0, -0.5)]), 0.6, bois.lightened(0.3))
		if r.randf() < 0.6:
			var b := m + d * r.randf_range(-3.0, 4.0)
			var e := b + Vector2.from_angle(a + r.randf_range(0.6, 1.0)) * r.randf_range(3.0, 5.0)
			p.tracer(PackedVector2Array([b, e]), 2.2, ENCRE)
			p.tracer(PackedVector2Array([b, e]), 1.3, bois)
		p.disque(ligne[2], 0.75, 0.7, P.IVOIRE.lerp(P.BRAISE, 0.2).darkened(0.25))


# la couronne d'un arbre : un nœud à part, qui se dessine par son arbre
class Couronne extends Node2D:
	var objet

	func _draw() -> void:
		objet._dessiner_couronne(self)
