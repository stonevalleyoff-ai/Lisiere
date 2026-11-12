extends RefCounted
# Lisière — le son du temps qu'il fait (scripts/sons_temps.gd)
# Ce que le temps fait entendre, et ce qu'il fait à la veilleuse (scripts/climat.gd, scripts/incendie.gd) :
#  - la pluie : un voile qui grossit du crachin à l'averse (pluie_drue), des gouttes claires par-dessus (pluie_fine) ; sous un
#    feuillage le voile s'éloigne et s'assourdit, et l'on entend les gouttes tomber des feuilles (pluie_feuilles ; elles gouttent
#    encore un moment après l'averse) ; les pieds dans l'eau, tout est plus mat, et les gouttes y font des bulles (pluie_eau) ;
#  - la foudre : son présage (l'air grésille, là d'où elle viendra), puis le claquement si elle tombe près, et le roulement,
#    qui arrive d'autant plus tard, plus faible et plus sourd qu'elle est loin ; aucun coup ne sonne comme le précédent ;
#  - l'incendie : le ronflement des foyers (leur nombre, leur distance, d'où ils sont), leurs crépitements, le bois qui éclate ;
#    ce qui s'embrase, ce que la pluie éteint (la vapeur), ce qui tombe en cendres ;
#  - le corps : elle prend feu (ça crépite sur elle, elle crie à peine), l'eau l'éteint, elle grelotte ;
#  - et ce qui se tait : les oiseaux, les grillons sous la pluie, tout sous la neige, la musique sous l'orage (sons.gd lit ici
#    sec, etouffe, orage, vent, chaleur, musique_db, braise).
# sons.gd l'appelle à chaque image (maj), lui demande le sol sous chaque pas (sol), et le branche sur les signaux du climat et
# de l'incendie au début d'une partie (nouvelle_partie). Rien ne se fabrique ici : tout passe par les voix et les couches de
# sons.gd, et tous ces sons sont dans sa file (sur un téléphone, ils sont prêts avant la partie).

const R := preload("res://scripts/regles.gd")
const SON := 650.0        # la vitesse du son, en pixels par seconde : le tonnerre d'une foudre lointaine arrive en retard
const PORTEE := 1000.0    # jusqu'où s'entend un arbre en feu
# ce qui brûle : sa taille à l'oreille, et la hauteur de ce qu'on entend quand il s'embrase, s'éteint ou tombe
const TAILLE := {"arbre": 1.0, "sapin": 1.0, "buisson": 0.6, "souche": 0.45, "touffe": 0.3}
const HAUTEUR := {"arbre": 0.74, "sapin": 0.8, "buisson": 1.0, "souche": 0.92, "touffe": 1.3}

var s                       # le nœud des sons
# ce que sons.gd lit
var pluie := 0.0
var orage := 0.0
var vent := 0.12
var chaleur := 0.0          # la canicule, de 0 à 1
var sec := 1.0              # 1 : les bêtes chantent ; 0 : la pluie, l'orage les ont fait taire
var etouffe := 0.0          # la neige (tombée, qui tombe), le brouillard : de 0 à 1
var musique_db := 0.0       # ce que l'orage retire à la musique
var braise := 0.0           # ce que l'incendie (ou la veilleuse en feu) demande à la couche des braises
var image_foudre := -1      # l'image où la foudre est tombée (sons.gd y tait le « coup » que le jeu joue encore)

var _r := RandomNumberGenerator.new()
var _jeu
var _sens := 0.0            # avant de regarder de nouveau où est la veilleuse (un abri, de l'eau)
var _abri_vu := 0.0
var _eau_vue := 0.0
var _abri := 0.0
var _eau := 0.0
var _feuilles := 0.0        # ce que les feuillages gardent de la dernière pluie
var _tu_fort := false
var _eclaircie := false
var _en_feu := false
var _frisson := 0.0
var _grain := 0.0
var _craque := 1.0
var _sur_elle := 0.0
var _vu := {"presage": -9.0, "foudre": -9.0, "pris": -9.0, "fini": -9.0}   # la dernière fois, à l'horloge des sons


func _init(sons) -> void:
	s = sons
	_r.randomize()


# une partie commence : on se branche sur le ciel et sur l'incendie (une fois : ils restent d'une partie à l'autre)
func nouvelle_partie(jeu) -> void:
	_jeu = jeu
	_relier(jeu.get("climat"), "presage", _presage)
	_relier(jeu.get("climat"), "foudre", _foudre)
	_relier(jeu.get("climat"), "change", _change)
	_relier(jeu.get("incendie"), "pris", _pris)
	_relier(jeu.get("incendie"), "fini", _fini)
	_oublier()


func taire() -> void:
	_jeu = null
	_oublier()


func _relier(qui, nom: String, quoi: Callable) -> void:
	if qui != null and qui.has_signal(nom) and not qui.is_connected(nom, quoi):
		qui.connect(nom, quoi)


func _oublier() -> void:
	pluie = 0.0
	orage = 0.0
	vent = 0.12
	chaleur = 0.0
	sec = 1.0
	etouffe = 0.0
	musique_db = 0.0
	braise = 0.0
	_sens = 0.0
	_abri = 0.0
	_eau = 0.0
	_abri_vu = 0.0
	_eau_vue = 0.0
	_feuilles = 0.0
	_tu_fort = false
	_eclaircie = false
	_en_feu = false
	_frisson = 0.8
	for k in _vu:
		_vu[k] = -9.0


# la pluie vient de cesser (une fois) : les oiseaux reviennent
func eclaircie() -> bool:
	var e := _eclaircie
	_eclaircie = false
	return e


# --- chaque image ---

func maj(jeu, j, dt: float, morte: bool, comble: float) -> void:
	var C = jeu.get("climat")
	if C == null:
		return
	var p: Vector2 = j.position
	# où elle est, huit fois par seconde (l'abri cherche les arbres autour d'elle) ; lissé, pour qu'un feuillage ne claque pas
	_sens -= dt
	if _sens <= 0.0:
		_sens = 0.12
		_abri_vu = float(C.abri(p))
		_eau_vue = float(C.eau(p))
	_abri = lerpf(_abri, _abri_vu, 1.0 - exp(-dt * 6.0))
	_eau = lerpf(_eau, _eau_vue, 1.0 - exp(-dt * 5.0))
	pluie = C.pluie
	orage = C.orage
	vent = C.vent
	chaleur = clampf(float(C.chaleur) / 0.2, 0.0, 1.0)
	etouffe = clampf(0.85 * smoothstep(0.15, 0.7, float(C.neige_sol)) + 0.4 * float(C.neige) + 0.3 * float(C.brouillard), 0.0, 1.0)
	# ce qui se tait : vite quand la pluie vient, lentement quand elle s'en va ; puis l'éclaircie
	var mouille := maxf(smoothstep(0.06, 0.3, pluie), smoothstep(0.1, 0.4, orage))
	var tu := 1.0 - sec
	tu = lerpf(tu, mouille, 1.0 - exp(-dt / (1.5 if mouille > tu else 7.0)))
	sec = 1.0 - tu
	if tu > 0.8:
		_tu_fort = true
	elif tu < 0.45 and _tu_fort:
		_tu_fort = false
		_eclaircie = true
	musique_db = -10.0 * smoothstep(0.2, 0.7, orage) - 3.0 * smoothstep(0.5, 1.0, pluie)
	var k := (0.0 if morte else 1.0) * (1.0 - 0.5 * comble)
	_pluie(dt, k)
	_incendie(jeu, j, dt, k)
	_corps(j, dt, C, k)


# la pluie : son voile, ses gouttes, ce qu'un feuillage et l'eau en font
func _pluie(dt: float, k: float) -> void:
	var L: Dictionary = s._couches
	var bain := smoothstep(0.05, 0.3, _eau)
	# le voile : il grossit et s'épaissit avec la pluie ; sous un feuillage il s'éloigne, plus sourd ; dans l'eau, plus mat
	L["pluie_drue"].cible = pow(pluie, 1.2) * (1.0 - 0.6 * _abri) * (1.0 - 0.3 * bain) * k if pluie > 0.015 else 0.0
	L["pluie_drue"].hauteur = (1.12 - 0.18 * pluie) * (1.0 - 0.2 * _abri) * (1.0 - 0.12 * bain)
	# les gouttes claires : celles du crachin et de la pluie ; l'averse les couvre à moitié
	L["pluie_fine"].cible = smoothstep(0.02, 0.2, pluie) * (1.0 - 0.5 * smoothstep(0.5, 1.0, pluie)) * (1.0 - 0.8 * _abri) * (1.0 - 0.6 * bain) * k
	L["pluie_fine"].hauteur = 0.9 + 0.25 * pluie
	# sous un feuillage : les gouttes tombent des feuilles, une à une ; elles gouttent encore un moment après l'averse
	_feuilles = lerpf(_feuilles, 1.0 if pluie > 0.05 else 0.0, 1.0 - exp(-dt / (6.0 if pluie > 0.05 else 30.0)))
	var gouttes := maxf(pow(smoothstep(0.03, 0.4, pluie), 0.5), 0.45 * _feuilles)
	L["pluie_feuilles"].cible = _abri * gouttes * k
	L["pluie_feuilles"].hauteur = 0.62 + 0.2 * _feuilles + 0.3 * pluie
	# les pieds dans l'eau : les gouttes y font des bulles
	L["pluie_eau"].cible = bain * pow(smoothstep(0.03, 0.5, pluie), 0.6) * (1.0 - 0.6 * _abri) * k
	L["pluie_eau"].hauteur = 0.9 + 0.2 * pluie


# --- la foudre ---

func _ici() -> bool:
	return s._joueur != null and is_instance_valid(s._joueur) and s._mort < 0.0


# pas deux fois le même son coup sur coup (l'essai fait tomber quatre-vingts éclairs dans la même image)
func _trop_tot(quoi: String, ecart: float) -> bool:
	if s._horloge - float(_vu[quoi]) < ecart:
		return true
	_vu[quoi] = s._horloge
	return false


# elle va tomber en p : l'air se charge et grésille, de ce côté-là, d'autant plus fort qu'elle sera près
func _presage(p: Vector2, _dans: float) -> void:
	if not _ici() or _trop_tot("presage", 0.2):
		return
	var d: float = p.distance_to(s._joueur.position)
	if d > 1100.0:
		return
	var pres := 1.0 - d / 1100.0
	s._son("presage", lerpf(-26.0, -5.0, pres * pres), _r.randf_range(0.97, 1.04), s.pan_de(p), 0.0, s.B_MONDE, not s.mobile)


# elle tombe en p. Près : le claquement, sec, tout de suite, puis le roulement. Plus loin : le claquement vient en retard, plus
# faible et plus sourd ; au loin il n'y a plus que le roulement, longtemps après l'éclair
func _foudre(p: Vector2, _sur) -> void:
	image_foudre = Engine.get_process_frames()
	if not _ici() or _trop_tot("foudre", 0.35):
		return
	var d: float = p.distance_to(s._joueur.position)
	var pan: float = s.pan_de(p)
	var retard := maxf(0.0, d - 120.0) / SON
	if d < 800.0:
		var pres := 1.0 - d / 800.0
		_plus_tard(retard, "foudre%d" % (_r.randi() % 2), lerpf(-22.0, -3.0, pow(pres, 1.3)), lerpf(0.72, 1.0, pres) * _r.randf_range(0.9, 1.12),
			s.B_PEUR if d < 150.0 else s.B_MONDE, pan)
	# (le roulement : deux façons de rouler de près, une de loin ; chaque coup à sa hauteur, donc à sa longueur)
	var loin := smoothstep(300.0, 1300.0, d)
	var nom := "tonnerre2" if d > 750.0 else "tonnerre%d" % (_r.randi() % 2)
	_plus_tard(retard + 0.05, nom, -6.0 - 11.0 * smoothstep(100.0, 1500.0, d), lerpf(1.0, 0.8, loin) * _r.randf_range(0.82, 1.18), s.B_MONDE, pan * 0.7)


# le temps change : l'orage s'annonce, de loin
func _change(nom: String) -> void:
	if nom == "orage" and _ici():
		_plus_tard(0.8, "tonnerre2", -15.0, _r.randf_range(0.8, 1.0), s.B_MONDE, _r.randf_range(-0.5, 0.5))


func _plus_tard(attente: float, nom: String, vol: float, hauteur: float, bus: String, pan: float) -> void:
	if attente < 0.03:
		s._son(nom, vol, hauteur, pan, 0.0, bus, not s.mobile)
	else:
		s._plus_tard.append([attente, nom, vol, hauteur, bus, pan])


# --- l'incendie ---

# un objet s'embrase : le souffle d'un feu qui prend, d'autant plus grave que ce qui brûle est grand
func _pris(o) -> void:
	if not _ici() or not is_instance_valid(o) or _trop_tot("pris", 0.35):
		return
	var d: float = o.position.distance_to(s._joueur.position)
	if d > 900.0:
		return
	var pres := 1.0 - d / 900.0
	var genre: String = o.genre
	s._son("allume", lerpf(-28.0, -3.0, pres * pres) + linear_to_db(float(TAILLE.get(genre, 0.5))) * 0.5, float(HAUTEUR.get(genre, 1.0)) * _r.randf_range(0.93, 1.07),
		s.pan_de(o.position), 0.0, s.B_MONDE, false)


# il ne brûle plus : la pluie l'a éteint (un sifflement de vapeur), ou il a brûlé jusqu'au bout (un arbre tombe en cendres)
func _fini(o, brule: bool) -> void:
	if not _ici() or not is_instance_valid(o) or _trop_tot("fini", 0.4):
		return
	var d: float = o.position.distance_to(s._joueur.position)
	if d > 900.0:
		return
	var pres := 1.0 - d / 900.0
	var genre: String = o.genre
	var h: float = float(HAUTEUR.get(genre, 1.0)) * _r.randf_range(0.93, 1.07)
	var taille: float = linear_to_db(float(TAILLE.get(genre, 0.5))) * 0.5
	var pan: float = s.pan_de(o.position)
	if not brule:
		s._son("vapeur", lerpf(-30.0, -7.0, pres * pres) + taille, h * 1.1, pan, 0.0, s.B_MONDE, false)
	elif genre == "arbre" or genre == "sapin" or genre == "souche":
		s._son("effondre", lerpf(-28.0, -5.0, pres * pres), h * 1.2, pan, 0.0, s.B_MONDE, false)
	else:
		s._son("eteint", lerpf(-30.0, -10.0, pres * pres), 1.25, pan, 0.0, s.B_MONDE, false)


# les foyers : un ronflement (plus fort, plus aigu de près et quand ils sont nombreux), placé vers eux ; des crépitements et du
# bois qui éclate, là où est l'un d'eux, tiré au sort à chaque image (d'autant plus souvent qu'il s'entend)
func _incendie(jeu, j, dt: float, k: float) -> void:
	var I = jeu.get("incendie")
	var p: Vector2 = j.position
	var somme := 0.0
	var proche := 0.0
	var pan := 0.0
	var tire = null
	var tire_a := 0.0
	if I != null and k > 0.0:
		for f in I.foyers:
			if not f.allume():
				continue
			var d: float = p.distance_to(f.position)
			if d >= PORTEE:
				continue
			var a: float = float(TAILLE.get(f.objet.genre, 0.5)) * pow(1.0 - d / PORTEE, 1.8)
			somme += a
			pan += a * float(s.pan_de(f.position))
			proche = maxf(proche, a)
			if _r.randf() * somme < a:
				tire = f
				tire_a = a
	var c = s._couches["brasier"]
	c.cible = (1.0 - exp(-1.5 * somme)) * k
	c.hauteur = 0.88 + 0.22 * proche + float(s._flamme)
	if somme > 0.001:
		c.pan = pan / somme
	# elle brûle : ça crépite sur elle
	var en_feu: bool = j.en_feu > 0.0 and k > 0.0
	braise = maxf(clampf((proche - 0.3) * 1.6, 0.0, 1.0), 0.8 if en_feu else 0.0) * k
	var leger := 0.55 if s.mobile else 1.0
	if en_feu:
		_sur_elle -= dt
		while _sur_elle <= 0.0:
			_sur_elle += -log(maxf(_r.randf(), 0.0001)) / (12.0 * leger)
			s._son("braise%d" % (_r.randi() % 8), _r.randf_range(-17.0, -7.0), _r.randf_range(0.9, 1.6), 0.0, 0.0, s.B_MONDE, false)
	if tire == null or proche < 0.1:
		return
	# (les aigus se perdent avec la distance : les crépitements faiblissent plus vite que le ronflement)
	var db := linear_to_db(tire_a) * 1.4 + linear_to_db(k)
	var pan_f: float = s.pan_de(tire.position)
	var foule := minf(1.0, somme)
	_grain -= dt
	while _grain <= 0.0:
		_grain += -log(maxf(_r.randf(), 0.0001)) / ((5.0 + 13.0 * foule) * leger)
		var v := db + _r.randf_range(-22.0, -9.0)
		if v > -48.0:
			s._son("braise%d" % (_r.randi() % 8), v, _r.randf_range(0.55, 1.15), clampf(pan_f + _r.randf_range(-0.12, 0.12), -1.0, 1.0), 0.0, s.B_MONDE, false)
	_craque -= dt
	if _craque <= 0.0:
		_craque = -log(maxf(_r.randf(), 0.0001)) / ((0.3 + 1.5 * foule) * leger)
		if _r.randf() < 0.65:
			s._son("craque%d" % (_r.randi() % 2), db + _r.randf_range(-10.0, -3.0), _r.randf_range(0.75, 1.2), pan_f, 0.0, s.B_MONDE, false)
		else:
			s._son("pop%d" % (_r.randi() % 3), db + _r.randf_range(-9.0, -3.0), _r.randf_range(0.6, 0.9), pan_f, 0.0, s.B_MONDE, false)


# --- le corps ---

# elle prend feu (le souffle des flammes, l'air happé, à peine un cri), l'eau l'éteint (la vapeur) ; elle a froid (un souffle
# qui tremble, de loin en loin, d'autant plus près et plus fort qu'elle gèle)
func _corps(j, dt: float, C, k: float) -> void:
	var en_feu: bool = j.en_feu > 0.0
	if k > 0.0 and en_feu and not _en_feu:
		s._son("allume", -7.0, 1.4, 0.0, 0.0, s.B_MONDE, false)
		s._son("cri", -12.0, _r.randf_range(0.96, 1.06), 0.0, 0.0, s.B_PEUR, false)
	elif k > 0.0 and _en_feu and not en_feu:
		if float(C.eau(j.position)) > 0.3:
			s._son("vapeur", -5.0, 1.12, 0.0, 0.0, s.B_MONDE, false)
		else:
			s._son("eteint", -9.0, 1.25, 0.0, 0.0, s.B_MONDE, false)
	_en_feu = en_feu
	var froid := clampf((R.FROID - float(j.temperature)) / R.FROID, 0.0, 1.0)
	if froid <= 0.0 or en_feu or k <= 0.0:
		_frisson = minf(_frisson, 0.8)
		return
	_frisson -= dt
	if _frisson <= 0.0:
		_frisson = _r.randf_range(3.0, 5.5) * (1.0 - 0.4 * froid)
		s._son("frisson", lerpf(-25.0, -17.0, froid), _r.randf_range(0.94, 1.08), 0.0, 0.0, s.B_MONDE, false)


# --- le sol ---

# le sol sous un pas, en p : [la boue (de 0 à 1 : son épaisseur, flaques comprises), l'eau (sa profondeur), la neige tombée]
func sol(p: Vector2) -> Array:
	if _jeu == null or not is_instance_valid(_jeu):
		return [0.0, 0.0, 0.0]
	var C = _jeu.get("climat")
	if C == null:
		return [0.0, 0.0, 0.0]
	var eau: float = C.eau(p)
	var neige: float = C.neige_sol
	var boue: float = C.boue
	if boue > 0.02 and eau <= 0.0 and neige <= 0.2:
		# (dans ses flaques la boue est plus épaisse : c'est l'allure de la marche qui le dit)
		boue = clampf((1.0 - float(C.allure(p))) / R.BOUE_FREIN, 0.0, 1.0)
	else:
		boue *= 0.75
	return [boue, eau, neige]
