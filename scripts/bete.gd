extends Node2D
# Lisière — une bête (scripts/bete.gd)
# Une lignée vraie du monde d'Orvane, dessinée par Lisière d'après son plan de corps, à la taille que lui donne sa masse.
# Sa vitesse, son flair, son audace viennent de son plan (vitesse_rel, perception, temperament). Quatre conduites :
#  - proie : elle broute, s'éloigne, fuit quand on approche (plus tôt si l'on court vers elle) ;
#  - rodeur : un chasseur qui vit le jour ; il laisse passer, mais se retourne si l'on s'approche trop ou si on le frappe ;
#  - chasseur : la nuit, il vient vers la veilleuse ; il n'entre pas dans la lumière d'un feu, tourne à sa lisière, et garde
#    ses distances avec une torche (sauf les plus audacieux) ; dans le noir, il mord. À l'aube, il repart ;
#  - echo : une bête qu'on a tuée, revenue la nuit quand la peur est haute ; pâle, lente, elle ne mord pas : elle traverse.
# Et ce que sa population a appris des joueurs (la mémoire d'Orvane, docs/12 : _apprendre) : craintive, elle fuit de plus loin et
# guette ; habituée, elle se laisse approcher ; traqueuse, elle suit la veilleuse, revient après un coup, passe la torche (en
# s'annonçant) ; selon qu'elle craint le feu ou s'y est faite, elle s'en tient plus ou moins loin. Sans mémoire, rien ne change.
# Elle dit aussi au jeu ce qu'Orvane en retiendra : un feu ou une torche qui l'arrêtent, un assaut, une blessure dont elle réchappe.
# Elle bouge d'après ce que sa planche rend (scripts/bestiaire_planche.gd ; à défaut scripts/squelette.gd) :
#  - ses pieds tiennent au sol : un pied posé ne bouge plus dans le lieu, c'est le corps qui passe au-dessus ; levé, il va se
#    poser en avant. La cadence vient de la vitesse et de la longueur des pattes ; trop vite pour elles, elle vole entre deux
#    appuis. À l'arrêt, chaque pied revient à sa place, d'un petit pas ;
#  - son corps est porté par ses pattes : il descend là où une patte ne peut plus atteindre son pied (le dos roule au pas), il
#    rebondit à la course, s'étire dans le bond ; une bête lourde va le pas, lente et basse, une légère trottine ;
#  - sa queue vit autour de sa racine (un ressort : elle traîne au départ, dépasse à l'arrêt, se lève dans la fuite, fouette ou
#    frémit au repos selon son caractère) ; sa tête broute, guette, hume ; elle respire, elle cligne de l'œil ;
#  - frappée, elle sursaute ; tuée, elle tombe sur le flanc (sur le dos, à six pattes), l'œil clos, et son encre s'efface ;
#    sans pattes, tout son corps ondule ; revenue en écho, c'est une fumée d'encre pâle.

const R := preload("res://scripts/regles.gd")
const Donnees := preload("res://scripts/donnees.gd")
const P := preload("res://scripts/palette.gd")
const Squelette := preload("res://scripts/squelette.gd")
const Bestiaire := preload("res://scripts/bestiaire.gd")
const SHADER_ENCRE := preload("res://shaders/bete_encre.gdshader")
const CHUTE := 0.55              # elle tombe (secondes)
const GISANT := 0.7              # elle reste couchée
const EFFACEMENT := 1.6          # son encre s'efface
const BARRE := 2.6               # la barre de vie reste visible, après un coup
# ce qui rend juste une conduite apprise : elle s'annonce (docs/7)
const REARME := 6.0              # secondes sans mordre, après lesquelles une morsure ouvre un nouvel assaut
const GUET := 0.6                # un rôdeur qui traque s'arrête et regarde, avant de charger
const PRESAGE := 1.0             # un chasseur qui a appris à passer la torche s'aplatit et gronde, avant

# (une couche dessinée par la bête : les pattes de derrière, celles de devant, la barre, la traîne d'un écho)
class Calque extends Node2D:
	var peindre: Callable

	func _draw() -> void:
		if peindre.is_valid():
			peindre.call(self)


var lignee: Dictionary = {}
var id := ""
var nom := ""
var role := "proie"
var masse := 1.0
var pv := 10.0
var pv_max := 10.0
var vitesse := 80.0
var flair := 160.0
var audace := 0.3
var largeur := 30.0
var vue := false
var regard := 1.0
var etat := "repos"
var maison := Vector2.ZERO
var oeil := Vector3(150.0, 40.0, 2.0)
var jeu
var sprite: Sprite2D
var robe := Color(0.4, 0.33, 0.25)
var _cible := Vector2.ZERO
var _t := 0.0
var _duree := 2.0
var _morsure := 0.0
var _apparition := 0.0
var _fuite_de := Vector2.ZERO
var _retenu := false
var _sens := 1.0
var _du_ciel := false            # (le coup en cours vient de la foudre ou de l'incendie)
# ce que sa population a appris des joueurs (la mémoire d'Orvane : donnees.gd la pose dans l'entrée de faune, _apprendre la lit).
# Tout à zéro, elle se conduit comme avant.
var crainte := 0.0               # (mefiance) elle fuit de plus loin, guette, lâche prise plus tôt
var confiance := 0.0             # (habituation) elle se laisse approcher
var traque := 0.0                # la veilleuse est une proie : elle la suit, revient, passe la torche
var attrait := 0.0               # la veilleuse et son camp l'attirent : elle vient voir
var peur_feu := 0.0              # (neophobie) de -1, faite au feu, à 1, elle le craint
var attitude := ""
var touchee := false             # frappée par la veilleuse, et en vie : une « blessure », si elle s'en va ainsi
var _effarouchee := -1           # le jour du jeu où un feu, une torche l'ont arrêtée (c'est compté une fois par nuit)
var _assaut := 0.0               # le temps pendant lequel une morsure est encore du même assaut
var _presage := 0.0              # ce qu'elle a déjà annoncé, avant de passer la torche
var _suit := false               # elle suit la veilleuse de loin

# l'animation
var _sq: Dictionary = {}
var _pivot: Node2D
var _loin: Calque
var _pres: Calque
var _dessus: Sprite2D
var _queue: Polygon2D
var _tete: Sprite2D
var _haut: Calque
var _traine: Calque
var _mat: ShaderMaterial
var _fin := true                 # qualité haute (un ordinateur)
var _premiere := true
var _avant := Vector2.ZERO
var _vit := Vector2.ZERO
var _accel := 0.0
var _avance := 0.0               # ce que le sol a reculé sous elle, cette image (vu de profil)
var _proj := 1.0                 # la part de sa marche qui se voit de profil (elle piétine quand elle va vers nous)
var _poids := 0.3                # de 0 (200 g) à 1 (300 kg) : ce qui pèse est lent, bas, et bouge peu
var _phase := 0.0
var _foulee_eff := 1.0
var _face := 1.0
var _marche := 0.0
var _affut := 0.0
var _course := 0.0
var _bond := 0.0
var _foulee := 0.9
var _appui := 0.62
var _levee := 0.3
var _bas := 0.0
var _s_max := 10.0               # la plus longue foulée que ses pattes couvrent sans quitter le sol
var _f_max := 4.2                # sa cadence la plus vive (pas par seconde)
var _f_pose := 2.0               # la cadence des petits pas qui la remettent d'aplomb
var _f_course := 2.0             # la cadence de sa course : celle de ses pattes (courtes, elles battent vite)
var _etire := 0.03               # ce qu'une patte tendue peut s'allonger (le pied qui se déroule)
var _a_poser := false
var _pietine := 0.0
var _vol_y := 0.0                # le rebond de la course (pixels ; négatif : en l'air)
var _air := 0.0
var _air_px := 0.0
var _porte := 0.0
var _porte_a := 0.0
var _hors := true
var _tangage := 0.0
var _souffle := 0.0
var _essouffle := 0.0
var _anim := 0.0
var _recul := Vector2.ZERO
var _ressort := 0.0
var _ressort_v := 0.0
var _derobe := 0.0
var _eclat := 0.0
var _depuis_coup := 99.0
var _geste := ""
var _geste_t := 1.0
var _geste_age := 0.0
var _broute_rot := 0.3
var _broute_penche := 0.05
var _tete_rot := 0.0
var _tete_d := Vector2.ZERO
var _penche := 0.0
var _leve := 0.0                 # de combien le corps est levé (un bond, un écho qui flotte), pour l'ombre
var _onde_phase := 0.0
var _mort := -1.0
var _cote_chute := 1.0
var _impact := false
var _dissipe := -1.0
var _t_corps := Transform2D.IDENTITY
var _t_tete := Transform2D.IDENTITY
var _pieds: Array = []
var _rot_pieds := PackedFloat32Array()
var _dec_pas := PackedFloat32Array()
var _dec_affut := PackedFloat32Array()
var _dec_bond := PackedFloat32Array()
var _sillage := PackedVector2Array()
var _sillage_t := 0.0
var _miettes: Array = []
var _params := {}
var _a_l_ecran := true
# (lu à chaque image : sorti du squelette une fois pour toutes)
var _H := 10.0
var _c := Vector2.ZERO
var _ventre := 0.0
var _n_cote := 0
var _sans := true
var _p_pts: Array[PackedVector2Array] = []
var _p_rel: Array[PackedVector2Array] = []
var _p_l1 := PackedFloat32Array()
var _p_l2 := PackedFloat32Array()
var _p_plie := PackedFloat32Array()
var _p_ang := PackedFloat32Array()
var _p_portee := PackedFloat32Array()
var _p_devant: Array[bool] = []
var _p_loin: Array[bool] = []
var _p_ang0 := PackedFloat32Array()      # l'angle de la cuisse, au repos
var _p_lim := PackedFloat32Array()       # de combien elle peut s'en écarter
var _p_atteint := PackedFloat32Array()   # jusqu'où la patte va, tendue
var _p_jeu := PackedFloat32Array()       # de combien son bas peut s'allonger ou se tasser, en plus
# (chaque pied, dans son pas)
var _p_dec := PackedFloat32Array()       # sa phase dans le cycle, cette image
var _p_hate := PackedFloat32Array()      # ce dont il a devancé son tour (un pied resté trop loin derrière se lève sans attendre)
var _p_off := PackedFloat32Array()       # où il est, d'avant en arrière, depuis sa place au repos
var _p_dep := PackedFloat32Array()       # d'où il s'est levé
var _p_lev := PackedFloat32Array()       # de combien il est levé (pixels)
var _p_pose := PackedByteArray()         # 1 : posé
var _p_etire := PackedFloat32Array()     # l'allongement du bas de la patte (pour le dessin)
# le galop (une proie qui fuit bondit haut ; un chasseur lancé galope bas et long)
var _g_foulee := 1.0
var _g_appui := 0.27
var _g_arc := 0.3
var _g_tangage := 0.1
var _g_ref := 0.05
# la queue
var _q_pivot := Vector2.ZERO
var _q_axe := Vector2.LEFT
var _q_long := 10.0
var _q_souple := 1.0
var _q_repos := PackedVector2Array()
var _q_t := PackedFloat32Array()
var _q_pts := PackedVector2Array()
var _q_a := 0.0
var _q_av := 0.0
var _q_b := 0.0
var _q_bv := 0.0
var _q_avant := Vector2.ZERO
var _q_vit := Vector2.ZERO
var _q_neuve := true
var _q_geste := ""
var _q_geste_t := 0.0
var _q_geste_d := 0.5
var _q_geste_s := 1.0
var _q_attente := 2.0
# l'œil
var _a_oeil := false
var _oeil_local := Vector2.ZERO
var _oeil_rayon := 1.5
var _cligne := -1.0              # depuis quand elle cligne (-1 : l'œil ouvert)
var _cligne_t := 2.0             # le prochain clignement, dans…
var _cligne_d := 0.2
var _haut_sale := false
static var _ombre_tex: ImageTexture
static var _vue_image := -1
static var _vue := Rect2()
static var _cercle := PackedVector2Array()


func preparer(e: Dictionary, r: String, j, biome: String) -> void:
	jeu = j
	lignee = e["lignee"]
	id = str(e["id"])
	nom = Donnees.nom_court(lignee)
	role = r
	masse = float(e["masse"])
	var plan: Dictionary = lignee.get("plan", {})
	# (sa taille à l'écran : celle du bestiaire de Lisière, qui se lit en jouant)
	largeur = Bestiaire.largeur_de(masse, Bestiaire.est_chasseur(plan))
	pv_max = 8.0 + 22.0 * log(masse + 1.0) / log(10.0)
	pv = pv_max
	vitesse = 45.0 + 15.0 * float(plan.get("vitesse_rel", 4.0))
	flair = 90.0 + 230.0 * float(plan.get("perception", 0.5))
	audace = float(plan.get("temperament", 0.3))
	if role != "echo":
		_apprendre(e.get("memoire", {}))
	_poids = clampf(log(maxf(masse, 0.2) / 0.2) / log(1500.0), 0.0, 1.0)
	_sens = 1.0 if randf() < 0.5 else -1.0
	var k = plan.get("corps", {}).get("couleurs", {}).get("robe", [])
	if typeof(k) == TYPE_ARRAY and k.size() >= 3:
		robe = Color8(int(k[0]), int(k[1]), int(k[2]))
	_fin = j == null or str(j.qualite) != "mobile"
	var y: Array = Orvane.yeux(id, biome)
	if not y.is_empty():
		oeil = y[0]
		_a_oeil = true
	# la bête dessinée par Lisière d'après son plan de corps (scripts/bestiaire.gd) ; à défaut (une forme qu'on ne sait pas encore
	# dessiner), sa planche d'Orvane (le squelette tiré de la planche : le corps, la tête à part, chaque patte)
	_sq = Bestiaire.lire(lignee, largeur)
	if _sq.is_empty():
		_sq = Squelette.lire(id + "|" + biome, Orvane._silhouette(id, biome), largeur)
	else:
		robe = Bestiaire.tons(plan)["robe"]
		_a_oeil = not _sq["yeux"].is_empty()
		if _a_oeil:
			# (son œil, là où Lisière l'a dessiné, dans le cadre que lit point_oeil)
			var y0: Vector3 = _sq["yeux"][0]
			var k170 := largeur / 170.0
			oeil = Vector3(85.0 + y0.x / k170, 86.0 + y0.y / k170, y0.z / k170 / 1.25)
	_oeil_local = Vector2((oeil.x - 85.0), (oeil.y - 86.0)) * largeur / 170.0
	_oeil_rayon = maxf(1.2, oeil.z * largeur / 170.0 * 1.25)
	if not _sq.is_empty():
		_monter()
	regard = 1.0 if randf() < 0.5 else -1.0
	_face = regard
	_souffle = randf() * TAU
	_phase = randf()
	_cligne_t = randf_range(0.5, 5.0)
	_q_attente = randf_range(1.0, 5.0)
	if role == "echo":
		modulate = Color(1.0, 1.0, 1.0, 0.0)


# ce que sa population a appris des joueurs (Orvane.dispositions : mefiance, habituation, traque, attrait, neophobie). La première
# nuit, ce qui la rend dangereuse ne compte que pour moitié : qui s'éveille dans un lieu que d'autres ont rendu hostile a une
# nuit pour le comprendre.
func _apprendre(m) -> void:
	if typeof(m) != TYPE_DICTIONARY or m.is_empty():
		return
	crainte = clampf(float(m.get("mefiance", 0.0)), 0.0, 1.0)
	confiance = clampf(float(m.get("habituation", 0.0)), 0.0, 1.0)
	traque = clampf(float(m.get("traque", 0.0)), 0.0, 1.0)
	# (une bête qui craint les joueurs ne vient pas les voir)
	attrait = clampf(float(m.get("attrait", 0.0)), 0.0, 1.0) * (1.0 - crainte)
	peur_feu = clampf((float(m.get("neophobie", 0.5)) - 0.5) * 2.0, -1.0, 1.0)
	attitude = str(m.get("attitude", ""))
	if jeu != null and "nuits" in jeu and int(jeu.nuits) == 0:
		traque *= 0.5
		peur_feu = maxf(peur_feu, peur_feu * 0.5)
	# (son audace : celle de son plan, que la traque enhardit et que la crainte rabat)
	if traque > 0.0 or crainte > 0.0:
		audace = clampf(audace + 0.35 * traque - 0.35 * crainte, 0.0, maxf(audace, 0.95))


func _monter() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_ENCRE
	_mat.set_shader_parameter("hauteur", maxf(4.0, -float(_sq["haut"])))
	_mat.set_shader_parameter("fin", _fin)
	_mat.set_shader_parameter("couleur_encre", P.ENCRE)
	_mat.set_shader_parameter("couleur_eclat", P.PAPIER.lightened(0.55))
	_mat.set_shader_parameter("couleur_echo", P.ECHO)
	if role == "echo":
		_mat.set_shader_parameter("echo", 1.0)
		_traine = Calque.new()
		_traine.peindre = _peindre_traine
		_traine.material = _mat
		add_child(_traine)
	_pivot = Node2D.new()
	add_child(_pivot)
	var avec_pattes: bool = not _sq["sans_pattes"]
	_H = _sq["jambe"]
	_c = _sq["centre"]
	_ventre = _sq["ventre"]
	_sans = _sq["sans_pattes"]
	_n_cote = 0 if _sq["pattes"].is_empty() else int(_sq["pattes"][0]["n_cote"])
	# ce que le poids change : une patte lourde se tend davantage avant que le dos ne descende, la cadence plafonne plus bas
	_etire = lerpf(0.02, 0.05, _poids)
	_f_max = lerpf(5.2, 3.0, _poids) * (1.0 if _fin else 0.82)
	_f_pose = lerpf(2.6, 1.4, _poids)
	_f_course = minf(_f_max, 2.3 / sqrt(maxf(_H, 2.0) / 18.0))
	var hanches := 0.0
	for p in _sq["pattes"]:
		hanches += p["pts"][0].x
	if not _sq["pattes"].is_empty():
		hanches /= _sq["pattes"].size()
	var s_max := INF
	for p in _sq["pattes"]:
		var pts: PackedVector2Array = p["pts"]
		var n := pts.size() - 1
		var l1: float = p["l1"]
		var l2: float = p["l2"]
		var portee: float = p["portee"]
		_p_pts.append(pts)
		_p_rel.append(p["rel"])
		_p_l1.append(l1)
		_p_l2.append(l2)
		_p_plie.append(p["plie"])
		_p_ang.append(p["ang_bas"])
		_p_portee.append(portee)
		_p_loin.append(p["loin"])
		# (devant : sa hanche est en avant du milieu des hanches ; c'est ce qui fait rouler le dos)
		_p_devant.append(pts[0].x > hanches)
		_p_ang0.append((pts[1] - pts[0]).angle())
		# une patte dessinée presque repliée sur elle-même (un insecte) : sa cuisse ne s'écarte guère de son repos
		var mou := (portee - absf(l1 - l2)) / maxf(l1 + l2 - absf(l1 - l2), 0.01)
		_p_lim.append(lerpf(0.4, 1.2, smoothstep(0.05, 0.3, mou)))
		_p_jeu.append(0.25 * (1.0 - smoothstep(0.05, 0.3, mou)))
		var atteint := maxf(portee, 0.985 * (l1 + l2)) * (1.0 + _etire)
		_p_atteint.append(atteint)
		var hy := (pts[n].y - pts[0].y) * 0.75
		s_max = minf(s_max, 2.0 * (sqrt(maxf(atteint * atteint - hy * hy, 0.0)) - absf(pts[n].x - pts[0].x)))
		_p_dec.append(0.0)
		_p_hate.append(0.0)
		_p_off.append(0.0)
		_p_dep.append(0.0)
		_p_lev.append(0.0)
		_p_pose.append(1)
		_p_etire.append(1.0)
	_s_max = maxf(_H * 0.5, s_max) if s_max < INF else _H
	if avec_pattes:
		_loin = Calque.new()
		_loin.peindre = _peindre_loin
		_loin.material = _mat
		_pivot.add_child(_loin)
	# (la queue, quand Lisière l'a dessinée à part : derrière le corps ; une bande de peau qui plie autour de sa racine)
	if not _sq.get("queue", {}).is_empty():
		_monter_queue(_sq["queue"])
	sprite = _calque_sprite(_sq["corps"])
	if avec_pattes:
		_pres = Calque.new()
		_pres.peindre = _peindre_pres
		_pres.material = _mat
		_pivot.add_child(_pres)
	if not _sq["dessus"].is_empty():
		_dessus = _calque_sprite(_sq["dessus"])
	if not _sq["tete"].is_empty():
		_tete = _calque_sprite(_sq["tete"])
		# (jusqu'où la tête descend pour brouter : le museau vers le sol, sans tordre le cou)
		var rt: Rect2 = _sq["tete"]["rect"]
		var pv_t: Vector2 = _sq["tete"]["pivot"]
		var museau := Vector2(rt.end.x, rt.position.y + rt.size.y * 0.55) - pv_t
		var bas := clampf((-_H * 0.12 - pv_t.y) / maxf(museau.length(), 1.0), -1.0, 1.0)
		_broute_rot = clampf(asin(bas) - museau.angle(), 0.22, 0.6)
		# (ce qui manque encore, ce sont les épaules qui le donnent : elle s'incline)
		var reste := -(pv_t.y + museau.rotated(_broute_rot).y) - _H * 0.12
		_broute_penche = clampf(reste / maxf(pv_t.x + museau.x - _c.x, _H * 0.5), 0.03, 0.15)
	_haut = Calque.new()
	_haut.peindre = _peindre_haut
	add_child(_haut)
	if avec_pattes:
		_decalages()
		for p in _sq["pattes"]:
			_pieds.append(p["pts"])
			_rot_pieds.append(0.0)
	else:
		_mat.set_shader_parameter("onde_vagues", 1.2 if largeur < 60.0 else 1.6)


func _calque_sprite(c: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = c["tex"]
	s.centered = false
	s.offset = c["pos"] * 2.0
	s.scale = Vector2(0.5, 0.5)
	s.material = _mat
	_pivot.add_child(s)
	return s


# la queue : son dessin, coupé en tranches le long de son axe (de sa racine vers son bout) ; chaque tranche tourne autour de
# la racine, le bout plus que la base : elle plie, elle ne pivote pas comme un bâton. Une seule image, un seul appel de dessin.
func _monter_queue(c: Dictionary) -> void:
	var rect: Rect2 = c["rect"]
	_q_pivot = c.get("pivot", Vector2(rect.end.x, rect.get_center().y))
	var vers := rect.get_center() - _q_pivot
	_q_axe = vers.normalized() if vers.length() > 1.0 else Vector2.LEFT
	var orth := _q_axe.orthogonal()
	var t0 := 0.0
	var t1 := 1.0
	var s0 := 0.0
	var s1 := 0.0
	var r := rect.grow(1.5)
	for k in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var d: Vector2 = k - _q_pivot
		t0 = minf(t0, d.dot(_q_axe))
		t1 = maxf(t1, d.dot(_q_axe))
		s0 = minf(s0, d.dot(orth))
		s1 = maxf(s1, d.dot(orth))
	_q_long = maxf(4.0, t1)
	# (une queue longue et fine fouette ; un moignon ne fait que frémir)
	_q_souple = clampf((_q_long / maxf(2.0, s1 - s0) - 0.6) / 2.2, 0.2, 1.0)
	var n := 6 if _fin else 3
	var uv := PackedVector2Array()
	var pos: Vector2 = c["pos"]
	var tri: Array = []
	for k in n + 1:
		var t := lerpf(t0, t1, float(k) / n)
		for s in [s0, s1]:
			var v: Vector2 = _q_pivot + _q_axe * t + orth * s
			_q_repos.append(v)
			uv.append((v - pos) * 2.0)
		_q_t.append(clampf(t / _q_long, 0.0, 1.0))
		if k < n:
			var a := 2 * k
			tri.append(PackedInt32Array([a, a + 1, a + 3]))
			tri.append(PackedInt32Array([a, a + 3, a + 2]))
	_q_pts = _q_repos.duplicate()
	_queue = Polygon2D.new()
	_queue.texture = c["tex"]
	_queue.polygon = _q_repos
	_queue.uv = uv
	_queue.polygons = tri
	_queue.material = _mat
	_pivot.add_child(_queue)


# la phase de chaque patte dans le cycle (0 à 1), pour chaque allure. Une patte se pose quand le cycle passe par 1 − sa phase.
#  - le pas : à quatre pattes, l'arrière puis l'avant du même côté (au trot chez une bête légère : les diagonales ensemble ; au
#    pas chez une lourde : une patte après l'autre) ; à six, en trépied ; à deux, en alternance ;
#  - l'affût : une patte après l'autre ;
#  - le galop : les deux arrière, puis les deux avant (presque ensemble chez une proie qui bondit, étalés chez un chasseur).
func _decalages() -> void:
	var chasse := role != "proie"
	# (une bête légère trottine, une lourde marche)
	var suit := lerpf(0.42, 0.27, smoothstep(0.25, 0.75, _poids))
	if chasse:
		_g_foulee = lerpf(1.25, 1.12, _poids)
		_g_appui = 0.3
		_g_arc = lerpf(0.22, 0.1, _poids)
		_g_tangage = lerpf(0.09, 0.055, _poids)
	else:
		_g_foulee = lerpf(1.2, 1.0, _poids)
		_g_appui = 0.27
		_g_arc = lerpf(0.5, 0.2, _poids)
		_g_tangage = lerpf(0.14, 0.08, _poids)
	for p in _sq["pattes"]:
		var rg: int = p["rang"]
		var n: int = p["n_cote"]
		var loin: bool = p["loin"]
		var a := 0.0
		var b := 0.0
		var c := 0.0
		if n == 1:
			a = 0.5 if loin else 0.0
			b = a
			c = a
		elif n == 2:
			var cote := 0.5 if loin else 0.0
			if rg == 0:
				a = fposmod(1.0 - suit - cote, 1.0)
				b = fposmod(0.75 - cote, 1.0)
				c = 1.0 - ((0.4 if loin else 0.52) if chasse else (0.5 if loin else 0.56))
			else:
				a = fposmod(1.0 - cote, 1.0)
				b = a
				c = 0.0 if loin else 1.0 - (0.11 if chasse else 0.05)
		else:
			a = 0.5 * float((rg + (1 if loin else 0)) % 2)
			b = fposmod(float(rg) * 0.2 + (0.5 if loin else 0.0), 1.0)
			c = a
		_dec_pas.append(a)
		_dec_affut.append(b)
		_dec_bond.append(c)


# où brille son œil, dans le monde : il suit la tête, le pas, le souffle, le retournement
func point_oeil() -> Vector2:
	if _pivot == null:
		return position + Vector2(_oeil_local.x * regard, _oeil_local.y)
	return position + _pivot.transform * (_t_corps * (_t_tete * _oeil_local))


func rayon_oeil() -> float:
	var r := maxf(1.3, _oeil_rayon)
	if _pivot != null:
		r *= 0.55 + 0.45 * absf(_pivot.scale.x)
	return r


# vers où pointe son museau, dans le monde : la lueur de son œil s'effile de ce côté (scripts/yeux.gd)
func axe_oeil() -> Vector2:
	if _pivot == null:
		return Vector2(regard, 0.0)
	return (_pivot.transform * (_t_corps * _t_tete)).basis_xform(Vector2.RIGHT).normalized()


# sa paupière : 1, l'œil ouvert ; 0, fermé (elle cligne, elle ferme l'œil sous un coup, elle meurt). La nuit, la lueur s'éteint.
func paupiere() -> float:
	if _mort >= 0.0:
		return 1.0 - smoothstep(0.1, 0.38, _mort)
	var o := 1.0
	if _cligne >= 0.0:
		var t := _cligne / _cligne_d
		o = 1.0 - smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.5, 1.0, t))
	return minf(o, 1.0 - smoothstep(0.3, 0.75, _derobe))


func blesser(n: float, depuis: Vector2) -> void:
	if pv <= 0.0:
		return
	pv -= n
	var recul := (position - depuis).normalized() * 10.0
	position += recul
	# (le recul se voit : le corps glisse en arrière, au lieu de sauter ; et ce n'est pas une vitesse)
	_avant += recul
	_recul -= recul
	_eclat = 1.0
	# (elle s'écrase sous le coup : une bête lourde encaisse)
	_ressort_v -= 0.19 * lerpf(22.0, 13.0, _poids) * (1.0 - 0.3 * _poids)
	_derobe = 1.0
	_depuis_coup = 0.0
	# (sa queue claque)
	_q_av += 7.0 * (1.0 if randf() < 0.5 else -1.0)
	if pv <= 0.0:
		# (hors du groupe tout de suite, pour qu'un second coup ne la tue pas deux fois ; elle tombe, puis s'efface)
		remove_from_group("betes")
		if _du_ciel:
			# (la foudre ou l'incendie : ce n'est pas une chasse, rien n'est compté)
			jeu.bete_foudroyee(self)
		else:
			jeu.bete_tuee(self)
		_mourir(depuis)
		return
	if not _du_ciel:
		touchee = true
	match role:
		"proie":
			_fuir(depuis, 4.0 * (1.0 + 0.6 * crainte))
		"rodeur":
			# (craintif, il ne se retourne que s'il lui reste presque toute sa force)
			if masse >= 4.0 and pv > pv_max * lerpf(0.4, 0.75, crainte):
				_charger()
			else:
				_fuir(depuis, 4.0)
		"chasseur":
			# (craintif, il lâche prise plus tôt, plus souvent, plus longtemps ; traqueur, il revient)
			if pv < pv_max * lerpf(0.4, 0.7, crainte) or randf() < lerpf(0.25, 0.6, crainte) * (1.0 - traque):
				_fuir(depuis, maxf(1.0, 2.5 + 4.0 * crainte - 1.2 * traque))


# la foudre, l'incendie : elle est blessée, mais personne ne l'a chassée
func foudroyer(n: float, depuis: Vector2) -> void:
	_du_ciel = true
	blesser(n, depuis)
	_du_ciel = false


# quelque chose l'effraie là-bas (la foudre qui tombe) : une proie s'enfuit, un chasseur recule un moment
func effrayer(depuis: Vector2, duree: float) -> void:
	if pv <= 0.0 or role == "echo":
		return
	_fuir(depuis, duree if role != "chasseur" else duree * 0.6)


# une bûche dans un feu de camp, une gerbe d'étincelles : une population qui craint le feu recule un moment
func gerbe(feu) -> void:
	if pv <= 0.0 or role == "echo" or peur_feu <= 0.2 or position.distance_to(feu.position) > feu.rayon() * 1.3:
		return
	effrayer(feu.position, 1.0 + 2.5 * peur_feu)
	_effaroucher("feu")


# un feu de camp, la torche l'ont arrêtée sans lui faire de mal : Orvane le retiendra, une fois par bête et par nuit (le jour
# du jeu ne change qu'à l'aube)
func _effaroucher(moyen: String) -> void:
	if jeu == null or _effarouchee == int(jeu.jour):
		return
	_effarouchee = int(jeu.jour)
	jeu.bete_effarouchee(self, moyen)


# un assaut sur la veilleuse, compté une fois : une série de morsures n'en fait qu'un, la charge d'un rôdeur aussi, qu'elle morde
# ou non ; il faut REARME secondes sans mordre pour qu'une morsure en ouvre un autre
func _assaillir(duree: float) -> void:
	if _assaut <= 0.0 and jeu != null:
		jeu.bete_attaque(self)
	_assaut = maxf(_assaut, duree)


# le rôdeur charge (plus longtemps s'il traque)
func _charger() -> void:
	_changer("attaque", 6.0 + 4.0 * traque)
	_assaillir(_duree)


# elle s'en va (trop loin, à l'aube) frappée par la veilleuse et en vie : une blessure, dont sa population se souviendra
func _exit_tree() -> void:
	if touchee and pv > 0.0 and jeu != null and is_instance_valid(jeu):
		touchee = false
		jeu.bete_echappee(self)


func _mourir(depuis: Vector2) -> void:
	etat = "mort"
	_mort = 0.0
	_retenu = false
	_cote_chute = 1.0 if position.x >= depuis.x else -1.0
	if _pivot == null:
		queue_free()
		return
	for i in 12:
		_miettes.append(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf()))


# un écho qui se défait (il a traversé la veilleuse) : il se dissipe, puis s'en va
func dissiper() -> void:
	remove_from_group("betes")
	if _dissipe < 0.0:
		_dissipe = 0.0


func _changer(e: String, duree: float) -> void:
	etat = e
	_t = 0.0
	_duree = duree


func _fuir(depuis: Vector2, duree: float) -> void:
	_fuite_de = depuis
	_suit = false
	_changer("fuit", duree)


func _process(delta: float) -> void:
	if jeu == null or jeu.joueur == null or jeu.en_pause:
		return
	if _mort >= 0.0 or _dissipe >= 0.0:
		# (morte, ou un écho qui se défait : plus rien qu'elle-même)
		_finir(delta)
		return
	_conduire(delta)
	_animer(delta)
	_redessiner()


# sa conduite, cette image (l'essai l'appelle aussi tout droit, pour la jouer sans attendre)
func _conduire(delta: float) -> void:
	_t += delta
	_morsure = maxf(0.0, _morsure - delta)
	_assaut = maxf(0.0, _assaut - delta)
	match role:
		"proie":
			_proie(delta)
		"rodeur":
			_rodeur(delta)
		"chasseur":
			_chasseur(delta)
		"echo":
			_echo(delta)
			_process_sillage(delta)


func _aller(vers: Vector2, v: float, delta: float) -> void:
	var d := vers - position
	var l := d.length()
	if l < 1.5:
		return
	# (la boue, l'eau, la neige la freinent aussi : moins une bête légère)
	if jeu != null and role != "echo":
		v *= float(jeu.allure_sol(position, masse))
	var pas := d / l * minf(l, v * delta)
	position += pas
	# (elle ne se retourne que si elle va vraiment de l'autre côté : pas à chaque pas de travers, quand elle monte ou descend)
	if absf(pas.x) > 0.02 and (signf(pas.x) == regard or absf(pas.x) > 0.3 * pas.length()):
		regard = signf(pas.x)
	if jeu != null and jeu.monde != null and jeu.monde.ouvert:
		# (un lieu sans bord : celle qu'on a laissée loin derrière s'en va)
		if role != "echo" and etat != "mort" and jeu.joueur != null and position.distance_to(jeu.joueur.position) > 2600.0:
			queue_free()
	else:
		position = Vector2(clampf(position.x, -R.DEMI, R.DEMI), clampf(position.y, -R.DEMI, R.DEMI))


func _errer(delta: float) -> void:
	if etat == "repos":
		if _t > _duree:
			_cible = maison + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 190.0)
			_changer("marche", randf_range(2.0, 6.0))
			_suivre()
	else:
		_aller(_cible, vitesse * (0.5 if _suit else 0.3), delta)
		if _t > _duree or position.distance_to(_cible) < 4.0:
			if _suit:
				maison = position
			_changer("repos", randf_range(1.0, 4.0))


# la mémoire : un rôdeur qui traque suit la veilleuse de loin, hors de portée de sa charge ; une bête que les joueurs attirent
# vient voir, juste hors de sa distance de fuite. Deux à la fois, pas plus : qu'on puisse les reconnaître. Elle reste de son
# côté (elle ne traverse pas la veilleuse), et n'entre jamais d'elle-même à portée de coup.
func _suivre() -> void:
	_suit = false
	var envie := 0.5 * attrait
	if role == "rodeur":
		envie = maxf(envie, 0.6 * traque)
	var j = jeu.joueur
	var d: Vector2 = position - j.position
	if envie <= 0.0 or d.length() > 900.0 or randf() >= envie:
		return
	var deja := 0
	for b in get_tree().get_nodes_in_group("betes"):
		if b != self and b._suit:
			deja += 1
	if deja >= 2:
		return
	var loin := randf_range(180.0, 260.0) if role == "rodeur" else _distance_fuite(true) + randf_range(30.0, 80.0)
	_cible = j.position + Vector2.from_angle(d.angle() + randf_range(-0.6, 0.6)) * loin
	_suit = true
	_duree = clampf(position.distance_to(_cible) / maxf(vitesse * 0.5, 1.0), 2.0, 8.0)


# à quelle distance de la veilleuse une proie s'enfuit : à son flair (un peu plus de la moitié si la veilleuse ne bouge pas).
# Craintive, de plus loin, mais jamais hors de l'écran (420 pixels) ; habituée, de plus près (60 au moins, si l'on marche vers
# elle), et qui ne bouge pas la voit venir brouter à ses pieds.
func _distance_fuite(en_marche: bool) -> float:
	if crainte <= 0.0 and confiance <= 0.0:
		return flair * (1.0 if en_marche else 0.55)
	if not en_marche:
		return flair * lerpf(0.55, 0.72, crainte) * (1.0 - confiance)
	var k := clampf(pow(1.8, crainte) * pow(0.55, confiance), 0.5, 1.8)
	return clampf(flair * k, minf(flair, 60.0), maxf(flair, 420.0))


func _loin_de(p: Vector2) -> Vector2:
	var d := position - p
	return position + (d.normalized() if d.length() > 0.01 else Vector2.RIGHT) * 240.0


func _proie(delta: float) -> void:
	var j = jeu.joueur
	var dj := position.distance_to(j.position)
	# (l'incendie : elle fuit ses flammes)
	if etat != "fuit" and jeu.incendie != null and jeu.incendie.brule():
		for f in jeu.incendie.foyers:
			if position.distance_to(f.position) < f.rayon() * 0.9:
				_fuir(f.position, 4.0)
				break
	if etat != "fuit" and dj < _distance_fuite(j.en_mouvement):
		_fuir(j.position, randf_range(3.0, 5.0) * (1.0 + 0.6 * crainte))
	if etat == "fuit":
		_aller(_loin_de(j.position if dj < 400.0 else _fuite_de), vitesse, delta)
		if _t > _duree:
			maison = position
			_changer("repos", 1.0)
	else:
		_errer(delta)


func _rodeur(delta: float) -> void:
	var j = jeu.joueur
	var dj := position.distance_to(j.position)
	if etat == "fuit":
		_aller(_loin_de(j.position), vitesse, delta)
		if _t > _duree:
			maison = position
			_changer("repos", 1.0)
		return
	# (habitué, il laisse passer de plus près ; traqueur, il charge de plus loin, 130 pixels au plus)
	var portee := clampf(70.0 - 30.0 * confiance + 60.0 * traque, 40.0, 130.0) + largeur * 0.3
	if etat == "guet":
		# (une charge apprise s'annonce : il s'arrête, tourné vers elle, et gronde ; si elle s'est éloignée, il renonce)
		if absf(j.position.x - position.x) > 2.0:
			regard = signf(j.position.x - position.x)
		if _t > _duree:
			if dj < portee * 1.6:
				_charger()
			else:
				_changer("repos", 1.0)
		return
	if etat != "attaque" and dj < portee and masse >= 4.0 and randf() < audace * delta * 3.0:
		if traque > 0.0:
			_changer("guet", GUET)
			jeu.grognement(self, true)
		else:
			_charger()
	if etat == "attaque":
		_aller(j.position, vitesse * 0.85, delta)
		_mordre_si_pres(dj)
		if _t > _duree:
			_changer("repos", 2.0)
		return
	_errer(delta)


func _chasseur(delta: float) -> void:
	var j = jeu.joueur
	var dj := position.distance_to(j.position)
	_retenu = false
	if jeu.est_jour() and etat != "part":
		_changer("part", 30.0)
	if etat == "part":
		_aller(_loin_de(j.position), vitesse, delta)
		if dj > 1100.0 or _t > _duree:
			queue_free()
		return
	if etat == "fuit":
		_aller(_loin_de(j.position), vitesse * 1.1, delta)
		if _t > _duree:
			_changer("chasse", 999.0)
		return
	# la cible : la veilleuse ; mais pas dans la lumière d'un feu, ni trop près d'une torche
	var but: Vector2 = j.position
	var retenu := false
	var feu = jeu.feu_qui_protege(j.position)
	if feu != null:
		var c: Vector2 = feu.position
		var bord: float = feu.rayon() * 0.85
		var ici := position - c
		var a := ici.angle() + _sens * 0.55
		but = c + Vector2.from_angle(a) * (bord + 16.0)
		retenu = true
		# (arrivé à la lisière d'un feu de camp, il est tenu : Orvane le retiendra ; un incendie n'est le fait de personne)
		if _effarouchee != int(jeu.jour) and ici.length() < feu.rayon() * _lisiere() + 40.0 and jeu.feux.has(feu):
			_effaroucher("feu")
	elif j.torche > 0.0:
		var tenue := _tenue_torche()
		if dj < tenue - 5.0:
			if audace < 0.75 + 0.2 * maxf(peur_feu, 0.0):
				but = j.position + (position - j.position).normalized() * tenue
				retenu = true
				_effaroucher("lumiere")
			elif traque > 0.0 and _presage < PRESAGE:
				# (il a appris à passer la torche : il s'aplatit et gronde d'abord, le temps qu'on le voie venir)
				if _presage <= 0.0:
					jeu.grognement(self, true)
				_presage += delta
				but = j.position + (position - j.position).normalized() * tenue
				retenu = true
		elif dj > tenue + 80.0:
			_presage = 0.0
	_retenu = retenu
	var allure := 0.5 if retenu else 0.9
	if traque > 0.0:
		# (traqueur, il arpente la lisière plus vite et vient plus droit, sans jamais gagner sur elle ce qu'il ne gagnait pas déjà)
		allure = 0.5 + 0.25 * traque if retenu else maxf(0.9, minf(lerpf(0.9, 1.0, traque), 0.97 * R.VITESSE / maxf(vitesse, 1.0)))
	_aller(but, vitesse * allure, delta)
	# (le feu a grandi sous elle : la bête recule hors de sa lumière ; plus loin encore si elle le craint)
	var lisiere := _lisiere()
	for f in jeu.feux_et_foyers():
		if f.allume():
			var ici2: Vector2 = position - f.position
			var bord2: float = f.rayon() * lisiere
			if ici2.length() < bord2:
				position = f.position + ici2.normalized() * bord2
	if not retenu:
		_mordre_si_pres(dj)
	if randf() < delta * 0.08 and dj < 420.0:
		jeu.grognement(self)


# jusqu'où un chasseur entre dans la lumière d'un feu, en parts de son rayon : 0,8, jamais moins (le feu reste une loi) ; plus
# loin s'il craint le feu ou les joueurs, jusqu'à 1,05 : on ne voit plus alors que ses yeux
func _lisiere() -> float:
	return 0.8 + maxf(0.25 * maxf(peur_feu, 0.0), 0.15 * crainte)


# à quelle distance la torche le tient : 145 pixels ; de plus loin s'il craint le feu, de plus près s'il s'y est fait ou s'il
# est habitué aux veilleuses (100 au moins : il s'y tient à quelques pixels près, hors de portée de morsure)
func _tenue_torche() -> float:
	return clampf(145.0 - 35.0 * confiance + 60.0 * peur_feu, 100.0, 205.0)


func _mordre_si_pres(dj: float) -> void:
	if dj < 24.0 + largeur * 0.3 and _morsure <= 0.0:
		_morsure = 1.15
		_assaillir(REARME)
		jeu.mordre(self)


func _echo(delta: float) -> void:
	var j = jeu.joueur
	_apparition = minf(1.0, _apparition + delta * 0.4)
	var fin: bool = jeu.est_jour() or j.peur < 30.0
	if fin:
		_apparition = maxf(0.0, _apparition - delta * 0.9)
		if _apparition <= 0.0:
			queue_free()
	var but: Vector2 = j.position + Vector2(sin(_t * 0.7) * 50.0, cos(_t * 0.5) * 30.0)
	_aller(but, 32.0, delta)
	# (une transparence qui respire, lentement)
	modulate = Color(1.0, 1.0, 1.0, (0.6 + 0.18 * sin(_t * 1.9)) * _apparition)
	if not fin and position.distance_to(j.position) < 22.0:
		jeu.toucher_echo(self)


# --- l'animation ---

func _animer(delta: float) -> void:
	_anim += delta
	_depuis_coup += delta
	if _premiere:
		_premiere = false
		_avant = position
	# la vitesse vraie, lissée (un saut de position, une bête qu'on déplace, n'en est pas une)
	var d := position - _avant
	var vi := d / maxf(delta, 0.0001)
	_avant = position
	if vi.length() > vitesse * 3.0 + 80.0:
		vi = _vit
		d = Vector2.ZERO
	var v0 := _vit.length()
	_vit = _vit.lerp(vi, 1.0 - exp(-delta * 9.0))
	var v := _vit.length()
	_accel = lerpf(_accel, (v - v0) / maxf(delta, 0.0001), 1.0 - exp(-delta * 4.0))
	# le sol qui passe sous elle, vu de profil : c'est ce dont ses pieds posés reculent. Quand elle monte ou descend dans le
	# lieu, on ne le voit presque pas passer : elle piétine, plutôt que de marcher de côté
	var dl := d.length()
	_avance = maxf(absf(d.x), 0.4 * dl)
	if dl > 0.02:
		_proj = lerpf(_proj, _avance / dl, 1.0 - exp(-delta * 8.0))
	_cligner(delta)
	if _pivot == null:
		_face = move_toward(_face, regard, delta / 0.16)
		return
	if _mort < 0.0:
		_allure(v, delta)
	var lisse := 1.0 - exp(-delta * 9.0)
	_eclat = maxf(0.0, _eclat - delta / 0.09)
	_derobe = maxf(0.0, _derobe - delta / 0.32)
	_recul = _recul.lerp(Vector2.ZERO, 1.0 - exp(-delta * 15.0))
	# (le ressort du corps : vif chez une bête légère, lourd chez une grosse)
	var wr := lerpf(22.0, 13.0, _poids)
	_ressort_v += (-wr * wr * _ressort - 0.82 * wr * _ressort_v) * delta
	_ressort += _ressort_v * delta
	# le retournement : un demi-tour de papier, sans saut ; plus lent chez une bête lourde
	var avant_face := _face
	_face = move_toward(_face, regard, delta / lerpf(0.15, 0.26, _poids))
	if avant_face == regard * -1.0 and _face != avant_face:
		# (elle se retourne : elle cligne, ses pieds piétinent, sa queue suit avec du retard)
		if _cligne < 0.0:
			_cligne = 0.0
		_pietine = 1.0
		_q_av += 5.0
	var fx := sin(_face * PI * 0.5)
	if absf(fx) < 0.05:
		fx = 0.05 if _face >= 0.0 else -0.05
	_pivot.scale = Vector2(fx, 1.0)
	_pivot.position = _recul
	# (hors de l'écran, elle marche toujours, mais on ne la dessine pas)
	_a_l_ecran = role == "echo" or _mort >= 0.0 or _sur_l_ecran()
	if not _a_l_ecran:
		_hors = true
		return
	if _mort < 0.0 and not _p_pts.is_empty():
		if _hors:
			_caler_pieds()
		_rebondir()
		_cibles_pieds()
	_hors = false
	_corps(v, delta, lisse, fx)
	_pas_des_pattes()
	if _queue != null:
		_animer_queue(delta)
	_parametres()


# ce que montre la caméra, dans le lieu (calculé une fois par image, pour toutes les bêtes)
func _sur_l_ecran() -> bool:
	var f := Engine.get_process_frames()
	if f != _vue_image:
		_vue_image = f
		var vp := get_viewport()
		_vue = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return _vue.grow(largeur * 1.5 + 40.0).has_point(global_position)


# l'allure, d'après ce qu'elle fait et sa vitesse : le pas, l'affût (bas, de longs pas lents), la course, le galop (une proie
# qui fuit bondit ; un chasseur lancé galope)
func _allure(v: float, delta: float) -> void:
	var lisse := 1.0 - exp(-delta * 6.0)
	var nuit: bool = role == "chasseur" and not jeu.est_jour()
	var affut := 1.0 if nuit and _retenu else 0.0
	var vite := clampf((v / maxf(vitesse, 1.0) - 0.42) / 0.3, 0.0, 1.0) * (1.0 - affut)
	var bond := vite if _n_cote == 2 and (role != "proie" or etat == "fuit") else 0.0
	_marche = lerpf(_marche, smoothstep(2.5, 12.0, v), 1.0 - exp(-delta * 10.0))
	_affut = lerpf(_affut, affut, lisse)
	_bond = lerpf(_bond, bond, lisse)
	_course = lerpf(_course, vite - bond, lisse)
	var w_pas := maxf(0.0, 1.0 - _affut - _course - _bond)
	# la foulée (en longueurs de patte), la part du cycle où le pied est posé, la hauteur où il se lève : une bête lourde
	# garde ses pieds au sol plus longtemps et les lève à peine
	_foulee = 0.85 * w_pas + 1.05 * _affut + 1.15 * _course + _g_foulee * _bond
	_appui = lerpf(0.6, 0.68, _poids) * w_pas + 0.76 * _affut + 0.42 * _course + _g_appui * _bond
	_levee = lerpf(0.26, 0.14, _poids) * w_pas + 0.15 * _affut + lerpf(0.4, 0.26, _poids) * _course + lerpf(0.42, 0.3, _poids) * _bond
	_bas = lerpf(_bas, (0.08 if nuit else 0.0) + 0.14 * affut + (0.07 if role != "proie" else 0.03) * vite, lisse)
	if role == "echo":
		_appui = 0.7
		_levee = 0.2
	# la cadence : le pied posé recule avec le sol, le temps d'une foulée. Trop vite pour l'œil, la cadence plafonne : le pied
	# reste moins longtemps au sol (elle vole entre deux appuis), et seulement après la foulée s'allonge
	var s := clampf(_foulee * _H, 0.5, _s_max)
	var f := _appui * v / s
	# (à la course, ce sont ses pattes qui donnent la cadence : elles battent à leur rythme, d'une foulée plus courte)
	f = maxf(f, _f_course * (_course + _bond) * minf(1.0, v / maxf(vitesse * 0.7, 1.0)))
	if f > _f_max:
		f = _f_max
		_appui = clampf(s * f / maxf(v, 1.0), 0.22, _appui)
	_foulee_eff = (_appui * v / f) if f > 0.01 else s
	# (à l'arrêt, le cycle continue tant qu'un pied n'est pas revenu à sa place : elle se remet d'aplomb)
	if _marche < 0.15 and (_a_poser or _pietine > 0.0):
		f = maxf(f, _f_pose)
	_pietine = maxf(0.0, _pietine - delta / 0.8)
	_phase = fposmod(_phase + f * delta, 1.0)
	for i in _p_dec.size():
		var dec := _dec_pas[i]
		if _bond > 0.001:
			dec = lerp_angle(dec * TAU, _dec_bond[i] * TAU, _bond) / TAU
		if _affut > 0.001:
			dec = lerp_angle(dec * TAU, _dec_affut[i] * TAU, _affut) / TAU
		# (un pied qui a devancé son tour y revient peu à peu)
		_p_hate[i] = move_toward(_p_hate[i], 0.0, delta * 0.3)
		_p_dec[i] = dec + _p_hate[i]
	if _sans:
		# (sans pattes : la vague court à la vitesse de la bête, et ne s'arrête jamais tout à fait)
		_onde_phase += delta * (1.1 + v / maxf(6.0, _H * 1.2))


# la course : quand plus aucun pied ne touche le sol, elle vole (d'autant plus haut que le vol est long) ; quand ses pattes
# la reçoivent, elle s'écrase un peu dessus. Rien au pas : il y a toujours un pied posé.
func _rebondir() -> void:
	_vol_y = 0.0
	_air = 0.0
	_air_px = 0.0
	var n_p := _p_dec.size()
	if _marche < 0.05 or _appui > 0.56 or role == "echo":
		return
	# quand chaque patte se pose, dans le cycle ; un vol : l'écart entre deux poses dépasse le temps d'appui
	var poses: Array = []
	for i in n_p:
		poses.append(fposmod(-_p_dec[i], 1.0))
	poses.sort()
	var vols: Array = []          # [début, durée]
	for k in n_p:
		var ecart: float = fposmod(poses[(k + 1) % n_p] - poses[k], 1.0)
		if n_p == 1:
			ecart = 1.0
		if ecart > _appui + 0.015:
			vols.append(Vector2(fposmod(poses[k] + _appui, 1.0), ecart - _appui))
	if vols.is_empty():
		return
	var arc := _g_arc * _bond + lerpf(0.16, 0.07, _poids) * (1.0 - _bond)
	if _n_cote >= 3:
		arc *= 0.25
	var haut := arc * _H * _marche
	var u := _phase
	var avant_fin := 2.0
	var apres_debut := 2.0
	var h_avant := 0.0
	var h_apres := 0.0
	for g in vols:
		var h: float = haut * minf(pow(g.y / 0.2, 2.0), 1.5)
		var t := fposmod(u - g.x, 1.0)
		if t < g.y:
			# en l'air
			var b := pow(sin(PI * t / g.y), 2.0)
			_vol_y = -h * b
			_air = b * minf(1.0, h / maxf(0.08 * _H, 0.01))
			_air_px = h * b
			return
		# (sinon : entre deux vols, sur ses pattes ; on cherche le vol d'avant et celui d'après)
		var depuis: float = t - g.y
		if depuis < avant_fin:
			avant_fin = depuis
			h_avant = h
		var jusqu := fposmod(g.x - u, 1.0)
		if jusqu < apres_debut:
			apres_debut = jusqu
			h_apres = h
	var duree_ := avant_fin + apres_debut
	if duree_ > 0.001:
		_vol_y = 0.3 * 0.5 * (h_avant + h_apres) * pow(sin(PI * avant_fin / duree_), 2.0)


# ses pieds, remis dans leur pas d'après le cycle (au départ, et quand elle revient à l'écran)
func _caler_pieds() -> void:
	var cible := 0.5 * _foulee_eff * _proj * _marche
	for i in _p_pts.size():
		var u := fposmod(_phase + _p_dec[i], 1.0)
		if u < _appui:
			_p_pose[i] = 1
			_p_off[i] = cible * (1.0 - 2.0 * u / maxf(_appui, 0.01))
		else:
			_p_pose[i] = 0
			_p_dep[i] = -cible
		_p_lev[i] = 0.0


# où va chaque pied, sous le corps : posé, il tient au sol, et c'est le sol qui recule sous la bête ; levé, il va de là où il
# a quitté le sol à là où il se posera, en avant, d'une demi-foulée
func _cibles_pieds() -> void:
	var H := _H
	var m := _marche
	var cible := 0.5 * _foulee_eff * _proj * m
	var lim := _s_max * 0.6
	var hauteur := _levee * H
	var seuil := H * 0.04
	var marge := H * 0.14
	var a_poser := false
	for i in _p_pts.size():
		var u := fposmod(_phase + _p_dec[i], 1.0)
		var off := _p_off[i]
		if u < _appui:
			_p_pose[i] = 1
			off = clampf(off - _avance, -lim, lim)
			_p_lev[i] = 0.0
			if absf(off) > seuil:
				a_poser = true
			if off < -(cible + marge) and m > 0.3:
				# (resté trop loin derrière, au départ, dans un coup de frein : il se lève sans attendre son tour)
				var hate := wrapf(_p_hate[i] + _appui - u, -0.5, 0.5)
				_p_dec[i] += hate - _p_hate[i]
				_p_hate[i] = hate
				u = _appui
		if u >= _appui:
			if _p_pose[i] == 1:
				_p_pose[i] = 0
				_p_dep[i] = off
			var t := (u - _appui) / (1.0 - _appui)
			var dep := _p_dep[i]
			off = lerpf(dep, cible, t * t * (3.0 - 2.0 * t))
			# (il se lève d'autant plus qu'il va loin ; en l'air avec elle, il suit le corps)
			var ampleur := maxf(sqrt(clampf((absf(cible - dep) - seuil) / (0.6 * H), 0.0, 1.0)), 0.4 * _pietine)
			_p_lev[i] = sin(PI * pow(t, 0.75)) * hauteur * ampleur + _air_px * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.75, 1.0, t))
			if absf(dep) > seuil:
				a_poser = true
		_p_off[i] = off
	_a_poser = a_poser


# ce qu'il manque à ses pattes pour atteindre leurs pieds, le corps étant là : devant, derrière (en pixels dont il faudrait
# descendre), et l'écart entre ses épaules et ses hanches (0 : on ne sait pas la faire tanguer)
func _besoin(t: Transform2D) -> Vector3:
	var df := 0.0
	var dh := 0.0
	var xf := 0.0
	var xh := 0.0
	var nf := 0
	var nh := 0
	var ecart := 0.18 * _derobe
	for i in _p_pts.size():
		var pts := _p_pts[i]
		var n := pts.size() - 1
		var h := t * pts[0]
		var dx := pts[n].x + _p_off[i] + (pts[n].x - _c.x) * ecart - h.x
		var dy := pts[n].y - _p_lev[i] - h.y
		var r := _p_atteint[i]
		var manque := dy - sqrt(maxf(r * r - dx * dx, r * r * 0.09))
		if _p_devant[i]:
			df = maxf(df, manque)
			xf += h.x
			nf += 1
		else:
			dh = maxf(dh, manque)
			xh += h.x
			nh += 1
	if nf == 0 or nh == 0:
		return Vector3(maxf(df, dh), maxf(df, dh), 0.0)
	var large := xf / nf - xh / nh
	return Vector3(df, dh, large if large > _H * 0.5 else 0.0)


# le corps : porté par ses pattes, la pente, le rebond, l'affût, le souffle, le sursaut ; la tête qui suit
func _corps(v: float, delta: float, lisse: float, fx: float) -> void:
	var H := _H
	var marche := _marche
	var y := 0.0
	var x := 0.0
	var tang := 0.0
	var sx := 1.0
	var sy := 1.0
	var six := _n_cote >= 3
	var u := _phase
	var leger := 1.0 - _poids
	if _sans:
		y -= H * 0.04 * sin(_onde_phase * 0.5)
	# la pente de sa course, et son élan (une bête lourde met plus longtemps à se redresser)
	var pente := clampf(_vit.y / maxf(v, 25.0), -1.0, 1.0) * marche
	var cible_t := pente * 0.09 + clampf(_accel / maxf(vitesse * 4.0, 1.0), -1.0, 1.0) * 0.07
	_tangage = lerpf(_tangage, cible_t, 1.0 - exp(-delta * lerpf(5.0, 2.4, _poids)))
	tang += _tangage
	# la course, le bond : étirée en l'air, tassée sur ses appuis ; au galop, elle bascule de l'arrière sur l'avant
	y += _vol_y
	sx *= 1.0 + 0.07 * _air * leger
	sy *= 1.0 - 0.04 * _air * leger
	if _vol_y > 0.0:
		sy *= 1.0 - 0.5 * _vol_y / maxf(H, 1.0)
	if _bond > 0.01:
		tang -= _g_tangage * sin((u - _g_ref) * TAU) * _bond * marche
	var vol := -minf(_vol_y, 0.0)
	# à l'affût, et la nuit pour un chasseur : plus bas
	y += H * _bas
	# le souffle, au repos : lent chez une grande bête ; court et fort après une course
	var repos := 1.0 - marche
	_essouffle = clampf(_essouffle + delta * ((_course + _bond) * 0.5 - 0.16), 0.0, 1.0)
	_souffle += delta * TAU / (1.3 + 1.1 * log(masse + 1.0) / log(10.0)) * (1.0 + 1.5 * _essouffle)
	var ampleur := (0.026 + 0.02 * _essouffle) * (0.35 + 0.65 * repos)
	sy *= 1.0 + ampleur * sin(_souffle)
	sx *= 1.0 + ampleur * 0.3 * sin(_souffle)
	# frappée : elle s'écrase, ses pattes se dérobent
	sy *= 1.0 + _ressort
	sx *= 1.0 - _ressort * 0.55
	y += H * lerpf(0.34, 0.2, _poids) * (1.0 - pow(1.0 - _derobe, 2.0)) * (1.0 if _mort < 0.0 else 0.0)
	# elle s'ébroue : un frisson, de la tête à la queue
	var frisson := 0.0
	if _geste == "frisson":
		frisson = sin(_geste_age * 34.0) * sin(PI * clampf(_geste_age / 0.5, 0.0, 1.0))
		sx *= 1.0 + 0.018 * frisson
		tang += 0.012 * frisson
	# elle broute, elle flaire le sol : ses épaules s'abaissent un peu
	var penche := 0.0
	if _geste == "broute" or _geste == "flaire":
		penche = _broute_penche
	_penche = lerpf(_penche, penche, 1.0 - exp(-delta * 4.0))
	tang += _penche
	# le demi-tour : un petit saut chez une bête légère, le temps de se retourner
	var saut := H * 0.1 * (1.0 - absf(fx)) * leger
	y -= saut
	# un écho flotte, ses pieds ne touchent plus le sol
	if role == "echo":
		y -= H * (0.32 + 0.12 * sin(_anim * 1.4))
	var c := _c
	var ventre := _ventre
	if _mort >= 0.0:
		# morte : un insecte se retourne sur le dos, d'un sursaut ; les autres s'affaissent sur le flanc, le ventre au sol
		tang = 0.0
		if six:
			var roule := smoothstep(0.04, CHUTE, _mort)
			sy *= cos(PI * 0.96 * roule)
			y -= H * 0.8 * sin(PI * roule)
		else:
			var t := smoothstep(0.0, CHUTE, _mort)
			var t2 := t * t
			y += -ventre * 0.9 * t2
			# (poussée par le coup : elle glisse un peu à l'opposé)
			x += _cote_chute * signf(fx) * H * 0.3 * t
			sy *= 1.0 - 0.14 * t2
			tang = 0.1 * t2
	_leve = -y if (role == "echo" or _mort >= 0.0) else vol + saut
	# (le corps se plie autour de son centre, et s'écrase vers ses hanches : le dos bouge, le ventre tient)
	y += (ventre - c.y) * (1.0 - sy)
	# porté par ses pattes : là où une patte tendue n'atteint plus son pied, la hanche descend ; l'avant et l'arrière chacun
	# pour soi (le dos roule), puis le corps entier de ce qu'il manque encore
	if _mort < 0.0 and role != "echo" and not _p_pts.is_empty():
		var t0 := Transform2D(tang, Vector2(sx, sy), 0.0, c + Vector2(x, y)) * Transform2D(0.0, -c)
		var b := _besoin(t0)
		var roulis := clampf((b.x - b.y) / b.z, -0.1, 0.1) if b.z > 0.0 else 0.0
		_porte_a = lerpf(_porte_a, roulis, 1.0 - exp(-delta * 14.0))
		tang += _porte_a
		var t1 := Transform2D(tang, Vector2(sx, sy), 0.0, c + Vector2(x, y)) * Transform2D(0.0, -c)
		var b1 := _besoin(t1)
		var manque := maxf(b1.x, b1.y)
		# (il descend aussitôt qu'il le faut, et remonte en douceur : le poids)
		_porte = maxf(manque, lerpf(_porte, manque, 1.0 - exp(-delta * lerpf(30.0, 14.0, _poids))))
		y += _porte
	else:
		_porte = 0.0
		_porte_a = 0.0
	_t_corps = Transform2D(tang, Vector2(sx, sy), 0.0, c + Vector2(x, y)) * Transform2D(0.0, -c)
	# la tête suit le corps, un peu en retard ; au repos, elle broute, guette, hume
	_gestes_repos(delta)
	var rot := 0.0
	var d := Vector2.ZERO
	var souple := 0.4 if six else 1.0
	match _geste:
		"broute":
			# (elle arrache l'herbe : de petits coups de tête)
			rot = _broute_rot + 0.035 * sin(_anim * 9.0)
			d = Vector2(0.05, 0.14) * H
		"flaire":
			rot = _broute_rot * 0.85 + 0.05 * sin(_geste_age * 2.6)
			d = Vector2(0.07, 0.12) * H
		"guette":
			rot = -0.13
			d = Vector2(-0.02, -0.07) * H
		"hume":
			# (le nez au vent : deux ou trois petits coups)
			rot = -0.2 + 0.04 * sin(_geste_age * 13.0) * sin(PI * clampf(_geste_age / 1.1, 0.0, 1.0))
			d = Vector2(0.03, -0.05) * H
		"frisson":
			rot = 0.05 * frisson
	rot += 0.12 * _affut + 0.06 * _course + 0.07 * _bond
	d += Vector2(0.06, 0.12) * H * _affut
	var raide := 1.0 - exp(-delta * lerpf(6.0, 3.6, _poids))
	_tete_rot = lerpf(_tete_rot, rot * souple, raide)
	_tete_d = _tete_d.lerp(d * souple, raide)
	var td := _tete_d
	# (la tête ne suit pas tout à fait le roulis du dos, ni le bond : elle regarde droit)
	var tr := _tete_rot - 0.6 * _porte_a - 0.5 * (tang - _porte_a - _penche) * (1.0 if _mort < 0.0 else 0.0)
	td.y -= 0.35 * _porte
	if _n_cote == 1:
		# (un oiseau, un bipède : la tête va de l'avant à chaque pas, puis attend)
		var w := fposmod(u * 2.0, 1.0)
		td.x += H * 0.09 * (smoothstep(0.0, 0.3, w) - w) * marche * (1.0 - _bond)
	if _mort >= 0.0 and not six:
		# (la tête retombe au sol)
		tr += 0.42 * smoothstep(0.1, CHUTE + 0.1, _mort)
		td.y += H * 0.3 * smoothstep(0.1, CHUTE + 0.1, _mort)
	if _tete == null:
		_t_tete = Transform2D.IDENTITY
	else:
		var pv_t: Vector2 = _sq["tete"]["pivot"]
		_t_tete = Transform2D(tr, Vector2.ONE, 0.0, pv_t + td) * Transform2D(0.0, -pv_t)
	var demi := Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2.ZERO)
	sprite.transform = _t_corps * demi
	if _dessus != null:
		_dessus.transform = _t_corps * demi
	if _tete != null:
		_tete.transform = _t_corps * _t_tete * demi


# ce qu'elle fait quand elle ne va nulle part : une proie broute, guette, hume ; un chasseur guette, hume, flaire le sol ;
# toutes piétinent, s'ébrouent, se retournent (une bête lourde moins souvent)
func _gestes_repos(delta: float) -> void:
	_geste_t -= delta
	_geste_age += delta
	if _marche > 0.3 or role == "echo" or _mort >= 0.0:
		_geste = ""
		_geste_t = maxf(_geste_t, 0.6)
		return
	if etat == "guet":
		# (le rôdeur qui va charger : la tête levée, sans la quitter des yeux)
		_geste = "guette"
		_geste_t = 0.3
		return
	if _geste_t > 0.0:
		return
	_geste_age = 0.0
	var x := randf()
	var tourne := 0.12 * (1.0 - 0.6 * _poids)
	if role == "proie":
		# (craintive, elle broute moins et guette plus : on le voit avant de l'approcher)
		if x < 0.4 - 0.25 * crainte:
			_geste = "broute"
			_geste_t = randf_range(1.6, 3.6)
		elif x < 0.62:
			_geste = "guette"
			_geste_t = randf_range(0.8, 1.8)
		elif x < 0.7:
			_geste = "hume"
			_geste_t = randf_range(1.1, 1.5)
		elif x < 0.7 + tourne:
			# (un regard qui se détourne)
			_geste = ""
			regard = -regard
			_geste_t = randf_range(1.0, 2.0)
		elif x < 0.88:
			_geste = "pietine"
			_pietine = 1.0
			_geste_t = randf_range(0.8, 1.2)
		elif x < 0.93:
			_geste = "frisson"
			_geste_t = 0.5
		else:
			_geste = ""
			_geste_t = randf_range(0.8, 2.0)
	else:
		if x < 0.32:
			_geste = "guette"
			_geste_t = randf_range(1.0, 2.2)
		elif x < 0.47:
			_geste = "hume"
			_geste_t = randf_range(1.1, 1.6)
		elif x < 0.6:
			_geste = "flaire"
			_geste_t = randf_range(1.6, 2.8)
		elif x < 0.6 + tourne:
			_geste = ""
			regard = -regard
			_geste_t = randf_range(1.5, 3.0)
		elif x < 0.8:
			_geste = "pietine"
			_pietine = 1.0
			_geste_t = randf_range(0.8, 1.3)
		elif x < 0.85:
			_geste = "frisson"
			_geste_t = 0.5
		else:
			_geste = ""
			_geste_t = randf_range(1.0, 2.5)


# chaque patte : la hanche suit le corps, le pied est là où son pas l'a mis ; le genou plie du côté de la planche
func _pas_des_pattes() -> void:
	var n_p := _p_pts.size()
	if n_p == 0:
		return
	var H := _H
	var c := _c
	var plie := smoothstep(0.08, 0.45, _mort) if _mort >= 0.0 else 0.0
	var haut := maxf(_levee * H, 0.5)
	for i in n_p:
		var pts := _p_pts[i]
		var n := pts.size() - 1
		var devant := _p_devant[i]
		var hanche := _t_corps * pts[0]
		var pied := pts[n] + Vector2(_p_off[i], -_p_lev[i])
		# (frappée : les pieds s'écartent, les pattes plient)
		pied.x += (pts[n].x - c.x) * 0.18 * _derobe
		var lev := clampf(_p_lev[i] / haut, 0.0, 1.0)
		if plie > 0.0:
			# morte : les pattes ne portent plus. Sur le dos, elles se replient et frémissent ; sur le flanc, celles de devant
			# s'étalent au sol (vers nous), celles de derrière se perdent sous le corps
			var v := pts[n] - pts[0]
			var portee := _p_portee[i]
			var replie := pts[0]
			if _n_cote >= 3:
				var fremit := 0.35 * sin(_mort * 23.0 + float(i) * 1.7) * (1.0 - smoothstep(CHUTE, CHUTE + GISANT + 0.6, _mort))
				replie += v.rotated(0.6 * (1.0 if devant else -1.0) + fremit) * 0.5
			elif _p_loin[i]:
				replie += Vector2(v.x * 0.5, v.y * 0.2)
			else:
				replie += Vector2(v.x * 0.4 + portee * (0.4 if devant else -0.3), portee * 0.62)
			pied = pied.lerp(_t_corps * replie, plie)
			lev = plie
		var j := _ik(i, hanche, pied, plie > 0.0 or role == "echo")
		_pieds[i] = j
		var bas: Vector2 = j[n] - j[1]
		_rot_pieds[i] = wrapf(bas.angle() - _p_ang[i], -PI, PI) * clampf(lev * 1.4, 0.0, 1.0)


# deux os : la cuisse, et le reste de la patte d'un seul tenant ; le genou du côté où la planche le plie. La cuisse ne
# s'écarte pas trop de son repos (une patte ne se retourne pas, ne s'arrache pas de l'épaule) ; ce qui manque alors pour
# atteindre le pied, le bas de la patte le rattrape en s'allongeant ou en se tassant un peu (le pied qui se déroule)
func _ik(i: int, h: Vector2, f: Vector2, libre: bool) -> PackedVector2Array:
	var l1 := _p_l1[i]
	var l2 := _p_l2[i]
	var d := f - h
	var l := d.length()
	var dist := clampf(l, absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var dir := d / l if l > 0.0001 else Vector2.DOWN
	var a := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var ang := dir.angle() - a * _p_plie[i]
	if not libre:
		var da := wrapf(ang - _p_ang0[i], -PI, PI)
		var lim := _p_lim[i]
		if absf(da) > lim:
			ang = _p_ang0[i] + clampf(da, -lim, lim)
	var genou := h + Vector2.from_angle(ang) * l1
	var bas := f - genou
	var lb := bas.length()
	var etire := 1.0 if libre else clampf(lb / l2, 0.82 - _p_jeu[i], 1.0 + _etire + 0.05 + _p_jeu[i])
	var vers := bas / lb if lb > 0.0001 else Vector2.DOWN
	var pied := genou + vers * l2 * etire
	_p_etire[i] = etire
	var out := PackedVector2Array([h, genou])
	var rel := _p_rel[i]
	if not rel.is_empty():
		var ang_b := vers.angle()
		for r in rel:
			out.append(genou + r.rotated(ang_b) * etire)
	out.append(pied)
	return out


# --- la queue ---

# elle vit autour de sa racine : un ressort la ramène à sa pose (levée dans la fuite, basse à l'affût, à plat quand elle
# meurt), ce que fait le corps la secoue (elle traîne au départ, dépasse à l'arrêt, bat au pas), son bout suit sa base avec
# du retard ; au repos, selon son caractère, elle fouette (les audacieux, les chasseurs) ou frémit (les craintifs)
func _animer_queue(delta: float) -> void:
	var dt := minf(delta, 0.05)
	# ce qui la secoue : la racine, portée par le corps, et l'élan de la bête
	var racine := _t_corps * _q_pivot
	var vr := (racine - _q_avant) / maxf(dt, 0.001)
	_q_avant = racine
	if _q_neuve:
		_q_neuve = false
		vr = Vector2.ZERO
		_q_vit = Vector2.ZERO
	var acc := ((vr - _q_vit) / maxf(dt, 0.001)).limit_length(2200.0)
	_q_vit = vr
	acc.x += clampf(_accel, -700.0, 700.0)
	var dir := _q_axe.rotated(_q_a)
	var couple := 1.1 * (acc.x * dir.y - acc.y * dir.x) / maxf(_q_long, 6.0)
	# sa pose
	var cible := 0.0
	var cible_b := 0.0
	var vif_a := 0.0              # (ce qui frémit va droit au dessin : le ressort l'étoufferait)
	var vif_b := 0.0
	var w := lerpf(15.0, 8.0, _poids)
	var z := 0.36
	var repos := 1.0 - _marche
	if _mort >= 0.0:
		# (elle retombe, molle, à plat derrière elle)
		cible = wrapf(Vector2(-1.0, 0.25).angle() - _q_axe.angle(), -PI, PI) * smoothstep(0.0, CHUTE, _mort)
		w *= 0.7
		z = 0.7
	elif role == "echo":
		# (une fumée : elle ondule lentement)
		cible = 0.22 * sin(_anim * 1.1)
		cible_b = 0.3 * sin(_anim * 1.1 - 1.2)
		w *= 0.5
		z = 0.8
	else:
		var vite := _course + _bond
		# (dans la fuite, la queue d'une proie se dresse ; celle d'un chasseur lancé file droit derrière lui)
		var levee := Vector2(-0.5, -0.87) if role == "proie" else Vector2(-1.0, -0.1)
		cible += wrapf(levee.angle() - _q_axe.angle(), -PI, PI) * (0.55 if role == "proie" else 0.8) * vite
		cible += wrapf(Vector2(-1.0, 0.42).angle() - _q_axe.angle(), -PI, PI) * 0.6 * _affut
		cible += 0.02 * sin(_souffle * 0.5 + 1.0) * repos
		# (au pas, elle bat la mesure)
		cible += 0.06 * _q_souple * sin(_phase * TAU) * _marche * (1.0 - vite) * (1.0 - _affut)
		if _geste == "guette":
			cible += 0.1
		if _geste == "frisson":
			vif_b += 0.22 * sin(_geste_age * 34.0 - 1.0) * sin(PI * clampf(_geste_age / 0.5, 0.0, 1.0))
		# ses gestes à elle, au repos ; à l'affût, son bout bat
		_q_attente -= dt
		if _q_geste == "" and _q_attente <= 0.0 and (_marche < 0.2 or _affut > 0.5):
			var hardi := audace > 0.55 or (role != "proie" and audace > 0.3) or _affut > 0.5
			_q_geste = "fouette" if hardi else "fremit"
			_q_geste_t = 0.0
			_q_geste_s = 1.0 if randf() < 0.65 else -1.0
			if hardi:
				_q_geste_d = lerpf(0.5, 0.85, _poids)
				_q_attente = randf_range(2.2, 5.5) * (1.4 - 0.7 * audace)
			else:
				_q_geste_d = 0.42
				_q_attente = randf_range(1.8, 5.0) * (0.6 + audace)
		if _q_geste != "":
			_q_geste_t += dt
			var g := clampf(_q_geste_t / _q_geste_d, 0.0, 1.0)
			if _q_geste == "fouette":
				# (un coup lent, puis le bout qui claque)
				cible += 0.42 * _q_souple * _q_geste_s * sin(PI * g) * (1.0 if _affut < 0.5 else 0.3)
				cible_b += 0.5 * _q_souple * _q_geste_s * sin(TAU * g - 0.9) * sin(PI * g)
			else:
				vif_b += 0.26 * sin(TAU * 9.0 * _q_geste_t) * sin(PI * g)
				vif_a += 0.05 * sin(TAU * 9.0 * _q_geste_t) * sin(PI * g)
			if g >= 1.0:
				_q_geste = ""
	cible = clampf(cible, -1.15, 1.15)
	_q_av += (-w * w * (_q_a - cible) - 2.0 * z * w * _q_av + couple) * dt
	_q_a = clampf(_q_a + _q_av * dt, -1.3, 1.3)
	# le bout : il suit la base, en retard
	var wb := w * 0.8
	cible_b += clampf(-_q_av * 0.085, -0.7, 0.7) * _q_souple
	_q_bv += (-wb * wb * (_q_b - cible_b) - 2.0 * 0.32 * wb * _q_bv + couple * 0.7 * _q_souple) * dt
	_q_b = clampf(_q_b + _q_bv * dt, -1.2, 1.2)
	# les tranches du dessin, chacune tournée autour de la racine
	for k in _q_t.size():
		var t := _q_t[k]
		var a := (_q_a + vif_a) * smoothstep(0.0, 0.3, t) + (_q_b + vif_b) * t * t
		var co := cos(a)
		var si := sin(a)
		for s in 2:
			var r := _q_repos[2 * k + s] - _q_pivot
			_q_pts[2 * k + s] = _q_pivot + Vector2(r.x * co - r.y * si, r.x * si + r.y * co)
	_queue.polygon = _q_pts
	_queue.transform = _t_corps


# --- l'œil ---

# elle cligne : de temps en temps, parfois deux fois de suite ; moins quand elle guette
func _cligner(delta: float) -> void:
	if _cligne >= 0.0:
		_cligne += delta
		if _cligne >= _cligne_d:
			_cligne = -1.0
		return
	_cligne_t -= delta * (0.4 if _geste == "guette" else 1.0)
	if _cligne_t <= 0.0:
		_cligne = 0.0
		_cligne_d = lerpf(0.17, 0.27, _poids)
		_cligne_t = randf_range(0.22, 0.4) if randf() < 0.16 else randf_range(2.4, 6.5)


# ce que lit le shader de son encre
func _parametres() -> void:
	_param("eclat", _eclat * 0.85)
	if role == "echo" or _mort >= 0.0 or _dissipe >= 0.0:
		_param("origine", global_position)
		_param("temps", fmod(_anim, 600.0))
	if _sans:
		var H := _H
		var hauteur := maxf(4.0, float(_sq["corps"]["taille"].y))
		_param("onde", clampf(H * (0.1 + 0.16 * _marche) / hauteur, 0.0, 0.09))
		_param("onde_phase", fmod(_onde_phase, TAU * 100.0))


func _param(n: String, v) -> void:
	if _params.get(n) != v:
		_params[n] = v
		_mat.set_shader_parameter(n, v)


# --- la mort, la dissipation d'un écho ---

func _finir(delta: float) -> void:
	if _dissipe >= 0.0:
		_dissipe += delta
		modulate.a = maxf(0.0, modulate.a - delta * 2.2)
		if _pivot != null:
			_pivot.scale *= 1.0 + delta * 0.8
			_param("temps", fmod(_anim + _dissipe * 3.0, 600.0))
		_anim += delta
		if _dissipe > 0.5:
			queue_free()
		_redessiner()
		return
	_mort += delta
	# elle tombe (_corps, _pas_des_pattes) : lentement d'abord, puis vite ; un rebond quand elle touche le sol
	var t := clampf(_mort / CHUTE, 0.0, 1.0)
	if t >= 1.0 and not _impact:
		_impact = true
		_ressort_v -= 0.12 * lerpf(22.0, 13.0, _poids)
		_q_av -= 4.0
	_vit = Vector2.ZERO
	_marche = 0.0
	_bond = 0.0
	_course = 0.0
	_affut = 0.0
	_animer(delta)
	# puis son encre s'efface (sur un téléphone : un fondu)
	var ef := clampf((_mort - CHUTE - GISANT) / EFFACEMENT, 0.0, 1.0)
	if _fin:
		_param("dissolution", ef)
	else:
		modulate.a = 1.0 - ef
	if _mort > CHUTE + GISANT + EFFACEMENT:
		queue_free()
	_redessiner()


func _redessiner() -> void:
	if not _a_l_ecran:
		return
	queue_redraw()
	if _loin != null:
		_loin.queue_redraw()
		_pres.queue_redraw()
	if _traine != null:
		_traine.queue_redraw()
	# (la barre, la paupière, les miettes : seulement quand elles se voient, et une image de plus pour les effacer)
	if _haut != null and (_haut_sale or _depuis_coup < BARRE + 0.1 or _mort >= 0.0 or _cligne >= 0.0 or _derobe > 0.0):
		_haut.queue_redraw()


# --- ce qui se dessine ---

func _peindre_loin(c: CanvasItem) -> void:
	_peindre_pattes(c, true)


func _peindre_pres(c: CanvasItem) -> void:
	_peindre_pattes(c, false)


func _peindre_pattes(c: CanvasItem, loin: bool) -> void:
	var atlas: Texture2D = _sq["atlas"]
	var pattes: Array = _sq["pattes"]
	var demi := Vector2(0.5, 0.5)
	for i in pattes.size():
		if _p_loin[i] != loin:
			continue
		var p: Dictionary = pattes[i]
		var j: PackedVector2Array = _pieds[i]
		var cel: Array = p["cellules"]
		# (le bas de la patte, un peu allongé ou tassé pour que le pied tienne au sol)
		var bas := Vector2(0.5 * _p_etire[i], 0.5)
		for s in cel.size():
			var a := j[s]
			c.draw_set_transform(a, (j[s + 1] - a).angle(), demi if s == 0 else bas)
			c.draw_texture_rect_region(atlas, Rect2(-cel[s]["debut"], cel[s]["region"].size), cel[s]["region"])
		var pied: Dictionary = p["pied"]
		if not pied.is_empty():
			c.draw_set_transform(j[j.size() - 1], _rot_pieds[i], demi)
			c.draw_texture_rect_region(atlas, Rect2(-pied["ancre"], pied["region"].size), pied["region"])
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# la traîne d'un écho : son corps, là où il était, qui se défait
func _peindre_traine(c: CanvasItem) -> void:
	if _pivot == null:
		return
	var corps: Dictionary = _sq["corps"]
	var n := _sillage.size()
	for i in n:
		var k := float(i + 1) / float(n + 1)
		var off := _sillage[n - 1 - i] - position
		var s := 1.0 + 0.1 * k
		# (la traîne monte, comme une fumée)
		c.draw_set_transform(off + Vector2(0.0, -_leve - k * float(_sq["jambe"]) * 0.5), 0.0, Vector2(_pivot.scale.x * s, s))
		c.draw_texture_rect(corps["tex"], Rect2(corps["pos"], corps["taille"]), false, Color(1.0, 1.0, 1.0, 0.34 * (1.0 - k)))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# au-dessus de tout : la barre de vie, un moment après un coup ; la paupière, le temps d'un clignement ; les miettes d'encre
# d'une bête qui s'efface. Rien n'y est dessiné le reste du temps.
func _peindre_haut(c: CanvasItem) -> void:
	_haut_sale = false
	var a := 1.0 - smoothstep(BARRE - 0.7, BARRE, _depuis_coup)
	if a > 0.0 and pv > 0.0 and pv < pv_max and _mort < 0.0:
		_haut_sale = true
		var w := clampf(largeur * 0.5, 14.0, 44.0)
		var y: float = float(_sq.get("haut", -largeur * 0.6)) - 5.0
		var g := Vector2(-w * 0.5, y)
		c.draw_line(g, g + Vector2(w, 0.0), Color(P.PAPIER, 0.42 * a), 2.6, true)
		c.draw_line(g, g + Vector2(w * pv / pv_max, 0.0), Color(P.ENCRE, 0.92 * a), 1.3, true)
	var ef := clampf((_mort - CHUTE - GISANT) / EFFACEMENT, 0.0, 1.0) if _mort >= 0.0 else 0.0
	var ferme := 1.0 - paupiere()
	if ferme > 0.03 and _a_oeil and role != "echo" and _pivot != null and absf(_pivot.scale.x) > 0.5 and ef < 0.3:
		_haut_sale = true
		_peindre_paupiere(c, ferme, 1.0 - ef / 0.3)
	if _mort > CHUTE + GISANT and _fin and not _miettes.is_empty():
		_haut_sale = true
		var ctr: Vector2 = _pivot.transform * (_t_corps * Vector2(_sq["centre"]))
		var r := Vector2(largeur * 0.32, largeur * 0.12)
		var encre := robe.darkened(0.6)
		for m in _miettes:
			var age: float = (ef - m.z * 0.6) / 0.4
			if age <= 0.0 or age >= 1.0:
				continue
			var q: Vector2 = ctr + Vector2(m.x * r.x, m.y * r.y) + Vector2(m.x * 3.0, -largeur * 0.25) * age
			c.draw_circle(q, 0.55 + 0.5 * (1.0 - age), Color(encre, 0.8 * sin(PI * age)))


# la paupière : la peau descend sur l'œil (et monte d'en dessous), son bord est un trait d'encre ; fermée, il ne reste que ce
# trait, un peu courbe. Des traits seulement : un seul appel de dessin, et seulement le temps du clignement.
func _peindre_paupiere(c: CanvasItem, ferme: float, alpha: float) -> void:
	var t := _pivot.transform * (_t_corps * _t_tete)
	var o := t * _oeil_local
	var ax := t.basis_xform(Vector2.RIGHT).normalized()
	var bas := t.basis_xform(Vector2.DOWN).normalized()
	var r := _oeil_rayon * 1.04
	var peau := Color(robe.lerp(P.ENCRE, 0.2), alpha)
	var encre := Color(P.ENCRE, alpha)
	# (les deux paupières se rejoignent un peu sous le milieu de l'œil)
	var joint := r * 0.25
	var y_haut := lerpf(-r, joint, ferme)
	var y_bas := lerpf(r, joint, ferme)
	for k in 3:
		var y0 := lerpf(-r, y_haut, float(k) / 3.0)
		var y1 := lerpf(-r, y_haut, float(k + 1) / 3.0)
		var ym := (y0 + y1) * 0.5
		var demi := sqrt(maxf(r * r - ym * ym, 0.0))
		if y1 - y0 > 0.02 and demi > 0.05:
			c.draw_line(o + bas * ym - ax * demi, o + bas * ym + ax * demi, peau, y1 - y0 + 0.25)
	if r - y_bas > 0.05:
		var ym2 := (r + y_bas) * 0.5
		var demi2 := sqrt(maxf(r * r - ym2 * ym2, 0.0))
		c.draw_line(o + bas * ym2 - ax * demi2, o + bas * ym2 + ax * demi2, peau, r - y_bas + 0.25)
	# le bord de la paupière : un trait d'encre, qui se creuse quand l'œil se ferme
	var demi3 := sqrt(maxf(r * r - y_haut * y_haut, 0.0)) * lerpf(1.0, 1.12, ferme)
	var creux := r * 0.22 * ferme
	var gros := maxf(0.55, r * 0.3)
	var p0 := o + bas * (y_haut - creux) - ax * demi3
	var p1 := o + bas * (y_haut + creux * 0.6)
	var p2 := o + bas * (y_haut - creux) + ax * demi3
	c.draw_line(p0, p1, encre, gros)
	c.draw_line(p1, p2, encre, gros)


func _draw() -> void:
	if _pivot != null:
		if role == "echo":
			return
		# l'ombre de contact : sous le corps, plus petite quand il se lève, couchée avec lui quand il tombe
		var rx: float = _sq["ombre"]
		var cx: float = float(_sq["ombre_x"]) * _pivot.scale.x + _recul.x
		var H := _H
		var leve := clampf(_leve / maxf(H, 1.0), 0.0, 1.5)
		var a := 1.0 - 0.45 * leve
		var w := rx * (1.0 - 0.3 * leve)
		if _mort >= 0.0:
			var t := clampf(_mort / CHUTE, 0.0, 1.0)
			var ctr: Vector2 = _pivot.transform * (_t_corps * Vector2(_sq["centre"]))
			cx = lerpf(cx, ctr.x, t)
			w = lerpf(w, rx * 0.8, t)
			a *= 1.0 - clampf((_mort - CHUTE - GISANT) / EFFACEMENT, 0.0, 1.0)
		var h := w * 0.24 + 0.6
		draw_texture_rect(_penombre(), Rect2(cx - w, 0.8 - h, 2.0 * w, 2.0 * h), false, Color(1.0, 1.0, 1.0, 0.34 * a))
		return
	_ellipse(Vector2(0, 1), largeur * 0.36, largeur * 0.09, Color(0, 0, 0, 0.25))
	# (pas de planche pour cette lignée : une silhouette simple, à sa taille et dans sa robe)
	var k := largeur
	var s := regard
	var b := -absf(sin(_t * 9.0)) * 1.5 if etat != "repos" else 0.0
	_ellipse(Vector2(0, -k * 0.3 + b), k * 0.4, k * 0.19, robe)
	draw_circle(Vector2(s * k * 0.42, -k * 0.42 + b), k * 0.13, robe.darkened(0.15))
	for x in [-0.25, -0.12, 0.15, 0.27]:
		draw_line(Vector2(x * k, -k * 0.18 + b), Vector2(x * k, 0), robe.darkened(0.35), maxf(1.5, k * 0.05))


func _process_sillage(delta: float) -> void:
	_sillage_t -= delta
	if _sillage_t <= 0.0:
		_sillage_t = 0.08
		_sillage.append(position)
		var n := 5 if _fin else 3
		while _sillage.size() > n:
			_sillage.remove_at(0)


# une pénombre ronde, d'encre, plus dense au milieu (une seule pour toutes les bêtes)
static func _penombre() -> ImageTexture:
	if _ombre_tex == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0).length()
				var a := pow(clampf(1.0 - r, 0.0, 1.0), 1.4)
				img.set_pixel(x, y, Color(P.ENCRE, a))
		_ombre_tex = ImageTexture.create_from_image(img)
	return _ombre_tex


func _ellipse(c: Vector2, rx: float, ry: float, couleur: Color) -> void:
	if _cercle.is_empty():
		for i in 20:
			_cercle.append(Vector2.from_angle(TAU * i / 20.0))
	draw_set_transform(c, 0.0, Vector2(rx, ry))
	draw_colored_polygon(_cercle, couleur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
