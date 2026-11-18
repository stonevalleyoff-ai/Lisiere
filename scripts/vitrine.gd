extends Node
# Lisière — la vitrine (scripts/vitrine.gd)
# Une scène jouée toute seule, pour regarder le jeu et le filmer : un lieu, une heure, un feu, des bêtes de chaque sorte, et la
# veilleuse qui fait ce qu'on fait en jouant (attendre au feu, marcher, couper un arbre, cueillir, chasser, se faire mordre).
# Rien n'est vérifié ici (c'est le travail de l'essai) : on regarde.
#   outils/godot.sh --path . -- --vitrine [--heure jour|soir|nuit|aube] [--duree 12] [--lieu foret]
#   outils/film.sh <dossier> -- --vitrine --heure nuit      (filmée image par image, et sa planche-contact)
# Le temps qu'il fait, montré (scripts/climat.gd) : --temps pluie|orage|crue|neige|brouillard|canicule|incendie. La veilleuse
# attend, tourne, puis va là où ça se passe (sous un arbre, dans l'eau, près de l'arbre frappé, contre les flammes).
#   --image <chemin> --a 0.3,0.6,0.9   écrit <chemin>_1.png, _2.png… à ces moments (en fractions de la durée)
#   --ouvert   le lieu sans bord (MONDE-OUVERT.md) : la veilleuse marche droit devant elle
#   --doigt    les boutons tactiles, comme sur un téléphone ; --carte : à la fin, la pause et la carte du carnet (et ses repères) ;
#   --carte toute : tout dévoilé (les régions de terre du monde, ou tout le lieu), la carte seule, en plein écran, de loin ;
#   --depuis x,y : d'où elle part ; --pont : au bord d'une rivière, elle pose un pont de fortune et le passe
#   --reste : elle ne bouge pas ; --vers x,y : elle marche vers ce point ; --recul 0.4 : la caméra recule d'autant (voir le
#   relief d'un pays, le plan d'une grotte) ; --torche : elle part une torche à la main
#   --herbier fichier.json : l'herbier d'un biome d'Orvane, donné à la main (voir sa flore sans le réseau)
#   --sans-feu : la nuit, pas de feu de camp (les chasseurs autour de la seule torche)
#   --meute 3 : tant de chasseurs, pour regarder leur affût autour du feu (scripts/affut.gd) ; elle ne bouge pas, ou : --sort
#   (elle sort de la lumière), --dos (elle tourne le dos au plus proche, puis se retourne), --marche (elle fait quelques pas
#   vers lui) ; --torche (avec --sans-feu) ; --bois 15 : le bois de son feu ; --hate 4 : leur patience quatre fois plus
#   courte ; --trace fichier : où ils sont, cinq fois par seconde (outils : un script qui en dessine les chemins)
#   --noire 2|3|4 : la Noire à cet acte (scripts/noire.gd) ; --noire dort, --noire piste : de jour, sa tanière, sa piste ;
#   --noire reveil : de jour, endormie puis réveillée (sa charge, sa morsure, son départ, en pleine lumière)
#   la fin de la Noire (scripts/noire_collet.gd) : --noire collet : la nuit, un collet amorcé qui sent la main, hors de la
#   lumière ; elle y vient la tête basse, le flaire, renâcle et s'en détourne ; --noire prise : le nœud vient de se serrer, elle
#   se jette au bout du filin, la veilleuse au bout de sa portée, lance en main (--frappe : elle frappe quand la lance porte,
#   jusqu'à la cicatrice ; --dedans : elle se tient dans sa portée, et se fait mordre) ; --noire part : l'aube de son départ
#   (le collet rompu, sa piste qui sort du lieu, puis la page « Elle est partie. » ; --page depart : la page tout de suite ;
#   --aupres couche : devant sa couche vide) ; --noire cicatrices 2 : de jour, à deux pas, avec tant de cicatrices, puis elle
#   s'en va (elle boite à deux) ; --cicatrices 2 : avec n'importe quelle autre scène d'elle ; --carnet avec --noire part : sa
#   dernière page ; --pose collet,collet,collet,couche --etat planche : le collet tendu et amorcé, serré, rompu, et la couche
#   (--etat amorce|serre|rompu|fouillee : cet état pour tous)
#   la faim, son cinquième acte (scripts/noire_faim.gd) : --noire 5 : la nuit de la faim, elle en chemin ; --noire saccage :
#   le feu bas, ce qu'on a posé (--pose tente,epouvantail,filet…) est hors de sa lumière : elle y va, le flaire, le met en
#   pièces (--duree 30 pour tout voir ; avec --compagne longe,piquet et --pose piquet : elle prend la bête) ; --noire
#   crepuscule : le jour baisse, elle appelle et arrive avant la nuit ; --etat saccage : ces choses en épaves (gauche : elle
#   tirait de l'autre côté) ; --etat mordu : dans sa gueule, secouées ; --etat rompue : au piquet, le bout de longe qu'elle a laissé
#   l'atelier (scripts/atelier.gd) : --pose etabli,tente,hamac,recuperateur,filet,cerf_volant,vestige : ces choses, posées
#   autour d'elle dans une clairière ; --etat travail,occupe,eau,prise,branche,foudre,fouille,popote : dans cet état ;
#   --tenue sac,chaud,pluie,lampe : ce qu'elle porte ; --geste marteler : ce geste, repris ; --dort ; --page etabli|sac
#   (--nourrir : le sac plein de la cueillette nourricière) ;
#   --fabrique tente,popote : à l'établi, elle fabrique ces choses l'une après l'autre ; --aupres tente : elle se tient
#   près de cette chose (avec --dort : elle s'y couche)
#   l'artisanat des plantes : --artisanat (avec --page : la fibre longue, le filin, les aromates, leur baume, un grand filet,
#   une longe de filin dans le sac) ; --pose filet_filin ; --compagne longe ; --botanique encens,onguent,parfum ; --filin (avec
#   --pont : le pont se lie de filin) ; --pont-ici : un pont lié de filin posé devant elle, pour le regarder (sans rivière) ;
#   --compagne longe,piquet,affolee : sa bête au piquet posé (--pose piquet), la nuit déjà affolée ; --loupe 2 : la caméra
#   deux fois plus près
#   les herbes (scripts/botanique.gd) : --botanique poison,torpeur,visions,voyance,calme,fumee : cet état, tenu ; --herbes :
#   son sac plein des herbes du lieu, la moitié reconnues, un mortier, une popote ; --geste gouter|piler|jeter
#   le jardin, l'élevage : --pose carre,epouvantail,piquet,mangeoire,appat ; --etat lin,fleur,eau (ou baie, simple ; semis,
#   pousse, mur ; gel ; regard, alerte ; foin ; attache) ; --compagne licol,selle,sacoche,grande,reste,monte : une bête à elle
#   la cueillette (scripts/flore.gd) : --cueillette : elle va de fleur en champignon des bois, et les cueille (avec --ouvert
#   --depuis x,y : dans le biome de son choix) ; --fruits : elle va d'arbre en arbre, ramasse les fruits tombés et cueille
#   ceux des branches (et les épis mûrs, le lichen des rennes, la pulpe des cactus) ; --planche arbres|sol|geste|secouer : une planche de la cueillette nourricière, posée dans une clairière à côté
#   d'elle, de près (les arbres et leurs fruits, à chaque état ; les épis, le lichen, le cactus, les grains au jardin ; « geste » :
#   elle cueille un pommier, de tout près ; « secouer » : un palmier, trop haut pour son bras, elle en secoue le fût) ; --gros : la caméra va de l'une à l'autre, de tout près
#   la flore de l'herbier (scripts/flore_dessins.gd) : --planche flore --lieu marais : toutes les plantes de l'herbier du biome,
#   côte à côte, chacune à sa taille (celle que lui donne le monde d'après sa hauteur d'Orvane), la veilleuse à gauche pour
#   l'échelle, la planche d'Orvane de chacune à sa droite, son nom, sa forme, sa hauteur et ses caractères dessous ; le cadre
#   se règle tout seul. --strate arbre,buisson,sol,eau,champignon : ces strates seulement (de plus près) ; --formes cactus,agave :
#   ces formes seulement ; --fois 3 : trois individus de chacune (trois graines) ; --etat entame,cueilli,neige,feu,roussi,
#   calcine,souche,printemps,automne,hiver,sans-fruits : toutes dans cet état ; --sans-orvane : sans les planches d'Orvane ;
#   --sur-le-sol : sur le vrai sol du lieu (sinon, un fond uni à sa couleur) ; --derriere : la veilleuse derrière le plus haut des arbres ;
#   --toutes : toutes les formes que Lisière sait dessiner (même celles que l'herbier du lieu n'a pas), une de chaque
#   --mesure   dit toutes les cinq secondes les images par seconde, la plus longue image, les appels de dessin
#   --sans son,ciel,sol,flammes,effets   éteint une chose, pour chercher ce qui coûte

const R := preload("res://scripts/regles.gd")

var jeu
var heure := "nuit"
var duree := 12.0
var lieu := "foret"
var _t := 0.0
var _pret := false
var _plan: Array = []          # [debut, fin, geste]
var _fait := {}
var _coup := 0.0
var temps := ""
var image := ""
var moments: Array = []
var _but := Vector2.ZERO
var _regles := {}              # (l'atelier : --boue, --crue, --neige-sol, --force, --vent, --corps (sa température), pour voir un état précis ;
								# le corps qui faiblit, tenu : --sante 15, --faim 5, --peur 90 : scripts/effets.gd, _le_corps)
# (l'atelier « feu » : --feu brasier|restes|pluie, --nu (sans l'interface), --appels (les appels de dessin, à la fin))
var feu := ""
var nu := false
var appels := false
var _appels_max := 0
var _appels_somme := 0.0
var _appels_n := 0
var _geste_atelier := ""
var _page := ""
var _etats := {}
var _fabrique: PackedStringArray = PackedStringArray()
var _fabrique_k := 0
var _dormir_dans = null
var _affolee = null            # (--compagne affolee) la bête qu'on tient affolée au bout de sa longe, même de jour
var _botanique := {}
var _geste_atelier_t := 0.0
var _brules: Array = []
var _meute := 0                # (--meute) combien de chasseurs, pour regarder leur affût
var _trace: FileAccess = null  # (--trace) où ils sont, cinq fois par seconde
var _trace_t := 0.0
var _planche: Array = []       # (--planche) ce qui y est posé ; avec --gros, la caméra va de l'un à l'autre, de tout près
var _fin_noire := ""           # (--noire collet|prise|part|cicatrices) la scène de sa fin qu'on regarde
var _collet = null             # … et son collet
var _feu_tenu := -1.0          # (--noire saccage) le bois où l'on tient son feu, pour que le camp reste dans le noir (-1 : il brûle)


func _ready() -> void:
	jeu = get_parent()
	var a := OS.get_cmdline_user_args()
	for i in a.size() - 1:
		match a[i]:
			"--heure":
				heure = a[i + 1]
			"--duree":
				duree = float(a[i + 1])
			"--lieu":
				lieu = a[i + 1]
			"--temps":
				temps = a[i + 1]
			"--feu":
				feu = a[i + 1]
				temps = "incendie"
			"--image":
				image = a[i + 1]
			"--boue", "--crue", "--neige-sol", "--force", "--vent", "--corps", "--sante", "--faim", "--peur":
				_regles[a[i]] = float(a[i + 1])
			"--a":
				for x in a[i + 1].split(","):
					moments.append(float(x))
	nu = a.has("--nu")
	appels = a.has("--appels")
	_lancer.call_deferred()


func _lancer() -> void:
	jeu.donnees.hors_ligne_force = true
	await jeu.donnees.charger_index()
	await jeu._commencer(lieu, {}, OS.get_cmdline_user_args().has("--ouvert"))
	var soir: float = R.DUREE * (1.0 - jeu.part_nuit)
	match heure:
		"jour":
			jeu.horloge = R.TRANSITION + 30.0
		"soir":
			jeu.horloge = soir - R.TRANSITION * 0.6
		"aube":
			# (le jour qui se lève : ce que la nuit a laissé)
			jeu.horloge = R.DUREE + R.TRANSITION * 0.3
		_:
			jeu.horloge = soir + 12.0
	var j = jeu.joueur
	j.inventaire["bois"] = 40
	j.inventaire["pierre"] = 12
	j.inventaire["fibre"] = 12
	j.inventaire["baies"] = 3
	# (--sans-feu : la nuit sans feu de camp, pour regarder les chasseurs autour de la seule torche)
	if heure != "jour" and heure != "aube" and not OS.get_cmdline_user_args().has("--sans-feu"):
		jeu.fabriquer("feu")
		jeu.feux[0].ajouter(3)
	# (--lance : elle a trouvé la lance ; --tir : elle a un lance-pierre et des galets, et tire toutes les secondes)
	if OS.get_cmdline_user_args().has("--lance"):
		j.lance = R.USURE_LANCE
	if OS.get_cmdline_user_args().has("--tir"):
		jeu.atelier.objets["lance_pierre"] = 1
		j.inventaire["galet"] = 40
	var F: Dictionary = jeu.faune
	for i in 3:
		if not F["proies_jour"].is_empty():
			jeu._creer(F["proies_jour"][i % F["proies_jour"].size()], "proie", j.position + Vector2.from_angle(i * 2.1 + 0.4) * randf_range(170.0, 260.0))
	if not F["rodeurs"].is_empty() and heure != "nuit":
		jeu._creer(F["rodeurs"][0], "rodeur", j.position + Vector2(-300, 120))
	# (--noire 2|3|4 : la Noire à cet acte, déjà en chemin ; --noire dort : de jour, couchée à deux pas ; --noire piste : de
	# jour, sa piste qui part du camp. Sans les chasseurs ordinaires, qu'elle ferait fuir.)
	var i_n := OS.get_cmdline_user_args().find("--noire")
	var quelle := OS.get_cmdline_user_args()[i_n + 1] if i_n >= 0 and i_n + 1 < OS.get_cmdline_user_args().size() else ""
	# (--meute 3 : tant de chasseurs, venus en bande du même côté, pour regarder leur affût autour du feu (scripts/affut.gd) ;
	# elle ne bouge pas. --sort : aux trois cinquièmes, elle sort de la lumière ; --dos : au tiers, elle tourne le dos au plus
	# proche, puis se retourne ; --marche : à mi-temps, elle fait quelques pas vers lui ; --torche (avec --sans-feu) : la nuit à
	# la torche ; --bois 15 : le bois de son feu (bas : 15 ; haut : 100) ; --hate 4 : leur patience quatre fois plus courte ;
	# --trace fichier : où ils sont, cinq fois par seconde (pour dessiner leurs chemins))
	var i_m := OS.get_cmdline_user_args().find("--meute")
	if i_m >= 0 and i_m + 1 < OS.get_cmdline_user_args().size():
		_meute = maxi(1, int(OS.get_cmdline_user_args()[i_m + 1]))
	if heure != "jour" and heure != "aube" and quelle == "" and _meute > 0:
		for i in _meute:
			jeu._creer(F["chasseurs_nuit"][i % F["chasseurs_nuit"].size()], "chasseur", j.position + Vector2.from_angle(1.0 + i * 0.12) * (430.0 + 30.0 * i))
	elif heure != "jour" and heure != "aube" and quelle == "":
		for i in 2:
			jeu._creer(F["chasseurs_nuit"][i % F["chasseurs_nuit"].size()], "chasseur", j.position + Vector2.from_angle(i * PI + 1.0) * 300.0)
	match quelle:
		"":
			pass
		"dort", "reveil":
			jeu.noire.acte = 2
			jeu.noire.taniere = j.position + Vector2(250.0, -30.0)
			jeu.noire.ou = jeu.noire.taniere
		"piste":
			jeu.noire.acte = 1
			jeu.noire.taniere = j.position + Vector2(3600.0, -900.0)
			jeu.noire._piste(j.position + Vector2(120.0, 60.0), jeu.noire.taniere)
		"collet", "prise", "part", "cicatrices":
			_la_fin_de_la_noire(quelle)
		"saccage", "crepuscule":
			# (la faim : mise en scène plus bas, une fois le camp posé)
			pass
		_:
			jeu.nuits = int(quelle) - 1 if int(quelle) < R.NOIRE_FAIM else jeu.noire.premiere_nuit(int(quelle))
			jeu._etait_nuit = true
			jeu.noire.mettre_en_scene(int(quelle), 700.0, PI * 0.92)
	# le plan de la veilleuse, en fractions de la durée
	_plan = [
		[0.0, 0.18, "attendre"],
		[0.18, 0.4, "tourner"],
		[0.4, 0.52, "couper"],
		[0.52, 0.62, "chasser"],
		[0.62, 0.7, "cueillir"],
		[0.7, 0.82, "torche"],
		[0.82, 1.0, "peur"],
	]
	if _meute > 0:
		var ar_m := OS.get_cmdline_user_args()
		_plan = [[0.0, 1.0, "attendre"]]
		if ar_m.has("--sort"):
			_plan = [[0.0, 0.6, "attendre"], [0.6, 1.0, "sortir"]]
		elif ar_m.has("--dos"):
			_plan = [[0.0, 0.33, "face"], [0.33, 0.7, "dos"], [0.7, 1.0, "face"]]
		elif ar_m.has("--marche"):
			_plan = [[0.0, 0.5, "attendre"], [0.5, 0.512, "vers"], [0.512, 1.0, "attendre"]]
		if ar_m.has("--torche"):
			jeu.fabriquer("torche")
		var i_bo := ar_m.find("--bois")
		if i_bo >= 0 and i_bo + 1 < ar_m.size() and not jeu.feux.is_empty():
			jeu.feux[0].bois = float(ar_m[i_bo + 1])
		var i_ha := ar_m.find("--hate")
		if i_ha >= 0 and i_ha + 1 < ar_m.size():
			load("res://scripts/affut.gd").hate = maxf(0.1, float(ar_m[i_ha + 1]))
		var i_tr := ar_m.find("--trace")
		if i_tr >= 0 and i_tr + 1 < ar_m.size():
			_trace = FileAccess.open(ar_m[i_tr + 1], FileAccess.WRITE)
	# (l'atelier, scripts/atelier.gd : --tenue sac,chaud,pluie,lampe : ce qu'elle porte ; --dort : elle dort ; --geste marteler :
	# ce geste d'atelier, repris sans cesse (marteler, scier, coudre, monter, fouiller, boire, remuer) ; --pose etabli,tente : ces
	# choses du camp, posées autour d'elle)
	var ar2 := OS.get_cmdline_user_args()
	var i_t := ar2.find("--tenue")
	if i_t >= 0 and i_t + 1 < ar2.size():
		var portee := {}
		for k in ar2[i_t + 1].split(","):
			portee[k] = true
		j.tenue = portee
	if ar2.has("--dort"):
		j.endormie = true
		_plan = [[0.0, 1.0, "attendre"]]
	var i_g := ar2.find("--geste")
	if i_g >= 0 and i_g + 1 < ar2.size():
		_geste_atelier = ar2[i_g + 1]
		_plan = [[0.0, 1.0, "attendre"]]
	# (--page etabli|sac : de quoi fabriquer, un établi posé à côté d'elle, puis cette page ouverte à mi-temps)
	var i_pg := ar2.find("--page")
	if i_pg >= 0 and i_pg + 1 < ar2.size() and jeu.atelier != null:
		_page = ar2[i_pg + 1]
		for k3 in ["bois", "pierre", "fibre", "peau", "ferraille", "corde", "bache"]:
			j.inventaire[k3] = 14
		j.inventaire["eau"] = 3
		jeu.atelier.objets = {"tente": 1, "gourde": 1, "sac_a_dos": 1, "lampe": 1, "piles": 1, "duvet": 1}
		# (--jardin : et de quoi jardiner, harnacher)
		if ar2.has("--jardin"):
			for k4 in ["houe", "arrosoir", "licol", "selle", "sacoche", "epouvantail"]:
				jeu.atelier.objets[k4] = 1
			for k4 in ["graine_baie", "graine_lin", "graine_simple"]:
				j.inventaire[k4] = 4
			j.inventaire["simples"] = 2
			j.inventaire["lait"] = 1
			j.inventaire["arrosages"] = 2
		# (--pays : et ce que donnent les pays, l'obsidienne, la tourbe ; scripts/biomes.gd)
		if ar2.has("--pays"):
			j.inventaire["obsidienne"] = 3
			j.inventaire["tourbe"] = 2
		# (--artisanat : et ce que donnent l'agave et les aromates ; scripts/atelier.gd, scripts/botanique.gd)
		if ar2.has("--artisanat"):
			j.inventaire["fibre_longue"] = 6
			j.inventaire["filin"] = 4
			j.inventaire["aromates"] = 7
			j.inventaire["baume_aromates"] = 1
			jeu.atelier.objets["longe"] = 1
			jeu.atelier.objets["filet_filin"] = 1
			jeu.atelier.objets["mortier"] = 1
		# (--nourrir : et ce que donne la cueillette nourricière, les fruits, les grains, le lichen, la pulpe, et ce que la
		# popote en a fait ; un mortier, une popote)
		if ar2.has("--nourrir"):
			for k4 in ["pomme", "figue", "coco", "pain_de_singe", "grains", "lichen", "pulpe", "gruau", "soupe_lichen"]:
				j.inventaire[k4] = 2 + k4.length() % 4
			jeu.atelier.objets["mortier"] = 1
			jeu.atelier.objets["popote"] = 1
		jeu.atelier.portes = {"sac_a_dos": true}
		jeu.atelier.charge = 62.0
		jeu.atelier._tenue()
		jeu.atelier._creer("etabli", j.position + Vector2(60.0, 10.0), {})
		_plan = [[0.0, 1.0, "attendre"]]
	var i_p := ar2.find("--pose")
	if i_p >= 0 and i_p + 1 < ar2.size() and jeu.atelier != null:
		var k2 := 0
		var quoi: PackedStringArray = ar2[i_p + 1].split(",")
		_plan = [[0.0, 1.0, "attendre"]]
		# (une clairière, que rien ne les cache ; un arbre y reste, pour le hamac)
		var garde = jeu.atelier._l_arbre(j.position + Vector2(-200.0, 30.0), 260.0) if quoi.has("hamac") else null
		for o in jeu.monde.autour(j.position, 330.0):
			if o != garde and (float(o.rayon) > 0.0 or str(o.genre) == "buisson"):
				jeu.monde.retirer(o)
		for g in quoi:
			var tour := Vector2.from_angle(-0.5 + TAU * float(k2) / float(quoi.size()))
			var ou: Vector2 = j.position + Vector2(tour.x * 150.0, tour.y * 105.0)
			if g == "hamac" and garde != null:
				ou = garde.position + Vector2(58.0, 12.0)
			jeu.atelier._creer(g, ou, {})
			k2 += 1
		# (--fabrique tente,popote,pelisse… : elle se tient à l'établi, et y fabrique ces choses l'une après l'autre ;
		# --aupres tente : elle se tient près de cette chose, pour un geste, pour y dormir)
		var i_f := ar2.find("--fabrique")
		var i_au := ar2.find("--aupres")
		var aupres := "etabli" if i_f >= 0 else (ar2[i_au + 1] if i_au >= 0 and i_au + 1 < ar2.size() else "")
		if i_f >= 0 and i_f + 1 < ar2.size():
			_fabrique = ar2[i_f + 1].split(",")
		for s in jeu.atelier.poses:
			if aupres != "" and str(s.genre) == aupres:
				j.position = s.position + Vector2(-38.0, 12.0)
				j.regard = 1.0
				if ar2.has("--dort") and aupres in ["tente", "hamac"]:
					j.endormie = false
					jeu.atelier.objets["duvet"] = 1
					_dormir_dans = s
		# (--etat occupe,eau,prise,branche,foudre,fouille,travail,popote : ces choses dans cet état, pour le voir)
		var i_e := ar2.find("--etat")
		if i_e >= 0 and i_e + 1 < ar2.size():
			for e in ar2[i_e + 1].split(","):
				_etats[e] = true
			for s in jeu.atelier.poses:
				match str(s.genre):
					"tente", "hamac":
						if _etats.has("occupe"):
							s.etat["occupe"] = true
					"recuperateur":
						if _etats.has("eau"):
							s.etat["eau"] = 4.6
					"filet":
						if _etats.has("prise"):
							s.etat["prise"] = {"id": "", "nom": "une bête", "masse": 2.4}
					"filet_filin":
						if _etats.has("prise"):
							s.etat["prise"] = {"id": "", "nom": "une bête", "masse": 24.0}
					"cerf_volant":
						if _etats.has("branche") or _etats.has("foudre"):
							jeu.atelier.objets["piles"] = 1
							jeu.atelier.fil = s
							jeu.atelier.charge = 35.0
							jeu.atelier.vent_force = 0.8
					"coffre":
						if _etats.has("ouvert"):
							s.etat["ouvert"] = true
					"collet":
						# (--etat planche : le premier tendu et amorcé, le deuxième serré, le troisième rompu)
						var rang_c: int = jeu.atelier.poses.filter(func(x): return str(x.genre) == "collet").find(s)
						var phase_c := ""
						if _etats.has("serre") or (_etats.has("planche") and rang_c == 1):
							phase_c = "serre"
						elif _etats.has("rompu") or (_etats.has("planche") and rang_c == 2):
							phase_c = "rompu"
						s.etat["phase"] = phase_c
						s.etat["amorce"] = phase_c == "" and (_etats.has("amorce") or _etats.has("planche"))
						s.etat["vers"] = [-0.94, 0.34] if phase_c == "serre" else [0.8, 0.6]
					"couche":
						s.etat["noeuds"] = 3
						s.etat["fouillee"] = _etats.has("fouillee")
					"vestige":
						if _etats.has("fouille"):
							s.etat["fouille"] = true
					"carre":
						# (--etat baie|lin|simple, et semis|pousse|fleur|mur ; eau : la terre humide ; gel ; sans culture
						# dite, chaque carré a la sienne, et sans stade dit, chacun le sien)
						var rang: int = jeu.atelier.poses.filter(func(x): return str(x.genre) == "carre").find(s)
						s.etat["culture"] = ["baie", "lin", "simple"][rang % 3]
						for c in ["baie", "lin", "simple"]:
							if _etats.has(c):
								s.etat["culture"] = c
						s.etat["stade"] = 3.0 if _etats.has("mur") else (2.0 if _etats.has("fleur") else (1.0 if _etats.has("pousse") else (0.2 if _etats.has("semis") else clampf(3.0 - 0.6 * float(rang / 3), 0.4, 3.0))))
						s.etat["eau"] = 1.0 if _etats.has("eau") else 0.0
						s.etat["gel"] = _etats.has("gel")
					"epouvantail":
						if _etats.has("regard"):
							s.etat["regard"] = PI
						s.etat["alerte"] = 1.0 if _etats.has("alerte") else 0.0
					"mangeoire":
						s.etat["foin"] = 9 if _etats.has("foin") else 0
					"piquet":
						s.etat["attache"] = _etats.has("attache")
						# (--etat rompue : le bout de longe de filin que la Noire y a laissé)
						if _etats.has("rompue"):
							s.etat["rompue"] = 2.0
				# (--etat saccage : ce que la Noire a mis en pièces, en épave ; gauche : elle tirait de l'autre côté ;
				# --etat mordu : dans sa gueule, à cet instant. scripts/noire_faim.gd, scripts/campement_epave.gd)
				if _etats.has("saccage"):
					jeu.noire.faim.mettre_en_pieces(s, -1.0 if _etats.has("gauche") else 1.0, false)
				elif _etats.has("mordu") and jeu.noire.faim.CHOSES.has(str(s.genre)):
					s.etat["mordu"] = 0.6
					s.etat["cote"] = -1.0 if _etats.has("gauche") else 1.0
	# (--compagne [licol,selle,sacoche,grande,reste,monte] : une bête à elle, près d'elle ; scripts/elevage.gd)
	var i_c := ar2.find("--compagne")
	if i_c >= 0 and jeu.elevage != null:
		var veut: PackedStringArray = ar2[i_c + 1].split(",") if i_c + 1 < ar2.size() and not ar2[i_c + 1].begins_with("--") else PackedStringArray()
		for e in jeu.faune["proies_jour"] + jeu.faune["proies_nuit"]:
			var x: Dictionary = e.duplicate()
			if veut.has("grande"):
				x["masse"] = 240.0
				x.erase("largeur")
			var b = jeu._creer(x, "proie", j.position + Vector2(70.0, 16.0))
			if not jeu.elevage.apprivoisable(b):
				b.remove_from_group("betes")
				b.queue_free()
				continue
			jeu.atelier.objets["licol"] = 1
			jeu.elevage.apprivoiser(b)
			for k in ["selle", "sacoche", "longe"]:
				if veut.has(k):
					b.harnais[k] = true
			if veut.has("reste"):
				b.suit_la = false
				b.maison = b.position
			# (--compagne longe,piquet : au piquet posé avec --pose piquet, sa longe nouée à l'anneau)
			if veut.has("piquet"):
				for s2 in jeu.atelier.poses:
					if str(s2.genre) == "piquet":
						b.suit_la = false
						b.maison = s2.position + Vector2(18.0, 10.0)
						b.position = b.maison
						break
			if veut.has("monte"):
				b.harnais["selle"] = true
				jeu.elevage.monter(b)
			# (--compagne longe,piquet,affolee : la nuit, déjà affolée par le noir, au bout de sa longe)
			if veut.has("affolee"):
				jeu.elevage._noir[b] = jeu.elevage.NOIR + 0.5
				_affolee = b
			break
	# (--noire saccage : la faim. Le feu est bas ; ce qu'elle a posé, sa bête au piquet sont hors de sa lumière ; la Noire
	# arrive, tourne un instant, puis va sur la première chose, la flaire, gronde, la met en pièces.
	# --noire crepuscule : le jour baisse, sa tanière est proche ; elle appelle et vient avant la nuit)
	if quelle == "saccage":
		jeu.nuits = jeu.noire.premiere_nuit(R.NOIRE_FAIM)
		jeu._etait_nuit = true
		# (un feu bas, tenu tel quel : _process ; le camp, écarté de lui : hors de sa lumière)
		_feu_tenu = 42.0
		for s in jeu.atelier.poses:
			if jeu.noire.faim.CHOSES.has(str(s.genre)) or str(s.genre) == "piquet":
				s.position = j.position + (s.position - j.position) * 1.75
		for b in jeu.elevage.betes:
			if is_instance_valid(b) and not bool(b.suit_la):
				b.maison = j.position + (b.maison - j.position - Vector2(18.0, 10.0)) * 1.75 + Vector2(18.0, 10.0)
				b.position = b.maison
		jeu.noire.mettre_en_scene(R.NOIRE_FAIM, 700.0, PI * 0.92)
		jeu.noire.faim._tenue = R.NOIRE_FAIM_ATTENTE - 2.0
		_plan = [[0.0, 1.0, "attendre"]]
	elif quelle == "crepuscule":
		jeu.nuits = jeu.noire.premiere_nuit(R.NOIRE_FAIM)
		jeu.horloge = soir - R.TRANSITION - 3.0
		jeu.noire.taniere = j.position + Vector2(-1500.0, 200.0)
		jeu.noire.ou = jeu.noire.taniere
		_plan = [[0.0, 1.0, "attendre"]]
	# (--pont-ici : un pont lié de filin et un pont de fibres, posés devant elle à même le sol, pour en comparer le dessin)
	if ar2.has("--pont-ici"):
		var a0: Vector2 = j.position + Vector2(50.0, 46.0)
		jeu.poser_pont(a0, a0 + Vector2(180.0, -24.0), R.PONT_DUREE * R.PONT_FILIN_DUREE, true)
		jeu.poser_pont(a0 + Vector2(-20.0, 86.0), a0 + Vector2(160.0, 62.0), R.PONT_DUREE, false)
		_plan = [[0.0, 1.0, "attendre"]]
	# (--loupe 2 : la caméra deux fois plus près, pour regarder un dessin)
	var i_lp := ar2.find("--loupe")
	if i_lp >= 0 and i_lp + 1 < ar2.size():
		jeu.effets.recul = float(ar2[i_lp + 1])
	# (--botanique poison,torpeur,visions,voyance,calme,fumee : cet état des herbes, tenu ; --herbes : son sac plein d'herbes
	# du lieu, la moitié reconnues ; scripts/botanique.gd)
	var i_b := ar2.find("--botanique")
	if i_b >= 0 and i_b + 1 < ar2.size():
		for e2 in ar2[i_b + 1].split(","):
			_botanique[e2] = true
	if ar2.has("--herbes") and jeu.botanique != null:
		var k5 := 0
		for id in jeu.botanique.especes(jeu.monde.lieu if jeu.botanique.FLORE.has(jeu.monde.lieu) else "foret"):
			j.inventaire[jeu.botanique.cle(id)] = 3
			jeu.botanique._fiche_savoir(id)["vue"] = true
			jeu.botanique._fiche_savoir(id)["indice"] = true
			if k5 % 2 == 0:
				jeu.botanique._fiche_savoir(id)["sue"] = "goutee"
			k5 += 1
		jeu.atelier.objets["mortier"] = 1
		jeu.atelier.objets["popote"] = 1
		j.inventaire["eau"] = 3
	# (--affut : elle ne bouge pas, pour regarder l'œil de l'affût s'ouvrir sur une bête ; scripts/pistage.gd)
	if OS.get_cmdline_user_args().has("--affut"):
		_plan = [[0.0, 1.0, "attendre"]]
	if _fin_noire != "":
		_plan = [[0.0, 1.0, "collet"]]
	# (devant la Noire, elle reste près de son feu ; --sort : à mi-temps, elle s'éloigne dans le noir, pour voir la charge)
	if quelle.is_valid_int():
		_plan = [[0.0, 1.0, "attendre"]]
		if OS.get_cmdline_user_args().has("--sort"):
			_plan = [[0.0, 0.55, "attendre"], [0.55, 1.0, "sortir"]]
	# (--doigt : comme sur un téléphone, les boutons à l'écran)
	if OS.get_cmdline_user_args().has("--doigt"):
		jeu.tactile.activer()
	if temps != "":
		_poser_le_temps()
	if jeu.ouvert:
		# (le monde ouvert : elle marche droit devant elle, pour voir le monde se faire et se défaire ; --depuis x,y : d'où elle part)
		_plan = [[0.0, 0.06, "attendre"], [0.06, 1.0, "est"]]
		var ar := OS.get_cmdline_user_args()
		# (--herbier fichier.json : l'herbier d'un biome d'Orvane, donné à la main — pour voir sa flore sans le réseau)
		var i_h := ar.find("--herbier")
		if i_h >= 0 and i_h + 1 < ar.size() and FileAccess.file_exists(ar[i_h + 1]):
			var herbier = JSON.parse_string(FileAccess.get_file_as_string(ar[i_h + 1]))
			if typeof(herbier) == TYPE_DICTIONARY and typeof(herbier.get("plantes")) == TYPE_DICTIONARY:
				var b = herbier.get("biome", "")
				var quel := str(b.get("id", "")) if typeof(b) == TYPE_DICTIONARY else str(b)
				Orvane.ajouter_herbier(quel, herbier)
				jeu.monde.lieu_de(quel)
				jeu.monde.flore_arrivee(quel)
				print("vitrine : herbier de « %s », %d plantes" % [quel, herbier["plantes"].size()])
		var i_d := ar.find("--depuis")
		if i_d >= 0 and i_d + 1 < ar.size():
			var xy := ar[i_d + 1].split(",")
			j.position = Vector2(float(xy[0]), float(xy[1]))
			jeu.monde.suivre(j.position, true)
			jeu.camera.reset_smoothing()
		# (--reste : elle ne bouge pas ; --recul 0.4 : on regarde de plus haut, pour voir le relief d'un pays)
		if ar.has("--reste"):
			_plan = [[0.0, 1.0, "attendre"]]
		# (--vers x,y : elle marche vers ce point)
		var i_v := ar.find("--vers")
		if i_v >= 0 and i_v + 1 < ar.size():
			var but := ar[i_v + 1].split(",")
			_but = Vector2(float(but[0]), float(but[1]))
			_plan = [[0.0, 0.06, "attendre"], [0.06, 1.0, "aller"]]
		# (--torche : elle allume une torche en partant)
		if ar.has("--torche"):
			jeu.fabriquer("torche")
		var i_r := ar.find("--recul")
		if i_r >= 0 and i_r + 1 < ar.size():
			jeu.effets.recul = float(ar[i_r + 1])
	# (--cueillette : elle cueille les fleurs et les champignons des bois autour d'elle)
	if OS.get_cmdline_user_args().has("--cueillette"):
		_plan = [[0.0, 0.08, "attendre"], [0.08, 1.0, "cueillette"]]
	# (--fruits : elle va d'arbre en arbre et cueille leurs fruits ; --planche arbres|sol : la planche de la cueillette)
	if OS.get_cmdline_user_args().has("--fruits"):
		_plan = [[0.0, 0.06, "attendre"], [0.06, 1.0, "fruits"]]
		# (de plus près : le geste se lit, le bras tendu dans les branches)
		jeu.effets.recul = 1.9
	var i_pl := OS.get_cmdline_user_args().find("--planche")
	if i_pl >= 0 and i_pl + 1 < OS.get_cmdline_user_args().size():
		_planche_cueillette(OS.get_cmdline_user_args()[i_pl + 1])
	# (--sans son,ciel,sol,flammes : pour chercher ce qui coûte, on éteint une chose à la fois)
	var args := OS.get_cmdline_user_args()
	var i_sans := args.find("--sans")
	if i_sans >= 0 and i_sans + 1 < args.size():
		for quoi in args[i_sans + 1].split(","):
			var cibles: Array = []
			match quoi:
				"son":
					cibles = [jeu.sons]
				"ciel":
					cibles = [jeu.ciel]
				"sol":
					cibles = jeu.scene.get_children().filter(func(n): return n.get_script() == jeu.TempsSol)
				"flammes":
					cibles = jeu.scene.get_children().filter(func(n): return n.get_script() == jeu.IncendieFlammes)
				"effets":
					cibles = [jeu.effets]
				"traces":
					# (les empreintes : on ne les dessine plus, pour mesurer ce qu'elles coûtent)
					cibles = [jeu.traces]
			for n in cibles:
				n.process_mode = Node.PROCESS_MODE_DISABLED
				if n is CanvasItem:
					n.visible = false
			print("vitrine : sans ", quoi, " (", cibles.size(), ")")
	# (--pres fondriere|faille|fumerolle|mare|obsidienne|tourbe|bois_flotte|carcasse : elle se tient à deux pas de la plus
	# proche, et ne bouge plus ; --dedans : sur elle, pour voir ce qu'elle fait. Le sol des pays : scripts/biome_terrain.gd)
	var i_pres := args.find("--pres")
	if i_pres >= 0 and i_pres + 1 < args.size() and jeu.terrain != null:
		jeu.terrain.suivre(jeu.joueur.position, true)
		var s: Dictionary = jeu.terrain.le_plus_proche(args[i_pres + 1], jeu.joueur.position)
		if not s.is_empty():
			var ou: Vector2 = s["p"]
			jeu.joueur.position = ou + (Vector2.ZERO if args.has("--dedans") else Vector2(-70.0, 46.0))
			if jeu.ouvert:
				jeu.monde.suivre(jeu.joueur.position, true)
			jeu.terrain.suivre(jeu.joueur.position, true)
			jeu.camera.reset_smoothing()
			_plan = [[0.0, 1.0, "attendre"]]
			print("vitrine : près de ", args[i_pres + 1], " en ", ou)
		else:
			print("vitrine : pas de ", args[i_pres + 1], " autour")
	_pret = true


# le temps qu'on veut voir, tout de suite, et là où la veilleuse ira
func _poser_le_temps() -> void:
	var C = jeu.climat
	var j = jeu.joueur
	_plan = [[0.0, 0.12, "attendre"], [0.12, 0.4, "tourner"], [0.4, 1.0, "aller"]]
	_but = j.position + Vector2(240, 60)
	var arbre = _plus_proche(["arbre", "sapin"])
	match temps:
		"pluie":
			C.forcer("pluie", 1.0, 9999.0)
			C.boue = 1.0
			if arbre != null:
				_but = arbre.position + Vector2(5, 8)
		"orage":
			C.forcer("orage", 1.0, 9999.0)
			C.boue = 0.7
		"crue":
			C.forcer("pluie", 0.8, 9999.0)
			C.boue = 1.0
			C.crue = 1.0
			var d0 := INF
			for k in 1600:
				var q: Vector2 = j.position + Vector2(-1200.0 + 60.0 * (k % 40), -1200.0 + 60.0 * (k / 40))
				if C.eau(q) > 0.85 and q.distance_to(j.position) < d0 and jeu.monde.repousser(q, 8.0).distance_to(q) < 1.0:
					d0 = q.distance_to(j.position)
					_but = q
			# (on part du bord de l'eau, pour la voir y entrer)
			j.position = _but + (j.position - _but).normalized() * 230.0
			_plan = [[0.0, 0.1, "attendre"], [0.1, 1.0, "aller"]]
		"neige":
			C.forcer("neige", 1.0, 9999.0)
			C.neige_sol = 0.9
			j.temperature = 32.0
		"canicule":
			C.forcer("canicule", 1.0, 9999.0)
			j.temperature = 74.0
		"incendie":
			C.forcer("clair", 0.0, 9999.0)
			C.vent = 0.5
		_:
			C.forcer(temps, 1.0, 9999.0)
	if _regles.has("--force"):
		C.forcer(C.temps, float(_regles["--force"]), 9999.0)
	if _regles.has("--boue"):
		C.boue = float(_regles["--boue"])
	if _regles.has("--crue"):
		C.crue = float(_regles["--crue"])
	if _regles.has("--neige-sol"):
		C.neige_sol = float(_regles["--neige-sol"])
	if _regles.has("--vent"):
		C.vent = float(_regles["--vent"])


# ce qui arrive pendant la scène : la foudre tombe sur un arbre (puis tout près d'elle), le feu prend
func _le_temps_passe(u: float) -> void:
	var j = jeu.joueur
	if temps == "orage" and u > 0.22 and not _fait.has("foudre"):
		_fait["foudre"] = true
		var arbre = _un_arbre(90.0, 230.0)
		if arbre != null:
			jeu.climat.frapper(arbre.position, R.FOUDRE_ANNONCE, arbre)
			_but = arbre.position + Vector2(52.0 * (1.0 if j.position.x >= arbre.position.x else -1.0), 12.0)
	if temps == "orage" and u > 0.8 and not _fait.has("foudre2"):
		_fait["foudre2"] = true
		jeu.climat.frapper(j.position + Vector2(48, -10), R.FOUDRE_ANNONCE)
	if feu != "":
		_atelier_feu(u)
	elif temps == "incendie" and u > 0.08 and not _fait.has("feu"):
		_fait["feu"] = true
		var arbre2 = _un_arbre(80.0, 260.0)
		if arbre2 != null:
			jeu.incendie.enflammer(arbre2)
			for o in jeu.monde.autour(arbre2.position, 70.0):
				if o != arbre2 and _fait.size() < 4:
					jeu.incendie.enflammer(o)
			# (elle s'approche, puis finit contre les flammes : elle prend feu)
			_but = arbre2.position + Vector2(16.0 * (1.0 if j.position.x >= arbre2.position.x else -1.0), 6.0)
	if not moments.is_empty() and u >= float(moments[0]) and image != "":
		moments.pop_front()
		_fait["images"] = int(_fait.get("images", 0)) + 1
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [image, int(_fait["images"])])
		print("APPELS %s %d : %d (objets %d)" % [image.get_file(), int(_fait["images"]), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])


# (l'atelier « feu ») un grand feu (24 objets), ce qui reste, la pluie qui éteint
func _atelier_feu(u: float) -> void:
	var j = jeu.joueur
	var I = jeu.incendie
	if u > 0.03 and not _fait.has("place"):
		_fait["place"] = true
		# (là où le lieu est le plus touffu, pas trop loin)
		var centre: Vector2 = j.position + Vector2(150, -30)
		var mieux := 0
		for o in jeu.monde.autour(j.position, 1300.0):
			if o.combustible():
				var n: int = jeu.monde.autour(o.position, 190.0).filter(func(x): return x.combustible()).size()
				if n > mieux:
					mieux = n
					centre = o.position
		j.position = jeu.monde.repousser(centre + Vector2(-150, 70), 8.0)
		_fait["centre"] = centre
		_but = j.position
		_plan = [[0.0, 1.0, "aller"]]
	if u > (0.06 if feu == "long" else 0.3) and not _fait.has("feu") and feu != "rien":
		_fait["feu"] = true
		var centre: Vector2 = _fait["centre"]
		var proches: Array = jeu.monde.autour(centre, 330.0)
		proches.sort_custom(func(a, b): return centre.distance_squared_to(a.position) < centre.distance_squared_to(b.position))
		var genres := {}
		for o in proches:
			if not o.combustible() or o.position.distance_to(j.position) < 50.0:
				continue
			if feu == "brasier" or int(genres.get(o._espece, 0)) < 3:
				if I.enflammer(o):
					genres[o._espece] = int(genres.get(o._espece, 0)) + 1
					_brules.append(o)
		print("vitrine : ", I.foyers.size(), " foyers ", genres)
	if feu == "restes" and u > 0.5 and not _fait.has("vite"):
		# (tout finit de brûler d'un coup, ou presque)
		_fait["vite"] = true
		for f in I.foyers:
			f.objet.brule = minf(f.objet.brule, randf_range(0.3, 2.5))
	if feu == "pluie" and u > 0.55 and not _fait.has("pluie"):
		_fait["pluie"] = true
		jeu.climat.forcer("pluie", 1.0, 9999.0)
	if feu == "brasier":
		# (le feu ne meurt pas pendant qu'on compte)
		for f in I.foyers:
			f.objet.brule = maxf(f.objet.brule, 6.0)
	if appels:
		var n := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var quand := "avant" if (u > 0.14 and u < 0.3) else ("apres" if u > 0.5 else "")
		if quand != "":
			_fait[quand] = float(_fait.get(quand, 0.0)) + n
			_fait[quand + "_n"] = int(_fait.get(quand + "_n", 0)) + 1
			_fait[quand + "_max"] = maxi(int(_fait.get(quand + "_max", 0)), n)
			_fait["foyers_max"] = maxi(int(_fait.get("foyers_max", 0)), I.foyers.size())
		if u >= 1.0 and not _fait.has("dit"):
			_fait["dit"] = true
			print("vitrine : appels de dessin, avant le feu %d (au pire %d) ; avec %d foyers %d (au pire %d)" % [int(float(_fait.get("avant", 0.0)) / maxi(1, int(_fait.get("avant_n", 0)))),
				int(_fait.get("avant_max", 0)), int(_fait.get("foyers_max", 0)), int(float(_fait.get("apres", 0.0)) / maxi(1, int(_fait.get("apres_n", 0)))), int(_fait.get("apres_max", 0))])


# (--mesure) toutes les cinq secondes : les images par seconde, la plus longue image, le temps du jeu (les scripts), les appels
var _mesure_ms := 0
var _mesure_n := 0
var _mesure_max := 0
var _mesure_avant := 0

func _mesurer() -> void:
	if not OS.get_cmdline_user_args().has("--mesure"):
		return
	var ms := Time.get_ticks_msec()
	if _mesure_avant > 0:
		_mesure_max = maxi(_mesure_max, ms - _mesure_avant)
	_mesure_avant = ms
	_mesure_n += 1
	if _mesure_ms == 0:
		_mesure_ms = ms
	elif ms - _mesure_ms >= 5000:
		print("vitrine mesure : %.1f images/s, la plus longue %d ms, %d appels, jeu %.0f ms au pire (%s, à %d s)" % [_mesure_n * 1000.0 / (ms - _mesure_ms), _mesure_max,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			temps if not jeu.ouvert else "sans bord : %d morceaux, %d objets, à %d pixels, un morceau en %.0f ms au pire" % [jeu.monde._morceaux.size(), jeu.monde.objets.size(), int(jeu.joueur.position.x), jeu.monde.pire_ms], int(_t)])
		jeu.monde.pire_ms = 0.0
		_mesure_ms = ms
		_mesure_n = 0
		_mesure_max = 0


func _un_arbre(de: float, a: float):
	var j = jeu.joueur
	var meilleur = null
	var d0 := INF
	for o in jeu.monde.autour(j.position, a):
		var d: float = j.position.distance_to(o.position)
		if o.couvert() > 0.0 and d >= de and d < d0:
			d0 = d
			meilleur = o
	return meilleur


func _process(delta: float) -> void:
	if not _pret or not jeu.en_partie:
		return
	_t += delta
	var j = jeu.joueur
	j.sante = maxf(j.sante, 60.0)
	for k in ["--sante", "--faim", "--peur"]:
		if _regles.has(k):
			j.set(k.trim_prefix("--"), float(_regles[k]))
	var u := _t / duree
	if _feu_tenu >= 0.0 and not jeu.feux.is_empty() and is_instance_valid(jeu.feux[0]):
		jeu.feux[0].bois = _feu_tenu
	# (--planche --gros : de tout près, chaque plante de la planche à son tour)
	if not _planche.is_empty() and OS.get_cmdline_user_args().has("--gros"):
		var o = _planche[clampi(int(u * _planche.size()), 0, _planche.size() - 1)]
		jeu.camera.position = o.position + Vector2(0.0, -float(o.hauteur) * 0.42) - j.position
		jeu.effets.recul = 2.6 if o.genre == "arbre" else 3.4
	if nu and jeu.ui != null and jeu.ui.visible:
		jeu.ui.visible = false
	_le_temps_passe(u)
	_mesurer()
	# (--tir : elle tire au lance-pierre, toutes les secondes, sur ce qui est à portée)
	if OS.get_cmdline_user_args().has("--tir") and int(_t / 1.1) != int((_t - delta) / 1.1):
		jeu.tirer()
	_tracer(delta)
	# (--carte : à la fin, la pause, et la carte du carnet, avec la carte et la plume dans le sac et quelques repères écrits ;
	# les régions à deux pas de là sont découvertes, ou, dans un lieu, ses environs parcourus, pour la voir pleine)
	if u > 0.8 and not _fait.has("carte") and OS.get_cmdline_user_args().has("--carte"):
		_fait["carte"] = true
		if jeu.carte != null:
			for i in jeu.decouvertes.keys():
				for v in jeu.carte.regions[i]["voisines"]:
					if not jeu.carte.regions[v]["eau"]:
						jeu.decouvertes[v] = true
						for w in jeu.carte.regions[v]["voisines"]:
							if not jeu.carte.regions[w]["eau"] and (w % 3) != 0:
								jeu.decouvertes[w] = true
		else:
			for k in 9:
				jeu.reperes.voir(j.position + Vector2.from_angle(TAU * k / 9.0) * (0.0 if k == 0 else 700.0))
		jeu.atelier.objets["carte"] = 1
		jeu.atelier.objets["plume"] = 1
		jeu.reperes._noter("camp", j.position, -1)
		for s in jeu.atelier.poses:
			if is_instance_valid(s) and str(s.genre) in ["coffre", "vestige"]:
				jeu.reperes._noter(str(s.genre), s.position, -1)
		jeu.reperes._noter("eau", j.position + Vector2(-520.0, 260.0), -1)
		jeu.reperes._noter("danger", j.position + Vector2(480.0, -340.0), -1)
		jeu.reperes._noter("cueillette", j.position + Vector2(300.0, 380.0), -1)
		if jeu.noire != null and Vector2(jeu.noire.taniere) != Vector2.ZERO:
			jeu.reperes._noter("taniere", jeu.noire.taniere, -1)
		var a := OS.get_cmdline_user_args()
		var toute: bool = a.find("--carte") + 1 < a.size() and a[a.find("--carte") + 1] == "toute"
		if toute:
			if jeu.carte != null:
				for k in jeu.carte.regions.size():
					if not jeu.carte.regions[k]["eau"]:
						jeu.decouvertes[k] = true
			else:
				var n := int(ceil(R.DEMI / jeu.reperes.CASE))
				for x in range(-n, n):
					for y in range(-n, n):
						jeu.reperes.vus[Vector2i(x, y)] = true
		jeu.en_pause = true
		jeu.ui.montrer_pause(true)
		if toute:
			_carte_entiere()
	if _page != "" and u > 0.5 and not _fait.has("page"):
		_fait["page"] = true
		jeu.ouvrir_page(_page)
	if not _etats.is_empty() and jeu.atelier != null:
		for s in jeu.atelier.poses:
			if _etats.has("travail") and str(s.genre) == "etabli":
				s.etat["travail"] = 1.0
			if _etats.has("foudre") and str(s.genre) == "cerf_volant" and u > 0.5 and not _fait.has("foudre"):
				_fait["foudre"] = true
				jeu.atelier.foudre(s.position)
		if _etats.has("popote") and u > 0.2 and not _fait.has("popote") and not jeu.feux.is_empty():
			_fait["popote"] = true
			jeu.atelier.objets["popote"] = 1
			jeu.joueur.inventaire["eau"] = 2
			jeu.joueur.inventaire["viande"] = 2
			jeu.atelier.cuisiner(jeu.feux[0])
	if not _botanique.is_empty() and jeu.botanique != null:
		var B = jeu.botanique
		if _botanique.has("poison"):
			B.poison = maxf(B.poison, 6.0)
			jeu.joueur.sante = maxf(jeu.joueur.sante, 60.0)
		if _botanique.has("torpeur"):
			B.torpeur = maxf(B.torpeur, 6.0)
		if _botanique.has("visions"):
			B.visions = maxf(B.visions, 6.0)
		if _botanique.has("voyance"):
			B.voyance = maxf(B.voyance, 6.0)
		if _botanique.has("calme"):
			B.calme = maxf(B.calme, 6.0)
		if _botanique.has("fumee"):
			for f in jeu.feux:
				if is_instance_valid(f):
					B.fumees[f] = maxf(float(B.fumees.get(f, 0.0)), 6.0)
		# (l'artisanat des plantes : la fumée des aromates sur les feux, le baume qui agit, l'odeur gardée)
		if _botanique.has("encens"):
			for f in jeu.feux:
				if is_instance_valid(f):
					B.encens[f] = maxf(float(B.encens.get(f, 0.0)), 6.0)
		if _botanique.has("onguent"):
			B.onguent = maxf(B.onguent, 6.0)
			jeu.joueur.sante = minf(jeu.joueur.sante, 70.0)
		if _botanique.has("parfum"):
			# (tout frais : elle sort de la fumée, l'odeur monte d'elle)
			B.parfum = maxf(B.parfum, R.PARFUM - 5.0)
	# (--compagne affolee : elle se débat au bout de sa longe, même de jour, pour qu'on voie le filin se tendre)
	if _affolee != null and is_instance_valid(_affolee) and jeu.elevage.betes.has(_affolee) and _affolee.longe != null:
		jeu.elevage._affoler(_affolee, delta)
	if _dormir_dans != null and u > 0.3 and not _fait.has("dort"):
		_fait["dort"] = true
		for b in get_tree().get_nodes_in_group("betes"):
			if str(b.role) != "proie":
				b.queue_free()
		jeu.atelier.dormir(_dormir_dans)
	if not _fabrique.is_empty() and jeu.atelier != null:
		# (--fabrique : elle fabrique pour de bon, à l'établi, une chose après l'autre : son geste, son bruit, les copeaux)
		_geste_atelier_t -= delta
		if _geste_atelier_t <= 0.0:
			_geste_atelier_t = 2.1
			var id: String = _fabrique[_fabrique_k % _fabrique.size()]
			_fabrique_k += 1
			for k3 in ["bois", "pierre", "fibre", "peau", "ferraille", "corde", "bache"]:
				jeu.joueur.inventaire[k3] = 14
			jeu.atelier.objets.erase(id)
			jeu.atelier.fabriquer(id)
	elif _geste_atelier != "":
		_geste_atelier_t -= delta
		if _geste_atelier_t <= 0.0:
			_geste_atelier_t = 1.8
			jeu.joueur.geste_atelier(_geste_atelier)
	# (--noire reveil : de jour, couchée à deux pas, puis réveillée au quart du temps : elle se lève, charge, mord, s'en va)
	if u > 0.25 and not _fait.has("reveil") and OS.get_cmdline_user_args().has("reveil") and jeu.noire.corps != null:
		_fait["reveil"] = true
		jeu.noire._reveiller()
	# (--carnet : à la fin, la pause, et le carnet des bêtes — la Noire, six choses apprises, vue dans la lumière ; --bas : la
	# page descendue jusqu'aux autres bêtes)
	if u > 0.8 and not _fait.has("carnet") and OS.get_cmdline_user_args().has("--carnet"):
		_fait["carnet"] = true
		for cle in ["appel", "empreintes", "silence", "yeux", "feu", "taniere"]:
			jeu.noire.su[cle] = true
		# (partie, ou balafrée : ce que le collet a appris d'elle, et sa dernière page)
		if jeu.noire.partie or jeu.noire.cicatrices > 0:
			for cle in ["feinte", "torche", "coups", "odeur", "collet", "cicatrice"]:
				jeu.noire.su[cle] = true
			if jeu.noire.partie:
				jeu.noire.su["depart"] = true
		# (--carnet --tout : tout ce qu'on peut apprendre d'elle, jusqu'à la faim)
		if OS.get_cmdline_user_args().has("--tout"):
			for s in jeu.noire.SAVOIRS:
				jeu.noire.su[str(s[0])] = true
		jeu.noire.vue = true
		jeu.noire.taniere_connue = true
		# (et les bêtes croisées : une connue, une observée, les autres seulement croisées)
		var k := 0
		for id in jeu.vues:
			jeu.savoir[id] = [18.0, 6.0, 0.0][mini(k, 2)]
			k += 1
		jeu.en_pause = true
		jeu.ui.montrer_pause(true)
		jeu.ui._pause._montrer_elle(true)
		if OS.get_cmdline_user_args().has("--bas"):
			await get_tree().process_frame
			await get_tree().process_frame
			jeu.ui._pause.savoirs.scroll_vertical = 230
	# (--pont : au bord d'une rivière, elle pose un pont de fortune et le passe)
	if jeu.ouvert and jeu.pont_possible and not _fait.has("pont") and OS.get_cmdline_user_args().has("--pont"):
		_fait["pont"] = true
		j.inventaire["bois"] = 40
		j.inventaire["fibre"] = 12
		if OS.get_cmdline_user_args().has("--filin"):
			j.inventaire["filin"] = 4
		jeu.fabriquer("pont")
		if not jeu.ponts.is_empty():
			var pt = jeu.ponts[0]
			_but = pt.b + (pt.b - pt.a).normalized() * 140.0
			_plan = [[0.0, 1.0, "aller"]]
	if _regles.has("--corps"):
		j.temperature = float(_regles["--corps"])
	if u >= 1.0:
		_pret = false
		_quitter()
		return
	var geste := "attendre"
	for p in _plan:
		if u >= p[0] and u < p[1]:
			geste = p[2]
	var centre: Vector2 = jeu.feux[0].position if not jeu.feux.is_empty() else Vector2.ZERO
	match geste:
		"attendre":
			j.deplacer(Vector2.ZERO, delta, jeu.monde)
		"tourner":
			var d: Vector2 = j.position - centre
			if d.length() < 1.0:
				d = Vector2.RIGHT
			var vers := d.normalized().orthogonal() + d.normalized() * (110.0 - d.length()) / 60.0
			j.deplacer(vers.limit_length(1.0), delta, jeu.monde)
		"couper", "cueillir", "cueillette":
			var genres := ["arbre", "sapin"] if geste == "couper" else (["fleur", "cepe", "amanite"] if geste == "cueillette" else ["buisson", "touffe"])
			var o = _plus_proche(genres)
			if o != null:
				# (de côté, pour que le geste se lise)
				var d2: Vector2 = o.position + Vector2(18.0 * (1.0 if j.position.x >= o.position.x else -1.0), 10.0) - j.position
				if d2.length() > 24.0:
					j.deplacer(d2.normalized(), delta, jeu.monde)
				else:
					j.deplacer(Vector2.ZERO, delta, jeu.monde)
					_cadence(geste, delta)
		"fruits":
			# (ce qui nourrit, le plus proche : elle se poste à son pied, de côté, et cueille)
			var arbre = _fruitier_proche()
			if arbre != null:
				var d3: Vector2 = arbre.position + Vector2(16.0 * (1.0 if j.position.x >= arbre.position.x else -1.0), 9.0) - j.position
				if d3.length() > 20.0:
					j.deplacer(d3.normalized(), delta, jeu.monde)
				else:
					j.deplacer(Vector2.ZERO, delta, jeu.monde)
					_coup -= delta
					if _coup <= 0.0:
						_coup = 0.75
						jeu.agir()
			else:
				j.deplacer(Vector2.ZERO, delta, jeu.monde)
		"chasser":
			if not _fait.has("proie"):
				_fait["proie"] = jeu._creer(jeu.faune["proies_jour"][0], "proie", j.position + Vector2(26, 0))
				_fait["proie"].flair = 0.0
			var b = _fait["proie"]
			if is_instance_valid(b) and b.is_in_group("betes"):
				b.position = j.position + Vector2(26.0 * j.regard, 0)
				_cadence("chasser", delta)
			j.deplacer(Vector2.ZERO, delta, jeu.monde)
		"collet":
			_devant_le_collet(u, delta)
		"est":
			j.deplacer(Vector2(1.0, 0.12).normalized(), delta, jeu.monde)
		"aller":
			var da: Vector2 = _but - j.position
			j.deplacer(da.normalized() if da.length() > 6.0 else Vector2.ZERO, delta, jeu.monde)
		"torche":
			if not _fait.has("torche"):
				_fait["torche"] = true
				jeu.fabriquer("torche")
			j.deplacer(Vector2(-1, 0.3), delta, jeu.monde)
		"peur":
			j.peur = minf(100.0, j.peur + 40.0 * delta)
			if not _fait.has("morsure"):
				var c = _un_chasseur()
				if c != null:
					_fait["morsure"] = true
					jeu.mordre(c)
			j.deplacer(Vector2(0.6, -0.4), delta, jeu.monde)
		"sortir":
			j.deplacer(Vector2(0.9, -0.35), delta, jeu.monde)
		"dos", "face", "vers":
			# (la meute : elle tourne le dos au chasseur le plus proche d'un pas de côté, lui fait face, ou marche vers lui)
			var ch = _chasseur_proche()
			var vers_lui: Vector2 = (ch.position - j.position) if ch != null else Vector2.ZERO
			var cote := signf(vers_lui.x) * (-1.0 if geste == "dos" else 1.0)
			if geste == "vers":
				j.deplacer(vers_lui.normalized(), delta, jeu.monde)
			elif ch != null and cote != 0.0 and cote != float(j.regard):
				j.deplacer(Vector2(cote, 0.0), delta, jeu.monde)
			else:
				j.deplacer(Vector2.ZERO, delta, jeu.monde)


# --- la fin de la Noire (scripts/noire_collet.gd) : son collet, sa prise, ses cicatrices, son départ ---

# la scène : une place dégagée à gauche du feu, hors de sa lumière, où le collet est tendu ; elle, à deux pas
func _la_fin_de_la_noire(quelle: String) -> void:
	var ar := OS.get_cmdline_user_args()
	var j = jeu.joueur
	var N = jeu.noire
	var C = N.collet
	_fin_noire = quelle
	# (--cicatrices 2, ou « --noire cicatrices 2 » : ce qu'elle porte déjà)
	var i_c := ar.find("--cicatrices")
	var i_n := ar.find("--noire")
	if quelle == "cicatrices" and i_n + 2 < ar.size() and ar[i_n + 2].is_valid_int():
		N.cicatrices = clampi(int(ar[i_n + 2]), 0, R.NOIRE_CICATRICES)
	elif i_c >= 0 and i_c + 1 < ar.size():
		N.cicatrices = clampi(int(ar[i_c + 1]), 0, R.NOIRE_CICATRICES)
	for b in get_tree().get_nodes_in_group("betes"):
		b.remove_from_group("betes")
		b.queue_free()
	var feu_p: Vector2 = jeu.feux[0].position if not jeu.feux.is_empty() else j.position + Vector2(40.0, 0.0)
	if not jeu.feux.is_empty():
		jeu.feux[0].bois = 46.0
	var place := feu_p + Vector2(-400.0, 26.0)
	for o in jeu.monde.autour(place + Vector2(60.0, 0.0), 520.0):
		if float(o.rayon) > 0.0 or str(o.genre) == "buisson":
			jeu.monde.retirer(o)
	for x in jeu.atelier.poses.duplicate():
		if is_instance_valid(x) and x.position.distance_to(place) < 700.0:
			jeu.atelier.poses.erase(x)
			x.queue_free()
	# (la septième nuit : l'heure, le jour et les nuits tenues d'accord entre eux, que l'aube ne vienne pas d'elle-même)
	jeu.horloge += R.DUREE * 6.0
	jeu.nuits = 6
	jeu.jour = 7
	jeu._etait_nuit = jeu.jour_du_ciel() <= 0.0
	N.acte = 3
	N.taniere = feu_p + Vector2(-1900.0, -1300.0)
	N.ou = N.taniere
	for cle in ["appel", "silence", "yeux", "feu"]:
		N.su[cle] = true
	j.lance = R.USURE_LANCE
	match quelle:
		"collet", "prise":
			N.tombee()
			N.acte = 3
			N._appel = true
			_collet = jeu.atelier._creer("collet", place, {"amorce": true, "odeur": quelle == "collet" and not ar.has("--propre"), "phase": ""})
			C.poses_n = 1
			if quelle == "collet":
				# (elle arrive par la gauche, à trois cents pas du nœud : elle le sent déjà)
				j.position = feu_p + Vector2(-70.0, 12.0)
				j.regard = -1.0
				N._apparaitre(place + Vector2(-360.0, 40.0))
				C.vise = _collet
				C._cote = 1.0
				C._flaire = false
				N._changer("appat")
				jeu.camera.position = Vector2(-190.0, 0.0)
			else:
				# (le nœud vient de se serrer ; la veilleuse est sortie, au bout de sa portée)
				N._apparaitre(place - Vector2(C.PATTE * R.NOIRE_LARGEUR, 0.0))
				N.corps.regard = 1.0
				C.vise = _collet
				C._cote = 1.0
				# (hors de la nuit, pour la regarder : le nœud la tient quand même ; --torche : la veilleuse en porte une)
				C.de_jour = true
				if ar.has("--torche"):
					j.torche = R.DUREE_TORCHE
				C._serrer(_collet)
				var pieu: Vector2 = C.ancre(_collet)
				var d := R.NOIRE_COLLET_LONGE + (R.NOIRE_COLLET_MORD - 22.0 if ar.has("--dedans") else R.NOIRE_COLLET_MORD + 26.0)
				j.position = pieu + Vector2(d, 14.0)
				j.regard = -1.0
				jeu.camera.position = Vector2(-120.0, -10.0)
		"part":
			# (l'aube de son départ : le collet rompu, sa piste qui en part et sort du lieu, sa couche vide ; puis la page)
			jeu.horloge = R.DUREE * 7.0 + R.TRANSITION * 0.5
			jeu.jour = 8
			jeu.nuits = 7
			jeu._etait_nuit = false
			_collet = jeu.atelier._creer("collet", place, {"amorce": false, "odeur": false, "phase": "rompu", "vers": [-0.92, 0.38]})
			N.cicatrices = R.NOIRE_CICATRICES
			N.partie = true
			N.vue = true
			C.poses_n = 4
			C.prises_n = 4
			C.morsures_n = 1
			C.emportes = 3
			C.jour_du_depart = 7
			C.depart_de = C.ancre(_collet)
			C.sortie = C._hors_du_lieu(C.depart_de, PI - 0.36)
			for cle in ["empreintes", "feinte", "torche", "coups", "taniere", "odeur", "collet", "cicatrice"]:
				N.su[cle] = true
			if ar.has("--aupres") and ar[ar.find("--aupres") + 1] == "couche":
				N.taniere = feu_p + Vector2(-140.0, 190.0)
				for o in jeu.monde.autour(N.taniere, 200.0):
					if float(o.rayon) > 0.0 or str(o.genre) == "buisson":
						jeu.monde.retirer(o)
				j.position = N.taniere + Vector2(96.0, 30.0)
				j.regard = -1.0
				jeu.camera.position = Vector2(-70.0, -20.0)
			else:
				j.position = place + Vector2(150.0, 40.0)
				j.regard = -1.0
				jeu.camera.position = Vector2(-150.0, -10.0)
			N.aube()
			if ar.has("--page") and ar[ar.find("--page") + 1] == "depart":
				C._page_dans = 0.8
			elif ar.has("--sans-page") or ar.has("--carnet"):
				C._page_dans = -1.0
		"cicatrices":
			# (de jour, à deux pas, debout devant elle ; puis elle s'en va, vers sa tanière)
			N.vue = true
			N.taniere = j.position + Vector2(3200.0, 240.0)
			N._apparaitre(j.position + Vector2(-250.0, 34.0))
			N.corps.regard = 1.0
			N.corps.ordre = "guette"
			N._colere = 9999.0
			N.etat = "pose"
			jeu.camera.position = Vector2(-150.0, -40.0)


# la veilleuse devant le collet : elle attend ; --frappe : lance en main, elle frappe dès que la bête est à sa portée
func _devant_le_collet(u: float, delta: float) -> void:
	var j = jeu.joueur
	var N = jeu.noire
	j.deplacer(Vector2.ZERO, delta, jeu.monde)
	if _fin_noire == "cicatrices":
		# (aux trois cinquièmes : elle se détourne, et s'en va en boitant)
		if u > 0.6 and not _fait.has("s_en_va") and N.corps != null:
			_fait["s_en_va"] = true
			N._colere = 0.0
			N._changer("rentre")
		elif u <= 0.6 and N.corps != null:
			N.corps.ordre = "guette"
		return
	if N.corps != null and is_instance_valid(N.corps) and absf(N.corps.position.x - j.position.x) > 12.0:
		j.regard = signf(N.corps.position.x - j.position.x)
	if _fin_noire == "prise" and OS.get_cmdline_user_args().has("--frappe") and N.etat == "prise" and N.corps != null:
		_coup -= delta
		if _coup <= 0.0 and N.corps.position.distance_to(j.position) - N.corps.largeur * 0.3 < R.PORTEE_COUP:
			_coup = R.CADENCE
			jeu.agir()


func _cadence(_quoi: String, delta: float) -> void:
	_coup -= delta
	if _coup <= 0.0:
		_coup = R.CADENCE
		jeu.agir()


func _plus_proche(genres: Array):
	var j = jeu.joueur
	var meilleur = null
	var d0 := INF
	for o in jeu.monde.autour(j.position, 700.0):
		if genres.has(o.genre) and not o.epuise():
			var d: float = j.position.distance_to(o.position)
			if d < d0:
				d0 = d
				meilleur = o
	return meilleur


# (--fruits) ce qui nourrit, le plus proche : un arbre qui porte encore des fruits, des épis mûrs, du lichen des rennes, un cactus
func _fruitier_proche():
	var j = jeu.joueur
	var meilleur = null
	var d0 := INF
	for o in jeu.monde.autour(j.position, 900.0):
		var nourrit: bool = o.porte_fruits() if o.genre == "arbre" else (str(o.forme) in ["cereale", "riz", "lichen_rennes", "cactus"] and not o.epuise())
		if nourrit:
			var d: float = j.position.distance_to(o.position)
			if d < d0:
				d0 = d
				meilleur = o
	return meilleur


# (--planche arbres|sol) la cueillette nourricière, posée en planche dans une clairière à côté d'elle, regardée de près : chaque
# plante dans chacun de ses états, comme sur une page de l'herbier. Rien n'y bouge que le vent ; elle se tient au bord
func _planche_cueillette(quoi: String) -> void:
	if quoi == "flore":
		_planche_flore()
		return
	var j = jeu.joueur
	var W = jeu.monde
	var Objet := load("res://scripts/objet.gd")
	var centre: Vector2 = j.position + Vector2(0.0, -60.0)
	# (la clairière : rien d'autre dans le cadre, ni bête)
	for o in W.autour(centre, 520.0):
		if is_instance_valid(o) and o != j:
			W.retirer(o)
	for b in get_tree().get_nodes_in_group("betes"):
		b.queue_free()
	_plan = [[0.0, 1.0, "attendre"]]
	# (une plante de cette forme, posée par le monde comme les siennes : un lieu où il ne pousse qu'elle)
	var poser := func(genre: String, forme: String, p: Vector2, graine: int, caracteres: Array = [], saison: String = "été"):
		var garde: String = Objet.saison
		Objet.saison = saison
		var strate := "arbre" if genre == "arbre" else "sol"
		var e := {"id": "planche-" + forme, "poids": 1.0, "taille": 1.0, "port": forme, "forme": forme, "genre": genre, "planche": false, "nom": forme,
			"stade": "feuilles", "defense": [], "caracteres": caracteres, "couleur": null, "fleur": null}
		var o = W._poser(strate, centre + p, W.palette["feuilles" if strate == "arbre" else "herbe"], graine, {"flore": {strate: [e]}, "climat": Objet.climat, "palette": W.palette})
		Objet.saison = garde
		_planche.append(o)
		return o
	if quoi == "geste" or quoi == "secouer":
		# (un pommier chargé, et elle qui cueille, de tout près : le geste, le bras tendu ; l'arbre ne se vide pas. « secouer » :
		# un palmier, ses cocos hors de portée de sa main : elle secoue le fût)
		var haut := quoi == "secouer"
		var o = poser.call("arbre", "palmier" if haut else "fruitier", Vector2(0.0, 60.0), _graine_qui_porte(31 if haut else 12))
		o.tombes = 0
		o.fruits_plein = 9
		o.fruits = 9
		j.position = o.position + Vector2(-16.0, 9.0)
		_plan = [[0.0, 0.05, "attendre"], [0.05, 1.0, "fruits"]]
		jeu.effets.recul = 1.9 if haut else 3.0
		jeu.camera.position = Vector2(14.0, -60.0 if haut else -34.0)
	elif quoi == "arbres":
		# (la rangée du fond, chargée : le pommier, le figuier, le palmier, le baobab, chacun avec ses fruits tombés à son pied)
		var fond := [["fruitier", 12], ["figuier", 28], ["palmier", 31], ["bouteille", 46]]
		for i in fond.size():
			var g := _graine_qui_porte(fond[i][1])
			var o = poser.call("arbre", fond[i][0], Vector2(-285.0 + 190.0 * i, -60.0), g)
			o.tombes = o.tombes_plein
		# (la rangée de devant : le pommier à moitié cueilli, vidé (ses fruits verts reviennent), au printemps (en fleurs), et
		# un arbre qu'Orvane dit aux fruits charnus : ses sorbes)
		var o1 = poser.call("arbre", "fruitier", Vector2(-285.0, 150.0), _graine_qui_porte(55))
		o1.fruits = o1.fruits_plein / 2
		o1.tombes = 0
		var o2 = poser.call("arbre", "fruitier", Vector2(-95.0, 150.0), _graine_qui_porte(66))
		o2.fruits = 0
		o2.tombes = 0
		o2._repousse_fruits = 0.3 * load("res://scripts/regles.gd").REPOUSSE_FRUITS
		poser.call("arbre", "fruitier", Vector2(95.0, 150.0), _graine_qui_porte(77), [], "printemps")
		var o4 = poser.call("arbre", "pionnier", Vector2(285.0, 150.0), _graine_qui_porte(88), ["fruits_charnus"])
		o4.tombes = o4.tombes_plein
		j.position = centre + Vector2(385.0, 150.0)
		jeu.effets.recul = 1.15
		# (la caméra regarde la planche, pas elle)
		jeu.camera.position = centre + Vector2(0.0, 20.0) - j.position
	else:
		# (de gauche à droite : la céréale mûre, ses épis cueillis, sa paille coupée, au printemps ; le riz sauvage mûr, cueilli ;
		# le lichen des rennes entier, entamé, tout pris ; le cactus entier, un bras coupé, les deux)
		var rangs := [
			[["touffe", "cereale", 2, "été"], ["touffe", "cereale", 1, "été"], ["touffe", "cereale", 0, "été"], ["touffe", "cereale", 2, "printemps"], ["touffe", "riz", 2, "été"], ["touffe", "riz", 1, "été"]],
			[["touffe", "lichen_rennes", 2, "été"], ["touffe", "lichen_rennes", 1, "été"], ["touffe", "lichen_rennes", 0, "été"], ["touffe", "cactus", 2, "été"], ["touffe", "cactus", 1, "été"], ["touffe", "cactus", 0, "été"]],
		]
		for ri in rangs.size():
			for i in rangs[ri].size():
				var e: Array = rangs[ri][i]
				var o = poser.call(e[0], e[1], Vector2(-150.0 + 60.0 * i, -40.0 + 85.0 * ri), 4000 + i * 7 + ri * 31, [], e[3])
				o.reste = int(e[2])
				o.queue_redraw()
		# (au jardin : trois carrés de grains, qui sortent, qui épient, mûrs)
		for i in 3:
			jeu.atelier._creer("carre", centre + Vector2(-100.0 + 100.0 * i, 115.0), {"culture": "grain", "stade": [1.1, 2.1, 3.0][i], "eau": 0.8})
		j.position = centre + Vector2(215.0, 60.0)
		jeu.effets.recul = 1.8
		jeu.camera.position = centre + Vector2(0.0, 30.0) - j.position
	jeu.camera.reset_smoothing()



# (--planche flore) l'herbier du biome, en planche : chaque plante telle que le monde la pose (sa forme, sa taille d'après sa
# hauteur d'Orvane, sa couleur, ses caractères), rangée par strate, la planche d'Orvane à sa droite pour comparer, et la
# veilleuse à gauche de chaque rangée pour l'échelle (la vraie, et des silhouettes d'encre à sa mesure : 22 sur 44)
func _planche_flore() -> void:
	var j = jeu.joueur
	var W = jeu.monde
	var Objet := load("res://scripts/objet.gd")
	var Flore := load("res://scripts/flore.gd")
	var ar := OS.get_cmdline_user_args()
	var option := func(nom: String) -> PackedStringArray:
		var i := ar.find(nom)
		return ar[i + 1].split(",") if i >= 0 and i + 1 < ar.size() else PackedStringArray()
	var strates: PackedStringArray = option.call("--strate")
	var formes: PackedStringArray = option.call("--formes")
	var fois := maxi(1, int(option.call("--fois")[0])) if not option.call("--fois").is_empty() else 1
	var i_e := ar.find("--etat")
	if i_e >= 0 and i_e + 1 < ar.size():
		for e in ar[i_e + 1].split(","):
			_etats[e] = true
	var centre: Vector2 = j.position + Vector2(0.0, -60.0)
	for o in W.autour(centre, 1500.0):
		if is_instance_valid(o) and o != j:
			W.retirer(o)
	for b in get_tree().get_nodes_in_group("betes"):
		b.queue_free()
	for f in jeu.feux:
		if is_instance_valid(f):
			f.visible = false
	_plan = [[0.0, 1.0, "attendre"]]
	# (rien que le sol et les ombres : ni l'herbe du décor, ni ses mares, ni ses pierres)
	for i in mini(3, W._calques.size()):
		W._calques[i].visible = false
	if not ar.has("--sur-le-sol") and jeu.terrain != null and jeu.terrain.get("_sol") != null:
		jeu.terrain._sol.visible = false
	# ce que l'herbier dit de chacune (sa hauteur, pour l'étiquette)
	var hauteurs := {}
	for e in Orvane.plantes(lieu):
		hauteurs[str(e["id"])] = float(e.get("hauteur_m", 0.0))
	var flore: Dictionary = W._flore_de(lieu)
	if ar.has("--toutes"):
		# (toutes les formes que Lisière dessine, une de chaque : celles que l'herbier du lieu n'a pas y sont aussi)
		flore = {}
		for forme in Flore.FORMES:
			var genre: String = Flore.FORMES[forme][0]
			var strate: String = Flore.FORMES[forme][1]
			if not flore.has(strate):
				flore[strate] = []
			flore[strate].append({"id": "planche-" + forme, "poids": 1.0, "taille": 1.0, "port": forme, "forme": forme, "genre": genre, "planche": false,
				"nom": forme, "stade": "feuilles", "defense": [], "caracteres": [], "couleur": null, "fleur": null})
	var saison := "été"
	for s in ["printemps", "automne", "hiver"]:
		if _etats.has(s):
			saison = s
	var climat: Dictionary = {"froid": 0.9, "humide": 0.5} if _etats.has("neige") else Objet.climat
	var orvane := not ar.has("--sans-orvane")
	# les rangées : une strate après l'autre, à la ligne quand la rangée est pleine ; la largeur des rangées qui remplit le mieux l'image
	var rangs: Array = []
	for strate in ["arbre", "buisson", "sol", "eau", "champignon"]:
		if not flore.has(strate) or (not strates.is_empty() and not strates.has(strate)):
			continue
		var L: Array = flore[strate].duplicate()
		if not formes.is_empty():
			L = L.filter(func(e): return formes.has(str(e["forme"])))
		if L.is_empty():
			continue
		L.sort_custom(func(a, b): return str(a["forme"]) + str(a["id"]) < str(b["forme"]) + str(b["id"]))
		rangs.append([strate, L])
	var vue: Vector2 = get_viewport().get_visible_rect().size
	var plan: Array = []
	var cadre := Rect2()
	var meilleur := 0.0
	for large in [520.0, 680.0, 840.0, 1000.0, 1200.0, 1400.0, 1700.0, 2100.0]:
		var essai := _ranger_flore(rangs, fois, orvane, large)
		var c: Rect2 = essai[1]
		if not c.has_area():
			continue
		var recul := minf(vue.x / (R.ZOOM * c.size.x), vue.y / (R.ZOOM * c.size.y))
		if recul > meilleur:
			meilleur = recul
			plan = essai[0]
			cadre = c
	if plan.is_empty():
		print("vitrine : rien à montrer sur la planche de la flore (« %s »)" % lieu)
		return
	var dessus := Node2D.new()
	dessus.z_index = 60
	W.add_child(dessus)
	var police: Font = load("res://polices/alegreya-sans/AlegreyaSans-Regular.ttf") if ResourceLoader.exists("res://polices/alegreya-sans/AlegreyaSans-Regular.ttf") else null
	var premiere := true
	for pl in plan:
		var strate: String = pl[0]
		var e: Dictionary = pl[1]
		var k: int = pl[2]
		var x: float = pl[3]
		var y: float = pl[4]
		var pw: float = pl[5]
		if bool(pl[6]):
			# (l'échelle, au début de chaque rangée : la veilleuse elle-même à la première ; ailleurs, sa silhouette)
			if premiere:
				j.position = centre + Vector2(22.0, y)
				premiere = false
			else:
				var sil := _Silhouette.new()
				sil.position = centre + Vector2(22.0, y)
				dessus.add_child(sil)
		var p := centre + Vector2(x + pw * 0.5, y)
		var garde: String = Objet.saison
		Objet.saison = saison
		var graine: int = 5000 + absi(hash(str(e["id"]))) % 9000 + k * 977
		if strate == "arbre" and not _etats.has("sans-fruits"):
			graine = _graine_qui_porte(graine % 4000)
		var o = W._poser(strate, p, W.palette["feuilles" if strate == "arbre" else "herbe"], graine, {"flore": {strate: [e]}, "climat": climat, "palette": W.palette})
		Objet.saison = garde
		if o == null:
			continue
		_planche.append(o)
		_mettre_en_etat(o)
		if k > 0:
			continue
		if orvane:
			var tex: Texture2D = Orvane.texture_plante(str(e["id"]), 60.0, lieu)
			if tex != null:
				var carte := _Carte.new()
				carte.tex = tex
				carte.position = centre + Vector2(x + pw + 34.0, y + 4.0)
				dessus.add_child(carte)
		var mot := Label.new()
		var h: float = hauteurs.get(str(e["id"]), 0.0)
		var car: Array = e.get("caracteres", []) if typeof(e.get("caracteres")) == TYPE_ARRAY else []
		var nom := str(e.get("nom", "")).split(" ")[0]
		mot.text = "%s · %s%s\n%s%s" % [nom, str(e["forme"]), (" · %s m" % str(snappedf(h, 0.01))) if h > 0.0 else "",
			("×%.2f " % float(e.get("taille", 1.0))) if absf(float(e.get("taille", 1.0)) - 1.0) > 0.005 else "", ", ".join(PackedStringArray(car))]
		if police != null:
			mot.add_theme_font_override("font", police)
		mot.add_theme_font_size_override("font_size", 9)
		mot.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
		mot.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.06, 0.9))
		mot.add_theme_constant_override("outline_size", 3)
		mot.add_theme_constant_override("line_spacing", -3)
		mot.position = centre + Vector2(x + 2.0, y + 10.0)
		dessus.add_child(mot)
	if not ar.has("--sur-le-sol") and W._racine != null and W._calques.size() > 3:
		# (un fond uni, de la couleur de la terre du lieu, sous les ombres : la planche se lit sans les mares ni les mousses du
		# sol ; --sur-le-sol : sur le vrai sol)
		var fond := Polygon2D.new()
		var c := Rect2(centre + cadre.position, cadre.size).grow(400.0)
		fond.polygon = PackedVector2Array([c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)])
		var terre: Color = W.palette.get("terre", Color(0.42, 0.36, 0.27))
		fond.color = terre.lerp(W.palette.get("herbe", terre), 0.25).lerp(Color(0.5, 0.46, 0.36), 0.35)
		W._racine.add_child(fond)
		W._racine.move_child(fond, W._calques[3].get_index())
	if ar.has("--derriere"):
		# (la veilleuse passe derrière le plus haut des arbres de la planche : sa couronne et son fût s'effacent, elle reste
		# lisible au travers)
		var grand = null
		for o in _planche:
			if str(o.genre) == "arbre" and (grand == null or float(o.hauteur) > float(grand.hauteur)):
				grand = o
		if grand != null:
			j.position = grand.position + Vector2(3.0, -18.0)
	# (le cadre : toute la planche tient dans l'image)
	jeu.effets.recul = meilleur
	jeu.camera.position = centre + cadre.get_center() - j.position
	jeu.camera.reset_smoothing()
	print("vitrine : la planche de la flore de « %s », %d plantes, recul %.2f" % [lieu, _planche.size(), jeu.effets.recul])


# où va chaque plante de la planche, pour des rangées de cette largeur : [[strate, plante, rang de l'individu, x, y (son pied), la
# place qu'elle a, début de rangée ?]…], et le cadre de l'ensemble
func _ranger_flore(rangs: Array, fois: int, orvane: bool, large_max: float) -> Array:
	# (la place de la plante ; la planche d'Orvane vient à sa droite)
	var places := {"arbre": 124.0, "buisson": 64.0, "sol": 60.0, "eau": 64.0, "champignon": 60.0}
	var hautes := {"arbre": 250.0, "buisson": 100.0, "sol": 104.0, "eau": 96.0, "champignon": 104.0}
	var plan: Array = []
	var cadre := Rect2()
	var y := 0.0
	for rg in rangs:
		var strate: String = rg[0]
		var L: Array = rg[1]
		var pw: float = places[strate]
		var lh: float = hautes[strate]
		var hauts := 0.0
		for e in L:
			hauts = maxf(hauts, float(e.get("taille", 1.0)))
			if strate == "sol" and str(e["forme"]) in ["cactus", "bambou"]:
				lh = 150.0
		if strate == "arbre":
			lh = 100.0 + 150.0 * hauts
		var x := 46.0
		y += lh
		var debut := true
		for e in L:
			for k in fois:
				var lw: float = pw + (74.0 if orvane and k == 0 else 10.0)
				if x + lw > large_max and not debut:
					x = 46.0
					y += lh + 30.0
					debut = true
				plan.append([strate, e, k, x, y, pw, debut])
				debut = false
				var r := Rect2(x, y - lh + 22.0, lw, lh + 8.0)
				cadre = cadre.merge(r) if cadre.has_area() else r
				x += lw
		y += 30.0
	if cadre.has_area():
		cadre = cadre.merge(Rect2(4.0, cadre.position.y, 10.0, 10.0)).grow(10.0)
	return [plan, cadre]


# (--planche flore --etat …) une plante de la planche, mise dans l'état qu'on veut voir
func _mettre_en_etat(o) -> void:
	if _etats.has("entame") and o.plein > 1 and o.genre != "arbre" and o.genre != "sapin":
		o.reste = o.plein - 1
	if _etats.has("entame") and (o.genre == "arbre" or o.genre == "sapin"):
		o.reste = 2
		o.fruits = o.fruits_plein / 2
	if _etats.has("cueilli"):
		if o.genre == "arbre" or o.genre == "sapin":
			o.fruits = 0
			o.tombes = 0
			if o.fruits_plein > 0:
				o._repousse_fruits = 0.4 * R.REPOUSSE_FRUITS
		elif o.plein > 0:
			o.reste = 0
	if _etats.has("souche") and (o.genre == "arbre" or o.genre == "sapin"):
		o.reprendre("souche", 0, 0.0)
	if _etats.has("roussi"):
		o.roussi = 0.8
	if _etats.has("calcine") and o.combustible():
		o.calciner()
		o._tiede = -1.0
		o.material = o._matiere_au_repos()
	if _etats.has("feu") and o.combustible() and jeu.incendie != null and jeu.incendie.enflammer(o):
		# (son feu, tenu à mi-chemin le temps de le regarder : les feuilles roussies et trouées, le bois qui paraît)
		o._brule_total *= 8.0
		o.brule = o._brule_total * (0.62 if o.graine % 2 == 0 else 0.38)
	if o.couronne != null:
		o.couronne.queue_redraw()
	o.queue_redraw()
	o._ombre_changee()


# la planche d'Orvane d'une plante, sur un carton de papier, le pied à l'origine
class _Carte extends Node2D:
	var tex: Texture2D

	func _draw() -> void:
		var t := tex.get_size()
		var coin := Vector2(-t.x * 0.5, -t.y * 144.0 / 150.0)
		draw_rect(Rect2(coin - Vector2(2, 2), t + Vector2(4, 4)), Color(0.09, 0.08, 0.06, 0.9))
		draw_rect(Rect2(coin - Vector2(1, 1), t + Vector2(2, 2)), Color(0.93, 0.89, 0.78))
		draw_texture(tex, coin)


# la silhouette de la veilleuse, à sa mesure (22 pixels de large, 44 de haut), pour l'échelle d'une rangée
class _Silhouette extends Node2D:
	func _draw() -> void:
		var e := Color(0.09, 0.08, 0.06, 0.82)
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-9, -24), Vector2(-6, -33), Vector2(6, -33), Vector2(9, -24), Vector2(7, 0)]), e)
		draw_circle(Vector2(0, -37), 6.5, e)
		draw_line(Vector2(-13, 0), Vector2(-13, -44), Color(0.96, 0.93, 0.84, 0.9), 1.0)
		draw_line(Vector2(-16, 0), Vector2(-10, 0), Color(0.96, 0.93, 0.84, 0.9), 1.0)
		draw_line(Vector2(-16, -44), Vector2(-10, -44), Color(0.96, 0.93, 0.84, 0.9), 1.0)


# une graine d'arbre qui porte des fruits cette année (scripts/objet.gd, _porter_fruits : une part de la graine en décide)
func _graine_qui_porte(depart: int) -> int:
	var g := depart * 1009 + 7
	while float((g / 7) % 100) >= load("res://scripts/regles.gd").PORTE_FRUITS * 100.0 or (g / 17) % 3 == 0:
		g += 1
	return g


func _chasseur_proche():
	var meilleur = null
	var d0 := INF
	for b in get_tree().get_nodes_in_group("betes"):
		var d: float = jeu.joueur.position.distance_to(b.position)
		if b.role == "chasseur" and d < d0:
			d0 = d
			meilleur = b
	return meilleur


# (--trace : le temps, la veilleuse, son regard, le feu et son rayon ; puis chaque chasseur : où il est, posté, détourné, où il en est)
func _tracer(delta: float) -> void:
	_trace_t -= delta
	if _trace == null or _trace_t > 0.0:
		return
	_trace_t = 0.2
	var j = jeu.joueur
	var f = jeu.feux[0] if not jeu.feux.is_empty() else null
	var l := "%.1f;%d;%d;%d;%d;%d;%d" % [_t, j.position.x, j.position.y, j.regard, f.position.x if f != null else 0.0, f.position.y if f != null else 0.0, f.rayon() if f != null else 0.0]
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role == "chasseur":
			l += ";%d;%d;%d;%.2f;%.2f;%d" % [b.get_instance_id() % 1000, b.position.x, b.position.y, b.poste, b.detourne, b._af]
	_trace.store_line(l)
	_trace.flush()


func _un_chasseur():
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role == "chasseur":
			return b
	for b in get_tree().get_nodes_in_group("betes"):
		if b.role != "echo":
			return b
	return null


# (des sons qui jouent encore quand Godot s'arrête, il dit qu'ils fuient : on les tait, et on laisse au serveur audio le temps)
func _quitter() -> void:
	# (où en est la Noire, pour qui lit la sortie : son acte, sa tanière, sa piste, ce qu'on sait d'elle)
	if jeu.noire != null and jeu.joueur != null and jeu.traces != null:
		print("vitrine : la Noire, acte %d, %s, sa tanière à %d pixels, %d empreintes d'elle, sait : %s" % [jeu.noire.acte, jeu.noire.etat,
			int(jeu.noire.taniere.distance_to(jeu.joueur.position)), jeu.traces.nombre(2), ", ".join(jeu.noire.su.keys())])
	jeu.sons.taire()
	jeu.sons.arreter_brefs()
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0)


# (--carte toute) la carte seule, en plein écran, de loin, tout dévoilé : ce que le carnet montrerait, en grand
func _carte_entiere() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 100
	add_child(couche)
	var fond := ColorRect.new()
	fond.color = load("res://scripts/palette.gd").PAPIER
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	couche.add_child(fond)
	var cm = load("res://scripts/interface_carte_monde.gd").new()
	couche.add_child(cm)
	cm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cm.loin = true
	cm.ouvrir(jeu)
	# (le relief de chaque région, d'un coup : la carte ne se complète pas sous les yeux)
	if jeu.carte != null:
		for k in jeu.decouvertes:
			cm._parois[k] = cm._relief_de(k)
			cm._bouches[k] = cm._bouches_de(k)
	cm.queue_redraw()
