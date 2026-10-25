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

# --- Combate ---
## Gatillo mantenido.
var fire: bool = false
## true solo en el tick en que se apretó el gatillo.
var fire_pressed: bool = false
## Estado de apuntado deseado (el proveedor resuelve alternar/mantener).
var aim: bool = false
var reload: bool = false
var fire_mode: bool = false
var interact: bool = false
## Slot de arma pedido este tick (1–4) o −1.
var weapon_slot: int = -1
## Muescas de aumento del visor este tick (+ acercar, − alejar).
var zoom: int = 0


func _to_string() -> String:
	return "PlayerCommand(move=%s jump=%s sprint=%s crouch=%s lean=%.1f fire=%s aim=%s)" % [
		move, jump, sprint, crouch, lean, fire, aim]
