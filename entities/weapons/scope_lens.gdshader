// Ocular de un visor con aumento real ("imagen en imagen"): muestra lo que
// ve una segunda cámara con FOV reducido, más la retícula y el viñeteado
// del ocular. Sin apuntar se ve como vidrio oscuro.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D scope_tex : source_color, filter_linear;
// 0 = sin apuntar (vidrio), 1 = apuntando (imagen aumentada)
uniform float active = 0.0;
// 0 cruz fina, 1 chevrón (tipo visor soviético), 2 duplex (cruz gruesa afuera, fina al centro)
uniform int reticle = 2;
uniform vec4 reticle_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.6, w, abs(d));
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	if (r > 1.0) {
		discard;
	}
	vec3 glass = vec3(0.03, 0.04, 0.05) + vec3(0.12, 0.16, 0.2) * smoothstep(0.9, 0.2, length(c - vec2(-0.15, -0.18)) * 2.0) * 0.4;
	vec3 img = texture(scope_tex, UV).rgb;
	vec3 col = mix(glass, img, active);

	// Retícula (solo con imagen)
	float ret = 0.0;
	if (reticle == 0) {
		ret = max(line(c.x, 0.0025), line(c.y, 0.0025));
	} else if (reticle == 1) {
		// Chevrón: dos líneas en V por debajo del centro + línea horizontal
		vec2 q = c;
		float v = 0.0;
		if (q.y > 0.0 && q.y < 0.06) {
			v = line(abs(q.x) - q.y * 0.6, 0.004);
		}
		ret = max(v, line(q.y, 0.0022) * step(0.08, abs(q.x)) * step(abs(q.x), 0.42));
		ret = max(ret, line(q.x, 0.004) * step(0.08, q.y));
	} else {
		float thin = max(line(c.x, 0.002), line(c.y, 0.002));
		float thick = max(line(c.x, 0.008) * step(0.18, abs(c.y)), line(c.y, 0.008) * step(0.18, abs(c.x)));
		ret = max(thin, thick);
	}
	col = mix(col, reticle_color.rgb, ret * active);

	// Viñeteado del ocular: borde negro (eye box)
	float vig = smoothstep(0.72, 1.0, r);
	col *= 1.0 - vig;
	ALBEDO = col;
}
