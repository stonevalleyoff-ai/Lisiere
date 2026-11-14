extends RefCounted
# Lisière — un quadrupède, dessiné à l'encre (scripts/bestiaire_quadrupede.gd)
# La bête de profil, tournée vers la droite, d'après le plan de corps de sa lignée (p.corps). Tout ce que dit le plan change le
# dessin : la longueur du corps (long), la hauteur des pattes (haut), le cou, la tête, le museau, les oreilles, la queue, le
# motif (rayures en travers, bande le long du flanc, taches, masque), les organes (cornes, défenses, trompe, antennes, crête,
# collerette, plaques, épines, carapace, ailes repliées, nageoires, massue, panache, aiguillon, mains) ; sa masse dit si elle
# est frêle ou massive (p.robustesse) ; les traits de son phénotype se voient (pattes longues, crocs, moustaches, robe noire).
# Sa façon de vivre fait son allure, pour qu'on sache d'un coup d'œil à qui l'on a affaire :
#  - elle rampe (reptation) : un lézard, bas, les pattes écartées, la queue qui continue le corps, une peau d'écailles ;
#  - elle nage d'abord : une loutre, le corps en fuseau, la queue épaisse, les pattes palmées (ou une tortue, un crocodile) ;
#  - elle court : haute sur jarrets ; un chasseur a le poitrail profond, le ventre levé, la tête basse en avant des épaules ;
#  - elle saute : le dos voûté, la cuisse lourde, un long pied posé à plat ; elle fouit : basse, le museau en pointe, des
#    griffes ; elle grimpe : la queue enroulée, des mains ; elle est lourde : des piliers, le ventre qui pend.
# Son régime fait sa tête (TETES) : le mufle long d'un brouteur, la tête ronde d'un rongeur, le coin d'un loup, la face courte
# d'un félin, le groin d'un sanglier, le museau pointu d'une fouine, d'un fouisseur, le crâne plat d'une loutre, d'un lézard,
# d'un crocodile. Deux familles voisines se mêlent (un museau plus ou moins long, une bête plus ou moins lourde).
# Elle dessine sur la planche p (scripts/bestiaire_planche.gd), dans quatre calques : la queue (elle pivote à sa racine), le
# corps, le dessus (la cuisse et l'épaule qui cachent le haut des pattes proches, une carapace, une aile), la tête et le cou
# (ils pivotent à la base du cou). Les raccords ne montrent pas de coupe : le cou recouvre le poitrail, sans trait en travers.

const Planche := preload("res://scripts/bestiaire_planche.gd")

# Les têtes. Un profil est fait de douze points, dans le sens des aiguilles : la nuque, le sommet du crâne, le front, le
# stop, le chanfrein, le dessus du nez, le bout du nez, la lèvre, le menton, la mâchoire, la gorge, l'angle de la mâchoire.
# Chaque point : [x, ce que le museau lui ajoute, y], en tailles de crâne (x vers le nez, y vers le bas, 0 au milieu du crâne).
# « oeil » : [x, y, rayon] ; « oreille » : où elle s'attache ; « incl » : de combien le nez pique (radians).
const TETES := {
	"brouteur": {"pts": [[-0.50, 0.0, -0.14], [-0.22, 0.0, -0.46], [0.16, 0.0, -0.44], [0.42, 0.10, -0.30], [0.46, 0.55, -0.20], [0.50, 1.0, -0.10],
		[0.57, 1.0, 0.06], [0.50, 1.0, 0.27], [0.34, 0.75, 0.33], [0.10, 0.25, 0.36], [-0.16, 0.0, 0.44], [-0.46, 0.0, 0.24]],
		"oeil": [0.04, -0.13, 0.15], "oreille": [-0.30, -0.36], "incl": 0.38, "tension": 1.0},
	"rongeur": {"pts": [[-0.50, 0.0, -0.08], [-0.20, 0.0, -0.50], [0.22, 0.0, -0.44], [0.44, 0.10, -0.28], [0.48, 0.50, -0.22], [0.52, 0.95, -0.14],
		[0.58, 1.0, -0.02], [0.50, 0.95, 0.18], [0.36, 0.60, 0.32], [0.12, 0.15, 0.44], [-0.16, 0.0, 0.48], [-0.48, 0.0, 0.26]],
		"oeil": [0.08, -0.12, 0.19], "oreille": [-0.26, -0.38], "incl": 0.22, "tension": 1.0},
	"loup": {"pts": [[-0.52, 0.0, -0.18], [-0.26, 0.0, -0.45], [0.12, 0.0, -0.42], [0.38, 0.05, -0.23], [0.44, 0.55, -0.19], [0.50, 1.0, -0.17],
		[0.58, 1.0, -0.05], [0.51, 1.0, 0.13], [0.36, 0.78, 0.25], [0.14, 0.30, 0.34], [-0.14, 0.0, 0.44], [-0.48, 0.0, 0.27]],
		"oeil": [0.18, -0.13, 0.12], "oreille": [-0.30, -0.36], "incl": 0.12, "tension": 0.82},
	"felin": {"pts": [[-0.50, 0.0, -0.10], [-0.20, 0.0, -0.48], [0.20, 0.0, -0.44], [0.42, 0.05, -0.20], [0.47, 0.50, -0.12], [0.52, 0.95, -0.08],
		[0.56, 1.0, 0.02], [0.50, 1.0, 0.20], [0.36, 0.70, 0.34], [0.12, 0.20, 0.42], [-0.16, 0.0, 0.46], [-0.50, 0.0, 0.26]],
		"oeil": [0.16, -0.10, 0.14], "oreille": [-0.24, -0.40], "incl": 0.10, "tension": 0.9},
	"sanglier": {"pts": [[-0.52, 0.0, -0.22], [-0.24, 0.0, -0.46], [0.16, 0.0, -0.38], [0.42, 0.10, -0.24], [0.48, 0.55, -0.20], [0.54, 1.0, -0.20],
		[0.60, 1.0, -0.02], [0.54, 1.0, 0.16], [0.36, 0.72, 0.26], [0.12, 0.25, 0.36], [-0.14, 0.0, 0.44], [-0.48, 0.0, 0.28]],
		"oeil": [0.08, -0.15, 0.10], "oreille": [-0.30, -0.38], "incl": 0.30, "tension": 0.9},
	"fouine": {"pts": [[-0.50, 0.0, -0.12], [-0.20, 0.0, -0.47], [0.20, 0.0, -0.42], [0.42, 0.08, -0.22], [0.46, 0.50, -0.12], [0.50, 1.0, -0.05],
		[0.57, 1.0, 0.03], [0.49, 1.0, 0.13], [0.34, 0.65, 0.24], [0.10, 0.20, 0.38], [-0.16, 0.0, 0.45], [-0.48, 0.0, 0.25]],
		"oeil": [0.12, -0.11, 0.15], "oreille": [-0.26, -0.38], "incl": 0.18, "tension": 0.95},
	"lezard": {"pts": [[-0.52, 0.0, -0.24], [-0.18, 0.0, -0.38], [0.16, 0.0, -0.37], [0.40, 0.10, -0.22], [0.46, 0.52, -0.12], [0.50, 1.0, -0.06],
		[0.57, 1.0, 0.05], [0.50, 1.0, 0.19], [0.36, 0.72, 0.27], [0.10, 0.25, 0.32], [-0.18, 0.0, 0.36], [-0.50, 0.0, 0.20]],
		"oeil": [0.10, -0.12, 0.17], "oreille": [-0.34, -0.10], "incl": 0.0, "tension": 0.95},
	"loutre": {"pts": [[-0.52, 0.0, -0.16], [-0.22, 0.0, -0.41], [0.16, 0.0, -0.38], [0.42, 0.08, -0.26], [0.48, 0.50, -0.21], [0.53, 0.95, -0.15],
		[0.59, 1.0, 0.0], [0.52, 1.0, 0.20], [0.38, 0.72, 0.30], [0.12, 0.22, 0.38], [-0.16, 0.0, 0.42], [-0.50, 0.0, 0.24]],
		"oeil": [0.18, -0.15, 0.12], "oreille": [-0.30, -0.26], "incl": 0.12, "tension": 1.0},
	"croco": {"pts": [[-0.52, 0.0, -0.22], [-0.22, 0.0, -0.34], [0.10, 0.0, -0.40], [0.34, 0.06, -0.16], [0.42, 0.50, -0.08], [0.50, 0.97, -0.13],
		[0.58, 1.0, -0.01], [0.52, 1.0, 0.10], [0.38, 0.75, 0.19], [0.12, 0.28, 0.25], [-0.18, 0.0, 0.34], [-0.50, 0.0, 0.20]],
		"oeil": [0.10, -0.22, 0.12], "oreille": [-0.30, -0.20], "incl": 0.02, "tension": 0.9},
	"fouisseur": {"pts": [[-0.50, 0.0, -0.14], [-0.20, 0.0, -0.44], [0.18, 0.0, -0.38], [0.40, 0.10, -0.22], [0.45, 0.52, -0.12], [0.50, 1.0, -0.06],
		[0.60, 1.03, -0.03], [0.50, 0.98, 0.07], [0.34, 0.62, 0.18], [0.10, 0.20, 0.33], [-0.16, 0.0, 0.42], [-0.48, 0.0, 0.24]],
		"oeil": [0.12, -0.10, 0.11], "oreille": [-0.28, -0.36], "incl": 0.25, "tension": 1.0},
}
# les points du profil, par leur nom
const NUQUE := 0
const SOMMET := 1
const FRONT := 2
const STOP := 3
const CHANFREIN := 4
const NEZ := 5
const BOUT := 6
const LEVRE := 7
const MENTON := 8
const MACHOIRE := 9
const GORGE := 10
const GANACHE := 11

# les organes d'Orvane : où ils vont et sous quelle forme, quand la lignée ne le dit pas
const PLACES := {"cornes": "tete", "defenses": "tete", "crete": "tete", "collerette": "tete", "antennes": "tete", "trompe": "tete", "ailes": "flancs",
	"nageoires": "flancs", "carapace": "dos", "plaques": "dos", "epines": "dos", "massue": "queue", "aiguillon": "queue", "panache": "queue",
	"pinces": "avant", "mains": "avant"}
const FORMES := {"cornes": "recourbees", "defenses": "recourbees", "crete": "lisse", "collerette": "lisse", "antennes": "fines", "trompe": "courte",
	"ailes": "plumes", "nageoires": "courtes", "carapace": "bombee", "plaques": "triangles", "epines": "fines", "massue": "ronde",
	"aiguillon": "droit", "panache": "touffe", "pinces": "fines", "mains": "agiles"}
const NOMBRES := {"cornes": 2, "plaques": 5, "epines": 7}
# la largeur du cou là où il rejoint la tête, au moins (en tailles de crâne)
const COU_A_LA_TETE := 0.7


# tout ce qu'on mesure d'une bête avant de la dessiner (pixels montrés)
class Mesures:
	var u := 1.0
	var e := 1.3
	var L := 60.0
	# ce qu'elle est
	var rob := 0.4
	var rampe := false
	var course := false
	var saut := false
	var grimpe := false
	var fouit := false
	var terrier := false
	var aquatique := false
	var lourd := false
	var tortue := false
	var carn := false
	var omni := false
	var chasseur := false
	var poilu := true
	var prend := false
	var famille := "brouteur"
	var organes: Array = []
	var motif := "uni"
	var oreilles := 0.0
	var queue := 0.3
	var etale := 0.0
	var pied := "coussinet"
	# le corps
	var lt := 0.0
	var th := 0.0
	var hl := 0.0
	var xc := 0.0
	var xa := 0.0
	var xr := 0.0
	var yb := 0.0
	var top := 0.0
	var bot := 0.0
	var pente := 0.0
	var bosse := 0.0
	var creux := 0.0
	var xf := 0.0
	var xh := 0.0
	var yhf := 0.0
	var yhh := 0.0
	var wp := 2.0
	var corps := PackedVector2Array()
	var i_qb := 0
	var i_nh := 0
	var i_nb := 0
	var fondue := false
	# le cou, la tête
	var ang := 0.5
	var nl := 0.0
	var wb := 0.0
	var base := Vector2.ZERO
	var dir := Vector2.RIGHT
	var nrm := Vector2.UP
	var o := Vector2.ZERO
	var hs := 0.0
	var ml := 0.0
	var mu := 0.5
	var incl := 0.0
	var tension := 1.0
	var crane := PackedVector2Array()
	var oeil := Vector3.ZERO
	var oreille := Vector2.ZERO
	var l_oreille := 0.0
	# la queue
	var tl := 0.0
	var racine := Vector2.ZERO
	var ligne := PackedVector2Array()
	var larg := PackedFloat32Array()
	var genre := "fouet"
	# ce qu'elle occupe
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	# le motif de sa robe, en chemins (les mêmes sur le corps, la cuisse, l'épaule, le cou)
	var d_sombre := ""
	var d_clair := ""

	# la pente du dos (un sauteur a la croupe haute, un lézard qui guette le poitrail levé)
	func yy(x: float) -> float:
		return pente * th * (x - xc) / maxf(lt, 0.001)

	func v(x: float, y: float) -> Vector2:
		return Vector2(x, y + yy(x))

	# un point de la tête : x vers le nez, y vers le bas, en tailles de crâne
	func tp(x: float, y: float) -> Vector2:
		return o + (Vector2(x, y) * hs).rotated(incl)

	# un point de son profil
	func cp(i: int) -> Vector2:
		return tp(crane[i].x, crane[i].y)

	func og(type: String, place := "") -> Dictionary:
		for q in organes:
			if q["type"] == type and (place == "" or q["place"] == place):
				return q
		return {}

	func voir(q: Vector2, marge := 0.0) -> void:
		x0 = minf(x0, q.x - marge)
		x1 = maxf(x1, q.x + marge)
		y0 = minf(y0, q.y - marge)


static func dessiner(p) -> void:
	var pl: Planche = p
	_teinter(pl)
	# on la mesure une première fois sans échelle, pour savoir ce qu'elle occupe du nez au bout de la queue ; puis à la largeur
	# de la planche, son milieu au-dessus de l'origine
	var m := _mesurer(pl, 1.0, 0.0, 0.0)
	var u: float = (pl.L * 0.96 - 2.0 * pl.e) / maxf(m.x1 - m.x0, 0.05)
	u = minf(u, (pl.L * 1.04 - pl.e) / maxf(-m.y0, 0.05))
	m = _mesurer(pl, u, -(m.x0 + m.x1) * 0.5 * u, pl.e)
	pl.ombre(m.xc, m.lt * 0.56)
	var sil: PackedVector2Array = pl.vivant(m.corps, pl.e * 0.22)
	_motif(pl, m)
	_queue(pl, m, sil)
	_patte(pl, m, true, true)
	_patte(pl, m, false, true)
	_sur_le_dos(pl, m, sil)
	_corps(pl, m, sil)
	_patte(pl, m, true, false)
	_patte(pl, m, false, false)
	_dessus(pl, m, sil)
	_cou_et_tete(pl, m, sil)


# les traits qui changent la robe : le mélanisme (une robe d'encre), l'albinisme (une robe d'os)
static func _teinter(p: Planche) -> void:
	var T: Dictionary = p.tons
	var robe: Color = T["robe"]
	var dos: Color = T["dos"]
	var ventre: Color = T["ventre"]
	var loin: Color = T["loin"]
	if p.traits.has("melanisme"):
		robe = robe.lerp(dos, 0.6).darkened(0.22)
		dos = dos.darkened(0.3)
		ventre = ventre.lerp(robe, 0.55)
		loin = loin.lerp(robe.darkened(0.3), 0.7)
	elif p.traits.has("albinisme"):
		var os: Color = T["os"]
		robe = robe.lerp(os, 0.62)
		dos = dos.lerp(robe, 0.55)
		ventre = ventre.lerp(os, 0.5)
		loin = loin.lerp(robe.darkened(0.25), 0.7)
	else:
		return
	T["robe"] = robe
	T["dos"] = dos
	T["ventre"] = ventre
	T["loin"] = loin
	T["lumiere"] = Planche.clair(robe)
	T["ombre"] = Planche.sombre(robe)


static func _f(c: Dictionary, k: String, d: float) -> float:
	var x = c.get(k, d)
	if typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT:
		return clampf(float(x), 0.0, 1.0)
	return d


# ses organes : la liste de la lignée ; à défaut, ceux que son corps marque en proportions (à partir de 0,2), comme Orvane
static func _organes(c: Dictionary) -> Array:
	var out := []
	var liste = c.get("organes")
	if typeof(liste) == TYPE_ARRAY:
		for q in liste:
			if typeof(q) != TYPE_DICTIONARY:
				continue
			var t := str(q.get("type", ""))
			if not PLACES.has(t):
				continue
			var place = q.get("place")
			var forme = q.get("forme")
			var nombre = q.get("nombre")
			var taille = q.get("taille")
			out.append({"type": t, "taille": clampf(float(taille), 0.05, 1.0) if typeof(taille) in [TYPE_FLOAT, TYPE_INT] else 0.5,
				"place": place if typeof(place) == TYPE_STRING else PLACES[t], "forme": forme if typeof(forme) == TYPE_STRING else FORMES[t],
				"nombre": int(nombre) if typeof(nombre) in [TYPE_FLOAT, TYPE_INT] else int(NOMBRES.get(t, 1))})
	for t in ["cornes", "crete", "ailes", "carapace", "antennes"]:
		var x := _f(c, t, 0.0)
		if x >= 0.2 and not out.any(func(q): return q["type"] == t):
			out.append({"type": t, "taille": x, "place": PLACES[t], "forme": FORMES[t], "nombre": int(NOMBRES.get(t, 1))})
	return out


# le profil de sa tête : une famille, ou deux qui se mêlent (k de 0 à 1)
static func _profil(m: Mesures, a: String, b: String, k: float) -> void:
	var A: Dictionary = TETES[a]
	var B: Dictionary = TETES[b]
	var pa: Array = A["pts"]
	var pb: Array = B["pts"]
	m.famille = b if k >= 0.5 else a
	m.crane = PackedVector2Array()
	for i in pa.size():
		var x := lerpf(float(pa[i][0]) + float(pa[i][1]) * m.mu, float(pb[i][0]) + float(pb[i][1]) * m.mu, k)
		var y := lerpf(float(pa[i][2]), float(pb[i][2]), k)
		if y > 0.0:
			# (une bête lourde a la mâchoire profonde)
			y *= 1.0 + 0.16 * (m.rob - 0.4)
		m.crane.append(Vector2(x, y))
	var oa: Array = A["oeil"]
	var ob: Array = B["oeil"]
	m.oeil = Vector3(lerpf(oa[0], ob[0], k), lerpf(oa[1], ob[1], k), lerpf(oa[2], ob[2], k))
	var ea: Array = A["oreille"]
	var eb: Array = B["oreille"]
	m.oreille = Vector2(lerpf(ea[0], eb[0], k), lerpf(ea[1], eb[1], k))
	m.incl = lerpf(A["incl"], B["incl"], k)
	m.tension = lerpf(A["tension"], B["tension"], k)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var t := float(i) / (n - 1)
		var s := 1.0 - t
		out.append(a * s * s * s + b * 3.0 * s * s * t + c * 3.0 * s * t * t + d * t * t * t)
	return out


# le chemin ouvert qui suit la courbe fermée Planche.ferme(pts, tension), du point a au point b (en avançant, en boucle) : pour
# ne cerner qu'une partie d'une forme, exactement sur son bord
static func _suite(pts: PackedVector2Array, a: int, b: int, tension := 1.0) -> String:
	var n := pts.size()
	if n < 3:
		return ""
	var combien := posmod(b - a, n)
	if combien == 0:
		combien = n
	var d := "M" + Planche.pt(pts[posmod(a, n)])
	for k in combien:
		var i := posmod(a + k, n)
		var p0 := pts[posmod(i - 1, n)]
		var p1 := pts[i]
		var p2 := pts[posmod(i + 1, n)]
		var p3 := pts[posmod(i + 2, n)]
		d += " C" + Planche.pt(p1 + (p2 - p0) * tension / 6.0) + " " + Planche.pt(p2 - (p3 - p1) * tension / 6.0) + " " + Planche.pt(p2)
	return d


# une forme fermée, peinte comme Planche.volume, mais cernée seulement du point a au point b : là où elle sort d'une autre (un
# cou du poitrail, une queue de la croupe), il n'y a pas de trait en travers
static func _forme(p: Planche, pts: PackedVector2Array, tension: float, a: int, b: int, teinte: Color, dedans := Callable(), k := 1.0) -> void:
	var bord := _suite(pts, a, b, tension)
	var encre := Planche.coul(p.tons["encre"])
	# (l'encre lourde, du côté de l'ombre)
	p.svg("<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" transform=\"translate(%s %s)\"/>" % [bord, encre, Planche.n(p.e * 1.5 * k), Planche.n(p.e * 0.3), Planche.n(p.e * 0.5)])
	p.volume(Planche.ferme(pts, tension), teinte, dedans, {"cerne": 0.0, "lourd": false})
	p.cerne(bord, k)


# des mèches de poil qui débordent d'un contour : n mèches de a à b, longues de « long », tournées vers l'angle « vers »
# (rien sur une bête trop petite pour qu'on les voie)
static func _meches(p: Planche, a: Vector2, b: Vector2, n: int, long: float, vers: float, teinte: Color) -> void:
	if p.L < 56.0 or n <= 0:
		return
	var t := (b - a) / n
	var v := Vector2.from_angle(vers)
	var plein := ""
	var bord := ""
	for i in n:
		var c := a + t * (i + 0.5)
		var l := long * p.r.randf_range(0.7, 1.15)
		var g := Planche.pt(c - t * 0.56)
		var d := Planche.pt(c + t * 0.56)
		var pointe := Planche.pt(c + v * l + t * 0.2)
		plein += "M%s L%s L%s L%sZ" % [g, pointe, d, Planche.pt(c - v * l * 0.6)]
		bord += "M%s L%s L%s" % [g, pointe, d]
	p.aplat(plein, teinte)
	p.tracer(bord, p.e * 0.7, p.tons["encre"])


# --- les mesures ---

static func _mesurer(p: Planche, u: float, dx: float, e: float) -> Mesures:
	var m := Mesures.new()
	var c: Dictionary = p.corps
	var loco: Array = p.locomotion
	var rob: float = p.robustesse
	m.u = u
	m.e = e
	m.L = p.L
	m.rob = rob
	m.organes = _organes(c)
	m.motif = str(c.get("motif", "uni"))
	m.rampe = loco.has("reptation")
	m.course = loco.has("course")
	m.saut = loco.has("saut") and not m.course
	m.grimpe = loco.has("grimpe")
	m.fouit = loco.has("fouissage")
	m.terrier = m.fouit and not m.course
	m.aquatique = not m.rampe and not loco.is_empty() and str(loco[0]) == "nage"
	m.carn = p.regime == "carnivore"
	m.omni = p.regime == "omnivore"
	m.chasseur = p.chasseur
	m.lourd = rob > 0.65 and not m.course and not m.saut and not m.rampe
	m.prend = m.grimpe or p.traits.has("queue-prehensile")
	var long := _f(c, "long", 0.5)
	var haut := _f(c, "haut", 0.3)
	var cou := _f(c, "cou", 0.2)
	var tete := _f(c, "tete", 0.4)
	var museau := _f(c, "museau", 0.4)
	m.oreilles = _f(c, "oreilles", 0.0)
	m.queue = _f(c, "queue", 0.3)
	var posture := _f(c, "posture", 0.0)
	var carap := m.og("carapace")
	m.tortue = m.aquatique and not carap.is_empty() and float(carap["taille"]) >= 0.8

	# --- la tête : sa taille (une petite bête a la tête grosse), son museau (un long museau est forcé), sa famille ---
	# (dans le monde d'Orvane, la tête de plusieurs lignées est tombée à zéro, surtout chez de gros carnivores : dessinée telle
	# quelle, elle se perdait sur leur corps. Elle garde ses écarts d'une lignée à l'autre, mais elle a un plancher : le champ
	# « tete » se lit de 0,3 à 1, un chasseur lourd ne la perd plus avec sa masse, et elle fait au moins les deux tiers de
	# l'épaisseur du corps chez un chasseur, un peu plus de la moitié chez les autres. Un chasseur se lit d'abord à sa tête.)
	var tete_vue := 0.3 + 0.7 * tete
	m.hs = (0.092 + 0.125 * tete_vue) * (1.1 - (0.07 if p.chasseur else 0.16) * rob) * (1.2 if p.chasseur else 1.04) * u
	m.hs = maxf(m.hs, (0.148 + 0.105 * rob + 0.04 * (1.0 - long)) * u * (0.68 if p.chasseur else 0.56))
	m.ml = (0.014 + 0.105 * museau * (1.15 if museau > 0.55 else 1.0)) * u
	if m.aquatique and m.carn and museau >= 0.6 and m.oreilles < 0.12:
		m.ml *= 1.3
	m.mu = m.ml / m.hs
	if m.rampe or m.tortue:
		_profil(m, "lezard", "lezard", 0.0)
	elif m.aquatique and m.carn and museau >= 0.6 and m.oreilles < 0.12:
		_profil(m, "croco", "croco", 0.0)
	elif m.aquatique:
		_profil(m, "loutre", "loutre", 0.0)
	elif m.fouit:
		_profil(m, "fouisseur", "fouisseur", 0.0)
	elif m.carn:
		_profil(m, "felin", "loup", smoothstep(0.42, 0.6, museau))
	elif m.omni:
		_profil(m, "fouine", "sanglier", smoothstep(0.5, 0.75, rob))
	else:
		_profil(m, "rongeur", "brouteur", smoothstep(0.44, 0.6, rob))
	m.poilu = m.famille != "lezard" and m.famille != "croco"
	m.l_oreille = m.hs * (0.28 + 1.05 * m.oreilles * (1.2 if m.oreilles > 0.4 else 1.0))
	if m.famille in ["lezard", "croco", "loutre"]:
		m.l_oreille *= 0.55

	# --- le corps ---
	m.lt = (0.3 + 0.32 * long) * u
	m.th = (0.148 + 0.105 * rob + 0.04 * (1.0 - long)) * u
	m.hl = (0.06 + 0.34 * haut * (1.1 if haut > 0.5 else 1.0)) * u
	if m.terrier:
		m.hl *= 0.7
	if p.traits.has("pattes-longues"):
		m.hl *= 1.2
	m.etale = clampf(1.0 - haut / 0.42, 0.0, 1.0) if m.rampe else 0.0
	m.nl = (0.02 + 0.3 * cou * (1.15 if cou > 0.4 else 1.0)) * u
	m.tl = (0.03 + 0.42 * m.queue) * u
	var bosse := 0.06 + 0.14 * rob        # le garrot
	var ens := 0.0                        # les reins (négatif : le dos se voûte)
	var croupe := 0.06                    # la croupe tombe
	var poitrine := 0.02                  # le poitrail descend
	var creux := 0.04 + 0.08 * rob        # le ventre pend
	var retrousse := 0.06                 # le flanc se lève
	var pente := -0.5 * posture           # (une bête qui se dresse a le poitrail haut)
	if m.rampe:
		bosse = 0.0
		ens = -0.03
		croupe = 0.08
		poitrine = 0.0
		creux = 0.12
		retrousse = 0.02
		if m.saut:
			pente -= 0.16
	elif m.aquatique:
		bosse = 0.03
		ens = -0.05
		croupe = 0.1
		poitrine = 0.0
		creux = 0.07 + 0.06 * rob
		retrousse = 0.02
	elif m.course and (m.carn or m.chasseur):
		bosse *= 1.3
		poitrine = 0.12
		creux = -0.03
		retrousse = 0.26
		ens = 0.02
	elif m.course:
		bosse *= 1.15
		poitrine = 0.06
		creux = 0.03
		retrousse = 0.14
	elif m.saut:
		bosse = 0.02
		ens = -0.14
		croupe = -0.04
		creux = 0.06
		retrousse = 0.0
		pente += 0.2
	elif m.lourd:
		bosse *= 1.2
		creux = 0.16
		retrousse = 0.0
		ens = 0.03
	elif m.terrier:
		bosse = 0.02
		ens = -0.03
		creux = 0.08
	elif m.grimpe:
		bosse = 0.03
		ens = -0.08
	if rob < 0.42 and not m.rampe and not m.aquatique:
		ens -= 0.05
	m.pente = pente
	m.bosse = bosse * m.th
	m.creux = creux * m.th
	m.xc = dx
	m.xa = dx + m.lt * 0.5
	m.xr = dx - m.lt * 0.5
	m.yb = -m.hl - m.th * (0.47 + 0.3 * absf(pente))
	m.top = m.yb - m.th * 0.5
	m.bot = m.yb + m.th * 0.5
	var lt := m.lt
	var th := m.th
	m.xf = m.xa - lt * (0.14 if m.rampe else 0.17)
	m.xh = m.xr + lt * (0.17 if m.rampe else 0.21)
	m.yhf = m.yb + th * 0.1 + m.yy(m.xf)
	m.yhh = m.yb + th * 0.1 + m.yy(m.xh)
	m.wp = maxf(th * (0.3 + 0.16 * rob), e * 1.5)
	if m.course and not m.carn and not m.chasseur:
		m.wp *= 0.86
	if m.rampe:
		m.pied = "main"
	elif m.carn or m.terrier:
		m.pied = "griffes"
	elif m.grimpe:
		m.pied = "main"
	elif m.aquatique or m.saut or rob <= 0.3:
		m.pied = "coussinet"
	else:
		m.pied = "sabot"

	# --- le cou : son angle (un brouteur porte la tête haute, un chasseur basse en avant des épaules), sa base ---
	var a := 0.6 + 0.8 * cou
	if m.rampe:
		a = 0.3 + 0.55 * cou
	elif m.terrier:
		a = 0.12 + 0.4 * cou
	elif m.aquatique:
		a = 0.26 + 0.5 * cou
	elif m.carn or m.chasseur:
		a = 0.1 + 0.45 * cou
	elif m.omni or m.fouit:
		a = 0.38 + 0.6 * cou
	a -= pente * 0.5
	m.ang = a
	m.dir = Vector2(cos(a), -sin(a))
	m.nrm = Vector2(-sin(a), -cos(a))
	var wb := th * (0.6 + 0.2 * rob)
	if m.rampe:
		wb = th * 0.76
	elif m.aquatique:
		wb = th * 0.8
	elif m.carn or m.chasseur:
		wb = th * (0.7 + 0.16 * rob)
	m.wb = clampf(maxf(wb, m.hs * 0.72), th * 0.5, th * 0.92)
	var nh := m.v(m.xa - lt * (0.1 + 0.13 * sin(a)), m.top - th * (bosse * (0.8 + 0.3 * smoothstep(0.4, 0.9, a)) - 0.02))
	var nb := nh - m.nrm * m.wb
	m.base = nh - m.nrm * m.wb * 0.5
	m.o = m.base + m.dir * (m.nl + m.hs * 0.38)
	# (la nuque ne rentre pas dans le dos, la gorge ne rentre pas dans le poitrail)
	var recul := minf((m.cp(NUQUE) - m.base).dot(m.dir) - m.wb * 0.16, (m.cp(GORGE) - m.base).dot(m.dir) - m.wb * 0.2)
	if recul < 0.0:
		m.o -= m.dir * recul

	# --- la silhouette du corps, dans le sens des aiguilles depuis la croupe ---
	m.fondue = (m.rampe or m.aquatique) and m.queue > 0.06
	var wq := th * (0.5 + 0.16 * m.queue)
	if m.tortue:
		wq = th * 0.3
	var pts := PackedVector2Array()
	if m.fondue:
		# (la queue continue le corps : la croupe s'ouvre sur elle, entre ces deux points)
		m.racine = m.v(m.xr + lt * 0.05, m.yb + th * 0.05)
		pts.append(m.racine + Vector2(0.0, -wq * 0.5))
		pts.append(m.v(m.xr + lt * 0.2, m.top + th * croupe))
	else:
		m.racine = m.v(m.xr + th * 0.18, m.yb - th * 0.2)
		pts.append(m.v(m.xr + lt * 0.03, m.yb - th * 0.28))
		pts.append(m.v(m.xr + lt * 0.14, m.top + th * croupe))
	pts.append(m.v(m.xr + lt * 0.34, m.top + th * ens))
	pts.append(m.v(m.xc + lt * 0.06, m.top + th * (ens * 0.4 - bosse * 0.35)))
	pts.append(m.v(m.xa - lt * 0.3, m.top - th * bosse))
	m.i_nh = pts.size()
	pts.append(nh)
	pts.append(m.base + m.dir * m.wb * 0.3)
	m.i_nb = pts.size()
	pts.append(nb)
	var bas_avant := m.bot + m.yy(m.xa)
	if nb.y < bas_avant - th * 0.4:
		pts.append(Vector2(lerpf(nb.x, m.xa, 0.5) - lt * 0.02, lerpf(nb.y, bas_avant, 0.55)))
	pts.append(m.v(minf(nb.x, m.xa) - lt * 0.1, m.bot - th * 0.05))
	pts.append(m.v(m.xa - lt * 0.27, m.bot + th * poitrine))
	pts.append(m.v(m.xc - lt * 0.04, m.bot + th * creux))
	pts.append(m.v(m.xr + lt * 0.29, m.bot - th * retrousse))
	if m.fondue:
		pts.append(m.v(m.xr + lt * 0.17, m.bot - th * 0.05))
		m.i_qb = pts.size()
		pts.append(m.racine + Vector2(0.0, wq * 0.5))
		pts.append(m.racine + Vector2(-lt * 0.03, 0.0))
	else:
		pts.append(m.v(m.xr + lt * 0.13, m.bot - th * (retrousse * 0.5 + 0.05)))
		m.i_qb = pts.size()
		pts.append(m.v(m.xr + lt * 0.02, m.yb + th * 0.24))
		pts.append(m.v(m.xr - lt * 0.01, m.yb - th * 0.03))
	m.corps = pts
	for q in pts:
		m.voir(q, e)

	# --- la queue : son port, son genre, ses points de la racine au bout, sa largeur à chacun ---
	var tl := m.tl * (1.1 if m.fondue else 1.0)
	var R := m.racine
	var ligne := PackedVector2Array()
	var aig := m.og("aiguillon")
	var w0 := th * (0.18 + 0.2 * rob)
	m.genre = "fouet"
	if m.fondue:
		m.genre = "fondue"
		w0 = wq
	elif m.queue < 0.28:
		m.genre = "courte"
		w0 = th * (0.2 + 0.16 * rob)
	elif m.poilu and (m.carn or m.omni) and not m.terrier and not m.prend and m.queue >= 0.35:
		m.genre = "touffue"
		w0 = th * (0.2 + 0.12 * rob)
	elif not m.carn and not m.omni and rob >= 0.5 and not m.prend:
		m.genre = "toupet"
		w0 = th * (0.14 + 0.1 * rob)
	elif rob < 0.45 and not m.prend and not m.carn:
		m.genre = "rat"
		w0 = maxf(th * 0.17, e * 1.6)
	elif m.prend:
		w0 = th * (0.2 + 0.14 * rob)
	if m.queue > 0.06:
		if not aig.is_empty() and aig["forme"] == "courbe":
			# (la queue recourbée au-dessus du dos)
			ligne = _bezier(R, R + Vector2(-0.55, -0.25) * tl, R + Vector2(-0.4, -1.0) * tl, R + Vector2(0.15, -0.95) * tl, 10)
		elif m.prend and m.fondue:
			# (elle part droit, puis s'enroule vers le bas : un caméléon)
			var s0 := R + Vector2(-0.34, 0.03) * tl
			var r0 := 0.22 * tl
			ligne.append(R)
			ligne.append(R.lerp(s0, 0.5) + Vector2(0.0, -0.012 * tl))
			for i in 11:
				var s := i / 10.0
				var an := PI * 0.5 + s * TAU * 1.08
				ligne.append(s0 + Vector2(0.0, r0) + Vector2(cos(an), -sin(an)) * r0 * (1.0 - 0.8 * pow(s, 0.85)))
		elif m.prend:
			# (elle monte, puis s'enroule)
			var cq := R + Vector2(-0.3, 0.3) * tl
			for i in 13:
				var s := i / 12.0
				var an := PI * 0.25 + s * TAU * 1.12
				ligne.append(cq + Vector2(cos(an), -sin(an)) * 0.4243 * tl * (1.0 - 0.82 * pow(s, 0.85)))
		elif m.rampe and (m.course or m.saut):
			# (un balancier, tenu au-dessus du sol)
			ligne = _bezier(R, R + Vector2(-0.35, 0.03) * tl, R + Vector2(-0.7, 0.12) * tl, R + Vector2(-1.0, -0.08) * tl, 9)
		elif m.rampe:
			# (elle traîne, le bout relevé)
			ligne = _bezier(R, R + Vector2(-0.32 * tl, 0.0), Vector2(R.x - 0.6 * tl, -th * 0.1), Vector2(R.x - tl, -th * 0.24), 9)
		elif m.aquatique:
			ligne = _bezier(R, R + Vector2(-0.35 * tl, 0.03 * tl), Vector2(R.x - 0.65 * tl, R.y * 0.3), Vector2(R.x - tl, R.y * 0.36), 9)
		elif m.genre == "courte":
			if m.carn or m.lourd:
				ligne = _bezier(R, R + Vector2(-0.4, 0.0) * tl, R + Vector2(-0.75, 0.2) * tl, R + Vector2(-0.95, 0.5) * tl, 7)
			else:
				# (un petit plumet dressé)
				ligne = _bezier(R, R + Vector2(-0.45, -0.2) * tl, R + Vector2(-0.8, -0.55) * tl, R + Vector2(-0.85, -1.0) * tl, 7)
		elif m.course and (m.carn or m.chasseur):
			# (basse, le bout qui remonte : un loup)
			ligne = _bezier(R, R + Vector2(-0.3, 0.04) * tl, R + Vector2(-0.62, 0.44) * tl, R + Vector2(-0.98, 0.3) * tl, 9)
		elif m.lourd or (m.genre == "toupet" and not m.saut):
			# (elle pend)
			ligne = _bezier(R, R + Vector2(-0.32, -0.02) * tl, R + Vector2(-0.44, 0.45) * tl, R + Vector2(-0.4, 0.95) * tl, 9)
		elif m.saut:
			# (un balancier : basse, puis le bout relevé)
			ligne = _bezier(R, R + Vector2(-0.4, 0.14) * tl, R + Vector2(-0.8, 0.02) * tl, R + Vector2(-0.95, -0.42) * tl, 9)
		elif m.course:
			ligne = _bezier(R, R + Vector2(-0.35, -0.2) * tl, R + Vector2(-0.72, -0.06) * tl, R + Vector2(-0.88, 0.36) * tl, 9)
		else:
			ligne = _bezier(R, R + Vector2(-0.4, -0.24) * tl, R + Vector2(-0.78, -0.14) * tl, R + Vector2(-0.96, 0.1) * tl, 9)
		# (elle ne passe pas sous le sol)
		var plus_bas := R.y
		for q in ligne:
			plus_bas = maxf(plus_bas, q.y)
		var sol := -maxf(w0 * 0.2, 0.012 * u) - 0.012 * u
		if plus_bas > sol and plus_bas > R.y + 0.001:
			var k := maxf(0.0, (sol - R.y) / (plus_bas - R.y))
			for i in ligne.size():
				ligne[i] = Vector2(ligne[i].x, R.y + (ligne[i].y - R.y) * k)
		if m.fondue:
			# (un point de plus, caché dans le corps)
			ligne.insert(0, R + Vector2(lt * 0.1, 0.0))
		var n := ligne.size()
		var premier := 1 if m.fondue else 0
		for i in n:
			var s := clampf(float(i - premier) / (n - 1 - premier), 0.0, 1.0)
			var w := lerpf(w0, maxf(e * 0.9, w0 * 0.25), pow(s, 0.8))
			match m.genre:
				"fondue":
					w = w0 * (0.94 * pow(1.0 - s, 0.85) + 0.06) + e * 0.4
				"touffue":
					w = w0 * (0.8 + 0.85 * sin(PI * pow(s, 0.7))) * (1.0 - 0.8 * pow(s, 4.0))
				"courte":
					w = w0 * (0.8 + 0.5 * sin(PI * s)) * (1.0 - 0.7 * pow(s, 3.0))
			m.larg.append(w)
			m.voir(ligne[i], w * 0.6)
		m.ligne = ligne
		# (ce qu'elle porte au bout)
		var bout := ligne[n - 1]
		var massue := m.og("massue")
		if not massue.is_empty():
			m.voir(bout, th * (0.2 + 0.3 * float(massue["taille"])) * 1.6)
		var panache := m.og("panache")
		if not panache.is_empty():
			m.voir(bout, th * (0.5 + 0.9 * float(panache["taille"])))
		if not aig.is_empty():
			m.voir(bout, th * (0.4 + 0.7 * float(aig["taille"])))
		if not m.og("epines", "queue").is_empty():
			m.voir(bout, th * 0.6)

	# --- ce que la tête occupe : le profil, les oreilles, les organes ---
	for i in m.crane.size():
		m.voir(m.cp(i), e)
	if m.oreilles > 0.12:
		m.voir(m.tp(m.oreille.x - 0.3 * m.l_oreille / m.hs, m.oreille.y - m.l_oreille / m.hs))
		m.voir(m.tp(m.oreille.x, m.oreille.y - m.l_oreille / m.hs))
	var cornes := m.og("cornes")
	if not cornes.is_empty():
		var lc := 0.5 + float(cornes["taille"])
		match str(cornes["forme"]):
			"ramifiees":
				m.voir(m.tp(-0.45 * lc, -0.42 - 1.3 * lc), e)
				m.voir(m.tp(0.3 * lc, -0.42 - 1.2 * lc), e)
			"droites":
				m.voir(m.tp(0.35 * lc, -0.42 - 1.1 * lc), e)
			_:
				m.voir(m.tp(0.2, -0.42 - 1.0 * lc), e)
				m.voir(m.tp(-0.95 * lc, -0.42 - 0.5 * lc), e)
		if int(cornes["nombre"]) == 1 or int(cornes["nombre"]) == 3:
			m.voir(m.tp(m.crane[NEZ].x, m.crane[NEZ].y - 0.9 * lc), e)
	var crete := m.og("crete", "tete")
	if not crete.is_empty():
		m.voir(m.tp(-0.1, -0.42 - (0.4 + 0.9 * float(crete["taille"]))), e)
	var col := m.og("collerette")
	if not col.is_empty():
		var r := 0.75 + 0.8 * float(col["taille"])
		m.voir(m.tp(-0.35, -r), e)
		m.voir(m.tp(-0.35 - r * 0.5, 0.0), e)
	var ant := m.og("antennes")
	if not ant.is_empty():
		var la := 1.0 + 1.6 * float(ant["taille"])
		m.voir(m.tp(0.15 + la * 0.6, -0.4 - la * 0.75), e)
	var defenses := m.og("defenses")
	if not defenses.is_empty():
		m.voir(m.cp(BOUT) + Vector2(m.hs * 0.7 * (0.5 + float(defenses["taille"])), 0.0), e)
	var trompe := m.og("trompe")
	if not trompe.is_empty():
		m.voir(m.cp(BOUT) + Vector2(m.hs * 0.5, 0.0), e)
	# (ce que le dos porte)
	var haut_dos := 0.0
	var cd := m.og("crete", "dos")
	if not cd.is_empty():
		haut_dos = maxf(haut_dos, th * (0.3 + 0.9 * float(cd["taille"])))
	var pl := m.og("plaques")
	if not pl.is_empty():
		haut_dos = maxf(haut_dos, th * (0.25 + 0.5 * float(pl["taille"])))
	var ep := m.og("epines", "dos")
	if not ep.is_empty():
		haut_dos = maxf(haut_dos, th * (0.25 + 0.45 * float(ep["taille"])))
	var na := m.og("nageoires", "dos")
	if not na.is_empty():
		haut_dos = maxf(haut_dos, th * (0.4 + 0.8 * float(na["taille"])))
	if not carap.is_empty():
		haut_dos = maxf(haut_dos, th * (0.08 + 0.3 * float(carap["taille"])))
	if haut_dos > 0.0:
		m.voir(Vector2(m.xc, m.top - m.bosse - haut_dos - absf(pente) * th * 0.5))
	return m


# --- le motif de la robe : des chemins, dans le repère du corps, qu'on peint découpés au corps, à la cuisse, à l'épaule, au cou ---

static func _motif(p: Planche, m: Mesures) -> void:
	var lt := m.lt
	var th := m.th
	# (jusqu'où va le cou)
	var x_fin := maxf(m.xa, m.o.x - m.hs * 0.3)
	match m.motif:
		"rayures":
			# des rayures en travers, effilées, qui descendent de l'échine
			var combien := clampi(int(round((x_fin - m.xr) / maxf(th * 0.34, 3.0))), 5, 12)
			var d := ""
			for i in combien:
				var x := lerpf(m.xr + lt * 0.03, x_fin, (i + 0.5) / combien) + p.r.randf_range(-0.012, 0.012) * lt
				var w := maxf(th * 0.13, 1.3) * p.r.randf_range(0.8, 1.2)
				var y0 := m.top - th * 0.8 + m.yy(x)
				var y1 := m.top + th * (0.78 if i % 2 == 0 else 0.5) * p.r.randf_range(0.85, 1.1) + m.yy(x)
				if x > m.xa - lt * 0.12:
					# (sur le cou : elles s'arrêtent à son milieu)
					y1 = minf(y1, m.base.y - (x - m.base.x) * tan(m.ang) + m.wb * 0.15)
				var penche := th * 0.14
				d += "M%s L%s Q%s %s Q%s %sZ" % [Planche.pt(Vector2(x - w * 0.5, y0)), Planche.pt(Vector2(x + w * 0.5, y0)),
					Planche.pt(Vector2(x + w * 0.5 + penche * 0.2, lerpf(y0, y1, 0.6))), Planche.pt(Vector2(x + penche, y1)),
					Planche.pt(Vector2(x - w * 0.5 + penche * 0.1, lerpf(y0, y1, 0.6))), Planche.pt(Vector2(x - w * 0.5, y0))]
			m.d_sombre = d
		"taches":
			# des taches en quinconce, plus grosses vers l'échine ; des ocelles sur un grand chasseur
			var colonnes := clampi(int((x_fin - m.xr) / maxf(th * 0.32, 3.2)), 4, 12)
			var ocelles: bool = m.carn and p.L >= 70.0
			var d2 := ""
			for j in 3:
				for i in colonnes:
					if p.r.randf() < 0.12:
						continue
					var x := lerpf(m.xr + lt * 0.04, x_fin, (i + 0.5 + 0.5 * (j % 2)) / colonnes) + p.r.randf_range(-0.02, 0.02) * lt
					var y := m.top + th * (0.16 + 0.22 * j + p.r.randf_range(-0.04, 0.04)) + m.yy(x)
					if x > m.xa - lt * 0.1:
						y = minf(y, m.base.y - (x - m.base.x) * tan(m.ang) - m.wb * (0.3 - 0.28 * j))
					var r := maxf(th * (0.1 - 0.02 * j) * p.r.randf_range(0.8, 1.2), 0.9)
					var rond := Planche.ellipse(Vector2(x, y), r * 1.15, r * 0.9, 7, p.r.randf() * TAU)
					d2 += Planche.ferme(p.vivant(rond, r * 0.12), 1.0)
					if ocelles and j < 2:
						var trou := Planche.ellipse(Vector2(x, y), r * 0.5, r * 0.4, 6)
						trou.reverse()
						d2 += Planche.ferme(trou, 1.0)
			m.d_sombre = d2
		"bandes":
			# une bande sombre le long du flanc, de l'épaule à la hanche, soulignée de clair
			var y := m.yb - th * 0.14
			var ligne := PackedVector2Array([m.v(m.xr - lt * 0.04, y + th * 0.08), m.v(m.xr + lt * 0.25, y - th * 0.02), m.v(m.xc, y),
				m.v(m.xa - lt * 0.22, y - th * 0.02), m.base + m.dir * m.wb * 0.2, m.o - Vector2(m.hs * 0.2, 0.0).rotated(m.incl)])
			var larg := PackedFloat32Array([th * 0.1, th * 0.2, th * 0.22, th * 0.2, th * 0.16, m.hs * 0.12])
			m.d_sombre = _ruban(ligne, larg, 0.9)
			var dessous := PackedVector2Array()
			for q in ligne:
				dessous.append(q + Vector2(0.0, th * 0.17))
			m.d_clair = _ruban(dessous, PackedFloat32Array([th * 0.04, th * 0.09, th * 0.1, th * 0.09, th * 0.07, m.hs * 0.05]), 0.9)
	if p.traits.has("camouflage") and m.d_sombre == "":
		# (une robe qui se fond : de grandes plaques douces)
		var d3 := ""
		for i in 5:
			var q := Vector2(lerpf(m.xr + lt * 0.1, m.xa - lt * 0.05, (i + 0.5) / 5.0), m.yb + th * p.r.randf_range(-0.3, 0.1))
			d3 += Planche.ferme(p.vivant(Planche.ellipse(q, lt * 0.09, th * 0.2, 7, p.r.randf() * TAU), th * 0.06), 1.0)
		m.d_sombre = d3


# le motif, peint là où l'on est (découpé par la forme qu'on remplit)
static func _peindre_motif(p: Planche, m: Mesures) -> void:
	if m.d_sombre != "":
		if p.traits.has("camouflage") and m.motif == "uni":
			p.aplat(m.d_sombre, p.tons["dos"], 0.4)
		else:
			var sombre: Color = p.tons["dos"]
			p.aplat(m.d_sombre, sombre.lerp(p.tons["encre"], 0.3), 0.8)
	if m.d_clair != "":
		p.aplat(m.d_clair, p.tons["ventre"], 0.75)


# les deux bords d'un ruban dont la largeur est donnée à chaque point : [le bord du dessus en allant, le bord du dessous]
static func _bords(ligne: PackedVector2Array, larg: PackedFloat32Array) -> Array:
	var n := ligne.size()
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in n:
		var t := (ligne[mini(i + 1, n - 1)] - ligne[maxi(i - 1, 0)]).normalized()
		var o := Vector2(t.y, -t.x)
		var w: float = larg[mini(i, larg.size() - 1)] * 0.5
		haut.append(ligne[i] + o * w)
		bas.append(ligne[i] - o * w)
	return [haut, bas]


# un ruban fermé, d'une largeur donnée à chaque point
static func _ruban(ligne: PackedVector2Array, larg: PackedFloat32Array, tension := 0.9) -> String:
	var b := _bords(ligne, larg)
	var bas: PackedVector2Array = b[1]
	bas.reverse()
	var tour: PackedVector2Array = b[0]
	tour.append_array(bas)
	return Planche.ferme(tour, tension)


# --- la queue (derrière le corps) ---

static func _queue(p: Planche, m: Mesures, sil: PackedVector2Array) -> void:
	var n := m.ligne.size()
	if m.queue <= 0.06 or n < 3:
		return
	var T: Dictionary = p.tons
	var ligne := m.ligne
	var e: float = p.e
	p.calque("queue")
	p.pivot("queue", m.racine)
	# ses deux bords : celui du dessus (le dos de la queue), celui du dessous
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in n:
		var t := (ligne[mini(i + 1, n - 1)] - ligne[maxi(i - 1, 0)]).normalized()
		var o := Vector2(-t.y, t.x)
		if t.x > 0.0 and not m.prend and m.og("aiguillon").is_empty():
			o = -o
		var w: float = m.larg[i] * 0.5
		var kh := 1.0
		var kb := 1.0
		if m.genre == "touffue" and i > 0 and i < n - 1:
			# (le poil : un bord en dents)
			kb = 1.1 if i % 2 == 0 else 0.94
		haut.append(ligne[i] + o * w * kh)
		bas.append(ligne[i] - o * w * kb)
	if m.fondue:
		haut[1] = sil[0]
		bas[1] = sil[m.i_qb]
	var tour := haut.duplicate()
	var retour := bas.duplicate()
	retour.reverse()
	tour.append_array(retour)
	tour = p.vivant(tour, e * 0.12)
	var tension := 0.8 if m.genre == "touffue" else 0.9
	var dedans := func():
		# (le dessus plus sombre, le dessous plus pâle)
		var dessus := haut.duplicate()
		var milieu := ligne.duplicate()
		milieu.reverse()
		dessus.append_array(milieu)
		p.aplat(Planche.ferme(dessus, 0.9), T["dos"], 0.42)
		if m.fondue:
			var dessous := bas.duplicate()
			for i in range(n - 1, -1, -1):
				dessous.append(ligne[i].lerp(bas[i], 0.45))
			p.aplat(Planche.ferme(dessous, 0.9), T["ventre"], 0.8)
		match m.motif:
			"rayures":
				# (des anneaux)
				var d := ""
				for i in range(2, n - 1, 2):
					var t := (ligne[i + 1] - ligne[i]) * 0.42
					d += "M%s L%s L%s L%sZ" % [Planche.pt(haut[i].lerp(ligne[i], -0.3)), Planche.pt(bas[i].lerp(ligne[i], -0.3)),
						Planche.pt(bas[i].lerp(ligne[i], -0.3) + t), Planche.pt(haut[i].lerp(ligne[i], -0.3) + t)]
				p.aplat(d, T["dos"], 0.75)
			"bandes":
				var fil := PackedVector2Array()
				for i in n:
					fil.append(ligne[i].lerp(haut[i], 0.25))
				p.aplat(Planche.ruban(fil, m.larg[0] * 0.34, e * 0.5), T["dos"], 0.7)
			"taches":
				var d2 := ""
				for i in range(1, n - 1):
					var q := ligne[i].lerp(haut[i] if i % 2 == 0 else bas[i], 0.35)
					d2 += Planche.ferme(Planche.ellipse(q, m.larg[i] * 0.2, m.larg[i] * 0.16, 6), 1.0)
				p.aplat(d2, T["dos"], 0.7)
			"masque":
				# (le bout sombre)
				var j := int(n * 0.68)
				var bout := haut.slice(j)
				var b2 := bas.slice(j)
				b2.reverse()
				bout.append_array(b2)
				p.aplat(Planche.poly(bout), T["dos"], 0.8)
		if m.genre == "touffue" and m.motif != "masque":
			# (le bout pâle d'un panache de renard)
			var j2 := int(n * 0.76)
			var bout2 := haut.slice(j2)
			var b3 := bas.slice(j2)
			b3.reverse()
			bout2.append_array(b3)
			p.aplat(Planche.poly(bout2), T["ventre"], 0.85)
		if m.genre == "touffue":
			p.poils(ligne.slice(1, n - 1), m.larg[n / 2] * 0.3, 2.6, 2.8, 0.5)
	if m.fondue:
		_forme(p, tour, tension, 1, 2 * n - 2, T["robe"], dedans)
	elif m.genre == "rat":
		# (une queue nue, pâle)
		var nue: Color = T["robe"]
		p.volume(Planche.ferme(tour, tension), nue.lerp(T["ventre"], 0.5), Callable(), {"plat": true})
	else:
		p.volume(Planche.ferme(tour, tension), T["robe"], dedans)
	if m.famille == "croco" or (m.rampe and p.L >= 50.0 and m.rob > 0.3):
		# (des écailles dressées le long du dessus)
		var d3 := ""
		for i in range(2, n - 2):
			var q := haut[i]
			var t := (haut[i + 1] - haut[i - 1]).normalized()
			var hh: float = maxf(m.larg[i] * 0.22, e * 1.1)
			d3 += "M%s L%s L%s" % [Planche.pt(q - t * hh * 0.7), Planche.pt(q + Vector2(-t.y, t.x) * -hh - t * hh * 0.2), Planche.pt(q + t * hh * 0.5)]
		if m.famille == "croco":
			p.svg("<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [d3, Planche.coul(T["dos"]), Planche.coul(T["encre"]), Planche.n(e * 0.7)])
	_bout_de_queue(p, m, haut, bas)


# ce que la queue porte au bout : un toupet, une massue, un aiguillon, un panache, des épines
static func _bout_de_queue(p: Planche, m: Mesures, haut: PackedVector2Array, bas: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var n := m.ligne.size()
	var bout := m.ligne[n - 1]
	var t := (bout - m.ligne[n - 2]).normalized()
	var o := Vector2(-t.y, t.x)
	var th := m.th
	if m.genre == "toupet":
		# (un toupet de crin, sombre)
		var l := maxf(th * 0.34, e * 3.0)
		var d := PackedVector2Array([bout - t * l * 0.5 + o * l * 0.14, bout + t * l * 0.25 + o * l * 0.3, bout + t * l * 1.0 + o * l * 0.05,
			bout + t * l * 0.7 - o * l * 0.12, bout + t * l * 0.95 - o * l * 0.3, bout + t * l * 0.2 - o * l * 0.32, bout - t * l * 0.5 - o * l * 0.14])
		p.volume(Planche.ferme(d, 0.6), T["dos"], Callable(), {"lourd": false, "cerne": 0.85})
	var epines := m.og("epines", "queue")
	if not epines.is_empty():
		var le := th * (0.35 + 0.5 * float(epines["taille"]))
		for k in [-1.0, 0.0, 1.0]:
			var pied: Vector2 = bout - t * th * 0.14 * (1.0 + k)
			var pointe: Vector2 = pied + (o * 1.0 - t * 0.3 * k).normalized() * le
			p.volume(Planche.ruban(PackedVector2Array([pied, pied.lerp(pointe, 0.5), pointe]), maxf(e * 1.5, le * 0.2), e * 0.5), T["os"], Callable(), {"lourd": false, "cerne": 0.75})
	var massue := m.og("massue")
	if not massue.is_empty():
		var r := th * (0.2 + 0.3 * float(massue["taille"]))
		var c := bout + t * r * 0.6
		if massue["forme"] == "cloutee":
			for i in 6:
				var a := i * TAU / 6.0 + 0.3
				var v := Vector2(cos(a), sin(a))
				p.volume(Planche.ruban(PackedVector2Array([c + v * r * 0.7, c + v * r * 1.2, c + v * r * 1.7]), maxf(e * 1.6, r * 0.34), e * 0.5), T["os"], Callable(), {"lourd": false, "cerne": 0.75})
		p.volume(Planche.ferme(p.vivant(Planche.ellipse(c, r * 1.15, r, 9, t.angle()), e * 0.15), 1.0), T["dos"], func():
			p.aplat(Planche.ferme(Planche.ellipse(c + Vector2(-r * 0.3, -r * 0.35), r * 0.5, r * 0.3, 6), 1.0), T["lumiere"], 0.35)
			p.hachures(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(r * 0.7, r * 0.5), 4, r * 0.4, 1.2))
	var aig := m.og("aiguillon")
	if not aig.is_empty():
		var la := th * (0.4 + 0.7 * float(aig["taille"]))
		var fin := bout + t * la
		var coude := bout + t * la * 0.5
		if aig["forme"] == "courbe":
			fin = bout + t * la * 0.45 + Vector2(0.0, la * 0.7)
			coude = bout + t * la * 0.6 + Vector2(0.0, la * 0.1)
		p.volume(Planche.ferme(Planche.ellipse(bout + t * la * 0.1, la * 0.26, la * 0.2, 8, t.angle()), 1.0), T["accent"], Callable(), {"lourd": false})
		p.volume(Planche.ruban(PackedVector2Array([bout + t * la * 0.2, coude, fin]), maxf(e * 1.8, la * 0.2), e * 0.4), T["encre"].lerp(T["accent"], 0.35), Callable(), {"lourd": false, "cerne": 0.7})
	var panache := m.og("panache")
	if not panache.is_empty():
		var lp := th * (0.5 + 0.9 * float(panache["taille"]))
		if panache["forme"] == "eventail":
			# (un éventail de longues plumes, ouvert vers le haut)
			var brins := 6
			for i in brins:
				var a := lerpf(-1.25, 0.75, float(i) / (brins - 1))
				var v := (t * cos(a) + o * -sin(a)).normalized()
				if v.y > 0.2:
					v = Vector2(v.x, 0.2).normalized()
				var long := lp * (1.0 if i % 2 == 0 else 0.82)
				var plume := PackedVector2Array([bout - t * lp * 0.1, bout + v * long * 0.5 + v.orthogonal() * long * 0.13, bout + v * long,
					bout + v * long * 0.5 - v.orthogonal() * long * 0.13])
				p.volume(Planche.ferme(plume, 0.8), T["accent"] if i % 2 == 0 else T["dos"], func():
					p.aplat(Planche.ferme(Planche.ellipse(bout + v * long * 0.8, long * 0.14, long * 0.1, 6), 1.0), T["ventre"], 0.8),
					{"lourd": i == brins - 1, "cerne": 0.8})
		else:
			# (une touffe en goutte)
			var goutte := PackedVector2Array([bout - t * lp * 0.15 + o * lp * 0.12, bout + t * lp * 0.35 + o * lp * 0.36, bout + t * lp * 1.05,
				bout + t * lp * 0.35 - o * lp * 0.36, bout - t * lp * 0.15 - o * lp * 0.12])
			p.volume(Planche.ferme(goutte, 0.8), T["accent"], func():
				p.hachures(bout - o * lp * 0.2, bout + t * lp * 0.7, 4, lp * 0.25, t.angle()))


# --- ce que le dos porte, derrière le corps (leur pied s'y cache) : une crête, des plaques, des épines, une nageoire ---

# un point de la ligne du dos, de la croupe (s = 0) à la base du cou (s = 1)
static func _dos(m: Mesures, sil: PackedVector2Array, s: float) -> Vector2:
	var x := lerpf(sil[0].x, sil[m.i_nh].x, s)
	for i in m.i_nh:
		if x <= sil[i + 1].x or i == m.i_nh - 1:
			var k := clampf((x - sil[i].x) / maxf(sil[i + 1].x - sil[i].x, 0.01), 0.0, 1.0)
			return sil[i].lerp(sil[i + 1], k)
	return sil[m.i_nh]


static func _sur_le_dos(p: Planche, m: Mesures, sil: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var th := m.th
	var fond := Vector2(0.0, th * 0.12)
	p.calque("corps")
	var crete := m.og("crete", "dos")
	if not crete.is_empty():
		var h := th * (0.3 + 0.9 * float(crete["taille"]))
		if crete["forme"] == "dentelee":
			# (une rangée de piquants, plus hauts aux épaules)
			var dents := 8
			var pts := PackedVector2Array([_dos(m, sil, 0.1) + fond])
			for i in dents:
				var s := lerpf(0.12, 0.92, (i + 0.5) / dents)
				var hh := h * (0.5 + 0.5 * sin(PI * pow(s, 0.8)))
				pts.append(_dos(m, sil, s - 0.045) + Vector2(-hh * 0.2, -hh))
				pts.append(_dos(m, sil, s + 0.03) + Vector2(0.0, -hh * 0.12))
			pts.append(_dos(m, sil, 0.94) + fond)
			p.volume(Planche.poly(p.vivant(pts, e * 0.12)), T["accent"], Callable(), {"lourd": false, "cerne": 0.85})
		else:
			# (une voile tendue sur des rayons)
			var pts2 := PackedVector2Array([_dos(m, sil, 0.1) + fond])
			var rayons := ""
			for i in 7:
				var s := lerpf(0.14, 0.9, i / 6.0)
				var hh := h * (0.35 + 0.65 * sin(PI * lerpf(0.12, 0.95, i / 6.0)))
				var pied := _dos(m, sil, s)
				pts2.append(pied + Vector2(-hh * 0.12, -hh))
				rayons += "M%s L%s" % [Planche.pt(pied), Planche.pt(pied + Vector2(-hh * 0.12, -hh * 0.92))]
			pts2.append(_dos(m, sil, 0.94) + fond)
			p.volume(Planche.ferme(p.vivant(pts2, e * 0.12), 0.7), T["accent"], func():
				p.tracer(rayons, e * 0.5, T["encre"], 0.6), {"lourd": false, "cerne": 0.85})
	var plaques := m.og("plaques")
	if not plaques.is_empty():
		var combien := clampi(int(plaques["nombre"]), 3, 9)
		var h2 := th * (0.25 + 0.5 * float(plaques["taille"]))
		for i in combien:
			var s := 0.12 + 0.76 * (i + 0.5) / combien
			var hh := h2 * (0.6 + 0.4 * sin(PI * (i + 0.5) / combien))
			var pied := _dos(m, sil, s) + fond
			var w := maxf(m.lt * 0.5 / combien, e * 2.4)
			var pts3: PackedVector2Array
			if plaques["forme"] == "rondes":
				pts3 = PackedVector2Array([pied + Vector2(-w * 0.5, 0.0), pied + Vector2(-w * 0.62, -hh * 0.75), pied + Vector2(0.0, -hh * 1.12),
					pied + Vector2(w * 0.62, -hh * 0.75), pied + Vector2(w * 0.5, 0.0)])
			else:
				pts3 = PackedVector2Array([pied + Vector2(-w * 0.55, 0.0), pied + Vector2(-w * 0.3, -hh * 0.6), pied + Vector2(-w * 0.05, -hh * 1.15),
					pied + Vector2(w * 0.3, -hh * 0.55), pied + Vector2(w * 0.55, 0.0)])
			p.volume(Planche.ferme(pts3, 0.8 if plaques["forme"] == "rondes" else 0.45), T["accent"], func():
				p.tracer("M%s L%s" % [Planche.pt(pied + Vector2(0.0, -hh * 0.2)), Planche.pt(pied + Vector2(0.0, -hh * 0.85))], e * 0.45, T["encre"], 0.45),
				{"lourd": false, "cerne": 0.85})
	var epines := m.og("epines", "dos")
	if not epines.is_empty():
		var combien2 := clampi(int(epines["nombre"]), 4, 12)
		var l := th * (0.3 + 0.5 * float(epines["taille"]))
		var gros: bool = epines["forme"] == "massives"
		for i in combien2:
			var s := 0.1 + 0.8 * (i + 0.5) / combien2
			var pied := _dos(m, sil, s) + fond
			var pointe := pied + Vector2(-l * 0.4, -l - fond.y) * (0.75 + 0.25 * sin(PI * s))
			p.volume(Planche.ruban(PackedVector2Array([pied, pied.lerp(pointe, 0.5), pointe]), maxf(e * (2.4 if gros else 1.5), l * (0.3 if gros else 0.16)), e * 0.4),
				T["os"], Callable(), {"lourd": false, "cerne": 0.7})
	var nageoire := m.og("nageoires", "dos")
	if not nageoire.is_empty():
		var h3 := th * (0.4 + 0.8 * float(nageoire["taille"]))
		var a := _dos(m, sil, 0.3) + fond
		var b := _dos(m, sil, 0.68) + fond
		var pts4 := PackedVector2Array([a, a.lerp(b, 0.3) + Vector2(-h3 * 0.1, -h3 * 0.7), a.lerp(b, 0.42) + Vector2(-h3 * 0.3, -h3), b + Vector2(0.0, -h3 * 0.15), b])
		p.volume(Planche.ferme(pts4, 0.7), T["dos"], func():
			p.hachures(a.lerp(b, 0.4) + Vector2(0.0, -h3 * 0.6), b + Vector2(0.0, -h3 * 0.2), 4, h3 * 0.4, 1.9), {"lourd": false, "cerne": 0.85})


# --- les pattes ---

# les articulations d'une patte, de la hanche (de l'épaule) au pied posé, et sa largeur à chacune. Elle garde assez de pli pour
# que le pied reste au sol quand la bête allonge le pas.
static func _patte_pts(m: Mesures, devant: bool, loin: bool) -> Array:
	var x := (m.xf if devant else m.xh) + (m.lt * 0.06 if loin else 0.0)
	var yh := m.yhf if devant else m.yhh
	var h := -yh
	var w := m.wp
	var pts: PackedVector2Array
	var larg: Array
	if m.rampe:
		# un lézard : la cuisse part de côté, le genou haut, d'autant plus que la bête est basse
		var lc := maxf(h * 0.62, m.th * 0.4)
		var gros := 1.0
		if m.saut and not devant:
			lc *= 1.3
			gros = 1.5
		var phi := lerpf(1.25, 0.1, m.etale)
		var genou := Vector2(x + (-1.0 if devant else 1.0) * cos(phi) * lc, minf(yh + sin(phi) * lc, -h * 0.32))
		var pied := Vector2(genou.x + (h * 0.3 + lc * 0.25 if devant else -h * 0.2 - lc * 0.05), 0.0)
		pts = PackedVector2Array([Vector2(x, yh), genou, pied])
		larg = [w * 1.1 * gros, w * 0.8, w * 0.6]
	elif m.saut and not devant:
		# un sauteur : la cuisse lourde, le genou haut devant, un long pied posé à plat
		pts = PackedVector2Array([Vector2(x + h * 0.06, yh), Vector2(x + h * 0.44, yh + h * 0.52), Vector2(x - h * 0.16, -h * 0.1), Vector2(x + h * 0.26, 0.0)])
		larg = [minf(w * 1.9, m.lt * 0.4), w * 0.95, w * 0.52, w * 0.48]
	elif m.saut:
		pts = PackedVector2Array([Vector2(x + h * 0.04, yh), Vector2(x - h * 0.16, yh + h * 0.45), Vector2(x + h * 0.06, 0.0)])
		larg = [w * 0.8, w * 0.55, w * 0.45]
	elif m.course and m.pied == "sabot":
		# un coureur à sabots : le canon long et fin
		if devant:
			pts = PackedVector2Array([Vector2(x + h * 0.04, yh), Vector2(x - h * 0.09, yh + h * 0.34), Vector2(x + h * 0.02, -h * 0.34), Vector2(x, 0.0)])
			larg = [w * 1.05, w * 0.68, w * 0.42, w * 0.38]
		else:
			pts = PackedVector2Array([Vector2(x, yh), Vector2(x + h * 0.13, yh + h * 0.33), Vector2(x - h * 0.12, -h * 0.4), Vector2(x - h * 0.05, 0.0)])
			larg = [w * 1.55, w * 0.85, w * 0.44, w * 0.38]
	elif m.course:
		# un coureur sur ses doigts : le jarret haut
		if devant:
			pts = PackedVector2Array([Vector2(x + h * 0.05, yh), Vector2(x - h * 0.1, yh + h * 0.36), Vector2(x + h * 0.02, -h * 0.24), Vector2(x, 0.0)])
			larg = [w * 1.15, w * 0.8, w * 0.52, w * 0.48]
		else:
			pts = PackedVector2Array([Vector2(x, yh), Vector2(x + h * 0.16, yh + h * 0.36), Vector2(x - h * 0.2, -h * 0.3), Vector2(x - h * 0.1, 0.0)])
			larg = [w * 1.6, w * 0.92, w * 0.52, w * 0.48]
	elif m.lourd:
		# un lourd : des piliers, à peine pliés
		if devant:
			pts = PackedVector2Array([Vector2(x + h * 0.07, yh), Vector2(x - h * 0.12, yh + h * 0.42), Vector2(x, 0.0)])
			larg = [w * 1.25, w * 1.05, w * 0.95]
		else:
			pts = PackedVector2Array([Vector2(x - h * 0.02, yh), Vector2(x + h * 0.16, yh + h * 0.44), Vector2(x, 0.0)])
			larg = [w * 1.45, w * 1.1, w * 0.95]
	elif m.terrier:
		# un fouisseur : court, fort, la main en avant
		if devant:
			pts = PackedVector2Array([Vector2(x, yh), Vector2(x - h * 0.26, yh + h * 0.5), Vector2(x + h * 0.3, 0.0)])
			larg = [w * 1.2, w * 0.92, w * 0.78]
		else:
			pts = PackedVector2Array([Vector2(x, yh), Vector2(x + h * 0.3, yh + h * 0.5), Vector2(x + h * 0.02, 0.0)])
			larg = [w * 1.2, w * 0.82, w * 0.64]
	else:
		if devant:
			pts = PackedVector2Array([Vector2(x + h * 0.05, yh), Vector2(x - h * 0.11, yh + h * 0.4), Vector2(x + h * 0.03, 0.0)])
			larg = [w, w * 0.72, w * 0.54]
		else:
			pts = PackedVector2Array([Vector2(x, yh), Vector2(x + h * 0.18, yh + h * 0.42), Vector2(x - h * 0.14, -h * 0.16), Vector2(x - h * 0.02, 0.0)])
			larg = [w * 1.3, w * 0.8, w * 0.52, w * 0.5]
	for i in larg.size():
		larg[i] = maxf(float(larg[i]), 1.5 if loin else 1.9)
	return [pts, larg]


static func _patte(p: Planche, m: Mesures, devant: bool, loin: bool) -> void:
	var q := _patte_pts(m, devant, loin)
	var pied := m.pied
	var taille := 1.25
	if devant and not m.og("mains").is_empty():
		pied = "main"
	match pied:
		"sabot":
			taille = 1.15
		"griffes":
			taille = 1.5 if (m.terrier and devant) else 1.3
		"main":
			taille = 1.5
		"coussinet":
			taille = 1.6 if m.aquatique else 1.25
	if m.lourd:
		taille = 0.62
	p.patte(q[0], q[1], loin, {"pied": pied, "pied_taille": taille, "poilu": m.poilu and not devant})


# --- le corps ---

static func _corps(p: Planche, m: Mesures, sil: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var th := m.th
	var lt := m.lt
	p.calque("corps")
	var haut := sil.slice(0, m.i_nh + 1)
	var bas := sil.slice(m.i_nb, m.i_qb + 1)
	var dedans := func():
		# le dos, plus sombre : une bande qui suit l'échine, au bord inégal (le poil), puis l'échine elle-même
		for passe in 2:
			var k := (0.36 if m.carn else 0.3) if passe == 0 else 0.13
			# (elle s'amincit vers la base du cou : le cou, qui recouvre le poitrail, porte sa propre nuque sombre)
			var dernier := haut.size() - 1
			var bande := PackedVector2Array([Vector2(m.xr - lt * 0.3, m.top - th * 1.5), Vector2(haut[dernier].x + th * 0.2, m.top - th * 1.5),
				haut[dernier] + Vector2(th * 0.2, th * k * 0.1)])
			for i in range(dernier, -1, -1):
				var kk := k * (0.3 if i == dernier else 1.0)
				bande.append(haut[i] + Vector2(0.0, th * (kk + (0.035 if i % 2 == 0 else -0.035) * (1.0 if m.poilu else 0.0))))
			bande.append(Vector2(m.xr - lt * 0.3, haut[0].y + th * k))
			p.aplat(Planche.ferme(bande, 0.7), T["dos"], 0.42 if passe == 0 else 0.3)
		# le ventre, plus pâle
		var dessous := PackedVector2Array()
		if m.fondue:
			dessous.append(Vector2(m.xr - lt * 0.3, m.bot + th))
			dessous.append(Vector2(m.xr - lt * 0.3, bas[bas.size() - 1].y - th * 0.16))
			for i in range(bas.size() - 1, -1, -1):
				dessous.append(bas[i] + Vector2(0.0, -th * 0.3))
			dessous.append(Vector2(m.xa + lt * 0.4, bas[0].y - th * 0.3))
			dessous.append(Vector2(m.xa + lt * 0.4, m.bot + th))
		else:
			dessous.append(Vector2(bas[bas.size() - 1].x, m.bot + th))
			for i in range(bas.size() - 1, -1, -1):
				var s := float(i) / (bas.size() - 1)
				dessous.append(bas[i] + Vector2(0.0, -th * 0.3 * pow(sin(PI * clampf(s, 0.04, 0.96)), 0.6)))
			dessous.append(Vector2(bas[0].x, m.bot + th))
		p.aplat(Planche.ferme(dessous, 0.8), T["ventre"], 0.85)
		_peindre_motif(p, m)
		# l'ombre sous le ventre, le creux du flanc devant la cuisse
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(m.xc, m.bot + m.creux + th * 0.1), lt * 0.52, th * 0.17, 10), 1.0), T["encre"], 0.2)
		if p.L >= 50.0:
			p.aplat(Planche.ferme(Planche.ellipse(Vector2(m.xh + m.wp * 1.25, m.yhh + th * 0.02), m.wp * 0.5, th * 0.3, 7, 0.2), 1.0), T["encre"], 0.12)
		# un filet de lumière sous l'échine
		if p.L >= 50.0:
			var filet := PackedVector2Array()
			for i in range(1, haut.size() - 1):
				filet.append(haut[i] + Vector2(-e * 0.4, e * 1.5))
			p.tracer(Planche.ouvert(filet), e * 0.8, T["lumiere"], 0.5)
		if m.poilu:
			# le poil de l'échine, le pli du flanc
			var echine := PackedVector2Array()
			for i in range(1, haut.size()):
				echine.append(haut[i] + Vector2(0.0, th * 0.1))
			p.poils(echine, th * 0.15, 2.3, 3.4, 0.5)
			p.hachures(Vector2(m.xh + m.wp * 0.6, m.yhh - th * 0.2), Vector2(m.xh + m.wp * 1.5, m.yhh + th * 0.25), 3, th * 0.2, 1.9, 0.45)
			p.hachures(Vector2(m.xf - m.wp * 1.5, m.yhf - th * 0.1), Vector2(m.xf - m.wp * 0.9, m.yhf + th * 0.3), 3, th * 0.18, 1.4, 0.4)
		else:
			_ecailles(p, m, haut)
	if m.fondue:
		_forme(p, sil, 1.0, 0, m.i_qb, T["robe"], dedans)
	else:
		p.volume(Planche.ferme(sil, 1.0), T["robe"], dedans)
	if m.poilu and (m.carn or m.chasseur) and m.og("carapace").is_empty() and m.og("crete", "dos").is_empty():
		# (le poil hérissé du garrot : un chasseur)
		var g := sil[m.i_nh - 1]
		_meches(p, g + Vector2(-lt * 0.1, th * 0.03), g.lerp(sil[m.i_nh], 0.7) + Vector2(0.0, th * 0.02), 4, th * 0.16, -2.5, T["robe"].lerp(T["dos"], 0.55))
		if bool(p.plan.get("noire", false)):
			# (la Noire : l'échine hérissée de la croupe à la nuque, de longues mèches d'encre, plus hautes au garrot)
			for k in 6:
				var s0 := 0.08 + 0.15 * k
				var a0 := _dos(m, sil, s0)
				var a1 := _dos(m, sil, s0 + 0.15)
				_meches(p, a0 + Vector2(0.0, th * 0.03), a1 + Vector2(0.0, th * 0.03), 3, th * lerpf(0.14, 0.34, pow(s0 + 0.08, 1.4)), -2.3, T["dos"])


# des écailles : de petits arcs, en deux rangs sous l'échine (rien sur une petite bête)
static func _ecailles(p: Planche, m: Mesures, haut: PackedVector2Array) -> void:
	if p.L < 48.0:
		return
	var d := ""
	var pas := maxf(m.th * 0.24, 2.6)
	for rang in 2:
		var x := haut[0].x + pas * (1.0 + 0.5 * rang)
		while x < haut[haut.size() - 1].x - pas:
			var y := m.top + m.yy(x) + m.th * (0.2 + 0.2 * rang) + p.r.randf_range(-0.3, 0.3)
			d += "M%s q%s %s %s 0" % [Planche.pt(Vector2(x, y)), Planche.n(pas * 0.22), Planche.n(-pas * 0.3), Planche.n(pas * 0.44)]
			x += pas * p.r.randf_range(0.85, 1.2)
	p.tracer(d, maxf(0.45, p.e * 0.4), p.tons["encre"], 0.4)


# --- ce qui passe devant les pattes proches : la cuisse, l'épaule, une carapace, une aile, une nageoire ---

static func _dessus(p: Planche, m: Mesures, sil: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	p.calque("dessus")
	for devant in [false, true]:
		var q := _patte_pts(m, devant, false)
		var pts: PackedVector2Array = q[0]
		var w0: float = q[1][0]
		var hanche := pts[0]
		var d := (pts[1] - pts[0]).normalized()
		var r := w0 * 0.5 + e * 0.9
		# (le haut de la patte se fond dans le corps : un rond de la robe, modelé, sans cerne)
		var rond := Planche.ellipse(hanche - d * w0 * 0.08, r * 1.04, r * 1.08, 10, d.angle())
		p.volume(Planche.ferme(rond, 1.0), T["robe"], func():
			_peindre_motif(p, m), {"cerne": 0.0, "lourd": false})
		# (le muscle : un arc d'encre qui passe au-dessus de l'articulation, et rejoint le devant de la patte)
		var arc := PackedVector2Array([hanche + d * w0 * 0.3 + d.rotated(-PI * 0.5) * w0 * 0.5])
		for i in 6:
			arc.append(hanche + d.rotated(-PI * 0.5 - i * (0.36 if devant else 0.4)) * w0 * 0.5)
		p.tracer(Planche.ouvert(arc), e * 0.7, T["encre"], 0.8)
	var carap := m.og("carapace")
	if not carap.is_empty():
		_carapace(p, m, sil, carap)
	var ailes := m.og("ailes")
	if not ailes.is_empty():
		_aile(p, m, ailes)
	var nageoires := m.og("nageoires", "flancs")
	if not nageoires.is_empty():
		# (une nageoire au flanc, derrière l'épaule, couchée vers l'arrière)
		var l := m.th * (0.5 + 0.8 * float(nageoires["taille"])) * (1.5 if nageoires["forme"] == "voiles" else 1.0)
		var a := Vector2(m.xf - m.wp * 0.2, m.yhf - m.th * 0.12)
		var pts2 := PackedVector2Array([a, a + Vector2(-l * 0.3, -l * 0.16), a + Vector2(-l * 1.0, l * 0.22), a + Vector2(-l * 0.55, l * 0.3), a + Vector2(-l * 0.12, l * 0.22)])
		p.volume(Planche.ferme(p.vivant(pts2, e * 0.12), 0.75), T["accent"], func():
			var rayons := ""
			for i in 4:
				rayons += "M%s L%s" % [Planche.pt(a + Vector2(-l * 0.1, l * 0.05)), Planche.pt(a + Vector2(-l * (0.5 + 0.12 * i), l * (0.02 + 0.08 * i)))]
			p.tracer(rayons, e * 0.45, T["encre"], 0.55), {"lourd": false, "cerne": 0.85})
	var pinces := m.og("pinces")
	if not pinces.is_empty():
		# (une pince, au poitrail)
		var l2 := m.hs * (1.0 + 1.2 * float(pinces["taille"]))
		var gros := 1.5 if pinces["forme"] == "massives" else 1.0
		var a2 := Vector2(m.xa - m.lt * 0.08, m.yb + m.th * 0.2)
		var coude := a2 + Vector2(l2 * 0.5, l2 * 0.12)
		var main := a2 + Vector2(l2, -l2 * 0.05)
		p.volume(Planche.ruban(PackedVector2Array([a2, coude, main]), m.wp * 0.8 * gros, m.wp * 0.6 * gros), T["dos"], Callable(), {"cerne": 0.9})
		for s in [-1.0, 1.0]:
			p.volume(Planche.ruban(PackedVector2Array([main, main + Vector2(l2 * 0.25, s * l2 * 0.2 * gros), main + Vector2(l2 * 0.5, s * l2 * 0.06)]), m.wp * 0.6 * gros, e * 0.6),
				T["dos"], Callable(), {"lourd": false, "cerne": 0.9})


# une carapace : petite, un bouclier d'écailles sur l'échine ; grande, une coque qui descend sur le flanc et cache le haut des
# pattes. Bombée : des écailles en dôme ; segmentée : des anneaux qui se recouvrent. Son bord du bas est festonné.
static func _carapace(p: Planche, m: Mesures, sil: PackedVector2Array, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var th := m.th
	var t: float = o["taille"]
	var k := smoothstep(0.2, 0.9, t)
	var s0 := lerpf(0.2, 0.02, k)
	var s1 := lerpf(0.84, 1.0, k)
	var h := th * (0.05 + 0.24 * t)
	var prof := th * lerpf(0.3, 0.9, k)
	var combien := clampi(int(round((_dos(m, sil, s1).x - _dos(m, sil, s0).x) / maxf(th * 0.42, 4.0))), 3, 7)
	var segm: bool = o["forme"] == "segmentee"
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in combien + 1:
		var f := float(i) / combien
		var q := _dos(m, sil, lerpf(s0, s1, f))
		var bombe := sin(PI * lerpf(0.1, 0.9, f))
		haut.append(q + Vector2(0.0, -h * (0.3 + 0.7 * bombe)))
		bas.append(q + Vector2(0.0, prof * (0.55 + 0.45 * bombe)))
	var tour := haut.duplicate()
	for i in range(combien, -1, -1):
		tour.append(bas[i])
		if i > 0:
			tour.append((bas[i] + bas[i - 1]) * 0.5 + Vector2(0.0, th * 0.07))
	p.volume(Planche.ferme(p.vivant(tour, e * 0.12), 0.8), T["dos"], func():
		var joints := ""
		var reflets := ""
		for i in range(1, combien):
			var milieu := (haut[i] + bas[i]) * 0.5 + Vector2(-th * 0.07, 0.0)
			joints += "M%s Q%s %s" % [Planche.pt(haut[i] + Vector2(0.0, -th * 0.2)), Planche.pt(milieu), Planche.pt(bas[i] + Vector2(0.0, th * 0.1))]
			if segm:
				reflets += "M%s Q%s %s" % [Planche.pt(haut[i] + Vector2(e * 1.3, 0.0)), Planche.pt(milieu + Vector2(e * 1.3, 0.0)), Planche.pt(bas[i] + Vector2(e * 1.3, 0.0))]
		if not segm:
			# (des écailles : un rang, ou deux sur une grande coque ; chacune a son reflet)
			var rangs := 2 if k > 0.45 else 1
			if rangs == 2:
				var parallele := PackedVector2Array()
				for i in combien + 1:
					parallele.append(haut[i].lerp(bas[i], 0.5))
				joints += Planche.ouvert(parallele)
			for i in combien:
				for j in rangs:
					var c := haut[i].lerp(haut[i + 1], 0.42).lerp(bas[i].lerp(bas[i + 1], 0.42), (0.3 if rangs == 1 else 0.2 + 0.5 * j))
					reflets += "M%s q%s %s %s %s" % [Planche.pt(c + Vector2(-th * 0.08, th * 0.03)), Planche.n(th * 0.03), Planche.n(-th * 0.08), Planche.n(th * 0.13), Planche.n(-th * 0.07)]
		p.tracer(joints, e * 0.6, T["encre"], 0.65)
		p.tracer(reflets, e * 0.8, T["lumiere"], 0.4)
		# (le luisant du dessus, l'ombre du bord)
		var luisant := PackedVector2Array()
		for i in range(0, combien):
			luisant.append(haut[i].lerp(haut[i + 1], 0.5) + Vector2(-e * 0.3, e * 1.5))
		p.tracer(Planche.ouvert(luisant), e * 0.9, T["lumiere"], 0.45)
		var ourlet := PackedVector2Array()
		for i in combien + 1:
			ourlet.append(bas[i] + Vector2(0.0, -e * 0.9))
		p.tracer(Planche.ouvert(ourlet), e * 1.6, T["encre"], 0.22))


# une aile repliée sur le flanc : de plumes (les couvertures, puis les rémiges dont les pointes font le bord du bas), ou de peau
# tendue sur des doigts
static func _aile(p: Planche, m: Mesures, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var th := m.th
	var l := m.lt * (0.55 + 0.6 * float(o["taille"]))
	var ep := Vector2(m.xf + m.wp * 0.3, m.yhf - th * 0.34)
	var pente := m.pente * th / maxf(m.lt, 0.001)
	# (un point de l'aile : vers l'arrière, vers le bas)
	var pos := func(fx: float, fy: float) -> Vector2:
		return ep + Vector2(-l * fx, th * fy - l * fx * pente)
	if o["forme"] == "membranes":
		var poignet: Vector2 = pos.call(-0.04, -0.12)
		var bouts := [pos.call(1.0, -0.1), pos.call(0.82, 0.3), pos.call(0.52, 0.42), pos.call(0.2, 0.42)]
		var tour := PackedVector2Array([poignet, pos.call(0.4, -0.3)])
		for i in bouts.size():
			tour.append(bouts[i])
			if i < bouts.size() - 1:
				tour.append((bouts[i] + bouts[i + 1]) * 0.5 + (poignet - bouts[i]).normalized() * th * 0.12)
		tour.append(pos.call(0.02, 0.16))
		p.volume(Planche.ferme(p.vivant(tour, e * 0.12), 0.6), T["dos"].lerp(T["accent"], 0.45), func():
			var doigts := ""
			for b in bouts:
				doigts += "M%s L%s" % [Planche.pt(poignet), Planche.pt(b)]
			p.tracer(doigts, e * 0.9, T["robe"], 0.9)
			p.tracer(doigts, e * 0.4, T["encre"], 0.6), {"cerne": 0.9})
		return
	var tour2 := PackedVector2Array([pos.call(-0.06, -0.06), pos.call(0.14, -0.3), pos.call(0.5, -0.31), pos.call(0.84, -0.18), pos.call(1.05, 0.06),
		pos.call(0.84, 0.16), pos.call(0.6, 0.27), pos.call(0.34, 0.35), pos.call(0.1, 0.3), pos.call(-0.04, 0.12)])
	p.volume(Planche.ferme(p.vivant(tour2, e * 0.12), 0.9), T["robe"].lerp(T["dos"], 0.6), func():
		# (les couvertures de l'épaule, plus claires ; une barre de couleur ; le bout des grandes plumes, sombre)
		p.aplat(Planche.ferme(PackedVector2Array([pos.call(-0.1, -0.34), pos.call(0.5, -0.34), pos.call(0.55, -0.08), pos.call(0.3, 0.04), pos.call(-0.1, 0.12)]), 0.9), T["robe"], 0.85)
		p.aplat(Planche.ferme(PackedVector2Array([pos.call(0.02, 0.1), pos.call(0.3, 0.04), pos.call(0.6, -0.06), pos.call(0.64, 0.05), pos.call(0.32, 0.17), pos.call(0.02, 0.22)]), 0.9), T["accent"], 0.75)
		p.aplat(Planche.ferme(PackedVector2Array([pos.call(0.74, -0.34), pos.call(1.12, -0.2), pos.call(1.12, 0.3), pos.call(0.86, 0.3)]), 0.9), T["dos"], 0.65)
		# (les rémiges : de longues plumes couchées, de l'épaule au bord ; puis deux rangs de petites plumes en festons)
		var plumes := ""
		for j in 5:
			var f := j / 4.0
			plumes += "M%s Q%s %s" % [Planche.pt(pos.call(0.3 - 0.14 * f, 0.02 + 0.12 * f)), Planche.pt(pos.call(0.62 - 0.2 * f, 0.0 + 0.18 * f)), Planche.pt(pos.call(1.0 - 0.52 * f, 0.07 + 0.24 * f))]
		for i in 5:
			var q: Vector2 = pos.call(0.04 + 0.1 * i, -0.12 + 0.05 * (i % 2))
			plumes += "M%s q%s %s %s 0" % [Planche.pt(q), Planche.n(-l * 0.04), Planche.n(th * 0.1), Planche.n(-l * 0.08)]
		p.tracer(plumes, e * 0.5, T["encre"], 0.6), {"cerne": 0.9})


# --- le cou et la tête ---

static func _cou_et_tete(p: Planche, m: Mesures, sil: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	p.calque("tete")
	p.pivot("tete", m.base)
	# le profil de la tête, dans le monde
	var P := PackedVector2Array()
	for i in m.crane.size():
		P.append(m.cp(i))
	P = p.vivant(P, e * 0.14)
	# le cou : de la base (deux points de la silhouette du corps) à la nuque et à la gorge ; il recouvre le poitrail d'un lobe
	# sans cerne, autour du pivot : la tête tourne sans montrer de coupe
	var nh := sil[m.i_nh]
	var nb := sil[m.i_nb]
	var nuque := P[NUQUE]
	var gorge := P[GORGE]
	# (un cou dressé arrive par-dessous la tête : la nuque et la gorge, presque l'une au-dessus de l'autre, le serreraient en
	# une tige sous un gros crâne. On l'attache alors plus large : la gorge avance sous la mâchoire, la nuque recule un peu
	# derrière le crâne)
	var large := (nuque - gorge).dot(m.nrm)
	var voulu := m.hs * COU_A_LA_TETE
	if large < voulu:
		gorge -= m.nrm * (voulu - large) * 0.7
		nuque += m.nrm * (voulu - large) * 0.3
	var gras := 0.06 if (m.carn or m.chasseur) else -0.03
	if m.famille == "lezard" or m.famille == "croco" or m.famille == "loutre":
		gras = 0.04
	var fanon := 0.0
	if m.famille == "lezard":
		fanon = 0.12
	elif m.lourd:
		fanon = 0.08
	var long_nuque := nh.distance_to(nuque)
	var long_gorge := nb.distance_to(gorge)
	var cou := PackedVector2Array([nh, nh.lerp(nuque, 0.5) + m.nrm * long_nuque * gras, nuque, m.o, gorge,
		gorge.lerp(nb, 0.5) - m.nrm * long_gorge * fanon + m.dir * long_gorge * fanon * 0.3, nb,
		Vector2(nb.x - m.wb * 0.35, minf(nb.y + m.wb * 0.45, m.bot + m.yy(nb.x) - m.th * 0.14)), Vector2(nh.x - m.wb * 0.55, nh.y + m.th * 0.16)])
	var encre := Planche.coul(T["encre"])
	var d_nuque := _suite(cou, 0, 2, 0.9)
	var d_gorge := _suite(cou, 4, 6, 0.9)
	p.svg("<path d=\"%s %s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" transform=\"translate(%s %s)\"/>" % [d_nuque, d_gorge, encre, Planche.n(e * 1.5), Planche.n(e * 0.3), Planche.n(e * 0.5)])
	p.volume(Planche.ferme(cou, 0.9), T["robe"], func():
		p.aplat(Planche.ruban(PackedVector2Array([nh + m.nrm * m.wb * 0.1 - m.dir * m.wb * 0.2, cou[1] + m.nrm * m.wb * 0.06, nuque + m.nrm * m.hs * 0.1]), m.wb * 0.62, m.hs * 0.5), T["dos"], 0.42)
		p.aplat(Planche.ruban(PackedVector2Array([nb - m.nrm * m.wb * 0.12, cou[5] - m.nrm * m.wb * 0.1, gorge - m.nrm * m.hs * 0.12]), m.wb * 0.42, m.hs * 0.42), T["ventre"], 0.62)
		_peindre_motif(p, m)
		if m.poilu and (m.carn or m.chasseur):
			# (le poil du collier)
			p.hachures(m.base + m.nrm * m.wb * 0.2, m.base - m.nrm * m.wb * 0.35 + m.dir * m.wb * 0.2, 4, m.wb * 0.22, m.dir.angle() + 2.2, 0.5),
		{"cerne": 0.0, "lourd": false})
	p.cerne(d_nuque)
	p.cerne(d_gorge)
	if m.poilu and (m.carn or m.chasseur) and long_gorge > m.wb * 0.5:
		# (le poil du poitrail)
		_meches(p, cou[5].lerp(nb, 0.15), cou[5].lerp(nb, 0.9), 3, m.wb * 0.2, m.dir.angle() + 2.0, T["robe"].lerp(T["ventre"], 0.45))
	_tete(p, m, P)


# la tête : derrière elle, l'oreille et la corne du côté lointain, la collerette, la crête ; puis le crâne et le museau d'une
# seule forme, la gueule, la truffe, l'œil ; puis l'oreille, la corne, les antennes du côté proche
static func _tete(p: Planche, m: Mesures, P: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var hs := m.hs
	var fam := m.famille
	var detail: bool = p.L >= 56.0
	var cornes := m.og("cornes")
	if m.oreilles > 0.12:
		_oreille(p, m, true)
	if not cornes.is_empty():
		_cornes(p, m, cornes, true)
	var defenses := m.og("defenses")
	if not defenses.is_empty():
		_defense(p, m, defenses, true)
	var collerette := m.og("collerette")
	if not collerette.is_empty():
		_collerette(p, m, collerette)
	var crete := m.og("crete", "tete")
	if not crete.is_empty():
		_crete_de_tete(p, m, crete)
	# le crâne et le museau : cernés de la nuque au bout du nez et jusqu'à l'angle de la mâchoire ; l'arrière se fond au cou
	var dedans := func():
		# (le dessus du crâne et le chanfrein, plus sombres ; la mâchoire, la gorge, plus pâles)
		p.aplat(Planche.ruban(PackedVector2Array([m.tp(-0.6, -0.42), m.tp(0.1, -0.45), m.cp(CHANFREIN) + Vector2(0.0, -hs * 0.06).rotated(m.incl), m.cp(BOUT)]), hs * 0.5, hs * 0.16), T["dos"], 0.42)
		p.aplat(Planche.ruban(PackedVector2Array([m.tp(-0.5, 0.42), m.cp(MACHOIRE) + Vector2(0.0, hs * 0.04).rotated(m.incl), m.cp(MENTON), m.cp(LEVRE)]), hs * 0.5, hs * 0.2), T["ventre"], 0.82)
		match m.motif:
			"masque":
				# (un loup sombre en travers de l'œil, du museau à la joue)
				var o := m.tp(m.oeil.x, m.oeil.y)
				p.aplat(Planche.ruban(PackedVector2Array([m.cp(NEZ).lerp(m.cp(LEVRE), 0.3), o + Vector2(hs * 0.06, hs * 0.04).rotated(m.incl), m.tp(-0.5, 0.05)]), hs * 0.14, hs * 0.5), T["dos"], 0.85)
			"bandes":
				var o2 := m.tp(m.oeil.x, m.oeil.y)
				p.aplat(Planche.ruban(PackedVector2Array([m.tp(-0.6, 0.0), o2, m.cp(NEZ).lerp(m.cp(BOUT), 0.5)]), hs * 0.2, hs * 0.08), T["dos"], 0.7)
			"rayures":
				var d := ""
				for i in 3:
					var a := m.tp(-0.36 + 0.2 * i, -0.5)
					var b := m.tp(-0.32 + 0.24 * i, -0.08 - 0.05 * i)
					d += "M%s L%s L%sZ" % [Planche.pt(a + Vector2(-hs * 0.06, 0.0)), Planche.pt(a + Vector2(hs * 0.06, 0.0)), Planche.pt(b)]
				p.aplat(d, T["dos"], 0.72)
			"taches":
				var d2 := ""
				for q in [Vector2(-0.3, -0.26), Vector2(-0.05, -0.34), Vector2(-0.34, 0.02), Vector2(0.3, -0.26)]:
					d2 += Planche.ferme(Planche.ellipse(m.tp(q.x, q.y), hs * 0.07, hs * 0.055, 6), 1.0)
				p.aplat(d2, T["dos"], 0.7)
		if fam == "brouteur":
			# (le mufle : le bout du museau, sombre et doux)
			p.aplat(Planche.ferme(Planche.ellipse(m.cp(BOUT) + Vector2(-hs * 0.02, hs * 0.08).rotated(m.incl), hs * 0.15, hs * 0.2, 8, m.incl), 1.0), T["truffe"], 0.9)
		elif fam == "sanglier":
			p.aplat(Planche.ferme(Planche.ellipse(m.cp(BOUT) + Vector2(-hs * 0.01, hs * 0.02).rotated(m.incl), hs * 0.1, hs * 0.22, 8, m.incl), 1.0), T["truffe"], 0.85)
		elif fam == "felin" or fam == "loutre":
			# (le coussin des moustaches, clair)
			p.aplat(Planche.ferme(Planche.ellipse(m.cp(LEVRE) + Vector2(-hs * 0.14, -hs * 0.08).rotated(m.incl), hs * 0.2, hs * 0.14, 8, m.incl), 1.0), T["ventre"], 0.7)
	_forme(p, P, m.tension, NUQUE, GANACHE, T["robe"], dedans)

	# la gueule : une fente longue chez un chasseur et un lézard, courte chez un brouteur
	var levre := m.crane[LEVRE]
	var debut := Vector2(levre.x - 0.02, levre.y - (0.03 if (m.carn or fam == "lezard" or fam == "croco") else 0.07))
	var coin := Vector2(lerpf(m.crane[STOP].x, m.crane[MACHOIRE].x, 0.5) - 0.08, m.crane[MACHOIRE].y - 0.2)
	if fam == "lezard" or fam == "croco":
		coin = Vector2(-0.12, m.crane[MACHOIRE].y - 0.2)
	elif not m.carn and fam != "sanglier":
		coin = Vector2(maxf(debut.x - 0.3 - 0.35 * m.mu, 0.3), debut.y + 0.01)
	var mi := debut.lerp(coin, 0.5) + Vector2(0.0, 0.045)
	p.tracer("M%s Q%s %s" % [Planche.pt(m.tp(debut.x, debut.y)), Planche.pt(m.tp(mi.x, mi.y)), Planche.pt(m.tp(coin.x, coin.y))], maxf(e * 0.6, 0.6), T["encre"], 0.9)
	if (m.carn or fam == "lezard") and detail:
		# (le coin de la gueule remonte)
		p.tracer("M%s l%s" % [Planche.pt(m.tp(coin.x, coin.y)), Planche.pt(Vector2(-hs * 0.07, -hs * 0.06).rotated(m.incl))], maxf(e * 0.55, 0.55), T["encre"], 0.8)
	# les dents : le croc d'un chasseur, les défenses d'un sanglier, la rangée d'un crocodile
	var longs: bool = p.traits.has("crocs-allonges")
	if fam == "croco":
		var dents := ""
		for i in 6:
			var q := debut.lerp(coin, 0.06 + 0.15 * i) + Vector2(0.0, 0.03 * sin(PI * (0.06 + 0.15 * i)))
			dents += "M%s L%s L%sZ" % [Planche.pt(m.tp(q.x - 0.035, q.y)), Planche.pt(m.tp(q.x, q.y + (0.1 if i % 2 == 0 else -0.09))), Planche.pt(m.tp(q.x + 0.035, q.y))]
		p.svg("<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [dents, Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.35)])
	elif (m.carn and (m.rob > 0.2 or longs)) or (longs and fam != "sanglier"):
		var lc := 0.46 if longs else 0.22
		var q2 := debut.lerp(coin, 0.2) + Vector2(0.0, 0.01)
		p.svg("<path d=\"M%s Q%s %s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(m.tp(q2.x + 0.07, q2.y)), Planche.pt(m.tp(q2.x + 0.05, q2.y + lc * 0.6)),
			Planche.pt(m.tp(q2.x - 0.02, q2.y + lc)), Planche.pt(m.tp(q2.x - 0.06, q2.y)), Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.4)])
		if longs and detail:
			var q3 := debut.lerp(coin, 0.5)
			p.svg("<path d=\"M%s L%s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(m.tp(q3.x + 0.04, q3.y + 0.02)), Planche.pt(m.tp(q3.x, q3.y + 0.16)), Planche.pt(m.tp(q3.x - 0.04, q3.y + 0.02)),
				Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.35)])
	elif fam == "sanglier" and (m.rob > 0.45 or longs):
		# (une défense qui remonte de la mâchoire)
		var lc2 := 0.5 if longs else 0.26
		var q4 := debut.lerp(coin, 0.3) + Vector2(0.0, 0.03)
		p.volume(Planche.ruban(PackedVector2Array([m.tp(q4.x, q4.y), m.tp(q4.x + 0.1, q4.y - lc2 * 0.5), m.tp(q4.x + 0.04, q4.y - lc2)]), hs * 0.12, e * 0.5), T["os"], Callable(), {"lourd": false, "cerne": 0.6})
	elif fam == "rongeur" and detail:
		# (les incisives)
		p.svg("<path d=\"M%s L%s L%s L%sZ\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [Planche.pt(m.tp(debut.x - 0.02, debut.y)), Planche.pt(m.tp(debut.x - 0.03, debut.y + 0.12)), Planche.pt(m.tp(debut.x - 0.1, debut.y + 0.11)),
			Planche.pt(m.tp(debut.x - 0.1, debut.y)), Planche.coul(T["os"]), Planche.coul(T["encre"]), Planche.n(e * 0.35)])

	# la truffe, les naseaux
	var bout := m.crane[BOUT]
	match fam:
		"loup", "felin", "loutre", "fouine":
			var rt := 0.12 if fam != "fouine" else 0.09
			p.aplat(Planche.ferme(Planche.ellipse(m.tp(bout.x - 0.05, bout.y - 0.05), hs * rt, hs * rt * 0.85, 7, m.incl), 1.0), T["truffe"])
			if detail:
				p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" opacity=\"0.5\"/>" % [Planche.n(m.tp(bout.x - 0.08, bout.y - 0.09).x), Planche.n(m.tp(bout.x - 0.08, bout.y - 0.09).y), Planche.n(maxf(0.4, hs * 0.03)), Planche.coul(T["lumiere"])])
		"rongeur", "fouisseur":
			p.aplat(Planche.ferme(Planche.ellipse(m.tp(bout.x - 0.03, bout.y - 0.01), hs * 0.085, hs * 0.075, 6), 1.0), T["truffe"].lerp(T["accent"], 0.45 if fam == "fouisseur" else 0.0))
		"brouteur", "sanglier":
			p.tracer("M%s l%s" % [Planche.pt(m.tp(bout.x - 0.07, bout.y - 0.02)), Planche.pt(Vector2(-hs * 0.07, -hs * 0.05).rotated(m.incl))], maxf(e * 0.55, 0.55), T["robe"].lerp(T["ventre"], 0.5), 0.9)
		_:
			# (un lézard, un crocodile : une narine)
			p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(m.tp(bout.x - 0.1, bout.y - 0.1).x), Planche.n(m.tp(bout.x - 0.1, bout.y - 0.1).y), Planche.n(maxf(0.45, hs * 0.035)), Planche.coul(T["encre"])])

	# les moustaches
	if m.poilu and p.L >= 48.0 and (p.traits.has("vibrisses") or fam in ["felin", "loutre", "rongeur", "fouine", "fouisseur"]):
		var lv := (1.0 if p.traits.has("vibrisses") else 0.6) * hs
		var d3 := ""
		var racine := m.tp(levre.x - 0.16, levre.y - 0.12)
		for i in (4 if p.traits.has("vibrisses") else 3):
			var a := 2.5 + 0.34 * i + m.incl
			d3 += "M%s q%s %s" % [Planche.pt(racine + Vector2(0.0, hs * 0.03 * i).rotated(m.incl)), Planche.pt(Vector2.from_angle(a) * lv * 0.5 + Vector2(0.0, lv * 0.1)), Planche.pt(Vector2.from_angle(a) * lv)]
		p.tracer(d3, maxf(0.45, e * 0.36), T["encre"], 0.7)

	# l'œil : rond et sombre, cerclé de clair, chez une proie ; d'ambre, sous une arcade, chez un chasseur
	var oe := m.tp(m.oeil.x, m.oeil.y)
	var ro := maxf(m.oeil.z * hs, 1.45 if p.L < 60.0 else 1.7) * (1.15 if p.nocturne else 1.0)
	if p.traits.has("yeux-nocturnes"):
		ro *= 1.12
	if not p.chasseur:
		p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" opacity=\"0.75\"/>" % [Planche.n(oe.x), Planche.n(oe.y), Planche.n(ro + e * (0.8 if m.poilu else 1.2)), Planche.coul(T["ventre"] if m.poilu else T["dos"])])
	elif detail:
		# (un cerne d'ombre : le regard s'enfonce)
		p.aplat(Planche.ferme(Planche.ellipse(oe + Vector2(-hs * 0.02, hs * 0.02).rotated(m.incl), ro * 2.1, ro * 1.5, 8, m.incl - 0.2), 1.0), T["encre"], 0.22)
	var opts := {}
	if (fam == "felin" and (p.nocturne or p.plan.get("activite", "") == "crepusculaire")) or ((fam == "lezard" or fam == "croco") and m.carn):
		opts["fente"] = true
	if bool(p.plan.get("noire", false)):
		opts["braise"] = true
		opts["pente"] = m.incl + 0.3
		ro *= 0.8
	p.oeil(oe, ro / (1.15 if p.nocturne else 1.0), opts)
	if (fam == "lezard" or fam == "croco") and detail:
		# (l'arcade d'écailles, le tympan)
		p.tracer("M%s Q%s %s" % [Planche.pt(oe + Vector2(-ro * 1.5, -ro * 0.7).rotated(m.incl)), Planche.pt(oe + Vector2(0.0, -ro * 1.9).rotated(m.incl)), Planche.pt(oe + Vector2(ro * 1.6, -ro * 0.5).rotated(m.incl))], e * 0.6, T["encre"], 0.8)
		if m.oreilles <= 0.12:
			p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" opacity=\"0.7\"/>" % [Planche.n(m.tp(-0.3, 0.02).x), Planche.n(m.tp(-0.3, 0.02).y), Planche.n(hs * 0.08), Planche.coul(T["dos"]), Planche.coul(T["encre"]), Planche.n(e * 0.4)])
	if m.poilu and detail and (fam == "loup" or fam == "felin"):
		# (le poil de la joue)
		_meches(p, m.cp(GANACHE) + Vector2(0.0, -hs * 0.2).rotated(m.incl), m.cp(GANACHE).lerp(m.cp(GORGE), 0.75), 2, hs * 0.24, m.incl + 2.6, T["robe"].lerp(T["ventre"], 0.3))

	# ce que la tête porte, du côté proche
	var trompe := m.og("trompe")
	if not trompe.is_empty():
		_trompe(p, m, trompe)
	if not defenses.is_empty():
		_defense(p, m, defenses, false)
	if m.oreilles > 0.12:
		_oreille(p, m, false)
	if not cornes.is_empty():
		_cornes(p, m, cornes, false)
	var antennes := m.og("antennes")
	if not antennes.is_empty():
		_antennes(p, m, antennes)


# une oreille : dressée et pointue chez un chasseur, en feuille couchée chez un brouteur, ronde chez un rongeur, un petit
# volet de peau chez un lézard
static func _oreille(p: Planche, m: Mesures, loin: bool) -> void:
	var T: Dictionary = p.tons
	var l := m.l_oreille / m.hs
	var r := m.oreille + (Vector2(0.24, 0.0) if loin else Vector2.ZERO)
	var teinte: Color = T["loin"] if loin else T["robe"]
	var pts: PackedVector2Array
	var creux: PackedVector2Array
	var tension := 1.0
	match m.famille:
		"loup", "felin":
			var k := 1.0 if m.famille == "loup" else 1.25
			pts = PackedVector2Array([m.tp(r.x - 0.2 * l * k, r.y + 0.08), m.tp(r.x - 0.16 * l, r.y - 0.55 * l), m.tp(r.x - 0.06 * l, r.y - l), m.tp(r.x + 0.2 * l * k, r.y - 0.4 * l), m.tp(r.x + 0.3 * l * k, r.y + 0.04)])
			creux = PackedVector2Array([m.tp(r.x - 0.04 * l, r.y - 0.05), m.tp(r.x - 0.05 * l, r.y - 0.8 * l), m.tp(r.x + 0.2 * l * k, r.y - 0.05)])
			tension = 0.55
		"brouteur", "sanglier":
			var d := Vector2(-0.5, -0.86) if m.oreilles > 0.45 else Vector2(-0.68, -0.73)
			if m.famille == "sanglier":
				d = Vector2(-0.3, -0.95)
			var t := Vector2(d.y, -d.x)
			pts = PackedVector2Array([m.tp(r.x, r.y), m.tp(r.x + d.x * l * 0.45 + t.x * l * 0.26, r.y + d.y * l * 0.45 + t.y * l * 0.26), m.tp(r.x + d.x * l, r.y + d.y * l),
				m.tp(r.x + d.x * l * 0.5 - t.x * l * 0.2, r.y + d.y * l * 0.5 - t.y * l * 0.2), m.tp(r.x - t.x * 0.1, r.y - t.y * 0.1)])
			creux = PackedVector2Array([m.tp(r.x + d.x * l * 0.15, r.y + d.y * l * 0.15), m.tp(r.x + d.x * l * 0.5 + t.x * l * 0.12, r.y + d.y * l * 0.5 + t.y * l * 0.12), m.tp(r.x + d.x * l * 0.85, r.y + d.y * l * 0.85),
				m.tp(r.x + d.x * l * 0.5 - t.x * l * 0.08, r.y + d.y * l * 0.5 - t.y * l * 0.08)])
		"lezard", "croco":
			pts = PackedVector2Array([m.tp(r.x + 0.06, r.y - 0.1), m.tp(r.x - 0.6 * l, r.y - 0.5 * l), m.tp(r.x - 1.0 * l, r.y + 0.05 * l), m.tp(r.x - 0.5 * l, r.y + 0.35 * l), m.tp(r.x + 0.04, r.y + 0.12)])
			creux = PackedVector2Array([m.tp(r.x - 0.1 * l, r.y), m.tp(r.x - 0.55 * l, r.y - 0.25 * l), m.tp(r.x - 0.8 * l, r.y + 0.05 * l), m.tp(r.x - 0.45 * l, r.y + 0.2 * l)])
			teinte = T["accent"].lerp(T["loin"], 0.5) if loin else T["accent"]
			tension = 0.8
		_:
			# (ronde ; longue, elle s'allonge comme celle d'un lièvre)
			var longue := m.oreilles > 0.4 and m.famille == "rongeur"
			var c := Vector2(r.x - (0.16 if longue else 0.08) * l, r.y - (0.5 if longue else 0.42) * l)
			var rx := (0.24 if longue else 0.4) * l
			var ry := (0.62 if longue else 0.5) * l
			var rot := -0.35 if longue else -0.15
			pts = PackedVector2Array()
			creux = PackedVector2Array()
			for i in 8:
				var a := TAU * i / 8.0
				var q := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
				pts.append(m.tp(c.x + q.x, c.y + q.y))
				creux.append(m.tp(c.x + q.x * 0.55 + 0.03 * l, c.y + q.y * 0.6 + 0.06 * l))
	p.volume(Planche.ferme(pts, tension), teinte, func():
		if not loin:
			p.aplat(Planche.ferme(creux, tension), T["accent"] if m.poilu else T["dos"], 0.55),
		{"lourd": false, "cerne": 0.85})


# les cornes : recourbées en croissant, droites, ramifiées ; une seule : sur le nez ; quatre : une seconde paire, plus courte
static func _cornes(p: Planche, m: Mesures, o: Dictionary, loin: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var t := 0.5 + float(o["taille"])
	var nombre := int(o["nombre"])
	var teinte: Color = T["os"].darkened(0.3) if loin else T["os"]
	var pied := Vector2(0.0, -0.4) + (Vector2(0.12, 0.02) if loin else Vector2.ZERO)
	if nombre == 1 or nombre == 3:
		if not loin:
			# (une corne sur le nez)
			var n := m.crane[CHANFREIN].lerp(m.crane[NEZ], 0.6)
			var l := 0.9 * t
			p.volume(Planche.ruban(PackedVector2Array([m.tp(n.x, n.y + 0.04), m.tp(n.x + 0.04, n.y - l * 0.5), m.tp(n.x - 0.08, n.y - l)]), m.hs * 0.3, e * 0.6), teinte, Callable(), {"lourd": false, "cerne": 0.8})
		if nombre == 1:
			return
	var paires := 2 if nombre >= 4 else 1
	for k in paires:
		var r := pied + Vector2(-0.2 * k, 0.03 * k)
		var tk := t * (1.0 if k == 0 else 0.6)
		match str(o["forme"]):
			"ramifiees":
				# (un bois : une perche vers l'arrière, trois andouillers vers l'avant)
				var L := 1.3 * tk
				var a := m.tp(r.x, r.y)
				var b := m.tp(r.x - 0.35 * L, r.y - L)
				var w := maxf(e * 1.5, m.hs * 0.11)
				for s in [0.35, 0.62, 0.86]:
					var q: Vector2 = a.lerp(b, s)
					var bout: Vector2 = q + (Vector2(0.3, -0.24) * L * (1.1 - 0.4 * s) * m.hs).rotated(m.incl)
					p.volume(Planche.ruban(PackedVector2Array([q, q.lerp(bout, 0.5) + Vector2(0.0, m.hs * 0.04), bout]), w * 0.85, e * 0.45), teinte, Callable(), {"lourd": false, "cerne": 0.7})
				p.volume(Planche.ruban(PackedVector2Array([a, a.lerp(b, 0.5) + (Vector2(-0.06, 0.0) * L * m.hs).rotated(m.incl), b]), w, e * 0.5), teinte, Callable(), {"lourd": false, "cerne": 0.7})
			"droites":
				var c := m.tp(r.x + 0.25 * tk, r.y - 1.1 * tk)
				p.volume(Planche.ruban(PackedVector2Array([m.tp(r.x, r.y + 0.05), m.tp(r.x + 0.1 * tk, r.y - 0.55 * tk), c]), maxf(e * 1.7, m.hs * 0.16), e * 0.5), teinte, Callable(), {"lourd": false, "cerne": 0.8})
			_:
				# (en croissant : elle monte, puis se couche vers l'arrière)
				var ligne := PackedVector2Array()
				for i in 6:
					var s := i / 5.0
					var q := Vector2(r.x, r.y + 0.05) * (1.0 - s) * (1.0 - s) + Vector2(r.x + 0.2, r.y - 1.15 * tk) * 2.0 * s * (1.0 - s) + Vector2(r.x - 0.9 * tk, r.y - 0.4 * tk) * s * s
					ligne.append(m.tp(q.x, q.y))
				var w2 := maxf(e * 1.8, m.hs * 0.2)
				p.volume(Planche.ruban(ligne, w2, e * 0.5), teinte, func():
					if not loin and p.L >= 56.0:
						# (les anneaux de la corne)
						var d := ""
						for i in range(1, 5):
							var tg := (ligne[i + 1] - ligne[i - 1]).normalized().orthogonal() * w2 * 0.6
							d += "M%s L%s" % [Planche.pt(ligne[i] + tg), Planche.pt(ligne[i] - tg)]
						p.tracer(d, e * 0.45, T["encre"], 0.45),
					{"lourd": false, "cerne": 0.8})


# une défense : elle sort de la gueule et remonte (recourbée), ou pointe vers l'avant (droite)
static func _defense(p: Planche, m: Mesures, o: Dictionary, loin: bool) -> void:
	var T: Dictionary = p.tons
	var t := 0.5 + float(o["taille"])
	var a := m.crane[LEVRE] + Vector2(-0.22 + (0.08 if loin else 0.0), -0.02)
	var b: Vector2
	var c: Vector2
	if o["forme"] == "droites":
		b = a + Vector2(0.35 * t, 0.2)
		c = a + Vector2(0.7 * t, 0.26)
	else:
		b = a + Vector2(0.4 * t, 0.22)
		c = a + Vector2(0.5 * t, -0.5 * t)
	p.volume(Planche.ruban(PackedVector2Array([m.tp(a.x, a.y), m.tp(b.x, b.y), m.tp(c.x, c.y)]), maxf(p.e * 1.8, m.hs * 0.17), p.e * 0.5), T["os"].darkened(0.3) if loin else T["os"], Callable(),
		{"lourd": false, "cerne": 0.8})


# une trompe : elle prolonge le museau et pend
static func _trompe(p: Planche, m: Mesures, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var l := (1.6 if o["forme"] == "longue" else 0.8) * (0.5 + float(o["taille"]))
	var a := m.cp(BOUT) + Vector2(-m.hs * 0.08, m.hs * 0.02).rotated(m.incl)
	var bas := minf(a.y + l * m.hs, -m.e * 2.0)
	var ligne := PackedVector2Array([a, a + Vector2(m.hs * 0.22, m.hs * 0.1), Vector2(a.x + m.hs * 0.3, lerpf(a.y, bas, 0.55)), Vector2(a.x + m.hs * 0.14, bas), Vector2(a.x + m.hs * 0.26, bas - m.hs * 0.02)])
	p.volume(Planche.ruban(ligne, m.hs * 0.34, m.hs * 0.15), T["robe"], func():
		var d := ""
		for i in 5:
			var y := lerpf(a.y + m.hs * 0.2, bas, i / 5.0)
			d += "M%s l%s 0" % [Planche.pt(Vector2(a.x, y)), Planche.n(m.hs * 0.6)]
		p.tracer(d, m.e * 0.45, T["encre"], 0.45))


# des antennes : deux fils qui partent du front ; plumeuses, un plumet au bout
static func _antennes(p: Planche, m: Mesures, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var l := 1.0 + 1.6 * float(o["taille"])
	for k in 2:
		var a := Vector2(0.12 + 0.1 * k, -0.4)
		var b := a + Vector2(0.02, -0.72) * l
		var c := a + Vector2(0.58 - 0.1 * k, -0.74 + 0.1 * k) * l
		var d := "M%s Q%s %s" % [Planche.pt(m.tp(a.x, a.y)), Planche.pt(m.tp(b.x, b.y)), Planche.pt(m.tp(c.x, c.y))]
		p.tracer(d, maxf(m.e * 0.95, m.hs * 0.07) * (0.85 if k == 1 else 1.0), T["encre"])
		var bout := m.tp(c.x, c.y)
		if o["forme"] == "plumeuses":
			p.volume(Planche.ferme(Planche.ellipse(bout + Vector2(-m.hs * 0.1, m.hs * 0.06), m.hs * 0.2 * l * 0.5, m.hs * 0.08 * l * 0.5, 7, -0.7), 1.0), T["accent"], Callable(), {"lourd": false, "cerne": 0.7})
		else:
			p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(bout.x), Planche.n(bout.y), Planche.n(maxf(m.e * 0.8, m.hs * 0.06)), Planche.coul(T["encre"])])


# une crête sur le crâne, du front à la nuque : une voile lisse sur des rayons (un lézard), une huppe de mèches couchées vers
# l'arrière (une bête à poil), des pointes (dentelée)
static func _crete_de_tete(p: Planche, m: Mesures, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var h := 0.3 + 0.8 * float(o["taille"])
	var creux := 0.0
	if o["forme"] == "dentelee":
		creux = 0.75
	elif m.poilu:
		creux = 0.5
	var pieds := [Vector2(0.26, -0.34), Vector2(0.04, -0.44), Vector2(-0.2, -0.44), Vector2(-0.42, -0.3), Vector2(-0.6, -0.1), Vector2(-0.74, 0.1)]
	var hauteurs := [0.6, 1.0, 0.9, 0.62, 0.4]
	var pts := PackedVector2Array([m.tp(0.36, -0.24)])
	var rayons := ""
	for i in pieds.size() - 1:
		var a: Vector2 = pieds[i]
		var b: Vector2 = pieds[i + 1]
		var d := (b - a).normalized()
		var hh: float = h * hauteurs[i]
		var pointe := (a + b) * 0.5 + Vector2(-d.y, d.x) * hh + d * hh * 0.4
		pts.append(m.tp(pointe.x, pointe.y))
		if i < pieds.size() - 2:
			var val := b + (Vector2(-d.y, d.x) * hh + d * hh * 0.2) * (1.0 - creux) * 0.9
			pts.append(m.tp(val.x, val.y))
		rayons += "M%s L%s" % [Planche.pt(m.tp(a.x, a.y)), Planche.pt(m.tp(pointe.x, pointe.y))]
	pts.append(m.tp(-0.76, 0.14))
	pts.append(m.tp(-0.3, -0.1))
	p.volume(Planche.poly(pts) if creux > 0.0 else Planche.ferme(pts, 0.8), T["accent"], func():
		p.tracer(rayons, p.e * 0.5, T["encre"], 0.5), {"lourd": false, "cerne": 0.85})


# une collerette, derrière la tête : un éventail de peau tendu sur des rayons (lisse : festonné ; frangée : en pointes) ; chez
# une bête à poil, une crinière
static func _collerette(p: Planche, m: Mesures, o: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var r := 0.75 + 0.8 * float(o["taille"])
	var c := Vector2(-0.32, 0.0)
	var pts := PackedVector2Array()
	var rayons := ""
	var frange: bool = o["forme"] == "frangee"
	var dents := 13 if (frange or m.poilu) else 9
	for i in dents:
		var a := lerpf(-0.6, 3.5, float(i) / (dents - 1))
		# (une ellipse dressée, étroite : on la voit de côté)
		var rr := r
		if frange or m.poilu:
			rr *= 1.0 if i % 2 == 0 else 0.78
		var q := c + Vector2(-sin(a) * rr * 0.5 - 0.05 * rr, -cos(a) * rr)
		pts.append(m.tp(q.x, q.y))
		if i > 0 and i < dents - 1 and (not m.poilu) and (not frange or i % 2 == 0):
			rayons += "M%s L%s" % [Planche.pt(m.tp(c.x, c.y)), Planche.pt(m.tp(q.x, q.y))]
	pts.append(m.tp(c.x + 0.2, c.y + 0.1))
	p.volume(Planche.ferme(p.vivant(pts, e * 0.12), 0.5 if (frange or m.poilu) else 0.85), T["accent"], func():
		# (le cœur sombre, le bord clair)
		p.aplat(Planche.ferme(Planche.ellipse(m.tp(c.x, c.y), m.hs * r * 0.3, m.hs * r * 0.62, 8, m.incl), 1.0), T["dos"], 0.5)
		if m.poilu:
			p.hachures(m.tp(c.x - 0.1, c.y - r * 0.7), m.tp(c.x - 0.1, c.y + r * 0.7), 6, m.hs * r * 0.3, m.incl + PI, 0.5)
		else:
			p.tracer(rayons, e * 0.5, T["encre"], 0.5)
			p.tracer(Planche.ouvert(pts.slice(0, dents)), e * 1.6, T["ventre"], 0.45),
		{"cerne": 0.9})
