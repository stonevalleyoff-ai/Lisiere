extends RefCounted
# Lisière — le jardin (scripts/jardin.gd)
# Ce que la veilleuse sème et récolte. Avec une houe (scripts/atelier.gd), elle retourne un carré de terre ; elle y sème des
# graines, qu'elle trouve en cueillant (un buisson rend parfois des graines de baies, une touffe des graines de lin ; les épis
# d'une céréale, d'un riz sauvage, des grains, qui se mangent et se sèment) ou dans les vestiges (les simples : des herbes qui
# pansent et apaisent). Ce qui pousse veut de l'eau : la pluie, ou son arrosoir.
# Les bêtes qui broutent viennent manger ce qui pousse, si rien ne garde le jardin : elle, ou un épouvantail.
# Les carrés et l'épouvantail sont des choses posées (scripts/campement.gd les dessine) ; leur état :
#   carre       : « culture » ("" : rien de semé ; « baie », « lin », « simple », « grain »), « stade » (de 0, semé, à 3, mûr),
#                 « eau » (de 0 à 1 : la terre est humide), « broute » (de 0 à 1 : une bête y mange), « gel » (vrai : il gèle)
#   epouvantail : « regard » (un angle : d'où vient la Noire, la nuit ; sans la clé : il ne regarde rien), « alerte » (de 0 à 1)

const R := preload("res://scripts/regles.gd")
const Campement := preload("res://scripts/campement.gd")
const Faim := preload("res://scripts/noire_faim.gd")

# ce qui se cultive : son nom, sa graine, ce que rend un carré mûr, les jours qu'il lui faut (la terre humide)
# (les grains : ce qu'on cueille aux épis d'une céréale, d'un riz sauvage, est aussi ce qu'on sème ; un carré mûr en rend, avec
# ses trois de semence, de quoi faire trois gruaux, et sa paille)
const CULTURES := {
	"baie": {"nom": "Baies", "graine": "graine_baie", "donne": {"baies": 6}, "jours": 1.5},
	"lin": {"nom": "Lin", "graine": "graine_lin", "donne": {"fibre": 8}, "jours": 1.0},
	"simple": {"nom": "Simples", "graine": "graine_simple", "donne": {"simples": 3}, "jours": 2.0},
	"grain": {"nom": "Grains", "graine": "grains", "donne": {"grains": 6, "fibre": 2}, "jours": 1.5},
}
const ORDRE := ["baie", "lin", "simple", "grain"]
const NOMS_GRAINES := {"graine_baie": "graines de baies", "graine_lin": "graines de lin", "graine_simple": "graines de simples", "grains": "grains"}
const TEINTE := Color(0.72, 0.84, 0.6)
const GRIS := Color(0.75, 0.7, 0.66)
const GRAINES := 2                # ce qu'il faut de graines pour un carré
const RENDUES := 3                # ce qu'un carré mûr rend de graines
const SECHE := 0.75               # jours : une terre trempée est sèche
const ARROSAGES := 4              # ce que tient l'arrosoir
const GARDE := 230.0              # jusqu'où un épouvantail garde
const BROUTE := 6.0               # secondes : une bête mange un stade
const CHANCE_BAIE := 0.35         # un buisson cueilli rend une graine
const CHANCE_LIN := 0.25          # une touffe coupée aussi
const SIMPLES_SANTE := 22.0       # ce que des simples rendent de santé
const SIMPLES_PEUR := 25.0        # et ôtent de peur
const CARRES_MAX := 12

var jeu
var _dit := {}
var _t := 0.0


func _atelier():
	return jeu.atelier


func carres() -> Array:
	return _atelier().poses.filter(func(s): return is_instance_valid(s) and str(s.genre) == "carre")


# --- ce que la page du sac demande ---

# ce qui l'empêche de bêcher un carré ici ("" : rien)
func empeche_becher() -> String:
	var A = _atelier()
	if A.possede("houe") <= 0:
		return "Il te faut une houe."
	if carres().size() >= CARRES_MAX:
		return "Ton jardin est assez grand."
	var p: Vector2 = A._devant("carre")
	if float(jeu.climat.eau(p)) > 0.2:
		return "Le sol est sous l'eau."
	if float(jeu.climat.neige_sol) > 0.5:
		return "La terre est gelée sous la neige."
	for o in jeu.monde.autour(p, 34.0):
		if float(o.rayon) > 0.0 or str(o.genre) == "buisson":
			return "Il n'y a pas la place ici."
	for s in A.poses:
		if is_instance_valid(s) and s.position.distance_to(p) < 30.0 + float(Campement.rayon(str(s.genre))):
			return "Il n'y a pas la place ici."
	for f in jeu.feux:
		if is_instance_valid(f) and f.position.distance_to(p) < 60.0:
			return "Trop près du feu."
	return ""


# elle retourne la terre devant elle : un carré, où semer
func becher() -> bool:
	var pourquoi := empeche_becher()
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var A = _atelier()
	var p: Vector2 = A._devant("carre")
	for o in jeu.monde.autour(p, 30.0):
		if float(o.rayon) <= 0.0 and str(o.genre) in ["brindille", "touffe", "fleur", "cepe", "amanite", "aquatique"]:
			jeu.monde.retirer(o)
	A._creer("carre", p, {"culture": "", "stade": 0.0, "eau": 0.3 + 0.7 * float(jeu.climat.boue)})
	jeu.joueur.geste_atelier("becher")
	jeu.ui.message("Un carré de terre retournée. Il lui faut des graines, et de l'eau.", TEINTE)
	return true


# une herbe de l'herbier, semée (« foret:ombelle » : scripts/botanique.gd) ?
static func est_une_herbe(culture: String) -> bool:
	return culture.contains(":")


# ce qu'on sait d'une culture : son nom, ce qu'on sème, ce qu'elle rend, ses jours ({} : ce n'en est pas une). Une herbe
# reconnue se sème de ses propres plants (deux), et en rend cinq
func info(culture: String) -> Dictionary:
	if CULTURES.has(culture):
		return CULTURES[culture]
	if not est_une_herbe(culture) or jeu.get("botanique") == null:
		return {}
	var B = jeu.botanique
	return {"nom": B.nom(culture), "graine": B.cle(culture), "donne": {B.cle(culture): int(B.RECOLTE_JARDIN)}, "jours": 1.5}


func graines(culture: String) -> int:
	return int(jeu.joueur.inventaire.get(str(info(culture)["graine"]), 0))


# ce qu'elle sèmerait là, sans choisir : ce dont elle a le plus de graines ("" : elle n'en a pas assez). Les grains, qui se
# mangent aussi, en dernier : seulement si elle n'a pas d'autres graines
func culture_par_defaut() -> String:
	var mieux := ""
	var n0 := GRAINES - 1
	for c in ORDRE:
		if c != "grain" and graines(c) > n0:
			n0 = graines(c)
			mieux = c
	if mieux == "" and graines("grain") >= GRAINES:
		mieux = "grain"
	return mieux


func semer(s, culture: String) -> bool:
	if s == null or info(culture).is_empty() or str(s.etat.get("culture", "")) != "":
		return false
	if Faim.est_epave(s):
		jeu.ui.message("La terre est piétinée : retourne-la d'abord (« Agir »).", GRIS)
		return false
	if est_une_herbe(culture) and str(jeu.botanique.empeche_semer(culture)) != "":
		jeu.ui.message(str(jeu.botanique.empeche_semer(culture)), GRIS)
		return false
	if graines(culture) < GRAINES:
		jeu.ui.message("Il te faut %d %s." % [GRAINES, str(NOMS_GRAINES.get(info(culture)["graine"], "plants"))], GRIS)
		return false
	var inv: Dictionary = jeu.joueur.inventaire
	var g := str(info(culture)["graine"])
	inv[g] = int(inv[g]) - GRAINES
	s.etat["culture"] = culture
	s.etat["stade"] = 0.0
	jeu.joueur.geste_atelier("semer")
	jeu.sons.atelier("tresse", -6.0, 1.3, s.position)
	jeu.ui.message("%s : semé. %s" % [str(info(culture)["nom"]), "La terre est humide." if float(s.etat.get("eau", 0.0)) > 0.15 else "La terre est sèche : il lui faut de l'eau."], TEINTE)
	return true


# l'arrosoir : ce qu'il tient d'arrosages
func arrosages() -> int:
	return int(jeu.joueur.inventaire.get("arrosages", 0))


# elle le remplit : les pieds dans l'eau, ou au récupérateur (deux gorgées de sa cuve)
func remplir(cuve = null) -> bool:
	var A = _atelier()
	if A.possede("arrosoir") <= 0:
		return false
	if arrosages() >= ARROSAGES:
		jeu.ui.message("L'arrosoir est plein.", GRIS)
		return false
	if cuve != null:
		if float(cuve.etat.get("eau", 0.0)) < 1.0:
			return false
		cuve.etat["eau"] = maxf(0.0, float(cuve.etat["eau"]) - 2.0)
	elif float(jeu.climat.eau(jeu.joueur.position)) < 0.3:
		return false
	jeu.joueur.inventaire["arrosages"] = ARROSAGES
	jeu.joueur.geste_atelier("boire")
	jeu.sons.atelier("gourde", 0.0, 0.85)
	jeu.ui.message("L'arrosoir est plein : %d arrosages." % ARROSAGES, TEINTE)
	return true


func arroser(s) -> bool:
	if s == null or _atelier().possede("arrosoir") <= 0:
		return false
	if arrosages() <= 0:
		jeu.ui.message("L'arrosoir est vide. Il se remplit au récupérateur, ou les pieds dans l'eau.", GRIS)
		return false
	jeu.joueur.inventaire["arrosages"] = arrosages() - 1
	s.etat["eau"] = 1.0
	jeu.joueur.geste_atelier("arroser")
	jeu.sons.atelier("gourde", -3.0, 1.2, s.position)
	return true


func mur(s) -> bool:
	return str(s.etat.get("culture", "")) != "" and float(s.etat.get("stade", 0.0)) >= 3.0


func recolter(s) -> bool:
	if s == null or not mur(s):
		return false
	var culture := str(s.etat["culture"])
	var c: Dictionary = info(culture)
	var A = _atelier()
	var dits := PackedStringArray()
	# (des grains : ce qu'on récolte est aussi ce qu'on sème, les grains de semence sont dans la récolte ; une herbe, elle, se
	# ressème d'elle-même, plus bas)
	var semence := bool(c["donne"].has(str(c["graine"]))) and not est_une_herbe(culture)
	for k in c["donne"]:
		var n: int = A.ranger(k, int(c["donne"][k]) + (RENDUES if semence and k == str(c["graine"]) else 0))
		dits.append("+%d %s" % [n, str(c["nom"]).to_lower() if est_une_herbe(culture) else str(R.NOMS.get(k, A.NOMS_MATIERES.get(k, k)))])
	var inv: Dictionary = jeu.joueur.inventaire
	if est_une_herbe(culture):
		# (une herbe : ses plants se ressèment d'eux-mêmes, on en garde pour le prochain carré)
		s.etat["culture"] = ""
		s.etat["stade"] = 0.0
		jeu.joueur.geste_atelier("fouiller")
		jeu.sons.jouer("herbe", -4.0, 1.0)
		jeu.ui.message("%s." % ", ".join(dits), TEINTE)
		return true
	if not semence:
		inv[str(c["graine"])] = int(inv.get(str(c["graine"]), 0)) + RENDUES
	s.etat["culture"] = ""
	s.etat["stade"] = 0.0
	jeu.joueur.geste_atelier("fouiller")
	jeu.sons.jouer("herbe", -4.0, 1.0)
	if semence:
		jeu.ui.message("%s : %s. Gardes-en pour semer." % [str(c["nom"]), ", ".join(dits)], TEINTE)
	else:
		jeu.ui.message("%s : %s, et %d graines." % [str(c["nom"]), ", ".join(dits), RENDUES], TEINTE)
	return true


# un carré que la Noire a piétiné (scripts/noire_faim.gd) : elle en retourne la terre, de ses mains ; il se sème de nouveau
func retourner(s) -> bool:
	if not Faim.est_epave(s):
		return false
	for k in ["saccage", "cote", "mordu", "nuit"]:
		s.etat.erase(k)
	s.redessiner(true)
	jeu.joueur.geste_atelier("becher")
	jeu.ui.message("Tu retournes la terre piétinée. Le carré se sème de nouveau.", TEINTE)
	return true


# « Agir », devant un carré : ce qu'il y a de mieux à y faire
func agir(s) -> void:
	if retourner(s):
		return
	var culture := str(s.etat.get("culture", ""))
	if culture == "":
		var c := culture_par_defaut()
		if c == "":
			jeu.ui.message("Un carré vide. Il te faut des graines : les buissons, les touffes en rendent parfois.", GRIS)
		else:
			semer(s, c)
		return
	if mur(s):
		recolter(s)
		return
	if float(s.etat.get("eau", 0.0)) < 0.5 and _atelier().possede("arrosoir") > 0:
		arroser(s)
		return
	jeu.ui.message(dire(s), TEINTE)


# où en est ce carré, en une phrase
func dire(s) -> String:
	var culture := str(s.etat.get("culture", ""))
	if culture == "":
		return "Un carré vide."
	var nom := str(info(culture)["nom"])
	var stade := float(s.etat.get("stade", 0.0))
	if stade >= 3.0:
		return "%s : mûr." % nom
	var ou := "sort de terre" if stade < 1.0 else ("pousse" if stade < 2.0 else "se forme")
	if bool(s.etat.get("gel", false)):
		return "%s : le gel l'arrête." % nom
	if float(s.etat.get("eau", 0.0)) <= 0.15:
		return "%s : la terre est sèche, rien ne pousse." % nom
	return "%s : ça %s." % [nom, ou]


# des simples : elle s'en panse (la santé revient, la peur s'apaise)
func panser() -> bool:
	var inv: Dictionary = jeu.joueur.inventaire
	if int(inv.get("simples", 0)) <= 0:
		return false
	inv["simples"] = int(inv["simples"]) - 1
	var j = jeu.joueur
	j.sante = minf(100.0, float(j.sante) + SIMPLES_SANTE)
	j.peur = maxf(0.0, float(j.peur) - SIMPLES_PEUR)
	j.geste_atelier("boire")
	jeu.ui.message("Des simples, mâchés : la douleur recule, le cœur se calme.", TEINTE)
	return true


# --- ce que le jeu en lit ---

# cueillir rend parfois des graines
func cueilli(genre: String) -> void:
	var g := ""
	if genre == "buisson" and randf() < CHANCE_BAIE:
		g = "graine_baie"
	elif genre == "touffe" and randf() < CHANCE_LIN:
		g = "graine_lin"
	if g == "":
		return
	var inv: Dictionary = jeu.joueur.inventaire
	inv[g] = int(inv.get(g, 0)) + 1
	if not _dit.has(g):
		_dit[g] = true
		jeu.ui.message("Des %s. Avec une houe, elles se sèment." % str(NOMS_GRAINES[g]), TEINTE)


# un épouvantail garde-t-il ce point ?
func garde(p: Vector2) -> bool:
	for s in _atelier().poses:
		if is_instance_valid(s) and str(s.genre) == "epouvantail" and s.position.distance_to(p) < GARDE and not Faim.est_epave(s):
			return true
	return false


# ce qui tente cette bête dans le jardin : un carré où ça pousse, que rien ne garde (null : rien)
func tentation(b):
	var mieux = null
	var d0: float = float(b.flair) * 1.3
	for s in carres():
		var culture := str(s.etat.get("culture", ""))
		if culture == "" or float(s.etat.get("stade", 0.0)) < 1.0:
			continue
		# (une herbe vénéneuse ou âcre : elles n'y touchent pas — un carré qui se garde tout seul)
		if est_une_herbe(culture) and not bool(jeu.botanique.se_broute(culture)):
			continue
		var d: float = s.position.distance_to(b.position)
		if d < d0 and not garde(s.position):
			d0 = d
			mieux = s
	return mieux


# une bête y mange : ce qui poussait recule, jusqu'à la terre nue
func mangee(s, delta: float) -> void:
	s.etat["broute"] = 1.0
	s.etat["stade"] = float(s.etat.get("stade", 0.0)) - delta / BROUTE
	if float(s.etat["stade"]) <= 0.0:
		s.etat["culture"] = ""
		s.etat["stade"] = 0.0
		if not _dit.has("broute"):
			_dit["broute"] = true
			jeu.ui.message("Une bête a mangé ce qui poussait. Un épouvantail les tient à l'écart.", Color(0.95, 0.5, 0.42))


# --- chaque image ---

func maj(delta: float) -> void:
	var C = jeu.climat
	if C == null:
		return
	_t += delta
	var pluie: float = float(C.pluie)
	var gel: bool = float(C.neige_sol) > 0.3 or float(C.air) < 0.16
	var seche := delta / (SECHE * R.DUREE) * (1.0 + 2.0 * maxf(0.0, float(C.chaleur)) / 0.3)
	var nuit: bool = jeu.jour_du_ciel() <= 0.0
	var N = jeu.noire
	for s in _atelier().poses:
		if not is_instance_valid(s):
			continue
		match str(s.genre):
			"carre":
				var eau: float = float(s.etat.get("eau", 0.0))
				eau = minf(1.0, eau + pluie * delta * 0.25) if pluie > 0.05 else maxf(0.0, eau - seche)
				s.etat["eau"] = eau
				s.etat["gel"] = gel
				s.etat["broute"] = maxf(0.0, float(s.etat.get("broute", 0.0)) - delta * 2.0)
				var culture := str(s.etat.get("culture", ""))
				if culture != "" and eau > 0.15 and not gel and float(s.etat.get("broute", 0.0)) <= 0.0:
					var avant: float = float(s.etat.get("stade", 0.0))
					var apres := minf(3.0, avant + delta * 3.0 / (float(info(culture)["jours"]) * R.DUREE))
					s.etat["stade"] = apres
					if avant < 3.0 and apres >= 3.0 and jeu.joueur.position.distance_to(s.position) < 900.0:
						jeu.ui.message("%s : c'est mûr." % str(info(culture)["nom"]), TEINTE)
			"epouvantail":
				# (en pièces : scripts/noire_faim.gd ; il ne regarde ni ne tremble plus)
				if Faim.est_epave(s):
					continue
				# (la nuit, il regarde d'où vient la Noire ; plus elle est près, plus il tremble)
				var alerte := 0.0
				# (à son cinquième acte, elle vient dès le crépuscule : il la regarde venir avant la nuit ; partie, il ne la cherche plus)
				if N != null and int(N.acte) >= 2 and not bool(N.partie) and (nuit or bool(N.faim.soir)):
					var ou: Vector2 = N.corps.position if N.presente() and N.corps != null and is_instance_valid(N.corps) else Vector2(N.taniere)
					s.etat["regard"] = (ou - s.position).angle()
					if N.presente():
						alerte = clampf(1.0 - (ou.distance_to(s.position) - 300.0) / 900.0, 0.0, 1.0)
				else:
					s.etat.erase("regard")
				s.etat["alerte"] = alerte
