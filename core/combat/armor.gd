class_name Armor
extends RefCounted
## Casco y chaleco: si frenan la bala, cuánto daño pasa y cuánto se gastan.
##
##  - Cada pieza tiene una clase (1–5). Cada clase frena hasta cierto "poder de
##    penetración" (WeaponData.penetration_power: pistola ~0,3, fusil de asalto ~1,
##    .308 de cerrojo ~3), que baja con el desgaste.
##  - La bala pasa con una probabilidad que sube suave alrededor de ese límite.
##  - Si la frena: golpe contuso (poco daño, sin sangrado, nunca letal). Si pasa:
##    casi todo el daño.
##  - Cobertura: el casco no tapa la cara (cubre parte de los tiros a la cabeza) y el
##    chaleco cubre la mayor parte del torso. Brazos y piernas no tienen protección.
## Sin estado ni escena (lo usan el jugador y los enemigos por igual).

## Poder de penetración que frena cada clase, con la pieza nueva.
const CLASS_RATING := [0.0, 0.25, 0.42, 0.75, 1.3, 2.0]
const HELMET_COVERAGE := 0.55
const VEST_COVERAGE := 0.85


## Resultado de un impacto contra una pieza.
class Result:
	## La pieza estaba en el camino de la bala.
	var covered: bool = false
	var penetrated: bool = true
	var damage: float = 0.0
	## Desgaste que sufre la pieza (se resta de su condición, 0–1).
	var wear: float = 0.0


static func rating(armor_class: int, condition: float) -> float:
	var r := float(CLASS_RATING[clampi(armor_class, 0, CLASS_RATING.size() - 1)])
	return r * (0.35 + 0.65 * clampf(condition, 0.0, 1.0))


## Probabilidad de que la bala atraviese.
static func penetration_chance(pen: float, armor_class: int, condition: float) -> float:
	var r := rating(armor_class, condition)
	if r <= 0.0:
		return 1.0
	return clampf(smoothstep(0.75, 1.3, pen / r), 0.02, 0.98)


## Pieza que cubre la zona ("helmet" para la cabeza, "armor" para el torso, "" si nada).
static func slot_for_zone(zone: String) -> String:
	if zone.begins_with("head"):
		return "helmet"
	if zone == "torso":
		return "armor"
	return ""


## Resuelve un impacto. `pen` es el poder de penetración de la bala al llegar
## (penetration_power × fracción de velocidad que le queda).
static func resolve(damage: float, pen: float, zone: String, armor_class: int, condition: float,
		rng: RandomNumberGenerator) -> Result:
	var res := Result.new()
	res.damage = damage
	if armor_class <= 0:
		return res
	var cov := HELMET_COVERAGE if zone.begins_with("head") else VEST_COVERAGE
	if rng.randf() > cov:
		return res
	res.covered = true
	var r := rating(armor_class, condition)
	var x := pen / maxf(r, 0.01)
	res.penetrated = rng.randf() < penetration_chance(pen, armor_class, condition)
	if res.penetrated:
		res.damage = damage * 0.85
	else:
		# Golpe contuso: más fuerte cuanto más cerca estuvo de pasar
		res.damage = damage * clampf(0.08 + 0.22 * x, 0.08, 0.3)
	res.wear = clampf(0.012 + 0.03 * x, 0.01, 0.09)
	return res
