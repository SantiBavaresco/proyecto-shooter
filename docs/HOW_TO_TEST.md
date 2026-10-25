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

## F1 — Armas y polígono de tiro

Desde el spawn, **date vuelta** (el polígono está atrás, pasando la abertura del muro).

| # | Probá | Esperado |
|---|---|---|
| 1 | 1 / 2 / 3 | Fusil, escopeta doble caño, pistola. El arma baja y sube al cambiar |
| 2 | Clic derecho (alterna) | Apuntás **por la mira del arma**: red dot en el fusil, guion en la escopeta, alza y guion en la pistola. El punto central desaparece |
| 3 | Disparar al maniquí de 10 m | Número de daño de color: blanco torso, rojo cabeza. Marcador de impacto en el centro. Un tiro de fusil a la cabeza lo voltea; se levanta a los 3 s |
| 4 | B con el fusil | Cambia TIRO A TIRO ↔ AUTOMÁTICO (abajo a la derecha) |
| 5 | Ráfaga en automático | La mira sube y se va de costado; al soltar vuelve una parte. Trazadora cada 3 balas |
| 6 | R | Recarga animada (el cargador sale y entra). Vacío tarda más (tira de la manija). No se puede disparar recargando |
| 7 | Escopeta: dos tiros y R | Se quiebra, saltan las vainas, entran cartuchos nuevos |
| 8 | Diana de 100 y 200 m (apuntando) | Arriba de la diana: distancia y **caída** de la bala en cm |
| 9 | Placa de acero inclinada | Tiros rasantes rebotan (chispas + zumbido). Con **F3** se ven las trayectorias (rojo = rebote) |
| 10 | Disparar al piso, muros, contenedores | Marcas y partículas distintas según material (tierra, hormigón, metal, madera) |
| 11 | Correr y disparar | Corriendo no dispara; al soltar Shift hay un instante antes de poder tirar |
| 12 | Apuntar y caminar | Más lento; correr cancela el apuntado |
| 13 | Caja de munición (al lado de la línea de tiro) | Mirarla: aparece "[F] Recargar munición"; F repone todo |
| 14 | F4 | Munición infinita (laboratorio) |
| 15 | Opciones → Video → Mostrar interfaz; Controles → Apuntar: alternar | Oculta todo el HUD; cambia entre alternar y mantener |

## F1.5 — Armería

Detrás de la línea de tiro hay 25 mesas (cartel ARMERÍA), cada una con un arma, su nombre y calibre.

| # | Probá | Esperado |
|---|---|---|
| 1 | Mirar una mesa y F | "[F] Tomar …"; el arma queda en la mano. Pistolas van al slot 3; las largas al slot largo que tengas en la mano |
| 2 | Apuntar con cada una | Siempre se apunta por su mira: alza y guion, red dot o visor |
| 3 | Visores (DR-1, KR-25, M-14E, R-700) | Al apuntar, el ocular muestra la imagen aumentada con retícula; alrededor la vista es normal. El mouse se vuelve más fino |
| 4 | Cerrojo (rifle .22, R-700, Argentino 1909) | Después de cada tiro se acciona el cerrojo y salta la vaina; no dispara hasta terminar |
| 5 | R con cerrojos y SK-45 | Carga cartucho a cartucho; vacía, el Argentino 1909 y la SK-45 cargan un peine entero de una |
| 6 | Escopetas recortada y superpuesta | Recortada: muy abierta; superpuesta: perdigones más agrupados |
| 7 | B en armas con automático | MK5, PP-B, K416, SC-L, AR-74, AR-M, FMR, G-3A, M-14E |

## F1.6 — Modelos y visor variable

| # | Probá | Esperado |
|---|---|---|
| 1 | Recorrer la armería | Cada arma se parece a la real: AR-74/AR-M con cargador curvo, DR-1 con culata esqueletizada, MK5 con tubo y capucha, escopetas con caños redondos |
| 2 | R-700 apuntando, rueda del mouse | Rueda arriba acerca hasta 25×, abajo aleja hasta 5×; abajo a la derecha se ve el aumento |
| 3 | R-700 apuntando, disparar y mantener el clic | El cerrojo se acciona sin salir del visor; recién al soltar y volver a apretar dispara de nuevo |
| 4 | R-700 apuntando, disparar y soltar enseguida | El arma baja para accionar el cerrojo y vuelve a apuntar sola |
| 5 | Opciones → Controles | Aparecen "Más aumento (visor)" y "Menos aumento (visor)" |

## Tests automáticos (opcional, desde una terminal)

```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
Al final imprime `RESULTADO: N OK, 0 FALLARON`.

Capturas de pantalla automáticas (sin `--headless`):
```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/screenshot_runner.tscn -- --out=capturas
```
