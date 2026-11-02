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

## --- Combate ---
## Un disparo propio salió (para HUD, sonido, IA que escucha en fases siguientes).
signal weapon_fired(weapon_id: String)
## Un proyectil del jugador impactó algo que recibe daño.
signal hit_confirmed(info: HitInfo, killed: bool)
## Estado del arma actual para el HUD.
signal weapon_state_changed(state: Dictionary)
## Entró o salió del apuntado.
signal aim_changed(aiming: bool)
## Texto de interacción bajo la mira ("" = nada).
signal interact_hint_changed(text: String)
## Mensaje breve en pantalla.
signal toast(text: String)

## --- Inventario y salud ---
## Algo cambió en el inventario del jugador (mochila, equipo, plata, ranuras rápidas).
signal inventory_changed
## Empezó / terminó de usar un consumible (ok = false si se cortó o no había).
signal item_use_started(item_id: String, duration: float)
signal item_use_finished(item_id: String, ok: bool)
## Salud del jugador (actual, máxima, nivel de sangrado 0–3).
signal health_changed(current: float, maximum: float, bleeding: int)
## El jugador recibió daño (para el indicador de dirección y la viñeta).
signal player_damaged(amount: float)
## El jugador murió.
signal player_died
## Se pidió abrir el inventario con un contenedor al lado (null = solo la mochila).
signal loot_requested(container: Object)
## Se pidió tirar al suelo una pila sacada del inventario.
signal item_dropped(stack: Object)
## Se guardó un reporte de bug (F12).
signal bug_report_saved(path: String)

@warning_ignore_restore("unused_signal")
