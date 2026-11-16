// Lisière — la nappe de fumée âcre (shaders/fumee_nappe.gdshader)
// Sous la colonne (shaders/fumee_colonne.gdshader), au ras du sol : la fumée s'étale autour du feu jusqu'où elle tient les
// chasseurs (le rayon du feu fois Botanique.GARDE). Un seul rectangle couché au sol (UV : de 0 à 1 ; le cercle y est une
// ellipse), deux lectures du bruit : des langues qui rampent du foyer vers le bord, que le vent pousse. Mince près du feu (on
// y voit le camp), plus épaisse en un bourrelet vers son bord : c'est lui qu'on lit, la nuit comme le jour. Un lavis d'ocre,
// au bord plus sombre ; elle se teint elle-même (l'heure, la lueur du feu).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float force = 1.0;       // de 0 à 1 : elle s'éteint sur ses dernières secondes
uniform float etale = 1.0;       // de 0 à 1 : elle gagne son rayon
uniform float vent = 0.0;        // de -1 à 1
uniform float graine = 0.0;
uniform float feu = 1.0;         // la lueur du feu, en son milieu
uniform float lumiere = 0.7;     // jusqu'où porte sa lumière, en parts du rayon de la nappe
uniform vec4 ocre : source_color = vec4(0.69, 0.5, 0.25, 1.0);
uniform vec4 sombre : source_color = vec4(0.3, 0.23, 0.15, 1.0);
uniform vec4 braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);
uniform vec4 ambiance : source_color = vec4(1.0);

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q) / max(etale, 0.05);
	float tour = atan(q.y, q.x) * 0.4775;
	// des langues qui partent du foyer (le bruit, étiré le long du rayon, qui s'éloigne) ; des volutes que le vent pousse
	float n1 = texture(bruit, vec2(tour * 2.0 + graine, d * 0.5 - TIME * 0.03)).r;
	float n2 = texture(bruit, q * vec2(2.3, 4.2) + vec2(graine - TIME * (0.016 + 0.035 * vent), TIME * 0.008)).r;
	float n = n1 * 0.45 + n2 * 0.55;
	// le bord : mangé par le bruit ; le bourrelet, juste avant (c'est là qu'elle tient les chasseurs)
	float r = d + (n - 0.5) * 0.3;
	float dedans = 1.0 - smoothstep(0.86, 1.0, r);
	float bourrelet = smoothstep(0.55, 0.9, r);
	// (près du feu, des filets seulement ; vers le bord, un rouleau épais)
	float filets = smoothstep(0.52, 0.7, n) * smoothstep(0.04, 0.22, d);
	float rouleau = smoothstep(0.34, 0.6, n + 0.1 * bourrelet) * bourrelet;
	float a = dedans * max(filets * 0.5, rouleau);
	float bord = smoothstep(0.02, 0.22, a) * (1.0 - smoothstep(0.22, 0.6, a));
	vec3 col = mix(ocre.rgb * 0.86, ocre.rgb * 1.18 + 0.05, smoothstep(0.5, 0.75, n2 + (n1 - 0.5) * 0.4));
	col = mix(col, sombre.rgb, bord * 0.5);
	// (dans la lumière du feu, elle la prend : claire et chaude près de lui, elle s'éteint vers le bord de sa lumière)
	float eclat = feu * pow(1.0 - clamp(length(q) / max(lumiere, 0.05), 0.0, 1.0), 1.3);
	col *= max(ambiance.rgb, vec3(0.5, 0.5, 0.58)) + braise.rgb * eclat * 1.1;
	COLOR = vec4(col, a * force * 0.52);
}
