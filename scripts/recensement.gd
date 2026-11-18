extends RefCounted
# Lisière — le recensement de la flore (scripts/recensement.gd)
# Ce qui pousse vraiment dans un lieu, compté : pour chaque plante de l'herbier d'Orvane, combien on en a posé, sa part réalisée
# dans sa strate à côté de sa part d'Orvane, et où elle se tient — à quelle distance de l'eau, sous combien d'arbres, près d'un
# rocher, à côté de qui. Puis ce que les règles de milieu promettent (scripts/milieu.gd) : les plantes de rive au bord de l'eau,
# celles du sous-bois sous le couvert, les plantes grasses espacées, les arbres en peuplements, les géants à l'écart.
# La vitrine le dit (`--vitrine --lieu marais --recense`, `--ouvert --depuis x,y --recense`) ; l'essai s'en sert pour ses
# contrôles (« La répartition »). Il ne change rien au lieu : il le lit.

const Flore := preload("res://scripts/flore.gd")

const RIVE := ["roseau", "jonc", "riz", "papyrus", "bambou"]          # ce qu'on attend au bord de l'eau
const SOUS_BOIS := ["mousse", "fougere", "liane", "orchidee", "bromelia", "sous_bois"]   # … sous le couvert
const GRASSES := ["cactus", "agave", "succulente"]                    # … espacées
const PIERRE := ["lichen", "lichen_croute", "lichen_rennes", "coussin", "caillou"]       # … près des rochers, sur le caillou
const GEANTS := ["geant", "emergent"]                                # … rares, à l'écart
const PRES_EAU := 70.0         # « au bord de l'eau » : à moins de tant de la rive d'une mare, d'une rivière
const SOUS := 70.0             # « sous le couvert » : à moins de tant d'un tronc
const ALENTOUR := 130.0        # les arbres « autour » d'une plante
const PRES_ROC := 60.0         # « près d'un rocher »
const PEUPLEMENT := 120.0      # deux arbres de la même espèce à moins de tant sont du même peuplement


# la distance de p à l'eau la plus proche : la rive d'une mare (une plante d'eau), ou — dans le monde ouvert — une rivière, un
# lac (cherchés autour, jusqu'à 400 pixels ; INF au-delà)
static func _vers_l_eau(p: Vector2, mares: Array, carte) -> float:
	var d := INF
	for m in mares:
		var q: Vector2 = (p - m[0]) / Vector2(1.0, 0.45)
		d = minf(d, maxf(0.0, q.length() - float(m[1])))
	if carte != null and d > 20.0:
		for pas in 20:
			var r := 20.0 * (pas + 1)
			if r >= d:
				break
			var vu := false
			for k in 12:
				if carte.mouille(p + Vector2.from_angle(TAU * k / 12.0) * r):
					vu = true
					break
			if vu:
				d = r
				break
	return d


static func _mediane(l: Array) -> float:
	if l.is_empty():
		return -1.0
	var t := l.duplicate()
	t.sort()
	return float(t[t.size() / 2])


static func _part(l: Array, sous: float) -> float:
	if l.is_empty():
		return 0.0
	return float(l.filter(func(x): return float(x) < sous).size()) / float(l.size())


# le recensement d'un monde (tous ses objets, ou ceux d'un rectangle) : { plantes: { id: {…} }, strates, rives, sous_bois,
# grasses, peuplements, geants, pierre, genres, parts_ecart }
static func compter(monde, biome: String, rect: Rect2 = Rect2()) -> Dictionary:
	var objets: Array = monde.objets.filter(func(o): return is_instance_valid(o) and (rect.size.x <= 0.0 or rect.has_point(o.position)))
	var carte = monde.get("carte")
	var arbres: Array = []
	var rochers: Array = []
	var mares: Array = []
	var genres := {}
	for o in objets:
		genres[o.genre] = int(genres.get(o.genre, 0)) + 1
		if o.genre in ["arbre", "sapin", "souche"]:
			arbres.append(o)
		elif o.genre == "rocher":
			rochers.append(o.position)
		elif o.genre == "aquatique":
			mares.append([o.position, float(o._rx)])
	# (une grille, pour trouver vite les voisins)
	var CASE := 150.0
	var grille := {}
	for a in arbres:
		var k := Vector2i((a.position / CASE).floor())
		if not grille.has(k):
			grille[k] = []
		grille[k].append(a)
	var pres := func(p: Vector2, rayon: float) -> Array:
		var out: Array = []
		var a := Vector2i(((p - Vector2(rayon, rayon)) / CASE).floor())
		var b := Vector2i(((p + Vector2(rayon, rayon)) / CASE).floor())
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for o in grille.get(Vector2i(x, y), []):
					if o.position.distance_to(p) <= rayon:
						out.append(o)
		return out
	var parts := {}
	var tot_strate := {}
	for e in Orvane.plantes(biome):
		var so := Flore.sorte(e)
		parts[str(e["id"])] = {"part": float(e.get("part", 0.0)), "strate": str(so["strate"]), "forme": str(so["forme"]), "nom": str(e.get("nom", "")),
			"caracteres": e.get("caracteres", [])}
		tot_strate[so["strate"]] = float(tot_strate.get(so["strate"], 0.0)) + maxf(0.02, float(e.get("part", 0.0)))
	var P := {}
	var n_strate := {}
	for o in objets:
		if str(o.plante) == "" or not parts.has(str(o.plante)):
			continue
		var id := str(o.plante)
		if not P.has(id):
			P[id] = {"n": 0, "eau": [], "arbres": [], "sous": 0, "roc": 0, "places": [], "forme": parts[id]["forme"], "strate": parts[id]["strate"],
				"nom": parts[id]["nom"], "part": parts[id]["part"]}
		var e: Dictionary = P[id]
		e["n"] += 1
		e["places"].append(o.position)
		n_strate[e["strate"]] = int(n_strate.get(e["strate"], 0)) + 1
		e["eau"].append(_vers_l_eau(o.position, mares, carte))
		var autour: Array = pres.call(o.position, ALENTOUR)
		autour.erase(o)
		e["arbres"].append(autour.size())
		if autour.any(func(a): return a.position.distance_to(o.position) <= SOUS):
			e["sous"] += 1
		for q in rochers:
			if q.distance_to(o.position) <= PRES_ROC:
				e["roc"] += 1
				break
	var ecart := 0.0
	for id in parts:
		var st: String = parts[id]["strate"]
		var attendu: float = maxf(0.02, float(parts[id]["part"])) / maxf(0.0001, float(tot_strate[st]))
		var vu := 0.0
		if P.has(id):
			vu = float(P[id]["n"]) / maxf(1.0, float(n_strate.get(st, 0)))
			P[id]["vu"] = vu
			P[id]["attendu"] = attendu
		elif n_strate.has(st):
			P[id] = {"n": 0, "eau": [], "arbres": [], "sous": 0, "roc": 0, "places": [], "forme": parts[id]["forme"], "strate": st, "nom": parts[id]["nom"],
				"part": parts[id]["part"], "vu": 0.0, "attendu": attendu}
		if n_strate.has(st):
			ecart = maxf(ecart, absf(vu - attendu))
	# les rives : ce qui est de rive, à quelle distance de l'eau
	var d_rive: Array = []
	var d_autres: Array = []
	var sous_bois := [0, 0]
	var sol_ailleurs := [0, 0]
	var pierre := [0, 0]
	var grasses: Array = []
	for id in P:
		var e: Dictionary = P[id]
		if RIVE.has(e["forme"]):
			d_rive.append_array(e["eau"])
		elif e["strate"] == "sol":
			d_autres.append_array(e["eau"])
		if SOUS_BOIS.has(e["forme"]):
			sous_bois[0] += int(e["sous"])
			sous_bois[1] += int(e["n"])
		elif e["strate"] == "sol":
			sol_ailleurs[0] += int(e["sous"])
			sol_ailleurs[1] += int(e["n"])
		if PIERRE.has(e["forme"]):
			pierre[0] += int(e["roc"])
			pierre[1] += int(e["n"])
		if GRASSES.has(e["forme"]):
			grasses.append_array(e["places"])
	# les plantes grasses : la distance de chacune à sa plus proche voisine
	var d_grasses: Array = []
	for i in grasses.size():
		var d := INF
		for j in grasses.size():
			if i != j:
				d = minf(d, grasses[i].distance_to(grasses[j]))
		if d < INF:
			d_grasses.append(d)
	# les peuplements : l'arbre le plus proche est-il de la même espèce ? et la taille des peuplements (les arbres de la même
	# espèce qui se tiennent à moins de PEUPLEMENT, de proche en proche)
	var meme := 0
	var avec_voisin := 0
	var hasard := 0.0
	var n_arbres := 0
	var par_espece := {}
	for a in arbres:
		if str(a.plante) == "":
			continue
		n_arbres += 1
		par_espece[a.plante] = int(par_espece.get(a.plante, 0)) + 1
		var d0 := INF
		var v = null
		for b in pres.call(a.position, 220.0):
			if b != a and str(b.plante) != "" and b.position.distance_to(a.position) < d0:
				d0 = b.position.distance_to(a.position)
				v = b
		if v != null:
			avec_voisin += 1
			if v.plante == a.plante:
				meme += 1
	for id in par_espece:
		hasard += pow(float(par_espece[id]) / maxf(1.0, float(n_arbres)), 2.0)
	var vus := {}
	var tailles: Array = []
	for a in arbres:
		if str(a.plante) == "" or vus.has(a):
			continue
		var pile := [a]
		vus[a] = true
		var n := 0
		while not pile.is_empty():
			var x = pile.pop_back()
			n += 1
			for b in pres.call(x.position, PEUPLEMENT):
				if not vus.has(b) and b.plante == a.plante:
					vus[b] = true
					pile.append(b)
		tailles.append(n)
	var dans_grand := 0
	for t in tailles:
		if int(t) >= 4:
			dans_grand += int(t)
	# les géants : l'arbre le plus proche de chacun
	var d_geants: Array = []
	var d_arbres: Array = []
	for a in arbres:
		var d0 := INF
		for b in pres.call(a.position, 400.0):
			if b != a:
				d0 = minf(d0, b.position.distance_to(a.position))
		if str(a.plante) != "" and parts.has(str(a.plante)) and (GEANTS.has(parts[a.plante]["forme"]) or parts[a.plante]["caracteres"].has("geante")):
			d_geants.append(minf(d0, 400.0))
		elif d0 < INF:
			d_arbres.append(d0)
	return {"biome": biome, "plantes": P, "n_strate": n_strate, "genres": genres, "ecart": ecart, "objets": objets.size(),
		"rives": {"n": d_rive.size(), "mediane": _mediane(d_rive), "pres": _part(d_rive, PRES_EAU), "autres_pres": _part(d_autres, PRES_EAU), "autres": d_autres.size(), "mares": mares.size()},
		"sous_bois": {"n": sous_bois[1], "sous": float(sous_bois[0]) / maxf(1.0, float(sous_bois[1])), "ailleurs": float(sol_ailleurs[0]) / maxf(1.0, float(sol_ailleurs[1])), "n_ailleurs": sol_ailleurs[1]},
		"pierre": {"n": pierre[1], "pres": float(pierre[0]) / maxf(1.0, float(pierre[1])), "rochers": rochers.size()},
		"grasses": {"n": grasses.size(), "mediane": _mediane(d_grasses), "min": d_grasses.min() if not d_grasses.is_empty() else -1.0, "serrees": _part(d_grasses, 40.0)},
		"peuplements": {"arbres": n_arbres, "meme": float(meme) / maxf(1.0, float(avec_voisin)), "hasard": hasard, "taille": float(n_arbres) / maxf(1.0, float(tailles.size())),
			"max": tailles.max() if not tailles.is_empty() else 0, "en_peuplement": float(dans_grand) / maxf(1.0, float(n_arbres))},
		"geants": {"n": d_geants.size(), "mediane": _mediane(d_geants), "min": d_geants.min() if not d_geants.is_empty() else -1.0, "autres": _mediane(d_arbres)}}


# le recensement, dit ligne à ligne
static func dire(monde, biome: String, rect: Rect2 = Rect2(), titre := "") -> Dictionary:
	var c := compter(monde, biome, rect)
	print("recensement : %s%s — %d objets (%s)" % [biome, (" " + titre) if titre != "" else "", int(c["objets"]),
		", ".join(c["genres"].keys().map(func(k): return "%s %d" % [k, int(c["genres"][k])]))])
	var ids: Array = c["plantes"].keys()
	ids.sort_custom(func(a, b): return [c["plantes"][a]["strate"], -float(c["plantes"][a]["part"])] < [c["plantes"][b]["strate"], -float(c["plantes"][b]["part"])])
	print("  %-7s %-11s %-34s %5s  %7s %7s  %9s %6s  %6s %5s  %5s" % ["strate", "forme", "plante", "posés", "part", "Orvane", "eau (méd)", "<%d px" % int(PRES_EAU), "arbres", "sous", "roc"])
	for id in ids:
		var e: Dictionary = c["plantes"][id]
		var n := int(e["n"])
		var moy := 0.0
		for x in e["arbres"]:
			moy += float(x)
		var med := _mediane(e["eau"])
		print("  %-7s %-11s %-34s %5d  %6.1f%% %6.1f%%  %9s %5.0f%%  %6.1f %4.0f%%  %4.0f%%" % [e["strate"], e["forme"], str(e["nom"]).left(34), n, 100.0 * float(e["vu"]), 100.0 * float(e["attendu"]),
			("%d" % int(med)) if med >= 0.0 and med < INF else "—", 100.0 * _part(e["eau"], PRES_EAU), moy / maxf(1.0, float(n)), 100.0 * float(e["sous"]) / maxf(1.0, float(n)),
			100.0 * float(e["roc"]) / maxf(1.0, float(n))])
	var rv: Dictionary = c["rives"]
	var sb: Dictionary = c["sous_bois"]
	var gr: Dictionary = c["grasses"]
	var pe: Dictionary = c["peuplements"]
	var ge: Dictionary = c["geants"]
	var pi: Dictionary = c["pierre"]
	print("  parts : l'écart le plus grand entre la part réalisée et celle d'Orvane (dans la strate) : %.1f points" % (100.0 * float(c["ecart"])))
	if int(rv["n"]) > 0:
		print("  rives : %d plantes de rive, à %s pixels de l'eau (médiane), %.0f %% à moins de %d (les autres plantes du sol : %.0f %% de %d) ; %d mares" % [int(rv["n"]),
			("%d" % int(rv["mediane"])) if float(rv["mediane"]) < INF else "plus de 400", 100.0 * float(rv["pres"]), int(PRES_EAU), 100.0 * float(rv["autres_pres"]), int(rv["autres"]), int(rv["mares"])])
	if int(sb["n"]) > 0:
		print("  sous-bois : %d plantes du sous-bois, %.0f %% à moins de %d pixels d'un tronc (les autres plantes du sol : %.0f %% de %d)" % [int(sb["n"]), 100.0 * float(sb["sous"]), int(SOUS),
			100.0 * float(sb["ailleurs"]), int(sb["n_ailleurs"])])
	if int(pi["n"]) > 0:
		print("  pierre : %d lichens, coussins, plantes-cailloux, %.0f %% à moins de %d pixels d'un rocher (%d rochers)" % [int(pi["n"]), 100.0 * float(pi["pres"]), int(PRES_ROC), int(pi["rochers"])])
	if int(gr["n"]) > 1:
		print("  plantes grasses : %d, à %d pixels de leur plus proche voisine (médiane ; au plus près %d), %.0f %% à moins de 40" % [int(gr["n"]), int(gr["mediane"]), int(gr["min"]), 100.0 * float(gr["serrees"])])
	if int(pe["arbres"]) > 0:
		print("  peuplements : %d arbres ; le plus proche voisin est de la même espèce pour %.0f %% (au hasard : %.0f %%) ; %.1f arbres par peuplement, le plus grand %d ; %.0f %% dans un peuplement de quatre ou plus" % [
			int(pe["arbres"]), 100.0 * float(pe["meme"]), 100.0 * float(pe["hasard"]), float(pe["taille"]), int(pe["max"]), 100.0 * float(pe["en_peuplement"])])
	if int(ge["n"]) > 0:
		print("  géants : %d, leur plus proche arbre à %d pixels (médiane ; au plus près %d) ; les autres arbres : %d" % [int(ge["n"]), int(ge["mediane"]), int(ge["min"]), int(ge["autres"])])
	return c
