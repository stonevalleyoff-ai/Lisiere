extends RefCounted
# Lisière — la Noire (scripts/noire.gd)
# Une seule bête, qui n'est pas d'Orvane : gigantesque, le poil noir, les yeux rouges. Les bêtes d'Orvane sont des animaux ;
# elle, elle suit un scénario, d'acte en acte, une nuit après l'autre :
#  1. les signes : on ne la voit pas. Un appel grave, loin, dans la nuit ; à l'aube, des empreintes énormes près du camp ;
#  2. les yeux : elle vient. Tout se tait avant elle, les autres bêtes s'en vont. Deux yeux rouges à la lisière de la lumière,
#     qui regardent longtemps. Si la veilleuse avance, ils s'éteignent, et elle reparaît ailleurs. Elle ne mord pas encore ;
#  3. le siège : elle tourne autour du camp, s'arrête, regarde, suit le feu à mesure qu'il baisse, et la veilleuse quand elle
#     en fait le tour ; elle feinte (elle se jette vers la lumière et s'arrête à son bord) ; une bûche jetée la fait sursauter.
#     Hors de la lumière d'un feu, la torche ne la tient qu'un moment ; puis elle s'aplatit, gronde (le présage), et charge ;
#  4. la chasse : comme le siège, mais elle part plus tôt de sa tanière et la torche la tient moitié moins.
# Ce qui la rend juste : elle s'annonce toujours (l'appel quand elle part, le silence quand elle approche, le présage avant la
# charge), un feu vif la tient toujours, et l'on peut lui échapper : elle dort le jour dans sa tanière, d'où elle part chaque
# nuit ; plus on dort loin, plus elle arrive tard. À l'aube elle y retourne, et sa piste y mène (scripts/traces.gd) : on peut la
# suivre, trouver où elle dort, et choisir où passer la nuit. Si la veilleuse s'éloigne trop, elle change de tanière pour suivre.
# Les coups ne la tuent pas ; assez de coups dans une nuit, et elle se retire jusqu'à la suivante.
# Ici, le scénario : où elle est, ce qu'elle veut faire. Son corps est une bête comme les autres (scripts/bete.gd, le rôle
# « noire »), qui fait ce qu'on lui dit ; tant qu'elle est loin de la veilleuse, elle n'a pas de corps : seulement une place.

const R := preload("res://scripts/regles.gd")

# ce qu'elle est : une bête faite à la main, que le bestiaire de Lisière dessine comme les autres (scripts/bestiaire.gd lit
# « noire » : une robe d'encre, l'œil en fente de braise, l'échine hérissée)
const LIGNEE := {
	"id": "la-noire", "nom": "La Noire",
	"plan": {
		"noire": true, "regime": "carnivore", "masse_kg": 900.0, "taille_m": 3.4, "locomotion": ["marche", "course"],
		"vitesse_rel": 9.0, "perception": 1.0, "temperament": 1.0, "activite": "nocturne",
		"corps": {"forme": "quadrupede", "pattes": 4, "long": 0.78, "haut": 0.6, "cou": 0.26, "tete": 0.9, "museau": 0.75,
			"oreilles": 0.2, "queue": 0.7, "cornes": 0, "crete": 0, "ailes": 0, "carapace": 0, "antennes": 0, "motif": "uni",
			"posture": 0.45, "organes": []},
	},
	"phenotypes": [{"traits": ["crocs-allonges"]}],
}
const NOM := "La Noire"
const TEINTE := Color(0.93, 0.47, 0.42)
# ce qu'on apprend d'elle, dans l'ordre du carnet : [la clé, ce que le carnet en garde, ce que le jeu dit la première fois]
const SAVOIRS := [
	["appel", "Elle appelle quand elle quitte sa tanière. On entend de quel côté elle vient.",
		"Quelque chose appelle, très loin. Ce n'est pas une bête d'ici."],
	["empreintes", "Ses empreintes sont larges comme un buste. Les griffes pointent vers où elle allait.",
		"Des empreintes, larges comme ton buste. Les griffes pointent vers où elle est partie."],
	["silence", "Avant qu'elle arrive, tout se tait : les autres bêtes s'en vont.",
		"Tout se tait. Même les grillons."],
	["yeux", "Deux yeux rouges à la lisière de la lumière. Elle regarde longtemps avant d'oser.",
		"Deux yeux rouges, à la lisière. Ils ne bougent pas."],
	["feu", "Un feu vif la tient : elle n'entre pas dans sa lumière. Elle le suit quand il baisse.",
		"Elle n'entre pas dans la lumière du feu. Garde-le vif."],
	["feinte", "Elle feinte : elle se jette vers la lumière et s'arrête à son bord. Qui recule hors du feu est perdu.",
		"Elle s'est jetée vers toi, et s'est arrêtée au bord de la lumière. Ne recule pas hors du feu."],
	["torche", "La torche ne la retient qu'un moment. Elle s'aplatit, gronde, puis elle passe.",
		"La torche la tient, mais pas longtemps. Quand elle s'aplatit, cours vers un feu."],
	["coups", "Les coups ne la tuent pas. Assez de coups, et elle se retire jusqu'à la nuit suivante.",
		"Elle recule dans le noir. Elle reviendra."],
	["taniere", "Le jour, elle dort dans sa tanière. Sa piste y mène. On ne la réveille pas.",
		"Elle dort là, le jour. Ne t'approche pas davantage."],
	["distance", "Plus on dort loin de sa tanière, plus elle arrive tard dans la nuit.",
		"Tu as dormi loin d'elle : elle est arrivée tard."],
]

var jeu
var acte := 0                    # celui de la nuit en cours, ou de la dernière (0 : elle n'est pas encore venue)
var taniere := Vector2.ZERO
var taniere_connue := false      # la veilleuse l'a trouvée (la carte du carnet la montre)
var ou := Vector2.ZERO           # où elle est : là où est son corps, ou sa place tant qu'elle n'en a pas
var corps = null                 # sa bête (scripts/bete.gd), quand elle est assez près pour en avoir une
var etat := "dort"               # dort, vient, guette, tourne, feinte, sursaut, recule, charge, rentre
var su := {}                     # ce que la veilleuse a appris d'elle (les clés de SAVOIRS)
var vue := false                 # la veilleuse l'a vue dans la lumière (son portrait, dans le carnet)
var silence := 0.0               # de 0 à 1 : ce qu'elle fait taire autour de la veilleuse (scripts/sons.gd)
var regard := 0.0                # de 0 à 1 : elle regarde la veilleuse (la peur qu'elle fait)
var _t := 0.0                    # depuis qu'elle est dans cet état
var _nuit_t := 0.0               # depuis la tombée de la nuit
var _duree_nuit := 80.0
var _depart := 0.0               # quand elle quitte sa tanière, cette nuit (secondes après la tombée)
var _arrivee := -1.0             # quand elle est arrivée devant la veilleuse, cette nuit (-1 : pas encore)
var _prise := 0.0                # les coups qu'elle a pris cette nuit
var _retiree := false            # elle en a pris assez : elle ne reviendra que la nuit prochaine
var _mefiante := false           # frappée cette nuit : elle se tient plus loin de la lumière
var _torche := 0.0               # le temps que la torche l'a déjà tenue, cette nuit
var _presage := 0.0
var _pose := 10.0                # ce que dure le guet, ou le tour, en cours
var _sens := 1.0
var _appel := false              # elle a appelé, cette nuit
var _colere := 0.0               # réveillée de jour : elle charge ce temps-là, feu ou pas
var _loin := 420.0               # jusqu'où elle recule
var _recul := 3.0                # et combien de temps
var _fuite := 0.0
var _lu := 0.0
var _regarde := 0.0              # depuis combien de temps elle fixe la veilleuse
var _siege := 0.0                # depuis combien de temps un feu la tient
var _bloquee := 0.0
var _feinte := 8.0               # avant sa prochaine feinte
var _avant := Vector2.ZERO
var _piste_de := Vector2.ZERO    # d'où part sa piste du jour (pour la refaire, quand on reprend une partie)
var _a_piste := false
var _r := RandomNumberGenerator.new()


# --- ce que le jeu appelle ---

func commencer() -> void:
	acte = 0
	etat = "dort"
	su = {}
	vue = false
	taniere_connue = false
	corps = null
	silence = 0.0
	regard = 0.0
	_retiree = false
	_a_piste = false
	_colere = 0.0
	_r.seed = int(jeu.graine) ^ 0x5eed
	_choisir_taniere(jeu.joueur.position)
	ou = taniere


# la nuit tombe : l'acte de cette nuit, et quand elle partira
func tombee() -> void:
	acte = clampi(int(jeu.nuits) + 1, 1, 4)
	_nuit_t = 0.0
	_duree_nuit = R.DUREE * float(jeu.part_nuit)
	_depart = float(R.NOIRE_DEPART[acte]) * _duree_nuit
	_arrivee = -1.0
	_prise = 0.0
	_retiree = false
	_mefiante = false
	_torche = 0.0
	_presage = 0.0
	_appel = false
	_colere = 0.0
	_feinte = _r.randf_range(6.0, 10.0)
	if etat != "dort":
		# (encore en chemin vers sa tanière, ou en colère : elle y est)
		_disparaitre()
		ou = taniere
		etat = "dort"
	# (la piste de la veille s'en va avec le jour)
	if jeu.traces != null:
		jeu.traces.effacer(2)
	_a_piste = false


# l'aube : elle rentre, et sa piste mène à sa tanière. Si la veilleuse est trop loin, elle en prend une autre, plus près.
func aube() -> void:
	if acte == 0:
		return
	var j = jeu.joueur
	if taniere.distance_to(j.position) > R.NOIRE_SUIT:
		_choisir_taniere(j.position, (taniere - j.position).angle())
		if corps == null:
			ou = taniere
	if _arrivee >= 0.0 and _arrivee > _duree_nuit * 0.62 and acte >= 2 and not _retiree:
		_apprendre("distance")
	if corps != null:
		_changer("rentre")
		return
	if acte == 1:
		# (les signes : elle est venue regarder, de loin, sans qu'on la voie ; ses empreintes le disent)
		var vers: Vector2 = (taniere - j.position).normalized()
		_piste(j.position + vers.rotated(_r.randf_range(-0.5, 0.5)) * 300.0, taniere)
	ou = taniere
	etat = "dort"


# un coup de la veilleuse (bete.gd, blesser) : elle encaisse, se méfie, et finit par se retirer
func frappee(n: float) -> void:
	_prise += n
	_mefiante = true
	if etat == "dort":
		_reveiller()
		return
	if corps != null and is_instance_valid(corps):
		corps.sursauter()
	if _prise >= R.NOIRE_ENDURE and not _retiree:
		_retiree = true
		_colere = 0.0
		_apprendre("coups")
		_changer("rentre")
		return
	if etat == "guette" or etat == "tourne":
		if acte >= 3 and jeu.feu_qui_protege(jeu.joueur.position) == null:
			# (frappée hors de la lumière : elle n'attend pas)
			_changer("charge")
		else:
			_reculer(460.0, 3.5)


# une bûche jetée dans le feu, sa gerbe d'étincelles (bete.gd, gerbe) : elle sursaute, et s'écarte d'un pas
func gerbe() -> void:
	if etat == "guette" or etat == "tourne" or etat == "feinte":
		_changer("sursaut")


# elle vient de mordre (principal.gd, mordre) : elle se reprend un instant, le temps de courir vers un feu
func a_mordu() -> void:
	if etat != "charge":
		return
	if _colere > 0.0:
		# (réveillée de jour : une morsure, et sa colère est passée ; elle s'en va dormir ailleurs)
		_partir_ailleurs()
		return
	_reculer(230.0, 2.2)


# un de ses pas, en « ou » (bete.gd) : on l'entend venir, de loin ; de près, la terre se soulève sous sa patte ; lancée, elle
# fait trembler le sol
func pas(b, ou: Vector2) -> void:
	var d: float = b.position.distance_to(jeu.joueur.position)
	if d > 950.0:
		return
	var lancee: bool = etat == "charge" or etat == "feinte"
	jeu.sons.evenement("pas_lourd", lerpf(-5.0, -26.0, d / 950.0) + (2.0 if lancee else 0.0), _r.randf_range(0.88, 1.06), jeu.sons.pan_de(ou), jeu.sons.B_MONDE)
	if d < 700.0 and jeu.effets != null:
		jeu.effets.pas(ou, 1.0 if lancee else 0.6)
	if d < 380.0 and lancee:
		jeu.effets.secousse(0.16 * (1.0 - d / 380.0))


# elle est là, ou elle arrive : le directeur ne fait venir personne d'autre (principal.gd)
func presente() -> bool:
	return silence > 0.4


# la peur qu'elle fait, par seconde (principal.gd, _corps)
func peur() -> float:
	return R.NOIRE_PEUR * regard


# à quelle distance de la veilleuse est son corps (INF : elle n'en a pas)
func distance() -> float:
	if corps == null or not is_instance_valid(corps) or jeu.joueur == null:
		return INF
	return corps.position.distance_to(jeu.joueur.position)


# ce que le carnet en dit : les phrases de ce qu'on a appris, dans l'ordre
func savoirs() -> Array:
	var out := []
	for s in SAVOIRS:
		if su.has(s[0]):
			out.append(str(s[1]))
	return out


# (la vitrine, l'essai) la nuit de cet acte, et elle déjà en chemin, à cette distance de la veilleuse
func mettre_en_scene(acte_: int, distance: float = 900.0, angle: float = PI) -> void:
	tombee()
	acte = clampi(acte_, 1, 4)
	_depart = 0.0
	_appel = true
	ou = jeu.joueur.position + Vector2.from_angle(angle) * distance
	_changer("vient")


# --- la partie gardée ---

func photo() -> Dictionary:
	return {
		"acte": acte, "tx": snappedf(taniere.x, 0.1), "ty": snappedf(taniere.y, 0.1), "connue": taniere_connue, "su": su.keys(),
		"vue": vue, "retiree": _retiree, "prise": snappedf(_prise, 0.1), "torche": snappedf(_torche, 0.1), "nuit": snappedf(_nuit_t, 0.1),
		"appel": _appel, "piste": [snappedf(_piste_de.x, 0.1), snappedf(_piste_de.y, 0.1)] if _a_piste else [],
	}


# une partie reprise : ce qu'on savait d'elle, sa tanière, l'acte ; elle-même repart de sa tanière (de nuit, elle revient)
func reprendre(d: Dictionary) -> void:
	if d.is_empty():
		return
	acte = int(d.get("acte", 0))
	taniere = Vector2(float(d.get("tx", taniere.x)), float(d.get("ty", taniere.y)))
	taniere_connue = bool(d.get("connue", false))
	su = {}
	for k in d.get("su", []):
		su[str(k)] = true
	vue = bool(d.get("vue", false))
	_retiree = bool(d.get("retiree", false))
	_prise = float(d.get("prise", 0.0))
	_torche = float(d.get("torche", 0.0))
	_nuit_t = float(d.get("nuit", 0.0))
	_appel = bool(d.get("appel", false))
	_duree_nuit = R.DUREE * float(jeu.part_nuit)
	_depart = float(R.NOIRE_DEPART[clampi(acte, 0, 4)]) * _duree_nuit
	ou = taniere
	etat = "dort"
	var p: Array = d.get("piste", [])
	if p.size() >= 2 and jeu.jour_du_ciel() > 0.0:
		_piste(Vector2(float(p[0]), float(p[1])), taniere)


# --- chaque image ---

func maj(delta: float) -> void:
	var j = jeu.joueur
	if j == null:
		return
	_t += delta
	var nuit: bool = jeu.jour_du_ciel() <= 0.0
	if nuit:
		_nuit_t += delta
	if corps != null and not is_instance_valid(corps):
		corps = null
	if corps != null:
		ou = corps.position
	# (le jour est là et elle est encore dehors : elle rentre ; l'aube le lui dit d'ordinaire, ceci le garantit)
	if not nuit and _colere <= 0.0 and jeu.jour_du_ciel() > 0.5 and etat != "dort" and etat != "rentre":
		_changer("rentre")
	match etat:
		"dort":
			_dormir(j, nuit)
		"vient":
			_venir(delta, j)
		"guette", "tourne":
			_assieger(delta, j)
		"feinte":
			_feinter(j)
		"sursaut":
			_sursauter(j)
		"recule":
			_s_effacer(j)
		"charge":
			_charger(delta, j)
		"rentre":
			_rentrer(j)
	_entourage(delta, j)
	_lire_le_sol(delta, j)


func _changer(e: String) -> void:
	etat = e
	_t = 0.0
	_presage = 0.0
	_bloquee = 0.0
	if corps != null:
		corps.aplatie = 0.0


# --- ses états ---

# dans sa tanière. La nuit, elle attend son heure (le premier acte : elle ne fait qu'appeler). Le jour, elle dort : qui vient
# jusque-là la voit, couchée, les yeux clos ; trop près, on la réveille.
func _dormir(j, nuit: bool) -> void:
	if corps == null:
		ou = taniere
	if nuit and not _retiree and _colere <= 0.0:
		if acte == 1:
			if not _appel and _nuit_t >= _depart:
				_appeler()
			return
		if acte >= 2 and _nuit_t >= _depart:
			_appeler()
			_changer("vient")
			return
	var d: float = taniere.distance_to(j.position)
	if corps == null and d < 950.0:
		_apparaitre(taniere)
		corps.ordre = "dort"
		corps.couchee = 1.0
		corps.yeux_clos = 1.0
		corps.regard = -1.0 if j.position.x > taniere.x else 1.0
	elif corps != null and d > 1500.0:
		_disparaitre()
	if corps == null:
		return
	corps.ordre = "dort"
	if not nuit:
		if not taniere_connue and d < 340.0:
			taniere_connue = true
			_apprendre("taniere")
		if d < R.NOIRE_REVEIL:
			_reveiller()


# réveillée (de trop près, ou d'un coup) : elle se lève et charge, feu ou pas, un moment ; puis elle s'en va faire sa tanière
# ailleurs
func _reveiller() -> void:
	if corps == null:
		return
	_colere = 7.0
	jeu.grognement(corps, true)
	jeu.joueur.peur = minf(100.0, float(jeu.joueur.peur) + 25.0)
	jeu.ui.message("Tu l'as réveillée. Cours.", TEINTE)
	_changer("charge")


# elle vient : sans corps tant qu'elle est loin (elle avance vers la veilleuse), puis elle en prend un, hors de vue, et marche
# jusqu'à la lisière de la lumière
func _venir(delta: float, j) -> void:
	if corps == null:
		ou = ou.move_toward(j.position, R.NOIRE_VOYAGE * delta)
		if ou.distance_to(j.position) < 1080.0:
			_apparaitre(_entree(j.position, (ou - j.position).angle()))
		return
	var a := _anneau(j)
	var ancre: Vector2 = a[0]
	var tenue: float = a[1]
	var ici: Vector2 = ou - ancre
	corps.ordre = "va"
	corps.ordre_allure = 0.46
	corps.ordre_but = ancre + (ici.normalized() if ici.length() > 1.0 else Vector2.RIGHT) * tenue
	if ici.length() < tenue + 50.0 or _coincee(delta):
		_arrivee = _nuit_t
		_pose = _r.randf_range(12.0, 18.0) if acte == 2 else _r.randf_range(5.0, 8.0)
		_sens = 1.0 if _r.randf() < 0.5 else -1.0
		_changer("guette")


# devant la veilleuse : elle guette (immobile, les deux yeux sur elle), puis tourne autour de la lumière, puis guette encore.
# Le deuxième acte s'en tient là, et elle s'efface si l'on avance sur elle. Ensuite : hors de la lumière d'un feu, la torche la
# tient un moment (de moins en moins, d'un acte à l'autre) ; puis vient le présage (aplatie, elle gronde), puis la charge.
func _assieger(delta: float, j) -> void:
	if corps == null:
		_changer("vient")
		return
	var a := _anneau(j)
	var ancre: Vector2 = a[0]
	var tenue: float = a[1]
	var feu = a[2]
	var ici: Vector2 = ou - ancre
	var dj: float = ou.distance_to(j.position)
	if acte == 2:
		if feu == null and dj < 215.0:
			# (la veilleuse sort de la lumière et avance sur elle : les yeux s'éteignent, elle reparaît ailleurs)
			_sens = -_sens
			_reculer(540.0, 4.5)
			return
	elif feu == null:
		if float(j.torche) > 0.0 and _torche < float(R.NOIRE_TORCHE[acte]):
			_torche += delta
			_presage = 0.0
			corps.aplatie = 0.0
			if _torche > 2.5:
				_apprendre("torche")
		else:
			# le présage : elle s'aplatit et gronde, le temps qu'on la voie venir
			if _presage <= 0.0:
				jeu.grognement(corps, true)
				jeu.ui.message("Elle s'aplatit. Elle va charger.", TEINTE)
			_presage += delta
			corps.aplatie = 1.0
			corps.ordre = "guette"
			if _presage >= R.NOIRE_PRESAGE:
				_changer("charge")
			return
	else:
		_presage = 0.0
		corps.aplatie = 0.0
		_siege += delta
		if acte >= 3 and _siege > 6.0:
			_apprendre("feu")
		# la feinte : de temps en temps elle se jette vers la lumière, et s'arrête à son bord
		_feinte -= delta
		if _feinte <= 0.0 and absf(ici.length() - tenue) < 60.0:
			_feinte = _r.randf_range(7.0, 12.0) if acte < 4 else _r.randf_range(4.0, 8.0)
			jeu.grognement(corps, true)
			_changer("feinte")
			return
	if etat == "guette":
		corps.ordre = "guette"
		var vise: Vector2 = j.position - ancre
		var ecart := wrapf(vise.angle() - ici.angle(), -PI, PI) if (feu != null and vise.length() > 24.0) else 0.0
		if absf(ici.length() - tenue) > 45.0:
			# (le feu a baissé, ou grandi ; la veilleuse a bougé : elle reprend sa place)
			corps.ordre = "va"
			corps.ordre_allure = 0.4
			corps.ordre_but = ancre + ici.normalized() * tenue
		elif absf(ecart) > 0.45:
			# (la veilleuse fait le tour du feu : elle la suit le long de la lisière, pour rester en face d'elle)
			corps.ordre = "va"
			corps.ordre_allure = 0.55
			corps.ordre_but = ancre + Vector2.from_angle(ici.angle() + signf(ecart) * 0.5) * tenue / cos(0.5)
		elif dj < 620.0 and jeu.eclairage(corps.point_oeil()) < 0.6:
			_regarde += delta
			if _regarde > 2.0:
				_apprendre("yeux")
		if _t > _pose:
			_pose = _r.randf_range(7.0, 12.0)
			_changer("tourne")
	else:
		corps.ordre = "va"
		corps.ordre_allure = 0.36 if acte < 4 else 0.46
		# (elle vise un peu plus loin que le cercle, pour ne pas le couper par la corde)
		corps.ordre_but = ancre + Vector2.from_angle(ici.angle() + _sens * 0.5) * tenue / cos(0.5)
		if _coincee(delta):
			_sens = -_sens
		if _t > _pose:
			_pose = _r.randf_range(12.0, 18.0) if acte == 2 else _r.randf_range(4.0, 7.0)
			_changer("guette")


# la feinte : elle se jette vers le feu de toute sa vitesse, bute sur le bord de sa lumière (bete.gd l'y arrête), y tient un
# instant, face à la veilleuse, puis reprend sa ronde
func _feinter(j) -> void:
	if corps == null:
		_changer("vient")
		return
	var feu = jeu.feu_qui_protege(j.position)
	if feu == null or _t > 1.25:
		if feu != null:
			_apprendre("feinte")
		_pose = _r.randf_range(4.0, 7.0)
		_changer("tourne")
		return
	if _t < 0.55:
		var ici: Vector2 = ou - feu.position
		corps.ordre = "va"
		corps.ordre_allure = 1.0
		corps.ordre_but = feu.position + (ici.normalized() if ici.length() > 1.0 else Vector2.RIGHT) * float(feu.rayon()) * 0.9
	else:
		corps.ordre = "guette"


# le sursaut : une gerbe d'étincelles l'écarte de quelques pas, puis elle revient guetter
func _sursauter(j) -> void:
	if corps == null:
		_changer("vient")
		return
	var a := _anneau(j)
	var ancre: Vector2 = a[0]
	var ici: Vector2 = ou - ancre
	corps.ordre = "va"
	corps.ordre_allure = 0.85
	corps.ordre_but = ancre + (ici.normalized() if ici.length() > 1.0 else Vector2.RIGHT) * (float(a[1]) + 110.0)
	if _t > 0.9:
		_pose = _r.randf_range(3.0, 6.0)
		_changer("guette")


# elle recule dans le noir, les yeux clos, puis revient
func _reculer(loin: float, duree: float) -> void:
	_loin = loin
	_recul = duree
	_changer("recule")


func _s_effacer(j) -> void:
	if corps == null:
		_changer("vient")
		return
	var d: Vector2 = ou - j.position
	corps.ordre = "efface"
	corps.ordre_allure = 0.7
	corps.ordre_but = _contourner(ou, j.position + (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * (_loin + 80.0))
	if _t > _recul:
		_pose = _r.randf_range(3.0, 6.0)
		_changer("tourne")


# elle charge : droit sur la veilleuse, et elle mord. La lumière d'un feu l'arrête net (sauf réveillée de jour : sa colère
# passe d'abord).
func _charger(delta: float, j) -> void:
	if corps == null:
		_changer("vient")
		return
	if _colere > 0.0:
		_colere -= delta
		if _colere <= 0.0:
			_partir_ailleurs()
			return
	elif jeu.feu_qui_protege(j.position) != null:
		_changer("tourne")
		return
	var d: Vector2 = ou - j.position
	corps.ordre = "charge"
	corps.ordre_allure = 1.0
	corps.ordre_but = _contourner(ou, j.position + (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * 62.0)


# sa colère est passée : elle s'en va, et fera sa tanière ailleurs
func _partir_ailleurs() -> void:
	_colere = 0.0
	_choisir_taniere(jeu.joueur.position, (ou - jeu.joueur.position).angle())
	_changer("rentre")


# elle rentre : elle s'éloigne vers sa tanière ; hors de vue, elle n'a plus de corps, et sa piste dit le reste du chemin
func _rentrer(j) -> void:
	if corps != null:
		corps.ordre = "va"
		corps.ordre_allure = 0.62
		corps.ordre_but = _contourner(ou, taniere)
		if ou.distance_to(taniere) < 60.0:
			_changer("dort")
			return
		if ou.distance_to(j.position) > 1150.0 or _t > 26.0:
			_disparaitre()
	if corps == null:
		_piste(ou, taniere)
		ou = taniere
		etat = "dort"


# --- autour d'elle ---

# ce qu'elle change autour de la veilleuse : le silence qui la précède, les bêtes qui s'en vont, la peur sous son regard
func _entourage(delta: float, j) -> void:
	var la: bool = etat != "dort" and etat != "rentre"
	var d: float = ou.distance_to(j.position)
	var cible := (1.0 - smoothstep(520.0, 1400.0, d)) if la else 0.0
	silence = move_toward(silence, cible, delta * (0.3 if cible > silence else 0.1))
	if silence > 0.6 and la:
		_apprendre("silence")
	var fixe := 0.0
	if corps != null and la and d < 620.0 and float(corps.paupiere()) > 0.5:
		fixe = 1.0 if (etat == "guette" or etat == "charge" or etat == "feinte") else 0.45
	regard = move_toward(regard, fixe, delta * 1.5)
	if corps == null:
		return
	if not vue and d < 520.0 and jeu.eclairage(ou) > 0.35:
		vue = true
	_fuite -= delta
	if (la or etat == "dort") and _fuite <= 0.0:
		# (les autres bêtes ne restent pas près d'elle ; endormie, elles se tiennent seulement à l'écart de sa tanière)
		_fuite = 0.6
		var portee := 580.0 if la else 340.0
		for b in jeu.get_tree().get_nodes_in_group("betes"):
			if b != corps and b.role != "echo" and b.position.distance_to(ou) < portee:
				b.effrayer(ou, 5.0)


# la veilleuse marche sur sa piste, de jour ou à la lumière : elle la reconnaît
func _lire_le_sol(delta: float, j) -> void:
	_lu -= delta
	if _lu > 0.0 or su.has("empreintes") or jeu.traces == null:
		return
	_lu = 0.5
	if jeu.traces.pres(j.position, 75.0, 2) and jeu.eclairage(j.position) > 0.4:
		_apprendre("empreintes")


# --- ce qu'il faut pour tout cela ---

# une chose apprise d'elle : dite une fois, gardée dans le carnet
func _apprendre(cle: String) -> bool:
	if su.has(cle):
		return false
	su[cle] = true
	for s in SAVOIRS:
		if s[0] == cle:
			jeu.ui.message(str(s[2]), TEINTE)
	return true


# son appel : grave, long, de là où elle est ; plus faible de loin, et du côté d'où elle vient
func _appeler() -> void:
	if _appel:
		return
	_appel = true
	var d: float = ou.distance_to(jeu.joueur.position)
	jeu.sons.evenement("appel", lerpf(-3.0, -15.0, clampf(d / 6000.0, 0.0, 1.0)), _r.randf_range(0.94, 1.04), jeu.sons.pan_de(ou), jeu.sons.B_PEUR)
	_apprendre("appel")


# où est le cercle qu'elle tient : autour du feu qui protège la veilleuse, à la lisière de sa lumière ; sans feu, autour d'elle
func _anneau(j) -> Array:
	var feu = jeu.feu_qui_protege(j.position)
	var plus := 80.0 if _mefiante else 0.0
	if feu != null:
		return [feu.position, float(feu.rayon()) * 1.04 + 26.0 + plus, feu]
	if acte >= 3 and float(j.torche) > 0.0:
		return [j.position, 215.0 + plus, null]
	return [j.position, (300.0 if acte == 2 else 250.0) + plus, null]


# le chemin de a à b, sans traverser la lumière d'un feu (elle n'y tient pas : bete.gd l'en repousse, et droit sur le feu elle
# n'avancerait plus) : si un feu est en travers, elle vise à côté de sa lumière, du côté où elle penche déjà
func _contourner(a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var l := ab.length()
	if l < 1.0:
		return b
	var dir := ab / l
	for f in jeu.feux_et_foyers():
		if not f.allume():
			continue
		var c: Vector2 = f.position
		var r: float = float(f.rayon()) * 0.98 + 16.0
		var s := clampf((c - a).dot(dir), 0.0, l)
		var pres := a + dir * s
		if s <= 0.0 or pres.distance_to(c) >= r:
			continue
		var cote := dir.orthogonal()
		var penche := cote.dot(a - c)
		if absf(penche) < 4.0:
			penche = _sens
		return c + cote * signf(penche) * (r + 60.0) + dir * 40.0
	return b


# elle n'avance plus (une rivière, une paroi) : vrai au bout d'une seconde et demie sans bouger
func _coincee(delta: float) -> bool:
	if corps == null:
		return false
	if corps.position.distance_to(_avant) < 12.0 * delta:
		_bloquee += delta
	else:
		_bloquee = 0.0
	_avant = corps.position
	if _bloquee > 1.5:
		_bloquee = 0.0
		return true
	return false


func _apparaitre(p: Vector2) -> void:
	corps = jeu._creer({"lignee": LIGNEE, "id": "la-noire", "masse": 900.0, "largeur": R.NOIRE_LARGEUR}, "noire", p)
	corps.nom = NOM
	corps.vue = true          # (elle n'est pas une rencontre d'Orvane : rien n'est compté)
	ou = p
	_avant = p


func _disparaitre() -> void:
	if corps != null and is_instance_valid(corps):
		corps.remove_from_group("betes")
		corps.queue_free()
	corps = null


# où elle prend corps, en venant : hors de vue, du côté d'où elle arrive, et d'où elle peut marcher jusqu'à la veilleuse (ni
# rivière ni paroi en travers, si un tel côté existe)
func _entree(centre: Vector2, cap: float) -> Vector2:
	for k in 9:
		var a := cap + (0.0 if k == 0 else (0.35 * ((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)))
		var p := centre + Vector2.from_angle(a) * 1040.0
		if _degage(p, centre):
			return p
	return centre + Vector2.from_angle(cap) * 1040.0


# peut-on marcher de a à b ? (le monde ouvert : ni eau, ni crête, ni roche en chemin)
func _degage(a: Vector2, b: Vector2) -> bool:
	if not jeu.ouvert or jeu.carte == null:
		return absf(a.x) < R.DEMI and absf(a.y) < R.DEMI
	var C = jeu.carte
	for k in 9:
		var p := a.lerp(b, k / 9.0)
		if C.retenir(p).distance_to(p) > 3.0 or bool(C.roche_en(p)):
			return false
	return true


# une tanière, à bonne distance de « autour » (de préférence du côté « cap ») : là où l'on tient debout ; près d'une grotte ou
# sous les arbres si elle a le choix ; dans un lieu fermé, le plus loin possible
func _choisir_taniere(autour: Vector2, cap: float = NAN) -> void:
	var meilleur := autour + Vector2.from_angle(_r.randf() * TAU) * R.NOIRE_TANIERE_MIN
	var note0 := -INF
	var C = jeu.carte if jeu.ouvert else null
	for k in 24:
		# (dans un lieu fermé, pas de côté préféré : il n'y a que ses bords, et elle prend le plus loin)
		var a := (cap + _r.randf_range(-0.8, 0.8)) if (not is_nan(cap) and C != null) else _r.randf() * TAU
		var p := autour + Vector2.from_angle(a) * _r.randf_range(R.NOIRE_TANIERE_MIN, R.NOIRE_TANIERE_MAX)
		var note := _r.randf()
		if C != null:
			var pr: Array = C.proches(p)
			if float(pr[3]) == INF or bool(C.regions[int(pr[0])]["eau"]):
				continue
			p = C.retenir(p)
			if bool(C.roche_en(p)) or float(C.lit(p)) > 0.0:
				continue
			if bool(C.pres_d_une_grotte(p)):
				note += 2.0
			if str(C.regions[C.region_en(p)]["type"]) in ["foret", "taiga", "jungle", "marais"]:
				note += 0.6
		else:
			var lim := R.DEMI * 0.88
			p = Vector2(clampf(p.x, -lim, lim), clampf(p.y, -lim, lim))
			note += p.distance_to(autour) / 800.0
		if note > note0:
			note0 = note
			meilleur = p
	taniere = meilleur
	taniere_connue = false


# sa piste, de a à b : une empreinte à chaque foulée, d'un côté puis de l'autre, le long d'un chemin qui flâne ; par endroits
# elle se perd (un trou), et reprend plus loin. Elle tient jusqu'au soir.
func _piste(a: Vector2, b: Vector2) -> void:
	if jeu.traces == null:
		return
	_piste_de = a
	_a_piste = true
	var long := a.distance_to(b)
	if long < 80.0:
		return
	var dir := (b - a) / long
	var orth := dir.orthogonal()
	var pas := R.NOIRE_LARGEUR * 0.2
	var n := int(long / pas)
	var phase := _r.randf() * TAU
	var trou := _r.randf_range(500.0, 800.0)
	var cote := 1.0
	var avant := a
	for i in n:
		var s := i * pas
		# (elle flâne : deux ondes ; rien aux deux bouts, où la piste doit partir du camp et finir à la tanière)
		var bord := smoothstep(0.0, 400.0, s) * smoothstep(0.0, 400.0, long - s)
		var p := a + dir * s + orth * (130.0 * sin(s / 520.0 + phase) + 60.0 * sin(s / 190.0 + phase * 1.7)) * bord
		trou -= pas
		# (jamais de trou aux deux bouts : la piste se trouve au camp, et ne se perd pas en vue de la tanière)
		if trou < 0.0 and s > 380.0 and long - s > 380.0:
			# (la piste se perd, sur quelques foulées, puis reprend)
			if trou < -_r.randf_range(160.0, 300.0):
				trou = _r.randf_range(500.0, 900.0)
			avant = p
			continue
		cote = -cote
		var sens := (p - avant).normalized() if p.distance_to(avant) > 1.0 else dir
		jeu.traces.poser(p + sens.orthogonal() * cote * R.NOIRE_LARGEUR * 0.07, sens.angle(), R.NOIRE_LARGEUR * 0.052, 420.0, 2, "la-noire", 0.95)
		avant = p
