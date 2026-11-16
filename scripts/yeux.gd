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
# Ce que les herbes y ajoutent (scripts/effets_herbes.gd le dessine, ici) : sous la voyance, le contour pâle de chaque bête et
# le fil vers la tanière de la Noire ; sous les visions, des yeux qui n'existent pas (par paires, violets).
# La Noire (scripts/noire.gd) a les siens : deux braises, petites, d'un rouge sombre, qui ne s'éteignent pas dans la lumière.
# Ni pupille, ni reflet, presque pas de halo : un cœur à peine plus clair, qui penche vers la veilleuse (elle regarde), et une
# lueur qui respire lentement. Leur taille se règle sur rayon_oeil() (scripts/bete.gd), jamais en pixels : NOIRE_TAILLE. De
# profil, une seule ; quand elle guette (de_face), la seconde paraît à sa place : de l'autre côté du chanfrein, plus loin,
# plus petite, vue de biais — jamais posée sur la première.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/effets_textures.gd")

var jeu
var _t := 0.0
var _vus := {}
var _a_voir: Array = []       # [la bête, sa lueur] : ceux qu'on dessine, cette image
static var _rond: ImageTexture
static var _amande: ImageTexture
static var _braise: ImageTexture
# les yeux de la Noire. NOIRE_TAILLE est le seul chiffre à régler : la demi-largeur de la braise, en rayons d'œil (rayon_oeil,
# scripts/bete.gd). Le reste se dit en demi-largeurs : sa demi-hauteur, son halo, et, pour une tête qui ne dit pas où est son
# second œil (oeil_loin), l'écart et la taille de celui-ci quand elle regarde en face (l'écart passe la somme des deux
# demi-largeurs : elles ne se touchent pas).
const NOIRE_TAILLE := 1.3
const NOIRE_HAUTE := 0.74
const NOIRE_HALO := 2.6
const NOIRE_ECART := 2.35
const NOIRE_SECONDE := 0.7


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
				# (ses yeux ne s'éteignent pas : dans la lumière d'un feu ils couvent ; le jour, il n'en reste qu'un rouge sourd, sur
				# l'œil que sa tête porte déjà)
				a = maxf(a, lerpf(0.18, 0.72, nuit))
			var avant: float = _vus.get(id, 0.0)
			var v := move_toward(avant, a, delta * (5.0 if a < avant else 2.5))
			garder[id] = v
			if v > 0.02:
				_a_voir.append([b, v])
		_vus = garder
	queue_redraw()


# ce que les herbes font voir (scripts/effets_herbes.gd) ; null hors d'une partie, ou sans les effets
func _herbes():
	var e = jeu.get("effets") if jeu != null else null
	return e.get("herbes") if e != null else null


func _draw() -> void:
	if jeu == null or not jeu.en_partie:
		return
	# les herbes d'abord, sous les vrais yeux : la voyance (le contour pâle de chaque bête, le fil vers la tanière de la Noire),
	# les visions (des yeux qui n'existent pas)
	var herbes = _herbes()
	var voit := 0.0
	if herbes != null:
		voit = herbes.voyance
		if voit > 0.01:
			herbes.peindre_voyance(self, T.point_doux())
			herbes.peindre_fil(self, T.point_doux())
		herbes.peindre_fantomes(self, _oeil_amande(), T.point_doux())
	if _a_voir.is_empty():
		return
	var j = jeu.joueur
	var yeux: Array = []          # [où, rayon, couleur, lueur, paupière, reflet, axe, chasseur]
	var braises: Array = []       # ceux de la Noire : [où, rayon, lueur, paupière, reflet, axe, vers la veilleuse, la première]
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
		# (la voyance : chaque œil renvoie une lumière qu'on ne voit pas)
		reflet = maxf(reflet, 0.6 * voit)
		if b.role == "noire":
			# une braise de profil ; quand elle guette (de_face), la seconde paraît là où sa tête la porte (bete.gd : oeil_loin, si
			# elle le dit) ; sinon elle sort de derrière le chanfrein : du côté du museau, un peu plus haut (plus loin de nous),
			# plus petite, et s'écarte de la première en venant. Jamais elles ne se touchent.
			var rn: float = float(b.rayon_oeil()) * NOIRE_TAILLE
			var an: Vector2 = b.axe_oeil()
			if an.length_squared() < 0.25:
				an = Vector2.RIGHT
			var face: float = smoothstep(0.0, 1.0, float(b.de_face))
			# (une lente respiration de la lueur ; le cœur penche vers la veilleuse)
			var couve: float = e[1] * (0.87 + 0.13 * sin(_t * 0.9))
			var vers := Vector2.ZERO
			if j != null:
				vers = (j.position + Vector2(0.0, -20.0) - p).normalized()
			braises.append([p, rn, couve, ouvert, reflet, an, vers, true])
			if face > 0.03:
				var devant := 1.0 if an.x >= 0.0 else -1.0
				var q := p + Vector2(devant * rn * NOIRE_ECART * lerpf(0.72, 1.0, face), -rn * 0.26 * face)
				var rq := rn * NOIRE_SECONDE
				if b.has_method("oeil_loin"):
					var loin: Vector3 = b.oeil_loin()
					q = Vector2(loin.x, loin.y)
					rq = loin.z * NOIRE_TAILLE
				braises.append([q, rq, couve * face * 0.85, ouvert, reflet, an, vers, false])
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
	if not braises.is_empty():
		_peindre_braises(braises, doux)


# les yeux de la Noire : un halo (à peine), la braise, son cœur. Trois appels de dessin quand elle est là, aucun sinon.
func _peindre_braises(braises: Array, doux: Texture2D) -> void:
	for o in braises:
		var ouvert: float = o[3]
		if ouvert <= 0.05:
			continue
		var ou: Vector2 = o[0]
		var h: float = float(o[1]) * NOIRE_HALO
		draw_texture_rect(doux, Rect2(ou - Vector2(h, h * 0.8), Vector2(h * 2.0, h * 1.6)), false, Color(P.OEIL_NOIRE, float(o[2]) * 0.1 * ouvert))
	var tex := _oeil_braise()
	for passe in 2:
		for o in braises:
			var ouvert: float = o[3]
			var premiere: bool = o[7]
			if ouvert <= 0.05 or (passe == 1 and not premiere):
				continue
			var ou: Vector2 = o[0]
			var r: float = o[1]
			var lueur: float = o[2]
			var axe: Vector2 = o[5]
			# (l'image regarde à droite : on la tourne vers le museau, sans la renverser ; la paupière l'écrase)
			var bas := Vector2(-axe.y, axe.x) if axe.x >= 0.0 else Vector2(axe.y, -axe.x)
			# (la seconde : vue de biais, plus étroite, la paupière plus basse ; elle n'a pas de cœur)
			var large := r * (1.0 if premiere else 0.8)
			var haute := r * NOIRE_HAUTE * ouvert * (1.0 if premiere else 0.9)
			if passe == 0:
				draw_set_transform_matrix(Transform2D(axe * large, bas * haute, ou))
				draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(P.OEIL_NOIRE, lueur))
			else:
				# le cœur : à peine plus clair, plus chaud ; il va vers la veilleuse, et s'avive un peu quand une lumière l'approche
				var vers: Vector2 = o[6]
				var vif: float = o[4]
				draw_set_transform_matrix(Transform2D(axe * large * 0.5, bas * haute * 0.5, ou + vers * r * 0.17 + bas * haute * 0.12))
				draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(P.OEIL_NOIRE.lerp(P.BRAISE, 0.35), lueur * (0.24 + 0.2 * vif) * ouvert))
	draw_set_transform(Vector2.ZERO)


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


# l'œil de la Noire, tourné vers la droite : une braise. Un ovale au bord fondu, sombre au pourtour, que la paupière du dessus
# coupe un peu bas, et plus bas encore du côté du museau (elle fixe). Ni pupille, ni blanc.
static func _oeil_braise() -> ImageTexture:
	if _braise == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var q := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
				var d := q.length()
				var dessus := q.y + 0.58 - 0.2 * q.x
				var a := clampf(minf((0.94 - d) * 4.5, dessus * 6.0), 0.0, 1.0)
				var v := 1.0 - 0.45 * smoothstep(0.15, 0.9, d)
				img.set_pixel(x, y, Color(v, v, v, a))
		_braise = ImageTexture.create_from_image(img)
	return _braise
