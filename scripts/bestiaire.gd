extends RefCounted
# Lisière — le bestiaire : les bêtes, dessinées par Lisière (scripts/bestiaire.gd)
# Chaque bête est une lignée vraie du monde d'Orvane ; son dessin, lui, est celui de Lisière. On ne montre plus la planche
# d'Orvane : on redessine la bête d'après le plan de corps de sa lignée (plan.corps : sa forme, ses pattes, la longueur de son
# corps, de son cou, de son museau, ses oreilles, sa queue, ses cornes, sa crête, son motif, ses organes, ses couleurs), à
# l'encre, dans les tons du jeu, et à une taille qui se lit en jouant. Une forme par fichier (scripts/bestiaire_<forme>.gd), qui
# dessine sur une planche (scripts/bestiaire_planche.gd). Une lignée sans plan de corps, ou d'une forme qu'on ne sait pas encore
# dessiner, garde sa planche d'Orvane (scripts/squelette.gd).
#   var sq := Bestiaire.lire(lignee, largeur)       # ce que la bête anime ({} : pas de dessin de Lisière pour elle)
#   var t := Bestiaire.portrait(lignee, largeur)    # la bête entière, au repos, en une image (le carnet de la fin)

const P := preload("res://scripts/palette.gd")
const Planche := preload("res://scripts/bestiaire_planche.gd")
# une forme, son fichier : chacun a une fonction statique dessiner(p), qui dessine la bête sur la planche p
const FORMES := {
	"quadrupede": "res://scripts/bestiaire_quadrupede.gd",
	"bipede": "res://scripts/bestiaire_oiseau.gd",
	"oiseau": "res://scripts/bestiaire_oiseau.gd",
	"hexapode": "res://scripts/bestiaire_hexapode.gd",
	"serpent": "res://scripts/bestiaire_serpent.gd",
}

static var _cache := {}
static var _portraits := {}
static var _scripts := {}


# la taille d'une bête à l'écran (la largeur de son dessin, en pixels du lieu), d'après sa masse. La veilleuse fait 22 pixels de
# large et 44 de haut : la plus petite bête (200 g) se voit encore (38), une bête d'un kilo se lit d'un coup d'œil (48), un
# chasseur de 35 kg lui arrive à l'épaule et s'étire sur deux fois sa hauteur (110). Un chasseur est dessiné un peu plus grand.
static func largeur_de(masse: float, chasseur_: bool) -> float:
	return clampf(48.0 * pow(maxf(masse, 0.05), 0.2) * (1.12 if chasseur_ else 1.0), 38.0, 150.0)


static func est_chasseur(plan: Dictionary) -> bool:
	var regime := str(plan.get("regime", ""))
	return regime == "carnivore" or (regime == "omnivore" and float(plan.get("masse_kg", 0.0)) >= 15.0)


static func _forme(nom: String):
	if not _scripts.has(nom):
		var chemin := str(FORMES.get(nom, ""))
		_scripts[nom] = load(chemin) if chemin != "" and ResourceLoader.exists(chemin) else null
	return _scripts[nom]


# la planche d'une lignée à cette largeur, dessinée (null : pas de plan de corps, ou une forme qu'on ne sait pas dessiner)
static func planche(lignee: Dictionary, largeur: float) -> Planche:
	var plan = lignee.get("plan", {})
	if typeof(plan) != TYPE_DICTIONARY:
		return null
	var corps = plan.get("corps", {})
	if typeof(corps) != TYPE_DICTIONARY or corps.is_empty():
		return null
	var f = _forme(str(corps.get("forme", "")))
	if f == null:
		return null
	var p := Planche.new()
	p.id = str(lignee.get("id", ""))
	p.L = largeur
	p.e = clampf(0.95 + largeur / 110.0, 1.15, 2.1)
	p.plan = plan
	p.corps = corps
	p.regime = str(plan.get("regime", "herbivore"))
	p.chasseur = est_chasseur(plan)
	p.nocturne = str(plan.get("activite", "diurne")) == "nocturne"
	p.robustesse = clampf((log(maxf(float(plan.get("masse_kg", 1.0)), 0.01)) / log(10.0) + 1.3) / 3.3, 0.0, 1.0)
	p.locomotion = plan.get("locomotion", [])
	p.traits = _traits(lignee)
	p.tons = tons(plan)
	p.r.seed = hash(p.id) & 0x7fffffff
	f.dessiner(p)
	return p


# ce que la bête anime (scripts/bete.gd), gardé par lignée et par taille
static func lire(lignee: Dictionary, largeur: float) -> Dictionary:
	var k := "%s|%d" % [str(lignee.get("id", "")), int(round(largeur * 4.0))]
	if not _cache.has(k):
		var p := planche(lignee, largeur)
		_cache[k] = p.finir() if p != null else {}
	return _cache[k]


# la bête entière, au repos : { tex, image, pos, taille, rect } ({} : pas de dessin de Lisière)
static func portrait(lignee: Dictionary, largeur: float) -> Dictionary:
	var k := "%s|%d" % [str(lignee.get("id", "")), int(round(largeur * 4.0))]
	if not _portraits.has(k):
		var p := planche(lignee, largeur)
		_portraits[k] = p.portrait() if p != null else {}
	return _portraits[k]


# les traits du phénotype le plus répandu de la lignée (« pattes-longues », « crocs-allonges »…), s'il en a
static func _traits(lignee: Dictionary) -> Array:
	var ph = lignee.get("phenotypes", [])
	if typeof(ph) != TYPE_ARRAY or ph.is_empty() or typeof(ph[0]) != TYPE_DICTIONARY:
		return []
	var t = ph[0].get("traits", [])
	return t if typeof(t) == TYPE_ARRAY else []


# --- les tons ---

# les couleurs d'une bête, accordées à la palette du jeu. La lignée a les siennes (plan.corps.couleurs : robe, sombre, ventre,
# oeil), parfois vives (un bleu, un rose) : on garde leur teinte, mais on les ramène à des pigments de carnet (moins saturés, ni
# trop clairs ni trop sombres pour le sol du lieu), un peu réchauffés par le papier.
static func tons(plan: Dictionary) -> Dictionary:
	var c: Dictionary = plan.get("corps", {}).get("couleurs", {}) if typeof(plan.get("corps", {})) == TYPE_DICTIONARY else {}
	var robe := _accorder(_rvb(c.get("robe"), Color(0.55, 0.47, 0.36)), 0.34, 0.48, 0.72)
	var dos := _accorder(_rvb(c.get("sombre"), robe.darkened(0.35)), 0.32, 0.24, 0.44)
	var ventre := _accorder(_rvb(c.get("ventre"), robe.lightened(0.35)), 0.22, 0.68, 0.88)
	var oeil := _rvb(c.get("oeil"), Color(0.2, 0.17, 0.13))
	if est_chasseur(plan):
		# (un chasseur a l'œil d'ambre : on le reconnaît, de jour comme de nuit)
		oeil = oeil.lerp(P.BRAISE, 0.6)
		oeil = Color.from_hsv(oeil.h, clampf(oeil.s, 0.55, 0.9), clampf(oeil.v, 0.75, 0.98))
	else:
		oeil = Color.from_hsv(oeil.h, minf(oeil.s, 0.6), clampf(oeil.v, 0.16, 0.5))
	return {
		"robe": robe,
		"lumiere": Planche.clair(robe),
		"ombre": Planche.sombre(robe),
		"dos": dos,
		"ventre": ventre,
		"loin": robe.darkened(0.34).lerp(P.NUIT_BLEUE, 0.18),
		"accent": _accorder(dos.lerp(P.SANG, 0.35), 0.5, 0.3, 0.55),
		"oeil": oeil,
		"encre": P.ENCRE,
		"os": Color("e6dcc2"),
		"truffe": P.ENCRE.lerp(robe, 0.12),
	}


static func _rvb(v, defaut: Color) -> Color:
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Color8(int(v[0]), int(v[1]), int(v[2]))
	return defaut


# une couleur ramenée à un pigment : sa saturation bornée, sa valeur tenue entre v0 et v1, un peu de papier dedans
static func _accorder(c: Color, sat_max: float, v0: float, v1: float) -> Color:
	var out := Color.from_hsv(c.h, minf(c.s, sat_max) * 0.92, clampf(c.v, v0, v1))
	return out.lerp(P.IVOIRE, 0.14)
