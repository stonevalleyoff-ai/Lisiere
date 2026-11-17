extends Node
# Lisière — les lots (scripts/lots.gd)
# Ce que la partie renvoie au monde d'Orvane, et quand (BRANCHER-UN-JEU.md d'Orvane, « Renvoyer des pressions »). Le kit
# (addons/orvane) compte au moment où ça arrive : une bête croisée, chassée, blessée, tenue par le feu, apprivoisée, rendue aux
# siens. Ici, on décide quand ce qui est compté devient un lot, et quand il part :
#  - à chaque sauvegarde de la partie (toutes les vingt secondes, à la pause, quand le jeu passe derrière une autre application),
#    ce qui est compté se garde sur l'appareil (Orvane.garder) : fermé d'un coup, le jeu le retrouve au lancement ;
#  - un lot se clôt au plus tous les quarts d'heure de jeu (Orvane en accepte 48 par joueur et par jour), et tout de suite au
#    retour au titre et à la fin de la partie ; au lancement, ce qui restait d'une partie d'avant se clôt aussi (l'écran-titre) ;
#  - chaque lot clos part aussitôt, et tous ceux qui attendaient avec lui. Refusé, ou faute de réseau, un lot reste sur
#    l'appareil et repart au moment suivant.
# La nuit venue, le cycle d'Orvane lit les lots de tous les jeux : ce que Lisière a renvoyé pèse sur le monde du lendemain.
# Rien ne part d'une partie d'essai, de la vitrine, ni d'une partie à la mémoire forcée (scripts/donnees.gd) : le kit l'oublie.
# Le joueur, pour Orvane : connecté au compte StoneValley, une empreinte de son compte (le même joueur sur tous ses appareils) ;
# sinon, celle de l'appareil (principal.gd, compte). Orvane n'en garde qu'un pseudonyme, pour ses plafonds par joueur.

const INTERVALLE := 15 * 60 * 1000       # millisecondes : un lot au plus par quart d'heure de jeu
const ATTENTE := 30000                    # millisecondes : un dépôt resté sans réponse est laissé pour le moment suivant

var jeu
var vers := ""                 # (l'essai seulement : l'adresse d'un faux Supabase d'Orvane, outils/faux-compte.js)
var recus := 0                 # les lots qu'Orvane a acceptés depuis le lancement
var recus_partie := 0          # … pendant cette partie
var clos_partie := 0           # les lots clos pendant cette partie (partis, ou qui attendent)
var erreur := ""               # pourquoi le dernier dépôt n'est pas passé ("" : il est passé)
var _clos_ms := 0              # quand le dernier lot s'est clos (ou la partie a commencé), à l'horloge de l'appareil
var _envoi := false
var _encore := false            # un lot s'est clos pendant un dépôt : un tour de plus
var _rep = null


func _ready() -> void:
	_clos_ms = Time.get_ticks_msec()
	Orvane.lot_depose.connect(_depose)


# le jeu envoie-t-il ? Sa clé, une vraie partie (l'essai, seulement vers son faux service), les bêtes du monde tel qu'il est
func permis() -> bool:
	if jeu == null or Orvane.cle_jeu == "" or jeu.donnees.memoire_forcee != "":
		return false
	if jeu.essai != null:
		return vers != "" and Orvane.supabase_url == vers
	return true


# le joueur, pour Orvane : opaque, et le même sur tous ses appareils s'il est connecté
func joueur() -> String:
	var s = jeu.session
	if s != null and s.connecte():
		return "sv:" + ("lisiere:" + str(s.uid)).sha256_text().substr(0, 24)
	return str(jeu.compte)


# une partie commence (ou reprend) : le quart d'heure repart d'ici
func nouvelle_partie() -> void:
	recus_partie = 0
	clos_partie = 0
	_clos_ms = Time.get_ticks_msec()


# à chaque sauvegarde de la partie (principal.gd, _garder) : ce qui est compté se garde ; un quart d'heure après le dernier lot,
# il se clôt et part
func au_fil() -> void:
	if not permis():
		return
	Orvane.garder()
	if Time.get_ticks_msec() - _clos_ms >= INTERVALLE:
		clore()


# clôt ce qui est compté en un lot (s'il y a de quoi) et dépose tout ce qui attend ; rend le nombre de lots clos ici
func clore() -> int:
	if not permis():
		return 0
	var avant: int = Orvane.lots_en_attente()
	if Orvane.en_cours() > 0:
		Orvane.clore(joueur())
	_clos_ms = Time.get_ticks_msec()
	var n: int = Orvane.lots_en_attente() - avant
	clos_partie += n
	deposer()
	return n


# dépose les lots qui attendent, un à un (le kit en dépose un à la fois) ; au premier refus, les autres attendent avec lui
func deposer() -> void:
	if not permis() or Orvane.lots_en_attente() == 0:
		return
	if _envoi:
		# (un dépôt est en route : un lot clos entre-temps part dans la foulée, même si celui-là est refusé)
		_encore = true
		return
	_envoi = true
	var tour := true
	while tour:
		_encore = false
		while Orvane.lots_en_attente() > 0 and permis():
			_rep = null
			Orvane.deposer(joueur())
			var t0 := Time.get_ticks_msec()
			while _rep == null and Time.get_ticks_msec() - t0 < ATTENTE:
				await get_tree().process_frame
			if _rep == null:
				erreur = "pas de réponse"
				break
			if not bool(_rep[0]):
				erreur = str(_rep[1].get("erreur", "refusé"))
				break
			erreur = ""
			recus += 1
			recus_partie += 1
		tour = _encore and erreur != "pas de réponse" and Orvane.lots_en_attente() > 0
	_envoi = false


func _depose(ok: bool, reponse: Dictionary) -> void:
	_rep = [ok, reponse]


func en_cours() -> bool:
	return _envoi


# ce que la pause en dit ("" : rien à dire)
func texte() -> String:
	if not permis():
		return ""
	var att: int = Orvane.lots_en_attente()
	var t := ""
	if recus_partie > 0:
		t = "Le monde d'Orvane a reçu %d lot%s de cette partie." % [recus_partie, "s" if recus_partie > 1 else ""]
	if att > 0:
		t += (" " if t != "" else "") + "%d lot%s attend%s le réseau." % [att, "s" if att > 1 else "", "ent" if att > 1 else ""]
	if t == "":
		t = "Ce que tu croises et ce que tu chasses part au monde d'Orvane : un lot par quart d'heure, et au retour au titre."
	return t
