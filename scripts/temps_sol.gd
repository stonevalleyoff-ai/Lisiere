extends Node2D
# Lisière — ce que le temps fait au sol (scripts/temps_sol.gd)
# Le sol détrempé, les flaques, l'eau montée dans les creux, la neige qui tient, le présage de la foudre et la foudre elle-même :
# ce que le temps qu'il fait (scripts/climat.gd) dessine dans le lieu. principal.gd le pose à chaque nouvelle partie, après que
# le climat du lieu est prêt ; il part avec la scène.

var jeu


# la scène du lieu (le sol, puis le monde et ce qui s'y tient debout, trié par y), au début d'une partie
func poser(_scene: Node2D, _monde: Node2D) -> void:
	pass
