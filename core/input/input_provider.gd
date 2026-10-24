class_name InputProvider
extends Node
## Fuente de comandos para el jugador. Clase base abstracta.
##
## Implementaciones:
##  - HumanInputProvider: teclado, mouse y joystick.
##  - BotInputProvider (tests): comandos programados por código.


## Devuelve el comando para este tick de física.
func poll_command(_delta: float) -> PlayerCommand:
	return PlayerCommand.new()


## Devuelve y resetea la rotación de mirada acumulada (radianes).
## x: giro horizontal (+ derecha), y: giro vertical (+ abajo).
## Se consume en _process (cada frame) para que la mirada no tenga latencia.
func consume_look(_delta: float) -> Vector2:
	return Vector2.ZERO


## El juego pide salir del apuntado (ej. al correr o recargar con alternar).
func cancel_aim() -> void:
	pass
