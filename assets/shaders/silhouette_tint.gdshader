// Tiñe una silueta de dos canales: el cuerpo va en rojo puro y el rasgo fijo en
// verde puro dentro del SVG. Velo 0 pinta ambos de negro; Velo 1, con los
// colores de npcs.json.
shader_type canvas_item;

uniform vec4 body_color : source_color = vec4(0.07, 0.07, 0.08, 1.0);
uniform vec4 trait_color : source_color = vec4(0.07, 0.07, 0.08, 1.0);

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	float total = max(mask.r + mask.g, 0.0001);
	vec3 tint = (body_color.rgb * mask.r + trait_color.rgb * mask.g) / total;
	COLOR = vec4(tint, mask.a * COLOR.a);
}
