extends Node2D
# Lisière — le temps qu'il fait, devant la caméra (scripts/ciel.gd)
# Ce qui tombe et ce qui couvre l'écran, d'après le temps de la partie (scripts/climat.gd), force par force :
#  - ce qui tombe : la pluie, du crachin à l'averse, couchée par le vent et ses rafales ; la neige. Un seul MultiMesh, que son
#    shader anime (shaders/temps_chute.gdshader) : un appel de dessin, rien à calculer par goutte ;
#  - le voile (shaders/temps_ciel.gdshader) : le ciel qui s'assombrit sous l'orage (l'ombre des nuages passe), les rideaux de
#    la pluie, le brouillard qui ne laisse voir qu'autour de soi, le voile de la neige, la lumière écrasée de la canicule,
#    l'éclat de la foudre (plus faible quand elle tombe hors de l'écran) : un appel de dessin, sans lire l'image ;
#  - en qualité haute, l'air qui tremble sous la canicule (shaders/temps_chaleur.gdshader : il lit l'écran).
# Ce que le temps fait au sol, et la foudre elle-même : scripts/temps_sol.gd. Un temps clair ne dessine rien.

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")
const Sol := preload("res://scripts/temps_sol.gd")
const VOILE := preload("res://shaders/temps_ciel.gdshader")
const CHUTE := preload("res://shaders/temps_chute.gdshader")
const CHALEUR := preload("res://shaders/temps_chaleur.gdshader")
const TOUR := 23100.0          # (au bout de ce chemin, les nappes poussées par le vent retombent sur elles-mêmes)

# le temps qu'il fait pendant la partie (scripts/climat.gd) : le ciel le suit
var climat
var _jeu
var _mobile := false
var _voile: Sprite2D
var _tremble: Sprite2D
var _chute: MultiMeshInstance2D
var _m_voile: ShaderMaterial
var _m_tremble: ShaderMaterial
var _m_chute: ShaderMaterial
var _taille := Vector2.ZERO
var _t := 0.0
var _derive := Vector2.ZERO
var _pente := 0.1
var _couvert := 0.0
var _eclair := -1.0            # l'âge de l'éclat de la foudre (-1 : aucun)
var _eclair_force := 0.0


func _ready() -> void:
	if climat == null or climat.jeu == null:
		set_process(false)
		return
	_jeu = climat.jeu
	_mobile = str(_jeu.qualite) == "mobile"
	var bruit := Sol.bruit_fin()
	if not _mobile:
		_m_tremble = ShaderMaterial.new()
		_m_tremble.shader = CHALEUR
		_m_tremble.set_shader_parameter("bruit", bruit)
		_tremble = _plein(_m_tremble)
	_m_voile = ShaderMaterial.new()
	_m_voile.shader = VOILE
	_m_voile.set_shader_parameter("bruit", bruit)
	_m_voile.set_shader_parameter("c_orage", P.NUIT.lerp(P.NUIT_BLEUE, 0.55))
	_m_voile.set_shader_parameter("c_pluie", P.LUNE.lerp(P.PAPIER, 0.4))
	_m_voile.set_shader_parameter("c_brume", P.IVOIRE.lerp(P.LUNE, 0.22).lightened(0.12))
	_m_voile.set_shader_parameter("c_brume_nuit", P.NUIT.lerp(P.LUNE, 0.2))
	_m_voile.set_shader_parameter("c_neige", P.PAPIER.lightened(0.3).lerp(P.LUNE, 0.1))
	_m_voile.set_shader_parameter("c_chaleur", P.BRAISE_COEUR.lerp(P.PAPIER, 0.55))
	_m_voile.set_shader_parameter("c_feu", P.BRAISE.lerp(P.BRAISE_COEUR, 0.3))
	_m_voile.set_shader_parameter("c_eclat", P.PAPIER.lerp(P.ECHO, 0.6).lightened(0.3))
	_voile = _plein(_m_voile)
	_m_chute = ShaderMaterial.new()
	_m_chute.shader = CHUTE
	_chute = MultiMeshInstance2D.new()
	_chute.multimesh = _gouttes(170 if _mobile else 420)
	_chute.material = _m_chute
	_chute.visible = false
	add_child(_chute)
	climat.foudre.connect(_sur_foudre)


# un rectangle de tout l'écran, pour un shader qui dessine tout lui-même (UV de 0 à 1)
func _plein(m: ShaderMaterial) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = T.blanc()
	s.centered = false
	s.material = m
	s.visible = false
	add_child(s)
	return s


# de quoi faire l'averse la plus drue, ou la neige la plus serrée : n petits rectangles, chacun avec son sort
# (où il tombe, sa taille, son rang : shaders/temps_chute.gdshader)
func _gouttes(n: int) -> MultiMesh:
	var carre := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	carre.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = carre
	mm.instance_count = n
	# (le shader les place : pour Godot, ils couvrent tout l'écran, quel qu'il soit)
	mm.custom_aabb = AABB(Vector3(-200, -200, -1), Vector3(8000, 8000, 2))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in n:
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), r.randf(), (i + 0.5) / n))
	return mm


func _process(delta: float) -> void:
	if _jeu == null or not _jeu.en_partie:
		return
	var c = climat
	if not _jeu.en_pause:
		_t = fposmod(_t + delta, 3600.0)
	var jour: float = _jeu.lumiere_du_jour()
	var pluie: float = c.pluie
	var orage: float = c.orage
	var neige: float = c.neige
	var brouillard: float = c.brouillard
	var chaleur: float = clampf(float(c.chaleur) / 0.3, 0.0, 1.0)
	_couvert = lerpf(_couvert, 1.0 if str(c.temps) == "couvert" else 0.0, clampf(delta / 5.0, 0.0, 1.0))
	var eclat := _eclat(delta)
	# (la nuit est déjà sombre : l'orage l'assombrit moins, on doit encore s'y retrouver)
	var sombre := (0.4 * orage + 0.14 * pluie * (1.0 - orage) + 0.1 * _couvert + 0.07 * neige + 0.05 * brouillard) * lerpf(0.4, 1.0, jour)
	var voile: bool = sombre > 0.01 or pluie > 0.03 or neige > 0.03 or brouillard > 0.01 or chaleur * jour > 0.01 or eclat > 0.0
	var tombe: bool = pluie > 0.03 or neige > 0.03
	var tremble: bool = _tremble != null and chaleur * jour > 0.02
	# (un ciel où rien ne tombe ne se dessine pas)
	_voile.visible = voile
	_chute.visible = tombe
	if _tremble != null:
		_tremble.visible = tremble
	if not voile and not tombe:
		return
	var s := get_viewport_rect().size
	if s != _taille:
		_taille = s
		_voile.scale = s / 4.0
		if _tremble != null:
			_tremble.scale = s / 4.0
			_m_tremble.set_shader_parameter("ratio", s.x / maxf(s.y, 1.0))
		_m_chute.set_shader_parameter("ecran", s)
	# le vent : il pousse les nappes, couche la pluie (plus fort dans les rafales), emporte la neige
	var vd: Vector2 = c.vent_dir
	var vent: float = c.vent
	var rafale: float = _jeu.vent()
	var cote := 1.0 if vd.x >= 0.0 else -1.0
	if not _jeu.en_pause:
		_derive += vd * (16.0 + 120.0 * vent) * delta
		_derive = Vector2(fposmod(_derive.x, TOUR), fposmod(_derive.y, TOUR))
		_pente = lerpf(_pente, cote * (0.05 + 1.1 * vent * (0.3 + 0.7 * absf(vd.x)) * (0.75 + 0.5 * rafale)), clampf(delta * 1.5, 0.0, 1.0))
	if tombe:
		var m := _m_chute
		m.set_shader_parameter("temps", _t)
		m.set_shader_parameter("pluie", pluie)
		m.set_shader_parameter("neige", neige * 0.7)
		m.set_shader_parameter("pente", _pente)
		m.set_shader_parameter("souffle", vd.x * vent * 170.0 * (0.7 + 0.6 * rafale))
		m.set_shader_parameter("eclat", minf(1.0, eclat * 1.5))
		# (la nuit, la pluie est un trait de lune, pas un trait de craie)
		m.set_shader_parameter("c_pluie", P.NUIT_BLEUE.lerp(P.LUNE, 0.75).lerp(P.PAPIER.lerp(P.LUNE, 0.4), jour))
		m.set_shader_parameter("c_neige", P.LUNE.lerp(P.PAPIER, 0.45).lerp(P.PAPIER.lightened(0.5), jour))
		m.set_shader_parameter("c_ombre", P.NUIT_BLEUE.lerp(P.LUNE, 0.5).lerp(P.LUNE.lerp(P.PAPIER, 0.25), jour))
	if tremble:
		_m_tremble.set_shader_parameter("temps", _t)
		_m_tremble.set_shader_parameter("force", chaleur * jour)
	if not voile:
		return
	var v := _m_voile
	var cam: Camera2D = _jeu.camera
	if cam != null and is_instance_valid(cam):
		v.set_shader_parameter("centre", cam.get_screen_center_position())
		v.set_shader_parameter("vue", s / cam.zoom)
	if _jeu.joueur != null:
		v.set_shader_parameter("joueur", _jeu.joueur.position)
	v.set_shader_parameter("derive", _derive)
	v.set_shader_parameter("chute", Vector2(_pente, 1.0))
	v.set_shader_parameter("temps", _t)
	v.set_shader_parameter("jour", jour)
	v.set_shader_parameter("sombre", sombre)
	v.set_shader_parameter("brouillard", brouillard)
	v.set_shader_parameter("pluie", pluie)
	v.set_shader_parameter("neige", neige)
	v.set_shader_parameter("chaleur", chaleur)
	v.set_shader_parameter("eclat", eclat)
	if brouillard > 0.01:
		var l: Array = Sol.lumieres(_jeu, 1.0 - jour)
		v.set_shader_parameter("feu0", l[0])
		v.set_shader_parameter("feu1", l[1])
		v.set_shader_parameter("torche", l[2])


# la foudre est tombée : tout l'écran s'éclaire ; moins si elle est tombée hors de la vue, de moins en moins avec la distance
func _sur_foudre(p: Vector2, _sur) -> void:
	var force := 0.3
	var cam: Camera2D = _jeu.camera
	if cam != null and is_instance_valid(cam) and is_inside_tree():
		var demi: Vector2 = get_viewport_rect().size / cam.zoom * 0.5
		var d: Vector2 = (p - cam.get_screen_center_position()).abs() - demi
		var dehors := maxf(d.x, d.y)
		force = 1.0 if dehors < 60.0 else lerpf(0.5, 0.2, clampf(dehors / 900.0, 0.0, 1.0))
	if _eclair >= 0.0 and force < _eclair_force * 0.5:
		return
	_eclair = 0.0
	_eclair_force = force


# l'éclat, à cette image : deux coups (le second retombe lentement)
func _eclat(delta: float) -> float:
	if _eclair < 0.0:
		return 0.0
	_eclair += delta
	var t := _eclair
	if t > 0.9:
		_eclair = -1.0
		return 0.0
	var e := 1.0 if t < 0.06 else (0.28 if t < 0.1 else 0.8 * exp(-(t - 0.1) * 6.0))
	return 0.38 * _eclair_force * e
