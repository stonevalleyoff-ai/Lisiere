extends RefCounted
# Lisière — la planche d'une bête : de quoi la dessiner à l'encre (scripts/bestiaire_planche.gd)
# Les bêtes de Lisière sont dessinées par Lisière, d'après le plan de corps de leur lignée (plan.corps, dans le monde d'Orvane),
# à la manière du reste du jeu : un cerne d'encre plus lourd du côté de l'ombre (en bas, à droite), trois tons (la lumière vient
# d'en haut à gauche), un dos plus sombre et un ventre plus pâle, des hachures courtes, un œil qui vit. Une forme (un quadrupède,
# un hexapode, un serpent, un oiseau : scripts/bestiaire_<forme>.gd) dessine sur une planche avec les gestes d'ici ; la planche
# en fait ce que la bête anime (scripts/bete.gd), dans la même forme que scripts/squelette.gd : des calques (la queue, le corps,
# le dessus, la tête) en images, et des pattes en morceaux dans un atlas, avec leurs articulations.
#
# Les mesures sont en pixels montrés dans le lieu. L'origine est le point où la bête touche le sol, sous son milieu ; x va vers
# la tête (la bête regarde à droite), y monte vers le négatif (le dos est à y < 0, le sol à y = 0). Tout le dessin tient dans la
# largeur L (du bout du nez au bout de la queue) et dans 1,1 L de haut. Les images sont faites à deux fois leur taille montrée.
#
#   p.calque("corps")                                   # où l'on dessine : "queue", "corps", "dessus", "tete"
#   p.volume(d, p.tons["robe"], func(): ...)            # une forme fermée, peinte et cernée ; ce que fait la fonction y est découpé
#   p.patte(points, largeurs, loin, {"pied": "sabot"})  # une patte, de la hanche au pied posé (y = 0)
#   p.oeil(centre, rayon)                               # l'œil (il brille la nuit : scripts/yeux.gd)

const P := preload("res://scripts/palette.gd")
const ECH := 2.0             # pixels de l'image par pixel montré
const MARGE := 3             # pixels de l'image autour de chaque morceau (le filtrage ne mêle pas deux morceaux)
const CALQUES := ["queue", "corps", "dessus", "tete"]

var L := 60.0                # la largeur de la bête (pixels montrés)
var e := 1.3                 # l'épaisseur du trait d'encre (pixels montrés)
var id := ""
var plan: Dictionary = {}
var corps: Dictionary = {}   # plan.corps : forme, pattes, long, haut, cou, tete, museau, oreilles, queue, cornes, crete, ailes,
#                              carapace, antennes, posture, motif, organes, couleurs
var tons: Dictionary = {}    # les couleurs de cette bête, accordées à la palette du jeu (bestiaire.gd, tons) : robe, lumiere, ombre,
#                              dos, ventre, loin (les pattes de l'autre côté), accent, oeil, encre, os, truffe
var r := RandomNumberGenerator.new()   # le hasard de cette lignée : la même bête se dessine toujours pareil
var chasseur := false        # un carnivore, ou un gros omnivore : il fait peur
var nocturne := false
var robustesse := 0.4        # de 0 (frêle, 100 g) à 1 (massif, 100 kg), d'après sa masse
var regime := "herbivore"
var locomotion: Array = []
var traits: Array = []       # les traits de son phénotype, s'il en a (pattes-longues, crocs-allonges…)
var onde := false            # un corps sans pattes, qui ondule : il lui faut de la place en haut et en bas de son image
var yeux: Array = []         # [Vector3(x, y, rayon)] : où brillent ses yeux, au repos

var _calques := {}
var _courant := "corps"
var _pattes: Array = []
var _pivots := {}
var _ombre := Vector2(0.0, -1.0)     # (son milieu en x, son demi-grand axe ; -1 : d'après le corps)
var _n := 0


func _init() -> void:
	for c in CALQUES:
		_calques[c] = PackedStringArray()


# --- où l'on dessine ---

func calque(nom: String) -> void:
	assert(_calques.has(nom))
	_courant = nom


# du SVG tel quel, dans le calque courant (pour ce que les gestes d'ici ne savent pas faire)
func svg(t: String) -> void:
	_calques[_courant].append(t)


# là où la tête pivote (le bas du cou, à l'arrière) ; là où la queue s'attache
func pivot(nom: String, v: Vector2) -> void:
	_pivots[nom] = v


# l'ombre de contact, au sol : son milieu, son demi-grand axe
func ombre(x: float, rx: float) -> void:
	_ombre = Vector2(x, rx)


# --- les chemins (l'attribut d d'un <path>) ---

static func n(x: float) -> String:
	return "%.2f" % x


static func pt(v: Vector2) -> String:
	return "%.2f %.2f" % [v.x, v.y]


# une courbe souple fermée qui passe par ces points (les coins s'arrondissent ; tension 0 : des segments droits)
static func ferme(pts: PackedVector2Array, tension := 1.0) -> String:
	var m := pts.size()
	if m < 3:
		return ""
	var d := "M" + pt(pts[0])
	for i in m:
		var p0 := pts[(i - 1 + m) % m]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % m]
		var p3 := pts[(i + 2) % m]
		d += " C" + pt(p1 + (p2 - p0) * tension / 6.0) + " " + pt(p2 - (p3 - p1) * tension / 6.0) + " " + pt(p2)
	return d + "Z"


# une courbe souple ouverte qui passe par ces points
static func ouvert(pts: PackedVector2Array, tension := 1.0) -> String:
	var m := pts.size()
	if m < 2:
		return ""
	var d := "M" + pt(pts[0])
	for i in m - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, m - 1)]
		d += " C" + pt(p1 + (p2 - p0) * tension / 6.0) + " " + pt(p2 - (p3 - p1) * tension / 6.0) + " " + pt(p2)
	return d


# un polygone aux coins vifs
static func poly(pts: PackedVector2Array) -> String:
	var d := ""
	for i in pts.size():
		d += ("M" if i == 0 else " L") + pt(pts[i])
	return d + "Z"


# les points d'une ellipse (à passer à ferme, ou à déformer d'abord)
static func ellipse(c: Vector2, rx: float, ry: float, m := 10, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in m:
		var a := TAU * i / m
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


# un ruban qui s'effile : une courbe (ses points), une largeur au début et à la fin ; fermé, prêt pour volume (une queue, un cou,
# une corne, une antenne épaisse)
static func ruban(ligne: PackedVector2Array, w0: float, w1: float) -> String:
	var b := bords(ligne, w0, w1)
	if b.is_empty():
		return ""
	var bas: PackedVector2Array = b[1].duplicate()
	bas.reverse()
	return ferme(b[0] + bas, 0.9)


# les deux bords d'un ruban (celui de gauche en allant, puis celui de droite), pour ne cerner que ses côtés : un cou qui sort
# du corps, une queue qui s'y attache, n'ont pas de trait en travers (volume avec "cerne": 0, puis cerne(ouvert(bord)))
static func bords(ligne: PackedVector2Array, w0: float, w1: float) -> Array:
	var m := ligne.size()
	if m < 2:
		return []
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in m:
		var t := (ligne[mini(i + 1, m - 1)] - ligne[maxi(i - 1, 0)]).normalized().orthogonal()
		var w := lerpf(w0, w1, float(i) / (m - 1)) * 0.5
		haut.append(ligne[i] + t * w)
		bas.append(ligne[i] - t * w)
	return [haut, bas]


# la main qui tremble : chaque point bouge un peu (amp, en pixels montrés), toujours pareil pour cette lignée
func vivant(pts: PackedVector2Array, amp := 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + Vector2(r.randf_range(-amp, amp), r.randf_range(-amp, amp)))
	return out


# --- les gestes de l'encre ---

static func coul(c: Color) -> String:
	return "#" + c.to_html(false)


# une forme fermée, peinte à la manière de Lisière : le cerne d'encre (plus lourd en bas à droite), l'aplat en trois tons (la
# lumière en haut à gauche, l'ombre en bas), puis ce que « dedans » dessine, découpé à la forme (le dos, le ventre, un motif, des
# hachures), et le trait d'encre par-dessus. opts : "cerne" (l'épaisseur du trait, en fois e ; 0 : pas de trait), "lourd" (faux :
# pas d'encre lourde dessous), "plat" (vrai : un seul ton), "lumiere" et "ombre" (d'autres tons que ceux de la teinte)
func volume(d: String, teinte: Color, dedans := Callable(), opts := {}) -> void:
	if d == "":
		return
	var k: float = opts.get("cerne", 1.0)
	var encre := coul(tons["encre"])
	if opts.get("lourd", true) and k > 0.0:
		svg("<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" transform=\"translate(%s %s)\"/>" % [d, encre, encre, n(e * 1.5 * k), n(e * 0.3), n(e * 0.5)])
	if opts.get("plat", false):
		svg("<path d=\"%s\" fill=\"%s\"/>" % [d, coul(teinte)])
	else:
		_n += 1
		var lum: Color = opts.get("lumiere", clair(teinte))
		var omb: Color = opts.get("ombre", sombre(teinte))
		svg("<linearGradient id=\"g%d\" x1=\"0.25\" y1=\"0\" x2=\"0.6\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.34\" stop-color=\"%s\"/><stop offset=\"0.7\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient><path d=\"%s\" fill=\"url(#g%d)\"/>" % [
			_n, coul(lum), coul(teinte), coul(teinte), coul(omb), d, _n])
	if dedans.is_valid():
		_n += 1
		svg("<clipPath id=\"c%d\"><path d=\"%s\"/></clipPath><g clip-path=\"url(#c%d)\">" % [_n, d, _n])
		dedans.call()
		svg("</g>")
	if k > 0.0:
		svg("<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"/>" % [d, encre, n(e * k)])


# le ton clair et le ton d'ombre d'une teinte (la lumière est chaude, l'ombre tire vers le bleu de la nuit)
static func clair(c: Color) -> Color:
	return c.lerp(P.PAPIER, 0.26)


static func sombre(c: Color) -> Color:
	return c.darkened(0.3).lerp(P.NUIT_BLEUE, 0.14)


# un aplat sans cerne (un ventre, un masque, une tache : le plus souvent dans le « dedans » d'un volume)
func aplat(d: String, c: Color, a := 1.0) -> void:
	svg("<path d=\"%s\" fill=\"%s\"%s/>" % [d, coul(c), "" if a >= 1.0 else " opacity=\"%s\"" % n(a)])


# un trait (une moustache, une plume, un pli, une antenne) : w en pixels montrés
func tracer(d: String, w: float, c: Color, a := 1.0) -> void:
	svg("<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"%s/>" % [d, coul(c), n(w), "" if a >= 1.0 else " opacity=\"%s\"" % n(a)])


# le trait d'encre seul, sur un chemin (ouvert ou fermé)
func cerne(d: String, k := 1.0) -> void:
	tracer(d, e * k, tons["encre"])


# des hachures : m petits traits d'encre de a à b (longs de « long », penchés de « angle » radians), un peu inégaux. Le poil du
# dos, l'ombre d'un ventre, le pli d'une cuisse. Rien sur une bête trop petite pour qu'on les voie (L < 44).
func hachures(a: Vector2, b: Vector2, m: int, long: float, angle: float, alpha := 0.55, w := 0.0) -> void:
	if L < 44.0 or m <= 0:
		return
	var d := ""
	for i in m:
		var q := a.lerp(b, (float(i) + r.randf_range(0.15, 0.85)) / m)
		var v := Vector2.from_angle(angle + r.randf_range(-0.22, 0.22)) * long * r.randf_range(0.65, 1.15)
		d += "M" + pt(q) + " l" + pt(v)
	tracer(d, w if w > 0.0 else maxf(0.45, e * 0.42), tons["encre"], alpha)


# des hachures le long d'une courbe (ses points) : le poil qui suit le dos, l'échine, la croupe
func poils(ligne: PackedVector2Array, long: float, angle: float, pas := 3.0, alpha := 0.55) -> void:
	for i in ligne.size() - 1:
		var m := int(ligne[i].distance_to(ligne[i + 1]) / maxf(pas, 0.5))
		hachures(ligne[i], ligne[i + 1], m, long, angle, alpha)


# des bandes en travers (un motif « bandes », « rayures ») : m bandes entre x0 et x1, de y0 à y1, penchées, d'une largeur w
func bandes(x0: float, x1: float, y0: float, y1: float, m: int, penche: float, w: float, c: Color, a := 0.6) -> void:
	var d := ""
	for i in m:
		var x := lerpf(x0, x1, (float(i) + 0.5) / m) + r.randf_range(-0.6, 0.6)
		var ww := w * r.randf_range(0.75, 1.2)
		d += "M" + pt(Vector2(x - ww * 0.5 - penche, y0)) + " L" + pt(Vector2(x + ww * 0.5 - penche, y0)) + " L" + pt(Vector2(x + ww * 0.2 + penche, y1)) + " L" + pt(Vector2(x - ww * 0.2 + penche, y1)) + "Z"
	aplat(d, c, a)


# des taches (un motif « taches ») : m ronds inégaux dans un rectangle
func taches(zone: Rect2, m: int, r0: float, r1: float, c: Color, a := 0.6) -> void:
	var d := ""
	for i in m:
		var q := zone.position + Vector2(r.randf() * zone.size.x, r.randf() * zone.size.y)
		d += ferme(ellipse(q, r.randf_range(r0, r1), r.randf_range(r0, r1) * 0.8, 6, r.randf() * TAU), 1.0)
	aplat(d, c, a)


# l'œil : ce qui fait vivre la bête. Un cerne d'encre, l'iris (de la couleur de la lignée, accordée), la pupille, un éclat de
# papier en haut à gauche ; un chasseur a l'arcade basse (il fixe), une proie l'œil rond. Jamais plus petit qu'on ne le verrait.
# opts : "sourcil" (faux : pas d'arcade), "fente" (vrai : une pupille en fente, un serpent, un chasseur de nuit)
func oeil(c: Vector2, rayon: float, opts := {}) -> void:
	var ro := maxf(rayon, 1.45 if L < 60.0 else 1.7)
	if nocturne:
		ro *= 1.15
	var encre := coul(tons["encre"])
	svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [n(c.x), n(c.y), n(ro + e * 0.55), encre])
	svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [n(c.x), n(c.y), n(ro), coul(tons["oeil"])])
	if opts.get("fente", false):
		svg("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"%s\"/>" % [n(c.x), n(c.y), n(ro * 0.28), n(ro * 0.9), encre])
	else:
		svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [n(c.x + ro * 0.12), n(c.y + ro * 0.05), n(ro * (0.5 if chasseur else 0.62)), encre])
	svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [n(c.x - ro * 0.32), n(c.y - ro * 0.36), n(maxf(0.42, ro * 0.3)), coul(P.PAPIER)])
	if chasseur and opts.get("sourcil", true):
		# (l'arcade : un trait d'encre qui tombe vers le museau)
		tracer("M%s L%s" % [pt(c + Vector2(-ro * 1.25, -ro * 1.15)), pt(c + Vector2(ro * 1.3, -ro * 0.45))], e * 0.9, tons["encre"])
	yeux.append(Vector3(c.x, c.y, ro))


# --- les pattes ---

# une patte : ses articulations de la hanche au pied, au repos (le pied est posé : y = 0) ; sa largeur à chaque articulation
# (autant que de points : elle s'effile) ; son côté (loin : celui qu'on ne voit pas, dessiné derrière le corps, dans l'ombre).
# Trois points au moins : la cuisse, puis le reste, qui suit d'un seul tenant (la bête plie le genou : bete.gd, _ik).
# opts : "teinte" (sinon la robe, ou le ton lointain), "pied" ("sabot", "coussinet", "griffes", "doigts", "pointe", "main",
# "aucun"), "pied_taille" (en fois la largeur du bas de la patte), "pied_teinte", "poilu" (vrai : des hachures sur la cuisse)
func patte(pts: PackedVector2Array, largeurs: Array, loin: bool, opts := {}) -> void:
	if pts.size() < 2:
		return
	var g := pts
	var w := largeurs.duplicate()
	while w.size() < g.size():
		w.append(w.back() if not w.is_empty() else 2.0)
	if g.size() == 2:
		g = PackedVector2Array([g[0], (g[0] + g[1]) * 0.5, g[1]])
		w = [w[0], (float(w[0]) + float(w[1])) * 0.5, w[1]]
	_pattes.append({"pts": g, "larg": w, "loin": loin, "opts": opts})


# le dessin d'un morceau de patte, couché : de (0, 0) à (lg, 0), large de w0 puis de w1. Le bout du début n'a pas de cerne : le
# morceau d'avant passe dessous, et la patte se lit d'un seul tenant
func _morceau(lg: float, w0: float, w1: float, teinte: Color, loin_: bool, poilu: bool) -> String:
	var r0 := w0 * 0.5
	var r1 := w1 * 0.5
	var encre := coul(tons["encre"])
	var corps_ := "M%s L%s A%s %s 0 0 1 %s L%s A%s %s 0 0 1 %sZ" % [pt(Vector2(0, -r0)), pt(Vector2(lg, -r1)), n(r1), n(r1), pt(Vector2(lg, r1)), pt(Vector2(0, r0)), n(r0), n(r0), pt(Vector2(0, -r0))]
	var bord := "M%s L%s A%s %s 0 0 1 %s L%s" % [pt(Vector2(0, -r0)), pt(Vector2(lg, -r1)), n(r1), n(r1), pt(Vector2(lg, r1)), pt(Vector2(0, r0))]
	var s := "<path d=\"%s\" fill=\"%s\"/>" % [corps_, coul(teinte)]
	if not loin_:
		# (un reflet le long du morceau, du côté de la lumière : la patte est ronde)
		s += "<path d=\"M%s L%s\" stroke=\"%s\" stroke-width=\"%s\" opacity=\"0.5\" fill=\"none\"/>" % [pt(Vector2(r0 * 0.4, -r0 * 0.32)), pt(Vector2(lg - r1 * 0.4, -r1 * 0.32)), coul(clair(teinte)), n(maxf(0.5, minf(w0, w1) * 0.3))]
		if poilu and L >= 44.0 and lg > 5.0:
			for i in int(lg / 3.2):
				var x := 2.0 + i * 3.2
				s += "<path d=\"M%s l%s\" stroke=\"%s\" stroke-width=\"%s\" opacity=\"0.5\" fill=\"none\"/>" % [pt(Vector2(x, r0 * 0.15)), pt(Vector2(1.6, lerpf(r0, r1, x / lg) * 0.55)), encre, n(maxf(0.45, e * 0.4))]
	s += "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"/>" % [bord, encre, n(e * (0.85 if loin_ else 1.0))]
	return s


# le dessin d'un pied, autour du point où il touche le sol (0, 0), tourné vers l'avant (+x) ; et sa boîte
func _pied(genre: String, w: float, teinte: Color, loin_: bool) -> Array:
	var encre := coul(tons["encre"])
	var os_ := coul(tons["os"].darkened(0.25) if loin_ else tons["os"])
	var t := coul(teinte)
	var ee := n(e * (0.85 if loin_ else 1.0))
	var s := ""
	var boite := Rect2(-w, -w, 2.0 * w, w * 1.4)
	match genre:
		"sabot":
			# (un coin d'encre, court : le sabot d'un brouteur)
			var d := "M%s L%s L%s L%sZ" % [pt(Vector2(-w * 0.55, -w * 0.62)), pt(Vector2(w * 0.5, -w * 0.62)), pt(Vector2(w * 0.72, 0)), pt(Vector2(-w * 0.6, 0))]
			s = "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [d, coul(P.ENCRE_DOUCE.lerp(teinte, 0.25)), encre, ee]
			boite = Rect2(-w * 0.9, -w * 0.9, w * 1.9, w * 1.2)
		"coussinet":
			# (une patte ronde, deux doigts marqués)
			var d2 := ferme(PackedVector2Array([Vector2(-w * 0.55, -w * 0.05), Vector2(-w * 0.5, -w * 0.6), Vector2(w * 0.3, -w * 0.7), Vector2(w * 0.95, -w * 0.32), Vector2(w * 0.9, 0.0), Vector2(0.0, w * 0.05)]))
			s = "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [d2, t, encre, ee]
			s += "<path d=\"M%s l%s M%s l%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\" opacity=\"0.7\"/>" % [pt(Vector2(w * 0.35, -w * 0.05)), pt(Vector2(0.05, -w * 0.35)), pt(Vector2(w * 0.65, -w * 0.05)), pt(Vector2(0.05, -w * 0.3)), encre, n(e * 0.5)]
			boite = Rect2(-w * 0.9, -w, w * 2.2, w * 1.4)
		"griffes":
			# (la patte d'un chasseur : large, trois griffes claires)
			var d3 := ferme(PackedVector2Array([Vector2(-w * 0.6, -w * 0.05), Vector2(-w * 0.5, -w * 0.62), Vector2(w * 0.35, -w * 0.72), Vector2(w * 1.0, -w * 0.3), Vector2(w * 0.95, 0.0), Vector2(0.0, w * 0.05)]))
			s = "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [d3, t, encre, ee]
			for i in 3:
				var x := w * (0.5 + 0.28 * i)
				s += "<path d=\"M%s L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [pt(Vector2(x, -w * 0.12)), pt(Vector2(x + w * 0.42, w * 0.06)), os_, n(maxf(0.7, w * 0.2))]
			boite = Rect2(-w * 0.95, -w * 1.05, w * 2.8, w * 1.5)
		"doigts":
			# (un oiseau : trois doigts devant, un derrière)
			for a in [Vector2(w * 1.5, 0.0), Vector2(w * 1.25, -w * 0.5), Vector2(w * 1.3, w * 0.25), Vector2(-w * 0.8, 0.05)]:
				s += "<path d=\"M0 0 L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/><path d=\"M0 0 L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [pt(a), encre, n(w * 0.55 + e * 0.9), pt(a), t, n(w * 0.55)]
			boite = Rect2(-w * 1.4, -w * 1.0, w * 3.6, w * 1.9)
		"pointe":
			# (un insecte : un petit crochet)
			s = "<path d=\"M0 %s L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [n(-w * 0.3), pt(Vector2(w * 0.9, 0.0)), encre, n(maxf(0.7, w * 0.6))]
			boite = Rect2(-w * 0.6, -w * 0.8, w * 2.2, w * 1.3)
		"main":
			# (des doigts écartés : un grimpeur, un fouisseur)
			for a in [Vector2(w * 1.0, -w * 0.1), Vector2(w * 0.85, -w * 0.55), Vector2(w * 0.95, w * 0.2)]:
				s += "<path d=\"M0 %s L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/><path d=\"M0 %s L%s\" stroke=\"%s\" stroke-width=\"%s\" fill=\"none\"/>" % [n(-w * 0.2), pt(a), encre, n(w * 0.5 + e * 0.9), n(-w * 0.2), pt(a), t, n(w * 0.5)]
			boite = Rect2(-w * 0.8, -w * 1.0, w * 2.6, w * 1.7)
		_:
			return ["", Rect2()]
	return [s, boite]


# --- la planche finie ---

func _cadre() -> Array:
	# (le cadre du dessin, en pixels montrés : sa taille, et où y tombe l'origine)
	var taille := Vector2(2.6 * L + 40.0, 1.9 * L + 40.0)
	return [taille, Vector2(taille.x * 0.5, 1.55 * L + 20.0)]


func _document(contenu: String) -> String:
	var c := _cadre()
	return "<svg viewBox=\"0 0 %s %s\" width=\"%s\" height=\"%s\"><g transform=\"translate(%s %s)\" stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</g></svg>" % [
		n(c[0].x), n(c[0].y), n(c[0].x), n(c[0].y), n(c[1].x), n(c[1].y), contenu]


func _image(contenu: String) -> Image:
	if contenu == "":
		return null
	var img := Image.new()
	if img.load_svg_from_string(_document(contenu), ECH) != OK:
		return null
	return img


# une image rognée à ce qu'elle dessine : { tex, pos, taille, rect } (pixels montrés, autour de l'origine)
func _rogner(img: Image, marge_onde: float) -> Dictionary:
	if img == null:
		return {}
	var u := img.get_used_rect()
	if u.size.x <= 0 or u.size.y <= 0:
		return {}
	var m := Vector2i(MARGE, MARGE + int(ceil(u.size.y * marge_onde)))
	var out := Image.create(u.size.x + 2 * m.x, u.size.y + 2 * m.y, false, img.get_format())
	out.blit_rect(img, u, m)
	# (les pixels transparents du rendu sont blancs : filtrés, ils feraient un liseré clair autour du dessin)
	out.fix_alpha_edges()
	var origine: Vector2 = _cadre()[1]
	var pos := Vector2(u.position - m) / ECH - origine
	return {"tex": ImageTexture.create_from_image(out), "image": out, "pos": pos, "taille": Vector2(out.get_size()) / ECH,
		"rect": Rect2(pos + Vector2(m) / ECH, Vector2(u.size) / ECH)}


func _contenu(nom: String) -> String:
	return "".join(_calques[nom])


# ce que la bête anime : la même forme que Squelette.lire (scripts/squelette.gd), et en plus « yeux » et « queue »
func finir() -> Dictionary:
	var corps_ := _rogner(_image(_contenu("corps")), 0.16 if onde else 0.0)
	if corps_.is_empty():
		return {}
	var sq := {"corps": corps_, "dessus": _rogner(_image(_contenu("dessus")), 0.0), "tete": _rogner(_image(_contenu("tete")), 0.0),
		"queue": _rogner(_image(_contenu("queue")), 0.0), "pattes": [], "atlas": null, "sans_pattes": _pattes.is_empty(), "yeux": yeux, "lisiere": true}
	var rc: Rect2 = corps_["rect"]
	sq["centre"] = rc.get_center()
	sq["haut"] = rc.position.y
	if not sq["tete"].is_empty():
		var rt: Rect2 = sq["tete"]["rect"]
		sq["haut"] = minf(sq["haut"], rt.position.y)
		sq["tete"]["pivot"] = _pivots.get("tete", Vector2(rt.position.x + rt.size.x * 0.2, rt.end.y - rt.size.y * 0.2))
	if not sq["queue"].is_empty():
		var rq: Rect2 = sq["queue"]["rect"]
		sq["queue"]["pivot"] = _pivots.get("queue", Vector2(rq.end.x - rq.size.x * 0.1, rq.get_center().y))
	sq["ombre"] = _ombre.y if _ombre.y > 0.0 else rc.size.x * 0.42
	sq["ombre_x"] = _ombre.x if _ombre.y > 0.0 else rc.get_center().x
	if not _pattes.is_empty():
		_atlas(sq)
	var portee := 0.0
	var hanches := 0.0
	for q in sq["pattes"]:
		portee += q["portee"]
		hanches += q["pts"][0].y
	if sq["pattes"].is_empty():
		sq["sans_pattes"] = true
		sq["jambe"] = maxf(2.0, rc.size.y * 0.45)
		sq["ventre"] = rc.end.y
	else:
		sq["jambe"] = maxf(1.0, portee / sq["pattes"].size())
		sq["ventre"] = hanches / sq["pattes"].size()
	return sq


# les morceaux d'une patte : [ { taille, svg, ancre } ] pour chaque segment, puis le pied (ou rien)
func _morceaux(q: Dictionary) -> Dictionary:
	var g: PackedVector2Array = q["pts"]
	var w: Array = q["larg"]
	var o: Dictionary = q["opts"]
	var loin_: bool = q["loin"]
	var teinte: Color = o.get("teinte", tons["loin"] if loin_ else tons["robe"])
	var pad := float(MARGE) / ECH
	var segs := []
	for s in g.size() - 1:
		var lg := g[s].distance_to(g[s + 1])
		var w0 := float(w[s])
		var w1 := float(w[s + 1])
		var rm := maxf(w0, w1) * 0.5 + e
		var ancre := Vector2(pad + w0 * 0.5 + e, pad + rm)
		segs.append({"taille": Vector2(lg + (w0 + w1) * 0.5 + 2.0 * e + 2.0 * pad, 2.0 * rm + 2.0 * pad), "ancre": ancre,
			"svg": _morceau(lg, w0, w1, teinte, loin_, o.get("poilu", false) and s == 0)})
	var pied := {}
	var genre := str(o.get("pied", "aucun"))
	if genre != "aucun":
		var wp := float(w.back()) * float(o.get("pied_taille", 1.0))
		var f := _pied(genre, maxf(wp, 1.6), o.get("pied_teinte", teinte), loin_)
		if f[0] != "":
			var b: Rect2 = f[1].grow(e)
			pied = {"taille": b.size + Vector2(2.0 * pad, 2.0 * pad), "ancre": Vector2(pad, pad) - b.position, "svg": f[0]}
	return {"segs": segs, "pied": pied}


# l'atlas des pattes, et ce que la marche lit de chacune (comme Squelette._pattes)
func _atlas(sq: Dictionary) -> void:
	var cellules := []
	var pattes := []
	var centre: Vector2 = sq["centre"]
	for q in _pattes:
		var m := _morceaux(q)
		var p := {"loin": q["loin"], "cellules": [], "pied": {}}
		for s in m["segs"]:
			p["cellules"].append(cellules.size())
			cellules.append(s)
		if not m["pied"].is_empty():
			p["pied"] = {"cellule": cellules.size()}
			cellules.append(m["pied"])
		var pts: PackedVector2Array = q["pts"]
		var k := pts.size() - 1
		var bas := pts[k] - pts[1]
		var rel := PackedVector2Array()
		for i in range(2, k):
			rel.append((pts[i] - pts[1]).rotated(-bas.angle()))
		var croix := (pts[1] - pts[0]).cross(pts[k] - pts[0])
		var droit := absf(croix) < 0.03 * pts[1].distance_to(pts[0]) * pts[k].distance_to(pts[0])
		p["pts"] = pts
		p["l1"] = pts[0].distance_to(pts[1])
		p["l2"] = bas.length()
		p["rel"] = rel
		p["ang_bas"] = bas.angle()
		p["portee"] = pts[0].distance_to(pts[k])
		p["devant"] = pts[0].x > centre.x
		p["plie"] = (1.0 if p["devant"] else -1.0) if droit else signf(croix)
		pattes.append(p)
	# (des rangées de morceaux, chacun dans sa case)
	var largeur_max := 420.0
	var x := 0.0
	var y := 0.0
	var rang := 0.0
	var large := 0.0
	var poses := []
	for c in cellules:
		var t: Vector2 = c["taille"]
		if x > 0.0 and x + t.x > largeur_max:
			x = 0.0
			y += rang
			rang = 0.0
		poses.append(Vector2(x, y))
		x += t.x
		rang = maxf(rang, t.y)
		large = maxf(large, x)
	var haut := y + rang
	var contenu := ""
	for i in cellules.size():
		contenu += "<g transform=\"translate(%s %s)\">%s</g>" % [n(poses[i].x + cellules[i]["ancre"].x), n(poses[i].y + cellules[i]["ancre"].y), cellules[i]["svg"]]
	var doc := "<svg viewBox=\"0 0 %s %s\" width=\"%s\" height=\"%s\"><g stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</g></svg>" % [n(large), n(haut), n(large), n(haut), contenu]
	var img := Image.new()
	if img.load_svg_from_string(doc, ECH) != OK:
		return
	img.fix_alpha_edges()
	sq["atlas"] = ImageTexture.create_from_image(img)
	for p in pattes:
		var cel := []
		for i in p["cellules"]:
			cel.append({"region": Rect2(poses[i] * ECH, cellules[i]["taille"] * ECH), "debut": cellules[i]["ancre"] * ECH})
		p["cellules"] = cel
		if not p["pied"].is_empty():
			var i: int = p["pied"]["cellule"]
			p["pied"] = {"region": Rect2(poses[i] * ECH, cellules[i]["taille"] * ECH), "ancre": cellules[i]["ancre"] * ECH}
	# (le rang de chaque patte, de l'avant vers l'arrière, de son côté : il fait sa phase dans le pas)
	for loin_ in [true, false]:
		var cote := pattes.filter(func(q): return q["loin"] == loin_)
		cote.sort_custom(func(a, b): return a["pts"][0].x > b["pts"][0].x)
		for i in cote.size():
			cote[i]["rang"] = i
			cote[i]["n_cote"] = cote.size()
	sq["pattes"] = pattes


# la bête entière, au repos, en une seule image (le carnet de la fin, les planches d'essai) : { image, pos, taille, rect }
func portrait() -> Dictionary:
	var contenu := ""
	for loin_ in [true, false]:
		if not loin_:
			contenu += _contenu("queue") + _contenu("corps")
		for q in _pattes:
			if q["loin"] != loin_:
				continue
			var m := _morceaux(q)
			var g: PackedVector2Array = q["pts"]
			for s in m["segs"].size():
				contenu += "<g transform=\"translate(%s %s) rotate(%s)\">%s</g>" % [n(g[s].x), n(g[s].y), n(rad_to_deg((g[s + 1] - g[s]).angle())), m["segs"][s]["svg"]]
			if not m["pied"].is_empty():
				contenu += "<g transform=\"translate(%s %s)\">%s</g>" % [n(g[g.size() - 1].x), n(g[g.size() - 1].y), m["pied"]["svg"]]
	contenu += _contenu("dessus") + _contenu("tete")
	return _rogner(_image(contenu), 0.0)
