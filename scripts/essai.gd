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
		if C.eau(q2) > 0.9 and C.eau(q2 + Vector2(30, 0)) > 0.9 and C.eau(q2 + Vector2(34, 4)) > 0.9 and jeu.monde.repousser(q2, 8.0).distance_to(q2) < 1.0:
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
	_la_noire(F)
	_le_pistage(F)

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


# un chasseur devant un feu où la veilleuse se tient, tant de secondes : au plus près et en moyenne (en parts du rayon), le
# chemin qu'il fait autour (en radians), la seconde moitié du temps ; et la bête, encore là (à ôter)
func _siege(e: Dictionary, memoire: Dictionary, feu, secondes: float) -> Dictionary:
	var b = _bete(e, "chasseur", feu.position + Vector2(feu.rayon() + 260.0, 40.0), memoire)
	var r: float = feu.rayon()
	var pres := INF
	var somme := 0.0
	var tours := 0.0
	var k := 0
	var avant := 0.0
	var pas := int(secondes / 0.05)
	for i in pas:
		b._conduire(0.05)
		var ici: Vector2 = b.position - feu.position
		pres = minf(pres, ici.length() / r)
		if i >= pas / 2:
			if k > 0:
				tours += absf(wrapf(ici.angle() - avant, -PI, PI))
			avant = ici.angle()
			somme += ici.length() / r
			k += 1
	return {"pres": pres, "moyenne": somme / maxf(k, 1), "tours": tours, "bete": b}


# un chasseur d'audace 0,5 dans le noir, face à la torche, tant de secondes : au plus près (pixels), où il se tient la seconde
# moitié du temps, quand il s'annonce, quand il mord (-1 : jamais), ses morsures ; et la bête
func _face_a_la_torche(e: Dictionary, memoire: Dictionary, secondes: float) -> Dictionary:
	var j = jeu.joueur
	j.torche = 75.0
	j.sante = 100.0
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
		"voltes": voltes, "va_et_vient": va_et_vient}


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
	verif(s0["pres"] >= 0.78 and st["pres"] >= 0.78 and sa["pres"] >= 0.78 and st["tours"] > s0["tours"] * 1.2,
		"le feu reste une loi : traqueur ou fait au feu, aucun chasseur n'entre dans sa lumière (au plus près : %.2f, %.2f et %.2f du rayon, sans mémoire, traqueur, accoutumé) ; le traqueur arpente la lisière plus vite (%.1f radians en vingt secondes, contre %.1f)" % [
			s0["pres"], st["pres"], sa["pres"], st["tours"], s0["tours"]])
	# une bûche : celui qui craint le feu recule, pas l'autre
	j.inventaire["bois"] = int(j.inventaire["bois"]) + 1
	jeu.nourrir_feu()
	verif(sp["moyenne"] > s0["moyenne"] + 0.15 and sc["moyenne"] > s0["moyenne"] + 0.08 and sp["bete"].etat == "fuit" and s0["bete"].etat != "fuit",
		"une population qui craint le feu se tient à %.2f du rayon (contre %.2f ; %.2f pour une population craintive), hors de sa lumière ; et une bûche la fait reculer" % [
			sp["moyenne"], s0["moyenne"], sc["moyenne"]])
	var tenus: float = _compte(str(ch_e["id"]), "effarouchement", "feu")
	for x in [s0, st, sa, sp, sc]:
		_oter(x["bete"])

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
	verif(t0["va_et_vient"] <= 2 and t0["voltes"] <= 6 and ta["va_et_vient"] <= 2 and ta["voltes"] <= 6 and tp["va_et_vient"] <= 2 and tp["voltes"] <= 6,
		"tenu par la torche, il longe la lisière de sa lumière sans aller et venir : en sept secondes, %d volte-face et %d va-et-vient (fait au feu : %d et %d ; qui le craint : %d et %d)" % [
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
	verif(faim_basse > 0.8 and faim_moyenne <= 0.0 and faim_vide > faim_basse and 100.0 / RR.FAMINE < 60.0 and 100.0 / RR.FAIM < RR.DUREE * 1.5,
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
	# les baies : peu de buissons, deux poignées chacun, qui repoussent lentement
	var buissons: Array = jeu.monde.objets.filter(func(x): return x.genre == "buisson")
	var un = null
	for x in buissons:
		if x.intact():
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

	# acte 1 : les signes
	jeu.nuits = 0
	jeu.horloge = nuit_h
	jeu.feux.append(feu)
	var journal_avant = jeu.sons.journal
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
	jeu.nuits = 1
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
	jeu.nuits = 2
	N.mettre_en_scene(3, 900.0, PI)
	var s3 := {"pres_feu": INF, "tour": 0.0, "avant": NAN}
	_noire_joue(34.0, func(_t):
		if N.corps == null:
			return
		var q: Vector2 = N.corps.position - feu.position
		s3["pres_feu"] = minf(s3["pres_feu"], q.length() / r)
		if (N.etat == "tourne" or N.etat == "guette") and not is_nan(s3["avant"]):
			s3["tour"] += absf(wrapf(q.angle() - float(s3["avant"]), -PI, PI))
		s3["avant"] = q.angle())
	verif(N.acte == 3 and s3["pres_feu"] >= 0.97 and s3["tour"] > 0.5 and j.sante == 100.0 and N.su.has("feu"),
		"acte 3, le siège : un feu vif la tient (au plus près, %.2f rayon), elle tourne autour (%.1f radians) sans mordre" % [s3["pres_feu"], s3["tour"]])
	# (hors de la lumière, la torche à la main : elle la tient un moment, puis le présage, puis la charge et la morsure)
	j.position = feu.position + Vector2(r + 420.0, 0.0)
	j.torche = 200.0
	var t3 := {"presage": -1.0, "charge": -1.0, "morsure": -1.0, "recule": false, "prise": 0.0}
	_noire_joue(RR.NOIRE_TORCHE[3] + 22.0, func(t):
		if N.corps == null:
			return
		if t3["presage"] < 0.0 and N.corps.aplatie > 0.5:
			t3["presage"] = t
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
		jeu.nuits = 1
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

