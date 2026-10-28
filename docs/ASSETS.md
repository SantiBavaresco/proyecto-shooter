# Assets

Registro obligatorio de **cada** asset externo: fuente, autor, licencia y si permite uso comercial.
Antes de sumar uno, verificar la licencia (ver prompt maestro, sección 4).

| ID | Archivo | Fuente | Autor | Licencia | Comercial | Notas |
|---|---|---|---|---|---|---|
| `weapon_ak74u` | `assets/models/ak74u/ak74u.glb` | [Sketchfab: "AK74U \| FREE ANIMATION."](https://sketchfab.com/3d-models/ak74u-free-animation-2ab66220c48b465e9501067667965569) | BURNER ([Alexander_Ovelar](https://sketchfab.com/Alexander_Ovelar)) | CC-BY 4.0 | Sí, con atribución | Carabina AR-74K (prueba F1.18): arma, brazos Mixamo y 7 animaciones. Desde F1.19 sus brazos son también las manos de todas las armas. ~69 mil triángulos. Crédito obligatorio en los créditos del juego |
| `sfx_gunshots` | `assets/audio/weapons/shot_<calibre>_<n>.wav` | Generados por código (`tools/audio/gen_gunshots.py`) | Propio | — | Sí | 11 calibres × 3 variantes, 44,1 kHz estéreo |

## Placeholders pendientes (`TODO-ASSET` en el código)

| ID | Dónde |
|---|---|
| `title_background` | `ui/title/title_background.gd` |
| `loading_background` | `ui/loading/loading_screen.gd` |
| `player_body` | `entities/player/player.gd` |
| Un modelo real por arma (25, ver `data/weapons/catalog.json`) | `entities/weapons/models_*.gd` (geometría por código con la silueta del arma real; reemplazables por .glb respetando marcadores y piezas) |
| `fps_arms` | `entities/weapons/arms_builder.gd` (brazos por código con dedos; reemplazable por un modelo con huesos) |
| `vfx_muzzle_flash` | `entities/weapons/weapon_controller.gd` |
| `decal_bullet_holes` | `systems/combat/combat_world.gd` |
| `sfx_weapons` (mecánica), `sfx_impacts` | `core/audio/synth_sfx.gd` |
| `target_paper` | `world/props/paper_target.gd` |

