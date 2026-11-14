extends Node2D
# Lisière — les empreintes (scripts/traces.gd)
# Ce qui marche laisse sa trace : une empreinte à chaque foulée (bete.gd), sur le sol, sous tout ce qui se tient debout. Elle
# reste un moment puis s'efface (plus vite sous la pluie) ; celles d'un chasseur tiennent plus longtemps que celles d'une
# proie, celles de la Noire toute une journée (scripts/noire.gd : sa piste, de la lisière du camp à sa tanière). Trois dessins,
# faits par le code, la pointe tournée vers où allait la bête : c'est ce qui se lit, quand on suit une piste.
#  - 0 : une patte (un coussinet, quatre doigts) ;
#  - 1 : un pied d'oiseau (trois doigts devant, un derrière) ;
#  - 2 : la Noire (une patte large comme un buste, des griffes devant chaque doigt).
# Rien dans l'eau d'une rivière, rien dans la roche. On ne dessine que ce qui est près de l'écran, trois fois par seconde.

const P := preload("res://scripts/palette.gd")
const MAX := 700                 # au-delà, les plus vieilles s'en vont (jamais celles de la Noire)
const N := 48

var jeu
var _t := 0.0
var _liste: Array = []           # [x, y, angle, taille, née à, s'efface à, genre]
var _vu := 0.0
static var _tex: Array = []


func _ready() -> void:
	name = "Traces"
	if _tex.is_empty() and DisplayServer.get_name() != "headless":
		for g in 3:
			_tex.append(ImageTexture.create_from_image(_image(g)))


func vider() -> void:
	_liste.clear()
	queue_redraw()


# une empreinte, en p, tournée vers « angle » ; taille : sa demi-largeur (pixels du lieu) ; duree : ce qu'elle tient (secondes)
func poser(p: Vector2, angle: float, taille: float, duree: float, genre: int) -> void:
	if jeu != null and jeu.get("carte") != null and jeu.carte != null:
		if float(jeu.carte.lit(p)) > 0.0 or bool(jeu.carte.roche_en(p)):
			return
	_liste.append([p.x, p.y, angle, taille, _t, _t + duree, genre])
	if _liste.size() > MAX:
		# (les plus vieilles d'abord, mais pas la piste de la Noire)
		for i in _liste.size():
			if int(_liste[i][6]) != 2:
				_liste.remove_at(i)
				break
		if _liste.size() > MAX + 200:
			_liste.remove_at(0)


# y a-t-il une empreinte de ce genre à moins de « rayon » de p ?
func pres(p: Vector2, rayon: float, genre: int) -> bool:
	var r2 := rayon * rayon
	for e in _liste:
		if int(e[6]) == genre and Vector2(e[0], e[1]).distance_squared_to(p) < r2:
			return true
	return false


# combien d'empreintes de ce genre (l'essai)
func nombre(genre: int = -1) -> int:
	if genre < 0:
		return _liste.size()
	var n := 0
	for e in _liste:
		if int(e[6]) == genre:
			n += 1
	return n


# effacer les empreintes d'un genre (la piste de la veille, quand la Noire en fait une autre)
func effacer(genre: int) -> void:
	_liste = _liste.filter(func(e): return int(e[6]) != genre)
	queue_redraw()


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause:
		return
	# (la pluie les lave : leur temps passe plus vite)
	var pluie: float = float(jeu.climat.pluie) if jeu.climat != null else 0.0
	_t += delta * (1.0 + 2.5 * pluie)
	_vu -= delta
	if _vu <= 0.0:
		_vu = 0.33
		var k := 0
		while k < _liste.size():
			if float(_liste[k][5]) <= _t:
				_liste.remove_at(k)
			else:
				k += 1
		queue_redraw()


func _draw() -> void:
	if _liste.is_empty() or _tex.is_empty():
		return
	var vp := get_viewport()
	var vue: Rect2 = (vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()).grow(260.0)
	# (un genre après l'autre : une image, un appel de dessin)
	for g in 3:
		var tex: Texture2D = _tex[g]
		for e in _liste:
			if int(e[6]) != g:
				continue
			var p := Vector2(e[0], e[1])
			if not vue.has_point(p):
				continue
			var ne: float = e[4]
			var fin: float = e[5]
			var a := clampf((fin - _t) / maxf((fin - ne) * 0.3, 0.01), 0.0, 1.0) * clampf((_t - ne) / 0.4, 0.0, 1.0)
			var t: float = e[3]
			draw_set_transform(p, float(e[2]), Vector2(t, t * 0.9))
			draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(P.ENCRE, (0.5 if g == 2 else 0.4) * a))
	draw_set_transform(Vector2.ZERO)


# le dessin d'une empreinte, blanche sur rien, la pointe vers la droite
static func _image(genre: int) -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var q := Vector2((x + 0.5) / N * 2.0 - 1.0, (y + 0.5) / N * 2.0 - 1.0)
			var a := 0.0
			match genre:
				1:
					# (trois doigts devant, un derrière : des traits fins)
					for ang in [0.0, 0.55, -0.55, PI]:
						var dir := Vector2.from_angle(ang)
						var l := 0.85 if ang != PI else 0.4
						var s := clampf(q.dot(dir), 0.0, l)
						a = maxf(a, _doux(q.distance_to(dir * s), 0.09))
				2:
					a = _doux(Vector2((q.x + 0.3) / 0.36, q.y / 0.44).length(), 1.0, 0.1)
					for k in 4:
						var yy := -0.6 + 0.4 * k
						var av := 0.28 - 0.1 * absf(yy)
						a = maxf(a, _doux(Vector2((q.x - av) / 0.15, (q.y - yy) / 0.13).length(), 1.0, 0.14))
						# (la griffe : une pointe en avant du doigt)
						var g0 := Vector2(av + 0.2, yy)
						var s2 := clampf(q.x - g0.x, 0.0, 0.42)
						a = maxf(a, _doux(Vector2(q.x - g0.x - s2, q.y - yy).length(), 0.055 * (1.0 - s2 / 0.5)))
				_:
					a = _doux(Vector2((q.x + 0.28) / 0.34, q.y / 0.4).length(), 1.0, 0.12)
					for k in 4:
						var yy := -0.57 + 0.38 * k
						var av := 0.42 - 0.16 * absf(yy)
						a = maxf(a, _doux(Vector2((q.x - av) / 0.16, (q.y - yy) / 0.14).length(), 1.0, 0.16))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return img


# un bord doux : 1 en dedans de « r », 0 au-delà (sur une frange)
static func _doux(d: float, r: float, frange: float = 0.035) -> float:
	return clampf((r - d) / frange, 0.0, 1.0)
