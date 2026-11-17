extends RefCounted
# Lisière — la page de l'établi, la page du sac (scripts/interface_atelier.gd)
# Deux feuilles du carnet, posées sur la partie (le papier de la pause : scripts/interface_carnet.gd).
#  - l'établi (Etabli) : tout ce qui se fabrique (scripts/atelier.gd, OBJETS), rangé par familles sur une planche ; on touche
#    une chose, sa fiche dit ce qu'elle est, ce qu'elle coûte (en rouge sang ce qui manque), combien on en a, et la fabrique ;
#  - le sac (Sac) : ce qu'elle a sur elle ; l'établi, qui se fait de ses mains ; ce qui est posé juste là, qu'on replie ; ses
#    affaires, et pour chacune ce qu'on en fait (poser, mettre, ôter, allumer, éteindre, boire, dormir).
# Les deux se tiennent de la même façon : en haut, ce qu'elle porte ; à gauche, la planche (des tuiles, qui défilent sous le
# doigt s'il y en a trop) ; à droite, la fiche de la chose choisie et son seul bouton, toujours au même endroit sous le pouce.
# Elles se ferment par « Fermer » et par la touche de pause ; au clavier, les flèches choisissent, Entrée fait.
# Rien ne se redessine tant que rien ne change : la page relit l'atelier trois fois par seconde, et chaque morceau ne se
# refait que si ce qu'il montre a changé (ou le temps d'un sautillement, d'un tampon).

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")
const I := preload("res://scripts/interface_icones.gd")
const Icones := preload("res://scripts/atelier_icones.gd")
const Carnet := preload("res://scripts/interface_carnet.gd")
const Bouton := preload("res://scripts/interface_bouton.gd")
const Hud := preload("res://scripts/interface_hud.gd")
const Atelier := preload("res://scripts/atelier.gd")
const R := preload("res://scripts/regles.gd")

const NOURRITURE := ["baies", "champignons", "viande", "viande_cuite", "bouillon"]
# ce qu'on cueille et qui sert (scripts/flore.gd) : les fleurs (une infusion), l'infusion, l'amanite (un appât) ; et leurs noms
const CUEILLETTE := ["fleurs", "infusion", "amanite"]
const NOMS_CUEILLETTE := {"fleurs": "Fleurs", "infusion": "Infusion de fleurs", "amanite": "Amanite", "champignons": "cèpes"}
# la cueillette nourricière (scripts/atelier.gd, NOURRITURE_CUEILLIE) : ce qui ne se montre dans « À manger » qu'une fois qu'elle
# en a, et son nom, court, sous l'icône ; ce qui a un usage dans le sac (les grains : un gruau ; le lichen : une soupe ; la pulpe :
# pressée, de l'eau), et son nom
const NOMS_COURTS := {"pomme": "Pommes", "figue": "Figues", "coco": "Coco", "pain_de_singe": "Baobab", "grains": "Grains", "lichen": "Lichen",
	"pulpe": "Pulpe", "gruau": "Gruau", "soupe_lichen": "Soupe"}
const CUEILLETTE_NOURRICIERE := ["grains", "lichen", "pulpe"]
const NOMS_NOURRICIERS := {"grains": "Grains", "lichen": "Lichen des rennes", "pulpe": "Pulpe de cactus"}
const Jardin := preload("res://scripts/jardin.gd")
const Elevage := preload("res://scripts/elevage.gd")
const Botanique := preload("res://scripts/botanique.gd")
const Reperes := preload("res://scripts/reperes.gd")
# ce que le jardin et les bêtes donnent, dans l'ordre où le sac le montre
const DU_JARDIN := ["graine_baie", "graine_lin", "graine_simple", "simples", "lait"]
const NOMS_DU_JARDIN := {"graine_baie": "Graines de baies", "graine_lin": "Graines de lin", "graine_simple": "Graines de simples",
	"simples": "Simples", "lait": "Lait"}


# --- la plume : ce que les morceaux d'une page ont en commun ---

class Plume:
	static func large(f: Font, t: String, taille: int) -> float:
		return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

	# un mot, depuis la gauche de sa ligne ; rend où il finit
	static func mot(ci: CanvasItem, f: Font, p: Vector2, t: String, taille: int, c: Color) -> float:
		ci.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, c)
		return p.x + large(f, t, taille)

	static func milieu(ci: CanvasItem, f: Font, p: Vector2, t: String, taille: int, c: Color) -> void:
		ci.draw_string(f, p - Vector2(large(f, t, taille) * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, c)

	static func a_droite(ci: CanvasItem, f: Font, p: Vector2, t: String, taille: int, c: Color) -> float:
		var w := large(f, t, taille)
		ci.draw_string(f, p - Vector2(w, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, c)
		return p.x - w

	# un texte coupé aux mots pour tenir dans cette largeur (un deux-points, un guillemet ne quittent pas leur mot)
	static func lignes(f: Font, t: String, taille: int, largeur: float) -> PackedStringArray:
		var mots := PackedStringArray()
		var colle := false
		for brut in t.split(" ", false):
			if mots.size() > 0 and (colle or brut in [":", ";", "!", "?", "»"]):
				mots[mots.size() - 1] = mots[mots.size() - 1] + " " + brut
			else:
				mots.append(brut)
			colle = brut == "«"
		var out := PackedStringArray()
		var ligne := ""
		for m in mots:
			var essai := m if ligne == "" else ligne + " " + m
			if ligne != "" and large(f, essai, taille) > largeur:
				out.append(ligne)
				ligne = m
			else:
				ligne = essai
		if ligne != "":
			out.append(ligne)
		return out

	static func majuscule(t: String) -> String:
		return t.left(1).to_upper() + t.substr(1)

	# un rectangle aux coins ronds, dont le bord tremble un peu : tracé à la main
	static func galet(r: Rect2, rayon: float, graine: float = 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var coins := [[Vector2(r.end.x - rayon, r.position.y + rayon), -PI * 0.5], [Vector2(r.end.x - rayon, r.end.y - rayon), 0.0],
			[Vector2(r.position.x + rayon, r.end.y - rayon), PI * 0.5], [Vector2(r.position.x + rayon, r.position.y + rayon), PI]]
		var k := 0
		for coin in coins:
			var c: Vector2 = coin[0]
			for i in 6:
				var a: float = float(coin[1]) + PI * 0.5 * i / 5.0
				pts.append(c + Vector2.from_angle(a) * (rayon + 0.55 * sin(k * 2.3 + graine)))
				k += 1
		return pts

	# un cadre à l'encre : quatre traits effilés, qui se croisent un peu aux coins
	static func cadre(ci: CanvasItem, r: Rect2, e: float, c: Color) -> void:
		var d := 5.0
		I.trait_encre(ci, r.position + Vector2(-d, 0.5), Vector2(r.end.x + d, r.position.y - 0.5), e, c)
		I.trait_encre(ci, Vector2(r.end.x + 0.5, r.position.y - d), r.end + Vector2(-0.5, d), e, c)
		I.trait_encre(ci, r.end + Vector2(d, -0.5), Vector2(r.position.x - d, r.end.y + 0.5), e, c)
		I.trait_encre(ci, Vector2(r.position.x - 0.5, r.end.y + d), r.position + Vector2(0.5, -d), e, c)

	# les planches de l'herbier, si elles sont là (null : pas encore)
	static func planches():
		if not ResourceLoader.exists("res://scripts/herbier_planches.gd"):
			return null
		return load("res://scripts/herbier_planches.gd")

	# une coche, d'un coup de plume
	static func coche(ci: CanvasItem, c: Vector2, s: float, couleur: Color) -> void:
		I.trait_encre(ci, c + Vector2(-0.5, 0.1) * s, c + Vector2(-0.12, 0.48) * s, s * 0.26, couleur)
		I.trait_encre(ci, c + Vector2(-0.16, 0.5) * s, c + Vector2(0.56, -0.5) * s, s * 0.24, couleur)

	# une icône de l'atelier ou du HUD ; pâlie (une esquisse) pour ce qu'on n'a pas, ce qu'on ne peut pas encore faire
	static func icone(ci: CanvasItem, id: String, c: Vector2, s: float, pale: bool = false, base: Transform2D = Transform2D.IDENTITY) -> void:
		# (une herbe de l'herbier, « h:foret:ombelle » : sa vignette, dessinée par scripts/herbier_planches.gd)
		if id.begins_with("h:"):
			var pl = planches()
			if pl != null:
				ci.draw_set_transform_matrix(base)
				pl.vignette(ci, id.substr(2), c, s, not pale)
				ci.draw_set_transform_matrix(base)
				return
			id = "simples"
		# (un repère de la carte, « rep:camp » : son signe à l'encre, celui de la carte ; scripts/reperes.gd)
		if id.begins_with("rep:"):
			Reperes.signe(ci, id.substr(4), c, s * 0.82, pale, base)
			return
		if pale:
			Icones.esquisse(ci, id, c, s, 0.62, base)
		else:
			Icones.icone(ci, id, c, s, Color.WHITE, base)


# --- la bande du haut : ce qu'elle porte ---

# chaque matière (et, dans le sac, ce qui se mange) : son icône, son compte sur ce qu'elle peut en porter, son nom dessous.
# Un compte qui change sautille ; plein, il passe au rouge sang ; à zéro, tout pâlit.
class Bande extends Control:
	const HAUT := 66.0
	var groupes: Array = []        # [{ titre, cases : [{ id, nom, n, sur (0 : sans plafond) }] }]
	var _ressorts := {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, HAUT)
		set_process(false)

	func montrer(g: Array) -> void:
		var avant := {}
		for gr in groupes:
			for c in gr["cases"]:
				avant[str(c["id"])] = int(c["n"])
		groupes = g
		for gr in groupes:
			for c in gr["cases"]:
				var id := str(c["id"])
				if avant.has(id) and int(avant[id]) != int(c["n"]):
					if not _ressorts.has(id):
						_ressorts[id] = Hud.Ressort.new()
					_ressorts[id].pousser(8.0 if int(c["n"]) > int(avant[id]) else -5.0)
					set_process(true)
		queue_redraw()

	func _process(d: float) -> void:
		var bouge := false
		for id in _ressorts:
			_ressorts[id].avancer(d / maxf(0.01, Engine.time_scale))
			if _ressorts[id].x != 0.0 or _ressorts[id].v != 0.0:
				bouge = true
		queue_redraw()
		if not bouge:
			set_process(false)

	func _draw() -> void:
		var total := 0
		for gr in groupes:
			total += int(gr["cases"].size())
		if total == 0:
			return
		var ecart := 34.0
		var cw := minf(132.0, (size.x - ecart * (groupes.size() - 1)) / total)
		var x := 0.0
		for gi in groupes.size():
			var gr: Dictionary = groupes[gi]
			if gi > 0:
				I.trait_encre(self, Vector2(x - ecart * 0.5, 4.0), Vector2(x - ecart * 0.5, HAUT - 2.0), 1.6, Color(P.ENCRE, 0.45))
			Plume.mot(self, T.capitales(), Vector2(x + 8.0, 13.0), str(gr["titre"]), 15, Color(P.ENCRE_DOUCE, 0.9))
			for c in gr["cases"]:
				_case(c, Rect2(x, 19.0, cw, HAUT - 19.0))
				x += cw
			x += ecart

	func _case(c: Dictionary, r: Rect2) -> void:
		var id := str(c["id"])
		var n := int(c["n"])
		var sur := int(c["sur"])
		var plein := sur > 0 and n >= sur
		var rien := n <= 0
		var g := T.texte_gras()
		var t := T.texte_moyen()
		var tn := str(n)
		var ts := ("/%d" % sur) if sur > 0 else ""
		var wn := Plume.large(g, tn, 20)
		var isz := 30.0
		var l := isz + 6.0 + wn + Plume.large(t, ts, 14)
		var x0 := r.position.x + (r.size.x - l) * 0.5
		var cy := r.position.y + 15.0
		var k := 1.0
		if _ressorts.has(id):
			k += clampf(float(_ressorts[id].x) * 0.5, -0.25, 0.4)
		Plume.icone(self, str(c.get("icone", id)), Vector2(x0 + isz * 0.5, cy), isz * k, rien)
		var encre := P.SANG if plein else (Color(P.ENCRE, 0.45) if rien else P.ENCRE)
		var x := Plume.mot(self, g, Vector2(x0 + isz + 6.0, cy + 7.0), tn, 20, encre)
		if ts != "":
			Plume.mot(self, t, Vector2(x + 1.0, cy + 7.0), ts, 14, P.SANG if plein else Color(P.ENCRE_DOUCE, 0.7))
		Plume.milieu(self, t, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 44.0), str(c["nom"]), 14, Color(P.ENCRE_DOUCE, 0.5 if rien else 0.95))


# --- la planche : les choses, en tuiles, par sections ---

# une section : { titre, tuiles : [{ cle, id (son icône), nom, pale, n (son compte, 0 : rien à dire), marque (un mot dessous) }],
# vide (ce qu'on dit quand elle n'a rien), a_la_ligne (elle commence sa rangée) }. Les sections courtes se partagent une rangée. On touche une tuile : « choix ».
# Si tout ne tient pas, la planche défile sous le doigt (ou à la molette), et le dit d'un trait sur son bord.
class Planche extends Control:
	signal choix(cle: String)

	const LARGEUR := 96.0          # (la largeur d'une tuile, au moins : une cible pour le pouce)
	const TITRE := 23.0            # (la hauteur du titre d'une section)
	const ENTRE := 8.0
	var sections: Array = []
	var choisie := ""
	var _cases: Array = []         # [cle, son rectangle, sa tuile]
	var _titres: Array = []        # [ce qu'il dit, où, s'il est un texte (une section vide)]
	var _icone := 56.0
	var _haut := 0.0               # la hauteur de tout
	var _defile := 0.0
	var _elan := 0.0
	var _appui := Vector2.ZERO
	var _appui_defile := 0.0
	var _tenue := ""               # la tuile sous le doigt qui vient de se poser
	var _glisse := false
	var _doigt := false
	var _survol := ""
	var _sauts := {}               # la cle → un ressort : un compte qui vient de monter

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		resized.connect(_placer)
		set_process(false)

	func montrer(s: Array, cle: String) -> void:
		var avant := {}
		for c in _cases:
			avant[c[0]] = int(c[2].get("n", 0))
		sections = s
		choisie = cle
		_placer()
		for c in _cases:
			if avant.has(c[0]) and int(c[2].get("n", 0)) > int(avant[c[0]]):
				if not _sauts.has(c[0]):
					_sauts[c[0]] = Hud.Ressort.new()
				_sauts[c[0]].pousser(9.0)
				set_process(true)

	# la place de chaque tuile : les sections à la suite, dans la première rangée où elles tiennent
	func _placer() -> void:
		_cases.clear()
		_titres.clear()
		if size.x < 10.0:
			return
		var cap := T.capitales()
		var cols := maxi(2, int(size.x / LARGEUR))
		var tw := floorf(size.x / cols)
		var rangs: Array = []          # ce qui est déjà pris de chaque rangée, en largeur
		var titrees: Array = []        # cette rangée porte-t-elle un titre ? (une section y commence)
		var poses: Array = []          # [la section, sa rangée, son x]
		for s in sections:
			var n := int(s["tuiles"].size())
			var besoin := maxf(n * tw, Plume.large(cap, str(s["titre"]), 16) + 14.0)
			if n == 0 or n > cols or (bool(s.get("a_la_ligne", false)) and n == cols):
				# (elle prend des rangées entières ; la dernière peut se partager)
				poses.append([s, rangs.size(), 0.0])
				var pleines := 1 if n == 0 else int(ceil(float(n) / cols))
				for k in pleines:
					rangs.append(size.x)
					titrees.append(k == 0)
				if n > 0 and n % cols != 0:
					rangs[rangs.size() - 1] = (n % cols) * tw
				continue
			var ou := -1
			for i in rangs.size():
				var debut: float = float(rangs[i]) + (tw * 0.5 if float(rangs[i]) > 0.0 else 0.0)
				if debut + besoin <= size.x + 1.0 and not bool(s.get("a_la_ligne", false)):
					ou = i
					break
			if ou < 0:
				rangs.append(0.0)
				titrees.append(true)
				ou = rangs.size() - 1
			var x: float = float(rangs[ou]) + (tw * 0.5 if float(rangs[ou]) > 0.0 else 0.0)
			poses.append([s, ou, x])
			rangs[ou] = x + besoin
			titrees[ou] = true
		# (l'icône grandit tant que tout tient dans la hauteur)
		var nr := maxi(1, rangs.size())
		var nt := titrees.count(true)
		_icone = clampf(floorf((size.y - nt * TITRE - nr * (46.0 + ENTRE) + ENTRE) / nr), 44.0, 72.0)
		var th := _icone + 46.0
		var hauts: Array = []          # où commence chaque rangée
		var yr := 0.0
		for i in nr:
			hauts.append(yr)
			yr += th + ENTRE + (TITRE if i < titrees.size() and titrees[i] else 0.0)
		for q in poses:
			var s: Dictionary = q[0]
			var r0 := int(q[1])
			var y: float = hauts[r0] if r0 < hauts.size() else 0.0
			var x0: float = q[2]
			_titres.append([str(s["titre"]), Vector2(x0 + 4.0, y + 16.0), false])
			var tuiles: Array = s["tuiles"]
			if tuiles.is_empty():
				_titres.append([str(s.get("vide", "")), Vector2(x0 + 4.0, y + TITRE + 22.0), true])
			for i in tuiles.size():
				var col := i % cols
				var rang := r0 + i / cols
				var yt: float = float(hauts[rang]) + (TITRE if titrees[rang] else 0.0)
				_cases.append([str(tuiles[i]["cle"]), Rect2(x0 + col * tw, yt, tw, th), tuiles[i]])
		_haut = yr - ENTRE
		_defile = clampf(_defile, 0.0, _fond())
		queue_redraw()

	func _fond() -> float:
		return maxf(0.0, _haut - size.y)

	func _sous(p: Vector2) -> String:
		var q := p + Vector2(0.0, _defile)
		for c in _cases:
			if (c[1] as Rect2).has_point(q):
				return c[0]
		return ""

	# au clavier : la tuile la plus proche dans cette direction
	func deplacer(dir: Vector2) -> void:
		var ici := Rect2()
		for c in _cases:
			if c[0] == choisie:
				ici = c[1]
		if ici.size.x <= 0.0:
			if not _cases.is_empty():
				choix.emit(_cases[0][0])
			return
		var mieux := ""
		var d0 := 1.0e9
		for c in _cases:
			var v: Vector2 = (c[1] as Rect2).get_center() - ici.get_center()
			var devant := v.dot(dir)
			if c[0] == choisie or devant < 8.0:
				continue
			var d := devant + absf(v.dot(dir.orthogonal())) * 2.5
			if d < d0:
				d0 = d
				mieux = c[0]
		if mieux != "":
			choix.emit(mieux)

	# la tuile choisie reste en vue
	func montrer_choisie() -> void:
		for c in _cases:
			if c[0] == choisie:
				var r: Rect2 = c[1]
				_defile = clampf(_defile, r.end.y - size.y, r.position.y - TITRE)
				_defile = clampf(_defile, 0.0, _fond())
				queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP:
				if e.pressed and _fond() > 0.0:
					_defile = clampf(_defile + (70.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -70.0), 0.0, _fond())
					queue_redraw()
				accept_event()
			elif e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					_doigt = true
					_glisse = false
					_elan = 0.0
					_appui = e.position
					_appui_defile = _defile
					_tenue = _sous(e.position)
				elif _doigt:
					_doigt = false
					if not _glisse and _tenue != "" and _sous(e.position) == _tenue:
						choix.emit(_tenue)
					elif _glisse and absf(_elan) > 40.0:
						set_process(true)
					_tenue = ""
				queue_redraw()
				accept_event()
		elif e is InputEventMouseMotion:
			if _doigt:
				# (au-delà de quelques points, le doigt fait défiler : ce n'est plus un appui)
				if not _glisse and absf(e.position.y - _appui.y) > 9.0 and _fond() > 0.0:
					_glisse = true
				if _glisse:
					var avant := _defile
					_defile = clampf(_appui_defile - (e.position.y - _appui.y), 0.0, _fond())
					_elan = lerpf(_elan, (_defile - avant) * 60.0, 0.5)
					queue_redraw()
			else:
				var s := _sous(e.position)
				if s != _survol:
					_survol = s
					queue_redraw()

	func _notification(quoi: int) -> void:
		if quoi == NOTIFICATION_MOUSE_EXIT and _survol != "":
			_survol = ""
			queue_redraw()

	func _process(d: float) -> void:
		var reel := d / maxf(0.01, Engine.time_scale)
		var bouge := false
		# (l'élan : la planche continue un peu après le doigt)
		if not _doigt and absf(_elan) > 8.0:
			_defile = clampf(_defile + _elan * reel, 0.0, _fond())
			_elan *= exp(-reel * 5.0)
			if _defile <= 0.0 or _defile >= _fond():
				_elan = 0.0
			bouge = true
		for cle in _sauts:
			_sauts[cle].avancer(reel)
			if _sauts[cle].x != 0.0 or _sauts[cle].v != 0.0:
				bouge = true
		queue_redraw()
		if not bouge:
			set_process(false)

	func _draw() -> void:
		var bas := Transform2D(0.0, Vector2(0.0, -_defile))
		draw_set_transform_matrix(bas)
		var cap := T.capitales()
		var ital := T.titre_italique()
		for t in _titres:
			if t[2]:
				var y: float = (t[1] as Vector2).y
				for l in Plume.lignes(ital, str(t[0]), 18, size.x - 12.0):
					Plume.mot(self, ital, Vector2((t[1] as Vector2).x, y), l, 18, Color(P.ENCRE_DOUCE, 0.85))
					y += 23.0
			else:
				var fin := Plume.mot(self, cap, t[1], str(t[0]), 16, P.ENCRE)
				I.trait_encre(self, Vector2((t[1] as Vector2).x - 2.0, (t[1] as Vector2).y + 5.0), Vector2(fin + 10.0, (t[1] as Vector2).y + 4.0), 1.5, Color(P.ENCRE, 0.5))
		for c in _cases:
			_tuile(c[0], c[1], c[2], bas)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# (ce qui dépasse : un trait sur le bord, là où l'on en est)
		if _fond() > 0.0:
			var h := size.y * size.y / _haut
			var y0 := (size.y - h) * _defile / _fond()
			draw_line(Vector2(size.x - 2.0, 2.0), Vector2(size.x - 2.0, size.y - 2.0), Color(P.ENCRE, 0.14), 2.0)
			I.trait_encre(self, Vector2(size.x - 2.0, y0 + 2.0), Vector2(size.x - 2.0, y0 + h - 2.0), 4.0, Color(P.ENCRE, 0.6))

	func _tuile(cle: String, r: Rect2, tu: Dictionary, bas: Transform2D) -> void:
		var pale := bool(tu.get("pale", false))
		var dedans := r.grow_individual(-3.0, -1.0, -3.0, -3.0)
		if cle == choisie:
			draw_colored_polygon(Plume.galet(dedans, 7.0, 1.0), Color(P.ENCRE, 0.075))
			Plume.cadre(self, dedans, 2.3, Color(P.ENCRE, 0.9))
		elif cle == _tenue and _doigt and not _glisse:
			draw_colored_polygon(Plume.galet(dedans, 7.0, 1.0), Color(P.ENCRE, 0.11))
		elif cle == _survol:
			draw_colored_polygon(Plume.galet(dedans, 7.0, 1.0), Color(P.ENCRE, 0.04))
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 6.0 + _icone * 0.5)
		Plume.icone(self, str(tu["id"]), c, _icone, pale, bas)
		# (son compte : un petit jeton d'encre, au coin de l'icône)
		var n := int(tu.get("n", 0))
		if n > 0:
			var k := 1.0
			if _sauts.has(cle):
				k += clampf(float(_sauts[cle].x) * 0.6, -0.2, 0.6)
			# (une tuile à étiquette : le jeton monte au coin du haut, l'étiquette tient le bas)
			var cj := c + Vector2(_icone * 0.44, _icone * (-0.34 if str(tu.get("etiquette", "")) != "" else 0.36))
			var g := T.texte_gras()
			I.disque(self, cj, 11.0 * k, P.PAPIER)
			I.disque(self, cj, 9.5 * k, P.ENCRE)
			Plume.milieu(self, g, cj + Vector2(0.0, 4.6), str(n), 13, P.PAPIER)
		# (son étiquette : un mot sur un bout de papier, au pied de l'icône — la vertu d'une herbe, qu'un nom long ne chasse pas)
		var etiquette := str(tu.get("etiquette", ""))
		if etiquette != "":
			var fe := T.titre_italique()
			var le := Plume.large(fe, etiquette, 14) + 12.0
			var re := Rect2(c.x - le * 0.5, r.position.y + _icone - 9.0, le, 18.0)
			draw_colored_polygon(Plume.galet(re, 5.0, 1.0), P.PAPIER)
			var bord_e := Plume.galet(re, 5.0, 1.0)
			bord_e.append(bord_e[0])
			draw_polyline(bord_e, Color(P.ENCRE, 0.55), 1.0, true)
			Plume.milieu(self, fe, Vector2(c.x, re.position.y + 13.5), etiquette, 14, P.SANG)
		var f := T.texte_moyen()
		var encre := Color(P.ENCRE_DOUCE, 0.6) if pale else P.ENCRE
		var y := r.position.y + _icone + 21.0
		var noms := Plume.lignes(f, str(tu["nom"]), 15, r.size.x - 8.0)
		for i in mini(2, noms.size()):
			Plume.milieu(self, f, Vector2(c.x, y), noms[i], 15, encre)
			y += 16.0
		var marque := str(tu.get("marque", ""))
		if marque != "" and noms.size() < 2:
			Plume.milieu(self, T.titre_italique(), Vector2(c.x, y + 1.0), marque, 15, P.SANG)


# --- la fiche : la chose choisie, et son bouton ---

# ce qu'elle montre : { id (l'icône), pale, nom, etat (une ligne sous le nom), dit (sa phrase), entete ([à gauche, à droite] :
# au-dessus des lignes), lignes, bouton (le mot ; "" : pas de bouton), actif, pourquoi (sous un bouton éteint : la raison) }
# une ligne : ["cout", l'icône, le nom, ce qu'on a, ce qu'il faut] · ["jauge", le nom, de 0 à 1, ce qu'on en dit] ·
# ["gouttes", combien, sur combien] · ["note", une phrase]
class Fiche extends Control:
	const PLANCHE := 178.0          # la hauteur d'une planche de l'herbier, dans une fiche
	signal action

	var d := {}
	var _r_bouton := Rect2()
	var _presse := false
	var _appui := 0.0
	var _survol := false
	var _tampon := -1.0            # le tampon « Fait » : depuis quand il tombe (-1 : aucun)
	var _tampon_mot := ""
	var _saut := Hud.Ressort.new()
	var _comptes := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)

	func montrer(dd: Dictionary) -> void:
		# (les comptes qui changent sous les yeux sautillent : on voit ce que le geste a pris, a donné)
		var comptes := str(dd.get("etat", "")) + str(dd.get("lignes", []))
		if str(dd.get("nom", "")) == str(d.get("nom", "")) and comptes != _comptes and _comptes != "":
			_saut.pousser(6.0)
			set_process(true)
		if str(dd.get("nom", "")) != str(d.get("nom", "")):
			_tampon = -1.0
		_comptes = comptes
		d = dd
		queue_redraw()

	# un tampon de sang séché tombe au coin de la fiche : c'est fait
	func tamponner(mot: String) -> void:
		_tampon = 0.0
		_tampon_mot = mot
		set_process(true)

	# le bouton, pressé d'ailleurs (la touche Entrée)
	func presser() -> void:
		if _peut():
			_appui = 1.0
			set_process(true)
			action.emit()

	func _peut() -> bool:
		return str(d.get("bouton", "")) != "" and bool(d.get("actif", false))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_presse = _peut() and _r_bouton.grow(6.0).has_point(e.position)
				if _presse:
					set_process(true)
			else:
				if _presse and _r_bouton.grow(14.0).has_point(e.position):
					action.emit()
				_presse = false
			accept_event()
		elif e is InputEventMouseMotion:
			var s := _peut() and _r_bouton.has_point(e.position)
			if s != _survol:
				_survol = s
				queue_redraw()

	func _notification(quoi: int) -> void:
		if quoi == NOTIFICATION_MOUSE_EXIT and _survol:
			_survol = false
			queue_redraw()

	func _process(dt: float) -> void:
		var reel := dt / maxf(0.01, Engine.time_scale)
		_appui = move_toward(_appui, 1.0 if _presse else 0.0, reel * (16.0 if _presse else 7.0))
		_saut.avancer(reel)
		if _tampon >= 0.0:
			_tampon += reel
			if _tampon > 1.9:
				_tampon = -1.0
		queue_redraw()
		if not _presse and _appui <= 0.0 and _tampon < 0.0 and _saut.x == 0.0 and _saut.v == 0.0:
			set_process(false)

	func _draw() -> void:
		var w := size.x
		var titre := T.titre()
		var ital := T.titre_italique()
		var txt := T.texte_moyen()
		var gras := T.texte_gras()
		if d.is_empty():
			var y0 := size.y * 0.4
			for l in Plume.lignes(ital, "Touche une chose de la planche : sa fiche vient ici.", 19, w - 40.0):
				Plume.milieu(self, ital, Vector2(w * 0.5, y0), l, 19, Color(P.ENCRE_DOUCE, 0.8))
				y0 += 24.0
			_r_bouton = Rect2()
			return
		var a_bouton := str(d.get("bouton", "")) != ""
		var actif := bool(d.get("actif", false))
		# --- le bas : le bouton, toujours à la même place ; au-dessus, ce qui l'empêche
		var bh := 56.0
		var bw := minf(w, 300.0)
		var bas := size.y
		if a_bouton:
			_r_bouton = Rect2((w - bw) * 0.5, size.y - bh - 2.0, bw, bh)
			bas = _r_bouton.position.y - 8.0
		else:
			_r_bouton = Rect2()
		var pourquoi := str(d.get("pourquoi", ""))
		var raisons := PackedStringArray()
		if pourquoi != "":
			raisons = Plume.lignes(ital, pourquoi, 18, w - 8.0)
			bas -= raisons.size() * 22.0 + 2.0
		# --- le haut : l'icône, le nom, l'état ; la phrase ; les lignes. S'il manque de la place, le tout rapetisse un peu
		var isz := 76.0
		var dit := Plume.lignes(ital, str(d.get("dit", "")), 19, w - 6.0)
		var lignes: Array = d.get("lignes", [])
		var entete: Array = d.get("entete", [])
		var besoin := isz + 8.0 + dit.size() * 23.0 + 8.0
		if not entete.is_empty():
			besoin += 24.0
		var notes := {}
		for i in lignes.size():
			if str(lignes[i][0]) == "note":
				notes[i] = Plume.lignes(txt, str(lignes[i][1]), 16, w - 8.0)
				besoin += (notes[i] as PackedStringArray).size() * 20.0 + 6.0
			elif str(lignes[i][0]) == "planche":
				besoin += PLANCHE + 8.0
			else:
				besoin += 31.0
		var k := clampf(bas / maxf(1.0, besoin), 0.7, 1.0)
		draw_set_transform(Vector2(w * (1.0 - k) * 0.5, 0.0), 0.0, Vector2(k, k))
		var ci := Vector2(isz * 0.5 + 2.0, isz * 0.5 + 1.0)
		Plume.icone(self, str(d["id"]), ci, isz, bool(d.get("pale", false)), Transform2D(0.0, Vector2(k, k), 0.0, Vector2(w * (1.0 - k) * 0.5, 0.0)))
		var nx := isz + 16.0
		var nom := str(d.get("nom", ""))
		var ns := 30
		while ns > 20 and Plume.large(titre, nom, ns) > w - nx:
			ns -= 1
		Plume.mot(self, titre, Vector2(nx, 32.0), nom, ns, P.ENCRE)
		var ye := 55.0
		var saute := 1.0 + clampf(_saut.x * 0.35, -0.12, 0.2)
		for l in Plume.lignes(txt, str(d.get("etat", "")), 17, w - nx):
			draw_string(txt, Vector2(nx, ye), l, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(17.0 * saute)), d.get("etat_encre", P.ENCRE_DOUCE))
			ye += 20.0
		var y := isz + 8.0 + 17.0
		for l in dit:
			Plume.mot(self, ital, Vector2(3.0, y), l, 19, P.ENCRE)
			y += 23.0
		y += 8.0 - 17.0
		if not entete.is_empty():
			Plume.mot(self, T.capitales(), Vector2(3.0, y + 15.0), str(entete[0]), 16, P.ENCRE)
			if entete.size() > 1:
				Plume.a_droite(self, ital, Vector2(w - 4.0, y + 15.0), str(entete[1]), 15, Color(P.ENCRE_DOUCE, 0.8))
			I.trait_encre(self, Vector2(0.0, y + 21.0), Vector2(w, y + 20.0), 1.4, Color(P.ENCRE, 0.5))
			y += 24.0
		for i in lignes.size():
			var l: Array = lignes[i]
			match str(l[0]):
				"cout":
					var a := int(l[3])
					var faut := int(l[4])
					var assez := a >= faut
					Plume.icone(self, str(l[1]), Vector2(17.0, y + 15.0), 27.0, false, Transform2D(0.0, Vector2(k, k), 0.0, Vector2(w * (1.0 - k) * 0.5, 0.0)))
					Plume.mot(self, txt, Vector2(38.0, y + 21.0), str(l[2]), 18, P.ENCRE)
					var encre := P.ENCRE if assez else P.SANG
					var xd := w - 30.0
					xd = Plume.a_droite(self, gras, Vector2(xd, y + 21.0), str(faut), 19, encre)
					xd = Plume.a_droite(self, txt, Vector2(xd - 3.0, y + 21.0), "/", 17, Color(encre, 0.7))
					Plume.a_droite(self, gras, Vector2(xd - 3.0, y + 21.0), str(a), int(round(19.0 * saute)), encre)
					if assez:
						Plume.coche(self, Vector2(w - 12.0, y + 15.0), 15.0, Color(P.ENCRE, 0.85))
					else:
						I.disque(self, Vector2(w - 12.0, y + 15.0), 3.4, P.SANG)
					y += 31.0
				"jauge":
					var v := clampf(float(l[2]), 0.0, 1.0)
					var x1 := Plume.mot(self, txt, Vector2(3.0, y + 21.0), str(l[1]), 18, P.ENCRE) + 12.0
					var x2 := Plume.a_droite(self, gras, Vector2(w - 4.0, y + 21.0), str(l[3]), int(round(19.0 * saute)), P.ENCRE) - 12.0
					var rj := Rect2(x1, y + 8.0, maxf(20.0, x2 - x1), 15.0)
					draw_colored_polygon(Plume.galet(rj, 6.0, 2.0), Color(P.ENCRE, 0.1))
					if v > 0.01:
						var plein := Rect2(rj.position, Vector2(maxf(13.0, rj.size.x * v), rj.size.y))
						draw_colored_polygon(Plume.galet(plein, 6.0, 2.0), P.BRAISE if v > 0.15 else P.BRAISE_ROUGE)
					var bord := Plume.galet(rj, 6.0, 2.0)
					bord.append(bord[0])
					draw_polyline(bord, P.ENCRE, 1.6, true)
					y += 31.0
				"gouttes":
					for g in int(l[2]):
						Plume.icone(self, "eau", Vector2(18.0 + g * 31.0, y + 15.0), 28.0, g >= int(l[1]), Transform2D(0.0, Vector2(k, k), 0.0, Vector2(w * (1.0 - k) * 0.5, 0.0)))
					y += 31.0
				"note":
					for n in (notes[i] as PackedStringArray):
						Plume.mot(self, txt, Vector2(3.0, y + 16.0), n, 16, P.ENCRE_DOUCE)
						y += 20.0
					y += 6.0
				"planche":
					# (la planche de l'herbe, à l'encre : scripts/herbier_planches.gd ; dessinée dans le repère de la fiche)
					var pl = Plume.planches()
					var decal := Vector2(w * (1.0 - k) * 0.5, 0.0)
					var cadre := Rect2(decal + Vector2(6.0, y + 2.0) * k, Vector2(w - 12.0, PLANCHE) * k)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					if pl != null:
						pl.planche(self, str(l[1]), cadre, str(l[2]), bool(l[3]))
					else:
						Plume.icone(self, "simples", cadre.get_center(), minf(cadre.size.x, cadre.size.y) * 0.7, not bool(l[3]))
					draw_set_transform(decal, 0.0, Vector2(k, k))
					y += PLANCHE + 8.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# --- ce qui empêche, puis le bouton
		var yr := bas + 19.0
		for l in raisons:
			Plume.milieu(self, ital, Vector2(w * 0.5, yr), l, 18, d.get("pourquoi_encre", P.SANG))
			yr += 22.0
		if a_bouton:
			_bouton(str(d["bouton"]), actif)
		if _tampon >= 0.0:
			_tamponner(Vector2(w - 44.0, 42.0))

	# le bouton : une étiquette d'encre pleine, le mot en clair ; éteint, il n'en reste que le contour pâle
	func _bouton(mot: String, actif: bool) -> void:
		var f := T.titre()
		var r := _r_bouton
		var k := 1.0 - 0.04 * _appui
		var c := r.get_center()
		draw_set_transform(c * (1.0 - k) + Vector2(0.0, 1.5 * _appui), 0.0, Vector2(k, k))
		var forme := Plume.galet(r, 9.0, 4.0)
		var tour := forme.duplicate()
		tour.append(forme[0])
		if actif:
			draw_colored_polygon(forme, P.ENCRE.lerp(P.SANG, 0.55 * _appui + (0.12 if _survol else 0.0)))
			draw_polyline(tour, P.ENCRE, 2.0, true)
			var dedans := Plume.galet(r.grow(-5.0), 6.0, 7.0)
			dedans.append(dedans[0])
			draw_polyline(dedans, Color(P.PAPIER, 0.3), 1.2, true)
			Plume.milieu(self, f, Vector2(c.x, c.y + 9.5), mot, 28, P.PAPIER.lerp(P.BRAISE_COEUR, _appui))
		else:
			draw_colored_polygon(forme, Color(P.ENCRE, 0.045))
			draw_polyline(tour, Color(P.ENCRE, 0.3), 1.5, true)
			Plume.milieu(self, f, Vector2(c.x, c.y + 9.5), mot, 28, Color(P.ENCRE, 0.34))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# le tampon : il tombe (plus grand, il se pose), il marque, puis l'encre s'en va
	func _tamponner(c: Vector2) -> void:
		var chute := clampf(_tampon / 0.13, 0.0, 1.0)
		var k := lerpf(1.9, 1.0, 1.0 - pow(1.0 - chute, 3.0))
		var a := clampf(_tampon / 0.08, 0.0, 1.0) * (1.0 - smoothstep(1.3, 1.9, _tampon)) * 0.9
		var encre := Color(P.SANG.lerp(P.BRAISE_ROUGE, 0.25), a)
		var rot := deg_to_rad(-13.0)
		var f := T.capitales()
		draw_set_transform(c, rot, Vector2(k, k))
		draw_arc(Vector2.ZERO, 32.0, 0.25, PI * 0.93, 22, encre, 3.4, true)
		draw_arc(Vector2.ZERO, 32.0, PI * 1.02, TAU - 0.06, 26, encre, 3.4, true)
		draw_arc(Vector2.ZERO, 26.5, 0.0, TAU, 40, Color(encre, a * 0.75), 1.3, true)
		var lw := Plume.large(f, _tampon_mot, 21)
		draw_string(f, Vector2(-lw * 0.5, 7.0), _tampon_mot, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, encre)
		for sx in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(sx * 3.5, -15.0), Vector2(0.0, -18.0), Vector2(-sx * 3.5, -15.0), Vector2(0.0, -12.0)]), encre)
		draw_colored_polygon(PackedVector2Array([Vector2(3.5, 17.0), Vector2(0.0, 14.0), Vector2(-3.5, 17.0), Vector2(0.0, 20.0)]), encre)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- une feuille : ce que la page de l'établi et celle du sac ont en commun ---

class Feuille extends Control:
	signal fermer

	var jeu
	var atelier
	var tactile := false
	var haut_reserve := 0.0        # (ce qu'il faut laisser libre en haut de l'écran, si quelque chose doit s'y voir encore)
	var page: Carnet.Page
	var _voile: ColorRect
	var _corps: Control
	var _titre: Label
	var _sous: Label
	var _filet: Carnet.Filet
	var _fermer: Bouton
	var _bande: Bande
	var _planche: Planche
	var _fiche: Fiche
	var _choisie := ""
	var _sous_clavier := ""
	var _sous_doigt := ""
	var _t := 0.0
	var _lu := 0.0
	var _signature := ""
	var _retard := 0.0             # (le tampon tombe : les comptes changent quand il touche)
	var _separe := 0.0

	func _init(titre: String = "", sous_clavier: String = "", sous_doigt: String = "", graine: float = 5.0) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		theme = T.theme()
		_sous_clavier = sous_clavier
		_sous_doigt = sous_doigt
		_voile = ColorRect.new()
		_voile.color = Color(P.NUIT, 0.66)
		_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_voile)
		page = Carnet.Page.new(graine)
		add_child(page)
		_corps = Control.new()
		_corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.contenu.add_child(_corps)
		_titre = Carnet.Encre.libelle(titre, T.titre(), 36, P.ENCRE, false)
		_corps.add_child(_titre)
		_sous = Carnet.Encre.libelle(sous_clavier, T.titre_italique(), 18, P.ENCRE_DOUCE, false)
		_corps.add_child(_sous)
		_fermer = Bouton.new("Fermer", 24, true, true)
		_fermer.focus_mode = Control.FOCUS_NONE
		_fermer.pressed.connect(refermer)
		_corps.add_child(_fermer)
		_filet = Carnet.Filet.new(1.0)
		_corps.add_child(_filet)
		_bande = Bande.new()
		_corps.add_child(_bande)
		_planche = Planche.new()
		_planche.choix.connect(_choisir)
		_corps.add_child(_planche)
		_fiche = Fiche.new()
		_fiche.action.connect(_sur_le_bouton)
		_corps.add_child(_fiche)
		_corps.draw.connect(_tracer)
		_corps.resized.connect(_ranger)
		resized.connect(_disposer)

	func mettre_tactile(oui: bool) -> void:
		tactile = oui
		_sous.text = _sous_doigt if oui else _sous_clavier
		# (sur un téléphone, le bouton de pause se dessine en haut, au milieu, par-dessus la page : scripts/tactile.gd.
		# Le haut de la feuille lui laisse son milieu libre, et le filet y perd son losange)
		_filet.visible = not oui
		_disposer()

	func ouvrir(jeu_) -> void:
		jeu = jeu_
		atelier = jeu.atelier if jeu != null else null
		visible = true
		_t = 0.0
		_lu = 0.0
		_retard = 0.0
		_signature = ""
		_disposer()
		_relire(true)
		_animer()

	# la page se ferme d'elle-même, et le dit
	func refermer() -> void:
		if not visible:
			return
		visible = false
		fermer.emit()

	# la feuille tient presque tout l'écran : un téléphone couché n'a pas de hauteur à perdre
	func _disposer() -> void:
		var s := size
		if s.x < 10.0:
			return
		var bas := s.y < 640.0
		var ps := Vector2(minf(1190.0, s.x - (36.0 if s.x >= 1100.0 else 16.0)), minf(684.0, s.y - haut_reserve - (20.0 if bas else 36.0)))
		page.size = ps
		page.position = Vector2((s.x - ps.x) * 0.5, haut_reserve + (s.y - haut_reserve - ps.y) * 0.5)
		page.marges(30 if s.x >= 1100.0 else 20, 14 if bas else 20)
		_ranger()

	# chaque morceau à sa place dans la feuille : le titre et « Fermer », la bande, la planche à gauche, la fiche à droite
	func _ranger() -> void:
		var s := _corps.size
		if s.x < 10.0:
			return
		_titre.reset_size()
		_titre.position = Vector2(0.0, -6.0)
		_sous.reset_size()
		_sous.position = Vector2(_titre.size.x + 18.0, 14.0)
		_sous.visible = _sous.position.x + _sous.size.x < (s.x * 0.5 - 36.0 if tactile else s.x - _fermer.size.x - 8.0)
		_fermer.reset_size()
		_fermer.position = Vector2(s.x - _fermer.size.x + 14.0, -6.0)
		_filet.position = Vector2(0.0, 40.0)
		_filet.size = Vector2(s.x, 12.0)
		_bande.position = Vector2(0.0, 54.0)
		_bande.size = Vector2(s.x, Bande.HAUT)
		var y := 54.0 + Bande.HAUT + 10.0
		var fw := clampf(s.x * 0.36, 300.0, 420.0)
		_fiche.position = Vector2(s.x - fw, y)
		_fiche.size = Vector2(fw, s.y - y)
		_planche.position = Vector2(0.0, y)
		_planche.size = Vector2(s.x - fw - 30.0, s.y - y)
		_separe = s.x - fw - 15.0
		_corps.queue_redraw()

	func _tracer() -> void:
		var y := _planche.position.y
		if tactile:
			var m := _corps.size.x * 0.5
			I.trait_encre(_corps, Vector2(0.0, 46.0), Vector2(m - 40.0, 46.0), 1.8, Color(P.ENCRE, 0.7))
			I.trait_encre(_corps, Vector2(m + 40.0, 46.0), Vector2(_corps.size.x, 46.0), 1.8, Color(P.ENCRE, 0.7))
		I.trait_encre(_corps, Vector2(0.0, y - 6.0), Vector2(_corps.size.x, y - 5.0), 1.4, Color(P.ENCRE, 0.4))
		I.trait_encre(_corps, Vector2(_separe, y + 4.0), Vector2(_separe + 1.0, _corps.size.y - 2.0), 1.8, Color(P.ENCRE, 0.5))

	func _animer() -> void:
		var u := smoothstep(0.0, 0.22, _t)
		_voile.color.a = 0.66 * u
		page.modulate.a = u
		page.position.y = haut_reserve + (size.y - haut_reserve - page.size.y) * 0.5 + 12.0 * (1.0 - u)

	func _process(d: float) -> void:
		if not visible:
			return
		# (le temps vrai : qu'elle dorme ou que le jeu ralentisse, la page garde son pas)
		var reel := d / maxf(0.01, Engine.time_scale)
		if _t < 0.3:
			_t += reel
			_animer()
		else:
			_t += reel
		# (la touche de pause, ou le bouton du haut d'un téléphone : ici, elle ferme la page)
		if _t > 0.12 and _touche_de_pause():
			refermer()
			return
		if _retard > 0.0:
			_retard -= reel
			if _retard <= 0.0:
				_relire(true)
			return
		_lu += reel
		if _lu >= 0.33:
			_lu = 0.0
			_relire(false)

	func _touche_de_pause() -> bool:
		if InputMap.has_action("pause"):
			return Input.is_action_just_pressed("pause")
		return Input.is_action_just_pressed("ui_cancel")

	func _unhandled_input(e: InputEvent) -> void:
		if not visible or not (e is InputEventKey) or not e.pressed:
			return
		var dir := Vector2.ZERO
		if e.is_action_pressed("ui_left", true):
			dir = Vector2.LEFT
		elif e.is_action_pressed("ui_right", true):
			dir = Vector2.RIGHT
		elif e.is_action_pressed("ui_up", true):
			dir = Vector2.UP
		elif e.is_action_pressed("ui_down", true):
			dir = Vector2.DOWN
		if dir != Vector2.ZERO:
			_planche.deplacer(dir)
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_accept") and not e.echo:
			_fiche.presser()
			get_viewport().set_input_as_handled()

	func _choisir(cle: String) -> void:
		if cle == _choisie:
			return
		_choisie = cle
		_relire(true)
		_planche.montrer_choisie()

	func _sur_le_bouton() -> void:
		if _retard > 0.0 or atelier == null:
			return
		var mot := _faire(_choisie)
		if not visible:
			return
		if mot != "":
			# (le geste est fait ; la page le montre quand le tampon touche le papier)
			_fiche.tamponner(mot)
			_retard = 0.12
		else:
			_relire(true)

	# tout relire de l'atelier ; ne rien refaire si rien n'a changé
	func _relire(force: bool) -> void:
		if atelier == null or jeu == null or jeu.joueur == null:
			return
		var groupes := _groupes()
		var sections := _sections()
		var cles := []
		for s in sections:
			for tu in s["tuiles"]:
				cles.append(str(tu["cle"]))
		if not cles.has(_choisie):
			_choisie = _par_defaut(cles)
		var fiche := _fiche_de(_choisie) if _choisie != "" else {}
		var signature := str([groupes, sections, fiche, _choisie])
		if signature == _signature and not force:
			return
		_signature = signature
		_bande.montrer(groupes)
		_planche.montrer(sections, _choisie)
		_fiche.montrer(fiche)

	# --- ce que chaque page dit à sa façon ---

	func _groupes() -> Array:
		return []

	func _sections() -> Array:
		return []

	func _par_defaut(cles: Array) -> String:
		return str(cles[0]) if not cles.is_empty() else ""

	func _fiche_de(_cle: String) -> Dictionary:
		return {}

	# le bouton de la fiche : fait ce qu'il dit ; rend le mot du tampon ("" : pas de tampon)
	func _faire(_cle: String) -> String:
		return ""

	# --- ce qu'elles lisent de la même façon ---

	# les huit matières : leur compte sur ce qu'elle peut en porter (l'eau : sur ce que tient la gourde)
	func _matieres() -> Array:
		var cases := []
		for k in Atelier.MATIERES:
			# (ce que seuls certains pays donnent ne se montre qu'une fois trouvé : scripts/biomes.gd)
			if (k == "obsidienne" or k == "tourbe") and atelier.possede(k) <= 0:
				continue
			var sur: int = atelier.capacite()
			if k == "eau":
				sur = Atelier.GORGEES if atelier.possede("gourde") > 0 else 0
			cases.append({"id": k, "nom": Plume.majuscule(str(Atelier.NOMS_MATIERES.get(k, k))), "n": atelier.possede(k), "sur": sur})
		return cases

	func _nom(id: String) -> String:
		return str(Atelier.OBJETS[id]["nom"])

	# combien de ces choses sont posées dans le lieu
	func _posees(id: String) -> int:
		var n := 0
		for s in atelier.poses:
			if is_instance_valid(s) and str(s.genre) == id:
				n += 1
		return n

	# la fiche d'une chose à fabriquer : ce qu'elle coûte, ce qu'on a, et « Fabriquer »
	func _fiche_a_fabriquer(id: String) -> Dictionary:
		var o: Dictionary = Atelier.OBJETS[id]
		var n: int = atelier.possede(id)
		var etat := ""
		if Atelier.MATIERES.has(id):
			etat = "Tu en portes %d." % n if n > 0 else "Tu n'en as pas."
		else:
			var la := _posees(id)
			if n > 0 and la > 0:
				etat = "Tu en as %d dans ton sac, %d dans le lieu." % [n, la]
			elif n > 0:
				etat = "Tu en as %d." % n
			elif la > 0:
				etat = "Tu en as %d, dans le lieu." % la
			else:
				etat = "Tu n'en as pas encore."
		var lignes := []
		for k in o["cout"]:
			lignes.append(["cout", k, Plume.majuscule(str(Atelier.NOMS_MATIERES.get(k, k))), atelier.possede(k), int(o["cout"][k])])
		var pourquoi: String = atelier.empeche(id)
		return {"id": id, "pale": false, "nom": str(o["nom"]), "etat": etat, "dit": str(o["dit"]), "entete": ["Il te faut", "tu as / il faut"],
			"lignes": lignes, "bouton": "Fabriquer", "actif": pourquoi == "", "pourquoi": pourquoi}


# --- la page de l'établi ---

class Etabli extends Feuille:
	func _init() -> void:
		super("L'établi", "Choisis une chose, puis « Fabriquer ».", "Touche une chose, puis « Fabriquer ».", 5.0)

	func _groupes() -> Array:
		return [{"titre": "Dans ton sac · %d de chaque, au plus" % int(atelier.capacite()), "cases": _matieres()}]

	func _sections() -> Array:
		var out := []
		for fam in Atelier.FAMILLES:
			var tuiles := []
			for id in Atelier.ORDRE:
				if str(Atelier.OBJETS[id]["famille"]) == str(fam[0]):
					tuiles.append({"cle": id, "id": id, "nom": _nom(id), "pale": not atelier.peut(id), "n": atelier.possede(id)})
			out.append({"titre": str(fam[1]), "tuiles": tuiles})
		return out

	# (d'abord l'établi lui-même tant qu'on n'en a pas ; sinon la première chose qu'on peut faire)
	func _par_defaut(cles: Array) -> String:
		for id in cles:
			if atelier.peut(str(id)):
				return str(id)
		return "etabli" if cles.has("etabli") else super(cles)

	func _fiche_de(cle: String) -> Dictionary:
		return _fiche_a_fabriquer(cle)

	func _faire(cle: String) -> String:
		return "Fait" if atelier.fabriquer(cle) else ""


# --- la page du sac ---

class Sac extends Feuille:
	func _init() -> void:
		super("Le sac", "Ce que tu as sur toi. Choisis une chose pour t'en servir.", "Ce que tu as sur toi. Touche une chose pour t'en servir.", 8.0)

	func _groupes() -> Array:
		var manger := []
		var inv: Dictionary = jeu.joueur.inventaire
		for k in NOURRITURE:
			manger.append({"id": k, "nom": Plume.majuscule(str(R.NOMS.get(k, NOMS_CUEILLETTE.get(k, k)))), "n": int(inv.get(k, 0)), "sur": 0})
		# (les fruits, les grains, le lichen, la pulpe, et ce que la popote en a fait : une fois qu'elle en a)
		for k in Atelier.NOURRITURE_CUEILLIE:
			if int(inv.get(k, 0)) > 0:
				manger.append({"id": k, "nom": str(NOMS_COURTS[k]), "n": int(inv.get(k, 0)), "sur": 0})
		# (trop de choses pour la bande : ce qu'elle n'a pas s'efface, pour que chaque nom se lise)
		if manger.size() > 8:
			manger = manger.filter(func(c): return int(c["n"]) > 0)
		return [{"titre": "Ce que tu portes · %d de chaque, au plus" % int(atelier.capacite()), "cases": _matieres()}, {"titre": "À manger", "cases": manger}]

	# ce qui est posé à portée de main, et qui se replie (un vestige ne se replie pas)
	func _juste_la():
		var s = atelier._la_plus_proche(Atelier.PORTEE)
		if s == null or not Atelier.OBJETS.has(str(s.genre)):
			return null
		return s

	func _sections() -> Array:
		var out := []
		var J = jeu.jardin
		var E = jeu.elevage
		var inv: Dictionary = jeu.joueur.inventaire
		var mains := [{"cle": "fab:etabli", "id": "etabli", "nom": "Faire un établi", "pale": not atelier.peut("etabli")}]
		if atelier.possede("houe") > 0:
			mains.append({"cle": "act:becher", "id": "carre", "nom": "Bêcher un carré", "pale": J.empeche_becher() != ""})
		if atelier.possede("licol") > 0 or not E.betes.is_empty():
			mains.append({"cle": "act:appat", "id": "appat", "nom": "Poser un appât", "pale": E.empeche_appat() != ""})
		# (l'herbier : dès qu'elle a cueilli une herbe)
		var B = jeu.botanique
		if not B.savoir.is_empty() or not B.sac().is_empty():
			mains.append({"cle": "page:herbier", "id": "herbier", "nom": "L'herbier"})
		# (la carte : y écrire ce qui est là, y rayer un repère ; scripts/reperes.gd)
		if atelier.possede("carte") > 0:
			mains.append({"cle": "page:carte", "id": "plume" if atelier.possede("plume") > 0 else "carte", "nom": "Écrire sur la carte" if atelier.possede("plume") > 0 else "La carte"})
		out.append({"titre": "De tes mains", "tuiles": mains})
		# juste là : ce qui se replie, le carré de jardin devant elle, sa bête
		var la := []
		var s = _juste_la()
		if s != null:
			la.append({"cle": "pose", "id": str(s.genre), "nom": _nom(str(s.genre)), "marque": "à replier"})
		var carre = _carre()
		if carre != null:
			if str(carre.etat.get("culture", "")) == "":
				for c in Jardin.ORDRE:
					var g := str(Jardin.CULTURES[c]["graine"])
					la.append({"cle": "semer:" + c, "id": g, "nom": "Semer : %s" % str(Jardin.CULTURES[c]["nom"]).to_lower(), "pale": J.graines(c) < Jardin.GRAINES, "n": J.graines(c)})
				# (les herbes reconnues se sèment aussi, de leurs propres plants)
				var herbes: Dictionary = B.sac()
				for id in herbes:
					if B.sue(id):
						la.append({"cle": "semer:" + id, "id": "h:" + id, "nom": "Semer : %s" % B.nom(id).to_lower(), "pale": int(herbes[id]) < Jardin.GRAINES, "n": int(herbes[id])})
			elif J.mur(carre):
				la.append({"cle": "recolter", "id": "carre", "nom": "Récolter", "marque": "mûr"})
			else:
				la.append({"cle": "arroser", "id": "arrosoir", "nom": "Arroser", "pale": atelier.possede("arrosoir") <= 0 or J.arrosages() <= 0})
			la.append({"cle": "combler", "id": "carre", "nom": "Le carré", "marque": "à combler"})
		var b = E.pres(Elevage.PORTEE + 24.0)
		if b != null:
			la.append({"cle": "bete:suite", "id": "bete", "nom": str(b.nom), "marque": "te suit" if bool(b.suit_la) else "reste là"})
			if bool(b.harnais.get("selle", false)):
				la.append({"cle": "bete:monter", "id": "selle", "nom": "La monter", "pale": E.empeche_monter(b) != ""})
			elif float(b.masse) >= Elevage.MASSE_SELLE:
				la.append({"cle": "bete:selle", "id": "selle", "nom": "La seller", "pale": E.empeche_harnacher(b, "selle") != ""})
			if not bool(b.harnais.get("sacoche", false)) and float(b.masse) >= Elevage.MASSE_SACOCHE:
				la.append({"cle": "bete:sacoche", "id": "sacoche", "nom": "Ses sacoches", "pale": E.empeche_harnacher(b, "sacoche") != ""})
			if float(b.masse) >= Elevage.MASSE_LAIT:
				la.append({"cle": "bete:traire", "id": "lait", "nom": "La traire", "pale": E.empeche_traire(b) != ""})
			la.append({"cle": "bete:liberer", "id": "licol", "nom": "La relâcher"})
		if not la.is_empty():
			out.append({"titre": "Juste là", "tuiles": la})
		# ce que le jardin et les bêtes lui donnent : les simples, le lait, les graines
		var dons := []
		for k in DU_JARDIN:
			var n := int(inv.get(k, 0))
			if n > 0:
				dons.append({"cle": ("use:" if k in ["simples", "lait"] else "graine:") + k, "id": k, "nom": str(NOMS_DU_JARDIN[k]), "n": n})
		# (ce qu'elle a cueilli et qui sert : des fleurs à infuser, une infusion à boire, une amanite à piler)
		for k in CUEILLETTE + CUEILLETTE_NOURRICIERE:
			var nc := int(inv.get(k, 0))
			if nc > 0:
				dons.append({"cle": "use:" + k, "id": k, "nom": str(NOMS_CUEILLETTE.get(k, NOMS_NOURRICIERS.get(k, k))), "n": nc, "pale": _empeche_cueillette(k) != ""})
		# (et ce qu'elle a préparé de ses herbes : scripts/botanique.gd)
		for p in Botanique.ORDRE_PREPARATIONS:
			if int(inv.get(p, 0)) > 0:
				dons.append({"cle": "prep:" + p, "id": p, "nom": str(Botanique.PREPARATIONS[p]["nom"]), "n": int(inv[p]), "pale": B.empeche_utiliser(p) != ""})
		if not dons.is_empty():
			out.append({"titre": "Du jardin, des bêtes, des herbes, de la cueillette", "tuiles": dons, "a_la_ligne": true})
		var affaires := []
		for id in Atelier.ORDRE:
			if Atelier.MATIERES.has(id) or atelier.possede(id) <= 0:
				continue
			var n: int = atelier.possede(id)
			var marque := ""
			if id == "lampe":
				marque = "allumée" if atelier.porte(id) else ""
			elif atelier.porte(id):
				marque = "sur toi"
			affaires.append({"cle": "obj:" + id, "id": id, "nom": _nom(id), "n": n if n > 1 else 0, "marque": marque})
		# (ses affaires commencent toujours leur rangée : on les retrouve au même endroit)
		out.append({"titre": "Tes affaires", "tuiles": affaires, "a_la_ligne": true, "vide": "Rien encore. L'établi vient d'abord : tout le reste s'y fabrique."})
		return out

	# (d'abord ce qu'on peut replier, sinon la première de ses affaires, sinon l'établi à faire)
	func _par_defaut(cles: Array) -> String:
		for c in cles:
			if str(c).begins_with("obj:"):
				return str(c)
		return super(cles)

	# ce qui l'empêche de se servir de ce qu'elle a cueilli ("" : rien) : infuser, piler, cuire un gruau, une soupe, presser
	func _empeche_cueillette(k: String) -> String:
		match k:
			"fleurs":
				return str(atelier.empeche_infuser())
			"amanite":
				return str(atelier.empeche_piler_amanite())
			"grains":
				return str(atelier.empeche_cuire("gruau"))
			"lichen":
				return str(atelier.empeche_cuire("soupe_lichen"))
			"pulpe":
				return str(atelier.empeche_presser())
		return ""

	# le carré de jardin à portée de main (null : aucun)
	func _carre():
		return atelier._proche("carre", Atelier.PORTEE + 10.0)

	func _carte(id: String, nom: String, etat: String, dit: String, bouton: String, pourquoi: String = "", lignes: Array = []) -> Dictionary:
		return {"id": id, "pale": false, "nom": nom, "etat": etat, "dit": dit, "lignes": lignes, "bouton": bouton, "actif": pourquoi == "", "pourquoi": pourquoi}

	# les fiches du jardin et de l'élevage ({} : ce n'en est pas une)
	func _fiche_du_jardin(cle: String) -> Dictionary:
		var J = jeu.jardin
		var E = jeu.elevage
		var inv: Dictionary = jeu.joueur.inventaire
		if cle == "act:becher":
			return _carte("carre", "Un carré de jardin", "Devant toi.", "La houe retourne la terre. On y sème ; ça pousse si la terre est humide : la pluie, ou l'arrosoir.", "Bêcher", J.empeche_becher())
		if cle == "act:appat":
			return _carte("appat", "Un appât", "%d baies, posées devant toi." % Elevage.APPAT, "Une bête qui broute viendra y manger, si tu te tiens à l'écart sans bouger. La tête dedans, elle laisse venir : « Agir », et le licol est passé.",
				"Poser", E.empeche_appat())
		var carre = _carre()
		if cle == "page:herbier":
			return _carte("herbier", "L'herbier", "%d herbes connues." % jeu.botanique.savoir.size(), "Ce que tu sais des herbes de ce lieu : leurs signes, ce qu'elles peuvent être, ce qu'on en prépare.", "Ouvrir")
		if cle == "page:carte":
			var nr: int = jeu.reperes.liste.size()
			return _carte("plume" if atelier.possede("plume") > 0 else "carte", "La carte", "%d repère%s écrit%s." % [nr, "s" if nr > 1 else "", "s" if nr > 1 else ""] if nr > 0 else "Rien n'y est écrit encore.",
				"Écris ce qui est là où tu te tiens : ton camp, une tanière, un coffre… Raye ce qui n'y est plus. Elle se lit à la pause.", "Ouvrir")
		if cle.begins_with("prep:"):
			var p := cle.trim_prefix("prep:")
			var op: Dictionary = Botanique.PREPARATIONS[p]
			var mot: String = {"baume": "Se soigner", "tisane": "Boire", "philtre": "Boire", "botte": "Jeter au feu"}.get(p, "Poser")
			return _carte(p, str(op["nom"]), "Tu en as %d." % int(inv.get(p, 0)), str(op["dit"]), mot, str(jeu.botanique.empeche_utiliser(p)))
		if cle.begins_with("semer:") and carre != null and Jardin.est_une_herbe(cle.trim_prefix("semer:")):
			var h := cle.trim_prefix("semer:")
			var manque_h := str(jeu.botanique.empeche_semer(h))
			return _carte("h:" + h, jeu.botanique.nom(h), "Tu en as %d plants ; il en faut %d." % [jeu.botanique.possede(h), Jardin.GRAINES],
				"Une herbe reconnue se sème de ses propres plants. Mûre en un jour et demi, la terre humide : un carré en rend %d." % Botanique.RECOLTE_JARDIN, "Semer", manque_h)
		if cle.begins_with("semer:") and carre != null:
			var c := cle.trim_prefix("semer:")
			var o: Dictionary = Jardin.CULTURES[c]
			var donne := PackedStringArray()
			for k in o["donne"]:
				donne.append("%d %s" % [int(o["donne"][k]), str(NOMS_DU_JARDIN.get(k, R.NOMS.get(k, Atelier.NOMS_MATIERES.get(k, k)))).to_lower()])
			var manque := "" if J.graines(c) >= Jardin.GRAINES else "Il te faut %d %s." % [Jardin.GRAINES, str(Jardin.NOMS_GRAINES[o["graine"]])]
			var jours := "un jour" if float(o["jours"]) <= 1.0 else ("un jour et demi" if float(o["jours"]) < 2.0 else "deux jours")
			if o["donne"].has(o["graine"]):
				# (des grains : ce qu'on récolte est aussi ce qu'on sème)
				var rend := PackedStringArray()
				for k in o["donne"]:
					rend.append("%d %s" % [int(o["donne"][k]) + (Jardin.RENDUES if k == o["graine"] else 0), str(R.NOMS.get(k, Atelier.NOMS_MATIERES.get(k, k))).to_lower()])
				return _carte("grains", str(o["nom"]), "Tu as %d grains ; il en faut %d." % [J.graines(c), Jardin.GRAINES],
					"Mûr en %s, la terre humide. Un carré rend %s : de quoi manger, et de quoi semer encore." % [jours, " et ".join(rend)], "Semer", manque)
			return _carte(str(o["graine"]), str(o["nom"]), "Tu as %d graines ; il en faut %d." % [J.graines(c), Jardin.GRAINES],
				"Mûr en %s, la terre humide. Un carré rend %s, et %d graines." % [jours, ", ".join(donne), Jardin.RENDUES],
				"Semer", manque)
		if cle == "recolter" and carre != null:
			return _carte("carre", "Le carré", J.dire(carre), "Ce qui est mûr se récolte ; le carré est de nouveau libre.", "Récolter")
		if cle == "arroser" and carre != null:
			var pourquoi := "" if atelier.possede("arrosoir") > 0 and J.arrosages() > 0 else ("Il te faut un arrosoir." if atelier.possede("arrosoir") <= 0 else "L'arrosoir est vide.")
			return _carte("arrosoir", "Le carré", J.dire(carre), "Sans eau, rien ne pousse. La pluie arrose aussi.", "Arroser", pourquoi,
				[["jauge", "Terre", float(carre.etat.get("eau", 0.0)), "humide" if float(carre.etat.get("eau", 0.0)) > 0.15 else "sèche"]])
		if cle == "combler" and carre != null:
			return _carte("carre", "Le carré", J.dire(carre), "Comblé, la terre reprend sa place. Ce qui y pousse est perdu.", "Combler")
		if cle == "use:simples":
			return _carte("simples", "Simples", "Tu en as %d." % int(inv.get("simples", 0)), "Des herbes qu'on mâche : la santé revient (%d), la peur s'apaise." % int(Jardin.SIMPLES_SANTE), "Se panser")
		if cle == "use:lait":
			return _carte("lait", "Lait", "Tu en as %d." % int(inv.get("lait", 0)), "Tiède. Il nourrit (%d), et calme un peu." % int(Elevage.LAIT_FAIM), "Boire")
		if cle == "use:fleurs":
			return _carte("fleurs", "Fleurs", "Tu en as %d." % int(inv.get("fleurs", 0)),
				"Cueillies dans l'herbe, sur une bruyère, sur une mare. %d fleurs et une gorgée d'eau, à la popote sur un feu allumé : une infusion, qui calme la peur." % R.FLEURS_INFUSION,
				"Infuser", atelier.empeche_infuser())
		if cle == "use:infusion":
			return _carte("infusion", "Infusion de fleurs", "Tu en as %d." % int(inv.get("infusion", 0)),
				"Chaude et douce : elle calme la peur (%d) et réchauffe un peu." % int(R.INFUSION_PEUR), "Boire")
		if cle == "use:amanite":
			return _carte("amanite", "Amanite", "Tu en as %d." % int(inv.get("amanite", 0)),
				"Rouge, piquée de blanc : elle empoisonne qui la mange. Pilée au mortier avec de la viande crue, elle fait un appât pour ce qui chasse.",
				"Piler un appât", atelier.empeche_piler_amanite())
		if cle == "use:grains":
			return _carte("grains", "Grains", "Tu en as %d." % int(inv.get("grains", 0)),
				"Cueillis aux épis d'une céréale, d'un riz sauvage. Crus, ils nourrissent à peine (E). %d grains et une gorgée d'eau, à la popote sur un feu allumé : un gruau, presque un bouillon (C, ou ici). Semés dans un carré de jardin, ils poussent." % R.GRUAU_GRAINS,
				"Cuire un gruau", atelier.empeche_cuire("gruau"))
		if cle == "use:lichen":
			return _carte("lichen", "Lichen des rennes", "Tu en as %d." % int(inv.get("lichen", 0)),
				"Cru, il est amer et noue le ventre. %d lichens et une gorgée d'eau, à la popote sur un feu : une soupe maigre, mais chaude (C, ou ici). Sur la banquise, c'est ce qui tient." % R.SOUPE_LICHENS,
				"Faire une soupe", atelier.empeche_cuire("soupe_lichen"))
		if cle == "use:pulpe":
			return _carte("pulpe", "Pulpe de cactus", "Tu en as %d." % int(inv.get("pulpe", 0)),
				"Mangée (E), elle nourrit à peine mais rafraîchit : la chaleur pèse moins un moment. %d pulpes pressées au mortier : une gorgée d'eau dans ta gourde." % R.PULPES_GORGEE,
				"Presser", atelier.empeche_presser())
		if cle.begins_with("graine:"):
			var g := cle.trim_prefix("graine:")
			var d_ou := "Un buisson cueilli en rend parfois." if g == "graine_baie" else ("Une touffe coupée en rend parfois." if g == "graine_lin" else "On en trouve dans les vestiges d'autres veilleuses.")
			return _carte(g, str(NOMS_DU_JARDIN[g]), "Tu en as %d ; il en faut %d par carré." % [int(inv.get(g, 0)), Jardin.GRAINES],
				"%s Elles se sèment dans un carré de terre, qu'une houe retourne : « Agir » devant le carré." % d_ou, "")
		if not cle.begins_with("bete:"):
			return {}
		var b = E.pres(Elevage.PORTEE + 24.0)
		if b == null:
			return {}
		var faim := float(b.faim)
		var jauges := [["jauge", "Faim", faim / 100.0, "repue" if faim > 60.0 else ("a faim" if faim > 25.0 else "affamée")]]
		match cle:
			"bete:suite":
				return _carte("bete", str(b.nom), "Elle te suit." if bool(b.suit_la) else "Elle reste là.",
					"Laissée près d'un piquet d'attache, elle y est liée et broute autour. La nuit, garde-la dans la lumière d'un feu : le noir les rend folles.",
					"Reste là" if bool(b.suit_la) else "Suis-moi", "", jauges)
			"bete:selle":
				return _carte("selle", "La seller", str(b.nom), str(Atelier.OBJETS["selle"]["dit"]), "Seller", E.empeche_harnacher(b, "selle"))
			"bete:sacoche":
				return _carte("sacoche", "Ses sacoches", str(b.nom), str(Atelier.OBJETS["sacoche"]["dit"]), "Les lui mettre", E.empeche_harnacher(b, "sacoche"))
			"bete:monter":
				return _carte("selle", "La monter", str(b.nom), "En selle, on va bien plus vite. Ce qui lui fait peur te jette à terre.", "Monter", E.empeche_monter(b))
			"bete:traire":
				return _carte("lait", "La traire", str(b.nom), "Nourrie, elle donne son lait une fois par jour.", "Traire", E.empeche_traire(b),
					[["jauge", "Lait", float(b.lait), "prête" if float(b.lait) >= 1.0 else "pas encore"]])
			"bete:liberer":
				return _carte("licol", "La relâcher", str(b.nom), "Tu lui ôtes son licol : elle retourne aux siens. Son harnais revient dans ton sac.", "Relâcher")
		return {}

	# faux : ce n'était pas une action du jardin ou de l'élevage
	func _faire_au_jardin(cle: String) -> bool:
		var J = jeu.jardin
		var E = jeu.elevage
		var carre = _carre()
		var b = E.pres(Elevage.PORTEE + 24.0)
		if cle == "act:becher":
			J.becher()
			refermer()
		elif cle == "page:herbier" or cle == "page:carte":
			# (une page se ferme, l'autre s'ouvre)
			refermer()
			jeu.ouvrir_page(cle.trim_prefix("page:"))
		elif cle.begins_with("prep:"):
			var p := cle.trim_prefix("prep:")
			jeu.botanique.utiliser(p)
			if p in ["botte", "appat_poison", "appat_dormant", "philtre"]:
				refermer()
		elif cle == "act:appat":
			E.poser_appat()
			refermer()
		elif cle.begins_with("semer:"):
			J.semer(carre, cle.trim_prefix("semer:"))
			refermer()
		elif cle == "recolter":
			J.recolter(carre)
			refermer()
		elif cle == "arroser":
			J.arroser(carre)
		elif cle == "combler":
			if carre != null:
				atelier.poses.erase(carre)
				carre.queue_free()
			refermer()
		elif cle == "use:simples":
			J.panser()
		elif cle == "use:lait":
			E.boire_lait()
		elif cle == "use:fleurs":
			atelier.infuser()
		elif cle == "use:infusion":
			atelier.boire_infusion()
		elif cle == "use:amanite":
			atelier.piler_amanite()
		elif cle == "use:grains":
			atelier.cuire_plat("gruau")
		elif cle == "use:lichen":
			atelier.cuire_plat("soupe_lichen")
		elif cle == "use:pulpe":
			atelier.presser()
		elif cle == "bete:suite":
			E.basculer_suite(b)
		elif cle == "bete:selle":
			E.harnacher(b, "selle")
		elif cle == "bete:sacoche":
			E.harnacher(b, "sacoche")
		elif cle == "bete:monter":
			E.monter(b)
			refermer()
		elif cle == "bete:traire":
			E.traire(b)
		elif cle == "bete:liberer":
			E.liberer(b)
		else:
			return false
		return true

	func _fiche_de(cle: String) -> Dictionary:
		if cle == "fab:etabli":
			return _fiche_a_fabriquer("etabli")
		if cle == "pose":
			return _fiche_posee()
		if not cle.begins_with("obj:"):
			return _fiche_du_jardin(cle)
		var id := cle.trim_prefix("obj:")
		var o: Dictionary = Atelier.OBJETS[id]
		var n: int = atelier.possede(id)
		var f := {"id": id, "pale": false, "nom": str(o["nom"]), "etat": "Dans ton sac." if n <= 1 else "Tu en as %d dans ton sac." % n, "dit": str(o["dit"]),
			"lignes": [], "bouton": "", "actif": true, "pourquoi": ""}
		if id == "lampe":
			_fiche_lampe(f)
		elif id == "piles":
			f["etat"] = "Au fil du cerf-volant." if atelier.fil != null else "Dans ton sac."
			f["lignes"] = [["jauge", "Charge", float(atelier.charge) / 100.0, "%d %%" % int(round(float(atelier.charge)))]]
		elif id == "gourde":
			var eau: int = atelier.possede("eau")
			f["etat"] = "Vide." if eau <= 0 else "%d gorgée%s sur %d." % [eau, "s" if eau > 1 else "", Atelier.GORGEES]
			f["lignes"] = [["gouttes", eau, Atelier.GORGEES]]
			f["bouton"] = "Boire"
			f["actif"] = eau > 0
			f["pourquoi"] = "" if eau > 0 else "Elle est vide. Remplis-la au récupérateur d'eau."
		elif id == "duvet":
			f["bouton"] = "Dormir"
			_demander(f, "empeche_dormir", [])
		elif id == "houe":
			f["bouton"] = "Bêcher"
			f["pourquoi"] = str(jeu.jardin.empeche_becher())
			f["actif"] = f["pourquoi"] == ""
		elif id == "arrosoir":
			var na: int = jeu.jardin.arrosages()
			f["etat"] = "Vide." if na <= 0 else "%d arrosage%s sur %d." % [na, "s" if na > 1 else "", Jardin.ARROSAGES]
			f["lignes"] = [["gouttes", na, Jardin.ARROSAGES]]
			f["bouton"] = "Remplir"
			f["actif"] = na < Jardin.ARROSAGES and float(jeu.climat.eau(jeu.joueur.position)) >= 0.3
			f["pourquoi"] = "" if f["actif"] else ("Il est plein." if na >= Jardin.ARROSAGES else "Les pieds dans l'eau, ou « Agir » au récupérateur.")
		elif id in ["carte", "plume"]:
			f["bouton"] = "Ouvrir"
			f["lignes"] = [["note", "À la pause, le carnet montre ta carte." if id == "carte" else "Sur ta carte, tu écris ce qui est là où tu te tiens."]]
		elif id in ["licol", "selle", "sacoche"]:
			f["lignes"] = [["note", "Pour une bête à toi : approche-la, et rouvre ton sac." if id != "licol" else "Pose un appât, écarte-toi : la bête qui y mange se laisse passer le licol."]]
		elif bool(o.get("pose", false)):
			f["lignes"] = [["note", "Se pose devant toi. Se replie quand tu veux."]]
			f["bouton"] = "Poser"
			_demander(f, "empeche_poser", [id])
		elif bool(o.get("porte", false)):
			var mise: bool = atelier.porte(id)
			f["etat"] = "Tu l'as sur toi." if mise else "Tu ne l'as pas sur toi."
			f["bouton"] = "Ôter" if mise else "Mettre"
		return f

	# si l'atelier sait dire d'avance ce qui empêche (empeche_poser, empeche_dormir), le bouton s'éteint et la page le dit
	func _demander(f: Dictionary, methode: String, args: Array) -> void:
		if atelier.has_method(methode):
			var pourquoi := str(atelier.callv(methode, args))
			f["actif"] = pourquoi == ""
			f["pourquoi"] = pourquoi

	# la lampe : ses piles, et ce qui l'empêche de s'allumer (les mêmes raisons que l'atelier, dites avant)
	func _fiche_lampe(f: Dictionary) -> void:
		var allumee: bool = atelier.porte("lampe")
		var charge: float = float(atelier.charge)
		f["etat"] = "Allumée." if allumee else "Éteinte."
		f["bouton"] = "Éteindre" if allumee else "Allumer"
		if atelier.possede("piles") <= 0:
			f["lignes"] = [["note", "Elle n'a pas de piles."]]
			f["actif"] = allumee
			f["pourquoi"] = "" if allumee else "Il lui faut des piles : elles se fabriquent à l'établi."
			return
		f["lignes"] = [["jauge", "Piles", charge / 100.0, "%d %%" % int(round(charge))]]
		if allumee:
			return
		if atelier.fil != null:
			f["actif"] = false
			f["pourquoi"] = "Ses piles sont au fil du cerf-volant : reprends-les d'abord."
		elif charge <= 0.5:
			f["actif"] = false
			f["pourquoi"] = "Les piles sont vides. Le cerf-volant les charge, par grand vent."

	# ce qui est posé juste là : on le replie, et il revient dans le sac
	func _fiche_posee() -> Dictionary:
		var s = _juste_la()
		if s == null:
			return {}
		var id := str(s.genre)
		var o: Dictionary = Atelier.OBJETS[id]
		var lignes := [["note", "Replié, il revient dans ton sac." if id != "tente" else "Repliée, elle revient dans ton sac."]]
		# (ce qu'on perdrait à replier maintenant)
		if id == "recuperateur" and float(s.etat.get("eau", 0.0)) >= 1.0:
			lignes.append(["note", "L'eau qu'il garde sera perdue : remplis d'abord ta gourde."])
		elif id == "filet" and s.etat.has("prise"):
			lignes.append(["note", "Une bête s'y est prise : relève-le d'abord."])
		elif id == "cerf_volant" and atelier.fil == s:
			lignes.append(["note", "Tes piles reviennent avec lui."])
		return {"id": id, "pale": false, "nom": str(o["nom"]), "etat": "Posé juste là, à portée de main." if id != "tente" else "Posée juste là, à portée de main.",
			"dit": str(o["dit"]), "lignes": lignes, "bouton": "Replier", "actif": true, "pourquoi": ""}

	func _faire(cle: String) -> String:
		if cle == "fab:etabli":
			return "Fait" if atelier.fabriquer("etabli") else ""
		if cle == "pose":
			atelier.replier()
			return ""
		if not cle.begins_with("obj:"):
			_faire_au_jardin(cle)
			return ""
		var id := cle.trim_prefix("obj:")
		var o: Dictionary = Atelier.OBJETS[id]
		if id == "gourde":
			atelier.boire()
		elif id == "houe":
			jeu.jardin.becher()
			refermer()
		elif id == "arrosoir":
			jeu.jardin.remplir()
		elif id in ["carte", "plume"]:
			refermer()
			jeu.ouvrir_page("carte")
		elif id == "duvet":
			# (qu'elle s'endorme ou que le jeu dise pourquoi elle ne peut pas : on le voit dans la partie, page fermée)
			atelier.dormir(null)
			refermer()
		elif bool(o.get("pose", false)):
			atelier.poser(id)
			refermer()
		elif bool(o.get("porte", false)):
			atelier.basculer(id)
		return ""


# --- la page de l'herbier : les herbes du lieu, ce qu'on en sait, ce qu'on en prépare (scripts/botanique.gd) ---

class Herbier extends Feuille:
	func _init() -> void:
		super("L'herbier", "Ce que tu sais des herbes. Choisis-en une.", "Ce que tu sais des herbes. Touche-en une.", 11.0)

	# le lieu où elle est (le biome de l'herbier ; ailleurs : la forêt)
	func _ici() -> String:
		var b := str(jeu.biome)
		return b if Botanique.FLORE.has(b) else "foret"

	# ce qu'il faut pour préparer, sous les yeux
	func _groupes() -> Array:
		var inv: Dictionary = jeu.joueur.inventaire
		var cases := []
		for k in ["eau", "viande", "baies", "fibre"]:
			cases.append({"id": k, "nom": Plume.majuscule(str(R.NOMS.get(k, Atelier.NOMS_MATIERES.get(k, k)))), "n": int(inv.get(k, 0)), "sur": 0})
		var outils := []
		for k in ["popote", "mortier"]:
			outils.append({"id": k, "nom": str(Atelier.OBJETS[k]["nom"]), "n": atelier.possede(k), "sur": 0})
		return [{"titre": "Pour préparer", "cases": cases}, {"titre": "Tes outils", "cases": outils}]

	func _tuile(id: String) -> Dictionary:
		var B = jeu.botanique
		var connue: bool = B.connue(id)
		var marque := ""
		if B.sue(id):
			marque = str(Botanique.NOMS_VERTUS[B.vertu(id)])
		elif connue:
			marque = "?"
		return {"cle": "h:" + id, "id": "h:" + id, "nom": B.nom(id) if connue else "Inconnue", "pale": not connue, "n": B.possede(id), "etiquette": marque}

	func _sections() -> Array:
		var B = jeu.botanique
		var inv: Dictionary = jeu.joueur.inventaire
		var ici := _ici()
		var out := []
		var la := []
		for id in Botanique.especes(ici):
			la.append(_tuile(id))
		out.append({"titre": "Les herbes de ce lieu", "tuiles": la})
		# (celles qu'elle a rapportées d'ailleurs, ou qu'elle y a connues)
		var ailleurs := []
		var vues := {}
		for id in B.savoir:
			if Botanique.lieu_de(str(id)) != ici and B.connue(str(id)):
				vues[str(id)] = true
		for id in B.sac():
			if Botanique.lieu_de(str(id)) != ici:
				vues[str(id)] = true
		for id in vues:
			ailleurs.append(_tuile(str(id)))
		if not ailleurs.is_empty():
			out.append({"titre": "D'ailleurs", "tuiles": ailleurs, "a_la_ligne": true})
		var prep := []
		for p in Botanique.ORDRE_PREPARATIONS:
			prep.append({"cle": "prep:" + p, "id": p, "nom": str(Botanique.PREPARATIONS[p]["nom"]), "pale": B.empeche_preparer(p) != "", "n": int(inv.get(p, 0))})
		out.append({"titre": "Préparer", "tuiles": prep, "a_la_ligne": true})
		return out

	# « apaisante ou somnifère », « cicatrisante, vénéneuse ou âcre »
	static func _ou(vertus: Array) -> String:
		var noms := PackedStringArray()
		for v in vertus:
			noms.append(str(Botanique.NOMS_VERTUS[v]))
		if noms.size() <= 1:
			return ", ".join(noms)
		var debut := noms.slice(0, noms.size() - 1)
		return "%s ou %s" % [", ".join(debut), noms[noms.size() - 1]]

	func _fiche_de(cle: String) -> Dictionary:
		var B = jeu.botanique
		var inv: Dictionary = jeu.joueur.inventaire
		if cle.begins_with("prep:"):
			var p := cle.trim_prefix("prep:")
			var o: Dictionary = Botanique.PREPARATIONS[p]
			var v := str(o["vertu"])
			var h: String = B.herbe_pour(v, 1)
			var lignes := [["cout", "h:" + h if h != "" else "simples", "Une herbe %s" % str(Botanique.NOMS_VERTUS[v]) if h == "" else B.nom(h), B.possede(h) if h != "" else 0, int(o["herbes"])]]
			for k in o["avec"]:
				lignes.append(["cout", k, Plume.majuscule(str(R.NOMS.get(k, Atelier.NOMS_MATIERES.get(k, k)))), int(inv.get(k, 0)), int(o["avec"][k])])
			lignes.append(["note", "À la popote, sur un feu allumé." if str(o["ou"]) == "feu" else "Au mortier."])
			var pourquoi := str(B.empeche_preparer(p))
			return {"id": p, "pale": pourquoi != "", "nom": str(o["nom"]), "etat": "Tu en as %d." % int(inv.get(p, 0)) if int(inv.get(p, 0)) > 0 else "Tu n'en as pas.",
				"dit": str(o["dit"]), "entete": ["Il te faut", "tu as / il faut"], "lignes": lignes, "bouton": "Préparer", "actif": pourquoi == "", "pourquoi": pourquoi}
		var id := cle.substr(2)
		var connue: bool = B.connue(id)
		var n: int = B.possede(id)
		var f := {"id": cle, "pale": not connue, "nom": B.nom(id) if connue else "Une herbe inconnue",
			"etat": ("Tu en as %d." % n if n > 0 else "Tu n'en as plus.") if connue else "Elle pousse dans ce lieu.",
			"dit": "", "lignes": [["planche", id, str(Botanique.signe(id)) if connue else "", connue]], "bouton": "", "actif": true, "pourquoi": ""}
		if not connue:
			f["dit"] = "Tu ne l'as pas encore cueillie. Cueillie, elle te dira un de ses signes."
			return f
		for l in B.lignes(id):
			f["lignes"].append(["note", str(l)])
		if B.sue(id):
			var v2: String = B.vertu(id)
			f["dit"] = "Elle est %s. %s" % [str(Botanique.NOMS_VERTUS[v2]), str(Botanique.DIT_VERTU[v2])]
			if n > 0:
				f["bouton"] = "Mâcher"
				if v2 in ["veneneuse", "acre", "somnifere", "voyante"]:
					f["pourquoi"] = "Crue, elle fait son effet sur toi."
		else:
			var c: Array = B.candidates(id)
			f["dit"] = "Ce peut être : %s." % _ou(c)
			f["lignes"].append(["note", "Pour savoir : regarde si les bêtes en mangent, reconnais les autres herbes du lieu, ou goûte-la."])
			if n > 0:
				f["bouton"] = "Goûter"
				if c.has("veneneuse"):
					f["pourquoi"] = "À tes risques : elle peut être vénéneuse."
				elif c.has("somnifere") or c.has("voyante") or c.has("acre"):
					f["pourquoi"] = "À tes risques."
		return f

	func _faire(cle: String) -> String:
		var B = jeu.botanique
		if cle.begins_with("prep:"):
			return "Fait" if B.preparer(cle.trim_prefix("prep:")) else ""
		# (elle y goûte : on le voit dans la partie, page fermée)
		if B.gouter(cle.substr(2)):
			refermer()
		return ""



# --- la page de la carte : ce qu'on y écrit, là où l'on se tient ; ce qu'on y raye (scripts/reperes.gd) ---

class PageCarte extends Feuille:
	func _init() -> void:
		super("La carte", "Écris ce qui est là, ou raye un repère. Elle se lit à la pause.", "Écris ce qui est là, ou raye un repère.", 6.0)

	func _groupes() -> Array:
		var outils := []
		for k in ["carte", "plume"]:
			outils.append({"id": k, "nom": str(Atelier.OBJETS[k]["nom"]), "n": atelier.possede(k), "sur": 0})
		return [{"titre": "Tes outils", "cases": outils}]

	# un repère, d'un mot qui ne change pas quand les autres sont rayés
	static func _cle_de(r: Dictionary) -> String:
		return "rayer:%s@%d,%d" % [str(r["genre"]), int(round(float(r["x"]))), int(round(float(r["y"])))]

	func _rang(cle: String) -> int:
		var Rp = jeu.reperes
		for i in Rp.liste.size():
			if _cle_de(Rp.liste[i]) == cle:
				return i
		return -1

	func _sections() -> Array:
		var Rp = jeu.reperes
		var la: String = Rp.ici()
		var peut: bool = Rp.empeche_ecrire() == ""
		var ecrire := []
		for g in Reperes.ORDRE:
			ecrire.append({"cle": "ecrire:" + g, "id": "rep:" + g, "nom": str(Reperes.GENRES[g]["nom"]), "pale": not peut, "marque": "c'est là" if g == la else ""})
		var ecrits := []
		for i in Rp.par_distance():
			var r: Dictionary = Rp.liste[i]
			var pas := int(round(Reperes.position(r).distance_to(jeu.joueur.position) / Reperes.PAS))
			ecrits.append({"cle": _cle_de(r), "id": "rep:" + str(r["genre"]), "nom": str(Reperes.GENRES[str(r["genre"])]["nom"]), "etiquette": "ici" if pas < 3 else "%d pas" % pas})
		return [{"titre": "Écrire, là où tu te tiens", "tuiles": ecrire},
			{"titre": "Sur ta carte · %d sur %d" % [Rp.liste.size(), Reperes.MAX], "tuiles": ecrits, "a_la_ligne": true, "vide": "Rien encore. Choisis ce qui est là, et écris-le."}]

	# (d'abord ce qui est là, s'il y a quelque chose)
	func _par_defaut(cles: Array) -> String:
		var la: String = jeu.reperes.ici()
		if la != "" and cles.has("ecrire:" + la):
			return "ecrire:" + la
		return super(cles)

	func _fiche_de(cle: String) -> Dictionary:
		var Rp = jeu.reperes
		if cle.begins_with("ecrire:"):
			var g := cle.trim_prefix("ecrire:")
			var pourquoi: String = Rp.empeche_ecrire()
			var o: Dictionary = Reperes.GENRES[g]
			return {"id": "rep:" + g, "pale": false, "nom": str(o["nom"]), "etat": "C'est ce qui est là." if Rp.ici() == g else "Là où tu te tiens.",
				"dit": str(o["dit"]), "lignes": [["note", "Il s'écrit là où tu te tiens. Le même, déjà écrit tout près, est récrit ici : pas doublé."]],
				"bouton": "Écrire", "actif": pourquoi == "", "pourquoi": pourquoi}
		var i := _rang(cle)
		if i < 0:
			return {}
		var r: Dictionary = Rp.liste[i]
		var o2: Dictionary = Reperes.GENRES[str(r["genre"])]
		return {"id": "rep:" + str(r["genre"]), "pale": false, "nom": str(o2["nom"]), "etat": Plume.majuscule(str(Rp.dire_ou(r))) + ".",
			"dit": str(o2["dit"]), "lignes": [["note", "Rayé, il quitte ta carte."]], "bouton": "Rayer", "actif": true, "pourquoi": ""}

	func _faire(cle: String) -> String:
		var Rp = jeu.reperes
		if cle.begins_with("ecrire:"):
			return "Écrit" if Rp.ecrire(cle.trim_prefix("ecrire:")) else ""
		var i := _rang(cle)
		return "Rayé" if i >= 0 and Rp.rayer(i) else ""
