extends Node2D
# Lisière — un pont de fortune (scripts/pont.gd)
# Le monde ouvert (MONDE-OUVERT.md) : une rivière ne se passe qu'à ses gués, ou sur un pont qu'on fabrique (du bois, de la fibre)
# et qu'on pose au bord, vers l'autre berge. Il ne dure pas : il s'use avec le temps et à chaque passage, la crue l'emporte, le
# feu le brûle. Tant qu'il tient, on y passe au sec, et les bêtes aussi (scripts/carte.gd, sur_un_pont).
# Lié de filin (la fibre longue de l'agave, du papyrus : scripts/atelier.gd), il tient trois fois plus, s'use moins à chaque
# passage et ne cède qu'à la plus forte crue ; on le voit à ses liures blondes aux pieux, aux planches serrées, et à sa main
# courante, un filin tendu de pieu à pieu de chaque côté.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const BOIS := Color("7a5c3c")
const FILIN := Color("c9ad6e")       # (le filin : celui de la longe, scripts/harnais.gd)

var jeu
var a := Vector2.ZERO
var b := Vector2.ZERO
var tenue := 0.0              # les secondes qu'il lui reste
var lie := false              # lié de filin : il dure, s'use moins, tient à la crue
var _dessus := false
var _etat := -1


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause:
		return
	tenue -= delta
	var j = jeu.joueur
	var dessus: bool = j != null and _porte(j.position)
	# (chaque passage l'use un peu plus)
	if dessus and not _dessus:
		tenue -= R.PONT_PASSAGE * (R.PONT_FILIN_USURE if lie else 1.0)
	_dessus = dessus
	var milieu := (a + b) * 0.5
	if jeu.climat.crue > (R.PONT_FILIN_CRUE if lie else 0.6):
		jeu.pont_tombe(self, "La crue a emporté le pont.")
	elif jeu.incendie.contact(a) or jeu.incendie.contact(b) or jeu.incendie.contact(milieu):
		jeu.pont_tombe(self, "Le pont a brûlé.")
	elif tenue <= 0.0:
		jeu.pont_tombe(self, "Le pont a cédé.")
	else:
		# (il se défait à vue d'œil : des planches manquent quand il lui reste peu)
		var etat := int(clampf(tenue / 30.0, 0.0, 3.0))
		if etat != _etat:
			_etat = etat
			queue_redraw()


func _porte(p: Vector2) -> bool:
	var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 1.0), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t) < 15.0


func _draw() -> void:
	var l := a.distance_to(b)
	if l < 2.0:
		return
	draw_set_transform(a, (b - a).angle(), Vector2.ONE)
	var encre := Color(P.ENCRE, 0.9)
	# l'ombre sur l'eau, les deux longerons, les planches (il en manque quand il s'use), les pieux des deux bouts
	draw_rect(Rect2(0.0, -10.0, l, 26.0), Color(0.0, 0.0, 0.0, 0.16))
	for cote in [-11.0, 11.0]:
		draw_rect(Rect2(-2.0, cote - 2.5, l + 4.0, 5.0), encre)
		draw_rect(Rect2(-1.0, cote - 1.5, l + 2.0, 3.0), BOIS.darkened(0.25))
	var r := RandomNumberGenerator.new()
	r.seed = hash(a) + 7
	var manque := clampf(1.0 - tenue / 90.0, 0.0, 0.6)
	var x := 3.0
	while x < l - 6.0:
		var large := r.randf_range(6.0, 8.0)
		var tombee := r.randf() < manque
		var ton := BOIS.lightened(r.randf_range(-0.08, 0.14))
		var biais := r.randf_range(-1.0, 1.0)
		if not tombee:
			draw_rect(Rect2(x - 0.8, -14.8 + biais, large + 1.6, 29.6), encre)
			draw_rect(Rect2(x, -14.0 + biais, large, 28.0), ton)
			draw_rect(Rect2(x, -14.0 + biais, large, 3.0), ton.lightened(0.18))
		x += large + r.randf_range(1.2, 2.6)
	for bout in [-3.0, l + 3.0]:
		for cote in [-13.0, 13.0]:
			draw_circle(Vector2(bout, cote), 4.6, encre)
			draw_circle(Vector2(bout, cote), 3.4, BOIS.darkened(0.1))
	if lie:
		_liures(l, encre, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# lié de filin : des liures en croix sur chaque pieu, des surliures qui serrent les planches aux longerons de loin en loin, et
# de chaque côté une main courante, un filin tendu de pieu à pieu qui creuse un peu en son milieu (son ombre sur l'eau)
func _liures(l: float, encre: Color, r: RandomNumberGenerator) -> void:
	var clair := FILIN.lightened(0.16)
	var sombre := FILIN.darkened(0.32)
	for cote in [-13.0, 13.0]:
		var pts := PackedVector2Array()
		var ombre := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			var x := lerpf(-3.0, l + 3.0, t)
			# (la main courante : un peu plus haut que le tablier, vue de trois quarts ; elle creuse au milieu)
			var creux := 4.0 * t * (1.0 - t) * minf(6.0, l * 0.025)
			pts.append(Vector2(x, cote - 7.0 + creux))
			ombre.append(Vector2(x + 2.0, cote + 5.0 + creux * 0.5))
		draw_polyline(ombre, Color(0.0, 0.0, 0.0, 0.14), 2.2, true)
		draw_polyline(pts, encre, 3.4, true)
		draw_polyline(pts, FILIN, 1.8, true)
		# (ses torons : de petits traits en biais)
		for i in range(1, pts.size() - 1):
			var q := pts[i]
			draw_line(q + Vector2(-1.0, -0.8), q + Vector2(0.4, 0.8), sombre, 0.7, true)
	# les pieux : une liure en croix, et la main courante qui y est nouée
	for bout in [-3.0, l + 3.0]:
		for cote in [-13.0, 13.0]:
			var c := Vector2(bout, cote)
			for k in [-1.0, 1.0]:
				draw_line(c + Vector2(-3.2, -3.0 * k), c + Vector2(3.2, 3.0 * k), encre, 2.6, true)
				draw_line(c + Vector2(-3.2, -3.0 * k), c + Vector2(3.2, 3.0 * k), clair, 1.3, true)
			draw_line(c + Vector2(0.0, -7.0), c + Vector2(0.0, -3.0), encre, 2.8, true)
			draw_line(c + Vector2(0.0, -7.0), c + Vector2(0.0, -3.0), FILIN, 1.4, true)
	# les surliures : tous les vingt-quatre pixels environ, deux tours de filin sur le longeron
	var x := 14.0 + r.randf_range(0.0, 6.0)
	while x < l - 10.0:
		for cote in [-11.0, 11.0]:
			for k in 2:
				var xx := x + k * 2.4
				draw_line(Vector2(xx - 0.6, cote - 3.2), Vector2(xx + 0.6, cote + 3.2), encre, 2.2, true)
				draw_line(Vector2(xx - 0.6, cote - 3.2), Vector2(xx + 0.6, cote + 3.2), FILIN, 1.0, true)
		x += r.randf_range(20.0, 28.0)
