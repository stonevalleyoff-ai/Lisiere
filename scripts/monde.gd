extends Node2D
# Lisière — le lieu (scripts/monde.gd)
# Un carré de terre, tiré du biome d'Orvane qu'on joue : son couvert fait les arbres, son humidité les buissons et l'herbe, son
# altitude les rochers, sa température et son humidité la couleur du sol. Ce qui pousse à ces places, c'est l'herbier d'Orvane
# qui le dit, forme par forme, selon la part de chaque plante (scripts/flore.gd) : un bouleau, un cactus, un nénuphar ; sans
# herbier, des sapins s'il fait froid, des feuillus sinon. S'y ajoutent ce qu'on cueille et qui n'est qu'à Lisière : les fleurs
# des prés, les champignons des bois (le cèpe, l'amanite), au pied des arbres. Les objets sont rangés
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
const Flore := preload("res://scripts/flore.gd")
const Milieu := preload("res://scripts/milieu.gd")
const Pays := preload("res://scripts/biome_terrain.gd")
const Biomes := preload("res://scripts/biomes.gd")
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
const HERBES := 110            # les plants d'herbes d'un lieu (les six espèces de son herbier : scripts/botanique.gd) : cinq ou six par écran
const OUBLI := 2300.0          # plus loin, un morceau est défait : on ne garde que ce qu'on y a changé
# la version du plan (ce qu'un morceau contient, place par place) : une partie gardée retient ce qu'on a changé par le rang des
# places dans ce plan. 1 : chaque strate semée au hasard, une plante tirée par place selon sa seule part ; 2 : chaque place a
# son milieu (scripts/milieu.gd). Une partie gardée d'avant garde son plan jusqu'à sa fin (reprendre_ouvert).
const PLAN := 2
# la cueillette (par lieu de 4 200 pixels de côté) : les fleurs des prés (et ce que l'herbe du sol y ajoute), les champignons
# des bois (sous un couvert humide), les mares et leurs plantes d'eau (ce que la boue y ajoute)
const FLEURS := 20.0
const FLEURS_HERBE := 140.0
const SOL_NU := 35.0          # sur le sol nu (peu de couvert) : des groupes de plantes du sol en plus, de deux à quatre
const CHAMPIGNONS := 130.0
const EAUX := 10.0
const EAUX_BOUE := 80.0
# la hauteur de chaque forme à la mesure de son dessin (m) : la plante de l'herbier, plus haute ou plus basse, est plus grande ou
# plus petite que lui (taille_de). Les dessins eux-mêmes sont à l'échelle les uns des autres, une échelle resserrée (la hauteur à
# la puissance 0,4 : scripts/objet.gd, _mesurer ; scripts/flore_dessins.gd, mesurer) : un arbre de 12 m fait 85 pixels, deux fois
# la veilleuse ; un géant de 45 m, 147 ; un pionnier de 9 m, 72, et de 4,5 m, 55 ; un fruitier de 6 m, 64 ; un conifère de 20 m, 108
const HAUTEURS := {"arbre": 12.0, "pionnier": 9.0, "fruitier": 6.0, "geant": 45.0, "emergent": 45.0, "figuier": 20.0, "bouteille": 20.0,
	"sous_bois": 5.0, "palmier": 15.0, "paletuvier": 6.0, "fougere_arbre": 8.0, "conifere": 12.0,
	# (ce qui se dresse sur le sol, et dont la hauteur d'Orvane se voit aussi : un bambou de 8 m dépasse un bambou de 4 m)
	"cactus": 6.0, "bambou": 6.0, "roseau": 1.8, "jonc": 0.4, "riz": 1.2, "cereale": 1.0, "papyrus": 2.5, "grande_herbe": 1.5,
	"fougere": 0.8, "agave": 1.5, "succulente": 0.8}
const TAILLE_PUISSANCE := 0.4

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
var _zone_cache := Rect2()     # où, autour du pied d'un arbre posé, la veilleuse peut être cachée par lui : la plus grande (objet.gd, zone_cache)
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
# le milieu des plantes (scripts/milieu.gd) : le plan que suit ce monde (1 : celui d'une partie gardée d'avant), l'échantillon
# du plan de chaque biome (« » : le lieu lui-même) et les poids réglés sur lui, ce que la météo d'Orvane fait aux densités
var plan_version := PLAN
var _relief: FastNoiseLite           # le relief du lieu : le même bruit que celui du temps qu'il fait (scripts/climat.gd, preparer)
var _crue := 0.0                     # l'eau qui reste dans ses creux (scripts/climat.gd, crue_fond)
var _pays_calcul                     # ce qui sait lister les choses d'un pays (ses fondrières, ses fumerolles…) sans les poser
var _pays_cases := {}                # case du pays → ce qu'elle porte (scripts/biome_terrain.gd, _lister)
var _echantillons := {}
var _tables := {}
var _densites := {}


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
	# (la saison du monde : les fruits des arbres et les épis mûrissent l'été et l'automne ; scripts/flore.gd, maturite)
	Objet.saison = str(jeu.get("saison")) if jeu != null and jeu.get("saison") != null else "été"
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
			mat_relief.set_shader_parameter("fin", false)
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
	# (le relief : les creux où l'eau reste et vient d'abord, les buttes sèches ; le même que scripts/climat.gd, preparer)
	_relief = FastNoiseLite.new()
	_relief.seed = graine + 5
	_relief.frequency = 0.0017
	_relief.fractal_octaves = 2
	_crue = clampf((humid - 0.85) * 3.0, 0.0, 0.3)
	_arbre = arbre
	_mesures = [couvert, humid, alt]
	if ouvert:
		# (rien d'un coup : les morceaux autour du réveil, puis ceux qu'on approche)
		if _racine != null:
			_outils = Decor.outils(_parts, palette, graine)
			_mat_herbe = _outils["mat"]
		if carte != null:
			lieu_de(lieu)
			# (les parts du biome du réveil se règlent pendant qu'on charge, pas dans le premier morceau)
			_table(lieu)
		suivre(Vector2.ZERO, true)
		return
	_semer_tout(r, gardes)
	# le décor, l'herbe, les ombres, la lisière : une fois les objets posés (le décor se glisse autour d'eux)
	if _racine != null:
		Decor.rive = _rive_du_decor(Rect2(-R.DEMI, -R.DEMI, 2.0 * R.DEMI, 2.0 * R.DEMI), "", objets)
		_mat_herbe = Decor.semer(self, _calques, _terrain, _parts, palette, graine, _mobile)
		Decor.rive = Callable()
		for k in _ombres:
			_case_ombre(k)
		Decor.lisiere(self, palette, graine, _mobile)


# le lieu fermé : son plan (le même que celui d'un morceau du monde ouvert : scripts/milieu.gd), sur tout le carré ; ses poids
# sont réglés sur ce plan même. Une partie reprise retrouve ses objets tels qu'on les avait laissés, à leur place.
func _semer_tout(r: RandomNumberGenerator, gardes: Array = []) -> void:
	var rect := Rect2(-R.DEMI, -R.DEMI, 2.0 * R.DEMI, 2.0 * R.DEMI)
	var ctx := _contexte("", rect)
	var plan: Array = []
	Milieu.prevoir(ctx, r, rect, plan)
	# au réveil, de quoi faire un premier feu à portée
	for i in 6:
		plan.append(["brindille", Vector2(r.randf_range(-120, 120), r.randf_range(-90, 90)), "", r.randi(), "", -1])
	for i in 2:
		plan.append(["rocher", Vector2(r.randf_range(-160, 160), r.randf_range(-130, 130)), "pierre", r.randi(), "", -1])
	# (la cueillette : sa propre graine, après tout le reste)
	var r2 := RandomNumberGenerator.new()
	r2.seed = _graine + 911
	Milieu.cueillette(ctx, r2, rect, plan, _arbres_du_plan(plan, rect))
	var ech := Milieu.echantillon(plan)
	ech["aire"] = rect.get_area()
	_echantillons[""] = ech
	_tables.erase("")
	if not gardes.is_empty():
		_reposer(gardes)
		return
	for e in plan:
		_poser(str(e[0]), e[1], palette[e[2]] if e[2] != "" else Color.WHITE, int(e[3]), {}, int(e[5]))


# --- une partie gardée ---

# chaque objet, tel qu'il est : [espèce, genre, x, y, graine, reste, repousse, brûlé] (une souche était un arbre, son espèce le
# dit) ; un arbre qui porte des fruits, en plus : [ses fruits, ceux tombés à son pied, le temps avant qu'il en porte de nouveau]
func photo_objets() -> Array:
	var out := []
	for o in objets:
		if is_instance_valid(o):
			# (ce qui brûle au moment de garder aura brûlé : un arbre en feu est gardé en souche noire)
			var feu: bool = o.brule > 0.0
			var arbre: bool = o.genre == "arbre" or o.genre == "sapin"
			# (ce que le lieu a semé à sa place — une strate, d'où la plante se retire de sa graine —, sinon son genre)
			var x := [o.semis if o.semis != "" else o._espece, "souche" if (feu and arbre) else o.genre, snappedf(o.position.x, 0.1), snappedf(o.position.y, 0.1), o.graine,
				0 if feu else o.reste, snappedf(o._repousse, 0.1), 1 if (o.calcine or feu) else 0]
			if o.fruits_plein > 0 or o.tombes_plein > 0:
				x.append_array([o.fruits, o.tombes, snappedf(o._repousse_fruits, 0.1)])
			# (son milieu, en dernier : « m » et son nombre ; la plante s'en retire comme elle en était venue)
			if o.has_meta("milieu"):
				x.append("m%d" % int(o.get_meta("milieu")))
			out.append(x)
	return out


func _reposer(gardes: Array) -> void:
	for g0 in gardes:
		if typeof(g0) != TYPE_ARRAY or g0.size() < 7:
			continue
		# (le milieu de sa place, s'il est gardé ; une partie gardée d'avant n'en a pas : sa plante se tire comme avant, de sa
		# graine et de sa seule part)
		var g: Array = g0
		var milieu := -1
		if typeof(g.back()) == TYPE_STRING and str(g.back()).begins_with("m"):
			milieu = int(str(g.back()).substr(1))
			g = g.slice(0, g.size() - 1)
		var espece := str(g[0])
		if (not Objet.BUTIN.has(espece) and Flore.strate_de(espece) == "") or espece == "souche":
			continue
		var ton := str(TONS.get(espece, ""))
		var o = _poser(espece, Vector2(float(g[2]), float(g[3])), palette[ton] if ton != "" else Color.WHITE, int(g[4]), {}, milieu)
		if o == null and milieu >= 0:
			# (l'herbier a changé depuis, et sa place ne porterait plus rien : ce qu'on avait laissé reste, tiré de sa seule part)
			o = _poser(espece, Vector2(float(g[2]), float(g[3])), palette[ton] if ton != "" else Color.WHITE, int(g[4]))
		if o != null:
			o.reprendre(str(g[1]), int(g[5]), float(g[6]), g.size() > 7 and int(g[7]) == 1)
			if g.size() > 10:
				o.reprendre_fruits(int(g[8]), int(g[9]), float(g[10]))


# le ton du lieu que prend ce qu'on sème
const TONS := {"arbre": "feuilles", "sapin": "feuilles", "buisson": "feuilles", "rocher": "pierre", "touffe": "herbe", "sol": "herbe",
	"fleur": "herbe", "eau": "feuilles"}


# les plantes du lieu, rangées par strate (scripts/flore.gd) : les arbres (un feuillu, un bouleau, un conifère, un palmier…), les
# buissons, le sol (les herbes, les fleurs, les lichens, les plantes grasses…), l'eau, les champignons d'une grotte. Chacune a son
# poids (sa part du lieu), le genre d'objet qu'elle devient, la forme que Lisière dessine, et ce que le dessin prend d'elle
# (objet.porter_plante) : sa couleur (lue une fois sur son dessin de l'herbier ; celle de ses fleurs aussi), sa taille (d'après sa
# hauteur vraie), son stade, ses défenses, ses caractères. Sans herbier, rien : les arbres suivent la température, le sol est
# d'herbe, les objets gardent les couleurs du lieu.
func _lire_flore(_arbre: String) -> void:
	flore = _flore_de(lieu)


func _flore_de(type: String, _arbre: String = "") -> Dictionary:
	var out := {}
	for e in Orvane.plantes(type):
		var so := Flore.sorte(e)
		var genre: String = so["genre"]
		var forme: String = so["forme"]
		var strate: String = so["strate"]
		var h := float(e.get("hauteur_m", 1.0))
		var k := taille_de(forme, genre, strate, h)
		if not out.has(strate):
			out[strate] = []
		var id := str(e["id"])
		out[strate].append({"id": id, "poids": maxf(0.02, float(e.get("part", 0.0))), "taille": k, "port": str(e.get("port", forme)),
			"forme": forme, "genre": genre, "planche": so["planche"], "nom": str(e.get("nom", "")), "stade": str(e.get("stade", "")),
			"defense": e.get("defense", []), "caracteres": e.get("caracteres", []),
			"couleur": _couleur_plante(id, type) if genre != "champignon" else null,
			"fleur": _couleur_fleur(id, type) if Flore.FLEURISSENT.has(forme) else null})
	return out


# la taille d'une plante de l'herbier, d'après sa hauteur d'Orvane (en mètres) : ce par quoi son dessin est agrandi ou réduit. À
# la hauteur de sa forme (HAUTEURS), elle est à la mesure de son dessin ; plus haute ou plus basse, elle suit une échelle
# resserrée (TAILLE_PUISSANCE) : un conifère de 20 m est d'un quart plus haut que le sapin du jeu, un pionnier de 4,5 m d'un
# quart plus petit qu'un pionnier de 9 m. Un arbre, de 0,6 à 1,5 ; un buisson, de 0,8 à 1,3 ; au sol, de 0,75 à 1,3
static func taille_de(forme: String, genre: String, strate: String, h: float) -> float:
	if h <= 0.0:
		return 1.0
	if strate == "arbre":
		return clampf(pow(h / float(HAUTEURS.get(forme, 12.0)), TAILLE_PUISSANCE), 0.6, 1.5)
	if genre == "buisson":
		return clampf(pow(h / 1.5, 0.35), 0.8, 1.3)
	if HAUTEURS.has(forme):
		return clampf(pow(h / float(HAUTEURS[forme]), TAILLE_PUISSANCE), 0.75, 1.3)
	return 1.0


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
	var sous_terre := str(info.get("milieu", "terrestre")) == "souterrain"
	# (l'eau qui reste dans les creux d'un biome détrempé : la crue de fond de scripts/climat.gd, d'après son humidité vraie)
	var crue := 0.0 if sous_terre else clampf((float(axes.get("humidite", 0.5)) - 0.85) * 3.0, 0.0, 0.3)
	if sous_terre:
		# (une grotte : pour Orvane un lieu couvert et humide — sa voûte ; ici, de la roche nue, sans herbe ni arbres)
		axes = axes.duplicate()
		axes["couvert"] = 0.0
		axes["humidite"] = 0.5
		axes["altitude"] = 0.9
	var pal := couleurs(axes)
	var parts := Decor.parts(axes)
	if sous_terre:
		for k in ["herbe", "litiere", "neige", "lande"]:
			parts[k] = 0.0
		parts["mousse"] = 0.08
		parts["cailloux"] = 0.5
		parts["fentes"] = 0.3
		pal = pal.duplicate()
		pal["terre"] = pal["terre"].lerp(Color(0.33, 0.32, 0.31), 0.75)
		pal["terre_claire"] = pal["terre_claire"].lerp(Color(0.43, 0.42, 0.4), 0.75)
		pal["terre_sombre"] = pal["terre_sombre"].lerp(Color(0.21, 0.21, 0.21), 0.75)
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
		"flore": _flore_de(type, arbre), "outils": {}, "climat": {"froid": float(parts["froid"]), "humide": float(parts["humide"])},
		"sous_terre": sous_terre, "crue": crue}
	_lieux[type] = L
	return L


# les plantes d'un biome viennent d'arriver (son herbier se lit en approchant) : ce qu'on y sèmera désormais les porte ; les
# morceaux déjà faits de ce biome (une partie reprise loin du réveil, un pas plus vite que la lecture) l'ont été sans elles :
# on les refait, avec ce qu'on y avait changé
func flore_arrivee(type: String) -> void:
	_tables.erase(type)
	_densites.erase(type)
	if _lieux.has(type):
		_lieux[type]["flore"] = _flore_de(type, str(_lieux[type]["arbre"]))
		# (ses parts se règlent maintenant, une fois, avant que ses morceaux soient refaits)
		if carte != null and not _lieux[type]["flore"].is_empty():
			_table(type)
		for k in _morceaux.keys():
			if _morceaux[k].get("types", {}).has(type):
				_oublier(k)
				_fabriquer(k)


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


# la couleur de ses fleurs : celle de son dessin de l'herbier, s'il est en fleurs, ramenée vers les encres du carnet (un rose vif
# devient un vieux rose) ; sinon l'une des encres des fleurs, tirée de son nom
const ENCRES_FLEURS := [P.PAPIER, P.BRAISE_COEUR, P.PEUR, P.BRAISE_ROUGE, P.LUNE, P.AUBE]

func _couleur_fleur(id: String, type: String) -> Color:
	var tex: ImageTexture = Orvane.texture_plante(id, 40.0, type)
	var somme := Color(0, 0, 0, 0)
	var n := 0
	if tex != null:
		var img := tex.get_image()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.s > 0.3 and (c.h < 0.15 or c.h > 0.47):
					somme += c
					n += 1
	if n < 3:
		return Color(ENCRES_FLEURS[absi(hash(id)) % ENCRES_FLEURS.size()]).lerp(P.PAPIER, 0.08)
	var vraie := Color(somme.r / n, somme.g / n, somme.b / n)
	var proche: Color = ENCRES_FLEURS[0]
	for e in ENCRES_FLEURS:
		if Vector3(e.r - vraie.r, e.g - vraie.g, e.b - vraie.b).length() < Vector3(proche.r - vraie.r, proche.g - vraie.g, proche.b - vraie.b).length():
			proche = e
	return vraie.lerp(proche, 0.5)


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


# (ici : le biome où il pousse, dans le monde ouvert ; sinon celui du lieu). genre : ce que le plan a semé là — un genre (un
# rocher, une brindille, une fleur des prés, un cèpe), ou une strate (un arbre, un buisson, une touffe du sol, une mare), dont la
# plante se tire de sa graine dans l'herbier du lieu. Une place d'arbre ou de buisson dont l'herbier n'a pas la strate revient aux
# plantes du sol (pas d'arbre sur la banquise : des lichens, en plaques). Rend l'objet ; null si rien n'y pousse (une mare dans un
# lieu sans plantes d'eau)
# milieu : celui de sa place dans le plan (scripts/milieu.gd), -1 sans plan (une partie gardée d'avant, une plante posée à la
# main) : la plante se tire alors de sa seule part
# sur_la_carte : rien ne se pose là où la carte dit que rien ne pousse (l'eau, une paroi, la roche) — demandé en dernier, quand
# on sait que la place servira : la carte est lente à lire
func _poser(genre: String, p: Vector2, couleur: Color, graine: int, ici: Dictionary = {}, milieu: int = -1, sur_la_carte: bool = false):
	if not ici.is_empty():
		Objet.climat = ici["climat"]
	var fl: Dictionary = ici["flore"] if not ici.is_empty() else flore
	# (là où l'herbier n'a pas d'arbre — la banquise, le volcan, le désert —, le bois mort est rare : une brindille sur quatre ; au
	# réveil, de quoi faire un premier feu reste à portée)
	if genre == "brindille" and not fl.is_empty() and not fl.has("arbre") and graine % 4 != 0 and p.length() > 200.0:
		return null
	var vrai := genre
	var pl := {}
	var strate := Flore.strate_de(genre)
	var place := false
	if milieu >= 0 and strate == "":
		# (la cueillette de Lisière : il y a plus de places que de fleurs, de champignons ; la météo d'Orvane dit combien servent)
		if genre in ["fleur", "cepe", "amanite"]:
			var d: Dictionary = _densite(str(ici.get("type", "")))
			if float(absi(hash(absi(graine) % 10007 + 77003)) % 10007) / 10007.0 >= float(d["fleurs" if genre == "fleur" else "champignons"]) / R.MILIEU_CUEILLETTE_RESERVE:
				return null
	elif milieu >= 0 and fl.is_empty():
		# (sans herbier : un arbre, un buisson, une touffe, deux par groupe ; rien de ce qui était offert en plus, pas de mare)
		if strate == "eau" or (milieu & Milieu.EN_PLUS) or Milieu.rang(milieu) >= 2:
			return null
		if strate == "sol":
			vrai = "touffe"
	elif milieu >= 0:
		# (une place du plan : sa plante se tire selon sa part et son goût pour ce milieu ; une place d'arbre ou de buisson dont
		# l'herbier n'a pas la strate revient aux plantes du sol ; une place dont aucune ne veut reste vide)
		var st := strate
		var m := milieu
		if not fl.has(st) and st in ["arbre", "buisson"]:
			if st == "arbre":
				m = Milieu.sans_arbres(m) & Milieu.MILIEUX
			st = "sol"
			couleur = (ici["palette"] if not ici.is_empty() else palette).get("herbe", couleur)
		var tb = _table(str(ici.get("type", ""))).get(st)
		if tb == null:
			return null
		var k := absi(graine) % 10007
		pl = Milieu.tirer(tb, m, k, Milieu.cellule(st, p, k, m, _graine))
		if pl.is_empty():
			return null
		vrai = str(pl["genre"])
		place = true
	elif strate != "":
		pl = _plante(strate, graine, fl)
		if pl.is_empty() and not fl.is_empty() and strate in ["arbre", "buisson"]:
			pl = _plante("sol", graine, fl)
			couleur = (ici["palette"] if not ici.is_empty() else palette).get("herbe", couleur)
		if not pl.is_empty():
			vrai = str(pl["genre"])
		elif strate == "eau" or not fl.is_empty():
			return null
		elif strate == "sol":
			vrai = "touffe"
	if sur_la_carte and carte != null and carte.nu(p):
		return null
	var o = Objet.new()
	o.preparer(vrai, couleur, graine)
	o.semis = genre
	if place:
		o.set_meta("milieu", milieu)
	if vrai == "herbe":
		o.porter_herbe(lieu)
	if not pl.is_empty():
		o.porter_plante(pl)
	elif vrai == "fleur":
		# (une fleur des prés, de Lisière : l'une des encres des fleurs du lieu)
		var fleurs: Array = (ici["palette"] if not ici.is_empty() else palette).get("fleurs", [P.PAPIER])
		o.couleur_fleur = fleurs[absi(graine) % fleurs.size()]
	o.position = p
	add_child(o)
	objets.append(o)
	if o.couronne != null:
		# (là où elle peut le cacher : les couronnes qui la cachent ne se cherchent que là, à chaque image)
		var z: Rect2 = o.zone_cache()
		if z.has_area():
			_zone_cache = z if not _zone_cache.has_area() else _zone_cache.merge(z)
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
			# (dans le biome de l'endroit : sous un ciel sans arbres, il en tombe peu)
			var o = _poser("brindille", q, Color.WHITE, g, lieu_de(carte.type_en(q)) if carte != null else {})
			if o == null:
				continue
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


# les arbres dont la couronne peut cacher la veilleuse debout en p : ceux dont le pied est là où la plus grande zone de ce qui
# est posé le permet (_zone_cache : au sud d'elle, jusqu'à la hauteur du plus grand — un géant, un émergent, plus haut que les
# autres d'après sa hauteur d'Orvane). Un rectangle, pas un cercle : moins de cases qu'un rayon qui irait aussi loin
func couronnes_pres(p: Vector2) -> Array:
	var out := []
	if not _zone_cache.has_area():
		return out
	var ou := Rect2(p - _zone_cache.end, _zone_cache.size).grow(1.0)
	var a := _cle(ou.position)
	var b := _cle(ou.end)
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for o in _grille.get(Vector2i(x, y), []):
				if is_instance_valid(o) and o.couronne != null and ou.has_point(o.position):
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
	# (ni dans ce qu'elle a posé : la tente, l'établi ; scripts/atelier.gd)
	var camp = jeu.get("atelier") if jeu != null else null
	if camp != null:
		p = camp.buter(p, r)
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
	if plan_version < PLAN:
		return _plan_m_1(k)
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(_graine, k.x, k.y))
	var rect := Rect2(Vector2(k) * MORCEAU, Vector2(MORCEAU, MORCEAU))
	var plan: Array = []
	# (la cueillette a sa propre graine, et vient après tout le reste)
	var cueillette: Array = []
	var rc := RandomNumberGenerator.new()
	rc.seed = hash(Vector3i(_graine + 911, k.x, k.y))
	if carte == null:
		var ctx := _contexte("", rect)
		Milieu.prevoir(ctx, r, rect, plan)
		Milieu.cueillette(ctx, rc, rect, cueillette, _arbres_du_plan(plan, rect))
	else:
		# (le monde ouvert : chaque quart du morceau est du biome de sa région ; près d'une frontière, les quarts se mêlent)
		for qx in 2:
			for qy in 2:
				var quart := Rect2(rect.position + Vector2(qx, qy) * MORCEAU * 0.5, Vector2(MORCEAU, MORCEAU) * 0.5)
				var reg: Dictionary = carte.regions[carte.region_en(quart.get_center() + Vector2(r.randf_range(-130, 130), r.randf_range(-130, 130)))]
				if reg["eau"]:
					continue
				var type := str(reg["type"])
				var L := lieu_de(type)
				if bool(L.get("sous_terre", false)):
					# (une grotte : de la pierre, et ses champignons — ceux de l'herbier d'Orvane, tirés selon leur part)
					_prevoir_lieu(r, plan, quart, str(L["arbre"]), L["mesures"], type)
				else:
					var ctx := _contexte(type, quart)
					_berges(ctx, quart)
					Milieu.prevoir(ctx, r, quart, plan)
					Milieu.cueillette(ctx, rc, quart, cueillette, _arbres_du_plan(plan, quart))
				# une crête (deux biomes qui ne sont pas voisins dans Orvane) : des rochers serrés, on ne passe pas
				if carte.crete_en(quart.get_center()) < 1.0 or carte.crete_en(quart.position) < 1.0 or carte.crete_en(quart.end) < 1.0:
					for i in 44:
						var q := Decor._dans(r, quart)
						var g := r.randi()
						if carte.crete_en(q) < 0.45 + 0.25 * r.randf():
							plan.append(["rocher", q, "pierre", g, type, -1])
	# au réveil, de quoi faire un premier feu à portée (les mêmes, quel que soit le morceau où ils tombent)
	var r0 := RandomNumberGenerator.new()
	r0.seed = _graine + 31
	for i in 8:
		var q := Vector2(r0.randf_range(-120, 120), r0.randf_range(-90, 90)) if i < 6 else Vector2(r0.randf_range(-160, 160), r0.randf_range(-130, 130))
		var g := r0.randi()
		if rect.has_point(q):
			plan.append(["brindille" if i < 6 else "rocher", q, "" if i < 6 else "pierre", g, lieu if carte != null else "", -1])
	plan.append_array(cueillette)
	return plan


# ce qui sert au plan d'un biome (scripts/milieu.gd, prevoir) : son terrain, les parts de son sol, ses mesures, le bruit des
# bosquets ; « » : le lieu lui-même (un lieu fermé, un lieu sans bord d'un seul biome). rect : le rectangle qu'on va prévoir
# (le monde ouvert : ce que la carte et le pays y mettent d'eau, de feu)
func _contexte(type: String, rect: Rect2 = Rect2()) -> Dictionary:
	var ctx: Dictionary
	if type == "":
		ctx = {"t": _terrain, "s": _parts, "mesures": _mesures, "bosquets": _bosquets, "arbre": _arbre, "type": type, "graine": _graine, "herbes": HERBES,
			"borne": 0.0 if ouvert else R.DEMI, "relief": _relief, "crue": _crue}
	else:
		var L := lieu_de(type)
		ctx = {"t": _terrain, "s": L["parts"], "mesures": L["mesures"], "bosquets": _bosquets, "arbre": str(L["arbre"]), "type": type, "graine": _graine, "herbes": HERBES,
			"borne": 0.0, "relief": _relief, "crue": float(L["crue"])}
	if rect.size.x > 0.0:
		_pays(ctx, rect, lieu if type == "" else type)
	return ctx


# ce que le pays met dans un rectangle (scripts/biome_terrain.gd : la banquise, le volcan, le marais, le désert), pour le plan :
# « eaux » (une fondrière, une mare gelée : rien n'y pousse, et une fondrière a sa rive : [où, son rayon, vrai si elle a une
# rive]), « feux » (une fumerolle, une faille, des scories : [où, jusqu'où ça brûle]), « dunes » ([où, son rayon]). Les cases
# du pays se listent ici comme le pays les posera (la même graine, la même place), sans rien poser
func _pays(ctx: Dictionary, rect: Rect2, type: String) -> void:
	if jeu == null or jeu.get("graine") == null or Biomes.de(type).is_empty():
		return
	var large := rect.grow(140.0)
	var a := Vector2i((large.position / Pays.CASE).floor())
	var b := Vector2i((large.end / Pays.CASE).floor())
	var eaux: Array = []
	var feux: Array = []
	var dunes: Array = []
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var k := Vector2i(x, y)
			for e in pays_case(k):
				var p: Vector2 = e["p"]
				var taille := float(e["taille"])
				if not large.grow(taille).has_point(p):
					continue
				match str(e["genre"]):
					"fondriere":
						eaux.append([p, taille, true])
					"mare":
						eaux.append([p, taille, false])
					"fumerolle":
						feux.append([p, R.MILIEU_FEU])
						eaux.append([p, 26.0, false])
					"faille":
						for q in e["trait"]:
							feux.append([q, R.MILIEU_FEU])
							eaux.append([q, float(e["large"]) + 8.0, false])
					"scories":
						feux.append([p, taille])
					"dune":
						dunes.append([p, taille * 0.7])
	ctx["eaux"] = eaux
	ctx["feux"] = feux
	ctx["dunes"] = dunes


# (pour le décor : ses roseaux) où est le bord de l'eau dans un rectangle : ce qui dit, pour un point, de 0 (non) à 1 s'il y
# est — la rive de l'eau qui reste dans les creux d'un lieu détrempé, le tour d'une mare (une plante d'eau parmi ces objets),
# d'une fondrière. Les eaux du rectangle sont cherchées une fois
func _rive_du_decor(rect: Rect2, type: String, objets_: Array) -> Callable:
	var crue := _crue if type == "" else float(lieu_de(type)["crue"])
	var niveau := lerpf(0.26, 0.5, crue) + 0.008 if crue > 0.01 else -1.0
	var large := rect.grow(70.0)
	# [où, son rayon, sa hauteur pour sa largeur, de combien on peut y entrer]
	var eaux: Array = []
	for o in objets_:
		if is_instance_valid(o) and o.genre == "aquatique" and large.has_point(o.position):
			eaux.append([o.position, float(o._rx), R.MILIEU_OVALE, -2.0])
	if not Biomes.de(lieu if type == "" else type).is_empty() and (rect.size.x <= 2.0 * MORCEAU or not ouvert):
		var a := Vector2i((rect.grow(120.0).position / Pays.CASE).floor())
		var b := Vector2i((rect.grow(120.0).end / Pays.CASE).floor())
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for e in _pays_cases.get(Vector2i(x, y), []):
					if str(e["genre"]) == "fondriere" and large.grow(float(e["taille"])).has_point(e["p"]):
						eaux.append([e["p"], float(e["taille"]), 0.82, 4.0])
	var relief := _relief
	return func(p: Vector2) -> float:
		for e in eaux:
			var c: Vector2 = e[0]
			if absf(p.x - c.x) > float(e[1]) + 26.0:
				continue
			var d: float = ((p - c) * Vector2(1.0, 1.0 / float(e[2]))).length() - float(e[1])
			if d > -float(e[3]) and d < 24.0:
				return 1.0
		if niveau > 0.0 and relief != null:
			return clampf(1.0 - absf(Milieu.relief_en({"relief": relief}, p) - niveau) / 0.04, 0.0, 1.0)
		return 0.0


# ce qu'une case du pays porte (scripts/biome_terrain.gd, _lister) : listée une seule fois — le pays reprend cette liste quand
# il pose la case, ou l'on reprend la sienne s'il l'a déjà posée
func pays_case(k: Vector2i) -> Array:
	var l = _pays_cases.get(k)
	if l != null:
		return l
	var pays = jeu.get("terrain") if jeu != null else null
	if pays != null and is_instance_valid(pays) and pays._cases.has(k):
		l = pays._cases[k]
	else:
		if _pays_calcul == null:
			_pays_calcul = Pays.new()
			_pays_calcul.jeu = jeu
		l = _pays_calcul._lister(k)
	if _pays_cases.size() > 900:
		_pays_cases.clear()
	_pays_cases[k] = l
	return l


# (l'échantillon d'un pays : le carré où l'on essaie son plan n'est pas chez lui ; on y met autant de fondrières, de
# fumerolles, de failles, de scories, de dunes qu'une de ses cases en porte — scripts/biomes.gd, « sorts » —, au hasard)
func _pays_factice(ctx: Dictionary, r: RandomNumberGenerator, rect: Rect2, type: String) -> void:
	var sorts: Dictionary = Biomes.de(type).get("sorts", {})
	if sorts.is_empty():
		return
	var cases := rect.get_area() / (Pays.CASE * Pays.CASE)
	var eaux: Array = []
	var feux: Array = []
	var dunes: Array = []
	for genre in ["fondriere", "mare", "fumerolle", "faille", "scories", "dune"]:
		for i in Decor._nombre(r, float(sorts.get(genre, 0.0)) * cases):
			var p := Decor._dans(r, rect)
			match genre:
				"fondriere":
					eaux.append([p, r.randf_range(42.0, 86.0), true])
				"mare":
					eaux.append([p, r.randf_range(34.0, 54.0), false])
				"fumerolle":
					feux.append([p, R.MILIEU_FEU])
					eaux.append([p, 26.0, false])
				"faille":
					var sens := Vector2.from_angle(r.randf() * TAU)
					var pas := r.randf_range(80.0, 160.0) * 2.0 / 7.0
					for j in 8:
						feux.append([p + sens * pas * (j - 3.5), R.MILIEU_FEU])
						eaux.append([p + sens * pas * (j - 3.5), 16.0, false])
				"scories":
					feux.append([p, r.randf_range(110.0, 200.0)])
				"dune":
					dunes.append([p, r.randf_range(150.0, 250.0) * 0.7])
	ctx["eaux"] = eaux
	ctx["feux"] = feux
	ctx["dunes"] = dunes


# (le monde ouvert) les berges près d'un quart de morceau : là où la terre touche l'eau d'une rivière, d'un lac, d'une mer —
# des points de la rive, et le sens où elle file. Rien si l'eau est loin (une seule lecture de la carte le dit)
func _berges(ctx: Dictionary, quart: Rect2) -> void:
	var c := quart.get_center()
	var pr: Array = carte.proches(c)
	var pres: bool = bool(carte.regions[int(pr[0])]["riviere"]) or bool(carte.regions[int(pr[0])]["eau"]) \
		or ((bool(carte.regions[int(pr[1])]["eau"]) or bool(carte.regions[int(pr[1])]["riviere"])) and float(pr[3]) - float(pr[2]) < 900.0)
	if not pres:
		return
	var berges: Array = []
	var sens := {}
	var pas := quart.size.x / 6.0
	for x in 6:
		for y in 6:
			var q := quart.position + Vector2(x + 0.5, y + 0.5) * pas
			if carte.mouille(q):
				continue
			# (vers où est l'eau, à quarante pixels ?)
			var vers := Vector2.ZERO
			for d in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				if carte.mouille(q + d * 40.0):
					vers += d
			if vers == Vector2.ZERO:
				continue
			berges.append(q)
			sens[q] = vers.normalized().orthogonal()
	if not berges.is_empty():
		ctx["berges"] = berges
		ctx["berges_sens"] = sens


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_PREDELETE and _pays_calcul != null and is_instance_valid(_pays_calcul):
		_pays_calcul.free()


# l'échantillon du plan d'un biome : combien de places de chaque milieu (scripts/milieu.gd, echantillon). Un lieu fermé : son
# plan même (_semer_tout) ; le monde ouvert : le plan de quarts de morceau à part, toujours les mêmes, tirés de la graine. Ils
# sont épars (à ÉPARS côtés l'un de l'autre) : un carré d'un seul tenant n'a que quelques bosquets, quelques creux, et les
# buissons, qui vont près des bosquets, y auraient deux ou trois fois trop de places, ou trop peu — leurs poids aussi
const EPARS := 7.0
func _echantillon(type: String) -> Dictionary:
	if _echantillons.has(type):
		return _echantillons[type]
	var ctx := _contexte(type)
	ctx["borne"] = 0.0
	var r := RandomNumberGenerator.new()
	r.seed = hash([_graine, type, "échantillon"])
	var cote := MORCEAU * (0.5 if carte != null else 1.0)
	var n := int(R.MILIEU_ECHANTILLON / cote)
	var plan: Array = []
	var coin := Vector2(40000.0, 40000.0)
	for x in n:
		for y in n:
			var ici := Rect2(coin + Vector2(x, y) * cote * EPARS + Vector2(r.randf(), r.randf()) * cote * (EPARS - 1.0), Vector2(cote, cote))
			_pays_factice(ctx, r, ici.grow(140.0), lieu if type == "" else type)
			Milieu.prevoir(ctx, r, ici, plan)
	var ech := Milieu.echantillon(plan)
	ech["aire"] = n * n * cote * cote
	_echantillons[type] = ech
	return ech


# les poids de chaque plante d'un biome, réglés sur son plan pour que chacune garde sa part d'Orvane (scripts/milieu.gd, regler) ;
# refaits quand son herbier arrive (flore_arrivee)
func _table(type: String) -> Dictionary:
	if _tables.has(type):
		return _tables[type]
	var seul := type == ""
	var fl: Dictionary = flore if seul else lieu_de(type)["flore"]
	var ech := _echantillon(type)
	var ctx := _contexte(type)
	var tb := Milieu.regler(fl, ech, Milieu.cibles(ctx["mesures"], ctx["s"], float(ech["aire"]), Orvane.meteo(lieu if seul else type), ech, fl))
	_tables[type] = tb
	if OS.has_environment("LISIERE_MILIEU"):
		for st in tb:
			var n_tr := 0
			var n_tot := 0
			for cle in ech.get(st, {}):
				n_tot += int(ech[st][cle])
				if int(cle) & Milieu.TRONE:
					n_tr += int(ech[st][cle])
			print("milieu ", type, " ", st, " : ", n_tot, " groupes (", n_tr, " trônes), ", ech.get(st, {}).size(), " sortes ; poids ", Array(tb[st]["poids"]).map(func(x): return snappedf(x, 0.001)), " ; tailles ", Array(tb[st]["tailles"]))
	return tb


# ce que la météo d'Orvane fait aux densités d'un biome, ce cycle (scripts/milieu.gd, densites)
func _densite(type: String) -> Dictionary:
	if not _densites.has(type):
		_densites[type] = Milieu.densites(Orvane.meteo(lieu if type == "" else type))
	return _densites[type]


# le plan d'une partie gardée d'avant (la version 1) : chaque strate semée à sa densité, sans milieu
func _plan_m_1(k: Vector2i) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(_graine, k.x, k.y))
	var rect := Rect2(Vector2(k) * MORCEAU, Vector2(MORCEAU, MORCEAU))
	var plan: Array = []
	# (la cueillette a sa propre graine, et vient après tout le reste : ce qu'une partie gardée a noté par rang ne bouge pas)
	var cueillette: Array = []
	var rc := RandomNumberGenerator.new()
	rc.seed = hash(Vector3i(_graine + 911, k.x, k.y))
	if carte == null:
		_prevoir_lieu(r, plan, rect, _arbre, _mesures, "")
		_prevoir_cueillette(rc, cueillette, rect, "", _arbres_du_plan(plan, rect))
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
				_prevoir_cueillette(rc, cueillette, quart, str(reg["type"]), _arbres_du_plan(plan, quart))
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
	plan.append_array(cueillette)
	return plan


# les places d'arbres d'un plan, dans ce rectangle (les champignons des bois poussent à leur pied)
static func _arbres_du_plan(plan: Array, rect: Rect2) -> Array:
	var out: Array = []
	for e in plan:
		if (e[0] == "arbre" or e[0] == "sapin") and rect.has_point(e[1]):
			out.append(e[1])
	return out


# ce qu'on cueille dans un rectangle d'un biome, en plus de ses plantes : des fleurs des prés là où le sol est herbeux, des
# champignons des bois au pied des arbres (sous un couvert humide ; une amanite sur trois), des mares pour ses plantes d'eau
# (là où le sol est boueux ; un biome sans plantes d'eau n'en a pas : la place reste vide)
func _prevoir_cueillette(r: RandomNumberGenerator, plan: Array, rect: Rect2, type: String, arbres: Array) -> void:
	if type != "" and bool(lieu_de(type).get("sous_terre", false)):
		return
	var s: Dictionary = lieu_de(type)["parts"] if type != "" else _parts
	if s.is_empty():
		return
	var ka := rect.get_area() / (4.0 * R.DEMI * R.DEMI)
	var froid := float(s["froid"])
	var sec := float(s["sec"])
	var terrain := not _terrain.is_empty()
	var n := Decor._nombre(r, (FLEURS + FLEURS_HERBE * float(s["herbe"])) * (1.0 - froid * 0.8) * (1.0 - sec * 0.85) * ka)
	var essais := n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var g := r.randi()
		if q.length() < 150.0:
			continue
		if terrain:
			var ici := Decor.sol_ici(_terrain, s, q)
			if r.randf() > 0.15 + float(ici["herbe"]) * 0.85 or float(ici["neige"]) > 0.3:
				continue
		plan.append(["fleur", q, "herbe", g, type])
		n -= 1
	n = Decor._nombre(r, CHAMPIGNONS * float(s["couvert"]) * clampf((float(s["humide"]) - 0.45) * 2.5, 0.0, 1.0) * (1.0 - froid * 0.7) * ka)
	essais = n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		if not arbres.is_empty() and r.randf() < 0.7:
			q = arbres[r.randi() % arbres.size()] + Vector2.from_angle(r.randf() * TAU) * r.randf_range(15.0, 34.0) * Vector2(1.0, 0.6)
		var g := r.randi()
		var amanite := r.randf() < Flore.AMANITES
		# (au pied d'un arbre, mais dans ce morceau : un morceau ne pose rien chez son voisin)
		if q.length() < 150.0 or not rect.has_point(q):
			continue
		if terrain and float(Decor.sol_ici(_terrain, s, q)["neige"]) > 0.3:
			continue
		plan.append(["amanite" if amanite else "cepe", q, "", g, type])
		n -= 1
	n = Decor._nombre(r, (EAUX + EAUX_BOUE * float(s["boue"])) * ka)
	essais = n * 6
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var g := r.randi()
		if q.length() < 200.0:
			continue
		if terrain and float(Decor.sol_ici(_terrain, s, q)["boue"]) < 0.5 and r.randf() > 0.3:
			continue
		plan.append(["eau", q, "feuilles", g, type])
		n -= 1
	# le sol nu : des plantes du sol en plus, par petits groupes de la même (un bouquet de lichens, une colonie de plantes grasses,
	# des coussins serrés) ; c'est par elles que se lit un lieu sans arbres
	n = Decor._nombre(r, SOL_NU * (1.0 - float(s["couvert"])) * ka)
	essais = n * 4
	while n > 0 and essais > 0:
		essais -= 1
		var q := Decor._dans(r, rect)
		var g := r.randi() % 100000000
		if q.length() < 170.0:
			continue
		# (des graines qui tirent la même plante : le même reste, modulo 10007)
		for j in 2 + g % 3:
			var p_g: Vector2 = (q + Vector2(r.randf_range(-22.0, 22.0), r.randf_range(-12.0, 12.0))).clamp(rect.position, rect.end - Vector2(0.01, 0.01))
			plan.append(["sol", p_g, "herbe", g + j * 10007, type])
		n -= 1


# ce qu'un rectangle d'un biome contient : les mêmes densités qu'un lieu fermé, rapportées à sa surface
func _prevoir_lieu(r: RandomNumberGenerator, plan: Array, rect: Rect2, arbre: String, mesures: Array, type: String) -> void:
	var ka := rect.get_area() / (4.0 * R.DEMI * R.DEMI)
	if type != "" and bool(lieu_de(type).get("sous_terre", false)):
		# (une grotte : ni arbres, ni buissons, ni herbe, ni bois mort — on y vient avec ce qu'il faut pour le feu ; de la pierre)
		_prevoir(r, plan, rect, "rocher", 240.0 * ka, "pierre", null, 1.0, type)
		# (et la flore de la grotte, celle de l'herbier d'Orvane : des champignons — les lumineux sont des repères dans le noir,
		# on mange ceux qu'on cueille —, des géants, des moisissures)
		_prevoir(r, plan, rect, "champignon", 300.0 * ka, "", null, 1.0, type)
		return
	var couvert: float = mesures[0]
	_prevoir(r, plan, rect, arbre, (70.0 + 430.0 * couvert) * ka, "feuilles", _bosquets, 0.25 + couvert, type)
	_prevoir(r, plan, rect, "rocher", (40.0 + 140.0 * float(mesures[2])) * ka, "pierre", null, 1.0, type)
	_prevoir(r, plan, rect, "buisson", (R.BUISSONS + R.BUISSONS_HUMIDE * float(mesures[1])) * ka, "feuilles", _bosquets, 0.6, type)
	_prevoir(r, plan, rect, "touffe", (90.0 + 130.0 * (1.0 - couvert)) * ka, "herbe", null, 1.0, type)
	_prevoir(r, plan, rect, "brindille", 160.0 * ka, "", _bosquets, 0.6, type)
	_prevoir(r, plan, rect, "herbe", HERBES * ka, "", null, 1.0, type)


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
	var types := {}
	var t_a := Time.get_ticks_usec()
	var plan := _plan_m(k)
	var t_b := Time.get_ticks_usec()
	for i in plan.size():
		var e: Array = plan[i]
		var c = changes.get(str(i), false)
		if c == null:
			continue
		var ici: Dictionary = lieu_de(str(e[4])) if carte != null else {}
		# (un champignon de grotte ne pousse pas au jour d'une bouche)
		if carte != null and str(e[0]) == "champignon" and carte.sous_terre(e[1]) < 0.6:
			continue
		var tons: Dictionary = ici["palette"] if carte != null else palette
		types[str(e[4])] = true
		var o = _poser(str(e[0]), e[1], tons[e[2]] if e[2] != "" else Color.WHITE, int(e[3]), ici, int(e[5]) if e.size() > 5 else -1, true)
		if o == null:
			# (une place que l'herbier laisse vide : une mare sans plante d'eau, un milieu dont aucune plante ne veut)
			continue
		if str(e[0]) == "herbe" and carte != null:
			o.porter_herbe(str(e[4]))
		o.set_meta("m", k)
		o.set_meta("rang", i)
		liste.append(o)
		if typeof(c) == TYPE_ARRAY and c.size() >= 5 and str(c[0]) != o.genre and not (str(c[0]) == "souche" and o.genre in ["arbre", "sapin"]):
			# (ce qui a changé n'est plus ce qui pousse là : l'herbier est arrivé depuis, et la place porte une autre plante)
			changes.erase(str(i))
		elif typeof(c) == TYPE_ARRAY and c.size() >= 5:
			# (les fruits d'un arbre ont mûri pendant qu'on était loin, eux aussi)
			if c.size() >= 8:
				var fruits_a_pousser := float(c[7])
				if fruits_a_pousser > 0.0:
					fruits_a_pousser -= heure - float(c[4])
				if fruits_a_pousser > 0.0:
					o.reprendre_fruits(int(c[5]), int(c[6]), fruits_a_pousser)
				elif float(c[7]) <= 0.0:
					o.reprendre_fruits(int(c[5]), int(c[6]), 0.0)
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
		if o == null:
			continue
		o.set_meta("m", k)
		o.set_meta("ajout", true)
		liste.append(o)
	var noeuds: Array = []
	var rect := Rect2(Vector2(k) * MORCEAU, Vector2(MORCEAU, MORCEAU))
	var t_c := Time.get_ticks_usec()
	if OS.has_environment("LISIERE_TEMPS"):
		print("morceau ", k, " : le plan ", (t_b - t_a) / 1000.0, " ms (", plan.size(), " places), la pose ", (t_c - t_b) / 1000.0, " ms (", liste.size(), " objets)")
	if _racine != null and carte != null:
		# (le décor de chaque quart : l'herbe, les plantes, les cailloux du biome de sa région ; rien sur l'eau)
		for qx in 2:
			for qy in 2:
				var quart := Rect2(rect.position + Vector2(qx, qy) * MORCEAU * 0.5, Vector2(MORCEAU, MORCEAU) * 0.5)
				var reg: Dictionary = carte.regions[carte.region_en(quart.get_center())]
				if reg["eau"]:
					continue
				var L := lieu_de(str(reg["type"]))
				if L["sous_terre"]:
					# (sous terre : ni herbe, ni fleurs)
					continue
				if L["outils"].is_empty():
					L["outils"] = Decor.outils(L["parts"], L["palette"], _graine)
				# (dans une vallée de rivière, rien dans le lit ; dans un pays de relief, rien sur une paroi, sur un col)
				Decor.exclure = Callable(carte, "nu") if reg["riviere"] or carte.force(quart.get_center()) > 0.0 or carte.creux(quart.get_center()) > 0.3 else Callable()
				Decor.rive = _rive_du_decor(quart, str(reg["type"]), liste) if plan_version >= PLAN and float(L["parts"]["boue"]) > 0.0 else Callable()
				noeuds.append_array(Decor.semer_dans(self, _calques, _terrain, L["parts"], L["palette"], hash(Vector3i(_graine + 7 + qx * 2 + qy, k.x, k.y)), _mobile, quart, L["outils"], liste))
		Decor.exclure = Callable()
		Decor.rive = Callable()
	elif _racine != null and not _outils.is_empty():
		Decor.rive = _rive_du_decor(rect, "", liste) if plan_version >= PLAN and float(_parts["boue"]) > 0.0 else Callable()
		noeuds = Decor.semer_dans(self, _calques, _terrain, _parts, palette, hash(Vector3i(_graine + 7, k.x, k.y)), _mobile, rect, _outils, liste)
		Decor.rive = Callable()
	if OS.has_environment("LISIERE_TEMPS"):
		print("  … le décor ", (Time.get_ticks_usec() - t_c) / 1000.0, " ms")
	_morceaux[k] = {"objets": liste, "noeuds": noeuds, "types": types}


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
			if o.fruits_plein > 0 or o.tombes_plein > 0:
				# (un arbre qui porte des fruits : ce qu'il en a encore, à son pied, et le temps avant qu'il en porte de nouveau)
				changes[i].append_array([o.fruits, o.tombes, snappedf(o._repousse_fruits, 0.1)])
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
	return {"changes": _changes.duplicate(true), "ajouts": _ajouts.duplicate(true), "plan": plan_version}


# (une partie gardée d'avant ne dit pas son plan : c'est le premier, et elle le garde — ce qu'elle a changé y est noté par rang)
func reprendre_ouvert(d: Dictionary) -> void:
	_changes = {}
	_ajouts = {}
	plan_version = clampi(int(d.get("plan", 1)), 1, PLAN)
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
	for o in couronnes_pres(p):
		if not _effaces.has(o) and o.cache(p):
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
