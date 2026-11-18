extends "res://scripts/sons_atelier.gd"
# Lisière — les sons du collet (scripts/sons_collet.gd)
# Ce qu'on entend de la fin de la Noire (scripts/noire_collet.gd), fait à la main comme tous les sons du jeu, avec les briques
# de l'atelier (scripts/sons_atelier.gd, dont ce fichier hérite : _souffle, _grains, _grince, _mettre) et la voix des bêtes
# (scripts/sons_recettes.gd, _voix) :
#  - collet_claque  : le nœud coulant qui se ferme. Le filin file dans son œil (un sifflement qui monte), claque, et mord ;
#  - collet_coup    : l'à-coup, quand elle arrive au bout du filin : il se tend d'un coup (un choc sourd, bas, qui porte), ses
#                     torons crient, le pieu cogne dans son trou, la terre s'égrène. Deux variantes ;
#  - collet_arrache : les pieux qui cèdent : le bois gémit, craque, sort de terre ; les pierres de lest roulent ;
#  - noire_cri      : son cri quand le nœud la prend, et quand la lance la blesse (plus haut) : rauque, bref, cassé en deux.
#                     Rien de son appel : pour la première fois, elle a une voix de bête ;
#  - noire_flaire   : elle flaire l'appât : deux reniflements courts, graves ;
#  - noire_renacle  : elle renâcle : un souffle chassé par les naseaux, qui bat ;
#  - dernier_appel  : son dernier appel. Pas celui qui enfle et tient : trois notes qui retombent, chacune plus loin, plus
#                     sourde, plus faible que la précédente, avec l'écho du lieu. Il s'éloigne.
# sons_atelier.gd les nomme (TAUX, NOMS, NIVEAUX) et les demande ici : fabriquer_collet(base, k, r) rend les échantillons.

const F := preload("res://scripts/sons_recettes.gd")


static func fabriquer_collet(base: String, k: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	match base:
		"collet_claque":
			return _claque(r)
		"collet_coup":
			return _a_coup(k, r)
		"collet_arrache":
			return _arrache(r)
		"noire_cri":
			return _cri_de_prise(r)
		"noire_flaire":
			return _flaire(r)
		"noire_renacle":
			return _renacle(r)
		"dernier_appel":
			return _dernier_appel(r)
	return PackedFloat32Array()


# le nœud qui se ferme : le filin file dans son œil (un sifflement de fibre, qui monte et s'accélère), puis il claque (un
# éclat sec) et mord (un coup mat, le corps du filin qui répond) ; un dernier crissement de torons qui se serrent
static func _claque(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.62, VIF)
	var k := r.randf_range(0.95, 1.05)
	_souffle(s, 0.0, 0.13, 1400.0 * k, 4200.0 * k, 2.2, 0.55, VIF, r, 0.85)
	_grains(s, 0.01, 0.11, 22, 2600.0, 1.2, 0.45, VIF, r, Vector2(0.0002, 0.0007), 0.6)
	var tc := 0.135
	var c := O.vide(0.02, VIF)
	O.eclat(c, 0.0, 0.0005, 1.0, r, VIF)
	O.bande(c, 3100.0 * k, 1.6, VIF)
	_mettre(s, c, tc, 0.95, VIF)
	O.mode(s, tc, 2300.0 * k, 0.007, 0.35, VIF)
	O.mode(s, tc + 0.004, 310.0 * k, 0.05, 0.75, VIF, 0.9)
	O.mode(s, tc + 0.004, 640.0 * k, 0.022, 0.4, VIF, 0.94)
	O.mode(s, tc + 0.006, 140.0, 0.07, 0.45, VIF, 0.85)
	var g := _grince(0.26, 70.0, 24.0, [[520.0 * k, 5.0, 1.0], [1250.0 * k, 6.0, 0.5], [2400.0 * k, 5.0, 0.2]], 0.35, VIF, r)
	O.enveloppe(g, 0.02, 0.16, VIF)
	_mettre(s, g, tc + 0.07, 0.4, VIF)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.1, CRETE)
	return O.bords(s, VIF)


# l'à-coup au bout du filin : il se tend d'un coup (un choc sourd, très bas : neuf cents kilos arrêtés net), ses torons crient
# (un grincement qui ralentit), le pieu cogne dans son trou (le bois, bref), la terre s'égrène autour.
# k : 0, un à-coup franc ; 1, plus lourd, le pieu qui joue davantage
static func _a_coup(k: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var lourd := k % 2 == 1
	var s := O.vide(0.9, SOURD)
	var q := r.randf_range(0.93, 1.07)
	var c := O.vide(0.03, SOURD)
	O.eclat(c, 0.0, 0.004, 1.0, r, SOURD)
	O.bas(c, 1400.0, SOURD)
	_mettre(s, c, T0, 0.8, SOURD)
	O.mode(s, T0, 96.0 * q, 0.11 if lourd else 0.08, 0.9, SOURD, 0.82)
	O.mode(s, T0, 250.0 * q, 0.06, 0.6, SOURD, 0.92)
	O.mode(s, T0, 430.0 * q, 0.03, 0.4, SOURD, 0.95)
	# (ses torons : ils crient en se serrant, puis se taisent)
	var g := _grince(0.42, 85.0, 16.0, [[360.0 * q, 5.0, 1.0], [880.0 * q, 6.0, 0.55], [1700.0 * q, 6.0, 0.22]], 0.3, SOURD, r)
	O.enveloppe(g, 0.01, 0.3, SOURD)
	_mettre(s, g, 0.02, 0.6, SOURD)
	# (le pieu, dans son trou : un ou deux coups de bois)
	var tp := 0.05
	for i in (2 if lourd else 1):
		var fb := r.randf_range(480.0, 640.0)
		O.mode(s, tp, fb, 0.016, 0.45, SOURD, 0.96)
		O.mode(s, tp, fb * 1.9, 0.008, 0.2, SOURD)
		tp += r.randf_range(0.09, 0.14)
	# (la terre qui s'égrène)
	_grains(s, 0.08, 0.5, 26 if lourd else 16, 1500.0, 0.8, 0.22, SOURD, r, Vector2(0.0006, 0.002), 1.7)
	O.niveau(s, 0.1, CRETE)
	return O.bords(s, SOURD)


# les pieux qui cèdent : le bois gémit sous le filin (un grincement qui monte), craque, et sort de terre d'un coup (un souffle
# bas, des mottes) ; deux ou trois pierres de lest roulent et se heurtent ; le filin fouette l'air en partant
static func _arrache(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(1.25, VIF)
	var k := r.randf_range(0.95, 1.05)
	var g := _grince(0.3, 22.0, 95.0, [[460.0 * k, 4.0, 1.0], [1100.0 * k, 5.0, 0.6], [2100.0 * k, 5.0, 0.25]], 0.4, VIF, r)
	O.enveloppe(g, 0.06, 0.03, VIF)
	_mettre(s, g, 0.0, 0.55, VIF)
	var tc := 0.3
	# (le bois qui craque : trois éclats serrés, ses fibres)
	var c := O.vide(0.08, VIF)
	var t := 0.0
	for i in 3:
		O.eclat(c, t, r.randf_range(0.0004, 0.0009), r.randf_range(0.6, 1.0), r, VIF)
		t += r.randf_range(0.006, 0.02)
	O.bande(c, 2400.0 * k, 1.3, VIF)
	_mettre(s, c, tc, 0.9, VIF)
	O.mode(s, tc, 620.0 * k, 0.02, 0.5, VIF, 0.9)
	O.mode(s, tc, 1350.0 * k, 0.01, 0.3, VIF)
	# (il sort de terre : la motte qui cède, la terre qui retombe)
	O.mode(s, tc + 0.02, 110.0, 0.09, 0.8, VIF, 0.75)
	_souffle(s, tc + 0.01, 0.32, 520.0, 260.0, 0.8, 0.5, VIF, r, 0.15)
	_grains(s, tc + 0.08, 0.6, 40, 1300.0, 0.8, 0.3, VIF, r, Vector2(0.0006, 0.0022), 1.8)
	# (les pierres de lest : elles roulent, se heurtent)
	var tp := tc + 0.16
	for i in r.randi_range(2, 3):
		var f := r.randf_range(1900.0, 2700.0)
		O.mode(s, tp, f, 0.009, 0.3, VIF)
		O.mode(s, tp, f * 1.52, 0.005, 0.18, VIF)
		O.mode(s, tp + 0.002, 240.0, 0.02, 0.25, VIF, 0.9)
		tp += r.randf_range(0.11, 0.22)
	# (le filin qui part avec elle)
	_souffle(s, tc + 0.04, 0.2, 900.0, 2600.0, 2.0, 0.3, VIF, r, 0.7)
	O.bas(s, 5200.0, VIF)
	O.niveau(s, 0.1, CRETE)
	return O.bords(s, VIF)


# son cri, quand le nœud la prend : rauque, bref, qui part haut et se casse (un hoquet), puis retombe en râle. Une voix de
# bête, enfin : c'est ce qui dit qu'elle peut avoir mal
static func _cri_de_prise(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(1.5, SOURD)
	var a := F._voix(0.5, 128.0, 104.0, [[560.0, 3.0, 1.0], [1250.0, 4.0, 0.7], [2300.0, 5.0, 0.3]], 0.6, SOURD, r)
	O.enveloppe(a, 0.03, 0.12, SOURD)
	_mettre(s, a, 0.0, 0.95, SOURD)
	# (elle se casse : un blanc, puis le râle, plus bas, qui tombe)
	var b := F._voix(0.82, 92.0, 46.0, [[400.0, 3.0, 1.0], [900.0, 4.0, 0.55], [1800.0, 5.0, 0.2]], 0.7, SOURD, r)
	var n := b.size()
	var ph := r.randf() * TAU
	for i in n:
		var u := float(i) / n
		ph += TAU * lerpf(11.0, 6.0, u) / SOURD
		b[i] *= minf(1.0, u / 0.06) * pow(1.0 - u, 1.4) * (0.7 + 0.3 * sin(ph))
	_mettre(s, b, 0.56, 0.8, SOURD)
	# (le souffle qui sort avec)
	_souffle(s, 0.0, 0.5, 1500.0, 900.0, 1.2, 0.2, SOURD, r, 0.2)
	O.bas(s, 3400.0, SOURD)
	O.normaliser(s, 0.92)
	return O.bords(s, SOURD)


# elle flaire : deux reniflements courts, graves, l'air tiré par de larges naseaux
static func _flaire(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.62, LENT)
	var k := r.randf_range(0.94, 1.06)
	_souffle(s, 0.0, 0.2, 420.0 * k, 980.0 * k, 1.8, 0.8, LENT, r, 0.75)
	_souffle(s, 0.0, 0.2, 1500.0 * k, 2200.0 * k, 2.4, 0.2, LENT, r, 0.75)
	_souffle(s, 0.3, 0.26, 380.0 * k, 1100.0 * k, 1.8, 1.0, LENT, r, 0.8)
	_souffle(s, 0.3, 0.26, 1400.0 * k, 2400.0 * k, 2.4, 0.25, LENT, r, 0.8)
	O.niveau(s, 0.07, CRETE)
	return O.bords(s, LENT)


# elle renâcle : un souffle chassé d'un coup par les naseaux, qui bat (les lèvres, les narines), et un reste de gorge
static func _renacle(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(0.75, SOURD)
	var b := O.vide(0.5, SOURD)
	O.bruit(b, r)
	O.bande(b, 620.0, 0.9, SOURD)
	var n := b.size()
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		ph += TAU * lerpf(34.0, 21.0, u) / SOURD
		b[i] *= minf(1.0, u / 0.03) * pow(1.0 - u, 1.2) * (0.45 + 0.55 * maxf(0.0, sin(ph)))
	_mettre(s, b, 0.0, 0.95, SOURD)
	_souffle(s, 0.0, 0.3, 1900.0, 1100.0, 1.4, 0.3, SOURD, r, 0.12)
	var g := F._voix(0.3, 60.0, 44.0, [[300.0, 3.0, 1.0], [760.0, 4.0, 0.4]], 0.5, SOURD, r)
	O.enveloppe(g, 0.04, 0.2, SOURD)
	_mettre(s, g, 0.12, 0.35, SOURD)
	O.niveau(s, 0.1, CRETE)
	return O.bords(s, SOURD)


# son dernier appel. Celui des nuits enflait lentement et tenait ; celui-ci retombe : trois notes, chacune plus loin que la
# précédente (plus sourde, plus faible, plus brève), et l'écho du lieu derrière chacune. On entend qu'elle s'en va
static func _dernier_appel(r: RandomNumberGenerator) -> PackedFloat32Array:
	var s := O.vide(8.6, SOURD)
	var debut := 0.0
	var notes := [[3.1, 50.0, 35.0, 1500.0, 1.0], [2.4, 45.0, 32.0, 950.0, 0.5], [1.9, 41.0, 30.0, 620.0, 0.24]]
	for q in notes:
		var duree: float = q[0]
		var v := F._voix(duree, float(q[1]), float(q[2]), [[225.0, 3.0, 1.0], [500.0, 4.0, 0.55], [980.0, 5.0, 0.18]], 0.3, SOURD, r)
		var n := v.size()
		for i in n:
			var u := float(i) / n
			# (elle part d'un coup, et tombe longtemps : pas de tenue, pas de battement)
			v[i] *= minf(1.0, u / 0.07) * pow(1.0 - u, 1.25)
		O.bas(v, float(q[3]), SOURD)
		O.normaliser(v, 0.9)
		O.poser(s, v, int(debut * SOURD), float(q[4]))
		# (l'écho du lieu : deux retours, plus sourds)
		var e := v.duplicate()
		O.bas(e, float(q[3]) * 0.55, SOURD)
		O.poser(s, e, int((debut + 0.34) * SOURD), float(q[4]) * 0.3)
		O.bas(e, float(q[3]) * 0.4, SOURD)
		O.poser(s, e, int((debut + 0.71) * SOURD), float(q[4]) * 0.15)
		debut += duree - 0.25
	O.normaliser(s, 0.9)
	return O.bords(s, SOURD)
