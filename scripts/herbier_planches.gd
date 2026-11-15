extends RefCounted
# Lisière — les planches de l'herbier (scripts/herbier_planches.gd)
# Chaque herbe (scripts/botanique.gd) sur une planche de naturaliste, à l'encre, pour la page de l'herbier
# (scripts/interface_atelier.gd) ; et sa vignette, pour les tuiles. (Une marque provisoire, en attendant leur dessin.)

const Icones := preload("res://scripts/atelier_icones.gd")


# la planche de cette herbe, dans ce cadre ; son signe (« rouge », « duvet », « miel », « lait », "") ; connue : faux pour
# une herbe qu'on n'a pas encore cueillie (sa silhouette seulement)
static func planche(ci: CanvasItem, id: String, cadre: Rect2, _signe: String, connue: bool) -> void:
	vignette(ci, id, cadre.get_center(), minf(cadre.size.x, cadre.size.y) * 0.7, connue)


# la même herbe, en petit (de 28 à 96 points)
static func vignette(ci: CanvasItem, _id: String, centre: Vector2, taille: float, connue: bool) -> void:
	if connue:
		Icones.icone(ci, "simples", centre, taille)
	else:
		Icones.esquisse(ci, "simples", centre, taille, 0.62)
