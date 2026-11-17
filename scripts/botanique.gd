extends RefCounted
# Lisière — la botanique (scripts/botanique.gd)
# Chaque lieu a ses six herbes (des objets du lieu, genre « herbe » : scripts/objet.gd, leur dessin dans scripts/herbe.gd),
# et chacune a une vertu, une seule, que rien ne dit : cicatrisante, apaisante, vénéneuse, âcre, somnifère ou voyante. Dans un
# lieu, chaque vertu n'est portée que par une herbe ; d'une partie à l'autre, elles changent de plante : il faut réapprendre.
# Ce qu'on en sait s'écrit dans l'herbier (la page : scripts/interface_atelier.gd). On l'apprend :
#  - en la cueillant : un indice (une feuille amère, un lait blanc…), que deux vertus seulement partagent ;
#  - en regardant les bêtes : celles qui broutent ne touchent ni à la vénéneuse ni à l'âcre ;
#  - par élimination : une vertu déjà reconnue dans ce lieu n'est pas celle d'une autre herbe ;
#  - en la goûtant : on sait aussitôt, et on en paie le prix (la vénéneuse empoisonne, la somnifère endort, la voyante égare) ;
#  - en la donnant à une bête, dans un appât.
# Reconnue, une herbe se prépare : un baume, une tisane, un philtre (à la popote, sur un feu, avec de l'eau) ; une botte à
# jeter au feu, un appât empoisonné, un appât dormant (au mortier). Et elle se sème, dans un carré de jardin.

const R := preload("res://scripts/regles.gd")
const CAPS := ["l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest", "le nord", "le nord-est"]

const VERTUS := ["cicatrisante", "apaisante", "veneneuse", "acre", "somnifere", "voyante"]
const NOMS_VERTUS := {"cicatrisante": "cicatrisante", "apaisante": "apaisante", "veneneuse": "vénéneuse", "acre": "âcre",
	"somnifere": "somnifère", "voyante": "voyante"}
const DIT_VERTU := {
	"cicatrisante": "Elle referme les plaies. Deux font un baume.",
	"apaisante": "Elle calme le cœur. Deux font une tisane.",
	"veneneuse": "Elle tue. Avec de la viande : un appât pour ce qui chasse.",
	"acre": "Sa fumée brûle les yeux et la gorge. Trois font une botte, à jeter au feu : ce qui rôde s'en tient plus loin.",
	"somnifere": "Elle endort. Avec des baies : un appât pour ce qui broute.",
	"voyante": "Elle ouvre les yeux sur ce qu'on ne voit pas. Deux font un philtre.",
}
# les indices : chacun est partagé par deux vertus, et chaque vertu en a deux (une ronde : l'indice seul ne tranche jamais)
const INDICES := {"cicatrisante": ["amere", "rouge"], "veneneuse": ["amere", "lait"], "somnifere": ["lait", "miel"],
	"apaisante": ["miel", "duvet"], "voyante": ["duvet", "piquante"], "acre": ["piquante", "rouge"]}
const DIT_INDICE := {"amere": "Sa feuille est amère sous la dent.", "lait": "Sa tige cassée rend un lait blanc.", "miel": "Elle sent le miel.",
	"duvet": "Un duvet d'argent couvre ses feuilles.", "piquante": "Son odeur pique le nez.", "rouge": "Sa tige est rouge sang."}
# celles que les bêtes broutent
const BROUTEES := ["cicatrisante", "apaisante", "somnifere", "voyante"]
# les sept formes d'herbe (scripts/herbe.gd les dessine)
const FORMES := ["ombelle", "clochette", "epi", "rosette", "morelle", "chardon", "crosse"]
# les six herbes de chaque lieu : [la forme, le nom, la couleur de sa fleur ou de son fruit]
const FLORE := {
	"foret": [["ombelle", "Ombelle des lisières", "ece4cf"], ["clochette", "Clochette de minuit", "6c58a6"], ["crosse", "Crosse-de-veilleuse", "86b25c"],
		["morelle", "Morelle des souches", "2c2338"], ["rosette", "Feuille-de-lune", "a9c3ab"], ["epi", "Épi roux", "b8632d"]],
	"lande": [["chardon", "Chardon bleu", "5f7fc0"], ["epi", "Bruyère-cendre", "c07f9a"], ["rosette", "Rosette des pierres", "9aa37a"],
		["ombelle", "Ombelle sèche", "d9cf9e"], ["clochette", "Clochette des vents", "e3d27a"], ["morelle", "Prunelle amère", "3a3550"]],
	"marais": [["ombelle", "Ombelle des mares", "e2e8d8"], ["clochette", "Clochette d'eau", "5a8fc4"], ["crosse", "Prêle noire", "4f6b4a"],
		["rosette", "Feuille-des-noyés", "7fa38a"], ["epi", "Massette rouge", "8c3b2a"], ["morelle", "Morelle des vases", "3b2a3a"]],
	"prairie": [["ombelle", "Ombelle dorée", "e8c85a"], ["epi", "Épi-de-miel", "d9a441"], ["chardon", "Étoile des prés", "b062b8"],
		["clochette", "Clochette pâle", "e8dff0"], ["rosette", "Rosette douce", "a8c878"], ["morelle", "Groseille folle", "b0303a"]],
	"taiga": [["crosse", "Crosse des neiges", "9fc0b0"], ["chardon", "Chardon de givre", "b9d4e6"], ["rosette", "Rosette des mousses", "7f9a6a"],
		["clochette", "Clochette boréale", "8ad0c0"], ["epi", "Épi gris", "a8a59a"], ["morelle", "Airelle noire", "26283a"]],
}
# ce qui se prépare : sa vertu, combien d'herbes, ce qu'il faut d'autre, où (« feu » : la popote sur un feu, avec de l'eau ;
# « mortier »), ce que c'est
const PREPARATIONS := {
	"baume": {"nom": "Baume", "vertu": "cicatrisante", "herbes": 2, "ou": "feu", "avec": {"eau": 1},
		"dit": "Un onguent tiède. Il rend la santé (45), et chasse le poison."},
	"tisane": {"nom": "Tisane", "vertu": "apaisante", "herbes": 2, "ou": "feu", "avec": {"eau": 1},
		"dit": "Elle calme la peur (50), et la tient basse une minute."},
	"philtre": {"nom": "Philtre de voyance", "vertu": "voyante", "herbes": 2, "ou": "feu", "avec": {"eau": 1},
		"dit": "Bu la nuit : un moment, tu vois ce qui se cache, et d'où vient la Noire. Le cœur s'emballe."},
	"botte": {"nom": "Botte âcre", "vertu": "acre", "herbes": 3, "ou": "mortier", "avec": {"fibre": 1},
		"dit": "Jetée dans un feu : trois quarts de minute, sa fumée tient les chasseurs moitié plus loin."},
	"appat_poison": {"nom": "Appât empoisonné", "vertu": "veneneuse", "herbes": 1, "ou": "mortier", "avec": {"viande": 1},
		"dit": "De la viande, frottée de poison. Ce qui chasse vient la manger, et n'ira pas loin."},
	"appat_dormant": {"nom": "Appât dormant", "vertu": "somnifere", "herbes": 1, "ou": "mortier", "avec": {"baies": 2},
		"dit": "Des baies, mêlées d'herbe à dormir. La bête qui les mange s'endort : on l'approche, on lui passe un licol."},
}
const ORDRE_PREPARATIONS := ["baume", "tisane", "philtre", "botte", "appat_poison", "appat_dormant"]
const TEINTE := Color(0.72, 0.84, 0.6)
const GRIS := Color(0.75, 0.7, 0.66)
const ROUGE := Color(0.95, 0.5, 0.42)
const POISON := 18.0              # secondes : ce que dure le poison
const POISON_MAL := 1.6           # ce qu'il prend de santé par seconde
const TORPEUR := 26.0             # secondes : la somnifère goûtée (on marche à moitié moins vite)
const VISIONS := 30.0             # secondes : la voyante goûtée
const VOYANCE := 38.0             # secondes : le philtre
const CALME := 60.0               # secondes : la tisane tient la peur basse
const FUMEE := 45.0               # secondes : une botte dans un feu
const GARDE := 1.5                # ce que la fumée ajoute à la distance où un feu tient les chasseurs
const SOMMEIL_BETE := 40.0        # secondes : une bête endormie par un appât
const POISON_BETE := 22.0         # secondes : ce que met une bête empoisonnée à s'éteindre
const RECOLTE_JARDIN := 5         # ce qu'un carré rend d'une herbe semée
const SEMIS := 2                  # ce qu'il faut de plants pour un carré

# la botanique de la partie en cours : le dessin d'une herbe y lit son indice (une tige rouge, un duvet d'argent se voient)
static var partie = null

var jeu
var graine := 0                   # celle de la partie : elle tire les vertus
var savoir := {}                  # l'espèce → { vue, indice, broutee, sue (« goutee », « deduite », « essai ») }
var poison := 0.0                 # secondes de poison encore dans le sang
var torpeur := 0.0
var visions := 0.0
var voyance := 0.0
var calme := 0.0
var fumees := {}                  # le feu → secondes de fumée âcre
var dernier_gout := ""            # la vertu de la dernière herbe goûtée (le geste « gouter » en lit la grimace)
var _vertus := {}                 # le lieu → [la vertu de chacune de ses six herbes]
var _indices := {}                # l'espèce → son indice
var _dit := {}
var _guet := 0.0


# --- les espèces ---

# l'espèce de l'herbe qui pousse là : « foret:ombelle » (sa place dans la flore du lieu vient de sa graine)
static func espece_de(type: String, graine_objet: int) -> String:
	var t := type if FLORE.has(type) else "foret"
	var k: int = absi(graine_objet) % int(FLORE[t].size())
	return "%s:%s" % [t, str(FLORE[t][k][0])]


static func lieu_de(id: String) -> String:
	return id.get_slice(":", 0)


static func forme_de(id: String) -> String:
	return id.get_slice(":", 1)


static func _fiche(id: String) -> Array:
	for e in FLORE.get(lieu_de(id), []):
		if str(e[0]) == forme_de(id):
			return e
	return ["ombelle", "Herbe", "c0c0a0"]


static func nom(id: String) -> String:
	return str(_fiche(id)[1])


static func couleur(id: String) -> Color:
	return Color(str(_fiche(id)[2]))


static func especes(type: String) -> Array:
	var out := []
	for e in FLORE.get(type, []):
		out.append("%s:%s" % [type, str(e[0])])
	return out


# la clé de cette herbe dans le sac
static func cle(id: String) -> String:
	return "h:" + id


# sa vertu (tirée une fois par partie et par lieu : chaque vertu y est, une seule fois)
func vertu(id: String) -> String:
	var type := lieu_de(id)
	if not _vertus.has(type):
		var r := RandomNumberGenerator.new()
		r.seed = hash("%d|%s" % [graine, type])
		var v: Array = VERTUS.duplicate()
		for i in range(v.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var x = v[i]
			v[i] = v[j]
			v[j] = x
		_vertus[type] = v
	var k: int = especes(type).find(id)
	return str(_vertus[type][maxi(k, 0)])


# son indice : l'un des deux de sa vertu
func indice(id: String) -> String:
	if not _indices.has(id):
		_indices[id] = INDICES[vertu(id)][absi(hash("%d|%s" % [graine, id])) % 2]
	return str(_indices[id])


# ce que le dessin d'une herbe montre de son indice, sans qu'on la cueille : « rouge » (sa tige), « duvet » (ses feuilles),
# « miel » (des insectes autour), « lait » (une goutte blanche, une fois cueillie) ; "" : rien qui se voie (amère, piquante)
static func signe(id: String) -> String:
	if partie == null:
		return ""
	var i: String = partie.indice(id)
	return i if i in ["rouge", "duvet", "miel", "lait"] else ""


# --- ce qu'on en sait ---

func _fiche_savoir(id: String) -> Dictionary:
	if not savoir.has(id):
		savoir[id] = {}
	return savoir[id]


func connue(id: String) -> bool:
	return savoir.has(id) and bool(savoir[id].get("vue", false))


# sa vertu est-elle reconnue ?
func sue(id: String) -> bool:
	return savoir.has(id) and str(savoir[id].get("sue", "")) != ""


# ce qu'elle peut être, d'après ce qu'on sait : l'indice, les bêtes, ce qui est déjà reconnu dans ce lieu
func candidates(id: String) -> Array:
	if sue(id):
		return [vertu(id)]
	var s: Dictionary = savoir.get(id, {})
	var out := []
	for v in VERTUS:
		if bool(s.get("indice", false)) and not INDICES[v].has(indice(id)):
			continue
		if bool(s.get("broutee", false)) and not BROUTEES.has(v):
			continue
		out.append(v)
	for autre in especes(lieu_de(id)):
		if autre != id and sue(autre):
			out.erase(vertu(autre))
	return out


# une seule vertu possible : elle est reconnue, sans y avoir goûté (et cela en éclaire peut-être d'autres)
func _deduire(type: String) -> void:
	var encore := true
	while encore:
		encore = false
		for id in especes(type):
			if connue(id) and not sue(id) and candidates(id).size() == 1:
				_fiche_savoir(id)["sue"] = "deduite"
				encore = true
				jeu.ui.message("%s : ce ne peut être que la %s." % [nom(id), str(NOMS_VERTUS[vertu(id)])], TEINTE)


# ce qu'on en dit, en quelques lignes (l'herbier)
func lignes(id: String) -> Array:
	var out := []
	var s: Dictionary = savoir.get(id, {})
	if not bool(s.get("vue", false)):
		return ["Tu ne l'as pas encore cueillie."]
	if bool(s.get("indice", false)):
		out.append(str(DIT_INDICE[indice(id)]))
	if bool(s.get("broutee", false)):
		out.append("Les bêtes en mangent : ni vénéneuse, ni âcre.")
	match str(s.get("sue", "")):
		"goutee":
			out.append("Tu y as goûté.")
		"deduite":
			out.append("Reconnue sans y goûter.")
		"essai":
			out.append("Une bête t'a montré ce qu'elle fait.")
	return out


func possede(id: String) -> int:
	return int(jeu.joueur.inventaire.get(cle(id), 0))


# toutes les herbes du sac : l'espèce → combien
func sac() -> Dictionary:
	var out := {}
	var inv: Dictionary = jeu.joueur.inventaire
	for k in inv:
		if str(k).begins_with("h:") and int(inv[k]) > 0:
			out[str(k).substr(2)] = int(inv[k])
	return out


# --- cueillir, regarder, goûter ---

# elle cueille cette herbe (un objet du lieu) : dans le sac ; la première fois, son indice
func cueillie(id: String) -> void:
	var inv: Dictionary = jeu.joueur.inventaire
	inv[cle(id)] = int(inv.get(cle(id), 0)) + 1
	var s := _fiche_savoir(id)
	if not bool(s.get("vue", false)):
		s["vue"] = true
		s["indice"] = true
		jeu.ui.message("%s. %s %s" % [nom(id), str(DIT_INDICE[indice(id)]), "" if _dit.has("herbier") else "L'herbier de ton sac la retient."], TEINTE)
		_dit["herbier"] = true
		_deduire(lieu_de(id))


# une bête en mange, sous ses yeux
func vue_broutee(id: String) -> void:
	var s := _fiche_savoir(id)
	if bool(s.get("broutee", false)):
		return
	s["broutee"] = true
	if bool(s.get("vue", false)):
		jeu.ui.message("Une bête mange de la %s : elle n'est ni vénéneuse, ni âcre." % nom(id).to_lower(), TEINTE)
	_deduire(lieu_de(id))


# une bête broute-t-elle cette herbe ?
func se_broute(id: String) -> bool:
	return BROUTEES.has(vertu(id))


func _savoir_par(id: String, comment: String) -> void:
	var s := _fiche_savoir(id)
	s["vue"] = true
	if str(s.get("sue", "")) == "":
		s["sue"] = comment
	_deduire(lieu_de(id))


# elle y goûte : elle sait, et elle en paie le prix
func gouter(id: String) -> bool:
	if possede(id) <= 0:
		return false
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	inv[cle(id)] = possede(id) - 1
	var v := vertu(id)
	dernier_gout = v
	var deja := sue(id)
	_savoir_par(id, "goutee")
	j.geste_atelier("gouter")
	var n := nom(id)
	match v:
		"cicatrisante":
			j.sante = minf(100.0, float(j.sante) + 8.0)
			poison = maxf(0.0, poison - 6.0)
			jeu.ui.message("%s : amère, mais la douleur recule. Elle est cicatrisante." % n, TEINTE)
		"apaisante":
			j.peur = maxf(0.0, float(j.peur) - 12.0)
			jeu.ui.message("%s : le cœur ralentit. Elle est apaisante." % n, TEINTE)
		"veneneuse":
			poison = POISON
			j.peur = minf(100.0, float(j.peur) + 10.0)
			jeu.ui.message("%s : la gorge se serre, le ventre se tord. Elle est vénéneuse. Un baume chasse le poison." % n, ROUGE)
		"acre":
			j.sante = maxf(1.0, float(j.sante) - 6.0)
			j.peur = minf(100.0, float(j.peur) + 6.0)
			jeu.ui.message("%s : la bouche en feu, tu tousses à t'arracher la gorge. Elle est âcre." % n, ROUGE)
			jeu.sons.jouer("grogne", -14.0, 1.7)
		"somnifere":
			torpeur = TORPEUR
			jeu.ui.message("%s : les paupières tombent, les jambes pèsent. Elle est somnifère." % n, ROUGE)
		"voyante":
			visions = VISIONS
			j.peur = minf(100.0, float(j.peur) + 15.0)
			jeu.ui.message("%s : le noir se peuple d'yeux qui n'y sont pas. Elle est voyante.%s" % [n, _ou_est_la_noire()], ROUGE)
	if not deja and not _dit.has("gout"):
		_dit["gout"] = true
	return true


func _ou_est_la_noire() -> String:
	var N = jeu.noire
	if N == null or Vector2(N.taniere) == Vector2.ZERO:
		return ""
	var d: Vector2 = Vector2(N.taniere) - jeu.joueur.position
	return " Quelque chose dort vers %s." % str(CAPS[int(round(fposmod(d.angle(), TAU) / (TAU / 8.0))) % 8])


# --- préparer ---

# l'herbe du sac qui porte cette vertu, et qu'on sait la porter ("" : aucune) : celle dont on a le plus
func herbe_pour(v: String, il_en_faut: int = 1) -> String:
	var mieux := ""
	var n0 := il_en_faut - 1
	var s := sac()
	for id in s:
		if sue(id) and vertu(id) == v and int(s[id]) > n0:
			n0 = int(s[id])
			mieux = id
	return mieux


# connaît-elle une herbe de cette vertu ?
func sait_faire(p: String) -> bool:
	var v := str(PREPARATIONS[p]["vertu"])
	for id in savoir:
		if sue(id) and vertu(id) == v:
			return true
	return false


# ce qui l'empêche de la préparer ("" : rien)
func empeche_preparer(p: String) -> String:
	var o: Dictionary = PREPARATIONS[p]
	var A = jeu.atelier
	if not sait_faire(p):
		return "Tu ne connais pas d'herbe %s." % str(NOMS_VERTUS[o["vertu"]])
	if herbe_pour(str(o["vertu"]), int(o["herbes"])) == "":
		return "Il t'en faut %d, de la même herbe." % int(o["herbes"])
	var inv: Dictionary = jeu.joueur.inventaire
	for k in o["avec"]:
		if int(inv.get(k, 0)) < int(o["avec"][k]):
			return "Il te manque %d %s." % [int(o["avec"][k]) - int(inv.get(k, 0)), str(R.NOMS.get(k, A.NOMS_MATIERES.get(k, k)))]
	if str(o["ou"]) == "feu":
		if A.possede("popote") <= 0:
			return "Il te faut une popote."
		if jeu._feu_proche(jeu.joueur.position, true) == null:
			return "Il faut un feu allumé, tout près."
	elif A.possede("mortier") <= 0:
		return "Il te faut un mortier."
	return ""


func preparer(p: String) -> bool:
	var pourquoi := empeche_preparer(p)
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var o: Dictionary = PREPARATIONS[p]
	var inv: Dictionary = jeu.joueur.inventaire
	var id := herbe_pour(str(o["vertu"]), int(o["herbes"]))
	inv[cle(id)] = possede(id) - int(o["herbes"])
	for k in o["avec"]:
		inv[k] = int(inv[k]) - int(o["avec"][k])
	inv[p] = int(inv.get(p, 0)) + 1
	if str(o["ou"]) == "feu":
		jeu.joueur.geste_atelier("remuer")
		jeu.atelier.mijoter(jeu._feu_proche(jeu.joueur.position, true))
		jeu.sons.jouer("allume", -10.0, 0.6)
	else:
		jeu.joueur.geste_atelier("piler")
		# (le pilon dans la pierre : trois coups, au rythme du geste — Joueur.PILER_COUPS —, puis les herbes qu'on broie)
		for t in [1.1, 1.32, 1.54]:
			jeu.get_tree().create_timer(float(t)).timeout.connect(func(): jeu.sons.jouer("pierre", -13.0, 1.45))
		jeu.sons.atelier("tresse", -4.0, 0.8)
	jeu.ui.message("%s. %s" % [str(o["nom"]), str(o["dit"])], TEINTE)
	return true


# ce qui empêche de s'en servir, là, maintenant ("" : rien)
func empeche_utiliser(p: String) -> String:
	if int(jeu.joueur.inventaire.get(p, 0)) <= 0:
		return "Tu n'en as pas."
	if p == "botte" and jeu._feu_proche(jeu.joueur.position, true) == null:
		return "Il faut un feu allumé, tout près."
	if p == "appat_poison" or p == "appat_dormant":
		for s in jeu.atelier.poses:
			if is_instance_valid(s) and str(s.genre) == "appat" and s.position.distance_to(jeu.joueur.position) < 200.0:
				return "Il y a déjà un appât ici."
	return ""


# elle s'en sert
func utiliser(p: String) -> bool:
	var pourquoi := empeche_utiliser(p)
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	inv[p] = int(inv[p]) - 1
	match p:
		"baume":
			j.sante = minf(100.0, float(j.sante) + 45.0)
			var gueri := poison > 0.0
			poison = 0.0
			j.geste_atelier("boire")
			jeu.ui.message("Le baume, tiède sur la peau.%s" % (" Le poison lâche prise." if gueri else ""), TEINTE)
		"tisane":
			j.peur = maxf(0.0, float(j.peur) - 50.0)
			calme = CALME
			j.geste_atelier("boire")
			jeu.sons.atelier("gorgee")
			jeu.ui.message("La tisane. Le cœur se pose.", TEINTE)
		"philtre":
			voyance = VOYANCE
			j.peur = minf(100.0, float(j.peur) + 20.0)
			j.geste_atelier("boire")
			jeu.sons.atelier("gorgee", 0.0, 0.8)
			var N = jeu.noire
			var ou := ""
			if N != null and Vector2(N.taniere) != Vector2.ZERO:
				N.taniere_connue = true
				# (elle l'écrit sur sa carte, si elle a la carte, la plume et l'encre ; scripts/reperes.gd)
				var ecrite: bool = jeu.get("reperes") != null and jeu.reperes.noter_taniere(N.taniere)
				ou = " Tu sais où elle dort : tu l'écris sur ta carte." if ecrite else " Tu sais où elle dort, vers %s." % str(CAPS[int(round(fposmod((Vector2(N.taniere) - j.position).angle(), TAU) / (TAU / 8.0))) % 8])
			jeu.ui.message("Le philtre. Le noir s'ouvre : tu vois ce qui s'y tient.%s" % ou, TEINTE)
		"botte":
			var f = jeu._feu_proche(j.position, true)
			fumees[f] = FUMEE
			j.geste_atelier("jeter")
			jeu.sons.jouer("allume", -6.0, 0.5)
			jeu.ui.message("La botte dans les flammes : une fumée âcre monte. Ce qui chasse s'en tient plus loin.", TEINTE)
		"appat_poison", "appat_dormant":
			var A = jeu.atelier
			A._creer("appat", A._devant("appat"), {"reste": 1.0, "sorte": "poison" if p == "appat_poison" else "dormant"})
			j.geste_atelier("fouiller")
			jeu.ui.message("L'appât est posé. Écarte-toi.", TEINTE)
	return true


# --- le jardin : une herbe reconnue se sème ---

func empeche_semer(id: String) -> String:
	if not sue(id):
		return "Tu ne sais pas encore ce qu'elle vaut."
	if possede(id) < SEMIS:
		return "Il t'en faut %d plants." % SEMIS
	return ""


# --- ce que le jeu en lit ---

# son allure : la torpeur pèse
func allure() -> float:
	return 0.55 if torpeur > 0.0 else 1.0


# la fumée âcre de ce feu (de 0 à 1 ; elle s'éteint sur ses dernières secondes)
func fumee(feu) -> float:
	return clampf(float(fumees.get(feu, 0.0)) / 4.0, 0.0, 1.0)


# ce qu'un chasseur, là, doit de distance en plus aux feux : la fumée âcre du plus proche
func garde(p: Vector2) -> float:
	var k := 1.0
	for f in fumees:
		if is_instance_valid(f) and f.position.distance_to(p) < 900.0:
			k = maxf(k, lerpf(1.0, GARDE, fumee(f)))
	return k


# ce qui tente cette bête : un appât dormant (ce qui broute), un appât empoisonné (ce qui chasse) ; null : rien
func tentation(b):
	var veut := "dormant" if str(b.role) == "proie" else ("poison" if str(b.role) in ["chasseur", "rodeur"] else "")
	if veut == "":
		return null
	var mieux = null
	var d0: float = float(b.flair) * 1.6
	for s in jeu.atelier.poses:
		if is_instance_valid(s) and str(s.genre) == "appat" and str(s.etat.get("sorte", "")) == veut and float(s.etat.get("reste", 0.0)) > 0.0:
			var d: float = s.position.distance_to(b.position)
			if d < d0:
				d0 = d
				mieux = s
	return mieux


# une bête mange un de ces appâts : fini, il fait son effet
func mangee(b, s, delta: float) -> void:
	s.etat["reste"] = float(s.etat.get("reste", 1.0)) - delta / 5.0
	if float(s.etat["reste"]) > 0.0:
		return
	var sorte := str(s.etat.get("sorte", ""))
	jeu.atelier.poses.erase(s)
	s.queue_free()
	if sorte == "dormant":
		b.endormir(SOMMEIL_BETE)
		if b.position.distance_to(jeu.joueur.position) < 700.0:
			jeu.ui.message("%s s'est endormie sur l'appât." % str(b.nom), TEINTE)
	elif sorte == "poison":
		# (un peu plus longtemps que ce que le poison met à l'éteindre : il va jusqu'au bout)
		b.empoisonner(POISON_BETE * 1.2)
		if b.position.distance_to(jeu.joueur.position) < 700.0:
			jeu.ui.message("%s a mangé l'appât. Le poison fera le reste." % str(b.nom), TEINTE)


# --- chaque image ---

func maj(delta: float) -> void:
	var j = jeu.joueur
	if j == null:
		return
	if poison > 0.0:
		poison = maxf(0.0, poison - delta)
		jeu._mal("poison", POISON_MAL * delta)
		if poison <= 0.0:
			jeu.ui.message("Le poison s'est éteint.", TEINTE)
	torpeur = maxf(0.0, torpeur - delta)
	visions = maxf(0.0, visions - delta)
	voyance = maxf(0.0, voyance - delta)
	if calme > 0.0:
		calme = maxf(0.0, calme - delta)
		j.peur = maxf(0.0, float(j.peur) - 1.4 * delta)
	# (une herbe qu'elle ne connaît pas, à quelques pas : le jeu le dit, une fois par espèce — elles sont petites, on passe à côté)
	_guet -= delta
	if _guet <= 0.0 and jeu.monde != null:
		_guet = 0.6
		for o in jeu.monde.autour(j.position, 120.0):
			if str(o.genre) == "herbe" and int(o.reste) > 0 and not connue(str(o.herbe)) and not _dit.has("pres:" + str(o.herbe)):
				_dit["pres:" + str(o.herbe)] = true
				jeu.ui.message("Une herbe que tu ne connais pas, à quelques pas. « Agir » la cueille.", TEINTE)
				break
	for f in fumees.keys():
		if not is_instance_valid(f) or not f.allume():
			fumees.erase(f)
			continue
		fumees[f] = float(fumees[f]) - delta
		if float(fumees[f]) <= 0.0:
			fumees.erase(f)


# --- la partie gardée ---

func commencer(graine_partie: int) -> void:
	partie = self
	graine = graine_partie
	savoir = {}
	_vertus = {}
	_indices = {}
	_dit = {}
	poison = 0.0
	torpeur = 0.0
	visions = 0.0
	voyance = 0.0
	calme = 0.0
	fumees = {}
	dernier_gout = ""


func photo() -> Dictionary:
	return {"graine": graine, "savoir": savoir.duplicate(true), "poison": snappedf(poison, 0.1), "torpeur": snappedf(torpeur, 0.1),
		"visions": snappedf(visions, 0.1), "voyance": snappedf(voyance, 0.1), "calme": snappedf(calme, 0.1)}


func reprendre(d: Dictionary) -> void:
	if d.is_empty():
		return
	commencer(int(d.get("graine", graine)))
	var s = d.get("savoir", {})
	if typeof(s) == TYPE_DICTIONARY:
		savoir = s.duplicate(true)
	poison = float(d.get("poison", 0.0))
	torpeur = float(d.get("torpeur", 0.0))
	visions = float(d.get("visions", 0.0))
	voyance = float(d.get("voyance", 0.0))
	calme = float(d.get("calme", 0.0))
