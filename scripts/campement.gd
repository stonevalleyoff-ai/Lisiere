extends Node2D
# Lisière — une chose posée dans le lieu (scripts/campement.gd)
# Ce que la veilleuse monte de ses mains et laisse au sol : l'établi, la tente, le hamac, le récupérateur d'eau, le filet, le
# cerf-volant ; et les vestiges d'autres veilleuses, où elle trouve de la ferraille. Ici, son dessin et sa vie (elle bouge au
# vent, se remplit, s'use) ; ce qu'elle fait au jeu est dans scripts/atelier.gd, qui lui dit son état :
#   genre  : « etabli », « tente », « hamac », « recuperateur », « filet », « cerf_volant », « vestige » ; et, du jardin et de
#            l'élevage (scripts/jardin.gd, scripts/elevage.gd) : « carre », « epouvantail », « piquet », « mangeoire », « appat »
#   etat   : ce que l'atelier lui dit, et qu'elle montre
#     etabli       : « travail » (de 0 à 1 : on y fabrique quelque chose, des copeaux volent)
#     tente, hamac : « occupe » (vrai : la veilleuse y dort)
#     recuperateur : « eau » (de 0 à 6 : ce qu'il tient)
#     filet        : « prise » ({ nom, masse } : une bête s'y est prise, elle se débat)
#     cerf_volant  : « vent » (de 0 à 1), « branche » (vrai : les piles sont au fil), « charge » (de 0 à 1), « foudre » (un
#                    instant : la foudre vient de le prendre)
#     vestige      : « fouille » (vrai : il n'y a plus rien), « riche » (0 ou 1)
#     carre        : « culture » ("", « baie », « lin », « simple »), « stade » (de 0, semé, à 3, mûr, en continu), « eau » (de 0,
#                    la terre sèche, à 1), « broute » (de 0 à 1 : une bête y mange), « gel » (vrai : du givre)
#     epouvantail  : « regard » (un angle du lieu, la nuit seulement : sa tête y tourne, lentement ; sans lui, il regarde
#                    devant lui), « alerte » (de 0 à 1 : il tremble)
#     piquet       : « attache » (vrai : une bête y est liée ; sa longe, c'est elle qui la dessine, jusqu'à l'anneau)
#     mangeoire    : « foin » (de 0 à 12 : les fibres qu'on y a mises)
#     appat        : « reste » (de 1 à 0 : ce qu'il reste de baies)
#     coffre       : « ouvert » (vrai : on l'a forcé, il est vide) ; « leve » (de 0 à 1 : l'ouverture, que l'atelier met à 0
#                    en l'ouvrant et que le coffre fait avancer lui-même ; sans elle, un coffre ouvert l'est tout à fait)
# Son pied est à l'origine (0, 0) : le lieu trie ce qui s'y tient par hauteur (monde.gd).
# Le dessin : à l'encre, dans la peinture des arbres et des rochers (scripts/decor_pinceau.gd, la matière qui ne bouge pas de
# scripts/objet.gd). Chaque chose a un fond, dessiné une fois (et de nouveau quand son état change : la neige, l'eau, un pan
# fermé), et ce qui remue (la toile au vent, les gouttes, une bête dans la maille), redessiné quinze fois par seconde au plus
# (dix sur un téléphone ; image par image pour ce qui vole ou éclate), et pas du tout hors de l'écran. Ce qui brille (les
# étincelles de la charge, la foudre) est sur un calque à part, que la nuit n'éteint pas.
# Le vent est celui de l'herbe autour d'elle (monde.vent, là où elle est posée) ; la pluie et la neige, celles du climat.
#   Campement.rayon(genre)    son encombrement au sol (0 : on marche dessus : le filet, le carré, l'appât)
#   Campement.hauteur(genre)  sa hauteur, au-dessus de son pied
#   Campement.popote(ci, t)   la popote sur le feu, dessinée à l'origine de ci, d'un seul appel
#   coup()                    un coup de maillet sur l'établi : une gerbe de copeaux (sans lui, « travail » les fait voler seul)
#   foudroyer()               la foudre prend le cerf-volant (comme « foudre » qui passe de 0 à 1 dans son état)
#   Campement.ANNEAU          où tient l'anneau du piquet, depuis son pied : là où finit la longe d'une bête à l'attache
# Le carré et l'appât, sur lesquels on marche, se trient en plusieurs fois (_poser_a_plat) : la terre passe sous les pieds,
# les rangs de plantes devant ou derrière qui les traverse.

const P := preload("res://scripts/palette.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const Objet := preload("res://scripts/objet.gd")
const Herbe := preload("res://scripts/herbe.gd")
const T := preload("res://scripts/effets_textures.gd")

const PROF := 0.5                   # la vue de trois quarts : ce qui vient vers nous d'un pixel descend d'un demi
const ENCRE := Color(0.086, 0.075, 0.059, 0.92)
# les matières, tirées de la palette
const TOILE := Color("b9a585")      # la bâche : une toile enduite, entre l'ivoire et la terre
const TOILE_CLAIR := Color("d2c3a2")
const TOILE_OMBRE := Color("7b6f5e")
const CORDE := Color("c4a877")      # la fibre tressée
const BOIS := Color("8a6a45")       # le bois pelé d'une perche
const BOIS_CLAIR := Color("c2a57c") # le bois fendu, un copeau
const ECORCE := Color("4a3c2c")
const CUIR := Color("6e573c")
const CUIR_CLAIR := Color("9a7b55")
const CUIR_OMBRE := Color("4a3a28")
const ROUILLE := Color("8a4a2f")    # la ferraille : la terre qui tire vers la braise
const METAL := Color("4b4d55")      # la cendre qui tire vers la lune
const METAL_CLAIR := Color("858b97")
const CUIVRE := Color("d5883f")
const EAU := Color("46587f")
const NEIGE := Color("f1ebdc")
const NEIGE_OMBRE := Color("b9c0cf")
const OS_PALE := Color("d9cfb4")         # l'os d'une scie, d'une alêne
const BAIE := Color("a1321f")
const CADENCE := 1.0 / 15.0         # ce qui remue doucement : pas plus de quinze fois par seconde
const VENT_MIN := 0.3               # le vent qu'il faut au cerf-volant (celui de scripts/atelier.gd)
const ALTITUDE := 168.0             # la hauteur où vole le cerf-volant, au-dessus de son pied
# la tente : sa demi-largeur, sa demi-longueur, sa hauteur ; l'axe de son faîte au sol (l'entrée vient vers nous, un peu à gauche)
const TENTE_W := 20.0
const TENTE_L := 27.0
const TENTE_H := 31.0
const TENTE_A := Vector2(-0.479, 0.878)
const TENTE_B := Vector2(0.878, 0.479)
# le hamac : la demi-longueur de sa toile, la hauteur de ses bouts
const HAMAC_L := 22.0
const HAMAC_Z := 17.0
# le carré de jardin : où sont ses trois rangs, du fond vers nous (en pixels de l'écran, depuis son milieu)
const CARRE_RANGS := [-6.5, 0.5, 7.5]
const ANNEAU := Vector2(2.0, -9.0)
const BOITES := {
	"etabli": Rect2(-44.0, -40.0, 96.0, 62.0), "tente": Rect2(-44.0, -58.0, 90.0, 88.0), "hamac": Rect2(-110.0, -70.0, 220.0, 150.0),
	"recuperateur": Rect2(-30.0, -44.0, 60.0, 66.0), "filet": Rect2(-40.0, -30.0, 80.0, 50.0),
	"cerf_volant": Rect2(-60.0, -900.0, 260.0, 930.0), "vestige": Rect2(-50.0, -52.0, 100.0, 76.0), "coffre": Rect2(-24.0, -34.0, 48.0, 46.0),
	"carre": Rect2(-30.0, -32.0, 60.0, 52.0), "epouvantail": Rect2(-28.0, -54.0, 60.0, 62.0), "piquet": Rect2(-16.0, -20.0, 32.0, 30.0),
	"mangeoire": Rect2(-24.0, -30.0, 48.0, 42.0), "appat": Rect2(-12.0, -8.0, 24.0, 16.0),
}

static var _pinceau

var jeu
var genre := ""
var etat := {}

var _graine := 0
var _t := 0.0                   # l'horloge du jeu (le vent, la pluie : elle file quand la veilleuse dort)
var _tr := 0.0                  # l'horloge vraie (un souffle, un éclair : ils ne s'emballent pas)
var _dt := 0.0
var _attente := 0.0
var _cle := "?"
var _vif: Node2D                # ce qui remue, par-dessus le fond
var _eclat: Node2D              # ce qui brille : additif, hors de l'ombre (créé quand il le faut)
var _mobile := false
var _boite := Rect2(-44.0, -58.0, 90.0, 88.0)
var _vent := 0.0                # le vent ici, de 0 à 1, sans à-coups
var _pluie := 0.0
var _neige := 0.0
var _mouille := 0.0             # ce que la pluie a trempé (il sèche lentement)
# l'établi
var _copeaux: Array = []        # ce qui vole : [où, vitesse, tour, vrille, âge, vie, sol, sorte]
var _copeaux_sol := 0           # ce qui est retombé, et reste
var _coup_dans := 0.0
# le hamac
var _arbre = null               # le tronc où il est noué (null : deux piquets)
var _arbre_vu := 0.0
var _axe := Vector2.RIGHT       # du piquet vers le tronc, au sol
var _travers := Vector2.DOWN    # en travers du hamac, vers nous
var _court := 1.0               # ce que la vue raccourcit de sa longueur
var _sens := 1.0
var _tronc := Vector2.ZERO      # où est le tronc, depuis le pied du hamac
var _occupe := 0.0              # de 0 (vide) à 1 (un corps le creuse), sans à-coups
# le filet
var _pris := false              # une bête s'y débat
var _prise_t := 0.0             # depuis quand (à l'horloge vraie)
# le cerf-volant
var _monte := 0.0               # de 0 (au sol, replié) à 1 (là-haut)
var _foudre_vue := false
var _foudre_t := -1.0           # depuis que la foudre l'a pris (-1 : rien)
var _foudre_graine := 0
var _roussi := false            # la foudre l'a pris une fois : il en garde la marque
var _lueur: PointLight2D
# le carré, l'appât
var _sol: Node2D                # la terre, triée par son bord du fond (ce sur quoi l'on marche)
var _rangs: Array = []          # les rangs de plantes de devant (celui du fond est _vif)
var _sec := 0.0                 # la soif des plantes, de 0 à 1, sans à-coups
# l'épouvantail
var _tete := PI * 0.5           # où regarde sa tête (un angle du lieu ; vers nous : un quart de tour)
var _secousse := Vector2.ZERO   # ce dont il tremble, à cette image
# le coffre
var _leve := 0.0                # son ouverture, de 0 (fermé) à 1 (le couvercle rejeté en arrière)
var _poussiere := -1.0          # depuis que le couvercle est retombé (-1 : rien ne vole)
var _luit := false              # un reflet passe sur sa serrure
var _efface := false            # ce qui remuait vient de finir : un dernier dessin, pour l'ôter


# son encombrement au sol, pour qu'on ne marche pas dedans (0 : on marche dessus, et les bêtes aussi)
static func rayon(g: String) -> float:
	match g:
		"etabli":
			return 21.0
		"tente":
			return 27.0
		"hamac":
			return 13.0
		"recuperateur":
			return 17.0
		"cerf_volant":
			return 6.0
		"vestige":
			return 19.0
		"coffre":
			return 11.0
		"epouvantail":
			return 7.0
		"piquet":
			return 5.0
		"mangeoire":
			return 15.0
	return 0.0


# sa hauteur, en pixels au-dessus de son pied (le cerf-volant : son piquet ; sa voilure vole à ALTITUDE)
static func hauteur(g: String) -> float:
	match g:
		"etabli":
			return 27.0
		"tente":
			return 36.0
		"hamac":
			return 25.0
		"recuperateur":
			return 33.0
		"filet":
			return 4.0
		"cerf_volant":
			return 17.0
		"vestige":
			return 37.0
		"coffre":
			return 15.0
		"carre":
			return 14.0
		"epouvantail":
			return 46.0
		"piquet":
			return 14.0
		"mangeoire":
			return 23.0
		"appat":
			return 4.0
	return 10.0


static func pinceau():
	if _pinceau == null:
		_pinceau = Pinceau.new()
	return _pinceau


func _ready() -> void:
	add_to_group("campement")
	_graine = absi(hash(Vector2i(position))) % 1000003
	_mobile = jeu != null and str(jeu.get("qualite")) == "mobile"
	_boite = BOITES.get(genre, _boite)
	Objet.matieres()
	material = Objet.fixe
	_vif = Calque.new()
	_vif.hote = self
	_vif.quoi = "vif"
	_vif.material = Objet.fixe
	add_child(_vif)
	if genre == "hamac":
		_chercher_arbre()
	if genre == "carre" or genre == "appat":
		_poser_a_plat()
	_sec = _soif()
	_tete = _regard_voulu()
	_occupe = 1.0 if bool(etat.get("occupe", false)) else 0.0
	_pris = etat.has("prise")
	_prise_t = -5.0
	_foudre_vue = _vrai(etat.get("foudre", false))
	if genre == "coffre" and bool(etat.get("ouvert", false)):
		_leve = clampf(float(etat.get("leve", 1.0)), 0.0, 1.0)
	_lire(0.0)
	_vent = _vent_ici()
	_mouille = 1.0 if _pluie > 0.3 else 0.0
	_monte = 1.0 if _vent_du_fil() >= VENT_MIN else 0.0
	_attente = CADENCE * float(_graine % 97) / 97.0


func _process(delta: float) -> void:
	if jeu != null and jeu.en_pause:
		return
	var reel := delta / maxf(Engine.time_scale, 0.01)
	_t += delta
	_tr += reel
	_dt += delta
	_attente -= reel
	if _attente > 0.0:
		return
	var dt := _dt
	_dt = 0.0
	_lire(dt)
	if not _a_l_ecran():
		_attente = 0.3
		return
	_attente = _cadence()
	redessiner()


# ce qui a changé se redessine : le fond s'il n'est plus le même, ce qui remue, ce qui brille
func redessiner(tout: bool = false) -> void:
	var cle := _cle_du_fond()
	var change := cle != _cle or tout
	if change:
		_cle = cle
		queue_redraw()
		if _sol != null:
			_sol.queue_redraw()
	if change or _remue():
		_vif.queue_redraw()
		for c in _rangs:
			c.queue_redraw()
	if _eclat != null:
		_eclat.visible = _brille()
		if _eclat.visible:
			_eclat.queue_redraw()


func _draw() -> void:
	if _sol == null:
		_peindre(self, "fond")


func _peindre(ci: CanvasItem, quoi: String) -> void:
	var p = pinceau()
	p.commencer(ci.get_canvas_item())
	# (un calque posé ailleurs qu'au pied, pour le tri : son dessin, lui, reste au pied)
	if ci != self and ci.position != Vector2.ZERO:
		RenderingServer.canvas_item_add_set_transform(ci.get_canvas_item(), Transform2D(0.0, -ci.position))
	match quoi:
		"fond":
			match genre:
				"etabli":
					_etabli(p)
				"tente":
					_tente(p)
				"hamac":
					_hamac(p)
				"recuperateur":
					_recuperateur(p)
				"filet":
					_ombre(p, Vector2(1.0, 1.0), 31.0, 10.5, 0.2)
					if not etat.has("prise"):
						_filet(p)
				"cerf_volant":
					_cerf_volant(p)
				"vestige":
					_vestige(p)
				"coffre":
					_coffre(p)
				"carre":
					_carre(p)
				"epouvantail":
					_epouvantail(p)
				"piquet":
					_pieu(p)
				"mangeoire":
					_mangeoire(p)
				"appat":
					_appat(p)
		"vif":
			match genre:
				"etabli":
					_etabli_vif(p)
				"tente":
					_tente_vif(p)
				"hamac":
					_hamac_vif(p)
				"recuperateur":
					_recuperateur_vif(p)
				"filet":
					if etat.has("prise"):
						_filet(p)
				"cerf_volant":
					_cerf_volant_vif(p)
				"vestige":
					_vestige_vif(p)
				"coffre":
					_coffre_vif(p)
				"carre":
					_carre_vif(p, int(ci.get("rang")))
				"epouvantail":
					_epouvantail_vif(p)
				"mangeoire":
					_mangeoire_vif(p)
		"eclat":
			if genre == "cerf_volant":
				_cerf_volant_eclat(p)
	p.finir()


# --- ce qu'elle lit du jeu, quinze fois par seconde ---

func _lire(dt: float) -> void:
	var C = jeu.climat if jeu != null else null
	_pluie = float(C.pluie) if C != null else 0.0
	_neige = float(C.neige_sol) if C != null else 0.0
	_mouille = move_toward(_mouille, 1.0 if _pluie > 0.05 else 0.0, dt * (0.3 if _pluie > 0.05 else 0.03))
	_vent = lerpf(_vent, _vent_ici(), clampf(dt * 3.0, 0.0, 1.0))
	match genre:
		"etabli":
			_lire_etabli(dt)
		"tente", "hamac":
			_occupe = move_toward(_occupe, 1.0 if bool(etat.get("occupe", false)) else 0.0, dt * 2.5)
			if genre == "hamac":
				# (l'arbre abattu, brûlé : le hamac se retend entre deux piquets)
				_arbre_vu -= dt
				if _arbre_vu <= 0.0:
					_arbre_vu = 2.0
					if _arbre != null and (not is_instance_valid(_arbre) or not _est_un_arbre(_arbre)):
						_chercher_arbre()
						_cle = "?"
		"carre":
			# (arrosées, les plantes se redressent en deux secondes ; elles mettent plus longtemps à pencher)
			var soif := _soif()
			_sec = move_toward(_sec, soif, dt * (0.5 if soif < _sec else 0.12))
		"epouvantail":
			# (sa tête tourne lentement : on ne la voit pas bouger, on voit qu'elle a tourné)
			_tete = rotate_toward(_tete, _regard_voulu(), dt * 0.3)
		"coffre":
			_lire_coffre(dt)
		"filet":
			if etat.has("prise") != _pris:
				_pris = not _pris
				_prise_t = _tr
				_cle = "?"
		"cerf_volant":
			var cible := 1.0 if _vent_du_fil() >= VENT_MIN else 0.0
			_monte = move_toward(_monte, cible, dt * (0.5 if cible > _monte else 0.16))
			var f := _vrai(etat.get("foudre", false))
			if f and not _foudre_vue:
				foudroyer()
			_foudre_vue = f
			if _lueur != null:
				_lueur.energy = 2.6 * _eclair()
			if _foudre_t >= 0.0 and _tr - _foudre_t > 0.9:
				_foudre_t = -1.0
				if _lueur != null:
					_lueur.queue_free()
					_lueur = null
			if _eclat == null and (_charge_en_cours() or _foudre_t >= 0.0):
				_eclat = Calque.new()
				_eclat.hote = self
				_eclat.quoi = "eclat"
				_eclat.material = T.materiau(true, false)
				add_child(_eclat)


# le vent là où elle est posée : celui de l'herbe et des feuillages autour d'elle (monde.vent), de 0 à 1
func _vent_ici() -> float:
	if jeu == null:
		return 0.0
	var m = jeu.monde
	if m != null and m.has_method("vent"):
		return clampf((float(m.vent(position)) - 0.2) / 1.15, 0.0, 1.0)
	return clampf(float(jeu.vent()), 0.0, 1.0)


# le vent que l'atelier dit au cerf-volant (celui qui charge les piles) ; sans lui, celui d'ici
func _vent_du_fil() -> float:
	return clampf(float(etat.get("vent", _vent)), 0.0, 1.0)


static func _vrai(v) -> bool:
	return (typeof(v) == TYPE_BOOL and v) or ((typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0)


func _a_l_ecran() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var vue: Rect2 = get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return vue.intersects(Rect2(global_position + _boite.position, _boite.size))


# le temps jusqu'au prochain regard : ce qui vole, se débat ou éclate se suit image par image ; ce qui remue doucement,
# quinze fois par seconde (dix sur un téléphone)
func _cadence() -> float:
	if not _copeaux.is_empty() or _foudre_t >= 0.0:
		return 0.0
	# (le couvercle qui se lève, sa poussière : une seconde et demie, image par image)
	if genre == "coffre" and _coffre_bouge():
		return (1.0 / 30.0) if _mobile else 0.0
	if genre == "filet" and _pris and _sursaut() > 0.0:
		return (1.0 / 20.0) if _mobile else 0.0
	if genre == "cerf_volant" and _monte > 0.02:
		return (1.0 / 20.0) if _mobile else (1.0 / 30.0)
	# (des tiges sous la dent d'une bête, un épouvantail qui tremble : image par image, ou presque)
	if (genre == "carre" and float(etat.get("broute", 0.0)) > 0.0) or (genre == "epouvantail" and float(etat.get("alerte", 0.0)) > 0.02):
		return (1.0 / 20.0) if _mobile else 0.0
	# (les plantes ploient lentement : dix fois par seconde leur suffisent, sept sur un téléphone)
	if genre == "carre":
		return CADENCE * (2.0 if _mobile else 1.5)
	return CADENCE * (1.5 if _mobile else 1.0)


# ce qui remue se redessine-t-il ? (rien ne bouge : rien ne se redessine)
func _remue() -> bool:
	match genre:
		"etabli":
			return not _copeaux.is_empty()
		"tente":
			return _vent > 0.02 or _pluie > 0.02 or (_occupe > 0.0 and _occupe < 1.0) or bool(etat.get("occupe", false))
		"hamac":
			return _vent > 0.03 or _pluie > 0.05 or _occupe > 0.0
		"recuperateur":
			return _vent > 0.05 or _pluie > 0.02
		"filet":
			return _pris
		"cerf_volant":
			return _monte > 0.0
		"vestige":
			return _vent > 0.03
		"coffre":
			return _coffre_bouge() or _luit or _efface
		"carre":
			return str(etat.get("culture", "")) != "" and float(etat.get("stade", 0.0)) >= 0.25 and (_vent > 0.02 or float(etat.get("broute", 0.0)) > 0.0 or absf(_sec - _soif()) > 0.004)
		"epouvantail":
			return _vent > 0.03 or float(etat.get("alerte", 0.0)) > 0.0 or absf(angle_difference(_tete, _regard_voulu())) > 0.002
		"mangeoire":
			return _vent > 0.05 and float(etat.get("foin", 0)) > 0.0
	return false


func _brille() -> bool:
	return _foudre_t >= 0.0 or _charge_en_cours()


# ce dont le fond dépend : il ne se redessine que si cette clé change (et, avec lui, ce qui remue)
func _cle_du_fond() -> String:
	var k := "%d-%d" % [int(_neige * 6.0 + 0.5), int(_mouille * 3.0 + 0.5)]
	match genre:
		"etabli":
			k += "-%d" % _copeaux_sol
		"tente", "hamac":
			k += "-%s" % bool(etat.get("occupe", false))
		"recuperateur":
			k += "-%d" % int(clampf(float(etat.get("eau", 0.0)), 0.0, 6.0) * 4.0 + 0.5)
		"filet":
			k += "-%s" % etat.has("prise")
		"cerf_volant":
			k += "-%s-%s-%d-%s" % [_monte <= 0.0, bool(etat.get("branche", false)), int(clampf(float(etat.get("charge", 0.0)), 0.0, 1.0) * 3.0 + 0.01), _roussi]
		"vestige":
			k += "-%s-%d-%s" % [bool(etat.get("fouille", false)), int(etat.get("riche", 0)), _vent > 0.03]
		"coffre":
			k += "-%s-%d" % [bool(etat.get("ouvert", false)), int(_leve * 400.0)]
		"carre":
			# (la terre par crans d'eau ; la pousse par seizièmes de stade : elle est lente, le fond se refait rarement)
			k += "-%d-%s-%s-%d" % [int(clampf(float(etat.get("eau", 0.0)), 0.0, 1.0) * 5.0 + 0.5), bool(etat.get("gel", false)), str(etat.get("culture", "")),
				int(clampf(float(etat.get("stade", 0.0)), 0.0, 3.0) * 16.0)]
		"piquet":
			k += "-%s" % bool(etat.get("attache", false))
		"mangeoire":
			k += "-%d" % int(clampf(float(etat.get("foin", 0)), 0.0, 12.0))
		"appat":
			k += "-%d-%s" % [_appat_baies(), str(etat.get("sorte", ""))]
	return k


# la neige et la pluie, par crans (le fond ne se refait pas pour un rien)
func _neige_cran() -> float:
	return float(int(_neige * 6.0 + 0.5)) / 6.0


func _mouille_cran() -> float:
	return float(int(_mouille * 3.0 + 0.5)) / 3.0


func _hasard(k: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _graine * 7 + k
	return r


# --- les gestes du dessin ---

# un point de l'espace (à droite, vers nous, en hauteur), vu de trois quarts
static func _pr(x: float, y: float, z: float) -> Vector2:
	return Vector2(x, y * PROF - z)


# une courbe douce de a à b, tirée vers m
static func _courbe(a: Vector2, m: Vector2, b: Vector2, n: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		out.append(a.lerp(m, u).lerp(m.lerp(b, u), u))
	return out


# une perche, un pieu, un rondin debout : de a (le pied) à b ; son écorce éclairée à gauche, l'encre plus lourde côté ombre
static func _perche(p, a: Vector2, b: Vector2, w0: float, w1: float, c: Color) -> void:
	var n := (b - a).normalized().orthogonal()
	if n.dot(Vector2(-0.6, -0.8)) < 0.0:
		n = -n
	var g0 := a + n * w0 * 0.5
	var g1 := b + n * w1 * 0.5
	var d0 := a - n * w0 * 0.5
	var d1 := b - n * w1 * 0.5
	p.aplat_libre(PackedVector2Array([g0, g1, d1, d0]), PackedColorArray([c, c, c, c]),
		PackedVector2Array([Vector2(10.0, 11.0), Vector2(10.0, 11.0), Vector2(12.0, 11.0), Vector2(12.0, 11.0)]))
	p.tracer(PackedVector2Array([g0, g1]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([d0, d1]), 1.4, ENCRE, false)
	p.tracer(PackedVector2Array([g1, d1]), 0.9, ENCRE, false)


# un bâton, une baguette : un trait de couleur sur un trait d'encre
static func _baton(p, ligne: PackedVector2Array, w: float, c: Color, cerne: float = 1.1) -> void:
	p.tracer(ligne, w + cerne, ENCRE, false)
	p.tracer(ligne, w, c, false)


# une corde, un hauban
static func _corde(p, ligne: PackedVector2Array, w: float = 0.9, c: Color = CORDE) -> void:
	p.tracer(ligne, w + 0.9, ENCRE, false)
	p.tracer(ligne, w, c, false)


# une pierre posée : son centre, ses rayons
static func _caillou(p, q: Vector2, rx: float, ry: float, c: Color, r: RandomNumberGenerator, e: float = 1.1) -> void:
	var poly := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0 + r.randf_range(-0.25, 0.25)
		poly.append(q + Vector2(cos(a) * rx, sin(a) * ry) * r.randf_range(0.84, 1.1))
	p.aplat(poly, c, Pinceau.PIERRE, q + Vector2(0.0, -ry * 0.1), Vector2(rx, ry) * 1.05)
	p.contour(poly, e, ENCRE, r, 2)


# un piquet de tente, planté de biais : son pied, où penche sa tête
static func _piquet(p, pied: Vector2, tete: Vector2) -> void:
	_baton(p, PackedVector2Array([pied, pied + tete]), 1.3, BOIS, 0.9)
	p.disque(pied + tete, 0.8, 0.65, BOIS_CLAIR)


# une ombre de contact, douce
static func _ombre(p, centre: Vector2, rx: float, ry: float, a: float = 0.42) -> void:
	p.eventail(centre, rx, ry, Color(P.ENCRE, a), Color(P.ENCRE, 0.0), 18)


# un quadrilatère, sans passer par la triangulation (une maille de toile, par dizaines)
static func _quad(p, a: Vector2, b: Vector2, c: Vector2, d: Vector2, couleur: Color) -> void:
	var base: int = p.pts.size()
	p.pts.append_array(PackedVector2Array([a, b, c, d]))
	p.cols.append_array(PackedColorArray([couleur, couleur, couleur, couleur]))
	p.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	p.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


# une goutte qui tombe de a jusqu'au sol (u : où elle en est, de 0 à 1), et le rond qu'elle y fait
static func _goutte(p, a: Vector2, sol: float, u: float, force: float = 1.0) -> void:
	var pale := Color(P.ECHO.lerp(P.PAPIER, 0.4), 0.75 * force)
	if u < 0.7:
		var y := lerpf(a.y, sol, pow(u / 0.7, 1.6))
		p.tracer(PackedVector2Array([Vector2(a.x, y - 2.2), Vector2(a.x, y)]), 0.9, pale, false)
	else:
		var v := (u - 0.7) / 0.3
		var rond := Pinceau.ellipse(Vector2(a.x, sol), 1.0 + 2.6 * v, 0.4 + 1.0 * v, 8)
		rond.append(rond[0])
		p.tracer(rond, 0.6, Color(pale, pale.a * (1.0 - v)), false)


# --- l'établi : un plateau de rondins fendus sur quatre pieds, un étau de corde, la scie d'os, l'alêne, une peau à tanner ; et
# le billot, son maillet de pierre ---

func _lire_etabli(dt: float) -> void:
	var travail := clampf(float(etat.get("travail", 0.0)), 0.0, 1.0)
	if travail > 0.0:
		_coup_dans -= dt
		if _coup_dans <= 0.0:
			_coup_dans = 0.42
			coup(0.5 + 0.5 * travail)
	else:
		_coup_dans = 0.0
	# ce qui vole retombe, reste un instant, puis fait partie du sol
	for i in range(_copeaux.size() - 1, -1, -1):
		var c: Array = _copeaux[i]
		c[4] += dt
		var q: Vector2 = c[0]
		var v: Vector2 = c[1]
		if q.y < float(c[6]) or v.y < 0.0:
			v.y += (90.0 if int(c[7]) == 1 else 230.0) * dt
			v.x += _vent * 30.0 * dt
			q += v * dt
			c[2] += float(c[3]) * dt
			if q.y >= float(c[6]) and v.y > 0.0:
				q.y = float(c[6])
				v = Vector2.ZERO
			c[0] = q
			c[1] = v
		if float(c[4]) >= float(c[5]):
			if int(c[7]) == 0 and _copeaux_sol < 14:
				_copeaux_sol += 1
			_copeaux.remove_at(i)


# un coup de maillet, un trait de scie : des copeaux sautent du plateau, de la sciure en tombe
func coup(force: float = 1.0) -> void:
	if genre != "etabli":
		return
	var r := RandomNumberGenerator.new()
	r.seed = _graine + int(_t * 977.0)
	for i in (3 if _mobile else 5):
		var q := Vector2(r.randf_range(-16.0, -4.0), r.randf_range(-17.0, -13.0))
		_copeaux.append([q, Vector2(r.randf_range(-38.0, 38.0), r.randf_range(-78.0, -34.0)) * (0.55 + 0.45 * force),
			r.randf() * TAU, r.randf_range(-11.0, 11.0), 0.0, r.randf_range(0.8, 1.2), r.randf_range(2.5, 9.0), 0])
	for i in (2 if _mobile else 5):
		var q := Vector2(r.randf_range(-22.0, 4.0), -9.5)
		_copeaux.append([q, Vector2(r.randf_range(-5.0, 5.0), r.randf_range(-6.0, 4.0)), 0.0, 0.0, 0.0, r.randf_range(0.5, 0.9),
			r.randf_range(1.0, 5.0), 1])
	_attente = 0.0


func _etabli(p) -> void:
	var r := _hasard(1)
	var mouille := _mouille_cran()
	var neige := _neige_cran()
	var clair := BOIS_CLAIR.darkened(0.24 * mouille)
	var ecorce := ECORCE.darkened(0.2 * mouille)
	var bois := BOIS.darkened(0.2 * mouille)
	_ombre(p, Vector2(-9.0, 1.5), 28.0, 7.5)
	_ombre(p, Vector2(23.5, 3.0), 11.5, 4.4)
	# les copeaux de toujours, et ceux du dernier ouvrage
	for i in 4 + _copeaux_sol:
		var q := Vector2(r.randf_range(-31.0, 14.0), r.randf_range(2.5, 9.5))
		var d := Vector2.from_angle(r.randf() * PI) * r.randf_range(1.4, 2.3)
		p.tracer(PackedVector2Array([q - d, q + d]), 1.2, clair.darkened(r.randf_range(0.0, 0.2)))
	# les pieds du fond, l'entretoise, les pieds de devant
	for x in [-22.5, 5.5]:
		_perche(p, Vector2(x, -3.5), Vector2(x, -11.0), 3.4, 3.4, ecorce.darkened(0.25))
	_baton(p, PackedVector2Array([Vector2(-26.0, -1.0), Vector2(-9.0, -1.6), Vector2(8.5, -1.3)]), 1.8, bois.darkened(0.1))
	for x in [-24.0, 6.0]:
		_perche(p, Vector2(x, 2.6), Vector2(x + 0.3, -8.0), 4.4, 4.0, ecorce)
		_corde(p, PackedVector2Array([Vector2(x - 2.6, -1.9), Vector2(x + 2.6, -0.9)]), 0.9)
		_corde(p, PackedVector2Array([Vector2(x - 2.6, -0.7), Vector2(x + 2.6, -2.1)]), 0.9)
	# le plateau : quatre rondins fendus, le plat en haut ; celui de devant montre son écorce
	var y0 := -18.5
	var haut := PackedVector2Array()
	for k in 4:
		var ya := y0 + k * 2.0
		var yb := ya + 2.0 + (0.1 if k == 3 else 0.0)
		var xa := -28.0 + r.randf_range(-1.6, 1.0)
		var xb := 10.0 + r.randf_range(-1.0, 1.9)
		var ton := clair.darkened(r.randf_range(0.02, 0.16))
		p.aplat(PackedVector2Array([Vector2(xa, ya), Vector2(xb, ya), Vector2(xb + 0.4, yb), Vector2(xa - 0.3, yb)]), ton)
		p.tracer(PackedVector2Array([Vector2(xa + 1.0, ya + 0.5), Vector2(xb - 1.0, ya + 0.5)]), 0.5, Color(ton.lightened(0.3), 0.8))
		p.tracer(PackedVector2Array([Vector2(xa, yb), Vector2((xa + xb) * 0.5, yb + 0.1), Vector2(xb, yb)]), 0.7, Color(ENCRE, 0.7), false)
		# (un nœud du bois, une fente)
		if k == 1 or k == 2:
			var nx := r.randf_range(-14.0, -6.0)
			p.disque(Vector2(nx, ya + 1.0), 1.0, 0.55, ton.darkened(0.35))
		if k == 0:
			haut = PackedVector2Array([Vector2(xa, ya), Vector2(xb, ya)])
		p.tracer(PackedVector2Array([Vector2(xa, ya), Vector2(xa - 0.3, yb)]), 0.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(xb, ya), Vector2(xb + 0.4, yb)]), 1.3, ENCRE, false)
	p.tracer(haut, 0.9, ENCRE, false)
	var face := PackedVector2Array([Vector2(-28.6, -10.5), Vector2(11.0, -10.5), Vector2(10.8, -7.6), Vector2(4.0, -7.0), Vector2(-20.0, -7.1), Vector2(-28.4, -7.6)])
	p.aplat(face, ecorce.lightened(0.06))
	p.tracer(PackedVector2Array([Vector2(-28.0, -10.2), Vector2(10.4, -10.2)]), 0.6, Color(clair, 0.75), false)
	for i in 5:
		var x := r.randf_range(-26.0, 8.0)
		p.tracer(PackedVector2Array([Vector2(x, -9.6), Vector2(x + r.randf_range(-0.4, 0.4), -7.8)]), 0.6, Color(ENCRE, 0.55))
	p.tracer(PackedVector2Array([Vector2(-28.4, -7.6), Vector2(-20.0, -7.1), Vector2(4.0, -7.0), Vector2(10.8, -7.6)]), 1.5, ENCRE, false)
	p.tracer(PackedVector2Array([Vector2(-28.6, -10.5), Vector2(-28.4, -7.6)]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([Vector2(11.0, -10.5), Vector2(10.8, -7.6)]), 1.3, ENCRE, false)
	# la neige tient sur le plateau, entre les outils
	if neige > 0.15:
		var bord := PackedVector2Array([Vector2(-19.0, -18.6), Vector2(-9.0, -19.3), Vector2(1.0, -18.9)])
		for k in 7:
			var x := lerpf(1.2, -19.2, k / 6.0)
			bord.append(Vector2(x, lerpf(-17.4, -12.4, neige) + r.randf_range(-0.7, 0.7)))
		p.aplat(bord, NEIGE)
		var bas := PackedVector2Array()
		for k in range(3, bord.size()):
			bas.append(bord[k])
		p.tracer(bas, 0.7, Color(NEIGE_OMBRE.darkened(0.25), 0.8), false)
	# une peau à tanner, jetée sur le bout du plateau, qui pend devant
	var peau := PackedVector2Array([Vector2(1.6, -18.3), Vector2(9.4, -18.0), Vector2(11.3, -10.6), Vector2(11.0, -4.6), Vector2(8.3, -2.4),
		Vector2(6.0, -4.4), Vector2(3.4, -2.9), Vector2(1.4, -6.0), Vector2(0.8, -10.6), Vector2(0.4, -14.5)])
	p.aplat(peau, CUIR_CLAIR.darkened(0.15 * mouille))
	p.aplat(PackedVector2Array([Vector2(0.8, -10.6), Vector2(11.3, -10.6), Vector2(11.0, -4.6), Vector2(8.3, -2.4), Vector2(6.0, -4.4), Vector2(3.4, -2.9),
		Vector2(1.4, -6.0)]), CUIR.darkened(0.12 * mouille))
	p.tracer(PackedVector2Array([Vector2(3.0, -17.0), Vector2(6.0, -15.6), Vector2(8.6, -12.2)]), 0.7, Color(CUIR_OMBRE, 0.7))
	p.tracer(PackedVector2Array([Vector2(4.6, -9.6), Vector2(5.2, -6.2)]), 0.6, Color(CUIR_OMBRE, 0.8))
	p.contour(peau, 1.1, ENCRE, r, 3)
	# l'étau de corde : deux mâchoires, une pièce serrée entre elles, la corde et son garrot
	_baton(p, PackedVector2Array([Vector2(-35.0, -21.3), Vector2(-19.0, -21.9)]), 1.9, clair.lightened(0.08))
	for x in [-27.2, -21.8]:
		_perche(p, Vector2(x, -17.2), Vector2(x, -26.0), 2.9, 2.7, bois)
	for y in [-24.6, -19.0]:
		_corde(p, PackedVector2Array([Vector2(-29.0, y), Vector2(-20.0, y + 0.2)]), 1.0)
	_baton(p, PackedVector2Array([Vector2(-26.4, -28.6), Vector2(-22.6, -23.4)]), 1.2, bois.lightened(0.1), 0.9)
	# la scie : une lame d'os dentelée, tendue dans un arc de bois
	var a := Vector2(-18.6, -13.0)
	var b := Vector2(-5.0, -15.4)
	_baton(p, _courbe(a, (a + b) * 0.5 + Vector2(-0.8, -6.6), b, 8), 1.2, bois.lightened(0.05), 0.9)
	_baton(p, PackedVector2Array([a, b]), 1.3, OS_PALE, 1.0)
	var dir := (b - a).normalized()
	for k in 8:
		var q := a.lerp(b, (k + 0.6) / 8.5)
		p.tracer(PackedVector2Array([q + dir.orthogonal() * -0.4, q + dir.orthogonal() * -1.7 + dir * 0.5]), 0.75, ENCRE, false)
	_baton(p, PackedVector2Array([b - dir * 0.6, b + dir * 3.2]), 2.3, CUIR, 1.0)
	# l'alêne, plantée dans le bois
	p.tracer(PackedVector2Array([Vector2(-1.4, -17.2), Vector2(-0.8, -23.4)]), 1.0, METAL.darkened(0.2), false)
	p.disque(Vector2(-0.7, -24.6), 1.5, 2.1, ENCRE)
	p.disque(Vector2(-0.7, -24.6), 0.9, 1.5, OS_PALE)
	# une glène de corde, pendue au pied
	var glene := Pinceau.ellipse(Vector2(-12.0, -4.6), 2.2, 2.5, 12)
	glene.append(glene[0])
	_corde(p, glene, 1.0)
	_billot(p, r, ecorce, clair, neige)


# le billot : une souche debout, sa coupe aux cernes clairs, entaillée ; le maillet de pierre posé dessus
func _billot(p, r: RandomNumberGenerator, ecorce: Color, clair: Color, neige: float) -> void:
	var c := Vector2(23.0, 2.0)
	var corps := PackedVector2Array([Vector2(15.7, -9.0), Vector2(30.2, -9.0), Vector2(30.6, 2.0)])
	for k in range(1, 8):
		var a := PI * k / 8.0
		corps.append(c + Vector2(cos(a) * 7.6, sin(a) * 3.0))
	corps.append(Vector2(15.4, 2.0))
	p.aplat(corps, ecorce, Pinceau.ECORCE, Vector2(23.0, -4.0), Vector2(7.6, 8.0))
	for i in 4:
		var x := r.randf_range(17.0, 29.0)
		p.tracer(PackedVector2Array([Vector2(x, r.randf_range(-7.0, -5.0)), Vector2(x + r.randf_range(-0.5, 0.5), r.randf_range(-1.0, 3.0))]), 0.7, Color(ENCRE, 0.5))
	p.contour(corps, 1.3, ENCRE, r, 3)
	var coupe := Vector2(23.0, -9.0)
	p.disque(coupe, 7.3, 3.0, clair.darkened(0.06))
	for k in 2:
		var cerne := Pinceau.ellipse(coupe + Vector2(0.4, 0.1), 4.9 - k * 2.6, 2.0 - k * 1.05, 12)
		cerne.append(cerne[0])
		p.tracer(cerne, 0.5, clair.darkened(0.38), false)
	p.tracer(PackedVector2Array([coupe + Vector2(0.4, 0.1), coupe + Vector2(5.6, 1.5)]), 0.7, Color(ENCRE, 0.8))
	p.tracer(PackedVector2Array([coupe + Vector2(-5.4, 0.4), coupe + Vector2(-2.6, 1.0)]), 0.8, Color(ENCRE, 0.7))
	var bord := Pinceau.ellipse(coupe, 7.3, 3.0, 18)
	bord.append(bord[0])
	p.tracer(bord, 1.0, ENCRE, false)
	if neige > 0.15:
		p.disque(coupe + Vector2(1.5, -0.6), 5.4 * minf(1.0, neige + 0.5), 2.1, NEIGE, Pinceau.DOME)
	# le maillet : une pierre ligaturée sur un manche, la tête sur la coupe
	var tete := Vector2(20.6, -11.6)
	_baton(p, PackedVector2Array([tete + Vector2(1.0, -0.6), Vector2(30.6, -24.6)]), 1.9, BOIS)
	var pierre: Color = Color(0.45, 0.44, 0.42)
	if jeu != null and jeu.monde != null:
		pierre = jeu.monde.palette.get("pierre", pierre)
	var bloc := PackedVector2Array([tete + Vector2(-4.2, -1.6), tete + Vector2(-1.0, -3.4), tete + Vector2(3.6, -2.6), tete + Vector2(4.4, 0.8),
		tete + Vector2(1.6, 2.8), tete + Vector2(-3.4, 2.0)])
	p.aplat(bloc, pierre.lightened(0.1), Pinceau.PIERRE, tete, Vector2(4.6, 3.4))
	p.contour(bloc, 1.2, ENCRE, r, 2)
	_corde(p, PackedVector2Array([tete + Vector2(-0.6, -3.0), tete + Vector2(1.6, 2.4)]), 0.9)
	_corde(p, PackedVector2Array([tete + Vector2(1.6, -3.0), tete + Vector2(-0.4, 2.2)]), 0.9)


# les copeaux qui volent, la sciure qui tombe
func _etabli_vif(p) -> void:
	for c in _copeaux:
		var q: Vector2 = c[0]
		var fin := clampf((float(c[5]) - float(c[4])) / 0.25, 0.0, 1.0)
		if int(c[7]) == 1:
			p.disque(q, 0.75, 0.6, Color(BOIS_CLAIR.lightened(0.1), 0.8 * fin))
			continue
		var d := Vector2.from_angle(float(c[2]))
		var n := d.orthogonal() * 0.75
		d *= 1.6
		p.aplat(PackedVector2Array([q - d - n, q + d - n * 0.4, q + d + n, q - d + n * 0.6]), Color(BOIS_CLAIR.lightened(0.12), fin))


# --- la tente : une bâche sur deux perches, vue de trois quarts ; on voit son entrée et un pan de son toit ---

# un point de la tente : en travers (u), le long du faîte (v, vers l'entrée), en hauteur
static func _tente_pt(u: float, v: float, z: float) -> Vector2:
	var g := TENTE_B * u + TENTE_A * v
	return Vector2(g.x, g.y * PROF - z)


# un point du pan de toit : i de l'entrée (0) au fond (1), j du faîte (0) au sol (1). gonfle : ce que le vent pousse dehors
# (ou que la pluie creuse) ; leve : le bas qui se soulève entre deux piquets
static func _tente_pan(i: float, j: float, gonfle: float, leve: float) -> Vector2:
	var g := gonfle * sin(PI * i) * sin(PI * j)
	var u := TENTE_W * j + g * 0.84
	var z := TENTE_H * (1.0 - j) + g * 0.54
	# (le faîte pend un peu entre ses deux perches)
	z -= 1.7 * sin(PI * i) * (1.0 - j)
	z += leve * absf(sin(TAU * i)) * j * j * j
	return _tente_pt(u, TENTE_L * (1.0 - 2.0 * i), z)


func _tente(p) -> void:
	var r := _hasard(2)
	_ombre(p, Vector2(5.0, 5.0), 37.0, 14.0, 0.45)
	_ombre(p, Vector2(-8.0, 12.0), 24.0, 7.0, 0.3)
	# la perche du fond dépasse du faîte ; son hauban file derrière
	_baton(p, PackedVector2Array([_tente_pt(0.0, -TENTE_L - 0.5, TENTE_H - 3.0), _tente_pt(0.0, -TENTE_L - 0.5, TENTE_H + 4.5)]), 2.0, BOIS)
	# les piquets du pan, et leurs boucles de corde
	for k in 3:
		var i := k * 0.5
		var bas := _tente_pan(i, 1.0, 0.0, 0.0)
		var pied := _tente_pt(TENTE_W + 5.5, TENTE_L * (1.0 - 2.0 * i), 0.0)
		_hauban(p, PackedVector2Array([bas, pied + Vector2(0.4, -1.4)]))
		_piquet(p, pied + Vector2(0.0, 0.6), Vector2(2.0, -3.6))
	var coin := _tente_pt(-TENTE_W, TENTE_L, 0.0)
	_hauban(p, PackedVector2Array([coin, coin + Vector2(-4.6, 0.2)]))
	_piquet(p, coin + Vector2(-4.6, 1.6), Vector2(-1.8, -3.4))
	# le dedans : l'ombre, le tapis de sol, un rouleau
	var fa := _tente_pt(0.0, TENTE_L, TENTE_H - 1.0)
	var fl := _tente_pt(-TENTE_W, TENTE_L, 0.0)
	var fr := _tente_pt(TENTE_W, TENTE_L, 0.0)
	p.aplat(PackedVector2Array([fa, fr, fl]), Color("12121a"))
	p.aplat(PackedVector2Array([fl.lerp(fr, 0.2), fl.lerp(fr, 0.86), fl.lerp(fr, 0.8) + Vector2(1.2, -3.6), fl.lerp(fr, 0.3) + Vector2(1.6, -3.8)]), Color("2a2622"))
	if not bool(etat.get("occupe", false)):
		p.disque(fl.lerp(fr, 0.66) + Vector2(1.2, -3.6), 4.2, 1.9, Color("3b3329"))


func _tente_vif(p) -> void:
	var r := _hasard(3)
	var occupe := _occupe
	var mouille := _mouille
	var neige := _neige
	# le souffle : la toile se gonfle sous le vent (elle est sous le vent : il la pousse dehors), frémit dans la rafale ; la
	# pluie et la neige la creusent
	var souffle := _vent * (0.55 + 0.45 * sin(_t * 1.9 + _graine)) + _vent * _vent * 0.35 * sin(_t * 7.7 + 1.3)
	var gonfle := 2.6 * souffle - 2.4 * minf(1.0, _pluie * 1.4) - 2.0 * neige
	var leve := 0.5 + 1.5 * _vent * (0.5 + 0.5 * sin(_t * 5.3 + 0.7))
	var ton := TOILE.lerp(TOILE_OMBRE.lerp(EAU, 0.12), 0.42 * mouille)
	var clair := TOILE_CLAIR.lerp(TOILE.lerp(EAU, 0.08), 0.5 * mouille)
	var ombre := TOILE_OMBRE.darkened(0.2 * mouille)
	# --- le pan du toit ---
	var faite := PackedVector2Array()
	for k in 9:
		faite.append(_tente_pan(k / 8.0, 0.0, gonfle, leve))
	var fond := PackedVector2Array()
	for k in 5:
		fond.append(_tente_pan(1.0, k / 4.0, gonfle, leve))
	var bas := PackedVector2Array()
	for k in 13:
		bas.append(_tente_pan(1.0 - k / 12.0, 1.0, gonfle, leve))
	var devant := PackedVector2Array()
	for k in 5:
		devant.append(_tente_pan(0.0, 1.0 - k / 4.0, gonfle, leve))
	var pan := PackedVector2Array()
	pan.append_array(faite)
	for k in range(1, 5):
		pan.append(fond[k])
	for k in range(1, 13):
		pan.append(bas[k])
	for k in range(1, 4):
		pan.append(devant[k])
	p.aplat(pan, ton)
	# la lumière accroche le haut du pan, l'ombre gagne le bas et le fond
	var lum := PackedVector2Array()
	for k in 9:
		lum.append(faite[k])
	for k in 9:
		lum.append(_tente_pan(1.0 - k / 8.0, 0.15, gonfle, leve))
	p.aplat(lum, clair.lerp(ton, 0.3))
	var sombre := PackedVector2Array()
	for k in 9:
		var i := k / 8.0
		sombre.append(_tente_pan(i, lerpf(0.9, 0.46, smoothstep(0.0, 1.0, i)), gonfle, leve))
	for k in 13:
		sombre.append(bas[k])
	p.aplat(sombre, ton.lerp(ombre, 0.5))
	# la couture des deux lés, ses points ; une pièce recousue
	var couture := PackedVector2Array()
	for k in 9:
		couture.append(_tente_pan(k / 8.0, 0.5, gonfle, leve))
	p.tracer(couture, 0.6, Color(ENCRE, 0.5), false)
	for k in 8:
		var q := _tente_pan((k + 0.5) / 8.0, 0.5, gonfle, leve)
		p.tracer(PackedVector2Array([q + Vector2(-0.4, -1.0), q + Vector2(0.4, 1.0)]), 0.6, Color(ENCRE, 0.5), false)
	var piece := PackedVector2Array([_tente_pan(0.56, 0.62, gonfle, leve), _tente_pan(0.7, 0.6, gonfle, leve), _tente_pan(0.71, 0.8, gonfle, leve),
		_tente_pan(0.57, 0.82, gonfle, leve)])
	p.aplat(piece, CUIR_CLAIR.lerp(ton, 0.45))
	piece.append(piece[0])
	p.tracer(piece, 0.6, Color(ENCRE, 0.6), false)
	# les plis que tirent les piquets : ils bougent quand la toile respire
	for k in 3:
		var i := 0.04 + 0.46 * k
		var pli := PackedVector2Array()
		for n in 4:
			var j := 1.0 - 0.13 * n
			pli.append(_tente_pan(i + (0.5 - i) * 0.12 * n - 0.012 * gonfle * n, j, gonfle, leve))
		p.tracer(pli, 0.8, Color(ENCRE, 0.36))
	# la neige : une coiffe le long du faîte, qui descend ; un bourrelet au pied du pan
	if neige > 0.12:
		var coiffe := PackedVector2Array()
		for k in 9:
			coiffe.append(faite[k] + Vector2(0.0, -0.5 - 1.0 * neige))
		var lisiere := PackedVector2Array()
		for k in 13:
			var i := 1.0 - k / 12.0
			lisiere.append(_tente_pan(i, (0.1 + 0.5 * neige) * (1.0 + 0.16 * sin(i * 7.0 + _graine) + 0.08 * sin(i * 17.0)), gonfle, leve))
		coiffe.append_array(lisiere)
		p.aplat(coiffe, NEIGE)
		var creux := PackedVector2Array()
		for k in 13:
			var i := 1.0 - k / 12.0
			creux.append(_tente_pan(i, (0.1 + 0.5 * neige) * (0.72 + 0.1 * sin(i * 9.0 + 1.0)), gonfle, leve))
		for k in 13:
			creux.append(lisiere[12 - k])
		p.aplat(creux, NEIGE.lerp(NEIGE_OMBRE, 0.6))
		p.tracer(lisiere, 0.8, Color(NEIGE_OMBRE.darkened(0.3), 0.8), false)
		for k in 3:
			var q := _tente_pan(0.2 + k * 0.3, 1.0, 0.0, 0.0) + Vector2(2.2, 0.4)
			p.disque(q, 5.0 * neige + 1.0, 1.3 * neige + 0.4, NEIGE.lerp(NEIGE_OMBRE, 0.25))
	# l'encre du pan : le faîte, le fond, le bas festonné (plus lourd : c'est le côté de l'ombre)
	p.tracer(fond, 1.3, ENCRE, false)
	p.tracer(bas, 1.5, ENCRE, false)
	# --- l'entrée ---
	var fa := _tente_pt(0.0, TENTE_L, TENTE_H)
	var fl := _tente_pt(-TENTE_W, TENTE_L, 0.0)
	var fr := _tente_pt(TENTE_W, TENTE_L, 0.0)
	var bat := sin(_t * 4.3 + 2.0) * _vent * 1.6 + sin(_tr * 0.9) * 0.35 * occupe
	# le pan de gauche, roulé et noué ; celui de droite, noué lui aussi, ou fermé quand elle dort dedans
	var ou_g := 0.26
	var ou_d := lerpf(0.72, 0.4, occupe)
	var g_bas := fl.lerp(fr, ou_g)
	var d_bas := fl.lerp(fr, ou_d) + Vector2(bat * 0.5, 0.0)
	var g_mi := fa.lerp(fl.lerp(fr, ou_g * 0.62), 0.55) + Vector2(bat * 0.3, 0.0)
	var d_mi := fa.lerp(fl.lerp(fr, lerpf(0.8, 0.47, occupe)), 0.55) + Vector2(bat, 0.0)
	var bord_g := _courbe(fa, g_mi, g_bas, 6)
	var bord_d := _courbe(fa, d_mi, d_bas, 6)
	var gauche := PackedVector2Array([fl])
	gauche.append_array(bord_g)
	p.aplat(gauche, clair)
	var droite := PackedVector2Array([fr])
	droite.append_array(bord_d)
	p.aplat(droite, clair.lerp(ton, 0.5))
	# (les plis du pan fermé, ses deux attaches)
	if occupe > 0.5:
		for k in 2:
			var a := fa.lerp(fr, 0.18 + 0.1 * k)
			var b := d_bas.lerp(fr, 0.3 + 0.3 * k)
			p.tracer(_courbe(a, a.lerp(b, 0.5) + Vector2(bat * 0.5 - 1.0, 0.0), b, 5), 0.7, Color(ENCRE, 0.3))
		for k in 2:
			var q: Vector2 = bord_d[2 + k * 2]
			_corde(p, PackedVector2Array([q + Vector2(-2.4, 0.3), q + Vector2(1.2, -0.2)]), 0.7)
	else:
		var q: Vector2 = bord_d[3]
		_corde(p, PackedVector2Array([q + Vector2(-0.6, -0.2), q + Vector2(3.0, 0.5)]), 0.7)
	var q_g: Vector2 = bord_g[3]
	_corde(p, PackedVector2Array([q_g + Vector2(0.6, -0.2), q_g + Vector2(-3.0, 0.4)]), 0.7)
	p.tracer(bord_g, 1.0, ENCRE, false)
	p.tracer(bord_d, 1.1, ENCRE, false)
	p.tracer(PackedVector2Array([fa, fl]), 1.1, ENCRE, false)
	p.tracer(PackedVector2Array([fl, g_bas]), 1.2, ENCRE, false)
	p.tracer(PackedVector2Array([d_bas, fr]), 1.3, ENCRE, false)
	p.tracer(faite, 1.2, ENCRE, false)
	p.tracer(devant, 1.2, ENCRE, false)
	# la perche de l'entrée, son hauban, son piquet
	var pied := _tente_pt(0.0, TENTE_L + 0.5, 0.0)
	var tete := _tente_pt(0.0, TENTE_L + 0.5, TENTE_H + 4.5)
	var loin := _tente_pt(0.0, TENTE_L + 17.0, 0.0)
	_hauban(p, _courbe(tete + Vector2(0.0, 1.5), tete.lerp(loin, 0.5) + Vector2(0.6, 1.2 + 0.8 * _vent * sin(_t * 6.1)), loin, 6))
	_piquet(p, loin + Vector2(0.0, 1.0), Vector2(-2.4, -3.4))
	_perche(p, pied, tete, 2.6, 2.2, BOIS.darkened(0.15 * mouille))
	_corde(p, PackedVector2Array([tete + Vector2(-1.6, 2.6), tete + Vector2(1.6, 2.2)]), 0.8)
	# ses bottes, laissées debout devant l'entrée
	if occupe > 0.5:
		for k in 2:
			var b := fl.lerp(fr, 0.34 + 0.1 * k) + Vector2(-3.4, 4.6 - k * 0.5)
			var botte := PackedVector2Array([b + Vector2(-1.2, -5.0), b + Vector2(1.3, -5.0), b + Vector2(1.4, 0.6), b + Vector2(-3.6, 0.8), b + Vector2(-3.7, -0.7),
				b + Vector2(-1.3, -1.5)])
			p.aplat(botte, Color("3a2e22"))
			p.tracer(PackedVector2Array([b + Vector2(-1.1, -4.6), b + Vector2(1.2, -4.6)]), 0.9, CUIR_CLAIR, false)
			botte.append(botte[0])
			p.tracer(botte, 0.8, ENCRE, false)
	# la pluie : elle ruisselle sur le pan, goutte de ses festons
	if _pluie > 0.03:
		var n := 2 if _mobile else 4
		for k in n:
			var ph := fposmod(_t * (0.55 + 0.1 * k) + k * 0.37 + r.randf(), 1.0)
			var i := fposmod(0.17 + k * 0.23 + floor(_t * (0.55 + 0.1 * k) + k * 0.37) * 0.31, 1.0) * 0.86 + 0.07
			var a := _tente_pan(i, 0.12 + 0.76 * ph, gonfle, leve)
			var b := _tente_pan(i, minf(1.0, 0.12 + 0.76 * ph + 0.1), gonfle, leve)
			p.tracer(PackedVector2Array([a, b]), 0.8, Color(P.ECHO.lerp(P.PAPIER, 0.5), 0.55 * minf(1.0, _pluie * 2.0)))
		for k in (2 if _mobile else 3):
			var i := 0.25 + 0.25 * k
			var a := _tente_pan(i, 1.0, gonfle, leve)
			_goutte(p, a + Vector2(0.6, 0.4), a.y + 5.0 + 3.0 * absf(sin(TAU * i)), fposmod(_t * (1.1 + 0.9 * _pluie) + k * 0.41, 1.0), minf(1.0, _pluie * 2.5))
		_goutte(p, fl + Vector2(-1.0, -1.0), fl.y + 2.0, fposmod(_t * 1.3 + 0.2, 1.0), minf(1.0, _pluie * 2.5))


# --- le hamac : une toile entre deux poignées de cordes, du piquet au tronc le plus proche ; il pend, se balance ---

static func _est_un_arbre(o) -> bool:
	var g := str(o.get("genre"))
	return (g == "arbre" or g == "sapin") and not bool(o.get("calcine"))


# le tronc où le nouer (le plus proche, à portée de corde) ; sans arbre : deux piquets, en travers de la vue
func _chercher_arbre() -> void:
	_arbre = null
	var mieux := 100.0
	if jeu != null and jeu.monde != null and jeu.monde.has_method("autour"):
		for o in jeu.monde.autour(position, 100.0):
			if not _est_un_arbre(o):
				continue
			var d: float = o.position.distance_to(position)
			if d < mieux and d > 22.0:
				mieux = d
				_arbre = o
	var vers := Vector2(1.0, 0.1 if _graine % 2 == 0 else -0.1).normalized()
	_tronc = Vector2.ZERO
	if _arbre != null:
		_tronc = _arbre.position - position
		vers = _tronc.normalized()
	_axe = vers
	# (la vue de trois quarts raccourcit ce qui s'éloigne de nous)
	_court = Vector2(vers.x, vers.y * 0.62).length()
	_travers = Vector2(-vers.y, vers.x)
	_sens = 1.0
	if _travers.y < 0.0:
		_travers = -_travers
		_sens = -1.0


# un point du hamac : le long de sa toile (s, en pixels de toile), en travers (vers nous), en hauteur
func _hamac_pt(s: float, travers: float, z: float) -> Vector2:
	return _axe * (s * _court) + Vector2(_travers.x * travers, _travers.y * travers * PROF - z)


# une ombre allongée le long d'un axe
static func _ombre_axe(p, c: Vector2, dir: Vector2, rl: float, rw: float, a: float) -> void:
	var base: int = p.pts.size()
	var tr := dir.orthogonal()
	p.pts.append(c)
	p.cols.append(Color(P.ENCRE, a))
	p.uvs.append(Vector2.ZERO)
	for i in 16:
		var ang := TAU * i / 16.0
		p.pts.append(c + dir * cos(ang) * rl + tr * sin(ang) * rw)
		p.cols.append(Color(P.ENCRE, 0.0))
		p.uvs.append(Vector2.ZERO)
	for i in 16:
		p.idx.append_array(PackedInt32Array([base, base + 1 + i, base + 1 + (i + 1) % 16]))


# un piquet de hamac : une perche fourchue, plantée de biais, que retient un hauban
func _hamac_piquet(p, cote: float) -> void:
	var pied := _hamac_pt(cote * (HAMAC_L + 14.0), 0.0, 0.0)
	var tete := _hamac_pt(cote * (HAMAC_L + 16.5), 0.0, 25.0)
	var ancre := _hamac_pt(cote * (HAMAC_L + 29.0), 0.0, 0.0)
	_ombre(p, pied + Vector2(0.5, 0.8), 5.0, 2.0, 0.4)
	_hauban(p, PackedVector2Array([tete + Vector2(0.0, 2.0), ancre]))
	_piquet(p, ancre + Vector2(0.0, 0.8), (ancre - pied).normalized() * 2.2 + Vector2(0.0, -3.0))
	_perche(p, pied + Vector2(0.0, 1.0), tete, 3.4, 2.6, ECORCE.lightened(0.05))
	# (la fourche)
	_baton(p, PackedVector2Array([tete + Vector2(0.0, 3.0), tete + Vector2(-2.2, -1.6)]), 1.4, ECORCE.lightened(0.08), 0.9)
	_baton(p, PackedVector2Array([tete + Vector2(0.0, 3.0), tete + Vector2(2.2, -1.2)]), 1.4, ECORCE.lightened(0.08), 0.9)
	_corde(p, PackedVector2Array([tete + Vector2(-1.8, 3.4), tete + Vector2(1.8, 3.0)]), 0.9)
	_hauban(p, PackedVector2Array([tete + Vector2(0.0, 3.0), _hamac_pt(cote * (HAMAC_L + 4.5), 0.0, HAMAC_Z + 1.0)]), 1.0)


# un hauban : une corde fine, tendue
static func _hauban(p, ligne: PackedVector2Array, w: float = 0.8) -> void:
	p.tracer(ligne, w + 0.6, ENCRE, false)
	p.tracer(ligne, w * 0.6, CORDE, false)


func _hamac(p) -> void:
	var dir := (_axe * _court).normalized()
	_ombre_axe(p, Vector2(1.0, 2.0), dir, HAMAC_L * _court * 1.08, 4.6 + 4.4 * absf(_axe.y), 0.3 + 0.12 * _occupe)
	_hamac_piquet(p, -1.0)
	if _arbre == null:
		_hamac_piquet(p, 1.0)
		return
	# la corde file jusqu'au tronc, y fait deux tours
	var loin := _tronc.length() / maxf(_court, 0.2)
	var haut := clampf(HAMAC_Z + 1.0 + (loin - HAMAC_L - 4.5) * 0.28, HAMAC_Z + 1.0, 27.0)
	var noeud := _tronc + Vector2(0.0, -haut)
	_hauban(p, PackedVector2Array([_hamac_pt(HAMAC_L + 4.5, 0.0, HAMAC_Z + 1.0), noeud]), 1.0)
	for k in 2:
		_corde(p, PackedVector2Array([noeud + Vector2(-4.6, -0.9 + k * 1.9), noeud + Vector2(0.0, -0.2 + k * 1.9), noeud + Vector2(4.6, -0.9 + k * 1.9)]), 0.9)


func _hamac_vif(p) -> void:
	var occ := smoothstep(0.0, 1.0, _occupe)
	var ns := 10 if _mobile else 12
	var nt := 4 if _mobile else 6
	var mouille := _mouille
	var toile := TOILE.lerp(TOILE_OMBRE.lerp(EAU, 0.12), 0.4 * mouille)
	var clair := TOILE_CLAIR.lerp(TOILE.lerp(EAU, 0.08), 0.5 * mouille)
	var ombre := TOILE_OMBRE.darkened(0.15 * mouille)
	# il se balance : au vent quand il est vide, à peine sous un corps
	var phi := sin(_t * lerpf(2.0, 1.4, occ) + _graine) * lerpf(0.36 * _vent, 0.03 + 0.08 * _vent, occ)
	var souffle := sin(_tr * 1.45) * occ
	var bas := lerpf(9.5, 5.6, occ)
	# la tête : du côté qui s'éloigne de nous, sinon du côté du tronc
	var tete := 1.0
	if absf(_axe.y) > 0.3 and _axe.y > 0.0:
		tete = -1.0
	var grille: Array = []
	var quille := PackedVector2Array()
	var hauteurs := PackedFloat32Array()
	var ecarts := PackedFloat32Array()
	for a in ns + 1:
		var sig := float(a) / ns
		var arche := sin(PI * sig)
		var zk := HAMAC_Z - (HAMAC_Z - bas) * pow(arche, lerpf(1.0, 0.55, occ))
		var w := lerpf(6.0, 7.4, occ) * pow(arche, 0.5)
		var d := lerpf(3.0, 5.4, occ) * pow(arche, 0.8)
		var ecart := (HAMAC_Z + 1.0 - zk) * sin(phi)
		var s := lerpf(-HAMAC_L, HAMAC_L, sig)
		var rang := PackedVector2Array()
		for b in nt + 1:
			var u := -1.0 + 2.0 * b / nt
			rang.append(_hamac_pt(s, w * u + ecart, zk + d * u * u))
		grille.append(rang)
		quille.append(_hamac_pt(s, ecart, zk))
		hauteurs.append(zk)
		ecarts.append(ecart)
	# les poignées de cordes, des anneaux aux bouts de la toile
	for cote in [-1.0, 1.0]:
		var anneau := _hamac_pt(cote * (HAMAC_L + 4.5), 0.0, HAMAC_Z + 1.0)
		var rang: PackedVector2Array = grille[1 if cote < 0.0 else ns - 1]
		for b in [0, nt / 2, nt]:
			p.tracer(PackedVector2Array([anneau, rang[b]]), 0.8, Color(ENCRE, 0.85), false)
		p.disque(anneau, 1.5, 1.4, ENCRE)
		p.disque(anneau, 0.7, 0.65, CORDE)
	# la toile, maille par maille : son dedans d'abord (le fond, éclairé d'en haut à gauche) ; son dehors viendra par-dessus le corps
	var dehors: Array = []
	var enneige := _neige > 0.25 and occ < 0.5
	for b in nt:
		var um := -1.0 + 2.0 * (b + 0.5) / nt
		var k := absf(um)
		for a in ns:
			var q0: Vector2 = grille[a][b]
			var q1: Vector2 = grille[a + 1][b]
			var q2: Vector2 = grille[a + 1][b + 1]
			var q3: Vector2 = grille[a][b + 1]
			if (q1 - q0).cross(q3 - q0) * _sens > 0.0:
				var c := toile.lerp(clair, k).darkened((1.0 - k) * 0.24) if um < 0.0 else toile.darkened(0.1 + 0.22 * (1.0 - k))
				if enneige and k < 0.45 and a > 1 and a < ns - 2:
					c = NEIGE.lerp(NEIGE_OMBRE, 0.5 * (1.0 - k))
				_quad(p, q0, q1, q2, q3, c)
			else:
				dehors.append([q0, q1, q2, q3, ombre.lerp(toile.darkened(0.08), k)])
	# une rayure rouille, tissée dans la longueur
	var rayure := PackedVector2Array()
	for a in range(1, ns):
		rayure.append((grille[a][1] as Vector2).lerp(grille[a][2], 0.3))
	p.tracer(rayure, 1.1, Color(P.ECHARPE.lerp(toile, 0.35), 0.9), false)
	# la veilleuse, dedans : son corps sous la cape, sa capuche, son écharpe qui pend
	if occ > 0.02:
		var corps := PackedVector2Array()
		for a in range(2, ns - 3 + 1):
			var i := a if tete > 0.0 else ns - a
			var sig := float(i) / ns
			var genou := 1.4 * exp(-pow((float(a) / ns - 0.38) / 0.11, 2.0))
			corps.append(_hamac_pt(lerpf(-HAMAC_L, HAMAC_L, sig), ecarts[i], hauteurs[i] + (2.3 + genou + 0.35 * souffle) * occ))
		p.tracer(corps, 7.6 * occ, ENCRE, false, PackedFloat32Array(), true)
		p.tracer(corps, 6.2 * occ, P.CAPE, false)
		var pli := PackedVector2Array()
		for q in corps:
			pli.append(q + Vector2(-0.4, -1.5))
		p.tracer(pli, 0.8, Color("57607a"))
		var it := ns - 3 if tete > 0.0 else 3
		var cou: Vector2 = _hamac_pt(lerpf(-HAMAC_L, HAMAC_L, float(it) / ns), ecarts[it], hauteurs[it] + 2.6 * occ)
		var vers := (_axe * _court).normalized() * tete
		var chef := cou + vers * 2.6 + Vector2(0.0, -1.6 - 0.25 * souffle)
		# (l'écharpe : un tour au cou, un pan qui passe le bord et se balance)
		var pan := PackedVector2Array([cou + Vector2(0.0, -0.6), cou + Vector2(_travers.x * 4.0, 2.2), cou + Vector2(_travers.x * 4.6 + sin(_t * 1.7) * 0.8 * (0.3 + _vent), 7.4)])
		p.tracer(pan, 3.0, ENCRE, false)
		p.tracer(pan, 1.9, P.ECHARPE, false)
		p.disque(chef, 5.2, 4.9, ENCRE)
		p.disque(chef, 4.3, 4.0, P.CAPE)
		p.disque(chef + Vector2(-1.2, -1.4), 2.2, 1.5, Color("57607a"))
		p.disque(chef + Vector2(0.5, 1.1), 2.5, 2.1, Color("0f121c"))
		p.disque(chef + Vector2(0.6, 1.6), 1.8, 1.3, P.VISAGE)
		p.tracer(PackedVector2Array([chef + Vector2(-0.4, 1.4), chef + Vector2(1.5, 1.5)]), 0.5, Color(ENCRE, 0.8), false)
	for m in dehors:
		_quad(p, m[0], m[1], m[2], m[3], m[4])
	# l'encre : les deux bords, et le ventre de la toile, du côté de l'ombre
	var loin := PackedVector2Array()
	var pres := PackedVector2Array()
	var ventre := PackedVector2Array()
	var vers_bas := (_axe * _court).normalized().orthogonal()
	if vers_bas.y < 0.0:
		vers_bas = -vers_bas
	for a in ns + 1:
		var rang: PackedVector2Array = grille[a]
		loin.append(rang[0])
		pres.append(rang[nt])
		var q := rang[0]
		for b in range(1, nt + 1):
			if rang[b].dot(vers_bas) > q.dot(vers_bas):
				q = rang[b]
		ventre.append(q)
	p.tracer(loin, 0.9, ENCRE, false)
	p.tracer(pres, 1.0, ENCRE, false)
	p.tracer(ventre, 1.4, ENCRE, false)
	if _pluie > 0.05 and not _mobile:
		var q: Vector2 = ventre[ns / 2]
		_goutte(p, q + Vector2(0.0, 0.6), 3.0, fposmod(_t * 1.2 + 0.3, 1.0), minf(1.0, _pluie * 2.5))


# --- le récupérateur d'eau : une bâche en pente sur quatre pieux, pliée en gouttière ; elle verse dans un creux doublé de toile,
# bordé de pierres, où l'on voit monter l'eau ---

func _pierre_du_lieu() -> Color:
	var pierre := Color(0.45, 0.44, 0.42)
	if jeu != null and jeu.monde != null:
		pierre = jeu.monde.palette.get("pierre", pierre)
	return pierre


# le niveau de l'eau dans le creux : son centre, ses rayons (k : de 0, à sec, à 1, plein)
static func _recuperateur_eau(k: float) -> Array:
	return [Vector2(0.0, lerpf(9.6, 7.9, k)), lerpf(6.6, 10.6, k), lerpf(2.4, 4.3, k)]


func _recuperateur(p) -> void:
	var r := _hasard(4)
	var neige := _neige_cran()
	var pierre := _pierre_du_lieu()
	var k := float(int(clampf(float(etat.get("eau", 0.0)), 0.0, 6.0) * 4.0 + 0.5)) / 24.0
	_ombre(p, Vector2(1.0, -3.0), 22.0, 8.0, 0.4)
	_ombre(p, Vector2(0.5, 8.5), 17.0, 7.0, 0.36)
	# les deux pieux du fond, plus hauts
	for cote in [-1.0, 1.0]:
		_perche(p, _pr(cote * 11.0, -10.0, 0.0), _pr(cote * 11.2, -10.0, 28.5), 2.8, 2.4, ECORCE.darkened(0.3))
	# le creux : les pierres du fond, le bord de toile rabattu, le dedans dans l'ombre
	var b := Vector2(0.0, 7.5)
	for i in 5:
		var a := lerpf(-2.85, -0.3, i / 4.0) + r.randf_range(-0.1, 0.1)
		_caillou(p, b + Vector2(cos(a) * 13.6, sin(a) * 5.6 - 1.6), r.randf_range(3.0, 4.0), r.randf_range(2.3, 2.9), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
	var bord := Pinceau.ellipse(b, 12.6, 5.3, 22)
	p.aplat(bord, TOILE.darkened(0.06 + 0.14 * _mouille_cran()))
	p.contour(bord, 1.2, ENCRE, r, 3)
	p.disque(b + Vector2(0.0, 0.5), 10.9, 4.3, Color("2b2823"))
	# (le fond du creux, ses plis)
	p.disque(Vector2(0.0, 9.6), 6.6, 2.4, Color("4e463b"))
	p.tracer(PackedVector2Array([Vector2(-3.6, 9.2), Vector2(-0.6, 10.2), Vector2(2.8, 9.4)]), 0.6, Color(ENCRE, 0.5))
	if k > 0.02:
		var e: Array = _recuperateur_eau(k)
		var c: Vector2 = e[0]
		var rx: float = e[1]
		var ry: float = e[2]
		p.disque(c, rx, ry, EAU.darkened(0.12))
		# le ciel dans l'eau : un croissant clair, du côté du jour ; un liseré au bord du fond
		var ciel := PackedVector2Array()
		for i in 9:
			var a := lerpf(PI * 0.98, PI * 1.9, i / 8.0)
			ciel.append(c + Vector2(cos(a) * rx * 0.94, sin(a) * ry * 0.92))
		for i in 9:
			var a := lerpf(PI * 1.9, PI * 0.98, i / 8.0)
			ciel.append(c + Vector2(cos(a) * rx * 0.94, sin(a) * ry * 0.92 + ry * (0.55 + 0.25 * sin(i * 0.39))))
		p.aplat(ciel, EAU.lerp(P.ECHO, 0.42))
		var rive := PackedVector2Array()
		for i in 12:
			var a := lerpf(PI * 0.05, PI * 0.95, i / 11.0)
			rive.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		p.tracer(rive, 0.8, Color(ENCRE, 0.7))
	elif neige < 0.3:
		# (à sec : une feuille morte au fond)
		p.disque(Vector2(2.4, 9.9), 1.6, 0.8, P.ECHARPE.lerp(P.TERRE, 0.4))
	# les pierres de devant
	for a in [0.72, 2.45]:
		_caillou(p, b + Vector2(cos(a) * 13.2, sin(a) * 5.4 + 0.4), r.randf_range(3.2, 3.9), r.randf_range(2.4, 2.9), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.16)), r)
	if neige > 0.2:
		for i in 4:
			var a := lerpf(-2.7, -0.45, i / 3.0)
			p.disque(b + Vector2(cos(a) * 13.6, sin(a) * 5.6 - 3.6), 3.0, 1.3, NEIGE, Pinceau.DOME)


func _recuperateur_vif(p) -> void:
	var r := _hasard(5)
	var mouille := _mouille
	var neige := _neige
	var ton := TOILE.lerp(TOILE_OMBRE.lerp(EAU, 0.12), 0.42 * mouille)
	var clair := TOILE_CLAIR.lerp(TOILE.lerp(EAU, 0.08), 0.5 * mouille)
	var bat := _vent * (0.6 + 0.4 * sin(_t * 2.3 + _graine)) + _vent * _vent * 0.4 * sin(_t * 8.1)
	# (sous la bâche, le sol et le pied des pieux du fond sont dans l'ombre)
	_ombre(p, Vector2(0.0, -6.8), 15.0, 3.6, 0.55)
	# la bâche : quatre coins noués, un pli au milieu que leste une pierre, un bec qui dépasse devant
	var hg := _pr(-11.0, -10.0, 25.5)
	var hd := _pr(11.0, -10.0, 25.5)
	var bg := _pr(-16.5, 2.0, 13.0)
	var bd := _pr(16.5, 2.0, 13.0)
	var hm := _pr(0.0, -10.0, 19.5 - 1.5 * neige)
	var cm := _pr(0.0, -4.0, 13.5 - 1.2 * neige)
	var bec := _pr(0.0, 6.5, 8.2)
	var mg := hg.lerp(bg, 0.5) + Vector2(1.6 + 1.3 * bat, 1.0 - 1.4 * bat)
	var md := hd.lerp(bd, 0.5) + Vector2(-1.6 + 1.6 * bat, 1.0 - 1.8 * bat)
	var gauche := PackedVector2Array()
	gauche.append_array(_courbe(hg, hg.lerp(hm, 0.5) + Vector2(0.0, 0.8), hm, 4))
	gauche.append(cm)
	gauche.append_array(_courbe(bec, bec.lerp(bg, 0.5) + Vector2(0.0, 1.6), bg, 4))
	gauche.append(mg)
	var droite := PackedVector2Array()
	droite.append_array(_courbe(hm, hm.lerp(hd, 0.5) + Vector2(0.0, 0.8), hd, 4))
	droite.append(md)
	droite.append_array(_courbe(bd, bd.lerp(bec, 0.5) + Vector2(0.0, 1.6), bec, 4))
	droite.append(cm)
	p.aplat(gauche, ton.lerp(TOILE_OMBRE, 0.35))
	p.aplat(droite, clair)
	# (l'ombre dans le pli, la lumière sur le pan qui regarde le jour)
	p.aplat(PackedVector2Array([hm, cm, bec, bec.lerp(bg, 0.35) + Vector2(0.0, 0.8), cm.lerp(mg, 0.45), hm.lerp(hg, 0.3) + Vector2(0.0, 0.5)]), TOILE_OMBRE.darkened(0.12))
	p.aplat(PackedVector2Array([hm, hm.lerp(hd, 0.22) + Vector2(0.0, 0.4), cm.lerp(md, 0.2), bec.lerp(bd, 0.16) + Vector2(0.0, 0.5), bec, cm]), ton)
	if neige > 0.12:
		var blanc := PackedVector2Array([hg, hg.lerp(hm, 0.5) + Vector2(0.0, 0.6), hm, hm.lerp(hd, 0.5) + Vector2(0.0, 0.6), hd])
		var f := 0.2 + 0.55 * neige
		for i in 7:
			var u := i / 6.0
			var bas := md.lerp(cm, minf(1.0, u * 2.0)) if u < 0.5 else cm.lerp(mg, (u - 0.5) * 2.0)
			var haut := hd.lerp(hm, minf(1.0, u * 2.0)) if u < 0.5 else hm.lerp(hg, (u - 0.5) * 2.0)
			blanc.append(haut.lerp(bas, f * (1.0 + 0.5 * exp(-pow((u - 0.5) * 5.0, 2.0)) + 0.14 * sin(i * 2.3 + _graine))))
		p.aplat(blanc, NEIGE, Pinceau.DOME, hm + Vector2(0.0, 2.0), Vector2(20.0, 14.0))
		var lis := PackedVector2Array()
		for i in range(5, blanc.size()):
			lis.append(blanc[i])
		p.tracer(lis, 0.8, Color(NEIGE_OMBRE.darkened(0.2), 0.85), false)
	p.tracer(PackedVector2Array([hm, cm, bec]), 0.9, Color(ENCRE, 0.55), false)
	_caillou(p, cm + Vector2(1.4, -2.2), 2.6, 1.9, _pierre_du_lieu().lightened(0.08), r, 0.9)
	p.tracer(_courbe(hg, hg.lerp(hm, 0.5) + Vector2(0.0, 0.8), hm, 4), 0.9, ENCRE, false)
	p.tracer(_courbe(hm, hm.lerp(hd, 0.5) + Vector2(0.0, 0.8), hd, 4), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([hg, mg, bg]), 1.0, ENCRE, false)
	p.tracer(PackedVector2Array([hd, md, bd]), 1.3, ENCRE, false)
	p.tracer(_courbe(bec, bec.lerp(bg, 0.5) + Vector2(0.0, 1.6), bg, 4), 1.4, ENCRE, false)
	p.tracer(_courbe(bd, bd.lerp(bec, 0.5) + Vector2(0.0, 1.6), bec, 4), 1.4, ENCRE, false)
	# les deux pieux de devant, et les nœuds des quatre coins
	for cote in [-1.0, 1.0]:
		_perche(p, _pr(cote * 16.5, 2.0, -0.5), _pr(cote * 16.7, 2.0, 16.0), 3.2, 2.7, ECORCE.lightened(0.06))
		_corde(p, PackedVector2Array([_pr(cote * 16.5 - 2.0, 2.0, 12.7), _pr(cote * 16.5 + 2.0, 2.0, 13.3)]), 0.9)
		_corde(p, PackedVector2Array([_pr(cote * 11.0 - 1.8, -10.0, 25.2), _pr(cote * 11.0 + 1.8, -10.0, 25.8)]), 0.9)
	# l'eau : celle qui court dans le pli, le filet qui tombe du bec, les ronds dans le creux
	var k := clampf(float(etat.get("eau", 0.0)) / 6.0, 0.0, 1.0)
	var e: Array = _recuperateur_eau(k)
	var c: Vector2 = e[0]
	var rx: float = e[1]
	var ry: float = e[2]
	var pale := P.ECHO.lerp(P.PAPIER, 0.4)
	if _pluie > 0.02:
		var force := minf(1.0, _pluie * 2.2)
		for i in (2 if _mobile else 3):
			var u := fposmod(_t * 0.9 + i / 3.0, 1.0)
			var a := hm.lerp(cm, minf(1.0, u * 2.0)) if u < 0.5 else cm.lerp(bec, (u - 0.5) * 2.0)
			var v := minf(1.0, u + 0.08)
			var a2 := hm.lerp(cm, minf(1.0, v * 2.0)) if v < 0.5 else cm.lerp(bec, (v - 0.5) * 2.0)
			p.tracer(PackedVector2Array([a, a2]), 0.9, Color(pale, 0.7 * force), false)
		# (du goutte-à-goutte au filet d'eau, selon la pluie)
		var sol := c.y if k > 0.02 else 9.6
		if _pluie > 0.55:
			var filet := PackedVector2Array()
			for i in 5:
				filet.append(Vector2(bec.x + sin(_t * 9.0 + i * 1.3) * 0.35, lerpf(bec.y + 0.6, sol, i / 4.0)))
			p.tracer(filet, 1.1, Color(pale, 0.7), false)
		else:
			var u := fposmod(_t * (1.2 + 2.2 * _pluie), 1.0)
			p.tracer(PackedVector2Array([Vector2(bec.x, lerpf(bec.y, sol, u * u) - 1.8), Vector2(bec.x, lerpf(bec.y, sol, u * u))]), 1.0, Color(pale, 0.8), false)
		if k > 0.02:
			for i in 2:
				var u := fposmod(_t * 1.5 + i * 0.5, 1.0)
				var rond := Pinceau.ellipse(Vector2(c.x, c.y + 0.2), 1.0 + (rx - 1.6) * u, 0.4 + (ry - 0.6) * u, 12)
				rond.append(rond[0])
				p.tracer(rond, 0.7, Color(pale, 0.6 * (1.0 - u) * force), false)
			# (la pluie tombe aussi dans le creux)
			if not _mobile:
				for i in 2:
					var n: float = floorf(_t * 3.0 + i * 0.5)
					var u := fposmod(_t * 3.0 + i * 0.5, 1.0)
					var q := c + Vector2((fposmod(n * 0.618 + i * 0.37, 1.0) - 0.5) * rx * 1.3, (fposmod(n * 0.381, 1.0) - 0.5) * ry * 0.9)
					var rond := Pinceau.ellipse(q, 0.6 + 1.8 * u, 0.3 + 0.7 * u, 8)
					rond.append(rond[0])
					p.tracer(rond, 0.5, Color(pale, 0.5 * (1.0 - u) * force), false)
	elif k > 0.02 and _vent > 0.25:
		# (le vent ride l'eau)
		var u := fposmod(_t * 0.6, 1.0)
		var y := c.y + ry * (u - 0.5) * 1.2
		var l := rx * sqrt(maxf(0.0, 1.0 - pow((y - c.y) / ry, 2.0))) * 0.7
		p.tracer(PackedVector2Array([Vector2(c.x - l, y), Vector2(c.x, y + 0.3), Vector2(c.x + l, y)]), 0.6, Color(pale, 0.35 * sin(PI * u) * _vent))


# --- le filet : une nappe de mailles tendue au ras du sol, lestée de pierres, un appât au milieu ; une bête prise s'y débat ---

# de combien la bête se débat, à cet instant : de 0 (elle reprend son souffle) à 1 (elle rue)
func _sursaut() -> float:
	if not _pris:
		return 0.0
	var t := _tr - _prise_t
	if t < 2.2:
		return 1.0 - 0.3 * t / 2.2
	var u := fposmod(t - 2.2, 3.7)
	return smoothstep(2.5, 2.62, u) * (1.0 - smoothstep(3.45, 3.7, u))


func _filet(p) -> void:
	var r := _hasard(6)
	var pierre := _pierre_du_lieu()
	var coins := [Vector2(-24.0, -7.5), Vector2(23.0, -9.0), Vector2(27.0, 7.0), Vector2(-22.0, 9.0)]
	var prise: bool = etat.has("prise")
	var masse := 1.0
	if prise and typeof(etat["prise"]) == TYPE_DICTIONARY:
		masse = clampf(float(etat["prise"].get("masse", 1.0)), 0.1, 12.0)
	var rb := 5.8 + 2.4 * pow(masse, 0.42)
	var t := _tr - _prise_t if prise else 0.0
	var rue := _sursaut() if prise else 0.0
	var tour: float = floorf((t - 2.2) / 3.7) if t > 2.2 else -1.0
	var vers := Vector2.from_angle(fposmod(tour * 2.4 + _graine, TAU))
	# où est la bête sous la maille (elle tire d'un côté, de l'autre), et de combien elle la soulève
	var saut := Vector2(sin(t * 23.0) * 0.5 + sin(t * 37.0 + 1.0) * 0.5, sin(t * 29.0 + 2.0)) * rue
	var ou := Vector2(0.5, 0.5) + Vector2(vers.x * 0.1, vers.y * 0.16) * rue + Vector2(saut.x * 0.05, saut.y * 0.07)
	var haleine := sin(t * 8.5) * (1.0 - rue)
	var bosse := (rb * (1.2 + 0.3 * absf(saut.x)) + 0.4 * haleine) if prise else 0.0
	var centre: Vector2 = (coins[0] as Vector2).lerp(coins[1], ou.x).lerp((coins[3] as Vector2).lerp(coins[2], ou.x), ou.y)
	# la nappe : un point de la maille (a en travers, b vers nous), soulevé par ce qu'il y a dessous
	var pt := func(a: float, b: float) -> Vector2:
		var q: Vector2 = (coins[0] as Vector2).lerp(coins[1], a).lerp((coins[3] as Vector2).lerp(coins[2], a), b)
		# (la ralingue se creuse entre deux pierres)
		q += Vector2(2.4 * sin(PI * b) * (pow(1.0 - a, 4.0) - pow(a, 4.0)), 2.0 * absf(sin(TAU * a)) * (pow(1.0 - b, 4.0) - pow(b, 4.0)))
		var h := 1.5 * sin(PI * a) * sin(PI * b)
		if prise:
			var d := (q - centre) * Vector2(1.0, 2.0)
			h += bosse * exp(-d.length_squared() / (rb * rb * 1.5))
			# (la maille se resserre vers la bête)
			q += (centre - q) * 0.16 * sin(PI * a) * sin(PI * b)
		return q + Vector2(0.0, -h)
	if not prise:
		# l'appât : trois baies, sous la maille
		for i in 3:
			var q := Vector2(1.0, 0.6) + Vector2.from_angle(i * 2.1 + 0.4) * 1.9
			p.disque(q, 1.6, 1.5, ENCRE)
			p.disque(q, 1.1, 1.05, BAIE, Pinceau.DOME)
	else:
		# la bête : une masse sombre sous la maille, qui pousse du côté où elle rue ; l'œil pâle d'une proie
		var corps := PackedVector2Array()
		var dos := PackedVector2Array()
		var c := centre + Vector2(0.0, -bosse * 0.42)
		for i in 16:
			var a := TAU * i / 16.0
			var e := 1.0 + 0.12 * sin(a * 2.0 + _graine) + 0.38 * rue * exp(-pow(angle_difference(a, vers.angle()) / 0.7, 2.0)) * (0.6 + 0.4 * absf(saut.y))
			e += 0.045 * haleine
			corps.append(c + Vector2(cos(a) * rb * 1.18, sin(a) * rb * 0.7) * e)
			dos.append(c + Vector2(-rb * 0.2, -rb * 0.2) + Vector2(cos(a) * rb * 0.74, sin(a) * rb * 0.36) * e)
		_ombre(p, centre + Vector2(0.5, 1.0), rb * 1.5, rb * 0.6, 0.4)
		p.aplat(corps, Color("3a2f24"))
		p.aplat(dos, Color("6a5741"))
		corps.append(corps[0])
		p.tracer(corps, 1.0, Color(ENCRE, 0.85), false)
		if fposmod(t, 2.9) > 0.16:
			var oeil := c + Vector2(vers.x * rb * 0.72, vers.y * rb * 0.3 - rb * 0.1)
			p.disque(oeil, 1.5, 1.4, ENCRE)
			p.disque(oeil, 0.95, 0.9, P.OEIL_PROIE)
	# la maille : ses nœuds (une grille), puis deux familles de fils qui les joignent en losanges ; leur ombre sur le sol d'abord
	var n := 7
	var noeuds: Array = []
	for j in n + 1:
		var rang := PackedVector2Array()
		for i in n + 1:
			rang.append(pt.call(float(i) / n, float(j) / n))
		noeuds.append(rang)
	var fils: Array = []
	for k in range(-n + 1, n):
		var fil := PackedVector2Array()
		for i in range(maxi(0, k), mini(n, n + k) + 1):
			fil.append(noeuds[i - k][i])
		fils.append(fil)
	for k in range(1, 2 * n):
		var fil := PackedVector2Array()
		for i in range(maxi(0, k - n), mini(n, k) + 1):
			fil.append(noeuds[k - i][i])
		fils.append(fil)
	# (pas d'ombre sous une maille qui remue : celle de la bête suffit, et elle coûterait à chaque image)
	if not _mobile and not prise:
		for fil in fils:
			var bas := PackedVector2Array()
			for q in fil:
				bas.append(q + Vector2(0.6, 1.5))
			p.tracer(bas, 0.7, Color(P.ENCRE, 0.26), false)
	var fibre := CORDE.darkened(0.1 + 0.15 * _mouille_cran())
	for fil in fils:
		p.tracer(fil, 0.8, fibre, false)
	# la ralingue, autour ; les pierres qui la tiennent (une bête prise en a bousculé une)
	var tour_ := PackedVector2Array()
	for i in n + 1:
		tour_.append(noeuds[0][i])
	for j in range(1, n + 1):
		tour_.append(noeuds[j][n])
	for i in range(n - 1, -1, -1):
		tour_.append(noeuds[n][i])
	for j in range(n - 1, -1, -1):
		tour_.append(noeuds[j][0])
	_corde(p, tour_, 1.1, fibre.lightened(0.08))
	var poids := [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.52, 0.0], [0.45, 1.0]]
	for i in poids.size():
		var q: Vector2 = pt.call(float(poids[i][0]), float(poids[i][1]))
		if prise and i == 4:
			q += Vector2(6.0, -4.5)
		var rr := r.randf_range(3.6, 5.0)
		_ombre(p, q + Vector2(0.6, rr * 0.5), rr * 1.3, rr * 0.5, 0.35)
		_caillou(p, q + Vector2(0.0, -rr * 0.35), rr, rr * 0.72, pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.2)), r)
		if _neige_cran() > 0.25:
			p.disque(q + Vector2(-0.3, -rr * 0.9), rr * 0.7, rr * 0.3, NEIGE, Pinceau.DOME)


# --- le cerf-volant : un piquet, un dévidoir, un fil qui monte ; là-haut, la voilure et sa queue de rubans. Sans vent, il est
# replié au pied du piquet. Branché, deux piles pendent au dévidoir, un fil de cuivre court le long du fil ---

func _charge_en_cours() -> bool:
	return genre == "cerf_volant" and bool(etat.get("branche", false)) and _monte > 0.6 and float(etat.get("charge", 0.0)) < 0.999


# la foudre le prend : un éclair du ciel à la voilure, qui descend le fil jusqu'aux piles (un instant)
func foudroyer() -> void:
	if genre != "cerf_volant":
		return
	_foudre_t = _tr
	_foudre_graine = _graine + int(_tr * 131.0)
	_roussi = true
	_attente = 0.0
	if _lueur == null and not _mobile:
		_lueur = PointLight2D.new()
		_lueur.texture = T.lueur()
		_lueur.texture_scale = 3.4
		_lueur.color = P.ECHO.lerp(Color.WHITE, 0.4)
		_lueur.energy = 0.0
		_lueur.position = Vector2(0.0, -14.0)
		add_child(_lueur)


# la force de l'éclair, à cet instant : un coup, un noir, un second coup, puis ce qui reste dans l'œil
func _eclair() -> float:
	if _foudre_t < 0.0:
		return 0.0
	var t := _tr - _foudre_t
	if t < 0.08:
		return 1.0
	if t < 0.13:
		return 0.12
	if t < 0.21:
		return 0.8
	return 0.5 * exp(-(t - 0.21) * 7.0)


# où est la voilure, à cet instant : [son centre, son angle, où le fil s'y attache]
func _cerf_volant_ou() -> Array:
	var v := _vent_du_fil()
	var m := smoothstep(0.0, 1.0, _monte)
	var danse := Vector2(sin(_t * 0.83 + _graine) * 7.0 + sin(_t * 2.1 + 1.0) * 2.2, sin(_t * 1.27 + 2.0) * 5.0 + sin(_t * 3.1) * 1.3) * (0.35 + 0.75 * v)
	var haut := Vector2(44.0 + 36.0 * v, -(ALTITUDE - 12.0 + 26.0 * v)) + danse
	var c := Vector2(21.0, -3.0).lerp(haut, m) + Vector2(-14.0 * sin(PI * m), 0.0)
	var angle := lerpf(1.35, -0.3 + 0.12 * sin(_t * 1.9 + 0.5) * (0.4 + v) + 0.05 * sin(_t * 5.3), smoothstep(0.0, 0.35, m))
	return [c, angle, c + Vector2(-4.5, 3.0).rotated(angle)]


# le fil, du dévidoir à la voilure : il fait le ventre sous le vent, et pend quand elle redescend
func _cerf_volant_fil(n: int = 16) -> PackedVector2Array:
	var ou: Array = _cerf_volant_ou()
	var bride: Vector2 = ou[2]
	var depart := Vector2(0.6, -13.2)
	var m := smoothstep(0.0, 1.0, _monte)
	var ventre := Vector2(9.0, 15.0) * (1.0 - 0.5 * _vent_du_fil()) * m + Vector2(0.0, 9.0) * (1.0 - m)
	return _courbe(depart, (depart + bride) * 0.5 + ventre, bride, n)


func _cerf_volant(p) -> void:
	var branche := bool(etat.get("branche", false))
	var charge := clampf(float(etat.get("charge", 0.0)), 0.0, 1.0)
	_ombre(p, Vector2(0.8, 1.4), 9.5, 3.6, 0.42)
	# le piquet, planté contre la traction du fil
	var tete := Vector2(-2.4, -17.0)
	_perche(p, Vector2(0.0, 1.2), tete, 4.4, 3.6, BOIS.darkened(0.12))
	if _roussi:
		# (la foudre y est passée : le haut du piquet est noir)
		p.tracer(PackedVector2Array([tete + Vector2(0.5, 5.5), tete + Vector2(0.0, 0.4)]), 2.6, Color("1d1915"), false)
	# le dévidoir : une bobine de fil entre deux flasques, sa manivelle
	var d := Vector2(0.4, -10.2)
	_baton(p, PackedVector2Array([d + Vector2(-4.3, -3.8), d + Vector2(-4.3, 3.8)]), 1.5, BOIS)
	var bobine := PackedVector2Array([d + Vector2(-3.4, -2.2), d + Vector2(-1.5, -2.9), d + Vector2(1.5, -2.9), d + Vector2(3.4, -2.2), d + Vector2(3.4, 2.2),
		d + Vector2(1.5, 2.9), d + Vector2(-1.5, 2.9), d + Vector2(-3.4, 2.2)])
	p.aplat(bobine, CORDE.darkened(0.06))
	for k in 4:
		var x := -2.4 + k * 1.6
		p.tracer(PackedVector2Array([d + Vector2(x, -2.6), d + Vector2(x + 0.5, 2.6)]), 0.5, Color(ENCRE, 0.6), false)
	bobine.append(bobine[0])
	p.tracer(bobine, 0.9, ENCRE, false)
	_baton(p, PackedVector2Array([d + Vector2(4.3, -3.8), d + Vector2(4.3, 3.8)]), 1.5, BOIS)
	_baton(p, PackedVector2Array([d + Vector2(4.6, 0.0), d + Vector2(7.6, 0.3), d + Vector2(7.9, 3.0)]), 1.1, BOIS.lightened(0.08), 0.9)
	# les piles, pendues au dévidoir par leurs fils de cuivre ; leurs bagues disent la charge
	if branche:
		for k in 2:
			var b := Vector2(-7.4 - k * 3.9, -5.6 + k * 0.8)
			p.tracer(PackedVector2Array([d + Vector2(-3.0, 2.0), b + Vector2(0.0, -3.6)]), 0.7, CUIVRE, false)
			p.aplat(PackedVector2Array([b + Vector2(-1.9, -3.5), b + Vector2(1.9, -3.5), b + Vector2(1.9, 3.6), b + Vector2(-1.9, 3.6)]), ENCRE)
			p.aplat(PackedVector2Array([b + Vector2(-1.2, -2.0), b + Vector2(1.2, -2.0), b + Vector2(1.2, 3.0), b + Vector2(-1.2, 3.0)]), METAL)
			p.aplat(PackedVector2Array([b + Vector2(-1.2, -3.0), b + Vector2(1.2, -3.0), b + Vector2(1.2, -2.0), b + Vector2(-1.2, -2.0)]), CUIVRE)
			for i in 3:
				var y := 2.2 - i * 1.5
				var pleine := charge > (i + 0.5) / 3.0
				p.tracer(PackedVector2Array([b + Vector2(-1.2, y), b + Vector2(1.2, y)]), 0.7, CUIVRE.lightened(0.25) if pleine else METAL_CLAIR.darkened(0.25), false)
	if _monte > 0.0:
		return
	# sans vent : la voilure repliée au pied du piquet, sa queue en tas, le fil qui traîne
	_ombre(p, Vector2(22.0, 3.0), 15.0, 3.6, 0.36)
	_hauban(p, _courbe(d + Vector2(1.0, 2.6), Vector2(5.0, 6.0), Vector2(11.0, 2.4), 6))
	var plie := PackedVector2Array([Vector2(9.0, 1.6), Vector2(20.0, -1.8), Vector2(33.0, 0.4), Vector2(21.0, 4.4)])
	p.aplat(plie, TOILE)
	p.aplat(PackedVector2Array([Vector2(9.0, 1.6), Vector2(20.0, -1.8), Vector2(33.0, 0.4)]), TOILE_CLAIR)
	p.aplat(PackedVector2Array([Vector2(24.0, 1.0), Vector2(33.0, 0.4), Vector2(21.0, 4.4), Vector2(20.4, 1.4)]), P.ECHARPE.lerp(TOILE, 0.3))
	p.tracer(PackedVector2Array([Vector2(9.0, 1.6), Vector2(33.0, 0.4)]), 0.8, ENCRE, false)
	plie.append(plie[0])
	p.tracer(plie, 1.1, ENCRE, false)
	for k in 3:
		_ruban(p, Vector2(35.0 + k * 1.6, 3.4 - k * 1.3), Vector2.from_angle(0.5 + k * 1.1), P.ECHARPE if k % 2 == 0 else OS_PALE)


# un ruban de la queue : un nœud, deux coques
static func _ruban(p, q: Vector2, dir: Vector2, c: Color) -> void:
	var tr := dir.orthogonal()
	var noeud := PackedVector2Array([q - tr * 2.9 - dir * 1.3, q - tr * 2.9 + dir * 1.3, q, q + tr * 2.9 - dir * 1.3, q + tr * 2.9 + dir * 1.3, q])
	p.aplat(PackedVector2Array([noeud[0], noeud[1], noeud[2]]), c)
	p.aplat(PackedVector2Array([noeud[3], noeud[4], noeud[5]]), c.darkened(0.15))
	noeud.append(noeud[0])
	p.tracer(noeud, 0.7, ENCRE, false)


func _cerf_volant_vif(p) -> void:
	if _monte <= 0.0:
		return
	var v := _vent_du_fil()
	var ou: Array = _cerf_volant_ou()
	var c: Vector2 = ou[0]
	var angle: float = ou[1]
	var m := smoothstep(0.0, 1.0, _monte)
	var jour: float = float(jeu.lumiere_du_jour()) if jeu != null else 1.0
	# son ombre, loin dessous
	if not _mobile and jour > 0.1:
		_ombre(p, Vector2(c.x * 0.92, 5.0), lerpf(13.0, 8.0, m), lerpf(3.4, 2.4, m), lerpf(0.34, 0.15, m) * jour)
	# le fil ; branché, un fil de cuivre s'y enroule
	var fil := _cerf_volant_fil(18)
	p.tracer(fil, 1.25, ENCRE, false)
	p.tracer(fil, 0.5, CORDE, false)
	if bool(etat.get("branche", false)):
		var long := _cerf_volant_fil(44)
		var cuivre := PackedVector2Array()
		for i in long.size():
			var dir := (long[mini(i + 1, long.size() - 1)] - long[maxi(i - 1, 0)]).normalized()
			cuivre.append(long[i] + dir.orthogonal() * (0.75 if i % 2 == 0 else -0.75))
		p.tracer(cuivre, 0.6, CUIVRE, false)
	# la queue : une ficelle et ses rubans, que le vent couche et fait onduler
	var rot := Transform2D(angle, c)
	var q: Vector2 = rot * Vector2(0.0, 15.5)
	var queue := PackedVector2Array([q])
	var dirs: Array = []
	for k in 9:
		var ang := lerpf(PI * 0.5, 0.55, v * m) + (0.55 * sin(_t * 5.6 - k * 0.85) + 0.2 * sin(_t * 9.1 - k * 1.3)) * (0.25 + 0.75 * v) * minf(1.0, k * 0.3 + 0.2)
		var dir := Vector2.from_angle(ang)
		q += dir * 4.3
		queue.append(q)
		dirs.append(dir)
	p.tracer(queue, 0.8, ENCRE, false)
	for k in [2, 4, 6, 8]:
		_ruban(p, queue[k], dirs[k - 1], P.ECHARPE if (k / 2) % 2 == 1 else OS_PALE)
	# la voilure : un losange de toile sur deux baguettes, un quartier rapiécé de rouille ; ses bords se creusent au vent
	var bat := 0.9 + 0.5 * sin(_t * 6.3) * v
	var nez: Vector2 = rot * Vector2(0.0, -16.5)
	var ag: Vector2 = rot * Vector2(-11.0, -3.5)
	var ad: Vector2 = rot * Vector2(10.4, -3.5)
	var bout: Vector2 = rot * Vector2(0.0, 15.5)
	var coeur: Vector2 = rot * Vector2(0.0, -3.5)
	var m_ng: Vector2 = rot * (Vector2(-5.5, -10.0) + Vector2(0.9, 0.9) * bat)
	var m_nd: Vector2 = rot * (Vector2(5.2, -10.0) + Vector2(-0.9, 0.9) * bat)
	var m_gb: Vector2 = rot * (Vector2(-5.5, 6.0) + Vector2(1.3, -0.8) * bat)
	var m_db: Vector2 = rot * (Vector2(5.2, 6.0) + Vector2(-1.3, -0.8) * bat)
	var eclair := _eclair()
	var toile := TOILE.lerp(Color.WHITE, 0.7 * eclair)
	p.aplat(PackedVector2Array([nez, m_ng, ag, coeur]), TOILE_CLAIR.lerp(Color.WHITE, 0.7 * eclair))
	p.aplat(PackedVector2Array([nez, coeur, ad, m_nd]), toile)
	p.aplat(PackedVector2Array([ag, m_gb, bout, coeur]), toile.lerp(TOILE_CLAIR, 0.4))
	p.aplat(PackedVector2Array([coeur, bout, m_db, ad]), P.ECHARPE.lerp(TOILE, 0.25).lerp(Color.WHITE, 0.6 * eclair))
	if _roussi:
		p.aplat(PackedVector2Array([nez, nez.lerp(m_ng, 0.6), nez.lerp(coeur, 0.3), nez.lerp(m_nd, 0.6)]), Color("2a221b"))
	p.tracer(PackedVector2Array([nez, bout]), 0.9, ENCRE, false)
	p.tracer(_courbe(ag, rot * Vector2(0.0, -4.6), ad, 4), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([nez, m_ng, ag, m_gb, bout]), 1.0, ENCRE, false)
	p.tracer(PackedVector2Array([nez, m_nd, ad, m_db, bout]), 1.3, ENCRE, false)
	# la bride : deux brins, du mât au fil
	var bride: Vector2 = ou[2]
	p.tracer(PackedVector2Array([rot * Vector2(0.0, -10.0), bride]), 0.6, Color(ENCRE, 0.85), false)
	p.tracer(PackedVector2Array([rot * Vector2(0.0, 5.0), bride]), 0.6, Color(ENCRE, 0.85), false)


# ce qui brille : la charge qui crépite le long du cuivre et aux piles ; la foudre
func _cerf_volant_eclat(p) -> void:
	var fil := _cerf_volant_fil(18)
	var charge := clampf(float(etat.get("charge", 0.0)), 0.0, 1.0)
	if _charge_en_cours():
		var r := RandomNumberGenerator.new()
		r.seed = _graine + int(_tr * 15.0)
		var v := _vent_du_fil()
		for i in (2 if _mobile else 4):
			var q: Vector2 = fil[r.randi_range(1, fil.size() - 2)] if i > 0 else Vector2(-8.5 + r.randf_range(-3.0, 2.0), -9.0 + r.randf_range(-1.0, 1.0))
			if r.randf() > 0.35 + 0.5 * v:
				continue
			var l := r.randf_range(1.4, 2.8)
			var a := r.randf() * PI
			for k in 2:
				var dir := Vector2.from_angle(a + k * PI * 0.5) * l
				p.tracer(PackedVector2Array([q - dir, q + dir]), 0.9, Color(P.BRAISE_COEUR, 0.95))
			p.disque(q, 1.0, 1.0, Color(1.0, 0.96, 0.85, 0.9))
	if bool(etat.get("branche", false)) and charge > 0.02:
		for k in 2:
			p.eventail(Vector2(-7.4 - k * 3.9, -8.2 + k * 0.8), 3.6, 3.0, Color(CUIVRE, 0.4 * charge), Color(CUIVRE, 0.0), 10)
	var e := _eclair()
	if e <= 0.0:
		return
	if _lueur != null:
		_lueur.energy = 2.6 * e
	var r := RandomNumberGenerator.new()
	r.seed = _foudre_graine
	var ou: Array = _cerf_volant_ou()
	var rot := Transform2D(float(ou[1]), ou[0])
	var nez: Vector2 = rot * Vector2(0.0, -16.5)
	var blanc := P.ECHO.lerp(Color.WHITE, 0.6)
	# du ciel à la voilure : un trait brisé, ses branches
	var ciel := nez + Vector2(r.randf_range(-90.0, 60.0), -640.0)
	var trait_ := PackedVector2Array([ciel])
	for i in range(1, 12):
		var u := i / 12.0
		trait_.append(ciel.lerp(nez, u) + Vector2(r.randf_range(-22.0, 22.0), r.randf_range(-8.0, 8.0)) * (1.0 - 0.6 * u))
	trait_.append(nez)
	p.tracer(trait_, 13.0, Color(P.ECHO, 0.2 * e), false)
	p.tracer(trait_, 5.0, Color(blanc, 0.65 * e), false)
	p.tracer(trait_, 2.0, Color(1.0, 1.0, 1.0, e), false)
	for k in 2:
		var d: Vector2 = trait_[4 + k * 3]
		var branche := PackedVector2Array([d])
		for i in 4:
			d += Vector2(r.randf_range(8.0, 22.0) * (1.0 if k == 0 else -1.0), r.randf_range(10.0, 26.0))
			branche.append(d)
		p.tracer(branche, 3.0, Color(P.ECHO, 0.3 * e))
		p.tracer(branche, 1.1, Color(1.0, 1.0, 1.0, 0.8 * e))
	# puis le long du fil, jusqu'aux piles ; la voilure s'embrase d'un halo
	p.eventail(ou[0], 30.0, 30.0, Color(blanc, 0.55 * e), Color(blanc, 0.0), 14)
	p.tracer(fil, 6.0, Color(P.ECHO, 0.22 * e), false)
	p.tracer(fil, 1.8, Color(1.0, 1.0, 1.0, 0.9 * e), false)
	p.eventail(Vector2(0.0, -11.0), 22.0, 17.0, Color(blanc, 0.6 * e), Color(blanc, 0.0), 14)
	# des étincelles sautent du dévidoir
	var t := _tr - _foudre_t
	for i in (5 if _mobile else 10):
		var v0 := Vector2.from_angle(r.randf_range(-PI, 0.0)) * r.randf_range(40.0, 110.0)
		var q := Vector2(0.0, -11.0) + v0 * t + Vector2(0.0, 150.0) * t * t
		if q.y > 4.0:
			continue
		p.tracer(PackedVector2Array([q - v0 * 0.03, q]), 1.2, Color(P.BRAISE_COEUR, clampf(1.2 - t * 1.6, 0.0, 1.0)))


# --- le vestige : ce qu'une autre veilleuse a laissé. Un cercle de pierres froides, une caisse rouillée, un sac éventré, une
# botte ; et, à une perche, un lambeau d'écharpe comme la sienne ---

func _vestige(p) -> void:
	var r := _hasard(8)
	var neige := _neige_cran()
	var sombre := 0.16 * _mouille_cran()
	var pierre := _pierre_du_lieu().darkened(0.08 + sombre)
	var fouille := bool(etat.get("fouille", false))
	var noir := Color("1d1915")
	_ombre(p, Vector2(0.0, 4.0), 38.0, 13.0, 0.2)
	# le foyer mort : la cendre grise, deux bouts de bois noirs, l'herbe qui y repousse
	var foyer := Vector2(-10.0, 0.0)
	var cendre := P.CENDRE.lerp(P.IVOIRE, 0.32)
	p.disque(foyer + Vector2(0.0, 0.4), 13.5, 5.6, P.CENDRE.darkened(0.2))
	p.disque(foyer, 10.5, 4.1, cendre)
	var pierres: Array = []
	for i in 9:
		if i == 1 or i == 6:
			continue
		var a := TAU * i / 9.0 + r.randf_range(-0.14, 0.14)
		pierres.append(foyer + Vector2(cos(a) * 15.5, sin(a) * 6.6))
	# (une pierre a roulé hors du cercle)
	pierres.append(foyer + Vector2(-12.0, 11.5))
	pierres.sort_custom(func(x, y): return x.y < y.y)
	for q in pierres:
		if q.y < foyer.y:
			_caillou(p, q + Vector2(0.0, -1.6), r.randf_range(3.2, 4.2), r.randf_range(2.4, 3.0), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.15)), r)
	_baton(p, PackedVector2Array([foyer + Vector2(-6.5, -1.4), foyer + Vector2(3.6, 1.0)]), 2.3, noir.lightened(0.05))
	_baton(p, PackedVector2Array([foyer + Vector2(-2.0, 1.8), foyer + Vector2(5.5, -1.8)]), 2.0, noir.lightened(0.08))
	p.disque(foyer + Vector2(3.6, 1.0), 1.0, 0.9, cendre.lightened(0.1))
	if int(etat.get("riche", 0)) > 0:
		# (un camp mieux pourvu : une gamelle rouillée, renversée dans la cendre)
		var g := foyer + Vector2(-4.0, -2.6)
		p.disque(g, 4.6, 3.4, ENCRE)
		p.disque(g, 3.8, 2.7, ROUILLE.darkened(0.32 + sombre), Pinceau.DOME)
		p.disque(g + Vector2(1.4, 0.5), 2.2, 1.6, Color("17140f"))
		p.tracer(_courbe(g + Vector2(-3.6, -0.6), g + Vector2(-1.0, -6.4), g + Vector2(2.6, -2.0), 6), 0.7, METAL.darkened(0.1), false)
	for i in 5:
		var x := foyer.x + r.randf_range(4.0, 9.5)
		var y := foyer.y + r.randf_range(-1.0, 2.0)
		p.tracer(PackedVector2Array([Vector2(x, y), Vector2(x + r.randf_range(-1.2, 1.2), y - r.randf_range(3.0, 5.5)), Vector2(x + r.randf_range(-2.6, 2.6), y - r.randf_range(6.5, 9.5))]), 1.3,
			P.MOUSSE.lightened(r.randf_range(0.0, 0.14)))
	for q in pierres:
		if q.y >= foyer.y:
			_caillou(p, q + Vector2(0.0, -1.6), r.randf_range(3.2, 4.2), r.randf_range(2.4, 3.0), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.15)), r)
			if r.randf() < 0.6:
				p.disque(q + Vector2(-1.0, -3.4), 1.8, 0.9, P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.3), Pinceau.FEUILLAGE)
	# la perche, calée de deux pierres ; son lambeau pend quand il n'y a pas de vent
	var pied := Vector2(-27.0, -0.5)
	var tete := Vector2(-31.2, -36.5)
	_ombre(p, pied + Vector2(1.0, 1.0), 6.0, 2.2, 0.35)
	_perche(p, pied, tete, 2.8, 2.0, BOIS.lerp(P.CENDRE, 0.4))
	_caillou(p, pied + Vector2(3.0, 0.4), 2.8, 2.0, pierre, r, 0.9)
	_caillou(p, pied + Vector2(-2.6, 0.8), 2.3, 1.7, pierre.lightened(0.06), r, 0.9)
	if _vent <= 0.03:
		_lambeau(p, 0.0)
	# la caisse : de la tôle rouillée, un peu enfoncée dans la terre ; fouillée, son couvercle est levé sur du vide
	var m := Transform2D(-0.07, Vector2(16.0, 2.0))
	var rouille := ROUILLE.darkened(sombre)
	var g0: Vector2 = m * Vector2(-8.5, 0.0)
	var d0: Vector2 = m * Vector2(8.5, 0.0)
	var g1: Vector2 = m * Vector2(-8.5, -9.5)
	var d1: Vector2 = m * Vector2(8.5, -9.5)
	var fuite := m.basis_xform(Vector2(2.8, -4.6))
	_ombre(p, m * Vector2(1.5, 0.6), 13.0, 3.6, 0.45)
	if fouille:
		# (le couvercle, debout derrière ; le dedans, noir)
		var c0 := g1 + fuite
		var c1 := d1 + fuite
		var haut := m.basis_xform(Vector2(1.6, -9.6))
		var couvercle := PackedVector2Array([c0, c1, c1 + haut, c0 + haut])
		p.aplat(couvercle, rouille.darkened(0.22))
		p.tracer(PackedVector2Array([c0.lerp(c0 + haut, 0.5), c1.lerp(c1 + haut, 0.5)]), 0.7, Color(ENCRE, 0.55), false)
		p.contour(couvercle, 1.1, ENCRE, r, 2)
		p.aplat(PackedVector2Array([g1, d1, d1 + fuite, g1 + fuite]), Color("15120e"))
		p.aplat(PackedVector2Array([g1 + fuite, d1 + fuite, d1 + fuite * 0.45, g1 + fuite * 0.45]), rouille.darkened(0.5))
	else:
		var dessus := PackedVector2Array([g1, d1, d1 + fuite, g1 + fuite])
		p.aplat(dessus, rouille.lightened(0.16).lerp(METAL_CLAIR, 0.18))
		p.tracer(PackedVector2Array([g1.lerp(d1, 0.5) + fuite * 0.15, g1.lerp(d1, 0.5) + fuite * 0.85]), 0.7, Color(ENCRE, 0.5), false)
		if neige > 0.2:
			p.aplat(PackedVector2Array([g1 + fuite * 0.2, d1 + fuite * 0.25, d1 + fuite * 0.95, g1 + fuite * 0.95]), NEIGE)
	var face := PackedVector2Array([g0, d0, d1, g1])
	p.aplat(face, rouille)
	p.aplat(PackedVector2Array([d0, d0 + fuite, d1 + fuite, d1]), rouille.darkened(0.34))
	# (la rouille : des taches, deux nervures, le fermoir)
	for i in 9:
		var q: Vector2 = m * Vector2(r.randf_range(-7.4, 7.4), r.randf_range(-8.6, -0.8))
		p.disque(q, r.randf_range(0.7, 1.7), r.randf_range(0.5, 1.2), rouille.darkened(0.3) if i % 3 > 0 else rouille.lerp(P.BRAISE, 0.35))
	for x in [-4.6, 4.6]:
		p.tracer(PackedVector2Array([m * Vector2(x, -9.2), m * Vector2(x, -0.3)]), 0.8, Color(ENCRE, 0.5), false)
	p.aplat(PackedVector2Array([m * Vector2(-1.3, -9.9), m * Vector2(1.3, -9.9), m * Vector2(1.3, -6.6), m * Vector2(-1.3, -6.6)]), METAL.darkened(0.25))
	p.tracer(PackedVector2Array([g1, g0]), 1.0, ENCRE, false)
	p.tracer(PackedVector2Array([g0, d0, d0 + fuite]), 1.5, ENCRE, false)
	p.tracer(PackedVector2Array([d0 + fuite, d1 + fuite]), 1.3, ENCRE, false)
	p.tracer(PackedVector2Array([d0, d1]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([g1, d1]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([g1, g1 + fuite, d1 + fuite]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([d1, d1 + fuite]), 0.9, ENCRE, false)
	for i in 4:
		var x := 6.0 + i * 2.6 + r.randf_range(-0.6, 0.6)
		p.tracer(PackedVector2Array([Vector2(x, 3.0), Vector2(x + r.randf_range(-1.5, 1.5), -r.randf_range(1.5, 4.5))]), 1.2, P.MOUSSE.lightened(r.randf_range(0.0, 0.12)))
	# le sac éventré : le cuir ouvert d'un coup de griffe, sa bourre qui sort, sa sangle
	var sac := PackedVector2Array([Vector2(-2.0, 12.6), Vector2(0.6, 9.0), Vector2(6.6, 8.2), Vector2(11.6, 9.6), Vector2(13.0, 12.6), Vector2(10.4, 15.4), Vector2(3.0, 15.8),
		Vector2(-1.0, 14.8)])
	_ombre(p, Vector2(6.0, 15.0), 10.0, 2.6, 0.4)
	_baton(p, _courbe(Vector2(-1.0, 14.2), Vector2(-8.0, 17.6), Vector2(-9.5, 13.2), 6), 0.9, CUIR_OMBRE, 0.8)
	p.aplat(sac, CUIR.darkened(sombre))
	p.aplat(PackedVector2Array([Vector2(0.6, 9.0), Vector2(6.6, 8.2), Vector2(11.6, 9.6), Vector2(7.0, 10.4), Vector2(1.4, 10.8)]), CUIR_CLAIR.darkened(sombre))
	var rabat := PackedVector2Array([Vector2(7.0, 8.4), Vector2(13.6, 6.2), Vector2(16.4, 9.0), Vector2(11.6, 9.8)])
	p.aplat(rabat, CUIR_CLAIR.darkened(0.12 + sombre))
	p.contour(rabat, 0.9, ENCRE, r, 2)
	p.contour(sac, 1.1, ENCRE, r, 3)
	var plaie := PackedVector2Array([Vector2(1.8, 12.0), Vector2(4.4, 10.8), Vector2(5.8, 12.2), Vector2(8.2, 11.2), Vector2(9.4, 13.0), Vector2(6.4, 14.2), Vector2(3.4, 13.6)])
	p.aplat(plaie, Color("17130f"))
	for i in 4:
		var a := Vector2(3.6 + i * 1.5, 12.8)
		p.tracer(PackedVector2Array([a, a + Vector2(r.randf_range(-1.6, 1.6), 2.2), a + Vector2(r.randf_range(-3.0, 3.0), 4.6)]), 0.8, Color(OS_PALE, 0.9))
	# une botte, couchée sur le flanc : la tige, le pied, la semelle
	var bo := Vector2(25.0, 12.0)
	var botte := PackedVector2Array([bo + Vector2(-5.6, -1.9), bo + Vector2(0.8, -2.3), bo + Vector2(2.4, -4.6), bo + Vector2(5.2, -4.2), bo + Vector2(5.6, 1.6), bo + Vector2(1.0, 1.9),
		bo + Vector2(-5.4, 1.5)])
	_ombre(p, bo + Vector2(0.4, 2.2), 7.5, 2.0, 0.4)
	p.aplat(botte, CUIR_OMBRE.darkened(0.15 + sombre))
	p.aplat(PackedVector2Array([bo + Vector2(-5.6, -1.9), bo + Vector2(-3.4, -2.0), bo + Vector2(-3.2, 1.6), bo + Vector2(-5.4, 1.5)]), CUIR.darkened(sombre))
	p.tracer(PackedVector2Array([bo + Vector2(2.6, -4.7), bo + Vector2(5.5, -4.2), bo + Vector2(5.9, 1.7)]), 1.5, Color("17130f"), false)
	p.disque(bo + Vector2(-5.5, -0.2), 0.8, 1.5, Color("120f0c"))
	p.contour(botte, 0.9, ENCRE, r, 2)
	if neige > 0.2:
		for q in [foyer + Vector2(0.0, -0.5), Vector2(6.0, 9.4), bo + Vector2(0.0, -3.0)]:
			p.disque(q, 5.0 * neige + 1.5, 1.4 * neige + 0.5, NEIGE, Pinceau.DOME)


# --- le coffre d'une autre veilleuse, laissé là depuis longtemps : des planches grises, deux ferrures qui passent sur le
# couvercle, des coins de fer, une serrure rouillée et son moraillon ; de la mousse et des feuilles mortes dessus, l'herbe
# qui a poussé autour, plus haute qu'ailleurs (on n'y marche plus). Un reflet passe de loin en loin sur sa serrure : c'est le
# seul du lieu, on doit le voir. Ouvert : le couvercle rejeté en arrière (on voit son dedans, ses traverses), le dedans
# sombre, la paille, et dans la paille le creux où dormait la lance, un chiffon au bout.
# L'ouverture (« leve », de 0 à 1, une seconde) : elle force la serrure (le couvercle tressaute, la rouille tombe), il se
# lève (la mousse et les feuilles glissent derrière), passe la verticale, retombe en arrière et rebondit : la poussière ---

const COFFRE_W := 13.0              # sa demi-largeur
const COFFRE_Y0 := -7.0             # son fond (la charnière) et son devant, au sol
const COFFRE_Y1 := 5.0
const COFFRE_H := 9.5               # la caisse, sans le couvercle
const COFFRE_E := 3.2               # l'épaisseur du couvercle
const COFFRE_DUREE := 1.0           # l'ouverture, en secondes
const COFFRE_REFLET := 4.6          # un reflet sur la serrure, toutes les tant de secondes
const COFFRE_NOIR := Color("15120e")


func _coffre_bouge() -> bool:
	return (bool(etat.get("ouvert", false)) and _leve < 1.0) or _poussiere >= 0.0


func _lire_coffre(dt: float) -> void:
	var ouvert := bool(etat.get("ouvert", false))
	var bougeait := _coffre_bouge() or _luit
	if not ouvert:
		_leve = 0.0
	elif _leve < 1.0:
		# (l'atelier vient de l'ouvrir : « leve » repart de 0)
		_leve = minf(_leve, clampf(float(etat.get("leve", 1.0)), 0.0, 1.0))
		var avant := _leve
		_leve = minf(1.0, _leve + dt / COFFRE_DUREE)
		etat["leve"] = _leve
		if avant < 0.86 and _leve >= 0.86:
			# (le couvercle retombe en arrière : la poussière, et le bois qui sonne, sourd)
			_poussiere = 0.0
			if jeu != null and jeu.get("sons") != null:
				jeu.sons.jouer("bois", -7.0, 0.6)
	elif float(etat.get("leve", 1.0)) <= 0.0:
		_leve = 0.0
	if _poussiere >= 0.0:
		_poussiere += dt
		if _poussiere > 0.9:
			_poussiere = -1.0
	# (pas de reflet sur un téléphone : au repos, le coffre n'y redessine rien)
	_luit = not ouvert and not _mobile and fmod(_tr + float(_graine % 40) * 0.1, COFFRE_REFLET) < 0.7
	_efface = bougeait and not (_coffre_bouge() or _luit)


# l'angle du couvercle selon « leve » : il tressaute sur sa serrure, se lève (lourd d'abord), retombe en arrière, rebondit
func _coffre_angle() -> float:
	var u := _leve
	if u <= 0.0:
		return 0.0
	if u < 0.34:
		return absf(sin(u * 55.0)) * 0.06 * smoothstep(0.0, 0.12, u)
	if u < 0.86:
		var k := (u - 0.34) / 0.52
		return 1.98 * (0.3 * k + 0.7 * k * k)
	var v := (u - 0.86) / 0.14
	return 1.84 + 0.14 * cos(v * PI * 1.5) * (1.0 - v)


# un point du couvercle : le long de la charnière, de la charnière vers son bord, dans son épaisseur ; a : son angle
static func _coffre_pt(x: float, d: float, h: float, a: float) -> Vector2:
	return _pr(x, COFFRE_Y0 + d * cos(a) - h * sin(a), COFFRE_H + d * sin(a) + h * cos(a))


# une feuille morte : son milieu, sa longueur, son angle
static func _feuille_morte(p, q: Vector2, l: float, ang: float, c: Color) -> void:
	var u := Vector2.from_angle(ang)
	var n := u.orthogonal() * l * 0.36
	p.aplat(PackedVector2Array([q - u * l * 0.5, q + n, q + u * l * 0.5, q - n]), c)
	p.tracer(PackedVector2Array([q - u * l * 0.6, q + u * l * 0.5]), 0.45, Color(ENCRE, 0.6), false)


func _coffre(p) -> void:
	var r := _hasard(31)
	var mouille := _mouille_cran()
	var neige := _neige_cran()
	var sombre := 0.16 * mouille
	var bois := BOIS.lerp(P.CENDRE, 0.3).darkened(0.22 + sombre)
	var fer := METAL.darkened(0.06 + sombre)
	var rouille := ROUILLE.darkened(0.1 + sombre)
	var a := _coffre_angle()
	var w := COFFRE_W
	var bas_av := COFFRE_Y1 * PROF
	var haut_av := bas_av - COFFRE_H
	var haut_ar := COFFRE_Y0 * PROF - COFFRE_H
	_ombre(p, Vector2(0.5, 1.6), 19.5, 5.8, 0.32)
	# l'herbe qui a poussé derrière et sur les côtés : de longs brins, qui dépassent du couvercle
	var rh := _hasard(33)
	for i in 11:
		var x := -17.5 + 35.0 * float(i) / 10.0 + rh.randf_range(-1.3, 1.3)
		var au_bord := absf(x) > 12.5
		var pied := Vector2(x, rh.randf_range(-1.6, 1.6) if au_bord else rh.randf_range(-4.2, -2.6))
		var long := rh.randf_range(8.0, 13.0) if au_bord else rh.randf_range(15.0, 20.5)
		var penche := rh.randf_range(-3.2, 3.2) + (signf(x) * 1.6 if au_bord else 0.0)
		p.tracer(PackedVector2Array([pied, pied + Vector2(penche * 0.3, -long * 0.6), pied + Vector2(penche, -long)]), 1.25,
			P.MOUSSE.lerp(P.FEUILLE_SOMBRE, rh.randf_range(0.0, 0.45)).lightened(rh.randf_range(0.0, 0.12)))
	# le dedans (on ne le voit que le couvercle levé) : le noir, la paroi du fond, la paille et le creux de la lance
	if a > 0.02:
		var trou := PackedVector2Array([Vector2(-w + 1.2, haut_ar + 0.6), Vector2(w - 1.2, haut_ar + 0.6), Vector2(w - 1.0, haut_av), Vector2(-w + 1.0, haut_av)])
		p.aplat(trou, COFFRE_NOIR)
		var jour := smoothstep(0.5, 1.5, a)
		p.aplat(PackedVector2Array([trou[0], trou[1], trou[1] + Vector2(-0.2, 2.4), trou[0] + Vector2(0.2, 2.4)]), COFFRE_NOIR.lerp(bois, 0.42 * jour))
		if jour > 0.05:
			var rp := _hasard(34)
			var paille := CORDE.lerp(CUIVRE, 0.18).darkened(0.18 + sombre)
			for i in 16:
				var q := Vector2(rp.randf_range(-10.5, 10.5), rp.randf_range(haut_ar + 3.6, haut_av - 0.7))
				var v := Vector2.from_angle(rp.randf_range(-0.5, 0.5)) * rp.randf_range(2.2, 4.4)
				p.tracer(PackedVector2Array([q - v * 0.5, q + v * 0.5]), 0.7, Color(paille.lightened(rp.randf_range(-0.1, 0.16)), jour), false)
			# (le creux qu'elle a laissé, long et droit, le chiffon qui enveloppait son fer)
			p.tracer(PackedVector2Array([Vector2(-9.6, haut_av - 2.9), Vector2(6.4, haut_av - 3.5)]), 1.5, Color(COFFRE_NOIR, 0.9 * jour), false)
			p.aplat(PackedVector2Array([Vector2(5.6, haut_av - 4.6), Vector2(9.8, haut_av - 4.9), Vector2(10.4, haut_av - 2.5), Vector2(6.2, haut_av - 2.0)]),
				Color(TOILE_OMBRE.lerp(TOILE, 0.3).darkened(sombre), jour))
			p.tracer(PackedVector2Array([Vector2(6.6, haut_av - 3.9), Vector2(9.6, haut_av - 3.2)]), 0.5, Color(ENCRE, 0.5 * jour), false)
	# la face : trois planches, leur fil, le bas plus sombre (la terre y remonte)
	var face := PackedVector2Array([Vector2(-w, haut_av), Vector2(w, haut_av), Vector2(w, bas_av), Vector2(-w, bas_av)])
	p.aplat(face, bois)
	p.aplat(PackedVector2Array([Vector2(-w, bas_av - 2.6), Vector2(w, bas_av - 2.6), Vector2(w, bas_av), Vector2(-w, bas_av)]), bois.darkened(0.2))
	p.aplat(PackedVector2Array([Vector2(-w, haut_av), Vector2(w, haut_av), Vector2(w, haut_av + 1.3), Vector2(-w, haut_av + 1.3)]), bois.lightened(0.07))
	for y in [haut_av + 3.3, haut_av + 6.5]:
		p.tracer(PackedVector2Array([Vector2(-w + 0.5, y + r.randf_range(-0.25, 0.25)), Vector2(w - 0.5, y + r.randf_range(-0.25, 0.25))]), 0.6, Color(ENCRE, 0.5), false)
	for i in 7:
		var q := Vector2(r.randf_range(-11.5, 8.0), haut_av + r.randf_range(1.0, 8.8))
		p.tracer(PackedVector2Array([q, q + Vector2(r.randf_range(2.0, 4.6), r.randf_range(-0.25, 0.25))]), 0.45, Color(ENCRE, 0.26), false)
	p.contour(face, 1.15, ENCRE, r)
	# les ferrures, leurs rivets ; les coins de fer
	for x in [-7.6, 7.6]:
		p.tracer(PackedVector2Array([Vector2(x, haut_av), Vector2(x, bas_av)]), 2.9, ENCRE, false)
		p.tracer(PackedVector2Array([Vector2(x, haut_av + 0.4), Vector2(x, bas_av - 0.4)]), 1.8, fer, false)
		p.tracer(PackedVector2Array([Vector2(x - 0.5, haut_av + 0.6), Vector2(x - 0.5, bas_av - 0.6)]), 0.45, Color(METAL_CLAIR, 0.5), false)
		for y in [haut_av + 1.7, bas_av - 1.7]:
			p.disque(Vector2(x, y), 0.6, 0.6, METAL_CLAIR.darkened(sombre))
		# (la rouille a coulé sous la ferrure)
		p.tracer(PackedVector2Array([Vector2(x + 1.3, haut_av + 4.0), Vector2(x + 1.5, bas_av - 0.8)]), 0.7, Color(rouille, 0.5), false)
	for c in [-1.0, 1.0]:
		var coin := PackedVector2Array([Vector2(c * w, bas_av - 3.6), Vector2(c * (w - 3.4), bas_av), Vector2(c * w, bas_av)])
		p.aplat(coin, fer.darkened(0.1))
		p.tracer(PackedVector2Array([coin[0], coin[1]]), 0.7, ENCRE, false)
	# la serrure : une platine rouillée, son trou ; la rouille qui a coulé dessous
	var serrure := Vector2(0.0, haut_av + 3.4)
	p.tracer(PackedVector2Array([serrure + Vector2(0.5, 2.2), Vector2(0.8, bas_av - 0.7)]), 0.9, Color(rouille, 0.55), false)
	p.disque(serrure, 3.1, 3.3, ENCRE)
	p.disque(serrure, 2.35, 2.55, rouille.lerp(CUIVRE, 0.22))
	p.disque(serrure + Vector2(-0.7, -0.8), 0.9, 0.7, Color(CUIVRE.lightened(0.2), 0.5))
	p.disque(serrure + Vector2(0.0, -0.2), 0.75, 0.75, COFFRE_NOIR)
	p.tracer(PackedVector2Array([serrure + Vector2(0.0, 0.2), serrure + Vector2(0.0, 1.7)]), 0.7, COFFRE_NOIR, false)
	_coffre_couvercle(p, a, bois, fer, neige, mouille)
	# devant : l'herbe au pied, deux feuilles mortes ; la neige contre les planches
	for i in 6:
		var x := rh.randf_range(-16.0, 16.0)
		var pied := Vector2(x, bas_av + rh.randf_range(0.2, 1.4))
		p.tracer(PackedVector2Array([pied, pied + Vector2(rh.randf_range(-1.4, 1.4), -rh.randf_range(3.2, 6.4))]), 1.15, P.MOUSSE.lightened(rh.randf_range(0.0, 0.16)))
	_feuille_morte(p, Vector2(-15.2, bas_av + 1.0), 3.4, 0.3, ROUILLE.lightened(0.08).darkened(sombre))
	_feuille_morte(p, Vector2(11.6, bas_av + 1.7), 3.0, -0.5, CUIVRE.darkened(0.3 + sombre))
	if neige > 0.1:
		var blanc := Color(NEIGE, minf(1.0, neige * 1.5))
		p.disque(Vector2(-9.5, bas_av + 0.3), 6.5 * neige + 1.5, 1.7, blanc)
		p.disque(Vector2(8.0, bas_av + 0.6), 5.0 * neige + 1.5, 1.4, blanc)
		p.disque(Vector2(-1.0, bas_av + 0.9), 4.0 * neige + 1.0, 1.1, Color(NEIGE_OMBRE, blanc.a))


# le couvercle, à son angle : fermé ou à peine levé, on voit son dessus (ses deux planches, les ferrures, la mousse, les
# feuilles, la neige) ; levé, son dedans (plus sombre, deux traverses) ; et toujours son chant de devant
func _coffre_couvercle(p, a: float, bois: Color, fer: Color, neige: float, mouille: float) -> void:
	var r := _hasard(32)
	var w := COFFRE_W + 0.8
	var d := COFFRE_Y1 - COFFRE_Y0 + 0.7
	var e := COFFRE_E
	var c0 := _coffre_pt(-w, d, 0.0, a)
	var c1 := _coffre_pt(w, d, 0.0, a)
	var c2 := _coffre_pt(w, d, e, a)
	var c3 := _coffre_pt(-w, d, e, a)
	var chant := PackedVector2Array([c3, c2, c1, c0])
	var blanc := Color(NEIGE, minf(1.0, neige * 1.5))
	if a > 0.4636:
		var dedans := PackedVector2Array([_coffre_pt(-w, 0.0, 0.0, a), _coffre_pt(w, 0.0, 0.0, a), c1, c0])
		p.aplat(dedans, bois.darkened(0.36))
		for k in [0.26, 0.76]:
			var g := _coffre_pt(-w + 1.0, d * k, 0.0, a)
			var dr := _coffre_pt(w - 1.0, d * k, 0.0, a)
			p.tracer(PackedVector2Array([g, dr]), 2.3, Color(ENCRE, 0.7), false)
			p.tracer(PackedVector2Array([g, dr]), 1.4, bois.darkened(0.16), false)
		p.contour(dedans, 1.1, ENCRE, r)
		p.aplat(chant, bois.lightened(0.05))
		p.contour(chant, 0.9, ENCRE, r, 2)
		if neige > 0.1:
			p.tracer(PackedVector2Array([c3 + Vector2(0.6, -0.4), c2 + Vector2(-0.6, -0.4)]), 1.3 + neige, blanc, false)
		return
	var dessus := PackedVector2Array([_coffre_pt(-w, 0.0, e, a), _coffre_pt(w, 0.0, e, a), c2, c3])
	p.aplat(dessus, bois.lightened(0.13))
	for i in 5:
		# (le fil des deux planches)
		var x := r.randf_range(-w + 1.5, w - 6.0)
		var k := r.randf_range(0.12, 0.88)
		p.tracer(PackedVector2Array([_coffre_pt(x, d * k, e, a), _coffre_pt(x + r.randf_range(2.5, 5.0), d * k, e, a)]), 0.45, Color(ENCRE, 0.24), false)
	p.tracer(PackedVector2Array([_coffre_pt(-w + 0.6, d * 0.5, e, a), _coffre_pt(w - 0.6, d * 0.5, e, a)]), 0.6, Color(ENCRE, 0.45), false)
	if mouille > 0.1:
		p.tracer(PackedVector2Array([_coffre_pt(-w + 3.0, d * 0.3, e, a), _coffre_pt(w - 8.0, d * 0.3, e, a)]), 0.7, Color(P.IVOIRE, 0.2 * mouille), false)
	p.aplat(chant, bois.darkened(0.1))
	for x in [-7.6, 7.6]:
		var ferrure := PackedVector2Array([_coffre_pt(x, 0.0, e, a), _coffre_pt(x, d, e, a), _coffre_pt(x, d, 0.0, a)])
		p.tracer(ferrure, 2.9, ENCRE, false)
		p.tracer(ferrure, 1.8, fer.lightened(0.07), false)
		p.disque(_coffre_pt(x, d * 0.5, e, a), 0.6, 0.45, METAL_CLAIR)
	p.contour(dessus, 1.1, ENCRE, r)
	p.contour(chant, 1.0, ENCRE, r, 2)
	# le moraillon : rabattu sur la serrure ; forcé, il n'en reste qu'un bout tordu
	var milieu := (c0 + c1) * 0.5
	var bout := Vector2(0.0, COFFRE_Y1 * PROF - COFFRE_H + 1.9) if _leve <= 0.0 else milieu + Vector2(1.3, 1.4)
	p.tracer(PackedVector2Array([milieu + Vector2(0.0, -1.6), bout]), 2.7, ENCRE, false)
	p.tracer(PackedVector2Array([milieu + Vector2(0.0, -1.4), bout]), 1.5, fer.lightened(0.12), false)
	if neige > 0.1:
		# (la neige fait un bourrelet dessus)
		var n0 := _coffre_pt(-w + 0.8, 0.6, e, a)
		var n1 := _coffre_pt(w - 0.8, 0.6, e, a)
		var n2 := _coffre_pt(w - 1.2, d - 1.0, e, a)
		var n3 := _coffre_pt(-w + 1.2, d - 1.0, e, a)
		var tas := PackedVector2Array([n3, n0 + Vector2(0.8, -1.6 * neige), (n0 + n1) * 0.5 + Vector2(0.0, -2.6 * neige), n1 + Vector2(-0.8, -1.6 * neige), n2])
		p.aplat(tas, blanc)
		p.tracer(PackedVector2Array([n3 + Vector2(0.5, -0.2), n2 + Vector2(-0.5, -0.2)]), 0.8, Color(NEIGE_OMBRE, blanc.a), false)
	elif _leve < 0.36:
		# la mousse, sur un coin et le long d'une ferrure ; trois feuilles mortes
		var m := _mouille_cran() * 0.1
		p.disque(_coffre_pt(-8.4, d * 0.34, e, a), 4.8, 2.0, P.MOUSSE.darkened(0.1 + m), Pinceau.FEUILLAGE)
		p.disque(_coffre_pt(-11.0, d * 0.7, e, a), 2.6, 1.3, P.MOUSSE.lightened(0.06), Pinceau.FEUILLAGE)
		p.disque(_coffre_pt(9.4, d * 0.2, e, a), 2.4, 1.0, P.MOUSSE.darkened(0.04), Pinceau.FEUILLAGE)
		_feuille_morte(p, _coffre_pt(2.4, d * 0.42, e, a), 3.6, 0.5, ROUILLE.lightened(0.12))
		_feuille_morte(p, _coffre_pt(5.6, d * 0.74, e, a), 3.0, -0.35, CUIVRE.darkened(0.28))
		_feuille_morte(p, _coffre_pt(-2.6, d * 0.2, e, a), 2.8, 2.6, ROUILLE.darkened(0.12))


# ce qui bouge sur le coffre : le reflet de sa serrure ; puis, quand on l'ouvre, la rouille qui tombe de la serrure forcée,
# les feuilles qui glissent du couvercle, et la poussière quand il retombe
func _coffre_vif(p) -> void:
	var haut_av := COFFRE_Y1 * PROF - COFFRE_H
	if not bool(etat.get("ouvert", false)):
		var k := fmod(_tr + float(_graine % 40) * 0.1, COFFRE_REFLET)
		if k < 0.7:
			var f := sin(k / 0.7 * PI)
			var c := Vector2(-0.7, haut_av + 2.6)
			var pale := Color(P.IVOIRE, 0.9 * f)
			p.tracer(PackedVector2Array([c + Vector2(-3.6 * f, 0.0), c + Vector2(3.6 * f, 0.0)]), 0.8, pale)
			p.tracer(PackedVector2Array([c + Vector2(0.0, -2.6 * f), c + Vector2(0.0, 2.6 * f)]), 0.8, pale)
			p.disque(c, 0.9 * f, 0.9 * f, pale)
		return
	var u := _leve
	if u < 1.0:
		var rv := _hasard(35)
		# (la rouille de la serrure, par miettes)
		for i in (2 if _mobile else 5):
			var t := (u - 0.05 - 0.05 * float(i)) * COFFRE_DUREE
			var v := Vector2(rv.randf_range(-22.0, 22.0), rv.randf_range(-34.0, -12.0))
			if t > 0.0 and t < 0.42:
				p.disque(Vector2(0.0, haut_av + 3.4) + v * t + Vector2(0.0, 190.0 * t * t), 0.7, 0.7, Color(ROUILLE.lightened(0.1), 1.0 - t / 0.42))
		# (les feuilles glissent derrière)
		if u >= 0.36 and u < 0.96:
			var k := (u - 0.36) / 0.6
			for i in 3:
				var q := _coffre_pt([2.4, 5.6, -2.6][i], 6.0, COFFRE_E, minf(_coffre_angle(), 0.7))
				q += Vector2((float(i) - 1.0) * 5.0 * k + sin(k * 9.0 + float(i)) * 1.6, -11.0 * k + 22.0 * k * k)
				_feuille_morte(p, q, 3.2, 0.5 + k * (4.0 + float(i)), Color([ROUILLE.lightened(0.12), CUIVRE.darkened(0.28), ROUILLE.darkened(0.12)][i], 1.0 - k * k))
	if _poussiere >= 0.0:
		var t := clampf(_poussiere / 0.9, 0.0, 1.0)
		var ton := P.IVOIRE.lerp(P.TERRE, 0.45)
		var n := 3 if _mobile else 6
		var rq := _hasard(36)
		for i in n:
			var x := lerpf(-13.0, 13.0, float(i) / float(n - 1)) + rq.randf_range(-2.0, 2.0)
			var c := Vector2(x * (1.0 + 0.55 * t), -15.0 - rq.randf_range(4.0, 11.0) * (1.0 - pow(1.0 - t, 2.0)))
			var ray := rq.randf_range(3.0, 4.6) + 8.0 * t
			p.eventail(c, ray, ray * 0.72, Color(ton, 0.55 * (1.0 - t) * (1.0 - t)), Color(ton, 0.0), 12)


func _vestige_vif(p) -> void:
	if _vent > 0.03:
		_lambeau(p, _vent)


# le lambeau d'écharpe, noué en haut de la perche : il pend, ou bat faiblement au vent
func _lambeau(p, vent: float) -> void:
	var a := Vector2(-30.7, -33.0)
	var ligne := PackedVector2Array([a])
	var q := a
	for k in 6:
		var ang := lerpf(1.42, 0.22, pow(vent, 0.6)) + 0.55 * sin(_t * 6.5 - k * 0.95) * vent * (0.4 + k * 0.12) + 0.05 * k * (1.0 - vent)
		q += Vector2.from_angle(ang) * 2.8
		ligne.append(q)
	var teinte := P.ECHARPE.lerp(P.IVOIRE, 0.28).darkened(0.12 + 0.2 * _mouille_cran())
	p.tracer(ligne, 3.0, ENCRE, false, PackedFloat32Array([3.6, 4.2, 4.2, 3.9, 3.5, 3.0, 2.2]))
	p.tracer(ligne, 2.0, teinte, false, PackedFloat32Array([2.4, 3.0, 3.0, 2.7, 2.3, 1.8, 1.0]))
	# (effiloché : deux fils au bout ; le nœud sur la perche)
	var bout := (ligne[6] - ligne[5]).normalized()
	p.tracer(PackedVector2Array([ligne[6], ligne[6] + bout.rotated(0.5) * 2.4]), 0.6, teinte)
	p.tracer(PackedVector2Array([ligne[6], ligne[6] + bout.rotated(-0.4) * 2.0]), 0.6, teinte)
	_corde(p, PackedVector2Array([a + Vector2(-1.7, -0.6), a + Vector2(1.5, 0.2)]), 1.3, teinte.lightened(0.1))


# --- le jardin et l'élevage ---

# ce sur quoi l'on marche (le carré, l'appât) se trie autrement : sa terre par son bord du fond, pour passer sous les pieds de
# qui la foule ; ses rangs de plantes chacun à sa place, pour qu'on passe entre eux (le lieu trie aussi les enfants d'un
# enfant qui se trie)
func _poser_a_plat() -> void:
	y_sort_enabled = true
	_sol = Calque.new()
	_sol.hote = self
	_sol.quoi = "fond"
	_sol.material = Objet.fixe
	_sol.position = Vector2(0.0, -15.0 if genre == "carre" else -5.0)
	add_child(_sol)
	move_child(_sol, 0)
	if genre != "carre":
		return
	_vif.position = Vector2(0.0, float(CARRE_RANGS[0]))
	for k in [1, 2]:
		var c := Calque.new()
		c.hote = self
		c.quoi = "vif"
		c.rang = k
		c.material = Objet.fixe
		c.position = Vector2(0.0, float(CARRE_RANGS[k]))
		add_child(c)
		_rangs.append(c)


# une pastille : une baie, une fleur, une motte (un petit disque, sans passer par la triangulation)
static func _pastille(p, q: Vector2, rx: float, ry: float, c: Color) -> void:
	p.eventail(q, rx, ry, c, c, 7)


# un rondin couché, de a à b : son écorce, son dos éclairé, son bout coupé (du côté de b)
static func _rondin(p, a: Vector2, b: Vector2, w: float, ecorce: Color, clair: Color) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal() * w * 0.5
	if n.y > 0.0:
		n = -n
	p.aplat(PackedVector2Array([a + n, b + n, b - n, a - n]), ecorce)
	p.tracer(PackedVector2Array([a + n * 0.4 + d, b + n * 0.4 - d * 2.0]), 0.8, Color(ecorce.lightened(0.3), 0.85), false)
	for f in [0.2, 0.47, 0.76]:
		var q := a.lerp(b, float(f))
		p.tracer(PackedVector2Array([q + n * 0.8, q - n * 0.3 + d * 0.7]), 0.6, Color(ENCRE, 0.5))
	p.tracer(PackedVector2Array([a + n, b + n]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([a - n, b - n]), 1.4, ENCRE, false)
	p.tracer(PackedVector2Array([a + n, a - n]), 1.0, ENCRE, false)
	p.disque(b, w * 0.36 + 0.55, w * 0.5 + 0.55, ENCRE)
	p.disque(b, w * 0.36, w * 0.5, clair)
	p.disque(b + Vector2(0.1, 0.1), w * 0.1, w * 0.16, clair.darkened(0.38))


# --- le carré de jardin : une planche de terre retournée entre deux rondins et quelques pierres, ses sillons, ce qui y pousse ---

# un point du carré (le long des sillons, en travers d'eux), déjà vu de trois quarts : il est posé un peu de biais
static func _carre_pt(x: float, y: float) -> Vector2:
	return Vector2(x + y * 0.14, y - x * 0.04)


# la soif des plantes, de 0 (la terre est humide) à 1 (elle est sèche : elles penchent)
func _soif() -> float:
	return 1.0 - smoothstep(0.06, 0.3, clampf(float(etat.get("eau", 0.0)), 0.0, 1.0))


# une ligne le long d'un sillon, à peine tremblée
static func _sillon(y: float, r: RandomNumberGenerator, jeu_y: float = 0.45) -> PackedVector2Array:
	var l := PackedVector2Array()
	for i in 7:
		l.append(_carre_pt(lerpf(-20.0, 20.0, i / 6.0), y + r.randf_range(-jeu_y, jeu_y)))
	return l


func _carre(p) -> void:
	var r := _hasard(21)
	var neige := _neige_cran()
	var mouille := _mouille_cran()
	var eau := maxf(float(int(clampf(float(etat.get("eau", 0.0)), 0.0, 1.0) * 5.0 + 0.5)) / 5.0, 0.5 * mouille)
	var gel := bool(etat.get("gel", false))
	var culture := str(etat.get("culture", ""))
	var stade := clampf(float(etat.get("stade", 0.0)), 0.0, 3.0)
	# la terre : claire et craquelée quand elle a soif, sombre et luisante quand elle a bu
	var terre := P.TERRE.lerp(P.IVOIRE, 0.34 * (1.0 - eau)).darkened(0.08 + 0.4 * eau)
	if gel:
		terre = terre.lerp(NEIGE_OMBRE, 0.22)
	var ecorce := ECORCE.darkened(0.2 * mouille)
	var clair := BOIS_CLAIR.darkened(0.24 * mouille)
	var pierre := _pierre_du_lieu().darkened(0.06 + 0.16 * mouille)
	_ombre(p, Vector2(0.5, 1.5), 29.0, 16.5, 0.22)
	# le repère de ce qu'on y a semé : une baguette, un brin d'écharpe noué
	var repere := _carre_pt(-20.0, -13.6)
	_baton(p, PackedVector2Array([repere, repere + Vector2(-0.7, -8.6)]), 1.2, BOIS.darkened(0.2 * mouille), 0.9)
	p.tracer(PackedVector2Array([repere + Vector2(-0.6, -7.2), repere + Vector2(1.3, -6.2), repere + Vector2(2.2, -4.2)]), 1.5, P.ECHARPE.lerp(P.IVOIRE, 0.2).darkened(0.2 * mouille))
	_rondin(p, _carre_pt(-22.5, -12.7), _carre_pt(22.2, -13.0), 3.4, ecorce, clair)
	# la planche de terre, son bord inégal
	var tour := PackedVector2Array()
	for i in 8:
		tour.append(_carre_pt(lerpf(-21.0, 21.0, i / 7.0), -11.2 + r.randf_range(-0.5, 0.5)))
	for i in 2:
		tour.append(_carre_pt(21.7 + r.randf_range(-0.5, 0.5), lerpf(-4.0, 4.5, float(i))))
	for i in 8:
		tour.append(_carre_pt(lerpf(21.0, -21.0, i / 7.0), 11.4 + r.randf_range(-0.5, 0.5)))
	for i in 2:
		tour.append(_carre_pt(-21.7 + r.randf_range(-0.5, 0.5), lerpf(4.5, -4.0, float(i))))
	p.aplat(tour, terre)
	# les sillons : le creux dans l'ombre, la crête où l'on sème, ses mottes retournées
	for yf in [-10.3, -3.0, 4.0, 10.5]:
		p.tracer(_sillon(float(yf), r), 2.4, terre.darkened(0.32))
	for k in 3:
		var yr: float = CARRE_RANGS[k]
		p.tracer(_sillon(yr, r), 3.3, terre.lightened(0.09))
		for i in 7:
			var q := _carre_pt(r.randf_range(-19.0, 19.0), yr + r.randf_range(-1.7, 0.7))
			var m := r.randf_range(0.8, 1.5)
			p.tracer(PackedVector2Array([q + Vector2(-m, 0.75), q + Vector2(m * 1.1, 0.8)]), 0.8, Color(ENCRE, 0.5), false)
			_pastille(p, q, m, m * 0.62, terre.lightened(r.randf_range(0.12, 0.24)))
	p.contour(tour, 0.9, Color(ENCRE, 0.8), r, 4)
	# (ce qui dépend de son état a son propre hasard : les pierres ne changent pas quand on arrose)
	if eau < 0.25:
		var rc := _hasard(22)
		for i in 7:
			var q := _carre_pt(rc.randf_range(-17.0, 17.0), rc.randf_range(-8.5, 8.5))
			var fente := PackedVector2Array([q])
			for k in 3:
				q += Vector2(rc.randf_range(1.2, 2.6) * (1.0 if i % 2 == 0 else -1.0), rc.randf_range(-1.1, 1.3))
				fente.append(q)
			p.tracer(fente, 0.7, Color(ENCRE, 0.62))
	elif eau > 0.55:
		var rl := _hasard(23)
		var luit := Color(P.ECHO.lerp(P.PAPIER, 0.3), 0.34 * (eau - 0.55) / 0.45 + 0.1 * mouille)
		for i in 8:
			var q := _carre_pt(rl.randf_range(-17.0, 17.0), float([-3.0, 4.0, 10.3, -10.1][i % 4]) + 0.3)
			p.tracer(PackedVector2Array([q + Vector2(-rl.randf_range(1.5, 3.4), 0.0), q + Vector2(rl.randf_range(1.5, 3.4), -0.15)]), 0.8, luit)
	# semé : les graines se voient encore, sur la crête
	if culture != "" and stade < 0.75:
		var rg := _hasard(24)
		var grain := P.IVOIRE
		if culture == "lin":
			grain = P.IVOIRE.lerp(CUIVRE, 0.4)
		elif culture == "grain":
			grain = P.BRAISE.lerp(P.IVOIRE, 0.45).darkened(0.05)
		elif culture == "baie":
			grain = P.IVOIRE.lerp(BAIE, 0.3)
		elif culture.contains(":"):
			# (une herbe de l'herbier : sa graine a un peu de sa couleur)
			grain = Herbe.graine(culture)
		for k in 3:
			for i in 9:
				_pastille(p, _carre_pt(lerpf(-18.0, 18.0, i / 8.0) + rg.randf_range(-1.0, 1.0), float(CARRE_RANGS[k]) + rg.randf_range(-0.8, 0.5)), 0.65, 0.5, grain)
	if gel and neige < 0.5:
		var rf := _hasard(25)
		var givre := Color(NEIGE.lerp(P.ECHO, 0.2), 0.85)
		for i in 24:
			var q := _carre_pt(rf.randf_range(-20.0, 20.0), rf.randf_range(-10.5, 10.5))
			p.tracer(PackedVector2Array([q, q + Vector2(rf.randf_range(0.8, 2.0), rf.randf_range(-0.5, 0.2))]), 0.8, givre)
	if neige > 0.15:
		# la neige comble les sillons, puis couvre tout ; les crêtes se devinent à leur ombre
		p.aplat(tour, Color(NEIGE, clampf(neige * 1.15 - 0.1, 0.0, 0.94)))
		var rn := _hasard(26)
		for k in 3:
			p.tracer(_sillon(float(CARRE_RANGS[k]) + 1.5, rn), 1.3, Color(NEIGE_OMBRE.darkened(0.12), 0.8 * neige))
	# les pierres des deux bouts, le rondin de devant
	for cote in [-1.0, 1.0]:
		for i in 3:
			var q := _carre_pt(float(cote) * (23.6 + r.randf_range(-0.5, 0.8)), -7.2 + i * 7.0 + r.randf_range(-0.8, 0.8))
			_caillou(p, q + Vector2(0.0, -0.8), r.randf_range(2.5, 3.3), r.randf_range(1.9, 2.4), pierre.lerp(P.IVOIRE, r.randf_range(0.0, 0.14)), r, 0.9)
			if neige > 0.2:
				p.disque(q + Vector2(-0.2, -2.4), 2.1, 0.6 + 0.7 * neige, NEIGE, Pinceau.DOME)
	var droite := _carre_pt(22.8, 13.3)
	var gauche := _carre_pt(-23.0, 13.6)
	_rondin(p, droite, gauche, 3.8, ecorce.lightened(0.05), clair)
	if neige > 0.2:
		for bord in [[_carre_pt(-21.0, -14.5), _carre_pt(20.5, -14.8)], [gauche + Vector2(2.0, -1.8), droite + Vector2(-1.0, -1.8)]]:
			p.tracer(PackedVector2Array([bord[0], bord[1]]), 0.8 + 1.5 * neige, NEIGE)


# le vert d'une plante : il jaunit quand elle a soif, il blanchit sous le givre
func _verdure(c: Color, givre: bool) -> Color:
	var v := c.lerp(CORDE, 0.42 * _sec)
	return v.lerp(NEIGE_OMBRE.lightened(0.25), 0.45) if givre else v


# un rang de plantes : elles penchent au vent comme l'herbe du lieu, s'affaissent quand elles ont soif, tressautent sous la dent
func _carre_vif(p, rang: int) -> void:
	var culture := str(etat.get("culture", ""))
	var stade := clampf(float(etat.get("stade", 0.0)), 0.0, 3.0)
	if culture == "" or stade < 0.25:
		return
	var r := _hasard(60 + rang)
	var n := 4 if _mobile else 5
	var broute := clampf(float(etat.get("broute", 0.0)), 0.0, 1.0)
	var givre := bool(etat.get("gel", false)) or _neige > 0.3
	var yr: float = CARRE_RANGS[rang]
	var mur := smoothstep(2.6, 3.0, stade)
	for i in n:
		# (en quinconce d'un rang à l'autre ; chacune a son avance, sa taille, son côté où tomber)
		var x := lerpf(-18.0, 18.0, (i + 0.5) / n) + r.randf_range(-1.3, 1.3) + (1.8 if rang == 1 else 0.0)
		var q := _carre_pt(x, yr + r.randf_range(-0.7, 0.7))
		var s := clampf(stade + (r.randf() - 0.62) * 0.36 * (1.0 - mur), 0.0, 3.0)
		var k := r.randf_range(0.88, 1.12) * (1.0 - 0.14 * _sec)
		var cote := 1.0 if r.randf() < 0.5 else -1.0
		var g := r.randf()
		if s < 0.25:
			continue
		var bal := sin(_t * (1.7 + 1.5 * _vent) + x * 0.13 + rang * 1.1) * (0.03 + 0.2 * _vent) + 0.15 * _vent + cote * 0.4 * _sec
		if broute > 0.0:
			bal += sin(_tr * 37.0 + i * 2.3 + rang) * 0.3 * broute
			k *= 1.0 + 0.07 * broute * sin(_tr * 29.0 + i * 1.7)
		match culture:
			"baie":
				_plant_baie(p, q, s, k, bal, g, givre)
			"lin":
				_plant_lin(p, q, s, k, bal, g, givre)
			"simple":
				_plant_simple(p, q, s, k, bal, g, givre)
			"grain":
				_plant_grain(p, q, s, k, bal, g, givre)
			_:
				# (une herbe de l'herbier, semée : « foret:ombelle » ; son dessin est celui du lieu, en petit : scripts/herbe.gd)
				if culture.contains(":"):
					Herbe.plant(p, culture, q, s, k, bal, g, _sec, givre, _mobile)


# les baies : deux feuilles rondes, puis un buisson bas et sombre, ses fleurs pâles, ses baies qui rougissent
func _plant_baie(p, q: Vector2, s: float, k: float, bal: float, g: float, givre: bool) -> void:
	var vert := _verdure(P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.3), givre)
	if s < 1.0:
		var u0 := (s - 0.25) / 0.75
		var h := (1.0 + 3.4 * u0) * k
		var haut := q + Vector2(bal * h, -h)
		var f := 0.7 + 1.0 * u0
		p.tracer(PackedVector2Array([q, haut]), 0.9, vert.lightened(0.2), false, PackedFloat32Array(), not _mobile)
		_pastille(p, haut + Vector2(-f, -0.2), f, f * 0.7, vert.lightened(0.3))
		_pastille(p, haut + Vector2(f, -0.4), f, f * 0.7, vert.lightened(0.2))
		return
	var u := clampf(s - 1.0, 0.0, 1.0)
	var rx := (2.3 + 2.1 * u) * k
	var ry := (2.0 + 1.8 * u) * k
	var c := q + Vector2(bal * ry * 1.5, -ry - 0.3)
	var touffes := [Vector2(-0.52 * rx, 0.3 * ry), Vector2(0.52 * rx, 0.24 * ry), Vector2(bal * ry * 0.9, -0.42 * ry)]
	if _mobile:
		p.eventail(c + Vector2(0.0, -0.06 * ry), rx * 1.2 + 0.8, ry * 1.06 + 0.8, ENCRE, ENCRE, 10)
	else:
		for o in touffes:
			_pastille(p, c + o, rx * 0.68 + 0.8, ry * 0.7 + 0.8, ENCRE)
	for j in 3:
		var o: Vector2 = touffes[j]
		p.eventail(c + o, rx * 0.68, ry * 0.7, vert.lightened(0.06 * j), vert.lightened(0.06 * j), 9, Pinceau.FEUILLAGE)
	if givre:
		_pastille(p, c + Vector2(-0.25 * rx, -0.75 * ry), rx * 0.5, ry * 0.26, Color(NEIGE, 0.8))
	# (les fleurs passent, les baies viennent : vertes d'abord, puis rouges)
	var fleur := smoothstep(1.5, 1.95, s) * (1.0 - smoothstep(2.2, 2.55, s))
	var fruit := smoothstep(2.15, 3.0, s)
	if fleur <= 0.05 and fruit <= 0.05:
		return
	var rouge := vert.lightened(0.35).lerp(BAIE.lerp(P.BRAISE_ROUGE, 0.6), smoothstep(0.2, 0.8, fruit))
	for j in (3 if _mobile else 5):
		var a := g * TAU + j * 2.4
		var o := Vector2(cos(a) * rx * (0.5 + 0.12 * (j % 3)), sin(a) * ry * 0.42 - ry * 0.1)
		if fruit > 0.05:
			_pastille(p, c + o, 0.55 + 0.45 * fruit, 0.55 + 0.4 * fruit, rouge)
		elif j < 4:
			_pastille(p, c + o, 0.9 * fleur, 0.8 * fleur, P.PAPIER.lerp(P.ECHARPE, 0.14))


# le lin : des brins fins et hauts, clairs, qui ploient ensemble ; leurs fleurs bleues, puis leurs capsules dorées
func _plant_lin(p, q: Vector2, s: float, k: float, bal: float, g: float, givre: bool) -> void:
	var mur := smoothstep(2.1, 3.0, s)
	var vert := _verdure(P.MOUSSE.lerp(CORDE, 0.34).lightened(0.14).lerp(CORDE, 0.5 * mur), givre)
	var bleu := P.LUNE.lerp(P.ECHO, 0.22)
	var n := 3 if (_mobile or s < 1.0) else 5
	var h0 := (1.5 + 4.0 * clampf((s - 0.25) / 0.75, 0.0, 1.0) + 9.0 * clampf(s - 1.0, 0.0, 1.0)) * k
	var fleur := smoothstep(1.5, 2.0, s)
	for j in n:
		var e := j - (n - 1) * 0.5
		var h1 := fposmod(g * 5.3 + j * 0.61, 1.0)
		var hj := h0 * (0.7 + 0.3 * h1)
		var pied := q + Vector2(e * 1.15 + (h1 - 0.5) * 0.9, 0.0)
		var pen := bal * 1.3 + e * 0.1 + (fposmod(g * 9.1 + j * 0.37, 1.0) - 0.5) * 0.2
		var haut := pied + Vector2(pen * hj, -hj + absf(pen) * hj * 0.3)
		p.tracer(PackedVector2Array([pied, pied + Vector2(pen * hj * 0.3, -hj * 0.55), haut]), 1.0, vert.lightened(0.1 * (j % 2)), false, PackedFloat32Array([1.25, 0.95, 0.6]), not _mobile)
		if fleur <= 0.05:
			continue
		if mur > 0.05 and j % 2 == 0:
			_pastille(p, haut, 0.55 + 0.6 * mur, 0.55 + 0.65 * mur, CORDE.darkened(0.12).lerp(CUIVRE, 0.25))
		else:
			_pastille(p, haut, 1.2 * fleur, 1.05 * fleur, bleu)
	if givre:
		_pastille(p, q + Vector2(bal * h0 * 0.5, -h0 * 0.55), 1.6, 0.6, Color(NEIGE, 0.7))


# les grains (scripts/jardin.gd) : deux lames fines, puis une touffe qui talle, ses tiges qui montent ; leurs épis, verts, se
# remplissent, puis dorent et ploient sous leur poids. Mûrs, le rang entier a la couleur de la paille
func _plant_grain(p, q: Vector2, s: float, k: float, bal: float, g: float, givre: bool) -> void:
	var mur := smoothstep(2.2, 3.0, s)
	var vert := _verdure(P.MOUSSE.lerp(CORDE, 0.2).lightened(0.1), givre)
	var paille := CORDE.lerp(P.IVOIRE, 0.25).lerp(P.BRAISE_COEUR, 0.12)
	var tige := vert.lerp(paille, mur)
	var u0 := clampf((s - 0.25) / 0.75, 0.0, 1.0)
	var u1 := clampf(s - 1.0, 0.0, 1.0)
	# (les lames, au pied)
	var nl := 2 if (s < 1.0 or _mobile) else 4
	for j in nl:
		var cote := -1.0 if j % 2 == 0 else 1.0
		var l := (1.6 + 2.6 * u0 + 1.8 * u1) * k
		var bout := q + Vector2(cote * (1.2 + 0.4 * j) * l * 0.45 + bal * l * 0.6, -l * (0.9 - 0.12 * j))
		p.tracer(PackedVector2Array([q, q.lerp(bout, 0.5) + Vector2(-cote * 0.4, -0.3), bout]), 0.9, vert.lerp(paille, mur * 0.6).darkened(0.05 * j), true, PackedFloat32Array(), not _mobile)
	if s < 1.2:
		return
	# (les tiges, et leurs épis : un épi qui se remplit, puis qui ploie, doré)
	var nt := 2 if _mobile else 3
	var epi := smoothstep(1.6, 2.2, s)
	var or_ := P.BRAISE_COEUR.lerp(P.IVOIRE, 0.3).lerp(CORDE, 0.3).darkened(0.06)
	for j in nt:
		var e := j - (nt - 1) * 0.5
		var h1 := fposmod(g * 7.3 + j * 0.47, 1.0)
		var hj := (2.5 + 9.5 * u1 * (0.8 + 0.2 * h1)) * k
		var pied := q + Vector2(e * 1.1, 0.0)
		var pen := bal * 1.2 + e * 0.12 + (0.22 * mur) * (1.0 if g > 0.5 else -1.0)
		var haut := pied + Vector2(pen * hj, -hj + absf(pen) * hj * 0.25)
		p.tracer(PackedVector2Array([pied, pied + Vector2(pen * hj * 0.3, -hj * 0.55), haut]), 0.95, tige, false, PackedFloat32Array([1.15, 0.9, 0.6]), not _mobile)
		if epi <= 0.05:
			continue
		# (l'épi : trois grains en chevron, qui pendent un peu plus quand il mûrit)
		var d := Vector2(pen * 0.6 + 0.35 * mur * signf(pen + 0.001), -1.0 + 0.55 * mur).normalized()
		var c := tige.lerp(or_, mur)
		for m in 3:
			var gq := haut + d * (0.9 + 1.25 * m) * epi
			_pastille(p, gq + d.orthogonal() * 0.55, 0.62 * epi + 0.2, 0.5 * epi + 0.2, c)
			_pastille(p, gq - d.orthogonal() * 0.55, 0.62 * epi + 0.2, 0.5 * epi + 0.2, c.darkened(0.08))
		if mur > 0.3 and not _mobile:
			p.tracer(PackedVector2Array([haut + d * 3.4 * epi, haut + d * 5.6 * epi + d.orthogonal() * 0.6]), 0.4, Color(ENCRE, 0.5))
	if givre:
		_pastille(p, q + Vector2(bal * 2.0, -2.2), 1.8, 0.6, Color(NEIGE, 0.7))


# les simples : une rosette gris-vert au ras du sol, deux hampes, leurs ombelles plates qui pâlissent en mûrissant
func _plant_simple(p, q: Vector2, s: float, k: float, bal: float, g: float, givre: bool) -> void:
	var vert := _verdure(P.MOUSSE.lerp(P.IVOIRE, 0.36), givre)
	var u0 := clampf((s - 0.25) / 0.75, 0.0, 1.0)
	var u1 := clampf(s - 1.0, 0.0, 1.0)
	var nf := 3 if (s < 1.0 or _mobile) else 5
	var lf := (1.4 + 2.2 * u0 + 1.9 * u1) * k
	for j in nf:
		var a := -PI * 0.5 + (j - (nf - 1) * 0.5) * (0.66 if nf == 5 else 0.8) + (g - 0.5) * 0.3
		var bout := q + Vector2(cos(a) * lf + bal * 1.2, sin(a) * lf * 0.55 - 0.2)
		p.tracer(PackedVector2Array([q, q.lerp(bout, 0.55) + Vector2(0.0, -0.7), bout]), 1.5 if nf == 5 else 1.9, vert.lightened(0.05 * (j % 2)), true, PackedFloat32Array(), not _mobile)
	if s <= 1.15:
		return
	var fl := smoothstep(1.45, 2.0, s)
	var mur := smoothstep(2.1, 3.0, s)
	for j in 2:
		var hj := (2.0 + (9.6 - j * 3.2) * u1) * k
		var pied := q + Vector2(-0.9 + j * 1.9, -0.5)
		var pen := bal + (j - 0.5) * 0.24
		var haut := pied + Vector2(pen * hj, -hj)
		p.tracer(PackedVector2Array([pied, pied.lerp(haut, 0.5) + Vector2(-pen * hj * 0.12, 0.0), haut]), 0.85, vert.darkened(0.15), false, PackedFloat32Array(), not _mobile)
		if fl <= 0.05:
			continue
		# (une ombelle : trois bouquets plats, serrés, sur leur ombre d'encre)
		var rx := (1.1 + 1.6 * mur) * (0.45 + 0.55 * fl) * k
		var ry := rx * 0.3 + 0.3
		var pale := vert.lightened(0.2).lerp(P.PAPIER, 0.3 + 0.7 * mur)
		p.eventail(haut + Vector2(0.0, 0.2), rx + 0.7, ry + 0.75, Color(ENCRE, 0.85), Color(ENCRE, 0.85), 10)
		if _mobile:
			p.eventail(haut + Vector2(0.0, -0.1), rx, ry, pale.darkened(0.03), pale.darkened(0.03), 9)
			continue
		_pastille(p, haut + Vector2(-rx * 0.45, 0.1), rx * 0.55, ry * 0.8, pale.darkened(0.1))
		_pastille(p, haut + Vector2(rx * 0.45, 0.15), rx * 0.55, ry * 0.8, pale.darkened(0.04))
		_pastille(p, haut + Vector2(0.0, -ry * 0.45), rx * 0.6, ry * 0.75, pale)
	if givre:
		_pastille(p, q + Vector2(0.0, -1.2), lf * 0.6, 0.6, Color(NEIGE, 0.7))


# --- l'épouvantail : une croix de perches habillée de bâche, bourrée de fibres ; une tête de toile, deux trous pour les yeux ---

# le regard qu'on lui dit (un angle du lieu) ; sans lui, il regarde devant lui : vers nous
func _regard_voulu() -> float:
	return float(etat["regard"]) if etat.has("regard") else PI * 0.5


# un point de son corps (de côté, en hauteur) : sa perche penche un rien, et tremble d'autant plus qu'on est haut
func _ep(x: float, z: float) -> Vector2:
	return Vector2(x + 0.025 * z, -z) + _secousse * pow(clampf(z / 40.0, 0.0, 1.2), 1.4)


# son pied : la perche plantée, calée de pierres, les brins qui en sont tombés
func _epouvantail(p) -> void:
	var r := _hasard(31)
	var neige := _neige_cran()
	var mouille := _mouille_cran()
	var pierre := _pierre_du_lieu().darkened(0.06 + 0.16 * mouille)
	var paille := CORDE.lightened(0.12).darkened(0.22 * mouille)
	_ombre(p, Vector2(2.5, 1.0), 13.0, 4.0, 0.34)
	for i in 5:
		var q := Vector2(r.randf_range(-9.0, 10.0), r.randf_range(-0.5, 3.6))
		var d := Vector2.from_angle(r.randf_range(-0.5, 0.5)) * r.randf_range(1.6, 2.8)
		p.tracer(PackedVector2Array([q - d, q + d]), 0.9, paille.darkened(r.randf_range(0.0, 0.2)))
	_perche(p, Vector2(0.0, 0.8), Vector2(0.3, -15.0), 3.1, 2.7, BOIS.darkened(0.12 + 0.2 * mouille))
	_caillou(p, Vector2(-3.0, 0.9), 2.7, 1.9, pierre, r, 0.9)
	_caillou(p, Vector2(3.1, 1.3), 2.3, 1.7, pierre.lightened(0.07), r, 0.9)
	for i in 3:
		var x := -6.5 + i * 5.6 + r.randf_range(-0.8, 0.8)
		p.tracer(PackedVector2Array([Vector2(x, 2.4), Vector2(x + r.randf_range(-1.2, 1.2), -r.randf_range(1.6, 4.2))]), 1.2, P.MOUSSE.lightened(r.randf_range(0.0, 0.12)))
	if neige > 0.2:
		p.disque(Vector2(0.6, 1.4), 3.0 + 2.6 * neige, 0.8 + 0.8 * neige, NEIGE, Pinceau.DOME)


# une bande de toile qui pend d'un point, et bat au vent
func _pan(p, a: Vector2, long: float, w: float, c: Color, phase: float) -> void:
	var pousse := 0.5 * _vent + 0.42 * sin(_t * 5.6 + phase) * _vent + 0.05 * sin(phase * 3.0) + 0.3 * _secousse.x
	var m := a + Vector2(pousse * long * 0.3, long * 0.52)
	var b := a + Vector2(pousse * long * 0.9, long * (1.0 - 0.22 * absf(pousse)))
	var ligne := PackedVector2Array([a, m, b])
	p.tracer(ligne, w + 1.0, ENCRE, false, PackedFloat32Array([w + 1.1, w + 1.0, w * 0.5 + 0.8]))
	p.tracer(ligne, w, c, false, PackedFloat32Array([w, w * 0.9, w * 0.4]))


# ce qui tient en l'air : ses bras, sa bâche, ses brins, son écharpe, sa tête et son chapeau. De jour, tout cela bat au vent ;
# la nuit, sa tête a tourné
func _epouvantail_vif(p) -> void:
	var r := _hasard(32)
	var neige := _neige_cran()
	var mouille := _mouille_cran()
	var alerte := clampf(float(etat.get("alerte", 0.0)), 0.0, 1.0)
	var toile := TOILE.darkened(0.26 * mouille)
	var paille := CORDE.lightened(0.14).darkened(0.22 * mouille)
	var bois := BOIS.darkened(0.2 * mouille)
	# il tremble : à peine d'abord, puis de tout son bois
	_secousse = Vector2(sin(_tr * (29.0 + 26.0 * alerte)), 0.45 * sin(_tr * (41.0 + 19.0 * alerte) + 1.3)) * (0.25 * alerte + 1.15 * alerte * alerte)
	# de combien sa tête a tourné (0 : vers nous ; son buste la suit d'un tiers)
	var tour := angle_difference(PI * 0.5, _tete)
	var buste := clampf(tour * 0.32, -0.8, 0.8)
	var bras := Vector2(cos(buste), sin(buste) * PROF)
	var large := 0.84 + 0.16 * cos(buste)
	_perche(p, _ep(0.3, 13.5), _ep(0.0, 43.0), 2.7, 2.2, bois.darkened(0.12))
	# les brins qui sortent par le bas, là où seraient ses jambes
	for i in 6:
		var x := -3.4 + i * 1.4 + r.randf_range(-0.4, 0.4)
		var bas := _ep(x * 1.5, r.randf_range(8.0, 10.5)) + Vector2(_vent * 1.6 + 0.8 * sin(_t * 4.8 + i) * _vent, 0.0)
		p.tracer(PackedVector2Array([_ep(x, 15.5), bas]), 1.1, paille.darkened(0.08 * (i % 3)))
	# ses bras : une traverse, un bout plus bas que l'autre ; au bout, une poignée de brins pour main
	var epaule := _ep(0.0, 29.6)
	var mains := [epaule - bras * 13.2 + Vector2(0.0, 1.1), epaule + bras * 13.2 + Vector2(0.0, -1.3)]
	_baton(p, PackedVector2Array([mains[0], mains[1]]), 1.9, bois)
	for k in 2:
		var cote := -1.0 if k == 0 else 1.0
		var main: Vector2 = mains[k]
		for i in 4:
			var a := (0.0 if cote > 0.0 else PI) + (i - 1.5) * 0.42 + r.randf_range(-0.12, 0.12) + 0.25 * _vent * sin(_t * 5.0 + i + k)
			p.tracer(PackedVector2Array([main - Vector2(cote * 1.0, 0.0), main + Vector2(cos(a), sin(a) * 0.9) * r.randf_range(3.2, 4.6)]), 1.0, paille.darkened(0.06 * i))
	# ses manches : la bâche jetée sur la traverse, qui pend dessous ; un lambeau à chaque poignet
	for k in 2:
		var cote := -1.0 if k == 0 else 1.0
		var main: Vector2 = mains[k]
		var poignet := main.lerp(epaule, 0.14)
		var pend := Vector2(0.9 * _vent + 0.5 * sin(_t * 4.4 + k * 2.0) * _vent, 0.0)
		var manche := PackedVector2Array([_ep(cote * 2.6, 32.6), poignet + Vector2(0.0, -1.7), poignet + Vector2(cote * 0.5, 2.2), main.lerp(epaule, 0.5) + Vector2(0.0, 6.8) + pend,
			_ep(cote * 4.8 * large, 23.6)])
		p.aplat(manche, toile.darkened(0.1 + (0.12 if cote * buste < -0.05 else 0.0)))
		manche.append(manche[0])
		p.tracer(manche, 1.0, ENCRE, false)
		_pan(p, poignet + Vector2(cote * 0.3, 1.6), 5.6, 2.3, toile.darkened(0.16), 1.7 + k * 2.6)
	# son buste : une bâche serrée d'une corde, rapiécée ; le bas en dents, et ses lambeaux
	var corps := PackedVector2Array([_ep(-4.2, 32.6), _ep(4.2, 32.6), _ep(6.5 * large, 24.0), _ep(7.1 * large, 16.0)])
	for i in 7:
		corps.append(_ep(lerpf(7.0, -7.0, i / 6.0) * large, (13.2 if i % 2 == 0 else 15.6) + r.randf_range(-0.5, 0.5)))
	corps.append(_ep(-7.1 * large, 16.0))
	corps.append(_ep(-6.5 * large, 24.0))
	for i in 4:
		_pan(p, _ep((-5.2 + i * 3.4) * large, 14.6), 5.0 + (i % 2) * 1.6, 2.4, toile.darkened(0.2), i * 1.9)
	p.aplat(corps, toile)
	p.aplat(PackedVector2Array([_ep(1.8, 32.4), _ep(4.2, 32.6), _ep(6.5 * large, 24.0), _ep(7.1 * large, 16.0), _ep(5.2 * large, 14.2), _ep(2.8, 15.0)]), toile.darkened(0.17))
	p.tracer(PackedVector2Array([_ep(-2.2, 30.5), _ep(-2.9, 24.5), _ep(-2.4, 16.5)]), 0.7, Color(ENCRE, 0.42))
	p.tracer(PackedVector2Array([_ep(1.4, 29.0), _ep(1.9, 17.5)]), 0.7, Color(ENCRE, 0.36))
	var piece := PackedVector2Array([_ep(-5.0 * large, 29.0), _ep(-1.6 * large, 29.6), _ep(-1.3 * large, 25.8), _ep(-4.8 * large, 25.4)])
	p.aplat(piece, CUIR_CLAIR.darkened(0.08 + 0.2 * mouille))
	piece.append(piece[0])
	p.tracer(piece, 0.7, Color(ENCRE, 0.8), false)
	corps.append(corps[0])
	p.tracer(corps, 1.1, ENCRE, false)
	_corde(p, PackedVector2Array([_ep(-6.8 * large, 22.3), _ep(0.0, 21.5), _ep(6.8 * large, 22.6)]), 1.0)
	_corde(p, _courbe(_ep(2.0, 21.6), _ep(3.8, 18.6), _ep(2.6 + 1.4 * _vent, 16.2), 5), 0.8)
	p.disque(_ep(2.0, 21.6), 1.1, 1.0, CORDE.darkened(0.15))
	if neige > 0.2:
		for k in 2:
			var main: Vector2 = mains[k]
			p.tracer(PackedVector2Array([main.lerp(epaule, 0.1) + Vector2(0.0, -2.0), main.lerp(epaule, 0.8) + Vector2(0.0, -2.6)]), 1.0 + 1.4 * neige, NEIGE)
	# sa tête : un sac de toile bourré, noué au cou ; l'écharpe qu'elle lui a laissée
	var tete := _ep(0.2, 37.2)
	var clair := TOILE_CLAIR.darkened(0.24 * mouille)
	var echarpe := P.ECHARPE.lerp(P.IVOIRE, 0.12).darkened(0.1 + 0.2 * mouille)
	for i in 4:
		var x := -2.7 + i * 1.8
		p.tracer(PackedVector2Array([_ep(x * 0.6, 33.4), _ep(x * 1.3, 30.4 - (i % 2) * 0.8)]), 1.5, clair.darkened(0.2))
	p.disque(tete, 5.9, 6.4, ENCRE)
	p.disque(tete, 5.0, 5.6, clair, Pinceau.DOME)
	# (la couture de l'arrière du sac : on la voit quand il nous tourne le dos)
	if sin(_tete) < -0.15:
		var x := -cos(_tete) * 4.6
		p.tracer(_courbe(tete + Vector2(x, -4.6), tete + Vector2(x * 1.2, 0.0), tete + Vector2(x, 4.4), 6), 0.7, Color(ENCRE, 0.6), false)
		for i in 3:
			var q := tete + Vector2(x * 1.08, -2.4 + i * 2.3)
			p.tracer(PackedVector2Array([q + Vector2(-1.1, -0.3), q + Vector2(1.1, 0.3)]), 0.6, Color(ENCRE, 0.6), false)
	# (deux trous, l'un plus grand que l'autre : ils ne brillent pas ; ils sont seulement là où il regarde)
	for k in 2:
		var cote := -1.0 if k == 0 else 1.0
		var a := _tete + cote * 0.5
		var face := sin(a)
		if face < -0.1:
			continue
		var q := tete + Vector2(cos(a) * 4.5, -0.6 + 0.5 * face)
		_pastille(p, q, (1.3 if k == 0 else 1.0) * clampf(0.3 + 0.7 * face, 0.3, 1.0), 1.65 if k == 0 else 1.3, Color("17130f"))
	p.tracer(PackedVector2Array([_ep(-3.9, 32.9), _ep(0.0, 31.8), _ep(3.9, 33.0)]), 3.0, ENCRE, false)
	p.tracer(PackedVector2Array([_ep(-3.7, 32.9), _ep(0.0, 31.9), _ep(3.7, 33.0)]), 2.0, echarpe, false)
	var bout := _ep(3.0, 32.3)
	var ligne := PackedVector2Array([bout])
	for k in 5:
		var ang := lerpf(1.45, 0.3, pow(_vent, 0.6)) + 0.5 * sin(_t * 6.5 - k * 0.95) * _vent * (0.4 + k * 0.12) + 0.06 * k * (1.0 - _vent) + 0.3 * alerte * sin(_tr * 43.0 + k)
		bout += Vector2.from_angle(ang) * 2.5
		ligne.append(bout)
	p.tracer(ligne, 2.8, ENCRE, false, PackedFloat32Array([3.2, 3.6, 3.5, 3.2, 2.7, 2.0]))
	p.tracer(ligne, 1.8, echarpe, false, PackedFloat32Array([2.0, 2.4, 2.3, 2.0, 1.5, 0.8]))
	# son chapeau de fibres tressées, de travers
	var m := Transform2D(-0.16, _ep(0.5, 41.4))
	p.aplat(m * Pinceau.ellipse(Vector2.ZERO, 9.3, 3.3, 16), ENCRE)
	p.aplat(m * Pinceau.ellipse(Vector2.ZERO, 8.5, 2.6, 16), paille.darkened(0.1))
	p.aplat(m * Pinceau.ellipse(Vector2(-0.6, -0.4), 6.6, 1.7, 14), paille.lightened(0.08))
	var calotte: PackedVector2Array = m * PackedVector2Array([Vector2(-4.4, 0.2), Vector2(-3.7, -3.4), Vector2(-0.8, -4.9), Vector2(2.6, -4.3), Vector2(4.3, 0.2), Vector2(0.0, 1.3)])
	p.aplat(calotte, paille.darkened(0.04))
	p.tracer(m * PackedVector2Array([Vector2(-4.1, -0.9), Vector2(0.0, 0.2), Vector2(4.1, -0.8)]), 1.1, echarpe.darkened(0.25), false)
	p.tracer(m * PackedVector2Array([Vector2(-4.4, 0.2), Vector2(-3.7, -3.4), Vector2(-0.8, -4.9), Vector2(2.6, -4.3), Vector2(4.3, 0.2)]), 1.0, ENCRE, false)
	for i in 3:
		var q: Vector2 = m * Vector2([-8.3, 7.6, 3.4][i], [0.3, 0.9, 2.3][i])
		p.tracer(PackedVector2Array([q, q + Vector2([-2.2, 2.4, 1.0][i], [1.2, 0.6, 1.9][i])]), 0.8, paille)
	if neige > 0.2:
		p.aplat(m * Pinceau.ellipse(Vector2(-0.4, -4.0), 3.6, 0.8 + 1.0 * neige, 10), NEIGE)
		p.aplat(m * Pinceau.ellipse(Vector2(-4.6, -0.6), 3.0, 0.5 + 0.6 * neige, 8), NEIGE)


# --- le piquet d'attache : un pieu court, enfoncé au maillet ; son anneau de corde ---

func _pieu(p) -> void:
	var r := _hasard(36)
	var neige := _neige_cran()
	var mouille := _mouille_cran()
	var attache := bool(etat.get("attache", false))
	var bois := BOIS.darkened(0.2 * mouille)
	var pied := Vector2(0.0, 0.8)
	var tete := Vector2(-1.2, -13.6)
	# la terre foulée autour de lui (plus encore quand une bête y tourne)
	p.eventail(Vector2(0.6, 0.9), 14.0 if attache else 8.5, 5.4 if attache else 3.3, Color(P.TERRE.darkened(0.2), 0.55 if attache else 0.4), Color(P.TERRE, 0.0), 14)
	_ombre(p, Vector2(1.8, 0.9), 6.5, 2.4, 0.42)
	_perche(p, pied, tete, 4.2, 3.6, bois)
	# (un reste d'écorce au pied ; la tête écrasée par le maillet, ses éclats)
	var reste := PackedVector2Array([pied + Vector2(-2.0, -0.2), pied + Vector2(2.0, -0.2), Vector2(1.6, -3.4), Vector2(0.4, -2.6), Vector2(-0.8, -4.8), Vector2(-2.3, -3.2)])
	p.aplat(reste, ECORCE.darkened(0.2 * mouille))
	p.tracer(PackedVector2Array([Vector2(1.6, -3.4), Vector2(0.4, -2.6), Vector2(-0.8, -4.8), Vector2(-2.3, -3.2)]), 0.6, Color(ENCRE, 0.7), false)
	p.tracer(PackedVector2Array([pied + Vector2(2.0, -0.2), Vector2(1.6, -3.6)]), 1.4, ENCRE, false)
	p.disque(tete, 2.6, 1.3, ENCRE)
	p.disque(tete + Vector2(0.0, -0.1), 1.9, 0.8, BOIS_CLAIR.darkened(0.1 + 0.2 * mouille))
	p.tracer(PackedVector2Array([tete + Vector2(-2.1, 0.3), tete + Vector2(-3.3, 1.9)]), 0.9, BOIS_CLAIR.darkened(0.2 * mouille))
	p.tracer(PackedVector2Array([tete + Vector2(2.0, 0.5), tete + Vector2(2.9, 2.4)]), 0.9, BOIS_CLAIR.darkened(0.15 + 0.2 * mouille))
	_caillou(p, Vector2(-3.4, 1.2), 2.0, 1.4, _pierre_du_lieu().darkened(0.06 + 0.16 * mouille), r, 0.9)
	for i in 3:
		_pastille(p, Vector2(r.randf_range(2.0, 6.5), r.randf_range(0.6, 2.4)), r.randf_range(0.8, 1.3), 0.6, P.TERRE.lightened(r.randf_range(0.0, 0.12)))
	# l'anneau de corde : deux tours sur le pieu, et sa boucle, qui pend ; tenue par une longe, elle se serre sur un nœud
	var haut := pied.lerp(tete, 0.7)
	for k in (3 if attache else 2):
		var c := pied.lerp(tete, 0.72 - k * 0.09)
		_corde(p, PackedVector2Array([c + Vector2(-2.4, -0.3), c + Vector2(2.3, 0.5)]), 1.0)
	if attache:
		var noeud := haut + Vector2(2.6, 0.3)
		var anneau: PackedVector2Array = Transform2D(-0.2, noeud + Vector2(2.4, -0.4)) * Pinceau.ellipse(Vector2.ZERO, 2.3, 1.5, 10)
		anneau.append(anneau[0])
		_corde(p, anneau, 0.9)
		p.disque(noeud, 1.7, 1.5, ENCRE)
		p.disque(noeud, 1.1, 0.95, CORDE.darkened(0.1))
	else:
		var boucle: PackedVector2Array = Transform2D(0.5, Vector2(5.0, -4.2)) * Pinceau.ellipse(Vector2.ZERO, 2.5, 5.2, 12)
		boucle.append(boucle[0])
		_corde(p, boucle, 0.9)
		_corde(p, PackedVector2Array([haut + Vector2(2.2, 0.4), Vector2(3.4, -8.6)]), 0.9)
	if neige > 0.2:
		p.disque(tete + Vector2(0.0, -0.9), 2.3, 0.9 + 0.8 * neige, NEIGE, Pinceau.DOME)


# --- la mangeoire : une auge de deux rondins fendus, le plat en dedans, couchée dans deux croix de pieux liés ---

# un point de la mangeoire : le long de l'auge (vers la droite et vers nous), en travers (vers nous, à gauche), en hauteur
static func _mg(l: float, w: float, z: float) -> Vector2:
	return Vector2(l * 0.87 - w * 0.5, l * 0.25 + w * 0.43 - z)


# le dos du tas de foin, au-dessus du bord de devant (u : le long de l'auge, de 0 à 1 ; foin : de 0, vide, à 1, comble)
static func _foin_dos(u: float, foin: float) -> float:
	return (0.8 + 7.4 * foin) * (0.3 + 0.7 * sin(PI * clampf(u, 0.0, 1.0)))


func _mangeoire(p) -> void:
	var r := _hasard(41)
	var neige := _neige_cran()
	var mouille := _mouille_cran()
	var foin := clampf(float(etat.get("foin", 0)) / 12.0, 0.0, 1.0)
	var ecorce := ECORCE.darkened(0.2 * mouille)
	var clair := BOIS_CLAIR.darkened(0.24 * mouille)
	var paille := CORDE.lightened(0.16).darkened(0.25 * mouille)
	_ombre(p, Vector2(0.0, 1.5), 21.0, 8.5, 0.36)
	# les brins tombés dessous, de la dernière fois
	for i in 6:
		var q := Vector2(r.randf_range(-13.0, 12.0), r.randf_range(-2.0, 5.0))
		var d := Vector2.from_angle(r.randf_range(-0.6, 0.6)) * r.randf_range(1.5, 2.6)
		p.tracer(PackedVector2Array([q - d, q + d]), 0.9, paille.darkened(r.randf_range(0.05, 0.25)))
	# de chaque croix, le pieu qui passe derrière l'auge
	for l in [-12.0, 12.0]:
		_perche(p, _mg(float(l), 8.0, 0.0), _mg(float(l), -7.0, 17.0), 2.7, 2.2, ecorce.darkened(0.15))
	# l'auge : le plat du rondin du fond, son creux
	var fa := _mg(-16.0, 0.0, 9.5)
	var fb := _mg(16.0, 0.0, 9.5)
	var ra := _mg(-16.0, -5.5, 16.0)
	var rb := _mg(16.0, -5.5, 16.0)
	var na := _mg(-16.0, 5.5, 16.0)
	var nb := _mg(16.0, 5.5, 16.0)
	p.aplat(PackedVector2Array([ra, rb, fb, fa]), clair.darkened(0.14))
	p.aplat(PackedVector2Array([fa, fb, fb.lerp(rb, 0.42), fa.lerp(ra, 0.42)]), Color("1d1915").lerp(clair, 0.12))
	for i in 3:
		var u := r.randf_range(0.1, 0.8)
		p.tracer(PackedVector2Array([ra.lerp(rb, u) + Vector2(0.0, 1.6 + i), ra.lerp(rb, u + 0.14) + Vector2(0.0, 1.6 + i)]), 0.5, Color(ENCRE, 0.4))
	p.tracer(PackedVector2Array([ra, rb]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([ra + Vector2(0.2, 0.9), rb + Vector2(-0.4, 0.9)]), 0.6, Color(clair.lightened(0.2), 0.8), false)
	# la planchette qui la ferme, au bout qui vient vers nous
	var bout := PackedVector2Array([nb, rb, fb])
	p.aplat(bout, BOIS.darkened(0.1 + 0.2 * mouille))
	p.tracer(PackedVector2Array([nb.lerp(rb, 0.5), fb + Vector2(-0.2, -1.2)]), 0.5, Color(ENCRE, 0.45), false)
	# le foin : des fibres en tas, qui dépassent du bord ; vide, on voit le fond
	if foin > 0.0:
		var tas := PackedVector2Array([na + Vector2(0.6, -0.2)])
		for k in 9:
			var u := k / 8.0
			tas.append(na.lerp(nb, 0.03 + 0.94 * u) + Vector2(1.3, -_foin_dos(u, foin) + r.randf_range(-0.5, 0.5)))
		tas.append(nb + Vector2(-0.4, -0.2))
		p.aplat(tas, paille)
		var dos := tas.slice(1, 10)
		p.tracer(dos, 1.0, ENCRE, false)
		for i in 5 + int(foin * 9.0):
			var u := r.randf_range(0.06, 0.94)
			var q := na.lerp(nb, u) + Vector2(1.3, -r.randf_range(0.1, 0.85) * _foin_dos(u, foin))
			var d := Vector2.from_angle(r.randf_range(-0.9, 0.9)) * r.randf_range(1.4, 2.8)
			p.tracer(PackedVector2Array([q - d, q + d]), 0.7, paille.darkened(0.3) if i % 3 == 0 else paille.lightened(0.16))
	# le rondin de devant : son écorce vers nous, la tranche claire de son plat
	var devant := PackedVector2Array([na, nb, fb + Vector2(0.0, 0.7), fa + Vector2(0.0, 0.7)])
	p.aplat(devant, ecorce.lightened(0.05))
	p.tracer(PackedVector2Array([na.lerp(fa, 0.3) + Vector2(1.0, 0.0), nb.lerp(fb, 0.3) + Vector2(-1.0, 0.0)]), 0.8, Color(ecorce.lightened(0.26), 0.8), false)
	for i in 5:
		var u := r.randf_range(0.05, 0.92)
		p.tracer(PackedVector2Array([na.lerp(nb, u) + Vector2(0.4, 1.3), na.lerp(nb, u) + Vector2(0.9, 3.6)]), 0.6, Color(ENCRE, 0.5))
	var tranche := Vector2(0.7, -0.6)
	p.aplat(PackedVector2Array([na, nb, nb + tranche, na + tranche]), clair)
	p.tracer(PackedVector2Array([na, nb]), 0.9, ENCRE, false)
	p.tracer(PackedVector2Array([na, fa + Vector2(0.0, 0.7)]), 1.0, ENCRE, false)
	p.tracer(PackedVector2Array([fa + Vector2(0.0, 0.7), fb + Vector2(0.0, 0.7)]), 1.5, ENCRE, false)
	p.tracer(PackedVector2Array([nb, fb + Vector2(0.0, 0.7), rb, nb]), 1.1, ENCRE, false)
	if neige > 0.2:
		p.tracer(PackedVector2Array([ra + Vector2(1.0, -0.6), rb + Vector2(-1.0, -0.6)]), 0.8 + 1.2 * neige, NEIGE)
		p.tracer(PackedVector2Array([na + Vector2(1.5, -0.9), nb + Vector2(-0.5, -0.9)]), 0.8 + 1.4 * neige, NEIGE)
		if foin > 0.0:
			var cime := na.lerp(nb, 0.5) + Vector2(1.3, -_foin_dos(0.5, foin) + 0.5)
			p.aplat(Transform2D(0.28, cime) * Pinceau.ellipse(Vector2.ZERO, 3.0 + 3.6 * neige, 0.7 + 0.9 * neige, 10), NEIGE)
	# de chaque croix, le pieu qui passe devant ; la ligature, là où ils se croisent
	for l in [-12.0, 12.0]:
		_perche(p, _mg(float(l), -8.0, 0.0), _mg(float(l), 7.0, 17.0), 2.9, 2.3, ecorce.lightened(0.04))
		var c := _mg(float(l), 0.0, 9.0)
		_corde(p, PackedVector2Array([c + Vector2(-2.3, -1.3), c + Vector2(2.2, 1.0)]), 0.9)
		_corde(p, PackedVector2Array([c + Vector2(-2.2, 0.9), c + Vector2(2.3, -1.2)]), 0.9)
		if neige > 0.2:
			p.disque(_mg(float(l), 7.0, 17.6), 1.6, 0.7 + 0.5 * neige, NEIGE, Pinceau.DOME)


# les brins qui dépassent du tas, et que le vent tire
func _mangeoire_vif(p) -> void:
	var foin := clampf(float(etat.get("foin", 0)) / 12.0, 0.0, 1.0)
	if foin <= 0.0:
		return
	var r := _hasard(43)
	var paille := CORDE.lightened(0.2).darkened(0.25 * _mouille_cran())
	var na := _mg(-16.0, 5.5, 16.0)
	var nb := _mg(16.0, 5.5, 16.0)
	for i in (3 if _mobile else 6):
		var u := r.randf_range(0.12, 0.88)
		var pied := na.lerp(nb, u) + Vector2(1.3, -_foin_dos(u, foin) + 0.6)
		var h := r.randf_range(2.2, 4.4)
		var pen := r.randf_range(-0.5, 0.5) + 0.6 * _vent + 0.4 * sin(_t * 5.2 + i * 1.9) * _vent
		p.tracer(PackedVector2Array([pied, pied + Vector2(pen * h * 0.4, -h * 0.6), pied + Vector2(pen * h, -h)]), 0.85, paille.darkened(0.08 * (i % 3)))


# --- l'appât : une poignée de baies, sur une feuille ; sa sorte (« sorte ») : "" (les baies), « dormant » (des baies mêlées
# d'herbe à dormir), « poison » (un morceau de viande, des feuilles écrasées dessus) ---

# ce qu'il en reste, en baies
func _appat_baies() -> int:
	return int(ceil(clampf(float(etat.get("reste", 1.0)), 0.0, 1.0) * 7.0 - 0.001))


func _appat(p) -> void:
	var sorte := str(etat.get("sorte", ""))
	if sorte == "poison":
		_appat_poison(p)
		return
	var r := _hasard(51)
	var n := _appat_baies()
	var vert := P.MOUSSE.lightened(0.24)
	_ombre(p, Vector2(0.4, 1.4), 9.0, 3.4, 0.34)
	# la feuille : large, un peu roulée, sa nervure pâle
	var feuille := PackedVector2Array([Vector2(-8.0, 0.9), Vector2(-5.0, -2.0), Vector2(-0.6, -3.2), Vector2(3.9, -2.6), Vector2(6.8, -0.5), Vector2(4.2, 2.2), Vector2(-0.4, 3.2),
		Vector2(-4.8, 2.7)])
	p.aplat(feuille, vert)
	p.aplat(PackedVector2Array([Vector2(-8.0, 0.9), Vector2(-0.6, 0.4), Vector2(6.8, -0.5), Vector2(4.2, 2.2), Vector2(-0.4, 3.2), Vector2(-4.8, 2.7)]), vert.darkened(0.2))
	p.tracer(PackedVector2Array([Vector2(-7.4, 0.8), Vector2(-0.6, 0.3), Vector2(6.4, -0.5)]), 0.7, Color(P.PAPIER, 0.6), false)
	for x in [-4.2, -1.0, 2.4]:
		p.tracer(PackedVector2Array([Vector2(float(x), 0.5), Vector2(float(x) + 1.6, -1.9)]), 0.5, Color(P.PAPIER, 0.4))
	p.contour(feuille, 1.0, ENCRE, r, 3)
	_baton(p, PackedVector2Array([Vector2(6.6, -0.5), Vector2(9.2, -1.7)]), 0.8, vert.darkened(0.3), 0.8)
	# ce qu'on y a déjà mangé : le jus, deux queues
	if n < 7:
		for q in [Vector2(-3.2, 1.5), Vector2(2.6, 1.0), Vector2(0.2, -1.4)]:
			_pastille(p, q, 1.0, 0.6, Color(P.SANG, 0.5))
		p.tracer(PackedVector2Array([Vector2(3.4, 1.4), Vector2(4.6, 0.2)]), 0.6, CUIR_OMBRE)
	# les baies, en tas : celles du dessus partent les premières
	var places := [Vector2(-3.4, 0.5), Vector2(-1.1, 1.0), Vector2(1.3, 0.8), Vector2(3.4, 0.2), Vector2(-2.2, -1.5), Vector2(2.2, -1.6), Vector2(0.0, -2.3)]
	var rouge := BAIE.lerp(P.BRAISE_ROUGE, 0.7)
	for i in n:
		var q: Vector2 = places[i]
		_pastille(p, q, 2.1, 2.0, ENCRE)
		_pastille(p, q, 1.45, 1.35, rouge.darkened(0.12 * (i % 2)))
		_pastille(p, q + Vector2(-0.45, -0.45), 0.45, 0.4, Color(P.PAPIER, 0.75))
	if sorte == "dormant":
		# l'herbe à dormir, mêlée aux baies : trois brins pâles qui dépassent, leurs petites feuilles, une fleur
		var brin := P.MOUSSE.lightened(0.36).lerp(P.IVOIRE, 0.25)
		for b in [[Vector2(-2.0, 0.6), Vector2(-7.6, -4.4)], [Vector2(0.6, -0.4), Vector2(2.6, -6.2)], [Vector2(2.4, 1.2), Vector2(8.8, -3.2)]]:
			var a: Vector2 = b[0]
			var c: Vector2 = b[1]
			var cote := (c - a).orthogonal().normalized()
			var mi := a.lerp(c, 0.56)
			_baton(p, PackedVector2Array([a, a.lerp(c, 0.5) + Vector2(0.0, -0.8), c]), 0.9, brin, 0.8)
			p.tracer(PackedVector2Array([mi, mi + cote * 2.3 + (c - a) * 0.12]), 1.4, brin.lightened(0.12))
			p.tracer(PackedVector2Array([mi, mi - cote * 2.1 + (c - a) * 0.12]), 1.4, brin)
		_pastille(p, Vector2(2.7, -6.5), 1.55, 1.45, ENCRE)
		_pastille(p, Vector2(2.7, -6.5), 1.0, 0.95, P.PAPIER)
	if _neige_cran() > 0.3:
		_pastille(p, Vector2(-5.2, -0.4), 2.0, 0.8, Color(NEIGE, 0.9))


# l'appât empoisonné : un morceau de viande sombre, son gras, son bout d'os ; les feuilles écrasées dessus, leur jus ; une
# mouche. Ce qu'une bête en a mangé y manque
func _appat_poison(p) -> void:
	var r := _hasard(52)
	var n := _appat_baies()
	_ombre(p, Vector2(0.4, 1.6), 9.5, 3.4, 0.36)
	if n <= 0:
		# (il n'en reste qu'une tache, et l'os)
		_pastille(p, Vector2(-1.0, 1.0), 4.2, 1.7, Color(P.SANG, 0.5))
		_baton(p, PackedVector2Array([Vector2(1.0, 0.6), Vector2(5.2, -0.6)]), 1.2, P.IVOIRE.lightened(0.15), 0.9)
		return
	var k := 0.64 + 0.36 * n / 7.0
	var chair := P.SANG.lerp(BAIE, 0.3).darkened(0.1)
	var morceau := PackedVector2Array()
	for q in [Vector2(-7.6, 0.6), Vector2(-5.6, -2.8), Vector2(-1.0, -4.2), Vector2(4.0, -3.4), Vector2(7.4, -0.6), Vector2(6.6, 2.4), Vector2(2.0, 3.6), Vector2(-3.6, 3.4)]:
		var v: Vector2 = q
		morceau.append(Vector2(v.x * k, v.y * lerpf(k, 1.0, 0.5)))
	# l'os dépasse, derrière
	_baton(p, PackedVector2Array([Vector2(5.0 * k, -0.6), Vector2(8.8 * k + 0.8, -2.0)]), 1.4, P.IVOIRE.lightened(0.15), 0.9)
	_pastille(p, Vector2(8.9 * k + 1.0, -2.1), 1.1, 1.0, P.IVOIRE.lightened(0.2))
	p.aplat(morceau, chair, Pinceau.DOME, Vector2(0.0, -0.4), Vector2(8.2, 4.6) * k)
	p.contour(morceau, 1.1, ENCRE, r, 3)
	# le gras, en liseré ; les fibres
	p.tracer(PackedVector2Array([Vector2(-6.2, 0.0) * k, Vector2(-4.4, -2.2) * k, Vector2(-0.8, -3.3) * k]), 0.9, Color(P.IVOIRE, 0.85))
	for y in [1.0, 2.3]:
		p.tracer(PackedVector2Array([Vector2(-4.0 * k, float(y)), Vector2(0.5, float(y) + 0.5), Vector2(4.6 * k, float(y) - 0.2)]), 0.5, Color(ENCRE, 0.45))
	# les feuilles écrasées : leur jus sombre, leurs lambeaux verts
	_pastille(p, Vector2(-0.8 * k, -0.9), 3.8 * k, 1.9, Color(P.FEUILLE_SOMBRE, 0.8))
	var vert := P.MOUSSE.lightened(0.22)
	for f in [[Vector2(-3.8, -1.3), Vector2(-0.8, -2.6)], [Vector2(-1.8, 0.3), Vector2(1.6, -0.9)], [Vector2(0.6, -2.3), Vector2(3.4, -1.5)]]:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		p.tracer(PackedVector2Array([a * k, b * k]), 1.8, vert.darkened(0.12 * r.randf()))
	if n < 7:
		# (ce qu'une dent y a pris)
		_pastille(p, Vector2(-6.4 * k, 1.5), 1.6, 1.3, P.SANG.darkened(0.4))
	# la mouche : posée dessus, ses deux ailes
	var mo := Vector2(3.6 * k, -3.9)
	p.tracer(PackedVector2Array([mo, mo + Vector2(-1.7, -1.3)]), 1.1, Color(P.PAPIER, 0.8))
	p.tracer(PackedVector2Array([mo, mo + Vector2(1.6, -1.4)]), 1.1, Color(P.PAPIER, 0.8))
	_pastille(p, mo, 0.95, 0.8, ENCRE)
	if _neige_cran() > 0.3:
		_pastille(p, Vector2(-5.0, -1.8), 2.0, 0.8, Color(NEIGE, 0.9))


# --- la popote, sur le feu : une marmite de ferraille noircie, posée sur trois pierres ; son bouillon frémit, sa vapeur monte ---

# dessinée à l'origine de ci (le pied du feu), d'un seul appel ; t : le temps qui passe
static func popote(ci: CanvasItem, t: float) -> void:
	var p = pinceau()
	p.commencer(ci.get_canvas_item())
	var gris := Color(0.45, 0.44, 0.42)
	var fer := Color("2f2f35")
	# les trois pierres : celle du fond d'abord, la marmite, puis les deux de devant
	var pierres := [Vector2(0.5, -10.5), Vector2(-10.0, -4.4), Vector2(10.2, -4.0)]
	for k in 3:
		if k == 1:
			# la marmite : un ventre noirci, que le feu rougit par-dessous
			var ventre := PackedVector2Array([Vector2(-8.4, -19.5), Vector2(-9.8, -15.4), Vector2(-8.2, -11.4), Vector2(-4.4, -9.6), Vector2(4.4, -9.6), Vector2(8.2, -11.4),
				Vector2(9.8, -15.4), Vector2(8.4, -19.5)])
			p.aplat(ventre, fer)
			p.aplat(PackedVector2Array([Vector2(-8.4, -19.5), Vector2(-9.8, -15.4), Vector2(-8.2, -11.4), Vector2(-6.0, -11.6), Vector2(-7.2, -15.4), Vector2(-6.0, -19.5)]), METAL_CLAIR.darkened(0.2))
			p.aplat(PackedVector2Array([Vector2(-8.2, -11.4), Vector2(-4.4, -9.6), Vector2(4.4, -9.6), Vector2(8.2, -11.4), Vector2(4.6, -11.2), Vector2(-4.6, -11.2)]),
				P.BRAISE_ROUGE.lerp(fer, 0.35 + 0.1 * sin(t * 7.0)))
			for q in [Vector2(3.0, -14.6), Vector2(5.6, -16.6), Vector2(1.0, -12.6)]:
				p.disque(q, 1.3, 0.9, ROUILLE.darkened(0.15))
			var tour := PackedVector2Array([Vector2(-8.4, -19.5), Vector2(-9.8, -15.4), Vector2(-8.2, -11.4), Vector2(-4.4, -9.6), Vector2(4.4, -9.6), Vector2(8.2, -11.4),
				Vector2(9.8, -15.4), Vector2(8.4, -19.5)])
			p.tracer(tour, 1.3, ENCRE, false)
			# le bouillon, dans son cercle de fer : il frémit, des bulles y crèvent
			var haut := Vector2(0.0, -19.5)
			p.disque(haut, 9.0, 3.5, ENCRE)
			p.disque(haut, 8.2, 2.9, METAL_CLAIR.darkened(0.3))
			p.disque(haut + Vector2(0.0, 0.3), 7.0, 2.2, Color("a8703a"))
			p.disque(haut + Vector2(-1.6 + sin(t * 0.9) * 0.8, 0.0), 3.6, 0.9, Color("c48a4c"))
			for i in 4:
				var u := fposmod(t * (0.8 + 0.17 * i) + i * 0.29, 1.0)
				var n: float = floorf(t * (0.8 + 0.17 * i) + i * 0.29)
				var q := haut + Vector2((fposmod(n * 0.618 + i * 0.21, 1.0) - 0.5) * 10.0, 0.3 + (fposmod(n * 0.37 + i * 0.5, 1.0) - 0.5) * 2.4)
				if u < 0.75:
					p.disque(q, 0.5 + 1.0 * u, 0.4 + 0.7 * u, Color("e2b36c"))
				else:
					var rond := Pinceau.ellipse(q, 1.6 + 1.6 * (u - 0.75) * 4.0, 0.9 + 0.5 * (u - 0.75) * 4.0, 8)
					rond.append(rond[0])
					p.tracer(rond, 0.5, Color(Color("e2b36c"), 1.0 - (u - 0.75) * 4.0), false)
			# la cuiller de bois, laissée dedans ; l'anse de fil de fer
			p.tracer(PackedVector2Array([Vector2(3.4, -19.4), Vector2(11.2, -25.6)]), 2.5, ENCRE, false)
			p.tracer(PackedVector2Array([Vector2(3.4, -19.4), Vector2(11.2, -25.6)]), 1.4, BOIS_CLAIR.darkened(0.1), false)
			var anse := _courbe(Vector2(-8.6, -19.6), Vector2(-1.0, -33.0), Vector2(8.6, -19.6), 10)
			p.tracer(anse, 1.5, ENCRE, false)
			p.tracer(anse, 0.6, METAL_CLAIR, false)
		var q: Vector2 = pierres[k]
		var cote := -1.0 if k == 1 else 1.0
		var bloc := PackedVector2Array([q + Vector2(-4.0, -3.6), q + Vector2(-0.6, -5.2), q + Vector2(3.4, -4.0), q + Vector2(4.4, 1.6), q + Vector2(2.0, 4.2), q + Vector2(-3.4, 3.8),
			q + Vector2(-4.6, 0.4)])
		p.aplat(bloc, gris)
		p.aplat(PackedVector2Array([q + Vector2(-4.0, -3.6), q + Vector2(-0.6, -5.2), q + Vector2(3.4, -4.0), q + Vector2(0.6, -1.8), q + Vector2(-2.8, -1.4)]), gris.lightened(0.24))
		# (la face tournée vers le feu rougeoie)
		p.aplat(PackedVector2Array([q + Vector2(cote * -0.6, -1.6), q + Vector2(cote * 4.4, -0.2), q + Vector2(cote * 2.4, 4.0), q + Vector2(cote * -0.4, 3.9)]) if k > 0 else
			PackedVector2Array([q + Vector2(-2.8, -1.4), q + Vector2(0.6, -1.8), q + Vector2(2.0, 4.2), q + Vector2(-3.4, 3.8)]), gris.darkened(0.3).lerp(P.BRAISE_ROUGE, 0.3))
		bloc.append(bloc[0])
		p.tracer(bloc, 1.2, ENCRE, false)
	# la vapeur : trois volutes pâles, qui montent en se tordant et s'effacent
	for i in 3:
		var u := fposmod(t * 0.33 + i * 0.37, 1.0)
		var x0 := -3.6 + i * 3.4
		var volute := PackedVector2Array()
		for k in 7:
			var y := -22.0 - 20.0 * u - k * 2.3
			volute.append(Vector2(x0 + sin(t * 1.5 + k * 0.85 + i * 2.1) * (0.8 + 0.4 * k) * (0.5 + u), y))
		p.tracer(volute, 1.8, Color(P.PAPIER, 0.42 * sin(PI * u)))
	p.finir()


# --- les calques ---

# ce qui remue, ce qui brille : un nœud à part, qui se dessine par sa chose
class Calque extends Node2D:
	var hote
	var quoi := ""
	var rang := 0               # (un rang de plantes du carré : lequel)

	func _draw() -> void:
		if hote != null and is_instance_valid(hote):
			hote._peindre(self, quoi)
