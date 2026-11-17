extends Node
# Lisière — le compte (scripts/session.gd)
# Le même compte que Stone Valley : le même Supabase (le projet « Vallée de pierre », sa clé publique), la même porte. Une adresse
# et un mot de passe ; l'adresse se confirme par le courriel de Supabase ; un mot de passe oublié se change par un lien. Tout
# passe par Supabase Auth (/auth/v1) : le jeu n'envoie l'adresse et le mot de passe qu'à lui, et ne garde que la session (le jeton,
# celui qui le renouvelle, l'adresse), dans user://session.json. Le jeton ne vaut qu'une heure : il se renouvelle une minute avant.
# Dans un navigateur, la session est celle du portail et des autres jeux du site (même adresse, même stockage, sous la clé
# « stonevalley:session ») : connecté au portail, on l'est ici en arrivant, et l'inverse ; se déconnecter déconnecte partout. Un
# jeton de renouvellement ne sert qu'une fois : avant de renouveler, on regarde si un autre ne vient pas de le faire.
# Sans compte, Lisière se joue pareil. Connecté, la partie en cours est aussi gardée sur le compte (plus bas : la partie sur le
# compte), et le portail montre où l'on en est.
#   var r = await jeu.session.connexion(adresse, mot_de_passe)     # { ok, erreur } ; puis jeu.session.connecte()

signal change           # connecté, ou plus
signal partie_en_conflit    # un autre appareil a continué la partie du compte : celle-ci n'y part plus

const URL := "https://ldazucyrnpewkqdneznc.supabase.co"
# (publique par nature, celle de Stone Valley : sans compte connecté, elle n'ouvre rien)
const CLE := "sb_publishable_qUrfgAsAUzc3jd_tiqkY9g_EVkkQRAs"
const FICHIER := "user://session.json"
const COMMUNE := "stonevalley:session"      # dans un navigateur : la session commune au portail et aux jeux
const ADRESSE_DU_JEU := "https://stonevalleyoff-ai.github.io/Lisiere/"
const MDP_MIN := 8
# les messages de Supabase sont en anglais : on les dit
const DITS := [
	["invalid login credentials", "adresse ou mot de passe incorrect"],
	["email not confirmed", "adresse pas encore confirmée : ouvre le courriel reçu"],
	["already registered", "cette adresse a déjà un compte"],
	["already been registered", "cette adresse a déjà un compte"],
	["password should be at least", "mot de passe trop court : %d caractères au moins" % MDP_MIN],
	["unable to validate email", "adresse e-mail invalide"],
	["invalid format", "adresse e-mail invalide"],
	["for security purposes", "trop d'essais : patiente une minute"],
	["rate limit", "trop d'essais : patiente une minute"],
	["too many", "trop d'essais : patiente une minute"],
	["same_password", "c'est déjà ton mot de passe"],
	["should be different", "c'est déjà ton mot de passe"],
]

var jeton := ""
var renouveau := ""         # le jeton qui renouvelle la session (refresh_token)
var expire := 0.0           # quand le jeton cesse de valoir (secondes, horloge du système)
var uid := ""
var email := ""
# (l'essai joue contre un faux service : LISIERE_SERVICE, hors d'un navigateur seulement)
var url := URL
# revenu d'un lien « mot de passe oublié » : la porte s'ouvre pour en choisir un nouveau
var nouveau_mdp := false
var _renouvellement := false


func _ready() -> void:
	if not OS.has_feature("web") and OS.get_environment("LISIERE_SERVICE") != "":
		url = OS.get_environment("LISIERE_SERVICE").trim_suffix("/")
	_lire()
	if OS.has_feature("web"):
		await _retour_du_courriel()
	if connecte() and Time.get_unix_time_from_system() > expire - 60.0:
		await jeton_valide()


func connecte() -> bool:
	return jeton != "" and uid != ""


# --- ce que la porte demande ---

func connexion(adresse: String, mdp: String) -> Dictionary:
	var r := await _appeler("/token?grant_type=password", {"email": adresse, "password": mdp})
	if r["ok"]:
		_prendre(r["donnees"])
	return r


# un compte neuf. Supabase exige ici une adresse confirmée : il ne rend pas de session, il envoie un courriel (r.entre = false)
func inscription(adresse: String, mdp: String) -> Dictionary:
	var r := await _appeler("/signup", {"email": adresse, "password": mdp, "options": {"email_redirect_to": _retour()}})
	r["entre"] = false
	if r["ok"] and typeof(r["donnees"]) == TYPE_DICTIONARY and r["donnees"].has("access_token"):
		_prendre(r["donnees"])
		r["entre"] = true
	return r


func oubli(adresse: String) -> Dictionary:
	return await _appeler("/recover", {"email": adresse, "redirect_to": _retour()})


func changer_mdp(mdp: String) -> Dictionary:
	await jeton_valide()
	var r := await _appeler("/user", {"password": mdp}, HTTPClient.METHOD_PUT, true)
	if r["ok"]:
		nouveau_mdp = false
		var u = r["donnees"]
		if typeof(u) == TYPE_DICTIONARY:
			uid = str(u.get("id", uid))
			email = str(u.get("email", email))
			_ecrire()
	return r


func deconnexion() -> void:
	var j := jeton
	jeton = ""
	renouveau = ""
	expire = 0.0
	uid = ""
	email = ""
	nouveau_mdp = false
	_ecrire()
	change.emit()
	if j != "":
		# (la session se ferme aussi chez Supabase ; si le réseau manque, elle mourra seule)
		_appeler("/logout", {}, HTTPClient.METHOD_POST, true, j)


# le jeton, renouvelé s'il le faut (une minute avant la fin) ; "" si la session est perdue
func jeton_valide() -> String:
	if not connecte():
		return ""
	if Time.get_unix_time_from_system() < expire - 60.0 or renouveau == "":
		return jeton
	if _renouvellement:
		while _renouvellement:
			await get_tree().process_frame
		return jeton
	if _renouvelee_ailleurs():
		return jeton
	_renouvellement = true
	var r := await _appeler("/token?grant_type=refresh_token", {"refresh_token": renouveau})
	_renouvellement = false
	if r["ok"]:
		_prendre(r["donnees"])
	elif (int(r["code"]) == 400 or int(r["code"]) == 401) and not _renouvelee_ailleurs():
		# (la session a péri ailleurs, ou trop vieille) : on la quitte
		deconnexion()
	return jeton


# --- le tableau des scores (les fonctions lisiere_* de la base de Stone Valley) ---
# Une partie commencée connecté a son numéro (lisiere_partie_commencer) ; à la fin, ses nuits tenues y sont inscrites
# (lisiere_partie_finir : la base refuse plus de nuits que le temps passé n'en permet). Sans réseau à la fin, l'inscription
# attend (user://tableau.json) et repart à l'écran-titre.

const ATTENTE := "user://tableau.json"


# une fonction de la base (/rest/v1/rpc/…), avec le jeton si l'on est connecté, sinon en anonyme
func base(nom: String, args: Dictionary = {}) -> Dictionary:
	var j := ""
	if connecte():
		j = await jeton_valide()
	var r := await _http(url + "/rest/v1/rpc/" + nom, args, HTTPClient.METHOD_POST, j)
	# (les fonctions de Lisière répondent { ok, erreur } ; le tableau, une liste)
	if r["ok"] and typeof(r["donnees"]) == TYPE_DICTIONARY and r["donnees"].has("ok") and not r["donnees"]["ok"]:
		r["ok"] = false
		r["erreur"] = str(r["donnees"].get("erreur", "refusé"))
	return r


# le numéro d'une partie qui commence ("" : pas de compte, ou pas de réseau)
func commencer_partie(lieu: String, nom_du_lieu: String) -> String:
	if not connecte():
		return ""
	var r := await base("lisiere_partie_commencer", {"p_lieu": lieu, "p_lieu_nom": nom_du_lieu})
	return str(r["donnees"].get("partie", "")) if r["ok"] else ""


# la fin d'une partie au tableau : { ok, rang, meilleur, erreur, attend } ; sans réseau, elle attend (attend = true)
func finir_partie(partie: String, nuits: int, croisees: int, chassees: int) -> Dictionary:
	var args := {"p_partie": partie, "p_nuits": nuits, "p_croisees": croisees, "p_chassees": chassees}
	var r := await base("lisiere_partie_finir", args)
	if r["ok"]:
		var d: Dictionary = r["donnees"]
		return {"ok": true, "rang": int(d.get("rang", 0)), "meilleur": int(d.get("meilleur", nuits)), "attend": false}
	if int(r["code"]) == 0 or int(r["code"]) >= 500:
		_mettre_en_attente(args)
		return {"ok": false, "erreur": r["erreur"], "attend": true}
	return {"ok": false, "erreur": r["erreur"], "attend": false}


# ce qui attendait d'être inscrit, renvoyé (à l'écran-titre)
func renvoyer_attente() -> void:
	var liste := _attente()
	if liste.is_empty() or not connecte():
		return
	var reste := []
	for a in liste:
		var r := await base("lisiere_partie_finir", a)
		if not r["ok"] and (int(r["code"]) == 0 or int(r["code"]) >= 500):
			reste.append(a)
	_ecrire_attente(reste)


func tableau(limite: int = 20) -> Dictionary:
	var r := await base("lisiere_tableau", {"p_limite": limite})
	if r["ok"] and typeof(r["donnees"]) == TYPE_ARRAY:
		return {"ok": true, "lignes": r["donnees"]}
	return {"ok": false, "lignes": [], "erreur": r.get("erreur", "")}


func moi() -> Dictionary:
	if not connecte():
		return {"ok": false, "erreur": "pas de compte"}
	var r := await base("lisiere_moi")
	return r["donnees"] if r["ok"] else {"ok": false, "erreur": r["erreur"]}


func nommer(pseudo: String) -> Dictionary:
	var r := await base("lisiere_nommer", {"p_pseudo": pseudo})
	return r["donnees"] if r["ok"] else {"ok": false, "erreur": r["erreur"]}


# --- la partie sur le compte (les fonctions lisiere_garder, lisiere_reprendre, lisiere_oublier : outils/sauvegarde.sql) ---
# Connectée, la partie gardée sur l'appareil part aussi sur le compte StoneValley : au plus une fois par minute pendant qu'on
# joue, et tout de suite à la pause, quand l'application passe derrière une autre, au retour au titre. À l'écran-titre, la plus
# récente des deux se reprend : on continue d'un autre appareil. Chaque appareil a un nom, tiré une fois. La base n'écrase pas ce
# qu'un autre appareil a écrit depuis la dernière révision que celui-ci a lue : elle le dit (« conflit »), et la partie ne part
# plus d'ici (elle reste sur l'appareil ; à l'écran-titre, la plus récente se reprend). Une partie nouvelle remplace celle du
# compte. Une partie finie s'efface du compte ; sans réseau, l'effacement attend (user://oubli.json).

const APPAREIL := "user://appareil.txt"
const OUBLI := "user://oubli.json"
const ENVOI := 60.0             # secondes : au plus un envoi par minute, pendant qu'on joue

var rev_partie := -1            # la révision de la partie du compte que cet appareil connaît (-1 : il n'en connaît pas)
var partie_nouvelle := false    # la prochaine écriture est celle d'une partie nouvelle : elle remplace celle du compte
var en_conflit := false         # un autre appareil a continué : cette partie ne part plus sur le compte
var _envoi := false
var _envoye_ms := -1000000
var _appareil := ""


# le nom de cet appareil : tiré une fois, gardé sur lui
func appareil() -> String:
	if _appareil != "":
		return _appareil
	if FileAccess.file_exists(APPAREIL):
		_appareil = FileAccess.get_file_as_string(APPAREIL).strip_edges()
	if _appareil.length() < 4:
		_appareil = Crypto.new().generate_random_bytes(8).hex_encode()
		var f := FileAccess.open(APPAREIL, FileAccess.WRITE)
		if f != null:
			f.store_string(_appareil)
	return _appareil


# une partie nouvelle commence : elle remplacera celle du compte
func partie_commence() -> void:
	rev_partie = -1
	partie_nouvelle = true
	en_conflit = false


# une partie reprend ; rev : la révision du compte lue à l'écran-titre (-1 : pas lue)
func partie_reprise(rev: int) -> void:
	rev_partie = rev
	partie_nouvelle = false
	en_conflit = false


# un envoi partirait-il maintenant ? (connectée, pas en conflit, pas d'envoi en cours, et la minute passée, sauf vite)
func envoi_possible(vite: bool) -> bool:
	return connecte() and not en_conflit and not _envoi and (vite or Time.get_ticks_msec() - _envoye_ms >= int(ENVOI * 1000.0))


# la partie, sur le compte. vite : sans attendre la minute. Rend { ok, erreur } ; « conflit » : un autre appareil a continué
func garder_partie(d: Dictionary, resume: Dictionary, vite: bool) -> Dictionary:
	if not connecte():
		return {"ok": false, "erreur": "pas de compte"}
	if en_conflit:
		return {"ok": false, "erreur": "conflit"}
	if _envoi:
		return {"ok": false, "erreur": "un envoi est en cours"}
	if not vite and Time.get_ticks_msec() - _envoye_ms < int(ENVOI * 1000.0):
		return {"ok": false, "erreur": "pas encore"}
	_envoi = true
	_envoye_ms = Time.get_ticks_msec()
	var r := await base("lisiere_garder", {"p_donnees": d, "p_resume": resume, "p_appareil": appareil(),
		"p_rev": rev_partie if rev_partie >= 0 else null, "p_nouvelle": partie_nouvelle})
	_envoi = false
	if r["ok"] and typeof(r["donnees"]) == TYPE_DICTIONARY:
		rev_partie = int(r["donnees"].get("rev", rev_partie))
		partie_nouvelle = false
	elif str(r.get("erreur", "")) == "conflit":
		en_conflit = true
		partie_en_conflit.emit()
	return r


# la partie du compte : { lu (la base a répondu), partie ({ donnees, rev, maj_le, appareil }, ou null) }
func partie_du_compte() -> Dictionary:
	if not connecte():
		return {"lu": false, "partie": null}
	var r := await base("lisiere_reprendre")
	if not r["ok"] or typeof(r["donnees"]) != TYPE_DICTIONARY:
		return {"lu": false, "partie": null}
	var p = r["donnees"].get("partie")
	return {"lu": true, "partie": p if typeof(p) == TYPE_DICTIONARY else null}


# la partie est finie : elle s'efface du compte (pas celle qu'un autre appareil a écrite depuis) ; sans réseau, cela attend
func oublier_partie() -> void:
	if not connecte():
		return
	var args := {"p_appareil": appareil(), "p_rev": rev_partie if rev_partie >= 0 else null}
	rev_partie = -1
	partie_nouvelle = false
	var r := await base("lisiere_oublier", args)
	if not r["ok"] and (int(r["code"]) == 0 or int(r["code"]) >= 500):
		var f := FileAccess.open(OUBLI, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(args))


# un effacement qui attendait le réseau (à l'écran-titre, avant de lire la partie du compte)
func renvoyer_oubli() -> void:
	if not connecte() or not FileAccess.file_exists(OUBLI):
		return
	var args = JSON.parse_string(FileAccess.get_file_as_string(OUBLI))
	if typeof(args) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(OUBLI)
		return
	var r := await base("lisiere_oublier", args)
	if r["ok"] or (int(r["code"]) > 0 and int(r["code"]) < 500):
		DirAccess.remove_absolute(OUBLI)


func _attente() -> Array:
	if not FileAccess.file_exists(ATTENTE):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(ATTENTE))
	return d if typeof(d) == TYPE_ARRAY else []


func _mettre_en_attente(args: Dictionary) -> void:
	var liste := _attente()
	liste.append(args)
	_ecrire_attente(liste.slice(-20))


func _ecrire_attente(liste: Array) -> void:
	if liste.is_empty():
		if FileAccess.file_exists(ATTENTE):
			DirAccess.remove_absolute(ATTENTE)
		return
	var f := FileAccess.open(ATTENTE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(liste))


# --- Supabase Auth ---

# un appel à Supabase Auth : { ok, code, donnees, erreur } ; l'erreur est dite en français
func _appeler(chemin: String, corps, methode: int = HTTPClient.METHOD_POST, avec_jeton: bool = false, j: String = "") -> Dictionary:
	return await _http(url + "/auth/v1" + chemin, corps, methode, (j if j != "" else jeton) if avec_jeton else "")


func _http(adresse: String, corps, methode: int, j: String) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 20.0
	add_child(h)
	var entetes := PackedStringArray(["Content-Type: application/json", "apikey: " + CLE])
	if j != "":
		entetes.append("Authorization: Bearer " + j)
	var e := h.request(adresse, entetes, methode, JSON.stringify(corps) if corps != null else "")
	if e != OK:
		h.queue_free()
		return {"ok": false, "code": 0, "donnees": null, "erreur": "pas de connexion"}
	var res: Array = await h.request_completed
	h.queue_free()
	var code := int(res[1])
	var texte: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var d = JSON.parse_string(texte) if texte != "" else null
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "donnees": null, "erreur": "pas de connexion"}
	if code < 200 or code >= 300:
		var m := ""
		if typeof(d) == TYPE_DICTIONARY:
			for k in ["error_description", "msg", "message", "error", "error_code"]:
				if d.get(k) != null and str(d.get(k)) != "":
					m = str(d.get(k))
					break
		return {"ok": false, "code": code, "donnees": d, "erreur": dire(m if m != "" else "erreur %d" % code)}
	return {"ok": true, "code": code, "donnees": d, "erreur": ""}


static func dire(m: String) -> String:
	var bas := m.to_lower()
	for x in DITS:
		if bas.contains(x[0]):
			return x[1]
	return m


func _prendre(r) -> void:
	if typeof(r) != TYPE_DICTIONARY or not r.has("access_token"):
		return
	jeton = str(r["access_token"])
	if r.get("refresh_token") != null:
		renouveau = str(r["refresh_token"])
	expire = Time.get_unix_time_from_system() + float(r.get("expires_in", 3600))
	var u = r.get("user")
	if typeof(u) == TYPE_DICTIONARY:
		uid = str(u.get("id", uid))
		email = str(u.get("email", email))
	_ecrire()
	change.emit()


# où le courriel de Supabase ramène : la page du jeu (Supabase doit la connaître, dans ses adresses de retour permises ;
# sinon il ramène à la sienne, celle de Stone Valley, et le compte vaut pareil)
func _retour() -> String:
	if OS.has_feature("web"):
		var a = JavaScriptBridge.eval("location.origin + location.pathname", true)
		if typeof(a) == TYPE_STRING and str(a).begins_with("http"):
			return str(a)
	return ADRESSE_DU_JEU


# retour du courriel : Supabase ramène ici avec la session dans l'adresse (#access_token=…&type=signup|recovery) ; on la prend,
# puis on l'efface de l'adresse
func _retour_du_courriel() -> void:
	var h = JavaScriptBridge.eval("location.hash", true)
	if typeof(h) != TYPE_STRING or not (str(h).contains("access_token=") or str(h).contains("error_description=")):
		return
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)", true)
	var p := {}
	for morceau in str(h).trim_prefix("#").split("&"):
		var kv := morceau.split("=", true, 1)
		if kv.size() == 2:
			p[kv[0]] = kv[1].uri_decode()
	if not p.has("access_token"):
		return
	jeton = str(p["access_token"])
	renouveau = str(p.get("refresh_token", ""))
	expire = Time.get_unix_time_from_system() + float(p.get("expires_in", "3600"))
	var r := await _appeler("/user", null, HTTPClient.METHOD_GET, true)
	if r["ok"] and typeof(r["donnees"]) == TYPE_DICTIONARY:
		uid = str(r["donnees"].get("id", ""))
		email = str(r["donnees"].get("email", ""))
		nouveau_mdp = str(p.get("type", "")) == "recovery"
		_ecrire()
		change.emit()
	else:
		jeton = ""
		renouveau = ""


# --- la session gardée ---
# Hors d'un navigateur : un fichier. Dans un navigateur : la clé commune du site, et elle seule (le fichier d'avant y est versé une
# fois, puis effacé : sinon une session fermée au portail renaîtrait d'ici).

func _lire() -> void:
	if OS.has_feature("web"):
		var c := _commune()
		if not c.is_empty():
			_adopter(c)
			return
	if not FileAccess.file_exists(FICHIER):
		return
	var s = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(s) == TYPE_DICTIONARY:
		jeton = str(s.get("jeton", ""))
		renouveau = str(s.get("renouveau", ""))
		expire = float(s.get("expire", 0.0))
		uid = str(s.get("uid", ""))
		email = str(s.get("email", ""))
	if OS.has_feature("web"):
		DirAccess.remove_absolute(FICHIER)
		_ecrire()


func _ecrire() -> void:
	if OS.has_feature("web"):
		_ecrire_commune()
		return
	if not connecte():
		if FileAccess.file_exists(FICHIER):
			DirAccess.remove_absolute(FICHIER)
		return
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"jeton": jeton, "renouveau": renouveau, "expire": expire, "uid": uid, "email": email}))


# la session commune du site, telle qu'elle est gardée ({} : aucune). Sa forme : { jeton, refresh, exp (millisecondes), uid, email, pseudo }
func _commune() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var t = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % COMMUNE, true)
	if typeof(t) != TYPE_STRING or str(t) == "":
		return {}
	var s = JSON.parse_string(str(t))
	if typeof(s) != TYPE_DICTIONARY or str(s.get("jeton", "")) == "" or str(s.get("uid", "")) == "":
		return {}
	return s


func _adopter(c: Dictionary) -> void:
	jeton = str(c.get("jeton", ""))
	renouveau = str(c.get("refresh", ""))
	expire = float(c.get("exp", 0.0)) / 1000.0
	uid = str(c.get("uid", ""))
	email = str(c.get("email", ""))


func _ecrire_commune() -> void:
	if not connecte():
		JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % COMMUNE, true)
		return
	# (le pseudo que le portail y a mis reste, si c'est le même compte)
	var avant := _commune()
	var pseudo := str(avant.get("pseudo", "")) if str(avant.get("uid", "")) == uid else ""
	var texte := JSON.stringify({"jeton": jeton, "refresh": renouveau, "exp": int(expire * 1000.0), "uid": uid, "email": email, "pseudo": pseudo})
	JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [COMMUNE, JSON.stringify(texte)], true)


# le portail ou un autre jeu vient-il de renouveler la session commune ? Alors on prend la leur, sans rien demander au service
func _renouvelee_ailleurs() -> bool:
	var c := _commune()
	if c.is_empty() or str(c.get("uid", "")) != uid or str(c.get("refresh", "")) in ["", renouveau]:
		return false
	if float(c.get("exp", 0.0)) / 1000.0 <= Time.get_unix_time_from_system() + 60.0:
		return false
	_adopter(c)
	return true
