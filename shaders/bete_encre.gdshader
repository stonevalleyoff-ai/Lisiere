// Lisière — l'encre d'une bête (shaders/bete_encre.gdshader)
// Ce que le corps d'une bête montre de plus que son dessin : l'éclair clair d'un coup, l'ondulation d'un corps sans pattes,
// l'encre qui s'efface à la mort, la fumée pâle d'un écho ; et, en qualité haute, un grain de papier dans ses aplats.
// Toutes les parties d'une bête (la queue, le corps, la tête, les pattes) le partagent : son bruit se lit dans le lieu, en
// pixels autour de la bête, pour qu'elles s'effacent et tremblent ensemble ; le grain, lui, tient au dessin.
shader_type canvas_item;

uniform float eclat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur_eclat : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float dissolution : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur_encre : source_color = vec4(0.086, 0.075, 0.059, 1.0);
uniform float echo : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur_echo : source_color = vec4(0.75, 0.89, 1.0, 1.0);
uniform float temps = 0.0;
uniform vec2 origine = vec2(0.0);
uniform float hauteur = 30.0;
uniform float onde = 0.0;
uniform float onde_phase = 0.0;
uniform float onde_vagues = 1.4;
uniform bool fin = true;

varying vec2 lieu;
varying vec4 teinte;

void vertex() {
	lieu = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origine;
	// (la teinte seule : dans le fragment, COLOR porte déjà la texture, lue sans déformation)
	teinte = COLOR;
}

float hachage(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hachage(i), hachage(i + vec2(1.0, 0.0)), u.x), mix(hachage(i + vec2(0.0, 1.0)), hachage(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	// sans pattes : une vague qui court vers la queue (la tête, à droite du dessin, bouge moins)
	if (onde > 0.0) {
		uv.y += sin(uv.x * onde_vagues * 6.2832 + onde_phase) * onde * (1.0 - 0.65 * uv.x);
	}
	// un écho : ses bords tremblent
	if (echo > 0.0) {
		vec2 t = vec2(bruit(lieu * 0.14 + vec2(temps * 1.7, 0.0)), bruit(lieu * 0.14 + vec2(5.3, temps * 2.1))) - 0.5;
		uv += t * 4.5 * TEXTURE_PIXEL_SIZE * echo;
	}
	vec4 c = texture(TEXTURE, uv) * teinte;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// le papier : un grain très léger dans les aplats (pas dans le trait d'encre), qui tient au dessin
	if (fin && echo <= 0.0) {
		vec2 px = uv / TEXTURE_PIXEL_SIZE;
		float grain = (bruit(px * 0.19) - 0.5) * 0.075 + (hachage(floor(px * 0.5)) - 0.5) * 0.04;
		c.rgb *= 1.0 + grain * smoothstep(0.1, 0.34, lum);
	}
	if (echo > 0.0) {
		vec3 pale = mix(couleur_echo.rgb * 0.42, couleur_echo.rgb * 1.06, smoothstep(0.06, 0.55, lum));
		float f = bruit(lieu * 0.06 + vec2(0.0, temps * 0.5)) * 0.65 + bruit(lieu * 0.2 + vec2(temps * 0.35, temps * 0.95)) * 0.35;
		// (les pieds se perdent dans la fumée)
		float pied = smoothstep(hauteur * 0.12, hauteur * 0.8, -lieu.y);
		c.rgb = mix(c.rgb, pale, echo);
		c.a *= mix(1.0, (0.12 + 0.88 * smoothstep(0.28, 0.72, f)) * (0.06 + 0.94 * pied), echo);
	}
	// la mort : l'encre s'efface. Les aplats pâlissent et partent d'abord, par plaques (à la mesure de la bête : de grandes
	// plaques sur une grande bête) ; le trait tient un peu plus longtemps, puis s'émiette à son tour
	if (dissolution > 0.0) {
		float ech = clamp(26.0 / hauteur, 0.3, 1.0);
		float n = bruit(lieu * 0.3 * ech);
		if (fin) {
			n = n * 0.6 + bruit(lieu * 0.8 * ech + 7.3) * 0.27 + bruit(lieu * 2.1 - 3.1) * 0.13;
		}
		float trait = 1.0 - smoothstep(0.12, 0.36, lum);
		float s = dissolution * 1.34 - 0.08 - 0.2 * trait;
		float bord = 1.0 - smoothstep(s, s + 0.1, n);
		// (l'aplat se délave vers le papier avant de partir ; son bord boit l'encre)
		float proche = (1.0 - smoothstep(s + 0.05, s + 0.4, n)) * smoothstep(0.0, 0.15, dissolution);
		c.rgb = mix(c.rgb, couleur_eclat.rgb * 0.86, (1.0 - trait) * proche * 0.6);
		c.rgb = mix(c.rgb, couleur_encre.rgb, clamp(bord * 0.7 * (1.0 - trait) + dissolution * 0.12, 0.0, 1.0));
		c.a *= smoothstep(s - 0.03, s + 0.04, n);
	}
	// un coup : l'éclair blanchit la robe ; le trait d'encre reste, la bête garde son dessin
	c.rgb = mix(c.rgb, couleur_eclat.rgb, eclat * mix(0.3, 1.0, smoothstep(0.1, 0.4, lum)));
	COLOR = c;
}
