class_name StressOverlay
extends CanvasLayer
## Visión con estrés: desenfoque (más fuerte en los bordes), distorsión que ondula
## y late con el pulso, y algo de desaturación (sin oscurecer los bordes). Va en la capa 0: afecta la imagen del mundo,
## no al arma (capa 1) ni al HUD.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float pulse = 0.0;
uniform float blur_extra = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
	float r = length(d);
	float edge = smoothstep(0.15, 0.8, r);
	// Distorsión: la imagen ondula lento (más en los bordes) y "respira" con cada latido
	float w = amount * (0.35 + 0.65 * edge);
	vec2 warp = vec2(sin(uv.y * 9.0 + TIME * 1.7) + 0.6 * sin(uv.y * 23.0 - TIME * 2.9),
		cos(uv.x * 8.0 + TIME * 1.3) + 0.6 * cos(uv.x * 19.0 + TIME * 2.3)) * 0.0035 * w;
	warp += (uv - 0.5) * pulse * amount * -0.006;
	uv += warp;
	// Desenfoque: un poco en el centro, más en los bordes; el latido lo empuja
	float lod = amount * (0.35 + 1.9 * edge) + pulse * amount * 0.5;
	// Alto: más borroso; extremo: mucho más (en medio casi no suma)
	lod += blur_extra * (0.9 + 0.9 * edge);
	vec3 col = textureLod(screen_tex, uv, lod).rgb;
	// Doble imagen apenas corrida (visión que no termina de enfocar)
	vec3 ghost = textureLod(screen_tex, uv + vec2(0.004, 0.0015) * amount, lod + 0.5).rgb;
	col = mix(col, ghost, 0.22 * amount);
	float gray = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(gray), 0.2 * amount);
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
		_mat.set_shader_parameter("blur_extra", player.stress.blur_extra())
