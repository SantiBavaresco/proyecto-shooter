class_name WeaponData
extends Resource
## Definición de un arma (datos, no código). Archivos en res://data/weapons/

@export var id: String = ""
## Clave de traducción del nombre.
@export var name_key: String = ""
## Slot por defecto: 1 y 2 armas largas, 3 pistola, 4 cuchillo.
@export var slot: int = 1
## Familia del modelo procedural: "pistol", "smg", "rifle_ar", "rifle_ak",
## "rifle_battle", "bolt", "shotgun_sxs", "shotgun_ou".
@export var model: String = "rifle_battle"
## Parámetros del modelo (largo de caño, culata, cargador...). Ver WeaponModelBuilder.
@export var model_params: Dictionary = {}
## Mira: "iron", "red_dot", "scope", "bead".
@export var sight: String = "iron"
## Aumento del visor (solo sight = "scope").
@export var scope_mag: float = 0.0
## Visor variable: aumento máximo (la rueda del mouse lo regula entre scope_mag
## y este valor). 0 = aumento fijo.
@export var scope_mag_max: float = 0.0
## Retícula del visor: "cross", "chevron", "duplex".
@export var reticle: String = "duplex"
## Calibre (texto para mostrar).
@export var caliber: String = ""

@export_group("Mecanismo")
## "magazine" (cargador), "break" (escopeta que se quiebra), "rounds" (cartucho a cartucho).
@export var reload_type: String = "magazine"
## Recarga "rounds": tiempo por cartucho.
@export var round_time: float = 0.4
## Recarga "rounds" con el arma vacía: carga un peine completo en reload_time_empty.
@export var clip_reload: bool = false
## Cerrojo manual: hay que accionarlo después de cada disparo.
@export var bolt_action: bool = false
@export var cycle_time: float = 0.8

@export_group("Disparo")
## Modos disponibles: "semi", "auto".
@export var fire_modes: PackedStringArray = PackedStringArray(["semi"])
@export var rpm: float = 400.0
## Daño por proyectil a velocidad de boca.
@export var damage: float = 30.0
@export var pellets: int = 1
## Velocidad de boca (m/s).
@export var muzzle_velocity: float = 400.0
## Resistencia del aire: v -= drag · v² · dt
@export var drag: float = 0.0004
## Máximo de rebotes por proyectil.
@export var max_ricochets: int = 2
## Una trazadora cada N disparos (0 = nunca).
@export var tracer_every: int = 0
## Para escopetas de dos caños: disparos antes de recargar sin importar el cargador.
@export var mag_size: int = 30
@export var start_reserve: int = 90

@export_group("Precisión (grados)")
@export var spread_hip: float = 2.5
@export var spread_ads: float = 0.15
## Dispersión de los perdigones (escopeta), se suma.
@export var pellet_spread: float = 0.0
## Multiplicador extra al moverse, en el aire y agachado.
@export var spread_move_mult: float = 2.0
@export var spread_air_mult: float = 3.0
@export var spread_crouch_mult: float = 0.7

@export_group("Retroceso")
## Subida de la cámara por disparo (grados).
@export var recoil_pitch: float = 1.2
## Desvío lateral aleatorio máximo (grados).
@export var recoil_yaw: float = 0.4
## Fracción del retroceso que la cámara recupera sola al dejar de disparar.
@export var recoil_recovery: float = 0.6
## Patada visual del arma hacia atrás (m) y hacia arriba (grados).
@export var kick_back: float = 0.05
@export var kick_rot: float = 4.0
## Multiplicador de retroceso apuntando.
@export var recoil_ads_mult: float = 0.7

@export_group("Tiempos (s)")
@export var reload_time: float = 2.2
@export var reload_time_empty: float = 2.8
@export var ads_time: float = 0.22
@export var draw_time: float = 0.35
@export var holster_time: float = 0.2

@export_group("Cámara al apuntar")
## FOV de la cámara del mundo al apuntar = FOV × este valor.
@export var ads_fov_mult: float = 0.85
## Distancia ojo–mira al apuntar (m). 0 = automática según el modelo.
@export var eye_relief: float = 0.0

@export_group("Sonido sintético")
## Parámetros del sonido de disparo generado por código (hasta tener audio real).
@export var sfx_tail: float = 0.25
@export var sfx_body_hz: float = 90.0
@export var sfx_volume_db: float = -2.0


## Poder de penetración (1 ≈ fusil de asalto): de la energía del proyectil
## (daño × velocidad). Una pistola ~0,3; un perdigón ~0,15; un .308 de cerrojo ~2.
func penetration_power() -> float:
	return damage * muzzle_velocity / 30000.0


func seconds_per_shot() -> float:
	return 60.0 / maxf(rpm, 1.0)


func has_mode(mode: String) -> bool:
	return fire_modes.has(mode)
