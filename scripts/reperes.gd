extends RefCounted
# Lisière — la carte, et ce qu'on y écrit (scripts/reperes.gd)
# La carte se fabrique à l'établi (scripts/atelier.gd : une peau, une corde). Sans elle, le carnet n'en montre pas ; avec
# elle, la pause montre ce qu'on a parcouru (scripts/interface_carte_monde.gd) : dans le monde ouvert, les régions où l'on
# est entrée (principal.gd, decouvertes) ; dans un lieu, les cases où l'on est passée (vus). La veilleuse s'en souvient
# même sans carte : la carte faite, tout ce qu'elle a parcouru y est.
# La plume et l'encre (une fibre, deux baies, une pierre) y écrivent des repères, là où elle se tient : son camp, une
# tanière, un coffre, un vestige, de l'eau, une grotte, une cueillette, un danger. Un repère du même genre tout près est
# récrit, pas doublé ; un repère se raye, d'où qu'on soit. La tanière de la Noire, quand elle la trouve (ou qu'un philtre la
# lui montre), elle l'écrit d'elle-même, si elle a de quoi ; la Noire peut en changer : le repère, lui, reste où il était.

const Pistage := preload("res://scripts/pistage.gd")
const P := preload("res://scripts/palette.gd")

const GENRES := {
	"camp": {"nom": "Campement", "dit": "Ton camp : ton feu, ta tente, ton établi. Là où revenir avant la nuit."},
	"taniere": {"nom": "Tanière", "dit": "Là où dort ce qu'on ne réveille pas."},
	"coffre": {"nom": "Coffre", "dit": "Un coffre, sous la mousse : ce qu'une autre veilleuse gardait."},
	"vestige": {"nom": "Vestige", "dit": "Le camp abandonné d'une autre veilleuse."},
	"eau": {"nom": "Eau", "dit": "Une rive, un gué, de quoi remplir sa gourde."},
	"grotte": {"nom": "Grotte", "dit": "Une bouche dans la roche. Dedans, il fait noir."},
	"cueillette": {"nom": "Cueillette", "dit": "Des baies, des herbes : de quoi cueillir."},
	"danger": {"nom": "Danger", "dit": "Un endroit où ne pas retourner."},
}
const ORDRE := ["camp", "taniere", "coffre", "vestige", "eau", "grotte", "cueillette", "danger"]
const MAX := 48                  # ce que tient une carte
const PRES := 220.0              # un repère du même genre plus près que ça : récrit là où elle est, pas doublé
const CASE := 300.0              # un lieu : le côté d'une case de la carte
const VUE := 480.0               # ce qu'elle voit autour d'elle, qui s'y dessine
const PAS := 40.0                # pixels : un pas, pour dire à combien est un repère
const ROUGE := Color("a8321f")
const GRIS := Color(0.75, 0.7, 0.66)
const TEINTE := Color(0.86, 0.8, 0.66)

var jeu
var liste: Array = []            # ses repères : [{ genre, x, y }], dans l'ordre où elle les a écrits
var vus := {}                    # un lieu : les cases qu'elle a parcourues (Vector2i → vrai)
var _t := 0.0


func _atelier():
	return jeu.atelier


func a_une_carte() -> bool:
	return jeu != null and jeu.get("atelier") != null and int(_atelier().possede("carte")) > 0


# ce qui l'empêche d'écrire ("" : rien)
func empeche_ecrire() -> String:
	if not a_une_carte():
		return "Il te faut une carte : elle se fait à l'établi."
	if int(_atelier().possede("plume")) <= 0:
		return "Il te faut la plume et l'encre : elles se font à l'établi."
	return ""


# elle écrit ce repère sur sa carte, là où elle se tient ; faux si elle ne peut pas (et le jeu dit pourquoi)
func ecrire(genre: String) -> bool:
	if not GENRES.has(genre):
		return false
	var pourquoi := empeche_ecrire()
	if pourquoi != "":
		jeu.ui.message(pourquoi, GRIS)
		return false
	var ici: Vector2 = jeu.joueur.position
	var i := _meme(genre, ici, PRES)
	if i < 0 and liste.size() >= MAX:
		jeu.ui.message("Ta carte est pleine : raye un repère.", GRIS)
		return false
	_noter(genre, ici, i)
	jeu.sons.atelier("couture", -6.0, 1.7)
	jeu.ui.message("%s : %s sur ta carte." % [str(GENRES[genre]["nom"]), "récrit" if i >= 0 else "écrit"], TEINTE)
	return true


# un repère de ce genre près de là (son rang ; -1 : aucun)
func _meme(genre: String, p: Vector2, portee: float) -> int:
	var mieux := -1
	var d0 := portee
	for i in liste.size():
		var r: Dictionary = liste[i]
		var d := p.distance_to(position(r))
		if str(r["genre"]) == genre and d < d0:
			d0 = d
			mieux = i
	return mieux


func _noter(genre: String, p: Vector2, i: int) -> void:
	var r := {"genre": genre, "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1)}
	if i >= 0:
		liste[i] = r
	else:
		liste.append(r)


# elle raye un repère ; faux s'il n'y en a pas
func rayer(i: int) -> bool:
	if i < 0 or i >= liste.size():
		return false
	var nom := str(GENRES.get(str(liste[i]["genre"]), {}).get("nom", "Un repère"))
	liste.remove_at(i)
	jeu.sons.atelier("couture", -8.0, 1.3)
	jeu.ui.message("%s : rayé de ta carte." % nom, TEINTE)
	return true


# la tanière de la Noire : trouvée (ou montrée par un philtre), elle l'écrit d'elle-même, si elle a de quoi. Rend vrai si
# c'est écrit.
func noter_taniere(p: Vector2) -> bool:
	if empeche_ecrire() != "":
		return false
	var i := _meme("taniere", p, PRES * 2.0)
	if i < 0 and liste.size() >= MAX:
		return false
	_noter("taniere", p, i)
	return true


static func position(r: Dictionary) -> Vector2:
	return Vector2(float(r.get("x", 0.0)), float(r.get("y", 0.0)))


# ce qu'il y a là où elle est, qu'elle voudrait sans doute écrire ("" : rien de particulier)
func ici() -> String:
	var p: Vector2 = jeu.joueur.position
	var A = _atelier()
	var proche := ""
	var d0 := 200.0
	for s in A.poses:
		if not is_instance_valid(s):
			continue
		var g := str(s.genre)
		var d: float = s.position.distance_to(p)
		var quoi := "coffre" if g == "coffre" else ("vestige" if g == "vestige" else ("camp" if g in ["etabli", "tente", "hamac"] else ""))
		if quoi != "" and d < d0:
			d0 = d
			proche = quoi
	if proche == "coffre" or proche == "vestige":
		return proche
	var N = jeu.get("noire")
	if N != null and Vector2(N.taniere) != Vector2.ZERO and p.distance_to(N.taniere) < 420.0 and bool(N.taniere_connue):
		return "taniere"
	if proche == "camp":
		return proche
	for f in jeu.feux:
		if is_instance_valid(f) and f.position.distance_to(p) < 220.0:
			return "camp"
	var C = jeu.get("carte")
	if C != null:
		var k: int = C.region_en(p)
		if k >= 0 and bool(C.regions[k].get("grotte", false)):
			return "grotte"
		if float(C.lit(p)) > 0.0:
			return "eau"
	if jeu.get("climat") != null and float(jeu.climat.eau(p)) > 0.2:
		return "eau"
	return ""


# où est ce repère, depuis elle, en mots : « à 120 pas, vers le nord-est » ; « ici »
func dire_ou(r: Dictionary) -> String:
	var d: Vector2 = position(r) - jeu.joueur.position
	var pas := int(round(d.length() / PAS))
	if pas < 3:
		return "ici"
	return "à %d pas, vers %s" % [pas, Pistage.cap(d.angle())]


# ses repères, du plus proche au plus loin : leurs rangs
func par_distance() -> Array:
	var ici_: Vector2 = jeu.joueur.position
	var rangs := range(liste.size())
	rangs.sort_custom(func(a, b): return position(liste[a]).distance_squared_to(ici_) < position(liste[b]).distance_squared_to(ici_))
	return rangs


# --- chaque image : dans un lieu, les cases qu'elle parcourt se notent ---

func maj(delta: float) -> void:
	if jeu == null or jeu.joueur == null or jeu.get("carte") != null:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	voir(jeu.joueur.position)


# ce qu'elle voit d'ici se note (un lieu)
func voir(p: Vector2) -> void:
	var c := cle(p)
	var n := int(ceil(VUE / CASE))
	for dx in range(-n, n + 1):
		for dy in range(-n, n + 1):
			var k := c + Vector2i(dx, dy)
			if not vus.has(k) and ((Vector2(k) + Vector2(0.5, 0.5)) * CASE).distance_to(p) < VUE + CASE * 0.5:
				vus[k] = true


static func cle(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CASE)), int(floor(p.y / CASE)))


# --- la partie ---

func vider() -> void:
	liste = []
	vus = {}
	_t = 0.0


func photo() -> Dictionary:
	var v := []
	for k in vus:
		v.append([k.x, k.y])
	return {"liste": liste.duplicate(true), "vus": v}


func reprendre(d: Dictionary) -> void:
	vider()
	for r in d.get("liste", []):
		if typeof(r) == TYPE_DICTIONARY and GENRES.has(str(r.get("genre", ""))):
			liste.append({"genre": str(r["genre"]), "x": float(r.get("x", 0.0)), "y": float(r.get("y", 0.0))})
	for k in d.get("vus", []):
		if typeof(k) == TYPE_ARRAY and k.size() == 2:
			vus[Vector2i(int(k[0]), int(k[1]))] = true


# --- le dessin d'un repère, à l'encre : sur la carte du carnet, et sur les tuiles de la page de la carte ---

# son signe, dans une boîte de « taille » pixels centrée en c (pale : sur une tuile qu'on ne peut pas écrire)
static func signe(ci: CanvasItem, genre: String, c: Vector2, taille: float, pale: bool = false, base: Transform2D = Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(taille, taille) / 100.0, 0.0, c))
	var a := 0.45 if pale else 1.0
	var encre := Color(P.ENCRE, a)
	var papier := Color(P.PAPIER, a)
	var w := 7.0
	match genre:
		"camp":
			# (une tente, sa porte ; un feu devant)
			var tente := PackedVector2Array([Vector2(-34, 26), Vector2(-4, -34), Vector2(26, 26)])
			ci.draw_colored_polygon(tente, Color("cbc6a4", a))
			ci.draw_polyline(_ferme(tente), encre, w, true)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, 26), Vector2(-4, 4), Vector2(4, 26)]), Color(P.ENCRE, 0.8 * a))
			ci.draw_circle(Vector2(34, 22), 9.0, encre)
			ci.draw_circle(Vector2(34, 20), 6.0, Color(P.BRAISE, a))
		"taniere":
			# (une tache d'encre, deux points rouges)
			ci.draw_circle(Vector2.ZERO, 40.0, papier)
			ci.draw_circle(Vector2.ZERO, 33.0, Color(0.05, 0.04, 0.05, a))
			ci.draw_circle(Vector2(-12, -6), 7.0, Color(P.OEIL_NOIRE, a))
			ci.draw_circle(Vector2(12, -6), 7.0, Color(P.OEIL_NOIRE, a))
		"coffre":
			# (un coffre : sa caisse, son couvercle bombé, sa serrure)
			var caisse := PackedVector2Array([Vector2(-36, -6), Vector2(36, -6), Vector2(36, 30), Vector2(-36, 30)])
			ci.draw_colored_polygon(caisse, Color("a07a4c", a))
			ci.draw_polyline(_ferme(caisse), encre, w, true)
			var couvercle := PackedVector2Array([Vector2(-36, -6), Vector2(-30, -26), Vector2(0, -32), Vector2(30, -26), Vector2(36, -6)])
			ci.draw_colored_polygon(couvercle, Color("8a6a48", a))
			ci.draw_polyline(_ferme(couvercle), encre, w, true)
			ci.draw_rect(Rect2(-7, -10, 14, 16), Color("77726a", a))
			ci.draw_rect(Rect2(-7, -10, 14, 16), encre, false, 4.0)
		"vestige":
			# (trois perches qui tiennent encore, une toile déchirée)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -30), Vector2(26, 24), Vector2(4, 10), Vector2(-10, 26)]), Color("aba888", 0.8 * a))
			ci.draw_line(Vector2(-30, 30), Vector2(-4, -34), encre, w, true)
			ci.draw_line(Vector2(30, 30), Vector2(-8, -30), encre, w, true)
			ci.draw_line(Vector2(-4, 32), Vector2(4, -36), encre, w * 0.8, true)
			ci.draw_line(Vector2(-38, 32), Vector2(38, 32), Color(P.ENCRE, 0.6 * a), w * 0.6, true)
		"eau":
			# (deux vagues)
			for y in [-12.0, 12.0]:
				var v := PackedVector2Array()
				for i in 17:
					var x := -38.0 + 76.0 * i / 16.0
					v.append(Vector2(x, y + sin(x / 9.0) * 6.0))
				ci.draw_polyline(v, Color("4a7fad", a), w * 1.2, true)
		"grotte":
			# (un rocher, sa bouche noire)
			var roc := PackedVector2Array([Vector2(-40, 30), Vector2(-32, -10), Vector2(-10, -32), Vector2(16, -30), Vector2(36, -6), Vector2(40, 30)])
			ci.draw_colored_polygon(roc, Color("9d968a", a))
			ci.draw_polyline(_ferme(roc), encre, w, true)
			var bouche := PackedVector2Array()
			for i in 13:
				var t := PI + PI * i / 12.0
				bouche.append(Vector2(cos(t) * 17.0, 30.0 + sin(t) * 30.0))
			ci.draw_colored_polygon(bouche, Color(0.08, 0.07, 0.08, a))
		"cueillette":
			# (une feuille, trois baies)
			var feuille := PackedVector2Array([Vector2(-30, 26), Vector2(-28, -8), Vector2(-6, -30), Vector2(-4, 0)])
			ci.draw_colored_polygon(feuille, Color("5f7d44", a))
			ci.draw_polyline(_ferme(feuille), encre, w * 0.7, true)
			for q in [Vector2(12, 4), Vector2(28, 14), Vector2(14, 24)]:
				ci.draw_circle(q, 11.0, encre)
				ci.draw_circle(q, 8.0, Color(ROUGE, a))
		"danger":
			# (un rond rouge, un trait et un point : on n'y retourne pas)
			ci.draw_circle(Vector2.ZERO, 38.0, Color(ROUGE, a))
			ci.draw_circle(Vector2.ZERO, 30.0, papier)
			ci.draw_line(Vector2(0, -20), Vector2(0, 6), Color(ROUGE, a), 10.0, true)
			ci.draw_circle(Vector2(0, 18), 5.5, Color(ROUGE, a))
	ci.draw_set_transform_matrix(base)


static func _ferme(pts: PackedVector2Array) -> PackedVector2Array:
	var f := pts.duplicate()
	f.append(pts[0])
	return f
