extends Node
# Lisière — le jeu (scripts/principal.gd)
# Un lieu vrai du monde d'Orvane, une veilleuse, des jours de quatre minutes et des nuits qui durent selon la saison du monde.
# Le jour, on récolte et l'on chasse les bêtes du lieu ; la nuit, on tient près d'un feu : ses chasseurs viennent, tournent à la
# lisière de la lumière, mordent dans le noir. La peur monte dans l'obscurité ; au comble, ce qu'on a tué revient, en échos.
# Chaque bête croisée est comptée (« rencontre »), chaque bête tuée aussi (« prélèvement »), dans le lieu d'Orvane où c'est
# arrivé : à la fin de la partie, le kit en fait un lot (docs/4), déposé dans le monde d'Orvane (scripts/regles.gd : sa clé, son monde) ; l'essai et la vitrine n'envoient rien.
# La mémoire d'Orvane (docs/50) : chaque bête se conduit d'après ce que sa population a appris des joueurs (scripts/bete.gd), et la
# partie raconte ce qu'elle lui apprendra (_raconter) : une bête blessée qui s'en va, un chasseur tenu par un feu ou par la torche,
# un assaut, une morsure qui tue. Le kit ne garde ces comptes que si le monde lu tient la mémoire.
#   outils/godot.sh --path .                       jouer
#   outils/godot.sh --headless --path . -- --essai l'essai sans écran (scripts/essai.gd)
#   outils/godot.sh --path . -- --memoire traque   essayer une mémoire à la main (scripts/donnees.gd, MEMOIRES) : rien n'est envoyé

const R := preload("res://scripts/regles.gd")
const Donnees := preload("res://scripts/donnees.gd")
const Monde := preload("res://scripts/monde.gd")
const Joueur := preload("res://scripts/joueur.gd")
const Bete := preload("res://scripts/bete.gd")
const Feu := preload("res://scripts/feu.gd")
const Interface := preload("res://scripts/interface.gd")
const Sons := preload("res://scripts/sons.gd")
const Yeux := preload("res://scripts/yeux.gd")
const Essai := preload("res://scripts/essai.gd")
const Tactile := preload("res://scripts/tactile.gd")
const Effets := preload("res://scripts/effets.gd")
const Vitrine := preload("res://scripts/vitrine.gd")
const Ciel := preload("res://scripts/ciel.gd")
const Session := preload("res://scripts/session.gd")
const PartieGardee := preload("res://scripts/partie_gardee.gd")
const Bestiaire := preload("res://scripts/bestiaire.gd")
const Climat := preload("res://scripts/climat.gd")
const Incendie := preload("res://scripts/incendie.gd")
const Carte := preload("res://scripts/carte.gd")
const Pont := preload("res://scripts/pont.gd")
const TempsSol := preload("res://scripts/temps_sol.gd")
const IncendieFlammes := preload("res://scripts/incendie_flammes.gd")
const SAUVEGARDE := "user://lisiere.json"
const DUREE_MORT := 2.4          # la veilleuse tombe, puis l'écran de fin

var donnees := Donnees.new()
var ui
var sons
var tactile
var effets
# « haute » sur un ordinateur ; « mobile » sur un téléphone ou une tablette : moins de particules, pas d'ombres portées
var qualite := "haute"
var scene: Node2D
var monde
var joueur
var camera: Camera2D
var obscurite: CanvasModulate
var couche_yeux: CanvasLayer
var couche_ciel: CanvasLayer
var ciel
# le temps qu'il fait dans le lieu, ce cycle du monde d'Orvane (docs/45) ; {} : un monde sans météo
var meteo: Dictionary = {}
var feu_temps := 1.0
# le temps qu'il fait pendant la partie (scripts/climat.gd), et l'incendie qu'allume la foudre (scripts/incendie.gd)
var climat
var incendie
var yeux
var feux: Array = []
var en_partie := false
var en_pause := false
var au_titre := false
var biome := ""
var biome_info: Dictionary = {}
var faune: Dictionary = {}
var saison := "été"
var ouvert := false           # le monde ouvert (MONDE-OUVERT.md)
var carte                     # sa carte (scripts/carte.gd) ; null : un lieu fermé, ou la carte manque
var _region := -1             # la région où est la veilleuse
var decouvertes := {}         # les régions où elle est entrée (leur rang sur la carte) : la carte du carnet les montre
var _faunes := {}             # ce qui vit dans chaque biome déjà lu (le monde ouvert les lit en approchant)
var _meteos := {}
var _lecture := ""            # le biome qu'on est en train de lire
var _illisibles := {}         # ceux qui ne se lisent pas (hors ligne, hors de la copie gardée)
var ponts: Array = []         # les ponts de fortune qui tiennent encore (scripts/pont.gd)
var altitude := 0.0           # l'étage du relief où est la veilleuse (0 : en bas ; scripts/carte.gd, palier), lissé
var sous_terre := 0.0         # de 0 (à l'air libre) à 1 (dans une grotte : ni jour, ni temps qu'il fait), lissé
var pont_possible := false    # la veilleuse est au bord d'une rivière, là où un pont peut se poser (regardé trois fois par seconde)
var _pont_vu := 0.0
var part_nuit := 0.33
var horloge := 0.0
var jour := 1
var nuits := 0
var croisees := 0
var chassees := 0
var tuees: Array = []
var vues: Dictionary = {}
var rencontres: Dictionary = {}
var prelevements: Dictionary = {}
# ce que la partie apprend aux bêtes, et qui part vers Orvane (_raconter) : { blessure, effarouchement, attaque, joueur_tombe }
var appris: Dictionary = {}
var compte := ""
var record := 0
var essai = null
var session
# la graine du lieu (il se sème d'après elle) ; le numéro de la partie au tableau des scores ("" : elle n'y est pas)
var graine := 0
var partie_id := ""
var _garde_ms := 0
var _directeur := 0.0
var _vague := 0.0
var _agir := 0.0
var _grogne := 0.0
var _etait_nuit := false
var _deja: Dictionary = {}
# le compteur d'images par seconde : affiché ou non (gardé dans la sauvegarde), et son étiquette
var ips := false
var _ips_label: Label
# l'image d'un téléphone qui traîne : mesurée une fois, au début de la première partie (_regler_image)
var _image_ms := 0
var _image_vue := 0
var _image_n := 0
var _image_fait := false
var _mort := -1.0
# ce que le dernier geste vise : son son, ses éclats et l'arrêt d'image viennent quand il touche, à l'image (joueur.impact)
var _coup_vise := {}
var _coup_age := 0.0
var _pause_vue := false


func _ready() -> void:
	randomize()
	_actions()
	if DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--mobile" in OS.get_cmdline_user_args():
		qualite = "mobile"
	effets = Effets.new()
	effets.jeu = self
	add_child(effets)
	sons = Sons.new()
	sons.mobile = qualite == "mobile"
	add_child(sons)
	climat = Climat.new()
	climat.jeu = self
	add_child(climat)
	climat.change.connect(_temps_change)
	incendie = Incendie.new()
	incendie.jeu = self
	add_child(incendie)
	incendie.pris.connect(_incendie_pris)
	# le compte, le même que celui de Stone Valley (scripts/session.gd) : facultatif, la partie se joue pareil
	session = Session.new()
	add_child(session)
	ui = Interface.new()
	add_child(ui)
	ui.relier_session(session)
	ui.commencer.connect(_lieu_choisi)
	ui.reprendre_partie.connect(reprendre)
	ui.recommencer.connect(func(): _commencer(biome, {}, ouvert))
	ui.vers_titre.connect(_titre)
	tactile = Tactile.new()
	tactile.jeu = self
	add_child(tactile)
	if qualite == "mobile":
		ui.alleger()
	_charger()
	_compteur_ips()
	# l'application installée (une PWA, outils/pwa.js) : une version nouvelle s'ouvre à l'écran-titre, jamais pendant une partie
	if OS.has_feature("web"):
		JavaScriptBridge.pwa_update_available.connect(_nouvelle_version)
	Orvane.jeu = "lisiere"
	Orvane.monde = R.MONDE_DES_LOTS
	Orvane.cle_jeu = R.CLE_JEU
	_memoire_forcee()
	if "--essai" in OS.get_cmdline_user_args():
		essai = Essai.new()
		add_child(essai)
		return
	if "--vitrine" in OS.get_cmdline_user_args():
		essai = Vitrine.new()
		add_child(essai)
		return
	if "--betes" in OS.get_cmdline_user_args():
		# (la vitrine du bestiaire : toutes les bêtes d'un lieu, à regarder et à filmer)
		essai = load("res://scripts/vitrine_betes.gd").new()
		add_child(essai)
		return
	_titre()


# une mémoire forcée, pour essayer à la main tant que le monde publié n'en porte pas : -- --memoire <nom> (crainte, confiance,
# traque, feu, accoutumance : scripts/donnees.gd, MEMOIRES), ou ?memoire=<nom> au bout de l'adresse du jeu web. Elle ne change que
# ce que le jeu lit des populations du lieu ; une partie jouée ainsi n'envoie rien à Orvane. L'essai pose les siennes lui-même.
func _memoire_forcee() -> void:
	var nom := ""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--memoire")
	if i >= 0 and i + 1 < args.size():
		nom = str(args[i + 1])
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('memoire') || ''", true)
		if typeof(q) == TYPE_STRING and str(q) != "":
			nom = str(q)
	if nom == "" or "--essai" in args:
		return
	if Donnees.MEMOIRES.has(nom):
		donnees.memoire_forcee = nom
	else:
		print("--memoire : « %s » n'est pas une mémoire connue (%s) ; rien n'est forcé." % [nom, ", ".join(PackedStringArray(Donnees.MEMOIRES.keys()))])


# le compteur d'images par seconde, discret, en haut au milieu. Il s'allume et s'éteint à la pause (basculer_ips), et le choix
# est gardé ; ?ips au bout de l'adresse du jeu web l'allume, ?ips=0 l'éteint ; -- --ips hors navigateur
func _compteur_ips() -> void:
	if "--ips" in OS.get_cmdline_user_args():
		ips = true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and str(q).contains("ips"):
			ips = not (str(q).contains("ips=0") or str(q).contains("ips=non"))
			_sauver()
	var couche := CanvasLayer.new()
	couche.layer = 20
	add_child(couche)
	_ips_label = Label.new()
	_ips_label.add_theme_font_size_override("font_size", 13)
	_ips_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	_ips_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_ips_label.add_theme_constant_override("outline_size", 4)
	_ips_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ips_label.position.y = 64.0
	_ips_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ips_label.visible = ips
	couche.add_child(_ips_label)
	var minuteur := Timer.new()
	minuteur.wait_time = 0.5
	minuteur.autostart = true
	minuteur.timeout.connect(func():
		if _ips_label.visible:
			var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var appels := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_ips_label.text = "%d images/s · %.1f ms de jeu · %d appels · ×%.2f · %s" % [Engine.get_frames_per_second(), ms, appels,
				DisplayServer.screen_get_scale(), qualite])
	couche.add_child(minuteur)


# sur un téléphone, dans un navigateur, l'image se calcule à 1,5 fois la résolution CSS (export_presets.cfg, head_include). Si
# elle traîne (moins de 24 images par seconde, six secondes durant, une fois le lieu installé), elle passe à 1 : 2,25 fois moins
# de pixels à peindre. Elle y reste ; on la surveille tant que la partie dure (le temps qu'il fait peut peser plus tard) ; ?dpr= au
# bout de l'adresse décide à sa place.
func _regler_image(_delta: float) -> void:
	if _image_fait or qualite != "mobile" or not OS.has_feature("web"):
		return
	# (à l'horloge de l'appareil, par fenêtres de six secondes, tant que la partie dure : un orage, une crue peuvent peser
	# plus tard que les premières secondes. Une pause, un onglet caché : on recommence à compter)
	var ms := Time.get_ticks_msec()
	if _image_ms == 0 or ms - _image_vue > 700:
		_image_ms = ms + (5000 if _image_ms == 0 else 1500)
		_image_n = 0
	_image_vue = ms
	if ms < _image_ms:
		return
	_image_n += 1
	if ms - _image_ms < 6000:
		return
	var par_seconde := _image_n * 1000.0 / (ms - _image_ms)
	_image_ms = ms
	_image_n = 0
	if par_seconde < 24.0:
		_image_fait = true
		if DisplayServer.screen_get_scale() > 1.05:
			JavaScriptBridge.eval("window.lisiere_dpr && !window.lisiere_dpr.force && window.lisiere_dpr.set(1.0)", true)


# la pause : afficher ou masquer le compteur ; il le reste d'une partie à l'autre
func basculer_ips() -> bool:
	ips = not ips
	_ips_label.visible = ips
	_sauver()
	return ips


# les touches, posées ici : par leur place sur le clavier (ZQSD sur un clavier français, WASD sur un anglais)
func _actions() -> void:
	var touches := {
		"haut": [KEY_W, KEY_UP], "bas": [KEY_S, KEY_DOWN], "gauche": [KEY_A, KEY_LEFT], "droite": [KEY_D, KEY_RIGHT],
		"agir": [KEY_SPACE], "feu": [KEY_1, KEY_KP_1], "torche": [KEY_2, KEY_KP_2], "lance": [KEY_3, KEY_KP_3], "pont": [KEY_4, KEY_KP_4],
		"manger": [KEY_E], "nourrir": [KEY_F], "cuire": [KEY_C], "pause": [KEY_ESCAPE, KEY_P], "valider": [KEY_ENTER, KEY_KP_ENTER],
	}
	for a in touches:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in touches[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("agir", clic)


# --- l'écran-titre, le début d'une partie ---

func _titre() -> void:
	if en_partie and _mort < 0.0:
		# (les bêtes ne sont pas gardées : celles qu'on a frappées en réchappent, et la partie gardée le sait)
		_blessees_en_vie()
		_garder()
	_vider()
	ui.montrer_chargement("Le monde d'Orvane s'éveille…")
	await donnees.charger_index()
	ui.montrer_titre(_lieux_du_titre(), _infos_monde(), record)
	ui.montrer_reprise(PartieGardee.lire() if essai == null else {})
	sons.titre()
	au_titre = true
	if session != null and essai == null:
		session.renvoyer_attente()
	if OS.has_feature("web") and JavaScriptBridge.pwa_needs_update():
		_nouvelle_version()


# une version nouvelle du jeu est publiée, et l'application l'a reçue : à l'écran-titre, la page se recharge sur elle ; pendant
# une partie, elle attend le retour à l'écran-titre
func _nouvelle_version() -> void:
	if au_titre and essai == null:
		JavaScriptBridge.pwa_update()


# les lieux qu'on propose : ceux du monde, et, à l'essai, le monde ouvert (MONDE-OUVERT.md), où l'on s'éveille dans la prairie
# du centre
func _lieux_du_titre() -> Array:
	var lieux: Array = donnees.lieux().duplicate()
	for l in lieux:
		if str(l["id"]) == "prairie":
			# (juste après la forêt, sur laquelle la liste s'ouvre : une flèche à droite et on y est)
			var ou := 0
			for i in lieux.size():
				if str(lieux[i]["id"]) == "foret":
					ou = i + 1
			lieux.insert(ou, {"id": "ouvert:monde", "nom": "Le monde d'Orvane", "lignees": l["lignees"], "detail": "le monde ouvert, à l'essai : tous ses biomes, d'un seul tenant"})
			break
	return lieux


func _lieu_choisi(id: String) -> void:
	if id.begins_with("ouvert:"):
		# (on s'y éveille dans la prairie du centre : scripts/carte.gd)
		_commencer("prairie", {}, true)
	else:
		_commencer(id)


func _infos_monde() -> String:
	var c: Dictionary = donnees.index.get("cycle", {})
	var s := str(c.get("saison", {}).get("nom", ""))
	var t := "Le monde d'Orvane, cycle %s%s" % [str(c.get("n", "?")), (", " + s) if s != "" else ""]
	if donnees.en_ligne:
		return t + ", tel qu'il est ce matin."
	return t + " : la copie gardée dans le jeu (hors ligne)."


# ouvert_ : le lieu sans bord (MONDE-OUVERT.md), fabriqué par morceaux autour de la veilleuse
func _commencer(b: String, gardee: Dictionary = {}, ouvert_: bool = false) -> void:
	if b == "":
		return
	ouvert = ouvert_ or bool(gardee.get("ouvert", false))
	carte = Carte.lire(donnees.index.get("biomes", [])) if ouvert else null
	if carte != null:
		# (le monde ouvert : on s'éveille dans la prairie du centre)
		b = str(carte.regions[carte.depart]["type"])
	biome = b
	ui.montrer_chargement("Le lieu s'éveille…")
	var inst: Dictionary = await donnees.charger_lieu(b)
	if inst.is_empty():
		ui.message_titre("Ce lieu ne se lit pas pour l'instant. Choisis-en un autre.")
		return
	var f: Dictionary = donnees.faune(inst, b)
	if (f["proies_jour"].is_empty() and f["proies_nuit"].is_empty()) or f["chasseurs_nuit"].is_empty():
		ui.message_titre("Aucune bête de ce lieu ne marche sur la terre ferme pour l'instant. Choisis-en un autre.")
		return
	faune = f
	_faunes = {b: f}
	_meteos = {b: Orvane.meteo(b)}
	_illisibles = {}
	_lecture = ""
	_region = -1
	decouvertes = {}
	altitude = 0.0
	sous_terre = 0.0
	biome_info = donnees.biome(b)
	saison = str(inst.get("cycle", {}).get("saison", {}).get("nom", "été"))
	part_nuit = float(R.NUIT.get(saison, 0.4))
	meteo = Orvane.meteo(b)
	feu_temps = 1.0
	if ouvert:
		sons.preparer_les_sols()
	if qualite == "mobile":
		await _attendre_sons()
	await _dessiner_la_faune()
	_nouvelle_partie(gardee)


# les bêtes du lieu, dessinées avant la partie (scripts/bestiaire.gd les garde) : une bête qui vient n'attend pas son dessin, et
# l'image ne saute pas quand elle arrive. Quelques-unes par image, pour que l'écran d'attente vive.
# (en jouant : la faune d'un biome qu'on approche, une bête toutes les « entre » secondes ; dessinées à la file, elles
# feraient traîner l'image plusieurs secondes sur un téléphone)
func _dessiner_la_faune(laquelle: Dictionary = {}, entre: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vues := {}
	var debut := Time.get_ticks_msec()
	var f: Dictionary = laquelle if not laquelle.is_empty() else faune
	var partie := graine
	for k in f:
		for e in f[k]:
			if vues.has(e["id"]):
				continue
			vues[e["id"]] = true
			var plan: Dictionary = e["lignee"].get("plan", {})
			var avant := Time.get_ticks_usec()
			Bestiaire.lire(e["lignee"], Bestiaire.largeur_de(float(e["masse"]), Bestiaire.est_chasseur(plan)))
			if entre > 0.0:
				# (déjà dessinée : rien à attendre)
				if Time.get_ticks_usec() - avant > 1500:
					await get_tree().create_timer(entre).timeout
					if not en_partie or graine != partie:
						return
			elif Time.get_ticks_msec() - debut > 24:
				await get_tree().process_frame
				debut = Time.get_ticks_msec()


# la partie gardée sur l'appareil, reprise là où on l'avait laissée (scripts/partie_gardee.gd)
func reprendre() -> void:
	var d := PartieGardee.lire()
	if d.is_empty():
		ui.message_titre("Il n'y a plus de partie à reprendre.")
		return
	await _commencer(str(d["biome"]), d)


# sur un téléphone, les sons se fabriquent avant la partie (sons.gd, mobile) : pendant qu'on joue, ils figeraient l'image
func _attendre_sons() -> void:
	sons.preparer_lieu(biome_info.get("axes", {}))
	var t0 := Time.get_ticks_msec()
	while sons.restant() > 0 and Time.get_ticks_msec() - t0 < 30000:
		ui.montrer_chargement("Le lieu s'éveille…\nles sons s'accordent (%d)" % sons.restant())
		await get_tree().process_frame


func _nouvelle_partie(gardee: Dictionary = {}) -> void:
	au_titre = false
	_vider()
	var reprise := not gardee.is_empty()
	if reprise:
		# (ce qu'Orvane a déjà compté de cette partie, le kit l'a gardé : on ne l'oublie pas)
		graine = int(gardee.get("graine", randi()))
	else:
		Orvane.oublier()
		graine = randi()
	scene = Node2D.new()
	add_child(scene)
	obscurite = CanvasModulate.new()
	scene.add_child(obscurite)
	monde = Monde.new()
	monde.jeu = self
	monde.y_sort_enabled = true
	monde.ouvert = ouvert
	monde.carte = carte
	scene.add_child(monde.creer_sol(biome_info, graine))
	scene.add_child(monde)
	if reprise:
		# (l'heure d'abord : ce qui repoussait dans un lieu sans bord se compte depuis elle)
		horloge = float(gardee.get("horloge", 0.0))
		if ouvert:
			monde.reprendre_ouvert(gardee.get("monde", {}))
	monde.generer(biome_info, graine, gardee.get("objets", []) if (reprise and not ouvert) else [])
	joueur = Joueur.new()
	monde.add_child(joueur)
	joueur.pas.connect(_sur_pas)
	joueur.impact.connect(_sur_impact)
	joueur.chute.connect(_sur_chute)
	camera = Camera2D.new()
	camera.zoom = Vector2(R.ZOOM, R.ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	joueur.add_child(camera)
	camera.make_current()
	effets.nouvelle_partie(scene, camera, obscurite)
	couche_yeux = CanvasLayer.new()
	couche_yeux.layer = 1
	couche_yeux.follow_viewport_enabled = true
	add_child(couche_yeux)
	yeux = Yeux.new()
	yeux.jeu = self
	couche_yeux.add_child(yeux)
	couche_ciel = CanvasLayer.new()
	couche_ciel.layer = 2
	add_child(couche_ciel)
	ciel = Ciel.new()
	ciel.climat = climat
	couche_ciel.add_child(ciel)
	incendie.vider()
	climat.preparer(graine, biome_info.get("axes", {}), meteo)
	# (ce que le temps dessine dans le lieu : le sol détrempé, l'eau, la foudre ; les flammes de l'incendie)
	for dessin in [TempsSol.new(), IncendieFlammes.new()]:
		dessin.jeu = self
		scene.add_child(dessin)
		dessin.poser(scene, monde)
	monde.relief_au_dessus(scene)
	horloge = R.TRANSITION + 2.0
	jour = 1
	nuits = 0
	croisees = 0
	chassees = 0
	tuees.clear()
	vues.clear()
	rencontres.clear()
	prelevements.clear()
	appris.clear()
	_deja.clear()
	_directeur = 0.5
	_vague = 0.0
	_etait_nuit = false
	_mort = -1.0
	_coup_vise = {}
	_agir = 0.35          # (le clic qui lance la partie n'est pas un coup)
	en_pause = false
	en_partie = true
	_garde_ms = Time.get_ticks_msec()
	ui.montrer_hud()
	joueur.temperature = 50.0
	joueur.trempe = 0.0
	joueur.en_feu = 0.0
	if reprise:
		PartieGardee.appliquer(self, gardee)
		if ouvert:
			# (un lieu sans bord : le lieu se fait d'un coup là où elle était, pas autour du réveil)
			monde.suivre(joueur.position, true)
		ui.message("La partie reprend : %s, jour %d, %d nuit%s tenue%s." % [str(biome_info.get("nom", biome)), jour, nuits,
			"s" if nuits > 1 else "", "s" if nuits > 1 else ""])
		_garder()
		return
	partie_id = ""
	if essai == null:
		PartieGardee.effacer()
		_ouvrir_au_tableau()
	ui.message("Tu t'éveilles à la lisière : %s, %s. Le jour baisse vite." % [str(biome_info.get("nom", biome)), saison])
	if donnees.memoire_forcee != "":
		ui.message("Mémoire forcée, pour essayer : « %s ». Cette partie n'envoie rien à Orvane." % donnees.memoire_forcee, Color(0.75, 0.88, 1.0))
	if climat.neige_sol >= R.NEIGE_AU_SOL:
		ui.message("La neige tient au sol : on y marche moins vite.", Color(0.72, 0.82, 0.92))
	elif climat.boue_fond > 0.1:
		ui.message("Le sol est gorgé d'eau : on s'y enfonce.", Color(0.72, 0.82, 0.92))
	ui.message("Ramasse des brindilles et des pierres (Espace). Avec 4 bois et 2 pierres : un feu (1).", Color(0.95, 0.75, 0.45))


func _vider() -> void:
	en_partie = false
	en_pause = false
	ui.montrer_pause(false)
	if scene != null:
		_blessees_en_vie()
		scene.queue_free()
		scene = null
	if couche_yeux != null:
		couche_yeux.queue_free()
		couche_yeux = null
	if couche_ciel != null:
		couche_ciel.queue_free()
		couche_ciel = null
		ciel = null
	feux.clear()
	ponts.clear()
	pont_possible = false
	if incendie != null:
		incendie.vider()
	joueur = null
	monde = null
	yeux = null
	effets.vider()
	sons.taire()


# --- le temps et la lumière ---

# le souffle du vent là où est la veilleuse, de 0 à 1 : celui de l'herbe et des feuillages (monde.vent, et son shader), que
# le son du vent suit ; hors d'une partie, celui du son (Sons.rafale)
func vent() -> float:
	if monde != null and joueur != null:
		return clampf((monde.vent(joueur.position) - 0.2) / 1.15, 0.0, 1.0)
	return Sons.rafale(horloge)


# le jour là où est la veilleuse : celui du ciel, qui n'entre pas sous terre (une grotte du monde ouvert)
func lumiere_du_jour() -> float:
	return jour_du_ciel() * (1.0 - sous_terre)


func jour_du_ciel() -> float:
	var t := fmod(horloge, R.DUREE)
	var soir := R.DUREE * (1.0 - part_nuit)
	if t < R.TRANSITION:
		return t / R.TRANSITION
	if t < soir - R.TRANSITION:
		return 1.0
	if t < soir:
		return (soir - t) / R.TRANSITION
	return 0.0


func est_jour() -> bool:
	return lumiere_du_jour() > 0.5


func texte_horloge() -> String:
	var t := fmod(horloge, R.DUREE)
	var soir := R.DUREE * (1.0 - part_nuit)
	if t < soir:
		return "Jour %d · %s%s · la nuit dans %s" % [jour, saison, _texte_temps(), _duree(soir - t)]
	return "Nuit %d · %s%s · le jour dans %s" % [jour, saison, _texte_temps(), _duree(R.DUREE - t)]


# le temps qu'il fait, pour l'horloge (« , pluie ») ; rien sous un temps clair, ou dans un monde sans météo
func _texte_temps() -> String:
	var t: String = climat.temps if climat != null else ""
	return ", " + str(R.TEMPS.get(t, t)) if t != "" and t != "clair" else ""


func _duree(s: float) -> String:
	var n := int(ceil(s))
	return "%d s" % n if n < 60 else "%d min %02d" % [n / 60, n % 60]


# combien un point est éclairé, de 0 (le noir) à 1 : le jour, un feu, la torche
func eclairage(p: Vector2) -> float:
	var l := lumiere_du_jour()
	for f in feux:
		if is_instance_valid(f):
			l = maxf(l, f.eclaire(p))
	if incendie != null:
		for f in incendie.foyers:
			l = maxf(l, f.eclaire(p))
	if joueur != null and joueur.torche > 0.0:
		var d: float = p.distance_to(joueur.position)
		l = maxf(l, clampf((R.RAYON_TORCHE - d) / (R.RAYON_TORCHE * 0.4), 0.0, 1.0))
	return l


# le feu allumé dans la lumière duquel est ce point (null : aucun)
func feu_qui_protege(p: Vector2):
	var meilleur = null
	var d0 := INF
	for f in feux_et_foyers():
		if f.allume():
			var d: float = p.distance_to(f.position)
			if d < f.rayon() * 0.85 and d < d0:
				d0 = d
				meilleur = f
	return meilleur


# tout ce qui fait une lumière de feu dans le lieu : les feux de camp, et ce que l'incendie a pris (scripts/incendie.gd, Foyer)
func feux_et_foyers() -> Array:
	var tous := []
	for f in feux:
		if is_instance_valid(f):
			tous.append(f)
	if incendie != null:
		tous.append_array(incendie.foyers)
	return tous


func _feu_proche(p: Vector2, allume: bool):
	var meilleur = null
	var d0 := R.PORTEE_FEU
	for f in feux:
		if is_instance_valid(f) and (f.allume() or not allume):
			var d: float = p.distance_to(f.position)
			if d < d0:
				d0 = d
				meilleur = f
	return meilleur


func _lumieres() -> void:
	effets.teinter(obscurite, lumiere_du_jour())


# --- chaque image ---

func _process(delta: float) -> void:
	if not en_partie:
		return
	if Input.is_action_just_pressed("pause"):
		en_pause = not en_pause
		ui.montrer_pause(en_pause)
	if en_pause:
		if not _pause_vue:
			_garder()
		_pause_vue = true
		return
	if _pause_vue:
		# (le clic qui ferme la pause n'est pas un coup)
		_pause_vue = false
		_agir = 0.35
	_regler_image(delta)
	# (toutes les vingt secondes, à l'horloge de l'appareil : sur un téléphone qui rame, le temps du jeu avance moins vite)
	if Time.get_ticks_msec() - _garde_ms >= 20000:
		_garder()
	if _mort >= 0.0:
		# (elle est tombée : le monde continue un instant sans elle, puis l'écran de fin)
		_mort += delta
		_lumieres()
		effets.maj(delta)
		sons.maj(self, delta)
		if _mort >= DUREE_MORT:
			_fin()
		return
	horloge += delta
	_coup_age += delta
	if not _coup_vise.is_empty() and _coup_age > 0.45:
		_toucher_vise()
	var j := int(horloge / R.DUREE) + 1
	if j != jour:
		jour = j
		_aube()
	var nuit := jour_du_ciel() <= 0.0
	if nuit and not _etait_nuit:
		_tombee_de_la_nuit()
	_etait_nuit = nuit
	_lumieres()
	if essai == null:
		_gestes(delta)
	_corps(delta)
	_temps_du_corps(delta)
	if carte != null:
		_regions()
		_voir_les_ponts(delta)
		# (l'étage du relief où elle est, lissé : plus haut, il fait plus froid et l'on voit plus loin)
		altitude = move_toward(altitude, float(carte.palier(joueur.position)), delta * 0.7)
		# (sous terre : le noir d'une grotte, son abri ; scripts/carte.gd)
		sous_terre = move_toward(sous_terre, float(carte.sous_terre(joueur.position)), delta * 0.9)
		climat.toit = sous_terre
	_directeur_passe(delta)
	effets.maj(delta)
	sons.maj(self, delta)
	ui.maj_hud(self)
	if joueur.sante <= 0.0:
		_tomber()


func _gestes(delta: float) -> void:
	joueur.deplacer(Input.get_vector("gauche", "droite", "haut", "bas"), delta, monde)
	_agir = maxf(0.0, _agir - delta)
	if Input.is_action_pressed("agir") and _agir <= 0.0:
		_agir = R.CADENCE
		agir()
	for k in R.ORDRE_RECETTES:
		if Input.is_action_just_pressed(k):
			fabriquer(k)
	if Input.is_action_just_pressed("manger"):
		manger()
	if Input.is_action_just_pressed("nourrir"):
		nourrir_feu()
	if Input.is_action_just_pressed("cuire"):
		cuire()


# frapper la bête la plus proche à portée ; sinon, prendre ce qui est à portée
func agir() -> void:
	var p: Vector2 = joueur.position
	var cible = null
	var d0 := R.PORTEE_COUP
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role == "echo":
			continue
		var d: float = p.distance_to(b.position) - b.largeur * 0.3
		if d < d0:
			d0 = d
			cible = b
	if cible != null:
		joueur.frapper()
		var degats := R.DEGATS_LANCE if joueur.lance > 0 else R.DEGATS_POINGS
		if joueur.lance > 0:
			joueur.lance -= 1
			if joueur.lance == 0:
				ui.message("La lance s'est brisée.", Color(0.8, 0.7, 0.6))
		_viser({"bete": true, "son": "coup", "db": -2.0, "p": cible.position + Vector2(0, -cible.largeur * 0.3), "c": cible.robe})
		cible.blesser(degats, p)
		return
	var o = monde.plus_proche(p, R.PORTEE_RECOLTE)
	if o == null:
		return
	var genre: String = o.genre
	joueur.geste(genre, o.position)
	var g: Dictionary = o.recolter()
	var son := "bois"
	if genre == "rocher":
		son = "pierre"
	elif genre == "buisson" or genre == "touffe":
		son = "herbe"
	_viser({"son": son, "db": -4.0, "p": o.position, "genre": genre})
	for k in g:
		joueur.inventaire[k] = int(joueur.inventaire.get(k, 0)) + int(g[k])
		ui.ramasse(k, int(g[k]), o.position)
	if genre == "brindille" and o.epuise():
		monde.retirer(o)
	_conseil("feu", peut_fabriquer("feu") and feux.is_empty(), "Tu as de quoi faire un feu : touche 1.")


# un geste part : ce qu'il fera quand il touchera (le geste d'avant, s'il n'a pas encore touché, touche d'abord)
func _viser(d: Dictionary) -> void:
	_toucher_vise()
	_coup_vise = d
	_coup_age = 0.0


func _toucher_vise() -> void:
	if _coup_vise.is_empty():
		return
	var d := _coup_vise
	_coup_vise = {}
	sons.jouer(str(d["son"]), float(d["db"]), randf_range(0.9, 1.12))
	if d.has("bete"):
		effets.impact(d["p"], d["c"])
		effets.arret(0.05)
		if d.has("mort"):
			effets.mort(d["mort"][0], d["mort"][1], d["mort"][2])
			effets.arret(0.09)
			effets.secousse(0.25)
	else:
		effets.recolte(d["p"], str(d["genre"]))
		if ["arbre", "sapin", "rocher"].has(d["genre"]):
			effets.arret(0.02)


func _sur_impact(_p: Vector2, _genre: String) -> void:
	_toucher_vise()


# (le son des pas se branche lui-même sur ce signal : sons.gd)
func _sur_pas(p: Vector2) -> void:
	effets.pas(p, 0.5)


func _sur_chute(p: Vector2) -> void:
	effets.secousse(0.3)
	if effets.has_method("chute"):
		effets.chute(p)


func peut_fabriquer(quoi: String) -> bool:
	if joueur == null:
		return false
	# (un pont ne se fait qu'au bord d'une rivière, là où il peut se poser)
	if quoi == "pont" and not pont_possible:
		return false
	var cout: Dictionary = R.RECETTES[quoi]["cout"]
	for k in cout:
		if int(joueur.inventaire.get(k, 0)) < int(cout[k]):
			return false
	return true


func fabriquer(quoi: String) -> void:
	var rec: Dictionary = R.RECETTES[quoi]
	var berges: Array = []
	if quoi == "pont":
		berges = carte.pont_depuis(joueur.position) if carte != null else []
		pont_possible = not berges.is_empty()
		if berges.is_empty():
			ui.message("Un pont se pose au bord d'une rivière, là où elle n'est pas trop large.", Color(0.75, 0.7, 0.66))
			return
	if not peut_fabriquer(quoi):
		var manque := []
		for k in rec["cout"]:
			var m := int(rec["cout"][k]) - int(joueur.inventaire.get(k, 0))
			if m > 0:
				manque.append("%d %s" % [m, R.nom(k, m)])
		ui.message("%s : il te manque %s." % [rec["nom"], ", ".join(PackedStringArray(manque))], Color(0.75, 0.7, 0.66))
		return
	if quoi == "feu" and climat.eau(joueur.position + Vector2(joueur.regard * 34.0, 4.0)) > 0.25:
		ui.message("Le sol est sous l'eau : un feu n'y prendra pas. Gagne une butte.", Color(0.72, 0.82, 0.92))
		return
	for k in rec["cout"]:
		joueur.inventaire[k] = int(joueur.inventaire[k]) - int(rec["cout"][k])
	match quoi:
		"feu":
			var f = Feu.new()
			f.jeu = self
			f.position = monde.repousser(joueur.position + Vector2(joueur.regard * 34.0, 4.0), 12.0)
			monde.add_child(f)
			feux.append(f)
			effets.allumage(f.position)
			sons.jouer("allume", -2.0)
			ui.message("Le feu prend. Nourris-le (F) : chaque bûche le fait durer.", Color(0.95, 0.75, 0.45))
		"torche":
			joueur.torche = R.DUREE_TORCHE
			sons.jouer("allume", -6.0, 1.3)
			ui.message("Une torche : un peu plus d'une minute de lumière.", Color(0.95, 0.75, 0.45))
		"lance":
			joueur.lance = R.USURE_LANCE
			ui.message("Une lance : elle frappe trois fois plus fort.", Color(0.95, 0.75, 0.45))
		"pont":
			poser_pont(berges[0], berges[1], R.PONT_DUREE)
			sons.jouer("bois", -3.0, 0.8)
			ui.message("Un pont de fortune : il ne tiendra pas longtemps. Les bêtes y passent aussi.", Color(0.95, 0.75, 0.45))


# --- les ponts de fortune (scripts/pont.gd) ---

func poser_pont(a: Vector2, b: Vector2, tenue: float):
	var p = Pont.new()
	p.jeu = self
	p.a = a
	p.b = b
	p.tenue = tenue
	# (posé à plat, sous tout ce qui se tient debout)
	monde._calques[2].add_child(p)
	ponts.append(p)
	if carte != null:
		carte.ponts.append([a, b])
	return p


func pont_tombe(p, pourquoi: String) -> void:
	ponts.erase(p)
	if carte != null:
		carte.ponts = carte.ponts.filter(func(e): return e[0] != p.a or e[1] != p.b)
	if joueur != null and joueur.position.distance_to((p.a + p.b) * 0.5) < 900.0:
		ui.message(pourquoi, Color(0.72, 0.82, 0.92))
		sons.jouer("bois", -6.0, 0.6)
	p.queue_free()


# la veilleuse est-elle là où un pont peut se poser ? (regardé trois fois par seconde : c'est ce qui allume sa recette)
func _voir_les_ponts(delta: float) -> void:
	_pont_vu -= delta
	if _pont_vu > 0.0:
		return
	_pont_vu = 0.33
	pont_possible = carte != null and _region >= 0 and bool(carte.regions[_region]["riviere"]) and not carte.pont_depuis(joueur.position).is_empty()


func manger() -> void:
	var inv: Dictionary = joueur.inventaire
	if int(inv["viande_cuite"]) > 0:
		inv["viande_cuite"] = int(inv["viande_cuite"]) - 1
		joueur.faim = minf(100.0, joueur.faim + 35.0)
		joueur.sante = minf(100.0, joueur.sante + 6.0)
		joueur.peur = maxf(0.0, joueur.peur - 8.0)
		ui.message("De la viande cuite. Ça réchauffe.")
	elif int(inv["baies"]) > 0:
		inv["baies"] = int(inv["baies"]) - 1
		joueur.faim = minf(100.0, joueur.faim + 12.0)
		ui.message("Une poignée de baies.")
	elif int(inv["viande"]) > 0:
		inv["viande"] = int(inv["viande"]) - 1
		joueur.faim = minf(100.0, joueur.faim + 18.0)
		joueur.sante = maxf(0.0, joueur.sante - 6.0)
		joueur.peur = minf(100.0, joueur.peur + 6.0)
		ui.message("La viande crue passe mal. Cuis-la (C), près d'un feu.", Color(0.85, 0.6, 0.55))
	else:
		ui.message("Rien à manger.", Color(0.75, 0.7, 0.66))
		return
	sons.jouer("manger", -5.0)


func nourrir_feu() -> void:
	var f = _feu_proche(joueur.position, false)
	if f == null:
		ui.message("Aucun feu à portée.", Color(0.75, 0.7, 0.66))
		return
	if int(joueur.inventaire["bois"]) <= 0:
		ui.message("Il te faut du bois.", Color(0.75, 0.7, 0.66))
		return
	joueur.inventaire["bois"] = int(joueur.inventaire["bois"]) - 1
	f.ajouter(1)
	sons.jouer("allume", -8.0, 1.2)
	# (la gerbe d'une bûche : les bêtes qui craignent le feu reculent un moment)
	for b in get_tree().get_nodes_in_group("betes"):
		b.gerbe(f)


func cuire() -> void:
	var f = _feu_proche(joueur.position, true)
	if f == null:
		ui.message("Il faut un feu allumé, tout près.", Color(0.75, 0.7, 0.66))
		return
	if int(joueur.inventaire["viande"]) <= 0:
		ui.message("Rien à cuire.", Color(0.75, 0.7, 0.66))
		return
	joueur.inventaire["viande"] = int(joueur.inventaire["viande"]) - 1
	joueur.inventaire["viande_cuite"] = int(joueur.inventaire["viande_cuite"]) + 1
	sons.jouer("allume", -9.0, 0.7)
	ui.message("La viande grésille.", Color(0.95, 0.75, 0.45))


# --- le corps : la faim, la peur, la santé ---

func _corps(delta: float) -> void:
	var nuit := 1.0 - lumiere_du_jour()
	var lumiere := eclairage(joueur.position)
	# (la torche brûle : DUREE_TORCHE secondes de lumière, comme le message le promet)
	# (sous la pluie, et trempée, elle brûle plus vite)
	joueur.torche = maxf(0.0, joueur.torche - delta * (1.0 + 0.6 * climat.pluie + (0.7 if joueur.trempe > 60.0 else 0.0)))
	joueur.faim = maxf(0.0, joueur.faim - R.FAIM * delta)
	if joueur.faim <= 0.0:
		joueur.sante -= R.FAMINE * delta
		_conseil("faim", true, "Tu as faim. Mange (E) : des baies, de la viande cuite.")
	var dp := -R.PEUR_JOUR
	if nuit > 0.5:
		dp = R.PEUR_NOIR if lumiere < 0.35 else -R.PEUR_LUMIERE
	if _chasseur_le_plus_proche() < 260.0:
		dp += R.PEUR_PRESENCE
	joueur.peur = clampf(joueur.peur + dp * delta, 0.0, 100.0)
	if joueur.peur >= 100.0:
		joueur.sante -= R.PANIQUE * delta
		_conseil("panique", true, "La peur te serre le cœur. Reviens à la lumière.")
	# (on ne guérit pas de la mort : à zéro, la partie s'arrête à la fin de cette image)
	if joueur.sante > 0.0 and joueur.faim > 60.0 and joueur.peur < 30.0:
		joueur.sante = minf(100.0, joueur.sante + R.SOIN * delta)


func _chasseur_le_plus_proche() -> float:
	var d0 := INF
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role == "chasseur" or (b.role == "rodeur" and b.etat == "attaque"):
			d0 = minf(d0, joueur.position.distance_to(b.position))
	return d0


# --- ce qui arrive aux bêtes ---

func bete_tuee(b) -> void:
	chassees += 1
	# (la veilleuse n'a que ses poings et sa lance : au corps à corps ; dans le lieu, et la parcelle, où vivait la bête)
	Orvane.compter(b.id, str(b.get_meta("biome", biome)), "prelevement", 1.0, "", str(b.get_meta("parcelle", "")), "", "melee")
	prelevements[b.id] = int(prelevements.get(b.id, 0)) + 1
	var viande := clampi(int(round(pow(b.masse, 0.4))), 1, 6)
	joueur.inventaire["viande"] = int(joueur.inventaire["viande"]) + viande
	ui.message("%s : +%d viande" % [b.nom, viande], Color(0.85, 0.72, 0.6))
	ui.ramasse("viande", viande, b.position)
	if _coup_vise.has("bete"):
		_coup_vise["mort"] = [b.position, b.robe, b.largeur]
	else:
		effets.mort(b.position, b.robe, b.largeur)
		effets.arret(0.09)
		effets.secousse(0.25)
	var deja := false
	for t in tuees:
		if t["id"] == b.id:
			deja = true
	if not deja:
		tuees.append({"lignee": b.lignee, "id": b.id, "nom": b.nom, "masse": b.masse, "effectif": 1.0, "poids": 1.0, "sociable": 0.0, "activite": "nocturne"})
	_conseil("echo", true, "Ce qu'on tue ici ne s'oublie pas tout à fait.")


# ce que la mémoire d'Orvane retiendra de cette partie (docs/50), compté pour la lignée, dans le lieu (et la parcelle) où vivait
# la bête, comme une rencontre ou un prélèvement. Le kit ne
# garde ces actions que si le monde lu tient la mémoire (Orvane.memoire_eveillee) ; la fin ne dit que ce qui part.
func _raconter(b, action: String, moyen: String = "") -> void:
	Orvane.compter(b.id, str(b.get_meta("biome", biome)), action, 1.0, "", str(b.get_meta("parcelle", "")), "", moyen)
	if Orvane.memoire_eveillee():
		appris[action] = int(appris.get(action, 0)) + 1


# une bête frappée par la veilleuse s'en va en vie (trop loin, à l'aube, à la fin de la partie) : une blessure, une par bête
func bete_echappee(b) -> void:
	_raconter(b, "blessure", "melee")


# une bête arrêtée sans mal, par un feu de camp (« feu ») ou par la torche (« lumiere ») : une fois par bête et par nuit, vue ou non
func bete_effarouchee(b, moyen: String) -> void:
	_raconter(b, "effarouchement", moyen)


# un assaut sur la veilleuse : une série de morsures, la charge d'un rôdeur (bete.gd, _assaillir)
func bete_attaque(b) -> void:
	_raconter(b, "attaque")


# les bêtes frappées et encore en vie quand le lieu s'en va (la fin, le retour au titre) : elles en réchappent
func _blessees_en_vie() -> void:
	for b in get_tree().get_nodes_in_group("betes"):
		if b.touchee and b.pv > 0.0:
			b.touchee = false
			bete_echappee(b)


# une bête tuée par la foudre ou par l'incendie : ce n'est pas une chasse (rien n'est compté, ni pour la partie ni pour Orvane)
func bete_foudroyee(b) -> void:
	effets.mort(b.position, b.robe, b.largeur)
	if joueur != null and joueur.position.distance_to(b.position) < 420.0:
		ui.message("%s : la foudre l'a prise." % b.nom, Color(0.98, 0.9, 0.6))


func mordre(b) -> void:
	if _mort >= 0.0:
		return
	var d := 4.0 + 7.0 * log(float(b.masse) + 1.0) / log(10.0)
	var en_vie: bool = joueur.sante > 0.0
	joueur.blesser(d)
	if en_vie and joueur.sante <= 0.0:
		# (la morsure qui la fait tomber : sa population apprend qu'une veilleuse est une proie)
		_raconter(b, "joueur_tombe")
	sons.jouer("mord", -1.0, randf_range(0.85, 1.1))
	ui.blessure()
	effets.blessure()
	effets.secousse(clampf(0.35 + d / 30.0, 0.35, 1.0))
	_conseil("morsure-" + str(b.id), true, "%s te mord." % b.nom, Color(0.95, 0.5, 0.42))


# (presage : une bête qui annonce ce qu'elle va faire se fait toujours entendre)
func grognement(b, presage: bool = false) -> void:
	if _grogne > 0.0 and not presage:
		return
	_grogne = 4.0
	var d: float = joueur.position.distance_to(b.position)
	sons.jouer("grogne", -2.0 - d / 60.0, randf_range(0.8, 1.15) * clampf(2.0 / sqrt(maxf(0.2, float(b.masse))), 0.6, 1.5))


func toucher_echo(e) -> void:
	joueur.peur = minf(100.0, joueur.peur + 14.0)
	sons.jouer("murmure", -3.0)
	ui.message("L'écho d'un %s te traverse." % e.nom, Color(0.75, 0.88, 1.0))
	effets.echo(e.position)
	e.dissiper()


# --- le directeur : qui vient, et quand ---

func _directeur_passe(delta: float) -> void:
	_grogne = maxf(0.0, _grogne - delta)
	_directeur -= delta
	if _directeur > 0.0:
		return
	_directeur = 0.5
	_voir()
	var l := lumiere_du_jour()
	var proies := 0
	var chasseurs := 0
	var echos := 0
	for b in get_tree().get_nodes_in_group("betes"):
		var loin: float = joueur.position.distance_to(b.position)
		if b.role != "echo" and loin > 1600.0:
			b.queue_free()
			continue
		match b.role:
			"proie", "rodeur":
				proies += 1
			"chasseur":
				chasseurs += 1
			"echo":
				echos += 1
	if randf() > 0.25:
		return
	if l > 0.5:
		if proies < R.PROIES_JOUR:
			var avec_rodeurs: Array = faune["proies_jour"] + faune["rodeurs"]
			var e = _choisir(avec_rodeurs)
			if e != null:
				_groupe(e, "rodeur" if faune["rodeurs"].has(e) else "proie", 520.0, 900.0)
		return
	# le soir et la nuit
	_vague -= 2.0
	var plafond := mini(R.CHASSEURS_MAX, 2 + nuits + (1 if part_nuit >= 0.45 else 0))
	if chasseurs < plafond and _vague <= 0.0 and l < 0.3:
		_vague = R.VAGUE
		var e = _choisir(faune["chasseurs_nuit"])
		if e != null:
			_groupe(e, "chasseur", 650.0, 950.0)
	if proies < 3:
		var e2 = _choisir(faune["proies_nuit"])
		if e2 != null:
			_groupe(e2, "proie", 520.0, 900.0)
	if joueur.peur > 55.0 and not tuees.is_empty() and echos < R.ECHOS_MAX and randf() < 0.5:
		var t = tuees[randi() % tuees.size()]
		_creer(t, "echo", joueur.position + Vector2.from_angle(randf() * TAU) * randf_range(280.0, 420.0))
		_conseil("echos", true, "Quelque chose de pâle approche. Tu le reconnais.", Color(0.75, 0.88, 1.0))


# une lignée, au hasard, d'autant plus souvent qu'elle est nombreuse ici
func _choisir(liste: Array):
	if liste.is_empty():
		return null
	var tot := 0.0
	for e in liste:
		tot += float(e["poids"])
	var x := randf() * tot
	for e in liste:
		x -= float(e["poids"])
		if x <= 0.0:
			return e
	return liste.back()


# une bête, ou une petite bande si la lignée vit en groupe, hors de vue
func _groupe(e: Dictionary, role: String, dmin: float, dmax: float) -> void:
	var p := Vector2.ZERO
	for essai_ in 8:
		p = joueur.position + Vector2.from_angle(randf() * TAU) * randf_range(dmin, dmax)
		if not ouvert:
			p = Vector2(clampf(p.x, -R.DEMI, R.DEMI), clampf(p.y, -R.DEMI, R.DEMI))
		if eclairage(p) < 0.3 or role != "chasseur":
			break
	var n := 1
	if float(e["sociable"]) > 0.55:
		n = randi_range(2, 4 if role != "chasseur" else 3)
	for i in n:
		_creer(e, role, p + Vector2(randf_range(-40, 40), randf_range(-30, 30)))


func _creer(e: Dictionary, role: String, p: Vector2):
	var b = Bete.new()
	b.preparer(e, role, self, biome)
	b.position = p
	b.maison = p
	# (le monde ouvert : ce qu'on en verra, ce qu'on en chassera est compté dans son biome et sa parcelle d'Orvane)
	b.set_meta("biome", biome)
	if carte != null and _region >= 0 and str(carte.regions[_region]["type"]) == biome:
		b.set_meta("parcelle", str(carte.regions[_region]["id"]))
	b.add_to_group("betes")
	if role == "echo":
		yeux.add_child(b)
	else:
		monde.add_child(b)
	return b


# une bête vue dans la lumière, la première fois : une rencontre, comptée dans le lieu d'Orvane où elle vit
func _voir() -> void:
	for b in get_tree().get_nodes_in_group("betes"):
		if b.vue or b.role == "echo":
			continue
		if joueur.position.distance_to(b.position) < 520.0 and eclairage(b.position) > 0.3:
			b.vue = true
			croisees += 1
			rencontres[b.id] = int(rencontres.get(b.id, 0)) + 1
			Orvane.compter(b.id, str(b.get_meta("biome", biome)), "rencontre", 1.0, "", str(b.get_meta("parcelle", "")))
			if not vues.has(b.id):
				vues[b.id] = b.nom
				var quoi := "un chasseur" if b.role != "proie" else "une bête"
				ui.message("%s : %s de ce lieu." % [b.nom, quoi], Color(0.8, 0.84, 0.78))


func _tombee_de_la_nuit() -> void:
	_vague = 0.0
	ui.carte("Nuit %d" % jour, "Reste dans la lumière." if nuits == 0 else "Tiens jusqu'au matin.")
	effets.tombee()
	if nuits == 0:
		ui.message("La nuit tombe. Reste dans la lumière.", Color(0.95, 0.75, 0.45))
	else:
		ui.message("La nuit tombe.", Color(0.95, 0.75, 0.45))


func _aube() -> void:
	nuits += 1
	ui.carte("L'aube", "Nuit %d tenue." % nuits)
	effets.aube()
	ui.message("Le jour revient. Nuit %d tenue." % nuits, Color(0.98, 0.86, 0.6))
	if nuits > record:
		record = nuits
		_sauver()
	monde.semer_brindilles(30)


# un conseil, une seule fois par partie
func _conseil(cle: String, quand: bool, t: String, c: Color = Color(0.95, 0.75, 0.45)) -> void:
	if quand and not _deja.has(cle):
		_deja[cle] = true
		ui.message(t, c)


# --- la fin ---

# la santé à zéro : elle tombe ; le monde continue un instant sans elle, puis l'écran de fin (_process, DUREE_MORT)
func _tomber() -> void:
	if _mort >= 0.0:
		return
	_mort = 0.0
	joueur.mourir()
	effets.fin()


func _fin() -> void:
	en_partie = false
	sons.taire()
	if nuits > record:
		record = nuits
	_sauver()
	if essai == null:
		PartieGardee.effacer()
	var nr := 0
	var np := 0
	for k in rencontres:
		nr += int(rencontres[k])
	for k in prelevements:
		np += int(prelevements[k])
	_blessees_en_vie()
	var depot := "Le jeu n'a pas encore sa clé : le lot reste ici, rien n'est envoyé."
	if essai != null:
		# (une partie jouée toute seule, l'essai ou la vitrine : rien de vrai, rien ne part)
		depot = "Une partie d'essai : rien n'est envoyé."
		Orvane.oublier()
	elif donnees.memoire_forcee != "":
		# (des bêtes conduites par une mémoire qui n'est pas celle du monde : ce qu'elles ont fait n'apprendrait rien de vrai)
		depot = "Une partie à la mémoire forcée (« %s ») : rien n'est envoyé." % donnees.memoire_forcee
		Orvane.oublier()
	elif Orvane.cle_jeu != "":
		Orvane.clore(compte)
		Orvane.deposer(compte)
		depot = "Le lot part vers le monde d'Orvane : il y pèsera au cycle de cette nuit." if Orvane.monde == "orvane" else \
			"Le lot part dans le bac à sable d'Orvane (monde « %s »)." % Orvane.monde
	else:
		Orvane.oublier()
	var noms := []
	for id in vues:
		var x := "%s ×%d" % [vues[id], int(rencontres.get(id, 0))]
		if prelevements.has(id):
			x += " (%d chassé%s)" % [prelevements[id], "s" if int(prelevements[id]) > 1 else ""]
		noms.append(x)
	var titre := "La nuit t'a prise." if lumiere_du_jour() < 0.5 else "Le lieu t'a prise."
	var ou := "dans ce lieu : %s" % str(biome_info.get("nom", biome))
	var ou_lot := "dans le lieu « %s »" % biome
	if carte != null:
		# (le monde ouvert : ce qu'on en a découvert)
		var biomes_vus := {}
		for k in decouvertes:
			biomes_vus[carte.regions[k]["type"]] = true
		ou = "dans le monde d'Orvane : %d région%s découverte%s, %d biome%s" % [decouvertes.size(), "s" if decouvertes.size() > 1 else "",
			"s" if decouvertes.size() > 1 else "", biomes_vus.size(), "s" if biomes_vus.size() > 1 else ""]
		ou_lot = "dans les lieux où tu es passée"
	var resume := "Tu as tenu %d nuit%s %s. Ton record : %d.\nTu as croisé %d bête%s de %d lignée%s, et tu en as chassé %d." % [
		nuits, "s" if nuits > 1 else "", ou, record, croisees, "s" if croisees > 1 else "",
		vues.size(), "s" if vues.size() > 1 else "", chassees]
	var lot := "Ce que ta partie renvoie au monde d'Orvane : %d rencontre%s, %d prélèvement%s%s, %s. %s\n%s" % [
		nr, "s" if nr > 1 else "", np, "s" if np > 1 else "", _texte_appris(), ou_lot, depot, " · ".join(PackedStringArray(noms))]
	ui.montrer_fin(titre, resume, lot)
	_inscrire_au_tableau()


# ce que la partie apprend aux bêtes, pour le texte du lot (« , 2 bêtes blessées, 3 tenues à distance, 1 assaut ») ; "" si le
# monde ne tient pas la mémoire, ou s'il n'y a rien à dire
func _texte_appris() -> String:
	var mots := {"blessure": ["bête blessée", "bêtes blessées"], "effarouchement": ["tenue à distance", "tenues à distance"],
		"attaque": ["assaut", "assauts"], "joueur_tombe": ["morsure qui t'a prise", "morsures qui t'ont prise"]}
	var t := ""
	for k in mots:
		var n := int(appris.get(k, 0))
		if n > 0:
			t += ", %d %s" % [n, mots[k][0] if n == 1 else mots[k][1]]
	return t


# --- le temps qu'il fait : ce qu'il fait au corps, au feu, aux bêtes (scripts/climat.gd, scripts/incendie.gd) ---

# ce que le sol fait à la marche là où est quelqu'un (la boue, l'eau, la neige) ; le froid engourdit la veilleuse
func allure_sol(p: Vector2, masse: float = 60.0) -> float:
	return climat.allure(p, masse) if climat != null else 1.0


# chaque image : la veilleuse se mouille et sèche, son corps suit la température, elle brûle si elle a pris feu ; le feu de camp
# peine sous la pluie et se noie dans l'eau
func _temps_du_corps(delta: float) -> void:
	var j = joueur
	var p: Vector2 = j.position
	var eau: float = climat.eau(p)
	var abri: float = climat.abri(p)
	# la chaleur des feux : un feu de camp (jusqu'au bord de sa lumière), une torche, un incendie
	var feu := 0.0
	var tout_pres := false
	for f in feux:
		if is_instance_valid(f) and f.allume():
			var d: float = p.distance_to(f.position)
			feu = maxf(feu, clampf(1.0 - d / (f.rayon() * 0.8), 0.0, 1.0))
			if d < 18.0:
				tout_pres = true
	var brasier: float = incendie.chaleur(p)
	# --- trempée ---
	# (ce qui tombe sur elle : presque rien sous un feuillage. Tant qu'il lui pleut dessus, elle ne sèche guère)
	var expose: float = climat.pluie * lerpf(1.0, R.TREMPE_ABRI, abri)
	var mouille: float = R.TREMPE_PLUIE * expose + 2.0 * climat.neige * (1.0 - abri)
	if eau > 0.15:
		mouille += R.TREMPE_EAU * eau
	var seche: float = R.SECHE + R.SECHE_FEU * maxf(feu, brasier)
	if climat.pluie < 0.05 and eau < 0.15:
		seche += 3.0 * lumiere_du_jour() * climat.air + 2.0 * climat.vent
	if j.en_feu > 0.0 and eau <= 0.3:
		seche += 30.0
	seche *= 1.0 - 0.75 * clampf(maxf(expose * 2.0, eau * 3.0), 0.0, 1.0)
	j.trempe = clampf(j.trempe + (mouille - seche) * delta, 0.0, 100.0)
	# --- la température du corps : elle va vers ce que l'air, l'eau, le vent et les feux en font ---
	var cible: float = 50.0 + (climat.air - 0.5) * 100.0
	cible -= 24.0 * j.trempe / 100.0
	cible -= 9.0 * climat.vent * (0.4 + 0.6 * j.trempe / 100.0) * (1.0 - 0.6 * abri)
	if eau > 0.15:
		cible -= 10.0 * eau
	# (à l'ombre d'un arbre, la canicule pèse moins)
	if climat.air > 0.62:
		cible -= 12.0 * abri
	cible += 34.0 * feu + (22.0 if tout_pres else 0.0)
	cible += 6.0 if j.torche > 0.0 else 0.0
	cible += 70.0 * brasier
	if j.en_feu > 0.0:
		cible = 110.0
	var k := 1.0 - exp(-delta * R.TEMPERATURE_ALLURE * (3.0 if (j.en_feu > 0.0 or brasier > 0.5) else 1.0))
	j.temperature = clampf(lerpf(j.temperature, cible, k), 0.0, 100.0)
	if j.temperature < R.FROID:
		j.sante -= R.FROID_DEGATS * (R.FROID - j.temperature) / R.FROID * delta
		_conseil("froid", true, "Tu as froid. Trempée, c'est pire : réchauffe-toi près d'un feu." if j.trempe > 40.0 else "Tu as froid. Réchauffe-toi près d'un feu.", Color(0.72, 0.82, 0.92))
	elif j.temperature > R.CHAUD:
		j.sante -= R.CHAUD_DEGATS * (j.temperature - R.CHAUD) / (100.0 - R.CHAUD) * delta
		_conseil("chaud", j.en_feu <= 0.0, "La chaleur t'accable. Éloigne-toi des flammes." if (brasier > 0.2 or feu > 0.8) else "La chaleur t'accable. Cherche l'ombre d'un arbre, ou l'eau.")
	# --- en feu : au contact des flammes ; la pluie, l'eau l'éteignent ---
	if j.en_feu <= 0.0 and incendie.contact(p) and eau < 0.3:
		enflammer_joueur()
	if j.en_feu > 0.0:
		j.sante -= R.EN_FEU_DEGATS * delta
		j.en_feu -= delta * (1.0 + 1.5 * climat.pluie + (1.0 if j.trempe > 50.0 else 0.0))
		if eau > 0.3:
			j.en_feu = 0.0
			ui.message("L'eau éteint les flammes.", Color(0.72, 0.82, 0.92))
	# --- ce que le temps apprend, une fois ---
	_conseil("pluie", climat.pluie > 0.4 and j.trempe > 25.0 and abri < 0.5, "Il pleut : tu te mouilles. Sous un arbre, on reste au sec. Mais la foudre aime les arbres.", Color(0.72, 0.82, 0.92))
	_conseil("boue", climat.boue > 0.6, "Le sol est détrempé : la boue colle aux pieds.", Color(0.72, 0.82, 0.92))
	_conseil("crue", climat.crue > climat.crue_fond + 0.25, "L'eau monte dans les creux. Un feu s'y noie : gagne les hauteurs.", Color(0.72, 0.82, 0.92))
	_conseil("trempee", j.trempe > 85.0 and climat.pluie < 0.2, "Tu es trempée. Un feu te sèche vite.", Color(0.72, 0.82, 0.92))
	# --- le feu de camp : son bois part plus vite sous la pluie et le vent ; dans l'eau, il se noie ---
	feu_temps = 1.0 + 0.55 * climat.pluie + 0.35 * climat.orage + 0.3 * climat.neige + 0.25 * climat.vent
	for f in feux:
		if is_instance_valid(f) and f.allume() and climat.eau(f.position) > 0.3:
			f.bois = 0.0
			effets.flammes_eteintes(f.position + Vector2(0.0, -8.0), true)
			ui.message("L'eau a noyé le feu.", Color(0.72, 0.82, 0.92))


func enflammer_joueur() -> void:
	if joueur.en_feu > 0.0 or joueur.morte:
		return
	joueur.en_feu = R.EN_FEU
	joueur.peur = minf(100.0, joueur.peur + 12.0)
	effets.blessure()
	ui.message("Tu brûles ! La pluie ou l'eau éteignent les flammes.", Color(0.98, 0.6, 0.4))


# le temps change : on le dit
func _temps_change(nom: String) -> void:
	if not en_partie or essai != null:
		return
	var dit := {"pluie": "La pluie arrive.", "orage": "L'orage gronde. La foudre cherche ce qui dépasse.", "neige": "Il se met à neiger.",
		"brouillard": "Le brouillard tombe.", "canicule": "La chaleur écrase le lieu.", "clair": "Le ciel se dégage.", "couvert": ""}
	var t := str(dit.get(nom, ""))
	if t != "":
		ui.message(t, Color(0.72, 0.82, 0.92))


# la foudre est tombée en p (scripts/climat.gd) : elle blesse autour d'elle (plus loin, les pieds dans l'eau), fait peur, met le
# feu à ce qu'elle frappe ; les bêtes proches s'enfuient
func foudre_tombee(p: Vector2, sur) -> void:
	if not en_partie or joueur == null:
		return
	var d: float = joueur.position.distance_to(p)
	effets.secousse(clampf(1.2 - d / 500.0, 0.0, 1.0))
	var dans_l_eau: bool = climat.eau(joueur.position) > 0.2 and climat.eau(p) > 0.05
	var rayon: float = R.FOUDRE_RAYON * (1.9 if dans_l_eau else 1.0)
	if d < rayon and _mort < 0.0:
		var n: float = R.FOUDRE_DEGATS * (1.0 - d / rayon) * (1.25 if joueur.trempe > 60.0 else 1.0)
		joueur.blesser(n)
		ui.blessure()
		ui.message("La foudre !" if not dans_l_eau else "La foudre court dans l'eau !", Color(0.98, 0.9, 0.6))
		if d < R.FOUDRE_RAYON * 0.45:
			enflammer_joueur()
	if d < 420.0:
		joueur.peur = minf(100.0, joueur.peur + R.FOUDRE_PEUR * (1.0 - d / 420.0))
	# ce qu'elle frappe prend feu ; sur la terre nue, ce qui pousse tout près
	if sur != null:
		incendie.enflammer(sur)
	elif monde != null:
		for o in monde.autour(p, 36.0):
			incendie.enflammer(o)
	# les bêtes : celles qu'elle touche sont blessées (ce n'est pas une chasse), les autres s'enfuient
	for b in get_tree().get_nodes_in_group("betes"):
		var db: float = b.position.distance_to(p)
		if db < R.FOUDRE_RAYON and b.role != "echo":
			b.foudroyer(R.FOUDRE_DEGATS * 1.5 * (1.0 - db / R.FOUDRE_RAYON), p)
		elif db < 360.0 and b.role != "echo":
			b.effrayer(p, 3.0)


func _incendie_pris(o) -> void:
	if not en_partie or essai != null:
		return
	if joueur != null and joueur.position.distance_to(o.position) < 600.0:
		_conseil("incendie", true, "La foudre a mis le feu. Les bêtes n'entrent pas dans sa lumière. Mais il brûle, et il court sous le vent.", Color(0.98, 0.75, 0.45))


# --- le monde ouvert : d'une région à l'autre (scripts/carte.gd) ---

# chaque image : la région où elle est ; le biome d'à côté se lit quand on approche de sa frontière
func _regions() -> void:
	var pr: Array = carte.proches(joueur.position)
	var i: int = pr[0]
	if i != _region:
		var avant := _region
		_region = i
		decouvertes[i] = true
		if avant < 0 or str(carte.regions[avant]["type"]) != str(carte.regions[i]["type"]):
			_entrer_dans(carte.regions[i], avant >= 0)
	if _lecture != "":
		return
	var ici := str(carte.regions[i]["type"])
	var a_cote := str(carte.regions[int(pr[1])]["type"])
	if not _faunes.has(ici) and not _illisibles.has(ici):
		_lire_biome(ici)
	elif not carte.regions[int(pr[1])]["eau"] and not _faunes.has(a_cote) and not _illisibles.has(a_cote) and float(pr[3]) - float(pr[2]) < 7000.0:
		_lire_biome(a_cote)


# on entre dans un autre biome : ses bêtes, son climat, son sol sous les pieds ; son nom, en carte de titre
func _entrer_dans(reg: Dictionary, le_dire: bool) -> void:
	var type := str(reg["type"])
	biome = type
	biome_info = donnees.biome(type)
	var axes: Dictionary = monde.lieu_de(type)["axes"]
	if _faunes.has(type):
		faune = _faunes[type]
	meteo = _meteos.get(type, {})
	climat.changer_de_lieu(axes, meteo)
	sons.changer_de_lieu(axes)
	if le_dire:
		ui.carte(str(reg["nom"]), "")


# un biome du monde, lu en approchant : ce qui y vit (dessiné d'avance, quelques bêtes par image), ses plantes, son temps
func _lire_biome(type: String) -> void:
	_lecture = type
	var partie := graine
	var inst: Dictionary = await donnees.charger_lieu(type)
	if not en_partie or graine != partie:
		_lecture = ""
		return
	var f: Dictionary = donnees.faune(inst, type) if not inst.is_empty() else {}
	if f.is_empty() or (f["proies_jour"].is_empty() and f["proies_nuit"].is_empty() and f["chasseurs_nuit"].is_empty()):
		_illisibles[type] = true
	else:
		_faunes[type] = f
		_meteos[type] = Orvane.meteo(type)
		monde.flore_arrivee(type)
		await _dessiner_la_faune(f, 0.25)
		if en_partie and graine == partie and biome == type:
			faune = f
			meteo = _meteos[type]
	_lecture = ""


# --- la partie gardée, le tableau des scores ---

# la partie en cours, sur l'appareil (scripts/partie_gardee.gd) ; l'essai et la vitrine ne gardent rien
func _garder() -> void:
	_garde_ms = Time.get_ticks_msec()
	if essai != null or not en_partie or _mort >= 0.0 or joueur == null or monde == null:
		return
	PartieGardee.ecrire(self)


# l'application passe derrière une autre, la fenêtre perd la main, on la ferme : la partie se met en pause, et se garde
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_WM_CLOSE_REQUEST]:
		if en_partie and _mort < 0.0 and essai == null and ui != null:
			if not en_pause:
				en_pause = true
				ui.montrer_pause(true)
			_garder()


# une partie commencée connecté a son numéro au tableau des scores (la base vérifiera, à la fin, le temps qu'elle a duré)
func _ouvrir_au_tableau() -> void:
	if essai != null or session == null or not session.connecte():
		return
	var id: String = await session.commencer_partie(biome, str(biome_info.get("nom", biome)))
	if en_partie and partie_id == "" and id != "":
		partie_id = id
		_garder()


func _inscrire_au_tableau() -> void:
	if essai != null or session == null:
		return
	if partie_id == "":
		if session.connecte():
			ui.fin_tableau("Cette partie n'était pas inscrite au tableau des scores (pas de réseau quand elle a commencé).")
		else:
			ui.fin_tableau("Connecte-toi à l'écran-titre avant d'entrer dans la nuit : tes nuits iront au tableau des scores.")
		return
	var id := partie_id
	partie_id = ""
	ui.fin_tableau("Au tableau des scores…")
	var r: Dictionary = await session.finir_partie(id, nuits, croisees, chassees)
	if r.get("ok", false):
		var m := int(r["meilleur"])
		ui.fin_tableau("Au tableau des scores : rang %d (ta meilleure partie : %d nuit%s)." % [int(r["rang"]), m, "s" if m > 1 else ""])
	elif r.get("attend", false):
		ui.fin_tableau("Pas de réseau : tes nuits iront au tableau des scores dès qu'il reviendra.")
	else:
		ui.fin_tableau("Le tableau des scores refuse cette partie : %s." % str(r.get("erreur", "")))


func _charger() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		var s = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
		if typeof(s) == TYPE_DICTIONARY:
			record = int(s.get("record", 0))
			compte = str(s.get("compte", ""))
			ips = bool(s.get("ips", false))
	if compte == "":
		# un compte opaque : Orvane ne peut pas remonter au joueur
		compte = "h:" + ("lisiere-%d-%d" % [randi(), Time.get_unix_time_from_system()]).sha256_text().substr(0, 24)
		_sauver()


func _sauver() -> void:
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"record": record, "compte": compte, "ips": ips}))
