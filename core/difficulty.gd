class_name Difficulty
extends RefCounted
## Dificultad por habilidad de los enemigos (no por vida ni daño: una bala hace lo
## mismo en cualquier nivel). Cambia cuánto tardan en verte y reaccionar, cuánto
## erran, cómo se cubren y si flanquean, se avisan o tiran granadas.

enum Level { NOVATO, REGULAR, VETERANO }

const NAMES := ["difficulty.novato", "difficulty.regular", "difficulty.veterano"]

## Perfil de cada nivel.
##  sight_range: metros a los que ve a alguien parado a plena vista.
##  fov: ángulo de visión (grados, total).
##  notice: segundos para darse cuenta de alguien a 20 m a plena vista.
##  reaction: segundos entre verte y el primer tiro.
##  aim_error: error de puntería inicial (grados); baja mientras te sigue viendo
##    hasta aim_error × settle_floor.
##  settle_time: segundos que tarda en asentar la puntería.
##  burst: tiros por ráfaga (mín, máx) con armas automáticas; burst_pause: pausa (s).
##  hearing: multiplicador del radio al que oye disparos y pasos.
##  cover: probabilidad de buscar cobertura al recibir fuego / recargar.
##  flank: probabilidad de flanquear cuando te perdió de vista.
##  grenade: probabilidad por intento de tirar una granada si estás a cubierto.
##  callout: segundos que tarda en avisar a sus compañeros (−1 = no avisa).
##  retreat_hp: vida con la que se retira a cubrirse y curarse.
##  head_aim: probabilidad de apuntar a la cabeza en vez del pecho.
##  spread: dispersión de los tiros en metros a 1 m (crece con la raíz de la distancia:
##    a 5 m ×2,2, a 30 m ×5,5, a 60 m ×7,7). De cerca erran más que con un error
##    angular fijo y de lejos alguna pegan.
##  move_shoot: puede disparar mientras se mueve.
const PROFILES := [
	{"sight_range": 40.0, "fov": 110.0, "notice": 1.4, "reaction": 0.95, "aim_error": 8.0, "spread": 0.45, "settle_floor": 0.7,
		"settle_time": 3.5, "burst": [2, 5], "burst_pause": 1.1, "hearing": 0.7, "cover": 0.5, "flank": 0.0,
		"grenade": 0.0, "callout": 2.0, "retreat_hp": 0.0, "head_aim": 0.02, "move_shoot": false},
	{"sight_range": 55.0, "fov": 130.0, "notice": 0.9, "reaction": 0.6, "aim_error": 5.5, "spread": 0.3, "settle_floor": 0.55,
		"settle_time": 2.5, "burst": [3, 6], "burst_pause": 0.8, "hearing": 1.0, "cover": 0.8, "flank": 0.35,
		"grenade": 0.12, "callout": 1.0, "retreat_hp": 30.0, "head_aim": 0.08, "move_shoot": false},
	{"sight_range": 70.0, "fov": 150.0, "notice": 0.55, "reaction": 0.32, "aim_error": 4.0, "spread": 0.2, "settle_floor": 0.45,
		"settle_time": 1.6, "burst": [3, 7], "burst_pause": 0.55, "hearing": 1.25, "cover": 0.9, "flank": 0.7,
		"grenade": 0.3, "callout": 0.4, "retreat_hp": 40.0, "head_aim": 0.18, "move_shoot": true},
]


static func profile(level: int) -> Dictionary:
	return PROFILES[clampi(level, 0, PROFILES.size() - 1)]


static func name_key(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]
