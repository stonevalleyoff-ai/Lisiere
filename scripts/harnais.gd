extends Node2D
# Lisière — le harnais d'une bête apprivoisée (scripts/harnais.gd)
# Ce qu'une compagne porte (scripts/elevage.gd : bete.harnais), dessiné sur son corps qui bouge :
#  - le licol : une têtière de corde (un tour de museau, un tour de nuque derrière les oreilles, un montant qui passe sous
#    l'œil, un anneau d'os sous le menton), et sa longe, de l'anneau à ce qui la tient (bete.longe : la main de la veilleuse,
#    la tête d'un piquet) : elle pend en chaînette, se tend quand la bête s'éloigne, traîne au sol quand elle est près ;
#    sans personne au bout, elle est nouée court et pend sous le menton ; en selle, ce sont les rênes ;
#  - les sacoches : deux poches de peau de part et d'autre du dos (celle de l'autre flanc dépasse derrière l'échine), leur
#    rabat, leur bouton d'os, une sangle sous le ventre ; elles ballottent au pas ;
#  - la selle : de peau, sur un tapis de chanvre à liseré rouille, sa sangle et sa boucle, un étrier de corde à marche de bois ;
#  - la longe de filin (scripts/elevage.gd : harnais « longe ») : à la place de la longe de chanvre, un filin blond de fibre
#    longue, plus gros, dont on voit tourner les torons ; noué court sous le menton, son bout a une surliure sombre.
# Rien n'est écrit pour une espèce : la ligne du dos, celle du ventre, le museau, la nuque se lisent sur le dessin de la
# bête (l'image de son corps, celle de sa tête), une fois. Chaque pièce est dessinée une seule fois, dans un calque qui
# suit le corps (ou la tête) comme ses images le suivent : seule la longe se redessine, quand un de ses bouts bouge.
# La bête l'appelle : monter(bete) une fois, suivre() à chaque image, siege() pour qui la monte. Celle qui la monte se dessine
# ici aussi (joueur.peindre_en_selle), par-dessus la selle : les deux ne peuvent pas se croiser.

const P := preload("res://scripts/palette.gd")
# (les tons de la veilleuse, scripts/veilleuse_corps.gd : sa peau, son cuir, son chanvre ; le harnais sort du même atelier)
const CHANVRE := Color("9c9168")
# (le filin : la fibre longue de l'agave, blonde, la braise pâle tirée d'un tiers vers la terre ; ses torons, plus sombres)
const FILIN := Color("c9ad6e")
const FILIN_TORON := Color("8c7546")
const TAPIS := Color("8f8763")
const TAPIS_OMBRE := Color("6a6348")
const PEAU := Color("8a6038")
const PEAU_OMBRE := Color("5f4128")
const PEAU_CLAIR := Color("a77a4c")
const CUIR_OMBRE := Color("4a3a28")
const IVOIRE_OS := Color("b3a88f")
const BOIS := Color("8a6a45")
const PIERRE := Color("8f8a7f")
const N_DOS := 9                 # les points où se lit la ligne du dos, des hanches aux épaules
const LONGE_MOU := 14.0          # ce que la longe a de plus long que la distance où la bête suit (elle n'est tendue qu'au-delà)
const LONGE_PIQUET := 56.0       # la longe d'une bête à l'attache
const ETRIER := 9.4              # du creux de la selle à la marche de l'étrier : la jambe de la veilleuse

class Calque extends Node2D:
	var peindre: Callable

	func _draw() -> void:
		if peindre.is_valid():
			peindre.call(self)


var bete
var _loin: Calque                # derrière le corps : la poche de l'autre flanc
var _pres: Calque                # sur le corps : le tapis, la selle, les sangles
var _sac: Calque                 # la poche de ce flanc-ci, qui ballotte
var _etrier: Calque
var _tete: Calque                # sur la tête : le licol
var _bout: Calque                # la longe nouée court, qui pend
var _porte := -1
var _mobile := false
var _dos_pts := PackedVector2Array()
var _ventre_pts := PackedVector2Array()
var _xr := 0.0
var _xf := 1.0
var _k := 1.0                    # la taille de la selle (1 : quatorze pixels de long)
var _ks := 1.0                   # celle des sacoches
var _o := Vector2.ZERO           # la selle : son milieu sur le dos, sa pente
var _ang := 0.0
var _creux := Vector2.ZERO
var _charniere := Vector2.ZERO   # où pendent les sacoches
var _s_sac := 0.5
var _a_tete := false
var _mh := Vector2.ZERO          # le tour de museau : dessus, dessous
var _mb := Vector2.ZERO
var _nh := Vector2.ZERO          # le tour de nuque
var _nb := Vector2.ZERO
var _joue := Vector2.ZERO        # où le montant passe, sous l'œil
var _anneau := Vector2.ZERO
var _w := 1.0                    # la grosseur de la corde
var _bal := 0.0                  # ce qui pend : un pendule
var _bal_v := 0.0
var _vit_avant := Vector2.ZERO
var _corde := 0                  # 0 : rien ; 1 : la longe ; 2 : les rênes
var _ca := Vector2.ZERO          # ses deux bouts, ici ; le sol sous chacun
var _cb := Vector2.ZERO
var _sol_b := 0.0
var _long := 80.0
var _fleche := 0.0
var _graine := 0.0
var _cavaliere = null
var _filin := false              # sa longe est de filin (elle se dessine blonde, plus grosse, ses torons visibles)


# --- la pose : une fois, sur la bête montée (son squelette, ses images) ---

func monter(b) -> void:
	bete = b
	_graine = randf() * TAU
	_mobile = not bool(b._fin)
	b.add_child(self)
	var pivot: Node2D = b._pivot
	_mesurer_corps()
	_mesurer_tete()
	_loin = _calque(_peindre_loin)
	pivot.add_child(_loin)
	pivot.move_child(_loin, b.sprite.get_index())
	_pres = _calque(_peindre_pres)
	pivot.add_child(_pres)
	_sac = _calque(_peindre_sac)
	_pres.add_child(_sac)
	_etrier = _calque(_peindre_etrier)
	_pres.add_child(_etrier)
	_tete = _calque(_peindre_licol)
	pivot.add_child(_tete)
	_bout = _calque(_peindre_bout)
	_tete.add_child(_bout)
	_bout.position = _anneau


func _calque(f: Callable) -> Calque:
	var c := Calque.new()
	c.peindre = f
	return c


# le bord d'une image, en partant d'un point qui est dedans : on marche jusqu'à sortir du dessin (ou jusqu'à « loin »)
static func _bord(im: Dictionary, p0: Vector2, dir: Vector2, loin: float) -> Vector2:
	var img: Image = im.get("image")
	if img == null:
		return p0 + dir * loin * 0.6
	var pos: Vector2 = im["pos"]
	var taille: Vector2 = im["taille"]
	var ech := float(img.get_width()) / maxf(taille.x, 1.0)
	var dernier := p0
	var d := 0.0
	while d <= loin:
		var q := p0 + dir * d
		var px := int((q.x - pos.x) * ech)
		var py := int((q.y - pos.y) * ech)
		if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height() or img.get_pixel(px, py).a < 0.5:
			break
		dernier = q
		d += 0.4
	return dernier


# le haut et le bas du dessin à cette abscisse (une colonne de l'image) ; rien là : ce que dit son cadre
static func _colonne(im: Dictionary, x: float) -> Vector2:
	var rc: Rect2 = im["rect"]
	var out := Vector2(rc.position.y + rc.size.y * 0.12, rc.end.y - rc.size.y * 0.1)
	var img: Image = im.get("image")
	if img == null:
		return out
	var pos: Vector2 = im["pos"]
	var taille: Vector2 = im["taille"]
	var ech := float(img.get_width()) / maxf(taille.x, 1.0)
	var px := int((x - pos.x) * ech)
	if px < 0 or px >= img.get_width():
		return out
	var h := img.get_height()
	for py in h:
		if img.get_pixel(px, py).a > 0.5:
			out.x = pos.y + py / ech
			break
	for py in h:
		if img.get_pixel(px, h - 1 - py).a > 0.5:
			out.y = pos.y + (h - py) / ech
			break
	return out


# le dos et le ventre, entre les hanches et les épaules : là où se posent la selle, les sacoches, leurs sangles
func _mesurer_corps() -> void:
	var b = bete
	var corps: Dictionary = b._sq["corps"]
	var rc: Rect2 = corps["rect"]
	var hanches: Array = b._p_pts
	var devant: Array = b._p_devant
	var xr := 0.0
	var xf := 0.0
	var nr := 0
	var nf := 0
	for i in hanches.size():
		var pts: PackedVector2Array = hanches[i]
		if bool(devant[i]):
			xf += pts[0].x
			nf += 1
		else:
			xr += pts[0].x
			nr += 1
	_xr = xr / nr if nr > 0 else rc.position.x + rc.size.x * 0.25
	_xf = xf / nf if nf > 0 else rc.position.x + rc.size.x * 0.75
	if _xf - _xr < 4.0:
		_xr = rc.position.x + rc.size.x * 0.25
		_xf = rc.position.x + rc.size.x * 0.75
	for i in N_DOS:
		var x := lerpf(_xr, _xf, float(i) / (N_DOS - 1))
		var c := _colonne(corps, x)
		_dos_pts.append(Vector2(x, c.x))
		_ventre_pts.append(Vector2(x, c.y))
	var long := _xf - _xr
	_k = clampf(0.22 * long / 7.0, 0.5, 1.15)
	# (la selle, juste derrière le garrot : son milieu, la pente du dos à cet endroit, et le creux où l'on s'assied)
	_o = _dos(0.58)
	_ang = clampf((_dos(0.8) - _dos(0.36)).angle(), -0.3, 0.3)
	_creux = _o + Vector2(-1.2, -2.2).rotated(_ang) * _k


func _dos(s: float) -> Vector2:
	var x := clampf(s, 0.0, 1.0) * (N_DOS - 1)
	var i := mini(int(x), N_DOS - 2)
	return _dos_pts[i].lerp(_dos_pts[i + 1], x - i)


func _ventre(s: float) -> Vector2:
	var x := clampf(s, 0.0, 1.0) * (N_DOS - 1)
	var i := mini(int(x), N_DOS - 2)
	return _ventre_pts[i].lerp(_ventre_pts[i + 1], x - i)


# la tête : l'œil et le bout du museau donnent son axe ; les tours de corde vont d'un bord à l'autre, en travers
func _mesurer_tete() -> void:
	var b = bete
	var tete: Dictionary = b._sq["tete"]
	if tete.is_empty() or b._tete == null:
		_anneau = _dos(1.0)
		return
	_a_tete = true
	var rt: Rect2 = tete["rect"]
	var oeil := Vector2(rt.end.x - rt.size.x * 0.42, rt.position.y + rt.size.y * 0.38)
	var r_oeil := 1.2
	if bool(b._a_oeil):
		oeil = b._oeil_local
		r_oeil = float(b._oeil_rayon)
	var col := _colonne(tete, rt.end.x - 0.8)
	var nez := Vector2(rt.end.x - 0.8, (col.x + col.y) * 0.5)
	var d := maxf(oeil.distance_to(nez), 3.0)
	var u := (nez - oeil) / d if oeil.distance_to(nez) > 0.5 else Vector2.RIGHT
	var v := Vector2(-u.y, u.x)
	_w = clampf(d / 10.0, 0.62, 1.1)
	# (le tour de museau : entre l'œil et le nez, plus près du nez)
	var m0 := oeil + u * maxf(d * 0.6, r_oeil + 1.6)
	_mh = _bord(tete, m0, -v, d * 0.9)
	_mb = _bord(tete, m0, v, d * 0.9)
	# (le tour de nuque : derrière l'œil, un peu couché vers l'arrière ; il s'arrête au crâne, pas au bout des oreilles)
	var crane := minf(oeil.distance_to(_bord(tete, oeil, -v, d * 0.7)), r_oeil + d * 0.3)
	var n0 := oeil - u * (r_oeil + d * 0.34) + v * d * 0.12
	_nh = _bord(tete, n0, (-v - u * 0.3).normalized(), crane + d * 0.16)
	_nb = _bord(tete, n0, (v - u * 0.12).normalized(), d * 1.1)
	# (le montant, de l'un à l'autre : il passe sous l'œil)
	var a := _mh.lerp(_mb, 0.5)
	var c := _nh.lerp(_nb, 0.55)
	_joue = (a + c) * 0.5
	var sous := (_joue - oeil).dot(v)
	if sous < r_oeil + 1.2:
		_joue += v * (r_oeil + 1.2 - sous)
	_anneau = _mb + v * 1.0 * _w


# --- chaque image ---

func suivre() -> void:
	var b = bete
	var dt := minf(get_process_delta_time(), 0.05)
	var h: Dictionary = b.harnais
	var licol := bool(h.get("licol", false))
	var selle := bool(h.get("selle", false))
	var sacoche := bool(h.get("sacoche", false))
	var cle := (1 if licol else 0) + (2 if selle else 0) + (4 if sacoche else 0) + (8 if bool(h.get("longe", false)) else 0)
	if cle != _porte:
		_porte = cle
		_poser(licol, selle, sacoche)
	var mort: float = b._mort
	var montee := bool(b.montee) and mort < 0.0
	var pivot: Node2D = b._pivot
	var tc: Transform2D = b._t_corps
	var tt: Transform2D = b._t_tete
	# ce qui pend ballotte : un pendule, que ses élans et son pas dérangent
	var vit: Vector2 = b._vit
	var ax := (vit.x - _vit_avant.x) / maxf(dt, 0.001) * signf(pivot.scale.x)
	_vit_avant = vit
	_bal_v += (-81.0 * _bal - 4.5 * _bal_v - 0.006 * clampf(ax, -900.0, 900.0)) * dt
	_bal = clampf(_bal + _bal_v * dt, -0.6, 0.6)
	if bool(b._a_l_ecran):
		var pas := sin(TAU * 2.0 * float(b._phase)) * float(b._marche) * (1.0 + 0.6 * float(b._course))
		_pres.transform = tc
		_loin.transform = tc * Transform2D(0.0, Vector2(0.0, 0.5 * pas))
		_tete.transform = tc * tt
		_sac.rotation = _bal + 0.07 * pas
		_sac.position = _charniere + Vector2(0.0, 0.5 * absf(pas))
		# (un pied dans l'étrier le tient en avant ; vide, il bat)
		_etrier.rotation = -0.3 if montee else _bal * 1.4 + 0.1 * pas
		_bout.rotation = _bal * 1.6 + 0.12 * pas
		_bout.visible = licol and not montee and b.longe == null
		if mort >= 0.0:
			# (elle tombe : son harnais s'efface avec son encre)
			var ef := 1.0 - clampf((mort - float(b.CHUTE) - float(b.GISANT)) / float(b.EFFACEMENT), 0.0, 1.0)
			_pres.modulate.a = ef
			_loin.modulate.a = ef
			_tete.modulate.a = ef
	# la longe : de l'anneau à la main qui la tient, à la tête du piquet ; en selle, les rênes
	var corde := 0
	var but := Vector2.ZERO
	var sol_b := 0.0
	var long := _long
	var j = b.jeu.joueur if b.jeu != null else null
	var ici := pivot.transform * (tc * (tt * _anneau))
	if licol and mort < 0.0:
		if montee and j != null:
			corde = 2
			but = to_local(_main(j, ici, true))
			sol_b = but.y + 30.0
		elif b.longe != null:
			corde = 1
			var l: Vector2 = b.longe
			if j != null and l.distance_to(j.global_position) < 3.0:
				but = to_local(_main(j, ici, false))
				sol_b = j.global_position.y - global_position.y
				long = 58.0 + float(b.largeur) * 0.4 + LONGE_MOU
			else:
				# (les règles donnent l'anneau du piquet lui-même : scripts/elevage.gd, Campement.ANNEAU)
				but = to_local(l)
				sol_b = l.y + 9.0 - global_position.y
				long = LONGE_PIQUET
	# celle qui la monte : dessinée ici, par-dessus la selle
	var cav = j if montee and j != null and j.get("monture") == b and j.has_method("peindre_en_selle") else null
	var d := ici.distance_to(but)
	var fleche := sqrt(maxf(0.0, 0.375 * d * (maxf(long, d) - d))) if corde == 1 else 2.2
	var avant := _fleche
	_fleche = lerpf(_fleche, fleche, 1.0 - exp(-dt * 7.0)) if corde == _corde else fleche
	if corde != _corde or cav != null or cav != _cavaliere or absf(_fleche - avant) > 0.02 or absf(_bal_v) > 0.03 \
			or ici.distance_squared_to(_ca) > 0.01 or but.distance_squared_to(_cb) > 0.01 or bool(h.get("longe", false)) != _filin:
		_corde = corde
		_filin = bool(h.get("longe", false))
		_cavaliere = cav
		_ca = ici
		_cb = but
		_sol_b = sol_b
		_long = long
		queue_redraw()


# la main qui tient sa longe, dans le lieu (la veilleuse le sait : sa main suit la corde)
func _main(j, anneau: Vector2, renes: bool) -> Vector2:
	if j.has_method("prise_longe"):
		return j.prise_longe(to_global(anneau), renes)
	return j.global_position + Vector2(0.0, -15.0)


# où s'assied qui la monte, dans le lieu : le creux de la selle, qui suit le dos
func siege() -> Vector2:
	var pivot: Node2D = bete._pivot
	var tc: Transform2D = bete._t_corps
	return to_global(pivot.transform * (tc * _creux))


# ce qu'elle porte a changé : où vont les sacoches (derrière la selle, s'il y en a une), ce qui se voit
func _poser(licol: bool, selle: bool, sacoche: bool) -> void:
	_s_sac = 0.2 if selle else 0.48
	var haut := _dos(_s_sac)
	var epais := _ventre(_s_sac).y - haut.y
	_ks = minf(clampf((_xf - _xr) * 0.2 / 4.5, 0.6, 1.2), maxf(0.45, epais * 0.66 / 9.2))
	_charniere = haut + Vector2(0.0, 0.8)
	_etrier.position = _o + Vector2(1.6, 3.6).rotated(_ang) * _k
	_loin.visible = sacoche
	_sac.visible = sacoche
	_etrier.visible = selle
	_pres.visible = selle or sacoche
	_tete.visible = licol and _a_tete
	for c in [_loin, _pres, _sac, _etrier, _tete, _bout]:
		c.queue_redraw()


# --- ce qui se dessine ---

static func _forme(c: CanvasItem, pts: PackedVector2Array, couleur: Color, w: float = 1.0) -> void:
	c.draw_colored_polygon(pts, couleur)
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	c.draw_polyline(ferme, P.ENCRE, w, true)


# une corde : son encre, puis son chanvre (un fil net, sans frange : à cette finesse, la frange mangerait l'encre)
static func _brin(c: CanvasItem, pts: PackedVector2Array, w: float, ton: Color = CHANVRE) -> void:
	c.draw_polyline(pts, P.ENCRE, 1.9 * w, true)
	c.draw_polyline(pts, ton, 0.85 * w, false)


# une sangle de cuir, du dos au ventre : elle suit le rond du flanc
func _sangle(c: CanvasItem, haut: Vector2, s: float, boucle: bool) -> void:
	var bas := _ventre(s) + Vector2(0.0, 0.4)
	bas.x = haut.x + 0.6
	var pts := PackedVector2Array([haut, haut.lerp(bas, 0.55) + Vector2(1.1, 0.0), bas])
	c.draw_polyline(pts, P.ENCRE, 2.7, true)
	c.draw_polyline(pts, CUIR_OMBRE.lightened(0.12), 1.4, true)
	if boucle and not _mobile:
		var q := haut.lerp(bas, 0.3) + Vector2(0.5, 0.0)
		c.draw_rect(Rect2(q - Vector2(1.1, 1.0), Vector2(2.2, 2.0)), P.ENCRE)
		c.draw_rect(Rect2(q - Vector2(0.6, 0.5), Vector2(1.2, 1.0)), PIERRE.lightened(0.15))


# la poche d'une sacoche, pendue par son haut (0, 0) : son rabat, son bouton d'os, son lien
func _poche(c: CanvasItem, loin: bool) -> void:
	var peau := PEAU_OMBRE.darkened(0.25) if loin else PEAU
	var poche := PackedVector2Array([Vector2(-4.2, 0.4), Vector2(4.2, 0.4), Vector2(4.9, 5.4), Vector2(3.5, 9.0), Vector2(0.0, 9.6), Vector2(-3.5, 9.0), Vector2(-4.9, 5.4)])
	_forme(c, poche, peau)
	if loin:
		return
	c.draw_colored_polygon(PackedVector2Array([Vector2(0.6, 5.0), Vector2(4.7, 5.2), Vector2(3.4, 8.8), Vector2(0.0, 9.3), Vector2(-3.2, 8.6)]), PEAU_OMBRE)
	var rabat := PackedVector2Array([Vector2(-4.6, 0.0), Vector2(4.6, 0.0), Vector2(4.5, 3.0), Vector2(0.0, 4.7), Vector2(-4.5, 3.0)])
	_forme(c, rabat, PEAU_CLAIR.lerp(PEAU, 0.35), 0.8)
	c.draw_line(Vector2(-3.4, 1.0), Vector2(1.4, 1.0), PEAU_CLAIR.lightened(0.12), 0.7, true)
	c.draw_line(Vector2(0.0, 4.6), Vector2(0.3, 7.2), P.ENCRE, 0.8, true)
	c.draw_circle(Vector2(0.0, 4.9), 1.15, P.ENCRE)
	c.draw_circle(Vector2(0.0, 4.9), 0.65, IVOIRE_OS)
	if not _mobile:
		# (la couture du fond)
		for i in 3:
			c.draw_line(Vector2(-2.4 + 2.0 * i, 8.0), Vector2(-1.4 + 2.0 * i, 8.1), PEAU_CLAIR, 0.6, true)


# derrière le corps : la poche de l'autre flanc, dont le haut dépasse de l'échine
func _peindre_loin(c: CanvasItem) -> void:
	c.draw_set_transform(_charniere + Vector2(1.6, -3.6 * _ks), 0.0, Vector2(_ks, _ks))
	_poche(c, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# sur le corps : les sangles, le tapis, la selle ; le bât des sacoches, qui passe par-dessus le dos
func _peindre_pres(c: CanvasItem) -> void:
	var selle := (_porte & 2) != 0
	var sacoche := (_porte & 4) != 0
	if sacoche:
		_sangle(c, _charniere + Vector2(1.0, 3.0 * _ks), _s_sac + 0.03, false)
		var pont := PackedVector2Array([_charniere + Vector2(-2.6, 0.9) * _ks, _charniere + Vector2(0.0, -1.5) * _ks, _charniere + Vector2(3.0, -2.2) * _ks])
		c.draw_polyline(pont, P.ENCRE, 3.4 * _ks, true)
		c.draw_polyline(pont, CUIR_OMBRE.lightened(0.1), 2.0 * _ks, true)
	if not selle:
		return
	_sangle(c, _o + Vector2(2.4, 4.4).rotated(_ang) * _k, 0.58 + 2.4 * _k / maxf(_xf - _xr, 1.0), true)
	c.draw_set_transform(_o, _ang, Vector2(_k, _k))
	# le tapis : du chanvre tissé, son liseré rouille (celui de son écharpe), ses franges
	var tapis := PackedVector2Array([Vector2(-7.6, -0.9), Vector2(-4.0, -1.3), Vector2(0.0, -1.4), Vector2(4.0, -1.3), Vector2(7.4, -0.9), Vector2(7.9, 2.5),
		Vector2(7.2, 6.6), Vector2(0.0, 7.0), Vector2(-7.4, 6.6), Vector2(-8.1, 2.5)])
	_forme(c, tapis, TAPIS)
	c.draw_colored_polygon(PackedVector2Array([Vector2(1.0, 3.6), Vector2(7.7, 3.2), Vector2(7.2, 6.6), Vector2(0.0, 7.0), Vector2(-7.4, 6.6), Vector2(-7.7, 5.0)]), TAPIS_OMBRE)
	c.draw_polyline(PackedVector2Array([Vector2(-7.5, 5.3), Vector2(0.0, 5.7), Vector2(7.3, 5.3)]), P.ECHARPE, 0.9, true)
	if not _mobile:
		for i in 5:
			var x := -6.0 + 3.0 * i
			c.draw_line(Vector2(x, 6.8), Vector2(x - 0.3, 8.1), P.ENCRE, 0.7, true)
	# la selle : le troussequin derrière, le pommeau devant, le creux entre les deux ; son quartier qui descend sur le flanc
	var siege_ := PackedVector2Array([Vector2(-6.4, -4.4), Vector2(-4.6, -3.0), Vector2(-1.5, -2.2), Vector2(2.5, -2.5), Vector2(4.8, -4.0), Vector2(6.0, -3.2),
		Vector2(6.2, -1.0), Vector2(5.2, 0.6), Vector2(4.6, 4.2), Vector2(0.5, 5.0), Vector2(-3.2, 4.2), Vector2(-4.6, 0.8), Vector2(-7.0, -0.8), Vector2(-7.2, -3.0)])
	_forme(c, siege_, PEAU)
	c.draw_colored_polygon(PackedVector2Array([Vector2(5.2, 0.6), Vector2(4.6, 4.2), Vector2(0.5, 5.0), Vector2(-3.2, 4.2), Vector2(-4.6, 0.8), Vector2(0.0, 1.4)]), PEAU_OMBRE)
	c.draw_polyline(PackedVector2Array([Vector2(-5.8, -3.5), Vector2(-4.2, -2.2), Vector2(-1.4, -1.5), Vector2(2.6, -1.8), Vector2(4.6, -3.2)]), PEAU_CLAIR.lightened(0.1), 0.8, true)
	c.draw_polyline(PackedVector2Array([Vector2(-6.6, -0.6), Vector2(-1.0, 0.7), Vector2(5.6, -0.3)]), Color(P.ENCRE, 0.75), 0.7, true)
	if not _mobile:
		# (la couture du quartier, le lacet du pommeau)
		for i in 4:
			var q := Vector2(-2.6 + 1.9 * i, 3.4 + 0.5 * sin(i * 1.2))
			c.draw_line(q, q + Vector2(0.9, 0.1), PEAU_CLAIR, 0.6, true)
		c.draw_line(Vector2(5.0, -2.2), Vector2(5.6, -0.4), IVOIRE_OS, 0.7, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# la poche de ce flanc-ci (elle tourne autour de son haut : _sac.rotation)
func _peindre_sac(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(_ks, _ks))
	_poche(c, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# l'étrier : une corde doublée, une marche de bois
func _peindre_etrier(c: CanvasItem) -> void:
	var bas := maxf(1.5, ETRIER - (_etrier.position.y - _creux.y) - 2.0)
	c.draw_line(Vector2.ZERO, Vector2(0.0, bas), P.ENCRE, 1.9, true)
	c.draw_line(Vector2.ZERO, Vector2(0.0, bas), CHANVRE, 0.9, true)
	var boucle := PackedVector2Array([Vector2(-1.7, bas + 2.0), Vector2(0.0, bas), Vector2(1.7, bas + 2.0)])
	c.draw_polyline(boucle, P.ENCRE, 1.7, true)
	c.draw_polyline(boucle, CHANVRE, 0.8, true)
	c.draw_line(Vector2(-2.1, bas + 2.1), Vector2(2.1, bas + 2.1), P.ENCRE, 2.2, true)
	c.draw_line(Vector2(-1.7, bas + 2.1), Vector2(1.7, bas + 2.1), BOIS, 1.1, true)


# le licol : le tour de museau, le tour de nuque, le montant sous l'œil ; ses nœuds, son anneau d'os sous le menton
func _peindre_licol(c: CanvasItem) -> void:
	if not _a_tete:
		return
	var w := _w
	var u := (_mh - _mb).orthogonal().normalized()
	if u.x < 0.0:
		u = -u
	var a := _mh.lerp(_mb, 0.5)
	var b := _nh.lerp(_nb, 0.55)
	_brin(c, PackedVector2Array([_nh, _nh.lerp(_nb, 0.5) - u * 0.7 * w, _nb]), w)
	_brin(c, PackedVector2Array([b, _joue, a]), w)
	_brin(c, PackedVector2Array([_mh, a + u * 0.7 * w, _mb]), w)
	# (un fil plus clair sur le dessus du museau : la corde tourne)
	c.draw_line(_mh.lerp(_mb, 0.12) + u * 0.2, _mh.lerp(_mb, 0.4) + u * 0.6 * w, CHANVRE.lightened(0.22), 0.6 * w, true)
	for q in [a + u * 0.5 * w, b]:
		c.draw_circle(q, 0.9 * w, P.ENCRE)
		c.draw_circle(q, 0.45 * w, CHANVRE.darkened(0.15))
	c.draw_circle(_anneau, 1.4 * w, P.ENCRE)
	c.draw_circle(_anneau, 0.9 * w, IVOIRE_OS)
	c.draw_circle(_anneau, 0.36 * w, P.ENCRE)


# la longe nouée court : une boucle et son bout, sous l'anneau (elle tourne : _bout.rotation)
func _peindre_bout(c: CanvasItem) -> void:
	var w := _w
	var filin: bool = bete != null and bool(bete.harnais.get("longe", false))
	var ton := FILIN if filin else CHANVRE
	var e := w * (1.0 if filin else 0.8)
	_brin(c, PackedVector2Array([Vector2(0.0, 0.8) * w, Vector2(1.2, 2.6) * w, Vector2(0.2, 4.6) * w, Vector2(-1.0, 2.8) * w, Vector2(0.0, 1.0) * w]), e, ton)
	_brin(c, PackedVector2Array([Vector2(0.0, 1.2) * w, Vector2(0.5, 4.2) * w, Vector2(-0.2, 7.4 if filin else 6.8) * w]), e, ton)
	if filin:
		# (son bout surlié : trois tours de fil sombre, pour qu'il ne s'effiloche pas)
		var bout := Vector2(-0.1, 6.0) * w
		c.draw_line(bout + Vector2(-0.9, 0.0) * w, bout + Vector2(0.9, -0.2) * w, FILIN_TORON.darkened(0.3), 0.9 * w, true)


# la longe (les rênes), et celle qui la monte
func _draw() -> void:
	if _cavaliere != null and is_instance_valid(_cavaliere):
		_cavaliere.peindre_en_selle(self)
	if _corde == 0:
		return
	var n := 9 if _mobile else 16
	var libre := _corde == 1
	var d := _ca.distance_to(_cb)
	# (jamais un trait droit : même tendue, elle garde un peu de ventre)
	var fl := maxf(_fleche, 0.035 * d + 1.0)
	var ha := maxf(0.0, -_ca.y)
	var hb := maxf(0.0, _sol_b - _cb.y)
	var pts := PackedVector2Array()
	var ombre := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var bosse := 4.0 * t * (1.0 - t)
		var hh := lerpf(ha, hb, t) - fl * bosse
		var x := lerpf(_ca.x, _cb.x, t)
		var sol := lerpf(0.0, _sol_b, t)
		if libre:
			x += _bal * 12.0 * bosse
			# (elle arrive au sol en douceur, et y traîne en boucles molles)
			var pose := clampf(-hh / 4.0, 0.0, 1.0) * bosse
			x += 1.9 * sin(t * 17.0 + _graine) * pose
			sol += 1.0 * sin(t * 11.0 + 1.3 + _graine) * pose
			hh = 0.5 * (hh + sqrt(hh * hh + 5.0 * bosse))
		pts.append(Vector2(x, sol - hh))
		# (son ombre, sous ce qui est en l'air)
		if libre and hh > 2.0 and not _mobile:
			ombre.append(Vector2(x, sol + 0.6))
		else:
			if ombre.size() > 1:
				draw_polyline(ombre, Color(0, 0, 0, 0.12), 1.5, true)
			ombre.clear()
	if ombre.size() > 1:
		draw_polyline(ombre, Color(0, 0, 0, 0.12), 1.5, true)
	if _filin and libre:
		# (la longe de filin : plus grosse, blonde ; ses torons tournent en biais, un sur deux points)
		_brin(self, pts, _w * 1.05, FILIN)
		for i in range(1, pts.size() - 1, 2):
			var sens := (pts[i + 1] - pts[i - 1]).normalized()
			var t := sens.orthogonal() * 0.42 * _w
			draw_line(pts[i] - t - sens * 0.5 * _w, pts[i] + t + sens * 0.5 * _w, FILIN_TORON, 0.45 * _w, true)
	else:
		_brin(self, pts, _w * (0.85 if libre else 0.75))
