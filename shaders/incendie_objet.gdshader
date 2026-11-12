shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Lisière — ce qui brûle (shaders/incendie_objet.gdshader)
// La matière d'un arbre, d'un sapin, d'un buisson, d'une touffe, d'une souche tant qu'ils sont en feu (scripts/objet.gd la pose
// à la place de la végétation, scripts/incendie_flammes.gd la règle) : la même peinture que les feuillages
// (shaders/vegetation_feuillage.gdshader : trois tons, les mêmes modes dans les UV, le même vent), que le feu mange. Les
// feuilles roussissent, puis un bord de braise les troue et les emporte ; l'écorce noircit et se fend de rouge ; et les pans de
// flammes que l'objet ajoute à son dessin (UV autour de 23) brûlent à sa taille : un corps de flammes sur une couronne, une
// langue sur un sapin, un feu qui court au sol à son pied. Tout dans le dessin de l'objet lui-même : pas un appel de dessin de
// plus, et l'arbre en feu reste à sa place parmi les autres (derrière ce qui est devant lui).
// Elle ne reçoit pas de lumière (unshaded) : elle pose elle-même l'obscurité du lieu (obscur) sur ce qui n'est pas encore
// flamme, et la lueur de son propre feu. Chaque objet retrouve son feu par son pied (foyers).
//   UV autour de 23 : un pan de flammes (x de -1 à 1 en travers, y de 0 au pied à 1 en haut) ; sa couleur dit sa graine (r),
//                     sa sorte (g : 0 une langue, 0,5 un corps rond, 1 un feu au sol), sa hauteur en pixels / 256 (b)
//   UV à 27         : l'encre posée sur un feuillage (elle part avec lui) ; autour de 31 : un dôme qui part aussi (une baie)
//   UV à 35         : du charbon (une souche calcinée) : il rougeoie tant qu'il est chaud

#include "res://shaders/vegetation_vent.gdshaderinc"

uniform float temps = 0.0;                          // l'horloge du vent des feuillages (monde.gd)
uniform bool simple = false;
uniform sampler2D bruit : repeat_enable, filter_linear;
uniform vec4 foyers[32];                            // xy : le pied ; z : où en est le feu (0 à 1 ; de 1 à 2, la souche refroidit) ; w : la force des flammes
uniform int combien = 0;
uniform float t = 0.0;                              // l'horloge des flammes
uniform vec2 vent = vec2(0.0);                      // où penche le feu (climat.vent_dir * climat.vent)
uniform vec4 obscur : source_color = vec4(1.0);     // la couleur du monde à cette heure (le CanvasModulate)
uniform float opacite = 0.5;                        // ce que la flamme cache de ce qui est derrière
uniform vec4 rouge : source_color = vec4(0.77, 0.27, 0.16, 1.0);
uniform vec4 braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);
uniform vec4 coeur : source_color = vec4(1.0, 0.85, 0.54, 1.0);
uniform vec4 charbon : source_color = vec4(0.09, 0.075, 0.06, 1.0);
uniform vec4 roux : source_color = vec4(0.35, 0.2, 0.1, 1.0);

varying vec2 v_local;
varying vec2 v_pied;
varying vec2 v_feu;      // (où en est le feu, la force des flammes)

const vec3 LUMIERE = vec3(-0.5, -0.64, 0.58);

void vertex() {
	v_local = VERTEX;
	v_pied = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	v_feu = vec2(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= combien) {
			break;
		}
		vec2 d = foyers[i].xy - v_pied;
		if (dot(d, d) < 2.0) {
			v_feu = foyers[i].zw;
			break;
		}
	}
	if (UV.x > 21.5 && UV.x < 24.5) {
		// un pan de flammes : il penche au vent, d'autant plus qu'il monte ; le vent qui vient vers nous le couche, il paraît plus court
		float y = UV.y - 23.0;
		float h = COLOR.b * 256.0;
		VERTEX += vec2(vent.x * 0.55, vent.y * 0.22) * h * y * y;
	} else {
		float h = max(0.0, -VERTEX.y);
		float k = smoothstep(4.0, 70.0, h) * (0.45 + h / 110.0);
		if (k > 0.0) {
			float phase = vent_hash(floor(v_pied * 0.37)) * 6.2831;
			VERTEX += vent_pli(v_pied, temps, phase) * k * 2.6;
		}
	}
}

// les trois tons (et un éclat), d'après la lumière l (de -1, le dos, à 1, face au jour) : comme les feuillages
vec3 peindre(vec3 base, float l) {
	float aa = max(fwidth(l), 0.002) * 0.8;
	vec3 ombre = base * vec3(0.5, 0.56, 0.7);
	vec3 clair = mix(base * 1.32, vec3(0.98, 0.92, 0.72), 0.14);
	vec3 eclat = mix(base * 1.62, vec3(1.0, 0.95, 0.8), 0.32);
	vec3 c = mix(ombre, base, smoothstep(-aa, aa, l + 0.02));
	c = mix(c, clair, smoothstep(-aa, aa, l - 0.42));
	return mix(c, eclat, smoothstep(-aa, aa, l - 0.8) * 0.85);
}

void cellules(vec2 p, out vec2 vers, out float d1, out float d2, out vec2 cle) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	d1 = 9.0;
	d2 = 9.0;
	vers = vec2(0.0);
	cle = i;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + 0.15 + 0.7 * vec2(vent_hash(i + o), vent_hash(i + o + 19.7));
			vec2 d = pt - f;
			float dd = dot(d, d);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
				vers = d;
				cle = i + o;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	d1 = sqrt(d1);
	d2 = sqrt(d2);
}

vec3 dome(vec2 q) {
	return vec3(q, sqrt(max(0.0, 1.0 - dot(q, q))));
}

// les bandes de couleur d'une flamme, d'après la distance à son bord, en pixels (nettes : dessinée, pas floue) : un liseré
// sombre, le rouge, la braise, puis le cœur clair ; une grande flamme a de plus larges bandes
vec3 teinte_flamme(float px, float haut) {
	vec3 c = mix(rouge.rgb * 0.62, rouge.rgb, smoothstep(1.6, 2.4, px));
	float b = max(6.5, haut * 0.085);
	c = mix(c, braise.rgb, smoothstep(b, b + 1.5, px));
	b = max(15.0, haut * 0.26);
	c = mix(c, coeur.rgb, smoothstep(b, b + 2.5, px));
	b = max(30.0, haut * 0.48);
	return mix(c, vec3(1.0, 0.94, 0.78), smoothstep(b, b + 4.0, px) * 0.6);
}

// un pan de flammes : de combien q (x de -1 à 1, y de 0 à 1) est en dedans du bord des flammes (négatif : dehors)
float flammes(vec2 q, float graine, float sorte, float force, float avance) {
	float g = graine * 9.7;
	float f = mix(0.42, 1.0, force);
	if (sorte > 0.75) {
		// un feu qui court au sol : des langues courtes, inégales, le long d'un arc (le devant d'un rond couché)
		float y = q.y - 0.3 * (1.0 - sqrt(max(0.0, 1.0 - q.x * q.x)));
		float n = texture(bruit, vec2(q.x * 0.8 + g, q.y * 0.3 - t * 0.4 + g)).r;
		float n2 = texture(bruit, vec2(q.x * 2.1 + g * 1.7, q.y * 0.45 - t * 0.75)).r;
		float h = f * sqrt(max(0.0, 1.0 - q.x * q.x)) * (0.1 + 0.9 * smoothstep(0.3, 0.75, n)) * (0.45 + 0.9 * n2);
		return min(min(h - y, y * 3.0), 0.6);
	}
	// de grandes langues qui montent (le bruit défile vers le haut), et un bruit plus fin qui les déchire vers la pointe
	float n = texture(bruit, vec2(q.x * 0.5 + g, q.y * 0.4 - t * 0.47 + g * 0.3)).r;
	float n2 = texture(bruit, vec2(q.x * 1.25 + g * 1.3, q.y * 0.75 - t * 0.85)).r;
	float x = q.x + (n2 - 0.5) * 0.3 * q.y;
	float env;
	float dessous;
	if (sorte > 0.4) {
		// un corps rond (une couronne qui flambe) : le dessous arrondi, comme elle
		float rond = sqrt(max(0.0, 1.0 - x * x / 0.74));
		env = rond;
		dessous = 0.3 * (1.0 - rond);
	} else {
		// une langue : large en bas, pointue en haut
		env = pow(max(0.0, 1.0 - abs(x) / 0.82), 0.7);
		dessous = 0.14 * (1.0 - sqrt(max(0.0, 1.0 - x * x / 0.68)));
		if (sorte > 0.05) {
			// (une langue de devant : petite quand le feu prend, elle grandit avec lui)
			f *= 0.5 + 0.5 * smoothstep(0.0, 0.55, avance);
		}
	}
	float h = f * env * (0.26 + 0.7 * n);
	return min(h - q.y - (n2 - 0.5) * 0.34 * q.y, (q.y - dessous) * 1.6);
}

void fragment() {
	float avance = v_feu.x;
	float force = v_feu.y;
	float a = COLOR.a;
	if (UV.x > 21.5 && UV.x < 24.5) {
		// --- un pan de flammes ---
		vec2 q = UV - vec2(23.0);
		float haut = COLOR.b * 256.0;
		float px = flammes(q, COLOR.r, COLOR.g, force, avance) * haut;
		float m = smoothstep(0.0, 0.9, px) * step(0.02, force);
		vec3 c = teinte_flamme(px, haut);
		COLOR = vec4(c * m * a, m * opacite * a);
	} else {
		vec3 base = COLOR.rgb;
		vec3 c = base;
		float n = vent_bruit(v_local * 0.31 + v_pied * 0.01) - 0.5;
		bool part = false;       // ce que le feu emporte (les feuilles, leur encre)
		float chaud = 0.0;       // ce qui brille de soi-même
		if (UV.x > 1.5 && UV.x < 4.5) {
			vec2 q = UV - vec2(3.0);
			float l0 = dot(normalize(dome(q * 0.92)), LUMIERE);
			if (simple) {
				c = peindre(base, l0 * 0.95 - 0.12 + n * 0.3);
			} else {
				vec2 vers;
				float d1;
				float d2;
				vec2 cle;
				cellules(v_local / 12.5 + v_pied * 0.017, vers, d1, d2, cle);
				vec2 o = -vers / 0.6;
				float l1 = dot(normalize(dome(o * 0.95)), LUMIERE);
				float creux = 1.0 - smoothstep(0.0, 0.13, d2 - d1);
				float l = l0 * 0.85 + l1 * 0.5 - 0.36 + n * 0.22 - creux * 0.5 * smoothstep(-0.7, 0.3, -l0);
				c = peindre(base * (0.93 + 0.14 * vent_hash(cle)), l);
			}
			part = true;
		} else if (UV.x > 9.5 && UV.x < 12.5) {
			float x = clamp(UV.x - 11.0, -1.0, 1.0);
			float l = dot(normalize(vec3(x, -0.15, sqrt(max(0.0, 1.0 - x * x)))), LUMIERE) - 0.2 + n * 0.15;
			float fibre = vent_bruit(vec2(v_local.x * 0.85, v_local.y * 0.09) + v_pied * 0.05);
			l -= (1.0 - smoothstep(0.2, 0.34, fibre)) * 0.5;
			c = peindre(base, l);
		} else if ((UV.x > 13.5 && UV.x < 16.5) || (UV.x > 29.5 && UV.x < 32.5)) {
			part = UV.x > 29.5;
			vec2 q = UV - vec2(part ? 31.0 : 15.0);
			float l = dot(normalize(dome(q * 0.97)), LUMIERE) + n * 0.1;
			c = peindre(base, l);
		} else if (UV.x > 17.5 && UV.x < 20.5) {
			float x = clamp(UV.x - 19.0, -1.0, 1.0);
			float y = UV.y - 19.0;
			float l = dot(normalize(vec3(x * 0.9, -0.35, 0.75)), LUMIERE) + 0.25 - y * 0.55 + n * 0.22;
			float trait = vent_bruit(vec2((v_local.x + v_local.y * 0.9) * 0.55, (v_local.y - v_local.x * 0.45) * 0.16) + v_pied * 0.03);
			l -= (1.0 - smoothstep(0.24, 0.36, trait)) * 0.38;
			c = peindre(base, l);
			part = true;
		} else if (UV.x > 25.5 && UV.x < 28.5) {
			part = true;
		}
		c *= 0.968 + 0.064 * vent_bruit(v_local * 0.83 + 41.0);
		// --- le feu le mange ---
		float veine = texture(bruit, v_local / 46.0 + v_pied * 0.013).r;
		if (part) {
			// les feuilles : elles roussissent, un bord de braise les troue, puis les emporte (le bas et les bords d'abord)
			float grain = texture(bruit, v_local / 70.0 + v_pied * 0.021 + vec2(0.3, 0.6)).r * 0.75 + veine * 0.25;
			float b = avance * 1.55 - grain - 0.25;
			float cuit = smoothstep(-0.5, -0.04, b);
			c = mix(c, mix(roux.rgb, c * 0.45, 0.35), cuit * 0.85);
			float bord = smoothstep(-0.05, 0.0, b);
			chaud = bord * (0.75 + 0.25 * sin(t * 9.0 + grain * 40.0)) * step(0.02, force + (1.0 - step(1.0, avance)));
			c = mix(c, mix(rouge.rgb, braise.rgb, smoothstep(0.0, 0.03, b)), bord);
			a *= 1.0 - smoothstep(0.03, 0.05, b);
		} else if (UV.x > 33.5) {
			// le charbon d'une souche calcinée : des fentes rouges, qui battent, puis s'éteignent
			float tiede = clamp(2.0 - avance, 0.0, 1.0) * step(1.0, avance);
			float fente = 1.0 - smoothstep(0.0, 0.05 + 0.07 * tiede, abs(veine - 0.5 + 0.08 * sin(v_local.y * 0.4)));
			chaud = fente * tiede * (0.6 + 0.4 * sin(t * 2.3 + veine * 30.0));
			c = mix(c, mix(rouge.rgb, braise.rgb, tiede * fente), chaud);
		} else {
			// le bois, l'encre : ils noircissent, et le bois se fend de rouge
			float noir = smoothstep(0.08, 0.75, avance);
			c = mix(c, charbon.rgb, noir * 0.85);
			if (UV.x > 9.5) {
				float fente = 1.0 - smoothstep(0.0, 0.06, abs(veine - 0.5));
				chaud = fente * smoothstep(0.2, 0.7, avance) * (0.55 + 0.45 * sin(t * 3.1 + veine * 30.0)) * step(0.02, force);
				c = mix(c, mix(rouge.rgb, braise.rgb, 0.4), chaud);
			}
		}
		// l'heure du lieu, et la lueur de son propre feu : ce qui brille ne prend pas la nuit
		vec3 jour = mix(obscur.rgb, vec3(1.12, 0.9, 0.68), clamp(force, 0.0, 1.0) * 0.8);
		c *= mix(jour, vec3(1.0), clamp(chaud, 0.0, 1.0));
		COLOR = vec4(c * a, a);
	}
}
