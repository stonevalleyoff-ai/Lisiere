extends RefCounted
# Lisière — l'encre en un seul geste (scripts/interface_trace.gd)
# Une icône, un jeton, un arc au pinceau se dessinent en dizaines de traits : un polygone, un trait lissé (que Godot fait de
# trois bandes), un disque… Chacun coûte un appel de dessin, image après image, et un téléphone en meurt (un millier d'appels
# pour le HUD et les boutons tactiles). Ici, ces traits s'enregistrent une fois, comme Godot les aurait faits (les mêmes
# triangles, la même frange de 1,25 qui s'efface au bord d'un trait lissé), dans un maillage gardé : ensuite, une icône est un
# seul appel (draw_mesh), à la couleur près (la teinte multipliée, la transparence).
#   var m := Trace.maillage("cle", func(t): t.draw_circle(...); t.draw_polyline(...))
#   ci.draw_mesh(m, null, Transform2D(0.0, centre), couleur)
# Ou tout de suite, pour ce qui change à chaque image (la veilleuse qui marche, un feu) : la trace recueille les traits d'un
# _draw, puis les rend d'un seul appel (canvas_item_add_triangle_array) ; ce qui a une texture passe tel quel, à son rang.
#   _trace.commencer(self) ; corps.ci = _trace ; corps.dessiner() ; _trace.vider()
# La trace répond aux mêmes noms que CanvasItem (draw_colored_polygon, draw_polygon, draw_polyline, draw_line, draw_arc,
# draw_circle, draw_rect, draw_primitive, draw_texture_rect, draw_set_transform_matrix) : ce qui dessine peut dessiner dans
# l'un ou dans l'autre.

const FRANGE := 1.25            # (la frange d'un trait lissé, de chaque côté : celle de Godot)
const CERCLE := 64              # (les côtés d'un disque plein : ceux de Godot)
const GARDES := 1500            # (au-delà, le cache se vide : des arcs aux angles toujours neufs ne doivent pas l'enfler)

static var _cache := {}

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _t := Transform2D.IDENTITY
var _cible: CanvasItem = null


# le maillage gardé sous cette clé ; s'il n'existe pas encore, faire(trace) le dessine
static func maillage(cle: String, faire: Callable) -> ArrayMesh:
	var m = _cache.get(cle)
	if m == null:
		if _cache.size() >= GARDES:
			_cache.clear()
		var t = load("res://scripts/interface_trace.gd").new()
		faire.call(t)
		m = t.en_maillage()
		_cache[cle] = m
	return m


func en_maillage() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _idx.is_empty():
		return m
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = _pts
	a[Mesh.ARRAY_COLOR] = _cols
	a[Mesh.ARRAY_INDEX] = _idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


func vide() -> bool:
	return _idx.is_empty()


# --- tout de suite ---

func commencer(cible: CanvasItem) -> void:
	_cible = cible
	_t = Transform2D.IDENTITY
	_pts.clear()
	_cols.clear()
	_idx.clear()


# ce qui est recueilli, rendu d'un seul appel sur la cible (à la suite de ce qu'elle a déjà dessiné)
func vider() -> void:
	if _cible != null and not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_cible.get_canvas_item(), _idx, _pts, _cols)
	_pts.clear()
	_cols.clear()
	_idx.clear()


# ce qui a une texture ne se recueille pas : ce qui précède est rendu, puis lui, à sa place et sous la même transformation
func draw_texture_rect(tex: Texture2D, r: Rect2, tuile: bool, m: Color = Color.WHITE, transpose: bool = false) -> void:
	vider()
	if _cible == null:
		return
	_cible.draw_set_transform_matrix(_t)
	_cible.draw_texture_rect(tex, r, tuile, m, transpose)
	_cible.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- les mêmes gestes que CanvasItem ---

func draw_set_transform_matrix(t: Transform2D) -> void:
	_t = t


func draw_set_transform(p: Vector2, rot: float = 0.0, s: Vector2 = Vector2.ONE) -> void:
	_t = Transform2D(rot, s, 0.0, p)


func draw_colored_polygon(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var o := _pts.size()
	_pts.append_array(_t * pts)
	for i in pts.size():
		_cols.append(c)
	for i in tri:
		_idx.append(o + i)


# des triangles déjà faits (des indices dans pts), d'une seule couleur
func triangles(idx: PackedInt32Array, pts: PackedVector2Array, c: Color) -> void:
	var o := _pts.size()
	_pts.append_array(_t * pts)
	var cl := PackedColorArray()
	cl.resize(pts.size())
	cl.fill(c)
	_cols.append_array(cl)
	for i in idx:
		_idx.append(o + i)


func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray, _uvs := PackedVector2Array(), _tex: Texture2D = null) -> void:
	if pts.size() < 3:
		return
	if cols.size() != pts.size():
		draw_colored_polygon(pts, cols[0] if not cols.is_empty() else Color.WHITE)
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var o := _pts.size()
	_pts.append_array(_t * pts)
	_cols.append_array(cols)
	for i in tri:
		_idx.append(o + i)


# un triangle ou un quadrilatère, chaque coin sa couleur (sans texture)
func draw_primitive(pts: PackedVector2Array, cols: PackedColorArray, _uvs := PackedVector2Array(), _tex: Texture2D = null) -> void:
	var n := pts.size()
	if n < 3:
		if n == 2:
			draw_line(pts[0], pts[1], cols[0] if not cols.is_empty() else Color.WHITE)
		return
	var o := _pts.size()
	_pts.append_array(_t * pts)
	for i in n:
		_cols.append(cols[i] if cols.size() == n else (cols[0] if not cols.is_empty() else Color.WHITE))
	_idx.append_array([o, o + 1, o + 2])
	if n == 4:
		_idx.append_array([o, o + 2, o + 3])


func draw_rect(r: Rect2, c: Color, plein: bool = true, w: float = -1.0) -> void:
	var coins := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	if not plein:
		coins.append(r.position)
		draw_polyline(coins, c, w)
		return
	draw_primitive(coins, PackedColorArray([c]))


# un disque plein : en 64 côtés comme Godot, moins pour un petit (une braise, un coude : à quelques pixels, douze suffisent)
func draw_circle(centre: Vector2, r: float, c: Color) -> void:
	var n := clampi(int(ceil(r * _t.get_scale().x * 3.0)), 12, CERCLE)
	var loc := PackedVector2Array()
	loc.resize(n + 1)
	loc[0] = centre
	for i in n:
		var a := TAU * i / n
		loc[i + 1] = centre + Vector2(cos(a), sin(a)) * r
	var o := _pts.size()
	_pts.append_array(_t * loc)
	var cl := PackedColorArray()
	cl.resize(n + 1)
	cl.fill(c)
	_cols.append_array(cl)
	var ib := PackedInt32Array()
	ib.resize(n * 3)
	for i in n:
		ib[i * 3] = o
		ib[i * 3 + 1] = o + 1 + i
		ib[i * 3 + 2] = o + 1 + (i + 1) % n
	_idx.append_array(ib)


func draw_arc(centre: Vector2, r: float, a0: float, a1: float, n: int, c: Color, w: float = -1.0, lisse: bool = false) -> void:
	if n < 2:
		return
	var pts := PackedVector2Array()
	var da := clampf(a1 - a0, -TAU, TAU)
	for i in n:
		var a := a0 + da * i / (n - 1.0)
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, c, w, lisse)


func draw_line(a: Vector2, b: Vector2, c: Color, w: float = -1.0, lisse: bool = false) -> void:
	draw_polyline(PackedVector2Array([a, b]), c, w, lisse)


# un trait : une bande de largeur w (au moins un pixel), les coins en onglet (borné) ; lissé, une frange de chaque côté et aux
# bouts, dont le bord extérieur est transparent
func draw_polyline(brut: PackedVector2Array, c: Color, w: float = -1.0, lisse: bool = false) -> void:
	# (les points doublés ne font pas de direction : on les ôte)
	var pts := PackedVector2Array()
	for p in brut:
		if pts.is_empty() or not p.is_equal_approx(pts[pts.size() - 1]):
			pts.append(p)
	var n := pts.size()
	if n < 2:
		return
	if w <= 0.0:
		w = 1.0
		lisse = false
	var boucle := n >= 3 and pts[0].is_equal_approx(pts[n - 1])
	var bord := (FRANGE * minf(w, 1.0)) if lisse else 0.0
	var clair := Color(c, 0.0)
	var h := w * 0.5
	var pas := 4 if lisse else 2
	var o := _pts.size()
	# (pour chaque point, à gauche et à droite de sa normale : le cœur, puis la frange)
	var loc := PackedVector2Array()
	loc.resize(n * pas)
	var cl := PackedColorArray()
	cl.resize(n * pas)
	var debut := (pts[1] - pts[0]).normalized()
	var fin := (pts[n - 1] - pts[n - 2]).normalized()
	for i in n:
		var avant: Vector2
		var apres: Vector2
		if i == 0:
			apres = debut
			avant = (pts[0] - pts[n - 2]).normalized() if boucle else apres
		elif i == n - 1:
			avant = fin
			apres = debut if boucle else avant
		else:
			avant = (pts[i] - pts[i - 1]).normalized()
			apres = (pts[i + 1] - pts[i]).normalized()
		var dir := (avant + apres).normalized()
		if dir.is_zero_approx():
			dir = apres
		var nrm := dir.orthogonal()
		var e := nrm * (h / maxf(0.5, nrm.dot(apres.orthogonal())))
		var p := pts[i]
		var j := i * pas
		loc[j] = p + e
		loc[j + 1] = p - e
		cl[j] = c
		cl[j + 1] = c
		if lisse:
			var f := e + nrm * bord
			loc[j + 2] = p + f
			loc[j + 3] = p - f
			cl[j + 2] = clair
			cl[j + 3] = clair
	_pts.append_array(_t * loc)
	_cols.append_array(cl)
	# (les quadrilatères entre deux points : le cœur, et lissé, les deux franges ; deux triangles chacun)
	var par := 18 if lisse else 6
	var ib := PackedInt32Array()
	ib.resize((n - 1) * par)
	var k := 0
	for i in n - 1:
		var a := o + i * pas
		var b := a + pas
		ib[k] = a
		ib[k + 1] = a + 1
		ib[k + 2] = b
		ib[k + 3] = a + 1
		ib[k + 4] = b + 1
		ib[k + 5] = b
		if lisse:
			ib[k + 6] = a + 2
			ib[k + 7] = a
			ib[k + 8] = b + 2
			ib[k + 9] = a
			ib[k + 10] = b
			ib[k + 11] = b + 2
			ib[k + 12] = a + 1
			ib[k + 13] = a + 3
			ib[k + 14] = b + 1
			ib[k + 15] = a + 3
			ib[k + 16] = b + 3
			ib[k + 17] = b + 1
		k += par
	_idx.append_array(ib)
	# (les bouts d'un trait lissé qui ne se referme pas : la frange les déborde aussi)
	if lisse and not boucle:
		_bout(o, -debut * bord, c)
		_bout(o + (n - 1) * pas, fin * bord, c)


func _quad(a: int, b: int, c: int, d: int) -> void:
	_idx.append_array([a, b, c, b, d, c])


# un bout : les quatre points du bord (frange gauche, cœur gauche, cœur droit, frange droite) poussés de d, transparents
func _bout(o: int, d: Vector2, c: Color) -> void:
	var td := _t.basis_xform(d)
	var clair := Color(c, 0.0)
	var q := _pts.size()
	for k in [o + 2, o, o + 1, o + 3]:
		_pts.append(_pts[k] + td)
		_cols.append(clair)
	_quad(o + 2, o, q, q + 1)
	_quad(o, o + 1, q + 1, q + 2)
	_quad(o + 1, o + 3, q + 2, q + 3)
