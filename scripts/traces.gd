extends Node2D
# Lisière — les empreintes (scripts/traces.gd)
# Ce qui marche laisse sa trace : une empreinte là où chaque pied se pose (bete.gd), dans le sol, sous tout ce qui se tient
# debout. Ce n'est pas une image : un creux, que shaders/empreinte.gdshader calcule et éclaire (le soleil le jour, le feu ou
# la torche la nuit). Ici, ce qu'on sait de chacune, et ce qui lui arrive :
#  - son genre, d'après le pied de la bête : des coussinets (0), un pied d'oiseau (1), la Noire (2 : large comme un buste,
#    de longues griffes), un sabot fendu (3), une main (4), des coussinets à griffes (5). Un sabot : une proie ; des griffes :
#    ce qui chasse, ou ce qui creuse. C'est ce qui se lit, quand on suit une piste ; la pointe dit où allait la bête ;
#  - sa profondeur : une bête lourde, ou qui court, marque davantage ;
#  - le sol où elle est : la terre nue la prend nette, avec son bourrelet ; l'herbe, la mousse, la litière se couchent
#    seulement ; la neige la garde bleue, le bord blanc ;
#  - l'eau : sous la pluie elle se remplit, du fond vers les bords, d'autant plus vite qu'il pleut ; dans un sol déjà gorgé,
#    l'eau y sourd dès qu'elle est faite ; le beau temps revenu, elle sèche lentement. Sous la crue, elle disparaît ;
#  - son âge : ses bords s'émoussent, puis elle s'efface (plus vite sous la pluie, bien plus vite sous la neige qui tombe).
#    Celles d'une proie tiennent 45 secondes, celles d'un chasseur deux minutes et demie, celles de la Noire toute la journée.
# Rien dans l'eau d'une rivière, rien dans la roche. Un seul maillage pour toutes celles qui sont près de l'écran (un appel de
# dessin), refait trois fois par seconde, et dès qu'un pied se pose.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")
const Decor := preload("res://scripts/decor.gd")
const SHADER := preload("res://shaders/empreinte.gdshader")
const MAX := 700                 # au-delà, les plus vieilles s'en vont (jamais celles de la Noire)
const GENRES := {"coussinet": 0, "oiseau": 1, "doigts": 1, "noire": 2, "sabot": 3, "main": 4, "griffes": 5}
const REMPLIR := 0.11            # ce qu'une pluie battante y met d'eau par seconde
const SECHER := 0.014            # et ce qu'elle perd par seconde, la pluie finie
# (où chaque chose est rangée, dans une empreinte)
const X := 0
const Y := 1
const ANGLE := 2
const TAILLE := 3
const NEE := 4
const FIN := 5
const GENRE := 6
const QUI := 7
const FOND := 8
const COUVERT := 9
const NEIGE := 10
const EAU := 11
const NOYEE := 12

var jeu
var _t := 0.0
var _liste: Array = []
var _vu := 0.0
var _sale := false
var _mat: ShaderMaterial
var _maille: ArrayMesh
var _dessinees := 0


func _ready() -> void:
	name = "Traces"
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_maille = ArrayMesh.new()


func vider() -> void:
	_liste.clear()
	_sale = true


# une empreinte, en p, tournée vers « angle » ; taille : sa demi-largeur (pixels du lieu) ; duree : ce qu'elle tient (secondes) ;
# genre : de 0 à 5 (GENRES) ; qui : la lignée qui l'a laissée (scripts/pistage.gd la lit) ; fond : sa profondeur, de 0,35 à 1
func poser(p: Vector2, angle: float, taille: float, duree: float, genre: int, qui: String = "", fond: float = 0.7) -> void:
	var couvert := 0.0
	var neige := 0.0
	var eau := 0.0
	if jeu != null:
		if jeu.get("carte") != null and jeu.carte != null:
			if float(jeu.carte.lit(p)) > 0.0 or bool(jeu.carte.roche_en(p)):
				return
		var C = jeu.get("climat")
		if C != null:
			# (sous la crue, on ne marque pas ; dans la neige, pas d'eau ; dans un sol gorgé, l'eau sourd tout de suite)
			if float(C.crue) > 0.01 and float(C.eau(p)) > 0.05:
				return
			if float(C.neige_sol) >= 0.3:
				neige = 1.0
			else:
				eau = clampf((float(C.boue) - 0.3) * 0.9, 0.0, 0.55)
		var M = jeu.get("monde")
		if M != null and neige < 0.5 and typeof(M.get("_terrain")) == TYPE_DICTIONARY and not M._terrain.is_empty() and typeof(M.get("_parts")) == TYPE_DICTIONARY:
			# (ce qui pousse là : l'herbe, la mousse, la litière se couchent, sans bourrelet)
			var s: Dictionary = Decor.sol_ici(M._terrain, M._parts, p)
			couvert = clampf(maxf(maxf(float(s["herbe"]), float(s["mousse"])), float(s["litiere"]) * 0.8), 0.0, 1.0)
	_liste.append([p.x, p.y, angle, taille, _t, _t + duree, genre, qui, clampf(fond, 0.35, 1.0), couvert, neige, eau, false])
	_sale = true
	if _liste.size() > MAX:
		# (les plus vieilles d'abord, mais pas la piste de la Noire)
		for i in _liste.size():
			if int(_liste[i][GENRE]) != 2:
				_liste.remove_at(i)
				break
		if _liste.size() > MAX + 200:
			_liste.remove_at(0)


# y a-t-il une empreinte de ce genre à moins de « rayon » de p ?
func pres(p: Vector2, rayon: float, genre: int) -> bool:
	var r2 := rayon * rayon
	for e in _liste:
		if int(e[GENRE]) == genre and Vector2(e[X], e[Y]).distance_squared_to(p) < r2:
			return true
	return false


# l'empreinte la plus proche de p, à moins de « rayon » ([] : aucune) ; et son âge, de 0 (elle vient d'être laissée) à 1 (elle
# s'efface)
func la_plus_proche(p: Vector2, rayon: float) -> Array:
	var d0 := rayon * rayon
	var mieux: Array = []
	for e in _liste:
		var d := Vector2(e[X], e[Y]).distance_squared_to(p)
		if d < d0 and not bool(e[NOYEE]):
			d0 = d
			mieux = e
	return mieux


func age(e: Array) -> float:
	return clampf((_t - float(e[NEE])) / maxf(float(e[FIN]) - float(e[NEE]), 0.01), 0.0, 1.0)


# combien d'empreintes de ce genre (l'essai)
func nombre(genre: int = -1) -> int:
	if genre < 0:
		return _liste.size()
	var n := 0
	for e in _liste:
		if int(e[GENRE]) == genre:
			n += 1
	return n


# effacer les empreintes d'un genre (la piste de la veille, quand la Noire en fait une autre)
func effacer(genre: int) -> void:
	_liste = _liste.filter(func(e): return int(e[GENRE]) != genre)
	_sale = true


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause:
		return
	maj(delta)


# une image : leur âge avance ; trois fois par seconde, l'eau y monte ou y sèche, les mortes s'en vont, et le maillage est refait
func maj(delta: float) -> void:
	var C = jeu.climat
	var pluie: float = float(C.pluie) if C != null else 0.0
	var il_neige: bool = C != null and str(C.temps) == "neige"
	# (la pluie les lave, la neige qui tombe les comble : leur temps passe plus vite)
	_t += delta * (1.0 + 1.3 * pluie + (3.0 if il_neige else 0.0))
	_vu -= delta
	if _vu <= 0.0:
		var dt := 0.33 - _vu
		_vu = 0.33
		var crue: bool = C != null and float(C.crue) > 0.01
		var fonte: bool = C != null and float(C.neige_sol) < 0.15
		var k := 0
		while k < _liste.size():
			var e: Array = _liste[k]
			if float(e[FIN]) <= _t:
				_liste.remove_at(k)
				continue
			if float(e[NEIGE]) > 0.5:
				# (la neige a fondu sous elle : elle part avec)
				if fonte:
					e[FIN] = minf(float(e[FIN]), _t + 4.0)
			elif pluie > 0.02:
				e[EAU] = minf(1.0, float(e[EAU]) + REMPLIR * pluie * dt)
			elif float(e[EAU]) > 0.0:
				e[EAU] = maxf(0.0, float(e[EAU]) - SECHER * dt)
			if crue:
				e[NOYEE] = float(C.eau(Vector2(e[X], e[Y]))) > 0.05
			elif bool(e[NOYEE]):
				e[NOYEE] = false
			k += 1
		_sale = true
	if _sale:
		_sale = false
		_refaire()


# le maillage de celles qu'on peut voir : un carré chacune, ce que le shader doit en savoir dans ses sommets
func _refaire() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var avant := _dessinees
	_dessinees = 0
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	if not _liste.is_empty():
		var vp := get_viewport()
		var vue: Rect2 = (vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()).grow(240.0)
		for e in _liste:
			var p := Vector2(e[X], e[Y])
			if bool(e[NOYEE]) or not vue.has_point(p):
				continue
			var t: float = float(e[TAILLE]) * 1.32
			var a: float = e[ANGLE]
			var ax := Vector2.from_angle(a) * t
			var ay := Vector2(-ax.y, ax.x)
			var n := pts.size()
			pts.append(p - ax - ay)
			pts.append(p + ax - ay)
			pts.append(p + ax + ay)
			pts.append(p - ax + ay)
			var u0 := 4.0 * float(e[GENRE]) + 1.0
			var v0 := 4.0 * float(posmod(int(round(a / TAU * 64.0)), 64)) + 1.0
			uvs.append(Vector2(u0, v0))
			uvs.append(Vector2(u0 + 1.0, v0))
			uvs.append(Vector2(u0 + 1.0, v0 + 1.0))
			uvs.append(Vector2(u0, v0 + 1.0))
			var c := Color(float(e[EAU]), age(e), 0.8 if float(e[NEIGE]) > 0.5 else float(e[COUVERT]) * 0.5, float(e[FOND]))
			for i in 4:
				cols.append(c)
			idx.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))
			_dessinees += 1
	_maille.clear_surfaces()
	if _dessinees > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pts
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		_maille.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_lumieres()
	if _dessinees > 0 or avant > 0:
		queue_redraw()


# ce que le shader doit savoir du moment : le jour, les feux proches, le ciel que l'eau renvoie, la pluie, les tons du sol
func _lumieres() -> void:
	var jour: float = jeu.lumiere_du_jour()
	var C = jeu.climat
	var pluie: float = float(C.pluie) if C != null else 0.0
	_mat.set_shader_parameter("jour", jour)
	_mat.set_shader_parameter("pluie", pluie)
	var M = jeu.monde
	if M != null and typeof(M.get("palette")) == TYPE_DICTIONARY and M.palette.has("terre_sombre"):
		var so: Color = Color(M.palette["terre_sombre"]).darkened(0.62)
		var cl: Color = Color(M.palette["terre_claire"]).lightened(0.5)
		var ne: Color = Color(M.palette["neige_ombre"]).darkened(0.25)
		_mat.set_shader_parameter("terre_ombre", Vector3(so.r, so.g, so.b))
		_mat.set_shader_parameter("terre_claire", Vector3(cl.r, cl.g, cl.b))
		_mat.set_shader_parameter("neige_ombre", Vector3(ne.r, ne.g, ne.b))
	# les quatre lumières les plus proches de la veilleuse : les feux, les foyers d'un incendie, sa torche
	var feux := PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	var j = jeu.joueur
	if j != null and jour < 0.98:
		var tous: Array = []
		for f in jeu.feux_et_foyers():
			if f.allume():
				tous.append([f.position.distance_to(j.position), f.position, float(f.rayon()) * 1.25, 1.0])
		if float(j.torche) > 0.0:
			tous.append([0.0, j.position + Vector2(0.0, -6.0), R.RAYON_TORCHE * 1.2, 0.9])
		tous.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		for i in mini(4, tous.size()):
			var q: Vector2 = tous[i][1]
			feux[i] = Color(q.x, q.y, float(tous[i][2]), float(tous[i][3]))
	_mat.set_shader_parameter("feux", feux)


func _draw() -> void:
	if _dessinees > 0:
		draw_mesh(_maille, null)
