shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Lisière — l'air de l'incendie (shaders/incendie_air.gdshader)
// La fumée qui monte et file sous le vent, les braises qui volent vers où le feu peut sauter, les étincelles ; et ce qui ne
// dure qu'un instant : une bouffée de vapeur, une gerbe, des éclats de boue, des éclaboussures. Tout tient dans un seul
// MultiMesh (scripts/incendie_flammes.gd), un seul appel de dessin, et rien n'est calculé par le jeu à chaque image : chaque
// instance est une particule qui recommence sa vie sans fin, et sa place se déduit de l'heure (t). Le jeu n'écrit une instance
// que quand un feu prend ou s'éteint.
// Ce que dit une instance : où elle naît (sa transformation : une simple translation) ; sa couleur : quand son foyer a pris
// (r * 8 + v, en secondes de l'horloge des flammes), combien de temps il fait naître des particules (b), sa taille (a) ;
// ses données : sa phase (x), la durée d'une vie (y ; 0 : rien), sa sorte et sa graine (z : la sorte, plus une fraction), sa
// force (w). Une particule née avant que son foyer prenne, ou après qu'il a fini, ne se montre pas : la fumée ne surgit pas
// en l'air, et elle finit de monter quand le feu est mort.
// Alpha prémultiplié : la fumée couvre (un lavis), les braises s'ajoutent (elles brillent dans la nuit).

uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float t = 0.0;
uniform vec2 vent = vec2(0.0);                      // climat.vent_dir * climat.vent
uniform float portee = 64.0;                        // jusqu'où le feu saute (R.INCENDIE_PORTEE) : là tombent les braises
uniform float pluie = 0.0;
uniform vec4 obscur : source_color = vec4(1.0);     // la couleur du monde à cette heure
uniform vec4 c_fumee : source_color = vec4(0.2, 0.18, 0.16, 1.0);
uniform vec4 c_vapeur : source_color = vec4(0.91, 0.87, 0.78, 1.0);
uniform vec4 c_boue : source_color = vec4(0.25, 0.2, 0.15, 1.0);
uniform vec4 c_eau : source_color = vec4(0.7, 0.78, 0.86, 1.0);
uniform vec4 rouge : source_color = vec4(0.77, 0.27, 0.16, 1.0);
uniform vec4 braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);
uniform vec4 coeur : source_color = vec4(1.0, 0.85, 0.54, 1.0);

varying float v_sorte;
varying float v_a;          // son âge, de 0 à 1
varying float v_alpha;
varying float v_graine;

float hasard(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	float t0 = COLOR.r * 8.0 + COLOR.g;
	float dure = COLOR.b;
	float taille = COLOR.a;
	float phase = INSTANCE_CUSTOM.x;
	float vie = max(INSTANCE_CUSTOM.y, 0.001);
	float sorte = floor(INSTANCE_CUSTOM.z + 0.01);
	float graine = fract(INSTANCE_CUSTOM.z + 0.01);
	float force = INSTANCE_CUSTOM.w;
	float c = t / vie + phase;
	float tour = floor(c);
	float a = c - tour;
	float nee = (tour - phase) * vie;
	v_sorte = sorte;
	v_a = a;
	v_graine = graine;
	v_alpha = 0.0;
	if (INSTANCE_CUSTOM.y < 0.01 || nee < t0 - 0.02 || nee > t0 + dure + 0.02) {
		VERTEX = vec2(0.0);
	} else {
		float age = a * vie;
		vec2 g = vec2(graine * 251.0, mod(tour, 1024.0));
		float r1 = hasard(g);
		float r2 = hasard(g + vec2(17.3, 3.1));
		float r3 = hasard(g + vec2(5.7, 29.9));
		float r4 = hasard(g + vec2(41.1, 11.3));
		vec2 p = vec2(0.0);
		float s = 2.0;
		if (sorte < 0.5) {
			// la fumée : elle monte, grossit, et file sous le vent
			// (à l'écran, le vent qui vient vers nous ne la fait guère descendre : elle monte toujours)
			p = vec2((r1 - 0.5) * taille * 0.7, -r2 * taille * 0.3);
			p.y -= (34.0 + 22.0 * r2) * pow(age, 0.92);
			p += vent * vec2(1.0, 0.3) * (24.0 * age + 8.0 * age * age);
			p.x += sin(age * 1.9 + r3 * 6.2832) * 5.0;
			s = taille * (0.55 + 1.5 * a);
			v_alpha = smoothstep(0.0, 0.1, a) * (1.0 - smoothstep(0.3, 1.0, a)) * force;
		} else if (sorte < 1.5) {
			// une braise qui vole : du haut des flammes jusqu'où le feu peut prendre (plus loin sous le vent, comme la règle)
			float ang = r3 * 6.2832;
			vec2 dir = vec2(cos(ang), sin(ang));
			float loin = (0.45 + 0.55 * r4) * portee * (1.0 + 0.6 * dot(dir, vent));
			p = mix(vec2((r1 - 0.5) * 22.0, -taille * (0.55 + 0.45 * r2)), dir * loin, a);
			p.y -= sin(a * 3.1416) * (16.0 + 26.0 * r1);
			p.x += sin(age * 9.0 + r2 * 6.2832) * 1.6;
			s = 4.0 + 2.0 * r2;
			v_alpha = smoothstep(0.0, 0.06, a) * (1.0 - smoothstep(0.9, 1.0, a)) * force;
		} else if (sorte < 2.5) {
			// une étincelle : elle monte vite, tremble, s'éteint
			p = vec2((r1 - 0.5) * taille, -r4 * taille * 0.4);
			p.y -= (38.0 + 50.0 * r2) * age;
			p += vent * 70.0 * age * (0.5 + r3);
			p.x += sin(age * 7.0 + r4 * 6.2832) * 4.0 * (0.3 + a);
			s = 2.6;
			v_alpha = smoothstep(0.0, 0.05, a) * (1.0 - a) * force;
		} else if (sorte < 3.5) {
			// une bouffée de vapeur : pâle, elle monte et s'étale
			p = vec2((r1 - 0.5) * taille, (r2 - 0.5) * taille * 0.6);
			p.y -= (20.0 + 22.0 * r3) * age * (1.0 - 0.3 * a);
			p += vent * vec2(1.0, 0.3) * 26.0 * age;
			s = taille * (0.55 + 1.1 * a);
			v_alpha = smoothstep(0.0, 0.08, a) * pow(1.0 - a, 1.3) * force;
		} else if (sorte < 4.5) {
			// une gerbe d'étincelles : elles partent de tous côtés et retombent
			float ang = r1 * 6.2832;
			float v = (40.0 + 80.0 * r2) * taille / 30.0;
			p = vec2(cos(ang), sin(ang) * 0.7) * v * age * (1.0 - 0.35 * a);
			p.y += -40.0 * age + 110.0 * age * age;
			p += vent * 30.0 * age;
			s = 2.8;
			v_alpha = (1.0 - a * a) * force;
		} else {
			// des éclats (la boue, l'eau) : lancés vers le haut, ils retombent
			float ang = (r1 - 0.5) * 2.4;
			float v = (50.0 + 55.0 * r2) * taille / 30.0;
			p = vec2(sin(ang) * v * 0.7, -cos(ang) * v) * age;
			p.y = min(p.y + 260.0 * age * age, 1.5);
			s = sorte < 5.5 ? 2.2 + 1.8 * r3 : 1.7 + 1.3 * r3;
			v_alpha = (1.0 - smoothstep(0.75, 1.0, a)) * force;
		}
		VERTEX = VERTEX * s + p;
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (v_sorte < 0.5 || (v_sorte > 2.5 && v_sorte < 3.5)) {
		// une bouffée : un lavis, au bord mangé par un bruit (de l'encre dans l'eau, pas un nuage flou)
		float n = texture(bruit, UV * 0.33 + vec2(v_graine * 3.7, v_graine * 1.3 + v_a * 0.2)).r;
		float m = 1.0 - smoothstep(0.4, 0.9, d + (n - 0.5) * 0.9);
		if (v_sorte < 0.5) {
			// (jeune, la fumée est éclairée d'en dessous par les flammes : elle ne fait pas un trou noir dans la nuit ; puis
			// elle prend l'heure du lieu ; sous la pluie, elle pâlit : de la vapeur s'y mêle)
			vec3 lumiere = mix(vec3(1.25, 0.8, 0.5), mix(obscur.rgb, vec3(1.0), 0.3), smoothstep(0.05, 0.6, v_a));
			vec3 c = mix(c_fumee.rgb, c_vapeur.rgb * 0.8, pluie * 0.45) * lumiere;
			float al = m * v_alpha * (0.5 + 0.12 * pluie) * mix(0.6, 1.0, obscur.g);
			COLOR = vec4(c * al, al);
		} else {
			float al = m * v_alpha * 0.55;
			COLOR = vec4(c_vapeur.rgb * mix(obscur.rgb, vec3(1.0), 0.4) * al, al);
		}
	} else if (v_sorte < 2.5 || (v_sorte > 3.5 && v_sorte < 4.5)) {
		// une braise, une étincelle : un point net et son halo, ajoutés ; elle rougit en s'éteignant
		float m = 1.0 - smoothstep(0.28, 0.5, d);
		float halo = pow(max(1.0 - d, 0.0), 2.0) * 0.4;
		vec3 c = mix(coeur.rgb, braise.rgb, smoothstep(0.0, 0.4, v_a));
		c = mix(c, rouge.rgb, smoothstep(0.5, 1.0, v_a));
		COLOR = vec4(c * (m + halo) * v_alpha, 0.0);
	} else {
		float m = (1.0 - smoothstep(0.55, 0.9, d)) * v_alpha;
		vec3 c = v_sorte < 5.5 ? c_boue.rgb * obscur.rgb : c_eau.rgb * mix(obscur.rgb, vec3(1.0), 0.45);
		COLOR = vec4(c * m, m * (v_sorte < 5.5 ? 1.0 : 0.75));
	}
}
