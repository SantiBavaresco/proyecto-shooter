// Ocular de un visor con aumento real ("imagen en imagen"): muestra lo que
// ve una segunda cámara con FOV reducido, más la retícula y el viñeteado
// del ocular. Sin apuntar (desde la cadera) se ve la misma imagen pero como en un
// visor real lejos del ojo: chica, corrida según el ángulo, deformada y borrosa.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D scope_tex : source_color, filter_linear;
// 0 = sin apuntar (vidrio), 1 = apuntando (imagen aumentada)
uniform float active = 0.0;
// 0 cruz fina, 1 chevrón (tipo visor soviético), 2 duplex (cruz gruesa afuera, fina al centro)
uniform int reticle = 2;
uniform vec4 reticle_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
// 1 = mostrar la imagen deformada cuando no se apunta (desde la cadera)
uniform float hip_view = 0.0;

varying vec3 lens_fwd;

void vertex() {
	// Eje del visor (hacia atrás, hacia el ojo) en espacio de cámara
	lens_fwd = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
}

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

	// Desde la cadera: la pupila de salida (círculo con imagen) se corre según de
	// dónde se mira, y la imagen se deforma (barril) y se ve borrosa
	float hip = hip_view * (1.0 - active);
	if (hip > 0.001) {
		vec3 v = normalize(VIEW);
		vec2 off = (v.xy - lens_fwd.xy) * 1.6;
		off = clamp(off, vec2(-0.45), vec2(0.45));
		vec2 cd = c - off * 0.5;
		float rd = length(cd);
		vec2 uvd = vec2(0.5) + cd * (0.55 + 1.6 * rd * rd);
		vec3 blur = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			float a = float(i) * 1.5708 + 0.4;
			blur += texture(scope_tex, uvd + vec2(cos(a), sin(a)) * 0.012).rgb;
		}
		blur *= 0.25;
		// Bordes de color (aberración) en el contorno de la pupila
		float pupil = 1.0 - smoothstep(0.12, 0.3, rd);
		vec3 tint = vec3(1.0, 0.92, 0.85) * mix(0.55, 0.9, pupil);
		vec3 hipcol = blur * tint * pupil;
		// La retícula también se ve, corrida y deformada
		vec2 rc = cd * (1.1 + 3.0 * rd * rd);
		float rh = max(line(rc.x, 0.006), line(rc.y, 0.006)) * pupil;
		hipcol = mix(hipcol, reticle_color.rgb, rh * 0.8);
		col = mix(col, max(glass * 0.6, hipcol), hip);
	}

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
