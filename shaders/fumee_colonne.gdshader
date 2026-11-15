// Lisière — la colonne de fumée âcre (shaders/fumee_colonne.gdshader)
// Une botte d'herbe âcre jetée dans un feu (scripts/botanique.gd) : une fumée ocre, épaisse, qui monte en se tordant et que le
// vent couche. Un seul rectangle au-dessus du foyer (UV : 0 en haut, 1 au pied), deux lectures du bruit : des volutes qui
// montent, plus serrées au pied, qui s'ouvrent et se déchirent en haut. Posée comme un lavis : deux tons, un bord plus sombre
// là où l'encre s'accumule. Elle se teint elle-même (l'heure, la lueur du feu à son pied) : la nuit, on la voit encore.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float force = 1.0;       // de 0 à 1 : elle s'éteint sur ses dernières secondes
uniform float monte = 1.0;       // de 0 à 1 : elle vient de prendre, elle monte
uniform float vent = 0.0;        // de -1 à 1
uniform float graine = 0.0;
uniform float feu = 1.0;         // la lueur du feu à son pied
uniform vec4 ocre : source_color = vec4(0.69, 0.5, 0.25, 1.0);
uniform vec4 sombre : source_color = vec4(0.3, 0.23, 0.15, 1.0);
uniform vec4 braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);
uniform vec4 ambiance : source_color = vec4(1.0);

void fragment() {
	float h = 1.0 - UV.y;
	// l'axe de la colonne : droit au pied, couché par le vent à mesure qu'elle monte, et qui serpente
	float axe = vent * pow(h, 1.55) * 0.27 + sin(h * 5.0 - TIME * 0.7 + graine) * 0.028 * h;
	float x = UV.x - 0.5 - axe;
	float large = mix(0.06, 0.22, pow(h, 0.7));
	// les volutes : elles montent (le bruit descend), en gros rouleaux ; une trame plus fine, plus vive, par-dessus
	float n1 = texture(bruit, vec2(x * 1.5 / (0.3 + h) + graine, h * 1.5 - TIME * 0.2)).r;
	float n2 = texture(bruit, vec2(UV.x * 4.2 - axe * 4.0 + graine * 1.7, h * 3.6 - TIME * 0.37)).r;
	float n = n1 * 0.6 + n2 * 0.4;
	float profil = 1.0 - smoothstep(large * 0.45, large, abs(x) + (n - 0.5) * 0.3 * (0.25 + h));
	// (le haut se déchire, le pied sort du foyer ; quand elle prend, elle n'a pas encore toute sa hauteur)
	float haut = 1.0 - smoothstep(0.5 * monte, 0.97 * monte + 0.02, h + (n2 - 0.5) * 0.3);
	float pied = smoothstep(0.0, 0.06, h);
	float dense = profil * haut * pied;
	float a = smoothstep(0.26, 0.5, n * 0.5 + dense * 0.5) * smoothstep(0.0, 0.3, dense);
	// le lavis : un ton pour le corps, un plus clair au gras des rouleaux, un bord sombre là où l'encre s'accumule
	float gras = smoothstep(0.5, 0.72, n1 + (n2 - 0.5) * 0.5);
	float bord = smoothstep(0.02, 0.3, a) * (1.0 - smoothstep(0.3, 0.75, a));
	vec3 col = mix(ocre.rgb * 0.82, ocre.rgb * 1.2 + 0.06, gras);
	col = mix(col, sombre.rgb, bord * 0.6 + smoothstep(0.5, 1.0, h) * 0.25);
	col *= max(ambiance.rgb, vec3(0.52, 0.52, 0.58));
	col += braise.rgb * feu * 0.55 * exp(-h * 5.0) * (0.55 + 0.45 * n2);
	COLOR = vec4(col, a * force * mix(0.92, 0.6, smoothstep(0.15, 1.0, h)));
}
