extends Node2D
# Lisière — un galet, tiré au lance-pierre (scripts/galet.gd)
# Il part de la main de la veilleuse, file vers ce qu'elle vise en montant un peu, et retombe ; son ombre court au sol sous
# lui. Il suit d'un rien la bête visée (elle a fait un pas pendant qu'il volait) ; arrivé, il le dit au jeu
# (scripts/principal.gd, galet_arrive), qui voit s'il a touché. Un seul nœud, redessiné tant qu'il vole : une demi-seconde.

const R := preload("res://scripts/regles.gd")
const P := preload("res://scripts/palette.gd")

var jeu
var cible = null              # la bête visée (null : droit devant)
var de := Vector2.ZERO        # d'où il est parti
var vers := Vector2.ZERO      # où il tombe
var _t := 0.0
var _duree := 0.3
var _haut := 0.0              # sa hauteur au-dessus du sol, cette image
var _main := 20.0             # la hauteur de la main qui l'a lâché
var _avant := Vector2.ZERO


# où l'on vise une bête : le milieu de son corps
static func vise(b) -> Vector2:
	return b.position + Vector2(0.0, -float(b.largeur) * 0.22)


# depuis : au sol, sous la main qui le lâche (pour que le tri des profondeurs le range bien) ; hauteur : celle de cette main
func partir(depuis: Vector2, hauteur: float, jusqu_a: Vector2) -> void:
	_main = hauteur
	de = depuis
	vers = jusqu_a
	position = de
	_avant = de
	_duree = maxf(0.12, de.distance_to(vers) / R.VITESSE_GALET)
	_haut = _main


func _process(delta: float) -> void:
	if jeu == null or jeu.en_pause:
		return
	_t += delta
	var k := clampf(_t / _duree, 0.0, 1.0)
	if cible != null and is_instance_valid(cible) and cible.is_in_group("betes"):
		vers = vers.lerp(vise(cible), minf(1.0, delta * 5.0))
	_avant = position
	position = de.lerp(vers, k)
	# (tendu : il monte à peine, et descend de la hauteur de la main jusqu'à celle de ce qu'il vise)
	_haut = lerpf(_main, 8.0, k) + sin(k * PI) * minf(14.0, de.distance_to(vers) * 0.05)
	queue_redraw()
	if k >= 1.0:
		set_process(false)
		jeu.galet_arrive(self)
		queue_free()


func _draw() -> void:
	# son ombre, au sol ; lui, au-dessus, et le trait de sa course
	draw_circle(Vector2.ZERO, 1.6, Color(P.ENCRE, 0.22))
	var ici := Vector2(0.0, -_haut)
	var sillage := (_avant - position).limit_length(16.0)
	draw_line(ici + sillage, ici, Color(P.IVOIRE, 0.3), 1.2, true)
	draw_circle(ici, 2.1, P.ENCRE)
	draw_circle(ici, 1.5, Color("aaa395"))
