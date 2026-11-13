extends Node
# Lisière — l'essai sans écran (scripts/essai.gd)
# Une partie jouée toute seule, en accéléré, sur la copie du monde gardée dans le jeu (sans réseau), qui vérifie que tout tient :
# le lieu, ses bêtes dessinées d'après leurs planches, la récolte, les fabrications, le jeu du doigt, la nuit, les chasseurs qui n'entrent pas
# dans la lumière du feu, la peur dans le noir, les échos, l'aube, la fin, et ce qui est compté pour Orvane.
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
	# (un arbre sans rien d'autre à prendre à son pied : les trois coups sont pour lui)
	var o = null
	for x in jeu.monde.objets:
		if (x.genre == "arbre" or x.genre == "sapin") and jeu.monde.autour(x.position + Vector2(0, 20), 70.0).filter(func(y): return y != x and not y.epuise()).is_empty():
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
	jeu.fabriquer("lance")
	verif(jeu.feux.size() == 1 and j.lance == 30 and int(j.inventaire["bois"]) == 24, "un feu de camp et une lance, payés en bois, pierres et fibres")
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
		if C.eau(q2) > 0.9 and C.eau(q2 + Vector2(30, 0)) > 0.9 and jeu.monde.repousser(q2, 8.0).distance_to(q2) < 1.0:
			creux = q2
			break
	j.position = creux
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
	var plus := 1
	var essouffle := 1.0
	for k in 8:
		I.avancer(2.1)
		plus = maxi(plus, I.foyers.size())
		for foyer in I.foyers:
			essouffle = minf(essouffle, foyer.force)
	C.forcer("pluie", 1.0, 9999.0)
	for k in 240:
		I.avancer(0.5)
	var brules: int = jeu.monde.objets.filter(func(x): return x.calcine).size()
	verif(voisins_max >= 1 and plus > 1 and plus <= RR.INCENDIE_MAX and I.foyers.is_empty(),
		"par temps sec l'incendie gagne les voisins (jusqu'à %d objets en feu, %d au plus permis) ; la pluie l'éteint (%d objets calcinés)" % [plus, RR.INCENDIE_MAX, brules])
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

	# (la partie telle qu'elle est, avant l'aube, un arbre abattu en plus : elle sera reprise à la fin, et doit revenir pareille)
	for x in jeu.monde.objets:
		if (x.genre == "arbre" or x.genre == "sapin") and x.reste == x.plein:
			for k in x.plein:
				x.recolter()
			break
	jeu.climat.boue = 0.4
	jeu.joueur.trempe = 30.0
	jeu.joueur.temperature = 41.0
	var gardee: Dictionary = load("res://scripts/partie_gardee.gd").photo(jeu)
	jeu.climat.boue = 0.0
	jeu.joueur.trempe = 0.0
	jeu.joueur.temperature = 50.0

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
	verif(not FileAccess.file_exists("user://partie.json") or PG.lire() == lu, "l'essai ne réécrit pas la partie gardée")
	PG.effacer()
	jeu.ui.montrer_reprise({})
	verif(not jeu.ui._reprise.visible and jeu.ui._entrer.principal, "effacée, l'écran-titre ne propose plus que d'entrer dans la nuit")
	await _lieu_sans_bord()
	print("\n%s (%d vérifications)" % ["tout passe" if ok else "ÉCHEC", n])
	# (des sons qui jouent encore quand Godot s'arrête, il dit qu'ils fuient : on les arrête, et l'on laisse au serveur audio
	# le temps de les lâcher)
	jeu.sons.arreter_brefs()
	for p in jeu.sons.find_children("*", "AudioStreamPlayer", false, false):
		p.stop()
	_fini = true
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit(0 if ok else 1)


# le lieu sans bord, à part : ses noms ne se mêlent pas à ceux de la partie d'avant
func _lieu_sans_bord() -> void:
	var PG := load("res://scripts/partie_gardee.gd")
	print("8. Le lieu sans bord")
	# (MONDE-OUVERT.md, étape 2 : le lieu se fabrique par morceaux autour de la veilleuse, et ne garde que ce qu'on y change)
	var propose: Array = jeu._lieux_du_titre()
	var rang_foret := -1
	var rang_ouvert := -1
	for i in propose.size():
		if str(propose[i]["id"]) == "foret":
			rang_foret = i
		elif str(propose[i]["id"]) == "ouvert:monde":
			rang_ouvert = i
	verif(rang_ouvert == rang_foret + 1 and rang_foret >= 0 and propose.size() == jeu.donnees.lieux().size() + 1,
		"l'écran-titre propose « %s » (%s) juste après la forêt, sur laquelle la liste s'ouvre" % [propose[rang_ouvert]["nom"], propose[rang_ouvert]["detail"]])
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
	jeu.ui.montrer_pause(true)
	var page_carte: bool = jeu.ui._pause.carte_monde.visible and not jeu.ui._pause._commandes.visible and str(jeu.ui._pause._sous.text).contains("découverte")
	jeu.ui.montrer_pause(false)
	var gardee_d: Dictionary = JSON.parse_string(JSON.stringify(load("res://scripts/partie_gardee.gd").photo(jeu)))
	verif(jeu.decouvertes.has(foret) and jeu.decouvertes.size() >= 2 and absf(aire_) * 0.5 > 0.3 * C.cote * C.cote and absf(aire_) * 0.5 < 3.0 * C.cote * C.cote
		and page_carte and gardee_d["decouvertes"].has(str(C.regions[foret]["id"])),
		"ce qu'on découvre se note (%d régions) et se garde ; à la pause, le carnet en montre la carte (« %s »)" % [jeu.decouvertes.size(), jeu.ui._pause._sous.text])
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
	# un col : on y monte à pied, lentement
	var e_c: Array = C._paroi(p_col)
	var monte_c: Vector2 = e_c[1]
	var bas_c: Vector2 = p_col - monte_c * (C.PAROI + 14.0)
	var arrivee := _marcher(bas_c, monte_c, 80)
	verif(C.retenir(p_col) == p_col and C.col_en(p_col) and jeu.climat.allure(p_col) < 0.8 and jeu.climat.allure(bas_c) > 0.99 and C.palier(arrivee) == C.palier(bas_c) + 1,
		"un col est une rampe dans la paroi : on y monte à pied, plus lentement (%.2f), d'un étage au suivant" % jeu.climat.allure(p_col))
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
	jeu.sous_terre = 0.0
	jeu.climat.toit = 0.0
	jeu.climat.forcer("clair", 1.0, 600.0)
	jeu.climat.boue = 0.0
	jeu.climat.crue = 0.0
	jo.position = Vector2.ZERO
	W.suivre(Vector2.ZERO, true)
	jeu._regions()


# marcher droit devant soi, à petits pas que la carte retient : où l'on arrive
func _marcher(de: Vector2, vers: Vector2, pas: int) -> Vector2:
	var p := de
	for i in pas:
		p = jeu.carte.retenir(p + vers.normalized() * 1.5)
	return p

