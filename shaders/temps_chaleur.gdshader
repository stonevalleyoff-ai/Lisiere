// Lisière — l'air qui tremble (shaders/temps_chaleur.gdshader)
// La canicule, en qualité haute seulement (il lit l'écran) : l'image ondule, par nappes qui montent. scripts/ciel.gd ne
// l'allume que tant que la chaleur écrase le lieu.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ecran : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D bruit : filter_linear, repeat_enable;
uniform float force = 0.0;
uniform float temps = 0.0;
uniform float ratio = 1.7778;

void fragment() {
	vec2 q = vec2(SCREEN_UV.x * ratio, SCREEN_UV.y);
	float a = texture(bruit, q * vec2(1.7, 3.4) + vec2(0.0, temps * 0.21)).r;
	float b = texture(bruit, q * vec2(3.3, 5.6) + vec2(0.3, temps * 0.34)).r;
	// (pas partout à la fois : des nappes d'air chaud, lentes)
	float nappes = smoothstep(0.3, 0.65, texture(bruit, q * 0.8 + vec2(temps * 0.017, temps * 0.05)).r);
	vec2 d = vec2(a - 0.5, (b - 0.5) * 0.45) * force * nappes * 0.0055;
	COLOR = vec4(texture(ecran, SCREEN_UV + d).rgb, 1.0);
}
