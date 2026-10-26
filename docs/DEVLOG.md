# Devlog

## F0 — Base técnica y movimiento (2026-10-23)

### Funciona
- Proyecto Godot 4.7.2 (Forward+, Jolt, interpolación de física), estructura de carpetas, Git LFS configurado.
- Autoloads: EventBus, Settings, Loc, AudioManager, SaveManager (esqueleto), GameState, DebugTools.
- Flujo de pantallas: título → carga en segundo plano con progreso → pista de pruebas ⇄ pausa → título.
- Opciones completas con guardado: FOV (90° por defecto, 70–110), pantalla completa, VSync, sensibilidad, invertir Y, movimiento de cámara, volúmenes, idioma (español / English), **remapeo de teclas** con aviso de conflictos.
- Jugador: caminar, correr, saltar (con coyote time y buffer), agacharse (mantener C), deslizarse (C corriendo), inclinarse (Q/E) con límite contra paredes, estamina con agotamiento, bamboleo de cámara opcional, FOV dinámico al correr/deslizarse, sombra del cuerpo.
- HUD mínimo: punto central y barra de estamina que aparece solo cuando no está llena.
- F1: overlay de rendimiento y estado. F12: reporte de bug a archivo + portapapeles.
- Pausa silencia música, ambiente, voces y mundo; la UI sigue sonando.
- Pista de pruebas: carril con marcas, cajas de salto, túnel bajo, rampas, escalera, huecos, esquina para inclinarse, contenedores.
- 41 tests automáticos (unitarios + bot jugando): todos pasan.

### Falta / próximo
- Joystick: mapeado pero sin probar con un control real.
- Escalones reales sin rampa invisible.
- Fondo del título y pantalla de carga: dibujados por código (placeholder).

### Bugs conocidos
- Ninguno detectado en los tests. El rendimiento real se mide en tu PC (en mi entorno el render es por software).

## F0.1 — Ajuste de salto (2026-10-24)
- Feedback: salto y caída muy lentos. Gravedad aumentada y caída más rápida que la subida; misma altura.
- Tests nuevos: tiempo en el aire y cruce de hueco de 2 m. 43 tests OK.

## F1 — Armas, balística y polígono de tiro (2026-10-24)

### Funciona
- Tres armas con datos en `data/weapons/*.tres`: fusil (tiro a tiro/automático, red dot), escopeta doble caño (9 perdigones), pistola. Slots 1–3.
- Modelos de prueba por código con puntos de anclaje (`Muzzle`, `Sight`, `Ejection`) y piezas animables. Manos de bloque.
- Vista del arma en un mundo propio (SubViewport): no atraviesa paredes, FOV propio, iluminada con la dirección del sol del nivel.
- **Apuntado real**: el marcador `Sight` queda exactamente en el centro de la pantalla. Red dot con punto proyectado al infinito (shader), solo visible a través de la lente.
- Retroceso de cámara (sube + desvío) con recuperación parcial; patada visual del arma; dispersión según cadera/apuntado, movimiento, aire y agachado.
- Animaciones por código: balanceo al caminar, inercia al mirar, respiración, arma baja al correr, recarga (cargador / quiebre de la escopeta / manija / corredera), sacar y guardar.
- Balística: proyectiles con velocidad, gravedad y resistencia del aire; daño según velocidad remanente y zona (cabeza ×2,5, torso ×1, extremidades ×0,6); rebotes según material y ángulo.
- Efectos: fogonazo + luz real, trazadoras, casquillos con física, marcas de impacto, partículas por material, sonidos sintéticos (disparo, mecánica, impacto, rebote). Hit-stop sutil en derribos y tiros a la cabeza.
- Polígono: dianas a 25/50/100/200 m (muestran distancia y caída), maniquíes con zonas, placa de acero, caja de munición (primera interacción con F).
- HUD: munición siempre visible, modo de disparo, recargando, marcador de impacto, punto central que se oculta al apuntar, opción para ocultar todo el HUD.
- Opciones nuevas: apuntar alternar/mantener, mostrar HUD. Teclas nuevas: B modo de disparo, F3 trayectorias, F4 munición infinita.
- 67 tests automáticos (24 nuevos de armas y balística).

### Falta / próximo
- Granadas y cuchillo (slot 4).
- Indicador de dirección de daño (necesita enemigos, F3).
- Sonidos y modelos reales (F8).

### Bugs conocidos
- Ninguno en los tests. Al cerrar los tests Godot avisa de 4 objetos sin liberar (caché de sonidos sintéticos): inofensivo.

## F1.5 — Armería: 25 armas (2026-10-25)

### Funciona
- 25 armas con nombres ficticios inspirados en reales (catálogo en `data/weapons/catalog.json`):
  - Pistolas: P9 (9 mm, polímero), Pampa .22 (de inicio), Tala T9 (9 mm), Ballestero .45, Liberty .45.
  - Subfusiles: MK5 (9 mm), PP-B (9×18, cargador helicoidal).
  - Fusiles: AR-C (5.56, solo tiro a tiro), K416 y SC-L (5.56, red dot), AR-74 (5.45), AR-M (7.62×39), FMR (7.62×51), G-3A (7.62×51), carabina SK-45 (7.62×39, se carga por peine).
  - Tiradores: DR-1 (visor 4×, retícula chevrón), KR-25 (visor 5×), M-14E (visor 3×, automático), carabina R-22S (.22).
  - Cerrojo: rifle .22 (de inicio), R-700 (.308, visor 6×), Fusil Argentino 1909 (7.65×53, peine).
  - Escopetas: doble caño, recortada, superpuesta de caza.
- Generador de modelos por familia y parámetros (largo de caño, receptor, culata, guardamanos, cargador recto/curvo/helicoidal/interno, boca, madera/polímero/arena).
- **Visor con aumento real** (imagen en imagen): una segunda cámara renderiza al ocular con el FOV justo para que el aumento sea el indicado; la vista de afuera no hace zoom. Retículas cruz, duplex y chevrón. La sensibilidad del mouse baja con el aumento.
- **Cerrojo manual**: después de cada tiro se acciona (animación, sale la vaina); no se puede disparar mientras tanto.
- **Recarga cartucho a cartucho** (cerrojos, SK-45) y **por peine** con el arma vacía (Argentino 1909, SK-45).
- Armería en el polígono: 25 mesas con el arma, nombre y calibre. F la equipa: pistolas al slot 3; largas al slot largo en la mano (o al 1).
- HUD: nombre del arma + calibre.
- 75 tests (8 nuevos: catálogo, modelos, apuntado de las 25 armas, cerrojo, recargas, visor, armería).

## F1.6 — Modelos de armas y visor variable (2026-10-25)

### Funciona
- **Modelos nuevos para las 25 armas**, cada uno con la silueta y medidas del arma real: receptores estampados o fresados, guardamanos (redondo, cuádruple riel, M-LOK, madera), empuñaduras inclinadas con resaltos, culatas (retráctil, fija, esqueletizada, plegable, de caza con Monte Carlo), cargadores curvos de verdad, bocachas, rieles Picatinny con dientes, miras con orejas, capuchas y alzas de anillo, visores con campanas, torretas y anillas, y madera con veta.
- Generador nuevo `MeshKit` (perfiles extruidos con bordes redondeados, secciones y tornos). Las mallas se funden por material: menos carga para la placa.
- Las mesas de la armería apoyan y centran cada arma según su tamaño real.
- **Cerrojo sin sacar el ojo del visor**: con el gatillo apretado después del tiro, se acciona el cerrojo sin bajar el arma. Soltando, baja como antes.
- **Visor variable**: el R-700 va de 5× a 25× con la rueda del mouse mientras se apunta. El HUD muestra el aumento. Las teclas se pueden cambiar en Opciones.
- 78 tests (3 nuevos: cerrojo con gatillo apretado, cerrojo con gatillo suelto, visor variable).

### Falta / próximo
- F2: inventario.

## F1.7 — Brazos, guardamanos y tiros a la cabeza (2026-10-25)

### Funciona
- **Brazos nuevos** (`ArmsBuilder`): guante con palma, cuatro dedos de tres falanges que se cierran alrededor de la empuñadura o del guardamanos, índice en la cola del disparador, pulgar, muñeca con puño, antebrazo con manga, codo y arranque del brazo. Pose propia por arma (empuñadura, garganta de culata, guardamanos); pistolas con las dos manos.
- **Escopetas**: la mano izquierda va con los caños, así al quebrarla ya no la atraviesan.
- **Guardamanos con forma** (nueva herramienta de loft): estrías del A2, ensanche para la palma del AK, tope para la mano del MK5, FMR y G-3A redondeados con ventilaciones, DR-1 con ventanas, forends de escopeta redondeados, cubiertas de riel en el K416.
- **Cabeza en dos zonas**: el núcleo (cerebro y centro de la cara, también la sien de perfil) mata de un tiro con cualquier arma y muestra "LETAL"; la periferia (pómulo, mandíbula, oreja, roce del cráneo) hace ×3.
- 79 tests (1 nuevo: núcleo letal y periferia).

## F1.8 — Recarga de escopetas (2026-10-25)

### Funciona
- Los caños se quiebran a fondo (62°) y el arma se sube y se acerca para ver las recámaras.
- La mano izquierda suelta el guardamanos, los caños caen, salen las vainas, la mano trae dos cartuchos, los mete al ras de la recámara, se va, el arma se cierra y la mano vuelve al guardamanos. Vale para las tres escopetas.
- 79 tests.

## F1.9 — Recargas con manos y movimiento fluido (2026-10-25)

### Funciona
- Recorridos suaves (Catmull-Rom) para manos y piezas en todas las recargas, y golpes del arma: al sacar y calzar el cargador, al abrir y cerrar los caños, al tirar de la manija.
- **Cargador (fusiles y subfusiles)**: el arma se sube y se inclina; la mano derecha baja al cargador, se lo lleva, trae otro, lo calza y, vacía, tira de la manija. La mano izquierda se acomoda en el guardamanos y gira sobre él para que el brazo cuelgue.
- **Pistolas**: la mano izquierda saca y pone el cargador.
- **Cartucho a cartucho** (cerrojos, SK-45): la mano derecha va a la ventana y empuja cada cartucho.
- **Cerrojo**: la mano derecha va a la bola y la acompaña.
- **Escopetas**: la muñeca de la mano que carga ahora sale de la palma; recorridos en arco.
- Báscula y culatas de las escopetas redondeadas (secciones ovaladas que cambian a lo largo).
- 79 tests.

## F1.10 — Ajustes de manos (2026-10-26)

### Funciona
- Armas largas: la derecha sostiene el arma y la izquierda cambia el cargador y tira de la manija.
- Escopetas: la mano que carga va con la palma sobre los culotes, nudillos arriba, dedos por adelante y pulgar del lado de la cámara (ya no se ve invertida).
- Pistolas: la mano derecha toma alto, bajo la cola del armazón.
- Cerrojos: la mano que carga cartucho a cartucho va pegada a la ventana.
- Al apuntar, si el ojo queda muy cerca de la mano (escopetas), la mano baja un poco.

## F1.11 — Montar en recámara, vainas y recámaras huecas (2026-10-26)

### Funciona
- **Fusiles tipo AK (AR-74, AR-M, DR-1, PP-B) y SKS/EBR**: la izquierda cambia el cargador y vuelve al guardamanos; el arma gira para mostrar el lado derecho y la **mano derecha** monta con la manija y vuelve a la empuñadura.
- **G-3A, MK5, FMR, SC-L y familia AR**: la izquierda va del brocal a la manija **por afuera del arma** (ya no la atraviesa).
- Mano de montar con pose propia (gancho): índice y mayor enganchados delante de la bola, anular y meñique en puño, pulgar por abajo. El brazo cuelga hacia abajo aunque el arma esté girada.
- La manija va atrás con la mano, se sostiene y **se suelta**: vuelve de golpe y el arma se sacude.
- Recarga con cargador más fluida: tiempos nuevos, muñecas que giran en el recorrido, golpes del arma al sacar, calzar, tirar y soltar.
- El cargador viejo baja y **sale de la vista** (se oculta abajo); el nuevo entra desde abajo. Ya no se ve el mismo cargador ir y volver.
- Pistolas: la corredera se libera apenas entra el cargador.
- **Escopetas**: al quebrar, el extractor saca las vainas y el expulsor las tira **hacia arriba y atrás**; siguen como vainas físicas. Un cartucho sin disparar queda en su recámara.
- **Recámaras huecas** en las dos escopetas (boca achaflanada y fondo oscuro); forend, monoblock y herrajes corridos para no taparlas.
- Mano que carga los cartuchos: la muñeca sigue al antebrazo (ya no queda quebrada).
- 79 tests.

## F1.12 — Estrés de combate y fallas del arma (2026-10-26)

### Funciona
- **Zonas de prueba** pintadas entre la armería y la línea de tiro: *Estrés medio*, *Estrés alto*, *Estrés extremo* y *Armas gastadas*. Desde ahí se tira a las dianas.
- **Estrés** (`core/stress.gd`): sube rápido y baja lento; niveles medio, alto y extremo (este último para casos puntuales: balanceo mucho más amplio, también arriba y abajo, más deriva, desenfoque máximo con visión de túnel estrecha (el centro queda nítido; en alto hay un túnel suave y ancho), recarga con tres intentos al brocal y 50 % de olvidar montar). Por ahora lo fijan las zonas (después: supresión y daño).
  - Visión: desenfoque leve (más en los bordes), distorsión que ondula y late con el pulso, algo desaturada y doble imagen apenas corrida; sin oscurecer los bordes (`ui/effects/stress_overlay.gd`, capa 0: no afecta al arma ni al HUD).
  - Más dispersión desde la cadera (hasta ×2,1 en alto).
  - Deriva lenta de la mira, menor apuntando; cada latido la empuja. Mueve la cámara de verdad: cambia dónde va la bala.
  - Pulso inestable: el arma y las manos se balancean lento e irregular (no vibran), con un tirón en cada latido; más fuerte manipulando. En alto, más desenfoque; en extremo, el máximo. El latido del movimiento es redondeado (antes era un golpe seco que se veía como vibración).
- **Recarga con estrés** (`entities/weapons/reload_plan.gd`): la recarga con cargador ahora es un plan armado al empezar.
  - Medio: ~12 % más lenta y a veces le pega al brocal una vez.
  - Alto: ~70–75 % más lenta; le erra al brocal dos veces (el cargador pega en el borde, lo baja y reintenta).
  - Vacía con estrés, a veces se olvida de montar (15 % medio, 35 % alto): el primer gatillazo hace "clic" y R monta.
  - Escopetas y cartucho a cartucho: solo más lentas.
- **Fallas por desgaste**: cada arma tiene estado (baja con cada disparo; se ve en el HUD cuando no está al 100 %). La zona de armas gastadas lo simula al 18 %.
  - *No disparó*: clic. R: golpe al cargador, monta, sale el cartucho.
  - *Encasquillada*: vaina trabada en la ventana (se ve). R: monta y sale la vaina.
  - *Doble alimentación*: manija apenas atrás. R: saca el cargador, monta dos veces, lo vuelve a meter y monta. Se pierde un cartucho.
  - Cerrojos: se acciona el cerrojo. Pistolas: mano izquierda nueva que toma la corredera por arriba. Escopetas: falla el cartucho y se pasa al otro caño.
  - Mensaje en rojo debajo del centro con la falla y "[R]".
- 87 tests (8 nuevos: estrés, riesgo de falla, duración con estrés, planes, zonas, olvido de montar, destrabado, cerrojo).

