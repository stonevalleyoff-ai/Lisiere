extends SceneTree
# Lisière — l'icône en images (outils/icone.gd)
# Rend icon.svg (outils/icone.js la dessine) en PNG, avec le rendu SVG de Godot, pour l'application qu'on installe (outils/pwa.js) :
#   - « any » : les coins arrondis, pour un bureau, un onglet, la liste des applications ;
#   - « maskable » : pleine, sans coins ; Android la découpe à sa façon (ce qui compte tient dans le cercle du milieu) ;
#   - « apple » : pleine aussi, iOS arrondit lui-même.
#   outils/godot.sh --headless --path . --script res://outils/icone.gd

const SOURCE := "res://icon.svg"
const DOSSIER := "res://application/"
# (le nom, la taille, les coins arrondis)
const IMAGES := [
	["lisiere-512.png", 512, true],
	["lisiere-192.png", 192, true],
	["lisiere-masquable-512.png", 512, false],
	["lisiere-masquable-192.png", 192, false],
	["lisiere-apple-180.png", 180, false],
]
const COINS := 0.2            # le rayon des coins, en part de la largeur


func _init() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		printerr("icone.gd : pas de %s (node outils/icone.js le dessine)" % SOURCE)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	for i in IMAGES:
		var img := Image.new()
		var err := img.load_svg_from_string(svg, float(i[1]) / 512.0)
		if err != OK or img.get_width() != i[1]:
			printerr("icone.gd : %s ne se rend pas (%s)" % [i[0], error_string(err)])
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		if i[2]:
			_arrondir(img, COINS * i[1])
		img.save_png(DOSSIER + i[0])
		print("  %s (%d px)" % [i[0], i[1]])
	quit(0)


# les coins arrondis, adoucis sur un pixel
func _arrondir(img: Image, r: float) -> void:
	var w := img.get_width()
	for y in w:
		for x in w:
			# la distance au coin le plus proche, quand on est dans un coin
			var cx := clampf(x + 0.5, r, w - r)
			var cy := clampf(y + 0.5, r, w - r)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > r - 1.0:
				var c := img.get_pixel(x, y)
				c.a *= clampf(r - d + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, c)
