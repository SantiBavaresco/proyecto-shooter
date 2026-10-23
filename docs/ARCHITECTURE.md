# Arquitectura

## Principios

- **Simulación separada de presentación**: la lógica (movimiento, estamina, más adelante inventario y daño) no depende de nodos visuales. Requisito para guardado y cooperativo.
- **El jugador recibe comandos, no lee el teclado**: `InputProvider` → `PlayerCommand` → `Player`. Hoy hay dos proveedores (humano y bot de tests); a futuro, uno remoto para cooperativo.
- **Datos fuera del código**: parámetros en recursos `.tres` (`/data`), textos en `/localization/*.json`.
- **Sistemas desacoplados** por señales de `EventBus`.

## Carpetas

```
autoload/      singletons globales
core/          clases base: comandos, input, estamina, recursos de datos
entities/      jugador (y a futuro NPCs, enemigos, pickups)
world/         niveles; hoy la pista de pruebas
ui/            título, carga, pausa, opciones, HUD, tema visual
data/          parámetros (.tres)
localization/  textos por idioma (es, en)
tests/         runner, tests unitarios y de juego, bot, capturas
docs/          documentación y capturas
assets/        modelos, texturas, audio (Git LFS) — vacío en F0
```

## Autoloads (en orden de carga)

| Nombre | Responsabilidad |
|---|---|
| `EventBus` | Señales globales |
| `Settings` | Opciones del jugador (`user://settings.cfg`), registro de acciones de input y remapeo |
| `Loc` | Carga de idiomas desde JSON → `TranslationServer` (`tr("clave")`) |
| `AudioManager` | Buses `Music`, `Ambience`, `SFX_World`, `UI`, `Voice`; silencio del mundo en pausa |
| `SaveManager` | Guardado de partidas (estructura; se implementa en F7) |
| `GameState` | Estados `BOOT → TITLE → LOADING → PLAYING ⇄ PAUSED`, cambio de escenas, pausa |
| `DebugTools` | Overlay F1 y reporte de bug F12 |

## Jugador (`entities/player`)

```
Player (CharacterBody3D, origen en los pies)
├─ Collision        cápsula: 1,8 m parado / 1,1 m agachado
├─ BodyShadow       cápsula invisible que solo proyecta sombra (TODO-ASSET: player_body)
├─ HumanInput       InputProvider (lo crea el script si no hay otro)
└─ Head (top_level, sin interpolación)
   └─ Pitch → Lean → Camera3D
```

- Física a 60 Hz con **interpolación de física** activada en el proyecto. La cabeza no se interpola: en cada frame se ubica sobre la posición interpolada del cuerpo. La mirada se aplica cada frame (sin latencia de física).
- Posturas: `STANDING`, `CROUCHING`, `SLIDING`. Para pararse se verifica espacio con `test_move`.
- Inclinación limitada por un raycast lateral para no meter la cámara en las paredes.
- Parámetros: `data/player/player_movement_default.tres` (`PlayerMovementConfig`).

## Tests

- `tests/test_runner.tscn` corre todas las suites de `SUITES` y sale con código 0/1.
- `TestCase` (base) con asserts y esperas por frames.
- `BotInputProvider` maneja al jugador real en la pista de pruebas.
- Correr con `--fixed-fps 60`: cada frame avanza exactamente 1/60 s, así los tests son deterministas y rápidos.
