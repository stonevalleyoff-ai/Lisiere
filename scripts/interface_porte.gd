extends Control
# Lisière — la porte : le compte, depuis l'écran-titre (scripts/interface_porte.gd)
# Une page de papier, comme la pause : se connecter, créer un compte, demander un nouveau mot de passe, et (revenu du courriel)
# en choisir un ; connecté, l'adresse et « Se déconnecter ». Le compte est celui de Stone Valley (scripts/session.gd).
# Dans un navigateur, les deux champs sont de vrais champs de la page, posés sur la feuille à leur place : le clavier du
# téléphone s'ouvre comme il faut (une adresse, un mot de passe), et le gestionnaire de mots de passe peut les remplir. Hors
# navigateur, ce sont des LineEdit.

signal fermee

const P := preload("res://scripts/palette.gd")
const T := preload("res://scripts/interface_theme.gd")
const Bouton := preload("res://scripts/interface_bouton.gd")
const Carnet := preload("res://scripts/interface_carnet.gd")
const Session := preload("res://scripts/session.gd")

const SOUS := {
	"connexion": "Le même compte que pour Stone Valley.",
	"inscription": "Un compte, pour Lisière et pour Stone Valley.",
	"oubli": "Un lien pour choisir un nouveau mot de passe.",
	"nouveau": "Choisis un nouveau mot de passe.",
	"compte": "",
}
const VALIDER := {"connexion": "Se connecter", "inscription": "Créer le compte", "oubli": "Envoyer le lien", "nouveau": "Enregistrer",
	"compte": "Enregistrer le nom"}

var session
var mode := "connexion"
var tactile := false
var page: Carnet.Page
var _voile: ColorRect
var _titre: Label
var _sous: Label
var _adresse: Champ
var _mdp: Champ
var _nom: Champ              # (connecté : le nom au tableau des scores)
var _msg: Label
var _valider: Bouton
var _bascule: Bouton
var _oubli: Bouton
var _retour: Bouton
var _occupe := false
var _t := 0.0
var _entrees := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_voile = ColorRect.new()
	_voile.color = Color(P.NUIT, 0.7)
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_voile)
	page = Carnet.Page.new(5.0)
	add_child(page)
	page.marges(36, 18)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.contenu.add_child(v)
	_titre = Carnet.Encre.libelle("Ton compte", T.titre(), 36, P.ENCRE)
	v.add_child(_titre)
	_sous = Carnet.Encre.libelle("", T.titre_italique(), 17, P.ENCRE_DOUCE)
	v.add_child(_sous)
	v.add_child(Carnet.Filet.new(0.4))
	_adresse = Champ.new("email", "adresse e-mail", "username")
	v.add_child(_adresse)
	_mdp = Champ.new("password", "mot de passe", "current-password")
	v.add_child(_mdp)
	_nom = Champ.new("text", "ton nom au tableau des scores", "nickname")
	v.add_child(_nom)
	_msg = Carnet.Encre.libelle("", T.texte_moyen(), 15, P.SANG)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	_valider = Bouton.new("Se connecter", 22, true, true)
	_valider.pressed.connect(valider)
	h.add_child(_valider)
	_retour = Bouton.new("Retour", 18, true)
	_retour.pressed.connect(fermer)
	h.add_child(_retour)
	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_theme_constant_override("separation", 14)
	v.add_child(h2)
	_bascule = Bouton.new("Créer un compte", 16, true)
	_bascule.pressed.connect(_basculer)
	h2.add_child(_bascule)
	_oubli = Bouton.new("Mot de passe oublié", 16, true)
	_oubli.pressed.connect(func(): mettre_mode("oubli"))
	h2.add_child(_oubli)
	resized.connect(_disposer)


func ouvrir(m: String = "") -> void:
	if m == "":
		m = "compte" if session != null and session.connecte() else "connexion"
	mettre_mode(m)
	_t = 0.0
	visible = true
	_entrees = _compter_entrees()
	if m != "compte" and m != "nouveau" and not tactile:
		_adresse.prendre_focus.call_deferred()
	if m == "compte":
		_lire_compte()


func fermer() -> void:
	if not visible:
		return
	visible = false
	_mdp.vider()
	Champ.rendre_le_clavier()
	fermee.emit()


func mettre_mode(m: String) -> void:
	mode = m
	_sous.text = SOUS[m]
	if m == "compte":
		_sous.text = "Ton compte : %s" % (session.email if session != null else "")
	_valider.libelle = VALIDER[m]
	_valider._mesurer()
	_adresse.visible = m in ["connexion", "inscription", "oubli"]
	_mdp.visible = m in ["connexion", "inscription", "nouveau"]
	_nom.visible = m == "compte"
	_mdp.autocomplete("current-password" if m == "connexion" else "new-password")
	_bascule.visible = m in ["connexion", "inscription", "oubli", "compte"]
	_bascule.libelle = "Créer un compte" if m == "connexion" else ("Se déconnecter" if m == "compte" else "J'ai déjà un compte")
	_bascule._mesurer()
	_oubli.visible = m == "connexion"
	_retour.libelle = "Retour" if m != "compte" else "Fermer"
	_retour._mesurer()
	dire("")
	_disposer.call_deferred()


func dire(t: String, bien: bool = false) -> void:
	_msg.text = t
	_msg.visible = t != ""
	_msg.add_theme_color_override("font_color", P.MOUSSE if bien else P.SANG)
	_disposer.call_deferred()


func valider() -> void:
	if _occupe or session == null:
		return
	var adresse := _adresse.texte().strip_edges()
	var mdp := _mdp.texte()
	if mode == "compte":
		_occupe = true
		dire("…", true)
		var rn: Dictionary = await session.nommer(_nom.texte())
		_occupe = false
		if rn.get("ok", false):
			_nom.ecrire(str(rn.get("pseudo", "")))
			dire("Ton nom au tableau : %s." % str(rn.get("pseudo", "")), true)
		else:
			dire(str(rn.get("erreur", "erreur inattendue")))
		return
	if mode in ["connexion", "inscription", "oubli"] and not _adresse_valide(adresse):
		dire("adresse e-mail invalide")
		return
	if mode in ["connexion", "inscription", "nouveau"] and mdp.length() < Session.MDP_MIN:
		dire("mot de passe : %d caractères au moins" % Session.MDP_MIN)
		return
	_occupe = true
	dire("…", true)
	var r: Dictionary
	match mode:
		"connexion":
			r = await session.connexion(adresse, mdp)
			if r["ok"]:
				_mdp.vider()
				mettre_mode("compte")
				_lire_compte("Bienvenue. ")
		"inscription":
			r = await session.inscription(adresse, mdp)
			if r["ok"]:
				_mdp.vider()
				if r.get("entre", false):
					mettre_mode("compte")
					dire("Compte créé. Bienvenue.", true)
				else:
					mettre_mode("connexion")
					dire("Compte créé : ouvre le courriel de confirmation, puis connecte-toi.", true)
		"oubli":
			r = await session.oubli(adresse)
			if r["ok"]:
				mettre_mode("connexion")
				dire("Si un compte existe pour cette adresse, le lien est parti.", true)
		"nouveau":
			r = await session.changer_mdp(mdp)
			if r["ok"]:
				_mdp.vider()
				mettre_mode("compte")
				dire("Mot de passe enregistré.", true)
	if not r.get("ok", false):
		dire(str(r.get("erreur", "erreur inattendue")))
	_occupe = false


func _basculer() -> void:
	if mode == "compte":
		session.deconnexion()
		mettre_mode("connexion")
		dire("Tu as quitté ton compte.", true)
	else:
		mettre_mode("inscription" if mode == "connexion" else "connexion")


# connecté : le nom au tableau (choisi ici, sinon celui de Stone Valley), la meilleure partie et son rang
func _lire_compte(avant: String = "") -> void:
	if session == null or not session.connecte():
		return
	var r: Dictionary = await session.moi()
	if mode != "compte" or not visible:
		return
	if not r.get("ok", false):
		dire(avant + "Le tableau des scores ne se lit pas pour l'instant.", avant != "")
		return
	_nom.ecrire(str(r.get("pseudo", "")))
	var m = r.get("meilleur")
	if m == null:
		dire(avant + "Pas encore de partie au tableau : tes nuits y entreront à la fin de ta prochaine partie.", true)
	else:
		dire(avant + "Ta meilleure partie : %d nuit%s, rang %d au tableau." % [int(m), "s" if int(m) > 1 else "", int(r.get("rang", 0))], true)


static func _adresse_valide(a: String) -> bool:
	var at := a.find("@")
	return at > 0 and a.find("@", at + 1) < 0 and not a.contains(" ") and a.substr(at + 1).contains(".") and not a.ends_with(".")


func _disposer() -> void:
	var s := size
	# (la feuille prend la hauteur de ce qu'elle porte : deux champs, ou seulement l'adresse, ou rien)
	var haut := page.contenu.get_combined_minimum_size().y + 8.0
	var ps := Vector2(minf(600.0, s.x - 40.0), minf(haut, s.y - 20.0))
	page.size = ps
	# (au doigt, la feuille monte en haut : le clavier du téléphone prend le bas de l'écran)
	page.position = Vector2((s.x - ps.x) * 0.5, 10.0 if tactile else (s.y - ps.y) * 0.5)


func _process(d: float) -> void:
	if not visible:
		return
	_t += d
	var u := smoothstep(0.0, 0.25, _t)
	_voile.color.a = 0.7 * u
	page.modulate.a = u
	# (Entrée dans un champ de la page web : valider)
	var n := _compter_entrees()
	if n != _entrees:
		_entrees = n
		valider()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("pause"):
		fermer()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("valider"):
		valider()
		get_viewport().set_input_as_handled()


func _compter_entrees() -> int:
	if not OS.has_feature("web"):
		return _entrees
	var n = JavaScriptBridge.eval("window.lisiere_entrees || 0", true)
	return int(n) if typeof(n) in [TYPE_INT, TYPE_FLOAT] else 0


# --- un champ ---

# un cadre d'encre sur le papier ; dedans, un vrai champ de la page web (posé à sa place à chaque image, à l'échelle du canevas),
# ou hors navigateur un LineEdit
class Champ extends Control:
	const JS_PREPARER := """(function(){if(window.lisiere_placer)return;
var s=document.createElement('style');s.textContent='.lisiere-champ{position:fixed;display:none;z-index:20;box-sizing:border-box;border:0;outline:0;margin:0;padding:0 .6em;background:transparent;color:#16130f;font-family:"IM Fell English",Georgia,"Times New Roman",serif;-webkit-appearance:none;appearance:none;border-radius:0}.lisiere-champ::placeholder{color:rgba(43,38,32,.45)}.lisiere-champ:-webkit-autofill{-webkit-box-shadow:0 0 0 60px #e4d8bf inset;-webkit-text-fill-color:#16130f}';document.head.appendChild(s);
var f=document.createElement('form');f.id='lisiere-porte';f.setAttribute('autocomplete','on');f.style.cssText='position:fixed;left:0;top:0;width:0;height:0;margin:0;padding:0';
f.addEventListener('submit',function(e){e.preventDefault();window.lisiere_entrees=(window.lisiere_entrees||0)+1;});document.body.appendChild(f);
window.lisiere_placer=function(id,x,y,w,h,fs,v){var i=document.getElementById(id);if(!i)return;if(!v){if(i.style.display!=='none'){i.style.display='none';if(document.activeElement===i)i.blur();}return;}
var c=document.getElementById('canvas')||document.querySelector('canvas');var r=c.getBoundingClientRect();var k=r.width/(c.width||1);
i.style.display='block';i.style.left=(r.left+x*k)+'px';i.style.top=(r.top+y*k)+'px';i.style.width=(w*k)+'px';i.style.height=(h*k)+'px';i.style.fontSize=Math.max(12,fs*k)+'px';};
})()"""
	const JS_CREER := """(function(){var i=document.getElementById('%s');if(!i){i=document.createElement('input');i.id='%s';i.name='%s';i.className='lisiere-champ';
i.type='%s';i.placeholder='%s';i.setAttribute('autocomplete','%s');i.setAttribute('autocapitalize','off');i.setAttribute('autocorrect','off');i.spellcheck=false;
i.addEventListener('keydown',function(e){e.stopPropagation();if(e.key==='Escape'){i.blur();}});i.addEventListener('keyup',function(e){e.stopPropagation();});
var f=document.getElementById('lisiere-porte');(f||document.body).appendChild(i);var b=document.createElement('button');b.type='submit';b.style.display='none';if(f&&!f.querySelector('button'))f.appendChild(b);}})()"""
	static var _n := 0

	var _web := false
	var _id := ""
	var _type := ""
	var _ligne: LineEdit
	var _cadre := StyleBoxFlat.new()
	var _dernier := []

	func _init(type: String, indice: String, auto: String) -> void:
		custom_minimum_size = Vector2(0, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_type = type
		_cadre.bg_color = Color(P.PAPIER.darkened(0.04), 0.9)
		_cadre.border_color = Color(P.ENCRE, 0.55)
		_cadre.set_border_width_all(1)
		_cadre.border_width_bottom = 2
		_cadre.set_corner_radius_all(3)
		_cadre.anti_aliasing = true
		_web = OS.has_feature("web")
		if _web:
			_n += 1
			_id = "lisiere-champ-%d" % _n
			JavaScriptBridge.eval(JS_PREPARER, true)
			JavaScriptBridge.eval(JS_CREER % [_id, _id, type, type, indice, auto], true)
		else:
			_ligne = LineEdit.new()
			_ligne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_ligne.placeholder_text = indice
			_ligne.secret = type == "password"
			_ligne.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if type == "password" else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
			_ligne.add_theme_font_override("font", T.texte_moyen())
			_ligne.add_theme_font_size_override("font_size", 17)
			_ligne.add_theme_color_override("font_color", P.ENCRE)
			_ligne.add_theme_color_override("font_placeholder_color", Color(P.ENCRE_DOUCE, 0.45))
			_ligne.add_theme_color_override("caret_color", P.ENCRE)
			_ligne.add_theme_color_override("selection_color", Color(P.BRAISE, 0.35))
			_ligne.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			_ligne.add_theme_constant_override("outline_size", 0)
			var vide := StyleBoxEmpty.new()
			vide.content_margin_left = 10
			vide.content_margin_right = 10
			for k in ["normal", "focus", "read_only"]:
				_ligne.add_theme_stylebox_override(k, vide)
			_ligne.text_submitted.connect(func(_t): _valider_parent())
			add_child(_ligne)

	func _valider_parent() -> void:
		var p := get_parent()
		while p != null and not p.has_method("valider"):
			p = p.get_parent()
		if p != null:
			p.valider()

	func texte() -> String:
		if _web:
			var v = JavaScriptBridge.eval("(document.getElementById('%s')||{}).value||''" % _id, true)
			return str(v) if typeof(v) == TYPE_STRING else ""
		return _ligne.text

	func ecrire(t: String) -> void:
		if _web:
			JavaScriptBridge.eval("(function(){var i=document.getElementById('%s');if(i)i.value=%s;})()" % [_id, JSON.stringify(t)], true)
		else:
			_ligne.text = t

	func vider() -> void:
		if _web:
			JavaScriptBridge.eval("(function(){var i=document.getElementById('%s');if(i)i.value='';})()" % _id, true)
		else:
			_ligne.text = ""

	func autocomplete(a: String) -> void:
		if _web:
			JavaScriptBridge.eval("(function(){var i=document.getElementById('%s');if(i)i.setAttribute('autocomplete','%s');})()" % [_id, a], true)

	func prendre_focus() -> void:
		if _web:
			JavaScriptBridge.eval("(function(){var i=document.getElementById('%s');if(i)i.focus();})()" % _id, true)
		else:
			_ligne.grab_focus()

	# la porte fermée : le canevas du jeu reprend le clavier
	static func rendre_le_clavier() -> void:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("(function(){if(document.activeElement&&document.activeElement.blur)document.activeElement.blur();var c=document.getElementById('canvas')||document.querySelector('canvas');if(c)c.focus();})()", true)

	func _draw() -> void:
		draw_style_box(_cadre, Rect2(Vector2.ZERO, size))

	func _process(_d: float) -> void:
		if not _web:
			return
		var v := is_visible_in_tree() and modulate.a > 0.0
		var t := get_viewport().get_final_transform() * get_global_transform_with_canvas()
		var a := t * Vector2.ZERO
		var b := t * size
		var fs := 17.0 * (b.y - a.y) / maxf(1.0, size.y)
		var cle := [v, a.round(), b.round(), roundf(fs)]
		if cle == _dernier:
			return
		_dernier = cle
		JavaScriptBridge.eval("window.lisiere_placer&&window.lisiere_placer('%s',%f,%f,%f,%f,%f,%s)" % [_id, a.x, a.y, b.x - a.x, b.y - a.y, fs, "true" if v else "false"], true)

	func _exit_tree() -> void:
		if _web:
			JavaScriptBridge.eval("(function(){var i=document.getElementById('%s');if(i)i.remove();})()" % _id, true)
