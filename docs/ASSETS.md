# Assets

Registro obligatorio de **cada** asset externo: fuente, autor, licencia y si permite uso comercial.
Antes de sumar uno, verificar la licencia (ver prompt maestro, sección 4).

| ID | Archivo | Fuente | Autor | Licencia | Comercial | Notas |
|---|---|---|---|---|---|---|
| `weapon_ak74u` | `assets/models/ak74u/ak74u.glb` | [Sketchfab: "AK74U \| FREE ANIMATION."](https://sketchfab.com/3d-models/ak74u-free-animation-2ab66220c48b465e9501067667965569) | BURNER ([Alexander_Ovelar](https://sketchfab.com/Alexander_Ovelar)) | CC-BY 4.0 | Sí, con atribución | Carabina AR-74K (prueba F1.18): arma, brazos Mixamo y 7 animaciones. Desde F1.19 sus brazos son también las manos de todas las armas. ~69 mil triángulos. Crédito obligatorio en los créditos del juego |
| `sfx_gunshots` | `assets/audio/weapons/shot_<calibre>_<n>.wav` | Generados por código (`tools/audio/gen_gunshots.py`) | Propio | — | Sí | 11 calibres × 3 variantes, 44,1 kHz estéreo |
| `weapon_akm` | `assets/models/weapons/akmn/akmn.glb` | [Sketchfab: "AKMN"](https://sketchfab.com/3d-models/akmn-c1e6d788ecc84d33962027a40046134d) | Kihan_lee | CC-BY 4.0 | Sí, con atribución | Modelo del Fusil AR-M (F1.23) |
| `weapon_m14` | `assets/models/weapons/m14/m14.glb` | [Sketchfab: "M14"](https://sketchfab.com/3d-models/m14-e23e0f1970b44165a06b684b2214f9df) | ardickasaretas | Sketchfab Standard | Sí (no se redistribuye suelto) | Modelo del Fusil M-14E (piezas por hueso, se pasan a mallas fijas al cargar) |
| `weapon_xm2010` | `assets/models/weapons/xm2010/xm2010.glb` | [Sketchfab: "Remington XM2010"](https://sketchfab.com/3d-models/remington-xm2010-4038f2ba4d5547578f17fcb7d79716e0) | ardickasaretas | Sketchfab Standard | Sí (no se redistribuye suelto) | Rifle R-700 SR |
| `weapon_sten` | `assets/models/weapons/sten/sten.glb` | [Sketchfab: "Submachine gun STEN MK2"](https://sketchfab.com/3d-models/submachine-gun-sten-mk2-9842e3b67fc242719f22f942f5591faf) | Modest3D | Sketchfab Standard | Sí (no se redistribuye suelto) | Subfusil ST-2 |
| `weapon_pleter91` | `assets/models/weapons/pleter91/pleter91.glb` | [Sketchfab: "Pleter 91 Submachine Gun"](https://sketchfab.com/3d-models/pleter-91-submachine-gun-493ca72005ff4db8b3828b2671c98693) | thecalcman | Sketchfab Standard | Sí (no se redistribuye suelto) | Subfusil PT-91 |
| `weapon_andrews` | `assets/models/weapons/andrews/andrews.glb` | [Sketchfab: "Andrews Machine Carbine"](https://sketchfab.com/3d-models/andrews-machine-carbine-379c346d465c44d5aac19828b89cea46) | the_table | Sketchfab Standard | Sí (no se redistribuye suelto) | Subfusil casero AC-9 |
| `weapon_revolver` | `assets/models/weapons/revolver/revolver.glb` | [Sketchfab: "Ruger Speed-Six Revolver"](https://sketchfab.com/3d-models/ruger-speed-six-revolver-bafae43402c941f6b78f3104983e7660) | Tomas Dvorak | Sketchfab Standard | Sí (no se redistribuye suelto) | Revólver RS-6 |
| `npc_fsb` | `assets/models/npc/fsb/fsb.glb` | [Sketchfab: "FSB Operator"](https://sketchfab.com/3d-models/fsb-operator-43a561e941704eefb1ab0614be4f0049) | Mateusz Woliński | CC-BY 4.0 | Sí, con atribución | Personaje de prueba |
| `npc_swat` | `assets/models/npc/swat/swat.glb` | [Sketchfab: "S.W.A.T. Operator"](https://sketchfab.com/3d-models/swat-operator-9e82fabf26194896b5ad4a364d864eab) | Mateusz Woliński | CC-BY 4.0 | Sí, con atribución | Personaje de prueba |
| `npc_swat_remaster` | `assets/models/npc/swat_remaster/swat_remaster.glb` | [Sketchfab: "S.W.A.T. Operator- Remastered"](https://sketchfab.com/3d-models/swat-operator-remastered-732d2eec5a0c456bafedd08af35134c3) | Mateusz Woliński | Sketchfab Standard | Sí (no se redistribuye suelto) | Personaje de prueba |
| `npc_swat_special` | `assets/models/npc/swat_special/swat_special.glb` | [Sketchfab: "S.W.A.T. Operator- 4k Followers Special Remaster"](https://sketchfab.com/3d-models/swat-operator-4k-followers-special-remaster-f6923917c8014578b1c1cb2b4c249268) | Mateusz Woliński | CC-BY 4.0 | Sí, con atribución | Personaje de prueba |
| `props_crates_barrels` | `assets/models/props/crates_barrels/crates_barrels.glb` | [Sketchfab: "Crates And Barrels"](https://sketchfab.com/3d-models/crates-and-barrels-5ae3c72285474862a89d69c2f2ad2246) | Mateusz Woliński | CC-BY 4.0 | Sí, con atribución | Cajas y barriles en la pista |

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

