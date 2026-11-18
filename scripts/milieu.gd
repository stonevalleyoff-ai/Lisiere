extends RefCounted
# Lisière — le milieu de chaque plante (scripts/milieu.gd)
# Orvane dit quelles plantes poussent dans un biome, leur forme, leurs caractères, leur part ; ce fichier dit OÙ, dans le lieu,
# chacune se tient. Trois temps :
#  1. le plan (prevoir) : les places d'un rectangle du lieu, tirées de la graine, des axes du biome et de son sol — jamais de
#     l'herbier, qui change à chaque cycle et arrive parfois après (une partie gardée retrouve ses places par leur rang).
#     Chaque place porte son MILIEU : sous le couvert, en lisière, à découvert ; au pied d'un arbre ; au bord de l'eau, dans
#     la boue ; dans l'herbe, sur le sol nu ; contre un rocher ; au plus sec ; près de ce qui brûle ; au cœur d'un bosquet,
#     seul dans le pré, à la place d'un géant. Les places viennent par groupes (une colonie, une touffe, la ceinture d'une
#     mare), et il y en a plus qu'il n'en faut : c'est l'herbier qui dit lesquelles servent ;
#  2. les règles (FORMES, CARACTERES) : ce que chaque forme et chaque caractère d'Orvane aime ou évite, milieu par milieu,
#     la taille de ses colonies, la place qu'un pied occupe ;
#  3. le réglage (regler) et le tirage (tirer) : à chaque place, une plante est tirée selon sa part ET son goût pour ce
#     milieu ; un poids par plante est réglé une fois par biome pour que, sur tout le lieu, chacune garde sa part d'Orvane
#     dans sa strate. Une place dont aucune plante de l'herbier ne veut reste vide.
# scripts/monde.gd appelle tout ceci (le lieu fermé et le monde ouvert) ; scripts/recensement.gd compte ce qui en sort.

const R := preload("res://scripts/regles.gd")
const Decor := preload("res://scripts/decor.gd")
const Flore := preload("res://scripts/flore.gd")

# --- les milieux (un bit chacun : une place en porte plusieurs) ---
const SOUS := 1            # sous le couvert : un tronc à moins de COUVERT pixels, ou l'intérieur d'un bosquet
const LISIERE := 2         # au bord d'un bosquet : le couvert tombe
const DECOUVERT := 4       # à découvert : ni l'un ni l'autre
const PIED := 8            # au pied même d'un arbre
const RIVE := 16           # au bord de l'eau : la ceinture d'une mare, d'une fondrière, la berge d'une rivière, d'un lac
const BOUE := 32           # sur un sol boueux
const HERBE := 64          # dans l'herbe
const NU := 128            # sur le sol nu : ni herbe ni boue (la terre, le caillou, le sable)
const PIERRE := 256        # contre un rocher
const SEC := 512           # au plus sec du lieu : une butte, une dune
const FEU := 1024          # près de ce qui brûle : une fumerolle, une faille, des scories
const NEIGE := 2048        # sous la neige
const COEUR := 4096        # (un arbre) au cœur d'un bosquet ; (une mare) son milieu, l'eau la plus profonde
const ISOLE := 8192        # (un arbre) seul, loin des bosquets
const TRONE := 16384       # (un arbre) la place d'un géant : au cœur, rien autour
const EN_PLUS := 32768     # une place offerte en plus (une ceinture, un pied d'arbre, un rocher) : sans herbier, elle reste vide
const CREUX := 65536       # dans un creux du terrain : là où l'eau vient d'abord quand elle monte (scripts/climat.gd, relief)
const LIBRE := 131072      # (le sol) aucune autre plante à moins de R.MILIEU_LIBRE pixels : la place de qui boit toute l'eau autour
const MILIEUX := 1048575   # (le masque des milieux ; au-dessus : le rang dans le groupe, 4 bits, puis sa taille, 4 bits)
const RANG := 20
const TAILLE := 24
const NOMS := {SOUS: "sous le couvert", LISIERE: "en lisière", DECOUVERT: "à découvert", PIED: "au pied d'un arbre", RIVE: "au bord de l'eau",
	BOUE: "dans la boue", HERBE: "dans l'herbe", NU: "sur le sol nu", PIERRE: "contre un rocher", SEC: "au plus sec", FEU: "près de ce qui brûle",
	NEIGE: "sous la neige", COEUR: "au cœur", ISOLE: "isolé", TRONE: "à la place d'un géant", CREUX: "dans un creux", LIBRE: "à l'écart des autres"}

# --- les règles : ce que chaque forme d'Orvane aime (plus de 1) ou évite (moins de 1), milieu par milieu (une entrée par
# ligne). « ailleurs » : ce qui lui reste hors des milieux qu'elle aime (0 : jamais) ; « groupe » : la taille de ses colonies
# (1 : seule) ; « place » : la place qu'un pied tient dans le lieu (un géant vaut plusieurs arbres : sa part d'Orvane est une
# part du couvert, pas un nombre de pieds) ---
const FORMES := {
	# les arbres
	"arbre": {COEUR: 2.0, ISOLE: 0.45},                                  # l'arbre de fond : il fait le bosquet
	"pionnier": {LISIERE: 4.0, ISOLE: 3.0, COEUR: 0.2, FEU: 2.0},        # le bouleau : la lisière, la clairière, le brûlis
	"fruitier": {LISIERE: 3.5, ISOLE: 2.5, COEUR: 0.25},                 # de la lumière : au bord du bois, dans le pré
	"geant": {TRONE: 60.0, "ailleurs": 0.0, "place": R.MILIEU_GEANT},    # rare, au cœur, de la place autour
	"emergent": {TRONE: 60.0, "ailleurs": 0.0, "place": R.MILIEU_GEANT}, # il dépasse la canopée : comme le géant
	"figuier": {COEUR: 2.0, TRONE: 2.0, RIVE: 1.5},                      # il s'appuie sur les grands arbres
	"bouteille": {ISOLE: 4.0, SEC: 2.0, COEUR: 0.2},                     # le baobab : seul, au sec
	"sous_bois": {COEUR: 4.0, LISIERE: 0.5, ISOLE: 0.05},                # l'arbre d'ombre, sous les autres
	"palmier": {RIVE: 3.0, ISOLE: 2.0, LISIERE: 1.5},                    # l'oasis, la rive, la plage
	"paletuvier": {RIVE: 30.0, BOUE: 5.0, "ailleurs": 0.02},             # les pieds dans l'eau
	"fougere_arbre": {COEUR: 3.0, BOUE: 1.5, CREUX: 1.5, ISOLE: 0.1},    # l'ombre humide
	"conifere": {COEUR: 1.6, NEIGE: 1.5, PIERRE: 1.3},                   # la sapinière, serrée
	# les buissons
	"buisson": {LISIERE: 2.5, DECOUVERT: 1.2, SOUS: 0.6, "groupe": 2},   # le fourré, au bord du bois
	"baies": {LISIERE: 3.0, SOUS: 1.5, CREUX: 1.2, "groupe": 3},         # les myrtilles : la lisière, le sous-bois clair
	"epine": {DECOUVERT: 2.0, LISIERE: 1.5, SEC: 1.5, SOUS: 0.2, "groupe": 2},     # la haie d'épines, au soleil
	"ronce": {LISIERE: 5.0, DECOUVERT: 0.8, SOUS: 0.4, "groupe": 3},     # le roncier ferme la lisière
	"aromatique": {DECOUVERT: 2.0, NU: 2.0, PIERRE: 1.5, SEC: 1.5, SOUS: 0.1, "groupe": 2},   # la garrigue : au sec, sur le caillou
	"bruyere": {DECOUVERT: 2.5, NU: 2.0, HERBE: 0.6, SOUS: 0.2, "groupe": 4},      # la lande : des nappes, à découvert
	"liane": {PIED: 40.0, "ailleurs": 0.02},                             # sur les grands arbres
	# le sol
	"herbe": {DECOUVERT: 1.5, HERBE: 1.5, SOUS: 0.5, NEIGE: 0.5, "groupe": 2},
	"cereale": {DECOUVERT: 2.0, HERBE: 2.0, SOUS: 0.15, BOUE: 0.5, NEIGE: 0.3, "groupe": 4},   # des taches dans l'herbe
	"grande_herbe": {DECOUVERT: 2.0, HERBE: 1.5, RIVE: 1.5, CREUX: 1.5, SOUS: 0.3, "groupe": 3},   # la prairie haute, les fonds frais
	"legumineuse": {LISIERE: 2.5, DECOUVERT: 1.3, HERBE: 1.3, SOUS: 0.6, "groupe": 2},        # la clairière, l'ourlet du bois
	"fougere": {SOUS: 5.0, PIED: 2.0, LISIERE: 2.0, CREUX: 1.5, "ailleurs": 0.08, "groupe": 3},   # l'ombre, l'humide
	"mousse": {SOUS: 5.0, PIED: 3.0, BOUE: 1.5, CREUX: 1.5, "ailleurs": 0.08, "groupe": 3},   # en tapis, au pied des troncs
	"coussin": {NU: 3.0, PIERRE: 3.0, SEC: 1.5, HERBE: 0.4, CREUX: 0.5, SOUS: 0.05, NEIGE: 0.5, "ailleurs": 0.3, "groupe": 2},   # le sol nu, le vent des buttes
	"lichen": {PIERRE: 6.0, NU: 2.0, SOUS: 0.3, NEIGE: 0.5, "ailleurs": 0.25, "groupe": 3},   # sur la pierre
	"lichen_croute": {PIERRE: 10.0, NU: 1.5, NEIGE: 0.5, "ailleurs": 0.15, "groupe": 3},      # la croûte : la roche même
	"lichen_rennes": {NU: 2.5, DECOUVERT: 1.5, SOUS: 0.5, "ailleurs": 0.4, "groupe": 4},      # en tapis, à découvert
	"succulente": {NU: 3.0, PIERRE: 2.0, SEC: 1.5, CREUX: 0.5, SOUS: 0.05, BOUE: 0.02},       # seule, entre les pierres
	"agave": {NU: 3.0, SEC: 2.0, CREUX: 0.5, SOUS: 0.05, BOUE: 0.02, "groupe": 2},            # la rosette et son rejet
	"cactus": {NU: 3.0, SEC: 2.5, LIBRE: 5.0, CREUX: 0.4, SOUS: 0.03, BOUE: 0.01},            # seul : ses racines prennent toute l'eau autour
	"caillou": {PIERRE: 10.0, NU: 2.0, "ailleurs": 0.1, "groupe": 3},                         # la plante-caillou, parmi les cailloux
	"roseau": {RIVE: 12.0, BOUE: 2.5, "ailleurs": 0.02, "groupe": 6},                         # la roselière : la ceinture des eaux, la boue
	"jonc": {RIVE: 5.0, BOUE: 5.0, CREUX: 3.0, "ailleurs": 0.03, "groupe": 3},                # la boue, le bord, les fonds mouillés
	"riz": {RIVE: 14.0, "ailleurs": 0.01, "groupe": 4},                                       # les pieds dans l'eau, et nulle part ailleurs
	"papyrus": {RIVE: 14.0, "ailleurs": 0.01, "groupe": 3},                                   # la touffe au bord de l'eau
	"bambou": {LISIERE: 3.0, BOUE: 2.5, CREUX: 2.0, RIVE: 1.5, SOUS: 1.2, "ailleurs": 0.25, "groupe": 4},   # le fourré de bambous, au frais
	"fleur": {DECOUVERT: 1.5, HERBE: 2.5, SOUS: 0.3, "groupe": 3},                            # des taches dans l'herbe
	"bulbe": {LISIERE: 2.5, SOUS: 1.3, HERBE: 1.5, "groupe": 3},                              # des touffes, à l'ourlet du bois
	"orchidee": {PIED: 6.0, SOUS: 4.0, "ailleurs": 0.1},
	"bromelia": {PIED: 8.0, SOUS: 3.0, "ailleurs": 0.1, "groupe": 2},
	# l'eau (une mare : son milieu est profond, ses bords ne le sont pas)
	"nenuphar": {COEUR: 6.0, "ailleurs": 0.3, "groupe": 9},              # enraciné au fond, là où l'eau est profonde
	"lentille": {COEUR: 0.25, SOUS: 2.5, "groupe": 9},                   # l'eau morte des bords, à l'ombre
	"algue": {"groupe": 9},                                              # partout où il y a de l'eau
}
# ce que chaque caractère d'Orvane y ajoute (les mêmes clés ; « groupe » : ce qu'il ajoute à la colonie ; « place » : ce qu'il
# multiplie)
const CARACTERES := {
	"rapide": {LISIERE: 1.6, ISOLE: 1.4, DECOUVERT: 1.3},                # pionnière : la lisière, la clairière
	"vent": {ISOLE: 1.5, DECOUVERT: 1.3, SOUS: 0.7},                     # elle tient au vent : à découvert
	"echasses": {RIVE: 6.0, BOUE: 3.0, CREUX: 2.0},                      # des racines-échasses : les pieds dans l'eau
	"racines_profondes": {SEC: 3.0, RIVE: 0.6, CREUX: 0.7},              # elle va chercher l'eau : au plus sec
	"pyrophyte": {FEU: 6.0},                                             # elle aime le feu : près de ce qui brûle
	"geante": {TRONE: 6.0, ISOLE: 1.5, "place": 1.5},                    # plus grande que les siennes : de la place
	"naine": {DECOUVERT: 1.4, PIERRE: 1.3, COEUR: 0.6},                  # basse : à découvert, entre les pierres
	"fruits_charnus": {LISIERE: 1.5},                                    # les oiseaux la sèment en lisière
	"graines_abondantes": {"groupe": 2},                                 # elle se ressème : des colonies
	"bulbe": {"groupe": 1},                                              # elle se divise : des touffes
	"coriace": {NU: 1.3, SEC: 1.2, PIERRE: 1.2},                         # elle tient sur un sol pauvre
	"mellifere": {HERBE: 1.2, LISIERE: 1.2},                             # au soleil, parmi les fleurs
}
# les strates où une place dont l'herbier ne veut pas reste vide (les arbres, eux, tiennent toutes leurs places : le bois)
const ECLAIRCIES := ["buisson", "sol", "eau"]
# les peuplements : la taille d'une cellule (pixels), et la part des places qui y tirent la plante de la cellule
const COHESION := {"arbre": [R.MILIEU_PEUPLEMENT, R.MILIEU_COHESION_ARBRES], "buisson": [220.0, 0.4], "sol": [170.0, 0.25]}


# --- ce qu'une plante de l'herbier aime ---

static func _selon(regle: Dictionary, milieu: int) -> float:
	var a := 1.0
	var chez_elle := false
	for k in regle:
		if typeof(k) == TYPE_INT and milieu & int(k):
			var w := float(regle[k])
			a *= w
			if w > 1.0:
				chez_elle = true
	if not chez_elle and regle.has("ailleurs"):
		a *= float(regle["ailleurs"])
	return a


# son goût pour un milieu (1 : indifférente ; 0 : jamais) : celui de sa forme, fois celui de chacun de ses caractères
static func affinite(pl: Dictionary, milieu: int) -> float:
	var a := _selon(FORMES.get(str(pl.get("forme", "")), {}), milieu)
	var car = pl.get("caracteres", [])
	if typeof(car) == TYPE_ARRAY:
		for c in car:
			if CARACTERES.has(c):
				a *= _selon(CARACTERES[c], milieu)
	return a


# la taille de ses colonies (1 : seule)
static func groupe(pl: Dictionary) -> int:
	var n := int(FORMES.get(str(pl.get("forme", "")), {}).get("groupe", 1))
	var car = pl.get("caracteres", [])
	if typeof(car) == TYPE_ARRAY and n < 9:
		for c in car:
			n += int(CARACTERES.get(c, {}).get("groupe", 0))
		n = mini(n, R.MILIEU_GROUPE)
	return maxi(1, n)


# la place qu'un pied tient (un arbre : 1 ; un géant : plusieurs)
static func place(pl: Dictionary) -> float:
	var k := float(FORMES.get(str(pl.get("forme", "")), {}).get("place", 1.0))
	var car = pl.get("caracteres", [])
	if typeof(car) == TYPE_ARRAY and str(pl.get("genre", "")) in ["arbre", "sapin"]:
		for c in car:
			k *= float(CARACTERES.get(c, {}).get("place", 1.0))
	return k


# un milieu, dans un lieu sans arbres (leur strate manque à l'herbier) : ni couvert, ni lisière, ni cœur
static func sans_arbres(milieu: int) -> int:
	return (milieu & ~(SOUS | LISIERE | PIED | COEUR | ISOLE | TRONE)) | DECOUVERT


static func rang(milieu: int) -> int:
	return (milieu >> RANG) & 15


static func taille(milieu: int) -> int:
	return (milieu >> TAILLE) & 15


static func dire(milieu: int) -> String:
	var mots: Array = []
	for k in NOMS:
		if milieu & int(k):
			mots.append(NOMS[k])
	return ", ".join(mots)


# --- le réglage : un poids par plante, pour que chacune garde sa part d'Orvane sur tout le lieu ---

# l'échantillon d'un plan : par strate, combien de groupes de chaque sorte (son milieu et sa taille : milieu | taille << TAILLE)
static func echantillon(plan: Array) -> Dictionary:
	var out := {"arbre": {}, "buisson": {}, "sol": {}, "eau": {}}
	for e in plan:
		if e.size() < 6 or int(e[5]) < 0:
			continue
		var strate := _strate(str(e[0]))
		if not out.has(strate):
			continue
		var m := int(e[5])
		# (une mare : chaque plante d'eau compte, le milieu et les bords n'ont pas le même milieu ; ailleurs, un groupe compte
		# une fois, par sa première place)
		var cle := (m & MILIEUX) | (1 << TAILLE) if strate == "eau" else m & ~(15 << RANG)
		if strate != "eau" and rang(m) != 0:
			continue
		out[strate][cle] = int(out[strate].get(cle, 0)) + 1
	return out


static func _strate(genre: String) -> String:
	match genre:
		"arbre", "sapin":
			return "arbre"
		"buisson":
			return "buisson"
		"touffe", "sol":
			return "sol"
		"eau":
			return "eau"
	return ""


# règle les poids d'une flore sur un échantillon. cibles : { strate: combien de plantes on veut sur l'échantillon } (les
# arbres : toutes leurs places). Rend { strate: { plantes, poids, tailles, eclaircie, cache } } ; les places d'arbres et de
# buissons d'un herbier sans arbres ni buissons reviennent aux plantes du sol (monde.gd, _poser).
static func regler(flore: Dictionary, ech: Dictionary, cibles: Dictionary) -> Dictionary:
	var tables := {}
	var boise := flore.has("arbre")
	for strate in ["arbre", "buisson", "sol", "eau"]:
		if not flore.has(strate):
			continue
		var L: Array = flore[strate]
		var n := L.size()
		# les sortes de places de cette strate : [milieu, taille du groupe, combien]
		var sortes: Array = []
		var cumul := {}
		var sources: Array = [strate]
		if strate == "sol":
			for autre in ["arbre", "buisson"]:
				if not flore.has(autre):
					sources.append(autre)
		for src in sources:
			for cle in ech.get(src, {}):
				var m := int(cle) & MILIEUX
				var t := maxi(1, taille(int(cle)))
				if src != strate:
					# (une place d'arbre devient celle d'une plante du sol, seule)
					m = sans_arbres(m) if src == "arbre" else m
					t = 1 if src == "arbre" else t
				if not boise:
					m = sans_arbres(m)
				var k := m | (t << TAILLE)
				cumul[k] = int(cumul.get(k, 0)) + int(ech[src][cle])
		for k in cumul:
			sortes.append([int(k) & MILIEUX, taille(int(k)), int(cumul[k])])
		# ce qu'on veut de chacune : sa part, divisée par la place qu'un pied tient
		var parts := PackedFloat32Array()
		var tailles := PackedInt32Array()
		var somme := 0.0
		for pl in L:
			var x := float(pl["poids"]) / place(pl)
			parts.append(x)
			somme += x
			tailles.append(1 if strate == "arbre" else groupe(pl))
		var eclaircie := ECLAIRCIES.has(strate)
		var total := float(cibles.get(strate, -1.0))
		if total < 0.0 or not eclaircie:
			total = 0.0
			for so in sortes:
				total += float(so[2])
		# le goût de chacune pour chaque sorte de place
		var gouts: Array = []
		for so in sortes:
			var g := PackedFloat32Array()
			for pl in L:
				g.append(affinite(pl, int(so[0])))
			gouts.append(g)
		var poids := PackedFloat32Array()
		for i in n:
			poids.append(parts[i] / maxf(0.0001, somme))
		# (de proche en proche : chaque poids monte ou descend jusqu'à ce que la plante ait sa part ; il ne monte pas sans fin,
		# pour qu'une plante sans milieu dans ce lieu n'aille pas se poser n'importe où)
		if not sortes.is_empty() and total > 0.0:
			var eu := PackedFloat32Array()
			eu.resize(n)
			for tour in R.MILIEU_TOURS:
				eu.fill(0.0)
				for j in sortes.size():
					var g: PackedFloat32Array = gouts[j]
					var s := 0.0
					for i in n:
						s += poids[i] * g[i]
					if s <= 0.0:
						continue
					var combien := float(sortes[j][2]) * (minf(1.0, s) if eclaircie else 1.0) / s
					var tg := int(sortes[j][1])
					for i in n:
						eu[i] += combien * poids[i] * g[i] * float(mini(tailles[i], tg))
				for i in n:
					var veut := total * parts[i] / maxf(0.0001, somme)
					if eu[i] > 0.0:
						poids[i] = clampf(poids[i] * pow(veut / eu[i], 0.7), 0.00001, R.MILIEU_POIDS_MAX * parts[i] / maxf(0.0001, somme))
		tables[strate] = {"plantes": L, "poids": poids, "tailles": tailles, "eclaircie": eclaircie, "cache": {}, "boise": boise}
	return tables


# la plante d'une place ({} : la place reste vide). k : le tirage du groupe (le reste de sa graine, modulo 10 007 : toutes les
# places d'un groupe ont le même) ; k_cellule : celui de la cellule où elle est (un peuplement), ou -1
static func tirer(tb: Dictionary, milieu: int, k: int, k_cellule: int = -1) -> Dictionary:
	var m := milieu & MILIEUX
	if not bool(tb["boise"]):
		m = sans_arbres(m)
	var cache: Dictionary = tb["cache"]
	var c = cache.get(m)
	if c == null:
		# (les poids cumulés de chaque plante dans ce milieu, puis leur somme)
		var L: Array = tb["plantes"]
		var poids: PackedFloat32Array = tb["poids"]
		var cum := PackedFloat32Array()
		var s := 0.0
		for i in L.size():
			s += poids[i] * affinite(L[i], m)
			cum.append(s)
		c = cum
		cache[m] = c
	var cum: PackedFloat32Array = c
	var s: float = cum[cum.size() - 1] if not cum.is_empty() else 0.0
	if s <= 0.0:
		return {}
	# (une place dont l'herbier veut peu reste souvent vide : le même tirage pour tout le groupe)
	if bool(tb["eclaircie"]) and s < 1.0 and float(absi(hash(k + 77003)) % 10007) / 10007.0 >= s:
		return {}
	var x := float(k_cellule if k_cellule >= 0 else k) / 10007.0 * s
	var i := 0
	while i < cum.size() - 1 and x >= cum[i]:
		i += 1
	if rang(milieu) >= int(tb["tailles"][i]):
		return {}
	return tb["plantes"][i]


# le tirage de la cellule où est p (un peuplement : les places qui s'y rangent tirent la même plante), ou -1 si cette place
# tire pour elle-même. Les cellules ondulent, pour que les peuplements n'aient pas de bords droits.
static func cellule(strate: String, p: Vector2, k: int, milieu: int, graine: int) -> int:
	var c = COHESION.get(strate)
	if c == null or milieu & (TRONE | RIVE | PIED | PIERRE):
		return -1
	if float(k % 100) >= float(c[1]) * 100.0:
		return -1
	var cote: float = c[0]
	var q := p + Vector2(sin(p.y / (cote * 0.37)), sin(p.x / (cote * 0.43))) * cote * 0.22
	# (d'une cellule à sa voisine le tirage avance d'un pas qui ne retombe jamais sur lui-même : sur un grand lieu, les cellules
	# se partagent toutes les plantes à leur part, et deux voisines n'ont pas la même)
	var u: float = floor(q.x / cote) * 0.7548776662 + floor(q.y / cote) * 0.5698402910 + float(absi(graine + strate.length() * 7919) % 1000) / 1000.0
	return int((u - floor(u)) * 10007.0) % 10007


# --- la météo d'Orvane : ce qu'elle fait aux densités (1 : rien) ---

# { sol, buisson, eau, fleurs, champignons } d'après la météo du biome ce cycle (production, secheresse, eaux, e : l'humidité)
static func densites(meteo: Dictionary) -> Dictionary:
	if meteo.is_empty():
		return {"sol": 1.0, "buisson": 1.0, "eau": 1.0, "fleurs": 1.0, "champignons": 1.0}
	var vigueur := clampf(float(meteo.get("production", 1.0)), 0.6, 1.3)
	var seche := clampf(float(meteo.get("secheresse", 0.0)), 0.0, 1.0)
	var eaux := clampf(float(meteo.get("eaux", 0.0)), 0.0, 1.0)
	var humide := clampf(float(meteo.get("e", 0.0)), -1.0, 1.0)
	return {
		"sol": clampf(vigueur * (1.0 - R.MILIEU_SECHERESSE_SOL * seche), 0.5, 1.3),
		"buisson": clampf(vigueur * (1.0 - R.MILIEU_SECHERESSE_BUISSONS * seche) * (1.0 + 0.15 * humide), 0.6, 1.3),
		"eau": clampf(R.MILIEU_EAUX_FOND + R.MILIEU_EAUX * eaux - 0.3 * seche, 0.6, R.MILIEU_MARES_RESERVE),
		"fleurs": clampf(vigueur * (1.0 - 0.6 * seche), 0.5, R.MILIEU_CUEILLETTE_RESERVE),
		"champignons": clampf(1.0 + 0.5 * humide + 0.3 * eaux - 0.4 * seche, 0.5, R.MILIEU_CUEILLETTE_RESERVE),
	}


# combien de plantes on veut sur une surface, par strate (les buissons, le sol, l'eau ; les arbres tiennent toutes leurs places)
static func cibles(mesures: Array, s: Dictionary, aire: float, meteo: Dictionary, ech: Dictionary, flore: Dictionary) -> Dictionary:
	var ka := aire / (4.0 * R.DEMI * R.DEMI)
	var d := densites(meteo)
	var couvert := float(mesures[0])
	var sol := sol_voulu(couvert) * ka * float(d["sol"])
	# (les places d'arbres et de buissons d'un lieu sans arbres ni buissons : autant de plantes du sol en plus)
	for autre in ["arbre", "buisson"]:
		if not flore.has(autre):
			for cle in ech.get(autre, {}):
				sol += float(ech[autre][cle]) * (1.0 if autre == "arbre" else float(d["sol"]))
	return {
		"buisson": (R.BUISSONS + R.BUISSONS_HUMIDE * float(mesures[1])) * ka * float(d["buisson"]),
		"sol": sol,
		"eau": (R.MILIEU_MARES + R.MILIEU_MARES_BOUE * float(s["boue"])) * ka * float(d["eau"]),
	}


# les plantes du sol d'un lieu (4 200 pixels de côté), d'après son couvert
static func sol_voulu(couvert: float) -> float:
	return R.MILIEU_SOL + R.MILIEU_SOL_DECOUVERT * (1.0 - couvert)


# --- le plan : les places d'un rectangle, et leur milieu ---

# une petite grille pour retrouver vite ce qui est près d'un point
static func _ranger(g: Dictionary, p: Vector2, x = null) -> void:
	var k := Vector2i((p / 96.0).floor())
	if not g.has(k):
		g[k] = []
	g[k].append([p, x])


# la distance de p au plus proche point rangé, à moins de « rayon » (INF sinon) ; ovale : compte les hauteurs deux fois
static func _vers(g: Dictionary, p: Vector2, rayon: float) -> float:
	if g.is_empty():
		return INF
	var d := INF
	var a := Vector2i(((p - Vector2(rayon, rayon)) / 96.0).floor())
	var b := Vector2i(((p + Vector2(rayon, rayon)) / 96.0).floor())
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for e in g.get(Vector2i(x, y), []):
				d = minf(d, p.distance_to(e[0]))
	return d if d <= rayon else INF


# le couvert en p, de 0 à 1 : la chance qu'un arbre y pousse (le bruit des bosquets, plus le couvert du biome)
static func couvert_en(ctx: Dictionary, p: Vector2) -> float:
	var b = ctx.get("bosquets")
	var v: float = b.get_noise_2d(p.x, p.y) if b != null else 0.0
	return clampf((0.25 + float(ctx["mesures"][0])) * 0.5 + v * 0.9, 0.0, 1.0)


# la distance de p au bord de la mare la plus proche (négative : dedans ; INF : aucune près)
static func _vers_mare(mares: Array, p: Vector2) -> float:
	var d := INF
	for m in mares:
		var c: Vector2 = m[0]
		var rx: float = m[1]
		if absf(p.x - c.x) > rx + 80.0 or absf(p.y - c.y) > rx + 80.0:
			continue
		d = minf(d, ((p - c) * Vector2(1.0, 1.0 / R.MILIEU_OVALE)).length() - rx)
	return d


# les places de géants près d'un rectangle : une trame de cellules, un site au plus par cellule, là où le couvert est épais
# (le même calcul partout : un morceau sait où sont les géants de son voisin, et leur laisse la place)
static func trones(ctx: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var cote: float = R.MILIEU_TRONES
	var marge: float = R.MILIEU_DEGAGE
	var a := Vector2i(((rect.position - Vector2(marge, marge)) / cote).floor())
	var b := Vector2i(((rect.end + Vector2(marge, marge)) / cote).floor())
	var graine: int = ctx["graine"]
	var borne: float = float(ctx.get("borne", 0.0))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var h := absi(hash(Vector3i(x, y, graine + 4099)))
			var q := (Vector2(x, y) + Vector2(0.2 + 0.6 * float(h % 1000) / 1000.0, 0.2 + 0.6 * float((h / 1000) % 1000) / 1000.0)) * cote
			if q.length() < 300.0 or (borne > 0.0 and (absf(q.x) > borne - 60.0 or absf(q.y) > borne - 60.0)):
				continue
			if couvert_en(ctx, q) < R.MILIEU_TRONE_COUVERT or _noye(ctx, q):
				continue
			# (son tirage avance d'une cellule à l'autre, comme celui des peuplements : les géants ont leur part au plus juste)
			var u: float = x * 0.7548776662 + y * 0.5698402910 + float(absi(graine) % 1000) / 1000.0
			out.append([q, (h % 100000) * 10007 + int((u - floor(u)) * 10007.0) % 10007])
	return out


# le relief en p, de 0 (un creux) à 1 (une butte) : le même que celui du temps qu'il fait (scripts/climat.gd, relief), où l'eau
# d'une crue gagne d'abord les creux ; ctx["relief"] : son bruit (rien : tout est plat)
static func relief_en(ctx: Dictionary, p: Vector2) -> float:
	var b = ctx.get("relief")
	if b == null:
		return 0.5
	return clampf(b.get_noise_2d(p.x, p.y) * 0.5 + 0.5 + 0.4 * exp(-p.length_squared() / (280.0 * 280.0)), 0.0, 1.0)


# le niveau de l'eau qui reste dans les creux d'un lieu détrempé (un marais), sur l'échelle du relief (-1 : il n'en reste pas) ;
# ctx["crue"] : la crue de fond du biome (scripts/climat.gd, crue_fond)
static func niveau(ctx: Dictionary) -> float:
	var crue := float(ctx.get("crue", 0.0))
	return lerpf(0.26, 0.5, crue) if crue > 0.01 else -1.0


# le milieu du sol en p : le couvert (arbres : la grille des arbres du rectangle), l'herbe, la boue, la neige, le sec, la pierre,
# la rive
static func _milieu_du_sol(ctx: Dictionary, p: Vector2, arbres: Dictionary, rochers: Dictionary, mares: Array) -> int:
	var m := 0
	var c := couvert_en(ctx, p)
	if c >= R.MILIEU_BOSQUET or _vers(arbres, p, R.MILIEU_COUVERT) < INF:
		m |= SOUS
	elif c >= R.MILIEU_LISIERE:
		m |= LISIERE
	else:
		m |= DECOUVERT
	m |= _sol(ctx, p)
	if _vers(rochers, p, R.MILIEU_ROCHER) < INF:
		m |= PIERRE
	if _vers_mare(mares, p) < R.MILIEU_RIVE or _au_bord(ctx, p):
		m |= RIVE
	if _brule(ctx, p):
		m |= FEU
	return m


# ce que le sol est en p : herbeux, boueux, nu ; enneigé ; dans un creux, au plus sec (une butte du terrain, une dune) ; sur la
# rive de l'eau qui reste dans les creux
static func _sol(ctx: Dictionary, p: Vector2) -> int:
	var t: Dictionary = ctx["t"]
	var m := 0
	if t.is_empty():
		m = HERBE
	else:
		var ici := Decor.sol_ici(t, ctx["s"], p)
		if float(ici["boue"]) > 0.5:
			m |= BOUE
		elif float(ici["herbe"]) > 0.45:
			m |= HERBE
		else:
			m |= NU
		if float(ici["neige"]) > 0.4:
			m |= NEIGE
	var h := relief_en(ctx, p)
	var eau := niveau(ctx)
	if h < R.MILIEU_CREUX:
		m |= CREUX
	elif not (m & BOUE) and (h > R.MILIEU_BUTTE or _sur_une_dune(ctx, p)):
		m |= SEC
	if eau > 0.0 and h < eau + R.MILIEU_RIVAGE:
		m |= RIVE
	return m


# p est-il dans l'eau qui reste dans les creux (à plus de « marge » de sa rive, sur l'échelle du relief) ?
static func _noye(ctx: Dictionary, p: Vector2, marge: float = 0.0) -> bool:
	var eau := niveau(ctx)
	return eau > 0.0 and relief_en(ctx, p) < eau - marge


# (le monde ouvert) p est-il sur la berge d'une rivière, la rive d'un lac ? ctx["berges"] : les points d'eau trouvés près du
# rectangle (rien : pas d'eau près)
static func _au_bord(ctx: Dictionary, p: Vector2) -> bool:
	for q in ctx.get("berges", []):
		if p.distance_squared_to(q) < R.MILIEU_BERGE * R.MILIEU_BERGE:
			return true
	for e in ctx.get("eaux", []):
		var d: Vector2 = (p - e[0]) * Vector2(1.0, 1.0 / 0.82)
		if d.length() < float(e[1]) + R.MILIEU_RIVE:
			return true
	return false


# p est-il près de ce qui brûle ? (ctx["feux"] : les fumerolles, les failles, les scories du pays : [où, jusqu'où])
static func _brule(ctx: Dictionary, p: Vector2) -> bool:
	for e in ctx.get("feux", []):
		if p.distance_to(e[0]) < float(e[1]):
			return true
	return false


static func _sur_une_dune(ctx: Dictionary, p: Vector2) -> bool:
	for e in ctx.get("dunes", []):
		if p.distance_to(e[0]) < float(e[1]):
			return true
	return false


# p est-il dans l'eau d'un pays (une fondrière, une mare gelée) ? Rien n'y pousse
static func _dans_l_eau(ctx: Dictionary, p: Vector2, marge: float = 0.0) -> bool:
	for e in ctx.get("eaux", []):
		var d: Vector2 = (p - e[0]) * Vector2(1.0, 1.0 / 0.82)
		if d.length() < float(e[1]) + marge:
			return true
	return false


# des objets d'un genre, au hasard dans le rectangle, plus serrés là où le bruit est haut ; rien sur le réveil (comme monde.gd,
# _prevoir : les rochers, les brindilles, les herbes de l'herbier de Lisière n'ont pas de milieu)
static func _semis(r: RandomNumberGenerator, plan: Array, rect: Rect2, genre: String, combien: float, ton: String, bruit, densite: float, type: String, sauf: Callable = Callable()) -> Array:
	var n := Decor._nombre(r, combien)
	var poses := 0
	var essais := 0
	var places: Array = []
	while poses < n and essais < n * 12:
		essais += 1
		var p := Decor._dans(r, rect)
		if p.length() < 150.0:
			continue
		if bruit != null:
			var v: float = bruit.get_noise_2d(p.x, p.y)
			if r.randf() > clampf(densite * 0.5 + v * 0.9, 0.04, 1.0):
				continue
		var g := r.randi()
		if sauf.is_valid() and sauf.call(p):
			continue
		plan.append([genre, p, ton, g, type, -1])
		places.append(p)
		poses += 1
	return places


# une graine dont le tirage (son reste, modulo 10 007) suit le précédent d'un pas qui ne retombe jamais sur lui-même : sur un
# grand rectangle, les tirages se répartissent, et chaque plante a sa part au plus juste. suite : [le tirage d'avant]
static func _graine(r: RandomNumberGenerator, suite: Array) -> int:
	suite[0] = (int(suite[0]) + 6185) % 10007
	return (r.randi() % 200000) * 10007 + int(suite[0])


# un groupe de places serrées autour de q (une colonie, une touffe) : la même graine modulo 10 007 (le même tirage), le même
# milieu, leur rang et la taille du groupe
static func _groupe(ctx: Dictionary, r: RandomNumberGenerator, suite: Array, plan: Array, rect: Rect2, genre: String, ton: String, type: String, q: Vector2, milieu: int, n: int, large: float, places: Array = []) -> void:
	var g := _graine(r, suite)
	var ps: Array = []
	for j in n:
		var p := q
		if j < places.size():
			p = places[j]
		elif j > 0:
			p = q + Vector2(r.randf_range(-large, large), r.randf_range(-large, large) * 0.55)
		ps.append(p.clamp(rect.position, rect.end - Vector2(0.01, 0.01)))
	# (aucune ne va au large de l'eau qui reste dans les creux : celle qui y tomberait se serre contre une voisine au sec — la
	# première qui l'est ; un groupe tout entier dans l'eau n'a pas lieu)
	var sur = null
	for p in ps:
		if not _noye(ctx, p, 0.03):
			sur = p
			break
	if sur == null:
		return
	for j in n:
		var p: Vector2 = ps[j]
		if _noye(ctx, p, 0.03):
			p = sur + Vector2(r.randf_range(-3.0, 3.0), r.randf_range(-2.0, 2.0))
		else:
			sur = p
		plan.append([genre, p, ton, g + j * 10007, type, milieu | (j << RANG) | (n << TAILLE)])


# ce qu'un rectangle d'un biome contient : ses mares et leurs ceintures, ses arbres (les géants d'abord), ses rochers, ses
# buissons, ses plantes du sol, son bois mort, ses herbes. ctx : { t (le terrain), s (les parts du sol), mesures (couvert,
# humidité, altitude), bosquets, arbre (« arbre » ou « sapin »), type, graine, borne (un lieu fermé : son demi-côté), et, dans
# le monde ouvert : berges, eaux, feux, dunes (ce que la carte et le pays y mettent) }
static func prevoir(ctx: Dictionary, r: RandomNumberGenerator, rect: Rect2, plan: Array) -> void:
	var s: Dictionary = ctx["s"]
	var t: Dictionary = ctx["t"]
	var type: String = ctx["type"]
	var couvert := float(ctx["mesures"][0])
	var humid := float(ctx["mesures"][1])
	var alt := float(ctx["mesures"][2])
	var bosquets = ctx.get("bosquets")
	var ka := rect.get_area() / (4.0 * R.DEMI * R.DEMI)
	var sec := float(s["sec"])
	var terrain := not t.is_empty()
	var ov: float = R.MILIEU_OVALE
	var suite := [r.randi() % 10007]
	var debut := plan.size()
	# 1. l'eau. Dans un lieu détrempé (un marais), de l'eau reste au creux du terrain : une part des plantes d'eau y va, deux
	# par deux — au large, où elle est profonde ; près du bord. Les autres font des mares : deux à cinq plantes d'eau qui se
	# touchent, celle du milieu au plus profond ; dans la boue de préférence
	var eau := niveau(ctx)
	var n_eau := (R.MILIEU_MARES + R.MILIEU_MARES_BOUE * float(s["boue"])) * R.MILIEU_MARES_RESERVE * ka
	var n := 0
	var essais := 0
	if eau > 0.0:
		n = Decor._nombre(r, n_eau * R.MILIEU_ETANG / 2.0)
		n_eau *= 1.0 - R.MILIEU_ETANG
		essais = n * 10
		while n > 0 and essais > 0:
			essais -= 1
			var q := Decor._dans(r, rect)
			var g := _graine(r, suite)
			var a := r.randf() * TAU
			var h := relief_en(ctx, q)
			if q.length() < 260.0 or h > eau - 0.012 or _dans_l_eau(ctx, q, 30.0):
				continue
			var ombre := SOUS if couvert_en(ctx, q) >= R.MILIEU_BOSQUET else 0
			for j in 2:
				var p := (q + Vector2(cos(a), sin(a) * 0.4) * 34.0 * j).clamp(rect.position, rect.end - Vector2(0.01, 0.01))
				var hp := relief_en(ctx, p)
				if j > 0 and hp > eau - 0.012:
					continue
				plan.append(["eau", p, "feuilles", g + j * 10007, type, (COEUR if hp < eau - R.MILIEU_PROFOND else 0) | ombre | (j << RANG) | (2 << TAILLE)])
			n -= 1
	var mares: Array = []
	n = Decor._nombre(r, n_eau / 3.5)
	essais = n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var combien := 2 + r.randi() % 4
		var chance := r.randf()
		var g := _graine(r, suite)
		var tour := r.randf() * TAU
		if q.length() < 260.0 or _dans_l_eau(ctx, q, 70.0) or (eau > 0.0 and relief_en(ctx, q) < eau + 0.06):
			continue
		if terrain and float(Decor.sol_ici(t, s, q)["boue"]) < 0.5 and chance > 0.3:
			continue
		var anneau := 24.0 if combien <= 3 else 30.0
		var rx := anneau + 20.0
		q = q.clamp(rect.position + Vector2(rx + 4.0, rx * ov + 4.0), rect.end - Vector2(rx + 4.0, rx * ov + 4.0))
		var libre := true
		for m in mares:
			if q.distance_to(m[0]) < rx + float(m[1]) + 40.0:
				libre = false
		if not libre:
			continue
		mares.append([q, rx])
		var ombre := SOUS if couvert_en(ctx, q) >= R.MILIEU_BOSQUET else 0
		for j in combien:
			var p := q
			if j > 0:
				var a := tour + TAU * float(j - 1) / float(combien - 1)
				p = q + Vector2(cos(a) * anneau, sin(a) * anneau * 0.4)
			plan.append(["eau", p, "feuilles", g + j * 10007, type, (COEUR if j == 0 and combien >= 3 else 0) | ombre | (j << RANG) | (combien << TAILLE)])
		n -= 1
	# 2. les arbres : les géants d'abord (leurs places sont les mêmes pour tous les morceaux), puis les autres, plus serrés là
	# où le bruit des bosquets est haut ; jamais à moins d'un tronc d'écart, ni dans une mare, ni sur la place d'un géant
	var arbre: String = ctx["arbre"]
	var arbres := {}
	var liste_arbres: Array = []
	var grands: Array = []
	var sites := trones(ctx, rect)
	for e in sites:
		var q: Vector2 = e[0]
		if rect.has_point(q) and _vers_mare(mares, q) > 14.0 and not _dans_l_eau(ctx, q, 20.0):
			plan.append([arbre, q, "feuilles", int(e[1]), type, TRONE | COEUR | _sol(ctx, q) | (1 << TAILLE)])
			_ranger(arbres, q)
			liste_arbres.append(q)
			grands.append(q)
	n = Decor._nombre(r, (70.0 + 430.0 * couvert) * ka)
	var poses := 0
	# (deux troncs ne se touchent pas ; où il fait sec, ils s'écartent : leurs racines se partagent l'eau)
	var espace := lerpf(R.MILIEU_ESPACE_ARBRES, R.MILIEU_ECART_SEC * 0.8, sec)
	# (au bord des mares, un arbre souvent : la place du palétuvier, de ce qui a des échasses)
	for mare in mares:
		var a := r.randf() * TAU
		var d := r.randf_range(8.0, 18.0)
		var g := _graine(r, suite)
		if r.randf() > R.MILIEU_ARBRES_DE_RIVE or poses >= n:
			continue
		var p: Vector2 = mare[0] + Vector2(cos(a), sin(a) * ov) * (float(mare[1]) + d)
		if not rect.has_point(p) or p.length() < 150.0 or _vers(arbres, p, R.MILIEU_ESPACE_ARBRES) < INF or sites.any(func(e): return p.distance_to(e[0]) < R.MILIEU_DEGAGE):
			continue
		plan.append([arbre, p, "feuilles", g, type, (_sol(ctx, p) & ~SEC) | RIVE | (1 << TAILLE)])
		_ranger(arbres, p)
		liste_arbres.append(p)
		poses += 1
	essais = 0
	while poses < n and essais < n * 12:
		essais += 1
		var p := Decor._dans(r, rect)
		var chance := r.randf()
		if p.length() < 150.0:
			continue
		var c := couvert_en(ctx, p)
		if chance > maxf(c, 0.04) or _noye(ctx, p, 0.008):
			continue
		var d_mare := _vers_mare(mares, p)
		if d_mare < 8.0 or _dans_l_eau(ctx, p, 6.0) or _vers(arbres, p, espace) < INF:
			continue
		var pris := false
		for e in sites:
			if p.distance_to(e[0]) < R.MILIEU_DEGAGE:
				pris = true
				break
		if pris:
			continue
		var m := _sol(ctx, p)
		if c >= R.MILIEU_COEUR:
			m |= COEUR
		elif c < R.MILIEU_ISOLE:
			m |= ISOLE
		elif c < R.MILIEU_LISIERE_ARBRES:
			m |= LISIERE
		if d_mare < R.MILIEU_RIVE_ARBRES or _au_bord(ctx, p):
			m |= RIVE
		if _brule(ctx, p):
			m |= FEU
		plan.append([arbre, p, "feuilles", _graine(r, suite), type, m | (1 << TAILLE)])
		_ranger(arbres, p)
		liste_arbres.append(p)
		poses += 1
	# 3. les rochers (pas dans une mare)
	var rochers := {}
	var liste_rochers: Array = _semis(r, plan, rect, "rocher", (40.0 + 140.0 * alt) * ka, "pierre", null, 1.0, type,
		func(p: Vector2) -> bool: return _vers_mare(mares, p) < 12.0 or _dans_l_eau(ctx, p, 14.0))
	for p in liste_rochers:
		_ranger(rochers, p)
	# 4. les buissons : des fourrés (un groupe de un à quatre), près des bosquets ; et des lianes, au pied des arbres (les géants
	# d'abord)
	n = Decor._nombre(r, (R.BUISSONS + R.BUISSONS_HUMIDE * humid) * R.MILIEU_FOURRES * ka)
	essais = n * 12
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var chance := r.randf()
		var combien := 2 + r.randi() % 3
		if q.length() < 170.0:
			continue
		if bosquets != null and chance > clampf(0.3 + bosquets.get_noise_2d(q.x, q.y) * 0.9, 0.04, 1.0):
			continue
		if _vers_mare(mares, q) < 10.0 or _dans_l_eau(ctx, q, 10.0) or _noye(ctx, q) or _vers(arbres, q, 20.0) < INF:
			continue
		_groupe(ctx, r, suite, plan, rect, "buisson", "feuilles", type, q, _milieu_du_sol(ctx, q, arbres, rochers, mares), combien, 30.0)
		n -= 1
	n = Decor._nombre(r, float(liste_arbres.size()) * R.MILIEU_LIANES * clampf(humid * 1.6 - 0.4, 0.0, 1.0))
	for i in n:
		var pied: Vector2 = grands[i] if i < grands.size() else liste_arbres[r.randi() % liste_arbres.size()]
		var q := pied + Vector2((1.0 if r.randf() < 0.5 else -1.0) * r.randf_range(9.0, 14.0), r.randf_range(2.0, 5.0))
		if q.length() < 170.0 or not rect.has_point(q):
			continue
		_groupe(ctx, r, suite, plan, rect, "buisson", "feuilles", type, q, SOUS | PIED | EN_PLUS | _sol(ctx, q), 1, 0.0)
	# 5. les plantes du sol, par groupes : le fond du lieu (plus espacé où il fait sec : les racines se partagent l'eau) ; puis
	# ce qui est offert en plus à qui l'aime — le pied des arbres, le tour des rochers, la ceinture des mares, les berges
	var ecart := lerpf(R.MILIEU_ECART, R.MILIEU_ECART_SEC, sec)
	var centres := {}
	n = Decor._nombre(r, sol_voulu(couvert) * R.MILIEU_TOUFFES * ka)
	essais = n * 8
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var combien := r.randi_range(3, R.MILIEU_GROUPE)
		if q.length() < 170.0 or _vers(centres, q, ecart) < INF or _vers(arbres, q, ecart * 0.8) < INF or _vers_mare(mares, q) < 6.0 or _dans_l_eau(ctx, q, 4.0) or _noye(ctx, q, 0.012):
			continue
		_ranger(centres, q)
		_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, q, _milieu_du_sol(ctx, q, arbres, rochers, mares), combien, lerpf(22.0, 30.0, sec))
		n -= 1
	n = Decor._nombre(r, float(liste_arbres.size()) * R.MILIEU_SOUS_BOIS)
	for i in n:
		var pied: Vector2 = liste_arbres[r.randi() % liste_arbres.size()]
		var q := pied + Vector2.from_angle(r.randf() * TAU) * r.randf_range(18.0, 40.0) * Vector2(1.0, 0.6)
		var combien := r.randi_range(2, 5)
		if q.length() < 170.0 or not rect.has_point(q) or _vers_mare(mares, q) < 6.0 or _dans_l_eau(ctx, q, 4.0) or _noye(ctx, q, 0.012):
			continue
		_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, q, (_milieu_du_sol(ctx, q, arbres, rochers, mares) & ~(LISIERE | DECOUVERT)) | SOUS | PIED | EN_PLUS, combien, 16.0)
	n = Decor._nombre(r, float(liste_rochers.size()) * R.MILIEU_AU_ROCHER)
	for i in n:
		var roc: Vector2 = liste_rochers[r.randi() % liste_rochers.size()]
		var combien := r.randi_range(2, 5)
		var tour := r.randf() * TAU
		var autour: Array = []
		for j in combien:
			autour.append(roc + Vector2.from_angle(tour + j * r.randf_range(0.7, 1.3)) * r.randf_range(19.0, 31.0) * Vector2(1.0, 0.6))
		if autour[0].length() < 170.0 or not rect.has_point(autour[0]) or _dans_l_eau(ctx, autour[0], 4.0) or _noye(ctx, roc) or _vers(centres, roc, ecart * 0.7) < INF:
			continue
		_ranger(centres, roc)
		_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, autour[0], _milieu_du_sol(ctx, autour[0], arbres, rochers, mares) | PIERRE | EN_PLUS, combien, 0.0, autour)
	for m in mares:
		# (la ceinture d'une mare : un ou deux arcs de six places, serrées contre son bord)
		var c: Vector2 = m[0]
		var rx: float = m[1]
		var tour := r.randf() * TAU
		for b in 1 + r.randi() % 2:
			var a0 := tour + b * TAU / 3.0 + r.randf_range(-0.3, 0.3)
			var autour: Array = []
			for j in R.MILIEU_GROUPE:
				var a := a0 + j * 0.3
				autour.append(c + Vector2(cos(a), sin(a) * ov) * (rx + r.randf_range(5.0, 16.0)))
			var ici := (_milieu_du_sol(ctx, autour[0], arbres, rochers, mares) & ~NU & ~SEC) | RIVE | EN_PLUS
			_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, autour[0], ici, R.MILIEU_GROUPE, 0.0, autour)
	if eau > 0.0:
		# (la rive de l'eau qui reste dans les creux : des groupes de six places, le long du rivage, les pieds dans l'eau ou juste
		# au-dessus)
		n = Decor._nombre(r, rect.get_area() / (R.MILIEU_RIVAGES * R.MILIEU_RIVAGES))
		for i in n:
			var q := Decor._dans(r, rect)
			var h := relief_en(ctx, q)
			if h < eau - 0.012 or h > eau + R.MILIEU_RIVAGE * 0.6 or q.length() < 170.0:
				continue
			var pente := Vector2(relief_en(ctx, q + Vector2(6.0, 0.0)) - h, relief_en(ctx, q + Vector2(0.0, 6.0)) - h)
			if pente.length() < 0.000001 or _dans_l_eau(ctx, q, 4.0):
				continue
			pente = pente.normalized()
			var autour: Array = [q]
			for j in R.MILIEU_GROUPE - 1:
				autour.append(q + pente.orthogonal() * (j / 2 + 1) * (11.0 if j % 2 == 0 else -11.0) + pente * r.randf_range(-4.0, 8.0))
			_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, autour[0], (_milieu_du_sol(ctx, q, arbres, rochers, mares) & ~NU & ~SEC) | RIVE | EN_PLUS, R.MILIEU_GROUPE, 0.0, autour)
	_rives(ctx, r, suite, rect, plan, arbres, rochers, mares)
	_libres(plan, debut)
	# 6. le bois mort (sous les bosquets), les herbes de l'herbier de Lisière (scripts/botanique.gd)
	_semis(r, plan, rect, "brindille", 160.0 * ka, "", bosquets, 0.6, type)
	_semis(r, plan, rect, "herbe", float(ctx.get("herbes", 110)) * ka, "", null, 1.0, type)


# les places du sol qu'aucune autre plante ne serre — rien, hors de son propre groupe, à moins de R.MILIEU_LIBRE pixels de sa
# première place : la place de qui prend toute l'eau autour de lui (un cactus). Tout le groupe porte ce milieu (le même tirage,
# la même plante). Seules comptent les places de ce rectangle (à partir de « debut ») : un plan ne voit pas le rectangle voisin,
# et au bord une place peut se croire libre
static func _libres(plan: Array, debut: int) -> void:
	var g := {}
	var tetes: Array = []
	var tete := -1
	for i in range(debut, plan.size()):
		var e: Array = plan[i]
		if e.size() < 6 or int(e[5]) < 0 or not (str(e[0]) in ["sol", "buisson", "arbre", "sapin"]):
			continue
		if rang(int(e[5])) == 0:
			tete = i
			if str(e[0]) == "sol":
				tetes.append(i)
		_ranger(g, e[1], tete)
	var loin: float = R.MILIEU_LIBRE
	for i in tetes:
		var p: Vector2 = plan[i][1]
		var a := Vector2i(((p - Vector2(loin, loin)) / 96.0).floor())
		var b := Vector2i(((p + Vector2(loin, loin)) / 96.0).floor())
		var libre := true
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for q in g.get(Vector2i(x, y), []):
					if int(q[1]) != i and p.distance_squared_to(q[0]) < loin * loin:
						libre = false
						break
				if not libre:
					break
			if not libre:
				break
		if libre:
			for j in maxi(1, taille(int(plan[i][5]))):
				if i + j < plan.size() and str(plan[i + j][0]) == "sol":
					plan[i + j][5] = int(plan[i + j][5]) | LIBRE


# les rives que la carte et le pays donnent (le monde ouvert : la berge d'une rivière, la rive d'un lac ; un pays : le bord
# d'une fondrière) : des groupes de places de rive, serrées contre l'eau
static func _rives(ctx: Dictionary, r: RandomNumberGenerator, suite: Array, rect: Rect2, plan: Array, arbres: Dictionary, rochers: Dictionary, mares: Array) -> void:
	var type: String = ctx["type"]
	for q in ctx.get("berges", []):
		if not rect.has_point(q) or r.randf() > R.MILIEU_BERGES:
			continue
		var autour: Array = []
		var sens: Vector2 = ctx.get("berges_sens", {}).get(q, Vector2.RIGHT)
		for j in R.MILIEU_GROUPE:
			autour.append(q + sens * (j - 2.5) * 11.0 + sens.orthogonal() * r.randf_range(-7.0, 7.0))
		_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, autour[0], (_milieu_du_sol(ctx, q, arbres, rochers, mares) & ~NU & ~SEC) | RIVE | EN_PLUS, R.MILIEU_GROUPE, 0.0, autour)
	for e in ctx.get("eaux", []):
		var c: Vector2 = e[0]
		if not rect.grow(float(e[1]) + 30.0).has_point(c) or not bool(e[2]):
			continue
		# (le bord d'une fondrière : un arc de six places, deux parfois)
		var tour := r.randf() * TAU
		for b in 1 + (1 if r.randf() < 0.3 else 0):
			var a0 := tour + b * TAU / 2.0 + r.randf_range(-0.4, 0.4)
			var autour: Array = []
			for j in R.MILIEU_GROUPE:
				var a := a0 + j * 14.0 / maxf(30.0, float(e[1]))
				autour.append(c + Vector2(cos(a), sin(a) * 0.82) * (float(e[1]) + r.randf_range(4.0, 14.0)))
			if not rect.has_point(autour[0]) or autour[0].length() < 170.0:
				continue
			_groupe(ctx, r, suite, plan, rect, "sol", "herbe", type, autour[0], (_milieu_du_sol(ctx, autour[0], arbres, rochers, mares) & ~NU & ~SEC) | RIVE | EN_PLUS, R.MILIEU_GROUPE, 0.0, autour)


# ce qu'on cueille en plus dans un rectangle, et qui n'est qu'à Lisière : des fleurs des prés là où le sol est herbeux, des
# champignons des bois au pied des arbres (sous un couvert humide ; une amanite sur trois). Il y en a un peu plus qu'il n'en
# faut : la météo d'Orvane dit combien servent (monde.gd, _poser). arbres : les places d'arbres du rectangle
static func cueillette(ctx: Dictionary, r: RandomNumberGenerator, rect: Rect2, plan: Array, arbres: Array) -> void:
	var s: Dictionary = ctx["s"]
	var t: Dictionary = ctx["t"]
	var type: String = ctx["type"]
	var ka := rect.get_area() / (4.0 * R.DEMI * R.DEMI)
	var froid := float(s["froid"])
	var sec := float(s["sec"])
	var terrain := not t.is_empty()
	var n := Decor._nombre(r, (R.MILIEU_FLEURS + R.MILIEU_FLEURS_HERBE * float(s["herbe"])) * (1.0 - froid * 0.8) * (1.0 - sec * 0.85) * R.MILIEU_CUEILLETTE_RESERVE * ka)
	var essais := n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var g := r.randi()
		if q.length() < 150.0 or _noye(ctx, q):
			continue
		if terrain:
			var ici := Decor.sol_ici(t, s, q)
			if r.randf() > 0.15 + float(ici["herbe"]) * 0.85 or float(ici["neige"]) > 0.3:
				continue
		plan.append(["fleur", q, "herbe", g, type, 0])
		n -= 1
	n = Decor._nombre(r, R.MILIEU_CHAMPIGNONS * float(s["couvert"]) * clampf((float(s["humide"]) - 0.45) * 2.5, 0.0, 1.0) * (1.0 - froid * 0.7) * R.MILIEU_CUEILLETTE_RESERVE * ka)
	essais = n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		if not arbres.is_empty() and r.randf() < 0.7:
			q = arbres[r.randi() % arbres.size()] + Vector2.from_angle(r.randf() * TAU) * r.randf_range(15.0, 34.0) * Vector2(1.0, 0.6)
		var g := r.randi()
		var amanite := r.randf() < Flore.AMANITES
		# (au pied d'un arbre, mais dans ce morceau : un morceau ne pose rien chez son voisin)
		if q.length() < 150.0 or not rect.has_point(q) or _noye(ctx, q):
			continue
		if terrain and float(Decor.sol_ici(t, s, q)["neige"]) > 0.3:
			continue
		plan.append(["amanite" if amanite else "cepe", q, "", g, type, 0])
		n -= 1
