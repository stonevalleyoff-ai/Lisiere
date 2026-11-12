extends Node2D
# Lisière — le temps qu'il fait (scripts/ciel.gd)
# Le temps du lieu dans le monde d'Orvane, ce cycle (docs/45) : la pluie, l'orage, la tempête, la neige, le brouillard, dessinés
# par-dessus le lieu, devant la caméra. Un temps clair ou couvert ne dessine rien. Le vent couche la pluie.

var temps := ""
var vent := 0.0
# le temps qu'il fait pendant la partie (scripts/climat.gd) : s'il est là, le ciel le suit, force par force
var climat
var _t := 0.0
var _grains: Array = []
var _eclair := 0.0            # l'éclat de la foudre, qui retombe
var _vide := true


func regler(t: String, v: float) -> void:
	temps = t
	vent = v
	_grains.clear()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var n := 0
	match t:
		"pluie":
			n = 130
		"orage", "tempete":
			n = 220
		"neige":
			n = 150
	for i in n:
		_grains.append([r.randf(), r.randf(), r.randf_range(0.6, 1.4)])
	set_process(n > 0 or t == "brouillard")
	queue_redraw()


func visible_du_ciel() -> bool:
	return _grains.size() > 0 or temps == "brouillard"


func _ready() -> void:
	if climat != null:
		# (de quoi faire la pluie la plus drue ; on n'en dessine que ce qu'il tombe)
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 240:
			_grains.append([r.randf(), r.randf(), r.randf_range(0.6, 1.4)])
		climat.foudre.connect(func(_p, _sur): _eclair = 1.0)
		set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if climat == null:
		queue_redraw()
		return
	_eclair = maxf(0.0, _eclair - delta * 3.5)
	vent = climat.vent
	var rien: bool = climat.pluie < 0.03 and climat.neige < 0.03 and climat.brouillard < 0.03 and _eclair <= 0.0
	# (un ciel où rien ne tombe ne se redessine pas ; une fois de plus, pour s'effacer)
	if not rien or not _vide:
		queue_redraw()
	_vide = rien


func _draw() -> void:
	var s := get_viewport_rect().size
	if climat != null:
		_dessiner_climat(s)
		return
	if temps == "brouillard":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.78, 0.8, 0.82, 0.3))
		for i in 5:
			var y := s.y * (0.15 + 0.17 * i) + sin(_t * 0.3 + i) * 14.0
			draw_rect(Rect2(Vector2(0, y), Vector2(s.x, 46.0)), Color(0.85, 0.87, 0.88, 0.1))
		return
	if temps == "neige":
		for g in _grains:
			var x := fposmod(float(g[0]) * s.x + sin(_t * 1.2 + float(g[1]) * 30.0) * 18.0 + _t * 40.0 * vent, s.x)
			var y := fposmod(float(g[1]) * s.y + _t * 52.0 * float(g[2]), s.y)
			draw_circle(Vector2(x, y), 1.6 * float(g[2]), Color(0.95, 0.97, 1.0, 0.8))
		return
	# la pluie : des traits qui tombent, couchés par le vent ; plus serrés et plus sombres sous l'orage et la tempête
	var fort := temps == "orage" or temps == "tempete"
	var pente := 0.18 + 0.7 * vent + (0.35 if temps == "tempete" else 0.0)
	var vitesse := 620.0 if fort else 480.0
	if fort:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.07, 0.12, 0.16))
	for g in _grains:
		var y := fposmod(float(g[1]) * s.y + _t * vitesse * float(g[2]), s.y + 40.0) - 20.0
		var x := fposmod(float(g[0]) * (s.x + 200.0) + y * pente, s.x + 200.0) - 100.0
		draw_line(Vector2(x, y), Vector2(x + 14.0 * pente, y + 14.0), Color(0.72, 0.8, 0.9, 0.45), 1.2)


# le ciel de la partie : le brouillard, la neige, la pluie à leur force, l'ombre de l'orage, l'éclat de la foudre
func _dessiner_climat(s: Vector2) -> void:
	var b: float = climat.brouillard
	if b > 0.03:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.78, 0.8, 0.82, 0.3 * b))
		for i in 5:
			var y := s.y * (0.15 + 0.17 * i) + sin(_t * 0.3 + i) * 14.0
			draw_rect(Rect2(Vector2(0, y), Vector2(s.x, 46.0)), Color(0.85, 0.87, 0.88, 0.1 * b))
	var n: float = climat.neige
	if n > 0.03:
		for i in int(150.0 * n):
			var g: Array = _grains[i]
			var x := fposmod(float(g[0]) * s.x + sin(_t * 1.2 + float(g[1]) * 30.0) * 18.0 + _t * 40.0 * vent, s.x)
			var y := fposmod(float(g[1]) * s.y + _t * 52.0 * float(g[2]), s.y)
			draw_circle(Vector2(x, y), 1.6 * float(g[2]), Color(0.95, 0.97, 1.0, 0.8))
	var p: float = climat.pluie
	var o: float = climat.orage
	if o > 0.03:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.07, 0.12, 0.18 * o))
	if p > 0.03:
		var pente := 0.18 + 0.7 * vent
		var vitesse := lerpf(460.0, 640.0, p)
		for i in int(240.0 * p):
			var g: Array = _grains[i]
			var y := fposmod(float(g[1]) * s.y + _t * vitesse * float(g[2]), s.y + 40.0) - 20.0
			var x := fposmod(float(g[0]) * (s.x + 200.0) + y * pente, s.x + 200.0) - 100.0
			draw_line(Vector2(x, y), Vector2(x + 14.0 * pente, y + 14.0), Color(0.72, 0.8, 0.9, 0.45), 1.2)
	if _eclair > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.92, 0.95, 1.0, 0.55 * _eclair * _eclair))
