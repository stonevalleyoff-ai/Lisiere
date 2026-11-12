// Lisière — le voile de l'écran (shaders/ecran_voile.gdshader)
// Posé sur l'image sans la lire (il ne coûte presque rien, sur un téléphone comme sur un ordinateur) : la nuit qui bleuit les
// noirs (jamais d'un noir plat), la vignette (toujours un peu ; beaucoup avec la peur, et au-delà de 70 elle bat avec le
// cœur), la morsure (un voile rouge, des bords d'encre rouge), le souffle froid de la tombée, le givre quand le corps a froid, la fournaise quand il a trop chaud ou qu'il brûle, la lumière de l'aube, le frisson
// d'un écho, la fin qui assombrit tout, et un grain très léger. Alpha prémultiplié : il peut assombrir et éclairer.
// Sur un ordinateur, la passe d'écran (shaders/ecran_post.gdshader) retire la couleur ; sans elle (« seul »), le voile l'imite.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float seul = 1.0;
uniform float ratio = 1.7778;
uniform float nuit = 0.0;
uniform float peur = 0.0;
uniform float coeur = 0.0;
uniform float blessure = 0.0;
uniform float froid = 0.0;
uniform float givre = 0.0;
uniform float fournaise = 0.0;
uniform float aube = 0.0;
uniform float echo = 0.0;
uniform float fin = 0.0;
uniform float noir = 0.0;
uniform float grain = 0.0;
uniform vec4 encre : source_color = vec4(0.04, 0.05, 0.094, 1.0);
uniform vec4 ombre : source_color = vec4(0.1, 0.14, 0.25, 1.0);
uniform vec4 sang : source_color = vec4(0.48, 0.11, 0.11, 1.0);
uniform vec4 c_peur : source_color = vec4(0.54, 0.44, 0.84, 1.0);
uniform vec4 c_froid : source_color = vec4(0.44, 0.53, 0.72, 1.0);
uniform vec4 c_givre : source_color = vec4(0.8, 0.89, 0.97, 1.0);
uniform vec4 c_braise : source_color = vec4(0.93, 0.44, 0.15, 1.0);
uniform vec4 c_aube : source_color = vec4(0.91, 0.73, 0.63, 1.0);
uniform vec4 c_echo : source_color = vec4(0.75, 0.89, 1.0, 1.0);

float hache(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// une couche de plus, par-dessus les autres (couleur, opacité)
vec4 sur(vec4 dessous, vec3 c, float a) {
	return vec4(c * a + dessous.rgb * (1.0 - a), a + dessous.a * (1.0 - a));
}

void fragment() {
	vec2 c = UV - 0.5;
	float re = length(c) * 1.4142;
	vec4 v = vec4(0.0);
	v = sur(v, vec3(0.42), fin * 0.3 * seul);
	v = sur(v, c_peur.rgb * 0.3, smoothstep(0.55, 1.0, peur) * 0.14 * seul);
	v = sur(v, c_froid.rgb * 0.35, froid * 0.22);
	v = sur(v, c_echo.rgb * 0.5, echo * 0.12 * seul);
	float ouvre = mix(0.58, 0.16, peur) - coeur * 0.12;
	float vi = smoothstep(ouvre, ouvre + 0.9, re);
	v = sur(v, encre.rgb, clamp(vi * (0.32 + 0.5 * peur + 0.12 * coeur), 0.0, 0.92));
	if (blessure > 0.01) {
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 0.9).r;
		// (un bord net, mangé par le bruit : de l'encre, pas un nuage ; il gagne vers le centre au plus fort de la morsure)
		float bord = smoothstep(0.0, 0.04, re + (n - 0.5) * 0.55 - mix(1.05, 0.72, blessure));
		v = sur(v, sang.rgb * 0.7, blessure * 0.22);
		v = sur(v, sang.rgb * (0.6 + 0.4 * n), clamp(bord * (0.35 + 0.6 * blessure), 0.0, 0.92));
	}
	if (givre > 0.01) {
		// le corps a froid : le givre gagne par les bords, en aiguilles tournées vers le centre (le bruit, étiré le long du rayon)
		float tour = atan(c.y, c.x * ratio) * 0.63662;
		float n = texture(bruit, vec2(tour * 2.0, re * 0.3)).r * 0.65 + texture(bruit, UV * vec2(ratio, 1.0) * 2.3).r * 0.35;
		float bord = smoothstep(0.0, 0.09, re + (n - 0.5) * 0.55 - mix(1.14, 0.76, givre));
		v = sur(v, c_givre.rgb * 0.45, givre * 0.1);
		v = sur(v, c_givre.rgb * (0.62 + 0.38 * n), clamp(bord * (0.22 + 0.5 * givre), 0.0, 0.8));
	}
	if (fournaise > 0.01) {
		// la chaleur accable, ou elle brûle : les bords rougeoient et montent comme une flamme
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 1.1 + vec2(0.0, TIME * 0.4)).r;
		float bord = smoothstep(0.0, 0.32, re + (n - 0.5) * 0.5 - mix(1.16, 0.84, fournaise));
		v = sur(v, c_braise.rgb * 0.8, fournaise * 0.08);
		v = sur(v, c_braise.rgb * (0.5 + 0.5 * n), clamp(bord * (0.2 + 0.42 * fournaise), 0.0, 0.7));
	}
	v = sur(v, encre.rgb * 0.5, noir);
	// ce qui éclaire : ajouté par-dessus (le bleu des noirs la nuit, la lumière de l'aube)
	v.rgb += ombre.rgb * nuit * (1.0 - v.a) + c_aube.rgb * aube * 0.12 * (1.0 - re * 0.6);
	// le grain : un peu de lumière ici, un peu d'ombre là, qui change à chaque image
	float g = (hache(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + fract(TIME * 7.13) * 311.0) - 0.5) * grain;
	v.rgb += vec3(max(g, 0.0)) * (1.0 - v.a);
	v = sur(v, vec3(0.0), max(-g, 0.0));
	COLOR = v;
}
