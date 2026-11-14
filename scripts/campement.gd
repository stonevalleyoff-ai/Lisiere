extends Node2D
# Lisière — une chose posée dans le lieu (scripts/campement.gd)
# Ce que la veilleuse monte de ses mains et laisse au sol : l'établi, la tente, le hamac, le récupérateur d'eau, le filet, le
# cerf-volant ; et les vestiges d'autres veilleuses, où elle trouve de la ferraille. Ici, son dessin et sa vie (elle bouge au
# vent, se remplit, s'use) ; ce qu'elle fait au jeu est dans scripts/atelier.gd, qui lui dit son état :
#   genre  : « etabli », « tente », « hamac », « recuperateur », « filet », « cerf_volant », « vestige »
#   etat   : ce que l'atelier lui dit, et qu'elle montre
#     etabli       : « travail » (de 0 à 1 : on y fabrique quelque chose, des copeaux volent)
#     tente, hamac : « occupe » (vrai : la veilleuse y dort)
#     recuperateur : « eau » (de 0 à 6 : ce qu'il tient)
#     filet        : « prise » ({ nom, masse } : une bête s'y est prise, elle se débat)
#     cerf_volant  : « vent » (de 0 à 1), « branche » (vrai : les piles sont au fil), « charge » (de 0 à 1), « foudre » (un
#                    instant : la foudre vient de le prendre)
#     vestige      : « fouille » (vrai : il n'y a plus rien), « riche » (0 ou 1)
# Son pied est à l'origine (0, 0) : le lieu trie ce qui s'y tient par hauteur (monde.gd).

var jeu
var genre := ""
var etat := {}


func _ready() -> void:
	add_to_group("campement")


func _process(_delta: float) -> void:
	queue_redraw()


# (en attendant son vrai dessin : une marque au sol, et son nom)
func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.3, 0.24, 0.18, 0.8))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.09, 0.08, 0.06), 1.5, true)
