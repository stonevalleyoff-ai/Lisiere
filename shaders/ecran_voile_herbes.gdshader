// Lisière — le voile de l'écran, avec ce que les herbes font voir (shaders/ecran_voile_herbes.gdshader)
// Le voile de toujours (shaders/ecran_voile.gdshader : la nuit, la vignette, la morsure, le givre, la fournaise, l'aube, l'écho,
// la fin, le grain ; et le corps qui faiblit : la faim qui fane le monde par les bords, ses crampes, la santé qui s'en va, au
// bord rouge qui bat avec un cœur lourd), et dans le même passage, sans lire l'image : le poison (un vert malade qui gagne par les bords, en veines
// qui battent avec le cœur), la torpeur (les paupières : deux pans d'ombre, frangés de cils, qui se ferment), les visions (les
// couleurs glissent au bord de l'œil), la voyance (le noir s'ouvre, froid et bleu, dans un iris de givre). Les herbes à zéro,
// l'image est celle du voile de toujours, au même prix. Alpha prémultiplié : il peut assombrir et éclairer.
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
// le corps qui faiblit (scripts/effets.gd, _le_corps) : la faim, une crampe (de 1 à 0), la santé qui s'en va, un coup du cœur lourd
uniform float faim = 0.0;
uniform float crampe = 0.0;
uniform float agonie = 0.0;
uniform float lourd = 0.0;
uniform float aube = 0.0;
uniform float echo = 0.0;
uniform float fin = 0.0;
uniform float noir = 0.0;
uniform float grain = 0.0;
// les herbes (scripts/effets_herbes.gd) : chacune de 0 à 1
uniform float poison = 0.0;
uniform float pouls = 0.0;
uniform float torpeur = 0.0;
uniform float paupiere = 0.0;
uniform float visions = 0.0;
uniform float voyance = 0.0;
uniform vec4 encre : source_color = vec4(0.04, 0.05, 0.094, 1.0);
uniform vec4 ombre : source_color = vec4(0.1, 0.14, 0.25, 1.0);
uniform vec4 sang : source_color = vec4(0.48, 0.11, 0.11, 1.0);
uniform vec4 c_peur : source_color = vec4(0.54, 0.44, 0.84, 1.0);
uniform vec4 c_faim : source_color = vec4(0.6, 0.48, 0.26, 1.0);
uniform vec4 c_froid : source_color = vec4(0.44, 0.53, 0.72, 1.0);
uniform vec4 c_givre : source_color = vec4(0.8, 0.89, 0.97, 1.0);
uniform vec4 c_braise : source_color = vec4(0.93, 0.44, 0.15, 1.0);
uniform vec4 c_aube : source_color = vec4(0.91, 0.73, 0.63, 1.0);
uniform vec4 c_echo : source_color = vec4(0.75, 0.89, 1.0, 1.0);
uniform vec4 c_poison : source_color = vec4(0.45, 0.55, 0.17, 1.0);
uniform vec4 c_voyance : source_color = vec4(0.53, 0.72, 0.95, 1.0);

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
	// (la voyance : la vignette s'écarte, le noir du bord s'allège)
	float ouvre = mix(0.58, 0.16, peur) - coeur * 0.12 + voyance * 0.22;
	float vi = smoothstep(ouvre, ouvre + 0.9, re);
	v = sur(v, encre.rgb, clamp(vi * (0.32 + 0.5 * peur + 0.12 * coeur) * (1.0 - 0.45 * voyance), 0.0, 0.92));
	if (faim > 0.01) {
		// la faim : le monde se fane, et par les bords un creux d'ocre sombre se resserre, en taches lentes ; il respire comme un
		// ventre vide (lentement, pour que l'œil le voie bouger) ; une crampe le serre d'un coup et l'assombrit, puis il se relâche.
		// Sans la passe qui lit l'image, un lavis gris-jaune éteint les couleurs à sa place
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 0.8 + vec2(TIME * 0.006, 0.0)).r * 0.7 + texture(bruit, UV * vec2(ratio, 1.0) * 2.6).r * 0.3;
		float respire = 0.5 + 0.5 * sin(TIME * 2.1);
		float d = re + (n - 0.5) * 0.5 - mix(1.08, 0.5, faim) + (0.05 * respire + 0.26 * crampe) * faim;
		float bord = smoothstep(0.0, 0.38, d);
		v = sur(v, vec3(0.42, 0.37, 0.25), faim * 0.28 * seul);
		v = sur(v, c_faim.rgb * 0.2, faim * 0.07);
		v = sur(v, mix(encre.rgb, c_faim.rgb, 0.38 + 0.3 * n - 0.12 * seul), clamp(bord * (0.5 + 0.42 * faim + 0.08 * seul), 0.0, 0.92));
		// (au ras du creux, un liseré d'ocre clair : on voit où il s'arrête)
		v.rgb += c_faim.rgb * (1.0 - abs(d * 6.0 - 0.6)) * step(0.0, d) * step(d, 0.2) * 0.16 * faim * (1.0 - v.a * 0.5);
		v = sur(v, encre.rgb * 0.7, clamp(crampe * (0.28 + 0.45 * smoothstep(0.1, 1.0, re)), 0.0, 0.68));
	}
	if (agonie > 0.01) {
		// la santé s'en va : le monde s'éloigne dans le noir, le bord rougit et se resserre à chaque coup du cœur lourd
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 0.7 + vec2(0.0, TIME * 0.004)).r;
		float d = re + (n - 0.5) * 0.42 - mix(1.02, 0.46, agonie) + lourd * 0.13 * (0.4 + 0.6 * agonie);
		float bord = smoothstep(0.0, 0.42, d);
		v = sur(v, encre.rgb, clamp(agonie * (0.14 + 0.3 * smoothstep(0.25, 1.1, re)), 0.0, 0.48));
		v = sur(v, vec3(0.42), agonie * 0.14 * seul);
		v = sur(v, sang.rgb * (0.75 + 0.45 * n + 0.45 * lourd), clamp(bord * (0.5 + 0.4 * agonie + 0.2 * lourd), 0.0, 0.94));
		v = sur(v, sang.rgb * 0.8, lourd * agonie * 0.14);
	}
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
		float bord = smoothstep(0.0, 0.26, re + (n - 0.5) * 0.5 - mix(1.12, 0.72, fournaise));
		v = sur(v, c_braise.rgb * 0.8, fournaise * 0.1);
		v = sur(v, c_braise.rgb * (0.5 + 0.5 * n), clamp(bord * (0.28 + 0.5 * fournaise), 0.0, 0.78));
	}
	if (poison > 0.01) {
		// le poison : le vert malade gagne par les bords, en veines qui rampent vers le centre (le bruit, étiré le long du rayon,
		// qui coule) et se gonflent à chaque battement ; au cœur de chaque veine, une encre plus sombre, au bord net. Sans la
		// passe qui lit l'image, un lavis gris-vert éteint les couleurs à sa place
		float tour = atan(c.y, c.x * ratio) * 0.63662;
		float veine = texture(bruit, vec2(tour * 1.5 + 0.3, re * 0.24 - TIME * 0.014)).r;
		float tache = texture(bruit, UV * vec2(ratio, 1.0) * 1.3 + vec2(TIME * 0.011, 0.0)).r;
		float n = veine * 0.62 + tache * 0.38;
		float d = re + (n - 0.5) * 0.72 - mix(1.2, 0.8, poison) + pouls * 0.06;
		float bord = smoothstep(0.0, 0.3, d);
		float net = smoothstep(0.0, 0.03, d - 0.17);
		v = sur(v, vec3(0.34, 0.37, 0.29), poison * 0.17 * seul);
		v = sur(v, c_poison.rgb * 0.5, poison * (0.02 + 0.045 * pouls));
		v = sur(v, c_poison.rgb * (0.4 + 0.55 * n), clamp(bord * (0.3 + 0.36 * poison), 0.0, 0.78));
		v = sur(v, mix(encre.rgb, c_poison.rgb, 0.22), clamp(net * (0.34 + 0.2 * pouls) * poison, 0.0, 0.6));
		// (la nuit, le bord est déjà noir : les veines y luisent un peu, d'une lueur de pourriture)
		v.rgb += c_poison.rgb * bord * (1.0 - net) * (0.1 + 0.08 * pouls) * poison;
	}
	if (visions > 0.01) {
		// les visions : les couleurs glissent au bord de l'œil (deux lueurs qui tournent lentement, jamais au centre), et le noir
		// respire comme une pupille
		float tour = atan(c.y, c.x * ratio);
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 0.7 + vec2(TIME * 0.021, -TIME * 0.013)).r;
		vec3 glisse = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + tour + TIME * 0.45 + n * 5.0);
		float bord = smoothstep(0.3, 1.05, re + (n - 0.5) * 0.45);
		v = sur(v, mix(c_peur.rgb, glisse, 0.55) * 0.55, visions * bord * (0.16 + 0.1 * seul));
		v = sur(v, encre.rgb, visions * smoothstep(0.55, 1.25, re + 0.07 * sin(TIME * 1.7)) * 0.34);
	}
	v = sur(v, encre.rgb * 0.5, noir);
	// ce qui éclaire : ajouté par-dessus (le bleu des noirs la nuit, la lumière de l'aube)
	v.rgb += ombre.rgb * nuit * (1.0 - v.a) + c_aube.rgb * aube * 0.12 * (1.0 - re * 0.6);
	if (voyance > 0.01) {
		// la voyance : une clarté de lune posée sur les noirs, et au bord un iris : des rayons de givre très fins, tournés vers le
		// centre, qui respirent ; un anneau pâle le ferme
		float tour = atan(c.y, c.x * ratio) * 0.63662;
		float rayon = texture(bruit, vec2(tour * 3.0, re * 0.12 + TIME * 0.008)).r;
		float fil = smoothstep(0.56, 0.74, rayon) * smoothstep(0.5, 1.0, re);
		float anneau = 1.0 - smoothstep(0.0, 0.035, abs(re + (rayon - 0.5) * 0.1 - 0.9 - 0.012 * sin(TIME * 0.9)));
		v.rgb += c_voyance.rgb * voyance * (0.075 * (1.0 - 0.6 * re) * (1.0 - v.a) + 0.13 * fil + 0.07 * anneau);
	}
	// le grain : un peu de lumière ici, un peu d'ombre là, qui change à chaque image
	float g = (hache(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + fract(TIME * 7.13) * 311.0) - 0.5) * grain;
	v.rgb += vec3(max(g, 0.0)) * (1.0 - v.a);
	v = sur(v, vec3(0.0), max(-g, 0.0));
	if (paupiere > 0.004 || torpeur > 0.01) {
		// la torpeur : tout s'assourdit, et les paupières tombent. Deux pans d'ombre, celui du haut qui descend, celui du bas qui
		// monte à sa rencontre (ils se joignent un peu sous le milieu) ; leur bord est courbe, comme celui d'un œil, et frangé de
		// cils (le bruit, étiré de haut en bas) ; la chair laisse passer un peu de rouge au ras du bord
		v = sur(v, encre.rgb * 0.7, torpeur * 0.12 + paupiere * 0.3);
		float ouv = 1.0 - paupiere;
		float arc = 1.0 - c.x * c.x * 2.2;
		float cils = texture(bruit, vec2(UV.x * 7.0, 0.37)).r - 0.5;
		float joint = 0.07;
		float y_haut = joint - 1.42 * ouv * arc + cils * 0.035;
		float y_bas = joint + 1.1 * ouv * arc - cils * 0.02;
		float e = 0.035 + 0.05 * ouv;
		float pan = max(1.0 - smoothstep(-e * 0.4, e, c.y - y_haut), smoothstep(-e, e * 0.4, c.y - y_bas));
		float ras = pan * (1.0 - pan) * 4.0;
		v = sur(v, mix(encre.rgb * 0.55, sang.rgb * 0.5, 0.18 + 0.5 * ras), clamp(pan * 0.97, 0.0, 0.97));
	}
	COLOR = v;
}
