# Cómo probar

## Cada entrega

1. En la carpeta del proyecto: `git pull`
2. Abrir Godot 4.7.2 → el proyecto → **F5**.
3. Seguir la lista de la fase (abajo).
4. Si algo falla: **F12** en el momento del problema. Guarda un reporte y lo copia al portapapeles: pegalo en el chat tal cual.

## F0 — Movimiento y base

Desde el título elegí **Pista de pruebas**. Arrancás mirando hacia el carril de carrera.

| # | Probá | Esperado |
|---|---|---|
| 1 | Caminar con WASD y mirar con el mouse | Movimiento preciso, sin tirones ni demora en la mirada |
| 2 | Shift + W en el carril | Corrés más rápido; el campo de visión se abre un poco; aparece la barra de estamina abajo |
| 3 | Correr ~8 s seguidos | La estamina se agota (barra roja) y pasás a caminar; se recupera después de 1 s quieto |
| 4b | Saltar en el lugar | Salto firme: sube rápido y cae más rápido, ~0,6 s en el aire (antes ~0,95 s, se sentía flotante) |
| 4 | Espacio frente a las cajas (derecha) | Subís a la de 0,5 m y a la de 1 m; la de 1,5 m no |
| 5 | Mantener C | Bajás la cámara y caminás lento; al soltar te parás |
| 6 | Entrar al **túnel** (izquierda) parado y después agachado | Parado no entrás; agachado sí. Si soltás C adentro, seguís agachado hasta salir |
| 7 | Correr y apretar C | Te deslizás con impulso y terminás agachado |
| 8 | Q / E en la **esquina** | La cámara se asoma y rota; contra la pared no la atraviesa |
| 9 | **Rampas** de 20°, 40° y 55° | Subís las dos primeras; la de 55° no |
| 10 | **Escalera** | La subís caminando |
| 11 | Huecos de 2, 3 y 4 m | 2 m caminando; 3 m corriendo; 4 m corriendo y saltando justo en el borde (al límite) |
| 12 | Esc | Pausa; Opciones funciona desde ahí; Continuar vuelve al juego |
| 13 | Opciones → cambiar FOV, sensibilidad, una tecla, idioma a English | Se aplica al instante y queda guardado al reiniciar |
| 14 | F1 | Aparecen FPS y datos del jugador. **Pasame los FPS que te da en tu PC** |

## Tests automáticos (opcional, desde una terminal)

```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
Al final imprime `RESULTADO: N OK, 0 FALLARON`.

Capturas de pantalla automáticas (sin `--headless`):
```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/screenshot_runner.tscn -- --out=capturas
```
