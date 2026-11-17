// Lisière — la passe d'écran, avec ce que les herbes font voir (shaders/ecran_post_herbes.gdshader)
// La passe de toujours (shaders/ecran_post.gdshader : elle lit l'image du lieu, sur un ordinateur seulement, et en retire la
// couleur), et dans le même passage : le poison (l'image tangue, se dédouble à chaque battement, verdit et s'éteint), la
// torpeur (le flou), les visions (le bord de l'image nage, ses couleurs glissent), la voyance (les noirs se lèvent, froids) ; et
// le corps qui faiblit : la faim (les couleurs se fanent, une crampe brouille la vue), la santé qui s'en va (le monde pâlit), le
// froid (il bleuit), la chaleur (l'air tremble).
// Jamais plus de quatre lectures de l'image, quel que soit le mélange ; les herbes à zéro, c'est la passe de toujours.
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_linear;
uniform float peur = 0.0;
uniform float echo = 0.0;
uniform float fin = 0.0;
uniform float aberration = 0.0;
// le corps (scripts/effets.gd, _le_corps)
uniform float faim = 0.0;
uniform float crampe = 0.0;
uniform float agonie = 0.0;
uniform float lourd = 0.0;
uniform float givre = 0.0;
uniform float fournaise = 0.0;
// les herbes (scripts/effets_herbes.gd)
uniform float poison = 0.0;
uniform float pouls = 0.0;
uniform float flou = 0.0;
uniform float visions = 0.0;
uniform float voyance = 0.0;
uniform vec4 c_peur : source_color = vec4(0.54, 0.44, 0.84, 1.0);
uniform vec4 c_echo : source_color = vec4(0.75, 0.89, 1.0, 1.0);
uniform vec4 c_poison : source_color = vec4(0.45, 0.55, 0.17, 1.0);
uniform vec4 c_voyance : source_color = vec4(0.53, 0.72, 0.95, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float re = length(c) * 1.4142;
	// (les visions : le bord de l'image nage, le centre tient ; le poison : tout tangue, lentement, comme sur l'eau)
	uv += c * sin(TIME * 0.9 + re * 9.0) * 0.014 * visions * re * re;
	uv += vec2(sin(TIME * 1.1 + uv.y * 2.6), cos(TIME * 0.83 + uv.x * 2.1)) * 0.0042 * poison;
	// (la chaleur : l'air tremble, plus au bord qu'au centre)
	uv += vec2(sin(uv.y * 38.0 + TIME * 5.0), cos(uv.x * 31.0 + TIME * 4.3)) * 0.0017 * smoothstep(0.25, 0.8, fournaise) * (0.35 + re);
	// (une crampe : la vue se brouille un instant, comme un vertige)
	float brouille = max(flou, crampe * (0.5 + 0.5 * faim));
	float ab = aberration * re * re;
	vec3 col;
	if (poison > 0.01) {
		// l'image se dédouble : deux images qui s'écartent à chaque battement, l'une tirant sur le rouge, l'autre sur le bleu
		float a = TIME * 0.6;
		vec2 d = vec2(cos(a), sin(a) * 0.6) * (0.003 + 0.0075 * pouls) * poison * (0.45 + 0.55 * re);
		vec3 une = texture(ecran, uv + d).rgb;
		vec3 autre = texture(ecran, uv - d).rgb;
		col = vec3(mix(une.r, autre.r, 0.28), (une.g + autre.g) * 0.5, mix(une.b, autre.b, 0.72));
	} else if (brouille > 0.01) {
		// la torpeur, une crampe : quatre lectures en croix tournée, qui s'écartent ; on ne voit plus net
		vec2 px = SCREEN_PIXEL_SIZE * (0.5 + 2.0 * brouille);
		col = (texture(ecran, uv + px * vec2(1.0, 0.4)).rgb + texture(ecran, uv + px * vec2(-0.4, 1.0)).rgb
			+ texture(ecran, uv + px * vec2(-1.0, -0.4)).rgb + texture(ecran, uv + px * vec2(0.4, -1.0)).rgb) * 0.25;
	} else if (ab > 0.0005) {
		vec2 dir = c * ab * 0.016;
		col = vec3(texture(ecran, uv + dir).r, texture(ecran, uv).g, texture(ecran, uv - dir).b);
	} else {
		col = texture(ecran, uv).rgb;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float sat = clamp(1.0 - 0.6 * smoothstep(0.3, 1.0, peur) - 0.4 * echo - 0.88 * fin - 0.5 * poison - 0.3 * flou
		- 0.6 * faim - 0.75 * agonie - 0.25 * givre, 0.0, 1.0);
	col = mix(vec3(lum), col, sat);
	// la faim : ce qui reste de couleur tire sur la paille, terne ; la santé qui s'en va : le monde pâlit, puis s'assombrit à chaque
	// coup du cœur ; le froid : il bleuit ; la chaleur : elle éblouit un peu
	col = mix(col, col * vec3(1.1, 0.97, 0.66) + vec3(0.02, 0.015, 0.0), faim * 0.65);
	col = mix(col, mix(col, vec3(lum * 1.08), 0.35), agonie * 0.5) * (1.0 - 0.12 * lourd * agonie);
	col = mix(col, col * vec3(0.86, 0.96, 1.16), givre * 0.45);
	col = mix(col, col * vec3(1.12, 1.02, 0.86) + vec3(0.03, 0.015, 0.0), smoothstep(0.25, 0.8, fournaise) * 0.5);
	col = mix(col, col * (0.75 + c_peur.rgb * 0.45), smoothstep(0.55, 1.0, peur) * 0.6);
	col = mix(col, col * vec3(0.78, 0.92, 1.15) + c_echo.rgb * 0.04, echo * 0.55);
	// le poison : ce qui reste de lumière verdit, par les bords (le centre garde ses tons, éteints)
	col = mix(col, vec3(lum) * c_poison.rgb * 2.0, poison * (0.13 + 0.08 * pouls + 0.36 * smoothstep(0.25, 0.95, re)));
	if (visions > 0.01) {
		// les couleurs glissent : la teinte tourne autour du gris, d'un angle qui ondule du centre vers le bord (le centre garde
		// presque les siennes : on y lit toujours une bête, un feu)
		float a = (sin(TIME * 0.37 + re * 2.4) * 1.7 + sin(TIME * 0.11) * 1.1) * visions;
		float co = cos(a);
		float si = sin(a);
		vec3 k = vec3(0.57735);
		vec3 tourne = col * co + cross(k, col) * si + k * dot(k, col) * (1.0 - co);
		col = mix(col, tourne, visions * (0.22 + 0.6 * smoothstep(0.1, 0.85, re)));
	}
	if (voyance > 0.01) {
		// le noir s'ouvre : les ombres se lèvent, bleues et froides ; les clairs ne bougent presque pas
		vec3 clair = pow(col, vec3(0.74)) * vec3(0.8, 0.97, 1.24) + c_voyance.rgb * 0.03;
		col = mix(col, clair, voyance * 0.55);
	}
	COLOR = vec4(col, 1.0);
}
