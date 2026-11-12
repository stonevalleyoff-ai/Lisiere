extends Node2D
# Lisière — ce que le temps fait au sol (scripts/temps_sol.gd)
# Le sol détrempé, les flaques, l'eau montée dans les creux, la neige qui tient, le présage de la foudre et la foudre elle-même :
# ce que le temps qu'il fait (scripts/climat.gd) dessine dans le lieu. principal.gd le pose à chaque nouvelle partie, après que
# le climat du lieu est prêt ; il part avec la scène.
#  - le sol : un seul grand rectangle (shaders/temps_sol.gdshader), sous la lueur des feux et sous ce qui se tient debout. Le
#    relief (climat.relief) et le bruit des flaques (climat._flaques) y sont cuits une fois, dans deux petites textures ; à
#    chaque image, quelques nombres (la crue, la boue, la neige, la pluie). Il se cache quand il n'a rien à montrer.
#  - la foudre, au-dessus de tout : son présage (le sol pâlit jusqu'où elle blessera, un cercle se resserre, des étincelles
#    montent), puis l'éclair (un trait brisé du haut de l'écran, ses branches, d'un seul maillage), sa lumière sur ce qui
#    l'entoure, une gerbe, l'image qui reste dans l'œil, et la marque brûlée au sol.
# Au pire moment (un éclair, l'eau montée) : quatre appels de dessin. Par temps sec : aucun.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")
const Decor := preload("res://scripts/decor.gd")
const Feu := preload("res://scripts/feu.gd")
const SOL := preload("res://shaders/temps_sol.gdshader")
const MARQUE := 18.0           # secondes : la marque brûlée s'efface
const ECLAIR := 0.8            # secondes : l'éclair (deux coups, 0,2 s), puis son image qui reste dans l'œil
const VIF := 0.2
const RELIEF_MILIEU := 0.38

static var _bruit_fin: Texture2D

var jeu
var _climat
var _nappe: Node2D
var _mat: ShaderMaterial
var _mobile := false
var _t := 0.0
var _montre := false
var _presages: Array = []      # [où, ce qui reste, la durée, le rayon, dans l'eau]
var _marques: Array = []       # [où, son âge, son rayon]
var _foudre_a_dire := true     # (les présages, les marques ont changé : à redonner au shader)
var _eclair := -1.0            # l'âge de l'éclair qu'on voit (-1 : aucun)
var _eclat := 0.0              # l'éclat du ciel, que l'eau renvoie (même quand elle tombe loin)
var _ou := Vector2.ZERO
var _trait: MeshInstance2D
var _lumiere: PointLight2D
var _etincelles: CPUParticles2D
var _gerbe: CPUParticles2D
var _gerbe_reste := 0.0
var _etincelles_reste := 0.0
var _avant := Vector2.ZERO     # où était la veilleuse à l'image d'avant
var _remue := 0.0
var _r := RandomNumberGenerator.new()


# la scène du lieu (le sol, puis le monde et ce qui s'y tient debout, trié par y), au début d'une partie
func poser(scene: Node2D, monde: Node2D) -> void:
	if jeu == null or jeu.climat == null:
		return
	_climat = jeu.climat
	_mobile = str(jeu.qualite) == "mobile"
	_r.randomize()
	_mat = ShaderMaterial.new()
	_mat.shader = SOL
	_cuire()
	_couleurs()
	_mat.set_shader_parameter("etendue", Decor.ETENDUE)
	_mat.set_shader_parameter("demi", R.DEMI)
	_mat.set_shader_parameter("simple", _mobile)
	_nappe = Nappe.new()
	_nappe.name = "TempsSol"
	_nappe.material = _mat
	_nappe.visible = false
	scene.add_child(_nappe)
	# (sur le sol peint et son herbe ; sous la lueur des feux, la brume, et tout ce qui se tient debout)
	var lueurs: Node = scene.get_node_or_null("EffetsSol")
	scene.move_child(_nappe, lueurs.get_index() if lueurs != null else monde.get_index())
	_poser_la_foudre()
	_climat.presage.connect(_sur_presage)
	_climat.foudre.connect(_sur_foudre)


# --- le relief et les flaques, cuits une fois ---

func _cuire() -> void:
	# (sans écran, rien ne se peint : deux textures de rien)
	var sans_ecran := DisplayServer.get_name() == "headless"
	var etendue: float = Decor.ETENDUE
	# le relief : le bruit de climat.relief, en demi-flottants (un octet ne suffit pas : le bord de l'eau ferait des marches),
	# compté depuis RELIEF_MILIEU, là où sont les rives, pour y être le plus fin. La butte du réveil, le shader l'ajoute.
	var n := 8 if sans_ecran else (384 if _mobile else 512)
	var bruit: FastNoiseLite = _climat._relief
	var valeurs := PackedFloat32Array()
	valeurs.resize(n * n)
	var pas := etendue / n
	var i := 0
	for y in n:
		var wy := (y + 0.5) * pas - etendue * 0.5
		for x in n:
			valeurs[i] = bruit.get_noise_2d((x + 0.5) * pas - etendue * 0.5, wy) * 0.5 + 0.5 - RELIEF_MILIEU
			i += 1
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, valeurs.to_byte_array())
	img.convert(Image.FORMAT_RH)
	_mat.set_shader_parameter("relief", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("relief_milieu", RELIEF_MILIEU)
	# les flaques : le bruit de climat.allure, lu par Godot lui-même (à la même échelle, au milieu de chaque texel). Ses
	# octaves les plus fines, plus petites qu'un texel, n'y sont pas : le gain rend à la valeur sa mesure.
	var m := 8 if sans_ecran else (512 if _mobile else 1024)
	var vrai: FastNoiseLite = _climat._flaques
	var f: FastNoiseLite = vrai.duplicate()
	var gain := 1.0
	if vrai.fractal_type == FastNoiseLite.FRACTAL_FBM:
		f.fractal_octaves = mini(vrai.fractal_octaves, 2 if _mobile else 3)
		gain = _somme(vrai.fractal_gain, f.fractal_octaves) / _somme(vrai.fractal_gain, vrai.fractal_octaves)
	f.frequency = vrai.frequency * etendue / m
	f.offset = Vector3(0.5 - m * 0.5 + vrai.offset.x * m / etendue, 0.5 - m * 0.5 + vrai.offset.y * m / etendue, 0.0)
	_mat.set_shader_parameter("flaques", _fine(f.get_image(m, m, false, false, false)))
	_mat.set_shader_parameter("flaques_gain", gain)
	_mat.set_shader_parameter("bruit", bruit_fin())


# (une image d'octets, passée en demi-flottants : entre deux texels, le filtrage ne fait plus de marches, sur aucune carte.
# Un bord tiré d'un seuil en a besoin pour rester net.)
static func _fine(img: Image) -> ImageTexture:
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RH)
	return ImageTexture.create_from_image(img)


# le bruit doux des effets (scripts/effets_textures.gd), sans marches : le sol et le ciel y tracent des bords
static func bruit_fin() -> Texture2D:
	if _bruit_fin == null:
		_bruit_fin = _fine(T.bruit().get_image())
	return _bruit_fin


static func _somme(gain: float, octaves: int) -> float:
	var s := 0.0
	var a := 1.0
	for k in octaves:
		s += a
		a *= absf(gain)
	return s


# les couleurs : celles du lieu (monde.gd, couleurs) et de la palette
func _couleurs() -> void:
	var pal: Dictionary = jeu.monde.palette if jeu.monde != null else {}
	var eau: Color = pal.get("eau", P.NUIT_BLEUE.lerp(P.FEUILLE_SOMBRE, 0.45))
	var boue: Color = pal.get("boue", P.ENCRE_DOUCE.lerp(P.TERRE, 0.45))
	_mat.set_shader_parameter("c_feu", P.BRAISE.lerp(P.BRAISE_COEUR, 0.3))
	_mat.set_shader_parameter("c_eau", eau.lerp(P.LUNE, 0.34))
	_mat.set_shader_parameter("c_fond", eau.lerp(P.NUIT_BLEUE, 0.45).darkened(0.12))
	_mat.set_shader_parameter("c_reflet", P.PAPIER.lerp(P.LUNE, 0.28))
	_mat.set_shader_parameter("c_boue", boue)
	_mat.set_shader_parameter("c_flaque", boue.lerp(P.TERRE, 0.4).lerp(eau, 0.2))
	_mat.set_shader_parameter("c_neige", pal.get("neige", P.PAPIER.lightened(0.35)))
	_mat.set_shader_parameter("c_neige_ombre", pal.get("neige_ombre", P.LUNE.lerp(P.PAPIER, 0.45)))
	_mat.set_shader_parameter("c_encre", P.ENCRE)
	_mat.set_shader_parameter("c_foudre", _blanc_foudre())
	_mat.set_shader_parameter("c_braise", P.BRAISE)


static func _blanc_foudre() -> Color:
	return P.PAPIER.lerp(P.ECHO, 0.6).lightened(0.25)


# --- chaque image ---

func _process(delta: float) -> void:
	if _mat == null or jeu == null or not jeu.en_partie or jeu.en_pause or not is_instance_valid(_nappe):
		return
	var c = _climat
	_la_foudre(delta)
	var pluie: float = c.pluie
	var montre: bool = c.boue > 0.02 or c.crue > 0.01 or c.neige_sol > 0.02 or pluie > 0.03 or not _presages.is_empty() or not _marques.is_empty() or _eclair >= 0.0 or _eclat > 0.0
	if montre != _montre:
		_montre = montre
		_nappe.visible = montre
	if not montre:
		return
	_t = fposmod(_t + delta, 3600.0)
	var jour: float = jeu.lumiere_du_jour()
	var m := _mat
	m.set_shader_parameter("temps", _t)
	m.set_shader_parameter("crue", c.crue)
	m.set_shader_parameter("boue", c.boue)
	m.set_shader_parameter("neige_sol", c.neige_sol)
	m.set_shader_parameter("pluie", pluie)
	m.set_shader_parameter("nuit", 1.0 - jour)
	m.set_shader_parameter("obscur", jeu.obscurite.color if jeu.obscurite != null else Color.WHITE)
	var l := lumieres(jeu, 1.0 - jour)
	m.set_shader_parameter("feu0", l[0])
	m.set_shader_parameter("feu1", l[1])
	m.set_shader_parameter("torche", l[2])
	# la veilleuse dans l'eau : elle la remue quand elle marche
	var j = jeu.joueur
	if j != null and c.crue > 0.01:
		var p: Vector2 = j.position
		var va := p.distance_to(_avant) / maxf(delta, 0.001)
		_avant = p
		_remue = lerpf(_remue, clampf(va / 60.0, 0.25, 1.0) * clampf(float(c.eau(p)) * 3.0, 0.0, 1.0), clampf(delta * 5.0, 0.0, 1.0))
		m.set_shader_parameter("pieds", Vector4(p.x, p.y, _remue, 0.0))


# les lumières que le sol mouillé et la brume renvoient : les deux feux les plus proches de la veilleuse (un feu de camp, ce qui
# brûle) et sa torche (Vector4 : où, rayon, force). De jour, elles ne comptent pas. (le ciel s'en sert aussi : scripts/ciel.gd)
static func lumieres(jeu, nuit: float) -> Array:
	var l := [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	if nuit < 0.05 or jeu == null:
		return l
	var j = jeu.joueur
	var ici: Vector2 = j.position if j != null else Vector2.ZERO
	var d0 := INF
	var d1 := INF
	var tous: Array = []
	tous.append_array(jeu.feux)
	if jeu.incendie != null:
		tous.append_array(jeu.incendie.foyers)
	for f in tous:
		if not is_instance_valid(f) or not f.allume():
			continue
		var q: Vector2 = f.position
		var d := ici.distance_squared_to(q)
		if d >= d1:
			continue
		var v := Vector4(q.x, q.y - 10.0, f.rayon(), nuit)
		if d < d0:
			d1 = d0
			l[1] = l[0]
			d0 = d
			l[0] = v
		else:
			d1 = d
			l[1] = v
	if j != null and j.torche > 0.0 and j.lumiere != null:
		var p: Vector2 = j.lumiere.global_position
		l[2] = Vector4(p.x, p.y, R.RAYON_TORCHE, nuit * minf(1.0, j.lumiere.energy))
	return l


# --- la foudre ---

func _poser_la_foudre() -> void:
	var blanc := _blanc_foudre()
	# l'éclair et ses étincelles : au-dessus de tout, du voile du ciel aussi (scripts/ciel.gd, couche 2), dans leur couche à
	# eux, qui suit la vue. Sa lumière, elle, reste dans le lieu : elle éclaire ce qui s'y tient.
	var dessus := CanvasLayer.new()
	dessus.layer = 3
	dessus.follow_viewport_enabled = true
	add_child(dessus)
	_trait = MeshInstance2D.new()
	_trait.visible = false
	dessus.add_child(_trait)
	_lumiere = PointLight2D.new()
	_lumiere.texture = Feu.texture_lumiere()
	_lumiere.color = blanc
	_lumiere.enabled = false
	add_child(_lumiere)
	# les étincelles du présage : elles naissent dans le cercle, et montent vers le point où elle tombera
	var e := CPUParticles2D.new()
	e.amount = 12 if _mobile else 26
	e.lifetime = 0.42
	e.lifetime_randomness = 0.35
	e.local_coords = false
	e.texture = T.etincelle()
	e.material = T.materiau(true, false)
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = R.FOUDRE_RAYON * 0.9
	e.direction = Vector2(0, -1)
	e.spread = 30.0
	e.gravity = Vector2(0, -90)
	e.initial_velocity_min = 10.0
	e.initial_velocity_max = 50.0
	e.radial_accel_min = -420.0
	e.radial_accel_max = -180.0
	e.scale_amount_min = 0.22
	e.scale_amount_max = 0.5
	e.color_ramp = T.rampe([[0.0, Color(blanc, 0.0)], [0.2, Color(blanc, 0.95)], [0.6, Color(Color.WHITE, 0.9)], [1.0, Color(blanc, 0.0)]])
	e.emitting = false
	e.visible = false
	dessus.add_child(e)
	_etincelles = e
	# la gerbe : là où elle tombe, des éclats blancs qui retombent en braises
	var g := CPUParticles2D.new()
	g.amount = 12 if _mobile else 26
	g.lifetime = 0.65
	g.lifetime_randomness = 0.4
	g.one_shot = true
	g.explosiveness = 0.95
	g.local_coords = false
	g.texture = T.etincelle()
	g.material = T.materiau(true, false)
	g.direction = Vector2(0, -1)
	g.spread = 80.0
	g.gravity = Vector2(0, 560)
	g.initial_velocity_min = 110.0
	g.initial_velocity_max = 340.0
	g.damping_min = 60.0
	g.damping_max = 160.0
	g.scale_amount_min = 0.3
	g.scale_amount_max = 0.6
	g.color_ramp = T.rampe([[0.0, Color(Color.WHITE, 1.0)], [0.3, Color(blanc, 0.95)], [0.7, Color(P.BRAISE, 0.8)], [1.0, Color(P.BRAISE_ROUGE, 0.0)]])
	g.emitting = false
	g.visible = false
	dessus.add_child(g)
	_gerbe = g


# elle va tomber en p : le sol pâlit jusqu'où elle blessera, des étincelles montent
func _sur_presage(p: Vector2, dans: float) -> void:
	# (les pieds dans l'eau, elle blesse près de deux fois plus loin : principal.gd, foudre_tombee)
	var mouille := 1.0 if float(_climat.eau(p)) > 0.05 else 0.0
	_presages.append([p, dans, maxf(dans, 0.05), R.FOUDRE_RAYON, mouille])
	while _presages.size() > 2:
		_presages.pop_front()
	_foudre_a_dire = true
	if _a_l_ecran(p, R.FOUDRE_RAYON + 40.0):
		_etincelles.position = p
		_etincelles.visible = true
		_etincelles.restart()
		_etincelles.emitting = true
		_etincelles_reste = dans + 0.5
		_lumiere.position = p + Vector2(0, -20)
		_lumiere.texture_scale = R.FOUDRE_RAYON * 1.7 / 128.0
		_lumiere.energy = 0.0
		_lumiere.enabled = true


# elle tombe : l'éclair, sa lumière, sa gerbe, sa marque
func _sur_foudre(p: Vector2, sur) -> void:
	# (son présage a fait son temps)
	for i in _presages.size():
		if (_presages[i][0] as Vector2).distance_squared_to(p) < 4.0:
			_presages.remove_at(i)
			break
	var arbre: bool = sur != null and is_instance_valid(sur)
	_marques.append([p, 0.0, 17.0 if arbre else 27.0])
	while _marques.size() > 4:
		_marques.pop_front()
	_foudre_a_dire = true
	_etincelles.emitting = false
	# loin de l'écran : son éclat seul (scripts/ciel.gd), que l'eau renvoie
	if not _a_l_ecran(p, 200.0):
		_eclat = maxf(_eclat, 0.45)
		return
	_eclat = 1.0
	var bas := p
	if arbre and sur.get("hauteur") != null:
		bas = p + Vector2(0.0, -float(sur.hauteur) * 0.8)
	_ou = p
	_eclair = 0.0
	_trait.mesh = _batir(bas)
	_trait.modulate = Color.WHITE
	_trait.visible = true
	_lumiere.position = bas + Vector2(0, -12)
	_lumiere.texture_scale = 620.0 / 128.0
	_lumiere.energy = 2.4
	_lumiere.enabled = true
	_gerbe.position = bas
	_gerbe.visible = true
	_gerbe.restart()
	_gerbe.emitting = true
	_gerbe_reste = 1.1


func _a_l_ecran(p: Vector2, marge: float) -> bool:
	var cam: Camera2D = jeu.camera
	if cam == null or not is_instance_valid(cam) or not is_inside_tree():
		return false
	var demi: Vector2 = get_viewport_rect().size / cam.zoom * 0.5 + Vector2(marge, marge)
	var d: Vector2 = (p - cam.get_screen_center_position()).abs()
	return d.x < demi.x and d.y < demi.y


# l'éclair : du haut de l'écran jusqu'à son point, un trait brisé et ses branches, d'un seul maillage. Trois épaisseurs,
# l'une sur l'autre : un halo pâle, un cerne d'encre bleue (il se lit en plein jour), le cœur blanc.
func _batir(bas: Vector2) -> ArrayMesh:
	var cam: Camera2D = jeu.camera
	var vue: Vector2 = get_viewport_rect().size / cam.zoom
	var haut := Vector2(bas.x + _r.randf_range(-0.25, 0.25) * vue.y, cam.get_screen_center_position().y - vue.y * 0.5 - 80.0)
	if haut.y > bas.y - 160.0:
		haut.y = bas.y - 420.0
	var canal := _brise(haut, bas, 5, 0.2)
	var traits: Array = [[canal, 2.7, 1.7]]
	# ses branches : elles partent du canal, vers le bas, et s'amenuisent
	var longueur := haut.distance_to(bas)
	for k in _r.randi_range(2, 4):
		var i := _r.randi_range(int(canal.size() * 0.15), int(canal.size() * 0.72))
		var sens: Vector2 = (canal[i + 1] - canal[i - 1]).normalized().rotated(_r.randf_range(0.35, 0.95) * (1.0 if _r.randf() < 0.5 else -1.0))
		var bout: Vector2 = canal[i] + sens * longueur * _r.randf_range(0.14, 0.34)
		var branche := _brise(canal[i], bout, 3, 0.24)
		traits.append([branche, 1.4, 0.2])
		if k == 0:
			var j := _r.randi_range(3, 6)
			var bout2: Vector2 = branche[j] + sens.rotated(_r.randf_range(-0.9, 0.9)) * longueur * 0.1
			traits.append([_brise(branche[j], bout2, 2, 0.25), 0.9, 0.1])
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var blanc := _blanc_foudre()
	var cerne := P.NUIT_BLEUE.lerp(P.LUNE, 0.2)
	for t in traits:
		_ruban(pts, cols, idx, t[0], float(t[1]) * 1.3, float(t[2]) * 1.3, 11.0, Color(blanc, 0.34))
	for t in traits:
		_ruban(pts, cols, idx, t[0], float(t[1]) + 2.2, float(t[2]) + 1.5, 1.2, Color(cerne, 0.9))
	for t in traits:
		_ruban(pts, cols, idx, t[0], float(t[1]), float(t[2]), 1.0, Color(blanc.lightened(0.6), 1.0))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pts
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


# un trait brisé de a à b : on coupe chaque segment en deux, et on écarte le milieu, plusieurs fois
func _brise(a: Vector2, b: Vector2, fois: int, ecart: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	for k in fois:
		var suite := PackedVector2Array()
		for i in pts.size() - 1:
			var u: Vector2 = pts[i]
			var w: Vector2 = pts[i + 1]
			suite.append(u)
			suite.append((u + w) * 0.5 + (w - u).orthogonal() * _r.randf_range(-ecart, ecart))
		suite.append(pts[pts.size() - 1])
		pts = suite
	return pts


# un ruban le long d'une ligne : sa demi-largeur du début à la fin, et une frange qui s'efface de chaque côté
func _ruban(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, ligne: PackedVector2Array, demi0: float, demi1: float, frange: float, c: Color) -> void:
	var base := pts.size()
	var n := ligne.size()
	var c0 := Color(c, 0.0)
	for i in n:
		var d: Vector2 = (ligne[mini(i + 1, n - 1)] - ligne[maxi(i - 1, 0)]).normalized().orthogonal()
		var demi := lerpf(demi0, demi1, float(i) / float(n - 1))
		pts.append(ligne[i] - d * (demi + frange))
		pts.append(ligne[i] - d * demi)
		pts.append(ligne[i] + d * demi)
		pts.append(ligne[i] + d * (demi + frange))
		cols.append(c0)
		cols.append(c)
		cols.append(c)
		cols.append(c0)
	for i in n - 1:
		var q := base + i * 4
		for k in 3:
			idx.append_array(PackedInt32Array([q + k, q + k + 1, q + k + 4, q + k + 1, q + k + 5, q + k + 4]))


# chaque image : les présages mûrissent, l'éclair passe, les marques s'effacent ; le shader du sol en reçoit ce qu'il dessine
func _la_foudre(delta: float) -> void:
	if _etincelles_reste > 0.0:
		_etincelles_reste -= delta
		if _etincelles_reste <= 0.0:
			_etincelles.emitting = false
			_etincelles.visible = false
	if _gerbe_reste > 0.0:
		_gerbe_reste -= delta
		if _gerbe_reste <= 0.0:
			_gerbe.visible = false
	var m := _mat
	# les présages
	var i := 0
	while i < _presages.size():
		var q: Array = _presages[i]
		q[1] = float(q[1]) - delta
		# (la foudre l'enlève en tombant ; s'il traîne, il s'en va)
		if float(q[1]) < -0.3:
			_presages.remove_at(i)
			_foudre_a_dire = true
		else:
			i += 1
	if not _presages.is_empty() or _foudre_a_dire:
		for k in 2:
			var v := Vector4.ZERO
			var eau := 0.0
			if k < _presages.size():
				var q: Array = _presages[k]
				var u := clampf(1.0 - float(q[1]) / float(q[2]), 0.0, 1.0)
				v = Vector4(q[0].x, q[0].y, u, float(q[3]))
				eau = float(q[4])
				if _eclair < 0.0 and _lumiere.enabled and k == _presages.size() - 1:
					_lumiere.energy = 0.55 * u * u * (0.8 + 0.2 * sin(_t * 40.0))
			m.set_shader_parameter("presage%d" % k, v)
			m.set_shader_parameter("presage_eau%d" % k, eau)
	if _presages.is_empty() and _eclair < 0.0 and _lumiere.enabled:
		_lumiere.enabled = false
	# les marques
	if not _marques.is_empty() or _foudre_a_dire:
		i = 0
		while i < _marques.size():
			_marques[i][1] = float(_marques[i][1]) + delta
			if float(_marques[i][1]) >= MARQUE:
				_marques.remove_at(i)
			else:
				i += 1
		for k in 4:
			var v := Vector4.ZERO
			if k < _marques.size():
				var q: Array = _marques[k]
				v = Vector4(q[0].x, q[0].y, 1.0 - float(q[1]) / MARQUE, float(q[2]))
			m.set_shader_parameter("marque%d" % k, v)
	_foudre_a_dire = false
	if _eclat > 0.0:
		_eclat = maxf(0.0, _eclat - delta * 3.5)
		m.set_shader_parameter("eclair", _eclat * _eclat)
	# l'éclair : deux coups, puis son image qui reste dans l'œil, violette, et s'efface
	if _eclair < 0.0:
		return
	_eclair += delta
	var t := _eclair
	var vif := 0.0
	if t < VIF:
		vif = 1.0 if t < 0.07 else (0.3 if t < 0.11 else 0.85)
		_trait.modulate = Color(1, 1, 1, vif)
	else:
		var reste := clampf(1.0 - (t - VIF) / (ECLAIR - VIF), 0.0, 1.0)
		_trait.modulate = Color(0.66, 0.6, 0.95, 0.5 * reste * reste)
		vif = 0.25 * reste * reste
	_lumiere.energy = 2.4 * vif
	m.set_shader_parameter("impact", Vector4(_ou.x, _ou.y, 0.8 * vif, 170.0))
	if t >= ECLAIR:
		_eclair = -1.0
		_trait.visible = false
		_trait.mesh = null
		_lumiere.enabled = false
		m.set_shader_parameter("impact", Vector4.ZERO)


# le rectangle du sol : il couvre le lieu et ses abords ; le shader fait le reste
class Nappe extends Node2D:
	const RG := preload("res://scripts/regles.gd")

	func _draw() -> void:
		var d := RG.DEMI + 320.0
		draw_rect(Rect2(-d, -d, d * 2.0, d * 2.0), Color.WHITE)
