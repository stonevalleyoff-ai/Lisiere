extends RefCounted
# Lisière — la Noire, acte 5 : la faim (scripts/noire_faim.gd)
# À partir de la dixième nuit (regles.gd : NOIRE_ACTES, NOIRE_FAIM), la Noire a faim, et la nuit pèse plus encore :
#  - elle rôde dès le crépuscule : elle n'attend plus la nuit noire. Son appel s'entend quand le jour baisse (NOIRE_DEPART est
#    négatif à cet acte : elle part avant la nuit) ; quand la nuit commence, elle est à la lisière ;
#  - elle saccage le camp : tenue par un feu, au lieu de seulement tourner, elle s'en prend à ce qui est posé hors de la
#    lumière d'un feu vif (CHOSES : la tente, le hamac, le récupérateur, les filets et leur prise, l'épouvantail, la mangeoire,
#    un carré de jardin où quelque chose pousse). Une chose à la fois, deux par nuit au plus ;
#  - ce qu'elle a saccagé reste là, en épave (scripts/campement_epave.gd la dessine) : on la répare sur place, pour la moitié
#    de son prix (« Agir »), ou on la replie, pour la moitié de ses matières (scripts/atelier.gd) ;
#  - elle prend elle-même les bêtes attachées dans le noir, à leur piquet ou au bout de la main : même le filin cède sous sa
#    gueule (scripts/elevage.gd). Elle la mange sur place, la tête basse.
# Ce qui reste juste : elle s'annonce (elle quitte le cercle, va sur la chose la tête basse, la flaire et gronde quatre
# secondes avant d'y mettre la dent ; l'épouvantail tremble à son approche) ; ce qui est dans la lumière d'un feu vif est gardé
# (jeu.feu_qui_protege : la même loi que pour la veilleuse) ; une bûche jetée dans le feu, un galet, lui font lâcher ce
# qu'elle flaire ; la veilleuse qui sort de la lumière la détourne sur elle. Elle ne touche jamais à un collet.
# Ici : ce qu'elle choisit et ce qu'elle en fait. scripts/noire.gd garde son scénario et l'appelle (tombee, aube, maj,
# _assieger, _changer, gerbe, frappee, la partie gardée) ; il lui laisse trois états : « flaire » (elle va sur la chose, puis
# la flaire et gronde), « saccage » (elle la secoue et la met en pièces), « devore » (elle mange la bête qu'elle a prise).

const R := preload("res://scripts/regles.gd")

# ce qu'elle met en pièces : le genre de la chose posée → [comment le jeu la nomme, ce qu'il dit quand c'est fait, sa matière
# (ce qu'on entend, ce qui vole : scripts/sons_faim.gd, scripts/effets.gd)]. Ce qui n'y est pas, elle n'y touche pas : l'établi
# (des rondins et des pierres), le piquet nu, le cerf-volant, les vestiges et les coffres ; et jamais un collet.
const CHOSES := {
	"tente": ["ta tente", "Ta tente est en pièces.", "toile"],
	"hamac": ["ton hamac", "Ton hamac est en pièces.", "toile"],
	"recuperateur": ["ton récupérateur d'eau", "Ton récupérateur d'eau est en pièces.", "toile"],
	"filet": ["ton filet", "Ton filet est en pièces.", "corde"],
	"filet_filin": ["ton grand filet", "Ton grand filet est en pièces.", "corde"],
	"epouvantail": ["ton épouvantail", "Ton épouvantail est en pièces.", "paille"],
	"mangeoire": ["ta mangeoire", "Ta mangeoire est en pièces.", "bois"],
	"carre": ["ton jardin", "Ton jardin est piétiné : ce qui y poussait est perdu.", "terre"],
}
const ETATS := ["flaire", "saccage", "devore"]
const MUSEAU := 0.33              # de combien son museau, la tête basse, porte en avant de ses pieds (en largeurs de bête)
const GRIS := Color(0.75, 0.7, 0.66)
# le niveau de chaque son de la faim, tout près (en dB ; la distance l'affaiblit : sons.gd, au_loin)
const NIVEAUX := {"dechire": -6.0, "brise": -6.0, "cede": -7.0, "pierre": -11.0, "pas_lourd": -5.0, "herbe": -9.0, "manger": -8.0}

# la Noire (scripts/noire.gd), et le jeu : c'est elle qui tient la faim, pas l'inverse (pas de boucle de références)
var _n: WeakRef
var N:
	get:
		return _n.get_ref() if _n != null else null
var jeu:
	get:
		return N.jeu
var cible = null                  # ce qu'elle a choisi : une chose posée (scripts/campement.gd), ou une bête attachée (scripts/bete.gd)
var prises := 0                   # ce qu'elle a mis en pièces, cette nuit
var betes := 0                    # les bêtes qu'elle a prises, cette nuit
var soir := false                 # elle est partie au crépuscule, cette nuit
var _tenue := 0.0                 # depuis combien de temps un feu la tient (depuis la dernière chose, la dernière bûche)
var _attente := R.NOIRE_FAIM_ATTENTE
var _vu := 0.0                    # avant de regarder de nouveau le camp
var _gardees := 0                 # ce qu'elle aurait pris, et que la lumière garde
var _place := Vector2.ZERO        # où elle se tient pour y mettre le museau
var _cote := 1.0                  # de quel côté de la chose elle se tient (1 : à sa droite)
var _sur_place := false           # elle y est : le temps du flair court
var _hors := {}                   # ce qu'elle n'a pas pu atteindre, cette nuit (une rivière, une paroi en travers)
var _feu = null                   # le feu qui la tenait quand elle a regardé le camp
var _cadence := 0.0
var _coups := 0
var _a_retracer := false          # une partie reprise : ses empreintes sont à remettre autour des épaves de la dernière nuit


# --- ce que noire.gd appelle ---

func lier(noire) -> void:
	_n = weakref(noire)


# une partie commence
func commencer() -> void:
	tombee()


# la nuit tombe (ou elle part au crépuscule) : les comptes de la nuit
func tombee() -> void:
	_lacher()
	prises = 0
	betes = 0
	soir = false
	_tenue = 0.0
	_attente = R.NOIRE_FAIM_ATTENTE
	_vu = 0.0
	_hors.clear()
	_feu = null


# le jour revient
func aube() -> void:
	soir = false


# combien de secondes avant la nuit (INF : il fait nuit)
func avant_la_nuit() -> float:
	var t := fmod(float(jeu.horloge), R.DUREE)
	var soir_h := R.DUREE * (1.0 - float(jeu.part_nuit))
	return soir_h - t if t < soir_h else INF


# à chaque image (noire.gd, maj) : le jour qui baisse, et, une partie reprise, ses empreintes à remettre
func veiller(nuit: bool) -> void:
	if _a_retracer:
		_a_retracer = false
		_retracer(nuit)
	if not nuit and N.etat == "dort":
		crepuscule()


# le jour baisse (de jour, tant qu'elle dort) : à l'acte de la faim, elle n'attend pas la nuit. Elle appelle et quitte sa
# tanière assez tôt pour être à la lisière quand la nuit commence
func crepuscule() -> void:
	if soir or bool(N.partie) or N.etat != "dort" or float(N._colere) > 0.0:
		return
	var part := float(R.NOIRE_DEPART[N.acte_de(int(jeu.nuits))])
	if part >= 0.0:
		return
	var reste := avant_la_nuit()
	if reste == INF or reste > -part * R.DUREE * float(jeu.part_nuit):
		return
	# (les comptes de la nuit, dès maintenant : son acte, la piste de la veille qui s'efface ; puis la nuit qui tombe ne la
	# renverra pas à sa tanière : noire.gd, tombee)
	N.tombee()
	soir = true
	N._appeler()
	N._apprendre("crepuscule")
	N._changer("vient")


# elle change d'état (noire.gd, _changer) : sortie des siens, elle lâche ce qu'elle tenait, sa tête se relève
func change(e: String) -> void:
	if not ETATS.has(e):
		_lacher()


# une bûche dans le feu, un coup (noire.gd, gerbe, frappee) : vrai si elle lâche ce qu'elle flairait. Une fois la dent dedans,
# il est trop tard
func derangee() -> bool:
	if N.etat != "flaire" or cible == null:
		return false
	if _sur_place and jeu.joueur != null:
		jeu.ui.message("Elle lâche %s." % _nom(cible), N.TEINTE)
	_renoncer()
	return true


# tenue par un feu (noire.gd, _assieger) : elle finit par se tourner vers le camp. Vrai : elle a choisi, et quitte le cercle
func tenter(delta: float, feu) -> bool:
	if int(N.acte) < R.NOIRE_FAIM or N.corps == null or bool(N._retiree) or feu == null:
		return false
	_tenue += delta
	_vu -= delta
	if _vu > 0.0:
		return false
	_vu = 0.5
	_feu = feu
	# (une bête attachée dans le noir passe avant toute chose : la viande d'abord)
	if _tenue >= R.NOIRE_FAIM_BETE:
		var b = _bete_a_prendre(feu)
		if b != null:
			_partir_vers(b)
			return true
	if prises >= R.NOIRE_SACCAGES:
		if _tenue > 6.0:
			N._apprendre("assez")
		return false
	if _tenue < _attente:
		return false
	var s = _chose_a_saccager(feu)
	if s == null:
		# (tout ce qu'elle aurait pris est dans la lumière : elle regarde, et n'y va pas)
		if _gardees > 0 and _tenue > _attente + 6.0:
			N._apprendre("garde")
		return false
	_partir_vers(s)
	return true


# ses trois états, à chaque image (noire.gd, maj)
func maj(delta: float, j) -> void:
	if N.corps == null:
		_lacher()
		N._changer("vient")
		return
	match str(N.etat):
		"flaire":
			_flairer(delta, j)
		"saccage":
			_saccager(delta, j)
		"devore":
			_devorer(delta, j)


# une bête attachée dans le noir (scripts/elevage.gd) : vient-elle la prendre elle-même ? Sinon, la règle d'avant vaut : on
# l'entend crier, une fois, dans le noir
func vient_prendre(b) -> bool:
	if int(N.acte) < R.NOIRE_FAIM or bool(N._retiree) or N.etat == "dort" or N.etat == "rentre" or float(N._colere) > 0.0:
		return false
	if b == cible:
		return true
	if not b.tenue():
		return false
	# (il faut qu'un feu la tienne, et que la bête soit à sa portée : sinon c'est la veilleuse qu'elle chasse)
	var feu = jeu.feu_qui_protege(jeu.joueur.position)
	return feu != null and b.position.distance_to(feu.position) <= R.NOIRE_FAIM_PORTEE


# --- ce qu'elle choisit ---

# cette chose posée peut-elle être mise en pièces ? (jamais un collet ; un carré nu n'a rien à perdre)
static func saccageable(s) -> bool:
	if s == null or not is_instance_valid(s) or not CHOSES.has(str(s.genre)) or est_epave(s):
		return false
	return str(s.genre) != "carre" or str(s.etat.get("culture", "")) != ""


# ce point est-il gardé ? Dans la lumière d'un feu vif : la loi qui protège la veilleuse garde aussi ce qu'elle a posé
func gardee(p: Vector2) -> bool:
	return jeu.feu_qui_protege(p) != null


func _chose_a_saccager(feu):
	var mieux = null
	var note0 := -INF
	_gardees = 0
	for s in jeu.atelier.poses:
		if not saccageable(s) or _hors.has(s) or s.position.distance_to(feu.position) > R.NOIRE_FAIM_PORTEE:
			continue
		if gardee(s.position):
			_gardees += 1
			continue
		if _ou_se_tenir(s.position).is_empty():
			continue
		# (ce qui sent la viande d'abord : un filet et sa prise ; puis le plus proche d'elle)
		var note: float = -s.position.distance_to(N.ou) + (4000.0 if s.etat.has("prise") else 0.0)
		if note > note0:
			note0 = note
			mieux = s
	return mieux


func _bete_a_prendre(feu):
	var mieux = null
	var d0 := INF
	for b in jeu.elevage.betes:
		if not _bete_prenable(b) or _hors.has(b) or b.position.distance_to(feu.position) > R.NOIRE_FAIM_PORTEE:
			continue
		var d: float = b.position.distance_to(N.ou)
		if d < d0 and not _ou_se_tenir(b.position).is_empty():
			d0 = d
			mieux = b
	return mieux


# une bête à elle, tenue (au piquet, ou sa longe dans la main de la veilleuse), hors de la lumière d'un feu
func _bete_prenable(b) -> bool:
	return b != null and is_instance_valid(b) and str(b.role) == "compagne" and float(b.pv) > 0.0 and b.tenue() and not gardee(b.position)


# où elle se tient pour mettre le museau sur ce point : à côté de lui (on la voit de profil), du côté opposé au feu qui la
# tient (la chose entre elle et lui : sa tête tournée vers la lumière, qui l'accroche, tout son corps dans le noir) ; si la
# chose est au-dessus ou au-dessous du feu, du côté où elle est déjà ; et de l'autre côté si la lumière d'un feu tombe là.
# [la place, le côté] ; vide : nulle part (la lumière des deux côtés)
func _ou_se_tenir(p: Vector2) -> Array:
	var cote := 1.0 if N.ou.x >= p.x else -1.0
	if _feu != null and is_instance_valid(_feu) and absf(p.x - _feu.position.x) > 40.0:
		cote = signf(p.x - _feu.position.x)
	for k in 2:
		var q := p + Vector2(cote * R.NOIRE_LARGEUR * MUSEAU, 5.0)
		var libre := true
		for f in jeu.feux_et_foyers():
			if f.allume() and q.distance_to(f.position) < float(f.rayon()) * 1.02:
				libre = false
				break
		if libre and N._degage(N.ou, q):
			return [q, cote]
		cote = -cote
	return []


func _partir_vers(c) -> void:
	var ou := _ou_se_tenir(c.position)
	cible = c
	_place = ou[0]
	_cote = ou[1]
	_sur_place = false
	_cadence = 0.0
	_coups = 0
	N._changer("flaire")


# --- ses états ---

# ce qu'elle a choisi tient-il toujours ? (la chose est encore là, hors de la lumière ; la bête encore attachée dans le noir)
func _tient() -> bool:
	if cible == null or not is_instance_valid(cible):
		return false
	if _est_une_bete(cible):
		return _bete_prenable(cible)
	return saccageable(cible) and not gardee(cible.position)


static func _est_une_bete(c) -> bool:
	return c.get("role") != null


func _nom(c) -> String:
	if _est_une_bete(c):
		return str(c.nom)
	return str(CHOSES[str(c.genre)][0])


# elle va sur la chose, la tête déjà basse ; arrivée, elle la flaire et gronde (l'annonce), puis y met la dent
func _flairer(delta: float, j) -> void:
	var c = N.corps
	# (la veilleuse sort de la lumière : elle vaut mieux qu'une tente. noire.gd reprend : la torche, le présage, la charge)
	if jeu.feu_qui_protege(j.position) == null:
		N._changer("guette")
		return
	if not _tient():
		if cible != null and is_instance_valid(cible) and _sur_place and gardee(cible.position):
			jeu.ui.message("La lumière a repris %s. Elle s'en écarte." % _nom(cible), N.TEINTE)
		_renoncer()
		return
	if not _sur_place:
		# (une bête tire sur sa longe, d'un côté, de l'autre : elle la suit)
		if _est_une_bete(cible):
			var ou := _ou_se_tenir(cible.position)
			if not ou.is_empty():
				_place = ou[0]
				_cote = ou[1]
		c.ordre = "va"
		c.ordre_allure = 0.5
		c.ordre_but = N._contourner(N.ou, _place)
		c.fouille = 0.4
		var la: bool = N.ou.distance_to(_place) < 16.0
		if not la and (N._coincee(delta) or float(N._t) > 18.0):
			# (elle n'y arrive pas : une rivière, une paroi. Tout près, cela ira ; sinon elle y renonce pour la nuit)
			la = N.ou.distance_to(_place) < 70.0
			if not la:
				_hors[cible] = true
				_renoncer()
				return
		if la:
			_sur_place = true
			N._t = 0.0
			_cadence = 0.0
			jeu.grognement(c, true)
			if _est_une_bete(cible):
				jeu.ui.message("Elle est sur %s, dans le noir. Elle gronde." % _nom(cible), N.TEINTE)
			else:
				jeu.ui.message("Elle flaire %s. Elle gronde." % _nom(cible), N.TEINTE)
				N._apprendre("faim")
		return
	c.ordre = "fouille"
	c.ordre_but = cible.position
	c.fouille = 1.0
	# (elle gronde encore, à mi-temps ; la bête, elle, tire à l'opposé au bout de sa longe)
	_cadence -= delta
	if _cadence <= 0.0:
		_cadence = 1.3
		if _est_une_bete(cible):
			cible.effrayer(N.ou, 1.4)
		elif float(N._t) > 1.0:
			jeu.grognement(c, true)
	if float(N._t) >= R.NOIRE_FLAIRE:
		if _est_une_bete(cible):
			_prendre_la_bete()
		else:
			_cadence = 0.0
			_coups = 0
			N._changer("saccage")


# elle la tient dans sa gueule : elle la secoue, tire, arrache. La chose tressaute (scripts/campement_epave.gd, « mordu »), ses
# lambeaux volent ; au bout, il n'en reste qu'une épave
func _saccager(delta: float, j) -> void:
	var c = N.corps
	if cible == null or not is_instance_valid(cible) or not saccageable(cible):
		_renoncer()
		return
	if jeu.feu_qui_protege(j.position) == null:
		N._changer("guette")
		return
	c.ordre = "fouille"
	c.ordre_but = cible.position
	c.fouille = 1.0
	c.secoue = 1.0
	var u := clampf(float(N._t) / R.NOIRE_SACCAGE, 0.0, 1.0)
	cible.etat["mordu"] = maxf(u, 0.01)
	cible.etat["cote"] = _cote
	_cadence -= delta
	if _cadence <= 0.0:
		_cadence = 0.85
		_bruit(cible, _coups)
		_coups += 1
	if float(N._t) >= R.NOIRE_SACCAGE:
		var s = cible
		mettre_en_pieces(s, _cote)
		prises += 1
		_finir(R.NOIRE_FAIM_REPIT)


# elle mange ce qu'elle a pris, la tête basse, à grands coups ; puis elle revient tourner
func _devorer(delta: float, j) -> void:
	var c = N.corps
	if jeu.feu_qui_protege(j.position) == null:
		N._changer("guette")
		return
	c.ordre = "fouille"
	c.ordre_but = _place - Vector2(_cote * R.NOIRE_LARGEUR * MUSEAU, 5.0)
	c.fouille = 1.0
	_cadence -= delta
	c.secoue = 1.0 if _cadence > 1.0 else 0.0
	if _cadence <= 0.0:
		_cadence = 1.5
		_son("manger", N.ou, 0.0, 0.62)
	if float(N._t) >= R.NOIRE_DEVORE:
		_finir(R.NOIRE_FAIM_ATTENTE)


# elle y renonce (dérangée, ou la chose n'est plus à prendre) : elle retourne au cercle, et attendra de nouveau
func _renoncer() -> void:
	_lacher()
	_tenue = 0.0
	_attente = R.NOIRE_FAIM_ATTENTE
	if ETATS.has(str(N.etat)):
		N._pose = 4.0
		N._changer("tourne")


func _finir(repit: float) -> void:
	_lacher()
	_tenue = 0.0
	_attente = repit
	N._pose = 5.0
	N._changer("tourne")


# elle lâche : sa tête se relève, ce qu'elle secouait retombe
func _lacher() -> void:
	if cible != null and is_instance_valid(cible) and not _est_une_bete(cible):
		cible.etat.erase("mordu")
	cible = null
	_sur_place = false
	if N != null and N.corps != null and is_instance_valid(N.corps):
		N.corps.fouille = 0.0
		N.corps.secoue = 0.0


# --- ce qu'elle fait d'une chose, d'une bête ---

# une chose posée, mise en pièces : elle reste là, en épave (ce qu'elle tenait est perdu), et la terre garde ses pattes autour.
# cote : de quel côté elle tirait. (noire_faim l'appelle au bout du saccage ; la vitrine et l'essai, pour en voir une)
func mettre_en_pieces(s, cote: float = 1.0, dire: bool = true) -> void:
	if s == null or not is_instance_valid(s) or not CHOSES.has(str(s.genre)):
		return
	var A = jeu.atelier
	var g := str(s.genre)
	var perdu := ""
	s.etat.erase("mordu")
	match g:
		"tente", "hamac":
			if A.lit == s:
				A.reveiller("")
			s.etat.erase("occupe")
		"recuperateur":
			if float(s.etat.get("eau", 0.0)) >= 1.0:
				perdu = " Son eau s'en va dans la terre."
			s.etat["eau"] = 0.0
		"filet", "filet_filin":
			if s.etat.has("prise"):
				perdu = " Elle a mangé ce qui s'y était pris."
				s.etat.erase("prise")
				s.etat["mangee"] = true
		"epouvantail":
			s.etat.erase("regard")
			s.etat["alerte"] = 0.0
		"mangeoire":
			if int(s.etat.get("foin", 0)) > 0:
				perdu = " Son foin est foulé."
			s.etat["foin"] = 0
		"carre":
			s.etat["culture"] = ""
			s.etat["stade"] = 0.0
			s.etat["broute"] = 0.0
	s.etat["saccage"] = 1.0
	s.etat["cote"] = 1.0 if cote >= 0.0 else -1.0
	# (de quelle nuit : pour remettre ses empreintes autour, si la partie est reprise avant le soir)
	s.etat["nuit"] = int(jeu.nuits)
	if s.has_method("redessiner"):
		s.redessiner(true)
	_empreintes_autour(s.position, cote)
	if not dire:
		return
	_bruit(s, 9)
	if jeu.effets != null:
		jeu.effets.secousse(0.12 * clampf(1.0 - s.position.distance_to(jeu.joueur.position) / 700.0, 0.0, 1.0))
	jeu.ui.message(str(CHOSES[g][1]) + perdu, N.TEINTE)
	if g != "carre" and jeu.has_method("_conseil"):
		jeu._conseil("epave", true, "Ce qu'elle a mis en pièces se répare sur place (« Agir »), pour la moitié de son prix. Ou se replie : tu en sauves la moitié.", GRIS)
	elif g == "carre" and jeu.has_method("_conseil"):
		jeu._conseil("pietine", true, "Un carré piétiné se retourne de nouveau (« Agir »), puis se sème.", GRIS)


# la bête attachée : le filin cède sous sa gueule (une longe de chanvre, à plus forte raison). Il n'en reste que le bout de la
# longe à l'anneau du piquet, et ce qu'elle mange, là, dans le noir
func _prendre_la_bete() -> void:
	var b = cible
	var c = N.corps
	var filin: bool = bool(b.harnais.get("longe", false))
	# (ce qu'elle laisse : la longe rompue, à l'anneau ; scripts/campement.gd, le piquet)
	if not bool(b.suit_la):
		var piquet = jeu.elevage._piquet_pres(b.maison, 60.0)
		if piquet != null:
			piquet.etat["rompue"] = 2.0 if filin else 1.0
	_place = N.ou
	c._claque = 0.0
	c.secoue = 1.0
	_son("cede", b.position, 2.0 if filin else -1.0, 1.0 if filin else 1.25)
	_empreintes_autour(b.position, _cote)
	jeu.elevage.prise_par_la_noire(b, filin)
	betes += 1
	cible = null
	N._apprendre("longe")
	_cadence = 1.6
	N._changer("devore")


# ce qu'on entend quand elle déchire : la toile qui se fend, les cordes qui cèdent, le bois qui casse, la terre foulée ; k : le
# combientième coup de tête (9 : le dernier, quand tout s'effondre). Et ce qui en vole
func _bruit(s, k: int) -> void:
	var p: Vector2 = s.position
	var matiere := str(CHOSES[str(s.genre)][2])
	var dernier := k >= 9
	var h: float = randf_range(0.92, 1.08)
	match matiere:
		"toile":
			_son("dechire%d" % (k % 2), p, 0.0, h)
			if dernier or k == 1:
				_son("brise%d" % (k % 2), p, -2.0, h)
		"corde":
			_son("cede", p, 0.0, h * 1.15)
			if dernier:
				_son("pierre", p, 0.0, 0.7)
		"paille":
			_son("brise%d" % (k % 2), p, -1.0, h * 1.1)
			_son("dechire%d" % ((k + 1) % 2), p, -4.0, h * 1.1)
		"bois":
			_son("brise%d" % (k % 2), p, 0.0, h * 0.9)
		"terre":
			_son("pas_lourd", p, 0.0, h * 1.1)
			_son("herbe", p, 0.0, h * 0.8)
	if jeu.effets != null and jeu.effets.has_method("saccage"):
		jeu.effets.saccage(p, matiere, _cote, dernier)


# un son de la faim, là où il se fait : on l'entend du feu, plus faible avec la distance, jusqu'à 1 300 pixels (elle ne va pas
# au-delà de NOIRE_FAIM_PORTEE du feu : on l'entend toujours déchirer)
func _son(nom: String, p: Vector2, db: float, hauteur: float = 1.0) -> void:
	jeu.sons.au_loin(nom, p, float(NIVEAUX.get(nom.rstrip("0123456789"), -8.0)) + db, hauteur, 1300.0)


# ses pattes, autour de ce qu'elle a mis en pièces : quatre empreintes, larges comme un buste, les griffes vers la chose (elles
# tiennent jusqu'au soir : scripts/traces.gd)
func _empreintes_autour(p: Vector2, cote: float) -> void:
	if jeu.traces == null:
		return
	var u := R.NOIRE_LARGEUR
	for q in [Vector2(0.18, 0.05), Vector2(0.22, -0.03), Vector2(0.5, 0.06), Vector2(0.56, -0.02)]:
		var ou: Vector2 = p + Vector2(cote * float(q.x) * u, float(q.y) * u)
		jeu.traces.poser(ou, PI if cote > 0.0 else 0.0, u * 0.052, 420.0, 2, "la-noire", 0.95)


# une partie reprise : les empreintes ne se gardent pas (scripts/traces.gd), mais celles de la dernière nuit tiennent jusqu'au
# soir. On les remet autour de ce qu'elle a mis en pièces cette nuit (reprise de nuit), ou la nuit d'avant (reprise de jour)
func _retracer(nuit: bool) -> void:
	if jeu.atelier == null:
		return
	var derniere: int = int(jeu.nuits) if nuit else int(jeu.nuits) - 1
	for s in jeu.atelier.poses:
		if est_epave(s) and int(s.etat.get("nuit", -9)) == derniere:
			_empreintes_autour(s.position, float(s.etat.get("cote", 1.0)))


# --- les épaves (scripts/atelier.gd les répare et les replie ; scripts/campement_epave.gd les dessine) ---

# cette chose posée est-elle en pièces ?
static func est_epave(s) -> bool:
	if s == null or not is_instance_valid(s):
		return false
	var v = s.etat.get("saccage", 0.0)
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0


# ce que coûte de la réparer sur place, d'après son prix : de chaque matière, la part que l'épave n'a plus (arrondie au-dessus)
static func cout_reparation(cout: Dictionary) -> Dictionary:
	var out := {}
	for k in cout:
		var n := int(cout[k]) - int(floor(float(cout[k]) * R.NOIRE_EPAVE))
		if n > 0:
			out[k] = n
	return out


# ce qu'on en sauve en la repliant : de chaque matière, la part qui reste (arrondie en dessous)
static func restes(cout: Dictionary) -> Dictionary:
	var out := {}
	for k in cout:
		var n := int(floor(float(cout[k]) * R.NOIRE_EPAVE))
		if n > 0:
			out[k] = n
	return out


# --- la partie gardée (noire.gd, photo, reprendre) ---

func photo() -> Dictionary:
	return {"prises": prises, "betes": betes, "soir": soir}


func reprendre(d) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	prises = int(d.get("prises", 0))
	betes = int(d.get("betes", 0))
	soir = bool(d.get("soir", false))
	_a_retracer = true
