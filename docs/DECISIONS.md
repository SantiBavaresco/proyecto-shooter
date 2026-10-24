# Registro de decisiones

## 2026-10-23 — Godot 4.7.2 con GDScript tipado
Motor elegido en el prompt maestro: gratis, sin regalías, escenas y recursos en texto (los puedo escribir y versionar), y se puede ejecutar y testear en mi entorno con render por software. Versión fijada para que mi entorno y el tuyo sean idénticos.

## 2026-10-23 — Acciones de input registradas por código
`core/input/input_actions.gd` es la única definición de teclas. Motivo: una sola fuente legible, remapeo simple y testeable. Contra: el "Input Map" del editor aparece vacío (es esperado).

## 2026-10-23 — El jugador recibe comandos (`PlayerCommand`)
El controlador nunca lee `Input`. Permite tests con bot y prepara el cooperativo (el host valida comandos de los clientes).

## 2026-10-23 — Interpolación de física + cabeza sin interpolar
Movimiento fluido a cualquier tasa de refresco (144 Hz, etc.) con física fija a 60 Hz, y mirada sin retraso.

## 2026-10-23 — Textos en JSON propio (no CSV importado)
`Loc` arma las traducciones en runtime desde `localization/*.json`. No depende de que el editor importe archivos y un test verifica que todos los idiomas tengan las mismas claves.

## 2026-10-23 — Runner de tests propio (sin GUT/GdUnit4)
Unas 120 líneas, sin addons ni dependencias de versión. Si crece la necesidad, se migra.

## 2026-10-23 — Escaleras con rampa de colisión invisible
`CharacterBody3D` no sube escalones solo. En la pista se usa una rampa invisible (técnica estándar). Subir escalones reales ("step up") se evalúa cuando haya escenarios con escalones sueltos.

## 2026-10-23 — Aceleración en m/s²
`ground_accel` 16 y `ground_decel` 20: arranque y frenado con algo de peso, sin sentirse lento. Ajustable en el `.tres`.

## 2026-10-23 — Joystick: saltar = A, agacharse = B
El prompt dejaba A para interactuar. Como `interact` y `reload` comparten X (tocar/mantener se resuelve en F1–F2), en F0 A es saltar. Se revisa cuando haya interacción.

## 2026-10-24 — Gravedad de juego, no real
Con 9,8 m/s² el salto se sentía "como un papel" (prueba en tu PC). Ahora la subida usa 2× la gravedad y la caída 2,6×, con velocidad de salto 6,6 m/s: misma altura (~1,1 m) pero ~0,6 s en el aire en vez de ~0,95 s. Parámetros `gravity_up_mult`, `gravity_down_mult` y `max_fall_speed` en el `.tres`.

## 2026-10-24 — Entregas como .exe
Cada fase se entrega también como `Medoreador.exe` (preset "Windows" en `export_presets.cfg`, todo embebido en un solo archivo) para probar sin instalar Godot.
