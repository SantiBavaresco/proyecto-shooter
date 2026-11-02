class_name Vitals
extends RefCounted
## Salud y sangrado del jugador (sin dependencias de escena, testeable).
##
##  - Sangrado en niveles 0–3: saca vida por segundo hasta que se venda.
##  - Comida y botiquines pueden dar regeneración por un rato.
##  - Energizante: más regeneración de estamina por un rato (lo aplica el jugador).
## Hambre, sed y sueño llegan en F5.

const MAX_HEALTH := 100.0
## Vida por segundo según el nivel de sangrado.
const BLEED_DPS := [0.0, 0.7, 1.6, 3.0]
const BLEED_MAX := 3

var health: float = MAX_HEALTH
var bleeding: int = 0
var dead: bool = false
## Regeneración de vida (por segundo) y segundos que le quedan.
var regen_rate: float = 0.0
var regen_left: float = 0.0
## Regeneración extra de estamina (multiplicador sumado) y segundos que le quedan.
var stamina_boost: float = 0.0
var stamina_boost_left: float = 0.0


func ratio() -> float:
	return health / MAX_HEALTH


## Daño directo; "bleed" suma niveles de sangrado. Devuelve true si murió.
func damage(amount: float, bleed := 0) -> bool:
	if dead:
		return false
	health = maxf(0.0, health - amount)
	bleeding = clampi(bleeding + bleed, 0, BLEED_MAX)
	if health <= 0.0:
		dead = true
		return true
	return false


func heal(amount: float) -> void:
	if not dead:
		health = minf(MAX_HEALTH, health + amount)


## Aplica los efectos de un consumible (ver data/items/items.json).
func apply_effects(fx: Dictionary) -> void:
	if fx.has("heal"):
		heal(float(fx["heal"]))
	if fx.has("bleed"):
		bleeding = clampi(bleeding + int(fx["bleed"]), 0, BLEED_MAX)
	var dur := float(fx.get("duration", 0.0))
	if fx.has("regen") and dur > 0.0:
		regen_rate = maxf(regen_rate if regen_left > 0.0 else 0.0, float(fx["regen"]))
		regen_left = maxf(regen_left, dur)
	if fx.has("stamina_regen") and dur > 0.0:
		stamina_boost = maxf(stamina_boost if stamina_boost_left > 0.0 else 0.0, float(fx["stamina_regen"]))
		stamina_boost_left = maxf(stamina_boost_left, dur)


## Avanza el tiempo. Devuelve true si murió en este tick.
func tick(delta: float) -> bool:
	if dead:
		return false
	if regen_left > 0.0:
		regen_left -= delta
		heal(regen_rate * delta)
	if stamina_boost_left > 0.0:
		stamina_boost_left -= delta
		if stamina_boost_left <= 0.0:
			stamina_boost = 0.0
	if bleeding > 0:
		return damage(float(BLEED_DPS[bleeding]) * delta)
	return false


func reset() -> void:
	health = MAX_HEALTH
	bleeding = 0
	dead = false
	regen_left = 0.0
	stamina_boost_left = 0.0
	stamina_boost = 0.0


func to_dict() -> Dictionary:
	return {"health": health, "bleeding": bleeding}


func load_dict(d: Dictionary) -> void:
	health = float(d.get("health", MAX_HEALTH))
	bleeding = int(d.get("bleeding", 0))
	dead = health <= 0.0
