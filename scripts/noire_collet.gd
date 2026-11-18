extends RefCounted
# Lisière — la fin de la Noire : le collet de filin (scripts/noire_collet.gd)
# La Noire vient d'acte en acte, et les coups ne la tuent pas. Il y a pourtant de quoi lui faire quitter le lieu :
#  - le grand collet (scripts/atelier.gd, « collet » : du filin, des pieux, des pierres de lest) se tend de jour, sur sa piste,
#    près de sa tanière ou à la lisière du camp ; « Agir » auprès de lui, avec de la viande crue, l'amorce ;
#  - l'odeur : posé ou amorcé à mains nues, il sent la main. Elle vient, le flaire, renâcle et s'en détourne (et le jeu le
#    dit). Avec l'odeur des aromates sur soi (scripts/botanique.gd, parfum), il ne sent rien. Une longue pluie le lave ;
#  - la prise : la nuit, un collet amorcé assez près d'où elle passe l'attire : elle a faim, l'appât passe avant le reste
#    (attire() le dit à qui veut le savoir). Elle y vient la tête basse, le flaire, y met la patte : le nœud se serre. Elle
#    n'entre pas dans la lumière d'un feu : un collet éclairé ne prend rien, il faut sortir se battre ;
#  - tenue (R.NOIRE_COLLET_TENUE secondes) : elle se ramasse, se jette au bout du filin, qui l'arrête d'un à-coup (il grince,
#    les pieux bougent) et la laisse sonnée un instant. Elle mord qui entre dans sa portée ; au bout du filin tendu, on la
#    touche sans qu'elle atteigne (regles.gd dit la bande) ;
#  - blessée ou non : assez de coups pendant qu'elle est tenue (R.NOIRE_COLLET_BLESSE), et elle s'arrache, garde une
#    cicatrice (une par nuit au plus) et se retire pour la nuit. Sinon elle arrache les pieux, furieuse : elle s'aplatit
#    (son présage reste), et charge. Dans les deux cas le collet est perdu : on reprend ses pieux et ses pierres, elle a
#    emporté le nœud ;
#  - les cicatrices : chacune se voit sur elle (scripts/noire_cicatrices.gd) et ralentit sa charge ; à la deuxième elle boite ;
#  - le départ : à la troisième, elle ne rentre pas. Elle pousse un dernier appel, qui s'éloigne ; à l'aube sa piste part du
#    collet et sort du lieu, sa couche est vide (les nœuds qu'elle a rongés y sont restés), les nuits retrouvent leurs
#    bruits, et une page le dit : « Elle est partie. » La partie continue sans elle.
# Ici : tout cela. scripts/noire.gd l'appelle en quelques endroits (maj, tombee, aube, frappee, la partie gardée) ;
# scripts/atelier.gd pour poser, amorcer, replier ; scripts/collet_dessin.gd le dessine (par scripts/campement.gd).

const R := preload("res://scripts/regles.gd")
const TEINTE := Color(0.93, 0.47, 0.42)        # (celle de la Noire : scripts/noire.gd)
const CLAIR := Color(0.86, 0.8, 0.66)          # (celle de l'atelier)
const GRIS := Color(0.75, 0.7, 0.66)
const AUBE := Color(0.98, 0.86, 0.6)
# le pieu d'ancrage, depuis le milieu du nœud (là où le dessin le met : scripts/collet_dessin.gd)
const PIEU := Vector2(40.0, -5.0)
# sa patte de devant, depuis le milieu de son corps, en largeurs de bête (scripts/noire_corps.gd, PATTE_AV)
const PATTE := 0.15
const NEZ := 0.46                              # son nez, tête basse
const CE_QU_IL_REND := {"bois": 4, "pierre": 4}   # rompu : ses pieux, ses pierres

var jeu
var noire                        # elle (scripts/noire.gd)
var vise = null                  # le collet où elle va, celui qui la tient (une chose posée : scripts/campement.gd)
var tenue := 0.0                 # depuis quand le nœud la tient
var coups := 0.0                 # ce qu'elle a pris, tenue
var prise_cette_nuit := false    # elle s'y est prise cette nuit : échaudée, elle ne touche plus à un appât avant la suivante
var poses_n := 0                 # les collets tendus, depuis le début (le compte de la dernière page)
var prises_n := 0                # les fois où elle s'y est prise
var morsures_n := 0              # ses morsures
var emportes := 0                # les nœuds qu'elle a ramenés à sa tanière, à la patte
var jour_du_depart := 0          # le jour dont la nuit l'a vue partir (0 : elle est là)
var depart_de := Vector2.ZERO    # d'où part sa dernière piste : le collet
var sortie := Vector2.ZERO       # par où elle a quitté le lieu
var aube_dite := false           # l'aube de son départ est passée : sa piste, sa couche vide
var page_dite := false           # la page « Elle est partie. » a été lue
var depuis_a_coup := INF         # secondes depuis le dernier à-coup du filin (le dessin fait bouger les pieux)
var _phase := ""                 # tenue : « saisie », « ramasse », « jette », « sonnee »
var _pt := 0.0
var _dir := Vector2.RIGHT        # où elle se jette
var _elans := 0
var _cote := 1.0                 # de quel côté elle aborde le collet
var _flaire := false             # elle l'a flairé
var _renifle := 0
var _boude := 0.0                # avant de regarder de nouveau vers un collet qu'elle n'a pas pu atteindre
var _lumiere_dite := -1          # la nuit où l'on a dit que le feu éclaire le collet
var _appel := false              # son dernier appel est poussé
var _page_dans := -1.0           # avant la page (-1 : rien)
var _a_revoir := false           # une partie vient d'être reprise : les collets posés sont à revoir, une fois
var _r := RandomNumberGenerator.new()


func commencer() -> void:
	vise = null
	tenue = 0.0
	coups = 0.0
	prise_cette_nuit = false
	poses_n = 0
	prises_n = 0
	morsures_n = 0
	emportes = 0
	jour_du_depart = 0
	depart_de = Vector2.ZERO
	sortie = Vector2.ZERO
	aube_dite = false
	page_dite = false
	depuis_a_coup = INF
	_phase = ""
	_flaire = false
	_boude = 0.0
	_lumiere_dite = -1
	_appel = false
	_page_dans = -1.0
	_a_revoir = false
	_r.seed = int(jeu.graine) ^ 0xc011e7


# --- ce que l'atelier appelle (scripts/atelier.gd) ---

# ce qui empêche de le tendre, là, maintenant ("" : rien)
func empeche_poser() -> String:
	if jeu.jour_du_ciel() <= 0.0:
		return "Un collet se tend de jour : la nuit, tu ne verrais pas ton nœud."
	return ""


# elle vient de le tendre : il garde l'odeur de la main qui l'a posé, sauf si elle sent les aromates
func pose(s) -> void:
	poses_n += 1
	var couvre := _sent_les_aromates()
	s.etat["amorce"] = false
	s.etat["odeur"] = not couvre
	s.etat["phase"] = ""
	if noire.partie:
		jeu.ui.message("Le collet est tendu. Il n'y a plus rien ici qu'il puisse prendre.", CLAIR)
		return
	if couvre:
		jeu.ui.message("Le collet est tendu. L'odeur des aromates couvre celle de tes mains. Il lui faut un appât : de la viande crue.", CLAIR)
	elif noire.su.has("odeur"):
		jeu.ui.message("Le collet est tendu, mais il sent ta main : elle le sentira. La fumée des aromates couvre ton odeur.", TEINTE)
	else:
		jeu.ui.message("Le collet est tendu : le nœud ouvert, les pieux enfoncés. Il lui faut un appât : de la viande crue.", CLAIR)
	if _eclaire(s):
		jeu.ui.message("Trop près de ton feu : elle n'entre pas dans sa lumière. Tends-le plus loin.", TEINTE)


# « Agir » auprès du collet : de la viande crue l'amorce ; rompu, elle en reprend ce qui reste. Auprès de la couche vide de
# la Noire : elle la fouille
func agir(s) -> void:
	if str(s.genre) == "couche":
		_fouiller_la_couche(s)
		return
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	match str(s.etat.get("phase", "")):
		"serre":
			jeu.ui.message("Le filin est tendu à rompre. C'est elle qu'il faut frapper.", TEINTE)
			return
		"rompu":
			replier(s)
			return
	if bool(s.etat.get("amorce", false)):
		jeu.ui.message("Le collet est amorcé. Écarte-toi, et attends la nuit.", CLAIR)
		return
	if int(inv.get("viande", 0)) <= 0:
		jeu.ui.message("Il faut de la viande crue : c'est le sang qu'elle sent." if int(inv.get("viande_cuite", 0)) > 0 else "Il faut de la viande crue pour l'amorcer.", GRIS)
		return
	inv["viande"] = int(inv["viande"]) - 1
	s.etat["amorce"] = true
	var couvre := _sent_les_aromates()
	if not couvre:
		s.etat["odeur"] = true
	j.geste_atelier("fouiller")
	jeu.sons.jouer("herbe", -9.0, 0.7)
	jeu.sons.jouer("manger", -14.0, 0.6)
	if noire.partie:
		jeu.ui.message("La viande au milieu du nœud. Personne ne viendra la prendre.", CLAIR)
	elif bool(s.etat.get("odeur", false)) and noire.su.has("odeur"):
		jeu.ui.message("Le collet est amorcé, mais il sent ta main : elle s'en détournera." if not couvre else
			"Le collet est amorcé. Tu l'avais tendu à mains nues : il sent encore ta main.", TEINTE)
	else:
		jeu.ui.message("Le collet est amorcé : la viande au milieu du nœud. Écarte-toi, et attends la nuit.", CLAIR)


# elle le replie : entier, il revient dans son sac, avec sa viande ; rompu, il ne rend que ses pieux et ses pierres
func replier(s) -> bool:
	var A = jeu.atelier
	var phase := str(s.etat.get("phase", ""))
	if phase == "serre":
		jeu.ui.message("Le filin est tendu à rompre. C'est elle qu'il faut frapper.", TEINTE)
		return false
	if phase == "rompu":
		var pris := []
		for k in CE_QU_IL_REND:
			pris.append("+%d %s" % [int(A.ranger(k, int(CE_QU_IL_REND[k]))), R.nom(k, 2) if R.NOMS.has(k) else k])
		A.poses.erase(s)
		s.queue_free()
		jeu.joueur.geste_atelier("fouiller")
		jeu.sons.jouer("bois", -8.0, 0.9)
		jeu.sons.jouer("pierre", -12.0, 0.8)
		jeu.ui.message("Tu reprends les pieux et les pierres (%s). Le nœud, elle l'a emporté." % ", ".join(PackedStringArray(pris)), CLAIR)
		return true
	if bool(s.etat.get("amorce", false)):
		A.ranger("viande", 1)
	A.objets["collet"] = int(A.possede("collet")) + 1
	A.poses.erase(s)
	jeu.sons.atelier("corde", -2.0, 0.8, s.position)
	s.queue_free()
	jeu.joueur.geste_atelier("monter")
	return true


# ce que la page du sac dit du collet posé juste là (scripts/interface_atelier.gd)
func note_du_sac(s) -> String:
	match str(s.etat.get("phase", "")):
		"serre":
			return "Elle y est prise."
		"rompu":
			return "Rompu : tu en reprends les pieux et les pierres. Le nœud, elle l'a emporté."
	var t := "Amorcé." if bool(s.etat.get("amorce", false)) else "Sans appât : « Agir » auprès de lui, avec de la viande crue."
	if noire.su.has("odeur"):
		t += " Il sent ta main : replie-le, et retends-le avec l'odeur des aromates." if bool(s.etat.get("odeur", false)) else " Il ne sent rien."
	return t


# --- ce que les autres en lisent ---

# un collet amorcé l'attire-t-il, là, maintenant ? (elle y va, le flaire, ou y est prise : il passe avant tout le reste)
func attire() -> bool:
	if noire.partie:
		return false
	if noire.etat in ["appat", "flaire", "prise"]:
		return true
	return _appat_pour(noire.ou) != null


# où est sa patte prise, depuis le milieu du nœud (Vector2.INF : ce collet ne la tient pas) : le dessin y tend le filin
func patte(s) -> Vector2:
	if vise != s or noire.etat != "prise" or noire.corps == null or not is_instance_valid(noire.corps):
		return Vector2.INF
	return noire.corps.pied_pris() - s.position


# le pieu d'ancrage d'un collet, dans le lieu
static func ancre(s) -> Vector2:
	return s.position + PIEU


# --- chaque image (scripts/noire.gd, maj) : vrai si c'est le collet qui la mène ---

func maj(delta: float, j) -> bool:
	depuis_a_coup += delta
	_boude = maxf(0.0, _boude - delta)
	if _a_revoir:
		_revoir()
	_laver(delta)
	_la_page(delta)
	if noire.partie and noire.etat != "part":
		# (elle n'est plus du lieu : plus rien d'elle, ni son silence ni son regard)
		noire.silence = move_toward(noire.silence, 0.0, delta * 0.1)
		noire.regard = move_toward(noire.regard, 0.0, delta * 1.5)
		return true
	match noire.etat:
		"appat":
			_aller(delta, j)
		"flaire":
			_flairer(j)
		"prise":
			_tenir(delta, j)
		"furie":
			_fureur()
		"part":
			_partir(j)
		"vient", "guette", "tourne":
			var s = _appat_pour(noire.ou)
			if s == null:
				_dire_la_lumiere()
				return false
			vise = s
			_flaire = false
			_cote = 1.0 if s.position.x >= noire.ou.x else -1.0
			noire._changer("appat")
		_:
			return false
	return true


# le collet amorcé le plus proche qu'elle sente de là (null : aucun) : tendu, pas éventé cette nuit, hors de la lumière
func _appat_pour(ou: Vector2):
	if noire.partie or prise_cette_nuit or noire.acte < 2 or noire._retiree or noire._colere > 0.0 or _boude > 0.0 or jeu.jour_du_ciel() > 0.0:
		return null
	var mieux = null
	var d0 := R.NOIRE_COLLET_FLAIR
	for s in jeu.atelier.poses:
		if not _amorce(s) or int(s.etat.get("evente", -1)) == int(jeu.nuits) or _eclaire(s):
			continue
		var d: float = s.position.distance_to(ou)
		if d < d0:
			d0 = d
			mieux = s
	return mieux


static func _amorce(s) -> bool:
	return is_instance_valid(s) and str(s.genre) == "collet" and str(s.etat.get("phase", "")) == "" and bool(s.etat.get("amorce", false))


# ce collet est-il trop près d'un feu ? Elle ne tient pas dans sa lumière (bete.gd l'en repousse) : il faut qu'elle puisse
# poser son corps devant le nœud ; et que la veilleuse ne puisse pas la frapper sans sortir de la lumière qui la protège (la
# lance porte à PORTEE_COUP + 0,3 × sa largeur ; tant que la veilleuse est à l'abri, elle tire de l'autre côté du pieu)
func _eclaire(s) -> bool:
	var lance := R.PORTEE_COUP + 0.3 * R.NOIRE_LARGEUR - 0.25 * R.NOIRE_COLLET_LONGE + 12.0
	for f in jeu.feux_et_foyers():
		if not f.allume():
			continue
		var r: float = float(f.rayon())
		if f.position.distance_to(s.position) < r * 0.98 + PATTE * R.NOIRE_LARGEUR + 8.0 or f.position.distance_to(ancre(s)) < r * 0.85 + lance:
			return true
	return false


# elle sent la viande, mais le feu éclaire le collet : dit une fois par nuit, quand elle est là
func _dire_la_lumiere() -> void:
	if _lumiere_dite == int(jeu.nuits) or noire.corps == null or noire.acte < 2 or prise_cette_nuit or noire._retiree:
		return
	for s in jeu.atelier.poses:
		if _amorce(s) and _eclaire(s) and s.position.distance_to(noire.ou) < R.NOIRE_COLLET_FLAIR:
			_lumiere_dite = int(jeu.nuits)
			jeu.ui.message("Elle a senti la viande, mais le collet est trop près de ton feu. Elle n'entrera pas dans sa lumière.", TEINTE)
			return


func _sent_les_aromates() -> bool:
	return jeu.get("botanique") != null and jeu.botanique.impregnee()


# une longue pluie lave d'un collet l'odeur d'une main
func _laver(delta: float) -> void:
	var C = jeu.climat
	if C == null or float(C.pluie) < 0.3:
		return
	for s in jeu.atelier.poses:
		if is_instance_valid(s) and str(s.genre) == "collet" and bool(s.etat.get("odeur", false)) and str(s.etat.get("phase", "")) == "":
			s.etat["lave"] = float(s.etat.get("lave", 0.0)) + delta * float(C.pluie)
			if float(s.etat["lave"]) >= R.NOIRE_COLLET_PLUIE:
				s.etat["odeur"] = false
				s.etat.erase("lave")
				if noire.su.has("odeur"):
					jeu.ui.message("La pluie a lavé le collet : il ne sent plus ta main.", CLAIR)


# --- elle y va ---

# vers l'appât : sans corps tant qu'elle est loin ; puis au pas, la tête basse, jusqu'à avoir le nez dessus (elle le flaire),
# puis la patte dedans
func _aller(delta: float, j) -> void:
	var s = vise
	if not _amorce(s) or _eclaire(s) or jeu.jour_du_ciel() > 0.0:
		_laisser(4.0)
		return
	var u := R.NOIRE_LARGEUR
	if noire.corps == null:
		noire.ou = noire.ou.move_toward(s.position, R.NOIRE_VOYAGE * delta)
		# (elle prend corps hors de vue : en vue du collet, ou à l'approche de la veilleuse)
		if noire.ou.distance_to(j.position) < 1080.0:
			noire._apparaitre(noire._entree(j.position, (noire.ou - j.position).angle()))
		elif noire.ou.distance_to(s.position) < 460.0:
			noire._apparaitre(noire.ou)
		if noire.corps != null:
			_cote = 1.0 if s.position.x >= noire.ou.x else -1.0
		return
	var c = noire.corps
	if noire._arrivee < 0.0:
		noire._arrivee = noire._nuit_t
	# (là où poser son corps : le nez sur l'appât d'abord, puis la patte de devant dans le nœud)
	var cible: Vector2 = s.position - Vector2(_cote * (PATTE if _flaire else NEZ) * u, 0.0)
	var d: float = c.position.distance_to(cible)
	c.ordre = "va"
	c.ordre_allure = 0.36 if d > 220.0 else 0.2
	c.ordre_but = noire._contourner(noire.ou, cible) if d > 60.0 else cible
	c.flaire = 1.0 if c.position.distance_to(s.position) < 330.0 else 0.0
	if d < 9.0:
		c.regard = _cote
		if not _flaire:
			_renifle = 0
			noire._changer("flaire")
		else:
			_serrer(s)
		return
	if noire._coincee(delta):
		_laisser(8.0)


# elle renonce à ce collet (il n'est plus amorcé, le feu l'éclaire, quelque chose lui barre le chemin) : elle reprend sa nuit
func _laisser(pour: float) -> void:
	vise = null
	_boude = pour
	if noire.corps != null and is_instance_valid(noire.corps):
		noire.corps.flaire = 0.0
	noire._pose = _r.randf_range(4.0, 7.0)
	noire._changer("tourne" if noire.corps != null else "vient")


# le nez dessus : elle flaire, deux fois. Rien que la viande : elle y met la patte. Une main : elle renâcle et s'en détourne
func _flairer(_j) -> void:
	var s = vise
	var c = noire.corps
	if c == null or not _amorce(s):
		_laisser(4.0)
		return
	c.ordre = ""
	c.regard = _cote
	c.flaire = 1.0
	var sent: bool = bool(s.etat.get("odeur", false))
	var t: float = noire._t
	# (ses reniflements : on les entend, de près)
	if _renifle < 2 and t > 0.35 + 0.8 * _renifle:
		_renifle += 1
		jeu.sons.atelier("noire_flaire", 0.0, _r.randf_range(0.92, 1.06), c.position)
	if not sent:
		if t > 1.3:
			_flaire = true
			noire._changer("appat")
		return
	if t < R.NOIRE_COLLET_FLAIRE:
		return
	# elle renâcle : la tête qui se relève d'un coup, un pas en arrière ; ce collet-là, elle n'y reviendra pas de la nuit
	s.etat["evente"] = int(jeu.nuits)
	c.flaire = 0.0
	c.sursauter()
	jeu.sons.atelier("noire_renacle", 2.0, 1.0, c.position)
	if not noire._apprendre("odeur") and c.position.distance_to(jeu.joueur.position) < 900.0:
		jeu.ui.message("Elle renâcle, et s'en détourne : le collet sent ta main.", TEINTE)
	vise = null
	noire._sens = -noire._sens
	noire._pose = _r.randf_range(5.0, 8.0)
	noire._changer("tourne")


# --- la prise ---

# le nœud se serre sur sa patte
func _serrer(s) -> void:
	var c = noire.corps
	var j = jeu.joueur
	prise_cette_nuit = true
	prises_n += 1
	tenue = 0.0
	coups = 0.0
	_phase = "saisie"
	_pt = 0.0
	_elans = 0
	depuis_a_coup = 0.0
	s.etat["phase"] = "serre"
	s.etat["amorce"] = false
	s.etat["vers"] = [snappedf(-_cote, 0.01), 0.0]
	c.flaire = 0.0
	c.tenue_a = ancre(s)
	c.tenue_long = R.NOIRE_COLLET_LONGE
	noire._changer("prise")
	c.sursauter()
	var d: float = c.position.distance_to(j.position)
	# le nœud qui claque, et son cri : rien de son appel. On l'entend de loin
	jeu.sons.atelier("collet_claque", 2.0, 1.0, s.position)
	jeu.sons.evenement("noire_cri", lerpf(0.0, -16.0, clampf(d / 3000.0, 0.0, 1.0)), _r.randf_range(0.96, 1.04), jeu.sons.pan_de(c.position), jeu.sons.B_PEUR)
	if jeu.effets != null:
		jeu.effets.pas(s.position, 1.0)
		if d < 500.0:
			jeu.effets.secousse(0.4 * (1.0 - d / 500.0))
	if not noire._apprendre("collet"):
		jeu.ui.message("Le nœud s'est serré : elle est prise." if d < 900.0 else "Loin, un cri : le collet l'a prise.", TEINTE)


# tenue : elle se ramasse, se jette au bout du filin, qui l'arrête d'un à-coup et la laisse sonnée ; et recommence
func _tenir(delta: float, j) -> void:
	var s = vise
	var c = noire.corps
	if c == null or s == null or not is_instance_valid(s):
		# (on ne la voyait plus : elle s'est arrachée seule)
		if s != null and is_instance_valid(s):
			_rompre(s)
		vise = null
		noire._changer("vient")
		return
	tenue += delta
	_pt += delta
	if tenue >= R.NOIRE_COLLET_TENUE or jeu.jour_du_ciel() > 0.5:
		_se_liberer()
		return
	var pieu := ancre(s)
	c.tenue_a = pieu
	match _phase:
		"saisie":
			c.ordre = ""
			if _pt > 0.6:
				_elan(j, pieu)
		"ramasse":
			# (son présage, à chaque élan : aplatie, tournée vers où elle va se jeter, elle recule vers le pieu pour le prendre)
			c.ordre = ""
			c.aplatie = 1.0
			if absf(_dir.x) > 0.15:
				c.regard = signf(_dir.x)
			c.position = c.position.move_toward(pieu + _dir * R.NOIRE_COLLET_LONGE * 0.25, 120.0 * delta)
			if _pt >= R.NOIRE_COLLET_ELAN:
				_phase = "jette"
				_pt = 0.0
				c.aplatie = 0.0
		"jette":
			c.ordre = "charge"
			c.ordre_allure = 1.0
			c.ordre_but = pieu + _dir * (R.NOIRE_COLLET_LONGE + 90.0)
			if (c.position - pieu).dot(_dir) >= R.NOIRE_COLLET_LONGE * 0.96 or _pt > 1.3:
				_a_coup(s, c)
		"sonnee":
			c.ordre = ""
			if _pt >= R.NOIRE_COLLET_SONNEE:
				_elan(j, pieu)


# un élan de plus : sur la veilleuse si elle est à sa portée ou presque ; sinon pour s'arracher, d'un côté puis de l'autre.
# Un feu vif la tient toujours : tant que la veilleuse est dans sa lumière, elle ne se jette pas vers elle, elle tire à
# l'opposé du feu (il faut sortir pour l'atteindre)
func _elan(j, pieu: Vector2) -> void:
	var c = noire.corps
	_elans += 1
	var vers_elle: Vector2 = j.position - pieu
	var feu = jeu.feu_qui_protege(j.position)
	if feu == null and vers_elle.length() < R.NOIRE_COLLET_LONGE + R.NOIRE_COLLET_MORD + 75.0 and vers_elle.length() > 1.0:
		_dir = vers_elle.normalized()
		jeu.grognement(c, true)
	elif feu != null:
		_dir = Vector2.from_angle((pieu - feu.position).angle() + (1.0 if _elans % 2 == 0 else -1.0) * _r.randf_range(0.2, 0.9))
	else:
		# (elle tire d'un côté, puis de l'autre : jamais deux fois le même)
		var ici: Vector2 = c.position - pieu
		var a := (ici.angle() if ici.length() > 4.0 else _r.randf() * TAU) + (1.0 if _elans % 2 == 0 else -1.0) * _r.randf_range(1.5, 2.6)
		_dir = Vector2.from_angle(a)
	_phase = "ramasse"
	_pt = 0.0


# le filin l'arrête net, au bout de son élan : il grince, les pieux bougent, la terre vole sous sa patte ; elle en reste
# sonnée un instant, et ne mord pas
func _a_coup(s, c) -> void:
	_phase = "sonnee"
	_pt = 0.0
	depuis_a_coup = 0.0
	c.ordre = ""
	c.sursauter()
	s.etat["vers"] = [snappedf(_dir.x, 0.01), snappedf(_dir.y, 0.01)]
	var pied: Vector2 = c.pied_pris()
	var d: float = c.position.distance_to(jeu.joueur.position)
	jeu.sons.atelier("collet_coup", 0.0, _r.randf_range(0.94, 1.06), s.position)
	if jeu.effets != null:
		jeu.effets.pas(pied, 1.0)
		if d < 420.0:
			jeu.effets.secousse(0.22 * (1.0 - d / 420.0))
	# (sa patte laboure le sol là où le filin l'arrête : on y lit jusqu'où elle va)
	if jeu.traces != null:
		jeu.traces.poser(pied, _dir.angle(), R.NOIRE_LARGEUR * 0.052, 420.0, 2, "la-noire", 1.0)


# un coup de la veilleuse (scripts/noire.gd, frappee) : vrai si le collet en répond. Tenue, c'est le seul moment où les
# coups comptent vraiment : assez de coups, et elle en garde une cicatrice
func frappee(n: float) -> bool:
	if noire.etat == "part":
		return true
	if noire.etat in ["appat", "flaire"]:
		# (frappée devant l'appât : elle n'y pense plus)
		_laisser(20.0)
		return false
	if noire.etat != "prise":
		return false
	coups += n
	var c = noire.corps
	if c != null and is_instance_valid(c):
		c.sursauter()
	if coups >= R.NOIRE_COLLET_BLESSE:
		_blesser()
	return true


# elle vient de mordre (scripts/noire.gd, a_mordu) : le compte de la dernière page
func mordue() -> void:
	morsures_n += 1


# assez de coups : elle s'arrache, et en garde une cicatrice. À la troisième, elle quitte le lieu
func _blesser() -> void:
	var s = vise
	var c = noire.corps
	var j = jeu.joueur
	noire.cicatrices = mini(noire.cicatrices + 1, R.NOIRE_CICATRICES)
	noire._retiree = true
	noire._colere = 0.0
	_rompre(s)
	var d: float = c.position.distance_to(j.position)
	jeu.sons.evenement("noire_cri", lerpf(1.0, -15.0, clampf(d / 3000.0, 0.0, 1.0)), _r.randf_range(1.12, 1.2), jeu.sons.pan_de(c.position), jeu.sons.B_PEUR)
	if jeu.effets != null:
		jeu.effets.arret(0.11)
		jeu.effets.secousse(0.5)
	if noire.cicatrices >= R.NOIRE_CICATRICES:
		_quitter_le_lieu(s, c, j)
		return
	if not noire._apprendre("cicatrice"):
		jeu.ui.message("Elle s'arrache et s'en va dans le noir, sur trois pattes. Une cicatrice de plus.", TEINTE)
	emportes += 1
	noire._changer("rentre")


# le temps est passé sans assez de coups : les pieux cèdent. Furieuse, elle s'aplatit (le présage), puis elle charge
func _se_liberer() -> void:
	var s = vise
	var c = noire.corps
	_rompre(s)
	emportes += 1
	if jeu.jour_du_ciel() > 0.5:
		noire._changer("rentre")
		return
	noire._changer("furie")
	jeu.grognement(c, true)
	jeu.ui.message("Les pieux ont cédé : elle est libre. Elle s'aplatit. Elle va charger.", TEINTE)


# libre, furieuse : elle s'aplatit et gronde (le présage, comme toujours), puis charge ; un feu vif la tient encore
func _fureur() -> void:
	var c = noire.corps
	if c == null:
		noire._changer("vient")
		return
	c.ordre = "guette"
	c.aplatie = 1.0
	if noire._t >= R.NOIRE_PRESAGE:
		noire._changer("charge")


# le collet est perdu : ses pieux arrachés, ses pierres roulées, le nœud parti avec elle
func _rompre(s) -> void:
	var c = noire.corps
	if c != null and is_instance_valid(c):
		c.tenue_a = Vector2.INF
		c.aplatie = 0.0
		c.flaire = 0.0
		c.sursauter()
		if s != null and is_instance_valid(s):
			var vers: Vector2 = (c.position - ancre(s)).normalized()
			s.etat["vers"] = [snappedf(vers.x, 0.01), snappedf(vers.y, 0.01)]
	if s != null and is_instance_valid(s):
		s.etat["phase"] = "rompu"
		s.etat["amorce"] = false
		depart_de = ancre(s)
		jeu.sons.atelier("collet_arrache", 2.0, 1.0, s.position)
		if jeu.effets != null:
			jeu.effets.pas(ancre(s), 1.0)
	elif c != null and is_instance_valid(c):
		depart_de = c.position
	vise = null
	tenue = 0.0
	_phase = ""


# --- le départ ---

# la troisième cicatrice : elle ne rentre pas. Elle s'en va, à l'opposé de la veilleuse, pas vers sa tanière, hors du lieu
func _quitter_le_lieu(_s, c, j) -> void:
	noire.partie = true
	jour_du_depart = int(jeu.jour)
	aube_dite = false
	page_dite = false
	_appel = false
	var cap: float = (c.position - j.position).angle()
	var vers_taniere: float = (noire.taniere - c.position).angle()
	if absf(angle_difference(cap, vers_taniere)) < 0.9:
		cap = vers_taniere + (1.3 if angle_difference(vers_taniere, cap) >= 0.0 else -1.3)
	sortie = _hors_du_lieu(depart_de, cap)
	noire._changer("part")
	jeu.ui.message("Elle s'arrache une troisième fois. Elle ne rentre pas : elle s'en va.", TEINTE)


# par où elle sort, de « de », cap sur « cap » : dans un lieu fermé, au-delà de son bord ; dans le monde ouvert, au loin
func _hors_du_lieu(de: Vector2, cap: float) -> Vector2:
	var dir := Vector2.from_angle(cap)
	if jeu.ouvert:
		return de + dir * 5200.0
	# (jusqu'au bord du carré, et un peu plus loin : sous les arbres qui ferment le lieu)
	var tx := INF if absf(dir.x) < 0.001 else ((R.DEMI if dir.x > 0.0 else -R.DEMI) - de.x) / dir.x
	var ty := INF if absf(dir.y) < 0.001 else ((R.DEMI if dir.y > 0.0 else -R.DEMI) - de.y) / dir.y
	return de + dir * (maxf(0.0, minf(tx, ty)) + 260.0)


# elle s'en va : au trot, en boitant, sans se retourner. Un dernier appel, qui n'est pas le même, et qui s'éloigne
func _partir(j) -> void:
	var c = noire.corps
	if c != null:
		c.ordre = "va"
		c.ordre_allure = 0.66
		c.ordre_but = noire._contourner(noire.ou, sortie)
		if not _appel and noire._t > 4.0:
			_dernier_appel()
		if c.position.distance_to(j.position) > 1150.0 or noire._t > 30.0 or c.position.distance_to(sortie) < 80.0:
			noire._disparaitre()
	if noire.corps == null:
		if not _appel:
			_dernier_appel()
		noire.ou = sortie
		noire.etat = "dort"


func _dernier_appel() -> void:
	_appel = true
	var d: float = noire.ou.distance_to(jeu.joueur.position)
	jeu.sons.evenement("dernier_appel", lerpf(-2.0, -10.0, clampf(d / 3000.0, 0.0, 1.0)), 1.0, jeu.sons.pan_de(sortie), jeu.sons.B_PEUR)
	jeu.ui.message("Un appel, long, qui retombe. Ce n'est plus le même : il s'éloigne.", TEINTE)


# la nuit tombe (scripts/noire.gd, tombee) : vrai si elle est partie — la nuit se passe sans elle, avec ses bruits
func tombee() -> bool:
	prise_cette_nuit = false
	vise = null
	tenue = 0.0
	_phase = ""
	_boude = 0.0
	if not noire.partie:
		return false
	if jeu.traces != null:
		jeu.traces.effacer(2)
	if not jeu._deja.has("nuit-sans-elle"):
		jeu._deja["nuit-sans-elle"] = true
		jeu.ui.message("La nuit a retrouvé ses bruits : les grillons, une chouette, ce qui chasse ici depuis toujours. Elle ne viendra pas.", AUBE)
	return true


# l'aube (scripts/noire.gd, aube) : vrai si elle est partie. La première fois : sa piste part du collet et sort du lieu, sa
# couche est vide ; puis la page. Les aubes suivantes : plus rien d'elle
func aube() -> bool:
	if not noire.partie:
		if noire.etat == "prise":
			_se_liberer()
		elif noire.etat in ["appat", "flaire"]:
			vise = null
		return false
	if aube_dite:
		return true
	aube_dite = true
	if not _appel:
		_appel = true
	noire._disparaitre()
	noire.ou = sortie
	noire.etat = "dort"
	_piste_du_depart()
	_poser_la_couche()
	noire._apprendre("depart")
	_page_dans = R.NOIRE_DEPART_PAGE
	return true


# sa dernière piste, du collet à la sortie du lieu : elle ne flâne plus, elle va droit, à grandes foulées ; une patte marque
# moins que les autres (elle boite). Elle ne se perd pas avant d'être loin
func _piste_du_depart() -> void:
	if jeu.traces == null or depart_de == Vector2.ZERO or sortie == Vector2.ZERO:
		return
	jeu.traces.effacer(2)
	var long := depart_de.distance_to(sortie)
	if long < 80.0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = int(jeu.graine) ^ 0x9a27
	var dir := (sortie - depart_de) / long
	var orth := dir.orthogonal()
	var pas := R.NOIRE_LARGEUR * 0.26
	var phase := r.randf() * TAU
	var trou := r.randf_range(1500.0, 1900.0)
	var cote := 1.0
	var avant := depart_de
	for i in int(long / pas):
		var s := i * pas
		var bord := smoothstep(0.0, 500.0, s)
		var p := depart_de + dir * s + orth * 46.0 * sin(s / 640.0 + phase) * bord
		trou -= pas
		if trou < 0.0 and long - s > 300.0:
			if trou < -r.randf_range(140.0, 260.0):
				trou = r.randf_range(700.0, 1100.0)
			avant = p
			continue
		cote = -cote
		var sens := (p - avant).normalized() if p.distance_to(avant) > 1.0 else dir
		# (une foulée sur quatre : la patte prise, qu'elle pose à peine)
		jeu.traces.poser(p + sens.orthogonal() * cote * R.NOIRE_LARGEUR * 0.07, sens.angle(), R.NOIRE_LARGEUR * 0.052, 420.0, 2, "la-noire", 0.5 if i % 4 == 1 else 1.0)
		avant = p


# sa couche, là où elle dormait : vide. Les nœuds qu'elle a ramenés à la patte y sont restés, rongés
func _poser_la_couche() -> void:
	for s in jeu.atelier.poses:
		if is_instance_valid(s) and str(s.genre) == "couche":
			return
	jeu.atelier._creer("couche", noire.taniere, {"noeuds": clampi(emportes, 0, 4), "fouillee": false})


func _fouiller_la_couche(s) -> void:
	var j = jeu.joueur
	if bool(s.etat.get("fouillee", false)):
		jeu.ui.message("Sa couche est vide. L'herbe s'y redresse déjà.", GRIS)
		return
	s.etat["fouillee"] = true
	j.geste_atelier("fouiller")
	jeu.sons.atelier("fouille", -4.0, 0.8)
	var n := int(s.etat.get("noeuds", 0))
	if n > 0 and int(jeu.atelier.ranger("filin", 1)) > 0:
		jeu.ui.message("Sa couche : l'herbe couchée, froide. Du poil noir, des os, et tes nœuds de filin, tranchés d'un coup de dent. Tu en tires de quoi refaire un filin.", AUBE)
	else:
		jeu.ui.message("Sa couche : l'herbe couchée, froide. Du poil noir, des os rongés. Rien d'autre.", AUBE)


# --- la page « Elle est partie. » ---

func _la_page(delta: float) -> void:
	if _page_dans < 0.0:
		return
	_page_dans -= delta
	if _page_dans <= 0.0:
		_page_dans = -1.0
		if not page_dite and jeu.has_method("montrer_depart"):
			jeu.montrer_depart()


# ce que la page dit : son titre, son sous-titre, quatre nombres et leurs mots, et ce qu'on écrit dessous
func page() -> Dictionary:
	var nuits := int(jeu.nuits)
	var cap := _cap_dit(sortie - depart_de)
	var lieu := "Le monde d'Orvane" if jeu.ouvert else str(jeu.biome_info.get("nom", jeu.biome))
	return {
		"titre": "Elle est partie.",
		"lieu": "%s, en %s — la nuit %d" % [lieu, str(jeu.saison), maxi(1, jour_du_depart)],
		"nombres": [[nuits, "nuit tenue" if nuits <= 1 else "nuits tenues"], [int(noire.cicatrices), "cicatrices"],
			[poses_n, "collet tendu" if poses_n <= 1 else "collets tendus"], [morsures_n, "morsure" if morsures_n <= 1 else "morsures"]],
		"dit": "Sa piste part du collet et sort du lieu%s. Elle ne s'est pas retournée. Sa couche est vide, et froide ; les nuits ont retrouvé leurs bruits." % (", vers %s" % cap if cap != "" else "")
			+ (" Dans le monde ouvert, elle est allée au loin, sans retour." if jeu.ouvert else ""),
		"reste": "Ce n'est pas la fin : le lieu est à toi. La faim, le froid et ce qui chasse ici depuis toujours, eux, restent.",
	}


# ce que le carnet écrit d'elle, à la fin : sa dernière page (scripts/interface_carnet.gd)
func derniere_page() -> String:
	if not noire.partie:
		return ""
	var cap := _cap_dit(sortie - depart_de)
	return "Partie la nuit %d, à sa troisième cicatrice%s. Elle ne reviendra pas." % [maxi(1, jour_du_depart), (", vers %s" % cap) if cap != "" else ""]


static func _cap_dit(v: Vector2) -> String:
	if v.length() < 1.0:
		return ""
	return ["l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest", "le nord", "le nord-est"][int(round(fposmod(v.angle(), TAU) / (TAU / 8.0))) % 8]


# la page est lue : « rester veiller » (ou « revenir au titre »)
func page_lue() -> void:
	page_dite = true
	_page_dans = -1.0


# --- la partie gardée ---

func photo() -> Dictionary:
	return {"poses": poses_n, "prises": prises_n, "morsures": morsures_n, "emportes": emportes, "prise_nuit": prise_cette_nuit, "jour_depart": jour_du_depart,
		"de": [snappedf(depart_de.x, 0.1), snappedf(depart_de.y, 0.1)], "sortie": [snappedf(sortie.x, 0.1), snappedf(sortie.y, 0.1)],
		"aube": aube_dite, "page": page_dite}


# une partie reprise : ce qu'on en comptait ; un collet qui la tenait quand on a quitté est rompu (elle s'est arrachée seule) ;
# le jour de son départ, sa piste se refait ; la page, si elle n'était pas lue, revient
func reprendre(d: Dictionary) -> void:
	poses_n = int(d.get("poses", 0))
	prises_n = int(d.get("prises", 0))
	morsures_n = int(d.get("morsures", 0))
	emportes = int(d.get("emportes", 0))
	prise_cette_nuit = bool(d.get("prise_nuit", false))
	jour_du_depart = int(d.get("jour_depart", 0))
	var a: Array = d.get("de", [])
	var b: Array = d.get("sortie", [])
	depart_de = Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO
	sortie = Vector2(float(b[0]), float(b[1])) if b.size() >= 2 else Vector2.ZERO
	aube_dite = bool(d.get("aube", false))
	page_dite = bool(d.get("page", false))
	_appel = noire.partie
	# (les choses posées reviennent après elle : scripts/principal.gd ; on les revoit à la première image)
	_a_revoir = true


func _revoir() -> void:
	_a_revoir = false
	for s in jeu.atelier.poses:
		if is_instance_valid(s) and str(s.genre) == "collet" and str(s.etat.get("phase", "")) == "serre":
			s.etat["phase"] = "rompu"
			prise_cette_nuit = true
			emportes += 1
	if noire.partie and aube_dite:
		if int(jeu.jour) == jour_du_depart + 1 and jeu.jour_du_ciel() > 0.0:
			_piste_du_depart()
		if not page_dite:
			_page_dans = 2.5
