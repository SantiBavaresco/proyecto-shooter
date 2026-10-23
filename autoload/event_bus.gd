extends Node
## Bus de eventos global: los sistemas se comunican por señales sin
## conocerse entre sí. Agregar señales acá a medida que hagan falta.

@warning_ignore_start("unused_signal")

## Cambio de estado global del juego (valores de GameState.State).
signal game_state_changed(previous: int, current: int)
## Alguna opción cambió (video, controles, audio, idioma).
signal settings_changed
## Cambió el idioma activo.
signal language_changed(locale: String)

## El jugador apareció en el mundo.
signal player_spawned(player: Node)
## Estamina actualizada (actual, máxima).
signal stamina_changed(current: float, maximum: float)
## El jugador aterrizó; fall_speed en m/s (positivo).
signal player_landed(fall_speed: float)
## Cambió la postura del jugador (valores de Player.Stance).
signal player_stance_changed(stance: int)

## Se guardó un reporte de bug (F12).
signal bug_report_saved(path: String)

@warning_ignore_restore("unused_signal")
