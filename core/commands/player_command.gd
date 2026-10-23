class_name PlayerCommand
extends RefCounted
## Intención del jugador para un tick de física.
##
## El controlador del jugador NUNCA lee Input directamente: recibe un
## PlayerCommand de un InputProvider (humano, bot de test o, a futuro,
## un cliente remoto en cooperativo). Así la lógica de movimiento es
## testeable y lista para red.

## Movimiento deseado. x: derecha (+) / izquierda (−). y: adelante (+) / atrás (−).
var move: Vector2 = Vector2.ZERO
## true solo en el tick en que se presionó saltar.
var jump: bool = false
## Mantener para correr.
var sprint: bool = false
## Mantener para agacharse (o deslizarse si venía corriendo).
var crouch: bool = false
## Inclinación: −1 izquierda, 0 nada, +1 derecha.
var lean: float = 0.0


func _to_string() -> String:
	return "PlayerCommand(move=%s jump=%s sprint=%s crouch=%s lean=%.1f)" % [move, jump, sprint, crouch, lean]
