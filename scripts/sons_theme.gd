extends RefCounted
# Lisière — le thème de l'écran-titre (scripts/sons_theme.gd)
# Une berceuse à trois temps, en ré mineur, d'une quarantaine de secondes, qui revient : un chant de flûte, lié (les notes
# glissent l'une dans l'autre, un souffle les porte, un vibrato vient aux notes tenues), sur des cordes pincées en arpèges,
# et un écho qui les fond. Seize mesures : quatre phrases de quatre ; la troisième monte, la quatrième redescend et pose.
# Le morceau est fait d'un seul tenant, en une fois, puis joué tel quel : sa mesure ne dépend pas des images du jeu (un
# thème joué note à note, image par image, boite dès qu'une image tarde). Il se fabrique par petits pas (Chantier.avancer),
# pour ne pas figer l'écran-titre ; sons.gd le garde ensuite sur le disque (user://), pour les fois suivantes.

const O := preload("res://scripts/sons_outils.gd")
const VERSION := 2                 # à changer quand le morceau change : la copie gardée sur le disque est refaite
const TAUX := O.LENT
const TEMPS := 0.8                 # un temps : 75 à la minute
const MESURE := 3.0 * TEMPS
const MESURES := 16
const DUREE := MESURES * MESURE    # le morceau
const QUEUE := 3.0                 # ce qui sonne encore après sa dernière mesure
const PERIODE := DUREE + MESURE    # il reprend après une mesure de souffle
const NIVEAU := -6.0               # son niveau (dB), sur le bus de la musique

# le chant : quatre phrases ; chaque note [hauteur (en demi-tons, le la 440 vaut 69 ; -1 : un silence), temps]
const CHANT := [
	[[69, 2.0], [74, 1.0], [77, 2.0], [76, 0.5], [74, 0.5], [72, 1.0], [77, 1.0], [81, 1.0], [79, 2.0], [76, 0.7], [-1, 0.3]],
	[[77, 2.0], [74, 1.0], [70, 1.0], [74, 1.0], [77, 1.0], [79, 1.5], [77, 0.5], [74, 1.0], [76, 2.5], [-1, 0.5]],
	[[81, 2.0], [79, 1.0], [76, 1.0], [79, 1.0], [84, 1.0], [82, 1.5], [81, 0.5], [79, 1.0], [81, 2.5], [-1, 0.5]],
	[[77, 1.0], [74, 1.0], [70, 1.0], [67, 1.0], [70, 1.0], [74, 1.0], [76, 2.0], [73, 1.0], [74, 3.0]],
]
# les cordes : un accord par mesure, égrené en six croches (la basse, puis l'accord qui monte et retombe)
const ACCORDS := {
	"re": [50, 57, 62, 65, 57, 65], "sib": [46, 53, 58, 62, 53, 62], "fa": [53, 60, 65, 69, 60, 69], "do": [48, 55, 60, 64, 55, 64],
	"sol": [55, 62, 67, 70, 62, 70], "la": [45, 52, 57, 61, 52, 61], "la4": [45, 52, 57, 62, 52, 61], "fin": [50, 57, 62, 65, 69, -1],
}
const GRILLE := ["re", "sib", "fa", "do", "re", "sib", "sol", "la", "fa", "do", "sol", "re", "sib", "sol", "la4", "fin"]
const POIDS := [1.0, 0.5, 0.62, 0.58, 0.46, 0.55]     # la force de chaque croche de la mesure
const CORDE := 1.25                # secondes : ce que dure une corde pincée
const ECHO := 0.75 * TEMPS         # l'écho : une croche pointée
const ECHO_GAIN := 0.3


# le nom du fichier où le morceau est gardé (16 bits, à TAUX)
static func fichier() -> String:
	return "user://theme_%d_%d.pcm" % [VERSION, TAUX]


# le morceau, fait pas à pas : avancer(budget) travaille au plus ce temps-là (en microsecondes), et rend vrai quand c'est fini
class Chantier:
	var s: PackedFloat32Array
	var pcm := PackedByteArray()
	var fini := false
	var _etape := 0
	var _k := 0
	var _r := RandomNumberGenerator.new()
	var _hauteurs: Array = []
	var _cordes := {}
	var _poses: Array = []          # [échantillon, hauteur, gain]
	var _notes: Array = []          # [début, fin, fréquence, début de sa phrase, fin de sa phrase, première de sa phrase]
	var _table: PackedFloat32Array
	var _note := 0
	var _ph := 0.0
	var _f := 440.0
	var _souffle := 0.0
	var _passe := 0.0
	var _crete := 0.0

	static func frequence(m: int) -> float:
		return 440.0 * pow(2.0, (m - 69) / 12.0)

	func _init() -> void:
		_r.seed = 7
		s = O.vide(DUREE + QUEUE, TAUX)
		_table = O.table([[1.0, 1.0], [2.0, 0.2], [3.0, 0.085], [4.0, 0.03]])
		var c := 0.0
		for x in _table:
			c = maxf(c, absf(x))
		for i in _table.size():
			_table[i] /= c
		# les cordes : où, lesquelles
		var vues := {}
		for b in MESURES:
			var accord: Array = ACCORDS[GRILLE[b]]
			for e in 6:
				var m: int = accord[e]
				if m < 0:
					continue
				vues[m] = true
				var t := b * MESURE + e * TEMPS * 0.5 + (0.0 if e == 0 else _r.randf_range(-0.006, 0.008))
				# (la dernière mesure ralentit, et s'efface)
				if b == MESURES - 1:
					t = b * MESURE + e * TEMPS * 0.5 * (1.0 + 0.09 * e)
				_poses.append([int(t * TAUX), m, 0.34 * float(POIDS[e]) * _r.randf_range(0.9, 1.08) * (0.8 if b == MESURES - 1 else 1.0)])
		_hauteurs = vues.keys()
		_hauteurs.sort()
		# le chant : ses notes, dans le temps
		var t0 := 0.0
		for phrase in CHANT:
			var debut := t0
			var fin := t0
			var d := t0
			for n in phrase:
				d += float(n[1]) * TEMPS
				if int(n[0]) >= 0:
					fin = d
			var premiere := true
			for n in phrase:
				var t1 := t0 + float(n[1]) * TEMPS
				if int(n[0]) >= 0:
					_notes.append([t0, t1, frequence(int(n[0])), debut, fin, premiere])
					premiere = false
				t0 = t1

	func avancer(budget_us: int) -> bool:
		var fin := Time.get_ticks_usec() + budget_us
		while not fini:
			match _etape:
				0:
					_corde()
				1:
					_poser()
				2:
					_chanter(1024)
				3:
					_echo(4096)
				4:
					_mesurer(8192)
				5:
					_regler(8192)
				6:
					_coder(8192)
			if Time.get_ticks_usec() >= fin:
				break
		return fini

	func _suite() -> void:
		_etape += 1
		_k = 0

	# une corde pincée par hauteur : des partiels qui s'éteignent, les aigus d'abord (les graves ont plus d'harmoniques : un
	# téléphone ne rend rien sous 200 Hz, c'est par elles qu'on les entend). Un partiel par pas
	func _corde() -> void:
		var m: int = _hauteurs[_k / 4]
		var p := _k % 4
		if p == 0:
			_cordes[m] = O.vide(CORDE, TAUX)
		var f := frequence(m)
		var grave := clampf((57.0 - m) / 12.0, 0.0, 1.0)
		var amp: float = [1.0, lerpf(0.28, 0.75, grave), lerpf(0.1, 0.4, grave), lerpf(0.035, 0.16, grave)][p]
		var tau: float = [0.52, 0.34, 0.2, 0.12][p]
		if f * (p + 1) < TAUX * 0.45:
			_cordes[m] = O.mode(_cordes[m], 0.0, f * (p + 1) * (1.0 + 0.0006 * p * p), tau, amp, TAUX)
		if p == 3:
			# (le doigt sur la corde : une attaque douce, pas un claquement)
			var c: PackedFloat32Array = _cordes[m]
			var n := int(0.004 * TAUX)
			for i in n:
				c[i] *= float(i) / n
			var q := int(0.12 * TAUX)
			for i in q:
				c[c.size() - 1 - i] *= float(i) / q
			O.normaliser(c, 1.0)
			_cordes[m] = c
		_k += 1
		if _k >= _hauteurs.size() * 4:
			_suite()

	func _poser() -> void:
		var e: Array = _poses[_k]
		O.poser(s, _cordes[e[1]], e[0], e[2])
		_k += 1
		if _k >= _poses.size():
			_cordes.clear()
			_suite()

	# le chant : une voix de flûte, d'un seul souffle par phrase. La hauteur glisse d'une note à l'autre ; entre deux notes
	# liées, le souffle fléchit à peine ; une note tenue enfle, et son vibrato vient avec le temps
	func _chanter(n: int) -> void:
		var total := int(DUREE * TAUX)
		var glisse := 1.0 - exp(-1.0 / (0.028 * TAUX))
		var i1 := mini(total, _k + n)
		for i in range(_k, i1):
			var t := float(i) / TAUX
			while _note < _notes.size() - 1 and t >= float(_notes[_note][1]):
				_note += 1
			var e: Array = _notes[_note]
			var t0: float = e[0]
			var t1: float = e[1]
			if t < t0 or t >= float(e[4]):
				# (entre deux phrases : elle reprend son souffle)
				if bool(e[5]):
					_f = float(e[2]) * 0.982
				continue
			_f += (float(e[2]) - _f) * glisse
			var a := minf(1.0, (t - float(e[3])) / 0.09) * minf(1.0, (float(e[4]) - t) / 0.3)
			a = a * a * (3.0 - 2.0 * a)
			# (l'articulation : un creux bref au passage d'une note à l'autre)
			var u0 := (t - t0) / 0.026
			var u1 := (t1 - t) / 0.026
			var lie := 1.0
			if not bool(e[5]):
				lie -= 0.2 * exp(-u0 * u0)
			if t1 < float(e[4]) - 0.01:
				lie -= 0.2 * exp(-u1 * u1)
			var tenue := t1 - t0
			var enfle := 1.0 + 0.13 * sin(PI * (t - t0) / tenue) if tenue > 1.2 else 1.0
			var vib := 0.0055 * smoothstep(0.3, 0.85, t - t0) * sin(TAU * 5.2 * t)
			_ph += _f * (1.0 + vib) / TAUX
			_ph -= floorf(_ph)
			var p := _ph * O.TABLE
			var j := int(p)
			var x: float = _table[j] + (_table[j + 1] - _table[j]) * (p - j)
			# (le souffle : un bruit doux sous la note, plus fort à l'attaque de la phrase)
			_souffle += (_r.randf_range(-1.0, 1.0) - _souffle) * 0.42
			var air := _souffle * (0.022 + 0.09 * exp(-(t - float(e[3])) / 0.035))
			# (les notes hautes chantent moins fort : une flûte qui monte ne doit pas percer)
			var doux := 1.0 - 0.32 * clampf((_f - 587.0) / 460.0, 0.0, 1.0)
			s[i] += (x * lie * enfle * doux + air) * a * 0.3
		_k = i1
		if _k >= total:
			_suite()

	# l'écho : chaque note revient, une croche pointée plus tard, plus sombre et plus faible ; c'est lui qui fond les cordes
	func _echo(n: int) -> void:
		var d := int(ECHO * TAUX)
		var i0 := maxi(_k, d)
		var i1 := mini(s.size(), i0 + n)
		for i in range(i0, i1):
			_passe += (s[i - d] - _passe) * 0.5
			s[i] += _passe * ECHO_GAIN
		_k = i1
		if _k >= s.size():
			_suite()

	func _mesurer(n: int) -> void:
		var i1 := mini(s.size(), _k + n)
		for i in range(_k, i1):
			_crete = maxf(_crete, absf(s[i]))
		_k = i1
		if _k >= s.size():
			_suite()

	# le niveau, et ses bords : il naît et s'éteint sans claquer
	func _regler(n: int) -> void:
		var g := 0.84 / maxf(_crete, 0.001)
		var total := s.size()
		var bord := int(0.9 * TAUX)
		var i1 := mini(total, _k + n)
		for i in range(_k, i1):
			var k := g
			if i > total - bord:
				k *= float(total - i) / bord
			s[i] *= k
		_k = i1
		if _k >= total:
			_suite()

	# en 16 bits, comme un lecteur le veut (et comme il est gardé sur le disque)
	func _coder(n: int) -> void:
		if _k == 0:
			pcm.resize(s.size() * 2)
		var i1 := mini(s.size(), _k + n)
		for i in range(_k, i1):
			pcm.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
		_k = i1
		if _k >= s.size():
			fini = true


# la taille du morceau, en octets (16 bits)
static func octets() -> int:
	return maxi(1, int((DUREE + QUEUE) * TAUX)) * 2


# un lecteur le joue tel quel
static func flux(pcm: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAUX
	w.stereo = false
	w.data = pcm
	return w


# le morceau, d'un coup (l'essai, les outils)
static func fabriquer() -> PackedFloat32Array:
	var c := Chantier.new()
	while not c.avancer(1000000):
		pass
	return c.s
