class_name PlayerMovementConfig
extends Resource
## Parámetros de movimiento del jugador (datos, no código).
## El archivo por defecto es res://data/player/player_movement_default.tres

@export_group("Velocidades (m/s)")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
@export var crouch_speed: float = 2.0
@export var air_control: float = 0.3
@export var ground_accel: float = 16.0
@export var ground_decel: float = 20.0

@export_group("Salto y gravedad")
## Velocidad inicial del salto. Con gravity_up_mult 2.0 da ~1,1 m de altura.
@export var jump_velocity: float = 6.6
## Multiplicadores sobre la gravedad del proyecto (9,8). La gravedad real
## se siente flotante en un juego; subir rápido y caer más rápido da peso.
@export var gravity_up_mult: float = 2.0
@export var gravity_down_mult: float = 2.6
## Velocidad máxima de caída (m/s).
@export var max_fall_speed: float = 50.0
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12

@export_group("Altura (m)")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var capsule_radius: float = 0.35
## Distancia de los ojos al techo de la cápsula.
@export var eye_from_top: float = 0.14
@export var stance_lerp_speed: float = 10.0

@export_group("Deslizamiento")
@export var slide_start_speed: float = 8.5
@export var slide_duration: float = 0.85
@export var slide_min_entry_speed: float = 5.2
@export var slide_cooldown: float = 0.6
@export var slide_steer: float = 1.5

@export_group("Inclinación")
@export var lean_offset: float = 0.38
@export var lean_angle_deg: float = 11.0
@export var lean_speed: float = 6.0

@export_group("Estamina")
@export var stamina_max: float = 100.0
@export var stamina_regen: float = 18.0
@export var stamina_regen_delay: float = 1.0
@export var stamina_recover_threshold: float = 25.0
@export var sprint_cost_per_sec: float = 12.0
@export var jump_cost: float = 10.0
@export var slide_cost: float = 15.0

@export_group("Cámara")
@export var bob_frequency: float = 1.8
@export var bob_amplitude: float = 0.035
@export var sprint_fov_bonus: float = 4.0
@export var slide_fov_bonus: float = 7.0
@export var fov_lerp_speed: float = 8.0
