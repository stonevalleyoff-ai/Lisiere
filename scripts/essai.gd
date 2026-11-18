extends Node
# Lisière — l'essai sans écran (scripts/essai.gd)
# Une partie jouée toute seule, en accéléré, sur la copie du monde gardée dans le jeu (sans réseau), qui vérifie que tout tient :
# le lieu, ses bêtes dessinées d'après leurs planches, la récolte, les fabrications, le jeu du doigt, la nuit, les chasseurs qui n'entrent pas
# dans la lumière du feu, la peur dans le noir, les échos, la mémoire d'Orvane (ce que les bêtes ont appris des joueurs, et ce
# que la partie leur apprend), l'aube, la fin, et ce qui est compté pour Orvane.
#   outils/godot.sh --headless --path . -- --essai              (sur la copie gardée dans le jeu)
#   outils/godot.sh --headless --path . -- --essai --en-ligne   (sur le monde publié)
# Il sort avec le code 0 si tout passe, 1 sinon.

var jeu
var ok := true
var n := 0
# le garde-fou : un fil à part regarde si l'essai avance. S'il ne dit plus rien pendant cent secondes, il dit où il en était
# (la dernière vérification, si les images passent encore, l'allure du temps) et arrête tout : un essai qui se fige est un échec
var _garde: Thread
var _dit_ms := 0
var _dernier := ""
var _images := 0
var _fini := false


func _ready() -> void:
	jeu = get_parent()
	_dit_ms = Time.get_ticks_msec()
	_garde = Thread.new()
	_garde.start(_garder)
	_lancer.call_deferred()


func _process(_delta: float) -> void:
	_images += 1


func _garder() -> void:
	var images_avant := 0
	while not _fini:
		OS.delay_msec(2000)
		if _fini:
			return
		var passent: bool = _images != images_avant
		images_avant = _images
		if Time.get_ticks_msec() - _dit_ms > 100000:
			print("\nÉCHEC : l'essai n'avance plus depuis cent secondes, après « %s ». Les images %s ; l'allure du temps : %s." % [
				_dernier, "passent encore (une attente qui ne finit pas)" if passent else "sont figées (un calcul qui ne finit pas)", str(Engine.time_scale)])
			OS.kill(OS.get_process_id())
			return


func _exit_tree() -> void:
	_fini = true
	if _garde != null and _garde.is_started():
		_garde.wait_to_finish()


func verif(c: bool, m: String) -> void:
	n += 1
	if not c:
		ok = false
	_dit_ms = Time.get_ticks_msec()
	_dernier = m.substr(0, 90)
	print(("  ✓ " if c else "  ✗ ") + m)


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


# un doigt qui se pose ou se lève, qui glisse : donné tout droit à la couche tactile (scripts/tactile.gd)
func _toucher(tac, doigt: int, p: Vector2, pose: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = doigt
	e.position = p
	e.pressed = pose
	tac._input(e)


func _glisser(tac, doigt: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = doigt
	e.position = p
	tac._input(e)


func _lancer() -> void:
	print("Lisière — l'essai")
	jeu.donnees.hors_ligne_force = not ("--en-ligne" in OS.get_cmdline_user_args())
	await jeu.donnees.charger_index()
	# (--seulement cueillette | faim | collet : une partie seule, pour la mettre au point vite ; c'est l'essai entier qui fait foi)
	var args_e: PackedStringArray = OS.get_cmdline_user_args()
	if "--seulement" in args_e:
		var quoi: String = args_e[args_e.find("--seulement") + 1] if args_e.find("--seulement") + 1 < args_e.size() else "cueillette"
		match quoi:
			"faim":
				await _la_faim_de_la_noire()
			"collet":
				await _le_collet_de_la_noire()
			"reunie":
				await _la_noire_reunie()
			"repartition":
				await _la_repartition()
			_:
				await _la_cueillette_nourriciere()
				await _les_retouches()
		await _conclure()
		return
	var L: Array = jeu.donnees.lieux()
	verif(L.size() >= 3, "%d lieux jouables (%s)" % [L.size(), ", ".join(PackedStringArray(L.map(func(x): return str(x["nom"]))))])
	# (chaque lieu proposé à l'écran-titre se charge, et a de quoi chasser et de quoi faire peur, comme _commencer le demande)
	var maigres := []
	# (et le bestiaire : chaque lignée jouable est dessinée par Lisière, d'après son plan de corps : scripts/bestiaire.gd)
	var Best := load("res://scripts/bestiaire.gd")
	var dessinees_l := {}
	var mal := []
	for l in L:
		var inst: Dictionary = await jeu.donnees.charger_lieu(str(l["id"]))
		var fl: Dictionary = jeu.donnees.faune(inst, str(l["id"])) if not inst.is_empty() else {}
		if fl.is_empty() or (fl["proies_jour"].is_empty() and fl["proies_nuit"].is_empty()) or fl["chasseurs_nuit"].is_empty():
			maigres.append(str(l["nom"]))
		for k in fl:
			for e in fl[k]:
				if dessinees_l.has(e["id"]):
					continue
				var plan_e: Dictionary = e["lignee"].get("plan", {})
				var sq_e: Dictionary = Best.lire(e["lignee"], Best.largeur_de(float(e["masse"]), Best.est_chasseur(plan_e)))
				var pattes_e := int(plan_e.get("corps", {}).get("pattes", 0))
				dessinees_l[e["id"]] = str(plan_e.get("corps", {}).get("forme", "?"))
				if sq_e.is_empty() or sq_e["corps"].is_empty() or sq_e["yeux"].is_empty() or sq_e["pattes"].size() != pattes_e or (pattes_e > 0 and sq_e["atlas"] == null):
					mal.append("%s (%s)" % [e["id"], dessinees_l[e["id"]]])
	var formes_l := {}
	for id_l in dessinees_l:
		formes_l[dessinees_l[id_l]] = int(formes_l.get(dessinees_l[id_l], 0)) + 1
	# (en ligne, le monde change chaque jour : un lieu maigre est dit, et le jeu le refuse au lancement ; la copie, elle, doit tout jouer)
	verif(maigres.is_empty() or jeu.donnees.en_ligne, "chaque lieu proposé se charge, avec des proies et des chasseurs" + (" ; sauf, refusés au lancement : %s" % ", ".join(PackedStringArray(maigres)) if maigres.size() > 0 else ""))

	verif(mal.is_empty() and dessinees_l.size() >= 60, "le bestiaire : les %d lignées jouables des lieux gardés sont dessinées par Lisière, avec leur œil et toutes leurs pattes (%s)%s" % [
		dessinees_l.size(), str(formes_l), (" ; mal dessinées : " + ", ".join(PackedStringArray(mal.slice(0, 8)))) if not mal.is_empty() else ""])

	print("0. Le compte")
	# (le compte de Stone Valley, sans réseau : la porte s'ouvre, refuse ce qui ne peut pas partir, et se ferme)
	var S = jeu.session
	var Ses := load("res://scripts/session.gd")
	verif(S != null and not S.connecte() and str(Ses.URL).contains("ldazucyrnpewkqdneznc"), "le compte est celui de Stone Valley (le Supabase « Vallée de pierre »), et personne n'y est entré")
	verif(S.dire("Invalid login credentials") == "adresse ou mot de passe incorrect" and S.dire("Email not confirmed").begins_with("adresse pas encore"), "les refus de Supabase sont dits en français")
	var porte = jeu.ui._porte
	jeu.ui._compte.pressed.emit()
	verif(porte.visible and porte.mode == "connexion" and porte._adresse.visible and porte._mdp.visible and jeu.ui._compte.libelle == "Se connecter",
		"« Se connecter », à l'écran-titre, ouvre la porte : une adresse, un mot de passe")
	porte._adresse._ligne.text = "pas-une-adresse"
	porte._mdp._ligne.text = "x"
	await porte.valider()
	var refus: String = porte._msg.text
	porte.mettre_mode("inscription")
	var inscrire: bool = porte._valider.libelle == "Créer le compte" and porte._bascule.libelle == "J'ai déjà un compte"
	porte.fermer()
	verif(refus == "adresse e-mail invalide" and inscrire and not porte.visible, "elle refuse une adresse mal faite sans rien envoyer, sait créer un compte, et se referme")

	print("1. Le lieu")
	await jeu._commencer("foret")
	verif(jeu.en_partie, "une partie commence en forêt")
	var F: Dictionary = jeu.faune
	verif(F["proies_jour"].size() > 0 and F["chasseurs_nuit"].size() > 0, "la faune du lieu : %d proies le jour, %d chasseurs la nuit, %d rôdeurs" % [F["proies_jour"].size(), F["chasseurs_nuit"].size(), F["rodeurs"].size()])
	var genres := {}
	for o in jeu.monde.objets:
		genres[o.genre] = int(genres.get(o.genre, 0)) + 1
	verif(int(genres.get("arbre", 0)) + int(genres.get("sapin", 0)) > 100 and int(genres.get("rocher", 0)) > 20, "le lieu est semé : %s" % str(genres))
	# (docs/49) les arbres, les buissons et les touffes du lieu sont ses plantes dans le monde d'Orvane, dessinées d'après l'herbier
	var plantes_lieu: Array = Orvane.plantes("foret")
	var dessines := 0
	var especes := {}
	for o in jeu.monde.objets:
		if o.plante != "":
			dessines += 1
			especes[o.plante] = true
	verif(plantes_lieu.size() > 0 and dessines > 100 and especes.size() >= 2, "le décor est fait des plantes du lieu : %d objets d'après l'herbier (leur couleur, leur taille, leur port, leurs épines), à l'encre, de %d lignées sur %d (%s)" % [dessines, especes.size(), plantes_lieu.size(), ", ".join(PackedStringArray(plantes_lieu.slice(0, 3).map(func(x): return str(x.get("forme", "?")))))])
	Engine.time_scale = 4.0
	# (le directeur tire au sort toutes les demi-secondes : on attend qu'une bête vienne, trente secondes au plus)
	var betes: Array = []
	for i in 30:
		await _attendre(1.0)
		betes = jeu.get_tree().get_nodes_in_group("betes")
		if betes.size() > 0 and i >= 5:
			break
	var dessinees := betes.filter(func(b): return b.sprite != null).size()
	verif(betes.size() > 0, "des bêtes viennent, le jour : %d" % betes.size())
	var de_lisiere := betes.filter(func(b): return b._sq.get("lisiere", false)).size()
	verif(dessinees > 0 and dessinees == betes.size() and de_lisiere == betes.size(), "chacune est dessinée, par Lisière (%d sur %d), à sa taille (de %d à %d pixels)" % [
		de_lisiere, betes.size(), int(betes.map(func(b): return b.largeur).min()), int(betes.map(func(b): return b.largeur).max())])

	print("2. Les gestes")
	var j = jeu.joueur
	# (un arbre sans rien d'autre à prendre à son pied : les trois coups sont pour lui ; et sans fruits, qu'« Agir » cueillerait
	# avant d'abattre : scripts/objet.gd, la cueillette nourricière)
	var o = null
	for x in jeu.monde.objets:
		if (x.genre == "arbre" or x.genre == "sapin") and int(x.fruits) == 0 and int(x.tombes) == 0 \
				and jeu.monde.autour(x.position + Vector2(0, 20), 70.0).filter(func(y): return y != x and not y.epuise()).is_empty():
			o = x
			break
	j.position = o.position + Vector2(0, 20)
	var b0 := int(j.inventaire["bois"])
	for i in 3:
		jeu.agir()
	verif(int(j.inventaire["bois"]) == b0 + 3, "trois coups sur un arbre : trois bois")
	j.inventaire["bois"] = 30
	j.inventaire["pierre"] = 10
	j.inventaire["fibre"] = 10
	j.position = Vector2(0, 0)
	jeu.fabriquer("feu")
	# (la lance ne se fabrique plus : elle se trouve, dans un coffre — _le_lance_pierre le vérifie ; ici on la lui donne, et l'on
	# retire ce qu'elle coûtait, pour que la suite compte comme avant)
	j.lance = jeu.R.USURE_LANCE
	j.inventaire["bois"] = int(j.inventaire["bois"]) - 2
	j.inventaire["pierre"] = int(j.inventaire["pierre"]) - 1
	j.inventaire["fibre"] = int(j.inventaire["fibre"]) - 2
	verif(jeu.feux.size() == 1 and int(j.inventaire["bois"]) == 24 and not jeu.R.RECETTES.has("lance") and not jeu.atelier.OBJETS.has("lance"),
		"un feu de camp, payé en bois et en pierres ; la lance ne se fabrique plus, ni de ses mains ni à l'établi")
	var f = jeu.feux[0]
	var avant: float = f.bois
	jeu.nourrir_feu()
	verif(f.bois > avant + 20.0, "une bûche nourrit le feu (%d → %d secondes)" % [int(avant), int(f.bois)])

	# (le son de la foudre se fabriquait par une boucle qui, pour six tirages sur mille, ne finissait pas : le jeu se figeait.
	# Ces graines-là la figeaient ; si elle se fige de nouveau, le garde-fou de l'essai le dira)
	var Recettes := load("res://scripts/sons_recettes.gd")
	var r_son := RandomNumberGenerator.new()
	var foudres := 0
	for graine_son in [3357669, 5068173, 5939263, 6145157, 9803735, 10263037]:
		r_son.seed = graine_son
		if not Recettes._foudre(r_son).is_empty():
			foudres += 1
	for nom_son in ["foudre0", "foudre1", "tonnerre0", "tonnerre1", "tonnerre2", "presage"]:
		for k in 12:
			r_son.seed = 1000 + k * 77
			if not Recettes.fabriquer(nom_son, r_son).is_empty():
				foudres += 1
	verif(foudres == 6 + 72, "les sons de la foudre se fabriquent toujours jusqu'au bout (78 tirages, dont six qui figeaient le jeu)")
	print("2 bis. Le temps qu'il fait")
	# (scripts/climat.gd, scripts/incendie.gd : le temps de la partie pèse sur le feu, le sol, le corps ; tout est joué ici sans
	# attendre, en appelant les mêmes fonctions que le jeu, image par image)
	var C = jeu.climat
	var I = jeu.incendie
	var RR = jeu.R
	C.forcer("clair", 0.0, 9999.0)
	C.boue = 0.0
	C.crue = 0.0
	jeu._temps_du_corps(0.1)
	var bois0: float = f.bois
	await _attendre(2.0)
	var calme: float = bois0 - f.bois
	C.forcer("orage", 1.0, 9999.0)
	jeu._temps_du_corps(0.1)
	bois0 = f.bois
	await _attendre(2.0)
	var tempete: float = bois0 - f.bois
	verif(calme > 0.0 and tempete > calme * 1.5 and jeu.texte_horloge().contains("orage"),
		"sous l'orage, le feu mange son bois plus vite (%.1f s de bois en deux secondes, contre %.1f), et l'horloge le dit" % [tempete, calme])
	# un coin à découvert et au sec, loin du feu ; un arbre debout, loin du feu aussi
	var decouvert := Vector2.ZERO
	for k in 40:
		var q := Vector2(420.0 + 45.0 * k, 0.0)
		if C.abri(q) == 0.0 and jeu.monde.repousser(q, 8.0).distance_to(q) < 1.0:
			decouvert = q
			break
	var arbre_abri = null
	var voisins_max := -1
	for x in jeu.monde.objets:
		if x.couvert() > 0.0 and x.position.distance_to(f.position) > 500.0:
			var nv := 0
			for y in jeu.monde.autour(x.position, 60.0):
				if y != x and y.combustible():
					nv += 1
			if nv > voisins_max:
				voisins_max = nv
				arbre_abri = x
	# la pluie trempe ; sous un feuillage, bien moins
	C.forcer("pluie", 1.0, 9999.0)
	j.position = decouvert
	j.trempe = 0.0
	j.temperature = 50.0
	for k in 20:
		jeu._temps_du_corps(0.5)
	var trempee: float = j.trempe
	var refroidie: float = j.temperature
	for k in 80:
		jeu._temps_du_corps(0.5)
	var froid: float = j.temperature
	var sante_froid: float = j.sante
	j.sante = 100.0
	j.position = arbre_abri.position + Vector2(3.0, 0.0)
	j.trempe = 0.0
	for k in 20:
		jeu._temps_du_corps(0.5)
	var abritee: float = j.trempe
	verif(decouvert != Vector2.ZERO and trempee > 70.0 and abritee < trempee * 0.4 and C.abri(j.position) == 1.0,
		"dix secondes sous une pluie battante trempent la veilleuse (%d sur 100) ; sous un feuillage, bien moins (%d)" % [int(trempee), int(abritee)])
	verif(refroidie < 50.0 and froid < RR.FROID and sante_froid < 100.0,
		"trempée, elle prend froid (sa température tombe de 50 à %d), et le froid lui coûte de la santé (%d sur 100)" % [int(froid), int(sante_froid)])
	# près du feu, la pluie passée, elle sèche et se réchauffe
	C.forcer("clair", 0.0, 9999.0)
	j.position = f.position + Vector2(34.0, 6.0)
	j.trempe = 100.0
	j.temperature = 15.0
	for k in 30:
		jeu._temps_du_corps(0.5)
	verif(j.trempe < 15.0 and j.temperature > 45.0, "près du feu, elle sèche et se réchauffe (trempée : %d ; température : %d)" % [int(j.trempe), int(j.temperature)])
	j.sante = 100.0
	# la boue freine
	j.position = decouvert
	j.temperature = 50.0
	C.boue = 0.0
	j.deplacer(Vector2(1, 0), 1.0, jeu.monde)
	var au_sec: float = j.position.x - decouvert.x
	j.position = decouvert
	C.boue = 1.0
	j.deplacer(Vector2(1, 0), 1.0, jeu.monde)
	var dans_la_boue: float = j.position.x - decouvert.x
	verif(dans_la_boue > 0.0 and dans_la_boue < au_sec * 0.86, "dans la boue, on marche moins vite (%d pixels en une seconde, contre %d au sec)" % [int(dans_la_boue), int(au_sec)])
	# la crue : l'eau gagne les creux, pas la butte du réveil ; on y patauge, on y est trempée, un feu s'y noie, on n'en allume pas
	C.crue = 1.0
	var creux := Vector2.ZERO
	for k in 400:
		var q2 := Vector2(-1800.0 + 180.0 * (k % 20), -1800.0 + 180.0 * (k / 20))
		# (un creux franc : l'eau y est profonde là où elle sera, et là où sera le feu qu'on y noie)
		# (et rien autour qui pousserait ailleurs le feu qu'elle voudra y poser : un tronc, un rocher, un vestige)
		if C.eau(q2) > 0.9 and C.eau(q2 + Vector2(30, 0)) > 0.9 and C.eau(q2 + Vector2(34, 4)) > 0.9 and jeu.monde.repousser(q2, 8.0).distance_to(q2) < 1.0 \
				and jeu.monde.repousser(q2 + Vector2(34.0, 4.0), 12.0).distance_to(q2 + Vector2(34.0, 4.0)) < 1.0:
			creux = q2
			break
	j.position = creux
	# (elle regarde vers la droite : c'est là, dans l'eau profonde, qu'elle voudra poser son feu)
	j.regard = 1.0
	j.trempe = 0.0
	j.en_feu = 2.0
	var feu_noye = jeu.Feu.new()
	feu_noye.jeu = jeu
	feu_noye.position = creux + Vector2(30, 0)
	jeu.monde.add_child(feu_noye)
	jeu.feux.append(feu_noye)
	jeu._temps_du_corps(1.0)
	var n_feux: int = jeu.feux.size()
	j.inventaire["bois"] = 30
	j.inventaire["pierre"] = 10
	jeu.fabriquer("feu")
	verif(creux != Vector2.ZERO and C.eau(Vector2.ZERO) == 0.0 and C.allure(creux) < 0.62 and j.trempe > 40.0 and j.en_feu == 0.0 and not feu_noye.allume() and jeu.feux.size() == n_feux,
		"la crue : l'eau gagne les creux, pas la butte du réveil ; on y patauge (%d %% de l'allure), on y est trempée, les flammes s'y éteignent, un feu s'y noie et l'on n'en allume pas" % int(C.allure(creux) * 100.0))
	jeu.feux.erase(feu_noye)
	feu_noye.queue_free()
	C.crue = 0.0
	C.boue = 0.0
	# la foudre : un présage, puis elle tombe ; elle blesse autour d'elle, met le feu à l'arbre qu'elle frappe
	C.forcer("orage", 1.0, 9999.0, true)
	C.pluie = 0.0
	var presages := [0]
	var tombees := [0]
	var sur_presage := func(_p, _dans): presages[0] += 1
	var sur_foudre := func(_p, _sur): tombees[0] += 1
	C.presage.connect(sur_presage)
	C.foudre.connect(sur_foudre)
	j.position = arbre_abri.position + Vector2(44.0, 0.0)
	j.sante = 100.0
	j.trempe = 0.0
	j.en_feu = 0.0
	var proie_foudre = jeu._creer(F["proies_jour"][0], "proie", arbre_abri.position + Vector2(-20.0, 6.0))
	var chassees0: int = jeu.chassees
	var comptes0: int = Orvane.en_cours()
	C.frapper(arbre_abri.position, 0.5, arbre_abri)
	var avant_la_foudre: bool = presages[0] == 1 and tombees[0] == 0 and j.sante == 100.0
	C._foudre_dans = 999.0
	C.avancer(0.6)
	C.presage.disconnect(sur_presage)
	C.foudre.disconnect(sur_foudre)
	verif(avant_la_foudre and tombees[0] == 1 and j.sante < 100.0 and j.sante > 60.0 and arbre_abri.brule > 0.0 and I.foyers.size() == 1,
		"la foudre s'annonce, puis tombe sur un arbre : à 44 pixels, la veilleuse est blessée (%d sur 100), et l'arbre prend feu" % int(j.sante))
	verif(not is_instance_valid(proie_foudre) or not proie_foudre.is_in_group("betes") or proie_foudre.pv < proie_foudre.pv_max,
		"une bête au pied de l'arbre est foudroyée")
	verif(jeu.chassees == chassees0 and Orvane.en_cours() == comptes0, "ce que la foudre tue n'est pas une chasse : rien n'est compté")
	if is_instance_valid(proie_foudre):
		proie_foudre.queue_free()
	# un arbre en feu éclaire et protège comme un feu de camp ; à son contact, on prend feu
	var lueur: float = I.foyers[0].eclaire(arbre_abri.position + Vector2(40.0, 0.0))
	var protege: bool = jeu.feu_qui_protege(arbre_abri.position + Vector2(40.0, 0.0)) != null
	j.position = arbre_abri.position + Vector2(12.0, 0.0)
	j.en_feu = 0.0
	j.sante = 100.0
	jeu._temps_du_corps(0.5)
	var en_feu: bool = j.en_feu > 0.0
	jeu._temps_du_corps(1.0)
	verif(lueur > 0.5 and protege and en_feu and j.sante < 100.0 and j.temperature > 60.0,
		"un arbre en feu éclaire et tient les chasseurs à distance comme un feu de camp ; à son contact, la veilleuse prend feu et brûle (santé : %d)" % int(j.sante))
	j.position = decouvert
	j.en_feu = 0.0
	j.sante = 100.0
	j.temperature = 50.0
	# par temps sec, le feu saute aux voisins (jamais plus de INCENDIE_MAX à la fois) ; la pluie l'éteint
	# (sans vent, qui le porterait loin d'eux, et par grande chaleur : que le hasard d'un saut ne décide pas de l'essai)
	var vent_avant: float = C.vent
	var chaleur_avant: float = C.chaleur
	C.vent = 0.0
	C.chaleur = 1.0
	var plus := 1
	var essouffle := 1.0
	for k in 8:
		I.avancer(2.1)
		plus = maxi(plus, I.foyers.size())
		for foyer in I.foyers:
			essouffle = minf(essouffle, foyer.force)
	C.forcer("pluie", 1.0, 9999.0)
	C.chaleur = chaleur_avant
	for k in 240:
		I.avancer(0.5)
	C.vent = vent_avant
	var brules: int = jeu.monde.objets.filter(func(x): return x.calcine).size()
	verif(voisins_max >= 1 and plus > 1 and plus <= RR.INCENDIE_MAX and I.foyers.is_empty(),
		"par temps sec et chaud l'incendie gagne les voisins (jusqu'à %d objets en feu, %d au plus permis) ; la pluie l'éteint (%d objets calcinés)" % [plus, RR.INCENDIE_MAX, brules])
	verif(essouffle < 1.0 and essouffle <= RR.INCENDIE_ESSOUFFLE + 0.001, "à chaque saut l'incendie s'essouffle (il ne rase pas le lieu) : un voisin n'a plus que %d %% de sa force" % int(RR.INCENDIE_ESSOUFFLE * 100.0))
	# brûlé jusqu'au bout, un arbre n'est plus qu'une souche noire
	C.forcer("clair", 0.0, 9999.0)
	var debout = null
	for x in jeu.monde.objets:
		if x.couvert() > 0.0 and x.combustible() and x.position.distance_to(f.position) > 500.0:
			debout = x
			break
	I.enflammer(debout)
	var abrite_en_feu: float = debout.couvert()
	debout.brule = 0.1
	I.avancer(0.2)
	verif(abrite_en_feu == 0.0 and debout.calcine and debout.genre == "souche" and debout.couvert() == 0.0 and not debout.combustible() and I.foyers.is_empty(),
		"brûlé jusqu'au bout, un arbre n'est plus qu'une souche noire : elle n'abrite plus de la pluie, et ne reprend pas feu")
	# sous un arbre pendant l'orage, la foudre finit par choisir cet arbre-là ; seule debout à découvert, elle tombe sur elle
	C.forcer("orage", 1.0, 9999.0)
	# (un arbre seul : sous deux feuillages qui se touchent, la foudre prendrait l'un ou l'autre)
	var refuge = null
	for x in jeu.monde.objets:
		if x.couvert() > 0.0 and x.position.distance_to(f.position) > 500.0 and jeu.monde.autour(x.position, 90.0).filter(func(y): return y.couvert() > 0.0).size() == 1:
			refuge = x
			break
	j.position = refuge.position + Vector2(3.0, 0.0)
	var sur_l_abri := [0]
	var sur_elle := [0]
	var compter := func(p, _dans):
		if p.distance_to(refuge.position) < 1.0:
			sur_l_abri[0] += 1
		if p.distance_to(j.position) < 36.0:
			sur_elle[0] += 1
	C.presage.connect(compter)
	for k in 80:
		C._foudre_dans = 0.0
		C._ciel(0.0)
	var a_l_abri: int = sur_l_abri[0]
	var seule := Vector2.ZERO
	for k in 3600:
		var q3 := Vector2(-2400.0 + 80.0 * (k % 60), -2400.0 + 80.0 * (k / 60))
		var libre := true
		for y in jeu.monde.autour(q3, 175.0):
			if y.couvert() > 0.0:
				libre = false
				break
		if libre:
			seule = q3
			break
	j.position = seule
	sur_elle[0] = 0
	for k in 80:
		C._foudre_dans = 0.0
		C._ciel(0.0)
	C.presage.disconnect(compter)
	C._presages.clear()
	verif(a_l_abri >= 8 and a_l_abri <= 40, "sous un arbre pendant l'orage, la foudre choisit cet arbre-là une fois sur quatre (%d éclairs sur 80)" % a_l_abri)
	verif(seule != Vector2.ZERO and sur_elle[0] >= 5, "seule debout loin de tout arbre, c'est sur elle qu'elle tombe (%d éclairs sur 80)" % sur_elle[0])
	# la jauge du corps dit tout cela
	j.temperature = 12.0
	j.trempe = 80.0
	jeu.ui.maj_hud(jeu)
	var gelee: bool = jeu.ui._jauges.corps == 12.0 and jeu.ui._jauges.trempe == 80.0 and jeu.ui._jauges.nom_du_corps() == "Gelée"
	j.temperature = 90.0
	jeu.ui.maj_hud(jeu)
	var brulante: bool = jeu.ui._jauges.nom_du_corps() == "Brûlante"
	j.en_feu = 2.0
	jeu.ui.maj_hud(jeu)
	verif(gelee and brulante and jeu.ui._jauges.nom_du_corps() == "En feu", "la jauge du corps suit : « Gelée » à 12, « Brûlante » à 90, « En feu » quand elle brûle, et la goutte quand elle est trempée")
	# (tout revient au calme pour la suite : le ciel, le sol, le corps)
	C.forcer("clair", 0.0, 9999.0)
	C.boue = 0.0
	C.crue = 0.0
	j.trempe = 0.0
	j.temperature = 50.0
	j.en_feu = 0.0
	j.sante = 100.0
	j.peur = 0.0
	j.position = Vector2(0, 0)

	print("3. Du doigt")
	var tac = jeu.tactile
	tac.activer()
	var clic := InputMap.action_get_events("agir").any(func(e): return e is InputEventMouseButton)
	verif(tac.actif and jeu.ui.tactile and not clic, "l'écran tactile s'allume : les boutons remplacent les touches, et un toucher ne frappe plus")
	var depart := Vector2(200, tac._taille().y - 150)
	_toucher(tac, 0, depart, true)
	_glisser(tac, 0, depart + Vector2(70, 20))
	# (deux images : la couche tactile presse les actions de marche dans son _process)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := Input.get_vector("gauche", "droite", "haut", "bas")
	_toucher(tac, 0, depart + Vector2(70, 20), false)
	await get_tree().process_frame
	await get_tree().process_frame
	var arret := Input.get_vector("gauche", "droite", "haut", "bas")
	verif(dir.x > 0.6 and dir.y > 0.0 and arret == Vector2.ZERO, "le pouce gauche la fait marcher (%.2f, %.2f), et levé, l'arrête" % [dir.x, dir.y])
	_toucher(tac, 1, tac.position_bouton("feu"), true)
	var feu := Input.is_action_pressed("feu")
	_toucher(tac, 1, tac.position_bouton("feu"), false)
	_toucher(tac, 2, tac.position_bouton("agir"), true)
	var frappe := Input.is_action_pressed("agir")
	_toucher(tac, 2, tac.position_bouton("agir"), false)
	verif(feu and frappe and not Input.is_action_pressed("agir") and not Input.is_action_pressed("feu"), "les boutons pressent les actions du clavier (Feu, Agir), et les lâchent")
	jeu.ui.message("Ramasse des brindilles (Espace). Avec 4 bois et 2 pierres : un feu (1).")
	var dit: String = jeu.ui._messages.back()[0].text
	verif(dit.contains("(Agir)") and dit.contains("bouton Feu"), "les messages nomment les boutons : « %s »" % dit)

	print("4. La nuit")
	jeu.horloge = jeu.jour * 240.0 - 240.0 * jeu.part_nuit - 3.0
	j.position = f.position + Vector2(0, 30)
	f.ajouter(6)
	var plus_pres := INF
	var vus := 0
	for i in 60:
		await _attendre(1.0)
		j.position = f.position + Vector2(0, 30)
		for b in jeu.get_tree().get_nodes_in_group("betes"):
			if b.role == "chasseur":
				vus = maxi(vus, 1)
				plus_pres = minf(plus_pres, b.position.distance_to(f.position) / f.rayon())
	verif(jeu.lumiere_du_jour() <= 0.0, "la nuit est tombée (%s)" % jeu.texte_horloge())
	verif(vus > 0, "des chasseurs viennent : %s" % ", ".join(PackedStringArray(jeu.get_tree().get_nodes_in_group("betes").filter(func(b): return b.role == "chasseur").map(func(b): return str(b.nom)))))
	verif(vus > 0 and plus_pres >= 0.78, "aucun n'entre dans la lumière du feu (au plus près : %.2f du rayon)" % plus_pres)
	verif(j.peur < 30.0, "dans la lumière, la peur reste basse (%d)" % int(j.peur))

	print("5. Le noir")
	var proie = jeu._creer(F["proies_jour"][0], "proie", j.position + Vector2(20, 0))
	proie.flair = 0.0
	for i in 12:
		if is_instance_valid(proie):
			proie.position = j.position + Vector2(20, 0)
			jeu.agir()
	# (douze coups dans la même image : la bête ne meurt qu'une fois, et n'est comptée qu'une fois)
	verif(jeu.chassees == 1 and int(j.inventaire["viande"]) > 0, "une bête chassée donne de la viande (%d), une seule fois (%d chassée)" % [int(j.inventaire["viande"]), jeu.chassees])
	verif(Orvane.en_cours() > 0, "ce qui est arrivé est compté pour Orvane (%d comptes)" % Orvane.en_cours())
	# (la nuit tire à sa fin : on revient à son début, pour que les quarante secondes suivantes soient toutes dans le noir)
	jeu.horloge = jeu.jour * 240.0 - 240.0 * jeu.part_nuit + 2.0
	j.position = f.position + Vector2(f.rayon() + 700.0, 0)
	var peur0: float = j.peur
	var peur_max := peur0
	var perdu := 0.0
	var echo := false
	for i in 40:
		j.sante = 100.0
		await _attendre(1.0)
		perdu += 100.0 - j.sante
		peur_max = maxf(peur_max, j.peur)
		for b in jeu.get_tree().get_nodes_in_group("betes"):
			if b.role == "echo":
				echo = true
	j.sante = 100.0
	verif(peur_max > peur0 + 40.0, "loin du feu, dans le noir, la peur monte (%d → %d)" % [int(peur0), int(peur_max)])
	verif(echo, "la peur haute, ce qu'on a tué revient en écho")
	verif(perdu > 0.0, "le noir coûte de la santé (%d points perdus en quarante secondes)" % int(perdu))

	await _la_memoire(F, f)

	# (la partie telle qu'elle est, avant l'aube, un arbre abattu en plus : elle sera reprise à la fin, et doit revenir pareille)
	for x in jeu.monde.objets:
		if (x.genre == "arbre" or x.genre == "sapin") and x.reste == x.plein:
			for k in x.plein:
				x.recolter()
			break
	jeu.climat.boue = 0.4
	jeu.joueur.trempe = 30.0
	jeu.joueur.temperature = 41.0
	jeu.savoir["essai-affut"] = 7.5
	var gardee: Dictionary = load("res://scripts/partie_gardee.gd").photo(jeu)
	jeu.savoir.erase("essai-affut")
	jeu.climat.boue = 0.0
	jeu.joueur.trempe = 0.0
	jeu.joueur.temperature = 50.0

	_la_durete()
	_le_corps_a_l_ecran()
	_la_noire(F)
	_le_pistage(F)
	_les_empreintes(F)
	_le_lance_pierre(F)
	_l_atelier(F)
	_le_jardin_et_les_betes(F)
	_la_botanique(F)
	await _la_carte()
	await _la_partie_sur_le_compte()
	await _les_lots(F)

	print("6. L'aube, la fin")
	jeu.horloge = jeu.jour * 240.0 + 20.0
	await _attendre(2.0)
	verif(jeu.nuits == 1, "le jour revient : %d nuit%s tenue%s" % [jeu.nuits, "s" if jeu.nuits > 1 else "", "s" if jeu.nuits > 1 else ""])
	j.faim = 100.0
	j.peur = 0.0
	j.sante = 0.0
	# (elle tombe d'abord : l'écran de fin vient jeu.DUREE_MORT secondes après)
	for i in 40:
		await _attendre(0.25)
		if not jeu.en_partie:
			break
	verif(not jeu.en_partie, "la santé à zéro, la partie s'arrête sur l'écran de fin, même rassasiée et calme")
	verif(Orvane.cle_jeu != "" and Orvane.lots_en_attente() == 0 and Orvane.en_cours() == 0, "le jeu a sa clé d'Orvane, mais l'essai ne lui envoie rien")

	print("7. La partie gardée")
	var PG := load("res://scripts/partie_gardee.gd")
	PG.ecrire_donnees(gardee)
	var lu: Dictionary = PG.lire()
	jeu.ui.montrer_reprise(lu)
	verif(not lu.is_empty() and jeu.ui._reprise.visible and not jeu.ui._entrer.principal and str(jeu.ui._reprise.libelle).contains("Forêt"),
		"une partie gardée se relit, et l'écran-titre propose de la reprendre (« %s »)" % jeu.ui._reprise.libelle)
	await jeu._commencer(str(lu["biome"]), lu)
	var revenue: Dictionary = JSON.parse_string(JSON.stringify(PG.photo(jeu)))
	var avant_g: Dictionary = JSON.parse_string(JSON.stringify(gardee))
	var souches := func(d): return d["objets"].filter(func(x): return x[1] == "souche").size()
	var entames := func(d): return d["objets"].filter(func(x): return x[1] != "souche" and int(x[5]) < 4 and x[0] in ["arbre", "sapin", "rocher"]).size()
	var pareil: bool = jeu.en_partie and souches.call(avant_g) > 0 and revenue["objets"].size() == avant_g["objets"].size() and souches.call(revenue) == souches.call(avant_g) \
		and entames.call(revenue) == entames.call(avant_g) and revenue["joueur"]["inventaire"] == avant_g["joueur"]["inventaire"] \
		and revenue["feux"].size() == avant_g["feux"].size() and absf(float(revenue["horloge"]) - float(avant_g["horloge"])) < 0.5 \
		and revenue["nuits"] == avant_g["nuits"] and revenue["tuees"] == avant_g["tuees"] and revenue["graine"] == avant_g["graine"] \
		and Vector2(revenue["joueur"]["x"], revenue["joueur"]["y"]).distance_to(Vector2(avant_g["joueur"]["x"], avant_g["joueur"]["y"])) < 1.0
	verif(pareil, "reprise, elle revient pareille : %d objets dont %d souches, le sac (%d bois), %d feu, l'heure, %d nuit, %d bête tuée" % [
		revenue["objets"].size(), souches.call(revenue), int(revenue["joueur"]["inventaire"].get("bois", 0)), revenue["feux"].size(),
		int(revenue["nuits"]), revenue["tuees"].size()])
	verif(absf(jeu.climat.boue - 0.4) < 0.02 and absf(jeu.joueur.trempe - 30.0) < 0.5 and absf(jeu.joueur.temperature - 41.0) < 0.5 and jeu.monde.objets.filter(func(x): return x.calcine).size() > 0,
		"avec elle reviennent le sol détrempé, la veilleuse mouillée, sa température, et ce que l'incendie a brûlé")
	verif(absf(float(jeu.savoir.get("essai-affut", 0.0)) - 7.5) < 0.01, "et ce qu'elle avait appris des bêtes, à l'affût")
	verif(not FileAccess.file_exists("user://partie.json") or PG.lire() == lu, "l'essai ne réécrit pas la partie gardée")
	PG.effacer()
	jeu.ui.montrer_reprise({})
	verif(not jeu.ui._reprise.visible and jeu.ui._entrer.principal, "effacée, l'écran-titre ne propose plus que d'entrer dans la nuit")
	_les_pattes()
	await _lieu_sans_bord()
	await _la_flore()
	await _la_repartition()
	await _les_pays()
	await _l_artisanat()
	await _la_cueillette_nourriciere()
	await _les_retouches()
	await _la_faim_de_la_noire()
	await _le_collet_de_la_noire()
	await _la_noire_reunie()
	await _conclure()


# ce que la relecture de la cueillette et de l'artisanat a trouvé, et qui est réparé : en pause, rien ne repousse ; un arbre
# chargé relâche ses fruits à son pied (l'affût y tient) ; une bête dont la cible a changé sous sa dent ne casse rien ; ce qui
# rafraîchit ne réchauffe pas qui a froid ; un second baume s'ajoute au premier ; au doigt, « Manger » voit les fruits
func _les_retouches() -> void:
	print("12. Les retouches")
	await jeu._commencer("foret")
	var W = jeu.monde
	var j = jeu.joueur
	var RR = jeu.R
	var O = jeu.ObjetDuLieu
	var arbre = null
	for x in W.objets:
		if x.genre == "arbre" and int(x.fruits_plein) > 0 and int(x.tombes_plein) > 0:
			arbre = x
			break
	if arbre == null:
		print("    (pas d'arbre chargé dans ce lieu : les retouches des fruits ne sont pas essayées)")
	else:
		# en pause, ses fruits ne repoussent pas
		arbre.fruits = 0
		arbre.tombes = 0
		arbre._lache = 0.0
		arbre._vide_de_fruits()
		var r0: float = arbre._repousse_fruits
		O.en_pause = true
		arbre._process(100.0)
		var en_pause_r: float = arbre._repousse_fruits
		O.en_pause = false
		arbre._process(1.0)
		verif(r0 > 0.0 and is_equal_approx(en_pause_r, r0) and arbre._repousse_fruits < r0,
			"en pause, un arbre vidé ne repousse pas (%d s restent après cent secondes de pause) ; la partie reprise, si" % int(en_pause_r))
		# un fruit tombé mangé : l'arbre en relâche un autre de ses branches
		arbre._repousse_fruits = 0.0
		arbre.fruits = int(arbre.fruits_plein)
		arbre.tombes = 1
		arbre.manger_tombe()
		var vide_sol: int = int(arbre.tombes)
		arbre._process(RR.FRUIT_TOMBE + 1.0)
		verif(vide_sol == 0 and int(arbre.tombes) == 1 and int(arbre.fruits) == int(arbre.fruits_plein) - 1,
			"un fruit tombé qu'une bête a mangé : l'arbre chargé en lâche un autre à son pied (%d s plus tard) ; l'affût y tient tant qu'il porte" % int(RR.FRUIT_TOMBE))
	# une bête dont la cible a changé (un arbre devenu souche) : rien ne casse
	var Objet := load("res://scripts/objet.gd")
	var souche = Objet.new()
	souche.preparer("souche", Color.WHITE, 77)
	jeu.mangee(null, souche, 1.0)
	souche.free()
	verif(true, "une bête qui broutait sous un arbre devenu souche cherche autre chose, sans faute")
	# ce qui rafraîchit ne réchauffe pas qui a froid
	j.temperature = 20.0
	jeu.fraicheur = 0.0
	jeu._rafraichir(8.0)
	var froide: float = j.temperature
	var gardee: bool = jeu.fraicheur > 0.0
	j.temperature = 76.0
	jeu._rafraichir(8.0)
	verif(froide == 20.0 and gardee and is_equal_approx(j.temperature, 68.0),
		"une pulpe, une noix de coco ne réchauffent pas qui a froid (20 reste 20, la fraîcheur gardée pour plus tard) ; elles rafraîchissent qui a chaud (76 → %d)" % int(j.temperature))
	jeu.fraicheur = 0.0
	j.temperature = 50.0
	# un second baume s'ajoute au premier
	var B = jeu.botanique
	B.onguent = RR.ONGUENT * 0.5
	j.inventaire["baume_aromates"] = 1
	B.oindre()
	verif(is_equal_approx(B.onguent, RR.ONGUENT * 1.5), "un second baume d'aromates s'ajoute au premier qui agit encore (%d s de soin)" % int(B.onguent))
	B.onguent = 0.0
	# au doigt, « Manger » voit tout ce que E mange
	for k in jeu.A_MANGER:
		j.inventaire[k] = 0
	var rien: bool = not jeu.tactile._disponible("manger")
	j.inventaire["pomme"] = 1
	var pomme: bool = jeu.tactile._disponible("manger")
	j.inventaire["pomme"] = 0
	verif(rien and pomme, "au doigt, le bouton « Manger » s'allume pour une pomme, comme pour la viande")


# la Noire, acte 5 : la faim (scripts/noire_faim.gd) — elle rôde dès le crépuscule, saccage ce qui est posé hors de la lumière
# d'un feu vif (une chose à la fois, deux par nuit), prend elle-même les bêtes attachées dans le noir ; ce qu'elle a saccagé
# reste en épave, qu'on répare ou qu'on replie. Jouée sans attendre, comme les autres actes : son scénario, son corps, les
# bêtes à l'attache, l'épouvantail. Le camp est posé dans une clairière qu'on dégage : rien n'y dépend du tirage du lieu.

# tant de secondes de la nuit du camp (noire.maj, son corps, l'élevage, le jardin), « voir » appelé à chaque pas ; avec_le_jour :
# l'horloge avance, et la nuit qui tombe le lui dit (ce que fait principal.gd)
func _faim_joue(secondes: float, voir: Callable = Callable(), avec_le_jour: bool = false) -> void:
	for i in int(round(secondes / 0.05)):
		_faim_pas(avec_le_jour)
		if voir.is_valid():
			voir.call(i * 0.05)


# un vingtième de seconde de cette nuit-là
func _faim_pas(avec_le_jour: bool = false) -> void:
	var N = jeu.noire
	var dt := 0.05
	if avec_le_jour:
		var etait: bool = jeu.jour_du_ciel() <= 0.0
		jeu.horloge += dt
		if jeu.jour_du_ciel() <= 0.0 and not etait:
			N.tombee()
	N.maj(dt)
	if N.corps != null and is_instance_valid(N.corps):
		N.corps._conduire(dt)
		N.corps._animer(dt)
	jeu.elevage.maj(dt)
	jeu.jardin.maj(dt)
	for b in jeu.elevage.betes:
		if is_instance_valid(b):
			b._conduire(dt)


# la nuit se joue jusqu'à ce que « quand » soit vrai : les secondes passées (-1 : ce n'est pas arrivé en « au_plus » secondes)
func _faim_jusqu_a(quand: Callable, au_plus: float = 60.0) -> float:
	for i in int(round(au_plus / 0.05)):
		if quand.call():
			return i * 0.05
		_faim_pas()
	return -1.0


# la Noire est sur la chose qu'elle a choisie, et la flaire depuis une seconde
func _faim_au_flair() -> bool:
	var N = jeu.noire
	return _faim_jusqu_a(func(): return N.etat == "hume" and N.faim._sur_place and N._t > 1.0, 50.0) >= 0.0


# un feu de camp, là, avec tant de bois (l'horloge du jeu ne tourne pas pendant qu'on joue la Noire : il ne baisse pas)
func _faim_feu(p: Vector2, bois: float):
	var feu = jeu.Feu.new()
	feu.jeu = jeu
	feu.position = p
	feu.bois = bois
	jeu.monde.add_child(feu)
	jeu.feux.append(feu)
	return feu


# la nuit de la faim, la Noire déjà en chemin (à 900 pixels, du côté gauche) ; ce qu'elle a mordu, ses comptes : remis à neuf
func _faim_nuit(acte: int = -1) -> void:
	var N = jeu.noire
	var RR = jeu.R
	N._disparaitre()
	N.etat = "dort"
	N.faim.soir = false
	jeu.nuits = N.premiere_nuit(RR.NOIRE_FAIM if acte < 0 else acte)
	N.mettre_en_scene(RR.NOIRE_FAIM if acte < 0 else acte, 900.0, PI)
	N._feinte = 999.0


func _la_faim_de_la_noire() -> void:
	print("13. La Noire : la faim")
	await jeu._commencer("foret")
	await get_tree().process_frame
	await get_tree().process_frame
	var j = jeu.joueur
	var N = jeu.noire
	var F = N.faim
	var A = jeu.atelier
	var E = jeu.elevage
	var J = jeu.jardin
	var W = jeu.monde
	var RR = jeu.R
	var T = jeu.traces
	var inv: Dictionary = j.inventaire
	var Camp = load("res://scripts/campement.gd")
	var Epave = load("res://scripts/campement_epave.gd")
	jeu.climat.forcer("clair", 0.0, 9999.0)
	# (une clairière : ni arbre, ni buisson, ni vestige à 900 pixels ; ni bête, ni feu)
	var ici := Vector2(-300.0, 250.0)
	for o in W.autour(ici, 900.0):
		if float(o.rayon) > 0.0 or str(o.genre) == "buisson":
			W.retirer(o)
	for x in A.poses.duplicate():
		if is_instance_valid(x) and x.position.distance_to(ici) < 1100.0:
			A.poses.erase(x)
			x.queue_free()
	_a_l_heure(true)
	_remettre(ici)
	j.torche = 0.0
	var D: float = RR.DUREE
	var duree_nuit: float = D * jeu.part_nuit
	var soir_h: float = floorf(jeu.horloge / D) * D + D * (1.0 - jeu.part_nuit)
	var nuit_h: float = jeu.horloge
	var journal_avant = jeu.sons.journal
	jeu.sons.journal = []
	var dits := func() -> String:
		return " | ".join(PackedStringArray(jeu.ui._messages.map(func(m): return str(m[0].text))))

	# --- les nombres : la dixième nuit, et celles d'après ---
	var actes: Array = RR.NOIRE_ACTES
	verif(N.acte_de(N.premiere_nuit(RR.NOIRE_FAIM)) == RR.NOIRE_FAIM and N.premiere_nuit(RR.NOIRE_FAIM) == 9 and N.acte_de(8) == 4 and N.acte_de(99) >= RR.NOIRE_FAIM
		and RR.NOIRE_DEPART.size() == RR.NOIRE_TORCHE.size() and RR.NOIRE_DEPART.size() > int(actes.max()) and float(RR.NOIRE_DEPART[RR.NOIRE_FAIM]) < 0.0
		and float(RR.NOIRE_TORCHE[RR.NOIRE_FAIM]) < float(RR.NOIRE_TORCHE[4]) and float(RR.NOIRE_TORCHE[RR.NOIRE_FAIM]) > RR.NOIRE_PRESAGE,
		"acte 5, la faim : à la %de nuit, et pour toutes celles d'après ; elle part avant la nuit (%.1f nuit), la torche ne la tient plus que %d secondes" % [
		N.premiere_nuit(RR.NOIRE_FAIM) + 1, float(RR.NOIRE_DEPART[RR.NOIRE_FAIM]), int(RR.NOIRE_TORCHE[RR.NOIRE_FAIM])])

	# --- le crépuscule : son appel quand le jour baisse, elle à la lisière quand la nuit commence ---
	var feu = _faim_feu(ici + Vector2(30.0, 0.0), 60.0)
	var r: float = feu.rayon()
	var epouvantail = A._creer("epouvantail", feu.position + Vector2(40.0, 90.0), {})
	# (ce que fait un soir : [quand elle appelle, quand elle est à la lisière] en secondes depuis la nuit ; NAN : pas de la nuit)
	var un_soir := func(nuits: int, distance: float, jusqu_a: float) -> Dictionary:
		N._disparaitre()
		N.etat = "dort"
		N.faim.soir = false
		N.acte = N.acte_de(maxi(nuits - 1, 0))
		N.taniere = ici + Vector2(-distance, 0.0)
		N.ou = N.taniere
		jeu.nuits = nuits
		jeu.horloge = soir_h - 70.0
		jeu.sons.journal = []
		var m := {"appel": NAN, "lisiere": NAN, "corps_de_jour": false, "regard_de_jour": false, "tombee_la_renvoie": false, "appels": 0, "avant": 0}
		var avant_etat := ["dort"]
		_faim_joue(70.0 + jusqu_a, func(_t):
			var t: float = jeu.horloge - soir_h
			if is_nan(m["appel"]) and N._appel and N.etat != "dort":
				m["appel"] = t
			if is_nan(m["lisiere"]) and N.etat == "guette":
				m["lisiere"] = t
			if t < 0.0 and N.corps != null:
				m["corps_de_jour"] = true
			if t < 0.0 and N.etat != "dort" and epouvantail.etat.has("regard"):
				m["regard_de_jour"] = true
			# (la nuit qui tombe ne la renvoie pas dans sa tanière)
			if t >= 0.0 and t < 0.1 and avant_etat[0] != "dort" and N.etat == "dort":
				m["tombee_la_renvoie"] = true
			avant_etat[0] = N.etat, true)
		m["appels"] = jeu.sons.journal.filter(func(x): return str(x[1]) == "appel").size()
		return m
	N.su.erase("crepuscule")
	var pres_s: Dictionary = un_soir.call(N.premiere_nuit(RR.NOIRE_FAIM), RR.NOIRE_TANIERE_MIN, 30.0)
	var su_crepuscule: bool = N.su.has("crepuscule")
	var acte_soir: int = N.acte
	var loin_s: Dictionary = un_soir.call(N.premiere_nuit(RR.NOIRE_FAIM), RR.NOIRE_TANIERE_MAX, 30.0)
	var chasse_s: Dictionary = un_soir.call(N.premiere_nuit(4), RR.NOIRE_TANIERE_MIN, 12.0)
	var attendu: float = float(RR.NOIRE_DEPART[RR.NOIRE_FAIM]) * duree_nuit
	verif(absf(pres_s["appel"] - attendu) < 0.2 and pres_s["appel"] < -RR.TRANSITION and pres_s["appels"] == 1 and su_crepuscule and acte_soir == RR.NOIRE_FAIM
		and not pres_s["tombee_la_renvoie"] and not loin_s["tombee_la_renvoie"],
		"elle n'attend plus la nuit : son appel s'entend %d secondes avant, quand le jour baisse (une fois) ; la veilleuse le retient ; la nuit qui tombe ne la renvoie pas" % int(-pres_s["appel"]))
	verif(absf(pres_s["lisiere"]) < 12.0 and absf(loin_s["lisiere"]) < 12.0 and loin_s["lisiere"] > pres_s["lisiere"] + 5.0 and pres_s["corps_de_jour"] and pres_s["regard_de_jour"],
		"elle est à la lisière du feu quand la nuit commence : %.1f s d'une tanière à %d pixels, %.1f s à %d (qui dort plus loin la voit arriver plus tard) ; l'épouvantail la regarde venir dans le jour qui tombe" % [
		pres_s["lisiere"], int(RR.NOIRE_TANIERE_MIN), loin_s["lisiere"], int(RR.NOIRE_TANIERE_MAX)])
	verif(is_nan(chasse_s["appel"]) or chasse_s["appel"] > 0.0, "avant la faim, rien ne change : à l'acte 4, elle attend la nuit pour partir%s" % (
		"" if is_nan(chasse_s["appel"]) else " (%.1f s après la tombée)" % chasse_s["appel"]))
	jeu.horloge = nuit_h
	A.poses.erase(epouvantail)
	epouvantail.queue_free()

	# --- le saccage : ce qui est posé hors de la lumière d'un feu vif, une chose à la fois, deux par nuit ---
	# (le feu : 198 pixels de rayon, il garde à 168. Dans sa lumière : la tente. Dehors : le filet et sa prise, l'épouvantail, le
	# récupérateur et son eau)
	var tente = A._creer("tente", feu.position + Vector2(60.0, -110.0), {})
	var filet = A._creer("filet", feu.position + Vector2(-300.0, -40.0), {"prise": {"id": "", "nom": "une bête", "masse": 2.0}})
	epouvantail = A._creer("epouvantail", feu.position + Vector2(330.0, 60.0), {})
	var citerne = A._creer("recuperateur", feu.position + Vector2(-60.0, 420.0), {"eau": 3.0})
	j.position = feu.position + Vector2(-30.0, 0.0)
	N.su.erase("faim")
	N.su.erase("assez")
	jeu.sons.journal = []
	T.vider()
	_faim_nuit()
	var s := {"lisiere": -1.0, "part": -1.0, "sur": -1.0, "mord": -1.0, "fini": -1.0, "premiere": null, "seconde": null, "part2": -1.0, "fini1": -1.0,
		"pres_feu": INF, "tete_guet": 0.0, "tete_flair": -9.0, "secoue": 0.0, "gueule": 0.0, "ecart": 0.0, "mordu": 0.0, "alerte": 0.0, "profil": 1.0, "dit_flair": "",
		"dit_fait": "", "grogne_flair": 0}
	_faim_joue(110.0, func(t):
		if N.corps == null:
			return
		var c = N.corps
		s["pres_feu"] = minf(s["pres_feu"], c.position.distance_to(feu.position) / r)
		if s["lisiere"] < 0.0 and N.etat == "guette":
			s["lisiere"] = t
		# (sa tête au guet, avant qu'elle ne quitte le cercle pour la première fois : ensuite elle guette d'ailleurs, autrement)
		if N.etat == "guette" and s["part"] < 0.0:
			s["tete_guet"] = c._tete_rot
		if N.etat == "hume" and s["part"] < 0.0:
			s["part"] = t
			s["premiere"] = F.cible
			jeu.sons.journal = []
		if N.etat == "hume" and F._sur_place and F.cible == s["premiere"]:
			if s["sur"] < 0.0:
				s["sur"] = t
				s["dit_flair"] = dits.call()
			s["tete_flair"] = maxf(s["tete_flair"], c._tete_rot)
			s["ecart"] = absf(c.position.x - F.cible.position.x)
			s["profil"] = minf(s["profil"], 1.0 - c.de_face) if t > s["sur"] + 2.0 else s["profil"]
		if N.etat == "saccage" and F.cible == s["premiere"]:
			if s["mord"] < 0.0:
				s["mord"] = t
				s["grogne_flair"] = jeu.sons.journal.filter(func(x): return str(x[1]) == "grogne").size()
			s["secoue"] = maxf(s["secoue"], c._secoue)
			s["gueule"] = maxf(s["gueule"], c._gueule)
			s["mordu"] = maxf(s["mordu"], float(F.cible.etat.get("mordu", 0.0)))
		if s["mord"] >= 0.0 and s["fini1"] < 0.0 and F.prises == 1:
			s["fini1"] = t
			s["dit_fait"] = dits.call()
		if s["fini1"] >= 0.0 and N.etat == "hume" and s["part2"] < 0.0:
			s["part2"] = t
			s["seconde"] = F.cible
		if s["fini"] < 0.0 and F.prises == 2:
			s["fini"] = t)
	var entendus: Array = jeu.sons.journal.map(func(x): return str(x[1]).rstrip("0123456789"))
	verif(s["premiere"] == filet and s["part"] - s["lisiere"] >= RR.NOIRE_FAIM_ATTENTE - 0.6 and s["part"] - s["lisiere"] < RR.NOIRE_FAIM_ATTENTE + 4.0
		and F.est_epave(filet) and not filet.etat.has("prise") and bool(filet.etat.get("mangee", false)) and N.su.has("faim"),
		"tenue par le feu %d secondes, elle quitte le cercle et s'en prend à ce qui est posé dans le noir : le filet et sa prise d'abord (la viande), qu'elle mange ; la veilleuse le retient" % int(s["part"] - s["lisiere"]))
	verif(absf(s["mord"] - s["sur"] - RR.NOIRE_FLAIRE) < 0.3 and s["grogne_flair"] >= 2 and str(s["dit_flair"]).contains("Elle flaire ton filet")
		and absf(s["fini1"] - s["mord"] - RR.NOIRE_SACCAGE) < 0.3 and str(s["dit_fait"]).contains("Ton filet est en pièces") and str(s["dit_fait"]).contains("mangé"),
		"elle s'annonce : sur la chose, elle la flaire et gronde %.1f s (%d grondements, « Elle flaire ton filet ») avant d'y mettre la dent ; %.1f s plus tard, il est en pièces, et le jeu le dit" % [
		s["mord"] - s["sur"], s["grogne_flair"], s["fini1"] - s["mord"]])
	verif(s["tete_flair"] > s["tete_guet"] + 0.15 and s["tete_flair"] > 0.4 and s["profil"] > 0.9 and s["secoue"] > 0.9 and s["gueule"] > 0.1 and s["mordu"] > 0.8
		and absf(s["ecart"] - RR.NOIRE_LARGEUR * F.MUSEAU) < 30.0,
		"son geste : la tête basse sur la chose (%.2f radian plus bas qu'au guet), de profil, à une longueur de cou (%d pixels) ; puis elle la secoue, la gueule entrouverte, et la chose tressaute" % [
		s["tete_flair"] - s["tete_guet"], int(s["ecart"])])
	verif(entendus.has("cede") and entendus.has("pierre") and T.pres(filet.position, 260.0, 2),
		"on l'entend (la corde qui cède, une pierre de lest qui roule), et la terre garde ses pattes autour de l'épave")
	# (la seconde : la plus proche d'elle à ce moment-là, l'épouvantail ou le récupérateur ; l'autre reste)
	var seconde = s["seconde"]
	var autre = citerne if seconde == epouvantail else epouvantail
	verif((seconde == epouvantail or seconde == citerne) and s["part2"] - s["fini1"] >= RR.NOIRE_FAIM_REPIT - 0.6 and s["part2"] - s["fini1"] < RR.NOIRE_FAIM_REPIT + 4.0
		and F.est_epave(seconde) and entendus.has("brise") and entendus.has("dechire"),
		"une chose à la fois : %d secondes de répit, puis %s ; on entend son bois casser, sa toile se déchirer" % [int(s["part2"] - s["fini1"]), F.CHOSES[str(seconde.genre)][0]])
	verif(F.prises == RR.NOIRE_SACCAGES and s["fini"] > 0.0 and s["fini"] - s["lisiere"] < 79.0 and not F.est_epave(autre) and N.su.has("assez") and (N.etat == "guette" or N.etat == "tourne"),
		"%d choses par nuit, pas davantage (la seconde %d secondes après son arrivée : cela tient dans la plus courte nuit) : %s, dans le noir aussi, est intact ; elle ne fait plus que tourner" % [
		RR.NOIRE_SACCAGES, int(s["fini"] - s["lisiere"]), F.CHOSES[str(autre.genre)][0]])
	verif(not F.est_epave(tente) and s["pres_feu"] >= 0.97 and j.sante == 100.0,
		"ce qui reste juste : la tente, dans la lumière du feu, est intacte ; la Noire n'y est jamais entrée (au plus près, %.2f rayon) ; la veilleuse n'a rien" % s["pres_feu"])

	# (au jour : ce qu'elle a laissé)
	N.aube()
	var dit_aube: String = dits.call()
	verif(dit_aube.contains("Le jour se lève sur ce qu'elle a laissé : 2 choses en pièces") and F.prises == 0 and not F.soir and N.etat == "rentre"
		and T.pres(seconde.position, 260.0, 2),
		"à l'aube, elle rentre, et le jour montre ce qu'elle a laissé (le jeu le dit) : les épaves, ses empreintes autour")

	# --- l'épouvantail tremble à son approche ; en pièces, il ne garde plus rien ---
	for x in [tente, filet, epouvantail, citerne]:
		A.poses.erase(x)
		x.queue_free()
	epouvantail = A._creer("epouvantail", feu.position + Vector2(0.0, -230.0), {})
	var gardait: bool = J.garde(epouvantail.position + Vector2(60.0, 0.0))
	_faim_nuit()
	var ep := {"avant": 0.0, "sur": 0.0, "regard": false}
	var fait_ep: float = _faim_jusqu_a(func():
		if N.corps != null and N.etat == "hume":
			var al: float = float(epouvantail.etat.get("alerte", 0.0))
			if F._sur_place:
				ep["sur"] = maxf(ep["sur"], al)
			else:
				ep["avant"] = maxf(ep["avant"], al)
			ep["regard"] = ep["regard"] or absf(angle_difference(float(epouvantail.etat.get("regard", 9.0)), (N.corps.position - epouvantail.position).angle())) < 0.2
		return F.est_epave(epouvantail), 60.0)
	verif(gardait and fait_ep > 0.0 and ep["avant"] > 0.7 and ep["sur"] > 0.99 and ep["regard"] and not J.garde(epouvantail.position + Vector2(60.0, 0.0))
		and float(epouvantail.etat.get("alerte", 1.0)) == 0.0 and not epouvantail.etat.has("regard"),
		"l'épouvantail la regarde venir et tremble déjà à son approche (%.2f), de tout son bois quand elle le flaire (%.2f) ; en pièces, il ne tremble plus, ne regarde plus, ne garde plus le jardin" % [ep["avant"], ep["sur"]])
	A.poses.erase(epouvantail)
	epouvantail.queue_free()

	# --- ce qui la fait lâcher : une bûche, un galet, la lumière qui revient ; et la veilleuse qui sort ---
	# (une seule chose dans le noir, assez près du feu pour que sa gerbe d'étincelles porte)
	var hamac = A._creer("hamac", feu.position + Vector2(0.0, -230.0), {})
	_faim_nuit()
	var au_flair: bool = _faim_au_flair()
	N.corps.gerbe(feu)
	var lache: bool = N.etat == "sursaut" and F.cible == null and not hamac.etat.has("mordu")
	var dit_lache: String = dits.call()
	var repart: float = _faim_jusqu_a(func(): return N.etat == "hume", 40.0)
	# (un galet, pendant qu'elle flaire de nouveau)
	var au_flair2: bool = _faim_au_flair()
	N.corps.blesser(RR.DEGATS_TIR * RR.TIR_NOIRE, j.position)
	var lache2: bool = N.etat == "recule" and F.cible == null
	# (la lumière qui revient : le feu nourri jusqu'au comble garde de nouveau le hamac)
	var au_flair3: bool = _faim_au_flair()
	feu.bois = RR.FEU_MAX
	_faim_joue(0.2)
	var lache3: bool = F.cible == null and N.etat != "saccage" and F.gardee(hamac.position)
	var dit_lumiere: String = dits.call()
	_faim_joue(40.0)
	verif(au_flair and lache and dit_lache.contains("Elle lâche ton hamac") and repart >= RR.NOIRE_FAIM_ATTENTE - 2.5 and au_flair2 and lache2,
		"une bûche jetée dans le feu pendant qu'elle flaire : elle sursaute et lâche (« Elle lâche ton hamac »), et n'y revient que %d secondes plus tard ; un galet la fait lâcher aussi" % int(repart))
	verif(au_flair3 and lache3 and dit_lumiere.contains("La lumière a repris ton hamac") and not F.est_epave(hamac) and F.prises == 0,
		"le feu nourri, sa lumière reprend le hamac : elle s'en écarte, et n'y touche plus de la nuit")
	# (le feu baisse : sa lumière se retire, ce qu'elle gardait ne l'est plus)
	N.su.erase("garde")
	feu.bois = 110.0
	_faim_nuit()
	_faim_joue(RR.NOIRE_FAIM_ATTENTE + 30.0)
	var gardee_n: bool = not F.est_epave(hamac) and F.prises == 0 and N.su.has("garde")
	feu.bois = 40.0
	var tombe: float = _faim_jusqu_a(func(): return F.est_epave(hamac), 60.0)
	verif(gardee_n and tombe > 0.0 and F.prises == 1,
		"tant que le feu est vif, elle regarde le camp et n'y va pas (la veilleuse le retient) ; quand il baisse, sa lumière se retire : le hamac qu'elle gardait est mis en pièces")
	# (la veilleuse sort de la lumière pendant qu'elle flaire : elle vaut mieux qu'une toile)
	A.poses.erase(hamac)
	hamac.queue_free()
	feu.bois = 60.0
	var mangeoire = A._creer("mangeoire", feu.position + Vector2(0.0, -230.0), {"foin": 8})
	_faim_nuit()
	var au_flair4: bool = _faim_au_flair()
	j.position = feu.position + Vector2(0.0, 420.0)
	var d4 := {"presage": -1.0, "charge": -1.0}
	_faim_joue(RR.NOIRE_TORCHE[RR.NOIRE_FAIM] + RR.NOIRE_PRESAGE + 1.0, func(t):
		if d4["presage"] < 0.0 and N.corps != null and N.corps.aplatie > 0.5:
			d4["presage"] = t
		if d4["charge"] < 0.0 and N.etat == "charge":
			d4["charge"] = t)
	verif(au_flair4 and d4["presage"] >= 0.0 and d4["presage"] < 0.5 and absf(d4["charge"] - d4["presage"] - RR.NOIRE_PRESAGE) < 0.3 and not F.est_epave(mangeoire)
		and int(mangeoire.etat.get("foin", 0)) == 8,
		"la veilleuse sort de la lumière pendant qu'elle flaire la mangeoire : elle la laisse et se tourne vers elle (le présage, puis la charge %.1f s après) ; la mangeoire est intacte" % (d4["charge"] - d4["presage"]))
	j.position = feu.position + Vector2(-30.0, 0.0)
	j.sante = 100.0
	j.peur = 0.0
	_faim_joue(6.0)

	# --- jamais un collet (l'autre moitié de la suite de la Noire le pose : ici, seulement ce que la faim en sait) ---
	var collet = A._creer("collet", feu.position + Vector2(-260.0, 200.0), {})
	F.mettre_en_pieces(collet, 1.0, false)
	verif(not F.CHOSES.has("collet") and not F.saccageable(collet) and not F.est_epave(collet) and not F.saccageable(null) and F.saccageable(mangeoire),
		"elle ne saccage jamais un collet : il n'est pas de ce qu'elle met en pièces, et rien ne peut en faire une épave")
	A.poses.erase(collet)
	collet.queue_free()

	# --- les épaves : elles restent là, ne servent plus à rien ; on les répare sur place, ou on les replie ---
	A.poses.erase(mangeoire)
	mangeoire.queue_free()
	N._disparaitre()
	N.etat = "dort"
	N.silence = 0.0
	var p_ep: Vector2 = ici + Vector2(500.0, -300.0)
	var choses := {}
	var k_ep := 0
	for g in F.CHOSES:
		var etat0 := {}
		match g:
			"recuperateur":
				etat0 = {"eau": 4.0}
			"filet", "filet_filin":
				etat0 = {"prise": {"id": "", "nom": "une bête", "masse": 2.0}}
			"mangeoire":
				etat0 = {"foin": 9}
			"carre":
				etat0 = {"culture": "baie", "stade": 2.4, "eau": 0.6}
		choses[g] = A._creer(g, p_ep + Vector2(140.0 * (k_ep % 4), 120.0 * (k_ep / 4)), etat0)
		k_ep += 1
	# (son dessin : celui de la chose, puis celui de l'épave ; chaque épave a le sien)
	var points := func(x, quoi: String) -> int:
		var pin = Camp.pinceau()
		pin.commencer(x.get_canvas_item())
		if Epave.est(x):
			Epave.peindre(x, pin, quoi)
		var n_pts: int = pin.pts.size()
		pin.vider()
		return n_pts
	var sans_dessin := []
	var avant_ep: bool = true
	for g in choses:
		avant_ep = avant_ep and points.call(choses[g], "fond") == 0 and not Epave.est(choses[g])
		F.mettre_en_pieces(choses[g], 1.0 if k_ep % 2 == 0 else -1.0, false)
		k_ep += 1
		if points.call(choses[g], "fond") < 120:
			sans_dessin.append(g)
	var perdus: bool = float(choses["recuperateur"].etat.get("eau", 0.0)) == 0.0 and not choses["filet"].etat.has("prise") and int(choses["mangeoire"].etat.get("foin", 0)) == 0 \
		and str(choses["carre"].etat.get("culture", "")) == ""
	verif(avant_ep and sans_dessin.is_empty() and perdus and choses.values().all(func(x): return F.est_epave(x) and Epave.est(x) and Epave.remue(x) == (float(x._vent) > 0.03 and str(x.genre) in ["tente", "recuperateur", "epouvantail", "hamac"])),
		"ce qu'elle a saccagé reste là, en épave : les %d choses ont chacune leur dessin d'épave%s ; ce qu'elles tenaient est perdu (l'eau, la prise, le foin, ce qui poussait)" % [
		choses.size(), "" if sans_dessin.is_empty() else " (sauf : %s)" % ", ".join(PackedStringArray(sans_dessin))])
	# (elles ne servent plus : ni abri, ni sommeil, ni eau, ni prise, ni garde)
	var t_ep = choses["tente"]
	j.position = t_ep.position + Vector2(-40.0, 14.0)
	for k in ["bache", "corde", "bois", "fibre", "pierre", "filin"]:
		inv[k] = 0
	var agi: bool = A.agir()
	var dit_manque: String = dits.call()
	var sans_abri: bool = A.abri(t_ep.position) == 0.0 and not A.endormie and F.est_epave(t_ep)
	jeu.climat.pluie = 1.0
	var proie_f = _bete(jeu.faune["proies_jour"][0], "proie", choses["filet"].position + Vector2(4.0, 2.0), {})
	proie_f.masse = 2.0
	A.maj(5.0)
	jeu.climat.pluie = 0.0
	var inertes: bool = float(choses["recuperateur"].etat.get("eau", 0.0)) == 0.0 and not choses["filet"].etat.has("prise") and proie_f.is_in_group("betes") \
		and not J.garde(choses["epouvantail"].position)
	_oter(proie_f)
	verif(agi and sans_abri and inertes and dit_manque.contains("Pour réparer ta tente") and dit_manque.contains("Il te manque"),
		"une épave ne sert plus : la tente n'abrite pas et l'on n'y dort pas, le récupérateur ne se remplit pas sous la pluie, rien ne se prend au filet, l'épouvantail ne garde rien ; « Agir » dit ce qu'il faut pour la réparer")
	# (réparer : la moitié de chaque matière, arrondie au-dessus ; replier : la moitié, arrondie en dessous)
	var justes := true
	var pire := ""
	for g in F.CHOSES:
		if g == "carre":
			continue
		var cout: Dictionary = A.OBJETS[g]["cout"]
		var rep: Dictionary = A.cout_reparation(g)
		var res: Dictionary = A.restes(g)
		var somme := 0
		var somme_rep := 0
		for m in cout:
			somme += int(cout[m])
			somme_rep += int(rep.get(m, 0))
			if int(rep.get(m, 0)) + int(res.get(m, 0)) != int(cout[m]) or int(rep.get(m, 0)) < int(res.get(m, 0)):
				justes = false
				pire = g
		if somme_rep >= somme or somme_rep * 2 < somme:
			justes = false
			pire = g
	var cout_t: Dictionary = A.cout_reparation("tente")
	for m in cout_t:
		inv[m] = int(cout_t[m]) + 1
	var repare: bool = A.agir()
	var paye: bool = cout_t.keys().all(func(m): return int(inv[m]) == 1)
	var debout: bool = not F.est_epave(t_ep) and A.abri(t_ep.position) == 1.0 and not t_ep.etat.has("cote") and points.call(t_ep, "fond") == 0
	var dit_repare: String = dits.call()
	A.agir()
	var dort_dedans: bool = A.endormie and A.lit == t_ep
	A.reveiller("")
	verif(justes and repare and paye and debout and dort_dedans and dit_repare.contains("Tu répares ta tente") and cout_t == {"bache": 1, "corde": 1, "bois": 2},
		"« Agir » la répare sur place pour la moitié de son prix (la tente : %s ; chaque matière arrondie au-dessus, toujours moins que la chose neuve%s) : elle est debout, on y dort de nouveau" % [
		A.dire_cout(cout_t), "" if pire == "" else " — sauf %s" % pire])
	var e_ep = choses["epouvantail"]
	j.position = e_ep.position + Vector2(-20.0, 10.0)
	for k in ["bache", "corde", "bois", "fibre", "pierre", "filin"]:
		inv[k] = 0
	var avait: int = A.possede("epouvantail")
	var replie: bool = A.replier()
	var dit_replie: String = dits.call()
	verif(replie and not A.poses.has(e_ep) and A.possede("epouvantail") == avait and int(inv["bois"]) == 1 and int(inv["fibre"]) == 2 and int(inv["bache"]) == 0
		and dit_replie.contains("Tu replies ce qui reste de ton épouvantail"),
		"repliée, une épave ne revient pas dans le sac : on en sauve la moitié des matières, arrondie en dessous (l'épouvantail : 1 bois et 2 fibres sur 3 bois, 4 fibres et 1 bâche)")
	# (le carré piétiné : on le retourne, puis on le sème de nouveau)
	var c_ep = choses["carre"]
	j.position = c_ep.position + Vector2(-30.0, 10.0)
	inv["graine_baie"] = 4
	var seme_trop_tot: bool = J.semer(c_ep, "baie")
	J.agir(c_ep)
	var retourne: bool = not F.est_epave(c_ep)
	J.agir(c_ep)
	verif(not seme_trop_tot and retourne and str(c_ep.etat.get("culture", "")) == "baie" and int(inv["graine_baie"]) == 2,
		"un carré piétiné ne se sème pas ; « Agir » en retourne la terre, sans rien coûter, puis il se sème de nouveau")

	# --- les bêtes attachées : dans le noir, elle vient les prendre elle-même, même à la longe de filin ---
	for g in choses:
		if is_instance_valid(choses[g]) and A.poses.has(choses[g]):
			A.poses.erase(choses[g])
			choses[g].queue_free()
	var e_bete: Dictionary = {}
	for e in jeu.faune["proies_jour"] + jeu.faune["proies_nuit"]:
		var b0 = _bete(e, "proie", ici + Vector2(0.0, 900.0), {})
		var bonne: bool = E.apprivoisable(b0)
		_oter(b0)
		if bonne:
			e_bete = e
			break
	if e_bete.is_empty():
		verif(false, "la forêt a une proie à quatre pattes à apprivoiser")
	else:
		# (leurs traits fixés : la bête moyenne de sa population, qui s'est faite au feu ; nourrie, à sa longe de filin)
		var attacher := func(piquet):
			var b = _bete(e_bete, "proie", piquet.position + Vector2(18.0, 10.0), {"neophobie": 0.05})
			A.objets["licol"] = 1
			E.apprivoiser(b)
			b.suit_la = false
			b.maison = piquet.position + Vector2(18.0, 10.0)
			b.faim = 95.0
			b.harnais["longe"] = true
			return b
		j.position = feu.position + Vector2(-30.0, 0.0)
		var piquet_noir = A._creer("piquet", feu.position + Vector2(-40.0, -290.0), {})
		var piquet_feu = A._creer("piquet", feu.position + Vector2(70.0, 60.0), {})
		var tente_noire = A._creer("tente", feu.position + Vector2(-330.0, 120.0), {})
		var au_noir = attacher.call(piquet_noir)
		var au_feu = attacher.call(piquet_feu)
		j.position = feu.position + Vector2(-30.0, 0.0)
		# (avant la faim, à l'acte 4 : la règle d'avant. Elle ne vient pas ; la bête laissée dans le noir crie, et il n'en reste rien)
		_faim_nuit(4)
		var vient4: bool = F.vient_prendre(au_noir)
		var temoin = attacher.call(piquet_noir)
		var t4 := {"prise": -1.0, "flaire": false}
		_faim_joue(30.0, func(t):
			t4["flaire"] = t4["flaire"] or N.etat == "hume"
			if t4["prise"] < 0.0 and not E.betes.has(temoin):
				t4["prise"] = t)
		var avant_la_faim: bool = not vient4 and not t4["flaire"] and t4["prise"] > 0.0 and not piquet_noir.etat.has("rompue") and E.betes.has(au_feu)
		# (la faim : elle va sur elle, gronde, et le filin cède sous sa gueule ; elle la mange là)
		if not E.betes.has(au_noir):
			au_noir = attacher.call(piquet_noir)
		N.su.erase("longe")
		jeu.sons.journal = []
		_faim_nuit()
		var b5 := {"lisiere": -1.0, "part": -1.0, "sur": -1.0, "prise": -1.0, "fini": -1.0, "cible": null, "debat": false, "tete": 0.0, "dit": "", "dit_sur": "", "pres_feu": INF}
		_faim_joue(60.0, func(t):
			if N.corps == null:
				return
			b5["pres_feu"] = minf(b5["pres_feu"], N.corps.position.distance_to(feu.position) / r)
			if b5["lisiere"] < 0.0 and N.etat == "guette":
				b5["lisiere"] = t
			if b5["part"] < 0.0 and N.etat == "hume":
				b5["part"] = t
				b5["cible"] = F.cible
			if N.etat == "hume" and F._sur_place:
				if b5["sur"] < 0.0:
					b5["sur"] = t
					b5["dit_sur"] = dits.call()
				if is_instance_valid(au_noir):
					b5["debat"] = b5["debat"] or str(au_noir.etat) == "fuit"
			if b5["prise"] < 0.0 and N.etat == "devore":
				b5["prise"] = t
				b5["dit"] = dits.call()
			if N.etat == "devore":
				b5["tete"] = maxf(b5["tete"], N.corps._tete_rot)
			if b5["prise"] >= 0.0 and b5["fini"] < 0.0 and N.etat != "devore":
				b5["fini"] = t)
		var entendus_b: Array = jeu.sons.journal.map(func(x): return str(x[1]).rstrip("0123456789"))
		verif(avant_la_faim, "avant la faim (acte 4), rien ne change : elle ne vient pas elle-même, la bête laissée dans le noir crie une fois (%.1f s), et il n'en reste rien" % t4["prise"])
		verif(b5["cible"] == au_noir and b5["part"] - b5["lisiere"] >= RR.NOIRE_FAIM_BETE - 0.6 and b5["part"] - b5["lisiere"] < RR.NOIRE_FAIM_ATTENTE - 2.0
			and absf(b5["prise"] - b5["sur"] - RR.NOIRE_FLAIRE) < 0.3 and b5["debat"] and str(b5["dit_sur"]).contains("dans le noir. Elle gronde"),
			"la faim : la bête attachée dans le noir passe avant la tente (au bout de %d secondes) ; elle va sur elle et gronde %.1f s, la bête se débat au bout de sa longe" % [
			int(b5["part"] - b5["lisiere"]), b5["prise"] - b5["sur"]])
		verif(not E.betes.has(au_noir) and (not is_instance_valid(au_noir) or au_noir.is_queued_for_deletion()) and float(piquet_noir.etat.get("rompue", 0.0)) == 2.0
			and str(b5["dit"]).contains("Le filin casse net sous sa gueule") and N.su.has("longe") and entendus_b.has("cede") and entendus_b.has("cri")
			and absf(b5["fini"] - b5["prise"] - RR.NOIRE_DEVORE) < 0.3 and b5["tete"] > 0.3 and F.betes == 1,
			"même le filin cède sous sa gueule : elle prend la bête (un cri), la mange sur place %d secondes, la tête basse ; au piquet, il reste un bout de longe rompue ; la veilleuse le retient" % int(b5["fini"] - b5["prise"]))
		verif(E.betes.has(au_feu) and is_instance_valid(au_feu) and float(au_feu.pv) > 0.0 and not piquet_feu.etat.has("rompue") and b5["pres_feu"] >= 0.97 and j.sante == 100.0,
			"dans la lumière du feu, l'autre bête est à l'abri : elle y est toujours, à son piquet")
		# (une bête de nouveau liée au piquet : le bout de longe n'y est plus)
		var revenue = attacher.call(piquet_noir)
		feu.bois = 150.0
		E.maj(0.1)
		var renoue: bool = not piquet_noir.etat.has("rompue") and bool(piquet_noir.etat.get("attache", false))
		feu.bois = 60.0
		# --- la partie gardée : les épaves, le bout de longe, les comptes de la nuit ---
		piquet_noir.etat["rompue"] = 2.0
		F.mettre_en_pieces(tente_noire, -1.0, false)
		F.prises = 1
		F.soir = true
		var photo_a: Dictionary = JSON.parse_string(JSON.stringify(A.photo()))
		var photo_n: Dictionary = JSON.parse_string(JSON.stringify(N.photo()))
		var A2 = jeu.Atelier.new()
		A2.jeu = jeu
		A2.reprendre(photo_a)
		var N2 = jeu.Noire.new()
		N2.jeu = jeu
		N2.commencer()
		N2.reprendre(photo_n)
		var tentes2: Array = A2.poses.filter(func(x): return str(x.genre) == "tente")
		var piquets2: Array = A2.poses.filter(func(x): return str(x.genre) == "piquet" and float(x.etat.get("rompue", 0.0)) == 2.0)
		# (ses empreintes ne se gardent pas : la partie reprise les remet autour des épaves de cette nuit)
		T.vider()
		N2.faim.veiller(true)
		var retracees: bool = T.pres(tente_noire.position, 260.0, 2)
		verif(renoue and tentes2.size() == 1 and F.est_epave(tentes2[0]) and float(tentes2[0].etat.get("cote", 0.0)) == -1.0 and piquets2.size() == 1
			and N2.acte == N.acte and N2.faim.prises == 1 and N2.faim.betes == F.betes and N2.faim.soir and retracees,
			"la partie gardée s'en souvient : la tente en épave (et de quel côté elle tirait), le bout de longe au piquet, ce qu'elle a déjà pris cette nuit ; reprise, ses empreintes sont de nouveau autour de l'épave")
		for x in A2.poses:
			x.queue_free()
		F.soir = false
		for b in [au_feu, revenue]:
			if is_instance_valid(b):
				E.betes.erase(b)
				_oter(b)

	# --- le carnet, les sons ---
	var cles: Array = N.SAVOIRS.map(func(x): return str(x[0]))
	var de_la_faim := ["crepuscule", "faim", "garde", "longe", "assez"]
	for k in de_la_faim:
		N.su[k] = true
	var SA = load("res://scripts/sons_atelier.gd")
	var rs := RandomNumberGenerator.new()
	rs.seed = 11
	var durees := {}
	for nom in ["dechire0", "dechire1", "brise0", "brise1", "cede"]:
		var a: Array = SA.fabriquer(nom, rs)
		durees[nom] = float(a[0].size()) / float(a[1]) if a.size() == 2 else 0.0
	verif(de_la_faim.all(func(k): return cles.has(k)) and N.savoirs().size() == N.su.size() and N.SAVOIRS.size() >= 10 + de_la_faim.size()
		and durees.values().all(func(d): return d > 0.5 and d < 1.2) and SA.NOMS.has("dechire0") and SA.NOMS.has("brise1") and SA.NOMS.has("cede"),
		"le carnet garde ce qu'on apprend d'elle à cet acte (le crépuscule, la faim, ce que la lumière garde, la longe, « assez » : %d choses en tout) ; ses sons sont faits à la main (la toile qui se déchire, %.2f s ; le bois qui casse, %.2f s ; la corde qui cède, %.2f s)" % [
		N.SAVOIRS.size(), durees["dechire0"], durees["brise0"], durees["cede"]])

	# (tout remis)
	jeu.sons.journal = journal_avant
	T.vider()
	N.commencer()
	for x in A.poses.duplicate():
		if is_instance_valid(x):
			x.queue_free()
	A.commencer()
	jeu.feux.erase(feu)
	feu.queue_free()
	j.sante = 100.0
	j.peur = 0.0


# la Noire, la fin : le collet de filin, l'appât, les cicatrices, son départ (scripts/noire_collet.gd, scripts/atelier.gd).
# La scène est jouée de bout en bout, sans attendre (noire.maj, puis son corps, comme _noire_joue) : le collet fabriqué, tendu
# de jour, amorcé ; la nuit, elle le flaire ; la prise, les élans au bout du filin, les coups, la cicatrice ; trois fois ;
# l'aube, la piste qui sort, la couche vide, la page ; la partie gardée et reprise. Rien n'y dépend du tirage du lieu : la
# place est dégagée (arbres, buissons, choses posées, bêtes), le temps clair, le hasard fixé.
func _le_collet_de_la_noire() -> void:
	print("14. La Noire : le collet et la fin")
	await jeu._commencer("foret")
	seed(20261118)
	var j = jeu.joueur
	var N = jeu.noire
	var A = jeu.atelier
	var B = jeu.botanique
	var RR = jeu.R
	var W = jeu.monde
	var T = jeu.traces
	var inv: Dictionary = j.inventaire
	var Best = load("res://scripts/bestiaire.gd")
	var Ic = load("res://scripts/atelier_icones.gd")
	var SA = load("res://scripts/sons_atelier.gd")
	var Dessin = load("res://scripts/collet_dessin.gd")
	jeu.climat.forcer("clair", 0.0, 99999.0)
	jeu.graine = 4242
	N.commencer()
	var C = N.collet
	# le camp, et la place du collet : 420 pixels à gauche du feu, hors de sa lumière ; tout dégagé autour
	var camp := Vector2(260.0, 120.0)
	_remettre(camp)
	j.torche = 0.0
	for o in W.autour(camp + Vector2(-300.0, 0.0), 1250.0):
		if float(o.rayon) > 0.0 or str(o.genre) in ["buisson", "touffe", "brindille", "fleur", "cepe", "amanite", "herbe", "aquatique"]:
			W.retirer(o)
	for x in A.poses.duplicate():
		if is_instance_valid(x) and x.position.distance_to(camp) < 1500.0:
			A.poses.erase(x)
			x.queue_free()
	var feu = jeu.Feu.new()
	feu.jeu = jeu
	feu.position = camp + Vector2(30.0, 0.0)
	feu.bois = 40.0
	W.add_child(feu)
	jeu.feux.append(feu)
	var r: float = feu.rayon()
	var place: Vector2 = feu.position + Vector2(-420.0, 0.0)
	var pieu: Vector2 = place + C.PIEU
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	var nuit_h: float = base + RR.DUREE * (1.0 - jeu.part_nuit) + 20.0
	var jour_h: float = base + RR.DUREE * 0.3
	var duree_nuit: float = RR.DUREE * jeu.part_nuit
	N.taniere = camp + Vector2(-1500.0, -900.0)
	N.ou = N.taniere
	jeu.sons.journal = []
	var entendu := func(nom: String) -> int:
		return jeu.sons.journal.filter(func(x): return str(x[1]).rstrip("0123456789") == nom).size()
	var collet_pose := func():
		for x in A.poses:
			if is_instance_valid(x) and str(x.genre) == "collet":
				return x
		return null

	# --- la recette, la pose de jour, l'appât ---
	jeu.horloge = jour_h
	var cout: Dictionary = A.OBJETS["collet"]["cout"]
	var etabli = A._creer("etabli", camp + Vector2(70.0, 40.0), {})
	j.position = etabli.position + Vector2(-34.0, 8.0)
	for k in cout:
		inv[k] = 0
	var sans_rien: bool = not A.peut("collet")
	for k in cout:
		inv[k] = int(cout[k])
	var fait: bool = A.fabriquer("collet")
	var paye := true
	for k in cout:
		paye = paye and int(inv[k]) == 0
	verif(A.ORDRE.has("collet") and int(cout.get("filin", 0)) >= 3 and int(cout.get("bois", 0)) >= 2 and int(cout.get("pierre", 0)) >= 2 and bool(A.OBJETS["collet"].get("pose", false))
		and sans_rien and fait and paye and A.possede("collet") == 1 and Ic.connue("collet"),
		"le grand collet se fabrique à l'établi : %d filins, %d bois, %d pierres (rien sans eux) ; il a son icône, et se pose" % [int(cout["filin"]), int(cout["bois"]), int(cout["pierre"])])
	# (de nuit, il ne se tend pas)
	j.position = place + Vector2(46.0, -6.0)
	j.regard = -1.0
	jeu.horloge = nuit_h
	var de_nuit: String = A.empeche_poser("collet")
	jeu.horloge = jour_h
	B.parfum = 0.0
	var pose_ok: bool = A.poser("collet")
	var s = collet_pose.call()
	verif(de_nuit != "" and pose_ok and s != null and s.position.distance_to(place) < 2.0 and A.possede("collet") == 0 and bool(s.etat.get("odeur", false)) and not bool(s.etat.get("amorce", true))
		and A.Campement.rayon("collet") == 0.0 and not C._eclaire(s),
		"il se tend de jour (la nuit : « %s »), devant elle, à %d pixels du feu, hors de sa lumière ; posé à mains nues, il garde l'odeur de sa main" % [de_nuit, int(s.position.distance_to(feu.position)) if s != null else -1])
	# (l'appât : de la viande crue, « Agir » auprès de lui ; la viande cuite n'y fait rien)
	inv["viande"] = 0
	inv["viande_cuite"] = 1
	jeu.agir()
	var cuite_refusee: bool = not bool(s.etat.get("amorce", false)) and int(inv["viande_cuite"]) == 1
	inv["viande"] = 2
	jeu.agir()
	verif(cuite_refusee and bool(s.etat.get("amorce", false)) and int(inv["viande"]) == 1 and Dessin.cle(s).contains("true"),
		"« Agir » auprès du collet, avec de la viande crue, l'amorce (la viande cuite n'y fait rien) ; son dessin le montre")

	# --- la nuit : il sent sa main. Elle vient, le flaire, renâcle et s'en détourne ---
	j.position = camp
	jeu.horloge = nuit_h
	jeu.nuits = N.premiere_nuit(2)
	N.mettre_en_scene(2, 900.0, PI)
	var o1 := {"appat": false, "flaire": false, "nez": INF, "attire": false, "tete": 0.0, "prise": false, "pres_feu": INF}
	_noire_joue(48.0, func(_t):
		o1["appat"] = o1["appat"] or N.etat == "appat"
		o1["prise"] = o1["prise"] or N.etat == "prise"
		o1["attire"] = o1["attire"] or (N.etat in ["appat", "flaire"] and N.appat_l_attire())
		if N.corps == null:
			return
		o1["pres_feu"] = minf(o1["pres_feu"], N.corps.position.distance_to(feu.position) / r)
		if N.etat == "flaire":
			o1["flaire"] = true
			o1["nez"] = minf(o1["nez"], absf(N.corps.position.distance_to(s.position) - C.NEZ * RR.NOIRE_LARGEUR))
			o1["tete"] = maxf(o1["tete"], N.corps.flaire))
	verif(o1["appat"] and o1["attire"] and o1["flaire"] and o1["nez"] < 12.0 and o1["tete"] > 0.9 and not o1["prise"] and N.su.has("odeur") and entendu.call("noire_renacle") == 1
		and entendu.call("noire_flaire") >= 2 and int(s.etat.get("evente", -1)) == int(jeu.nuits) and str(s.etat.get("phase", "")) == "" and bool(s.etat.get("amorce", false))
		and N.etat in ["tourne", "guette"] and not N.appat_l_attire() and j.sante == 100.0 and o1["pres_feu"] >= 0.97,
		"la nuit, l'appât l'attire : elle y vient la tête basse et le flaire, le nez dessus ; il sent la main : elle renâcle et s'en détourne, sans y toucher (le jeu le dit, le carnet le garde), et reprend sa ronde")
	_noire_joue(20.0)
	verif(not N.appat_l_attire() and C.vise == null and str(s.etat.get("phase", "")) == "", "éventé, ce collet ne l'attire plus de la nuit ; il reste tendu, amorcé, pour une autre")
	N.aube()
	N._disparaitre()
	N.etat = "dort"
	# (la pluie lave l'odeur d'une main : une demi-minute d'averse)
	jeu.climat.pluie = 1.0
	for i in int(RR.NOIRE_COLLET_PLUIE) - 2:
		C._laver(1.0)
	var encore: bool = bool(s.etat.get("odeur", false))
	for i in 4:
		C._laver(1.0)
	var lave: bool = not bool(s.etat.get("odeur", true))
	jeu.climat.pluie = 0.0
	s.etat["odeur"] = true
	# (replié : il revient dans son sac, avec sa viande ; retendu avec l'odeur des aromates sur elle, il ne sent rien)
	jeu.horloge = jour_h
	j.position = place + Vector2(46.0, -6.0)
	j.regard = -1.0
	var viande_avant := int(inv["viande"])
	var replie: bool = A.replier()
	var rendu: bool = A.possede("collet") == 1 and int(inv["viande"]) == viande_avant + 1 and collet_pose.call() == null
	# (l'odeur : des aromates au feu, elle se tient dans leur fumée)
	inv["aromates"] = RR.AROMATES_FEU
	j.position = feu.position + Vector2(-30.0, 10.0)
	var fume: bool = B.fumiger()
	B.maj(1.0)
	B.maj(1.0)
	var parfumee: bool = B.impregnee()
	j.position = place + Vector2(46.0, -6.0)
	j.regard = -1.0
	A.poser("collet")
	s = collet_pose.call()
	jeu.agir()
	# (le sac : le collet posé juste là, ce qu'on en sait, « Replier »)
	jeu.ouvrir_page("sac")
	var sac_c = jeu.ui._pages.get("sac")
	var tuile_c := false
	if sac_c != null:
		for sec in sac_c._sections():
			for tu in sec["tuiles"]:
				tuile_c = tuile_c or (str(tu["cle"]) == "pose" and str(tu["id"]) == "collet")
	var fiche_c: Dictionary = sac_c._fiche_de("pose") if sac_c != null else {}
	jeu.fermer_page()
	var note_c := ""
	for l in fiche_c.get("lignes", []):
		note_c += str(l[1]) if l.size() > 1 else ""
	verif(encore and lave and replie and rendu and fume and parfumee and s != null and bool(s.etat.get("amorce", false)) and not bool(s.etat.get("odeur", true))
		and tuile_c and str(fiche_c.get("bouton", "")) == "Replier" and note_c.contains("Amorcé") and note_c.contains("ne sent rien"),
		"une averse de %d secondes lave l'odeur ; replié, le collet revient dans le sac avec sa viande ; retendu et amorcé avec l'odeur des aromates sur elle, il ne sent rien (le sac le dit : « %s »)" % [int(RR.NOIRE_COLLET_PLUIE), note_c])

	# --- la prise : elle y met la patte, le nœud se serre ; tenue, elle se jette au bout du filin ---
	# (les nombres, par le calcul : la bande où la lance porte et où sa gueule ne porte pas)
	var lance_porte: float = RR.PORTEE_COUP + 0.3 * RR.NOIRE_LARGEUR
	var bande: float = lance_porte - RR.NOIRE_COLLET_MORD
	var coups_lance := int(ceil(RR.NOIRE_COLLET_BLESSE / RR.DEGATS_LANCE))
	var elan_s: float = RR.NOIRE_COLLET_ELAN + RR.NOIRE_COLLET_SONNEE + 0.75 * RR.NOIRE_COLLET_LONGE / RR.NOIRE_VITESSE
	verif(bande >= 40.0 and coups_lance >= 2 and coups_lance <= 3 and (coups_lance - 1) * RR.CADENCE < RR.NOIRE_COLLET_SONNEE and RR.NOIRE_COLLET_TENUE / elan_s >= 5.0
		and RR.NOIRE_MORSURE * 2.0 < 100.0 and RR.NOIRE_COLLET_MORD < 100.0,
		"par le calcul : tenue, sa gueule porte à %d pixels et la lance à %d (une bande de %d) ; %d coups de lance font une cicatrice, ils tiennent dans la seconde où elle est sonnée (%.2f s pour %.1f) ; %d élans en %d secondes" % [
		int(RR.NOIRE_COLLET_MORD), int(lance_porte), int(bande), coups_lance, (coups_lance - 1) * RR.CADENCE, RR.NOIRE_COLLET_SONNEE, int(RR.NOIRE_COLLET_TENUE / elan_s), int(RR.NOIRE_COLLET_TENUE)])
	# la nuit d'une prise : la veilleuse attend au feu ; le nœud serré, elle sort se battre (ou non)
	var une_nuit := func(k: int, acte: int, frappe: bool, dedans: bool) -> Dictionary:
		var m := {"prise": -1.0, "patte": INF, "loin_du_pieu": 0.0, "morsures": 0, "coups": 0, "a_coups": 0, "liberee": -1.0, "furie": -1.0, "charge": -1.0, "presage": false,
			"cicatrice": false, "pres_feu": INF, "ramasse": false, "attire": false, "serre": false, "vers_elle": 0,
			"part": false, "part_de": Vector2.ZERO, "part_cap": 1.0, "loin_taniere": INF}
		j.position = camp
		j.sante = 100.0
		j.lance = RR.USURE_LANCE
		jeu.horloge = nuit_h
		jeu.nuits = N.premiere_nuit(2) + k
		jeu.sons.journal = []
		N.mettre_en_scene(acte, 900.0, PI)
		var cic0: int = N.cicatrices
		var sante := [100.0]
		var cadence := [0.0]
		var a_coups0 := [0]
		_noire_joue(34.0 + RR.NOIRE_COLLET_TENUE + 12.0, func(t):
			if N.corps == null:
				return
			var c = N.corps
			m["pres_feu"] = minf(m["pres_feu"], c.position.distance_to(feu.position) / r)
			if N.etat == "prise":
				if m["prise"] < 0.0:
					m["prise"] = t
					m["patte"] = Vector2(C.prise_a).length()
					m["serre"] = str(s.etat.get("phase", "")) == "serre" and not bool(s.etat.get("amorce", true))
					# (elle sort de la lumière : au bout de la portée de la bête, du côté du camp ; ou dedans, pour voir)
					j.position = pieu + Vector2(RR.NOIRE_COLLET_LONGE + (RR.NOIRE_COLLET_MORD - 25.0 if dedans else RR.NOIRE_COLLET_MORD + 0.45 * bande), 0.0)
				m["attire"] = m["attire"] or N.appat_l_attire()
				m["loin_du_pieu"] = maxf(m["loin_du_pieu"], c.position.distance_to(pieu))
				m["ramasse"] = m["ramasse"] or (C._phase == "ramasse" and c.aplatie > 0.5)
				if C._phase == "jette":
					if C._dir.dot((j.position - pieu).normalized()) > 0.9:
						m["vers_elle"] += 1
				cadence[0] -= 0.05
				if frappe and cadence[0] <= 0.0 and c.position.distance_to(j.position) - c.largeur * 0.3 < RR.PORTEE_COUP and N.etat == "prise":
					cadence[0] = RR.CADENCE
					jeu.agir()
					m["coups"] += 1
			elif m["prise"] >= 0.0:
				if m["liberee"] < 0.0:
					m["liberee"] = t
					m["cicatrice"] = N.cicatrices == cic0 + 1
				if N.etat == "furie" and m["furie"] < 0.0:
					m["furie"] = t
				if N.etat == "furie":
					m["presage"] = m["presage"] or c.aplatie > 0.5
				if N.etat == "charge" and m["charge"] < 0.0:
					m["charge"] = t
					# (elle court vers son feu)
					j.position = camp
				if N.etat == "part":
					# (elle quitte le lieu : par où, et à quelle distance de sa tanière elle passe)
					if not m["part"]:
						m["part"] = true
						m["part_de"] = c.position
					m["loin_taniere"] = minf(m["loin_taniere"], c.position.distance_to(N.taniere))
					if c.position.distance_to(m["part_de"]) > 200.0:
						m["part_cap"] = (c.position - Vector2(m["part_de"])).normalized().dot((N.taniere - Vector2(m["part_de"])).normalized())
			if j.sante < sante[0] - 1.0:
				m["morsures"] += 1
				sante[0] = j.sante
				if dedans and m["morsures"] >= 2:
					# (deux morsures : elle en réchapperait à peine d'une troisième ; elle sort de sa portée)
					j.position = camp
			m["a_coups"] = entendu.call("collet_coup"))
		return m
	# deuxième nuit : elle s'y prend. La veilleuse se tient au bout de sa portée, sans frapper : pas une morsure ; le temps
	# passé, les pieux cèdent ; furieuse, elle s'aplatit (le présage), puis charge ; un feu vif la tient encore
	var n1: Dictionary = une_nuit.call(1, 2, false, false)
	var s1 = s
	verif(n1["prise"] > 0.0 and n1["patte"] < 28.0 and n1["serre"] and n1["attire"] and N.su.has("collet") and entendu.call("collet_claque") == 1 and entendu.call("noire_cri") >= 1 and n1["pres_feu"] >= 0.97,
		"le collet ne sent rien : elle le flaire, y pose la patte (à %d pixels du milieu du nœud, large de 50), le nœud claque et se serre, elle crie ; le carnet le garde ; elle n'est pas entrée dans la lumière (%.2f rayon)" % [int(n1["patte"]), n1["pres_feu"]])
	verif(n1["loin_du_pieu"] <= RR.NOIRE_COLLET_LONGE + 0.5 and n1["a_coups"] >= 5 and n1["ramasse"] and n1["vers_elle"] >= 4 and n1["morsures"] == 0,
		"tenue, elle se ramasse puis se jette au bout du filin (%d à-coups, jamais plus loin que %d pixels du pieu : %.1f), sur la veilleuse qui se tient au bout de sa portée : pas une morsure en %d secondes" % [
		n1["a_coups"], int(RR.NOIRE_COLLET_LONGE), n1["loin_du_pieu"], int(RR.NOIRE_COLLET_TENUE)])
	verif(absf(n1["liberee"] - n1["prise"] - RR.NOIRE_COLLET_TENUE) < 0.2 and not n1["cicatrice"] and N.cicatrices == 0 and n1["furie"] >= 0.0 and n1["presage"]
		and absf(n1["charge"] - n1["furie"] - RR.NOIRE_PRESAGE) < 0.15 and str(s1.etat.get("phase", "")) == "rompu" and entendu.call("collet_arrache") == 1 and j.sante == 100.0 and not N.partie,
		"sans coups, le nœud la tient %d secondes ; puis les pieux cèdent : libre, furieuse, elle s'aplatit %.1f s (son présage) avant de charger ; le collet est perdu ; la veilleuse a regagné son feu, sans une morsure" % [
		int(n1["liberee"] - n1["prise"]), n1["charge"] - n1["furie"]])
	# (rompu, on en reprend les pieux et les pierres, pas le filin)
	N.aube()
	N._disparaitre()
	N.etat = "dort"
	jeu.horloge = jour_h
	j.position = s1.position + Vector2(30.0, 4.0)
	for k in cout:
		inv[k] = 0
	jeu.agir()
	verif(int(inv["bois"]) == int(C.CE_QU_IL_REND["bois"]) and int(inv["pierre"]) == int(C.CE_QU_IL_REND["pierre"]) and int(inv["filin"]) == 0 and collet_pose.call() == null and A.possede("collet") == 0,
		"du collet rompu, elle reprend ses pieux et ses pierres (%d bois, %d pierres) ; le nœud, la bête l'a emporté" % [int(inv["bois"]), int(inv["pierre"])])
	# un collet de plus, tendu au même endroit, l'odeur des aromates sur elle
	var retendre := func():
		jeu.horloge = jour_h
		for k in cout:
			inv[k] = int(cout[k])
		j.position = etabli.position + Vector2(-34.0, 8.0)
		A.fabriquer("collet")
		B.parfum = RR.PARFUM
		j.position = place + Vector2(46.0, -6.0)
		j.regard = -1.0
		A.poser("collet")
		inv["viande"] = 1
		jeu.agir()
		return collet_pose.call()
	# troisième nuit : dedans sa portée, elle mord
	s = retendre.call()
	var n2: Dictionary = une_nuit.call(2, 3, false, true)
	verif(n2["prise"] > 0.0 and n2["morsures"] == 2 and absf(100.0 - j.sante - RR.NOIRE_MORSURE * 2.0) < 0.01 and C.morsures_n == 2 and j.sante > 0.0,
		"qui entre dans sa portée est mordue, à chaque élan : deux morsures à %d pixels du bout de son filin (%d de santé chacune) ; sortie de sa portée, plus aucune" % [
		int(RR.NOIRE_COLLET_MORD - 25.0), int(RR.NOIRE_MORSURE)])
	N.aube()
	N._disparaitre()
	N.etat = "dort"
	for x in A.poses.duplicate():
		if is_instance_valid(x) and str(x.genre) == "collet":
			A.poses.erase(x)
			x.queue_free()
	var morsures_avant: int = C.morsures_n

	# --- les coups comptent : la première cicatrice ---
	var portrait0: Dictionary = Best.portrait(N.lignee_a(0), 300.0)
	s = retendre.call()
	var n3: Dictionary = une_nuit.call(3, 3, true, false)
	var lance_usee: int = RR.USURE_LANCE - int(j.lance)
	verif(n3["prise"] > 0.0 and n3["coups"] == coups_lance and lance_usee == coups_lance and n3["cicatrice"] and N.cicatrices == 1 and n3["morsures"] == 0 and N._retiree
		and str(s.etat.get("phase", "")) == "rompu" and N.su.has("cicatrice") and not N.partie and n3["liberee"] - n3["prise"] < RR.NOIRE_COLLET_TENUE,
		"tenue, les coups comptent : au %de coup de lance (en %.1f s, sans une morsure, du bout de sa portée), elle s'arrache et se retire ; elle en garde une cicatrice" % [n3["coups"], n3["liberee"] - n3["prise"]])
	_noire_joue(45.0)
	var rentree: bool = N.corps == null and N.etat == "dort" and T.pres(N.taniere, 300.0, 2)
	_noire_joue(20.0)
	verif(rentree and N.corps == null and C.emportes >= 2, "blessée, elle rentre à sa tanière (sa piste y mène) et ne revient pas de la nuit")
	N.aube()
	# ce que la cicatrice change : son dessin, sa charge
	var portrait1: Dictionary = Best.portrait(N.lignee_a(1), 300.0)
	var portrait2: Dictionary = Best.portrait(N.lignee_a(2), 300.0)
	var portrait3: Dictionary = Best.portrait(N.lignee_a(3), 300.0)
	var clair := func(po: Dictionary, q: Vector2) -> float:
		var img: Image = po["image"]
		var px := Vector2i(((q * 300.0 - Vector2(po["pos"])) * 2.0).round())
		var v := 0.0
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				v = maxf(v, img.get_pixel(clampi(px.x + dx, 0, img.get_width() - 1), clampi(px.y + dy, 0, img.get_height() - 1)).get_luminance())
		return v
	var epaule := Vector2(0.2, -0.462)
	var flanc := Vector2(-0.021, -0.412)
	var e0: float = clair.call(portrait0, epaule)
	var e1: float = clair.call(portrait1, epaule)
	var f1: float = clair.call(portrait1, flanc)
	var f2: float = clair.call(portrait2, flanc)
	verif(e1 > e0 + 0.25 and f2 > f1 + 0.25 and portrait0["image"].get_data() != portrait1["image"].get_data() and portrait2["image"].get_data() != portrait3["image"].get_data()
		and Vector2(portrait0["taille"]) == Vector2(portrait1["taille"]),
		"chaque cicatrice se voit sur son dessin : une balafre pâle à la naissance du cou à la première (%.2f de clair, pour %.2f), sur les côtes à la deuxième (%.2f pour %.2f), au chanfrein à la troisième ; son poil, lui, reste le même" % [e1, e0, f2, f1])
	jeu.horloge = nuit_h
	jeu.nuits += 1
	N.mettre_en_scene(3, 900.0, PI)
	for x in A.poses.duplicate():
		if is_instance_valid(x) and str(x.genre) == "collet":
			A.poses.erase(x)
			x.queue_free()
	_noire_joue(3.0)
	var v1: float = N.corps.vitesse if N.corps != null else 0.0
	verif(N.corps != null and absf(v1 - RR.NOIRE_VITESSE * (1.0 - RR.NOIRE_CICATRICE_FREIN)) < 0.01 and v1 > RR.VITESSE and N.corps._boite_i < 0,
		"une cicatrice ralentit sa charge : %d pixels par seconde au lieu de %d (la veilleuse court à %d) ; elle ne boite pas encore" % [int(v1), int(RR.NOIRE_VITESSE), int(RR.VITESSE)])
	N.aube()
	N._disparaitre()
	N.etat = "dort"

	# --- la deuxième : elle boite ---
	s = retendre.call()
	var n4: Dictionary = une_nuit.call(5, 4, true, false)
	_noire_joue(45.0)
	N.aube()
	jeu.horloge = nuit_h
	jeu.nuits += 1
	for x in A.poses.duplicate():
		if is_instance_valid(x) and str(x.genre) == "collet":
			A.poses.erase(x)
			x.queue_free()
	N.mettre_en_scene(4, 900.0, PI)
	_noire_joue(3.0)
	var v2: float = N.corps.vitesse if N.corps != null else 0.0
	verif(n4["cicatrice"] and N.cicatrices == 2 and not N.partie and N.corps != null and absf(v2 - RR.NOIRE_VITESSE * (1.0 - 2.0 * RR.NOIRE_CICATRICE_FREIN)) < 0.01 and v2 > RR.VITESSE
		and N.corps._boite_i >= 0 and N.corps._boite_i == N.corps._prise_i,
		"la deuxième : %d pixels par seconde, toujours plus que la veilleuse ; et elle boite de la patte prise" % int(v2))
	N.aube()
	N._disparaitre()
	N.etat = "dort"

	# --- la troisième : elle quitte le lieu ---
	s = retendre.call()
	var nuits_tenues := 9
	jeu.jour = nuits_tenues + 1
	var n5: Dictionary = une_nuit.call(7, 4, true, false)
	_noire_joue(20.0)
	verif(n5["cicatrice"] and N.cicatrices == 3 and N.partie and n5["part"] and n5["part_cap"] < 0.75 and n5["loin_taniere"] > 700.0 and N.corps == null and N.etat == "dort"
		and entendu.call("dernier_appel") == 1 and entendu.call("appel") == 0 and C.jour_du_depart == nuits_tenues + 1 and n5["morsures"] == 0,
		"à la troisième cicatrice, elle ne rentre pas : elle s'en va, pas vers sa tanière (jamais à moins de %d pixels d'elle), pousse un dernier appel, qui n'est pas le sien, et disparaît" % int(minf(n5["loin_taniere"], 99999.0)))
	# l'aube : sa piste part du collet et sort du lieu ; sa couche est vide ; le carnet écrit sa dernière page
	jeu.horloge = jour_h + RR.DUREE
	jeu.jour = nuits_tenues + 2
	jeu.nuits = nuits_tenues
	N.aube()
	var hors := 0
	var pres_taniere := false
	var au_collet := false
	for e in T._liste:
		if int(e[6]) != 2:
			continue
		var q := Vector2(e[0], e[1])
		if absf(q.x) > RR.DEMI or absf(q.y) > RR.DEMI:
			hors += 1
		pres_taniere = pres_taniere or q.distance_to(N.taniere) < 500.0
		au_collet = au_collet or q.distance_to(pieu) < 140.0
	var couche = null
	for x in A.poses:
		if is_instance_valid(x) and str(x.genre) == "couche":
			couche = x
	verif(T.nombre(2) >= 12 and au_collet and hors >= 1 and not pres_taniere and (absf(C.sortie.x) > RR.DEMI or absf(C.sortie.y) > RR.DEMI),
		"à l'aube, sa piste part du collet et sort du lieu (%d empreintes, dont %d au-delà de son bord), sans passer par sa tanière" % [T.nombre(2), hors])
	inv["filin"] = 0
	j.position = N.taniere + Vector2(20.0, 6.0)
	_noire_joue(2.0)
	var pas_de_corps: bool = N.corps == null
	jeu.agir()
	var fouillee: bool = couche != null and bool(couche.etat.get("fouillee", false)) and int(inv["filin"]) == 1
	jeu.agir()
	verif(couche != null and couche.position.distance_to(N.taniere) < 1.0 and int(couche.etat.get("noeuds", 0)) >= 2 and pas_de_corps and fouillee and int(inv["filin"]) == 1 and j.sante > 60.0,
		"sa tanière est vide : sa couche froide, et les nœuds qu'elle y a rongés (%d), dont la veilleuse tire un filin, une fois ; plus personne à réveiller" % int(couche.etat.get("noeuds", 0)) if couche != null else "sa couche")
	# (le carnet : ce qu'on a appris d'elle, sa dernière page, son portrait aux trois cicatrices)
	var cles := []
	for sv in N.SAVOIRS:
		cles.append(str(sv[0]))
	N.vue = true
	jeu.en_pause = true
	jeu.ui.montrer_pause(true)
	var carnet = jeu.ui._pause.savoirs
	var textes := PackedStringArray()
	for l in carnet.find_children("*", "Label", true, false):
		textes.append(str(l.text))
	var images: Array = carnet.find_children("*", "TextureRect", true, false)
	jeu.ui.montrer_pause(false)
	jeu.en_pause = false
	var tout_le_carnet := "\n".join(textes)
	verif(cles.has("odeur") and cles.has("collet") and cles.has("cicatrice") and cles.has("depart") and N.su.has("depart") and N.savoirs().size() == N.su.size()
		and tout_le_carnet.contains("La Noire, partie") and tout_le_carnet.contains(C.derniere_page()) and C.derniere_page().contains("nuit %d" % (nuits_tenues + 1))
		and not images.is_empty() and images[0].texture == portrait3["tex"],
		"le carnet garde l'odeur, le collet, les cicatrices, son départ (%d choses sues sur %d), écrit sa dernière page (« %s ») et la montre avec ses trois cicatrices" % [N.su.size(), N.SAVOIRS.size(), C.derniere_page()])
	# la page « Elle est partie. » : après l'aube ; ce n'est pas une fin, la partie continue
	j.position = camp
	var avant_page: bool = jeu.page == "" and C._page_dans > 0.0
	_noire_joue(RR.NOIRE_DEPART_PAGE + 1.0)
	var pg = jeu.ui._page_depart
	var montree: bool = jeu.page == "depart" and jeu.en_pause and pg != null and pg.visible and pg._titre.text == "Elle est partie."
	var d_page: Dictionary = C.page()
	var chiffres := PackedStringArray()
	if pg != null:
		for c in pg._chiffres:
			chiffres.append("%s %s" % [c[0].text, c[1].text])
	jeu.fermer_page()
	verif(avant_page and montree and int(d_page["nombres"][0][0]) == nuits_tenues and int(d_page["nombres"][1][0]) == 3 and int(d_page["nombres"][2][0]) == C.poses_n and C.poses_n >= 5
		and int(d_page["nombres"][3][0]) == C.morsures_n and C.morsures_n == morsures_avant and morsures_avant == 2 and chiffres.size() == 4 and chiffres[1] == "3 cicatrices"
		and jeu.page == "" and not jeu.en_pause and not pg.visible and C.page_dite and jeu.en_partie and jeu._mort < 0.0 and j.sante > 0.0,
		"%d secondes après l'aube, la page « Elle est partie. » : %s ; deux choix, et « Rester veiller » rend la partie, qui continue (ce n'est pas une fin)" % [int(RR.NOIRE_DEPART_PAGE), ", ".join(chiffres)])
	# les nuits d'après : plus rien d'elle
	jeu.horloge = nuit_h + RR.DUREE
	jeu.nuits = nuits_tenues + 1
	jeu.sons.journal = []
	N.tombee()
	var revue := [false]
	var silence := [0.0]
	_noire_joue(duree_nuit, func(_t):
		revue[0] = revue[0] or N.corps != null or N.presente()
		silence[0] = maxf(silence[0], N.silence))
	N.aube()
	verif(not revue[0] and silence[0] < 0.01 and entendu.call("appel") == 0 and N.peur() == 0.0 and T.nombre(2) == 0 and C._page_dans < 0.0 and not N.appat_l_attire(),
		"les nuits d'après : elle ne vient pas, n'appelle pas, ne fait rien taire (les nuits ont retrouvé leurs bruits) ; à l'aube, plus de piste, plus de page")

	# --- la partie gardée, et reprise ---
	var PG = jeu.PartieGardee
	var photo: Dictionary = JSON.parse_string(JSON.stringify(PG.photo(jeu)))
	var poses_n: int = C.poses_n
	await jeu._commencer("foret", photo)
	N = jeu.noire
	C = N.collet
	A = jeu.atelier
	j = jeu.joueur
	var couche2 = null
	for x in A.poses:
		if is_instance_valid(x) and str(x.genre) == "couche":
			couche2 = x
	jeu.horloge = floorf(jeu.horloge / RR.DUREE) * RR.DUREE + RR.DUREE * (1.0 - jeu.part_nuit) + 20.0
	N.tombee()
	var revue2 := [false]
	_noire_joue(30.0, func(_t): revue2[0] = revue2[0] or N.corps != null or N.presente())
	verif(N.partie and N.cicatrices == 3 and C.poses_n == poses_n and C.page_dite and C.aube_dite and N.su.has("depart") and couche2 != null and bool(couche2.etat.get("fouillee", false))
		and not revue2[0] and jeu.page == "" and N.acte_de(99) >= 4,
		"la partie gardée s'en souvient : reprise, elle est toujours partie (ses trois cicatrices, sa couche fouillée, la page lue), et ne revient pas")
	# (une partie gardée la nuit du départ, avant l'aube : reprise, l'aube fait sa piste et sa page)
	C.aube_dite = false
	C.page_dite = false
	C.depart_de = Vector2(-160.0, 115.0)
	C.sortie = Vector2(-RR.DEMI - 260.0, 115.0)
	var photo2: Dictionary = JSON.parse_string(JSON.stringify(N.photo()))
	var N3 = jeu.Noire.new()
	N3.jeu = jeu
	N3.commencer()
	N3.reprendre(photo2)
	jeu.traces.vider()
	jeu.horloge = floorf(jeu.horloge / RR.DUREE) * RR.DUREE + RR.DUREE * 0.3
	N3.aube()
	verif(N3.partie and N3.collet.aube_dite and N3.collet._page_dans > 0.0 and jeu.traces.nombre(2) >= 8 and N3.collet.sortie.distance_to(C.sortie) < 0.2,
		"gardée la nuit même de son départ, la partie reprise retrouve à l'aube sa piste (%d empreintes) et sa page" % jeu.traces.nombre(2))
	jeu.traces.vider()
	# les sons du collet, faits à la main : chacun se fabrique
	var rs := RandomNumberGenerator.new()
	rs.seed = 7
	var faits := 0
	var durees := PackedStringArray()
	for nom in ["collet_claque", "collet_coup0", "collet_coup1", "collet_arrache", "noire_cri", "noire_flaire", "noire_renacle", "dernier_appel"]:
		var a: Array = SA.fabriquer(nom, rs)
		if a.size() == 2 and a[0].size() > int(a[1]) / 5 and SA.NOMS.has(nom):
			var crete := 0.0
			for v in a[0]:
				crete = maxf(crete, absf(v))
			if crete > 0.1 and crete <= 1.0:
				faits += 1
				durees.append("%s %.1f s" % [nom, float(a[0].size()) / float(a[1])])
	verif(faits == 8, "les sons du collet sont faits à la main, comme les autres : %s" % ", ".join(durees))


# la faim et la fin dans la même nuit (les deux ont été écrites à part : scripts/noire_faim.gd, scripts/noire_collet.gd) : à
# l'acte 5, un collet amorcé passe avant le camp ; tenue, elle ne prend rien d'autre ; libérée, elle revient au camp et le met
# en pièces ; partie pour de bon, le crépuscule ne la fait plus venir, et la partie gardée le retient
func _la_noire_reunie() -> void:
	print("15. La Noire : la faim et la fin, ensemble")
	await jeu._commencer("foret")
	await get_tree().process_frame
	seed(20261119)
	var j = jeu.joueur
	var N = jeu.noire
	var A = jeu.atelier
	var W = jeu.monde
	var RR = jeu.R
	var Faim = load("res://scripts/noire_faim.gd")
	jeu.climat.forcer("clair", 0.0, 99999.0)
	jeu.graine = 4242
	N.commencer()
	var C = N.collet
	var F = N.faim
	# (une clairière : rien qui dépasse à 1 250 pixels, ni chose posée, ni bête, ni autre feu)
	var camp := Vector2(260.0, 120.0)
	_remettre(camp)
	j.torche = 0.0
	for o in W.autour(camp + Vector2(-300.0, 0.0), 1250.0):
		if float(o.rayon) > 0.0 or str(o.genre) in ["buisson", "touffe", "brindille", "fleur", "cepe", "amanite", "herbe", "aquatique"]:
			W.retirer(o)
	for x in A.poses.duplicate():
		if is_instance_valid(x) and x.position.distance_to(camp) < 1500.0:
			A.poses.erase(x)
			x.queue_free()
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	for f in jeu.feux.duplicate():
		if is_instance_valid(f):
			f.queue_free()
	jeu.feux.clear()
	var feu = _faim_feu(camp + Vector2(30.0, 0.0), 40.0)
	var r: float = feu.rayon()
	var D: float = RR.DUREE
	var base: float = floorf(jeu.horloge / D) * D
	var nuit_h: float = base + D * (1.0 - jeu.part_nuit) + 20.0
	jeu.horloge = nuit_h
	N.taniere = camp + Vector2(-1500.0, -900.0)
	N.ou = N.taniere
	# le collet, amorcé, sans odeur, à gauche du feu (d'où elle vient) ; la tente à droite, hors de la lumière, à sa portée
	var collet = A._creer("collet", feu.position + Vector2(-420.0, 0.0), {"amorce": true, "odeur": false})
	var tente = A._creer("tente", feu.position + Vector2(r + 170.0, -50.0), {})
	var pose_juste: bool = not C._eclaire(collet) and not F.gardee(tente.position) and Faim.saccageable(tente) and not Faim.saccageable(collet) \
		and tente.position.distance_to(feu.position) < RR.NOIRE_FAIM_PORTEE
	_faim_nuit()
	# --- l'appât d'abord : elle va au collet, pas à la tente ---
	var vu := {"hume": false, "appat": false}
	var prise_a: float = _faim_jusqu_a(func():
		vu["hume"] = vu["hume"] or N.etat in Faim.ETATS
		vu["appat"] = vu["appat"] or N.etat == "appat"
		return N.etat == "prise", 60.0)
	if not (pose_juste and prise_a >= 0.0 and not vu["hume"]):
		print("    (posé juste %s ; prise à %.1f s ; %s ; elle : %s, à %d pixels du collet)" % [str(pose_juste), prise_a, str(vu), str(N.etat), int(N.ou.distance_to(collet.position))])
	verif(pose_juste and int(N.acte) >= RR.NOIRE_FAIM and vu["appat"] and prise_a >= 0.0 and not vu["hume"] and not Faim.est_epave(tente) and N.au_collet(),
		"à la nuit de la faim, un collet amorcé passe avant le camp : elle y va tout droit et s'y prend (%d s), la tente, hors de la lumière, n'a rien" % int(prise_a))
	# --- tenue, puis libérée (personne ne la frappe) : elle revient au feu qui la tient, puis se tourne vers la tente ---
	var tenue_sage := true
	var libre_a: float = _faim_jusqu_a(func():
		tenue_sage = tenue_sage and not (N.etat in Faim.ETATS) and not Faim.est_epave(tente)
		return N.etat != "prise", RR.NOIRE_COLLET_TENUE + 6.0)
	var rompu: bool = str(collet.etat.get("phase", "")) != ""
	var saccage_a: float = _faim_jusqu_a(func(): return Faim.est_epave(tente), 150.0)
	if not (libre_a >= 0.0 and saccage_a >= 0.0):
		print("    (libre à %.1f s ; la tente en pièces à %.1f s ; elle : %s, %d choses prises, tenue par le feu depuis %.1f s, retirée %s)" % [
			libre_a, saccage_a, str(N.etat), int(F.prises), float(F._tenue), str(N._retiree)])
	verif(tenue_sage and libre_a >= 0.0 and rompu and int(N.cicatrices) == 0 and C.prise_cette_nuit and saccage_a >= 0.0 and int(F.prises) == 1 and not N.au_collet(),
		"tenue %d s sans un coup, elle se libère (le collet est rompu, pas de cicatrice) ; le feu la tient, et %d s plus tard c'est la tente qu'elle met en pièces" % [
		int(libre_a), int(saccage_a)])
	# --- on ne lui apporte pas le feu : de la lumière, les coups ne comptent pas ; un feu allumé près du pieu la libère ---
	for x in [collet, tente]:
		A.poses.erase(x)
		x.queue_free()
	var collet2 = A._creer("collet", feu.position + Vector2(-420.0, 0.0), {"amorce": true, "odeur": false})
	_faim_nuit(3)
	var prise2: float = _faim_jusqu_a(func(): return N.etat == "prise", 60.0)
	j.position = camp
	var a_l_abri: bool = jeu.feu_qui_protege(j.position) != null
	for i in 3:
		N.frappee(26.0)
	var sans_effet: bool = float(C.coups) == 0.0 and N.etat == "prise" and int(N.cicatrices) == 0
	var dit_abri: bool = " | ".join(PackedStringArray(jeu.ui._messages.map(func(m): return str(m[0].text)))).contains("Il faut sortir")
	var feu2 = _faim_feu(C.ancre(collet2) + Vector2(70.0, 0.0), 40.0)
	_faim_joue(0.5)
	var arrachee: bool = N.etat != "prise" and int(N.cicatrices) == 0 and str(collet2.etat.get("phase", "")) != ""
	jeu.feux.erase(feu2)
	feu2.queue_free()
	if not (prise2 >= 0.0 and a_l_abri and sans_effet and arrachee):
		print("    (prise à %.1f s ; à l'abri %s ; coups comptés %.0f ; elle : %s, %d cicatrices ; le collet : « %s »)" % [prise2, str(a_l_abri), float(C.coups), str(N.etat), int(N.cicatrices), str(collet2.etat.get("phase", ""))])
	verif(prise2 >= 0.0 and a_l_abri and sans_effet and dit_abri and arrachee,
		"on ne lui apporte pas le feu : trois coups de lance donnés de la lumière ne l'entament pas (« Il faut sortir ») ; un feu allumé près du pieu, et elle arrache tout, sans cicatrice")
	# --- un collet à l'est du feu, juste au-delà de « trop près » : elle fait le tour de la lumière et s'y prend ---
	A.poses.erase(collet2)
	collet2.queue_free()
	var x_est: float = r
	var collet3 = A._creer("collet", feu.position + Vector2(x_est, 0.0), {"amorce": true, "odeur": false})
	while C._eclaire(collet3) and x_est < r + 600.0:
		x_est += 5.0
		collet3.position = feu.position + Vector2(x_est, 0.0)
	x_est += 8.0
	collet3.position = feu.position + Vector2(x_est, 0.0)
	_faim_nuit(3)
	var prise3: float = _faim_jusqu_a(func(): return N.etat == "prise", 150.0)
	var cote_noir: bool = N.corps != null and N.corps.position.x > collet3.position.x and jeu.feu_qui_protege(N.corps.position) == null
	if not (prise3 >= 0.0 and cote_noir):
		print("    (le collet à %d pixels à l'est du feu, sa lumière à %d ; prise à %.1f s ; elle : %s, son côté %s, boudé %s)" % [
			int(x_est), int(r), prise3, str(N.etat), str(C._cote), str(collet3.etat.get("boude", ""))])
	verif(not C._eclaire(collet3) and prise3 >= 0.0 and cote_noir,
		"un collet à l'est du feu, à %d pixels (juste au-delà de « trop près », la lumière à %d) : elle en fait le tour et s'y prend par le côté du noir (%d s) ; elle ne reste pas plantée devant" % [
		int(x_est), int(r), int(prise3)])
	# --- à l'acte de la faim, un collet près de sa tanière : elle part au crépuscule, et il la prend au passage ---
	N._disparaitre()
	N.etat = "dort"
	F.tombee()
	A.poses.erase(collet3)
	collet3.queue_free()
	N.taniere = camp + Vector2(-900.0, -300.0)
	N.ou = N.taniere
	var collet4 = A._creer("collet", N.taniere + (camp - N.taniere).normalized() * 320.0, {"amorce": true, "odeur": false})
	jeu.nuits = N.premiere_nuit(RR.NOIRE_FAIM)
	jeu.horloge = base + D + D * (1.0 - jeu.part_nuit) - 14.0
	var jour_la: float = jeu.jour_du_ciel()
	var prise4: float = _faim_jusqu_a(func(): return N.etat == "prise", 90.0)
	var partie_au_soir: bool = F.soir
	_faim_joue(3.0)
	var tient_au_soir: bool = N.etat == "prise"
	# (et l'aube qui la trouve au collet : elle arrache les pieux et rentre, sans annoncer une charge qui n'aura pas lieu)
	jeu.ui._messages.clear()
	N.aube()
	var dit_aube: String = " | ".join(PackedStringArray(jeu.ui._messages.map(func(m): return str(m[0].text))))
	if not (prise4 >= 0.0 and tient_au_soir and N.etat == "rentre"):
		print("    (le jour à %.2f ; partie au soir %s ; prise à %.1f s ; tient %s ; à l'aube : %s, « %s »)" % [jour_la, str(partie_au_soir), prise4, str(tient_au_soir), str(N.etat), dit_aube])
	verif(jour_la > 0.0 and partie_au_soir and prise4 >= 0.0 and tient_au_soir and N.etat == "rentre" and int(N.cicatrices) == 0 and dit_aube.contains("Le jour vient") and not dit_aube.contains("charger"),
		"à l'acte de la faim, un collet près de sa tanière la prend au crépuscule, quand elle part (le jour encore à %.2f, %d s) et la tient ; l'aube qui la trouve au collet la renvoie sans annoncer de charge" % [jour_la, int(prise4)])
	A.poses.erase(collet4)
	collet4.queue_free()
	# --- une bête laissée dans le noir : elle ne la prend ni au collet, ni blessée et retirée, ni quand elle rentre ---
	N.silence = 1.0
	N._retiree = false
	N.etat = "tourne"
	var prend: bool = N.prend_dans_le_noir()
	N.etat = "prise"
	var pas_prise: bool = not N.prend_dans_le_noir()
	N.etat = "furie"
	pas_prise = pas_prise and not N.prend_dans_le_noir()
	N.etat = "rentre"
	pas_prise = pas_prise and not N.prend_dans_le_noir()
	N.etat = "tourne"
	N._retiree = true
	pas_prise = pas_prise and not N.prend_dans_le_noir()
	N._retiree = false
	N.silence = 0.0
	verif(prend and pas_prise, "une bête laissée dans le noir : elle la prend quand elle assiège, pas quand le collet la mène, ni libérée et furieuse, ni blessée et retirée, ni quand elle rentre")
	# --- partie pour de bon : le crépuscule de la faim ne la fait plus venir ; la partie gardée le retient ---
	N._disparaitre()
	N.etat = "dort"
	N.ou = N.taniere
	F.tombee()
	N.cicatrices = 3
	N.partie = true
	C.aube_dite = true
	C.page_dite = true
	var garde_fou = A._creer("epouvantail", feu.position + Vector2(r + 150.0, 120.0), {})
	jeu.nuits = N.premiere_nuit(RR.NOIRE_FAIM)
	jeu.horloge = base + D + D * (1.0 - jeu.part_nuit) - 12.0
	var venue := false
	_faim_joue(40.0, func(_t):
		venue = venue or N.corps != null or F.soir or N.etat != "dort" or N.presente(), true)
	var nuit_tombee: bool = jeu.jour_du_ciel() <= 0.0
	var d: Dictionary = N.photo()
	N.partie = false
	N.cicatrices = 0
	N.reprendre(d)
	verif(nuit_tombee and not venue and not Faim.est_epave(garde_fou) and N.partie and int(N.cicatrices) == 3 and not F.soir and N.au_collet(),
		"partie pour de bon : au crépuscule d'une nuit de la faim, puis la nuit tombée, elle ne vient pas (ni appel, ni corps, ni silence), l'épouvantail hors de la lumière n'a rien ; une partie reprise s'en souvient")
	for x in [garde_fou]:
		if is_instance_valid(x):
			A.poses.erase(x)
			x.queue_free()
	jeu.feux.erase(feu)
	feu.queue_free()
	N.partie = false
	N.cicatrices = 0


func _conclure() -> void:
	print("\n%s (%d vérifications)" % ["tout passe" if ok else "ÉCHEC", n])
	# (des sons qui jouent encore quand Godot s'arrête, il dit qu'ils fuient : on les arrête, et l'on laisse au serveur audio
	# le temps de les lâcher)
	jeu.sons.arreter_brefs()
	for p in jeu.sons.find_children("*", "AudioStreamPlayer", false, false):
		p.stop()
	_fini = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if ok else 1)


# --- la mémoire d'Orvane (docs/50) : deux mondes pareils sauf ce que les bêtes ont appris des joueurs donnent deux conduites ---
# La copie gardée dans le jeu n'en porte pas : chaque bête est faite ici avec la mémoire qu'aurait sa population, et jouée sans
# attendre, image par image, par les fonctions du jeu (bete.gd, _conduire).

# une bête de cette lignée, dont la population aurait appris cela (les autres dispositions à leur valeur neutre) ; elle est la
# bête moyenne de sa population (ecart 0), sauf si l'entrée dit son écart d'audace
# le lance-pierre et ses galets (l'établi les fait ; principal.gd tire ; galet.gd vole), et le coffre où se trouve la lance
func _le_lance_pierre(F: Dictionary) -> void:
	print("Le lance-pierre, le coffre")
	var j = jeu.joueur
	var A = jeu.atelier
	var RR = jeu.R
	var garde := {"p": j.position, "inv": j.inventaire.duplicate(), "objets": A.objets.duplicate(), "lance": j.lance, "h": jeu.horloge, "regard": j.regard,
		"chassees": jeu.chassees, "prel": jeu.prelevements.duplicate(), "deja": jeu._deja.duplicate()}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	jeu.horloge = floorf(jeu.horloge / RR.DUREE) * RR.DUREE + RR.DUREE * 0.3
	var inv: Dictionary = j.inventaire
	# un tir, joué sans attendre : elle arme, sa main lâche (le signal que joueur.gd envoie), le galet vole jusqu'au bout
	var tirer := func() -> bool:
		jeu._tir = 0.0
		jeu.tirer()
		if jeu._tir_vise.is_empty():
			return false
		jeu._sur_impact(j.position + Vector2(8.0 * j.regard, -22.0), "tir")
		var parti := false
		for g in jeu.monde.get_children():
			if g.get_script() == jeu.Galet and g.is_processing():
				parti = true
				for i in 200:
					if not g.is_processing():
						break
					g._process(0.02)
		return parti

	# le coffre : un seul dans le lieu, près d'un camp abandonné, loin du réveil ; la lance ne se trouve que là
	var coffres: Array = A.poses.filter(func(s): return is_instance_valid(s) and str(s.genre) == "coffre")
	var vestiges: Array = A.poses.filter(func(s): return is_instance_valid(s) and str(s.genre) == "vestige")
	var pres_d_un_camp := false
	if coffres.size() == 1:
		for v in vestiges:
			if v.position.distance_to(coffres[0].position) < 90.0 and int(v.etat.get("riche", 0)) > 0:
				pres_d_un_camp = true
	verif(coffres.size() == 1 and pres_d_un_camp and coffres[0].position.length() > 500.0,
		"un coffre dans le lieu, un seul, près du camp abandonné le mieux pourvu, à %d pixels du réveil" % (int(coffres[0].position.length()) if coffres.size() > 0 else -1))
	if coffres.size() == 1:
		var c = coffres[0]
		j.lance = 0
		inv["galet"] = 0
		# (du côté opposé au camp abandonné : « Agir » sert la chose la plus proche)
		j.position = c.position + Vector2(30.0, 6.0)
		var pris: bool = A.agir()
		var lance1: int = j.lance
		var galets1 := int(inv["galet"])
		j.lance = 3
		A.agir()
		verif(pris and lance1 == RR.USURE_LANCE and galets1 == RR.GALETS_COFFRE and j.lance == 3 and int(inv["galet"]) == galets1 and bool(c.etat.get("ouvert", false)) and not A.replier(),
			"« Agir » l'ouvre : une lance entière (%d coups) et %d galets ; rouvert, il est vide ; il ne se replie pas" % [lance1, galets1])

	# à l'établi : les galets, quatre par pierre ; le lance-pierre, une fois
	for s in A.poses.duplicate():
		if is_instance_valid(s) and str(s.genre) == "etabli":
			A.poses.erase(s)
			s.queue_free()
	j.position = Vector2(40.0, 300.0)
	j.regard = 1.0
	A.objets.erase("lance_pierre")
	inv["galet"] = 0
	inv["pierre"] = 3
	inv["bois"] = 5
	inv["corde"] = 2
	inv["peau"] = 2
	var sans_etabli: bool = not A.peut("lance_pierre") and not A.peut("galet")
	var sans_arme: bool = not jeu.peut_fabriquer("tir") and not tirer.call()
	var etabli = A._creer("etabli", j.position + Vector2(30.0, 0.0), {})
	var fait_g: bool = A.fabriquer("galet")
	var fait_l: bool = A.fabriquer("lance_pierre")
	verif(sans_etabli and sans_arme and fait_g and fait_l and int(inv["galet"]) == 4 and int(inv["pierre"]) == 2 and A.possede("lance_pierre") == 1 and int(inv["bois"]) == 4
		and int(inv["corde"]) == 1 and int(inv["peau"]) == 1 and not A.peut("lance_pierre") and jeu.peut_fabriquer("tir"),
		"à l'établi seulement : une pierre donne %d galets ; le lance-pierre (un bois, une corde, une peau) ne se fait qu'une fois ; sans lui, on ne tire pas" % int(inv["galet"]))

	# un tir : le galet part vers la bête la plus proche à portée, la blesse, et il en reste un de moins
	var proie = _bete(F["proies_jour"][0], "proie", j.position + Vector2(190.0, -40.0), {})
	proie.conduite = false
	proie.pv = 500.0
	var pv0: float = proie.pv
	var parti: bool = tirer.call()
	var touche: bool = absf((pv0 - proie.pv) - RR.DEGATS_TIR) < 0.01
	var reste := int(inv["galet"])
	# (la cadence : un second tir aussitôt ne part pas)
	jeu.tirer()
	var trop_tot: bool = jeu._tir_vise.is_empty()
	# (hors de portée : elle tire droit devant, le galet tombe dans l'herbe)
	proie.position = j.position + Vector2(RR.PORTEE_TIR + 200.0, 0.0)
	var pv1: float = proie.pv
	var parti2: bool = tirer.call()
	verif(parti and touche and reste == 3 and trop_tot and parti2 and proie.pv == pv1 and int(inv["galet"]) == 2 and RR.DEGATS_TIR > RR.DEGATS_POINGS and RR.DEGATS_TIR < RR.DEGATS_LANCE,
		"un tir : le galet vole jusqu'à la bête à %d pixels et lui prend %d (les poings : %d, la lance : %d) ; pas deux tirs à la fois ; hors de portée, il tombe dans l'herbe ; chaque tir prend un galet" % [
			190, int(RR.DEGATS_TIR), int(RR.DEGATS_POINGS), int(RR.DEGATS_LANCE)])
	# (dans le noir aussi : un chasseur dont on ne voit que les yeux)
	proie.position = j.position + Vector2(150.0, 30.0)
	proie.pv = RR.DEGATS_TIR * 0.5
	var chassees0: int = jeu.chassees
	tirer.call()
	inv["galet"] = 0
	var vide: bool = not jeu.peut_fabriquer("tir") and not tirer.call()
	verif(not is_instance_valid(proie) or proie.pv <= 0.0 and jeu.chassees == chassees0 + 1 and vide,
		"un galet peut tuer : c'est une chasse ; sans galet, on ne tire plus")
	_oter(proie)
	# la nuit, on ne tire que sur ce qu'on voit : des yeux qui brillent, oui ; un chasseur qui s'est détourné, non
	jeu.horloge = floorf(jeu.horloge / RR.DUREE) * RR.DUREE + RR.DUREE * (1.0 - jeu.part_nuit) + 2.0
	var torche0: float = j.torche
	j.torche = 0.0
	var feux0: Array = jeu.feux.duplicate()
	jeu.feux.clear()
	inv["galet"] = 10
	var rode = _bete(F["chasseurs_nuit"][0], "chasseur", j.position + Vector2(170.0, 20.0), {})
	rode.conduite = false
	rode.pv = 500.0
	rode.detourne = 0.0
	var pv_r: float = rode.pv
	# (vers des yeux, dans le noir, elle manque souvent : douze galets, pour être sûr d'en voir toucher un)
	var tires := 0
	inv["galet"] = 12
	while tires < 12 and rode.pv == pv_r:
		tires += 1
		tirer.call()
	var vu: bool = rode.pv < pv_r
	rode.detourne = 1.0
	pv_r = rode.pv
	inv["galet"] = 6
	var partis := 0
	for i in 6:
		if tirer.call():
			partis += 1
	verif(vu and partis == 6 and rode.pv == pv_r and jeu.lumiere_du_jour() < 0.3 and RR.TIR_NOIR >= 15.0,
		"la nuit, dans le noir : elle vise les yeux qui brillent, moins juste qu'en pleine lumière (touché au %s tir) ; détourné, on le perd, et ses galets partent droit devant" % (
			"1er" if tires == 1 else "%de" % tires))
	_oter(rode)
	# un chasseur à son affût, touché de loin : il quitte son poste et se détourne ; la Noire : un galet l'agace à peine
	var guet = _bete(F["chasseurs_nuit"][0], "chasseur", j.position + Vector2(260.0, 0.0), {"traque": 1.0})
	guet.conduite = false
	guet.pv = 500.0
	guet.pv_max = 500.0
	# (un traqueur entier : la première nuit, sa traque est rabattue de moitié, et il pourrait alors, une fois sur huit, fuir
	# au lieu de changer de poste ; ce n'est pas ce qu'on regarde ici)
	guet.traque = 1.0
	guet._poste_feu = guet
	guet._af = guet.Affut.POSTE
	var Af = guet.Affut
	# (un faux feu, le temps du test : il lui faut un rayon, une place, une flamme)
	var faux = jeu.Feu.new()
	faux.jeu = jeu
	faux.position = j.position
	faux.bois = 40.0
	jeu.monde.add_child(faux)
	guet._poste_feu = faux
	guet.blesser(1.0, j.position)
	var quitte: bool = guet._af == Af.CHANGE
	_oter(guet)
	faux.queue_free()
	verif(quitte and RR.TIR_NOIRE * RR.DEGATS_TIR * 20.0 < RR.NOIRE_ENDURE,
		"un chasseur à l'affût, touché de loin, quitte son poste et se détourne ; la Noire : vingt galets ne suffisent pas à la faire partir (%d sur %d)" % [
			int(RR.TIR_NOIRE * RR.DEGATS_TIR * 20.0), int(RR.NOIRE_ENDURE)])
	jeu.feux.assign(feux0)
	j.torche = torche0
	A.poses.erase(etabli)
	etabli.queue_free()
	j.position = garde["p"]
	j.regard = garde["regard"]
	j.lance = garde["lance"]
	j.inventaire.clear()
	j.inventaire.merge(garde["inv"], true)
	A.objets = garde["objets"]
	jeu.horloge = garde["h"]
	jeu.chassees = garde["chassees"]
	jeu.prelevements = garde["prel"]
	jeu._deja = garde["deja"]
	jeu._tir = 0.0


# le jardin (scripts/jardin.gd) et l'élevage (scripts/elevage.gd)
func _le_jardin_et_les_betes(F: Dictionary) -> void:
	print("Le jardin et les bêtes")
	var j = jeu.joueur
	var A = jeu.atelier
	var J = jeu.jardin
	var E = jeu.elevage
	var C = jeu.climat
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "p": j.position, "inv": j.inventaire.duplicate(), "sante": j.sante, "faim": j.faim, "peur": j.peur, "torche": j.torche,
		"pluie": C.pluie, "air": C.air, "neige": C.neige_sol, "feux": jeu.feux.duplicate(), "regard": j.regard, "acte": jeu.noire.acte}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	var jour_h: float = base + RR.DUREE * 0.3
	var nuit_h: float = base + RR.DUREE * (1.0 - jeu.part_nuit) + 2.0
	jeu.horloge = jour_h
	jeu.feux.clear()
	C.pluie = 0.0
	C.air = 0.5
	C.neige_sol = 0.0
	j.torche = 0.0
	j.regard = 1.0
	A.commencer()
	E.vider()
	var inv: Dictionary = j.inventaire
	# (un endroit dégagé : ni eau, ni tronc, ni buisson)
	var ici := Vector2.ZERO
	for k in 200:
		var q := Vector2(-300.0 + 90.0 * (k % 14), -300.0 + 90.0 * (k / 14))
		j.position = q
		A.objets["houe"] = 1
		if J.empeche_becher() == "" and float(C.eau(q)) < 0.05:
			ici = q
			break
	j.position = ici

	# la houe, un carré, des graines
	A.objets.erase("houe")
	var sans_houe: String = J.empeche_becher()
	A.objets["houe"] = 1
	var beche: bool = J.becher()
	var carre = J.carres()[0] if J.carres().size() == 1 else null
	verif(sans_houe.contains("houe") and beche and carre != null and str(carre.etat.get("culture", "x")) == "" and carre.position.distance_to(j.position) < 80.0,
		"avec une houe, elle retourne un carré de terre devant elle ; sans houe, non (« %s »)" % sans_houe)
	var rien: bool = not J.semer(carre, "lin")
	inv["graine_lin"] = 2
	inv["graine_baie"] = 1
	var choix: String = J.culture_par_defaut()
	jeu.atelier.agir()
	verif(rien and choix == "lin" and str(carre.etat["culture"]) == "lin" and int(inv["graine_lin"]) == 0,
		"« Agir » devant un carré vide y sème ce dont elle a assez de graines (deux) ; sans graines, rien")

	# ça pousse si la terre est humide ; l'arrosoir, la pluie
	carre.etat["eau"] = 0.0
	for i in 60:
		J.maj(2.0)
	var a_sec: float = carre.etat["stade"]
	var sans_arrosoir: bool = not J.arroser(carre)
	A.objets["arrosoir"] = 1
	var vide: bool = not J.arroser(carre)
	var cuve = A._creer("recuperateur", ici + Vector2(0.0, -140.0), {"eau": 4.0})
	var rempli: bool = J.remplir(cuve)
	var arrose: bool = J.arroser(carre)
	for i in 60:
		J.maj(2.0)
	var humide: float = carre.etat["stade"]
	verif(a_sec == 0.0 and sans_arrosoir and vide and rempli and absf(float(cuve.etat["eau"]) - 2.0) < 0.01 and arrose and J.arrosages() == J.ARROSAGES - 1 and humide > 1.0 and humide < 2.0,
		"la terre sèche, rien ne pousse ; l'arrosoir se remplit au récupérateur (quatre arrosages pour deux gorgées), et arrosé, le lin lève : stade %.1f en une demi-journée" % humide)
	carre.etat["eau"] = 0.0
	C.pluie = 1.0
	for i in 10:
		J.maj(1.0)
	C.pluie = 0.0
	var mouille: float = carre.etat["eau"]
	C.neige_sol = 1.0
	var avant_gel: float = carre.etat["stade"]
	for i in 30:
		J.maj(2.0)
	C.neige_sol = 0.0
	verif(mouille > 0.9 and absf(float(carre.etat["stade"]) - avant_gel) < 0.001 and bool(carre.etat["gel"]),
		"la pluie arrose le jardin ; sous la neige, il ne pousse plus")
	carre.etat["eau"] = 1.0
	carre.etat["stade"] = 2.95
	J.maj(8.0)
	inv["fibre"] = 0
	var mur: bool = J.mur(carre)
	jeu.atelier.agir()
	verif(mur and int(inv["fibre"]) == 8 and int(inv["graine_lin"]) == J.RENDUES and str(carre.etat["culture"]) == "",
		"mûr, le lin se récolte : huit fibres, et trois graines pour le resemer")

	# les bêtes le mangent, sauf sous la garde d'un épouvantail
	var espece: Dictionary = {}
	for e in F["proies_jour"] + F["proies_nuit"]:
		var essai_b = _bete(e, "proie", ici + Vector2(900.0, 0.0), {})
		var bonne: bool = E.apprivoisable(essai_b)
		_oter(essai_b)
		if bonne:
			espece = e
			break
	if espece.is_empty():
		print("  (aucune proie à quatre pattes dans ce lieu : le reste n'est pas essayé)")
	else:
		inv["graine_baie"] = 2
		J.semer(carre, "baie")
		carre.etat["stade"] = 2.0
		carre.etat["eau"] = 1.0
		j.position = ici + Vector2(-700.0, 0.0)
		var brouteuse = _bete(espece, "proie", carre.position + Vector2(120.0, 20.0), {})
		var tentee: bool = jeu.tentation(brouteuse) == carre
		var tete := 0.0
		for i in 240:
			brouteuse._conduire(0.1)
			tete = maxf(tete, float(brouteuse.mange))
		var mange: float = 2.0 - float(carre.etat.get("stade", 0.0))
		carre.etat["culture"] = "baie"
		carre.etat["stade"] = 2.0
		var epouvantail = A._creer("epouvantail", carre.position + Vector2(60.0, -30.0), {})
		brouteuse._tentation_t = 0.0
		for i in 60:
			brouteuse._conduire(0.1)
		verif(tentee and mange > 0.5 and tete > 0.6 and jeu.tentation(brouteuse) != carre and J.garde(carre.position) and float(carre.etat["stade"]) == 2.0,
			"une bête qui broute vient manger ce qui pousse (la tête au sol : le carré a perdu %.1f stade) ; l'épouvantail posé, elle n'y touche plus" % mange)
		_oter(brouteuse)
		# la nuit, l'épouvantail regarde d'où vient la Noire
		jeu.horloge = jour_h
		J.maj(0.1)
		var de_jour: bool = not epouvantail.etat.has("regard")
		jeu.horloge = nuit_h
		jeu.noire.acte = 2
		J.maj(0.1)
		var vers: Vector2 = Vector2(jeu.noire.taniere) - epouvantail.position
		verif(de_jour and epouvantail.etat.has("regard") and absf(angle_difference(float(epouvantail.etat["regard"]), vers.angle())) < 0.01,
			"de jour l'épouvantail ne regarde rien ; la nuit, il est tourné vers d'où vient la Noire")
		jeu.horloge = jour_h

		# des simples : la santé, la peur
		inv["simples"] = 1
		j.sante = 50.0
		j.peur = 60.0
		var panse: bool = J.panser()
		verif(panse and j.sante == 50.0 + J.SIMPLES_SANTE and j.peur == 60.0 - J.SIMPLES_PEUR and not J.panser(), "des simples : la santé revient, la peur s'apaise")

		# l'appât, le licol
		j.position = ici
		inv["baies"] = 1
		var sans_baies: bool = not E.poser_appat()
		inv["baies"] = 4
		var pose: bool = E.poser_appat()
		var appat = A.poses[A.poses.size() - 1]
		j.position = ici + Vector2(-700.0, 0.0)
		var grande: Dictionary = espece.duplicate()
		grande["masse"] = 220.0
		grande.erase("largeur")
		var bete = _bete(grande, "proie", appat.position + Vector2(150.0, 30.0), {})
		for i in 120:
			bete._conduire(0.1)
		var a_l_appat: bool = bete.mange > 0.6 and bete.position.distance_to(appat.position) < 60.0
		# (la tête dedans, elle laisse venir ; sans licol, rien)
		j.position = bete.position + Vector2(-40.0 - bete.largeur * 0.25, 0.0)
		bete._conduire(0.1)
		var reste_la: bool = str(bete.etat) != "fuit"
		var sans_licol: bool = not E.agir() and E.betes.is_empty()
		A.objets["licol"] = 1
		jeu.agir()
		verif(sans_baies and pose and str(appat.genre) == "appat" and int(inv["baies"]) == 2 and a_l_appat and reste_la and sans_licol and E.betes.has(bete) and str(bete.role) == "compagne"
			and bool(bete.harnais.get("licol", false)) and A.possede("licol") == 0 and bete.pv == bete.pv_max,
			"deux baies font un appât ; une proie vient y manger, et la tête dedans laisse venir : « Agir » lui passe le licol (sans la frapper), elle est à elle")

		# elle suit ; elle reste au piquet ; la mangeoire
		j.position = bete.position + Vector2(400.0, 0.0)
		for i in 100:
			bete._conduire(0.1)
			E.maj(0.1)
		var suivie: bool = bete.position.distance_to(j.position) < 150.0 and bete.longe != null
		var piquet = A._creer("piquet", bete.position + Vector2(30.0, 0.0), {})
		j.position = bete.position + Vector2(-30.0, 0.0)
		jeu.agir()
		E.maj(0.1)
		var liee: bool = not bete.suit_la and bool(piquet.etat.get("attache", false)) and bete.longe != null and Vector2(bete.longe).distance_to(piquet.position) < 14.0
		j.position = bete.position + Vector2(600.0, 0.0)
		for i in 100:
			bete._conduire(0.1)
		var restee: bool = bete.position.distance_to(piquet.position) < 80.0
		var auge = A._creer("mangeoire", piquet.position + Vector2(0.0, 50.0), {})
		inv["fibre"] = 6
		j.position = auge.position + Vector2(20.0, 0.0)
		jeu.atelier.agir()
		bete.faim = 30.0
		E.maj(0.1)
		verif(suivie and liee and restee and int(inv["fibre"]) == 2 and int(auge.etat["foin"]) == 3 and bete.faim > 70.0,
			"sa bête la suit, sa longe dans la main ; laissée près d'un piquet d'attache, elle y reste ; la mangeoire garnie la nourrit")

		# les sacoches, la selle
		j.position = bete.position + Vector2(-30.0, 0.0)
		var cap0: int = A.capacite()
		A.objets["sacoche"] = 1
		var chargee: bool = E.harnacher(bete, "sacoche")
		var cap1: int = A.capacite()
		j.position = bete.position + Vector2(500.0, 0.0)
		var cap2: int = A.capacite()
		j.position = bete.position + Vector2(-30.0, 0.0)
		var petite = _bete(espece, "proie", bete.position + Vector2(0.0, 60.0), {})
		petite.masse = 12.0
		var trop_petite: String = E.empeche_harnacher(petite, "selle")
		_oter(petite)
		var sans_selle: String = E.empeche_monter(bete)
		A.objets["selle"] = 1
		var sellee: bool = E.harnacher(bete, "selle")
		jeu.agir()
		var en_selle: bool = E.monture == bete and bete.montee and j.monture == bete
		var x0: float = j.position.x
		j.deplacer(Vector2(1, 0), 0.5, jeu.monde)
		E.maj(0.5)
		var en_selle_dx: float = j.position.x - x0
		var dessous: bool = bete.position.distance_to(j.position) < 1.0
		jeu.agir()
		var a_pied: bool = E.monture == null and not bete.montee and j.monture == null
		x0 = j.position.x
		j.deplacer(Vector2(1, 0), 0.5, jeu.monde)
		var a_pied_dx: float = j.position.x - x0
		verif(chargee and cap1 == cap0 + E.SACOCHE and cap2 == cap0 and trop_petite != "" and sans_selle.contains("selle") and sellee and en_selle and dessous and a_pied
			and en_selle_dx > a_pied_dx * 1.4,
			"des sacoches : à ses côtés, elle porte %d de plus ; une selle (pas sur une petite bête) : « Agir » la monte, puis la descend ; en selle elle va %.1f fois plus vite" % [E.SACOCHE, en_selle_dx / maxf(a_pied_dx, 0.01)])

		# son harnais se dessine, la selle a son creux ; les six gestes du jardin et de l'élevage existent
		bete._harnacher()
		var creux: Vector2 = bete.siege()
		var gestes_la := true
		for g in ["becher", "semer", "arroser", "caresser", "seller", "traire"]:
			if not j.ATELIER.has(g) or not A.GESTES.has(g):
				gestes_la = false
		verif(bete._harnais_n != null and creux.y < bete.position.y - 8.0 and absf(creux.x - bete.position.x) < bete.largeur and gestes_la,
			"son harnais se dessine sur elle, la selle a son creux (à %d pixels au-dessus de ses pieds) ; bêcher, semer, arroser, caresser, seller, traire ont leur geste" % int(bete.position.y - creux.y))

		# le lait
		bete.lait = 0.0
		bete.faim = 90.0
		var pas_encore: String = E.empeche_traire(bete)
		for i in 125:
			E.maj(2.0)
			bete.faim = 90.0
		var traite: bool = E.traire(bete)
		j.faim = 40.0
		var bu: bool = E.boire_lait()
		verif(pas_encore != "" and traite and bu and absf(j.faim - (40.0 + E.LAIT_FAIM)) < 0.1 and int(inv["lait"]) == 0, "nourrie, elle donne son lait une fois par jour ; il nourrit")

		# la peur : un chasseur près d'elle, on ne la monte pas ; en selle, elle jette à terre
		j.position = bete.position + Vector2(-30.0, 0.0)
		jeu.agir()
		var remontee: bool = E.monture == bete
		var chasseur = _bete(F["chasseurs_nuit"][0], "chasseur", bete.position + Vector2(90.0, 0.0), {})
		j.sante = 100.0
		E.maj(0.1)
		var jetee: bool = E.monture == null and j.sante < 100.0
		var refuse: String = E.empeche_monter(bete)
		_oter(chasseur)
		verif(remontee and jetee and refuse != "", "un chasseur tout près : sa monture se cabre et la jette à terre, et ne se laisse plus monter (« %s »)" % refuse)
		bete.etat = "repos"

		# le feu ne la fait pas fuir : tenue au piquet ou en licol, elle s'y sent à l'abri, même si sa population le craint
		jeu.horloge = jour_h
		bete.peur_feu = 1.0
		bete.suit_la = false
		bete.maison = piquet.position + Vector2(18.0, 10.0)
		bete.position = bete.maison
		j.position = piquet.position + Vector2(-140.0, 0.0)
		var feu_camp = jeu.Feu.new()
		feu_camp.jeu = jeu
		feu_camp.position = piquet.position + Vector2(0.0, 110.0)
		jeu.monde.add_child(feu_camp)
		jeu.feux.append(feu_camp)
		E.maj(0.1)
		var a_l_abri: bool = jeu.feu_qui_protege(bete.position) == feu_camp and bete.tenue()
		var maison0: Vector2 = bete.maison
		var jamais_fui := true
		var ecartee := 0.0
		for k in 3:
			# (une bûche, trois fois : la gerbe d'étincelles)
			bete.gerbe(feu_camp)
			for i in 20:
				bete._conduire(0.1)
				E.maj(0.1)
				jamais_fui = jamais_fui and str(bete.etat) != "fuit"
				ecartee = maxf(ecartee, bete.position.distance_to(maison0))
		# (la foudre tombe à côté : dans la lumière du feu, elle tressaille, sans plus)
		bete.effrayer(bete.position + Vector2(160.0, 0.0), 3.0)
		jamais_fui = jamais_fui and str(bete.etat) != "fuit"
		var au_piquet: bool = E.betes.has(bete) and bool(piquet.etat.get("attache", false)) and bete.maison == maison0
		# (en licol, sa longe dans la main de la veilleuse, au bord du feu)
		bete.suit_la = true
		j.position = bete.position + Vector2(-60.0, 0.0)
		E.maj(0.1)
		var en_main: bool = bete.tenue() and Vector2(bete.longe).distance_to(j.position) < 1.0
		for k in 3:
			bete.gerbe(feu_camp)
			for i in 20:
				bete._conduire(0.1)
				E.maj(0.1)
				jamais_fui = jamais_fui and str(bete.etat) != "fuit"
		var reste_en_main: bool = E.betes.has(bete) and bete.position.distance_to(j.position) < 150.0
		verif(a_l_abri and jamais_fui and ecartee < 48.0 and au_piquet and en_main and reste_en_main,
			"tenue au piquet ou en licol, sa bête ne fuit pas le feu (sa population le craint-elle) : une bûche, la foudre, elle reste au feu, attachée (à %d pixels au plus de sa place)" % int(ecartee))
		jeu.feux.erase(feu_camp)
		feu_camp.queue_free()

		# ce qui l'effraie hors de la lumière (la foudre) : un écart au bout de sa longe, et elle se reprend, toujours au piquet
		bete.suit_la = false
		bete.maison = maison0
		bete.position = maison0
		bete.etat = "repos"
		j.position = piquet.position + Vector2(-140.0, 0.0)
		E.maj(0.1)
		bete.effrayer(bete.position + Vector2(120.0, 0.0), 3.0)
		var sursaute: bool = str(bete.etat) == "fuit"
		var bout := 0.0
		for i in 40:
			bete._conduire(0.1)
			E.maj(0.1)
			bout = maxf(bout, bete.position.distance_to(maison0))
		var reprise: bool = str(bete.etat) != "fuit" and bete.maison == maison0 and bool(piquet.etat.get("attache", false)) and E.betes.has(bete)
		verif(sursaute and bout > 5.0 and bout < 50.0 and reprise,
			"hors de la lumière, la foudre lui fait faire un écart au bout de sa longe (%d pixels), puis elle se reprend, toujours au piquet" % int(bout))
		bete.peur_feu = 0.0
		bete.etat = "repos"

		# la torche en selle : une monture dont la lignée s'est faite au feu la souffre ; les autres se cabrent, et refusent
		bete.suit_la = true
		j.position = bete.position + Vector2(-30.0, 0.0)
		j.torche = 0.0
		var neutre_monte: bool = E.monter(bete)
		j.torche = 20.0
		E.maj(0.1)
		var cabree: bool = E.monture == null and not bete.montee and j.monture == null
		var refus_torche: String = E.empeche_monter(bete)
		bete.etat = "repos"
		A.objets["licol"] = 1
		var faite = _bete(grande, "proie", j.position + Vector2(0.0, 120.0), {"neophobie": 0.05})
		var apprivoisee: bool = E.apprivoiser(faite)
		faite.harnais["selle"] = true
		j.position = faite.position + Vector2(-30.0, 0.0)
		var accepte: String = E.empeche_monter(faite)
		var montee_torche: bool = E.monter(faite)
		for i in 20:
			E.maj(0.1)
		var tient_torche: bool = E.monture == faite and faite.montee and j.monture == faite
		E.descendre()
		j.torche = 0.0
		verif(not bete.faite_au_feu() and faite.faite_au_feu() and neutre_monte and cabree and refus_torche.contains("torche") and apprivoisee
			and accepte == "" and montee_torche and tient_torche,
			"la torche en selle : une monture dont la lignée s'est faite au feu (« %s ») la souffre ; une autre se cabre, la jette à terre, et refuse (« %s »)" % [
			jeu.Donnees.dire_memoire(faite.memoire), refus_torche])
		E.betes.erase(faite)
		_oter(faite)

		# la nuit : dans le noir, elle rompt sa longe ; dans la lumière d'un feu, elle reste ; la Noire prend celle qu'on y laisse
		jeu.horloge = nuit_h
		jeu.noire.acte = 1
		bete.suit_la = false
		bete.maison = bete.position
		j.position = bete.position + Vector2(800.0, 0.0)
		var feu = jeu.Feu.new()
		feu.jeu = jeu
		feu.position = bete.position + Vector2(40.0, 0.0)
		jeu.monde.add_child(feu)
		jeu.feux.append(feu)
		for i in 30:
			E.maj(1.0)
		var au_feu: bool = E.betes.has(bete)
		jeu.feux.erase(feu)
		feu.queue_free()
		for i in 30:
			E.maj(1.0)
		var enfuie: bool = not E.betes.has(bete) and str(bete.role) == "proie" and bete.harnais.is_empty()
		verif(au_feu and enfuie, "la nuit, près d'un feu, sa bête reste ; dans le noir, au bout de %d secondes, elle rompt sa longe et s'enfuit" % int(E.NOIR))
		_oter(bete)

		# la partie gardée
		var b2 = _bete(grande, "proie", ici + Vector2(100.0, 0.0), {"neophobie": 0.05})
		b2.ecart = 0.8
		A.objets["licol"] = 1
		jeu.horloge = jour_h
		E.apprivoiser(b2)
		b2.harnais["selle"] = true
		b2.suit_la = false
		b2.faim = 61.0
		var photo: Dictionary = JSON.parse_string(JSON.stringify(E.photo()))
		var avant_n: int = get_tree().get_nodes_in_group("betes").size()
		E.vider()
		E.reprendre(photo)
		var b3 = E.betes[0] if E.betes.size() == 1 else null
		verif(b3 != null and b3 != b2 and str(b3.role) == "compagne" and bool(b3.harnais.get("selle", false)) and not b3.suit_la and absf(b3.faim - 61.0) < 0.2
			and b3.position.distance_to(b2.position) < 1.0 and str(b3.id) == str(b2.id) and get_tree().get_nodes_in_group("betes").size() == avant_n + 1
			and b3.faite_au_feu() and absf(b3.ecart - 0.8) < 0.01,
			"la partie gardée retient ses bêtes : l'espèce, où elles sont, leur harnais, leur faim, ce que les leurs ont appris (faite au feu), leur audace")
		_oter(b2)
		if b3 != null:
			_oter(b3)

	# (tout remis comme avant)
	for s3 in A.poses:
		if is_instance_valid(s3):
			s3.queue_free()
	A.commencer()
	E.vider()
	for k in inv.keys():
		inv[k] = int(garde["inv"].get(k, 0))
	jeu.feux.clear()
	for f in garde["feux"]:
		jeu.feux.append(f)
	jeu.horloge = garde["h"]
	jeu.noire.acte = garde["acte"]
	j.position = garde["p"]
	j.regard = garde["regard"]
	j.sante = garde["sante"]
	j.faim = garde["faim"]
	j.peur = garde["peur"]
	j.torche = garde["torche"]
	j.monture = null
	C.pluie = garde["pluie"]
	C.air = garde["air"]
	C.neige_sol = garde["neige"]


# la carte, la plume et l'encre (scripts/reperes.gd) : elles se fabriquent à l'établi ; sans carte, la pause n'en montre pas ;
# avec, ce qu'elle a parcouru du lieu ; la plume y écrit des repères là où elle se tient (le même tout près est récrit), on les
# raye, la page de la carte le fait ; la tanière de la Noire s'écrit d'elle-même ; la partie gardée s'en souvient
func _la_carte() -> void:
	print("La carte")
	var j = jeu.joueur
	var A = jeu.atelier
	var Rp = jeu.reperes
	var inv: Dictionary = j.inventaire
	var garde := {"p": j.position, "inv": inv.duplicate(), "objets": A.objets.duplicate(), "liste": Rp.liste.duplicate(true), "vus": Rp.vus.duplicate(),
		"connue": jeu.noire.taniere_connue, "taniere": jeu.noire.taniere, "h": jeu.horloge}
	var ici: Vector2 = j.position
	var etabli = A._creer("etabli", jeu.monde.repousser(ici + Vector2(30.0, 0.0), 10.0), {})
	A.objets.erase("carte")
	A.objets.erase("plume")

	# sans carte : rien à la pause, rien ne s'écrit ; à l'établi, la carte, puis la plume et l'encre
	jeu.ui.montrer_pause(true)
	var sans: bool = not jeu.ui._pause.carte_monde.visible and jeu.ui._pause._commandes.visible
	jeu.ui.montrer_pause(false)
	var refus: String = Rp.empeche_ecrire()
	for k in ["peau", "corde", "fibre", "baies", "pierre"]:
		inv[k] = 0
	inv["peau"] = 1
	inv["corde"] = 1
	var fait_carte: bool = A.fabriquer("carte")
	var sans_plume: String = Rp.empeche_ecrire()
	var sans_baies: String = A.empeche("plume")
	inv["fibre"] = 1
	inv["baies"] = 2
	inv["pierre"] = 1
	var fait_plume: bool = A.fabriquer("plume")
	var paye: bool = int(inv["peau"]) == 0 and int(inv["corde"]) == 0 and int(inv["fibre"]) == 0 and int(inv["baies"]) == 0 and int(inv["pierre"]) == 0
	inv["peau"] = 1
	inv["corde"] = 1
	var une_seule: String = A.empeche("carte")
	verif(sans and refus.contains("carte") and fait_carte and sans_plume.contains("plume") and sans_baies.contains("baies") and fait_plume and paye
		and une_seule.contains("déjà") and A.possede("carte") == 1 and A.possede("plume") == 1,
		"sans carte, la pause n'en montre pas et rien ne s'écrit ; à l'établi, la carte (une peau, une corde), la plume et l'encre (une fibre, deux baies, une pierre) ; une seule de chaque")

	# ce qu'elle parcourt du lieu s'y dessine ; la pause montre la carte
	Rp.vus.clear()
	j.position = ici + Vector2(600.0, 0.0)
	Rp.voir(j.position)
	var vu_la: bool = Rp.vus.has(Rp.cle(j.position)) and not Rp.vus.has(Rp.cle(ici + Vector2(-1500.0, 0.0)))
	Rp.voir(ici)
	jeu.ui.montrer_pause(true)
	var avec: bool = jeu.ui._pause.carte_monde.visible and not jeu.ui._pause._commandes.visible
	# (la carte se dessine, de près puis de loin)
	await get_tree().process_frame
	jeu.ui._pause.carte_monde.loin = true
	jeu.ui._pause.carte_monde.queue_redraw()
	await get_tree().process_frame
	jeu.ui._pause.carte_monde.loin = false
	jeu.ui.montrer_pause(false)
	verif(vu_la and avec and Rp.vus.size() >= 8, "la carte faite, la pause la montre : ce qu'elle a parcouru du lieu (%d cases), pas le reste" % Rp.vus.size())

	# écrire, là où elle se tient : le même tout près est récrit, pas doublé ; un autre s'ajoute ; on le raye
	Rp.liste.clear()
	j.position = etabli.position + Vector2(-40.0, 10.0)
	var la: String = Rp.ici()
	var e1: bool = Rp.ecrire("camp")
	j.position += Vector2(-100.0, 0.0)
	var e2: bool = Rp.ecrire("camp")
	var recrit: bool = Rp.liste.size() == 1 and Rp.position(Rp.liste[0]).distance_to(j.position) < 1.0
	var camp: Vector2 = j.position
	j.position = camp + Vector2(900.0, 0.0)
	Rp.ecrire("eau")
	Rp.ecrire("camp")
	var trois: bool = Rp.liste.size() == 3
	var proche: int = Rp.par_distance()[0]
	var loin_: int = Rp.par_distance()[2]
	var dit_loin: String = Rp.dire_ou(Rp.liste[loin_])
	var dit_ici: String = Rp.dire_ou(Rp.liste[proche])
	var raye: bool = Rp.rayer(Rp.liste.find(Rp.liste.filter(func(r): return str(r["genre"]) == "eau")[0]))
	verif(la == "camp" and e1 and e2 and recrit and trois and dit_ici == "ici" and dit_loin.contains("pas") and dit_loin.contains("ouest") and raye and Rp.liste.size() == 2
		and Rp.liste.filter(func(r): return str(r["genre"]) == "eau").is_empty(),
		"la plume écrit là où elle se tient (près de l'établi : « %s ») ; le même tout près est récrit, pas doublé ; un repère loin d'elle est « %s » ; on le raye" % [la, dit_loin])

	# la page de la carte, depuis le sac : écrire ce qui est là, rayer
	var sac_la: bool = false
	jeu.ouvrir_page("sac")
	var sac = jeu.ui._pages.get("sac")
	if sac != null:
		for sec in sac._sections():
			for tu in sec["tuiles"]:
				if str(tu["cle"]) == "page:carte":
					sac_la = true
	jeu.fermer_page()
	jeu.ouvrir_page("carte")
	var pc = jeu.ui._pages.get("carte")
	var ouverte: bool = pc != null and pc.visible and jeu.page == "carte"
	var tuiles := 0
	var ecrite := ""
	var rayee := ""
	if pc != null:
		for sec in pc._sections():
			tuiles += sec["tuiles"].size()
		ecrite = pc._faire("ecrire:coffre")
		var cle_coffre: String = pc._cle_de(Rp.liste[Rp.liste.size() - 1])
		var fiche: Dictionary = pc._fiche_de(cle_coffre)
		if str(fiche.get("bouton", "")) == "Rayer":
			rayee = pc._faire(cle_coffre)
	jeu.fermer_page()
	verif(sac_la and ouverte and tuiles == 8 + 2 and ecrite == "Écrit" and rayee == "Rayé" and Rp.liste.size() == 2 and jeu.page == "",
		"le sac ouvre la page de la carte : huit repères à écrire, ceux qu'elle a écrits ; elle y écrit un coffre, puis le raye")

	# la tanière de la Noire, trouvée, s'écrit d'elle-même ; sans plume, non ; la partie gardée s'en souvient
	var tan: Vector2 = camp + Vector2(0.0, -1200.0)
	var ecrite_t: bool = Rp.noter_taniere(tan)
	A.objets["plume"] = 0
	var sans_plume_t: bool = not Rp.noter_taniere(tan + Vector2(800.0, 0.0))
	A.objets["plume"] = 1
	var photo: Dictionary = JSON.parse_string(JSON.stringify(Rp.photo()))
	var avant_l: Array = Rp.liste.duplicate(true)
	var avant_v: int = Rp.vus.size()
	Rp.vider()
	Rp.reprendre(photo)
	var reprise: bool = Rp.liste.size() == avant_l.size() and Rp.vus.size() == avant_v and str(Rp.liste[2]["genre"]) == "taniere" and Rp.position(Rp.liste[2]).distance_to(tan) < 0.2
	verif(ecrite_t and sans_plume_t and reprise, "la tanière de la Noire, trouvée, s'écrit d'elle-même sur la carte (pas sans la plume) ; la partie gardée retient les repères et ce qu'elle a parcouru")

	# (tout remis comme avant)
	A.poses.erase(etabli)
	etabli.queue_free()
	j.position = garde["p"]
	for k in inv.keys():
		inv[k] = garde["inv"].get(k, 0)
	A.objets = garde["objets"]
	Rp.liste = garde["liste"]
	Rp.vus = garde["vus"]
	jeu.noire.taniere_connue = garde["connue"]
	jeu.horloge = garde["h"]


# la partie sur le compte (scripts/session.gd, outils/sauvegarde.sql), contre un faux service (outils/faux-compte.js, lancé ici
# si node est là ; ou celui que donne LISIERE_SERVICE) : rien ne part sans compte ; connectée, la partie part (une partie nouvelle,
# puis la suite, au plus une fois par minute sauf « vite ») ; un autre appareil qui n'a pas lu la dernière révision ne l'écrase
# pas (conflit) ; celui qui l'a lue continue ; la plus récente se reprend ; une partie finie s'efface, et sans réseau cela attend
func _la_partie_sur_le_compte() -> void:
	print("La partie sur le compte")
	var S = jeu.session
	var garde := {"url": S.url, "jeton": S.jeton, "renouveau": S.renouveau, "expire": S.expire, "uid": S.uid, "email": S.email, "app": S._appareil}
	var pid := -1
	var service := OS.get_environment("LISIERE_SERVICE")
	if service == "":
		pid = OS.create_process("node", [ProjectSettings.globalize_path("res://outils/faux-compte.js"), str(_port(0))])
		if pid <= 0:
			print("  (node manque : la partie sur le compte n'est pas essayée)")
			return
		service = "http://127.0.0.1:%d" % _port(0)
	S.url = service
	var pret := false
	# (le monde attend pendant qu'on attend le faux service : la partie en pause, sinon la nuit continue et ses chasseurs avec ;
	# et l'on attend à l'horloge, pas en images : sans écran les images filent, et node met parfois quelques secondes à partir)
	var pause_c: bool = jeu.en_pause
	jeu.en_pause = true
	var depuis_c := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depuis_c < 20000:
		var r0: Dictionary = await S._http(service + "/__etat", null, HTTPClient.METHOD_GET, "")
		if r0["ok"]:
			pret = true
			break
		await get_tree().process_frame
	jeu.en_pause = pause_c
	if not pret:
		print("  (le faux service ne répond pas : la partie sur le compte n'est pas essayée)")
		S.url = garde["url"]
		if pid > 0:
			OS.kill(pid)
		return
	await S._http(service + "/__vider", {}, HTTPClient.METHOD_POST, "")
	var conflits := [0]
	var compter := func(): conflits[0] += 1
	S.partie_en_conflit.connect(compter)
	S.jeton = ""
	S.uid = ""
	var sans_compte: bool = not S.envoi_possible(true)
	var connexion: Dictionary = await S.connexion("ada@exemple.fr", "bon")
	var d: Dictionary = load("res://scripts/partie_gardee.gd").photo(jeu)
	var resume: Dictionary = load("res://scripts/partie_gardee.gd").resume_portail(jeu)
	var PG = load("res://scripts/partie_gardee.gd")

	# une partie nouvelle, puis la suite ; pas deux envois dans la minute, sauf « vite »
	S.partie_commence()
	var r1: Dictionary = await S.garder_partie(d.duplicate(true), resume, true)
	var attend: bool = not S.envoi_possible(false) and S.envoi_possible(true)
	var r2: Dictionary = await S.garder_partie(d.duplicate(true), resume, true)
	var etat: Dictionary = (await S._http(service + "/__etat", null, HTTPClient.METHOD_GET, ""))["donnees"]
	var gardee: Dictionary = etat.get("u-ada", {})
	verif(sans_compte and connexion["ok"] and S.connecte() and r1["ok"] and int(r1["donnees"]["rev"]) == 1 and attend and r2["ok"] and S.rev_partie == 2
		and int(gardee.get("rev", 0)) == 2 and int(gardee["donnees"]["jour"]) == int(jeu.jour) and str(gardee["resume"].get("nom", "")) != ""
		and int(gardee["resume"].get("jour", 0)) == int(jeu.jour) and gardee["resume"].has("nuits") and gardee["resume"].has("regions"),
		"sans compte, rien ne part ; connectée, la partie part sur le compte (révision %d), avec son résumé pour le portail (« %s, jour %d ») ; pas deux fois dans la minute, sauf à la pause" % [
		S.rev_partie, str(gardee.get("resume", {}).get("nom", "")), int(gardee.get("resume", {}).get("jour", 0))])

	# un autre appareil, qui n'a pas lu la dernière révision : il n'écrase pas ; celui qui l'a lue continue
	var ici: String = S.appareil()
	S._appareil = "autre-appareil"
	S.partie_reprise(-1)
	var r3: Dictionary = await S.garder_partie(d.duplicate(true), resume, true)
	var bloque: bool = str(r3.get("erreur", "")) == "conflit" and S.en_conflit and conflits[0] == 1 and not S.envoi_possible(true)
	S.partie_reprise(2)
	var d2: Dictionary = d.duplicate(true)
	d2["jour"] = int(jeu.jour) + 1
	d2["quand"] = int(d["quand"]) + 100
	var r4: Dictionary = await S.garder_partie(d2, resume, true)
	S._appareil = ici
	S.partie_reprise(2)
	var r5: Dictionary = await S.garder_partie(d.duplicate(true), resume, true)
	var lue: Dictionary = await S.partie_du_compte()
	var p = lue.get("partie")
	var reprend: bool = (typeof(p) == TYPE_DICTIONARY and int(p["rev"]) == 3 and PG.compte_plus_recent(d, p["donnees"]) and PG.compte_plus_recent({}, p["donnees"])
		and not PG.compte_plus_recent(d2.merged({"quand": int(d2["quand"]) + 1}, true), p["donnees"]) and not PG.compte_plus_recent(d, {"v": 99}))
	verif(bloque and r4["ok"] and int(r4["donnees"]["rev"]) == 3 and str(r5.get("erreur", "")) == "conflit" and reprend and conflits[0] == 2,
		"un autre appareil qui n'a pas lu la dernière révision n'écrase pas la partie (conflit, c'est dit) ; celui qui l'a lue continue (jour %d) ; à l'écran-titre, la plus récente se reprend" % int(d2["jour"]))

	# une partie finie s'efface du compte ; sans réseau, l'effacement attend, puis part
	S.partie_reprise(3)
	S._appareil = "autre-appareil"
	await S.oublier_partie()
	var effacee: bool = (await S.partie_du_compte()).get("partie") == null
	S.partie_commence()
	await S.garder_partie(d.duplicate(true), resume, true)
	S.url = "http://127.0.0.1:9"
	await S.oublier_partie()
	var en_attente: bool = FileAccess.file_exists(S.OUBLI)
	S.url = service
	var encore: bool = (await S.partie_du_compte()).get("partie") != null
	await S.renvoyer_oubli()
	var partie_apres = (await S.partie_du_compte()).get("partie")
	verif(effacee and en_attente and encore and partie_apres == null and not FileAccess.file_exists(S.OUBLI),
		"une partie finie s'efface du compte ; sans réseau, l'effacement attend sur l'appareil, et part à l'écran-titre")

	# (tout remis comme avant)
	S.partie_en_conflit.disconnect(compter)
	S.url = garde["url"]
	S.jeton = garde["jeton"]
	S.renouveau = garde["renouveau"]
	S.expire = garde["expire"]
	S.uid = garde["uid"]
	S.email = garde["email"]
	S._appareil = garde["app"]
	S.rev_partie = -1
	S.partie_nouvelle = false
	S.en_conflit = false
	S._ecrire()
	if pid > 0:
		OS.kill(pid)


# les lots pour Orvane (scripts/lots.gd), contre le faux Supabase d'Orvane (outils/faux-compte.js, orvane_deposer) : ce qui est
# compté se garde sur l'appareil à chaque sauvegarde, sans faire de lot ; un quart d'heure de jeu plus tard, il se clôt et part ;
# refusé, il attend sur l'appareil et repart avec le suivant ; connectée, le joueur est son compte (une empreinte) ; une bête
# apprivoisée est une capture, rendue aux siens une libération
func _les_lots(F: Dictionary) -> void:
	print("Les lots pour Orvane")
	var L = jeu.lots
	var S = jeu.session
	var E = jeu.elevage
	var A = jeu.atelier
	var garde := {"url": Orvane.supabase_url, "attente": Orvane._en_attente.duplicate(), "ev": Orvane._evenements.duplicate(true),
		"debut": Orvane._debut, "jeton": S.jeton, "uid": S.uid, "appris": jeu.appris.duplicate(), "licol": A.possede("licol")}
	var ferme: bool = not L.permis()
	var pid := OS.create_process("node", [ProjectSettings.globalize_path("res://outils/faux-compte.js"), str(_port(1))])
	if pid <= 0:
		print("  (node manque : les lots ne sont pas essayés)")
		return
	var service := "http://127.0.0.1:%d" % _port(1)
	var pret := false
	# (le monde attend déjà pendant qu'on attend le faux service, à l'horloge : voir « la partie sur le compte »)
	var pause_l: bool = jeu.en_pause
	jeu.en_pause = true
	var depuis_l := Time.get_ticks_msec()
	while Time.get_ticks_msec() - depuis_l < 20000:
		if (await S._http(service + "/__lots", null, HTTPClient.METHOD_GET, ""))["ok"]:
			pret = true
			break
		await get_tree().process_frame
	jeu.en_pause = pause_l
	if not pret:
		print("  (le faux service ne répond pas : les lots ne sont pas essayés)")
		OS.kill(pid)
		return
	Orvane.supabase_url = service
	L.vers = service
	Orvane._en_attente.clear()
	Orvane._evenements.clear()
	S.jeton = ""
	L.nouvelle_partie()
	# (le monde attend pendant qu'on parle au faux service : la partie en pause, comme quand on la quitte des yeux)
	var pause0: bool = jeu.en_pause
	jeu.en_pause = true
	var etat := "en partie : %s, santé %d, à terre : %s" % [jeu.en_partie, int(jeu.joueur.sante), jeu._mort >= 0.0]
	if not jeu.en_partie or jeu._mort >= 0.0:
		# (elle est tombée avant d'arriver ici : ce qui l'a prise, pour le retrouver)
		etat += " — « %s », la Noire : %s, acte %d, à %d pixels ; nuit %d, le jour à %.2f" % [jeu._titre_de_fin(), str(jeu.noire.etat), int(jeu.noire.acte),
			int(minf(jeu.noire.ou.distance_to(jeu.joueur.position), 99999.0)), int(jeu.nuits), jeu.jour_du_ciel()]

	# ce qui est compté se garde à chaque sauvegarde (toutes les vingt secondes), sans faire de lot
	Orvane.compter("essai-lot", "prairie", "rencontre", 2.0)
	jeu._garder(false)
	var f = JSON.parse_string(FileAccess.get_file_as_string("user://orvane.json"))
	var dans_le_fichier: bool = typeof(f) == TYPE_DICTIONARY and JSON.stringify(f.get("evenements", [])).contains("essai-lot")
	var r0: Array = await _lots_recus(service)
	verif(ferme and L.permis() and dans_le_fichier and Orvane.lots_en_attente() == 0 and Orvane.en_cours() == 1 and r0.is_empty(),
		"rien ne part d'une partie d'essai (sauf vers un faux Orvane) ; ce qui est compté se garde sur l'appareil à chaque sauvegarde, sans faire de lot (%s)" % etat)

	# un quart d'heure de jeu plus tard : un lot se clôt, et part
	L._clos_ms -= L.INTERVALLE
	jeu._garder(false)
	await _attendre_lots(L)
	var r1: Array = await _lots_recus(service)
	var lot1: Dictionary = r1[0]["lot"] if r1.size() == 1 else {}
	var deux := false
	for e in lot1.get("evenements", []):
		deux = deux or (str(e.get("taxon", "")) == "essai-lot" and str(e.get("action", "")) == "rencontre" and float(e.get("n", 0)) == 2.0)
	verif(r1.size() == 1 and L.recus_partie == 1 and L.clos_partie == 1 and Orvane.lots_en_attente() == 0 and Orvane.en_cours() == 0 and deux
		and str(lot1.get("monde", "")) == "orvane" and str(lot1.get("source", {}).get("jeu", "")) == "lisiere" and str(r1[0]["compte"]) == str(jeu.compte)
		and str(lot1.get("periode", {}).get("debut", "")) != "" and str(lot1.get("periode", {}).get("fin", "")).ends_with("Z") and str(r1[0]["cle"]) == Orvane.cle_jeu,
		"un quart d'heure de jeu plus tard, ce qui est compté se clôt en un lot et part : Orvane le reçoit (« lisiere », monde « orvane », 2 rencontres, sa période)")

	# refusé, un lot attend sur l'appareil ; il repart avec le suivant ; connectée, le joueur est son compte
	await S._http(service + "/__refuser", {}, HTTPClient.METHOD_POST, "")
	Orvane.compter("essai-lot", "prairie", "prelevement", 1.0, "", "", "", "piege")
	var n2: int = L.clore()
	await _attendre_lots(L)
	var refuse: bool = n2 == 1 and Orvane.lots_en_attente() == 1 and L.erreur.contains("trop de dépôts") and L.texte().contains("1 lot attend")
	var rien: int = L.clore()
	await _attendre_lots(L)
	await S._http(service + "/__accepter", {}, HTTPClient.METHOD_POST, "")
	S.jeton = "jeton:ada@exemple.fr"
	S.uid = "u-ada"
	Orvane.compter("essai-lot", "prairie", "rencontre", 1.0)
	L.clore()
	await _attendre_lots(L)
	var r2: Array = await _lots_recus(service)
	var c2: String = str(r2[2]["compte"]) if r2.size() == 3 else ""
	verif(refuse and rien == 0 and r2.size() == 3 and Orvane.lots_en_attente() == 0 and L.recus_partie == 3 and L.erreur == "" and str(r2[1]["compte"]) == c2
		and c2.begins_with("sv:") and not c2.contains("ada") and L.texte().contains("reçu 3 lots"),
		"refusé (« trop de dépôts »), un lot attend sur l'appareil, et repart avec le suivant ; connectée, le joueur est son compte, en empreinte (%s) ; la pause le dit" % c2)

	# une bête apprivoisée : une capture ; rendue aux siens : une libération (et la fin le dit)
	var espece: Dictionary = {}
	for e in F["proies_jour"] + F["proies_nuit"]:
		var b0 = _bete(e, "proie", jeu.joueur.position + Vector2(900.0, 0.0), {})
		var bonne: bool = E.apprivoisable(b0)
		_oter(b0)
		if bonne:
			espece = e
			break
	if espece.is_empty():
		print("  (aucune proie à quatre pattes dans ce lieu : la capture n'est pas essayée)")
	else:
		var b = _bete(espece, "proie", jeu.joueur.position + Vector2(40.0, 0.0), {})
		A.objets["licol"] = 1
		var apprivoisee: bool = E.apprivoiser(b)
		var capture: float = _compte(str(b.id), "capture")
		var liberee: bool = E.liberer(b)
		var dit: String = jeu._texte_appris()
		verif(apprivoisee and capture == 1.0 and liberee and _compte(str(b.id), "liberation") == 1.0 and int(jeu.appris.get("capture", 0)) == int(garde["appris"].get("capture", 0)) + 1
			and dit.contains("apprivoisée") and dit.contains("aux siens"),
			"une bête apprivoisée est une capture, pour Orvane ; rendue aux siens, une libération (« %s »)" % dit.trim_prefix(", "))
		_oter(b)

	# (tout remis comme avant)
	Orvane.supabase_url = garde["url"]
	L.vers = ""
	Orvane._en_attente.clear()
	Orvane._en_attente.append_array(garde["attente"])
	Orvane._evenements = garde["ev"]
	Orvane._debut = garde["debut"]
	Orvane.garder()
	S.jeton = garde["jeton"]
	S.uid = garde["uid"]
	jeu.appris = garde["appris"]
	A.objets["licol"] = garde["licol"]
	L.nouvelle_partie()
	jeu.en_pause = pause0
	OS.kill(pid)


# les ports des faux services (outils/faux-compte.js) : 8139 et 8140, ou à partir de LISIERE_PORTS (deux essais en même temps sur
# une machine : LISIERE_PORTS=8150 pour l'un)
func _port(i: int) -> int:
	var base := OS.get_environment("LISIERE_PORTS")
	return (int(base) if base.is_valid_int() else 8139) + i


func _lots_recus(service: String) -> Array:
	var r: Dictionary = await jeu.session._http(service + "/__lots", null, HTTPClient.METHOD_GET, "")
	return r["donnees"] if r["ok"] and typeof(r["donnees"]) == TYPE_ARRAY else []


func _attendre_lots(L) -> void:
	for i in 900:
		if not L.en_cours():
			return
		await get_tree().process_frame


# la botanique (scripts/botanique.gd) : les herbes, leurs vertus cachées, ce qu'on en apprend, ce qu'on en prépare
func _la_botanique(F: Dictionary) -> void:
	print("La botanique")
	var j = jeu.joueur
	var A = jeu.atelier
	var J = jeu.jardin
	var E = jeu.elevage
	var B = jeu.botanique
	var C = jeu.climat
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "p": j.position, "inv": j.inventaire.duplicate(), "sante": j.sante, "faim": j.faim, "peur": j.peur, "torche": j.torche,
		"pluie": C.pluie, "feux": jeu.feux.duplicate(), "regard": j.regard, "graine": B.graine, "savoir": B.savoir.duplicate(true), "connue": jeu.noire.taniere_connue}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	jeu.horloge = base + RR.DUREE * 0.3
	jeu.feux.clear()
	C.pluie = 0.0
	j.torche = 0.0
	A.commencer()
	E.vider()
	B.commencer(4242)
	var inv: Dictionary = j.inventaire
	var lieu: String = jeu.monde.lieu if B.FLORE.has(jeu.monde.lieu) else "foret"
	var ids: Array = B.especes(lieu)
	var par_vertu := {}
	for id in ids:
		par_vertu[B.vertu(id)] = id

	# l'herbier se tient : six herbes par lieu, six vertus, une chacune ; les indices vont par deux
	var bon := true
	for type in B.FLORE:
		var formes := {}
		var vertus := {}
		for id in B.especes(type):
			formes[B.forme_de(id)] = true
			vertus[B.vertu(id)] = true
			if not B.FORMES.has(B.forme_de(id)) or B.nom(id) == "" or not B.INDICES[B.vertu(id)].has(B.indice(id)):
				bon = false
		if formes.size() != 6 or vertus.size() != 6:
			bon = false
	var partage := {}
	for v in B.VERTUS:
		for i in B.INDICES[v]:
			partage[i] = int(partage.get(i, 0)) + 1
	for i in partage:
		if int(partage[i]) != 2:
			bon = false
	var autre = load("res://scripts/botanique.gd").new()
	autre.jeu = jeu
	var change := false
	for g in [1, 2, 3, 4, 5]:
		autre.graine = g
		autre._vertus = {}
		for id in ids:
			if autre.vertu(id) != B.vertu(id):
				change = true
	B.partie = B
	verif(bon and partage.size() == 6 and change, "chaque lieu a six herbes et six vertus, une chacune ; chaque indice est partagé par deux vertus ; d'une partie à l'autre, les vertus changent de plante")

	# le lieu en est semé
	var plants := 0
	var du_lieu := true
	var un_plant = null
	for o in jeu.monde.objets:
		if is_instance_valid(o) and str(o.genre) == "herbe":
			plants += 1
			if not ids.has(str(o.herbe)):
				du_lieu = false
			if un_plant == null and int(o.reste) > 0:
				un_plant = o
	verif(plants >= 30 and du_lieu and un_plant != null, "des herbes poussent dans le lieu : %d plants, tous de son herbier" % plants)

	# cueillir : dans le sac, et un indice, qui laisse deux vertus possibles (la vraie en est)
	var id0: String = str(un_plant.herbe)
	j.position = un_plant.position + Vector2(6.0, 4.0)
	# (le lieu est tiré au sort : rien d'autre à portée de main qu'« Agir » prendrait d'abord — une bête à frapper, un vestige
	# à fouiller, un arbre et ses fruits tombés, une fleur plus près, ce que le pays pose au sol)
	for b in get_tree().get_nodes_in_group("betes"):
		if b.position.distance_to(un_plant.position) < 300.0:
			_oter(b)
	for x in jeu.atelier.poses.duplicate():
		if is_instance_valid(x) and x.position.distance_to(un_plant.position) < 140.0:
			jeu.atelier.poses.erase(x)
			x.queue_free()
	for o in jeu.monde.autour(un_plant.position, 110.0):
		if o != un_plant:
			jeu.monde.retirer(o)
	var terrain_b = jeu.terrain
	jeu.terrain = null
	var sac_b: Dictionary = j.inventaire.duplicate()
	jeu.agir()
	jeu.terrain = terrain_b
	var c0: Array = B.candidates(id0)
	if not (B.possede(id0) == 1 and int(un_plant.reste) == 0):
		var pris := {}
		for k in j.inventaire:
			if int(j.inventaire[k]) != int(sac_b.get(k, 0)):
				pris[k] = int(j.inventaire[k]) - int(sac_b.get(k, 0))
		print("    (l'herbe « %s » : %d dans le sac, il en reste %d au plant ; « Agir » a donné %s ; autour : %s)" % [id0, B.possede(id0), int(un_plant.reste), str(pris),
			str(jeu.monde.autour(un_plant.position, 160.0).map(func(o): return str(o.genre)))])
	verif(B.possede(id0) == 1 and B.connue(id0) and int(un_plant.reste) == 0 and c0.size() == 2 and c0.has(B.vertu(id0)) and not B.sue(id0) and B.lignes(id0).size() >= 1,
		"« Agir » cueille une herbe : elle entre dans le sac et dans l'herbier, avec un indice (« %s ») qui laisse deux vertus possibles, dont la vraie" % str(B.DIT_INDICE[B.indice(id0)]))

	# les bêtes : celles qui broutent ne touchent ni à la vénéneuse, ni à l'âcre ; ce qu'on leur voit manger se retient
	var espece: Dictionary = {}
	for e in F["proies_jour"] + F["proies_nuit"]:
		var essai_b = _bete(e, "proie", j.position + Vector2(900.0, 0.0), {})
		var bonne: bool = E.apprivoisable(essai_b)
		_oter(essai_b)
		if bonne:
			espece = e
			break
	var herbe_sure = null
	var herbe_tue = null
	for o in jeu.monde.objets:
		if is_instance_valid(o) and str(o.genre) == "herbe" and int(o.reste) > 0:
			if B.se_broute(str(o.herbe)) and herbe_sure == null:
				herbe_sure = o
			if not B.se_broute(str(o.herbe)) and herbe_tue == null:
				herbe_tue = o
	if espece.is_empty() or herbe_sure == null or herbe_tue == null:
		print("  (pas de proie à quatre pattes, ou pas d'herbe des deux sortes dans ce lieu : le reste n'est pas essayé)")
	else:
		var id_sure: String = str(herbe_sure.herbe)
		j.position = herbe_sure.position + Vector2(300.0, 0.0)
		var brouteuse = _bete(espece, "proie", herbe_sure.position + Vector2(-20.0, 0.0), {})
		jeu.mangee(brouteuse, herbe_sure, 3.2)
		var vu: bool = bool(B.savoir.get(id_sure, {}).get("broutee", false)) and int(herbe_sure.reste) == 0
		var tentantes := true
		for o in jeu.monde.autour(herbe_tue.position, 150.0):
			if str(o.genre) == "herbe" and not B.se_broute(str(o.herbe)):
				brouteuse._tentation = null
		B.cueillie(id_sure)
		var apres: Array = B.candidates(id_sure)
		verif(vu and tentantes and apres.has(B.vertu(id_sure)) and not apres.has("veneneuse") and not apres.has("acre"),
			"une bête qui broute mange une herbe sous ses yeux : l'herbier le retient, elle n'est ni vénéneuse ni âcre (reste : %s)" % ", ".join(PackedStringArray(apres)))
		_oter(brouteuse)

	# par élimination : cinq vertus reconnues, la sixième se déduit sans y goûter
	B.commencer(4242)
	for k in 5:
		B._savoir_par(str(ids[k]), "goutee")
	B.cueillie(str(ids[5]))
	verif(B.sue(str(ids[5])) and str(B.savoir[ids[5]]["sue"]) == "deduite" and B.candidates(str(ids[5])) == [B.vertu(str(ids[5]))],
		"cinq herbes reconnues dans un lieu : la sixième se déduit, sans y goûter")

	# goûter : on sait aussitôt, et on en paie le prix
	B.commencer(4242)
	for id in ids:
		inv[B.cle(id)] = 6
	j.sante = 60.0
	j.peur = 40.0
	B.gouter(str(par_vertu["cicatrisante"]))
	var soigne: bool = j.sante == 68.0
	B.gouter(str(par_vertu["apaisante"]))
	var calme: bool = j.peur == 28.0
	B.gouter(str(par_vertu["veneneuse"]))
	var s0: float = j.sante
	for i in 10:
		B.maj(0.5)
	var empoisonnee: bool = B.poison > 0.0 and j.sante < s0 - 6.0 and B.sue(str(par_vertu["veneneuse"]))
	# (le poison fait dévier ses pas : on l'ôte pour mesurer la torpeur seule)
	B.poison = 0.0
	B.gouter(str(par_vertu["somnifere"]))
	# (le même pas, du même endroit dégagé, avec et sans la torpeur)
	var depart: Vector2 = j.position
	for k in 80:
		var q := Vector2(-320.0 + 80.0 * (k % 9), -320.0 + 80.0 * (k / 9))
		if jeu.monde.repousser(q, 8.0).distance_to(q) < 0.5 and jeu.monde.repousser(q + Vector2(90.0, 0.0), 8.0).distance_to(q + Vector2(90.0, 0.0)) < 0.5 and float(C.eau(q)) < 0.05:
			depart = q
			break
	j.position = depart
	j.atelier = ""
	j.deplacer(Vector2(1, 0), 0.5, jeu.monde)
	var lente: float = j.position.x - depart.x
	B.torpeur = 0.0
	j.position = depart
	j.deplacer(Vector2(1, 0), 0.5, jeu.monde)
	var vive: float = j.position.x - depart.x
	B.gouter(str(par_vertu["voyante"]))
	B.gouter(str(par_vertu["acre"]))
	verif(soigne and calme and empoisonnee and lente < vive * 0.7 and B.visions > 0.0 and B.dernier_gout == "acre" and B.possede(str(par_vertu["acre"])) == 5,
		"goûtées : la cicatrisante soigne un peu, l'apaisante calme, la vénéneuse empoisonne (la santé fond), la somnifère alourdit le pas (%d %% de l'allure), la voyante donne des visions"
		% int(100.0 * lente / maxf(vive, 0.01)))

	# préparer : il faut l'outil, le feu, l'eau ; le baume chasse le poison
	inv["eau"] = 3
	inv["fibre"] = 3
	inv["viande"] = 2
	inv["baies"] = 4
	var sans_outil: String = B.empeche_preparer("baume")
	A.objets["popote"] = 1
	var sans_feu: String = B.empeche_preparer("baume")
	var feu = jeu.Feu.new()
	feu.jeu = jeu
	feu.position = j.position + Vector2(40.0, 0.0)
	jeu.monde.add_child(feu)
	jeu.feux.append(feu)
	var fait: bool = B.preparer("baume")
	var sans_mortier: String = B.empeche_preparer("botte")
	A.objets["mortier"] = 1
	var botte: bool = B.preparer("botte") and B.preparer("tisane") and B.preparer("philtre") and B.preparer("appat_poison") and B.preparer("appat_dormant")
	j.sante = 30.0
	B.poison = 9.0
	var panse: bool = B.utiliser("baume")
	verif(sans_outil.contains("popote") and sans_feu.contains("feu") and fait and B.possede(str(par_vertu["cicatrisante"])) == 3 and sans_mortier.contains("mortier") and botte
		and int(inv["eau"]) == 0 and int(inv["fibre"]) == 2 and int(inv["viande"]) == 1 and int(inv["baies"]) == 2 and panse and j.sante == 75.0 and B.poison == 0.0 and int(inv["baume"]) == 0,
		"les décoctions se font à la popote, sur un feu, avec de l'eau ; le reste au mortier ; le baume rend 45 de santé et chasse le poison")

	# la tisane, le philtre
	j.peur = 80.0
	B.utiliser("tisane")
	var peur_t: float = j.peur
	for i in 10:
		B.maj(1.0)
	var peur_calme: float = j.peur
	jeu.noire.taniere_connue = false
	var philtre: bool = B.utiliser("philtre")
	verif(peur_t == 30.0 and peur_calme < 20.0 and philtre and B.voyance > 0.0 and (jeu.noire.taniere_connue or Vector2(jeu.noire.taniere) == Vector2.ZERO),
		"la tisane ôte 50 de peur et la tient basse ; le philtre ouvre la voyance, et dit où dort la Noire")

	# la botte âcre : sa fumée tient les chasseurs moitié plus loin, trois quarts de minute
	var chasseur = _bete(F["chasseurs_nuit"][0], "chasseur", feu.position + Vector2(300.0, 0.0), {})
	var avant_f: float = chasseur._lisiere()
	var jetee: bool = B.utiliser("botte")
	var pendant: float = chasseur._lisiere()
	for i in 50:
		B.maj(1.0)
	var apres_f: float = chasseur._lisiere()
	verif(jetee and absf(pendant - avant_f * B.GARDE) < 0.01 and absf(apres_f - avant_f) < 0.01 and B.fumee(feu) == 0.0,
		"une botte âcre jetée au feu : les chasseurs s'en tiennent %.1f fois plus loin, puis la fumée retombe" % (pendant / maxf(avant_f, 0.01)))

	# l'appât empoisonné : ce qui chasse vient le manger, et en meurt
	j.position = feu.position + Vector2(-500.0, 0.0)
	j.regard = 1.0
	var pose: bool = B.utiliser("appat_poison")
	var appat = A.poses[A.poses.size() - 1]
	chasseur.position = appat.position + Vector2(140.0, 20.0)
	var pv0: float = chasseur.pv
	var chassees0: int = jeu.chassees
	for i in 400:
		if is_instance_valid(chasseur) and chasseur.is_in_group("betes") and chasseur.pv > 0.0:
			chasseur._conduire(0.1)
	var mort: bool = not is_instance_valid(chasseur) or chasseur.pv <= 0.0
	verif(pose and not A.poses.has(appat) and mort and pv0 > 0.0 and jeu.chassees == chassees0,
		"l'appât empoisonné : un chasseur vient le manger, s'en va, et le poison l'éteint (ce n'est pas une chasse)%s" % ("" if mort and not A.poses.has(appat) and jeu.chassees == chassees0
		else " [posé %s, mangé %s, mort %s, pv %.1f sur %.1f, empoisonné %.1f, chassées %d → %d]" % [pose, not A.poses.has(appat), mort, chasseur.pv if is_instance_valid(chasseur) else -1.0, pv0,
		chasseur.empoisonnee if is_instance_valid(chasseur) else -1.0, chassees0, jeu.chassees]))
	_oter(chasseur)

	# l'appât dormant : une bête qui broute s'endort dessus ; on lui passe le licol ; un coup la réveille
	if not espece.is_empty():
		var pose2: bool = B.utiliser("appat_dormant")
		var appat2 = A.poses[A.poses.size() - 1]
		j.position = appat2.position + Vector2(-600.0, 0.0)
		var dormeuse = _bete(espece, "proie", appat2.position + Vector2(120.0, 10.0), {})
		for i in 150:
			dormeuse._conduire(0.1)
		var dort: bool = dormeuse.endormie > 0.0 and dormeuse.couchee > 0.9 and dormeuse.yeux_clos > 0.9
		j.position = dormeuse.position + Vector2(-30.0 - dormeuse.largeur * 0.25, 0.0)
		dormeuse._conduire(0.1)
		var a_portee: bool = E.a_apprivoiser() == dormeuse and str(dormeuse.etat) != "fuit"
		dormeuse.blesser(1.0, j.position)
		verif(pose2 and dort and a_portee and dormeuse.endormie == 0.0,
			"l'appât dormant : la bête qui le mange s'endort, couchée, les yeux clos ; on l'approche pour lui passer un licol ; un coup la réveille")
		_oter(dormeuse)

		# le jardin : une herbe reconnue se sème de ses plants ; les bêtes ne broutent pas la vénéneuse
		A.objets["houe"] = 1
		j.position = feu.position + Vector2(0.0, 420.0)
		var beche := false
		for k in 60:
			j.position = feu.position + Vector2(-600.0 + 80.0 * (k % 12), 300.0 + 80.0 * (k / 12))
			if J.empeche_becher() == "":
				beche = J.becher()
				break
		var carre = J.carres()[0] if J.carres().size() >= 1 else null
		var tue: String = str(par_vertu["veneneuse"])
		var sure: String = str(par_vertu["cicatrisante"])
		var avant_semis: int = B.possede(tue)
		var seme: bool = carre != null and J.semer(carre, tue)
		var reste_h: int = B.possede(tue)
		var pas_tentee := false
		var recolte := false
		if seme:
			carre.etat["stade"] = 2.0
			carre.etat["eau"] = 1.0
			var b3 = _bete(espece, "proie", carre.position + Vector2(100.0, 0.0), {})
			pas_tentee = J.tentation(b3) == null
			carre.etat["culture"] = sure
			var tentee2: bool = J.tentation(b3) == carre
			pas_tentee = pas_tentee and tentee2
			_oter(b3)
			carre.etat["culture"] = tue
			carre.etat["stade"] = 3.0
			j.position = carre.position + Vector2(-30.0, 0.0)
			recolte = J.recolter(carre) and B.possede(tue) == reste_h + B.RECOLTE_JARDIN
		verif(beche and seme and reste_h == avant_semis - J.GRAINES and pas_tentee and recolte,
			"une herbe reconnue se sème de deux de ses plants, et un carré mûr en rend %d ; les bêtes ne touchent pas à un carré de vénéneuse" % B.RECOLTE_JARDIN)

	# la partie gardée
	var photo: Dictionary = JSON.parse_string(JSON.stringify(B.photo()))
	var B2 = load("res://scripts/botanique.gd").new()
	B2.jeu = jeu
	B2.reprendre(photo)
	var memes_b: bool = B2.graine == B.graine and B2.savoir.size() == B.savoir.size()
	for id in ids:
		if B2.vertu(id) != B.vertu(id) or B2.sue(id) != B.sue(id) or B2.indice(id) != B.indice(id):
			memes_b = false
	B.partie = B
	verif(memes_b, "la partie gardée retient les vertus tirées et ce qu'elle sait des herbes")

	# (tout remis comme avant)
	jeu.feux.erase(feu)
	feu.queue_free()
	for s3 in A.poses:
		if is_instance_valid(s3):
			s3.queue_free()
	A.commencer()
	E.vider()
	B.commencer(int(garde["graine"]))
	B.savoir = garde["savoir"]
	for k in inv.keys():
		if garde["inv"].has(k):
			inv[k] = int(garde["inv"][k])
		else:
			inv.erase(k)
	for f in garde["feux"]:
		jeu.feux.append(f)
	jeu.horloge = garde["h"]
	jeu.noire.taniere_connue = garde["connue"]
	j.position = garde["p"]
	j.regard = garde["regard"]
	j.sante = garde["sante"]
	j.faim = garde["faim"]
	j.peur = garde["peur"]
	j.torche = garde["torche"]
	C.pluie = garde["pluie"]


func _bete(e: Dictionary, role: String, p: Vector2, memoire: Dictionary):
	var x: Dictionary = e.duplicate()
	if not x.has("ecart"):
		x["ecart"] = 0.0
	var m: Dictionary = Orvane.DISPOSITIONS_NEUTRES.duplicate()
	m.merge(memoire, true)
	x["memoire"] = m
	return jeu._creer(x, role, p)


func _oter(b) -> void:
	if is_instance_valid(b):
		b.remove_from_group("betes")
		b.queue_free()


# à quelle distance de la veilleuse une proie s'enfuit : on la rapproche, deux pixels à la fois, jusqu'à ce qu'elle parte
func _fuite(e: Dictionary, memoire: Dictionary, en_marche: bool) -> float:
	var j = jeu.joueur
	j.en_mouvement = en_marche
	var b = _bete(e, "proie", j.position + Vector2(700.0, 0.0), memoire)
	var d := 700.0
	while d > 0.0 and b.etat != "fuit":
		d -= 2.0
		b.position = j.position + Vector2(d, 0.0)
		b._proie(0.0)
	_oter(b)
	return d


# un chasseur devant un feu où la veilleuse se tient, tant de secondes : au plus près (en parts du rayon), et où il se tient
# une fois posté, la seconde moitié du temps (la veilleuse le regarde : il ne gagne rien dans son dos) ; la part de ce temps
# qu'il passe posté ; et la bête, encore là (à ôter)
func _siege(e: Dictionary, memoire: Dictionary, feu, secondes: float) -> Dictionary:
	var j = jeu.joueur
	var b = _bete(e, "chasseur", feu.position + Vector2(feu.rayon() + 260.0, 40.0), memoire)
	var r: float = feu.rayon()
	var pres := INF
	var somme := 0.0
	var k := 0
	var somme_p := 0.0
	var k_p := 0
	var pas := int(secondes / 0.05)
	for i in pas:
		j.regard = 1.0 if b.position.x >= j.position.x else -1.0
		b._conduire(0.05)
		var ici: Vector2 = b.position - feu.position
		pres = minf(pres, ici.length() / r)
		if i >= pas / 2:
			somme += ici.length() / r
			k += 1
			if b.poste > 0.5:
				somme_p += ici.length() / r
				k_p += 1
	return {"pres": pres, "moyenne": somme_p / k_p if k_p > 0 else somme / maxf(k, 1), "poste": float(k_p) / maxf(k, 1), "bete": b}


# l'affût : ce que font les chasseurs autour d'un feu où la veilleuse se tient (scripts/bete.gd, _chasseur ; scripts/affut.gd).
# Ce qui tient au hasard est fixé : la veilleuse regarde celui qu'on mesure (sauf quand on dit qu'elle tourne le dos), sa
# patience est posée à la main, et aucun ne mord (on s'arrête avant)
func _l_affut(e: Dictionary, f) -> void:
	var Affut := load("res://scripts/affut.gd")
	var RR := load("res://scripts/regles.gd")
	var j = jeu.joueur
	var centre: Vector2 = f.position
	var bois0: float = f.bois
	var regard0: float = j.regard
	j.torche = 0.0
	# (un chasseur resté là de la nuit compterait dans la meute, sans que personne le fasse marcher)
	for x in jeu.get_tree().get_nodes_in_group("betes"):
		if str(x.role) == "chasseur":
			_oter(x)
	# --- un seul, devant un feu haut : il vient voir, se poste, et ne bouge plus
	f.bois = 100.0
	j.position = centre + Vector2(0, 30)
	var b = _bete(e, "chasseur", centre + Vector2(f.rayon() + 260.0, 40.0), {})
	b.audace = 0.3
	var t_poste := -1.0
	for i in 800:
		j.regard = 1.0 if b.position.x >= j.position.x else -1.0
		b._conduire(0.05)
		if b._af == Affut.POSTE and b.poste >= 1.0:
			t_poste = i * 0.05
			break
	b._poste_t = 999.0
	var chemin := 0.0
	var avant: Vector2 = b.position
	for i in 600:
		j.regard = 1.0 if b.position.x >= j.position.x else -1.0
		b._conduire(0.05)
		chemin += b.position.distance_to(avant)
		avant = b.position
	var manege: float = 0.5 * b.vitesse * 30.0
	var d_poste: float = b.position.distance_to(centre)
	var de_j: Vector2 = (b.position - j.position).abs()
	verif(t_poste >= 0.0 and chemin < manege * 0.05 and b.poste >= 1.0 and b.detourne <= 0.0,
		"l'affût : il vient voir, puis se poste dans le noir (en %d secondes) ; posté, il ne bouge presque plus : %d pixels en trente secondes (le manège lui en faisait faire %d)" % [
			int(t_poste), int(chemin), int(manege)])
	verif(d_poste - b.largeur * 0.5 >= f.rayon() and f.eclaire(b.position) <= 0.0 and Affut.hors_ecran(jeu, b.position) <= 0.0,
		"son poste est hors de la lumière (à %.2f du rayon du feu : on ne voit que ses yeux) et dans l'écran (à %d pixels de côté et %d de haut de la veilleuse, qui en voit %d et %d)" % [
			d_poste / f.rayon(), int(de_j.x), int(de_j.y), int(Affut.demi_ecran(jeu).x), int(Affut.demi_ecran(jeu).y)])
	# --- l'impatience : il se détourne, passe par le noir, au large, et reparaît ailleurs
	var a0: float = (b.position - centre).angle()
	b._poste_t = 0.0
	var detourne_max := 0.0
	var large := 0.0
	var pres := INF
	var t_change := -1.0
	for i in 1200:
		j.regard = 1.0 if b.position.x >= j.position.x else -1.0
		b._conduire(0.05)
		var ici: Vector2 = b.position - centre
		detourne_max = maxf(detourne_max, b.detourne)
		large = maxf(large, ici.length())
		pres = minf(pres, ici.length() / f.rayon())
		if i > 4 and b._af == Affut.POSTE and b.poste >= 1.0:
			t_change = i * 0.05
			break
	b._poste_t = 999.0
	var tourne := absf(wrapf((b.position - centre).angle() - a0, -PI, PI))
	verif(t_change > 0.0 and detourne_max >= 1.0 and b.detourne <= 0.0 and tourne >= 0.8 and large > d_poste + 0.15 * f.rayon() and pres >= 1.0,
		"impatient, il change de poste : il se détourne (on le perd), passe par le noir, au large (jusqu'à %.2f du rayon, jamais dans la lumière : %.2f au plus près), et reparaît %d degrés plus loin, %d secondes après" % [
			large / f.rayon(), pres, int(rad_to_deg(tourne)), int(t_change)])
	# --- la feinte (forcée : elle est rare) : quelques pas vifs jusqu'à la lisière, un grondement, et retour
	var d_avant: float = b.position.distance_to(centre)
	b._af = Affut.FEINTE
	b._af_t = 0.0
	var pres_f := INF
	var gronde := false
	for i in 600:
		j.regard = 1.0 if b.position.x >= j.position.x else -1.0
		b._conduire(0.05)
		pres_f = minf(pres_f, b.position.distance_to(centre) / f.rayon())
		gronde = gronde or b._af == Affut.GRONDE
		if gronde and b._af == Affut.POSTE and b.poste >= 1.0:
			break
	verif(gronde and pres_f >= 0.78 and pres_f <= 0.9 and absf(b.position.distance_to(centre) - d_avant) < 10.0 and b.poste >= 1.0,
		"la feinte : quelques pas vifs jusqu'à la lisière (%.2f du rayon, pas plus près), un grondement, et il retourne à son poste" % pres_f)
	_oter(b)
	# --- à trois, autour d'un feu bas : ils ne tiennent pas le même côté
	f.bois = 20.0
	j.position = centre
	var r: float = f.rayon()
	var meute: Array = []
	for i in 3:
		var m = _bete(e, "chasseur", centre + Vector2(r + 300.0 + 30.0 * i, -60.0 + 40.0 * i), {})
		m.audace = 0.3
		meute.append(m)
	var pres3 := INF
	for i in 1200:
		for m in meute:
			j.regard = 1.0 if m.position.x >= j.position.x else -1.0
			m._conduire(0.05)
			if m._af == Affut.POSTE:
				m._poste_t = 999.0
			pres3 = minf(pres3, m.position.distance_to(centre) / r)
		if meute.all(func(m): return m._af == Affut.POSTE and m.poste >= 1.0):
			break
	var ecarts: Array = []
	for i in 3:
		ecarts.append(absf(wrapf((meute[i].position - centre).angle() - (meute[(i + 1) % 3].position - centre).angle(), -PI, PI)))
	var noir: bool = meute.all(func(m): return f.eclaire(m.position) <= 0.0 and Affut.hors_ecran(jeu, m.position) <= 0.0)
	verif(meute.all(func(m): return m.poste >= 1.0) and ecarts.min() >= 0.7 and noir and pres3 >= 0.78,
		"à trois autour d'un feu bas, ils ne tiennent pas le même côté : %d, %d et %d degrés de l'un à l'autre, tous postés hors de la lumière et dans l'écran (au plus près : %.2f du rayon)" % [
			int(rad_to_deg(ecarts[0])), int(rad_to_deg(ecarts[1])), int(rad_to_deg(ecarts[2])), pres3])
	# --- le feu baisse : le cercle se resserre ; une bûche : ils reculent
	var d_haut: Array = meute.map(func(m): return m.position.distance_to(centre))
	f.bois = 5.0
	var pres4 := INF
	for i in 200:
		for m in meute:
			j.regard = 1.0 if m.position.x >= j.position.x else -1.0
			m._conduire(0.05)
			pres4 = minf(pres4, m.position.distance_to(centre) / f.rayon())
	var d_bas: Array = meute.map(func(m): return m.position.distance_to(centre))
	var r_bas: float = f.rayon()
	f.bois = 20.0
	for i in 200:
		for m in meute:
			j.regard = 1.0 if m.position.x >= j.position.x else -1.0
			m._conduire(0.05)
	var resserre := true
	var recule := true
	for i in 3:
		resserre = resserre and d_bas[i] < d_haut[i] - 15.0
		recule = recule and meute[i].position.distance_to(centre) > d_bas[i] + 15.0
	verif(resserre and recule and pres4 >= 0.78 and meute.all(func(m): return m.poste >= 1.0),
		"le feu baisse (son rayon passe de %d à %d pixels) : ils se rapprochent d'autant (de %d, %d et %d pixels), sans entrer dans sa lumière (%.2f du rayon au plus près) ; une bûche : ils reculent" % [
			int(r), int(r_bas), int(d_haut[0] - d_bas[0]), int(d_haut[1] - d_bas[1]), int(d_haut[2] - d_bas[2]), pres4])
	# --- le dos tourné : celui qu'elle ne regarde pas gagne quelques pas ; elle se retourne, il se fige
	var m0 = meute[0]
	for m in meute:
		if absf(m.position.x - j.position.x) > absf(m0.position.x - j.position.x):
			m0 = m
	var cote := signf(m0.position.x - j.position.x)
	var d0: float = m0.position.distance_to(centre)
	var pres5 := INF
	j.regard = -cote
	for i in 240:
		for m in meute:
			m._conduire(0.05)
			pres5 = minf(pres5, m.position.distance_to(centre) / r)
	var gagne: float = d0 - m0.position.distance_to(centre)
	j.regard = cote
	m0._conduire(0.05)
	var la: Vector2 = m0.position
	for i in 30:
		m0._conduire(0.05)
	var bouge: float = m0.position.distance_to(la)
	verif(gagne >= 10.0 and bouge < 0.5 and pres5 >= 0.78,
		"elle a le dos tourné : celui qu'elle ne regarde pas gagne %d pixels vers la lisière (%.2f du rayon au plus près) ; elle se retourne, il se fige (%.1f pixel en une seconde et demie)" % [
			int(gagne), pres5, bouge])
	# --- elle marche sur lui, dans la lumière : il recule, se détourne, et va se poster ailleurs
	for i in 160:
		for m in meute:
			j.regard = 1.0 if m.position.x >= j.position.x else -1.0
			m._conduire(0.05)
	var m1 = meute[1]
	var a1: float = (m1.position - centre).angle()
	var parti := false
	for i in 12:
		j.position += Vector2.from_angle(a1) * RR.VITESSE * 0.05
		j.regard = 1.0 if m1.position.x >= j.position.x else -1.0
		m1._conduire(0.05)
		parti = parti or m1._af == Affut.CHANGE
	var dans_la_lumiere: bool = jeu.feu_qui_protege(j.position) == f
	j.position = centre
	var detourne1 := 0.0
	for i in 1200:
		j.regard = 1.0 if m1.position.x >= j.position.x else -1.0
		m1._conduire(0.05)
		detourne1 = maxf(detourne1, m1.detourne)
		if m1._af == Affut.POSTE and m1.poste >= 1.0:
			break
	m1._poste_t = 999.0
	var tourne1 := absf(wrapf((m1.position - centre).angle() - a1, -PI, PI))
	# (son nouveau poste est à 0,8 radian ou plus de là où il était quand il l'a choisi, scripts/affut.gd ; on le mesure ici
	# depuis là où il était avant qu'elle marche sur lui : à quelques degrés près, donc)
	verif(parti and dans_la_lumiere and detourne1 >= 1.0 and tourne1 >= 0.7 and m1.poste >= 1.0,
		"elle marche sur lui sans sortir de la lumière : il recule, se détourne, et va se poster ailleurs (%d degrés plus loin)" % int(rad_to_deg(tourne1)))
	# --- elle sort de la lumière : ils viennent, de leurs postes, l'un après l'autre (on s'arrête avant la morsure)
	for i in 100:
		for m in meute:
			j.regard = 1.0 if m.position.x >= j.position.x else -1.0
			m._conduire(0.05)
	# (par le plus grand vide entre deux d'entre eux : aucun n'est à deux pas de là où elle sort)
	var angles: Array = meute.map(func(m): return (m.position - centre).angle())
	angles.sort()
	var par := 0.0
	var vide := 0.0
	for i in 3:
		var g := fposmod(angles[(i + 1) % 3] - angles[i], TAU)
		if g > vide:
			vide = g
			par = angles[i] + g * 0.5
	j.position = centre + Vector2.from_angle(par) * (r * 0.85 + 40.0)
	var d_sortie: Array = meute.map(func(m): return m.position.distance_to(j.position))
	var departs: Array = [-1.0, -1.0, -1.0]
	var arrives := 0
	for i in 200:
		for k in 3:
			var m = meute[k]
			var d: float = m.position.distance_to(j.position)
			if d < 110.0:
				continue
			m._conduire(0.05)
			if departs[k] < 0.0 and d < d_sortie[k] - 6.0:
				departs[k] = i * 0.05
	for k in 3:
		if meute[k].position.distance_to(j.position) < d_sortie[k] - 50.0 or meute[k].position.distance_to(j.position) < 115.0:
			arrives += 1
	var tries: Array = departs.duplicate()
	tries.sort()
	verif(tries[0] >= 0.0 and tries[0] < 1.0 and tries[1] - tries[0] >= 0.25 and tries[2] - tries[1] >= 0.25 and tries[2] < 5.0 and arrives == 3,
		"elle sort de la lumière : ils viennent, de leurs postes, l'un après l'autre (le premier après %.1f s, puis à %.1f et %.1f s)" % [tries[0], tries[1], tries[2]])
	for m in meute:
		_oter(m)
	f.bois = bois0
	j.position = centre + Vector2(0, 30)
	j.regard = regard0


# un chasseur d'audace 0,5 dans le noir, face à la torche, tant de secondes : au plus près (pixels), où il se tient la seconde
# moitié du temps, quand il s'annonce, quand il mord (-1 : jamais), ses morsures ; et la bête
func _face_a_la_torche(e: Dictionary, memoire: Dictionary, secondes: float) -> Dictionary:
	var j = jeu.joueur
	j.torche = 75.0
	j.sante = 100.0
	# (elle lui fait face : tenu, il ira chercher son dos)
	j.regard = 1.0
	var b = _bete(e, "chasseur", j.position + Vector2(380.0, 0.0), {})
	# (la même audace de plan pour tous, puis ce que la population a appris : bete.gd, _apprendre)
	b.audace = 0.5
	var m: Dictionary = Orvane.DISPOSITIONS_NEUTRES.duplicate()
	m.merge(memoire, true)
	b._apprendre(m)
	var pres := INF
	var somme := 0.0
	var k := 0
	var annonce := -1.0
	var morsure := -1.0
	var morsures := 0
	var pas := int(secondes / 0.05)
	# (dans la seconde moitié, tenu : combien de fois il fait volte-face, combien de fois il passe d'avancer à reculer)
	var voltes := 0
	var va_et_vient := 0
	var regard_avant: float = b.regard
	var d_avant := INF
	var sens_avant := 0.0
	for i in pas:
		var sante: float = j.sante
		b._conduire(0.05)
		var d: float = b.position.distance_to(j.position)
		pres = minf(pres, d)
		if i >= pas / 2:
			somme += d
			k += 1
			if b.regard != regard_avant:
				voltes += 1
			var sens := signf(d - d_avant) if absf(d - d_avant) > 0.05 else sens_avant
			if sens != sens_avant and sens_avant != 0.0:
				va_et_vient += 1
			sens_avant = sens
		regard_avant = b.regard
		d_avant = d
		if annonce < 0.0 and b._presage > 0.0:
			annonce = i * 0.05
		if j.sante < sante:
			morsures += 1
			if morsure < 0.0:
				morsure = i * 0.05
			j.sante = 100.0
	j.torche = 0.0
	return {"pres": pres, "moyenne": somme / maxf(k, 1), "annonce": annonce, "morsure": morsure, "morsures": morsures, "bete": b,
		"voltes": voltes, "va_et_vient": va_et_vient, "derriere": (b.position.x - j.position.x) * j.regard < 0.0 and b.poste >= 0.99}


# un rôdeur d'audace 0,5 tenu à cette distance de la veilleuse, une minute au plus : quand il s'arrête pour guetter, quand il
# charge (-1 : jamais), et combien de temps sa charge doit durer
func _charge(e: Dictionary, memoire: Dictionary, distance: float) -> Dictionary:
	var out := {"guet": -1.0, "charge": -1.0, "duree": 0.0}
	if e.is_empty():
		return out
	var j = jeu.joueur
	var b = _bete(e, "rodeur", j.position + Vector2(distance, 0.0), {})
	b.audace = 0.5
	var m: Dictionary = Orvane.DISPOSITIONS_NEUTRES.duplicate()
	m.merge(memoire, true)
	b._apprendre(m)
	for i in 1200:
		b.position = j.position + Vector2(distance, 0.0)
		b._conduire(0.05)
		if out["guet"] < 0.0 and b.etat == "guet":
			out["guet"] = i * 0.05
		if b.etat == "attaque":
			out["charge"] = i * 0.05
			out["duree"] = b._duree
			break
	_oter(b)
	return out


# une proie dont la veilleuse s'approche, deux pixels à la fois (quarante pixels par seconde) : à quelle distance elle s'arrête
# pour faire front (-1 : jamais), à quelle distance elle charge (-1 : jamais) et pour combien de temps, à quelle distance elle
# s'enfuit (-1 : jamais) ; et la bête, encore là (à ôter)
func _front(e: Dictionary, memoire: Dictionary, masse: float, ecart: float = 0.0) -> Dictionary:
	var out := {"front": -1.0, "charge": -1.0, "fuite": -1.0, "duree": 0.0, "portee": 0.0, "bete": null}
	var j = jeu.joueur
	j.en_mouvement = true
	var x: Dictionary = e.duplicate()
	x["masse"] = masse
	x["ecart"] = ecart
	var b = _bete(x, "proie", j.position + Vector2(700.0, 0.0), memoire)
	out["portee"] = b._portee_front()
	var d := 700.0
	while d > 20.0:
		d -= 2.0
		b.position = j.position + Vector2(d, 0.0)
		b._conduire(0.05)
		if out["front"] < 0.0 and b.etat == "front":
			out["front"] = d
		if b.etat == "attaque":
			out["charge"] = d
			out["duree"] = b._duree
			break
		if b.etat == "fuit":
			out["fuite"] = d
			break
	out["bete"] = b
	return out


# combien de fois cette action est comptée pour Orvane, pour cette lignée (et ce moyen, s'il est dit)
func _compte(id: String, action: String, moyen: String = "") -> float:
	var n := 0.0
	for e in Orvane._evenements.values():
		if str(e.get("taxon", "")) == id and str(e.get("action", "")) == action and (moyen == "" or str(e.get("moyen", "")) == moyen):
			n += float(e["n"])
	return n


func _la_memoire(F: Dictionary, f) -> void:
	print("5 bis. La mémoire")
	var j = jeu.joueur
	var D := load("res://scripts/donnees.gd")
	# (la partie telle qu'elle est : tout revient à sa place après)
	var garde := {"p": j.position, "torche": j.torche, "peur": j.peur, "lance": j.lance, "marche": j.en_mouvement, "bois": f.bois,
		"sac": int(j.inventaire["bois"]), "horloge": jeu.horloge, "nuits": jeu.nuits, "monde": Orvane.instantane.get("monde", {}),
		"appris": jeu.appris.duplicate()}
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		_oter(b)
	jeu.horloge = jeu.jour * 240.0 - 240.0 * jeu.part_nuit + 2.0
	# (la première nuit passée : les dispositions comptent en entier)
	jeu.nuits = 1
	var sans: Dictionary = garde["monde"].duplicate()
	sans.erase("memoire")
	var avec: Dictionary = sans.duplicate()
	avec["memoire"] = true

	# --- le kit : lire les dispositions, ne compter les actions de la mémoire que si le monde la tient
	var t_essai := {"id": "essai-memoire", "populations": [
		{"biome": "foret", "effectif": 300, "mefiance": 0.6, "memoire": {"traque": 0.61, "neophobie": 0.31}, "attitude": "traqueuse"},
		{"biome": "lande", "effectif": 10}]}
	var lu: Dictionary = Orvane.dispositions(t_essai, "foret")
	var neutre: Dictionary = Orvane.dispositions(t_essai, "lande")
	verif(is_equal_approx(lu["mefiance"], 0.6) and lu["habituation"] == 0.0 and lu["attrait"] == 0.0 and is_equal_approx(lu["traque"], 0.61)
		and is_equal_approx(lu["neophobie"], 0.31) and lu["attitude"] == "traqueuse" and neutre == Orvane.DISPOSITIONS_NEUTRES and neutre["neophobie"] == 0.5
		and Orvane.dispositions("inconnue", "foret") == Orvane.DISPOSITIONS_NEUTRES,
		"le kit lit ce qu'une population a appris (méfiance %.2f, traque %.2f, néophobie %.2f, « %s ») ; ce qu'elle ne porte pas vaut sa valeur neutre (néophobie 0,5)" % [
			lu["mefiance"], lu["traque"], lu["neophobie"], lu["attitude"]])
	Orvane.instantane["monde"] = sans
	var c0: int = Orvane.en_cours()
	for a in Orvane.ACTIONS_MEMOIRE:
		Orvane.compter("essai-memoire", "foret", a)
	var endormi: bool = not Orvane.memoire_eveillee() and Orvane.en_cours() == c0
	Orvane.compter("essai-memoire", "foret", "rencontre", 1.0, "", "", "", "feu")
	Orvane.compter("essai-memoire", "foret", "rencontre", 1.0, "", "", "", "lumiere")
	Orvane.compter("essai-memoire", "foret", "rencontre", 1.0, "", "", "", "n-importe-quoi")
	var moyens: bool = Orvane.en_cours() == c0 + 3 and _compte("essai-memoire", "rencontre", "feu") == 1.0 and _compte("essai-memoire", "rencontre") == 3.0
	Orvane.instantane["monde"] = avec
	for a in Orvane.ACTIONS_MEMOIRE:
		Orvane.compter("essai-memoire", "foret", a)
	verif(endormi and moyens and Orvane.memoire_eveillee() and Orvane.en_cours() == c0 + 3 + Orvane.ACTIONS_MEMOIRE.size(),
		"un monde qui ne tient pas la mémoire : ses %d actions ne sont pas comptées (le lot serait refusé), le moyen passe toujours ; un monde qui l'annonce : elles le sont" % Orvane.ACTIONS_MEMOIRE.size())
	for cle in Orvane._evenements.keys():
		if cle.begins_with("essai-memoire|"):
			Orvane._evenements.erase(cle)

	# --- la crainte, la confiance : la distance de fuite d'une proie
	var proie_e: Dictionary = F["proies_jour"][0]
	for e in F["proies_jour"]:
		# (un flair moyen : la fuite d'une craintive tient dans l'écran sans toucher son plafond)
		if absf(float(e["lignee"]["plan"].get("perception", 0.5)) - 0.45) < absf(float(proie_e["lignee"]["plan"].get("perception", 0.5)) - 0.45):
			proie_e = e
	var flair := 90.0 + 230.0 * float(proie_e["lignee"]["plan"].get("perception", 0.5))
	var d0 := _fuite(proie_e, {}, true)
	var i0 := _fuite(proie_e, {}, false)
	verif(absf(d0 - flair) <= 2.0 and absf(i0 - flair * 0.55) <= 2.0,
		"sans mémoire, une proie fuit comme avant : à son flair si l'on marche (%d pixels pour %d), à 55 %% si l'on ne bouge pas (%d)" % [int(d0), int(flair), int(i0)])
	var d1 := _fuite(proie_e, {"mefiance": 0.9}, true)
	var d2 := _fuite(proie_e, {"habituation": 0.9}, true)
	var i2 := _fuite(proie_e, {"habituation": 0.9}, false)
	var d3 := _fuite(proie_e, {"mefiance": 1.0}, true)
	verif(d1 > d0 * 1.4 and d3 <= 420.0 and d2 < d0 * 0.7 and d2 >= 58.0 and i2 < i0 * 0.3,
		"la même lignée fuit de %d pixels sans mémoire, de %d craintive (%d au comble, jamais hors de l'écran), de %d habituée ; et qui ne bouge pas la laisse venir à %d pixels (contre %d)" % [
			int(d0), int(d1), int(d3), int(d2), int(i2), int(i0)])

	# --- le feu reste une loi ; la traque, la peur du feu, l'accoutumance autour de lui
	Orvane.instantane["monde"] = avec
	var ch_e: Dictionary = F["chasseurs_nuit"][0]
	f.bois = 100.0
	j.position = f.position + Vector2(0, 30)
	j.torche = 0.0
	var s0 := _siege(ch_e, {}, f, 40.0)
	var st := _siege(ch_e, {"traque": 1.0}, f, 40.0)
	var sa := _siege(ch_e, {"neophobie": 0.0}, f, 40.0)
	var sp := _siege(ch_e, {"neophobie": 0.95}, f, 40.0)
	var sc := _siege(ch_e, {"mefiance": 0.9}, f, 40.0)
	verif(s0["pres"] >= 0.78 and st["pres"] >= 0.78 and sa["pres"] >= 0.78 and sp["pres"] >= 0.78 and sc["pres"] >= 0.78 and st["bete"]._patience() < s0["bete"]._patience() * 0.85,
		"le feu reste une loi : traqueur ou fait au feu, aucun chasseur n'entre dans sa lumière (au plus près : %.2f, %.2f et %.2f du rayon, sans mémoire, traqueur, accoutumé) ; le traqueur tient moins longtemps en place (%d secondes à son poste, contre %d)" % [
			s0["pres"], st["pres"], sa["pres"], int(st["bete"]._patience()), int(s0["bete"]._patience())])
	# une bûche : celui qui craint le feu recule, pas l'autre
	j.inventaire["bois"] = int(j.inventaire["bois"]) + 1
	jeu.nourrir_feu()
	verif(sp["moyenne"] > s0["moyenne"] + 0.15 and sc["moyenne"] > s0["moyenne"] + 0.08 and sp["bete"].etat == "fuit" and s0["bete"].etat != "fuit",
		"une population qui craint le feu se poste à %.2f du rayon (contre %.2f ; %.2f pour une population craintive), hors de sa lumière ; et une bûche la fait reculer" % [
			sp["moyenne"], s0["moyenne"], sc["moyenne"]])
	var tenus: float = _compte(str(ch_e["id"]), "effarouchement", "feu")
	for x in [s0, st, sa, sp, sc]:
		_oter(x["bete"])
	_l_affut(ch_e, f)

	# --- la torche : tenu, ou traqueur (il s'annonce, puis passe) ; la première nuit, à moitié
	j.position = f.position + Vector2(f.rayon() + 700.0, 0)
	var t0 := _face_a_la_torche(ch_e, {}, 14.0)
	var tt := _face_a_la_torche(ch_e, {"traque": 1.0}, 14.0)
	var ta := _face_a_la_torche(ch_e, {"neophobie": 0.05}, 14.0)
	var tp := _face_a_la_torche(ch_e, {"neophobie": 0.95}, 14.0)
	jeu.nuits = 0
	var t1 := _face_a_la_torche(ch_e, {"traque": 1.0}, 14.0)
	jeu.nuits = 1
	# (il avançait dès qu'il sortait de sa limite et reculait dès qu'il y rentrait : cent volte-face en sept secondes)
	verif(t0["derriere"] and t0["va_et_vient"] <= 2 and t0["voltes"] <= 6 and ta["va_et_vient"] <= 2 and ta["voltes"] <= 6 and tp["va_et_vient"] <= 2 and tp["voltes"] <= 6,
		"tenu par la torche, il garde sa distance, passe dans son dos et s'y arrête (plus de manège), sans aller et venir : en sept secondes, %d volte-face et %d va-et-vient (fait au feu : %d et %d ; qui le craint : %d et %d)" % [
			t0["voltes"], t0["va_et_vient"], ta["voltes"], ta["va_et_vient"], tp["voltes"], tp["va_et_vient"]])
	# (il passe la ligne des 140 pixels d'un pas avant d'être tenu : au plus près, un peu moins de 140 ; mesuré, 133)
	verif(t0["pres"] >= 125.0 and t0["morsure"] < 0.0 and tt["morsure"] > 0.0 and tt["annonce"] >= 0.0 and tt["morsure"] - tt["annonce"] >= 0.8,
		"la torche tient un chasseur d'audace 0,5 à %d pixels ; le même, d'une population qui traque, s'aplatit et gronde, puis la franchit et mord %.1f s plus tard" % [
			int(t0["pres"]), tt["morsure"] - tt["annonce"]])
	verif(t1["morsure"] < 0.0 and t1["pres"] >= 125.0 and is_equal_approx(t1["bete"].traque, 0.5),
		"la première nuit, ce qui rend une population dangereuse compte pour moitié : le même traqueur ne passe pas encore la torche (au plus près : %d pixels)" % int(t1["pres"]))
	var portee_morsure: float = 24.0 + ta["bete"].largeur * 0.3
	verif(ta["moyenne"] < t0["moyenne"] - 25.0 and ta["pres"] >= 80.0 and ta["pres"] > portee_morsure + 10.0 and ta["morsure"] < 0.0 and tp["moyenne"] > t0["moyenne"] + 40.0,
		"fait au feu, il se tient plus près de la torche (%d pixels contre %d ; au plus près %d, hors de portée de morsure : %d), sans mordre ; s'il le craint, plus loin (%d)" % [
			int(ta["moyenne"]), int(t0["moyenne"]), int(ta["pres"]), int(portee_morsure), int(tp["moyenne"])])

	# --- ce que la partie raconte à Orvane (le monde tenant la mémoire)
	var id_ch := str(ch_e["id"])
	var lumiere: float = _compte(id_ch, "effarouchement", "lumiere")
	var assauts: float = _compte(id_ch, "attaque")
	# la morsure qui la ferait tomber (elle est relevée aussitôt : la partie continue)
	j.sante = 1.0
	jeu.mordre(tt["bete"])
	j.sante = 100.0
	var tombee: float = _compte(id_ch, "joueur_tombe")
	for x in [t0, tt, ta, tp, t1]:
		_oter(x["bete"])
	# une proie frappée du poing qui s'en va : une blessure ; frappée puis tuée, ou frappée par la foudre : aucune
	j.lance = 0
	var id_p := str(proie_e["id"])
	var tuees0: float = _compte(id_p, "prelevement", "melee")
	var blessee = _bete(proie_e, "proie", j.position + Vector2(20, 0), {})
	jeu.agir()
	var touchee: bool = blessee.touchee and blessee.pv > 0.0
	_oter(blessee)
	var achevee = _bete(proie_e, "proie", j.position + Vector2(-20, 0), {})
	for i in 12:
		if is_instance_valid(achevee) and achevee.is_in_group("betes"):
			achevee.position = j.position + Vector2(-20, 0)
			jeu.agir()
	var foudroyee = _bete(proie_e, "proie", j.position + Vector2(0, 300), {})
	foudroyee.foudroyer(1.0, j.position)
	_oter(foudroyee)
	await get_tree().process_frame
	await get_tree().process_frame
	verif(tenus == 5.0 and lumiere == 4.0 and assauts == 1.0 and tt["morsures"] >= 2 and tombee == 1.0 and touchee
		and _compte(id_p, "blessure", "melee") == 1.0 and _compte(id_p, "prelevement", "melee") == tuees0 + 1.0 and _compte(id_p, "prelevement") == _compte(id_p, "prelevement", "melee"),
		"ce que la partie apprend aux bêtes est compté pour Orvane : chaque chasseur tenu, une fois (%d par le feu, %d par la torche) ; %d morsures, un seul assaut ; la morsure qui tue ; une proie frappée qui s'en va, une blessure ; tuée, un prélèvement, au corps à corps ; la foudre, rien" % [
			int(tenus), int(lumiere), int(tt["morsures"])])

	# (ce que le lot en dira, à ce moment de la partie)
	var dit: String = jeu._texte_appris()

	# --- le rôdeur : sa charge apprise s'annonce ; celle qui suit la veilleuse
	var rod_e: Dictionary = {}
	for e in F["rodeurs"] + F["chasseurs_nuit"]:
		if float(e["masse"]) >= 4.0:
			rod_e = e
			break
	var id_r := str(rod_e.get("id", ""))
	var charges0: float = _compte(id_r, "attaque")
	var c_sans := _charge(rod_e, {}, 60.0)
	var c_traque := _charge(rod_e, {"traque": 1.0}, 60.0)
	var loin_sans := _charge(rod_e, {}, 125.0)
	var loin_traque := _charge(rod_e, {"traque": 1.0}, 125.0)
	verif(not rod_e.is_empty() and c_sans["charge"] >= 0.0 and c_sans["guet"] < 0.0 and c_sans["duree"] == 6.0
		and c_traque["guet"] >= 0.0 and c_traque["charge"] - c_traque["guet"] >= 0.55 and c_traque["duree"] == 10.0
		and loin_sans["charge"] < 0.0 and loin_traque["charge"] >= 0.0 and _compte(id_r, "attaque") == charges0 + 3.0,
		"un rôdeur d'une population qui traque s'arrête et guette %.1f s avant de charger, et charge de plus loin (à 125 pixels, où l'autre laisse passer) ; sans mémoire il charge sans présage, comme avant ; chaque charge est un assaut" % (c_traque["charge"] - c_traque["guet"]))
	var suit_sans = _bete(rod_e, "rodeur", j.position + Vector2(500, 0), {})
	var suit_1 = _bete(rod_e, "rodeur", j.position + Vector2(500, 0), {"traque": 1.0})
	var suit_2 = _bete(proie_e, "proie", j.position + Vector2(-500, 0), {"attrait": 1.0})
	var suit_3 = _bete(proie_e, "proie", j.position + Vector2(0, 500), {"attrait": 1.0})
	for i in 60:
		suit_sans._suivre()
		if not suit_1._suit:
			suit_1._suivre()
		if not suit_2._suit:
			suit_2._suivre()
	var jamais: bool = not suit_sans._suit
	for i in 60:
		suit_3._suivre()
	var a_distance: float = suit_1._cible.distance_to(j.position)
	var hors_fuite: float = suit_2._cible.distance_to(j.position) - suit_2._distance_fuite(true)
	verif(jamais and suit_1._suit and a_distance >= 179.0 and a_distance <= 261.0 and suit_2._suit and hors_fuite >= 29.0 and hors_fuite <= 81.0 and not suit_3._suit,
		"un rôdeur qui traque suit la veilleuse de loin (à %d pixels, hors de portée de sa charge) ; une proie que les joueurs attirent vient voir, %d pixels au-delà de sa distance de fuite ; deux à la fois, pas plus ; sans mémoire, aucune" % [int(a_distance), int(hors_fuite)])
	for x in [suit_sans, suit_1, suit_2, suit_3]:
		_oter(x)

	# --- l'agressivité (docs/50) : une proie qui fait front au lieu de fuir ; et une bête n'est pas sa population
	var flair_p := 90.0 + 230.0 * float(proie_e["lignee"]["plan"].get("perception", 0.5))
	var assauts_p0: float = _compte(id_p, "attaque")
	var f_sans := _front(proie_e, {}, 12.0)
	var f_ag := _front(proie_e, {"agressivite": 0.8}, 12.0)
	var f_menue := _front(proie_e, {"agressivite": 0.8}, 0.3)
	jeu.nuits = 0
	var f_nuit1 := _front(proie_e, {"agressivite": 0.6}, 12.0)
	jeu.nuits = 1
	verif(f_sans["front"] < 0.0 and absf(f_sans["fuite"] - flair_p) <= 2.0 and f_ag["fuite"] < 0.0 and absf(f_ag["front"] - flair_p) <= 2.0
		and f_ag["charge"] > 0.0 and f_ag["charge"] <= f_ag["portee"] and f_ag["portee"] >= 50.0 and f_ag["portee"] <= 200.0 and f_ag["front"] - f_ag["charge"] >= 30.0 and is_equal_approx(f_ag["duree"], 6.2)
		and _compte(id_p, "attaque") == assauts_p0 + 1.0,
		"une proie d'une population agressive ne fuit plus : à %d pixels (là où l'autre s'enfuit) elle s'arrête, fait face et gronde ; si la veilleuse insiste, elle charge à %d pixels, %.1f secondes ; sa charge est un assaut, compté pour Orvane" % [
			int(f_ag["front"]), int(f_ag["charge"]), f_ag["duree"]])
	verif(f_menue["front"] > 0.0 and f_menue["charge"] < 0.0 and f_menue["fuite"] >= 0.0 and f_menue["fuite"] <= 36.0 and f_nuit1["front"] < 0.0 and f_nuit1["fuite"] > 0.0 and is_equal_approx(f_nuit1["bete"].agressivite, 0.3),
		"trop petite pour charger (300 grammes), elle tient sa place et menace, et ne file qu'à %d pixels ; la première nuit, l'agressivité compte pour moitié : celle-là fuit encore" % int(f_menue["fuite"]))
	# frappée : elle se retourne, là où l'autre s'enfuit
	f_sans["bete"].etat = "repos"
	f_sans["bete"].blesser(0.5, j.position)
	var ag2 = _bete(proie_e.merged({"masse": 12.0}), "proie", j.position + Vector2(40, 0), {"agressivite": 0.8})
	ag2.blesser(0.5, j.position)
	verif(f_sans["bete"].etat == "fuit" and ag2.etat == "attaque", "frappée, une proie sans mémoire s'enfuit ; agressive et de taille, elle se retourne et charge")
	# la même population, trois bêtes : la plus hardie fait front, la plus craintive fuit de plus loin
	var troupeau := {"mefiance": 0.7, "agressivite": 0.3}
	var f_moy := _front(proie_e, troupeau, 12.0, 0.0)
	var f_hardie := _front(proie_e, troupeau, 12.0, 1.5)
	var f_crainte := _front(proie_e, troupeau, 12.0, -1.5)
	var une: Dictionary = Orvane.individu(troupeau, 1.5)
	var meme: Dictionary = Orvane.individu(troupeau, 0.0)
	verif(f_moy["front"] < 0.0 and f_moy["fuite"] > flair_p and f_hardie["front"] > 0.0 and f_hardie["fuite"] < 0.0 and f_crainte["front"] < 0.0 and f_crainte["fuite"] > f_moy["fuite"] + 10.0
		and absf(float(une["mefiance"]) - 0.4495) < 0.001 and absf(float(une["agressivite"]) - 0.5505) < 0.001 and is_equal_approx(float(meme["mefiance"]), 0.7) and is_equal_approx(float(meme["agressivite"]), 0.3)
		and float(Orvane.individu(Orvane.DISPOSITIONS_NEUTRES, 2.0)["agressivite"]) == 0.0 and float(Orvane.individu(Orvane.DISPOSITIONS_NEUTRES, 2.0)["mefiance"]) == 0.0,
		"une bête n'est pas sa population : dans un troupeau qui fuit (méfiance 0,7, agressivité 0,3), la bête moyenne s'enfuit à %d pixels, la plus craintive à %d, et la plus hardie fait front à %d (méfiance %.2f, agressivité %.2f) ; rien d'appris, rien à déplacer" % [
			int(f_moy["fuite"]), int(f_crainte["fuite"]), int(f_hardie["front"]), une["mefiance"], une["agressivite"]])
	for x in [f_sans, f_ag, f_menue, f_nuit1, f_moy, f_hardie, f_crainte]:
		_oter(x["bete"])
	_oter(ag2)
	# un chasseur agressif ne lâche plus prise sous les coups (quatre cents coups qui ne l'entament pas)
	var lache := [0, 0]
	for k in 2:
		var ch = _bete(ch_e, "chasseur", j.position + Vector2(300, 0), {"agressivite": 0.8} if k == 1 else {})
		ch.pv_max = 1.0e9
		ch.pv = 1.0e9
		for i in 400:
			ch.etat = "chasse"
			ch.blesser(1.0, j.position)
			if ch.etat == "fuit":
				lache[k] += 1
		_oter(ch)
	var car: Dictionary = Orvane.caractere({"id": "essai", "caractere": {"hardiesse": 0.7, "combativite": 0.86, "opportunisme": 0.57}})
	verif(lache[0] >= 70 and lache[0] <= 130 and lache[1] <= 40 and lache[1] * 2 < lache[0] and is_equal_approx(float(car.get("combativite", 0.0)), 0.86) and car.size() == 3 and Orvane.caractere("inconnue").is_empty(),
		"frappé, un chasseur lâche prise %d fois sur 400 ; d'une population agressive, %d fois : il ne recule plus ; le kit lit aussi le caractère d'une lignée (combativité %.2f)" % [lache[0], lache[1], car.get("combativite", 0.0)])

	# --- le carnet, le texte du lot, la mémoire qu'on force pour essayer
	var comptes: int = Orvane.en_cours()
	jeu.donnees.memoire_forcee = "traque"
	var forcee: Dictionary = jeu.donnees.faune(Orvane.instantane, jeu.biome)
	jeu.donnees.memoire_forcee = ""
	var libre: Dictionary = jeu.donnees.faune(Orvane.instantane, jeu.biome)
	var du_monde := true
	for i in libre["chasseurs_nuit"].size():
		if libre["chasseurs_nuit"][i]["memoire"] != jeu.faune["chasseurs_nuit"][i]["memoire"]:
			du_monde = false
	verif(D.dire_memoire({"mefiance": 0.9}) == "méfiante : on la chasse ici" and D.dire_memoire({"neophobie": 0.95, "attitude": "traqueuse"}) == "elle traque les veilleuses"
		and D.dire_memoire({"agressivite": 0.6}) == "elle a appris à faire front" and D.dire_memoire({"attitude": "agressive"}) == "elle fait front, et charge" and D.MEMOIRES.has("agressivite")
		and D.dire_memoire(Orvane.DISPOSITIONS_NEUTRES) == "" and dit.contains("tenues à distance") and dit.contains("1 assaut") and dit.contains("bête blessée"),
		"le carnet le dit : « %s » sous une bête craintive, rien sous une bête sans mémoire ; et le lot : « …%s »" % [D.dire_memoire({"mefiance": 0.9}), dit])
	verif(forcee["chasseurs_nuit"].all(func(e): return e["memoire"]["traque"] == 0.9 and e["memoire"]["attitude"] == "traqueuse")
		and du_monde and Orvane.en_cours() == comptes,
		"« --memoire traque » pose la traque sur les %d populations de chasseurs du lieu, sans rien compter ; sans l'argument, la mémoire est celle du monde" % forcee["chasseurs_nuit"].size())

	# (tout revient à sa place : le monde lu, l'heure, la veilleuse, le feu)
	Orvane.instantane["monde"] = garde["monde"]
	jeu.horloge = garde["horloge"]
	jeu.nuits = garde["nuits"]
	jeu.appris = garde["appris"]
	f.bois = garde["bois"]
	j.inventaire["bois"] = garde["sac"]
	j.position = garde["p"]
	j.torche = garde["torche"]
	j.peur = garde["peur"]
	j.lance = garde["lance"]
	j.en_mouvement = garde["marche"]
	j.sante = 100.0


# le lieu sans bord, à part : ses noms ne se mêlent pas à ceux de la partie d'avant
func _lieu_sans_bord() -> void:
	var PG := load("res://scripts/partie_gardee.gd")
	print("8. Le lieu sans bord")
	# (MONDE-OUVERT.md, étape 2 : le lieu se fabrique par morceaux autour de la veilleuse, et ne garde que ce qu'on y change)
	var propose: Array = jeu._lieux_du_titre()
	verif(jeu.ui._portail_b != null and jeu.ui._portail_b.get_parent() == jeu.ui._ligne_compte and jeu.R.PORTAIL == "https://stonevalleyoff-ai.github.io/",
		"l'écran-titre a son « Retour au portail », à côté du compte et du tableau des scores")
	verif(propose.size() == 1 and str(propose[0]["id"]) == "ouvert:monde" and jeu.donnees.lieux().size() > 1,
		"l'écran-titre ne propose que « %s » (%s) : plus les lieux d'un seul biome (%d se liraient)" % [propose[0]["nom"] if propose.size() > 0 else "?",
		propose[0]["detail"] if propose.size() > 0 else "?", jeu.donnees.lieux().size()])
	await jeu._commencer("prairie", {}, true)
	var W = jeu.monde
	var jo = jeu.joueur
	# (ce qu'il y a à moins de 600 pixels d'un point, dans l'ordre : pour dire si c'est le même lieu)
	var signature := func(centre: Vector2) -> String:
		var l: Array = W.autour(centre, 600.0).map(func(x): return "%s %d %d" % [x.genre, int(round(x.position.x)), int(round(x.position.y))])
		l.sort()
		return "|".join(PackedStringArray(l))
	var n0: int = W.objets.size()
	var loin0 := 0.0
	for x in W.objets:
		loin0 = maxf(loin0, maxf(absf(x.position.x), absf(x.position.y)))
	verif(jeu.en_partie and jeu.ouvert and W.ouvert and n0 > 100 and loin0 <= W.PORTEE + W.MORCEAU and W._morceaux.size() >= 16,
		"au réveil, le lieu n'existe qu'autour d'elle : %d objets en %d morceaux, à moins de %d pixels" % [n0, W._morceaux.size(), int(loin0)])
	jo.position = Vector2(jeu.R.DEMI - 40.0, 0.0)
	for k in 30:
		jo.deplacer(Vector2(1, 0), 0.1, W)
	verif(jo.position.x > jeu.R.DEMI + 100.0, "elle passe l'ancien bord du lieu (%d pixels à l'est, il était à %d)" % [int(jo.position.x), int(jeu.R.DEMI)])
	var depart: String = signature.call(Vector2.ZERO)
	var ici := Vector2(9000.0, 300.0)
	jo.position = ici
	W.suivre(ici, true)
	var n1: int = W.objets.size()
	verif(not W.autour(ici, 600.0).is_empty() and W.autour(Vector2.ZERO, 600.0).is_empty() and n1 < n0 * 2 and n1 > n0 / 3,
		"à 9 000 pixels de là, le lieu s'est fait autour d'elle et défait derrière elle : %d objets, comme au réveil" % n1)
	# ce qu'elle change là-bas : un arbre brûlé, une brindille ramassée, un buisson cueilli (qui repoussera)
	var le_plus_pres := func(test: Callable):
		var mieux_ = null
		var d0 := INF
		for x in W.autour(ici, 900.0):
			if test.call(x) and x.position.distance_to(ici) < d0:
				d0 = x.position.distance_to(ici)
				mieux_ = x
		return mieux_
	var arbre_la = le_plus_pres.call(func(x): return x.couvert() > 0.0)
	var brindille_la = le_plus_pres.call(func(x): return x.genre == "brindille")
	var buisson_la = le_plus_pres.call(func(x): return x.genre == "buisson" or x.genre == "touffe")
	var p_arbre: Vector2 = arbre_la.position
	var p_brindille: Vector2 = brindille_la.position
	var p_buisson: Vector2 = buisson_la.position
	arbre_la.calciner()
	W.retirer(brindille_la)
	buisson_la.reprendre(buisson_la.genre, 0, 50.0)
	var a_cet_endroit := func(p: Vector2):
		var l: Array = W.autour(p, 1.5)
		return l[0] if not l.is_empty() else null
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	verif(signature.call(Vector2.ZERO) == depart and W.autour(ici, 900.0).is_empty(), "revenue au réveil, elle retrouve le même lieu, objet pour objet")
	jo.position = ici
	W.suivre(ici, true)
	var souche_la = a_cet_endroit.call(p_arbre)
	var buisson_vide = a_cet_endroit.call(p_buisson)
	verif(souche_la != null and souche_la.genre == "souche" and souche_la.calcine and a_cet_endroit.call(p_brindille) == null and buisson_vide != null and buisson_vide.reste == 0,
		"et là-bas, ce qu'elle avait changé : la souche noire de l'arbre brûlé, la brindille qui n'y est plus, le buisson cueilli")
	# le temps passe pendant qu'elle est loin : le buisson a repoussé
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu.horloge += 120.0
	jo.position = ici
	W.suivre(ici, true)
	var buisson_plein = a_cet_endroit.call(p_buisson)
	verif(buisson_plein != null and buisson_plein.intact() and a_cet_endroit.call(p_arbre).genre == "souche", "deux minutes plus tard, le buisson a repoussé sans elle ; la souche est toujours une souche")
	await _les_regions()
	_le_relief()
	_les_grottes()
	jo.position = ici
	W.suivre(ici, true)
	# gardée, la partie ne retient que ce qui a changé
	var gardee2: Dictionary = JSON.parse_string(JSON.stringify(PG.photo(jeu)))
	await jeu._commencer("prairie", gardee2)
	var souche2 = jeu.monde.autour(p_arbre, 1.5)
	verif(jeu.ouvert and gardee2["objets"].is_empty() and gardee2["monde"]["changes"].size() >= 1 and jeu.joueur.position.distance_to(ici) < 1.0
		and souche2.size() == 1 and souche2[0].genre == "souche" and souche2[0].calcine and jeu.monde.autour(p_brindille, 1.5).is_empty(),
		"gardée puis reprise, la partie sans bord revient là où elle était, avec ce qu'elle avait changé (%d octets pour tout le lieu)" % JSON.stringify(gardee2["monde"]).length())


# le monde ouvert : d'un biome à l'autre (scripts/carte.gd, MONDE-OUVERT.md, étape 3)
func _les_regions() -> void:
	var C = jeu.carte
	var W = jeu.monde
	var jo = jeu.joueur
	jeu._regions()
	var terres := 0
	for reg in C.regions:
		if not reg["eau"]:
			terres += 1
	verif(C != null and str(C.regions[C.region_en(Vector2.ZERO)]["type"]) == "prairie" and jeu.biome == "prairie" and terres > 100,
		"le monde ouvert a sa carte : %d régions de terre ; on s'éveille dans la prairie du centre (%s)" % [terres, C.regions[C.depart]["id"]])
	# vers la forêt voisine : la plus proche des régions de forêt
	var foret := -1
	for k in C.regions.size():
		if str(C.regions[k]["type"]) == "foret" and (foret < 0 or C.regions[k]["pos"].length() < C.regions[foret]["pos"].length()):
			foret = k
	var la: Vector2 = C.regions[foret]["pos"] - C.tordre(C.regions[foret]["pos"])
	W.suivre(Vector2.ZERO, true)
	var arbres_ici: int = W.autour(Vector2.ZERO, 1000.0).filter(func(x): return x.couvert() > 0.0).size()
	jo.position = la
	W.suivre(la, true)
	await jeu._lire_biome("foret")
	jeu._regions()
	var arbres_la: int = W.autour(la, 1000.0).filter(func(x): return x.couvert() > 0.0).size()
	verif(str(C.regions[C.region_en(la)]["type"]) == "foret" and jeu.biome == "foret" and jeu.faune == jeu._faunes["foret"] and not jeu.faune["chasseurs_nuit"].is_empty()
		and absf(jeu.climat.humide - float(jeu.donnees.biome("foret")["axes"]["humidite"])) < 0.01 and arbres_la > arbres_ici * 2,
		"à %d pixels de là, la forêt : ses bêtes (%d chasseurs de nuit), son climat, ses arbres (%d dans un rayon de 1 000 pixels, contre %d dans la prairie)" % [
			int(la.length()), jeu.faune["chasseurs_nuit"].size(), arbres_la, arbres_ici])
	var bete_la = jeu._creer(jeu.faune["proies_jour"][0], "proie", la + Vector2(60, 0))
	verif(str(bete_la.get_meta("biome", "")) == "foret" and str(bete_la.get_meta("parcelle", "")) == str(C.regions[foret]["id"]),
		"une bête de là-bas sera comptée dans son biome et sa parcelle d'Orvane (%s)" % str(bete_la.get_meta("parcelle", "")))
	bete_la.queue_free()
	# l'eau est une frontière : on n'y entre pas, rien n'y pousse
	var eau_ := -1
	var terre_ := -1
	for k in C.regions.size():
		if C.regions[k]["eau"] or eau_ >= 0:
			continue
		for v in C.regions[k]["voisines"]:
			if C.regions[v]["eau"] and not C.regions[v]["bord"]:
				eau_ = v
				terre_ = k
				break
	var p_eau: Vector2 = C.regions[eau_]["pos"] - C.tordre(C.regions[eau_]["pos"])
	var p_terre: Vector2 = C.regions[terre_]["pos"] - C.tordre(C.regions[terre_]["pos"])
	var vers_l_eau: Vector2 = p_terre
	for k in 2000:
		var n: Vector2 = W.repousser(vers_l_eau + (p_eau - vers_l_eau).normalized() * 40.0, 8.0)
		if n.distance_to(vers_l_eau) < 2.0:
			break
		vers_l_eau = n
	W.suivre(p_eau, true)
	verif(not C.regions[C.region_en(vers_l_eau)]["eau"] and vers_l_eau.distance_to(p_eau) < p_terre.distance_to(p_eau) * 0.75 and W.autour(p_eau, 900.0).is_empty(),
		"l'eau est une frontière : partie de %s vers %s, elle s'arrête sur la rive ; rien ne pousse dans l'eau" % [C.regions[terre_]["id"], C.regions[eau_]["id"]])
	# une crête : deux biomes qui se touchent sur la carte sans être voisins dans Orvane
	var ca := -1
	var cb := -1
	for k in C.regions.size():
		if not C.regions[k]["murs"].is_empty() and ca < 0:
			ca = k
			cb = int(C.regions[k]["murs"].keys()[0])
	var p_a: Vector2 = C.regions[ca]["pos"] - C.tordre(C.regions[ca]["pos"])
	var p_b: Vector2 = C.regions[cb]["pos"] - C.tordre(C.regions[cb]["pos"])
	var vers_la_crete: Vector2 = p_a
	for k in 2000:
		var n: Vector2 = C.retenir(vers_la_crete + (p_b - vers_la_crete).normalized() * 40.0)
		if n.distance_to(vers_la_crete) < 2.0:
			break
		vers_la_crete = n
	var au_pied: Vector2 = vers_la_crete + (p_b - vers_la_crete).normalized() * 60.0
	W.suivre(au_pied, true)
	var rochers: int = W.autour(au_pied, 500.0).filter(func(x): return x.genre == "rocher").size()
	verif(C.region_en(vers_la_crete) != cb and vers_la_crete.distance_to(p_b) < p_a.distance_to(p_b) * 0.8 and rochers >= 8,
		"une crête ferme la frontière entre %s et %s : on ne passe pas, des rochers la marquent (%d au pied)" % [C.regions[ca]["type"], C.regions[cb]["type"], rochers])
	# ce qu'on découvre se note, et la carte du carnet le montre
	var co: Array = C.contour(foret)
	var aire_ := 0.0
	for k in co[0].size():
		aire_ += co[0][k].cross(co[0][(k + 1) % co[0].size()])
	# (sans carte fabriquée, le carnet n'en montre pas ; la carte faite, tout ce qu'elle a découvert y est)
	var carte_avant: int = int(jeu.atelier.objets.get("carte", 0))
	jeu.atelier.objets["carte"] = 0
	jeu.ui.montrer_pause(true)
	var sans_carte: bool = not jeu.ui._pause.carte_monde.visible and jeu.ui._pause._commandes.visible and str(jeu.ui._pause._sous.text).contains("établi")
	jeu.ui.montrer_pause(false)
	jeu.atelier.objets["carte"] = 1
	jeu.ui.montrer_pause(true)
	var page_carte: bool = jeu.ui._pause.carte_monde.visible and not jeu.ui._pause._commandes.visible and str(jeu.ui._pause._sous.text).contains("découverte")
	jeu.ui.montrer_pause(false)
	jeu.atelier.objets["carte"] = carte_avant
	var gardee_d: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	verif(jeu.decouvertes.has(foret) and jeu.decouvertes.size() >= 2 and absf(aire_) * 0.5 > 0.3 * C.cote * C.cote and absf(aire_) * 0.5 < 3.0 * C.cote * C.cote
		and sans_carte and page_carte and gardee_d["decouvertes"].has(str(C.regions[foret]["id"])),
		"ce qu'on découvre se note (%d régions) et se garde ; sans carte, le carnet n'en montre pas ; la carte faite, il montre tout (« %s »)" % [jeu.decouvertes.size(), jeu.ui._pause._sous.text])
	# une rivière traverse sa vallée : son lit arrête ; à gué on passe à pied ; ailleurs, un pont de fortune
	var riv := -1
	for k in C.regions.size():
		if C.regions[k]["riviere"] and (riv < 0 or C.regions[k]["pos"].length() < C.regions[riv]["pos"].length()):
			riv = k
	var fond := Vector2.INF
	var gue := Vector2.INF
	for ix in range(-40, 41):
		for iy in range(-40, 41):
			var q: Vector2 = C.regions[riv]["pos"] + Vector2(ix, iy) * 220.0
			if C.region_en(q) != riv or C.lit(q) < 0.5:
				continue
			if C.champ_gue(q) > 0.62 and gue == Vector2.INF:
				gue = q
			elif C.champ_gue(q) < 0.3 and fond == Vector2.INF and not C.pont_depuis(C.retenir(q)).is_empty():
				fond = q
	var berge: Vector2 = C.retenir(fond)
	jo.position = berge
	W.suivre(berge, true)
	jeu._regions()
	verif(riv >= 0 and fond != Vector2.INF and C.lit(fond) > 0.5 and C.lit(berge) == 0.0 and berge.distance_to(fond) > 20.0 and jeu.biome == "riviere"
		and W.objets.filter(func(x): return C.mouille(x.position)).is_empty(),
		"une rivière traverse sa vallée (%s) : son lit arrête la veilleuse sur la berge, rien n'y pousse" % C.regions[riv]["id"])
	verif(gue != Vector2.INF and C.retenir(gue) == gue and jeu.climat.eau(gue) > 0.3 and jeu.climat.allure(gue) < 0.9,
		"à gué, on passe à pied : de l'eau jusqu'aux genoux (%.2f), on y marche à %d %% de l'allure" % [jeu.climat.eau(gue), int(jeu.climat.allure(gue) * 100.0)])
	jo.inventaire["bois"] = 20
	jo.inventaire["fibre"] = 10
	jeu._pont_vu = 0.0
	jeu._voir_les_ponts(1.0)
	var possible: bool = jeu.pont_possible
	jeu.fabriquer("pont")
	var pont = jeu.ponts[0] if not jeu.ponts.is_empty() else null
	var milieu: Vector2 = (pont.a + pont.b) * 0.5 if pont != null else Vector2.ZERO
	verif(possible and pont != null and int(jo.inventaire["bois"]) == 14 and int(jo.inventaire["fibre"]) == 7 and C.lit(milieu) > 0.0 and C.retenir(milieu) == milieu
		and jeu.climat.eau(milieu) == 0.0 and C.lit(pont.b) == 0.0,
		"au bord, un pont de fortune se pose jusqu'à l'autre berge (%d pixels ; 6 bois, 3 fibres) : on y passe au sec" % int(pont.a.distance_to(pont.b)))
	# (et il se voit : peint après le calque du relief, qui porte le lit de la rivière, et non dessous comme avant)
	# (sans écran, le calque du relief n'est pas fait : alors après la nappe du temps qu'il fait, ou, sans elle, dans les calques)
	var dessous_p: Node = jeu.scene.get_node_or_null("SolRelief")
	if dessous_p == null:
		dessous_p = jeu.scene.get_node_or_null("TempsSol")
	var au_dessus: bool = pont != null and ((dessous_p == null and pont.get_parent() == jeu.monde._calques[2])
		or (dessous_p != null and pont.get_parent() == jeu.scene and pont.get_index() > dessous_p.get_index()))
	verif(au_dessus, "le pont se dessine par-dessus le lit de la rivière (après %s), son tablier se voit d'une berge à l'autre" % (
		str(dessous_p.name) if dessous_p != null else "les calques du sol"))
	var gardee_p: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	pont.tenue = 0.5
	pont._process(1.0)
	verif(gardee_p["ponts"].size() == 1 and jeu.ponts.is_empty() and C.retenir(milieu).distance_to(milieu) > 5.0,
		"il se garde avec la partie, mais ne dure pas : usé, il cède, et le lit arrête de nouveau")
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu._regions()


# le monde ouvert : le relief des régions hautes (scripts/carte.gd, MONDE-OUVERT.md, étape 4)
func _le_relief() -> void:
	var C = jeu.carte
	var W = jeu.monde
	var jo = jeu.joueur
	# la montagne la plus proche : un point de paroi, un point de col (bien au milieu de sa rampe)
	var mont := -1
	for k in C.regions.size():
		if str(C.regions[k]["type"]) == "montagne" and (mont < 0 or C.regions[k]["pos"].length() < C.regions[mont]["pos"].length()):
			mont = k
	var centre: Vector2 = C.regions[mont]["pos"] - C.tordre(C.regions[mont]["pos"])
	var p_paroi := Vector2.INF
	var p_col := Vector2.INF
	var etages := {}
	for ix in range(-70, 71):
		for iy in range(-70, 71):
			var q: Vector2 = centre + Vector2(ix, iy) * 60.0
			if C.region_en(q) != mont:
				continue
			etages[C.palier(q)] = true
			var e: Array = C._paroi(q)
			if e.is_empty() or absf(float(e[0])) > 6.0:
				continue
			if not bool(e[2]) and C.champ_col(q) < 0.0 and p_paroi == Vector2.INF:
				p_paroi = q
			elif bool(e[2]) and C.champ_col(q) > 0.75 and p_col == Vector2.INF:
				p_col = q
	verif(float(C.regions[mont]["haut"]) > 0.4 and C.force(Vector2.ZERO) == 0.0 and C.palier(Vector2.ZERO) == 0 and etages.size() >= 2
		and p_paroi != Vector2.INF and p_col != Vector2.INF,
		"la montagne s'élève par paliers (%d étages), entre eux des parois et des cols ; la prairie du réveil est plate" % etages.size())
	# une paroi : on ne la passe ni d'en haut, ni d'en bas
	var e_p: Array = C._paroi(p_paroi)
	var monte: Vector2 = e_p[1]
	var haut: Vector2 = p_paroi + monte * (C.PAROI + 14.0)
	var bas: Vector2 = p_paroi - monte * (C.PAROI + 14.0)
	var d_haut := _marcher(haut, -monte, 160)
	var d_bas := _marcher(bas, monte, 160)
	verif(C.palier(haut) == C.palier(bas) + 1 and C.retenir(p_paroi).distance_to(p_paroi) > 10.0 and C.palier(d_haut) == C.palier(haut) and C.palier(d_bas) == C.palier(bas)
		and not C.paroi_en(d_haut) and not C.paroi_en(d_bas),
		"une paroi sépare deux étages (%d en haut, %d en bas) : on ne la passe ni en descendant, ni en montant" % [C.palier(haut), C.palier(bas)])
	# un col : on y monte à pied, lentement (ni boue, ni neige, ni crue : le col seul)
	var temps_col := [jeu.climat.boue, jeu.climat.neige_sol, jeu.climat.crue]
	jeu.climat.boue = 0.0
	jeu.climat.neige_sol = 0.0
	jeu.climat.crue = 0.0
	var e_c: Array = C._paroi(p_col)
	var monte_c: Vector2 = e_c[1]
	var bas_c: Vector2 = p_col - monte_c * (C.PAROI + 14.0)
	var arrivee := _marcher(bas_c, monte_c, 80)
	verif(C.retenir(p_col) == p_col and C.col_en(p_col) and jeu.climat.allure(p_col) < 0.8 and jeu.climat.allure(bas_c) > 0.99 and C.palier(arrivee) == C.palier(bas_c) + 1,
		"un col est une rampe dans la paroi : on y monte à pied, plus lentement (%.2f), d'un étage au suivant" % jeu.climat.allure(p_col))
	jeu.climat.boue = temps_col[0]
	jeu.climat.neige_sol = temps_col[1]
	jeu.climat.crue = temps_col[2]
	# rien ne pousse sur une paroi ; plus haut, l'air est plus froid
	jo.position = bas
	W.suivre(bas, true)
	var dessus: int = W.objets.filter(func(x): return not C._paroi(x.position).is_empty()).size()
	jeu.altitude = 0.0
	var air_bas: float = jeu.climat._air_de_fond()
	jeu.altitude = 2.0
	var air_haut: float = jeu.climat._air_de_fond()
	jeu.altitude = 0.0
	verif(dessus == 0 and W.objets.size() > 20 and air_haut < air_bas - 0.04,
		"rien ne pousse sur une paroi, sur un col (%d objets autour) ; deux étages plus haut, l'air est plus froid (%.2f contre %.2f)" % [W.objets.size(), air_haut, air_bas])
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu._regions()


# le monde ouvert : les grottes (scripts/carte.gd, MONDE-OUVERT.md, étape 4)
func _les_grottes() -> void:
	var C = jeu.carte
	var W = jeu.monde
	var jo = jeu.joueur
	var grotte := -1
	for k in C.regions.size():
		if C.regions[k]["grotte"] and (grotte < 0 or C.regions[k]["pos"].length() < C.regions[grotte]["pos"].length()):
			grotte = k
	# une bouche : du vide au milieu de la muraille, d'où l'on va tout droit du dehors jusqu'aux salles
	var centre: Vector2 = C.regions[grotte]["pos"] - C.tordre(C.regions[grotte]["pos"])
	var bouche := Vector2.INF
	var vers := Vector2.ZERO
	var muraille := 0
	var percee := 0
	for ix in range(-110, 111):
		if bouche != Vector2.INF:
			break
		for iy in range(-110, 111):
			var q: Vector2 = centre + Vector2(ix, iy) * 90.0
			var cr: float = C.creux(q)
			if cr < 0.66 or cr > 0.7:
				continue
			muraille += 1
			if C.plein(q) > -0.05:
				continue
			percee += 1
			var g := Vector2(C.creux(q + Vector2(20, 0)) - C.creux(q - Vector2(20, 0)), C.creux(q + Vector2(0, 20)) - C.creux(q - Vector2(0, 20))).normalized()
			var libre: bool = not C.regions[C.region_en(q - g * 400.0)]["eau"] and C.crete_en(q - g * 330.0) >= 1.0
			for t in range(-320, 520, 20):
				if C.plein(q + g * float(t)) > 0.0 or not C._paroi(q + g * float(t)).is_empty():
					libre = false
					break
			if libre:
				bouche = q
				vers = g
				break
	var dehors: Vector2 = bouche - vers * 330.0
	var dedans := _marcher(dehors, vers, 600)
	# (la roche : le point de muraille pleine le plus proche de la bouche, le long de la frontière)
	var roc := Vector2.INF
	for t in range(60, 1500, 30):
		for cote in [-1.0, 1.0]:
			var q2: Vector2 = bouche + vers.orthogonal() * cote * float(t)
			if roc == Vector2.INF and C.plein(q2) > 0.08:
				roc = q2
	var hors_roc: Vector2 = C.retenir(roc)
	verif(bouche != Vector2.INF and roc != Vector2.INF and percee * 3 < muraille and C.sous_terre(dehors) == 0.0 and C.sous_terre(dedans) > 0.95 and not C.roche_en(dedans)
		and C.roche_en(roc) and not C.roche_en(hors_roc) and hors_roc.distance_to(roc) > 2.0,
		"une grotte est fermée d'une muraille de roche (%d %% de vide) qu'on ne traverse pas ; par une bouche, on entre à pied jusqu'aux salles (%d pixels)" % [
			int(100.0 * percee / maxf(muraille, 1)), int(dehors.distance_to(dedans))])
	# dedans : ni le jour, ni le temps qu'il fait ; de la pierre, pas un arbre
	jeu.horloge = floorf(jeu.horloge / jeu.R.DUREE) * jeu.R.DUREE + jeu.R.DUREE * 0.3
	jo.position = dedans
	W.suivre(dedans, true)
	jeu.climat.forcer("orage", 1.0, 60.0)
	var pluie_dehors: float = jeu.climat.pluie
	jeu.sous_terre = C.sous_terre(dedans)
	jeu.climat.toit = jeu.sous_terre
	for i in 40:
		jeu.climat.avancer(0.1)
	# (à 600 pixels à la ronde : plus loin, on retrouverait les arbres du dehors)
	var arbres: int = W.autour(dedans, 600.0).filter(func(x): return x.couvert() > 0.0 and C.sous_terre(x.position) > 0.5).size()
	var rochers: int = W.autour(dedans, 900.0).filter(func(x): return x.genre == "rocher" and C.sous_terre(x.position) > 0.5).size()
	var dans_la_roche: int = W.objets.filter(func(x): return C.roche_en(x.position)).size()
	verif(jeu.jour_du_ciel() > 0.9 and jeu.lumiere_du_jour() == 0.0 and not jeu.est_jour() and pluie_dehors > 0.8 and jeu.climat.pluie < 0.02 and jeu.climat.orage < 0.02
		and jeu.climat.abri(dedans) == 1.0 and absf(jeu.climat._air_de_fond() - jeu.R.AIR_SOUS_TERRE) < 0.001 and arbres == 0 and rochers >= 1 and dans_la_roche == 0,
		"dedans, en plein jour et sous l'orage : il fait noir, il ne pleut pas, l'air est frais (%.2f) ; de la pierre (%d rochers), pas un arbre (%d), rien dans la roche (%d)" % [
			jeu.climat._air_de_fond(), rochers, arbres, dans_la_roche])
	if arbres > 0 or dans_la_roche > 0 or jeu.lumiere_du_jour() != 0.0 or jeu.climat.pluie >= 0.02:
		print("    (jour du ciel %.2f, lumière %.2f, pluie dehors %.2f, pluie %.3f, orage %.3f, abri %.1f ; dans la roche : %s)" % [jeu.jour_du_ciel(), jeu.lumiere_du_jour(), pluie_dehors,
			jeu.climat.pluie, jeu.climat.orage, jeu.climat.abri(dedans), W.objets.filter(func(x): return C.roche_en(x.position)).map(func(x): return [x.genre, x.position, C.plein(x.position)])])
	# des champignons luisants : on les cueille (de quoi manger), ils s'éteignent, ils repousseront
	var champignons: Array = W.objets.filter(func(x): return x.genre == "champignon")
	var champi = champignons[0] if not champignons.is_empty() else null
	var cueilli := {}
	var luisait := false
	if champi != null:
		luisait = champi.lueur != null and champi.reste == champi.plein
		cueilli = champi.recolter()
		champi.recolter()
	verif(champi != null and luisait and int(cueilli.get("baies", 0)) == 1 and champi.epuise() and champi._repousse > 0.0
		and champignons.filter(func(x): return C.sous_terre(x.position) < 0.6).is_empty(),
		"sous terre poussent des champignons qui luisent (%d autour) : on les cueille pour manger, ils s'éteignent, ils repousseront" % champignons.size())
	# avec l'herbier d'Orvane (en ligne), la flore de la grotte est la sienne : chaque forme de champignon a son dessin et sa règle
	Orvane.ajouter_herbier("grotte", {"plantes": {
		"flore-grotte-champignon": {"nom": "Febel champignon", "forme": "champignon", "port": "champignon", "hauteur_m": 0.1, "part": 0.3, "defense": ["epineux"]},
		"flore-grotte-moisissure": {"nom": "Déon moisissure", "forme": "moisissure", "port": "champignon", "hauteur_m": 0.008, "part": 0.24, "defense": ["epineux"]},
		"flore-grotte-champignon-lumineux": {"nom": "Taon champignon lumineux", "forme": "champignon_lumineux", "port": "champignon", "hauteur_m": 0.16, "part": 0.23, "defense": []},
		"flore-grotte-champignon-geant": {"nom": "Vinfe champignon géant", "forme": "champignon_geant", "port": "champignon", "hauteur_m": 2.0, "part": 0.23, "defense": []}}})
	W.flore_arrivee("grotte")
	var par_forme := {}
	var poses: Array = []
	for k in 60:
		# (des graines étalées, comme celles du semis : la plante se tire d'après elle)
		var o = W._poser("champignon", dedans + Vector2(4000.0 + 30.0 * k, 0.0), Color.WHITE, (k * 7919 + 13) * 104729 % 1000003, W.lieu_de("grotte"))
		poses.append(o)
		if not par_forme.has(o.forme):
			par_forme[o.forme] = o
	var lumineux = par_forme.get("champignon_lumineux")
	var ocre = par_forme.get("champignon")
	var geant = par_forme.get("champignon_geant")
	var moisi = par_forme.get("moisissure")
	var toutes: bool = lumineux != null and ocre != null and geant != null and moisi != null
	verif(toutes and par_forme.size() == 4 and lumineux.lueur != null and str(lumineux.plante) == "flore-grotte-champignon-lumineux" and ocre.lueur == null and ocre.plein == 1
		and geant.lueur == null and geant.plein == 2 and geant.rayon > 0.0 and geant.hauteur > ocre.hauteur * 2.0 and moisi.epuise() and moisi.lueur == null
		and int(geant.recolter().get("baies", 0)) == 1,
		"en ligne, la flore d'une grotte est celle de l'herbier d'Orvane : le champignon, le lumineux (lui seul luit), le géant (deux parts, on bute dessus), la moisissure (rien à cueillir)")
	if not toutes or par_forme.size() != 4:
		print("    (formes : %s ; la flore du lieu : %s)" % [par_forme.keys(), W.lieu_de("grotte")["flore"].keys()])
	for o in poses:
		W.retirer(o)
	Orvane.ajouter_herbier("grotte", {})
	W.flore_arrivee("grotte")
	# le noir est celui de la roche, plus profond que la nuit ; on entend des gouttes, la roche qui résonne, rien du dehors
	jeu.camera.reset_smoothing()
	jeu.camera.force_update_scroll()
	jeu._lumieres()
	var teinte_dedans: Color = jeu.effets.teinte
	var ecran_dedans: Color = jeu.obscurite.color
	var journal_avant = jeu.sons.journal
	jeu.sons.journal = []
	for i in 40:
		jeu.sons.maj(jeu, 0.25)
	var entendus: Array = jeu.sons.journal.map(func(x): return str(x[1]).rstrip("0123456789"))
	var echo: float = jeu.sons._espace
	jeu.sons.journal = journal_avant
	var roche: Color = jeu.effets.nuit_roche
	verif(teinte_dedans.is_equal_approx(roche) and ecran_dedans.is_equal_approx(roche) and roche.v < jeu.effets.nuit_monde.v * 0.7
		and entendus.has("goutte") and not entendus.has("grillon") and not entendus.has("oiseau") and not entendus.has("chouette") and echo > 1.0,
		"le noir de la roche est plus profond que la nuit ; on y entend des gouttes (%d en dix secondes) et tout y résonne, ni grillons ni oiseaux" % entendus.count("goutte"))
	# du dehors, devant la bouche : il fait jour où l'on est, et la grotte reste sombre (le jour du dehors est une lumière masquée)
	jeu.sous_terre = 0.0
	jeu.climat.toit = 0.0
	jo.position = dehors
	jeu.camera.reset_smoothing()
	jeu.camera.force_update_scroll()
	jeu._lumieres()
	var lum = jeu.effets._lum_dehors
	verif(jeu.effets.teinte.v > 0.8 and jeu.effets._dehors_etat == 1 and jeu.obscurite.color.is_equal_approx(roche) and lum != null and lum.enabled
		and lum.color.v > 0.5 and jeu.lumiere_du_jour() > 0.9,
		"devant la bouche, il fait jour là où l'on est et la grotte reste noire : le jour du dehors s'arrête à la roche")
	jeu.climat.forcer("clair", 1.0, 600.0)
	jeu.climat.boue = 0.0
	jeu.climat.crue = 0.0
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu.camera.reset_smoothing()
	jeu.camera.force_update_scroll()
	jeu._lumieres()
	jeu._regions()


# marcher droit devant soi, à petits pas que la carte retient : où l'on arrive
func _marcher(de: Vector2, vers: Vector2, pas: int) -> Vector2:
	var p := de
	for i in pas:
		p = jeu.carte.retenir(p + vers.normalized() * 1.5)
	return p




# les pattes à trois os (scripts/bete.gd, _ik3) : la cuisse bouge peu, c'est le jarret qui plie
func _les_pattes() -> void:
	var F: Dictionary = jeu.faune
	var bete = null
	var patte := -1
	for k in ["proies_jour", "proies_nuit", "rodeurs", "chasseurs_nuit"]:
		for e in F[k]:
			if bete != null:
				break
			var b = jeu._creer(e, "proie", jeu.joueur.position + Vector2(300.0, 200.0))
			# (une patte de derrière à trois os : sa hanche est en arrière du milieu)
			for i in b._p_trois.size():
				if b._p_trois[i] and not b._p_devant[i]:
					bete = b
					patte = i
					break
			if bete == null:
				b.queue_free()
	if bete == null:
		verif(false, "une bête à quatre pattes a des pattes arrière à trois os")
		return
	var pts: PackedVector2Array = bete._p_pts[patte]
	var seg: PackedFloat32Array = bete._p_seg[patte]
	var jambe: float = seg[0] + seg[1] + seg[2]
	# au repos : elle retrouve sa pose
	var repos: PackedVector2Array = bete._ik3(patte, pts[0], pts[3], 0.0)
	var ecart := 0.0
	for k in 4:
		ecart = maxf(ecart, repos[k].distance_to(pts[k]))
	# le pli du jarret, compté du côté où il plie au repos (plus grand : plus fermé ; négatif : retourné)
	var sens: float = signf(wrapf((pts[3] - pts[2]).angle() - (pts[2] - pts[1]).angle(), -PI, PI))
	var pli := func(j: PackedVector2Array) -> float: return wrapf((j[3] - j[2]).angle() - (j[2] - j[1]).angle(), -PI, PI) * sens
	var pli_repos: float = pli.call(repos)
	# le pied levé derrière elle (le pas qui se lève) : la cuisse suit peu, le jarret se ferme, rien ne s'arrache
	var derriere: Vector2 = pts[3] + Vector2(-jambe * 0.2, -jambe * 0.16)
	var leve: PackedVector2Array = bete._ik3(patte, pts[0], derriere, 1.0)
	var cuisse := absf(wrapf((leve[1] - leve[0]).angle() - (pts[1] - pts[0]).angle(), -PI, PI))
	var tient := true
	for k in 3:
		var r: float = leve[k].distance_to(leve[k + 1]) / seg[k]
		tient = tient and r > 0.8 and r < 1.2
	# le pied porté en avant, encore levé (le pas qui va se poser) : le jarret ne se retourne pas
	var devant: Vector2 = pts[3] + Vector2(jambe * 0.28, -jambe * 0.12)
	var porte: PackedVector2Array = bete._ik3(patte, pts[0], devant, 0.8)
	verif(ecart < 1.0 and cuisse < 0.65 and float(pli.call(leve)) > pli_repos + 0.15 and tient and leve[3].distance_to(derriere) < jambe * 0.12
		and float(pli.call(porte)) > 0.05 and porte[3].distance_to(devant) < jambe * 0.15,
		"une patte arrière a trois os : au repos elle garde sa pose ; levée derrière, la cuisse suit peu (%.2f rad) et le jarret se ferme (%.2f → %.2f) ; portée en avant, il ne se retourne pas (%.2f)" % [
			cuisse, pli_repos, float(pli.call(leve)), float(pli.call(porte))])
	bete.queue_free()




# ce que l'écran montre du corps qui faiblit (scripts/effets.gd, _le_corps ; shaders/ecran_voile_herbes.gdshader) : rien quand elle
# va bien ; la faim dès 30, bien avant qu'elle ne prenne sur la santé ; sous R.FAIM_MORD, ses crampes, et la caméra qui tangue ;
# la santé qui s'en va, au bord rouge, au cœur lourd qui serre l'image ; le froid qui fait grelotter, la chaleur. Les effets
# tournent ici image par image (0,05 s), le corps tenu à cet état ; et quand la faim revient ronger la santé, c'est redit
func _le_corps_a_l_ecran() -> void:
	print("Le corps à l'écran")
	var j = jeu.joueur
	var garde := {"faim": j.faim, "sante": j.sante, "temp": j.temperature, "peur": j.peur, "feu": j.en_feu}
	j.en_feu = 0.0
	var bien: Dictionary = _tenir_le_corps(100.0, 100.0, 50.0, 8.0)
	var faim_20: Dictionary = _tenir_le_corps(20.0, 100.0, 50.0, 5.0)
	var faim_3: Dictionary = _tenir_le_corps(3.0, 100.0, 50.0, 10.0)
	var blessee: Dictionary = _tenir_le_corps(100.0, 15.0, 50.0, 5.0)
	var gelee: Dictionary = _tenir_le_corps(100.0, 100.0, 12.0, 5.0)
	var brulante: Dictionary = _tenir_le_corps(100.0, 100.0, 92.0, 5.0)
	verif(bien["faim"] < 0.03 and bien["agonie"] < 0.03 and bien["crampe"] < 0.01 and bien["givre"] < 0.03 and bien["fournaise"] < 0.03 and bien["tangue"] < 0.002,
		"elle va bien : l'écran ne montre rien du corps, la caméra ne bouge pas")
	verif(faim_20["faim"] > 0.25 and faim_20["crampe"] < 0.01 and faim_3["faim"] > 0.8 and faim_3["crampe"] > 0.3 and faim_3["tangue"] > 0.008 and faim_3["serre"] > 1.004 and faim_20["tangue"] < 0.002,
		"la faim se voit dès 30, avant qu'elle ne ronge la santé (à 20 : %.2f, sans crampe) ; à 3, le monde se fane (%.2f), les crampes serrent l'image et la caméra tangue (%.3f rad)" % [
			faim_20["faim"], faim_3["faim"], faim_3["tangue"]])
	verif(blessee["agonie"] > 0.55 and blessee["lourd"] > 0.4 and blessee["serre"] > 1.006 and bien["serre"] < 1.0005,
		"la santé qui s'en va (à 15) : le bord rougit (%.2f), un cœur lourd bat et serre l'image à chaque coup" % blessee["agonie"])
	verif(gelee["givre"] > 0.5 and gelee["grelotte"] > 1.0 and brulante["fournaise"] > 0.6 and bien["grelotte"] < 0.2,
		"le froid : le givre gagne l'écran (%.2f) et la caméra grelotte (%.1f pixels) ; la chaleur : la fournaise (%.2f)" % [gelee["givre"], gelee["grelotte"], brulante["fournaise"]])
	# la faim revient ronger la santé : c'est redit (la première fois, c'est le conseil)
	j.faim = 5.0
	jeu._corps(0.05)
	j.faim = 60.0
	jeu._corps(0.05)
	j.faim = 5.0
	jeu._corps(0.05)
	var redit := false
	for m in jeu.ui._messages:
		redit = redit or (is_instance_valid(m[0]) and str(m[0].text).contains("La faim te ronge"))
	verif(redit, "quand la faim revient ronger la santé, c'est redit : « La faim te ronge. Mange (E). »")
	j.faim = garde["faim"]
	j.sante = garde["sante"]
	j.temperature = garde["temp"]
	j.peur = garde["peur"]
	j.en_feu = garde["feu"]
	_tenir_le_corps(j.faim, j.sante, j.temperature, 4.0)


func _tenir_le_corps(faim: float, sante: float, temp: float, secondes: float) -> Dictionary:
	var j = jeu.joueur
	var Fx = jeu.effets
	var V: ShaderMaterial = Fx._ecran.voile
	var vu := {"faim": 0.0, "crampe": 0.0, "agonie": 0.0, "lourd": 0.0, "givre": 0.0, "fournaise": 0.0, "tangue": 0.0, "grelotte": 0.0, "serre": 1.0}
	var zmin := 99.0
	var zmax := 0.0
	var n := int(secondes / 0.05)
	for i in n:
		j.faim = faim
		j.sante = sante
		j.temperature = temp
		j.peur = 0.0
		Fx._trauma = 0.0
		Fx.maj(0.05)
		# (on lit la seconde moitié : l'état est installé ; les crampes, qui vont et viennent, y passent au moins une fois)
		if i < n / 2:
			continue
		for k in ["faim", "crampe", "agonie", "lourd", "givre", "fournaise"]:
			vu[k] = maxf(float(vu[k]), float(V.get_shader_parameter(k)))
		if Fx.camera != null:
			vu["tangue"] = maxf(float(vu["tangue"]), absf(Fx.camera.rotation))
			vu["grelotte"] = maxf(float(vu["grelotte"]), Fx.camera.offset.length())
			# (ce que le cœur ou la crampe serre, au-delà du cadrage de l'heure : la caméra rapportée à son zoom du moment)
			var serre: float = Fx.camera.zoom.x / (jeu.R.ZOOM * Fx._zoom * Fx.recul)
			zmin = minf(zmin, serre)
			zmax = maxf(zmax, serre)
	vu["serre"] = zmax
	return vu


# ce qui tue (scripts/regles.gd) : la faim, la peur, le froid, la chaleur prennent sur la santé avant leur comble ; une morsure
# compte ; les baies sont rares. Et la fin dit ce qui a pris la veilleuse
func _la_durete() -> void:
	var j = jeu.joueur
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "faim": j.faim, "peur": j.peur, "sante": j.sante, "temp": j.temperature, "trempe": j.trempe, "p": j.position, "maux": jeu._maux.duplicate()}
	# (en plein jour, pour que le noir ne s'en mêle pas)
	jeu.horloge = floorf(jeu.horloge / RR.DUREE) * RR.DUREE + RR.DUREE * 0.3
	var perd := func(faim: float, peur: float) -> float:
		j.faim = faim
		j.peur = peur
		j.sante = 80.0
		jeu._corps(1.0)
		return 80.0 - j.sante
	var faim_basse: float = perd.call(5.0, 0.0)
	var faim_moyenne: float = perd.call(40.0, 0.0)
	var faim_vide: float = perd.call(0.0, 0.0)
	var peur_haute: float = perd.call(100.0, 92.0)
	var peur_moyenne: float = perd.call(100.0, 60.0)
	verif(faim_basse > 0.8 and faim_moyenne <= 0.0 and faim_vide > faim_basse and 100.0 / RR.FAMINE < 60.0 and 100.0 / RR.FAIM < RR.DUREE * 2.0,
		"la faim tue : sous %d elle prend sur la santé (%.1f par seconde à 5, %.1f l'estomac vide : moins d'une minute pour en mourir) ; affamée en %d secondes" % [
			int(RR.FAIM_MORD), faim_basse, faim_vide, int(100.0 / RR.FAIM)])
	verif(peur_haute > 1.0 and peur_moyenne <= 0.0 and 100.0 / RR.PANIQUE < 30.0,
		"la peur tue : au-dessus de %d elle prend sur la santé (%.1f par seconde à 90 ; au comble, moins de trente secondes pour en mourir)" % [int(RR.PEUR_MORD), peur_haute])
	# le froid, la chaleur : ce que coûte une seconde, le corps à cette température (on la lui rend avant chaque mesure)
	var par_le_temps := func(t: float) -> float:
		j.temperature = t
		j.sante = 80.0
		jeu._temps_du_corps(0.05)
		return (80.0 - j.sante) / 0.05
	var gele: float = par_le_temps.call(8.0)
	var frais: float = par_le_temps.call(28.0)
	var bien: float = par_le_temps.call(50.0)
	var brule: float = par_le_temps.call(95.0)
	verif(gele > 1.2 and frais > 0.1 and frais < gele and bien <= 0.0 and brule > 1.5 and 100.0 / RR.FROID_DEGATS < 60.0 and 100.0 / RR.CHAUD_DEGATS < 60.0,
		"le froid tue (%.1f par seconde à 8, il mord dès %d) ; la chaleur aussi (%.1f par seconde à 95, dès %d) ; à 50, rien" % [gele, int(RR.FROID), brule, int(RR.CHAUD)])
	# une morsure
	var F: Dictionary = jeu.faune
	var b = jeu._creer(F["chasseurs_nuit"][0], "chasseur", j.position + Vector2(400.0, 300.0))
	j.sante = 100.0
	jeu.mordre(b)
	var morsure: float = 100.0 - j.sante
	var avant_m: float = 4.0 + 7.0 * log(float(b.masse) + 1.0) / log(10.0)
	verif(morsure > avant_m * 1.4 and morsure < 40.0 and jeu._mordeur == str(b.nom),
		"une morsure compte : %s (%.1f kg) prend %d points de santé (%d avant)" % [b.nom, float(b.masse), int(morsure), int(avant_m)])
	# la fin dit ce qui l'a prise
	jeu._maux = {"froid": 30.0, "faim": 4.0}
	var t_froid: String = jeu._titre_de_fin()
	jeu._maux = {"bete": 20.0, "peur": 6.0}
	var t_bete: String = jeu._titre_de_fin()
	jeu._maux = {"peur": 12.0}
	var t_peur: String = jeu._titre_de_fin()
	jeu._maux = {}
	var t_rien: String = jeu._titre_de_fin()
	verif(t_froid == "Le froid t'a prise." and t_bete == "%s t'a prise." % b.nom and t_peur == "La peur t'a prise." and t_rien.ends_with("t'a prise."),
		"la fin dit ce qui l'a prise : « %s », « %s », « %s » ; sinon « %s »" % [t_froid, t_bete, t_peur, t_rien])
	b.queue_free()
	# les baies : peu de buissons, trois poignées chacun, qui repoussent lentement
	var buissons: Array = jeu.monde.objets.filter(func(x): return x.genre == "buisson")
	var un = null
	for x in buissons:
		# (un buisson à baies : la flore suit l'herbier, et tous ses buissons n'en portent pas — une liane donne des fibres, un
		# buisson d'épines sans fruits son bois mort : scripts/flore.gd)
		if x.intact() and x.butin() == "baies":
			un = x
			break
	var pleins: bool = un != null and un.plein == RR.BAIES_PAR_BUISSON
	var cueillies := 0
	if un != null:
		for k in 4:
			cueillies += int(un.recolter().get("baies", 0))
	verif(buissons.size() <= int(RR.BUISSONS + RR.BUISSONS_HUMIDE) and buissons.size() >= 5 and pleins and cueillies == RR.BAIES_PAR_BUISSON and un._repousse == RR.REPOUSSE_BAIES,
		"les baies sont rares : %d buissons dans le lieu, %d poignées chacun, qui repoussent en %d secondes" % [buissons.size(), cueillies, int(RR.REPOUSSE_BAIES)])
	if un != null:
		un.reprendre("buisson", un.plein, 0.0)
	jeu.horloge = garde["h"]
	j.faim = garde["faim"]
	j.peur = garde["peur"]
	j.sante = garde["sante"]
	j.temperature = garde["temp"]
	j.trempe = garde["trempe"]
	j.position = garde["p"]
	jeu._maux = garde["maux"]




# --- la Noire (scripts/noire.gd) : son scénario, joué acte par acte, sans attendre (noire.maj, puis son corps : bete.gd) ---

# tant de secondes de la Noire, l'horloge arrêtée (la nuit, ou le jour, où l'on est). « voir » est appelé à chaque pas.
func _noire_joue(secondes: float, voir: Callable = Callable()) -> void:
	var N = jeu.noire
	var dt := 0.05
	for i in int(secondes / dt):
		N.maj(dt)
		if N.corps != null and is_instance_valid(N.corps):
			N.corps._conduire(dt)
			N.corps._animer(dt)
		if voir.is_valid():
			voir.call(i * dt)


func _la_noire(F: Dictionary) -> void:
	print("La Noire")
	var j = jeu.joueur
	var N = jeu.noire
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "nuits": jeu.nuits, "p": j.position, "sante": j.sante, "peur": j.peur, "faim": j.faim, "torche": j.torche,
		"feux": jeu.feux.duplicate(), "etait": jeu._etait_nuit, "maux": jeu._maux.duplicate(), "mordeur": jeu._mordeur, "deja": jeu._deja.duplicate()}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	var nuit_h: float = base + RR.DUREE * (1.0 - jeu.part_nuit) + 2.0
	var jour_h: float = base + RR.DUREE * 0.3
	var duree_nuit: float = RR.DUREE * jeu.part_nuit
	j.position = Vector2(-200.0, 100.0)
	j.sante = 100.0
	j.peur = 0.0
	j.torche = 0.0
	jeu.feux.clear()
	var feu = jeu.Feu.new()
	feu.jeu = jeu
	feu.position = j.position + Vector2(30.0, 0.0)
	feu.bois = 40.0
	jeu.monde.add_child(feu)
	var r: float = feu.rayon()

	# sa tanière
	N.commencer()
	var loin: float = N.taniere.distance_to(j.position)
	verif(N.acte == 0 and N.corps == null and loin > 1500.0 and absf(N.taniere.x) <= RR.DEMI and absf(N.taniere.y) <= RR.DEMI,
		"la Noire a sa tanière, loin de la veilleuse (%d pixels), dans le lieu ; rien d'elle avant la première nuit" % int(loin))

	# les premières nuits : rien. Elle dort, elle n'appelle pas, on ne sait rien d'elle
	jeu.horloge = nuit_h
	jeu.feux.append(feu)
	var journal_avant = jeu.sons.journal
	jeu.sons.journal = []
	var calmes := 0
	var venue_tot := false
	for nuit_k in N.premiere_nuit(1):
		jeu.nuits = nuit_k
		N.tombee()
		_noire_joue(duree_nuit * 0.5, func(_t): venue_tot = venue_tot or N.corps != null)
		if N.acte == 0:
			calmes += 1
		N.aube()
	var appels_tot: int = jeu.sons.journal.filter(func(x): return str(x[1]) == "appel").size()
	verif(calmes == N.premiere_nuit(1) and calmes >= 2 and not venue_tot and appels_tot == 0 and N.su.is_empty() and N.acte_de(99) == int(RR.NOIRE_ACTES.max()) and N.acte_de(99) >= 4,
		"les %d premières nuits, la Noire ne vient pas et n'appelle pas ; les actes se suivent ensuite, de nuit en nuit, jusqu'au dernier" % calmes)
	# acte 1 : les signes
	jeu.nuits = N.premiere_nuit(1)
	jeu.sons.journal = []
	N.tombee()
	var corps_vu := [false]
	_noire_joue(duree_nuit, func(_t): corps_vu[0] = corps_vu[0] or N.corps != null)
	var appels: int = jeu.sons.journal.filter(func(x): return str(x[1]) == "appel").size()
	verif(N.acte == 1 and not corps_vu[0] and appels == 1 and N.su.has("appel") and j.sante == 100.0,
		"acte 1, les signes : elle ne vient pas ; un appel dans la nuit (%d), que la veilleuse retient" % appels)
	jeu.horloge = jour_h
	N.aube()
	var T = jeu.traces
	var pres_camp: bool = T.pres(j.position, 420.0, 2)
	var pres_taniere: bool = T.pres(N.taniere, 260.0, 2)
	verif(T.nombre(2) >= 8 and pres_camp and pres_taniere and not T.pres(j.position, 150.0, 2),
		"à l'aube, sa piste : %d empreintes, de la lisière du camp à sa tanière" % T.nombre(2))
	var premiere := Vector2.ZERO
	for e in T._liste:
		if int(e[6]) == 2:
			premiere = Vector2(e[0], e[1])
			break
	var ici: Vector2 = j.position
	j.position = premiere + Vector2(20.0, 0.0)
	_noire_joue(1.2)
	verif(N.su.has("empreintes"), "la veilleuse qui marche sur sa piste reconnaît ses empreintes")
	j.position = ici

	# acte 2 : les yeux
	jeu.nuits = N.premiere_nuit(2)
	jeu.horloge = nuit_h
	var proie = _bete(F["proies_jour"][0], "proie", feu.position + Vector2(-(r + 200.0), 60.0), {})
	N.mettre_en_scene(2, 900.0, PI)
	var m := {"pres_feu": INF, "pres": INF, "guette": false, "face": 0.0, "silence": 0.0, "peur": 0.0, "fuit": false}
	var regarder := func(_t):
		if N.corps == null:
			return
		m["pres_feu"] = minf(m["pres_feu"], N.corps.position.distance_to(feu.position) / r)
		m["pres"] = minf(m["pres"], N.corps.position.distance_to(j.position))
		m["guette"] = m["guette"] or N.etat == "guette"
		m["face"] = maxf(m["face"], N.corps.de_face)
		m["silence"] = maxf(m["silence"], N.silence)
		m["peur"] = maxf(m["peur"], N.peur())
		if is_instance_valid(proie):
			proie._conduire(0.05)
			m["fuit"] = m["fuit"] or proie.etat == "fuit"
	_noire_joue(32.0, regarder)
	verif(N.corps != null and m["guette"] and m["pres_feu"] >= 0.97 and m["face"] > 0.9 and j.sante == 100.0,
		"acte 2, les yeux : elle vient, s'arrête hors de la lumière (au plus près, %.2f rayon du feu) et regarde en face, sans mordre" % m["pres_feu"])
	verif(m["silence"] > 0.9 and N.su.has("silence") and N.su.has("yeux") and m["fuit"] and N.presente() and absf(m["peur"] - RR.NOIRE_PEUR) < 0.01,
		"tout se tait avant elle, les autres bêtes s'enfuient, et la peur monte sous son regard (%.1f par seconde)" % m["peur"])
	verif(T.nombre(2) >= 4, "elle laisse ses empreintes en marchant : %d" % T.nombre(2))
	_oter(proie)
	# (la veilleuse avance sur elle, dans le noir : les yeux s'éteignent, elle recule ; elle ne mord toujours pas)
	var vers_elle: Vector2 = (N.corps.position - j.position).normalized()
	j.position = N.corps.position - vers_elle * 170.0
	feu.bois = 0.0
	var e2 := {"recule": false, "clos": 0.0, "loin": 0.0}
	_noire_joue(22.0, func(_t):
		if N.corps == null:
			return
		e2["recule"] = e2["recule"] or N.etat == "recule"
		e2["clos"] = maxf(e2["clos"], N.corps.yeux_clos)
		e2["loin"] = maxf(e2["loin"], N.corps.position.distance_to(j.position)))
	verif(e2["recule"] and e2["clos"] > 0.9 and e2["loin"] > 400.0 and j.sante == 100.0,
		"si la veilleuse avance sur elle, ses yeux s'éteignent et elle recule (jusqu'à %d pixels) ; vingt secondes dans le noir, pas une morsure" % int(e2["loin"]))
	j.position = ici
	feu.bois = 40.0

	# acte 3 : le siège
	jeu.nuits = N.premiere_nuit(3)
	N.mettre_en_scene(3, 900.0, PI)
	var s3 := {"pres_feu": INF, "tour": 0.0, "avant": NAN, "feinte": false, "feinte_pres": INF}
	_noire_joue(34.0, func(_t):
		if N.corps == null:
			return
		var q: Vector2 = N.corps.position - feu.position
		s3["pres_feu"] = minf(s3["pres_feu"], q.length() / r)
		if N.etat == "feinte":
			s3["feinte"] = true
			s3["feinte_pres"] = minf(s3["feinte_pres"], q.length() / r)
		if (N.etat == "tourne" or N.etat == "guette") and not is_nan(s3["avant"]):
			s3["tour"] += absf(wrapf(q.angle() - float(s3["avant"]), -PI, PI))
		s3["avant"] = q.angle())
	verif(N.acte == 3 and s3["pres_feu"] >= 0.97 and s3["tour"] > 0.5 and j.sante == 100.0 and N.su.has("feu"),
		"acte 3, le siège : un feu vif la tient (au plus près, %.2f rayon), elle tourne autour (%.1f radians) sans mordre" % [s3["pres_feu"], s3["tour"]])
	verif(s3["feinte"] and s3["feinte_pres"] >= 0.97 and s3["feinte_pres"] < 1.06 and N.su.has("feinte") and j.sante == 100.0,
		"elle feinte : elle se jette vers la lumière et s'arrête à son bord (%.2f rayon), sans mordre ; la veilleuse le retient" % s3["feinte_pres"])
	# (vive : plus légère dans ses pas que sa masse ; sa tête suit la veilleuse, en haut puis en bas)
	N._changer("guette")
	N._pose = 99.0
	N._feinte = 99.0
	# (sans écran, la caméra n'a pas suivi la veilleuse : on joue son corps tout droit, comme s'il était à l'image)
	var poser_la_tete := func() -> float:
		for i in 30:
			N.corps._corps(0.0, 0.05, 0.36, 1.0 if N.corps._face >= 0.0 else -1.0)
		return N.corps._tete_rot
	# (elle ne bouge pas ; la veilleuse est devant elle, à 200 pixels : plus loin dans le lieu, puis plus près de nous)
	_noire_joue(1.0)
	N.corps.ordre = "guette"
	var devant_elle: Vector2 = N.corps.position + Vector2(200.0 * (1.0 if N.corps._face >= 0.0 else -1.0), 0.0)
	j.position = devant_elle + Vector2(0.0, -90.0)
	var tete_haut: float = poser_la_tete.call()
	j.position = devant_elle + Vector2(0.0, 90.0)
	var tete_bas: float = poser_la_tete.call()
	# (sa cadence la plus vive : un quart de plus que celle qu'aurait une bête de sa masse, dans cette qualité)
	verif(N.corps._poids < N.corps._lourd and N.corps._f_max > 3.0 * (1.0 if N.corps._fin else 0.82) * 1.25 and tete_bas - tete_haut > 0.12,
		"elle est vive (ses pas : ceux d'une bête de poids %.2f, pour %.2f) et sa tête suit la veilleuse (%.2f radian quand elle monte, %.2f quand elle descend)" % [N.corps._poids, N.corps._lourd, tete_haut, tete_bas])
	# (la veilleuse passe de l'autre côté du feu : elle la suit le long de la lisière)
	var en_face: Vector2 = feu.position - (N.corps.position - feu.position).normalized() * 55.0
	j.position = en_face
	_noire_joue(14.0)
	var entre: float = absf(wrapf((N.corps.position - feu.position).angle() - (j.position - feu.position).angle(), -PI, PI))
	verif(entre < 0.75 and (N.corps.position - feu.position).length() / r >= 0.97 and j.sante == 100.0,
		"la veilleuse fait le tour du feu : elle la suit le long de la lisière, et se retrouve en face d'elle (à %.2f radian)" % entre)
	# (une bûche dans le feu : elle sursaute et s'écarte)
	var avant_gerbe: float = (N.corps.position - feu.position).length()
	N.corps.gerbe(feu)
	var saute: bool = N.etat == "sursaut"
	_noire_joue(0.8)
	var ecartee: float = (N.corps.position - feu.position).length() - avant_gerbe
	_noire_joue(1.5)
	verif(saute and ecartee > 30.0 and N.etat == "guette", "une bûche jetée dans le feu la fait sursauter : elle s'écarte de %d pixels, puis revient guetter" % int(ecartee))
	j.position = ici
	N._pose = 6.0
	# (hors de la lumière, la torche à la main : elle la tient un moment, puis le présage, puis la charge et la morsure)
	j.position = feu.position + Vector2(r + 420.0, 0.0)
	j.torche = 200.0
	var t3 := {"presage": -1.0, "charge": -1.0, "morsure": -1.0, "recule": false, "prise": 0.0, "claque": false, "tendue": 0.0}
	_noire_joue(RR.NOIRE_TORCHE[3] + 22.0, func(t):
		if N.corps == null:
			return
		if t3["presage"] < 0.0 and N.corps.aplatie > 0.5:
			t3["presage"] = t
		t3["claque"] = t3["claque"] or N.corps._claque >= 0.0
		if N.corps.aplatie > 0.5:
			t3["tendue"] = maxf(t3["tendue"], N.corps._bas)
		if t3["charge"] < 0.0 and N.etat == "charge":
			t3["charge"] = t
		if t3["morsure"] < 0.0 and j.sante < 100.0:
			t3["morsure"] = t
			t3["prise"] = 100.0 - j.sante
		if t3["morsure"] >= 0.0:
			t3["recule"] = t3["recule"] or N.etat == "recule")
	verif(absf(t3["presage"] - RR.NOIRE_TORCHE[3]) < 6.0 and absf(t3["charge"] - t3["presage"] - RR.NOIRE_PRESAGE) < 0.3 and t3["morsure"] > t3["charge"] and N.su.has("torche"),
		"hors du feu, la torche la tient %d secondes ; puis elle s'aplatit %.1f s (le présage), charge, et mord %.1f s après" % [int(t3["presage"]), t3["charge"] - t3["presage"], t3["morsure"] - t3["charge"]])
	verif(absf(t3["prise"] - RR.NOIRE_MORSURE) < 0.01 and t3["recule"] and jeu._mordeur == "La Noire",
		"sa morsure prend %d ; elle se reprend un instant après avoir mordu ; la fin dira « La Noire t'a prise. »" % int(RR.NOIRE_MORSURE))
	verif(t3["tendue"] > 0.15 and t3["claque"], "avant de charger elle se tasse au sol (%.2f de sa hauteur de pattes) ; quand elle mord, son corps se jette en avant et sa tête claque" % t3["tendue"])
	# (revenue dans la lumière : elle lâche)
	j.position = ici
	j.sante = 100.0
	_noire_joue(12.0)
	verif(j.sante == 100.0 and (N.etat == "tourne" or N.etat == "guette"), "revenue dans la lumière du feu, la veilleuse n'est plus mordue : elle reprend son siège")
	# (sans torche : le présage tout de suite)
	j.position = feu.position + Vector2(-(r + 380.0), 0.0)
	j.torche = 0.0
	var sans := {"charge": -1.0}
	_noire_joue(4.0, func(t):
		if sans["charge"] < 0.0 and N.etat == "charge":
			sans["charge"] = t)
	verif(sans["charge"] > RR.NOIRE_PRESAGE - 0.2 and sans["charge"] < RR.NOIRE_PRESAGE + 0.6, "sans torche hors du feu : le présage, puis la charge au bout de %.1f s" % sans["charge"])
	j.position = ici
	j.sante = 100.0
	_noire_joue(6.0)

	# les coups : elle ne meurt pas, elle se retire
	var pv0: float = N.corps.pv_max
	var coups := 0
	while not N._retiree and coups < 12:
		N.corps.blesser(RR.DEGATS_LANCE, j.position)
		coups += 1
	verif(coups == int(ceil(RR.NOIRE_ENDURE / RR.DEGATS_LANCE)) and is_instance_valid(N.corps) and N.corps.pv == pv0 and N.etat == "rentre" and N.su.has("coups"),
		"les coups ne la tuent pas : au %de coup de lance, elle se retire" % coups)
	_noire_joue(40.0)
	var partie: bool = N.corps == null and N.etat == "dort"
	_noire_joue(20.0)
	verif(partie and N.corps == null, "retirée, elle rentre à sa tanière et ne revient pas de la nuit")

	# la chasse : plus tôt, et la torche tient moins
	verif(RR.NOIRE_DEPART[4] < RR.NOIRE_DEPART[3] and RR.NOIRE_DEPART[3] < RR.NOIRE_DEPART[2] and RR.NOIRE_TORCHE[4] < RR.NOIRE_TORCHE[3],
		"acte 4, la chasse : elle part plus tôt de sa tanière et la torche la tient moitié moins")

	# plus on dort loin, plus elle arrive tard
	var arrive := func(distance: float) -> float:
		jeu.nuits = N.premiere_nuit(2)
		N.taniere = j.position + Vector2(-distance, 0.0)
		N.ou = N.taniere
		N.etat = "dort"
		N.tombee()
		var quand := [-1.0]
		_noire_joue(duree_nuit, func(t):
			if quand[0] < 0.0 and N.corps != null:
				quand[0] = t)
		return quand[0]
	var pres_t: float = arrive.call(1800.0)
	var loin_t: float = arrive.call(4200.0)
	var jamais: float = arrive.call(9000.0)
	verif(pres_t > 0.0 and loin_t > pres_t + 10.0 and jamais < 0.0,
		"plus on dort loin de sa tanière, plus elle arrive tard : à %d s de la tombée à 1 800 pixels, à %d s à 4 200 ; à 9 000, elle n'arrive pas de la nuit" % [int(pres_t), int(loin_t)])

	# le jour : elle dort dans sa tanière ; trop près, on la réveille
	jeu.horloge = jour_h
	N.tombee()
	N.acte = 3
	N.taniere = ici + Vector2(1200.0, 300.0)
	N.ou = N.taniere
	N.etat = "dort"
	N.taniere_connue = false
	j.position = N.taniere + Vector2(-600.0, 0.0)
	_noire_joue(3.0)
	var dort: bool = N.corps != null and N.corps.ordre == "dort" and N.corps.couchee > 0.9 and N.corps.paupiere() < 0.1 and not N.taniere_connue
	j.position = N.taniere + Vector2(-300.0, 0.0)
	_noire_joue(1.0)
	verif(dort and N.taniere_connue and N.su.has("taniere") and N.etat == "dort" and j.sante == 100.0,
		"le jour, elle dort dans sa tanière, couchée, les yeux clos ; qui la trouve le note, et elle ne se réveille pas à 300 pixels")
	var ancienne: Vector2 = N.taniere
	j.position = N.taniere + Vector2(-(RR.NOIRE_REVEIL - 10.0), 0.0)
	var reveil := [false]
	_noire_joue(12.0, func(_t): reveil[0] = reveil[0] or (N.etat == "charge" and N._colere > 0.0))
	verif(reveil[0] and absf(100.0 - j.sante - RR.NOIRE_MORSURE) < 0.01 and N.taniere.distance_to(ancienne) > 800.0 and not N.taniere_connue and (N.etat == "rentre" or N.etat == "dort"),
		"à %d pixels, on la réveille : elle charge, mord une fois, même de jour, puis s'en va faire sa tanière ailleurs (à %d pixels de l'ancienne)" % [int(RR.NOIRE_REVEIL), int(N.taniere.distance_to(ancienne))])
	j.sante = 100.0

	# elle suit : sa tanière trop loin à l'aube, elle en prend une autre
	N._disparaitre()
	N.etat = "dort"
	N.acte = 2
	j.position = ici
	N.taniere = ici + Vector2(RR.NOIRE_SUIT + 900.0, 0.0)
	N.aube()
	verif(N.taniere.distance_to(ici) < RR.NOIRE_SUIT, "si la veilleuse s'est trop éloignée, à l'aube elle change de tanière pour la suivre (à %d pixels)" % int(N.taniere.distance_to(ici)))

	# la partie gardée
	N.taniere_connue = true
	var photo: Dictionary = JSON.parse_string(JSON.stringify(N.photo()))
	var N2 = jeu.Noire.new()
	N2.jeu = jeu
	N2.commencer()
	N2.reprendre(photo)
	verif(N2.acte == N.acte and N2.taniere.distance_to(N.taniere) < 0.2 and N2.taniere_connue and N2.su.size() == N.su.size() and N2.su.has("taniere") and N.savoirs().size() == N.su.size(),
		"la partie gardée retient l'acte, sa tanière et ce qu'on sait d'elle (%d choses apprises)" % N.su.size())

	# les empreintes des autres bêtes
	T.vider()
	var marcheuse = null
	for e in F["chasseurs_nuit"] + F["proies_jour"]:
		var b = _bete(e, "proie", ici + Vector2(300.0, 200.0), {})
		if b._trace_pas > 0.0:
			marcheuse = b
			break
		_oter(b)
	if marcheuse != null:
		marcheuse.conduite = false
		for i in 200:
			marcheuse.position += Vector2(2.0, 0.0)
			marcheuse._animer(0.05)
	verif(marcheuse != null and T.nombre(marcheuse._trace_genre) >= 3 and T.nombre(2) == 0,
		"les autres bêtes laissent aussi leurs empreintes : %d en 400 pixels de marche" % (T.nombre(marcheuse._trace_genre) if marcheuse != null else 0))
	_oter(marcheuse)

	# (tout remis comme avant)
	T.vider()
	jeu.sons.journal = journal_avant
	jeu.feux.clear()
	for f in garde["feux"]:
		jeu.feux.append(f)
	feu.queue_free()
	jeu.horloge = garde["h"]
	jeu.nuits = garde["nuits"]
	jeu._etait_nuit = garde["etait"]
	jeu._maux = garde["maux"]
	jeu._mordeur = garde["mordeur"]
	jeu._deja = garde["deja"]
	j.position = garde["p"]
	j.sante = garde["sante"]
	j.peur = garde["peur"]
	j.faim = garde["faim"]
	j.torche = garde["torche"]
	N.commencer()


# --- le pistage (scripts/pistage.gd) : l'affût, les pistes, le carnet des bêtes ---

func _le_pistage(F: Dictionary) -> void:
	print("Le pistage")
	var j = jeu.joueur
	var Pi = jeu.pistage
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "p": j.position, "torche": j.torche, "savoir": jeu.savoir.duplicate(), "vues": jeu.vues.duplicate(),
		"mouvement": j.en_mouvement, "deja": jeu._deja.duplicate(), "su": jeu.noire.su.duplicate()}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	var jour_h: float = base + RR.DUREE * 0.3
	var nuit_h: float = base + RR.DUREE * (1.0 - jeu.part_nuit) + 2.0
	jeu.horloge = jour_h
	jeu.savoir.clear()
	jeu.traces.vider()
	j.position = Vector2(900.0, -700.0)
	j.torche = 0.0
	j.en_mouvement = false
	var e: Dictionary = F["proies_jour"][0]
	var id := str(e["id"])
	var b = _bete(e, "proie", j.position + Vector2(200.0, 30.0), {})
	jeu.vues[id] = b.nom
	var joue := func(secondes: float) -> void:
		for i in int(round(secondes / 0.1)):
			Pi.maj(0.1)
	# l'affût : immobile, près d'une bête qu'on voit et qui vaque
	joue.call(3.0)
	var a3: float = jeu.savoir.get(id, 0.0)
	verif(Pi.cible == b and absf(a3 - 3.0) < 0.15 and Pi.niveau(id) == 0 and absf(Pi.part(id) - 0.5) < 0.05,
		"à l'affût, immobile, la veilleuse observe la bête la plus proche : %.1f s d'affût en 3 s, la jauge à moitié" % a3)
	j.en_mouvement = true
	joue.call(2.0)
	var marche: bool = Pi.cible == null and absf(float(jeu.savoir[id]) - a3) < 0.01
	j.en_mouvement = false
	b.etat = "fuit"
	joue.call(2.0)
	var fuite: bool = Pi.cible == null and absf(float(jeu.savoir[id]) - a3) < 0.01
	b.etat = "repos"
	jeu.horloge = nuit_h
	joue.call(2.0)
	var noir: bool = Pi.cible == null and absf(float(jeu.savoir[id]) - a3) < 0.01 and jeu.eclairage(b.position) < 0.3
	jeu.horloge = jour_h
	b.position = j.position + Vector2(Pi.PORTEE + 40.0, 0.0)
	joue.call(2.0)
	var loin: bool = Pi.cible == null and absf(float(jeu.savoir[id]) - a3) < 0.01
	b.position = j.position + Vector2(200.0, 30.0)
	verif(marche and fuite and noir and loin, "rien ne s'apprend en marchant, d'une bête qui fuit, dans le noir, ni de trop loin ; et rien n'est perdu")
	var p0: Dictionary = Pi.page(jeu, id)
	joue.call(3.2)
	var p1: Dictionary = Pi.page(jeu, id)
	verif(Pi.niveau(id) == 1 and p0["lignes"].is_empty() and p0["reste"] != "" and p1["lignes"].size() >= 4 and p1["lignes"][0] == "Une proie." and p1["reste"] != "",
		"six secondes : elle est observée, et le carnet dit ce qu'elle est (%d lignes : %s)" % [p1["lignes"].size(), " ".join(p1["lignes"])])
	joue.call(13.0)
	var p2: Dictionary = Pi.page(jeu, id)
	var plein: float = jeu.savoir[id]
	joue.call(2.0)
	verif(Pi.niveau(id) == 2 and p2["lignes"].size() >= p1["lignes"].size() + 3 and p2["reste"] == "" and Pi.cible == null and jeu.savoir[id] == plein and plein == Pi.CONNUE,
		"dix-huit secondes : elle est connue, le carnet dit comment l'approcher et ce qu'elle vaut (%d lignes de plus) ; il n'y a plus rien à en apprendre" % (p2["lignes"].size() - p1["lignes"].size()))
	# un chasseur : sa morsure, la torche
	var c: Dictionary = F["chasseurs_nuit"][0]
	jeu.vues[str(c["id"])] = str(c["nom"])
	jeu.savoir[str(c["id"])] = Pi.CONNUE
	var pc: Dictionary = Pi.page(jeu, str(c["id"]))
	var texte: String = " ".join(pc["lignes"])
	verif(texte.contains("chasseur") and texte.contains("morsure") and (texte.contains("torche") or texte.contains("charge")) and texte.contains("coup"),
		"d'un chasseur connu, le carnet dit la morsure, la torche et les coups qu'il faut : « %s »" % texte)
	# les pistes
	jeu.traces.vider()
	jeu.savoir.erase(id)
	jeu.traces.poser(j.position + Vector2(12.0, 0.0), 0.0, 5.0, 60.0, 0, id)
	Pi._sol = 0.0
	Pi.maj(0.05)
	var dit1: String = Pi.dernier_dit
	var gagne: float = jeu.savoir.get(id, 0.0)
	Pi.dernier_dit = ""
	Pi._sol = 0.0
	Pi.maj(0.05)
	verif(dit1.contains(b.nom) and dit1.contains("toute fraîche") and dit1.contains("l'est") and absf(gagne - Pi.PISTE) < 0.01 and Pi.dernier_dit == "",
		"sur des empreintes, elle lit la piste : « %s » ; cela vaut %.1f s d'affût, une fois par bête et par moment" % [dit1, gagne])
	jeu.traces.vider()
	jeu.traces.poser(j.position + Vector2(0.0, 10.0), PI * 0.5, 5.0, 60.0, 1, "jamais-vue")
	Pi._sol = 0.0
	Pi.maj(0.05)
	var dit2: String = Pi.dernier_dit
	jeu.traces.vider()
	jeu.noire.su["empreintes"] = true
	jeu.traces.poser(j.position + Vector2(-10.0, 0.0), -PI * 0.5, 20.0, 60.0, 2, "la-noire")
	Pi._sol = 0.0
	Pi.maj(0.05)
	verif(dit2.contains("pas encore vue") and dit2.contains("le sud") and Pi.dernier_dit.contains("la Noire") and Pi.dernier_dit.contains("le nord") and Pi.cap(PI) == "l'ouest",
		"la piste d'une bête jamais vue se lit sans son nom, celle de la Noire se reconnaît ; chacune dit vers où elle va")
	# (tout remis comme avant)
	_oter(b)
	jeu.traces.vider()
	jeu.horloge = garde["h"]
	j.position = garde["p"]
	j.torche = garde["torche"]
	j.en_mouvement = garde["mouvement"]
	jeu.savoir = garde["savoir"]
	jeu.vues = garde["vues"]
	jeu._deja = garde["deja"]
	jeu.noire.su = garde["su"]


# --- les empreintes (scripts/traces.gd, shaders/empreinte.gdshader) : le pied de la bête, son poids, le sol, l'eau ---

func _les_empreintes(F: Dictionary) -> void:
	print("Les empreintes")
	var j = jeu.joueur
	var T = jeu.traces
	var C = jeu.climat
	var garde := {"h": jeu.horloge, "p": j.position, "pluie": C.pluie, "temps": C.temps, "boue": C.boue, "neige": C.neige_sol, "crue": C.crue}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	jeu.horloge = floorf(jeu.horloge / jeu.R.DUREE) * jeu.R.DUREE + jeu.R.DUREE * 0.3
	C.pluie = 0.0
	C.temps = "clair"
	C.boue = 0.0
	C.neige_sol = 0.0
	C.crue = 0.0
	T.vider()
	# le pied de chaque bête fait son empreinte
	var genres := {}
	var pieds := {}
	var lourde = null
	var legere = null
	var tous: Array = F["proies_jour"] + F["proies_nuit"] + F["rodeurs"] + F["chasseurs_nuit"]
	for e in tous:
		var b = _bete(e, "proie", j.position + Vector2(400.0, 300.0), {})
		if b._trace_pas > 0.0:
			var pied := str(b._sq["pattes"][0].get("pied_genre", "")) if not b._sq.is_empty() and not b._sq["pattes"].is_empty() else ""
			genres[b._trace_genre] = true
			pieds[pied] = b._trace_genre
			if lourde == null or b.masse > lourde.masse:
				if lourde != null and lourde != legere:
					_oter(lourde)
				lourde = b
				continue
			if legere == null or b.masse < legere.masse:
				if legere != null and legere != lourde:
					_oter(legere)
				legere = b
				continue
		_oter(b)
	var bon := true
	for pied in pieds:
		if T.GENRES.has(pied) and int(T.GENRES[pied]) != int(pieds[pied]):
			bon = false
	verif(genres.size() >= 2 and bon and not genres.has(2),
		"le pied de chaque bête fait son empreinte : %d genres dans ce lieu (%s), aucun n'est celui de la Noire" % [genres.size(), ", ".join(pieds.keys())])
	var fond_marche: float = lourde._trace_fond()
	lourde._course = 1.0
	var fond_course: float = lourde._trace_fond()
	lourde._course = 0.0
	verif(lourde != null and legere != null and fond_marche > legere._trace_fond() + 0.05 and fond_course > fond_marche + 0.1,
		"une bête lourde marque davantage (%.2f pour %d kg, %.2f pour %.1f kg), et plus encore quand elle court (%.2f)" % [fond_marche, int(lourde.masse), legere._trace_fond(), legere.masse, fond_course])
	# chaque pied pose la sienne : deux files, de part et d'autre de sa marche
	lourde.conduite = false
	lourde.position = j.position + Vector2(-160.0, 120.0)
	lourde._premiere = true
	var y0: float = lourde.position.y
	for i in 260:
		lourde.position += Vector2(1.6, 0.0)
		lourde._animer(0.05)
	var dessus := 0
	var dessous := 0
	for e in T._liste:
		if float(e[T.Y]) < y0 - 1.0:
			dessus += 1
		elif float(e[T.Y]) > y0 + 1.0:
			dessous += 1
	verif(dessus >= 2 and dessous >= 2 and T.nombre(lourde._trace_genre) == dessus + dessous,
		"en marchant, ses pieds laissent deux files d'empreintes (%d d'un côté, %d de l'autre, en %d pixels)" % [dessus, dessous, 416])
	_oter(lourde)
	_oter(legere)
	# le sol : nu là où la veilleuse s'éveille, couvert plus loin
	T.vider()
	T.poser(Vector2(4.0, 3.0), 0.0, 6.0, 500.0, 0, "x", 0.7)
	var nu: float = T._liste[0][T.COUVERT]
	var couvert_max := 0.0
	for k in 24:
		T.poser(Vector2(700.0 + 90.0 * k, -600.0 + 55.0 * k), 0.0, 6.0, 500.0, 0, "x", 0.7)
		couvert_max = maxf(couvert_max, float(T._liste[T._liste.size() - 1][T.COUVERT]))
	verif(nu < 0.25 and couvert_max > 0.3, "le sol compte : la terre nue du réveil la prend nette (%.2f de couvert), l'herbe et la litière se couchent seulement (jusqu'à %.2f)" % [nu, couvert_max])
	# l'eau : la pluie la remplit, le beau temps la sèche
	T.vider()
	T.poser(Vector2(4.0, 3.0), 0.0, 6.0, 5000.0, 0, "x", 0.7)
	var e0: Array = T._liste[0]
	var sec: float = e0[T.EAU]
	C.pluie = 1.0
	C.temps = "pluie"
	for i in 12:
		T.maj(0.34)
	var mi: float = e0[T.EAU]
	for i in 30:
		T.maj(0.34)
	var pleine: float = e0[T.EAU]
	C.pluie = 0.0
	C.temps = "clair"
	for i in 60:
		T.maj(0.34)
	var apres: float = e0[T.EAU]
	verif(sec == 0.0 and mi > 0.3 and mi < 0.6 and pleine == 1.0 and apres < 1.0 and apres > 0.5,
		"sous la pluie, l'empreinte se remplit : %.2f en 4 secondes, pleine en 14 ; le beau temps revenu, elle sèche lentement (%.2f vingt secondes après)" % [mi, apres])
	# un sol gorgé : l'eau y sourd tout de suite ; la neige : pas d'eau, et elle part à la fonte
	C.boue = 0.85
	T.poser(Vector2(40.0, 3.0), 0.0, 6.0, 5000.0, 0, "x", 0.7)
	var sourd: float = T._liste[T._liste.size() - 1][T.EAU]
	C.boue = 0.0
	C.neige_sol = 0.6
	T.poser(Vector2(80.0, 3.0), 0.0, 6.0, 5000.0, 0, "x", 0.7)
	var en_neige: Array = T._liste[T._liste.size() - 1]
	C.pluie = 1.0
	for i in 12:
		T.maj(0.34)
	var neige_seche: bool = float(en_neige[T.NEIGE]) == 1.0 and float(en_neige[T.EAU]) == 0.0
	C.pluie = 0.0
	C.neige_sol = 0.0
	for i in 20:
		T.maj(0.34)
	verif(sourd > 0.3 and neige_seche and not T._liste.has(en_neige) and T._liste.has(e0),
		"dans un sol gorgé l'eau y sourd aussitôt (%.2f) ; dans la neige elle reste sèche, et s'en va quand la neige fond" % sourd)
	# la crue : on n'y marque pas, et celle qui y était disparaît sous l'eau
	var creux := Vector2.ZERO
	var trouve := false
	C.crue = 0.6
	for k in 400:
		var q := Vector2(-1500.0 + 37.0 * (k % 80), -900.0 + 190.0 * (k / 80))
		if float(C.eau(q)) > 0.3:
			creux = q
			trouve = true
			break
	C.crue = 0.0
	T.vider()
	T.poser(creux, 0.0, 6.0, 5000.0, 0, "x", 0.7)
	C.crue = 0.6
	T.poser(creux + Vector2(3.0, 0.0), 0.0, 6.0, 5000.0, 0, "x", 0.7)
	T.maj(0.34)
	var noyee: bool = T._liste.size() == 1 and bool(T._liste[0][T.NOYEE]) and T.la_plus_proche(creux, 30.0).is_empty()
	C.crue = 0.0
	T.maj(0.34)
	verif(trouve and noyee and not bool(T._liste[0][T.NOYEE]), "sous la crue on ne marque pas, et l'empreinte qui était là disparaît sous l'eau ; l'eau retirée, elle reparaît")
	# (tout remis comme avant)
	T.vider()
	C.pluie = garde["pluie"]
	C.temps = garde["temps"]
	C.boue = garde["boue"]
	C.neige_sol = garde["neige"]
	C.crue = garde["crue"]
	jeu.horloge = garde["h"]
	j.position = garde["p"]


# --- l'atelier (scripts/atelier.gd) : ce qu'elle fabrique, porte, pose, et ce que chaque chose change ---

func _l_atelier(F: Dictionary) -> void:
	print("L'atelier")
	var j = jeu.joueur
	var A = jeu.atelier
	var C = jeu.climat
	var RR = jeu.R
	var garde := {"h": jeu.horloge, "p": j.position, "inv": j.inventaire.duplicate(), "sante": j.sante, "faim": j.faim, "peur": j.peur, "temp": j.temperature,
		"trempe": j.trempe, "torche": j.torche, "pluie": C.pluie, "air": C.air, "vent": C.vent, "chassees": jeu.chassees, "prel": jeu.prelevements.duplicate(),
		"feux": jeu.feux.duplicate(), "regard": j.regard, "deja": jeu._deja.duplicate()}
	for b in get_tree().get_nodes_in_group("betes"):
		_oter(b)
	var base: float = floorf(jeu.horloge / RR.DUREE) * RR.DUREE
	var jour_h: float = base + RR.DUREE * 0.3
	var nuit_h: float = base + RR.DUREE * (1.0 - jeu.part_nuit) + 2.0
	jeu.horloge = jour_h
	jeu.feux.clear()
	C.pluie = 0.0
	j.torche = 0.0
	j.regard = 1.0
	# (un endroit sans arbre au-dessus de la tête, le sol sec devant elle, sans buisson où poser l'établi ; le lieu est tiré au sort)
	var ici := Vector2(60.0, 40.0)
	for k in 160:
		var q := Vector2(60.0 + 55.0 * (k % 16), 40.0 + 60.0 * (k / 16))
		var devant_q := q + Vector2(60.0, 6.0)
		if float(C.abri(q)) == 0.0 and float(C.eau(q)) <= 0.05 and float(C.eau(devant_q)) <= 0.05 \
				and jeu.monde.autour(devant_q, 60.0).filter(func(x): return str(x.genre) == "buisson").is_empty():
			ici = q
			break
	j.position = ici
	A.commencer()
	var inv: Dictionary = j.inventaire
	var donner := func(d: Dictionary) -> void:
		for k in d:
			inv[k] = d[k]

	# la liste se tient
	var bon: bool = A.ORDRE.size() == A.OBJETS.size()
	var familles := {}
	for f in A.FAMILLES:
		familles[f[0]] = true
	for id in A.ORDRE:
		var o: Dictionary = A.OBJETS.get(id, {})
		if o.is_empty() or str(o.get("nom", "")) == "" or str(o.get("dit", "")) == "" or not familles.has(o.get("famille")) or not (o.get("ou") in ["main", "etabli"]):
			bon = false
		for k in o.get("cout", {}):
			if not (A.MATIERES.has(k) or k == "baies") or int(o["cout"][k]) <= 0:
				bon = false
		if bool(o.get("pose", false)) and not (str(o["famille"]) in ["camp", "jardin", "elevage"]):
			bon = false
	verif(bon, "l'atelier a %d choses à fabriquer, chacune avec son nom, sa phrase, sa famille et ce qu'elle coûte en matières connues" % A.ORDRE.size())

	# l'établi, de ses mains ; le reste, à l'établi
	donner.call({"bois": 20, "pierre": 10, "fibre": 20})
	var sans: String = A.empeche("corde")
	var fait: bool = A.fabriquer("etabli")
	var paye: bool = int(inv["bois"]) == 14 and int(inv["pierre"]) == 8 and int(inv["fibre"]) == 18 and A.possede("etabli") == 1
	var pose: bool = A.poser("etabli")
	var etabli = A.poses[0] if A.poses.size() == 1 else null
	verif(sans.contains("établi") and fait and paye and pose and etabli != null and A.possede("etabli") == 0 and etabli.position.distance_to(j.position) < 80.0 and A.pres_d_un_etabli(),
		"l'établi se fabrique de ses mains (6 bois, 2 pierres, 2 fibres) et se pose devant elle ; sans lui, rien d'autre ne se fait (« %s »)" % sans)
	var corde: bool = A.fabriquer("corde")
	var rien: bool = not A.fabriquer("tente")
	verif(corde and int(inv["corde"]) == 1 and int(inv["fibre"]) == 15 and rien and int(inv["corde"]) == 1 and A.possede("tente") == 0 and not A.manque("tente").is_empty(),
		"à l'établi, trois fibres font une corde ; ce qu'elle n'a pas de quoi faire ne se fait pas, et ne lui prend rien")

	# ce qu'elle porte : sans sac, vingt de chaque ; avec, quarante
	donner.call({"bois": 18, "peau": 6, "corde": 4, "bache": 4, "fibre": 12})
	var entre: int = A.ranger("bois", 10)
	var cap0: int = A.capacite()
	var sac: bool = A.fabriquer("sac_a_dos")
	var entre2: int = A.ranger("bois", 10)
	verif(entre == 2 and cap0 == 20 and sac and A.porte("sac_a_dos") and A.capacite() == 40 and entre2 == 10 and bool(j.tenue.get("sac", false)) and A.empeche("sac_a_dos") != "",
		"sans sac elle porte vingt de chaque matière (deux bois sur dix sont entrés) ; le sac à dos, cousu, se porte aussitôt, se voit sur elle, et double ce qu'elle porte")
	A.basculer("sac_a_dos")
	var ote: bool = not A.porte("sac_a_dos") and A.capacite() == 20 and not bool(j.tenue.get("sac", false))
	A.basculer("sac_a_dos")
	verif(ote and A.porte("sac_a_dos"), "une tenue s'ôte et se remet")
	verif(A.peaux_de(2.0) >= 1 and A.peaux_de(300.0) > A.peaux_de(2.0) and A.peaux_de(900.0) <= 4, "la chasse donne des peaux : %d pour une bête de 2 kg, %d pour une de 300" % [A.peaux_de(2.0), A.peaux_de(300.0)])

	# la pelisse contre le froid, la cape contre la pluie (trente secondes de grand froid prennent sur la santé : on la lui rend après
	# chaque mesure, sinon, déjà mordue plus tôt dans l'essai, elle en mourait une fois sur quelques-unes)
	var sante_avant: float = j.sante
	var refroidir := func() -> float:
		j.temperature = 50.0
		j.trempe = 0.0
		for i in 30:
			j.sante = 100.0
			jeu._temps_du_corps(1.0)
		return j.temperature
	C.air = 0.12
	C.vent = 0.0
	var nue: float = refroidir.call()
	A.fabriquer("vetement_chaud")
	var couverte: float = refroidir.call()
	verif(A.porte("vetement_chaud") and couverte > nue + 8.0 and couverte < 50.0, "la pelisse coupe le froid : par grand froid, son corps tombe à %d sans elle, à %d avec" % [int(nue), int(couverte)])
	C.air = 0.5
	var se_mouiller := func() -> float:
		j.trempe = 0.0
		j.temperature = 50.0
		for i in 6:
			jeu._temps_du_corps(1.0)
		return j.trempe
	C.pluie = 1.0
	var mouillee: float = se_mouiller.call()
	A.fabriquer("vetement_pluie")
	var au_sec: float = se_mouiller.call()
	C.pluie = 0.0
	j.sante = sante_avant
	verif(A.porte("vetement_pluie") and mouillee > 10.0 and au_sec < mouillee * 0.3, "la cape de pluie : six secondes d'averse la trempent à %d sans elle, à %d avec" % [int(mouillee), int(au_sec)])

	# la tente : un abri
	donner.call({"bois": 12, "corde": 6, "bache": 6})
	j.position = ici + Vector2(0.0, 160.0)
	A.fabriquer("corde")
	j.position = ici
	verif(A.fabriquer("tente") and A.possede("tente") == 1, "à l'établi : une tente (2 bâches, 2 cordes, 4 bois)")
	j.position = ici + Vector2(-220.0, 30.0)
	j.regard = -1.0
	# (la flore d'Orvane sème des buissons de toutes formes, et un buisson empêche de poser : on fait la place devant elle)
	for x in jeu.monde.autour(A._devant("tente"), 90.0):
		if str(x.genre) == "buisson":
			jeu.monde.retirer(x)
	var posee: bool = A.poser("tente")
	var tente = A.poses[A.poses.size() - 1]
	verif(posee and str(tente.genre) == "tente" and A.abri(tente.position) == 1.0 and C.abri(tente.position) == 1.0 and A.abri(tente.position + Vector2(90.0, 0.0)) == 0.0,
		"posée, la tente abrite qui s'y tient (de la pluie, du vent), pas ce qui est à côté")

	# le thème de l'écran-titre (scripts/sons_theme.gd) : un morceau d'un seul tenant, fait pas à pas
	var MorceauTitre = load("res://scripts/sons_theme.gd")
	var chantier = MorceauTitre.Chantier.new()
	var pas_theme := 0
	while not chantier.avancer(4000) and pas_theme < 5000:
		pas_theme += 1
	var crete_t := 0.0
	var carre_t := 0.0
	var trou_t := 0
	var silence_t := 0
	var taux_t: int = MorceauTitre.TAUX
	for i in chantier.s.size():
		var x: float = chantier.s[i]
		crete_t = maxf(crete_t, absf(x))
		carre_t += x * x
		# (un trou : plus d'un quart de seconde de silence avant la dernière mesure)
		silence_t = silence_t + 1 if absf(x) < 0.004 else 0
		if silence_t > taux_t / 4 and i < int((MorceauTitre.DUREE - MorceauTitre.MESURE) * taux_t):
			trou_t += 1
	var rms_t := sqrt(carre_t / chantier.s.size())
	verif(chantier.fini and pas_theme > 8 and chantier.pcm.size() == MorceauTitre.octets() and crete_t > 0.7 and crete_t <= 0.86 and rms_t > 0.1 and rms_t < 0.4 and trou_t == 0
		and absf(chantier.s[chantier.s.size() - 1]) < 0.002 and absf(MorceauTitre.PERIODE - 40.8) < 0.01,
		"le thème de l'écran-titre se fabrique pas à pas (%d pas), d'un seul tenant (%d secondes, sans un trou), et s'éteint sans claquer ; il reprend toutes les %.1f secondes" % [pas_theme, int(MorceauTitre.DUREE), MorceauTitre.PERIODE])

	# ce qu'on entend à l'établi et au camp (scripts/sons_atelier.gd)
	var SA = load("res://scripts/sons_atelier.gd")
	var rs := RandomNumberGenerator.new()
	rs.seed = 7
	var sonnent := true
	var le_pire := ""
	for nom in SA.NOMS:
		var a: Array = SA.fabriquer(nom, rs)
		var crete := 0.0
		if a.size() == 2:
			for x in a[0]:
				crete = maxf(crete, absf(x))
		if a.size() != 2 or a[0].size() < 200 or crete < 0.05 or crete > 1.0 or is_nan(crete):
			sonnent = false
			le_pire = str(nom)
	var journal_a = jeu.sons.journal
	jeu.sons.journal = []
	donner.call({"fibre": 12, "corde": 2})
	var ou_a: Vector2 = j.position
	j.position = ici
	A.fabriquer("corde")
	j.position = ou_a
	A.basculer("sac_a_dos")
	A.basculer("sac_a_dos")
	var geste_corde: String = str(j.atelier)
	# (le maillet : son geste, puis son coup, qui sonne et fait sauter des copeaux de l'établi)
	j.position = ici
	j.geste_atelier("marteler")
	var geste_maillet: String = str(j.atelier)
	var copeaux0: int = etabli._copeaux.size()
	jeu._sur_impact(etabli.position, "marteler")
	var copeaux1: int = etabli._copeaux.size()
	j.atelier = ""
	j.position = ou_a
	var entendus_a: Array = jeu.sons.journal.map(func(x): return str(x[1]).rstrip("0123456789"))
	jeu.sons.journal = journal_a
	verif(geste_corde == "coudre" and geste_maillet == "marteler" and copeaux1 > copeaux0 and entendus_a.has("marteau"),
		"elle a ses gestes d'atelier (tresser une corde : « %s ») ; quand le maillet tombe, il sonne, et des copeaux sautent de l'établi (%d)" % [geste_corde, copeaux1 - copeaux0])
	verif(sonnent and entendus_a.has("tresse") and entendus_a.has("sangle") and jeu.sons._couches.has("bouillon") and jeu.sons._couches.has("fil"),
		"les %d sons de l'atelier se fabriquent, sans crête folle%s ; une corde qu'on tresse, un sac qu'on boucle s'entendent" % [SA.NOMS.size(), "" if le_pire == "" else " (sauf « %s »)" % le_pire])

	# ce qui est posé tient sa place dans le lieu
	var Camp = load("res://scripts/campement.gd")
	var ouvrage: float = float(etabli.etat.get("travail", 0.0))
	A.maj(2.0)
	var bute: Vector2 = jeu.monde.repousser(tente.position + Vector2(3.0, 1.0), 8.0)
	var maille = A._creer("filet", ici + Vector2(-400.0, 200.0), {})
	var dessus: Vector2 = A.buter(maille.position + Vector2(2.0, 0.0), 8.0)
	A.poses.erase(maille)
	maille.queue_free()
	verif(ouvrage == 1.0 and float(etabli.etat.get("travail", 0.0)) == 0.0 and bute.distance_to(tente.position) > float(Camp.rayon("tente")) + 7.5
		and dessus.distance_to(maille.position) < 3.0,
		"l'établi travaille le temps de l'ouvrage (des copeaux en volent), puis se tait ; on bute contre la tente (à %d pixels de son pied), on marche sur le filet" % int(bute.distance_to(tente.position)))
	# (un arbre debout, avec de la place à côté de lui : ni eau, ni buisson, ni feu)
	var arbre = null
	var avant_h: Vector2 = j.position
	A.objets["hamac"] = 1
	j.regard = -1.0
	for o in jeu.monde.objets:
		if is_instance_valid(o) and str(o.genre) in ["arbre", "sapin"] and not bool(o.get("calcine")):
			j.position = o.position + Vector2(40.0, 30.0)
			var ph: Vector2 = A._devant("hamac")
			if A.empeche_poser("hamac") == "" and A._l_arbre(ph, 90.0) == o and ph.y > o.position.y and ph.distance_to(o.position) < 100.0:
				arbre = o
				break
	if arbre == null:
		A.objets.erase("hamac")
		j.position = avant_h
		j.regard = 1.0
	else:
		var pourquoi_h: String = A.empeche_poser("hamac")
		var tendu: bool = A.poser("hamac")
		var hamac = A.poses[A.poses.size() - 1]
		if not (tendu and str(hamac.genre) == "hamac" and hamac.position.y > arbre.position.y and hamac.position.distance_to(arbre.position) < 100.0 and hamac._arbre != null):
			print("    (tendu %s, %s à %s de l'arbre, noué %s)" % [str(tendu), str(hamac.genre), str(hamac.position - arbre.position), str(hamac._arbre != null)])
		verif(tendu and str(hamac.genre) == "hamac" and hamac.position.y > arbre.position.y and hamac.position.distance_to(arbre.position) < 100.0 and hamac._arbre != null,
			"le hamac se tend à côté de son arbre, en avant de lui (sa couronne ne le cache pas), et s'y noue (« %s »)" % pourquoi_h)
		A.poses.erase(hamac)
		hamac.queue_free()
		A.objets.erase("hamac")
		j.position = avant_h
		j.regard = 1.0

	# le récupérateur d'eau, la gourde, la popote
	var cuve = A._creer("recuperateur", ici + Vector2(0.0, -120.0), {})
	C.pluie = 1.0
	for i in 26:
		A.maj(1.0)
	C.pluie = 0.0
	var tombee: float = cuve.etat.get("eau", 0.0)
	j.position = cuve.position + Vector2(20.0, 0.0)
	A._puiser(cuve)
	var sans_gourde: int = int(inv.get("eau", 0))
	A.objets["gourde"] = 1
	A._puiser(cuve)
	var puisee: int = int(inv.get("eau", 0))
	j.temperature = 80.0
	var bu: bool = A.boire()
	verif(tombee > 2.0 and tombee < 2.5 and sans_gourde == 0 and puisee == 2 and bu and int(inv["eau"]) == 1 and j.temperature < 75.0,
		"sous l'averse le récupérateur se remplit (%.1f gorgées en 26 secondes) ; il faut une gourde pour en emporter ; boire rafraîchit" % tombee)
	A.objets["popote"] = 1
	donner.call({"viande": 2, "bouillon": 0})
	var foyer := Node2D.new()
	jeu.monde.add_child(foyer)
	var cuit: bool = A.cuisiner(foyer)
	var sur_le_feu: bool = foyer.get_node_or_null("Popote") != null
	var plus_d_eau: bool = not A.cuisiner(foyer)
	foyer.queue_free()
	j.faim = 20.0
	jeu.manger()
	verif(cuit and sur_le_feu and plus_d_eau and int(inv["viande"]) == 1 and int(inv["eau"]) == 0 and int(inv["bouillon"]) == 0 and absf(j.faim - 70.0) < 0.5,
		"la popote : de l'eau et de la viande font un bouillon, qui rend 50 de faim (la viande cuite : 35) ; elle reste un moment sur le feu")

	# le sommeil
	j.position = ici
	j.faim = 100.0
	j.sante = 60.0
	j.peur = 40.0
	j.temperature = 50.0
	var sans_duvet: bool = not A.dormir(null)
	A.objets["duvet"] = 1
	var allure: float = Engine.time_scale
	var dort: bool = A.dormir(null)
	A.maj(0.5)
	var vite: bool = is_equal_approx(Engine.time_scale, allure * A.SOMMEIL) and j.endormie
	for i in 20:
		A.maj(0.5)
	var reposee: bool = j.peur < 40.0 and j.sante > 60.0
	jeu.agir()
	verif(sans_duvet and dort and vite and reposee and not A.endormie and not j.endormie and is_equal_approx(Engine.time_scale, allure),
		"avec un duvet, elle dort à même le sol : le temps passe %d fois plus vite, la peur s'en va, la santé revient ; un geste la réveille" % int(A.SOMMEIL))
	j.position = tente.position + Vector2(20.0, 0.0)
	jeu.horloge = nuit_h
	A.dormir(tente)
	var dedans: bool = A.endormie and bool(tente.etat.get("occupe", false)) and str(j.couchage) == "tente" and j.position.distance_to(tente.position) < 40.0
	jeu.horloge = jour_h
	A._t = 3.0
	A.maj(0.1)
	verif(dedans and not A.endormie and not bool(tente.etat.get("occupe", false)) and str(j.couchage) == "",
		"couchée de nuit sous sa tente (à sa porte, on ne la voit plus), elle se réveille au jour")
	var chasseur = _bete(F["chasseurs_nuit"][0], "chasseur", j.position + Vector2(200.0, 0.0), {})
	var guettee: bool = not A.dormir(tente)
	_oter(chasseur)
	verif(guettee and not A.endormie, "une bête trop près : elle ne s'endort pas")

	# la lampe et ses piles
	j.position = ici
	j.regard = 1.0
	jeu.horloge = nuit_h
	A.objets["lampe"] = 1
	A.basculer("lampe")
	var sans_piles: bool = not A.porte("lampe")
	A.objets["piles"] = 1
	A.basculer("lampe")
	var vides: bool = not A.porte("lampe")
	A.charge = 50.0
	A.basculer("lampe")
	var devant: float = jeu.eclairage(j.position + Vector2(200.0, 0.0))
	var derriere: float = jeu.eclairage(j.position + Vector2(-200.0, 0.0))
	var de_cote: float = jeu.eclairage(j.position + Vector2(40.0, 180.0))
	for i in 10:
		A.maj(1.0)
	var apres: float = A.charge
	A.charge = 0.4
	A.maj(1.0)
	verif(sans_piles and vides and devant > 0.9 and derriere == 0.0 and de_cote == 0.0 and absf(apres - (50.0 - 10.0 * A.LAMPE)) < 0.1 and not A.porte("lampe"),
		"la lampe ne s'allume qu'avec des piles chargées ; son faisceau éclaire loin devant elle (%.1f à 200 pixels), rien derrière ni sur les côtés ; vides, elle s'éteint" % devant)

	# le cerf-volant recharge les piles
	jeu.horloge = jour_h
	var volant = A._creer("cerf_volant", ici + Vector2(140.0, -60.0), {})
	j.position = volant.position + Vector2(-20.0, 0.0)
	A.charge = 0.0
	A._brancher(volant)
	A.vent_force = 0.1
	for i in 10:
		A.maj(1.0)
	var calme: float = A.charge
	A.vent_force = 0.8
	for i in 10:
		A.maj(1.0)
	var vent_fort: float = A.charge
	A.basculer("lampe")
	var pas_sur_elle: bool = not A.porte("lampe")
	A.foudre(volant.position + Vector2(100.0, 0.0))
	verif(A.fil == volant or A.charge == 100.0, "les piles sont au fil du cerf-volant")
	verif(calme == 0.0 and absf(vent_fort - 10.0 * A.CHARGER * 0.8) < 0.2 and pas_sur_elle and A.charge == 100.0,
		"le cerf-volant ne charge rien sans vent ; par grand vent, %d %% en dix secondes ; la foudre qui tombe près de lui les remplit d'un coup" % int(vent_fort))
	A.vent_force = -1.0
	A.fil = null

	# le filet
	var filet = A._creer("filet", ici + Vector2(-80.0, 140.0), {})
	var petite = null
	var grosse = null
	for e in F["proies_jour"] + F["proies_nuit"]:
		if petite == null and float(e["masse"]) <= A.PRISE_MAX:
			petite = e
		if grosse == null and float(e["masse"]) > A.PRISE_MAX:
			grosse = e
	var g = _bete(grosse, "proie", filet.position, {}) if grosse != null else null
	A.maj(0.1)
	var passe: bool = not filet.etat.has("prise")
	_oter(g)
	var prises_avant: int = jeu.chassees
	var b2 = _bete(petite, "proie", filet.position + Vector2(4.0, 2.0), {})
	A.maj(0.1)
	var prise: bool = filet.etat.has("prise") and not b2.is_in_group("betes") and jeu.chassees == prises_avant + 1
	donner.call({"viande": 0, "peau": 0})
	j.position = filet.position + Vector2(20.0, 0.0)
	A._relever(filet)
	verif(petite != null and passe and prise and int(inv["viande"]) >= 1 and int(inv["peau"]) == 1 and not filet.etat.has("prise"),
		"le filet : une bête de plus de %d kg passe ; une petite s'y prend, et se relève sans combat (de la viande, une peau)" % int(A.PRISE_MAX))

	# les vestiges
	var n_poses: int = A.poses.size()
	A.semer_vestiges()
	var vestiges: Array = A.poses.filter(func(x): return str(x.genre) == "vestige")
	var loin := true
	for v in vestiges:
		if v.position.length() < 600.0 or absf(v.position.x) > RR.DEMI or absf(v.position.y) > RR.DEMI:
			loin = false
	donner.call({"ferraille": 0})
	j.position = vestiges[0].position + Vector2(20.0, 0.0) if not vestiges.is_empty() else ici
	jeu.agir()
	var trouve: int = int(inv["ferraille"])
	jeu.agir()
	# (trois vestiges, et le coffre du mieux pourvu : quatre choses de plus dans le lieu)
	verif(vestiges.size() == 3 and A.poses.size() == n_poses + 4 and loin and trouve >= 2 and int(inv["ferraille"]) == trouve,
		"trois vestiges d'autres veilleuses dans le lieu, loin du réveil ; « Agir » y trouve de la ferraille (%d), une seule fois" % trouve)

	# replier, et la partie gardée
	j.position = filet.position + Vector2(20.0, 0.0)
	var replie: bool = A.replier()
	verif(replie and A.possede("filet") == 1 and not A.poses.has(filet), "une chose posée se replie et retourne dans le sac")
	# (la foudre a pu réduire le cerf-volant en cendres, une fois sur trois : il en faut un pour y laisser les piles)
	if not A.poses.has(volant):
		volant = A._creer("cerf_volant", ici + Vector2(140.0, -60.0), {})
	A.fil = volant
	A.charge = 37.0
	var photo: Dictionary = JSON.parse_string(JSON.stringify(A.photo()))
	var A2 = jeu.Atelier.new()
	A2.jeu = jeu
	A2.reprendre(photo)
	var memes: bool = A2.objets.size() == A.objets.size() and A2.possede("filet") == 1 and A2.porte("sac_a_dos") and A2.porte("vetement_chaud") and not A2.porte("lampe") \
		and A2.poses.size() == A.poses.size() and absf(A2.charge - 37.0) < 0.1 and A2.fil != null and str(A2.fil.genre) == "cerf_volant" \
		and A2.poses.filter(func(x): return str(x.genre) == "vestige" and bool(x.etat.get("fouille", false))).size() == 1
	verif(memes, "la partie gardée retient ce qu'elle a fabriqué, ce qu'elle porte, son camp posé (%d choses), les piles et où elles sont" % A.poses.size())
	for s2 in A2.poses:
		s2.queue_free()

	# (tout remis comme avant)
	for s3 in A.poses:
		if is_instance_valid(s3):
			s3.queue_free()
	A.commencer()
	for k in inv.keys():
		inv[k] = int(garde["inv"].get(k, 0))
	jeu.feux.clear()
	for f in garde["feux"]:
		jeu.feux.append(f)
	jeu.horloge = garde["h"]
	jeu.chassees = garde["chassees"]
	jeu.prelevements = garde["prel"]
	jeu._deja = garde["deja"]
	j.position = garde["p"]
	j.regard = garde["regard"]
	j.sante = garde["sante"]
	j.faim = garde["faim"]
	j.peur = garde["peur"]
	j.temperature = garde["temp"]
	j.trempe = garde["trempe"]
	j.torche = garde["torche"]
	C.pluie = garde["pluie"]
	C.air = garde["air"]
	C.vent = garde["vent"]



# --- la flore (scripts/flore.gd, scripts/flore_dessins.gd) : l'herbier d'Orvane fait les plantes du lieu, forme par forme, que
# Lisière dessine ; on cueille les fleurs et les champignons des bois, ils servent, ils repoussent ---

# un grand rectangle d'un biome, loin de tout, semé comme un morceau du monde ouvert (son plan, puis ses objets) : ce qu'il y
# pousse, par forme (les objets sont défaits ensuite)
# (le plan est celui du monde : scripts/milieu.gd — chaque place a son milieu, et sa plante s'y tire selon sa part et son goût.
# garder : les objets restent, pour qu'on les compte — scripts/recensement.gd — ; ils sont rendus dans « objets », à défaire)
func _semer_a_part(type: String, coin: Vector2, garder: bool = false) -> Dictionary:
	var W = jeu.monde
	var Mi = load("res://scripts/milieu.gd")
	var L: Dictionary = W.lieu_de(type)
	var rect := Rect2(coin, Vector2(8400.0, 8400.0))
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var plan: Array = []
	var ctx: Dictionary = W._contexte(type)
	Mi.prevoir(ctx, r, rect, plan)
	var rc := RandomNumberGenerator.new()
	rc.seed = 4343
	Mi.cueillette(ctx, rc, rect, plan, W._arbres_du_plan(plan, rect))
	var par_forme := {}
	var genres := {}
	var mal := []
	var vides := 0
	var gardes: Array = []
	for e in plan:
		var o = W._poser(str(e[0]), e[1], L["palette"][e[2]] if e[2] != "" else Color.WHITE, int(e[3]), L, int(e[5]))
		if o == null:
			vides += 1
			continue
		genres[o.genre] = int(genres.get(o.genre, 0)) + 1
		if o.plante != "":
			par_forme[o.forme] = int(par_forme.get(o.forme, 0)) + 1
			if not load("res://scripts/flore_dessins.gd").sait(o.forme) or o.planche:
				mal.append(o.forme)
		if garder:
			gardes.append(o)
		else:
			W._defaire(o)
	return {"formes": par_forme, "genres": genres, "mal": mal, "vides": vides, "objets": gardes, "rect": rect, "plan": plan.size()}


# --- la répartition (scripts/milieu.gd, scripts/recensement.gd) : chaque plante de l'herbier d'Orvane se tient dans son milieu
# — les roseaux au bord de l'eau, les fougères sous le couvert, les géants à l'écart, les lichens contre la pierre, les cactus
# espacés — et garde sa part. Tout est compté sur de grands nombres (un lieu entier, puis quatre fois sa surface par biome),
# avec de la marge : rien ne tient à un tirage. Puis les parties gardées : celle d'avant garde son plan ---
func _la_repartition() -> void:
	print("La répartition")
	var Mi = load("res://scripts/milieu.gd")
	var Re = load("res://scripts/recensement.gd")
	seed(20261120)
	await jeu._commencer("marais")
	var W = jeu.monde
	var C = jeu.climat
	var T = jeu.terrain
	C.forcer("clair", 0.0, 9999.0)
	# le relief du plan est celui du temps qu'il fait : l'eau qui reste au creux du marais est là où le plan la croit
	var pire := 0.0
	var mouilles := 0
	var ctx: Dictionary = W._contexte("")
	for i in 400:
		var q := Vector2(-2000.0 + 200.0 * (i % 20), -2000.0 + 200.0 * (i / 20))
		pire = maxf(pire, absf(float(Mi.relief_en(ctx, q)) - float(C.relief(q))))
		if (float(C.eau(q)) > 0.0 and float(T.fondriere(q)) <= 0.0) != (float(Mi.relief_en(ctx, q)) < float(Mi.niveau(ctx))):
			mouilles += 1
	verif(pire < 0.0001 and mouilles == 0 and float(Mi.niveau(ctx)) > 0.3,
		"le relief que lit le plan est celui du temps qu'il fait (écart %.5f sur 400 points) : l'eau qui reste au creux du marais (niveau %.2f) est là où il la croit" % [pire, float(Mi.niveau(ctx))])
	# le pays : ses fondrières sont celles que le plan a lues (la même liste, une fois), et aucun tronc n'y trempe
	var cases_pareilles := 0
	var fondrieres := 0
	for k in T._cases:
		if W.pays_case(k) == T._cases[k]:
			cases_pareilles += 1
		fondrieres += T._cases[k].filter(func(x): return str(x["genre"]) == "fondriere").size()
	var noyes: int = W.objets.filter(func(o): return o.genre in ["arbre", "sapin"] and float(T.fondriere(o.position)) > 0.0).size()
	var dans_l_eau: int = W.objets.filter(func(o): return o.genre in ["arbre", "sapin", "buisson", "touffe"] and float(C.eau(o.position)) >= 0.6).size()
	verif(cases_pareilles == T._cases.size() and fondrieres > 40 and noyes == 0 and dans_l_eau == 0,
		"le plan connaît le pays : les %d cases du marais (%d fondrières) sont celles qu'il a lues ; pas un tronc dans une fondrière (%d), rien de planté au large de l'eau (%d)" % [
		T._cases.size(), fondrieres, noyes, dans_l_eau])
	# le marais entier, compté : les plantes de rive au bord de l'eau, le palétuvier les pieds dedans, les nénuphars au large
	var c: Dictionary = Re.compter(W, "marais")
	var P: Dictionary = c["plantes"]
	var au_bord := func(formes: Array) -> Array:
		var d: Array = []
		for id in P:
			if formes.has(P[id]["forme"]):
				d.append_array(P[id]["eau"])
		return [d.size(), Re._part(d, Re.PRES_EAU), Re._mediane(d)]
	var roseaux: Array = au_bord.call(["roseau", "riz", "papyrus"])
	var paletuviers: Array = au_bord.call(["paletuvier"])
	var autres_arbres: Array = au_bord.call(["arbre", "pionnier", "geant"])
	verif(int(roseaux[0]) >= 60 and float(roseaux[1]) >= 0.8 and float(roseaux[2]) <= 40.0,
		"au marais, les roseaux et le riz tiennent le bord de l'eau : %d, %d %% à moins de %d pixels d'une mare, d'une fondrière, de l'eau des creux (médiane %d)" % [
		int(roseaux[0]), int(float(roseaux[1]) * 100.0), int(Re.PRES_EAU), int(roseaux[2])])
	verif(int(paletuviers[0]) >= 8 and float(paletuviers[1]) >= 0.55 and float(paletuviers[1]) > float(autres_arbres[1]) + 0.15,
		"le palétuvier a les pieds dans l'eau : %d, %d %% au bord (les autres arbres : %d %%)" % [int(paletuviers[0]), int(float(paletuviers[1]) * 100.0), int(float(autres_arbres[1]) * 100.0)])
	verif(int(c["fond"]["n"]) >= 15 and float(c["fond"]["nenuphars"]) > float(c["fond"]["lentilles"]) + 0.2,
		"sur l'eau, les nénuphars sont au large (%d %% au milieu d'une mare, là où l'eau est profonde) et les lentilles d'eau au bord (%d %%)" % [
		int(float(c["fond"]["nenuphars"]) * 100.0), int(float(c["fond"]["lentilles"]) * 100.0)])
	verif(float(c["ecart_grand"]) < 0.12 and int(c["genres"].get("arbre", 0)) > 250 and int(c["genres"].get("touffe", 0)) > 120,
		"et chacune garde sa part d'Orvane dans sa strate, à %.1f points près sur ce lieu (%d arbres, %d plantes du sol, %d plantes d'eau)" % [100.0 * float(c["ecart_grand"]),
		int(c["genres"].get("arbre", 0)), int(c["genres"].get("touffe", 0)), int(c["genres"].get("aquatique", 0))])
	# le lieu fermé gardé : la photo de chaque plante porte son milieu, et elle s'en retire la même
	var photo: Array = JSON.parse_string(JSON.stringify(W.photo_objets()))
	var avec := 0
	var pareilles := 0
	var essayees := 0
	var vivants: Array = W.objets.filter(func(o): return is_instance_valid(o))
	for i in range(0, mini(photo.size(), vivants.size()), 3):
		var g: Array = photo[i]
		var o0 = vivants[i]
		if typeof(g.back()) != TYPE_STRING or str(o0.plante) == "":
			continue
		avec += 1
		var avant_n: int = W.objets.size()
		W._reposer([g])
		essayees += 1
		if W.objets.size() == avant_n + 1:
			var o1 = W.objets[W.objets.size() - 1]
			if str(o1.plante) == str(o0.plante) and o1.position.distance_to(o0.position) < 0.2 and int(o1.get_meta("milieu", -1)) == int(o0.get_meta("milieu", -2)):
				pareilles += 1
			W._defaire(o1)
	# (et une plante gardée sans milieu — une partie d'avant — se repose aussi, tirée de sa seule part)
	var vieille: Array = photo.filter(func(g): return typeof(g.back()) == TYPE_STRING and str(g[0]) == "sol")
	var revenue := false
	if not vieille.is_empty():
		var g1: Array = vieille[0].slice(0, vieille[0].size() - 1)
		var avant_n: int = W.objets.size()
		W._reposer([g1])
		revenue = W.objets.size() == avant_n + 1 and str(W.objets[W.objets.size() - 1].plante) != "" and not W.objets[W.objets.size() - 1].has_meta("milieu")
		if W.objets.size() == avant_n + 1:
			W._defaire(W.objets[W.objets.size() - 1])
	verif(avec >= 100 and pareilles == essayees and revenue,
		"le lieu gardé : la photo de chaque plante porte son milieu, et %d sur %d se retirent les mêmes, à leur place ; une plante gardée sans milieu (une partie d'avant) se repose aussi, de sa seule part" % [
		pareilles, essayees])
	# le monde ouvert : quatre biomes, chacun semé à part sur quatre fois la surface d'un lieu, et compté
	seed(20261121)
	await jeu._commencer("prairie", {}, true)
	W = jeu.monde
	var comptes := {}
	var i_b := 0
	for type in ["foret", "taiga", "desert", "banquise"]:
		await jeu.donnees.charger_lieu(type)
		W.flore_arrivee(type)
		var d := _semer_a_part(type, Vector2(190000.0 + i_b * 12000.0, 190000.0), true)
		i_b += 1
		comptes[type] = Re.compter(W, type, d["rect"], true, false)
		comptes[type]["plan"] = d["plan"]
		for o in d["objets"]:
			if is_instance_valid(o):
				W._defaire(o)
	var f: Dictionary = comptes["foret"]
	var ta: Dictionary = comptes["taiga"]
	var de: Dictionary = comptes["desert"]
	var ba: Dictionary = comptes["banquise"]
	verif(int(f["sous_bois"]["n"]) >= 80 and float(f["sous_bois"]["sous"]) >= 0.7 and float(f["sous_bois"]["sous"]) > float(f["sous_bois"]["ailleurs"]) + 0.15
		and int(ta["sous_bois"]["n"]) >= 80 and float(ta["sous_bois"]["sous"]) >= 0.7,
		"le sous-bois : en forêt, %d %% des fougères et des mousses à moins de %d pixels d'un tronc (les autres plantes du sol : %d %%) ; en taïga, %d %%" % [
		int(float(f["sous_bois"]["sous"]) * 100.0), int(Re.SOUS), int(float(f["sous_bois"]["ailleurs"]) * 100.0), int(float(ta["sous_bois"]["sous"]) * 100.0)])
	verif(int(f["lianes"]["n"]) >= 8 and float(f["lianes"]["au_pied"]) >= 0.9,
		"les lianes sont sur les arbres : %d, %d %% à moins de %d pixels d'un tronc" % [int(f["lianes"]["n"]), int(float(f["lianes"]["au_pied"]) * 100.0), int(Re.AU_PIED)])
	verif(int(f["geants"]["n"]) >= 20 and float(f["geants"]["min"]) >= 100.0 and int(ta["geants"]["n"]) >= 20 and float(ta["geants"]["min"]) >= 100.0
		and float(f["geants"]["n"]) < 0.08 * float(f["peuplements"]["arbres"]),
		"les géants sont rares et à l'écart : %d en forêt pour %d arbres, le plus proche voisin d'aucun à moins de %d pixels (les autres arbres : %d, à la médiane) ; %d en taïga (%d)" % [
		int(f["geants"]["n"]), int(f["peuplements"]["arbres"]), int(f["geants"]["min"]), int(f["geants"]["autres"]), int(ta["geants"]["n"]), int(ta["geants"]["min"])])
	verif(float(f["peuplements"]["meme"]) > float(f["peuplements"]["hasard"]) + 0.07 and float(ta["peuplements"]["meme"]) > float(ta["peuplements"]["hasard"]) + 0.07
		and float(f["peuplements"]["en_peuplement"]) > 0.12,
		"les arbres vont par peuplements : le plus proche voisin est de la même espèce pour %d %% en forêt (au hasard : %d %%), %d %% en taïga (%d %%) ; %d %% des arbres de la forêt dans un peuplement de quatre ou plus" % [
		int(float(f["peuplements"]["meme"]) * 100.0), int(float(f["peuplements"]["hasard"]) * 100.0), int(float(ta["peuplements"]["meme"]) * 100.0),
		int(float(ta["peuplements"]["hasard"]) * 100.0), int(float(f["peuplements"]["en_peuplement"]) * 100.0)])
	verif(int(de["cactus"]["n"]) >= 30 and float(de["cactus"]["serres"]) <= 0.1 and float(de["grasses"]["mediane"]) >= 90.0,
		"au désert, les plantes grasses se partagent l'eau : %d cactus, %d %% à moins de 50 pixels d'une autre plante grasse (médiane %d) ; toutes : %d pixels à la médiane" % [
		int(de["cactus"]["n"]), int(float(de["cactus"]["serres"]) * 100.0), int(de["cactus"]["mediane"]), int(de["grasses"]["mediane"])])
	verif(int(ba["pierre"]["n"]) >= 300 and float(ba["pierre"]["pres"]) >= 0.25,
		"sur la banquise, les lichens et les coussins tiennent à la pierre : %d %% des %d à moins de %d pixels d'un rocher" % [
		int(float(ba["pierre"]["pres"]) * 100.0), int(ba["pierre"]["n"]), int(Re.PRES_ROC)])
	verif(float(f["ecart_grand"]) < 0.06 and float(ta["ecart_grand"]) < 0.06 and float(de["ecart_grand"]) < 0.06 and float(ba["ecart_grand"]) < 0.06,
		"et les parts d'Orvane tiennent, dans chaque strate d'au moins %d plantes : à %.1f points près en forêt, %.1f en taïga, %.1f au désert, %.1f sur la banquise" % [
		Re.GRANDE_STRATE, 100.0 * float(f["ecart_grand"]), 100.0 * float(ta["ecart_grand"]), 100.0 * float(de["ecart_grand"]), 100.0 * float(ba["ecart_grand"])])
	# le plan d'un morceau : toujours le même ; refait, le morceau porte les mêmes plantes aux mêmes places
	var k := Vector2i(2, 1)
	W.suivre(Vector2(1750.0, 1050.0), true)
	var plan_a: Array = W._plan_m(k)
	var plan_b: Array = W._plan_m(k)
	var dit := func() -> Array:
		var l: Array = W._morceaux[k]["objets"].filter(func(o): return is_instance_valid(o) and o.has_meta("rang")).map(func(o): return [int(o.get_meta("rang")), str(o.plante), o.position])
		l.sort()
		return l
	var avant_m: Array = dit.call()
	W._oublier(k)
	W._fabriquer(k)
	var apres_m: Array = dit.call()
	var chez_soi: bool = W._morceaux[k]["objets"].all(func(o): return not o.has_meta("rang") or Rect2(Vector2(k) * W.MORCEAU, Vector2(W.MORCEAU, W.MORCEAU)).has_point(o.position))
	verif(plan_a == plan_b and plan_a.size() > 20 and avant_m == apres_m and avant_m.size() > 10 and chez_soi and W.pire_ms < 60.0,
		"le plan d'un morceau est toujours le même (%d places) ; refait, il porte les mêmes %d plantes aux mêmes places, aucune chez son voisin (fabriqué en %.1f ms)" % [
		plan_a.size(), avant_m.size(), W.pire_ms])
	# une partie gardée d'avant ne dit pas son plan : elle garde le premier, et ses rangs retrouvent leurs objets ; une neuve dit le sien
	var neuve: Dictionary = W.photo_ouvert()
	W._oublier(k)
	W.reprendre_ouvert({"changes": {}, "ajouts": {}})
	var plan_1: Array = W._plan_m(k)
	W._fabriquer(k)
	var cible = null
	for o in W._morceaux[k]["objets"]:
		if is_instance_valid(o) and o.has_meta("rang") and o.genre in ["arbre", "sapin"]:
			cible = o
			break
	var rang_c: int = int(cible.get_meta("rang")) if cible != null else -1
	var place_c: Vector2 = cible.position if cible != null else Vector2.ZERO
	W._oublier(k)
	W.reprendre_ouvert({"changes": {W._nom_m(k): {str(rang_c): ["souche", 0, 0.0, 0, 0.0]}}, "ajouts": {}})
	W._fabriquer(k)
	var souches_1: Array = W._morceaux[k]["objets"].filter(func(o): return is_instance_valid(o) and o.genre == "souche")
	var garde_1: Dictionary = W.photo_ouvert()
	verif(int(neuve.get("plan", 0)) == W.PLAN and W.plan_version == 1 and plan_1.size() > 10 and plan_1.all(func(e): return e.size() == 5)
		and souches_1.size() == 1 and souches_1[0].position.distance_to(place_c) < 0.2 and int(garde_1.get("plan", 0)) == 1,
		"une partie neuve dit son plan (%d) ; une partie gardée d'avant ne le dit pas : elle garde le premier (%d places sans milieu dans ce morceau), l'arbre qu'elle avait abattu est encore une souche, à sa place, et elle se garde de nouveau avec ce plan" % [
		int(neuve.get("plan", 0)), plan_1.size()])
	# (on rend au monde le plan d'aujourd'hui)
	W._oublier(k)
	W.reprendre_ouvert({"changes": {}, "ajouts": {}, "plan": W.PLAN})
	W._fabriquer(k)
	verif(W.plan_version == W.PLAN and W._plan_m(k) == plan_a, "et le plan d'aujourd'hui revient tel quel")


func _la_flore() -> void:
	print("La flore")
	var Fl := load("res://scripts/flore.gd")
	var W = jeu.monde
	var jo = jeu.joueur
	# les biomes d'abord : chaque forme de leur herbier est semée, selon sa part, et dessinée par Lisière (aucune ne manque)
	var i := 0
	for type in ["banquise", "volcan", "desert", "marais", "taiga"]:
		await jeu.donnees.charger_lieu(type)
		W.flore_arrivee(type)
		var attendues := {}
		for e in Orvane.plantes(type):
			attendues[str(Fl.sorte(e)["forme"])] = true
		var d := _semer_a_part(type, Vector2(90000.0 + i * 12000.0, 90000.0))
		i += 1
		var manque: Array = attendues.keys().filter(func(x): return not d["formes"].has(x))
		var arbres: int = int(d["genres"].get("arbre", 0)) + int(d["genres"].get("sapin", 0))
		var dit := ", ".join(PackedStringArray(d["formes"].keys().map(func(x): return "%s %d" % [x, d["formes"][x]])))
		verif(not attendues.is_empty() and manque.is_empty() and d["mal"].is_empty(),
			"%s : les %d formes de son herbier poussent, dessinées par Lisière (%s)%s" % [type, attendues.size(), dit,
			(" ; manquent : " + ", ".join(PackedStringArray(manque))) if not manque.is_empty() else (" ; sans dessin : " + str(d["mal"]) if not d["mal"].is_empty() else "")])
		match type:
			"banquise", "volcan", "desert":
				# (leur herbier n'a pas d'arbre : pas un sapin, pas un feuillu ; leurs places vont aux plantes du sol)
				# (et sans arbre, peu de bois mort : une brindille sur quatre)
				verif(arbres == 0 and int(d["genres"].get("touffe", 0)) > 600 and int(d["genres"].get("brindille", 0)) < 260,
					"%s : pas un arbre (l'herbier n'en a pas : %d sapins, %d feuillus) ; leurs places vont aux plantes du sol (%d) ; peu de bois mort (%d brindilles)" % [type,
					int(d["genres"].get("sapin", 0)), int(d["genres"].get("arbre", 0)), int(d["genres"].get("touffe", 0)), int(d["genres"].get("brindille", 0))])
			"marais":
				verif(int(d["genres"].get("sapin", 0)) == 0 and int(d["genres"].get("arbre", 0)) > 400 and int(d["genres"].get("aquatique", 0)) > 40 and int(d["genres"].get("brindille", 0)) > 450,
					"marais : ses arbres sont ceux de son herbier (%d, palétuviers et fougères arborescentes compris, aucun sapin), ses mares portent nénuphars, lentilles d'eau et algues (%d)" % [
					int(d["genres"].get("arbre", 0)), int(d["genres"].get("aquatique", 0))])
			"taiga":
				verif(int(d["genres"].get("sapin", 0)) > 40 and int(d["formes"].get("conifere", 0)) == int(d["genres"].get("sapin", 0)) and int(d["genres"].get("arbre", 0)) > 200,
					"taïga : ses sapins sont les conifères de son herbier (%d), parmi ses feuillus (%d)" % [int(d["genres"].get("sapin", 0)), int(d["genres"].get("arbre", 0))])
	# une plante d'un port que Lisière ne connaît pas : la planche d'Orvane, en secours (un nœud à part, sans encre)
	var une_planche: String = str(Orvane._herbiers.get("prairie", {}).get("plantes", {}).get("flore-prairie-fleur", {}).get("svg", ""))
	Orvane.ajouter_herbier("essai-planche", {"plantes": {"flore-essai-inconnue": {"svg": une_planche, "nom": "Inconnue", "forme": "inconnue", "port": "inconnu", "part": 1.0}}})
	var o_pl = W._poser("sol", Vector2(90000.0, 150000.0), Color.WHITE, 17, W.lieu_de("essai-planche"))
	var sa_planche: bool = o_pl != null and o_pl.planche and o_pl.get_children().any(func(c): return c is Sprite2D and c.texture != null)
	if o_pl != null:
		W._defaire(o_pl)
	Orvane.ajouter_herbier("essai-planche", {})
	verif(une_planche != "" and sa_planche, "une plante d'un port inconnu se montre par la planche d'Orvane, en secours")
	# sans herbier, la température décide encore : la banquise reprend ses sapins
	var gardee: Dictionary = Orvane._herbiers.get("banquise", {})
	Orvane.ajouter_herbier("banquise", {})
	W.flore_arrivee("banquise")
	var sans := _semer_a_part("banquise", Vector2(90000.0, 130000.0))
	verif(int(sans["genres"].get("sapin", 0)) > 100 and int(sans["genres"].get("arbre", 0)) == 0,
		"sans herbier, la température décide encore : la banquise a ses sapins (%d)" % int(sans["genres"].get("sapin", 0)))
	# une partie reprise sur la banquise, loin du réveil : ce qui s'est fait avant que son herbier arrive est refait avec ses plantes
	var C = jeu.carte
	var banq := -1
	for k in C.regions.size():
		if str(C.regions[k]["type"]) == "banquise" and (banq < 0 or C.regions[k]["pos"].length() < C.regions[banq]["pos"].length()):
			banq = k
	var p_b: Vector2 = C.regions[banq]["pos"] - C.tordre(C.regions[banq]["pos"])
	jo.position = p_b
	W.suivre(p_b, true)
	var sur_la_banquise := func(x): return str(C.regions[C.region_en(x.position)]["type"]) == "banquise"
	var sapins_avant: int = W.autour(p_b, 900.0).filter(func(x): return x.genre == "sapin" and sur_la_banquise.call(x)).size()
	Orvane.ajouter_herbier("banquise", gardee)
	W.flore_arrivee("banquise")
	var autour_b: Array = W.autour(p_b, 900.0).filter(func(x): return sur_la_banquise.call(x))
	var sapins_apres: int = autour_b.filter(func(x): return x.genre == "sapin").size()
	var lichens: int = autour_b.filter(func(x): return str(x.forme).begins_with("lichen")).size()
	verif(sapins_avant > 0 and sapins_apres == 0 and lichens > 0,
		"reprise sur la banquise avant que son herbier soit lu : %d sapins ; l'herbier arrivé, ses morceaux sont refaits : plus un sapin, %d lichens" % [sapins_avant, lichens])

	# dans le monde ouvert : à la forêt, les fleurs des prés et les champignons des bois sont des objets du lieu, qu'on cueille
	var foret := -1
	for k in C.regions.size():
		if str(C.regions[k]["type"]) == "foret" and (foret < 0 or C.regions[k]["pos"].length() < C.regions[foret]["pos"].length()):
			foret = k
	var la: Vector2 = C.regions[foret]["pos"] - C.tordre(C.regions[foret]["pos"])
	jo.position = la
	W.suivre(la, true)
	await jeu._lire_biome("foret")
	jeu._regions()
	# (le plus proche de là, de ce genre, loin de ce qu'elle a posé et seul à portée de main)
	var le_plus_pres := func(genre: String):
		var mieux = null
		var d0 := INF
		for x in W.autour(la, 1600.0):
			if x.genre != genre or x.epuise() or not x.has_meta("rang"):
				continue
			if jeu.atelier.poses.any(func(y): return is_instance_valid(y) and y.position.distance_to(x.position) < 80.0):
				continue
			if W.autour(x.position, 6.0).filter(func(y): return y != x and not y.epuise()).size() > 0:
				continue
			if x.position.distance_to(la) < d0:
				d0 = x.position.distance_to(la)
				mieux = x
		return mieux
	var fleur = le_plus_pres.call("fleur")
	var cepe = le_plus_pres.call("cepe")
	var amanite = le_plus_pres.call("amanite")
	verif(fleur != null and cepe != null and amanite != null and W.objets.filter(func(x): return x.genre in ["cepe", "amanite"]).size() >= 3,
		"en forêt, les fleurs des prés et les champignons des bois (le cèpe, l'amanite) sont des objets du lieu : %d champignons, %d fleurs autour d'elle" % [
		W.objets.filter(func(x): return x.genre in ["cepe", "amanite"]).size(), W.objets.filter(func(x): return x.genre == "fleur").size()])
	if fleur == null or cepe == null or amanite == null:
		return
	var inv: Dictionary = jo.inventaire
	var cueillir := func(o) -> Dictionary:
		for b in get_tree().get_nodes_in_group("betes"):
			if b.position.distance_to(o.position) < 300.0:
				_oter(b)
		jo.position = o.position + Vector2(0, 2)
		var avant := inv.duplicate()
		jeu.agir()
		var gagne := {}
		for k in inv:
			if int(inv[k]) != int(avant.get(k, 0)):
				gagne[k] = int(inv[k]) - int(avant.get(k, 0))
		return gagne
	var p_fleur: Vector2 = fleur.position
	var p_cepe: Vector2 = cepe.position
	var g_fleur: Dictionary = cueillir.call(fleur)
	var g_cepe: Dictionary = cueillir.call(cepe)
	var g_amanite: Dictionary = cueillir.call(amanite)
	verif(g_fleur == {"fleurs": 1} and g_cepe == {"champignons": 1} and g_amanite == {"amanite": 1} and fleur.epuise() and cepe.epuise() and fleur._repousse > 0.0 and cepe._repousse > 0.0,
		"« Agir » cueille : une fleur (%s), un cèpe (%s), une amanite (%s) ; cueillis, ils repousseront" % [str(g_fleur), str(g_cepe), str(g_amanite)])
	# le cèpe se mange (E) ; l'amanite, mangée faute de mieux, empoisonne
	for k in ["baies", "viande", "viande_cuite", "bouillon"]:
		inv[k] = 0
	jo.faim = 40.0
	jeu.manger()
	var faim_cepe: float = jo.faim - 40.0
	jeu.botanique.poison = 0.0
	jeu.manger()
	var empoisonnee: bool = jeu.botanique.poison > 0.0
	jeu.botanique.poison = 0.0
	verif(absf(faim_cepe - jeu.R.CHAMPIGNON) < 0.01 and int(inv.get("champignons", 0)) == 0 and empoisonnee and int(inv.get("amanite", 0)) == 0,
		"le cèpe se mange (E : +%d à la faim) ; l'amanite, mangée faute de mieux, empoisonne (un baume chasse le poison)" % int(faim_cepe))
	# l'amanite, pilée au mortier avec de la viande : l'appât empoisonné des herbes
	var A = jeu.atelier
	inv["amanite"] = 1
	inv["viande"] = 1
	var sans_mortier: String = A.empeche_piler_amanite()
	var mortier := int(A.objets.get("mortier", 0))
	A.objets["mortier"] = 1
	var appats := int(inv.get("appat_poison", 0))
	var pile: bool = A.piler_amanite()
	verif(sans_mortier.contains("mortier") and pile and int(inv.get("appat_poison", 0)) == appats + 1 and int(inv["amanite"]) == 0 and int(inv["viande"]) == 0
		and jeu.botanique.empeche_utiliser("appat_poison") == "",
		"au mortier, une amanite et de la viande font un appât empoisonné, qui se pose comme celui des herbes")
	inv["appat_poison"] = appats
	A.objets["mortier"] = mortier
	# les fleurs : trois, une gorgée d'eau, à la popote sur un feu, font une infusion qui calme la peur
	inv["fleurs"] = jeu.R.FLEURS_INFUSION
	inv["eau"] = 1
	var popote := int(A.objets.get("popote", 0))
	A.objets["popote"] = 1
	var sans_feu: String = A.empeche_infuser()
	inv["bois"] = int(inv["bois"]) + 4
	inv["pierre"] = int(inv["pierre"]) + 2
	var feux_avant: int = jeu.feux.size()
	jeu.fabriquer("feu")
	var infuse: bool = A.infuser()
	jo.peur = 60.0
	var bue: bool = A.boire_infusion()
	verif(sans_feu.contains("feu") and jeu.feux.size() == feux_avant + 1 and infuse and bue and int(inv["fleurs"]) == 0 and int(inv["eau"]) == 0
		and int(inv.get("infusion", 0)) == 0 and absf(jo.peur - (60.0 - jeu.R.INFUSION_PEUR)) < 0.5,
		"%d fleurs et une gorgée d'eau, à la popote sur un feu : une infusion ; bue, la peur tombe (60 → %d)" % [jeu.R.FLEURS_INFUSION, int(jo.peur)])
	A.objets["popote"] = popote
	# ce qui pique écorche les mains nues ; la pelisse les garde
	var cactus = null
	for k in 400:
		var o = W._poser("sol", jo.position + Vector2(0, 30), Color.WHITE, 7000 + k * 7919, W.lieu_de("desert"))
		if o != null and o.forme == "cactus":
			cactus = o
			break
		if o != null:
			W._defaire(o)
	var sante0 := 80.0
	jo.sante = sante0
	var g_cactus: Dictionary = cueillir.call(cactus) if cactus != null else {}
	var pique: float = sante0 - jo.sante
	jo.sante = sante0
	A.portes["vetement_chaud"] = true
	if cactus != null:
		cueillir.call(cactus)
	var protegee: float = sante0 - jo.sante
	A.portes.erase("vetement_chaud")
	jo.sante = 100.0
	# (le cactus donne sa pulpe, plus ses fibres : la cueillette nourricière en fait l'eau du désert ; _la_cueillette_nourriciere)
	verif(cactus != null and cactus.piquant and g_cactus.get("pulpe", 0) == 1 and absf(pique - jeu.R.EPINES) < 0.01 and protegee < 0.01,
		"un cactus (comme un roncier, un agave, un buisson d'épines) écorche les mains qui le cueillent (-%d) ; la pelisse les garde" % int(pique))
	if cactus != null:
		W._defaire(cactus)
	# ce qu'on a cueilli reste cueilli : loin, puis de retour ; gardé avec la partie ; puis ça repousse
	var a_cet_endroit := func(p: Vector2):
		var l: Array = W.autour(p, 1.5)
		return l[0] if not l.is_empty() else null
	var gardee_f: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	var notes := 0
	for nom_m in gardee_f["monde"]["changes"]:
		for rang in gardee_f["monde"]["changes"][nom_m]:
			var c = gardee_f["monde"]["changes"][nom_m][rang]
			if typeof(c) == TYPE_ARRAY and str(c[0]) in ["fleur", "cepe"] and int(c[1]) == 0:
				notes += 1
	var loin := la + Vector2(9000.0, 0.0)
	jo.position = loin
	W.suivre(loin, true)
	var partis: bool = a_cet_endroit.call(p_fleur) == null and a_cet_endroit.call(p_cepe) == null
	jo.position = la
	W.suivre(la, true)
	var f2 = a_cet_endroit.call(p_fleur)
	var c2 = a_cet_endroit.call(p_cepe)
	verif(partis and notes >= 2 and f2 != null and c2 != null and f2.genre == "fleur" and f2.epuise() and c2.genre == "cepe" and c2.epuise()
		and gardee_f["joueur"]["inventaire"].has("fleurs"),
		"loin puis de retour, la fleur et le cèpe cueillis le sont toujours ; la partie gardée les retient (%d), et le sac aussi" % notes)
	# (le temps passe sans elle : on les dit cueillis il y a longtemps, à quarante secondes de repousser)
	f2._repousse = 40.0
	c2._repousse = 40.0
	jo.position = loin
	W.suivre(loin, true)
	jeu.horloge += 45.0
	jo.position = la
	W.suivre(la, true)
	var f3 = a_cet_endroit.call(p_fleur)
	var c3 = a_cet_endroit.call(p_cepe)
	verif(f3 != null and c3 != null and f3.intact() and c3.intact() and not f3.epuise() and not c3.epuise(),
		"le temps passé sans elle, la fleur a refleuri, le cèpe est ressorti")
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu._regions()


# --- les pays qui ont leur caractère (scripts/biomes.gd, scripts/biome_terrain.gd) : chacun pèse à sa façon, et offre ce qu'on ne
# trouve pas ailleurs. Joué sans attendre : le climat et le corps avancent par les fonctions du jeu, image par image ---

# le corps tenu « secondes » à l'heure qu'il est (le climat avance, le corps le suit ; rien d'autre ne bouge) : [sa température, sa santé]
func _tenir_au_climat(secondes: float, dt: float = 0.5) -> Array:
	var C = jeu.climat
	for k in int(secondes / dt):
		C.avancer(dt)
		jeu._temps_du_corps(dt)
	return [jeu.joueur.temperature, jeu.joueur.sante]


# au milieu du jour, ou au milieu de la nuit, d'aujourd'hui
func _a_l_heure(nuit: bool) -> void:
	var D: float = jeu.R.DUREE
	var soir: float = D * (1.0 - jeu.part_nuit)
	jeu.horloge = floorf(jeu.horloge / D) * D + (soir + D * jeu.part_nuit * 0.5 if nuit else soir * 0.5)
	jeu.climat._air(0.0)


# la veilleuse, remise à neuf là : rassasiée, calme, à 50, sèche, ni en feu ni enfoncée, sans bête autour ni feu
func _remettre(p: Vector2) -> void:
	var j = jeu.joueur
	j.position = p
	j.sante = 100.0
	j.faim = 100.0
	j.peur = 0.0
	j.temperature = 50.0
	j.trempe = 0.0
	j.en_feu = 0.0
	j.en_mouvement = false
	jeu._maux = {}
	jeu.terrain.enlise = 0.0
	for b in jeu.get_tree().get_nodes_in_group("betes"):
		_oter(b)
	for f in jeu.feux:
		if is_instance_valid(f):
			f.queue_free()
	jeu.feux.clear()


# ce que le ciel (scripts/ciel.gd) donne à son voile, une fois qu'il a dessiné (deux images : il dessine pendant la seconde)
func _voile(nom: String) -> float:
	await get_tree().process_frame
	await get_tree().process_frame
	var v = jeu.ciel._m_voile.get_shader_parameter(nom)
	return float(v) if v != null else 0.0


# combien de fois chaque temps vient, sur tant de tirages, au climat du lieu
func _tirages(combien: int) -> Dictionary:
	var C = jeu.climat
	var vus := {}
	for k in combien:
		C._suivant()
		vus[C.temps] = int(vus.get(C.temps, 0)) + 1
	C.forcer("clair", 0.0, 9999.0)
	return vus


func _les_pays() -> void:
	print("9. Les pays")
	var Biomes := load("res://scripts/biomes.gd")
	verif(Biomes.de("banquise").has("dit") and Biomes.de("volcan").has("dit") and Biomes.de("marais").has("dit") and Biomes.de("desert").has("dit") and Biomes.de("prairie").is_empty(),
		"quatre pays ont leur caractère (la banquise, le volcan, le marais, le désert) ; la prairie n'en a pas d'autre que ses axes")
	await _les_pays_du_monde()
	await _la_banquise()
	await _le_volcan()
	await _le_marais()
	await _le_desert()


# le monde ouvert : en passant de la steppe au désert, le climat prend le caractère du pays, on le dit, et son sol se fait ; en
# revenant à la prairie, il le perd
func _les_pays_du_monde() -> void:
	var C = jeu.carte
	var W = jeu.monde
	var jo = jeu.joueur
	var T = jeu.terrain
	var vers := func(type: String) -> Vector2:
		var mieux := -1
		for k in C.regions.size():
			if str(C.regions[k]["type"]) == type and (mieux < 0 or C.regions[k]["pos"].length() < C.regions[mieux]["pos"].length()):
				mieux = k
		return C.regions[mieux]["pos"] - C.tordre(C.regions[mieux]["pos"])
	jeu._deja.erase("pays_desert")
	# (la région où elle est, d'abord : c'est en la quittant pour le désert qu'on le dit)
	jeu._regions()
	var desert: Vector2 = vers.call("desert")
	jo.position = desert
	W.suivre(desert, true)
	await jeu._lire_biome("desert")
	jeu._regions()
	T.suivre(desert, true)
	var carcasse: Dictionary = T.le_plus_proche("carcasse", desert)
	var dunes := 0
	for k in T._cases:
		for s in T._cases[k]:
			if str(s["genre"]) == "dune":
				dunes += 1
	var au_desert: bool = jeu.biome == "desert" and jeu.climat.lieu == "desert" and jeu.climat.sol_frein > 0.0 and jeu._deja.has("pays_desert") and not carcasse.is_empty() \
		and C.type_en(carcasse.get("p", Vector2.ZERO)) == "desert" and dunes >= 10
	verif(au_desert, "le monde ouvert : entrée au désert, le climat prend son caractère, on le dit une fois, et son sol se fait autour d'elle (%d dunes, des carcasses)" % dunes)
	if not au_desert:
		print("    (biome %s, climat %s, frein %.2f, dit %s, carcasse %s, région %s)" % [jeu.biome, jeu.climat.lieu, jeu.climat.sol_frein, str(jeu._deja.has("pays_desert")),
			str(carcasse.get("p", "aucune")), C.type_en(desert)])
	var volcan: Vector2 = vers.call("volcan")
	jo.position = volcan
	W.suivre(volcan, true)
	await jeu._lire_biome("volcan")
	jeu._regions()
	T.suivre(volcan, true)
	var fum: Dictionary = T.le_plus_proche("fumerolle", volcan)
	var faille: Dictionary = T.le_plus_proche("faille", volcan)
	var tient: bool = not fum.is_empty() and not faille.is_empty() and C.retenir(fum["p"]) == fum["p"]
	if tient:
		for q in faille["trait"]:
			if C.retenir(q).distance_to(q) > 1.0 or C.type_en(q) != "volcan":
				tient = false
	verif(jeu.climat.lieu == "volcan" and tient and fum.has("noeud") and is_instance_valid(fum["noeud"]),
		"au volcan, des fumerolles et des failles, jamais sur une paroi, une crête ou dans l'eau")
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu._regions()
	T.suivre(Vector2.ZERO, true)
	var hors := true
	for k in T._cases:
		if not T._cases[k].is_empty():
			hors = false
	verif(jeu.biome == "prairie" and jeu.climat.lieu == "prairie" and jeu.climat.identite.is_empty() and jeu.climat.sol_frein == 0.0 and jeu.climat.neige_fond == 0.0 and hors,
		"revenue dans la prairie, le climat perd ce caractère, et le sol des pays lointains s'est défait")


# la banquise : la nuit tue sans feu, la neige ne fond pas et freine, la tourmente ; le bois flotté, l'eau sous la glace
func _la_banquise() -> void:
	await jeu._commencer("banquise")
	var C = jeu.climat
	var T = jeu.terrain
	var j = jeu.joueur
	var RR = jeu.R
	C.forcer("clair", 0.0, 9999.0)
	# (un coin dégagé, loin de tout ce qui pose une question : pas de chose du pays à deux pas)
	var ici := Vector2(-900.0, 600.0)
	for k in 40:
		var q := Vector2(-1500.0 + 75.0 * k, 900.0)
		var libre := true
		for s in T._autour(q, 200.0):
			if Vector2(s["p"]).distance_to(q) < 160.0:
				libre = false
		if libre:
			ici = q
			break
	_remettre(ici)
	_a_l_heure(false)
	for k in 120:
		C.avancer(0.5)
	var neige: float = C.neige_sol
	verif(neige >= RR.NEIGE_AU_SOL and C.allure(ici) < 0.82, "la neige de la banquise ne fond pas, en plein jour d'été (%.2f) : on y marche à %d %% de l'allure" % [neige, int(C.allure(ici) * 100.0)])
	var jour_ := _tenir_au_climat(80.0)
	_remettre(ici)
	_a_l_heure(true)
	var nuit_ := _tenir_au_climat(80.0)
	var titre: String = jeu._titre_de_fin()
	verif(float(nuit_[1]) <= 0.0 and float(nuit_[0]) < 15.0 and titre == "Le froid t'a prise." and float(jour_[1]) > 50.0 and float(jour_[0]) < RR.FROID + 2.0,
		"une nuit de banquise sans feu tue (son corps tombe à %d, sa santé à %d : « %s ») ; le jour, elle a froid sans en mourir (%d, santé %d)" % [
			int(nuit_[0]), int(nuit_[1]), titre, int(jour_[0]), int(jour_[1])])
	# près d'un feu, la même nuit se passe ; dans la pelisse, le froid mord bien moins
	_remettre(ici)
	var f = jeu.Feu.new()
	f.jeu = jeu
	f.position = ici + Vector2(30.0, 0.0)
	f.bois = RR.FEU_MAX
	jeu.monde.add_child(f)
	jeu.feux.append(f)
	var au_feu := _tenir_au_climat(80.0)
	_remettre(ici)
	jeu.atelier.portes["vetement_chaud"] = true
	var pelisse := _tenir_au_climat(80.0)
	jeu.atelier.portes.erase("vetement_chaud")
	verif(float(au_feu[0]) > RR.FROID and float(au_feu[1]) >= 99.0 and float(pelisse[0]) > float(nuit_[0]) + 12.0,
		"près d'un feu, la nuit se passe (corps à %d, santé %d) ; dans la pelisse, sans feu, le froid mord bien moins (%d)" % [int(au_feu[0]), int(au_feu[1]), int(pelisse[0])])
	# la tourmente : on n'y voit plus, le vent se lève, le feu dévore son bois, le corps gèle plus vite
	_remettre(ici)
	_a_l_heure(false)
	var calme := _tenir_au_climat(40.0)
	var feu_calme: float = jeu.feu_temps
	_remettre(ici)
	C.forcer("tourmente", 1.0, 9999.0)
	var dans := _tenir_au_climat(40.0)
	var voile: float = await _voile("tourmente")
	var horloge_dit: String = jeu.texte_horloge()
	var tourmente_ok: bool = C.neige > 0.9 and C.vent > 0.75 and jeu.feu_temps > feu_calme + 0.7 and float(dans[0]) < float(calme[0]) - 8.0 and voile > 0.9 and horloge_dit.contains("tourmente")
	verif(tourmente_ok, "la tourmente : la neige, un vent de %.2f, le feu mange son bois %.1f fois plus vite qu'au calme, le corps tombe à %d (contre %d), on n'y voit plus" % [
		C.vent, jeu.feu_temps / maxf(feu_calme, 0.01), int(dans[0]), int(calme[0])])
	if not tourmente_ok:
		print("    (neige %.2f, voile %.2f, l'horloge : « %s »)" % [C.neige, voile, horloge_dit])
	var tirages := _tirages(400)
	verif(int(tirages.get("tourmente", 0)) >= 20 and int(tirages.get("pluie", 0)) == 0 and int(tirages.get("orage", 0)) == 0 and int(tirages.get("canicule", 0)) == 0,
		"elle revient souvent (%d fois sur 400), et il ne pleut jamais sur la banquise : %s" % [int(tirages.get("tourmente", 0)), str(tirages)])
	# le bois flotté : le seul bois ; trois prises, puis la mer en rapporte. Sous la glace d'une mare, de l'eau pour la gourde
	var bf: Dictionary = T.le_plus_proche("bois_flotte", Vector2.ZERO)
	_remettre(Vector2(bf["p"]) + Vector2(12.0, 4.0) if not bf.is_empty() else ici)
	# (rien d'autre à portée de la main : une bête de passage, « Agir » la frapperait ; et de la place dans le sac)
	for b in get_tree().get_nodes_in_group("betes"):
		if is_instance_valid(b) and b.position.distance_to(j.position) < 260.0:
			_oter(b)
	j.inventaire["bois"] = 0
	var bois0 := int(j.inventaire["bois"])
	for k in 4:
		jeu.agir()
	var pris := int(j.inventaire["bois"]) - bois0
	var vide: int = T.reste(bf) if not bf.is_empty() else -1
	jeu.horloge += RR.BOIS_FLOTTE_REVIENT + 1.0
	verif(not bf.is_empty() and pris == 6 and vide == 0 and T.reste(bf) == 3 and jeu._deja.has("butin_bois_flotte"),
		"le bois flotté : trois prises, deux bois chacune (+%d), puis plus rien ; deux jours plus tard, la mer en a rapporté" % pris)
	var mare: Dictionary = T.le_plus_proche("mare", Vector2.ZERO)
	_remettre(Vector2(mare["p"]) + Vector2(0.0, 6.0) if not mare.is_empty() else ici)
	# (pas de bête à portée de la main : « Agir » la frapperait au lieu de casser la glace)
	for b in get_tree().get_nodes_in_group("betes"):
		if is_instance_valid(b) and b.position.distance_to(j.position) < 260.0:
			_oter(b)
	j.inventaire["eau"] = 0
	jeu.agir()
	var sans_gourde := int(j.inventaire.get("eau", 0))
	jeu.atelier.objets["gourde"] = 1
	jeu.agir()
	verif(not mare.is_empty() and sans_gourde == 0 and int(j.inventaire["eau"]) == jeu.atelier.GORGEES,
		"sous la glace d'une mare, de l'eau : sans gourde, on ne l'emporte pas ; avec, elle est pleine (%d gorgées)" % int(j.inventaire["eau"]))
	jeu.atelier.objets.erase("gourde")


# le volcan : la fumerolle (sa chaleur, sa bouffée qui brûle), la faille (on y prend feu), la pluie de cendres ; l'obsidienne,
# qui fait une lance ; ce qu'on y a pris se garde
func _le_volcan() -> void:
	await jeu._commencer("volcan")
	var C = jeu.climat
	var T = jeu.terrain
	var j = jeu.joueur
	var RR = jeu.R
	C.forcer("clair", 0.0, 9999.0)
	var fum: Dictionary = T.le_plus_proche("fumerolle", Vector2.ZERO)
	var o: Vector2 = fum.get("p", Vector2.ZERO)
	var pres: float = T.chaleur(o + Vector2(50.0, 0.0))
	# (loin de toute fumerolle, de toute faille : le sol n'y chauffe pas)
	var loin := -1.0
	for k in 60:
		var q := Vector2(-1800.0 + 60.0 * k, -1700.0)
		var degage := true
		for s in T._autour(q, 300.0):
			if str(s["genre"]) in ["fumerolle", "faille"] and Vector2(s["p"]).distance_to(q) < 300.0:
				degage = false
		if degage:
			loin = T.chaleur(q)
			break
	# (à l'heure où elle siffle, puis où elle crache)
	var periode := float(fum.get("periode", 10.0))
	var phase := float(fum.get("phase", 0.0))
	var base := ceilf((jeu.horloge + phase) / periode) * periode - phase + periode
	jeu.horloge = base + periode - 0.5
	var siffle: bool = T.siffle(fum) and T.crache(fum) == 0.0
	_remettre(o + Vector2(14.0, 6.0))
	for k in 6:
		T._dangers(0.25, j.position)
	var avant_la_bouffee: float = j.sante
	jeu.horloge = base + 1.2
	var bouffee: float = T.crache(fum)
	for k in 6:
		T._dangers(0.25, j.position)
	var brulee: float = j.sante
	var titre: String = jeu._titre_de_fin()
	verif(not fum.is_empty() and pres > 10.0 and loin == 0.0 and siffle and avant_la_bouffee == 100.0 and bouffee > 0.8 and brulee < 92.0 and titre.contains("fumerolle"),
		"une fumerolle chauffe tout près (+%d au corps), siffle, puis crache : sa vapeur brûle qui est contre elle (santé %d, « %s »)" % [int(pres), int(brulee), titre])
	# la faille : y mettre le pied, c'est prendre feu
	var faille: Dictionary = T.le_plus_proche("faille", Vector2.ZERO)
	var t: PackedVector2Array = faille.get("trait", PackedVector2Array([Vector2(9999, 9999), Vector2(9999, 9999)]))
	var a_cote: Vector2 = t[3] + (t[4] - t[3]).normalized().orthogonal() * 60.0
	_remettre(a_cote)
	T._dangers(0.1, j.position)
	var pas_encore: bool = j.en_feu <= 0.0
	_remettre(t[3])
	T._dangers(0.1, j.position)
	verif(not faille.is_empty() and pas_encore and j.en_feu > 0.0 and T.chaleur(a_cote) > 0.0,
		"une faille rougeoie : à côté, il fait chaud ; le pied dedans, elle prend feu")
	_remettre(Vector2(-1500.0, -1500.0))
	# la pluie de cendres : le ciel s'éteint, la vue se ferme ; elle revient au volcan, et seulement là
	C.forcer("cendres", 1.0, 9999.0)
	var voile: float = await _voile("cendre")
	var cendreux: bool = jeu.ciel._voile.visible and jeu.ciel._chute.visible
	var tirages := _tirages(400)
	verif(voile > 0.9 and cendreux and int(tirages.get("cendres", 0)) >= 15 and not tirages.has("tourmente") and not tirages.has("sable"),
		"il pleut des cendres sur le volcan (%d fois sur 400) : le ciel s'éteint, des flocons gris tombent" % int(tirages.get("cendres", 0)))
	# l'obsidienne : on la taille, et à l'établi elle fait une lance
	var obs: Dictionary = T.le_plus_proche("obsidienne", Vector2.ZERO)
	_remettre(Vector2(obs.get("p", Vector2.ZERO)) + Vector2(10.0, 4.0))
	for k in 3:
		jeu.agir()
	var taillee := int(j.inventaire.get("obsidienne", 0))
	var A = jeu.atelier
	var etabli = A._creer("etabli", j.position + Vector2(30.0, 0.0), {})
	j.inventaire["bois"] = 5
	j.inventaire["corde"] = 2
	j.lance = 0
	var faite: bool = A.fabriquer("lance_obsidienne")
	verif(not obs.is_empty() and taillee == 3 and T.reste(obs) == 0 and faite and j.lance == RR.USURE_LANCE and int(j.inventaire["obsidienne"]) == 1
		and int(j.inventaire["bois"]) == 3 and A.possede("lance_obsidienne") == 0,
		"l'obsidienne se taille (trois éclats) ; à l'établi, deux éclats, du bois et une corde font une lance, aussitôt dans ses mains")
	A.poses.erase(etabli)
	etabli.queue_free()
	# ce qu'on a pris au volcan se garde avec la partie
	var gardee: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	await jeu._commencer("volcan", gardee)
	var obs2: Dictionary = jeu.terrain.le_plus_proche("obsidienne", obs["p"])
	verif(str(obs2.get("id", "")) == str(obs["id"]) and jeu.terrain.reste(obs2) == 0 and int(jeu.joueur.inventaire.get("obsidienne", 0)) == 1 and jeu.climat.lieu == "volcan",
		"reprise, la partie retrouve le volcan pareil : l'obsidienne taillée l'est toujours, l'éclat qui reste est dans le sac")


# le marais : la fondrière (on s'y enfonce si l'on s'arrête, les sangsues), le brouillard, les feux follets ; la tourbe, qui tient le feu
func _le_marais() -> void:
	await jeu._commencer("marais")
	var C = jeu.climat
	var T = jeu.terrain
	var j = jeu.joueur
	var RR = jeu.R
	C.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	var fon: Dictionary = T.le_plus_proche("fondriere", Vector2(800.0, 800.0))
	var o: Vector2 = fon.get("p", Vector2.ZERO)
	_remettre(o)
	var eau: float = C.eau(o)
	var au_bord: float = C.allure(o)
	# (elle s'arrête au milieu : elle s'enfonce ; les sangsues)
	for k in 24:
		T._dangers(0.25, j.position)
	var enfoncee: float = T.enlise
	var engluee: float = jeu.allure_sol(j.position)
	var eau_enfoncee: float = C.eau(j.position)
	var sangsues: float = float(jeu._maux.get("sangsues", 0.0))
	verif(not fon.is_empty() and eau >= 0.45 and enfoncee > 0.95 and engluee < 0.2 and eau_enfoncee > 0.95 and sangsues > 0.5 and jeu._titre_de_fin() == "La fondrière t'a prise.",
		"une fondrière : de l'eau aux genoux (%.2f) ; arrêtée, elle s'enfonce jusqu'aux cuisses, n'avance plus qu'à %d %% de l'allure, et les sangsues s'y mettent" % [eau, int(engluee * 100.0)])
	# (elle marche : elle s'en tire, lentement)
	j.en_mouvement = true
	for k in 8:
		T._dangers(0.25, j.position)
	verif(T.enlise < enfoncee - 0.5 and jeu.allure_sol(j.position) > engluee * 2.0 and au_bord < 0.85,
		"en marchant, elle s'en tire peu à peu (enfoncée à %d %%, deux secondes plus tard)" % int(T.enlise * 100.0))
	# le brouillard : il vient bien plus souvent au marais
	var siens := _tirages(400)
	var garde: Dictionary = C.identite
	C.identite = {}
	var sans := _tirages(400)
	C.identite = garde
	verif(int(siens.get("brouillard", 0)) > int(sans.get("brouillard", 0)) * 2 and int(siens.get("brouillard", 0)) >= 40,
		"le brouillard vient bien plus souvent au marais (%d fois sur 400, contre %d sans son caractère)" % [int(siens.get("brouillard", 0)), int(sans.get("brouillard", 0))])
	# la nuit, des feux follets dansent au-dessus des fondrières, et fuient qui approche
	_a_l_heure(true)
	_remettre(Vector2(-1600.0, 1600.0))
	var follets := 0
	for i in 2:
		for k in T._cases:
			for s in T._cases[k]:
				if str(s["genre"]) == "fondriere" and bool(s.get("follet", false)) and follets == 0:
					j.position = Vector2(s["p"]) + Vector2(400.0, 0.0)
		for k in 30:
			T._follets_(0.25, j.position)
		follets = 0
		for id in T._follets:
			if float(T._follets[id][1]) > 0.5:
				follets += 1
	var fuit := 1.0
	var file := 0.0
	for id in T._follets:
		if float(T._follets[id][1]) > 0.5:
			var avant: Vector2 = T._follets[id][0]
			j.position = avant + Vector2(60.0, 0.0)
			for k in 4:
				T._follets_(0.25, j.position)
			fuit = float(T._follets[id][1])
			file = Vector2(T._follets[id][0]).distance_to(j.position) - 60.0
			break
	verif(follets >= 1 and fuit < 0.3 and file > 20.0, "la nuit, des feux follets luisent au-dessus des fondrières (%d) ; on s'en approche, ils s'éteignent et filent (%d pixels plus loin)" % [follets, int(file)])
	_a_l_heure(false)
	# la tourbe : on la coupe, et elle tient un feu bien plus longtemps qu'une bûche
	var tb: Dictionary = T.le_plus_proche("tourbe", Vector2.ZERO)
	_remettre(Vector2(tb.get("p", Vector2.ZERO)) + Vector2(10.0, 4.0))
	jeu.agir()
	var coupee := int(j.inventaire.get("tourbe", 0))
	var f = jeu.Feu.new()
	f.jeu = jeu
	f.position = j.position + Vector2(40.0, 0.0)
	f.bois = 10.0
	jeu.monde.add_child(f)
	jeu.feux.append(f)
	var bois0 := int(j.inventaire["bois"])
	jeu.nourrir_feu()
	verif(not tb.is_empty() and coupee == 1 and absf(f.bois - 10.0 - RR.TOURBE_FEU) < 0.5 and int(j.inventaire["tourbe"]) == 0 and int(j.inventaire["bois"]) == bois0
		and RR.TOURBE_FEU > RR.FEU_BUCHE * 2.0,
		"la tourbe se coupe ; nourri d'une motte, le feu gagne %d secondes (une bûche : %d), sans toucher au bois" % [int(RR.TOURBE_FEU), int(RR.FEU_BUCHE)])


# le désert : des jours qui brûlent et des nuits qui gèlent, la canicule hors de l'été, le vent de sable, le sable qui freine ;
# les carcasses ensablées, et leur ferraille
func _le_desert() -> void:
	await jeu._commencer("desert")
	var C = jeu.climat
	var T = jeu.terrain
	var j = jeu.joueur
	var RR = jeu.R
	C.forcer("clair", 0.0, 9999.0)
	# (à découvert : pas un arbre au-dessus d'elle)
	var ici := Vector2(-900.0, 900.0)
	for k in 60:
		var q := Vector2(-1500.0 + 55.0 * k, 1100.0)
		if C.abri(q) == 0.0 and jeu.monde.autour(q, 120.0).filter(func(x): return x.couvert() > 0.0).is_empty():
			ici = q
			break
	_remettre(ici)
	_a_l_heure(false)
	var air_jour: float = C.air
	var jour_ := _tenir_au_climat(60.0)
	_remettre(ici)
	_a_l_heure(true)
	var air_nuit: float = C.air
	var nuit_ := _tenir_au_climat(60.0)
	verif(air_jour - air_nuit > 0.4 and float(jour_[0]) > RR.CHAUD + 2.0 and float(nuit_[0]) < RR.FROID,
		"le désert : le jour brûle à découvert (le corps monte à %d), la nuit gèle (il tombe à %d) ; l'air passe de %.2f à %.2f" % [int(jour_[0]), int(nuit_[0]), air_jour, air_nuit])
	# la canicule y vient en toute saison, sauf l'hiver
	var saison: String = jeu.saison
	jeu.saison = "printemps"
	var printemps := _tirages(400)
	jeu.saison = "hiver"
	var hiver := _tirages(400)
	jeu.saison = saison
	verif(int(printemps.get("canicule", 0)) >= 20 and int(hiver.get("canicule", 0)) == 0 and int(printemps.get("sable", 0)) >= 20,
		"au printemps aussi, la canicule écrase le désert (%d fois sur 400), jamais l'hiver ; le vent de sable vient souvent (%d)" % [int(printemps.get("canicule", 0)), int(printemps.get("sable", 0))])
	# le sable freine ; le vent de sable bien plus, et on n'y voit plus
	_a_l_heure(false)
	var au_sable: float = C.allure(ici)
	var air_clair: float = C.air
	C.forcer("sable", 1.0, 9999.0)
	for k in 40:
		C.avancer(0.5)
	jeu._temps_du_corps(0.1)
	var voile: float = await _voile("sable")
	verif(au_sable < 0.95 and C.allure(ici) < au_sable * 0.8 and C.vent > 0.65 and voile > 0.9 and jeu.feu_temps > 1.4 and C.air > air_clair + 0.03,
		"le sable freine le pas (%d %% de l'allure) ; dans le vent de sable, bien plus (%d %%), on n'y voit plus, un vent brûlant (l'air passe de %.2f à %.2f), et le feu mange son bois plus vite" % [
			int(au_sable * 100.0), int(C.allure(ici) * 100.0), air_clair, C.air])
	C.forcer("clair", 0.0, 9999.0)
	# une carcasse ensablée : de la ferraille
	var ca: Dictionary = T.le_plus_proche("carcasse", Vector2.ZERO)
	_remettre(Vector2(ca.get("p", Vector2.ZERO)) + Vector2(10.0, 4.0))
	var fer0 := int(j.inventaire.get("ferraille", 0))
	for k in 3:
		jeu.agir()
	verif(not ca.is_empty() and int(j.inventaire["ferraille"]) == fer0 + 3 and T.reste(ca) == 0,
		"une vieille carcasse, à demi ensablée : trois morceaux de ferraille, puis plus rien")



# --- l'artisanat des plantes (scripts/flore.gd, scripts/atelier.gd, scripts/elevage.gd, scripts/pont.gd, scripts/botanique.gd) :
# la fibre longue de l'agave et du papyrus, le filin qu'on en commet, et ce qu'il tient (une bête affolée par le noir, une
# grosse proie, un pont) ; les aromates, leur baume et leur fumée. Une partie à elle, au désert (l'agave, l'aromatique), puis
# au marais (les sangsues). Joué sans attendre, par les fonctions du jeu ---

func _l_artisanat() -> void:
	print("10. L'artisanat des plantes")
	await jeu._commencer("desert")
	var j = jeu.joueur
	var A = jeu.atelier
	var E = jeu.elevage
	var B = jeu.botanique
	var C = jeu.climat
	var W = jeu.monde
	var RR = jeu.R
	var Flore = load("res://scripts/flore.gd")
	var inv: Dictionary = j.inventaire
	C.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	var ici := Vector2(-700.0, 700.0)
	_remettre(ici)
	j.torche = 0.0

	# l'agave et le papyrus donnent la fibre longue ; l'agave pique toujours ; l'aromatique donne des aromates ; la bruyère garde
	# ses fleurs
	var de_forme := func(f: String, strate: String):
		var mieux = null
		for o in W.objets:
			if is_instance_valid(o) and str(o.forme) == f and int(o.reste) > 0 and (mieux == null or o.position.distance_to(ici) < mieux.position.distance_to(ici)):
				mieux = o
		if mieux != null:
			return mieux
		for k in 800:
			var o = W._poser(strate, ici + Vector2(0, 60), Color.WHITE, 9100 + k * 7919)
			if o != null and str(o.forme) == f:
				return o
			if o != null:
				W._defaire(o)
		return null
	var cueillir := func(o) -> Dictionary:
		j.position = o.position + Vector2(0, 2)
		for b in get_tree().get_nodes_in_group("betes"):
			_oter(b)
		# (un vestige, un coffre tout près : « Agir » le fouillerait d'abord)
		for x in jeu.atelier.poses.duplicate():
			if is_instance_valid(x) and x.position.distance_to(o.position) < 120.0:
				jeu.atelier.poses.erase(x)
				x.queue_free()
		var avant := inv.duplicate()
		# (ni ce que le pays pose au sol, une carcasse du désert à deux pas : « Agir » la fouillerait d'abord)
		var terrain_g = jeu.terrain
		jeu.terrain = null
		jeu.agir()
		jeu.terrain = terrain_g
		var gagne := {}
		for k in inv:
			if int(inv[k]) != int(avant.get(k, 0)):
				gagne[k] = int(inv[k]) - int(avant.get(k, 0))
		return gagne
	var agave = de_forme.call("agave", "sol")
	var aromatique = de_forme.call("aromatique", "buisson")
	j.sante = 80.0
	var g_agave: Dictionary = cueillir.call(agave) if agave != null else {}
	var pique: float = 80.0 - j.sante
	j.sante = 100.0
	var Objet = load("res://scripts/objet.gd")
	var papyrus = Objet.new()
	papyrus.preparer("touffe", Color.WHITE, 4242)
	papyrus.porter_plante({"forme": "papyrus", "port": "roseau", "id": "essai-papyrus"})
	var g_papyrus: Dictionary = papyrus.recolter()
	var papyrus_pique: bool = papyrus.piquant
	papyrus.free()
	var g_aromatique: Dictionary = cueillir.call(aromatique) if aromatique != null else {}
	var aromatique_entame: bool = aromatique != null and int(aromatique.reste) < int(aromatique.plein)
	verif(agave != null and agave.piquant and g_agave == {"fibre_longue": 1} and absf(pique - RR.EPINES) < 0.01 and g_papyrus == {"fibre_longue": 1} and not papyrus_pique
		and A.MATIERES.has("fibre_longue") and aromatique != null and g_aromatique == {"aromates": 1} and aromatique_entame and not aromatique.piquant
		and Flore.donne("bruyere", "buisson", true, false) == "fleurs" and Flore.donne("aromatique", "buisson", false, false) == "aromates",
		"au désert, un agave donne la fibre longue (%s), et pique toujours (-%d) ; un papyrus aussi (%s) ; un buisson aromatique, des aromates, en fleurs ou non (%s) ; la bruyère garde ses fleurs" % [
		str(g_agave), int(pique), str(g_papyrus), str(g_aromatique)])

	# le filin : trois fibres longues à l'établi ; la longe de filin, le grand filet
	A.commencer()
	for k in ["bois", "pierre", "fibre", "fibre_longue", "filin", "corde", "peau", "aromates", "eau", "baume_aromates"]:
		inv[k] = 0
	inv["bois"] = 20
	inv["pierre"] = 12
	inv["fibre"] = 10
	inv["fibre_longue"] = 15
	j.position = ici
	# (rien ne gêne l'établi devant elle : un buisson, une touffe)
	for o in W.autour(ici + Vector2(60.0, 6.0), 70.0):
		if str(o.genre) == "buisson":
			W.retirer(o)
	A.fabriquer("etabli")
	A.poser("etabli")
	var sans_fibre: String = ""
	var commis := 0
	for k in 6:
		if A.fabriquer("filin"):
			commis += 1
		else:
			sans_fibre = A.empeche("filin")
	var longe: bool = A.fabriquer("longe")
	var grand: bool = A.fabriquer("filet_filin")
	verif(commis == 5 and int(inv["fibre_longue"]) == 0 and sans_fibre.contains("fibres longues") and longe and grand and A.possede("longe") == 1
		and A.possede("filet_filin") == 1 and int(inv["filin"]) == 0 and int(inv["pierre"]) == 12 - 2 - 4
		and A.OBJETS["filin"]["cout"] == {"fibre_longue": 3} and A.OBJETS["longe"]["cout"] == {"filin": 2} and A.OBJETS["filet_filin"]["cout"] == {"filin": 3, "pierre": 4},
		"à l'établi, trois fibres longues font un filin (cinq de quinze ; puis « %s ») ; deux filins, une longe de filin ; trois et quatre pierres, un grand filet" % sans_fibre)

	# le grand filet tient une bête de vingt kilos, que le filet de corde laisse passer ; relevé, il donne sa viande et ses peaux
	var proies: Array = jeu.faune["proies_jour"] + jeu.faune["proies_nuit"]
	var e_grosse: Dictionary = {}
	for e in proies:
		e_grosse = e.duplicate()
		break
	e_grosse["masse"] = 20.0
	e_grosse.erase("largeur")
	inv["corde"] = 3
	A.fabriquer("filet")
	var p_filet: Vector2 = ici + Vector2(-260.0, 0.0)
	var p_grand: Vector2 = ici + Vector2(-260.0, 160.0)
	var filet = A._creer("filet", p_filet, {})
	var grand_filet = A._creer("filet_filin", p_grand, {})
	var b1 = _bete(e_grosse, "proie", p_filet, {})
	A.maj(0.1)
	var passe: bool = not filet.etat.has("prise") and is_instance_valid(b1) and b1.is_in_group("betes")
	_oter(b1)
	var b2 = _bete(e_grosse, "proie", p_grand + Vector2(12.0, 6.0), {})
	A.maj(0.1)
	var prise: bool = grand_filet.etat.has("prise") and not b2.is_in_group("betes")
	j.position = p_grand + Vector2(-20.0, 0.0)
	var peaux0 := int(inv.get("peau", 0))
	var viande0 := int(inv.get("viande", 0))
	A.agir()
	var releve: bool = not grand_filet.etat.has("prise") and int(inv["peau"]) - peaux0 == A.peaux_de(20.0) and int(inv["viande"]) > viande0
	verif(passe and prise and releve and RR.FILET_FILIN >= 20.0 and A.PRISE_MAX < 20.0,
		"une bête de 20 kilos passe sur le filet de corde (%d kilos au plus) ; le grand filet, de filin, la tient (%d kilos au plus) : relevé, sa viande et %d peaux" % [
		int(A.PRISE_MAX), int(RR.FILET_FILIN), A.peaux_de(20.0)])

	# la longe de filin : la nuit, dans le noir, une bête au piquet s'affole et se débat, mais reste ; celle qui n'a que sa longe
	# de chanvre la rompt et s'enfuit ; celle qui a sa longe de filin mais que rien ne tient, s'enfuit aussi
	var e_bete: Dictionary = {}
	var b_essai = null
	for e in proies:
		b_essai = _bete(e, "proie", ici, {})
		var bonne: bool = E.apprivoisable(b_essai)
		_oter(b_essai)
		if bonne:
			e_bete = e
			break
	if e_bete.is_empty():
		verif(false, "le désert a une proie à quatre pattes à apprivoiser")
		return
	var piquet = A._creer("piquet", ici + Vector2(300.0, -200.0), {})
	var apprivoiser := func(p: Vector2):
		var b = _bete(e_bete, "proie", p, {"neophobie": 0.05})
		A.objets["licol"] = 1
		E.apprivoiser(b)
		b.suit_la = false
		b.maison = p
		b.faim = 90.0
		return b
	var tenue_filin = apprivoiser.call(piquet.position + Vector2(18.0, 10.0))
	var sans_filin = apprivoiser.call(piquet.position + Vector2(-18.0, 10.0))
	var seule = apprivoiser.call(ici + Vector2(-600.0, -400.0))
	# (la longe se passe depuis le sac, la bête tout près ; une seule longe : la seconde se fabrique)
	j.position = tenue_filin.position + Vector2(30.0, 0.0)
	jeu.ouvrir_page("sac")
	var page_sac = jeu.ui._pages.get("sac")
	var tuile_longe := false
	if page_sac != null:
		for sec in page_sac._sections():
			for tu in sec["tuiles"]:
				if str(tu["cle"]) == "bete:longe":
					tuile_longe = true
		page_sac._faire_au_jardin("bete:longe")
	jeu.fermer_page()
	A.objets["longe"] = 1
	var passee: bool = E.harnacher(seule, "longe")
	j.position = ici + Vector2(-900.0, 600.0)
	_a_l_heure(true)
	var faim0: float = float(tenue_filin.faim)
	var faim_sans0: float = float(sans_filin.faim)
	var debattue := false
	for i in 40:
		E.maj(1.0)
		debattue = debattue or E.affolee(tenue_filin)
	var reste: bool = E.betes.has(tenue_filin) and str(tenue_filin.role) == "compagne" and bool(tenue_filin.harnais.get("longe", false))
	var a_eu_faim: float = faim0 - float(tenue_filin.faim)
	var rompue: bool = not E.betes.has(sans_filin) and str(sans_filin.role) == "proie" and sans_filin.harnais.is_empty()
	var fuie: bool = not E.betes.has(seule) and str(seule.role) == "proie"
	# (affolée dix-huit secondes sur quarante, elle a eu faim deux fois plus vite pendant ce temps)
	verif(tuile_longe and bool(tenue_filin.harnais.get("longe", false)) and passee and reste and debattue and rompue and fuie and a_eu_faim > E.FAIM * 40.0 * 1.3
		and float(tenue_filin.faim) > 0.0,
		"la longe de filin se passe depuis le sac ; la nuit, au piquet dans le noir, sa bête se débat au bout (affolée, elle a eu faim de %d en 40 secondes), mais le filin tient ; celle qui n'a que sa longe de chanvre la rompt au bout de %d secondes ; celle que rien ne tient s'enfuit" % [
		int(a_eu_faim), int(E.NOIR)])
	# (près d'un feu, elle se calme : plus d'affolement)
	var feu_b = jeu.Feu.new()
	feu_b.jeu = jeu
	feu_b.position = tenue_filin.position + Vector2(40.0, 0.0)
	feu_b.bois = 60.0
	jeu.monde.add_child(feu_b)
	jeu.feux.append(feu_b)
	for i in 30:
		E.maj(0.5)
	verif(not E.affolee(tenue_filin) and E.betes.has(tenue_filin), "près d'un feu, la nuit, elle cesse de se débattre")
	jeu.feux.erase(feu_b)
	feu_b.queue_free()
	_a_l_heure(false)

	# le pont lié de filin : il tient trois fois plus, chaque passage l'use moins, la crue ne l'emporte qu'à son plus fort ; avec
	# deux filins dans le sac, le pont se lie de filin, à la place de ses fibres
	inv["filin"] = 0
	inv["fibre"] = 3
	inv["bois"] = 6
	var cout_fibres: Dictionary = jeu.cout_de("pont")
	inv["filin"] = 2
	inv["fibre"] = 0
	var cout_filin: Dictionary = jeu.cout_de("pont")
	var garde_pp: bool = jeu.pont_possible
	jeu.pont_possible = true
	var faisable: bool = jeu.peut_fabriquer("pont")
	jeu.pont_possible = garde_pp
	var pa: Vector2 = ici + Vector2(400.0, 300.0)
	var de_fibres = jeu.poser_pont(pa, pa + Vector2(160.0, 0.0), RR.PONT_DUREE)
	var de_filin = jeu.poser_pont(pa + Vector2(0.0, 120.0), pa + Vector2(160.0, 120.0), RR.PONT_DUREE * RR.PONT_FILIN_DUREE, true)
	# (elle passe sur chacun, une fois)
	var usures := []
	for pt in [de_fibres, de_filin]:
		var t0: float = pt.tenue
		j.position = (pt.a + pt.b) * 0.5 + Vector2(0.0, 200.0)
		pt._process(0.0)
		j.position = (pt.a + pt.b) * 0.5
		pt._process(0.0)
		j.position = (pt.a + pt.b) * 0.5 + Vector2(0.0, 200.0)
		pt._process(0.0)
		usures.append(t0 - pt.tenue)
	# (le temps passe : quatre cents secondes)
	for i in 400:
		if is_instance_valid(de_fibres) and jeu.ponts.has(de_fibres):
			de_fibres._process(1.0)
		de_filin._process(1.0)
	var fibres_tombe: bool = not jeu.ponts.has(de_fibres)
	var filin_tient: bool = jeu.ponts.has(de_filin)
	var de_fibres2 = jeu.poser_pont(pa + Vector2(0.0, 240.0), pa + Vector2(160.0, 240.0), RR.PONT_DUREE)
	C.crue = 0.75
	de_fibres2._process(0.1)
	de_filin._process(0.1)
	var crue_fibres: bool = not jeu.ponts.has(de_fibres2)
	var crue_filin: bool = jeu.ponts.has(de_filin)
	C.crue = 0.0
	verif(cout_fibres == {"bois": 6, "fibre": 3} and cout_filin == {"bois": 6, "filin": RR.PONT_FILIN} and faisable and absf(float(usures[0]) - RR.PONT_PASSAGE) < 0.01
		and absf(float(usures[1]) - RR.PONT_PASSAGE * RR.PONT_FILIN_USURE) < 0.01 and fibres_tombe and filin_tient and crue_fibres and crue_filin and de_filin.lie,
		"avec deux filins, le pont se lie de filin (%s) ; un passage use un pont de fibres de %d secondes, lié de filin de %d ; quatre cents secondes plus tard, le pont de fibres a cédé, l'autre tient ; une crue à 0,75 emporte le premier, pas le second" % [
		str(cout_filin), int(usures[0]), int(usures[1])])

	# les aromates : pilés au mortier dans une gorgée d'eau, un baume ; il soigne longtemps, et chasse le poison bien plus vite
	inv["aromates"] = 5
	inv["eau"] = 2
	A.objets.erase("mortier")
	var sans_mortier: String = B.empeche_piler_aromates()
	A.objets["mortier"] = 1
	var pile: bool = B.piler_aromates()
	var apres_pile: bool = int(inv["baume_aromates"]) == 1 and int(inv["aromates"]) == 5 - RR.AROMATES_BAUME and int(inv["eau"]) == 1
	j.sante = 30.0
	B.poison = B.POISON
	var oint: bool = B.oindre()
	var poison_t := 0.0
	for i in 20:
		B.maj(0.5)
		if B.poison > 0.0:
			poison_t += 0.5
	var sante_10: float = j.sante
	for i in 70:
		B.maj(0.5)
	var sante_fin: float = j.sante
	# (le même poison, sans baume : il dure ses dix-huit secondes)
	j.sante = 100.0
	verif(sans_mortier.contains("mortier") and pile and apres_pile and oint and poison_t <= 5.0 and B.poison == 0.0 and B.onguent == 0.0 and sante_fin > 30.0 + RR.ONGUENT * RR.ONGUENT_SOIN - 12.0
		and sante_10 > 30.0 and RR.ONGUENT * RR.ONGUENT_SOIN > 45.0,
		"au mortier, %d aromates et une gorgée d'eau font un baume ; oint, le poison (%d secondes d'ordinaire) s'en va en %.1f, et la santé remonte de 30 à %d en %d secondes" % [
		RR.AROMATES_BAUME, int(B.POISON), poison_t, int(sante_fin), int(RR.ONGUENT)])

	# jetés dans un feu : une fumée bleue jusqu'au bord de sa lumière ; qui s'y tient sent sa peur tomber, et en garde l'odeur
	# (sa bête reste au piquet : on ne la retire pas)
	j.position = ici
	j.peur = 0.0
	var f = jeu.Feu.new()
	f.jeu = jeu
	f.position = ici + Vector2(40.0, 0.0)
	f.bois = 80.0
	jeu.monde.add_child(f)
	jeu.feux.append(f)
	inv["aromates"] = 1
	var trop_peu: String = B.empeche_fumiger()
	inv["aromates"] = 2
	var journal = jeu.sons.journal
	jeu.sons.journal = []
	var jete: bool = B.fumiger()
	var entendus: Array = jeu.sons.journal.map(func(x): return str(x[1]).rstrip("0123456789"))
	jeu.sons.journal = journal
	# (les brins volent encore : la fumée prend quand ils tombent dans le feu)
	var fumee_vue := false
	for i in 12:
		await _attendre(0.25)
		fumee_vue = f._encens != null and is_instance_valid(f._encens)
		if fumee_vue:
			break
	j.position = f.position + Vector2(-30.0, 12.0)
	j.peur = 80.0
	var dans: float = B.dans_l_encens(j.position)
	for i in 10:
		B.maj(0.5)
	var peur_dedans: float = j.peur
	var impregnee: bool = B.impregnee()
	# (hors de la fumée, au-delà de la lumière : rien ne l'apaise, l'odeur reste sur elle un moment)
	j.position = f.position + Vector2(B.portee_encens(f) + 120.0, 0.0)
	j.peur = 80.0
	for i in 10:
		B.maj(0.5)
	var peur_dehors: float = j.peur
	var encore: bool = B.impregnee() and B.parfum < RR.PARFUM
	# (sa durée : une minute et demie)
	for i in 74:
		B.maj(1.0)
	var tient_encore: bool = B.encens.has(f)
	for i in 6:
		B.maj(1.0)
	var finie: bool = not B.encens.has(f)
	verif(trop_peu.contains("aromates") and jete and int(inv["aromates"]) == 0 and entendus.has("aromates") and fumee_vue and dans > 0.9 and peur_dedans < 80.0 - RR.ENCENS_APAISE * 5.0 + 1.0
		and impregnee and absf(peur_dehors - 80.0) < 0.01 and encore and tient_encore and finie,
		"%d aromates jetés au feu (on les entend crépiter) : sa fumée bleue monte ; tenue dedans cinq secondes, la peur tombe de 80 à %d (dehors, rien) ; l'odeur lui reste ; la fumée dure %d secondes%s" % [
		RR.AROMATES_FEU, int(peur_dedans), int(RR.ENCENS), "" if fumee_vue and entendus.has("aromates") and dans > 0.9 and tient_encore and finie else
		" (vue %s, entendue %s, dedans %.2f, encore %s, finie %s, %s)" % [fumee_vue, entendus.has("aromates"), dans, tient_encore, finie, str(entendus)]])

	# ce qu'on en voit : chaque chose a son icône ; le sac propose les aromates (un baume, au feu) et leur baume ; la carte du
	# pont, au HUD, dit son filin quand elle en a
	var Ic = load("res://scripts/atelier_icones.gd")
	var dessinees := true
	for id in ["fibre_longue", "filin", "filet_filin", "longe", "aromates", "baume_aromates", "fumigation"]:
		dessinees = dessinees and Ic.connue(id)
	inv["aromates"] = 3
	inv["baume_aromates"] = 1
	j.position = f.position + Vector2(-30.0, 12.0)
	jeu.ouvrir_page("sac")
	var sac2 = jeu.ui._pages.get("sac")
	var tuiles_a := {}
	if sac2 != null:
		for sec in sac2._sections():
			for tu in sec["tuiles"]:
				if str(tu["cle"]) in ["use:aromates", "use:fumigation", "use:baume_aromates"]:
					tuiles_a[str(tu["cle"])] = not bool(tu.get("pale", false))
	var fiche_f: Dictionary = sac2._fiche_de("use:fumigation") if sac2 != null else {}
	jeu.fermer_page()
	var Hud = load("res://scripts/interface_hud.gd")
	var carte_pont = Hud.Recette.new("pont")
	carte_pont.maj(false, {"bois": 6, "filin": 2})
	var cout_carte: Dictionary = carte_pont.cout.duplicate()
	carte_pont.free()
	verif(dessinees and tuiles_a.size() == 3 and bool(tuiles_a.get("use:fumigation", false)) and str(fiche_f.get("bouton", "")) == "Jeter au feu" and bool(fiche_f.get("actif", false))
		and cout_carte == {"bois": 6, "filin": RR.PONT_FILIN},
		"chaque chose a son icône à l'encre ; près d'un feu, le sac propose les aromates, « Jeter au feu » et leur baume ; la carte du pont dit son filin (%s)" % str(cout_carte))

	# la partie gardée : ce qu'elle porte, son camp, sa bête et sa longe, le pont lié, le baume qui agit, la fumée sur son feu,
	# l'odeur sur elle
	inv["filin"] = 3
	inv["aromates"] = 4
	inv["baume_aromates"] = 1
	B.encens[f] = 50.0
	B.onguent = 12.0
	B.parfum = 90.0
	j.position = tenue_filin.position + Vector2(-30.0, 0.0)
	var PG := load("res://scripts/partie_gardee.gd")
	var gardee: Dictionary = JSON.parse_string(JSON.stringify(PG.photo(jeu)))
	await jeu._commencer("desert", gardee)
	var f2 = jeu.feux[0] if not jeu.feux.is_empty() else null
	var lie: Array = jeu.ponts.filter(func(x): return is_instance_valid(x) and x.lie)
	var b_revenue: Array = jeu.elevage.betes.filter(func(x): return bool(x.harnais.get("longe", false)))
	var poses_rev: Array = jeu.atelier.poses.map(func(x): return str(x.genre))
	var inv2: Dictionary = jeu.joueur.inventaire
	verif(int(inv2.get("filin", 0)) == 3 and int(inv2.get("aromates", 0)) == 4 and int(inv2.get("baume_aromates", 0)) == 1 and poses_rev.has("filet_filin")
		and b_revenue.size() == 1 and lie.size() == 1 and absf(float(jeu.botanique.onguent) - 12.0) < 0.2 and absf(float(jeu.botanique.parfum) - 90.0) < 0.2
		and f2 != null and absf(float(jeu.botanique.encens.get(f2, 0.0)) - 50.0) < 0.2,
		"reprise, elle retrouve son filin, ses aromates et leur baume, son grand filet, sa bête à la longe de filin, son pont lié, le baume qui agit encore, la fumée sur son feu et l'odeur sur elle")

	# les sangsues : au marais, l'odeur des aromates les tient ; sans elle, elles mordent
	await jeu._commencer("marais")
	var C2 = jeu.climat
	var T = jeu.terrain
	C2.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	var fon: Dictionary = T.le_plus_proche("fondriere", Vector2(800.0, 800.0))
	var o: Vector2 = fon.get("p", Vector2.ZERO)
	var mordue := func(odeur: bool) -> float:
		_remettre(o)
		jeu.botanique.parfum = RR.PARFUM if odeur else 0.0
		for k in 24:
			T._dangers(0.25, jeu.joueur.position)
		return float(jeu._maux.get("sangsues", 0.0))
	var avec: float = mordue.call(true)
	var sans: float = mordue.call(false)
	verif(not fon.is_empty() and avec == 0.0 and sans > 0.5 and T.enlise > 0.95,
		"au marais, enfoncée dans une fondrière, les sangsues ne mordent pas qui garde l'odeur des aromates ; sans elle, elles mordent (-%.1f)" % sans)


# --- la cueillette nourricière (scripts/flore.gd, objet.gd, flore_dessins.gd ; principal.gd : agir, manger, cuire ; atelier.gd :
# la popote, le mortier ; jardin.gd : les grains semés) : les fruits des arbres, les grains, le lichen des rennes, la pulpe du
# cactus ; ce qu'on en mange, ce que la popote en fait, ce que la partie en garde. Chaque partie se lance à part ---

func _la_cueillette_nourriciere() -> void:
	print("11. La cueillette nourricière")
	await _les_fruits()
	_les_grains()
	_manger_dans_l_ordre()
	await _le_lichen()
	await _la_pulpe()
	await _les_fruits_dans_le_monde()


# ce que l'herbier dirait d'un arbre, d'une plante du sol, de cette forme : un lieu où il ne pousse qu'elle (monde.gd, _poser)
func _ici_rien_que(forme: String, strate: String, genre: String, caracteres: Array = []) -> Dictionary:
	var e := {"id": "essai-" + forme, "poids": 1.0, "taille": 1.0, "port": forme, "forme": forme, "genre": genre, "planche": false,
		"nom": forme, "stade": "feuilles", "defense": [], "caracteres": caracteres, "couleur": null, "fleur": null}
	return {"flore": {strate: [e]}, "climat": {"froid": 0.0, "humide": 0.6}, "palette": jeu.monde.palette}


# une plante de cette forme, posée là, seule (ce qui était à deux pas est ôté) ; un arbre, de ceux qui portent cette année (et
# laissent tomber des fruits à leur pied), à moins que porte ne soit faux
func _poser_seule(forme: String, strate: String, genre: String, p: Vector2, caracteres: Array = [], porte := true):
	var W = jeu.monde
	for x in W.autour(p, 70.0):
		W.retirer(x)
	for b in get_tree().get_nodes_in_group("betes"):
		if b.position.distance_to(p) < 400.0:
			_oter(b)
	var ici := _ici_rien_que(forme, strate, genre, caracteres)
	for k in 400:
		var o = W._poser(strate, p, W.palette["feuilles" if strate == "arbre" else "herbe"], 1000 + k * 7919, ici)
		if o == null:
			continue
		if genre != "arbre" or not porte or (o.fruits_plein > 0 and o.tombes_plein > 0):
			return o
		W._defaire(o)
	return null


# ce que ses fruits (ou ses fleurs) mettent de traits sur sa couronne (scripts/flore_dessins.gd, fruits_couronne)
func _traits_de_fruits(o) -> int:
	var p = load("res://scripts/decor_pinceau.gd").new()
	load("res://scripts/flore_dessins.gd").fruits_couronne(o, p)
	return p.pts.size()


# elle cueille l'arbre jusqu'au dernier fruit, puis frappe une fois : ce qu'elle en a tiré, ses gestes, son dessin, sa repousse
func _un_arbre_cueilli(o) -> Dictionary:
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	var fruit := str(o.fruit)
	j.position = o.position + Vector2(0.0, 2.0)
	var avant := int(inv.get(fruit, 0))
	var a_cueillir: int = int(o.fruits) + int(o.tombes)
	var tombes: int = int(o.tombes)
	var traits0 := _traits_de_fruits(o)
	var gestes := []
	var traits_un := -1
	var reste0: int = int(o.reste)
	for k in a_cueillir:
		jeu.agir()
		gestes.append(str(j._geste))
		if k == tombes:
			traits_un = _traits_de_fruits(o)
	var pris := int(inv.get(fruit, 0)) - avant
	var vide: bool = not o.porte_fruits() and _traits_de_fruits(o) == 0 and int(o.reste) == reste0
	var bois := int(inv["bois"])
	jeu.agir()
	var abat: bool = int(inv["bois"]) == bois + 1 and int(o.reste) == reste0 - 1
	# (il en portera de nouveau : à mi-chemin, des fruits verts, rien à cueillir ; au bout, tout revient)
	var attend: bool = absf(float(o._repousse_fruits) - jeu.R.REPOUSSE_FRUITS) < 0.01
	o._process(jeu.R.REPOUSSE_FRUITS * 0.5)
	var verts: bool = int(o.fruits) == 0 and not o.porte_fruits() and _traits_de_fruits(o) > 0
	o._process(jeu.R.REPOUSSE_FRUITS * 0.55)
	var revenus: bool = int(o.fruits) == int(o.fruits_plein) and int(o.tombes) == int(o.tombes_plein) and o.porte_fruits()
	return {"pris": pris, "attendu": a_cueillir, "gestes": gestes, "tombes": tombes, "dessin": traits0 > 0 and traits_un >= 0 and traits_un < traits0,
		"vide": vide, "abat": abat, "attend": attend, "verts": verts, "revenus": revenus}


# les arbres et leurs fruits : la forêt d'Orvane (ses fruitiers, ses arbres aux fruits charnus) ; le figuier, le palmier, le baobab ;
# les fruits tombés et les bêtes qui viennent les manger ; les saisons ; la partie gardée
func _les_fruits() -> void:
	await jeu._commencer("foret")
	var W = jeu.monde
	var j = jeu.joueur
	var RR = jeu.R
	var Fl := load("res://scripts/flore.gd")
	var Objet := load("res://scripts/objet.gd")
	jeu.climat.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	var fruitiers: Array = W.objets.filter(func(x): return x.genre == "arbre" and str(x.fruit) == "pomme")
	var portent: Array = fruitiers.filter(func(x): return int(x.fruits_plein) > 0)
	var sorbiers: Array = W.objets.filter(func(x): return x.genre == "arbre" and str(x.fruit) == "baies" and int(x.fruits_plein) > 0)
	var bornes: bool = portent.all(func(x): return int(x.fruits_plein) >= 3 and int(x.fruits_plein) <= 5 and int(x.tombes_plein) <= RR.TOMBES)
	var part := float(portent.size()) / maxf(1.0, float(fruitiers.size()))
	# (sept sur dix portent, au tirage de chacun : sur soixante-dix arbres, la part tombe parfois à la moitié)
	verif(fruitiers.size() >= 10 and part > 0.4 and part < 0.95 and bornes and sorbiers.size() >= 5,
		"en forêt, %d fruitiers d'après l'herbier, dont %d %% portent leurs pommes cette année (de 3 à 5, et quelques-unes tombées à leur pied) ; %d arbres aux fruits charnus portent des sorbes" % [
		fruitiers.size(), int(part * 100.0), sorbiers.size()])
	# chaque arbre : ses fruits se dessinent, se cueillent (à terre d'abord, en se baissant ; puis dans les branches, le bras
	# tendu), manquent au dessin ; vide, il s'abat ; il en porte de nouveau en deux jours et demi, verts d'abord
	var arbres := {"pomme": null, "figue": null, "coco": null, "pain_de_singe": null, "baies": null}
	# (des arbres du lieu, loin de ce qu'elle a posé et de ce qui pousse à leur pied)
	var libre := func(x) -> bool:
		return x.position.length() > 300.0 and not jeu.atelier.poses.any(func(y): return is_instance_valid(y) and y.position.distance_to(x.position) < 90.0) \
			and W.autour(x.position, 8.0).filter(func(y): return y != x).is_empty()
	for x in portent:
		if int(x.tombes_plein) > 0 and arbres["pomme"] == null and libre.call(x):
			arbres["pomme"] = x
	for x in sorbiers:
		if int(x.tombes_plein) > 0 and arbres["baies"] == null and libre.call(x):
			arbres["baies"] = x
	arbres["figue"] = _poser_seule("figuier", "arbre", "arbre", Vector2(1400.0, 1300.0))
	arbres["coco"] = _poser_seule("palmier", "arbre", "arbre", Vector2(1550.0, 1300.0))
	arbres["pain_de_singe"] = _poser_seule("bouteille", "arbre", "arbre", Vector2(1700.0, 1300.0))
	for sorte in arbres:
		var o = arbres[sorte]
		if o == null:
			verif(false, "un arbre qui porte « %s », avec des fruits tombés à son pied" % sorte)
			continue
		for b in get_tree().get_nodes_in_group("betes"):
			if b.position.distance_to(o.position) < 300.0:
				_oter(b)
		var d := _un_arbre_cueilli(o)
		var g: Array = d["gestes"]
		var bons_gestes: bool = g.slice(0, int(d["tombes"])).all(func(x): return x == "brindille") and g.slice(int(d["tombes"])).all(func(x): return x == "cueillir")
		verif(int(d["pris"]) == int(d["attendu"]) and int(d["pris"]) > 0 and bons_gestes and bool(d["dessin"]) and bool(d["vide"]) and bool(d["abat"]) and bool(d["attend"])
			and bool(d["verts"]) and bool(d["revenus"]),
			"%s (%s) : %d fruits, %d ramassés à son pied puis cueillis le bras tendu ; chacun manque au dessin ; vide, il s'abat (un bois) ; à mi-chemin des fruits verts, puis il en porte de nouveau" % [
			str(o.forme), sorte, int(d["pris"]), int(d["tombes"])])
		if not bool(d["revenus"]) or not bons_gestes:
			print("    (gestes %s ; %s)" % [str(g), str(d)])
	# les fruits tombés : une bête qui broute vient les manger, la tête dans l'herbe ; qui s'est postée à côté la tient à portée
	var arbre = arbres["pomme"]
	var F: Dictionary = jeu.faune
	# (une proie qui marche à quatre pattes : celles qu'on apprivoise, qui broutent)
	var espece: Dictionary = {}
	for e in F["proies_jour"] + F["proies_nuit"]:
		var b0 = _bete(e, "proie", Vector2(1900.0, -1900.0), {})
		var bonne: bool = jeu.elevage.apprivoisable(b0)
		_oter(b0)
		if bonne:
			espece = e
			break
	if arbre != null and not espece.is_empty():
		arbre.tombes = arbre.tombes_plein
		# (les fruitiers voisins n'ont rien à terre : c'est vers celui-ci qu'elle doit venir, pas vers un autre plus près d'elle)
		for x in jeu.monde.autour(arbre.position, RR.TOMBES_FLAIR + 200.0):
			if x != arbre and str(x.genre) == "arbre" and int(x.tombes) > 0:
				x.tombes = 0
				x._lache = 1.0e9
		j.position = arbre.position + Vector2(-700.0, 0.0)
		# (le sous-bois est serré : elle n'est pas loin, du côté dégagé)
		for x in jeu.monde.autour(arbre.position + Vector2(60.0, 20.0), 50.0):
			if x != arbre:
				jeu.monde.retirer(x)
		var brouteuse = _bete(espece, "proie", arbre.position + Vector2(75.0, 25.0), {})
		# (elle se tient loin, immobile : une bête ne vient pas manger sous les yeux de qui marche)
		j.en_mouvement = false
		var tentee := false
		for k in 80:
			if jeu.tentation(brouteuse) == arbre:
				tentee = true
				break
		brouteuse._tentation_t = 0.0
		var tete := 0.0
		var avant: int = int(arbre.tombes)
		for k in 400:
			brouteuse._conduire(0.1)
			tete = maxf(tete, float(brouteuse.mange))
		var manges: int = avant - int(arbre.tombes)
		if not (tentee and manges >= 1 and tete > 0.6):
			print("    (tentée %s, %d mangés sur %d, la tête %.2f ; elle est à %d pixels de l'arbre, %s)" % [str(tentee), manges, avant, tete, int(brouteuse.position.distance_to(arbre.position)), str(brouteuse.etat)])
		verif(tentee and manges >= 1 and tete > 0.6,
			"une bête qui broute sent les fruits tombés d'un arbre chargé, vient les manger la tête dans l'herbe (%d mangés en quarante secondes) : une proie qu'on sait où attendre" % manges)
		_oter(brouteuse)
	# les saisons : au printemps, il fleurit (des fleurs à la place des fruits, rien à cueillir : « Agir » l'abat) ; l'hiver, rien ;
	# le stade d'Orvane passe avant la saison ; hors ligne, toujours l'été
	var garde: String = Objet.saison
	Objet.saison = "printemps"
	var fleuri = _poser_seule("fruitier", "arbre", "arbre", Vector2(1400.0, 1550.0), [], false)
	Objet.saison = "hiver"
	var nu = _poser_seule("fruitier", "arbre", "arbre", Vector2(1550.0, 1550.0), [], false)
	Objet.saison = garde
	j.position = fleuri.position + Vector2(0.0, 2.0)
	var bois := int(j.inventaire["bois"])
	jeu.agir()
	var abattu: bool = int(j.inventaire["bois"]) == bois + 1
	verif(str(fleuri.maturite) == "fleurs" and int(fleuri.fruits_plein) == 0 and _traits_de_fruits(fleuri) > 0 and abattu and str(nu.maturite) == "" and int(nu.fruits_plein) == 0
		and _traits_de_fruits(nu) == 0 and Fl.maturite("hiver", "fruits") == "murs" and Fl.maturite("été", "dormance") == "" and Fl.maturite("automne", "feuilles") == "murs"
		and jeu.saison == "été" and Fl.maturite(jeu.saison, "feuilles") == "murs",
		"au printemps, le fruitier fleurit (des fleurs dessinées, rien à cueillir : « Agir » l'abat) ; l'hiver, il n'a rien ; un stade « fruits » d'Orvane passe avant la saison ; hors ligne, c'est l'été")
	# la partie gardée : un arbre entamé, un arbre qui repousse, et ce qu'elle a cueilli dans son sac
	# (deux arbres du lieu : un arbre posé par l'essai n'est pas dans le plan du lieu, et la partie reprise ne le ressème pas)
	var entame = null
	var repousse = null
	for x in portent:
		if x == arbres["pomme"] or int(x.fruits_plein) < 3 or int(x.reste) != int(x.plein) or not libre.call(x):
			continue
		if entame == null:
			entame = x
		elif repousse == null and x.position.distance_to(entame.position) > 10.0:
			repousse = x
			break
	if entame == null or repousse == null:
		verif(false, "la partie gardée garde les fruits (un arbre entamé, un arbre qui repousse)")
		return
	entame.fruits = 1
	entame.tombes = 0
	repousse.fruits = 0
	repousse.tombes = 0
	repousse._repousse_fruits = 123.0
	var p_e: Vector2 = entame.position
	var p_r: Vector2 = repousse.position
	j.inventaire["pomme"] = 3
	j.inventaire["figue"] = 2
	var d: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	await jeu._commencer("foret", d)
	var e2 = null
	var r2 = null
	for x in jeu.monde.autour(p_e, 1.0):
		e2 = x
	for x in jeu.monde.autour(p_r, 1.0):
		r2 = x
	verif(e2 != null and r2 != null and int(e2.fruits) == 1 and int(e2.tombes) == 0 and str(r2.fruit) == "pomme" and int(r2.fruits) == 0 and absf(float(r2._repousse_fruits) - 123.0) < 0.2
		and int(jeu.joueur.inventaire.get("pomme", 0)) == 3 and int(jeu.joueur.inventaire.get("figue", 0)) == 2,
		"la partie gardée retient les fruits : un pommier entamé n'en a plus qu'un, un autre, vidé, repousse encore (%d s) ; et les fruits du sac" % int(r2._repousse_fruits if r2 != null else -1))


# les grains : la céréale et le riz sauvage, leurs épis puis leur paille ; crus, à peine ; le gruau ; semés, une récolte
func _les_grains() -> void:
	var W = jeu.monde
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	var RR = jeu.R
	var A = jeu.atelier
	var J = jeu.jardin
	var cereale = _poser_seule("cereale", "sol", "touffe", Vector2(-1500.0, 1400.0))
	var riz = _poser_seule("riz", "sol", "touffe", Vector2(-1400.0, 1400.0))
	if cereale == null or riz == null:
		verif(false, "une céréale, un riz sauvage")
		return
	for k in ["grains", "fibre"]:
		inv[k] = 0
	j.position = cereale.position + Vector2(0.0, 2.0)
	var murs: bool = bool(cereale.epis_murs) and bool(riz.epis_murs)
	jeu.agir()
	var epis := int(inv["grains"])
	jeu.agir()
	var paille := int(inv["fibre"])
	var cueillie: bool = cereale.epuise() and float(cereale._repousse) > 0.0 and int(inv["grains"]) == epis
	j.position = riz.position + Vector2(0.0, 2.0)
	jeu.agir()
	verif(murs and epis == RR.GRAINS_PAR_EPI and paille == 1 and cueillie and int(inv["grains"]) == 2 * RR.GRAINS_PAR_EPI,
		"la céréale mûre : ses épis d'abord (+%d grains), sa paille ensuite (une fibre), puis elle repousse ; le riz sauvage aussi" % epis)
	# crus : à peine
	for k in ["baies", "viande", "viande_cuite", "bouillon", "champignons", "amanite", "gruau", "soupe_lichen", "pomme", "figue", "coco", "pain_de_singe", "pulpe", "lichen"]:
		inv[k] = 0
	inv["grains"] = 1
	j.faim = 40.0
	j.temperature = 50.0
	jeu.manger()
	var crus: float = j.faim - 40.0
	# le gruau : trois grains, une gorgée d'eau, à la popote sur un feu (« Cuire », sans viande)
	inv["grains"] = RR.GRUAU_GRAINS
	inv["eau"] = 1
	var popote := int(A.objets.get("popote", 0))
	A.objets.erase("popote")
	inv["bois"] = int(inv["bois"]) + 4
	inv["pierre"] = int(inv["pierre"]) + 2
	jeu.fabriquer("feu")
	var sans_popote: String = A.empeche_cuire("gruau")
	A.objets["popote"] = 1
	jeu.cuire()
	var cuit: bool = int(inv.get("gruau", 0)) == 1 and int(inv["grains"]) == 0 and int(inv["eau"]) == 0
	j.faim = 40.0
	j.temperature = 40.0
	jeu.manger()
	verif(absf(crus - RR.GRAINS_CRUS) < 0.01 and sans_popote.contains("popote") and cuit and absf(j.faim - 40.0 - RR.GRUAU) < 0.01 and j.temperature > 40.0 + RR.GRUAU_CHAUD - 0.5,
		"crus, des grains nourrissent à peine (+%d) ; %d grains et une gorgée d'eau, à la popote sur un feu (C) : un gruau, +%d à la faim, et il réchauffe" % [int(crus), RR.GRUAU_GRAINS, int(RR.GRUAU)])
	if popote <= 0:
		A.objets.erase("popote")
	# semés : un carré de grains, qui pousse, mûrit, et rend de quoi manger et semer encore (et sa paille)
	inv["grains"] = J.GRAINES
	for k in ["graine_baie", "graine_lin", "graine_simple"]:
		inv[k] = 0
	var defaut_seul: String = J.culture_par_defaut()
	inv["graine_lin"] = 2
	var defaut_lin: String = J.culture_par_defaut()
	inv["graine_lin"] = 0
	var carre = A._creer("carre", Vector2(-1500.0, 1650.0), {"culture": "", "stade": 0.0, "eau": 1.0})
	var seme: bool = J.semer(carre, "grain")
	for k in 60:
		carre.etat["eau"] = 1.0
		J.maj(10.0)
	var mur: bool = J.mur(carre)
	var fibre := int(inv["fibre"])
	var recolte: bool = J.recolter(carre)
	var rend := int(inv["grains"])
	verif(defaut_seul == "grain" and defaut_lin == "lin" and seme and mur and recolte and rend == int(J.CULTURES["grain"]["donne"]["grains"]) + J.RENDUES
		and int(inv["fibre"]) == fibre + int(J.CULTURES["grain"]["donne"]["fibre"]) and str(carre.etat["culture"]) == "",
		"semés dans un carré (deux grains ; on ne les sème d'office que faute d'autres graines), ils mûrissent en un jour et demi, la terre humide : +%d grains (de quoi semer encore) et leur paille" % rend)
	A.poses.erase(carre)
	carre.queue_free()


# « Manger » prend le meilleur d'abord, et ce qui fait mal en dernier ; accablée de chaleur, ce qui rafraîchit d'abord. Chaque
# chose a son icône, son nom, ce qu'on en dit
func _manger_dans_l_ordre() -> void:
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	var ordre: Array = jeu.A_MANGER
	for k in ordre:
		inv[k] = 1
	j.temperature = 50.0
	var mange := []
	for i in ordre.size():
		var avant := inv.duplicate()
		j.faim = 10.0
		jeu.manger()
		for k in ordre:
			if int(inv[k]) < int(avant[k]):
				mange.append(k)
	jeu.botanique.poison = 0.0
	inv["baies"] = 1
	inv["pulpe"] = 1
	j.temperature = 76.0
	jeu.manger()
	var frais: bool = int(inv["pulpe"]) == 0 and int(inv["baies"]) == 1 and j.temperature <= 76.0 - jeu.R.PULPE_FRAIS + 0.01 and jeu.fraicheur > 0.0
	inv["baies"] = 0
	jeu.fraicheur = 0.0
	j.temperature = 50.0
	j.sante = 100.0
	j.peur = 0.0
	var Icones := load("res://scripts/atelier_icones.gd")
	var nouveaux := ["pomme", "figue", "coco", "pain_de_singe", "grains", "lichen", "pulpe", "gruau", "soupe_lichen"]
	var dits: bool = nouveaux.all(func(k): return Icones.connue(k) and load("res://scripts/interface_atelier.gd").NOMS_COURTS.has(k)) \
		and ["pomme", "figue", "coco", "pain_de_singe", "grains", "lichen", "pulpe"].all(func(k): return jeu.CUEILLETTE.has(k))
	verif(mange == ordre and frais and dits,
		"« Manger » prend le meilleur d'abord (le bouillon, le gruau, la viande cuite, la soupe de lichen, les fruits, les baies…) et ce qui fait mal en dernier (le lichen cru, la viande crue, l'amanite) ; accablée de chaleur, la pulpe d'abord ; chaque chose a son icône et son nom")
	if mange != ordre:
		print("    (mangé dans cet ordre : %s)" % str(mange))


# le lichen des rennes : cru, amer ; bouilli, une soupe ; et la banquise se tient, trois jours, de soupe de lichen, d'eau prise
# sous la glace et d'un feu
func _le_lichen() -> void:
	await jeu._commencer("banquise")
	var W = jeu.monde
	var T = jeu.terrain
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	var RR = jeu.R
	var A = jeu.atelier
	jeu.climat.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	var mare: Dictionary = T.le_plus_proche("mare", Vector2.ZERO)
	if mare.is_empty():
		verif(false, "la banquise a ses mares gelées")
		return
	var camp: Vector2 = Vector2(mare["p"]) + Vector2(0.0, 60.0)
	_remettre(camp)
	var tous: Array = W.objets.filter(func(x): return str(x.forme) == "lichen_rennes")
	# (ceux qu'on cueille sans qu'une chose du pays soit à portée de main : sinon « Agir » prendrait celle-là)
	var debout := func(q: Vector2) -> bool:
		return T._autour(q, 130.0).any(func(t): return str(t["genre"]) in T.DEBOUT or str(t["genre"]) == "mare")
	var libres: Array = tous.filter(func(x): return not debout.call(x.position))
	libres.sort_custom(func(a, b): return a.position.distance_to(camp) < b.position.distance_to(camp))
	var cueillir := func(o) -> int:
		var n := 0
		j.position = o.position + Vector2(0.0, 2.0)
		for k in 2:
			var avant := int(inv.get("lichen", 0))
			jeu.agir()
			n += int(inv.get("lichen", 0)) - avant
		return n
	for k in ["baies", "viande", "viande_cuite", "bouillon", "champignons", "amanite", "gruau", "soupe_lichen", "pomme", "figue", "coco", "pain_de_singe", "pulpe", "grains"]:
		inv[k] = 0
	inv["lichen"] = 0
	var premier: int = cueillir.call(libres[0]) if not libres.is_empty() else 0
	var epuise: bool = not libres.is_empty() and libres[0].epuise()
	_remettre(camp)
	inv["lichen"] = 1
	j.faim = 40.0
	jeu.manger()
	var cru: float = j.faim - 40.0
	var peur: float = j.peur
	verif(tous.size() >= 20 and premier == 2 and epuise and absf(cru - RR.LICHEN_CRU) < 0.01 and peur >= RR.LICHEN_CRU_PEUR - 0.01,
		"la banquise a son lichen des rennes (%d touffes) : deux poignées chacune ; cru, il nourrit à peine (+%d) et noue le ventre (la peur monte)" % [tous.size(), int(cru)])
	# trois jours à la banquise : chaque jour, elle cueille le lichen proche du camp (il repousse en un jour), puise sous la glace,
	# fait ses soupes au feu, et mange quand la faim vient. Elle n'a rien d'autre
	A.objets["gourde"] = 1
	A.objets["popote"] = 1
	var f = jeu.Feu.new()
	f.jeu = jeu
	f.position = camp + Vector2(30.0, 0.0)
	jeu.monde.add_child(f)
	jeu.feux.append(f)
	var proches: Array = libres.slice(1, 13)
	j.faim = 80.0
	var faim_min := 100.0
	var soupes := 0
	var cuites := 0
	for jour_ in 3:
		f.bois = RR.FEU_MAX
		for o in proches:
			if not o.epuise():
				cueillir.call(o)
		while int(inv["lichen"]) >= RR.SOUPE_LICHENS:
			j.position = Vector2(mare["p"]) + Vector2(0.0, 6.0)
			jeu.agir()
			j.position = camp
			var avant := int(inv.get("soupe_lichen", 0))
			jeu.cuire()
			if int(inv.get("soupe_lichen", 0)) <= avant:
				break
			cuites += 1
		# (le jour passe : la faim baisse ; elle mange une soupe quand elle a faim)
		for k in int(RR.DUREE / 10.0):
			j.faim = maxf(0.0, j.faim - RR.FAIM * 10.0)
			if j.faim < 55.0 and int(inv.get("soupe_lichen", 0)) > 0:
				jeu.manger()
				soupes += 1
			faim_min = minf(faim_min, j.faim)
		# (la nuit, le lichen repousse)
		for o in proches:
			o._process(load("res://scripts/objet.gd").REPOUSSE + 1.0)
	var besoin := ceilf(RR.FAIM * RR.DUREE / RR.SOUPE_LICHEN)
	var loin: float = proches.back().position.distance_to(camp) if not proches.is_empty() else 0.0
	verif(proches.size() >= 8 and faim_min > RR.FAIM_MORD and soupes >= 6 and j.temperature >= 40.0,
		"la banquise se tient de lichen : trois jours de soupes (%d cuites, %d mangées ; il en faut %d par jour) du lichen de %d touffes autour du camp (la plus loin à %d pixels), l'eau prise sous la glace, un feu ; la faim n'est jamais descendue sous %d" % [
		cuites, soupes, int(besoin), proches.size(), int(loin), int(faim_min)])
	f.queue_free()
	jeu.feux.erase(f)


# la pulpe du cactus : elle pique ; mangée, elle rafraîchit (au désert, en plein jour, la chaleur ne tue plus) ; pressée au
# mortier, elle remplit la gourde
func _la_pulpe() -> void:
	await jeu._commencer("desert")
	var W = jeu.monde
	var j = jeu.joueur
	var inv: Dictionary = j.inventaire
	var RR = jeu.R
	var A = jeu.atelier
	var C = jeu.climat
	C.forcer("clair", 0.0, 9999.0)
	_a_l_heure(false)
	# (loin de ce que le pays a de debout, que « Agir » prendrait d'abord : une carcasse)
	var debout := func(q: Vector2) -> bool:
		return jeu.terrain._autour(q, 130.0).any(func(t): return str(t["genre"]) in jeu.terrain.DEBOUT or str(t["genre"]) == "mare")
	var cactus: Array = W.objets.filter(func(x): return str(x.forme) == "cactus" and not debout.call(x.position))
	var c = cactus[0] if not cactus.is_empty() else null
	if c == null:
		verif(false, "le désert a ses cactus")
		return
	inv["pulpe"] = 0
	_remettre(c.position + Vector2(0.0, 2.0))
	jeu.agir()
	var pique: float = 100.0 - j.sante
	var une := int(inv["pulpe"])
	A.portes["vetement_chaud"] = true
	j.sante = 100.0
	jeu.agir()
	var gardee: float = 100.0 - j.sante
	A.portes.erase("vetement_chaud")
	var tous: int = W.objets.filter(func(x): return str(x.forme) == "cactus").size()
	verif(tous >= 15 and une == 1 and int(inv["pulpe"]) == 2 and absf(pique - RR.EPINES) < 0.01 and gardee < 0.01 and c.epuise(),
		"le désert a ses cactus (%d) : d'un bras coupé, sa pulpe ; il pique les mains nues (-%d), la pelisse les garde" % [tous, int(pique)])
	# au désert, en plein jour : sans rien, le corps passe la chaleur qui tue ; une pulpe mangée, il reste en deçà
	var ici: Vector2 = c.position + Vector2(-200.0, 120.0)
	for k in 40:
		var q := Vector2(-1500.0 + 70.0 * k, 1100.0)
		if C.abri(q) == 0.0 and W.autour(q, 120.0).filter(func(x): return x.couvert() > 0.0).is_empty():
			ici = q
			break
	_remettre(ici)
	jeu.fraicheur = 0.0
	var sans := _tenir_au_climat(40.0)
	_remettre(ici)
	inv["pulpe"] = 1
	jeu.manger()
	var avec := _tenir_au_climat(40.0)
	verif(float(sans[0]) > RR.CHAUD and float(avec[0]) < RR.CHAUD and float(avec[0]) < float(sans[0]) - 6.0,
		"en plein jour au désert, le corps monte à %d (la chaleur tue) ; une pulpe de cactus mangée, il reste à %d : la chaleur pèse moins, trois quarts de minute" % [int(sans[0]), int(avec[0])])
	# pressée au mortier : de l'eau dans la gourde (deux pulpes, une gorgée) ; l'eau du désert, sans pluie
	inv["pulpe"] = RR.PULPES_GORGEE
	inv["eau"] = 0
	var mortier := int(A.objets.get("mortier", 0))
	var gourde := int(A.objets.get("gourde", 0))
	A.objets.erase("mortier")
	A.objets["gourde"] = 1
	var sans_mortier: String = A.empeche_presser()
	A.objets["mortier"] = 1
	var presse: bool = A.presser()
	verif(sans_mortier.contains("mortier") and presse and int(inv["eau"]) == 1 and int(inv["pulpe"]) == 0,
		"pressées au mortier, %d pulpes de cactus remplissent la gourde d'une gorgée : l'eau des recettes, au désert, sans pluie" % RR.PULPES_GORGEE)
	if mortier <= 0:
		A.objets.erase("mortier")
	if gourde <= 0:
		A.objets.erase("gourde")
	jeu.fraicheur = 0.0


# le monde ouvert : un arbre cueilli le reste, même loin, et il en porte de nouveau pendant qu'on est ailleurs
func _les_fruits_dans_le_monde() -> void:
	await jeu._commencer("prairie", {}, true)
	var W = jeu.monde
	var j = jeu.joueur
	var arbre = null
	for x in W.objets:
		if x.genre == "arbre" and int(x.fruits_plein) >= 3 and int(x.tombes_plein) == 0 and x.has_meta("rang") and x.position.length() > 300.0:
			if W.autour(x.position, 6.0).filter(func(y): return y != x and not y.epuise()).is_empty():
				arbre = x
				break
	if arbre == null:
		verif(false, "le monde ouvert a des arbres qui portent des fruits, autour du réveil")
		return
	var p: Vector2 = arbre.position
	var plein: int = int(arbre.fruits_plein)
	j.position = p + Vector2(0.0, 2.0)
	for b in get_tree().get_nodes_in_group("betes"):
		if b.position.distance_to(p) < 300.0:
			_oter(b)
	jeu.agir()
	var loin := p + Vector2(9000.0, 0.0)
	j.position = loin
	W.suivre(loin, true)
	var parti: bool = W.autour(p, 1.0).is_empty()
	j.position = p + Vector2(0.0, 2.0)
	W.suivre(p, true)
	var a2 = W.autour(p, 1.0)[0] if not W.autour(p, 1.0).is_empty() else null
	var reste_un: bool = a2 != null and int(a2.fruits) == plein - 1
	var restaient: int = int(a2.fruits) if a2 != null else -1
	# (vidé, puis loin plus longtemps que sa repousse : il en porte de nouveau)
	for k in plein - 1:
		jeu.agir()
	var vide: bool = a2 != null and not a2.porte_fruits() and float(a2._repousse_fruits) > 0.0
	j.position = loin
	W.suivre(loin, true)
	jeu.horloge += jeu.R.REPOUSSE_FRUITS + 5.0
	j.position = p + Vector2(0.0, 2.0)
	W.suivre(p, true)
	var a3 = W.autour(p, 1.0)[0] if not W.autour(p, 1.0).is_empty() else null
	verif(parti and reste_un and vide and a3 != null and int(a3.fruits) == plein and a3.intact(),
		"le monde ouvert : un arbre entamé l'est toujours, loin puis de retour (%d fruits sur %d) ; vidé, il en porte de nouveau quand on revient deux jours et demi plus tard" % [
		restaient, plein])
	j.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
