extends Control
# Lisière — la page « Elle est partie. » (scripts/interface_depart.gd)
# À l'aube qui suit la troisième cicatrice de la Noire (scripts/noire_collet.gd), une page du carnet le dit, dans le papier et
# l'encre de l'écran de fin (scripts/interface_carnet.gd) — mais ce n'est pas une fin, et l'on n'y compte pas de morts : son
# titre, le lieu et la nuit, le compte (les nuits tenues, ses cicatrices, les collets tendus, ses morsures), elle-même
# dessinée telle qu'elle est partie (ses trois balafres, la patte qu'elle ne pose plus), sa piste qui sort de la page, ce
# qu'on en écrit, et deux choix : rester veiller dans le lieu (la partie continue, sans elle), ou revenir au titre (la
# partie est gardée). scripts/interface.gd la montre (montrer_depart) ; scripts/principal.gd met la partie en attente.

signal rester
signal quitter

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")
const I := preload("res://scripts/interface_icones.gd")
const Bouton := preload("res://scripts/interface_bouton.gd")
const Carnet := preload("res://scripts/interface_carnet.gd")
const Bestiaire := preload("res://scripts/bestiaire.gd")
const LaNoire := preload("res://scripts/noire.gd")

var compact := false
var page: Carnet.Page
var _voile: ColorRect
var _titre: Label
var _lieu: Label
var _stats: HBoxContainer
var _chiffres: Array = []
var _vignette: Vignette
var _dit: Label
var _reste: Label
var _boutons: Array = []
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_voile = ColorRect.new()
	# (l'aube derrière la page, pas la nuit : un voile chaud, qui laisse voir le lieu)
	_voile.color = Color(P.NUIT_BLEUE.lerp(P.AUBE, 0.22), 0.0)
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_voile)
	page = Carnet.Page.new(13.0)
	add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.contenu.add_child(v)
	_titre = Carnet.Encre.libelle("Elle est partie.", T.titre(), 52, P.ENCRE)
	v.add_child(_titre)
	_lieu = Carnet.Encre.libelle("", T.titre_italique(), 19, P.ENCRE_DOUCE)
	v.add_child(_lieu)
	v.add_child(Carnet.Filet.new(0.5))
	_stats = HBoxContainer.new()
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override("separation", 46)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_stats)
	for k in 4:
		var b := VBoxContainer.new()
		b.add_theme_constant_override("separation", -6)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := Carnet.Encre.libelle("0", T.titre(), 40, P.ENCRE)
		var m := Carnet.Encre.libelle("", T.capitales(), 15, P.ENCRE_DOUCE)
		b.add_child(n)
		b.add_child(m)
		_stats.add_child(b)
		_chiffres.append([n, m])
	_vignette = Vignette.new()
	_vignette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_vignette)
	_dit = Carnet.Encre.libelle("", T.titre_italique(), 18, P.ENCRE)
	_dit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_dit)
	_reste = Carnet.Encre.libelle("", T.texte(), 14, P.ENCRE_DOUCE)
	_reste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_reste)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 30)
	v.add_child(h)
	var b1 := Bouton.new("Rester veiller", 24, true, true)
	b1.pressed.connect(func(): rester.emit())
	var b2 := Bouton.new("Revenir au titre", 24, true)
	b2.pressed.connect(func(): quitter.emit())
	h.add_child(b1)
	h.add_child(b2)
	_boutons = [b1, b2]
	resized.connect(_disposer)


func mettre_compact(oui: bool) -> void:
	compact = oui
	_titre.add_theme_font_size_override("font_size", 38 if oui else 52)
	_lieu.add_theme_font_size_override("font_size", 16 if oui else 19)
	_stats.add_theme_constant_override("separation", 26 if oui else 46)
	for c in _chiffres:
		c[0].add_theme_font_size_override("font_size", 28 if oui else 40)
		c[1].add_theme_font_size_override("font_size", 13 if oui else 15)
	_dit.add_theme_font_size_override("font_size", 15 if oui else 18)
	_reste.add_theme_font_size_override("font_size", 13 if oui else 14)
	for b in _boutons:
		b.mettre_taille(20 if oui else 24)
	page.marges(28 if oui else 40, 12 if oui else 24)
	_disposer()


func _disposer() -> void:
	var s := size
	var ps := Vector2(minf(1000.0, s.x - (24.0 if compact else 60.0)), minf(660.0, s.y - (16.0 if compact else 40.0)))
	page.size = ps
	page.position = (s - ps) * 0.5


# la page : ce que dit scripts/noire_collet.gd (page()), et elle, dessinée avec ses cicatrices
func remplir(d: Dictionary, jeu) -> void:
	_titre.text = str(d.get("titre", "Elle est partie."))
	_lieu.text = str(d.get("lieu", ""))
	var nombres: Array = d.get("nombres", [])
	for i in 4:
		var a: Array = nombres[i] if i < nombres.size() else [0, ""]
		_chiffres[i][0].text = str(a[0])
		_chiffres[i][1].text = str(a[1])
	_dit.text = str(d.get("dit", ""))
	_reste.text = str(d.get("reste", ""))
	var cicatrices := 3
	var vers_la_gauche := false
	if jeu != null and jeu.get("noire") != null:
		cicatrices = int(jeu.noire.cicatrices)
		# (elle sort de la page du côté où elle a quitté le lieu)
		vers_la_gauche = float(jeu.noire.collet.sortie.x) < float(jeu.noire.collet.depart_de.x)
	_vignette.remplir(cicatrices, vers_la_gauche)
	_t = 0.0
	_disposer()
	if not compact and _boutons.size() > 0:
		_boutons[0].grab_focus.call_deferred()


func _process(d: float) -> void:
	if not visible:
		return
	_t += d
	var u := smoothstep(0.0, 1.1, _t)
	_voile.color.a = 0.62 * u
	page.modulate.a = smoothstep(0.15, 0.95, _t)
	page.position.y = (size.y - page.size.y) * 0.5 + 22.0 * (1.0 - smoothstep(0.1, 1.1, _t))
	page.rotation = deg_to_rad(0.5) * (1.0 - u)


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("valider"):
		rester.emit()
		accept_event()


# ce que la page montre d'elle : à gauche, le collet rompu (ses pieux couchés, un bout de filin) ; elle, qui s'en va vers la
# droite, ses cicatrices sur elle ; et sa piste, du collet à elle, puis d'elle au bord de la page, qui s'efface. Tout vient
# peu à peu, comme on lit une piste
class Vignette extends Control:
	const FILIN := Color("c9ad6e")
	var _portrait := {}
	var _miroir := false          # elle s'en va vers la gauche de la page
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 150)

	func remplir(cicatrices: int, vers_la_gauche: bool = false) -> void:
		_portrait = Bestiaire.portrait(LaNoire.lignee_a(cicatrices), 300.0)
		_miroir = vers_la_gauche
		_t = 0.0

	func _process(d: float) -> void:
		if is_visible_in_tree():
			_t += d
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sol := h * 0.86
		if _miroir:
			# (la même page, retournée : le collet à droite, elle qui sort par la gauche)
			draw_set_transform(Vector2(w, 0.0), 0.0, Vector2(-1.0, 1.0))
		# le sol : un trait d'encre, qui s'interrompt
		I.trait_encre(self, Vector2(w * 0.04, sol), Vector2(w * 0.5, sol), 1.4, Color(P.ENCRE, 0.35))
		I.trait_encre(self, Vector2(w * 0.56, sol), Vector2(w * 0.96, sol), 1.4, Color(P.ENCRE, 0.28))
		# le collet rompu, à gauche : deux pieux couchés, l'un cassé, leurs trous, un bout de filin effiloché
		var c := Vector2(w * 0.13, sol)
		var a0 := smoothstep(0.3, 0.9, _t)
		draw_circle(c + Vector2(-16.0, -1.0), 3.2, Color(P.ENCRE, 0.7 * a0))
		draw_circle(c + Vector2(-6.0, -2.0), 2.8, Color(P.ENCRE, 0.6 * a0))
		for pieu in [[c + Vector2(4.0, -3.0), c + Vector2(40.0, -9.0)], [c + Vector2(-2.0, -11.0), c + Vector2(15.0, -15.0)], [c + Vector2(20.0, -17.0), c + Vector2(33.0, -15.5)]]:
			draw_line(pieu[0], pieu[1], Color(P.ENCRE, a0), 6.4, true)
			draw_line(pieu[0], pieu[1], Color(Color("8a6a45"), a0), 4.2, true)
		var bout := PackedVector2Array([c + Vector2(24.0, -6.5), c + Vector2(30.0, 2.0), c + Vector2(44.0, -1.0), c + Vector2(52.0, 3.0)])
		draw_polyline(bout, Color(P.ENCRE, a0), 4.2, true)
		draw_polyline(bout, Color(FILIN, a0), 2.4, true)
		for k in 3:
			draw_line(bout[3], bout[3] + Vector2(5.0, (k - 1) * 3.0), Color(FILIN.darkened(0.1), a0), 1.2, true)
		# elle : où elle se tient sur la page
		var elle := Vector2(w * 0.6, sol)
		var haut := h * 0.82
		var k_dessin := 1.0
		if not _portrait.is_empty():
			var taille: Vector2 = _portrait["taille"]
			k_dessin = minf(minf(haut / taille.y, w * 0.42 / taille.x), 1.5)
		# sa piste : du collet à elle, puis d'elle au bord de la page ; les empreintes viennent une à une, et s'effacent au loin
		var debut := c.x + 62.0
		var fin := w * 0.985
		var pas := 34.0
		var n := int((fin - debut) / pas)
		for i in n:
			var x := debut + pas * (i + 0.5)
			if not _portrait.is_empty() and absf(x - elle.x) < float(_portrait["taille"].x) * 0.5 * k_dessin + 6.0:
				continue
			var vient := smoothstep(0.5 + 0.09 * i, 0.8 + 0.09 * i, _t)
			if vient <= 0.0:
				continue
			var loin := 1.0 - smoothstep(elle.x + w * 0.12, fin, x) * 0.75
			# (une sur quatre : la patte prise, qu'elle pose à peine)
			var legere := 0.45 if i % 4 == 1 else 1.0
			_empreinte(Vector2(x, sol + (3.0 if i % 2 == 0 else 9.0)), 6.4 * (0.8 + 0.2 * loin), Color(P.ENCRE, 0.72 * vient * loin * legere))
		if _portrait.is_empty():
			return
		var t: Vector2 = _portrait["taille"]
		var po: Vector2 = _portrait["pos"]
		var a := smoothstep(0.9, 1.9, _t)
		var centre_x: float = po.x + t.x * 0.5
		draw_texture_rect(_portrait["tex"], Rect2(elle + Vector2(po.x - centre_x, po.y) * k_dessin, t * k_dessin), false, Color(1, 1, 1, a))

	# une de ses empreintes, vue de dessus, la pointe vers la droite : la paume large, quatre griffes devant
	func _empreinte(o: Vector2, r: float, c: Color) -> void:
		var paume := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			paume.append(o + Vector2(cos(a) * r, sin(a) * r * 0.62))
		draw_colored_polygon(paume, c)
		for k in 4:
			var dy := (k - 1.5) * r * 0.42
			var d0 := o + Vector2(r * 1.15, dy)
			draw_line(d0, d0 + Vector2(r * 0.85, dy * 0.25), c, maxf(1.0, r * 0.22), true)
