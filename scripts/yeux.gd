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
# Un chasseur posté dans le noir (scripts/bete.gd : poste) fixe la veilleuse : sa tête vient vers nous, et l'on voit ses deux
# yeux, côte à côte, qui s'effilent l'un vers l'autre. On compte les paires : on sait par combien on est regardé, et d'où. Leur
# lueur est celle du feu qu'ils renvoient : elle pâlit moins vite que lui, une bûche les fait briller un instant ; et quand il
# se détourne pour changer de poste (detourne), le second œil passe derrière sa tête, le premier s'étrécit et s'éteint : on
# le perd. Toujours trois images et les mêmes appels de dessin : la paire est faite de la même amande, retournée.

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
# la paire d'un chasseur posté, en rayons d'œil elle aussi : l'écart de ses deux yeux (leurs deux demi-largeurs, et du noir
# entre eux : sans ce noir, de loin, on n'en compte qu'un), la taille du second, et le plus petit rayon d'un œil qui fixe (à
# 300 pixels, sur un téléphone, il faut encore compter les paires)
const PAIRE_ECART := 3.9
const PAIRE_SECOND := 0.84
const PAIRE_PETIT := 2.1
const BUCHE := 1.4               # secondes : ce que dure l'éclat des yeux quand une bûche avive le feu
var _feux_r := {}                # le rayon de chaque feu, à l'image d'avant : une bûche le fait bondir
var _buche := 0.0                # de 1 à 0 : un feu vient de s'aviver, à _buche_ou
var _buche_ou := Vector2.ZERO
var _buche_r := 0.0
var _fixes := {}                 # les chasseurs dont on a vu la paire, immobile (les mots : quand elle s'éteint)
var _fixe_t := 0.0               # depuis quand des yeux la fixent, à l'écran


func _ready() -> void:
	material = T.materiau(true, false)


func _process(delta: float) -> void:
	_t += delta
	_a_voir.clear()
	# (chaque œil vu s'allume ou s'éteint doucement : ce qui n'est plus là, on l'oublie)
	if jeu != null and jeu.en_partie:
		var garder := {}
		var nuit: float = 1.0 - jeu.lumiere_du_jour()
		_feux_avives(delta)
		var herbes = _herbes()
		var voit: float = herbes.voyance if herbes != null else 0.0
		var j = jeu.joueur
		var fixes := {}
		var fixee := false
		var perdu := false
		for b in jeu.get_tree().get_nodes_in_group("betes"):
			if not is_instance_valid(b) or b.role == "echo":
				continue
			var id: int = b.get_instance_id()
			var a := 0.0
			var l := 0.0
			if nuit >= 0.2:
				l = jeu.eclairage(b.point_oeil())
				a = clampf((0.45 - l) / 0.45, 0.0, 1.0) * nuit
			if b.role == "chasseur":
				if nuit >= 0.2 and b.poste > 0.01:
					# (posté au bord d'un feu bas, sa tête entre dans la pénombre : ses yeux fixent le feu, ils le renvoient encore.
					# Sans cela le cercle d'yeux s'éteindrait en se resserrant, quand le feu meurt : le moment où il doit peser)
					a = maxf(a, clampf((0.45 + 0.35 * float(b.poste) - l) / 0.45, 0.0, 1.0) * nuit)
				# (il se détourne pour changer de poste : ses yeux ne renvoient plus rien, on le perd ; la voyance, elle, le voit)
				a *= 1.0 - smoothstep(0.1, 0.85, float(b.detourne)) * (1.0 - voit) * (1.0 - _eclat_buche(b.position))
				# (les mots : une paire qu'on a vue, à l'écran, sans bouger ; puis celle qui s'éteint)
				var vue: bool = float(_vus.get(id, 0.0)) > 0.6 and b.poste > 0.9 and b.detourne < 0.1 and j != null \
					and absf(b.position.x - j.position.x) < 450.0 and absf(b.position.y - j.position.y) < 200.0
				if vue:
					fixee = true
					fixes[id] = true
				elif _fixes.has(id):
					if b.detourne > 0.8:
						perdu = true
					else:
						fixes[id] = true
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
		_fixes = fixes
		# les mots, une fois par partie : des yeux qui la fixent sans bouger ; puis les premiers qui s'éteignent
		_fixe_t = _fixe_t + delta if fixee else 0.0
		if (_fixe_t > 2.5 or perdu) and jeu.has_method("_conseil"):
			jeu._conseil("yeux-fixes", _fixe_t > 2.5, "Des yeux, dans le noir. Ils ne bougent pas.")
			jeu._conseil("yeux-perdus", perdu, "Deux yeux s'éteignent. Il n'est pas parti : écoute.")
	queue_redraw()


# le premier instant de cet éclat (une demi-seconde), de 1 à 0, pour un œil qui est là : il tient par-dessus la paupière et
# le demi-tour. Sans cela on ne le verrait pas : la bête cligne et se détourne dans le dixième de seconde où le feu grandit.
func _eclat_buche(ou: Vector2) -> float:
	if _buche <= 0.6:
		return 0.0
	return smoothstep(0.6, 0.88, _buche) * clampf(1.0 - (ou.distance_to(_buche_ou) - _buche_r * 2.2) / (_buche_r * 1.2), 0.0, 1.0)


# une bûche jetée au feu : son rayon bondit d'une image à l'autre. Les yeux tournés vers lui brillent un instant (_draw).
func _feux_avives(delta: float) -> void:
	_buche = maxf(0.0, _buche - delta / BUCHE)
	var rayons := {}
	for f in jeu.feux:
		if is_instance_valid(f) and f.allume():
			var idf: int = f.get_instance_id()
			var rf: float = f.rayon()
			if rf > float(_feux_r.get(idf, rf)) + 6.0:
				_buche = 1.0
				_buche_ou = f.position
				_buche_r = rf
			rayons[idf] = rf
	_feux_r = rayons


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
	# [où, rayon, couleur, lueur, paupière, reflet, axe, chasseur, son halo (0 : aucun), où est le halo, sa forme (demi-largeur
	# et demi-hauteur, en rayons), de combien son cœur va vers la veilleuse, ce qu'il renvoie du feu]
	var yeux: Array = []
	var braises: Array = []       # ceux de la Noire : [où, rayon, lueur, paupière, reflet, axe, vers la veilleuse, la première]
	for e in _a_voir:
		var b = e[0]
		if not is_instance_valid(b):
			continue
		var p: Vector2 = b.point_oeil()
		var ouvert: float = b.paupiere()
		# (une bûche vient d'aviver le feu : ses yeux l'ont renvoyé avant qu'il ait cligné, avant qu'il se soit détourné)
		var saisi := _eclat_buche(p) if b.role == "chasseur" else 0.0
		ouvert = maxf(ouvert, saisi)
		# la torche, le bord d'un feu : les yeux renvoient la lumière
		var reflet := 0.0
		# (posté, ce que ses yeux renvoient de la lumière qu'il fixe : un feu qui baisse pâlit plus vite qu'eux)
		var renvoi := 0.0
		if j != null and j.torche > 0.0:
			var dt: float = p.distance_to(j.position)
			reflet = clampf(1.0 - (dt - R.RAYON_TORCHE * 0.8) / (R.RAYON_TORCHE * 0.7), 0.0, 1.0)
			renvoi = 0.7 * clampf(1.0 - (dt - R.RAYON_TORCHE * 1.6) / (R.RAYON_TORCHE * 1.4), 0.0, 1.0)
		for f in jeu.feux:
			if is_instance_valid(f) and f.allume():
				var rf: float = f.rayon()
				reflet = maxf(reflet, 0.55 * clampf(1.0 - (p.distance_to(f.position) - rf * 0.82) / (rf * 0.5), 0.0, 1.0))
				renvoi = maxf(renvoi, pow(clampf(rf / 270.0, 0.0, 1.0), 0.4) * clampf(1.0 - (p.distance_to(f.position) - rf * 2.2) / (rf * 1.2), 0.0, 1.0))
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
		var r0: float = b.rayon_oeil()
		var axe0: Vector2 = b.axe_oeil()
		var teinte: Color = P.OEIL_CHASSEUR if chasse else P.OEIL_PROIE
		var face := 0.0
		var tourne := 0.0
		if b.role == "chasseur":
			tourne = float(b.detourne) * (1.0 - voit) * (1.0 - saisi)
			face = smoothstep(0.0, 1.0, float(b.poste)) * (1.0 - smoothstep(0.0, 0.45, tourne))
			if _buche > 0.0:
				# (une bûche : le feu s'avive, ses yeux le renvoient d'un coup, puis retombent)
				reflet = maxf(reflet, _buche * _buche * (1.0 - tourne) * clampf(1.0 - (p.distance_to(_buche_ou) - _buche_r * 2.2) / (_buche_r * 1.2), 0.0, 1.0))
		if face <= 0.03:
			# de profil : un seul œil (celui qui se détourne s'étrécit en s'éteignant)
			yeux.append([p, r0, teinte, a, ouvert, reflet, axe0, chasse, 1.0, p, Vector2(2.3 * (1.0 - 0.5 * tourne), 1.5) if chasse else Vector2(1.45, 1.45), Vector2.ZERO, 0.0])
			continue
		# posté, il la fixe : la paire. Le premier œil est celui que sa tête porte ; le second paraît du côté du museau, un peu
		# plus haut (plus loin de nous), plus petit. Chacun s'effile vers l'autre, le coin du dedans plus bas : il ne cligne
		# presque pas (bete.gd : _cligner). Leur cœur, et la fente de la pupille avec lui, vont vers la veilleuse.
		var devant := 1.0 if axe0.x >= 0.0 else -1.0
		var rp := lerpf(r0, maxf(r0, PAIRE_PETIT), face)
		var pente := 0.2 * face
		var axe1 := axe0.lerp(Vector2(devant * cos(pente), sin(pente)), face).normalized()
		var axe2 := Vector2(-devant * cos(pente), sin(pente))
		# (la paire se tient sur sa tête : le premier œil recule un peu vers la nuque, le second vient vers le museau)
		var ecart := devant * rp * PAIRE_ECART * lerpf(0.55, 1.0, face)
		p.x -= ecart * 0.42 * face
		var q := p + Vector2(ecart, -rp * 0.2 * face)
		var vers := Vector2.ZERO
		if j != null:
			vers = (j.position + Vector2(0.0, -20.0) - p).normalized() * rp * 0.28 * face
		renvoi *= face
		# (un feu bas : ils pâlissent, mais moins que lui)
		var lueur_p := a * lerpf(1.0, 0.8 + 0.2 * renvoi, face)
		yeux.append([p, rp, teinte, lueur_p, ouvert, reflet, axe1, true, lerpf(1.0, 1.3, face), p.lerp(q, 0.5 * face), Vector2(lerpf(2.3, 1.72, face) * (1.0 - 0.5 * tourne), lerpf(1.5, 1.56, face)), vers, renvoi])
		yeux.append([q, rp * PAIRE_SECOND, teinte, lueur_p * face, ouvert, reflet, axe2, true, 0.0, q, Vector2(1.72, 1.56), vers, renvoi])
	# les halos d'abord (une seule image, un seul appel), puis les yeux ronds, puis les amandes, puis les reflets
	var doux := T.point_doux()
	for o in yeux:
		var ouvert: float = o[4]
		var halo: float = o[8]
		if ouvert <= 0.05 or halo <= 0.0:
			continue
		var r: float = o[1]
		var reflet: float = o[5]
		var lueur: float = o[3]
		var ou: Vector2 = o[9]
		var renvoi: float = o[12]
		var h := maxf(r * (7.5 if o[7] else 6.0), 5.0) * (1.0 + 0.8 * reflet) * halo
		draw_texture_rect(doux, Rect2(ou - Vector2(h, h * 0.8), Vector2(h * 2.0, h * 1.6)), false, Color(o[2], lueur * (0.24 + 0.3 * reflet + 0.1 * renvoi) * ouvert))
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
			var forme: Vector2 = o[10]
			var vers: Vector2 = o[11]
			var renvoi: float = o[12]
			var large := r * forme.x
			var hauteur := r * forme.y * ouvert
			draw_set_transform_matrix(Transform2D(axe * large, haut * hauteur, ou))
			draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c, lueur))
			# le cœur, plus clair (et plus encore pour qui fixe un feu : il le renvoie)
			draw_set_transform_matrix(Transform2D(axe * large * 0.62, haut * hauteur * 0.62, ou - haut * hauteur * 0.06 + vers))
			draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, Color(c.lightened(0.5 + 0.22 * renvoi), lueur * (0.75 + 0.25 * maxf(reflet, renvoi))))
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
