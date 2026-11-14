extends Node2D
# Lisière — le pistage (scripts/pistage.gd)
# Ce que la veilleuse apprend des bêtes du lieu, en les regardant vivre. Deux gestes :
#  - l'affût : immobile, près d'une bête qu'on voit (le jour, ou dans une lumière) et qui ne fuit ni n'attaque, elle l'observe.
#    Un œil s'ouvre au-dessus de la bête, et sa jauge se remplit. Six secondes : elle est « observée » ; dix-huit : « connue ».
#    Le temps se compte par lignée, d'une bête à l'autre ; marcher l'arrête, sans rien faire perdre ;
#  - la piste : en passant sur des empreintes (scripts/traces.gd), à la lumière, elle les lit : de qui elles sont (si elle a
#    déjà vu la bête), si elles sont fraîches, vers où elles vont. Chaque piste lue vaut un peu d'observation.
# Ce qu'elle en tire est dans le carnet (la pause, « Le carnet des bêtes » : scripts/interface_carnet.gd), une page par bête
# croisée, écrite d'après sa lignée d'Orvane et les règles du jeu : rien n'y est inventé.
#  - croisée : son nom, son dessin ;
#  - observée : proie ou chasseur, ce qu'elle mange, quand elle vit, seule ou à plusieurs, son poids ;
#  - connue : ce qui sert à survivre. Une proie : de quelle distance elle fuit, si on la rattrape à la course, ce qu'elle donne,
#    combien de coups il faut. Un chasseur : ce que prend sa morsure, si la torche le tient, combien de coups. Et ce que sa
#    population a appris des joueurs (la mémoire d'Orvane), combien il en reste ici.
# Ce nœud est au-dessus du lieu : il dessine l'œil de l'affût. Le savoir lui-même est au jeu (principal.gd, savoir).

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const I := preload("res://scripts/interface_icones.gd")
const Donnees := preload("res://scripts/donnees.gd")
const Bestiaire := preload("res://scripts/bestiaire.gd")
const PORTEE := 380.0            # jusqu'où l'on observe une bête
const OBSERVEE := 6.0            # secondes d'affût pour l'avoir observée
const CONNUE := 18.0             # et pour la connaître
const PISTE := 1.5               # ce que vaut une piste lue, en secondes d'affût
const RELIRE := 22.0             # entre deux lectures de la piste d'une même bête
const TEINTE := Color(0.8, 0.86, 0.72)
const CAPS := ["l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest", "le nord", "le nord-est"]
const METS := {"feuilles": "des feuilles", "fruits": "des fruits", "graines": "des graines", "insectes": "des insectes",
	"nectar": "du nectar", "viande": "de la viande"}

var jeu
var cible = null                 # la bête qu'elle observe, cette image
var dernier_dit := ""            # la dernière piste lue, telle qu'elle a été dite (l'essai)
var _choix := 0.0
var _sol := 0.0
var _lues := {}                  # par lignée : quand on pourra relire sa piste
var _t := 0.0
var _ouvert := 0.0               # l'œil s'ouvre et se ferme en douceur
var _ou := Vector2.ZERO
var _part := 0.0


func _ready() -> void:
	name = "Pistage"


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause or jeu.joueur == null:
		return
	maj(delta)


# une image (l'essai l'appelle aussi tout droit)
func maj(delta: float) -> void:
	_t += delta
	var j = jeu.joueur
	_choix -= delta
	if _choix <= 0.0 or (cible != null and not _observable(cible, j)):
		_choix = 0.2
		cible = _a_observer(j)
	if cible != null:
		_gagner(str(cible.id), str(cible.nom), delta)
		_ou = cible.position + Vector2(0.0, float(cible._sq.get("haut", -cible.largeur * 0.6)) - 16.0) if not cible._sq.is_empty() else cible.position + Vector2(0.0, -cible.largeur * 0.7)
		_part = part(str(cible.id))
	var avant := _ouvert
	_ouvert = move_toward(_ouvert, 1.0 if cible != null else 0.0, delta * 4.0)
	if _ouvert > 0.0 or avant > 0.0:
		queue_redraw()
	_sol -= delta
	if _sol <= 0.0:
		_sol = 0.33
		_lire_le_sol(j)


# --- l'affût ---

# la bête qu'elle peut observer : la plus proche de celles qu'elle voit, qui vaquent, et dont il reste à apprendre ; il faut
# qu'elle-même ne bouge pas
func _a_observer(j):
	if j.morte:
		return null
	var mieux = null
	var d0 := PORTEE
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		if not _observable(b, j, false):
			continue
		var d: float = b.position.distance_to(j.position)
		if d < d0:
			d0 = d
			mieux = b
	if mieux != null and j.en_mouvement:
		# (elle passe près d'une bête sans s'arrêter : le jeu dit le geste, une fois, passé les premières secondes)
		jeu._conseil("affut", jeu.horloge > R.TRANSITION + 22.0 and float(jeu.savoir.get(mieux.id, 0.0)) <= 0.0,
			"Une bête ne t'a pas vue. Reste immobile : tu l'observes, et ton carnet se remplit.", TEINTE)
		return null
	return mieux


func _observable(b, j, immobile: bool = true) -> bool:
	if not is_instance_valid(b) or (immobile and j.en_mouvement) or j.morte:
		return false
	if not (b.role == "proie" or b.role == "rodeur" or b.role == "chasseur") or b.pv <= 0.0:
		return false
	if b.etat == "fuit" or b.etat == "attaque" or b.etat == "mort" or b.etat == "part":
		return false
	if float(jeu.savoir.get(b.id, 0.0)) >= CONNUE or b.position.distance_to(j.position) > PORTEE:
		return false
	return float(jeu.eclairage(b.position)) > 0.3


# du temps d'affût gagné sur une lignée ; les deux seuils se disent
func _gagner(id: String, nom: String, secondes: float) -> void:
	var avant := float(jeu.savoir.get(id, 0.0))
	if avant >= CONNUE:
		return
	var apres := minf(CONNUE, avant + secondes)
	jeu.savoir[id] = apres
	if avant < OBSERVEE and apres >= OBSERVEE:
		jeu.ui.message("%s : tu l'as observée. Ton carnet dit ce qu'elle mange et quand elle vit." % nom, TEINTE)
	if avant < CONNUE and apres >= CONNUE:
		jeu.ui.message("%s : tu la connais. Ton carnet dit comment l'approcher et ce qu'elle vaut." % nom, TEINTE)


# ce qu'on sait d'une lignée : 0, croisée ; 1, observée ; 2, connue
func niveau(id: String) -> int:
	var s := float(jeu.savoir.get(id, 0.0))
	return 2 if s >= CONNUE else (1 if s >= OBSERVEE else 0)


# où en est la jauge de l'œil, de 0 à 1 : vers « observée », puis vers « connue »
func part(id: String) -> float:
	var s := float(jeu.savoir.get(id, 0.0))
	if s < OBSERVEE:
		return s / OBSERVEE
	return clampf((s - OBSERVEE) / (CONNUE - OBSERVEE), 0.0, 1.0)


# --- la piste ---

# elle passe sur des empreintes, à la lumière : elle les lit (pas plus d'une fois toutes les RELIRE secondes par bête)
func _lire_le_sol(j) -> void:
	if jeu.traces == null or j.morte or float(jeu.eclairage(j.position)) < 0.35:
		return
	var e: Array = jeu.traces.la_plus_proche(j.position, 34.0)
	if e.is_empty():
		return
	var qui := str(e[7]) if e.size() > 7 else ""
	var genre := int(e[6])
	if genre == 2:
		qui = "la-noire"
		# (la Noire dit elle-même la première fois qu'on reconnaît ses empreintes : scripts/noire.gd)
		if jeu.noire == null or not jeu.noire.su.has("empreintes"):
			return
	if qui == "" or float(_lues.get(qui, 0.0)) > _t:
		return
	_lues[qui] = _t + RELIRE
	var age: float = jeu.traces.age(e)
	var fraiche := "toute fraîche" if age < 0.3 else ("fraîche" if age < 0.7 else "ancienne")
	var vers := cap(float(e[2]))
	if genre == 2:
		dernier_dit = "La piste de la Noire. Elle va vers %s." % vers
		jeu.ui.message(dernier_dit, jeu.noire.TEINTE)
		return
	var nom := str(jeu.vues.get(qui, ""))
	if nom == "":
		dernier_dit = "Une piste %s, d'une bête que tu n'as pas encore vue. Elle va vers %s." % [fraiche, vers]
	else:
		dernier_dit = "Une piste %s : %s. Elle va vers %s." % [fraiche, nom, vers]
		_gagner(qui, nom, PISTE)
	jeu.ui.message(dernier_dit, TEINTE)


# vers où pointe un angle du lieu, en mots (le nord est en haut de l'écran et de la carte)
static func cap(angle: float) -> String:
	return CAPS[int(round(fposmod(angle, TAU) / (TAU / 8.0))) % 8]


# --- l'œil de l'affût ---

func _draw() -> void:
	if _ouvert <= 0.0:
		return
	var a := _ouvert
	var r := 13.0
	draw_circle(_ou, r + 2.5, Color(P.ENCRE, 0.5 * a))
	draw_arc(_ou, r, 0.0, TAU, 28, Color(P.PAPIER, 0.25 * a), 2.0, true)
	if _part > 0.005:
		draw_arc(_ou, r, -PI * 0.5, -PI * 0.5 + TAU * _part, 28, Color(P.PAPIER, 0.95 * a), 2.4, true)
	I.icone(self, "oeil", _ou, 17.0, Color(1.0, 1.0, 1.0, a), _ouvert)


# --- ce que le carnet dit d'une bête ---

# la bête de cette lignée, dans ce qu'on a lu du monde ({} : on ne la retrouve pas)
static func entree(jeu_, id: String) -> Dictionary:
	var lots: Array = [jeu_.faune]
	lots.append_array(jeu_._faunes.values())
	for F in lots:
		if typeof(F) != TYPE_DICTIONARY:
			continue
		for k in F:
			for e in F[k]:
				if str(e["id"]) == id:
					return e
	return {}


# sa page : { nom, lignee, niveau, lignes (ce qu'on sait), reste (ce qu'il reste à faire, "" : rien) }
static func page(jeu_, id: String) -> Dictionary:
	var e := entree(jeu_, id)
	var s := float(jeu_.savoir.get(id, 0.0))
	var niv := 2 if s >= CONNUE else (1 if s >= OBSERVEE else 0)
	var out := {"id": id, "nom": str(jeu_.vues.get(id, id)), "lignee": e.get("lignee", {}), "niveau": niv, "lignes": [], "reste": ""}
	if e.is_empty():
		return out
	if niv == 0:
		out["reste"] = "Tu l'as croisée. Reste immobile près d'elle, sans qu'elle fuie : tu l'observeras."
		return out
	var plan: Dictionary = e["lignee"].get("plan", {})
	var masse := float(e["masse"])
	var chasseur: bool = Bestiaire.est_chasseur(plan)
	var act := str(plan.get("activite", "diurne"))
	var rodeur: bool = chasseur and act == "diurne" and masse >= 1.0
	var L: Array = out["lignes"]
	# observée : ce qu'elle est
	if not chasseur:
		L.append("Une proie.")
	elif rodeur:
		L.append("Un chasseur du jour. Elle laisse passer, tant qu'on ne l'approche pas.")
	else:
		L.append("Un chasseur de la nuit.")
	var mets: Array = []
	var diete = plan.get("diete", {})
	if typeof(diete) == TYPE_DICTIONARY:
		var cles: Array = diete.keys()
		cles.sort_custom(func(x, y): return float(diete[x]) > float(diete[y]))
		for k in cles.slice(0, 2):
			if METS.has(k):
				mets.append(METS[k])
	if not mets.is_empty():
		L.append("Elle mange %s." % " et ".join(mets))
	match act:
		"nocturne":
			L.append("Elle vit la nuit.")
		"crepusculaire":
			L.append("Elle sort à l'aube et au crépuscule.")
		"continue":
			L.append("Elle ne dort jamais vraiment.")
		_:
			L.append("Elle vit le jour.")
	L.append("On la croise à plusieurs." if float(e["sociable"]) > 0.55 else "On la croise seule.")
	L.append("Elle pèse environ %s." % (("%d kg" % int(round(masse))) if masse >= 1.0 else ("%d g" % int(round(masse * 100.0) * 10.0))))
	if niv == 1:
		out["reste"] = "Observe-la encore : tu sauras comment l'approcher, et ce qu'elle vaut."
		return out
	# connue : ce qui sert à survivre
	var pv := 8.0 + 22.0 * log(masse + 1.0) / log(10.0)
	var coups_lance := int(ceil(pv / R.DEGATS_LANCE))
	var coups_mains := int(ceil(pv / R.DEGATS_POINGS))
	var viande := clampi(int(round(pow(masse, 0.4))), 1, 6)
	var vitesse := 45.0 + 15.0 * float(plan.get("vitesse_rel", 4.0))
	if not chasseur:
		var flair := 90.0 + 230.0 * float(plan.get("perception", 0.5))
		if flair < 165.0:
			L.append("Elle se laisse approcher de près.")
		elif flair < 245.0:
			L.append("Elle fuit quand on marche vers elle. Immobile, on l'approche presque deux fois plus.")
		else:
			L.append("Elle te sent de loin. Reste immobile : c'est elle qui revient.")
		L.append("Elle court plus vite que toi." if vitesse * 1.1 > R.VITESSE else "À la course, tu la rattrapes.")
	else:
		L.append("Sa morsure prend %d de santé." % int(round(R.MORSURE + R.MORSURE_MASSE * log(masse + 1.0) / log(10.0))))
		if rodeur:
			L.append("Elle charge si on l'approche de trop près, ou si on la frappe.")
		elif float(plan.get("temperament", 0.3)) < 0.75:
			L.append("La torche la tient à distance.")
		else:
			L.append("La torche ne l'arrête pas : il te faut un feu.")
	L.append("%d coup%s de lance pour l'abattre (%d à mains nues). Elle donne %d viande%s." % [coups_lance, "s" if coups_lance > 1 else "", coups_mains, viande, "s" if viande > 1 else ""])
	var dit := Donnees.dire_memoire(e.get("memoire", {})) if typeof(e.get("memoire")) == TYPE_DICTIONARY else ""
	if dit != "":
		L.append("Ce que les veilleuses lui ont appris : %s." % dit)
	var n := int(round(float(e["effectif"])))
	L.append("Il en reste %d ici." % n if n > 1 else "Il n'en reste qu'une ici.")
	return out
