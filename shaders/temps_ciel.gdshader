// Lisière — le voile du temps (shaders/temps_ciel.gdshader)
// Ce que le temps met entre l'œil et le lieu, sur tout l'écran, sans lire l'image (scripts/ciel.gd) : le ciel qui s'assombrit
// (l'ombre des nuages passe sur le lieu, poussée par le vent), les rideaux de la pluie, le brouillard (des nappes qui dérivent,
// épaisses au loin : on ne voit bien qu'autour de soi, et dans la lumière d'un feu), le voile de la neige, la lumière écrasée
// de la canicule, l'éclat de la foudre. Les nappes sont lues en coordonnées du lieu : elles restent où elles sont quand on marche.
// Alpha prémultiplié : il assombrit et il éclaire.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D bruit : filter_linear, repeat_enable;
uniform vec2 centre = vec2(0.0);       // le milieu de l'écran, dans le lieu
uniform vec2 vue = vec2(948.0, 533.0); // ce qu'on voit du lieu, en pixels du lieu
uniform vec2 joueur = vec2(0.0);
uniform vec2 derive = vec2(0.0);       // ce que le vent a poussé
uniform vec2 chute = vec2(0.2, 1.0);   // le sens de la pluie, à l'écran
uniform float temps = 0.0;
uniform float jour = 1.0;
uniform float sombre = 0.0;
uniform float brouillard = 0.0;
uniform float pluie = 0.0;
uniform float neige = 0.0;
uniform float chaleur = 0.0;
uniform float eclat = 0.0;
uniform vec4 feu0 = vec4(0.0);         // xy : où, z : le rayon, w : la force (0 : rien)
uniform vec4 feu1 = vec4(0.0);
uniform vec4 torche = vec4(0.0);
uniform vec4 c_orage : source_color = vec4(0.07, 0.09, 0.16, 1.0);
uniform vec4 c_pluie : source_color = vec4(0.6, 0.66, 0.74, 1.0);
uniform vec4 c_brume : source_color = vec4(0.85, 0.84, 0.8, 1.0);
uniform vec4 c_brume_nuit : source_color = vec4(0.16, 0.2, 0.3, 1.0);
uniform vec4 c_neige : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform vec4 c_chaleur : source_color = vec4(1.0, 0.9, 0.66, 1.0);
uniform vec4 c_feu : source_color = vec4(0.97, 0.66, 0.35, 1.0);
uniform vec4 c_eclat : source_color = vec4(0.9, 0.94, 1.0, 1.0);

// une couche de plus, par-dessus les autres (couleur, opacité)
vec4 sur(vec4 dessous, vec3 c, float a) {
	return vec4(c * a + dessous.rgb * (1.0 - a), a + dessous.a * (1.0 - a));
}

float lueur(vec4 l, vec2 p) {
	if (l.w <= 0.0) {
		return 0.0;
	}
	return l.w * clamp(1.0 - length(p - l.xy) / max(l.z, 1.0), 0.0, 1.0);
}

void fragment() {
	vec2 p = centre + (UV - 0.5) * vue;         // ce pixel, dans le lieu
	float clair = mix(0.3, 1.0, jour);          // (la nuit, ce qui est pâle l'est moins)
	float n = texture(bruit, (p + derive) / 1100.0).r;
	vec4 v = vec4(0.0);

	// le ciel s'assombrit : l'ombre des nuages, inégale, qui passe
	if (sombre > 0.01) {
		v = sur(v, c_orage.rgb, clamp(sombre * (0.76 + 0.48 * n), 0.0, 0.8));
	}

	// la pluie : des rideaux plus serrés qui traversent, étirés dans le sens de la chute
	if (pluie > 0.03) {
		vec2 d = normalize(chute);
		vec2 q = (UV - 0.5) * vue;
		float rideau = texture(bruit, vec2(dot(q, vec2(d.y, -d.x)) / 560.0 + temps * 0.23, dot(q, d) / 2400.0 - temps * 0.55)).r;
		v = sur(v, c_pluie.rgb * clair, pluie * (0.05 + 0.1 * smoothstep(0.4, 0.85, rideau)));
	}

	// la neige : un voile blanc, plus épais au loin
	if (neige > 0.03) {
		float r = length(p - joueur);
		v = sur(v, c_neige.rgb * clair, neige * (0.05 + 0.2 * smoothstep(170.0, 560.0, r + (n - 0.5) * 200.0)));
	}

	// le brouillard : des nappes qui dérivent ; on ne voit bien qu'autour de soi
	if (brouillard > 0.01) {
		float n2 = texture(bruit, (p * vec2(1.0, 1.7) + derive * 1.6) / 420.0 + 0.3).r;
		float nb = n * 0.55 + n2 * 0.45;
		float r = length((p - joueur) * vec2(1.0, 1.2)) + (nb - 0.5) * 210.0;
		float voit = mix(440.0, 165.0, brouillard);
		float loin = smoothstep(voit * 0.5, voit * 1.55, r);
		// (des nappes aux bords nets, l'une sur l'autre : un lavis, pas un nuage)
		float nappes = 0.1 + 0.16 * smoothstep(0.4, 0.44, nb) + 0.14 * smoothstep(0.55, 0.58, nb);
		float a = brouillard * mix(nappes, 0.74 + 0.5 * nappes, loin);
		// la lumière d'un feu perce la brume, et la dore
		float l = min(1.0, lueur(feu0, p) + lueur(feu1, p) + lueur(torche, p));
		a *= 1.0 - 0.5 * l;
		vec3 cb = mix(c_brume_nuit.rgb, c_brume.rgb, jour) + c_feu.rgb * l * 0.3 * (1.0 - jour);
		v = sur(v, cb, clamp(a, 0.0, 0.92));
	}

	// la canicule : la lumière écrase tout, les ombres se vident, les bords de la vue brûlent
	if (chaleur > 0.01) {
		float c = chaleur * jour;
		float re = length(UV - 0.5) * 1.4142;
		v = sur(v, c_chaleur.rgb, c * (0.13 + 0.05 * n + 0.2 * re * re));
		v.rgb += c_chaleur.rgb * c * 0.13;
	}

	// l'éclat de la foudre
	if (eclat > 0.0) {
		v = sur(v, c_eclat.rgb, eclat);
	}
	COLOR = v;
}
