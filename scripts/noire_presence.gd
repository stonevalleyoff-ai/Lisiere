extends RefCounted
# Lisière — la présence de la Noire (scripts/noire_presence.gd)
# Ce qui dit « elle est là » avant qu'on l'ait vue. Rien qu'on puisse montrer du doigt : le lieu se retient.
#  - le vent tombe, et ce qu'il en reste tire vers elle : la flamme du feu, sa fumée, ses étincelles penchent de son côté
#    (scripts/feu.gd lit effets.vent()), les feuilles tombent droit ;
#  - les lucioles s'éteignent (scripts/effets_lieu.gd).
# Tout suit jeu.noire.silence (scripts/noire.gd : ce qui fait déjà taire les grillons). scripts/effets.gd l'appelle, et rien
# ne se dessine ici : aucun appel de dessin de plus.

const TIRE := 0.6               # ce que le vent garde, tourné vers elle (la flamme penche à peine : le vent va de -1 à 1)

var jeu
var calme := 0.0                # de 0 à 1 : ce que sa présence retient du lieu
var cote := 0.0                 # de -1 à 1 : de quel côté du feu (de la veilleuse, sans feu) elle se tient
var _eteintes := 0.0            # de 0 à 1 : ce que les lucioles ont perdu


func vider() -> void:
	calme = 0.0
	cote = 0.0
	_eteintes = 0.0


# chaque image
func maj(delta: float) -> void:
	var noire = jeu.get("noire") if jeu != null else null
	var j = jeu.joueur if jeu != null else null
	if noire == null or j == null:
		calme = 0.0
		_eteintes = 0.0
		return
	calme = smoothstep(0.2, 0.85, float(noire.silence))
	# (les lucioles ne s'éteignent pas d'un coup : en six ou sept secondes, et elles mettent plus longtemps à revenir)
	var eteint := smoothstep(0.0, 0.6, calme)
	_eteintes = move_toward(_eteintes, eteint, delta * (0.15 if eteint > _eteintes else 0.06))
	if calme <= 0.0:
		return
	# (le feu qui protège la veilleuse : c'est lui qu'on regarde pencher)
	var ici: Vector2 = j.position
	var feu = jeu.feu_qui_protege(ici) if jeu.has_method("feu_qui_protege") else null
	if feu != null and is_instance_valid(feu):
		ici = feu.position
	# (elle tourne autour du feu : la flamme la suit sans à-coup, et se redresse quand elle passe derrière ou devant)
	var vers: float = clampf((float(noire.ou.x) - ici.x) / 180.0, -1.0, 1.0)
	cote = move_toward(cote, vers, delta * 0.5)


# le vent du lieu, tel que sa présence le laisse : il tombe, et ce qu'il en reste va vers elle
func vent(v: float) -> float:
	if calme <= 0.0:
		return v
	return lerpf(v, cote * TIRE, calme * 0.85)


# ce qu'il reste des lucioles : elles s'éteignent avant qu'elle arrive
func lucioles() -> float:
	return 1.0 - _eteintes
