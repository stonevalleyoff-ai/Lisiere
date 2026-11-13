shader_type canvas_item;
// Lisière — le sol peint (shaders/sol_peint.gdshader)
// La terre du lieu, peinte en coordonnées du monde, dans les couleurs de son biome (monde.gd, couleurs) : de grandes plaques
// (trois bruits lents, cuits une fois dans de petites textures, que le décor lit aussi : decor.gd), où se mêlent la terre, la
// mousse, l'herbe rase, la litière de feuilles mortes (une à une, avec leur ombre), des cailloux ; la neige et le givre s'il fait
// froid, la boue s'il est humide, des fentes s'il est sec. Une clairière de terre battue autour du réveil, là où l'on campe.
// Au-delà du carré jouable, le sol s'enfonce dans le noir du bois. Un grain de papier très léger par-dessus.
// Ce shader ne tourne pas à chaque image : il peint des tuiles, une fois, quand la caméra en approche (scripts/decor_sol.gd).
// (« fin » : les feuilles et les cailloux au pixel, qu'on peut éteindre.)

uniform sampler2D plaques : filter_linear, repeat_enable;
uniform sampler2D taches : filter_linear, repeat_enable;
uniform sampler2D voiles : filter_linear, repeat_enable;
uniform sampler2D motif_a : filter_linear, repeat_enable;
uniform sampler2D motif_b : filter_linear, repeat_enable;
uniform float etendue = 5400.0;
// le monde ouvert (scripts/carte.gd) : une tuile où deux ou trois régions se touchent est peinte en autant de couches. La
// première couvre tout ; les suivantes ne se montrent que là où leur région est la plus proche (sur le plan tordu de la carte)
uniform int couche = 0;
uniform vec2 site_moi = vec2(0.0);
uniform vec2 site_a = vec2(1.0e7);
uniform vec2 site_b = vec2(1.0e7);
uniform vec2 site_c = vec2(1.0e7);
uniform float fondu = 150.0;           // la demi-largeur où deux régions se mêlent
uniform float rive = 0.0;              // 1 : de l'autre côté, c'est l'eau (ou la terre) : un bord net, un trait d'encre
uniform float etendue_eau = 0.0;       // 1 : cette région est de l'eau
uniform vec3 crete = vec3(0.0);        // pour site_a, site_b, site_c : 1 si la frontière avec elle est fermée (une crête de roche)
uniform float lit_ici = 0.0;           // 1 : cette région est une vallée de rivière (son lit suit les zéros de champ)
uniform vec3 eaux = vec3(0.0);         // pour site_a, site_b, site_c : 1 si c'est de l'eau ou une rivière (le lit ne s'amincit pas vers elle)
uniform vec3 c_eau = vec3(0.13, 0.19, 0.24);
// le relief (scripts/carte.gd) : les régions qui comptent autour de la tuile (leur point, la force de leur relief)
uniform vec3 reliefs[6];
uniform float creuses[6];              // pour chacune : 1 si c'est une grotte (de la roche pleine, des salles : scripts/carte.gd)
uniform int n_reliefs = 0;
// (vrai : on ne peint que les parois, transparent ailleurs — le calque posé par-dessus ce que le temps fait au sol, pour que
// la neige ou la crue ne cachent pas un mur : scripts/monde.gd, relief_au_dessus)
uniform bool que_relief = false;

uniform vec3 terre = vec3(0.35, 0.27, 0.19);
uniform vec3 terre_claire = vec3(0.45, 0.36, 0.25);
uniform vec3 terre_sombre = vec3(0.24, 0.19, 0.14);
uniform vec3 mousse = vec3(0.31, 0.42, 0.23);
uniform vec3 mousse_claire = vec3(0.42, 0.52, 0.3);
uniform vec3 herbe = vec3(0.34, 0.42, 0.22);
uniform vec3 litiere_a = vec3(0.55, 0.27, 0.14);
uniform vec3 litiere_b = vec3(0.6, 0.45, 0.22);
uniform vec3 litiere_c = vec3(0.36, 0.25, 0.16);
uniform vec3 caillou = vec3(0.5, 0.48, 0.45);
uniform vec3 neige = vec3(0.88, 0.9, 0.94);
uniform vec3 neige_ombre = vec3(0.6, 0.68, 0.82);
uniform vec3 boue = vec3(0.17, 0.15, 0.13);
uniform vec3 usure = vec3(0.47, 0.39, 0.28);
uniform vec3 encre = vec3(0.086, 0.075, 0.059);
uniform vec3 sous_bois = vec3(0.04, 0.05, 0.05);

uniform float part_mousse = 0.4;
uniform float part_herbe = 0.3;
uniform float part_litiere = 0.4;
uniform float part_cailloux = 0.2;
uniform float part_neige = 0.0;
uniform float part_boue = 0.0;
uniform float part_fentes = 0.0;
uniform float demi = 2100.0;
uniform float clairiere = 250.0;
uniform bool fin = true;

varying vec2 monde;

const vec3 LUMIERE = vec3(-0.5, -0.64, 0.58);
const float COL_ = 0.4;                // au-dessus : un col (scripts/carte.gd, COL)

void vertex() {
	monde = VERTEX;
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// un masque aux bords nets mais tremblés : 1 au-dessus du seuil
float masque(float v, float seuil, float aa) {
	return smoothstep(seuil - aa, seuil + aa, v);
}

// le plan tordu de la carte : le même calcul que scripts/carte.gd (tordre)
vec2 tordre(vec2 p) {
	return vec2(
		420.0 * sin(p.y / 1900.0 + 1.3) + 180.0 * sin(p.y / 730.0 + p.x / 2600.0 + 4.1) + 70.0 * sin(p.y / 260.0 + 0.7),
		420.0 * sin(p.x / 2100.0 + 2.2) + 180.0 * sin(p.x / 810.0 - p.y / 2900.0 + 0.5) + 70.0 * sin(p.x / 290.0 + 3.3));
}

// les rivières : les mêmes calculs que scripts/carte.gd (champ, champ_gue)
float champ(vec2 p) {
	return sin(p.x / 1500.0 + 1.9 * sin(p.y / 2600.0 + 0.4)) + 0.55 * sin(p.y / 1150.0 + 1.1 + 1.4 * sin(p.x / 3100.0));
}

float champ_gue(vec2 p) {
	return sin(p.x / 700.0 + 0.9 * sin(p.y / 1900.0)) * sin(p.y / 830.0 + 1.7);
}

// le relief : les mêmes calculs que scripts/carte.gd (bosses, champ_col)
float bosses(vec2 p) {
	float f = sin((p.x * 0.966 + p.y * 0.259) / 520.0 + 1.6 * sin((p.y * 0.966 - p.x * 0.259) / 1700.0 + 0.4));
	f += sin((p.y * 0.94 - p.x * 0.342) / 610.0 + 1.3 * sin((-p.x * 0.94 - p.y * 0.342) / 2100.0 + 2.1) + 1.7);
	f += 0.7 * sin((p.x * 0.643 - p.y * 0.766) / 330.0 + 1.1 * sin((p.x * 0.766 + p.y * 0.643) / 1300.0 + 4.0) + 0.6);
	f += 0.16 * sin(p.x / 95.0 + 1.2 * sin(p.y / 240.0) + 2.9) * sin(p.y / 110.0 + 0.5);
	return 0.5 + f / 5.72;
}

float champ_col(vec2 p) {
	return sin(p.x / 150.0 + 0.9 * sin(p.y / 900.0)) * sin(p.y / 170.0 + 1.7 + 0.8 * sin(p.x / 1100.0));
}

// les grottes : le même calcul que scripts/carte.gd (cavites)
float cavites(vec2 p) {
	float f = sin((p.x * 0.891 + p.y * 0.454) / 190.0 + 2.2 * sin((p.y * 0.891 - p.x * 0.454) / 600.0 + 0.9));
	f += sin((p.y * 0.966 - p.x * 0.259) / 230.0 + 1.9 * sin((-p.x * 0.966 - p.y * 0.259) / 750.0 + 2.6) + 0.8);
	f += 0.6 * sin((p.x * 0.574 - p.y * 0.819) / 120.0 + 1.6 * sin((p.x * 0.819 + p.y * 0.574) / 480.0 + 3.3) + 2.2);
	f += 0.2 * sin(p.x / 45.0 + 1.1 * sin(p.y / 110.0) + 1.4) * sin(p.y / 52.0 + 2.0);
	return 0.5 + f / 5.6;
}

float salles(vec2 p) {
	return 0.55 + 0.09 * sin(p.x / 700.0 + 1.3 * sin(p.y / 900.0)) * sin(p.y / 650.0 + 0.7);
}

void fragment() {
	vec2 uv = monde / etendue + 0.5;
	float px = max(fwidth(monde.x), 0.3);
	float A = texture(plaques, uv).r;
	float B = texture(taches, uv).r;
	float C = texture(voiles, uv).r;
	// les bruits fins, lus dans deux motifs sans couture à des échelles qui ne tombent pas juste
	float d1 = texture(motif_a, monde / 310.0).r;
	float d2 = texture(motif_b, monde / 97.0 + 0.37).r;
	float d3 = texture(motif_a, monde / 31.0 + 0.71).r;
	float g1 = texture(motif_b, monde / 13.0).r;
	float g2 = texture(motif_a, monde * vec2(1.0 / 40.0, 1.0 / 4.5)).r;
	float aa = 0.018;

	// la clairière du réveil : la terre battue, sans mousse ni litière
	float r0 = length(monde * vec2(1.0, 1.25)) + (d2 - 0.5) * 90.0 + (d3 - 0.5) * 26.0;
	float use = 1.0 - smoothstep(clairiere * 0.8 - 6.0, clairiere * 0.8 + 6.0, r0);
	float pietine = 1.0 - smoothstep(0.0, clairiere * 0.75, r0);

	// la terre, marbrée
	float t = A * 0.45 + d1 * 0.35 + d3 * 0.2;
	vec3 col = mix(terre_sombre, terre, smoothstep(0.25, 0.55, t));
	col = mix(col, terre_claire, smoothstep(0.6, 0.85, t) * 0.7);

	// l'herbe rase, par grandes nappes
	float mh = masque(B * 0.5 + A * 0.25 + d2 * 0.25 + (d3 - 0.5) * 0.12, 1.0 - part_herbe * 0.95 - 0.05, aa * 2.0) * (1.0 - use * 0.85);
	vec3 herbe_ici = herbe * (0.82 + 0.3 * d3) * (0.9 + 0.12 * g1);
	col = mix(col, herbe_ici, mh * 0.9);

	// la mousse : des coussins, plus sombres au bord, piquetés de clair
	float vm = B * 0.45 + d2 * 0.5 + (d3 - 0.5) * 0.07 - 0.025;
	float sm = 1.0 - part_mousse * 0.9 - 0.1;
	float mm = masque(vm, sm, 0.006) * (1.0 - use);
	float bord_m = mm * (1.0 - masque(vm, sm + 0.022, 0.006));
	float coussin = smoothstep(sm, sm + 0.12, vm);
	vec3 mousse_ici = mix(mousse * 0.86, mousse_claire, coussin * 0.55 + smoothstep(0.6, 0.7, g1) * 0.35) * (0.92 + 0.12 * d3);
	col = mix(col, mousse_ici, mm);
	col = mix(col, mousse * 0.58, bord_m * 0.75);

	// la boue, dans les creux
	float mb = masque(1.0 - A * 0.7 - d2 * 0.3 + (d3 - 0.5) * 0.15, 1.0 - part_boue * 0.7, aa) * (1.0 - use * 0.5);
	col = mix(col, boue * (0.85 + 0.25 * g2), mb * 0.92);
	col += vec3(0.05, 0.06, 0.08) * mb * smoothstep(0.7, 0.9, g2) * 0.8;

	// les fentes de la terre sèche
	if (part_fentes > 0.01) {
		vec2 g = monde / vec2(38.0, 30.0);
		vec2 gi = floor(g);
		vec2 gf = fract(g);
		float e1 = 9.0;
		float e2 = 9.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = vec2(float(x), float(y));
				vec2 pt = o + 0.2 + 0.6 * vec2(h21(gi + o), h21(gi + o + 7.7)) - gf;
				float dd = dot(pt, pt);
				if (dd < e1) {
					e2 = e1;
					e1 = dd;
				} else if (dd < e2) {
					e2 = dd;
				}
			}
		}
		float fente = 1.0 - smoothstep(0.0, 0.035 + px * 0.02, sqrt(e2) - sqrt(e1));
		float ou = masque(A * 0.6 + d2 * 0.4, 1.0 - part_fentes * 0.8, 0.04) * (1.0 - mh) * (1.0 - mm);
		col = mix(col, col * 0.55, fente * ou * 0.8);
	}

	// la litière : des feuilles mortes, une à une, chacune avec son ombre, plus serrées sous le couvert
	float ml = clamp((C * 0.55 + A * 0.2 + d2 * 0.25 + (d3 - 0.5) * 0.2 - (1.0 - part_litiere * 0.9 - 0.1)) * 3.0, 0.0, 1.0) * (1.0 - use * 0.95) * (1.0 - mb);
	col = mix(col, col * 0.84, ml * 0.45);
	if (fin && ml > 0.01) {
		for (int k = 0; k < 2; k++) {
			vec2 dec = k == 0 ? vec2(0.0) : vec2(6.7, 4.3);
			vec2 g = (monde + dec) / 14.0;
			vec2 gi = floor(g) + float(k) * 31.0;
			vec2 gf = fract(g);
			if (h21(gi) < ml * 0.62) {
				float ang = h21(gi + 2.3) * 6.2831;
				vec2 c = vec2(0.5) + (vec2(h21(gi + 3.1), h21(gi + 4.9)) - 0.5) * 0.2;
				float L = 0.27 + 0.11 * h21(gi + 5.5);
				float W = L * (0.42 + 0.14 * h21(gi + 6.1));
				float bord = px / 14.0;
				float ca = cos(ang);
				float sa = sin(ang);
				// (l'ombre de la feuille, posée en bas à droite)
				vec2 o = gf - c - vec2(0.03, 0.04);
				o = vec2(o.x * ca + o.y * sa, (-o.x * sa + o.y * ca) * 1.3);
				float xo = o.x / L;
				float ombre = (1.0 - smoothstep(0.85, 1.05, abs(xo))) * (1.0 - smoothstep(W * (1.0 - xo * xo), W * (1.0 - xo * xo) + 0.05, abs(o.y)));
				col = mix(col, col * 0.62, ombre * 0.55);
				vec2 d = gf - c;
				d = vec2(d.x * ca + d.y * sa, (-d.x * sa + d.y * ca) * 1.3);
				float x = d.x / L;
				float largeur = W * (1.0 - x * x);
				float dedans = (1.0 - smoothstep(0.9, 1.0, abs(x))) * (1.0 - smoothstep(largeur - bord, largeur + bord, abs(d.y)));
				float hk = h21(gi + 8.8);
				vec3 f = hk < 0.22 ? litiere_a : (hk < 0.62 ? litiere_b : litiere_c);
				f = mix(f, col, 0.22) * (0.85 + 0.28 * h21(gi + 1.7));
				f *= d.y > 0.0 ? 0.84 : 1.05;
				float nervure = 1.0 - smoothstep(0.0, 0.018 + bord, abs(d.y));
				f = mix(f, f * 0.62, nervure * 0.65 * step(abs(x), 0.85));
				float lisere = smoothstep(largeur - bord * 2.5 - 0.02, largeur, abs(d.y));
				f = mix(f, encre, lisere * 0.45);
				col = mix(col, f, dedans);
			}
		}
	}

	// la neige, en plaques, bleutée sur son bord d'ombre ; le givre, en grains
	float vs = C * 0.55 + A * 0.25 + d2 * 0.2 + (d3 - 0.5) * 0.05;
	float ss = 1.0 - part_neige * 0.9;
	float ms = masque(vs, ss, aa);
	float creux_s = 1.0 - masque(vs, ss + 0.06, aa * 2.0);
	vec3 neige_ici = mix(neige, neige_ombre, creux_s * 0.75 + (1.0 - d3) * 0.15);
	col = mix(col, neige_ici, ms);
	if (part_neige > 0.01) {
		float givre = masque(vs + 0.07, ss, 0.05) * (1.0 - ms) * part_neige;
		col = mix(col, mix(col, neige_ombre, 0.55), givre * 0.4);
		col += vec3(0.18) * step(0.992, h21(floor(monde / 2.0))) * givre;
	}

	// les cailloux, un par case de 22 pixels, quand le sort le veut
	if (fin) {
		vec2 g = monde / 22.0;
		vec2 gi = floor(g);
		vec2 gf = fract(g);
		float dens = part_cailloux * (0.35 + 0.65 * A) * (1.0 + use * 1.5) * (1.0 - ms) * (1.0 - mm * 0.7);
		if (h21(gi + 3.1) < dens) {
			float rr = 0.08 + 0.15 * h21(gi + 9.7);
			vec2 c = vec2(rr) + (1.0 - 2.0 * vec2(rr)) * vec2(h21(gi + 1.3), h21(gi + 5.9));
			vec2 d = (gf - c) / vec2(rr, rr * 0.7);
			float r = length(d);
			float bord = px / (22.0 * rr);
			// l'ombre du caillou, posée en bas à droite
			float o = 1.0 - smoothstep(0.7, 1.25, length(d - vec2(0.3, 0.35)));
			col = mix(col, col * 0.62, o * 0.6);
			float dedans = 1.0 - smoothstep(1.0 - bord, 1.0 + bord, r);
			float l = dot(normalize(vec3(d, sqrt(max(0.0, 1.0 - r * r)) + 0.15)), LUMIERE);
			vec3 pc = caillou * (0.75 + 0.4 * h21(gi + 4.4));
			vec3 pcol = mix(pc * 0.6, pc, smoothstep(-0.05, 0.05, l));
			pcol = mix(pcol, pc * 1.3, smoothstep(0.5, 0.6, l));
			pcol = mix(pcol, encre, smoothstep(0.7, 0.98, r) * 0.7);
			col = mix(col, pcol, dedans);
		}
	}

	// la clairière : la terre battue, plus claire au cœur, piquetée de graviers ; un liseré plus sombre à son bord
	vec3 battue = usure * (0.84 + 0.2 * d3 + 0.08 * pietine) * (0.94 + 0.09 * g2);
	vec2 gc = monde / 3.4;
	vec2 gci = floor(gc);
	float grain_c = 1.0 - smoothstep(0.2, 0.2 + px / 3.4, length(fract(gc) - 0.5 - (vec2(h21(gci + 1.1), h21(gci + 2.2)) - 0.5) * 0.4));
	battue = mix(battue, battue * 0.68, grain_c * step(0.9, h21(gci)) * 0.8);
	col = mix(col, battue, use);
	float bord_c = (1.0 - smoothstep(clairiere * 0.8 + 4.0, clairiere * 0.8 + 22.0, r0)) * (1.0 - use);
	col = mix(col, col * 0.78, bord_c * 0.5);

	// au-delà du lieu, le sol s'enfonce dans le noir
	float e = max(abs(monde.x), abs(monde.y)) - demi;
	float noir = smoothstep(-60.0, 300.0, e + (d2 - 0.5) * 160.0 + (d1 - 0.5) * 120.0);
	col = mix(col, sous_bois, noir * 0.92);
	col = mix(col, sous_bois * 0.5, smoothstep(250.0, 650.0, e));

	// le grain du papier
	col *= 0.965 + 0.05 * g1 + 0.025 * g2;
	// les rides de l'eau : de courts traits clairs, couchés (les lignes de niveau d'un bruit étiré)
	float r1 = texture(motif_a, monde / vec2(1100.0, 170.0)).r + 0.5 * texture(motif_b, monde / vec2(700.0, 120.0) + 0.3).r;
	float rides = (1.0 - smoothstep(0.0, 0.07, abs(fract(r1 * 7.0) - 0.5))) * smoothstep(0.4, 0.6, d2);
	if (etendue_eau > 0.5) {
		// une étendue d'eau : un lavis sombre, par nappes, ses rides
		col = mix(c_eau, c_eau * 1.4 + 0.03, rides * 0.32) * (0.86 + 0.28 * d1);
		col *= 0.965 + 0.05 * g1;
	}
	if (lit_ici > 0.5) {
		// une rivière : son lit, qui s'amincit vers les terres voisines ; plus claire à ses berges et à ses gués
		vec2 ql = monde + tordre(monde);
		float ml = distance(ql, site_moi);
		float mince = 1.0;
		if (eaux.x < 0.5) { mince = min(mince, (distance(ql, site_a) - ml) / 2400.0); }
		if (eaux.y < 0.5) { mince = min(mince, (distance(ql, site_b) - ml) / 2400.0); }
		if (eaux.z < 0.5) { mince = min(mince, (distance(ql, site_c) - ml) / 2400.0); }
		float w = 0.08 * clamp(mince, 0.0, 1.0);
		float fl = champ(monde);
		// (la distance à la berge, en pixels du lieu : positive dans l'eau)
		float pente = max(length(vec2(dFdx(fl), dFdy(fl))) / px, 1.0e-6);
		float berge = (w - abs(fl)) / pente;
		float dans = smoothstep(-1.2, 1.2, berge) * step(1.0e-4, w);
		float gue_ = smoothstep(0.44, 0.56, champ_gue(monde));
		vec3 flot = mix(c_eau * 1.55 + 0.04, c_eau, smoothstep(4.0, 70.0, berge));
		flot = mix(flot, flot * 1.4 + 0.03, rides * 0.35) * (0.88 + 0.24 * d1);
		// le gué : on voit le fond, des galets affleurent
		vec3 fond_gue = mix(c_eau * 2.2 + 0.1, caillou, 0.26) * (0.85 + 0.3 * d3);
		float galets = step(0.955, h21(floor(monde / 9.0))) * 0.5;
		flot = mix(flot, mix(fond_gue, caillou * 1.1, galets), gue_ * 0.85);
		col = mix(col, flot, dans);
		// la berge : un trait d'encre, un liseré clair juste dedans
		col = mix(col, encre, (1.0 - smoothstep(0.8, 3.6, abs(berge))) * 0.72 * step(1.0e-4, w));
		col = mix(col, vec3(0.86, 0.9, 0.92), (1.0 - smoothstep(0.0, 3.0, abs(berge - 7.0 - 3.0 * d2))) * 0.3 * dans);
	}
	vec4 dessus = vec4(0.0);
	if (n_reliefs > 0 && etendue_eau < 0.5) {
		// le relief : la force de la région, mêlée à celles de ses voisines ; la hauteur, ses paliers
		vec2 qr = monde + tordre(monde);
		float d0 = 1.0e9;
		for (int k = 0; k < n_reliefs; k++) {
			d0 = min(d0, distance(qr, reliefs[k].xy));
		}
		float somme = 0.0;
		float poids = 0.0;
		for (int k = 0; k < n_reliefs; k++) {
			float w = max(0.0, 1.0 - (distance(qr, reliefs[k].xy) - d0) / 3000.0);
			w *= w;
			poids += w;
			somme += w * reliefs[k].z;
		}
		float force = somme / max(poids, 1.0e-6);
		float bh = bosses(monde);
		if (force > 0.03 && bh > 0.3) {
			float h = bh + 0.62 * (force - 1.0);
			vec2 gr = vec2(bosses(monde + vec2(4.0, 0.0)) - bosses(monde - vec2(4.0, 0.0)), bosses(monde + vec2(0.0, 4.0)) - bosses(monde - vec2(0.0, 4.0))) / 8.0;
			float lg = length(gr);
			float pente_r = clamp(lg, 0.0005, 0.0012);
			vec2 monte = gr / max(lg, 1.0e-7);
			// (l'étage, et l'écart au palier le plus proche, en pixels : positif du côté haut)
			float etage = 0.0;
			float dp = 1.0e9;
			for (int n = 0; n < 3; n++) {
				float d = (h - (0.4 + 0.27 * float(n))) / pente_r;
				etage += smoothstep(-26.0, 26.0, d);
				if (abs(d) < abs(dp)) {
					dp = d;
				}
			}
			// plus haut, la terre est plus claire, plus minérale
			col = mix(col, caillou * (0.85 + 0.3 * d1), 0.1 * etage) * (1.0 + 0.07 * etage);
			float passe = smoothstep(COL_ - 0.035, COL_ + 0.035, champ_col(monde));
			float bande = 1.0 - smoothstep(26.0 - 1.2, 26.0 + 1.2, abs(dp));
			// (la lumière vient d'en haut à gauche : une pente qui lui tourne le dos est sombre, et porte son ombre à son pied)
			float eclat = dot(-monte, vec2(-0.62, -0.78));
			float ombre_p = smoothstep(-70.0, -26.0, dp) * (1.0 - step(-26.0, dp)) * clamp(-eclat * 1.4, 0.0, 1.0) * (1.0 - passe * 0.7);
			col = mix(col, col * 0.62, ombre_p * 0.5);
			// la pente, dessinée comme sur une carte : la roche, claire ou sombre selon le jour ; un trait d'encre le long de son
			// bord haut ; des barbules qui en descendent, épaisses en haut, effilées vers le pied
			float tp = clamp((dp + 26.0) / 52.0, 0.0, 1.0);
			vec3 roche_p = mix(col, caillou * (0.82 + 0.3 * d3), 0.72) * (1.0 + 0.42 * eclat) * (0.72 + 0.32 * tp);
			// (les barbules suivent la pente à un seizième de tour près : leur rang le long de la paroi reste stable)
			float tour = 6.2831853 / 16.0;
			float aq = (floor(atan(monte.y, monte.x) / tour) + 0.5) * tour;
			float le_long = dot(monde, vec2(-sin(aq), cos(aq))) / 9.0;
			float alea = h21(vec2(floor(le_long), floor(aq * 40.0) + 7.0));
			float demi_b = 0.33 * max(0.0, 1.0 - (1.0 - tp) / (0.4 + 0.55 * alea));
			float barbule = (1.0 - smoothstep(demi_b - 0.07, demi_b + 0.07, abs(fract(le_long) - 0.5))) * step(0.01, demi_b);
			float bord_haut = 1.0 - smoothstep(0.0, 2.6, abs(dp - 24.5));
			vec3 paroi_c = mix(roche_p, encre, max(barbule * 0.8, bord_haut * 0.9));
			paroi_c = mix(paroi_c, encre, (1.0 - smoothstep(0.0, 1.8, abs(dp + 25.0))) * 0.35);
			// un col : la même pente, douce — la terre du lieu à peine éclaircie, de courtes barbules légères, des éboulis
			vec3 rampe = mix(col, usure * (0.9 + 0.2 * d3), 0.35) * (1.0 + 0.12 * eclat);
			float courte = (1.0 - smoothstep(demi_b * 0.5 - 0.05, demi_b * 0.5 + 0.05, abs(fract(le_long * 0.5) - 0.5))) * step(0.01, demi_b) * step(0.5, tp);
			rampe = mix(rampe, encre, courte * 0.3);
			vec2 ge = monde / 7.0;
			vec2 gei = floor(ge);
			float eboulis = step(0.9, h21(gei)) * (1.0 - smoothstep(0.2, 0.3, length(fract(ge) - 0.5 - (vec2(h21(gei + 1.7), h21(gei + 5.3)) - 0.5) * 0.4)));
			rampe = mix(rampe, caillou * 1.08, eboulis * 0.8);
			vec3 avec = mix(col, mix(paroi_c, rampe, passe), bande);
			// (par-dessus la neige, la boue, l'eau d'une crue : la paroi entière ; d'un col, ses barbules et un voile)
			dessus = vec4(mix(paroi_c, mix(rampe, encre, courte * 0.5), passe), bande * mix(1.0, 0.3 + 0.5 * courte, passe));
			// (le plateau, juste au bord : un liseré clair du côté du jour)
			avec = mix(avec, avec * 1.2 + 0.03, (1.0 - smoothstep(0.0, 3.0, abs(dp - 30.0))) * clamp(eclat, 0.0, 1.0) * 0.55 * (1.0 - passe));
			col = avec;
		}
	}
	if (n_reliefs > 0) {
		// une grotte : le creux (0 dehors, 1 au cœur), la roche pleine là où le champ des cavités passe son seuil
		vec2 qg = monde + tordre(monde);
		float dg = 1.0e9;
		for (int k = 0; k < n_reliefs; k++) {
			dg = min(dg, distance(qg, reliefs[k].xy));
		}
		float somme_g = 0.0;
		float poids_g = 0.0;
		for (int k = 0; k < n_reliefs; k++) {
			float w = max(0.0, 1.0 - (distance(qg, reliefs[k].xy) - dg) / 1600.0);
			w *= w;
			poids_g += w;
			somme_g += w * creuses[k];
		}
		float creux = somme_g / max(poids_g, 1.0e-6);
		if (creux > 0.5) {
			float seuil_g = mix(0.24, salles(monde), smoothstep(0.8, 0.985, creux)) + 1.0 - smoothstep(0.5, 0.566, creux);
			float sg = cavites(monde) - seuil_g;
			// (l'enfoncement dans la roche, en pixels du lieu : positif dedans)
			float pente_g = max(length(vec2(dFdx(sg), dFdy(sg))) / px, 0.0004);
			float eg = sg / pente_g;
			float roc = smoothstep(-1.0, 1.0, eg);
			// le sol d'une grotte s'assombrit vers ses parois ; la roche : un bord éclairé par endroits, fendu, puis le noir du plein
			col = mix(col, col * 0.55, (1.0 - smoothstep(0.0, 46.0, -eg)) * (1.0 - roc) * 0.6);
			vec3 bord_g = mix(caillou * 0.5, caillou * 0.95, smoothstep(0.3, 0.7, d3)) * (0.8 + 0.3 * d1);
			float fentes_g = 1.0 - smoothstep(0.0, 0.07, abs(fract(d1 * 5.0 + d2 * 2.5) - 0.5));
			bord_g = mix(bord_g, encre, fentes_g * 0.5);
			vec3 plein_g = mix(bord_g, encre * (0.55 + 0.25 * d2), smoothstep(6.0, 24.0, eg));
			plein_g = mix(plein_g, encre, (1.0 - smoothstep(0.0, 2.4, abs(eg - 1.5))) * 0.85);
			col = mix(col, plein_g, roc);
			dessus = mix(dessus, vec4(plein_g, 1.0), roc);
		}
	}
	if (crete.x + crete.y + crete.z > 0.5) {
		// une crête : une bande de roche nue, fendue, de part et d'autre de la frontière (là où scripts/carte.gd retient les pas)
		vec2 qc = monde + tordre(monde);
		float mc = distance(qc, site_moi);
		float ec = 1.0e9;
		if (crete.x > 0.5) { ec = min(ec, abs(distance(qc, site_a) - mc)); }
		if (crete.y > 0.5) { ec = min(ec, abs(distance(qc, site_b) - mc)); }
		if (crete.z > 0.5) { ec = min(ec, abs(distance(qc, site_c) - mc)); }
		float bande = 1.0 - smoothstep(120.0, 230.0, ec + (d2 - 0.5) * 110.0);
		vec3 roche = mix(caillou * 0.42, caillou * 0.8, smoothstep(0.35, 0.65, d3)) * (0.8 + 0.35 * d1);
		float fentes_r = 1.0 - smoothstep(0.0, 0.06, abs(fract(d1 * 5.0 + d2 * 2.5) - 0.5));
		roche = mix(roche, encre, fentes_r * 0.55);
		col = mix(col, roche, bande * 0.92);
	}
	float alpha = 1.0;
	if (couche > 0) {
		vec2 q = monde + tordre(monde);
		float moi = distance(q, site_moi);
		float eux = min(distance(q, site_a), min(distance(q, site_b), distance(q, site_c)));
		// (la frontière tremble : deux régions se mêlent par taches ; une rive est nette)
		float f = mix(fondu, 5.0, rive);
		float e2 = eux - moi + (d2 - 0.5) * 2.2 * f * (1.0 - rive) + (d1 - 0.5) * 1.2 * f * (1.0 - rive);
		alpha = smoothstep(-f, f, e2);
		col = mix(col, encre, rive * (1.0 - smoothstep(2.0, 9.0, abs(e2))) * 0.75);
		col = mix(col, vec3(0.86, 0.9, 0.92), rive * etendue_eau * (1.0 - smoothstep(0.0, 6.0, abs(e2 - 22.0))) * 0.3);
	}
	COLOR = que_relief ? dessus : vec4(col, alpha);
}
