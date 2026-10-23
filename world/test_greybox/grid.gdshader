// Material de "greybox" con grilla en coordenadas de mundo:
// línea fina cada 1 m y gruesa cada 5 m, para leer distancias y alturas.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.42, 0.43, 0.40);
uniform vec3 line_color : source_color = vec3(0.24, 0.25, 0.23);
uniform vec3 major_color : source_color = vec3(0.16, 0.17, 0.15);
uniform float roughness_value = 0.88;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
	vec2 fw = fwidth(p) * 1.2;
	vec2 l = 1.0 - smoothstep(vec2(width), vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p;
	if (n.y > 0.6) {
		p = world_pos.xz;
	} else if (n.x > n.z) {
		p = world_pos.zy;
	} else {
		p = world_pos.xy;
	}
	float minor = grid_line(p, 1.0, 0.012);
	float major = grid_line(p, 5.0, 0.03);
	vec3 col = mix(base_color, line_color, minor);
	col = mix(col, major_color, major);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
