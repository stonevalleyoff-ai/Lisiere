extends RefCounted
# Lisière — un hexapode, dessiné à l'encre (scripts/bestiaire_hexapode.gd)
# Une bête à six pattes (parfois huit), de profil, tournée vers la droite, d'après le plan de corps de sa lignée (p.corps) : pas
# de poil, de la chitine. Trois masses qui se lisent : la tête, le thorax (où tiennent les pattes), l'abdomen. Le plan dit le
# reste : long (trapu ou élancé), haut (la garde au sol), tete, cou (un prothorax qui se dresse : une mante), museau (un rostre
# chez un brouteur, une tête plus longue chez un chasseur), queue (des cerques qui traînent, ou une queue relevée, en pince),
# cornes (la corne d'un scarabée, ou de plus grandes mandibules chez un chasseur), crete (des pointes le long du dos), oreilles
# (un éperon au corselet), antennes, carapace (des élytres et un corselet : les pattes sortent dessous ; courts, ils laissent
# l'abdomen nu ; sans eux, le corps est annelé), ailes (repliées sur le dos), et ses organes (aiguillon, pinces, antennes
# plumeuses, carapace segmentée, épines, collerette…). Son régime fait son caractère : un brouteur est rond, bombé, la tête
# rentrée, les pattes sous lui ; un chasseur est bas, long, anguleux, les mandibules ouvertes, les pattes de devant ravisseuses,
# les genoux hauts. Huit pattes : une « araignée » (pas d'antennes, des crochets, des yeux en rang, les genoux par-dessus le dos).
# Elle dessine sur la planche p (scripts/bestiaire_planche.gd), dans quatre calques : la queue (les cerques, l'aiguillon), le
# corps (le thorax et l'abdomen), le dessus (les élytres, le corselet, les ailes, les hanches : ce qui passe devant les pattes
# proches), la tête (qui pivote au bord du thorax, avec ses antennes, ses mandibules, ses pinces).

const Planche := preload("res://scripts/bestiaire_planche.gd")
# vers où va chaque pied, de la patte de devant à celle de derrière (1 : loin devant, -1 : loin derrière)
const VERS := {2: [1.0, -1.0], 3: [1.0, 0.1, -1.0], 4: [1.0, 0.45, -0.35, -1.0], 5: [1.0, 0.5, 0.0, -0.5, -1.0]}


# ce qu'on mesure une fois, et que chaque partie lit : d'abord sans échelle, puis en pixels montrés
class Mesures:
	var n := 3                  # les pattes de chaque côté
	var arach := false          # huit pattes : la tête et le thorax d'un seul bloc, pas d'antennes
	var fer := 0.0              # de 0 (un brouteur, rond) à 1 (un chasseur, bas et anguleux)
	var chasse := false
	var herbi := false
	var course := false
	var saut := false
	var rampe := false          # elle rampe seulement : au ras du sol, les pattes courtes
	var petit := false          # moins de 46 pixels : la silhouette, l'œil, deux ou trois traits
	var grand := false          # plus de 80 : du détail
	var rob := 0.4
	var e := 1.3                # le trait d'encre
	var cara := 0.0             # la carapace (0 : le corps nu, annelé)
	var anneaux := false        # une carapace segmentée
	var couv := 1.0             # ce que les élytres couvrent de l'abdomen (courts : un staphylin)
	var ailes := 0.0
	var haut := 0.2
	var queue := 0.0
	var cornes := 0.0
	var museau := 0.3
	var antennes := 0.0
	var aiguillon := 0.0        # la longueur de la queue à dard (0 : pas d'aiguillon)
	var courbe := false         # relevé par-dessus le dos (un scorpion) ; sinon droit (une guêpe)
	var pinces := 0.0           # la longueur des pinces
	var lc := 0.0               # le corps : le thorax et l'abdomen
	var lth := 0.0
	var lab := 0.0
	var th := 0.0               # l'épaisseur de l'abdomen
	var hth := 0.0              # celle du thorax
	var hs := 0.0               # la tête : sa hauteur
	var lhd := 0.0              # sa longueur
	var hl := 0.0               # la garde au sol
	var cl := 0.0               # le « cou » : un prothorax allongé
	var dresse := 0.0           # il se dresse (une mante)
	var md := 0.0               # les mandibules
	var rostre := 0.0
	var la := 0.0               # les antennes
	var tl := 0.0               # la queue
	var env := 0.0              # jusqu'où va un pied, de sa hanche
	var xr := 0.0               # le bout de l'abdomen
	var xj := 0.0               # la jonction du thorax et de l'abdomen
	var xa := 0.0               # l'avant du thorax
	var yb := 0.0               # le milieu de l'abdomen
	var yt := 0.0               # celui du thorax
	var haut_dos := 0.0         # le haut du dos
	var dome := 0.0             # le dos bombé
	var bosse := 0.0            # le corselet bombé
	var pointu := 0.0           # l'abdomen : rond (0) ou en pointe (1)
	var taille := 0.0           # la taille de guêpe
	var rim := 0.0              # le bord bas de la carapace : les pattes proches sortent dessous
	var genou := 0.0            # la hauteur des genoux, de 0 (au bord de la carapace) à 1 (au dos)
	var sous := false           # les pattes sortent de sous la carapace : le genou bas, la cuisse le long de son bord
	var col := Vector2.ZERO     # où la tête tient au corps
	var o := Vector2.ZERO       # le milieu de la tête
	var t_coque := Color.WHITE
	var t_corselet := Color.WHITE
	var t_tete := Color.WHITE
	var t_dessous := Color.WHITE
	var t_patte := Color.WHITE
	var t_patte_loin := Color.WHITE

	# toutes les longueurs, mises à l'échelle
	func agrandir(u: float) -> void:
		for k in ["lc", "lth", "lab", "th", "hth", "hs", "lhd", "hl", "cl", "md", "rostre", "la", "tl", "env", "aiguillon", "pinces"]:
			set(k, float(get(k)) * u)

	# les repères, d'après les longueurs : le bout de l'abdomen est à x = xr
	func poser(x_bout: float) -> void:
		xr = x_bout
		xj = xr + lab
		xa = xr + lc
		yb = -(hl + th * 0.5)
		yt = yb + (th - hth) * 0.35
		dome = th * ((0.1 + 0.3 * cara) * (1.0 - 0.7 * fer) if cara > 0.0 else 0.05 * (1.0 - fer))
		bosse = hth * (0.2 if arach else lerpf(0.16, 0.05, fer))
		haut_dos = yb - th * 0.5 - dome
		# (le bord de la carapace : bas sur le flanc d'un brouteur, un couvercle plat chez un chasseur, dont les genoux montent)
		rim = yb + th * (clampf(lerpf(0.12, -0.16, fer) + (cara - 0.5) * 0.2 * (1.0 - fer), -0.2, 0.24) if cara > 0.0 else 0.12)
		var angle := dresse * 1.05
		var base := Vector2(xa - lth * 0.02, yt - hth * lerpf(0.04, 0.14, fer))
		col = base + Vector2(cos(angle), -sin(angle)) * cl
		o = col + Vector2(lhd * 0.4, hs * lerpf(0.2, -0.08, fer))
		if arach:
			o = col + Vector2(lhd * 0.28, hs * 0.14)


static func dessiner(p) -> void:
	var m := _mesurer(p)
	p.ombre((m.xr + m.xa) * 0.5 + m.lhd * 0.2, m.lc * 0.52 + m.lhd * 0.3)
	_queue(p, m)
	_pattes(p, m, true)
	_corps(p, m)
	_pattes(p, m, false)
	_dessus(p, m)
	_tete(p, m)


# un organe de la lignée (plan.corps.organes), ou {} ; un corps d'avant le dit en proportion (au-delà de 0,2)
static func _organe(c: Dictionary, type: String, place := "") -> Dictionary:
	var liste = c.get("organes", null)
	if typeof(liste) == TYPE_ARRAY:
		for og in liste:
			if typeof(og) == TYPE_DICTIONARY and str(og.get("type", "")) == type and (place == "" or str(og.get("place", place)) == place):
				return og
	if type in ["cornes", "ailes", "carapace", "antennes"] or (type == "crete" and place != "tete"):
		var v := float(c.get(type, 0.0))
		if v >= 0.2:
			return {"type": type, "taille": v, "forme": ""}
	return {}


static func _taille(og: Dictionary) -> float:
	return clampf(float(og.get("taille", 0.5)), 0.05, 1.0) if not og.is_empty() else 0.0


# une courbe à trois points (départ, tirant, arrivée), en k segments
static func _courbe(a: Vector2, b: Vector2, c: Vector2, k := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in k + 1:
		var t := float(i) / k
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return pts


# un reflet : un trait clair sur la chitine, là où elle tourne vers la lumière
static func _reflet(p, pts: PackedVector2Array, w := 0.85, a := 0.8) -> void:
	p.tracer(Planche.ouvert(pts), maxf(0.8, p.e * w), p.tons["lumiere"], a)


# --- les mesures : d'abord sans échelle (u = 1), puis mises à la largeur de la planche ---

static func _mesurer(p) -> Mesures:
	var m := Mesures.new()
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var loco: Array = p.locomotion
	var L: float = p.L
	m.e = p.e
	m.rob = p.robustesse
	m.n = clampi(int(round(float(c.get("pattes", 6)) / 2.0)), 2, 5)
	m.arach = m.n >= 4
	m.chasse = p.chasseur
	m.herbi = p.regime == "herbivore"
	m.fer = 1.0 if m.chasse else (0.0 if m.herbi else 0.4)
	m.course = loco.has("course")
	m.saut = loco.has("saut")
	m.rampe = loco.has("reptation") and not (loco.has("marche") or m.course or m.saut) and not m.arach
	m.petit = L < 46.0
	m.grand = L >= 80.0
	var fer := m.fer
	var long := float(c.get("long", 0.5))
	var tete := float(c.get("tete", 0.4))
	var cou := float(c.get("cou", 0.0))
	m.haut = float(c.get("haut", 0.2))
	m.museau = float(c.get("museau", 0.3))
	m.queue = float(c.get("queue", 0.0))
	m.cornes = _taille(_organe(c, "cornes"))
	var og_cara := _organe(c, "carapace")
	m.cara = _taille(og_cara) if _taille(og_cara) >= 0.25 else 0.0
	m.anneaux = str(og_cara.get("forme", "")) == "segmentee"
	# (des élytres courts chez un chasseur à petite carapace : l'abdomen dépasse, nu)
	m.couv = clampf((m.cara - 0.15) / 0.45, 0.5, 1.0) if m.chasse and not m.anneaux else 1.0
	m.ailes = _taille(_organe(c, "ailes"))
	m.antennes = maxf(_taille(_organe(c, "antennes")), float(c.get("antennes", 0.0)))
	# le corps
	m.lc = 0.42 + 0.26 * long
	var ft := lerpf(0.32, 0.36, fer) if m.cara > 0.0 else lerpf(0.44, 0.48, fer)
	m.th = (0.215 + 0.06 * m.rob - 0.045 * long) * lerpf(1.2, 1.05, fer)
	m.hth = m.th * lerpf(0.82, 0.9, fer)
	if m.arach:
		m.lc = 0.4 + 0.2 * long
		ft = 0.44
		m.th *= 1.15
		m.hth = m.th * 0.68
	m.lth = m.lc * ft
	m.lab = m.lc - m.lth
	m.hs = (0.13 + 0.07 * tete) * lerpf(1.08, 0.84, m.rob) * (0.92 if m.herbi else 1.0)
	m.lhd = m.hs * (lerpf(0.95, 1.05, fer) + (0.3 * m.museau if m.chasse else 0.0))
	m.hl = (0.085 + 0.24 * m.haut) * lerpf(1.0, 0.92, fer) * (1.2 if p.traits.has("pattes-longues") else 1.0) * (0.5 if m.rampe else 1.0)
	m.cl = m.lc * 0.5 * maxf(0.0, cou - 0.08) * (0.0 if m.arach else 1.0)
	m.dresse = clampf((cou - 0.08) * 1.25, 0.0, 1.0) * lerpf(0.3, 1.0, fer) * (0.0 if m.arach else 1.0)
	m.env = m.lc * (0.2 + 0.1 * fer + 0.14 * m.haut + (0.03 if m.course else 0.0)) * (0.7 if m.rampe else 1.0)
	if m.arach:
		# (une araignée : un petit corps bas, de longues pattes en éventail)
		m.env = m.lc * (0.62 + 0.4 * m.haut) * (0.7 if m.cara > 0.0 else 1.0)
		m.hl *= 0.62
	m.genou = clampf((0.8 if m.chasse else 0.0) + 0.35 * m.haut + (0.12 if m.course else 0.0), 0.0, 1.0)
	m.sous = m.cara > 0.0 and (not m.chasse or m.petit)
	m.pointu = clampf(0.2 + 0.6 * fer + 0.35 * (m.queue - 0.4), 0.0, 1.0)
	m.taille = fer * 0.8 if m.cara <= 0.0 and not m.arach else 0.0
	# ce qui dépasse devant : les mandibules, le rostre, les antennes, les pinces
	if m.chasse:
		m.md = m.hs * (0.6 + 0.6 * m.cornes) * (1.3 if p.traits.has("crocs-allonges") else 1.0)
	elif not m.herbi:
		m.md = m.hs * 0.3
	if m.arach:
		m.md = m.hs * 0.4
	m.rostre = m.hs * (0.5 + 2.0 * (m.museau - 0.55)) if not m.chasse and not m.arach and m.museau > 0.55 else 0.0
	m.la = m.lc * (0.16 + 0.6 * m.antennes) * (0.0 if m.arach else 1.0)
	var og_pin := _organe(c, "pinces")
	m.pinces = m.lc * (0.25 + 0.3 * _taille(og_pin)) if not og_pin.is_empty() else 0.0
	var angle := m.dresse * 1.05
	var devant := m.cl * cos(angle) + m.lhd * 0.95 + maxf(maxf(m.md * 0.95, m.rostre * 0.8), maxf(m.pinces - m.lhd * 0.5, (m.la * 0.5 - m.lhd * 0.4) if m.antennes <= 0.45 else 0.0))
	# ce qui dépasse derrière : la queue, l'aiguillon, les ailes
	m.tl = m.lc * 0.42 * m.queue if m.queue > 0.15 else 0.0
	var og_aig := _organe(c, "aiguillon")
	var derriere := 0.03
	if not og_aig.is_empty():
		m.courbe = str(og_aig.get("forme", "")) == "courbe"
		m.aiguillon = m.lc * (0.36 + 0.45 * _taille(og_aig)) if m.courbe else m.lc * (0.1 + 0.2 * _taille(og_aig))
		derriere = m.aiguillon * (0.45 if m.courbe else 1.0)
	elif m.tl > 0.0:
		derriere = m.tl * ((0.4 if m.queue >= 0.5 else 0.8) if m.chasse else 0.85)
	if m.ailes > 0.0:
		derriere = maxf(derriere, m.lab * (0.05 + 0.3 * m.ailes))
	# (les pieds, posés loin : ils comptent dans la largeur)
	m.poser(0.0)
	for i in m.n:
		for loin in [false, true]:
			var pts: PackedVector2Array = _patte(m, i, loin)[0]
			devant = maxf(devant, pts[pts.size() - 1].x - m.xa + 0.01)
			derriere = maxf(derriere, 0.01 - pts[pts.size() - 1].x)
	var naturel := derriere + m.lc + devant
	var u := L * 0.96 / naturel
	var haut_naturel := m.hl + m.th * 1.3 + maxf(m.cl * sin(angle) + m.hs + m.la * 0.5, m.aiguillon * 0.9 if m.courbe else 0.0)
	if haut_naturel * u > L:
		u = L / haut_naturel
	m.agrandir(u)
	m.poser((derriere - naturel * 0.5) * u)
	# les tons : les élytres dans la robe, le corselet et la tête plus sombres, le dessous pâle (l'ombre y tombe), les pattes sombres
	m.t_coque = T["robe"]
	m.t_corselet = T["robe"].lerp(T["dos"], 0.35)
	m.t_tete = T["robe"].lerp(T["dos"], lerpf(0.4, 0.55, fer))
	m.t_dessous = T["ventre"].lerp(T["robe"], 0.3)
	m.t_patte = T["dos"].lerp(T["robe"], 0.3)
	m.t_patte_loin = T["loin"].darkened(0.12)
	return m


# --- la queue : des cerques qui traînent, une queue relevée, un aiguillon ---

static func _queue(p, m: Mesures) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var e: float = p.e
	var racine := Vector2(m.xr + m.lab * 0.1, m.yb + m.th * lerpf(0.0, 0.08, m.pointu))
	p.calque("queue")
	if m.aiguillon > 0.0:
		p.pivot("queue", racine)
		if m.courbe:
			_queue_scorpion(p, m, racine, m.aiguillon)
		else:
			# (droit : le dard d'une guêpe, au bout de l'abdomen)
			var bout := Vector2(m.xr - m.aiguillon, m.yb + m.th * 0.24)
			p.volume(Planche.ruban(PackedVector2Array([racine, racine.lerp(bout, 0.5) + Vector2(0, m.th * 0.03), bout]), maxf(e * 1.6, m.th * 0.16), e * 0.5), T["os"], Callable(), {"lourd": false, "cerne": 0.7})
		return
	if m.tl <= 0.0:
		return
	p.pivot("queue", racine)
	if m.chasse and m.queue < 0.5:
		# (courte : deux pointes claires au bout de l'abdomen)
		for i in 2:
			var bout := racine + Vector2(-m.lab * 0.1 - m.tl * (0.8 - 0.1 * i), -m.tl * (0.15 + 0.5 * i))
			p.volume(Planche.ruban(_courbe(racine + Vector2(0, -m.th * 0.1 * i), racine + Vector2(-m.lab * 0.1 - m.tl * 0.5, m.th * 0.05 - m.tl * 0.1 * i), bout, 4), maxf(e * 1.5, m.th * 0.2), e * 0.4), T["os"].darkened(0.2 * (1 - i)), Callable(), {"lourd": false, "cerne": 0.7})
	elif m.chasse:
		# (une queue d'anneaux, relevée, qui finit en pince : le staphylin qui menace)
		var leve := 0.7 + 0.5 * float(p.plan.get("temperament", 0.4))
		var bout := racine + Vector2(-m.tl * 0.36, -m.tl * 0.85 * leve)
		var ligne := _courbe(racine, racine + Vector2(-m.tl * 0.66, m.th * 0.1), bout, 6)
		var w0 := m.th * 0.26
		var w1 := maxf(e * 1.2, m.th * 0.14)
		p.volume(Planche.ruban(ligne, w0, w1), m.t_coque.lerp(T["dos"], 0.2), func():
			p.aplat(Planche.ruban(PackedVector2Array([ligne[0] + Vector2(0, w0 * 0.3), ligne[3] + Vector2(w1 * 0.2, w0 * 0.25), ligne[6] + Vector2(w1 * 0.3, w1 * 0.3)]), w0 * 0.4, w1 * 0.4), m.t_dessous, 0.6)
			var k := 3 if m.petit else 5
			for i in range(1, k):
				var j := int(round(6.0 * i / k))
				var q: Vector2 = ligne[j]
				var t: Vector2 = (ligne[mini(j + 1, 6)] - q).normalized().orthogonal()
				p.tracer("M%s L%s" % [Planche.pt(q + t * w0), Planche.pt(q - t * w0)], e * 0.5, T["encre"], 0.8))
		# (la pince du bout : deux crocs clairs)
		var dir := (ligne[6] - ligne[5]).normalized()
		var lf := maxf(e * 2.8, m.tl * 0.34)
		for s in [-1.0, 1.0]:
			var t2: Vector2 = dir.orthogonal() * s
			p.volume(Planche.ruban(_courbe(bout + t2 * w1 * 0.3, bout + dir * lf * 0.5 + t2 * lf * 0.55, bout + dir * lf + t2 * lf * 0.14, 4), maxf(w1 * 0.9, e * 1.2), e * 0.4), T["os"] if s > 0.0 else T["os"].darkened(0.22), Callable(), {"lourd": false, "cerne": 0.7})
	else:
		# (des cerques : deux filets qui traînent ; très longue, une tarière entre eux)
		var w := maxf(e * 0.8, m.th * 0.07)
		for i in 2:
			var bout := racine + Vector2(-m.tl * (1.0 - 0.12 * i), -m.tl * (0.04 + 0.22 * i))
			p.tracer(Planche.ouvert(_courbe(racine, racine + Vector2(-m.tl * 0.5, m.th * (0.14 - 0.2 * i)), bout, 5)), w * (1.0 - 0.2 * i), T["encre"])
		if m.queue > 0.7:
			var bout2 := racine + Vector2(-m.tl * 0.7, m.th * 0.16)
			p.volume(Planche.ruban(PackedVector2Array([racine, racine.lerp(bout2, 0.5) + Vector2(0, m.th * 0.04), bout2]), m.th * 0.2, e * 0.6), m.t_corselet, Callable(), {"lourd": false, "cerne": 0.75})
	var og_ep := _organe(c, "epines", "queue")
	if not og_ep.is_empty():
		for i in 3:
			var q := racine + Vector2(-m.tl * (0.15 + 0.2 * i), -m.th * 0.12)
			p.volume(Planche.poly(PackedVector2Array([q + Vector2(-e, 0), q + Vector2(-e * 0.5, -m.th * (0.2 + 0.3 * _taille(og_ep))), q + Vector2(e, 0)])), T["os"], Callable(), {"lourd": false, "cerne": 0.6})


# la queue d'un scorpion : des anneaux en chapelet, relevés par-dessus le dos, la vésicule et son dard
static func _queue_scorpion(p, m: Mesures, racine: Vector2, l: float) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var a := racine
	var b := Vector2(m.xr - l * 0.5, m.yb - l * 0.25)
	var c2 := Vector2(m.xr - l * 0.25, m.haut_dos - l * 0.78)
	var d := Vector2(m.xr + l * 0.3, m.haut_dos - l * 0.6)
	var k := 4 if m.petit else 5
	var w0 := m.th * 0.42
	var avant := a
	for i in range(1, k + 1):
		var t := float(i) / k
		var q := a.lerp(b, t).lerp(b.lerp(c2, t), t).lerp(b.lerp(c2, t).lerp(c2.lerp(d, t), t), t)
		var w := w0 * lerpf(1.0, 0.62, t)
		var milieu := (avant + q) * 0.5
		var rot := (q - avant).angle()
		p.volume(Planche.ferme(Planche.ellipse(milieu, avant.distance_to(q) * 0.62, w * 0.5, 8, rot), 1.0), m.t_corselet if i % 2 == 1 else m.t_corselet.lerp(T["robe"], 0.5), func():
			_reflet(p, PackedVector2Array([milieu + Vector2(-w * 0.3, -w * 0.2).rotated(rot), milieu + Vector2(w * 0.3, -w * 0.2).rotated(rot)]), 0.6, 0.7),
			{"lourd": i == 1, "cerne": 0.85})
		avant = q
	# (la vésicule, et le dard qui pointe vers l'avant)
	var rv := w0 * 0.5
	var v := d + Vector2(rv * 0.7, rv * 0.1)
	var pointe := v + Vector2(rv * 1.6, rv * 2.0)
	p.volume(Planche.ruban(_courbe(v + Vector2(rv * 0.5, -rv * 0.2), v + Vector2(rv * 2.0, rv * 0.1), pointe, 4), maxf(rv * 0.7, e * 1.3), e * 0.4), T["os"], Callable(), {"lourd": false, "cerne": 0.7})
	p.volume(Planche.ferme(Planche.ellipse(v, rv * 1.1, rv * 0.9, 8, 0.3), 1.0), T["accent"], Callable(), {"lourd": false, "cerne": 0.85})


# --- les pattes : arquées, de la hanche (au thorax) au genou, puis au pied posé loin ---

# où tient la patte i (0 : celle de devant) : sous le thorax, et sous l'avant des élytres quand il y a une carapace. La dernière
# tient derrière le milieu du corps : la bête sait ainsi quelles pattes vont vers l'avant, lesquelles vers l'arrière (bete.gd)
static func _hanche(m: Mesures, i: int, loin: bool) -> Vector2:
	var x0 := m.xa - m.lth * 0.14
	var x1 := minf((m.xj - m.lab * 0.32) if m.cara > 0.0 and not m.arach else (m.xj + m.lth * 0.06), (m.xr + m.xa) * 0.5 - m.lc * 0.015)
	var pas := (x0 - x1) / (m.n - 1)
	# (celles de l'autre côté : un demi-pas en arrière, elles se voient entre les proches)
	var h := Vector2(x0 - pas * (float(i) + (0.5 if loin else 0.0)), m.yt + m.hth * 0.4)
	if i == 0 and m.chasse and not m.arach and m.dresse > 0.0:
		# (un chasseur qui se dresse : la patte ravisseuse part du haut du prothorax)
		h = h.lerp(m.col + Vector2(-m.hs * (0.25 + (0.3 if loin else 0.0)), m.hs * 0.3), m.dresse)
	return h


# une patte : [ses points (la hanche, le genou, la cheville, le pied posé), ses largeurs]
static func _patte(m: Mesures, i: int, loin: bool) -> Array:
	var s: float = VERS[m.n][i]
	var coque := m.cara > 0.0
	var hanche := _hanche(m, i, loin)
	var hx := hanche.x
	var wf := maxf(0.45, m.th * 0.1 * (1.0 + 0.4 * m.rob)) * (0.82 if loin else 1.0)
	# (de l'autre côté, les pattes vont moins loin : elles restent sous le corps, et les deux rangs ne se doublent pas)
	var env := m.env * (1.0 if absf(s) > 0.6 else 0.9) * ((0.6 if m.petit else 0.75) if loin and not m.arach else 1.0)
	# (le genou : jamais plus haut que le bord de la carapace, qui passe devant ; de l'autre côté, il dépasse le dos d'un chasseur)
	var bas := m.rim if coque else m.yb + m.th * 0.36
	var yk := lerpf(bas, m.haut_dos + m.th * 0.06, m.genou)
	if m.arach and not coque:
		# (une araignée : les genoux par-dessus le dos, plus hauts au milieu, où les pattes viennent vers nous)
		yk = m.haut_dos - m.th * (0.02 + 0.22 * (1.0 - absf(s))) - m.hl * 0.2 + (m.th * 0.14 if loin else 0.0)
	if coque and not loin:
		yk = maxf(yk, m.rim + m.e * 0.3)
	elif loin and (coque or not m.arach):
		# (de l'autre côté : un peu plus haut, mais jamais par-dessus le dos, où il ferait une épine)
		yk = maxf(yk - m.th * 0.16, maxf(m.haut_dos, m.yt - m.hth * 0.5 - m.bosse) + m.th * 0.1)
	yk = minf(yk, hanche.y - m.th * 0.1)
	var pied := Vector2(hx + s * env * 1.15, 0.0)
	var genou := Vector2(hx + s * env * 0.55, yk)
	if m.sous:
		# (elle sort de sous la carapace : la cuisse file le long du bord, le genou pointe dehors, la jambe tombe)
		genou = Vector2(hx + s * env * 0.62, minf(m.rim + m.th * 0.14, hanche.y - m.th * 0.08) - (m.th * 0.08 if loin else 0.0))
	if m.arach:
		pied.x = hx + s * env * (1.25 if not loin else 1.0)
		genou.x = hx + s * env * (0.55 if not loin else 0.42)
	elif absf(s) < 0.3:
		# (la patte du milieu : le genou un peu devant, le pied presque dessous)
		genou.x = hx + env * 0.3
	var larg := [wf * 1.25, wf * 0.85, wf * 0.55, wf * 0.42]
	if i == 0 and m.chasse and not m.arach:
		# (un chasseur : la patte de devant ravisseuse, la cuisse épaisse tendue sous la tête, le pied loin devant)
		# (dressé, une mante : le bras se tend devant elle, puis tombe droit)
		pied.x = hx + env * (1.4 - 0.2 * m.dresse)
		genou = Vector2(hx + env * (0.72 + 0.3 * m.dresse), lerpf(hanche.y - m.th * 0.1, hanche.y * 0.74, m.dresse))
		larg = [wf * (1.6 if m.petit else 2.1), wf * 1.3, wf * 0.62, wf * 0.42]
	elif i == m.n - 1 and m.saut and not m.arach:
		# (une sauteuse : la grosse cuisse, le genou haut, loin derrière)
		genou = Vector2(hx - env * 1.0, yk - m.th * (0.0 if coque or loin else 0.3))
		pied.x = hx - env * 0.62
		larg = [wf * 2.3, wf * 0.95, wf * 0.55, wf * 0.42]
	# (aucun pied ne dépasse le bout de l'abdomen)
	pied.x = maxf(pied.x, m.xr + m.lab * 0.02)
	if m.petit:
		# (petite : un trait d'encre plié, sans tarse)
		return [PackedVector2Array([hanche, genou, pied]), [larg[0], larg[1], larg[2]]]
	# (la cheville : un tarse court, presque à plat, vers où va le pied)
	var tarse := maxf(1.8, (pied - genou).length() * 0.22)
	var cheville := pied + Vector2(-tarse * 0.88 * (1.0 if s > -0.3 else -1.0), -tarse * 0.36)
	return [PackedVector2Array([hanche, genou, cheville, pied]), larg]


static func _pattes(p, m: Mesures, loin: bool) -> void:
	for i in m.n:
		var q := _patte(m, i, loin)
		p.patte(q[0], q[1], loin, {"teinte": m.t_patte_loin if loin else m.t_patte, "pied": "pointe", "pied_taille": 0.8 if m.petit else 1.3,
			"epines": (maxf(1.7, m.th * 0.085) if m.grand else 0.0)})


# --- le corps : l'abdomen, le thorax, le prothorax qui se dresse ---

static func _abdomen(m: Mesures) -> PackedVector2Array:
	var k := m.pointu
	var th := m.th
	var lab := m.lab
	var yb := m.yb
	var pince := lerpf(0.42, 0.2, m.taille)
	return PackedVector2Array([
		Vector2(m.xj + m.lth * 0.14, m.yt - m.hth * pince),
		Vector2(m.xj - lab * 0.24, yb - th * 0.5 - m.dome * 0.8),
		Vector2(m.xj - lab * 0.56, yb - th * lerpf(0.5, 0.42, k) - m.dome * lerpf(0.9, 0.4, k)),
		Vector2(m.xr + lab * lerpf(0.13, 0.2, k), yb - th * lerpf(0.34, 0.16, k)),
		Vector2(m.xr, yb + th * lerpf(0.02, 0.1, k)),
		Vector2(m.xr + lab * lerpf(0.16, 0.24, k), yb + th * lerpf(0.36, 0.3, k)),
		Vector2(m.xj - lab * 0.5, yb + th * 0.5),
		Vector2(m.xj - lab * 0.16, yb + th * 0.47),
		Vector2(m.xj + m.lth * 0.14, m.yt + m.hth * pince),
	])


static func _thorax(m: Mesures) -> PackedVector2Array:
	var h := m.hth
	var y := m.yt
	var l := m.lth
	return PackedVector2Array([
		Vector2(m.xj - l * 0.1, y - h * 0.38),
		Vector2(m.xj + l * 0.3, y - h * 0.5 - m.bosse),
		Vector2(m.xa - l * 0.25, y - h * 0.5 - m.bosse * 0.6),
		Vector2(m.xa + l * 0.02, y - h * 0.24),
		Vector2(m.xa + l * 0.02, y + h * 0.2),
		Vector2(m.xa - l * 0.22, y + h * 0.5),
		Vector2(m.xj + l * 0.2, y + h * 0.52),
		Vector2(m.xj - l * 0.1, y + h * 0.34),
	])


static func _corps(p, m: Mesures) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var e: float = p.e
	var motif := str(c.get("motif", "uni"))
	var top := m.haut_dos
	var bot := m.yb + m.th * 0.5
	p.calque("corps")
	var d_ab := Planche.ferme(p.vivant(_abdomen(m), e * 0.2), lerpf(1.0, 0.86, m.fer))
	# les anneaux de l'abdomen : des traits d'encre fins, bombés vers l'arrière
	var k := 3 if m.petit else (6 if m.grand else 4)
	if m.rampe:
		k += 2
	var nu := m.cara <= 0.0 or m.couv < 0.95       # (le dos se voit, au moins au bout)
	p.volume(d_ab, T["robe"], func():
		# (les plaques du dos, plus sombres ; le dessous, pâle, où tombe l'ombre)
		if nu:
			p.aplat(Planche.ferme(PackedVector2Array([Vector2(m.xr - 2.0, top - 3.0), Vector2(m.xj + m.lth * 0.2, top - 3.0), Vector2(m.xj + m.lth * 0.2, m.yb - m.th * 0.2),
				Vector2((m.xr + m.xj) * 0.5, m.yb - m.th * 0.14), Vector2(m.xr - 2.0, m.yb - m.th * 0.05)]), 0.8), T["dos"], 0.45)
		p.aplat(Planche.ferme(PackedVector2Array([Vector2(m.xr - 2.0, bot + 3.0), Vector2(m.xr + m.lab * 0.1, m.yb + m.th * 0.24), Vector2((m.xr + m.xj) * 0.5, m.yb + m.th * 0.14),
			Vector2(m.xj + m.lth * 0.2, m.yb + m.th * 0.12), Vector2(m.xj + m.lth * 0.2, bot + 3.0)]), 0.8), m.t_dessous, 0.92)
		if nu:
			_motif_anneaux(p, m, motif, k, top, bot)
		for i in range(1, k):
			var x := lerpf(m.xj - m.lab * 0.04, m.xr, float(i) / k)
			p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(x, top - 1.0)), Planche.pt(Vector2(x - m.lab * 0.07, m.yb)), Planche.pt(Vector2(x, bot + 1.0))], e * 0.5, T["encre"], 0.8)
			if nu and not m.petit:
				# (chaque plaque accroche la lumière à son bord)
				p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(x - e * 0.9, top + m.th * 0.12)), Planche.pt(Vector2(x - e * 0.9 - m.lab * 0.03, top + m.th * 0.24)), Planche.pt(Vector2(x - e * 0.9 - m.lab * 0.035, top + m.th * 0.36))], maxf(0.7, e * 0.55), T["lumiere"], 0.6)
		if nu:
			_reflet(p, PackedVector2Array([Vector2(m.xj - m.lab * 0.12, top + m.th * 0.17), Vector2(m.xj - m.lab * 0.36, top + m.th * 0.13), Vector2(m.xj - m.lab * 0.6, top + m.th * 0.2)]))
		p.aplat(Planche.ferme(Planche.ellipse(Vector2((m.xr + m.xj) * 0.5, bot + m.th * 0.04), m.lab * 0.6, m.th * 0.14, 10), 1.0), T["encre"], 0.25))
	# le thorax : là où tiennent les pattes
	var d_th := Planche.ferme(p.vivant(_thorax(m), e * 0.2), lerpf(1.0, 0.8, m.fer))
	var xm := (m.xj + m.xa) * 0.5
	p.volume(d_th, m.t_corselet, func():
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(xm, m.yt + m.hth * 0.52), m.lth * 0.7, m.hth * 0.36, 8), 1.0), m.t_dessous, 0.92)
		if m.cara <= 0.0:
			_reflet(p, PackedVector2Array([Vector2(m.xj + m.lth * 0.18, m.yt - m.hth * 0.3 - m.bosse), Vector2(m.xj + m.lth * 0.45, m.yt - m.hth * 0.36 - m.bosse), Vector2(m.xa - m.lth * 0.25, m.yt - m.hth * 0.3)]))
			if not m.petit:
				# (les plaques du thorax : un pli d'encre)
				p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(xm - m.lth * 0.1, m.yt - m.hth * 0.6)), Planche.pt(Vector2(xm - m.lth * 0.2, m.yt)), Planche.pt(Vector2(xm - m.lth * 0.04, m.yt + m.hth * 0.5))], e * 0.5, T["encre"], 0.6)
		p.aplat(Planche.ferme(Planche.ellipse(Vector2(xm, m.yt + m.hth * 0.56), m.lth * 0.6, m.hth * 0.14, 8), 1.0), T["encre"], 0.25))
	# le prothorax, quand il s'allonge : un « cou » d'une pièce, qui se dresse chez un chasseur
	if m.cl > e:
		var base := Vector2(m.xa - m.lth * 0.16, m.yt - m.hth * 0.06)
		var cou := PackedVector2Array([base, base.lerp(m.col, 0.55) + Vector2(-m.hs * 0.04, m.hs * 0.03), m.col + Vector2(m.hs * 0.05, 0.0)])
		var w0 := m.hth * 0.8
		var w1 := m.hs * 0.62
		p.volume(Planche.ruban(cou, w0, w1), m.t_corselet, func():
			p.aplat(Planche.ruban(PackedVector2Array([cou[0] + Vector2(m.hth * 0.1, w0 * 0.34), cou[2] + Vector2(m.hs * 0.1, w1 * 0.34)]), w0 * 0.3, w1 * 0.3), m.t_dessous, 0.7)
			_reflet(p, PackedVector2Array([cou[0] + Vector2(m.hth * 0.2, -w0 * 0.24), cou[2] + Vector2(-m.hs * 0.1, -w1 * 0.2)])),
			{"lourd": false, "cerne": 0.0})
		for bord in Planche.bords(cou, w0, w1):
			p.cerne(Planche.ouvert(bord.slice(1)))


# le motif d'un abdomen nu : il suit ses anneaux
static func _motif_anneaux(p, m: Mesures, motif: String, k: int, top: float, bot: float) -> void:
	var T: Dictionary = p.tons
	var pas := (m.xj - m.xr) / k
	match motif:
		"bandes":
			# (un anneau sombre sur deux : une guêpe)
			for i in range(1, k, 2):
				var x := lerpf(m.xj - m.lab * 0.04, m.xr, float(i) / k)
				p.aplat("M%s Q%s %s L%s Q%s %sZ" % [Planche.pt(Vector2(x, top - 2.0)), Planche.pt(Vector2(x - m.lab * 0.07, m.yb)), Planche.pt(Vector2(x, bot + 2.0)),
					Planche.pt(Vector2(x - pas, bot + 2.0)), Planche.pt(Vector2(x - pas - m.lab * 0.07, m.yb)), Planche.pt(Vector2(x - pas, top - 2.0))], T["dos"], 0.7)
		"rayures":
			# (un liseré sombre au bord de chaque anneau)
			for i in range(1, k + 1):
				var x := lerpf(m.xj - m.lab * 0.04, m.xr, float(i) / k) + pas * 0.24
				p.tracer("M%s Q%s %s" % [Planche.pt(Vector2(x, top - 2.0)), Planche.pt(Vector2(x - m.lab * 0.07, m.yb)), Planche.pt(Vector2(x, bot + 2.0))], maxf(1.0, pas * 0.22), T["dos"], 0.7)
		"taches":
			for i in k:
				var x := lerpf(m.xj - m.lab * 0.04, m.xr, (float(i) + 0.5) / k)
				p.aplat(Planche.ferme(Planche.ellipse(Vector2(x, m.yb - m.th * 0.1 + m.th * 0.06 * sin(i * 2.1)), pas * 0.26, m.th * 0.13, 6), 1.0), T["dos"], 0.7)


# --- le dessus : les élytres, le corselet, les ailes repliées, les hanches ; ce qui passe devant les pattes proches ---

# un élytre : 9 points (0 l'épaule en haut, 1-3 le dos, 4 le bout, 5-7 le bord bas, 8 l'épaule en bas)
static func _elytre(m: Mesures) -> PackedVector2Array:
	var k := m.pointu
	var th := m.th
	var lab := m.lab
	var yb := m.yb
	var xe := m.xj + m.lth * 0.1
	if m.couv < 0.95:
		# (courts : ils s'arrêtent net, en biais, l'abdomen continue nu)
		var l := lab * m.couv
		return PackedVector2Array([
			Vector2(xe, yb - th * 0.46 - m.dome * 0.35),
			Vector2(m.xj - l * 0.35, yb - th * 0.56 - m.dome),
			Vector2(m.xj - l * 0.8, yb - th * 0.55 - m.dome * 0.8),
			Vector2(m.xj - l * 1.02, yb - th * 0.42),
			Vector2(m.xj - l * 0.9, m.rim + th * 0.02),
			Vector2(m.xj - l * 0.6, m.rim + th * 0.05),
			Vector2(m.xj - l * 0.3, m.rim + th * 0.04),
			Vector2(m.xj - l * 0.02, m.rim),
			Vector2(xe, m.rim - th * 0.12),
		])
	var y_bout := yb + th * lerpf(0.0, 0.08, k)
	return PackedVector2Array([
		Vector2(xe, yb - th * 0.46 - m.dome * 0.35),
		Vector2(m.xj - lab * 0.24, yb - th * 0.54 - m.dome),
		Vector2(m.xj - lab * 0.57, yb - th * lerpf(0.54, 0.46, k) - m.dome * lerpf(1.0, 0.45, k)),
		Vector2(m.xr + lab * lerpf(0.12, 0.19, k), yb - th * lerpf(0.38, 0.19, k) - m.dome * 0.12),
		Vector2(m.xr - lab * 0.02, y_bout),
		Vector2(m.xr + lab * lerpf(0.2, 0.3, k), lerpf(m.rim + th * 0.06, y_bout, 0.35)),
		Vector2(m.xj - lab * 0.45, m.rim + th * 0.05),
		Vector2(m.xj - lab * 0.05, m.rim),
		Vector2(xe, m.rim - th * 0.12),
	])


static func _corselet(m: Mesures) -> PackedVector2Array:
	var h := m.hth
	var y := m.yt
	var l := m.lth
	var bord := minf(m.rim, y + h * 0.26)
	return PackedVector2Array([
		Vector2(m.xj + l * 0.0, y - h * 0.44),
		Vector2(m.xj + l * 0.36, y - h * 0.56 - m.bosse),
		Vector2(m.xa - l * 0.16, y - h * 0.5 - m.bosse * 0.5),
		Vector2(m.xa + l * 0.07, y - h * 0.2),
		Vector2(m.xa + l * 0.04, minf(bord, y + h * 0.1)),
		Vector2(m.xa - l * 0.3, bord + h * 0.06),
		Vector2(m.xj + l * 0.0, bord),
	])


static func _dessus(p, m: Mesures) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var e: float = p.e
	var motif := str(c.get("motif", "uni"))
	p.calque("dessus")
	# les hanches : de petites plaques rondes où les pattes s'emboîtent
	if not m.petit:
		for i in m.n:
			var q := _patte(m, i, false)
			var h: Vector2 = q[0][0]
			var r := maxf(1.3, minf(float(q[1][0]) * 0.72, m.th * 0.16))
			p.volume(Planche.ferme(Planche.ellipse(h, r, r * 0.9, 8, (q[0][1] - h).angle()), 1.0), m.t_patte, Callable(), {"lourd": false, "cerne": 0.6})
	if m.ailes > 0.0:
		_ailes(p, m)
	if m.cara > 0.0:
		if m.anneaux:
			_carapace_anneaux(p, m)
		else:
			var el := _elytre(m)
			p.volume(Planche.ferme(p.vivant(el, e * 0.2), lerpf(1.0, 0.85, m.fer)), m.t_coque, func():
				# (le bas de l'élytre tourne dans l'ombre)
				p.aplat(Planche.ferme(PackedVector2Array([el[8] + Vector2(2.0, -m.th * 0.16), el[7] + Vector2(0, -m.th * 0.14), el[6] + Vector2(0, -m.th * 0.14), el[5] + Vector2(-m.lab * 0.1, -m.th * 0.1),
					el[4] + Vector2(-3.0, 3.0), el[6] + Vector2(0, m.th * 0.3), el[8] + Vector2(2.0, m.th * 0.3)]), 0.9), T["dos"], 0.4)
				_motif_elytre(p, m, motif, el)
				# (le reflet : un trait clair le long du dos, un éclat plus court dessous)
				var d := m.th * 0.15
				_reflet(p, PackedVector2Array([el[0] + Vector2(-m.lab * 0.1, d * 1.3), el[1] + Vector2(0, d), el[2] + Vector2(m.lab * 0.06, d)]), 0.9, 0.85)
				if not m.petit:
					_reflet(p, PackedVector2Array([el[1] + Vector2(-m.lab * 0.02, d * 2.3), el[1].lerp(el[2], 0.6) + Vector2(0, d * 2.2)]), 0.55, 0.55)
					# (l'ourlet : un trait fin le long du bord)
					p.tracer(Planche.ouvert(PackedVector2Array([el[5] + Vector2(0, -e * 1.3), el[6] + Vector2(0, -e * 1.3), el[7] + Vector2(0, -e * 1.3), el[8] + Vector2(-e, -e * 0.6)])), e * 0.45, T["encre"], 0.6),
				{"lourd": false})
		# le corselet : le bouclier du thorax, plus sombre
		var co := _corselet(m)
		p.volume(Planche.ferme(p.vivant(co, e * 0.2), lerpf(1.0, 0.8, m.fer)), m.t_corselet, func():
			_reflet(p, PackedVector2Array([co[0] + Vector2(m.lth * 0.14, m.hth * 0.12), co[1] + Vector2(0, m.hth * 0.14), co[2] + Vector2(-m.lth * 0.05, m.hth * 0.14)]), 0.9, 0.85)
			if motif == "masque":
				p.aplat(Planche.ferme(Planche.ellipse(Vector2((m.xj + m.xa) * 0.5, m.yt), m.lth * 0.3, m.hth * 0.3, 8), 1.0), T["dos"], 0.6)
			if not m.petit:
				p.tracer(Planche.ouvert(PackedVector2Array([co[6] + Vector2(e, -e * 1.3), co[5] + Vector2(0, -e * 1.3), co[4] + Vector2(-e * 1.2, -e * 0.4)])), e * 0.45, T["encre"], 0.6),
			{"lourd": false})
	var og_crete := _organe(c, "crete", "dos")
	if not og_crete.is_empty():
		_crete(p, m, _taille(og_crete), str(og_crete.get("forme", "")) != "lisse")
	var og_ep := _organe(c, "epines", "dos")
	if not og_ep.is_empty():
		_epines(p, m, og_ep)
	if float(c.get("oreilles", 0.0)) >= 0.3:
		_oreillettes(p, m, float(c.get("oreilles", 0.0)))


# le motif d'un élytre : des bandes en travers, des raies le long, des taches ; uni, de fines stries
static func _motif_elytre(p, m: Mesures, motif: String, el: PackedVector2Array) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var top := m.yb - m.th * 0.56 - m.dome
	var bas := m.rim + m.th * 0.3
	var xe := minf(el[3].x, el[4].x)  # le bout de l'élytre
	var le := el[0].x - xe            # sa longueur
	var court := m.couv < 0.95
	var sombre: Color = T["dos"].darkened(0.12)
	match motif:
		"bandes":
			p.bandes(xe + le * 0.12, xe + le * 0.9, top, bas, 2 if m.petit or court else 3, m.th * 0.08, le * (0.24 if m.petit or court else 0.17), sombre, 0.85)
		"rayures", "uni":
			# (des lignes qui suivent le dos, de l'épaule à la pointe)
			var raies := motif == "rayures"
			var nb := (2 if m.petit else 3) if raies else (0 if p.L < 50.0 else (4 if m.grand else 2))
			for j in nb:
				var f := (float(j) + 1.0) / (nb + 1.0)
				var ligne := PackedVector2Array([el[0].lerp(el[8], f) + Vector2(-m.lab * 0.04, 0), el[1].lerp(el[7], f), el[2].lerp(el[6], f)])
				if court:
					ligne.append(el[3].lerp(el[4], f) + Vector2(e, 0))
				else:
					ligne.append(el[3].lerp(el[5], f * 0.8))
					ligne.append(el[4] + Vector2(m.lab * 0.06, -m.th * 0.02))
				if raies:
					p.tracer(Planche.ouvert(ligne), maxf(1.3, m.th * 0.11), sombre, 0.85)
				else:
					p.tracer(Planche.ouvert(ligne), maxf(0.45, e * 0.4), T["encre"], 0.38)
		"taches":
			p.taches(Rect2(xe + le * 0.14, top + m.th * 0.16, le * 0.7, (bas - top) * 0.5), 4 if m.petit else 7, m.th * 0.13, m.th * 0.2, sombre, 0.85)
	if m.grand:
		# (un grain de points d'encre, là où la carapace tourne)
		var d := ""
		for i in 16:
			var q := Vector2(lerpf(xe + le * 0.15, xe + le * 0.9, p.r.randf()), lerpf(m.rim - m.th * 0.3, m.rim - m.th * 0.04, p.r.randf()))
			d += "M%s l0.1 0.1" % Planche.pt(q)
		p.tracer(d, e * 0.55, T["encre"], 0.5)


# une carapace segmentée : des plaques en tuiles, de la nuque à la pointe (un cloporte, un tatou)
static func _carapace_anneaux(p, m: Mesures) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var k := 3 if m.petit else (6 if m.grand else 4)
	var haut := m.yb - m.th * 0.53 - m.dome
	# (de l'arrière vers l'avant : chaque plaque recouvre la suivante)
	for i in range(k - 1, -1, -1):
		var xa := lerpf(m.xj + m.lth * 0.1, m.xr, float(i) / k)
		var xb := lerpf(m.xj + m.lth * 0.1, m.xr, float(i + 1) / k) - m.lab * 0.03
		var fa := sin(PI * clampf(0.12 + 0.76 * float(i) / k, 0.0, 1.0))
		var fb := sin(PI * clampf(0.12 + 0.76 * float(i + 1) / k, 0.0, 1.0))
		var ya := lerpf(m.yb - m.th * 0.2, haut, fa)
		var yc := lerpf(m.yb - m.th * 0.2, haut, fb)
		var pts := PackedVector2Array([Vector2(xa, ya), Vector2((xa + xb) * 0.5, minf(ya, yc) - m.th * 0.04), Vector2(xb, yc), Vector2(xb - m.lab * 0.05, (yc + m.rim) * 0.5), Vector2(xb + m.lab * 0.02, m.rim + m.th * 0.04),
			Vector2(xa - m.lab * 0.02, m.rim + m.th * 0.04), Vector2(xa - m.lab * 0.07, (ya + m.rim) * 0.5)])
		p.volume(Planche.ferme(pts, 0.9), m.t_coque if i % 2 == 0 or str(p.corps.get("motif", "")) != "bandes" else m.t_coque.lerp(T["dos"], 0.6), func():
			_reflet(p, PackedVector2Array([Vector2(xa - m.lab * 0.03, ya + m.th * 0.14), Vector2(xb + m.lab * 0.05, yc + m.th * 0.14)])),
			{"lourd": false, "cerne": 0.85})


# les ailes repliées sur le dos : deux lames de membrane, nervurées, qui dépassent le bout de l'abdomen
static func _ailes(p, m: Mesures) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var haut := m.haut_dos
	var depasse := m.lab * (0.05 + 0.3 * m.ailes)
	for i in 2:
		var dy := -m.th * 0.16 * (1 - i)
		var racine := Vector2(m.xj + m.lth * 0.3, m.yt - m.hth * 0.45 + dy * 0.3)
		var bout := Vector2(m.xr - depasse * (1.0 - 0.15 * i), m.yb - m.th * (0.3 - 0.1 * i) + dy)
		var pts := PackedVector2Array([racine, Vector2(m.xj - m.lab * 0.3, haut - m.th * 0.12 + dy), Vector2(m.xr + m.lab * 0.1, haut - m.th * 0.04 + dy), bout,
			Vector2(m.xr + m.lab * 0.2, m.yb - m.th * 0.02 + dy * 0.5), Vector2(m.xj - m.lab * 0.2, m.yb - m.th * 0.16 + dy * 0.5)])
		var d := Planche.ferme(pts, 0.95)
		p.aplat(d, T["os"] if i == 1 else T["os"].lerp(T["dos"], 0.35), 0.62)
		if not m.petit:
			# (les nervures)
			for j in 2:
				p.tracer(Planche.ouvert(PackedVector2Array([racine + Vector2(-m.lab * 0.05, m.th * 0.06), pts[1].lerp(pts[5], 0.35 + 0.3 * j), bout.lerp(pts[4], 0.2 + 0.4 * j)])), e * 0.4, T["encre"], 0.45)
		p.cerne(d, 0.6)


# le haut du dos à cet endroit (le corselet, puis les élytres ou l'abdomen)
static func _dos(m: Mesures, x: float) -> float:
	if x > m.xj:
		return m.yt - m.hth * 0.5 - m.bosse * 0.8
	return m.yb - m.th * 0.5 - m.dome * 0.9 * sin(PI * clampf((m.xj - x) / m.lab + 0.2, 0.0, 1.0))


# une crête : des pointes le long du corselet et du dos (lisse : une carène)
static func _crete(p, m: Mesures, taille: float, dents: bool) -> void:
	var T: Dictionary = p.tons
	var h := m.th * (0.14 + 0.42 * taille)
	var x0 := m.xj - m.lab * (0.5 if m.cara > 0.0 else 0.35) * m.couv
	var x1 := m.xa - m.lth * 0.18
	var nb := 3 if m.petit else (7 if m.grand else 5)
	var pts := PackedVector2Array([Vector2(x0, _dos(m, x0) + 1.0)])
	for i in nb:
		var xa := lerpf(x0, x1, float(i) / nb)
		var xb := lerpf(x0, x1, float(i + 1) / nb)
		var k := 0.6 + 0.4 * sin(PI * (float(i) + 0.5) / nb)
		if dents:
			pts.append(Vector2(lerpf(xa, xb, 0.25), _dos(m, xa) - h * k))
			pts.append(Vector2(xb, _dos(m, xb) - h * 0.1))
		else:
			pts.append(Vector2(lerpf(xa, xb, 0.5), _dos(m, xa) - h * k * 0.8))
	pts.append(Vector2(x1, _dos(m, x1) + 1.0))
	p.volume(Planche.poly(pts) if dents else Planche.ferme(pts, 0.8), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})


# des épines sur le dos : fines, ou massives
static func _epines(p, m: Mesures, og: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var nb := clampi(int(og.get("nombre", 7)), 3, 4 if m.petit else 10)
	var l := m.th * (0.25 + 0.45 * _taille(og))
	var w := (m.th * 0.16 if str(og.get("forme", "")) == "massives" else m.th * 0.08) + e * 0.5
	for i in nb:
		var x := lerpf(m.xr + m.lab * 0.2, m.xj + m.lth * 0.5, (float(i) + 0.5) / nb)
		var y := _dos(m, x)
		p.volume(Planche.poly(PackedVector2Array([Vector2(x - w, y + 1.0), Vector2(x - w * 1.6, y - l), Vector2(x + w, y + 1.0)])), T["os"], Callable(), {"lourd": false, "cerne": 0.7})


# les « oreilles » d'un insecte : au coin du corselet, un lobe rond chez un brouteur, un éperon couché en arrière chez un chasseur
static func _oreillettes(p, m: Mesures, taille: float) -> void:
	var l := m.hth * (0.22 + 0.5 * taille)
	var o := Vector2(m.xj + m.lth * 0.2, m.yt - m.hth * 0.46 - m.bosse * 0.7)
	var pts: PackedVector2Array
	if m.chasse:
		pts = PackedVector2Array([o + Vector2(l * 0.45, l * 0.05), o + Vector2(-l * 0.2, -l * 0.5), o + Vector2(-l * 1.1, -l * 0.62), o + Vector2(-l * 0.3, l * 0.12)])
	else:
		pts = PackedVector2Array([o + Vector2(l * 0.35, 0), o + Vector2(l * 0.1, -l * 0.6), o + Vector2(-l * 0.5, -l * 0.7), o + Vector2(-l * 0.6, -l * 0.15), o + Vector2(-l * 0.3, l * 0.1)])
	p.volume(Planche.ferme(pts, 0.7 if m.chasse else 1.0), m.t_corselet, Callable(), {"lourd": false, "cerne": 0.8})


# --- la tête : la capsule, l'œil composé, les antennes, les mandibules ou le rostre, la corne, les pinces ---

static func _tete(p, m: Mesures) -> void:
	var c: Dictionary = p.corps
	var T: Dictionary = p.tons
	var e: float = p.e
	var o := m.o
	var hs := m.hs
	var l := m.lhd
	var fer := m.fer
	p.calque("tete")
	p.pivot("tete", m.col)
	var og_ant := _organe(c, "antennes")
	var plumeuses := str(og_ant.get("forme", "")) == "plumeuses"
	var og_pin := _organe(c, "pinces")
	var og_coll := _organe(c, "collerette")
	if not og_coll.is_empty():
		_collerette(p, m, og_coll)
	# ce qui est de l'autre côté : l'antenne, la mandibule, la pince
	if m.la > 0.0:
		_antenne(p, m, true, plumeuses)
	if not og_pin.is_empty():
		_pince(p, m, og_pin, true)
	if m.md > 0.0:
		_mandibule(p, m, true)
	# la capsule : ronde et rentrée chez un brouteur, carrée, le front droit, chez un chasseur
	var rond := PackedVector2Array([o + Vector2(-l * 0.52, -hs * 0.1), o + Vector2(-l * 0.3, -hs * 0.46), o + Vector2(l * 0.2, -hs * 0.44),
		o + Vector2(l * 0.5, -hs * 0.05), o + Vector2(l * 0.42, hs * 0.36), o + Vector2(l * 0.08, hs * 0.52), o + Vector2(-l * 0.36, hs * 0.36)])
	var coin := PackedVector2Array([o + Vector2(-l * 0.5, -hs * 0.36), o + Vector2(-l * 0.12, -hs * 0.5), o + Vector2(l * 0.32, -hs * 0.4),
		o + Vector2(l * 0.52, -hs * 0.08), o + Vector2(l * 0.46, hs * 0.28), o + Vector2(l * 0.04, hs * 0.46), o + Vector2(-l * 0.46, hs * 0.36)])
	var pts := PackedVector2Array()
	for i in rond.size():
		pts.append(rond[i].lerp(coin[i], fer))
	var motif := str(c.get("motif", "uni"))
	p.volume(Planche.ferme(p.vivant(pts, e * 0.15), lerpf(1.0, 0.72, fer)), m.t_tete, func():
		p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(l * 0.1, hs * 0.42), l * 0.5, hs * 0.2, 8), 1.0), m.t_dessous, 0.5)
		if motif == "masque":
			# (le masque : une bande sombre, de l'œil à la bouche)
			p.aplat(Planche.ferme(Planche.ellipse(o + Vector2(l * 0.12, -hs * 0.06), l * 0.56, hs * 0.26, 8, 0.2), 1.0), T["dos"].darkened(0.2), 0.85)
		_reflet(p, PackedVector2Array([pts[0] + Vector2(l * 0.16, -hs * 0.1), pts[1] + Vector2(l * 0.1, hs * 0.13), pts[2] + Vector2(-l * 0.1, hs * 0.12)]), 0.75, 0.75))
	if m.rostre > 0.0:
		# (un rostre : le long nez d'un charançon, courbé vers le sol)
		var s := o + Vector2(l * 0.36, hs * 0.14)
		var ligne := _courbe(s, s + Vector2(m.rostre * 0.6, m.rostre * 0.1), s + Vector2(m.rostre * 0.82, m.rostre * 0.6), 5)
		var b: Array = Planche.bords(ligne, hs * 0.36, hs * 0.2)
		p.volume(Planche.ruban(ligne, hs * 0.36, hs * 0.2), m.t_tete, Callable(), {"lourd": false, "cerne": 0.0})
		for bord in b:
			p.cerne(Planche.ouvert(bord.slice(1)), 0.9)
		p.cerne("M%s L%s" % [Planche.pt(b[0][5]), Planche.pt(b[1][5])], 0.9)
	if m.md > 0.0:
		_mandibule(p, m, false)
	# l'œil composé : large, l'éclat de papier dessus
	if m.arach:
		# (une araignée : des yeux en rang, le grand d'abord)
		p.oeil(o + Vector2(l * 0.26, -hs * 0.14), hs * 0.2, {"sourcil": false})
		for i in (2 if m.petit else 3):
			var q := o + Vector2(l * (0.02 - 0.2 * i), -hs * (0.26 + 0.05 * i))
			var r := maxf(0.9, hs * (0.1 - 0.015 * i))
			p.svg("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/><circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\"/>" % [Planche.n(q.x), Planche.n(q.y), Planche.n(r + e * 0.4), Planche.coul(T["encre"]),
				Planche.n(q.x), Planche.n(q.y), Planche.n(r), Planche.coul(T["oeil"])])
	else:
		p.oeil(o + Vector2(l * lerpf(0.1, 0.0, fer), -hs * lerpf(0.08, 0.17, fer)), hs * lerpf(0.25, 0.21, fer))
	# la corne d'un brouteur (un scarabée rhinocéros) ; chez un chasseur, les cornes sont ses mandibules
	if m.cornes > 0.0 and not m.chasse and not m.arach:
		_corne(p, m, _organe(c, "cornes"))
	var og_crete := _organe(c, "crete", "tete")
	if not og_crete.is_empty():
		var h := hs * (0.3 + 0.7 * _taille(og_crete))
		p.volume(Planche.ferme(PackedVector2Array([o + Vector2(-l * 0.45, -hs * 0.3), o + Vector2(-l * 0.3, -hs * 0.4 - h), o + Vector2(l * 0.05, -hs * 0.45 - h * 0.6), o + Vector2(l * 0.3, -hs * 0.36)]), 0.8), T["accent"], Callable(), {"lourd": false, "cerne": 0.8})
	if m.la > 0.0:
		_antenne(p, m, false, plumeuses)
	if not og_pin.is_empty():
		_pince(p, m, og_pin, false)


# une antenne : souple et courbée chez un brouteur (une petite massue au bout), coudée chez un chasseur ; très longue, elle
# part en arrière par-dessus le dos (un capricorne) ; plumeuse, elle porte ses barbes (un papillon de nuit)
static func _antenne(p, m: Mesures, loin: bool, plumeuses: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var la := m.la * (0.9 if loin else 1.0)
	var hs := m.hs
	var base := m.o + Vector2(m.lhd * lerpf(0.22, 0.3, m.fer) + (hs * 0.12 if loin else 0.0), -hs * lerpf(0.42, 0.34, m.fer))
	var w := maxf(0.75, e * (0.6 if loin else 0.75))
	var alpha := 0.75 if loin else 1.0
	var ligne: PackedVector2Array
	if m.antennes > 0.45:
		# (longue : elle se couche en arrière)
		var bout := base + Vector2(-la * 0.78, -la * (0.28 if loin else 0.16))
		ligne = _courbe(base, base + Vector2(la * 0.12, -la * (0.62 if loin else 0.5)), bout, 7)
	elif m.chasse:
		# (coudée : le scape monte, le fouet part en avant)
		var coude := base + Vector2(la * 0.14, -la * (0.42 if loin else 0.34))
		var bout2 := coude + Vector2(la * 0.62, la * (0.02 if loin else 0.14))
		ligne = PackedVector2Array([base, coude])
		ligne.append_array(_courbe(coude, coude + Vector2(la * 0.36, -la * 0.14), bout2, 4).slice(1))
		p.tracer(Planche.poly(ligne).trim_suffix("Z"), w, T["encre"], alpha)
		return
	else:
		var bout3 := base + Vector2(la * 0.8, -la * (0.42 if loin else 0.26))
		ligne = _courbe(base, base + Vector2(la * 0.3, -la * (0.85 if loin else 0.72)), bout3, 6)
	p.tracer(Planche.ouvert(ligne), w, T["encre"], alpha)
	var bout4 := ligne[ligne.size() - 1]
	if plumeuses:
		# (les barbes, des deux côtés)
		var d := ""
		var k := ligne.size()
		for i in range(1, k):
			var t: Vector2 = (ligne[i] - ligne[i - 1]).normalized().orthogonal()
			var lb := la * 0.16 * sin(PI * float(i) / k)
			d += "M%s L%s M%s L%s" % [Planche.pt(ligne[i]), Planche.pt(ligne[i] + t * lb + (ligne[i] - ligne[i - 1]) * 0.4), Planche.pt(ligne[i]), Planche.pt(ligne[i] - t * lb + (ligne[i] - ligne[i - 1]) * 0.4)]
		p.tracer(d, maxf(0.6, e * 0.5), T["encre"], alpha)
	elif not m.chasse and not m.petit:
		# (la massue du bout)
		p.aplat(Planche.ferme(Planche.ellipse(bout4, maxf(1.1, hs * 0.1), maxf(0.8, hs * 0.07), 6, (bout4 - ligne[ligne.size() - 2]).angle()), 1.0), T["encre"], alpha)


# une mandibule : une faucille claire, en avant de la tête ; les deux s'ouvrent comme une tenaille
static func _mandibule(p, m: Mesures, loin: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var o := m.o
	var hs := m.hs
	var l := m.lhd
	var md := m.md
	var teinte: Color = (T["os"] if m.chasse or m.arach else m.t_tete.lerp(T["os"], 0.35))
	if m.arach:
		# (des crochets, sous la tête)
		var b := o + Vector2(l * (0.4 if loin else 0.3), hs * 0.2)
		p.volume(Planche.ruban(_courbe(b, b + Vector2(md * 0.5, md * 0.3), b + Vector2(md * 0.2, md * 1.1), 4), hs * 0.26, e * 0.4), teinte.darkened(0.25) if loin else teinte, Callable(), {"lourd": false, "cerne": 0.7})
		return
	var ligne: PackedVector2Array
	if loin:
		# (celle du haut : elle part du front, se bombe, et retombe)
		var b2 := o + Vector2(l * 0.4, -hs * 0.1)
		ligne = _courbe(b2, b2 + Vector2(md * 0.7, -hs * 0.34), b2 + Vector2(md * 0.98, hs * 0.04), 5)
	else:
		# (celle du bas : elle part de la joue, se creuse, et remonte)
		var b3 := o + Vector2(l * 0.36, hs * 0.24)
		ligne = _courbe(b3, b3 + Vector2(md * 0.7, hs * 0.46), b3 + Vector2(md, hs * 0.06), 5)
	var w0 := maxf(e * 1.6, hs * (0.26 if loin else 0.32))
	p.volume(Planche.ruban(ligne, w0, e * 0.4), teinte.darkened(0.12) if loin else teinte, Callable(), {"lourd": false, "cerne": 0.72})
	if m.cornes > 0.6 and not loin and not m.petit:
		# (de grandes mandibules : une dent en dedans)
		var q := ligne[3]
		p.volume(Planche.poly(PackedVector2Array([q + Vector2(-md * 0.1, -hs * 0.02), q + Vector2(md * 0.02, -hs * 0.2), q + Vector2(md * 0.1, 0)])), teinte, Callable(), {"lourd": false, "cerne": 0.6})


# la corne d'un scarabée : recourbée vers l'arrière, droite, ou ramifiée (un lucane)
static func _corne(p, m: Mesures, og: Dictionary) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var hs := m.hs
	var lc := hs * (0.5 + 1.5 * m.cornes)
	var base := m.o + Vector2(m.lhd * 0.34, -hs * 0.28)
	var forme := str(og.get("forme", ""))
	var bout := base + (Vector2(lc * 0.62, -lc * 0.8) if forme == "droites" else Vector2(lc * 0.1, -lc))
	var ligne := _courbe(base, base + (Vector2(lc * 0.3, -lc * 0.4) if forme == "droites" else Vector2(lc * 0.55, -lc * 0.45)), bout, 5)
	var w0 := maxf(e * 1.8, hs * 0.3)
	p.volume(Planche.ruban(ligne, w0, e * 0.6), m.t_tete.lerp(T["dos"], 0.3), func():
		_reflet(p, PackedVector2Array([ligne[1] + Vector2(-w0 * 0.2, 0), ligne[3] + Vector2(-w0 * 0.14, 0)]), 0.6, 0.75),
		{"lourd": false, "cerne": 0.85})
	if forme == "ramifiees":
		var q := ligne[3]
		p.volume(Planche.ruban(_courbe(q, q + Vector2(lc * 0.2, -lc * 0.02), q + Vector2(lc * 0.34, -lc * 0.22), 3), w0 * 0.6, e * 0.5), m.t_tete.lerp(T["dos"], 0.3), Callable(), {"lourd": false, "cerne": 0.8})


# une pince (un scorpion, un crabe) : le bras plié, la main renflée, deux doigts qui s'ouvrent vers l'avant
static func _pince(p, m: Mesures, og: Dictionary, loin: bool) -> void:
	var T: Dictionary = p.tons
	var e: float = p.e
	var gros := 1.45 if str(og.get("forme", "")) == "massives" else 0.8
	var lp := m.pinces
	var teinte: Color = m.t_patte_loin.lerp(m.t_corselet, 0.35) if loin else m.t_corselet
	var epaule := Vector2(m.xa - m.lth * 0.08, m.yt + m.hth * 0.22) + (Vector2(m.lth * 0.16, -m.hth * 0.25) if loin else Vector2.ZERO)
	var coude := epaule + Vector2(lp * 0.36, m.th * (0.0 if loin else 0.14))
	var poignet := coude + Vector2(lp * 0.24, -lp * (0.32 if loin else 0.2))
	var w := maxf(e * 1.6, m.th * 0.17 * gros)
	p.volume(Planche.ruban(PackedVector2Array([epaule, coude, poignet]), w, w * 0.85), teinte, Callable(), {"lourd": false, "cerne": 0.85})
	var dir := Vector2(1.0, -0.5 if loin else -0.3).normalized()
	var t := dir.orthogonal()
	var lm := lp * 0.2 * sqrt(gros)
	var rm := m.th * 0.2 * gros
	var centre := poignet + dir * lm * 0.6
	var bf := centre + dir * lm * 0.7
	var lf := lp * (0.3 if gros > 1.0 else 0.4)
	# (le doigt fixe, dessous ; le doigt mobile, dessus, plus court)
	p.volume(Planche.ruban(_courbe(bf - t * rm * 0.45, bf + dir * lf * 0.55 - t * rm * 0.8, bf + dir * lf + t * rm * 0.05, 4), maxf(rm * 0.75, e * 1.4), e * 0.4), teinte, Callable(), {"lourd": false, "cerne": 0.8})
	p.volume(Planche.ruban(_courbe(bf + t * rm * 0.5, bf + dir * lf * 0.5 + t * rm * 1.15, bf + dir * lf * 0.9 + t * rm * 0.45, 4), maxf(rm * 0.62, e * 1.3), e * 0.4), teinte, Callable(), {"lourd": false, "cerne": 0.8})
	p.volume(Planche.ferme(Planche.ellipse(centre, lm, rm, 8, dir.angle()), 1.0), teinte, func():
		if not loin:
			_reflet(p, PackedVector2Array([centre - dir * lm * 0.5 + t * rm * 0.45, centre + dir * lm * 0.4 + t * rm * 0.45]), 0.6, 0.75),
		{"lourd": false, "cerne": 0.85})


# une collerette : une plaque dressée derrière la tête, lisse ou frangée
static func _collerette(p, m: Mesures, og: Dictionary) -> void:
	var T: Dictionary = p.tons
	var r := m.hs * (0.7 + 0.8 * _taille(og))
	var ctr := m.o + Vector2(-m.lhd * 0.4, -m.hs * 0.05)
	var frange := str(og.get("forme", "")) == "frangee"
	var pts := PackedVector2Array()
	var k := 9
	for i in k:
		var a := lerpf(-PI * 0.95, -PI * 0.25, float(i) / (k - 1)) - 0.5
		var rr := r * (1.0 if not frange or i % 2 == 0 else 0.8)
		pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	pts.append(ctr + Vector2(m.lhd * 0.1, m.hs * 0.2))
	p.volume(Planche.poly(pts) if frange else Planche.ferme(pts, 0.8), T["accent"], func():
		for i in range(1, k - 1, 2):
			p.tracer("M%s L%s" % [Planche.pt(ctr), Planche.pt(pts[i])], p.e * 0.45, T["encre"], 0.5),
		{"lourd": false, "cerne": 0.85})
