// Lisière — ce que le temps fait au sol (shaders/temps_sol.gdshader)
// Un seul grand rectangle, posé sur le sol peint, sous tout ce qui se tient debout (scripts/temps_sol.gd) : le sol détrempé et
// ses flaques (là où la boue freine le plus), l'eau montée dans les creux (elle suit climat.eau(p), au pixel : son bord à
// l'encre, son liseré clair là où l'on a pied, plus sombre où c'est profond), la neige qui tient, les impacts de la pluie,
// la marque brûlée de la foudre, et son présage : le sol qui pâlit jusqu'où elle blessera, un cercle qui se resserre.
// Le relief et les flaques sont cuits une fois dans deux petites textures ; les seuils viennent du climat, à chaque image.
// Alpha prémultiplié : il assombrit (le sol mouillé), couvre (l'eau, la neige) et éclaire (la foudre) d'un seul passage.
// Il fait sa lumière lui-même (l'obscurité du lieu, les feux, la torche), comme la brume : unshaded.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D relief : filter_linear, repeat_disable;      // le bruit du relief, compté depuis relief_milieu
uniform sampler2D flaques : filter_linear, repeat_disable;     // le bruit des flaques
uniform sampler2D bruit : filter_linear, repeat_enable;        // un bruit doux, sans couture
uniform float etendue = 5400.0;
uniform float demi = 2100.0;
uniform float relief_milieu = 0.38;
uniform float flaques_gain = 0.9;      // (cuit avec moins d'octaves que le bruit du jeu : ce qu'il faut pour retrouver sa valeur)
uniform bool simple = false;           // un téléphone : moins de lectures

uniform float crue = 0.0;
uniform float boue = 0.0;
uniform float neige_sol = 0.0;
uniform float pluie = 0.0;
uniform float temps = 0.0;
uniform float nuit = 0.0;
uniform float eclair = 0.0;            // l'éclat du ciel, que l'eau renvoie
uniform vec4 obscur : source_color = vec4(1.0);     // la couleur du monde (le CanvasModulate)
uniform vec4 feu0 = vec4(0.0);         // xy : où, z : le rayon, w : la force (0 : rien)
uniform vec4 feu1 = vec4(0.0);
uniform vec4 torche = vec4(0.0);
uniform vec4 presage0 = vec4(0.0);     // xy : où ; z : de 0 (annoncée) à 1 (elle tombe) ; w : jusqu'où elle blessera (0 : rien)
uniform vec4 presage1 = vec4(0.0);
uniform float presage_eau0 = 0.0;      // son point est dans l'eau : elle y court plus loin
uniform float presage_eau1 = 0.0;
uniform vec4 marque0 = vec4(0.0);      // xy : où ; z : sa force (1, puis elle s'efface) ; w : son rayon
uniform vec4 marque1 = vec4(0.0);
uniform vec4 marque2 = vec4(0.0);
uniform vec4 marque3 = vec4(0.0);
uniform vec4 impact = vec4(0.0);       // xy : où la foudre vient de tomber ; z : sa lumière ; w : son rayon
uniform vec4 pieds = vec4(0.0);        // xy : les pieds de la veilleuse ; z : elle remue l'eau (0 à 1)

uniform vec4 c_feu : source_color = vec4(0.97, 0.66, 0.35, 1.0);
uniform vec4 c_eau : source_color = vec4(0.2, 0.27, 0.33, 1.0);
uniform vec4 c_fond : source_color = vec4(0.1, 0.14, 0.2, 1.0);
uniform vec4 c_reflet : source_color = vec4(0.75, 0.82, 0.88, 1.0);
uniform vec4 c_boue : source_color = vec4(0.17, 0.15, 0.13, 1.0);
uniform vec4 c_flaque : source_color = vec4(0.22, 0.2, 0.19, 1.0);
uniform vec4 c_neige : source_color = vec4(0.93, 0.92, 0.9, 1.0);
uniform vec4 c_neige_ombre : source_color = vec4(0.62, 0.7, 0.82, 1.0);
uniform vec4 c_encre : source_color = vec4(0.086, 0.075, 0.059, 1.0);
uniform vec4 c_foudre : source_color = vec4(0.86, 0.92, 1.0, 1.0);
uniform vec4 c_braise : source_color = vec4(0.95, 0.6, 0.28, 1.0);

varying vec2 monde;

void vertex() {
	monde = VERTEX;
}

float h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// une couche de plus, par-dessus les autres (couleur, opacité)
vec4 sur(vec4 dessous, vec3 c, float a) {
	return vec4(c * a + dessous.rgb * (1.0 - a), a + dessous.a * (1.0 - a));
}

float lueur(vec4 l) {
	if (l.w <= 0.0) {
		return 0.0;
	}
	float d = length(monde - l.xy) / max(l.z, 1.0);
	return l.w * pow(clamp(1.0 - d, 0.0, 1.0), 0.8);
}

// les gouttes qui touchent le sol : par case, une goutte de temps en temps, là où le sort la pose.
// x : son rond qui s'élargit (sur l'eau) ; y : son éclat bref (sur la terre)
vec2 gouttes(vec2 p, float taille, float t, float part) {
	vec2 g = p / taille;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float h = h21(gi);
	float tour = t * (1.2 + 0.7 * h) + h * 9.0;
	float k = floor(tour);
	float u = fract(tour);
	if (h21(gi + k * 0.71 + 13.0) > part) {
		return vec2(0.0);
	}
	vec2 c = 0.3 + 0.4 * vec2(h21(gi + k * 1.37), h21(gi - k * 2.11 + 4.7));
	// (vu de biais : un rond couché)
	float r = length((gf - c) * vec2(1.0, 1.6)) * taille;
	float rond = (1.0 - smoothstep(0.0, 1.0, abs(r - u * taille * 0.27))) * (1.0 - u) * (1.0 - u);
	float eclat = (1.0 - smoothstep(0.8, 2.0, r)) * (1.0 - smoothstep(0.0, 0.22, u));
	return vec2(rond, eclat);
}

// la marque brûlée de la foudre : une étoile de cendre, ses braises les premiers instants
vec4 bruler(vec4 v, vec4 m, vec3 lum, float n2) {
	if (m.z <= 0.0) {
		return v;
	}
	vec2 q = monde - m.xy;
	float r = length(q * vec2(1.0, 1.25)) / m.w;
	if (r > 1.7) {
		return v;
	}
	float dent = texture(bruit, vec2(atan(q.y, q.x) * 0.4775, m.x * 0.013 + 0.2)).r;
	float rr = r + (dent - 0.5) * 0.85 + (n2 - 0.5) * 0.3;
	float cendre = 1.0 - smoothstep(0.5, 0.95, rr);
	float coeur = 1.0 - smoothstep(0.1, 0.5, rr);
	float force = min(1.0, m.z * 3.0);
	v = sur(v, c_encre.rgb * 1.4 * lum, cendre * 0.6 * force);
	v = sur(v, c_encre.rgb * 0.7 * lum, coeur * 0.85 * force);
	// (les braises : au bord de la cendre, tant que la marque est fraîche)
	float frais = smoothstep(0.75, 1.0, m.z);
	float bord = cendre * (1.0 - smoothstep(0.0, 0.35, abs(rr - 0.6))) * step(0.45, dent);
	v.rgb += c_braise.rgb * bord * frais * 0.9;
	return v;
}

// le présage : le sol pâlit jusqu'où la foudre blessera, son bord crépite, un cercle se resserre sur le point où elle tombe.
// (mouille : il y a de l'eau ici, et le point est dans l'eau : elle y court près de deux fois plus loin)
vec4 presager(vec4 v, vec4 p, float mouille, float n2, float px) {
	if (p.w <= 0.0) {
		return v;
	}
	vec2 q = monde - p.xy;
	float r = length(q);
	float large = p.w * 1.9;
	if (r > (mouille > 0.0 ? large : p.w) + 14.0) {
		return v;
	}
	float u = p.z;
	float ang = atan(q.y, q.x);
	// (des filaments qui rampent vers le centre)
	float fil = texture(bruit, vec2(ang * 0.6366, r / 110.0 + temps * 1.3)).r;
	float fil2 = texture(bruit, vec2(ang * 0.3183 + 0.37, temps * 0.9 + 0.5)).r;
	// (son bord n'est pas un cercle tiré au compas : il tremble)
	float bord = r + (n2 - 0.5) * 9.0 + (fil2 - 0.5) * 7.0 * sin(temps * 9.0 + ang * 3.0);
	float dedans = 1.0 - smoothstep(p.w - 5.0, p.w + 1.0, bord);
	float clignote = 0.85 + 0.15 * sin(temps * 47.0 + fil2 * 20.0);
	float veine = 1.0 - smoothstep(0.0, 0.022 + 0.01 * px, abs(fil - 0.52));
	// dans l'eau : elle pâlit plus loin, parcourue d'étincelles
	if (mouille > 0.0) {
		float loin = (1.0 - smoothstep(large - 12.0, large, bord)) * (1.0 - dedans) * mouille;
		v = sur(v, c_foudre.rgb, loin * (0.1 + 0.16 * u + veine * (0.3 + 0.3 * u)) * clignote);
		float limite2 = (1.0 - smoothstep(0.4, 1.3 + px, abs(bord - large + 2.0))) * smoothstep(0.34, 0.5, fil2);
		v = sur(v, c_foudre.rgb, limite2 * mouille * (0.35 + 0.4 * u) * clignote);
	}
	// le sol pâlit, plus fort à mesure qu'elle vient
	float pale = dedans * (0.1 + 0.2 * u) * (0.75 + 0.5 * fil);
	v = sur(v, c_foudre.rgb, pale * clignote);
	// sa limite : un trait pâle, rompu, qui frémit
	float limite = (1.0 - smoothstep(0.3, 1.1 + px, abs(bord - p.w + 2.0))) * smoothstep(0.4, 0.56, fil);
	v = sur(v, c_foudre.rgb, limite * (0.4 + 0.45 * u) * clignote);
	// le cercle qui se resserre : il arrive au centre quand elle tombe
	float rho = p.w * (1.0 - u * u) + (fil - 0.5) * 9.0;
	float cercle = (1.0 - smoothstep(0.5, 1.6 + px, abs(r - rho))) * dedans;
	v = sur(v, vec3(1.0), cercle * (0.55 + 0.4 * u));
	// les veines : de fines étincelles au sol, entre le cercle et le bord
	v = sur(v, c_foudre.rgb, veine * dedans * smoothstep(rho - 16.0, rho + 6.0, r) * (0.25 + 0.5 * u) * clignote);
	// le point : il blanchit à la fin
	float point = (1.0 - smoothstep(0.0, 16.0, r)) * u * u;
	v.rgb += c_foudre.rgb * point * 0.55;
	return v;
}

void fragment() {
	float px = clamp(fwidth(monde.x), 0.2, 4.0);        // un pixel de l'écran, en pixels du lieu
	vec2 uv = monde / etendue + 0.5;
	float n1 = texture(bruit, monde / 610.0).r;
	float n2 = texture(bruit, monde / 230.0 + 0.31).r;
	// (le sens de la vue : une dérivée d'écran rapportée au lieu)
	vec2 sens = vec2(sign(dFdx(monde.x)), sign(dFdy(monde.y)));
	vec3 lum = obscur.rgb + c_feu.rgb * (lueur(feu0) + lueur(feu1) + lueur(torche)) * 0.6;
	// (ce qui luit sur l'eau : le ciel, la lune la nuit, l'éclair)
	vec3 luit = lum + vec3(0.2, 0.25, 0.38) * nuit + c_foudre.rgb * eclair * 0.9;
	vec4 v = vec4(0.0);
	float nappe = 0.0;      // là où il y a de l'eau à la surface (flaque ou crue) : les ronds de la pluie s'y voient
	float inonde = 0.0;     // là où l'eau est montée

	// --- la boue : le sol s'assombrit, plus là où elle est épaisse ; ses flaques, là où elle freine le plus ---
	if (boue > 0.02) {
		float f = clamp(0.5 + (texture(flaques, uv).r - 0.5) * flaques_gain, 0.0, 1.0);
		float moite = boue * (0.55 + 0.45 * smoothstep(0.3, 0.7, f));
		v = sur(v, c_boue.rgb * lum, moite * (0.3 + 0.16 * n1));
		// (les flaques gagnent à mesure que le sol se gorge)
		float seuil_f = mix(0.88, 0.645, smoothstep(0.12, 1.0, boue));
		float fl = f + (n2 - 0.5) * 0.03;
		vec2 gr = vec2(dFdx(fl), dFdy(fl));
		float g = max(length(gr), 1e-5);
		float d = (fl - seuil_f) / g;                   // la distance au bord, en pixels de l'écran (dedans : positive)
		float dans = smoothstep(-0.6, 0.6, d);
		// la berge : un anneau de boue épaisse
		float berge = smoothstep(seuil_f - 0.06, seuil_f - 0.005, fl) * (1.0 - dans);
		v = sur(v, c_boue.rgb * 0.8 * lum, berge * 0.34);
		// l'eau de la flaque : un lavis de sépia, plus sombre à son bord (le pigment s'y dépose) ; les grandes
		// reflètent le ciel en leur milieu
		vec2 vers = gr / g * sens;
		float dw = d * px;
		vec3 cf = c_flaque.rgb * lum;
		v = sur(v, cf, dans * 0.74);
		v = sur(v, mix(c_reflet.rgb, c_flaque.rgb * 2.2, 0.45) * luit, dans * smoothstep(seuil_f + 0.03, seuil_f + 0.08, fl) * 0.22);
		// (des reflets : de courts traits clairs, couchés)
		float rf = texture(bruit, vec2(monde.x / 760.0 + 0.2, monde.y / 120.0)).r * 7.0;
		float reflets = 1.0 - smoothstep(0.5, 1.2, abs(fract(rf) - 0.5) / max(fwidth(rf), 1e-4));
		v = sur(v, c_reflet.rgb * luit, reflets * smoothstep(0.5, 0.62, n2) * dans * smoothstep(2.5, 5.0, dw) * 0.38);
		float depot = dans * (1.0 - smoothstep(0.2, 1.8 + 1.6 * n2, dw));
		v = sur(v, c_encre.rgb * 1.3 * lum, depot * (0.42 + 0.25 * smoothstep(0.1, -0.7, vers.y)));
		nappe = dans;
	}

	// --- la foudre a brûlé le sol ---
	v = bruler(v, marque0, lum, n2);
	v = bruler(v, marque1, lum, n2);
	v = bruler(v, marque2, lum, n2);
	v = bruler(v, marque3, lum, n2);

	// --- la crue : l'eau dans les creux, exactement là où climat.eau(p) la met ---
	if (crue > 0.01) {
		// (les nombres de climat.relief et de climat.eau)
		float rel = clamp(texture(relief, uv).r + relief_milieu + 0.4 * exp(-dot(monde, monde) / 78400.0), 0.0, 1.0);
		float e = (mix(0.26, 0.5, crue) - rel) / 0.07;
		float plein = min(1.0, crue * 6.0);
		float prof = clamp(e, 0.0, 1.0) * plein;        // la profondeur, celle du jeu
		// (le bord respire : l'eau lèche la rive)
		float ev = e + ((n2 - 0.5) * 0.05 + 0.022 * sin(temps * 1.1 + n1 * 14.0)) * (1.0 - smoothstep(0.0, 0.5, e));
		vec2 gr = vec2(dFdx(ev), dFdy(ev));
		float g = max(length(gr), 1e-5);
		float d = ev / g;
		float dw = d * px;
		float dans = smoothstep(-0.6, 0.6, d);
		float mince = mix(0.4, 1.0, plein);
		// là où l'on a pied (sous 0,15 : on n'y est pas trempée), un liseré clair ; puis l'eau, de plus en plus sombre
		float pied = 1.0 - smoothstep(0.11, 0.17, prof);
		vec3 ce = mix(c_eau.rgb, c_fond.rgb, smoothstep(0.2, 0.95, prof)) * lum;
		ce = mix(ce, c_reflet.rgb * luit, pied * 0.3);
		float ae = mix(mix(0.62, 0.9, smoothstep(0.15, 0.9, prof)), 0.4, pied) * mince;
		v = sur(v, ce, dans * ae);
		// les rides : des traits clairs, couchés, qui glissent (les lignes de niveau d'un bruit étiré)
		float rr = texture(bruit, vec2(monde.x / 900.0 + temps * 0.004, monde.y / 150.0 - temps * 0.012)).r;
		if (!simple) {
			rr += texture(bruit, vec2(monde.x / 640.0 - temps * 0.006, monde.y / 105.0 + 0.4)).r * 0.6;
		}
		rr *= 9.0;
		float gl = max(fwidth(rr), 1e-4);
		float ligne = abs(fract(rr) - 0.5) / gl;
		float rides = (1.0 - smoothstep(0.4, 1.1, ligne)) * smoothstep(0.46, 0.6, n2);
		float creux = (1.0 - smoothstep(0.4, 1.1, abs(fract(rr + 0.37) - 0.5) / gl)) * smoothstep(0.58, 0.44, n2);
		float large = dans * smoothstep(3.0, 9.0, dw) * mince;
		v = sur(v, c_reflet.rgb * luit, rides * large * 0.3);
		v = sur(v, c_fond.rgb * 0.7 * lum, creux * large * 0.3);
		// la ligne des 0,3 : au-delà, un feu se noie
		float l3 = (prof - 0.3) / max(g * plein, 1e-5) * px;
		v = sur(v, c_fond.rgb * 0.6 * lum, (1.0 - smoothstep(0.3, 0.9, abs(l3))) * 0.3 * dans);
		// le bord : un trait d'encre, puis un liseré clair juste dedans
		float encre = 1.0 - smoothstep(0.4, 1.0, abs(dw - 0.3) / (0.55 + 0.9 * n2));
		v = sur(v, c_encre.rgb * lum, encre * 0.72 * min(1.0, plein * 2.5));
		float lisere = 1.0 - smoothstep(0.5, 1.2, abs(dw - 2.3 - n2));
		v = sur(v, c_reflet.rgb * luit, lisere * 0.5 * mince * dans);
		nappe = max(nappe, dans);
		inonde = dans;
		// la veilleuse remue l'eau : des ronds autour de ses pieds
		if (pieds.z > 0.01) {
			float rp = length((monde - pieds.xy) * vec2(1.0, 1.6));
			float onde = smoothstep(0.72, 0.96, sin(rp * 0.48 - temps * 7.5));
			v = sur(v, c_reflet.rgb * luit, onde * (1.0 - smoothstep(9.0, 38.0, rp)) * pieds.z * dans * 0.5);
		}
	}

	// --- la neige qui tient : par plaques, puis partout ; bleutée sur son bord et dans ses creux ---
	if (neige_sol > 0.02) {
		float n3 = texture(bruit, monde / 97.0 + 0.63).r;
		float vs = n1 * 0.5 + n2 * 0.38 + n3 * 0.12;
		float ss = neige_sol < 0.2 ? mix(0.8, 0.53, neige_sol / 0.2) : (neige_sol < 0.6 ? mix(0.53, 0.38, (neige_sol - 0.2) / 0.4) : mix(0.38, 0.1, (neige_sol - 0.6) / 0.4));
		float aa = max(fwidth(vs), 0.004);
		float ms = smoothstep(ss - aa, ss + aa, vs) * (1.0 - nappe);
		// (le givre, avant la neige : il poudre le sol)
		float givre = smoothstep(ss - 0.1, ss, vs) * (1.0 - ms) * (1.0 - nappe);
		v = sur(v, c_neige_ombre.rgb * lum, givre * (0.2 + 0.3 * smoothstep(0.5, 0.7, n3)));
		// son bord dans l'ombre ; plus elle est épaisse, plus elle se creuse de congères, à l'ombre bleue elles aussi
		float bord = 1.0 - smoothstep(ss + 0.012, ss + 0.05, vs);
		float epaisse = smoothstep(ss + 0.04, ss + 0.2, vs);
		float congere = texture(bruit, vec2(monde.x / 520.0 + 0.11, monde.y / 170.0)).r * 5.0;
		float ombre = (1.0 - smoothstep(0.0, 0.22, abs(fract(congere) - 0.3))) * epaisse;
		// (la nuit, elle garde un peu de la lune : on voit où elle tient)
		vec3 cn = mix(c_neige.rgb, c_neige_ombre.rgb, clamp(bord * 0.7 + ombre * 0.3 + smoothstep(0.6, 0.3, n3) * 0.14, 0.0, 1.0)) * (lum + vec3(0.05, 0.07, 0.12) * nuit);
		v = sur(v, cn, ms * 0.93);
		// (au soleil, elle scintille)
		v.rgb += vec3(0.4) * ms * step(0.993, h21(floor(monde / 2.5))) * (1.0 - bord) * (1.0 - nuit);
	}

	// --- la pluie touche le sol : des ronds sur l'eau, un éclat bref sur la terre ---
	if (pluie > 0.03) {
		vec2 gt = gouttes(monde, 31.0, temps, pluie * 0.85);
		if (!simple) {
			gt += gouttes(monde + 17.3, 22.0, temps * 1.13 + 3.0, pluie * 0.7);
		}
		v = sur(v, c_reflet.rgb * luit, clamp(gt.x * nappe * 0.6 + gt.y * mix(0.3, 0.55, nappe), 0.0, 0.8));
	}

	// --- la foudre : ses présages, la lumière de son impact ---
	v = presager(v, presage0, presage_eau0 * inonde, n2, px);
	v = presager(v, presage1, presage_eau1 * inonde, n2, px);
	if (impact.z > 0.0) {
		float ri = length(monde - impact.xy) / impact.w;
		v.rgb += c_foudre.rgb * impact.z * (1.0 - smoothstep(0.0, 1.0, ri)) * (1.0 - smoothstep(0.0, 1.0, ri));
	}

	// au-delà du lieu, tout s'enfonce dans le noir du bois
	v *= 1.0 - smoothstep(-40.0, 260.0, max(abs(monde.x), abs(monde.y)) - demi);
	COLOR = v;
}
