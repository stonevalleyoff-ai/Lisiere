// Lisière — ce qui tombe (shaders/temps_chute.gdshader)
// La pluie et la neige, devant la caméra : quelques centaines de petits rectangles (un MultiMesh, un seul appel de dessin :
// scripts/ciel.gd), que ce shader fait tomber lui-même d'après l'heure. Chacun a son rang, de 0 à 1 : les premiers sont des
// gouttes (autant qu'il pleut), les derniers des flocons (autant qu'il neige), les autres ne se dessinent pas.
// Une goutte : un trait fin, couché par le vent, plus pâle à sa queue ; une sur cinq passe tout près, plus longue et plus vive.
// Un flocon : un point net, qui descend en se balançant.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform vec2 ecran = vec2(1280.0, 720.0);
uniform float pluie = 0.0;             // la part des gouttes
uniform float neige = 0.0;             // la part des flocons
uniform float temps = 0.0;
uniform float pente = 0.2;             // ce que le vent couche la pluie (pixels de côté par pixel de chute)
uniform float souffle = 0.0;           // ce qu'il pousse la neige (pixels par seconde)
uniform float eclat = 0.0;
uniform vec4 c_pluie : source_color = vec4(0.78, 0.82, 0.86, 1.0);
uniform vec4 c_neige : source_color = vec4(0.96, 0.96, 0.95, 1.0);
uniform vec4 c_ombre : source_color = vec4(0.5, 0.58, 0.74, 1.0);

varying vec2 coin;
varying float flocon;
varying float force;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;          // x, y : où ; z : sa taille, sa vitesse ; w : son rang
	coin = UV;
	vec2 v = VERTEX;
	if (c.w < pluie) {
		float proche = step(0.8, fract(c.z * 7.0 + 0.13));
		float vitesse = mix(780.0, 1150.0, c.z) * (1.0 + 0.3 * proche);
		float chemin = ecran.y + 90.0;
		float tour = c.y + temps * vitesse / chemin;
		// (à chaque passage, ailleurs)
		float hx = fract(sin((c.x + floor(tour) * 0.137) * 91.345) * 43758.5453);
		float y = fract(tour) * chemin - 45.0;
		float marge = abs(pente) * ecran.y * 0.5 + 24.0;
		float x = hx * (ecran.x + 2.0 * marge) - marge + pente * (y - ecran.y * 0.5);
		vec2 d = normalize(vec2(pente, 1.0));
		VERTEX = vec2(x, y) + d * (v.y * mix(14.0, 30.0, c.z) * (1.0 + 0.8 * proche)) + vec2(d.y, -d.x) * (v.x * (1.7 + 1.1 * proche));
		flocon = 0.0;
		force = mix(0.36, 0.7, proche);
	} else if (c.w > 1.0 - neige) {
		float proche = fract(c.z * 5.0 + 0.4);
		float haut = ecran.y + 24.0;
		float large = ecran.x + 24.0;
		float y = fract(c.y + temps * mix(34.0, 92.0, proche) / haut) * haut - 12.0;
		float x = fract(c.x + (temps * souffle * (0.5 + 0.9 * proche) + sin(temps * (0.6 + c.z) + c.x * 40.0) * 16.0) / large) * large - 12.0;
		VERTEX = vec2(x, y) + v * mix(3.4, 8.0, proche * proche);
		flocon = 1.0;
		force = mix(0.5, 0.95, proche);
	} else {
		VERTEX = vec2(-100.0);
		flocon = 0.0;
		force = 0.0;
	}
}

void fragment() {
	float a = force;
	vec3 col = c_pluie.rgb;
	if (flocon > 0.5) {
		// (un point blanc, cerné d'un bleu d'ombre : il se lit sur la terre comme sur la neige)
		float r = length(coin - 0.5) * 2.0;
		a *= 1.0 - smoothstep(0.78, 0.98, r);
		col = mix(c_neige.rgb, c_ombre.rgb, smoothstep(0.42, 0.62, r));
	} else {
		a *= smoothstep(0.0, 0.7, coin.y) * (1.0 - smoothstep(0.88, 1.0, coin.y)) * smoothstep(0.0, 0.7, 1.0 - abs(coin.x - 0.5) * 2.0);
	}
	col = mix(col, vec3(1.0), eclat);
	a = min(1.0, a * (1.0 + eclat));
	COLOR = vec4(col * a, a);
}
