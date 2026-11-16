extends RefCounted
# Lisière — le corps de la veilleuse (scripts/veilleuse_corps.gd)
# Sa pose, et son dessin à l'encre. Chaque partie est un point du corps (devant, à sa droite, en hauteur, en pixels), tourné vers
# où elle regarde, puis vu de trois quarts : ce qui vient vers nous descend un peu. Ainsi elle tourne d'un seul tenant (de face,
# de trois quarts, de profil, de dos), sans images à part. Le joueur (scripts/joueur.gd) règle la pose à chaque image ; ici,
# on la dessine : la cape en plis, la capuche profonde et son visage pâle, l'écharpe rouille, le sac de cuir, les bottes.
# Sa tenue (scripts/atelier.gd) se dessine dans le même trait : le sac à dos de peau, sanglé, son rouleau ; la pelisse, qui
# l'épaissit et montre sa fourrure aux bords (le col, les poignets, l'ourlet, le tour du visage) ; la cape de pluie, cirée,
# claire, à capuchon pointu, par-dessus le reste. Les trois se portent ensemble. Sa lampe se tient de la main gauche.
# Ses gestes d'atelier : l'outil dans sa main (un maillet, une scie d'os, une aiguille, sa gourde, une cuiller), et l'ouvrage
# posé devant elle, qui ne bouge pas avec son corps (la pièce martelée, le rondin scié, la peau cousue, le piquet et sa corde).
# Son sommeil : couchée sur le côté, son duvet de peau jusqu'aux épaules, la capuche qui dépasse.
# Le jardin et l'élevage : la houe, le sachet de graines, l'outre à bec, le licol, la selle qu'elle porte, le bol ; la terre
# retournée, les graines à la volée, le filet d'eau, le lait. En selle : la cuisse sur le flanc de la bête, le genou en avant,
# la jambe de l'autre côté cachée par la bête ; pas d'ombre à ses pieds (c'est la bête qui la porte).
# Son lance-pierre (fronde) : une fourche de bois pelé, deux boyaux, une poche de cuir. Au repos il pend à sa ceinture, sur la
# hanche gauche, la fourche en bas, et balance avec son pas ; pour tirer il est dans son poing gauche (avec la torche ou la
# lampe, s'il y en a une), et les boyaux vont jusqu'à la poche, que sa main droite tire puis lâche.

const P := preload("res://scripts/palette.gd")
const INCL := 0.45            # la vue de trois quarts : ce qui avance vers nous d'un pixel descend d'autant
const TRAIT := 1.0            # l'encre du contour
const MAIN_D := Vector3(2.0, 7.0, 14.5)
const MAIN_G := Vector3(2.0, -7.0, 14.5)
const DIR_TORCHE := Vector3(0.18, -0.2, 1.0) / 1.036

# les couleurs, tirées de la palette
const CAPE := P.CAPE
const CAPE_OMBRE := Color("232733")
const CAPE_LISERE := Color("57607a")
const DOUBLURE := Color("0f121c")
const ECHARPE := P.ECHARPE
const ECHARPE_OMBRE := Color("6d2f18")
const ECHARPE_LISERE := Color("c0653a")
const VISAGE := P.VISAGE
const VISAGE_OMBRE := Color("a8977e")
const CUIR := Color("6e573c")
const CUIR_OMBRE := Color("4a3a28")
const CUIR_CLAIR := Color("9a7b55")
const ROULEAU := Color("7a6c54")
const MAIN := Color("c2b196")
const BOTTE := Color("2e241b")
const JAMBE := Color("1f1c19")
const BOIS := Color("8a6a45")
const PIERRE := Color("8f8a7f")
# la tenue : la peau tannée du sac, la fourrure de la pelisse, la toile cirée de la cape de pluie, la ferraille de la lampe
const PEAU := Color("8a6038")
const PEAU_OMBRE := Color("5f4128")
const PEAU_CLAIR := Color("a77a4c")
const PELISSE := Color("6c4529")
const PELISSE_OMBRE := Color("4a2f1f")
const PELISSE_LISERE := Color("92643c")
const FOURRURE := Color("b3a88f")
const FOURRURE_OMBRE := Color("7b705c")
const CIRE := Color("8e8b70")
const CIRE_OMBRE := Color("656350")
const CIRE_LISERE := Color("bab696")
const CIRE_PLI := Color("48463a")
const DUVET := Color("7f6748")
const DUVET_OMBRE := Color("58462f")
const DUVET_CLAIR := Color("a08763")
const IVOIRE_OS := Color("b3a88f")
const CHANVRE := Color("9c9168")
const FERRAILLE := Color("8b8a84")
const ROUILLE := Color("8a5433")
const DIR_LAMPE := Vector3(0.992, 0.0, -0.125)
# le lance-pierre : le bois pelé de la fourche, le boyau séché
const FOURCHE := Color("7f5d38")
const BOYAU := Color("d3c196")
const BOYAU_REPOS := 7.0      # la longueur d'un boyau qu'on ne tire pas
const HERBE := Color("6f8a45")
const MALADE := Color("9eae80")
# trempée, elle s'assombrit (le joueur en teinte tout son dessin) ; la toile cirée, non : sa couleur est relevée d'autant
const TON_MOUILLE := Color(0.7, 0.74, 0.85)

static var _doux: GradientTexture2D

var ci                         # ce qui dessine : un CanvasItem, ou une trace qui recueille tout (scripts/interface_trace.gd)
# --- la pose ---
var cap := 0.0                # les hanches : 0 vers nous, PI/2 vers la droite de l'écran, PI de dos, -PI/2 vers la gauche
var buste := 0.0              # le buste (les hanches et une torsion)
var tete := 0.0               # la tête
var bas := 0.0                # combien elle se baisse
var penche := 0.0             # combien le haut du corps passe devant
var elan := 0.0               # le corps qui part en avant (un coup), les pieds restant posés
var souffle := 0.0            # le buste qui monte et descend
var epaules := 0.0            # les épaules qui montent (la peur)
var hanche := 0.0             # le poids d'un pied sur l'autre
var tete_baisse := 0.0
var decal := Vector2.ZERO     # tout le corps, à l'écran (un recul, un tremblement)
var pied_d := Vector3(0, 2.5, 0)      # (devant, côté, levé)
var pied_g := Vector3(0, -2.5, 0)
var main_d := MAIN_D
var main_g := MAIN_G
var objet := ""               # ce que tient la main droite pendant un geste
var lance := false
var lance_main := -1.0        # la main qui tient la lance : -1 la gauche, 1 la droite (quand la gauche tient la torche)
var lance_dir := Vector3(0.2, 0.0, 1.0)
var torche := false           # la main gauche la tient
var cape := Vector2.ZERO      # le bas de la cape, en retard sur le corps
var plis := 0.0
var pan := 0.0                # les pans de l'écharpe, devant
var yeux := 1.0
var chute := Transform2D.IDENTITY
var allonge := 0.0            # 0 debout, 1 couchée
var sens_chute := 1.0
var echarpe := PackedVector2Array()   # la queue de l'écharpe (points, dans le nœud), simulée par le joueur
var mobile := false
# --- ce que le temps lui fait (le joueur le règle : scripts/joueur.gd) ---
var mouille := 0.0            # de 0 (sèche) à 1 (trempée) : des gouttes tombent d'elle, son manteau luit
var enfonce := 0.0            # en pixels : ses jambes dans l'eau, ses bottes dans la boue (on ne voit que ce qui dépasse)
var eau := 0.0                # de 0 à 1 : elle est dans l'eau (des rides autour d'elle)
var sillage := Vector2.ZERO   # sa marche dans l'eau, à l'écran (de 0 à 1) : le sillage part derrière elle
var froid := 0.0              # de 0 à 1 : son souffle fait de la buée, son visage bleuit
var chaud := 0.0              # de 0 à 1 : son visage rougit
var boue := 0.0               # de 0 à 1 : la boue sur ses bottes
var horloge := 0.0            # pour ce qui passe : les gouttes, la buée, les rides
# --- sa tenue (scripts/atelier.gd ; le joueur dit ce qu'elle porte) ---
var sac_a_dos := false        # le grand sac de peau, à la place du petit sac de cuir
var pelisse := false          # doublée de fourrure : elle l'épaissit, et se voit aux bords
var cire := false             # la cape de pluie, par-dessus
var lampe := false            # la lampe, allumée, dans sa main gauche (jamais avec la torche)
var pluie := 0.0              # la pluie qu'il fait, de 0 à 1 : la toile cirée luit, l'eau y perle
var ballant := Vector2.ZERO   # le sac à dos, en retard sur le corps (à l'écran)
var godet := 0.0              # le gobelet pendu au sac, qui balance (un angle)
var lampe_dir := DIR_LAMPE    # vers où elle la pointe (devant, à droite, en hauteur)
# --- ses gestes d'atelier (le joueur les règle) ---
var outil := ""               # ce que tient sa main : maillet, scie, aiguille, gourde, cuiller, trouvaille
var outil_main := 1.0         # la main qui le tient : 1 la droite, -1 la gauche (elle travaille de la main qu'on voit)
var outil_dir := Vector3(0, 0, 1)
var ouvrage := ""             # ce sur quoi elle travaille, posé devant elle : piece, rondin, peau, piquet, fouille
var ouvrage_ou := Vector3.ZERO    # où (devant, de côté, en hauteur), sans la pose : il ne bouge pas avec elle
var ouvrage_u := 0.0          # où il en est : le rondin se fend, le piquet s'enfonce, les points de la couture
var eclats := -1.0            # depuis le dernier coup (des copeaux, de la sciure, de la terre) ; -1 : rien
var fil := 0.0                # un fil, une corde, de l'ouvrage à sa main (de 0 à 1 : sa présence)
var lance_pose := 0.0         # la lance : 0 dans sa main, 1 posée au sol près d'elle
var lance_sol := PackedVector2Array([Vector2(-10, 6), Vector2(15, 8)])   # où (à l'écran) : son talon, sa pointe
# --- son lance-pierre (le joueur le règle) ---
var fronde := 0               # 0 : elle n'en a pas ; 1 : pendu à sa ceinture, sur la hanche gauche ; 2 : dans son poing gauche
var fronde_u := Vector3(0, 0, 1)      # dans son poing : vers où monte la fourche
var fronde_a := Vector3(0, 1, 0)      # et l'axe de ses deux branches
var poche := Vector3.ZERO     # la poche de cuir, au bout des deux boyaux (dans sa main droite quand elle la tire)
var fronde_galet := false     # un galet dans la poche
var fronde_bal := 0.0         # à la ceinture, il balance avec son pas (un angle)
# --- son sommeil ---
var filet := 0.0              # le filet d'eau de l'outre, de 0 à 1
var selle := 0.0              # de 0 (à pied) à 1 (en selle : assise, une jambe de chaque côté)
var dort := 0.0               # le duvet qui la couvre, de 0 à 1
var respire := 0.0            # son souffle de dormeuse, de -1 à 1
# ce que les herbes lui font (scripts/botanique.gd ; scripts/joueur.gd, _poser_herbes)
var malade := 0.0             # de 0 à 1 : le poison verdit son visage et ses mains
var crache := -1.0            # depuis qu'elle a recraché l'herbe âcre, en secondes ; -1 : rien
var soupir := 0.0             # de 0 à 1 : le long souffle du poison qui la quitte
var c_visage := VISAGE
var c_main := MAIN
var c_botte := BOTTE
var c_cire := CIRE
var c_cire_ombre := CIRE_OMBRE
var c_cire_lisere := CIRE_LISERE
# la carrure (la pelisse l'épaissit) : la largeur et la profondeur des épaules, de la taille, de l'ourlet ; l'épaule ; la manche
var _ep := Vector2(7.0, 4.8)
var _ta := Vector2(7.5, 5.6)
var _ou := Vector2(10.8, 8.4)
var _epaule := 6.2
var _manche := 0.0
# --- ce que le dessin donne au joueur ---
var bout_torche := Vector2.ZERO
var prof_torche := 0.0
var bout_lampe := Vector2.ZERO    # le verre de la lampe (sa lueur, son faisceau)
var prof_lampe := 0.0
var ancre_echarpe := Vector2.ZERO
var prof_echarpe := 0.0
var main_d_ecran := Vector2.ZERO
var main_g_ecran := Vector2.ZERO
var pointe_lance := Vector2.ZERO


static func doux() -> GradientTexture2D:
	if _doux == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_doux = t
	return _doux


# --- la projection ---

# un point du corps, tourné vers th, vu de trois quarts (sans la pose)
static func proj(v: Vector3, th: float) -> Vector2:
	var s := sin(th)
	var c := cos(th)
	return Vector2(v.x * s - v.y * c, -v.z + (v.x * c + v.y * s) * INCL)


# combien un point du corps vient vers nous (pour l'ordre du dessin)
static func prof(v: Vector3, th: float) -> float:
	return v.x * cos(th) + v.y * sin(th)


# un point du corps, avec la pose : elle se baisse, se penche, respire, part en avant
func pt(v: Vector3, th: float) -> Vector2:
	var k := clampf((v.z - 1.0) / 8.0, 0.0, 1.0)
	var h := v.z - bas * k
	if v.z > 12.0:
		h += souffle * clampf((v.z - 12.0) / 16.0, 0.0, 1.0)
	var f := v.x + penche * clampf(v.z / 36.0, 0.0, 1.4) + elan * k
	var cote := v.y + hanche * k
	return proj(Vector3(f, cote, h), th) + decal + Vector2(0.0, enfonce)


# le point du corps qui, la pose prise, se trouve là (devant, de côté, en hauteur, comme si elle se tenait droite) : pour poser
# une main sur ce qui ne bouge pas avec elle (un piquet, une pièce sur l'établi)
func depose(w: Vector3) -> Vector3:
	var b := minf(bas, 7.8)
	var z := w.z + b
	if z < 9.0:
		z = clampf((w.z - b / 8.0) / (1.0 - b / 8.0), 0.0, 9.0)
	var k := clampf((z - 1.0) / 8.0, 0.0, 1.0)
	return Vector3(w.x - penche * clampf(z / 36.0, 0.0, 1.4) - elan * k, w.y - hanche * k, z)


# un point du lieu autour d'elle (devant, de côté, en hauteur), sans sa pose
func sol(v: Vector3) -> Vector2:
	return proj(v, cap) + Vector2(0.0, enfonce)


# les points qui servent au joueur (la torche, l'écharpe, les mains), avant le dessin
func preparer() -> void:
	# (le froid bleuit son visage et ses mains, la chaleur les rougit ; la boue colle à ses bottes)
	c_visage = VISAGE.lerp(P.LUNE.lightened(0.5), 0.45 * froid).lerp(P.BRAISE_ROUGE.lerp(VISAGE, 0.3), 0.8 * chaud)
	c_main = MAIN.lerp(P.LUNE.lightened(0.4), 0.5 * froid).lerp(P.BRAISE_ROUGE.lerp(MAIN, 0.4), 0.6 * chaud)
	c_visage = c_visage.lerp(MALADE, 0.6 * malade)
	c_main = c_main.lerp(MALADE.darkened(0.1), 0.45 * malade)
	c_botte = BOTTE.lerp(P.TERRE.lerp(P.ENCRE_DOUCE, 0.25), 0.75 * boue)
	# (la pelisse l'épaissit : les épaules, la taille, l'ourlet, les manches)
	var gros := 1.12 if pelisse else 1.0
	_ep = Vector2(7.0, 4.8) * gros
	_ta = Vector2(7.5, 5.6) * (gros + 0.03 if pelisse else 1.0)
	_ou = Vector2(10.8, 8.4) * (1.07 if pelisse else 1.0)
	_epaule = 6.2 * gros
	_manche = 0.8 if pelisse else 0.0
	# (la toile cirée ne boit pas l'eau : elle garde sa couleur quand le reste s'assombrit)
	var sec := Color.WHITE.lerp(TON_MOUILLE, mouille)
	c_cire = Color(CIRE.r / sec.r, CIRE.g / sec.g, CIRE.b / sec.b)
	c_cire_ombre = Color(CIRE_OMBRE.r / sec.r, CIRE_OMBRE.g / sec.g, CIRE_OMBRE.b / sec.b)
	c_cire_lisere = Color(CIRE_LISERE.r / sec.r, CIRE_LISERE.g / sec.g, CIRE_LISERE.b / sec.b)
	ancre_echarpe = chute * pt(Vector3(-3.6, 1.6, 29.6 + epaules), buste)
	prof_echarpe = prof(Vector3(-3.6, 1.6, 0.0), buste)
	main_d_ecran = chute * pt(main_d, buste)
	main_g_ecran = chute * pt(main_g, buste)
	if torche:
		bout_torche = chute * pt(main_g + DIR_TORCHE * 10.5, buste)
		prof_torche = prof(main_g, buste)
	if lampe:
		bout_lampe = chute * pt(main_g + lampe_dir * 5.4, buste)
		prof_lampe = prof(main_g + lampe_dir * 5.0, buste)
	if lance:
		var main := main_d if lance_main > 0.0 else main_g
		pointe_lance = chute * pt(main + lance_dir.normalized() * 31.0, buste)


# --- le dessin ---

func dessiner() -> void:
	if selle < 0.5:
		_ombres()
	if lance and lance_pose > 0.5:
		_lance_posee()
	ci.draw_set_transform_matrix(chute)
	# les jambes d'abord : la cape les couvre
	var jambes := [[prof(pied_d, cap), pied_d, 1.0], [prof(pied_g, cap), pied_g, -1.0]]
	jambes.sort_custom(func(a, b): return a[0] < b[0])
	var couchee := dort > 0.01
	var parts := []
	for j in jambes:
		# (en selle : la jambe de l'autre flanc est derrière la bête ; celle qu'on voit passe par-dessus le manteau, la cuisse
		# à plat sur la selle)
		if selle > 0.5:
			if float(j[0]) > 0.5:
				parts.append([0.05, _jambe.bind(j[1], j[2])])
			elif float(j[0]) >= -0.5:
				_jambe(j[1], j[2])
			continue
		_jambe(j[1], j[2])
	parts.append([-0.5, _manteau])
	if not couchee:
		parts.append([0.2, _capuche])
		parts.append([0.3, _col])
	parts.append([-6.0 * cos(buste), _sac_a_dos if sac_a_dos else _sac])
	if sac_a_dos and not couchee:
		parts.append([0.1, _bretelles])
	var pd := prof(Vector3(0, 6.2, 0), buste) + 0.15 * prof(main_d, buste) + 0.6
	var pg := prof(Vector3(0, -6.2, 0), buste) + 0.15 * prof(main_g, buste) + 0.6
	parts.append([pd, _bras.bind(1.0)])
	parts.append([pg, _bras.bind(-1.0)])
	if echarpe.size() > 1:
		parts.append([prof_echarpe - 0.4, _queue])
	if not couchee:
		parts.append([prof(Vector3(3.6, -1.0, 0), buste) + 0.4, _pans])
	if ouvrage != "":
		parts.append([prof(ouvrage_ou, cap) * 0.6 + 1.0, _ouvrage])
	if fronde == 1 and not couchee and selle < 0.5:
		# (sur la hanche gauche, par-dessus le manteau et le bras : de l'autre profil, son corps le cache)
		parts.append([prof(Vector3(0.0, -8.6, 0.0), buste) + 1.2, _fronde_ceinture])
	parts.sort_custom(func(a, b): return a[0] < b[0])
	for p in parts:
		p[1].call()
	if couchee:
		# le duvet la couvre jusqu'aux épaules ; la capuche et l'écharpe en dépassent
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_duvet()
		ci.draw_set_transform_matrix(chute)
		_col()
		# (sa tête repose sur le côté, moins couchée que son corps : on voit son visage, ses yeux clos)
		var c0 := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
		var haut := chute * pt(Vector3(0.0, 0.0, 26.8 + epaules), buste)
		var pied := chute * pt(Vector3(0.0, 0.0, -7.5), cap)
		var le_long := (haut - pied).normalized()
		var repos := Transform2D(0.6 * sens_chute, haut + le_long * 6.6 + Vector2(0.0, -1.4)) * Transform2D(0.0, -c0)
		ci.draw_set_transform_matrix(chute.interpolate_with(repos, dort))
		_capuche()
	if allonge < 0.3:
		if mouille > 0.15:
			_gouttes()
		if cire and pluie > 0.04:
			_perles()
		if froid > 0.2:
			_buee()
		if crache >= 0.0 or soupir > 0.02:
			_bouche_herbes()
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# l'ombre de contact : douce sous le corps, plus nette sous chaque pied posé ; dans l'eau, des rides et son sillage
func _ombres() -> void:
	var t := doux()
	var c := Vector2(decal.x, decal.y * 0.3 + 0.6)
	var w := 24.0 + 5.0 * clampf(bas / 6.0, 0.0, 1.0) + 34.0 * allonge
	var h := 8.0 + 2.5 * allonge
	c.x += sens_chute * allonge * 17.0
	var sec := 1.0 - 0.45 * eau
	ci.draw_texture_rect(t, Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(0, 0, 0, 0.42 * sec))
	ci.draw_texture_rect(t, Rect2(c - Vector2(w, h) * 0.3, Vector2(w, h) * 0.6), false, Color(0, 0, 0, 0.28 * sec))
	if allonge < 0.5 and enfonce < 0.6:
		for f in [pied_d, pied_g]:
			var fp := pt(Vector3(f.x + 0.6, f.y, 0.0), cap)
			var a := 0.4 * clampf(1.0 - f.z / 2.6, 0.0, 1.0) * (1.0 - allonge * 2.0)
			ci.draw_texture_rect(t, Rect2(fp - Vector2(4.2, 1.6), Vector2(8.4, 3.2)), false, Color(0, 0, 0, a))
	if eau > 0.04 and allonge < 0.5:
		_rides(c)


# dans l'eau : des rides qui s'élargissent autour d'elle ; quand elle marche, elles restent en arrière, et un sillage s'ouvre
func _rides(c: Vector2) -> void:
	var pale := P.PAPIER.lerp(P.ECHO, 0.4)
	var v := sillage.length()
	var arriere := -sillage.normalized() if v > 0.05 else Vector2.ZERO
	for k in 2:
		var u := fposmod(horloge * (0.5 + 0.5 * v) + k * 0.5, 1.0)
		var rx := 8.0 + 13.0 * u
		var rond := _ellipse(c + arriere * Vector2(1.0, 0.5) * (4.0 + 16.0 * u) * v, rx, rx * 0.4, 16)
		rond.append(rond[0])
		ci.draw_polyline(rond, Color(pale, 0.42 * (1.0 - u) * eau), 0.9, true)
	if v > 0.15:
		var travers := arriere.orthogonal()
		for k in 2:
			var cote := -1.0 if k == 0 else 1.0
			var a := c + (travers * cote * 6.5 - arriere * 3.0) * Vector2(1.0, 0.5)
			var m := c + (travers * cote * 10.5 + arriere * 9.0) * Vector2(1.0, 0.5)
			var b := c + (travers * cote * 15.0 + arriere * 23.0) * Vector2(1.0, 0.5)
			ci.draw_polyline(PackedVector2Array([a, m]), Color(pale, 0.5 * eau * v), 1.1, true)
			ci.draw_polyline(PackedVector2Array([m, b]), Color(pale, 0.24 * eau * v), 0.9, true)


# ce qu'on voit d'un trait qui descend dans l'eau (ou dans la boue) : la part au-dessus de la ligne y0
static func _au_dessus(pts: PackedVector2Array, y0: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var p := pts[i]
		if p.y <= y0:
			out.append(p)
			continue
		if i > 0 and pts[i - 1].y < y0:
			var q := pts[i - 1]
			out.append(q.lerp(p, (y0 - q.y) / (p.y - q.y)))
		break
	return out


func _jambe(pied: Vector3, cote: float) -> void:
	var hanche_ := Vector3(0.0, cote * 2.6, 9.5)
	var genou := Vector3(pied.x * 0.5 + 0.7 + bas * 0.35, cote * 2.6, 5.2 + pied.z * 0.5)
	# (en selle : la cuisse à plat sur le flanc, le genou en avant et écarté)
	genou = genou.lerp(Vector3(3.8, cote * 4.7, 7.9), selle)
	var cheville := Vector3(pied.x, pied.y, pied.z + 1.4)
	var pts := PackedVector2Array([pt(hanche_, cap), pt(genou, cap), pt(cheville, cap)])
	# la botte : la tige, puis le pied qui pointe où elle va
	var tige := PackedVector2Array([pt(Vector3(pied.x - 0.2, pied.y, pied.z + 3.6), cap), pt(Vector3(pied.x, pied.y, pied.z + 0.9), cap)])
	if enfonce > 0.6:
		# (dans l'eau, dans la boue : on ne voit que ce qui dépasse ; l'eau fait un anneau autour de la jambe)
		var ligne := -0.3
		var coupe := pts[2].y > ligne
		pts = _au_dessus(pts, ligne)
		if pts.size() > 1:
			ci.draw_polyline(pts, P.ENCRE, 4.6, true)
			ci.draw_polyline(pts, JAMBE, 2.4, true)
		tige = _au_dessus(tige, ligne)
		if tige.size() > 1:
			ci.draw_polyline(tige, P.ENCRE, 4.8, true)
			ci.draw_polyline(tige, c_botte, 2.6, true)
		if coupe and pts.size() > 1 and eau > 0.04:
			var o := pts[pts.size() - 1]
			var anneau := _ellipse(Vector2(o.x, ligne + 0.3), 3.6, 1.3, 10)
			anneau.append(anneau[0])
			ci.draw_polyline(anneau, Color(P.PAPIER.lerp(P.ECHO, 0.4), 0.55 * eau), 0.8, true)
		return
	ci.draw_polyline(pts, P.ENCRE, 4.6, true)
	ci.draw_polyline(pts, JAMBE, 2.4, true)
	ci.draw_polyline(tige, P.ENCRE, 4.8, true)
	ci.draw_polyline(tige, c_botte, 2.6, true)
	var talon := pt(Vector3(pied.x - 1.0, pied.y, pied.z + 0.8), cap)
	var orteil := pt(Vector3(pied.x + 2.3, pied.y, pied.z + 0.8), cap)
	var m := (talon + orteil) * 0.5
	var d := orteil - talon
	var rx := d.length() * 0.5 + 1.6
	var ang := d.angle() if d.length() > 0.3 else 0.0
	var sole := _ellipse(m, rx, 1.65, 10, ang)
	_forme(sole, c_botte)
	ci.draw_line(tige[0] + Vector2(-1.2, 0.4), tige[0] + Vector2(1.2, 0.4), CUIR_OMBRE, 1.0, true)


# un anneau du manteau (h : sa hauteur ; a : sa largeur, de côté ; b : sa profondeur) ; genre 2 : l'ourlet, ses plis ; 3 : celui
# de la cape de pluie
func _anneau(h: float, a: float, b: float, th: float, n: int, genre: int) -> Array:
	var pts := PackedVector2Array()
	var profs := PackedFloat32Array()
	for i in n:
		var al := TAU * i / n
		var k := 1.0
		var hh := h
		var dec := Vector2.ZERO
		if genre == 2:
			k = 1.0 + 0.06 * sin(6.0 * al + plis)
			hh += 0.75 * cos(6.0 * al + plis)
			dec = cape * (0.8 + 0.35 * maxf(0.0, -cos(al)))
		elif genre == 1:
			dec = cape * 0.35
		elif genre == 3:
			# (la cape de pluie : cinq plis plus larges, une toile plus raide)
			k = 1.0 + 0.05 * sin(5.0 * al + plis * 1.3 + 1.0)
			hh += 0.6 * cos(5.0 * al + plis * 1.3 + 1.0)
			dec = cape * (0.6 + 0.3 * maxf(0.0, -cos(al)))
		var v := Vector3(b * cos(al) * k, a * sin(al) * k, hh)
		pts.append(pt(v, th) + dec)
		profs.append(prof(v, th))
	return [pts, profs]


func _extremes(pts: PackedVector2Array) -> Vector2i:
	var g := 0
	var d := 0
	for i in pts.size():
		if pts[i].x < pts[g].x:
			g = i
		if pts[i].x > pts[d].x:
			d = i
	return Vector2i(g, d)


# l'arc d'un anneau, d'un point à un autre, par le côté proche (vers nous) ou lointain
func _arc(pts: PackedVector2Array, profs: PackedFloat32Array, i0: int, i1: int, proche: bool) -> PackedVector2Array:
	var n := pts.size()
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var sa := 0.0
	var sb := 0.0
	var i := i0
	while true:
		a.append(pts[i])
		sa += profs[i]
		if i == i1:
			break
		i = (i + 1) % n
	i = i0
	while true:
		b.append(pts[i])
		sb += profs[i]
		if i == i1:
			break
		i = (i - 1 + n) % n
	var plus_proche := sa / a.size() > sb / b.size()
	return a if plus_proche == proche else b


# une courbe de a à c qui passe par b (sans a ni c)
static func _courbe(a: Vector2, b: Vector2, c: Vector2, n: int) -> PackedVector2Array:
	var q := b * 2.0 - (a + c) * 0.5
	var out := PackedVector2Array()
	for k in range(1, n):
		var t := float(k) / n
		out.append(a.lerp(q, t).lerp(q.lerp(c, t), t))
	return out


func _manteau() -> void:
	var n := 20 if mobile else 30
	var mi := lerp_angle(cap, buste, 0.5)
	var ep: Array = _anneau(27.2 + epaules, _ep.x, _ep.y, buste, n, 0)
	var ta: Array = _anneau(17.0, _ta.x, _ta.y, mi, n, 1)
	var ou: Array = _anneau(8.0, _ou.x, _ou.y, cap, n, 2)
	var e := _extremes(ep[0])
	var t := _extremes(ta[0])
	var o := _extremes(ou[0])
	var contour := PackedVector2Array()
	contour.append_array(_arc(ep[0], ep[1], e.y, e.x, false))
	contour.append_array(_courbe(ep[0][e.x], ta[0][t.x], ou[0][o.x], 6))
	var ourlet := _arc(ou[0], ou[1], o.x, o.y, true)
	contour.append_array(ourlet)
	contour.append_array(_courbe(ou[0][o.y], ta[0][t.y], ep[0][e.y], 6))
	contour = _simple(contour)
	var cx: float = (ta[0][t.x].x + ta[0][t.y].x) * 0.5
	# (la pelisse : une peau brune, à la place de l'étoffe du manteau ; la capuche reste la sienne)
	var etoffe := PELISSE if pelisse else CAPE
	var etoffe_ombre := PELISSE_OMBRE if pelisse else CAPE_OMBRE
	_remplir(contour, etoffe)
	# l'ombre, du côté loin de la lumière (elle vient d'en haut à gauche)
	_remplir(_vers_droite(contour, cx + 1.0), etoffe_ombre)
	# les plis : une ligne qui descend vers chaque creux de l'ourlet, du côté qu'on voit
	for k in 6:
		var al := (-PI * 0.5 - plis + TAU * k) / 6.0
		var vo := Vector3(_ou.y * cos(al) * 0.94, _ou.x * sin(al) * 0.94, 8.0 - 0.75)
		if prof(vo, cap) < 1.5:
			continue
		var vt := Vector3(_ta.y * cos(al), _ta.x * sin(al), 15.0)
		var bas_ := pt(vo, cap) + cape * 0.85
		var haut := pt(vt, mi) + cape * 0.35
		var mil := haut.lerp(bas_, 0.55) + Vector2(0.6 * sin(al * 3.0 + plis), 0)
		ci.draw_polyline(PackedVector2Array([haut.lerp(bas_, 0.25), mil, bas_]), etoffe_ombre.darkened(0.35), 0.9, true)
	# l'ouverture du manteau, sous la ceinture, quand elle est de face
	var devant := prof(Vector3(1, 0, 0), cap)
	if devant > 0.25:
		var a := pt(Vector3(_ta.y, 0.0, 16.0), mi) + cape * 0.35
		var b := pt(Vector3(_ou.y, 0.0, 7.6), cap) + cape * 0.8
		ci.draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0.3, 0), b]), DOUBLURE, 1.2, true)
	if not cire:
		# la ceinture, et la bourse à sa hanche droite (la cape de pluie les couvre)
		var tl := _arc(ta[0], ta[1], t.x, t.y, true)
		ci.draw_polyline(tl, P.ENCRE, 2.8, true)
		ci.draw_polyline(tl, CUIR_OMBRE, 1.4, true)
		if devant > 0.2:
			var boucle := pt(Vector3(_ta.y + 0.1, 0.0, 17.0), mi) + cape * 0.35
			ci.draw_rect(Rect2(boucle - Vector2(0.9, 0.9), Vector2(1.8, 1.8)), PIERRE.lightened(0.1))
		var vb := Vector3(_ta.y * cos(1.75), _ta.x * sin(1.75) + 0.6, 15.2)
		if prof(vb, cap) > -2.5:
			var pb := pt(vb, cap) + cape * 0.35
			var bourse := PackedVector2Array([pb + Vector2(-1.7, -1.0), pb + Vector2(1.7, -1.0), pb + Vector2(1.9, 1.6), pb + Vector2(0.0, 3.0), pb + Vector2(-1.9, 1.6)])
			_forme(bourse, CUIR)
	# le liseré de lumière, en haut et à gauche, puis l'encre
	var lisere := PackedVector2Array()
	for p in contour:
		if p.x < cx - 2.0 and p.y < ourlet[0].y - 1.0:
			lisere.append(p + Vector2(0.9, 0.2))
	if lisere.size() > 1:
		ci.draw_polyline(lisere, PELISSE_LISERE if pelisse else CAPE_LISERE, 1.0, true)
	_encre(contour)
	# la pelisse : sa fourrure dépasse à l'ourlet
	if pelisse:
		_fourrure(ourlet, 3.0, 0.9, cx)
	# l'ombre de la capuche sur les épaules
	var col := pt(Vector3(-0.5, 0.0, 28.0 + epaules), buste)
	_remplir(_ellipse(col + Vector2(0.8, 0.6), _ep.x, 2.4, 12), CAPE_OMBRE.darkened(0.3))
	if cire:
		_cape_pluie(n)
	if pelisse:
		# le col de fourrure, sur les épaules (l'écharpe se noue par-dessus)
		_fourrure(_arc(ep[0], ep[1], e.x, e.y, true), 1.4, 2.6 if cire else 3.6, cx)


# une bande de fourrure le long d'un trait (ce qu'elle dépasse au-dessus, au-dessous) : pâle, son bord en mèches
func _fourrure(arc: PackedVector2Array, haut: float, dessous: float, cx: float) -> void:
	if arc.size() < 2:
		return
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in arc.size():
		var m := 0.4 if i % 2 == 0 else -0.2
		a.append(arc[i] + Vector2(0.0, -haut - m * 0.4))
		b.append(arc[i] + Vector2(0.0, dessous + m))
	b.reverse()
	a.append_array(b)
	a = _simple(a)
	_remplir(a, FOURRURE)
	_remplir(_vers_droite(a, cx + 1.5), FOURRURE_OMBRE)
	_encre(a, 0.8)


# la cape de pluie : une cloche de toile cirée, des épaules à mi-cuisse, par-dessus le manteau
func _cape_pluie(n: int) -> void:
	var mi := lerp_angle(cap, buste, 0.6)
	var ep: Array = _anneau(27.6 + epaules, _ep.x + 0.5, _ep.y + 0.5, buste, n, 0)
	var ta: Array = _anneau(19.2, _ta.x + 1.9, _ta.y + 1.7, mi, n, 1)
	var bo: Array = _anneau(12.4, _ou.x + 0.5, _ou.y + 0.4, cap, n, 3)
	var e := _extremes(ep[0])
	var t := _extremes(ta[0])
	var o := _extremes(bo[0])
	var contour := PackedVector2Array()
	contour.append_array(_arc(ep[0], ep[1], e.y, e.x, false))
	contour.append_array(_courbe(ep[0][e.x], ta[0][t.x], bo[0][o.x], 6))
	var bord := _arc(bo[0], bo[1], o.x, o.y, true)
	contour.append_array(bord)
	contour.append_array(_courbe(bo[0][o.y], ta[0][t.y], ep[0][e.y], 6))
	contour = _simple(contour)
	var cx: float = (ta[0][t.x].x + ta[0][t.y].x) * 0.5
	# (son ombre portée sur le manteau, juste dessous)
	var portee := PackedVector2Array()
	for p in bord:
		portee.append(p + Vector2(0.0, 1.5))
	ci.draw_polyline(portee, Color(DOUBLURE, 0.7), 1.6, true)
	_remplir(contour, c_cire)
	_remplir(_vers_droite(contour, cx + 1.0), c_cire_ombre)
	# ses plis, raides : une ligne vers chaque creux du bord
	for k in 5:
		var al := (-PI * 0.5 - plis * 1.3 - 1.0 + TAU * k) / 5.0
		var vo := Vector3((_ou.y + 0.4) * cos(al) * 0.95, (_ou.x + 0.5) * sin(al) * 0.95, 12.4 - 0.6)
		if prof(vo, cap) < 1.5:
			continue
		var vt := Vector3((_ta.y + 1.7) * cos(al), (_ta.x + 1.9) * sin(al), 20.5)
		var bas_ := pt(vo, cap) + cape * 0.75
		var haut := pt(vt, mi) + cape * 0.35
		ci.draw_polyline(PackedVector2Array([haut, haut.lerp(bas_, 0.55) + Vector2(0.5 * sin(al * 3.0 + plis), 0), bas_]), CIRE_PLI, 0.8, true)
	# elle se ferme devant : une ligne, deux boutons d'os
	var devant := prof(Vector3(1, 0, 0), cap)
	if devant > 0.25:
		var a := pt(Vector3(_ep.y + 0.6, 0.0, 26.0 + epaules), buste)
		var b := pt(Vector3(_ou.y + 0.4, 0.0, 12.2), cap) + cape * 0.7
		ci.draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0.3, 0), b]), CIRE_PLI, 1.0, true)
		if not mobile:
			for u in [0.42, 0.7]:
				ci.draw_circle(a.lerp(b, u) + Vector2(1.3, 0.0), 0.75, FOURRURE)
	# la toile luit, du côté du jour : un liseré, plus vif sous la pluie
	var lisere := PackedVector2Array()
	for p in contour:
		if p.x < cx - 2.0 and p.y < bord[0].y - 1.0:
			lisere.append(p + Vector2(1.0, 0.2))
	if lisere.size() > 1:
		ci.draw_polyline(lisere, c_cire_lisere.lerp(P.PAPIER, 0.5 * pluie), 1.0 + 0.4 * pluie, true)
	_encre(contour)


# le tour de la capuche, autour de c ; celle de la cape de pluie est pointue
func _tour_capuche(c: Vector2, th: float, n: int) -> PackedVector2Array:
	var pic := _pic(th)
	var pointe := 3.0 * (0.35 + 0.65 * absf(sin(th)))
	var aigu := 6.0
	var rx := 7.7
	var ry := 7.0
	var depart := 0.0
	if cire:
		# (un capuchon pointu, qui part en arrière : un point du tour est juste à sa pointe)
		pointe = 5.2
		aigu = 22.0
		rx = 7.9
		ry = 7.2
		depart = pic.angle()
	var contour := PackedVector2Array()
	for k in n:
		var be := depart + TAU * k / n
		var dir := Vector2(cos(be), sin(be))
		var p := Vector2(cos(be) * rx, sin(be) * ry)
		if dir.y > 0.0:
			p.x *= 1.0 + 0.14 * dir.y
		var vers := maxf(0.0, dir.dot(pic))
		p += dir * pow(vers, aigu) * pointe
		if cire:
			p += dir * pow(vers, 3.0) * 1.7
		contour.append(c + p)
	return contour


# vers où pointe la capuche (à l'écran)
func _pic(th: float) -> Vector2:
	return proj(Vector3(-0.7, 0.0, 1.0) if cire else Vector3(-1.0, 0.0, 0.85), th).normalized()


func _capuche() -> void:
	var th := tete
	var c := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
	var pic := _pic(th)
	var contour := _tour_capuche(c, th, 20 if mobile else 30)
	var etoffe := c_cire if cire else CAPE
	var etoffe_ombre := c_cire_ombre if cire else CAPE_OMBRE
	var etoffe_lisere := c_cire_lisere if cire else CAPE_LISERE
	_remplir(contour, etoffe)
	_remplir(_vers_droite(contour, c.x + 1.6), etoffe_ombre)
	# l'ouverture, et le visage dans son ombre
	var vis := smoothstep(-0.45, 0.05, cos(th))
	if vis > 0.02:
		var oc := c + proj(Vector3(3.6, 0.0, -1.3), th)
		var rx := 4.9 * (0.5 + 0.5 * absf(cos(th))) * (0.35 + 0.65 * vis)
		var ry := 5.3 * (0.55 + 0.45 * vis)
		var trou := _ellipse(oc, rx, ry, 18)
		for i in trou.size():
			var q := trou[i]
			if q.y < oc.y:
				q.y -= 0.9 * pow((oc.y - q.y) / ry, 4.0)
				trou[i] = q
		if pelisse:
			# la fourrure, tout autour du visage : pâle, en mèches (sous l'écharpe, on n'en voit que le haut)
			var poil := PackedVector2Array()
			for i in 22:
				var al := TAU * i / 22.0
				var m := 0.35 if i % 2 == 0 else -0.2
				var q := Vector2(cos(al) * (rx + 2.15 + m), sin(al) * (ry + 2.0 + m))
				if q.y < 0.0:
					q.y -= 0.9 * pow(-q.y / (ry + 2.0), 4.0)
				poil.append(oc + q)
			# (sans cerne : il mangerait ce liseré ; le clair sur l'étoffe sombre suffit)
			_remplir(poil, FOURRURE)
			_remplir(_vers_droite(poil, oc.x + rx * 0.75), FOURRURE.lerp(FOURRURE_OMBRE, 0.65))
		_remplir(trou, DOUBLURE)
		var fc := oc + Vector2(sin(th) * minf(0.9, rx * 0.25), 1.0)
		var rxf := rx * 0.62
		var ryf := ry * 0.74
		var face := _ellipse(fc, rxf, ryf, 16)
		_remplir(face, c_visage)
		_remplir(_vers_droite(face, fc.x + rxf * 0.25), c_visage.darkened(0.23))
		# l'ombre du bord de la capuche, sur le front
		var visiere := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			visiere.append(oc + Vector2(cos(a) * rx * 1.02, sin(a) * ry * 1.02))
		for i in 7:
			var u := 1.0 - float(i) / 6.0
			var x := lerpf(-rx, rx, u)
			visiere.append(oc + Vector2(x, -ry * 0.18 + 0.9 * (1.0 - pow(x / rx, 2.0)) - 0.6))
		_remplir(visiere, DOUBLURE)
		# les deux points des yeux
		var ey := fc.y - ryf * 0.12
		for s in [1.0, -1.0]:
			var oeil := Vector3(3.0, s * 1.45, 0.0)
			if prof(oeil, th) < -0.8:
				continue
			var ex := fc.x + proj(oeil, th).x - proj(Vector3(3.6, 0.0, 0.0), th).x
			if yeux > 1.5:
				# (grands ouverts : on en voit le blanc — la peur d'une vision, le sursaut de qui s'endormait)
				ci.draw_rect(Rect2(ex - 1.05, ey - 1.15, 2.1, 2.3), P.PAPIER)
				ci.draw_rect(Rect2(ex - 0.5, ey - 0.55, 1.0, 1.1), P.ENCRE)
			elif yeux > 0.5:
				ci.draw_rect(Rect2(ex - 0.6, ey - 0.65, 1.2, 1.3), P.ENCRE)
			else:
				ci.draw_line(Vector2(ex - 0.8, ey), Vector2(ex + 0.8, ey), P.ENCRE, 0.7, true)
		_encre(trou, 0.5 if pelisse else 0.8)
		if not pelisse:
			# le bord de la capuche, qui prend la lumière
			var bord := PackedVector2Array()
			for i in 7:
				var a := PI * 1.08 + PI * 0.7 * i / 6.0
				bord.append(oc + Vector2(cos(a) * (rx + 0.7), sin(a) * (ry + 0.7)))
			ci.draw_polyline(bord, etoffe_lisere, 0.9, true)
	# de dos : la couture
	if cos(th) < -0.15:
		var haut := c + pic * (13.0 if cire else 9.5)
		var a := clampf(-cos(th) * 2.0, 0.0, 1.0)
		ci.draw_polyline(PackedVector2Array([haut, c + pic * 3.0, c + Vector2(0.0, 6.0)]), Color(CIRE_PLI if cire else CAPE_OMBRE.darkened(0.4), a), 0.9, true)
	# le liseré en haut à gauche, puis l'encre
	var lisere := PackedVector2Array()
	var k0 := 0
	if cire:
		# (son tour part de la pointe : on le reprend au premier point de gauche, pour que le trait ne saute pas)
		for i in contour.size():
			var d0 := (contour[i] - c).normalized()
			var d1 := (contour[(i + contour.size() - 1) % contour.size()] - c).normalized()
			if d0.x < 0.25 and d0.y < -0.15 and not (d1.x < 0.25 and d1.y < -0.15):
				k0 = i
	for i in contour.size():
		var p := contour[(k0 + i) % contour.size()]
		var d := (p - c).normalized()
		if d.x < 0.25 and d.y < -0.15:
			lisere.append(p - d * 0.9)
	if lisere.size() > 1:
		ci.draw_polyline(lisere, etoffe_lisere.lerp(P.PAPIER, 0.5 * pluie) if cire else etoffe_lisere, 1.0, true)
	_encre(contour)


# l'écharpe, nouée autour du cou : le côté qu'on voit
func _col() -> void:
	var n := 24
	var h := 29.6 + epaules
	var pts := PackedVector2Array()
	var profs := PackedFloat32Array()
	for i in n:
		var al := TAU * i / n
		var v := Vector3(4.7 * cos(al), 5.6 * sin(al), h)
		pts.append(pt(v, buste))
		profs.append(prof(v, buste))
	var e := _extremes(pts)
	var arc := _arc(pts, profs, e.x, e.y, true)
	var haut := PackedVector2Array()
	var bas_ := PackedVector2Array()
	for i in arc.size():
		var u := float(i) / maxf(1.0, arc.size() - 1.0)
		var gonfle := 0.45 * sin(u * PI * 3.0 + 0.6)
		haut.append(arc[i] + Vector2(0, -2.1 - gonfle))
		bas_.append(arc[i] + Vector2(0, 1.9 + gonfle * 0.5))
	bas_.reverse()
	var bande := PackedVector2Array()
	bande.append_array(haut)
	bande.append_array(bas_)
	bande = _simple(bande)
	var cx := (pts[e.x].x + pts[e.y].x) * 0.5
	_remplir(bande, ECHARPE)
	_remplir(_vers_droite(bande, cx + 1.2), ECHARPE_OMBRE)
	if haut.size() > 3:
		var clair := haut.slice(0, haut.size() / 2)
		for i in clair.size():
			clair[i] += Vector2(0.3, 0.8)
		ci.draw_polyline(clair, ECHARPE_LISERE, 0.9, true)
	for k in [0.3, 0.62]:
		var i := int(k * (arc.size() - 1))
		var p := arc[i]
		ci.draw_line(p + Vector2(-0.8, -1.1), p + Vector2(0.9, 1.0), ECHARPE_OMBRE.darkened(0.2), 0.8, true)
	_encre(bande, 0.9)


# les deux pans noués devant, qui pendent sur la poitrine
func _pans() -> void:
	var nd := Vector3(3.8, -1.2, 28.3 + epaules)
	if prof(nd, buste) < -0.6:
		return
	var k := pt(nd, buste)
	for i in 2:
		var l := 6.8 if i == 0 else 4.8
		var x0 := -0.7 + i * 1.6
		var bout := k + Vector2(x0 + pan * (1.0 + i * 0.5) + cape.x * 0.25, l)
		var pts := PackedVector2Array([k + Vector2(x0 - 1.6, 0), k + Vector2(x0 + 1.6, 0), bout + Vector2(1.4, 0), bout + Vector2(-0.1, 1.0), bout + Vector2(-1.5, 0)])
		_forme(pts, ECHARPE if i == 0 else ECHARPE_OMBRE, 0.8)
	_forme(_ellipse(k + Vector2(0, -0.3), 1.9, 1.5, 8), ECHARPE_LISERE, 0.8)


# la queue de l'écharpe, qui flotte (ses points viennent du joueur)
func _queue() -> void:
	var n := echarpe.size()
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	for i in n:
		var a := echarpe[maxi(0, i - 1)]
		var b := echarpe[mini(n - 1, i + 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var l := lerpf(1.6, 1.0, float(i) / (n - 1))
		gauche.append(echarpe[i] + nrm * l)
		droite.append(echarpe[i] - nrm * l)
	for i in n - 1:
		var t0 := echarpe[i + 1] - echarpe[i]
		var t1 := echarpe[mini(n - 1, i + 2)] - echarpe[i + 1]
		var envers := t0.cross(t1) < -0.4
		var c := ECHARPE_OMBRE if envers else ECHARPE
		ci.draw_primitive(PackedVector2Array([gauche[i], gauche[i + 1], droite[i + 1], droite[i]]), PackedColorArray([c, c, c, c]), PackedVector2Array())
	var tour := PackedVector2Array()
	tour.append_array(gauche)
	var d2 := droite.duplicate()
	d2.reverse()
	tour.append_array(d2)
	tour.append(gauche[0])
	ci.draw_polyline(tour, P.ENCRE, 0.9, true)
	# la frange
	var fin := echarpe[n - 1]
	var dir := (echarpe[n - 1] - echarpe[n - 2]).normalized()
	for k in 3:
		var o := Vector2(-dir.y, dir.x) * (k - 1) * 0.8
		ci.draw_line(fin + o, fin + o + dir * 1.8, ECHARPE_OMBRE, 0.7, true)


func _sac() -> void:
	var th := buste
	var f0 := -9.8
	var f1 := -4.4
	var s := 4.6
	var h0 := 16.2
	var h1 := 26.4
	var coins := PackedVector2Array()
	for v in [Vector3(f0, -s, h0), Vector3(f0, s, h0), Vector3(f0, s, h1), Vector3(f0, -s, h1), Vector3(f1, -s, h0), Vector3(f1, s, h0), Vector3(f1, s, h1), Vector3(f1, -s, h1)]:
		coins.append(pt(v, th))
	var dos := -cos(th)
	var droite := sin(th)
	# une poche de cuir aux coins ronds, vue de là où l'on est ; le dessus plus clair
	var poche := _arrondi(_enveloppe(coins), 2)
	var cx := (coins[0].x + coins[1].x + coins[4].x + coins[5].x) * 0.25
	_remplir(poche, CUIR)
	_remplir(_vers_droite(poche, cx + 1.4), CUIR_OMBRE)
	_remplir(_arrondi(PackedVector2Array([coins[3], coins[2], coins[6], coins[7]]), 1), CUIR_CLAIR)
	if dos > 0.15:
		# le rabat, et sa boucle
		var milieu := (coins[0].lerp(coins[3], 0.55) + coins[1].lerp(coins[2], 0.55)) * 0.5
		var rabat := _arrondi(PackedVector2Array([coins[3], coins[2], coins[2].lerp(coins[1], 0.4), milieu + Vector2(0, 1.8), coins[3].lerp(coins[0], 0.4)]), 1)
		_forme(rabat, CUIR_OMBRE, 0.8)
		ci.draw_rect(Rect2(milieu + Vector2(-0.8, 0.6), Vector2(1.6, 1.6)), PIERRE.lightened(0.15))
	_encre(poche)
	# le rouleau de couverture, dessus
	var r1 := pt(Vector3(-7.2, -6.2, 28.8), th)
	var r2 := pt(Vector3(-7.2, 6.2, 28.8), th)
	ci.draw_line(r1, r2, P.ENCRE, 5.2, true)
	ci.draw_line(r1, r2, ROULEAU, 3.0, true)
	for u in [0.3, 0.7]:
		var p := r1.lerp(r2, u)
		ci.draw_line(p + Vector2(0, -2.0), p + Vector2(0, 2.0), CUIR_OMBRE, 1.1, true)
	var bout := r1 if droite < 0.0 else r2
	if absf(droite) > 0.25:
		_forme(_ellipse(bout, 1.2 * absf(droite) + 0.4, 2.2, 10), ROULEAU.darkened(0.15))
		ci.draw_arc(bout, 0.8, 0.0, TAU * 0.8, 8, CUIR_OMBRE, 0.6, true)
	# de face : les bretelles sur les épaules
	if dos < -0.25:
		for c in [1.0, -1.0]:
			var a := pt(Vector3(3.0, c * 4.4, 26.8 + epaules), th)
			var b := pt(Vector3(4.6, c * 4.1, 21.5), th)
			ci.draw_line(a, b, CUIR_OMBRE, 1.1, true)


# le sac à dos : de peau, plus haut et plus large que le petit sac, son rabat sanglé, ses poches, un rouleau en travers dessus ;
# il est en retard d'un rien sur le corps quand elle marche (ballant), un gobelet de ferraille y pend
func _sac_a_dos() -> void:
	var th := buste
	var f0 := -11.6
	var f1 := -4.6
	var s := 5.7
	var h0 := 14.0
	var h1 := 26.2
	var coins := PackedVector2Array()
	for v in [Vector3(f0, -s, h0), Vector3(f0, s, h0), Vector3(f0, s, h1), Vector3(f0, -s, h1), Vector3(f1, -s, h0), Vector3(f1, s, h0), Vector3(f1, s, h1), Vector3(f1, -s, h1)]:
		coins.append(pt(v, th) + ballant)
	var dos := -cos(th)
	var droite := sin(th)
	# la poche de peau, aux coins ronds ; le dessus plus clair
	var poche := _arrondi(_enveloppe(coins), 2)
	var cx := (coins[0].x + coins[1].x + coins[4].x + coins[5].x) * 0.25
	_remplir(poche, PEAU)
	_remplir(_vers_droite(poche, cx + 1.6), PEAU_OMBRE)
	_remplir(_arrondi(PackedVector2Array([coins[3], coins[2], coins[6], coins[7]]), 1), PEAU_CLAIR)
	if absf(droite) > 0.3:
		# de profil : la poche de côté, et la bretelle qui passe l'épaule
		var c := 1.0 if droite > 0.0 else -1.0
		var q := PackedVector2Array()
		for v in [Vector3(f0 + 1.6, c * s, h0 + 0.6), Vector3(f1 - 1.0, c * s, h0 + 0.6), Vector3(f1 - 1.0, c * s, h0 + 6.4), Vector3(f0 + 1.6, c * s, h0 + 6.4)]:
			q.append(pt(v + Vector3(0.0, c * 1.3, 0.0), th) + ballant)
		_forme(_arrondi(q, 2), PEAU_OMBRE.lerp(PEAU, 0.5), 0.8)
		ci.draw_line(q[3].lerp(q[2], 0.1) + Vector2(0.0, 1.6), q[2].lerp(q[3], 0.1) + Vector2(0.0, 1.6), P.ENCRE, 0.7, true)
		var e0 := pt(Vector3(f1, c * (s - 0.6), h1 - 0.6), th) + ballant
		var e1 := pt(Vector3(0.6, c * (_epaule - 0.4), 28.2 + epaules), th)
		var e2 := pt(Vector3(_ep.y, c * (_epaule - 0.6), 24.4), th)
		ci.draw_polyline(PackedVector2Array([e0, e1, e2]), P.ENCRE, 2.6, true)
		ci.draw_polyline(PackedVector2Array([e0, e1, e2]), PEAU, 1.3, true)
	if dos > 0.15:
		# de dos : le rabat, plus sombre, son bord en accolade ; deux sangles et leurs boucles
		var g := coins[3]
		var d := coins[2]
		var gb := coins[0]
		var db := coins[1]
		var rabat := PackedVector2Array([g, d, d.lerp(db, 0.44), d.lerp(db, 0.52).lerp(g.lerp(gb, 0.52), 0.25) + Vector2(0, 0.9), d.lerp(db, 0.5).lerp(g.lerp(gb, 0.5), 0.5) + Vector2(0, 0.2),
			d.lerp(db, 0.52).lerp(g.lerp(gb, 0.52), 0.75) + Vector2(0, 0.9), g.lerp(gb, 0.44)])
		_forme(_arrondi(rabat, 1), CUIR, 0.8)
		for u in [0.27, 0.73]:
			var haut := g.lerp(d, u)
			var bas_ := gb.lerp(db, u)
			ci.draw_line(haut.lerp(bas_, 0.06), haut.lerp(bas_, 0.86), CUIR_OMBRE, 1.5, true)
			ci.draw_rect(Rect2(haut.lerp(bas_, 0.56) - Vector2(0.8, 0.7), Vector2(1.6, 1.4)), PIERRE)
	_encre(poche)
	# le gobelet de ferraille, pendu au côté qu'on voit : il balance
	if not mobile and absf(droite) > 0.2:
		var c := 1.0 if droite > 0.0 else -1.0
		var clou := pt(Vector3(f0 + 2.4, c * (s + 0.4), h0 + 3.0), th) + ballant
		var pend := clou + Vector2(sin(godet), cos(godet)) * 2.6
		ci.draw_line(clou, pend, P.ENCRE, 0.7, true)
		_forme(PackedVector2Array([pend + Vector2(-1.4, -0.7), pend + Vector2(1.4, -0.7), pend + Vector2(1.0, 1.9), pend + Vector2(-1.0, 1.9)]), FERRAILLE.darkened(0.25), 0.8)
		ci.draw_line(pend + Vector2(-0.6, -0.1), pend + Vector2(-0.5, 1.1), FERRAILLE.lightened(0.25), 0.6, true)
	# le rouleau, en travers sur le sac : gros, sanglé deux fois, ses bouts dépassent des épaules
	var r1 := pt(Vector3(-7.9, -9.0, 28.3), th) + ballant
	var r2 := pt(Vector3(-7.9, 9.0, 28.3), th) + ballant
	ci.draw_line(r1, r2, P.ENCRE, 6.2, true)
	ci.draw_line(r1, r2, ROULEAU, 4.0, true)
	ci.draw_line(r1 + Vector2(0.0, -1.2), r2 + Vector2(0.0, -1.2), ROULEAU.lightened(0.2), 0.9, true)
	for u in [0.3, 0.7]:
		var p := r1.lerp(r2, u)
		ci.draw_line(p + Vector2(0, -2.6), p + Vector2(0, 2.6), CUIR_OMBRE, 1.3, true)
	for bout in [r1, r2]:
		var vers: float = signf(bout.x - (r1.x + r2.x) * 0.5)
		if absf(r1.x - r2.x) < 3.0:
			vers = 1.0 if droite >= 0.0 else -1.0
			if (bout == r1) == (droite >= 0.0):
				continue
		# (de profil on voit son bout, enroulé ; de face et de dos, sa tranche)
		_forme(_ellipse(bout, 0.7 + 1.5 * absf(droite), 2.7, 10), ROULEAU.darkened(0.12), 0.9)
		if absf(droite) > 0.35:
			ci.draw_arc(bout, 1.3, 0.0, TAU * 0.8, 8, CUIR_OMBRE, 0.6, true)


# les bretelles du sac à dos, devant : claires sur le manteau, de l'épaule à la taille, une boucle
func _bretelles() -> void:
	var droite := sin(buste)
	for c in [1.0, -1.0]:
		if prof(Vector3(1.0, c * 0.9, 0.0), buste) < 0.1:
			continue
		var a := pt(Vector3(1.6, c * (_epaule - 1.9), 27.6 + epaules), buste)
		var m := pt(Vector3(_ep.y + 0.5, c * (_epaule - 2.2), 24.0), buste)
		var b := pt(Vector3(_ta.y + 0.2, c * (_epaule - 1.6), 18.6), buste)
		var bretelle := PackedVector2Array([a, m, b])
		ci.draw_polyline(bretelle, P.ENCRE, 3.0, true)
		ci.draw_polyline(bretelle, PEAU_CLAIR if c * droite >= -0.1 else PEAU, 1.6, true)
		ci.draw_rect(Rect2(m.lerp(b, 0.5) - Vector2(0.9, 0.8), Vector2(1.8, 1.6)), P.ENCRE)
		ci.draw_rect(Rect2(m.lerp(b, 0.5) - Vector2(0.5, 0.4), Vector2(1.0, 0.8)), PIERRE.lightened(0.1))


# un bras (cote : 1 le droit, -1 le gauche), de l'épaule à la main
func _bras(cote: float) -> void:
	var main := main_d if cote > 0.0 else main_g
	var epaule := Vector3(0.2, cote * _epaule, 25.8 + epaules)
	var d := main - epaule
	var l := d.length()
	var demi := 7.0
	if l > demi * 2.0 - 0.05:
		main = epaule + d / l * (demi * 2.0 - 0.05)
		d = main - epaule
		l = d.length()
	var pli := Vector3(-0.5, cote * 1.0, -0.4)
	pli = (pli - d * (pli.dot(d) / maxf(0.001, l * l))).normalized()
	var coude := epaule + d * 0.5 + pli * sqrt(maxf(0.0, demi * demi - l * l * 0.25))
	var pts := PackedVector2Array([pt(epaule, buste), pt(coude, buste), pt(main, buste)])
	var loin := prof(Vector3(0, cote, 0), buste) < -0.3
	# (la manche s'arrête au poignet : la main en sort)
	# (deux segments et un coude rond : un trait épais plié fait une pointe)
	var poignet := pts[1].lerp(pts[2], 0.82)
	var tissu := CAPE_OMBRE if loin else CAPE.lightened(0.1)
	if cire:
		tissu = c_cire_ombre if loin else c_cire.lightened(0.06)
	elif pelisse:
		tissu = PELISSE_OMBRE if loin else PELISSE.lightened(0.08)
	var gros := _manche
	ci.draw_line(pts[0], pts[1], P.ENCRE, 4.8 + gros, true)
	ci.draw_line(pts[1], poignet, P.ENCRE, 4.6 + gros, true)
	ci.draw_circle(pts[1], 2.35 + gros * 0.5, P.ENCRE)
	ci.draw_line(pts[0], pts[1], tissu, 3.0 + gros, true)
	ci.draw_line(pts[1], poignet, tissu, 2.8 + gros, true)
	ci.draw_circle(pts[1], 1.45 + gros * 0.5, tissu)
	var a := pts[1].lerp(pts[2], 0.55)
	var b := pts[1].lerp(pts[2], 0.8)
	if pelisse:
		# le poignet de fourrure : un bourrelet pâle
		var p0 := pts[1].lerp(pts[2], 0.62)
		var p1 := pts[1].lerp(pts[2], 0.9)
		ci.draw_line(p0, p1, P.ENCRE, 5.4, true)
		ci.draw_line(p0, p1, FOURRURE_OMBRE if loin else FOURRURE, 3.8, true)
	elif cire:
		# (la manche du manteau dépasse de la toile)
		ci.draw_line(a, b, CAPE_OMBRE if loin else CAPE.lightened(0.1), 3.0, true)
	else:
		# le brassard de cuir
		ci.draw_line(a, b, CUIR_OMBRE if loin else CUIR, 3.0, true)
	# ce qu'elle tient
	if lance and cote == lance_main and lance_pose <= 0.5:
		_lance(main)
	if cote < 0.0 and torche:
		_torche(main)
	if cote < 0.0 and lampe:
		_lampe(main)
	if outil != "" and cote == outil_main:
		_outil(main)
	if fronde == 2 and cote < 0.0:
		_fronde(main)
	_forme(_ellipse(pts[2], 1.6, 1.5, 8), c_main.darkened(0.3) if loin else c_main, 0.9)
	if cote > 0.0 and objet != "":
		_objet(pts[2])


# un boyau, d'une branche de la fourche à la poche (a, b : dans le corps) : tendu, il s'amincit ; lâche, il pend
func _boyau(a: Vector3, b: Vector3) -> void:
	var d := a.distance_to(b)
	var pa := pt(a, buste)
	var pb := pt(b, buste)
	var ligne := PackedVector2Array([pa, pb])
	if d < BOYAU_REPOS - 0.2:
		var creux := Vector2(0.0, sqrt(BOYAU_REPOS * BOYAU_REPOS - d * d) * 0.5)
		ligne = PackedVector2Array([pa, pa.lerp(pb, 0.3) + creux * 0.8, pa.lerp(pb, 0.65) + creux, pb])
	var w := clampf(1.1 - 0.04 * d, 0.55, 0.9)
	ci.draw_polyline(ligne, P.ENCRE, w + 0.8, true)
	ci.draw_polyline(ligne, BOYAU, w, true)


# le lance-pierre dans son poing gauche : le manche, les deux branches, une ligature claire à chaque bout ; les deux boyaux
# jusqu'à la poche de cuir, et le galet dedans
func _fronde(main: Vector3) -> void:
	var u := fronde_u
	var a := fronde_a
	var cul := pt(main - u * 3.2, buste)
	var noeud := pt(main + u * 2.2, buste)
	var b1 := main + u * 6.6 + a * 3.1
	var b2 := main + u * 6.6 - a * 3.1
	var p1 := pt(b1, buste)
	var p2 := pt(b2, buste)
	# (le boyau de la branche loin de nous d'abord : la fourche passe dessus)
	var loin := prof(a, buste) > 0.0
	_boyau(b2 if loin else b1, poche)
	var branches := PackedVector2Array([p1, noeud.lerp(p1, 0.4) + (noeud - cul) * 0.14, noeud, noeud.lerp(p2, 0.4) + (noeud - cul) * 0.14, p2])
	ci.draw_line(cul, noeud, P.ENCRE, 3.8, true)
	ci.draw_polyline(branches, P.ENCRE, 3.4, true)
	ci.draw_line(cul, noeud, FOURCHE.darkened(0.15), 2.2, true)
	ci.draw_polyline(branches, FOURCHE, 1.9, true)
	ci.draw_line(noeud.lerp(p1, 0.25), p1, FOURCHE.lightened(0.22), 0.7, true)
	_boyau(b1 if loin else b2, poche)
	for q in [p1, p2]:
		ci.draw_circle(q, 0.9, BOYAU.lightened(0.15))
	var po := pt(poche, buste)
	_forme(_ellipse(po, 2.0, 1.6, 8), CUIR_CLAIR, 0.7)
	if fronde_galet:
		ci.draw_circle(po, 0.95, PIERRE.lightened(0.35))


# pendu à sa ceinture, sur la hanche gauche : la poche passée sous la ceinture, les boyaux, la fourche en bas, son manche vers
# le sol ; il balance d'avant en arrière avec son pas, et suit l'évasement du manteau
func _fronde_ceinture() -> void:
	var large := _ta.x / 7.5
	var haut := Vector3(0.4, -(7.8 * large + 0.5), 16.4)
	var s := sin(fronde_bal)
	var c := cos(fronde_bal)
	var pts := PackedVector2Array()
	# (le long du pendule, puis en travers : la poche, les deux bouts des branches, la fourche, le bout du manche)
	for q in [Vector2(0.0, 0.0), Vector2(2.4, -2.9), Vector2(2.4, 2.9), Vector2(6.6, 0.0), Vector2(11.2, 0.0)]:
		pts.append(pt(haut + Vector3(s * q.x + c * q.y, -0.2 * q.x, -c * q.x + s * q.y), buste))
	for i in [1, 2]:
		ci.draw_line(pts[0], pts[i], P.ENCRE, 1.7, true)
		ci.draw_line(pts[0], pts[i], BOYAU, 0.8, true)
	var branches := PackedVector2Array([pts[1], pts[3].lerp(pts[1], 0.4) + (pts[3] - pts[4]) * 0.1, pts[3], pts[3].lerp(pts[2], 0.4) + (pts[3] - pts[4]) * 0.1, pts[2]])
	ci.draw_line(pts[4], pts[3], P.ENCRE, 3.6, true)
	ci.draw_polyline(branches, P.ENCRE, 3.2, true)
	ci.draw_line(pts[4], pts[3], FOURCHE.darkened(0.15), 2.0, true)
	ci.draw_polyline(branches, FOURCHE, 1.7, true)
	ci.draw_line(pts[3].lerp(pts[1], 0.25), pts[1], FOURCHE.lightened(0.22), 0.7, true)
	_forme(_ellipse(pts[0], 1.6, 1.25, 8), CUIR_CLAIR, 0.8)


# la lampe : un tube de ferraille rouillée, une tête plus large, son verre clair ; une dragonne de corde au poignet
func _lampe(main: Vector3) -> void:
	var d := lampe_dir
	var cul := pt(main - d * 2.4, buste)
	var col := pt(main + d * 3.2, buste)
	var tete_ := pt(main + d * 4.6, buste)
	ci.draw_line(cul, tete_, P.ENCRE, 3.5, true)
	ci.draw_line(cul, col, FERRAILLE.darkened(0.2), 2.0, true)
	ci.draw_line(cul.lerp(col, 0.2), cul.lerp(col, 0.45), ROUILLE, 2.0, true)
	ci.draw_line(col, tete_, P.ENCRE, 4.6, true)
	ci.draw_line(col, tete_, FERRAILLE, 3.0, true)
	# (le verre : on le voit quand elle ne nous tourne pas le dos)
	var face := prof(d, buste)
	if face > -0.5:
		var verre := pt(main + d * 5.4, buste)
		var large := 0.45 + 0.55 * clampf(face, 0.0, 1.0)
		_forme(_ellipse(verre, 1.75 * large + 0.35, 1.75, 10), P.BRAISE_COEUR.lerp(P.PAPIER, 0.5), 0.8)
	var dragonne := pt(main - d * 2.4 + Vector3(0.0, 0.0, -2.6), buste)
	ci.draw_polyline(PackedVector2Array([cul, dragonne, pt(main + Vector3(-0.6, 0.0, -1.2), buste)]), ROULEAU.lightened(0.15), 0.7, true)


func _lance(main: Vector3) -> void:
	var dir := lance_dir.normalized()
	var pointe := pt(main + dir * 25.0, buste)
	var talon := pt(main - dir * 11.0, buste)
	if lance_pose > 0.0:
		# (elle la pose : de sa main vers le sol)
		talon = talon.lerp(lance_sol[0], lance_pose)
		pointe = pointe.lerp(lance_sol[1], lance_pose)
	_fut(talon, pointe)


# la lance posée au sol, près d'elle (elle a besoin de ses deux mains ; elle dort)
func _lance_posee() -> void:
	var main := main_d if lance_main > 0.0 else main_g
	var dir := lance_dir.normalized()
	var talon := (chute * pt(main - dir * 11.0, buste)).lerp(lance_sol[0], lance_pose)
	var pointe := (chute * pt(main + dir * 25.0, buste)).lerp(lance_sol[1], lance_pose)
	ci.draw_line(talon + Vector2(0.0, 1.2), pointe + Vector2(0.0, 1.2), Color(0, 0, 0, 0.25), 2.4, true)
	_fut(talon, pointe)


func _fut(talon: Vector2, pointe: Vector2) -> void:
	ci.draw_line(talon, pointe, P.ENCRE, 3.1, true)
	ci.draw_line(talon, pointe, BOIS, 1.5, true)
	var u := (pointe - talon).normalized()
	var nrm := Vector2(-u.y, u.x)
	var k := clampf((pointe - talon).length() / 36.0, 0.5, 1.0)
	var fer := PackedVector2Array([pointe + u * 6.5 * k, pointe + u * 2.0 * k + nrm * 1.8, pointe - u * 0.6, pointe + u * 2.0 * k - nrm * 1.8])
	_forme(fer, PIERRE)
	ci.draw_line(pointe - u * 0.6 + nrm * 1.0, pointe - u * 0.6 - nrm * 1.0, ROULEAU, 1.2, true)
	ci.draw_line(pointe - u * 2.0 + nrm * 1.0, pointe - u * 2.0 - nrm * 1.0, ROULEAU, 1.2, true)


# l'outil d'un geste d'atelier, dans sa main : il pointe vers outil_dir
func _outil(main: Vector3) -> void:
	var d := outil_dir.normalized()
	var p := pt(main, buste)
	match outil:
		"maillet":
			# un manche de bois, un galet lié en travers
			var bout := pt(main + d * 6.5, buste)
			var cul := pt(main - d * 1.8, buste)
			ci.draw_line(cul, bout, P.ENCRE, 2.8, true)
			ci.draw_line(cul, bout, BOIS, 1.4, true)
			var u := (bout - cul).normalized()
			if u == Vector2.ZERO:
				u = Vector2.UP
			var n := Vector2(-u.y, u.x)
			var galet := PackedVector2Array([bout - u * 1.7 + n * 3.0, bout + u * 1.7 + n * 2.6, bout + u * 1.9 - n * 2.6, bout - u * 1.5 - n * 3.0])
			_forme(_arrondi(galet, 1), PIERRE)
			ci.draw_line(bout - u * 1.2 + n * 2.0, bout + u * 0.9 + n * 1.8, PIERRE.lightened(0.25), 0.8, true)
			ci.draw_line(bout + n * 1.5, bout - n * 1.5, ROULEAU.darkened(0.25), 1.0, true)
		"scie":
			# une lame d'os, ses dents de silex vers le bas ; une poignée de bois
			var bout := pt(main + d * 9.5, buste)
			var cul := pt(main - d * 1.8, buste)
			var u := (bout - p).normalized()
			if u == Vector2.ZERO:
				u = Vector2.RIGHT
			var n := Vector2(-u.y, u.x)
			if n.y < 0.0:
				n = -n
			_forme(PackedVector2Array([p + u * 0.8 - n * 1.0, bout - n * 0.5, bout + n * 0.7, p + u * 0.8 + n * 1.4]), IVOIRE_OS, 0.8)
			for k in 4:
				var q := p.lerp(bout, 0.26 + 0.19 * k) + n * 1.2
				ci.draw_line(q, q + n * 0.9 - u * 0.5, P.ENCRE, 0.7, true)
			ci.draw_line(cul, p + u * 1.2, P.ENCRE, 3.0, true)
			ci.draw_line(cul, p + u * 1.2, BOIS, 1.6, true)
		"aiguille":
			var bout := pt(main + d * 3.4, buste)
			ci.draw_line(p, bout, P.ENCRE, 1.7, true)
			ci.draw_line(p, bout, IVOIRE_OS.lightened(0.2), 0.8, true)
		"gourde":
			# une outre de peau : sa panse au bout, son col vers la bouche, un lien
			var panse := pt(main + d * 2.9, buste)
			var col := pt(main - d * 1.5, buste)
			var u := (panse - col).normalized()
			if u == Vector2.ZERO:
				u = Vector2.UP
			ci.draw_line(col, panse, P.ENCRE, 2.6, true)
			ci.draw_line(col, panse, PEAU_OMBRE, 1.3, true)
			_forme(_ellipse(panse + u * 0.4, 3.0, 2.3, 10, u.angle()), PEAU)
			ci.draw_line(panse - u * 1.0 + Vector2(-0.8, -0.9), panse + u * 1.2 + Vector2(-0.8, -0.9), PEAU_CLAIR, 0.8, true)
			ci.draw_line(col - u * 0.3, col + u * 0.6, IVOIRE_OS, 1.3, true)
		"cuiller":
			# une longue cuiller de bois, tenue par le haut
			var cul := pt(main - d * 1.2, buste)
			var bout := pt(main + d * 8.4, buste)
			ci.draw_line(cul, bout, P.ENCRE, 2.4, true)
			ci.draw_line(cul, bout, BOIS.lightened(0.1), 1.1, true)
			var u := (bout - cul).normalized()
			_forme(_ellipse(bout + u * 0.9, 1.9, 1.4, 8, u.angle()), BOIS.lightened(0.1), 0.8)
		"trouvaille":
			# un morceau de ferraille, levé pour le regarder : il accroche le jour
			var c := p + Vector2(0.0, -2.4)
			_forme(PackedVector2Array([c + Vector2(-2.0, -0.4), c + Vector2(-0.4, -2.0), c + Vector2(2.1, -1.1), c + Vector2(1.5, 1.4), c + Vector2(-1.2, 1.6)]), FERRAILLE)
			ci.draw_line(c + Vector2(-0.9, -0.6), c + Vector2(0.9, -1.0), FERRAILLE.lightened(0.5), 0.8, true)
			ci.draw_line(c + Vector2(0.2, 0.9), c + Vector2(1.0, 0.2), ROUILLE, 0.8, true)
			var vif := 0.5 + 0.5 * sin(horloge * 19.0)
			for k in 4:
				var r := Vector2.from_angle(k * PI * 0.5 + 0.4)
				ci.draw_line(c + Vector2(0.6, -1.4) + r * 1.4, c + Vector2(0.6, -1.4) + r * (2.6 + vif), Color(P.PAPIER, 0.75), 0.7, true)
		"houe":
			# un long manche, une lame de pierre liée en travers, qui revient vers elle
			var bout := pt(main + d * 12.0, buste)
			var cul := pt(main - d * 2.2, buste)
			ci.draw_line(cul, bout, P.ENCRE, 2.8, true)
			ci.draw_line(cul, bout, BOIS, 1.4, true)
			var u := (bout - cul).normalized()
			if u == Vector2.ZERO:
				u = Vector2.DOWN
			var n := Vector2(-u.y, u.x) * (1.0 if sin(buste) >= 0.0 else -1.0)
			var lame := PackedVector2Array([bout - u * 1.3 - n * 0.6, bout + u * 1.3 - n * 0.4, bout + u * 0.3 + n * 4.6, bout - u * 1.6 + n * 4.2])
			_forme(lame, PIERRE)
			ci.draw_line(bout - u * 0.6 + n * 0.8, bout - u * 1.0 + n * 3.6, PIERRE.lightened(0.25), 0.8, true)
			ci.draw_line(bout - u * 1.5, bout + u * 1.5, ROULEAU.darkened(0.25), 1.1, true)
		"sachet":
			# le sachet de graines, ouvert, tenu par le col
			var c := p + Vector2(0.0, 1.9)
			_forme(PackedVector2Array([c + Vector2(-1.5, -2.0), c + Vector2(1.5, -2.0), c + Vector2(2.4, 0.6), c + Vector2(1.4, 2.4), c + Vector2(-1.4, 2.4), c + Vector2(-2.4, 0.6)]), PEAU, 0.9)
			ci.draw_line(c + Vector2(-1.5, -1.3), c + Vector2(1.5, -1.3), CHANVRE, 0.8, true)
			ci.draw_line(c + Vector2(-0.9, -2.1), c + Vector2(0.9, -2.1), IVOIRE_OS.lightened(0.15), 0.9, true)
		"outre":
			# l'outre de peau, son bec de bois : la panse sous la main, le bec vers où elle verse
			var panse := pt(main - d * 1.6, buste)
			var bec := pt(main + d * 6.6, buste)
			var u := (bec - panse).normalized()
			if u == Vector2.ZERO:
				u = Vector2.RIGHT
			var n := Vector2(-u.y, u.x)
			_forme(_ellipse(panse, 4.3, 3.1, 12, u.angle()), PEAU)
			ci.draw_line(panse - u * 2.4 - n * 1.4, panse + u * 1.6 - n * 1.4, PEAU_CLAIR, 0.9, true)
			ci.draw_line(panse + u * 3.6, bec, P.ENCRE, 2.6, true)
			ci.draw_line(panse + u * 3.6, bec, BOIS.lightened(0.08), 1.3, true)
			ci.draw_line(panse + u * 3.5 + n * 1.5, panse + u * 3.5 - n * 1.5, CHANVRE, 1.0, true)
		"licol":
			# le licol : une boucle de corde et son bout, qui pendent de sa main
			var boucle := PackedVector2Array([p, p + Vector2(1.9, 2.4), p + Vector2(0.8, 5.6), p + Vector2(-1.5, 4.6), p + Vector2(-1.3, 1.8), p])
			ci.draw_polyline(boucle, P.ENCRE, 1.8, true)
			ci.draw_polyline(boucle, CHANVRE, 0.85, true)
			ci.draw_line(p + Vector2(0.3, 0.6), p + Vector2(0.9, 7.4), P.ENCRE, 1.6, true)
			ci.draw_line(p + Vector2(0.3, 0.6), p + Vector2(0.9, 7.4), CHANVRE, 0.75, true)
		"selle":
			# la charge, entre ses deux mains : la selle sur son tapis plié
			var q := (pt(main_d, buste) + pt(main_g, buste)) * 0.5 + Vector2(0.0, 1.2)
			_forme(PackedVector2Array([q + Vector2(-4.6, 1.8), q + Vector2(-4.2, -0.6), q + Vector2(4.2, -0.6), q + Vector2(4.6, 1.8), q + Vector2(0.0, 2.6)]), ROULEAU, 0.9)
			ci.draw_line(q + Vector2(-4.2, 1.5), q + Vector2(4.2, 1.5), ECHARPE, 0.8, true)
			_forme(PackedVector2Array([q + Vector2(-4.0, -0.8), q + Vector2(-3.4, -3.4), q + Vector2(-0.8, -2.4), q + Vector2(2.0, -2.6), q + Vector2(3.6, -3.6), q + Vector2(4.2, -0.8)]), PEAU, 0.9)
			ci.draw_line(q + Vector2(-2.8, -2.6), q + Vector2(2.6, -2.0), PEAU_CLAIR, 0.8, true)
		"bol":
			# le bol de bois, plein de lait
			_forme(PackedVector2Array([p + Vector2(-2.9, -0.9), p + Vector2(2.9, -0.9), p + Vector2(1.9, 1.9), p + Vector2(-1.9, 1.9)]), BOIS, 0.9)
			ci.draw_line(p + Vector2(-2.1, -0.7), p + Vector2(2.1, -0.7), P.PAPIER, 1.1, true)
		"feuille":
			# un brin d'herbe entre ses doigts : sa tige, deux feuilles, une fleur pâle au bout
			var bout := pt(main + d * 4.4, buste)
			var u := (bout - p).normalized() if bout.distance_to(p) > 0.1 else Vector2.UP
			var n := Vector2(-u.y, u.x)
			ci.draw_line(p - u * 0.8, bout, P.ENCRE, 1.6, true)
			ci.draw_line(p - u * 0.8, bout, HERBE, 0.8, true)
			_forme(PackedVector2Array([p + u * 1.0, p + u * 2.2 + n * 2.0, p + u * 3.3 + n * 0.5]), HERBE, 0.6)
			_forme(PackedVector2Array([p + u * 1.8, p + u * 2.8 - n * 1.9, p + u * 3.9 - n * 0.4]), HERBE.darkened(0.15), 0.6)
			ci.draw_circle(bout, 1.15, P.ENCRE)
			ci.draw_circle(bout, 0.75, P.PAPIER.lerp(P.PEUR, 0.3))
		"pilon":
			# le pilon : un galet long, tenu par le haut, sa tête lourde en bas
			var bout := pt(main + d * 6.0, buste)
			var cul := pt(main - d * 1.4, buste)
			var u := (bout - cul).normalized() if bout.distance_to(cul) > 0.1 else Vector2.DOWN
			ci.draw_line(cul, bout, P.ENCRE, 3.4, true)
			ci.draw_line(cul, bout, PIERRE, 2.0, true)
			_forme(_ellipse(bout - u * 0.6, 2.0, 1.7, 8, u.angle()), PIERRE.darkened(0.08), 0.8)
			ci.draw_line(cul + u * 1.0 + Vector2(-0.6, 0.0), bout - u * 2.2 + Vector2(-0.6, 0.0), PIERRE.lightened(0.28), 0.7, true)
		"botte":
			# la botte d'herbe âcre, tenue par le milieu
			_botte(pt(main - d * 3.8, buste), pt(main + d * 4.6, buste))


# l'ouvrage, posé devant elle (il ne suit pas son corps) ; ce qui en saute quand elle frappe, le fil qui le lie à sa main
func _ouvrage() -> void:
	var o := ouvrage_ou
	var main := chute.affine_inverse() * (main_d_ecran if outil_main > 0.0 else main_g_ecran)
	var grain := BOIS.lightened(0.3)
	match ouvrage:
		"piece":
			# une pièce de bois, sur le billot : elle tressaute sous le maillet
			var saut := Vector2(0.0, 0.6) if eclats >= 0.0 and eclats < 0.07 else Vector2.ZERO
			var a := sol(o + Vector3(0.0, -3.4, 0.0)) + saut
			var b := sol(o + Vector3(0.0, 3.4, 0.0)) + saut
			if a.distance_to(b) < 3.0:
				a = sol(o) + saut + Vector2(-1.6, 0.0)
				b = sol(o) + saut + Vector2(1.6, 0.0)
			ci.draw_line(a, b, P.ENCRE, 4.2, true)
			ci.draw_line(a, b, BOIS, 2.6, true)
			ci.draw_line(a + Vector2(0.0, -0.8), b + Vector2(0.0, -0.8), grain, 0.8, true)
		"rondin":
			# un rondin en travers ; au dernier trait de scie, son bout tombe
			var coupe := 2.8
			var a := sol(o + Vector3(0.0, -6.4, 0.0))
			var m := sol(o + Vector3(0.0, coupe, 0.0))
			var b := sol(o + Vector3(0.0, 6.2, 0.0))
			var de_bout := a.distance_to(b) < 5.0
			if de_bout:
				# (vu par le bout : ses cernes ; la rondelle sciée s'en détache et tombe)
				var c := sol(o)
				_forme(_ellipse(c, 3.1, 2.9, 10), BOIS)
				ci.draw_arc(c, 1.5, 0.0, TAU, 8, grain, 0.7, true)
				if ouvrage_u > 0.0:
					var q := c + Vector2(2.2 * ouvrage_u, minf(10.0 * ouvrage_u * ouvrage_u, o.z - 1.0))
					_forme(_ellipse(q, 3.0, 2.8 * (1.0 - 0.6 * ouvrage_u), 10), grain, 0.8)
			else:
				var chu := ouvrage_u * ouvrage_u
				var tombe := Vector2(signf(b.x - m.x) * 2.5 * ouvrage_u, minf(9.0 * chu, o.z - 1.5))
				ci.draw_line(a, m, P.ENCRE, 4.6, true)
				ci.draw_line(a, m, BOIS, 3.0, true)
				ci.draw_line(a + Vector2(0.0, -0.9), m + Vector2(0.0, -0.9), grain, 0.8, true)
				var m2 := m + tombe + (b - m).normalized() * 0.5 * signf(ouvrage_u)
				var b2 := b + tombe + Vector2(0.0, 2.0 * chu)
				ci.draw_line(m2, b2, P.ENCRE, 4.6, true)
				ci.draw_line(m2, b2, BOIS, 3.0, true)
				_forme(_ellipse(m2, 1.0, 1.9, 8), grain, 0.7)
		"peau":
			# une pièce de peau sur ses genoux ; les points s'y alignent un à un
			var c := sol(o)
			var piece := PackedVector2Array([c + Vector2(-3.6, -1.6), c + Vector2(-0.4, -2.3), c + Vector2(3.4, -1.5), c + Vector2(3.9, 1.0), c + Vector2(1.0, 2.2), c + Vector2(-3.2, 1.5)])
			_forme(piece, PEAU)
			_remplir(PackedVector2Array([c + Vector2(0.6, 0.2), c + Vector2(3.9, 1.0), c + Vector2(1.0, 2.2), c + Vector2(-3.2, 1.5)]), PEAU_OMBRE)
			_encre(piece, 0.8)
			for k in int(round(ouvrage_u * 3.0)):
				var q := c + Vector2(-2.2 + 1.7 * k, -0.9 + 0.15 * k)
				ci.draw_line(q, q + Vector2(0.9, 0.5), IVOIRE_OS.lightened(0.2), 0.8, true)
		"piquet":
			# un piquet, qui s'enfonce à chaque coup ; puis la corde qu'elle y tend
			var pied := sol(Vector3(o.x, o.y, 0.0))
			var haut := sol(o)
			ci.draw_line(pied + Vector2(-2.2, 0.2), pied + Vector2(2.2, 0.2), Color(0, 0, 0, 0.3), 1.6, true)
			ci.draw_line(pied, haut, P.ENCRE, 3.3, true)
			ci.draw_line(pied, haut, BOIS, 1.8, true)
			ci.draw_line(haut + Vector2(-1.0, 0.0), haut + Vector2(1.0, 0.0), grain, 1.2, true)
		"fouille":
			# ce qu'elle écarte : de la terre, des débris
			var c := sol(o)
			for k in 3:
				var q := c + Vector2(-3.0 + 3.0 * k, 0.4 - 0.5 * (k % 2))
				_forme(_ellipse(q, 1.9, 1.1, 6, 0.4 * k), P.TERRE.darkened(0.25) if k != 1 else FERRAILLE.darkened(0.35), 0.8)
		"terre":
			# la terre qu'elle retourne : une plaie sombre qui s'élargit à chaque coup de houe, ses mottes
			var c := sol(Vector3(o.x, o.y, 0.0))
			var u := ouvrage_u
			if u > 0.02:
				_remplir(_ellipse(c + Vector2(-1.0, 0.3), 2.5 + 4.6 * u, 1.2 + 1.5 * u, 10), Color(P.TERRE.darkened(0.42), 0.9))
				for k in int(ceil(u * 3.0)) * 2:
					var q := c + Vector2(-5.0 + 2.6 * k + 1.2 * sin(k * 2.1), -0.4 + 1.1 * cos(k * 1.7))
					_forme(_ellipse(q, 1.5 - 0.2 * (k % 2), 1.0, 6, 0.5 * k), P.TERRE.darkened(0.12 + 0.1 * (k % 3)), 0.7)
		"semis":
			# les graines : à la volée, de sa main au sol, où elles restent (deux jets, l'un après l'autre)
			var c := sol(Vector3(o.x, o.y, 0.0))
			var depart := pt(Vector3(10.6, -6.2 * outil_main, 19.4), buste)
			var jets := int(round(ouvrage_u * 2.0))
			var vol := eclats >= 0.0 and eclats < 0.36
			for k in 9:
				var but := c + Vector2(6.5 * cos(k * 2.4), 2.2 * sin(k * 1.7 + 0.5))
				var jet := 1 if k % 2 == 1 else 2
				if vol and jet == jets:
					var x := eclats / 0.36
					var q := depart.lerp(but, x) + Vector2(0.0, -7.0 * sin(PI * x) * (0.6 + 0.08 * k))
					ci.draw_circle(q, 0.6, IVOIRE_OS.lightened(0.2))
				elif jet <= jets:
					ci.draw_circle(but, 0.5, Color(IVOIRE_OS, 0.75))
		"arrose":
			# l'eau : la terre qui fonce là où elle tombe, le filet du bec au sol, ses éclaboussures
			var c := sol(Vector3(o.x, o.y, 0.0))
			if ouvrage_u > 0.02:
				_remplir(_ellipse(sol(Vector3(o.x, 0.0, 0.0)), 3.0 + 4.5 * ouvrage_u, 1.3 + 1.6 * ouvrage_u, 10), Color(P.ENCRE_DOUCE, 0.3 * minf(1.0, ouvrage_u * 2.0)))
			if filet > 0.02:
				var bec := pt((main_d if outil_main > 0.0 else main_g) + outil_dir.normalized() * 6.6, buste)
				var ton := P.ECHO.lerp(P.PAPIER, 0.35)
				var jet := PackedVector2Array()
				for k in 6:
					var x := k / 5.0
					jet.append(Vector2(lerpf(bec.x, c.x, x) + 0.25 * sin(horloge * 31.0 + k * 1.7) * x, lerpf(bec.y, c.y, x * x)))
				ci.draw_polyline(jet, Color(ton, 0.6 * filet), 0.7, true)
				for k in 3:
					var e := fposmod(horloge * 3.1 + k * 0.37, 1.0)
					ci.draw_circle(c + Vector2((k - 1) * 2.4 * e, -2.4 * sin(PI * e)), 0.5, Color(ton, 0.7 * filet * (1.0 - e)))
		"mortier":
			# le mortier : une pierre creuse posée au sol, qui tressaute sous le pilon ; l'herbe y dépasse d'abord en brins, puis
			# n'est plus qu'une pâte sombre au fond
			var c := sol(Vector3(o.x, o.y, 0.0)) + (Vector2(0.0, 0.5) if eclats >= 0.0 and eclats < 0.06 else Vector2.ZERO)
			_remplir(_ellipse(c + Vector2(0.0, 2.0), 5.8, 1.8, 10), Color(P.ENCRE, 0.22))
			var panse := PackedVector2Array([c + Vector2(-4.6, -3.0), c + Vector2(4.6, -3.0), c + Vector2(4.0, 0.6), c + Vector2(2.4, 2.2), c + Vector2(-2.4, 2.2), c + Vector2(-4.0, 0.6)])
			_forme(_arrondi(panse, 1), PIERRE.darkened(0.12))
			ci.draw_line(c + Vector2(-3.7, -1.0), c + Vector2(-2.7, 1.1), PIERRE.lightened(0.2), 0.7, true)
			ci.draw_line(c + Vector2(1.6, 0.9), c + Vector2(3.2, -0.6), PIERRE.darkened(0.3), 0.7, true)
			_forme(_ellipse(c + Vector2(0.0, -3.0), 4.5, 1.5, 12), PIERRE.darkened(0.45), 0.8)
			_remplir(_ellipse(c + Vector2(0.0, -2.7), 3.2, 0.9, 8), HERBE.lerp(HERBE.darkened(0.4), ouvrage_u))
			if ouvrage_u < 0.62:
				for k in 3:
					ci.draw_line(c + Vector2(-1.8 + 1.8 * k, -2.9), c + Vector2(-2.9 + 2.7 * k, -5.6 + 0.7 * k + 2.4 * ouvrage_u), HERBE.lightened(0.1), 0.8, true)
			ci.draw_line(c + Vector2(-3.9, -3.5), c + Vector2(-1.2, -4.3), PIERRE.lightened(0.32), 0.7, true)
		"botte_vol":
			# la botte lancée : elle tourne en l'air, de sa main au cœur du feu, où elle disparaît ; des brins s'en détachent
			if ouvrage_u < 0.98:
				var depart := pt(Vector3(11.5, 3.5 * outil_main, 27.5), buste)
				var but := sol(o)
				var x := ouvrage_u
				var q := depart.lerp(but, x) + Vector2(0.0, -15.0 * sin(PI * x))
				var tourne := Vector2.from_angle(x * 9.0 + 0.6) * 3.8
				_botte(q - tourne, q + tourne)
				for k in 2:
					var y := maxf(0.0, x - 0.13 * (k + 1))
					var r := depart.lerp(but, y) + Vector2(0.0, -15.0 * sin(PI * y) + 2.2 * (k + 1))
					ci.draw_line(r, r + Vector2(1.3, 0.8), Color(CHANVRE, 0.75 * (1.0 - x)), 0.7, true)
		"bol":
			# le bol sous elle : le lait y file, d'une main puis de l'autre, et monte
			var c := sol(Vector3(o.x, o.y, 0.0))
			_forme(PackedVector2Array([c + Vector2(-3.0, -1.6), c + Vector2(3.0, -1.6), c + Vector2(2.0, 1.2), c + Vector2(-2.0, 1.2)]), BOIS, 0.9)
			var niveau := clampf(ouvrage_u / 4.0, 0.0, 1.0)
			if niveau > 0.05:
				ci.draw_line(c + Vector2(-2.3 - 0.4 * niveau, -0.2 - 1.2 * niveau), c + Vector2(2.3 + 0.4 * niveau, -0.2 - 1.2 * niveau), P.PAPIER, 1.0, true)
			var tire := sin(TAU * ouvrage_u)
			if ouvrage_u > 0.05 and ouvrage_u < 3.95 and absf(tire) > 0.25:
				var m := pt(main_d if tire * outil_main < 0.0 else main_g, buste)
				ci.draw_line(m + Vector2(0.0, 1.6), c + Vector2(signf(m.x - c.x) * 0.8, -1.2), Color(P.PAPIER, 0.6), 0.5, true)
	if fil > 0.01:
		var depart := sol(o)
		if ouvrage == "peau":
			# le fil, de la peau à l'aiguille
			var bout := pt((main_d if outil_main > 0.0 else main_g) + outil_dir.normalized() * 3.4, buste)
			ci.draw_line(depart + Vector2(0.6, -0.8), bout, Color(IVOIRE_OS, 0.85 * fil), 0.5, true)
		else:
			# la corde, du piquet à ses mains : tendue, elle vibre
			var milieu := depart.lerp(main, 0.5) + Vector2(0.0, 3.0 * (1.0 - fil) + 0.35 * sin(horloge * 60.0) * fil)
			var corde := PackedVector2Array([depart + Vector2(0.0, 1.0), milieu, main])
			ci.draw_polyline(corde, Color(P.ENCRE, fil), 1.7, true)
			ci.draw_polyline(corde, Color(CHANVRE, fil), 0.8, true)
	if eclats >= 0.0 and eclats < 0.34 and not mobile and ouvrage != "semis":
		# ce qui saute : des copeaux, de la sciure, de la terre (sous la houe : des mottes, et davantage)
		var terre := ouvrage == "fouille" or ouvrage == "terre"
		var c := sol(o) + (Vector2(0.0, -1.5) if not terre else Vector2.ZERO)
		var teinte := grain if not terre else P.TERRE.lightened(0.15)
		if ouvrage == "mortier":
			# (sous le pilon : des brins d'herbe, qui sautent du creux)
			teinte = HERBE.lightened(0.12)
			c += Vector2(0.0, -1.6)
		var n := 7 if ouvrage == "terre" else 4
		for k in n:
			var v := Vector2(-16.0 + 44.0 * k / n + 5.0 * sin(k * 2.3), -26.0 - 7.0 * cos(k * 1.7))
			var q := c + v * eclats + Vector2(0.0, 150.0 * eclats * eclats)
			ci.draw_line(q, q + v.normalized() * 1.5, Color(teinte, 1.0 - eclats / 0.34), 0.9, true)
			if ouvrage == "terre" and k % 2 == 0:
				ci.draw_circle(q + Vector2(1.5, -1.0), 0.8, Color(P.TERRE.darkened(0.25), 1.0 - eclats / 0.34))


# le duvet : une peau roulée autour d'elle, des pieds aux épaules (on y devine la hanche, l'épaule), cousue le long, son bord
# retourné sur sa fourrure ; il se soulève à son souffle
func _duvet() -> void:
	var pied := chute * pt(Vector3(0.0, 0.0, -7.5), cap)
	var haut := chute * pt(Vector3(0.0, 0.0, 26.8 + epaules), buste)
	var axe := haut - pied
	var l := axe.length()
	if l < 4.0:
		return
	var u := axe / l
	var n := Vector2(-u.y, u.x)
	if n.y > 0.0:
		n = -n
	# (le long du corps : où, son épaisseur au-dessus, au-dessous ; les pieds, les genoux, la hanche, la taille, l'épaule)
	var gonfle := 0.5 * respire
	var profil := [[0.0, 1.8, 1.6], [0.05, 4.0, 3.4], [0.13, 5.6, 4.4], [0.24, 5.0, 4.9], [0.36, 6.3, 5.3], [0.5, 7.6 + 0.3 * gonfle, 5.6], [0.66, 6.3 + 0.5 * gonfle, 5.4],
		[0.86, 8.1 + gonfle, 5.8], [1.0, 7.3 + 0.7 * gonfle, 5.5]]
	var dessus := PackedVector2Array()
	var dessous := PackedVector2Array()
	var jusque := dort
	for q in profil:
		var f := minf(float(q[0]), jusque)
		dessus.append(pied + u * l * f + n * float(q[1]))
		dessous.append(pied + u * l * f - n * float(q[2]))
		if float(q[0]) >= jusque:
			break
	var retour := dessous.duplicate()
	retour.reverse()
	var corps := PackedVector2Array()
	corps.append_array(dessus)
	corps.append_array(retour)
	corps = _arrondi(corps, 2)
	_remplir(corps, DUVET)
	# (l'ombre : le dessous, contre le sol ; la lumière : une ligne sur le dessus)
	var ombre := PackedVector2Array()
	for i in dessous.size():
		ombre.append(dessous[i].lerp(dessus[i], 0.36))
	ombre.append_array(retour)
	_remplir(_simple(ombre), DUVET_OMBRE)
	var clair := PackedVector2Array()
	for i in range(1, dessus.size()):
		clair.append(dessus[i].lerp(dessous[i], 0.17))
	if clair.size() > 1:
		ci.draw_polyline(clair, DUVET_CLAIR, 1.1, true)
	# la couture, le long ; deux plis où le corps se creuse
	if not mobile:
		for k in 8:
			var f := 0.1 + 0.1 * k
			if f < jusque - 0.06:
				var c := pied + u * l * f + n * 0.6
				ci.draw_line(c - u * 0.9, c + u * 0.9 + n * 0.5, DUVET_OMBRE.darkened(0.35), 0.8, true)
		for f in [0.33, 0.7]:
			if f < jusque - 0.06:
				var c: Vector2 = pied + u * l * float(f)
				ci.draw_polyline(PackedVector2Array([c + n * 6.0, c + n * 3.2 + u * 1.2, c + n * 1.6 + u * 0.6]), DUVET_OMBRE.darkened(0.3), 0.8, true)
	_encre(corps)
	if jusque > 0.9:
		# le bord, retourné sur sa fourrure, sous son menton
		var bord := PackedVector2Array()
		for k in 7:
			var v := -1.0 + 2.0 * k / 6.0
			var m := 0.3 if k % 2 == 0 else -0.2
			bord.append(pied + u * (l * jusque - 0.4 - 1.5 * (1.0 - v * v) + m) + n * ((7.2 + 0.7 * gonfle) * v if v > 0.0 else 5.4 * v))
		ci.draw_polyline(bord, P.ENCRE, 3.8, true)
		ci.draw_polyline(bord, FOURRURE, 2.3, true)


func _torche(main: Vector3) -> void:
	var d := DIR_TORCHE
	var bas_ := pt(main - d * 3.5, buste)
	var haut := pt(main + d * 9.0, buste)
	ci.draw_line(bas_, haut, P.ENCRE, 3.3, true)
	ci.draw_line(bas_, haut, BOIS.darkened(0.25), 1.8, true)
	var tete_ := pt(main + d * 9.8, buste)
	_forme(_ellipse(tete_, 1.9, 2.3, 10), P.CENDRE)
	ci.draw_line(tete_ + Vector2(-1.6, 0.6), tete_ + Vector2(1.6, -0.4), P.ENCRE_DOUCE, 0.8, true)


func _objet(p: Vector2) -> void:
	match objet:
		"caillou":
			_forme(PackedVector2Array([p + Vector2(-2.2, -0.6), p + Vector2(-0.6, -2.3), p + Vector2(1.9, -1.4), p + Vector2(2.2, 0.9), p + Vector2(-0.4, 1.8)]), PIERRE)
		"baie":
			for o in [Vector2(-0.9, -1.4), Vector2(1.0, -1.1), Vector2(0.1, -2.6)]:
				_forme(_ellipse(p + o, 1.05, 1.05, 6), P.SANG.lightened(0.25))
		"fibre":
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.35
				ci.draw_line(p, p + Vector2.from_angle(a) * 4.5, P.MOUSSE.lightened(0.25), 0.9, true)
		"brindille":
			ci.draw_line(p + Vector2(-4.0, 1.2), p + Vector2(4.0, -1.4), P.ENCRE, 2.6, true)
			ci.draw_line(p + Vector2(-4.0, 1.2), p + Vector2(4.0, -1.4), BOIS, 1.2, true)


# --- ce que le temps lui fait ---

# trempée : des gouttes tombent de sa capuche, de son écharpe, du bas de son manteau ; l'étoffe mouillée luit
func _gouttes() -> void:
	var pale := P.PAPIER.lerp(P.ECHO, 0.55)
	var departs := [pt(Vector3(1.0, 9.6, 8.6), cap) + cape * 0.8, pt(Vector3(4.6, -1.0, 33.4 - tete_baisse), tete), pt(Vector3(1.0, -9.6, 8.6), cap) + cape * 0.8,
		pt(Vector3(-4.0, 2.0, 26.0), buste), pt(Vector3(6.0, 3.0, 9.0), cap) + cape * 0.8]
	var n := clampi(int(ceil(mouille * 5.0 - 0.7)), 0, 5)
	for k in n:
		var u := fposmod(horloge * (1.05 + 0.17 * k) + k * 0.37, 1.0)
		var d: Vector2 = departs[k]
		# (elle perle un instant, puis tombe jusqu'au sol)
		var y := lerpf(d.y, enfonce - 0.5, smoothstep(0.25, 1.0, u) * smoothstep(0.25, 1.0, u))
		var x := d.x + cape.x * 0.1
		ci.draw_line(Vector2(x, y - (0.5 + 1.9 * smoothstep(0.25, 0.6, u))), Vector2(x, y), Color(pale, (0.3 + 0.4 * smoothstep(0.2, 0.5, u)) * (1.0 - smoothstep(0.85, 1.0, u))), 0.8, true)
	# (le reflet de l'eau sur la capuche et l'épaule, du côté du jour)
	var c := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
	ci.draw_line(c + Vector2(-4.6, -3.4), c + Vector2(-2.2, -5.4), Color(pale, 0.42 * mouille), 1.0, true)
	var ep := pt(Vector3(0.0, 0.0, 26.6 + epaules), buste)
	ci.draw_line(ep + Vector2(-5.8, 0.6), ep + Vector2(-4.6, 4.4), Color(pale, 0.34 * mouille), 1.0, true)


# la cape de pluie sous l'averse : la toile luit (un reflet sur le capuchon, un sur l'épaule), et l'eau y perle : des gouttes
# rondes se forment, roulent jusqu'au bord, et tombent
func _perles() -> void:
	var pale := P.PAPIER.lerp(P.ECHO, 0.3)
	var c := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
	var vif := 0.75 + 0.25 * sin(horloge * 5.3)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-5.6, -1.6), c + Vector2(-4.7, -4.0), c + Vector2(-2.6, -5.8)]), Color(pale, 0.7 * pluie * vif), 1.2, true)
	var ep := pt(Vector3(0.0, 0.0, 26.8 + epaules), buste)
	ci.draw_line(ep + Vector2(-6.4, 0.4), ep + Vector2(-7.2, 5.6), Color(pale, 0.55 * pluie * (1.5 - vif)), 1.2, true)
	ci.draw_line(ep + Vector2(-1.6, 2.2), ep + Vector2(-2.2, 7.0), Color(pale, 0.3 * pluie * vif), 0.9, true)
	# (chaque perle : où elle naît, sur le capuchon ou l'épaule, et le bord d'où elle tombe)
	var bord := 12.0
	var chemins := [[pt(Vector3(1.0, 5.0, 27.5 + epaules), buste), pt(Vector3(2.5, 9.4, bord), cap) + cape * 0.7],
		[c + Vector2(-3.0, -3.6), c + Vector2(-7.0, 4.6)],
		[pt(Vector3(3.0, -4.6, 27.0 + epaules), buste), pt(Vector3(5.5, -7.6, bord), cap) + cape * 0.7],
		[c + Vector2(3.6, -2.4), c + Vector2(7.0, 5.0)],
		[pt(Vector3(4.2, 1.0, 26.0 + epaules), buste), pt(Vector3(8.2, 2.2, bord), cap) + cape * 0.7]]
	var n := clampi(int(ceil(pluie * (3.0 if mobile else 5.0))), 1, chemins.size())
	for k in n:
		var u := fposmod(horloge * (0.62 + 0.11 * k) + k * 0.41, 1.0)
		var a: Vector2 = chemins[k][0]
		var b: Vector2 = chemins[k][1]
		if u < 0.72:
			# (elle grossit sur place, puis roule, de plus en plus vite)
			var v := smoothstep(0.18, 0.72, u)
			var p := a.lerp(b, v * v)
			var r := 0.5 + 0.35 * smoothstep(0.0, 0.2, u)
			ci.draw_circle(p, r, Color(pale, 0.85 * pluie))
			ci.draw_circle(p + Vector2(0.25, 0.3), r * 0.5, Color(c_cire_ombre, 0.5))
		else:
			# (puis tombe du bord, jusqu'au sol)
			var v := (u - 0.72) / 0.28
			var y := lerpf(b.y, enfonce - 0.5, v * v)
			ci.draw_line(Vector2(b.x, y - 2.0), Vector2(b.x, y), Color(pale, 0.6 * pluie * (1.0 - smoothstep(0.8, 1.0, v))), 0.8, true)


# elle a froid : son souffle fait de la buée, par bouffées, devant sa bouche
func _buee() -> void:
	if cos(tete) < -0.35:
		return
	var u := fposmod(horloge / 2.1, 1.0) / 0.46
	if u >= 1.0:
		return
	var devant := Vector2(sin(tete), cos(tete) * INCL)
	var bouche := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste) + proj(Vector3(3.9, 0.0, -3.2), tete)
	var pale := P.PAPIER.lerp(P.ECHO, 0.35)
	var a := 0.55 * froid * (1.0 - u) * smoothstep(0.0, 0.15, u)
	var p := bouche + devant * (2.5 + 8.0 * u) + Vector2(0.0, -3.0 * u * u)
	ci.draw_circle(p, 1.5 + 3.0 * u, Color(pale, a))
	ci.draw_circle(p + devant * 2.2 + Vector2(0.8, -1.4), 1.0 + 2.2 * u, Color(pale, a * 0.7))


# ce que les herbes font sortir de sa bouche : ce qu'elle recrache (l'herbe âcre : des gouttes et des brins mâchés, en gerbe
# courte, qui retombent), le long souffle du poison qui la quitte
func _bouche_herbes() -> void:
	if cos(tete) < -0.35:
		return
	var devant := Vector2(sin(tete), cos(tete) * INCL)
	var bouche := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste) + proj(Vector3(3.9, 0.0, -3.2), tete)
	if crache >= 0.0 and crache < 0.5:
		var x := crache / 0.5
		for k in 6:
			var v := devant * (9.0 + 4.0 * sin(k * 2.1)) + Vector2(2.2 * cos(k * 1.7), -4.5 - 2.0 * cos(k * 2.9))
			var q := bouche + v * x + Vector2(0.0, 15.0 * x * x)
			if k % 2 == 0:
				ci.draw_line(q, q + v.normalized() * 1.4, Color(HERBE.darkened(0.1), 1.0 - x * x), 0.9, true)
			else:
				ci.draw_circle(q, 0.6, Color(P.PAPIER.lerp(HERBE, 0.3), 0.85 * (1.0 - x)))
	if soupir > 0.02:
		var pale := P.PAPIER.lerp(P.ECHO, 0.25)
		var p := bouche + devant * (2.5 + 7.0 * soupir) + Vector2(0.0, 1.5 * soupir)
		ci.draw_circle(p, 1.2 + 2.4 * soupir, Color(pale, 0.32 * soupir))
		ci.draw_circle(p + devant * 2.4 + Vector2(0.6, 0.9), 0.9 + 1.8 * soupir, Color(pale, 0.22 * soupir))


# une botte d'herbe sèche : des tiges liées d'un brin, leurs têtes en éventail
func _botte(cul: Vector2, bout: Vector2) -> void:
	var u := (bout - cul).normalized() if bout.distance_to(cul) > 0.1 else Vector2.RIGHT
	var n := Vector2(-u.y, u.x)
	var paille := CHANVRE.lerp(HERBE, 0.35)
	ci.draw_line(cul, bout, P.ENCRE, 3.6, true)
	for k in 4:
		var e := (k - 1.5) * 0.7
		ci.draw_line(cul + n * e * 0.6, bout + n * e * 1.5 + u * (0.6 - 0.3 * absf(e)), paille.darkened(0.12 * (k % 2)), 0.8, true)
	var milieu := cul.lerp(bout, 0.45)
	ci.draw_line(milieu - n * 1.7, milieu + n * 1.7, ROULEAU.darkened(0.3), 1.1, true)
	for k in 3:
		ci.draw_circle(bout + n * (k - 1) * 1.5 + u * 0.4, 0.75, HERBE.darkened(0.25))


# --- la silhouette seule (l'éclair d'une blessure, le liseré de lune la nuit) ---

func silhouette(couleur: Color) -> void:
	ci.draw_set_transform_matrix(chute)
	var ep: Array = _anneau(27.2 + epaules, _ep.x, _ep.y, buste, 24, 0)
	var ou: Array = _anneau(8.0, _ou.x, _ou.y, cap, 24, 2)
	var tout := PackedVector2Array()
	tout.append_array(ep[0])
	tout.append_array(ou[0])
	_remplir(_enveloppe(tout), couleur)
	var c := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
	if cire:
		_remplir(_tour_capuche(c, tete, 24), couleur)
	else:
		_remplir(_ellipse(c, 7.6, 7.2, 16), couleur)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# le contour du haut, côté lune (en haut à gauche) : la nuit, elle se détache du noir
func lisere_lune(couleur: Color) -> void:
	ci.draw_set_transform_matrix(chute)
	var c := pt(Vector3(0.6 + tete_baisse * 0.5, 0.0, 37.4 + epaules * 0.4 - tete_baisse), buste)
	var arc := PackedVector2Array()
	if cire:
		# (le capuchon pointu : son tour, du côté de la lune)
		var tour := _tour_capuche(c, tete, 30)
		var k0 := 0
		for i in tour.size():
			var d0 := (tour[i] - c).normalized()
			var d1 := (tour[(i + tour.size() - 1) % tour.size()] - c).normalized()
			if d0.x < 0.2 and d0.y < -0.02 and not (d1.x < 0.2 and d1.y < -0.02):
				k0 = i
		for i in tour.size():
			var p := tour[(k0 + i) % tour.size()]
			var d := (p - c).normalized()
			if d.x < 0.2 and d.y < -0.02:
				arc.append(p + d * 0.1)
	else:
		var pic := proj(Vector3(-1.0, 0.0, 0.85), tete).normalized()
		for k in 12:
			var be := PI * 0.95 + PI * 0.65 * k / 11.0
			var dir := Vector2(cos(be), sin(be))
			arc.append(c + Vector2(cos(be) * 7.5, sin(be) * 7.1) + dir * pow(maxf(0.0, dir.dot(pic)), 6.0) * 3.2)
	if arc.size() > 1:
		ci.draw_polyline(arc, couleur, 1.2, true)
	var ep: Array = _anneau(27.2 + epaules, _ep.x, _ep.y, buste, 24, 0)
	var ta: Array = _anneau(17.0, _ta.x, _ta.y, buste, 24, 1)
	var ou: Array = _anneau(8.0, _ou.x, _ou.y, cap, 24, 2)
	var g := _courbe(ep[0][_extremes(ep[0]).x], ta[0][_extremes(ta[0]).x], ou[0][_extremes(ou[0]).x], 6)
	ci.draw_polyline(g, Color(couleur, couleur.a * 0.7), 1.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- les outils du trait ---

static func _ellipse(c: Vector2, rx: float, ry: float, n: int, ang: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rot := Vector2.from_angle(ang)
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(p.x * rot.x - p.y * rot.y, p.x * rot.y + p.y * rot.x))
	return pts


# un polygone aux coins adoucis (Chaikin)
static func _arrondi(pts: PackedVector2Array, fois: int) -> PackedVector2Array:
	var p := pts
	for k in fois:
		var q := PackedVector2Array()
		for i in p.size():
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


static func _enveloppe(pts: PackedVector2Array) -> PackedVector2Array:
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0] == h[h.size() - 1]:
		h.remove_at(h.size() - 1)
	return h


# un polygone qui se dessine sans erreur : s'il se croise, son enveloppe
static func _simple(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3 or not Geometry2D.triangulate_polygon(pts).is_empty():
		return pts
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0] == h[h.size() - 1]:
		h.remove_at(h.size() - 1)
	return h


# la part du polygone à droite d'une ligne (l'ombre) : ce qui est à gauche est ramené contre elle
static func _vers_droite(pts: PackedVector2Array, x0: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(maxf(p.x, x0 + (p.x - x0) * 0.16), p.y))
	return out


func _remplir(pts: PackedVector2Array, couleur: Color) -> void:
	if pts.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		pts = _simple(pts)
		idx = Geometry2D.triangulate_polygon(pts)
		if idx.is_empty():
			return
	if ci is CanvasItem:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([couleur]))
	else:
		ci.triangles(idx, pts, couleur)


func _encre(pts: PackedVector2Array, largeur: float = TRAIT) -> void:
	if pts.size() < 2:
		return
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	ci.draw_polyline(ferme, P.ENCRE, largeur, true)


func _forme(pts: PackedVector2Array, couleur: Color, largeur: float = TRAIT) -> void:
	_remplir(pts, couleur)
	_encre(pts, largeur)
