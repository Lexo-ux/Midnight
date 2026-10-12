// La mirada de Akba: la capa akba_overlay (sobre negro puro) se suma a la
// escena, así que el negro no añade nada y no hace falta recortar nada. Las
// fisuras tornasolan y laten despacio; con movimiento reducido se quedan quietas.
shader_type canvas_item;
render_mode blend_add;

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform bool animate = true;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float t = animate ? TIME : 0.0;
	float pulse = 0.8 + 0.2 * sin(t * 1.6 + UV.x * 9.0 + UV.y * 5.0);
	vec3 hue = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + UV.x * 0.7 + UV.y * 0.3 + t * 0.04));
	vec3 iris = mix(base.rgb, base.rgb * hue * 1.7, 0.35);
	COLOR = vec4(iris * pulse * strength * base.a, 1.0);
}
