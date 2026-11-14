shader_type canvas_item;
// Lisière — une empreinte dans le sol (shaders/empreinte.gdshader ; scripts/traces.gd en fait un maillage)
// Pas une image posée sur le sol : un creux. La forme du pied est calculée ici (des coussinets, des doigts, des griffes, un
// sabot fendu), avec la terre refoulée en bourrelet autour ; on en tire une pente, et la lumière fait le reste : la paroi
// tournée vers elle s'éclaire, l'autre est dans l'ombre, le fond est sombre de terre fraîche. Le jour, c'est le soleil ; la
// nuit, le feu ou la torche les plus proches (l'empreinte tourne son ombre quand la veilleuse passe avec sa torche).
// Sous la pluie le creux se remplit, du fond vers les bords, de la même eau que les flaques du lieu : un lavis de sépia, à plat,
// cerné d'encre, où les gouttes font des ronds ; près d'un feu, ses reflets en prennent la couleur.
// Dans la neige, le creux est bleu et son bord blanc ; dans l'herbe ou la litière, pas de bourrelet : des brins couchés.
// Une empreinte vieillit : ses bords s'émoussent, le fond se comble, puis elle s'efface.
// Chaque sommet porte ce qu'il faut (traces.gd) :
//   COLOR : r l'eau (0 à 1), g l'âge (0 fraîche, 1 effacée), b le sol (jusqu'à 0,5 : la part d'herbe, de mousse, de litière ;
//           au-dessus de 0,55 : la neige), a la profondeur (le poids de la bête, son allure)
//   UV    : x = 4 × le genre + 1 + u ; y = 4 × le cap (en 64es de tour) + 1 + v

uniform float jour = 1.0;                       // de 0 (la nuit) à 1 (le plein jour)
uniform vec2 soleil = vec2(-0.56, -0.83);       // d'où vient la lumière du ciel, dans le lieu
uniform vec4 feux[4];                           // les lumières proches : xy où, z jusqu'où, w leur force
uniform vec3 lueur = vec3(1.0, 0.62, 0.3);      // la couleur d'un feu, dans l'eau
uniform vec3 flaque = vec3(0.22, 0.2, 0.19);    // l'eau d'une flaque : un lavis de sépia (les tons de shaders/temps_sol.gdshader)
uniform vec3 reflet = vec3(0.75, 0.82, 0.88);
uniform vec3 encre = vec3(0.086, 0.075, 0.059);
uniform float pluie = 0.0;
uniform vec3 terre_ombre = vec3(0.06, 0.045, 0.035);
uniform vec3 terre_claire = vec3(1.0, 0.93, 0.78);
uniform vec3 neige_ombre = vec3(0.4, 0.49, 0.66);
uniform vec3 herbe_ombre = vec3(0.07, 0.085, 0.045);

varying vec2 monde;
varying vec4 donnees;

void vertex() {
	monde = VERTEX;
	donnees = COLOR;
}

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hasard(i), hasard(i + vec2(1.0, 0.0)), f.x), mix(hasard(i + vec2(0.0, 1.0)), hasard(i + vec2(1.0, 1.0)), f.x), f.y);
}

// un lobe : 1 au cœur, 0 au bord, négatif dehors (une ellipse, tournée de « a »)
float lobe(vec2 q, vec2 c, vec2 r, float a) {
	vec2 d = q - c;
	float co = cos(a);
	float si = sin(a);
	d = vec2(co * d.x + si * d.y, -si * d.x + co * d.y);
	return 1.0 - length(d / r);
}

// le pied, dans son repère (x vers l'avant) : x, sa profondeur (0 à 1) ; y, ce qui en est le dedans (pour le bourrelet)
vec2 pied(vec2 q, float genre, float mou, float pese) {
	float dedans = -9.0;
	float fond = 0.0;
	float bord = mix(0.2, 0.5, mou);
	if (genre < 0.5 || (genre > 1.5 && genre < 2.5) || genre > 4.5) {
		// des coussinets (0), ceux de la Noire (2, plus larges, de longues griffes), avec des griffes (5)
		float gros = (genre > 1.5 && genre < 2.5) ? 1.14 : 1.0;
		float l = max(lobe(q, vec2(-0.2, 0.0), vec2(0.27, 0.31) * gros, 0.0),
			max(lobe(q, vec2(-0.36, 0.17), vec2(0.17, 0.16) * gros, 0.0), lobe(q, vec2(-0.36, -0.17), vec2(0.17, 0.16) * gros, 0.0)));
		dedans = l;
		fond = smoothstep(0.0, bord, l);
		for (int i = 0; i < 4; i++) {
			float cote = (i < 2) ? 1.0 : -1.0;
			bool dehors = (i == 0 || i == 2);
			vec2 c = dehors ? vec2(0.27, 0.37 * cote) : vec2(0.45, 0.135 * cote);
			float a = (dehors ? 0.42 : 0.12) * cote;
			float d = lobe(q, c * gros, vec2(0.165, 0.118) * gros, a);
			dedans = max(dedans, d);
			fond = max(fond, 0.92 * smoothstep(0.0, bord, d));
			if (genre > 1.5) {
				// la griffe : une entaille étroite, en avant du doigt
				float longue = (genre < 2.5) ? 0.2 : 0.1;
				vec2 g = c * gros + vec2(cos(a), sin(a)) * (0.19 * gros + longue);
				float e = lobe(q, g, vec2(longue, 0.042), a);
				fond = max(fond, 0.7 * smoothstep(0.0, 0.8, e));
			}
		}
	} else if (genre < 1.5) {
		// un pied d'oiseau : trois doigts devant, un derrière, fins
		for (int i = 0; i < 4; i++) {
			float a = (i == 0) ? 0.0 : ((i == 1) ? 0.62 : ((i == 2) ? -0.62 : 3.14159));
			float lg = (i == 3) ? 0.22 : 0.38;
			float d = lobe(q, vec2(-0.08, 0.0) + vec2(cos(a), sin(a)) * lg, vec2(lg, 0.062), a);
			dedans = max(dedans, d);
			fond = max(fond, 0.85 * smoothstep(0.0, bord, d));
		}
		float d = lobe(q, vec2(-0.08, 0.0), vec2(0.11, 0.11), 0.0);
		dedans = max(dedans, d);
		fond = max(fond, smoothstep(0.0, bord, d));
	} else if (genre < 3.5) {
		// un sabot fendu : deux moitiés en amande, pointues devant ; les ergots derrière, quand la bête pèse ou court
		for (int i = 0; i < 2; i++) {
			float cote = (i == 0) ? 1.0 : -1.0;
			vec2 d2 = q - vec2(0.03, 0.2 * cote);
			float large = 0.19 * (1.0 - 0.55 * smoothstep(0.0, 0.55, d2.x));
			d2.y -= 0.05 * cote * smoothstep(0.0, 0.5, d2.x);
			float d = 1.0 - length(d2 / vec2(0.52, large));
			dedans = max(dedans, d);
			fond = max(fond, smoothstep(0.0, bord, d));
			float e = lobe(q, vec2(-0.66, 0.23 * cote), vec2(0.075, 0.062), 0.0);
			fond = max(fond, 0.6 * smoothstep(0.0, bord, e) * smoothstep(0.6, 0.85, pese));
		}
	} else {
		// une main : une paume, cinq doigts longs
		float l = lobe(q, vec2(-0.2, 0.0), vec2(0.24, 0.25), 0.0);
		dedans = l;
		fond = smoothstep(0.0, bord, l);
		for (int i = 0; i < 5; i++) {
			float a = (float(i) - 2.0) * 0.46;
			float lg = (i == 0 || i == 4) ? 0.17 : 0.23;
			float d = lobe(q, vec2(-0.14, 0.0) + vec2(cos(a), sin(a)) * (0.3 + lg), vec2(lg, 0.058), a);
			dedans = max(dedans, d);
			fond = max(fond, 0.85 * smoothstep(0.0, bord, d));
		}
	}
	return vec2(fond, dedans);
}

// sa hauteur : le creux, et le bourrelet de terre refoulée autour
float hauteur(vec2 q, float genre, float mou, float pese, float profond, float bourrelet) {
	vec2 p = pied(q, genre, mou, pese);
	float tour = smoothstep(-0.4, -0.13, p.y) * (1.0 - smoothstep(-0.13, 0.03, p.y));
	return -p.x * profond + 0.2 * tour * bourrelet;
}

void fragment() {
	float genre = floor(UV.x * 0.25);
	float tour64 = floor(UV.y * 0.25);
	vec2 uv = vec2(UV.x - 4.0 * genre - 1.0, UV.y - 4.0 * tour64 - 1.0);
	float cap = tour64 * 6.2831853 / 64.0;
	float eau = donnees.r;
	float age = donnees.g;
	float neige = step(0.55, donnees.b);
	float couvert = (1.0 - neige) * clamp(donnees.b * 2.0, 0.0, 1.0);
	float mou = smoothstep(0.2, 1.0, age);
	// (dans l'herbe, la neige tassée : un creux moins franc, plus net dans la neige)
	float profond = donnees.a * (1.0 - 0.45 * mou) * (1.0 - 0.45 * couvert);
	float bourrelet = donnees.a * (1.0 - 0.6 * mou) * (1.0 - couvert) * (1.0 + 0.5 * neige);
	// (aucune n'est tout à fait pareille : la terre cède de travers)
	vec2 q = (uv * 2.0 - 1.0) * 1.32;
	q += 0.05 * (vec2(bruit(monde * 0.19), bruit(monde * 0.19 + 7.3)) - 0.5);
	float pese = donnees.a;
	vec2 p = pied(q, genre, mou, pese);
	float tour = smoothstep(-0.4, -0.13, p.y) * (1.0 - smoothstep(-0.13, 0.03, p.y));
	float h = -p.x * profond + 0.2 * tour * bourrelet;
	float e = 0.045;
	vec2 pente = vec2(hauteur(q + vec2(e, 0.0), genre, mou, pese, profond, bourrelet) - h, hauteur(q + vec2(0.0, e), genre, mou, pese, profond, bourrelet) - h) / e;
	// la pente, dans le lieu
	float co = cos(cap);
	float si = sin(cap);
	vec2 pm = vec2(co * pente.x - si * pente.y, si * pente.x + co * pente.y);
	vec3 n = normalize(vec3(-pm * 0.85, 1.0));
	// d'où vient la lumière : le ciel, le jour ; la nuit, les feux proches
	vec2 vers = vec2(0.0);
	float poids = 0.0;
	for (int i = 0; i < 4; i++) {
		if (feux[i].z > 1.0) {
			vec2 d = feux[i].xy - monde;
			float w = clamp(1.0 - length(d) / feux[i].z, 0.0, 1.0) * feux[i].w;
			vers += normalize(d + vec2(0.001)) * w;
			poids += w;
		}
	}
	float au_feu = clamp(poids * 1.6, 0.0, 1.0) * (1.0 - jour);
	vec2 l2 = normalize(mix(soleil, vers / max(poids, 0.0001), au_feu));
	// (la nuit, loin de tout feu : presque plus de relief, la lune seule)
	float relief = mix(0.3, 1.0, max(jour, au_feu));
	vec3 lum = normalize(vec3(l2 * 0.78, 0.63));
	float pris = (dot(n, lum) - lum.z) * 2.3 * relief;
	float grain = 0.82 + 0.36 * bruit(monde * 1.9);
	// (le fond : de la terre fraîche, sombre et à plat ; la paroi du côté de la lumière : dans l'ombre ; celle d'en face : éclairée)
	float ombre = clamp((p.x * profond * mix(0.52, 0.26, mou) + max(-pris, 0.0) * 0.5) * grain, 0.0, 0.82);
	float clair = clamp(max(pris, 0.0) * 0.42, 0.0, 0.5) * (1.0 - 0.75 * couvert);
	vec3 sombre = mix(mix(terre_ombre, herbe_ombre, couvert), neige_ombre, neige);
	vec3 col = mix(sombre, mix(terre_claire, vec3(1.0), neige), clair / (clair + ombre + 0.0001));
	float a = max(ombre, clair);
	// l'eau : elle monte du fond ; à ras bord, elle déborde un peu sur le bourrelet. Peinte comme les flaques du lieu
	// (shaders/temps_sol.gdshader) : un lavis de sépia, à plat, plus sombre à son bord où le pigment se dépose ; un peu de ciel
	// en son milieu ; de courts traits clairs, couchés ; les ronds des gouttes quand il pleut.
	if (eau > 0.02) {
		float seuil = mix(0.98, 0.05, eau);
		float nappe = smoothstep(seuil, seuil + 0.09, p.x);
		nappe = max(nappe, smoothstep(-0.45, -0.18, p.y) * smoothstep(0.86, 1.0, eau));
		// (la berge : la terre gorgée, autour)
		a = max(a, 0.3 * eau * smoothstep(-0.5, -0.1, p.y) * (1.0 - nappe));
		vec3 renvoi = mix(reflet, lueur, au_feu * 0.7) * mix(0.55, 1.0, max(jour, au_feu));
		vec3 c_eau = flaque;
		float a_eau = 0.74;
		// (son milieu renvoie un peu le ciel)
		float milieu = smoothstep(seuil + 0.2, seuil + 0.55, p.x);
		c_eau = mix(c_eau, mix(renvoi, flaque * 2.2, 0.45), milieu * 0.16);
		// (des reflets : de courts traits clairs, couchés dans le lieu, pas dans le sens du pied)
		float rang = monde.y * 0.3 + bruit(vec2(monde.x * 0.06, floor(monde.y * 0.3))) * 0.8;
		float trait = (1.0 - smoothstep(0.1, 0.34, abs(fract(rang) - 0.5))) * step(0.56, bruit(vec2(monde.x * 0.11 + 9.0, floor(rang) * 3.7)));
		c_eau = mix(c_eau, renvoi, trait * milieu * 0.4);
		// (le dépôt : un cerne d'encre à son bord)
		float bord_eau = nappe * (1.0 - nappe) * 4.0;
		c_eau = mix(c_eau, encre * 1.3, bord_eau * 0.5);
		// les ronds des gouttes : un rond couché qui s'élargit, par case du lieu
		if (pluie > 0.02) {
			vec2 g = monde / 15.0;
			vec2 gi = floor(g);
			vec2 gf = fract(g);
			float hh = hasard(gi);
			float t = TIME * (1.2 + 0.7 * hh) + hh * 9.0;
			float k = floor(t);
			float u = fract(t);
			if (hasard(gi + k * 0.71 + 13.0) < pluie * 0.9) {
				vec2 c = 0.3 + 0.4 * vec2(hasard(gi + k * 1.37), hasard(gi - k * 2.11 + 4.7));
				float r = length((gf - c) * vec2(1.0, 1.6)) * 15.0;
				float rond = (1.0 - smoothstep(0.0, 1.0, abs(r - u * 5.0))) * (1.0 - u) * (1.0 - u);
				c_eau = mix(c_eau, renvoi, rond * 0.6);
			}
		}
		col = mix(col, c_eau, nappe);
		a = mix(a, a_eau, nappe);
	}
	// (elle s'efface : la fin de son âge)
	a *= 1.0 - smoothstep(0.86, 1.0, age);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
