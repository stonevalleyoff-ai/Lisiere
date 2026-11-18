extends RefCounted
# Lisière — l'atelier (scripts/atelier.gd)
# Ce que la veilleuse fabrique, porte, pose et dont elle se sert, au-delà du feu, de la torche et de la lance. Tout part d'un
# établi, qu'elle monte de ses mains ; le reste s'y fabrique (la page de l'établi : scripts/interface_atelier.gd).
#  - des matières : la corde et la bâche, tirées des fibres ; la peau, que donne la chasse ; la ferraille, qu'on trouve dans
#    les vestiges d'autres veilleuses ; l'eau, que la pluie laisse dans le récupérateur ; et le filin, commis de la fibre longue
#    que donnent l'agave et le papyrus (scripts/flore.gd) : il ne cède pas où la corde casse (le grand filet, la longe de filin,
#    le pont lié : principal.gd) ;
#  - un camp, qui se pose dans le lieu et se replie (scripts/campement.gd les dessine) : l'établi, la tente, le hamac, le
#    récupérateur d'eau, le filet, le cerf-volant ;
#  - une tenue, qui se porte et se voit sur elle (scripts/veilleuse_corps.gd) : le sac à dos, la pelisse, la cape de pluie ;
#  - des outils : la gourde, la popote, le duvet, la lampe et ses piles ; la carte, la plume et l'encre (scripts/reperes.gd).
# Ici : la liste (OBJETS), ce qu'elle possède, et ce que chaque chose change au jeu. Ce que les autres scripts en lisent :
# principal.gd (le froid, la pluie, l'abri, ce qu'elle peut porter, la cuisine, « Agir » sur une chose posée, le sommeil),
# joueur.gd (sa tenue, sa lampe, ses gestes), les sons, la partie gardée.

const R := preload("res://scripts/regles.gd")
const Campement := preload("res://scripts/campement.gd")
const Faim := preload("res://scripts/noire_faim.gd")

# les matières, dans l'ordre où on les montre ; celles du début sont dans le sac depuis toujours (regles.gd, NOMS)
const MATIERES := ["bois", "pierre", "fibre", "peau", "ferraille", "corde", "bache", "eau", "galet",
	# (ce que seuls certains pays donnent : le volcan, le marais ; scripts/biomes.gd)
	"obsidienne", "tourbe",
	# (la fibre longue de l'agave et du papyrus, qui ne pousse qu'au chaud ; le filin qu'on en commet)
	"fibre_longue", "filin"]
const NOMS_MATIERES := {"bois": "bois", "pierre": "pierre", "fibre": "fibres", "peau": "peau", "ferraille": "ferraille",
	"corde": "corde", "bache": "bâche", "eau": "eau", "galet": "galets", "obsidienne": "obsidienne", "tourbe": "tourbe",
	"fibre_longue": "fibres longues", "filin": "filin"}
# les familles, dans l'ordre de la page de l'établi : [la clé, son titre]
const FAMILLES := [["matiere", "Les matières"], ["camp", "Le camp"], ["tenue", "La tenue"], ["outil", "Les outils"],
	["jardin", "Le jardin"], ["elevage", "L'élevage"]]
# chaque chose : son nom, sa famille, ce qu'elle coûte, où elle se fait (« main » : n'importe où ; « etabli » : à portée d'un
# établi), ce qu'on en dit (une phrase : à quoi elle sert). « pose » : elle se pose dans le lieu ; « porte » : elle se porte.
const OBJETS := {
	"corde": {"nom": "Corde", "famille": "matiere", "ou": "etabli", "cout": {"fibre": 3},
		"dit": "Trois brins de fibres, tressés. Il en faut partout."},
	"bache": {"nom": "Bâche", "famille": "matiere", "ou": "etabli", "cout": {"fibre": 6},
		"dit": "Une toile serrée, enduite. Elle arrête la pluie et le vent."},
	# (« lot » : ce qu'un ouvrage en donne d'un coup)
	"galet": {"nom": "Galets", "famille": "matiere", "ou": "etabli", "lot": 4, "cout": {"pierre": 1},
		"dit": "Une pierre cassée, ses éclats roulés : quatre galets, pour le lance-pierre."},
	# (la fibre longue de l'agave, du papyrus : commise en trois torons, elle tient ce qu'une corde de fibres ne tient pas)
	"filin": {"nom": "Filin", "famille": "matiere", "ou": "etabli", "cout": {"fibre_longue": 3},
		"dit": "Trois torons de fibre longue, commis serré. Il ne cède pas où la corde casse."},
	"etabli": {"nom": "Établi", "famille": "camp", "ou": "main", "pose": true, "cout": {"bois": 6, "pierre": 2, "fibre": 2},
		"dit": "Un billot, un plateau, des outils de pierre. Tout le reste s'y fabrique."},
	"tente": {"nom": "Tente", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"bache": 2, "corde": 2, "bois": 4},
		"dit": "Un abri : ni pluie, ni vent, moins de froid. On y dort."},
	"hamac": {"nom": "Hamac", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"corde": 3, "bache": 1},
		"dit": "Il se tend près d'un arbre. On y dort au sec, loin du sol."},
	"recuperateur": {"nom": "Récupérateur d'eau", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"bache": 1, "bois": 3, "corde": 1},
		"dit": "Sous la pluie il se remplit. On y remplit sa gourde."},
	"filet": {"nom": "Filet", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"corde": 3, "pierre": 2},
		"dit": "Tendu au sol : une petite bête qui passe s'y prend."},
	"filet_filin": {"nom": "Grand filet", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"filin": 3, "pierre": 4},
		"dit": "Une large maille de filin, lestée de grosses pierres : une bête jusqu'à 30 kilos s'y prend, et n'en sort pas."},
	# (la fin de la Noire : scripts/noire_collet.gd. Il se pose de jour, s'amorce de viande crue, et ne sert qu'une fois)
	"collet": {"nom": "Grand collet", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"filin": 4, "bois": 4, "pierre": 4},
		"dit": "Un nœud coulant de filin, large comme un buste, couché en rond entre ses pieux. Amorcé de viande crue, il n'est fait que pour une bête."},
	"cerf_volant": {"nom": "Cerf-volant", "famille": "camp", "ou": "etabli", "pose": true, "cout": {"bache": 1, "bois": 2, "corde": 2, "ferraille": 1},
		"dit": "Par grand vent il recharge les piles. Sous l'orage, il appelle la foudre."},
	"sac_a_dos": {"nom": "Sac à dos", "famille": "tenue", "ou": "etabli", "porte": true, "cout": {"peau": 2, "corde": 1},
		"dit": "On porte deux fois plus de chaque chose."},
	"vetement_chaud": {"nom": "Pelisse", "famille": "tenue", "ou": "etabli", "porte": true, "cout": {"peau": 3, "fibre": 2},
		"dit": "Doublée de fourrure. Le froid mord moitié moins ; la chaleur pèse davantage."},
	"vetement_pluie": {"nom": "Cape de pluie", "famille": "tenue", "ou": "etabli", "porte": true, "cout": {"bache": 1, "corde": 1},
		"dit": "Cirée, à capuchon. La pluie ne trempe presque plus."},
	"gourde": {"nom": "Gourde", "famille": "outil", "ou": "etabli", "cout": {"peau": 1, "corde": 1},
		"dit": "Cinq gorgées d'eau, prises au récupérateur."},
	"popote": {"nom": "Popote", "famille": "outil", "ou": "etabli", "cout": {"pierre": 3, "ferraille": 1},
		"dit": "Sur un feu, avec de l'eau : un bouillon, qui nourrit et réchauffe mieux que la viande grillée."},
	"duvet": {"nom": "Duvet", "famille": "outil", "ou": "etabli", "cout": {"peau": 2, "fibre": 4},
		"dit": "On dort n'importe où, sans prendre froid."},
	"lampe": {"nom": "Lampe", "famille": "outil", "ou": "etabli", "porte": true, "cout": {"ferraille": 2, "corde": 1},
		"dit": "Un faisceau, loin devant soi. Il lui faut des piles chargées."},
	"piles": {"nom": "Piles", "famille": "outil", "ou": "etabli", "cout": {"ferraille": 2},
		"dit": "Vides quand on les fait. Le cerf-volant les charge."},
	"mortier": {"nom": "Mortier", "famille": "outil", "ou": "etabli", "unique": true, "cout": {"pierre": 3, "bois": 1},
		"dit": "Une pierre creuse et son pilon : on y broie les herbes qu'on a reconnues (l'herbier, dans ton sac)."},
	"lance_pierre": {"nom": "Lance-pierre", "famille": "outil", "ou": "etabli", "unique": true, "cout": {"bois": 1, "corde": 1, "peau": 1},
		"dit": "Une fourche, un boyau, une poche de cuir. Il porte loin, même vers des yeux dans le noir. Il lui faut des galets."},
	# la carte et ce qu'on y écrit (scripts/reperes.gd)
	"carte": {"nom": "Carte", "famille": "outil", "ou": "etabli", "unique": true, "cout": {"peau": 1, "corde": 1},
		"dit": "Une peau grattée, roulée sur sa corde. Ce que tu as parcouru s'y dessine : tu la lis à la pause."},
	"plume": {"nom": "Plume et encre", "famille": "outil", "ou": "etabli", "unique": true, "cout": {"fibre": 1, "baies": 2, "pierre": 1},
		"dit": "Une plume taillée dans un roseau, une encre de baies écrasées dans un godet de pierre. Sur ta carte, tu écris ce que tu veux retrouver."},
	# le jardin (scripts/jardin.gd)
	"houe": {"nom": "Houe", "famille": "jardin", "ou": "etabli", "unique": true, "cout": {"bois": 2, "pierre": 1, "corde": 1},
		"dit": "Elle retourne la terre : un carré de jardin, où l'on sème."},
	"arrosoir": {"nom": "Arrosoir", "famille": "jardin", "ou": "etabli", "unique": true, "cout": {"peau": 1, "bois": 1, "corde": 1},
		"dit": "Une outre à bec : quatre arrosages. Il se remplit au récupérateur, ou les pieds dans l'eau."},
	"epouvantail": {"nom": "Épouvantail", "famille": "jardin", "ou": "etabli", "pose": true, "cout": {"bois": 3, "fibre": 4, "bache": 1},
		"dit": "Les bêtes qui broutent n'approchent pas du jardin qu'il garde. La nuit, il regarde d'où vient ce qui vient."},
	# l'élevage (scripts/elevage.gd)
	"licol": {"nom": "Licol", "famille": "elevage", "ou": "etabli", "cout": {"corde": 2, "peau": 1},
		"dit": "Passé au cou d'une bête qui mange dans ta main, il en fait la tienne."},
	# (scripts/elevage.gd : la longe de filin se passe à une bête qu'on a déjà, depuis le sac ; le noir l'affole toujours)
	"longe": {"nom": "Longe de filin", "famille": "elevage", "ou": "etabli", "cout": {"filin": 2},
		"dit": "Une longe qui ne rompt pas. Nouée au piquet ou dans ta main, ta bête affolée par le noir s'y débat, mais elle reste."},
	"piquet": {"nom": "Piquet d'attache", "famille": "elevage", "ou": "etabli", "pose": true, "cout": {"bois": 2, "corde": 1},
		"dit": "Une bête qu'on y laisse y reste, et broute autour. Près d'un feu, la nuit : le noir les rend folles."},
	"mangeoire": {"nom": "Mangeoire", "famille": "elevage", "ou": "etabli", "pose": true, "cout": {"bois": 4, "corde": 1},
		"dit": "On y met des fibres : les bêtes à l'attache s'y nourrissent, et donnent leur lait."},
	"sacoche": {"nom": "Sacoches", "famille": "elevage", "ou": "etabli", "cout": {"peau": 2, "corde": 2},
		"dit": "Sur le dos d'une bête : à ses côtés, tu portes vingt de plus de chaque chose."},
	"selle": {"nom": "Selle", "famille": "elevage", "ou": "etabli", "cout": {"peau": 3, "corde": 2, "bois": 1},
		"dit": "Sur une bête assez forte, on la monte : on va bien plus vite. Elle te jette à terre quand elle a peur."},
	# le volcan (scripts/biomes.gd) : son obsidienne est la seule pointe qu'on sache encore tailler ; la lance est aussitôt dans
	# ses mains (fabriquer), elle ne se range pas
	"lance_obsidienne": {"nom": "Lance d'obsidienne", "famille": "outil", "ou": "etabli", "cout": {"obsidienne": 2, "bois": 2, "corde": 1},
		"dit": "Une pointe de verre noir, ligaturée sur une hampe. Elle frappe comme une lance ferrée."},
}
const ORDRE := ["corde", "bache", "galet", "filin", "etabli", "tente", "hamac", "recuperateur", "filet", "filet_filin", "collet", "cerf_volant", "sac_a_dos",
	"vetement_chaud", "vetement_pluie", "gourde", "popote", "duvet", "lampe", "piles", "mortier", "lance_pierre", "carte", "plume", "houe", "arrosoir",
	"epouvantail", "licol", "longe", "piquet", "mangeoire", "sacoche", "selle", "lance_obsidienne"]
const GESTES := ["marteler", "scier", "coudre", "monter", "fouiller", "boire", "remuer", "becher", "semer", "arroser", "caresser", "seller", "traire"]
const TEINTE := Color(0.86, 0.8, 0.66)
const PORTEE := 54.0              # à quelle distance on se sert d'une chose posée, d'un établi
const PORTER := 20                # ce qu'elle porte de chaque matière, sans sac à dos
const PORTER_SAC := 40
const GORGEES := 5                # ce que tient la gourde
const CITERNE := 6.0              # ce que tient le récupérateur
const REMPLIR := 0.085            # ce qu'une pluie battante y verse par seconde (une gorgée en douze secondes)
const LAMPE := 1.1                # ce que la lampe prend aux piles par seconde (sur 100)
const RAYON_LAMPE := 330.0
const VENT_MIN := 0.3             # le vent qu'il faut au cerf-volant
const CHARGER := 1.6              # ce qu'il rend aux piles par seconde, par grand vent
const PRISE_MAX := 8.0            # la plus grosse bête qu'un filet retient (kilos ; le grand filet, de filin : R.FILET_FILIN)
const SOMMEIL := 6.0              # le temps passe tant de fois plus vite quand elle dort
const MIJOTE := 16.0              # secondes : la popote reste sur le feu, après qu'elle y a cuit
const OUVRAGE := 1.5              # secondes : les copeaux volent de l'établi, après qu'elle y a fabriqué

var jeu
var objets := {}                  # ce qu'elle possède, plié dans son sac : l'id → combien
var portes := {}                  # ce qu'elle porte, ou qui est allumé : l'id → vrai
var poses: Array = []             # ce qui est posé dans le lieu (des nœuds : scripts/campement.gd)
var charge := 0.0                 # les piles, de 0 à 100
var fil = null                    # le cerf-volant où les piles sont branchées (null : elle les a sur elle)
var endormie := false
var lit = null                    # là où elle dort (une tente, un hamac ; null : dans son duvet, à même le sol)
var lit_de_nuit := false          # elle s'est couchée de nuit (elle se réveillera à l'aube ; de jour : au soir)
var _dit := {}
var _t := 0.0
var _avant := 1.0                 # l'allure du temps avant qu'elle s'endorme (l'essai joue en accéléré)
var vent_force := -1.0            # (l'essai) le vent qu'on lui donne, à la place de celui du lieu (-1 : celui du lieu)


# --- ce que la page de l'établi et celle du sac demandent ---

# combien elle en a : une matière (dans son sac ; les baies aussi, que l'encre demande), ou une chose (pliée, portée)
func possede(id: String) -> int:
	if MATIERES.has(id) or id == "baies":
		return int(jeu.joueur.inventaire.get(id, 0))
	return int(objets.get(id, 0))


func porte(id: String) -> bool:
	return bool(portes.get(id, false))


# ce qu'elle peut porter de chaque matière
func capacite() -> int:
	var plus: int = int(jeu.elevage.porte_en_plus()) if jeu.get("elevage") != null else 0
	return (PORTER_SAC if porte("sac_a_dos") else PORTER) + plus


func pres_d_un_etabli() -> bool:
	return _proche("etabli", PORTEE * 1.3) != null


# ce qui manque pour la fabriquer : [[matière, combien], …] ; vide : elle a tout
func manque(id: String) -> Array:
	var out := []
	var cout: Dictionary = OBJETS[id]["cout"]
	for k in cout:
		var m := int(cout[k]) - possede(k)
		if m > 0:
			out.append([k, m])
	return out


# peut-elle la fabriquer, là, maintenant ? ("" : oui ; sinon, pourquoi pas, en une phrase)
func empeche(id: String) -> String:
	var o: Dictionary = OBJETS[id]
	if str(o["ou"]) == "etabli" and not pres_d_un_etabli():
		return "Il faut un établi, tout près."
	var m := manque(id)
	if not m.is_empty():
		var dits := PackedStringArray()
		for x in m:
			dits.append("%d %s" % [int(x[1]), str(NOMS_MATIERES.get(x[0], x[0]))])
		return "Il te manque %s." % ", ".join(dits)
	if id == "piles" and possede("piles") > 0:
		return "Tu as déjà des piles."
	if (bool(o.get("porte", false)) or bool(o.get("unique", false)) or id in ["gourde", "popote", "duvet"]) and possede(id) > 0:
		return "Tu en as déjà."
	if MATIERES.has(id) and possede(id) >= capacite():
		return "Tu n'en porterais pas davantage."
	return ""


func peut(id: String) -> bool:
	return empeche(id) == ""


# elle la fabrique : les matières partent, la chose est là (une tenue se met aussitôt) ; faux si elle ne peut pas
func fabriquer(id: String) -> bool:
	var pourquoi := empeche(id)
	if pourquoi != "":
		jeu.ui.message("%s : %s" % [str(OBJETS[id]["nom"]), pourquoi.to_lower()], Color(0.75, 0.7, 0.66))
		return false
	var o: Dictionary = OBJETS[id]
	var inv: Dictionary = jeu.joueur.inventaire
	for k in o["cout"]:
		inv[k] = int(inv.get(k, 0)) - int(o["cout"][k])
	if MATIERES.has(id):
		inv[id] = int(inv.get(id, 0)) + int(o.get("lot", 1))
	elif id == "lance_obsidienne":
		# (une lance : dans ses mains, toute neuve, à la place de celle qu'elle avait)
		jeu.joueur.lance = R.USURE_LANCE
	else:
		objets[id] = int(objets.get(id, 0)) + 1
		if bool(o.get("porte", false)) and id != "lampe":
			portes[id] = true
	# (son geste, et ce qu'on entend : les fibres qu'on tresse, la toile, l'alêne et le fil ; le bois se scie ; le reste se
	# martèle, et chaque coup de maillet sonne quand il tombe : coup())
	var cousu: bool = str(o["famille"]) == "tenue" or id in ["corde", "bache", "duvet", "gourde", "hamac", "filet", "licol", "sacoche", "selle", "arrosoir", "carte",
		"filin", "filet_filin", "longe", "collet"]
	var scie: bool = not cousu and o["cout"].has("bois")
	jeu.joueur.geste_atelier("coudre" if cousu else ("scier" if scie else "marteler"))
	if id in ["filin", "filet_filin", "longe", "collet"]:
		# (la fibre longue se commet en torons, puis le filin se tend, raide, et grince : on l'entend tenir)
		jeu.sons.atelier("tresse", 0.0, 0.86)
		jeu.sons.atelier("filin", -2.0)
	elif id == "corde" or id == "filet":
		jeu.sons.atelier("tresse")
	elif id == "bache":
		jeu.sons.atelier("toile", -3.0)
	elif cousu:
		jeu.sons.atelier("couture")
	elif scie:
		jeu.sons.atelier("scie")
	# (à l'établi : des copeaux en volent, le temps de l'ouvrage)
	var e = _proche("etabli", PORTEE * 1.3)
	if e != null:
		e.etat["travail"] = 1.0
	jeu.ui.message("%s. %s" % [str(o["nom"]), str(o["dit"])], TEINTE)
	_tenue()
	return true


# une tenue qu'on met ou qu'on ôte ; la lampe qu'on allume ou qu'on éteint
func basculer(id: String) -> void:
	if possede(id) <= 0 or not bool(OBJETS[id].get("porte", false)):
		return
	if id == "lampe":
		if not porte("lampe"):
			if possede("piles") <= 0 or fil != null:
				jeu.ui.message("La lampe n'a pas ses piles.", Color(0.75, 0.7, 0.66))
				return
			if charge <= 0.5:
				jeu.ui.message("Les piles sont vides. Le cerf-volant les charge, par grand vent.", Color(0.75, 0.7, 0.66))
				return
		portes["lampe"] = not porte("lampe")
		jeu.sons.atelier("clic", 0.0, 1.0 if porte("lampe") else 0.86)
	else:
		portes[id] = not porte(id)
		jeu.sons.atelier("sangle")
	_tenue()


# où elle la poserait : devant elle, là où il y a la place (le hamac : à côté de son arbre, en avant de lui, que sa couronne
# ne le cache pas)
func _devant(id: String = "") -> Vector2:
	var j = jeu.joueur
	var r := maxf(16.0, Campement.rayon(id))
	var p: Vector2 = j.position + Vector2(float(j.regard) * (30.0 + r), 6.0)
	if id == "hamac":
		var a = _l_arbre(p, 90.0)
		if a != null:
			var cote := 1.0 if j.position.x >= a.position.x else -1.0
			p = a.position + Vector2(cote * 58.0, 12.0)
	return jeu.monde.repousser(p, r)


# ce qui l'empêche de la poser là ("" : rien) ; la page du sac éteint son bouton et le dit
func empeche_poser(id: String) -> String:
	if possede(id) <= 0 or not bool(OBJETS[id].get("pose", false)):
		return "Tu n'en as pas."
	var p := _devant(id)
	if float(jeu.climat.eau(p)) > 0.2:
		return "Le sol est sous l'eau : rien ne s'y pose."
	if id == "hamac" and not _un_arbre(p, 90.0):
		return "Un hamac se tend près d'un arbre."
	# (le grand collet : de jour seulement ; scripts/noire_collet.gd)
	if id == "collet" and jeu.noire != null and jeu.noire.collet.empeche_poser() != "":
		return jeu.noire.collet.empeche_poser()
	# (ni sur un buisson, ni sur un feu)
	var r := Campement.rayon(id)
	for o in jeu.monde.autour(p, r + 14.0):
		if str(o.genre) == "buisson":
			return "Un buisson gêne : il n'y a pas la place ici."
	for f in jeu.feux:
		if is_instance_valid(f) and f.position.distance_to(p) < r + 26.0:
			return "Trop près du feu."
	return ""


# ce qui l'empêche de dormir dans son duvet ("" : rien)
func empeche_dormir() -> String:
	if endormie:
		return "Tu dors déjà."
	if possede("duvet") <= 0:
		return "Sans duvet, on ne dort pas à même le sol."
	return _danger()


# elle pose devant elle une chose du camp ; faux si elle ne peut pas (et le jeu dit pourquoi)
func poser(id: String) -> bool:
	var pourquoi := empeche_poser(id)
	if pourquoi != "":
		if possede(id) > 0:
			jeu.ui.message(pourquoi, Color(0.75, 0.7, 0.66))
		return false
	var j = jeu.joueur
	var p := _devant(id)
	objets[id] = possede(id) - 1
	# (elle dégage le sol : les brindilles, les touffes qui passeraient au travers)
	for o in jeu.monde.autour(p, maxf(14.0, Campement.rayon(id)) + 4.0):
		if float(o.rayon) <= 0.0 and str(o.genre) in ["brindille", "touffe", "fleur", "cepe", "amanite", "aquatique"]:
			jeu.monde.retirer(o)
	var posee = _creer(id, p, {})
	# (le grand collet : il garde l'odeur de la main qui le pose, sauf si elle sent les aromates ; scripts/noire_collet.gd)
	if id == "collet" and jeu.noire != null:
		jeu.noire.collet.pose(posee)
	j.geste_atelier("monter")
	_son_de_pose(id, p)
	return true


# elle replie la chose posée la plus proche, et la reprend dans son sac
func replier() -> bool:
	var s = _la_plus_proche(PORTEE)
	if s == null or str(s.genre) in ["vestige", "appat", "coffre", "couche"]:
		return false
	# (le grand collet : entier, il revient dans le sac avec sa viande ; rompu, il ne rend que ses pieux et ses pierres)
	if str(s.genre) == "collet" and jeu.noire != null:
		return jeu.noire.collet.replier(s)
	if str(s.genre) == "carre":
		# (un carré se comble : la terre reprend sa place, ce qui y poussait est perdu)
		poses.erase(s)
		s.queue_free()
		jeu.joueur.geste_atelier("fouiller")
		return true
	# (la faim de la Noire : une épave ne revient pas dans le sac ; elle en sauve la moitié des matières)
	if Faim.est_epave(s):
		return _replier_epave(s)
	if fil == s:
		fil = null
	if lit == s:
		reveiller("")
	objets[str(s.genre)] = possede(str(s.genre)) + 1
	poses.erase(s)
	jeu.sons.atelier("corde" if str(s.genre) in ["hamac", "filet", "filet_filin", "etabli"] else "toile", -2.0, 1.0, s.position)
	s.queue_free()
	jeu.joueur.geste_atelier("monter")
	return true


# --- les épaves : ce que la Noire a mis en pièces, à son cinquième acte (scripts/noire_faim.gd ; scripts/campement_epave.gd
# les dessine). Une épave vaut la moitié de la chose (regles.gd, NOIRE_EPAVE) : on la répare sur place pour l'autre moitié de
# chaque matière (« Agir »), ou on la replie pour ce qui s'en sauve ---

# ce que coûte de réparer cette chose, ce qu'on en sauve en la repliant (la matière → combien)
func cout_reparation(id: String) -> Dictionary:
	return Faim.cout_reparation(OBJETS[id]["cout"])


func restes(id: String) -> Dictionary:
	return Faim.restes(OBJETS[id]["cout"])


# un prix, dit : « 1 bâche, 1 corde, 2 bois »
func dire_cout(cout: Dictionary) -> String:
	var dits := PackedStringArray()
	for k in cout:
		dits.append("%d %s" % [int(cout[k]), str(NOMS_MATIERES.get(k, k))])
	return ", ".join(dits)


# ce qui lui manque pour réparer cette épave ("" : rien)
func empeche_reparer(s) -> String:
	var manque_ := {}
	var cout := cout_reparation(str(s.genre))
	for k in cout:
		if int(cout[k]) > possede(k):
			manque_[k] = int(cout[k]) - possede(k)
	return "" if manque_.is_empty() else "Il te manque %s." % dire_cout(manque_)


# elle répare sur place ce que la Noire a mis en pièces : les matières partent, la chose est debout, comme neuve (vide : son
# eau, sa prise, son foin sont perdus) ; faux si elle n'a pas de quoi (et le jeu dit ce qu'il faut)
func reparer(s) -> bool:
	if not Faim.est_epave(s) or not OBJETS.has(str(s.genre)):
		return false
	var id := str(s.genre)
	var nom := str(Faim.CHOSES[id][0])
	var cout := cout_reparation(id)
	var pourquoi := empeche_reparer(s)
	if pourquoi != "":
		jeu.ui.message("Pour réparer %s : %s. %s Repliée, l'épave rend %s." % [nom, dire_cout(cout), pourquoi, dire_cout(restes(id)) if not restes(id).is_empty() else "peu de chose"],
			Color(0.75, 0.7, 0.66))
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	for k in cout:
		inv[k] = int(inv.get(k, 0)) - int(cout[k])
	for k in ["saccage", "cote", "mangee", "mordu", "nuit"]:
		s.etat.erase(k)
	s.redessiner(true)
	# (elle recoud la toile, renoue les cordes ; le bois se replante au maillet : coup(), « monter »)
	jeu.joueur.geste_atelier("monter")
	jeu.sons.atelier("couture" if cout.has("bache") or cout.has("corde") or cout.has("filin") else "corde", -1.0, 1.0, s.position)
	jeu.ui.message("Tu répares %s : %s." % [nom, dire_cout(cout)], TEINTE)
	return true


# elle replie une épave : ce qui s'en sauve entre dans son sac, le reste est perdu
func _replier_epave(s) -> bool:
	var id := str(s.genre)
	var sauve := restes(id)
	var pris := {}
	for k in sauve:
		var n := ranger(k, int(sauve[k]))
		if n > 0:
			pris[k] = n
	if fil == s:
		fil = null
	poses.erase(s)
	jeu.sons.atelier("toile", -4.0, 0.9, s.position)
	s.queue_free()
	jeu.joueur.geste_atelier("fouiller")
	jeu.ui.message("Tu replies ce qui reste de %s : %s." % [str(Faim.CHOSES[id][0]), dire_cout(pris) if not pris.is_empty() else "rien qui vaille"], TEINTE)
	return true


# ce qu'on entend quand elle monte une chose : la corde qu'on tend, la toile qu'on déplie (le piquet qu'on enfonce sonne
# quand son geste frappe : coup())
func _son_de_pose(id: String, p: Vector2) -> void:
	match id:
		"hamac", "filet":
			jeu.sons.atelier("corde", 0.0, 1.0, p)
		"filet_filin", "collet":
			jeu.sons.atelier("filin", 0.0, 1.0, p)
		"etabli":
			pass
		_:
			jeu.sons.atelier("toile", 0.0, 1.0, p)


# un geste d'atelier frappe (le signal « impact » de la veilleuse, scripts/joueur.gd) : le maillet tombe sur l'établi, des
# copeaux en sautent ; le piquet s'enfonce
func coup(geste: String, p: Vector2) -> void:
	match geste:
		"marteler":
			jeu.sons.atelier("marteau", 0.0, 1.0, p)
			var e = _proche("etabli", PORTEE * 1.3)
			if e != null:
				e.coup(1.0)
		"monter":
			jeu.sons.atelier("piquet", 0.0, 1.0, p)
		"becher":
			# (la houe entre dans la terre)
			jeu.sons.jouer("pierre", -10.0, 0.62)
			jeu.sons.jouer("herbe", -6.0, 0.8)


# une gorgée (la canicule pèse moins), et elle le dit
func boire() -> bool:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("eau", 0)) <= 0:
		jeu.ui.message("La gourde est vide.", Color(0.75, 0.7, 0.66))
		return false
	inv["eau"] = int(inv["eau"]) - 1
	jeu.joueur.temperature = move_toward(float(jeu.joueur.temperature), 50.0, 9.0)
	jeu.joueur.faim = minf(100.0, float(jeu.joueur.faim) + 2.0)
	jeu.joueur.geste_atelier("boire")
	jeu.sons.atelier("gorgee")
	jeu.ui.message("Une gorgée d'eau.", TEINTE)
	return true


# --- ce que le jeu en lit ---

# le froid mord moins sous la pelisse (et la chaleur pèse plus) ; un duvet tient chaud à qui dort
func froid_k() -> float:
	return (0.5 if porte("vetement_chaud") else 1.0) * (0.25 if endormie and possede("duvet") > 0 else 1.0)


func chaud_k() -> float:
	return 1.35 if porte("vetement_chaud") else 1.0


# ce que la pluie trempe encore
func pluie_k() -> float:
	return 0.15 if porte("vetement_pluie") else 1.0


# l'abri d'une tente, à cet endroit (de 0 à 1)
func abri(p: Vector2) -> float:
	for s in poses:
		if is_instance_valid(s) and str(s.genre) == "tente" and s.position.distance_to(p) < 40.0 and not Faim.est_epave(s):
			return 1.0
	return 0.0


# sa lampe éclaire-t-elle ce point ? (de 0 à 1 : un faisceau, devant elle)
func eclaire(p: Vector2) -> float:
	if not porte("lampe"):
		return 0.0
	var j = jeu.joueur
	var d: Vector2 = p - j.position
	var l := d.length()
	if l > RAYON_LAMPE or l < 1.0:
		return 1.0 if l < 1.0 else 0.0
	var dans := d.normalized().dot(Vector2(float(j.regard), 0.0))
	return clampf((dans - 0.72) / 0.14, 0.0, 1.0) * clampf((RAYON_LAMPE - l) / (RAYON_LAMPE * 0.3), 0.0, 1.0)


# la chasse donne aussi des peaux
func peaux_de(masse: float) -> int:
	return clampi(int(round(pow(masse, 0.35) * 0.75)), 1, 4)


# ce qu'elle ramasse entre dans son sac, jusqu'à ce qu'il soit plein : ce qui y entre vraiment
func ranger(k: String, n: int) -> int:
	var inv: Dictionary = jeu.joueur.inventaire
	var place := maxi(0, capacite() - int(inv.get(k, 0))) if MATIERES.has(k) else n
	var pris := mini(n, place)
	inv[k] = int(inv.get(k, 0)) + pris
	if pris < n and not _dit.has("plein-" + k):
		_dit["plein-" + k] = true
		jeu.ui.message("Tu ne portes pas plus de %s%s." % [str(NOMS_MATIERES.get(k, k)), "" if porte("sac_a_dos") else " : il te faudrait un sac à dos"], Color(0.75, 0.7, 0.66))
	return pris


# « Agir », près d'une chose posée : vrai si elle s'en est servie (et le jeu n'en fait rien d'autre)
func agir() -> bool:
	if endormie:
		reveiller("Tu te lèves.")
		return true
	var s = _la_plus_proche(PORTEE)
	if s == null:
		return false
	# (une épave : elle ne sert plus à rien ; « Agir » la répare, si elle a de quoi. Un carré piétiné : le jardin le retourne)
	if Faim.est_epave(s) and str(s.genre) != "carre":
		reparer(s)
		return true
	match str(s.genre):
		"etabli":
			jeu.ouvrir_page("etabli")
		"tente", "hamac":
			dormir(s)
		"recuperateur":
			# (l'arrosoir d'abord, s'il est vide ; puis la gourde)
			if possede("arrosoir") > 0 and jeu.jardin.arrosages() <= 0 and float(s.etat.get("eau", 0.0)) >= 1.0:
				jeu.jardin.remplir(s)
			else:
				_puiser(s)
		"carre":
			jeu.jardin.agir(s)
		"mangeoire":
			jeu.elevage.garnir(s)
		"filet", "filet_filin":
			_relever(s)
		"cerf_volant":
			_brancher(s)
		"vestige":
			_fouiller(s)
		"coffre":
			_ouvrir(s)
		# (le grand collet : de la viande crue l'amorce ; la couche vide de la Noire, partie : scripts/noire_collet.gd)
		"collet", "couche":
			if jeu.noire == null:
				return false
			jeu.noire.collet.agir(s)
		_:
			return false
	return true


# elle cuit à la popote, sur ce feu : de l'eau et de la viande font un bouillon ; faux si elle n'a pas de quoi
func cuisiner(feu = null) -> bool:
	var inv: Dictionary = jeu.joueur.inventaire
	if possede("popote") <= 0 or int(inv.get("eau", 0)) <= 0 or int(inv.get("viande", 0)) <= 0:
		return false
	mijoter(feu)
	inv["eau"] = int(inv["eau"]) - 1
	inv["viande"] = int(inv["viande"]) - 1
	inv["bouillon"] = int(inv.get("bouillon", 0)) + 1
	jeu.joueur.geste_atelier("remuer")
	jeu.ui.message("Un bouillon frémit dans la popote.", Color(0.95, 0.75, 0.45))
	return true


# --- la cueillette (scripts/flore.gd) : l'infusion de fleurs, l'appât d'amanite ---

# ce qui l'empêche d'infuser ses fleurs ("" : rien) : des fleurs, une gorgée d'eau, la popote, un feu allumé tout près
func empeche_infuser() -> String:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("fleurs", 0)) < R.FLEURS_INFUSION:
		return "Il te faut %d fleurs." % R.FLEURS_INFUSION
	if possede("popote") <= 0:
		return "Il te faut une popote."
	if int(inv.get("eau", 0)) <= 0:
		return "Il te faut une gorgée d'eau."
	if jeu._feu_proche(jeu.joueur.position, true) == null:
		return "Il faut un feu allumé, tout près."
	return ""


# des fleurs et de l'eau, à la popote sur un feu : une infusion
func infuser() -> bool:
	var pourquoi := empeche_infuser()
	if pourquoi != "":
		jeu.ui.message(pourquoi, Color(0.75, 0.7, 0.66))
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	inv["fleurs"] = int(inv["fleurs"]) - R.FLEURS_INFUSION
	inv["eau"] = int(inv["eau"]) - 1
	inv["infusion"] = int(inv.get("infusion", 0)) + 1
	mijoter(jeu._feu_proche(jeu.joueur.position, true))
	jeu.joueur.geste_atelier("remuer")
	jeu.sons.jouer("allume", -10.0, 0.6)
	jeu.ui.message("Les fleurs frémissent dans la popote : une infusion.", Color(0.95, 0.75, 0.45))
	return true


# elle boit une infusion : la peur se pose, le corps se réchauffe un peu
func boire_infusion() -> bool:
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	if int(inv.get("infusion", 0)) <= 0:
		return false
	inv["infusion"] = int(inv["infusion"]) - 1
	j.peur = maxf(0.0, float(j.peur) - R.INFUSION_PEUR)
	if float(j.temperature) < 58.0:
		j.temperature = minf(58.0, float(j.temperature) + R.INFUSION_CHAUD)
	j.geste_atelier("boire")
	jeu.sons.atelier("gorgee")
	jeu.ui.message("L'infusion, chaude et douce. Le cœur se pose.", TEINTE)
	return true


# ce qui l'empêche de piler une amanite en appât ("" : rien)
func empeche_piler_amanite() -> String:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("amanite", 0)) <= 0:
		return "Tu n'as pas d'amanite."
	if possede("mortier") <= 0:
		return "Il te faut un mortier."
	if int(inv.get("viande", 0)) <= 0:
		return "Il te faut de la viande crue."
	return ""


# une amanite pilée avec de la viande : l'appât empoisonné des herbes (scripts/botanique.gd, « appat_poison »), qui se pose de même
func piler_amanite() -> bool:
	var pourquoi := empeche_piler_amanite()
	if pourquoi != "":
		jeu.ui.message(pourquoi, Color(0.75, 0.7, 0.66))
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	inv["amanite"] = int(inv["amanite"]) - 1
	inv["viande"] = int(inv["viande"]) - 1
	inv["appat_poison"] = int(inv.get("appat_poison", 0)) + 1
	jeu.joueur.geste_atelier("piler")
	jeu.sons.atelier("tresse", -4.0, 0.8)
	jeu.ui.message("Un appât empoisonné : de la viande frottée d'amanite. Pose-le loin du camp (ton sac) : ce qui chasse viendra le manger.", TEINTE)
	return true


# --- la cueillette nourricière (scripts/flore.gd) : le gruau, la soupe de lichen, la pulpe pressée ---

# ce que la popote fait de la cueillette, sur un feu, avec une gorgée d'eau : son nom, ce qu'il y faut, ce qu'on en dit
const PLATS := {
	"gruau": {"nom": "Gruau", "avec": {"grains": R.GRUAU_GRAINS, "eau": 1},
		"fait": "Les grains gonflent dans l'eau de la popote : un gruau épais."},
	"soupe_lichen": {"nom": "Soupe de lichen", "avec": {"lichen": R.SOUPE_LICHENS, "eau": 1},
		"fait": "Le lichen bouilli perd son amertume : une soupe maigre, grise, chaude."},
}
const ORDRE_PLATS := ["gruau", "soupe_lichen"]
# tout ce que la cueillette nourricière met dans le sac (scripts/principal.gd, manger ; interface_atelier.gd, le sac)
const NOURRITURE_CUEILLIE := ["pomme", "figue", "coco", "pain_de_singe", "grains", "lichen", "pulpe", "gruau", "soupe_lichen"]


# ce qui l'empêche de cuire ce plat ("" : rien) : ce qu'il y faut, la popote, un feu allumé tout près
func empeche_cuire(quoi: String) -> String:
	var inv: Dictionary = jeu.joueur.inventaire
	var avec: Dictionary = PLATS[quoi]["avec"]
	for k in avec:
		if int(inv.get(k, 0)) < int(avec[k]):
			if k == "eau":
				return "Il te faut une gorgée d'eau."
			return "Il te faut %d %s." % [int(avec[k]), "grains" if k == "grains" else "lichens"]
	if possede("popote") <= 0:
		return "Il te faut une popote."
	if jeu._feu_proche(jeu.joueur.position, true) == null:
		return "Il faut un feu allumé, tout près."
	return ""


# elle le cuit à la popote, sur ce feu : faux si elle ne peut pas (elle dit pourquoi)
func cuire_plat(quoi: String, feu = null) -> bool:
	var pourquoi := empeche_cuire(quoi)
	if pourquoi != "":
		jeu.ui.message(pourquoi, Color(0.75, 0.7, 0.66))
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	var avec: Dictionary = PLATS[quoi]["avec"]
	for k in avec:
		inv[k] = int(inv[k]) - int(avec[k])
	inv[quoi] = int(inv.get(quoi, 0)) + 1
	mijoter(feu if feu != null else jeu._feu_proche(jeu.joueur.position, true))
	jeu.joueur.geste_atelier("remuer")
	jeu.sons.jouer("allume", -10.0, 0.62)
	jeu.ui.message(str(PLATS[quoi]["fait"]), Color(0.95, 0.75, 0.45))
	return true


# « Cuire » (C), sans viande : le premier plat qu'elle peut faire ; sinon, si elle a de quoi en faire un, ce qui lui manque.
# Faux : elle n'a rien de ce qu'il faut (le jeu dit « Rien à cuire »)
func cuire_cueillette(feu = null) -> bool:
	for quoi in ORDRE_PLATS:
		if empeche_cuire(quoi) == "":
			return cuire_plat(quoi, feu)
	var inv: Dictionary = jeu.joueur.inventaire
	for quoi in ORDRE_PLATS:
		var principal: String = "grains" if quoi == "gruau" else "lichen"
		if int(inv.get(principal, 0)) > 0:
			jeu.ui.message("%s : %s" % [str(PLATS[quoi]["nom"]), empeche_cuire(quoi).to_lower()], Color(0.75, 0.7, 0.66))
			return true
	return false


# ce qui l'empêche de presser la pulpe d'un cactus ("" : rien) : deux pulpes, le mortier, la gourde, et de la place dedans
func empeche_presser() -> String:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("pulpe", 0)) < R.PULPES_GORGEE:
		return "Il te faut %d pulpes de cactus." % R.PULPES_GORGEE
	if possede("mortier") <= 0:
		return "Il te faut un mortier."
	if possede("gourde") <= 0:
		return "Il te faut une gourde, pour garder l'eau."
	if int(inv.get("eau", 0)) >= GORGEES:
		return "Ta gourde est pleine."
	return ""


# la pulpe, pressée au mortier : son eau coule dans la gourde (deux pulpes, une gorgée). L'eau du désert, sans pluie
func presser() -> bool:
	var pourquoi := empeche_presser()
	if pourquoi != "":
		jeu.ui.message(pourquoi, Color(0.75, 0.7, 0.66))
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	inv["pulpe"] = int(inv["pulpe"]) - R.PULPES_GORGEE
	inv["eau"] = int(inv.get("eau", 0)) + 1
	jeu.joueur.geste_atelier("piler")
	jeu.sons.atelier("tresse", -5.0, 0.7)
	jeu.sons.atelier("gourde", -4.0, 1.15)
	jeu.ui.message("La pulpe écrasée rend son eau, verte et fade : une gorgée dans ta gourde.", TEINTE)
	return true


# la popote reste un moment sur ce feu : elle y frémit (un bouillon, une décoction : scripts/botanique.gd)
func mijoter(feu) -> void:
	if feu == null or not is_instance_valid(feu):
		return
	var m = feu.get_node_or_null("Popote")
	if m == null:
		m = Marmite.new()
		m.name = "Popote"
		m.jeu = jeu
		feu.add_child(m)
	m.reste = MIJOTE


# --- le sommeil ---

# elle se couche (dans cette tente, ce hamac ; null : dans son duvet, à même le sol) ; le temps passe plus vite, jusqu'à
# l'aube ou au soir, ou jusqu'à ce que quelque chose la réveille
func dormir(ou = null) -> bool:
	if endormie:
		return false
	if ou == null and possede("duvet") <= 0:
		jeu.ui.message("Sans duvet, on ne dort pas à même le sol.", Color(0.75, 0.7, 0.66))
		return false
	var danger := _danger()
	if danger != "":
		jeu.ui.message(danger, Color(0.95, 0.5, 0.42))
		return false
	endormie = true
	_avant = Engine.time_scale
	lit = ou
	lit_de_nuit = jeu.jour_du_ciel() <= 0.0
	_t = 0.0
	var j = jeu.joueur
	j.couchage = ""
	if ou != null:
		ou.etat["occupe"] = true
		# (elle s'y glisse : on la voit se baisser à sa porte, au bord de sa toile, puis on ne la voit plus)
		var porte_la: Vector2 = Vector2(-26.5, 24.4) if str(ou.genre) == "tente" else Vector2(0.0, 23.0)
		j.position = ou.position + porte_la
		j.couchage = str(ou.genre)
	j.endormie = true
	jeu.ui.message("Tu t'endors. Un geste te réveille.", TEINTE)
	return true


func reveiller(pourquoi: String) -> void:
	if not endormie:
		return
	endormie = false
	if lit != null and is_instance_valid(lit):
		lit.etat["occupe"] = false
	lit = null
	jeu.joueur.endormie = false
	jeu.joueur.couchage = ""
	Engine.time_scale = _avant
	if pourquoi != "":
		jeu.ui.message(pourquoi, TEINTE)


# ce qui empêche de dormir, ou réveille ("" : rien)
func _danger() -> String:
	var j = jeu.joueur
	if jeu.noire != null and jeu.noire.presente():
		return "Quelque chose approche. Tu ne dors plus."
	if float(jeu._chasseur_le_plus_proche()) < 320.0:
		return "Une bête est trop près pour dormir."
	if float(j.faim) < R.FAIM_MORD:
		return "La faim t'empêche de dormir."
	if float(j.temperature) < R.FROID + 4.0 and possede("duvet") <= 0:
		return "Le froid te réveille. Il te faudrait un duvet."
	if float(j.en_feu) > 0.0 or float(j.sante) < 25.0:
		return "Tu es trop mal en point pour dormir."
	return ""


# --- chaque image ---

func maj(delta: float) -> void:
	var j = jeu.joueur
	if j == null:
		return
	var C = jeu.climat
	_t += delta
	# la lampe mange ses piles ; vides, elle s'éteint
	if porte("lampe"):
		charge = maxf(0.0, charge - LAMPE * delta)
		if charge <= 0.0:
			portes["lampe"] = false
			_tenue()
			jeu.ui.message("Les piles sont vides : la lampe s'éteint.", Color(0.95, 0.5, 0.42))
	var pluie: float = float(C.pluie) if C != null else 0.0
	var vent: float = vent_force if vent_force >= 0.0 else float(jeu.vent())
	for s in poses:
		# (une épave ne fait plus rien : elle ne se remplit pas, rien ne s'y prend)
		if not is_instance_valid(s) or Faim.est_epave(s):
			continue
		match str(s.genre):
			"etabli":
				if float(s.etat.get("travail", 0.0)) > 0.0:
					s.etat["travail"] = maxf(0.0, float(s.etat["travail"]) - delta / OUVRAGE)
			"recuperateur":
				# (sous la pluie, hors d'un toit : il se remplit)
				if pluie > 0.02:
					s.etat["eau"] = minf(CITERNE, float(s.etat.get("eau", 0.0)) + REMPLIR * pluie * delta)
			"cerf_volant":
				s.etat["vent"] = vent
				s.etat["branche"] = fil == s
				if float(s.etat.get("foudre", 0.0)) > 0.0:
					s.etat["foudre"] = maxf(0.0, float(s.etat["foudre"]) - 2.5 * delta)
				if fil == s and vent >= VENT_MIN and charge < 100.0:
					charge = minf(100.0, charge + CHARGER * vent * delta)
					s.etat["charge"] = charge / 100.0
			"filet", "filet_filin":
				_guetter(s)
	if endormie:
		_dormir(delta, j)


func _dormir(delta: float, j) -> void:
	Engine.time_scale = _avant * SOMMEIL
	# (elle se repose : la peur s'en va, la santé revient un peu)
	j.peur = maxf(0.0, float(j.peur) - 1.5 * delta)
	if float(j.faim) > 30.0:
		j.sante = minf(100.0, float(j.sante) + 0.25 * delta)
	var danger := _danger()
	if danger != "":
		reveiller(danger)
		return
	# (la nuit finie, ou le jour : elle se réveille d'elle-même)
	var nuit: bool = jeu.jour_du_ciel() <= 0.0
	if bool(lit_de_nuit) != nuit and _t > 2.0:
		reveiller("Le jour se lève." if not nuit else "La nuit tombe : tu te réveilles.")



# --- les choses posées ---

func _creer(genre: String, p: Vector2, etat: Dictionary):
	var s = Campement.new()
	s.jeu = jeu
	s.genre = genre
	s.etat = etat
	s.position = p
	jeu.monde.add_child(s)
	poses.append(s)
	return s


func _proche(genre: String, portee: float):
	var j = jeu.joueur
	if j == null:
		return null
	for s in poses:
		if is_instance_valid(s) and str(s.genre) == genre and s.position.distance_to(j.position) < portee:
			return s
	return null


func _la_plus_proche(portee: float):
	var j = jeu.joueur
	var mieux = null
	var d0 := portee
	for s in poses:
		if not is_instance_valid(s):
			continue
		var d: float = s.position.distance_to(j.position)
		if d < d0:
			d0 = d
			mieux = s
	return mieux


func _un_arbre(p: Vector2, rayon: float) -> bool:
	return _l_arbre(p, rayon) != null


# l'arbre debout le plus proche de ce point (null : aucun à cette portée)
func _l_arbre(p: Vector2, rayon: float):
	var mieux = null
	var d0 := rayon
	for o in jeu.monde.autour(p, rayon):
		if (str(o.genre) == "arbre" or str(o.genre) == "sapin") and not bool(o.get("calcine")):
			var d: float = o.position.distance_to(p)
			if d < d0:
				d0 = d
				mieux = o
	return mieux


# un pas bute aussi sur ce qu'elle a posé (scripts/monde.gd, repousser) ; le filet : on marche dessus
func buter(p: Vector2, r: float) -> Vector2:
	for s in poses:
		if not is_instance_valid(s):
			continue
		var ro: float = Campement.rayon(str(s.genre))
		if ro <= 0.0:
			continue
		var d: Vector2 = p - s.position
		var m := r + ro
		var l := d.length()
		if l < m:
			p = (s.position + d / l * m) if l > 0.001 else p + Vector2(m, 0.0)
	return p


# au récupérateur : elle remplit sa gourde
func _puiser(s) -> void:
	var inv: Dictionary = jeu.joueur.inventaire
	if possede("gourde") <= 0:
		jeu.ui.message("Il te faut une gourde pour emporter l'eau.", Color(0.75, 0.7, 0.66))
		return
	var la: int = int(floor(float(s.etat.get("eau", 0.0))))
	var place := GORGEES - int(inv.get("eau", 0))
	var pris := mini(la, place)
	if pris <= 0:
		jeu.ui.message("Le récupérateur est vide : il lui faut de la pluie." if la <= 0 else "Ta gourde est pleine.", Color(0.75, 0.7, 0.66))
		return
	s.etat["eau"] = float(s.etat.get("eau", 0.0)) - pris
	inv["eau"] = int(inv.get("eau", 0)) + pris
	jeu.joueur.geste_atelier("boire")
	jeu.sons.atelier("gourde")
	jeu.ui.message("Tu remplis ta gourde : %d gorgée%s." % [pris, "s" if pris > 1 else ""], TEINTE)


# le filet : une petite bête qui passe dessus s'y prend ; le grand filet, de filin, en tient de bien plus lourdes, sur une
# maille plus large
func _guetter(s) -> void:
	if s.etat.has("prise"):
		return
	var grand: bool = str(s.genre) == "filet_filin"
	var plus_lourde: float = R.FILET_FILIN if grand else PRISE_MAX
	var large := 30.0 if grand else 20.0
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		if b.role != "proie" or float(b.masse) > plus_lourde or b.position.distance_to(s.position) > large:
			continue
		s.etat["prise"] = {"id": str(b.id), "nom": str(b.nom), "masse": float(b.masse)}
		jeu.bete_prise(b)
		jeu.sons.atelier("filet", 0.0, 1.0 if not grand else 0.82, s.position)
		if grand:
			jeu.sons.atelier("filin", -4.0, 1.0, s.position)
		if jeu.joueur.position.distance_to(s.position) < 600.0:
			jeu.ui.message("Quelque chose s'est pris dans ton filet.", TEINTE)
		return


# elle relève son filet : la viande et la peau de ce qui s'y est pris, sans combat
func _relever(s) -> void:
	if not s.etat.has("prise"):
		jeu.ui.message("Le filet est vide.", Color(0.75, 0.7, 0.66))
		return
	var prise: Dictionary = s.etat["prise"]
	s.etat.erase("prise")
	var viande := clampi(int(round(pow(float(prise["masse"]), 0.4))), 1, 6)
	# (une grosse bête, prise au grand filet, donne ses peaux comme à la chasse)
	var peaux := peaux_de(float(prise["masse"])) if str(s.genre) == "filet_filin" else 1
	# (ce qui entre vraiment dans le sac : le message dit ce qu'elle emporte, pas ce que la bête donnait)
	var v_pris: int = ranger("viande", viande)
	var p_pris: int = ranger("peau", peaux)
	jeu.joueur.geste_atelier("monter")
	jeu.sons.atelier("filet", -4.0, 0.9)
	var plein := " Le sac est plein : le reste demeure." if v_pris < viande or p_pris < peaux else ""
	jeu.ui.message("%s : +%d viande, +%d peau%s.%s" % [str(prise["nom"]), v_pris, p_pris, "x" if p_pris > 1 else "", plein], Color(0.85, 0.72, 0.6))


# le cerf-volant : elle y branche ses piles, ou les reprend
func _brancher(s) -> void:
	if possede("piles") <= 0:
		jeu.ui.message("Le cerf-volant charge des piles : il t'en faut.", Color(0.75, 0.7, 0.66))
		return
	if fil == s:
		fil = null
		jeu.ui.message("Tu reprends tes piles : chargées à %d %%." % int(charge), TEINTE)
	else:
		fil = s
		if porte("lampe"):
			portes["lampe"] = false
			_tenue()
		jeu.ui.message("Tes piles sont au fil du cerf-volant. Il lui faut du vent.", TEINTE)
	jeu.joueur.geste_atelier("monter")
	jeu.sons.atelier("clic", -2.0, 1.15)


# un vestige : ce qu'une autre veilleuse a laissé
func _fouiller(s) -> void:
	if bool(s.etat.get("fouille", false)):
		jeu.ui.message("Il n'y a plus rien ici.", Color(0.75, 0.7, 0.66))
		return
	s.etat["fouille"] = true
	var n := 2 + int(s.etat.get("riche", 0))
	ranger("ferraille", n)
	# (et un sachet de graines : des simples, qu'on ne trouve pas dans le lieu ; scripts/jardin.gd)
	var inv: Dictionary = jeu.joueur.inventaire
	inv["graine_simple"] = int(inv.get("graine_simple", 0)) + 2
	jeu.joueur.geste_atelier("fouiller")
	jeu.sons.atelier("fouille")
	jeu.ui.message("Un camp abandonné. Tu y trouves de la ferraille (%d), et un sachet de graines : des simples." % n, TEINTE)


# un coffre : ce qu'une autre veilleuse gardait pour plus tard. La lance ne se trouve que là : on ne sait plus la faire.
func _ouvrir(s) -> void:
	if bool(s.etat.get("ouvert", false)):
		jeu.ui.message("Le coffre est vide.", Color(0.75, 0.7, 0.66))
		return
	s.etat["ouvert"] = true
	# (le couvercle se lève : le coffre fait avancer « leve », de 0 à 1 ; scripts/campement.gd)
	s.etat["leve"] = 0.0
	var j = jeu.joueur
	j.lance = R.USURE_LANCE
	var n := ranger("galet", R.GALETS_COFFRE)
	j.geste_atelier("fouiller")
	# (la serrure rouillée qu'on force, les charnières qui grincent ; le couvercle qui retombe : c'est le coffre qui le fait sonner)
	jeu.sons.atelier("fouille", 2.0, 0.9)
	jeu.sons.atelier("corde", 4.0, 0.62)
	jeu.ui.message("Un coffre, sous la mousse. Dedans : une lance, ferrée, entière%s. On n'en fait plus de pareilles." % (", et %d galets" % n if n > 0 else ""),
		Color(0.95, 0.75, 0.45))


# sa tenue a changé : le corps de la veilleuse la lit (scripts/joueur.gd)
func _tenue() -> void:
	var j = jeu.joueur
	if j == null:
		return
	j.tenue = {"sac": porte("sac_a_dos"), "chaud": porte("vetement_chaud"), "pluie": porte("vetement_pluie"), "lampe": porte("lampe")}


# la foudre vient de tomber en p : un cerf-volant en l'air, tout près, la prend. Les piles qui y sont branchées se chargent
# d'un coup ; une fois sur trois, il n'en reste que des cendres.
func foudre(p: Vector2) -> void:
	for s in poses.duplicate():
		if not is_instance_valid(s) or str(s.genre) != "cerf_volant" or float(s.etat.get("vent", 0.0)) < VENT_MIN or s.position.distance_to(p) > 520.0:
			continue
		s.etat["foudre"] = 1.0
		if fil == s:
			charge = 100.0
			s.etat["charge"] = 1.0
			jeu.ui.message("La foudre a pris le cerf-volant : tes piles sont pleines.", Color(0.98, 0.9, 0.6))
		if randf() < 0.34:
			if fil == s:
				fil = null
			poses.erase(s)
			s.queue_free()
			jeu.ui.message("Du cerf-volant, il ne reste que des cendres.", Color(0.75, 0.7, 0.66))
		return


# --- les vestiges : ce que d'autres veilleuses ont laissé (de la ferraille, pour la popote, la lampe, les piles, le cerf-volant) ---

# un lieu fermé : trois vestiges, loin du réveil
func semer_vestiges() -> void:
	if jeu.ouvert or jeu.monde == null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = int(jeu.graine) ^ 0x7e57
	var lim := R.DEMI * 0.88
	for k in 3:
		for essai in 12:
			var p := Vector2.from_angle(TAU * (k + r.randf()) / 3.0) * r.randf_range(650.0, 1700.0)
			p = jeu.monde.repousser(Vector2(clampf(p.x, -lim, lim), clampf(p.y, -lim, lim)), 20.0)
			if float(jeu.climat.eau(p)) < 0.05 or essai == 11:
				_creer("vestige", p, {"riche": 1 if k == 0 else 0})
				# (le camp le mieux pourvu garde un coffre, à deux pas : le seul du lieu)
				if k == 0:
					_creer("coffre", jeu.monde.repousser(p + Vector2(46.0, 10.0), 14.0), {})
				break


# le monde ouvert : dans cette région qu'elle découvre, un vestige, trois fois sur quatre (toujours dans la première : il lui
# faut de la ferraille), sur son chemin : à quelques centaines de pas devant elle, vers le cœur de la région
func vestige_de(i: int) -> void:
	var C = jeu.carte
	if C == null or i < 0 or i >= C.regions.size() or bool(C.regions[i]["eau"]):
		return
	var r := RandomNumberGenerator.new()
	r.seed = (int(jeu.graine) ^ 0x7e57) + i * 7919
	if r.randf() > 0.75 and not jeu.decouvertes.is_empty():
		return
	var ici: Vector2 = jeu.joueur.position
	var centre: Vector2 = C.regions[i]["pos"]
	var cap := (centre - ici).angle() if centre.distance_to(ici) > 200.0 else r.randf() * TAU
	for essai in 12:
		var p: Vector2 = C.retenir(ici + Vector2.from_angle(cap + r.randf_range(-0.8, 0.8)) * r.randf_range(650.0, 1400.0))
		if int(C.region_en(p)) == i and not bool(C.roche_en(p)) and float(C.lit(p)) <= 0.0:
			var riche := r.randf() < 0.3
			_creer("vestige", p, {"riche": 1 if riche else 0})
			# (un camp bien pourvu garde un coffre, à deux pas : un pays sur quatre environ)
			if riche:
				_creer("coffre", C.retenir(p + Vector2(46.0, 10.0)), {})
			return


# le lieu s'en va (la fin, le retour au titre)
func vider() -> void:
	if endormie:
		Engine.time_scale = _avant
	endormie = false
	poses = []
	fil = null
	lit = null


# --- la partie ---

func commencer() -> void:
	objets = {}
	portes = {}
	poses = []
	charge = 0.0
	fil = null
	endormie = false
	lit = null
	_dit = {}
	var inv: Dictionary = jeu.joueur.inventaire
	for k in ["peau", "ferraille", "corde", "bache", "galet", "eau", "bouillon", "graine_baie", "graine_lin", "graine_simple", "simples", "lait", "arrosages",
			"fleurs", "champignons", "amanite", "infusion",
			# (l'artisanat des plantes : la fibre longue, le filin, les aromates et leur baume)
			"fibre_longue", "filin", "aromates", "baume_aromates"]:
		if not inv.has(k):
			inv[k] = 0
	# (la cueillette nourricière : les fruits des arbres, les grains, le lichen, la pulpe, et ce que la popote en fait)
	for k in NOURRITURE_CUEILLIE:
		if not inv.has(k):
			inv[k] = 0
	_tenue()


func photo() -> Dictionary:
	var la := []
	for s in poses:
		if is_instance_valid(s):
			la.append([str(s.genre), snappedf(s.position.x, 0.1), snappedf(s.position.y, 0.1), s.etat.duplicate(), fil == s])
	return {"objets": objets.duplicate(), "portes": portes.keys().filter(func(k): return bool(portes[k])), "poses": la, "charge": snappedf(charge, 0.1)}


func reprendre(d: Dictionary) -> void:
	if d.is_empty():
		return
	for k in d.get("objets", {}):
		objets[str(k)] = int(d["objets"][k])
	for k in d.get("portes", []):
		portes[str(k)] = true
	charge = float(d.get("charge", 0.0))
	for x in d.get("poses", []):
		if typeof(x) != TYPE_ARRAY or x.size() < 4:
			continue
		var etat: Dictionary = x[3] if typeof(x[3]) == TYPE_DICTIONARY else {}
		etat.erase("occupe")
		etat.erase("mordu")
		var s = _creer(str(x[0]), Vector2(float(x[1]), float(x[2])), etat)
		if x.size() > 4 and bool(x[4]):
			fil = s
	_tenue()


# la popote, sur un feu : elle y frémit un moment, puis elle la reprend (son dessin : scripts/campement.gd)
class Marmite extends Node2D:
	const Camp := preload("res://scripts/campement.gd")
	var jeu
	var reste := 0.0
	var _t := 0.0
	var _dans := 0.0

	func _process(delta: float) -> void:
		if jeu != null and jeu.en_pause:
			return
		_t += delta
		reste -= delta
		var feu = get_parent()
		if reste <= 0.0 or (feu != null and feu.has_method("allume") and not feu.allume()):
			queue_free()
			return
		_dans -= delta / maxf(Engine.time_scale, 0.01)
		if _dans <= 0.0:
			_dans = 1.0 / 14.0
			queue_redraw()

	func _draw() -> void:
		Camp.popote(self, _t)

