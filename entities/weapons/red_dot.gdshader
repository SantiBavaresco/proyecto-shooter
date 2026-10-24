// Lente de mira red dot "real": el punto está proyectado al infinito sobre
// el eje del arma. No es un dibujo fijo en pantalla: si el arma se mueve
// (retroceso, balanceo) el punto se mueve con su eje, y solo se ve a través
// del vidrio de la mira.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 dot_color : source_color = vec4(1.0, 0.12, 0.06, 1.0);
// Radio angular del punto (radianes). 0.0018 rad ≈ 6 MOA.
uniform float dot_radius = 0.0022;
uniform float dot_glow = 3.5;
uniform vec4 tint : source_color = vec4(0.45, 0.65, 0.75, 0.08);

varying vec3 sight_forward;

void vertex() {
	// Eje del arma (−Z local) en espacio de cámara
	sight_forward = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
}

void fragment() {
	// Lente redonda
	if (length(UV - vec2(0.5)) > 0.5) {
		discard;
	}
	vec3 ray = normalize(-VIEW);
	float ang = acos(clamp(dot(ray, sight_forward), -1.0, 1.0));
	float core = 1.0 - smoothstep(dot_radius * 0.55, dot_radius, ang);
	float halo = (1.0 - smoothstep(dot_radius, dot_radius * 2.5, ang)) * 0.25;
	float d = clamp(core + halo, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, dot_color.rgb * dot_glow, d);
	ALPHA = max(tint.a, d);
}
