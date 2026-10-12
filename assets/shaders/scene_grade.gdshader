// Gradación de la escena por hora (data/scenes.json): viñeta y grano de papel.
// Se pinta encima de las capas, sin leer la pantalla. El grano es estático (no
// usa TIME), así que también vale con movimiento reducido.
shader_type canvas_item;

uniform float vignette : hint_range(0.0, 1.0) = 0.2;
uniform float grain : hint_range(0.0, 0.2) = 0.04;
uniform float grain_size = 3.0;

void fragment() {
	float edge = smoothstep(0.32, 0.95, distance(UV * vec2(1.0, 0.8), vec2(0.5, 0.45)));
	float noise = fract(sin(dot(floor(FRAGCOORD.xy / grain_size), vec2(12.9898, 78.233))) * 43758.5453);
	float speck = (noise - 0.5) * grain;
	// Viñeta: negro con alfa. Grano: un poco de claro o de oscuro.
	vec3 tone = speck > 0.0 ? vec3(1.0, 0.97, 0.9) : vec3(0.0);
	float alpha = clamp(edge * vignette + abs(speck), 0.0, 1.0);
	COLOR = vec4(mix(tone, vec3(0.0), clamp(edge * vignette / max(alpha, 0.0001), 0.0, 1.0)), alpha);
}
