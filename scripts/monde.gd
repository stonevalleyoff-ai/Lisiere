extends Node2D
# Lisière — le lieu (scripts/monde.gd)
# Un carré de terre, tiré du biome d'Orvane qu'on joue : son couvert fait les arbres (des sapins s'il fait froid), son humidité
# les buissons et l'herbe, son altitude les rochers, sa température et son humidité la couleur du sol. Les objets sont rangés
# dans une grille, pour trouver vite ce qui est à portée. Ce nœud trie ses enfants par hauteur (y_sort_enabled) : le joueur, les
# bêtes et les feux y vivent aussi.
# Le sol est peint par un shader (shaders/sol_peint.gdshader), cuit par tuiles autour de la caméra (scripts/decor_sol.gd) ;
# l'herbe, les fougères, les fleurs, le décor et la lisière du
# monde viennent de scripts/decor.gd ; les ombres au sol sont dessinées ici, par cases, une fois (et redessinées quand un objet
# change). À chaque image, le monde donne le temps au vent, la place de la veilleuse à l'herbe, l'heure aux ombres, et efface
# les couronnes qui la cachent.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const Objet := preload("res://scripts/objet.gd")
const Decor := preload("res://scripts/decor.gd")
const Pinceau := preload("res://scripts/decor_pinceau.gd")
const SolCuit := preload("res://scripts/decor_sol.gd")
const SHADER_SOL := preload("res://shaders/sol_peint.gdshader")
const SHADER_OMBRE := preload("res://shaders/sol_ombre.gdshader")
const CASE := 200.0
const CASE_OMBRE := 420.0
const EFFACE := 0.35           # l'opacité d'une couronne qui cache la veilleuse
# un lieu sans bord (MONDE-OUVERT.md) : il se fabrique par morceaux autour de la veilleuse
const MORCEAU := 700.0         # le côté d'un morceau
const PORTEE := 1400.0         # jusqu'où le lieu existe autour d'elle
const OUBLI := 2300.0          # plus loin, un morceau est défait : on ne garde que ce qu'on y a changé

var jeu
var objets: Array = []
var palette := {}
var _grille := {}
var _racine: Node2D
var _sol
var _sol_relief               # (le monde ouvert : les parois du relief, sur un calque au-dessus du temps qu'il fait)
var _terrain := {}
var _parts := {}
var _mobile := false
var _ombres := {}              # case → [le nœud qui dessine ses ombres, ses objets]
var _effaces := {}             # les objets dont la couronne s'efface, ou revient
var _temps := 0.0
var _mat_sol: ShaderMaterial
var _mat_herbe: ShaderMaterial
var _mat_ombre: ShaderMaterial
# (docs/49) les plantes du lieu, d'après l'herbier d'Orvane : par genre d'objet, celles qu'on sème et leur poids
var lieu := ""
var flore := {}
# sans bord : ses morceaux faits (place → { objets, noeuds }), ce qu'on y a changé (« x,y » → { rang : [genre, reste, repousse,
# brûlé, l'heure], ou null s'il n'y est plus }), ce qui y est tombé depuis (« x,y » → [[genre, x, y, graine]…])
var ouvert := false
# le monde ouvert : la carte (scripts/carte.gd ; null : un seul biome, sans bord), et ce qu'est chaque biome qu'on y rencontre
# (type → { axes, palette, parts, sol (ce que reçoit le shader du sol), arbre, mesures, flore, outils (du décor), climat })
var carte
var _lieux := {}
var _morceaux := {}
var _changes := {}
var _ajouts := {}
var _graine := 0
var _bosquets: FastNoiseLite
var _arbre := "arbre"
var _mesures := [0.4, 0.5, 0.3]      # le couvert, l'humidité, l'altitude du lieu
var _outils := {}
var _calques: Array = []             # ce qui est posé à plat, l'herbe et les plantes, ce qui dépasse, les ombres : dans cet ordre


# les couleurs du lieu, d'après ses axes (0 à 1), toutes tirées de la palette (scripts/palette.gd)
static func couleurs(axes: Dictionary) -> Dictionary:
	var temp := float(axes.get("temperature", 0.5))
	var humid := float(axes.get("humidite", 0.5))
	var couvert := float(axes.get("couvert", 0.4))
	var froid := clampf((0.35 - temp) * 4.0, 0.0, 1.0)
	var sec := clampf((0.42 - humid) * 3.0, 0.0, 1.0)
	var chaud := clampf((temp - 0.72) * 3.0, 0.0, 1.0)
	var mouille := clampf((humid - 0.6) * 2.0, 0.0, 1.0)
	# la terre : un humus brun ; plus pâle au sec, ocre rouge au chaud et sec, sombre à l'humide, grise au froid
	var terre := P.TERRE.lerp(P.IVOIRE.darkened(0.28), sec * 0.5 + 0.06)
	terre = terre.lerp(P.BRAISE.darkened(0.42), chaud * sec * 0.45)
	terre = terre.lerp(P.ENCRE_DOUCE, mouille * 0.35)
	terre = terre.lerp(P.LUNE.lerp(P.IVOIRE, 0.5).darkened(0.38), froid * 0.7)
	var mousse := P.MOUSSE.lerp(P.FEUILLE_SOMBRE, couvert * 0.25).lerp(P.IVOIRE.darkened(0.3), sec * 0.4).lerp(P.LUNE.darkened(0.35), froid * 0.3)
	var herbe := P.MOUSSE.lightened(0.08).lerp(P.IVOIRE.darkened(0.22), sec * 0.55 + chaud * 0.2).lerp(P.LUNE.darkened(0.2), froid * 0.25)
	var feuilles := P.MOUSSE.lerp(P.FEUILLE_SOMBRE, 0.15 + humid * 0.3)
	feuilles = feuilles.lerp(P.IVOIRE.darkened(0.35), sec * 0.3).lerp(P.NUIT_BLEUE.lerp(P.MOUSSE, 0.5), froid * 0.45)
	var pierre := P.CENDRE.lerp(P.IVOIRE, 0.3).lerp(terre, 0.18)
	var fleurs := [P.PAPIER, P.BRAISE_COEUR.darkened(0.1) if froid < 0.3 else P.LUNE.lightened(0.35), P.PEUR.lerp(P.CREPUSCULE, 0.5).lightened(0.15)]
	return {"sol": terre.lerp(mousse, 0.4), "feuilles": feuilles, "herbe": herbe, "pierre": pierre, "froid": temp < 0.35,
		"terre": terre, "terre_claire": terre.lerp(P.IVOIRE, 0.22), "terre_sombre": terre.lerp(P.ENCRE, 0.32),
		"mousse": mousse, "mousse_claire": mousse.lerp(P.IVOIRE, 0.2).lightened(0.05),
		"litiere_a": P.ECHARPE.lerp(P.TERRE, 0.35), "litiere_b": P.IVOIRE.lerp(P.BRAISE, 0.35).darkened(0.3), "litiere_c": P.TERRE.darkened(0.12),
		"neige": P.PAPIER.lightened(0.35), "neige_ombre": P.LUNE.lerp(P.PAPIER, 0.45), "boue": P.ENCRE_DOUCE.lerp(P.TERRE, 0.45),
		"eau": P.NUIT_BLEUE.lerp(P.FEUILLE_SOMBRE, 0.45).lerp(P.CENDRE, 0.2), "usure": terre.lerp(P.IVOIRE, 0.24), "sous_bois": P.NUIT.lerp(P.FEUILLE_SOMBRE, 0.3),
		"fougere": feuilles.lerp(P.MOUSSE, 0.6).lightened(0.1), "fleurs": fleurs,
		"bruyere": P.CREPUSCULE.lerp(P.PEUR, 0.3).lightened(0.08), "bruyere_feuille": P.MOUSSE.lerp(P.TERRE, 0.4).darkened(0.12),
		"humide": humid, "caillou": pierre}


# le sol (un shader, peint en coordonnées du monde), sous le décor et les ombres : à poser sous ce nœud
func creer_sol(biome: Dictionary, graine: int) -> Node2D:
	var axes: Dictionary = biome.get("axes", {})
	palette = couleurs(axes)
	_parts = Decor.parts(axes)
	_mobile = jeu != null and str(jeu.get("qualite")) == "mobile"
	_terrain = Decor.terrain(graine, ouvert)
	Objet.matieres()
	Objet.vegetation.set_shader_parameter("simple", _mobile)
	Objet.fixe.set_shader_parameter("simple", _mobile)
	Objet.climat = {"froid": float(_parts["froid"]), "humide": float(_parts["humide"])}
	_racine = Node2D.new()
	_mat_sol = ShaderMaterial.new()
	_mat_sol.shader = SHADER_SOL
	for k in ["plaques", "taches", "voiles", "motif_a", "motif_b"]:
		_mat_sol.set_shader_parameter(k, ImageTexture.create_from_image(_terrain[k]))
	_mat_sol.set_shader_parameter("etendue", Decor.ETENDUE)
	for k in ["terre", "terre_claire", "terre_sombre", "mousse", "mousse_claire", "herbe", "litiere_a", "litiere_b", "litiere_c",
			"caillou", "neige", "neige_ombre", "boue", "usure", "sous_bois"]:
		var c: Color = palette[k]
		_mat_sol.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	_mat_sol.set_shader_parameter("encre", Vector3(P.ENCRE.r, P.ENCRE.g, P.ENCRE.b))
	for k in ["mousse", "herbe", "litiere", "cailloux", "neige", "boue", "fentes"]:
		_mat_sol.set_shader_parameter("part_" + k, float(_parts[k]))
	_mat_sol.set_shader_parameter("demi", 1.0e9 if ouvert else R.DEMI)
	# (le sol est cuit par tuiles, autour de la caméra : scripts/decor_sol.gd ; peint une fois, il garde ses détails sur un
	# téléphone, à un texel par pixel du monde au lieu de 1,35 ; sans écran, rien ne se peint)
	if DisplayServer.get_name() != "headless":
		_sol = SolCuit.new()
		_sol.preparer(_mat_sol, 1.0 if _mobile else R.ZOOM)
		if ouvert:
			_sol.limite = 1 << 24
			_sol.monde_ = self
		_racine.add_child(_sol)
		if ouvert and carte != null:
			# (les parois du relief, peintes une seconde fois sur un calque à part : scripts/principal.gd le pose par-dessus ce
			# que le temps fait au sol, pour que la neige ou une crue ne cachent pas un mur)
			var mat_relief: ShaderMaterial = _mat_sol.duplicate()
			mat_relief.set_shader_parameter("que_relief", true)
			_sol_relief = SolCuit.new()
			_sol_relief.name = "SolRelief"
			_sol_relief.que_relief = true
			_sol_relief.gardees = 12
			_sol_relief.preparer(mat_relief, 1.0 if _mobile else R.ZOOM)
			_sol_relief.limite = 1 << 24
			_sol_relief.monde_ = self
			_racine.add_child(_sol_relief)
	_calques = []
	for i in 4:
		var calque := Node2D.new()
		_racine.add_child(calque)
		_calques.append(calque)
	_mat_ombre = ShaderMaterial.new()
	_mat_ombre.shader = SHADER_OMBRE
	_mat_ombre.set_shader_parameter("teinte", Vector3(P.NUIT.r, P.NUIT.g, P.NUIT.b).lerp(Vector3(P.NUIT_BLEUE.r, P.NUIT_BLEUE.g, P.NUIT_BLEUE.b), 0.4))
	return _racine


# le lieu semé d'après sa graine ; ou, une partie reprise (scripts/partie_gardee.gd), les objets tels qu'on les avait laissés :
# gardes, une liste de [espèce, genre, x, y, graine, reste, repousse] (photo_objets)
func generer(biome: Dictionary, graine: int, gardes: Array = []) -> void:
	var axes: Dictionary = biome.get("axes", {})
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var bosquets := FastNoiseLite.new()
	bosquets.seed = graine + 1
	bosquets.frequency = 0.0018
	var couvert := float(axes.get("couvert", 0.4))
	var humid := float(axes.get("humidite", 0.5))
	var alt := float(axes.get("altitude", 0.3))
	var arbre := "sapin" if palette.get("froid", false) else "arbre"
	lieu = str(biome.get("id", ""))
	_lire_flore(arbre)
	_graine = graine
	_bosquets = bosquets
	_arbre = arbre
	_mesures = [couvert, humid, alt]
	if ouvert:
		# (rien d'un coup : les morceaux autour du réveil, puis ceux qu'on approche)
		if _racine != null:
			_outils = Decor.outils(_parts, palette, graine)
			_mat_herbe = _outils["mat"]
		if carte != null:
			lieu_de(lieu)
		suivre(Vector2.ZERO, true)
		return
	if not gardes.is_empty():
		_reposer(gardes)
	else:
		_semer_tout(r, arbre, bosquets, couvert, humid, alt)
	# le décor, l'herbe, les ombres, la lisière : une fois les objets posés (le décor se glisse autour d'eux)
	if _racine != null:
		_mat_herbe = Decor.semer(self, _calques, _terrain, _parts, palette, graine, _mobile)
		for k in _ombres:
			_case_ombre(k)
		Decor.lisiere(self, palette, graine, _mobile)


func _semer_tout(r: RandomNumberGenerator, arbre: String, bosquets, couvert: float, humid: float, alt: float) -> void:
	_semer(r, arbre, int(70 + 430 * couvert), palette["feuilles"], bosquets, 0.25 + couvert)
	_semer(r, "rocher", int(40 + 140 * alt), palette["pierre"], null, 1.0)
	_semer(r, "buisson", int(40 + 110 * humid), palette["feuilles"], bosquets, 0.6)
	_semer(r, "touffe", int(90 + 130 * (1.0 - couvert)), palette["herbe"], null, 1.0)
	_semer(r, "brindille", 160, Color.WHITE, bosquets, 0.6)
	# au réveil, de quoi faire un premier feu à portée
	for i in 6:
		_poser("brindille", Vector2(r.randf_range(-120, 120), r.randf_range(-90, 90)), Color.WHITE, r.randi())
	for i in 2:
		_poser("rocher", Vector2(r.randf_range(-160, 160), r.randf_range(-130, 130)), palette["pierre"], r.randi())


# --- une partie gardée ---

# chaque objet, tel qu'il est : [espèce, genre, x, y, graine, reste, repousse] (une souche était un arbre, son espèce le dit)
func photo_objets() -> Array:
	var out := []
	for o in objets:
		if is_instance_valid(o):
			# (ce qui brûle au moment de garder aura brûlé : un arbre en feu est gardé en souche noire)
			var feu: bool = o.brule > 0.0
			var arbre: bool = o.genre == "arbre" or o.genre == "sapin"
			out.append([o._espece, "souche" if (feu and arbre) else o.genre, snappedf(o.position.x, 0.1), snappedf(o.position.y, 0.1), o.graine,
				0 if feu else o.reste, snappedf(o._repousse, 0.1), 1 if (o.calcine or feu) else 0])
	return out


func _reposer(gardes: Array) -> void:
	for g in gardes:
		if typeof(g) != TYPE_ARRAY or g.size() < 7:
			continue
		var espece := str(g[0])
		if not Objet.BUTIN.has(espece) or espece == "souche":
			continue
		var c: Color = Color.WHITE
		match espece:
			"arbre", "sapin", "buisson":
				c = palette["feuilles"]
			"rocher":
				c = palette["pierre"]
			"touffe":
				c = palette["herbe"]
		_poser(espece, Vector2(float(g[2]), float(g[3])), c, int(g[4]))
		objets.back().reprendre(str(g[1]), int(g[5]), float(g[6]), g.size() > 7 and int(g[7]) == 1)


# des objets d'un genre, au hasard, plus serrés là où le bruit des bosquets est haut ; rien sur le lieu du réveil
func _semer(r: RandomNumberGenerator, genre: String, n: int, couleur: Color, bruit, densite: float) -> void:
	var poses := 0
	var essais := 0
	while poses < n and essais < n * 12:
		essais += 1
		var p := Vector2(r.randf_range(-R.DEMI, R.DEMI), r.randf_range(-R.DEMI, R.DEMI))
		if p.length() < 150.0:
			continue
		if bruit != null:
			var v: float = bruit.get_noise_2d(p.x, p.y)
			if r.randf() > clampf(densite * 0.5 + v * 0.9, 0.04, 1.0):
				continue
		_poser(genre, p, couleur, r.randi())
		poses += 1


# les plantes du lieu, rangées par genre d'objet : un arbre du jeu est une plante au port d'arbre, un buisson une plante au port de
# buisson, une touffe une herbe, un roseau, une succulente ou un lichen. Chacune a son poids (sa part du lieu), et ce que le dessin
# à l'encre de l'objet prend d'elle (objet.porter_plante) : sa couleur (lue une fois sur son dessin de l'herbier), sa taille
# (d'après sa hauteur vraie), son port, ses défenses. Sans herbier, rien : les objets gardent les couleurs du lieu.
const PORTS := {"arbre": ["arbre"], "buisson": ["buisson"], "touffe": ["herbe", "roseau", "succulente", "lichen", "champignon"]}

func _lire_flore(arbre: String) -> void:
	flore = _flore_de(lieu, arbre)


func _flore_de(type: String, arbre: String) -> Dictionary:
	var out := {}
	for e in Orvane.plantes(type):
		var port := str(e.get("port", e.get("forme", "")))
		for genre in PORTS:
			if not PORTS[genre].has(port):
				continue
			var h := float(e.get("hauteur_m", 1.0))
			# (la taille : un arbre de 12 m, un buisson d'1,5 m sont à la mesure du dessin ; plus haut, un peu plus grand, sans excès)
			var k := 1.0
			if genre == "arbre":
				k = clampf(pow(h / 12.0, 0.35), 0.8, 1.3)
			elif genre == "buisson":
				k = clampf(pow(h / 1.5, 0.35), 0.8, 1.3)
			var g := arbre if genre == "arbre" else str(genre)
			if not out.has(g):
				out[g] = []
			out[g].append({"id": str(e["id"]), "poids": maxf(0.02, float(e.get("part", 0.0))), "taille": k, "port": port,
				"defense": e.get("defense", []), "couleur": _couleur_plante(str(e["id"]), type)})
	return out


# ce qu'est un biome du monde ouvert, d'après ses axes (fait une fois, à sa première rencontre)
const TONS_DU_SOL := ["terre", "terre_claire", "terre_sombre", "mousse", "mousse_claire", "herbe", "litiere_a", "litiere_b", "litiere_c",
	"caillou", "neige", "neige_ombre", "boue", "usure", "sous_bois"]
const PARTS_DU_SOL := ["mousse", "herbe", "litiere", "cailloux", "neige", "boue", "fentes"]

func lieu_de(type: String) -> Dictionary:
	if _lieux.has(type):
		return _lieux[type]
	var info: Dictionary = jeu.donnees.biome(type) if jeu != null and jeu.get("donnees") != null else {}
	var axes: Dictionary = info.get("axes", {})
	if type == "riviere":
		# (une vallée de rivière : pour Orvane c'est de l'eau ; ici, ses berges sont une prairie humide, pas un marécage)
		axes = axes.duplicate()
		axes["humidite"] = 0.68
	var pal := couleurs(axes)
	var parts := Decor.parts(axes)
	var sol := {}
	for k in TONS_DU_SOL:
		var c: Color = pal[k]
		sol[k] = Vector3(c.r, c.g, c.b)
	for k in PARTS_DU_SOL:
		sol["part_" + k] = float(parts[k])
	var eau: Color = pal["eau"]
	sol["c_eau"] = Vector3(eau.r, eau.g, eau.b)
	# (une vallée de rivière est de la terre : seul son lit est de l'eau)
	sol["etendue_eau"] = 1.0 if type != "riviere" and ["marin", "aquatique"].has(str(info.get("milieu", "terrestre"))) else 0.0
	var arbre := "sapin" if pal.get("froid", false) else "arbre"
	var L := {"type": type, "axes": axes, "palette": pal, "parts": parts, "sol": sol, "arbre": arbre,
		"mesures": [float(axes.get("couvert", 0.4)), float(axes.get("humidite", 0.5)), float(axes.get("altitude", 0.3))],
		"flore": _flore_de(type, arbre), "outils": {}, "climat": {"froid": float(parts["froid"]), "humide": float(parts["humide"])}}
	_lieux[type] = L
	return L


# les plantes d'un biome viennent d'arriver (son herbier se lit en approchant) : ce qu'on y sèmera désormais les porte
func flore_arrivee(type: String) -> void:
	if _lieux.has(type):
		_lieux[type]["flore"] = _flore_de(type, str(_lieux[type]["arbre"]))


# la couleur d'une plante : la moyenne des verts de son dessin de l'herbier, rendu petit une fois (null : pas de dessin)
func _couleur_plante(id: String, type: String):
	var tex: ImageTexture = Orvane.texture_plante(id, 40.0, type)
	if tex == null:
		return null
	var img := tex.get_image()
	var somme := Color(0, 0, 0, 0)
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.g > maxf(c.r, c.b) + 0.03:
				somme += c
				n += 1
	return Color(somme.r / n, somme.g / n, somme.b / n) if n > 0 else null


# une plante du lieu pour ce genre d'objet, tirée selon son poids ({} : aucune)
func _plante(genre: String, graine: int, flore_: Dictionary) -> Dictionary:
	var L: Array = flore_.get(genre, [])
	if L.is_empty():
		return {}
	var tot := 0.0
	for e in L:
		tot += float(e["poids"])
	var x := float(graine % 10007) / 10007.0 * tot
	for e in L:
		x -= float(e["poids"])
		if x <= 0.0:
			return e
	return L[0]


# (ici : le biome où il pousse, dans le monde ouvert ; sinon celui du lieu)
func _poser(genre: String, p: Vector2, couleur: Color, graine: int, ici: Dictionary = {}):
	if not ici.is_empty():
		Objet.climat = ici["climat"]
	var o = Objet.new()
	o.preparer(genre, couleur, graine)
	var pl := _plante(genre, graine, ici["flore"] if not ici.is_empty() else flore)
	if not pl.is_empty():
		o.porter_plante(pl)
	o.position = p
	add_child(o)
	objets.append(o)
	var k := _cle(p)
	if not _grille.has(k):
		_grille[k] = []
	_grille[k].append(o)
	var ko := _cle_ombre(p)
	if not _ombres.has(ko):
		_ombres[ko] = [null, []]
	_ombres[ko][1].append(o)
	if _ombres[ko][0] != null:
		_ombres[ko][0].queue_redraw()
	elif _mat_herbe != null:
		_case_ombre(ko)
	return o


# chaque aube, des brindilles tombées dans la nuit
func semer_brindilles(n: int) -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	if ouvert:
		# (autour de la veilleuse, à la même densité ; pas plus de six par morceau : elles ne s'entassent pas là où l'on reste)
		var c: Vector2 = jeu.joueur.position if jeu != null and jeu.get("joueur") != null else Vector2.ZERO
		for i in int(ceil(n * PORTEE * PORTEE / (R.DEMI * R.DEMI))):
			var q := c + Vector2(r.randf_range(-PORTEE, PORTEE), r.randf_range(-PORTEE, PORTEE))
			var k := _cle_m(q)
			var nom := _nom_m(k)
			if not _morceaux.has(k) or _ajouts.get(nom, []).size() >= 6:
				continue
			var g := r.randi()
			var o = _poser("brindille", q, Color.WHITE, g)
			o.set_meta("m", k)
			o.set_meta("ajout", true)
			_morceaux[k]["objets"].append(o)
			if not _ajouts.has(nom):
				_ajouts[nom] = []
			_ajouts[nom].append(["brindille", snappedf(q.x, 0.1), snappedf(q.y, 0.1), g])
		return
	for i in n:
		_poser("brindille", Vector2(r.randf_range(-R.DEMI, R.DEMI), r.randf_range(-R.DEMI, R.DEMI)), Color.WHITE, r.randi())


func retirer(o) -> void:
	if ouvert and o.has_meta("m"):
		var km: Vector2i = o.get_meta("m")
		var nom := _nom_m(km)
		if o.has_meta("rang"):
			if not _changes.has(nom):
				_changes[nom] = {}
			_changes[nom][str(o.get_meta("rang"))] = null
		elif _ajouts.has(nom):
			_ajouts[nom] = _ajouts[nom].filter(func(e): return int(e[3]) != o.graine)
		if _morceaux.has(km):
			_morceaux[km]["objets"].erase(o)
	_defaire(o)


func _defaire(o) -> void:
	var k := _cle(o.position)
	if _grille.has(k):
		_grille[k].erase(o)
	var ko := _cle_ombre(o.position)
	if _ombres.has(ko):
		_ombres[ko][1].erase(o)
		if _ombres[ko][1].is_empty() and ouvert:
			# (plus rien dans cette case : son dessin s'en va avec)
			if _ombres[ko][0] != null:
				_ombres[ko][0].queue_free()
			_ombres.erase(ko)
		elif _ombres[ko][0] != null:
			_ombres[ko][0].queue_redraw()
	_effaces.erase(o)
	objets.erase(o)
	o.queue_free()


func _cle(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CASE)), int(floor(p.y / CASE)))


func autour(p: Vector2, rayon: float) -> Array:
	var out := []
	var a := _cle(p - Vector2(rayon, rayon))
	var b := _cle(p + Vector2(rayon, rayon))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for o in _grille.get(Vector2i(x, y), []):
				if is_instance_valid(o) and p.distance_to(o.position) <= rayon:
					out.append(o)
	return out


# ce qui est à prendre le plus près (null : rien à portée)
func plus_proche(p: Vector2, rayon: float):
	var meilleur = null
	var d0 := rayon
	for o in autour(p, rayon):
		if o.epuise():
			continue
		var d: float = p.distance_to(o.position)
		if d < d0:
			d0 = d
			meilleur = o
	return meilleur


# le calque des parois passe juste au-dessus de la nappe du temps qu'il fait (scripts/temps_sol.gd), dans la scène
func relief_au_dessus(scene: Node2D) -> void:
	if _sol_relief == null:
		return
	var nappe: Node = scene.get_node_or_null("TempsSol")
	if nappe == null:
		return
	_sol_relief.get_parent().remove_child(_sol_relief)
	scene.add_child(_sol_relief)
	scene.move_child(_sol_relief, nappe.get_index() + 1)


# un pas qui bute sur les troncs et les rochers, et reste dans le lieu
func repousser(p: Vector2, r: float) -> Vector2:
	for o in autour(p, r + 22.0):
		var ro: float = o.rayon
		if ro <= 0.0:
			continue
		var d: Vector2 = p - o.position
		var m := r + ro
		var l := d.length()
		if l < m:
			p = (o.position + d / l * m) if l > 0.001 else p + Vector2(m, 0)
	if ouvert:
		# (ni dans l'eau, ni dans une crête : scripts/carte.gd)
		return carte.retenir(p) if carte != null else p
	return Vector2(clampf(p.x, -R.DEMI, R.DEMI), clampf(p.y, -R.DEMI, R.DEMI))


# --- un lieu sans bord : ses morceaux (MONDE-OUVERT.md, étape 2) ---

func _cle_m(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / MORCEAU)), int(floor(p.y / MORCEAU)))


static func _nom_m(k: Vector2i) -> String:
	return "%d,%d" % [k.x, k.y]


# chaque image : fabriquer ce qui manque autour de p (le morceau le plus proche ; tous d'un coup si « tout »), défaire ce qui est loin
func suivre(p: Vector2, tout := false) -> void:
	for k in _morceaux.keys():
		var c := (Vector2(k) + Vector2(0.5, 0.5)) * MORCEAU
		if maxf(absf(c.x - p.x), absf(c.y - p.y)) > OUBLI:
			_oublier(k)
	var a := _cle_m(p - Vector2(PORTEE, PORTEE))
	var b := _cle_m(p + Vector2(PORTEE, PORTEE))
	var manque: Array = []
	var d0 := INF
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var k := Vector2i(x, y)
			if _morceaux.has(k):
				continue
			var d := ((Vector2(k) + Vector2(0.5, 0.5)) * MORCEAU).distance_squared_to(p)
			if tout:
				manque.append(k)
			elif d < d0:
				d0 = d
				manque = [k]
	for k in manque:
		_fabriquer(k)


# ce qu'un morceau contient, tiré de la graine du lieu et de sa place (toujours le même) : [genre, place, ton, graine]. Les
# mêmes densités qu'un lieu fermé, rapportées à sa surface ; plus serré là où le bruit des bosquets est haut ; rien sur le réveil
func _plan_m(k: Vector2i) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(_graine, k.x, k.y))
	var rect := Rect2(Vector2(k) * MORCEAU, Vector2(MORCEAU, MORCEAU))
	var plan: Array = []
	if carte == null:
		_prevoir_lieu(r, plan, rect, _arbre, _mesures, "")
	else:
		# (le monde ouvert : chaque quart du morceau est du biome de sa région ; près d'une frontière, les quarts se mêlent)
		for qx in 2:
			for qy in 2:
				var quart := Rect2(rect.position + Vector2(qx, qy) * MORCEAU * 0.5, Vector2(MORCEAU, MORCEAU) * 0.5)
				var reg: Dictionary = carte.regions[carte.region_en(quart.get_center() + Vector2(r.randf_range(-130, 130), r.randf_range(-130, 130)))]
				if reg["eau"]:
					continue
				var L := lieu_de(str(reg["type"]))
				_prevoir_lieu(r, plan, quart, str(L["arbre"]), L["mesures"], str(reg["type"]))
				# une crête (deux biomes qui ne sont pas voisins dans Orvane) : des rochers serrés, on ne passe pas
				if carte.crete_en(quart.get_center()) < 1.0 or carte.crete_en(quart.position) < 1.0 or carte.crete_en(quart.end) < 1.0:
					for i in 44:
						var q := Decor._dans(r, quart)
						var g := r.randi()
						if carte.crete_en(q) < 0.45 + 0.25 * r.randf():
							plan.append(["rocher", q, "pierre", g, str(reg["type"])])
	# au réveil, de quoi faire un premier feu à portée (les mêmes, quel que soit le morceau où ils tombent)
	var r0 := RandomNumberGenerator.new()
	r0.seed = _graine + 31
	for i in 8:
		var q := Vector2(r0.randf_range(-120, 120), r0.randf_range(-90, 90)) if i < 6 else Vector2(r0.randf_range(-160, 160), r0.randf_range(-130, 130))
		var g := r0.randi()
		if rect.has_point(q):
			plan.append(["brindille" if i < 6 else "rocher", q, "" if i < 6 else "pierre", g, lieu if carte != null else ""])
	return plan


# ce qu'un rectangle d'un biome contient : les mêmes densités qu'un lieu fermé, rapportées à sa surface
func _prevoir_lieu(r: RandomNumberGenerator, plan: Array, rect: Rect2, arbre: String, mesures: Array, type: String) -> void:
	var ka := rect.get_area() / (4.0 * R.DEMI * R.DEMI)
	var couvert: float = mesures[0]
	_prevoir(r, plan, rect, arbre, (70.0 + 430.0 * couvert) * ka, "feuilles", _bosquets, 0.25 + couvert, type)
	_prevoir(r, plan, rect, "rocher", (40.0 + 140.0 * float(mesures[2])) * ka, "pierre", null, 1.0, type)
	_prevoir(r, plan, rect, "buisson", (40.0 + 110.0 * float(mesures[1])) * ka, "feuilles", _bosquets, 0.6, type)
	_prevoir(r, plan, rect, "touffe", (90.0 + 130.0 * (1.0 - couvert)) * ka, "herbe", null, 1.0, type)
	_prevoir(r, plan, rect, "brindille", 160.0 * ka, "", _bosquets, 0.6, type)


func _prevoir(r: RandomNumberGenerator, plan: Array, rect: Rect2, genre: String, combien: float, ton: String, bruit, densite: float, type: String) -> void:
	var n := Decor._nombre(r, combien)
	var poses := 0
	var essais := 0
	while poses < n and essais < n * 12:
		essais += 1
		var p := Decor._dans(r, rect)
		if p.length() < 150.0:
			continue
		if bruit != null:
			var v: float = bruit.get_noise_2d(p.x, p.y)
			if r.randf() > clampf(densite * 0.5 + v * 0.9, 0.04, 1.0):
				continue
		plan.append([genre, p, ton, r.randi(), type])
		poses += 1


var pire_ms := 0.0      # (la vitrine, --mesure) le morceau le plus long à fabriquer, et sa part d'objets

func _fabriquer(k: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	_fabriquer_(k)
	pire_ms = maxf(pire_ms, (Time.get_ticks_usec() - t0) / 1000.0)


func _fabriquer_(k: Vector2i) -> void:
	var nom := _nom_m(k)
	var changes: Dictionary = _changes.get(nom, {})
	var heure: float = float(jeu.horloge) if jeu != null and jeu.get("horloge") != null else 0.0
	var liste: Array = []
	var plan := _plan_m(k)
	for i in plan.size():
		var e: Array = plan[i]
		var c = changes.get(str(i), false)
		if c == null:
			continue
		var ici: Dictionary = lieu_de(str(e[4])) if carte != null else {}
		if carte != null and carte.nu(e[1]):
			continue
		var tons: Dictionary = ici["palette"] if carte != null else palette
		var o = _poser(str(e[0]), e[1], tons[e[2]] if e[2] != "" else Color.WHITE, int(e[3]), ici)
		o.set_meta("m", k)
		o.set_meta("rang", i)
		liste.append(o)
		if typeof(c) == TYPE_ARRAY and c.size() >= 5:
			# (ce qui repoussait a continué de repousser pendant qu'on était loin)
			var reste_a_pousser := float(c[2])
			if reste_a_pousser > 0.0:
				reste_a_pousser -= heure - float(c[4])
				if reste_a_pousser <= 0.0:
					changes.erase(str(i))
					continue
			o.reprendre(str(c[0]), int(c[1]), reste_a_pousser, int(c[3]) == 1)
	for e in _ajouts.get(nom, []):
		var o = _poser(str(e[0]), Vector2(float(e[1]), float(e[2])), Color.WHITE, int(e[3]))
		o.set_meta("m", k)
		o.set_meta("ajout", true)
		liste.append(o)
	var noeuds: Array = []
	var rect := Rect2(Vector2(k) * MORCEAU, Vector2(MORCEAU, MORCEAU))
	if _racine != null and carte != null:
		# (le décor de chaque quart : l'herbe, les plantes, les cailloux du biome de sa région ; rien sur l'eau)
		for qx in 2:
			for qy in 2:
				var quart := Rect2(rect.position + Vector2(qx, qy) * MORCEAU * 0.5, Vector2(MORCEAU, MORCEAU) * 0.5)
				var reg: Dictionary = carte.regions[carte.region_en(quart.get_center())]
				if reg["eau"]:
					continue
				var L := lieu_de(str(reg["type"]))
				if L["outils"].is_empty():
					L["outils"] = Decor.outils(L["parts"], L["palette"], _graine)
				# (dans une vallée de rivière, rien dans le lit ; dans un pays de relief, rien sur une paroi, sur un col)
				Decor.exclure = Callable(carte, "nu") if reg["riviere"] or carte.force(quart.get_center()) > 0.0 else Callable()
				noeuds.append_array(Decor.semer_dans(self, _calques, _terrain, L["parts"], L["palette"], hash(Vector3i(_graine + 7 + qx * 2 + qy, k.x, k.y)), _mobile, quart, L["outils"], liste))
		Decor.exclure = Callable()
	elif _racine != null and not _outils.is_empty():
		noeuds = Decor.semer_dans(self, _calques, _terrain, _parts, palette, hash(Vector3i(_graine + 7, k.x, k.y)), _mobile, rect, _outils, liste)
	_morceaux[k] = {"objets": liste, "noeuds": noeuds}


# ce qu'on a changé dans un morceau (un arbre abattu ou brûlé, un buisson cueilli, un rocher entamé), noté pour le retrouver
func _noter(k: Vector2i) -> void:
	var nom := _nom_m(k)
	var changes: Dictionary = _changes.get(nom, {})
	var heure: float = float(jeu.horloge) if jeu != null and jeu.get("horloge") != null else 0.0
	for o in _morceaux[k]["objets"]:
		if not is_instance_valid(o) or not o.has_meta("rang"):
			continue
		var i := str(o.get_meta("rang"))
		if o.intact():
			changes.erase(i)
		else:
			# (ce qui brûle quand on s'éloigne aura brûlé)
			var feu: bool = o.brule > 0.0
			var arbre: bool = o.genre == "arbre" or o.genre == "sapin"
			changes[i] = ["souche" if (feu and arbre) else o.genre, 0 if feu else o.reste, snappedf(o._repousse, 0.1), 1 if (o.calcine or feu) else 0, snappedf(heure, 0.1)]
	if changes.is_empty():
		_changes.erase(nom)
	else:
		_changes[nom] = changes


func _oublier(k: Vector2i) -> void:
	_noter(k)
	var m: Dictionary = _morceaux[k]
	for o in m["objets"]:
		if is_instance_valid(o):
			_defaire(o)
	for n in m["noeuds"]:
		if is_instance_valid(n):
			n.queue_free()
	_morceaux.erase(k)


# une partie gardée : ce qu'on a changé et ce qui est tombé, par morceau (le reste se refait de la graine)
func photo_ouvert() -> Dictionary:
	for k in _morceaux:
		_noter(k)
	return {"changes": _changes.duplicate(true), "ajouts": _ajouts.duplicate(true)}


func reprendre_ouvert(d: Dictionary) -> void:
	_changes = {}
	_ajouts = {}
	var c = d.get("changes", {})
	var a = d.get("ajouts", {})
	if typeof(c) == TYPE_DICTIONARY:
		_changes = c.duplicate(true)
	if typeof(a) == TYPE_DICTIONARY:
		_ajouts = a.duplicate(true)


# le vent ici, maintenant (environ 0,2 à 1,3) : le même calcul que le shader (shaders/vegetation_vent.gdshaderinc) ; pour le son
func vent(p: Vector2) -> float:
	var t := _temps
	var houle := 0.5 + 0.5 * sin(t * 0.29) * sin(t * 0.11 + 1.3)
	var q := Vector2((p.x + p.y * 0.35) / 520.0 - t * 0.31, (p.y - p.x * 0.35) / 900.0)
	var rafale := smoothstep(0.52, 0.92, _bruit(q) * (0.7 + 0.5 * houle))
	return 0.2 + 0.4 * houle + 0.75 * rafale


static func _hash(p: Vector2) -> float:
	var p3 := Vector3(p.x, p.y, p.x) * 0.1031
	p3 = p3 - p3.floor()
	p3 += Vector3.ONE * p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3.ONE * 33.33)
	var v := (p3.x + p3.y) * p3.z
	return v - floor(v)


static func _bruit(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1, 0))
	var c := _hash(i + Vector2(0, 1))
	var d := _hash(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


# --- chaque image : le vent, l'herbe autour de la veilleuse, le soleil des ombres, les couronnes qui s'effacent ---

func _process(delta: float) -> void:
	_temps = fmod(_temps + delta, 3600.0)
	if Objet.vegetation != null:
		Objet.vegetation.set_shader_parameter("temps", _temps)
	if _mat_herbe != null:
		_mat_herbe.set_shader_parameter("temps", _temps)
	for L in _lieux.values():
		if not L["outils"].is_empty():
			L["outils"]["mat"].set_shader_parameter("temps", _temps)
	if jeu == null:
		return
	var cam = jeu.get("camera")
	if _sol != null and cam != null and is_instance_valid(cam):
		var centre: Vector2 = cam.get_screen_center_position()
		var taille: Vector2 = get_viewport_rect().size / cam.zoom
		_sol.suivre(Rect2(centre - taille * 0.5 - Vector2(160, 160), taille + Vector2(320, 320)))
		if _sol_relief != null:
			_sol_relief.suivre(Rect2(centre - taille * 0.5 - Vector2(160, 160), taille + Vector2(320, 320)))
	if _mat_ombre != null and jeu.has_method("lumiere_du_jour"):
		var t := fmod(float(jeu.horloge), R.DUREE)
		var soir := R.DUREE * (1.0 - float(jeu.part_nuit))
		var u := clampf(t / soir, 0.0, 1.0)
		# (le matin, les ombres filent vers la droite, longues ; à midi, courtes, en bas à droite ; le soir, longues, vers le bas)
		var a := lerpf(0.12, 1.15, u)
		_mat_ombre.set_shader_parameter("soleil", Vector2(cos(a), sin(a) * 0.6) * (0.3 + 0.32 * (1.0 - sin(u * PI))))
		_mat_ombre.set_shader_parameter("jour", jeu.lumiere_du_jour())
	var j = jeu.get("joueur")
	if j == null or not is_instance_valid(j):
		return
	var p: Vector2 = j.position
	if ouvert:
		suivre(p)
	if _mat_herbe != null:
		_mat_herbe.set_shader_parameter("veilleuse", p)
	for L in _lieux.values():
		if not L["outils"].is_empty():
			L["outils"]["mat"].set_shader_parameter("veilleuse", p)
	for o in autour(p, 120.0):
		if o.couronne != null and not _effaces.has(o) and o.cache(p):
			_effaces[o] = true
	for o in _effaces.keys():
		if not is_instance_valid(o) or o.couronne == null:
			_effaces.erase(o)
			continue
		var cible := EFFACE if o.cache(p) else 1.0
		var c: Node2D = o.couronne
		c.self_modulate.a = move_toward(c.self_modulate.a, cible, delta * 2.6)
		if c.self_modulate.a >= 1.0 and cible >= 1.0:
			_effaces.erase(o)


# --- les ombres au sol : une case de 420 pixels les dessine toutes, une fois (et de nouveau quand un objet change) ---

func _cle_ombre(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CASE_OMBRE)), int(floor(p.y / CASE_OMBRE)))


func _case_ombre(k: Vector2i) -> void:
	if _ombres[k][0] != null or _racine == null:
		return
	var c := Decor.Calque.new()
	c.material = _mat_ombre
	var liste: Array = _ombres[k][1]
	var mobile := _mobile
	c.dessin = func(n: CanvasItem): _dessiner_ombres(n, liste, mobile)
	_calques[3].add_child(c)
	_ombres[k][0] = c


# un objet a changé (un arbre abattu, un rocher entamé) : son ombre aussi
func ombre_changee(o) -> void:
	var k := _cle_ombre(o.position)
	if _ombres.has(k) and _ombres[k][0] != null:
		_ombres[k][0].queue_redraw()


static func _dessiner_ombres(n: CanvasItem, liste: Array, mobile: bool) -> void:
	var p := Pinceau.new()
	p.commencer(n.get_canvas_item())
	for o in liste:
		if not is_instance_valid(o):
			continue
		for e in o.ombres():
			var portee: float = e[3]
			if portee > 0.0 and mobile:
				continue
			var h: float = e[4]
			var q: Vector2 = o.position + e[0]
			var rr: Vector2 = e[1]
			p.eventail(q, rr.x, rr.y, Color(portee, h / 100.0, 1.0, e[2]), Color(portee, h / 100.0, 0.0, e[2]), 18)
	p.finir()
