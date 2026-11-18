extends RefCounted
# Lisière — l'élevage (scripts/elevage.gd)
# Les bêtes que la veilleuse apprivoise. Une proie à quatre pattes vient manger l'appât qu'elle pose (deux baies) ; la tête
# dedans, elle laisse venir : « Agir » lui passe un licol (scripts/atelier.gd), et elle est à elle (son rôle : « compagne »,
# scripts/bete.gd). Elle la suit, ou reste où on la laisse (à un piquet d'attache, elle broute autour). Elle porte des
# sacoches (à ses côtés, la veilleuse porte davantage) ; assez forte, une selle : on la monte, et l'on va bien plus vite.
# Nourrie (elle broute le jour, ou mange à la mangeoire), elle donne son lait.
# Le noir les rend folles : la nuit, hors de la lumière d'un feu, une bête prend peur, rompt sa longe et s'enfuit ; et
# quand la Noire vient, celle qui n'est pas dans la lumière est à elle. En selle, la peur de sa monture jette à terre ; la
# torche aussi, sauf si sa lignée s'est faite au feu (ce que sa population a appris des joueurs : scripts/bete.gd, faite_au_feu).
# Le feu, lui, est leur abri : elles n'en ont pas peur. Tenue (en licol ou au piquet), une bête ne s'enfuit pas : ce qui
# l'effraie la fait tressaillir dans la lumière d'un feu, ou faire un écart au bout de sa longe (scripts/bete.gd, effrayer).
# La longe de filin (scripts/atelier.gd : la fibre longue de l'agave, du papyrus) ne rompt pas : nouée au piquet ou dans la
# main de la veilleuse, la bête que le noir affole s'y débat, s'épuise (elle a faim deux fois plus vite), mais reste. Le noir
# l'affole toujours ; laissée sans rien qui la tienne, elle fuit ; la Noire la prend comme une autre.
# Les choses posées de l'élevage (scripts/campement.gd les dessine), leur état :
#   appat     : « reste » (de 1 à 0 : ce qu'il en reste)
#   piquet    : « attache » (vrai : une bête y est liée)
#   mangeoire : « foin » (de 0 à 12 : les fibres qu'on y a mises)

const R := preload("res://scripts/regles.gd")
const Campement := preload("res://scripts/campement.gd")

const TEINTE := Color(0.86, 0.8, 0.66)
const GRIS := Color(0.75, 0.7, 0.66)
const ROUGE := Color(0.95, 0.5, 0.42)
const APPAT := 2                  # les baies d'un appât
const APPAT_DUREE := 14.0         # secondes : ce qu'une bête met à le manger
const PORTEE := 58.0              # à quelle distance on lui passe le licol, on la selle, on la monte
const MASSE_LICOL := 3.0          # en dessous (kilos), rien à quoi passer un licol
# (les bêtes des lieux sont petites : les plus lourdes de celles qui broutent font de 30 à 60 kilos)
const MASSE_SACOCHE := 8.0
const MASSE_SELLE := 25.0
const MASSE_LAIT := 15.0
const SACOCHE := 20               # ce qu'on porte de plus de chaque chose, la bête aux sacoches à ses côtés
const COTES := 150.0              # « à ses côtés »
const ALLURE := 1.6               # en selle, on va tant de fois plus vite
const TROUPEAU := 4               # ce qu'elle peut tenir de bêtes
const FAIM := 100.0 / (1.6 * 240.0)   # ce qu'une bête perd de faim par seconde : affamée en un jour et demi
const BROUTE := 100.0 / 60.0      # ce qu'elle reprend en broutant, de jour
const FOIN := 12                  # ce que tient une mangeoire
const FOIN_RASSASIE := 45.0       # ce qu'une fibre de la mangeoire rend de faim
const LAIT := 1.0 / 240.0         # son lait revient en un jour, nourrie
const NOIR := 22.0                # secondes dans le noir, la nuit, avant qu'elle ne rompe sa longe
const EFFROI := 130.0             # un chasseur à cette distance : la monture se cabre
const LAIT_FAIM := 24.0           # ce que rend le lait

var jeu
var betes: Array = []             # ses bêtes (des nœuds : scripts/bete.gd, rôle « compagne »)
var monture = null                # celle qu'elle monte
var _noir := {}                   # la bête → depuis combien de temps elle est dans le noir
var _affolee := {}                # la bête → le temps avant son prochain écart, affolée au bout de sa longe de filin
var _dit := {}
var _t := 0.0


func _atelier():
	return jeu.atelier


func _vivantes() -> Array:
	betes = betes.filter(func(b): return is_instance_valid(b) and float(b.pv) > 0.0 and str(b.role) == "compagne")
	return betes


# --- ce que la page du sac et « Agir » demandent ---

# la bête apprivoisée la plus proche, à portée de main (null : aucune)
func pres(portee: float = PORTEE):
	var mieux = null
	var d0 := portee
	for b in _vivantes():
		var d: float = b.position.distance_to(jeu.joueur.position) - float(b.largeur) * 0.25
		if d < d0:
			d0 = d
			mieux = b
	return mieux


# la proie à qui elle pourrait passer un licol, là, maintenant (null : aucune)
func a_apprivoiser():
	var j = jeu.joueur
	var mieux = null
	var d0 := PORTEE + 12.0
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		if str(b.role) != "proie" or float(b.pv) <= 0.0 or not apprivoisable(b):
			continue
		var d: float = b.position.distance_to(j.position) - float(b.largeur) * 0.25
		if d < d0 and (float(b.mange) > 0.6 or float(b.confiance) >= 0.8 or float(b.endormie) > 0.0):
			d0 = d
			mieux = b
	return mieux


# une bête à quatre pattes, assez grande pour un licol
static func apprivoisable(b) -> bool:
	var plan: Dictionary = b.lignee.get("plan", {})
	var corps = plan.get("corps", {})
	var forme := str(corps.get("forme", "")) if typeof(corps) == TYPE_DICTIONARY else ""
	return forme == "quadrupede" and float(b.masse) >= MASSE_LICOL


func empeche_appat() -> String:
	if int(jeu.joueur.inventaire.get("baies", 0)) < APPAT:
		return "Il te faut %d baies." % APPAT
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "appat" and s.position.distance_to(jeu.joueur.position) < 300.0:
			return "Il y a déjà un appât ici."
	return ""


# elle pose devant elle une poignée de baies : une bête qui broute viendra y manger, si elle se tient à l'écart
func poser_appat() -> bool:
	var pourquoi := empeche_appat()
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var A = _atelier()
	var inv: Dictionary = jeu.joueur.inventaire
	inv["baies"] = int(inv["baies"]) - APPAT
	A._creer("appat", A._devant("appat"), {"reste": 1.0})
	jeu.joueur.geste_atelier("fouiller")
	jeu.ui.message("Un appât. Écarte-toi, ne bouge plus : une bête viendra. La tête dedans, elle laisse venir." if A.possede("licol") > 0
		else "Un appât. Il te faudra un licol pour la bête qui viendra y manger.", TEINTE)
	return true


# elle lui passe le licol : la bête est à elle
func apprivoiser(b) -> bool:
	var A = _atelier()
	if b == null or not is_instance_valid(b) or str(b.role) != "proie" or not apprivoisable(b):
		return false
	if A.possede("licol") <= 0:
		jeu.ui.message("Il te faut un licol.", GRIS)
		return false
	if _vivantes().size() >= TROUPEAU:
		jeu.ui.message("Tu ne tiendrais pas une bête de plus.", GRIS)
		return false
	A.objets["licol"] = A.possede("licol") - 1
	b.role = "compagne"
	b.endormie = 0.0
	b.harnais = {"licol": true}
	b.suit_la = true
	b.faim = 80.0
	b.lait = 0.0
	b.etat = "repos"
	b._tentation = null
	b.crainte = 0.0
	b.confiance = 1.0
	betes.append(b)
	_aupres(b, "caresser")
	jeu.joueur.geste_atelier("caresser")
	jeu.sons.atelier("sangle", 0.0, 0.9)
	jeu.ui.message("%s : le licol passé, elle est à toi. Garde-la dans la lumière, la nuit." % str(b.nom), TEINTE)
	if jeu.has_method("bete_apprivoisee"):
		jeu.bete_apprivoisee(b)
	return true


# pour un geste sur sa bête, elle se met là où ses mains la touchent (scripts/joueur.gd, place_pour)
func _aupres(b, geste: String) -> void:
	var j = jeu.joueur
	var p: Vector2 = j.place_pour(geste, b)
	if p.distance_to(j.position) < 90.0:
		j.position = jeu.monde.repousser(p, 8.0)


# « suis-moi », « reste là » (près d'un piquet d'attache : elle y est liée)
func basculer_suite(b) -> void:
	if b == null:
		return
	b.suit_la = not bool(b.suit_la)
	if not b.suit_la:
		var piquet = _piquet_pres(b.position, 90.0)
		b.maison = piquet.position + Vector2(18.0, 10.0) if piquet != null else b.position
		jeu.ui.message("%s reste %s." % [str(b.nom), "au piquet" if piquet != null else "là"], TEINTE)
		jeu.sons.atelier("corde", -4.0, 1.1, b.position)
	else:
		jeu.ui.message("%s te suit." % str(b.nom), TEINTE)


func empeche_harnacher(b, quoi: String) -> String:
	if b == null:
		return "Aucune bête à toi n'est là."
	if bool(b.harnais.get(quoi, false)):
		return "Elle en porte déjà."
	if _atelier().possede(quoi) <= 0:
		return "Tu n'en as pas."
	# (une longe de filin se passe à toute bête qu'on a ; seuls la selle et les sacoches demandent une bête assez forte)
	if quoi == "longe":
		return ""
	if float(b.masse) < (MASSE_SELLE if quoi == "selle" else MASSE_SACOCHE):
		return "Elle est trop petite pour %s." % ("porter quelqu'un" if quoi == "selle" else "des sacoches")
	return ""


# elle lui met une selle, des sacoches
func harnacher(b, quoi: String) -> bool:
	var pourquoi := empeche_harnacher(b, quoi)
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var A = _atelier()
	A.objets[quoi] = A.possede(quoi) - 1
	b.harnais[quoi] = true
	if quoi == "longe":
		# (la longe de chanvre s'ôte, celle de filin se noue à l'anneau du licol : on l'entend se tendre)
		_aupres(b, "caresser")
		jeu.joueur.geste_atelier("caresser")
		jeu.sons.atelier("filin", -3.0, 1.0, b.position)
		jeu.ui.message("%s a sa longe de filin. Nouée au piquet ou dans ta main, le noir ne la fera plus partir ; il lui fera peur quand même." % str(b.nom), TEINTE)
		return true
	_aupres(b, "seller")
	jeu.joueur.geste_atelier("seller")
	jeu.sons.atelier("sangle", 0.0, 0.85)
	jeu.ui.message("%s porte %s." % [str(b.nom), "sa selle : « Agir » près d'elle, et tu la montes" if quoi == "selle" else "ses sacoches : à ses côtés, tu portes %d de plus de chaque chose" % SACOCHE], TEINTE)
	return true


# elle lui ôte tout, et la rend au lieu : son harnais retourne dans le sac
func liberer(b) -> bool:
	if b == null or not betes.has(b):
		return false
	if monture == b:
		descendre()
	var A = _atelier()
	for k in b.harnais:
		if bool(b.harnais[k]):
			A.objets[k] = A.possede(k) + 1
	_rendre(b)
	jeu.ui.message("%s retourne aux siens." % str(b.nom), TEINTE)
	return true


func _rendre(b) -> void:
	# (elle retourne aux siens : une libération, pour Orvane ; principal.gd, bete_rendue)
	if betes.has(b) and jeu.has_method("bete_rendue"):
		jeu.bete_rendue(b)
	betes.erase(b)
	_noir.erase(b)
	_affolee.erase(b)
	b.harnais = {}
	b.longe = null
	b.montee = false
	b.role = "proie"
	b.confiance = 0.6
	b.maison = b.position


func empeche_monter(b) -> String:
	if b == null:
		return "Aucune bête à toi n'est là."
	if not bool(b.harnais.get("selle", false)):
		return "Il lui faut une selle."
	# (la torche : seule une bête dont la lignée s'est faite au feu la souffre ; scripts/bete.gd, faite_au_feu)
	if float(jeu.joueur.torche) > 0.0 and not b.faite_au_feu():
		return "Pas la torche à la main : elle en a peur. Les siens ne se sont pas faits au feu."
	return _effroi(b)


func monter(b) -> bool:
	var pourquoi := empeche_monter(b)
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	monture = b
	b.montee = true
	b.suit_la = true
	b.longe = null
	jeu.joueur.position = b.position
	jeu.joueur.monture = b
	jeu.sons.atelier("sangle", -3.0, 1.1)
	jeu.ui.message("En selle, la torche haute : les siens se sont faits au feu. « Agir » pour descendre." if float(jeu.joueur.torche) > 0.0
		else "En selle. « Agir » pour descendre.", TEINTE)
	return true


func descendre(jetee: bool = false, devant: String = "") -> void:
	if monture == null:
		return
	var b = monture
	monture = null
	jeu.joueur.monture = null
	if is_instance_valid(b):
		b.montee = false
		jeu.joueur.position = jeu.monde.repousser(b.position + Vector2(float(jeu.joueur.regard) * -(20.0 + float(b.largeur) * 0.3), 8.0), 8.0)
		if jetee:
			b.effrayer(jeu.joueur.position, 4.0)
	if jetee:
		jeu.joueur.tomber_de_selle()
		jeu.joueur.sante = maxf(1.0, float(jeu.joueur.sante) - 6.0)
		jeu.joueur.peur = minf(100.0, float(jeu.joueur.peur) + 12.0)
		jeu.effets.secousse(0.5)
		jeu.ui.message("Elle se cabre%s : tu es à terre." % ((" devant " + devant) if devant != "" else ""), ROUGE)


# ce qui affole une bête, là où elle est ("" : rien)
func _effroi(b) -> String:
	if jeu.noire != null and jeu.noire.presente():
		return "Elle tremble : quelque chose vient."
	for c in jeu.get_tree().get_nodes_in_group("betes"):
		if str(c.role) in ["chasseur", "rodeur"] and float(c.pv) > 0.0 and c.position.distance_to(b.position) < EFFROI:
			return "Elle sent une bête, tout près : elle ne se laisse pas monter."
	return ""


func empeche_traire(b) -> String:
	if b == null:
		return "Aucune bête à toi n'est là."
	if float(b.masse) < MASSE_LAIT:
		return "Elle est trop petite pour donner du lait."
	if float(b.lait) < 1.0:
		return "Elle n'a pas de lait : il lui faut manger, et du temps."
	return ""


func traire(b) -> bool:
	var pourquoi := empeche_traire(b)
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	b.lait = 0.0
	var inv: Dictionary = jeu.joueur.inventaire
	inv["lait"] = int(inv.get("lait", 0)) + 1
	_aupres(b, "traire")
	jeu.joueur.geste_atelier("traire")
	jeu.sons.atelier("gourde", -4.0, 1.25)
	jeu.ui.message("Du lait, tiède.", TEINTE)
	return true


# elle boit son lait
func boire_lait() -> bool:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("lait", 0)) <= 0:
		return false
	inv["lait"] = int(inv["lait"]) - 1
	var j = jeu.joueur
	j.faim = minf(100.0, float(j.faim) + LAIT_FAIM)
	j.peur = maxf(0.0, float(j.peur) - 6.0)
	j.geste_atelier("boire")
	jeu.sons.atelier("gorgee")
	return true


# la mangeoire : elle y met ses fibres (quatre à la fois)
func garnir(s) -> void:
	var inv: Dictionary = jeu.joueur.inventaire
	var place := FOIN - int(s.etat.get("foin", 0))
	var n := mini(mini(4, place), int(inv.get("fibre", 0)))
	if n <= 0:
		jeu.ui.message("La mangeoire est pleine." if place <= 0 else "Il te faut des fibres pour la garnir.", GRIS)
		return
	inv["fibre"] = int(inv["fibre"]) - n
	s.etat["foin"] = int(s.etat.get("foin", 0)) + n
	jeu.joueur.geste_atelier("fouiller")
	jeu.sons.jouer("herbe", -5.0, 0.9)
	jeu.ui.message("La mangeoire : %d fibres." % int(s.etat["foin"]), TEINTE)


# « Agir » : ce qui touche à l'élevage, là où elle est ; vrai si c'est fait (et le jeu n'en fait rien d'autre)
func agir() -> bool:
	if monture != null:
		descendre()
		return true
	var sauvage = a_apprivoiser()
	if sauvage != null and _atelier().possede("licol") > 0:
		return apprivoiser(sauvage)
	# (tout contre elle : une bête qui suit se tient plus loin, et « Agir » reste à ce qu'on a devant soi)
	var b = pres(46.0)
	if b == null:
		return false
	if bool(b.harnais.get("selle", false)):
		monter(b)
	else:
		basculer_suite(b)
	return true


# --- ce que le jeu en lit ---

# ce qu'elle porte de plus : une bête aux sacoches, à ses côtés
func porte_en_plus() -> int:
	for b in _vivantes():
		if bool(b.harnais.get("sacoche", false)) and b.position.distance_to(jeu.joueur.position) < COTES:
			return SACOCHE
	return 0


# en selle : son allure
func allure() -> float:
	return ALLURE if monture != null else 1.0


# « Agir » ne frappe pas ses bêtes
func est_a_elle(b) -> bool:
	return betes.has(b)


# ce qui tente cette proie : un appât (null : rien)
func tentation(b):
	if not apprivoisable(b):
		return null
	var mieux = null
	var d0: float = float(b.flair) * 1.5
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "appat" and str(s.etat.get("sorte", "")) == "" and float(s.etat.get("reste", 0.0)) > 0.0:
			var d: float = s.position.distance_to(b.position)
			if d < d0:
				d0 = d
				mieux = s
	return mieux


# une bête mange l'appât
func mangee(s, delta: float) -> void:
	s.etat["reste"] = float(s.etat.get("reste", 1.0)) - delta / APPAT_DUREE
	if float(s.etat["reste"]) <= 0.0:
		_atelier().poses.erase(s)
		s.queue_free()


func _piquet_pres(p: Vector2, portee: float):
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "piquet" and s.position.distance_to(p) < portee:
			return s
	return null


func _mangeoire_pres(p: Vector2, portee: float):
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "mangeoire" and int(s.etat.get("foin", 0)) > 0 and s.position.distance_to(p) < portee:
			return s
	return null


# --- chaque image ---

func maj(delta: float) -> void:
	var j = jeu.joueur
	if j == null:
		return
	_t += delta
	var nuit: bool = jeu.jour_du_ciel() <= 0.0
	var noire: bool = jeu.noire != null and jeu.noire.presente()
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "piquet":
			s.etat["attache"] = false
	for b in _vivantes().duplicate():
		# sa longe : dans la main de la veilleuse, ou au piquet
		var piquet = null if bool(b.suit_la) else _piquet_pres(b.maison, 60.0)
		if piquet != null:
			piquet.etat["attache"] = true
			# (à l'anneau du piquet : scripts/campement.gd)
			b.longe = piquet.position + Campement.ANNEAU
		elif bool(b.suit_la) and not bool(b.montee) and b.position.distance_to(j.position) < 220.0:
			b.longe = j.position
		else:
			b.longe = null
		# la faim : elle broute le jour, laissée là ; à l'attache, la mangeoire
		b.faim = maxf(0.0, float(b.faim) - FAIM * delta)
		if not bool(b.suit_la) and float(b.mange) > 0.5 and not nuit:
			b.faim = minf(100.0, float(b.faim) + BROUTE * delta)
		if float(b.faim) < 50.0:
			var m = _mangeoire_pres(b.position, 130.0)
			if m != null:
				m.etat["foin"] = int(m.etat["foin"]) - 1
				b.faim = minf(100.0, float(b.faim) + FOIN_RASSASIE)
		if float(b.faim) > 40.0 and float(b.masse) >= MASSE_LAIT:
			b.lait = minf(1.0, float(b.lait) + LAIT * delta)
		# (sa longe de filin, nouée au piquet ou dans la main de la veilleuse : rien ne la rompt)
		var filin: bool = bool(b.harnais.get("longe", false))
		var tient: bool = filin and b.longe != null and not bool(b.montee)
		if float(b.faim) <= 0.0:
			_perdre(b, ("%s avait trop faim : elle a rongé sa longe de filin." if filin else "%s avait trop faim : elle a rompu sa longe.") % str(b.nom))
			continue
		# le noir, la nuit : elle prend peur
		var dans_le_noir: bool = nuit and float(jeu.eclairage(b.position)) < 0.25
		_noir[b] = (float(_noir.get(b, 0.0)) + delta) if dans_le_noir else maxf(0.0, float(_noir.get(b, 0.0)) - delta * 2.0)
		if noire and dans_le_noir and not bool(b.montee) and float(_noir[b]) > 4.0:
			_prendre(b)
			continue
		if float(_noir[b]) > NOIR and not bool(b.montee):
			if tient:
				_affoler(b, delta)
			else:
				_affolee.erase(b)
				_perdre(b, ("%s a pris peur dans le noir : rien ne la tenait, elle s'est enfuie." if filin else "%s a pris peur dans le noir : elle a rompu sa longe.") % str(b.nom))
				continue
		else:
			_affolee.erase(b)
		if dans_le_noir and float(_noir[b]) > NOIR * 0.5 and not _dit.has("noir"):
			_dit["noir"] = true
			jeu.ui.message(("%s tremble dans le noir. Sa longe de filin la tiendra ; ramène-la quand même près d'un feu." if tient
				else "%s tremble dans le noir. Ramène-la près d'un feu.") % str(b.nom), ROUGE)
	# en selle : elle va où va la veilleuse ; ce qui l'affole la jette à terre
	if monture != null:
		if not is_instance_valid(monture) or float(monture.pv) <= 0.0:
			monture = null
			j.monture = null
		else:
			monture.position = j.position
			monture.regard = j.regard
			monture.maison = j.position
			if _effroi(monture) != "":
				descendre(true)
			elif float(j.torche) > 0.0 and not monture.faite_au_feu():
				descendre(true, "la torche")


# affolée par le noir au bout de sa longe de filin : elle tire, fait un écart, se reprend, recommence ; le filin grince et
# tient. Elle s'y épuise : elle a faim plus vite. Ce que la veilleuse en voit et en entend ; elle ne la perd pas
func _affoler(b, delta: float) -> void:
	b.faim = maxf(0.0, float(b.faim) - FAIM * (R.LONGE_AFFOLEE - 1.0) * delta)
	var dans := float(_affolee.get(b, 0.0)) - delta
	if dans <= 0.0:
		dans = randf_range(2.6, 4.2)
		# (elle tire à l'opposé de ce qui la tient : la main de la veilleuse, l'anneau du piquet)
		var tient_la: Vector2 = Vector2(b.longe)
		b.effrayer(tient_la + (b.position - tient_la).normalized().rotated(randf_range(-0.6, 0.6)) * -40.0, 2.0)
		if b.position.distance_to(jeu.joueur.position) < 700.0:
			jeu.sons.atelier("filin", -6.0, randf_range(0.92, 1.05), b.position)
		if not _dit.has("filin-tient"):
			_dit["filin-tient"] = true
			jeu.ui.message("%s se débat au bout de sa longe de filin. Le filin tient." % str(b.nom), ROUGE)
	_affolee[b] = dans


# est-elle affolée au bout de sa longe de filin ? (le sac, l'essai)
func affolee(b) -> bool:
	return _affolee.has(b)


# elle s'enfuit : elle retourne au lieu, son harnais avec elle
func _perdre(b, dit: String) -> void:
	if monture == b:
		descendre(true)
	var ou: Vector2 = b.position
	_rendre(b)
	b.effrayer(jeu.joueur.position if jeu.joueur.position.distance_to(ou) > 4.0 else ou + Vector2(1.0, 0.0), 6.0)
	jeu.ui.message(dit, ROUGE)


# la Noire la prend : il n'en reste rien
func _prendre(b) -> void:
	var nom := str(b.nom)
	betes.erase(b)
	_noir.erase(b)
	_affolee.erase(b)
	jeu.sons.jouer("mord", -2.0, 0.7)
	jeu.sons.jouer("cri", -6.0, 0.8)
	b.remove_from_group("betes")
	b.queue_free()
	jeu.joueur.peur = minf(100.0, float(jeu.joueur.peur) + 25.0)
	jeu.ui.message("Dans le noir, %s crie, une fois. Puis plus rien." % nom, ROUGE)


# --- la partie gardée ---

func vider() -> void:
	betes.clear()
	monture = null
	_noir.clear()
	_affolee.clear()
	_dit.clear()


func photo() -> Dictionary:
	var la := []
	for b in _vivantes():
		# (ce que sa population a appris des joueurs, et son audace à elle : reprise, elle est la même bête)
		la.append({"e": {"lignee": b.lignee, "id": str(b.id), "masse": float(b.masse), "largeur": float(b.largeur),
			"memoire": b.memoire.duplicate(), "ecart": snappedf(float(b.ecart), 0.001)},
			"x": snappedf(b.position.x, 0.1), "y": snappedf(b.position.y, 0.1), "harnais": b.harnais.duplicate(), "suit": bool(b.suit_la),
			"faim": snappedf(float(b.faim), 0.1), "lait": snappedf(float(b.lait), 0.01), "maison": [snappedf(b.maison.x, 0.1), snappedf(b.maison.y, 0.1)]})
	return {"betes": la}


func reprendre(d: Dictionary) -> void:
	for x in d.get("betes", []):
		if typeof(x) != TYPE_DICTIONARY or typeof(x.get("e")) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = x["e"]
		# (une partie gardée avant qu'on y garde sa mémoire : celle de sa lignée, ici)
		if typeof(e.get("memoire")) != TYPE_DICTIONARY and typeof(e.get("lignee")) == TYPE_DICTIONARY and jeu.get("donnees") != null:
			e["memoire"] = jeu.donnees.memoire_de(e["lignee"], str(jeu.biome))
		var b = jeu._creer(e, "compagne", Vector2(float(x.get("x", 0.0)), float(x.get("y", 0.0))))
		b.harnais = x.get("harnais", {"licol": true})
		b.suit_la = bool(x.get("suit", true))
		b.faim = float(x.get("faim", 80.0))
		b.lait = float(x.get("lait", 0.0))
		b.confiance = 1.0
		var m = x.get("maison", [])
		if typeof(m) == TYPE_ARRAY and m.size() == 2:
			b.maison = Vector2(float(m[0]), float(m[1]))
		betes.append(b)
