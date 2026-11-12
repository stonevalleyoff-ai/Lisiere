shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Lisière — l'incendie, au sol (shaders/incendie_sol.gdshader)
// Sous chaque objet en feu, posé sur le sol (sous tout ce qui se tient debout) : la terre brûlée et ses braises, là où l'on
// prend feu (un disque de vingt-quatre pixels autour du pied), et autour la lueur des flammes, qui bat. Tous les foyers dans
// un seul MultiMesh (scripts/incendie_flammes.gd) : un appel de dessin. Quand le feu est mort, les braises s'éteignent une à
// une et la lueur s'en va.
// Ce que dit une instance : sa couleur : la force du feu (r), le rayon de sa lueur en pixels / 256 (v), sa graine (b), ce
// qu'il reste de chaleur une fois le feu mort (a : de 1 à 0).

uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform float nuit = 0.0;                           // de 0 (le plein jour) à 1
uniform float contact = 24.0;                       // à cette distance du pied, on prend feu (R.INCENDIE_CONTACT)
uniform vec4 encre : source_color = vec4(0.086, 0.075, 0.059, 1.0);
uniform vec4 rouge : source_color = vec4(0.77, 0.27, 0.16, 1.0);
uniform vec4 braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);
uniform vec4 coeur : source_color = vec4(1.0, 0.85, 0.54, 1.0);

varying vec4 v_feu;         // (la force, le rayon, la graine, la chaleur qui reste)
varying vec2 v_p;           // autour du pied, en pixels

void vertex() {
	v_feu = COLOR;
	float r = COLOR.g * 256.0;
	// (le sol est vu de biais : la lueur s'y couche)
	VERTEX *= vec2(r * 2.0, r * 1.3);
	v_p = VERTEX;
}

void fragment() {
	float force = v_feu.r;
	float r = v_feu.g * 256.0;
	float g = v_feu.b * 17.0;
	float tiede = v_feu.a;
	float vif = max(force, tiede * 0.5);
	// la lueur : elle bat, et s'efface vers son bord
	float d = length(v_p / vec2(r, r * 0.65));
	float bat = 0.86 + 0.14 * sin(t * 7.3 + g * 5.0) * sin(t * 3.1 + g);
	float lueur = pow(max(1.0 - d, 0.0), 1.7) * force * bat * mix(0.2, 0.52, nuit);
	// la terre brûlée, là où l'on prend feu : une tache à peine couchée, au bord déchiré par un bruit (pas un cercle)
	vec2 q = v_p / vec2(contact + 3.0, contact * 0.66);
	float n = texture(bruit, v_p / 47.0 + g).r;
	float dq = length(q) + (n - 0.5) * 0.7;
	float brule = (1.0 - smoothstep(0.55, 1.0, dq)) * max(smoothstep(0.0, 0.3, force), tiede);
	// ses braises : des grains qui battent, plus serrés vers le pied, qui s'éteignent un à un quand le feu est mort
	float grains = texture(bruit, v_p / 7.0 + g * 3.0).r;
	float bat2 = 0.55 + 0.45 * sin(t * (2.0 + 3.0 * n) + grains * 40.0);
	float seuil = 0.72 - 0.16 * vif + 0.2 * dq;
	float pts = smoothstep(seuil, seuil + 0.05, grains) * smoothstep(1.05, 0.7, dq) * vif * bat2;
	vec3 feu = mix(rouge.rgb, braise.rgb, bat2 * 0.8) * pts + mix(braise.rgb, coeur.rgb, 0.2) * lueur;
	float noir = brule * 0.5;
	COLOR = vec4(encre.rgb * noir * (1.0 - min(pts, 1.0)) + feu, noir);
}
