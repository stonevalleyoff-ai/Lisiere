extends Node2D
# Lisière — les flammes de l'incendie (scripts/incendie_flammes.gd)
# Ce qui brûle (scripts/incendie.gd, ses foyers), tel qu'on le voit. principal.gd le pose à chaque nouvelle partie ; il part
# avec la scène. Jusqu'à vingt-quatre objets brûlent à la fois : rien ici n'est fait « par objet ».
#  - Les flammes sont dans le dessin de l'objet lui-même (scripts/objet.gd, shaders/incendie_objet.gdshader) : à sa taille, et
#    à sa place parmi les autres (un arbre en feu reste derrière ce qui est devant lui). Ici, on donne à leur matière, chaque
#    image, la liste des foyers (où en est chaque feu, sa force), le vent, l'heure.
#  - Au sol, sous tout ce qui se tient debout : la terre brûlée et ses braises, là où l'on prend feu, et la lueur de chaque
#    foyer (un MultiMesh : un appel de dessin ; shaders/incendie_sol.gdshader).
#  - En l'air : la fumée, qui monte et file sous le vent ; les braises, qui volent jusqu'où le feu peut sauter (plus loin sous
#    le vent : c'est par elles qu'on le comprend) ; les étincelles ; et les bouffées d'un instant (un arbre qui s'effondre, la
#    vapeur d'un feu que la pluie éteint, les éclats de boue et les éclaboussures de la veilleuse : bref()). Un MultiMesh, un
#    appel de dessin, et rien à calculer par image : chaque particule se place d'après l'heure (shaders/incendie_air.gdshader).
#  - La nuit : deux ou trois lumières, pas une par foyer ; une par groupe de foyers, les groupes les plus proches d'abord.
# Quand rien ne brûle, tout est caché et rien ne tourne. Ce qui a brûlé jusqu'au bout rougeoie encore un moment (objet.tiedeur()),
# puis refroidit : une souche noire, de la cendre (c'est l'objet qui les dessine).

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")
const Feu := preload("res://scripts/feu.gd")
const Objet := preload("res://scripts/objet.gd")
const AIR := preload("res://shaders/incendie_air.gdshader")
const SOL := preload("res://shaders/incendie_sol.gdshader")
const PLACES := 32              # les feux suivis à la fois : ceux qui brûlent (24 au plus), ceux qui refroidissent
const PAS := 16                 # les nombres d'une instance : sa transformation (8), sa couleur (4), ses données (4)
# les sortes de particules (shaders/incendie_air.gdshader)
const FUMEE := 0.0
const BRAISE := 1.0
const ETINCELLE := 2.0
const VAPEUR := 3.0
const GERBE := 4.0
const BOUE := 5.0
const EAU := 6.0
# ce qu'un feu met dans l'air, d'après ce qui brûle : [la hauteur d'où part la fumée (0 : celle de l'objet), la taille d'une
# bouffée, les fumées, les braises, les étincelles]
const AIRS := {"arbre": [0.0, 38.0, 6, 4, 3], "sapin": [0.0, 34.0, 6, 4, 3], "buisson": [26.0, 24.0, 3, 3, 2], "touffe": [20.0, 16.0, 2, 2, 1], "souche": [20.0, 17.0, 2, 2, 1]}

var jeu
var _mobile := false
var _t := 0.0                   # l'horloge des flammes (elle repart de zéro quand plus rien ne brûle)
var _places: Array = []         # une fiche par feu suivi (ou null)
var _par_objet := {}            # l'objet (son identifiant) → sa place
var _par_place := 12            # les particules d'un feu : fumées, braises, étincelles, et deux fumerolles pour après
var _brefs := 96                # les particules d'un instant
var _bref_i := 0
var _bref_fin := 0.0
var _air: MultiMeshInstance2D
var _air_mat: ShaderMaterial
var _air_nombres := PackedFloat32Array()
var _air_change := false
var _sol: MultiMeshInstance2D
var _sol_mat: ShaderMaterial
var _sol_nombres := PackedFloat32Array()
var _lumieres: Array = []       # [la lumière, où elle va, son rayon, sa force]
var _foyers := PackedFloat32Array()
var _vent := Vector2.ZERO
var _actif := false
var _hasard := RandomNumberGenerator.new()
var _bruit := FastNoiseLite.new()


# la scène du lieu (le sol, puis le monde et ce qui s'y tient debout, trié par y), au début d'une partie
func poser(scene: Node2D, monde: Node2D) -> void:
	_mobile = jeu != null and jeu.qualite == "mobile"
	_par_place = 8 if _mobile else 16
	_brefs = 48 if _mobile else 96
	_hasard.randomize()
	_bruit.frequency = 1.0
	_places.resize(PLACES)
	_foyers.resize(PLACES * 4)
	Objet.matieres()
	Objet.incendie.set_shader_parameter("simple", _mobile)
	Objet.incendie.set_shader_parameter("combien", 0)
	# au sol, sous le monde (et par-dessus ce que le temps a fait du sol) : la terre brûlée, les braises, la lueur
	_sol_mat = ShaderMaterial.new()
	_sol_mat.shader = SOL
	_sol_mat.set_shader_parameter("bruit", T.bruit())
	Objet.incendie.set_shader_parameter("bruit", Objet.bruit_des_flammes())
	_sol_mat.set_shader_parameter("contact", R.INCENDIE_CONTACT)
	_sol_mat.set_shader_parameter("encre", P.ENCRE)
	_sol_nombres = _nombres(PLACES)
	_sol = _nuee(_sol_nombres, _sol_mat, 150.0)
	_sol.name = "IncendieSol"
	scene.add_child(_sol)
	scene.move_child(_sol, monde.get_index())
	# en l'air, par-dessus tout : la fumée, les braises
	_air_mat = ShaderMaterial.new()
	_air_mat.shader = AIR
	_air_mat.set_shader_parameter("bruit", T.bruit())
	_air_mat.set_shader_parameter("portee", R.INCENDIE_PORTEE)
	_air_mat.set_shader_parameter("c_fumee", P.CENDRE.lerp(P.ENCRE_DOUCE, 0.3))
	_air_mat.set_shader_parameter("c_vapeur", P.PAPIER)
	_air_mat.set_shader_parameter("c_eau", P.ECHO.lerp(P.PAPIER, 0.5))
	var boue: Color = P.ENCRE_DOUCE.lerp(P.TERRE, 0.45)
	if monde != null and monde.get("palette") != null:
		boue = monde.palette.get("boue", boue)
	_air_mat.set_shader_parameter("c_boue", boue)
	_air_nombres = _nombres(PLACES * _par_place + _brefs)
	_air = _nuee(_air_nombres, _air_mat, 420.0)
	_air.name = "IncendieAir"
	add_child(_air)
	for m in [_sol_mat, _air_mat]:
		m.set_shader_parameter("rouge", P.BRAISE_ROUGE)
		m.set_shader_parameter("braise", P.BRAISE)
		m.set_shader_parameter("coeur", P.BRAISE_COEUR)
	# les lumières : une par groupe de foyers
	for i in (2 if _mobile else 3):
		var l := PointLight2D.new()
		l.texture = Feu.texture_lumiere()
		l.color = P.BRAISE.lerp(P.BRAISE_COEUR, 0.3)
		l.energy = 0.0
		l.enabled = false
		add_child(l)
		_lumieres.append([l, Vector2.ZERO, 0.0, 0.0])
	if jeu != null and jeu.get("incendie") != null:
		jeu.incendie.fini.connect(_fini)
	if jeu != null and jeu.get("effets") != null:
		jeu.effets.flammes = self
	_cacher()


func _exit_tree() -> void:
	if jeu != null and jeu.get("incendie") != null and jeu.incendie.fini.is_connected(_fini):
		jeu.incendie.fini.disconnect(_fini)
	if jeu != null and jeu.get("effets") != null and jeu.effets.flammes == self:
		jeu.effets.flammes = null
	if Objet.incendie != null:
		Objet.incendie.set_shader_parameter("combien", 0)


# une nuée : n carrés dans un MultiMesh, que son shader place et dessine (portee : jusqu'où une particule s'éloigne de sa
# source, pour que le moteur ne la croie pas hors de l'écran)
func _nuee(nombres: PackedFloat32Array, matiere: ShaderMaterial, portee: float) -> MultiMeshInstance2D:
	var carre := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	carre.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	carre.custom_aabb = AABB(Vector3(-portee, -portee, 0.0), Vector3(portee * 2.0, portee * 2.0, 0.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = carre
	mm.instance_count = nombres.size() / PAS
	mm.buffer = nombres
	var m := MultiMeshInstance2D.new()
	m.multimesh = mm
	m.material = matiere
	m.texture = T.blanc()
	return m


# les nombres de n instances vides (sans écran, le moteur ne les garde pas : on les tient ici)
static func _nombres(n: int) -> PackedFloat32Array:
	var nombres := PackedFloat32Array()
	nombres.resize(n * PAS)
	nombres.fill(0.0)
	for i in n:
		nombres[i * PAS] = 1.0
		nombres[i * PAS + 5] = 1.0
	return nombres


func _cacher() -> void:
	_actif = false
	_t = 0.0
	_bref_fin = 0.0
	if _air != null:
		_air.visible = false
		_sol.visible = false
	for l in _lumieres:
		l[0].enabled = false
		l[3] = 0.0
	if Objet.incendie != null:
		Objet.incendie.set_shader_parameter("combien", 0)
	# (l'horloge repart de zéro : ce qui restait dans l'air ne doit pas rejouer)
	for i in PLACES:
		if _places[i] != null:
			_par_objet.erase(_places[i]["id"])
			_places[i] = null
	for i in _air_nombres.size() / PAS:
		_air_nombres[i * PAS + 13] = 0.0
	_air_change = true


func _process(delta: float) -> void:
	if jeu == null or _air == null or not jeu.en_partie or jeu.en_pause:
		return
	var foyers: Array = jeu.incendie.foyers if jeu.get("incendie") != null else []
	if not _actif:
		if foyers.is_empty():
			return
		_actif = true
		_vent = _vent_du_lieu()
	_t += delta
	# le vent du feu : celui des règles (climat.vent_dir, climat.vent), sans à-coup
	_vent = _vent.lerp(_vent_du_lieu(), clampf(delta * 1.5, 0.0, 1.0))
	_suivre(foyers)
	var vivants := _regler_les_foyers(delta)
	if vivants == 0 and _t > _bref_fin:
		_cacher()
		return
	var obscur: Color = jeu.obscurite.color if jeu.get("obscurite") != null and is_instance_valid(jeu.obscurite) else Color.WHITE
	var jour: float = jeu.lumiere_du_jour()
	var pluie: float = jeu.climat.pluie if jeu.get("climat") != null else 0.0
	var feu: ShaderMaterial = Objet.incendie
	feu.set_shader_parameter("foyers", _foyers)
	feu.set_shader_parameter("t", _t)
	feu.set_shader_parameter("vent", _vent)
	feu.set_shader_parameter("obscur", obscur)
	feu.set_shader_parameter("opacite", lerpf(0.72, 0.88, jour))
	var temps = Objet.vegetation.get_shader_parameter("temps") if Objet.vegetation != null else null
	if temps != null:
		feu.set_shader_parameter("temps", temps)
	_air_mat.set_shader_parameter("t", _t)
	_air_mat.set_shader_parameter("vent", _vent)
	_air_mat.set_shader_parameter("obscur", obscur)
	_air_mat.set_shader_parameter("pluie", pluie)
	_sol_mat.set_shader_parameter("t", _t)
	_sol_mat.set_shader_parameter("nuit", 1.0 - jour)
	_sol.visible = vivants > 0
	if vivants > 0:
		_sol.multimesh.buffer = _sol_nombres
	_air.visible = true
	if _air_change:
		_air_change = false
		_air.multimesh.buffer = _air_nombres
	_eclairer(delta, jour)


func _vent_du_lieu() -> Vector2:
	if jeu == null or jeu.get("climat") == null:
		return Vector2.ZERO
	var d: Vector2 = jeu.climat.vent_dir
	var f: float = jeu.climat.vent
	return d * f


# --- les feux suivis : ceux qui brûlent, ceux qui refroidissent ---

# ce qui vient de prendre feu reçoit une place ; ce qui ne brûle plus la garde le temps que sa fumée retombe et qu'il refroidisse
func _suivre(foyers: Array) -> void:
	for f in foyers:
		var o = f.objet
		if not is_instance_valid(o):
			continue
		var id: int = o.get_instance_id()
		if _par_objet.has(id):
			if float(_places[_par_objet[id]]["fin"]) >= 0.0 and o.brule > 0.0:
				# (il a repris feu avant d'avoir refroidi)
				_liberer(_par_objet[id])
			else:
				continue
		var i := _place_libre()
		if i < 0:
			continue
		var genre: String = o.genre
		var air: Array = AIRS.get(genre, AIRS["souche"])
		var fiche := {"o": o, "id": id, "pos": o.position, "genre": genre, "t0": floorf(_t * 128.0) / 128.0, "fin": -1.0, "brule": false,
			"haut": float(air[0]) if float(air[0]) > 0.0 else float(o.hauteur), "rayon": f.rayon(), "graine": _hasard.randf(), "force": 0.0}
		_places[i] = fiche
		_par_objet[id] = i
		_ecrire_air(i, fiche, air, o.brule)


func _place_libre() -> int:
	var vieux := -1
	for i in PLACES:
		if _places[i] == null:
			return i
		# (plus de place : la plus ancienne de celles qui ne brûlent plus cède la sienne)
		if _places[i]["fin"] >= 0.0 and (vieux < 0 or _places[i]["fin"] < _places[vieux]["fin"]):
			vieux = i
	if vieux >= 0:
		_liberer(vieux)
	return vieux


func _liberer(i: int) -> void:
	var fiche = _places[i]
	if fiche != null:
		_par_objet.erase(fiche["id"])
	_places[i] = null
	for k in _par_place:
		_air_nombres[(i * _par_place + k) * PAS + 13] = 0.0
	_air_change = true


# chaque image : où en est chaque feu, sa force ; ce que lit la matière des objets en feu, et la lueur au sol
func _regler_les_foyers(delta: float) -> int:
	var pluie: float = jeu.climat.pluie if jeu.get("climat") != null else 0.0
	var n := 0
	for i in PLACES:
		var fiche = _places[i]
		var k := n * 4
		var s := i * PAS
		if fiche == null:
			_sol_nombres[s + 8] = 0.0
			_sol_nombres[s + 11] = 0.0
			continue
		var o = fiche["o"]
		var valide: bool = is_instance_valid(o)
		var brule: bool = valide and o.brule > 0.0
		if not brule and fiche["fin"] < 0.0:
			_finir(i, fiche, valide and o.calcine)
		var avance := 0.0
		var force := 0.0
		var tiede := 0.0
		if brule:
			# (il prend en une seconde et demie ; il faiblit quand il ne lui reste que quelques secondes, et sous la pluie)
			var reste: float = o.brule
			var total: float = maxf(o._brule_total, 0.1)
			avance = o.feu_avance()
			force = clampf((_t - float(fiche["t0"])) / 1.5, 0.0, 1.0) * lerpf(0.22, 1.0, smoothstep(0.0, minf(5.0, total * 0.35), reste)) * (1.0 - 0.4 * pluie)
			fiche["force"] = force
		else:
			tiede = float(o.tiedeur()) if valide and bool(fiche["brule"]) else 0.0
			avance = 2.0 - tiede
			# (il ne brûle plus : sa place se libère quand sa dernière fumée est retombée et qu'il a refroidi)
			if tiede <= 0.0 and _t > float(fiche["fin"]) + 4.5:
				_liberer(i)
				_sol_nombres[s + 8] = 0.0
				_sol_nombres[s + 11] = 0.0
				continue
		var pos: Vector2 = fiche["pos"]
		_foyers[k] = pos.x
		_foyers[k + 1] = pos.y
		_foyers[k + 2] = avance
		_foyers[k + 3] = force
		n += 1
		_sol_nombres[s + 3] = pos.x
		_sol_nombres[s + 7] = pos.y + 1.0
		_sol_nombres[s + 8] = force
		_sol_nombres[s + 9] = float(fiche["rayon"]) * 0.62 / 256.0
		_sol_nombres[s + 10] = fiche["graine"]
		_sol_nombres[s + 11] = tiede
	Objet.incendie.set_shader_parameter("combien", n)
	return n


# un feu vient de finir (brûlé jusqu'au bout, ou éteint) : il ne fait plus naître de fumée ; calciné, il fume encore un peu
func _finir(i: int, fiche: Dictionary, calcine: bool) -> void:
	fiche["fin"] = _t
	fiche["brule"] = calcine
	fiche["force"] = 0.0
	var dure := _t - float(fiche["t0"])
	for k in _par_place - 2:
		_air_nombres[(i * _par_place + k) * PAS + 10] = dure
	if calcine:
		var pos: Vector2 = fiche["pos"]
		for k in 2:
			_instance((i + 1) * _par_place - 2 + k, pos + Vector2(0.0, -10.0), _t, Objet.TIEDE * 0.7, 11.0, _hasard.randf(), snappedf(2.6 + 0.5 * k, 1.0 / 64.0), FUMEE, 0.5)
	_air_change = true


# les particules d'un feu qui prend : sa fumée, ses braises, ses étincelles (reste : les secondes qu'il doit encore brûler)
func _ecrire_air(i: int, fiche: Dictionary, air: Array, reste: float) -> void:
	var pos: Vector2 = fiche["pos"]
	var haut: float = fiche["haut"]
	var t0: float = fiche["t0"]
	var q := 0.5 if _mobile else 1.0
	var fumees := maxi(1, int(ceil(int(air[2]) * q)))
	var braises := maxi(1, int(ceil(int(air[3]) * q)))
	var etincelles := int(int(air[4]) * q)
	var k := i * _par_place
	var fin := k + _par_place - 2
	for j in fumees:
		if k < fin:
			_instance(k, pos + Vector2(0.0, -haut * 0.86), t0, reste, air[1], (j + _hasard.randf()) / fumees, snappedf(_hasard.randf_range(3.0, 3.9), 1.0 / 64.0), FUMEE, 1.0)
			k += 1
	for j in braises:
		if k < fin:
			# (la braise part du haut des flammes, et tombe autour du pied : sa taille dit de quelle hauteur)
			_instance(k, pos, t0, reste, haut * 0.9, (j + _hasard.randf()) / braises, snappedf(_hasard.randf_range(1.5, 2.3), 1.0 / 64.0), BRAISE, 1.0)
			k += 1
	for j in etincelles:
		if k < fin:
			_instance(k, pos + Vector2(0.0, -haut * 0.7), t0, reste, float(air[1]) * 0.9, (j + _hasard.randf()) / etincelles, snappedf(_hasard.randf_range(1.0, 1.6), 1.0 / 64.0), ETINCELLE, 1.0)
			k += 1
	while k < i * _par_place + _par_place:
		_air_nombres[k * PAS + 13] = 0.0
		k += 1
	_air_change = true


# une instance de la nuée : où elle naît, depuis quand et pour combien de temps, sa taille ; sa phase, sa vie, sa sorte, sa force
func _instance(n: int, ou: Vector2, t0: float, dure: float, taille: float, phase: float, vie: float, sorte: float, force: float) -> void:
	var s := n * PAS
	_air_nombres[s] = 1.0
	_air_nombres[s + 3] = ou.x
	_air_nombres[s + 5] = 1.0
	_air_nombres[s + 7] = ou.y
	_air_nombres[s + 8] = floorf(t0 / 8.0)
	_air_nombres[s + 9] = t0 - floorf(t0 / 8.0) * 8.0
	_air_nombres[s + 10] = dure
	_air_nombres[s + 11] = taille
	_air_nombres[s + 12] = phase
	_air_nombres[s + 13] = vie
	_air_nombres[s + 14] = sorte + 0.9 * _hasard.randf()
	_air_nombres[s + 15] = force


# --- ce qui ne dure qu'un instant ---

# n particules d'un coup en p (dans le lieu) : une bouffée de VAPEUR, une GERBE d'étincelles, des éclats de BOUE, d'EAU, une
# bouffée de FUMEE. taille : celle d'une bouffée, ou l'élan des éclats ; vie : en secondes.
func bref(sorte: float, p: Vector2, n: int, taille: float, vie: float, force: float = 1.0) -> void:
	if _air == null or jeu == null:
		return
	if not _actif:
		_actif = true
		_vent = _vent_du_lieu()
	vie = maxf(snappedf(vie, 1.0 / 64.0), 0.25)
	var t0 := floorf(_t * 128.0) / 128.0
	if _mobile:
		n = maxi(1, int(ceil(n * 0.6)))
	for j in mini(n, _brefs):
		# (chacune naît à son instant, dans le dixième de seconde : sa phase le dit)
		var retard := _hasard.randf() * 0.1
		_instance(PLACES * _par_place + _bref_i, p, t0, 0.14, taille, fposmod(-(t0 + retard) / vie, 1.0), vie, sorte, force)
		_bref_i = (_bref_i + 1) % _brefs
	_bref_fin = maxf(_bref_fin, _t + vie + 0.3)
	_air_change = true


# l'incendie dit qu'un objet ne brûle plus (brule : jusqu'au bout ; sinon la pluie l'a éteint)
func _fini(o, brule: bool) -> void:
	if not is_instance_valid(o) or not _par_objet.has(o.get_instance_id()):
		return
	var fiche: Dictionary = _places[_par_objet[o.get_instance_id()]]
	var pos: Vector2 = fiche["pos"]
	var haut: float = fiche["haut"]
	var grand: bool = fiche["genre"] == "arbre" or fiche["genre"] == "sapin"
	if brule:
		# (un arbre s'effondre : une gerbe d'étincelles, une bouffée noire)
		bref(GERBE, pos + Vector2(0.0, -haut * 0.45), 14 if grand else 5, 34.0 if grand else 20.0, 1.2)
		bref(FUMEE, pos + Vector2(0.0, -haut * 0.5), 5 if grand else 2, 40.0 if grand else 22.0, 2.6, 0.9)
	else:
		# (la pluie l'a éteint : il siffle, une bouffée de vapeur)
		bref(VAPEUR, pos + Vector2(0.0, -haut * 0.6), 6 if grand else 3, 34.0 if grand else 20.0, 2.0)


# --- la lumière : une par groupe de foyers, les plus proches de la veilleuse d'abord ---

func _eclairer(delta: float, jour: float) -> void:
	var centre: Vector2 = jeu.joueur.position if jeu.get("joueur") != null and is_instance_valid(jeu.joueur) else Vector2.ZERO
	var libres: Array = []
	for fiche in _places:
		if fiche != null and float(fiche["force"]) > 0.0:
			libres.append(fiche)
	libres.sort_custom(func(a, b): return centre.distance_squared_to(a["pos"]) < centre.distance_squared_to(b["pos"]))
	var groupes: Array = []
	while not libres.is_empty() and groupes.size() < _lumieres.size():
		var tete: Dictionary = libres[0]
		var somme := Vector2.ZERO
		var poids := 0.0
		var membres: Array = []
		var reste: Array = []
		for f in libres:
			if (f["pos"] as Vector2).distance_to(tete["pos"]) < 130.0:
				membres.append(f)
				somme += (f["pos"] as Vector2) * float(f["force"])
				poids += float(f["force"])
			else:
				reste.append(f)
		libres = reste
		var milieu: Vector2 = somme / maxf(poids, 0.001)
		var rayon := 0.0
		var force := 0.0
		for f in membres:
			rayon = maxf(rayon, milieu.distance_to(f["pos"]) + float(f["rayon"]))
			force = maxf(force, float(f["force"]))
		groupes.append([milieu, minf(rayon, 300.0), force])
	# chaque groupe prend la lumière la plus proche de lui (une lumière éteinte va où l'on veut)
	var prises := {}
	for g in groupes:
		var mieux := -1
		var d0 := INF
		for i in _lumieres.size():
			if prises.has(i):
				continue
			var l: Array = _lumieres[i]
			var d: float = (l[1] as Vector2).distance_to(g[0]) if float(l[3]) > 0.02 else 100000.0 + i
			if d < d0:
				d0 = d
				mieux = i
		if mieux < 0:
			break
		prises[mieux] = g
	for i in _lumieres.size():
		var l: Array = _lumieres[i]
		var lum: PointLight2D = l[0]
		if prises.has(i):
			var g: Array = prises[i]
			if float(l[3]) <= 0.02:
				l[1] = g[0]
				l[2] = g[1]
			else:
				l[1] = (l[1] as Vector2).lerp(g[0], clampf(delta * 4.0, 0.0, 1.0))
				l[2] = lerpf(l[2], g[1], clampf(delta * 3.0, 0.0, 1.0))
			l[3] = lerpf(l[3], g[2], clampf(delta * 3.0, 0.0, 1.0))
		else:
			l[3] = maxf(0.0, float(l[3]) - delta * 1.2)
		var vif: float = l[3]
		lum.enabled = vif > 0.01
		if lum.enabled:
			# (elle vacille, comme un feu de camp ; en plein jour, elle éclaire à peine)
			var n := _bruit.get_noise_1d(_t * 8.0 + i * 31.0)
			lum.position = (l[1] as Vector2) + Vector2(0.0, -14.0)
			lum.texture_scale = float(l[2]) / 128.0 * (1.0 + 0.012 * n)
			lum.energy = 1.3 * vif * (1.0 + 0.1 * n) * lerpf(1.0, 0.3, jour)
