extends RefCounted
# Lisière — les sons de l'atelier (scripts/sons_atelier.gd)
# Ce qu'on entend à l'établi et au camp (scripts/atelier.gd) : le maillet, la scie, l'alêne et le fil, les fibres, la bâche,
# le piquet, la corde, la ferraille d'un vestige, l'eau dans la gourde et dans la gorge, le bouillon, la lampe, le fil du
# cerf-volant, les piles qui chargent, la bête prise au filet, la sangle. Faits comme ceux de sons_recettes.gd, avec les
# mêmes outils (sons_outils.gd) : du bruit filtré, des éclats, des résonances amorties. Courts, mats ; rien qui tienne une note.
# fabriquer(nom, r) rend [échantillons, taux] ; un chiffre au bout du nom tire une variante (« marteau1 », « etincelle2 » :
# tout nom en accepte un, chaque tirage est différent ; pour le marteau et la scie, il choisit aussi le caractère).
# Un téléphone ne rend rien sous 200 Hz : chaque son a son corps entre 300 Hz et 4 kHz ; les graves ne sont là qu'en plus.

const O := preload("res://scripts/sons_outils.gd")
const GRAVE := O.GRAVE
const SOURD := O.SOURD
const LENT := O.LENT
const VIF := O.VIF

# le taux de chaque son : assez pour ses aigus, pas plus
const TAUX := {
	"marteau": VIF, "scie": VIF, "couture": VIF, "tresse": VIF, "toile": VIF, "piquet": VIF, "corde": SOURD, "fouille": VIF,
	"gourde": LENT, "gorgee": LENT, "bouillon": SOURD, "clic": VIF, "fil": SOURD, "etincelle": VIF, "filet": VIF, "sangle": VIF,
}
# tous les noms, avec leurs variantes (ce qui revient souvent en a plusieurs : on ne reconnaît pas deux fois la même étincelle)
const NOMS := ["marteau0", "marteau1", "marteau2", "scie0", "scie1", "couture", "tresse", "toile", "piquet", "corde", "fouille",
	"gourde", "gorgee", "bouillon0", "bouillon1", "clic", "fil0", "fil1", "etincelle0", "etincelle1", "etincelle2", "filet0", "filet1",
	"sangle"]
# les deux couches continues, en tuiles qui se chevauchent comme celles de sons_recettes.gd : [longueur, fondu] (en secondes)
const TUILES := {"bouillon": [3.6, 0.9], "fil": [4.0, 1.2]}
# le niveau conseillé de chaque son (en dB : tout son volume, pas un appoint), celui où il pèse à l'oreille ce qu'il faut à
# côté des gestes du jeu (un coup de hache, un pas dans les feuilles) ; pour les deux couches, leur niveau à 1 (comme dans
# COUCHES, sons.gd). Et sa part de réverbère la nuit (comme MOUILLE, sons.gd) : ce qui porte dans le lieu en a, ce qui se
# fait tout contre soi n'en a pas
const NIVEAUX := {"marteau": -7.0, "scie": -16.0, "couture": -12.0, "tresse": -16.0, "toile": -9.0, "piquet": -8.0, "corde": -16.0,
	"fouille": -12.0, "gourde": -17.0, "gorgee": -15.0, "clic": -10.0, "etincelle": -11.0, "filet": -13.0, "sangle": -17.0,
	"bouillon": -15.0, "fil": -14.0}
const MOUILLE := {"marteau": 0.3, "scie": 0.15, "toile": 0.3, "piquet": 0.35, "corde": 0.1, "fouille": 0.2, "filet": 0.25}
# un choc part juste après le fondu d'entrée (O.bords, 1,5 ms), qui sinon lui mange son attaque
const T0 := 0.002
# chaque son est réglé par son énergie (c'est elle qui pèse à l'oreille : d'un tirage à l'autre il sonne aussi fort), sans
# que sa crête dépasse ceci
const CRETE := 0.92


# [échantillons, taux] ; [] si le nom n'est pas connu
static func fabriquer(nom: String, r: RandomNumberGenerator) -> Array:
	var base := nom.rstrip("0123456789")
	var k := int(nom.substr(base.length())) if base.length() < nom.length() else 0
	match base:
		"marteau":
			return [_marteau(k, r), TAUX[base]]
		"scie":
			return [_scie(k, r), TAUX[base]]
		"couture":
			return [_couture(r), TAUX[base]]
		"tresse":
			return [_tresse(r), TAUX[base]]
		"toile":
			return [_toile(r), TAUX[base]]
		"piquet":
			return [_piquet(r), TAUX[base]]
		"corde":
			return [_corde(r), TAUX[base]]
		"fouille":
			return [_fouille(r), TAUX[base]]
		"gourde":
			return [_gourde(r), TAUX[base]]
		"gorgee":
			return [_gorgee(r), TAUX[base]]
		"bouillon":
			return [_bouillon(r), TAUX[base]]
		"clic":
			return [_clic(r), TAUX[base]]
		"fil":
			return [_fil(r), TAUX[base]]
		"etincelle":
			return [_etincelle(r), TAUX[base]]
		"filet":
			return [_filet(r), TAUX[base]]
		"sangle":
			return [_sangle(r), TAUX[base]]
	return []


# une couche continue (« bouillon », « fil ») en vraie boucle : la tuile repliée sur elle-même (sa fin fondue dans son
# début), longue de longueur − fondu. Le dernier échantillon rejoint le premier : elle se lit avec AudioStreamWAV.LOOP_FORWARD.
# (dans un navigateur, une boucle laisse un trou à chaque tour : là, ce sont les tuiles qu'il faut, celles de fabriquer())
static func boucle(nom: String, r: RandomNumberGenerator) -> Array:
	var base := nom.rstrip("0123456789")
	if not TUILES.has(base):
		return []
	var a: Array = fabriquer(nom, r)
	var tuile: PackedFloat32Array = a[0]
	var taux: int = a[1]
	var p := tuile.size() - int(float(TUILES[base][1]) * taux)
	var s := tuile.slice(0, p)
	for i in tuile.size() - p:
		s[i] += tuile[p + i]
	return [s, taux]


# --- des briques ---

# pose src dans dest à partir de « debut » (en secondes), sa crête ramenée à amp
static func _mettre(dest: PackedFloat32Array, src: PackedFloat32Array, debut: float, amp: float, taux: int) -> void:
	O.poser(dest, src, int(debut * taux), amp / maxf(O.crete(src), 0.0001))


# un souffle : du bruit dans une bande qui glisse de f0 à f1, sous une cloche dont le sommet tombe à « sommet » (de 0 à 1)
static func _souffle(s: PackedFloat32Array, debut: float, duree: float, f0: float, f1: float, q: float, amp: float, taux: int, r: RandomNumberGenerator, sommet: float = 0.4) -> void:
	var n := maxi(8, int(duree * taux))
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var u := float(i) / n
		var e := sin(PI * 0.5 * u / sommet) if u < sommet else pow(cos(PI * 0.5 * (u - sommet) / (1.0 - sommet)), 1.5)
		b[i] = r.randf_range(-1.0, 1.0) * e
	if absf(f1 - f0) < 1.0:
		O.bande(b, f0, q, taux)
	else:
		O.bande_glissee(b, f0, f1, q, taux)
	_mettre(s, b, debut, amp, taux)


# des grains : de petits éclats semés sur « duree », dans une bande (serre > 1 : plus serrés au début ; < 1 : vers la fin)
static func _grains(s: PackedFloat32Array, debut: float, duree: float, nombre: int, fc: float, q: float, amp: float, taux: int, r: RandomNumberGenerator, tau := Vector2(0.0003, 0.0012), serre: float = 1.0) -> void:
	var b := O.vide(duree + 0.02, taux)
	for i in nombre:
		O.eclat(b, duree * pow(r.randf(), serre), r.randf_range(tau.x, tau.y), r.randf_range(0.25, 1.0), r, taux)
	O.bande(b, fc, q, taux)
	_mettre(s, b, debut, amp, taux)


# un grincement : ça accroche et ça lâche, par à-coups inégaux (c0 par seconde au début, c1 à la fin), à travers des
# résonances [fréquence, q, gain] ; « rale » : ce qui frotte entre les à-coups
static func _grince(duree: float, c0: float, c1: float, formants: Array, rale: float, taux: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := maxi(8, int(duree * taux))
	var e := PackedFloat32Array()
	e.resize(n)
	var k := exp(-1.0 / (0.0012 * taux))
	var imp := 0.0
	var attente := 0.0
	for i in n:
		attente -= 1.0
		if attente <= 0.0:
			# (jamais deux à-coups au même écart : sinon c'est une note, et plus un grincement)
			attente = taux / (lerpf(c0, c1, float(i) / n) * r.randf_range(0.7, 1.4))
			imp = r.randf_range(0.45, 1.0)
		e[i] = imp + r.randf_range(-rale, rale) * (0.25 + imp)
		imp *= k
	var s := PackedFloat32Array()
	s.resize(n)
	for fo in formants:
		var c := e.duplicate()
		O.bande(c, fo[0], fo[1], taux)
		O.poser(s, c, 0, fo[2])
	return s


# --- l'établi ---

# le maillet de pierre sur le bois de l'établi : un choc mat, le plateau qui répond (court), le billot dessous.
# k : 0, un coup franc ; 1, plus sec et plus haut ; 2, le dernier, plus lourd (un outil posé sur le plateau tressaute)
static func _marteau(k: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var v := k % 3
	var s := O.vide(0.22, VIF)
	var f: float = [348.0, 414.0, 324.0][v] * r.randf_range(0.98, 1.03)
	var tenue: float = [1.0, 0.75, 1.25][v]
	# le choc : la pierre ne sonne pas, elle cogne
	var c := O.vide(0.03, VIF)
	O.eclat(c, 0.0, [0.0012, 0.0009, 0.0017][v], 1.0, r, VIF)
	O.bas(c, [2800.0, 3600.0, 2200.0][v], VIF)
	_mettre(s, c, T0, 0.9, VIF)
	O.mode(s, T0, r.randf_range(1500.0, 1900.0), 0.004, 0.3, VIF)
	# le bois répond d'un bloc (un « toc » sans note)…
	var b := O.vide(0.07, VIF)
	O.eclat(b, 0.0, 0.007 * tenue, 1.0, r, VIF)
	O.bande(b, f * 2.6, 0.8, VIF)
	_mettre(s, b, T0, 0.55, VIF)
	# … puis les modes du plateau de rondins, vite éteints
	O.mode(s, T0, f, 0.024 * tenue, 0.6, VIF, 0.985)
	O.mode(s, T0, f * 2.32, 0.014 * tenue, 0.4, VIF)
	O.mode(s, T0, f * 4.25, 0.008 * tenue, 0.3, VIF)
	O.mode(s, T0, f * 6.9, 0.005, 0.16, VIF)
	# le billot, dessous (un téléphone ne le rend pas)
	O.mode(s, T0, 118.0, 0.03, 0.32 if v == 2 else 0.25, VIF, 0.85)
	if v == 2:
		for i in 2:
			var t := 0.05 + 0.04 * i + r.randf_range(0.0, 0.015)
			O.mode(s, t, r.randf_range(2100.0, 2900.0), 0.004, 0.09 - 0.03 * i, VIF)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.075, CRETE)
	return O.bords(s, VIF)


# un trait de scie : les dents mordent une à une (le bruit est haché à leur cadence, qui suit la vitesse de la lame),
# la lame racle (f_lame), la planche chante dessous (f_bois) ; « mord » : de 0 (elle glisse) à 1 (chaque dent arrache) ;
# « niveau » : son niveau moyen
static func _trait_scie(s: PackedFloat32Array, debut: float, duree: float, dents: float, f_lame: float, f_bois: float, niveau: float, mord: float, r: RandomNumberGenerator) -> void:
	var n := maxi(8, int(duree * VIF))
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var a := 1.0
	for i in n:
		# (la vitesse de la lame : elle part, file, ralentit)
		var v := pow(sin(PI * float(i) / n), 0.6)
		ph += dents * v / VIF
		if ph >= 1.0:
			ph -= 1.0
			a = r.randf_range(0.5, 1.0)
		var d := 1.0 - ph
		b[i] = r.randf_range(-1.0, 1.0) * v * (1.0 - mord + mord * a * d * d)
	var c := b.duplicate()
	O.bande(b, f_lame, 0.9, VIF)
	O.bande(c, f_bois, 2.0, VIF)
	O.poser(b, c, 0, 0.6)
	var e := 0.0
	for i in n:
		e += b[i] * b[i]
	O.poser(s, b, int(debut * VIF), niveau / maxf(sqrt(e / n), 0.0001))


# la scie d'os dans le bois : un aller qui mord, un retour qui glisse (plus bas, plus doux). k = 1 : un trait plus court,
# plus vif (le trait est plus profond, la planche chante plus haut)
static func _scie(k: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var court := k % 2 == 1
	var da := 0.25 if court else 0.3
	var dr := 0.2 if court else 0.24
	var s := O.vide(da + dr + 0.07, VIF)
	var h := r.randf_range(0.95, 1.05) * (1.12 if court else 1.0)
	_trait_scie(s, 0.0, da, 118.0 * h, 2700.0 * h, 640.0 * h, 0.2, 0.9, r)
	_trait_scie(s, da + 0.035, dr, 88.0 * h, 1900.0 * h, 560.0 * h, 0.1, 0.45, r)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.09, CRETE)
	return O.bords(s, VIF)


# coudre la peau : deux points. L'alêne perce (un petit « pk », la peau tendue répond), puis le fil file (un souffle mince
# qui monte, grenu : les fibres accrochent le cuir). Très doux
static func _couture(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.8, VIF)
	var t := 0.004
	for p in 2:
		var g := 1.0 - 0.22 * p
		var h := r.randf_range(0.94, 1.08)
		var c := O.vide(0.02, VIF)
		O.eclat(c, 0.0, 0.0004, 1.0, r, VIF)
		O.bande(c, 2300.0 * h, 2.2, VIF)
		_mettre(s, c, t, 0.5 * g, VIF)
		O.mode(s, t, 410.0 * h, 0.007, 0.3 * g, VIF, 0.8)
		O.mode(s, t, 980.0 * h, 0.004, 0.15 * g, VIF)
		var d := r.randf_range(0.2, 0.26)
		_souffle(s, t + 0.06, d, 2300.0 * h, 3500.0 * h, 3.5, 0.32 * g, VIF, r, 0.3)
		_grains(s, t + 0.07, d - 0.04, 14, 3000.0 * h, 1.4, 0.22 * g, VIF, r, Vector2(0.0002, 0.0005))
		t += r.randf_range(0.38, 0.44)
	O.bas(s, 5000.0, VIF)
	O.niveau(s, 0.042, CRETE)
	return O.bords(s, VIF)


# des fibres qu'on tord en corde : trois tours de main. Les brins frottent, craquent, et crissent au bout du tour ; le brin
# se serre : chaque tour sonne plus haut, plus court
static func _tresse(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.7, VIF)
	var t := 0.0
	for p in 3:
		var h := 1.0 + 0.09 * p
		var d := 0.2 - 0.03 * p
		_souffle(s, t, d, 1000.0 * h, 1500.0 * h, 1.3, 0.3, VIF, r, 0.55)
		_grains(s, t + 0.01, d - 0.03, 16 + 2 * p, 2500.0 * h, 1.3, 0.8, VIF, r, Vector2(0.0003, 0.001), 0.8)
		var g := _grince(0.09, 70.0 * h, 110.0 * h, [[760.0 * h, 5.0, 1.0], [1900.0 * h, 6.0, 0.5]], 0.3, VIF, r)
		O.enveloppe(g, 0.01, 0.04, VIF)
		_mettre(s, g, t + d - 0.08, 0.4, VIF)
		t += d + r.randf_range(0.03, 0.06)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.075, CRETE)
	return O.bords(s, VIF)


# --- le camp ---

# une bâche qu'on déplie : la toile enduite se froisse, de plus en plus ; elle claque, une fois (l'air chassé d'un coup) ;
# elle retombe
static func _toile(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.82, VIF)
	var tc := r.randf_range(0.43, 0.47)
	_souffle(s, 0.0, tc + 0.01, 520.0, 1500.0, 0.8, 0.4, VIF, r, 0.85)
	_grains(s, 0.02, tc - 0.04, 30, 1900.0, 1.0, 0.45, VIF, r, Vector2(0.0005, 0.002), 0.6)
	var c := O.vide(0.06, VIF)
	O.eclat(c, 0.0, 0.004, 1.0, r, VIF)
	O.bas(c, 3000.0, VIF)
	O.haut(c, 300.0, VIF)
	_mettre(s, c, tc, 1.0, VIF)
	O.mode(s, tc, 150.0, 0.03, 0.45, VIF, 0.7)
	O.mode(s, tc, 330.0, 0.016, 0.4, VIF, 0.8)
	O.mode(s, tc, 720.0, 0.007, 0.2, VIF, 0.85)
	_souffle(s, tc + 0.02, 0.3, 1100.0, 600.0, 0.8, 0.2, VIF, r, 0.15)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.055, CRETE)
	return O.bords(s, VIF)


# un piquet qu'on enfonce : trois coups de maillet. La terre le serre de plus en plus : le bois sonne moins, moins haut,
# et le coup dans le sol prend le dessus (de plus en plus sourd)
static func _piquet(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.72, VIF)
	var t := T0
	var k := r.randf_range(0.94, 1.06)
	for p in 3:
		var u := p * 0.5
		var b := O.vide(0.34, VIF)
		O.eclat(b, 0.0, lerpf(0.001, 0.0022, u), 1.0, r, VIF)
		var f := lerpf(560.0, 390.0, u) * k
		O.mode(b, 0.0004, f, lerpf(0.022, 0.013, u), 0.6, VIF, 0.97)
		O.mode(b, 0.0004, f * 2.4, lerpf(0.011, 0.005, u), lerpf(0.4, 0.14, u), VIF)
		O.mode(b, 0.0004, f * 4.3, 0.004, lerpf(0.22, 0.03, u), VIF)
		# (le coup dans le sol : son grave, et de quoi l'entendre sur un téléphone)
		O.mode(b, 0.0, lerpf(104.0, 82.0, u), lerpf(0.03, 0.045, u), lerpf(0.25, 0.5, u), VIF, 0.75)
		O.mode(b, 0.0, lerpf(430.0, 330.0, u), 0.024, lerpf(0.2, 0.5, u), VIF, 0.88)
		O.bas(b, lerpf(4600.0, 1500.0, u), VIF)
		_mettre(s, b, t, lerpf(1.0, 0.86, u), VIF)
		# (au rythme de son geste : les trois coups de « monter », scripts/joueur.gd, MONTER_COUPS)
		t += 0.18
	O.niveau(s, 0.07, CRETE)
	return O.bords(s, VIF)


# une corde qu'on tend : les brins roulent les uns sur les autres, par à-coups de plus en plus serrés ; on reprend, plus
# court, plus tendu (plus haut) ; puis elle tient
static func _corde(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.8, SOURD)
	var k := r.randf_range(0.93, 1.07)
	var a := _grince(0.42, 20.0, 58.0, [[540.0 * k, 6.0, 1.0], [1380.0 * k, 7.0, 0.55], [2350.0 * k, 6.0, 0.22]], 0.35, SOURD, r)
	O.enveloppe(a, 0.05, 0.1, SOURD)
	_mettre(s, a, 0.0, 0.8, SOURD)
	_souffle(s, 0.0, 0.4, 1300.0, 1700.0, 1.0, 0.1, SOURD, r, 0.5)
	var b := _grince(0.26, 44.0, 96.0, [[580.0 * k, 6.0, 1.0], [1470.0 * k, 7.0, 0.6], [2500.0 * k, 6.0, 0.25]], 0.3, SOURD, r)
	O.enveloppe(b, 0.03, 0.05, SOURD)
	_mettre(s, b, 0.5, 1.0, SOURD)
	O.niveau(s, 0.09, CRETE)
	return O.bords(s, SOURD)


# la ferraille d'un vestige, qu'on remue : la rouille qui s'effrite sous la main, et deux ou trois morceaux qui se cognent,
# sourds, vite éteints (la rouille mange la note), chacun à sa hauteur
static func _fouille(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.8, VIF)
	_grains(s, 0.0, 0.7, 26, 1700.0, 1.4, 0.3, VIF, r, Vector2(0.0004, 0.0015))
	_souffle(s, 0.0, 0.7, 650.0, 900.0, 0.8, 0.14, VIF, r, 0.35)
	var t := 0.015
	var coups := 3 if r.randf() < 0.6 else 2
	for p in coups:
		var f := r.randf_range(470.0, 800.0)
		var g := r.randf_range(0.65, 1.0) * (1.0 if p < 2 else 0.6)
		var c := O.vide(0.012, VIF)
		O.eclat(c, 0.0, 0.0005, 1.0, r, VIF)
		O.bande(c, 2400.0, 1.2, VIF)
		_mettre(s, c, t, 0.5 * g, VIF)
		var rapports := PackedFloat32Array([1.0, 1.52, 2.27, 3.05])
		var gains := PackedFloat32Array([0.8, 0.6, 0.4, 0.22])
		for j in 4:
			O.mode(s, t, f * rapports[j] * r.randf_range(0.97, 1.03), r.randf_range(0.02, 0.045) / (1.0 + 0.7 * j), g * gains[j], VIF)
		# (un partiel tout près du premier : ça bat, ça ne chante pas)
		O.mode(s, t, f * r.randf_range(1.04, 1.09), 0.03, g * 0.4, VIF)
		t += r.randf_range(0.2, 0.3)
	O.bas(s, 3800.0, VIF)
	O.niveau(s, 0.055, CRETE)
	return O.bords(s, VIF)


# --- l'eau ---

# l'eau qui entre dans l'outre : l'air en ressort par goulées (des « glou » dont la note monte à mesure qu'elle se
# remplit), de petites bulles autour, le filet d'eau ; la peau étouffe tout
static func _gourde(r: RandomNumberGenerator) -> PackedFloat32Array:
	var duree := 1.05
	var s := O.vide(duree, LENT)
	var n := s.size()
	O.bruit_bande(s, 1700.0, 0.8, 0.08, LENT, r)
	var t := 0.03
	while t < duree - 0.14:
		var u := t / duree
		var f := lerpf(330.0, 760.0, pow(u, 1.3)) * r.randf_range(0.92, 1.1)
		O.mode(s, t, f, r.randf_range(0.013, 0.02), r.randf_range(0.55, 1.0), LENT, r.randf_range(1.12, 1.3))
		for i in 2:
			O.mode(s, t + r.randf_range(0.01, 0.08), f * r.randf_range(2.2, 3.6), r.randf_range(0.003, 0.006), r.randf_range(0.15, 0.4), LENT, 1.2)
		t += r.randf_range(0.11, 0.16) * lerpf(1.0, 0.7, u)
	for i in n:
		var v := float(i) / LENT
		s[i] *= minf(1.0, v / 0.03) * minf(1.0, (duree - v) / 0.16)
	O.bas(s, 3000.0, LENT)
	O.niveau(s, 0.12, CRETE)
	return O.bords(s, LENT)


# deux gorgées : la gorge se ferme (un petit choc mouillé), l'eau descend (une note qui tombe), la gorge se rouvre (une
# bulle qui remonte) ; entre les deux, l'eau bouge dans la gourde
static func _gorgee(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.76, LENT)
	var t := 0.01
	for p in 2:
		var h := (1.0 - 0.07 * p) * r.randf_range(0.96, 1.04)
		var g := 1.0 - 0.18 * p
		var c := O.vide(0.02, LENT)
		O.eclat(c, 0.0, 0.0009, 1.0, r, LENT)
		O.bande(c, 1100.0 * h, 2.0, LENT)
		_mettre(s, c, t, 0.4 * g, LENT)
		O.mode(s, t + 0.008, 620.0 * h, 0.017, 0.8 * g, LENT, 0.6)
		O.mode(s, t + 0.008, 1300.0 * h, 0.008, 0.34 * g, LENT, 0.7)
		O.mode(s, t + 0.075, 390.0 * h, 0.02, 0.6 * g, LENT, 1.5)
		_souffle(s, t + 0.11, 0.17, 650.0, 950.0, 1.5, 0.1 * g, LENT, r, 0.3)
		t += r.randf_range(0.36, 0.42)
	O.bas(s, 3000.0, LENT)
	O.niveau(s, 0.085, CRETE)
	return O.bords(s, LENT)


# le bouillon qui frémit dans la popote (une tuile) : de petites bulles qui crèvent sans cesse, chacune une note brève
# qui monte, par bouffées ; un pétillement plus fin par-dessus ; la popote qui ronfle tout bas. Aucune bulle ne dépasse
# des autres : rien qu'on reconnaisse d'un tour à l'autre
static func _bouillon(r: RandomNumberGenerator) -> PackedFloat32Array:
	var d: Array = TUILES["bouillon"]
	var duree: float = d[0]
	var s := O.vide(duree, SOURD)
	O.bruit_bande(s, 480.0, 0.7, 0.2, SOURD, r)
	var p1 := r.randf() * TAU
	var p2 := r.randf() * TAU
	var t := 0.0
	while t < duree - 0.1:
		var bouffee := 0.82 + 0.12 * sin(t * 5.3 + p1) + 0.06 * sin(t * 13.1 + p2)
		O.mode(s, t, 300.0 * pow(3.2, r.randf()), r.randf_range(0.006, 0.014), (0.35 + 0.45 * r.randf()) * bouffee, SOURD, r.randf_range(1.1, 1.3))
		t += maxf(0.004, -log(maxf(r.randf(), 0.0001)) / (30.0 * bouffee))
	t = 0.0
	while t < duree - 0.03:
		O.mode(s, t, r.randf_range(1300.0, 3000.0), r.randf_range(0.0012, 0.003), r.randf_range(0.15, 0.42), SOURD, 1.1)
		t += maxf(0.002, -log(maxf(r.randf(), 0.0001)) / 95.0)
	O.niveau(s, 0.1)
	return O.tuile(s, d[1], SOURD)


# --- la lampe, le cerf-volant ---

# l'interrupteur de la lampe : un poussoir de ferraille. Il s'enfonce, il revient : deux petits chocs secs, la tôle du
# boîtier qui répond à peine
static func _clic(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.09, VIF)
	var k := r.randf_range(0.95, 1.05)
	for p in 2:
		var t := 0.002 + 0.03 * p
		var g := 1.0 - 0.45 * p
		var h := k * (1.0 + 0.12 * p)
		var c := O.vide(0.01, VIF)
		O.eclat(c, 0.0, 0.00035, 1.0, r, VIF)
		O.bande(c, 2700.0 * h, 1.8, VIF)
		_mettre(s, c, t, 0.8 * g, VIF)
		O.mode(s, t, 920.0 * h, 0.006, 0.25 * g, VIF)
		O.mode(s, t, 1850.0 * h, 0.004, 0.3 * g, VIF)
		O.mode(s, t, 3300.0 * h, 0.0025, 0.2 * g, VIF)
	O.niveau(s, 0.06, CRETE)
	return O.bords(s, VIF)


# le fil du cerf-volant qui chante au vent (une tuile) : le vent fait vibrer le fil tendu, une note de souffle, étroite,
# et son octave ; elle tremble (le vent du jeu la fait enfler : sons.gd). Sa hauteur erre un peu au milieu de la tuile et
# se tient aux deux bouts : là où deux tuiles se fondent, elles chantent la même note
static func _fil(r: RandomNumberGenerator) -> PackedFloat32Array:
	var d: Array = TUILES["fil"]
	var s := O.vide(d[0], SOURD)
	var n := s.size()
	# deux courbes lentes, à gros grain (un point tous les 32 échantillons) : où va la note, comment elle tremble
	const PAS := 32
	var nc := n / PAS + 2
	var ce := PackedFloat32Array()
	ce.resize(nc)
	O.bruit(ce, r)
	O.bas(ce, 0.6, SOURD / PAS)
	O.bas(ce, 0.6, SOURD / PAS)
	O.normaliser(ce, 1.0)
	var cm := PackedFloat32Array()
	cm.resize(nc)
	O.bruit(cm, r)
	O.bas(cm, 1.3, SOURD / PAS)
	O.bas(cm, 1.3, SOURD / PAS)
	O.normaliser(cm, 1.0)
	var i0 := int(float(d[1]) * SOURD)
	var milieu := maxi(1, n - 2 * i0)
	# deux résonances étroites sur le même bruit, en une seule boucle (recalculées à chaque point des courbes)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var z1 := 0.0
	var z2 := 0.0
	var b0 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var c0 := 0.0
	var c1 := 0.0
	var c2 := 0.0
	var am := 0.0
	var dam := 0.0
	var energie := 0.0
	var crete := 0.0
	for i in n:
		if i % PAS == 0:
			var k := i / PAS
			var u := sin(PI * clampf(float(i - i0) / milieu, 0.0, 1.0))
			var w := TAU * 590.0 * pow(2.0, ce[k] * 0.16 * u * u) / SOURD
			var al := sin(w) / 36.0
			var n0 := 1.0 + al
			b0 = al / n0
			a1 = -2.0 * cos(w) / n0
			a2 = (1.0 - al) / n0
			al = sin(2.0 * w) / 52.0
			n0 = 1.0 + al
			c0 = al / n0
			c1 = -2.0 * cos(2.0 * w) / n0
			c2 = (1.0 - al) / n0
			am = 0.8 + 0.2 * cm[k]
			dam = 0.2 * (cm[k + 1] - cm[k]) / PAS
		var x := r.randf_range(-1.0, 1.0)
		var y := b0 * (x - x2) - a1 * y1 - a2 * y2
		var z := c0 * (x - x2) - c1 * z1 - c2 * z2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		z2 = z1
		z1 = z
		var v := (y + 0.45 * z) * am
		am += dam
		s[i] = v
		energie += v * v
		crete = maxf(crete, absf(v))
	O.gain(s, minf(0.14 / maxf(sqrt(energie / n), 0.00001), 0.95 / maxf(crete, 0.00001)))
	return O.tuile(s, d[1], SOURD)


# les piles qui chargent : quelques étincelles au dévidoir, serrées puis éparses ; la plus grosse claque un peu ; l'air
# grésille dessous, à peine
static func _etincelle(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.2, VIF)
	var c := O.vide(0.2, VIF)
	for i in r.randi_range(5, 9):
		O.eclat(c, 0.003 + 0.15 * pow(r.randf(), 1.8), r.randf_range(0.00006, 0.00025), r.randf_range(0.3, 1.0), r, VIF)
	O.bande(c, r.randf_range(3000.0, 3800.0), 0.8, VIF)
	_mettre(s, c, 0.0, 0.9, VIF)
	O.mode(s, r.randf_range(0.003, 0.03), r.randf_range(1300.0, 1700.0), 0.0015, 0.3, VIF)
	_souffle(s, 0.0, 0.16, 2800.0, 3400.0, 1.5, 0.12, VIF, r, 0.15)
	O.niveau(s, 0.035, CRETE)
	return O.bords(s, VIF)


# une bête prise au filet, qui se débat : elle se jette contre les mailles (la corde racle, le corps cogne le sol), deux
# élans serrés, un répit, et elle recommence ; parfois une pierre de lest en heurte une autre. Aucune voix : on ne sait
# pas quelle bête c'est
static func _filet(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(1.05, VIF)
	var t := 0.0
	for p in 5:
		if t > 0.82:
			break
		var g := r.randf_range(0.55, 1.0)
		var d := r.randf_range(0.09, 0.15)
		_grains(s, t, d, r.randi_range(10, 16), r.randf_range(1300.0, 2100.0), 1.0, 0.75 * g, VIF, r, Vector2(0.0005, 0.002))
		_souffle(s, t, d + 0.04, 800.0, 1250.0, 1.0, 0.3 * g, VIF, r, 0.3)
		O.mode(s, t + 0.004, r.randf_range(150.0, 210.0), 0.02, 0.3 * g, VIF, 0.8)
		O.mode(s, t + 0.004, r.randf_range(340.0, 470.0), 0.012, 0.4 * g, VIF, 0.88)
		if r.randf() < 0.45:
			var tp := t + r.randf_range(0.03, 0.09)
			var f := r.randf_range(2000.0, 2700.0)
			O.mode(s, tp, f, 0.009, 0.22, VIF)
			O.mode(s, tp, f * 1.58, 0.005, 0.14, VIF)
		t += d + (r.randf_range(0.02, 0.06) if p % 2 == 0 else r.randf_range(0.1, 0.2))
	O.bas(s, 4400.0, VIF)
	O.niveau(s, 0.078, CRETE)
	return O.bords(s, VIF)


# --- la tenue ---

# une sangle de cuir qu'on serre : le cuir grince en passant dans la boucle, l'ardillon tombe dans son trou (un tic mat),
# un dernier coup sec pour serrer, et la sangle retombe contre le sac
static func _sangle(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.56, VIF)
	var k := r.randf_range(0.94, 1.06)
	var a := _grince(0.28, 34.0, 82.0, [[430.0 * k, 4.0, 1.0], [1150.0 * k, 5.0, 0.6], [2300.0 * k, 4.0, 0.2]], 0.5, VIF, r)
	O.enveloppe(a, 0.03, 0.07, VIF)
	_mettre(s, a, 0.0, 0.6, VIF)
	var c := O.vide(0.01, VIF)
	O.eclat(c, 0.0, 0.0003, 1.0, r, VIF)
	O.bande(c, 3000.0, 2.0, VIF)
	_mettre(s, c, 0.31, 0.55, VIF)
	O.mode(s, 0.31, 2400.0 * k, 0.006, 0.3, VIF)
	O.mode(s, 0.31, 3900.0 * k, 0.003, 0.15, VIF)
	_souffle(s, 0.335, 0.11, 900.0, 2000.0, 2.5, 0.5, VIF, r, 0.6)
	O.mode(s, 0.45, 240.0, 0.012, 0.3, VIF, 0.85)
	O.mode(s, 0.45, 520.0, 0.006, 0.2, VIF)
	O.bas(s, 5000.0, VIF)
	O.niveau(s, 0.095, CRETE)
	return O.bords(s, VIF)
