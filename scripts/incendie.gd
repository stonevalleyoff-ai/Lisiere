extends Node
# Lisière — l'incendie (scripts/incendie.gd)
# La foudre met le feu à ce qu'elle frappe (scripts/climat.gd). Un arbre, un buisson, une touffe en feu brûle quelques secondes
# (scripts/regles.gd, INCENDIE_DUREE), éclaire comme un feu de camp (les chasseurs n'entrent pas dans sa lumière : c'est un
# refuge, et un danger), chauffe, met le feu à qui le touche, et saute à ses voisins : plus loin sous le vent, presque jamais
# sous la pluie ni sur un sol détrempé, et de moins en moins fort à chaque saut (il s'essouffle : un incendie laisse une
# clairière brûlée, il ne rase pas le lieu). La pluie l'éteint. Brûlé jusqu'au bout, un arbre n'est plus qu'une souche noire ; un
# buisson, une touffe repousseront. Au plus INCENDIE_MAX objets brûlent à la fois.
#   jeu.incendie.enflammer(objet) ; .chaleur(p) (de 0 à 1) ; .contact(p) ; .foyers (pour la lumière et les bêtes)

signal pris(objet)            # un objet vient de prendre feu
signal fini(objet, brule: bool)   # il ne brûle plus (brule : jusqu'au bout ; sinon la pluie l'a éteint)

const R := preload("res://scripts/regles.gd")

# ce que les bêtes et la lumière lisent d'un objet en feu, avec les noms d'un feu de camp (scripts/feu.gd)
class Foyer:
	var objet
	var position := Vector2.ZERO
	var force := 1.0          # ce qu'il lui reste d'élan pour sauter aux voisins (1 : frappé par la foudre ; moins à chaque saut)
	var _r := 60.0

	func allume() -> bool:
		return is_instance_valid(objet) and objet.brule > 0.0

	func rayon() -> float:
		return _r

	func eclaire(p: Vector2) -> float:
		return clampf((_r - p.distance_to(position)) / (_r * 0.4), 0.0, 1.0)


var jeu
var foyers: Array = []        # un Foyer par objet en feu
var _saut := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()


func vider() -> void:
	foyers.clear()


func enflammer(o, force: float = 1.0) -> bool:
	if o == null or not is_instance_valid(o) or not o.combustible() or foyers.size() >= R.INCENDIE_MAX:
		return false
	var genre: String = o.genre
	o.enflammer(float(R.INCENDIE_DUREE.get(genre, 8.0)) * _r.randf_range(0.85, 1.15))
	var f := Foyer.new()
	f.objet = o
	f.position = o.position
	f.force = force
	f._r = float(R.INCENDIE_LUEUR.get(genre, 60.0))
	foyers.append(f)
	pris.emit(o)
	return true


func brule() -> bool:
	return not foyers.is_empty()


# la chaleur des flammes en p, de 0 à 1 (au contact)
func chaleur(p: Vector2) -> float:
	var c := 0.0
	for f in foyers:
		c = maxf(c, clampf(1.0 - (p.distance_to(f.position) - R.INCENDIE_CONTACT) / (f._r * 0.55), 0.0, 1.0))
	return c


# touche-t-on un objet en feu ?
func contact(p: Vector2) -> bool:
	for f in foyers:
		if p.distance_to(f.position) < R.INCENDIE_CONTACT:
			return true
	return false


func _process(delta: float) -> void:
	if jeu == null or not jeu.en_partie or jeu.en_pause or foyers.is_empty():
		return
	avancer(delta)


func avancer(delta: float) -> void:
	var climat = jeu.climat
	var pluie: float = climat.pluie if climat != null else 0.0
	var boue: float = climat.boue if climat != null else 0.0
	var i := 0
	while i < foyers.size():
		var f: Foyer = foyers[i]
		var o = f.objet
		if not is_instance_valid(o):
			foyers.remove_at(i)
			continue
		o.brule -= delta
		# (la pluie l'éteint, d'autant plus vite qu'elle est forte)
		if pluie > 0.3 and _r.randf() < pluie * 0.22 * delta:
			o.eteindre()
			foyers.remove_at(i)
			fini.emit(o, false)
			continue
		if o.brule <= 0.0:
			o.calciner()
			foyers.remove_at(i)
			fini.emit(o, true)
			continue
		i += 1
	# toutes les deux secondes, le feu cherche à sauter
	_saut -= delta
	if _saut > 0.0 or jeu.monde == null:
		return
	_saut = 2.0
	# (la pluie, un sol détrempé, un lieu humide le retiennent ; la canicule l'attise)
	var prise := R.INCENDIE_PRISE * (1.0 - 0.9 * pluie) * (1.0 - 0.6 * boue)
	if climat != null:
		prise *= (1.15 - 0.5 * climat.humide) * (1.0 + 2.0 * climat.chaleur)
	if prise <= 0.005:
		return
	var vent: Vector2 = (climat.vent_dir * climat.vent) if climat != null else Vector2.ZERO
	for f in foyers.duplicate():
		if foyers.size() >= R.INCENDIE_MAX:
			break
		for o in jeu.monde.autour(f.position, R.INCENDIE_PORTEE * 1.6):
			if not o.combustible():
				continue
			# (sous le vent, il porte plus loin ; contre lui, moins)
			var d: Vector2 = o.position - f.position
			var portee := R.INCENDIE_PORTEE * (1.0 + 0.6 * d.normalized().dot(vent))
			if d.length() < portee and _r.randf() < prise * f.force:
				enflammer(o, f.force * R.INCENDIE_ESSOUFFLE)


# --- une partie gardée : ce qui brûlait est gardé comme brûlé (scripts/partie_gardee.gd) ---

func finir_tout() -> void:
	for f in foyers:
		if is_instance_valid(f.objet):
			f.objet.calciner()
	foyers.clear()
