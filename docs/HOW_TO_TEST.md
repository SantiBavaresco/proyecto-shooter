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

## F1.7 — Brazos, guardamanos y cabeza

| # | Probá | Esperado |
|---|---|---|
| 1 | Mirar las manos con cada arma | Dedos cerrados sobre la empuñadura y el guardamanos, índice en la cola del disparador; con pistola, las dos manos |
| 2 | Recargar escopetas (vacías) | La mano izquierda baja con los caños; no la atraviesan |
| 3 | Guardamanos de AR-C, AR-74/AR-M, MK5, FMR, G-3A, DR-1 | Redondeados, con estrías, ensanches, ventilaciones |
| 4 | Tiro al centro de la cara o a la sien de un maniquí | Cae de un tiro con cualquier arma (aparece LETAL) |
| 5 | Tiro al pómulo, mandíbula u oreja | Mucho daño (×3) pero no siempre lo tira |

## F1.8 — Recarga de escopetas

| # | Probá | Esperado |
|---|---|---|
| 1 | Vaciar una escopeta y R | Los caños se abren a fondo; la mano izquierda trae dos cartuchos y los mete; se cierra y la mano vuelve al guardamanos |

## F1.9 — Recargas con manos

| # | Probá | Esperado |
|---|---|---|
| 1 | Vaciar un fusil (AR-M, K416…) y R | El arma se sube e inclina; la mano derecha saca el cargador, trae otro, lo calza y tira de la manija |
| 2 | Recargar sin vaciar | Igual, pero sin la manija |
| 3 | Pistola vacía y R | La mano izquierda cambia el cargador; la corredera vuelve al final |
| 4 | R-700 / Argentino 1909 | La mano derecha empuja cada cartucho; al disparar, va a la bola del cerrojo |
| 5 | Escopetas | Báscula y culata redondeadas; la mano que carga los cartuchos no tiene la muñeca separada |

## F1.11 — Montar en recámara

| # | Probá | Esperado |
|---|---|---|
| 1 | Vaciar el AR-M (o AR-74, DR-1, PP-B) y R | La izquierda cambia el cargador y vuelve adelante; el arma gira y la mano derecha tira de la manija, la suelta y vuelve a la empuñadura |
| 2 | Vaciar el G-3A (o MK5, FMR) y R | La izquierda va del cargador a la manija por afuera del arma, con los dedos enganchados; tira, suelta y vuelve al guardamanos |
| 3 | Cualquier recarga con cargador | El cargador viejo baja y sale de la vista; no se ve el mismo cargador volver |
| 4 | Escopeta: disparar los dos tiros y R | Al quebrar, las vainas salen hacia arriba y atrás; después entran los cartuchos nuevos |
| 5 | Escopeta: disparar un solo tiro y R | Sale una vaina; el otro cartucho queda en su recámara |
| 6 | Mirar las recámaras con los caños abiertos | Son huecas (no planas) |
| 7 | Mano que carga la escopeta | La muñeca sigue la línea del antebrazo |

## F1.12 — Estrés y fallas

Las zonas están pintadas en el piso entre las mesas de la armería y la línea de tiro.

| # | Probá | Esperado |
|---|---|---|
| 1 | Pararte en ESTRÉS ALTO | En ~1 s la vista se desenfoca, ondula y late con el pulso (sin bordes oscuros); arriba de la munición dice ESTRÉS ALTO |
| 2 | Apuntar ahí | La mira se mueve apenas, lento; los tiros se abren un poco |
| 3 | Tirar desde la cadera ahí | Bastante más dispersión que afuera |
| 4 | Vaciar el AR-M y R en estrés alto | Tarda ~70 % más; el cargador pega dos veces en el brocal antes de entrar; manos temblorosas |
| 5 | Repetir varias veces | A veces no monta: el gatillo hace clic y aparece SIN BALA EN RECÁMARA; R monta |
| 6 | ESTRÉS MEDIO | Lo mismo pero más leve |
| 6b | ESTRÉS EXTREMO | Mucho más borroso, el arma se balancea en un rango grande, la mira deriva más; recarga muy torpe |
| 7 | Salir de la zona | El estrés baja de a poco (~5 s) |
| 8 | ARMAS GASTADAS con un fusil, tirar ráfagas | Cada tanto: NO DISPARÓ, ENCASQUILLADA o TRABADA; el gatillo no hace nada hasta apretar R |
| 9 | R con cada falla | No disparó: golpe al cargador y monta (sale el cartucho). Encasquillada: se ve la vaina parada en la ventana; al montar sale. Trabada: saca el cargador, monta dos veces, lo mete y monta |
| 10 | Pistola en ARMAS GASTADAS | La mano izquierda toma la corredera por arriba y la tira |
| 11 | R-700 en ARMAS GASTADAS | Si no dispara, R acciona el cerrojo |

## F1.13 — Penetración

La estación está a la izquierda del polígono, afuera del muro, con su propia línea amarilla.

| # | Probá | Esperado |
|---|---|---|
| 1 | Fusil (AR-M) a cada panel | Atraviesa madera 2 cm, chapa 1 mm y chapa 4 mm (la diana de atrás marca el impacto); la viga de 20 cm lo frena |
| 2 | Pistola a cada panel | Atraviesa madera 2 cm y chapa 1 mm; la chapa de 4 mm y la viga la frenan |
| 3 | Escopeta | Los perdigones casi no pasan la madera; la chapa fina sí, apenas |
| 4 | R-700 a la viga | Tampoco la pasa (20 cm es mucho); a la chapa de 4 mm sí |
| 5 | F3 (trayectorias) | La línea sigue del otro lado del panel |

## F1.14 — Ajustes

| # | Probá | Esperado |
|---|---|---|
| 1 | Recargar en ESTRÉS EXTREMO varias veces | El brazo izquierdo no pasa por arriba de la pantalla; los intentos al brocal varían (1 a 4) |
| 2 | Pistola en ESTRÉS EXTREMO | Hasta 3 intentos |
| 3 | Escopeta: tirar y recargar | Las vainas rojas saltan rápido hacia arriba; no salen casquillos dorados |
| 4 | R-700 vacío y R | El contador sube de a uno |
| 5 | Durante esa recarga, clic | Cierra el cerrojo y se puede tirar con los que ya entraron |

## F1.15 — Respiración con visor

| # | Probá | Esperado |
|---|---|---|
| 1 | R-700 o DR-1 apuntando a la diana de 200 m | La retícula se mece lento sobre el blanco; la bala va donde está la retícula |
| 2 | Mantener Shift apuntando | Se queda casi quieta; en el HUD "AGUANTANDO LA RESPIRACIÓN" con los segundos |
| 3 | Mantenerlo más de 5 s | "SIN AIRE": se mueve más unos segundos |
| 4 | En ESTRÉS ALTO | Shift ayuda pero sigue moviéndose; dura menos |
| 5 | En ESTRÉS EXTREMO | Shift no hace nada |
| 6 | Agachado | Se mece menos |

## F1.16 — Escopetas

| # | Probá | Esperado |
|---|---|---|
| 1 | Escopeta doble caño y recortada, apuntar | Se ve el guion (punto dorado) arriba de la báscula, como en la superpuesta |
| 2 | Recargar | Los caños se abren rápido y secos |
| 3 | Recargar en ESTRÉS ALTO / EXTREMO | Más lenta; a veces los cartuchos pegan en el borde de la recámara y reintenta; la mano tiembla |

## F1.19 — Brazos y recarga importada con estrés
1. Recorré la armería con varias armas (pistola, AK, escopeta, cerrojo): todas usan ahora los brazos del AR-74K. Mirá las manos en cadera, apuntando y en cada recarga (sacar y poner cargador, montar, cartuchos en la escopeta, cerrojo).
2. Con la AR-74K parate en ESTRÉS ALTO o EXTREMO y recargá varias veces: a veces el cargador pega en el brocal y reintenta (golpe y sonido), hasta 2 veces en alto y 3 en extremo.

## F1.20 — Manos, mira y sonido
1. Con varias armas (AK, pistola, SKS, cerrojo) mirá la mano derecha: el índice en el gatillo y la mano sobre la empuñadura, sin atravesar el arma.
2. AR-74K apuntando: el blanco se ve arriba del guion y la bala pega en la punta del guion.
3. Disparos: probá una de cada calibre (pistola, AK, fusil 7,62, escopeta, .22). Ráfagas: las colas se encadenan.

## F1.21 — Sonido y fogonazos
1. Pistolas, .22 y escopeta: sin sonido de pandereta ni eco largo.
2. Rifles de cerrojo (R-700, Mauser) y fusiles largos: retumbe más largo.
3. Tirando a una placa de acero: ya no hay zumbido de rebote.
4. En automático cada fogonazo es distinto (forma, largo, color).

## Tests automáticos (opcional, desde una terminal)

```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
Al final imprime `RESULTADO: N OK, 0 FALLARON`.

Capturas de pantalla automáticas (sin `--headless`):
```
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/screenshot_runner.tscn -- --out=capturas
```
