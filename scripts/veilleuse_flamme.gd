extends Node2D
# Lisière — la flamme de la torche (scripts/veilleuse_flamme.gd)
# Quelques langues qui dansent l'une contre l'autre, un cœur presque blanc, une lueur douce, et des étincelles qui montent et
# restent en arrière quand la veilleuse marche. Elle s'ajoute à ce qui est dessous et ne prend pas l'ombre de la nuit : c'est
# une lumière. La veilleuse la pose au bout de sa torche ; sa lumière (le PointLight2D du joueur) suit son vacillement (vie).
# Les mêmes langues brûlent sur elle quand elle a pris feu (corps : là où elle brûle).
# Toutes les langues en un seul appel de dessin (la trace les recueille : scripts/interface_trace.gd).

const P := preload("res://scripts/palette.gd")
const Corps := preload("res://scripts/veilleuse_corps.gd")
const Trace := preload("res://scripts/interface_trace.gd")
const LANGUES := [[0.0, 1.0, 1.0, 0.0], [-1.3, 0.62, 0.8, 1.7], [1.25, 0.7, 0.78, 3.1], [0.2, 0.45, 0.6, 4.6]]

var force := 1.0              # 0 : éteinte ; 1 : pleine
var couche := Vector2.ZERO    # ce qui la couche : le vent, la marche (en pixels, au bout)
var vie := 0.0                # son vacillement, de -1 à 1
var mobile := false
# la veilleuse en feu : là où elle brûle ([où, dans ce nœud ; la taille de la flamme]) ; vide : la flamme d'une torche
var corps: Array = []
var _trace := Trace.new()
var _t := 0.0
var _braises: Array = []      # [position dans le monde, vitesse, âge, durée]
var _prochaine := 0.0
var _lechee := Vector3(0, 0, -1)   # une langue qui s'échappe : (x, y, âge)


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	_t = randf() * 10.0


static func _onde(t: float, k: float) -> float:
	return sin(t * 13.1 + k) * 0.5 + sin(t * 7.7 + k * 2.3) * 0.3 + sin(t * 23.3 + k * 3.7) * 0.2


func avancer(dt: float) -> void:
	_t += dt
	vie = _onde(_t, 0.0)
	# les étincelles : nées au bout, elles montent, dérivent, s'éteignent ; elles vivent dans le monde
	if not mobile and force > 0.3:
		_prochaine -= dt
		if _prochaine <= 0.0:
			_prochaine = randf_range(0.12, 0.34) / force
			var v := Vector2(randf_range(-10.0, 10.0) - couche.x * 2.0, randf_range(-38.0, -22.0))
			var d: Vector2 = corps[randi() % corps.size()][0] if not corps.is_empty() else Vector2.ZERO
			_braises.append([global_position + d + Vector2(randf_range(-1.5, 1.5), -6.0 * force), v, 0.0, randf_range(0.45, 0.9)])
	for b in _braises:
		b[2] += dt
		b[1] += Vector2(randf_range(-60.0, 60.0), -12.0) * dt
		b[0] += b[1] * dt
	_braises = _braises.filter(func(b): return b[2] < b[3])
	# une langue s'échappe du bout, de temps en temps
	if _lechee.z < 0.0 and force > 0.5 and randf() < dt * 2.2:
		_lechee = Vector3(couche.x * 0.8 + randf_range(-1.0, 1.0), -10.0 * force, 0.0)
	elif _lechee.z >= 0.0:
		_lechee.z += dt
		_lechee.y -= dt * 26.0
		_lechee.x += couche.x * dt * 2.0
		if _lechee.z > 0.22:
			_lechee.z = -1.0
	queue_redraw()


func _draw() -> void:
	_trace.commencer(self)
	for b in _braises:
		var u: float = b[2] / b[3]
		var c := P.BRAISE_COEUR.lerp(P.BRAISE_ROUGE, u)
		var p: Vector2 = to_local(b[0])
		_trace.draw_rect(Rect2(p - Vector2(0.55, 0.55), Vector2(1.1, 1.1)), Color(c, 1.0 - u * u))
	if force <= 0.02:
		_trace.vider()
		return
	var f := force * (0.94 + 0.06 * vie)
	if not corps.is_empty():
		# elle brûle : une lueur, et des langues à l'épaule, au dos, à la capuche, au bas du manteau
		var milieu: Vector2 = corps[0][0].lerp(corps[corps.size() - 1][0], 0.5)
		var r := 26.0 * f
		_trace.draw_texture_rect(Corps.doux(), Rect2(milieu - Vector2(r, r * 1.15), Vector2(r, r * 1.15) * 2.0), false, Color(P.BRAISE, 0.2 + 0.05 * vie))
		for i in corps.size():
			_bruler(corps[i][0], f * float(corps[i][1]), i * 1.9, 2, i)
		_trace.vider()
		return
	# la lueur
	var r := 15.0 * f
	_trace.draw_texture_rect(Corps.doux(), Rect2(Vector2(-r, -r - 5.0 * f), Vector2(r, r) * 2.0), false, Color(P.BRAISE, 0.14 + 0.04 * vie))
	_bruler(Vector2.ZERO, f, 0.0, 2 if mobile else LANGUES.size(), 0)
	if _lechee.z >= 0.0:
		var u := _lechee.z / 0.22
		_langue(Vector2(_lechee.x, _lechee.y), 3.0 * (1.0 - u), 1.1 * (1.0 - u), couche.x * 0.3, Color(P.BRAISE, 0.7 * (1.0 - u)))
	_trace.draw_texture_rect(Corps.doux(), Rect2(Vector2(-2.2, -3.6) * f, Vector2(4.4, 4.4) * f), false, Color(1.0, 0.95, 0.8, 0.9))
	_trace.vider()


# les langues d'un foyer, en o : rouge dehors, braise, puis le cœur (n langues ; k0 les distingue de celles d'un autre foyer)
func _bruler(o: Vector2, f: float, k0: float, n: int, depuis: int) -> void:
	for couche_ in [[P.BRAISE_ROUGE, 1.0, 0.55], [P.BRAISE, 0.72, 0.6], [P.BRAISE_COEUR, 0.42, 0.8]]:
		for i in n:
			var l: Array = LANGUES[(i + depuis) % LANGUES.size()] if i > 0 else LANGUES[0]
			var k: float = l[3] + k0
			var haut: float = 10.5 * f * l[1] * couche_[1] * (0.85 + 0.25 * _onde(_t * 1.3, k))
			var large: float = 2.7 * f * l[2] * (0.55 + 0.45 * couche_[1])
			var balance := _onde(_t * 0.9, k + 1.0) * 1.6 * f + couche.x
			_langue(o + Vector2(l[0] * f * couche_[1], 0.0), haut, large, balance, Color(couche_[0], couche_[2]))


# une langue : une goutte renversée, ronde en bas, qui file en pointe et se couche au bout
func _langue(base: Vector2, haut: float, large: float, balance: float, couleur: Color) -> void:
	var g := PackedVector2Array()
	var d := PackedVector2Array()
	var n := 7
	for k in n + 1:
		var u := float(k) / n
		var c := base + Vector2(balance * u * u, -haut * u)
		var w := large * pow(1.0 - u, 1.1) * sqrt(u + 0.2) * 1.5
		g.append(c - Vector2(w, 0.0))
		if k < n:
			d.append(c + Vector2(w, 0.0))
	var pts := PackedVector2Array()
	pts.append_array(g)
	d.reverse()
	pts.append_array(d)
	var w0 := large * sqrt(0.2) * 1.5
	for k in 5:
		var a := PI * (k + 1) / 6.0
		pts.append(base + Vector2(cos(a), sin(a) * 0.8) * w0)
	_trace.draw_colored_polygon(pts, couleur)
