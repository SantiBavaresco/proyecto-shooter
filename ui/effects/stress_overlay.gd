class_name StressOverlay
extends CanvasLayer
## Visión con estrés: desenfoque (más fuerte en los bordes), algo de desaturación
## y viñeta que late con el pulso. Va en la capa 0: afecta la imagen del mundo,
## no al arma (capa 1) ni al HUD.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
	float r = length(d);
	float edge = smoothstep(0.18, 0.8, r);
	// Desenfoque: un poco en el centro, mucho en los bordes; el latido lo empuja
	float lod = amount * (0.35 + 1.9 * edge) + pulse * amount * 0.5;
	vec3 col = textureLod(screen_tex, uv, lod).rgb;
	// Doble imagen apenas corrida (visión que no termina de enfocar)
	vec3 ghost = textureLod(screen_tex, uv + vec2(0.004, 0.0015) * amount, lod + 0.5).rgb;
	col = mix(col, ghost, 0.22 * amount);
	float gray = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(gray), 0.3 * amount);
	col *= 1.0 - amount * edge * (0.42 + 0.25 * pulse);
	COLOR = vec4(col, 1.0);
}
"""

var player: Player
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _process(_delta: float) -> void:
	if player == null:
		return
	var a := player.stress.value
	_rect.visible = a > 0.01
	if _rect.visible:
		_mat.set_shader_parameter("amount", a)
		_mat.set_shader_parameter("pulse", player.stress.pulse())
