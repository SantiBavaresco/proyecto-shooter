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

## Combate (F1)

```
Player
└─ Weapons (WeaponController)
   ├─ lógica en physics_tick(cmd): estados READY / RELOADING / HOLSTER / DRAW, disparo, apuntado
   └─ ViewmodelLayer (CanvasLayer 1) → SubViewport (mundo propio)
      ├─ Camera3D (FOV 62 → 52 apuntando), luces, ambiente
      └─ Rig → modelos de armas (WeaponModelBuilder)
```

### Modelos de armas por código
- `MeshKit` (`entities/weapons/mesh_kit.gd`) arma mallas con tres formas: perfil lateral extruido
  (`prism`), sección extruida a lo largo (`section`) y torno (`lathe`), con esquinas y bordes redondeados.
- `WeaponModelBuilder` reparte por arma (`model_params.shape` o el id) a `ModelsRifles`, `ModelsBolt`,
  `ModelsPistols` y `ModelsShotguns`, y tiene las piezas comunes: rieles, miras, punto rojo, visor,
  cargador curvo, materiales (madera con veta por ruido triplanar).
- Al final funde todas las mallas fijas por material (y por separado dentro de cada pieza animable):
  cada arma queda en unas 10 llamadas de dibujo.
- Visor del modelo: `tests/screenshots/model_viewer.tscn` saca de costado, tres cuartos y por la mira.

```

CombatWorld (uno por nivel, grupo "combat_world")
├─ proyectiles (Projectile): integración + raycast por tramo + rebotes
└─ pools: marcas, partículas, trazadoras, casquillos, sonidos 3D, luz de fogonazo
```

- Datos: `WeaponData` (`data/weapons`), `DamageModel` (`data/combat`), superficies en `core/combat/surface.gd`.
- Recibir daño: cualquier nodo con `apply_hit(info: HitInfo) -> bool` (devuelve true si fue derribado). La zona sale de la metadata `hit_zone` del cuerpo golpeado.
- Interacción: cualquier nodo con `interact(player)` y `get_interact_text() -> String` (clave de traducción con `%s` para la tecla).
- El jugador expone `apply_recoil(pitch, yaw, recovery)` y `last_look`; el arma expone `fov_mult()`, `move_speed_mult()`, `blocks_sprint()`.

### Estrés y fallas (F1.12)
- `Stress` (`core/stress.gd`, sin escena): valor 0–1 que sigue a un objetivo; niveles, pulso, deriva de la
  mira (`Player.aim_drift`, se suma a la cámara sin tocar yaw/pitch) y temblor. Hoy lo fijan las
  `TestZone` (`world/props/test_zone.gd`, grupo "test_zones", el jugador las consulta cada tick).
- `StressOverlay` (`ui/effects`): CanvasLayer 0 con shader que lee la pantalla; queda debajo del arma (capa 1).
- `ReloadPlan` (`entities/weapons/reload_plan.gd`): la recarga con cargador y cada destrabado se arman al
  empezar como claves (manos, cargador, mano de gancho, manija, golpes, eventos) en fracciones de la
  duración; `WeaponController` solo los evalúa. Acciones: reload, rack, misfire, stovepipe, double_feed.
- `WeaponSlot.condition` y `malfunction`; `WeaponController.fault_risk(estado)` da la probabilidad por disparo.
  R con falla → estado `CLEARING` (o `CYCLING` en cerrojos).
