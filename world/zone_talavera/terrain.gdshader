shader_type spatial;
// Terreno de la isla: color por vértice (pasto, pasto seco, tierra, barro) con
// detalle de ruido a dos escalas para que no se vea liso, más oscuro en las hondonadas.

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.08;
uniform float fine_scale = 0.9;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = texture(detail, wpos.xz * detail_scale).r;
	float b = texture(detail, wpos.xz * fine_scale).r;
	float c = texture(detail, wpos.xz * 0.013 + vec2(0.37, 0.71)).r;
	vec3 col = COLOR.rgb;
	col *= mix(0.78, 1.12, a) * mix(0.85, 1.1, b);
	// Manchas grandes un poco más verdes o más secas
	col = mix(col, col * vec3(0.92, 1.05, 0.85), smoothstep(0.45, 0.7, c));
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.25;
}
