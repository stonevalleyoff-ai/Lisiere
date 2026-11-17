extends RefCounted
# Lisière — ce qui fait un pays (scripts/biomes.gd)
# Pour Lisière, un biome d'Orvane, c'était cinq nombres (sa température, son humidité, son altitude, son couvert, son milieu) :
# de là venaient son sol, ses plantes, son temps. Ça ne suffisait pas : d'un pays à l'autre, on jouait la même partie. Quatre
# pays ont maintenant un caractère à eux, pour qu'y aller soit une décision : chacun pose son problème (un climat qui presse, un
# sol qui piège) et offre ce qu'on ne trouve pas ailleurs.
#  - la banquise : un froid qui tue une nuit sans feu (la pelisse, un feu) ; une neige qui ne fond jamais, où l'on marche moins
#    vite ; la tourmente (le vent, la neige qui aveugle, le froid qui mord, le feu qui dévore son bois). Pas un arbre : le bois,
#    c'est la mer qui le rapporte sur le rivage (le bois flotté) ; sous la glace des mares, de l'eau pour la gourde ;
#  - le volcan : un sol chaud ; les fumerolles crachent une vapeur qui brûle, mais leur bord tient chaud la nuit ; les failles
#    rougeoient (y mettre le pied, c'est prendre feu) ; il pleut des cendres. L'obsidienne s'y taille : une lance ;
#  - le marais : la boue, l'eau dormante, le brouillard ; les fondrières avalent qui s'y arrête, et ses sangsues ; les feux
#    follets, la nuit. La tourbe, qui tient un feu bien plus longtemps qu'une bûche ;
#  - le désert : des jours qui brûlent (l'ombre, une tente, une gorgée sauvent), des nuits qui gèlent, la canicule en toute
#    saison sauf l'hiver, le vent de sable (un vent brûlant, qui aveugle et freine) ; le sable freine le pas. De vieilles
#    carcasses ensablées : de la ferraille.
# Le jeu lit ce tableau : le climat (scripts/climat.gd : l'air, le sol, le temps qui vient), et le sol avec ce qu'on y trouve
# (scripts/biome_terrain.gd). Ce que chaque chose fait au corps se règle dans scripts/regles.gd (« les biomes »).

# l'identité d'un pays, par l'id de son biome :
#  - air_jour, air_nuit : ce qu'il ajoute à l'air le jour, et la nuit (en plus de ce que la nuit retire partout) ;
#  - neige_fond : le manteau de neige qui ne fond jamais ; sol_frein : ce que son sol retire à l'allure (le sable) ;
#  - temps : ce qui y vient plus souvent, [ce qu'on multiplie au poids du tirage, ce qu'on lui ajoute] (scripts/climat.gd) ;
#    canicule : les saisons où elle peut venir, même hors de l'été ;
#  - sorts : ce que son sol porte, combien par case de 600 pixels (un nombre au-dessus de 1 : plusieurs) ; les dunes, les
#    scories ne sont que le sol même, qu'on voit ;
#  - dit : ce qu'on en dit en y entrant, une fois par partie.
const IDENTITES := {
	"banquise": {
		"nom": "la banquise",
		"air_jour": -0.02, "air_nuit": -0.1,
		"neige_fond": 0.6,
		"temps": {"tourmente": [1.0, 0.45], "neige": [1.4, 0.0]},
		# (le bois flotté : rare loin de l'eau, il s'entasse sur le rivage)
		"sorts": {"bois_flotte": 0.12, "rivage": 0.7, "mare": 0.3},
		"dit": "La banquise. Une nuit sans feu y tue, la tourmente aveugle. Pas un arbre : le bois, c'est la mer qui le rapporte sur le rivage.",
	},
	"volcan": {
		"nom": "le volcan",
		"air_jour": 0.02, "air_nuit": 0.0,
		"temps": {"cendres": [1.0, 0.3]},
		"sorts": {"scories": 1.6, "fumerolle": 0.8, "faille": 0.55, "obsidienne": 0.4},
		"dit": "Le volcan. Le sol est chaud : les fumerolles crachent, les failles rougeoient, n'y mets pas le pied. L'obsidienne s'y taille.",
	},
	"marais": {
		"nom": "le marais",
		"temps": {"brouillard": [3.0, 0.4]},
		"sorts": {"fondriere": 2.2, "tourbe": 0.4},
		"dit": "Le marais. Les fondrières avalent qui s'y arrête : ne reste pas plantée là. La tourbe y tient un feu longtemps.",
	},
	"desert": {
		"nom": "le désert",
		"air_jour": 0.02, "air_nuit": -0.36,
		"sol_frein": 0.08,
		"temps": {"sable": [1.0, 0.6], "canicule": [1.0, 0.5]},
		"canicule": ["printemps", "été", "automne"],
		"sorts": {"dune": 2.6, "carcasse": 0.26},
		"dit": "Le désert. Le jour brûle (cherche l'ombre), la nuit gèle (fais du feu). Le sable cache de vieilles carcasses : de la ferraille.",
	},
}

# ce que chaque sorte de chose ramassée dans ces pays donne, et ce qu'on en dit la première fois
const BUTINS := {
	"bois_flotte": {"donne": "bois", "n": 2, "parts": 3, "geste": "brindille", "son": "bois",
		"dit": "Du bois flotté, blanchi par le sel. Ici, c'est le seul bois : la mer en rapporte sur le rivage."},
	"obsidienne": {"donne": "obsidienne", "n": 1, "parts": 3, "geste": "rocher", "son": "pierre",
		"dit": "De l'obsidienne : un verre noir, plus tranchant qu'une lame. À l'établi, avec du bois et une corde, elle fait une lance."},
	"tourbe": {"donne": "tourbe", "n": 1, "parts": 3, "geste": "rocher", "son": "herbe",
		"dit": "De la tourbe. Sèche, elle tient un feu bien plus longtemps qu'une bûche : nourris-en le feu (F)."},
	"carcasse": {"donne": "ferraille", "n": 1, "parts": 3, "geste": "rocher", "son": "pierre",
		"dit": "Une vieille carcasse, à demi ensablée : de la ferraille, pour la popote, la lampe, les piles."},
	"mare": {"donne": "eau", "n": 0, "parts": 99, "geste": "rocher", "son": "pierre",
		"dit": "Tu brises la glace de la mare : de l'eau, autant que ta gourde en tient."},
}


# l'identité de ce biome ({} : un pays sans caractère à lui)
static func de(id: String) -> Dictionary:
	return IDENTITES.get(id, {})
