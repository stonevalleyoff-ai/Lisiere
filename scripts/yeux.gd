extends Node2D
# Lisière — ce qui brille dans le noir (scripts/yeux.gd)
# Une couche au-dessus de l'obscurité (une CanvasLayer qui suit la caméra) : la nuit, l'œil des bêtes restées hors de la
# lumière brille, pile là où leur dessin le porte (bete.gd : point_oeil, rayon_oeil ; la tête qui pivote, le pas, le demi-tour
# l'emmènent). Les bêtes sont de profil : un seul œil, net. Ambre pour un chasseur, pâle pour une proie : on apprend à les lire.
#  - une proie : un œil rond, pâle, doux ;
#  - un chasseur : une amande qui s'effile vers le museau, sous une arcade qui tombe, fendue d'une pupille noire ; plus la bête
#    est grande, plus son œil l'est.
# Un halo doux, l'œil, un cœur plus clair. Quand la bête cligne (bete.gd : paupiere), la lueur s'éteint un instant ; quand la
# torche l'approche, l'œil la renvoie : plus vif, avec un reflet. Ils s'allument et s'éteignent en douceur, mais la règle
# tient : seulement la nuit, seulement hors de la lumière. Trois images faites par le code, trois appels de dessin pour tous
# les yeux du lieu. Les échos vivent aussi dans cette couche : la nuit ne les cache pas.
# La Noire (scripts/noire.gd) a les siens : rouges, plus grands, et qui ne s'éteignent pas dans la lumière ; quand elle guette,
# elle regarde en face, et l'on voit ses deux yeux.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")

var jeu
var _t := 0.0
var _vus := {}
var _a_voir: Array = []       # [la bête, sa lueur] : ceux qu'on dessine, cette image
static var _rond: ImageTexture
static var _amande: ImageTexture


func _ready() -> void:
	material = T.materiau(true, false)


func _process(delta: float) -> void:
	_t += delta
	_a_voir.clear()
	# (chaque œil vu s'allume ou s'éteint doucement : ce qui n'est plus là, on l'oublie)
	if jeu != null and jeu.en_partie:
		var garder := {}
		var nuit: float = 1.0 - jeu.lumiere_du_jour()
		for b in jeu.get_tree().get_nodes_in_group("betes"):
			if not is_instance_valid(b) or b.role == "echo":
				continue
			var id: int = b.get_instance_id()
			var a := 0.0
			if nuit >= 0.2:
				var l: float = jeu.eclairage(b.point_oeil())
				a = clampf((0.45 - l) / 0.45, 0.0, 1.0) * nuit
			if b.role == "noire":
				# (ses yeux ne s'éteignent pas : ni dans la lumière d'un feu, ni tout à fait le jour)
				a = maxf(a, lerpf(0.55, 0.85, nuit))
			var avant: float = _vus.get(id, 0.0)
			var v := move_toward(avant, a, delta * (5.0 if a < avant else 2.5))
			garder[id] = v
			if v > 0.02:
				_a_voir.append([b, v])
		_vus = garder
	queue_redraw()


func _draw() -> void:
	if jeu == null or not jeu.en_partie or _a_voir.is_empty():
		return
	var j = jeu.joueur
	var yeux: Array = []          # [où, rayon, couleur, lueur, paupière, reflet, axe, chasseur]
	for e in _a_voir:
		var b = e[0]
		if not is_instance_valid(b):
			continue
		var p: Vector2 = b.point_oeil()
		var ouvert: float = b.paupiere()
		# la torche, le bord d'un feu : les yeux renvoient la lumière
		var reflet := 0.0
		if j != null and j.torche > 0.0:
			var dt: float = p.distance_to(j.position)
			reflet = clampf(1.0 - (dt - R.RAYON_TORCHE * 0.8) / (R.RAYON_TORCHE * 0.7), 0.0, 1.0)
		for f in jeu.feux:
			if is_instance_valid(f) and f.allume():
				var rf: float = f.rayon()
				reflet = maxf(reflet, 0.55 * clampf(1.0 - (p.distance_to(f.position) - rf * 0.82) / (rf * 0.5), 0.0, 1.0))
		var chasse: bool = b.role == "chasseur" or b.role == "rodeur"
		# (une lueur qui vit : elle respire à peine)
		var a: float = e[1] * (0.93 + 0.07 * sin(_t * 2.3 + float(b.get_instance_id() % 97)))
		if b.role == "noire":
			# de profil, un œil ; de face (elle guette), les deux, qui tombent l'un vers l'autre
			var r: float = float(b.rayon_oeil()) * 1.25
			var face: float = smoothstep(0.0, 1.0, float(b.de_face))
			var axe: Vector2 = b.axe_oeil()
			var ecart := r * 2.7 * face
			var bas := Vector2(0.0, 0.34)
			yeux.append([p + Vector2(ecart, 0.0), r, P.OEIL_NOIRE, a, ouvert, reflet * 0.5, axe.lerp(Vector2(-1.0, 0.0) + bas, face).normalized(), true])
			if face > 0.05:
				yeux.append([p - Vector2(ecart, 0.0), r, P.OEIL_NOIRE, a * face, ouvert, reflet * 0.5, (Vector2(1.0, 0.0) + bas).normalized(), true])
			continue
		yeux.append([p, float(b.rayon_oeil()), P.OEIL_CHASSEUR if chasse else P.OEIL_PROIE, a, ouvert, reflet, b.axe_oeil(), chasse])
	# les halos d'abord (une seule image, un seul appel), puis les yeux ronds, puis les amandes, puis les reflets
	var doux := T.point_doux()
	for o in yeux:
		var ouvert: float = o[4]
		if ouvert <= 0.05:
			continue
		var r: float = o[1]
		var reflet: float = o[5]
		var lueur: float = o[3]
		var ou: Vector2 = o[0]
		var h := maxf(r * (7.5 if o[7] else 6.0), 5.0) * (1.0 + 0.8 * reflet)
		draw_texture_rect(doux, Rect2(ou - Vector2(h, h * 0.8), Vector2(h * 2.0, h * 1.6)), false, Color(o[2], lueur * (0.24 + 0.3 * reflet) * ouvert))
	for passe in 2:
		var chasse := passe == 1
		var tex := _oeil_amande() if chasse else _oeil_rond()
		for o in yeux:
			if o[7] != chasse or o[4] <= 0.05:
				continue
			var reflet: float = o[5]
			var lueur: float = o[3]
			var ouvert: float = o[4]
			var ou: Vector2 = o[0]
			var r: float = o[1] * (1.0 + 0.15 * reflet)
			var c: Color = o[2]
			var axe: Vector2 = o[6]
			# (l'image regarde à droite : on la tourne vers le museau, sans la renverser ; la paupière l'écrase)
			var haut := Vector2(-axe.y, axe.x) if axe.x >= 0.0 else Vector2(axe.y, -axe.x)
			var large := r * (2.3 if chasse else 1.45)
			var hauteur := r * (1.5 if chasse else 1.45) * ouvert
			draw_set_transform_matrix(Transform2D(axe * large, haut * hauteur, ou))
			draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c, lueur))
			# le cœur, plus clair
			draw_set_transform_matrix(Transform2D(axe * large * 0.62, haut * hauteur * 0.62, ou - haut * hauteur * 0.06))
			draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c.lightened(0.5), lueur * (0.75 + 0.25 * reflet)))
	draw_set_transform(Vector2.ZERO)
	# le reflet de la torche : un point blanc, net
	var rond := _oeil_rond()
	for o in yeux:
		var reflet: float = o[5]
		var ouvert: float = o[4]
		if reflet > 0.05 and ouvert > 0.05:
			var r: float = o[1]
			var ou: Vector2 = o[0]
			var lueur: float = o[3]
			var g := maxf(0.6, r * 0.34)
			draw_texture_rect(rond, Rect2(ou + Vector2(-r * 0.4, -r * 0.34 * ouvert) - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(1, 1, 1, lueur * reflet * 0.9))


# l'œil d'une proie : un disque net, à peine plus sombre au bord
static func _oeil_rond() -> ImageTexture:
	if _rond == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var q := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
				var d := q.length()
				var a := clampf((0.92 - d) * n * 0.25, 0.0, 1.0)
				var v := 1.0 - 0.3 * smoothstep(0.45, 0.92, d)
				img.set_pixel(x, y, Color(v, v, v, a))
		_rond = ImageTexture.create_from_image(img)
	return _rond


# l'œil d'un chasseur, tourné vers la droite : une amande qui s'effile vers le museau, l'arcade qui tombe de ce côté, une
# pupille fendue (du noir : rien ne brille là)
static func _oeil_amande() -> ImageTexture:
	if _amande == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var q := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
				# (le coin de l'œil : pointu devant, rond derrière)
				var k := 1.0 - q.x * q.x / 0.86
				var a := 0.0
				if k > 0.0:
					var arche := pow(k, 0.62 if q.x < 0.0 else 0.9)
					var dessus := -(0.8 - 0.42 * (q.x + 1.0) * 0.5) * arche
					var dessous := 0.6 * arche
					a = clampf(minf(q.y - dessus, dessous - q.y) * n * 0.22, 0.0, 1.0)
				# la pupille : une fente
				var fente := Vector2(q.x / 0.13, q.y / 0.62).length()
				a *= clampf((fente - 1.0) * 3.2 + 0.5, 0.0, 1.0)
				var v := 1.0 - 0.25 * smoothstep(0.3, 0.9, absf(q.x))
				img.set_pixel(x, y, Color(v, v, v, a))
		_amande = ImageTexture.create_from_image(img)
	return _amande
