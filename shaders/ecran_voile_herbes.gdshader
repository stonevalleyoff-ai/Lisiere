// Lisière — le voile de l'écran, avec ce que les herbes font voir (shaders/ecran_voile_herbes.gdshader)
// Le voile de toujours (shaders/ecran_voile.gdshader : la nuit, la vignette, la morsure, l'aube, l'écho, la fin, le grain), et le
// corps qui faiblit, dessiné comme ce qui arrive à une page de carnet : la peur la froisse, la faim la jaunit et la pique de
// rousseurs, la santé qui s'en va y fait boire de l'encre rouge, le froid y grave un givre de hachures bleues, la chaleur en
// roussit les bords. Et dans le même passage, sans lire l'image : le poison (un vert malade qui gagne par les bords, en veines
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
uniform vec4 encre_bleue : source_color = vec4(0.16, 0.25, 0.48, 1.0);
uniform vec4 papier : source_color = vec4(0.914, 0.875, 0.784, 1.0);
uniform vec4 roussi : source_color = vec4(0.62, 0.46, 0.3, 1.0);
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

// des taches de rousseur (ou des gouttes) : sur une grille, une tache par case, ou pas (densité, de 0 à 1), de taille et de place
// tirées ; le cœur plus foncé que le bord
float rousseurs(vec2 p, float densite) {
	vec2 i = floor(p);
	if (hache(i * 1.7 + 3.1) > densite) {
		return 0.0;
	}
	vec2 o = vec2(hache(i + 11.3), hache(i + 27.9)) * 0.6 + 0.2;
	float r = 0.12 + 0.3 * hache(i + 41.7);
	float d = length(fract(p) - o) / r;
	return (1.0 - smoothstep(0.55, 1.0, d)) * (0.6 + 0.4 * (1.0 - d));
}

// le papier froissé : une page chiffonnée par les bords, le long de plis droits tirés une fois pour toutes (quinze qui partent du
// bord vers le centre, sept en travers) ; chaque pli la penche d'un côté et de l'autre. Rend (xy : la pente de la page sous ce
// point, ses pans plats, ses plis nets ; z : la distance au pli le plus proche ; w : ce pli, une arête (+) ou un creux (-)).
// p : le point, en hauteurs d'écran depuis le centre
vec4 froisse(vec2 p) {
	vec2 g = vec2(0.0);
	float pres = 9.0;
	float cote = 0.0;
	for (int i = 0; i < 22; i++) {
		float fi = float(i);
		vec2 o;
		vec2 nrm;
		if (i < 15) {
			// (un pli qui part du bord vers le centre, à peu près)
			float t = hache(vec2(fi, 1.3)) * 6.2832;
			o = vec2(cos(t) * 0.86, sin(t) * 0.5);
			float a = t + 1.5708 + (hache(vec2(fi, 4.2)) - 0.5) * 0.9;
			nrm = vec2(cos(a), sin(a));
		} else {
			o = (vec2(hache(vec2(fi, 1.3)), hache(vec2(fi, 7.9))) - 0.5) * vec2(1.8, 1.0);
			float a = hache(vec2(fi, 4.2)) * 3.1416;
			nrm = vec2(cos(a), sin(a));
		}
		float amp = (0.4 + 0.6 * hache(vec2(fi, 9.4))) * sign(hache(vec2(fi, 2.6)) - 0.5);
		float e = dot(p - o, nrm);
		g += nrm * amp * clamp(e / 0.002, -1.0, 1.0);
		if (abs(e) < pres) {
			pres = abs(e);
			cote = amp;
		}
	}
	return vec4(g, pres, cote);
}

// une couche de plus, par-dessus les autres (couleur, opacité)
vec4 sur(vec4 dessous, vec3 c, float a) {
	return vec4(c * a + dessous.rgb * (1.0 - a), a + dessous.a * (1.0 - a));
}

void fragment() {
	vec2 c = UV - 0.5;
	float re = length(c) * 1.4142;
	vec2 pp = vec2(c.x * ratio, c.y);
	vec4 v = vec4(0.0);
	v = sur(v, vec3(0.42), fin * 0.3 * seul);
	v = sur(v, c_peur.rgb * 0.3, smoothstep(0.55, 1.0, peur) * 0.14 * seul);
	v = sur(v, c_froid.rgb * 0.35, froid * 0.22);
	v = sur(v, c_echo.rgb * 0.5, echo * 0.12 * seul);
	// (la voyance : la vignette s'écarte, le noir du bord s'allège)
	float ouvre = mix(0.58, 0.3, peur) - coeur * 0.1 + voyance * 0.22;
	float vi = smoothstep(ouvre, ouvre + 0.9, re);
	v = sur(v, encre.rgb, clamp(vi * (0.32 + 0.34 * peur + 0.1 * coeur) * (1.0 - 0.45 * voyance), 0.0, 0.85));
	float effroi = smoothstep(0.35, 1.0, peur);
	if (effroi > 0.01) {
		// la peur : la page se froisse. Par les bords, le papier se chiffonne en pans plats penchés, chacun sa lumière ou son ombre,
		// le long de longs plis droits qui se croisent ; le froissé gagne vers le centre à mesure que la peur monte, et
		// se serre à chaque coup du cœur (la passe qui lit l'image y décale le dessin d'un pan à l'autre). La nuit, les plis
		// prennent la lumière : ils luisent pâles au lieu de se perdre dans le noir
		float n = texture(bruit, pp * 1.2).r;
		float d = re + (n - 0.5) * 0.55 - mix(1.16, 0.58, effroi) + coeur * 0.06;
		float k = smoothstep(-0.08, 0.32, d) * (0.55 + 0.45 * effroi) * (1.0 + 0.45 * coeur);
		vec4 fr = froisse(pp);
		float l = clamp(dot(fr.xy, vec2(-0.6, 0.8)) * 0.36, -1.0, 1.0);
		float pli = 1.0 - smoothstep(0.0012, 0.0032, fr.z);
		float la_nuit = clamp(nuit * 3.2, 0.0, 1.0);
		v = sur(v, papier.rgb * 0.82, clamp(0.12 * k, 0.0, 0.14));
		v = sur(v, encre.rgb, clamp(max(-l, 0.0) * 0.62 * k, 0.0, 0.62));
		v.rgb += papier.rgb * max(l, 0.0) * (0.2 + 0.1 * la_nuit) * k * (1.0 - v.a * 0.4);
		// (le pli : une arête qui prend la lumière, ou un creux d'ombre)
		v.rgb += papier.rgb * pli * step(0.0, fr.w) * (0.26 + 0.1 * coeur) * k;
		v = sur(v, encre.rgb * 0.7, clamp(pli * step(fr.w, 0.0) * (0.5 + 0.15 * coeur) * k, 0.0, 0.6));
	}
	if (faim > 0.01) {
		// la faim : la page jaunit. Par les bords, le papier se teinte d'un jaune sale qui s'avance en auréoles (un liseré plus
		// sombre marque où il s'arrête, comme une tache d'eau séchée), et se pique de taches de rousseur, de plus en plus serrées ;
		// l'encre pâlit (le voile éclaircit les noirs). Une crampe : le jaune avance d'un coup et s'assombrit, la vue se brouille
		float n = texture(bruit, pp * 0.8 + vec2(TIME * 0.004, 0.0)).r * 0.7 + texture(bruit, pp * 2.6).r * 0.3;
		float d = re + (n - 0.5) * 0.55 - mix(1.12, 0.52, sqrt(faim)) + (0.03 * sin(TIME * 1.4) + 0.24 * crampe) * faim;
		float jauni = smoothstep(-0.05, 0.35, d);
		v = sur(v, papier.rgb, faim * (0.1 + 0.16 * seul));
		v = sur(v, mix(papier.rgb, roussi.rgb, 0.45 + 0.35 * n), clamp(jauni * (0.42 + 0.4 * faim), 0.0, 0.85));
		float aureole = (1.0 - smoothstep(0.0, 0.035, abs(d + 0.02))) * smoothstep(0.1, 0.4, faim);
		v = sur(v, roussi.rgb * 0.62, aureole * 0.5);
		float dens = faim * (0.04 + 0.62 * smoothstep(-0.25, 0.3, d));
		float pique = max(rousseurs(pp * 34.0, dens), rousseurs(pp * 15.0 + 5.3, dens * 0.55) * 0.9);
		v = sur(v, roussi.rgb * 0.5, clamp(pique * 0.75, 0.0, 0.75));
		v = sur(v, roussi.rgb * 0.3, clamp(crampe * (0.2 + 0.3 * smoothstep(0.1, 1.0, re)), 0.0, 0.48));
	}
	if (agonie > 0.01) {
		// la santé s'en va : de l'encre rouge boit le papier depuis les bords. Au bord, l'encre pleine ; devant elle, une frange qui
		// a bu le long des fibres (plus claire, déchiquetée) ; à son front, l'encre s'amasse en un liseré sombre ; quelques gouttes
		// tombées plus loin. Elle gonfle à chaque coup du cœur lourd, et le monde, derrière, s'éloigne dans le noir
		float tour = atan(c.y, c.x * ratio) * 0.63662;
		float fib = texture(bruit, vec2(tour * 7.0, re * 1.8)).r;
		float n = texture(bruit, pp * 0.9 + vec2(0.0, TIME * 0.003)).r;
		float d = re + (n - 0.5) * 0.45 + (fib - 0.5) * 0.16 - mix(1.04, 0.48, agonie) + lourd * 0.1 * (0.4 + 0.6 * agonie);
		float plein = smoothstep(0.03, 0.08, d);
		float frange = smoothstep(-0.07, 0.03, d) * (1.0 - plein);
		v = sur(v, encre.rgb, clamp(agonie * (0.1 + 0.26 * smoothstep(0.25, 1.1, re)), 0.0, 0.4));
		v = sur(v, vec3(0.42), agonie * 0.12 * seul);
		v = sur(v, sang.rgb * (1.15 + 0.35 * fib), clamp(frange * (0.38 + 0.25 * fib) * (0.6 + 0.4 * agonie), 0.0, 0.6));
		v = sur(v, sang.rgb * (0.85 + 0.25 * n + 0.3 * lourd), clamp(plein * (0.78 + 0.18 * agonie), 0.0, 0.96));
		float amas = (1.0 - smoothstep(0.0, 0.022, abs(d - 0.045))) * agonie;
		v = sur(v, sang.rgb * 0.45, amas * 0.55);
		float gouttes = rousseurs(pp * 21.0 + 7.1, agonie * 0.32 * smoothstep(0.2, 0.9, re));
		v = sur(v, sang.rgb * 0.8, clamp(gouttes * 1.2, 0.0, 0.88));
	}
	if (blessure > 0.01) {
		float n = texture(bruit, UV * vec2(ratio, 1.0) * 0.9).r;
		// (un bord net, mangé par le bruit : de l'encre, pas un nuage ; il gagne vers le centre au plus fort de la morsure)
		float bord = smoothstep(0.0, 0.04, re + (n - 0.5) * 0.55 - mix(1.05, 0.72, blessure));
		v = sur(v, sang.rgb * 0.7, blessure * 0.22);
		v = sur(v, sang.rgb * (0.6 + 0.4 * n), clamp(bord * (0.35 + 0.6 * blessure), 0.0, 0.92));
	}
	if (givre > 0.01) {
		// le corps a froid : le givre est gravé. Par les bords, des hachures fines d'encre bleue (tous les sept pixels, couchées),
		// cassées comme au burin, qui gagnent vers le centre ; plus près du bord, croisées ; et le papier y bleuit, pâle
		float tour = atan(c.y, c.x * ratio) * 0.63662;
		float n = texture(bruit, vec2(tour * 2.0, re * 0.3)).r * 0.65 + texture(bruit, pp * 2.3).r * 0.35;
		float d = re + (n - 0.5) * 0.55 - mix(1.12, 0.66, givre);
		float zone = smoothstep(0.0, 0.2, d);
		float croise = smoothstep(0.12, 0.34, d);
		vec2 px = FRAGCOORD.xy;
		float l1 = 1.0 - smoothstep(0.07, 0.17, abs(fract(dot(px, vec2(0.574, 0.819)) / 7.0) - 0.5));
		float l2 = 1.0 - smoothstep(0.07, 0.17, abs(fract(dot(px, vec2(-0.866, 0.5)) / 7.0) - 0.5));
		float casse = smoothstep(0.38, 0.58, texture(bruit, px * 0.011).r + zone * 0.25);
		float trait = max(l1 * zone, l2 * croise) * casse;
		v = sur(v, mix(papier.rgb, c_givre.rgb, 0.6), clamp(zone * (0.16 + 0.22 * givre), 0.0, 0.38));
		v = sur(v, encre_bleue.rgb, clamp(trait * (0.5 + 0.35 * givre), 0.0, 0.85));
	}
	if (fournaise > 0.01) {
		// la chaleur accable, ou elle brûle : les bords de la page roussissent, comme approchés d'une flamme. Le papier brunit en
		// s'approchant du bord ; au bord, il est charbonné ; entre les deux, une ligne de braise qui vacille
		float n = texture(bruit, pp * 1.1 + vec2(0.0, TIME * 0.02)).r * 0.7 + texture(bruit, pp * 3.2).r * 0.3;
		float d = re + (n - 0.5) * 0.5 - mix(1.1, 0.68, fournaise);
		float brunit = smoothstep(-0.14, 0.1, d);
		float charbon = smoothstep(0.1, 0.15, d);
		float front = 1.0 - smoothstep(0.0, 0.025, abs(d - 0.105));
		float vacille = 0.6 + 0.4 * sin(TIME * 7.0 + n * 23.0);
		v = sur(v, mix(roussi.rgb, vec3(0.42, 0.22, 0.08), 0.5 + 0.5 * brunit), clamp(brunit * (0.4 + 0.35 * fournaise), 0.0, 0.72));
		v = sur(v, vec3(0.08, 0.055, 0.045), clamp(charbon * 0.92, 0.0, 0.92));
		v.rgb += c_braise.rgb * front * vacille * (0.35 + 0.45 * fournaise);
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
