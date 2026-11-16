extends Node2D
# Lisière — un galet, tiré au lance-pierre (scripts/galet.gd)
# Il part de la main de la veilleuse, file vers ce qu'elle vise en montant un peu, et retombe ; son ombre court au sol sous
# lui. Il suit d'un rien la bête visée (elle a fait un pas pendant qu'il volait) ; arrivé, il le dit au jeu
# (scripts/principal.gd, galet_arrive), qui voit s'il a touché. Sur une bête, il s'arrête là (l'impact est celui du jeu).
# Dans l'herbe, il rebondit, roule un peu sur sa lancée, soulève trois miettes de terre, puis s'efface : rien à ramasser.
# Un seul nœud, dessiné sans l'ombre de la nuit (on suit son trait clair dans le noir ; la nuit, il est seulement plus
# terne), redessiné tant qu'il vole ou roule : une seconde au plus.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const PIERRE := Color("aaa395")
const ROULE := 0.5            # le temps qu'il roule
const RESTE := 0.45           # puis celui qu'il met à s'effacer

static var _clair: CanvasItemMaterial

var jeu
var cible = null              # la bête visée (null : droit devant)
var suit := true              # il suit d'un rien la bête visée ; pas dans le noir, où elle n'a visé que des yeux
var de := Vector2.ZERO        # d'où il est parti
var vers := Vector2.ZERO      # où il tombe
var _t := 0.0
var _duree := 0.3
var _haut := 0.0              # sa hauteur au-dessus du sol, cette image
var _main := 20.0             # la hauteur de la main qui l'a lâché
var _avant := Vector2.ZERO
var _avant_haut := 0.0
var _sol := -1.0              # depuis qu'il a touché l'herbe (-1 : il vole)
var _sens := Vector2.RIGHT
var _elan := 0.0
var _jour := 1.0
var _miettes := []            # la terre qu'il soulève : [vitesse, hauteur de départ]


# où l'on vise une bête : le milieu de son corps
static func vise(b) -> Vector2:
	return b.position + Vector2(0.0, -float(b.largeur) * 0.22)


func _ready() -> void:
	if _clair == null:
		_clair = CanvasItemMaterial.new()
		_clair.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _clair
	if jeu != null and jeu.has_method("lumiere_du_jour"):
		_jour = clampf(float(jeu.lumiere_du_jour()), 0.0, 1.0)


# depuis : au sol, sous la main qui le lâche (pour que le tri des profondeurs le range bien) ; hauteur : celle de cette main
func partir(depuis: Vector2, hauteur: float, jusqu_a: Vector2) -> void:
	_main = hauteur
	de = depuis
	vers = jusqu_a
	position = de
	_avant = de
	_duree = maxf(0.12, de.distance_to(vers) / R.VITESSE_GALET)
	_haut = _main
	_avant_haut = _main


func _process(delta: float) -> void:
	if jeu == null or jeu.en_pause:
		return
	if _sol >= 0.0:
		_rouler(delta)
		return
	_t += delta
	var k := clampf(_t / _duree, 0.0, 1.0)
	if suit and cible != null and is_instance_valid(cible) and cible.is_in_group("betes"):
		vers = vers.lerp(vise(cible), minf(1.0, delta * 5.0))
	_avant = position
	_avant_haut = _haut
	position = de.lerp(vers, k)
	# (tendu : il monte à peine, et descend de la hauteur de la main jusqu'à celle de ce qu'il vise)
	_haut = lerpf(_main, 8.0, k) + sin(k * PI) * minf(14.0, de.distance_to(vers) * 0.05)
	queue_redraw()
	if k >= 1.0:
		_arriver()


# arrivé : le jeu dit s'il a touché (la bête visée y laisse de sa vie) ; sinon il tombe dans l'herbe, et roule
func _arriver() -> void:
	var b = cible if cible != null and is_instance_valid(cible) else null
	var pv := float(b.pv) if b != null else -1.0
	jeu.galet_arrive(self)
	if b != null and (not is_instance_valid(b) or float(b.pv) < pv):
		set_process(false)
		queue_free()
		return
	_sol = 0.0
	_sens = (vers - de).normalized() if vers.distance_to(de) > 1.0 else Vector2.RIGHT
	_elan = 70.0
	if str(jeu.get("qualite")) != "mobile":
		for i in 3:
			_miettes.append([Vector2(_sens.x * randf_range(10.0, 34.0) + randf_range(-16.0, 16.0), randf_range(-58.0, -30.0)), randf_range(0.0, 2.0)])


func _rouler(delta: float) -> void:
	_sol += delta
	# (sa lancée s'use dans l'herbe ; deux petits bonds, de plus en plus bas)
	_elan = maxf(0.0, _elan - 150.0 * delta)
	position += Vector2(_sens.x, _sens.y * 0.6) * _elan * delta
	_haut = 5.0 * exp(-_sol * 7.0) * absf(cos(_sol * 17.0))
	queue_redraw()
	if _sol >= ROULE + RESTE:
		set_process(false)
		queue_free()


func _draw() -> void:
	var pierre := PIERRE.darkened(0.42 * (1.0 - _jour))
	var encre := Color(P.ENCRE, 0.9)
	if _sol >= 0.0:
		# dans l'herbe : il roule, s'arrête, s'efface ; la terre qu'il a soulevée retombe
		var a := 1.0 - smoothstep(ROULE, ROULE + RESTE, _sol)
		for m in _miettes:
			var u := _sol / 0.34
			if u >= 1.0:
				continue
			var v: Vector2 = m[0]
			# (là où il est tombé, pas là où il roule)
			var q := vers - position + Vector2(v.x * _sol, v.y * _sol + 190.0 * _sol * _sol - float(m[1]))
			draw_circle(q, 0.95 * (1.0 - 0.5 * u), Color(P.TERRE.darkened(0.25 + 0.3 * (1.0 - _jour)), 0.9 * (1.0 - u * u)))
		draw_circle(Vector2(0.0, 0.4), 1.9, Color(P.ENCRE, 0.2 * a))
		var la := Vector2(0.0, -_haut - 1.0)
		draw_circle(la, 1.9, Color(encre, encre.a * a))
		draw_circle(la, 1.3, Color(pierre, a))
		draw_circle(la + Vector2(-0.4, -0.4), 0.5, Color(pierre.lightened(0.3), a))
		return
	# en vol : son ombre, au sol ; lui, au-dessus, et le trait clair de sa course (large et pâle, puis fin et vif)
	draw_circle(Vector2.ZERO, 1.6, Color(P.ENCRE, 0.22 * _jour))
	var ici := Vector2(0.0, -_haut)
	var sillage := (_avant - position + Vector2(0.0, _haut - _avant_haut)).limit_length(20.0)
	var clair := P.IVOIRE.lerp(P.LUNE.lightened(0.45), 0.5 * (1.0 - _jour))
	draw_line(ici + sillage, ici, Color(clair, 0.2), 2.6, true)
	draw_line(ici + sillage * 0.7, ici, Color(clair, 0.5), 1.5, true)
	draw_line(ici + sillage * 0.35, ici, Color(clair, 0.9), 0.9, true)
	draw_circle(ici, 2.1, encre)
	draw_circle(ici, 1.5, pierre.lerp(clair, 0.25))
	draw_circle(ici + Vector2(-0.4, -0.5), 0.6, pierre.lightened(0.35))
