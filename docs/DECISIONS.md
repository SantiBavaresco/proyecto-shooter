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

## 2026-10-24 — Vista del arma en un SubViewport con mundo propio
Godot no tiene "FOV de arma" ni capa sin profundidad nativa. Un SubViewport transparente con su propia cámara, luz y ambiente evita que el arma atraviese paredes y permite FOV independiente. La luz del arma copia la dirección del sol del nivel en espacio de cámara. Costo: un render extra de pocos objetos.

## 2026-10-24 — Proyectiles simulados, no hitscan
Cada bala se integra por tick (gravedad + resistencia cuadrática) con raycast por tramo. Permite caída, tiempo de vuelo, rebotes y, a futuro, penetración. Hasta 256 proyectiles simultáneos, vida máxima 3 s.

## 2026-10-24 — Rebotes: ángulo crítico + probabilidad por material
`core/combat/surface.gd`. El material se declara con metadata `surface` en el cuerpo físico. Solo rebota si el ángulo con la superficie es menor al crítico del material; la probabilidad baja linealmente con el ángulo.

## 2026-10-24 — Daño proporcional a la velocidad remanente
Simple y coherente con la caída de energía por distancia y por rebote. Se ajusta más adelante si hace falta (por ejemplo, curva por calibre).

## 2026-10-24 — Escopeta doble caño, perdigones independientes
Cada perdigón es un proyectil (9 por disparo). Dos disparos antes de recargar; mínimo 0,15 s entre caños.

## 2026-10-24 — Sonidos sintéticos
`core/audio/synth_sfx.gd` genera disparos, clicks, impactos y rebotes por código para que el juego no sea mudo. Se reemplazan por audio real en F8.

## 2026-10-25 — Visor "imagen en imagen"
Elegido por el autor (opción B). Una cámara en el mundo del juego renderiza a una textura de 512×512 que se muestra en el ocular. Su FOV se calcula a partir del tamaño angular del ocular en pantalla dividido el aumento, así el aumento es real. Solo se renderiza mientras se apunta con un arma con visor. Costo: un render extra del mundo a baja resolución mientras se apunta.

## 2026-10-25 — Nombres de armas ficticios
Dentro del juego las armas tienen nombres inventados; el id interno identifica el modelo real de referencia. Se cambian en `localization/*.json`.

## 2026-10-25 — Distancia ojo–mira automática
Cada modelo guarda en su marcador `Sight` una distancia sugerida (miras metálicas: alza a ~12 cm del ojo; red dot 24 cm; visor 7,5 cm; pistolas con el brazo extendido). `eye_relief` en los datos la puede forzar.

## 2026-10-25 — Armería provisoria
Mesas con F para equipar armas mientras no exista el inventario (F2). Se elimina o se convierte en un armero/comerciante cuando llegue el inventario.

## 2026-10-25 — "sks y te" interpretado como SKS + G3
Si era otra arma, se cambia en el generador de datos.

## 2026-10-25 — Modelos de armas por perfiles (F1.6)
Mientras no haya modelos .glb, cada arma se arma por código con perfiles laterales y secciones extruidas con bordes redondeados, piezas torneadas y rieles con dientes, copiando medidas y silueta del arma real. Se funden por material para no cargar la placa de video. Un modelo real futuro solo tiene que respetar los marcadores (`Sight`, `Muzzle`, `Ejection`) y las piezas animables.

## 2026-10-25 — Cerrojo sin dejar el visor
Si el gatillo sigue apretado después del tiro, el cerrojo se acciona sin bajar el arma (el tirador no despega la cara). Si se suelta, baja como antes y vuelve a apuntar al terminar. Mantener el gatillo nunca dispara el siguiente: hay que soltar y volver a apretar.

## 2026-10-25 — Visor variable con la rueda
Los visores con `scope_mag_max` regulan el aumento con la rueda del mouse mientras se apunta (cada muesca ×1,26). El R-700 va de 5× a 25×. La sensibilidad del mouse baja con la raíz del aumento. La rueda queda libre fuera del visor (más adelante puede cambiar de arma).

## 2026-10-25 — Núcleo letal de la cabeza
La caja de la cabeza tiene adentro un núcleo (12 × 13 × 15 cm). Si el recorrido de la bala lo atraviesa, el impacto es "head_core" y mata siempre (`DamageModel.lethal_damage`). Si solo toca la cabeza, es "head" (×3): mucho daño pero no siempre mortal. Los objetos que dan zonas pueden afinarla con `refine_zone()` (metadata `zone_owner`).

## 2026-10-25 — Brazos por código con pose por arma
Hasta tener un modelo de brazos con huesos, los brazos se generan por arma con dedos que se cierran sobre la empuñadura y el guardamanos (`ArmsBuilder.POSES`). La mano izquierda de las escopetas cuelga de los caños.

## 2026-11-02 — Inventario (F2)
- Munición contada por calibre en la mochila (compartida entre armas del mismo calibre). Cargadores individuales quedan para más adelante.
- Las mesas de la armería quedan como banco de pruebas: equipan directo (el arma reemplazada vuelve a la mesa) y dan la munición inicial. El comercio llega en F6.
- El inventario no pausa el mundo (como STALKER 2); el jugador no se mueve ni dispara con la pantalla abierta.
- Sin guardado todavía: morir reinicia el nivel.

## 2026-11-04 — Cargadores, accesorios e inventario por contenedores (2.1)
- **Cargadores reales** por familia (cada uno con sus balas). Pistolas: genéricos por calibre (9×19 de 15, .45 de 10, .22 de 10). Únicos: Bizon (64), Vityaz, MP5, G3, FAL, M14, SR-25, SVD (lo comparte el CK-21). Comparten: STANAG (AR-15, HK416, SCAR-L), AK 5,45 (AR-74, AR-74K), AK 7,62, STEN (ST-2 y AC-9). De más capacidad: STANAG 40, AK 5,45 de 45, AK 7,62 de 40, 9×19 de 25.
- Recarga: el más lleno del chaleco o los bolsillos; de la mochila tarda ×1,6. El viejo vuelve a donde estaba el nuevo con sus balas menos la de la recámara (30 + 1). R dos veces: ×0,72 y el viejo cae al piso.
- Escopetas, revólver, cerrojos y SK-45 siguen con munición suelta.
- **Lugar por equipo**: 4 bolsillos de 1×1, chaleco táctico con grillas chicas (liviano, mediano, de asalto) y mochila con una grilla (4×5, 5×6, 5×8, 6×10). Sin mochila no hay grilla grande. Una mochila o chaleco con cosas no entra en los contenedores del jugador; al cambiarla, lo de adentro pasa a la nueva.
- **Accesorios**: miras sobre un montaje por arma (`data/items/attachments.json`: punto de apoyo y soporte); silenciadores por grupo de rosca según el calibre. Las holográficas de la PP-B y la VK-19 y el visor del CK-21 son ítems sacados de sus modelos (vienen puestos de fábrica). La mira de las armas por código con óptica fija (HK416, SCAR-L, SVD...) no se saca todavía.
- **Disparo accidental**: al montar (recarga vacía o destrabado) y doble disparo en semiautomáticas; muy raro en un arma sana, más probable gastada.
- **Muerte y cooperativo (diseño)**: una sola vida sin cargar partida: al morir, el cuerpo queda con todo y se reaparece en el último campamento neutral con lo del alijo general. La historia avanza por hechos del mundo (no se deshace al morir). Se programa para un jugador pero preparado para cooperativo PvE: el jugador ya se maneja por órdenes (PlayerCommand), los ítems se guardan como datos (to_dict) y el loot al azar se tira la primera vez que se abre la caja con una semilla propia (en red decide el anfitrión).

## 2026-11-05 — Enemigos e Isla Talavera (F3)
- **3 dificultades** (no 4): Novato, Regular, Veterano. Cambian la habilidad de la IA, no la vida ni el daño. Se eligen en el menú antes de la incursión; en la pista de pruebas, con una consola.
- **Los Caranchos** (bandidos del Delta) usan los modelos de operadores/policía que ya había hasta tener los propios.
- **Pose por código** mientras no haya animaciones: IK de piernas y brazos sobre el esqueleto Mixamo. Cuando haya animaciones Mixamo se reemplaza solo la parte de NpcBody (la IA no cambia).
- **IA separada en cuerpo / cerebro / persona**: NpcBody (modelo, pose, cuerpos de impacto), NpcBrain (percepción y decisiones), HumanNpc (vida, blindaje, arma, movimiento). Los blancos son todos los del grupo "player" (cooperativo).
- **Capas**: 5 cuerpos de movimiento de los enemigos (las balas no los tocan; pegan en los cuerpos de impacto, capa 6), 9 follaje (tapa la vista; no frena balas ni gente), 10 tejidos de alambrado (frenan a la gente; no balas ni vista).
- **Blindaje por clase** contra el poder de penetración de la bala (que ya existía para atravesar materiales) y desgaste por impacto.
- **Muerte**: el cuerpo del jugador queda en el mundo con todo; se reaparece en el Puesto del Viejo con cuchillo, pistola y una venda. Todavía sin guardado (eso es F7).
- **Isla Talavera** es un mundo de prueba de la F3 (no es el mapa del Delta de la F4).

