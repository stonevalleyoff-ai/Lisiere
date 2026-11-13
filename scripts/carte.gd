extends RefCounted
# Lisière — la carte du monde (scripts/carte.gd)
# Le monde ouvert (MONDE-OUVERT.md) a la géographie du monde d'Orvane : donnees/carte.json (fait par outils/carte.js) donne un
# point par parcelle, ses voisines, ses frontières fermées. Une région est ce qui est plus près de son point que de tout autre,
# sur un plan un peu tordu : les frontières ondulent au lieu d'être des droites. L'origine du jeu (là où l'on s'éveille) est le
# point de la prairie la plus proche du centre de la carte.
#  - region_en(p) : la région d'un point ; proches(p) : les deux plus proches, et leurs distances (pour mêler deux régions) ;
#  - retenir(p) : un pas qui n'entre ni dans l'eau (une frontière, pour l'instant), ni dans une crête (deux biomes qui se
#    touchent sur la carte sans être voisins dans Orvane : on ne passe pas).
# Le shader du sol (shaders/sol_peint.gdshader) tord le plan de la même façon : tordre() et lui doivent rester pareils.

const FICHIER := "res://donnees/carte.json"
const FONDU := 150.0          # de part et d'autre d'une frontière, les deux régions se mêlent
const CRETE := 80.0           # la demi-épaisseur d'une frontière fermée, en pixels
# les rivières : une région « rivière » est une vallée, de la terre que traverse un cours d'eau. Son lit suit les zéros d'un
# champ lent (champ) ; il s'amincit vers les terres voisines (une source) et garde sa largeur vers un lac, une mer. Là où
# champ_gue est haut, c'est un gué : on passe à pied, de l'eau jusqu'aux genoux. Ailleurs il faut un pont (scripts/pont.gd).
const LIT := 0.08             # la demi-largeur du lit, dans l'unité du champ (200 à 300 pixels de large, selon sa pente)
const SOURCE := 2400.0        # sur cette distance (en écart de distances aux points), le lit s'amincit jusqu'à rien
const PONT_MAX := 400.0       # la plus longue portée d'un pont
const PONT_LARGE := 15.0      # sa demi-largeur

var regions: Array = []       # { id, type, nom, pos, eau, bord, voisines : [rangs], murs : { rang : true } }
var cote := 16000.0
var depart := 0
var _cases := {}              # la case d'un point (de côté « cote ») → les rangs des régions dont le point y est
var ponts: Array = []         # les ponts posés : [un bout, l'autre] (le jeu les tient à jour)


# lit la carte ; biomes : ceux de l'index du monde (leur milieu dit ce qui est de l'eau, leur nom se dit en entrant). null si
# elle manque
static func lire(biomes: Array):
	if not FileAccess.file_exists(FICHIER):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("parcelles")) != TYPE_ARRAY or d["parcelles"].is_empty():
		return null
	var c = new()
	c.cote = float(d.get("cote", 16000.0))
	var milieux := {}
	var noms := {}
	for b in biomes:
		milieux[str(b.get("id", ""))] = str(b.get("milieu", "terrestre"))
		noms[str(b.get("id", ""))] = str(b.get("nom", b.get("id", "")))
	var rang := {}
	for p in d["parcelles"]:
		rang[str(p["id"])] = c.regions.size()
		var type := str(p["type"])
		c.regions.append({"id": str(p["id"]), "type": type, "nom": str(noms.get(type, type)), "pos": Vector2(float(p["x"]), float(p["y"])),
			"eau": type != "riviere" and (bool(p.get("bord", false)) or ["marin", "aquatique"].has(str(milieux.get(type, "terrestre")))),
			"riviere": type == "riviere", "bord": bool(p.get("bord", false)), "voisines": [], "murs": {}})
	for k in d["parcelles"].size():
		var p: Dictionary = d["parcelles"][k]
		for v in p.get("voisines", []):
			if rang.has(str(v)):
				c.regions[k]["voisines"].append(int(rang[str(v)]))
		for v in p.get("murs", []):
			if rang.has(str(v)):
				c.regions[k]["murs"][int(rang[str(v)])] = true
	# l'origine : la prairie la plus proche du centre de la carte (à défaut, la terre la plus proche)
	var mieux := -1
	var d0 := INF
	for passe in 2:
		for k in c.regions.size():
			var r: Dictionary = c.regions[k]
			if r["eau"] or (passe == 0 and r["type"] != "prairie"):
				continue
			if r["pos"].length() < d0:
				d0 = r["pos"].length()
				mieux = k
		if mieux >= 0:
			break
	if mieux < 0:
		return null
	c.depart = mieux
	var origine: Vector2 = c.regions[mieux]["pos"]
	for k in c.regions.size():
		c.regions[k]["pos"] -= origine
		var cle := Vector2i((c.regions[k]["pos"] / c.cote).floor())
		if not c._cases.has(cle):
			c._cases[cle] = []
		c._cases[cle].append(k)
	return c


# le plan tordu : les frontières ondulent (de grandes vagues, de plus petites dessus). Le même calcul que le shader du sol
static func tordre(p: Vector2) -> Vector2:
	return Vector2(
		420.0 * sin(p.y / 1900.0 + 1.3) + 180.0 * sin(p.y / 730.0 + p.x / 2600.0 + 4.1) + 70.0 * sin(p.y / 260.0 + 0.7),
		420.0 * sin(p.x / 2100.0 + 2.2) + 180.0 * sin(p.x / 810.0 - p.y / 2900.0 + 0.5) + 70.0 * sin(p.x / 290.0 + 3.3))


# les deux régions les plus proches de p : [la sienne, l'autre, sa distance à la sienne, à l'autre] (sur le plan tordu). La
# moitié de l'écart entre les deux distances est, à peu près, sa distance à la frontière
func proches(p: Vector2) -> Array:
	var q := p + tordre(p)
	var c := Vector2i((q / cote).floor())
	var i := -1
	var j := -1
	var di := INF
	var dj := INF
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			for k in _cases.get(Vector2i(x, y), []):
				var d: float = q.distance_squared_to(regions[k]["pos"])
				if d < di:
					dj = di
					j = i
					di = d
					i = k
				elif d < dj:
					dj = d
					j = k
	if i < 0:
		# (hors de la carte : la haute mer)
		return [depart, depart, 0.0, INF]
	return [i, j if j >= 0 else i, sqrt(di), sqrt(dj)]


func region_en(p: Vector2) -> int:
	return int(proches(p)[0])


func type_en(p: Vector2) -> String:
	return str(regions[region_en(p)]["type"])


func ferme(i: int, j: int) -> bool:
	return regions[i]["murs"].has(j)


# de 0 (au cœur d'une crête) à 1 (elle est loin) : pour y poser ses rochers
func crete_en(p: Vector2) -> float:
	var pr := proches(p)
	if not ferme(int(pr[0]), int(pr[1])):
		return 1.0
	return clampf((float(pr[3]) - float(pr[2])) / (4.0 * CRETE), 0.0, 1.0)


# un pas retenu : il ne reste ni dans l'eau, ni dans une crête. (Sans mémoire d'où l'on vient : on ne franchit pas ce dans quoi
# on ne peut pas se tenir.)
func retenir(p: Vector2) -> Vector2:
	if sur_un_pont(p):
		return p
	for essai in 4:
		var pr := proches(p)
		var i: int = pr[0]
		var j: int = pr[1]
		if i == j:
			return p
		if regions[i]["riviere"]:
			# (le lit d'une rivière, hors de ses gués : vers la berge la plus proche)
			var w := LIT * _amincit(p, i)
			var f := champ(p)
			if w > 0.0 and absf(f) < w and champ_gue(p) <= 0.5:
				var g := Vector2(champ(p + Vector2(4, 0)) - champ(p - Vector2(4, 0)), champ(p + Vector2(0, 4)) - champ(p - Vector2(0, 4))) / 8.0
				var pente_ := maxf(g.length(), 1.0e-5)
				p += g / pente_ * (1.0 if f >= 0.0 else -1.0) * ((w - absf(f)) / pente_ + 2.0)
				continue
		var q := p + tordre(p)
		var si: Vector2 = regions[i]["pos"]
		var manque := 0.0
		var vers := Vector2.ZERO
		if regions[i]["eau"]:
			# (dans l'eau : vers la terre la plus proche)
			var k := _terre_proche(q, i)
			if k < 0:
				return p
			var sk: Vector2 = regions[k]["pos"]
			vers = (q - si).normalized() - (q - sk).normalized()
			manque = q.distance_to(sk) - float(pr[2]) + 3.0
		elif ferme(i, j) and float(pr[3]) - float(pr[2]) < 2.0 * CRETE:
			var sj: Vector2 = regions[j]["pos"]
			vers = (q - sj).normalized() - (q - si).normalized()
			manque = 2.0 * CRETE - (float(pr[3]) - float(pr[2])) + 1.0
		else:
			return p
		var pente := maxf(vers.length(), 0.3)
		p += vers / pente * (manque / pente)
	return p


func _terre_proche(q: Vector2, sauf: int) -> int:
	var c := Vector2i((q / cote).floor())
	var mieux := -1
	var d0 := INF
	for x in range(c.x - 3, c.x + 4):
		for y in range(c.y - 3, c.y + 4):
			for k in _cases.get(Vector2i(x, y), []):
				if k == sauf or regions[k]["eau"]:
					continue
				var d: float = q.distance_squared_to(regions[k]["pos"])
				if d < d0:
					d0 = d
					mieux = k
	return mieux


# les régions qui touchent un rectangle du lieu (le sol peint les mêle : scripts/decor_sol.gd) : la plus présente d'abord
func dans(rect: Rect2) -> Array:
	var compte := {}
	for u in 3:
		for v in 3:
			var pr := proches(rect.position + rect.size * Vector2(u * 0.5, v * 0.5))
			compte[pr[0]] = int(compte.get(pr[0], 0)) + 2
			if float(pr[3]) - float(pr[2]) < (SOURCE + 400.0 if regions[pr[0]]["riviere"] else 2.0 * FONDU) + 2.0 * rect.size.length() * 0.25:
				compte[pr[1]] = int(compte.get(pr[1], 0)) + 1
	var out: Array = compte.keys()
	out.sort_custom(func(a, b): return compte[a] > compte[b])
	return out


# --- les rivières ---

# le champ dont une rivière suit les zéros (le même calcul que le shader du sol)
static func champ(p: Vector2) -> float:
	return sin(p.x / 1500.0 + 1.9 * sin(p.y / 2600.0 + 0.4)) + 0.55 * sin(p.y / 1150.0 + 1.1 + 1.4 * sin(p.x / 3100.0))


# au-dessus de 0,5 : un gué
static func champ_gue(p: Vector2) -> float:
	return sin(p.x / 700.0 + 0.9 * sin(p.y / 1900.0)) * sin(p.y / 830.0 + 1.7)


# de 0 (le lit s'est aminci jusqu'à rien : une terre voisine est tout près) à 1 (toute sa largeur)
func _amincit(p: Vector2, i: int) -> float:
	var q := p + tordre(p)
	var c := Vector2i((q / cote).floor())
	var di: float = q.distance_to(regions[i]["pos"])
	var a := 1.0
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			for k in _cases.get(Vector2i(x, y), []):
				if k == i or regions[k]["eau"] or regions[k]["riviere"]:
					continue
				a = minf(a, (q.distance_to(regions[k]["pos"]) - di) / SOURCE)
	return clampf(a, 0.0, 1.0)


# la rivière en p : 0 hors de son lit ; sinon de 0 (la berge) à 1 (le milieu du courant)
func lit(p: Vector2) -> float:
	var i := region_en(p)
	if not regions[i]["riviere"]:
		return 0.0
	var w := LIT * _amincit(p, i)
	if w <= 0.0:
		return 0.0
	return clampf(1.0 - absf(champ(p)) / w, 0.0, 1.0)


# l'eau où l'on marche : un gué (de 0,3 au bord à 0,6 au milieu, sur l'échelle de climat.eau) ; 0 ailleurs, et sur un pont
func gue_en(p: Vector2) -> float:
	var i := region_en(p)
	if not regions[i]["riviere"] or champ_gue(p) <= 0.5 or sur_un_pont(p):
		return 0.0
	var l := lit(p)
	return (0.3 + 0.3 * l) if l > 0.0 else 0.0


# rien ne pousse là : une étendue d'eau, le lit d'une rivière
func mouille(p: Vector2) -> bool:
	var i := region_en(p)
	return regions[i]["eau"] or (regions[i]["riviere"] and lit(p) > 0.0)


func sur_un_pont(p: Vector2) -> bool:
	for pont in ponts:
		var a: Vector2 = pont[0]
		var b: Vector2 = pont[1]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 1.0), 0.0, 1.0)
		if p.distance_to(a + (b - a) * t) < PONT_LARGE:
			return true
	return false


# où poser un pont depuis p, vers l'eau la plus proche : [un bout, l'autre] sur les deux berges ; [] si l'on n'est pas au bord
# d'une rivière, ou si elle est trop large ici
func pont_depuis(p: Vector2) -> Array:
	var i := region_en(p)
	if not regions[i]["riviere"] or lit(p) > 0.0:
		return []
	var f := champ(p)
	var g := Vector2(champ(p + Vector2(4, 0)) - champ(p - Vector2(4, 0)), champ(p + Vector2(0, 4)) - champ(p - Vector2(0, 4)))
	if g.length() < 1.0e-6:
		return []
	# (vers le courant : là où le champ s'annule)
	var dir := -g.normalized() * (1.0 if f >= 0.0 else -1.0)
	var entree := -1.0
	var d := 0.0
	while d <= 70.0 + PONT_MAX:
		var dans := lit(p + dir * d) > 0.0
		if entree < 0.0:
			if dans:
				entree = d
			elif d > 70.0:
				return []
		elif not dans:
			return [p + dir * (entree - 12.0), p + dir * (d + 12.0)]
		d += 6.0
	return []
