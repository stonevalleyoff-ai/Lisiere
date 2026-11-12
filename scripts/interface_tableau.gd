extends Control
# Lisière — le tableau des scores (scripts/interface_tableau.gd)
# Une page du carnet, depuis l'écran-titre : les veilleuses qui ont tenu le plus de nuits, chacune une fois (sa meilleure
# partie), avec son nom, ses nuits, le lieu. Toi en rouge, et ton rang même si tu es plus bas. Lu dans la base de Stone Valley
# (scripts/session.gd, lisiere_tableau) ; sans compte, on le lit aussi, mais on n'y entre pas.

signal fermee
signal vers_le_compte

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")
const Bouton := preload("res://scripts/interface_bouton.gd")
const Carnet := preload("res://scripts/interface_carnet.gd")

var session
var tactile := false
var page: Carnet.Page
var _voile: ColorRect
var _sous: Label
var _defile: ScrollContainer
var _grille: GridContainer
var _etat: Label
var _compte: Bouton
var _t := 0.0
var _demande := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_voile = ColorRect.new()
	_voile.color = Color(P.NUIT, 0.7)
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_voile)
	page = Carnet.Page.new(9.0)
	add_child(page)
	page.marges(36, 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.contenu.add_child(v)
	v.add_child(Carnet.Encre.libelle("Le tableau des nuits", T.titre(), 34, P.ENCRE))
	_sous = Carnet.Encre.libelle("Celles et ceux qui ont tenu le plus de nuits, chacun sa meilleure partie.", T.titre_italique(), 16, P.ENCRE_DOUCE)
	_sous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sous)
	v.add_child(Carnet.Filet.new(0.4))
	_defile = ScrollContainer.new()
	_defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_defile)
	_grille = GridContainer.new()
	_grille.columns = 4
	_grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grille.add_theme_constant_override("h_separation", 18)
	_grille.add_theme_constant_override("v_separation", 2)
	_defile.add_child(_grille)
	_etat = Carnet.Encre.libelle("", T.texte_moyen(), 15, P.ENCRE_DOUCE)
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_etat)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	_compte = Bouton.new("Se connecter", 18, true)
	_compte.pressed.connect(func(): vers_le_compte.emit())
	h.add_child(_compte)
	var fermer_ := Bouton.new("Fermer", 20, true, true)
	fermer_.pressed.connect(fermer)
	h.add_child(fermer_)
	resized.connect(_disposer)


func ouvrir() -> void:
	_t = 0.0
	visible = true
	_disposer()
	_compte.visible = session == null or not session.connecte()
	montrer([], "Le tableau se lit…")
	if session == null:
		return
	_demande += 1
	var n := _demande
	var r: Dictionary = await session.tableau(20)
	if not visible or n != _demande:
		return
	if not r.get("ok", false):
		montrer([], "Le tableau ne se lit pas pour l'instant (pas de réseau ?).")
		return
	var lignes: Array = r["lignes"]
	var pied := ""
	if lignes.is_empty():
		pied = "Personne encore : finis une partie, connecté, et tes nuits ouvriront le tableau."
	elif not session.connecte():
		pied = "Connecte-toi avant d'entrer dans la nuit : tes nuits y seront inscrites."
	elif not lignes.any(func(l): return l.get("moi", false)):
		pied = "Tu n'y es pas encore : tes nuits y entreront à la fin de ta prochaine partie."
	montrer(lignes, pied)


func fermer() -> void:
	if visible:
		visible = false
		fermee.emit()


# les lignes du tableau : { rang, pseudo, nuits, lieu, moi } (et un mot dessous)
func montrer(lignes: Array, pied: String) -> void:
	for c in _grille.get_children():
		c.queue_free()
	if not lignes.is_empty():
		for k in 4:
			_case(["", "Veilleuse", "Nuits", "Lieu"][k], T.capitales(), 13, P.ENCRE_DOUCE, k)
		var avant := 0
		for l in lignes:
			var rang := int(l.get("rang", 0))
			var moi: bool = l.get("moi", false)
			var c := P.SANG if moi else P.ENCRE
			# (un rang qui saute : on n'est pas dans les premiers, on se voit quand même, plus bas)
			if rang > avant + 1 and avant > 0 and moi:
				for k in 4:
					_case("⋯" if k == 1 else "", T.texte(), 15, P.ENCRE_DOUCE, k)
			avant = rang
			var n := int(l.get("nuits", 0))
			_case("%d" % rang, T.titre(), 19, c, 0)
			_case(str(l.get("pseudo", "")), T.titre(), 19, c, 1)
			_case("%d nuit%s" % [n, "s" if n > 1 else ""], T.texte_gras(), 15, c, 2)
			_case(str(l.get("lieu", "")), T.titre_italique(), 15, P.ENCRE_DOUCE if not moi else c, 3)
	_etat.text = pied
	_etat.visible = pied != ""


# une case : sa colonne (0 le rang, 1 le nom, qui prend la place, 2 les nuits, 3 le lieu) ; un texte trop long finit en « … »
const LARGEURS := [34.0, 0.0, 74.0, 150.0]

func _case(t: String, f: Font, taille: int, c: Color, colonne: int) -> void:
	var l := Carnet.Encre.libelle(t, f, taille if not tactile else maxi(12, taille - 2), c, false)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if colonne == 0:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if colonne == 1:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 80.0
	else:
		l.custom_minimum_size.x = LARGEURS[colonne] * (0.85 if tactile else 1.0)
	_grille.add_child(l)


func _disposer() -> void:
	var s := size
	var ps := Vector2(minf(640.0, s.x - 40.0), minf(520.0, s.y - 24.0))
	page.size = ps
	page.position = (s - ps) * 0.5


func _process(d: float) -> void:
	if not visible:
		return
	_t += d
	var u := smoothstep(0.0, 0.25, _t)
	_voile.color.a = 0.7 * u
	page.modulate.a = u


func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("pause") or e.is_action_pressed("valider")):
		fermer()
		get_viewport().set_input_as_handled()
