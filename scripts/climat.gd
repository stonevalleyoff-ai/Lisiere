extends Node
# Lisière — le temps qu'il fait pendant la partie (scripts/climat.gd)
# Le temps n'est plus un décor : il change pendant la partie, et il pèse. D'après le climat du lieu dans le monde d'Orvane (ses
# axes : l'humidité, la température), la saison, l'heure, et le temps du cycle quand le monde en a un (Orvane.meteo), des
# épisodes se suivent : un ciel clair, couvert, la pluie, l'orage, la neige, le brouillard, la canicule. Chacun monte et retombe
# en quelques secondes. De là :
#  - la pluie trempe la veilleuse (moins sous un feuillage), détrempe le sol (la boue, qui freine), puis fait monter l'eau dans
#    les creux du lieu (la crue : on y patauge, on y est trempée, un feu s'y noie) ;
#  - l'orage jette la foudre : un présage (le sol pâlit), puis elle tombe, sur un arbre le plus souvent. Elle blesse autour
#    d'elle (plus loin, les pieds dans l'eau), et met le feu (scripts/incendie.gd) ;
#  - l'air a une température (le lieu, la saison, la nuit, le temps) : le corps de la veilleuse la suit (principal.gd, _temps_du_corps).
# Tout ce qui se règle est dans scripts/regles.gd. Le hasard du temps est semé par la graine du lieu : une partie reprise
# retrouve son ciel.
#   jeu.climat.pluie, .orage, .neige, .brouillard, .vent (de 0 à 1), .air (de 0, glacial, à 1, brûlant), .temps (son nom)
#   jeu.climat.boue, .crue, .neige_sol (de 0 à 1) ; .eau(p) (la profondeur d'eau en p) ; .allure(p, masse) ; .abri(p)

signal change(temps: String)                 # le temps nommé vient de changer
signal presage(p: Vector2, dans: float)      # la foudre va tomber en p, dans « dans » secondes
signal foudre(p: Vector2, sur)               # elle tombe en p (sur : l'objet frappé, ou null)

const R := preload("res://scripts/regles.gd")
const DUREES := {"clair": [55.0, 110.0], "couvert": [30.0, 60.0], "pluie": [45.0, 90.0], "orage": [35.0, 70.0], "neige": [50.0, 100.0],
	"brouillard": [40.0, 80.0], "canicule": [60.0, 120.0]}

var jeu
var temps := "clair"
var pluie := 0.0
var orage := 0.0
var neige := 0.0
var brouillard := 0.0
var vent := 0.1
var vent_dir := Vector2.RIGHT
var chaleur := 0.0            # ce que l'épisode ajoute à l'air (la canicule), ou lui retire
var air := 0.5
var boue := 0.0
var crue := 0.0
var neige_sol := 0.0
# le climat du lieu : son humidité, sa température (les axes du biome), et ce que le monde dit du temps du cycle
var humide := 0.5
var tiede := 0.5
var du_monde := ""
var boue_fond := 0.0          # un lieu gorgé d'eau (un marais) n'est jamais tout à fait sec
var crue_fond := 0.0

var _r := RandomNumberGenerator.new()
var _force := 0.0             # la force de l'épisode en cours
var _reste := 0.0             # secondes avant le suivant
var _foudre_dans := 8.0
var _presages: Array = []     # [où, dans combien de temps, sur quoi]
var _relief := FastNoiseLite.new()
var _flaques := FastNoiseLite.new()


# le climat du lieu, au début d'une partie : graine, les axes du biome, la saison, le temps du cycle dans le monde (ou "")
func preparer(graine: int, axes: Dictionary, meteo: Dictionary) -> void:
	_r.seed = graine + 77
	_relief.seed = graine + 5
	_relief.frequency = 0.0017
	_relief.fractal_octaves = 2
	_flaques.seed = graine + 6
	_flaques.frequency = 0.011
	humide = clampf(float(axes.get("humidite", 0.5)), 0.0, 1.0)
	tiede = clampf(float(axes.get("temperature", 0.5)), 0.0, 1.0)
	du_monde = str(meteo.get("temps", ""))
	boue_fond = clampf((humide - 0.75) * 1.6, 0.0, 0.4)
	crue_fond = clampf((humide - 0.85) * 3.0, 0.0, 0.3)
	boue = maxf(boue_fond, float(meteo.get("eaux", 0.0)) * 0.5)
	crue = crue_fond
	neige_sol = clampf(float(meteo.get("neige", 0.0)), 0.0, 1.0)
	vent = clampf(0.1 + float(meteo.get("vent", 0.0)) * 0.6, 0.0, 1.0)
	vent_dir = Vector2.from_angle(_r.randf() * TAU)
	# (au réveil, un temps calme : de quoi ramasser du bois et faire un premier feu)
	temps = "couvert" if du_monde in ["pluie", "orage", "tempete", "neige", "brouillard", "couvert"] else "clair"
	_force = 0.0
	_reste = R.TEMPS_REPIT + _r.randf_range(0.0, 15.0)
	pluie = 0.0
	orage = 0.0
	neige = 0.0
	brouillard = 0.0
	chaleur = 0.0
	_presages.clear()
	_air(0.0)


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause or jeu.joueur == null:
		return
	avancer(delta)


# une image du temps (l'essai l'appelle aussi, pour faire passer le temps)
func avancer(delta: float) -> void:
	_reste -= delta
	if _reste <= 0.0:
		_suivant()
	# chaque force rejoint celle de l'épisode, en une douzaine de secondes
	var k := 1.0 - exp(-delta / 5.0)
	pluie = lerpf(pluie, _force * (1.0 if temps == "pluie" else (0.9 if temps == "orage" else 0.0)), k)
	orage = lerpf(orage, _force if temps == "orage" else 0.0, k)
	neige = lerpf(neige, _force if temps == "neige" else 0.0, k)
	brouillard = lerpf(brouillard, _force if temps == "brouillard" else 0.0, k)
	chaleur = lerpf(chaleur, 0.22 * _force if temps == "canicule" else 0.0, k)
	var vent_cible := 0.12
	match temps:
		"pluie":
			vent_cible = 0.3 + 0.3 * _force
		"orage":
			vent_cible = 0.5 + 0.4 * _force
		"neige":
			vent_cible = 0.25 + 0.3 * _force
	vent = lerpf(vent, vent_cible, k * 0.5)
	_air(delta)
	_sol(delta)
	_ciel(delta)


# l'épisode suivant, tiré d'après le climat du lieu ; le temps du cycle dans le monde, s'il y en a un, revient le plus souvent
func _suivant() -> void:
	var froid := _air_de_fond() < 0.3
	var poids := {
		"clair": 0.75 - 0.4 * humide,
		"couvert": 0.2,
		"pluie": 0.08 + 0.3 * humide,
		"orage": (0.02 + 0.14 * humide) * (0.5 + tiede),
		"brouillard": 0.03 + 0.06 * humide,
		"canicule": 0.2 if (tiede > 0.7 and humide < 0.4) else 0.0,
		"neige": 0.0,
	}
	if froid:
		# (dans le froid, l'eau tombe en neige, et l'orage ne se forme pas)
		poids["neige"] = poids["pluie"] + poids["orage"]
		poids["pluie"] = 0.0
		poids["orage"] = 0.0
	var m := du_monde
	if m == "tempete":
		m = "neige" if froid else "orage"
	elif m == "gel":
		m = "clair"
	if poids.has(m):
		poids[m] = float(poids[m]) * 4.0 + 0.3
	# (pas deux fois de suite le même temps : après l'orage, la pluie ou l'éclaircie)
	poids[temps] = float(poids[temps]) * (0.25 if temps != "clair" else 0.6)
	var total := 0.0
	for k in poids:
		total += float(poids[k])
	var tirage := _r.randf() * total
	var choisi := "clair"
	for k in poids:
		tirage -= float(poids[k])
		if tirage <= 0.0:
			choisi = k
			break
	_poser(choisi, _r.randf_range(0.5, 1.0), _r.randf_range(DUREES[choisi][0], DUREES[choisi][1]))


func _poser(nom: String, force: float, duree: float) -> void:
	var avant := temps
	temps = nom
	_force = force
	_reste = duree
	if nom == "orage":
		_foudre_dans = _r.randf_range(7.0, 12.0)
	if _r.randf() < 0.5:
		vent_dir = vent_dir.rotated(_r.randf_range(-0.8, 0.8))
	if nom != avant:
		change.emit(nom)


# (l'essai, la vitrine) ce temps-là, tout de suite et à cette force, pour cette durée ; ensuite le temps reprend son cours
func forcer(nom: String, force: float = 1.0, duree: float = 60.0, d_un_coup: bool = true) -> void:
	_poser(nom, force, duree)
	if d_un_coup:
		pluie = force * (1.0 if nom == "pluie" else (0.9 if nom == "orage" else 0.0))
		orage = force if nom == "orage" else 0.0
		neige = force if nom == "neige" else 0.0
		brouillard = force if nom == "brouillard" else 0.0
		chaleur = 0.22 * force if nom == "canicule" else 0.0
	_air(0.0)


# --- l'air ---

# la température de l'air sans le temps qu'il fait : le lieu, la saison, la nuit
func _air_de_fond() -> float:
	var a := tiede
	match str(jeu.saison) if jeu != null else "été":
		"été":
			a += 0.07
		"hiver":
			a -= 0.14
		"automne":
			a -= 0.04
	if jeu != null:
		a -= 0.13 * (1.0 - jeu.lumiere_du_jour())
	return a


func _air(_delta: float) -> void:
	air = clampf(_air_de_fond() - 0.07 * pluie - 0.05 * orage - 0.14 * neige - 0.05 * brouillard - 0.06 * neige_sol + chaleur, 0.0, 1.0)


# --- le sol ---

func _sol(delta: float) -> void:
	var soleil := 0.0
	if jeu != null and pluie < 0.05 and neige < 0.05:
		soleil = jeu.lumiere_du_jour() * (0.5 + air)
	if pluie > 0.05:
		boue = minf(1.0, boue + R.BOUE_MONTE * pluie * delta)
	else:
		boue = maxf(boue_fond, boue - R.BOUE_SECHE * (0.6 + soleil) * delta)
	# (l'eau monte quand le sol ne boit plus ; la neige qui fond la nourrit aussi)
	if pluie > 0.3 and boue > 0.9:
		crue = minf(1.0, crue + R.CRUE_MONTE * pluie * delta)
	else:
		crue = maxf(crue_fond, crue - R.CRUE_BAISSE * (0.7 + soleil) * delta)
	if neige > 0.05:
		neige_sol = minf(1.0, neige_sol + 0.012 * neige * delta)
	elif air > 0.3:
		neige_sol = maxf(0.0, neige_sol - 0.004 * (air - 0.2) * 4.0 * delta)


# le relief du lieu, de 0 (un creux) à 1 (une butte) : là où l'on s'éveille, c'est une butte
func relief(p: Vector2) -> float:
	return clampf(_relief.get_noise_2d(p.x, p.y) * 0.5 + 0.5 + 0.4 * exp(-p.length_squared() / (280.0 * 280.0)), 0.0, 1.0)


# la profondeur de l'eau en p, de 0 (au sec) à 1 (jusqu'aux genoux) : elle gagne d'abord les creux
func eau(p: Vector2) -> float:
	if crue <= 0.01:
		return 0.0
	var seuil := lerpf(0.26, 0.5, crue)
	return clampf((seuil - relief(p)) / 0.07, 0.0, 1.0) * minf(1.0, crue * 6.0)


# ce que le sol fait à la marche en p (1 : rien ; 0,4 au pire) : la boue (plus épaisse dans ses flaques), l'eau, la neige.
# Une bête légère s'y enfonce moins.
func allure(p: Vector2, masse: float = 60.0) -> float:
	var poids := clampf(0.55 + 0.45 * masse / 40.0, 0.55, 1.0)
	var a := 1.0
	if boue > 0.02:
		var flaque := clampf(_flaques.get_noise_2d(p.x, p.y) * 0.5 + 0.5, 0.0, 1.0)
		a *= 1.0 - R.BOUE_FREIN * boue * (0.55 + 0.45 * flaque) * poids
	var e := eau(p)
	if e > 0.0:
		a *= 1.0 - R.EAU_FREIN * e
	if neige_sol > 0.2:
		a *= 1.0 - R.NEIGE_FREIN * smoothstep(0.2, 0.6, neige_sol) * poids
	return maxf(a, 0.4)


# la veilleuse en p est-elle à l'abri de la pluie ? de 0 (à découvert) à 1 (sous le feuillage d'un arbre debout)
func abri(p: Vector2) -> float:
	if jeu == null or jeu.monde == null:
		return 0.0
	for o in jeu.monde.autour(p, 90.0):
		var c: float = o.couvert()
		if c > 0.0 and p.distance_to(o.position + Vector2(0.0, -4.0)) < c:
			return 1.0
	return 0.0


# --- la foudre ---

func _ciel(delta: float) -> void:
	# les présages mûrissent : la foudre tombe
	var i := 0
	while i < _presages.size():
		_presages[i][1] = float(_presages[i][1]) - delta
		if float(_presages[i][1]) <= 0.0:
			var q: Array = _presages[i]
			_presages.remove_at(i)
			_tomber(q[0], q[2])
		else:
			i += 1
	if orage < 0.25 or jeu == null or jeu.joueur == null:
		return
	_foudre_dans -= delta
	if _foudre_dans > 0.0:
		return
	_foudre_dans = lerpf(13.0, 5.0, orage) * _r.randf_range(0.7, 1.3)
	var j: Vector2 = jeu.joueur.position
	var tirage := _r.randf()
	if tirage < 0.6 and jeu.monde != null:
		# (elle cherche ce qui dépasse : un arbre debout, près de la veilleuse)
		var arbres := []
		for o in jeu.monde.autour(j, 520.0):
			if o.couvert() > 0.0:
				arbres.append(o)
		if not arbres.is_empty():
			var o = arbres[_r.randi() % arbres.size()]
			frapper(o.position, R.FOUDRE_ANNONCE, o)
			return
	if tirage < 0.85:
		# (ou la terre nue, pas trop près)
		var a := _r.randf() * TAU
		frapper(j + Vector2.from_angle(a) * _r.randf_range(110.0, 420.0), R.FOUDRE_ANNONCE)
	else:
		# (ou au loin : on la voit, on l'entend, elle ne touche rien)
		frapper(j + Vector2.from_angle(_r.randf() * TAU) * _r.randf_range(900.0, 1500.0), R.FOUDRE_ANNONCE)


# la foudre tombe en p (sur un objet, ou sur le sol), après son présage
func frapper(p: Vector2, annonce: float = 0.0, sur = null) -> void:
	if annonce > 0.0:
		_presages.append([p, annonce, sur])
		presage.emit(p, annonce)
	else:
		_tomber(p, sur)


func _tomber(p: Vector2, sur) -> void:
	if sur != null and not is_instance_valid(sur):
		sur = null
	foudre.emit(p, sur)
	if jeu != null and jeu.has_method("foudre_tombee"):
		jeu.foudre_tombee(p, sur)


# --- une partie gardée ---

func photo() -> Dictionary:
	return {"temps": temps, "force": snappedf(_force, 0.01), "reste": snappedf(_reste, 0.1), "pluie": snappedf(pluie, 0.01), "orage": snappedf(orage, 0.01),
		"neige": snappedf(neige, 0.01), "brouillard": snappedf(brouillard, 0.01), "vent": snappedf(vent, 0.01), "vent_dir": snappedf(vent_dir.angle(), 0.01),
		"boue": snappedf(boue, 0.01), "crue": snappedf(crue, 0.01), "neige_sol": snappedf(neige_sol, 0.01), "tirages": str(_r.state)}


func reprendre(d: Dictionary) -> void:
	if d.is_empty():
		return
	temps = str(d.get("temps", temps)) if DUREES.has(str(d.get("temps", temps))) else "clair"
	_force = float(d.get("force", 0.0))
	_reste = float(d.get("reste", 30.0))
	pluie = float(d.get("pluie", 0.0))
	orage = float(d.get("orage", 0.0))
	neige = float(d.get("neige", 0.0))
	brouillard = float(d.get("brouillard", 0.0))
	vent = float(d.get("vent", vent))
	vent_dir = Vector2.from_angle(float(d.get("vent_dir", 0.0)))
	boue = float(d.get("boue", boue))
	crue = float(d.get("crue", crue))
	neige_sol = float(d.get("neige_sol", neige_sol))
	if d.has("tirages"):
		_r.state = str(d["tirages"]).to_int()
	_air(0.0)
