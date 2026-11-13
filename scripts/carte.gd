extends RefCounted
# Lisière — la carte du monde (scripts/carte.gd)
# Le monde ouvert (MONDE-OUVERT.md) a la géographie du monde d'Orvane : donnees/carte.json (fait par outils/carte.js) donne un
# point par parcelle, ses voisines, ses frontières fermées. Une région est ce qui est plus près de son point que de tout autre,
# sur un plan un peu tordu : les frontières ondulent au lieu d'être des droites. L'origine du jeu (là où l'on s'éveille) est le
# point de la prairie la plus proche du centre de la carte.
#  - region_en(p) : la région d'un point ; proches(p) : les deux plus proches, et leurs distances (pour mêler deux régions) ;
#  - retenir(p) : un pas qui n'entre ni dans l'eau (une frontière, pour l'instant), ni dans une crête (deux biomes qui se
#    touchent sur la carte sans être voisins dans Orvane : on ne passe pas), ni dans une paroi du relief ;
#  - palier(p) : à quel étage du relief on est (0 : en bas).
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
# le relief : une région haute (l'altitude de son biome) s'élève par paliers, comme les courbes d'une carte. Sa hauteur est
# celle d'un champ de bosses (bosses), d'autant plus haut que la région est haute (force) ; là où elle passe un palier, c'est
# une paroi de roche qu'on ne franchit pas, sauf à ses cols (champ_col), des rampes où l'on monte à pied, lentement.
const PALIERS := 3
const PALIER_0 := 0.4         # la hauteur du premier palier
const PALIER_PAS := 0.27      # d'un palier au suivant
const RELIEF := 0.62          # ce que la force d'une région ajoute à sa hauteur (à 0 : rien n'atteint le premier palier)
const PAROI := 26.0           # la demi-épaisseur d'une paroi, en pixels
const PENTE_MIN := 0.0005     # (là où le terrain est presque plat, une paroi s'épaissit : un massif)
const PENTE_MAX := 0.0012     # (et là où il est très raide, elle s'amincit)
const MAILLE := 256.0         # la force du relief se retient aux nœuds d'une grille de ce pas (elle varie lentement)
const MONTEE := 3000.0        # sur cet écart de distances aux points, la force d'une région se mêle à celle de sa voisine
const COL := 0.4              # au-dessus : un col
const COL_FREIN := 0.72       # ce que la pente d'un col fait à la marche

# le ton de chaque biome sur une carte (les mêmes que outils/carte.js)
const TONS := {"banquise": "e6edf0", "toundra": "c7ccb9", "taiga": "5f7a5c", "steppe": "cdbf8a", "prairie": "a9b86b", "foret": "55733f", "jungle": "2f6a3c",
	"savane": "cfae62", "desert": "e3c98a", "desert-froid": "cfc8b4", "maquis": "9aa05c", "montagne": "9a9488", "sommets": "dcdcd8", "volcan": "6b4a40",
	"grotte": "4a4540", "marais": "6f7a4a", "mangrove": "4f7a5a", "cote": "d8cfa6", "lac": "7fa3b5", "riviere": "9dbb8f", "recif": "7fc0b8", "large": "5f8fa8",
	"mer-froide": "86a4b8", "abysses": "3f5f7a", "rivage": "d9d2b0", "bois": "6a8548", "lande": "a59a6a", "falaise": "b0a898", "pierre": "a8a49a", "neige": "eef0f0",
	"tourbiere": "7a6f4a", "canyon": "c98a55", "sylve": "7a5f8a", "cristal": "a9c7d6", "caldeira": "7a5a50", "braises": "a04a30", "ossuaire": "d9d0bc",
	"terres-creuses": "8a7f6a", "cerisaie": "d79aa5"}

var regions: Array = []       # { id, type, nom, pos, eau, bord, voisines : [rangs], murs : { rang : true } }
var cote := 16000.0
var depart := 0
var _cases := {}              # la case d'un point (de côté « cote ») → les rangs des régions dont le point y est
var ponts: Array = []         # les ponts posés : [un bout, l'autre] (le jeu les tient à jour)
var _contours := {}           # le contour de chaque région déjà demandé (la carte du carnet les dessine)
var _hautes := {}             # les cases près desquelles une région a du relief (ailleurs, on ne le cherche pas)
var _forces := {}             # la force du relief aux nœuds de la grille déjà demandés


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
	var altitudes := {}
	for b in biomes:
		milieux[str(b.get("id", ""))] = str(b.get("milieu", "terrestre"))
		noms[str(b.get("id", ""))] = str(b.get("nom", b.get("id", "")))
		altitudes[str(b.get("id", ""))] = float(b.get("axes", {}).get("altitude", 0.3))
	var rang := {}
	for p in d["parcelles"]:
		rang[str(p["id"])] = c.regions.size()
		var type := str(p["type"])
		c.regions.append({"id": str(p["id"]), "type": type, "nom": str(noms.get(type, type)), "pos": Vector2(float(p["x"]), float(p["y"])),
			"eau": type != "riviere" and (bool(p.get("bord", false)) or ["marin", "aquatique"].has(str(milieux.get(type, "terrestre")))),
			"riviere": type == "riviere", "bord": bool(p.get("bord", false)), "voisines": [], "murs": {}, "haut": 0.0})
		var reg: Dictionary = c.regions[-1]
		if not reg["eau"] and not reg["riviere"] and str(milieux.get(type, "terrestre")) == "terrestre":
			# (un canyon est bas, pour Orvane ; mais c'est un pays de parois)
			reg["haut"] = 0.6 if type == "canyon" else smoothstep(0.5, 0.95, float(altitudes.get(type, 0.3)))
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
	for k in c.regions.size():
		if float(c.regions[k]["haut"]) > 0.0:
			var cle := Vector2i((c.regions[k]["pos"] / c.cote).floor())
			for x in range(cle.x - 2, cle.x + 3):
				for y in range(cle.y - 2, cle.y + 3):
					c._hautes[Vector2i(x, y)] = true
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
			# (une paroi du relief : du côté où l'on est)
			var e := _paroi(p)
			if e.is_empty() or bool(e[2]):
				return p
			p += e[1] * (1.0 if float(e[0]) >= 0.0 else -1.0) * float(e[3])
			continue
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


# --- le relief ---

# le champ des bosses, de 0 à 1 : trois ondes tordues qui se croisent, de petites dessus (le même calcul que le shader du sol)
static func bosses(p: Vector2) -> float:
	var f := sin((p.x * 0.966 + p.y * 0.259) / 520.0 + 1.6 * sin((p.y * 0.966 - p.x * 0.259) / 1700.0 + 0.4))
	f += sin((p.y * 0.94 - p.x * 0.342) / 610.0 + 1.3 * sin((-p.x * 0.94 - p.y * 0.342) / 2100.0 + 2.1) + 1.7)
	f += 0.7 * sin((p.x * 0.643 - p.y * 0.766) / 330.0 + 1.1 * sin((p.x * 0.766 + p.y * 0.643) / 1300.0 + 4.0) + 0.6)
	f += 0.16 * sin(p.x / 95.0 + 1.2 * sin(p.y / 240.0) + 2.9) * sin(p.y / 110.0 + 0.5)
	return 0.5 + f / 5.72


# au-dessus de COL : un col
static func champ_col(p: Vector2) -> float:
	return sin(p.x / 150.0 + 0.9 * sin(p.y / 900.0)) * sin(p.y / 170.0 + 1.7 + 0.8 * sin(p.x / 1100.0))


# la force du relief en p, de 0 (un pays plat) à 1 (les sommets) : celle de sa région, mêlée à celles de ses voisines près de
# leurs frontières (le relief ne s'arrête pas net : il a des contreforts). Elle varie lentement : on la calcule aux nœuds d'une
# grille, on la retient, et entre eux on la mêle
func force(p: Vector2) -> float:
	var u := p / MAILLE
	var k := Vector2i(u.floor())
	var t := u - Vector2(k)
	var a := lerpf(_force_au_noeud(k), _force_au_noeud(k + Vector2i(1, 0)), t.x)
	var b := lerpf(_force_au_noeud(k + Vector2i(0, 1)), _force_au_noeud(k + Vector2i(1, 1)), t.x)
	return lerpf(a, b, t.y)


func _force_au_noeud(k: Vector2i) -> float:
	var f = _forces.get(k)
	if f == null:
		if _forces.size() > 30000:
			_forces.clear()
		f = _force_en(Vector2(k) * MAILLE)
		_forces[k] = f
	return f


func _force_en(p: Vector2) -> float:
	var q := p + tordre(p)
	var c := Vector2i((q / cote).floor())
	if not _hautes.has(c):
		return 0.0
	var pres: Array = []
	var d0 := INF
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			for k in _cases.get(Vector2i(x, y), []):
				var d: float = q.distance_to(regions[k]["pos"])
				pres.append(k)
				pres.append(d)
				d0 = minf(d0, d)
	var somme := 0.0
	var poids := 0.0
	for n in range(0, pres.size(), 2):
		var w := maxf(0.0, 1.0 - (float(pres[n + 1]) - d0) / MONTEE)
		if w > 0.0:
			w *= w
			poids += w
			somme += w * float(regions[pres[n]]["haut"])
	return somme / poids if poids > 0.0 else 0.0


# la hauteur en p (au-dessus de PALIER_0 : sur le premier palier, et ainsi de suite)
func hauteur(p: Vector2) -> float:
	var b := bosses(p)
	if b < PALIER_0 - 0.03:
		# (sous le premier palier quelle que soit la force : inutile de la chercher)
		return b - RELIEF
	return b + RELIEF * (force(p) - 1.0)


# l'étage où l'on est : 0 en bas, jusqu'à PALIERS
func palier(p: Vector2) -> int:
	var h := hauteur(p)
	var n := 0
	while n < PALIERS and h > PALIER_0 + PALIER_PAS * n:
		n += 1
	return n


# la paroi où est p : [l'écart au palier, en pixels (positif : du côté haut), la direction qui monte, vrai si c'est un col,
# le pas qui en sort] ; [] s'il n'y en a pas. (marge : une paroi élargie d'autant, pour ce qui ne doit pas pousser tout contre.)
func _paroi(p: Vector2, marge: float = 0.0) -> Array:
	var b := bosses(p)
	if b < PALIER_0 - (PAROI + marge) * PENTE_MAX:
		return []
	var f := force(p)
	if f < 0.03:
		return []
	# (le palier le plus proche ; trop loin de lui, quelle que soit la pente : pas de paroi)
	var h := b + RELIEF * (f - 1.0)
	var n := clampi(roundi((h - PALIER_0) / PALIER_PAS), 0, PALIERS - 1)
	var e := h - (PALIER_0 + PALIER_PAS * n)
	if absf(e) >= (PAROI + marge) * PENTE_MAX:
		return []
	var g := Vector2(bosses(p + Vector2(4, 0)) - bosses(p - Vector2(4, 0)), bosses(p + Vector2(0, 4)) - bosses(p - Vector2(0, 4))) / 8.0
	var l := g.length()
	var pente := clampf(l, PENTE_MIN, PENTE_MAX)
	var d := e / pente
	if absf(d) >= PAROI + marge:
		return []
	return [d, g / maxf(l, 1.0e-7), champ_col(p) > COL, minf((PAROI - absf(d)) * pente / maxf(l, 1.0e-6) + 1.0, 80.0)]


# une paroi qu'on ne passe pas, en p ?
func paroi_en(p: Vector2) -> bool:
	var e := _paroi(p)
	return not e.is_empty() and not bool(e[2])


# un col, en p ? (une rampe dans une paroi)
func col_en(p: Vector2) -> bool:
	var e := _paroi(p)
	return not e.is_empty() and bool(e[2])


# ce que la pente fait à la marche en p : un col se monte lentement
func allure(p: Vector2) -> float:
	return COL_FREIN if col_en(p) else 1.0


# rien ne pousse là : l'eau, le lit d'une rivière, une paroi, un col
func nu(p: Vector2) -> bool:
	return mouille(p) or not _paroi(p, 10.0).is_empty()


# les régions dont le relief compte sur un rectangle : [x, y, force] chacune (au plus 6 ; [] si tout y est plat). Le shader du
# sol en refait la force, comme force()
func reliefs(rect: Rect2) -> Array:
	var p := rect.get_center()
	var q := p + tordre(p)
	var c := Vector2i((q / cote).floor())
	if not _hautes.has(c):
		return []
	var marge := MONTEE + 2.0 * rect.size.length() + 1400.0
	var pres: Array = []
	var d0 := INF
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			for k in _cases.get(Vector2i(x, y), []):
				var d: float = q.distance_to(regions[k]["pos"])
				pres.append([d, k])
				d0 = minf(d0, d)
	pres.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	var du_relief := false
	for e in pres:
		if float(e[0]) - d0 > marge or out.size() >= 6:
			break
		var r: Dictionary = regions[e[1]]
		out.append(Vector3(r["pos"].x, r["pos"].y, float(r["haut"])))
		du_relief = du_relief or float(r["haut"]) > 0.0
	return out if du_relief else []


# --- le contour d'une région, pour la dessiner (la carte du carnet : scripts/interface_carte_monde.gd) ---

# [ses points, dans le lieu (les frontières ondulent comme dans le jeu) ; ses bords : [la voisine, les points de ce bord]]
func contour(i: int) -> Array:
	if _contours.has(i):
		return _contours[i]
	var s: Vector2 = regions[i]["pos"]
	var d := cote * 3.0
	var poly: Array = [s + Vector2(-d, -d), s + Vector2(d, -d), s + Vector2(d, d), s + Vector2(-d, d)]
	var qui: Array = [-1, -1, -1, -1]
	# (sur le plan tordu, la région est ce qui reste quand chaque voisine a coupé sa part)
	for j in regions[i]["voisines"]:
		var t: Vector2 = regions[j]["pos"]
		var m := (s + t) * 0.5
		var nrm := t - s
		var out: Array = []
		var oq: Array = []
		for k in poly.size():
			var a: Vector2 = poly[k]
			var b: Vector2 = poly[(k + 1) % poly.size()]
			var da := (a - m).dot(nrm)
			var db := (b - m).dot(nrm)
			if da <= 0.0:
				out.append(a)
				oq.append(qui[k])
			if (da <= 0.0) != (db <= 0.0):
				out.append(a + (b - a) * (da / (da - db)))
				oq.append(j if da <= 0.0 else qui[k])
		poly = out
		qui = oq
	# chaque bord, coupé en petits pas et ramené du plan tordu au lieu
	var pts := PackedVector2Array()
	var bords: Array = []
	for k in poly.size():
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % poly.size()]
		var pas := maxi(1, int(ceil(a.distance_to(b) / 700.0)))
		var bord := PackedVector2Array()
		for u in pas + 1:
			var q: Vector2 = a.lerp(b, float(u) / pas)
			var p := q - tordre(q - tordre(q))
			bord.append(p)
			if u < pas:
				pts.append(p)
		bords.append([int(qui[k]), bord])
	_contours[i] = [pts, bords]
	return _contours[i]
